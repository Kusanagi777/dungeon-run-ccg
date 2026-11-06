## Phase P to T through the real view (targeting.md §5.3, §6, §10; story 017): the parked card,
## the held gap, the ghost, the arrow and the "No target" chip. `input_router_test` proves the
## session; this proves what the view draws from it. No shipped hand reaches a Battlecry with
## an optional target at a known gap, so a controller scripts `legal_commands()` over a real
## driver.
extends GdUnitTestSuite

const ROW_POINT := Vector2(640, 400)
const GHOST_ALPHA: float = 0.6
const FRAME_S: float = 1.0 / 60.0


## Answers a scripted list and hands everything else to the real driver.
class ScriptedLegal:
	extends MatchController

	var scripted: Array = []

	func _init(driver: MatchDriver) -> void:
		super(driver)

	func legal_commands() -> Array:
		return scripted


func _open(entries: Callable) -> MatchView:
	var boot: Node = MatchViewHarness.fresh_boot({"anim_speed": "instant"})
	var loader := MatchDebugLoader.new(MatchViewHarness.immediate_planner(), boot)
	var live: MatchController = loader.load_fixture("targeting_taunt")
	var controller := ScriptedLegal.new(live.get("_driver"))
	var view: MatchView = await MatchViewHarness.open_controller(self, boot, controller, loader.match_info)
	await MatchViewHarness.frames(view, 2)
	controller.scripted = entries.call(view)
	MatchViewHarness.run(view, FRAME_S)
	return view


func _battlecry(view: MatchView) -> Array:
	var target: int = int(view.view_state().side(&"boss").board[2].entity_id)
	var play: Callable = func(position: int, target_id: Variant) -> Dictionary:
		return {"type": MatchRecords.CMD_PLAY_CARD, "issuer": "player", "hand_index": 0, "position": position, "target_id": target_id}
	var out: Array = []
	for gap: int in 6:
		out.append(play.call(gap, target))
		out.append(play.call(gap, null))
	return out


func _hand_point(view: MatchView) -> Vector2:
	return MatchViewHarness.card_point(view, MatchViewHarness.hand_id(view, 0))


func test_a_gap_chosen_parks_the_card_and_holds_a_ghost_at_60_percent() -> void:
	# Arrange
	var view: MatchView = await _open(_battlecry)
	var row: BoardPresenter = view.find_child("PlayerRow", true, false)
	var id: int = MatchViewHarness.hand_id(view, 0)

	# Act
	MatchViewHarness.drag(view, _hand_point(view), ROW_POINT)
	await MatchViewHarness.frames(view, 2)

	# Assert
	assert_str(String(view.router().session().phase)).is_equal(String(InputRouter.SESSION_TARGET))
	assert_bool(view.hand().get("_parked")).is_true()
	assert_int(int(view.hand().get("_dragged"))).is_equal(id)
	var gap: Control = row.get("_gap")
	assert_object(gap).is_not_null()
	assert_int(gap.get_child_count()).is_equal(1)
	assert_float((gap.get_child(0) as Control).modulate.a).is_equal_approx(GHOST_ALPHA, 0.001)
	view.router().intent(InputRouter.INTENT_CANCEL)
	MatchViewHarness.close(view)


func test_the_arrow_starts_at_the_ghost_and_the_chip_stands_above_it() -> void:
	# Arrange
	var view: MatchView = await _open(_battlecry)
	var arrow: TargetingArrow = view.find_child("TargetingArrow", true, false)

	# Act
	MatchViewHarness.drag(view, _hand_point(view), ROW_POINT)

	# Assert
	var session: Dictionary = view.router().session()
	var ghost: Rect2 = session.ghost_rect
	var chip: Rect2 = session.chip_rect
	assert_bool(arrow.is_active()).is_true()
	assert_object(arrow.ends()[0]).is_equal(ghost.get_center())
	assert_float(chip.get_center().x).is_equal(ghost.get_center().x)
	assert_float(chip.end.y).is_less(ghost.position.y)
	assert_object(arrow.get("_chip")).is_equal(chip)
	view.router().intent(InputRouter.INTENT_CANCEL)
	MatchViewHarness.close(view)


func test_a_click_on_the_chip_sends_the_gap_with_no_target() -> void:
	# Arrange
	var view: MatchView = await _open(_battlecry)
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
	MatchViewHarness.drag(view, _hand_point(view), ROW_POINT)
	var gap: int = int(view.router().session().position)

	# Act
	MatchViewHarness.click(view, (view.router().session().chip_rect as Rect2).get_center())

	# Assert
	assert_int(sent.size()).is_equal(1)
	assert_int(int(sent[0].position)).is_equal(gap)
	assert_that(sent[0].target_id).is_null()
	MatchViewHarness.close(view)


func test_a_click_on_the_ghost_is_ignored() -> void:
	# Arrange
	var view: MatchView = await _open(_battlecry)
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
	MatchViewHarness.drag(view, _hand_point(view), ROW_POINT)

	# Act: §7.4 rank 2
	MatchViewHarness.click(view, (view.router().session().ghost_rect as Rect2).get_center())

	# Assert
	assert_array(sent).is_empty()
	assert_bool(view.router().in_session()).is_true()
	view.router().intent(InputRouter.INTENT_CANCEL)
	MatchViewHarness.close(view)


func test_a_cancel_from_phase_t_closes_the_gap_and_frees_the_ghost() -> void:
	# Arrange
	var view: MatchView = await _open(_battlecry)
	var row: BoardPresenter = view.find_child("PlayerRow", true, false)
	var arrow: TargetingArrow = view.find_child("TargetingArrow", true, false)
	MatchViewHarness.drag(view, _hand_point(view), ROW_POINT)

	# Act
	MatchViewHarness.action(view, &"ui_cancel")
	await MatchViewHarness.frames(view, 2)

	# Assert
	assert_object(row.get("_gap")).is_null()
	assert_bool(arrow.is_active()).is_false()
	assert_object(arrow.get("_chip")).is_equal(Rect2())
	assert_int(int(view.hand().get("_dragged"))).is_equal(-1)
	MatchViewHarness.close(view)


func test_a_pad_dropping_out_cancels_a_key_session_and_leaves_a_held_drag() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray")
	MatchViewHarness.run(view, FRAME_S)
	view.router().on_action(MatchInput.HERO_POWER)

	# Act
	view.call("_on_joy_connection_changed", 0, false)
	var after_key: bool = view.router().in_session()
	view.router().intent(InputRouter.INTENT_DRAG_START, {"source": {"kind": InputRouter.SOURCE_HERO_POWER, "id": -1}, "pos": Vector2(176, 414)})
	view.call("_on_joy_connection_changed", 0, false)

	# Assert: targeting.md §15; the mouse still holds the drag
	assert_bool(after_key).is_false()
	assert_bool(view.router().dragging()).is_true()
	view.router().intent(InputRouter.INTENT_CANCEL)
	MatchViewHarness.close(view)
