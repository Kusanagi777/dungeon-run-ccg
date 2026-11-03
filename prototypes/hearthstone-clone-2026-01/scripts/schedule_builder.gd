# res://scripts/schedule_builder.gd
extends Control

## Emitted when the schedule is finalized
signal schedule_confirmed(schedule: Array)

## Maximum number of activities allowed in the schedule
const MAX_SLOTS: int = 5
const REFERENCE_HEIGHT: float = 720.0

## Available Activity Types
var activities: Dictionary = {
	"duel": {
		"id": "duel",
		"name": "Duel",
		"description": "Fight a standard opponent to earn XP and Card Packs.",
		"icon": "⚔️",
		"color": Color(0.9, 0.3, 0.3)  # Red
	},
	"champion": {
		"id": "champion",
		"name": "Champion",
		"description": "Challenge an Elite opponent. High risk, high reward.",
		"icon": "🏆",
		"color": Color(1.0, 0.8, 0.2)  # Gold
	},
	"side_job": {
		"id": "side_job",
		"name": "Side Job",
		"description": "Work a shift to earn 150 Gold for the shop.",
		"icon": "💰",
		"color": Color(0.4, 0.8, 0.4)  # Green
	},
	"shop": {
		"id": "shop",
		"name": "Shop",
		"description": "Visit the merchant to buy cards and upgrades.",
		"icon": "🛒",
		"color": Color(0.3, 0.6, 0.9)  # Blue
	}
}

## Current Schedule - using untyped Array to avoid meta storage issues
var current_schedule: Array = []

## UI References
var title_label: Label
var slots_container: HBoxContainer
var activities_container: HBoxContainer
var description_label: RichTextLabel
var confirm_button: Button
var back_button: Button

## Slot UI elements (to update visuals dynamically)
var slot_panels: Array[PanelContainer] = []
var slot_icon_labels: Array[Label] = []
var slot_name_labels: Array[Label] = []


func _ready() -> void:
	_setup_ui()
	_apply_styling()
	_update_slots_visuals()
	
	# Connect to viewport resize for responsive UI
	get_viewport().size_changed.connect(_on_viewport_size_changed)


## --- UI Construction (Code-Driven) ---

func _setup_ui() -> void:
	# 1. Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.1, 0.14)  # Dark background matching other scenes
	add_child(bg)

	# 2. Main Layout
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	
	# Margins
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	margin.add_child(main_vbox)

	# 3. Title
	title_label = Label.new()
	title_label.text = "Plan Your Week (%d/%d)" % [current_schedule.size(), MAX_SLOTS]
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	main_vbox.add_child(title_label)
	
	main_vbox.add_child(HSeparator.new())

	# 4. Schedule Slots Display (The 5 empty/filled boxes)
	var slots_label = Label.new()
	slots_label.text = "Your Schedule"
	slots_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slots_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	main_vbox.add_child(slots_label)

	slots_container = HBoxContainer.new()
	slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_container.add_theme_constant_override("separation", 15)
	main_vbox.add_child(slots_container)
	
	# Create the 5 slot placeholders
	for i in range(MAX_SLOTS):
		var slot_data = _create_slot_ui(i)
		var slot_panel = slot_data["panel"]
		slots_container.add_child(slot_panel)
		slot_panels.append(slot_panel)
		slot_icon_labels.append(slot_data["icon"])
		slot_name_labels.append(slot_data["name"])

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	main_vbox.add_child(spacer1)

	# 5. Activity Selection Buttons
	var activities_label = Label.new()
	activities_label.text = "Available Activities"
	activities_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activities_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	main_vbox.add_child(activities_label)

	activities_container = HBoxContainer.new()
	activities_container.alignment = BoxContainer.ALIGNMENT_CENTER
	activities_container.add_theme_constant_override("separation", 20)
	main_vbox.add_child(activities_container)

	# Create buttons for Duel, Champion, Side Job, Shop
	for id in ["duel", "champion", "side_job", "shop"]:
		var btn = _create_activity_button(activities[id])
		activities_container.add_child(btn)

	# 6. Description / Info Panel
	var desc_panel = PanelContainer.new()
	desc_panel.custom_minimum_size = Vector2(600, 80)
	desc_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var desc_style = StyleBoxFlat.new()
	desc_style.bg_color = Color(0.12, 0.12, 0.15, 0.8)
	desc_style.border_color = Color(0.4, 0.35, 0.3)
	desc_style.set_border_width_all(1)
	desc_style.set_corner_radius_all(8)
	desc_panel.add_theme_stylebox_override("panel", desc_style)
	
	var desc_margin = MarginContainer.new()
	desc_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	desc_margin.add_theme_constant_override("margin_left", 15)
	desc_margin.add_theme_constant_override("margin_right", 15)
	desc_margin.add_theme_constant_override("margin_top", 10)
	desc_margin.add_theme_constant_override("margin_bottom", 10)
	
	description_label = RichTextLabel.new()
	description_label.bbcode_enabled = true
	description_label.fit_content = true
	description_label.text = "[center]Select an activity to add it to your schedule.[/center]"
	
	desc_margin.add_child(description_label)
	desc_panel.add_child(desc_margin)
	main_vbox.add_child(desc_panel)

	# Spacer
	var spacer2 = Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer2)

	# 7. Action Buttons (Back / Confirm)
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 40)
	main_vbox.add_child(btn_hbox)

	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(150, 50)
	back_button.pressed.connect(_on_back_pressed)
	btn_hbox.add_child(back_button)

	confirm_button = Button.new()
	confirm_button.text = "Start Week"
	confirm_button.custom_minimum_size = Vector2(200, 50)
	confirm_button.disabled = true  # Disabled until schedule is full
	confirm_button.pressed.connect(_on_confirm_pressed)
	btn_hbox.add_child(confirm_button)

	_apply_responsive_fonts()


