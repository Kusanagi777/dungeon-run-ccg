## Integration: the headless simulation harness on the shipped data (boss-ai C11, A22,
## A23, A28, Edge Cases "If two seeded runs diverge"; ADR-0008 Decision 11; story 016).
##
## A real match takes seconds, so the always-on samples are small and one per band. With
## `SIM_FULL=1` the A23 and collectible-deck cases run their full counts. A22 is recorded,
## not asserted: planner time is judged on the target machine on a release template
## (story 018); its `ai_decision` ceiling is a count and is asserted. Report files go to
## [constant OUT_DIR] and are removed after each test.
extends GdUnitTestSuite

const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const OUT_DIR: String = "user://sim_harness_test/"
const SIM_MAIN: String = "res://tests/integration/boss_ai/sim_main.gd"
const EXIT_NOT_RUN: int = 2
const PROFILE_LOCK: String = "user://profile.lock"
const FIXED_DATE: String = "2000-01-01"
const HERO: String = "hero_war"
const BOSS: String = "boss_rat_king"
const RIVAL: String = "boss_gatekeeper"
## One boss per band, and one with a hero power.
const BAND_SAMPLE: Array[String] = ["boss_rat_king", "boss_rot_warden", "boss_lich_archivist"]
const SAMPLE_SEEDS: int = 2
const FULL_SEEDS: int = 63
const ALL_HEROES: Array[String] = ["hero_war", "hero_decay", "hero_knowledge"]
const BANDS: Array[int] = [1, 2, 3]
## A22: the match's total `ai_decision` events.
const MAX_DECISIONS: int = 400
const FLOORS_IN_BAND_ONE: Array[String] = ["1", "2", "3"]
const SPY_MATCHES: int = 2
const REPORT_FIELDS: Array[String] = [
	"win_rate", "mean_turns", "mean_final_health", "decision_count", "p50_planner_ms",
	"p95_planner_ms", "rejections", "by_floor", "planner_target_ms", "play_turn", "forecast",
]
## The deck of a collectible-pool match.
const DECK_SIZE: int = 30

var _db: CardDatabase = null


## Counts the drivers and tasks it builds, and asks every task what it is.
class FactorySpy:
	extends RefCounted

	var drivers: int = 0
	var tasks: int = 0
	var foreign_tasks: int = 0
	var _db: CardDatabase

	func _init(db: CardDatabase) -> void:
		_db = db

	func maker(planner_source: Callable) -> Callable:
		var counted: Callable = func() -> PlannerTask:
			var task: PlannerTask = planner_source.call()
			tasks += 1
			if not task is ImmediatePlannerTask:
				foreign_tasks += 1
			return task
		return func(config: Dictionary, clock: Callable) -> MatchDriver:
			drivers += 1
			return MatchDriver.new(config, _db, {}, counted, clock)


func before() -> void:
	_db = ShippedMatch.database()


func after() -> void:
	_db = null


func after_test() -> void:
	if DirAccess.dir_exists_absolute(OUT_DIR):
		for file_name: String in DirAccess.get_files_at(OUT_DIR):
			@warning_ignore("return_value_discarded")
			DirAccess.remove_absolute(OUT_DIR + file_name)
		@warning_ignore("return_value_discarded")
		DirAccess.remove_absolute(OUT_DIR)


func _harness() -> BossAiSimHarness:
	return BossAiSimHarness.new(_db, FactorySpy.new(_db).maker)


func _run(boss_id: String, seeds: int, opponent: Dictionary = {"hero_id": HERO}, options: Dictionary = {}) -> Dictionary:
	var with_date: Dictionary = options.duplicate()
	with_date["date"] = FIXED_DATE
	return _harness().run(boss_id, BossAiSimHarness.seed_range(seeds), opponent, OUT_DIR, with_date)


func _full() -> bool:
	return OS.get_environment("SIM_FULL") == "1"


# --- A28 ------------------------------------------------------------------------------


func test_a28_writes_the_named_file_with_every_field() -> void:
	# Act
	var report: Dictionary = _run(BOSS, SAMPLE_SEEDS)

	# Assert
	var path: String = OUT_DIR + "%s_%s.json" % [BOSS, FIXED_DATE]
	assert_bool(FileAccess.file_exists(path)).is_true()
	var written: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_bool(written is Dictionary).is_true()
	for field: String in REPORT_FIELDS:
		assert_bool((written as Dictionary).has(field)).override_failure_message(field).is_true()
	assert_int(int(report.seeds)).is_equal(SAMPLE_SEEDS)
	assert_int(int(report.rejections)).is_equal(0)
	assert_int(int(report.decision_count)).is_greater(0)
	assert_float(float(report.mean_turns)).is_greater(0.0)
	assert_float(float(report.p95_planner_ms)).is_greater_equal(float(report.p50_planner_ms))


