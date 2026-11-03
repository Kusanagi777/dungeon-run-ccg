# res://scripts/deck_builder.gd
extends Control

## Path to card resources
const CARDS_PATH := "res://data/cards/"

## Card UI scene for tooltips
var card_ui_scene: PackedScene = preload("res://scenes/card_ui.tscn")

## Reference resolution for scaling
const REFERENCE_HEIGHT := 720.0

## Grid settings
const CARDS_PER_ROW := 4
const CARD_SCALE := 0.7

## Max copies of a card allowed in deck
const MAX_COPIES := 2

## All available card resources (for lookup)
var _all_cards: Dictionary = {}

## Unique cards list (no duplicates from ID/name mapping)
var _unique_cards: Array[CardData] = []

## Current deck being displayed (card IDs)
var current_deck: Array = []

## UI References - Header
var title_label: Label
var deck_count_label: Label
var back_button: Button
var class_label: Label

## UI References - Deck Panel (Left)
var deck_panel: PanelContainer
var deck_grid: GridContainer
var deck_scroll: ScrollContainer

## UI References - Collection Panel (Right)
var collection_panel: PanelContainer
var collection_list: VBoxContainer
var collection_scroll: ScrollContainer
var collection_title: Label

## Tooltip card preview
var tooltip_popup: PanelContainer
var tooltip_card_instance: Control

## Selected class info
var selected_class: Dictionary = {}

## Drag and drop state
var _is_dragging: bool = false
var _drag_preview: Control = null
var _drag_card_data: CardData = null
var _drag_source: String = ""  # "deck" or "collection"
var _drag_offset: Vector2 = Vector2.ZERO

## Drop zone highlighting
var _deck_drop_highlight: ColorRect = null
var _collection_drop_highlight: ColorRect = null


func _ready() -> void:
	# Get selected class and deck from GameManager
	if GameManager.has_meta("selected_class"):
		selected_class = GameManager.get_meta("selected_class")
	
	if GameManager.has_meta("selected_deck"):
		var deck_data: Dictionary = GameManager.get_meta("selected_deck")
		if deck_data.has("cards"):
			current_deck = deck_data["cards"]
	
	_load_all_cards()
	_setup_ui()
	_setup_tooltip()
	_setup_drag_preview()
	_populate_deck_grid()
	_populate_collection_list()
	_apply_styling()
	
	# Connect viewport resize
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _load_all_cards() -> void:
	var seen_ids: Dictionary = {}
	var dir := DirAccess.open(CARDS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var card_path := CARDS_PATH + file_name
				var card_data := load(card_path) as CardData
				if card_data:
					var card_id := card_data.id if not card_data.id.is_empty() else card_data.card_name.to_lower()
					
					# Store in lookup dictionary
					_all_cards[card_id] = card_data
					
					# Add to unique list if not seen
					if not seen_ids.has(card_id):
						seen_ids[card_id] = true
						_unique_cards.append(card_data)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Sort unique cards by cost then name
	_unique_cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		if a.cost != b.cost:
			return a.cost < b.cost
		return a.card_name < b.card_name
	)
	
	print("[DeckBuilder] Loaded %d unique cards" % _unique_cards.size())


