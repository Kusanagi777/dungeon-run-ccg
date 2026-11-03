extends Node
## Singleton manager for all game modifiers.
## Add this as an AutoLoad in Project Settings.
## Other systems call into this to apply modifier effects.

## Emitted when a modifier is added
signal modifier_added(modifier: Modifier)

## Emitted when a modifier is removed
signal modifier_removed(modifier: Modifier)

## Emitted when a modifier's stack count changes
signal modifier_stacks_changed(modifier: Modifier, old_stacks: int, new_stacks: int)

## Emitted when all modifiers are cleared
signal modifiers_cleared()


## Dictionary of active modifiers by ID
var _modifiers: Dictionary = {}

## Cached sorted list for priority execution
var _sorted_modifiers: Array[Modifier] = []

## Flag to indicate cache needs refresh
var _cache_dirty: bool = false


#region Modifier Management

## Add a modifier to the manager
func add_modifier(modifier: Modifier) -> bool:
	if modifier == null or modifier.id.is_empty():
		push_error("ModifierManager: Cannot add null modifier or modifier without ID")
		return false
	
	# Check if modifier already exists
	if _modifiers.has(modifier.id):
		var existing: Modifier = _modifiers[modifier.id]
		
		# Handle stacking
		if existing.max_stacks == 0 or existing.stacks < existing.max_stacks:
			var old_stacks := existing.stacks
			existing.stacks += modifier.stacks
			
			if existing.max_stacks > 0:
				existing.stacks = mini(existing.stacks, existing.max_stacks)
			
			existing.on_stack_added(existing.stacks)
			modifier_stacks_changed.emit(existing, old_stacks, existing.stacks)
			print("ModifierManager: Stacked '%s' to %d stacks" % [modifier.id, existing.stacks])
			return true
		else:
			print("ModifierManager: '%s' at max stacks (%d)" % [modifier.id, existing.max_stacks])
			return false
	
	# Add new modifier
	var instance := modifier.create_instance()
	_modifiers[instance.id] = instance
	_cache_dirty = true
	
	instance.on_added()
	modifier_added.emit(instance)
	print("ModifierManager: Added modifier '%s'" % instance.id)
	return true


## Remove a modifier by ID
func remove_modifier(modifier_id: String) -> bool:
	if not _modifiers.has(modifier_id):
		return false
	
	var modifier: Modifier = _modifiers[modifier_id]
	modifier.on_removed()
	_modifiers.erase(modifier_id)
	_cache_dirty = true
	
	modifier_removed.emit(modifier)
	print("ModifierManager: Removed modifier '%s'" % modifier_id)
	return true


## Remove one stack from a modifier
func remove_stack(modifier_id: String, count: int = 1) -> bool:
	if not _modifiers.has(modifier_id):
		return false
	
	var modifier: Modifier = _modifiers[modifier_id]
	var old_stacks := modifier.stacks
	modifier.stacks = maxi(0, modifier.stacks - count)
	
	if modifier.stacks <= 0:
		return remove_modifier(modifier_id)
	
	modifier.on_stack_removed(modifier.stacks)
	modifier_stacks_changed.emit(modifier, old_stacks, modifier.stacks)
	return true


## Get a modifier by ID
func get_modifier(modifier_id: String) -> Modifier:
	return _modifiers.get(modifier_id, null)


## Check if a modifier is active
func has_modifier(modifier_id: String) -> bool:
	return _modifiers.has(modifier_id)


## Get all active modifiers
func get_all_modifiers() -> Array[Modifier]:
	_refresh_cache_if_needed()
	return _sorted_modifiers.duplicate()


## Get modifiers with a specific tag
func get_modifiers_by_tag(tag: String) -> Array[Modifier]:
	var result: Array[Modifier] = []
	for modifier in _modifiers.values():
		if modifier.has_tag(tag):
			result.append(modifier)
	return result


## Clear all modifiers
func clear_all_modifiers() -> void:
	for modifier in _modifiers.values():
		modifier.on_removed()
	_modifiers.clear()
	_sorted_modifiers.clear()
	_cache_dirty = false
	modifiers_cleared.emit()
	print("ModifierManager: Cleared all modifiers")


## Refresh the sorted cache
func _refresh_cache_if_needed() -> void:
	if not _cache_dirty:
		return
	
	_sorted_modifiers.clear()
	for modifier in _modifiers.values():
		_sorted_modifiers.append(modifier)
	
	# Sort by priority (higher first)
	_sorted_modifiers.sort_custom(func(a, b): return a.priority > b.priority)
	_cache_dirty = false

#endregion


#region Hook Execution Helpers