func test_a28_planner_target_comes_from_the_profiles() -> void:
	# Act
	var report: Dictionary = _run(BOSS, 1)

	# Assert
	assert_float(float(report.planner_target_ms)).is_equal(float(_db.config(BossAI.CONFIG_NAME).runtime.planner_target_ms))


func test_a28_a_second_run_with_the_same_seeds_is_identical() -> void:
	# Arrange
	var first: Dictionary = _run(BOSS, SAMPLE_SEEDS)

	# Act
	var second: Dictionary = _run(BOSS, SAMPLE_SEEDS)

	# Assert — through JSON too, as the file is what A28 compares
	assert_str(BossAiSimHarness.compare_reports(first, second)).is_empty()
	var text: String = JSON.stringify(first)
	assert_str(BossAiSimHarness.compare_reports(JSON.parse_string(text), second)).is_empty()


func test_a28_seeds_change_the_match() -> void:
	# Act
	var report: Dictionary = _run(BOSS, SAMPLE_SEEDS)

	# Assert — an identical pair would make the test above prove nothing
	assert_str(str(report.matches[0].log_hash)).is_not_equal(str(report.matches[1].log_hash))


func test_a28_verify_replays_every_match_and_stays_silent_when_they_agree() -> void:
	# Arrange
	var spy: FactorySpy = FactorySpy.new(_db)
	var harness: BossAiSimHarness = BossAiSimHarness.new(_db, spy.maker)

	# Act
	var report: Dictionary = harness.run(BOSS, BossAiSimHarness.seed_range(1), {"hero_id": HERO}, OUT_DIR, {"verify": true, "date": FIXED_DATE})

	# Assert
	assert_int(spy.drivers).is_equal(2)
	assert_int(int(report.seeds)).is_equal(1)


func test_compare_reports_names_the_first_differing_path() -> void:
	# Arrange
	var a: Dictionary = {"win_rate": 0.5, "matches": [{"log_hash": "aa"}]}
	var b: Dictionary = {"win_rate": 0.5, "matches": [{"log_hash": "bb"}]}

	# Act
	var found: String = BossAiSimHarness.compare_reports(a, b)

	# Assert
	assert_str(found).is_equal("matches[0].log_hash")


func test_compare_reports_ignores_only_the_volatile_fields() -> void:
	# Arrange
	var a: Dictionary = {"generated_at": "x", "p50_planner_ms": 1.0, "p95_planner_ms": 2.0, "play_turn": {"p50_ms": 1.0}, "forecast": {"runs": 1}, "seeds": 1}
	var b: Dictionary = {"generated_at": "y", "p50_planner_ms": 3.0, "p95_planner_ms": 4.0, "play_turn": {"p50_ms": 2.0}, "forecast": {"runs": 2}, "seeds": 1}

	# Act
	var same: String = BossAiSimHarness.compare_reports(a, b)
	b["seeds"] = 2
	var different: String = BossAiSimHarness.compare_reports(a, b)

	# Assert
	assert_str(same).is_empty()
	assert_str(different).is_equal("seeds")


func test_first_decision_difference_prints_the_first_differing_payload() -> void:
	# Arrange
	var a: Array = [{"type": BossAI.EVENT_DECISION, "payload": {"chosen": 0}}, {"type": BossAI.EVENT_DECISION, "payload": {"chosen": 1}}]
	var b: Array = [{"type": BossAI.EVENT_DECISION, "payload": {"chosen": 0}}, {"type": BossAI.EVENT_DECISION, "payload": {"chosen": 2}}]

	# Act
	var found: String = BossAiSimHarness.first_decision_difference(a, b)

	# Assert
	assert_str(found).contains("ai_decision 1 differs")
	assert_str(found).contains("\"chosen\":1")
	assert_str(found).contains("\"chosen\":2")


func test_first_decision_difference_reports_a_shorter_list() -> void:
	# Arrange
	var a: Array = [{"type": BossAI.EVENT_DECISION, "payload": {"chosen": 0}}]

	# Act
	var found: String = BossAiSimHarness.first_decision_difference(a, [])

	# Assert
	assert_str(found).is_equal("ai_decision count differs: 1 vs 0")


