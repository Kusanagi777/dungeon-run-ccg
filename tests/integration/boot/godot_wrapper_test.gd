## Integration: `tools/bin/godot`, the committed wrapper every lane runs Godot
## through (boot-composition-root story 010).
##
## Each test runs the real script through `OS.execute("bash", ...)`, with a stub
## written under `user://` in place of the engine, so resolution order, exit
## codes, the worktree key and the templates link are forced rather than waited
## for. `run.sh` strips every `godot` from PATH and unsets the wrapper's own
## variables first: this suite usually runs *under* the wrapper, and a developer's
## engine must not answer for a stub. Its `timeout` is a hang guard for a wrapper
## that loops, never a timing assertion.
##
## The two-worktree run and a real export are manual evidence (story Completion
## Notes): a gdUnit run cannot launch a second Godot with a different `APPDATA`
## reliably. Needs `bash` and `git` on PATH.
extends GdUnitTestSuite

const WRAPPER := "res://tools/bin/godot"
const WRAPPER_DIR := "res://tools/bin"
const PRINT_USER_DIR := "res://tools/ci/print_user_dir.gd"
const FIXTURE := "user://godot_wrapper_fixture/"
## Exit codes of the wrapper.
const EXIT_NOT_FOUND := 127
const EXIT_REFUSED := 2
const EXIT_NOT_ISOLATED := 1
## What `timeout` returns when the wrapper never finished.
const EXIT_HUNG := 124
## What bash reports for the TD-013 access violation.
const EXIT_CRASH := 139
const EXIT_OTHER := 3
const TEMPLATE_VERSION := "4.7.2.stable"
const TEMPLATE_FILES: Array[String] = ["windows_debug_x86_64.exe", "windows_release_x86_64.exe"]
## Story AC-1's grep: what a path of one machine looks like.
const USER_PROFILE_PATTERNS: Array[String] = ["/c/Users", "C:\\Users", "Downloads", "/home/"]
const RUN_SH := """#!/usr/bin/env bash
# run.sh <wrapper> <cwd> <path-head or -> [NAME=VALUE ...] -- [wrapper args ...]
wrapper="$1"; cwd="$2"; path_head="$3"; shift 3
assignments=()
while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do assignments+=("$1"); shift; done
shift
clean=""
IFS=: read -r -a dirs <<< "$PATH"
for d in "${dirs[@]}"; do
	if [ -n "$d" ] && [ ! -e "$d/godot" ] && [ ! -e "$d/godot.exe" ]; then clean="$clean:$d"; fi
done
if [ "$path_head" != "-" ]; then clean="$path_head$clean"; else clean="${clean#:}"; fi
cd "$cwd" || exit 90
exec env -u GODOT_BIN -u GODOT_USERDATA_ROOT -u GODOT_WORKTREE_KEY -u GODOT_WRAPPER_REAL_USERDATA \\
	"PATH=$clean" "${assignments[@]}" timeout 30 "$wrapper" "$@"
"""
## Filesystem steps GDScript cannot do. A script, not `bash -c`: OS.execute on
## Windows strips the `"` inside an argument, and these paths hold spaces.
const UTIL_SH := """#!/usr/bin/env bash
case "$1" in
	make-executable) chmod +x "$2" ;;
	# Links go first, so a walk of the tree never enters one; git's objects are read-only.
	prepare-removal) chmod -R u+w "$2"; find "$2" -type l -delete ;;
esac
"""
## Stands in for the engine. `{label}` says which stub ran; `{data_var}` is the
## variable that moves `user://` on this OS.
const STUB := """#!/usr/bin/env bash
case " $* " in
	*" --version "*) echo "4.7.2.stable.stub"; exit 0 ;;
	*print_user_dir*)
		echo "Godot Engine banner line"
		data="${{data_var}//\\\\//}"
		echo "${STUB_USER_DIR:-$data/app_userdata/Dungeon Run CCG}"
		exit 0 ;;
esac
if [ -z "${STUB_ARGS_ONLY:-}" ]; then
	echo "label={label}"
	echo "data=${{data_var}}"
fi
for a in "$@"; do echo "arg=$a"; done
exit "${STUB_EXIT:-0}"
"""


func before_test() -> void:
	_remove_fixture()
	DirAccess.make_dir_recursive_absolute(_path(""))
	_write("run.sh", RUN_SH)
	_write("util.sh", UTIL_SH)


