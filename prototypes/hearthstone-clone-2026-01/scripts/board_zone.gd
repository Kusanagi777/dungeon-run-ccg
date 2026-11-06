# res://scripts/board_zone.gd
class_name board_zones
extends HBoxContainer

## Visual settings
@export var card_spacing: float = 10.0
@export var max_cards: int = 7

## Owner player ID
@export var player_id: int = 0


func _ready() -> void:
	add_theme_constant_override("separation", int(card_spacing))


## Get all minions on this board
func get_minions() -> Array[Node]:
	var minions: Array[Node] = []
	for child in get_children():
		if child is minion:
			minions.append(child)
	return minions


## Check if board has space
func has_space() -> bool:
	return get_child_count() < max_cards
