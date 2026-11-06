## `RunDebugLoader` and its fixtures (run-ui U10; AC-1 to AC-8, AC-31's logic half): every
## fixture opens its screen with no transition, and what each AC names is in the tree.
## Pixels stay manual: `production/qa/evidence/` per run-and-observe.
extends GdUnitTestSuite

## Fixture, screen (Acceptance Criteria; U10).
const SCREENS: Array = [
	["fresh_profile", &"main_menu"], ["fresh_profile", &"hero_select"], ["fresh_profile", &"run_log"], ["fresh_profile", &"settings"],
	["fresh_profile", &"controls"], ["fresh_profile", &"glossary"],
	["locked_heroes", &"hero_select"], ["locked_heroes_ts150", &"hero_select"],
	["mid_run_floor4", &"boss_intro"], ["mid_run_floor4", &"pause"],
	["draft_treasure_sample", &"draft_treasure"], ["draft_treasure_short", &"draft_treasure"],
	["draft_bundle_sample", &"draft_bundle"], ["draft_bundle_sample_ts150", &"draft_bundle"],
	["victory_sample", &"summary_victory"], ["victory_sample_ts150", &"summary_victory"],
	["defeat_sample", &"summary_defeat"], ["defeat_sample_ts150", &"summary_defeat"],
	["abandoned_sample", &"summary_abandoned"], ["resume_prompt", &"resume_prompt"],
	["run_log_sample", &"run_log"], ["toast_sample", &"main_menu"],
]
const REQUIRED: Array[String] = [
	"fresh_profile", "mid_run_floor4", "victory_sample", "defeat_sample", "locked_heroes", "abandoned_sample",
	"draft_treasure_sample", "draft_bundle_sample", "draft_treasure_short", "resume_prompt", "data_error_sample",
	"toast_sample", "draft_bundle_sample_ts150", "locked_heroes_ts150", "victory_sample_ts150", "defeat_sample_ts150",
	"run_log_sample", "unlock_toast_summary",
]
const DESIGN: Rect2 = Rect2(0, 0, 1280, 720)
## A label reading like an unresolved `tr()` key.
const KEY_SHAPE: String = "^[a-z_]+(\\.[a-z_0-9]+)+$"
const EDGE_PX: float = 1.0

var _rig: RunUiRig = null


func before() -> void:
	RunUiRig.install_input()


func after() -> void:
	RunUiRig.restore_input()


func after_test() -> void:
	if _rig != null:
		_rig.finish()
		_rig = null


func _open(fixture: String, screen: StringName) -> Screen:
	var loader: RunDebugLoader = RunDebugLoader.new()
	var overrides: Dictionary = loader.load_fixture(fixture)
	_rig = await RunUiRig.start(self, overrides.meta, {})
	loader.open(_rig.shell, screen)
	await _rig.settle(2)
	return _rig.top()


func _all_text(node: Node) -> String:
	return "\n".join(RunUiRig.texts(node))


func _buttons(node: Node) -> Array:
	return node.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.is_visible_in_tree()).map(func(b: Button) -> String: return b.text)


# --- from_args, load_fixture ----------------------------------------------------------

func test_from_args_reads_both_names() -> void:
	var found: Dictionary = RunDebugLoader.from_args(PackedStringArray(["--run-ui-screen=boss_intro", "--run-ui-fixture=mid_run_floor4"]))
	assert_str(str(found.screen)).is_equal("boss_intro")
	assert_str(str(found.fixture)).is_equal("mid_run_floor4")


func test_from_args_reads_absent_as_empty() -> void:
	var found: Dictionary = RunDebugLoader.from_args(PackedStringArray(["--other=1"]))
	assert_str(str(found.screen)).is_empty()
	assert_str(str(found.fixture)).is_empty()


func test_from_args_refuses_a_name_that_could_point_elsewhere() -> void:
	for bad: String in ["../../assets/data", "a/b", "Boss", "a.b", ""]:
		var found: Dictionary = RunDebugLoader.from_args(PackedStringArray(["--run-ui-fixture=" + bad]))
		assert_str(str(found.fixture)).override_failure_message(bad).is_empty()


