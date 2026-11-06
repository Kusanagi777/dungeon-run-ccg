# res://scripts/main_game.gd
# UPDATED: Now uses 5 lanes per row (10 total spaces)
# 5 front row + 5 back row for each player

extends Control

## Path to card resources
const CARDS_PATH := "res://data/cards/"

## Number of lanes per row (CHANGED from 3 to 5)
const LANES_PER_ROW := 5

## Lane arrays
var player_front_lanes: Array[Control] = []
var player_back_lanes: Array[Control] = []
var enemy_front_lanes: Array[Control] = []
var enemy_back_lanes: Array[Control] = []

## Player controllers
var player_one: Node
var player_two: Node

## UI References
var player_mana_label: Label
var enemy_mana_label: Label
var player_health_label: Label
var enemy_health_label: Label
var player_deck_label: Label
var enemy_deck_label: Label
var turn_button: Button
var game_over_panel: Control
var winner_label: Label
var player_hand_container: Control
var enemy_hand_container: Control
var player_hero_area: Control
var enemy_hero_area: Control

## Reference resolution for scaling
const REFERENCE_HEIGHT := 720.0


func _ready() -> void:
	# Connect to GameManager signals
	_connect_signals()
	
	# Find UI references
	_find_ui_references()
	
	# Setup the battlefield with 5 lanes per row
	_setup_lanes()
	
	# Setup player controllers
	_setup_player_controllers()
	
	# Apply styling
	_apply_styling()
	
	# Start the game
	_start_game()
	
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _connect_signals() -> void:
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.turn_ended.connect(_on_turn_ended)
	GameManager.mana_changed.connect(_on_mana_changed)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.card_drawn.connect(_on_card_drawn)
	GameManager.game_ended.connect(_on_game_over)


func _find_ui_references() -> void:
	# Find labels
	if not player_mana_label:
		player_mana_label = find_child("ManaLabel", true, false)
	if not enemy_mana_label:
		enemy_mana_label = find_child("EnemyManaLabel", true, false)
	if not player_health_label:
		player_health_label = find_child("PlayerHealthLabel", true, false)
	if not enemy_health_label:
		enemy_health_label = find_child("EnemyHealthLabel", true, false)
	if not player_deck_label:
		player_deck_label = find_child("PlayerDeckLabel", true, false)
	if not enemy_deck_label:
		enemy_deck_label = find_child("EnemyDeckLabel", true, false)
	if not game_over_panel:
		game_over_panel = find_child("GameOverPanel", true, false)
	if not winner_label:
		winner_label = find_child("WinnerLabel", true, false)
	if not player_hand_container:
		player_hand_container = find_child("PlayerHandContainer", true, false)
	if not enemy_hand_container:
		enemy_hand_container = find_child("EnemyHandContainer", true, false)
	if not player_hero_area:
		player_hero_area = find_child("PlayerHeroPanel", true, false)
	if not enemy_hero_area:
		enemy_hero_area = find_child("EnemyHeroPanel", true, false)
	if not turn_button:
		turn_button = find_child("TurnButton", true, false)
	
	# Connect turn button
	if turn_button:
		turn_button.pressed.connect(_on_turn_button_pressed)
	
	# Find player controllers (try multiple naming conventions)
	if not player_one:
		player_one = find_child("PlayerOneController", true, false)
		if not player_one:
			player_one = find_child("PlayerOne", true, false)
	if not player_two:
		player_two = find_child("PlayerTwoController", true, false)
		if not player_two:
			player_two = find_child("PlayerTwo", true, false)
	
	# Log what we found
	print("[MainGame] Player controllers: P1=%s, P2=%s" % [
		player_one.name if player_one else "NOT FOUND",
		player_two.name if player_two else "NOT FOUND"
	])