func _setup_ui() -> void:
	# Main layout
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 15)
	add_child(main_vbox)
	
	# === HEADER SECTION ===
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header)
	
	# Back button
	back_button = Button.new()
	back_button.text = "← Back"
	back_button.custom_minimum_size = Vector2(100, 40)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)
	
	# Title
	title_label = Label.new()
	title_label.text = "Deck Builder"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	header.add_child(title_label)
	
	# Deck count
	deck_count_label = Label.new()
	deck_count_label.text = "0 cards"
	deck_count_label.custom_minimum_size = Vector2(100, 0)
	deck_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	deck_count_label.add_theme_font_size_override("font_size", 18)
	deck_count_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	header.add_child(deck_count_label)
	
	# Class info
	class_label = Label.new()
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_label.add_theme_font_size_override("font_size", 14)
	if selected_class.has("color"):
		class_label.add_theme_color_override("font_color", selected_class["color"])
	else:
		class_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	class_label.text = "Playing as: %s" % selected_class.get("name", "Unknown")
	main_vbox.add_child(class_label)
	
	# Drag hint
	var hint_label := Label.new()
	hint_label.text = "💡 Drag cards between panels to add/remove from deck"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	main_vbox.add_child(hint_label)
	
	# === CONTENT SECTION (Two columns) ===
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(content_hbox)
	
	# === LEFT PANEL: Current Deck ===
	_setup_deck_panel(content_hbox)
	
	# === RIGHT PANEL: Collection ===
	_setup_collection_panel(content_hbox)


func _setup_deck_panel(parent: Control) -> void:
	deck_panel = PanelContainer.new()
	deck_panel.name = "DeckPanel"
	deck_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_panel.size_flags_stretch_ratio = 2.0  # Takes 2/3 of space
	parent.add_child(deck_panel)
	
	# Drop highlight overlay (initially hidden)
	_deck_drop_highlight = ColorRect.new()
	_deck_drop_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deck_drop_highlight.color = Color(0.2, 0.8, 0.3, 0.15)
	_deck_drop_highlight.visible = false
	_deck_drop_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_drop_highlight.z_index = 10
	deck_panel.add_child(_deck_drop_highlight)
	
	var deck_vbox := VBoxContainer.new()
	deck_vbox.add_theme_constant_override("separation", 10)
	deck_panel.add_child(deck_vbox)
	
	# Deck panel title
	var deck_title := Label.new()
	deck_title.text = "Current Deck"
	deck_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_title.add_theme_font_size_override("font_size", 18)
	deck_title.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	deck_vbox.add_child(deck_title)
	
	# Separator
	var sep := HSeparator.new()
	deck_vbox.add_child(sep)
	
	# Scroll container for deck grid
	deck_scroll = ScrollContainer.new()
	deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	deck_vbox.add_child(deck_scroll)
	
	# Center the grid
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_scroll.add_child(center)
	
	# Grid for cards
	deck_grid = GridContainer.new()
	deck_grid.columns = CARDS_PER_ROW
	deck_grid.add_theme_constant_override("h_separation", 12)
	deck_grid.add_theme_constant_override("v_separation", 12)
	center.add_child(deck_grid)


func _setup_collection_panel(parent: Control) -> void:
	collection_panel = PanelContainer.new()
	collection_panel.name = "CollectionPanel"
	collection_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_panel.size_flags_stretch_ratio = 1.0  # Takes 1/3 of space
	collection_panel.custom_minimum_size.x = 250
	parent.add_child(collection_panel)
	
	# Drop highlight overlay (initially hidden) - RED tint for removal
	_collection_drop_highlight = ColorRect.new()
	_collection_drop_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_collection_drop_highlight.color = Color(0.8, 0.3, 0.2, 0.15)
	_collection_drop_highlight.visible = false
	_collection_drop_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_collection_drop_highlight.z_index = 10
	collection_panel.add_child(_collection_drop_highlight)
	
	var coll_vbox := VBoxContainer.new()
	coll_vbox.add_theme_constant_override("separation", 10)
	collection_panel.add_child(coll_vbox)
	
	# Collection panel title
	collection_title = Label.new()
	collection_title.text = "Collection"
	collection_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	collection_title.add_theme_font_size_override("font_size", 18)
	collection_title.add_theme_color_override("font_color", Color(0.6, 0.8, 0.7))
	coll_vbox.add_child(collection_title)
	
	# Separator
	var sep := HSeparator.new()
	coll_vbox.add_child(sep)
	
	# Scroll container for collection list
	collection_scroll = ScrollContainer.new()
	collection_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	collection_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coll_vbox.add_child(collection_scroll)
	
	# VBox for card entries
	collection_list = VBoxContainer.new()
	collection_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_list.add_theme_constant_override("separation", 4)
	collection_scroll.add_child(collection_list)


