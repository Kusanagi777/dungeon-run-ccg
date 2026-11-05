## The headless AI-vs-AI simulation harness (design/gdd/boss-ai.md C11, A22, A23, A28;
## ADR-0006; ADR-0008 Decision 11; boss-ai-match-driver story 016).
##
## [method run] plays one seeded match per seed of a boss against a **hero-script**: a
## second [BossAI] on the `default` profile piloting a hero deck. Or boss vs boss, the
## other boss's deck and profile in the player's seat. It writes
## `<out_dir>/<boss_id>_<date>.json` and returns the same report.
##
## **One driver per match.** A match has one engine, and two drivers would be two
## matches, so the boss seat plans through the [MatchDriver] from the injected
## `driver_factory`, and the player's seat is this harness: its [BossAI] plans on a clone
## of that driver's engine and every command goes through [method MatchDriver.submit].
## [method _settle] ticks after each one until [method MatchDriver.is_planning] is false,
## so a boss Choice raised on the player's turn is answered before the next command. No
## worker ever starts: every task is a [TimedTask], an [ImmediatePlannerTask].
##
## **Determinism** (A28): everything flows from the seed through [RngService]. The driver
## gets a clock that never moves, so a plan replays in one tick and no wall-clock
## `tick_over_budget` can reach the log. What still varies between two runs is
## [constant VOLATILE_FIELDS], which [method compare_reports] skips: `generated_at` and
## the planner times, which are measurements. On a `verify` run each match is played
## twice and the first differing `ai_decision` payload is printed (Edge Cases "If two
## seeded runs diverge"); a report that differs from the file it replaces says where.
##
## [codeblock]
## var boot: Node = preload("res://src/core/boot.gd").new()
## boot.boot()
## var harness := BossAiSimHarness.new(boot.services().card_database, boot.driver_factory)
## var report: Dictionary = harness.run("boss_rat_king", BossAiSimHarness.seed_range(100), {"hero_id": "hero_war"}, "res://production/qa/sim/")
## [/codeblock]
class_name BossAiSimHarness
extends RefCounted

## Where A28's files go.
const DEFAULT_OUT_DIR: String = "res://production/qa/sim/"
## The report fields that change between two identical runs.
const VOLATILE_FIELDS: Array[String] = ["generated_at", "p50_planner_ms", "p95_planner_ms", "play_turn", "forecast"]
## The band overlay the hero-script plays: `default` needs one for its budgets, and
## band 2's is the one that changes no weight, so the pilot is the same on every floor.
const PILOT_BAND: int = 2
## The `ai_profile` of the hero-script (C11).
const PILOT_PROFILE: String = "default"
## The root stream of the player's seat, apart from the boss's `ai_<floor>`.
const PILOT_STREAM: String = "pilot_%d"
## Plans in one turn that may end on a rejection before the seat takes its first legal
## command instead.
const MAX_STALE_PLANS: int = 3
const USEC_PER_MSEC: float = 1000.0
const PERCENTILE_MEDIAN: float = 0.5
const PERCENTILE_TAIL: float = 0.95
const EVENT_REJECTED: String = "command_rejected"
const REASON_OVERFLOW: String = "resolution_overflow"


## Planner run times in microseconds (A22: `play_turn` and `forecast` apart).
class Timings:
	extends RefCounted

	var plan: Array[int] = []
	var forecast: Array[int] = []


## The harness's [PlannerTask]: an [ImmediatePlannerTask] that times the work inside
## [method start] (A22) and files it by what the work returned.
class TimedTask:
	extends ImmediatePlannerTask

	var _timings: Timings

	func _init(timings: Timings) -> void:
		_timings = timings

	func start(work: Callable) -> void:
		var before: int = Time.get_ticks_usec()
		super.start(work)
		var elapsed: int = Time.get_ticks_usec() - before
		if _result is Intent:
			_timings.forecast.append(elapsed)
		else:
			_timings.plan.append(elapsed)
		return


## One match in play: the driver, its seat's AI and how it ended.
class Seat:
	extends RefCounted

	var driver: MatchDriver
	var pilot: BossAI
	var log: EventLog
	## The `MatchResult`, once [signal MatchDriver.match_ended] fired.
	var result: Variant = null
	## Commands of the player's seat the engine refused.
	var rejected: int = 0

	func on_match_ended(match_result: Dictionary) -> void:
		result = match_result


