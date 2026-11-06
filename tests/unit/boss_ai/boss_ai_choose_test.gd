## Unit tests for the Boss AI choice phase (story boss-ai-match-driver/story-010;
## design/gdd/boss-ai.md C7, C1.4, C4, A16, Edge Cases "If a Discover is raised
## during the boss's turn" and "If all Discover options are identical";
## ADR-0006, ADR-0008; TR-boss-ai-001, TR-boss-ai-002).
##
## The boards are `tests/fixtures/boss_ai/discover_duplicate_options.json` and
## `choose_one_options.json` on the production `EffectResolver` ([BossAiBoard]).
## `op_values` and the profiles are the committed stub's, so the expected scores
## are written out where the arithmetic is the point. Streams are
## `TestRngStream.seeded`, so `draws` is exact.
extends GdUnitTestSuite

const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const DISCOVER: String = MatchRecords.CHOICE_DISCOVER
const CHOOSE_ONE: String = MatchRecords.CHOICE_CHOOSE_ONE
## Float tolerance for sums the GDD states exactly.
const EPSILON: float = 1e-9
## The `ai_1` seed of the plan cases.
const AI_SEED: int = 7


# --- helpers -----------------------------------------------------------------

func _discover_fixture() -> Dictionary:
	return BossAiBoard.read("discover_duplicate_options")


func _choose_one_fixture() -> Dictionary:
	return BossAiBoard.read("choose_one_options")


## The fixture's live engine at the boss's Main, with `boss_turns_taken` applied.
func _engine(fixture: Dictionary, db: BossAiBoard.FakeCardDatabase) -> RulesEngine:
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	if fixture.has("boss_turns_taken"):
		engine.state().players[SIDE_BOSS].turns_taken = int(fixture.boss_turns_taken)
	return engine


func _op_values() -> Dictionary:
	return BossAiBoard.stub_config().op_values


## An `ai_1` stream on the production generator.
func _stream(seed_value: int = 1) -> TestRngStream:
	return TestRngStream.seeded("ai_1", seed_value)


func _request(kind: String, options: Array, side: String = SIDE_BOSS) -> Dictionary:
	return MatchRecords.choice_request(side, kind, options, null, "bai.0")


## `Chooser.choose` on a clone of the fixture's board with [param profile]
## (the fixture's own when empty): `{index, diagnostic}`.
func _decide(fixture: Dictionary, kind: String, options: Array, stream: RefCounted, profile: Dictionary = {}) -> Dictionary:
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = _engine(fixture, db)
	var sandbox: RulesEngine = engine.clone()
	var used: Dictionary = profile if not profile.is_empty() else BossAiBoard.profile(fixture)
	var decision: Dictionary = Chooser.choose(sandbox, _request(kind, options), used, _op_values(), stream, db, SIDE_BOSS)
	sandbox.end_match()
	return decision


## The alternative of [param decision] for option [param index].
func _alternative(decision: Dictionary, index: int) -> Dictionary:
	for entry: Dictionary in decision.diagnostic.alternatives:
		if int(entry.command.option_index) == index:
			return entry
	fail("option %d is not among the alternatives" % index)
	return {"score": 0.0, "features": {"cost_fit": 0.0, "preference": 0.0}}


func _score(decision: Dictionary, index: int) -> float:
	return float(_alternative(decision, index).score)


func _preference(decision: Dictionary, index: int) -> float:
	return float(_alternative(decision, index).features.preference)


## A [BossAI] for [param fixture] over the stub's maps.
func _boss_ai(fixture: Dictionary, db: Variant, stream: RngStream) -> BossAI:
	var stub: Dictionary = BossAiBoard.stub_config()
	return BossAI.new(CardFactory.make_boss_def("boss_test", int(fixture.band)), BossAiBoard.profile(fixture), int(fixture.band), stream, stub.op_values, null, db, stub.keyword_values)


## One planned boss turn on a clone of [param fixture]'s board, through the task
## seam: `{plan, engine}`, the live engine untouched.
func _planned(fixture: Dictionary, stream: RngStream) -> Dictionary:
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = _engine(fixture, db)
	var sandbox: RulesEngine = engine.clone()
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()
	task.start(_boss_ai(fixture, db, stream).plan_task(sandbox, task))
	assert_bool(task.poll()).is_true()
	var plan: TurnPlan = task.result()
	sandbox.end_match()
	return {"plan": plan, "engine": engine}


## The `ai_decision {kind: choice}` diagnostics of [param plan].
func _choices(plan: TurnPlan) -> Array:
	return plan.diagnostics.filter(func(d: Dictionary) -> bool: return str(d.get("kind")) == BossAI.KIND_CHOICE)


