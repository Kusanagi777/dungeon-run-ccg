# res://scripts/mulligan_screen.gd
extends Control

## Emitted when mulligan is complete for a player
signal mulligan_complete(player_id: int, kept_cards: Array[CardData])

## Scene references
@export var card_ui_scene: PackedScene

## Constants
const CARDS_TO_DRAW: int = 10
const CARDS_TO_KEEP: int = 5
const REFERENCE_HEIGHT: float = 720.0

## UI References
var title_label: Label
var subtitle_label: Label
var instruction_label: Label
var cards_container: HBoxContainer
var confirm_button: Button
var selection_count_label: Label

## State
var player_id: int = 0
var mulligan_cards: Array[CardData] = []
var selected_indices: Array[int] = []
var card_buttons: Array[Control] = []
var is_ai_player: bool = false

## Callback for when mulligan completes
var _on_complete_callback: Callable


func _ready() -> void:
	_setup_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _setup_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.1, 0.95)
	add_child(bg)
	
	# Main container
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_child(main_vbox)
	add_child(margin)
	
	# Title
	title_label = Label.new()
	title_label.text = "Starting Hand"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	main_vbox.add_child(title_label)
	
	# Subtitle (player indicator)
	subtitle_label = Label.new()
	subtitle_label.text = "Player 1"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 20)
	subtitle_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	main_vbox.add_child(subtitle_label)
	
	# Instructions
	instruction_label = Label.new()
	instruction_label.text = "Select %d cards to keep. The rest will be shuffled back into your deck." % CARDS_TO_KEEP
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 16)
	instruction_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	main_vbox.add_child(instruction_label)
	
	# Selection count
	selection_count_label = Label.new()
	selection_count_label.text = "Selected: 0 / %d" % CARDS_TO_KEEP
	selection_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selection_count_label.add_theme_font_size_override("font_size", 18)
	selection_count_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	main_vbox.add_child(selection_count_label)
	
	# Spacer
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 10)
	main_vbox.add_child(top_spacer)
	
	# Cards container with scroll
	var scroll_container := ScrollContainer.new()
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.custom_minimum_size = Vector2(0, 220)
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll_container)
	
	# Center wrapper for cards
	var center_wrapper := CenterContainer.new()
	center_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(center_wrapper)
	
	cards_container = HBoxContainer.new()
	cards_container.add_theme_constant_override("separation", 15)
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	center_wrapper.add_child(cards_container)
	
	# Bottom spacer
	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(bottom_spacer)
	
	# Confirm button
	var button_container := CenterContainer.new()
	main_vbox.add_child(button_container)
	
	confirm_button = Button.new()
	confirm_button.text = "Confirm Selection"
	confirm_button.custom_minimum_size = Vector2(200, 50)
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_pressed)
	button_container.add_child(confirm_button)
	
	_style_confirm_button()
	_apply_responsive_fonts()


func _style_confirm_button() -> void:
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.5, 0.3)
	normal_style.border_color = Color(0.3, 0.7, 0.4)
	normal_style.set_border_width_all(2)
	normal_style.set_corner_radius_all(8)
	normal_style.set_content_margin_all(12)
	confirm_button.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.6, 0.35)
	confirm_button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.15, 0.4, 0.25)
	confirm_button.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = Color(0.15, 0.15, 0.18)
	disabled_style.border_color = Color(0.3, 0.3, 0.3)
	disabled_style.set_border_width_all(2)
	disabled_style.set_corner_radius_all(8)
	disabled_style.set_content_margin_all(12)
	confirm_button.add_theme_stylebox_override("disabled", disabled_style)


## Initialize mulligan for a player
func start_mulligan(pid: int, cards: Array[CardData], is_ai: bool = false, callback: Callable = Callable()) -> void:
	player_id = pid
	mulligan_cards = cards
	is_ai_player = is_ai
	selected_indices.clear()
	card_buttons.clear()
	_on_complete_callback = callback
	
	# Update UI
	subtitle_label.text = "Player %d" % (pid + 1)
	if is_ai:
		subtitle_label.text += " (AI)"
	
	# Clear existing cards
	for child in cards_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Create card displays
	_create_card_displays()
	
	# AI auto-selects
	if is_ai:
		_ai_select_cards()
	
	_update_selection_display()
	visible = true


## Create visual card displays
func _create_card_displays() -> void:
	for i in range(mulligan_cards.size()):
		var card_data: CardData = mulligan_cards[i]
		var card_wrapper := _create_card_wrapper(card_data, i)
		cards_container.add_child(card_wrapper)
		card_buttons.append(card_wrapper)


func _create_card_wrapper(card_data: CardData, index: int) -> Control:
	var wrapper := PanelContainer.new()
	wrapper.custom_minimum_size = Vector2(100, 150)
	
	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	wrapper.add_theme_stylebox_override("panel", style)
	
	# Content margin
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	wrapper.add_child(margin)
	
	# Content vbox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	
	# Cost
	var cost_label := Label.new()
	cost_label.text = "💧%d" % card_data.cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 16)
	cost_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	vbox.add_child(cost_label)
	
	# Name
	var name_label := Label.new()
	name_label.text = card_data.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(80, 0)
	vbox.add_child(name_label)
	
	# Stats (for minions)
	if card_data.card_type == CardData.CardType.MINION:
		var stats_label := Label.new()
		stats_label.text = "⚔️%d  ❤️%d" % [card_data.attack, card_data.health]
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_label.add_theme_font_size_override("font_size", 14)
		stats_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		vbox.add_child(stats_label)
	else:
		# Type indicator for non-minions
		var type_label := Label.new()
		type_label.text = _get_card_type_name(card_data.card_type)
		type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_label.add_theme_font_size_override("font_size", 11)
		type_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9))
		vbox.add_child(type_label)
	
	# Selection indicator
	var select_indicator := Label.new()
	select_indicator.name = "SelectIndicator"
	select_indicator.text = "✓"
	select_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	select_indicator.add_theme_font_size_override("font_size", 24)
	select_indicator.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	select_indicator.visible = false
	vbox.add_child(select_indicator)
	
	# Make clickable
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.gui_input.connect(_on_card_input.bind(index))
	wrapper.mouse_entered.connect(_on_card_hover.bind(index, true))
	wrapper.mouse_exited.connect(_on_card_hover.bind(index, false))
	
	# Store index
	wrapper.set_meta("card_index", index)
	
	return wrapper


