# res://scripts/player_controller.gd
class_name PlayerController
extends Node

## Signals
signal card_selected(card_ui: Control)
signal card_dropped_on_board(card_ui: Control)
signal targeting_started(source: Node)
signal targeting_ended(source: Node, target: Node)

## Player ID (0 or 1)
@export var player_id: int = 0

## Hand container reference
@export var hand_container: Control

## Lane references (set by main_game.gd)
var front_lanes: Array[Control] = []
var back_lanes: Array[Control] = []
var enemy_front_lanes: Array[Control] = []
var enemy_back_lanes: Array[Control] = []

## Hero areas
@export var enemy_hero_area: Control
@export var hero_area: Control

## Scene references
@export var card_ui_scene: PackedScene
@export var minion_scene: PackedScene
@export var targeting_arrow_scene: PackedScene

## Current targeting arrow
var _targeting_arrow: Node = null

## Currently dragged card (from hand)
var _dragged_card: Control = null

## Currently selected board entity (for attacking OR moving)
var _selected_attacker: Node = null

## Is AI controlled?
@export var is_ai: bool = false

## AI action delay (seconds between actions)
@export var ai_action_delay: float = 0.8

## Reference resolution for scaling
const REFERENCE_HEIGHT = 720.0


func _ready() -> void:
	GameManager.turn_started.connect(_on_turn_started)
	GameManager.card_drawn.connect(_on_card_drawn)
	
	call_deferred("_deferred_ready")


func _deferred_ready() -> void:
	GameManager.register_controller_ready()


func get_scale_factor() -> float:
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	return clampf(viewport_height / REFERENCE_HEIGHT, 0.8, 2.0)


## =============================================================================
## TURN MANAGEMENT
## =============================================================================

func _on_turn_started(turn_player_id: int) -> void:
	if turn_player_id == player_id:
		_enable_hand_interaction(true)
		_refresh_board_minions()
		
		if is_ai:
			call_deferred("_ai_take_turn")
	else:
		_enable_hand_interaction(false)


func _on_card_drawn(draw_player_id: int, card: CardData) -> void:
	if draw_player_id != player_id:
		return
	
	if not hand_container:
		push_warning("[PlayerController %d] Cannot add card - no hand_container!" % player_id)
		return
	
	_create_card_ui(card)


func _enable_hand_interaction(enabled: bool) -> void:
	if not hand_container:
		return
	
	for card_ui_instance in hand_container.get_children():
		if card_ui_instance.has_method("set_interactable"):
			card_ui_instance.set_interactable(enabled)


func _refresh_board_minions() -> void:
	for lane in front_lanes + back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				if child.has_method("refresh_for_turn"):
					child.refresh_for_turn()


func _clear_hand() -> void:
	if not hand_container:
		return
	for child in hand_container.get_children():
		child.queue_free()


func _clear_board() -> void:
	for lane in front_lanes + back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				child.queue_free()


func request_end_turn() -> void:
	if GameManager.is_player_turn(player_id):
		GameManager.end_turn()


## =============================================================================
## CARD UI CREATION
## =============================================================================

func _create_card_ui(card: CardData) -> void:
	if not card_ui_scene:
		push_warning("[PlayerController %d] No card_ui_scene assigned!" % player_id)
		return
	
	var card_ui = card_ui_scene.instantiate()
	hand_container.add_child(card_ui)
	
	if card_ui.has_method("setup"):
		card_ui.setup(card)
	
	# Connect signals
	if card_ui.has_signal("card_clicked"):
		card_ui.card_clicked.connect(_on_hand_card_clicked)
	if card_ui.has_signal("card_drag_started"):
		card_ui.card_drag_started.connect(_on_card_drag_started)
	if card_ui.has_signal("card_drag_ended"):
		card_ui.card_drag_ended.connect(_on_card_drag_ended)


## =============================================================================
## CARD PLAYING
## =============================================================================

func _on_hand_card_clicked(card_ui: Control) -> void:
	if is_ai or not GameManager.is_player_turn(player_id):
		return
	
	card_selected.emit(card_ui)


