# res://scripts/aspect_selection.gd
extends Control

## Aspects available for each faction
## These define playstyle variations within each faction
const ASPECTS = {
	"red": [
		{
			"id": "fury",
			"name": "Fury",
			"icon": "🔥",
			"description": "Embrace raw aggression. Your minions hit harder but are more fragile.",
			"passive": "+1 Attack to all minions, -1 Health to all minions"
		},
		{
			"id": "bloodlust",
			"name": "Bloodlust", 
			"icon": "💉",
			"description": "Feed on destruction. Gain power when your minions die.",
			"passive": "Draw a card when a friendly minion dies"
		},
		{
			"id": "rampage",
			"name": "Rampage",
			"icon": "💢",
			"description": "Unstoppable momentum. Damaged minions become more dangerous.",
			"passive": "Damaged friendly minions gain +1 Attack"
		}
	],
	"blue": [
		{
			"id": "control",
			"name": "Control",
			"icon": "🛡️",
			"description": "Patience wins wars. Outlast your opponents with superior defense.",
			"passive": "+1 Health to all minions"
		},
		{
			"id": "cunning",
			"name": "Cunning",
			"icon": "🎭",
			"description": "Knowledge is power. See more options, make better choices.",
			"passive": "Start with +1 card in hand"
		},
		{
			"id": "frost",
			"name": "Frost",
			"icon": "❄️",
			"description": "Slow and steady. Freeze enemies in their tracks.",
			"passive": "Minions you summon slow enemy minions for 1 turn"
		}
	]
}

## UI References
var title_label: Label
var faction_indicator: Label
var aspect_container: HBoxContainer
var description_panel: PanelContainer
var description_label: RichTextLabel
var passive_label: Label
var back_button: Button
var confirm_button: Button

## Currently selected aspect
var selected_aspect: Dictionary = {}

## Current faction data
var current_faction: Dictionary = {}

## Reference resolution
const REFERENCE_HEIGHT = 720.0


func _ready() -> void:
	# Get faction from GameManager
	if GameManager.has_meta("selected_faction"):
		current_faction = GameManager.get_meta("selected_faction")
	else:
		# Fallback if no faction selected
		push_error("No faction selected! Returning to faction selection.")
		get_tree().change_scene_to_file("res://scenes/faction_selection.tscn")
		return
	
	_setup_ui()
	_create_aspect_buttons()
	_apply_styling()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _setup_ui() -> void:
	# Create main layout
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)
	
	# Top spacer
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size.y = 30
	main_vbox.add_child(top_spacer)
	
	# Faction indicator
	faction_indicator = Label.new()
	faction_indicator.text = "%s" % current_faction.get("name", "Unknown Faction")
	faction_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	faction_indicator.add_theme_font_size_override("font_size", 20)
	faction_indicator.add_theme_color_override("font_color", current_faction.get("color", Color.WHITE))
	main_vbox.add_child(faction_indicator)
	
	# Title
	title_label = Label.new()
	title_label.text = "Choose Your Aspect"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 42)
	main_vbox.add_child(title_label)
	
	# Aspect buttons container
	var center_container = CenterContainer.new()
	center_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(center_container)
	
	aspect_container = HBoxContainer.new()
	aspect_container.add_theme_constant_override("separation", 40)
	center_container.add_child(aspect_container)
	
	# Description panel
	description_panel = PanelContainer.new()
	description_panel.custom_minimum_size = Vector2(650, 100)
	description_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(description_panel)
	
	var desc_vbox = VBoxContainer.new()
	desc_vbox.add_theme_constant_override("separation", 10)
	description_panel.add_child(desc_vbox)
	
	description_label = RichTextLabel.new()
	description_label.bbcode_enabled = true
	description_label.fit_content = true
	description_label.scroll_active = false
	description_label.text = "[center]Select an Aspect to define your playstyle[/center]"
	desc_vbox.add_child(description_label)
	
	passive_label = Label.new()
	passive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive_label.add_theme_font_size_override("font_size", 14)
	passive_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.6))
	desc_vbox.add_child(passive_label)
	
	# Button row
	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 20)
	main_vbox.add_child(button_row)
	
	back_button = Button.new()
	back_button.text = "← Back"
	back_button.custom_minimum_size = Vector2(120, 40)
	back_button.pressed.connect(_on_back_pressed)
	button_row.add_child(back_button)
	
	confirm_button = Button.new()
	confirm_button.text = "Confirm →"
	confirm_button.custom_minimum_size = Vector2(120, 40)
	confirm_button.disabled = true
	confirm_button.pressed.connect(_on_confirm_pressed)
	button_row.add_child(confirm_button)
	
	# Bottom spacer
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size.y = 30
	main_vbox.add_child(bottom_spacer)


func _create_aspect_buttons() -> void:
	var faction_id = current_faction.get("id", "red")
	var aspects = ASPECTS.get(faction_id, [])
	
	for aspect in aspects:
		var btn = _create_aspect_button(aspect)
		aspect_container.add_child(btn)


