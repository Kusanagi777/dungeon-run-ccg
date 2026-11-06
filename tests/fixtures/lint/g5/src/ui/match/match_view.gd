## G5 must-not-hit: `*_view.gd` is the input path that submits.
extends Control


func _on_end_turn_pressed(controller: RefCounted, command: RefCounted) -> void:
	controller.submit(command)
