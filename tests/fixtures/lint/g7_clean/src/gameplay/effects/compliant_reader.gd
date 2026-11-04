## Must not hit: an effects file that reads state and writes through primitives.
extends RefCounted


func read(x: Dictionary, engine: Variant) -> int:
	engine.apply_armor("player", 1)
	engine.emit(&"counter_changed", {})
	var targets: Array = []
	targets.append(x.board.size())
	return int(x["armor"]) + int(x.damage_taken) + targets.size()
