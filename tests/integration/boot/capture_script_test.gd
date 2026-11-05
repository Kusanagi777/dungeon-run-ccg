## Integration: `tools/capture.sh`, the screenshot rig, on both of its branches
## (boot-composition-root story 011; ADR-0010 Decisions 3 to 5, DD-X32).
##
## Each test runs the real script through `OS.execute("bash", ...)` with stubs on
## `PATH`, so nothing here opens a window: `uname` picks the branch whatever the host
## is, `xvfb-run` records its command, and a stub engine stands where Godot does,
## through `GODOT_BIN` on the Windows branch (behind the real `tools/bin/godot`) and as
## `godot` on `PATH` on the Linux one. The stub copies frames written by [method
## _write_frames], so the kept frame, the sidecar and the blank check run for real.
##
## A real capture is manual evidence, in
## `production/qa/evidence/story-011-windows-screenshot-capture/`. **The Linux tests
## here are not AC-3's evidence**: they pin the launch line and the exit codes on
## whatever host runs the suite, and only a Linux host can answer AC-3.
##
## Needs `bash` and a `python3` that starts on `PATH`: the blank check is the real one.
## `timeout` in `run.sh` is a hang guard, never a timing assertion.
extends GdUnitTestSuite

const CAPTURE := "res://tools/capture.sh"
const FIXTURE := "user://capture_script_fixture/"
const SCENE := "res://src/scenes/boot.tscn"
const SCENE_FRAME := "01-boot.png"
const SCENE_SIDECAR := "01-boot.renderer.txt"
const FRAMES_DEFAULT := "60"
const RESOLUTION := "1280x720"
## What `uname -s` answers on each side of the branch.
const UNAME_WINDOWS := "MINGW64_NT-10.0-26100"
const UNAME_CYGWIN := "CYGWIN_NT-10.0-26100"
const UNAME_LINUX := "Linux"
## The renderer lines each branch's engine stub prints. The Linux line is the one
## `production/qa/evidence/story-006-main-scene-composition-entry/README.md` retained.
const BANNER_WINDOWS := "D3D12 12_0 - Forward+ - Using Device #0: Stub - Stub GPU"
const BANNER_OPENGL := "OpenGL API 3.3 Stub - Compatibility - Using Device: Stub - Stub GPU"
const BANNER_LINUX := "OpenGL API 4.5 (Core Profile) Mesa 25.2.8 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)"
const LINUX_RENDERER_LINE := "xvfb / opengl3 / llvmpipe"
const XVFB_SCREEN := "-screen 0 1280x720x24"
## The capture's exit codes (`tools/capture.sh` header).
const EXIT_OK := 0
const EXIT_USAGE := 2
const EXIT_GODOT := 3
const EXIT_BLANK := 4
## The forwarded arguments of MUI-004's capture: `--ai-sync` selects the planner, in
## `Boot.driver_factory`, from `OS.get_cmdline_user_args()` (story 009).
const USER_ARGS: Array[String] = ["--fixture=turn1_player", "--ai-sync"]
const RUN_SH := """#!/usr/bin/env bash
# run.sh <capture> <cwd> <path-head> <stdout-file> <stderr-file> [NAME=VALUE ...] -- [capture args ...]
capture="$1"; cwd="$2"; path_head="$3"; out="$4"; err="$5"; shift 5
assignments=()
while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do assignments+=("$1"); shift; done
shift
clean=""
IFS=: read -r -a dirs <<< "$PATH"
for d in "${dirs[@]}"; do
	if [ -n "$d" ] && [ ! -e "$d/godot" ] && [ ! -e "$d/godot.exe" ]; then clean="$clean:$d"; fi
done
cd "$cwd" || exit 90
exec env -u GODOT_BIN -u GODOT_USERDATA_ROOT -u GODOT_WORKTREE_KEY -u GODOT_WRAPPER_REAL_USERDATA \\
	-u CAPTURE_LABEL -u CAPTURE_RENDERER -u MSYS_NO_PATHCONV \\
	"PATH=$path_head$clean" "${assignments[@]}" timeout 60 bash "$capture" "$@" > "$out" 2> "$err"
"""
## Filesystem steps GDScript cannot do. A script, not `bash -c`: OS.execute on
## Windows strips the `"` inside an argument, and these paths hold spaces.
const UTIL_SH := """#!/usr/bin/env bash
case "$1" in
	make-executable) chmod +x "$2" ;;
esac
"""
## Stands in for the engine: records how it was started, copies `STUB_FRAMES` where
## `--write-movie` points, and prints the banner with the CRLF a Windows console has.
const ENGINE_STUB := """#!/usr/bin/env bash
{
	echo "ran=engine"
	echo "cwd=$PWD"
	echo "pathconv=${MSYS_NO_PATHCONV:-unset}"
	echo "data=${APPDATA:-}"
	echo "xdg=${XDG_DATA_HOME:-}"
	for a in "$@"; do echo "arg=$a"; done
} >> "$STUB_LOG"
movie=""
while [ "$#" -gt 0 ]; do
	if [ "$1" = "--write-movie" ]; then movie="$2"; fi
	shift
done
if [ -n "${STUB_FRAMES:-}" ] && [ -n "$movie" ]; then cp "$STUB_FRAMES"/*.png "${movie%/*}/"; fi
if [ -n "${STUB_BANNER:-}" ]; then printf '%s\\r\\n' "$STUB_BANNER"; fi
if [ -n "${STUB_ERR:-}" ]; then printf '%s\\n' "$STUB_ERR" >&2; fi
exit "${STUB_EXIT:-0}"
"""
## Records the command and runs what follows `-a -s <screen>`.
const XVFB_STUB := """#!/usr/bin/env bash
echo "ran=xvfb-run" >> "$STUB_LOG"
for a in "$@"; do echo "xvfb-arg=$a" >> "$STUB_LOG"; done
shift 3
exec "$@"
"""
const UNAME_STUB := """#!/usr/bin/env bash
echo "$STUB_UNAME"
"""
## Only on a non-Windows host, where no `cygpath` exists: the last argument unchanged.
const CYGPATH_STUB := """#!/usr/bin/env bash
echo "${@: -1}"
"""
## A Python that does not start, as the Microsoft Store alias does when no Store
## Python is installed.
const PYTHON_BROKEN := """#!/usr/bin/env bash
exit 9
"""
## A Python that starts and records that it ran the blank check, with what arguments.
const PYTHON_WORKING := """#!/usr/bin/env bash
case " $* " in
	*" -c "*) exit 0 ;;
esac
echo "python={label} $*" >> "$STUB_LOG"
cat > /dev/null
exit 0
"""


