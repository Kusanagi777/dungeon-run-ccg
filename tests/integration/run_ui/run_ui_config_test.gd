## `RunUiConfig`: the F2, F3, F4 arithmetic over the shipped `run_ui.json`, and the
## validator against every row of run-ui Tuning Knobs (AC-24, AC-25, AC-27).
extends GdUnitTestSuite

## Knob, lowest legal value, highest legal value (run-ui Tuning Knobs).
const INT_KNOBS: Array = [
	["restart_budget_ms", 3000, 5000],
	["run_start_ms", 0, 1000],
	["toast_base_ms", 3000, 6000],
	["toast_per_char_ms", 20, 50],
	["toast_min_ms", 5000, 6000],
	["toast_max_ms", 6000, 10000],
	["toast_gap_ms", 100, 500],
	["toast_queue_max", 4, 16],
	["node_d", 16, 32],
	["seg_len", 16, 48],
	["strip_max_w", 480, 800],
]
## Every font role `RunUiTheme.build` reads.
const ROLES: Array[String] = ["hero", "title", "heading", "body", "small", "muted"]
## The art-bible minimum (run-ui Tuning Knobs `text_scale`: "never below the 12 px minimum").
const FONT_FLOOR_PX: int = 12


func _body() -> Dictionary:
	return RunUiRig.config().duplicate(true)


func _fields(body: Dictionary) -> Array:
	return RunUiConfig.validate_config(body, null).map(func(row: Dictionary) -> String: return str(row.field))


func _codes(body: Dictionary, field: String) -> Array:
	var rows: Array = RunUiConfig.validate_config(body, null).filter(func(row: Dictionary) -> bool: return str(row.field) == field)
	return rows.map(func(row: Dictionary) -> StringName: return row.code)


# --- F2 ---------------------------------------------------------------------------

func test_t_transition_scales_every_kind_by_speed_factor() -> void:
	var cfg: Dictionary = _body()
	assert_int(RunUiConfig.t_transition(cfg, &"fade", "normal", false)).is_equal(250)
	assert_int(RunUiConfig.t_transition(cfg, &"fade", "fast", false)).is_equal(125)
	assert_int(RunUiConfig.t_transition(cfg, &"draft_reveal", "fast", false)).is_equal(180)
	assert_int(RunUiConfig.t_transition(cfg, &"run_start", "normal", false)).is_equal(600)
	assert_int(RunUiConfig.t_transition(cfg, &"run_start", "fast", false)).is_equal(300)


func test_t_transition_is_zero_for_every_kind_at_instant() -> void:
	var cfg: Dictionary = _body()
	for kind: StringName in [&"fade", &"run_start", &"intro_slide", &"draft_reveal", &"fly_to_strip", &"toast_in_out"]:
		assert_int(RunUiConfig.t_transition(cfg, kind, "instant", false)).is_equal(0)
		assert_int(RunUiConfig.t_transition(cfg, kind, "instant", true)).is_equal(0)


func test_reduce_motion_halves_the_slides_and_leaves_a_fade() -> void:
	var cfg: Dictionary = _body()
	assert_int(RunUiConfig.t_transition(cfg, &"fly_to_strip", "normal", true)).is_equal(200)
	assert_int(RunUiConfig.t_transition(cfg, &"draft_reveal", "normal", true)).is_equal(180)
	assert_int(RunUiConfig.t_transition(cfg, &"toast_in_out", "normal", true)).is_equal(100)
	assert_int(RunUiConfig.t_transition(cfg, &"intro_slide", "normal", true)).is_equal(150)
	assert_int(RunUiConfig.t_transition(cfg, &"fade", "normal", true)).is_equal(250)


func test_unknown_speed_reads_as_normal() -> void:
	assert_int(RunUiConfig.t_transition(_body(), &"fade", "ludicrous", false)).is_equal(250)


# --- F1 ---------------------------------------------------------------------------

