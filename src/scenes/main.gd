## `main.tscn`'s root: the one composition entry (ADR-0001 Decision 4;
## architecture.md §Data Flow 5 step 1; boot-composition-root story 006).
##
## Its only job: add the Run UI input actions, call `Boot.boot()` exactly once in
## `_ready()`, then instantiate the `RunShell`, hand it the `Services` bag and the
## run machine by argument ([method RunShell.bind]) and add it to the tree. It holds
## no game state.
## This root and `run_shell.gd` are the only `Boot` references under
## `src/scenes/` and `src/ui/` (ADR-0001 gate G3 scope note).
##
## Debug builds only (`OS.is_debug_build()`): the user argument
## `--boot-fail-fixture=<name>` boots with the override
## `{card_database: CardDatabase over res://tests/fixtures/data/<name>/}` — an
## unloaded database that `Boot` loads with its own validator map, so the
## `data_error` state is reached through the real composition, never a
## hand-built view-state (ADR-0010). It is the override seam `RunDebugLoader`
## will reuse. A release build ignores the argument.
## [codeblock]
## godot --path . -- --boot-fail-fixture=boot_data_error     # data_error capture
## [/codeblock]
## Debug builds only: `--run-ui-screen=<id> --run-ui-fixture=<name>` opens one screen
## from a fixture through `RunDebugLoader` (run-ui U10), loaded by path so a release
## export never names it.
## [codeblock]
## godot --path . -- --run-ui-screen=boss_intro --run-ui-fixture=mid_run_floor4
## [/codeblock]
## Any build: the user argument `--print-data-version` boots, prints `data_version()`
## and quits without opening the shell, exit 0, or exit 1 with an empty line when the
## load did not end `Ready`. It is how an exported build proves its PCK holds the data
## (card-database story 010; ADR-0002 Decision 10).
## [codeblock]
## deckdelve.exe --headless -- --print-data-version
## [/codeblock]
## A release export needs no argument to reach `data_error`: Boot's validator
## map files every pending validator as an error there, so the shipped load
## ends `Failed` by design until `PENDING_CONFIG_OWNERS` / `PENDING_RECORD_OWNERS`
## are empty, and the `RunShell` opens `data_error` (pinned by
## `main_scene_test.gd` over the shipped data and the release map).
class_name Main
extends Control

## The `RunShell` scene.
const RUN_SHELL_SCENE: PackedScene = preload("res://src/ui/run/run_shell.tscn")
## The debug argument selecting a broken fixture root.
const FAIL_FIXTURE_ARG: String = "--boot-fail-fixture="
## The user argument that prints `data_version()` and quits.
const PRINT_DATA_VERSION_ARG: String = "--print-data-version"
## Where the fixture roots live (not exported: `tests/*` is excluded, so an
## exported debug build given the argument shows `E_MISSING_FILE` rows).
const FIXTURE_ROOT: String = "res://tests/fixtures/data/"
## Fixture names allowed after [constant FAIL_FIXTURE_ARG]: one folder name,
## no path separators, so the argument cannot point anywhere else.
const FIXTURE_NAME_PATTERN: String = "^[a-z0-9_]+$"
## `load()`ed by path: a release export has no such script.
const RUN_DEBUG_LOADER_PATH: String = "res://src/ui/run/run_debug_loader.gd"


func _ready() -> void:
	var args: Array = Array(OS.get_cmdline_user_args())
	RunInput.install()
	var overrides: Dictionary = boot_overrides(args, OS.is_debug_build())
	var loader: RefCounted = null
	var launch: Dictionary = {}
	if OS.is_debug_build() and ResourceLoader.exists(RUN_DEBUG_LOADER_PATH):
		var loader_script: GDScript = load(RUN_DEBUG_LOADER_PATH)
		launch = loader_script.call(&"from_args", OS.get_cmdline_user_args())
		if not str(launch.screen).is_empty() and not str(launch.fixture).is_empty():
			loader = loader_script.new()
			overrides.merge(loader.call(&"load_fixture", str(launch.fixture)), true)
	var booted: BootResult = Boot.boot(overrides)
	if args.has(PRINT_DATA_VERSION_ARG):
		print(Boot.services().card_database.data_version() if booted.ok else "")
		get_tree().quit(0 if booted.ok else 1)
		return
	var shell: RunShell = RUN_SHELL_SCENE.instantiate() as RunShell
	shell.bind(Boot.services(), Boot.run_machine() if booted.ok else null)
	add_child(shell)
	if loader != null:
		loader.call(&"open", shell, StringName(str(launch.screen)))


## The `Boot.boot()` overrides [param args] (the user arguments) select:
## `{}` normally; `{card_database: <unloaded CardDatabase over the fixture>}`
## for `--boot-fail-fixture=<name>` when [param debug_build]. A name outside
## [constant FIXTURE_NAME_PATTERN] is logged and ignored.
## Example: `Main.boot_overrides(["--boot-fail-fixture=parse_error"], true).card_database`.
static func boot_overrides(args: Array, debug_build: bool) -> Dictionary:
	if not debug_build:
		return {}
	for raw: Variant in args:
		var arg: String = String(raw)
		if not arg.begins_with(FAIL_FIXTURE_ARG):
			continue
		var name: String = arg.trim_prefix(FAIL_FIXTURE_ARG)
		if RegEx.create_from_string(FIXTURE_NAME_PATTERN).search(name) == null:
			push_warning("Main: ignoring %s%s (expected a fixture folder name, %s)" % [FAIL_FIXTURE_ARG, name, FIXTURE_NAME_PATTERN])
			return {}
		return {"card_database": CardDatabase.new(DataLoader.new(FIXTURE_ROOT + name + "/"))}
	return {}
