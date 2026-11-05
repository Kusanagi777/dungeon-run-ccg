## Blocking proof that an engine optimisation changed no rules behaviour (story
## match-rules/story-019 AC-2; QA plan sprint 5 NC-3; design/gdd/match-rules.md
## AC-38, C10, C15 `auras_recomputed`, DD-X26, DD-X27).
##
## Each test rebuilds a golden with [MatchGoldenLogs] from the engine under test
## and compares it byte for byte with the file recorded on the unchanged engine
## under `tests/fixtures/match_rules/golden_logs/`, committed before any `src/`
## edit. A failure is a rules change, not a stale file: do not regenerate to
## pass (see `tools/match_rules/record_golden_logs.gd`).
##
## Reading those committed files is this suite's only file I/O.
extends GdUnitTestSuite

## The fixture states of story 017 (AC-39).
const STATE_COUNT: int = 10
## AC-38: commands in the scripted match.
const SCRIPTED_COMMANDS: int = 200
## The aura goldens: the source's life (8 rows) and one per primitive.
const AURA_LIFE_SCENARIOS: int = 8
## How much of a differing line a failure prints.
const SHOWN_CHARS: int = 400

var _golden: MatchGoldenLogs = MatchGoldenLogs.new()


## The committed text of [param name], "" when it is missing.
func _recorded(name: String) -> String:
	var path: String = MatchGoldenLogs.path_of(name)
	assert_bool(FileAccess.file_exists(path)).override_failure_message("%s is missing" % path).is_true()
	return FileAccess.get_file_as_string(path)


## Asserts the engine still produces golden [param name] byte for byte, naming
## the first line that moved.
func _assert_matches(name: String) -> void:
	var recorded: String = _recorded(name)
	var captured: String = _golden.capture(name)
	assert_bool(recorded.is_empty()).override_failure_message("%s is empty" % name).is_false()
	if captured == recorded:
		return
	var want: PackedStringArray = recorded.split("\n")
	var got: PackedStringArray = captured.split("\n")
	for i: int in mini(want.size(), got.size()):
		if want[i] != got[i]:
			assert_bool(false).override_failure_message("%s line %d moved:\n  golden:  %s\n  engine:  %s" % [name, i + 1, want[i].left(SHOWN_CHARS), got[i].left(SHOWN_CHARS)]).is_true()
			return
	assert_int(got.size()).override_failure_message("%s: %d lines, golden has %d" % [name, got.size(), want.size()]).is_equal(want.size())


## The parsed lines of golden [param name] that hold [param key].
func _rows_with(name: String, key: String) -> Array:
	var out: Array = []
	for line: String in _recorded(name).split("\n", false):
		var row: Variant = JSON.parse_string(line)
		if row is Dictionary and (row as Dictionary).has(key):
			out.append(row)
	return out


func test_the_golden_set_is_every_fixture_with_one_file_each() -> void:
	# Arrange
	var names: Array[String] = _golden.names()
	var states: Array[String] = names.filter(func(n: String) -> bool: return n.begins_with(MatchGoldenLogs.STATE_PREFIX))

	# Act
	var files: Array = Array(DirAccess.get_files_at(MatchGoldenLogs.GOLDEN_DIR)).filter(func(f: String) -> bool: return f.ends_with(MatchGoldenLogs.GOLDEN_EXTENSION))

	# Assert
	assert_int(states.size()).is_equal(STATE_COUNT)
	assert_int(files.size()).is_equal(names.size())
	for name: String in names:
		assert_bool(files.has(name + MatchGoldenLogs.GOLDEN_EXTENSION)).override_failure_message("no golden for %s" % name).is_true()


func test_the_chain_golden_records_the_56_pass_chain_on_a_clone_and_live() -> void:
	# Act
	var clone_events: Array = _rows_with(MatchGoldenLogs.CHAIN, "clone_event").map(func(r: Dictionary) -> Dictionary: return r.clone_event)
	var live_events: Array = _rows_with(MatchGoldenLogs.CHAIN, "event").map(func(r: Dictionary) -> Dictionary: return r.event)

	# Assert: the file is the worst case, not an empty pass
	assert_int(MatchBudgetFixtures.deathrattle_passes(clone_events)).is_greater_equal(MatchBudgetFixtures.CHAIN_MIN_STEPS)
	assert_int(MatchBudgetFixtures.deathrattle_passes(live_events)).is_greater_equal(MatchBudgetFixtures.CHAIN_MIN_STEPS)


func test_the_chain_submit_is_byte_identical_to_its_golden() -> void:
	_assert_matches(MatchGoldenLogs.CHAIN)


