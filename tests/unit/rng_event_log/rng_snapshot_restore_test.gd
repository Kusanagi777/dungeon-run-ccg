## RngService snapshot / restore (reseed-and-discard), the command guard and
## the hex snapshot form.
##
## Story: production/epics/rng-event-log/story-003-snapshot-restore-and-command-guard.md
## GDD: design/gdd/rng-event-log.md rules 3, 5, 10; F4, F5; Edge Cases
## (Streams, Persistence). ADR-0003 Decision 3-4 and the 2026-11-03 erratum:
## forks are keyed by parent + label, rebuilt through `stream(parent).fork(label)`,
## and a restore clears every cached fork. Every service is built with a literal
## seed; no wall clock, no file I/O (`JSON.stringify` / `parse_string` only).
extends GdUnitTestSuite

## rng-event-log F2 example seed.
const SEED: int = TestConstants.DEFAULT_TEST_SEED
## AC-2: draws taken before the snapshot.
const WARMUP: int = 37
## AC-2: outputs compared after the restore.
const NEXT: int = 20
## 2^53 + 1: above JSON's exact-integer range (probe E).
const ABOVE_TWO_POW_53: int = 9007199254740993
## AC-3 data versions.
const SAVED_VERSION: String = "1.0"
const INSTALLED_VERSION: String = "1.1"
## A parent's draws before its fork, and the child's own draws (AC-2 fork case).
const PARENT_BEFORE_FORK: int = 5
const PARENT_AFTER_FORK: int = 3
const CHILD_DRAWS: int = 4

const SNAPSHOT_REFUSED: String = "RngService.snapshot: refused while a command is open (begin_command() without end_command())"
const END_WITHOUT_BEGIN: String = "RngService.end_command: no command is open"


## A service that records every name asked of `stream()` — the root-name rule
## says `restore()` must never ask it for a fork path.
class RecordingService extends RngService:
	var asked: Array[String] = []

	func _init(seed_value: int, version: String) -> void:
		super(seed_value, version)

	func stream(stream_name: String) -> RngStream:
		asked.append(stream_name)
		return super(stream_name)


func _deck() -> Array:
	var deck: Array = []
	for i: int in range(TestConstants.STARTER_DECK_SIZE):
		deck.append("card_%d" % i)
	return deck


func _outputs(stream: RngStream, count: int) -> Array[int]:
	var out: Array[int] = []
	for _i: int in range(count):
		out.append(stream.randi32())
	return out


func _burn(stream: RngStream, count: int) -> void:
	for _i: int in range(count):
		stream.randi32()


## A service whose `ai_1` drew 5, forked `sim_1` (1 parent draw), drew 3 more;
## the child drew 4. Snapshot: `ai_1` 9, `ai_1/sim_1` 4, fork point 5.
func _service_with_fork(version: String = "test") -> RngService:
	var service: RngService = RngService.new(SEED, version)
	var parent: RngStream = service.stream("ai_1")
	_burn(parent, PARENT_BEFORE_FORK)
	var child: RngStream = parent.fork("sim_1")
	_burn(parent, PARENT_AFTER_FORK)
	_burn(child, CHILD_DRAWS)
	return service


# --- AC-1: shuffle, restore, shuffle -------------------------------------------

func test_shuffle_restore_shuffle_gives_identical_orders_and_n_minus_1_draws_each() -> void:
	# Arrange
	var service: RngService = RngService.new(SEED, "test")
	var stream: RngStream = service.stream("match_1")
	var snap: Dictionary = service.snapshot()
	var first: Array = _deck()
	var second: Array = _deck()

	# Act
	stream.shuffle(first)
	var draws_first: int = stream.draws
	var status: Error = service.restore(snap)
	stream.shuffle(second)

	# Assert
	assert_int(status).is_equal(OK)
	assert_array(second).is_equal(first)
	assert_array(first).is_not_equal(_deck())
	assert_int(draws_first).is_equal(TestConstants.STARTER_DECK_SIZE - 1)
	assert_int(stream.draws).is_equal(TestConstants.STARTER_DECK_SIZE - 1)


