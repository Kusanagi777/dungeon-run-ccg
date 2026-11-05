## Integration: the shipped `assets/data/ai_profiles.json` against the Boss AI
## GDD, the content MVP boss table and the entity registry (story
## boss-ai-match-driver/story-003; design/gdd/boss-ai.md F1, F2, F7, F9, C8.4,
## A19; design/gdd/content.md CN-3 B1; DD-H06; ADR-0002, ADR-0006).
##
## These checks read versioned repository files, so they live here and not in
## the unit suite (the match-rules precedent, `match_rules_config_file_test.gd`):
## the config through `DataLoader` (the one game-data parser, card-database
## CR-1 — strict JSON, envelope and `schema_version` included), and the GDD,
## content table and registry as text, so a design change that is not mirrored
## in the file fails here. The loader reads a scratch root under `user://` that
## `before()` stages from the `minimal/` fixture plus the shipped file and
## `after()` removes; the repository is only read.
extends GdUnitTestSuite

const SHIPPED: String = "res://assets/data/ai_profiles.json"
## `minimal/` supplies every other CR-1 file; the loader fails a root with a
## required file missing, and only two config files ship so far.
const FIXTURE_ROOT: String = "res://tests/fixtures/data/minimal/"
const STAGE_ROOT: String = "user://boss_ai_profiles_data_test/"
const BOSS_AI_GDD: String = "res://design/gdd/boss-ai.md"
const CONTENT_GDD: String = "res://design/gdd/content.md"
const REGISTRY: String = "res://design/registry/entities.yaml"
## Story 003 AC-1: the default rules the F9 summary, F1 normalisers, Tuning
## Knobs and the DEFENSIVE row (States, `w_face ×0.25`…) give. The F9 summary
## names four of them; the rest are spread over the GDD, so the story's list
## is the spec here.
const DEFAULT_RULES: Dictionary = {
	"hero_power": "spare_mana", "lethal_search": "full", "defensive": false, "assume_aoe": false,
	"trade_ratio": 1.0, "tie_epsilon": 0.05, "overextend_cap_aoe": 4.0, "burn_per_mana": 1.0,
	"defensive_margin": 3.0, "BV_NORM": 10.0, "THREAT_NORM": 12.0,
	"taunt_bonus": 1.5, "flat_spell_damage": 2.0, "flat_deathrattle": 1.0, "flat_aura": 2.0,
	"defensive_multipliers": {"w_face": 0.25, "w_self": 2.0, "w_heal": 2.0, "w_threat": 1.5},
}
## Story 003 AC-3 overlays beyond `extends` (content.md B1 `ai_profile` column).
const OVERRIDE_EXTRAS: Dictionary = {
	"boss_rot_warden": {"synergy_tags": ["deathrattle"], "weights": {"w_self": 1.5}},
	"boss_hollow_king": {"weights": {"w_board": 3.0}},
}


func before() -> void:
	DirAccess.make_dir_recursive_absolute(STAGE_ROOT)
	for file_name: String in DirAccess.get_files_at(FIXTURE_ROOT):
		if file_name.get_extension() == "json" and file_name != BossAI.PROFILES_FILE:
			DirAccess.copy_absolute(FIXTURE_ROOT + file_name, STAGE_ROOT + file_name)
	DirAccess.copy_absolute(SHIPPED, STAGE_ROOT + BossAI.PROFILES_FILE)


func after() -> void:
	for file_name: String in DirAccess.get_files_at(STAGE_ROOT):
		DirAccess.remove_absolute(STAGE_ROOT + file_name)
	DirAccess.remove_absolute(STAGE_ROOT)


# --- helpers -----------------------------------------------------------------

func _body() -> Dictionary:
	var result: DataLoader.LoadResult = DataLoader.new(STAGE_ROOT).run(ValidatorStubs.accept_all())
	GameAssertions.fail_if(result.snapshot == null, "staged load failed:\n%s" % result.report.to_text())
	return result.snapshot.config_bodies[BossAI.CONFIG_NAME]