func test_first_decision_difference_of_equal_logs_is_empty() -> void:
	# Arrange
	var a: Array = [{"type": "card_drawn", "payload": {}}, {"type": BossAI.EVENT_DECISION, "payload": {"chosen": 0}}]

	# Act
	var found: String = BossAiSimHarness.first_decision_difference(a, a.duplicate(true))

	# Assert
	assert_str(found).is_empty()


func test_a_report_that_cannot_be_written_answers_empty() -> void:
	# Arrange — a file where the folder should be
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var blocker: FileAccess = FileAccess.open(OUT_DIR + "blocker", FileAccess.WRITE)
	blocker.close()

	# Act
	var report: Dictionary = _harness().run(BOSS, BossAiSimHarness.seed_range(1), {"hero_id": HERO}, OUT_DIR + "blocker/inner/", {"date": FIXED_DATE})

	# Assert
	assert_dict(report).is_empty()


# --- the command line -------------------------------------------------------------------


## `sim_main.gd` in a process of its own: its exit code and output.
func _sim(args: PackedStringArray) -> Dictionary:
	var output: Array = []
	var line: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", SIM_MAIN, "--"]
	line.append_array(args)
	var code: int = OS.execute(OS.get_executable_path(), line, output, true, false)
	return {"code": code, "text": "
".join(output)}


func test_sim_with_no_boss_exits_two() -> void:
	# Act
	var ran: Dictionary = _sim([])

	# Assert
	assert_int(int(ran.code)).is_equal(EXIT_NOT_RUN)
	assert_str(str(ran.text)).contains("--boss <id> is required")


func test_sim_with_an_unknown_boss_exits_two_and_leaves_no_lock() -> void:
	# Act
	var ran: Dictionary = _sim(["--boss", "boss_not_in_the_data"])

	# Assert
	assert_int(int(ran.code)).is_equal(EXIT_NOT_RUN)
	assert_bool(FileAccess.file_exists(PROFILE_LOCK)).is_false()


func test_sim_of_one_seed_exits_zero_writes_the_file_and_leaves_no_lock() -> void:
	# Act
	var ran: Dictionary = _sim(["--boss", BOSS, "--seeds", "1", "--out", OUT_DIR])

	# Assert
	assert_int(int(ran.code)).override_failure_message(str(ran.text)).is_equal(0)
	assert_int(DirAccess.get_files_at(OUT_DIR).size()).is_equal(1)
	assert_str(str(ran.text)).contains("%s, band" % BOSS)
	assert_bool(FileAccess.file_exists(PROFILE_LOCK)).is_false()


# --- A23 ------------------------------------------------------------------------------


func _assert_clean(report: Dictionary, label: String) -> void:
	assert_bool(BossAiSimHarness.is_clean(report)).override_failure_message("%s: %s" % [label, JSON.stringify(report.end_reasons)]).is_true()
	assert_int(int(report.rejections)).override_failure_message(label).is_equal(0)
	assert_int(int(report.faults)).override_failure_message(label).is_equal(0)
	assert_int(int(report.overflows)).override_failure_message(label).is_equal(0)


func test_a23_a_sample_of_every_band_ends_clean() -> void:
	# Act / Assert
	for boss_id: String in BAND_SAMPLE:
		_assert_clean(_run(boss_id, SAMPLE_SEEDS), boss_id)


func test_a23_every_shipped_boss_plays_a_match_to_its_end() -> void:
	# Arrange — one match each, the heroes in turn. `SIM_FULL=1`: A23's 1,000 and more, every
	# boss with every hero on `FULL_SEEDS / 3` seeds, 1,008 matches in all
	var seeds: int = FULL_SEEDS / ALL_HEROES.size() if _full() else 1
	var turn: int = 0

	# Act / Assert
	for band: int in BANDS:
		for boss: Dictionary in _db.bosses_in_band(band):
			var heroes: Array = ALL_HEROES if _full() else [ALL_HEROES[turn % ALL_HEROES.size()]]
			turn += 1
			for hero_id: String in heroes:
				_assert_clean(_run(str(boss.id), seeds, {"hero_id": hero_id}), "%s vs %s" % [boss.id, hero_id])


func test_is_clean_refuses_each_thing_a23_forbids() -> void:
	# Arrange
	var clean: Dictionary = {"rejections": 0, "faults": 0, "overflows": 0, "end_reasons": {"hero_dead": 1, "turn_cap": 1}}

	# Act
	var rejected: Dictionary = clean.merged({"rejections": 1}, true)
	var faulted: Dictionary = clean.merged({"faults": 1}, true)
	var overflowed: Dictionary = clean.merged({"overflows": 1}, true)
	var conceded: Dictionary = clean.merged({"end_reasons": {"concede": 1}}, true)
	var capped: Dictionary = clean.merged({"end_reasons": {"event_cap": 1}}, true)

	# Assert
	assert_bool(BossAiSimHarness.is_clean(clean)).is_true()
	for dirty: Dictionary in [rejected, faulted, overflowed, conceded, capped]:
		assert_bool(BossAiSimHarness.is_clean(dirty)).override_failure_message(str(dirty)).is_false()


func test_a23_row_counts_a_boss_rejection_from_the_log() -> void:
	# Arrange — the count must read the log: a boss command the engine refused
	var harness: BossAiSimHarness = _harness()
	var boss: Dictionary = _db.boss(BOSS)
	var seat: BossAiSimHarness.Seat = harness._play(boss, 1, 1, int(boss.band), {"hero_id": HERO})
	var log: EventLog = EventLog.new(EventLog.max_events_for(_db.config("rng_event_log")), EventLog.SCOPE_MATCH)
	@warning_ignore("return_value_discarded")
	log.append(&"command_rejected", {"side": SIDE_BOSS, "command": {}, "code": "x", "detail": "", "diagnostic": true}, 0)
	seat.log = log

	# Act
	var row: Dictionary = harness._match_row(seat, 1, 1)

	# Assert
	assert_int(int(row.boss_rejections)).is_equal(1)


func test_a23_a_turn_cap_of_one_ends_by_turn_cap_not_a_stall() -> void:
	# Arrange — a match that cannot reach a dead hero must still end
	var rules: Dictionary = (_db.config("match_rules") as Dictionary).duplicate(true)
	rules["turn_cap"] = 1
	var capped: CappedDatabase = CappedDatabase.new(_db, rules)
	var harness: BossAiSimHarness = BossAiSimHarness.new(capped, FactorySpy.new(capped).maker)

	# Act
	var report: Dictionary = harness.run(BOSS, BossAiSimHarness.seed_range(1), {"hero_id": HERO}, OUT_DIR, {"date": FIXED_DATE})

	# Assert
	assert_int(int(report.end_reasons.get("turn_cap", 0))).is_equal(1)
	assert_bool(BossAiSimHarness.is_clean(report)).is_true()


## The shipped database with a different `match_rules` body.
class CappedDatabase:
	extends CardDatabase

	var _inner: CardDatabase
	var _rules: Dictionary

	func _init(inner: CardDatabase, rules: Dictionary) -> void:
		_inner = inner
		_rules = rules

	func state() -> CardDatabase.State:
		return _inner.state()

	func has(id: String) -> bool:
		return _inner.has(id)

	func card(id: String) -> Variant:
		return _inner.card(id)

	func any_record(id: String) -> Variant:
		return _inner.any_record(id)

	func hero(id: String) -> Variant:
		return _inner.hero(id)

	func hero_power(id: String) -> Variant:
		return _inner.hero_power(id)

	func boss(id: String) -> Variant:
		return _inner.boss(id)

	func heroes() -> Array:
		return _inner.heroes()

	func collectible_pool(hero_set: String) -> Array:
		return _inner.collectible_pool(hero_set)

	func config(config_name: String) -> Variant:
		return _rules if config_name == "match_rules" else _inner.config(config_name)

	func data_version() -> String:
		return _inner.data_version()


# --- the story's construction clause ---------------------------------------------------


func test_every_match_gets_one_driver_from_the_factory_and_only_immediate_tasks() -> void:
	# Arrange
	var spy: FactorySpy = FactorySpy.new(_db)
	var harness: BossAiSimHarness = BossAiSimHarness.new(_db, spy.maker)

	# Act
	var report: Dictionary = harness.run(BOSS, BossAiSimHarness.seed_range(SPY_MATCHES), {"hero_id": HERO}, OUT_DIR, {"date": FIXED_DATE})

	# Assert
	assert_int(spy.drivers).is_equal(SPY_MATCHES)
	assert_int(spy.tasks).is_greater_equal(int(report.play_turn.runs) + int(report.forecast.runs))
	assert_int(spy.foreign_tasks).is_equal(0)


func test_seeds_run_across_the_floors_of_the_bosss_band() -> void:
	# Act
	var report: Dictionary = _run(BOSS, FLOORS_IN_BAND_ONE.size())

	# Assert — C11 / content AC-13: the boss win rate per floor
	assert_array((report.by_floor as Dictionary).keys()).contains_exactly_in_any_order(FLOORS_IN_BAND_ONE)
	for floor_key: String in report.by_floor:
		assert_int(int(report.by_floor[floor_key].matches)).is_equal(1)
		assert_float(float(report.by_floor[floor_key].target_player_win_rate)).is_equal(float(_db.config("run_structure").target_win_rate_by_floor[int(floor_key) - 1]))


func test_boss_health_rises_with_the_floor_by_the_run_structure_bonus() -> void:
	# Arrange
	var harness: BossAiSimHarness = _harness()
	var boss: Dictionary = _db.boss(BOSS)
	var bonus: int = int(_db.config("run_structure").floor_health_bonus)

	# Act
	var first: int = harness._boss_health(boss, 1)
	var third: int = harness._boss_health(boss, 3)

	# Assert
	assert_int(first).is_equal(int(boss.health))
	assert_int(third).is_equal(int(boss.health) + 2 * bonus)


func test_boss_vs_boss_seats_the_rivals_deck_in_the_players_seat() -> void:
	# Arrange
	var harness: BossAiSimHarness = _harness()
	var boss: Dictionary = _db.boss(BOSS)

	# Act
	var seat: BossAiSimHarness.Seat = harness._play(boss, 1, 1, int(boss.band), {"boss_id": RIVAL})

	# Assert
	var rival_cards: Array = _db.boss(RIVAL).deck
	var player_plays: Array = seat.log.events_since(0).filter(func(e: Dictionary) -> bool: return str(e.type) == "card_played" and str(e.payload.side) == MatchRecords.SIDE_PLAYER)
	assert_array(player_plays).is_not_empty()
	for event: Dictionary in player_plays:
		assert_bool(rival_cards.has(str(event.payload.card_id))).override_failure_message(str(event.payload)).is_true()
	assert_bool(BossAiSimHarness.CLEAN_END_REASONS.has(str(seat.result.reason))).is_true()


func test_boss_vs_boss_ends_clean_for_every_rival_pair_in_the_band_sample() -> void:
	# Act / Assert
	for boss_id: String in BAND_SAMPLE:
		_assert_clean(_run(boss_id, 1, {"boss_id": RIVAL}), boss_id)


# --- A22: the count is asserted, the time recorded --------------------------------------


func test_a22_band_three_budgets_stay_under_the_decision_ceiling() -> void:
	# Act
	var report: Dictionary = _run("boss_hollow_king", SAMPLE_SEEDS, {"hero_id": HERO}, {"band": 3})

	# Assert
	assert_int(int(report.max_decisions_in_a_match)).is_less_equal(MAX_DECISIONS)
	assert_int(int(report.play_turn.runs)).is_greater(0)
	assert_int(int(report.forecast.runs)).is_greater(0)


func test_percentile_is_nearest_rank_in_milliseconds() -> void:
	# Arrange
	var runs: Array[int] = [1000, 2000, 3000, 4000]

	# Act / Assert
	assert_float(BossAiSimHarness._percentile_ms(runs, BossAiSimHarness.PERCENTILE_MEDIAN)).is_equal(2.0)
	assert_float(BossAiSimHarness._percentile_ms(runs, BossAiSimHarness.PERCENTILE_TAIL)).is_equal(4.0)
	assert_float(BossAiSimHarness._percentile_ms([], BossAiSimHarness.PERCENTILE_TAIL)).is_equal(0.0)


# --- every collectible card in a seat's deck --------------------------------------------


## The collectible pool of [param hero_set] in [constant DECK_SIZE]-card decks, each with
## the pool's cards rotated so the last deck is full too.
func _collectible_decks(hero_set: String) -> Array[Array]:
	var pool: Array = _db.collectible_pool(hero_set).map(func(card: Dictionary) -> String: return str(card.id))
	var decks: Array[Array] = []
	var first: int = 0
	while first < pool.size():
		var deck: Array = []
		for offset: int in DECK_SIZE:
			deck.append(pool[(first + offset) % pool.size()])
		decks.append(deck)
		first += DECK_SIZE
	return decks


func test_a_seat_piloting_any_collectible_deck_ends_clean() -> void:
	# Arrange — the starters hold 15 cards; these hold the whole pool. `SIM_FULL=1`: more seeds
	var seeds: int = 8 if _full() else 1

	# Act / Assert
	for hero_id: String in ALL_HEROES:
		for deck: Array in _collectible_decks(str(_db.hero(hero_id).set)):
			_assert_clean(_run(BOSS, seeds, {"hero_id": hero_id, "deck": deck}), "%s %s" % [hero_id, deck[0]])