var _db: CardDatabase
var _timings: Timings = Timings.new()
var _driver_factory: Callable


## [param db] is the `Ready` database. [param factory_maker] is `Boot.driver_factory`, or
## any `Callable(planner_source: Callable) -> Callable` giving a `driver_factory`: it is
## called once, with the source of this harness's tasks.
func _init(db: CardDatabase, factory_maker: Callable) -> void:
	_db = db
	var timings: Timings = _timings
	_driver_factory = factory_maker.call(func() -> PlannerTask: return TimedTask.new(timings))


## The seeds `1 .. count`, which `--seeds <count>` means.
static func seed_range(count: int) -> Array[int]:
	var seeds: Array[int] = []
	for value: int in range(1, count + 1):
		seeds.append(value)
	return seeds


## Plays [param boss_id] once per seed and writes the report. [param opponent] is
## `{hero_id}` or `{boss_id}`; a `{boss_id}` seat is that boss's deck and profile on the
## first hero's body, without its passive, which only installs on the boss side.
## [param options]: `band` plays the boss at that band's overlay instead of its own;
## `date` names the file instead of today; `verify` plays every match twice and compares.
## The seeds run across the floors of the boss's band in turn (run-structure F1).
## An empty dictionary is returned when the file could not be written.
## [codeblock]
## var report: Dictionary = harness.run("boss_x", BossAiSimHarness.seed_range(100), {"hero_id": "hero_war"}, BossAiSimHarness.DEFAULT_OUT_DIR)
## report.rejections   # 0
## [/codeblock]
func run(boss_id: String, seeds: Array[int], opponent: Dictionary, out_dir: String, options: Dictionary = {}) -> Dictionary:
	_timings.plan.clear()
	_timings.forecast.clear()
	var boss_def: Dictionary = _db.boss(boss_id)
	var band: int = int(options.get("band", boss_def.band))
	var floors: Array[int] = _floors_of_band(int(boss_def.band))
	var verify: bool = bool(options.get("verify", false))
	var matches: Array[Dictionary] = []
	for index: int in seeds.size():
		var floor_number: int = floors[index % floors.size()]
		var seat: Seat = _play(boss_def, seeds[index], floor_number, band, opponent)
		if verify:
			_verify(seat, boss_def, seeds[index], floor_number, band, opponent)
		matches.append(_match_row(seat, seeds[index], floor_number))
	var report: Dictionary = _report(boss_id, band, opponent, matches)
	var date: String = str(options.get("date", Time.get_date_string_from_system()))
	var path: String = out_dir.path_join("%s_%s.json" % [boss_id, date])
	_note_previous(path, report)
	return report if _write(path, report) else {}


## Where two reports differ, ignoring [constant VOLATILE_FIELDS]: the first differing
## path, or `""` when they match (A28).
## [codeblock]
## BossAiSimHarness.compare_reports(first_run, second_run)   # ""
## [/codeblock]
static func compare_reports(a: Dictionary, b: Dictionary) -> String:
	for key: Variant in _all_keys(a, b):
		if not VOLATILE_FIELDS.has(str(key)):
			var found: String = _first_difference(a.get(key), b.get(key), str(key))
			if not found.is_empty():
				return found
	return ""


## The first differing `ai_decision` payload of two event lists, as text; `""` when
## they have the same ones (Edge Cases "If two seeded runs diverge").
static func first_decision_difference(a: Array, b: Array) -> String:
	var ours: Array = _decisions(a)
	var theirs: Array = _decisions(b)
	for index: int in mini(ours.size(), theirs.size()):
		var left: String = EventLogAssertions.canonical_json(ours[index])
		var right: String = EventLogAssertions.canonical_json(theirs[index])
		if left != right:
			return "ai_decision %d differs:\n  A: %s\n  B: %s" % [index, left, right]
	if ours.size() != theirs.size():
		return "ai_decision count differs: %d vs %d" % [ours.size(), theirs.size()]
	return ""


# --- one match ---------------------------------------------------------------------


func _play(boss_def: Dictionary, seed_value: int, floor_number: int, band: int, opponent: Dictionary) -> Seat:
	var seat: Seat = _seat(boss_def, seed_value, floor_number, band, opponent)
	seat.driver.match_ended.connect(seat.on_match_ended)
	while seat.result == null:
		_settle(seat)
		if seat.result == null:
			_move(seat)
	return seat