func before_test() -> void:
	_remove_fixture()
	DirAccess.make_dir_recursive_absolute(_path(""))
	_write("run.sh", RUN_SH)
	_write("util.sh", UTIL_SH)
	_tool("bin", "uname", UNAME_STUB)
	_tool("bin", "xvfb-run", XVFB_STUB)
	if OS.get_name() != "Windows":
		_tool("bin", "cygpath", CYGPATH_STUB)
	_tool("engine", "godot", ENGINE_STUB)
	_tool("linuxbin", "godot", ENGINE_STUB)
	_write_frames(false)


func after_test() -> void:
	_remove_fixture()


func _remove_fixture() -> void:
	var root: String = _path("")
	if DirAccess.dir_exists_absolute(root):
		_remove_tree(root)


## An instance, not the static listings: those skip hidden entries.
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


func _read(relative: String) -> String:
	return FileAccess.get_file_as_string(_path(relative))


## Writes an executable called `name` in fixture folder `dir`.
func _tool(dir: String, name: String, body: String) -> void:
	var relative: String = dir.path_join(name)
	_write(relative, body)
	OS.execute("bash", [_path("util.sh"), "make-executable", _bash_path(_path(relative))], [], true)


## The repository root, as Godot spells it.
func _repo_root() -> String:
	return ProjectSettings.globalize_path("res://").trim_suffix("/")