func test_the_full_board_legal_commands_are_byte_identical_to_their_golden() -> void:
	_assert_matches(MatchGoldenLogs.FULL_BOARD)


func test_every_legal_command_of_every_fixture_state_is_byte_identical_to_its_golden() -> void:
	for name: String in _golden.names():
		if name.begins_with(MatchGoldenLogs.STATE_PREFIX):
			_assert_matches(name)


func test_every_fixture_state_golden_submits_each_of_its_legal_commands() -> void:
	for name: String in _golden.names():
		if not name.begins_with(MatchGoldenLogs.STATE_PREFIX):
			continue
		# Act
		var legal: Array = _rows_with(name, "legal")
		var submitted: Array = _rows_with(name, "command")

		# Assert
		assert_array(legal).override_failure_message("%s lists no command" % name).is_not_empty()
		assert_int(submitted.size()).override_failure_message(name).is_equal(legal.size())
		for row: Dictionary in submitted:
			assert_bool(bool(row.result.accepted)).override_failure_message("%s: %s" % [name, str(row.command)]).is_true()


func test_the_200_command_match_is_byte_identical_to_its_golden() -> void:
	_assert_matches(MatchGoldenLogs.SCRIPTED)


func test_the_scripted_golden_is_the_ac38_match_of_every_command_type_ending_in_concede() -> void:
	# Act
	var rows: Array = _rows_with(MatchGoldenLogs.SCRIPTED, "command")
	var types: Array = rows.map(func(r: Dictionary) -> String: return str(r.command.type))

	# Assert
	assert_int(rows.size()).is_equal(SCRIPTED_COMMANDS)
	for row: Dictionary in rows:
		assert_bool(bool(row.result.accepted)).override_failure_message(str(row.command)).is_true()
	for type: String in [MatchRecords.CMD_MULLIGAN, MatchRecords.CMD_PLAY_CARD, MatchRecords.CMD_ATTACK, MatchRecords.CMD_USE_HERO_POWER, MatchRecords.CMD_CHOOSE, MatchRecords.CMD_END_TURN]:
		assert_bool(types.has(type)).override_failure_message("no %s in the scripted match" % type).is_true()
	assert_str(str(types.back())).is_equal(MatchRecords.CMD_CONCEDE)


func test_the_aura_passes_are_byte_identical_to_their_golden() -> void:
	_assert_matches(MatchGoldenLogs.AURAS)


func test_the_observer_order_is_byte_identical_to_its_golden() -> void:
	_assert_matches(MatchGoldenLogs.TRIGGERS)


func test_the_trigger_golden_queues_a_trigger_at_every_observer_point() -> void:
	# Act
	var queued: Dictionary = {}
	for row: Dictionary in _rows_with(MatchGoldenLogs.TRIGGERS, "event"):
		if str(row.event.type) == "trigger_queued":
			queued[str(row.event.payload.point)] = true

	# Assert: a point nothing answered proves nothing about candidate order
	for point: StringName in MatchGoldenLogs.OBSERVER_POINTS:
		assert_bool(queued.has(String(point))).override_failure_message("no trigger queued on %s" % point).is_true()


func test_the_aura_golden_runs_each_primitive_inside_the_pass() -> void:
	# Act
	var scenarios: Array = _rows_with(MatchGoldenLogs.AURAS, "scenario").map(func(r: Dictionary) -> String: return str(r.scenario))

	# Assert: every primitive, so a primitive that forgets the pass shows up here
	assert_int(scenarios.size()).is_equal(AURA_LIFE_SCENARIOS + RulesEngine.PRIMITIVES.size())
	for primitive: StringName in RulesEngine.PRIMITIVES:
		assert_bool(scenarios.has(String(primitive))).override_failure_message("no aura-pass scenario for %s" % primitive).is_true()


func test_the_aura_golden_holds_a_change_of_every_auras_recomputed_field() -> void:
	# Act: every field of every entry of every `auras_recomputed` (DD-X26)
	var seen: Dictionary = {}
	for row: Dictionary in _rows_with(MatchGoldenLogs.AURAS, "event"):
		if str(row.event.type) != "auras_recomputed":
			continue
		for change: Dictionary in row.event.payload.changes:
			for field: String in change:
				seen[field] = true

	# Assert: R1 must keep keywords and hand cost, not just stats
	for field: String in ["entity_id", "attack", "health", "max_health", "keywords", "instance_id", "zone", "effective_cost"]:
		assert_bool(seen.has(field)).override_failure_message("no auras_recomputed entry carries %s" % field).is_true()