func _setup_tooltip() -> void:
	# Create tooltip popup (card preview on hover)
	tooltip_popup = PanelContainer.new()
	tooltip_popup.visible = false
	tooltip_popup.z_index = 100
	tooltip_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tooltip_popup)
	
	# Style the tooltip panel
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.1, 0.12, 0.18, 0.95)
	tooltip_style.border_color = Color(0.5, 0.45, 0.3)
	tooltip_style.set_border_width_all(2)
	tooltip_style.set_corner_radius_all(8)
	tooltip_style.set_content_margin_all(8)
	tooltip_popup.add_theme_stylebox_override("panel", tooltip_style)


func _setup_drag_preview() -> void:
	# Create the drag preview container (hidden by default)
	_drag_preview = PanelContainer.new()
	_drag_preview.visible = false
	_drag_preview.z_index = 200
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_preview.modulate = Color(1, 1, 1, 0.85)
	add_child(_drag_preview)
	
	# Style the drag preview
	var drag_style := StyleBoxFlat.new()
	drag_style.bg_color = Color(0.15, 0.18, 0.25, 0.95)
	drag_style.border_color = Color(0.8, 0.7, 0.4)
	drag_style.set_border_width_all(3)
	drag_style.set_corner_radius_all(8)
	drag_style.set_content_margin_all(5)
	_drag_preview.add_theme_stylebox_override("panel", drag_style)


func _populate_deck_grid() -> void:
	# Clear existing cards
	for child in deck_grid.get_children():
		child.queue_free()
	
	# Update deck count
	deck_count_label.text = "%d cards" % current_deck.size()
	
	# Show empty message if no deck
	if current_deck.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No cards in deck\nDrag cards here to add"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 16)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		deck_grid.add_child(empty_label)
		return
	
	# Count card occurrences
	var card_counts: Dictionary = {}
	for card_id in current_deck:
		var lookup_id: String = str(card_id).to_lower()
		if card_counts.has(lookup_id):
			card_counts[lookup_id] += 1
		else:
			card_counts[lookup_id] = 1
	
	# Sort cards by mana cost
	var sorted_ids: Array = card_counts.keys()
	sorted_ids.sort_custom(_sort_by_mana_cost)
	
	# Create card displays
	for card_id in sorted_ids:
		var card_data: CardData = _all_cards.get(card_id)
		if not card_data:
			push_warning("[DeckBuilder] Card not found: %s" % card_id)
			continue
		
		var card_container := _create_deck_card_display(card_data, card_counts[card_id])
		deck_grid.add_child(card_container)


func _populate_collection_list() -> void:
	# Clear existing entries
	for child in collection_list.get_children():
		child.queue_free()
	
	# Count cards in deck
	var deck_counts: Dictionary = {}
	for card_id in current_deck:
		var lookup_id: String = str(card_id).to_lower()
		if deck_counts.has(lookup_id):
			deck_counts[lookup_id] += 1
		else:
			deck_counts[lookup_id] = 1
	
	# Create entries for all cards
	var has_available := false
	for card_data in _unique_cards:
		var card_id := card_data.id if not card_data.id.is_empty() else card_data.card_name.to_lower()
		var in_deck: int = deck_counts.get(card_id, 0)
		
		# Show all cards - cards at max copies are shown dimmed
		var card_entry := _create_collection_entry(card_data, in_deck)
		collection_list.add_child(card_entry)
		has_available = true
	
	if not has_available:
		var empty_label := Label.new()
		empty_label.text = "No cards available"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_font_size_override("font_size", 14)
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		collection_list.add_child(empty_label)


