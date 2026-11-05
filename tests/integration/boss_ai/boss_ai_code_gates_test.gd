## Integration: the `src/ai` CI gates (`tools/ci/ai_code_gates.sh`) have been
## watched failing (story boss-ai-match-driver/story-012 A29 and AC-3; control
## manifest: "each gate is run once against a deliberately broken file before it
## is trusted").
##
## Each fixture under `tests/fixtures/lint/ai_*/` is a miniature tree with one
## planted violation of its rule and the must-not-hit lines beside it. The suite
## runs the real script on each through `OS.execute`, then on the real tree. The
## fixtures sit behind a `.gdignore`, so Godot never imports them; the script only
## reads. Needs `bash` and ripgrep >= 14 on PATH, as `boot_lint_gates_test.gd`.
extends GdUnitTestSuite

const GATE_SCRIPT := "res://tools/ci/ai_code_gates.sh"
const FIXTURES := "res://tests/fixtures/lint/"
const PROJECT_ROOT := "res://"
const RULES: Array[String] = ["AI-LITERAL", "AI-THREAD", "AI-EMIT", "AI-TREE", "AI-MAINLOOP", "AI-NODE", "AI-LOG"]
## Exit codes of `ai_code_gates.sh`.
const EXIT_CLEAN := 0
const EXIT_HITS := 1
const EXIT_REFUSED := 2


## Runs the script on [param root] with [param env_path] as PATH (empty: inherit):
## `{exit, text}`, stdout and stderr together.
func _run_gates(root: String, env_path: String = "") -> Dictionary:
	var output: Array = []
	var script_path: String = ProjectSettings.globalize_path(GATE_SCRIPT)
	var root_path: String = ProjectSettings.globalize_path(root)
	var code: int
	if env_path.is_empty():
		code = OS.execute("bash", [script_path, root_path], output, true)
	else:
		# Through bash, not /usr/bin/env: Windows cannot launch POSIX paths directly.
		code = OS.execute("bash", ["-c", 'PATH="$1" exec "$BASH" "$2" "$3"', "bash", env_path, script_path, root_path], output, true)
	return {"exit": code, "text": "\n".join(output)}


## Runs the script on [param root] with [param fake] in front of the inherited PATH.
func _run_gates_with(fake: String, root: String) -> Dictionary:
	var output: Array = []
	var entry: String = _path_entry(ProjectSettings.globalize_path(FIXTURES + fake))
	var script_path: String = ProjectSettings.globalize_path(GATE_SCRIPT)
	var root_path: String = ProjectSettings.globalize_path(root)
	var code: int = OS.execute("bash", ["-c", 'PATH="$1:$PATH" exec "$BASH" "$2" "$3"', "bash", entry, script_path, root_path], output, true)
	return {"exit": code, "text": "\n".join(output)}


## [param path] as a PATH entry: Git Bash spells `C:/x` as `/c/x`.
func _path_entry(path: String) -> String:
	if path.length() > 1 and path[1] == ":":
		return "/" + path[0].to_lower() + path.substr(2)
	return path


## Asserts [param rule] counted [param hits] and every other rule counted none.
func _assert_only_rule_hits(text: String, rule: String, hits: int) -> void:
	for other: String in RULES:
		assert_str(text).contains("%s hits: %d\n" % [other, hits if other == rule else 0])


func test_thread_outside_the_planner_tasks_fails_naming_its_rule() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_thread")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("AI-THREAD src/ui/loader.gd:5:")
	assert_str(result.text).not_contains("worker_pool_planner_task.gd")
	_assert_only_rule_hits(result.text, "AI-THREAD", 1)


func test_worker_thread_pool_outside_the_planner_tasks_fails_and_planner_task_is_no_exception() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_worker_pool")

	# Assert — `planner_task.gd` is the seam, not a `*_planner_task.gd`
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("AI-THREAD src/gameplay/run/driver.gd:4:")
	assert_str(result.text).contains("AI-THREAD src/ai/planner_task.gd:4:")
	_assert_only_rule_hits(result.text, "AI-THREAD", 2)


