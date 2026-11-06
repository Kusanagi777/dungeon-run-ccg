## Hero panels, mana and End Turn (match-ui O3 zones, U3, U5, F6; hud.md §12; story 005).
extends GdUnitTestSuite

const PX: float = 2.0
const DAMAGE: int = 3
const HEAL: int = 2
## `power_press_scale` given through the helper body, off its shipped value.
const PRESS_SCALE: float = 0.5
const PRESS_D_S: float = 0.3


func _panel(view: MatchView) -> HeroPresenter:
	return view.find_child("PlayerPanel", true, false)


func _boss(view: MatchView) -> HeroPresenter:
	return view.find_child("BossPanel", true, false)


func _rect(control: Control) -> Rect2:
	return control.get_global_rect()


func _assert_rect(control: Control, want: Rect2, what: String) -> void:
	var got: Rect2 = _rect(control)
	assert_float(got.position.distance_to(want.position)).override_failure_message("%s at %s, want %s" % [what, str(got), str(want)]).is_less_equal(PX)
	assert_float(got.size.distance_to(want.size)).override_failure_message("%s is %s, want %s" % [what, str(got), str(want)]).is_less_equal(PX)


func _pops(view: MatchView) -> Array[Node]:
	return view.find_children("*", "NumberPop", true, false)


func test_every_zone_sits_at_its_f6_rect() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var player: HeroPresenter = _panel(view)
	var boss: HeroPresenter = _boss(view)

	# Assert: the numbers are the story's, not the config's
	_assert_rect(player.get("_portrait"), Rect2(24, 334, 120, 160), "player portrait")
	_assert_rect(boss.get("_portrait"), Rect2(1136, 96, 120, 160), "boss portrait")
	_assert_rect(player.get("_power"), Rect2(152, 390, 48, 48), "hero power")
	_assert_rect(player.get("_weapon"), Rect2(152, 446, 48, 48), "weapon slot")
	_assert_rect(boss.get("_hand_box"), Rect2(1136, 262, 60, 28), "boss hand count")
	_assert_rect(view.get("_end_turn"), Rect2(1116, 296, 140, 44), "End Turn")
	assert_object(view.ui_context().rect("mana_bar")).is_equal(Rect2(1060, 652, 196, 56))
	assert_object(view.ui_context().rect("top_bar")).is_equal(Rect2(0, 0, 1280, 40))
	assert_object((_rect(player.get("_deck").get_parent()) as Rect2).position).is_equal(Vector2(1180, 540))
	assert_object((_rect(boss.get("_deck").get_parent()) as Rect2).position).is_equal(Vector2(24, 96))
	MatchViewHarness.close(view)


func test_the_top_bar_reads_the_players_turn() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")

	# Assert
	assert_str((view.get("_turn_label") as Label).text).is_equal(tr("hud.turn.player") % 1)
	MatchViewHarness.close(view)


func test_damage_on_a_hero_pops_minus_the_amount_at_normal() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	var hero: int = int(view.view_state().side(&"player").hero.entity_id)

	# Act
	MatchViewHarness.inject(view, "damage_dealt", {"target": hero, "source": 2, "dealt": DAMAGE, "prevented": 0, "health_after": 27})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

	# Assert
	var pops: Array[Node] = _pops(view)
	assert_int(pops.size()).is_equal(1)
	assert_str((pops[0].find_children("*", "Label", true, false)[0] as Label).text).is_equal("−%d" % DAMAGE)
	MatchViewHarness.close(view)


func test_a_heal_pops_plus_the_amount_and_the_final_equals_the_view_state() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "boss_intent_full", [], {"anim_speed": "normal"})
	var hero: int = int(view.view_state().side(&"player").hero.entity_id)

	# Act
	MatchViewHarness.inject(view, "healed", {"target": hero, "source": hero, "amount": HEAL})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var pops: Array[Node] = _pops(view)
	var text: String = (pops[0].find_children("*", "Label", true, false)[0] as Label).text
	MatchViewHarness.settle(view)

	# Assert
	assert_str(text).is_equal("+%d" % HEAL)
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	assert_str((_panel(view).get("_health") as Label).text).is_equal(str(view.view_state().side(&"player").hero.health))
	MatchViewHarness.close(view)