func _sorted(items: Array) -> Array:
	var out: Array = items.duplicate()
	out.sort()
	return out


## The GDD section from heading [param heading] to the next heading of the
## same or a higher level ([param stop]).
func _section(text: String, heading: String, stop: String) -> String:
	return text.get_slice(heading, 1).get_slice(stop, 0)


## `"key value, key value"` (as the GDD writes deltas) → `{key: value}`, with
## numbers as float and `true`/`false` as bool.
func _pairs(spec: String) -> Dictionary:
	var out: Dictionary = {}
	var pair: RegEx = RegEx.create_from_string("([A-Za-z_]+) ([A-Za-z0-9_.]+)")
	for m: RegExMatch in pair.search_all(spec):
		var raw: String = m.get_string(2)
		var value: Variant = raw
		if raw == "true" or raw == "false":
			value = raw == "true"
		elif raw.is_valid_float():
			value = float(raw)
		out[m.get_string(1)] = value
	return out


## A GDD delta (`w_face 3.0, trade_ratio 1.3, choice_preference {charge 0.5}`)
## sorted into Profile sections: `w_*` → weights, `intent_mode` top level,
## `choice_preference {…}` its own map, everything else → rules.
func _delta_profile(spec: String) -> Dictionary:
	var flat: String = spec.replace("\n", " ")
	var profile: Dictionary = {}
	var choice: RegExMatch = RegEx.create_from_string("choice_preference \\{([^}]*)\\}").search(flat)
	if choice != null:
		profile["choice_preference"] = _pairs(choice.get_string(1))
		flat = flat.replace(choice.get_string(0), "")
	for key: String in _pairs(flat):
		var value: Variant = _pairs(flat)[key]
		var section: String = "weights" if key.begins_with("w_") else ("" if key == "intent_mode" else "rules")
		if section.is_empty():
			profile[key] = value
		else:
			if not profile.has(section):
				profile[section] = {}
			profile[section][key] = value
	return profile


## F9's archetype and band paragraph: `{"aggro": "<delta>", …, "1": "<delta>", …}`.
func _f9_deltas() -> Dictionary:
	var f9: String = _section(FileAccess.get_file_as_string(BOSS_AI_GDD), "### F9.", "\n## ")
	var out: Dictionary = {}
	var marked: RegEx = RegEx.create_from_string("\\*\\*([a-z_0-9]+)\\*\\*\\s+`([^`]+)`")
	for m: RegExMatch in marked.search_all(f9):
		out[m.get_string(1)] = m.get_string(2)
	return out


## The registry's `{boss id: band}` for every boss entity.
func _registry_bands() -> Dictionary:
	var bands: Dictionary = {}
	var current: String = ""
	for line: String in FileAccess.get_file_as_string(REGISTRY).split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("- name: "):
			current = stripped.trim_prefix("- name: ")
		elif stripped.begins_with("band: ") and current.begins_with("boss_"):
			bands[current] = int(stripped.trim_prefix("band: "))
			current = ""
	return bands


## content.md CN-3 B1 rows: `{boss id: {extends: first ai_profile token, batch}}`.
func _content_b1() -> Dictionary:
	var rows: Dictionary = {}
	var token: RegEx = RegEx.create_from_string("`([a-z_]+)`")
	for line: String in FileAccess.get_file_as_string(CONTENT_GDD).split("\n"):
		if not line.begins_with("| `boss_"):
			continue
		var cells: PackedStringArray = line.split("|")
		if cells.size() < 11:
			continue
		var id: String = token.search(cells[1]).get_string(1)
		rows[id] = {"extends": token.search(cells[8]).get_string(1), "batch": cells[10].strip_edges()}
	return rows


# --- load and validate (AC-4) ---------------------------------------------------