## Writes two frames: `f00000000.png` is always one colour; `f00000001.png`, the one
## to keep, has a second colour unless [param blank].
func _write_frames(blank: bool) -> void:
	DirAccess.make_dir_recursive_absolute(_path("frames"))
	var flat: Image = Image.create(4, 4, false, Image.FORMAT_RGB8)
	flat.fill(Color.BLACK)
	flat.save_png(_path("frames/f00000000.png"))
	if not blank:
		flat.set_pixel(1, 1, Color.WHITE)
	flat.save_png(_path("frames/f00000001.png"))


## Runs the capture with `uname` answering [param uname], from [param cwd] (the
## fixture when empty). `env` wins over the defaults, which give the stub engine.
## Returns `{exit: int, stdout: String, stderr: String}`.
func _run(uname: String, env: Dictionary, args: Array[String], path_head: String = "", cwd: String = "") -> Dictionary:
	var merged: Dictionary = {
		"STUB_UNAME": uname,
		"STUB_LOG": _bash_path(_path("stub.log")),
		"STUB_FRAMES": _bash_path(_path("frames")),
		"GODOT_BIN": _bash_path(_path("engine/godot")),
		"GODOT_USERDATA_ROOT": _path("root"),
		"APPDATA": _path("real"),
		"XDG_DATA_HOME": _path("real"),
	}
	merged.merge(env, true)
	var head: String = _bash_path(_path("bin"))
	if not path_head.is_empty():
		head = path_head + ":" + head
	var argv: Array[String] = [
		_path("run.sh"), _bash_path(ProjectSettings.globalize_path(CAPTURE)),
		cwd if not cwd.is_empty() else _path(""), head,
		_bash_path(_path("stdout.txt")), _bash_path(_path("stderr.txt")),
	]
	for key: String in merged:
		argv.append("%s=%s" % [key, merged[key]])
	argv.append("--")
	argv.append_array(args)
	var code: int = OS.execute("bash", argv, [], true)
	return {"exit": code, "stdout": _read("stdout.txt"), "stderr": _read("stderr.txt")}


## The Windows branch, on the rig-check form unless `args` is given.
func _run_windows(env: Dictionary = {}, args: Array[String] = [], path_head: String = "", cwd: String = "") -> Dictionary:
	var merged: Dictionary = {"STUB_BANNER": BANNER_WINDOWS}
	merged.merge(env, true)
	var given: Array[String] = args if not args.is_empty() else _rig_check()
	return _run(UNAME_WINDOWS, merged, given, path_head, cwd)


## The Linux branch: the engine stub is `godot` on `PATH`, and no `GODOT_BIN` is used.
func _run_linux(env: Dictionary = {}, args: Array[String] = [], cwd: String = "") -> Dictionary:
	var merged: Dictionary = {"STUB_BANNER": BANNER_LINUX}
	merged.merge(env, true)
	var given: Array[String] = args if not args.is_empty() else _rig_check()
	return _run(UNAME_LINUX, merged, given, _bash_path(_path("linuxbin")), cwd)


## The script header's rig-check form: `<scene> <out-dir> 60`.
func _rig_check() -> Array[String]:
	return [SCENE, _bash_path(_path("out")), FRAMES_DEFAULT]


## The rig-check form with arguments after a literal `--`.
func _with_user_args() -> Array[String]:
	var args: Array[String] = _rig_check()
	args.append("--")
	args.append_array(USER_ARGS)
	return args


## Every value the stub logged under `prefix=`, in order.
func _logged(prefix: String) -> Array[String]:
	var found: Array[String] = []
	for line: String in _read("stub.log").split("\n"):
		if line.begins_with(prefix + "="):
			found.append(line.trim_prefix(prefix + "=").strip_edges())
	return found


## The arguments the engine stub received.
func _engine_args() -> Array[String]:
	return _logged("arg")


## The value that followed `flag` on the engine's command line, or "".
func _engine_arg_after(flag: String) -> String:
	var args: Array[String] = _engine_args()
	var at: int = args.find(flag)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else ""


## What is left in the output folder, hidden entries included, sorted.
func _out_entries() -> Array[String]:
	var entries: Array[String] = []
	var access: DirAccess = DirAccess.open(_path("out"))
	if access == null:
		return entries
	access.include_hidden = true
	for name: String in access.get_files():
		entries.append(name)
	for name: String in access.get_directories():
		entries.append(name)
	entries.sort()
	return entries


