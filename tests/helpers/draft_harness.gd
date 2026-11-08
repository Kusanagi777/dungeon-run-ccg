## The Reward Draft Acceptance Criteria fixtures (design/gdd/reward-draft.md AC preamble)
## over the shipped data: **P20** is the original War pool, 8 `war` plus 12 neutral bundles;
## **P14** keeps the 8 `war` and the neutrals of the first three themes; **T10** is the
## GDD's synthetic treasure set; [method real_pool] is the 20 shipped treasures. The War
## starter, the bundles and the cards are the real records.
##
## [method simulate] is the AC-9 / AC-29 run: one bundle draft per floor from a real
## `RewardDraft`, picked by a policy, the run's own bookkeeping done here. "Seeds 1..N"
## are `run_seed` values through the real `draft_<floor>` stream seed (rng-event-log F2).
## [codeblock]
## var fix := DraftHarness.new(TreasureFixtures.shipped_database())
## var draft: RewardDraft = fix.draft({"reoffer_after_floors": 3})
## var run: DraftHarness.SimResult = fix.simulate(draft, 7, DraftHarness.POLICY_FIRST)
## [/codeblock]
class_name DraftHarness
extends RefCounted

const HERO_ID: String = "hero_war"
const DATA_VERSION: String = "test"
const POLICY_FIRST: StringName = &"first"
const POLICY_LAST: StringName = &"last"
const POLICY_RANDOM: StringName = &"random"
const POLICY_FOLLOWER: StringName = &"follower"
const NEUTRAL_SET: String = "neutral"
const P20_THEMES: Array[String] = ["aggro", "armour", "weapons", "big", "pings", "tempo", "tricks", "value", "wall"]
## How many neutral themes P14 keeps.
const P14_THEMES: int = 3
## The last floor with a draft, on the default layout.
const LAST_DRAFT_FLOOR: int = 7
## F2's example: 7 universal with no War plan tag, 3 War-affine.
const T10_UNIVERSAL_COMMON: int = 4
const T10_UNIVERSAL_RARE: int = 3
const T10_WAR_COMMON: int = 2
const T10_WAR_RARE: int = 1


## A database that is the shipped one, with a pool and records laid over it.
class PoolDb:
	extends CardDatabase

	var base: CardDatabase
	## Replaces `bundle_pool`, when set.
	var bundles: Array = []
	## Records by id, found before the base's.
	var extra: Dictionary = {}
	## Replaces `treasure_pool`, when set.
	var treasures: Array = []

	func _init(database: CardDatabase) -> void:
		base = database

	func has(id: String) -> bool:
		return extra.has(id) or base.has(id)

	func card(id: String) -> Variant:
		return extra[id] if extra.has(id) else base.card(id)

	func any_record(id: String) -> Variant:
		return extra[id] if extra.has(id) else base.any_record(id)

	func treasure(id: String) -> Variant:
		return extra[id] if extra.has(id) else base.treasure(id)

	func bundle(id: String) -> Variant:
		return extra[id] if extra.has(id) else base.bundle(id)

	func hero(id: String) -> Variant:
		return base.hero(id)

	func hero_power(id: String) -> Variant:
		return base.hero_power(id)

	func boss(id: String) -> Variant:
		return base.boss(id)

	func heroes() -> Array:
		return base.heroes()

	func bosses_in_band(band: int, collection_id: String = "") -> Array:
		return base.bosses_in_band(band, collection_id)

	func bundle_pool(hero_set: String, collection_id: String = "") -> Array:
		return bundles if not bundles.is_empty() else base.bundle_pool(hero_set, collection_id)

	func treasure_pool(collection_id: String = "") -> Array:
		return treasures if not treasures.is_empty() else base.treasure_pool(collection_id)

	func collectible_pool(hero_set: String, collection_id: String = "") -> Array:
		return base.collectible_pool(hero_set, collection_id)

	func cards_by_set(set_id: String) -> Array:
		return base.cards_by_set(set_id)

	func cards_by_type(type: String) -> Array:
		return base.cards_by_type(type)

	func cards_by_tag(tag: String) -> Array:
		return base.cards_by_tag(tag)

	func cards_by_cost(cost: int) -> Array:
		return base.cards_by_cost(cost)

	func cards_by_rarity(rarity: String) -> Array:
		return base.cards_by_rarity(rarity)

	func config(config_name: String) -> Variant:
		return base.config(config_name)

	func data_version() -> String:
		return base.data_version()