func _sort_by_mana_cost(a: String, b: String) -> bool:
	var card_a: CardData = _all_cards.get(a)
	var card_b: CardData = _all_cards.get(b)
	
	if not card_a or not card_b:
		return a < b
	
	if card_a.cost != card_b.cost:
		return card_a.cost < card_b.cost
	
	return card_a.card_name < card_b.card_name


func _create_deck_card_display(card_data: CardData, count: int) -> Control:
	# Use a PanelContainer as the wrapper - it auto-sizes to content
	var wrapper := PanelContainer.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let overlay handle clicks
	
	# Make the panel invisible
	var transparent_style := StyleBoxEmpty.new()
	wrapper.add_theme_stylebox_override("panel", transparent_style)
	
	# Store card data for dragging
	wrapper.set_meta("card_data", card_data)
	wrapper.set_meta("source", "deck")
	
	# Inner container for layout
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(container)
	
	# Card UI instance
	if card_ui_scene:
		var card_instance = card_ui_scene.instantiate()
		container.add_child(card_instance)
		
		card_instance.initialize(card_data, 0)
		card_instance.set_interactable(false)
		card_instance.scale = Vector2(CARD_SCALE, CARD_SCALE)
		card_instance.custom_minimum_size = Vector2(120, 170) * CARD_SCALE
		card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_children_mouse_filter(card_instance, Control.MOUSE_FILTER_IGNORE)
	
	# Count label
	var count_label := Label.new()
	count_label.text = "×%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 13)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if count >= 2:
		count_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	else:
		count_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	
	container.add_child(count_label)
	
	# Drag hint for deck cards
	var drag_hint := Label.new()
	drag_hint.text = "⟵ drag to remove"
	drag_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_hint.add_theme_font_size_override("font_size", 10)
	drag_hint.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4, 0.7))
	drag_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(drag_hint)
	
	# INVISIBLE CLICK OVERLAY - sits on top and catches all mouse events
	var click_overlay := ColorRect.new()
	click_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	click_overlay.color = Color(0, 0, 0, 0)  # Fully transparent
	click_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	click_overlay.z_index = 50  # Above everything in this container
	wrapper.add_child(click_overlay)
	
	# Connect signals to the overlay (catches all clicks)
	click_overlay.gui_input.connect(_on_deck_card_gui_input.bind(wrapper, card_data))
	click_overlay.mouse_entered.connect(_on_deck_card_hover.bind(wrapper))
	click_overlay.mouse_exited.connect(_on_deck_card_exit.bind(wrapper))
	
	return wrapper


## Recursive helper to set mouse filter on all children
func _set_children_mouse_filter(node: Control, filter: Control.MouseFilter) -> void:
	for child in node.get_children():
		if child is Control:
			child.mouse_filter = filter
			_set_children_mouse_filter(child, filter)


func _on_deck_card_hover(container: Control) -> void:
	if _is_dragging:
		return
	# Slight highlight effect
	container.modulate = Color(1.1, 1.1, 1.1)


func _on_deck_card_exit(container: Control) -> void:
	container.modulate = Color(1, 1, 1)


