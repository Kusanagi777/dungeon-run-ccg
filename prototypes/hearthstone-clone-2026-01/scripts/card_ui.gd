# res://scripts/card_ui.gd
# MODIFICATION: Hand hover behavior fix
# When a card is hovered, other cards no longer reorganize/shift

class_name card_ui
extends Control

## Emitted when card is clicked
signal card_clicked(card_ui: Control)

## Emitted when drag starts
signal card_drag_started(card_ui: Control)

## Emitted when drag ends
signal card_drag_ended(card_ui: Control, global_position: Vector2)

## Card states
enum CardState {
	IN_HAND,
	DRAGGING,
	HOVERING,
	PLAYED
}

## The card data this UI represents
var card_data: CardData

## Owner player ID
var owner_id: int = 0

## Current state
var current_state: CardState = CardState.IN_HAND

## Can this card be interacted with?
var is_interactable: bool = true

## Original position in hand (for returning)
var _hand_position: Vector2 = Vector2.ZERO

## Original index in hand
var _hand_index: int = 0

## Drag offset
var _drag_offset: Vector2 = Vector2.ZERO

## Is currently being dragged
var _is_dragging: bool = false

## Hover scale multiplier
const HOVER_SCALE := 1.15
const NORMAL_SCALE := 1.0
const HOVER_Y_OFFSET := -30.0

## Base card size (designed for 1280x720)
const BASE_CARD_SIZE := Vector2(120, 170)
const REFERENCE_HEIGHT := 720.0

## Base font sizes for scaling
const BASE_FONT_SIZES := {
	"cost": 14,
	"name": 11,
	"stats": 14,
	"description": 10
}

## UI References - these match the scene structure
@onready var card_frame: Panel = $CardFrame
@onready var highlight: ColorRect = $CardFrame/Highlight
@onready var art_panel: Panel = $CardFrame/ArtPanel
@onready var card_art: TextureRect = $CardFrame/ArtPanel/CardArt
@onready var mana_gem: Panel = $CardFrame/ManaGem
@onready var cost_label: Label = $CardFrame/ManaGem/CostLabel
@onready var name_label: Label = $CardFrame/NameLabel
@onready var description_label: RichTextLabel = $CardFrame/DescriptionLabel
@onready var attack_icon: Panel = $CardFrame/AttackIcon
@onready var attack_label: Label = $CardFrame/AttackIcon/AttackLabel
@onready var health_icon: Panel = $CardFrame/HealthIcon
@onready var health_label: Label = $CardFrame/HealthIcon/HealthLabel
@onready var type_icon: TextureRect = $CardFrame/TypeIcon


func _ready() -> void:
	# Ensure visibility
	visible = true
	modulate.a = 1.0
	
	# Set up mouse handling
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Apply responsive sizing
	_apply_responsive_size()
	
	# Apply default styling to panels
	_apply_default_styles()
	
	# Hide highlight initially
	if highlight:
		highlight.visible = false
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Connect mouse signals
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	# Connect to mana changes
	if not GameManager.mana_changed.is_connected(_on_mana_changed):
		GameManager.mana_changed.connect(_on_mana_changed)


func _on_mana_changed(_player_id: int, _current: int, _max_val: int) -> void:
	_update_playability_visual()


## Handle GUI input events
func _gui_input(event: InputEvent) -> void:
	if not is_interactable:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_drag(event.global_position)
			else:
				_end_drag(event.global_position)
			get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		if _is_dragging:
			_update_drag(event.global_position)
			get_viewport().set_input_as_handled()


## Handle mouse enter
func _on_mouse_entered() -> void:
	if current_state == CardState.IN_HAND and is_interactable and not _is_dragging:
		_enter_hover()


## Handle mouse exit
func _on_mouse_exited() -> void:
	if current_state == CardState.HOVERING and not _is_dragging:
		_exit_hover()