## A Meta whose unlocked keys a test sets.
class KeysMeta:
	extends MetaStub

	var keys: Array = []

	func unlocked_keys() -> Array:
		return keys.duplicate()


## A stream whose `randi_range` answers the top of its range: AC-22's `total - 1`.
class TopStream:
	extends RngStream

	func randi_range(_lo: int, hi: int) -> int:
		draws += 1
		return hi


## A seeded stream that keeps the index every `weighted_pick` answered (AC-18).
class RecordingStream:
	extends RngStream

	var indices: Array[int] = []

	func weighted_pick(weights: Array) -> int:
		var index: int = super(weights)
		indices.append(index)
		return index


## One simulated run.
class SimResult:
	extends RefCounted

	var state: RunState
	## The `Offer` of each drafted floor, oldest first.
	var offers: Array[Offer] = []
	## The eligible count of each floor before its draw, by D4.
	var eligible: Array[int] = []

	func flagged(flag: StringName) -> bool:
		return offers.any(func(offer: Offer) -> bool: return offer.flags.has(flag))


var db: CardDatabase
var meta: KeysMeta
var _config: Dictionary


func _init(database: CardDatabase) -> void:
	db = database
	meta = KeysMeta.new(db)
	_config = (db.config("reward_draft") as Dictionary).duplicate(true)


## The `reward_draft` body with [param overrides] on top.
func config(overrides: Dictionary = {}) -> Dictionary:
	var body: Dictionary = _config.duplicate(true)
	body.merge(overrides, true)
	return body


## A real `RewardDraft` over [param database], [member db] by default.
func draft(overrides: Dictionary = {}, database: CardDatabase = null) -> RewardDraft:
	var over: CardDatabase = database if database != null else db
	var treasures: Treasures = Treasures.new(over, over.config("treasures_balance"))
	return RewardDraft.new(over, treasures, meta, config(overrides))


## The original 20-bundle War pool, id-sorted, for the fixed-size AC tests.
func p20() -> Array:
	return db.bundle_pool("war").filter(func(bundle: Dictionary) -> bool: return P20_THEMES.has(str(bundle.theme)))


## [method p20] with its neutrals cut to the first [constant P14_THEMES] themes.
func p14() -> Array:
	var themes: Array = []
	var kept: Array = []
	for bundle: Dictionary in p20():
		if bundle["set"] != NEUTRAL_SET:
			kept.append(bundle)
			continue
		if not themes.has(bundle.theme) and themes.size() < P14_THEMES:
			themes.append(bundle.theme)
		if themes.has(bundle.theme):
			kept.append(bundle)
	return kept


## A [PoolDb] whose bundle pool is [param bundles].
func pool_db(bundles: Array) -> PoolDb:
	var over := PoolDb.new(db)
	over.bundles = bundles
	return over


## The T10 records, by F2's example, in id order, as TreasureDefs.
static func t10() -> Array:
	var records: Array = []
	for i: int in T10_UNIVERSAL_COMMON + T10_UNIVERSAL_RARE:
		records.append(_treasure("t10_u%d" % i, "common" if i < T10_UNIVERSAL_COMMON else "rare", ["universal", "economy"]))
	for i: int in T10_WAR_COMMON + T10_WAR_RARE:
		records.append(_treasure("t10_w%d" % i, "common" if i < T10_WAR_COMMON else "rare", ["war", "weapons"]))
	return records


## A [PoolDb] over [method t10].
func t10_db() -> PoolDb:
	var over := PoolDb.new(db)
	for record: Dictionary in t10():
		over.extra[record.id] = record
	over.treasures = t10()
	return over


