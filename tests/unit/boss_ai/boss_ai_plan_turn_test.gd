## Unit tests for `BossAI.plan_turn`, the C2 action loop (story
## boss-ai-match-driver/story-008; design/gdd/boss-ai.md C1-C4, C9, States and
## Transitions, Edge Cases "Legality and the command loop", A1, A3, A5, A10, A24,
## A27, and the turn-level clauses of A6, A7, A9; ADR-0006; TR-boss-ai-001,
## TR-boss-ai-002).
##
## Boards are `tests/fixtures/boss_ai/` setups on the production `EffectResolver`
## ([BossAiBoard]); `plan_turn` runs through `ImmediatePlannerTask` (no worker,
## ADR-0006). Doubles of the sandbox (a rejection, an empty `legal_commands()`) come
## from [method BossAiBoard.adopt]: those paths cannot arise on a real engine (A23).
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const AI_SEED: int = 7


## A sandbox whose first [member reject_left] non-`end_turn` commands are rejected.
class RejectingEngine:
	extends RulesEngine

	const CODE: String = "ILLEGAL_TARGET"

	var reject_left: int = 3
	var reject_end_turn: bool = false
	var end_turn_attempts: int = 0

	func submit(command: Dictionary) -> Dictionary:
		if str(command.type) == MatchRecords.CMD_END_TURN:
			end_turn_attempts += 1
			if reject_end_turn:
				return MatchRecords.command_result(false, CODE, "scripted")
		elif reject_left > 0:
			reject_left -= 1
			return MatchRecords.command_result(false, CODE, "scripted")
		return super(command)


## A [Scorer] that remembers each `score_all` context.
class SpyScorer:
	extends Scorer

	var contexts: Array[Dictionary] = []

	func score_all(sandbox: RulesEngine, candidates: Array, profile: Dictionary, mode: StringName, context: Dictionary, planner: PlannerTask) -> Array:
		contexts.append(context)
		return await super(sandbox, candidates, profile, mode, context, planner)


## A sandbox that lists nothing: a rules fault (Edge Cases).
class EmptyEngine:
	extends RejectingEngine

	func legal_commands() -> Array:
		return []


# --- helpers -----------------------------------------------------------------

func _board(name: String, band: int = -1) -> Dictionary:
	var fixture: Dictionary = BossAiBoard.read(name)
	if band > 0:
		fixture.band = band
	return _laid_out(fixture)


func _laid_out(fixture: Dictionary, ai_seed: int = AI_SEED) -> Dictionary:
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = BossAiBoard.engine(fixture, db, [], log)
	var stream: RngStream = TestRngStream.seeded("ai_1", ai_seed)
	return {"fixture": fixture, "db": db, "engine": engine, "log": log, "stream": stream, "ai": _ai(fixture, db, stream, log)}


func _ai(fixture: Dictionary, db: Variant, stream: RngStream, log: Variant) -> BossAI:
	var stub: Dictionary = BossAiBoard.stub_config()
	return BossAI.new(CardFactory.make_boss_def("boss_test", int(fixture.band)), BossAiBoard.profile(fixture), int(fixture.band), stream, stub.op_values, log, db, stub.keyword_values)


## The plan of one boss turn on a clone of [param board]'s engine, through the task
## seam; the sandbox is ended and left in `board.sandbox` for reading.
func _plan(board: Dictionary) -> TurnPlan:
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	var plan: TurnPlan = _run(board.ai, sandbox)
	sandbox.end_match()
	board["sandbox"] = sandbox
	return plan


func _run(ai: BossAI, sandbox: RulesEngine) -> TurnPlan:
	var task: ImmediatePlannerTask = ImmediatePlannerTask.new()
	task.start(ai.plan_task(sandbox, task))
	assert_bool(task.poll()).is_true()
	return task.result()


func _replay(engine: RulesEngine, plan: TurnPlan) -> void:
	for command: Dictionary in plan.commands:
		assert_bool(engine.submit(command.duplicate(true)).accepted).is_true()


func _events(plan: TurnPlan, event: String) -> Array:
	return plan.diagnostics.filter(func(d: Dictionary) -> bool: return str(d[TurnPlan.EVENT_KEY]) == event)


func _decisions(plan: TurnPlan) -> Array:
	return _events(plan, BossAI.EVENT_DECISION)


func _player_health(engine: RulesEngine) -> int:
	return engine.health(engine.state().players[SIDE_PLAYER].hero)


func _types(commands: Array) -> Array:
	return commands.map(func(c: Dictionary) -> String: return str(c.type))


## Ten boss turns from one seed: the plans, the `ai_<floor>` draws per turn, the
## log, and `script`, the command list of the match: `{player, boss}` per turn,
## after the mulligan [method BossAiBoard.started_match] submits.
func _ten_turns(fixture: Dictionary) -> Dictionary:
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var log: TestEventLog = TestEventLog.new()
	var started: Dictionary = BossAiBoard.started_match(fixture, db, int(fixture.run_seed), log)
	var engine: RulesEngine = started.engine
	var stream: RngStream = started.config.rng_ai
	var ai: BossAI = _ai(fixture, db, stream, log)
	var plans: Array[TurnPlan] = []
	var ai_draws: Array[int] = []
	var match_moved: Array[int] = []
	var commands: Array = []
	var script: Array = []
	while plans.size() < int(fixture.boss_turns):
		var player_commands: Array = []
		_script_player_turn(engine, fixture, player_commands)
		assert_str(String(engine.active_side())).is_equal(SIDE_BOSS)
		var stream_before: int = stream.draws
		var match_stream: RngStream = engine.rng_match()
		var match_before: int = match_stream.draws
		var sandbox: RulesEngine = engine.clone()
		var plan: TurnPlan = _run(ai, sandbox)
		match_moved.append(match_stream.draws - match_before)
		sandbox.end_match()
		ai_draws.append(stream.draws - stream_before)
		plans.append(plan)
		commands.append_array(plan.commands)
		script.append({"player": player_commands, "boss": plan.commands.duplicate(true)})
		_replay(engine, plan)
		assert_str(engine.phase()).is_equal(MatchState.PHASE_MAIN)
	return {"plans": plans, "ai_draws": ai_draws, "match_moved": match_moved, "commands": commands, "engine": engine, "log": log, "script": script}


