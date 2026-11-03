## Integration: the shipped `assets/data/rng_event_log.json` and the
## `src/core/log/` tree against story rng-event-log/story-007 AC-2 / AC-3
## ("No hardcoded values", DD-T01; `validate_config` returns `[]` for the
## shipped file).
##
## These checks read versioned repository files, so they live here and not in
## the unit suite: the config through `DataLoader` (the one game-data parser),
## and every `.gd` under `src/core/log/` for knob literals. The loader reads a
## scratch root under `user://` that `before()` stages and `after()` removes;
## the repository is only read.
extends GdUnitTestSuite

const SHIPPED_CONFIG: String = "res://assets/data/rng_event_log.json"
## `minimal/` supplies every other CR-1 file; only some configs ship so far.
const FIXTURE_ROOT: String = "res://tests/fixtures/data/minimal/"
## A scratch data root, created in `before()` and removed in `after()`.
const STAGE_ROOT: String = "user://event_log_config_file_test/"
const CONFIG_FILE: String = "rng_event_log.json"
const LOG_ROOT: String = "res://src/core/log/"
## The knob values AC-2 forbids as literals in `src/core/log/`, in either
## spelling (`2000000` / `2_000_000`); word-bounded, so `20_000_000` (a range
## bound) is not a hit.
const KNOB_LITERAL: String = "(?<![\\d_])(2_?000_?000|200|10_?000)(?![\\d_])"


## Stages a data root: every `minimal/` fixture file, with the shipped
## `rng_event_log.json` in place of the fixture's. Files are copied, not parsed.
func before() -> void:
	DirAccess.make_dir_recursive_absolute(STAGE_ROOT)
	for file_name: String in DirAccess.get_files_at(FIXTURE_ROOT):
		if file_name.get_extension() == "json" and file_name != CONFIG_FILE:
			DirAccess.copy_absolute(FIXTURE_ROOT + file_name, STAGE_ROOT + file_name)
	DirAccess.copy_absolute(SHIPPED_CONFIG, STAGE_ROOT + CONFIG_FILE)


func after() -> void:
	for file_name: String in DirAccess.get_files_at(STAGE_ROOT):
		DirAccess.remove_absolute(STAGE_ROOT + file_name)
	DirAccess.remove_absolute(STAGE_ROOT)


func _shipped_body() -> Dictionary:
	var result: DataLoader.LoadResult = DataLoader.new(STAGE_ROOT).run(ValidatorStubs.accept_all())
	assert_bool(result.report.has_errors()).override_failure_message(result.report.to_text()).is_false()
	return result.snapshot.configs[CONFIG_FILE.get_basename()]


## The non-comment code lines of `source` that hold a knob literal.
func _knob_literal_hits(source: String) -> Array[String]:
	var literal: RegEx = RegEx.create_from_string(KNOB_LITERAL)
	var hits: Array[String] = []
	for line: String in source.split("\n"):
		var code: String = line.split("#")[0]
		if literal.search(code) != null:
			hits.append(line.strip_edges())
	return hits


func test_shipped_file_loads_and_carries_the_story_defaults() -> void:
	# Act
	var body: Dictionary = _shipped_body()

	# Assert — boundary values: the exact numbers ARE the point (DD-T01 defaults)
	assert_array(body.keys()).contains_exactly_in_any_order(["log_memory_budget_bytes", "avg_event_bytes", "keep_match_logs"])
	assert_int(int(body.log_memory_budget_bytes)).is_equal(TestConstants.LOG_MEMORY_BUDGET_BYTES)
	assert_int(int(body.avg_event_bytes)).is_equal(200)
	assert_dict(body.keep_match_logs).is_equal({"debug": true, "release": false})


func test_validate_config_returns_no_entry_for_the_shipped_file() -> void:
	assert_array(EventLog.validate_config(_shipped_body(), null)).is_empty()


func test_max_events_for_the_shipped_file_is_ten_thousand() -> void:
	assert_int(EventLog.max_events_for(_shipped_body())).is_equal(TestConstants.MAX_MATCH_EVENTS)


func test_matcher_catches_each_knob_literal_and_skips_range_bounds() -> void:
	# Arrange
	var offending: Array[String] = [
		"var cap: int = 10000",
		"const BUDGET: int = 2_000_000",
		"return budget / 200",
		"EventLog.new(10_000, scope)",
	]

	# Act / Assert — the gate has been seen to fire on every form
	for line: String in offending:
		assert_array(_knob_literal_hits(line)).override_failure_message(line).is_equal([line])
	assert_array(_knob_literal_hits("\"log_memory_budget_bytes\": [500_000, 20_000_000],")).is_empty()
	assert_array(_knob_literal_hits("var x: int = 1200  # 200 in a comment")).is_empty()


func test_no_knob_literal_appears_in_src_core_log() -> void:
	# Arrange
	var hits: Array[String] = []
	var files: PackedStringArray = DirAccess.get_files_at(LOG_ROOT)

	# Act
	for file_name: String in files:
		if file_name.get_extension() == "gd":
			for hit: String in _knob_literal_hits(FileAccess.get_file_as_string(LOG_ROOT + file_name)):
				hits.append("%s: %s" % [file_name, hit])

	# Assert — the scan found the log, and the log holds no knob value
	assert_bool(files.has("event_log.gd")).is_true()
	assert_array(hits).is_empty()