func _on_card_drag_started(card_ui: Control) -> void:
	if is_ai or not GameManager.is_player_turn(player_id):
		return
	
	_dragged_card = card_ui


func _on_card_drag_ended(card_ui: Control, global_pos: Vector2) -> void:
	if is_ai or not GameManager.is_player_turn(player_id):
		return

	_dragged_card = null

	# Check if dropped on a valid lane
	for lane in front_lanes + back_lanes:
		if lane and lane.get_global_rect().has_point(global_pos):
			_try_play_card_to_lane(card_ui, lane)
			return

	# No valid lane found - return card to hand
	if card_ui.has_method("return_to_hand"):
		card_ui.return_to_hand()


func _try_play_card_to_lane(card_ui: Control, lane: Control) -> void:
	var card_data: CardData = card_ui.card_data
	if not card_data:
		card_ui.return_to_hand()
		return

	# Check if can play (includes modifier checks via GameManager)
	if not GameManager.can_play_card(player_id, card_data):
		print("[PlayerController %d] Cannot play card - insufficient mana or blocked" % player_id)
		card_ui.return_to_hand()
		return

	# Check lane availability only for minions (unless Huddle)
	if card_data.card_type == CardData.CardType.MINION:
		if not card_data.has_keyword("Huddle") and not _is_lane_empty(lane):
			print("[PlayerController %d] Lane is occupied!" % player_id)
			card_ui.return_to_hand()
			return

	# Play the card
	if GameManager.play_card(player_id, card_data):
		if card_data.card_type == CardData.CardType.MINION:
			var lane_index = lane.get_meta("lane_index", 0)
			var is_front = lane.get_meta("is_front", true)
			_spawn_minion(card_data, lane_index, is_front, lane)
		else:
			print("[PlayerController %d] Played action: %s" % [player_id, card_data.card_name])

		card_ui.queue_free()
	else:
		# Play failed for some reason
		card_ui.return_to_hand()


func _spawn_minion(card_data: CardData, lane_index: int, is_front: bool, lane: Control) -> void:
	if not minion_scene:
		push_warning("[PlayerController %d] No minion_scene assigned!" % player_id)
		return
	
	var minion = minion_scene.instantiate()
	var slot = _get_minion_slot(lane)
	
	if not slot:
		push_warning("[PlayerController %d] No slot found in lane!" % player_id)
		minion.queue_free()
		return
	
	slot.add_child(minion)
	minion.initialize(card_data, player_id)
	minion.lane_index = lane_index
	minion.is_front_row = is_front
	
	# Connect minion signals
	minion.minion_clicked.connect(_on_minion_clicked)
	minion.minion_drag_started.connect(_on_minion_drag_started)
	minion.minion_drag_ended.connect(_on_minion_drag_ended)
	
	# Register with GameManager (includes modifier hook)
	GameManager.register_minion_on_board(player_id, minion, lane_index, 0 if is_front else 1)
	
	print("[PlayerController %d] Spawned %s in lane %d (%s)" % [
		player_id, card_data.card_name, lane_index, "front" if is_front else "back"
	])


## =============================================================================
## BOARD HELPERS
## =============================================================================

func _get_minion_slot(lane: Control) -> Control:
	if lane.has_node("MinionSlot"):
		return lane.get_node("MinionSlot")
	# Fallback: use lane itself as container
	return lane


func _is_lane_empty(lane: Control) -> bool:
	var slot = _get_minion_slot(lane)
	if not slot:
		return false
	return slot.get_child_count() == 0


func _is_enemy_front_row_empty() -> bool:
	for lane in enemy_front_lanes:
		if not _is_lane_empty(lane):
			return false
	return true


func _get_all_minions() -> Array[Node]:
	var minions: Array[Node] = []
	for lane in front_lanes + back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				if child is Minion:
					minions.append(child)
	return minions


func _get_all_enemy_minions() -> Array[Node]:
	var minions: Array[Node] = []
	for lane in enemy_front_lanes + enemy_back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				if child is Minion:
					minions.append(child)
	return minions