## One player turn of [param fixture], each command also appended to [param recorded].
func _script_player_turn(engine: RulesEngine, fixture: Dictionary, recorded: Array = []) -> void:
	for step: Variant in fixture.player_script:
		if str(step) == "end":
			var end: Dictionary = MatchRecords.end_turn(SIDE_PLAYER)
			recorded.append(end.duplicate(true))
			assert_bool(engine.submit(end).accepted).is_true()
			continue
		for command: Dictionary in engine.legal_commands():
			if str(command.type) == MatchRecords.CMD_PLAY_CARD:
				recorded.append(command.duplicate(true))
				assert_bool(engine.submit(command).accepted).is_true()
				break


func _submit_all(engine: RulesEngine, commands: Array) -> void:
	for command: Dictionary in commands:
		assert_bool(engine.submit(command.duplicate(true)).accepted).is_true()


## A3's replay of [param script]: a new match from the fixture's seed, so a new
## `ai_<floor>` stream from its `stream_seed`, moved only by the recorded commands.
## The planner never drives this engine: each boss turn it plans on a clone, as a
## witness of the draw count, and the recorded commands are what is submitted.
func _replay_turns(fixture: Dictionary, script: Array) -> Dictionary:
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var log: TestEventLog = TestEventLog.new()
	var started: Dictionary = BossAiBoard.started_match(fixture, db, int(fixture.run_seed), log)
	var engine: RulesEngine = started.engine
	var stream: RngStream = started.config.rng_ai
	var ai: BossAI = _ai(fixture, db, stream, log)
	var ai_draws: Array[int] = []
	var commands: Array = []
	for turn: Dictionary in script:
		_submit_all(engine, turn.player)
		var stream_before: int = stream.draws
		var sandbox: RulesEngine = engine.clone()
		var plan: TurnPlan = _run(ai, sandbox)
		sandbox.end_match()
		ai_draws.append(stream.draws - stream_before)
		commands.append_array(plan.commands)
		_submit_all(engine, turn.boss)
	return {"ai_draws": ai_draws, "commands": commands}


func _canonical_decisions(result: Dictionary) -> String:
	var all: Array = []
	for plan: TurnPlan in result.plans:
		all.append_array(_decisions(plan))
	return EventLogAssertions.canonical_json(all)


# --- A1: determinism --------------------------------------------------------------

func test_ten_boss_turns_from_one_seed_give_byte_identical_decisions() -> void:
	# Arrange
	var fixture: Dictionary = BossAiBoard.read("scripted_player_10_turns")

	# Act
	var first: Dictionary = _ten_turns(fixture)
	var second: Dictionary = _ten_turns(fixture)

	# Assert
	assert_int((first.plans as Array).size()).is_equal(int(fixture.boss_turns))
	assert_str(_canonical_decisions(first)).is_equal(_canonical_decisions(second))
	assert_bool(_canonical_decisions(first).length() > 0).is_true()


func test_turn_plan_to_dict_is_json_representable() -> void:
	# Arrange
	var result: Dictionary = _ten_turns(BossAiBoard.read("scripted_player_10_turns"))

	for plan: TurnPlan in result.plans:
		# Act
		var dict: Dictionary = plan.to_dict()

		# Assert
		GameAssertions.assert_json_representable(dict, "TurnPlan.to_dict()")
		assert_bool((dict.mode_trace as Array).all(func(mode: Variant) -> bool: return mode is String)).is_true()


# --- A3 / A5: draw accounting ------------------------------------------------------

func test_a_logged_match_replays_from_its_seed_and_command_list_with_no_planner() -> void:
	# Arrange — the commands alone must rebuild the match: a planner that left a
	# trace on the live engine could not be replayed without it
	var fixture: Dictionary = BossAiBoard.read("scripted_player_10_turns")
	var original: Dictionary = _ten_turns(fixture)
	var log: TestEventLog = TestEventLog.new()
	var started: Dictionary = BossAiBoard.started_match(fixture, BossAiBoard.database(fixture), int(fixture.run_seed), log)
	var engine: RulesEngine = started.engine

	# Act
	for turn: Dictionary in original.script:
		_submit_all(engine, turn.player)
		_submit_all(engine, turn.boss)

	# Assert — rng-event-log F6, and the stream stands where the original's does
	EventLogAssertions.assert_replay_equal(log, original.log, "replayed and original logs")
	assert_int((engine.rng_match() as RngStream).draws).is_equal(((original.engine as RulesEngine).rng_match() as RngStream).draws)
	assert_int((engine.rng_match() as RngStream).draws).is_greater(0)


