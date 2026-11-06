## Integration: the shipped `assets/data/card_effects.json` and the rules
## source tree against card-effects AC-41 (story card-effects/story-002;
## design/gdd/card-effects.md Tuning Knobs, F6; ADR-0002 Decision 4; ADR-0007
## Decisions 7–8).
##
## These checks read versioned repository files, so they live here and not in
## the unit suite: the config through `DataLoader` (the one game-data parser,
## card-database CR-1), the GDD's Tuning Knobs table as text (to pin
## `EffectValidator`'s safe ranges and the shipped values to it), and every
## `.gd` under the rules tree (AC-41's "no knob literal" and "no global RNG"
## scans). The loader reads a scratch root under `user://` that `before()`
## stages and `after()` removes; the repository is only read.
extends GdUnitTestSuite

const SHIPPED_EFFECTS: String = "res://assets/data/card_effects.json"
## `minimal/` supplies every other CR-1 file (the loader fails a root with a
## required file missing).
const FIXTURE_ROOT: String = "res://tests/fixtures/data/minimal/"
const STAGE_ROOT: String = "user://card_effects_config_file_test/"
const EFFECTS_FILE: String = "card_effects.json"
const GDD_PATH: String = "res://design/gdd/card-effects.md"
const EFFECTS_SRC: String = "res://src/gameplay/effects"
## The rules tree (ADR-0001 tiers): rules and AI code.
const RULES_SRC: Array[String] = ["res://src/gameplay", "res://src/ai"]
## The G6 regex of `tools/lint/gates.sh` (ADR-0003 erratum), plus the class
## name ADR-0007 Decision 7 forbids under `src/gameplay/effects/**`.
const GLOBAL_RNG: String = "(^|[^.\\w])(randi|randf|randi_range|randf_range|seed|randomize)\\(|\\.shuffle\\(\\)|pick_random\\(|RandomNumberGenerator"


# --- setup ---------------------------------------------------------------------

func before() -> void:
	DirAccess.make_dir_recursive_absolute(STAGE_ROOT)
	for file_name: String in DirAccess.get_files_at(FIXTURE_ROOT):
		if file_name.get_extension() == "json" and file_name != EFFECTS_FILE:
			DirAccess.copy_absolute(FIXTURE_ROOT + file_name, STAGE_ROOT + file_name)
	DirAccess.copy_absolute(SHIPPED_EFFECTS, STAGE_ROOT + EFFECTS_FILE)


func after() -> void:
	for file_name: String in DirAccess.get_files_at(STAGE_ROOT):
		DirAccess.remove_absolute(STAGE_ROOT + file_name)
	DirAccess.remove_absolute(STAGE_ROOT)


# --- helpers -------------------------------------------------------------------

func _shipped_body() -> Dictionary:
	var result: DataLoader.LoadResult = DataLoader.new(STAGE_ROOT).run(ValidatorStubs.accept_all())
	return result.snapshot.config_bodies["card_effects"]


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


## The JSON value a Tuning Knobs cell token stands for: `true` / `false` are
## booleans, a number is an int, anything else (`auto`) a String.
func _token_value(token: String) -> Variant:
	if token == "true":
		return true
	if token == "false":
		return false
	if token.is_valid_int():
		return int(token)
	return token


## The GDD Tuning Knobs rows as `{<snake_case key>: {current, range | allowed}}`:
## an `a–b` safe range becomes `range: [a, b]`; a list of backticked values
## (`` `true`/`false` ``, `` `true` only ``) becomes `allowed: [...]`.
func _gdd_tuning_knobs() -> Dictionary:
	var text: String = FileAccess.get_file_as_string(GDD_PATH)
	var section: String = text.get_slice("\n## Tuning Knobs", 1).get_slice("\n## ", 0)
	var backticked: RegEx = RegEx.create_from_string("`([^`]+)`")
	var rows: Dictionary = {}
	for line: String in section.split("\n"):
		if not line.begins_with("| `"):
			continue
		var cells: PackedStringArray = line.split("|")
		var key: String = backticked.search(cells[1]).get_string(1).to_lower()
		var current: String = cells[2].strip_edges().trim_prefix("`").trim_suffix("`")
		var safe: String = cells[3].strip_edges()
		var row: Dictionary = {"current": _token_value(current)}
		if safe.contains("–"):
			row["range"] = [int(safe.get_slice("–", 0)), int(safe.get_slice("–", 1))]
		else:
			row["allowed"] = backticked.search_all(safe).map(func(m: RegExMatch) -> Variant: return _token_value(m.get_string(1)))
		rows[key] = row
	return rows


## AC-41 knob scan over GDScript source: a line binds a card-effects knob name
## (any case, as a whole word) to a literal — a number, `true`, `false` or a
## quoted string (`const MAX_REPEAT: int = 10`, `var discover_count := 3`,
## `"spell_damage_default": "auto"`). Comments are ignored.
func _knob_literal_hits(source: String) -> Array[String]:
	var names: String = "|".join(EffectValidator.CONFIG_KEYS)
	var binding: RegEx = RegEx.create_from_string("(?i)\\b(%s)\\b[\"']?\\s*(?::\\s*\\w+\\s*)?(?::=|=|:)\\s*(-?\\d|true\\b|false\\b|[\"'])" % names)
	var hits: Array[String] = []
	for line: String in source.split("\n"):
		if binding.search(line.split("#")[0]) != null:
			hits.append(line.strip_edges())
	return hits


