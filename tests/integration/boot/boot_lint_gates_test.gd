## Integration: the grep gates G1–G6 (`tools/lint/gates.sh`) have been watched
## failing (story boot-composition-root/story-005 AC-4; ADR-0001 Decision 6 —
## "the gate script is run once against a deliberately broken file before it
## is trusted").
##
## Each fixture under `tests/fixtures/lint/<gate>/` is a miniature project tree
## (`src/` plus a `project.godot`) holding one planted violation of its gate and
## the must-not-hit lines beside it (excluded files, doc comments, injected
## stream calls, the planner's own coroutines). The suite runs the real script
## on each through `OS.execute` and asserts a non-zero exit, a hit line naming
## the gate, no hit on any must-not-hit file, and zero hits for every other
## gate; then it runs the script on the real tree and asserts exit 0.
##
## The fixtures sit behind a `.gdignore`, so Godot never imports them. The test
## writes nothing; the script only reads. Needs `bash` and ripgrep ≥ 14 on PATH
## (CI installs both, see `.github/workflows/tests.yml`).
extends GdUnitTestSuite

const GATES_SCRIPT := "res://tools/lint/gates.sh"
const FIXTURES := "res://tests/fixtures/lint/"
const PROJECT_ROOT := "res://"
const GATES: Array[String] = ["G1", "G2", "G2b", "G3", "G4", "G5", "G6"]
## Exit codes of `gates.sh`.
const EXIT_CLEAN := 0
const EXIT_HITS := 1
const EXIT_REFUSED := 2


## Runs `gates.sh <root>` with `env_path` as PATH (empty: inherit) and returns
## `{exit: int, text: String}` (stdout and stderr together).
func _run_gates(root: String, env_path: String = "") -> Dictionary:
	var output: Array = []
	var script_path: String = ProjectSettings.globalize_path(GATES_SCRIPT)
	var root_path: String = ProjectSettings.globalize_path(root)
	var code: int
	if env_path.is_empty():
		code = OS.execute("bash", [script_path, root_path], output, true)
	else:
		code = OS.execute("/usr/bin/env", ["PATH=" + env_path, "/bin/bash", script_path, root_path], output, true)
	return {"exit": code, "text": "\n".join(output)}


## Asserts that `gate` reported hits and every other gate reported none.
func _assert_only_gate_hits(text: String, gate: String) -> void:
	for other: String in GATES:
		if other == gate:
			assert_str(text).not_contains("%s hits: 0\n" % other)
		else:
			assert_str(text).contains("%s hits: 0\n" % other)


func test_g1_fixture_node_in_rules_fails_naming_g1() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "g1")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("G1 src/gameplay/minion_node.gd:2:")
	assert_str(result.text).not_contains("clean_planner.gd")
	_assert_only_gate_hits(result.text, "G1")


func test_g2_fixture_tree_access_fails_and_boot_gd_is_excluded() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "g2")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("G2 src/gameplay/board_walker.gd:6:")
	assert_str(result.text).not_contains("src/core/boot.gd")
	_assert_only_gate_hits(result.text, "G2")


func test_g2b_fixture_await_fails_in_gameplay_and_on_a_signal_in_ai() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "g2b")

	# Assert — the planner's own coroutines and boot.gd are not hits
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("G2b src/gameplay/slow_attack.gd:6:")
	assert_str(result.text).contains("G2b src/ai/tweening_planner.gd:6:")
	assert_str(result.text).not_contains("sliced_planner.gd")
	assert_str(result.text).not_contains("src/core/boot.gd")
	_assert_only_gate_hits(result.text, "G2b")


func test_g3_fixture_boot_reference_fails_but_doc_comments_and_root_types_do_not() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "g3")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("G3 src/gameplay/locator_user.gd:6:")
	assert_str(result.text).not_contains("documented_service.gd")
	assert_str(result.text).not_contains("src/core/services.gd")
	assert_str(result.text).not_contains("src/core/boot_result.gd")
	assert_str(result.text).not_contains("src/core/boot.gd")
	_assert_only_gate_hits(result.text, "G3")


func test_g4_fixture_second_autoload_fails_naming_it() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "g4")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("G4 project.godot:12: GameManager=")
	assert_str(result.text).not_contains("G4 project.godot:11:")
	assert_str(result.text).not_contains("config_version")
	_assert_only_gate_hits(result.text, "G4")


func test_g4_fixture_single_autoload_not_named_boot_fails() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "g4_wrong_name")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("G4 project.godot:7: GameManager=")
	assert_str(result.text).contains("G4 project.godot: no autoload named Boot")
	_assert_only_gate_hits(result.text, "G4")


func test_g5_fixture_state_type_and_widget_submit_fail_but_view_and_controller_do_not() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "g5")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("G5 src/ui/match/hand_widget.gd:5:")
	assert_str(result.text).contains("G5 src/ui/match/hand_widget.gd:9:")
	assert_str(result.text).not_contains("match_view.gd")
	assert_str(result.text).not_contains("match_controller.gd")
	_assert_only_gate_hits(result.text, "G5")


func test_g6_fixture_every_bare_global_rng_call_fails_but_stream_calls_do_not() -> void:
	# Arrange — lines 6-12 of shuffler.gd each hold one or more bare calls
	var result: Dictionary = _run_gates(FIXTURES + "g6")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	for line: int in range(6, 13):
		assert_str(result.text).contains("G6 src/gameplay/shuffler.gd:%d:" % line)
	assert_str(result.text).contains("G6 hits: 7\n")
	assert_str(result.text).not_contains("stream_user.gd")
	_assert_only_gate_hits(result.text, "G6")


func test_real_tree_passes_every_gate() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(PROJECT_ROOT)

	# Assert
	assert_int(result.exit).is_equal(EXIT_CLEAN)
	for gate: String in GATES:
		assert_str(result.text).contains("%s hits: 0\n" % gate)
	assert_str(result.text).contains("ripgrep 1")


func test_missing_ripgrep_refuses_with_exit_2() -> void:
	# Arrange — a PATH with no rg on it
	var empty_path: String = ProjectSettings.globalize_path(FIXTURES + "no_rg")

	# Act
	var result: Dictionary = _run_gates(PROJECT_ROOT, empty_path)

	# Assert
	assert_int(result.exit).is_equal(EXIT_REFUSED)
	assert_str(result.text).contains("ripgrep (rg) not found")
	assert_str(result.text).not_contains("hits: 0")


func test_ripgrep_older_than_14_refuses_with_exit_2() -> void:
	# Arrange — fake_rg13/rg prints "ripgrep 13.0.0"; /usr/bin:/bin for head/sed
	var path: String = ProjectSettings.globalize_path(FIXTURES + "fake_rg13") + ":/usr/bin:/bin"

	# Act
	var result: Dictionary = _run_gates(PROJECT_ROOT, path)

	# Assert
	assert_int(result.exit).is_equal(EXIT_REFUSED)
	assert_str(result.text).contains("ripgrep 13.0.0")
	assert_str(result.text).contains("needs ripgrep >= 14")
	assert_str(result.text).not_contains("hits: 0")
