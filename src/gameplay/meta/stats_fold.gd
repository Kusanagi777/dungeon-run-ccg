## The lifetime statistics fold (design/gdd/meta-progression.md M7, F2, F3): pure
## functions over the `stats` Dictionary and a RunRecord. Reads no file and no clock.
##
## [codeblock]
## var fold := StatsFold.new(run_structure_config.abandon_counts_as_loss)
## fold.fold(profile.stats, record)
## StatsFold.floor_reached(record)   # 8 on an 8-floor victory
## [/codeblock]
class_name StatsFold
extends RefCounted

const OUTCOME_VICTORY: String = "victory"
const OUTCOME_DEFEAT: String = "defeat"
const OUTCOME_ABANDONED: String = "abandoned"
const REASON_PLAYER: String = "player"
const KIND_TREASURE: String = "treasure"
## What `match_summary` carries for the player's win: rng-event-log `result: win`
## with `winner: PLAYER`; F2 writes it `m.result == player`.
const MATCH_WIN_RESULTS: Array[String] = ["win", "player"]
const MATCH_WINNER_PLAYER: String = "player"
## Bests are kept from the rebuild, never maxed with the old value (M7.5).
const BEST_KEYS: Array[String] = ["fastest_victory_s", "fewest_turns_victory"]

var _abandon_counts_as_loss: bool


## [param abandon_counts_as_loss] is Run Structure's knob, read from
## `run_structure.json` by the composition root (M7.2).
func _init(abandon_counts_as_loss: bool) -> void:
	_abandon_counts_as_loss = abandon_counts_as_loss


## F3: the floor a [param record] counts for. `floors_per_run` on victory, else
## `result.floor_reached`, else `floors_cleared + 1` for an older record.
## Example: `StatsFold.floor_reached({"floors_per_run": 8, "result": {"outcome": "victory"}})`.
static func floor_reached(record: Dictionary) -> int:
	var result: Dictionary = _result_of(record)
	if result.get("outcome") == OUTCOME_VICTORY:
		return int(record.get("floors_per_run", result.get("floor_reached", 1)))
	if result.get("floor_reached") != null:
		return int(result.floor_reached)
	return int(result.get("floors_cleared", 0)) + 1


## True when [param record] folds as void: a system abandon, or a player abandon
## while `abandon_counts_as_loss` is off. A void run cannot grant (M3.5).
## Example: `if fold.is_void(record): return []`.
func is_void(record: Dictionary) -> bool:
	var result: Dictionary = _result_of(record)
	if result.get("outcome") != OUTCOME_ABANDONED:
		return false
	return not (result.get("abandon_reason") == REASON_PLAYER and _abandon_counts_as_loss)


## F2: folds [param record] into [param stats] in place.
## Example: `fold.fold(profile.stats, record)`.
func fold(stats: Dictionary, record: Dictionary) -> void:
	var result: Dictionary = _result_of(record)
	var outcome: Variant = result.get("outcome")
	var hero: Dictionary = _hero(stats, str(record.get("hero_id", "")))
	stats["runs_started"] = int(stats.runs_started) + 1
	hero["runs_started"] = int(hero.runs_started) + 1
	hero["last_played_at"] = record.get("ended_at")
	if is_void(record):
		stats["runs_void"] = int(stats.runs_void) + 1
		return
	if outcome == OUTCOME_VICTORY:
		stats["runs_won"] = int(stats.runs_won) + 1
		hero["runs_won"] = int(hero.runs_won) + 1
	else:
		stats["runs_lost"] = int(stats.runs_lost) + 1
		hero["runs_lost"] = int(hero.runs_lost) + 1
	var totals: Dictionary = record.get("totals", {}) if record.get("totals") is Dictionary else {}
	var turns: int = int(totals.get("turns", 0))
	var play_seconds: int = int(record.get("play_seconds", 0))
	stats["total_turns"] = int(stats.total_turns) + turns
	stats["total_play_seconds"] = int(stats.total_play_seconds) + play_seconds
	hero["best_floor_reached"] = maxi(int(hero.best_floor_reached), floor_reached(record))
	_fold_bosses(stats, record, result)
	_fold_treasures(stats, record)
	if outcome == OUTCOME_VICTORY and record.get("seed_source") == "random":
		for bests: Dictionary in [hero, stats.bests]:
			bests["fastest_victory_s"] = _lower(bests.get("fastest_victory_s"), play_seconds)
			bests["fewest_turns_victory"] = _lower(bests.get("fewest_turns_victory"), turns)


