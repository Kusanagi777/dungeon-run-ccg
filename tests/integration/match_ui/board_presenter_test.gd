## Board rows and tokens (match-ui O3, U3; ADR-0009 Verification; story 007 AC-1, AC-2).
extends GdUnitTestSuite

const FULL_ROW: int = 7
const FIRST_X: float = 301.0
const PITCH_X: float = 98.0
const BOSS_ROW_Y: float = 176.0
const PLAYER_ROW_Y: float = 334.0
const MIN_NUMERAL_PX: int = 14
const SUMMONED_ID: int = 901
const CAUSE: int = 777


func _row(view: MatchView, name: String) -> BoardPresenter:
	return view.find_child(name, true, false)


func _kinds_played(view: MatchView) -> Array[String]:
	var kinds: Array[String] = []
	view.queue().step_started.connect(func(step: AnimStep, _d: float) -> void: kinds.append(String(step.kind)))
	return kinds


func test_o3_seven_tokens_a_side_sit_on_the_f6_grid() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "midgame_full_board")
	await MatchViewHarness.frames(view, 2)

	# Assert
	for pair: Array in [["PlayerRow", &"player", PLAYER_ROW_Y], ["BossRow", &"boss", BOSS_ROW_Y]]:
		var board: Array = view.view_state().side(pair[1]).board
		assert_int(board.size()).is_equal(FULL_ROW)
		for i: int in FULL_ROW:
			var rect: Rect2 = _row(view, pair[0]).token(int(board[i].entity_id)).get_global_rect()
			assert_float(rect.position.x).override_failure_message("%s[%d] x %f" % [pair[0], i, rect.position.x]).is_equal_approx(FIRST_X + PITCH_X * i, 1.0)
			assert_float(rect.position.y).is_equal(pair[2])
	MatchViewHarness.close(view)


func test_o3_tokens_show_their_numerals_and_keyword_glyphs() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "midgame_full_board")
	var entry: Dictionary = view.view_state().side(&"boss").board[5]
	var token: MinionToken = _row(view, "BossRow").token(int(entry.entity_id))
	var ui: MatchUiContext = view.ui_context()

	# Assert: this token has Divine Shield and Taunt
	assert_str((token.get("_attack") as Label).text).is_equal(str(int(entry.attack)))
	assert_str((token.get("_health") as Label).text).is_equal(str(int(entry.health)))
	assert_int((token.get("_attack") as Label).get_theme_font_size(&"font_size")).is_greater_equal(MIN_NUMERAL_PX)
	var glyphs: String = (token.get("_badges") as Label).text
	assert_str(glyphs).contains(ui.glyph("taunt"))
	assert_str(glyphs).contains(ui.glyph("divine_shield"))
	MatchViewHarness.close(view)


func test_every_state_a_token_can_be_in_has_a_glyph_of_its_own() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "midgame_full_board")
	var ui: MatchUiContext = view.ui_context()

	# Act
	var seen: Dictionary = {}
	for state: String in ["taunt", "divine_shield", "frozen", "stealth", "windfury", "silenced", "summoning_sick"]:
		seen[ui.glyph(state)] = state

	# Assert: the non-colour backups stay distinct
	assert_int(seen.size()).is_equal(7)
	MatchViewHarness.close(view)


func test_a_summon_at_index_2_grows_in_over_0_2_s_and_the_row_respaces() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt", [], {"anim_speed": "normal"})
	var row: BoardPresenter = _row(view, "PlayerRow")
	var durations: Dictionary = {}
	view.queue().step_started.connect(func(step: AnimStep, d: float) -> void: durations[step.kind] = d)

	# Act
	MatchViewHarness.inject(view, "minion_summoned", {"side": "player", "entity_id": SUMMONED_ID, "card_id": "neutral_torch_imp", "attack": 1, "health": 2, "keywords": [], "position": 2})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var scale_at_start: Vector2 = row.token(SUMMONED_ID).offset_transform_scale
	MatchViewHarness.settle(view)
	await MatchViewHarness.frames(view, 2)

	# Assert
	assert_float(float(durations[AnimStep.SUMMON])).is_equal_approx(0.2, 0.001)
	assert_float(scale_at_start.x).is_less(1.0)
	assert_object(row.token(SUMMONED_ID).offset_transform_scale).is_equal(Vector2.ONE)
	var order: Array = row.get("_order")
	assert_int(order[2]).is_equal(SUMMONED_ID)
	assert_float(row.token(int(order[3])).get_global_rect().position.x - row.token(SUMMONED_ID).get_global_rect().position.x).is_equal_approx(PITCH_X, 1.0)
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	MatchViewHarness.close(view)


