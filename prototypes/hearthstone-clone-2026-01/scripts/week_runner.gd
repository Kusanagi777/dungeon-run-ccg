# res://scripts/week_runner.gd
extends Control

## This screen manages the weekly schedule execution
## It shows the current day and transitions to the appropriate scene

const REFERENCE_HEIGHT: float = 720.0
const SIDE_JOB_GOLD: int = 150

## Activity definitions (same as schedule builder)
var activities: Dictionary = {
	"duel": {
		"id": "duel",
		"name": "Duel",
		"description": "Fight a standard opponent",
		"icon": "⚔️",
		"color": Color(0.9, 0.3, 0.3),
		"scene": "res://scenes/main_game.tscn",
		"battle_type": "normal"
	},
	"champion": {
		"id": "champion",
		"name": "Champion",
		"description": "Challenge an Elite opponent",
		"icon": "🏆",
		"color": Color(1.0, 0.8, 0.2),
		"scene": "res://scenes/main_game.tscn",
		"battle_type": "elite"
	},
	"side_job": {
		"id": "side_job",
		"name": "Side Job",
		"description": "Work for gold",
		"icon": "💰",
		"color": Color(0.4, 0.8, 0.4),
		"scene": "",  # Handled inline
		"gold_reward": SIDE_JOB_GOLD
	},
	"shop": {
		"id": "shop",
		"name": "Shop",
		"description": "Visit the merchant",
		"icon": "🛒",
		"color": Color(0.3, 0.6, 0.9),
		"scene": "res://scenes/shop_screen.tscn"
	}
}

## Current schedule from GameManager
var weekly_schedule: Array = []
var current_day_index: int = 0

## UI References
var day_label: Label
var activity_icon: Label
var activity_name: Label
var activity_desc: Label
var gold_label: Label
var continue_button: Button
var progress_container: HBoxContainer

## Animation state
var _is_transitioning: bool = false


func _ready() -> void:
	print("[WeekRunner] _ready() called")
	
	# Load schedule from GameManager with validation
	if GameManager.has_meta("weekly_schedule"):
		var raw_schedule = GameManager.get_meta("weekly_schedule")
		print("[WeekRunner] Raw schedule from meta: ", raw_schedule, " type: ", typeof(raw_schedule))
		
		# Convert to regular array to avoid type issues
		weekly_schedule = []
		if raw_schedule is Array:
			for item in raw_schedule:
				weekly_schedule.append(str(item))  # Ensure strings
		print("[WeekRunner] Processed schedule: ", weekly_schedule)
	else:
		print("[WeekRunner] WARNING: No weekly_schedule in meta!")
		weekly_schedule = []
	
	if GameManager.has_meta("current_day_index"):
		current_day_index = GameManager.get_meta("current_day_index")
		print("[WeekRunner] Loaded current_day_index: ", current_day_index)
	else:
		print("[WeekRunner] WARNING: No current_day_index in meta, defaulting to 0")
		current_day_index = 0
	
	# Initialize gold if not set
	if not GameManager.has_meta("player_gold"):
		GameManager.set_meta("player_gold", 200)
	
	print("[WeekRunner] Schedule size: %d, Current day: %d" % [weekly_schedule.size(), current_day_index])
	
	# Safety check - if no schedule, redirect to schedule builder
	if weekly_schedule.is_empty():
		print("[WeekRunner] ERROR: Empty schedule! Redirecting to schedule builder.")
		get_tree().change_scene_to_file("res://scenes/schedule_builder.tscn")
		return
	
	_setup_ui()
	_apply_styling()
	_update_display()
	
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _setup_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.1, 0.14)
	add_child(bg)
	
	# Main layout
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_vbox)
	
	# Header with day and gold
	var header = HBoxContainer.new()
	main_vbox.add_child(header)
	
	day_label = Label.new()
	day_label.text = "Day 1 of 5"
	day_label.add_theme_font_size_override("font_size", 28)
	day_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(day_label)
	
	var gold_container = HBoxContainer.new()
	gold_container.add_theme_constant_override("separation", 5)
	header.add_child(gold_container)
	
	var gold_icon = Label.new()
	gold_icon.text = "💰"
	gold_icon.add_theme_font_size_override("font_size", 24)
	gold_container.add_child(gold_icon)
	
	gold_label = Label.new()
	gold_label.text = str(GameManager.get_meta("player_gold") if GameManager.has_meta("player_gold") else 0)
	gold_label.add_theme_font_size_override("font_size", 24)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	gold_container.add_child(gold_label)
	
	main_vbox.add_child(HSeparator.new())
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer1)
	
	# Activity display (centered)
	var center_margin = MarginContainer.new()
	center_margin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(center_margin)
	
	var centered_vbox = VBoxContainer.new()
	centered_vbox.add_theme_constant_override("separation", 15)
	center_margin.add_child(centered_vbox)
	
	activity_icon = Label.new()
	activity_icon.text = "⚔️"
	activity_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity_icon.add_theme_font_size_override("font_size", 64)
	centered_vbox.add_child(activity_icon)
	
	activity_name = Label.new()
	activity_name.text = "Duel"
	activity_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity_name.add_theme_font_size_override("font_size", 28)
	activity_name.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	centered_vbox.add_child(activity_name)
	
	activity_desc = Label.new()
	activity_desc.text = "Fight a standard opponent"
	activity_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity_desc.add_theme_font_size_override("font_size", 16)
	activity_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	centered_vbox.add_child(activity_desc)
	
	# Progress dots
	progress_container = HBoxContainer.new()
	progress_container.alignment = BoxContainer.ALIGNMENT_CENTER
	progress_container.add_theme_constant_override("separation", 10)
	main_vbox.add_child(progress_container)
	
	# Create progress dots based on schedule size (or 5 if empty)
	var num_dots = weekly_schedule.size() if weekly_schedule.size() > 0 else 5
	for i in range(num_dots):
		var dot = _create_progress_dot(i)
		progress_container.add_child(dot)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer2)
	
	# Continue button
	continue_button = Button.new()
	continue_button.text = "Begin Activity"
	continue_button.custom_minimum_size = Vector2(200, 50)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(_on_continue_pressed)
	main_vbox.add_child(continue_button)


