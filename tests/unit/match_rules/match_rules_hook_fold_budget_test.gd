## Blocking, deterministic half of the Match Rules budgets (story
## match-rules/story-018; design/gdd/match-rules.md AC-40 and Game Feel —
## Input Responsiveness; ADR-0005 Decision 4 / Implementation Guidelines —
## "≤ 12 entries per match, `entry_count()` asserted in debug"; ADR-0007
## Performance; control manifest Core guardrails).
##
## No wall clock here (coding standards): every assertion is a count or an
## equality — entries installed and copied, evaluator calls per fold, the
## Deathrattle chain's pass count under `resolution_step_cap`, and the
## `legal_commands()` list being identical call after call. The timings of
## the same fixtures live in the non-blocking
## `tests/performance/match_rules/match_rules_perf_test.gd`; the fixtures
## themselves are `tests/helpers/match_budget_fixtures.gd`, so both suites
## measure one thing.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
## ADR-0005 / treasures F5 bound (12), read from the registry.
const MAX_ENTRIES: int = HookRegistry.DEBUG_MAX_ENTRIES
## AC-40: repeated `legal_commands()` calls compared with the first.
const LEGAL_REPEATS: int = 100
## Folds run by the evaluator-count test, and its fold input.
const FOLD_RUNS: int = 3
const FOLD_INPUT: int = 0
## AC-40 full-board fixture, by construction: every character is a bolt
## target (both boards + both heroes); four untargeted plays (two blanks,
## the axe, the nova); minion plays are absent (board full).
const UNTARGETED_PLAYS: int = 4
const BOLTS: int = 2

var _fx: MatchBudgetFixtures = MatchBudgetFixtures.new()


## Runs [param call] and asserts it reported [param message]: an assert in a
## debug build (the `event_log_test.gd` pattern). A release build has no
## assert, so the test asserts the bound is NOT enforced there — and says so.
func _assert_debug_assertion(call: Callable, message: String) -> void:
	await assert_error(call).is_runtime_error("Assertion failed: " + message)


# --- ADR-0005 guardrail: entry_count, the 13th host, clone copies ---------------

func test_twelve_installed_modify_damage_entries_report_entry_count_twelve() -> void:
	# Arrange
	var resolver: TestEffectResolver = _fx.make_resolver()

	# Act
	var hooks: HookRegistry = _fx.make_fold_registry(resolver)

	# Assert
	assert_int(hooks.entry_count()).is_equal(MAX_ENTRIES)
	assert_int(hooks.entries(&"modify_damage").size()).is_equal(MAX_ENTRIES)
	assert_int(hooks.hosts().size()).is_equal(MatchBudgetFixtures.FOLD_HOSTS)


func test_installing_a_thirteenth_entry_trips_the_debug_assertion() -> void:
	# Arrange
	var hooks: HookRegistry = _fx.make_fold_registry(_fx.make_resolver())
	var extra: HookInstaller = MatchFactory.make_hook_installer("budget_extra", SIDE_PLAYER, [&"modify_damage"])
	var message: String = "HookRegistry holds %d entries (treasures F5 bound %d)" % [MAX_ENTRIES + 1, MAX_ENTRIES]

	# Act / Assert
	if not OS.is_debug_build():
		push_warning("NOT ASSESSED in a release build: the 12-entry bound is a debug assert (ADR-0005)")
		assert_bool(hooks.install(extra)).is_true()
		return
	await _assert_debug_assertion(func() -> void: hooks.install(extra), message)


func test_a_clone_of_a_twelve_entry_match_copies_exactly_twelve_entries() -> void:
	# Arrange
	var engine: RulesEngine = _fx.make_hooked_engine(_fx.make_resolver())
	assert_int(engine.state().hooks.entry_count()).is_equal(MAX_ENTRIES)

	# Act
	var sandbox: RulesEngine = engine.clone()

	# Assert
	assert_int(sandbox.state().hooks.entry_count()).is_equal(engine.state().hooks.entry_count())
	assert_int(sandbox.state().hooks.entry_count()).is_less_equal(MAX_ENTRIES)
	assert_int(sandbox.state().hooks.hosts().size()).is_equal(MatchBudgetFixtures.FOLD_HOSTS)
	sandbox.end_match()


func test_a_twelve_entry_fold_calls_the_evaluator_once_per_entry() -> void:
	# Arrange
	var resolver: TestEffectResolver = _fx.make_resolver()
	var hooks: HookRegistry = _fx.make_fold_registry(resolver)
	var ctx: Dictionary = {"source": null, "target": MatchFactory.PLAYER_HERO_ENTITY_ID}

	# Act
	var results: Array[int] = []
	for _i: int in FOLD_RUNS:
		results.append(hooks.fold(&"modify_damage", &"player", FOLD_INPUT, ctx))

	# Assert — one evaluator call per entry per fold, every delta applied, no clamp
	assert_int(resolver.hook_calls.size()).is_equal(FOLD_RUNS * MAX_ENTRIES)
	for result: int in results:
		assert_int(result).is_equal(FOLD_INPUT + MAX_ENTRIES * MatchBudgetFixtures.FOLD_DELTA)


