## Automated smoke seed created by /test-setup.
##
## The automated half of the smoke gate: it checks that the project settings
## load, that gdUnit4 is enabled, and that the scene tree can create and free a
## node headlessly. It runs with every `-a res://tests` run, in CI too. The
## launch-based half is project.yaml `commands.smoke`, which launches
## run/main_scene (res://src/scenes/boot.tscn since 2026-11-03); the scene
## itself is covered by tests/integration/boot/boot_scene_test.gd.
extends GdUnitTestSuite

const EXPECTED_PROJECT_NAME := "Dungeon Run CCG"
const GDUNIT4_PLUGIN_CFG := "res://addons/gdUnit4/plugin.cfg"


func test_project_settings_load_expected_name() -> void:
	# Arrange / Act
	var project_name: String = ProjectSettings.get_setting("application/config/name", "")

	# Assert
	assert_str(project_name).is_equal(EXPECTED_PROJECT_NAME)


func test_gdunit4_plugin_is_enabled_in_project() -> void:
	# Arrange / Act
	var enabled: PackedStringArray = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())

	# Assert
	assert_bool(enabled.has(GDUNIT4_PLUGIN_CFG)).is_true()


func test_node_can_be_added_to_tree_and_freed() -> void:
	# Arrange -- auto_free: the root is freed after the test, and frees its child
	# with it; a Node left alive is an orphan (gdUnit4 exit 101).
	var root: Node = auto_free(Node.new())
	root.name = "SmokeRoot"
	add_child(root)

	# Act
	var child: Node = Node.new()
	child.name = "SmokeChild"
	root.add_child(child)

	# Assert
	assert_bool(root.is_inside_tree()).is_true()
	assert_bool(child.is_inside_tree()).is_true()
	assert_int(root.get_child_count()).is_equal(1)