func _create_collection_entry(card_data: CardData, copies_in_deck: int) -> Control:
	var entry := PanelContainer.new()
	entry.custom_minimum_size = Vector2(0, 36)
	entry.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Store card data for tooltip and dragging
	entry.set_meta("card_data", card_data)
	entry.set_meta("copies_in_deck", copies_in_deck)
	entry.set_meta("source", "collection")
	
	# Connect hover signals
	entry.mouse_entered.connect(_on_collection_entry_hover.bind(entry, card_data))
	entry.mouse_exited.connect(_on_collection_entry_exit)
	
	# Connect drag signals
	entry.gui_input.connect(_on_collection_entry_gui_input.bind(entry, card_data, copies_in_deck))
	
	# Style based on copies in deck
	var is_maxed := copies_in_deck >= MAX_COPIES
	var style := StyleBoxFlat.new()
	if is_maxed:
		style.bg_color = Color(0.12, 0.12, 0.15)
		style.border_color = Color(0.25, 0.25, 0.3)
	else:
		style.bg_color = Color(0.15, 0.18, 0.25)
		style.border_color = Color(0.4, 0.35, 0.25)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	entry.add_theme_stylebox_override("panel", style)
	
	# Content HBox
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(hbox)
	
	# Mana cost gem
	var mana_container := PanelContainer.new()
	mana_container.custom_minimum_size = Vector2(28, 28)
	mana_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mana_style := StyleBoxFlat.new()
	mana_style.bg_color = Color(0.1, 0.3, 0.6)
	mana_style.set_corner_radius_all(14)
	mana_container.add_theme_stylebox_override("panel", mana_style)
	hbox.add_child(mana_container)
	
	var mana_label := Label.new()
	mana_label.text = str(card_data.cost)
	mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mana_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mana_label.add_theme_font_size_override("font_size", 14)
	mana_label.add_theme_color_override("font_color", Color.WHITE)
	mana_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mana_container.add_child(mana_label)
	
	# Card name
	var name_label := Label.new()
	name_label.text = card_data.card_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_maxed:
		name_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	else:
		name_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	name_label.clip_text = true
	hbox.add_child(name_label)
	
	# Copies indicator
	if copies_in_deck > 0:
		var copies_label := Label.new()
		copies_label.text = "(%d)" % copies_in_deck
		copies_label.add_theme_font_size_override("font_size", 12)
		copies_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.4))
		copies_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(copies_label)
	
	# Drag indicator
	var drag_hint := Label.new()
	drag_hint.text = "⋮⋮"
	drag_hint.add_theme_font_size_override("font_size", 14)
	drag_hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	drag_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(drag_hint)
	
	return entry


# ============= DRAG AND DROP LOGIC =============

func _on_deck_card_gui_input(event: InputEvent, container: Control, card_data: CardData) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging from deck
				_start_drag(card_data, "deck", container.get_global_rect().position)
			elif _is_dragging:
				_end_drag()


func _on_collection_entry_gui_input(event: InputEvent, entry: Control, card_data: CardData, copies_in_deck: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Only allow dragging if not maxed
				if copies_in_deck < MAX_COPIES:
					_start_drag(card_data, "collection", entry.get_global_rect().position)
				else:
					# Visual feedback that card is maxed
					_flash_entry(entry, Color(0.8, 0.3, 0.2, 0.5))
			elif _is_dragging:
				_end_drag()


func _flash_entry(entry: Control, flash_color: Color) -> void:
	var original_modulate := entry.modulate
	var tween := create_tween()
	tween.tween_property(entry, "modulate", flash_color, 0.1)
	tween.tween_property(entry, "modulate", original_modulate, 0.2)


func _start_drag(card_data: CardData, source: String, start_pos: Vector2) -> void:
	_is_dragging = true
	_drag_card_data = card_data
	_drag_source = source
	
	# Hide tooltip while dragging
	tooltip_popup.visible = false
	
	# Clear and populate drag preview
	for child in _drag_preview.get_children():
		child.queue_free()
	
	# Create a simple card preview for dragging
	var drag_content := VBoxContainer.new()
	drag_content.add_theme_constant_override("separation", 4)
	_drag_preview.add_child(drag_content)
	
	# Mana cost
	var mana_hbox := HBoxContainer.new()
	mana_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	drag_content.add_child(mana_hbox)
	
	var mana_gem := Label.new()
	mana_gem.text = "🔷 %d" % card_data.cost
	mana_gem.add_theme_font_size_override("font_size", 14)
	mana_gem.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	mana_hbox.add_child(mana_gem)
	
	# Card name
	var name_label := Label.new()
	name_label.text = card_data.card_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_content.add_child(name_label)
	
	# Action hint
	var action_label := Label.new()
	if source == "collection":
		action_label.text = "→ Add to deck"
		action_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	else:
		action_label.text = "← Remove from deck"
		action_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.4))
	action_label.add_theme_font_size_override("font_size", 12)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_content.add_child(action_label)
	
	_drag_preview.visible = true
	_drag_preview.global_position = get_global_mouse_position() - Vector2(60, 30)
	
	# Show appropriate drop highlight
	_update_drop_highlights()


