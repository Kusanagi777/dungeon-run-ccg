## F1 and F2 as pure functions (match-ui L10, L14, O1, O2; story 006 AC-1). Numbers are the
## GDD's own worked values at the shipped knobs; an injected config proves none is
## hardcoded in the layout.
extends GdUnitTestSuite

const MAX_HAND: int = 10
const SMALL_HAND: int = 3
const SPACING_MAX_HAND: float = 72.2
const SPACING_SMALL_HAND: float = 158.0
const END_ROT_MAX_HAND: float = 15.0
const END_ROT_SMALL_HAND: float = 4.0
const CENTRE_Y_MAX_HAND: float = 672.3
const CENTRE_Y_SMALL_HAND: float = 672.0
const CARD_CENTRE_MIN_X: float = 315.0
const CARD_CENTRE_MAX_X: float = 965.0
## The O1 edges: no card pixel left of 188 or right of 1092 once rotated.
const FAN_LEFT_PX: float = 188.0
const FAN_RIGHT_PX: float = 1092.0
const NARROW_HAND_W: int = 700
const TOLERANCE: float = 0.05


func _cfg() -> Dictionary:
	return MatchUiTestConfig.shipped().hand


func test_l10_ten_cards_space_at_72_2_with_ends_at_15_degrees() -> void:
	# Arrange / Act
	var slots: Array[Dictionary] = HandLayout.fan(MAX_HAND, _cfg())

	# Assert
	assert_int(slots.size()).is_equal(MAX_HAND)
	assert_float(HandLayout.spacing(MAX_HAND, _cfg())).is_equal_approx(SPACING_MAX_HAND, TOLERANCE)
	assert_float(float(slots[0].rot)).is_equal_approx(-END_ROT_MAX_HAND, TOLERANCE)
	assert_float(float(slots[MAX_HAND - 1].rot)).is_equal_approx(END_ROT_MAX_HAND, TOLERANCE)
	assert_float(float(slots[4].y)).is_equal_approx(CENTRE_Y_MAX_HAND, TOLERANCE)


func test_l14_three_cards_space_at_158_with_ends_at_4_degrees() -> void:
	# Arrange / Act
	var slots: Array[Dictionary] = HandLayout.fan(SMALL_HAND, _cfg())

	# Assert
	assert_float(HandLayout.spacing(SMALL_HAND, _cfg())).is_equal_approx(SPACING_SMALL_HAND, TOLERANCE)
	assert_float(float(slots[0].rot)).is_equal_approx(-END_ROT_SMALL_HAND, TOLERANCE)
	assert_float(float(slots[2].rot)).is_equal_approx(END_ROT_SMALL_HAND, TOLERANCE)
	assert_float(float(slots[1].y)).is_equal_approx(CENTRE_Y_SMALL_HAND, TOLERANCE)


func test_no_card_centre_leaves_the_band_at_any_hand_size() -> void:
	for n: int in range(1, MAX_HAND + 1):
		# Act
		for slot: Dictionary in HandLayout.fan(n, _cfg()):
			# Assert
			assert_float(float(slot.x)).override_failure_message("n=%d x=%f" % [n, slot.x]).is_between(CARD_CENTRE_MIN_X - TOLERANCE, CARD_CENTRE_MAX_X + TOLERANCE)


func test_o1_a_full_fan_keeps_every_rotated_corner_inside_its_edges() -> void:
	# Arrange
	var cfg: Dictionary = _cfg()
	var half_w: float = float(cfg.card_w) / 2.0

	# Act / Assert
	for slot: Dictionary in HandLayout.fan(MAX_HAND, cfg):
		var pivot := Vector2(float(slot.x), float(slot.y))
		for corner: Vector2 in [Vector2(-half_w, 0), Vector2(half_w, 0), Vector2(-half_w, -float(cfg.card_h)), Vector2(half_w, -float(cfg.card_h))]:
			var at: Vector2 = pivot + corner.rotated(deg_to_rad(float(slot.rot)))
			assert_float(at.x).override_failure_message("corner at %s" % str(at)).is_between(FAN_LEFT_PX, FAN_RIGHT_PX)