func test_ai_draws_per_turn_replayed_from_the_seed_and_commands_equal_the_original_and_tie_draws_plus_the_new_fork() -> void:
	# Arrange — a tie set of size > 1 takes one draw; each turn forks sim_<turn> once
	var fixture: Dictionary = BossAiBoard.read("scripted_player_10_turns")
	var original: Dictionary = _ten_turns(fixture)

	# Act
	var replayed: Dictionary = _replay_turns(fixture, original.script)

	# Assert
	assert_that(replayed.ai_draws).is_equal(original.ai_draws)
	assert_that(replayed.commands).is_equal(original.commands)
	var tie_draws_seen: int = 0
	for index: int in (original.plans as Array).size():
		var plan: TurnPlan = original.plans[index]
		var tie_draws: int = _decisions(plan).filter(func(d: Dictionary) -> bool: return int(d.get("tie_set_size", 1)) > 1).size()
		tie_draws_seen += tie_draws
		assert_int(original.ai_draws[index]).is_equal(tie_draws + 1)
		assert_int(plan.ai_draws).is_equal(original.ai_draws[index])
	assert_int(tie_draws_seen).is_greater(0)


func test_planning_never_moves_the_live_match_stream() -> void:
	# Arrange — a real match; random removal is among the boss's candidates
	var fixture: Dictionary = BossAiBoard.read("scripted_player_10_turns")

	# Act
	var result: Dictionary = _ten_turns(fixture)

	# Assert
	for moved: int in result.match_moved:
		assert_int(moved).is_equal(0)


func test_a_second_plan_on_the_same_turn_forks_nothing_new() -> void:
	# Arrange — sim_<turn> exists after the first plan
	var board: Dictionary = _board("f1_worked_example")
	var first: TurnPlan = _plan(board)
	var draws: int = (board.stream as RngStream).draws

	# Act
	var second: TurnPlan = _plan(board)

	# Assert — one parent draw the first time, none the second (no tie set here)
	assert_int(first.ai_draws).is_equal(1)
	assert_int(second.ai_draws).is_equal(0)
	assert_int((board.stream as RngStream).draws).is_equal(draws)


func test_play_turn_moves_the_match_stream_only_by_the_engines_own_draws() -> void:
	# Arrange — two equal boards: one played through play_turn, one planned on a
	# clone and replayed by hand; the random spell makes the engine draw
	var fixture: Dictionary = BossAiBoard.read("random_effect_board")
	var played: Dictionary = _laid_out(fixture.duplicate(true))
	var planned: Dictionary = _laid_out(fixture.duplicate(true))
	var played_stream: RngStream = (played.engine as RulesEngine).rng_match()
	var planned_stream: RngStream = (planned.engine as RulesEngine).rng_match()
	var before: int = played_stream.draws

	# Act
	await (played.ai as BossAI).play_turn(played.engine)
	var plan: TurnPlan = _plan(planned)
	var sandbox_draws: int = ((planned.sandbox as RulesEngine).rng_match() as RngStream).draws
	_replay(planned.engine, plan)

	# Assert
	assert_int(played_stream.draws).is_greater(before)
	assert_int(played_stream.draws).is_equal(planned_stream.draws)
	assert_int(sandbox_draws).is_equal(planned_stream.draws)
	assert_int((played.stream as RngStream).draws).is_equal(plan.ai_draws)


func test_play_turn_appends_each_diagnostic_before_its_command_with_cause_zero() -> void:
	# Arrange
	var board: Dictionary = _board("f1_worked_example")
	var log: TestEventLog = board.log
	var from: int = log.events.size()

	# Act
	await (board.ai as BossAI).play_turn(board.engine)

	# Assert — the commit, then decision and that command's first event, three times over
	var turn_events: Array = log.events.slice(from)
	var decisions: Array = turn_events.filter(func(e: Dictionary) -> bool: return str(e.type) == BossAI.EVENT_DECISION)
	assert_int(decisions.size()).is_equal(3)
	for decision: Dictionary in decisions:
		assert_int(int(decision.cause_seq)).is_equal(0)
		assert_bool(decision.payload.diagnostic).is_true()
		assert_bool(decision.payload.has(TurnPlan.EVENT_KEY)).is_false()
	assert_str(str(turn_events[0].type)).is_equal(BossAI.EVENT_INTENT_COMMITTED)
	assert_int(int(turn_events[0].cause_seq)).is_equal(0)
	assert_str(str(turn_events[1].type)).is_equal(BossAI.EVENT_DECISION)
	assert_str(String((board.engine as RulesEngine).active_side())).is_equal(SIDE_PLAYER)


# --- C4 sandbox stream ----------------------------------------------------------------

func test_a_trial_outcome_does_not_follow_the_live_stream() -> void:
	# Arrange — the same fork at each live position of the fixture; the first
	# scoring pass sees the same board, so its features must match
	var expect: Dictionary = BossAiBoard.read("random_effect_board").expect
	var features: Array = []
	for offset: Variant in expect.live_offsets:
		var board: Dictionary = _laid_out(BossAiBoard.read("random_effect_board"), int(expect.ai_seed))
		var stream: RngStream = (board.engine as RulesEngine).rng_match()
		for _i: int in int(offset):
			@warning_ignore("return_value_discarded")
			stream.randi32()
		var live_before: int = stream.draws

		# Act
		var plan: TurnPlan = _plan(board)

		# Assert — planning left the live stream alone, and the root sandbox moved
		# only by what it accepted: replaying lands on the same position
		assert_int(stream.draws).is_equal(live_before)
		var root_draws: int = ((board.sandbox as RulesEngine).rng_match() as RngStream).draws
		_replay(board.engine, plan)
		assert_int(stream.draws).is_equal(root_draws)
		features.append(EventLogAssertions.canonical_json(_decisions(plan)[0].alternatives))

	# Assert
	assert_str(features[0]).is_equal(features[1])