func _update_drop_highlights() -> void:
	if not _is_dragging:
		_deck_drop_highlight.visible = false
		_collection_drop_highlight.visible = false
		return
	
	if _drag_source == "collection":
		# Dragging from collection, highlight deck as drop target
		_deck_drop_highlight.visible = true
		_collection_drop_highlight.visible = false
	else:
		# Dragging from deck, highlight collection as drop target (remove)
		_deck_drop_highlight.visible = false
		_collection_drop_highlight.visible = true


func _end_drag() -> void:
	if not _is_dragging:
		return
	
	_is_dragging = false
	_drag_preview.visible = false
	
	# Hide drop highlights
	_deck_drop_highlight.visible = false
	_collection_drop_highlight.visible = false
	
	# Check where we dropped
	var mouse_pos := get_global_mouse_position()
	var deck_rect := deck_panel.get_global_rect()
	var collection_rect := collection_panel.get_global_rect()
	
	if _drag_source == "collection" and deck_rect.has_point(mouse_pos):
		# Add card to deck
		_add_card_to_deck(_drag_card_data)
	elif _drag_source == "deck" and collection_rect.has_point(mouse_pos):
		# Remove card from deck
		_remove_card_from_deck(_drag_card_data)
		print("[DeckBuilder] Dropped card on collection - removing from deck")
	elif _drag_source == "deck":
		# Dropped outside valid zone - just cancel (card stays in deck)
		print("[DeckBuilder] Drag cancelled - card stays in deck")
	
	_drag_card_data = null
	_drag_source = ""


func _add_card_to_deck(card_data: CardData) -> void:
	var card_id := card_data.id if not card_data.id.is_empty() else card_data.card_name.to_lower()
	
	# Count current copies
	var current_copies := 0
	for id in current_deck:
		if str(id).to_lower() == card_id:
			current_copies += 1
	
	# Check if we can add more
	if current_copies >= MAX_COPIES:
		print("[DeckBuilder] Already have max copies of %s" % card_data.card_name)
		return
	
	# Add to deck
	current_deck.append(card_id)
	print("[DeckBuilder] Added %s to deck (%d cards)" % [card_data.card_name, current_deck.size()])
	
	# Save to GameManager
	_save_deck()
	
	# Refresh displays
	_populate_deck_grid()
	_populate_collection_list()


func _remove_card_from_deck(card_data: CardData) -> void:
	var card_id := card_data.id if not card_data.id.is_empty() else card_data.card_name.to_lower()
	
	# Find and remove one instance
	for i in range(current_deck.size() - 1, -1, -1):
		if str(current_deck[i]).to_lower() == card_id:
			current_deck.remove_at(i)
			print("[DeckBuilder] Removed %s from deck (%d cards)" % [card_data.card_name, current_deck.size()])
			break
	
	# Save to GameManager
	_save_deck()
	
	# Refresh displays
	_populate_deck_grid()
	_populate_collection_list()


func _save_deck() -> void:
	var deck_data: Dictionary = {}
	if GameManager.has_meta("selected_deck"):
		deck_data = GameManager.get_meta("selected_deck")
	deck_data["cards"] = current_deck
	GameManager.set_meta("selected_deck", deck_data)


func _process(_delta: float) -> void:
	# Update drag preview position
	if _is_dragging and _drag_preview.visible:
		_drag_preview.global_position = get_global_mouse_position() - Vector2(60, 30)