func test_every_required_fixture_is_on_disk_and_there_are_no_strays() -> void:
	var on_disk: Array = Array(DirAccess.get_files_at("res://tests/fixtures/run_ui/")).filter(func(file: String) -> bool: return file.ends_with(".json")).map(func(file: String) -> String: return file.get_basename())
	on_disk.sort()
	var wanted: Array = REQUIRED.duplicate()
	wanted.sort()
	assert_array(on_disk).is_equal(wanted)


func test_every_fixture_loads_a_ready_database_and_a_stub() -> void:
	for fixture: String in REQUIRED:
		var overrides: Dictionary = RunDebugLoader.new().load_fixture(fixture)
		assert_int((overrides.card_database as CardDatabase).state()).override_failure_message(fixture).is_equal(CardDatabase.State.READY)
		assert_bool(overrides.meta is MetaStub).override_failure_message(fixture).is_true()


func test_a_ts150_fixture_carries_its_text_scale_and_the_base_does_not() -> void:
	var scaled: MetaApi = RunDebugLoader.new().load_fixture("victory_sample_ts150").meta
	var plain: MetaApi = RunDebugLoader.new().load_fixture("victory_sample").meta
	assert_float(float(scaled.get_setting(&"text_scale"))).is_equal(1.5)
	assert_float(float(plain.get_setting(&"text_scale"))).is_equal(1.0)


func test_a_missing_fixture_loads_as_an_empty_one() -> void:
	var overrides: Dictionary = RunDebugLoader.new().load_fixture("no_such_fixture")
	assert_bool(overrides.meta is MetaStub).is_true()


func test_every_fixture_screen_opens_with_no_transition_and_no_raw_key() -> void:
	var shape: RegEx = RegEx.create_from_string(KEY_SHAPE)
	for row: Array in SCREENS:
		var screen: Screen = await _open(row[0], row[1])
		var name: String = "%s/%s" % [row[0], row[1]]
		assert_str(String(_rig.controller.state.top())).override_failure_message(name).is_equal(String(row[1]))
		assert_bool(_rig.controller.state.transitioning).override_failure_message(name).is_false()
		for text: String in RunUiRig.texts(screen):
			assert_object(shape.search(text)).override_failure_message("%s shows %s" % [name, text]).is_null()
		_rig.finish()
		_rig = null


func test_the_toast_sample_shows_its_toasts_in_turn() -> void:
	await _open("toast_sample", &"main_menu")
	var layer: ToastLayer = _rig.shell._toasts
	assert_bool(layer.is_showing()).is_true()
	assert_array(RunUiRig.texts(layer)).contains(["New hero unlocked: Mother Wythe", "Win 1 runs"])
	assert_int(layer.queued().size()).is_equal(2)


# --- AC-1 to AC-8 -------------------------------------------------------------------

func test_ac1_a_fresh_menu_has_four_rows_no_continue_and_zero_runs() -> void:
	var screen: Screen = await _open("fresh_profile", &"main_menu")
	assert_array(_buttons(screen)).is_equal([tr("menu.new_run"), tr("menu.run_log"), tr("menu.settings"), tr("menu.quit")])
	assert_array(RunUiRig.texts(screen)).contains([tr("menu.stats").format({"runs": 0, "wins": 0, "best": 0})])


func test_ac2_hero_select_lists_the_data_with_war_chosen() -> void:
	# Arrange
	var screen: Screen = await _open("fresh_profile", &"hero_select")
	var heroes: Array = _rig.db.heroes()

	# Assert
	assert_int(screen._panels.size()).is_equal(heroes.size())
	assert_int(screen._locked.size()).is_equal(0)
	assert_str(str(screen._heroes[screen._selected].id)).is_equal("hero_war")
	var power: Dictionary = _rig.db.hero_power(str((_rig.db.hero("hero_war") as Dictionary).hero_power))
	assert_str(_all_text(screen)).contains(str(power.name))
	assert_str(screen._deck.text).is_equal(tr("hero.deck").format({"n": 15}))
	assert_array(RunUiRig.texts(screen)).contains([tr("hero.seed_random"), tr("hero.stats").format({"w": 0, "l": 0, "f": 0})])
	assert_str((_rig.focus() as Button).text).is_equal(tr("hero.start"))