func test_f1_machine_budget_defaults_leave_the_gdd_headroom() -> void:
	# Arrange: the measured steps at their GDD budgets (F1 Variables)
	var cfg: Dictionary = _body()
	var new_run_ms: int = 200
	var intro_ready_ms: int = 300
	var select_ready_ms: int = 300
	var human_pick_ms: int = 1500
	var fade: int = RunUiConfig.t_transition(cfg, &"fade", "normal", false)
	var seed_card: int = RunUiConfig.t_transition(cfg, &"run_start", "normal", false)

	# Act
	var path_a: int = fade + new_run_ms + seed_card + intro_ready_ms
	var path_b: int = fade + select_ready_ms + human_pick_ms + new_run_ms + seed_card + intro_ready_ms

	# Assert: F1 Output Range
	assert_int(path_a).is_equal(1350)
	assert_int(path_b).is_equal(3150)
	assert_int(path_b).is_less_equal(int(cfg.restart_budget_ms))
	var instant_a: int = RunUiConfig.t_transition(cfg, &"fade", "instant", false) + new_run_ms + RunUiConfig.t_transition(cfg, &"run_start", "instant", false) + intro_ready_ms
	assert_int(instant_a).is_equal(500)


# --- F3 ---------------------------------------------------------------------------

func test_t_toast_bounds_and_the_worked_example() -> void:
	var cfg: Dictionary = _body()
	assert_int(RunUiConfig.t_toast(cfg, 10)).is_equal(5300)
	assert_int(RunUiConfig.t_toast(cfg, 200)).is_equal(8000)
	assert_int(RunUiConfig.t_toast(cfg, 32)).is_equal(5960)
	assert_int(RunUiConfig.t_toast(cfg, 0)).is_equal(5000)


func test_toast_min_ms_holds_the_accessibility_floor() -> void:
	assert_int(int(_body().toast_min_ms)).is_greater_equal(5000)


# --- F4 ---------------------------------------------------------------------------

func test_slot_x_treasure_and_bundle_positions() -> void:
	var cfg: Dictionary = _body()
	var width: int = int(cfg.design_width)
	var treasure: Array = [0, 1, 2].map(func(i: int) -> int: return RunUiConfig.slot_x(i, 3, int(cfg.option_w.treasure), int(cfg.option_gap.treasure), width))
	var bundle: Array = [0, 1, 2].map(func(i: int) -> int: return RunUiConfig.slot_x(i, 3, int(cfg.option_w.bundle), int(cfg.option_gap.bundle), width))
	assert_array(treasure).is_equal([367, 565, 763])
	assert_array(bundle).is_equal([90, 470, 850])


func test_strip_node_centres_at_eight_and_four_floors() -> void:
	var cfg: Dictionary = _body()
	var eight: Dictionary = RunUiConfig.strip_layout(cfg, 8)
	var four: Dictionary = RunUiConfig.strip_layout(cfg, 4)
	assert_int(int(eight.width)).is_equal(472)
	assert_int(int(eight.x0)).is_equal(404)
	assert_int(int(four.width)).is_equal(216)
	assert_int(int(four.x0)).is_equal(532)
	for f: int in range(1, 9):
		assert_int(RunUiConfig.node_cx(eight, f)).is_equal(416 + 64 * (f - 1))
	for f: int in range(1, 5):
		assert_int(RunUiConfig.node_cx(four, f)).is_equal(544 + 64 * (f - 1))


func test_strip_width_never_exceeds_its_maximum_up_to_twelve_floors() -> void:
	var cfg: Dictionary = _body()
	for floors: int in range(3, 13):
		assert_int(int(RunUiConfig.strip_layout(cfg, floors).width)).is_less_equal(int(cfg.strip_max_w))
	assert_int(int(RunUiConfig.strip_layout(cfg, 12).seg_len)).is_equal(32)


func test_strip_drops_initials_under_the_minimum_segment() -> void:
	# Arrange: a narrow strip forces seg_len under `initials_min_seg`
	var cfg: Dictionary = _body()
	cfg.strip_max_w = 480
	cfg.node_d = 32

	# Act
	var layout: Dictionary = RunUiConfig.strip_layout(cfg, 12)

	# Assert
	assert_int(int(layout.seg_len)).is_less(int(cfg.initials_min_seg))
	assert_bool(layout.initials).is_false()
	assert_bool(RunUiConfig.strip_layout(_body(), 8).initials).is_true()