func _create_aspect_button(aspect: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 220)
	panel.set_meta("aspect_data", aspect)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	# Aspect icon
	var icon_label = Label.new()
	icon_label.text = aspect["icon"]
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 56)
	vbox.add_child(icon_label)
	
	# Aspect name
	var name_label = Label.new()
	name_label.text = aspect["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", current_faction.get("color", Color.WHITE).lightened(0.2))
	vbox.add_child(name_label)
	
	# Make clickable
	panel.gui_input.connect(_on_aspect_gui_input.bind(aspect))
	panel.mouse_entered.connect(_on_aspect_hover.bind(aspect, panel))
	panel.mouse_exited.connect(_on_aspect_exit.bind(panel))
	
	return panel


func _on_aspect_gui_input(event: InputEvent, aspect: Dictionary) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_aspect(aspect)


func _select_aspect(aspect: Dictionary) -> void:
	selected_aspect = aspect
	
	# Update description
	description_label.text = "[center]%s[/center]" % aspect["description"]
	passive_label.text = "Passive: %s" % aspect["passive"]
	
	# Update visual selection
	for child in aspect_container.get_children():
		var panel = child as PanelContainer
		if panel:
			var panel_aspect = panel.get_meta("aspect_data")
			var is_selected = panel_aspect["id"] == aspect["id"]
			_style_aspect_panel(panel, is_selected)
	
	# Enable confirm button
	confirm_button.disabled = false


func _on_aspect_hover(aspect: Dictionary, panel: PanelContainer) -> void:
	var panel_aspect = panel.get_meta("aspect_data")
	if selected_aspect.is_empty() or selected_aspect["id"] != panel_aspect["id"]:
		panel.modulate = Color(1.1, 1.1, 1.1)
	
	# Show hover description
	if selected_aspect.is_empty():
		description_label.text = "[center]%s[/center]" % aspect["description"]
		passive_label.text = "Passive: %s" % aspect["passive"]


func _on_aspect_exit(panel: PanelContainer) -> void:
	var panel_aspect = panel.get_meta("aspect_data")
	if selected_aspect.is_empty() or selected_aspect["id"] != panel_aspect["id"]:
		panel.modulate = Color.WHITE
	
	# Restore description
	if selected_aspect.is_empty():
		description_label.text = "[center]Select an Aspect to define your playstyle[/center]"
		passive_label.text = ""
	else:
		description_label.text = "[center]%s[/center]" % selected_aspect["description"]
		passive_label.text = "Passive: %s" % selected_aspect["passive"]


func _style_aspect_panel(panel: PanelContainer, selected: bool) -> void:
	var faction_color = current_faction.get("color", Color(0.4, 0.4, 0.5))
	var style = StyleBoxFlat.new()
	
	if selected:
		style.bg_color = faction_color.darkened(0.65)
		style.border_color = faction_color
		style.set_border_width_all(3)
		panel.modulate = Color(1.15, 1.15, 1.15)
	else:
		style.bg_color = Color(0.12, 0.14, 0.2)
		style.border_color = Color(0.3, 0.3, 0.35)
		style.set_border_width_all(2)
		panel.modulate = Color.WHITE
	
	style.set_corner_radius_all(10)
	style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", style)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/faction_selection.tscn")


func _on_confirm_pressed() -> void:
	if selected_aspect.is_empty():
		return
	
	# Store aspect selection in GameManager
	GameManager.set_meta("selected_aspect", selected_aspect)
	
	print("[AspectSelection] Selected aspect: %s" % selected_aspect["name"])
	
	# Go to deck selection (15-card deck)
	get_tree().change_scene_to_file("res://scenes/deck_selection.tscn")


func _apply_styling() -> void:
	# Style aspect panels
	for child in aspect_container.get_children():
		var panel = child as PanelContainer
		if panel:
			_style_aspect_panel(panel, false)
	
	# Style description panel
	var desc_style = StyleBoxFlat.new()
	desc_style.bg_color = Color(0.1, 0.12, 0.18)
	desc_style.border_color = current_faction.get("color", Color(0.4, 0.4, 0.5)).darkened(0.3)
	desc_style.set_border_width_all(2)
	desc_style.set_corner_radius_all(8)
	desc_style.set_content_margin_all(15)
	description_panel.add_theme_stylebox_override("panel", desc_style)
	
	# Style buttons
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.25, 0.35)
	btn_style.border_color = Color(0.5, 0.45, 0.3)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(10)
	
	back_button.add_theme_stylebox_override("normal", btn_style)
	confirm_button.add_theme_stylebox_override("normal", btn_style)
	
	var disabled_style = btn_style.duplicate()
	disabled_style.bg_color = Color(0.15, 0.15, 0.18)
	disabled_style.border_color = Color(0.3, 0.3, 0.3)
	confirm_button.add_theme_stylebox_override("disabled", disabled_style)


func get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 3.0)


func _on_viewport_size_changed() -> void:
	var s = get_scale_factor()
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(42 * s))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
		elif event.keycode == KEY_ENTER and not confirm_button.disabled:
			_on_confirm_pressed()