## =============================================================================
## TARGETING AND COMBAT
## =============================================================================

func _try_start_arrow_interaction(minion_instance: Node) -> void:
	if is_ai or not GameManager.is_player_turn(player_id):
		return
	
	if minion_instance.owner_id != player_id:
		if _selected_attacker:
			_on_minion_targeted(minion_instance)
		return
	
	var can_attack_enemies = minion_instance.can_attack()
	if not minion_instance.is_front_row and not minion_instance.has_snipe:
		can_attack_enemies = false
	
	var can_move_lanes = (not minion_instance.has_attacked) and (not minion_instance.has_moved_this_turn)
	
	if can_attack_enemies or can_move_lanes:
		_selected_attacker = minion_instance
		_start_targeting(minion_instance)
		_highlight_valid_targets()
	else:
		print("[PlayerController %d] Minion cannot act" % player_id)


func _on_minion_clicked(minion_instance: Node) -> void:
	_try_start_arrow_interaction(minion_instance)


func _on_minion_drag_started(minion_instance: Node) -> void:
	_try_start_arrow_interaction(minion_instance)


func _on_minion_drag_ended(_minion_instance: Node, _global_pos: Vector2) -> void:
	pass


func _on_minion_targeted(minion_instance: Node) -> void:
	if not _selected_attacker:
		return
	
	if minion_instance.owner_id == player_id:
		_cancel_targeting()
		return
	
	var allowed_to_attack = _selected_attacker.can_attack()
	if not _selected_attacker.is_front_row and not _selected_attacker.has_snipe:
		allowed_to_attack = false
	
	if not allowed_to_attack:
		print("[PlayerController %d] Minion cannot attack from back row!" % player_id)
		_cancel_targeting()
		return
	
	# MODIFIER HOOK: Check if targeting is allowed
	if ModifierManager:
		if not ModifierManager.can_target(_selected_attacker, minion_instance):
			print("[PlayerController %d] Targeting blocked by modifier!" % player_id)
			_cancel_targeting()
			return
	
	if minion_instance.has_hidden:
		print("[PlayerController %d] Cannot target Hidden minion!" % player_id)
		_cancel_targeting()
		return
	
	if not GameManager.is_valid_attack_target(_selected_attacker.owner_id, minion_instance):
		print("[PlayerController %d] Must target a Taunt minion in that row!" % player_id)
		_cancel_targeting()
		return
	
	var is_front_row_target = minion_instance.is_front_row
	var front_row_empty = _is_enemy_front_row_empty()
	
	if not _selected_attacker.has_snipe:
		if not is_front_row_target and not front_row_empty:
			print("[PlayerController %d] Must target front row first!" % player_id)
			_cancel_targeting()
			return
	
	# Execute combat
	_execute_attack(_selected_attacker, minion_instance)
	_cancel_targeting()


func target_enemy_hero() -> void:
	if not _selected_attacker:
		return
	
	# Check Rush restriction
	if _selected_attacker.just_played and _selected_attacker.has_rush and not _selected_attacker.has_charge:
		print("[PlayerController %d] Rush minion cannot attack hero on first turn!" % player_id)
		_cancel_targeting()
		return
	
	# Check if can attack from position
	if not _selected_attacker.is_front_row and not _selected_attacker.has_snipe:
		print("[PlayerController %d] Cannot attack hero from back row!" % player_id)
		_cancel_targeting()
		return
	
	# Check if front row is clear (unless has Snipe)
	if not _selected_attacker.has_snipe:
		for lane in enemy_front_lanes:
			if not _is_lane_empty(lane):
				# Check for taunt
				var slot = _get_minion_slot(lane)
				for child in slot.get_children():
					if child is Minion and child.has_taunt:
						print("[PlayerController %d] Must attack Taunt minion first!" % player_id)
						_cancel_targeting()
						return
	
	# Attack enemy hero
	var enemy_id = 1 if player_id == 0 else 0
	GameManager.attack_hero(_selected_attacker, enemy_id)
	
	targeting_ended.emit(_selected_attacker, null)
	_cancel_targeting()