func test_changing_node_d_moves_the_drawn_strip() -> void:
	# Arrange (AC-27)
	var cfg: Dictionary = _body()
	var model: Dictionary = {"nodes": [
		{"floor": 1, "band": 1, "band_color": "boss_band_1", "state": "cleared", "initial": "A", "tip": "a", "gem": false},
		{"floor": 2, "band": 1, "band_color": "boss_band_1", "state": "current", "initial": "B", "tip": "b", "gem": false},
	], "treasures": [], "deck_size": 15}
	var strip: ProgressStrip = auto_free(ProgressStrip.new())
	add_child(strip)

	# Act
	strip.show_strip(cfg, model)
	var before: float = strip.focus_stops()[1].position.x
	cfg.node_d = 32
	strip.show_strip(cfg, model)
	var after: float = strip.focus_stops()[1].position.x

	# Assert: the half-width grows by 4 + 4 and the step by 8 on a two-node strip
	assert_float(after).is_not_equal(before)
	var expected: int = RunUiConfig.node_cx(RunUiConfig.strip_layout(cfg, 2), 2)
	assert_float(after + ProgressStrip.NODE_HIT_W / 2.0).is_equal(float(expected))


# --- Validator ----------------------------------------------------------------------

func test_shipped_body_validates_clean() -> void:
	assert_array(RunUiConfig.validate_config(_body(), null)).is_empty()


func test_every_int_knob_refuses_just_outside_its_range_and_takes_its_bounds() -> void:
	for knob: Array in INT_KNOBS:
		var field: String = knob[0]
		for good: int in [knob[1], knob[2]]:
			var body: Dictionary = _body()
			body[field] = good
			assert_array(_codes(body, field)).override_failure_message("%s=%d refused" % [field, good]).is_empty()
		for bad: int in [knob[1] - 1, knob[2] + 1]:
			var body: Dictionary = _body()
			body[field] = bad
			assert_array(_codes(body, field)).override_failure_message("%s=%d taken" % [field, bad]).contains([ConfigRows.E_RANGE])


func test_a_fractional_knob_is_a_bad_value() -> void:
	var body: Dictionary = _body()
	body.toast_gap_ms = 150.5
	assert_array(_codes(body, "toast_gap_ms")).contains([ConfigRows.E_BAD_VALUE])


func test_transition_ranges_follow_tuning_knobs() -> void:
	for row: Array in [["fade", 400], ["intro_slide", 600], ["draft_reveal", 600], ["fly_to_strip", 600], ["toast_in_out", 600]]:
		var body: Dictionary = _body()
		body.transition_ms[row[0]] = row[1]
		assert_array(_codes(body, "transition_ms.%s" % row[0])).is_empty()
		body.transition_ms[row[0]] = row[1] + 1
		assert_array(_codes(body, "transition_ms.%s" % row[0])).contains([ConfigRows.E_RANGE])
		body.transition_ms[row[0]] = -1
		assert_array(_codes(body, "transition_ms.%s" % row[0])).contains([ConfigRows.E_RANGE])


func test_speed_factor_instant_must_be_zero() -> void:
	var body: Dictionary = _body()
	body.speed_factor.instant = 0.1
	assert_array(_codes(body, "speed_factor.instant")).contains([ConfigRows.E_RANGE])


func test_option_gap_range() -> void:
	var body: Dictionary = _body()
	body.option_gap.bundle = 65
	body.option_gap.treasure = 23
	assert_array(_fields(body)).contains(["option_gap.bundle", "option_gap.treasure"])


func test_enum_knobs_refuse_a_value_they_do_not_have() -> void:
	var body: Dictionary = _body()
	body.preselect_hero = "random"
	body.default_focus.summary = "quit"
	assert_array(_fields(body)).contains(["preselect_hero", "default_focus.summary"])


