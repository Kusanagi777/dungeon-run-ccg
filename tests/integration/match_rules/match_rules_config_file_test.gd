## Integration: the shipped `assets/data/match_rules.json` and the `src/` tree
## against match-rules AC-41 and the Tuning Knobs table (story
## match-rules/story-001; design/gdd/match-rules.md F9, Tuning Knobs; ADR-0002).
##
## These checks read versioned repository files, so they live here and not in
## the unit suite: the config through `DataLoader` (the one game-data parser,
## card-database CR-1 — never `JSON.parse_string` here), the GDD's Tuning Knobs
## table as text (to pin `RulesEngine.CONFIG_SAFE_RANGES` to it), and every
## `.gd` under `src/` (AC-41's "no knob literal" scan). The loader reads a
## scratch root under `user://` that `before()` stages and `after()` removes;
## the repository is only read.
extends GdUnitTestSuite

const SHIPPED_RULES: String = "res://assets/data/match_rules.json"
## `minimal/` supplies every other CR-1 file: only `match_rules.json` ships so
## far, and the loader fails a root with a required file missing.
const FIXTURE_ROOT: String = "res://tests/fixtures/data/minimal/"
## A scratch data root, created in `before()` and removed in `after()`.
const STAGE_ROOT: String = "user://match_rules_config_file_test/"
const RULES_FILE: String = "match_rules.json"
const GDD_PATH: String = "res://design/gdd/match-rules.md"
const SRC_ROOT: String = "res://src"
## Bounding calls whose numeric literal arguments AC-41 forbids: a cap or floor
## written as `clampi(n, 0, 4)` is a knob literal even with no knob name on
## the line.
const BOUND_CALLS: String = "clamp|clampi|clampf|min|mini|minf|max|maxi|maxf"


# --- setup: the shipped file in a complete data root ---------------------------

## Stages a data root: every `minimal/` fixture file, with the shipped
## `match_rules.json` in place of the fixture's. Files are copied, not parsed.
func before() -> void:
	DirAccess.make_dir_recursive_absolute(STAGE_ROOT)
	for file_name: String in DirAccess.get_files_at(FIXTURE_ROOT):
		if file_name.get_extension() == "json" and file_name != RULES_FILE:
			DirAccess.copy_absolute(FIXTURE_ROOT + file_name, STAGE_ROOT + file_name)
	DirAccess.copy_absolute(SHIPPED_RULES, STAGE_ROOT + RULES_FILE)


func after() -> void:
	for file_name: String in DirAccess.get_files_at(STAGE_ROOT):
		DirAccess.remove_absolute(STAGE_ROOT + file_name)
	DirAccess.remove_absolute(STAGE_ROOT)


# --- helpers -----------------------------------------------------------------

func _load_shipped() -> DataLoader.LoadResult:
	return DataLoader.new(STAGE_ROOT).run(ValidatorStubs.accept_all())


func _sorted(items: Array) -> Array:
	var out: Array = items.duplicate()
	out.sort()
	return out


func _gd_files(dir_path: String, out: Array[String]) -> Array[String]:
	for sub: String in DirAccess.get_directories_at(dir_path):
		_gd_files(dir_path.path_join(sub), out)
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.ends_with(".gd"):
			out.append(dir_path.path_join(file_name))
	return out


## The top-level arguments of the call whose `(` is at [param open] in
## [param code], split on the commas at bracket depth 0 (nested calls stay
## whole). An unclosed call yields the arguments up to the end of the line.
func _call_args(code: String, open: int) -> Array[String]:
	var args: Array[String] = []
	var depth: int = 0
	var start: int = open + 1
	for i: int in range(open + 1, code.length()):
		var c: String = code[i]
		if c == "(" or c == "[" or c == "{":
			depth += 1
		elif c == ")" or c == "]" or c == "}":
			if depth == 0:
				args.append(code.substr(start, i - start).strip_edges())
				return args
			depth -= 1
		elif c == "," and depth == 0:
			args.append(code.substr(start, i - start).strip_edges())
			start = i + 1
	args.append(code.substr(start).strip_edges())
	return args