func _sidecar() -> String:
	return _read("out/" + SCENE_SIDECAR)


## The last non-empty line of [param text].
func _last_line(text: String) -> String:
	var lines: PackedStringArray = text.strip_edges().split("\n")
	return lines[lines.size() - 1].strip_edges()


# --- AC-1: the Windows launch ------------------------------------------------


func test_windows_run_launches_no_xvfb_and_keeps_the_frame_under_the_linux_name() -> void:
	# Act
	var result: Dictionary = _run_windows()

	# Assert
	assert_int(result.exit).is_equal(EXIT_OK)
	assert_array(_logged("ran")).is_equal(["engine"])
	assert_bool(FileAccess.file_exists(_path("out/" + SCENE_FRAME))).is_true()
	assert_str(_last_line(result.stdout)).ends_with("/out/" + SCENE_FRAME)


func test_cygwin_is_the_windows_branch_too() -> void:
	# Act
	var result: Dictionary = _run(UNAME_CYGWIN, {"STUB_BANNER": BANNER_WINDOWS}, _rig_check())

	# Assert
	assert_int(result.exit).is_equal(EXIT_OK)
	assert_array(_logged("ran")).is_equal(["engine"])


func test_windows_run_never_passes_headless() -> void:
	# Act
	_run_windows()

	# Assert
	assert_array(_engine_args()).not_contains(["--headless"])


func test_windows_command_is_the_adr_form_in_order() -> void:
	# Act
	_run_windows()

	# Assert: `--write-movie`'s value is a fresh temp path, compared on its own below
	var args: Array[String] = _engine_args()
	assert_int(args.size()).is_equal(10)
	args[6] = "<movie>"
	assert_array(args).is_equal(["--path", _repo_root(), "--windowed", "--resolution", RESOLUTION,
		"--write-movie", "<movie>", "--quit-after", FRAMES_DEFAULT, SCENE])


func test_windows_movie_path_is_a_drive_path_under_the_out_dir() -> void:
	# Act
	_run_windows()

	# Assert: a `/c/...` path through a native exe is what `cygpath -m` is there to stop.
	# On a non-Windows host the `cygpath` stub echoes, so only the folder can be checked.
	var movie: String = _engine_arg_after("--write-movie")
	assert_str(movie).contains("/out/.capture-")
	assert_str(movie).ends_with("/f.png")
	if OS.get_name() == "Windows":
		assert_str(movie.substr(1, 2)).is_equal(":/")


func test_windows_engine_starts_with_msys_path_conversion_off() -> void:
	# Act
	_run_windows()

	# Assert: a user argument that starts with `/` must reach the engine as written
	assert_array(_logged("pathconv")).is_equal(["1"])


func test_windows_engine_runs_from_the_worktree_root_whatever_the_callers_folder() -> void:
	# Arrange: the wrapper keys `user://` on the current directory, not on `--path`
	DirAccess.make_dir_recursive_absolute(_path("elsewhere"))

	# Act
	var result: Dictionary = _run_windows({}, [], "", _path("elsewhere"))

	# Assert
	assert_int(result.exit).is_equal(EXIT_OK)
	assert_array(_logged("cwd")).is_equal([_bash_path(_repo_root())])


func test_windows_engine_gets_the_worktrees_user_dir_through_the_wrapper() -> void:
	# Arrange
	DirAccess.make_dir_recursive_absolute(_path("elsewhere"))
	var worktree_name: String = _repo_root().get_file()

	# Act
	_run_windows({}, [], "", _path("elsewhere"))

	# Assert: this is the wrapper's key, so a `godot` that skipped it would fail here
	var data: String = _logged("data" if OS.get_name() == "Windows" else "xdg")[0].replace("\\", "/")
	assert_str(data).contains("/root/%s-" % worktree_name)


func test_windows_a_bad_godot_bin_is_exit_2_with_the_wrappers_message() -> void:
	# Act
	var result: Dictionary = _run_windows({"GODOT_BIN": _bash_path(_path("nothing-here"))})

	# Assert
	assert_int(result.exit).is_equal(EXIT_USAGE)
	assert_str(result.stderr).contains("godot wrapper: GODOT_BIN is set to")
	assert_array(_out_entries()).is_empty()