func test_prevented_damage_and_a_zero_heal_pop_nothing() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	var hero: int = int(view.view_state().side(&"player").hero.entity_id)

	# Act
	MatchViewHarness.inject(view, "damage_dealt", {"target": hero, "source": 2, "dealt": 0, "prevented": DAMAGE, "health_after": 30})
	MatchViewHarness.inject(view, "healed", {"target": hero, "source": hero, "amount": 0})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

	# Assert
	assert_array(_pops(view)).is_empty()
	MatchViewHarness.close(view)


func test_a_skip_frees_the_pop_and_the_numbers_land_on_the_view_state() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	var hero: int = int(view.view_state().side(&"player").hero.entity_id)
	MatchViewHarness.inject(view, "damage_dealt", {"target": hero, "source": 2, "dealt": DAMAGE, "prevented": 0, "health_after": 27})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

	# Act
	view.queue().skip_all()
	await MatchViewHarness.frames(view)

	# Assert
	assert_array(_pops(view)).is_empty()
	assert_str((_panel(view).get("_health") as Label).text).is_equal("27")
	assert_array(MatchViewHarness.sync_lines(view)).is_empty()
	MatchViewHarness.close(view)


func test_armor_shows_its_stamp_only_while_there_is_some() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var box: Control = _panel(view).get("_armor_box")
	var before: bool = box.visible

	# Act
	MatchViewHarness.inject(view, "armor_gained", {"entity_id": view.view_state().side(&"player").hero.entity_id, "side": "player", "amount": 2, "armor": 2})
	MatchViewHarness.run(view, 0.0)
	view.call("_present", view.call("_display"))

	# Assert
	assert_bool(before).is_false()
	assert_bool(box.visible).is_true()
	MatchViewHarness.close(view)


func test_a_click_on_end_turn_in_idle_submits_exactly_one() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act: no arm guard on a click
	var took: bool = MatchViewHarness.press_end_turn(view)

	# Assert
	assert_bool(took).is_true()
	assert_int(sent.size()).is_equal(1)
	assert_str(str(sent[0].type)).is_equal(MatchRecords.CMD_END_TURN)
	MatchViewHarness.close(view)


func test_end_turn_is_disabled_on_the_mulligan_and_the_choice() -> void:
	for fixture: String in ["mulligan", "choice_discover"]:
		# Arrange / Act
		var view: MatchView = await MatchViewHarness.open(self, fixture)
		MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

		# Assert
		assert_bool((view.get("_end_turn") as Button).disabled).override_failure_message(fixture).is_true()
		assert_bool(MatchViewHarness.press_end_turn(view)).is_false()
		MatchViewHarness.close(view)


func test_end_turn_is_disabled_during_playback_and_the_boss_turn() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)

	# Act
	MatchViewHarness.press_end_turn(view)
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

	# Assert: the view is playing the boss's turn now
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_BOSS_TURN))
	assert_bool((view.get("_end_turn") as Button).disabled).is_true()
	assert_bool(MatchViewHarness.press_end_turn(view)).is_false()
	assert_int(sent.size()).is_equal(1)
	MatchViewHarness.close(view)


func test_end_turn_takes_the_actionable_outline_when_no_mana_is_left() -> void:
	# Arrange: 1 mana, a 1-cost card, and playback in between so `Idle` is entered afresh
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", [], {"anim_speed": "fast"})
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var style: StyleBoxFlat = view.get("_end_turn_style")
	var lit_before: bool = style.border_color == view.ui_context().color("state_actionable")
	var play: Dictionary = MatchViewHarness.legal(view, MatchRecords.CMD_PLAY_CARD)[0]

	# Act
	view.router().command_requested.emit(play)
	MatchViewHarness.settle(view)

	# Assert
	assert_bool(lit_before).is_false()
	assert_int(int(view.view_state().side(&"player").mana.available)).is_equal(0)
	assert_object(style.border_color).is_equal(view.ui_context().color("state_actionable"))
	MatchViewHarness.close(view)