func test_every_score_all_of_the_turn_gets_the_turns_sim_fork() -> void:
	# Arrange — two random spells: at least two scoring passes
	var fixture: Dictionary = BossAiBoard.read("random_effect_board")
	fixture.boss.hand = ["bai_dice", "bai_dice"]
	var board: Dictionary = _laid_out(fixture)
	var spy: SpyScorer = SpyScorer.new(board.db, BossAiBoard.keyword_values())
	(board.ai as BossAI)._scorer = spy
	var label: String = TieBreak.sim_label(int((board.engine as RulesEngine).state().turn))

	# Act
	@warning_ignore("return_value_discarded")
	_plan(board)

	# Assert — the very object of the memoised fork, which takes no further draw
	var draws: int = (board.stream as RngStream).draws
	var sim: RngStream = (board.stream as RngStream).fork(label)
	assert_int((board.stream as RngStream).draws).is_equal(draws)
	assert_int(spy.contexts.size()).is_greater(1)
	for context: Dictionary in spy.contexts:
		assert_object(context[Scorer.CONTEXT_SIM_STREAM]).is_same(sim)


# --- N3: collect → score_all → pick --------------------------------------------------

func test_the_f1_turn_runs_trade_then_play_then_end_turn_through_the_whole_pipeline() -> void:
	# Arrange — A11's board; the plain 4/4 is offered at two positions
	var board: Dictionary = _board("f1_worked_example")
	var expect: Dictionary = board.fixture.expect
	var offered: int = (board.engine as RulesEngine).legal_commands().filter(func(c: Dictionary) -> bool: return str(c.type) == MatchRecords.CMD_PLAY_CARD).size()

	# Act
	var plan: TurnPlan = _plan(board)

	# Assert — C6 drops the left position, so no size-2 tie set and no tie draw
	assert_int(offered).is_equal(2)
	assert_array(_types(plan.commands)).contains_exactly(expect.order)
	var decisions: Array = _decisions(plan)
	for index: int in (expect.scores as Array).size():
		var top: Dictionary = decisions[index].alternatives[0]
		assert_float(float(top.score)).is_equal_approx(float(expect.scores[index]), float(expect.tolerance))
		assert_int(int(decisions[index].tie_set_size)).is_equal(1)
	assert_int(plan.ai_draws).is_equal(1)


# --- N4: chosen and alternatives -----------------------------------------------------

func test_a_scored_decision_lists_at_most_three_alternatives_with_the_pick_among_them() -> void:
	# Arrange — the wide board: more candidates than alternatives slots
	var result: Dictionary = _ten_turns(BossAiBoard.read("scripted_player_10_turns"))

	for plan: TurnPlan in result.plans:
		for decision: Dictionary in _decisions(plan):
			# Act
			var alternatives: Array = decision.alternatives

			# Assert
			assert_int(alternatives.size()).is_less_equal(Scorer.ALTERNATIVES_MAX)
			if not alternatives.is_empty():
				assert_bool(alternatives.any(func(a: Dictionary) -> bool: return a.command == decision.chosen)).is_true()


func test_a_pick_below_the_top_slots_takes_the_last_one_and_order_stays_best_first() -> void:
	# Arrange — five tied entries; the tie-break chose the last
	var scored: Array = []
	for index: int in 5:
		scored.append({"command": {"type": "attack", "attacker_id": index}, "score": 1.0 - index * 0.01, "features": {}, "index": index})

	# Act
	var alternatives: Array = Scorer.alternatives(scored, scored[4])

	# Assert
	assert_int(alternatives.size()).is_equal(Scorer.ALTERNATIVES_MAX)
	assert_that(alternatives[2].command).is_equal(scored[4].command)
	assert_that(alternatives[0].command).is_equal(scored[0].command)
	assert_that(alternatives[1].command).is_equal(scored[1].command)


# --- A6 / A7 / A8 / A9, turn level ---------------------------------------------------

func test_lethal_on_an_open_board_is_taken_in_every_band_and_logged_lethal() -> void:
	for band: int in [1, 2, 3]:
		# Arrange
		var board: Dictionary = _board("lethal_open_face", band)

		# Act
		var plan: TurnPlan = _plan(board)
		_replay(board.engine, plan)

		# Assert
		assert_int(_player_health(board.engine)).is_less_equal(0)
		assert_str(str(_decisions(plan)[0].mode)).is_equal(String(Scorer.MODE_LETHAL))
		assert_array(plan.mode_trace).contains_exactly([Scorer.MODE_NORMAL, Scorer.MODE_LETHAL])
		assert_str((board.engine as RulesEngine).phase()).is_equal(MatchState.PHASE_ENDED)


func test_lethal_through_a_taunt_is_taken_in_bands_two_and_three() -> void:
	for band: int in [2, 3]:
		# Arrange
		var board: Dictionary = _board("lethal_through_taunt", band)

		# Act
		var plan: TurnPlan = _plan(board)
		_replay(board.engine, plan)

		# Assert
		assert_int(_player_health(board.engine)).is_less_equal(0)
		assert_str(str(_decisions(plan)[0].mode)).is_equal(String(Scorer.MODE_LETHAL))


func test_band_one_records_shallow_none_and_never_lethal_even_when_scoring_clears_the_taunt() -> void:
	# Arrange
	var board: Dictionary = _board("lethal_through_taunt", 1)

	# Act
	var plan: TurnPlan = _plan(board)

	# Assert — one search, at the top of the turn; A7 leaves the outcome open
	var decisions: Array = _decisions(plan)
	assert_str(str(decisions[0].get("lethal_search"))).is_equal(String(LethalSearch.OUTCOME_SHALLOW_NONE))
	for decision: Dictionary in decisions:
		assert_str(str(decision.mode)).is_not_equal(String(Scorer.MODE_LETHAL))
	assert_bool(plan.mode_trace.has(Scorer.MODE_LETHAL)).is_false()
	assert_int(decisions.filter(func(d: Dictionary) -> bool: return d.has("lethal_nodes")).size()).is_equal(1)
	assert_int(decisions.size()).is_greater(1)