func test_ac3_locked_heroes_show_a_hint_and_start_is_disabled_on_one() -> void:
	# Arrange
	var screen: Screen = await _open("locked_heroes", &"hero_select")

	# Assert
	assert_int(screen._locked.size()).is_equal(3)
	for name: String in ["Fortune", "Order", "Shadow"]:
		assert_str(_all_text(screen)).contains(tr("hero.locked").format({"name": name}))
	assert_str(_all_text(screen)).contains("/")
	assert_bool(screen._start.disabled).is_false()
	(screen._locked[0] as Control).grab_focus()
	assert_bool(screen._start.disabled).is_true()
	await _rig.key(KEY_ENTER)
	assert_str(String(_rig.shell.screen())).is_equal("hero_select")
	(screen._panels[0] as Control).grab_focus()
	assert_bool(screen._start.disabled).is_false()


func test_ac3_number_keys_skip_locked_panels() -> void:
	var screen: Screen = await _open("locked_heroes", &"hero_select")
	screen.handle_option_key(screen._panels.size())
	assert_bool(screen._locked.has(_rig.focus())).is_false()


func test_ac4_the_boss_intro_of_floor_four() -> void:
	# Arrange
	var screen: Screen = await _open("mid_run_floor4", &"boss_intro")
	var cfg: Dictionary = RunUiRig.config()
	var rust: Color = RunUiConfig.color(cfg, "boss_band_2")

	# Assert: the lines
	assert_array(RunUiRig.texts(screen)).contains([tr("boss.floor").format({"n": 4, "f": 8}), tr("strip.deck").format({"n": 24})])
	assert_str(_all_text(screen)).contains("Your power: ")
	assert_str(_all_text(screen)).not_contains(tr("boss.attempt").format({"n": 1}))

	# Two pips in rust
	var pips: Array = screen.find_children("*", "ColorRect", true, false).filter(func(rect: ColorRect) -> bool: return rect.color == rust and rect.custom_minimum_size.x == 12.0)
	assert_int(pips.size()).is_equal(2)

	# Nodes 1-3 filled with initials, 4 ringed, 5-8 hollow with none; two chips; two gems
	var strip: ProgressStrip = screen.find_children("*", "ProgressStrip", true, false)[0]
	var nodes: Array = strip.focus_stops().filter(func(stop: Control) -> bool: return stop is ProgressStrip.StripNode)
	assert_int(nodes.size()).is_equal(8)
	var states: Array = nodes.map(func(node: ProgressStrip.StripNode) -> String: return str(node.data.state))
	assert_array(states).is_equal(["cleared", "cleared", "cleared", "current", "upcoming", "upcoming", "upcoming", "upcoming"])
	for i: int in 4:
		assert_str(str(nodes[i].data.initial)).is_not_empty()
	for i: int in range(4, 8):
		assert_str(str(nodes[i].data.initial)).is_empty()
	assert_int(strip.focus_stops().filter(func(stop: Control) -> bool: return stop is Button).size()).is_equal(2)
	assert_int(nodes.filter(func(node: ProgressStrip.StripNode) -> bool: return bool(node.data.gem)).size()).is_equal(2)
	assert_str((_rig.focus() as Button).text).is_equal(tr("boss.fight"))


func test_ac5_treasure_options_sit_on_their_slots_with_pick_dim() -> void:
	var screen: Screen = await _open("draft_treasure_sample", &"draft_treasure")
	var xs: Array = screen._panels.map(func(panel: OptionPanel) -> float: return panel.position.x)
	assert_array(xs).is_equal([367.0, 565.0, 763.0])
	for panel: OptionPanel in screen._panels:
		assert_float(panel.position.y).is_equal(240.0)
	assert_bool(screen._pick.disabled).is_true()
	assert_object(_rig.focus()).is_null()
	screen.handle_option_key(0)
	assert_bool(screen._pick.disabled).is_false()


func test_ac5_bundle_panels_sit_on_their_slots_with_cards_and_a_preview() -> void:
	# Arrange
	var screen: Screen = await _open("draft_bundle_sample", &"draft_bundle")

	# Assert
	var xs: Array = screen._panels.map(func(panel: OptionPanel) -> float: return panel.position.x)
	assert_array(xs).is_equal([90.0, 470.0, 850.0])

	# Focusing a row previews the whole card, inside the viewport
	var rows: Array = screen._panels[2].find_children("*", "PanelContainer", true, false).filter(func(row: Control) -> bool: return row.focus_mode == Control.FOCUS_ALL)
	assert_int(rows.size()).is_equal(3)
	(rows[0] as Control).grab_focus()
	await _rig.settle(2)
	assert_bool(screen._preview.visible).is_true()
	assert_bool(DESIGN.encloses(screen._preview.get_global_rect())).override_failure_message(str(screen._preview.get_global_rect())).is_true()