func test_shipped_file_loads_through_data_loader_with_no_entry_naming_it() -> void:
	# Act
	var result: DataLoader.LoadResult = DataLoader.new(STAGE_ROOT).run(ValidatorStubs.accept_all())

	# Assert — strict JSON, envelope and schema_version 1 (CR-1, CR-5 1-3)
	var entries: Array = result.report.entries().filter(func(e: Dictionary) -> bool: return e.file == BossAI.PROFILES_FILE)
	assert_array(entries).is_empty()
	assert_object(result.snapshot).is_not_null()


func test_shipped_file_reports_zero_e_ai_rows() -> void:
	# Act
	var rows: Array = BossAI.validate_profiles_config(_body(), null)

	# Assert
	assert_array(rows).override_failure_message(str(rows)).is_empty()


func test_sections_are_in_f9_order() -> void:
	# Act / Assert — Dictionary keeps the parser's (file) order
	assert_array(_body().keys()).is_equal(BossAI.TOP_LEVEL_SECTIONS)


# --- F9 tables (AC-1) ------------------------------------------------------------

func test_op_values_are_f9s_twenty_card_effects_ops_with_its_values() -> void:
	# Arrange — F9: `op_values: {…} damage 1.0, destroy 2.0, …, retrigger 1.5,
	# add_counter 0.5` (content story 010, DD-X20)
	var f9: String = _section(FileAccess.get_file_as_string(BOSS_AI_GDD), "### F9.", "\n## ")
	var block: String = f9.get_slice("op_values:", 1).get_slice("keyword_values:", 0)
	var expected: Dictionary = {}
	for m: RegExMatch in RegEx.create_from_string("([a-z_]+) ([0-9]+\\.[0-9]+)").search_all(block):
		expected[m.get_string(1)] = float(m.get_string(2))

	# Act
	var op_values: Dictionary = _body().op_values

	# Assert
	assert_int(expected.size()).is_equal(20)
	assert_float(float(expected.get("add_counter", -1.0))).is_equal(0.5)
	assert_dict(op_values).is_equal(expected)
	assert_str(f9).not_contains("does not yet carry")


func test_keyword_values_are_the_f2_multipliers() -> void:
	# Arrange — F2 `keyword_mult` row: `taunt 1.2, divine_shield 1.3, …`
	var f2: String = _section(FileAccess.get_file_as_string(BOSS_AI_GDD), "### F2.", "\n### ")
	var row: String = ""
	for line: String in f2.split("\n"):
		if line.begins_with("| keyword_mult |"):
			row = line.split("|")[5]

	# Act / Assert
	assert_dict(_body().keyword_values).is_equal(_pairs(row))


func test_default_weights_and_ranges_are_the_f1_table() -> void:
	# Arrange — F1 rows `| w_face | float | 0–5 | data file | default 1.5; …`
	var f1: String = _section(FileAccess.get_file_as_string(BOSS_AI_GDD), "### F1.", "\n### ")
	var row: RegEx = RegEx.create_from_string("^\\| (w_[a-z]+) \\| float \\| ([0-9.]+)–([0-9.]+) \\| data file \\| default ([0-9.]+)")
	var expected: Dictionary = {}
	for line: String in f1.split("\n"):
		var m: RegExMatch = row.search(line)
		if m != null:
			expected[m.get_string(1)] = float(m.get_string(4))
			# RANGES is pinned to the same rows
			assert_float(BossAI.RANGES[m.get_string(1)].min).is_equal(float(m.get_string(2)))
			assert_float(BossAI.RANGES[m.get_string(1)].max).is_equal(float(m.get_string(3)))

	# Act / Assert
	assert_array(_sorted(expected.keys())).is_equal(_sorted(BossAI.WEIGHT_KEYS))
	assert_dict(_body().profiles.default.weights).is_equal(expected)


