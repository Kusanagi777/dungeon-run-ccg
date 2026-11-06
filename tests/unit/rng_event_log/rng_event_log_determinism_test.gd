## The determinism contract — F6 replay equivalence over the production
## RngService + EventLog, and the deterministic half of the restore budget.
##
## Story: production/epics/rng-event-log/story-010-determinism-contract-and-performance-budgets.md
## GDD: design/gdd/rng-event-log.md rules 8-10, F5, F6. ADR-0003 Decision 10(c):
## a scripted command sequence run twice gives byte-identical logs. Literal
## seeds and scripted sequences only: no wall clock, no global RNG, no file
## I/O. The timed budgets are the non-blocking performance suite
## (`tests/performance/rng_event_log/rng_event_log_perf_test.gd`).
extends GdUnitTestSuite

const SEED: int = TestConstants.DEFAULT_TEST_SEED
const CAP: int = TestConstants.MAX_MATCH_EVENTS
## The scripted damage roll's inclusive bounds; the variant raises the top by one.
const ROLL_LO: int = 1
const ROLL_HI: int = 6
## Restore depth of the performance AC (GDD Acceptance Criteria "Performance").
const RESTORE_DRAWS: int = 10000
const NEXT: int = 20
## F4 example weights (`weighted_pick([5, 0, 15])`).
const WEIGHTS: Array[int] = [5, 0, 15]


## One RngService + EventLog pair, as `MatchDriver` builds them.
func _pair() -> Dictionary:
	return {
		"rng": RngService.new(SEED, "test"),
		"log": EventLog.new(CAP, EventLog.SCOPE_MATCH, {"floor": 1, "data_version": "test", "run_seed_hex": RngService.to_hex_u64(SEED)}),
	}


## The scripted sequence: one command drawing on `match_1` and `ai_1` (with one
## `fork("sim_1")`) and appending nested events, then the match end.
func _play(pair: Dictionary, roll_hi: int = ROLL_HI) -> void:
	var rng: RngService = pair.rng
	var log: EventLog = pair.log
	rng.begin_command()
	var match_stream: RngStream = rng.stream("match_1")
	var ai_stream: RngStream = rng.stream("ai_1")
	log.set_turn(1)
	var turn_seq: int = log.append(&"turn_started", {"turn": 1, "side": "player"})
	var deck: Array = []
	for i: int in range(TestConstants.STARTER_DECK_SIZE):
		deck.append(i + 1)
	match_stream.shuffle(deck)
	log.append(&"deck_shuffled", {"side": "player", "instance_ids": deck}, turn_seq)
	var roll: int = match_stream.randi_range(ROLL_LO, roll_hi)
	var hit_seq: int = log.append(&"damage_dealt", {
		"source": deck[0], "target": 2, "requested": roll, "prevented": 0,
		"armor_absorbed": 0, "dealt": roll, "health_after": 30 - roll,
	}, turn_seq)
	var sim: RngStream = ai_stream.fork("sim_1")
	var plan_seq: int = log.append(&"ai_decision", {
		"diagnostic": true, "pick": sim.weighted_pick(WEIGHTS), "share": sim.randf(),
	}, hit_seq)
	log.append(&"ai_intent_shown", {"boss_id": 2, "intent_key": "strike", "target_id": 1, "amount": ai_stream.randi_range(1, 3), "effective_mode": "full"}, plan_seq)
	rng.end_command()
	log.append(&"match_ended", {"result": "win", "winner": "PLAYER", "reason": "hero_dead", "floor": 1, "turns": 1})


func _events(pair: Dictionary) -> Array:
	return (pair.log as EventLog).events_since(-1)


# --- AC-1: F6 self-test ----------------------------------------------------------

func test_the_same_scripted_sequence_twice_gives_replay_equal_byte_identical_logs() -> void:
	# Arrange
	var a: Dictionary = _pair()
	var b: Dictionary = _pair()

	# Act
	_play(a)
	_play(b)

	# Assert
	EventLogAssertions.assert_replay_equal(_events(a), _events(b))
	assert_str((b.log as EventLog).to_json()).is_equal((a.log as EventLog).to_json())
	assert_dict((b.rng as RngService).snapshot()).is_equal((a.rng as RngService).snapshot())
	assert_dict((a.rng as RngService).snapshot().streams).contains_keys(["match_1", "ai_1", "ai_1/sim_1"])
	EventLogAssertions.assert_seq_contiguous(_events(a))
	EventLogAssertions.assert_cause_seq_valid(_events(a))


func test_changing_one_draw_bound_breaks_replay_equal() -> void:
	# Arrange — scan for the first top bound that changes the roll from seed 42
	var reference: Dictionary = _pair()
	_play(reference)
	var changed: Dictionary = {}
	for hi: int in range(ROLL_HI + 1, ROLL_HI + 8):
		var candidate: Dictionary = _pair()

		# Act
		_play(candidate, hi)
		if EventLogAssertions.canonical_json(_events(candidate)) != EventLogAssertions.canonical_json(_events(reference)):
			changed = candidate
			break

	# Assert
	assert_dict(changed).override_failure_message("no bound in 7..13 changed the scripted roll").is_not_empty()
	assert_failure(func() -> void: EventLogAssertions.assert_replay_equal(_events(reference), _events(changed))).is_failed()


func test_a_cause_seq_difference_alone_breaks_replay_equal() -> void:
	# Arrange
	var a: Array = _events(_played())
	var b: Array = _events(_played())
	var tampered: Array = b.duplicate(true)
	tampered[3].cause_seq = 1

	# Act / Assert
	EventLogAssertions.assert_replay_equal(a, b)
	assert_dict(tampered[3].payload).is_equal(a[3].payload)
	assert_failure(func() -> void: EventLogAssertions.assert_replay_equal(a, tampered)).is_failed()


func _played() -> Dictionary:
	var pair: Dictionary = _pair()
	_play(pair)
	return pair


func test_a_snapshot_taken_mid_sequence_is_refused_and_the_log_is_unaffected() -> void:
	# Arrange
	var pair: Dictionary = _pair()
	var rng: RngService = pair.rng
	var out: Dictionary = {}

	# Act
	rng.begin_command()
	rng.stream("match_1").randi32()
	await assert_error(func() -> void: out.snap = rng.snapshot()).is_push_error(any_string())
	rng.end_command()

	# Assert
	assert_dict(out.snap).is_empty()
	assert_dict(rng.snapshot().streams).is_equal({"match_1": 1})


# --- AC-3 (deterministic half): restore at 10,000 draws --------------------------

func test_restore_at_ten_thousand_draws_gives_the_original_next_20_outputs() -> void:
	# Arrange
	var original: RngService = RngService.new(SEED, "test")
	var stream: RngStream = original.stream("match_1")
	for _i: int in range(RESTORE_DRAWS):
		stream.randi32()
	var snap: Dictionary = original.snapshot()
	var restored: RngService = RngService.new(SEED, "test")

	# Act
	var status: Error = restored.restore(snap)

	# Assert
	assert_int(status).is_equal(OK)
	assert_int(restored.stream("match_1").draws).is_equal(RESTORE_DRAWS)
	var expected: Array[int] = []
	var actual: Array[int] = []
	for _i: int in range(NEXT):
		expected.append(stream.randi32())
		actual.append(restored.stream("match_1").randi32())
	assert_array(actual).is_equal(expected)
