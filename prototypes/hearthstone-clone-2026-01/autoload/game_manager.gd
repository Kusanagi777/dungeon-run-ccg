# res://autoload/game_manager.gd
extends Node

## =============================================================================
## SIGNALS
## =============================================================================

## Core game signals
signal game_started()
signal game_ended(winner_id: int)
signal turn_started(player_id: int)
signal turn_ended(player_id: int)

## Card signals
signal card_drawn(player_id: int, card: CardData)
signal card_played(player_id: int, card: CardData)
signal card_discarded(player_id: int, card: CardData)

## Resource signals
signal mana_changed(player_id: int, current: int, maximum: int)
signal health_changed(player_id: int, current: int, maximum: int)

## Combat signals
signal combat_occurred(attacker_data: Dictionary, defender_data: Dictionary)
signal minion_died(player_id: int, minion: Node, board_position: int)
signal minion_summoned(player_id: int, minion: Node)


## =============================================================================
## CONSTANTS
## =============================================================================

## Game phase enumeration
enum GamePhase {
	IDLE,
	STARTING,
	DRAW,
	PLAY,
	COMBAT,
	END_TURN,
	GAME_OVER
}

## Player ID constants
const PLAYER_ONE: int = 0
const PLAYER_TWO: int = 1

## Mana system constants
const MAX_MANA_CAP: int = 10
const STARTING_HAND_SIZE: int = 3
const CARDS_DRAWN_PER_TURN: int = 1
const MAX_BOARD_SIZE: int = 7
const MAX_HAND_SIZE: int = 10
const STARTING_HEALTH: int = 30


## =============================================================================
## STATE VARIABLES
## =============================================================================

## Current game phase
var current_phase: GamePhase = GamePhase.IDLE

## Active player (whose turn it is)
var active_player: int = PLAYER_ONE

## Turn counter
var turn_number: int = 0

## Player data storage
var players: Array[Dictionary] = []

## Track if game is initialized
var _game_initialized: bool = false

## Track first turn for draw skip
var _first_turn: Array[bool] = [true, true]

## Track deferred card draws
var _deferred_draws: Array[Dictionary] = []

## Track controller readiness
var _controllers_ready: bool = false

## Conduit bonus tracking
var conduit_bonus: Array[int] = [0, 0]

## Track last card type for Empowered
var last_card_was_action: Array[bool] = [false, false]


## =============================================================================
## INITIALIZATION
## =============================================================================

func _ready() -> void:
	_initialize_player_data()


func _initialize_player_data() -> void:
	players.clear()
	for i in range(2):
		players.append({
			"current_mana": 0,
			"max_mana": 0,
			"hero_health": STARTING_HEALTH,
			"hero_max_health": STARTING_HEALTH,
			"hero_armor": 0,
			"deck": [] as Array[CardData],
			"hand": [] as Array[CardData],
			"board": [] as Array[Node],
			"graveyard": [] as Array[CardData],
			"fatigue_counter": 0,
			"cards_drawn_this_turn": [] as Array[String],
			# Class resource (Battery, Hunger, Spirit, etc.)
			"class_resource": 0,
			"max_class_resource": 10,
			"class_resource_type": ""  # Set based on class selection
		})


## Reset game to initial state
func reset_game() -> void:
	_game_initialized = false
	_controllers_ready = false
	_first_turn = [true, true]
	_deferred_draws.clear()
	turn_number = 0
	active_player = PLAYER_ONE
	current_phase = GamePhase.IDLE
	conduit_bonus = [0, 0]
	last_card_was_action = [false, false]
	_initialize_player_data()
	
	# Clear modifiers on game reset
	if ModifierManager:
		ModifierManager.clear_all_modifiers()


## Called by PlayerController when it's ready
func register_controller_ready() -> void:
	if not _controllers_ready:
		call_deferred("_check_controllers_ready")


func _check_controllers_ready() -> void:
	_controllers_ready = true
	_flush_deferred_draws()


func _flush_deferred_draws() -> void:
	for draw_data in _deferred_draws:
		card_drawn.emit(draw_data["player_id"], draw_data["card"])
	_deferred_draws.clear()


## =============================================================================
## GAME FLOW
## =============================================================================

func start_game() -> void:
	if _game_initialized:
		return
	
	_game_initialized = true
	current_phase = GamePhase.STARTING
	
	# Shuffle decks
	for i in range(2):
		players[i]["deck"].shuffle()
	
	# Draw starting hands
	for i in range(2):
		for j in range(STARTING_HAND_SIZE):
			_draw_card(i)
	
	game_started.emit()
	
	# Start first turn
	_start_turn(PLAYER_ONE)


