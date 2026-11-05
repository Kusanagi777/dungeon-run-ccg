## Every screen from a launch argument (run-ui U10; ADR-0011 Decision 4), debug builds
## only: `--run-ui-screen=<id> --run-ui-fixture=<name>` loads
## `tests/fixtures/run_ui/<name>.json` into a `MetaStub` and opens the screen with no
## transition. `main.gd` loads this script by path, so a release export never names it.
##
## A fixture is `{settings, active_run, record, offer, overrides, toasts}`, all optional.
## `record` is a stored run: its read model is what the screen shows, so no machine has
## to be walked to floor 4. `overrides` lay over the built read model, for what a
## `MetaStub` cannot answer (locked heroes, a 12-row report).
## [codeblock]
## var loader := RunDebugLoader.new()
## var args: Dictionary = RunDebugLoader.from_args(OS.get_cmdline_user_args())
## var overrides: Dictionary = loader.load_fixture(args.fixture)
## Boot.boot(overrides)
## loader.open(shell, args.screen)
## [/codeblock]
class_name RunDebugLoader
extends RefCounted

const SCREEN_ARG: String = "--run-ui-screen="
const FIXTURE_ARG: String = "--run-ui-fixture="
const FIXTURE_PATH: String = "res://tests/fixtures/run_ui/%s.json"
const NAME_PATTERN: String = "^[a-z0-9_]+$"

var _fixture: Dictionary = {}
var _db: CardDatabase = null


## `{screen, fixture}` from [param args], either empty when absent. A name outside
## [constant NAME_PATTERN] reads as absent, so the argument cannot point elsewhere.
static func from_args(args: PackedStringArray) -> Dictionary:
	var found: Dictionary = {"screen": "", "fixture": ""}
	var pattern: RegEx = RegEx.create_from_string(NAME_PATTERN)
	for arg: String in args:
		for row: Array in [[SCREEN_ARG, "screen"], [FIXTURE_ARG, "fixture"]]:
			if arg.begins_with(str(row[0])):
				var value: String = arg.trim_prefix(str(row[0]))
				if pattern.search(value) != null:
					found[row[1]] = value
	return found


## Reads fixture [param fixture_name] and returns the `Boot.boot` overrides: a loaded
## database, because `MetaStub` needs one, and the stub.
func load_fixture(fixture_name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH % fixture_name))
	if not parsed is Dictionary:
		push_warning("RunDebugLoader: no fixture %s" % fixture_name)
	_fixture = parsed if parsed is Dictionary else {}
	_db = CardDatabase.new()
	var _report: ValidationReport = _db.load(Boot._collect_validators(null))
	if _db.state() != CardDatabase.State.READY:
		return {"card_database": _db}
	return {"card_database": _db, "meta": MetaStub.from_fixture(_db, _fixture)}


## Opens [param screen] from the fixture on [param shell]'s controller.
func open(shell: RunShell, screen: StringName) -> void:
	var controller: RunController = shell.controller()
	var overrides: Dictionary = _fixture.get("overrides", {})
	if controller == null:
		shell.open_base(RunController.SCREEN_DATA_ERROR, overrides, RunShell.NO_TRANSITION)
		return
	controller.debug_open(screen, _run_model(), overrides)
	for row: Variant in _fixture.get("toasts", []):
		if row is Dictionary:
			controller.toast.emit(StringName(str(row.get("kind", "warning"))), row)


func _run_model() -> Dictionary:
	var record: Variant = _fixture.get("record")
	var model: Dictionary = {}
	if record is Dictionary:
		model = RunRecord.from_dict(record).read_model(_db, _db.config("run_structure"))
		model["unlocks_granted"] = _fixture.get("unlocks_granted", [])
	var offer: Variant = _fixture.get("offer")
	if offer is Dictionary:
		model["offer"] = offer
	return model
