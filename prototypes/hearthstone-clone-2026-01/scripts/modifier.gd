class_name Modifier
extends Resource
## Base class for all game modifiers. Extend this to create new modifiers.
## Modifiers hook into game events and can modify values or trigger effects.

## Unique identifier for this modifier
@export var id: String = ""

## Display name shown to player
@export var display_name: String = ""

## Description of what this modifier does
@export_multiline var description: String = ""

## Icon for UI display
@export var icon: Texture2D

## Whether this modifier is currently active
@export var is_enabled: bool = true

## Priority for execution order (higher = runs first)
@export var priority: int = 0

## Stack count for stackable modifiers (1 = no stacking)
@export var stacks: int = 1

## Maximum stacks allowed (0 = unlimited)
@export var max_stacks: int = 0

## Tags for categorization and filtering
@export var tags: Array[String] = []

## Duration in turns (0 = permanent)
@export var duration_turns: int = 0

## Internal turn counter
var _turns_remaining: int = 0


#region Lifecycle Methods

## Called when modifier is first added to the manager
func on_added() -> void:
	_turns_remaining = duration_turns


## Called when modifier is removed from the manager
func on_removed() -> void:
	pass


## Called when a new stack is added
func on_stack_added(new_total: int) -> void:
	pass


## Called when a stack is removed
func on_stack_removed(new_total: int) -> void:
	pass

#endregion


#region Turn Hooks

## Called at the start of a player's turn
func on_turn_start(player_index: int) -> void:
	pass


## Called at the end of a player's turn
func on_turn_end(player_index: int) -> void:
	# Handle duration countdown
	if duration_turns > 0:
		_turns_remaining -= 1
		if _turns_remaining <= 0:
			ModifierManager.remove_modifier(id)


## Called at the start of combat phase
func on_combat_start() -> void:
	pass


## Called at the end of combat phase
func on_combat_end() -> void:
	pass

#endregion


#region Damage Modification Hooks

## Modify damage before it's dealt. Return the modified amount.
func modify_damage_dealt(amount: int, source: Node, target: Node, damage_type: String = "normal") -> int:
	return amount


## Modify damage before it's received. Return the modified amount.
func modify_damage_taken(amount: int, source: Node, target: Node, damage_type: String = "normal") -> int:
	return amount


## Called after damage is dealt (for triggers, not modification)
func on_damage_dealt(amount: int, source: Node, target: Node) -> void:
	pass


## Called after damage is received
func on_damage_taken(amount: int, source: Node, target: Node) -> void:
	pass

#endregion


#region Healing Hooks

## Modify healing before it's applied. Return the modified amount.
func modify_healing(amount: int, source: Node, target: Node) -> int:
	return amount


## Called after healing is applied
func on_healing_applied(amount: int, source: Node, target: Node) -> void:
	pass

#endregion


#region Card Hooks

## Modify a card's mana cost. Return the modified cost.
func modify_card_cost(card_data: Resource, base_cost: int, player_index: int) -> int:
	return base_cost


## Modify a card's attack value
func modify_card_attack(card_data: Resource, base_attack: int) -> int:
	return base_attack


## Modify a card's health value
func modify_card_health(card_data: Resource, base_health: int) -> int:
	return base_health


## Called when a card is drawn
func on_card_drawn(card_data: Resource, player_index: int) -> void:
	pass


## Called when a card is played (before effects resolve)
func on_card_played(card_data: Resource, player_index: int, target: Variant) -> void:
	pass


## Called after a card's effects have resolved
func on_card_resolved(card_data: Resource, player_index: int) -> void:
	pass


## Called when a card is discarded
func on_card_discarded(card_data: Resource, player_index: int) -> void:
	pass


## Check if a card can be played. Return false to prevent.
func can_play_card(card_data: Resource, player_index: int) -> bool:
	return true

#endregion


#region Minion Hooks

## Called when a minion is summoned
func on_minion_summoned(minion: Node, player_index: int, lane: int, row: int) -> void:
	pass


## Called when a minion dies
func on_minion_death(minion: Node, player_index: int, killer: Node) -> void:
	pass


## Called when a minion attacks
func on_minion_attack(attacker: Node, defender: Node) -> void:
	pass


## Modify a minion's attack stat on the board
func modify_minion_attack(minion: Node, base_attack: int) -> int:
	return base_attack


## Modify a minion's health stat on the board
func modify_minion_health(minion: Node, base_health: int) -> int:
	return base_health


## Check if a minion can attack. Return false to prevent.
func can_minion_attack(minion: Node, target: Node) -> bool:
	return true

#endregion


#region Hero Power Hooks

## Modify hero power cost. Return the modified cost.
func modify_hero_power_cost(hero_power: Resource, base_cost: int, player_index: int) -> int:
	return base_cost


## Called when a hero power is used
func on_hero_power_used(hero_power: Resource, player_index: int, target: Variant) -> void:
	pass


## Check if hero power can be used. Return false to prevent.
func can_use_hero_power(hero_power: Resource, player_index: int) -> bool:
	return true

#endregion


#region Resource Hooks

## Modify mana gained at turn start
func modify_mana_gain(amount: int, player_index: int) -> int:
	return amount


## Modify class resource gained
func modify_class_resource_gain(resource_type: String, amount: int, player_index: int) -> int:
	return amount


## Modify class resource spent
func modify_class_resource_cost(resource_type: String, amount: int, player_index: int) -> int:
	return amount

#endregion


#region Targeting Hooks

## Check if a target is valid. Return false to prevent targeting.
func can_target(source: Node, target: Node) -> bool:
	return true


## Modify available targets (return filtered array)
func filter_targets(source: Node, available_targets: Array) -> Array:
	return available_targets

#endregion


#region Keyword Hooks

## Called when a keyword triggers (e.g., Drain heals, Taunt blocks)
func on_keyword_triggered(keyword: String, source: Node, context: Dictionary) -> void:
	pass


## Modify keyword effectiveness (e.g., double Drain healing)
func modify_keyword_value(keyword: String, base_value: int, source: Node) -> int:
	return base_value

#endregion


#region Schedule Hooks (for weekly schedule system)

## Modify the effect of a schedule activity
func modify_schedule_effect(activity_type: String, effect_value: int) -> int:
	return effect_value


## Called when a schedule day completes
func on_schedule_day_complete(day: int, activity: String) -> void:
	pass

#endregion


#region Utility Methods

## Check if this modifier has a specific tag
func has_tag(tag: String) -> bool:
	return tag in tags


## Get a description with current stack count
func get_scaled_description() -> String:
	return description.replace("{stacks}", str(stacks))


## Create a duplicate with fresh state
func create_instance() -> Modifier:
	var instance: Modifier = duplicate(true)
	instance.on_added()
	return instance

#endregion