func _execute_attack(attacker: Node, defender: Node) -> void:
	targeting_ended.emit(attacker, defender)
	GameManager.execute_combat(attacker, defender)


## =============================================================================
## TARGETING VISUALS
## =============================================================================

func _start_targeting(source: Node) -> void:
	if targeting_arrow_scene and not _targeting_arrow:
		_targeting_arrow = targeting_arrow_scene.instantiate()
		get_tree().root.add_child(_targeting_arrow)
		_targeting_arrow.start_from(source.global_position + source.size / 2)
	
	targeting_started.emit(source)


func _cancel_targeting() -> void:
	if _targeting_arrow:
		_targeting_arrow.queue_free()
		_targeting_arrow = null
	
	_clear_target_highlights()
	_selected_attacker = null


func _highlight_valid_targets() -> void:
	if not _selected_attacker:
		return
	
	# Get all potential targets
	var all_enemy_minions = _get_all_enemy_minions()
	
	# MODIFIER HOOK: Filter targets through modifiers
	var valid_targets = all_enemy_minions
	if ModifierManager:
		valid_targets = ModifierManager.filter_targets(_selected_attacker, all_enemy_minions)
	
	for minion in all_enemy_minions:
		var is_valid = minion in valid_targets
		is_valid = is_valid and not minion.has_hidden
		is_valid = is_valid and GameManager.is_valid_attack_target(_selected_attacker.owner_id, minion)
		
		# Check row restrictions
		if not _selected_attacker.has_snipe:
			if not minion.is_front_row and not _is_enemy_front_row_empty():
				is_valid = false
		
		minion.set_targetable(is_valid)


func _clear_target_highlights() -> void:
	for minion in _get_all_enemy_minions():
		minion.set_targetable(false)


func _check_attack_target(global_pos: Vector2) -> void:
	# Check Enemy Hero
	if enemy_hero_area and enemy_hero_area.get_global_rect().has_point(global_pos):
		target_enemy_hero()
		return
	
	# Check Enemy Minions
	for lane in enemy_front_lanes + enemy_back_lanes:
		var slot = _get_minion_slot(lane)
		if slot:
			for child in slot.get_children():
				if child is Control and child.get_global_rect().has_point(global_pos):
					_on_minion_targeted(child)
					return
	
	# Check Friendly Lanes (For Movement)
	if _selected_attacker and (not _selected_attacker.has_moved_this_turn) and (not _selected_attacker.has_attacked):
		for lane in front_lanes + back_lanes:
			if lane and lane.get_global_rect().has_point(global_pos):
				if _is_lane_empty(lane):
					var lane_index = lane.get_meta("lane_index", -1)
					var is_front = lane.get_meta("is_front", false)
					
					if lane_index == _selected_attacker.lane_index and is_front == _selected_attacker.is_front_row:
						pass  # Same position, ignore
					else:
						_move_minion_to_row(_selected_attacker, is_front, lane_index)
					
					_cancel_targeting()
					return
	
	_cancel_targeting()


func _move_minion_to_row(minion: Node, to_front: bool, to_lane: int) -> void:
	# Remove from current position
	var current_parent = minion.get_parent()
	if current_parent:
		current_parent.remove_child(minion)
	
	# Find new lane
	var target_lane: Control = null
	var lanes = front_lanes if to_front else back_lanes
	for lane in lanes:
		if lane.get_meta("lane_index", -1) == to_lane:
			target_lane = lane
			break
	
	if not target_lane:
		# Put back in original position
		current_parent.add_child(minion)
		return
	
	var slot = _get_minion_slot(target_lane)
	slot.add_child(minion)
	
	minion.is_front_row = to_front
	minion.lane_index = to_lane
	minion.has_moved_this_turn = true
	
	print("[PlayerController %d] Moved minion to lane %d (%s)" % [
		player_id, to_lane, "front" if to_front else "back"
	])