func test_windows_a_failed_launch_is_exit_3_with_the_engine_error_shown() -> void:
	# Act: what a service or remote session with no display looks like
	var result: Dictionary = _run_windows({"STUB_EXIT": "1", "STUB_FRAMES": "", "STUB_ERR": "ERROR: stub could not open a window"})

	# Assert
	assert_int(result.exit).is_equal(EXIT_GODOT)
	assert_str(result.stderr).contains("ERROR: stub could not open a window")
	assert_array(_out_entries()).is_empty()


func test_windows_frames_from_a_failed_run_are_discarded() -> void:
	# Act
	var result: Dictionary = _run_windows({"STUB_EXIT": "1"})

	# Assert
	assert_int(result.exit).is_equal(EXIT_GODOT)
	assert_array(_out_entries()).is_empty()


func test_windows_keeps_the_last_frame_and_nothing_else() -> void:
	# Act: the first frame is one colour, so keeping it would be exit 4
	var result: Dictionary = _run_windows()

	# Assert
	assert_int(result.exit).is_equal(EXIT_OK)
	assert_array(_out_entries()).is_equal([SCENE_FRAME, SCENE_SIDECAR])
	assert_array(FileAccess.get_file_as_bytes(_path("out/" + SCENE_FRAME))) \
		.is_equal(FileAccess.get_file_as_bytes(_path("frames/f00000001.png")))


func test_windows_blank_frame_is_exit_4() -> void:
	# Arrange
	_write_frames(true)

	# Act
	var result: Dictionary = _run_windows()

	# Assert
	assert_int(result.exit).is_equal(EXIT_BLANK)
	assert_str(result.stderr).contains("blank frame")


func test_windows_label_names_the_frame_and_its_sidecar() -> void:
	# Act
	var result: Dictionary = _run_windows({"CAPTURE_LABEL": "02-data_error"})

	# Assert
	assert_int(result.exit).is_equal(EXIT_OK)
	assert_array(_out_entries()).is_equal(["02-data_error.png", "02-data_error.renderer.txt"])


func test_windows_user_args_follow_the_scene_behind_a_double_dash() -> void:
	# Act
	var result: Dictionary = _run_windows({}, _with_user_args())

	# Assert
	assert_int(result.exit).is_equal(EXIT_OK)
	var args: Array[String] = _engine_args()
	assert_array(args.slice(args.find(SCENE))).is_equal([SCENE, "--", USER_ARGS[0], USER_ARGS[1]])


# --- AC-1: which Python runs the blank check ---------------------------------


func test_python3_runs_the_blank_check_when_it_starts() -> void:
	# Arrange
	_tool("py", "python3", PYTHON_WORKING.replace("{label}", "python3"))
	_tool("py", "python", PYTHON_WORKING.replace("{label}", "python"))

	# Act
	var result: Dictionary = _run_windows({}, [], _bash_path(_path("py")))

	# Assert
	assert_int(result.exit).is_equal(EXIT_OK)
	assert_str(_logged("python")[0]).starts_with("python3 -I -")


func test_python_runs_the_blank_check_when_python3_does_not_start() -> void:
	# Arrange: on the PATH, as the Store alias is, and exits at once
	_tool("py", "python3", PYTHON_BROKEN)
	_tool("py", "python", PYTHON_WORKING.replace("{label}", "python"))

	# Act
	var result: Dictionary = _run_windows({}, [], _bash_path(_path("py")))

	# Assert
	assert_int(result.exit).is_equal(EXIT_OK)
	assert_str(_logged("python")[0]).starts_with("python -I -")


func test_py_launcher_runs_the_blank_check_when_neither_other_starts() -> void:
	# Arrange
	_tool("py", "python3", PYTHON_BROKEN)
	_tool("py", "python", PYTHON_BROKEN)
	_tool("py", "py", PYTHON_WORKING.replace("{label}", "py"))

	# Act
	var result: Dictionary = _run_windows({}, [], _bash_path(_path("py")))

	# Assert
	assert_int(result.exit).is_equal(EXIT_OK)
	assert_str(_logged("python")[0]).starts_with("py -3 -I -")


