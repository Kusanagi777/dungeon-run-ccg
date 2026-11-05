## Reward Draft: what a won match offers (design/gdd/reward-draft.md D1-D12, F1-F4;
## ADR-0003, ADR-0005). Pure logic with no persistent state of its own: the run record
## is the memory and the `draft_<floor>` stream is the randomness.
##
## [method offer] is a pure function of `(run_state, stream position)`: it mutates
## nothing, reads no clock and no profile, and draws exactly F4's count, so a resume
## regenerates the same offer from the restored stream (D12). Exclusion and pity are
## derived from `run_state.drafts[]` on every call (D3); only the unlock-filtered
## treasure pool is snapshotted, once, in [method init_run].
##
## `offer` and `pick` take no log, so the run hands over its run log through
## [method set_run_log] whenever it opens one; `draft_offered`, `draft_picked` and the
## `run_warning`s go there.
## [codeblock]
## var draft := RewardDraft.new(db, treasures, meta, db.config("reward_draft"))
## draft.set_run_log(run_log)
## run_state.draft_state = draft.init_run(run_state)
## var offer: Offer = draft.offer(&"treasure", run_state, rng.stream("draft_1"))
## var pick: Pick = draft.pick(&"treasure", offer.option_ids[0], offer, run_state)
## [/codeblock]
class_name RewardDraft
extends RefCounted

## D3 `draft_state.schema_version`.
const DRAFT_STATE_SCHEMA_VERSION: int = 1
## The affinity tag of a universal treasure (F2; Treasures T1).
const UNIVERSAL_TAG: String = "universal"
## D8 `treasure_short_policy` values.
const POLICY_FEWER: String = "fewer"
const POLICY_REOFFER: String = "reoffer"
## F1 cost buckets, as indices into a `band_cost_curve` row.
const BUCKET_LOW: int = 0
const BUCKET_MID: int = 1
const BUCKET_HIGH: int = 2
## Percent scale of `affinity_step`, `band_cost_curve` and `treasure_affinity`: the
## data stores percentages as integers (reward-draft Formulas).
const PERCENT: int = 100

var _db: CardDatabase
var _treasures: Treasures
var _meta: MetaApi
var _heroes: Heroes
var _config: Dictionary
var _log: EventLog = null


## [param draft_config] is `config("reward_draft")`, read here and kept. The
## database, [param treasures] and [param meta] are held, not copied.
func _init(db: CardDatabase, treasures: Treasures, meta: MetaApi, draft_config: Dictionary) -> void:
	_db = db
	_treasures = treasures
	_meta = meta
	_config = draft_config
	_heroes = Heroes.new(db)


## The log draft events go to from now on (D11). The run calls this each time it
## opens or reopens a run log; null silences them.
func set_run_log(log: EventLog) -> void:
	_log = log


## True when `allow_skip` lets the player take nothing (D9).
func allows_skip() -> bool:
	return bool(_config.allow_skip)


## D3: the `draft_state` of a new run, `{schema_version, treasure_pool}`, the pool
## id-sorted through `Treasures.pool` (ADR-0005 rule 10, QQ-08), which is the one
## time Meta is read. Draws nothing and emits nothing. [param _run_state] is the
## D1 signature; no field of it decides the pool.
func init_run(_run_state: RunState) -> Dictionary:
	var unlocked: Dictionary = {}
	for key: Variant in _meta.unlocked_keys():
		unlocked[key] = true
	var pool: Array = []
	for def: Dictionary in _treasures.pool(unlocked, []):
		pool.append(def.id)
	return {"schema_version": DRAFT_STATE_SCHEMA_VERSION, "treasure_pool": pool}


## True when [param draft_state] has the D3 shape; otherwise the run calls
## [method init_run] at resume (run-structure R8.2).
static func draft_state_is_usable(draft_state: Dictionary) -> bool:
	return draft_state.get("schema_version") == DRAFT_STATE_SCHEMA_VERSION and draft_state.get("treasure_pool") is Array


## D1: the offer of [param kind] for `run_state.floor`, drawing from [param stream].
## An empty `option_ids` is the run's cue to skip the step (D8, run-structure R5.7):
## `draft_offered` is emitted for every non-empty offer and never for an empty one.
func offer(kind: StringName, run_state: RunState, stream: RngStream) -> Offer:
	var result: Offer = Offer.new()
	result.kind = String(kind)
	result.floor = run_state.floor
	var drawn: Array[String]
	if result.kind == DraftRecord.KIND_TREASURE:
		drawn = _draw_treasures(result, run_state, stream)
	else:
		drawn = _draw_bundles(result, run_state, stream)
	drawn.sort()
	result.option_ids = drawn
	if drawn.is_empty():
		return result
	result.per_option = _option_rows(result, run_state)
	var flag_names: Array[String] = []
	for flag: StringName in result.flags:
		flag_names.append(String(flag))
	_emit(RunCodes.EVENT_DRAFT_OFFERED, {
		"floor": result.floor,
		"kind": result.kind,
		"option_ids": Array(drawn),
		"flags": flag_names,
	})
	return result