func test_default_rules_and_intent_are_the_story_list() -> void:
	# Act
	var default_profile: Dictionary = _body().profiles.default

	# Assert
	assert_dict(default_profile.rules).is_equal(DEFAULT_RULES)
	assert_str(default_profile.intent_mode).is_equal("full")
	assert_dict(default_profile.choice_preference).is_empty()
	assert_array(default_profile.synergy_tags).is_empty()


func test_archetypes_carry_exactly_f9s_deltas() -> void:
	# Arrange
	var deltas: Dictionary = _f9_deltas()
	var profiles: Dictionary = _body().profiles

	# Act / Assert — default plus the four archetypes, each exactly its delta
	assert_array(_sorted(profiles.keys())).is_equal(_sorted(["default", "aggro", "control", "tempo", "passive_driven"]))
	for archetype: String in ["aggro", "control", "tempo", "passive_driven"]:
		assert_dict(profiles[archetype]).override_failure_message(archetype).is_equal(_delta_profile(deltas[archetype]))


func test_band_overlays_carry_f9s_rules_and_f7s_budgets() -> void:
	# Arrange — F7 rows `| \`lethal_max_nodes\` | 50 | 500 | 4000 | …`
	var deltas: Dictionary = _f9_deltas()
	var f7: String = _section(FileAccess.get_file_as_string(BOSS_AI_GDD), "### F7.", "\n### ")
	var row: RegEx = RegEx.create_from_string("^\\| `([a-z_]+)` \\| ([0-9]+) \\| ([0-9]+) \\| ([0-9]+) \\|")
	var budgets: Dictionary = {"1": {}, "2": {}, "3": {}}
	for line: String in f7.split("\n"):
		var m: RegExMatch = row.search(line)
		if m != null:
			for band: int in [1, 2, 3]:
				budgets[str(band)][m.get_string(1)] = float(m.get_string(band + 1))
	var bands: Dictionary = _body().bands

	# Act / Assert
	assert_array(bands.keys()).is_equal(BossAI.BAND_KEYS)
	for band: String in BossAI.BAND_KEYS:
		var expected: Dictionary = _delta_profile(deltas[band])
		expected["budgets"] = budgets[band]
		assert_dict(bands[band]).override_failure_message("band %s" % band).is_equal(expected)
	assert_float(bands["3"].budgets.lethal_max_nodes).is_equal(4000.0)


func test_f2_bonuses_ship_in_the_default_rules_at_f2s_values() -> void:
	# Arrange: A29, review D-3: these moved out of `Scorer.NORMALISERS` unchanged
	var rules: Dictionary = _body().profiles.default.rules

	# Act and Assert
	assert_float(float(rules.taunt_bonus)).is_equal(1.5)
	assert_float(float(rules.flat_spell_damage)).is_equal(2.0)
	assert_float(float(rules.flat_deathrattle)).is_equal(1.0)
	assert_float(float(rules.flat_aura)).is_equal(2.0)


func test_presentation_and_runtime_are_f9s_lines() -> void:
	# Arrange — F9 `presentation: {action_delay_s 0.6, …}` and `runtime: {planner_mode … (default worker), slice_ms 2, replay_budget_ms 2}`
	var f9: String = _section(FileAccess.get_file_as_string(BOSS_AI_GDD), "### F9.", "\n## ")
	var presentation_line: String = f9.get_slice("presentation:", 1).get_slice("\n", 0)
	var runtime_line: String = f9.get_slice("runtime:", 1).get_slice("\n", 0)
	var runtime_expected: Dictionary = _pairs(runtime_line.get_slice("),", 1))
	runtime_expected["planner_mode"] = RegEx.create_from_string("\\(default ([a-z_]+)\\)").search(runtime_line).get_string(1)
	var body: Dictionary = _body()

	# Act / Assert
	assert_dict(body.presentation).is_equal(_pairs(presentation_line))
	assert_dict(body.runtime).is_equal(runtime_expected)
	assert_str(body.runtime.planner_mode).is_equal("worker")


# --- runtime.planner_target_ms (handoff 2026-11-04 section 4, DD-X18; QA NC-8) ---------