func test_the_weapon_and_spell_line_is_taken_on_the_turn() -> void:
	# Arrange
	var board: Dictionary = _board("lethal_weapon_spell", 3)

	# Act
	var plan: TurnPlan = _plan(board)
	_replay(board.engine, plan)

	# Assert
	assert_int(_player_health(board.engine)).is_less_equal(0)
	assert_str(str(_decisions(plan)[0].mode)).is_equal(String(Scorer.MODE_LETHAL))


func test_an_f4_prune_expands_no_node_and_the_turn_plays_on() -> void:
	# Arrange
	var board: Dictionary = _board("lethal_pruned_root")

	# Act
	var plan: TurnPlan = _plan(board)

	# Assert
	var first: Dictionary = _decisions(plan)[0]
	assert_int(int(first.lethal_nodes)).is_equal(0)
	assert_str(str(first.mode)).is_equal(String(Scorer.MODE_NORMAL))
	assert_str(str(plan.commands.back().type)).is_equal(MatchRecords.CMD_END_TURN)


func test_an_exhausted_search_is_recorded_on_the_first_decision_and_scoring_completes_the_turn() -> void:
	# Arrange — six attackers leave a slot for the cub: a second decision to read
	var fixture: Dictionary = BossAiBoard.read("lethal_shield_wall")
	fixture["budgets"] = {"lethal_max_nodes": 30}
	(fixture.boss.board as Array).pop_back()
	fixture.boss.hand = ["bai_cub"]
	fixture.boss.mana = 2
	fixture.player.health = 7
	var board: Dictionary = _laid_out(fixture)

	# Act
	var plan: TurnPlan = _plan(board)

	# Assert — only the first decision carries it; the turn ends normally
	var decisions: Array = _decisions(plan)
	assert_str(str(decisions[0].mode)).is_equal(String(LethalSearch.OUTCOME_EXHAUSTED))
	assert_int(int(decisions[0].lethal_nodes)).is_equal(30)
	assert_str(str(decisions[1].mode)).is_equal(String(Scorer.MODE_NORMAL))
	assert_array(plan.mode_trace).contains_exactly([Scorer.MODE_NORMAL])
	assert_str(str(plan.commands.back().type)).is_equal(MatchRecords.CMD_END_TURN)


# --- A10: divergence ------------------------------------------------------------------

func _divergence_board() -> Dictionary:
	var fixture: Dictionary = BossAiBoard.read("deathrattle_taunt_divergence")
	var board: Dictionary = _laid_out(fixture, int(fixture.expect.ai_seed))
	var stream: RngStream = (board.engine as RulesEngine).rng_match()
	for _i: int in int(fixture.expect.live_offset):
		@warning_ignore("return_value_discarded")
		stream.randi32()
	return board


func test_a_plan_whose_deathrattle_summons_a_taunt_aborts_once_and_the_turn_completes() -> void:
	# Arrange
	var board: Dictionary = _divergence_board()

	# Act
	var plan: TurnPlan = _plan(board)

	# Assert — the Taunt fell, the fork spared the bomb, the sandbox did not
	var aborted: Array = _events(plan, BossAI.EVENT_PLAN_ABORTED)
	assert_int(aborted.size()).is_equal(1)
	assert_str(str(aborted[0].reason)).is_equal(BossAI.ABORT_DIVERGED)
	assert_int(int(aborted[0].at_step)).is_equal(1)
	assert_bool(aborted[0].diagnostic).is_true()
	var decisions: Array = _decisions(plan)
	assert_str(str(decisions[0].mode)).is_equal(String(Scorer.MODE_LETHAL))
	assert_str(str(decisions.back().mode)).is_equal(String(Scorer.MODE_NORMAL))
	assert_array(plan.mode_trace).contains_exactly([Scorer.MODE_NORMAL, Scorer.MODE_LETHAL, Scorer.MODE_NORMAL])
	assert_str(str(plan.commands.back().type)).is_equal(MatchRecords.CMD_END_TURN)
	# no rejected command: every one replays on the live engine
	_replay(board.engine, plan)
	assert_bool(decisions.any(func(d: Dictionary) -> bool: return d.has("rejection"))).is_false()


func test_the_abort_allows_exactly_one_more_search() -> void:
	# Arrange
	var board: Dictionary = _divergence_board()

	# Act
	var plan: TurnPlan = _plan(board)

	# Assert — the first search and the one after the abort, no third
	var searched: Array = _decisions(plan).filter(func(d: Dictionary) -> bool: return d.has("lethal_nodes"))
	assert_int(searched.size()).is_equal(2)


func test_the_abort_is_routed_before_the_next_command_and_the_mode_change_is_logged() -> void:
	# Arrange
	var board: Dictionary = _divergence_board()

	# Act
	var plan: TurnPlan = _plan(board)

	# Assert
	var aborted: Dictionary = _events(plan, BossAI.EVENT_PLAN_ABORTED)[0]
	assert_int(int(aborted[TurnPlan.COMMAND_INDEX_KEY])).is_equal(1)
	assert_bool(plan.diagnostics_before(1).has(aborted)).is_true()
	var decisions: Array = _decisions(plan)
	assert_that(decisions[0].mode_transition).is_equal({"from": "NORMAL", "to": "LETHAL"})
	assert_that(decisions[1].mode_transition).is_equal({"from": "LETHAL", "to": "NORMAL"})


