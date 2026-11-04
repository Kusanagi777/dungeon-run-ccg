## Integration: how `tools/lint/parse-check.sh` turns one Godot run into a verdict.
##
## Godot on Windows sometimes dies with an access violation in shutdown, after
## the script under check has loaded and printed its `ok:` line. Bash reports that
## as exit 139. The load is proven by then, so the file passes, but the crash is
## printed; every other way of not proving the load still fails.
##
## `tests/fixtures/lint/fake_godot/godot` stands in for the engine, so each exit
## is forced rather than waited for. Needs `bash` on PATH.
extends GdUnitTestSuite

const PARSE_CHECK := "res://tools/lint/parse-check.sh"
const FAKE_GODOT := "res://tests/fixtures/lint/fake_godot/godot"
## Exit codes of `parse-check.sh`.
const EXIT_CLEAN := 0
const EXIT_FAILED := 1
## What bash reports for a segfault or a Windows access violation.
const EXIT_CRASH := 139


## Runs `parse-check.sh` over the fake engine; returns `{exit: int, text: String}`.
func _parse_check(fake_exit: int, prints_ok: bool) -> Dictionary:
	var output: Array = []
	var godot: String = _bash_path(ProjectSettings.globalize_path(FAKE_GODOT))
	var script_path: String = ProjectSettings.globalize_path(PARSE_CHECK)
	var command: String = 'GODOT="$1" FAKE_GODOT_EXIT="$2" FAKE_GODOT_OK="$3" exec "$BASH" "$4"'
	var code: int = OS.execute("bash", ["-c", command, "bash", godot, str(fake_exit), "1" if prints_ok else "0", script_path], output, true)
	return {"exit": code, "text": "\n".join(output)}


## `path` as Git Bash spells it: `C:/x` is `/c/x`. Any other path comes back unchanged.
func _bash_path(path: String) -> String:
	if path.length() > 1 and path[1] == ":":
		return "/" + path[0].to_lower() + path.substr(2)
	return path


func test_clean_exit_after_ok_line_passes_with_no_crash_reported() -> void:
	# Act
	var result: Dictionary = _parse_check(0, true)

	# Assert
	assert_int(result.exit).is_equal(EXIT_CLEAN)
	assert_str(result.text).contains(" 0 failed")
	assert_str(result.text).not_contains("crashed at exit")


func test_crash_after_ok_line_passes_and_reports_the_crash() -> void:
	# Act
	var result: Dictionary = _parse_check(EXIT_CRASH, true)

	# Assert
	assert_int(result.exit).is_equal(EXIT_CLEAN)
	assert_str(result.text).contains(" 0 failed")
	assert_str(result.text).contains("crashed at exit")


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