func test_shuffle_of_zero_or_one_element_consumes_no_draws() -> void:
	# Arrange
	var stream: RngStream = RngService.new(SEED, "test").stream("match_1")

	# Act
	stream.shuffle([])
	stream.shuffle(["only"])

	# Assert
	assert_int(stream.draws).is_zero()


# --- AC-2: restore into a fresh service ---------------------------------------

func test_restore_at_37_draws_into_a_fresh_service_gives_the_same_next_20_outputs() -> void:
	# Arrange
	var original: RngService = RngService.new(SEED, "test")
	_burn(original.stream("match_3"), WARMUP)
	var snap: Dictionary = original.snapshot()

	# Act
	var restored: RngService = RngService.new(SEED, "test")
	var status: Error = restored.restore(snap)

	# Assert
	assert_int(status).is_equal(OK)
	assert_int(restored.stream("match_3").draws).is_equal(WARMUP)
	assert_array(_outputs(restored.stream("match_3"), NEXT)).is_equal(_outputs(original.stream("match_3"), NEXT))


func test_snapshot_shape_is_run_seed_data_version_and_stream_draws() -> void:
	# Arrange
	var service: RngService = _service_with_fork()
	_burn(service.stream("match_3"), WARMUP)

	# Act
	var snap: Dictionary = service.snapshot()

	# Assert
	assert_array(snap.keys()).contains_exactly_in_any_order(["run_seed", "data_version", "streams", "fork_points"])
	assert_int(typeof(snap.run_seed)).is_equal(TYPE_INT)
	assert_int(snap.run_seed).is_equal(SEED)
	assert_str(snap.data_version).is_equal("test")
	assert_dict(snap.streams).is_equal({
		"ai_1": PARENT_BEFORE_FORK + 1 + PARENT_AFTER_FORK,
		"ai_1/sim_1": CHILD_DRAWS,
		"match_3": WARMUP,
	})
	assert_dict(snap.fork_points).is_equal({"ai_1/sim_1": PARENT_BEFORE_FORK})
	assert_bool(GameAssertions.is_json_representable(snap)).is_true()


func test_restore_at_zero_draws_replays_the_stream_from_its_first_output() -> void:
	# Arrange
	var service: RngService = RngService.new(SEED, "test")
	service.stream("draft_1")
	var snap: Dictionary = service.snapshot()
	var first: Array[int] = _outputs(service.stream("draft_1"), NEXT)

	# Act
	var status: Error = service.restore(snap)

	# Assert
	assert_int(status).is_equal(OK)
	assert_int(snap.streams["draft_1"]).is_zero()
	assert_array(_outputs(service.stream("draft_1"), NEXT)).is_equal(first)


func test_a_fork_is_snapshotted_under_its_full_name_and_restored_through_its_parent() -> void:
	# Arrange
	var original: RngService = _service_with_fork()
	var snap: Dictionary = original.snapshot()

	# Act
	var restored: RecordingService = RecordingService.new(SEED, "test")
	var status: Error = restored.restore(snap)
	var parent: RngStream = restored.stream("ai_1")
	var child: RngStream = parent.fork("sim_1")

	# Assert — same positions, same next outputs on parent and child
	assert_int(status).is_equal(OK)
	assert_int(parent.draws).is_equal(PARENT_BEFORE_FORK + 1 + PARENT_AFTER_FORK)
	assert_int(child.draws).is_equal(CHILD_DRAWS)
	assert_str(child.name).is_equal("ai_1/sim_1")
	var original_child: RngStream = original.stream("ai_1").fork("sim_1")
	assert_array(_outputs(child, NEXT)).is_equal(_outputs(original_child, NEXT))
	assert_array(_outputs(parent, NEXT)).is_equal(_outputs(original.stream("ai_1"), NEXT))
	# never `stream("ai_1/sim_1")`: fork paths reach the service only through fork()
	for asked: String in restored.asked:
		assert_bool(asked.contains("/")).override_failure_message("restore asked stream() for \"%s\"" % asked).is_false()