## =============================================================================
## INPUT HANDLING
## =============================================================================

func _input(event: InputEvent) -> void:
	if is_ai:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_targeting()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _selected_attacker and _targeting_arrow:
				_check_attack_target(event.global_position)


func _process(_delta: float) -> void:
	if _targeting_arrow and _selected_attacker:
		_targeting_arrow.update_end_position(get_viewport().get_mouse_position())


## =============================================================================
## AI LOGIC
## =============================================================================

func _ai_take_turn() -> void:
	if not is_ai or not GameManager.is_player_turn(player_id):
		return
	
	if not hand_container:
		push_warning("[PlayerController %d] AI cannot take turn - no hand_container!" % player_id)
		await get_tree().create_timer(ai_action_delay).timeout
		GameManager.end_turn()
		return
	
	# Play cards
	await _ai_play_cards()
	
	# Attack with minions
	await _ai_attack_with_minions()
	
	# End turn
	await get_tree().create_timer(ai_action_delay).timeout
	GameManager.end_turn()


func _ai_play_cards() -> void:
	var played_any = true
	
	while played_any and GameManager.is_player_turn(player_id):
		played_any = false
		
		# Get playable cards sorted by cost (highest first for simple AI)
		var playable_cards: Array = []
		for card_ui in hand_container.get_children():
			if card_ui.has_method("get_card_data"):
				var card_data: CardData = card_ui.card_data
				if GameManager.can_play_card(player_id, card_data):
					playable_cards.append({"ui": card_ui, "data": card_data})
		
		# Sort by cost descending
		playable_cards.sort_custom(func(a, b): 
			return GameManager.get_card_cost(a["data"], player_id) > GameManager.get_card_cost(b["data"], player_id)
		)
		
		for card_info in playable_cards:
			var lane = _ai_find_empty_lane()
			if lane:
				await get_tree().create_timer(ai_action_delay).timeout
				_try_play_card_to_lane(card_info["ui"], lane)
				played_any = true
				break


func _ai_find_empty_lane() -> Control:
	# Prefer front row
	for lane in front_lanes:
		if _is_lane_empty(lane):
			return lane
	for lane in back_lanes:
		if _is_lane_empty(lane):
			return lane
	return null


func _ai_attack_with_minions() -> void:
	var my_minions = _get_all_minions()
	
	for minion in my_minions:
		if not GameManager.is_player_turn(player_id):
			break
		
		if not minion.can_attack():
			continue
		
		if not minion.can_attack_from_row():
			continue
		
		await get_tree().create_timer(ai_action_delay).timeout
		
		# Find a target
		var target = _ai_find_best_target(minion)
		if target:
			GameManager.execute_combat(minion, target)
		elif _is_enemy_front_row_empty():
			# Attack hero
			var enemy_id = 1 if player_id == 0 else 0
			if not minion.just_played or minion.has_charge or not minion.has_rush:
				GameManager.attack_hero(minion, enemy_id)


func _ai_find_best_target(attacker: Node) -> Node:
	var enemy_minions = _get_all_enemy_minions()
	
	# MODIFIER HOOK: Filter targets
	if ModifierManager:
		enemy_minions = ModifierManager.filter_targets(attacker, enemy_minions)
	
	# Prioritize taunt minions, then weakest
	var valid_targets: Array = []
	
	for minion in enemy_minions:
		if minion.has_hidden:
			continue
		if not GameManager.is_valid_attack_target(attacker.owner_id, minion):
			continue
		
		# Check row restrictions
		if not attacker.has_snipe:
			if not minion.is_front_row and not _is_enemy_front_row_empty():
				continue
		
		valid_targets.append(minion)
	
	if valid_targets.is_empty():
		return null
	
	# Sort: taunt first, then by health (kill weakest)
	valid_targets.sort_custom(func(a, b):
		if a.has_taunt != b.has_taunt:
			return a.has_taunt  # Taunt first
		return a.current_health < b.current_health  # Then weakest
	)
	
	return valid_targets[0]