## Execute hooks that return void (for triggers/events)
func _execute_void_hooks(method: String, args: Array) -> void:
	_refresh_cache_if_needed()
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		if modifier.has_method(method):
			modifier.callv(method, args)


## Execute hooks that modify an int value (chained)
func _execute_int_hooks(method: String, base_value: int, args: Array) -> int:
	_refresh_cache_if_needed()
	var result := base_value
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		if modifier.has_method(method):
			var full_args := [result] + args
			result = modifier.callv(method, full_args)
	return result


## Execute hooks that return bool (AND logic - all must return true)
func _execute_bool_hooks_and(method: String, args: Array) -> bool:
	_refresh_cache_if_needed()
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		if modifier.has_method(method):
			if not modifier.callv(method, args):
				return false
	return true

#endregion


#region Turn Hooks

func trigger_turn_start(player_index: int) -> void:
	_execute_void_hooks("on_turn_start", [player_index])


func trigger_turn_end(player_index: int) -> void:
	_execute_void_hooks("on_turn_end", [player_index])


func trigger_combat_start() -> void:
	_execute_void_hooks("on_combat_start", [])


func trigger_combat_end() -> void:
	_execute_void_hooks("on_combat_end", [])

#endregion


#region Damage Hooks

func apply_damage_dealt_modifiers(amount: int, source: Node, target: Node, damage_type: String = "normal") -> int:
	_refresh_cache_if_needed()
	var result := amount
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_damage_dealt(result, source, target, damage_type)
	return result


func apply_damage_taken_modifiers(amount: int, source: Node, target: Node, damage_type: String = "normal") -> int:
	_refresh_cache_if_needed()
	var result := amount
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_damage_taken(result, source, target, damage_type)
	return result


func trigger_damage_dealt(amount: int, source: Node, target: Node) -> void:
	_execute_void_hooks("on_damage_dealt", [amount, source, target])


func trigger_damage_taken(amount: int, source: Node, target: Node) -> void:
	_execute_void_hooks("on_damage_taken", [amount, source, target])

#endregion


#region Healing Hooks

func apply_healing_modifiers(amount: int, source: Node, target: Node) -> int:
	_refresh_cache_if_needed()
	var result := amount
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_healing(result, source, target)
	return result


func trigger_healing_applied(amount: int, source: Node, target: Node) -> void:
	_execute_void_hooks("on_healing_applied", [amount, source, target])

#endregion


#region Card Hooks

func apply_card_cost_modifiers(card_data: Resource, base_cost: int, player_index: int) -> int:
	_refresh_cache_if_needed()
	var result := base_cost
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_card_cost(card_data, result, player_index)
	return maxi(0, result)  # Costs can't go negative


func apply_card_attack_modifiers(card_data: Resource, base_attack: int) -> int:
	_refresh_cache_if_needed()
	var result := base_attack
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_card_attack(card_data, result)
	return maxi(0, result)


func apply_card_health_modifiers(card_data: Resource, base_health: int) -> int:
	_refresh_cache_if_needed()
	var result := base_health
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_card_health(card_data, result)
	return maxi(1, result)  # Health minimum 1


func trigger_card_drawn(card_data: Resource, player_index: int) -> void:
	_execute_void_hooks("on_card_drawn", [card_data, player_index])


func trigger_card_played(card_data: Resource, player_index: int, target: Variant) -> void:
	_execute_void_hooks("on_card_played", [card_data, player_index, target])


func trigger_card_resolved(card_data: Resource, player_index: int) -> void:
	_execute_void_hooks("on_card_resolved", [card_data, player_index])


func trigger_card_discarded(card_data: Resource, player_index: int) -> void:
	_execute_void_hooks("on_card_discarded", [card_data, player_index])


func can_play_card(card_data: Resource, player_index: int) -> bool:
	return _execute_bool_hooks_and("can_play_card", [card_data, player_index])

#endregion


#region Minion Hooks

func apply_minion_attack_modifiers(minion: Node, base_attack: int) -> int:
	_refresh_cache_if_needed()
	var result := base_attack
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_minion_attack(minion, result)
	return maxi(0, result)


func apply_minion_health_modifiers(minion: Node, base_health: int) -> int:
	_refresh_cache_if_needed()
	var result := base_health
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_minion_health(minion, result)
	return maxi(1, result)


func trigger_minion_summoned(minion: Node, player_index: int, lane: int, row: int) -> void:
	_execute_void_hooks("on_minion_summoned", [minion, player_index, lane, row])


func trigger_minion_death(minion: Node, player_index: int, killer: Node) -> void:
	_execute_void_hooks("on_minion_death", [minion, player_index, killer])


