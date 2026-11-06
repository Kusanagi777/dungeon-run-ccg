## Integration: `MetaFacade` and engine shutdown (TD-013; godotengine/godot#117975). On
## 4.7.2 `GDScriptLanguage::finish()` reads the next script before it releases the
## current one, and a script's `base` keeps its parent alive, so releasing `MetaStub`
## freed `MetaApi`, the next list node. `MetaFacade` is a second subclass of `MetaApi`:
## it must not reopen that, and it now loads with the whole save and rules graph.
##
## `boot_script_teardown_test.gd` is the scan over `res://src/`; this suite pins the
## facade by name, and runs the real exit a clean run proves only statistically: several
## children, each composing a facade and quitting with it alive.
extends GdUnitTestSuite

const ANCHOR: StringName = &"_teardown_anchor"
const CHILD_SCRIPT: String = "res://tests/integration/meta_progression/facade_exit_main.gd"
const CHILD_RUNS: int = 4
const LEAK_MESSAGE: String = "resources still in use at exit"


func test_meta_facade_base_holds_itself_in_the_anchor() -> void:
	# Arrange
	var base: Script = (MetaFacade as Script).get_base_script()

	# Act / Assert
	assert_object(base).is_same(MetaApi)
	assert_object(base.get(ANCHOR)).is_same(base)


func test_meta_facade_owns_no_unanchored_script() -> void:
	# Arrange
	var constants: Dictionary = (MetaFacade as Script).get_script_constant_map()

	# Act
	var owned: Array = constants.values().filter(func(value: Variant) -> bool: return value is Script)

	# Assert: a script held in a constant would need its own anchor
	assert_array(owned).is_empty()


func test_process_with_a_live_facade_exits_clean_every_run() -> void:
	# Arrange
	var args: Array[String] = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", CHILD_SCRIPT]

	for run: int in CHILD_RUNS:
		var output: Array = []

		# Act
		var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)

		# Assert
		assert_int(code).override_failure_message("run %d: exit %d\n%s" % [run, code, "\n".join(output)]).is_equal(0)
		assert_str("\n".join(output)).not_contains(LEAK_MESSAGE)