## AC-41 scanner over GDScript source. A line is a hit when it
##  1. binds a knob name to a numeric literal (`const MAX_MANA: int = 10`,
##     `var hand_size := 10`, `"board_size": 7`), or
##  2. passes a numeric literal other than 0 or 1 as an argument of a bounding
##     call ([constant BOUND_CALLS]) — `clampi(n, 0, 4)`, `mini(size, 10)`.
##     0 and 1 are the identity bounds (`maxi(0, total)`,
##     `RulesEngine.ATTACKS_PER_TURN`) and are not knob values on their own.
## Comments (`#` to end of line) are ignored.
func _knob_literal_hits(source: String) -> Array[String]:
	var names: String = "|".join(RulesEngine.CONFIG_KEYS)
	var binding: RegEx = RegEx.create_from_string("(?i)\\b(%s)\\b[\"']?\\s*(?::\\s*\\w+\\s*)?(?::=|=|:)\\s*-?\\d" % names)
	var bound_call: RegEx = RegEx.create_from_string("\\b(?:%s)\\s*\\(" % BOUND_CALLS)
	var number: RegEx = RegEx.create_from_string("^-?\\d+(?:\\.\\d+)?$")
	var hits: Array[String] = []
	for line: String in source.split("\n"):
		var code: String = line.split("#")[0]
		var hit: bool = binding.search(code) != null
		for call: RegExMatch in bound_call.search_all(code):
			for arg: String in _call_args(code, call.get_end() - 1):
				if number.search(arg) != null and absf(float(arg)) != 0.0 and absf(float(arg)) != 1.0:
					hit = true
		if hit:
			hits.append(line.strip_edges())
	return hits


## The GDD Tuning Knobs rows, as `{<snake_case key>: {current: int, range: [min, max]}}`.
## A row names one knob (`| \`MAX_MANA\` (DD-M04) | 10 | 7–10 |`) or several
## separated by ` / ` in every column (`FATIGUE_BASE / FATIGUE_STEP`); a single
## safe value (`2`) is the range `[2, 2]`. A row naming **one** knob with
## several ` / `-separated values is a per-band knob
## (`BOSS_STARTING_HEALTH_BY_BAND`, band 1 first): `{current: [int, …],
## range: [[min, max], …]}`.
func _gdd_tuning_knobs() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(GDD_PATH)
	var section: String = text.get_slice("\n## Tuning Knobs", 1).get_slice("\n## ", 0)
	var knob_name: RegEx = RegEx.create_from_string("`([A-Z][A-Z_]+)`")
	var rows: Dictionary = {}
	for line: String in section.split("\n"):
		if not line.begins_with("| `"):
			continue
		var cells: PackedStringArray = line.split("|")
		var names: Array = knob_name.search_all(cells[1]).map(func(m: RegExMatch) -> String: return m.get_string(1))
		var currents: PackedStringArray = cells[2].strip_edges().split(" / ")
		var ranges: PackedStringArray = cells[3].strip_edges().split(" / ")
		if names.size() == 1 and currents.size() > 1:
			var per_band: Array = []
			var band_ranges: Array = []
			for i: int in currents.size():
				per_band.append(int(currents[i]))
				band_ranges.append(_bounds(ranges[i]))
			rows[String(names[0]).to_lower()] = {"current": per_band, "range": band_ranges}
			continue
		for i: int in names.size():
			rows[String(names[i]).to_lower()] = {"current": int(currents[i]), "range": _bounds(ranges[i])}
	return rows


## `"7–10"` → `[7, 10]`; a single value `"2"` → `[2, 2]`.
func _bounds(cell: String) -> Array:
	var bounds: PackedStringArray = cell.strip_edges().split("–")
	var low: int = int(bounds[0])
	var high: int = int(bounds[1]) if bounds.size() > 1 else low
	return [low, high]


## Every key the `match_rules` body carries: the whole-number knobs, then the per-band knobs.
func _all_keys() -> Array:
	return Array(RulesEngine.CONFIG_KEYS) + Array(RulesEngine.CONFIG_BAND_KEYS)


# --- shipped file, through DataLoader ----------------------------------------

func test_shipped_match_rules_loads_through_data_loader_with_the_tuning_knob_defaults() -> void:
	# Act
	var result: DataLoader.LoadResult = _load_shipped()

	# Assert — the CR-1 envelope passed (no entry names the file) and the body
	# holds exactly the knobs, at the Tuning Knobs "Current value" (TestConstants)
	var file_entries: Array = result.report.entries().filter(func(e: Dictionary) -> bool: return e.file == RULES_FILE)
	assert_array(file_entries).is_empty()
	assert_object(result.snapshot).is_not_null()
	var body: Dictionary = result.snapshot.config_bodies["match_rules"]
	assert_array(_sorted(body.keys())).is_equal(_sorted(_all_keys()))
	var expected: Dictionary = MatchFactory.make_rules_config()
	for key: String in RulesEngine.CONFIG_KEYS:
		assert_int(int(body[key])).override_failure_message("match_rules.json %s" % key).is_equal(int(expected[key]))
	# DD-M02 band defaults: band 1 = 30, band 2 = 40, band 3 = 50
	for key: String in RulesEngine.CONFIG_BAND_KEYS:
		var shipped: Array = (body[key] as Array).map(func(v: Variant) -> int: return int(v))
		assert_array(shipped).override_failure_message("match_rules.json %s" % key).is_equal(Array(expected[key]))