## The `choose` commands of [param plan].
func _choose_commands(plan: TurnPlan) -> Array:
	return plan.commands.filter(func(c: Dictionary) -> bool: return str(c.type) == MatchRecords.CMD_CHOOSE)


## [param fixture]'s profile under the archetype [param key].
func _archetype(fixture: Dictionary, key: String) -> Dictionary:
	var named: Dictionary = fixture.duplicate(true)
	named.profile = key
	return BossAiBoard.profile(named)


# --- A16 ---------------------------------------------------------------------

func test_a16_duplicates_collapse_and_the_cheap_option_wins_with_no_draw() -> void:
	# Arrange — through the BossAI entry point, A16's three options and mana_max 4
	var fixture: Dictionary = _discover_fixture()
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = _engine(fixture, db)
	var sandbox: RulesEngine = engine.clone()
	var stream: TestRngStream = _stream()
	var boss_ai: BossAI = _boss_ai(fixture, db, stream)

	# Act
	var index: int = boss_ai.choose(sandbox, _request(DISCOVER, fixture.options))
	sandbox.end_match()

	# Assert
	var diagnostic: Dictionary = boss_ai.last_choice
	assert_int(index).is_equal(0)
	assert_int(stream.draws).is_equal(0)
	assert_str(str(diagnostic.kind)).is_equal("choice")
	assert_bool(bool(diagnostic.diagnostic)).is_true()
	assert_int(int(diagnostic.chosen.option_index)).is_equal(0)
	assert_str(str(diagnostic.chosen.type)).is_equal(MatchRecords.CMD_CHOOSE)
	assert_str(str(diagnostic.chosen.issuer)).is_equal(SIDE_BOSS)
	assert_int((diagnostic.alternatives as Array).size()).is_equal(2)


func test_the_diagnostic_is_json_representable_with_the_c9_alternative_keys() -> void:
	# Arrange
	var fixture: Dictionary = _discover_fixture()

	# Act
	var decision: Dictionary = _decide(fixture, DISCOVER, fixture.options, _stream())

	# Assert
	var round_trip: Variant = JSON.parse_string(JSON.stringify(decision.diagnostic))
	assert_bool(round_trip is Dictionary).is_true()
	assert_str(str(decision.diagnostic.mode)).is_equal(String(Scorer.MODE_NORMAL))
	for entry: Dictionary in decision.diagnostic.alternatives:
		assert_array(entry.keys()).contains_exactly_in_any_order(["command", "score", "features"])


# --- Discover score ------------------------------------------------------------

func test_a_vanilla_body_is_valued_as_buff_at_attack_plus_health_over_four() -> void:
	# Arrange
	var fixture: Dictionary = _discover_fixture()

	# Act
	var decision: Dictionary = _decide(fixture, DISCOVER, ["bai_squire", "bai_colossus"], _stream())

	# Assert — 0.8 × (2 + 3) / 4, and 0.8 × (3 + 3) / 4 × 0.5
	assert_float(_score(decision, 0)).is_equal_approx(1.0, EPSILON)
	assert_float(_score(decision, 1)).is_equal_approx(0.6, EPSILON)


func test_a_card_effect_adds_its_c6_value_times_its_targets() -> void:
	# Arrange — two player minions on the board, one `damage` row of 1.0 each
	var fixture: Dictionary = _discover_fixture()

	# Act
	var decision: Dictionary = _decide(fixture, DISCOVER, ["bai_wave", "bai_jab"], _stream())

	# Assert
	assert_float(_score(decision, 0)).is_equal_approx(2.0, EPSILON)
	assert_float(_score(decision, 1)).is_equal_approx(1.0, EPSILON)


func test_cost_fit_is_one_at_next_turns_mana_and_half_one_above_it() -> void:
	# Arrange — boss_turns_taken 3: next turn's mana_max is 4
	var fixture: Dictionary = _discover_fixture()

	# Act
	var decision: Dictionary = _decide(fixture, DISCOVER, ["bai_at_limit", "bai_over_limit"], _stream())

	# Assert — both are 0.8 × 6 / 4 = 1.2 before cost_fit
	assert_float(float(_alternative(decision, 0).features.cost_fit)).is_equal(1.0)
	assert_float(float(_alternative(decision, 1).features.cost_fit)).is_equal(0.5)
	assert_float(_score(decision, 0)).is_equal_approx(1.2, EPSILON)
	assert_float(_score(decision, 1)).is_equal_approx(0.6, EPSILON)