func _start_turn(player_id: int) -> void:
	active_player = player_id
	turn_number += 1
	current_phase = GamePhase.DRAW
	
	print("[GameManager] === Turn %d - Player %d ===" % [turn_number, player_id])
	
	# Increment max mana (up to cap) - WITH MODIFIER
	var p := players[player_id]
	var base_mana_gain := 1
	var modified_mana_gain := base_mana_gain
	if ModifierManager:
		modified_mana_gain = ModifierManager.apply_mana_gain_modifiers(base_mana_gain, player_id)
	
	p["max_mana"] = mini(p["max_mana"] + modified_mana_gain, MAX_MANA_CAP)
	p["current_mana"] = p["max_mana"]
	
	# Clear cards drawn this turn tracking
	p["cards_drawn_this_turn"].clear()
	
	mana_changed.emit(player_id, p["current_mana"], p["max_mana"])
	
	# Draw card (skip on very first turn for player going first)
	if _first_turn[player_id]:
		_first_turn[player_id] = false
	else:
		_draw_card(player_id)
	
	# Reset minion attacks
	_reset_minion_attacks(player_id)
	
	current_phase = GamePhase.PLAY
	
	# MODIFIER HOOK: Trigger turn start
	if ModifierManager:
		ModifierManager.trigger_turn_start(player_id)
	
	turn_started.emit(player_id)


func end_turn() -> void:
	if current_phase == GamePhase.GAME_OVER:
		return
	
	current_phase = GamePhase.END_TURN
	
	# MODIFIER HOOK: Trigger turn end
	if ModifierManager:
		ModifierManager.trigger_turn_end(active_player)
	
	turn_ended.emit(active_player)
	
	# Switch to other player
	var next_player := PLAYER_TWO if active_player == PLAYER_ONE else PLAYER_ONE
	_start_turn(next_player)


func _reset_minion_attacks(player_id: int) -> void:
	var board: Array = players[player_id]["board"]
	for minion in board:
		if is_instance_valid(minion):
			minion.has_attacked = false
			minion.attacks_this_turn = 0


## =============================================================================
## CARD DRAWING
## =============================================================================

func _draw_card(player_id: int) -> void:
	var p := players[player_id]
	var deck: Array = p["deck"]
	var hand: Array = p["hand"]
	
	if deck.is_empty():
		# Fatigue damage
		p["fatigue_counter"] += 1
		var fatigue_damage: int = p["fatigue_counter"]
		p["hero_health"] -= fatigue_damage
		print("[GameManager] Player %d takes %d fatigue damage!" % [player_id, fatigue_damage])
		health_changed.emit(player_id, p["hero_health"], p["hero_max_health"])
		_check_hero_death(player_id)
		return
	
	if hand.size() >= MAX_HAND_SIZE:
		# Overdraw - burn card
		var burned_card: CardData = deck.pop_back()
		p["graveyard"].append(burned_card)
		print("[GameManager] Player %d hand full, burned: %s" % [player_id, burned_card.card_name])
		
		# MODIFIER HOOK: Card discarded (burned)
		if ModifierManager:
			ModifierManager.trigger_card_discarded(burned_card, player_id)
		
		card_discarded.emit(player_id, burned_card)
		return
	
	var drawn_card: CardData = deck.pop_back()
	hand.append(drawn_card)
	
	# Track for Fated keyword
	p["cards_drawn_this_turn"].append(drawn_card.id)
	
	print("[GameManager] Player %d drew: %s" % [player_id, drawn_card.card_name])
	
	# MODIFIER HOOK: Card drawn
	if ModifierManager:
		ModifierManager.trigger_card_drawn(drawn_card, player_id)
	
	if _controllers_ready:
		card_drawn.emit(player_id, drawn_card)
	else:
		_deferred_draws.append({"player_id": player_id, "card": drawn_card})


## =============================================================================
## MANA MANAGEMENT
## =============================================================================

func spend_mana(player_id: int, amount: int) -> bool:
	var p := players[player_id]
	if p["current_mana"] >= amount:
		p["current_mana"] -= amount
		mana_changed.emit(player_id, p["current_mana"], p["max_mana"])
		return true
	return false


func get_current_mana(player_id: int) -> int:
	return players[player_id]["current_mana"]


func get_max_mana(player_id: int) -> int:
	return players[player_id]["max_mana"]