func _setup_lanes() -> void:
	# Clear existing lane arrays
	player_front_lanes.clear()
	player_back_lanes.clear()
	enemy_front_lanes.clear()
	enemy_back_lanes.clear()
	
	# Find player front lanes (should have 5 lanes now)
	var player_front_container = find_child("PlayerFrontLanes", true, false)
	if player_front_container:
		for i in range(player_front_container.get_child_count()):
			var lane = player_front_container.get_child(i)
			if lane and lane is PanelContainer:
				player_front_lanes.append(lane)
				_style_lane_panel(lane, true, true, i)
	
	# Find player back lanes
	var player_back_container = find_child("PlayerBackLanes", true, false)
	if player_back_container:
		for i in range(player_back_container.get_child_count()):
			var lane = player_back_container.get_child(i)
			if lane and lane is PanelContainer:
				player_back_lanes.append(lane)
				_style_lane_panel(lane, true, false, i)
	
	# Find enemy front lanes
	var enemy_front_container = find_child("EnemyFrontLanes", true, false)
	if enemy_front_container:
		for i in range(enemy_front_container.get_child_count()):
			var lane = enemy_front_container.get_child(i)
			if lane and lane is PanelContainer:
				enemy_front_lanes.append(lane)
				_style_lane_panel(lane, false, true, i)
	
	# Find enemy back lanes
	var enemy_back_container = find_child("EnemyBackLanes", true, false)
	if enemy_back_container:
		for i in range(enemy_back_container.get_child_count()):
			var lane = enemy_back_container.get_child(i)
			if lane and lane is PanelContainer:
				enemy_back_lanes.append(lane)
				_style_lane_panel(lane, false, false, i)
	
	print("[MainGame] Setup lanes - Player: %d front, %d back | Enemy: %d front, %d back" % [
		player_front_lanes.size(), player_back_lanes.size(),
		enemy_front_lanes.size(), enemy_back_lanes.size()
	])
	
	# Verify we have 5 lanes per row
	if player_front_lanes.size() != LANES_PER_ROW:
		push_warning("Expected %d player front lanes, got %d" % [LANES_PER_ROW, player_front_lanes.size()])
	if player_back_lanes.size() != LANES_PER_ROW:
		push_warning("Expected %d player back lanes, got %d" % [LANES_PER_ROW, player_back_lanes.size()])