func test_next_mana_max_is_f4_with_the_crystal_bonus_and_the_cap() -> void:
	# Arrange
	var fixture: Dictionary = _discover_fixture()
	var engine: RulesEngine = _engine(fixture, BossAiBoard.database(fixture))
	var boss: Dictionary = engine.state().players[SIDE_BOSS]

	# Act
	var plain: int = Chooser.next_mana_max(engine, SIDE_BOSS)
	boss.crystal_bonus = 2
	var bonus: int = Chooser.next_mana_max(engine, SIDE_BOSS)
	boss.turns_taken = engine.rule("max_mana")
	var capped: int = Chooser.next_mana_max(engine, SIDE_BOSS)

	# Assert
	assert_int(plain).is_equal(4)
	assert_int(bonus).is_equal(6)
	assert_int(capped).is_equal(engine.rule("max_mana"))


# --- preference ------------------------------------------------------------------

func test_aggro_prefers_charge_and_weapon() -> void:
	# Arrange
	var fixture: Dictionary = _discover_fixture()
	var profile: Dictionary = _archetype(fixture, "aggro")

	# Act
	var decision: Dictionary = _decide(fixture, DISCOVER, ["bai_squire", "bai_raider", "bai_blade"], _stream(), profile)

	# Assert — `weapon` is the card's type, not a `tags` entry
	assert_float(_preference(decision, 0)).is_equal(0.0)
	assert_float(_preference(decision, 1)).is_equal_approx(0.5, EPSILON)
	assert_float(_preference(decision, 2)).is_equal_approx(0.4, EPSILON)
	assert_int(int(decision.index)).is_equal(1)


func test_control_prefers_taunt_heal_and_damage_all() -> void:
	# Arrange
	var fixture: Dictionary = _discover_fixture()
	var profile: Dictionary = _archetype(fixture, "control")

	# Act
	var decision: Dictionary = _decide(fixture, DISCOVER, ["bai_wall", "bai_salve", "bai_wave"], _stream(), profile)
	var single_target: Dictionary = _decide(fixture, DISCOVER, ["bai_jab", "bai_squire"], _stream(), profile)

	# Assert — `heal` is an op name; `damage_all` a `damage` op on a C6 area selector
	assert_float(_preference(decision, 0)).is_equal_approx(0.5, EPSILON)
	assert_float(_preference(decision, 1)).is_equal_approx(0.4, EPSILON)
	assert_float(_preference(decision, 2)).is_equal_approx(0.6, EPSILON)
	assert_float(_preference(single_target, 0)).is_equal(0.0)


func test_tempo_prefers_the_lowest_cost_option() -> void:
	# Arrange — `low_cost` is an option's rank among the offered options, not a tag
	var fixture: Dictionary = _discover_fixture()
	var profile: Dictionary = BossAiBoard.profile(fixture)
	profile.choice_preference = {"low_cost": 0.5}

	# Act
	var decision: Dictionary = _decide(fixture, DISCOVER, ["bai_squire", "bai_goblet", "bai_at_limit"], _stream(), profile)

	# Assert — 1.0, 1.0 + 0.5 and 1.2
	assert_float(_preference(decision, 0)).is_equal(0.0)
	assert_float(_preference(decision, 1)).is_equal_approx(0.5, EPSILON)
	assert_float(_preference(decision, 2)).is_equal(0.0)
	assert_int(int(decision.index)).is_equal(1)


func test_passive_driven_matches_its_synergy_tag_through_a_keyword_or_trigger() -> void:
	# Arrange — the bonus is the profile's `choice_preference` row for the tag
	var fixture: Dictionary = _discover_fixture()
	var profile: Dictionary = _archetype(fixture, "passive_driven")
	profile.synergy_tags = ["deathrattle"]
	profile.choice_preference = {"deathrattle": 0.5}

	# Act
	var decision: Dictionary = _decide(fixture, DISCOVER, ["bai_squire", "bai_crypt"], _stream(), profile)

	# Assert
	assert_float(_preference(decision, 0)).is_equal(0.0)
	assert_float(_preference(decision, 1)).is_equal_approx(0.5, EPSILON)
	assert_int(int(decision.index)).is_equal(1)


func test_an_option_matching_two_tags_gets_both_bonuses() -> void:
	# Arrange
	var fixture: Dictionary = _discover_fixture()
	var profile: Dictionary = BossAiBoard.profile(fixture)
	profile.choice_preference = {"taunt": 0.5, "minion": 0.25}

	# Act
	var decision: Dictionary = _decide(fixture, DISCOVER, ["bai_wall", "bai_salve"], _stream(), profile)

	# Assert
	assert_float(_preference(decision, 0)).is_equal_approx(0.75, EPSILON)


