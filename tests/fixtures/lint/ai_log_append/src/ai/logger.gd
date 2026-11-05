## `log.append(type, payload, 0)` in a doc comment must not hit.
extends RefCounted

var _log: Variant
var scratch_log: Variant

func note(type: StringName) -> void:
	_log.append(type, {}, 0)
	scratch_log.append(type, {}, 0)
