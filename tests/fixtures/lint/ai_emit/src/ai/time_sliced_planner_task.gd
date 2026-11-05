## Must not hit: the seam resumes its own coroutine (ADR-0006).
extends RefCounted

signal _resume

func poll() -> void:
	_resume.emit()
