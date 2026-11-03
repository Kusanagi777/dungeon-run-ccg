class_name ModifierRegistry
extends Resource
## Registry of all available modifiers in the game.
## Load this as a resource and use it to grant modifiers to players.

## All registered modifier templates
@export var modifiers: Array[Modifier] = []

## Cached lookup by ID
var _by_id: Dictionary = {}


## Build the lookup cache
func _init() -> void:
	_rebuild_cache()


## Rebuild the ID lookup cache
func _rebuild_cache() -> void:
	_by_id.clear()
	for modifier in modifiers:
		if modifier and not modifier.id.is_empty():
			_by_id[modifier.id] = modifier


## Get a modifier template by ID
func get_modifier(modifier_id: String) -> Modifier:
	if _by_id.is_empty():
		_rebuild_cache()
	return _by_id.get(modifier_id, null)


## Check if a modifier exists
func has_modifier(modifier_id: String) -> bool:
	if _by_id.is_empty():
		_rebuild_cache()
	return _by_id.has(modifier_id)


## Get all modifier IDs
func get_all_ids() -> Array[String]:
	if _by_id.is_empty():
		_rebuild_cache()
	var ids: Array[String] = []
	for id in _by_id.keys():
		ids.append(id)
	return ids


## Get modifiers by tag
func get_by_tag(tag: String) -> Array[Modifier]:
	var result: Array[Modifier] = []
	for modifier in modifiers:
		if modifier and modifier.has_tag(tag):
			result.append(modifier)
	return result


## Grant a modifier to the active ModifierManager
func grant_modifier(modifier_id: String) -> bool:
	var modifier := get_modifier(modifier_id)
	if modifier:
		return ModifierManager.add_modifier(modifier)
	push_error("ModifierRegistry: Unknown modifier ID: %s" % modifier_id)
	return false


## Convert to dictionary for save/load
func to_dictionary() -> Dictionary:
	return _by_id.duplicate()