func test_the_restored_fork_is_memoised_so_forking_again_takes_no_parent_draw() -> void:
	# Arrange
	var restored: RngService = RngService.new(SEED, "test")
	var status: Error = restored.restore(_service_with_fork().snapshot())
	var parent: RngStream = restored.stream("ai_1")
	var before: int = parent.draws

	# Act
	var first: RngStream = parent.fork("sim_1")
	var second: RngStream = parent.fork("sim_1")

	# Assert
	assert_int(status).is_equal(OK)
	assert_object(second).is_same(first)
	assert_int(parent.draws).is_equal(before)


func test_a_fork_after_restore_matches_a_fresh_run_not_the_stale_child() -> void:
	# Arrange — the fresh run draws 5 then forks
	var fresh: RngService = RngService.new(SEED, "test")
	_burn(fresh.stream("ai_1"), PARENT_BEFORE_FORK)
	var fresh_child: RngStream = fresh.stream("ai_1").fork("sim_1")
	# the restored service snapshots at 5, then forks and draws (stale) before restoring
	var service: RngService = RngService.new(SEED, "test")
	_burn(service.stream("ai_1"), PARENT_BEFORE_FORK)
	var snap: Dictionary = service.snapshot()
	var stale: RngStream = service.stream("ai_1").fork("sim_1")
	_burn(stale, CHILD_DRAWS)

	# Act
	var status: Error = service.restore(snap)
	var child: RngStream = service.stream("ai_1").fork("sim_1")

	# Assert — a new child, seeded from a fresh parent draw, same sequence
	assert_int(status).is_equal(OK)
	assert_object(child).is_not_same(stale)
	assert_int(service.stream("ai_1").draws).is_equal(fresh.stream("ai_1").draws)
	assert_array(_outputs(child, NEXT)).is_equal(_outputs(fresh_child, NEXT))


func test_restore_in_place_keeps_held_stream_references_and_drops_streams_the_snapshot_lacks() -> void:
	# Arrange
	var service: RngService = RngService.new(SEED, "test")
	var held: RngStream = service.stream("match_1")
	_burn(held, WARMUP)
	var snap: Dictionary = service.snapshot()
	var expected: Array[int] = _outputs(RngService.new(SEED, "test").stream("match_1"), WARMUP + NEXT).slice(WARMUP)
	_burn(held, NEXT)
	service.stream("draft_1").randi32()

	# Act
	var status: Error = service.restore(snap)

	# Assert
	assert_int(status).is_equal(OK)
	assert_object(service.stream("match_1")).is_same(held)
	assert_array(_outputs(held, NEXT)).is_equal(expected)
	assert_bool(service.has_stream("draft_1")).is_false()


func test_stream_restore_reseeds_discards_and_clears_its_fork_memo() -> void:
	# Arrange
	var reference: RngStream = RngStream.new("match_1", SEED)
	_burn(reference, WARMUP)
	var stream: RngStream = RngStream.new("match_1", SEED)
	_burn(stream, WARMUP + NEXT)
	var stale: RngStream = stream.fork("sim_1")

	# Act
	stream.restore(WARMUP)

	# Assert
	assert_int(stream.draws).is_equal(WARMUP)
	assert_array(_outputs(stream, NEXT)).is_equal(_outputs(reference, NEXT))
	assert_object(stream.fork("sim_1")).is_not_same(stale)


# --- AC-3: data_version mismatch and other refusals ----------------------------

func test_restore_rejects_a_data_version_mismatch_and_creates_no_stream() -> void:
	# Arrange
	var saved: RngService = _service_with_fork(SAVED_VERSION)
	saved.stream("run").randi32()
	var installed: RngService = RngService.new(SEED, INSTALLED_VERSION)

	# Act
	var status: Error = installed.restore(saved.snapshot())

	# Assert
	assert_int(status).is_equal(ERR_INVALID_DATA)
	assert_bool(installed.has_stream("run")).is_false()
	assert_bool(installed.has_stream("ai_1")).is_false()
	assert_dict(installed.snapshot().streams).is_empty()


