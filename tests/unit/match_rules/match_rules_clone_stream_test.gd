## Unit tests for `RulesEngine.clone(rng_override)` — a sandbox clone given
## its own random stream (code review 2026-11-04, BAI-004 S1; boss-ai C4: a
## planner trial draws from `ai_<floor>/sim_<turn>`, "an estimate, not a peek
## at the live stream"; ADR-0003 Decision 1-2 and rule 5: the override is
## derived from the `ai_<floor>` stream by `fork()` / `copy()`, never by
## forking `rng_match`; ADR-0006 / ADR-0007 clone contract).
##
## The random draw is the `discard(side, PICK_RANDOM)` primitive (one
## `rng_match.randi_range` over the hand). Streams are `TestRngStream.seeded`
## (the production generator), so `draws` is exact.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
## Seeds: the live match stream (via TestRngService) and the `ai_1` stream.
const LIVE_SEED: int = 11
const AI_SEED: int = 23
const AI_STREAM: String = "ai_1"
const SIM_LABEL: String = "sim_3"


func _engine() -> RulesEngine:
	return MatchFactory.make_started_engine(TestRngService.new(LIVE_SEED))


func _sim() -> RngStream:
	return TestRngStream.seeded(AI_STREAM, AI_SEED).fork(SIM_LABEL)


func test_clone_with_override_draws_its_random_effects_from_the_override() -> void:
	# Arrange
	var engine: RulesEngine = _engine()
	var live: RngStream = engine.rng_match()
	var live_draws: int = live.draws
	var sim: RngStream = _sim()
	var trial_stream: RngStream = sim.copy()
	var expected: RngStream = sim.copy()

	# Act
	var trial: RulesEngine = engine.clone(trial_stream)
	var hand_size: int = trial.state().players[SIDE_PLAYER].hand.size()
	var discarded: int = trial.discard(SIDE_PLAYER, MatchRecords.PICK_RANDOM)

	# Assert — the clone holds the override itself; its one draw came from it
	# (the same index a fresh copy of the fork gives), and the live stream and
	# the fork it was copied from did not move
	assert_object(trial.rng_match()).is_same(trial_stream)
	assert_int(discarded).is_not_equal(RulesEngine.NO_ENTITY)
	assert_int(trial_stream.draws).is_equal(sim.draws + 1)
	assert_int(int(trial.state().log.events_since(0).back().payload.hand_index)).is_equal(expected.randi_range(0, hand_size - 1))
	assert_int(live.draws).is_equal(live_draws)
	assert_int(sim.draws).is_equal(expected.draws - 1)
	assert_str(trial_stream.name).is_equal("%s/%s" % [AI_STREAM, SIM_LABEL])
	trial.end_match()


func test_clone_without_override_still_copies_the_live_match_stream() -> void:
	# Arrange — the default is unchanged (match-rules story 017)
	var engine: RulesEngine = _engine()
	var live: RngStream = engine.rng_match()
	var live_draws: int = live.draws

	# Act
	var trial: RulesEngine = engine.clone()
	var copied: RngStream = trial.rng_match()

	# Assert — a separate stream at the live position, same name
	assert_object(copied).is_not_same(live)
	assert_str(copied.name).is_equal(live.name)
	assert_int(copied.draws).is_equal(live_draws)
	trial.end_match()


func test_clone_of_an_overridden_clone_copies_the_override_not_the_live_stream() -> void:
	# Arrange — the scorer's base sandbox may be overridden; its trials copy it
	var engine: RulesEngine = _engine()
	var sim: RngStream = _sim()
	var base: RulesEngine = engine.clone(sim.copy())

	# Act
	var trial: RulesEngine = base.clone()

	# Assert
	assert_str(trial.rng_match().name).is_equal(sim.name)
	assert_int(trial.rng_match().draws).is_equal(sim.draws)
	assert_object(trial.rng_match()).is_not_same(base.rng_match())
	trial.end_match()
	base.end_match()