## Enter hover state
## MODIFIED: Card hovers in place without affecting other cards
func _enter_hover() -> void:
	current_state = CardState.HOVERING
	
	# Store current local position (relative to parent) for returning later
	_hand_position = position
	
	# Store where we are in global space before enabling top_level
	var current_global := global_position
	
	# Use top_level to render above siblings WITHOUT affecting container layout
	top_level = true
	
	# Restore global position (top_level changes coordinate system)
	global_position = current_global
	z_index = 100
	
	var hover_y_offset := HOVER_Y_OFFSET * get_scale_factor()
	
	# Scale up and move up slightly - card hovers IN PLACE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * HOVER_SCALE, 0.1)
	tween.tween_property(self, "global_position:y", global_position.y + hover_y_offset, 0.1)
	
	# NOTE: We do NOT call queue_sort() on the parent container
	# This means other cards stay exactly where they are


## Exit hover state
## MODIFIED: Returns to exact position without container reorganization
func _exit_hover() -> void:
	current_state = CardState.IN_HAND
	
	# Calculate target global position from stored local position
	var target_global := global_position
	if get_parent():
		target_global = get_parent().global_position + _hand_position
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * NORMAL_SCALE, 0.1)
	tween.tween_property(self, "global_position", target_global, 0.1)
	
	# Restore normal rendering after animation
	tween.chain().tween_callback(_restore_from_top_level)


## Restore card from top_level mode
## MODIFIED: Properly convert position when disabling top_level
func _restore_from_top_level() -> void:
	if current_state == CardState.IN_HAND:
		# Restore the local position BEFORE disabling top_level
		# This prevents the position jump
		position = _hand_position
		top_level = false
		z_index = 0


## Start dragging the card
func _start_drag(global_pos: Vector2) -> void:
	if not GameManager.is_player_turn(owner_id):
		return
	
	if not is_interactable:
		return
	
	# If we're hovering, _hand_position is already set correctly (local coords)
	# If not, store current local position
	if current_state != CardState.HOVERING:
		_hand_position = position
		# Enable top_level if not already
		if not top_level:
			var current_global := global_position
			top_level = true
			global_position = current_global
	
	_hand_index = get_index()
	_drag_offset = global_position - global_pos
	
	current_state = CardState.DRAGGING
	_is_dragging = true
	z_index = 100
	
	# Reset scale during drag
	scale = Vector2.ONE * NORMAL_SCALE
	
	card_drag_started.emit(self)


## Update drag position
func _update_drag(global_pos: Vector2) -> void:
	if not _is_dragging:
		return
	global_position = global_pos + _drag_offset


## End dragging
func _end_drag(global_pos: Vector2) -> void:
	if not _is_dragging:
		return
	
	_is_dragging = false
	current_state = CardState.IN_HAND
	z_index = 0
	
	card_drag_ended.emit(self, global_pos)


## Return card to hand position (called if play fails)
func return_to_hand() -> void:
	current_state = CardState.IN_HAND
	_is_dragging = false
	z_index = 0
	
	# Calculate target global position from stored local position
	var target_global := global_position
	if get_parent():
		target_global = get_parent().global_position + _hand_position
	
	# Animate back to hand position
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", target_global, 0.2)
	tween.tween_callback(_finish_return_to_hand)


## Called after return animation completes
func _finish_return_to_hand() -> void:
	# Restore the local position BEFORE disabling top_level
	position = _hand_position
	top_level = false


## Set whether this card can be interacted with
func set_interactable(interactable: bool) -> void:
	is_interactable = interactable
	_update_playability_visual()


## Store hand position after layout
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_TRANSFORM_CHANGED:
		if current_state == CardState.IN_HAND and not _is_dragging and not top_level:
			# Store LOCAL position (relative to parent container)
			_hand_position = position


## Get responsive scale factor
func get_scale_factor() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	return clamp(viewport_size.y / REFERENCE_HEIGHT, 0.5, 2.0)


