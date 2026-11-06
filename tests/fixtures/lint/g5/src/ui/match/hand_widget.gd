## G5 planted violations: a widget holding rules state and submitting
## commands itself (TD-006).
extends Control

var state: MatchState = null


func _on_card_clicked(controller: RefCounted, command: RefCounted) -> void:
	controller.submit(command)