# --- Choose One --------------------------------------------------------------------

func test_choose_one_scores_each_ops_value_times_targets_with_cost_fit_one() -> void:
	# Arrange
	var fixture: Dictionary = _choose_one_fixture()
	var profile: Dictionary = BossAiBoard.profile(fixture)
	profile.choice_preference = {}

	# Act
	var decision: Dictionary = _decide(fixture, CHOOSE_ONE, fixture.options, _stream(), profile)

	# Assert — 1.0 × 1, 1.0 × 3 enemy minions, 0.6 × 1
	assert_float(_score(decision, 0)).is_equal_approx(1.0, EPSILON)
	assert_float(_score(decision, 1)).is_equal_approx(3.0, EPSILON)
	assert_float(_score(decision, 2)).is_equal_approx(0.6, EPSILON)
	assert_float(float(_alternative(decision, 1).features.cost_fit)).is_equal(1.0)
	assert_int(int(decision.index)).is_equal(1)


func test_choose_one_preference_is_looked_up_by_op_names() -> void:
	# Arrange — control: heal 0.4, damage_all 0.6
	var fixture: Dictionary = _choose_one_fixture()

	# Act
	var decision: Dictionary = _decide(fixture, CHOOSE_ONE, fixture.options, _stream())

	# Assert
	assert_float(_score(decision, 0)).is_equal_approx(1.0, EPSILON)
	assert_float(_score(decision, 1)).is_equal_approx(3.6, EPSILON)
	assert_float(_score(decision, 2)).is_equal_approx(1.0, EPSILON)


func test_choose_one_identical_ops_collapse_to_the_lowest_index_whatever_the_label() -> void:
	# Arrange
	var fixture: Dictionary = _choose_one_fixture()
	var stream: TestRngStream = _stream()

	# Act
	var decision: Dictionary = _decide(fixture, CHOOSE_ONE, fixture.duplicate_options, stream)

	# Assert
	assert_int(int(decision.index)).is_equal(0)
	assert_int(stream.draws).is_equal(0)
	assert_int((decision.diagnostic.alternatives as Array).size()).is_equal(2)


func test_a_boss_choice_raised_on_the_players_turn_returns_to_the_players_main() -> void:
	# Arrange — the player kills a boss Deathrattle that raises a Choose One
	var fixture: Dictionary = _choose_one_fixture()
	fixture.profile = "default"
	fixture.boss.board = ["bai_oracle"]
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = _engine(fixture, db)
	var oracle: int = BossAiBoard.ids_of(engine, SIDE_BOSS, "bai_oracle")[0]
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()
	@warning_ignore("return_value_discarded")
	BossAiBoard.add_to_hand(engine, SIDE_PLAYER, "bai_snipe")
	var last: int = (engine.state().players[SIDE_PLAYER].hand as Array).size() - 1
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, last, null, oracle)).accepted).is_true()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_CHOICE)
	var pending: Dictionary = engine.pending_choice()
	assert_str(str(pending.side)).is_equal(SIDE_BOSS)
	var boss_ai: BossAI = _boss_ai(fixture, db, _stream())
	var sandbox: RulesEngine = engine.clone()

	# Act
	var index: int = boss_ai.choose(sandbox, pending)
	sandbox.end_match()
	var result: Dictionary = engine.submit(MatchRecords.choose(SIDE_BOSS, index))

	# Assert — `jab` (1.0) beats `mend` (0.6)
	assert_int(index).is_equal(1)
	assert_bool(result.accepted).is_true()
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_str(String(engine.active_side())).is_equal(SIDE_PLAYER)
	assert_that(engine.pending_choice()).is_null()


# --- collapse and tie-break -----------------------------------------------------------

func test_all_identical_options_are_index_zero_no_draw_and_one_alternative() -> void:
	# Arrange
	var fixture: Dictionary = _discover_fixture()
	var stream: TestRngStream = _stream()

	# Act
	var decision: Dictionary = _decide(fixture, DISCOVER, ["bai_squire", "bai_squire", "bai_squire"], stream)

	# Assert
	assert_int(int(decision.index)).is_equal(0)
	assert_int(stream.draws).is_equal(0)
	assert_int((decision.diagnostic.alternatives as Array).size()).is_equal(1)


