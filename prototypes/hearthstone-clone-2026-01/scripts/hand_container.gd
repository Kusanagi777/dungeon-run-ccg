# res://scripts/hand_container.gd
class_name hand_container
extends HBoxContainer

## Visual settings
@export var card_spacing: float = -30.0  # Negative for overlap
@export var max_cards: int = 10
@export var fan_angle: float = 3.0  # Degrees between cards
@export var arc_height: float = 20.0  # Pixels of arc

## Owner player ID
@export var player_id: int = 0


func _ready() -> void:
	add_theme_constant_override("separation", int(card_spacing))


## Called when children change to update card positions
func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_arrange_cards()


## Arrange cards in a fan pattern
func _arrange_cards() -> void:
	var card_count := get_child_count()
	if card_count == 0:
		return
	
	var center_index := (card_count - 1) / 2.0
	
	for i in range(card_count):
		var card := get_child(i)
		if not card is Control:
			continue
		
		# Calculate rotation
		var offset_from_center := i - center_index
		var rotation_deg := offset_from_center * fan_angle
		card.rotation_degrees = rotation_deg
		
		# Calculate arc offset
		var arc_offset = abs(offset_from_center) * arc_height / center_index if center_index > 0 else 0
		card.position.y = arc_offset


## Get all cards in hand
func get_cards() -> Array[Control]:
	var cards: Array[Control] = []
	for child in get_children():
		if child is card_ui:
			cards.append(child)
	return cards