## D9: resolves a pick the run has already guarded, emits `draft_picked` and changes
## nothing else. A null [param id] is "take nothing", legal only under `allow_skip`.
## An id not in [param current_offer], or a null without `allow_skip`, sets
## `error = E_NOT_OFFERED`; an offered id whose record no longer resolves (a debug
## reload) sets `E_UNKNOWN_ID`. A refused pick emits nothing.
func pick(kind: StringName, id: Variant, current_offer: Offer, run_state: RunState) -> Pick:
	var result: Pick = Pick.new()
	if id == null:
		if not allows_skip():
			result.error = RunCodes.E_NOT_OFFERED
			return result
	else:
		var picked: String = str(id)
		result.option_index = current_offer.option_ids.find(picked)
		if result.option_index < 0:
			result.error = RunCodes.E_NOT_OFFERED
			return result
		if not _db.has(picked):
			result.error = RunCodes.E_UNKNOWN_ID
			return result
		result.picked_id = picked
		if String(kind) == DraftRecord.KIND_BUNDLE:
			result.card_ids_added.assign(_db.bundle(picked).cards)
	_emit(RunCodes.EVENT_DRAFT_PICKED, {
		"floor": run_state.floor,
		"kind": String(kind),
		"picked_id": result.picked_id,
		"option_index": result.option_index,
		"card_ids_added": Array(result.card_ids_added),
	})
	return result


## F1 `bundle_weight` of [param bundle] on [param floor_band] against a deck of
## [param tag_counts] (see [method deck_tag_counts]). Integer arithmetic throughout,
## rounding half up, so the draws never depend on a float.
func bundle_weight(bundle: Dictionary, floor_band: int, tag_counts: Dictionary) -> int:
	var n_tag: int = int(tag_counts.get(bundle.theme, 0))
	var affinity: int = PERCENT + int(_config.affinity_step) * mini(n_tag, int(_config.affinity_cap))
	var band_mult: int = int(_config.band_cost_curve[str(floor_band)][_cost_bucket(bundle)])
	var scale: int = PERCENT * PERCENT
	@warning_ignore("integer_division")
	return maxi(1, (int(_config.base_weight) * affinity * band_mult + scale / 2) / scale)


## F2 `treasure_weight` of [param treasure] for a hero with [param plan_tags].
func treasure_weight(treasure: Dictionary, plan_tags: Array) -> int:
	var rarity_weight: int = int(_config.treasure_rarity_weights[treasure.rarity])
	var boost: int = int(_config.treasure_affinity) if _is_affine(treasure, plan_tags) else 0
	@warning_ignore("integer_division")
	return maxi(1, (rarity_weight * (PERCENT + boost) + PERCENT / 2) / PERCENT)


## F3 `D`: the plan tag with the highest `n_tag`, ties to the earliest in
## [param plan_tags]; `""` when the hero has none.
func dominant_theme(plan_tags: Array, tag_counts: Dictionary) -> String:
	var best: String = ""
	var best_count: int = -1
	for tag: Variant in plan_tags:
		var count: int = int(tag_counts.get(tag, 0))
		if count > best_count:
			best = str(tag)
			best_count = count
	return best


## F3 `starve`: the most recent consecutive bundle drafts of [param run_state] whose
## offered ids held no bundle of [param theme]. Declining the theme resets the count.
func starve_count(run_state: RunState, theme: String) -> int:
	var starve: int = 0
	for i: int in range(run_state.drafts.size() - 1, -1, -1):
		var record: DraftRecord = run_state.drafts[i]
		if record.kind != DraftRecord.KIND_BUNDLE:
			continue
		for id: String in record.offered_ids:
			if _db.has(id) and _db.bundle(id).theme == theme:
				return starve
		starve += 1
	return starve


## `n_tag` for every tag of [param deck]: a card counts once per tag it carries (F1).
func deck_tag_counts(deck: Array) -> Dictionary:
	var counts: Dictionary = {}
	for card_id: Variant in deck:
		if not _db.has(str(card_id)):
			continue
		for tag: Variant in _db.card(str(card_id)).tags:
			counts[tag] = int(counts.get(tag, 0)) + 1
	return counts