func test_equal_scores_of_different_options_tie_break_through_one_stream_draw() -> void:
	# Arrange — same stats, different ids: no collapse; the two seeds differ
	var fixture: Dictionary = _discover_fixture()
	var picks: Dictionary = {}

	for seed_value: Variant in fixture.ai_seeds:
		var stream: TestRngStream = _stream(int(seed_value))
		var expected: int = _stream(int(seed_value)).randi_range(0, 1)

		# Act
		var decision: Dictionary = _decide(fixture, DISCOVER, ["bai_squire", "bai_page"], stream)

		# Assert
		assert_int(stream.draws).is_equal(1)
		assert_int(int(decision.index)).is_equal(expected)
		assert_int(int(decision.diagnostic.draws)).is_equal(1)
		picks[int(decision.index)] = true
	assert_int(picks.size()).is_equal(2)


func test_a_collapsed_duplicate_takes_no_place_in_the_tie_set() -> void:
	# Arrange — the third option repeats the first; a tie set of 3 would draw over 0–2
	var fixture: Dictionary = _discover_fixture()
	var stream: TestRngStream = _stream()

	# Act
	var decision: Dictionary = _decide(fixture, DISCOVER, ["bai_squire", "bai_page", "bai_squire"], stream)

	# Assert
	assert_int(stream.draws).is_equal(1)
	assert_int(int(decision.index)).is_between(0, 1)
	assert_int((decision.diagnostic.alternatives as Array).size()).is_equal(2)


func test_the_chosen_option_is_always_among_the_three_alternatives() -> void:
	# Arrange — four tied options; a seed whose draw picks the last, beyond a top three
	var fixture: Dictionary = _choose_one_fixture()
	var seed_value: int = 0
	while _stream(seed_value).randi_range(0, 3) != 3:
		seed_value += 1

	# Act
	var decision: Dictionary = _decide(fixture, CHOOSE_ONE, fixture.equal_options, _stream(seed_value))

	# Assert
	assert_int(int(decision.index)).is_equal(3)
	var alternatives: Array = decision.diagnostic.alternatives
	assert_int(alternatives.size()).is_equal(Scorer.ALTERNATIVES_MAX)
	assert_int(int(alternatives.back().command.option_index)).is_equal(3)


# --- C1.3, purity ---------------------------------------------------------------------

func test_a_request_is_answered_for_the_side_named_and_no_other() -> void:
	# Arrange — the side is the caller's, not a hard-coded boss (wave 1 review)
	var fixture: Dictionary = _discover_fixture()
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = _engine(fixture, db)
	var request: Dictionary = _request(DISCOVER, ["bai_squire", "bai_page"], SIDE_PLAYER)

	# Act
	var own: Dictionary = Chooser.choose(engine, request, BossAiBoard.profile(fixture), _op_values(), _stream(), db, SIDE_PLAYER)
	var other: Dictionary = Chooser.choose(engine, _request(DISCOVER, ["bai_squire", "bai_page"]), BossAiBoard.profile(fixture), _op_values(), _stream(), db, SIDE_PLAYER)

	# Assert
	assert_int(int(own.index)).is_not_equal(Chooser.NO_OPTION)
	assert_str(str(own.diagnostic.chosen.issuer)).is_equal(SIDE_PLAYER)
	assert_int(int(other.index)).is_equal(Chooser.NO_OPTION)


## The fixture's match on the player's turn, a boss Deathrattle's Choose One pending
## on the live engine: `{fixture, db, engine}`. `jab` scores over `mend`.
func _boss_choice_on_the_players_turn() -> Dictionary:
	var fixture: Dictionary = _choose_one_fixture()
	fixture.profile = "default"
	fixture.boss.board = ["bai_oracle"]
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = _engine(fixture, db)
	var oracle: int = BossAiBoard.ids_of(engine, SIDE_BOSS, "bai_oracle")[0]
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()
	@warning_ignore("return_value_discarded")
	BossAiBoard.add_to_hand(engine, SIDE_PLAYER, "bai_snipe")
	var last: int = (engine.state().players[SIDE_PLAYER].hand as Array).size() - 1
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, last, null, oracle)).accepted).is_true()
	assert_str(str(engine.pending_choice().side)).is_equal(SIDE_BOSS)
	return {"fixture": fixture, "db": db, "engine": engine}


