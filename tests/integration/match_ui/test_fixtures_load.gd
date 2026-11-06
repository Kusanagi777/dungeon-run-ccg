## The fixture sweep (match-ui U11, O12; ADR-0009 Verification "Fixtures run the real engine";
## story 022 AC-2 to AC-4): every required fixture runs the real `MatchDriver` with nothing
## refused, ends in the state its name claims, and holds no view-state of its own.
extends GdUnitTestSuite

const ROOT: String = "res://tests/fixtures/match_ui/"
## Name to the router state it rests in. `targeting_stealth` opens on its own drag pose.
const REQUIRED: Dictionary = {
	"turn1_player": InputRouter.STATE_IDLE, "mulligan": InputRouter.STATE_MULLIGAN,
	"mulligan_satchel": InputRouter.STATE_MULLIGAN, "mulligan_discount": InputRouter.STATE_MULLIGAN,
	"first_playable": InputRouter.STATE_MULLIGAN, "hand_10": InputRouter.STATE_IDLE,
	"midgame_full_board": InputRouter.STATE_IDLE, "simultaneous_deaths": InputRouter.STATE_IDLE,
	"targeting_taunt": InputRouter.STATE_IDLE, "targeting_stealth": InputRouter.STATE_DRAGGING,
	"choice_discover": InputRouter.STATE_CHOICE_OPEN, "choice_choose_one": InputRouter.STATE_CHOICE_OPEN,
	"boss_intent_full": InputRouter.STATE_IDLE, "boss_intent_plan_changed": InputRouter.STATE_IDLE,
	"boss_intent_hidden": InputRouter.STATE_IDLE, "boss_turn_playback": InputRouter.STATE_IDLE,
	"fatigue_and_burn": InputRouter.STATE_IDLE, "divine_shield_hit": InputRouter.STATE_IDLE,
	"treasure_tray": InputRouter.STATE_IDLE, "match_end_victory": InputRouter.STATE_ENDED,
	"match_end_defeat": InputRouter.STATE_ENDED, "match_end_both_dead": InputRouter.STATE_ENDED,
	"match_end_concede": InputRouter.STATE_ENDED, "match_end_fault": InputRouter.STATE_ENDED,
}
const VARIANTS: Array[String] = [
	"turn1_player", "midgame_full_board", "hand_10", "boss_intent_full", "boss_turn_playback",
	"treasure_tray", "fatigue_and_burn",
]
const TS150_SUFFIX: String = "_ts150"
const TEXT_SCALE_FULL: float = 1.5
## The keys a fixture may hold, top level: nothing that could stand for a view-state.
const FIXTURE_KEYS: Array[String] = ["config", "profile", "commands", "pose"]
const VIEW_FIELDS: Array[String] = ["phase", "active_side", "pending_choice", "pending_mulligan", "feed_lines", "hand", "board", "health", "intent"]
const SHIELD_SEQ: int = 131
const FRAME_S: float = 1.0 / 60.0
const DIAG_PREFIX: String = "feed.diag."
const DRAWER_RECT := Rect2(0, 40, 300, 290)


func _fixture_body(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(ROOT + name + ".json"))


func _assert_runs(name: String, state: StringName) -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, name)
	await MatchViewHarness.frames(view)
	var loader: MatchDebugLoader = view.get("_loader")

	# Assert
	assert_object(loader).override_failure_message(name).is_not_null()
	assert_array(loader.rejections).override_failure_message(name).is_empty()
	assert_str(String(view.router().view_state())).override_failure_message(name).is_equal(String(state))
	assert_int(view.sync_failures).override_failure_message(name).is_equal(0)
	assert_array(MatchViewHarness.sync_lines(view)).override_failure_message(name).is_empty()
	view.router().intent(InputRouter.INTENT_CANCEL)
	MatchViewHarness.close(view)


func test_every_required_fixture_runs_clean_and_rests_where_its_name_says() -> void:
	for name: String in REQUIRED:
		await _assert_runs(name, REQUIRED[name])


func test_every_ts150_variant_runs_clean_and_rests_where_its_base_does() -> void:
	for name: String in VARIANTS:
		await _assert_runs(name + TS150_SUFFIX, REQUIRED[name])


func test_a_ts150_variant_is_its_base_with_the_profile_alone_changed() -> void:
	for name: String in VARIANTS:
		# Arrange
		var base: Dictionary = _fixture_body(name)
		var variant: Dictionary = _fixture_body(name + TS150_SUFFIX)

		# Assert
		assert_float(float(variant.profile.text_scale)).override_failure_message(name).is_equal(TEXT_SCALE_FULL)
		assert_str(str(variant.commands)).override_failure_message(name).is_equal(str(base.commands))
		assert_str(str(variant.config)).override_failure_message(name).is_equal(str(base.config))