## Helper to create the visual slot boxes
func _create_slot_ui(index: int) -> Dictionary:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 150)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	# Internal layout
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	# Day Label (Day 1, Day 2, etc.)
	var day_label = Label.new()
	day_label.text = "Day %d" % (index + 1)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size", 14)
	day_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	vbox.add_child(day_label)
	
	# Centered container for icon and name
	var center = MarginContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_theme_constant_override("margin_left", 10)
	center.add_theme_constant_override("margin_right", 10)
	center.add_theme_constant_override("margin_top", 15)
	center.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(center)
	
	var center_vbox = VBoxContainer.new()
	center_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_vbox.add_theme_constant_override("separation", 5)
	center.add_child(center_vbox)
	
	# Icon
	var icon_label = Label.new()
	icon_label.text = "+"
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
	center_vbox.add_child(icon_label)
	
	# Name
	var name_label = Label.new()
	name_label.text = "Empty"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	center_vbox.add_child(name_label)
	
	# Make clickable for removal
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_remove_activity_at(index)
	)
	
	return {
		"panel": panel,
		"icon": icon_label,
		"name": name_label
	}


## Helper to create activity selection buttons
func _create_activity_button(activity_data: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(130, 100)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn.add_child(vbox)
	
	var icon = Label.new()
	icon.text = activity_data["icon"]
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 32)
	vbox.add_child(icon)
	
	var name_lbl = Label.new()
	name_lbl.text = activity_data["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", activity_data["color"])
	vbox.add_child(name_lbl)
	
	# Style the button
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.18, 0.22)
	style.border_color = activity_data["color"].darkened(0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.2, 0.24, 0.28)
	hover_style.border_color = activity_data["color"]
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = Color(0.12, 0.14, 0.18)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.1, 0.1, 0.12)
	disabled_style.border_color = Color(0.2, 0.2, 0.25)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	
	btn.pressed.connect(func():
		_add_activity(activity_data["id"])
		_show_description(activity_data["description"])
	)
	
	btn.mouse_entered.connect(func():
		_show_description(activity_data["description"])
	)
	
	return btn


## --- Logic ---