func after_test() -> void:
	_remove_fixture()


## Removes everything this suite staged.
func _remove_fixture() -> void:
	var root: String = _path("")
	if not DirAccess.dir_exists_absolute(root):
		return
	_write("util.sh", UTIL_SH)
	_util("prepare-removal", root)
	_remove_tree(root)


func _util(step: String, path: String) -> void:
	OS.execute("bash", [_path("util.sh"), step, _bash_path(path)], [], true)


## An instance, not the static listings: those skip `.git`, which is hidden on Windows.
func _remove_tree(dir: String) -> void:
	var access: DirAccess = DirAccess.open(dir)
	access.include_hidden = true
	for sub: String in access.get_directories():
		_remove_tree(dir.path_join(sub))
	for file_name: String in access.get_files():
		DirAccess.remove_absolute(dir.path_join(file_name))
	DirAccess.remove_absolute(dir)


## An absolute path under the fixture, as Godot spells it.
func _path(relative: String) -> String:
	return ProjectSettings.globalize_path(FIXTURE).path_join(relative).trim_suffix("/")


## `path` as Git Bash spells it: `C:/x` is `/c/x`. Any other path comes back unchanged.
func _bash_path(path: String) -> String:
	if path.length() > 1 and path[1] == ":":
		return "/" + path[0].to_lower() + path.substr(2)
	return path