func _create_progress_dot(index: int) -> PanelContainer:
	var dot = PanelContainer.new()
	dot.custom_minimum_size = Vector2(20, 20)
	
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.bg_color = Color(0.2, 0.2, 0.25)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(2)
	dot.add_theme_stylebox_override("panel", style)
	
	return dot


func _apply_styling() -> void:
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.35, 0.2)
	btn_style.border_color = Color(0.4, 0.6, 0.4)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(8)
	btn_style.set_content_margin_all(10)
	
	if continue_button:
		continue_button.add_theme_stylebox_override("normal", btn_style)
		continue_button.add_theme_font_size_override("font_size", 18)


func _update_display() -> void:
	# Update gold display
	gold_label.text = str(GameManager.get_meta("player_gold") if GameManager.has_meta("player_gold") else 0)
	
	# Check if week is complete
	if current_day_index >= weekly_schedule.size():
		day_label.text = "Week Complete!"
		activity_icon.text = "🎉"
		activity_name.text = "All activities finished"
		activity_name.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
		activity_desc.text = "Return to plan your next week"
		continue_button.text = "Continue"
		_refresh_progress_dots()
		return
	
	# Show current activity
	var activity_id: String = weekly_schedule[current_day_index]
	var activity: Dictionary = activities.get(activity_id, {})
	
	day_label.text = "Day %d of %d" % [current_day_index + 1, weekly_schedule.size()]
	activity_icon.text = activity.get("icon", "❓")
	activity_name.text = activity.get("name", "Unknown")
	activity_name.add_theme_color_override("font_color", activity.get("color", Color.WHITE))
	activity_desc.text = activity.get("description", "")
	
	# Update button text based on activity
	match activity_id:
		"duel":
			continue_button.text = "Start Duel!"
		"champion":
			continue_button.text = "Challenge Champion!"
		"shop":
			continue_button.text = "Enter Shop"
		"side_job":
			# MODIFIER HOOK: Get modified gold reward
			var base_gold := SIDE_JOB_GOLD
			var modified_gold := base_gold
			if ModifierManager:
				modified_gold = ModifierManager.apply_schedule_effect_modifiers("side_job", base_gold)
			continue_button.text = "Work Shift (+%d Gold)" % modified_gold
	
	_refresh_progress_dots()