func test_restore_rejects_a_snapshot_of_another_run_seed_and_leaves_streams_untouched() -> void:
	# Arrange
	var other: RngService = RngService.new(SEED + 1, "test")
	_burn(other.stream("run"), WARMUP)
	var service: RngService = RngService.new(SEED, "test")
	service.stream("match_1").randi32()
	var status: Dictionary = {}

	# Act
	await assert_error(func() -> void: status.value = service.restore(other.snapshot())) \
		.is_push_error("RngService.restore: snapshot run_seed %s is not this service's %s" % [RngService.to_hex_u64(SEED + 1), RngService.to_hex_u64(SEED)])

	# Assert
	assert_int(status.value).is_equal(ERR_INVALID_DATA)
	assert_bool(service.has_stream("run")).is_false()
	assert_int(service.stream("match_1").draws).is_equal(1)


func test_restore_rejects_malformed_stream_entries_and_creates_no_stream() -> void:
	# Arrange — each snapshot is wrong in exactly one way
	var good: Dictionary = _service_with_fork().snapshot()
	var bad: Array[Dictionary] = []
	var orphan: Dictionary = good.duplicate(true)
	orphan.streams.erase("ai_1")
	bad.append(orphan)
	var no_point: Dictionary = good.duplicate(true)
	no_point.fork_points.erase("ai_1/sim_1")
	bad.append(no_point)
	var point_past_parent: Dictionary = good.duplicate(true)
	point_past_parent.fork_points["ai_1/sim_1"] = good.streams["ai_1"]
	bad.append(point_past_parent)
	var float_draws: Dictionary = good.duplicate(true)
	float_draws.streams["ai_1"] = float(good.streams["ai_1"])
	bad.append(float_draws)
	var negative: Dictionary = good.duplicate(true)
	negative.streams["ai_1/sim_1"] = -1
	bad.append(negative)
	var bad_label: Dictionary = good.duplicate(true)
	bad_label.streams["ai_1/Sim"] = 0
	bad_label.fork_points["ai_1/Sim"] = 0
	bad.append(bad_label)
	var shared_point: Dictionary = good.duplicate(true)
	shared_point.streams["ai_1/sim_2"] = 0
	shared_point.fork_points["ai_1/sim_2"] = PARENT_BEFORE_FORK
	bad.append(shared_point)

	for snap: Dictionary in bad:
		var service: RngService = RngService.new(SEED, "test")
		var out: Dictionary = {}

		# Act
		await assert_error(func() -> void: out.status = service.restore(snap)).is_push_error(any_string())

		# Assert
		assert_int(out.status).override_failure_message("accepted %s" % str(snap)).is_equal(ERR_INVALID_DATA)
		assert_bool(service.has_stream("ai_1")).is_false()


# --- AC-4: command guard and hex form -----------------------------------------

func test_snapshot_between_begin_and_end_command_is_refused_with_an_error() -> void:
	# Arrange
	var service: RngService = RngService.new(SEED, "test")
	service.stream("match_1").randi32()
	var out: Dictionary = {}

	# Act
	service.begin_command()
	await assert_error(func() -> void: out.snap = service.snapshot()).is_push_error(SNAPSHOT_REFUSED)
	await assert_error(func() -> void: out.json = service.snapshot_to_json_dict()).is_push_error(SNAPSHOT_REFUSED)
	service.end_command()
	var after: Dictionary = service.snapshot()

	# Assert
	assert_dict(out.snap).is_empty()
	assert_dict(out.json).is_empty()
	assert_dict(after.streams).is_equal({"match_1": 1})


