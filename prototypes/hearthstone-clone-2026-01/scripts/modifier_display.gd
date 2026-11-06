class_name ModifierDisplay
extends Control
## UI component that displays active modifiers.
## Add this to your game UI to show the player their active buffs.

## Container for modifier icons
@export var icon_container: HBoxContainer

## Prefab for individual modifier display
@export var modifier_icon_scene: PackedScene

## Tooltip label (optional)
@export var tooltip_label: Label

## Dictionary mapping modifier IDs to their display nodes
var _displayed_modifiers: Dictionary = {}


func _ready() -> void:
	# Connect to ModifierManager signals
	ModifierManager.modifier_added.connect(_on_modifier_added)
	ModifierManager.modifier_removed.connect(_on_modifier_removed)
	ModifierManager.modifier_stacks_changed.connect(_on_stacks_changed)
	ModifierManager.modifiers_cleared.connect(_on_modifiers_cleared)
	
	# Initial population
	_refresh_all()


func _refresh_all() -> void:
	# Clear existing
	for child in icon_container.get_children():
		child.queue_free()
	_displayed_modifiers.clear()
	
	# Add all active modifiers
	for modifier in ModifierManager.get_all_modifiers():
		_create_modifier_icon(modifier)


func _create_modifier_icon(modifier: Modifier) -> void:
	var icon_node: Control
	
	if modifier_icon_scene:
		icon_node = modifier_icon_scene.instantiate()
	else:
		# Default simple display
		icon_node = _create_default_icon(modifier)
	
	icon_node.set_meta("modifier_id", modifier.id)
	
	# Update display
	_update_icon(icon_node, modifier)
	
	# Connect hover for tooltip
	icon_node.mouse_entered.connect(_on_icon_hover.bind(modifier))
	icon_node.mouse_exited.connect(_on_icon_unhover)
	
	icon_container.add_child(icon_node)
	_displayed_modifiers[modifier.id] = icon_node


func _create_default_icon(modifier: Modifier) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(48, 48)
	
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	
	# Icon or name abbreviation
	if modifier.icon:
		var tex_rect := TextureRect.new()
		tex_rect.texture = modifier.icon
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(tex_rect)
	else:
		var name_label := Label.new()
		name_label.text = modifier.display_name.substr(0, 2).to_upper()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_label)
	
	# Stack count
	var stack_label := Label.new()
	stack_label.name = "StackLabel"
	stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(stack_label)
	
	return panel


func _update_icon(icon_node: Control, modifier: Modifier) -> void:
	# Update stack count display
	var stack_label := icon_node.find_child("StackLabel", true, false) as Label
	if stack_label:
		if modifier.stacks > 1:
			stack_label.text = "x%d" % modifier.stacks
			stack_label.visible = true
		else:
			stack_label.visible = false
	
	# Update duration indicator if present
	var duration_label := icon_node.find_child("DurationLabel", true, false) as Label
	if duration_label and modifier.duration_turns > 0:
		duration_label.text = "%d" % modifier._turns_remaining
		duration_label.visible = true


func _on_modifier_added(modifier: Modifier) -> void:
	if not _displayed_modifiers.has(modifier.id):
		_create_modifier_icon(modifier)


func _on_modifier_removed(modifier: Modifier) -> void:
	if _displayed_modifiers.has(modifier.id):
		var node: Control = _displayed_modifiers[modifier.id]
		node.queue_free()
		_displayed_modifiers.erase(modifier.id)


func _on_stacks_changed(modifier: Modifier, old_stacks: int, new_stacks: int) -> void:
	if _displayed_modifiers.has(modifier.id):
		var node: Control = _displayed_modifiers[modifier.id]
		_update_icon(node, modifier)


func _on_modifiers_cleared() -> void:
	for node in _displayed_modifiers.values():
		node.queue_free()
	_displayed_modifiers.clear()


func _on_icon_hover(modifier: Modifier) -> void:
	if tooltip_label:
		tooltip_label.text = "%s\n%s" % [modifier.display_name, modifier.get_scaled_description()]
		tooltip_label.visible = true


func _on_icon_unhover() -> void:
	if tooltip_label:
		tooltip_label.visible = false