func test_no_python_starting_is_exit_2_and_opens_no_window() -> void:
	# Arrange
	_tool("py", "python3", PYTHON_BROKEN)
	_tool("py", "python", PYTHON_BROKEN)
	_tool("py", "py", PYTHON_BROKEN)

	# Act
	var result: Dictionary = _run_windows({}, [], _bash_path(_path("py")))

	# Assert
	assert_int(result.exit).is_equal(EXIT_USAGE)
	assert_str(result.stderr).contains("python3, python, py -3")
	assert_array(_logged("ran")).is_empty()


# --- AC-2: the renderer ------------------------------------------------------


func test_windows_default_passes_no_rendering_driver() -> void:
	# Act
	_run_windows()

	# Assert
	assert_array(_engine_args()).not_contains(["--rendering-driver"])


func test_windows_opengl3_passes_the_driver_and_still_no_xvfb() -> void:
	# Act
	var result: Dictionary = _run_windows({"CAPTURE_RENDERER": "opengl3", "STUB_BANNER": BANNER_OPENGL})

	# Assert
	assert_int(result.exit).is_equal(EXIT_OK)
	assert_str(_engine_arg_after("--rendering-driver")).is_equal("opengl3")
	assert_array(_logged("ran")).is_equal(["engine"])


func test_any_other_renderer_is_exit_2_and_launches_nothing() -> void:
	# Act
	var result: Dictionary = _run_windows({"CAPTURE_RENDERER": "d3d12"})

	# Assert
	assert_int(result.exit).is_equal(EXIT_USAGE)
	assert_str(result.stderr).contains("CAPTURE_RENDERER")
	assert_array(_logged("ran")).is_empty()


func test_windows_sidecar_holds_the_os_the_arguments_and_the_banner() -> void:
	# Act
	_run_windows({}, _with_user_args())

	# Assert
	var sidecar: String = _sidecar()
	assert_str(sidecar).contains("os: " + UNAME_WINDOWS)
	assert_str(sidecar).contains("--write-movie")
	assert_str(sidecar).contains("--quit-after 60 res://src/scenes/boot.tscn -- --fixture=turn1_player --ai-sync")
	assert_str(sidecar).contains(BANNER_WINDOWS)
	assert_str(sidecar).not_contains("\r")


func test_windows_sidecar_names_what_the_log_says_the_renderer_was() -> void:
	# Act
	_run_windows()

	# Assert
	assert_str(_sidecar()).contains("renderer: windows / default (Forward+) / Stub - Stub GPU")


func test_windows_sidecar_for_opengl3_names_compatibility() -> void:
	# Act
	_run_windows({"CAPTURE_RENDERER": "opengl3", "STUB_BANNER": BANNER_OPENGL})

	# Assert
	assert_str(_sidecar()).contains("renderer: windows / opengl3 (Compatibility) / Stub - Stub GPU")


func test_windows_a_silent_fallback_shows_in_the_sidecar() -> void:
	# Act: the default was asked for, and the engine fell back
	_run_windows({"STUB_BANNER": BANNER_OPENGL})

	# Assert
	assert_str(_sidecar()).contains("renderer: windows / default (Compatibility) / Stub - Stub GPU")


func test_blank_frame_keeps_its_sidecar_so_no_frame_is_left_without_one() -> void:
	# Arrange
	_write_frames(true)

	# Act
	_run_windows()

	# Assert
	assert_array(_out_entries()).is_equal([SCENE_FRAME, SCENE_SIDECAR])


func test_no_renderer_line_in_the_log_keeps_no_frame() -> void:
	# Act: a GUI build of the engine prints nothing to a pipe or a file
	var result: Dictionary = _run_windows({"STUB_BANNER": ""})

	# Assert
	assert_int(result.exit).is_equal(EXIT_GODOT)
	assert_str(result.stderr).contains("no renderer line")
	assert_array(_out_entries()).is_empty()


# --- AC-3's line, pinned on any host (AC-3 itself needs a Linux host) --------