func test_nested_commands_keep_the_guard_until_the_outermost_end() -> void:
	# Arrange
	var service: RngService = RngService.new(SEED, "test")
	var out: Dictionary = {}

	# Act
	service.begin_command()
	service.begin_command()
	service.end_command()
	await assert_error(func() -> void: out.snap = service.snapshot()).is_push_error(SNAPSHOT_REFUSED)
	service.end_command()

	# Assert
	assert_dict(out.snap).is_empty()
	assert_dict(service.snapshot()).is_not_empty()


func test_end_command_without_begin_is_reported_and_does_not_unbalance_the_guard() -> void:
	# Arrange
	var service: RngService = RngService.new(SEED, "test")

	# Act
	await assert_error(func() -> void: service.end_command()).is_push_error(END_WITHOUT_BEGIN)
	service.begin_command()
	var out: Dictionary = {}
	await assert_error(func() -> void: out.snap = service.snapshot()).is_push_error(SNAPSHOT_REFUSED)

	# Assert
	assert_dict(out.snap).is_empty()


func test_json_dict_carries_run_seed_as_16_uppercase_hex() -> void:
	# Arrange
	var service: RngService = RngService.new(ABOVE_TWO_POW_53, "test")
	service.stream("run").randi32()

	# Act
	var json_dict: Dictionary = service.snapshot_to_json_dict()

	# Assert
	assert_bool(json_dict.has("run_seed")).is_false()
	assert_str(json_dict.run_seed_hex).is_equal("0020000000000001")
	assert_str(json_dict.data_version).is_equal("test")
	assert_dict(json_dict.streams).is_equal({"run": 1})
	assert_bool(GameAssertions.is_json_representable(json_dict)).is_true()


func test_json_round_trip_above_two_pow_53_restores_the_exact_seed_and_next_outputs() -> void:
	# Arrange
	var original: RngService = RngService.new(ABOVE_TWO_POW_53, "test")
	_burn(original.stream("match_3"), WARMUP)
	_burn(original.stream("ai_1"), PARENT_BEFORE_FORK)
	_burn(original.stream("ai_1").fork("sim_1"), CHILD_DRAWS)
	var text: String = JSON.stringify(original.snapshot_to_json_dict())

	# Act
	var loaded: Dictionary = RngService.snapshot_from_json_dict(JSON.parse_string(text))
	var restored: RngService = RngService.new(loaded.run_seed, "test")
	var status: Error = restored.restore(loaded)

	# Assert
	assert_int(loaded.run_seed).is_equal(ABOVE_TWO_POW_53)
	assert_int(typeof(loaded.streams["match_3"])).is_equal(TYPE_INT)
	assert_int(typeof(loaded.fork_points["ai_1/sim_1"])).is_equal(TYPE_INT)
	assert_int(status).is_equal(OK)
	assert_array(_outputs(restored.stream("match_3"), NEXT)).is_equal(_outputs(original.stream("match_3"), NEXT))
	assert_array(_outputs(restored.stream("ai_1").fork("sim_1"), NEXT)) \
		.is_equal(_outputs(original.stream("ai_1").fork("sim_1"), NEXT))
	# the seed as a JSON number would not have survived (probe E)
	assert_int(int(JSON.parse_string(JSON.stringify({"s": ABOVE_TWO_POW_53})).s)).is_not_equal(ABOVE_TWO_POW_53)


func test_snapshot_from_json_dict_refuses_a_missing_or_malformed_seed() -> void:
	# Arrange
	var bad: Array[Dictionary] = [
		{"data_version": "test", "streams": {}, "fork_points": {}},
		{"run_seed_hex": "2A", "data_version": "test", "streams": {}, "fork_points": {}},
		{"run_seed_hex": 42.0, "data_version": "test", "streams": {}, "fork_points": {}},
		{"run_seed_hex": "000000000000002A", "data_version": "test", "streams": [], "fork_points": {}},
	]

	for d: Dictionary in bad:
		var out: Dictionary = {}

		# Act
		await assert_error(func() -> void: out.snap = RngService.snapshot_from_json_dict(d)).is_push_error(any_string())

		# Assert
		assert_dict(out.snap).override_failure_message("accepted %s" % str(d)).is_empty()