func _input(event: InputEvent) -> void:
	# Handle drag release anywhere
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _is_dragging:
				_end_drag()
	
	# Keyboard shortcuts
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_B:
			if _is_dragging:
				# Cancel drag
				_is_dragging = false
				_drag_preview.visible = false
				_deck_drop_highlight.visible = false
				_collection_drop_highlight.visible = false
				_drag_card_data = null
				_drag_source = ""
			else:
				_on_back_pressed()


# ============= TOOLTIP LOGIC =============

func _on_collection_entry_hover(entry: Control, card_data: CardData) -> void:
	# Don't show tooltip while dragging
	if _is_dragging:
		return
	
	# Remove old tooltip card if exists
	if tooltip_card_instance and is_instance_valid(tooltip_card_instance):
		tooltip_card_instance.queue_free()
		tooltip_card_instance = null
	
	# Create new card preview
	if card_ui_scene:
		tooltip_card_instance = card_ui_scene.instantiate()
		tooltip_popup.add_child(tooltip_card_instance)
		tooltip_card_instance.initialize(card_data, 0)
		tooltip_card_instance.set_interactable(false)
	
	# Position tooltip to the left of the collection panel
	var entry_rect := entry.get_global_rect()
	var tooltip_size := Vector2(130, 185)  # Approximate card size
	
	# Position to the left of the entry
	var tooltip_x := entry_rect.position.x - tooltip_size.x - 20
	var tooltip_y := entry_rect.position.y - (tooltip_size.y - entry_rect.size.y) / 2
	
	# Clamp to screen bounds
	var viewport_size := get_viewport_rect().size
	tooltip_y = clamp(tooltip_y, 10, viewport_size.y - tooltip_size.y - 10)
	if tooltip_x < 10:
		tooltip_x = entry_rect.end.x + 10  # Flip to right side
	
	tooltip_popup.global_position = Vector2(tooltip_x, tooltip_y)
	tooltip_popup.visible = true


func _on_collection_entry_exit() -> void:
	tooltip_popup.visible = false


func _on_back_pressed() -> void:
	# Return to previous screen
	if GameManager.has_meta("deck_builder_return_scene"):
		var return_scene: String = GameManager.get_meta("deck_builder_return_scene")
		get_tree().change_scene_to_file(return_scene)
	else:
		# Default to hero power selection
		get_tree().change_scene_to_file("res://scenes/hero_power_selection.tscn")


func _on_viewport_size_changed() -> void:
	# Update scale based on viewport
	var viewport_height := get_viewport_rect().size.y
	var scale_factor := viewport_height / REFERENCE_HEIGHT
	# Could adjust UI elements here if needed


func _apply_styling() -> void:
	# Style the deck panel
	var deck_style := StyleBoxFlat.new()
	deck_style.bg_color = Color(0.12, 0.14, 0.2)
	deck_style.border_color = Color(0.35, 0.3, 0.22)
	deck_style.set_border_width_all(2)
	deck_style.set_corner_radius_all(8)
	deck_style.set_content_margin_all(15)
	deck_panel.add_theme_stylebox_override("panel", deck_style)
	
	# Style the collection panel
	var coll_style := StyleBoxFlat.new()
	coll_style.bg_color = Color(0.1, 0.13, 0.18)
	coll_style.border_color = Color(0.25, 0.35, 0.3)
	coll_style.set_border_width_all(2)
	coll_style.set_corner_radius_all(8)
	coll_style.set_content_margin_all(15)
	collection_panel.add_theme_stylebox_override("panel", coll_style)
	
	# Style the back button
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.22, 0.28)
	btn_style.border_color = Color(0.4, 0.35, 0.25)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	back_button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover := btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.28, 0.35)
	back_button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed := btn_style.duplicate()
	btn_pressed.bg_color = Color(0.15, 0.18, 0.22)
	back_button.add_theme_stylebox_override("pressed", btn_pressed)