## The `.gd` paths under [param dir], recursively.
func _scripts_under(dir: String) -> Array[String]:
	var paths: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.get_extension() == "gd":
			paths.append(dir.path_join(file_name))
	for child: String in DirAccess.get_directories_at(dir):
		paths.append_array(_scripts_under(dir.path_join(child)))
	return paths


func test_shipped_planner_target_is_the_500_of_the_registry() -> void:
	# Arrange — the registry key is `ai_planner_target_ms`, the data key `planner_target_ms`
	var registry: PackedStringArray = FileAccess.get_file_as_string(REGISTRY).split("\n")
	var row: int = registry.find("  - name: ai_planner_target_ms")
	var value_line: String = ""
	for line: String in registry.slice(row):
		if line.strip_edges().begins_with("value: "):
			value_line = line.strip_edges()
			break

	# Act
	var shipped: Variant = _body().runtime.planner_target_ms

	# Assert
	assert_float(float(shipped)).is_equal(500.0)
	assert_str(value_line).is_equal("value: %d" % int(shipped))


func test_planner_target_reads_through_the_database_and_refuses_a_write() -> void:
	# Arrange — `make_read_only()` is shallow: this proves the nested block is frozen
	var db: CardDatabase = CardDatabase.new(DataLoader.new(STAGE_ROOT))
	db.load(ValidatorStubs.accept_all())
	var runtime: Dictionary = db.config(BossAI.CONFIG_NAME).runtime

	# Act / Assert
	assert_bool(runtime.is_read_only()).is_true()
	await assert_error(func() -> void: runtime["planner_target_ms"] = 1).is_runtime_error("Invalid assignment on read-only value (on base: 'Dictionary').")
	assert_float(float(db.config(BossAI.CONFIG_NAME).runtime.planner_target_ms)).is_equal(500.0)


func test_planner_target_is_never_a_runtime_clock() -> void:
	# Arrange — a measurement target: the validator names it, no planner or rules code reads it
	var readers: Array[String] = []

	# Act
	for root: String in ["res://src/ai", "res://src/gameplay"]:
		for path: String in _scripts_under(root):
			if path != "res://src/ai/boss_ai.gd" and FileAccess.get_file_as_string(path).contains("planner_target_ms"):
				readers.append(path)

	# Assert
	assert_array(readers).is_empty()


# --- boss overrides (AC-3) ---------------------------------------------------------

func test_boss_overrides_are_the_five_mvp_bosses_of_content_b1() -> void:
	# Arrange
	var b1: Dictionary = _content_b1()
	var mvp: Array = b1.keys().filter(func(id: String) -> bool: return String(b1[id].batch).begins_with("MVP"))
	var overrides: Dictionary = _body().boss_overrides

	# Act / Assert — the 11 non-MVP bosses are absent
	assert_int(b1.size()).is_equal(16)
	assert_array(_sorted(overrides.keys())).is_equal(_sorted(mvp))
	for id: String in overrides:
		var expected: Dictionary = {BossAI.EXTENDS_KEY: b1[id].extends}
		expected.merge(OVERRIDE_EXTRAS.get(id, {}))
		assert_dict(overrides[id]).override_failure_message(id).is_equal(expected)


func test_override_ids_are_registry_bosses_split_three_one_one_by_band() -> void:
	# Arrange — DD-H06: 3 band 1, 1 band 2, 1 band 3
	var registry: Dictionary = _registry_bands()
	var per_band: Array = [0, 0, 0]

	# Act
	for id: String in _body().boss_overrides:
		assert_bool(registry.has(id)).override_failure_message("%s not in entities.yaml" % id).is_true()
		per_band[registry.get(id, 1) - 1] += 1

	# Assert
	assert_array(per_band).is_equal([3, 1, 1])