## D4-D6 and D8 for bundles: fills `result.flags` and returns the drawn ids.
func _draw_bundles(result: Offer, run_state: RunState, stream: RngStream) -> Array[String]:
	var hero_set: String = str(_db.hero(run_state.hero_id)["set"])
	var taken: Dictionary = {}
	var cooling: Dictionary = {}
	var window: int = int(_config.reoffer_after_floors)
	for record: DraftRecord in run_state.drafts:
		if record.kind != DraftRecord.KIND_BUNDLE:
			continue
		if record.picked_id != null:
			taken[record.picked_id] = true
		if run_state.floor - record.floor <= window:
			for id: String in record.offered_ids:
				if id != record.picked_id:
					cooling[id] = true
	var not_taken: Array[String] = []
	var candidates: Array[String] = []
	for bundle: Dictionary in _db.bundle_pool(hero_set):
		var id: String = bundle.id
		if taken.has(id) or not _bundle_is_sound(bundle):
			continue
		not_taken.append(id)
		if not cooling.has(id):
			candidates.append(id)
	var wanted: int = int(_config.bundle_offers_per_draft)
	if candidates.size() < wanted and not_taken.size() > candidates.size():
		candidates = not_taken
		result.flags.append(Offer.FLAG_REOFFER)
	if candidates.size() < wanted:
		result.flags.append(Offer.FLAG_SHORT)
		RunCodes.warn(_log, RunCodes.W_BUNDLE_POOL_SHORT, {"floor": run_state.floor, "needed": wanted, "available": candidates.size()})
	if candidates.is_empty():
		return []
	var tag_counts: Dictionary = deck_tag_counts(run_state.deck)
	var plan_tags: Array = _heroes.plan_tags(run_state.hero_id)
	var theme: String = dominant_theme(plan_tags, tag_counts)
	var pity_due: bool = not theme.is_empty() and starve_count(run_state, theme) >= int(_config.pity_window)
	var weights: Dictionary = {}
	var floor_band: int = run_state.band(run_state.floor)
	for id: String in candidates:
		weights[id] = bundle_weight(_db.bundle(id), floor_band, tag_counts)
	var slots: int = mini(wanted, candidates.size())
	var remaining: Array[String] = candidates.duplicate()
	var drawn: Array[String] = []
	for slot: int in range(slots):
		var eligible: Array[String] = remaining
		if slot == 0 and pity_due:
			var on_theme: Array[String] = _of_theme(remaining, theme, true)
			if not on_theme.is_empty():
				eligible = on_theme
				result.flags.append(Offer.FLAG_PITY_FORCED)
		elif slot > 0 and slot == slots - 1 and slots == wanted and _share_theme(drawn):
			var off_theme: Array[String] = _of_theme(remaining, _db.bundle(drawn[0]).theme, false)
			if not off_theme.is_empty():
				eligible = off_theme
				result.flags.append(Offer.FLAG_COVERAGE_FORCED)
		var id: String = _draw_one(eligible, weights, stream)
		if id.is_empty():
			return _draft_fault(result)
		drawn.append(id)
		remaining.erase(id)
	return drawn


## D7, D8 for treasures: fills `result.flags` and returns the drawn ids. A held
## treasure is never offered, under any policy.
func _draw_treasures(result: Offer, run_state: RunState, stream: RngStream) -> Array[String]:
	var seen: Dictionary = {}
	for id: String in run_state.treasures:
		seen[id] = true
	var refill: Array[String] = []
	for record: DraftRecord in run_state.drafts:
		if record.kind != DraftRecord.KIND_TREASURE:
			continue
		for id: String in record.offered_ids:
			if not seen.has(id):
				seen[id] = true
				refill.append(id)
	var candidates: Array[String] = []
	for id: Variant in run_state.draft_state.get("treasure_pool", []):
		if not seen.has(id):
			candidates.append(str(id))
	var wanted: int = int(_config.treasure_offers_per_draft)
	var reoffering: bool = str(_config.treasure_short_policy) == POLICY_REOFFER and not refill.is_empty()
	if candidates.size() < wanted:
		if reoffering and not candidates.is_empty():
			result.flags.append(Offer.FLAG_REOFFER)
		if not reoffering or candidates.size() + refill.size() < wanted or candidates.is_empty():
			result.flags.append(Offer.FLAG_SHORT)
			RunCodes.warn(_log, RunCodes.W_TREASURE_POOL_SHORT, {"floor": run_state.floor, "needed": wanted, "available": candidates.size()})
	if candidates.is_empty():
		return []
	var plan_tags: Array = _heroes.plan_tags(run_state.hero_id)
	var weights: Dictionary = {}
	for id: String in candidates + refill:
		weights[id] = treasure_weight(_db.treasure(id), plan_tags)
	var remaining: Array[String] = candidates.duplicate()
	var drawn: Array[String] = []
	for slot: int in range(mini(wanted, candidates.size())):
		var eligible: Array[String] = remaining
		if slot == 0 and bool(_config.universal_slot):
			var universal: Array[String] = _universal_among(remaining)
			if universal.is_empty():
				result.flags.append(Offer.FLAG_UNIVERSAL_MISSING)
			else:
				eligible = universal
				result.flags.append(Offer.FLAG_UNIVERSAL_FORCED)
		var id: String = _draw_one(eligible, weights, stream)
		if id.is_empty():
			return _draft_fault(result)
		drawn.append(id)
		remaining.erase(id)
	if reoffering:
		var spare: Array[String] = refill.duplicate()
		while drawn.size() < wanted and not spare.is_empty():
			var id: String = _draw_one(spare, weights, stream)
			if id.is_empty():
				return _draft_fault(result)
			drawn.append(id)
			spare.erase(id)
	return drawn