## M7.5: every counter refolded from [param run_log]. The log is capped, so the
## result keeps `max(old, rebuilt)` for monotone counters and the rebuilt value for
## bests. An entry newer than this build is opaque and skipped (M4.4).
## Example: `profile["stats"] = fold.rebuilt(profile.run_log, profile.stats)`.
func rebuilt(run_log: Array, old_stats: Dictionary) -> Dictionary:
	var fresh: Dictionary = ProfileSchema.empty_stats()
	for entry: Dictionary in run_log:
		if int(entry.get("schema_version", 0)) <= ProfileMigrations.RUN_RECORD_SCHEMA_VERSION:
			fold(fresh, entry)
	_keep_monotone(fresh, old_stats)
	return fresh


func _fold_bosses(stats: Dictionary, record: Dictionary, result: Dictionary) -> void:
	for summary: Variant in record.get("match_summaries", []):
		if summary is Dictionary and _player_won(summary):
			var boss: Dictionary = _counter(stats.bosses, str(summary.get("boss_id", "")), ["defeated", "defeated_by"])
			boss["defeated"] = int(boss.defeated) + 1
	if result.get("ended_by") != null:
		var ended_by: Dictionary = _counter(stats.bosses, str(result.ended_by), ["defeated", "defeated_by"])
		ended_by["defeated_by"] = int(ended_by.defeated_by) + 1


## A draft skipped on an empty offer has a null `picked_id` (R5.7): nothing picked.
func _fold_treasures(stats: Dictionary, record: Dictionary) -> void:
	for draft: Variant in record.get("drafts", []):
		if not draft is Dictionary or draft.get("kind") != KIND_TREASURE:
			continue
		if draft.get("picked_id") != null:
			var picked: Dictionary = _counter(stats.treasures, str(draft.picked_id), ["picked", "offered"])
			picked["picked"] = int(picked.picked) + 1
		for offered_id: Variant in draft.get("offered_ids", []):
			var offered: Dictionary = _counter(stats.treasures, str(offered_id), ["picked", "offered"])
			offered["offered"] = int(offered.offered) + 1


func _keep_monotone(fresh: Dictionary, old: Dictionary) -> void:
	for key: Variant in old:
		var old_value: Variant = old[key]
		if BEST_KEYS.has(str(key)):
			continue
		if old_value is Dictionary:
			if not fresh.get(key) is Dictionary:
				fresh[key] = {}
			_keep_monotone(fresh[key], old_value)
		elif old_value is int or old_value is float:
			var rebuilt_value: Variant = fresh.get(key)
			fresh[key] = old_value if rebuilt_value == null else maxi(int(rebuilt_value), int(old_value))
		elif not fresh.has(key):
			fresh[key] = old_value


static func _player_won(summary: Dictionary) -> bool:
	var winner: Variant = summary.get("winner")
	if winner != null:
		return str(winner).to_lower() == MATCH_WINNER_PLAYER
	return MATCH_WIN_RESULTS.has(str(summary.get("result", "")).to_lower())


static func _result_of(record: Dictionary) -> Dictionary:
	var result: Variant = record.get("result")
	return result if result is Dictionary else {}


static func _hero(stats: Dictionary, hero_id: String) -> Dictionary:
	if not stats.heroes.has(hero_id):
		stats.heroes[hero_id] = ProfileSchema.empty_hero_stats()
	return stats.heroes[hero_id]


static func _counter(map: Dictionary, id: String, keys: Array) -> Dictionary:
	if not map.has(id):
		var zeros: Dictionary = {}
		for key: String in keys:
			zeros[key] = 0
		map[id] = zeros
	return map[id]


static func _lower(current: Variant, candidate: int) -> int:
	return candidate if current == null else mini(int(current), candidate)