func _style_lane_panel(panel: PanelContainer, is_player: bool, is_front: bool, index: int) -> void:
	# SET THE METADATA - This is what was missing!
	panel.set_meta("lane_index", index)
	panel.set_meta("is_front", is_front)
	panel.set_meta("is_player", is_player)
	
	var style := StyleBoxFlat.new()
	
	# Different colors for player vs enemy, front vs back
	if is_player:
		if is_front:
			style.bg_color = Color(0.15, 0.2, 0.15, 0.6)  # Greenish for player front
		else:
			style.bg_color = Color(0.12, 0.18, 0.12, 0.5)  # Darker green for player back
	else:
		if is_front:
			style.bg_color = Color(0.2, 0.15, 0.15, 0.6)  # Reddish for enemy front
		else:
			style.bg_color = Color(0.18, 0.12, 0.12, 0.5)  # Darker red for enemy back
	
	style.border_color = Color(0.35, 0.35, 0.4, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	
	panel.add_theme_stylebox_override("panel", style)


func _setup_player_controllers() -> void:
	# Setup player one (human)
	if player_one:
		player_one.player_id = 0
		player_one.is_ai = false
		player_one.front_lanes = player_front_lanes
		player_one.back_lanes = player_back_lanes
		player_one.enemy_front_lanes = enemy_front_lanes
		player_one.enemy_back_lanes = enemy_back_lanes
		player_one.enemy_hero_area = enemy_hero_area
		player_one.hero_area = player_hero_area
		print("[MainGame] Player 1 controller configured (hand_container: %s)" % (
			"SET" if player_one.hand_container else "NULL"
		))
	else:
		push_warning("[MainGame] Player 1 controller not found!")
	
	# Setup player two (AI)
	if player_two:
		player_two.player_id = 1
		player_two.is_ai = true
		player_two.front_lanes = enemy_front_lanes
		player_two.back_lanes = enemy_back_lanes
		player_two.enemy_front_lanes = player_front_lanes
		player_two.enemy_back_lanes = player_back_lanes
		player_two.enemy_hero_area = player_hero_area
		player_two.hero_area = enemy_hero_area
		print("[MainGame] Player 2 (AI) controller configured (hand_container: %s)" % (
			"SET" if player_two.hand_container else "NULL"
		))
	else:
		push_warning("[MainGame] Player 2 controller not found!")


func _start_game() -> void:
	# Reset game state first
	GameManager.reset_game()
	
	# Load player deck from GameManager meta
	var player_deck_cards: Array[CardData] = []
	var enemy_deck_cards: Array[CardData] = []
	
	# Get player deck
	if GameManager.has_meta("selected_deck"):
		var deck_data = GameManager.get_meta("selected_deck")
		if deck_data.has("cards"):
			player_deck_cards = _load_cards_from_ids(deck_data["cards"])
			print("[MainGame] Loaded player deck with %d cards" % player_deck_cards.size())
	
	# Get enemy deck (separate in test duel mode, otherwise copy player deck)
	if GameManager.has_meta("enemy_deck"):
		var enemy_deck_data = GameManager.get_meta("enemy_deck")
		if enemy_deck_data.has("cards"):
			enemy_deck_cards = _load_cards_from_ids(enemy_deck_data["cards"])
			print("[MainGame] Loaded separate enemy deck with %d cards" % enemy_deck_cards.size())
	else:
		# Duplicate player deck for enemy
		for card in player_deck_cards:
			enemy_deck_cards.append(card.duplicate())
	
	# If no decks loaded, create test deck
	if player_deck_cards.is_empty():
		print("[MainGame] No deck found, creating test deck")
		player_deck_cards = _create_test_deck()
		enemy_deck_cards = _create_test_deck()
	
	# Log test duel mode
	if GameManager.has_meta("test_duel_mode") and GameManager.get_meta("test_duel_mode"):
		print("[MainGame] TEST DUEL MODE - Random decks active")
	
	# Set up both players' decks using correct GameManager function
	GameManager.set_player_deck(0, player_deck_cards)
	GameManager.set_player_deck(1, enemy_deck_cards)
	
	# Hide game over panel
	if game_over_panel:
		game_over_panel.visible = false
	
	# Start the game
	GameManager.start_game()


## Load CardData resources from an array of card IDs
func _load_cards_from_ids(card_ids: Array) -> Array[CardData]:
	var cards: Array[CardData] = []
	
	for card_id in card_ids:
		var card_path := CARDS_PATH + str(card_id) + ".tres"
		
		if ResourceLoader.exists(card_path):
			var card_resource = load(card_path)
			if card_resource and card_resource is CardData:
				cards.append(card_resource)
			else:
				push_warning("[MainGame] Failed to load card: %s" % card_id)
		else:
			push_warning("[MainGame] Card not found: %s" % card_path)
	
	return cards


## Create a test deck with programmatically generated cards
func _create_test_deck() -> Array[CardData]:
	var deck: Array[CardData] = []
	
	# Create 15 basic test cards
	for i in range(15):
		var card := CardData.new()
		card.id = "test_minion_%d" % i
		card.card_name = "Test Minion %d" % (i % 5 + 1)
		card.cost = (i % 5) + 1
		card.attack = (i % 4) + 1
		card.health = (i % 4) + 2
		card.card_type = CardData.CardType.MINION
		card.description = "A test minion."
		deck.append(card)
	
	return deck


func _on_turn_started(player_id: int) -> void:
	print("[MainGame] Turn started for player %d" % player_id)
	_update_turn_button()
	_update_ui()


func _on_turn_ended(player_id: int) -> void:
	print("[MainGame] Turn ended for player %d" % player_id)


func _on_mana_changed(player_id: int, current: int, _max_val: int) -> void:
	if player_id == 0 and player_mana_label:
		player_mana_label.text = "%d / %d" % [current, _max_val]
	elif player_id == 1 and enemy_mana_label:
		enemy_mana_label.text = "%d / %d" % [current, _max_val]


func _on_health_changed(player_id: int, current: int, _max_val: int) -> void:
	if player_id == 0 and player_health_label:
		player_health_label.text = "HP: %d" % current
	elif player_id == 1 and enemy_health_label:
		enemy_health_label.text = "HP: %d" % current


func _on_card_drawn(_player_id: int, _card_data: CardData) -> void:
	# This will be handled by player controllers
	pass


func _on_game_over(winner_id: int) -> void:
	print("[MainGame] Game Over! Winner: Player %d" % winner_id)
	
	if game_over_panel:
		game_over_panel.visible = true
	
	if winner_label:
		if winner_id == 0:
			winner_label.text = "Victory!"
		else:
			winner_label.text = "Defeat!"
	
	# Wait a moment then transition
	await get_tree().create_timer(2.0).timeout
	
	if winner_id == 0:
		# Player won - go to victory/reward selection
		get_tree().change_scene_to_file("res://scenes/victory_selection.tscn")
	else:
		# Player lost - check if we should return to week runner
		if GameManager.has_meta("return_to_week_runner") and GameManager.get_meta("return_to_week_runner"):
			GameManager.set_meta("return_to_week_runner", false)
			
			# Advance the day even on loss
			var current_day: int = GameManager.get_meta("current_day_index") if GameManager.has_meta("current_day_index") else 0
			current_day += 1
			GameManager.set_meta("current_day_index", current_day)
			
			GameManager.reset_game()
			get_tree().change_scene_to_file("res://scenes/week_runner.tscn")
		else:
			# Not in schedule mode - return to start screen
			GameManager.reset_game()
			get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _on_turn_button_pressed() -> void:
	if GameManager.is_player_turn(0):
		GameManager.end_turn()


func _update_turn_button() -> void:
	if turn_button:
		turn_button.disabled = not GameManager.is_player_turn(0)
		turn_button.text = "End Turn" if GameManager.is_player_turn(0) else "Enemy Turn"


func _update_ui() -> void:
	# Update mana displays
	var p0 = GameManager.players[0]
	var p1 = GameManager.players[1]
	
	if player_mana_label:
		player_mana_label.text = "%d / %d" % [p0["current_mana"], p0["max_mana"]]
	if enemy_mana_label:
		enemy_mana_label.text = "%d / %d" % [p1["current_mana"], p1["max_mana"]]
	if player_health_label:
		player_health_label.text = "HP: %d" % p0["hero_health"]
	if enemy_health_label:
		enemy_health_label.text = "HP: %d" % p1["hero_health"]
	if player_deck_label:
		player_deck_label.text = "Deck: %d" % p0["deck"].size()
	if enemy_deck_label:
		enemy_deck_label.text = "Deck: %d" % p1["deck"].size()


func _apply_styling() -> void:
	# Style turn button
	if turn_button:
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.2, 0.35, 0.2)
		btn_style.border_color = Color(0.4, 0.6, 0.4)
		btn_style.set_border_width_all(2)
		btn_style.set_corner_radius_all(6)
		btn_style.set_content_margin_all(8)
		turn_button.add_theme_stylebox_override("normal", btn_style)
		
		var disabled_style = btn_style.duplicate()
		disabled_style.bg_color = Color(0.15, 0.15, 0.18)
		disabled_style.border_color = Color(0.3, 0.3, 0.3)
		turn_button.add_theme_stylebox_override("disabled", disabled_style)


func get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 3.0)


func _on_viewport_size_changed() -> void:
	# Could update responsive elements here
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# Return to menu
			get_tree().change_scene_to_file("res://scenes/start_screen.tscn")