func test_ac5_focusing_a_bundle_shows_its_hints_and_blur_clears_them() -> void:
	var screen: Screen = await _open("draft_bundle_sample", &"draft_bundle")
	screen.handle_option_key(1)
	assert_str(screen._hint2.text).starts_with("Deck ")
	_rig.shell.get_viewport().gui_release_focus()
	assert_str(screen._hint2.text).is_empty()


func test_ac5_options_keep_their_f4_size_at_100_and_150_percent() -> void:
	# A wrapped label measured before layout must not leave a panel taller than its slot
	for row: Array in [["draft_treasure_sample", &"draft_treasure", Vector2(150, 210)], ["draft_bundle_sample", &"draft_bundle", Vector2(340, 320)], ["draft_bundle_sample_ts150", &"draft_bundle", Vector2(340, 320)]]:
		var screen: Screen = await _open(row[0], row[1])
		for panel: OptionPanel in screen._panels:
			assert_vector(panel.size).override_failure_message(str(row[0])).is_equal(row[2])
		_rig.finish()
		_rig = null


func test_the_locked_panels_keep_their_height() -> void:
	var screen: Screen = await _open("locked_heroes", &"hero_select")
	for panel: OptionPanel in screen._locked:
		assert_float(panel.size.y).is_equal(screen.LOCKED_H)