func test_linux_command_is_the_existing_xvfb_line_in_order() -> void:
	# Act
	var result: Dictionary = _run_linux()

	# Assert
	assert_int(result.exit).is_equal(EXIT_OK)
	var args: Array[String] = _logged("xvfb-arg")
	assert_int(args.size()).is_equal(16)
	args[12] = "<movie>"
	assert_array(args).is_equal(["-a", "-s", XVFB_SCREEN, "godot", "--path", _bash_path(_repo_root()),
		"--windowed", "--resolution", RESOLUTION, "--rendering-driver", "opengl3",
		"--write-movie", "<movie>", "--quit-after", FRAMES_DEFAULT, SCENE])


func test_linux_run_stays_in_the_callers_folder_with_path_conversion_untouched() -> void:
	# Arrange
	DirAccess.make_dir_recursive_absolute(_path("elsewhere"))

	# Act
	_run_linux({}, [], _path("elsewhere"))

	# Assert
	assert_str(_logged("cwd")[0]).ends_with("/capture_script_fixture/elsewhere")
	assert_array(_logged("pathconv")).is_equal(["unset"])


func test_linux_user_args_follow_the_scene_behind_a_double_dash() -> void:
	# Act
	var result: Dictionary = _run_linux({}, _with_user_args())

	# Assert
	assert_int(result.exit).is_equal(EXIT_OK)
	var args: Array[String] = _engine_args()
	assert_array(args.slice(args.find(SCENE))).is_equal([SCENE, "--", USER_ARGS[0], USER_ARGS[1]])


func test_linux_sidecar_reads_xvfb_opengl3_llvmpipe() -> void:
	# Act
	_run_linux()

	# Assert
	assert_str(_sidecar()).contains("renderer: " + LINUX_RENDERER_LINE)
	assert_str(_sidecar()).contains(BANNER_LINUX)


func test_linux_engine_output_stays_on_its_own_streams() -> void:
	# Act
	var result: Dictionary = _run_linux({"STUB_ERR": "WARNING: stub stderr line"})

	# Assert
	assert_str(result.stdout).contains(BANNER_LINUX)
	assert_str(result.stdout).not_contains("WARNING: stub stderr line")
	assert_str(result.stderr).contains("WARNING: stub stderr line")


func test_linux_kept_path_is_the_last_line_of_stdout() -> void:
	# Act
	var result: Dictionary = _run_linux()

	# Assert
	assert_str(_last_line(result.stdout)).ends_with("/out/" + SCENE_FRAME)


func test_linux_exit_codes_are_as_before() -> void:
	# Act
	var usage: Dictionary = _run_linux({}, [SCENE])
	var bad_scene: Dictionary = _run_linux({}, ["boot.tscn", _bash_path(_path("out"))])
	var no_frame: Dictionary = _run_linux({"STUB_FRAMES": ""})
	var engine_failed: Dictionary = _run_linux({"STUB_EXIT": "1"})
	_write_frames(true)
	var blank: Dictionary = _run_linux()

	# Assert
	assert_int(usage.exit).is_equal(EXIT_USAGE)
	assert_int(bad_scene.exit).is_equal(EXIT_USAGE)
	assert_int(no_frame.exit).is_equal(EXIT_GODOT)
	assert_int(engine_failed.exit).is_equal(EXIT_GODOT)
	assert_int(blank.exit).is_equal(EXIT_BLANK)


func test_linux_runs_the_blank_check_under_python3_alone() -> void:
	# Arrange: `python` would answer on Windows; Linux has only ever used `python3`
	_tool("py", "python3", PYTHON_BROKEN)
	_tool("py", "python", PYTHON_WORKING.replace("{label}", "python"))

	# Act
	var result: Dictionary = _run(UNAME_LINUX, {"STUB_BANNER": BANNER_LINUX}, _rig_check(),
		_bash_path(_path("py")) + ":" + _bash_path(_path("linuxbin")))

	# Assert: as before, a python3 that fails is exit 4 and no other is tried
	assert_int(result.exit).is_equal(EXIT_BLANK)
	assert_array(_logged("python")).is_empty()