## The ids of [param records].
static func ids_of(records: Array) -> Array:
	return records.map(func(record: Dictionary) -> String: return record.id)


## The shipped treasure ids, id-sorted.
func real_pool() -> Array:
	return ids_of(db.treasure_pool())


## A `RunState` of War on [param floor_number] with the starter deck.
func state(floor_number: int = 1, treasure_pool: Array = [], floors_per_run: int = TestConstants.FLOORS_PER_RUN) -> RunState:
	var run_state := RunState.new()
	run_state.hero_id = HERO_ID
	run_state.floors_per_run = floors_per_run
	run_state.band_split.assign(TestConstants.BAND_SPLIT if floors_per_run == TestConstants.FLOORS_PER_RUN else [2, 1, 1])
	run_state.treasure_floors.assign(TestConstants.TREASURE_FLOORS)
	run_state.floor = floor_number
	run_state.status = RunState.STATUS_POST_MATCH_REWARD
	run_state.deck.assign(db.hero(HERO_ID).starter_deck)
	run_state.draft_state = {"schema_version": 1, "treasure_pool": treasure_pool.duplicate()}
	return run_state


## The `draft_<floor>` stream of [param run_seed].
static func stream(run_seed: int, floor_number: int) -> RngStream:
	var name: String = "draft_%d" % floor_number
	return RngStream.new(name, RngService.stream_seed_for(run_seed, name))


## Takes [param id] on [param run_state] as R5 does, cards of [param over] and all.
func take_bundle(run_state: RunState, offered: Array, id: Variant, floor_number: int, over: CardDatabase = null) -> void:
	var source: CardDatabase = over if over != null else db
	var cards: Array = source.bundle(str(id)).cards if id != null else []
	run_state.drafts.append(DraftRecord.make(floor_number, DraftRecord.KIND_BUNDLE, offered, id, cards))
	run_state.deck.append_array(cards)


## The eligible count before the draw on [param run_state]'s floor (D4).
func eligible_count(run_state: RunState, pool: Array, window: int) -> int:
	var excluded: Dictionary = {}
	for record: DraftRecord in run_state.drafts:
		if record.picked_id != null:
			excluded[record.picked_id] = true
		if run_state.floor - record.floor <= window:
			for id: String in record.offered_ids:
				excluded[id] = true
	return ids_of(pool).filter(func(id: String) -> bool: return not excluded.has(id)).size()


## A run of one bundle draft per floor through [param last_floor] under [param policy].
## [param pool] feeds [member SimResult.eligible].
func simulate(using: RewardDraft, run_seed: int, policy: StringName, over: CardDatabase = null, last_floor: int = LAST_DRAFT_FLOOR, pool: Array = [], window: int = 0) -> SimResult:
	var result := SimResult.new()
	var run_state: RunState = state()
	result.state = run_state
	for f: int in range(1, last_floor + 1):
		run_state.floor = f
		result.eligible.append(eligible_count(run_state, pool, window))
		var from: RngStream = stream(run_seed, f)
		var offer: Offer = using.offer(&"bundle", run_state, from)
		result.offers.append(offer)
		if offer.option_ids.is_empty():
			take_bundle(run_state, [], null, f, over)
			continue
		take_bundle(run_state, offer.option_ids, _choose(offer, policy, from), f, over)
	return result


func _choose(offer: Offer, policy: StringName, from: RngStream) -> String:
	match policy:
		POLICY_LAST:
			return offer.option_ids.back()
		POLICY_RANDOM:
			return offer.option_ids[from.randi_range(0, offer.option_ids.size() - 1)]
		POLICY_FOLLOWER:
			var best: Dictionary = offer.per_option[0]
			for row: Dictionary in offer.per_option:
				if int(row.n_tag) > int(best.n_tag):
					best = row
			return best.id
	return offer.option_ids[0]


static func _treasure(id: String, rarity: String, tags: Array) -> Dictionary:
	return {"id": id, "rarity": rarity, "tags": tags, "unlock": null, "effects": [], "text": {"en": id}}