func _get_card_type_name(card_type: CardData.CardType) -> String:
	match card_type:
		CardData.CardType.MINION:
			return "Minion"
		CardData.CardType.ACTION:
			return "Action"
		CardData.CardType.LOCATION:
			return "Location"
		_:
			return "Card"


func _on_card_input(event: InputEvent, index: int) -> void:
	if is_ai_player:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_card_selection(index)


func _on_card_hover(index: int, hovering: bool) -> void:
	if index >= card_buttons.size():
		return
	
	var wrapper: PanelContainer = card_buttons[index]
	var is_selected := index in selected_indices
	
	var style: StyleBoxFlat = wrapper.get_theme_stylebox("panel").duplicate()
	
	if hovering and not is_ai_player:
		style.border_color = Color(0.8, 0.7, 0.4)
		wrapper.scale = Vector2(1.05, 1.05)
	else:
		if is_selected:
			style.border_color = Color(0.3, 1.0, 0.5)
			style.bg_color = Color(0.1, 0.25, 0.15)
		else:
			style.border_color = Color(0.3, 0.3, 0.35)
			style.bg_color = Color(0.12, 0.14, 0.18)
		wrapper.scale = Vector2.ONE
	
	wrapper.add_theme_stylebox_override("panel", style)


func _toggle_card_selection(index: int) -> void:
	if index in selected_indices:
		# Deselect
		selected_indices.erase(index)
	else:
		# Select (if we haven't hit the limit)
		if selected_indices.size() < CARDS_TO_KEEP:
			selected_indices.append(index)
	
	_update_selection_display()


func _update_selection_display() -> void:
	# Update count label
	selection_count_label.text = "Selected: %d / %d" % [selected_indices.size(), CARDS_TO_KEEP]
	
	if selected_indices.size() == CARDS_TO_KEEP:
		selection_count_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		selection_count_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	
	# Update card visuals
	for i in range(card_buttons.size()):
		var wrapper: PanelContainer = card_buttons[i]
		var is_selected := i in selected_indices
		
		# Update style
		var style := StyleBoxFlat.new()
		if is_selected:
			style.bg_color = Color(0.1, 0.25, 0.15)
			style.border_color = Color(0.3, 1.0, 0.5)
		else:
			style.bg_color = Color(0.12, 0.14, 0.18)
			style.border_color = Color(0.3, 0.3, 0.35)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		wrapper.add_theme_stylebox_override("panel", style)
		
		# Update checkmark
		var indicator := wrapper.find_child("SelectIndicator", true, false)
		if indicator:
			indicator.visible = is_selected
	
	# Enable/disable confirm button
	confirm_button.disabled = selected_indices.size() != CARDS_TO_KEEP


func _ai_select_cards() -> void:
	# AI strategy: prefer lower cost cards for a smoother curve
	var indexed_cards: Array = []
	for i in range(mulligan_cards.size()):
		indexed_cards.append({"index": i, "cost": mulligan_cards[i].cost})
	
	# Sort by cost (prefer lower)
	indexed_cards.sort_custom(func(a, b): return a["cost"] < b["cost"])
	
	# Select the first CARDS_TO_KEEP cards (lowest cost)
	selected_indices.clear()
	for i in range(CARDS_TO_KEEP):
		if i < indexed_cards.size():
			selected_indices.append(indexed_cards[i]["index"])
	
	# Auto-confirm after a short delay
	await get_tree().create_timer(0.5).timeout
	_on_confirm_pressed()


func _on_confirm_pressed() -> void:
	if selected_indices.size() != CARDS_TO_KEEP:
		return
	
	# Build kept cards array
	var kept_cards: Array[CardData] = []
	for index in selected_indices:
		if index < mulligan_cards.size():
			kept_cards.append(mulligan_cards[index])
	
	# Build returned cards array
	var returned_cards: Array[CardData] = []
	for i in range(mulligan_cards.size()):
		if i not in selected_indices:
			returned_cards.append(mulligan_cards[i])
	
	print("[MulliganScreen] Player %d kept %d cards, returning %d to deck" % [player_id, kept_cards.size(), returned_cards.size()])
	
	# Emit signal
	mulligan_complete.emit(player_id, kept_cards)
	
	# Call callback if provided
	if _on_complete_callback.is_valid():
		_on_complete_callback.call(player_id, kept_cards, returned_cards)
	
	visible = false


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _apply_responsive_fonts() -> void:
	var scale := get_scale_factor()
	
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(36 * scale))
	if subtitle_label:
		subtitle_label.add_theme_font_size_override("font_size", int(20 * scale))
	if instruction_label:
		instruction_label.add_theme_font_size_override("font_size", int(16 * scale))
	if selection_count_label:
		selection_count_label.add_theme_font_size_override("font_size", int(18 * scale))


func get_scale_factor() -> float:
	var viewport_size := DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 2.0)