## One `weighted_pick` over [param ids]: one draw. `""` when the stream refused the
## weights, which F1/F2 make impossible.
func _draw_one(ids: Array[String], weights: Dictionary, stream: RngStream) -> String:
	var row: Array = []
	for id: String in ids:
		row.append(weights[id])
	var index: int = stream.weighted_pick(row)
	return ids[index] if index >= 0 else ""


## Edge Cases "weighted_pick returns -1": a logged empty draft, never a silent pick.
func _draft_fault(result: Offer) -> Array[String]:
	RunCodes.warn(_log, RunCodes.W_DRAFT_FAULT, {"floor": result.floor, "kind": result.kind})
	return []


## The D6 step 3 test: every id drawn so far has one theme.
func _share_theme(ids: Array[String]) -> bool:
	for id: String in ids:
		if _db.bundle(id).theme != _db.bundle(ids[0]).theme:
			return false
	return true


func _of_theme(ids: Array[String], theme: String, wanted: bool) -> Array[String]:
	var kept: Array[String] = []
	for id: String in ids:
		if (_db.bundle(id).theme == theme) == wanted:
			kept.append(id)
	return kept


func _universal_among(ids: Array[String]) -> Array[String]:
	var kept: Array[String] = []
	for id: String in ids:
		if Array(_db.treasure(id).tags).has(UNIVERSAL_TAG):
			kept.append(id)
	return kept


## Edge Cases: a bundle broken by a debug reload is left out, with a warning. Card
## Database refuses one at load, so this never fires on shipped data.
func _bundle_is_sound(bundle: Dictionary) -> bool:
	var cards: Array = bundle.cards
	var sound: bool = cards.size() == int(RecordSchemas.BUNDLE_FIELDS.cards["count"])
	for card_id: Variant in cards:
		sound = sound and _db.has(str(card_id)) and not bool(_db.card(str(card_id)).get("token", false))
	if not sound:
		RunCodes.warn(_log, RunCodes.W_BUNDLE_INVALID, {"bundle_id": bundle.id})
	return sound


## F1 `cost_bucket`: `avg_cost < cost_low` is low, `> cost_high` high, else mid.
func _cost_bucket(bundle: Dictionary) -> int:
	var cards: Array = bundle.cards
	var total: int = 0
	for card_id: Variant in cards:
		total += int(_db.card(str(card_id)).cost)
	var average: float = float(total) / float(cards.size())
	if average < float(_config.cost_low):
		return BUCKET_LOW
	return BUCKET_HIGH if average > float(_config.cost_high) else BUCKET_MID


## F2 `affine`: a tag of the treasure is a plan tag of the hero.
func _is_affine(treasure: Dictionary, plan_tags: Array) -> bool:
	for tag: Variant in treasure.tags:
		if plan_tags.has(tag):
			return true
	return false


## The per-option read model: the numbers Run UI's hint shows, never a weight.
func _option_rows(result: Offer, run_state: RunState) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var tag_counts: Dictionary = deck_tag_counts(run_state.deck)
	var plan_tags: Array = _heroes.plan_tags(run_state.hero_id)
	for id: String in result.option_ids:
		if result.kind == DraftRecord.KIND_BUNDLE:
			var theme: String = _db.bundle(id).theme
			rows.append({"id": id, "theme": theme, "n_tag": int(tag_counts.get(theme, 0))})
		else:
			rows.append({"id": id, "affine": 1 if _is_affine(_db.treasure(id), plan_tags) else 0})
	return rows


func _emit(type: StringName, payload: Dictionary) -> void:
	if _log != null:
		@warning_ignore("return_value_discarded")
		_log.append(type, payload)
