## The hand's hover preview (match-ui O2, F2; story 006 AC-3, AC-4). Tweens are stepped by
## hand, so the 100 ms claim does not hang on the machine. What the real viewport's mouse
## delivery adds to that latency stays for the owner's playtest (MUI-024).
extends GdUnitTestSuite

const CARD_9_INDEX: int = 8
const PREVIEW_W: float = 225.0
const PREVIEW_H: float = 315.0
const BASELINE_Y: float = 696.0
const MANA_BAR_X: float = 1060.0
const HOVER_S: float = 0.1
const EPSILON: float = 0.001


func _open() -> MatchView:
	var view: MatchView = await MatchViewHarness.open(self, "hand_10")
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	return view


func _positions(view: MatchView, except: int) -> Dictionary:
	var out: Dictionary = {}
	for id: int in view.hand().get("_order"):
		if id != except:
			out[id] = view.hand().card(id).position
	return out


func test_a_mouse_over_completes_the_1_5x_preview_within_hover_in_s() -> void:
	# Arrange
	var view: MatchView = await _open()
	var id: int = MatchViewHarness.hand_id(view, 4)
	assert_float(float(view.ui_context().config.hand.hover_in_s)).is_equal(HOVER_S)

	# Act
	MatchViewHarness.send(view, MatchViewHarness.motion(MatchViewHarness.card_point(view, id)))
	var tween: Tween = view.hand().get("_hover_tween")
	tween.custom_step(HOVER_S)

	# Assert
	assert_float(view.hand().card(id).scale.x).is_equal_approx(1.5, EPSILON)
	assert_float(view.hand().card(id).rotation_degrees).is_equal_approx(0.0, EPSILON)
	MatchViewHarness.close(view)


func test_the_preview_is_still_growing_halfway_through() -> void:
	# Arrange
	var view: MatchView = await _open()
	var id: int = MatchViewHarness.hand_id(view, 4)

	# Act
	MatchViewHarness.send(view, MatchViewHarness.motion(MatchViewHarness.card_point(view, id)))
	(view.hand().get("_hover_tween") as Tween).custom_step(HOVER_S / 2.0)

	# Assert: it is a tween, not a snap
	assert_float(view.hand().card(id).scale.x).is_between(1.0 + EPSILON, 1.5 - EPSILON)
	MatchViewHarness.close(view)


func test_mouse_out_restores_the_card_and_no_neighbour_ever_moves() -> void:
	# Arrange
	var view: MatchView = await _open()
	var id: int = MatchViewHarness.hand_id(view, 4)
	var rest: Vector2 = view.hand().card(id).position
	var neighbours: Dictionary = _positions(view, id)

	# Act
	MatchViewHarness.send(view, MatchViewHarness.motion(MatchViewHarness.card_point(view, id)))
	(view.hand().get("_hover_tween") as Tween).custom_step(HOVER_S)
	var during: Dictionary = _positions(view, id)
	MatchViewHarness.send(view, MatchViewHarness.motion(Vector2(640, 120)))

	# Assert
	assert_dict(during).is_equal(neighbours)
	assert_dict(_positions(view, id)).is_equal(neighbours)
	assert_object(view.hand().card(id).position).is_equal(rest)
	assert_float(view.hand().card(id).scale.x).is_equal(1.0)
	MatchViewHarness.close(view)


func test_o2_the_pose_stands_card_9_upright_on_the_baseline_clear_of_the_mana_bar() -> void:
	# Arrange
	var probe: MatchView = await _open()
	var id: int = MatchViewHarness.hand_id(probe, CARD_9_INDEX)
	MatchViewHarness.close(probe)

	# Act
	var view: MatchView = await MatchViewHarness.open(self, "hand_10", ["--pose=hover:%d" % id])
	var card: CardFrame = view.hand().card(id)
	var rect: Rect2 = view.hand().preview_rect(id)

	# Assert
	assert_float(rect.size.x).is_equal(PREVIEW_W)
	assert_float(rect.size.y).is_equal(PREVIEW_H)
	assert_float(rect.end.y).is_equal(BASELINE_Y)
	assert_float(card.rotation_degrees).is_equal(0.0)
	assert_float(card.scale.x).is_equal(1.5)
	assert_int(card.z_index).is_greater(view.hand().card(MatchViewHarness.hand_id(view, 9)).z_index)
	assert_float(rect.end.x).is_less_equal(MANA_BAR_X)
	assert_float(rect.position.x).is_greater_equal(0.0)
	MatchViewHarness.close(view)


func test_a_card_hit_tests_at_its_preview_while_hovered() -> void:
	# Arrange
	var view: MatchView = await _open()
	var id: int = MatchViewHarness.hand_id(view, 4)
	view.hand().set_hover(id, 0.0)
	var above_the_fan: Vector2 = view.hand().preview_rect(id).get_center() - Vector2(0, 100)

	# Act / Assert: the preview stands taller than the card at rest
	assert_int(view.hand().card_at(above_the_fan)).is_equal(id)
	MatchViewHarness.close(view)


func test_hover_outside_idle_opens_no_preview() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "mulligan")
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

	# Act
	view.call("_update_hover", Vector2(640, 600))

	# Assert
	assert_int(int(view.hand().get("_hovered"))).is_equal(-1)
	MatchViewHarness.close(view)


func test_a_pickup_is_immediate_with_no_tween_in() -> void:
	# Arrange
	var view: MatchView = await _open()
	var id: int = MatchViewHarness.hand_id(view, 4)
	view.hand().set_hover(id)

	# Act
	view.hand().begin_drag(id, false)
	view.hand().follow(Vector2(640, 300))

	# Assert: scale and rotation are settled on this frame
	assert_float(view.hand().card(id).scale.x).is_equal(1.0)
	assert_float(view.hand().card(id).rotation_degrees).is_equal(0.0)
	assert_object(view.hand().get("_hover_tween")).is_null()
	MatchViewHarness.close(view)