func add_mana(player_id: int, amount: int) -> void:
	var p := players[player_id]
	p["current_mana"] = mini(p["current_mana"] + amount, p["max_mana"])
	mana_changed.emit(player_id, p["current_mana"], p["max_mana"])


## =============================================================================
## CARD PLAYING
## =============================================================================

func can_play_card(player_id: int, card: CardData) -> bool:
	if not is_player_turn(player_id):
		return false
	
	var effective_cost := get_effective_card_cost(card, player_id)
	if get_current_mana(player_id) < effective_cost:
		return false
	
	# Check board space for minions
	if card.is_minion():
		if players[player_id]["board"].size() >= MAX_BOARD_SIZE:
			return false
	
	return true


func play_card(player_id: int, card: CardData, target: Variant = null) -> bool:
	if not can_play_card(player_id, card):
		return false
	
	var effective_cost := get_effective_card_cost(card, player_id)
	spend_mana(player_id, effective_cost)
	
	# Remove from hand
	var hand: Array = players[player_id]["hand"]
	hand.erase(card)
	
	# Update Empowered tracking
	update_last_card_type(card, player_id)
	
	# MODIFIER HOOK: Card played
	if ModifierManager:
		ModifierManager.trigger_card_played(card, player_id, target)	
	card_played.emit(player_id, card)
	
	return true


## =============================================================================
## BOARD MANAGEMENT
## =============================================================================

func add_minion_to_board(player_id: int, minion: Node) -> bool:
	var board: Array = players[player_id]["board"]
	if board.size() >= MAX_BOARD_SIZE:
		return false
	
	board.append(minion)
	
	# MODIFIER HOOK: Minion summoned
	if ModifierManager:
		var lane: int = minion.lane_index if minion.has_method("get") else 0
		var row: int = 0 if minion.is_front_row else 1 if "is_front_row" in minion else 0
		ModifierManager.trigger_minion_summoned(minion, player_id, lane, row)	
	# Check tag synergies
	check_role_synergies(player_id, minion)
	check_biology_synergies(player_id, minion)
	
	# Recalculate conduit
	recalculate_conduit(player_id)
	
	minion_summoned.emit(player_id, minion)
	return true


func remove_minion_from_board(player_id: int, minion: Node) -> void:
	var board: Array = players[player_id]["board"]
	board.erase(minion)
	
	# Recalculate conduit
	recalculate_conduit(player_id)


func get_board(player_id: int) -> Array:
	return players[player_id]["board"]


func get_board_size(player_id: int) -> int:
	return players[player_id]["board"].size()


## =============================================================================
## AFFINITY KEYWORD - Updated for Dual Tags
## =============================================================================

## Calculate affinity cost reduction
func get_affinity_reduction(card: CardData, player_id: int) -> int:
	if not card.has_keyword_base("Affinity"):
		return 0
	
	# Parse which tag provides affinity
	var affinity_info := _parse_affinity_tag(card)
	if affinity_info.is_empty():
		return 0
	
	# Count matching minions on board
	var board: Array = players[player_id]["board"]
	var count := 0
	
	var tag_type: String = affinity_info.get("type", "")
	var tag_value: String = affinity_info.get("value", "")
	
	if tag_type == "role":
		var role := MinionTags.get_role_from_name(tag_value)
		if role != MinionTags.Role.NONE:
			count = MinionTags.count_role_on_board(board, role)
	elif tag_type == "biology":
		var bio := MinionTags.get_biology_from_name(tag_value)
		# HUMANOID is the default, so we count it too
		for minion in board:
			if is_instance_valid(minion) and minion.card_data:
				if minion.card_data.biology_tag == bio:
					count += 1
	
	return count


## Parse affinity tag from card keywords - returns Dictionary with "type" and "value"
func _parse_affinity_tag(card: CardData) -> Dictionary:
	for kw in card.keywords:
		var kw_lower := kw.to_lower()
		if kw_lower.begins_with("affinity"):
			# Biology tags
			if "beast" in kw_lower:
				return {"type": "biology", "value": "beast"}
			elif "construct" in kw_lower:
				return {"type": "biology", "value": "construct"}
			elif "elemental" in kw_lower:
				return {"type": "biology", "value": "elemental"}
			elif "flora" in kw_lower:
				return {"type": "biology", "value": "flora"}
			elif "horror" in kw_lower:
				return {"type": "biology", "value": "horror"}
			elif "undead" in kw_lower:
				return {"type": "biology", "value": "undead"}
			elif "vermin" in kw_lower:
				return {"type": "biology", "value": "vermin"}
			elif "celestial" in kw_lower:
				return {"type": "biology", "value": "celestial"}
			elif "humanoid" in kw_lower:
				return {"type": "biology", "value": "humanoid"}
			# Role tags
			elif "warrior" in kw_lower:
				return {"type": "role", "value": "warrior"}
			elif "raider" in kw_lower:
				return {"type": "role", "value": "raider"}
			elif "savant" in kw_lower:
				return {"type": "role", "value": "savant"}
			elif "commander" in kw_lower:
				return {"type": "role", "value": "commander"}
			elif "zealot" in kw_lower:
				return {"type": "role", "value": "zealot"}
			elif "titan" in kw_lower:
				return {"type": "role", "value": "titan"}
	
	return {}