func test_the_centre_of_the_fan_is_its_highest_point() -> void:
	# Act
	var slots: Array[Dictionary] = HandLayout.fan(5, _cfg())

	# Assert: F1's arc peaks mid-fan and the ends sit on the baseline
	assert_float(float(slots[2].y)).is_equal_approx(float(_cfg().hand_base_y) - float(_cfg().arc_h), TOLERANCE)
	assert_float(float(slots[0].y)).is_equal_approx(float(_cfg().hand_base_y), TOLERANCE)
	assert_float(float(slots[4].y)).is_equal_approx(float(_cfg().hand_base_y), TOLERANCE)


func test_a_single_card_is_centred_and_upright() -> void:
	# Act
	var slot: Dictionary = HandLayout.fan(1, _cfg())[0]

	# Assert
	assert_float(float(slot.x)).is_equal(float(_cfg().hand_cx))
	assert_float(float(slot.rot)).is_equal(0.0)


func test_an_injected_hand_w_changes_the_output() -> void:
	# Arrange
	var cfg: Dictionary = _cfg()
	cfg.hand_w = NARROW_HAND_W

	# Act
	var spacing: float = HandLayout.spacing(MAX_HAND, cfg)

	# Assert: (700 - 150) / 9
	assert_float(spacing).is_equal_approx((NARROW_HAND_W - float(cfg.card_w)) / (MAX_HAND - 1), TOLERANCE)
	assert_float(float(HandLayout.fan(MAX_HAND, cfg)[0].x)).is_equal_approx(float(cfg.hand_cx) - 4.5 * spacing, TOLERANCE)


func test_f2_the_hover_is_upright_at_1_5x_on_the_baseline() -> void:
	# Act
	var hover: Dictionary = HandLayout.hover(640.0, _cfg())

	# Assert
	assert_float(float(hover.scale)).is_equal(1.5)
	assert_float(float(hover.rot)).is_equal(0.0)
	assert_float(float(hover.y)).is_equal(float(_cfg().hand_base_y))


func test_f2_a_preview_past_either_edge_clamps_inside_the_viewport() -> void:
	# Arrange
	var cfg: Dictionary = _cfg()
	var half: float = float(cfg.hover_scale) * float(cfg.card_w) / 2.0

	# Act / Assert
	assert_float(float(HandLayout.hover(0.0, cfg).x)).is_equal(half)
	assert_float(float(HandLayout.hover(float(cfg.viewport_w), cfg).x)).is_equal(float(cfg.viewport_w) - half)


func test_a_parked_card_stands_upright_with_its_top_at_y_438() -> void:
	# Arrange
	var cfg: Dictionary = _cfg()

	# Act: targeting.md §5.2
	var parked: Dictionary = HandLayout.parked(400.0, cfg)

	# Assert
	assert_float(float(parked.y) - float(cfg.card_h)).is_equal(438.0)
	assert_float(float(parked.rot)).is_equal(0.0)
	assert_float(float(parked.scale)).is_equal(1.0)
	assert_float(float(parked.x)).is_equal(400.0)


func test_contains_follows_the_rotation_of_the_card() -> void:
	# Arrange: a card tilted 15 degrees right, pivot at its bottom centre
	var cfg: Dictionary = _cfg()
	var slot: Dictionary = {"x": 640.0, "y": 696.0, "rot": 15.0}
	var inside_tip: Vector2 = Vector2(640, 696) + Vector2(0, -200).rotated(deg_to_rad(15.0))
	var unrotated_corner := Vector2(640 - 74, 696 - 208)

	# Act / Assert
	assert_bool(HandLayout.contains(inside_tip, slot, cfg)).is_true()
	assert_bool(HandLayout.contains(unrotated_corner, slot, cfg)).is_false()
