## Records the rules-engine golden logs (match-rules story 019 AC-2):
##
##   godot --headless --path . -s res://tools/match_rules/record_golden_logs.gd
##
## Writes [method MatchGoldenLogs.capture] for every golden to
## `tests/fixtures/match_rules/golden_logs/`, LF, one canonical-JSON object per
## line, and prints each file's size. Exits 0, or 1 when a file cannot be
## written.
##
## **This overwrites the proof.** A golden is regenerated only with a reviewed
## rules change, in that change's own commit, its diff read by
## technical-director (QA plan sprint 5, Cross-cutting 3). Regenerating to make
## `match_rules_golden_log_test.gd` pass hides exactly what it exists to catch.
extends SceneTree


func _initialize() -> void:
	var golden: MatchGoldenLogs = MatchGoldenLogs.new()
	var made: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MatchGoldenLogs.GOLDEN_DIR))
	if made != OK:
		printerr("record_golden_logs: cannot create %s: %s" % [MatchGoldenLogs.GOLDEN_DIR, error_string(made)])
		quit(1)
		return
	for name: String in golden.names():
		var text: String = golden.capture(name)
		var file: FileAccess = FileAccess.open(MatchGoldenLogs.path_of(name), FileAccess.WRITE)
		if file == null:
			printerr("record_golden_logs: cannot write %s: %s" % [name, error_string(FileAccess.get_open_error())])
			quit(1)
			return
		file.store_string(text)
		file.close()
		print("%s: %d bytes" % [name, text.length()])
	quit(0)