## =============================================================================
## CONDUIT KEYWORD
## =============================================================================

## Recalculate total conduit bonus for a player
func recalculate_conduit(player_id: int) -> void:
	var board: Array = players[player_id]["board"]
	var total := 0
	
	for minion in board:
		if is_instance_valid(minion) and minion.has_conduit:
			total += minion.conduit_value
	
	conduit_bonus[player_id] = total
	print("[GameManager] Player %d conduit bonus: +%d" % [player_id, total])


## Get action card damage bonus
func get_conduit_bonus(player_id: int) -> int:
	return conduit_bonus[player_id]


## =============================================================================
## EMPOWERED KEYWORD
## =============================================================================

## Check if Empowered should trigger
func check_empowered(player_id: int) -> bool:
	return last_card_was_action[player_id]


## Update action card tracking (call after playing any card)
func update_last_card_type(card: CardData, player_id: int) -> void:
	last_card_was_action[player_id] = card.is_action()


## =============================================================================
## SACRIFICE / RITUAL KEYWORD
## =============================================================================

signal sacrifice_requested(player_id: int, count: int, callback: Callable)

## Request sacrifice minions for effect
func request_sacrifice(player_id: int, count: int, on_complete: Callable) -> void:
	sacrifice_requested.emit(player_id, count, on_complete)


## Execute sacrifice
func execute_sacrifice(player_id: int, minions: Array[Node]) -> void:
	for minion in minions:
		if is_instance_valid(minion):
			print("[GameManager] Sacrificing %s" % minion.card_data.card_name)
			minion.die()


## =============================================================================
## BOUNTY KEYWORD
## =============================================================================

signal bounty_triggered(source_player: int, receiving_player: int, card_name: String)

## Trigger bounty reward (called when bounty minion dies)
func trigger_bounty(dying_minion: Node) -> void:
	var receiving_player: int = 1 - dying_minion.owner_id
	
	# Default bounty: draw a card
	_draw_card(receiving_player)
	
	bounty_triggered.emit(dying_minion.owner_id, receiving_player, dying_minion.card_data.card_name)
	print("[GameManager] Bounty: Player %d draws a card from %s" % [receiving_player, dying_minion.card_data.card_name])


## =============================================================================
## COMBAT INTEGRATION
## =============================================================================

## Enhanced execute_combat with keyword support
func execute_combat_with_keywords(attacker: Node, defender: Node) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	
	var attacker_damage: int = attacker.get_effective_attack()
	var defender_damage: int = defender.get_effective_attack()
	
	# Check Bully bonus
	if attacker.has_bully and defender_damage < attacker_damage:
		print("[GameManager] Bully triggered! %s gets bonus vs %s" % [attacker.card_data.card_name, defender.card_data.card_name])
		# Bully effect handled by card's specific effect
	
	# Hidden is removed when attacking
	if attacker.has_hidden:
		attacker.has_hidden = false
		print("[GameManager] %s revealed after attacking!" % attacker.card_data.card_name)
	
	# Illusion dies on being attacked
	if defender.has_illusion:
		print("[GameManager] Illusion %s dies on interaction!" % defender.card_data.card_name)
		defender.die()
		attacker.attacks_this_turn += 1
		return
	
	# Apply damage
	defender.take_damage(attacker_damage)
	attacker.take_damage(defender_damage)
	
	# Pierce damage to hero
	if attacker.has_pierce and is_instance_valid(defender):
		attacker.apply_pierce_damage(defender, attacker_damage)
	
	# Drain heals attacker's hero
	if attacker.has_drain and attacker_damage > 0:
		_heal_hero(attacker.owner_id, attacker_damage)
		print("[GameManager] Drain healed player %d for %d" % [attacker.owner_id, attacker_damage])
	
	# Lethal destroys defender regardless of damage
	if attacker.has_lethal and attacker_damage > 0 and is_instance_valid(defender):
		if defender.current_health > 0:
			print("[GameManager] Lethal triggered - %s destroyed!" % defender.card_data.card_name)
			defender.die()
	
	# Update attack counter
	attacker.attacks_this_turn += 1


