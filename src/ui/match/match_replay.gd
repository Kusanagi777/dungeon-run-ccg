## The public way into the replay viewer (architecture.md "Can defer"; ADR-0003;
## rng-event-log rules 17-18, Edge Cases). A shell lists a run's archived match logs with
## [method archives], asks [method inspect] whether one can play, and adds the view
## [method create_view] builds. The view ends with `match_view_finished`: the match's
## result after the end banner, or `{}` when the player left early.
##
## A log plays only on the engine and data it was recorded with (rule 9; Edge Cases). The
## others stay listed: [method inspect] names the `replay.not_replayable.*` key to label
## them with. In a release build `keep_match_logs` is false, so a run's list holds only
## the logs of its faults.
## [codeblock]
## for entry: Dictionary in MatchReplay.archives(run_id):
##     var check: Dictionary = MatchReplay.inspect(entry.path, db)
##     row.disabled = not check.replayable
##     row.tooltip_text = tr(check.reason_key)
## var view: MatchView = MatchReplay.create_view(path, db, hero_id, boss_id)
## view.match_view_finished.connect(func(_result: Dictionary) -> void: view.queue_free())
## add_child(view)
## [/codeblock]
class_name MatchReplay
extends RefCounted

const VIEW_SCENE_PATH: String = "res://src/ui/match/match_view.tscn"
const FILE_PATTERN: String = "floor_(\\d+)_attempt_(\\d+)\\.json$"
const KEY_UNREADABLE: String = "replay.not_replayable.unreadable"
const KEY_ENGINE: String = "replay.not_replayable.engine"
const KEY_DATA: String = "replay.not_replayable.data"


## Every archived match log of [param run_id], by floor then attempt: `{path, floor,
## attempt, fault}`. `fault` marks a log kept only in the faults folder (rule 16).
## [param root] replaces [constant EventLogArchive.LOGS_ROOT]; only a test passes one.
static func archives(run_id: String, root: String = EventLogArchive.LOGS_ROOT) -> Array[Dictionary]:
	var found: Dictionary = {}
	var pattern: RegEx = RegEx.create_from_string("^" + FILE_PATTERN)
	var folder: String = root.path_join(run_id)
	for file: String in _files_in(folder):
		_note(found, pattern.search(file), folder.path_join(file), false)
	var faults: String = root.path_join(EventLogArchive.FAULTS_FOLDER)
	var prefix: String = run_id + "_"
	for file: String in _files_in(faults):
		if file.begins_with(prefix):
			_note(found, pattern.search(file.trim_prefix(prefix)), faults.path_join(file), true)
	var out: Array[Dictionary] = []
	out.assign(found.values())
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.floor < b.floor or (a.floor == b.floor and a.attempt < b.attempt))
	return out


## Whether the log at [param path] can play here: `{replayable, reason_key, floor}`.
## [param reason_key] is `""` when it can.
static func inspect(path: String, db: CardDatabase) -> Dictionary:
	var log: EventLog = _read(path)
	if log == null:
		return {"replayable": false, "reason_key": KEY_UNREADABLE, "floor": 0}
	var header: Dictionary = log.snapshot()
	var reason: String = ""
	if str(header.engine_version) != Engine.get_version_info().string:
		reason = KEY_ENGINE
	elif str(header.data_version) != db.data_version():
		reason = KEY_DATA
	return {"replayable": reason == "", "reason_key": reason, "floor": int(header.get("floor", 0))}


## A match view that plays the log at [param path], not yet in the tree, or null when
## [method inspect] says it cannot. The log does not name its fighters, so the caller
## passes them from the run record.
static func create_view(path: String, db: CardDatabase, hero_def_id: String, boss_def_id: String) -> MatchView:
	var check: Dictionary = inspect(path, db)
	if not check.replayable:
		push_warning("MatchReplay: %s cannot play: %s" % [path, check.reason_key])
		return null
	var view: MatchView = (load(VIEW_SCENE_PATH) as PackedScene).instantiate()
	view.set_match_info({"floor": check.floor, "boss_def_id": boss_def_id, "hero_def_id": hero_def_id})
	view.set_controller(ReplayController.new(_read(path), db))
	view.ready.connect(_attach_hud.bind(view), CONNECT_ONE_SHOT)
	return view


## After the view's own `_ready`: the strings and the rects exist from there on.
static func _attach_hud(view: MatchView) -> void:
	var hud := ReplayHud.new()
	view.add_child(hud)
	hud.attach(view.ui_context(), view.feed())
	hud.exit_requested.connect(view.close_replay)


static func _note(found: Dictionary, match_result: RegExMatch, path: String, fault: bool) -> void:
	if match_result == null:
		return
	var floor_number: int = int(match_result.get_string(1))
	var attempt: int = int(match_result.get_string(2))
	var key: String = "%d_%d" % [floor_number, attempt]
	if not found.has(key):
		found[key] = {"path": path, "floor": floor_number, "attempt": attempt, "fault": fault}


static func _files_in(folder: String) -> PackedStringArray:
	return DirAccess.get_files_at(folder) if DirAccess.dir_exists_absolute(folder) else PackedStringArray()


static func _read(path: String) -> EventLog:
	if not FileAccess.file_exists(path):
		return null
	return EventLog.from_json(FileAccess.get_file_as_string(path))
