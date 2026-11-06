## `user://profile.lock`, the two-instances guard (M6, F7; ADR-0004 Decision 6).
##
## A lock whose heartbeat is younger than `lock_stale_s` belongs to a live
## instance: [method acquire] refuses it and the profile loads `ReadOnly`. A
## stale or unreadable lock is taken over. Boot's `Timer` drives
## [method heartbeat] through `ProfileStore`; this class holds no Node.
##
## [codeblock]
## var lock := ProfileLock.new("user://profile.lock", 90)
## if lock.acquire(instance_id) == ERR_LOCKED:
##     pass   # another instance owns the profile
## [/codeblock]
class_name ProfileLock
extends RefCounted

var _path: String
var _stale_s: int
var _clock: Callable
var _writer: AtomicFileWriter = AtomicFileWriter.new()
var _instance_id: String = ""
var _held: bool = false


## [param clock] returns unix seconds; tests inject one.
func _init(lock_path: String, stale_s: int, clock: Callable = Time.get_unix_time_from_system) -> void:
	_path = lock_path
	_stale_s = stale_s
	_clock = clock


## Takes the lock for [param instance_id]. Returns `OK` (free, stale, or already
## this instance's) or `ERR_LOCKED` (a live lock of another instance, F7). A lock
## file that cannot be written is logged and does not stop the session.
func acquire(instance_id: String) -> Error:
	var holder: Dictionary = _read()
	if not holder.is_empty() and str(holder.get("instance_id", "")) != instance_id:
		if _is_live(holder):
			return ERR_LOCKED
		print("profile.lock: stale lock of instance %s taken over" % str(holder.get("instance_id", "?")))
	_instance_id = instance_id
	_held = true
	_write()
	return OK


## Refreshes `heartbeat_at`. Returns false when another instance has taken the
## lock over (this one slept past `lock_stale_s`); it is then no longer held.
func heartbeat() -> bool:
	if not _held:
		return true
	var holder: Dictionary = _read()
	if not holder.is_empty() and str(holder.get("instance_id", "")) != _instance_id:
		_held = false
		return false
	_write()
	return true


## Deletes the lock file if this instance holds it (clean exit, M6.1).
func release() -> void:
	if _held and FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)
	_held = false


## F7: `lock_is_live`.
func _is_live(holder: Dictionary) -> bool:
	var heartbeat_at: Variant = holder.get("heartbeat_at")
	if not (heartbeat_at is float or heartbeat_at is int):
		return false
	return float(_clock.call()) - float(heartbeat_at) < _stale_s


## The lock file as a Dictionary; `{}` when absent or unreadable.
func _read() -> Dictionary:
	if not FileAccess.file_exists(_path):
		return {}
	var parsed: Variant = DataLoader.parse_text(FileAccess.get_file_as_string(_path), _path)
	return parsed if parsed is Dictionary else {}


func _write() -> void:
	var text: String = JSON.stringify({
		"instance_id": _instance_id,
		"pid": OS.get_process_id(),
		"heartbeat_at": int(_clock.call()),
	}, "\t")
	if _writer.write(_path, text) != OK:
		push_warning("profile.lock not written: %s" % _writer.last_error_detail())
