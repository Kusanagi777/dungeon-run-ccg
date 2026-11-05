## The one way a file under `user://` is written (ADR-0004 Decision 3; M4.1;
## control manifest, Foundation): stage to `<final>.tmp`, check it, move the old
## file to the backup, then rename the stage into a path that is now absent.
##
## Any failure before the last rename deletes the `.tmp` and leaves the final
## and backup files as they were. If the last rename itself fails, the old file
## is moved back from the backup. The retry after `io_retry_ms` is the caller's:
## this class holds no knob.
##
## Windows rename semantics are NOT SOURCEABLE (ADR-0004 Engine Compatibility):
## the order below needs no over-existing guarantee on the profile path, and
## `tests/integration/save/atomic_write_platform_test.gd` is the proof.
##
## Tests inject failures by overriding [method _fails_at].
##
## [codeblock]
## var writer := AtomicFileWriter.new()
## var err: Error = writer.write("user://profile.json", text, "user://profile.bak")
## if err != OK:
##     push_error(writer.last_error_detail())
## [/codeblock]
class_name AtomicFileWriter
extends RefCounted

## Appended to the final path to name the staging file (M1.1).
const TMP_SUFFIX: String = ".tmp"

var _detail: String = ""


## Writes [param text] to [param final_path] (steps W2-W8). With
## [param backup_path], an existing final file is first moved there, replacing
## the old backup. Without it, the stage is renamed over the final file: use that
## only for a file that has no backup. Returns `OK` or `E_IO`
## (`SaveErrors.E_IO`); [method last_error_detail] then names the step.
func write(final_path: String, text: String, backup_path: String = "") -> Error:
	_detail = ""
	var tmp_path: String = final_path + TMP_SUFFIX
	if not _stage(final_path, tmp_path, text):
		_discard(tmp_path)
		return SaveErrors.E_IO
	var rotated: bool = false
	if not backup_path.is_empty() and FileAccess.file_exists(final_path):
		if not _rotate(final_path, backup_path):
			_discard(tmp_path)
			return SaveErrors.E_IO
		rotated = true
	var renamed: Error = FAILED if _fails_at("W8") else DirAccess.rename_absolute(tmp_path, final_path)
	if renamed != OK:
		_fail("W8", renamed)
		_discard(tmp_path)
		if rotated:
			DirAccess.rename_absolute(backup_path, final_path)
		return SaveErrors.E_IO
	return OK


## Which step failed and with which `Error`, for the console line; empty after a
## successful [method write].
func last_error_detail() -> String:
	return _detail


## Test seam: true makes [param _step] (`"W2"` to `"W8"`) fail as if the engine
## had reported an error. ADR-0004 Verification, fault injection.
func _fails_at(_step: String) -> bool:
	return false


## W2-W6: directory, open, store, flush, close, size check.
func _stage(final_path: String, tmp_path: String, text: String) -> bool:
	var made: Error = FAILED if _fails_at("W2") else DirAccess.make_dir_recursive_absolute(final_path.get_base_dir())
	if made != OK and made != ERR_ALREADY_EXISTS:
		return _fail("W2", made)
	var file: FileAccess = null if _fails_at("W3") else FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return _fail("W3", FileAccess.get_open_error())
	var stored: bool = false if _fails_at("W4") else file.store_string(text)
	var store_error: Error = file.get_error()
	if not stored or store_error != OK:
		file.close()
		return _fail("W4", store_error)
	file.flush()
	var flushed: Error = FAILED if _fails_at("W5") else file.get_error()
	file.close()
	if flushed != OK:
		return _fail("W5", flushed)
	var staged: FileAccess = FileAccess.open(tmp_path, FileAccess.READ)
	var size: int = -1 if staged == null or _fails_at("W6") else staged.get_length()
	if staged != null:
		staged.close()
	if size != text.to_utf8_buffer().size():
		return _fail("W6", ERR_FILE_CORRUPT)
	return true


## W7: the old file to the backup. The one rename over an existing file, so it
## may fail on some platforms: the old backup is then deleted and the rename
## tried once more (the backup-of-the-backup is lost, never the profile).
func _rotate(final_path: String, backup_path: String) -> bool:
	var moved: Error = FAILED if _fails_at("W7") else DirAccess.rename_absolute(final_path, backup_path)
	if moved == OK:
		return true
	DirAccess.remove_absolute(backup_path)
	moved = FAILED if _fails_at("W7") else DirAccess.rename_absolute(final_path, backup_path)
	if moved == OK:
		return true
	return _fail("W7", moved)


func _discard(tmp_path: String) -> void:
	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(tmp_path)


func _fail(step: String, code: Error) -> bool:
	_detail = "%s failed: %s" % [step, error_string(code)]
	return false