func test_one_click_on_the_hero_power_submits_nothing_and_lifts_the_button() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray")
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
	var panel: HeroPresenter = _panel(view)
	var rest: Vector2 = (panel.get("_power") as Control).position

	# Act
	MatchViewHarness.click(view, panel.power_rect().get_center())

	# Assert
	assert_array(sent).is_empty()
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_KEY_TARGETING))
	assert_float(rest.y - (panel.get("_power") as Control).position.y).is_equal(float(view.ui_context().config.hero.power_lift_px))
	MatchViewHarness.close(view)


func test_a_second_click_on_the_hero_power_casts_once_and_the_button_dims() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray")
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var sent: Array[Dictionary] = MatchViewHarness.spy_commands(view)
	var panel: HeroPresenter = _panel(view)
	var at: Vector2 = panel.power_rect().get_center()
	MatchViewHarness.click(view, at)

	# Act
	MatchViewHarness.click(view, at)
	MatchViewHarness.settle(view)

	# Assert
	assert_int(sent.size()).is_equal(1)
	assert_str(str(sent[0].type)).is_equal(MatchRecords.CMD_USE_HERO_POWER)
	assert_that(sent[0].get("target_id")).is_null()
	assert_array(MatchViewHarness.event_types(view)).contains(["hero_power_used"])
	assert_str(str(view.view_state().side(&"player").hero.power_state)).is_equal(MatchViewState.POWER_USED)
	assert_float((panel.get("_power") as Control).modulate.a).is_equal(HeroPresenter.USED_ALPHA)
	MatchViewHarness.close(view)


func test_a_blocked_power_shows_its_reason_on_hover() -> void:
	# Arrange: one mana against a two-mana power
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)
	var panel: HeroPresenter = _panel(view)
	var state: Dictionary = view.ui_context().query.hero_power_state("player")

	# Act
	MatchViewHarness.send(view, MatchViewHarness.motion(panel.power_rect().get_center()))

	# Assert
	assert_str(str(state.state)).is_equal(MatchQuery.POWER_BLOCKED)
	assert_bool((panel.get("_tooltip") as Control).visible).is_true()
	assert_str((panel.get("_tooltip_text") as Label).text).contains(tr("reject." + str(state.reason_code)))
	MatchViewHarness.close(view)


func test_a_blocked_power_cannot_be_selected() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	MatchViewHarness.run(view, MatchViewHarness.FRAME_S)

	# Act
	MatchViewHarness.click(view, _panel(view).power_rect().get_center())

	# Assert
	assert_bool(view.router().in_session()).is_false()
	MatchViewHarness.close(view)


func test_the_power_press_dips_to_the_scale_the_config_gives() -> void:
	# Arrange: a panel on the helper body, its press pinned away from the shipped value
	var ui := MatchUiContext.new(MatchUiTestConfig.presenter_body({"hero": {"power_press_scale": PRESS_SCALE}}), MatchViewHarness.database())
	var view_state := MatchViewState.new(ui.config)
	var panel: HeroPresenter = (load("res://src/ui/match/hero_panel.tscn") as PackedScene).instantiate()
	add_child(panel)
	panel.side = HeroPresenter.SIDE_PLAYER
	panel.setup(ui)
	panel.bind(view_state)
	panel.set_identity({"primary": ui.color("war"), "power_id": "power_whetstone"})
	var step := AnimStep.new(AnimStep.POWER_PRESS, [], PRESS_D_S, 1, 1)

	# Act: the half-way point of the step is the bottom of the press
	panel.on_step_started(step, PRESS_D_S)
	var tweens: Array = (panel.get("_step_tweens") as Dictionary)[step]
	(tweens[0] as Tween).custom_step(PRESS_D_S / 2.0)
	var bottom: Vector2 = (panel.get("_power") as Control).scale
	panel.apply_final(step)

	# Assert
	assert_float(bottom.x).is_equal_approx(PRESS_SCALE, 0.001)
	assert_object((panel.get("_power") as Control).scale).is_equal(Vector2.ONE)
	panel.free()