## Apply responsive sizing based on viewport
func _apply_responsive_size() -> void:
	var scale_factor := get_scale_factor()
	var scaled_size := BASE_CARD_SIZE * scale_factor
	custom_minimum_size = scaled_size
	size = scaled_size
	
	# Scale font sizes
	if cost_label:
		cost_label.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["cost"] * scale_factor))
	if name_label:
		name_label.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["name"] * scale_factor))
	if attack_label:
		attack_label.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["stats"] * scale_factor))
	if health_label:
		health_label.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["stats"] * scale_factor))
	if description_label:
		description_label.add_theme_font_size_override("normal_font_size", int(BASE_FONT_SIZES["description"] * scale_factor))


## Apply default visual styles
func _apply_default_styles() -> void:
	# Card frame style
	if card_frame:
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(0.15, 0.15, 0.2)
		frame_style.border_color = Color(0.4, 0.35, 0.25)
		frame_style.set_border_width_all(2)
		frame_style.set_corner_radius_all(8)
		card_frame.add_theme_stylebox_override("panel", frame_style)
	
	# Mana gem style
	if mana_gem:
		var gem_style := StyleBoxFlat.new()
		gem_style.bg_color = Color(0.2, 0.4, 0.8)
		gem_style.set_corner_radius_all(12)
		mana_gem.add_theme_stylebox_override("panel", gem_style)
	
	# Attack icon style
	if attack_icon:
		var atk_style := StyleBoxFlat.new()
		atk_style.bg_color = Color(0.8, 0.6, 0.2)
		atk_style.set_corner_radius_all(10)
		attack_icon.add_theme_stylebox_override("panel", atk_style)
	
	# Health icon style
	if health_icon:
		var hp_style := StyleBoxFlat.new()
		hp_style.bg_color = Color(0.7, 0.2, 0.2)
		hp_style.set_corner_radius_all(10)
		health_icon.add_theme_stylebox_override("panel", hp_style)


## Setup the card with data
func setup(data: CardData, player_id: int = 0) -> void:
	card_data = data
	owner_id = player_id
	
	if not is_node_ready():
		await ready
	
	# Update visuals
	if cost_label:
		cost_label.text = str(data.cost)
	if name_label:
		name_label.text = data.card_name
	if attack_label:
		attack_label.text = str(data.attack)
	if health_label:
		health_label.text = str(data.health)
	if description_label:
		description_label.text = data.description
	if card_art and data.texture:
		card_art.texture = data.texture
	
	# Hide stats for action cards
	var is_minion := data.card_type == CardData.CardType.MINION
	if attack_icon:
		attack_icon.visible = is_minion
	if health_icon:
		health_icon.visible = is_minion
	
	# Apply rarity styling
	_apply_rarity_style(data.rarity)
	
	# Update playability
	_update_playability_visual()


## Apply rarity-based border color
func _apply_rarity_style(rarity: CardData.Rarity) -> void:
	if not card_frame:
		return
	
	var border_color: Color
	match rarity:
		CardData.Rarity.COMMON:
			border_color = Color(0.5, 0.5, 0.5)
		CardData.Rarity.RARE:
			border_color = Color(0.3, 0.5, 0.9)
		CardData.Rarity.EPIC:
			border_color = Color(0.6, 0.3, 0.8)
		CardData.Rarity.LEGENDARY:
			border_color = Color(1.0, 0.7, 0.2)
	
	var style: StyleBoxFlat = card_frame.get_theme_stylebox("panel").duplicate()
	style.border_color = border_color
	card_frame.add_theme_stylebox_override("panel", style)


## Update visual to show if card is playable
func _update_playability_visual() -> void:
	if not card_data or not highlight:
		return
	
	var can_play := GameManager.can_play_card(owner_id, card_data) and is_interactable
	highlight.visible = can_play
	
	if can_play:
		highlight.color = Color(0.3, 0.8, 0.3, 0.3)
	else:
		highlight.color = Color(0, 0, 0, 0)
