## G2b must-not-hit: `src/core/boot.gd` is excluded from G2b.
extends Node


func _settle() -> void:
	await get_tree().process_frame