## =============================================================================
## AFFINITY CALCULATION - Updated for Dual Tags
## =============================================================================

## Get affinity count for a card using the dual tag system
func get_affinity_count_dual_tags(card: CardData, player_id: int) -> int:
	# Check if card has a method to get affinity tag type
	if not card.has_method("get_affinity_tag_type"):
		return 0
	
	var affinity_type: String = card.get_affinity_tag_type()
	if affinity_type.is_empty():
		return 0
	
	var board: Array = players[player_id]["board"]
	var count := 0
	
	# Parse affinity type (format: "role:warrior" or "biology:beast")
	var parts: PackedStringArray = affinity_type.split(":")
	if parts.size() != 2:
		return 0
	
	var tag_category: String = parts[0]
	var tag_name: String = parts[1]
	
	if tag_category == "role":
		var target_role := MinionTags.get_role_from_name(tag_name)
		count = MinionTags.count_role_on_board(board, target_role)
	elif tag_category == "biology":
		var target_biology := MinionTags.get_biology_from_name(tag_name)
		count = MinionTags.count_biology_on_board(board, target_biology)
	
	return count


## =============================================================================
## TAG-BASED QUERIES
## =============================================================================

## Get all minions with a specific role on a player's board
func get_minions_with_role(player_id: int, role: MinionTags.Role) -> Array:
	var result: Array = []
	var board: Array = players[player_id]["board"]
	
	for minion in board:
		if is_instance_valid(minion) and minion.role_tag == role:
			result.append(minion)
	
	return result


## Get all minions with a specific biology on a player's board
func get_minions_with_biology(player_id: int, biology: MinionTags.Biology) -> Array:
	var result: Array = []
	var board: Array = players[player_id]["board"]
	
	for minion in board:
		if is_instance_valid(minion) and minion.biology_tag == biology:
			result.append(minion)
	
	return result


## Count minions with role
func count_role(player_id: int, role: MinionTags.Role) -> int:
	return get_minions_with_role(player_id, role).size()


## Count minions with biology
func count_biology(player_id: int, biology: MinionTags.Biology) -> int:
	return get_minions_with_biology(player_id, biology).size()


## Get all minions matching a tag name (works with both role and biology)
func get_minions_with_tag(player_id: int, tag_name: String) -> Array:
	var result: Array = []
	var board: Array = players[player_id]["board"]
	
	# Try as role first
	var role := MinionTags.get_role_from_name(tag_name)
	if role != MinionTags.Role.NONE:
		for minion in board:
			if is_instance_valid(minion) and minion.role_tag == role:
				result.append(minion)
		return result
	
	# Try as biology (note: HUMANOID is the default, not NONE)
	var biology := MinionTags.get_biology_from_name(tag_name)
	# Always check biology since HUMANOID is valid
	for minion in board:
		if is_instance_valid(minion) and minion.biology_tag == biology:
			result.append(minion)
	
	return result


## =============================================================================
## SYNERGY TRIGGERS
## =============================================================================

signal role_synergy_triggered(player_id: int, role: MinionTags.Role, count: int)
signal biology_synergy_triggered(player_id: int, biology: MinionTags.Biology, count: int)

## Check and trigger role synergies when a minion is summoned
func check_role_synergies(player_id: int, summoned_minion: Node) -> void:
	if summoned_minion.role_tag == MinionTags.Role.NONE:
		return
	
	var count := count_role(player_id, summoned_minion.role_tag)
	
	# Emit signal for synergy effects
	role_synergy_triggered.emit(player_id, summoned_minion.role_tag, count)
	
	# Role-specific threshold effects
	match summoned_minion.role_tag:
		MinionTags.Role.COMMANDER:
			if count >= 2:
				print("[GameManager] Commander synergy! %d Commanders on board" % count)
				_trigger_commander_synergy(player_id)
		MinionTags.Role.ZEALOT:
			if count >= 3:
				print("[GameManager] Zealot frenzy! %d Zealots on board" % count)
				_trigger_zealot_frenzy(player_id)


