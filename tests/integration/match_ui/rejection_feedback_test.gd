## Rejection Feedback (match-ui U5, O10; hud.md §12 Notifications; targeting.md §6 "Rejected";
## story 016). A rejection changes nothing on the table but its own feedback.
extends GdUnitTestSuite

const FRAME_S: float = 1.0 / 60.0
const TOOLTIP_S: float = 1.5


func _reject(view: MatchView) -> RejectPresenter:
	return view.get("_reject")


func _tooltip(view: MatchView) -> Control:
	return _reject(view).get("_tooltip")


func _tooltip_text(view: MatchView) -> String:
	var labels: Array[Node] = _tooltip(view).find_children("*", "Label", true, false)
	return (labels[0] as Label).text if not labels.is_empty() else ""


func test_o10_the_taunt_pose_shows_the_reason_and_flashes_the_taunts_only() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt", ["--pose=reject:MUST_ATTACK_TAUNT"])
	MatchViewHarness.run(view, FRAME_S)
	var row: BoardPresenter = view.find_child("BossRow", true, false)

	# Assert
	assert_bool(_tooltip(view).visible).is_true()
	assert_str(_tooltip_text(view)).is_equal(tr("reject.MUST_ATTACK_TAUNT"))
	for token: Dictionary in view.view_state().side(&"boss").board:
		var flash: bool = row.token(int(token.entity_id)).get("_flash")
		assert_bool(flash).override_failure_message(str(token.card_id)).is_equal((token.keywords as Array).has("taunt"))
	MatchViewHarness.close(view)


func test_the_mana_pose_flashes_the_bar_and_writes_the_ticker_and_nothing_else() -> void:
	# Arrange
	var clean: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var before: Dictionary = clean.view_state().snapshot()
	MatchViewHarness.close(clean)

	# Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", ["--pose=reject:NOT_ENOUGH_MANA"])
	MatchViewHarness.settle(view)
	var panel: HeroPresenter = view.find_child("PlayerPanel", true, false)
	var after: Dictionary = view.view_state().snapshot()

	# Assert
	assert_bool((panel.get("_mana_flash") as Control).visible).is_true()
	assert_str(_tooltip_text(view)).is_equal(tr("reject.NOT_ENOUGH_MANA"))
	var ticker: RichTextLabel = view.feed().get("_ticker")
	assert_str(ticker.text).contains(tr("reject.NOT_ENOUGH_MANA"))
	after.erase("feed_lines")
	after.erase("feed_total")
	before.erase("feed_lines")
	before.erase("feed_total")
	assert_dict(after).is_equal(before)
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	MatchViewHarness.close(view)


func test_a_forced_rejection_starts_its_feedback_on_the_next_step_of_the_clock() -> void:
	# Arrange: a race the disable missed: an attack that was never legal
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt", [], {"anim_speed": "normal"})
	await MatchViewHarness.frames(view, 2)
	MatchViewHarness.run(view, FRAME_S)
	var attacker: int = int(view.view_state().side(&"player").board[0].entity_id)
	var boss: int = int(view.view_state().side(&"boss").hero.entity_id)
	var shakes: Array[String] = []
	view.queue().step_started.connect(func(step: AnimStep, _d: float) -> void: shakes.append(String(step.kind)))

	# Act
	view.router().command_requested.emit(MatchRecords.attack("player", attacker, boss))
	view.call("_process", 0.0)

	# Assert: no clock has passed, inside the 50 ms budget
	assert_array(shakes).contains([String(AnimStep.REJECT_SHAKE)])
	assert_bool(_tooltip(view).visible).is_true()
	assert_bool(view.sfx.played(SfxStub.CUE_DENY)).is_true()
	MatchViewHarness.close(view)


func test_the_tooltip_clears_after_rejection_tooltip_s() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, FRAME_S)
	var attacker: int = int(view.view_state().side(&"player").board[0].entity_id)
	var boss: int = int(view.view_state().side(&"boss").hero.entity_id)
	view.router().command_requested.emit(MatchRecords.attack("player", attacker, boss))
	view.call("_process", 0.0)
	var hide: Tween = _reject(view).get("_hide")

	# Act
	hide.custom_step(TOOLTIP_S - 0.1)
	var held: bool = _tooltip(view).visible
	hide.custom_step(0.11)

	# Assert
	assert_bool(held).is_true()
	assert_bool(_tooltip(view).visible).is_false()
	MatchViewHarness.close(view)


