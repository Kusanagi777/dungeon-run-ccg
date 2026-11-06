## The treasure tray (match-ui F6, O18 tray clause; story 021).
extends GdUnitTestSuite

const CHIP_PX: float = 40.0
const HIT_PX: float = 44.0
const CHIP_1_X: float = 24.0
const CHIP_2_X: float = 72.0
const CHIP_Y: float = 502.0
const MAX_CHIPS: int = 3
const FRAME_S: float = 1.0 / 60.0
const CHARM: String = "treasure_mending_charm"


func _tray(view: MatchView) -> TreasureTray:
	return view.get("_tray")


func _tooltip_text(tray: TreasureTray) -> String:
	var labels: Array[Node] = (tray.get("_tooltip") as Node).find_children("*", "Label", true, false)
	return (labels[0] as Label).text if not labels.is_empty() else ""


func test_two_chips_sit_at_their_f6_slots_with_no_fourth() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray")
	var tray: TreasureTray = _tray(view)

	# Assert
	assert_int(tray.count()).is_equal(2)
	var first: Rect2 = tray.call("_visual_rect", 0)
	var second: Rect2 = tray.call("_visual_rect", 1)
	assert_object(first).is_equal(Rect2(CHIP_1_X, CHIP_Y, CHIP_PX, CHIP_PX))
	assert_object(second).is_equal(Rect2(CHIP_2_X, CHIP_Y, CHIP_PX, CHIP_PX))
	assert_array((tray.get("_chips") as Array)).has_size(2)
	MatchViewHarness.close(view)


func test_no_treasure_means_no_tray_and_no_stop() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")

	# Assert
	assert_int(_tray(view).count()).is_equal(0)
	assert_array((_tray(view).get("_chips") as Array)).is_empty()
	for stop: Dictionary in (view.get("_focus") as FocusPresenter).stops():
		assert_str(str(stop.kind)).is_not_equal(FocusPresenter.KIND_TREASURE)
	MatchViewHarness.close(view)


func test_hit_rects_measure_44_around_their_chip_and_three_never_overlap() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray")
	var tray: TreasureTray = _tray(view)

	# Act
	var rects: Array[Rect2] = []
	for i: int in MAX_CHIPS:
		rects.append(tray.hit_rect(i))

	# Assert
	for i: int in MAX_CHIPS:
		assert_object(rects[i].size).is_equal(Vector2(HIT_PX, HIT_PX))
		assert_object(rects[i].get_center()).is_equal((tray.call("_visual_rect", i) as Rect2).get_center())
		if i > 0:
			assert_bool(rects[i].intersects(rects[i - 1])).is_false()
	MatchViewHarness.close(view)


func test_the_focus_pose_opens_the_tooltip_with_the_treasure_text_and_no_hover() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray", ["--pose=focus:treasure:1"])
	await MatchViewHarness.frames(view)
	var tray: TreasureTray = _tray(view)
	var face: Dictionary = view.ui_context().treasure_face("treasure_worn_signet")

	# Assert
	assert_bool((tray.get("_tooltip") as Control).visible).is_true()
	assert_str(_tooltip_text(tray)).contains(tr(str(face.text_key)))
	assert_str(_tooltip_text(tray)).contains(tr(str(face.name_key)))
	assert_str(_tooltip_text(tray)).contains(tr("treasure.rarity.%s" % str(face.rarity)))
	MatchViewHarness.close(view)


func test_a_hook_flares_its_chip_for_its_step_and_no_longer() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, FRAME_S)
	var tray: TreasureTray = _tray(view)

	# Act
	MatchViewHarness.inject(view, "effect_resolved", {"host_kind": "treasure", "host_id": "treasure_hollow_crown", "source_id": "treasure_hollow_crown"})
	MatchViewHarness.run(view, FRAME_S)
	var during: Dictionary = (tray.get("_flaring") as Dictionary).duplicate()
	MatchViewHarness.settle(view)

	# Assert
	assert_dict(during).is_equal({"treasure_hollow_crown": true})
	assert_dict(tray.get("_flaring")).is_empty()
	MatchViewHarness.close(view)


func test_the_real_fixture_fires_a_treasure_hook_into_the_flare() -> void:
	# Arrange / Act: the opening log itself holds a hook firing
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray")
	var hooks: int = 0
	for event: Dictionary in (view.get("_controller") as MatchController).events_since(0):
		if str(event.type) == "effect_resolved" and str(event.payload.get("host_kind", "")) == MatchViewState.HOST_KIND_TREASURE:
			hooks += 1

	# Assert
	assert_int(hooks).is_greater(0)
	MatchViewHarness.close(view)


func test_a_treasure_heal_of_zero_pops_nothing_and_one_line_names_the_treasure() -> void:
	# Arrange: a full-health hero
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray", [], {"anim_speed": "normal"})
	MatchViewHarness.run(view, FRAME_S)
	var hero: int = int(view.view_state().side(&"player").hero.entity_id)
	var total: int = view.view_state().feed_total
	var name: String = tr(view.ui_context().treasure_face(CHARM).name_key)

	# Act
	MatchViewHarness.inject(view, "healed", {"source": CHARM, "target": hero, "requested": 2, "amount": 0})
	MatchViewHarness.run(view, FRAME_S)
	MatchViewHarness.settle(view)

	# Assert
	assert_array(view.find_children("*", "NumberPop", true, false)).is_empty()
	assert_int(view.view_state().feed_total).is_equal(total + 1)
	var ticker: RichTextLabel = view.feed().get("_ticker")
	assert_str(ticker.text).contains(name)
	MatchViewHarness.close(view)


func test_a_rarity_is_a_word_in_the_tooltip_and_never_the_frame_alone() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray")
	_tray(view).show_tooltip(0)

	# Assert
	var rarity: String = str(view.ui_context().treasure_face("treasure_hollow_crown").rarity)
	assert_str(_tooltip_text(_tray(view))).contains(tr("treasure.rarity.%s" % rarity))
	MatchViewHarness.close(view)


func test_a_chip_index_past_the_tray_closes_the_tooltip() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "treasure_tray")
	_tray(view).show_tooltip(0)

	# Act
	_tray(view).show_tooltip(TreasureTray.NO_CHIP)

	# Assert
	assert_bool((_tray(view).get("_tooltip") as Control).visible).is_false()
	MatchViewHarness.close(view)
