# res://data/card_effect_base.gd
class_name CardEffectBase
extends RefCounted
## Base class for card effects. Extend this to create custom card effects.
## Effects are triggered when cards are played and can interact with the modifier system.

## Reference to game manager for accessing game state
var game_manager: Node

## The player who owns/played this card
var owner_id: int

## The card data
var card_data: CardData


## =============================================================================
## MAIN EFFECT EXECUTION
## =============================================================================

## Called when the card is played (for all card types)
func on_play(gm: Node, player_id: int, data: CardData, target: Variant) -> void:
	game_manager = gm
	owner_id = player_id
	card_data = data
	_execute_play_effect(target)


## Override in subclasses to implement the card's main effect
func _execute_play_effect(_target: Variant) -> void:
	pass


## Override in subclasses for battlecry effects
func _execute_battlecry(_target: Variant) -> void:
	pass


## Override in subclasses for deathrattle effects
func _execute_deathrattle(_board_position: int) -> void:
	pass


## =============================================================================
## DAMAGE HELPERS (WITH MODIFIER SUPPORT)
## =============================================================================

## Deal damage to a target (minion or hero)
func deal_damage(target: Variant, amount: int, damage_type: String = "spell") -> int:
	var actual_damage := amount
	
	if target is Node and target.has_method("take_damage"):
		# Target is a minion
		# MODIFIER HOOK: Modify damage dealt
		if ModifierManager:
			actual_damage = ModifierManager.apply_damage_dealt_modifiers(
				actual_damage, null, target, damage_type
			)
			actual_damage = ModifierManager.apply_damage_taken_modifiers(
				actual_damage, null, target, damage_type
			)
		
		target.take_damage(actual_damage)
		
		# MODIFIER HOOK: Trigger damage events
		if ModifierManager and actual_damage > 0:
			ModifierManager.trigger_damage_dealt(actual_damage, null, target)
			ModifierManager.trigger_damage_taken(actual_damage, null, target)
		
	elif target is int:
		# Target is a player ID (hero damage)
		var player_data: Dictionary = game_manager.players[target]
		
		# MODIFIER HOOK: Modify damage to hero
		if ModifierManager:
			actual_damage = ModifierManager.apply_damage_dealt_modifiers(
				actual_damage, null, null, damage_type
			)
		
		# Damage armor first
		if player_data["hero_armor"] > 0:
			var armor_damage := mini(actual_damage, player_data["hero_armor"])
			player_data["hero_armor"] -= armor_damage
			actual_damage -= armor_damage
		
		if actual_damage > 0:
			player_data["hero_health"] -= actual_damage
			game_manager.health_changed.emit(
				target, 
				player_data["hero_health"], 
				player_data["hero_max_health"]
			)
		
		# MODIFIER HOOK: Trigger damage event
		if ModifierManager and actual_damage > 0:
			ModifierManager.trigger_damage_dealt(actual_damage, null, null)
	
	return actual_damage


## Deal damage to all enemy minions
func deal_damage_to_all_enemies(amount: int) -> void:
	var enemy_id := get_enemy_id()
	var enemy_board := get_board(enemy_id).duplicate()  # Duplicate to avoid modification during iteration
	
	for minion in enemy_board:
		if is_instance_valid(minion):
			deal_damage(minion, amount, "aoe")


## Deal damage to all minions (both sides)
func deal_damage_to_all_minions(amount: int) -> void:
	var all_minions := get_all_minions().duplicate()
	
	for minion in all_minions:
		if is_instance_valid(minion):
			deal_damage(minion, amount, "aoe")


## Deal damage to a random enemy minion
func deal_damage_to_random_enemy(amount: int) -> Node:
	var enemy_id := get_enemy_id()
	var enemy_board := get_board(enemy_id)
	
	if enemy_board.is_empty():
		return null
	
	var valid_targets := enemy_board.filter(func(m): return is_instance_valid(m))
	if valid_targets.is_empty():
		return null
	
	var target: Node = valid_targets.pick_random()
	deal_damage(target, amount, "random")
	return target


## =============================================================================
## HEALING HELPERS (WITH MODIFIER SUPPORT)
## =============================================================================

## Heal a target (minion or hero)
func heal_target(target: Variant, amount: int) -> int:
	var actual_heal := amount
	
	# MODIFIER HOOK: Modify healing
	if ModifierManager:
		actual_heal = ModifierManager.apply_healing_modifiers(amount, null, target if target is Node else null)
	
	if target is Node and target.has_method("heal"):
		var old_health: int = target.current_health
		target.heal(actual_heal)
		actual_heal = target.current_health - old_health
		
	elif target is int:
		# Hero healing
		var player_data: Dictionary = game_manager.players[target]
		var old_health: int = player_data["hero_health"]
		player_data["hero_health"] = mini(
			player_data["hero_health"] + actual_heal,
			player_data["hero_max_health"]
		)
		actual_heal = player_data["hero_health"] - old_health
		
		if actual_heal > 0:
			game_manager.health_changed.emit(
				target,
				player_data["hero_health"],
				player_data["hero_max_health"]
			)
	
	# MODIFIER HOOK: Trigger healing event
	if ModifierManager and actual_heal > 0:
		ModifierManager.trigger_healing_applied(actual_heal, null, target if target is Node else null)
	
	return actual_heal


## Heal all friendly minions
func heal_all_friendly_minions(amount: int) -> void:
	var board := get_board(owner_id)
	for minion in board:
		if is_instance_valid(minion):
			heal_target(minion, amount)