## A second play of the same match; a difference is printed, never raised.
func _verify(first: Seat, boss_def: Dictionary, seed_value: int, floor_number: int, band: int, opponent: Dictionary) -> void:
	var second: Seat = _play(boss_def, seed_value, floor_number, band, opponent)
	var found: String = first_decision_difference(first.log.events_since(0), second.log.events_since(0))
	if not found.is_empty():
		printerr("sim: seed %d diverged. %s" % [seed_value, found])


## Builds the `MatchConfig` (run-structure R3), then the driver and the seat's AI on it.
func _seat(boss_def: Dictionary, seed_value: int, floor_number: int, band: int, opponent: Dictionary) -> Seat:
	var rng: RngService = RngService.new(seed_value, _db.data_version())
	var seat: Seat = Seat.new()
	seat.log = EventLog.new(EventLog.max_events_for(_db.config("rng_event_log")), EventLog.SCOPE_MATCH, {
		"engine_version": str(Engine.get_version_info().string),
		"data_version": _db.data_version(),
		"run_seed_hex": RngService.to_hex_u64(seed_value),
		"floor": floor_number,
	})
	var hero_def: Dictionary = _hero(str(opponent.get("hero_id", "")))
	var rival: Variant = _db.boss(str(opponent.boss_id)) if opponent.has("boss_id") else null
	var player_deck: Array = rival.deck if rival != null else hero_def.starter_deck
	var config: Dictionary = {
		"floor": floor_number,
		"band": band,
		"rng_match": rng.stream("match_%d" % floor_number),
		"rng_ai": rng.stream("ai_%d" % floor_number),
		"log": seat.log,
		"player": {
			"hero_def_id": str(hero_def.id),
			"deck": player_deck.duplicate(),
			"hook_installers": [],
		},
		"boss": {
			"boss_def_id": str(boss_def.id),
			"deck": (boss_def.deck as Array).duplicate(),
			"health": _boss_health(boss_def, floor_number),
			"hook_installers": Treasures.passive_installer(boss_def),
			"ai_id": str(boss_def.ai_profile),
		},
	}
	seat.driver = _driver_factory.call(config, _still_clock)
	var seat_def: Dictionary = rival if rival != null else {"id": hero_def.id, "ai_profile": PILOT_PROFILE}
	seat.pilot = _pilot(seat_def, rng.stream(PILOT_STREAM % floor_number), seat.log)
	return seat


## The player's seat: a [BossAI] on [param seat_def] that watches the boss.
func _pilot(seat_def: Dictionary, stream: RngStream, log: EventLog) -> BossAI:
	var profiles: Dictionary = _db.config(BossAI.CONFIG_NAME)
	var profile: Dictionary = ProfileResolver.resolve(profiles, seat_def, PILOT_BAND)
	return BossAI.new(seat_def, profile, PILOT_BAND, stream, profiles.op_values, log, _db, profiles.keyword_values, MatchRecords.SIDE_BOSS)


## Every live task finished and every plan replayed.
func _settle(seat: Seat) -> void:
	while seat.driver.is_planning():
		seat.driver.tick()


## The player's seat acts: the keep-all mulligan, or a whole planned turn. A plan can
## go stale, when a boss Choice answered mid-turn moved what it was built on: it stops at
## the rejection, and the next plan starts from the new state. After
## [constant MAX_STALE_PLANS] of them the seat takes its first legal command, which is
## always there while the match runs.
func _move(seat: Seat) -> void:
	# The harness alone reads into the driver: the seat has to plan on a clone of the
	# engine, as a task would, and the driver hands a clone to no one else.
	var engine: RulesEngine = seat.driver._engine
	if engine.phase() == MatchState.PHASE_MULLIGAN:
		@warning_ignore("return_value_discarded")
		_submit(seat, seat.driver.legal_commands()[0])
		return
	for _attempt: int in MAX_STALE_PLANS:
		if _replay(seat, _plan(seat, engine)):
			return
	@warning_ignore("return_value_discarded")
	_submit(seat, seat.driver.legal_commands()[0])


## The hero-script's plan for its turn, built as a task would build it. Its diagnostics
## stay out of the log: `ai_decision` counts the boss's decisions (A22).
func _plan(seat: Seat, engine: RulesEngine) -> TurnPlan:
	var sandbox: RulesEngine = engine.clone()
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()
	task.start(seat.pilot.plan_task(sandbox, task))
	sandbox.end_match()
	return task.result()


