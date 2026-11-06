## Integration: project scripts survive engine shutdown (TD-013).
##
## Godot 4.7.2's `GDScriptLanguage::finish()` walks its script list and reads the
## next node before it releases the current script. `GDScript::clear()` leaves
## `base` and `constants` set, so that release can free the next node when the
## current script owns the last reference to it. The walk then reads freed memory
## on every exit, and on Windows it dies with an access violation whenever the
## heap has unmapped that page (godotengine/godot#117975, fixed for 4.8 by
## godotengine/godot#117991, not in any 4.7.x).
##
## The repo-side guard: a script another script owns keeps a static reference to
## itself. `clear()` drops it when the walk reaches that script, so no other
## script's release can free it first.
##
## A clean exit proves nothing here, because the read only faults when the heap
## happens to unmap the page, so the first test checks the guard itself.
extends GdUnitTestSuite

const SOURCE_ROOT: String = "res://src/"
## The static var each owned script holds itself in.
const ANCHOR: StringName = &"_teardown_anchor"
## Printed at exit when a script never released its anchor.
const LEAK_MESSAGE: String = "resources still in use at exit"


## Every `.gd` file under [param dir], recursively.
func _scripts_under(dir: String) -> Array[Script]:
	var scripts: Array[Script] = []
	for file: String in DirAccess.get_files_at(dir):
		if file.get_extension() == "gd":
			scripts.append(load(dir.path_join(file)) as Script)
	for sub: String in DirAccess.get_directories_at(dir):
		scripts.append_array(_scripts_under(dir.path_join(sub)))
	return scripts


## The scripts in other files that [param script] keeps a reference to until it
## is destroyed: its base, and any script held in a constant. An inner class is
## also a constant but has no path, and it is left out: it is created after its
## outer class, so the walk has passed it before the outer class is released.
func _owned_scripts(script: Script) -> Array[Script]:
	var owned: Array[Script] = []
	var base: Script = script.get_base_script()
	if base != null:
		owned.append(base)
	for value: Variant in script.get_script_constant_map().values():
		if value is Script and not (value as Script).resource_path.is_empty():
			owned.append(value as Script)
	return owned


func test_every_script_another_script_owns_anchors_itself() -> void:
	# Arrange
	var problems: Array[String] = []

	# Act
	for script: Script in _scripts_under(SOURCE_ROOT):
		for owned: Script in _owned_scripts(script):
			if owned.get(ANCHOR) != owned:
				problems.append("%s owns %s, which does not hold itself in %s"
					% [script.resource_path, owned.resource_path, ANCHOR])

	# Assert
	assert_array(problems).is_empty()


func test_owned_scripts_finds_a_base_script() -> void:
	# Act
	var owned: Array[Script] = _owned_scripts(MetaStub)

	# Assert: the scan above is not passing because it found nothing.
	assert_array(owned).contains([MetaApi])


func test_game_exit_releases_every_anchor() -> void:
	# Arrange
	var output: Array = []
	var args: Array[String] = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--quit-after", "5"]

	# Act
	var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)

	# Assert
	assert_int(code).is_equal(0)
	assert_str("\n".join(output)).not_contains(LEAK_MESSAGE)