func test_a_toast_stays_near_its_rect() -> void:
	# Arrange: wrapped labels, added after the rect is set
	await _open("toast_sample", &"main_menu")
	await _rig.settle(2)
	var rect: Rect2 = _rig.shell._toasts._panel.get_global_rect()

	# Assert: top right, on screen, and two lines tall at most
	assert_float(rect.position.x).is_equal(ToastLayer.TOAST_RECT.position.x)
	assert_bool(DESIGN.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_float(rect.size.y).override_failure_message(str(rect)).is_less_equal(ToastLayer.TOAST_RECT.size.y * 2.0)


func test_ac6_the_victory_summary() -> void:
	# Arrange
	var screen: Screen = await _open("victory_sample", &"summary_victory")
	var cfg: Dictionary = RunUiRig.config()
	var text: String = _all_text(screen)

	# Assert
	assert_array(RunUiRig.texts(screen)).contains([tr("summary.headline.victory").format({"f": 8})])
	assert_str(text).contains("48A10CC0B2ED54EC")
	assert_object(RunUiRig.button(screen, tr("summary.copy"))).is_not_null()
	assert_str(text).contains(tr("summary.more").format({"n": 2}).left(4))
	assert_str(text).contains("New hero unlocked")
	var cells: Array = screen.find_children("*", "FloorStrip", true, false)[0]._cells
	assert_int(cells.size()).is_equal(8)
	assert_int(cells.filter(func(cell: Dictionary) -> bool: return cell.state == "cleared").size()).is_equal(8)
	assert_str((_rig.focus() as Button).text).is_equal(tr("summary.new_run"))
	var back: ColorRect = screen.get_child(0)
	assert_object(back.color).is_equal(RunUiConfig.color(cfg, "table_lit"))


func test_ac6_the_portrait_saturates_when_the_summary_is_revealed() -> void:
	var screen: Screen = await _open("victory_sample", &"summary_victory")
	var hero_color: Color = RunUiConfig.color(RunUiRig.config(), "war")
	screen._view.saturate_portrait(hero_color, true)
	assert_object(screen._view._portrait.color).is_equal(hero_color)


func test_ac7_the_defeat_summary() -> void:
	# Arrange
	var screen: Screen = await _open("defeat_sample", &"summary_defeat")
	var cfg: Dictionary = RunUiRig.config()

	# Assert: bg_edge, the floor and boss in the headline, attempt 2 on floor 3
	assert_object((screen.get_child(0) as ColorRect).color).is_equal(RunUiConfig.color(cfg, "bg_edge"))
	assert_str(_all_text(screen)).contains("Fell on floor 5: ")
	var cells: Array = screen.find_children("*", "FloorStrip", true, false)[0]._cells
	assert_int(int(cells[2].attempt)).is_equal(2)
	assert_str(str(cells[2].tip)).contains(tr("summary.cell.attempt").format({"n": 2}))
	assert_str(str(cells[4].state)).is_equal("killed")
	assert_str(str(cells[5].state)).is_equal("hollow")
	assert_str((_rig.focus() as Button).text).is_equal(tr("summary.new_run"))

	# No state_danger fill bigger than a stamp
	var danger: Color = RunUiConfig.color(cfg, "state_danger")
	var fills: Array = screen.find_children("*", "ColorRect", true, false).filter(func(rect: ColorRect) -> bool: return rect.color == danger)
	assert_array(fills).is_empty()


func test_the_abandoned_notice_is_one_line_and_two_buttons() -> void:
	var screen: Screen = await _open("abandoned_sample", &"summary_abandoned")
	assert_array(RunUiRig.texts(screen)).contains([tr("summary.abandoned.player")])
	assert_array(_buttons(screen)).is_equal([tr("summary.new_run"), tr("summary.main_menu")])


func test_a_turn_one_concede_says_no_damage_dealt() -> void:
	# Edge Cases "damage_by_card is empty"
	var view: SummaryView = auto_free(SummaryView.new())
	add_child(view)
	view.show_summary(RunUiRig.config(), {
		"seed": "0", "headline": "", "outcome": "defeat", "hero_color": "war", "hero_initial": "W", "hero_name": "War",
		"reason": "", "floors_cleared": 0, "floors": 8, "matches": 1, "turns": 1, "duration": "", "custom_seed": false,
		"treasures": [], "unlocks": [], "status_line": "", "no_damage": true, "top_cards": [], "more_cards": 0, "cells": [], "deck_rows": [],
	})
	assert_array(RunUiRig.texts(view)).contains([tr("summary.no_damage")])


func test_ac31_every_base_screen_stays_on_screen_at_150_percent() -> void:
	for row: Array in SCREENS:
		# Arrange
		var loader: RunDebugLoader = RunDebugLoader.new()
		var overrides: Dictionary = loader.load_fixture(row[0])
		var meta: MetaApi = overrides.meta
		var _set: Error = meta.set_setting(&"text_scale", 1.5)
		_rig = await RunUiRig.start(self, meta, {})

		# Act
		loader.open(_rig.shell, row[1])
		await _rig.settle(3)

		# Assert
		_assert_fits(_rig.top(), "%s/%s" % [row[0], row[1]])
		_rig.finish()
		_rig = null


func test_ac31_the_stretch_settings_scale_the_design_to_every_window() -> void:
	assert_str(str(ProjectSettings.get_setting("display/window/stretch/mode"))).is_equal("canvas_items")
	assert_str(str(ProjectSettings.get_setting("display/window/stretch/aspect"))).is_equal("keep")
	assert_int(int(ProjectSettings.get_setting("display/window/size/viewport_width"))).is_equal(int(DESIGN.size.x))
	assert_int(int(ProjectSettings.get_setting("display/window/size/viewport_height"))).is_equal(int(DESIGN.size.y))


# Every visible control outside a scroll list lies in the design rect, and a one-line
# label is as wide as its text: the logic half of AC-31. A scroll list may run on.
func _assert_fits(root: Node, name: String) -> void:
	for node: Node in root.find_children("*", "Control", true, false):
		var control: Control = node
		if not control.is_visible_in_tree() or _in_scroll(control):
			continue
		var rect: Rect2 = control.get_global_rect().grow(-EDGE_PX)
		assert_bool(DESIGN.encloses(rect)).override_failure_message("%s: %s %s is off screen" % [name, control.get_class(), str(rect)]).is_true()
		if control is Label:
			var label: Label = control
			if label.autowrap_mode == TextServer.AUTOWRAP_OFF and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING and not label.clip_text:
				assert_float(label.size.x + EDGE_PX).override_failure_message("%s: '%s' is clipped" % [name, label.text]).is_greater_equal(label.get_minimum_size().x)


func _in_scroll(control: Control) -> bool:
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			return true
		parent = parent.get_parent()
	return false
