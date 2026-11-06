# res://autoload/debug_menu.gd
# Debug Menu - Toggle with Q key
# Add this as an AutoLoad in Project Settings

extends CanvasLayer

## Debug panel visibility
var is_visible: bool = false

## UI References
var panel: PanelContainer
var content_vbox: VBoxContainer
var title_label: Label
var state_label: Label

## Button references for state updates
var mana_buttons: Dictionary = {}


func _ready() -> void:
	layer = 100  # Always on top
	_build_ui()
	panel.visible = false
	
	print("[DebugMenu] Ready - Press Q to toggle")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_toggle_menu()


func _toggle_menu() -> void:
	is_visible = not is_visible
	panel.visible = is_visible
	
	if is_visible:
		_update_state_display()


func _build_ui() -> void:
	# Main panel
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	panel.position = Vector2(10, 0)
	panel.anchor_left = 0
	panel.anchor_right = 0
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_top = -250
	panel.offset_bottom = 250
	panel.offset_left = 10
	panel.offset_right = 260
	add_child(panel)
	
	# Style the panel
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	panel_style.border_color = Color(0.8, 0.6, 0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	
	# Scroll container for many options
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	
	# Main content
	content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(content_vbox)
	
	# Title
	title_label = Label.new()
	title_label.text = "🛠️ DEBUG MENU"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	content_vbox.add_child(title_label)
	
	# Close hint
	var hint := Label.new()
	hint.text = "(Press Q to close)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	content_vbox.add_child(hint)
	
	content_vbox.add_child(HSeparator.new())
	
	# State display
	state_label = Label.new()
	state_label.text = "Loading..."
	state_label.add_theme_font_size_override("font_size", 11)
	state_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	content_vbox.add_child(state_label)
	
	content_vbox.add_child(HSeparator.new())
	
	# === MANA SECTION ===
	_add_section_label("💧 MANA")
	
	var mana_row := HBoxContainer.new()
	mana_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(mana_row)
	
	_add_button(mana_row, "+1 Mana", _on_add_mana.bind(1))
	_add_button(mana_row, "+5 Mana", _on_add_mana.bind(5))
	_add_button(mana_row, "Max", _on_max_mana)
	
	# === CARDS SECTION ===
	_add_section_label("🃏 CARDS")
	
	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(cards_row)
	
	_add_button(cards_row, "Draw 1", _on_draw_cards.bind(1))
	_add_button(cards_row, "Draw 3", _on_draw_cards.bind(3))
	_add_button(cards_row, "Draw 5", _on_draw_cards.bind(5))
	
	# === HEALTH SECTION ===
	_add_section_label("❤️ HEALTH")
	
	var health_row1 := HBoxContainer.new()
	health_row1.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(health_row1)
	
	_add_button(health_row1, "Heal +10", _on_heal_player.bind(10))
	_add_button(health_row1, "Full Heal", _on_heal_player.bind(100))
	
	var health_row2 := HBoxContainer.new()
	health_row2.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(health_row2)
	
	_add_button(health_row2, "Dmg Enemy -10", _on_damage_enemy.bind(10))
	_add_button(health_row2, "Kill Enemy", _on_damage_enemy.bind(100))
	
	# === GAME CONTROL ===
	_add_section_label("🎮 GAME CONTROL")
	
	var game_row := HBoxContainer.new()
	game_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(game_row)
	
	_add_button(game_row, "Win Game", _on_win_game, Color(0.3, 0.7, 0.3))
	_add_button(game_row, "Lose Game", _on_lose_game, Color(0.7, 0.3, 0.3))
	
	var turn_row := HBoxContainer.new()
	turn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(turn_row)
	
	_add_button(turn_row, "End Turn", _on_end_turn)
	_add_button(turn_row, "Skip AI", _on_skip_ai_turn)
	
	# === GOLD / SCHEDULE ===
	_add_section_label("💰 ECONOMY / SCHEDULE")
	
	var gold_row := HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(gold_row)
	
	_add_button(gold_row, "+100 Gold", _on_add_gold.bind(100))
	_add_button(gold_row, "+500 Gold", _on_add_gold.bind(500))
	
	var schedule_row := HBoxContainer.new()
	schedule_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(schedule_row)
	
	_add_button(schedule_row, "Skip Day", _on_skip_day)
	_add_button(schedule_row, "Complete Week", _on_complete_week)
	
	# === MISC ===
	_add_section_label("🔧 MISC")
	
	var misc_row := HBoxContainer.new()
	misc_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(misc_row)
	
	_add_button(misc_row, "Reload Scene", _on_reload_scene)
	_add_button(misc_row, "Print State", _on_print_state)
	
	var nav_row := HBoxContainer.new()
	nav_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(nav_row)
	
	_add_button(nav_row, "→ Main Menu", _on_goto_menu)
	_add_button(nav_row, "→ Week Runner", _on_goto_week_runner)


func _add_section_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	content_vbox.add_child(label)


func _add_button(parent: Control, text: String, callback: Callable, color: Color = Color(0.25, 0.28, 0.35)) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(70, 28)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = color.lightened(0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style := style.duplicate()
	hover_style.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	btn.add_theme_font_size_override("font_size", 11)
	
	parent.add_child(btn)
	return btn


func _update_state_display() -> void:
	var lines: Array[String] = []
	
	# Check if GameManager exists and has data
	if GameManager and GameManager.players.size() >= 2:
		var p0 := GameManager.players[0]
		var p1 := GameManager.players[1]
		
		lines.append("Turn: %d | Active: P%d" % [GameManager.turn_number, GameManager.active_player + 1])
		lines.append("Phase: %s" % GameManager.GamePhase.keys()[GameManager.current_phase])
		lines.append("---")
		lines.append("Player: %d/%d HP | %d/%d Mana" % [p0["hero_health"], p0["hero_max_health"], p0["current_mana"], p0["max_mana"]])
		lines.append("  Hand: %d | Deck: %d" % [p0["hand"].size(), p0["deck"].size()])
		lines.append("Enemy:  %d/%d HP | %d/%d Mana" % [p1["hero_health"], p1["hero_max_health"], p1["current_mana"], p1["max_mana"]])
		lines.append("  Hand: %d | Deck: %d" % [p1["hand"].size(), p1["deck"].size()])
	else:
		lines.append("Game not initialized")
	
	# Gold
	if GameManager.has_meta("player_gold"):
		lines.append("---")
		lines.append("Gold: %d" % GameManager.get_meta("player_gold"))
	
	# Schedule info
	if GameManager.has_meta("current_day_index") and GameManager.has_meta("weekly_schedule"):
		var day: int = GameManager.get_meta("current_day_index")
		var schedule: Array = GameManager.get_meta("weekly_schedule")
		lines.append("Schedule: Day %d/%d" % [day + 1, schedule.size()])
	
	state_label.text = "\n".join(lines)


## === CALLBACK FUNCTIONS ===

func _on_add_mana(amount: int) -> void:
	if GameManager.players.size() < 1:
		return
	GameManager.players[0]["current_mana"] = mini(
		GameManager.players[0]["current_mana"] + amount,
		GameManager.MAX_MANA_CAP
	)
	GameManager.mana_changed.emit(0, GameManager.players[0]["current_mana"], GameManager.players[0]["max_mana"])
	_update_state_display()
	print("[Debug] Added %d mana" % amount)


func _on_max_mana() -> void:
	if GameManager.players.size() < 1:
		return
	GameManager.players[0]["current_mana"] = GameManager.MAX_MANA_CAP
	GameManager.players[0]["max_mana"] = GameManager.MAX_MANA_CAP
	GameManager.mana_changed.emit(0, GameManager.MAX_MANA_CAP, GameManager.MAX_MANA_CAP)
	_update_state_display()
	print("[Debug] Set mana to max")


func _on_draw_cards(count: int) -> void:
	for i in range(count):
		if GameManager.has_method("_draw_card"):
			GameManager._draw_card(0)
	_update_state_display()
	print("[Debug] Drew %d cards" % count)


func _on_heal_player(amount: int) -> void:
	if GameManager.players.size() < 1:
		return
	var p := GameManager.players[0]
	p["hero_health"] = mini(p["hero_health"] + amount, p["hero_max_health"])
	GameManager.health_changed.emit(0, p["hero_health"], p["hero_max_health"])
	_update_state_display()
	print("[Debug] Healed player for %d" % amount)


func _on_damage_enemy(amount: int) -> void:
	if GameManager.players.size() < 2:
		return
	var p := GameManager.players[1]
	p["hero_health"] = maxi(p["hero_health"] - amount, 0)
	GameManager.health_changed.emit(1, p["hero_health"], p["hero_max_health"])
	
	# Check for death
	if p["hero_health"] <= 0:
		GameManager._end_game(0)  # Player wins
	
	_update_state_display()
	print("[Debug] Damaged enemy for %d" % amount)


func _on_win_game() -> void:
	if GameManager.has_method("_end_game"):
		GameManager._end_game(0)
	print("[Debug] Forced win")


func _on_lose_game() -> void:
	if GameManager.has_method("_end_game"):
		GameManager._end_game(1)
	print("[Debug] Forced loss")


func _on_end_turn() -> void:
	if GameManager.has_method("end_turn"):
		GameManager.end_turn()
	_update_state_display()
	print("[Debug] Ended turn")


func _on_skip_ai_turn() -> void:
	# Force turn back to player
	if GameManager.active_player == 1:
		GameManager.active_player = 0
		GameManager.turn_started.emit(0)
	_update_state_display()
	print("[Debug] Skipped AI turn")


func _on_add_gold(amount: int) -> void:
	var current: int = GameManager.get_meta("player_gold") if GameManager.has_meta("player_gold") else 0
	GameManager.set_meta("player_gold", current + amount)
	_update_state_display()
	print("[Debug] Added %d gold (Total: %d)" % [amount, current + amount])


func _on_skip_day() -> void:
	if GameManager.has_meta("current_day_index"):
		var day: int = GameManager.get_meta("current_day_index")
		GameManager.set_meta("current_day_index", day + 1)
		_update_state_display()
		print("[Debug] Skipped to day %d" % (day + 2))


func _on_complete_week() -> void:
	if GameManager.has_meta("weekly_schedule"):
		var schedule: Array = GameManager.get_meta("weekly_schedule")
		GameManager.set_meta("current_day_index", schedule.size())
		_update_state_display()
		print("[Debug] Completed week")


func _on_reload_scene() -> void:
	get_tree().reload_current_scene()
	print("[Debug] Reloaded scene")


func _on_print_state() -> void:
	print("=== DEBUG STATE ===")
	print("Turn: %d, Active Player: %d" % [GameManager.turn_number, GameManager.active_player])
	print("Phase: %s" % GameManager.GamePhase.keys()[GameManager.current_phase])
	
	for i in range(GameManager.players.size()):
		var p := GameManager.players[i]
		print("Player %d:" % i)
		print("  Health: %d/%d" % [p["hero_health"], p["hero_max_health"]])
		print("  Mana: %d/%d" % [p["current_mana"], p["max_mana"]])
		print("  Hand: %d cards" % p["hand"].size())
		print("  Deck: %d cards" % p["deck"].size())
		print("  Board: %d minions" % p["board"].size())
	
	print("Meta data:")
	if GameManager.has_meta("player_gold"):
		print("  Gold: %d" % GameManager.get_meta("player_gold"))
	if GameManager.has_meta("weekly_schedule"):
		print("  Schedule: %s" % str(GameManager.get_meta("weekly_schedule")))
	if GameManager.has_meta("current_day_index"):
		print("  Day Index: %d" % GameManager.get_meta("current_day_index"))
	print("===================")


func _on_goto_menu() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _on_goto_week_runner() -> void:
	get_tree().change_scene_to_file("res://scenes/week_runner.tscn")


func _process(_delta: float) -> void:
	if is_visible:
		_update_state_display()