## Check and trigger biology synergies when a minion is summoned
func check_biology_synergies(player_id: int, summoned_minion: Node) -> void:
	# HUMANOID is the default biology - still valid for synergies
	var count := count_biology(player_id, summoned_minion.biology_tag)
	
	# Emit signal for synergy effects
	biology_synergy_triggered.emit(player_id, summoned_minion.biology_tag, count)
	
	# Biology-specific threshold effects
	match summoned_minion.biology_tag:
		MinionTags.Biology.BEAST:
			if count >= 3:
				print("[GameManager] Beast pack formed! %d Beasts on board" % count)
				_trigger_beast_pack(player_id)
		MinionTags.Biology.UNDEAD:
			if count >= 3:
				print("[GameManager] Undead horde! %d Undead on board" % count)
				_trigger_undead_horde(player_id)


## Synergy effect implementations
func _trigger_commander_synergy(player_id: int) -> void:
	# Commanders buff each other
	var commanders := get_minions_with_role(player_id, MinionTags.Role.COMMANDER)
	for commander in commanders:
		if is_instance_valid(commander):
			# Could add a buff here
			pass


func _trigger_zealot_frenzy(player_id: int) -> void:
	# Zealots go into frenzy mode
	var zealots := get_minions_with_role(player_id, MinionTags.Role.ZEALOT)
	for zealot in zealots:
		if is_instance_valid(zealot):
			# Could add a buff here
			pass


func _trigger_beast_pack(player_id: int) -> void:
	# Beast pack bonus
	var beasts := get_minions_with_biology(player_id, MinionTags.Biology.BEAST)
	for beast in beasts:
		if is_instance_valid(beast):
			# Could add a buff here
			pass


func _trigger_undead_horde(player_id: int) -> void:
	# Undead horde bonus
	var undead := get_minions_with_biology(player_id, MinionTags.Biology.UNDEAD)
	for u in undead:
		if is_instance_valid(u):
			# Could add a buff here
			pass


## =============================================================================
## CARD COST CALCULATION
## =============================================================================

## Get effective card cost (with Affinity, modifiers, etc.)
func get_effective_card_cost(card: CardData, player_id: int) -> int:
	var base_cost := card.cost
	
	# Apply Affinity reduction
	var affinity_reduction := get_affinity_reduction(card, player_id)
	base_cost -= affinity_reduction
	
	# Apply modifier system reductions
	if ModifierManager:
		base_cost = ModifierManager.apply_card_cost_modifiers(card, base_cost, player_id)	
	# Minimum cost is 0
	return maxi(0, base_cost)


## =============================================================================
## TURN END CLEANUP
## =============================================================================

func _end_turn_keyword_cleanup(player_id: int) -> void:
	# Remove Echo copies
	remove_echo_copies(player_id)
	
	# Clear Weakened and Stun from all minions
	var board: Array = players[player_id]["board"]
	for minion in board:
		if is_instance_valid(minion):
			if minion.has_method("clear_weakened"):
				minion.clear_weakened()
			if minion.has_method("clear_stun"):
				minion.clear_stun()


func remove_echo_copies(player_id: int) -> void:
	var hand: Array = players[player_id]["hand"]
	var to_remove: Array[CardData] = []
	
	for card in hand:
		if card.has_keyword("echo_copy"):
			to_remove.append(card)
	
	for card in to_remove:
		hand.erase(card)
		print("[GameManager] Echo copy %s removed from hand" % card.card_name)


## =============================================================================
## COMBAT SYSTEM
## =============================================================================