## Submits [param plan] until it is spent or the match ends, and answers `true`. A
## refused command, or a plan with nothing in it, is `false`: this plan moved nothing on.
func _replay(seat: Seat, plan: TurnPlan) -> bool:
	for command: Dictionary in plan.commands:
		if not _submit(seat, command):
			return false
		if seat.result != null:
			return true
	return not plan.commands.is_empty()


func _submit(seat: Seat, command: Dictionary) -> bool:
	var result: Dictionary = seat.driver.submit(command)
	if not result.accepted:
		seat.rejected += 1
	_settle(seat)
	return result.accepted


func _still_clock() -> int:
	return 0


# --- data ----------------------------------------------------------------------------


## The HeroDef named [param hero_id], or the first when it is empty or unknown.
func _hero(hero_id: String) -> Dictionary:
	var heroes: Array = _db.heroes()
	for record: Dictionary in heroes:
		if record.id == hero_id:
			return record
	return heroes[0]


## run-structure F1: the floors of [param band].
func _floors_of_band(band: int) -> Array[int]:
	var split: Array = _db.config("run_structure").band_split
	var first: int = 1
	for index: int in band - 1:
		first += int(split[index])
	var floors: Array[int] = []
	for offset: int in int(split[band - 1]):
		floors.append(first + offset)
	return floors


## run-structure F3.
func _boss_health(boss_def: Dictionary, floor_number: int) -> int:
	var bonus: int = int(_db.config("run_structure").floor_health_bonus)
	return int(boss_def.health) + bonus * (floor_number - _floors_of_band(int(boss_def.band))[0])


# --- the report ----------------------------------------------------------------------


## One match's row: what it came to and what the log shows.
func _match_row(seat: Seat, seed_value: int, floor_number: int) -> Dictionary:
	var result: Dictionary = seat.result
	var events: Array[Dictionary] = seat.log.events_since(0)
	var row: Dictionary = {
		"seed": str(seed_value),
		"floor": floor_number,
		"winner": str(result.winner),
		"reason": str(result.reason),
		"turns": int(result.turns),
		"final_health": {
			MatchRecords.SIDE_BOSS: int(result.final_health[MatchRecords.SIDE_BOSS]),
			MatchRecords.SIDE_PLAYER: int(result.final_health[MatchRecords.SIDE_PLAYER]),
		},
		"decisions": _count(events, BossAI.EVENT_DECISION),
		"boss_rejections": 0,
		"player_rejections": seat.rejected,
		"faults": _count(events, BossAI.EVENT_FAULT),
		"overflows": 1 if str(result.reason) == REASON_OVERFLOW else 0,
		"log_hash": EventLogAssertions.canonical_json(events).sha256_text(),
	}
	for event: Dictionary in events:
		if str(event.type) == EVENT_REJECTED and str(event.payload.get("side")) == MatchRecords.SIDE_BOSS:
			row.boss_rejections += 1
	return row