func test_the_rejected_source_shakes_and_rests_where_it_started() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray", [], {"anim_speed": "normal"})
	await MatchViewHarness.frames(view, 2)
	MatchViewHarness.run(view, FRAME_S)
	var panel: HeroPresenter = view.find_child("PlayerPanel", true, false)
	var power: Control = panel.power_control()
	var rest: Vector2 = power.position
	_reject(view).set_origin(power, Vector2(640, 360))
	var step := AnimStep.new(AnimStep.REJECT_SHAKE, [], 0.2, 1, 1)
	step.data = {"code": "NOT_ENOUGH_MANA"}

	# Act
	_reject(view).on_step_started(step, 0.2)
	(((_reject(view).get("_step_tweens") as Dictionary)[step] as Array)[0] as Tween).custom_step(0.03)
	var moved: Vector2 = power.position
	_reject(view).apply_final(step)

	# Assert
	assert_object(moved).is_not_equal(rest)
	assert_object(power.position).is_equal(rest)
	MatchViewHarness.close(view)


func test_reduce_motion_swaps_the_shake_for_the_outline_flash() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray", [], {"anim_speed": "normal", "reduce_motion": true})
	await MatchViewHarness.frames(view, 2)
	var panel: HeroPresenter = view.find_child("PlayerPanel", true, false)
	var power: Control = panel.power_control()
	var rest: Vector2 = power.position
	_reject(view).set_origin(power, Vector2(640, 360))
	var step := AnimStep.new(AnimStep.REJECT_SHAKE, [], 0.2, 1, 1)
	step.data = {"code": "NOT_ENOUGH_MANA"}

	# Act
	_reject(view).on_step_started(step, 0.2)

	# Assert
	assert_bool((_reject(view).get("_outline") as Control).visible).is_true()
	assert_bool((_reject(view).get("_step_tweens") as Dictionary).has(step)).is_false()
	assert_object(power.position).is_equal(rest)
	_reject(view).apply_final(step)
	MatchViewHarness.close(view)


func test_a_rejection_at_instant_still_shows_its_reason() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "targeting_taunt")
	MatchViewHarness.run(view, FRAME_S)
	var attacker: int = int(view.view_state().side(&"player").board[0].entity_id)
	var boss: int = int(view.view_state().side(&"boss").hero.entity_id)

	# Act
	view.router().command_requested.emit(MatchRecords.attack("player", attacker, boss))
	MatchViewHarness.run(view, FRAME_S)

	# Assert: it is the only text the player gets
	assert_bool(_tooltip(view).visible).is_true()
	MatchViewHarness.close(view)


func test_a_boss_rejection_shows_the_player_nothing() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, FRAME_S)
	var total: int = view.view_state().feed_total

	# Act
	MatchViewHarness.inject(view, "command_rejected", {"side": "boss", "code": "NOT_ENOUGH_MANA", "command": {}, "diagnostic": true})
	MatchViewHarness.run(view, FRAME_S)

	# Assert
	assert_bool(_tooltip(view).visible).is_false()
	assert_int(view.view_state().feed_total).is_equal(total)
	MatchViewHarness.close(view)


func test_a_refused_drag_sends_the_card_home() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray")
	await MatchViewHarness.frames(view, 2)
	MatchViewHarness.run(view, FRAME_S)
	var id: int = MatchViewHarness.hand_id(view, 1)
	var rest: Vector2 = view.hand().card(id).position
	view.hand().begin_drag(id, false)
	view.hand().follow(Vector2(640, 300))
	view.set("_dropped_card", id)
	view.hand().end_drag(true)

	# Act: a `play_card` the engine refuses: its hand index is past the hand
	view.call("_on_command_requested", MatchRecords.play_card("player", 99, 0))

	# Assert
	assert_object(view.hand().card(id).position).is_equal(rest)
	assert_dict(view.hand().get("_travelling")).is_empty()
	MatchViewHarness.close(view)
