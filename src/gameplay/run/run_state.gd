## The in-memory run (run-structure R1). `RunMachine` is the only writer; Reward
## Draft and the read model only read it. `run_seed` is the one field with no JSON
## form: it lives here as an int and is persisted as `run_seed_hex` alone.
##
## `draft_state` and `treasure_state` are opaque here, by R1: their owners read and
## write them. [method validate] and [method read_model] are the two ways out:
## the first is `RunRecord.validate` over this state, and the second is the plain
## Dictionary Run UI renders. Screens never hold a `RunState` (ADR-0011).
## [codeblock]
## var band: int = state.band(state.floor)
## var model: Dictionary = state.read_model(db, db.config("run_structure"))
## if state.validate(db) != OK: push_error("run state broke an R1 invariant")
## [/codeblock]
class_name RunState
extends RefCounted

## R1 `status`, in lifecycle order.
const STATUS_HERO_SELECT: String = "hero_select"
const STATUS_PRE_MATCH: String = "pre_match"
const STATUS_IN_MATCH: String = "in_match"
const STATUS_POST_MATCH_REWARD: String = "post_match_reward"
const STATUS_VICTORY: String = "victory"
const STATUS_DEFEAT: String = "defeat"
const STATUS_ABANDONED: String = "abandoned"
const STATUSES: Array[String] = [
	STATUS_HERO_SELECT, STATUS_PRE_MATCH, STATUS_IN_MATCH, STATUS_POST_MATCH_REWARD,
	STATUS_VICTORY, STATUS_DEFEAT, STATUS_ABANDONED,
]
const TERMINAL_STATUSES: Array[String] = [STATUS_VICTORY, STATUS_DEFEAT, STATUS_ABANDONED]
## R1 `seed_source`.
const SEED_RANDOM: String = "random"
const SEED_CUSTOM: String = "custom"
## R1 `result.abandon_reason`.
const REASON_PLAYER: String = "player"
const REASON_DATA_VERSION_MISMATCH: String = "data_version_mismatch"
const REASON_SAVE_CORRUPT: String = "save_corrupt"
## Progress strip pip states (run-structure UI Requirements).
const PIP_CLEARED: String = "cleared"
const PIP_CURRENT: String = "current"
const PIP_UPCOMING: String = "upcoming"

var schema_version: int = RunRecord.SCHEMA_VERSION
var data_version: String = ""
var engine_version: String = ""
var run_id: String = ""
## In memory only; the persisted form is [member run_seed_hex].
var run_seed: int = 0
var run_seed_hex: String = ""
var seed_source: String = SEED_RANDOM
var hero_id: String = ""
var floors_per_run: int = 0
var band_split: Array[int] = []
var treasure_floors: Array[int] = []
var boss_sequence: Array[String] = []
var floor: int = 1
var status: String = STATUS_PRE_MATCH
## [constant DraftRecord.KIND_TREASURE], [constant DraftRecord.KIND_BUNDLE] or null.
var reward_step: Variant = null
var deck: Array[String] = []
var treasures: Array[String] = []
var drafts: Array[DraftRecord] = []
## `{"<floor>": attempts}`: String keys, the only kind JSON has.
var match_attempts: Dictionary = {}
var match_summaries: Array[Dictionary] = []
var draft_state: Dictionary = {}
var treasure_state: Dictionary = {}
var rng_snapshot: Dictionary = {}
var run_log: Dictionary = {}
var started_at: int = 0
var updated_at: int = 0
## Null until the run ends.
var ended_at: Variant = null
var play_seconds: int = 0
## Null until the run ends (R1 `result`).
var result: Variant = null
## Empty until the run ends (R10 `totals`).
var totals: Dictionary = {}


## F1 `band(f)` for [param split]: 1, 2, or 3; 1 for the split of a damaged save,
## which reaches here only on its way to the summary.
static func band_of(floor_number: int, split: Array) -> int:
	if split.size() < RunRecord.BAND_COUNT:
		return 1
	if floor_number <= int(split[0]):
		return 1
	if floor_number <= int(split[0]) + int(split[1]):
		return 2
	return 3


## F1 `first_floor_of_band(b)` for [param split]: 1, s1 + 1, s1 + s2 + 1.
static func first_floor_of_band(band_number: int, split: Array) -> int:
	match band_number:
		1:
			return 1
		2:
			return int(split[0]) + 1
	return int(split[0]) + int(split[1]) + 1