func trigger_minion_attack(attacker: Node, defender: Node) -> void:
	_execute_void_hooks("on_minion_attack", [attacker, defender])


func can_minion_attack(minion: Node, target: Node) -> bool:
	return _execute_bool_hooks_and("can_minion_attack", [minion, target])

#endregion


#region Hero Power Hooks

func apply_hero_power_cost_modifiers(hero_power: Resource, base_cost: int, player_index: int) -> int:
	_refresh_cache_if_needed()
	var result := base_cost
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_hero_power_cost(hero_power, result, player_index)
	return maxi(0, result)


func trigger_hero_power_used(hero_power: Resource, player_index: int, target: Variant) -> void:
	_execute_void_hooks("on_hero_power_used", [hero_power, player_index, target])


func can_use_hero_power(hero_power: Resource, player_index: int) -> bool:
	return _execute_bool_hooks_and("can_use_hero_power", [hero_power, player_index])

#endregion


#region Resource Hooks

func apply_mana_gain_modifiers(amount: int, player_index: int) -> int:
	_refresh_cache_if_needed()
	var result := amount
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_mana_gain(result, player_index)
	return maxi(0, result)


func apply_class_resource_gain_modifiers(resource_type: String, amount: int, player_index: int) -> int:
	_refresh_cache_if_needed()
	var result := amount
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_class_resource_gain(resource_type, result, player_index)
	return result


func apply_class_resource_cost_modifiers(resource_type: String, amount: int, player_index: int) -> int:
	_refresh_cache_if_needed()
	var result := amount
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_class_resource_cost(resource_type, result, player_index)
	return maxi(0, result)

#endregion


#region Targeting Hooks

func can_target(source: Node, target: Node) -> bool:
	return _execute_bool_hooks_and("can_target", [source, target])


func filter_targets(source: Node, available_targets: Array) -> Array:
	_refresh_cache_if_needed()
	var result := available_targets.duplicate()
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.filter_targets(source, result)
	return result

#endregion


#region Keyword Hooks

func trigger_keyword(keyword: String, source: Node, context: Dictionary) -> void:
	_execute_void_hooks("on_keyword_triggered", [keyword, source, context])


func apply_keyword_value_modifiers(keyword: String, base_value: int, source: Node) -> int:
	_refresh_cache_if_needed()
	var result := base_value
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_keyword_value(keyword, result, source)
	return result

#endregion


#region Schedule Hooks

func apply_schedule_effect_modifiers(activity_type: String, effect_value: int) -> int:
	_refresh_cache_if_needed()
	var result := effect_value
	for modifier in _sorted_modifiers:
		if not modifier.is_enabled:
			continue
		result = modifier.modify_schedule_effect(activity_type, result)
	return result


func trigger_schedule_day_complete(day: int, activity: String) -> void:
	_execute_void_hooks("on_schedule_day_complete", [day, activity])

#endregion


#region Save/Load

func get_save_data() -> Dictionary:
	var data := {}
	for id in _modifiers:
		var mod: Modifier = _modifiers[id]
		data[id] = {
			"stacks": mod.stacks,
			"turns_remaining": mod._turns_remaining,
			"is_enabled": mod.is_enabled
		}
	return data


func load_save_data(data: Dictionary, modifier_registry: Dictionary) -> void:
	clear_all_modifiers()
	
	for id in data:
		if modifier_registry.has(id):
			var base_modifier: Modifier = modifier_registry[id]
			var instance := base_modifier.create_instance()
			
			var save_info: Dictionary = data[id]
			instance.stacks = save_info.get("stacks", 1)
			instance._turns_remaining = save_info.get("turns_remaining", 0)
			instance.is_enabled = save_info.get("is_enabled", true)
			
			_modifiers[id] = instance
			_cache_dirty = true
			modifier_added.emit(instance)
		else:
			push_warning("ModifierManager: Unknown modifier ID in save data: %s" % id)

#endregion


#region Debug

func print_active_modifiers() -> void:
	print("=== Active Modifiers ===")
	if _modifiers.is_empty():
		print("  (none)")
		return
	
	_refresh_cache_if_needed()
	for modifier in _sorted_modifiers:
		var status := "ENABLED" if modifier.is_enabled else "DISABLED"
		var stacks_str := " x%d" % modifier.stacks if modifier.stacks > 1 else ""
		var duration_str := " (%d turns left)" % modifier._turns_remaining if modifier.duration_turns > 0 else ""
		print("  [%d] %s%s - %s%s" % [modifier.priority, modifier.display_name, stacks_str, status, duration_str])

#endregion
