## `MatchUiConfig.validate_config`, the stage-7a check of `config("match_ui")` (match-ui
## Tuning Knobs; ADR-0002 Decision 4), and [MatchUiTestConfig] kept honest against the
## shipped body it stands in for.
extends GdUnitTestSuite

## One value past each edge of each safe range, by path.
const OUT_OF_RANGE: Dictionary = {
	"click_drag_px": [3, 13],
	"end_turn_arm_ms": [149, 601],
	"match_end_auto_s": [1, 9],
	"min_action_gap_s": [0.09, 0.31],
	"k_min": [0.24, 0.51],
	"coalesce_threshold": [3, 15],
	"feed_group_collapse": [3, 11],
	"feed_ticker_lines": [1, 5],
	"hand.hand_w": [699, 801],
	"hand.hover_in_s": [0.04, 0.21],
	"targeting.arrow_lift_px": [19, 101],
}


func _set_at(body: Dictionary, path: String, value: Variant) -> void:
	var parts: PackedStringArray = path.split(".")
	var at: Dictionary = body
	for i: int in parts.size() - 1:
		at = at[parts[i]]
	at[parts[parts.size() - 1]] = value


func _fields(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in rows:
		out.append(str(row.field))
	return out


func test_the_shipped_body_passes() -> void:
	# Act / Assert
	assert_array(MatchUiConfig.validate_config(MatchUiTestConfig.shipped(), null)).is_empty()


func test_a_value_past_either_edge_of_its_safe_range_is_e_range() -> void:
	for path: String in OUT_OF_RANGE:
		for value: Variant in OUT_OF_RANGE[path]:
			# Arrange
			var body: Dictionary = MatchUiTestConfig.shipped()
			_set_at(body, path, value)

			# Act
			var rows: Array = MatchUiConfig.validate_config(body, null)

			# Assert
			assert_int(rows.size()).override_failure_message("%s = %s" % [path, str(value)]).is_equal(1)
			assert_str(String(rows[0].code)).is_equal(String(MatchUiConfig.E_RANGE))
			assert_str(str(rows[0].field)).is_equal(path)


func test_a_value_on_an_edge_of_its_safe_range_passes() -> void:
	for path: String in MatchUiConfig.RANGES:
		for edge: Variant in MatchUiConfig.RANGES[path]:
			# Arrange
			var body: Dictionary = MatchUiTestConfig.shipped()
			_set_at(body, path, edge)

			# Act / Assert
			assert_array(MatchUiConfig.validate_config(body, null)).override_failure_message("%s = %s" % [path, str(edge)]).is_empty()


func test_a_ranged_knob_of_the_wrong_type_is_e_range() -> void:
	# Arrange
	var body: Dictionary = MatchUiTestConfig.shipped()
	body.click_drag_px = "eight"

	# Act
	var rows: Array = MatchUiConfig.validate_config(body, null)

	# Assert
	assert_str(String(rows[0].code)).is_equal(String(MatchUiConfig.E_RANGE))


func test_a_missing_section_and_a_missing_knob_are_each_reported() -> void:
	# Arrange
	var body: Dictionary = MatchUiTestConfig.shipped()
	body.erase("palette")
	body.erase("click_drag_px")
	(body.hand as Dictionary).erase("arc_h")

	# Act
	var rows: Array = MatchUiConfig.validate_config(body, null)

	# Assert: every fault in one pass
	assert_array(_fields(rows)).contains_exactly_in_any_order(["palette", "click_drag_px", "hand.arc_h"])
	for row: Dictionary in rows:
		assert_str(String(row.code)).is_equal(String(ValidationReport.E_MISSING_FIELD))


func test_a_layout_value_that_is_no_rect_is_e_range() -> void:
	# Arrange
	var body: Dictionary = MatchUiTestConfig.shipped()
	body.layout.end_turn = [1, 2, 3]
	body.layout.top_bar = "wide"

	# Act
	var rows: Array = MatchUiConfig.validate_config(body, null)

	# Assert
	assert_array(_fields(rows)).contains_exactly_in_any_order(["layout.end_turn", "layout.top_bar"])


func test_the_validator_is_registered_with_the_composition_root() -> void:
	# Arrange
	var boot: Node = auto_free(MatchViewHarness.BOOT_SCRIPT.new())

	# Act
	var validators: Dictionary = boot.call("_collect_validators", null)

	# Assert
	assert_bool(validators.configs.has("match_ui")).is_true()


# --- MatchUiTestConfig stays the shipped body's twin ---------------------------------

func _assert_same(pinned: Dictionary, shipped: Dictionary, path: String) -> void:
	for key: String in pinned:
		var at: String = path + key
		assert_bool(shipped.has(key)).override_failure_message("the helper pins %s, which does not ship" % at).is_true()
		if pinned[key] is Dictionary and shipped.get(key) is Dictionary:
			_assert_same(pinned[key], shipped[key], at + ".")
		elif pinned[key] is int or pinned[key] is float:
			assert_float(float(shipped[key])).override_failure_message(at).is_equal(float(pinned[key]))
		elif shipped.has(key):
			assert_str(str(shipped[key])).override_failure_message(at).is_equal(str(pinned[key]))


func test_every_value_the_helper_pins_is_the_shipped_value() -> void:
	# Act / Assert
	_assert_same(MatchUiTestConfig.body(), MatchUiTestConfig.shipped(), "")


func test_the_helper_names_every_shipped_step_duration() -> void:
	# Arrange
	var pinned: Dictionary = MatchUiTestConfig.body().d_base

	# Act / Assert: a kind missing here is a pushed error from `MatchViewState._step`
	for kind: String in MatchUiTestConfig.shipped().d_base:
		assert_bool(pinned.has(kind)).override_failure_message("d_base.%s" % kind).is_true()


func test_a_presenter_body_lays_an_override_over_the_section_it_names() -> void:
	# Act
	var body: Dictionary = MatchUiTestConfig.presenter_body({"hero": {"power_press_scale": 0.5}})

	# Assert: the rest of the section stands, and the shipped sections ride along
	assert_float(float(body.hero.power_press_scale)).is_equal(0.5)
	assert_int(int(body.hero.power_lift_px)).is_equal(2)
	assert_bool(body.has("palette")).is_true()