func test_a_signal_emit_fails_but_the_seam_and_engine_emit_do_not() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_emit")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("AI-EMIT src/ai/signalling.gd:7:")
	assert_str(result.text).contains("AI-EMIT src/ai/signalling.gd:8:")
	assert_str(result.text).not_contains("time_sliced_planner_task.gd")
	assert_str(result.text).not_contains("harness.gd")
	_assert_only_rule_hits(result.text, "AI-EMIT", 2)


func test_get_tree_fails_naming_its_rule() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_get_tree")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("AI-TREE src/ai/tree_walker.gd:5:")
	_assert_only_rule_hits(result.text, "AI-TREE", 1)


func test_get_main_loop_fails_naming_its_rule() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_main_loop")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("AI-MAINLOOP src/ai/looper.gd:4:")
	_assert_only_rule_hits(result.text, "AI-MAINLOOP", 1)


func test_extends_node_fails_naming_its_rule() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_extends_node")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("AI-NODE src/ai/node_brain.gd:1:")
	_assert_only_rule_hits(result.text, "AI-NODE", 1)


func test_log_append_fails_on_every_log_with_no_scratch_exception() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_log_append")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("AI-LOG src/ai/logger.gd:8:")
	assert_str(result.text).contains("AI-LOG src/ai/logger.gd:9:")
	_assert_only_rule_hits(result.text, "AI-LOG", 2)


func test_every_spelling_of_a_planted_literal_fails_naming_its_rule() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_literal")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	for line: int in [4, 5, 8, 9, 10, 11, 12]:
		assert_str(result.text).contains("AI-LITERAL src/ai/hardcoded.gd:%d:" % line)
	assert_str(result.text).not_contains("hardcoded.gd:1:")
	_assert_only_rule_hits(result.text, "AI-LITERAL", 7)


func test_a_named_constant_of_a_bare_number_fails_even_at_zero_or_one() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_literal_const")

	# Assert
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("AI-LITERAL src/ai/named.gd:3:")
	assert_str(result.text).contains("AI-LITERAL src/ai/named.gd:4:")
	_assert_only_rule_hits(result.text, "AI-LITERAL", 2)


func test_tables_strings_comments_and_indices_pass() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_clean")

	# Assert
	assert_int(result.exit).is_equal(EXIT_CLEAN)
	for rule: String in RULES:
		assert_str(result.text).contains("%s hits: 0\n" % rule)


func test_a_pinned_name_at_another_value_fails() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_pin_value")

	# Assert — the review's `UNPRICED = 0.75`, and the two rules it kept
	assert_int(result.exit).is_equal(EXIT_HITS)
	assert_str(result.text).contains("AI-LITERAL src/ai/lethal_search.gd:3:")
	assert_str(result.text).contains("AI-LITERAL src/ai/lethal_search.gd:4:")
	assert_str(result.text).contains("AI-LITERAL src/ai/scorer.gd:3:")
	assert_str(result.text).contains("AI-LITERAL src/ai/boss_ai.gd:3:")
	_assert_only_rule_hits(result.text, "AI-LITERAL", 4)


func test_a_pinned_name_or_table_in_another_file_fails() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_pin_file")

	# Assert — right name, right value, wrong file; a constant list of 0 and 1 too
	assert_int(result.exit).is_equal(EXIT_HITS)
	for line: int in [3, 4, 5, 7, 9]:
		assert_str(result.text).contains("AI-LITERAL src/ai/elsewhere.gd:%d:" % line)
	_assert_only_rule_hits(result.text, "AI-LITERAL", 5)


func test_a_new_or_changed_row_of_a_pinned_table_fails() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(FIXTURES + "ai_pin_rows")

	# Assert — a new key even at 1.0; a changed value; a changed range bound
	assert_int(result.exit).is_equal(EXIT_HITS)
	for line: int in [5, 6, 7]:
		assert_str(result.text).contains("AI-LITERAL src/ai/scorer.gd:%d:" % line)
	assert_str(result.text).not_contains("AI-LITERAL src/ai/scorer.gd:4:")
	assert_str(result.text).contains("AI-LITERAL src/ai/boss_ai.gd:4:")
	_assert_only_rule_hits(result.text, "AI-LITERAL", 4)


