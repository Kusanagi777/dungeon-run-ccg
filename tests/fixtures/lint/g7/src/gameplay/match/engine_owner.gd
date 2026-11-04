## Must not hit: the engine owns these writes; G7's scope is effects only.
extends RefCounted


func write(x: Dictionary, log: Variant) -> void:
	x.board.append(1)
	x["armor"] = 0
	log.append(&"minion_died", {})