func _report(boss_id: String, band: int, opponent: Dictionary, matches: Array[Dictionary]) -> Dictionary:
	var count: int = matches.size()
	var boss_wins: int = 0
	var totals: Dictionary = {"turns": 0, "health": 0, "decisions": 0, "rejections": 0, "player_rejections": 0, "faults": 0, "overflows": 0}
	var most_decisions: int = 0
	var reasons: Dictionary = {}
	var floors: Dictionary = {}
	for row: Dictionary in matches:
		var won: bool = row.winner == MatchRecords.SIDE_BOSS
		boss_wins += 1 if won else 0
		totals.turns += row.turns
		totals.health += row.final_health[MatchRecords.SIDE_BOSS]
		totals.decisions += row.decisions
		totals.rejections += row.boss_rejections
		totals.player_rejections += row.player_rejections
		totals.faults += row.faults
		totals.overflows += row.overflows
		most_decisions = maxi(most_decisions, row.decisions)
		reasons[row.reason] = int(reasons.get(row.reason, 0)) + 1
		var on_floor: Dictionary = floors.get_or_add(str(row.floor), {"matches": 0, "boss_wins": 0})
		on_floor.matches += 1
		on_floor.boss_wins += 1 if won else 0
	var targets: Array = _db.config("run_structure").target_win_rate_by_floor
	for floor_key: String in floors:
		var on_floor: Dictionary = floors[floor_key]
		on_floor["boss_win_rate"] = float(on_floor.boss_wins) / float(on_floor.matches)
		on_floor["target_player_win_rate"] = float(targets[int(floor_key) - 1])
	var runs: Array[int] = []
	runs.append_array(_timings.plan)
	runs.append_array(_timings.forecast)
	return {
		"boss_id": boss_id,
		"band": band,
		"opponent": opponent,
		"seeds": count,
		"data_version": _db.data_version(),
		"win_rate": _ratio(boss_wins, count),
		"mean_turns": _ratio(totals.turns, count),
		"mean_final_health": _ratio(totals.health, count),
		"decision_count": totals.decisions,
		"max_decisions_in_a_match": most_decisions,
		"rejections": totals.rejections,
		"player_rejections": totals.player_rejections,
		"faults": totals.faults,
		"overflows": totals.overflows,
		"end_reasons": reasons,
		"by_floor": floors,
		"planner_target_ms": float(_db.config(BossAI.CONFIG_NAME).runtime.planner_target_ms),
		"p50_planner_ms": _percentile_ms(runs, PERCENTILE_MEDIAN),
		"p95_planner_ms": _percentile_ms(runs, PERCENTILE_TAIL),
		"play_turn": _times(_timings.plan),
		"forecast": _times(_timings.forecast),
		"matches": matches,
		"generated_at": Time.get_datetime_string_from_system(true),
	}


static func _times(runs: Array[int]) -> Dictionary:
	return {"runs": runs.size(), "p50_ms": _percentile_ms(runs, PERCENTILE_MEDIAN), "p95_ms": _percentile_ms(runs, PERCENTILE_TAIL)}


## The nearest-rank [param fraction] percentile of [param runs], in milliseconds.
static func _percentile_ms(runs: Array[int], fraction: float) -> float:
	if runs.is_empty():
		return 0.0
	var sorted: Array[int] = runs.duplicate()
	sorted.sort()
	var rank: int = ceili(fraction * sorted.size()) - 1
	return float(sorted[clampi(rank, 0, sorted.size() - 1)]) / USEC_PER_MSEC


static func _ratio(part: int, whole: int) -> float:
	return float(part) / float(whole) if whole > 0 else 0.0


static func _count(events: Array[Dictionary], type: String) -> int:
	var total: int = 0
	for event: Dictionary in events:
		if str(event.type) == type:
			total += 1
	return total


static func _decisions(events: Array) -> Array:
	var payloads: Array = []
	for event: Dictionary in events:
		if str(event.type) == BossAI.EVENT_DECISION:
			payloads.append(event.payload)
	return payloads


static func _all_keys(a: Dictionary, b: Dictionary) -> Array:
	var keys: Array = a.keys()
	for key: Variant in b:
		if not keys.has(key):
			keys.append(key)
	keys.sort()
	return keys


static func _first_difference(a: Variant, b: Variant, path: String) -> String:
	if a is Dictionary and b is Dictionary:
		for key: Variant in _all_keys(a, b):
			var found: String = _first_difference(a.get(key), b.get(key), "%s.%s" % [path, key])
			if not found.is_empty():
				return found
		return ""
	if a is Array and b is Array and a.size() == b.size():
		for index: int in a.size():
			var found: String = _first_difference(a[index], b[index], "%s[%d]" % [path, index])
			if not found.is_empty():
				return found
		return ""
	return "" if _same(a, b) else path


## JSON gives every number back as a float.
static func _same(a: Variant, b: Variant) -> bool:
	if BossAI.is_number(a) and BossAI.is_number(b):
		return is_equal_approx(float(a), float(b))
	return a == b


## Says where [param report] differs from the file at [param path], if there is one.
static func _note_previous(path: String, report: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		return
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not previous is Dictionary:
		return
	var found: String = compare_reports(previous, report)
	if not found.is_empty():
		printerr("sim: this run differs from %s at %s" % [path, found])


static func _write(path: String, report: Dictionary) -> bool:
	var made: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE) if made == OK else null
	if file == null or not file.store_string(JSON.stringify(report, "\t")):
		printerr("sim: could not write %s" % path)
		return false
	file.close()
	return true