func test_shipped_match_rules_passes_its_config_validator() -> void:
	# Arrange
	var body: Dictionary = _load_shipped().snapshot.config_bodies["match_rules"]

	# Act
	var errors: Array = RulesEngine.validate_rules_config(body, null)

	# Assert — present, whole and inside every safe range
	assert_array(errors).is_empty()


# --- the engine's safe ranges are the GDD's ------------------------------------

func test_config_safe_ranges_equal_the_gdd_tuning_knobs_safe_range_column() -> void:
	# Act
	var rows: Dictionary = _gdd_tuning_knobs()

	# Assert — every knob has one GDD row, with the same bounds and current value
	assert_array(_sorted(rows.keys())).is_equal(_sorted(_all_keys()))
	assert_array(_sorted(RulesEngine.CONFIG_SAFE_RANGES.keys())).is_equal(_sorted(RulesEngine.CONFIG_KEYS))
	assert_array(_sorted(RulesEngine.CONFIG_BAND_SAFE_RANGES.keys())).is_equal(_sorted(RulesEngine.CONFIG_BAND_KEYS))
	var body: Dictionary = _load_shipped().snapshot.config_bodies["match_rules"]
	for key: String in RulesEngine.CONFIG_KEYS:
		assert_array(RulesEngine.CONFIG_SAFE_RANGES[key]).override_failure_message("safe range %s" % key).is_equal(rows[key].range)
		assert_int(int(body[key])).override_failure_message("current value %s" % key).is_equal(rows[key].current)
	for key: String in RulesEngine.CONFIG_BAND_KEYS:
		assert_array(RulesEngine.CONFIG_BAND_SAFE_RANGES[key]).override_failure_message("safe range %s" % key).is_equal(rows[key].range)
		var shipped: Array = (body[key] as Array).map(func(v: Variant) -> int: return int(v))
		assert_array(shipped).override_failure_message("current value %s" % key).is_equal(rows[key].current)


# --- AC-41: no knob is a literal in src/ --------------------------------------

func test_knob_literal_scanner_catches_each_broken_form() -> void:
	# Act / Assert — the scanner has been seen to fire on every form it claims
	assert_array(_knob_literal_hits("const MAX_MANA: int = 10")).has_size(1)
	assert_array(_knob_literal_hits("var hand_size := 10")).has_size(1)
	assert_array(_knob_literal_hits("\t\"board_size\": 7,")).has_size(1)
	assert_array(_knob_literal_hits("\treturn clampi(n, 0, 4)")).has_size(1)
	assert_array(_knob_literal_hits("var cards: int = mini(hand.size(), 10)")).has_size(1)
	assert_array(_knob_literal_hits("var n: int = maxi(clampi(x, 0, rule(\"max_mana\")), 2)")).has_size(1)
	# ...and stays quiet on the engine's real forms
	assert_array(_knob_literal_hits("var n: int = rule(\"max_attacks_cap\")")).is_empty()
	assert_array(_knob_literal_hits("\treturn clampi(n, 0, rule(\"max_attacks_cap\"))")).is_empty()
	assert_array(_knob_literal_hits("\treturn maxi(0, total)")).is_empty()
	assert_array(_knob_literal_hits("\treturn clampi(n, 0, 4)  # comment")).has_size(1)
	assert_array(_knob_literal_hits("## clampi(n, 0, 4) in a doc comment")).is_empty()


func test_engine_source_binds_no_knob_to_a_literal() -> void:
	# Arrange
	var files: Array[String] = _gd_files(SRC_ROOT, [] as Array[String])
	assert_bool(files.has(SRC_ROOT.path_join("gameplay/match/rules_engine.gd"))).is_true()

	# Act
	var hits: Array[String] = []
	for path: String in files:
		for hit: String in _knob_literal_hits(FileAccess.get_file_as_string(path)):
			hits.append("%s: %s" % [path, hit])

	# Assert
	assert_array(hits).is_empty()