func test_a_plan_opening_on_a_boss_choice_answers_it_and_leaves_the_players_turn_alone() -> void:
	# Arrange: DD-X31: the plan replaces the choose task, and this was its case
	var board: Dictionary = _boss_choice_on_the_players_turn()
	var engine: RulesEngine = board.engine
	var sandbox: RulesEngine = engine.clone()
	var boss_ai: BossAI = _boss_ai(board.fixture, board.db, _stream())
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()

	# Act
	task.start(boss_ai.plan_task(sandbox, task))
	var plan: TurnPlan = task.result()
	sandbox.end_match()

	# Assert: the `choose` alone, its decision routed before it, and it replays
	assert_array(plan.commands).is_equal([MatchRecords.choose(SIDE_BOSS, 1)])
	assert_int(plan.diagnostics.size()).is_equal(1)
	assert_str(str(plan.diagnostics[0].kind)).is_equal(BossAI.KIND_CHOICE)
	assert_int(int(plan.diagnostics[0][TurnPlan.COMMAND_INDEX_KEY])).is_equal(0)
	assert_str(str(boss_ai.last_choice.kind)).is_equal(BossAI.KIND_CHOICE)
	var mark: int = int(engine.state().log.size())
	assert_bool(engine.submit(plan.commands[0].duplicate(true)).accepted).is_true()
	assert_int(TurnPlan.checksum(engine.state().log.events_since(mark))).is_equal(plan.expected_checksum)
	assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	assert_str(String(engine.active_side())).is_equal(SIDE_PLAYER)


func test_a_plan_of_a_choice_alone_commits_no_intent_and_spends_no_forecast() -> void:
	# Arrange
	var board: Dictionary = _boss_choice_on_the_players_turn()
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	var stream: TestRngStream = _stream()
	var boss_ai: BossAI = _boss_ai(board.fixture, board.db, stream)
	var forecast: Intent = Intent.new("boss_test", Intent.KEY_PASS, null, null, Intent.MODE_FULL)
	boss_ai.note_forecast(forecast)
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()

	# Act
	task.start(boss_ai.plan_task(sandbox, task))
	var plan: TurnPlan = task.result()
	sandbox.end_match()

	# Assert: the turn is the player's, so nothing forked and the forecast stands
	assert_object(boss_ai.last_forecast).is_same(forecast)
	assert_bool(plan.diagnostics.any(func(d: Dictionary) -> bool: return str(d[TurnPlan.EVENT_KEY]) == String(BossAI.EVENT_INTENT_COMMITTED))).is_false()
	assert_int(stream.draws).is_equal(plan.ai_draws)


func test_a_plan_opening_on_a_choice_yields_to_a_time_sliced_task_before_it_scores() -> void:
	# Arrange: a clock always past the slice
	var board: Dictionary = _boss_choice_on_the_players_turn()
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	var boss_ai: BossAI = _boss_ai(board.fixture, board.db, _stream())
	var ticks: Array[int] = [0]
	var clock: Callable = func() -> int:
		ticks[0] += 1
		return ticks[0]
	var task: TimeSlicedPlannerTask = TimeSlicedPlannerTask.new(1, clock)

	# Act
	task.start(boss_ai.plan_task(sandbox, task))
	var scored_inside_start: bool = not boss_ai.last_choice.is_empty()
	var live_after_start: bool = task.is_live()
	while not task.poll():
		pass
	sandbox.end_match()

	# Assert
	assert_bool(scored_inside_start).is_false()
	assert_bool(live_after_start).is_true()
	assert_int((task.result() as TurnPlan).commands.size()).is_equal(1)


func test_a_plan_with_a_choice_it_cannot_answer_ends_with_a_fault() -> void:
	# Arrange: a request with no options is one `choose` leaves alone
	var board: Dictionary = _boss_choice_on_the_players_turn()
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	(sandbox.state().pending_choice.options as Array).clear()
	var boss_ai: BossAI = _boss_ai(board.fixture, board.db, _stream())
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()

	# Act
	task.start(boss_ai.plan_task(sandbox, task))
	var plan: TurnPlan = task.result()
	sandbox.end_match()

	# Assert: never the silent stop it was (review `boss_ai.gd:636`)
	assert_array(plan.commands).is_empty()
	assert_int(plan.diagnostics.size()).is_equal(1)
	assert_str(str(plan.diagnostics[0][TurnPlan.EVENT_KEY])).is_equal(BossAI.EVENT_FAULT)
	assert_str(str(plan.diagnostics[0].reason)).is_equal(BossAI.FAULT_CHOICE_UNANSWERED)


func test_a_players_pending_choice_is_never_scored() -> void:
	# Arrange
	var fixture: Dictionary = _discover_fixture()
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = _engine(fixture, db)
	var stream: TestRngStream = _stream()

	# Act
	var decision: Dictionary = Chooser.choose(engine, _request(DISCOVER, ["bai_squire", "bai_page"], SIDE_PLAYER), BossAiBoard.profile(fixture), _op_values(), stream, db, SIDE_BOSS)

	# Assert
	assert_int(int(decision.index)).is_equal(Chooser.NO_OPTION)
	assert_dict(decision.diagnostic).is_empty()
	assert_int(stream.draws).is_equal(0)


