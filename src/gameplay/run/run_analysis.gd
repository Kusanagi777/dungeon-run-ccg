## The analysis formulas of Run Structure (design/gdd/run-structure.md F5, F6): what
## the win-rate targets imply, and what archived runs measured. Nothing in play reads
## these; `/balance-check` and its harness do. Static and pure, and observations only:
## a rate below `min_sample` is reported `NOT ASSESSED`, never compared.
## [codeblock]
## var config: Dictionary = db.config("run_structure")
## RunAnalysis.p_reach(config.target_win_rate_by_floor, 8)           # 0.084 at the defaults
## RunAnalysis.expected_floors_cleared(config.target_win_rate_by_floor)  # 3.27
## [/codeblock]
class_name RunAnalysis
extends RefCounted

## F6: a floor with fewer matches than `min_sample`.
const NOT_ASSESSED: String = "NOT ASSESSED"
## F6: a floor with enough matches to report.
const ASSESSED: String = "ASSESSED"
## F5's damage-density model: `k_f = K_BASE + K_STEP * (f - 1)`.
const K_BASE: float = 0.6
const K_STEP: float = 0.05
const SECONDS_PER_MINUTE: float = 60.0


## F6 `p_reach(f)`: the product of the win rates of the floors before [param floor_number].
static func p_reach(win_rates: Array, floor_number: int) -> float:
	var reach: float = 1.0
	for i: int in range(floor_number - 1):
		reach *= float(win_rates[i])
	return reach


## F6 `expected_floors_cleared`.
static func expected_floors_cleared(win_rates: Array) -> float:
	var expected: float = 0.0
	for i: int in range(win_rates.size()):
		expected += p_reach(win_rates, i + 1) * float(win_rates[i])
	return expected


## F6 `p_victory`.
static func p_victory(win_rates: Array) -> float:
	return p_reach(win_rates, win_rates.size()) * float(win_rates[-1])


## F6 over archived [param records] (`RunRecord` Dictionaries): one row per floor
## through [param floors], `{floor, matches, wins, rate, status}`, where `rate` is null
## when `status` is [constant NOT_ASSESSED]. A restarted match counts once, by its last
## attempt, which is the one summary a floor keeps.
static func measured_win_rates(records: Array, floors: int, min_sample: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for floor_number: int in range(1, floors + 1):
		var matches: int = 0
		var wins: int = 0
		for record: Dictionary in records:
			for summary: Dictionary in record.get("match_summaries", []):
				if int(summary.get("floor", 0)) == floor_number:
					matches += 1
					if str(summary.get("result")) == MatchRecords.RESULT_WIN:
						wins += 1
		var assessed: bool = matches >= min_sample
		rows.append({
			"floor": floor_number,
			"matches": matches,
			"wins": wins,
			"rate": float(wins) / float(matches) if assessed and matches > 0 else null,
			"status": ASSESSED if assessed else NOT_ASSESSED,
		})
	return rows


## Match Rules F8 `turns_to_lethal`: the smallest n with
## `k * sum(min(t, max_mana) for t in 1..n) >= health`.
static func turns_to_lethal(health: int, k: float, max_mana: int) -> int:
	var cumulative: float = 0.0
	var turn: int = 0
	while cumulative < float(health):
		turn += 1
		cumulative += k * float(mini(turn, max_mana))
	return turn


## F5 `match_minutes(f)`: [param config] is `config("run_structure")`.
static func match_minutes(floor_number: int, health: int, config: Dictionary, max_mana: int) -> float:
	var k: float = K_BASE + K_STEP * float(floor_number - 1)
	return float(turns_to_lethal(health, k, max_mana)) * float(config.seconds_per_turn_pair) / SECONDS_PER_MINUTE


## F5 `run_minutes(victory)`. [param boss_health] lists the F3 health of each floor.
static func run_minutes_victory(boss_health: Array, config: Dictionary, max_mana: int) -> float:
	var floors: int = boss_health.size()
	var total: float = _minutes(config.select_s) + float(floors - 1 + _treasure_drafts(config, floors)) * _minutes(config.draft_s)
	for i: int in range(floors):
		total += _minutes(config.intro_s) + match_minutes(i + 1, int(boss_health[i]), config, max_mana)
	return total


## F5 `run_minutes(expected)`, at the `target_win_rate_by_floor` of [param config].
static func run_minutes_expected(boss_health: Array, config: Dictionary, max_mana: int) -> float:
	var floors: int = boss_health.size()
	var rates: Array = config.target_win_rate_by_floor
	var total: float = _minutes(config.select_s)
	for i: int in range(floors):
		var floor_number: int = i + 1
		var drafts_after: int = 0
		if floor_number < floors:
			drafts_after = 2 if Array(config.treasure_floors).has(floor_number) else 1
		total += p_reach(rates, floor_number) * (_minutes(config.intro_s) + match_minutes(floor_number, int(boss_health[i]), config, max_mana)
			+ float(rates[i]) * float(drafts_after) * _minutes(config.draft_s))
	return total


static func _treasure_drafts(config: Dictionary, floors: int) -> int:
	var drafts: int = 0
	for f: Variant in config.treasure_floors:
		if int(f) < floors:
			drafts += 1
	return drafts


static func _minutes(seconds: Variant) -> float:
	return float(seconds) / SECONDS_PER_MINUTE
