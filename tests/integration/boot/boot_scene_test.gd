## Integration: the boot scene (`run/main_scene`, test-rig exit item
## 2026-11-03) instantiates, shows its two labels with the expected text, and
## frees with no orphans. Loads the real `.tscn` through `SceneRunnerHelper`,
## so a broken hand-authored scene file fails here before CI's smoke does.
extends GdUnitTestSuite

const BOOT_SCENE := "res://src/scenes/boot.tscn"
const EXPECTED_TITLE := "Deckdelve — boot"
const EXPECTED_PROJECT_NAME := "Dungeon Run CCG"
const TITLE_PATH := NodePath("TitleLabel")
const BUILD_STAMP_PATH := NodePath("BuildStampLabel")


func test_project_main_scene_is_boot_scene() -> void:
	# Arrange / Act
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")

	# Assert
	assert_str(main_scene).is_equal(BOOT_SCENE)


func test_boot_scene_loads_with_both_labels() -> void:
	# Arrange / Act -- auto_free: a Node left alive is an orphan (gdUnit4 exit 101)
	var boot: Node = auto_free(await SceneRunnerHelper.load_scene_and_wait(self, BOOT_SCENE))

	# Assert
	assert_object(boot).is_not_null()
	assert_bool(boot is Control).is_true()
	assert_bool(boot is BootScreen).is_true()
	GameAssertions.assert_node_exists(boot, TITLE_PATH)
	GameAssertions.assert_node_exists(boot, BUILD_STAMP_PATH)
	assert_bool(boot.get_node(TITLE_PATH) is Label).is_true()
	assert_bool(boot.get_node(BUILD_STAMP_PATH) is Label).is_true()


func test_boot_scene_title_label_shows_boot_title() -> void:
	# Arrange
	var boot: Node = auto_free(await SceneRunnerHelper.load_scene_and_wait(self, BOOT_SCENE))

	# Act
	var title: Label = boot.get_node(TITLE_PATH) as Label

	# Assert
	assert_str(title.text).is_equal(EXPECTED_TITLE)


func test_boot_scene_build_stamp_names_project_and_engine_version() -> void:
	# Arrange
	var boot: BootScreen = auto_free(await SceneRunnerHelper.load_scene_and_wait(self, BOOT_SCENE))
	var version_string: String = str(Engine.get_version_info().get("string", ""))

	# Act
	var stamp: Label = boot.get_node(BUILD_STAMP_PATH) as Label

	# Assert
	assert_str(stamp.text).contains(EXPECTED_PROJECT_NAME)
	assert_str(stamp.text).contains(version_string)
	assert_str(stamp.text).is_equal(boot.build_stamp())


func test_boot_scene_frees_without_orphans() -> void:
	# Arrange -- no auto_free here: the test frees the scene itself
	var boot: Node = await SceneRunnerHelper.load_scene_and_wait(self, BOOT_SCENE)
	assert_bool(boot.is_inside_tree()).is_true()

	# Act
	boot.free()

	# Assert -- the orphan count in this suite's Statistics line must stay 0
	assert_bool(is_instance_valid(boot)).is_false()
	assert_bool(has_node(NodePath("BootScreen"))).is_false()
