## A whole match by mouse (match-ui U11; gate entry condition 5; story 012 AC-1): the
## scripted player of MUI-012 on `first_playable`, every action through the raw mouse path
## into `InputRouter`, at `anim_speed = instant`. Real viewport delivery is the owner's
## playtest: see [MatchViewHarness].
extends GdUnitTestSuite

const MAX_ACTIONS: int = 400
const ROW_POINT := Vector2(640, 400)
const CAST_POINT := Vector2(800, 220)
const AUTO_S: float = 4.5


func _play_turn_action(view: MatchView) -> void:
	var legal: Array[Dictionary] = view.router().player_commands()
	var chosen: Dictionary = {}
	for type: String in [MatchRecords.CMD_PLAY_CARD, MatchRecords.CMD_USE_HERO_POWER, MatchRecords.CMD_ATTACK]:
		for command: Dictionary in legal:
			if str(command.type) == type:
				chosen = command
				break
		if not chosen.is_empty():
			break
	match str(chosen.get("type", "")):
		MatchRecords.CMD_PLAY_CARD:
			_play_card(view, chosen)
		MatchRecords.CMD_USE_HERO_POWER:
			var power: Vector2 = (view.find_child("PlayerPanel", true, false) as HeroPresenter).power_rect().get_center()
			_through(view, power, chosen)
		MatchRecords.CMD_ATTACK:
			MatchViewHarness.drag(view, view.call("_locate", int(chosen.attacker_id)), view.call("_locate", int(chosen.target_id)))
		_:
			MatchViewHarness.press_end_turn(view)


func _play_card(view: MatchView, command: Dictionary) -> void:
	var id: int = MatchViewHarness.hand_id(view, int(command.hand_index))
	_through(view, MatchViewHarness.card_point(view, id), command)


## Drags from [param from] to where [param command] goes, and finishes a Phase T left open.
func _through(view: MatchView, from: Vector2, command: Dictionary) -> void:
	var target: Variant = command.get("target_id")
	var to: Vector2 = CAST_POINT
	if command.get("position") != null:
		to = ROW_POINT
	elif target != null:
		to = view.call("_locate", int(target))
	MatchViewHarness.drag(view, from, to)
	if view.router().in_session():
		MatchViewHarness.run(view, 0.0)
		var stop: int = int(view.router().session().hovered)
		var at: Vector2 = view.router().session().chip_rect.get_center() if stop == TargetingSession.NO_TARGET_CHIP else view.call("_locate", stop)
		MatchViewHarness.click(view, at)


func _choose(view: MatchView) -> void:
	view.choice().handle_action(MatchInput.HAND, 0)
	view.choice().handle_action(MatchInput.CONFIRM, -1)


func test_a_full_match_by_mouse_reaches_the_banner_with_no_desync_or_rejection() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "first_playable")
	await MatchViewHarness.frames(view, 2)
	var finished: Array[Dictionary] = []
	view.match_view_finished.connect(func(result: Dictionary) -> void: finished.append(result))
	var confirm: Button = view.mulligan().get("_confirm")
	confirm.pressed.emit()
	var actions: int = 0

	# Act
	while view.view_state().result == null and actions < MAX_ACTIONS:
		MatchViewHarness.settle(view)
		await view.get_tree().process_frame
		MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
		match view.router().view_state():
			InputRouter.STATE_IDLE:
				_play_turn_action(view)
			InputRouter.STATE_CHOICE_OPEN:
				_choose(view)
		actions += 1
	MatchViewHarness.settle(view)
	MatchViewHarness.run(view, AUTO_S)

	# Assert
	var types: Array[String] = MatchViewHarness.event_types(view)
	assert_int(actions).override_failure_message("the match did not end").is_less(MAX_ACTIONS)
	assert_array(types).contains(["match_ended", "attack_declared", "hero_power_used", "card_played"])
	assert_array(types).not_contains(["command_rejected"])
	assert_int(finished.size()).is_equal(1)
	assert_int(view.sync_failures).is_equal(0)
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	MatchViewHarness.close(view)
