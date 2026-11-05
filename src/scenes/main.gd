## `main.tscn`'s root: the one composition entry (ADR-0001 Decision 4;
## architecture.md §Data Flow 5 step 1; boot-composition-root story 006).
##
## Its only job: call `Boot.boot()` exactly once in `_ready()`, then
## instantiate the `RunShell` stub, hand it the `Services` bag by argument
## ([method RunShell.bind]) and add it to the tree. It holds no game state.
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
## Debug builds only: `--fixture=<name>` shows the match view instead of the shell, so
## an exported debug build reaches a match through its main scene (match-ui story 012).
## `MatchView` reads the argument itself. A release build ignores it.
## [codeblock]
## deckdelve-debug.exe -- --fixture=first_playable
## [/codeblock]
## A release export needs no argument to reach `data_error`: Boot's validator
## map files every pending validator as an error there, so the shipped load
## ends `Failed` by design until `PENDING_CONFIG_OWNERS` / `PENDING_RECORD_OWNERS`
## are empty, and the `RunShell` opens `data_error` (pinned by
## `main_scene_test.gd` over the shipped data and the release map).
class_name Main
extends Control

## The `RunShell` stub scene (the Run UI epic replaces its body, keeps the path).
const RUN_SHELL_SCENE: PackedScene = preload("res://src/ui/run/run_shell.tscn")
## The debug argument selecting a broken fixture root.
const FAIL_FIXTURE_ARG: String = "--boot-fail-fixture="
## Where the fixture roots live (not exported: `tests/*` is excluded, so an
## exported debug build given the argument shows `E_MISSING_FILE` rows).
const FIXTURE_ROOT: String = "res://tests/fixtures/data/"
## Fixture names allowed after [constant FAIL_FIXTURE_ARG]: one folder name,
## no path separators, so the argument cannot point anywhere else.
const FIXTURE_NAME_PATTERN: String = "^[a-z0-9_]+$"
## The debug argument naming a match fixture (`MatchDebugLoader`).
const MATCH_FIXTURE_ARG: String = "--fixture="
## `load()`ed on that route only, so the shell's start pays nothing for it.
const MATCH_VIEW_SCENE_PATH: String = "res://src/ui/match/match_view.tscn"


func _ready() -> void:
	if launches_match(Array(OS.get_cmdline_user_args()), OS.is_debug_build()):
		add_child((load(MATCH_VIEW_SCENE_PATH) as PackedScene).instantiate())
		return
	Boot.boot(boot_overrides(Array(OS.get_cmdline_user_args()), OS.is_debug_build()))
	var shell: RunShell = RUN_SHELL_SCENE.instantiate() as RunShell
	shell.bind(Boot.services())
	add_child(shell)


## True when [param args] (the user arguments) ask for a match fixture in a
## [param debug_build].
## Example: `Main.launches_match(["--fixture=first_playable"], true)`.
static func launches_match(args: Array, debug_build: bool) -> bool:
	if not debug_build:
		return false
	return args.any(func(arg: Variant) -> bool: return String(arg).begins_with(MATCH_FIXTURE_ARG))


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