func test_enum_knobs_take_every_listed_value() -> void:
	for value: String in ["last_played", "war", "none"]:
		var body: Dictionary = _body()
		body.preselect_hero = value
		assert_array(_codes(body, "preselect_hero")).is_empty()
	for value: String in ["new_run_same_hero", "hero_select", "none"]:
		var body: Dictionary = _body()
		body.default_focus.summary = value
		assert_array(_codes(body, "default_focus.summary")).is_empty()


func test_an_unknown_key_and_a_missing_key_both_report() -> void:
	var body: Dictionary = _body()
	body["toast_colour"] = "red"
	body.erase("node_d")
	var rows: Array = RunUiConfig.validate_config(body, null)
	var codes: Array = rows.map(func(row: Dictionary) -> StringName: return row.code)
	assert_array(codes).contains([ValidationReport.E_UNKNOWN_FIELD, ValidationReport.E_MISSING_FIELD])


func test_font_px_must_be_an_object() -> void:
	var body: Dictionary = _body()
	body.font_px = 16
	assert_array(_fields(body)).contains(["font_px"])


func test_font_px_reports_each_missing_role() -> void:
	for role: String in ROLES:
		var body: Dictionary = _body()
		body.font_px.erase(role)
		assert_array(_fields(body)).contains(["font_px.%s" % role])


func test_font_px_refuses_zero_negative_fractional_and_text_sizes() -> void:
	for bad: Variant in [0, -4, 13.5, "13"]:
		var body: Dictionary = _body()
		body.font_px.small = bad
		assert_array(_fields(body)).override_failure_message("small=%s taken" % str(bad)).contains(["font_px.small"])


func test_font_px_holds_the_twelve_pixel_minimum() -> void:
	var body: Dictionary = _body()
	body.font_px.small = FONT_FLOOR_PX
	assert_array(_codes(body, "font_px.small")).is_empty()
	body.font_px.small = FONT_FLOOR_PX - 1
	assert_array(_codes(body, "font_px.small")).is_not_empty()


func test_palette_needs_every_token_a_screen_or_read_model_names() -> void:
	var tokens: Array = RunUiConfig.TOKENS_REQUIRED
	for token: String in tokens:
		var body: Dictionary = _body()
		body.palette.erase(token)
		assert_array(_fields(body)).override_failure_message("palette without %s passes" % token).contains(["palette.%s" % token])


func test_a_token_that_is_not_a_colour_reports() -> void:
	var body: Dictionary = _body()
	body.palette.bg_edge = "not-a-colour"
	assert_array(_fields(body)).contains(["palette.bg_edge"])


func test_a_bad_high_contrast_colour_reports() -> void:
	var body: Dictionary = _body()
	body.palette_high_contrast.state_danger = "not-a-colour"
	assert_array(_fields(body)).contains(["palette_high_contrast.state_danger"])


func test_every_body_a_screen_reads_without_a_default_is_checked() -> void:
	# A screen indexes these directly (`cfg.option_w.bundle`), so a hole is a crash on a
	# player's screen unless the load refuses it.
	var holes: Array = [
		["option_w", "treasure"], ["option_w", "bundle"], ["option_y", "treasure"], ["option_y", "bundle"],
		["settings_steps", "volume"], ["settings_steps", "action_delay"], ["settings_steps", "action_delay_min"],
		["settings_steps", "action_delay_max"], ["settings_steps", "gamma"], ["settings_steps", "gamma_min"],
		["settings_steps", "gamma_max"], ["reading_panel", "font_px"], ["reading_panel", "max_w"],
	]
	for hole: Array in holes:
		var body: Dictionary = _body()
		(body[hole[0]] as Dictionary).erase(hole[1])
		var field: String = "%s.%s" % [hole[0], hole[1]]
		assert_array(_fields(body)).override_failure_message("%s missing passes" % field).contains([field])


func test_controls_and_glossary_and_sfx_must_be_objects() -> void:
	for key: String in ["controls", "glossary", "sfx"]:
		var body: Dictionary = _body()
		body[key] = "none"
		assert_array(_fields(body)).override_failure_message("%s not an object passes" % key).contains([key])


func test_strings_must_be_an_object() -> void:
	var body: Dictionary = _body()
	body.strings = []
	assert_array(_fields(body)).contains(["strings"])
