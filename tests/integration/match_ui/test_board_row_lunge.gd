## A lunge survives its row re-sorting (match-ui story 007 AC-3; 4.7 `offset_transform_*`).
## A token's `position` belongs to the row's container, so an attacker moved through it
## would snap home on the next sort. `offset_transform_position` is never reset by one.
extends GdUnitTestSuite

const SUMMONED_ID: int = 902
## Real frames to reach the out-swing of a 0.35 s lunge.
const FRAME_CAP: int = 120
const NEAR_ZERO_PX: float = 0.5


func test_a_token_mid_lunge_keeps_its_offset_through_a_re_layout() -> void:
	# Arrange: the attacker in slot 0, the boss's Taunt as its target
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt", [], {"anim_speed": "normal"})
	await MatchViewHarness.frames(view, 2)
	var row: BoardPresenter = view.find_child("PlayerRow", true, false)
	var attacker: int = int(view.view_state().side(&"player").board[0].entity_id)
	var defender: int = int(view.view_state().side(&"boss").board[2].entity_id)
	var token: MinionToken = row.token(attacker)
	var slot_before: Vector2 = token.position

	# Act: the lunge starts, then a summon lands on the same row
	MatchViewHarness.inject(view, "attack_declared", {"attacker": attacker, "defender": defender})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var frames: int = 0
	while token.offset_transform_position.length() <= NEAR_ZERO_PX and frames < FRAME_CAP:
		await view.get_tree().process_frame
		frames += 1
	var before_sort: Vector2 = token.offset_transform_position
	var entry := {"entity_id": SUMMONED_ID, "card_id": "neutral_torch_imp", "attack": 1, "health": 2, "max_health": 2, "keywords": [], "frozen": false, "silenced": false, "attacks_used": 0}
	var display: Dictionary = view.call("_display")
	(display.player.board as Array).insert(0, entry)
	row.present(display)
	await view.get_tree().process_frame

	# Assert: the slot moved under it, the offset did not reset
	assert_float(before_sort.length()).is_greater(NEAR_ZERO_PX)
	assert_float(token.offset_transform_position.length()).is_greater(NEAR_ZERO_PX)
	assert_object(token.position).is_not_equal(slot_before)
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_the_lunge_rests_at_zero_when_its_step_ends() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt", [], {"anim_speed": "normal"})
	await MatchViewHarness.frames(view, 2)
	var row: BoardPresenter = view.find_child("PlayerRow", true, false)
	var attacker: int = int(view.view_state().side(&"player").board[0].entity_id)
	var defender: int = int(view.view_state().side(&"boss").board[2].entity_id)
	MatchViewHarness.inject(view, "attack_declared", {"attacker": attacker, "defender": defender})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

	# Act
	view.queue().skip_all()

	# Assert
	assert_object(row.token(attacker).offset_transform_position).is_equal(Vector2.ZERO)
	MatchViewHarness.close(view)
