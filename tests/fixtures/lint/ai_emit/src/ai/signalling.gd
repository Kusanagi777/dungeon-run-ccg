## `done.emit()` in a doc comment must not hit.
extends RefCounted

signal done

func finish() -> void:
	done.emit()
	emit_signal("done")
