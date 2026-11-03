# res://scripts/faction_selection.gd
extends Control

## Faction data structure
const FACTIONS = {
	"red": {
		"name": "Red Faction",
		"color": Color(0.85, 0.2, 0.2),
		"description": "Aggressive and powerful. Red favors direct combat and overwhelming force.",
		"icon": "🔴"
	},
	"blue": {
		"name": "Blue Faction", 
		"color": Color(0.2, 0.4, 0.85),
		"description": "Strategic and cunning. Blue excels at control and manipulation.",
		"icon": "🔵"
	}
}

## UI References
var title_label: Label
var faction_container: HBoxContainer
var description_label: RichTextLabel
var back_button: Button
var confirm_button: Button

## Currently selected faction
var selected_faction: String = ""

## Reference resolution
const REFERENCE_HEIGHT = 720.0


func _ready() -> void:
	_setup_ui()
	_create_faction_buttons()
	_apply_styling()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _setup_ui() -> void:
	# Create main layout
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 30)
	add_child(main_vbox)
	
	# Spacer top
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size.y = 50
	main_vbox.add_child(top_spacer)
	
	# Title
	title_label = Label.new()
	title_label.text = "Choose Your Faction"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	main_vbox.add_child(title_label)
	
	# Faction buttons container (centered)
	var center_container = CenterContainer.new()
	center_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(center_container)
	
	faction_container = HBoxContainer.new()
	faction_container.add_theme_constant_override("separation", 80)
	center_container.add_child(faction_container)
	
	# Description area
	var desc_container = PanelContainer.new()
	desc_container.custom_minimum_size = Vector2(600, 80)
	desc_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(desc_container)
	
	description_label = RichTextLabel.new()
	description_label.bbcode_enabled = true
	description_label.fit_content = true
	description_label.scroll_active = false
	description_label.text = "[center]Select a faction to continue[/center]"
	desc_container.add_child(description_label)
	
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


func _create_faction_buttons() -> void:
	for faction_id in FACTIONS:
		var faction_data = FACTIONS[faction_id]
		var btn = _create_faction_button(faction_id, faction_data)
		faction_container.add_child(btn)


func _create_faction_button(faction_id: String, data: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 250)
	panel.set_meta("faction_id", faction_id)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)
	
	# Faction icon
	var icon_label = Label.new()
	icon_label.text = data["icon"]
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 72)
	vbox.add_child(icon_label)
	
	# Faction name
	var name_label = Label.new()
	name_label.text = data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", data["color"])
	vbox.add_child(name_label)
	
	# Make clickable
	panel.gui_input.connect(_on_faction_gui_input.bind(faction_id))
	panel.mouse_entered.connect(_on_faction_hover.bind(faction_id, panel))
	panel.mouse_exited.connect(_on_faction_exit.bind(panel))
	
	return panel


func _on_faction_gui_input(event: InputEvent, faction_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_faction(faction_id)


func _select_faction(faction_id: String) -> void:
	selected_faction = faction_id
	var data = FACTIONS[faction_id]
	
	# Update description
	description_label.text = "[center]%s[/center]" % data["description"]
	
	# Update visual selection
	for child in faction_container.get_children():
		var panel = child as PanelContainer
		if panel:
			var is_selected = panel.get_meta("faction_id") == faction_id
			_style_faction_panel(panel, is_selected, FACTIONS[panel.get_meta("faction_id")]["color"])
	
	# Enable confirm button
	confirm_button.disabled = false


func _on_faction_hover(faction_id: String, panel: PanelContainer) -> void:
	if selected_faction != faction_id:
		panel.modulate = Color(1.1, 1.1, 1.1)
	
	# Show hover description
	if selected_faction.is_empty():
		description_label.text = "[center]%s[/center]" % FACTIONS[faction_id]["description"]


func _on_faction_exit(panel: PanelContainer) -> void:
	var faction_id = panel.get_meta("faction_id")
	if selected_faction != faction_id:
		panel.modulate = Color.WHITE
	
	# Restore description
	if selected_faction.is_empty():
		description_label.text = "[center]Select a faction to continue[/center]"
	else:
		description_label.text = "[center]%s[/center]" % FACTIONS[selected_faction]["description"]


func _style_faction_panel(panel: PanelContainer, selected: bool, faction_color: Color) -> void:
	var style = StyleBoxFlat.new()
	
	if selected:
		style.bg_color = faction_color.darkened(0.7)
		style.border_color = faction_color
		style.set_border_width_all(4)
		panel.modulate = Color(1.2, 1.2, 1.2)
	else:
		style.bg_color = Color(0.15, 0.17, 0.22)
		style.border_color = Color(0.3, 0.3, 0.35)
		style.set_border_width_all(2)
		panel.modulate = Color.WHITE
	
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _on_confirm_pressed() -> void:
	if selected_faction.is_empty():
		return
	
	# Store selection in GameManager
	GameManager.set_meta("selected_faction", {
		"id": selected_faction,
		"name": FACTIONS[selected_faction]["name"],
		"color": FACTIONS[selected_faction]["color"]
	})
	
	print("[FactionSelection] Selected faction: %s" % selected_faction)
	
	# Go to Aspect selection
	get_tree().change_scene_to_file("res://scenes/aspect_selection.tscn")


func _apply_styling() -> void:
	# Style faction panels
	for child in faction_container.get_children():
		var panel = child as PanelContainer
		if panel:
			var faction_id = panel.get_meta("faction_id")
			_style_faction_panel(panel, false, FACTIONS[faction_id]["color"])
	
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
		title_label.add_theme_font_size_override("font_size", int(48 * s))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
		elif event.keycode == KEY_ENTER and not confirm_button.disabled:
			_on_confirm_pressed()