func _add_activity(activity_id: String) -> void:
	if current_schedule.size() >= MAX_SLOTS:
		return
	
	# Store as plain string in untyped array
	current_schedule.append(activity_id)
	print("[ScheduleBuilder] Added activity: %s, schedule: %s" % [activity_id, current_schedule])
	_update_slots_visuals()
	_update_state()


func _remove_activity_at(index: int) -> void:
	if index < current_schedule.size():
		var removed = current_schedule[index]
		current_schedule.remove_at(index)
		print("[ScheduleBuilder] Removed activity at %d: %s, schedule: %s" % [index, removed, current_schedule])
		_update_slots_visuals()
		_update_state()


func _update_slots_visuals() -> void:
	for i in range(MAX_SLOTS):
		var panel = slot_panels[i]
		var icon_lbl = slot_icon_labels[i]
		var name_lbl = slot_name_labels[i]
		var style = panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		
		if i < current_schedule.size():
			# Slot is filled
			var act_id = str(current_schedule[i])  # Ensure string
			var data = activities[act_id]
			
			icon_lbl.text = data["icon"]
			icon_lbl.add_theme_color_override("font_color", Color.WHITE)
			
			name_lbl.text = data["name"]
			name_lbl.add_theme_color_override("font_color", data["color"])
			
			style.border_color = data["color"]
			style.bg_color = data["color"].darkened(0.8)
		else:
			# Slot is empty
			icon_lbl.text = "+"
			icon_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.35))
			
			name_lbl.text = "Empty"
			name_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
			
			style.border_color = Color(0.3, 0.3, 0.35)
			style.bg_color = Color(0.15, 0.15, 0.18)
		
		panel.add_theme_stylebox_override("panel", style)


func _update_state() -> void:
	# Update Title
	title_label.text = "Plan Your Week (%d/%d)" % [current_schedule.size(), MAX_SLOTS]
	
	# Update Confirm Button
	confirm_button.disabled = (current_schedule.size() != MAX_SLOTS)
	
	if not confirm_button.disabled:
		confirm_button.text = "Start Week!"
	else:
		confirm_button.text = "Fill Schedule..."


func _show_description(text: String) -> void:
	description_label.text = "[center]%s[/center]" % text


func _on_back_pressed() -> void:
	# Go back to hero power selection
	get_tree().change_scene_to_file("res://scenes/hero_power_selection.tscn")


func _on_confirm_pressed() -> void:
	# Convert to a plain Array (not typed) to avoid meta storage issues
	var schedule_to_store: Array = []
	for item in current_schedule:
		schedule_to_store.append(str(item))
	
	print("[ScheduleBuilder] Schedule confirmed: ", schedule_to_store)
	
	# Store schedule in GameManager
	GameManager.set_meta("weekly_schedule", schedule_to_store)
	GameManager.set_meta("current_day_index", 0)
	
	# Verify storage
	var verify = GameManager.get_meta("weekly_schedule")
	print("[ScheduleBuilder] Verified stored schedule: ", verify, " type: ", typeof(verify))
	
	# Emit signal for any listeners
	schedule_confirmed.emit(schedule_to_store)
	
	# Go to week runner to execute the schedule
	get_tree().change_scene_to_file("res://scenes/week_runner.tscn")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()


## --- Styling & Responsiveness ---

func _apply_styling() -> void:
	# Reuse basic button styling logic
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.25, 0.35)
	btn_style.border_color = Color(0.5, 0.45, 0.3)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(10)
	
	if back_button:
		back_button.add_theme_stylebox_override("normal", btn_style)
	if confirm_button:
		confirm_button.add_theme_stylebox_override("normal", btn_style)
	
	# Disabled style for confirm button
	var disabled_style = btn_style.duplicate()
	disabled_style.bg_color = Color(0.15, 0.15, 0.18)
	disabled_style.border_color = Color(0.3, 0.3, 0.3)
	if confirm_button:
		confirm_button.add_theme_stylebox_override("disabled", disabled_style)


func get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 3.0)


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _apply_responsive_fonts() -> void:
	var s = get_scale_factor()
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(32 * s))
