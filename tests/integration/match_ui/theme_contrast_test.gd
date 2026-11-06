## The automated half of story 020 AC-2 (hud.md §10.1, §12; art bible §4): the palette's text
## and background pairs hold WCAG contrast with `high_contrast_states` on and off, and the
## mode swaps only its listed tokens. Coblis runs stay manual.
extends GdUnitTestSuite

const BODY_RATIO: float = 4.5
const LARGE_RATIO: float = 3.0
## `[text, background]`, as the presenters draw them.
const BODY_PAIRS: Array[Array] = [
	["text_light", "bg_edge"], ["text_light", "table_dark"], ["text_light", "table_lit"], ["text_light", "ink"],
	["text_muted", "table_dark"], ["text_muted", "bg_edge"], ["text_ink", "parchment"],
]
## State numerals and labels on the stamp and the plate: `state_danger` is a 14 px stamp
## numeral on `ink` and the `lethal` label.
const STATE_PAIRS: Array[Array] = [["state_danger", "ink"], ["state_buff", "ink"], ["state_target", "ink"], ["state_freeze", "ink"]]
const SWAPPED: Array[String] = ["state_danger", "state_buff"]
const STEADY: Array[String] = ["state_target", "state_freeze", "state_actionable", "text_light", "ink"]


func _linear(channel: float) -> float:
	return channel / 12.92 if channel <= 0.03928 else pow((channel + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _linear(color.r) + 0.7152 * _linear(color.g) + 0.0722 * _linear(color.b)


func _ratio(a: Color, b: Color) -> float:
	var hi: float = maxf(_luminance(a), _luminance(b))
	var lo: float = minf(_luminance(a), _luminance(b))
	return (hi + 0.05) / (lo + 0.05)


func _context(high_contrast: bool) -> MatchUiContext:
	var ui := MatchUiContext.new(MatchUiTestConfig.shipped())
	ui.set_high_contrast(high_contrast)
	return ui


func test_the_ratio_is_the_wcag_one() -> void:
	# Act / Assert: black on white is the top of the scale, a colour on itself the bottom
	assert_float(_ratio(Color.BLACK, Color.WHITE)).is_equal_approx(21.0, 0.01)
	assert_float(_ratio(Color.RED, Color.RED)).is_equal_approx(1.0, 0.001)


func test_every_text_pair_reaches_4_5_to_1_in_both_modes() -> void:
	for high_contrast: bool in [false, true]:
		# Arrange
		var ui: MatchUiContext = _context(high_contrast)

		# Act / Assert
		for pair: Array in BODY_PAIRS:
			var ratio: float = _ratio(ui.color(pair[0]), ui.color(pair[1]))
			assert_float(ratio).override_failure_message("%s on %s is %.2f" % [pair[0], pair[1], ratio]).is_greater_equal(BODY_RATIO)


func test_every_state_colour_reads_on_ink_in_both_modes() -> void:
	for high_contrast: bool in [false, true]:
		# Arrange
		var ui: MatchUiContext = _context(high_contrast)

		# Act / Assert
		for pair: Array in STATE_PAIRS:
			var ratio: float = _ratio(ui.color(pair[0]), ui.color(pair[1]))
			assert_float(ratio).override_failure_message("%s on %s is %.2f" % [pair[0], pair[1], ratio]).is_greater_equal(BODY_RATIO)


func test_large_type_clears_3_to_1_on_the_table() -> void:
	# Arrange
	var ui: MatchUiContext = _context(false)

	# Act / Assert: the 24 px health stamp, red when hurt, sits on `ink`; the banner on the table
	assert_float(_ratio(ui.color("state_target"), ui.color("table_lit"))).is_greater_equal(LARGE_RATIO)


func test_high_contrast_swaps_the_two_listed_tokens_only() -> void:
	# Arrange
	var off: MatchUiContext = _context(false)
	var on: MatchUiContext = _context(true)
	var swaps: Dictionary = MatchUiTestConfig.shipped().palette_high_contrast

	# Act / Assert
	assert_array(swaps.keys()).contains_exactly_in_any_order(SWAPPED)
	for token: String in SWAPPED:
		assert_object(on.color(token)).is_equal(Color.html(str(swaps[token])))
		assert_object(on.color(token)).is_not_equal(off.color(token))
	for token: String in STEADY:
		assert_object(on.color(token)).is_equal(off.color(token))


func test_high_contrast_off_restores_the_palette() -> void:
	# Arrange
	var ui: MatchUiContext = _context(true)

	# Act
	ui.set_high_contrast(false)

	# Assert
	assert_object(ui.color("state_danger")).is_equal(Color.html(str(MatchUiTestConfig.shipped().palette.state_danger)))


func test_the_setting_repaints_a_hurt_token_and_the_fatigue_label_on_the_table() -> void:
	# Arrange: a hurt token holds `state_danger` in a colour override, set when it was shown
	var view: MatchView = await MatchViewHarness.open(self, "midgame_full_board")
	var hurt: Dictionary = {}
	for token: Dictionary in view.view_state().side(&"boss").board:
		if int(token.health) < int(token.max_health):
			hurt = token
	var row: BoardPresenter = view.find_child("BossRow", true, false)
	var health: Label = row.token(int(hurt.entity_id)).get("_health")
	var panel: HeroPresenter = view.find_child("PlayerPanel", true, false)
	var swap: Color = Color.html(str(view.ui_context().config.palette_high_contrast.state_danger))

	# Act
	assert_int(MatchViewHarness.meta(view).set_setting(&"high_contrast_states", true)).is_equal(OK)

	# Assert
	assert_object(health.get_theme_color(&"font_color")).is_equal(swap)
	assert_object((panel.get("_fatigue") as Label).get_theme_color(&"font_color")).is_equal(swap)
	MatchViewHarness.close(view)


func test_the_flash_outline_and_the_reject_ring_take_the_swap() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var swap: Color = Color.html(str(view.ui_context().config.palette_high_contrast.state_danger))
	var panel: HeroPresenter = view.find_child("PlayerPanel", true, false)
	var reject: RejectPresenter = view.get("_reject")

	# Act
	MatchViewHarness.meta(view).set_setting(&"high_contrast_states", true)

	# Assert
	var flash: StyleBoxFlat = (panel.get("_mana_flash") as Panel).get_theme_stylebox("panel")
	var ring: StyleBoxFlat = (reject.get("_outline") as Panel).get_theme_stylebox("panel")
	assert_object(flash.border_color).is_equal(swap)
	assert_object(ring.border_color).is_equal(swap)
	MatchViewHarness.close(view)
