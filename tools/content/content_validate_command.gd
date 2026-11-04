## The testable core of the headless validate command (content CN-6.3;
## card-database CR-8 "the headless validate command prints the report and
## exits non-zero"; ADR-0002 Key Interfaces `tools/content/validate.gd`).
##
## [method run] composes the game's own `DataLoader` + `CardDatabase` over a
## data root with an injected validator map — the map `Boot` registers when
## run by `validate.gd` ([method boot_validators]), accepting stubs in tests —
## and returns the exit code and the text to print. It never opens a data file
## itself and has no parser of its own: the load is the loader's. The command
## emits observations, never verdicts beyond the exit contract: the load time
## is printed next to `data_load_budget_ms`, never judged.
##
## Exit contract: [constant EXIT_READY] 0 when the load ends `Ready`
## (warnings printed), [constant EXIT_FAILED] 1 when it ends `Failed` (full
## report printed), [constant EXIT_NOT_RUN] 2 when it could not run (no such
## root, a bad argument, no project).
##
## [codeblock]
## var out: Dictionary = ContentValidateCommand.run("res://assets/data/", ContentValidateCommand.boot_validators())
## print(out.report_text)
## quit(out.exit_code)
## [/codeblock]
## Not exported (`tools/*` is in the export exclude filter); editor binary only.
class_name ContentValidateCommand
extends RefCounted

## The load ended `Ready`.
const EXIT_READY: int = 0
## The load ended `Failed`.
const EXIT_FAILED: int = 1
## The command could not run.
const EXIT_NOT_RUN: int = 2
## The data root when no `--data-root` is given (the shipped data).
const DEFAULT_DATA_ROOT: String = "res://assets/data/"
## The one user argument (after `--` on the Godot command line).
const DATA_ROOT_ARG: String = "--data-root"
## `Boot`'s script: [method boot_validators] reads its validator map from a
## fresh, never-booted instance, so the command and the game cannot drift.
const BOOT_SCRIPT_PATH: String = "res://src/core/boot.gd"
## Usage line printed on a bad argument.
const USAGE: String = "usage: godot --headless --path . -s res://tools/content/validate.gd [-- --data-root res://assets/data/]"


## Loads [param data_root] through `DataLoader` + `CardDatabase.load(validators)`
## and returns `{exit_code, state, report_text}`: `state` is `Ready`,
## `Failed` or `NotRun`; `report_text` is `ValidationReport.to_text()`
## followed by one summary line (state, error and warning counts, load ms
## and the `data_load_budget_ms` it is compared with, as an observation).
## A root that is not a directory returns [constant EXIT_NOT_RUN] and loads
## nothing.
## Example: `ContentValidateCommand.run("res://tests/fixtures/data/minimal/", ValidatorStubs.accept_all()).exit_code == 0`.
static func run(data_root: String, validators: Dictionary) -> Dictionary:
	if not DirAccess.dir_exists_absolute(data_root):
		return {"exit_code": EXIT_NOT_RUN, "state": "NotRun",
			"report_text": "validate: could not run — data root %s is not a directory" % data_root}
	var db: CardDatabase = CardDatabase.new(DataLoader.new(data_root))
	var started_usec: int = Time.get_ticks_usec()
	var report: ValidationReport = db.load(validators)
	var load_ms: float = (Time.get_ticks_usec() - started_usec) / 1000.0
	var ready: bool = db.state() == CardDatabase.State.READY
	var state: String = "Ready" if ready else "Failed"
	var budget: String = "unknown (card_database.json did not load)"
	var records: String = "no snapshot"
	var checks: String = "content checks not run (load Failed)"
	if ready:
		budget = "%d" % int((db.config("card_database") as Dictionary).data_load_budget_ms)
		records = "%d records" % report.record_count()
		var rows: Array[Dictionary] = _content_checks(db)
		report = _merged(report, rows)
		var check_errors: int = rows.filter(func(r: Dictionary) -> bool: return r.severity == ValidationReport.SEVERITY_ERROR).size()
		checks = "content checks %d errors, %d warnings" % [check_errors, rows.size() - check_errors]
	var summary: String = "validate: %s — %d errors, %d warnings (%s), %s; load ms %.2f (data_load_budget_ms %s) — root %s" % [
		state, report.errors().size(), report.warnings().size(), checks, records, load_ms, budget, data_root]
	var text: String = report.to_text()
	return {
		"exit_code": EXIT_READY if ready and not report.has_errors() else EXIT_FAILED,
		"state": state,
		"report_text": (text + "\n" + summary) if not text.is_empty() else summary,
	}


## The content story 008 F1-F5 checks over a `Ready` [param db], with its
## `content_budgets` and `heroes_balance` bodies (`{}` when a body is absent,
## which the checks report as "not checked").
static func _content_checks(db: CardDatabase) -> Array[Dictionary]:
	var budgets: Variant = db.config("content_budgets")
	var balance: Variant = db.config("heroes_balance")
	return ContentValidator.run_checks(db, budgets if budgets is Dictionary else {}, balance if balance is Dictionary else {})


## A new report holding [param report]'s entries and [param rows]; the
## database's own report is left untouched.
static func _merged(report: ValidationReport, rows: Array[Dictionary]) -> ValidationReport:
	var out: ValidationReport = ValidationReport.new()
	for e: Dictionary in report.entries() + rows:
		out.add(e.severity, e.code, e.file, e.record_id, e.field, e.message)
	out.set_record_count(report.record_count())
	return out


## Parses the user arguments (`OS.get_cmdline_user_args()`): `--data-root
## <path>` or `--data-root=<path>`. Returns `{data_root, error}`; `error` is
## `""` when the arguments are usable, else names the bad argument.
## Example: `ContentValidateCommand.parse_args(["--data-root=res://x/"]).data_root == "res://x/"`.
static func parse_args(args: Array) -> Dictionary:
	var out: Dictionary = {"data_root": DEFAULT_DATA_ROOT, "error": ""}
	var i: int = 0
	while i < args.size():
		var arg: String = String(args[i])
		if arg.begins_with(DATA_ROOT_ARG + "="):
			out.data_root = arg.trim_prefix(DATA_ROOT_ARG + "=")
		elif arg == DATA_ROOT_ARG:
			if i + 1 >= args.size():
				out.error = "%s needs a path. %s" % [DATA_ROOT_ARG, USAGE]
				return out
			i += 1
			out.data_root = String(args[i])
		else:
			out.error = "unknown argument %s. %s" % [arg, USAGE]
			return out
		i += 1
	if String(out.data_root).is_empty():
		out.error = "%s is empty. %s" % [DATA_ROOT_ARG, USAGE]
	return out


## The validator map `Boot` registers, built by `Boot`'s own
## `_collect_validators(null, debug_build)` on a fresh instance of its script
## that is never booted and is freed at once — the same map the game loads
## with, including the pending owners' `W_VALIDATOR_PENDING` entries (a
## warning when [param debug_build], an error otherwise). `{}` when the
## script cannot be loaded (the command then fails with `E_DELEGATED`).
## Example: `ContentValidateCommand.boot_validators(OS.is_debug_build())`.
static func boot_validators(debug_build: bool = OS.is_debug_build()) -> Dictionary:
	var script: Script = load(BOOT_SCRIPT_PATH)
	if script == null:
		return {}
	var boot: Object = script.new()
	var map: Dictionary = boot.call("_collect_validators", null, debug_build)
	boot.free()
	return map