func test_a_plan_that_runs_out_with_the_player_alive_is_aborted_too() -> void:
	# Arrange — a burn at a random enemy character: where the fork hits the hero and
	# the sandbox hits the 1/1, every step stays legal and the player lives. The
	# sweep finds those pairs of fork and live position
	var reasons: Array = []
	for ai_seed: int in range(1, 7):
		for offset: int in range(0, 6):
			var fixture: Dictionary = BossAiBoard.read("lethal_weapon_spell")
			fixture.cards[3].effects[0].targets = "random_enemy_character"
			fixture.cards.append({"id": "bai_pawn", "type": "minion", "cost": 1, "attack": 1, "health": 1})
			fixture.boss.hand = ["bai_bolt"]
			fixture.player.board = ["bai_pawn"]
			fixture.player.health = 3
			var board: Dictionary = _laid_out(fixture, ai_seed)
			var stream: RngStream = (board.engine as RulesEngine).rng_match()
			for _i: int in offset:
				@warning_ignore("return_value_discarded")
				stream.randi32()

			# Act
			var plan: TurnPlan = _plan(board)

			# Assert — a plan that ended the match is never aborted
			var aborted: Array = _events(plan, BossAI.EVENT_PLAN_ABORTED)
			if not aborted.is_empty() and (board.sandbox as RulesEngine).phase() != MatchState.PHASE_ENDED:
				assert_str(str(_events(plan, BossAI.EVENT_INTENT_COMMITTED)[0].intent_key)).is_not_equal(Intent.KEY_LETHAL)
			if (board.sandbox as RulesEngine).phase() == MatchState.PHASE_ENDED:
				assert_array(aborted).is_empty()
			reasons.append_array(aborted.map(func(d: Dictionary) -> String: return str(d.reason)))

	# Assert — the sweep reached the case
	assert_bool(reasons.has(BossAI.ABORT_NOT_LETHAL)).is_true()


# --- A24 ----------------------------------------------------------------------------------

func test_only_end_turn_legal_gives_one_command_and_one_unscored_decision() -> void:
	# Arrange — no board, no hand, the hero power spent
	var fixture: Dictionary = BossAiBoard.read("lethal_open_face")
	fixture.boss.board = []
	var board: Dictionary = _laid_out(fixture)

	# Act
	var plan: TurnPlan = _plan(board)

	# Assert
	assert_array(_types(plan.commands)).contains_exactly([MatchRecords.CMD_END_TURN])
	var decisions: Array = _decisions(plan)
	assert_int(decisions.size()).is_equal(1)
	assert_int(plan.diagnostics.size()).is_equal(2)
	assert_str(str(_events(plan, BossAI.EVENT_INTENT_COMMITTED)[0].intent_key)).is_equal(Intent.KEY_PASS)
	assert_str(str(decisions[0].chosen.type)).is_equal(MatchRecords.CMD_END_TURN)
	assert_array(decisions[0].alternatives).is_empty()
	assert_str(str(decisions[0].reason)).is_equal(BossAI.REASON_ONLY_MOVE)
	assert_str(str(decisions[0].kind)).is_equal(BossAI.KIND_ACTION)
	assert_bool(decisions[0].diagnostic).is_true()


func test_an_empty_legal_list_faults_tries_end_turn_once_and_never_spins() -> void:
	# Arrange
	var board: Dictionary = _board("f1_worked_example")
	var sandbox: EmptyEngine = BossAiBoard.adopt(EmptyEngine, board.engine, board.db)

	# Act
	var plan: TurnPlan = _run(board.ai, sandbox)
	sandbox.end_match()

	# Assert
	var faults: Array = _events(plan, BossAI.EVENT_FAULT)
	assert_int(faults.size()).is_equal(1)
	assert_str(str(faults[0].reason)).is_equal(BossAI.FAULT_NO_LEGAL_COMMANDS)
	assert_int(sandbox.end_turn_attempts).is_equal(1)
	assert_array(_types(plan.commands)).contains_exactly([MatchRecords.CMD_END_TURN])


func test_an_empty_legal_list_whose_end_turn_is_rejected_faults_and_returns() -> void:
	# Arrange
	var board: Dictionary = _board("f1_worked_example")
	var sandbox: EmptyEngine = BossAiBoard.adopt(EmptyEngine, board.engine, board.db)
	sandbox.reject_end_turn = true

	# Act
	var plan: TurnPlan = _run(board.ai, sandbox)
	sandbox.end_match()

	# Assert — Faulted: two faults, one attempt, no command
	assert_array(_events(plan, BossAI.EVENT_FAULT).map(func(d: Dictionary) -> String: return str(d.reason))).contains_exactly([BossAI.FAULT_NO_LEGAL_COMMANDS, BossAI.FAULT_END_TURN_REJECTED])
	assert_int(sandbox.end_turn_attempts).is_equal(1)
	assert_array(plan.commands).is_empty()


# --- A27 ----------------------------------------------------------------------------------

func test_a_zero_cost_loop_ends_at_the_action_cap() -> void:
	# Arrange
	var board: Dictionary = _board("zero_cost_loop")
	var cap: int = int(BossAiBoard.profile(board.fixture).budgets.max_actions_per_turn)

	# Act
	var plan: TurnPlan = _plan(board)

	# Assert — C2: exactly the cap of actions, then the forced end_turn
	assert_int(plan.commands.size()).is_equal(cap + 1)
	assert_str(str(plan.commands.back().type)).is_equal(MatchRecords.CMD_END_TURN)
	var last: Dictionary = _decisions(plan).back()
	assert_str(str(last.reason)).is_equal(BossAI.REASON_ACTION_CAP)
	assert_array(last.alternatives).is_empty()
	assert_int(_types(plan.commands).count(MatchRecords.CMD_PLAY_CARD)).is_equal(cap)