func test_real_tree_passes_every_rule() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates(PROJECT_ROOT)

	# Assert
	assert_int(result.exit).is_equal(EXIT_CLEAN)
	for rule: String in RULES:
		assert_str(result.text).contains("%s hits: 0\n" % rule)
	assert_str(result.text).contains("ripgrep 1")


func test_a_root_with_no_src_ai_refuses_with_exit_2() -> void:
	# Arrange — a tree that exists but holds no planner: nothing was checked
	var root: String = FIXTURES + "g4"

	# Act
	var result: Dictionary = _run_gates(root)

	# Assert
	assert_int(result.exit).is_equal(EXIT_REFUSED)
	assert_str(result.text).contains("src/ai")
	assert_str(result.text).not_contains("hits: 0")


func test_a_src_ai_with_no_script_refuses_with_exit_2() -> void:
	# Arrange / Act — the directory exists and there is nothing in it to check
	var result: Dictionary = _run_gates(FIXTURES + "ai_empty")

	# Assert
	assert_int(result.exit).is_equal(EXIT_REFUSED)
	assert_str(result.text).contains("no .gd file under src/ai")
	assert_str(result.text).not_contains("hits:")


func test_an_rg_error_listing_the_files_refuses_with_exit_2() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates_with("fake_rg_fails", FIXTURES + "ai_thread")

	# Assert
	assert_int(result.exit).is_equal(EXIT_REFUSED)
	assert_str(result.text).contains("rg --files exited 2")
	assert_str(result.text).not_contains("hits:")


func test_an_rg_error_in_a_rule_refuses_with_exit_2_and_prints_no_count() -> void:
	# Arrange / Act — the literal scan is clean, then every search errors
	var result: Dictionary = _run_gates_with("fake_rg_search_fails", FIXTURES + "ai_thread")

	# Assert
	assert_int(result.exit).is_equal(EXIT_REFUSED)
	assert_str(result.text).contains("AI-THREAD: could not run")
	assert_str(result.text).not_contains("hits:")


func test_an_awk_error_refuses_with_exit_2_and_prints_no_count() -> void:
	# Arrange / Act
	var result: Dictionary = _run_gates_with("fake_awk_fails", FIXTURES + "ai_clean")

	# Assert
	assert_int(result.exit).is_equal(EXIT_REFUSED)
	assert_str(result.text).contains("AI-LITERAL: could not run")
	assert_str(result.text).not_contains("hits:")


func test_missing_ripgrep_refuses_with_exit_2() -> void:
	# Arrange — a PATH with no rg on it
	var empty_path: String = _path_entry(ProjectSettings.globalize_path(FIXTURES + "no_rg"))

	# Act
	var result: Dictionary = _run_gates(PROJECT_ROOT, empty_path)

	# Assert
	assert_int(result.exit).is_equal(EXIT_REFUSED)
	assert_str(result.text).contains("ripgrep (rg) not found")
	assert_str(result.text).not_contains("hits: 0")


func test_ripgrep_older_than_14_refuses_with_exit_2() -> void:
	# Arrange — fake_rg13/rg prints "ripgrep 13.0.0"; /usr/bin:/bin for head/sed
	var path: String = _path_entry(ProjectSettings.globalize_path(FIXTURES + "fake_rg13")) + ":/usr/bin:/bin"

	# Act
	var result: Dictionary = _run_gates(PROJECT_ROOT, path)

	# Assert
	assert_int(result.exit).is_equal(EXIT_REFUSED)
	assert_str(result.text).contains("ripgrep 13.0.0")
	assert_str(result.text).contains("needs ripgrep >= 14")
	assert_str(result.text).not_contains("hits: 0")
