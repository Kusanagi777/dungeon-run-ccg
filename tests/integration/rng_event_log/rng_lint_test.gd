## Integration: the no-global-RNG lint `tools/lint/no_global_rng.sh` (story
## rng-event-log/story-004; rng-event-log rule 7; ADR-0003 Decision 10(b) and
## its 2026-11-03 erratum). "Trusted once broken": the script is run headless
## through `OS.execute` against temporary fixture trees that this suite writes
## under `user://rng_lint_fixture/` and deletes after each test — one with a
## planted bare `randi()` under `src/gameplay/`, one clean tree holding only
## injected-stream calls — and finally against the real project tree.
##
## This file holds planted violations as string data, so the lint's own
## tests-scope skips it by path (see the script's TESTS_EXCLUDED list).
## Lives under `tests/integration/` because it writes files and runs a
## subprocess (sprint-2 QA plan note). Needs `bash` and ripgrep >= 14.
extends GdUnitTestSuite

const LINT_SCRIPT := "res://tools/lint/no_global_rng.sh"
const FIXTURE_ROOT := "user://rng_lint_fixture/"
const PROJECT_ROOT := "res://"
const EXIT_CLEAN := 0
const EXIT_HITS := 1
const EXIT_REFUSED := 2
## One line per forbidden form of the ADR-0003 erratum regex, in its order.
const OFFENDING_LINES: Array[String] = [
	"\tvar a: int = randi()",
	"\tvar b: float = randf()",
	"\tvar c: int = randi_range(1, 6)",
	"\tvar d: float = randf_range(0.0, 1.0)",
	"\tseed(42)",
	"\trandomize()",
	"\tdeck.shuffle()",
	"\tvar e: Variant = deck.pick_random()",
	"\tvar rng := RandomNumberGenerator.new()",
]
## Injected-stream calls rules code is required to make; never a hit.
const STREAM_LINES: Array[String] = [
	"\tvar a: float = stream.randf()",
	"\tvar b: int = stream.randi_range(1, 6)",
	"\tstream.shuffle(deck)",
	"\tvar c: int = _fork_seed(1)",
	"\trng.seed = 4",
]


func before_test() -> void:
	_remove_tree(ProjectSettings.globalize_path(FIXTURE_ROOT))


func after_test() -> void:
	_remove_tree(ProjectSettings.globalize_path(FIXTURE_ROOT))


## Deletes `dir` and everything under it (absolute path); no-op when absent.
func _remove_tree(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for sub: String in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	for file_name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file_name))
	DirAccess.remove_absolute(dir)


