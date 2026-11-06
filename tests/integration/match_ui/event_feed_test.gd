## The event feed on the table (match-ui U10, O11, O14; story 014 AC-2 to AC-4): the ticker,
## the drawer, and a feed that never runs ahead of the display.
extends GdUnitTestSuite

const DRAWER := Rect2(0, 40, 300, 290)
const PLAYER_PORTRAIT := Rect2(24, 334, 120, 160)
const FRAME_S: float = 1.0 / 60.0
const CAUSE: int = 777


func _ticker(view: MatchView) -> RichTextLabel:
	return view.feed().get("_ticker")


func _drawer_text(view: MatchView) -> RichTextLabel:
	return view.feed().get("_drawer_text")


func test_o14_the_drawer_takes_its_rect_clear_of_the_portrait() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "simultaneous_deaths", ["--pose=feed:open"])
	var drawer: Control = view.feed().get("_drawer")

	# Assert
	assert_bool(view.feed().is_open()).is_true()
	assert_object(drawer.get_global_rect()).is_equal(DRAWER)
	assert_bool(drawer.get_global_rect().intersects(PLAYER_PORTRAIT)).is_false()
	assert_bool(_ticker(view).visible).is_false()
	MatchViewHarness.close(view)


func test_o14_deaths_indent_under_their_root_and_a_long_chain_collapses() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "simultaneous_deaths", ["--pose=feed:open"])
	var text: String = _drawer_text(view).text
	var quiet: Dictionary = view.feed().get("_quiet")
	var rows: Array[Dictionary] = FeedLines.rows(FeedLines.shown(view.view_state().feed_lines, quiet), int(view.ui_context().config.feed_group_collapse), {})
	var more: int = 0
	for row: Dictionary in rows:
		if row.kind == FeedLines.ROW_MORE:
			more += 1

	# Assert
	assert_str(text).contains("[indent]")
	assert_int(more).override_failure_message("no chain past the collapse limit").is_greater(0)
	assert_int(text.count("[url=")).is_equal(more)
	MatchViewHarness.close(view)


func test_a_click_on_more_expands_its_group_and_a_second_folds_it() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "simultaneous_deaths", ["--pose=feed:open"])
	var folded: String = _drawer_text(view).text
	var start: int = folded.find("[url=") + 5
	var group: String = folded.substr(start, folded.find("]", start) - start)

	# Act
	view.feed().call("_on_meta_clicked", group)
	var open: String = _drawer_text(view).text
	view.feed().call("_on_meta_clicked", group)

	# Assert
	assert_int(open.length()).is_greater(folded.length())
	assert_str(_drawer_text(view).text).is_equal(folded)
	MatchViewHarness.close(view)


func test_o11_the_pile_reads_the_next_fatigue_at_zero_cards() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "fatigue_and_burn")
	var panel: HeroPresenter = view.find_child("PlayerPanel", true, false)
	var data: Dictionary = view.view_state().side(&"player")

	# Assert
	assert_int(int(data.deck_count)).is_equal(0)
	assert_bool((panel.get("_fatigue") as Label).visible).is_true()
	assert_str((panel.get("_fatigue") as Label).text).is_equal(tr("hud.fatigue_next") % int(data.fatigue_next))
	MatchViewHarness.close(view)


func test_o11_the_burned_card_is_named_through_card_text() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "fatigue_and_burn")
	var burned: Dictionary = {}
	for line: Dictionary in view.view_state().feed_lines:
		if str(line.key) == "feed.card_burned":
			burned = line
	var names: FeedNames = view.feed().get("_names")

	# Assert
	assert_dict(burned).is_not_empty()
	var name: String = tr(view.ui_context().card_face(str(burned.params.card_id)).name_key)
	assert_str(FeedLines.text(burned, names)).contains(name)
	MatchViewHarness.close(view)


func test_the_ticker_shows_the_newest_three_readable_lines() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")

	# Assert
	assert_int(_ticker(view).text.split("\n").size()).is_equal(int(view.ui_context().config.feed_ticker_lines))
	MatchViewHarness.close(view)


func test_a_quiet_type_keeps_its_line_and_stays_off_the_ticker() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var ticker_before: String = _ticker(view).text
	var total_before: int = view.view_state().feed_total

	# Act
	MatchViewHarness.inject(view, "mana_spent", {"side": "player", "amount": 1, "remaining": 0})
	view.call("_present", view.call("_display"))

	# Assert
	assert_int(view.view_state().feed_total).is_equal(total_before + 1)
	assert_str(_ticker(view).text).is_equal(ticker_before)
	MatchViewHarness.close(view)


func test_the_feed_never_tells_a_fate_ahead_of_the_table() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, FRAME_S)
	var id: int = int(view.view_state().side(&"player").board[0].entity_id)
	var ticker_before: String = _ticker(view).text

	# Act: the view-state knows at once; the death has not played
	MatchViewHarness.inject(view, "minion_died", {"entity_id": id, "side": "player", "card_id": "neutral_torch_imp"}, CAUSE)
	var while_queued: String = _ticker(view).text
	MatchViewHarness.settle(view)

	# Assert
	assert_str(while_queued).is_equal(ticker_before)
	assert_str(_ticker(view).text).is_not_equal(ticker_before)
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	MatchViewHarness.close(view)


func test_rmb_on_the_drawer_closes_it() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	view.feed().open()

	# Act
	view.feed().call("_on_drawer_input", MatchViewHarness.mouse_button(Vector2(100, 100), MOUSE_BUTTON_RIGHT, true, false))

	# Assert
	assert_bool(view.feed().is_open()).is_false()
	assert_bool(_ticker(view).visible).is_true()
	MatchViewHarness.close(view)


func test_the_top_bar_button_toggles_the_drawer() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var toggle: Button = view.feed().get("_toggle")

	# Act
	toggle.pressed.emit()
	var opened: bool = view.feed().is_open()
	toggle.pressed.emit()

	# Assert
	assert_bool(opened).is_true()
	assert_bool(view.feed().is_open()).is_false()
	MatchViewHarness.close(view)


func test_bbcode_in_a_name_cannot_write_markup_into_the_feed() -> void:
	# Act
	var escaped: String = FeedPresenter._escaped("[url=1]x")

	# Assert
	assert_str(escaped).is_equal("[lb]url=1]x")
