## G6 planted violations: the global RNG in rules code (TD-007).
extends RefCounted


func setup(deck: Array) -> int:
	randomize()
	seed(42)
	deck.shuffle()
	var pick: Variant = deck.pick_random()
	var roll: int = randi_range(1, 6)
	var chance: float = randf_range(0.0, 1.0)
	return randi() + int(randf() * chance) + roll + int(pick)
