## Automated smoke seed created by /test-setup.
##
## There is no run/main_scene yet (unset until the first UI story), so the
## launch-based smoke in project.yaml `commands.smoke` cannot run. Until it can,
## this suite is the automated half of the smoke gate: it checks that the project
## settings load, that gdUnit4 is enabled, and that the scene tree can create and
## free a node headlessly. It runs with every `-a res://tests` run, in CI too.
## Replace entry 1 of critical-paths.md with a real main-scene check once one exists.
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
	# Arrange
	var runner: GdUnitSceneRunner = scene_runner(Node.new())
	var root: Node = runner.scene()

	# Act
	var child: Node = Node.new()
	child.name = "SmokeChild"
	root.add_child(child)
	await runner.simulate_frames(1)

	# Assert
	assert_bool(child.is_inside_tree()).is_true()
	assert_int(root.get_child_count()).is_equal(1)
