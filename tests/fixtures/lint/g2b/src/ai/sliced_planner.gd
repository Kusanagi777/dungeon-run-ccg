## G2b must-not-hit: under `src/ai/**` the planner's own coroutines may be
## awaited (ADR-0006 time-slicing seam; ADR-0001 G2b deny-list erratum).
extends RefCounted


func plan_turn(planner: RefCounted, state: Dictionary) -> Array:
	await planner.checkpoint()
	var scores: Array = await score_all(planner, state)
	return scores


func score_all(planner: RefCounted, _state: Dictionary) -> Array:
	await planner.checkpoint()
	return []