func test_torchbearer_override_resolves_as_aggro_with_its_band_overlay() -> void:
	# Arrange — the batch-0 boss (content story 001)
	var body: Dictionary = _body()
	var boss: Dictionary = CardFactory.make_boss_def("boss_torchbearer", 1, {"ai_profile": "boss_torchbearer"})

	# Act
	var profile: Dictionary = ProfileResolver.resolve(body, boss, 1)

	# Assert
	assert_array(BossAI.validate_ai_profile(&"boss", "boss_torchbearer", "boss_torchbearer", null, {"ai_profiles": body})).is_empty()
	assert_str(body.boss_overrides.boss_torchbearer.extends).is_equal("aggro")
	assert_float(profile.weights.w_face).is_equal(body.profiles.aggro.weights.w_face)
	assert_float(profile.weights.w_trade).is_equal(body.bands["1"].weights.w_trade)
	assert_dict(profile.budgets).is_equal(body.bands["1"].budgets)


func test_rot_warden_and_hollow_king_resolve_their_extra_values() -> void:
	# Arrange
	var body: Dictionary = _body()
	var registry: Dictionary = _registry_bands()

	# Act
	var rot: Dictionary = ProfileResolver.resolve(body, CardFactory.make_boss_def("boss_rot_warden", registry.boss_rot_warden, {"ai_profile": "boss_rot_warden"}), registry.boss_rot_warden)
	var hollow: Dictionary = ProfileResolver.resolve(body, CardFactory.make_boss_def("boss_hollow_king", registry.boss_hollow_king, {"ai_profile": "boss_hollow_king"}), registry.boss_hollow_king)

	# Assert
	assert_float(rot.weights.w_passive).is_equal(body.profiles.passive_driven.weights.w_passive)
	assert_float(rot.weights.w_self).is_equal(1.5)
	assert_array(rot.synergy_tags).is_equal(["deathrattle"])
	assert_float(hollow.weights.w_board).is_equal(3.0)
	assert_float(hollow.weights.w_threat).is_equal(body.profiles.control.weights.w_threat)
	assert_bool(hollow.rules.defensive).is_true()


func test_no_mvp_boss_or_band_overlay_resolves_to_hidden() -> void:
	# Arrange — A19 last clause, C8.4, D-04
	var body: Dictionary = _body()
	var registry: Dictionary = _registry_bands()

	# Act / Assert — each MVP boss at its own band, and each band with no override
	for id: String in body.boss_overrides:
		assert_bool(body.boss_overrides[id].has("intent_mode")).override_failure_message(id).is_false()
		var band: int = registry[id]
		var profile: Dictionary = ProfileResolver.resolve(body, CardFactory.make_boss_def(id, band, {"ai_profile": id}), band)
		assert_str(profile.intent_mode).override_failure_message(id).is_equal("full")
	for band: int in [1, 2, 3]:
		var plain: Dictionary = ProfileResolver.resolve(body, CardFactory.make_boss_def("boss_x", band, {"ai_profile": "default"}), band)
		assert_str(plain.intent_mode).override_failure_message("band %d" % band).is_not_equal("hidden")


# --- file format (Implementation Notes) ---------------------------------------------

func test_integer_knobs_are_written_without_a_fractional_part_and_indent_is_two_spaces() -> void:
	# Arrange
	var text: String = FileAccess.get_file_as_string(SHIPPED)
	var integral: Array = BossAI.RANGES.keys().filter(func(k: String) -> bool: return BossAI.RANGES[k].integral)
	var fractional: RegEx = RegEx.create_from_string("\"(%s)\": -?[0-9]+\\.[0-9]" % "|".join(integral))

	# Act
	var odd_indent: Array = []
	for line: String in text.split("\n"):
		var lead: int = line.length() - line.lstrip(" ").length()
		if line.begins_with("\t") or lead % 2 != 0:
			odd_indent.append(line)

	# Assert
	assert_array(integral).is_not_empty()
	assert_object(fractional.search(text)).is_null()
	assert_array(odd_indent).is_empty()