func _write(relative: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(_path(relative).get_base_dir())
	var file: FileAccess = FileAccess.open(_path(relative), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _is_windows() -> bool:
	return OS.get_name() == "Windows"


## The variable that moves `user://` on this OS.
func _data_var() -> String:
	return "APPDATA" if _is_windows() else "XDG_DATA_HOME"


## The folder Godot keeps its data in, under that variable.
func _engine_dir() -> String:
	return "Godot" if _is_windows() else "godot"


## Writes a stub called `name` in fixture folder `dir`; returns its Git Bash path.
func _stub(dir: String, label: String, name: String = "godot") -> String:
	var relative: String = dir.path_join(name)
	_write(relative, STUB.replace("{label}", label).replace("{data_var}", _data_var()))
	_util("make-executable", _path(relative))
	return _bash_path(_path(relative))


## Makes a git repository in fixture folder `dir`; returns its absolute path.
func _repo(dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(_path(dir))
	OS.execute("git", ["-C", _path(dir), "init", "-q"], [], true)
	return _path(dir)


## Runs `wrapper` from `cwd` with `path_head` before a PATH that holds no `godot`.
## The real `APPDATA` / `XDG_DATA_HOME` is `real/` and the root is `root/`, inside
## the fixture, unless `env` says otherwise. Returns `{exit: int, text: String}`.
func _run(cwd: String, path_head: String, env: Dictionary, args: Array[String] = [], wrapper: String = "") -> Dictionary:
	var merged: Dictionary = {"APPDATA": _path("real"), "XDG_DATA_HOME": _path("real"), "GODOT_USERDATA_ROOT": _path("root")}
	merged.merge(env, true)
	var wrapper_path: String = wrapper if not wrapper.is_empty() else _bash_path(ProjectSettings.globalize_path(WRAPPER))
	# `-`, never "": OS.execute on Windows drops an empty argument, which shifts the rest.
	var argv: Array[String] = [_path("run.sh"), wrapper_path, cwd, path_head if not path_head.is_empty() else "-"]
	for key: String in merged:
		argv.append("%s=%s" % [key, merged[key]])
	argv.append("--")
	argv.append_array(args)
	var output: Array = []
	var code: int = OS.execute("bash", argv, output, true)
	return {"exit": code, "text": "\n".join(output)}


## The value the stub printed for the variable that moves `user://`.
func _data_dir(text: String) -> String:
	for line: String in text.split("\n"):
		if line.begins_with("data="):
			return line.trim_prefix("data=").replace("\\", "/")
	return ""


## Writes the 4.7.2 template files under the fixture's real user-data location.
func _install_templates() -> void:
	for file_name: String in TEMPLATE_FILES:
		_write("real/%s/export_templates/%s/%s" % [_engine_dir(), TEMPLATE_VERSION, file_name], "template")


## A template file as seen through isolated directory `key`.
func _isolated_template(key: String) -> String:
	return _path("root/%s/%s/export_templates/%s/%s" % [key, _engine_dir(), TEMPLATE_VERSION, TEMPLATE_FILES[0]])


# --- AC-1: resolution --------------------------------------------------------


func test_godot_bin_wins_over_engine_path_and_path() -> void:
	# Arrange
	var repo: String = _repo("repo")
	_write("repo/project.local.yaml", 'engine:\n  path: "%s"\n' % _stub("local", "local"))
	_stub("onpath", "onpath")
	var env: Dictionary = {"GODOT_BIN": _stub("named", "named")}

	# Act
	var result: Dictionary = _run(repo, _bash_path(_path("onpath")), env)

	# Assert
	assert_str(result.text).contains("label=named")


func test_engine_path_in_local_yaml_wins_over_path() -> void:
	# Arrange
	var repo: String = _repo("repo")
	_write("repo/project.local.yaml", 'engine:\n  path: "%s"\n' % _stub("local", "local"))
	_stub("onpath", "onpath")

	# Act
	var result: Dictionary = _run(repo, _bash_path(_path("onpath")), {})

	# Assert
	assert_str(result.text).contains("label=local")


func test_engine_path_on_one_line_is_read() -> void:
	# Arrange
	var repo: String = _repo("repo")
	_write("repo/project.local.yaml", "engine.path: %s\n" % _stub("local", "local"))

	# Act
	var result: Dictionary = _run(repo, "", {})

	# Assert
	assert_str(result.text).contains("label=local")


func test_engine_path_from_the_main_checkout_serves_a_linked_worktree() -> void:
	# Arrange — project.local.yaml is gitignored, so a plain `git worktree add` has none
	var repo: String = _repo("repo")
	_write("repo/project.local.yaml", 'engine:\n  path: "%s"\n' % _stub("local", "local"))
	OS.execute("git", ["-C", repo, "-c", "user.name=t", "-c", "user.email=t@example.invalid", "commit", "-q", "--allow-empty", "-m", "fixture"], [], true)
	OS.execute("git", ["-C", repo, "worktree", "add", "-q", "--detach", _path("linked")], [], true)

	# Act
	var result: Dictionary = _run(_path("linked"), "", {})

	# Assert
	assert_str(result.text).contains("label=local")


func test_engine_path_in_committed_project_yaml_is_not_read() -> void:
	# Arrange
	var repo: String = _repo("repo")
	_write("repo/project.yaml", 'engine:\n  path: "%s"\n' % _stub("committed", "committed"))

	# Act
	var result: Dictionary = _run(repo, "", {})

	# Assert
	assert_int(result.exit).is_equal(EXIT_NOT_FOUND)


func test_next_godot_on_path_runs_and_the_wrapper_skips_itself() -> void:
	# Arrange
	var own_dir: String = _bash_path(ProjectSettings.globalize_path(WRAPPER_DIR))
	_stub("onpath", "onpath")

	# Act
	var result: Dictionary = _run(_repo("repo"), "%s:%s" % [own_dir, _bash_path(_path("onpath"))], {})

	# Assert
	assert_int(result.exit).is_equal(0)
	assert_str(result.text).contains("label=onpath")


func test_second_copy_of_the_wrapper_on_path_is_skipped_without_a_loop() -> void:
	# Arrange — two worktrees' tools/bin on one PATH: each copy would find the other
	var own_dir: String = _bash_path(ProjectSettings.globalize_path(WRAPPER_DIR))
	_write("copy/godot", FileAccess.get_file_as_string(WRAPPER))
	_util("make-executable", _path("copy/godot"))
	_stub("onpath", "onpath")
	var path_head: String = "%s:%s:%s" % [_bash_path(_path("copy")), own_dir, _bash_path(_path("onpath"))]

	# Act
	var result: Dictionary = _run(_repo("repo"), path_head, {})

	# Assert
	assert_int(result.exit).is_not_equal(EXIT_HUNG)
	assert_str(result.text).contains("label=onpath")


func test_godot_exe_on_path_runs() -> void:
	# Arrange
	_stub("onpath", "exe", "godot.exe")

	# Act
	var result: Dictionary = _run(_repo("repo"), _bash_path(_path("onpath")), {})

	# Assert
	assert_str(result.text).contains("label=exe")


func test_directories_named_like_the_engine_on_path_are_skipped() -> void:
	# Arrange — the Windows download unpacks to a folder whose name ends in `.exe`
	DirAccess.make_dir_recursive_absolute(_path("folders/godot"))
	DirAccess.make_dir_recursive_absolute(_path("folders/godot.exe"))
	_stub("onpath", "onpath")
	var path_head: String = "%s:%s" % [_bash_path(_path("folders")), _bash_path(_path("onpath"))]

	# Act
	var result: Dictionary = _run(_repo("repo"), path_head, {})

	# Assert
	assert_str(result.text).contains("label=onpath")


func test_nothing_to_run_exits_127_and_names_godot_bin() -> void:
	# Act
	var result: Dictionary = _run(_repo("repo"), "", {})

	# Assert
	assert_int(result.exit).is_equal(EXIT_NOT_FOUND)
	assert_str(result.text).contains("GODOT_BIN")


func test_godot_bin_naming_a_folder_exits_127_and_does_not_fall_through() -> void:
	# Arrange
	DirAccess.make_dir_recursive_absolute(_path("Godot_win64.exe"))
	_stub("onpath", "onpath")
	var env: Dictionary = {"GODOT_BIN": _bash_path(_path("Godot_win64.exe"))}

	# Act
	var result: Dictionary = _run(_repo("repo"), _bash_path(_path("onpath")), env)

	# Assert
	assert_int(result.exit).is_equal(EXIT_NOT_FOUND)
	assert_str(result.text).contains("GODOT_BIN")
	assert_str(result.text).not_contains("label=onpath")


func test_engine_path_naming_nothing_exits_127_and_names_the_file() -> void:
	# Arrange
	var repo: String = _repo("repo")
	_write("repo/project.local.yaml", "engine.path: %s\n" % _bash_path(_path("gone/godot")))
	_stub("onpath", "onpath")

	# Act
	var result: Dictionary = _run(repo, _bash_path(_path("onpath")), {})

	# Assert
	assert_int(result.exit).is_equal(EXIT_NOT_FOUND)
	assert_str(result.text).contains("project.local.yaml")


func test_exit_codes_pass_through_unchanged() -> void:
	# Arrange
	var repo: String = _repo("repo")
	var stub: String = _stub("named", "named")

	# Act + Assert
	for code: int in [0, EXIT_OTHER, EXIT_CRASH]:
		var result: Dictionary = _run(repo, "", {"GODOT_BIN": stub, "STUB_EXIT": str(code)})
		assert_int(result.exit).is_equal(code)


func test_output_and_arguments_pass_through_unchanged() -> void:
	# Arrange
	var env: Dictionary = {"GODOT_BIN": _stub("named", "named"), "STUB_ARGS_ONLY": "1"}
	var args: Array[String] = ["--headless", "res://a b/c.tscn", "tcp://127.0.0.1:0"]

	# Act
	var result: Dictionary = _run(_repo("repo"), "", env, args)

	# Assert — nothing of the wrapper's own, no reordering, no splitting on the space
	assert_str(result.text).is_equal("arg=--headless\narg=res://a b/c.tscn\narg=tcp://127.0.0.1:0\n")


# --- AC-2: isolation ---------------------------------------------------------


func test_data_variable_moves_to_root_and_key() -> void:
	# Arrange
	var env: Dictionary = {"GODOT_BIN": _stub("named", "named"), "GODOT_WORKTREE_KEY": "lane-a"}

	# Act
	var result: Dictionary = _run(_repo("repo"), "", env)

	# Assert
	assert_str(_data_dir(result.text)).is_equal(_path("root/lane-a"))
	assert_bool(DirAccess.dir_exists_absolute(_path("root/lane-a"))).is_true()


func test_two_worktree_keys_get_different_directories() -> void:
	# Arrange
	var repo: String = _repo("repo")
	var stub: String = _stub("named", "named")

	# Act
	var first: Dictionary = _run(repo, "", {"GODOT_BIN": stub, "GODOT_WORKTREE_KEY": "lane-a"})
	var second: Dictionary = _run(repo, "", {"GODOT_BIN": stub, "GODOT_WORKTREE_KEY": "lane-b"})

	# Assert
	assert_str(_data_dir(first.text)).is_not_equal(_data_dir(second.text))


func test_same_directory_name_in_different_parents_gets_different_keys() -> void:
	# Arrange
	var stub: String = _stub("named", "named")

	# Act
	var first: Dictionary = _run(_repo("a/wt"), "", {"GODOT_BIN": stub})
	var second: Dictionary = _run(_repo("b/wt"), "", {"GODOT_BIN": stub})

	# Assert
	assert_str(_data_dir(first.text)).starts_with(_path("root/wt-"))
	assert_str(_data_dir(second.text)).starts_with(_path("root/wt-"))
	assert_str(_data_dir(first.text)).is_not_equal(_data_dir(second.text))


func test_key_is_the_same_from_anywhere_in_one_worktree() -> void:
	# Arrange
	var repo: String = _repo("repo")
	DirAccess.make_dir_recursive_absolute(repo.path_join("sub"))
	var env: Dictionary = {"GODOT_BIN": _stub("named", "named")}

	# Act
	var top: Dictionary = _run(repo, "", env)
	var sub: Dictionary = _run(repo.path_join("sub"), "", env)

	# Assert
	assert_str(_data_dir(top.text)).starts_with(_path("root/repo-"))
	assert_str(_data_dir(top.text)).is_equal(_data_dir(sub.text))


func test_directory_outside_any_repository_still_gets_a_key() -> void:
	# Arrange
	DirAccess.make_dir_recursive_absolute(_path("plain"))
	var env: Dictionary = {"GODOT_BIN": _stub("named", "named"), "GIT_CEILING_DIRECTORIES": _path("")}

	# Act
	var result: Dictionary = _run(_path("plain"), "", env)

	# Assert
	assert_str(_data_dir(result.text)).starts_with(_path("root/plain-"))


func test_default_root_is_the_named_folder_under_temp() -> void:
	# Arrange
	var env: Dictionary = {"GODOT_BIN": _stub("named", "named"), "GODOT_USERDATA_ROOT": "", "TMPDIR": _bash_path(_path("temp"))}

	# Act
	var result: Dictionary = _run(_repo("repo"), "", env)

	# Assert
	assert_str(_data_dir(result.text)).starts_with(_path("temp/dungeon-run-ccg-userdata/repo-"))


func test_root_inside_the_repository_is_refused() -> void:
	# Arrange
	var repo: String = _repo("repo")
	var env: Dictionary = {"GODOT_BIN": _stub("named", "named"), "GODOT_USERDATA_ROOT": repo.path_join("userdata")}

	# Act
	var result: Dictionary = _run(repo, "", env)

	# Assert
	assert_int(result.exit).is_equal(EXIT_REFUSED)
	assert_str(result.text).contains("GODOT_USERDATA_ROOT")
	assert_str(result.text).not_contains("label=named")


func test_print_user_dir_script_prints_this_process_user_directory() -> void:
	# Arrange
	var output: Array = []
	var args: Array[String] = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", PRINT_USER_DIR]

	# Act
	OS.execute(OS.get_executable_path(), args, output, true, false)

	# Assert — the child inherits this process's APPDATA, so it names the same directory
	assert_str("\n".join(output)).contains(OS.get_user_data_dir())


# --- AC-3: templates and the self-check --------------------------------------


func test_real_templates_are_visible_inside_the_isolated_directory() -> void:
	# Arrange
	_install_templates()
	var env: Dictionary = {"GODOT_BIN": _stub("named", "named"), "GODOT_WORKTREE_KEY": "lane-a"}

	# Act
	_run(_repo("repo"), "", env)

	# Assert
	assert_bool(FileAccess.file_exists(_isolated_template("lane-a"))).is_true()


func test_empty_export_templates_folder_from_first_import_gives_way_to_the_link() -> void:
	# Arrange — Godot makes this folder on first import, before any template is installed
	DirAccess.make_dir_recursive_absolute(_path("root/lane-a/%s/export_templates" % _engine_dir()))
	_install_templates()
	var env: Dictionary = {"GODOT_BIN": _stub("named", "named"), "GODOT_WORKTREE_KEY": "lane-a"}

	# Act
	_run(_repo("repo"), "", env)

	# Assert
	assert_bool(FileAccess.file_exists(_isolated_template("lane-a"))).is_true()


func test_templates_folder_holding_files_is_left_alone() -> void:
	# Arrange
	_write("root/lane-a/%s/export_templates/kept.txt" % _engine_dir(), "kept")
	_install_templates()
	var env: Dictionary = {"GODOT_BIN": _stub("named", "named"), "GODOT_WORKTREE_KEY": "lane-a"}

	# Act
	_run(_repo("repo"), "", env)

	# Assert
	assert_bool(FileAccess.file_exists(_path("root/lane-a/%s/export_templates/kept.txt" % _engine_dir()))).is_true()
	assert_bool(FileAccess.file_exists(_isolated_template("lane-a"))).is_false()


func test_wrapper_under_a_wrapper_still_finds_the_real_templates() -> void:
	# Arrange — a child of an isolated Godot inherits the isolated APPDATA
	_install_templates()
	var isolated: String = _path("root/lane-a")
	var env: Dictionary = {
		"GODOT_BIN": _stub("named", "named"),
		"GODOT_WORKTREE_KEY": "lane-b",
		"APPDATA": isolated,
		"XDG_DATA_HOME": isolated,
		"GODOT_WRAPPER_REAL_USERDATA": _path("real"),
	}

	# Act
	_run(_repo("repo"), "", env)

	# Assert
	assert_bool(FileAccess.file_exists(_isolated_template("lane-b"))).is_true()


func test_self_check_prints_binary_version_user_dir_and_templates() -> void:
	# Arrange
	_install_templates()
	var stub: String = _stub("named", "named")
	var env: Dictionary = {"GODOT_BIN": stub, "GODOT_WORKTREE_KEY": "lane-a"}

	# Act
	var result: Dictionary = _run(_repo("repo"), "", env, ["--self-check"])

	# Assert
	assert_int(result.exit).is_equal(0)
	assert_str(result.text).contains("binary:")
	assert_str(result.text).contains(stub)
	assert_str(result.text).contains("version:   4.7.2.stable.stub")
	assert_str(result.text).contains("user dir:  %s" % _path("root/lane-a"))
	assert_str(result.text).contains("templates: visible")


func test_self_check_reports_missing_templates_without_failing() -> void:
	# Arrange
	var env: Dictionary = {"GODOT_BIN": _stub("named", "named"), "GODOT_WORKTREE_KEY": "lane-a"}

	# Act
	var result: Dictionary = _run(_repo("repo"), "", env, ["--self-check"])

	# Assert
	assert_int(result.exit).is_equal(0)
	assert_str(result.text).contains("templates: NOT VISIBLE")
	assert_str(result.text).contains("Manage Export Templates" if _is_windows() else "EXPORT_TEMPLATES=1 bash tools/setup.sh")


func test_self_check_fails_when_the_engine_ignored_the_isolation() -> void:
	# Arrange
	var env: Dictionary = {"GODOT_BIN": _stub("named", "named"), "STUB_USER_DIR": _path("shared/app_userdata/x")}

	# Act
	var result: Dictionary = _run(_repo("repo"), "", env, ["--self-check"])

	# Assert
	assert_int(result.exit).is_equal(EXIT_NOT_ISOLATED)
	assert_str(result.text).contains("NOT ISOLATED")


func test_self_check_with_nothing_to_run_still_reports_and_exits_127() -> void:
	# Act
	var result: Dictionary = _run(_repo("repo"), "", {"GODOT_WORKTREE_KEY": "lane-a"}, ["--self-check"])

	# Assert
	assert_int(result.exit).is_equal(EXIT_NOT_FOUND)
	assert_str(result.text).contains("binary:")
	assert_str(result.text).contains("GODOT_BIN")
	assert_str(result.text).contains(_path("root/lane-a"))


# --- The committed form ------------------------------------------------------


func test_wrapper_is_tracked_executable_and_lf() -> void:
	# Arrange
	var output: Array = []

	# Act — `bin/` is gitignored, so an un-ignore that goes missing shows here
	OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "ls-files", "-s", "tools/bin/godot"], output, true)

	# Assert
	assert_str("\n".join(output)).starts_with("100755 ")
	assert_int(FileAccess.get_file_as_bytes(WRAPPER).find(13)).is_equal(-1)


func test_no_user_profile_path_in_tools_config_or_test_docs() -> void:
	# Arrange
	var output: Array = []
	var args: Array[String] = ["-C", ProjectSettings.globalize_path("res://"), "ls-files", "-c", "-o", "--exclude-standard", "tools", "project.yaml", "tests/README.md"]
	OS.execute("git", args, output, true)
	var hits: Array[String] = []

	# Act
	for path: String in "\n".join(output).split("\n", false):
		var text: String = FileAccess.get_file_as_string("res://" + path)
		for pattern: String in USER_PROFILE_PATTERNS:
			if text.contains(pattern):
				hits.append("%s: %s" % [path, pattern])

	# Assert
	assert_array(hits).is_empty()