## F3 `boss_health(f)` of [param boss_def] with the [param bonus] `floor_health_bonus`.
static func boss_health_at(boss_def: Dictionary, floor_number: int, split: Array, bonus: int) -> int:
	return int(boss_def.health) + bonus * (floor_number - first_floor_of_band(band_of(floor_number, split), split))


## F1 for this run's saved layout.
func band(floor_number: int) -> int:
	return band_of(floor_number, band_split)


## The treasure floors this run drafts on: a floor at or past the last is ignored
## (R5.1, Edge Cases).
func effective_treasure_floors() -> Array[int]:
	var floors: Array[int] = []
	for f: int in treasure_floors:
		if f < floors_per_run:
			floors.append(f)
	return floors


## True when a win on [param floor_number] drafts a treasure first (R5.1).
func is_treasure_floor(floor_number: int) -> bool:
	return effective_treasure_floors().has(floor_number)


## True when a `(floor, kind)` step is already in `drafts[]` (R8.5).
func has_draft(floor_number: int, kind: String) -> bool:
	for record: DraftRecord in drafts:
		if record.floor == floor_number and record.kind == kind:
			return true
	return false


## R1 `n_<kind>_picks`: the records of [param kind] whose `picked_id` is non-null.
func n_picks(kind: String) -> int:
	var picks: int = 0
	for record: DraftRecord in drafts:
		if record.kind == kind and record.picked_id != null:
			picks += 1
	return picks


## `match_attempts[f]`, 0 before the first `begin_match` on it.
func attempts_on(floor_number: int) -> int:
	return int(match_attempts.get(str(floor_number), 0))


## True in `victory`, `defeat` and `abandoned`.
func is_terminal() -> bool:
	return TERMINAL_STATUSES.has(status)


## R10 `totals` from the summaries so far.
func compute_totals() -> Dictionary:
	var turns: int = 0
	var damage_by_card: Dictionary = {}
	for summary: Dictionary in match_summaries:
		turns += int(summary.get("turns", 0))
		var damage: Variant = summary.get("damage_by_card", {})
		if not damage is Dictionary:
			continue
		for card_id: Variant in damage:
			damage_by_card[card_id] = int(damage_by_card.get(card_id, 0)) + int(damage[card_id])
	var cards_drafted: int = 0
	for record: DraftRecord in drafts:
		if record.kind == DraftRecord.KIND_BUNDLE:
			cards_drafted += record.card_ids_added.size()
	return {
		"matches_played": match_summaries.size(),
		"turns": turns,
		"damage_by_card": damage_by_card,
		"cards_drafted": cards_drafted,
		"treasures_taken": treasures.size(),
		"play_seconds": play_seconds,
	}


## `RunRecord.validate` over this state: `OK` or a `RunCodes` code. [param db] is
## the database the record must match.
func validate(db: CardDatabase) -> Error:
	return RunRecord.validate(RunRecord.to_dict(self), db)


## The Dictionary Run UI renders (run-structure UI Requirements; ADR-0011). Plain
## values only; every list is a copy. [param config] is `config("run_structure")`.
## Upcoming bosses stay hidden: `bosses_seen` stops at the current floor and the
## progress strip gives upcoming floors their band only.
## - always: identity, `status`, `reward_step`, `floor`, `floors_per_run`, `band`,
##   `hero`, `deck`, `deck_entries`, `treasures`, `drafts`, `match_summaries`,
##   `attempt`, `floors` (the strip), `bosses_seen`, times;
## - before a terminal status: `boss`, the current floor's intro data;
## - in a terminal status: `summary`.
func read_model(db: CardDatabase, config: Dictionary) -> Dictionary:
	var draft_rows: Array[Dictionary] = []
	for record: DraftRecord in drafts:
		draft_rows.append(record.to_dict())
	var model: Dictionary = {
		"run_id": run_id,
		"run_seed_hex": run_seed_hex,
		"seed_source": seed_source,
		"status": status,
		"reward_step": reward_step,
		"floor": floor,
		"floors_per_run": floors_per_run,
		"band": band(floor),
		"hero": _hero_model(db),
		"deck": Array(deck),
		"deck_size": deck.size(),
		"deck_entries": _deck_entries(),
		"treasures": Array(treasures),
		"drafts": draft_rows,
		"match_summaries": Array(match_summaries).duplicate(true),
		"attempt": attempts_on(floor),
		"floors": _progress_strip(),
		"bosses_seen": Array(boss_sequence.slice(0, floor)),
		"started_at": started_at,
		"updated_at": updated_at,
		"ended_at": ended_at,
		"play_seconds": play_seconds,
	}
	if is_terminal():
		model["summary"] = _summary_model(db, config)
	else:
		model["boss"] = _boss_model(db, config)
	return model


