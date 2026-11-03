## G2 must-not-hit: `src/core/boot.gd` is the one Node in the tier and is
## excluded from G2 (ADR-0001 Decision 6).
extends Node


func _start_timer(timer: Timer) -> void:
	add_child(timer)