## Global-RNG scan ([constant GLOBAL_RNG]); comment lines and trailing
## comments are ignored, as G6 ignores them.
func _global_rng_hits(source: String) -> Array[String]:
	var rng: RegEx = RegEx.create_from_string(GLOBAL_RNG)
	var hits: Array[String] = []
	for line: String in source.split("\n"):
		if rng.search(line.split("#")[0]) != null:
			hits.append(line.strip_edges())
	return hits


# --- the shipped file ----------------------------------------------------------

func test_shipped_card_effects_loads_with_exactly_the_tuning_knobs() -> void:
	# Act
	var result: DataLoader.LoadResult = DataLoader.new(STAGE_ROOT).run(ValidatorStubs.accept_all())

	# Assert — the DD-T01 envelope passed (no entry names the file); snake_case keys
	var file_entries: Array = result.report.entries().filter(func(e: Dictionary) -> bool: return e.file == EFFECTS_FILE)
	assert_array(file_entries).is_empty()
	var body: Dictionary = result.snapshot.config_bodies["card_effects"]
	assert_array(_sorted(body.keys())).is_equal(_sorted(EffectValidator.CONFIG_KEYS))


func test_shipped_card_effects_passes_its_config_validator() -> void:
	# Act
	var errors: Array = EffectValidator.validate_config(_shipped_body(), null)

	# Assert
	assert_array(errors).is_empty()


func test_shipped_values_are_the_gdd_current_values() -> void:
	# Arrange
	var rows: Dictionary = _gdd_tuning_knobs()
	var body: Dictionary = _shipped_body()

	# Assert — every knob, as JSON parses it (numbers are floats)
	assert_array(_sorted(rows.keys())).is_equal(_sorted(EffectValidator.CONFIG_KEYS))
	for key: String in EffectValidator.CONFIG_KEYS:
		var shipped: Variant = body[key]
		if typeof(shipped) == TYPE_FLOAT:
			shipped = int(shipped)
		assert_that(shipped).override_failure_message("card_effects.json %s" % key).is_equal(rows[key].current)


func test_validator_safe_ranges_equal_the_gdd_safe_range_column() -> void:
	# Act
	var rows: Dictionary = _gdd_tuning_knobs()

	# Assert — whole-number knobs by range, the others by their allowed values
	for key: String in EffectValidator.CONFIG_KEYS:
		if rows[key].has("range"):
			assert_array(EffectValidator.CONFIG_INT_RANGES.get(key, [])).override_failure_message("range %s" % key).is_equal(rows[key].range)
		else:
			assert_array(EffectValidator.CONFIG_ALLOWED_VALUES.get(key, [])).override_failure_message("allowed %s" % key).is_equal(rows[key].allowed)
	assert_int(EffectValidator.CONFIG_INT_RANGES.size() + EffectValidator.CONFIG_ALLOWED_VALUES.size()).is_equal(EffectValidator.CONFIG_KEYS.size())


# --- AC-41: no knob literal, no global RNG -------------------------------------

func test_scanners_fire_on_each_broken_form_and_stay_quiet_on_the_real_ones() -> void:
	# Knob literals
	assert_array(_knob_literal_hits("const MAX_REPEAT: int = 10")).has_size(1)
	assert_array(_knob_literal_hits("var discover_count := 3")).has_size(1)
	assert_array(_knob_literal_hits("const HOOKS_BEFORE_TRIGGERS := true")).has_size(1)
	assert_array(_knob_literal_hits("\t\"spell_damage_default\": \"auto\",")).has_size(1)
	assert_array(_knob_literal_hits("var n: int = knob_int(\"discover_count\")")).is_empty()
	assert_array(_knob_literal_hits("\t\"max_repeat\": [2, 20],")).is_empty()
	assert_array(_knob_literal_hits("const KNOB_MAX_REPEAT: String = \"max_repeat\"")).is_empty()
	assert_array(_knob_literal_hits("## MAX_REPEAT = 10 in a doc comment")).is_empty()
	# Global RNG — the planted calls are split across `+` so this file's own
	# text is not a hit for tools/lint/no_global_rng.sh, which scans tests too
	assert_array(_global_rng_hits("\tvar i: int = rand" + "i_range(0, 3)")).has_size(1)
	assert_array(_global_rng_hits("\tpool.shuf" + "fle()")).has_size(1)
	assert_array(_global_rng_hits("\tvar r := Random" + "NumberGenerator.new()")).has_size(1)
	assert_array(_global_rng_hits("\tvar x: Variant = pool.pick_" + "random()")).has_size(1)
	assert_array(_global_rng_hits("\tvar i: int = engine.rng_match().randi_range(0, 3)")).is_empty()
	assert_array(_global_rng_hits("## never names RandomNumberGenerator")).is_empty()


func test_effects_source_binds_no_knob_to_a_literal() -> void:
	# Arrange
	var files: Array[String] = _gd_files(EFFECTS_SRC, [] as Array[String])
	assert_bool(files.has(EFFECTS_SRC.path_join("effect_resolver.gd"))).is_true()

	# Act
	var hits: Array[String] = []
	for path: String in files:
		for hit: String in _knob_literal_hits(FileAccess.get_file_as_string(path)):
			hits.append("%s: %s" % [path, hit])

	# Assert
	assert_array(hits).is_empty()


func test_rules_tree_holds_no_global_rng_call() -> void:
	# Arrange
	var files: Array[String] = []
	for root: String in RULES_SRC:
		_gd_files(root, files)
	assert_bool(files.has(EFFECTS_SRC.path_join("effect_resolver.gd"))).is_true()

	# Act
	var hits: Array[String] = []
	for path: String in files:
		for hit: String in _global_rng_hits(FileAccess.get_file_as_string(path)):
			hits.append("%s: %s" % [path, hit])

	# Assert
	assert_array(hits).is_empty()
