extends Control

## Emitted when a card is selected
signal discovery_complete(selected_card: CardData)

## UI References
var title_label: Label
var cards_container: HBoxContainer
var confirm_button: Button
var instruction_label: Label

## State
var discover_cards: Array[CardData] = []
var selected_index: int = -1
var card_buttons: Array[Control] = []
var _on_complete_callback: Callable

const REFERENCE_HEIGHT: float = 720.0

func _ready() -> void:
	_setup_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _setup_ui() -> void:
	# Background (Semi-transparent overlay)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.1, 0.9)
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
	title_label.text = "Discover"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	main_vbox.add_child(title_label)
	
	# Instruction
	instruction_label = Label.new()
	instruction_label.text = "Choose a card"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 20)
	instruction_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	main_vbox.add_child(instruction_label)
	
	# Spacer
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(top_spacer)
	
	# Cards container
	var center_wrapper := CenterContainer.new()
	center_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(center_wrapper)
	
	cards_container = HBoxContainer.new()
	cards_container.add_theme_constant_override("separation", 25)
	cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
	center_wrapper.add_child(cards_container)
	
	# Spacer
	var bottom_spacer := Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 30)
	main_vbox.add_child(bottom_spacer)
	
	# Confirm button
	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	confirm_button.custom_minimum_size = Vector2(180, 50)
	confirm_button.disabled = true
	confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_button.pressed.connect(_on_confirm_pressed)
	main_vbox.add_child(confirm_button)
	
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


func start_discovery(cards: Array, title: String = "Discover", callback: Callable = Callable()) -> void:
	discover_cards = []
	# Cast to typed array
	for c in cards:
		if c is CardData:
			discover_cards.append(c)
			
	_on_complete_callback = callback
	selected_index = -1
	title_label.text = title
	confirm_button.disabled = true
	
	# Clear existing
	for child in cards_container.get_children():
		child.queue_free()
		
	card_buttons.clear()
	
	await get_tree().process_frame
	
	# Create displays
	for i in range(discover_cards.size()):
		var card = discover_cards[i]
		var wrapper = _create_card_wrapper(card, i)
		cards_container.add_child(wrapper)
		card_buttons.append(wrapper)
		
	visible = true


func _create_card_wrapper(card_data: CardData, index: int) -> Control:
	var wrapper := PanelContainer.new()
	wrapper.custom_minimum_size = Vector2(140, 200)
	
	# Style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.14, 0.18)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	wrapper.add_theme_stylebox_override("panel", style)
	
	# Content margin
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	wrapper.add_child(margin)
	
	# Content vbox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	
	# Cost
	var cost_label := Label.new()
	cost_label.text = "💧%d" % card_data.cost
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	vbox.add_child(cost_label)
	
	# Name
	var name_label := Label.new()
	name_label.text = card_data.card_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(100, 0)
	vbox.add_child(name_label)
	
	# Stats
	if card_data.card_type == CardData.CardType.MINION:
		var stats_label := Label.new()
		stats_label.text = "⚔️%d  ❤️%d" % [card_data.attack, card_data.health]
		stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats_label.add_theme_font_size_override("font_size", 16)
		stats_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
		vbox.add_child(stats_label)
	
	# Description (simplified)
	var desc_label := RichTextLabel.new()
	desc_label.text = card_data.description
	desc_label.fit_content = true
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_label.add_theme_font_size_override("normal_font_size", 10)
	vbox.add_child(desc_label)
	
	# Mouse handling
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	wrapper.gui_input.connect(_on_card_input.bind(index))
	wrapper.mouse_entered.connect(_on_card_hover.bind(index, true))
	wrapper.mouse_exited.connect(_on_card_hover.bind(index, false))
	
	return wrapper


func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_card(index)
		# Optional: Double click to confirm
		if event.double_click:
			_on_confirm_pressed()


func _select_card(index: int) -> void:
	# Update old selection style
	if selected_index >= 0 and selected_index < card_buttons.size():
		var old_wrapper = card_buttons[selected_index] as PanelContainer
		var style = old_wrapper.get_theme_stylebox("panel")
		style.border_color = Color(0.3, 0.3, 0.35)
		style.bg_color = Color(0.12, 0.14, 0.18)
	
	selected_index = index
	confirm_button.disabled = false
	
	# Update new selection style
	var wrapper = card_buttons[index] as PanelContainer
	var style = wrapper.get_theme_stylebox("panel")
	style.border_color = Color(0.3, 1.0, 0.5)
	style.bg_color = Color(0.1, 0.25, 0.15)


func _on_card_hover(index: int, hovering: bool) -> void:
	if index == selected_index:
		return
		
	var wrapper = card_buttons[index]
	var style = wrapper.get_theme_stylebox("panel")
	
	if hovering:
		style.border_color = Color(0.8, 0.7, 0.4)
		wrapper.scale = Vector2(1.05, 1.05)
	else:
		style.border_color = Color(0.3, 0.3, 0.35)
		wrapper.scale = Vector2.ONE


func _on_confirm_pressed() -> void:
	if selected_index < 0:
		return
		
	var selected_card = discover_cards[selected_index]
	print("[DiscoverSelection] Selected: %s" % selected_card.card_name)
	
	visible = false
	discovery_complete.emit(selected_card)
	
	if _on_complete_callback.is_valid():
		_on_complete_callback.call(selected_card)


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _apply_responsive_fonts() -> void:
	var scale := get_scale_factor()
	
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(36 * scale))
	if instruction_label:
		instruction_label.add_theme_font_size_override("font_size", int(20 * scale))


func get_scale_factor() -> float:
	var viewport_size := DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 2.0)