func test_four_deaths_of_one_cause_play_one_group_then_one_gap_close() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt", [], {"anim_speed": "normal"})
	var kinds: Array[String] = _kinds_played(view)
	var ids: Array[int] = []
	for token: Dictionary in view.view_state().side(&"player").board.slice(0, 4):
		ids.append(int(token.entity_id))

	# Act
	for id: int in ids:
		MatchViewHarness.inject(view, "minion_died", {"entity_id": id, "side": "player"}, CAUSE)
	MatchViewHarness.settle(view)
	await MatchViewHarness.frames(view, 2)

	# Assert
	assert_array(kinds).is_equal([String(AnimStep.DEATH_GROUP), String(AnimStep.GAP_CLOSE)])
	var row: BoardPresenter = _row(view, "PlayerRow")
	assert_dict(row.get("_leaving")).is_empty()
	for id: int in ids:
		assert_object(row.token(id)).is_null()
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	MatchViewHarness.close(view)


func test_a_dead_token_holds_its_slot_until_the_gap_closes() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt", [], {"anim_speed": "normal"})
	var row: BoardPresenter = _row(view, "PlayerRow")
	var id: int = int(view.view_state().side(&"player").board[0].entity_id)
	var held: Array = []
	var freed: Array = []
	view.queue().step_started.connect(func(step: AnimStep, _d: float) -> void:
		if step.kind == AnimStep.GAP_CLOSE:
			held.append((row.get("_leaving") as Dictionary).has(id)))
	view.queue().step_finished.connect(func(step: AnimStep) -> void:
		if step.kind == AnimStep.GAP_CLOSE:
			freed.append((row.get("_leaving") as Dictionary).has(id)))

	# Act
	MatchViewHarness.inject(view, "minion_died", {"entity_id": id, "side": "player"}, CAUSE)
	MatchViewHarness.settle(view)

	# Assert
	assert_array(held).is_equal([true])
	assert_array(freed).override_failure_message("freed at the step's own final, not the drain").is_equal([false])
	assert_dict(row.get("_leaving")).is_empty()
	MatchViewHarness.close(view)


func test_a_skip_mid_death_leaves_no_freed_token() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt", [], {"anim_speed": "normal"})
	var id: int = int(view.view_state().side(&"player").board[0].entity_id)
	MatchViewHarness.inject(view, "minion_died", {"entity_id": id, "side": "player"}, CAUSE)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

	# Act
	view.queue().skip_all()

	# Assert
	assert_dict(_row(view, "PlayerRow").get("_leaving")).is_empty()
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	MatchViewHarness.close(view)


func test_gap_index_reads_the_m_plus_1_layout() -> void:
	# Arrange: a row of 2 tokens makes a 3-slot layout, 90 wide, gaps of 8
	var row := Rect2(301, 334, 678, 126)
	var left: float = row.get_center().x - (3 * 90.0 + 2 * 8.0) / 2.0

	# Act / Assert
	assert_int(BoardPresenter.gap_index(left + 1.0, 2, row, 90.0, 8.0)).is_equal(0)
	assert_int(BoardPresenter.gap_index(left + 100.0, 2, row, 90.0, 8.0)).is_equal(1)
	assert_int(BoardPresenter.gap_index(left + 200.0, 2, row, 90.0, 8.0)).is_equal(2)
	assert_int(BoardPresenter.gap_index(0.0, 2, row, 90.0, 8.0)).is_equal(0)
	assert_int(BoardPresenter.gap_index(2000.0, 2, row, 90.0, 8.0)).is_equal(2)
