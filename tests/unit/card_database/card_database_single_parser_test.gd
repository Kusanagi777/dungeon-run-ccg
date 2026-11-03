## The single-parser grep gate and the "no hardcoded values" criterion
## (story card-database/story-001 AC-4; card-database CR-1, CR-5 step 3;
## ADR-0002 Implementation Guidelines; control manifest Foundation Forbidden).
##
## No file under `src/` outside `src/core/data/` may contain any of the four
## forbidden forms. The scan walks `res://src/` with `DirAccess` and reads each
## script and scene from the test (tests may read files; `src/core/data/` is the
## only production reader of `assets/data/`). The matcher is also run against
## inline text that contains each form, so the gate has been seen to fail.
extends GdUnitTestSuite


const SRC_ROOT: String = "res://src/"
const ALLOWED_DIR: String = "res://src/core/data/"
const SCANNED_EXTENSIONS: Array[String] = ["gd", "tscn", "tres"]
## `JSON.new(` rather than `JSON.new().parse`: any `JSON` instance outside
## `src/core/data/` is a parser, including the two-line form
## `var json := JSON.new()` / `json.parse(text)` that `DataLoader` itself uses.
const FORBIDDEN: Array[String] = [
	"FileAccess.open(\"res://assets/data/",
	"JSON.parse_string",
	"JSON.new(",
	"load(\"res://assets/data/",
]
const DATA_SCRIPTS: Array[String] = [
	"res://src/core/data/data_loader.gd",
	"res://src/core/data/card_database.gd",
	"res://src/core/data/validation_report.gd",
	"res://src/core/data/record_schemas.gd",
]


## The forbidden forms present in `text`.
func _violations_in(text: String) -> Array[String]:
	var out: Array[String] = []
	for pattern: String in FORBIDDEN:
		if text.contains(pattern):
			out.append(pattern)
	return out


## Every scanned file under `dir`, recursively, skipping `ALLOWED_DIR`.
func _files_under(dir: String) -> Array[String]:
	var out: Array[String] = []
	if dir == ALLOWED_DIR:
		return out
	for file_name: String in DirAccess.get_files_at(dir):
		if SCANNED_EXTENSIONS.has(file_name.get_extension()):
			out.append(dir + file_name)
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_files_under(dir + sub + "/"))
	return out


func test_schema_version_current_is_one_and_mirrored_by_test_constants() -> void:
	assert_int(DataLoader.SCHEMA_VERSION_CURRENT).is_equal(TestConstants.SCHEMA_VERSION_CURRENT)


func test_schema_version_current_is_the_only_numeric_constant_in_core_data() -> void:
	# Arrange
	var numeric: Array[String] = []

	# Act
	for path: String in DATA_SCRIPTS:
		var constants: Dictionary = (load(path) as Script).get_script_constant_map()
		for key: String in constants:
			var kind: int = typeof(constants[key])
			if kind == TYPE_INT or kind == TYPE_FLOAT:
				numeric.append("%s:%s" % [path.get_file(), key])

	# Assert
	assert_array(numeric).is_equal(["data_loader.gd:SCHEMA_VERSION_CURRENT"])


func test_data_loader_declares_only_the_manifest_and_schema_version_as_data() -> void:
	# Act — inner classes (LoadResult) are constants too; they are not data
	var data_constants: Array = []
	var constants: Dictionary = (load(DATA_SCRIPTS[0]) as Script).get_script_constant_map()
	for key: String in constants:
		if not constants[key] is Script:
			data_constants.append(key)

	# Assert
	assert_array(data_constants).contains_exactly_in_any_order(["SCHEMA_VERSION_CURRENT", "FILE_MANIFEST"])


func test_matcher_catches_each_forbidden_form() -> void:
	# Arrange — one line per form, as a per-system loader would write it
	var offending: Array[String] = [
		"var f := FileAccess.open(\"res://assets/data/match_rules.json\", FileAccess.READ)",
		"var d = JSON.parse_string(text)",
		"var err := JSON.new().parse(text)",
		"var r = load(\"res://assets/data/cards_war.json\")",
	]

	# Act / Assert — the gate has been seen to fire on every pattern
	for i: int in offending.size():
		assert_array(_violations_in(offending[i])).is_equal([FORBIDDEN[i]])
	assert_array(_violations_in("var db: CardDatabase = services.card_database")).is_empty()


func test_matcher_catches_the_two_line_json_instance_form() -> void:
	# Arrange — the form data_loader.gd uses, split over two lines
	var two_line: String = "var json: JSON = JSON.new()\nif json.parse(text) != OK:\n\treturn"
	var inferred: String = "var parser := JSON.new()\nparser.parse(text)"

	# Act / Assert
	assert_array(_violations_in(two_line)).is_equal(["JSON.new("])
	assert_array(_violations_in(inferred)).is_equal(["JSON.new("])
	assert_array(_violations_in("var text: String = JSON.stringify(data)")).is_empty()


func test_no_file_under_src_outside_core_data_parses_game_data() -> void:
	# Arrange
	var files: Array[String] = _files_under(SRC_ROOT)
	var hits: Array[String] = []

	# Act
	for path: String in files:
		for pattern: String in _violations_in(FileAccess.get_file_as_string(path)):
			hits.append("%s: %s" % [path, pattern])

	# Assert — the walk found the project's scripts, and none of them parses data
	assert_bool(files.has("res://src/core/rng/rng_stream.gd")).is_true()
	assert_bool(files.has(DATA_SCRIPTS[0])).is_false()
	assert_array(hits).is_empty()