func execute_combat(attacker: Node, defender: Node) -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(defender):
		return
	
	current_phase = GamePhase.COMBAT
	
	# MODIFIER HOOK: Combat start
	if ModifierManager:
		ModifierManager.trigger_combat_start()
	
	var attacker_attack: int = attacker.get_effective_attack()
	var defender_attack: int = defender.get_effective_attack()
	
	# Check for Shielded
	var attacker_shielded: bool = attacker.has_shielded
	var defender_shielded: bool = defender.has_shielded
	
	# Calculate damage
	var damage_to_defender: int = attacker_attack
	var damage_to_attacker: int = defender_attack
	
	# MODIFIER HOOK: Modify damage dealt by attacker
	if ModifierManager:
		damage_to_defender = ModifierManager.apply_damage_dealt_modifiers(
			damage_to_defender, attacker, defender, "combat"
		)
	
	# MODIFIER HOOK: Modify damage taken by defender
	if ModifierManager:
		damage_to_defender = ModifierManager.apply_damage_taken_modifiers(
			damage_to_defender, attacker, defender, "combat"
		)
	
	# MODIFIER HOOK: Modify damage dealt by defender (counter-attack)
	if ModifierManager:
		damage_to_attacker = ModifierManager.apply_damage_dealt_modifiers(
			damage_to_attacker, defender, attacker, "combat"
		)
	
	# MODIFIER HOOK: Modify damage taken by attacker
	if ModifierManager:
		damage_to_attacker = ModifierManager.apply_damage_taken_modifiers(
			damage_to_attacker, defender, attacker, "combat"
		)
	
	# Check Bully bonus
	var bully_active: bool = false
	if attacker.has_bully and attacker_attack > defender_attack:
		bully_active = true
		print("[GameManager] Bully active! %s attacking weaker target" % attacker.card_data.card_name)
		if ModifierManager:
			ModifierManager.trigger_keyword("Bully", attacker, {"defender": defender})
	
	# Apply damage
	defender.take_damage(damage_to_defender)
	attacker.take_damage(damage_to_attacker)
	
	# MODIFIER HOOK: Trigger damage dealt/taken events
	if ModifierManager:
		if damage_to_defender > 0:
			ModifierManager.trigger_damage_dealt(damage_to_defender, attacker, defender)
			ModifierManager.trigger_damage_taken(damage_to_defender, attacker, defender)
		if damage_to_attacker > 0:
			ModifierManager.trigger_damage_dealt(damage_to_attacker, defender, attacker)
			ModifierManager.trigger_damage_taken(damage_to_attacker, defender, attacker)
	
	# MODIFIER HOOK: Minion attack event
	if ModifierManager:
		ModifierManager.trigger_minion_attack(attacker, defender)
	
	# Handle Drain keyword
	if attacker.has_drain and damage_to_defender > 0 and not defender_shielded:
		var drain_amount := damage_to_defender
		if ModifierManager:
			drain_amount = ModifierManager.apply_keyword_value_modifiers("Drain", drain_amount, attacker)
			ModifierManager.trigger_keyword("Drain", attacker, {"amount": drain_amount})
		_heal_hero(attacker.owner_id, drain_amount)
		print("[GameManager] Drain: Healed %d" % drain_amount)
	
	# Handle Lethal keyword
	if attacker.has_lethal and damage_to_defender > 0 and not defender_shielded:
		defender.current_health = 0
		print("[GameManager] Lethal triggered!")
		if ModifierManager:
			ModifierManager.trigger_keyword("Lethal", attacker, {"victim": defender})
	
	if defender.has_lethal and damage_to_attacker > 0 and not attacker_shielded:
		attacker.current_health = 0
		print("[GameManager] Lethal counter-triggered!")
		if ModifierManager:
			ModifierManager.trigger_keyword("Lethal", defender, {"victim": attacker})
	
	# Hidden breaks when attacking
	if attacker.has_hidden:
		attacker.break_hidden()
	
	# Mark attacker as having attacked
	attacker.has_attacked = true
	attacker.attacks_this_turn += 1
	
	# Emit combat data
	var attacker_data := {
		"node": attacker,
		"damage_dealt": damage_to_defender,
		"damage_taken": damage_to_attacker
	}
	var defender_data := {
		"node": defender,
		"damage_dealt": damage_to_attacker,
		"damage_taken": damage_to_defender
	}
	combat_occurred.emit(attacker_data, defender_data)
	
	# MODIFIER HOOK: Combat end
	if ModifierManager:
		ModifierManager.trigger_combat_end()
	
	await get_tree().process_frame
	_check_minion_deaths()
	
	current_phase = GamePhase.PLAY


## Attack the enemy hero
func attack_hero(attacker: Node, target_player_id: int) -> void:
	if not is_instance_valid(attacker):
		return
	
	var attacker_attack: int = attacker.get_effective_attack()
	var player_data: Dictionary = players[target_player_id]
	var damage_dealt := 0
	
	# MODIFIER HOOK: Modify damage dealt to hero
	var modified_damage := attacker_attack
	if ModifierManager:
		modified_damage = ModifierManager.apply_damage_dealt_modifiers(
			modified_damage, attacker, null, "hero_attack"
		)
	
	# Damage armor first
	if player_data["hero_armor"] > 0:
		var armor_damage := mini(modified_damage, player_data["hero_armor"])
		player_data["hero_armor"] -= armor_damage
		modified_damage -= armor_damage
		damage_dealt += armor_damage
	
	if modified_damage > 0:
		player_data["hero_health"] -= modified_damage
		damage_dealt += modified_damage
	
	# Drain when attacking hero
	if attacker.has_drain and damage_dealt > 0:
		var drain_amount := damage_dealt
		if ModifierManager:
			drain_amount = ModifierManager.apply_keyword_value_modifiers("Drain", drain_amount, attacker)
			ModifierManager.trigger_keyword("Drain", attacker, {"amount": drain_amount, "target": "hero"})
		_heal_hero(attacker.owner_id, drain_amount)
		print("[GameManager] Drain: Healed %d from hero attack" % drain_amount)
	
	# Hidden breaks when attacking
	if attacker.has_hidden:
		attacker.break_hidden()
	
	attacker.has_attacked = true
	attacker.attacks_this_turn += 1
	
	# MODIFIER HOOK: Trigger damage events
	if ModifierManager and damage_dealt > 0:
		ModifierManager.trigger_damage_dealt(damage_dealt, attacker, null)
	
	print("[GameManager] Player %d hero took %d damage, now at %d HP" % [
		target_player_id, damage_dealt, player_data["hero_health"]
	])
	
	health_changed.emit(target_player_id, player_data["hero_health"], player_data["hero_max_health"])
	_check_hero_death(target_player_id)