func test_no_fixture_holds_a_view_state_field() -> void:
	for file: String in DirAccess.get_files_at(ROOT):
		if not file.ends_with(".json"):
			continue
		# Arrange
		var body: Dictionary = _fixture_body(file.get_basename())

		# Act / Assert
		for key: String in body:
			assert_array(FIXTURE_KEYS).override_failure_message("%s holds %s" % [file, key]).contains([key])
		for field: String in VIEW_FIELDS:
			assert_bool((body.config as Dictionary).has(field)).override_failure_message("%s config.%s" % [file, field]).is_false()


func test_a_name_outside_the_pattern_is_refused_before_any_file_is_read() -> void:
	# Arrange
	var boot: Node = auto_free(MatchViewHarness.fresh_boot())
	var loader := MatchDebugLoader.new(MatchViewHarness.immediate_planner(), boot)
	var out: Array = []

	# Act / Assert
	await assert_error(func() -> void: out.append(loader.load_fixture("../secrets"))).is_push_error("MatchDebugLoader: bad fixture name '../secrets'")
	assert_object(out[0]).is_null()


func test_a_missing_fixture_returns_null_with_its_reason() -> void:
	# Arrange
	var boot: Node = auto_free(MatchViewHarness.fresh_boot())
	var loader := MatchDebugLoader.new(MatchViewHarness.immediate_planner(), boot)
	var out: Array = []

	# Act / Assert
	await assert_error(func() -> void: out.append(loader.load_fixture("no_such_fixture"))).is_push_error("MatchDebugLoader: no fixture at %sno_such_fixture.json" % ROOT)
	assert_object(out[0]).is_null()


func test_an_unknown_pose_warns_and_leaves_the_view_alone() -> void:
	# Arrange
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
	var loader: MatchDebugLoader = view.get("_loader")

	# Act / Assert
	await assert_error(func() -> void: loader.apply_pose(view, "no_such:1")).is_push_warning("MatchDebugLoader: unknown pose 'no_such:1'")
	assert_str(String(view.router().view_state())).is_equal(String(InputRouter.STATE_IDLE))
	MatchViewHarness.close(view)


func test_anim_speed_overrides_the_setting_for_that_launch_only() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player", ["--anim-speed=fast"], {"anim_speed": "normal"})

	# Assert
	assert_str(String(view.get("_speed"))).is_equal("fast")
	assert_str(str(MatchViewHarness.meta(view).get_setting(&"anim_speed"))).is_equal("normal")
	MatchViewHarness.close(view)


func test_a_fixture_profile_never_reaches_the_stored_settings() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "turn1_player_ts150")

	# Assert: the launch shows it, the profile does not keep it
	assert_float(float((view.get("_settings") as Dictionary).text_scale)).is_equal(TEXT_SCALE_FULL)
	assert_float(float(MatchViewHarness.meta(view).get_setting(&"text_scale"))).is_equal(1.0)
	MatchViewHarness.close(view)


func test_o12_a_shield_pop_paused_shows_the_ring_and_no_number_on_its_target() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "divine_shield_hit", ["--pause-at=%d" % SHIELD_SEQ])
	for i: int in 60:
		MatchViewHarness.run(view, FRAME_S)
		await view.get_tree().process_frame

	# Assert
	assert_bool(view.queue().is_paused()).is_true()
	var bursting: int = 0
	for token: MinionToken in view.find_children("*", "MinionToken", true, false):
		if token.burst > 0.0:
			bursting += 1
	assert_int(bursting).is_equal(1)
	assert_array(view.find_children("*", "NumberPop", true, false)).is_empty()
	view.queue().skip_all()
	MatchViewHarness.close(view)


func test_ai_debug_opens_the_overlay_and_writes_diag_lines_in_muted_text() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "boss_turn_playback", ["--ai-debug"])
	var overlays: Array[Node] = view.find_children("*", "", true, false).filter(func(node: Node) -> bool: return node.get_script() != null and str(node.get_script().resource_path).ends_with("ai_debug_overlay.gd"))
	var diag: int = 0
	for line: Dictionary in view.view_state().feed_lines:
		if str(line.key).begins_with(DIAG_PREFIX):
			diag += 1

	# Assert
	assert_int(overlays.size()).is_equal(1)
	assert_object((overlays[0] as Control).get_global_rect()).is_equal(DRAWER_RECT)
	assert_int(diag).is_greater(0)
	assert_array(view.view_state().debug_buffer).is_not_empty()
	var line: Dictionary = {"key": DIAG_PREFIX + "ai_decision", "params": {}}
	assert_str(str(view.feed().call("_bbcode", line))).contains(view.ui_context().color("text_muted").to_html(false))
	MatchViewHarness.close(view)


func test_without_the_flag_no_diagnostic_reaches_the_feed() -> void:
	# Arrange / Act
	var view: MatchView = await MatchViewHarness.open(self, "boss_turn_playback")

	# Assert
	for line: Dictionary in view.view_state().feed_lines:
		assert_str(str(line.key)).not_contains(DIAG_PREFIX)
	assert_array(view.view_state().debug_buffer).is_empty()
	MatchViewHarness.close(view)
