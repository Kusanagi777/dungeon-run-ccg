## Integration: how `tools/lint/parse-check.sh` turns one Godot run into a verdict.
##
## Any non-zero exit fails the file, including a crash after the `ok:` line: the
## load is proven by then, but a crash in shutdown is a bug of its own (TD-013, an
## access violation Windows reports to bash as exit 139), and it must not pass.
##
## `tests/fixtures/lint/fake_godot/godot` stands in for the engine, so each exit
## is forced rather than waited for. Needs `bash` on PATH.
extends GdUnitTestSuite

const PARSE_CHECK := "res://tools/lint/parse-check.sh"
const FAKE_GODOT := "res://tests/fixtures/lint/fake_godot/godot"
## Exit codes of `parse-check.sh`.
const EXIT_CLEAN := 0
const EXIT_FAILED := 1
## A script of each tier the check must load: a UI script reaches Godot's loader
## the same way, and nothing else proves it parses on its own.
const UI_AND_RULES_SCRIPTS: Array[String] = ["res://src/gameplay/match/rules_engine.gd", "res://src/ai/boss_ai.gd", "res://src/core/boot.gd", "res://src/ui/boot_screen.gd", "res://src/ui/match/match_view_state.gd"]
## What bash reports for a segfault or a Windows access violation.
const EXIT_CRASH := 139


## Runs `parse-check.sh` over the fake engine; returns `{exit: int, text: String}`.
func _parse_check(fake_exit: int, prints_ok: bool) -> Dictionary:
	var output: Array = []
	var godot: String = _bash_path(ProjectSettings.globalize_path(FAKE_GODOT))
	var script_path: String = ProjectSettings.globalize_path(PARSE_CHECK)
	var launcher: String = ProjectSettings.globalize_path("res://tests/fixtures/lint/launch/with_fake_godot.sh")
	var code: int = OS.execute("bash", [launcher, godot, str(fake_exit), "1" if prints_ok else "0", script_path], output, true)
	return {"exit": code, "text": "\n".join(output)}


## `path` as Git Bash spells it: `C:/x` is `/c/x`. Any other path comes back unchanged.
func _bash_path(path: String) -> String:
	if path.length() > 1 and path[1] == ":":
		return "/" + path[0].to_lower() + path.substr(2)
	return path


func test_every_tier_with_scripts_is_in_scope() -> void:
	# Act
	var result: Dictionary = _parse_check(0, true)

	# Assert — one real script per tier; src/ui joined after the wave 2 review
	for script: String in UI_AND_RULES_SCRIPTS:
		assert_str(result.text).contains("ok: %s" % script)


func test_clean_exit_after_ok_line_passes() -> void:
	# Act
	var result: Dictionary = _parse_check(0, true)

	# Assert
	assert_int(result.exit).is_equal(EXIT_CLEAN)
	assert_str(result.text).contains(" 0 failed")


func test_crash_after_ok_line_fails() -> void:
	# Act
	var result: Dictionary = _parse_check(EXIT_CRASH, true)

	# Assert
	assert_int(result.exit).is_equal(EXIT_FAILED)
	assert_str(result.text).contains("PARSE FAIL")
	assert_str(result.text).contains("godot exited 139")


func test_crash_before_ok_line_fails_because_the_load_is_unproven() -> void:
	# Act
	var result: Dictionary = _parse_check(EXIT_CRASH, false)

	# Assert
	assert_int(result.exit).is_equal(EXIT_FAILED)
	assert_str(result.text).contains("PARSE FAIL")


func test_other_nonzero_exit_after_ok_line_still_fails() -> void:
	# Act
	var result: Dictionary = _parse_check(1, true)

	# Assert
	assert_int(result.exit).is_equal(EXIT_FAILED)
	assert_str(result.text).contains("PARSE FAIL")