# --- AC-40 worst case: the Deathrattle chain is >= 50 steps, under the cap ------

func test_the_deathrattle_chain_resolves_fifty_six_passes_under_the_step_cap_without_a_fault() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _fx.make_chain_engine(_fx.make_resolver(), log)
	var before: int = log.events.size()

	# Act
	var result: Dictionary = engine.submit(_fx.chain_command(engine))

	# Assert
	var passes: int = MatchBudgetFixtures.deathrattle_passes(log.events.slice(before))
	assert_bool(result.accepted).is_true()
	assert_int(passes).is_equal(MatchBudgetFixtures.CHAIN_HOSTS * (MatchBudgetFixtures.CHAIN_GENERATIONS + 1))
	assert_int(passes).is_greater_equal(MatchBudgetFixtures.CHAIN_MIN_STEPS)
	assert_int(passes).is_less(engine.rule("resolution_step_cap"))
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_int(engine.state().players[SIDE_BOSS].board.size()).is_equal(0)
	assert_int(engine.state().players[SIDE_PLAYER].board.size()).is_equal(TestConstants.BOARD_SIZE)


func test_the_deathrattle_chain_on_a_fresh_clone_is_the_same_chain_and_leaves_the_live_board() -> void:
	# Arrange — the perf suite times exactly this: one fresh clone per sample
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _fx.make_chain_engine(_fx.make_resolver(false), log)
	var counts: Array[int] = []

	# Act
	for _i: int in 2:
		var sandbox: RulesEngine = engine.clone()
		var result: Dictionary = sandbox.submit(_fx.chain_command(sandbox))
		assert_bool(result.accepted).is_true()
		counts.append(MatchBudgetFixtures.deathrattle_passes(sandbox.state().log.events_since(0)))
		sandbox.end_match()

	# Assert
	var expected: int = MatchBudgetFixtures.CHAIN_HOSTS * (MatchBudgetFixtures.CHAIN_GENERATIONS + 1)
	assert_array(counts).is_equal([expected, expected])
	assert_int(engine.state().players[SIDE_BOSS].board.size()).is_equal(MatchBudgetFixtures.CHAIN_HOSTS)
	assert_int(MatchBudgetFixtures.deathrattle_passes(log.events)).is_equal(0)


# --- AC-40 Input Responsiveness: legal_commands() is identical every call --------

func test_legal_commands_on_the_full_board_is_identical_on_every_call() -> void:
	# Arrange
	var engine: RulesEngine = _fx.make_full_board_engine(_fx.make_resolver(false))
	var first: Array = engine.legal_commands()

	# Act
	var differing: int = 0
	for _i: int in LEGAL_REPEATS:
		if engine.legal_commands() != first:
			differing += 1
	var sandbox: RulesEngine = engine.clone()
	var from_clone: Array = sandbox.legal_commands()
	sandbox.end_match()

	# Assert
	assert_int(differing).is_equal(0)
	assert_array(from_clone).is_equal(first)


func test_the_full_board_lists_every_attack_every_bolt_target_the_power_and_end_turn() -> void:
	# Arrange
	var engine: RulesEngine = _fx.make_full_board_engine(_fx.make_resolver(false))
	var board: int = TestConstants.BOARD_SIZE

	# Act
	var legal: Array = engine.legal_commands()

	# Assert — a fixture that silently lost its width would time a smaller list
	var by_type: Dictionary = {}
	for command: Dictionary in legal:
		by_type[command.type] = int(by_type.get(command.type, 0)) + 1
	assert_int(int(by_type.get(MatchRecords.CMD_ATTACK, 0))).is_equal(board * (board + 1))
	assert_int(int(by_type.get(MatchRecords.CMD_PLAY_CARD, 0))).is_equal(BOLTS * (2 * board + 2) + UNTARGETED_PLAYS)
	assert_int(int(by_type.get(MatchRecords.CMD_USE_HERO_POWER, 0))).is_equal(1)
	assert_int(int(by_type.get(MatchRecords.CMD_END_TURN, 0))).is_equal(1)
	assert_int(engine.state().players[SIDE_PLAYER].hand.size()).is_equal(TestConstants.HAND_SIZE)
	assert_bool(engine.has_windfury(engine.state().players[SIDE_PLAYER].board[0])).is_true()