func test_choose_leaves_the_sandbox_untouched() -> void:
	# Arrange
	var fixture: Dictionary = _discover_fixture()
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = _engine(fixture, db)
	var sandbox: RulesEngine = engine.clone()
	var before: Dictionary = sandbox.state().players[SIDE_BOSS].duplicate(true)
	var match_draws: int = sandbox.rng_match().draws

	# Act
	@warning_ignore("return_value_discarded")
	Chooser.choose(sandbox, _request(DISCOVER, fixture.options), BossAiBoard.profile(fixture), _op_values(), _stream(), db, SIDE_BOSS)

	# Assert
	assert_dict(sandbox.state().players[SIDE_BOSS]).is_equal(before)
	assert_int(sandbox.rng_match().draws).is_equal(match_draws)
	sandbox.end_match()


# --- C4: the sandbox answers its own Choices with C7 -------------------------------------

func _trial_entry(fixture: Dictionary, context: Dictionary) -> Dictionary:
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = _engine(fixture, db)
	var base: RulesEngine = engine.clone()
	var profile: Dictionary = BossAiBoard.profile(fixture)
	profile.choice_preference = {}
	var scorer: Scorer = Scorer.new(db, BossAiBoard.keyword_values(), _op_values())
	var entry: Dictionary = scorer.score(MatchRecords.play_card(SIDE_BOSS, 0, null, null), base, profile, Scorer.MODE_NORMAL, context)
	base.end_match()
	return entry


func test_a_trial_answers_its_own_choice_with_c7_and_never_advances_the_fork() -> void:
	# Arrange — bai_fork: option 0 heals (0.6), option 1 hits the player's hero (1.0)
	var fixture: Dictionary = _choose_one_fixture()
	fixture.boss.hand = ["bai_fork"]
	var sim: RngStream = _stream().fork(TieBreak.sim_label(2))
	var sim_draws: int = sim.draws

	# Act
	var entry: Dictionary = _trial_entry(fixture, {Scorer.CONTEXT_SIM_STREAM: sim})

	# Assert — the trial took option 1, so the player's hero was hit
	assert_float(float(entry.features.f_face)).is_greater(0.0)
	assert_int(sim.draws).is_equal(sim_draws)


func test_without_a_sim_stream_a_trial_still_answers_with_c7() -> void:
	# Arrange — no C4 fork: the trial's copy of `rng_match` serves its random effects
	var fixture: Dictionary = _choose_one_fixture()
	fixture.boss.hand = ["bai_fork"]

	# Act
	var entry: Dictionary = _trial_entry(fixture, {})

	# Assert
	assert_float(float(entry.features.f_face)).is_greater(0.0)


func test_a_scorer_without_op_values_answers_at_the_c6_fallback_row() -> void:
	# Arrange — every op values 1.0, so bai_fork ties and either option is a real answer
	var fixture: Dictionary = _choose_one_fixture()
	fixture.boss.hand = ["bai_fork"]
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var base: RulesEngine = _engine(fixture, db).clone()
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var scorer: Scorer = Scorer.new(db, BossAiBoard.keyword_values())

	# Act
	var entry: Dictionary = scorer.score(MatchRecords.play_card(SIDE_BOSS, 0, null, null), base, profile, Scorer.MODE_NORMAL, {})
	base.end_match()

	# Assert — the placeholder flag is gone with the placeholder
	assert_bool(entry.has("sim_choice_placeholder")).is_false()


# --- the join with plan_turn and the lethal search (QA "choose inside a plan") -------------

func test_a_plan_answers_a_choose_one_with_choose_and_holds_the_command() -> void:
	# Arrange — default profile: `jab` 1.0 beats `mend` 0.6
	var fixture: Dictionary = _choose_one_fixture()
	fixture.profile = "default"
	fixture.boss.hand = ["bai_fork"]

	# Act
	var result: Dictionary = _planned(fixture, _stream(AI_SEED))
	var plan: TurnPlan = result.plan

	# Assert
	var commands: Array = _choose_commands(plan)
	var choices: Array = _choices(plan)
	assert_int(commands.size()).is_equal(1)
	assert_int(int(commands[0].option_index)).is_equal(1)
	assert_int(choices.size()).is_equal(1)
	assert_int((choices[0].alternatives as Array).size()).is_equal(2)
	assert_bool(choices[0].has("sim_choice_placeholder")).is_false()
	for command: Dictionary in plan.commands:
		assert_bool((result.engine as RulesEngine).submit(command.duplicate(true)).accepted).is_true()