func _heal_hero(player_id: int, amount: int) -> void:
	var player_data: Dictionary = players[player_id]
	var old_health: int = player_data["hero_health"]
	
	# MODIFIER HOOK: Modify healing
	var modified_amount := amount
	if ModifierManager:
		modified_amount = ModifierManager.apply_healing_modifiers(amount, null, null)
	
	player_data["hero_health"] = mini(
		player_data["hero_health"] + modified_amount,
		player_data["hero_max_health"]
	)
	
	if player_data["hero_health"] != old_health:
		health_changed.emit(player_id, player_data["hero_health"], player_data["hero_max_health"])
		
		# MODIFIER HOOK: Healing applied
		if ModifierManager:
			ModifierManager.trigger_healing_applied(modified_amount, null, null)


## =============================================================================
## DEATH CHECKING
## =============================================================================

func _check_minion_deaths() -> void:
	for player_id in range(2):
		var board: Array = players[player_id]["board"]
		var dead_minions: Array = []
		
		for minion in board:
			if is_instance_valid(minion) and minion.current_health <= 0:
				dead_minions.append(minion)
		
		for minion in dead_minions:
			_handle_minion_death(player_id, minion)


func _handle_minion_death(player_id: int, minion: Node) -> void:
	var board_position = players[player_id]["board"].find(minion)
	
	# Handle Persistent keyword
	if minion.has_persistent:
		minion.current_health = 1
		minion.remove_persistent()
		print("[GameManager] Persistent triggered for %s" % minion.card_data.card_name)
		if ModifierManager:
			ModifierManager.trigger_keyword("Persistent", minion, {})
		return
	
	# Remove from board
	remove_minion_from_board(player_id, minion)
	
	# Add to graveyard
	if minion.card_data:
		players[player_id]["graveyard"].append(minion.card_data)
	
	# MODIFIER HOOK: Minion death
	if ModifierManager:
		ModifierManager.trigger_minion_death(minion, player_id, null)
	
	minion_died.emit(player_id, minion, board_position)
	
	# Queue free the minion node
	minion.queue_free()


func _check_hero_death(player_id: int) -> void:
	if players[player_id]["hero_health"] <= 0:
		var winner := PLAYER_TWO if player_id == PLAYER_ONE else PLAYER_ONE
		_end_game(winner)


func _end_game(winner_id: int) -> void:
	current_phase = GamePhase.GAME_OVER
	print("[GameManager] Game Over! Player %d wins!" % winner_id)
	game_ended.emit(winner_id)


## =============================================================================
## UTILITY FUNCTIONS
## =============================================================================

func is_player_turn(player_id: int) -> bool:
	return active_player == player_id and current_phase == GamePhase.PLAY


func get_player_health(player_id: int) -> int:
	return players[player_id]["hero_health"]


func get_hand_size(player_id: int) -> int:
	return players[player_id]["hand"].size()


func get_deck_size(player_id: int) -> int:
	return players[player_id]["deck"].size()


func set_player_deck(player_id: int, deck: Array[CardData]) -> void:
	players[player_id]["deck"] = deck.duplicate()


## =============================================================================
## TARGETING HELPERS (with modifier support)
## =============================================================================

## Get valid targets for an effect, filtered by modifiers
func get_valid_targets(source: Node, available_targets: Array) -> Array:
	if ModifierManager:
		return ModifierManager.filter_targets(source, available_targets)
	return available_targets


## Check if a specific target is valid (with modifier check)
func can_target(source: Node, target: Node) -> bool:
	if ModifierManager:
		return ModifierManager.can_target(source, target)
	return true