func _refresh_progress_dots() -> void:
	for i in range(progress_container.get_child_count()):
		var dot = progress_container.get_child(i) as PanelContainer
		if not dot:
			continue
		
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(25)
		style.set_content_margin_all(5)
		style.set_border_width_all(2)
		
		if i < current_day_index:
			style.bg_color = Color(0.3, 0.7, 0.3)
			style.border_color = Color(0.4, 0.8, 0.4)
		elif i == current_day_index:
			style.bg_color = Color(0.8, 0.6, 0.2)
			style.border_color = Color(1.0, 0.8, 0.3)
		else:
			style.bg_color = Color(0.2, 0.2, 0.25)
			style.border_color = Color(0.3, 0.3, 0.35)
		
		dot.add_theme_stylebox_override("panel", style)


func _on_continue_pressed() -> void:
	if _is_transitioning:
		return
	
	_is_transitioning = true
	
	if current_day_index >= weekly_schedule.size():
		# Week complete - go back to schedule builder
		GameManager.set_meta("current_day_index", 0)
		get_tree().change_scene_to_file("res://scenes/schedule_builder.tscn")
		return
	
	var activity_id: String = weekly_schedule[current_day_index]
	print("[WeekRunner] Executing activity: ", activity_id)
	
	match activity_id:
		"side_job":
			_execute_side_job()
		"shop":
			_execute_shop()
		"duel":
			_execute_battle("normal")
		"champion":
			_execute_battle("elite")
		_:
			print("[WeekRunner] Unknown activity: %s" % activity_id)
			_advance_day()


func _execute_side_job() -> void:
	# MODIFIER HOOK: Apply schedule effect modifier to gold reward
	var base_gold := SIDE_JOB_GOLD
	var modified_gold := base_gold
	if ModifierManager:
		modified_gold = ModifierManager.apply_schedule_effect_modifiers("side_job", base_gold)
	
	# Add gold
	var player_gold: int = GameManager.get_meta("player_gold") if GameManager.has_meta("player_gold") else 0
	player_gold += modified_gold
	GameManager.set_meta("player_gold", player_gold)
	
	print("[WeekRunner] Side job completed! Earned %d gold (base: %d). Total: %d" % [modified_gold, base_gold, player_gold])
	
	# Show gold earned animation
	_show_gold_popup(modified_gold)
	
	# MODIFIER HOOK: Trigger schedule day complete
	if ModifierManager:
		ModifierManager.trigger_schedule_day_complete(current_day_index, "side_job")
	
	# Wait then advance
	await get_tree().create_timer(1.5).timeout
	_advance_day()


func _show_gold_popup(amount: int) -> void:
	var popup = Label.new()
	popup.text = "+%d 💰" % amount
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.add_theme_font_size_override("font_size", 48)
	popup.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.z_index = 100
	add_child(popup)
	
	# Animate
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 100, 1.0)
	tween.tween_property(popup, "modulate:a", 0.0, 1.0).set_delay(0.5)
	tween.chain().tween_callback(popup.queue_free)
	
	# Update gold display immediately
	gold_label.text = str(GameManager.get_meta("player_gold"))


func _execute_shop() -> void:
	# Store return info
	GameManager.set_meta("return_to_week_runner", true)
	GameManager.set_meta("current_day_index", current_day_index)
	
	# MODIFIER HOOK: Trigger schedule day complete
	if ModifierManager:
		ModifierManager.trigger_schedule_day_complete(current_day_index, "shop")
	
	print("[WeekRunner] Going to shop, will return to day %d" % current_day_index)
	
	# Go to shop
	get_tree().change_scene_to_file("res://scenes/shop_screen.tscn")


func _execute_battle(battle_type: String) -> void:
	# Store battle info
	GameManager.set_meta("battle_type", battle_type)
	GameManager.set_meta("return_to_week_runner", true)
	GameManager.set_meta("current_day_index", current_day_index)
	
	# MODIFIER HOOK: Trigger schedule day complete (before battle)
	if ModifierManager:
		ModifierManager.trigger_schedule_day_complete(current_day_index, battle_type)
	
	print("[WeekRunner] Starting %s battle, will return to day %d" % [battle_type, current_day_index])
	
	# Go to battle
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")


func _advance_day() -> void:
	current_day_index += 1
	GameManager.set_meta("current_day_index", current_day_index)
	
	print("[WeekRunner] Advanced to day %d" % (current_day_index + 1))
	
	_is_transitioning = false
	_update_display()
	
	if current_day_index >= weekly_schedule.size():
		print("[WeekRunner] Week complete!")


func _on_viewport_size_changed() -> void:
	# Could update responsive elements here
	pass


func get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 3.0)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# Return to schedule builder
			get_tree().change_scene_to_file("res://scenes/schedule_builder.tscn")