## Writes a `.gd` file at `rel_path` under the fixture `tree`, one entry of
## `body` per line inside a function, and returns the tree's absolute path.
func _write(tree: String, rel_path: String, body: Array[String]) -> String:
	var root: String = ProjectSettings.globalize_path(FIXTURE_ROOT + tree)
	var path: String = root.path_join(rel_path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var text: String = "extends RefCounted\n\n\nfunc run(stream: RefCounted, deck: Array, rng: RandomNumberGenerator) -> void:\n"
	text += "\n".join(body) + "\n"
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	file.store_string(text)
	file.close()
	return root


## Runs the lint on `root` (absolute) with `env_path` as PATH (empty: inherit).
func _lint(root: String, env_path: String = "") -> Dictionary:
	var output: Array = []
	var script_path: String = ProjectSettings.globalize_path(LINT_SCRIPT)
	var code: int
	if env_path.is_empty():
		code = OS.execute("bash", [script_path, root], output, true)
	else:
		code = OS.execute("/usr/bin/env", ["PATH=" + env_path, "/bin/bash", script_path, root], output, true)
	return {"exit": code, "text": "\n".join(output)}


func test_planted_randi_under_gameplay_fails_naming_file_and_line() -> void:
	# Arrange — line 5 of the written file is the body's first line
	var root: String = _write("offending", "src/gameplay/dealer.gd", [OFFENDING_LINES[0]])

	# Act
	var result: Dictionary = _lint(root)

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("no_global_rng src/gameplay/dealer.gd:5:")
	assert_str(result.text).contains("no_global_rng hits: 1\n")


func test_clean_tree_with_injected_stream_calls_passes() -> void:
	# Arrange
	var root: String = _write("clean", "src/gameplay/dealer.gd", STREAM_LINES)

	# Act
	var result: Dictionary = _lint(root)

	# Assert
	assert_int(result.exit).is_equal(EXIT_CLEAN)
	assert_str(result.text).contains("no_global_rng hits: 0\n")


func test_every_forbidden_form_is_a_hit() -> void:
	# Arrange
	var root: String = _write("every_form", "src/ai/boss_brain.gd", OFFENDING_LINES)

	# Act
	var result: Dictionary = _lint(root)

	# Assert — one hit per line, lines 5..13
	assert_int(result.exit).is_equal(EXIT_HITS)
	for i: int in OFFENDING_LINES.size():
		assert_str(result.text).contains("no_global_rng src/ai/boss_brain.gd:%d:" % (5 + i))
	assert_str(result.text).contains("no_global_rng hits: %d\n" % OFFENDING_LINES.size())


func test_ui_and_core_rng_are_outside_the_scope() -> void:
	# Arrange
	_write("excluded", "src/ui/title_screen.gd", OFFENDING_LINES)
	var root: String = _write("excluded", "src/core/rng/rng_stream.gd", OFFENDING_LINES)

	# Act
	var result: Dictionary = _lint(root)

	# Assert
	assert_int(result.exit).is_equal(EXIT_CLEAN)
	assert_str(result.text).contains("no_global_rng hits: 0\n")


func test_allow_list_is_the_run_machine_path_not_a_pattern() -> void:
	# Arrange — the allow-listed file and a sibling with the same call
	_write("allow", "src/gameplay/run/run_machine.gd", [OFFENDING_LINES[5]])
	var root: String = _write("allow", "src/gameplay/run/run_state.gd", [OFFENDING_LINES[5]])

	# Act
	var result: Dictionary = _lint(root)

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("no_global_rng src/gameplay/run/run_state.gd:5:")
	assert_str(result.text).not_contains("run_machine.gd")
	assert_str(result.text).contains("no_global_rng hits: 1\n")


func test_rules_test_using_global_rng_fails() -> void:
	# Arrange
	var root: String = _write("tests_scope", "tests/unit/match_rules/match_rules_draw_test.gd", [OFFENDING_LINES[6]])

	# Act
	var result: Dictionary = _lint(root)

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("no_global_rng tests/unit/match_rules/match_rules_draw_test.gd:5:")


func test_tests_scope_skips_comments_and_the_listed_rng_suites() -> void:
	# Arrange — a comment quoting a call, and the excluded engine-pin suite
	_write("tests_skip", "tests/unit/card_effects/spike_test.gd", ["\t# F4 example: draws randi_range(0, 7)"])
	var root: String = _write("tests_skip", "tests/unit/rng_event_log/rng_engine_pins_test.gd", OFFENDING_LINES)

	# Act
	var result: Dictionary = _lint(root)

	# Assert
	assert_int(result.exit).is_equal(EXIT_CLEAN)
	assert_str(result.text).contains("no_global_rng hits: 0\n")


func test_real_tree_has_no_global_rng_call() -> void:
	# Arrange / Act
	var result: Dictionary = _lint(ProjectSettings.globalize_path(PROJECT_ROOT))

	# Assert
	assert_int(result.exit).is_equal(EXIT_CLEAN)
	assert_str(result.text).contains("no_global_rng hits: 0\n")


func test_missing_ripgrep_refuses_with_exit_2() -> void:
	# Arrange — a PATH with no rg on it
	var root: String = _write("no_rg", "src/gameplay/dealer.gd", STREAM_LINES)

	# Act
	var result: Dictionary = _lint(root, ProjectSettings.globalize_path(FIXTURE_ROOT + "no_bin"))

	# Assert
	assert_int(result.exit).is_equal(EXIT_REFUSED)
	assert_str(result.text).contains("ripgrep (rg) not found")
	assert_str(result.text).not_contains("hits:")