func test_the_action_cap_is_read_from_the_budget() -> void:
	# Arrange — the knob moved in the fixture
	var fixture: Dictionary = BossAiBoard.read("zero_cost_loop")
	var cap: int = 10
	fixture["budgets"] = {"max_actions_per_turn": cap}
	var board: Dictionary = _laid_out(fixture)

	# Act
	var plan: TurnPlan = _plan(board)

	# Assert — it never fires early: only the last decision carries the reason
	assert_int(plan.commands.size()).is_equal(cap + 1)
	var reasons: Array = _decisions(plan).filter(func(d: Dictionary) -> bool: return d.has("reason"))
	assert_int(reasons.size()).is_equal(1)


func test_three_rejections_force_end_turn_and_each_exact_command_is_excluded() -> void:
	# Arrange — three plays and an attack: more candidates than the cap on rejections
	var fixture: Dictionary = BossAiBoard.read("f1_worked_example")
	fixture.boss.hand = ["bai_ogre", "bai_ogre", "bai_ogre"]
	fixture.boss.mana = 10
	var board: Dictionary = _laid_out(fixture)
	var sandbox: RejectingEngine = BossAiBoard.adopt(RejectingEngine, board.engine, board.db)

	# Act
	var plan: TurnPlan = _run(board.ai, sandbox)
	sandbox.end_match()

	# Assert
	var decisions: Array = _decisions(plan)
	var rejected: Array = decisions.filter(func(d: Dictionary) -> bool: return d.has("rejection"))
	assert_int(rejected.size()).is_equal(BossAI.MAX_REJECTIONS)
	for decision: Dictionary in rejected:
		assert_str(str(decision.rejection)).is_equal(RejectingEngine.CODE)
	GameAssertions.assert_no_duplicates(rejected.map(func(d: Dictionary) -> String: return EventLogAssertions.canonical_json(d.chosen)), "rejected commands")
	assert_array(_types(plan.commands)).contains_exactly([MatchRecords.CMD_END_TURN])
	assert_str(str(decisions.back().chosen.type)).is_equal(MatchRecords.CMD_END_TURN)
	assert_int(int(decisions[0][TurnPlan.COMMAND_INDEX_KEY])).is_equal(0)


func test_a_rejected_end_turn_faults_and_returns() -> void:
	# Arrange — end_turn scores best (no other candidate) yet is refused
	var fixture: Dictionary = BossAiBoard.read("lethal_open_face")
	fixture.boss.board = []
	var board: Dictionary = _laid_out(fixture)
	var sandbox: RejectingEngine = BossAiBoard.adopt(RejectingEngine, board.engine, board.db)
	sandbox.reject_end_turn = true

	# Act
	var plan: TurnPlan = _run(board.ai, sandbox)
	sandbox.end_match()

	# Assert
	assert_int(sandbox.end_turn_attempts).is_equal(1)
	assert_array(plan.commands).is_empty()
	assert_str(str(_events(plan, BossAI.EVENT_FAULT)[0].reason)).is_equal(BossAI.FAULT_END_TURN_REJECTED)


# --- the plan as a whole ---------------------------------------------------------------

func test_the_checksum_of_the_live_replay_equals_the_plans() -> void:
	# Arrange — a turn with a random spell and the player's Start step after it
	var board: Dictionary = _board("random_effect_board")
	var log: TestEventLog = board.log
	var from: int = log.events.size()

	# Act
	var plan: TurnPlan = _plan(board)
	_replay(board.engine, plan)

	# Assert
	assert_int(plan.expected_checksum).is_not_equal(0)
	assert_int(TurnPlan.checksum(log.events.slice(from))).is_equal(plan.expected_checksum)


func test_a_diagnostic_on_the_log_does_not_move_the_checksum() -> void:
	# Arrange
	var game: Array = [{"type": "card_played", "payload": {}}, {"type": "turn_ended", "payload": {}}]
	var noisy: Array = game.duplicate()
	noisy.insert(1, {"type": "ai_decision", "payload": {"diagnostic": true}})

	# Act
	var clean: int = TurnPlan.checksum(game)
	var with_noise: int = TurnPlan.checksum(noisy)

	# Assert
	assert_int(with_noise).is_equal(clean)
	assert_int(TurnPlan.checksum(game.slice(0, 1))).is_not_equal(clean)


func test_planning_writes_nothing_to_the_live_log() -> void:
	# Arrange
	var board: Dictionary = _board("f1_worked_example")
	var log: TestEventLog = board.log
	var events: int = log.events.size()

	# Act
	@warning_ignore("return_value_discarded")
	_plan(board)

	# Assert
	assert_int(log.events.size()).is_equal(events)
	assert_str((board.engine as RulesEngine).phase()).is_equal(MatchState.PHASE_MAIN)
	assert_str(String((board.engine as RulesEngine).active_side())).is_equal(SIDE_BOSS)