func _hero_model(db: CardDatabase) -> Dictionary:
	for hero: Dictionary in db.heroes():
		if hero.id == hero_id:
			return {"id": hero_id, "name": hero.name, "set": hero["set"], "health": hero.health, "hero_power": hero.hero_power}
	return {"id": hero_id}


## The boss of the current floor as the intro shows it. `hero_power`,
## `passive_text` and `intro_text` are the record's own; absent ones are null.
func _boss_model(db: CardDatabase, config: Dictionary) -> Dictionary:
	if floor < 1 or floor > boss_sequence.size() or not db.has(boss_sequence[floor - 1]):
		return {}
	var boss_id: String = boss_sequence[floor - 1]
	var boss_def: Dictionary = db.boss(boss_id)
	return {
		"id": boss_id,
		"name": boss_def.name,
		"band": band(floor),
		"health": boss_health_at(boss_def, floor, band_split, int(config.get("floor_health_bonus", 0))),
		"hero_power": boss_def.get("hero_power"),
		"passive_text": boss_def.get("passive_text"),
		"intro_text": boss_def.get("intro_text"),
	}


## One pip per floor: a floor is cleared once its match is won, which on the
## current floor means the reward phase or a victory.
func _progress_strip() -> Array[Dictionary]:
	var cleared_through: int = floor - 1
	if status == STATUS_POST_MATCH_REWARD or status == STATUS_VICTORY:
		cleared_through = floor
	var pips: Array[Dictionary] = []
	for f: int in range(1, floors_per_run + 1):
		var pip: String = PIP_UPCOMING
		if f <= cleared_through:
			pip = PIP_CLEARED
		elif f == floor:
			pip = PIP_CURRENT
		pips.append({"floor": f, "band": band(f), "state": pip})
	return pips


## The deck in acquisition order, each entry with the floor it was drafted after,
## null for a starter card, so the summary can mark drafted cards.
func _deck_entries() -> Array[Dictionary]:
	var drafted_on: Array = []
	for record: DraftRecord in drafts:
		for _card_id: String in record.card_ids_added:
			drafted_on.append(record.floor)
	var starter_size: int = deck.size() - drafted_on.size()
	var entries: Array[Dictionary] = []
	for i: int in range(deck.size()):
		entries.append({"card_id": deck[i], "drafted_on": null if i < starter_size else drafted_on[i - starter_size]})
	return entries


## The R10 summary screen data. `top_cards` holds the `summary_top_cards` highest
## damage dealers, ties by id; `more_cards` is how many that leaves out; `no_damage`
## is true for an empty table (Edge Cases).
func _summary_model(db: CardDatabase, config: Dictionary) -> Dictionary:
	var outcome: Dictionary = result if result is Dictionary else {}
	var damage: Dictionary = totals.get("damage_by_card", {})
	var rows: Array[Dictionary] = []
	for card_id: Variant in damage:
		rows.append({"card_id": str(card_id), "damage": int(damage[card_id])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.damage > b.damage or (a.damage == b.damage and a.card_id < b.card_id))
	var top: int = int(config.get("summary_top_cards", rows.size()))
	var retried: Array[int] = []
	for key: Variant in match_attempts:
		if int(match_attempts[key]) > 1:
			retried.append(int(str(key)))
	retried.sort()
	var ended_by: Variant = outcome.get("ended_by")
	return {
		"outcome": outcome.get("outcome"),
		"floors_cleared": outcome.get("floors_cleared", 0),
		"floor_reached": outcome.get("floor_reached", 0),
		"total_turns": outcome.get("total_turns", 0),
		"abandon_reason": outcome.get("abandon_reason"),
		"ended_by": ended_by,
		"ended_by_name": db.boss(ended_by).name if ended_by is String and db.has(ended_by) else null,
		"matches_played": totals.get("matches_played", 0),
		"play_seconds": play_seconds,
		"cards_drafted": totals.get("cards_drafted", 0),
		"treasures_taken": totals.get("treasures_taken", 0),
		"top_cards": rows.slice(0, top),
		"more_cards": maxi(rows.size() - top, 0),
		"no_damage": rows.is_empty(),
		"retried_floors": retried,
	}
