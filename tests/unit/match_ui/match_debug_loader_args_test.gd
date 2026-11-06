## `MatchDebugLoader.from_args` and `Main.launches_match` (match-ui U11; story 022 AC-1,
## story 012). Pure argument parsing: no fixture is read.
extends GdUnitTestSuite

const PAUSE_SEQ: int = 203


func test_every_u11_form_parses_to_its_field() -> void:
	# Arrange
	var args := PackedStringArray([
		"--fixture=midgame_full_board", "--pose=hover:12", "--pause-at=%d" % PAUSE_SEQ,
		"--anim-speed=fast", "--ai-debug",
	])

	# Act
	var parsed: Dictionary = MatchDebugLoader.from_args(args)

	# Assert
	assert_dict(parsed).is_equal({
		"fixture": "midgame_full_board", "pose": "hover:12", "pause_at": PAUSE_SEQ,
		"anim_speed": "fast", "ai_debug": true,
	})


func test_no_arguments_give_the_documented_defaults() -> void:
	# Act / Assert
	assert_dict(MatchDebugLoader.from_args(PackedStringArray())).is_equal({
		"fixture": "", "pose": "", "pause_at": -1, "anim_speed": "", "ai_debug": false,
	})


func test_an_unknown_argument_changes_nothing() -> void:
	# Act
	var parsed: Dictionary = MatchDebugLoader.from_args(PackedStringArray(["--no-such=1", "--fixture=mulligan", "--ai-sync"]))

	# Assert
	assert_dict(parsed).is_equal({"fixture": "mulligan", "pose": "", "pause_at": -1, "anim_speed": "", "ai_debug": false})


func test_a_pose_keeps_every_colon_after_its_name() -> void:
	# Act / Assert: `focus:treasure:1` splits later, in `apply_pose`
	assert_str(str(MatchDebugLoader.from_args(PackedStringArray(["--pose=focus:treasure:1"])).pose)).is_equal("focus:treasure:1")


func test_each_anim_speed_label_passes_through() -> void:
	for label: String in ["instant", "fast", "normal"]:
		# Act / Assert
		assert_str(str(MatchDebugLoader.from_args(PackedStringArray(["--anim-speed=" + label])).anim_speed)).is_equal(label)


func test_a_fixture_argument_launches_a_match_in_a_debug_build_only() -> void:
	# Arrange
	var args: Array = ["--fixture=first_playable"]

	# Act / Assert
	assert_bool(Main.launches_match(args, true)).is_true()
	assert_bool(Main.launches_match(args, false)).is_false()


func test_no_fixture_argument_launches_no_match() -> void:
	# Act / Assert
	assert_bool(Main.launches_match([], true)).is_false()
	assert_bool(Main.launches_match(["--print-data-version", "--run-ui-fixture=x"], true)).is_false()