func test_a_plan_outside_the_sides_main_is_empty() -> void:
	# Arrange — the boss's turn is over on this clone
	var board: Dictionary = _board("f1_worked_example")
	var sandbox: RulesEngine = (board.engine as RulesEngine).clone()
	assert_bool(sandbox.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()
	assert_bool(sandbox.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	sandbox.state().phase = MatchState.PHASE_ENDED

	# Act
	var plan: TurnPlan = _run(board.ai, sandbox)
	sandbox.end_match()

	# Assert
	assert_array(plan.commands).is_empty()
	assert_array(plan.diagnostics).is_empty()
	assert_int(plan.ai_draws).is_equal(0)


func test_a_trial_that_overflows_is_never_chosen_and_the_decision_says_so() -> void:
	# Arrange — every attack kills the Taunt, whose queued Deathrattle passes a step
	# cap of one on the trial; end_turn is left
	var fixture: Dictionary = BossAiBoard.read("lethal_through_taunt")
	fixture.cards[3].health = 1
	fixture.cards[3].effects = [{"trigger": "deathrattle", "targets": "owner_hero", "ops": [{"op": "heal", "amount": 1}]}]
	var board: Dictionary = _laid_out(fixture)
	var sandbox: RulesEngine = BossAiBoard.adopt(RulesEngine, board.engine, board.db, {"resolution_step_cap": 1})

	# Act
	var plan: TurnPlan = _run(board.ai, sandbox)
	sandbox.end_match()

	# Assert — the `-INF` entries stay out of the payload: rule 14 has no infinity
	var decision: Dictionary = _decisions(plan)[0]
	assert_str(str(decision.chosen.type)).is_equal(MatchRecords.CMD_END_TURN)
	assert_bool(decision.sim_overflow).is_true()
	assert_array(_types(decision.alternatives.map(func(a: Dictionary) -> Dictionary: return a.command))).contains_exactly([MatchRecords.CMD_END_TURN])


func test_a_boss_discover_on_the_sandbox_is_answered_and_held_in_the_plan() -> void:
	# Arrange — the only other move is a Discover spell
	var fixture: Dictionary = BossAiBoard.read("f1_worked_example")
	fixture.cards.append({"id": "bai_seek", "type": "spell", "cost": 1, "effects": [{"trigger": "cast", "ops": [{"op": "discover", "pool": "list", "list": ["bai_ogre", "bai_brute", "bai_wall"], "then": "add_to_hand"}]}]})
	fixture.boss.hand = ["bai_seek"]
	fixture.boss.board = []
	var board: Dictionary = _laid_out(fixture)

	# Act
	var plan: TurnPlan = _plan(board)

	# Assert
	assert_bool(_types(plan.commands).has(MatchRecords.CMD_CHOOSE)).is_true()
	var choice: Array = _decisions(plan).filter(func(d: Dictionary) -> bool: return str(d.kind) == BossAI.KIND_CHOICE)
	assert_int(choice.size()).is_equal(1)
	assert_str(str(choice[0].chosen.type)).is_equal(MatchRecords.CMD_CHOOSE)
	_replay(board.engine, plan)


func test_aoe_seen_comes_from_the_public_log_through_plan_task() -> void:
	# Arrange — A13's board: the 5th minion over the cap. The player cast the area
	# spell on the log; plan_task reads it on the main thread
	var fixture: Dictionary = BossAiBoard.read("aoe_seen_board")
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = BossAiBoard.engine(fixture, db, [str(fixture.aoe_cast)], log)
	var quiet_engine: RulesEngine = BossAiBoard.engine(fixture, db, [], TestEventLog.new())
	var seen: BossAI = _ai(fixture, db, TestRngStream.seeded("ai_1", AI_SEED), log)
	var unseen: BossAI = _ai(fixture, db, TestRngStream.seeded("ai_1", AI_SEED), null)

	# Act
	var sandbox: RulesEngine = engine.clone()
	var quiet_sandbox: RulesEngine = quiet_engine.clone()
	var with_log: TurnPlan = _run(seen, sandbox)
	var without: TurnPlan = _run(unseen, quiet_sandbox)
	sandbox.end_match()
	quiet_sandbox.end_match()

	# Assert — f_over charges the play only where the area spell was seen
	var over: Callable = func(plan: TurnPlan) -> float:
		var play: Dictionary = {}
		for alternative: Dictionary in _decisions(plan)[0].alternatives:
			if str(alternative.command.type) == MatchRecords.CMD_PLAY_CARD:
				play = alternative
		return float(play.features.f_over)
	assert_float(over.call(with_log)).is_less(0.0)
	assert_float(over.call(without)).is_equal(0.0)


# --- NC-8: `planner_target_ms` is never a runtime clock ---------------------------------

## The plan of [param fixture] with `runtime.planner_target_ms` at [param target],
## built from the whole config body as the driver does, as canonical JSON.
func _plan_with_target(fixture: Dictionary, target: int) -> String:
	var config: Dictionary = BossAiBoard.stub_config()
	config.runtime.planner_target_ms = target
	var band: int = int(fixture.band)
	var boss_def: Dictionary = CardFactory.make_boss_def("boss_test", band, {"ai_profile": str(fixture.profile)})
	var profile: Dictionary = ProfileResolver.resolve(config, boss_def, band)
	var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
	var engine: RulesEngine = BossAiBoard.engine(fixture, db)
	var stream: RngStream = TestRngStream.seeded("ai_1", AI_SEED)
	var ai: BossAI = BossAI.new(boss_def, profile, band, stream, config.op_values, null, db, config.keyword_values)
	var sandbox: RulesEngine = engine.clone()
	var plan: TurnPlan = _run(ai, sandbox)
	sandbox.end_match()
	assert_array(plan.commands).is_not_empty()
	return JSON.stringify(plan.to_dict(), "", true)


func test_a_plan_is_byte_identical_at_either_end_of_the_planner_target_range() -> void:
	# Arrange — same state and seed; the Validator's bounds, 50 and 1,000
	var fixture: Dictionary = BossAiBoard.read("f1_worked_example")

	# Act
	var at_floor: String = _plan_with_target(fixture, 50)
	var at_ceiling: String = _plan_with_target(fixture, 1000)

	# Assert
	assert_str(at_floor).is_equal(at_ceiling)
