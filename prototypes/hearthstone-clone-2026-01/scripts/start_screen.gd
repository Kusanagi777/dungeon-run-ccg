# res://scripts/start_screen.gd
# UPDATED: Added Test Duel button for immediate testing with random decks
extends Control

## Path to card resources
const CARDS_PATH := "res://data/cards/"
const TEST_DECK_SIZE := 15

## UI References
@onready var start_button: Button = $CenterContainer/VBoxContainer/MenuButtons/StartButton
@onready var options_button: Button = $CenterContainer/VBoxContainer/MenuButtons/OptionsButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/MenuButtons/ExitButton
@onready var shop_test: Button = $CenterContainer/VBoxContainer/MenuButtons/ShopTest

## Reference resolution for scaling
const REFERENCE_HEIGHT := 720.0

## All available card IDs for random deck generation
var _all_card_ids: Array[String] = []


func _ready() -> void:
	# Reset game state when returning to menu
	GameManager.reset_game()
	
	# Load all available cards for test duel
	_load_all_card_ids()
	
	_connect_signals()
	_add_test_duel_button()
	_apply_responsive_fonts()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _load_all_card_ids() -> void:
	_all_card_ids.clear()
	
	var dir := DirAccess.open(CARDS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				# Extract card ID from filename (remove .tres extension)
				var card_id := file_name.get_basename()
				_all_card_ids.append(card_id)
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	if _all_card_ids.size() > 0:
		print("[StartScreen] Loaded %d card IDs for test duel" % _all_card_ids.size())
	else:
		print("[StartScreen] No cards found in %s - test duel will use generated cards" % CARDS_PATH)


func _connect_signals() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if options_button:
		options_button.pressed.connect(_on_options_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
	
	# Connect any additional buttons that might exist
	var deck_build_button = find_child("DeckBuildButton", true, false)
	if deck_build_button and deck_build_button is Button:
		deck_build_button.pressed.connect(_on_deck_build_pressed)
	
	var shop_button = find_child("ShopTest", true, false)
	if shop_button and shop_button is Button:
		shop_button.pressed.connect(_on_shop_pressed)


func _add_test_duel_button() -> void:
	# Find the MenuButtons container
	var menu_buttons = find_child("MenuButtons", true, false)
	if not menu_buttons:
		push_warning("[StartScreen] MenuButtons container not found, creating test button elsewhere")
		return
	
	# Check if test duel button already exists
	var existing = find_child("TestDuelButton", true, false)
	if existing:
		existing.pressed.connect(_on_test_duel_pressed)
		return
	
	# Create new Test Duel button
	var test_duel_button := Button.new()
	test_duel_button.name = "TestDuelButton"
	test_duel_button.text = "⚔️ Test Duel"
	test_duel_button.custom_minimum_size = Vector2(250, 60)
	test_duel_button.add_theme_font_size_override("font_size", 20)
	
	# Style it differently to stand out as a test/debug option
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.25, 0.1)  # Orange-brown
	style.border_color = Color(0.8, 0.5, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	test_duel_button.add_theme_stylebox_override("normal", style)
	
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.5, 0.3, 0.15)
	test_duel_button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style := style.duplicate()
	pressed_style.bg_color = Color(0.3, 0.2, 0.08)
	test_duel_button.add_theme_stylebox_override("pressed", pressed_style)
	
	# Add to menu (insert before Exit button if possible)
	var exit_idx := -1
	for i in range(menu_buttons.get_child_count()):
		if menu_buttons.get_child(i).name == "ExitButton":
			exit_idx = i
			break
	
	if exit_idx >= 0:
		menu_buttons.add_child(test_duel_button)
		menu_buttons.move_child(test_duel_button, exit_idx)
	else:
		menu_buttons.add_child(test_duel_button)
	
	# Connect signal
	test_duel_button.pressed.connect(_on_test_duel_pressed)
	
	print("[StartScreen] Test Duel button added")


func _on_test_duel_pressed() -> void:
	print("[StartScreen] Starting Test Duel...")
	
	# Generate random decks for both players
	var player_deck := _generate_random_deck()
	var enemy_deck := _generate_random_deck()
	
	print("[StartScreen] Player deck has %d card IDs" % player_deck.size())
	print("[StartScreen] Enemy deck has %d card IDs" % enemy_deck.size())
	
	# Store decks in GameManager (main_game will load actual CardData or create test cards)
	GameManager.set_meta("selected_deck", {
		"name": "Random Test Deck",
		"cards": player_deck
	})
	
	GameManager.set_meta("enemy_deck", {
		"name": "Random Enemy Deck", 
		"cards": enemy_deck
	})
	
	# Set test mode flag
	GameManager.set_meta("test_duel_mode", true)
	
	# Clear any faction/aspect selection (not needed for test)
	if GameManager.has_meta("selected_faction"):
		GameManager.remove_meta("selected_faction")
	if GameManager.has_meta("selected_aspect"):
		GameManager.remove_meta("selected_aspect")
	
	# Go directly to the game
	get_tree().change_scene_to_file("res://scenes/main_game.tscn")


func _generate_random_deck() -> Array:
	var deck: Array = []
	
	# If no real cards available, return empty array
	# main_game.gd will create test cards as fallback
	if _all_card_ids.is_empty():
		print("[StartScreen] No cards available - main_game will create test deck")
		return deck
	
	# Create a shuffled copy of all card IDs
	var shuffled_cards := _all_card_ids.duplicate()
	shuffled_cards.shuffle()
	
	# Track how many of each card we've added (max 2 copies)
	var card_counts: Dictionary = {}
	var idx := 0
	var max_iterations := shuffled_cards.size() * 3  # Safety limit
	
	while deck.size() < TEST_DECK_SIZE and idx < max_iterations:
		var card_id: String = shuffled_cards[idx % shuffled_cards.size()]
		var current_count: int = card_counts.get(card_id, 0)
		
		# Allow max 2 copies per card
		if current_count < 2:
			deck.append(card_id)
			card_counts[card_id] = current_count + 1
		
		idx += 1
	
	return deck


func _apply_responsive_fonts() -> void:
	var scale_factor := _get_scale_factor()
	
	var title_label = find_child("TitleLabel", true, false)
	if title_label and title_label is Label:
		title_label.add_theme_font_size_override("font_size", int(48 * scale_factor))
	
	var subtitle_label = find_child("SubtitleLabel", true, false)
	if subtitle_label and subtitle_label is Label:
		subtitle_label.add_theme_font_size_override("font_size", int(18 * scale_factor))
	
	# Scale button fonts
	var buttons = [start_button, options_button, exit_button]
	for btn in buttons:
		if btn:
			btn.add_theme_font_size_override("font_size", int(20 * scale_factor))
	
	# Also scale test duel button if it exists
	var test_duel_btn = find_child("TestDuelButton", true, false)
	if test_duel_btn and test_duel_btn is Button:
		test_duel_btn.add_theme_font_size_override("font_size", int(20 * scale_factor))


func _get_scale_factor() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	return viewport_size.y / REFERENCE_HEIGHT


func _on_viewport_size_changed() -> void:
	_apply_responsive_fonts()


func _on_start_pressed() -> void:
	# Go to faction selection (new flow)
	get_tree().change_scene_to_file("res://scenes/faction_selection.tscn")


func _on_deck_build_pressed() -> void:
	# Go to deck builder if you have one
	if ResourceLoader.exists("res://scenes/deck_builder.tscn"):
		get_tree().change_scene_to_file("res://scenes/deck_builder.tscn")
	else:
		print("[StartScreen] Deck builder scene not found")


func _on_options_pressed() -> void:
	# Show options panel if it exists
	var options_panel = find_child("OptionsPanel", true, false)
	if options_panel:
		options_panel.visible = true
	else:
		print("[StartScreen] Options panel not found")


func _on_shop_pressed() -> void:
	if ResourceLoader.exists("res://scenes/shop_screen.tscn"):
		get_tree().change_scene_to_file("res://scenes/shop_screen.tscn")
	else:
		print("[StartScreen] Shop scene not found")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# Check if options panel is open
			var options_panel = find_child("OptionsPanel", true, false)
			if options_panel and options_panel.visible:
				options_panel.visible = false
			else:
				get_tree().quit()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_on_start_pressed()
		elif event.keycode == KEY_T:
			# Quick shortcut: Press T for Test Duel
			_on_test_duel_pressed()