## Heal the owner's hero
func heal_owner_hero(amount: int) -> int:
	return heal_target(owner_id, amount)


## =============================================================================
## BUFF/DEBUFF HELPERS
## =============================================================================

## Buff a minion's stats
func buff_minion(m: Node, attack_bonus: int, health_bonus: int) -> void:
	if m.has_method("buff_stats"):
		m.buff_stats(attack_bonus, health_bonus)


## Buff all friendly minions
func buff_all_friendly_minions(attack_bonus: int, health_bonus: int) -> void:
	var board := get_board(owner_id)
	for minion in board:
		if is_instance_valid(minion):
			buff_minion(minion, attack_bonus, health_bonus)


## Buff a random friendly minion
func buff_random_friendly_minion(attack_bonus: int, health_bonus: int) -> Node:
	var board := get_board(owner_id)
	var valid := board.filter(func(m): return is_instance_valid(m))
	
	if valid.is_empty():
		return null
	
	var target: Node = valid.pick_random()
	buff_minion(target, attack_bonus, health_bonus)
	return target


## Give a keyword to a minion
func give_keyword(m: Node, keyword: String) -> void:
	match keyword.to_lower():
		"charge":
			m.has_charge = true
			m.just_played = false
		"taunt":
			m.has_taunt = true
		"shielded":
			m.has_shielded = true
		"aggressive":
			m.has_aggressive = true
		"drain":
			m.has_drain = true
		"lethal":
			m.has_lethal = true
		"hidden":
			m.has_hidden = true
		"rush":
			m.has_rush = true
		"snipe":
			m.has_snipe = true
	
	# Also add to card data for persistence
	if m.card_data:
		m.card_data.add_keyword(keyword)


## =============================================================================
## CARD DRAW HELPERS
## =============================================================================

## Draw cards for a player
func draw_cards(player_id: int, count: int) -> void:
	for i in range(count):
		game_manager._draw_card(player_id)


## Draw cards for the owner
func draw_cards_for_owner(count: int) -> void:
	draw_cards(owner_id, count)


## =============================================================================
## BOARD ACCESS HELPERS
## =============================================================================

## Get all minions on a player's board
func get_board(player_id: int) -> Array:
	return game_manager.players[player_id]["board"]


## Get all minions (both boards)
func get_all_minions() -> Array:
	return get_board(0) + get_board(1)


## Get enemy player ID
func get_enemy_id() -> int:
	return 1 - owner_id


## Get owner's hand
func get_hand() -> Array:
	return game_manager.players[owner_id]["hand"]


## Get owner's deck size
func get_deck_size() -> int:
	return game_manager.players[owner_id]["deck"].size()


## =============================================================================
## SUMMONING HELPERS
## =============================================================================

## Summon a minion (emits signal for PlayerController to handle)
func summon_minion(player_id: int, card_to_summon: CardData) -> void:
	# This would need access to the player controller
	# For now, emit a signal that can be handled
	print("[Effect] Would summon: %s for player %d" % [card_to_summon.card_name, player_id])
	# TODO: Implement proper summoning through signal or direct controller access


## =============================================================================
## TARGETING HELPERS (WITH MODIFIER SUPPORT)
## =============================================================================

## Get valid targets for this effect, filtered by modifiers
func get_valid_targets(available_targets: Array) -> Array:
	if ModifierManager:
		return ModifierManager.filter_targets(null, available_targets)
	return available_targets


## Check if a specific target can be targeted
func can_target(target: Node) -> bool:
	# Check hidden
	if target.has_method("has_hidden") and target.has_hidden:
		if target.owner_id != owner_id:
			return false
	
	# MODIFIER HOOK: Check modifier restrictions
	if ModifierManager:
		return ModifierManager.can_target(null, target)
	
	return true


## Get all valid enemy targets
func get_valid_enemy_targets() -> Array:
	var enemies := get_board(get_enemy_id())
	return get_valid_targets(enemies.filter(func(m): 
		return is_instance_valid(m) and can_target(m)
	))


## Get all valid friendly targets
func get_valid_friendly_targets() -> Array:
	var friendlies := get_board(owner_id)
	return get_valid_targets(friendlies.filter(func(m):
		return is_instance_valid(m)
	))


## =============================================================================
## CLASS RESOURCE HELPERS
## =============================================================================

## Add class resource to a player
func add_class_resource(player_id: int, amount: int) -> void:
	game_manager.add_class_resource(player_id, amount)


## Spend class resource (returns true if successful)
func spend_class_resource(player_id: int, amount: int) -> bool:
	return game_manager.spend_class_resource(player_id, amount)


## Get current class resource
func get_class_resource(player_id: int) -> int:
	return game_manager.get_class_resource(player_id)


## =============================================================================
## KEYWORD TRIGGER HELPERS
## =============================================================================

## Trigger a keyword event through the modifier system
func trigger_keyword(keyword: String, source: Node, context: Dictionary = {}) -> void:
	if ModifierManager:
		ModifierManager.trigger_keyword(keyword, source, context)


## Get modified keyword value
func get_keyword_value(keyword: String, base_value: int, source: Node) -> int:
	if ModifierManager:
		return ModifierManager.apply_keyword_value_modifiers(keyword, base_value, source)
	return base_value


## =============================================================================
## UTILITY
## =============================================================================

## Check if a node is still valid
func is_valid(node: Node) -> bool:
	return node != null and is_instance_valid(node)


## Get a random element from an array
func pick_random(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr.pick_random()
