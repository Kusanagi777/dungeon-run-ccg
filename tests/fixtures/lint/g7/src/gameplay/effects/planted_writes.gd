## G7 planted violations: direct state writes from effects (ADR-0007 Decision 9).
extends RefCounted


func write(x: Dictionary, log: Variant) -> void:
	x.board.append(1)
	x.damage_taken += 1
	x["hand"].erase(1)
	(x["enchantments"] as Array).clear()
	x["armor"] = 0
	log.append(&"minion_died", {})
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	x.mana_current = rng.randi()