func test_a_plan_answers_a_real_discover_and_the_replay_takes_the_best_card() -> void:
	# Arrange — boss_turns_taken 1, next turn's mana_max 2: all three fit; bai_ace is
	# worth most; mana 0 keeps the discovered card in hand
	var fixture: Dictionary = _choose_one_fixture()
	fixture.profile = "default"
	fixture.boss.hand = ["bai_seer"]
	fixture.boss.mana = 0

	# Act
	var result: Dictionary = _planned(fixture, _stream(AI_SEED))
	var plan: TurnPlan = result.plan
	var engine: RulesEngine = result.engine
	for command: Dictionary in plan.commands:
		assert_bool(engine.submit(command.duplicate(true)).accepted).is_true()

	# Assert
	var held: Array = (engine.state().players[SIDE_BOSS].hand as Array).map(func(card: Dictionary) -> String: return str(card.def_id))
	assert_int(_choose_commands(plan).size()).is_equal(1)
	assert_int((_choices(plan)[0].alternatives as Array).size()).is_equal(3)
	assert_array(held).contains(["bai_ace"])


func test_a_choice_tie_on_the_root_sandbox_is_one_draw_counted_in_ai_draws() -> void:
	# Arrange — bai_twin's two options score alike; trials draw from their own copies
	var fixture: Dictionary = _choose_one_fixture()
	fixture.profile = "default"
	fixture.boss.hand = ["bai_twin"]
	var stream: TestRngStream = _stream(AI_SEED)

	# Act
	var plan: TurnPlan = _planned(fixture, stream).plan

	# Assert
	assert_int(int(_choices(plan)[0].get("draws", 0))).is_equal(1)
	assert_int(plan.ai_draws).is_equal(stream.draws)


func test_a_lethal_plan_answers_with_choose_and_logs_the_lethal_mode() -> void:
	# Arrange — only `jab` (5) reaches the player's 5 health: option 0 would heal
	var fixture: Dictionary = _choose_one_fixture()
	fixture.profile = "default"
	fixture.boss.hand = ["bai_fork"]
	fixture.player.health = 5

	# Act
	var plan: TurnPlan = _planned(fixture, _stream(AI_SEED)).plan

	# Assert
	assert_array(plan.mode_trace).contains([Scorer.MODE_LETHAL])
	assert_int(int(_choose_commands(plan)[0].option_index)).is_equal(1)
	assert_str(str(_choices(plan)[0].mode)).is_equal(String(Scorer.MODE_LETHAL))


func test_the_lethal_search_finds_a_lethal_only_the_scored_option_reaches() -> void:
	# Arrange — option 0 heals; only `jab` (5) reaches the player's 5 health
	var fixture: Dictionary = _choose_one_fixture()
	fixture.profile = "default"
	fixture.boss.hand = ["bai_fork"]
	fixture.player.health = 5
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var base: RulesEngine = _engine(fixture, db).clone()
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var lethal: LethalSearch = LethalSearch.new(db, CandidateSet.new(db, _op_values(), profile.synergy_tags))

	# Act
	var steps: Variant = await lethal.search(base, profile, profile.budgets, ImmediatePlannerTask.new(), _stream(AI_SEED).fork(TieBreak.sim_label(2)))
	base.end_match()

	# Assert
	assert_bool(steps is Array).is_true()


func test_the_lethal_search_answers_a_node_choice_from_the_nodes_own_stream() -> void:
	# Arrange
	var fixture: Dictionary = _choose_one_fixture()
	fixture.profile = "default"
	fixture.boss.hand = ["bai_twin"]
	fixture.player.health = 1
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var base: RulesEngine = _engine(fixture, db).clone()
	var profile: Dictionary = BossAiBoard.profile(fixture)
	var lethal: LethalSearch = LethalSearch.new(db, CandidateSet.new(db, _op_values(), profile.synergy_tags))
	var sim: RngStream = _stream(AI_SEED).fork(TieBreak.sim_label(2))
	var sim_draws: int = sim.draws
	var base_draws: int = (base.rng_match() as RngStream).draws

	# Act
	var steps: Variant = await lethal.search(base, profile, profile.budgets, ImmediatePlannerTask.new(), sim)
	var base_after: int = (base.rng_match() as RngStream).draws
	base.end_match()

	# Assert — a tie drawn at a node moves neither the fork nor the root
	assert_bool(steps is Array).is_true()
	assert_int(sim.draws).is_equal(sim_draws)
	assert_int(base_after).is_equal(base_draws)
