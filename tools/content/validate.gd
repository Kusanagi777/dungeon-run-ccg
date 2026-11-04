## The headless validate command (content CN-6.3; card-database CR-8;
## ADR-0002 Key Interfaces):
##
##   godot --headless --path . -s res://tools/content/validate.gd [-- --data-root res://assets/data/]
##
## A thin SceneTree entry: parse the user arguments, run
## [method ContentValidateCommand.run] over the root with the validator map
## `Boot` registers ([method ContentValidateCommand.boot_validators], built for
## this binary's build type), print the report and `quit()` with its code —
## 0 `Ready` (warnings printed), 1 `Failed` (report printed), 2 could not run.
## Run from the editor binary, the pending owners' `W_VALIDATOR_PENDING`
## entries are warnings (debug build), so a root whose only problems are
## pending validators exits 0; a release binary would make them errors and
## exit 1 (tests/README.md "Content validate command").
## `quit(code)` is called from `_initialize()`; the exit code is observed on
## Godot 4.7.2 headless by `tests/integration/content/content_validate_process_test.gd`.
extends SceneTree


func _initialize() -> void:
	var args: Dictionary = ContentValidateCommand.parse_args(Array(OS.get_cmdline_user_args()))
	if not String(args.error).is_empty():
		printerr("validate: could not run — " + String(args.error))
		quit(ContentValidateCommand.EXIT_NOT_RUN)
		return
	var out: Dictionary = ContentValidateCommand.run(args.data_root, ContentValidateCommand.boot_validators(OS.is_debug_build()))
	print(out.report_text)
	quit(out.exit_code)
