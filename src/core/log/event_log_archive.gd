## Files a finished match log under `user://logs/` (design/gdd/rng-event-log.md rule
## 18, Tuning Knobs `keep_match_logs`; ADR-0003 Decision 9; ADR-0004; rng-event-log
## story 009).
##
## [method archive_match] writes the log to
## `user://logs/<run_id>/floor_<n>_attempt_<k>.json` when `keep_match_logs`, and a log
## that reached `log_overflow` to `user://logs/faults/<run_id>_floor_<n>_attempt_<k>.json`
## whatever that setting says, so an overflow can always be diagnosed.
##
## `EventLog` stays a pure data structure: this class holds the I/O, and the composition
## root chooses `keep_match_logs` from `config("rng_event_log").keep_match_logs[debug|
## release]`. Every write goes through the injected writer, which owns the staged-rename
## order (ADR-0004 W1-W9); this class only makes the folder first, because
## `FileAccess.open` does not.
##
## Main thread only, after `match_ended` and before `reduce_to_summary()`. A failed write
## is reported, never fatal, and the log is not changed.
## [codeblock]
## var archive := EventLogArchive.new(writer, config.keep_match_logs.debug)
## var error: Error = archive.archive_match(log, run_id, floor, attempt)
## [/codeblock]
class_name EventLogArchive
extends RefCounted

## Where every archive lives (rule 18).
const LOGS_ROOT: String = "user://logs/"
## The folder of the overflow copies, under the root.
const FAULTS_FOLDER: String = "faults"
## `floor_<n>_attempt_<k>.json`.
const FILE_NAME: String = "floor_%d_attempt_%d.json"
## The event that marks a log as overflowed (rule 16).
const EVENT_OVERFLOW: String = "log_overflow"

## An `AtomicFileWriter` (ADR-0004): `write(final_path: String, text: String) -> Error`.
## Untyped only because `src/core/save/` has not shipped the class yet.
var _writer: RefCounted
var _keep_match_logs: bool
var _root: String


## [param writer] is the `AtomicFileWriter`; [param keep_match_logs] the setting for this
## build. [param root] replaces [constant LOGS_ROOT]; only a test passes one.
func _init(writer: RefCounted, keep_match_logs: bool, root: String = LOGS_ROOT) -> void:
	_writer = writer
	_keep_match_logs = keep_match_logs
	_root = root


## The `keep_match_logs` of this build type, from the `config("rng_event_log")` body
## [param config] (rng-event-log Tuning Knobs: debug true, release false).
## [codeblock]
## EventLogArchive.new(writer, EventLogArchive.keep_for_build(db.config("rng_event_log")))
## [/codeblock]
static func keep_for_build(config: Dictionary, debug_build: bool = OS.is_debug_build()) -> bool:
	var per_build: Dictionary = config.get("keep_match_logs", {})
	return per_build.get("debug" if debug_build else "release", false) == true


## Writes [param log], a sealed match log, to the files it is due (see the class doc):
## none, one or both. [param run_id] is Run Structure's `<run_seed_hex>-<started_at>`;
## [param attempt] is `match_attempts[floor]`. Returns `OK`, or the first `Error` met; a
## failed regular copy does not stop the faults copy, since that one is the log's only
## way out.
## [codeblock]
## if archive.archive_match(log, run_id, 3, 1) != OK: push_warning("match log not archived")
## [/codeblock]
func archive_match(log: EventLog, run_id: String, floor_number: int, attempt: int) -> Error:
	var overflowed: bool = _overflowed(log)
	if not _keep_match_logs and not overflowed:
		return OK
	var text: String = log.to_json()
	var name: String = FILE_NAME % [floor_number, attempt]
	var outcome: Error = OK
	if _keep_match_logs:
		outcome = _write(_root.path_join(run_id), name, text)
	if overflowed:
		var faults: Error = _write(_root.path_join(FAULTS_FOLDER), "%s_%s" % [run_id, name], text)
		outcome = outcome if outcome != OK else faults
	return outcome


## Makes [param folder], then writes [param text] to [param file_name] in it.
func _write(folder: String, file_name: String, text: String) -> Error:
	var made: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	if made != OK:
		return made
	return _writer.write(folder.path_join(file_name), text)


static func _overflowed(log: EventLog) -> bool:
	for event: Dictionary in log.events_since(0):
		if str(event.type) == EVENT_OVERFLOW:
			return true
	return false
