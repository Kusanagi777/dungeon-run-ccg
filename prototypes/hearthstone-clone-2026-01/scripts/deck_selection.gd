# res://scripts/deck_selection.gd
# UPDATED: Now selects from pre-built 15-card decks
extends Control

const STARTER_DECKS_PATH := "res://data/starter_decks/"
const DECK_SIZE := 15  # New fixed deck size

## Currently selected deck index
var selected_index: int = -1

## UI References
var deck_buttons: Array[Control] = []
var description_label: RichTextLabel
var deck_contents_label: RichTextLabel
var select_button: Button
var back_button: Button
var title_label: Label
var faction_indicator: Label
var deck_container: Control

## Reference resolution
const REFERENCE_HEIGHT = 720.0

## Available starter decks (filtered by faction)
var deck_options: Array[Dictionary] = []

## Current faction
var current_faction: Dictionary = {}


func _ready() -> void:
	# Get faction from GameManager
	if GameManager.has_meta("selected_faction"):
		current_faction = GameManager.get_meta("selected_faction")
	
	_load_starter_decks()
	_setup_ui()
	_connect_signals()
	_apply_styling()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _load_starter_decks() -> void:
	deck_options.clear()
	var faction_id = current_faction.get("id", "")
	
	# Try to load from starter decks folder
	var dir := DirAccess.open(STARTER_DECKS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		
		while file_name != "":
			if file_name.ends_with(".tres"):
				var path := STARTER_DECKS_PATH + file_name
				var deck_data = load(path)
				
				if deck_data:
					# Check if deck matches current faction OR is neutral
					var deck_faction = ""
					if "faction_id" in deck_data:
						deck_faction = deck_data.faction_id
					elif "class_id" in deck_data:
						# Support legacy class_id field
						deck_faction = deck_data.class_id
					
					# Include if faction matches or deck is neutral
					if deck_faction == faction_id or deck_faction == "" or deck_faction == "neutral":
						var cards_array = []
						if "card_ids" in deck_data:
							cards_array = Array(deck_data.card_ids)
						
						# Only include decks with exactly 15 cards (or close to it)
						if cards_array.size() >= 10 and cards_array.size() <= 20:
							deck_options.append({
								"name": deck_data.deck_name if "deck_name" in deck_data else file_name,
								"description": deck_data.description if "description" in deck_data else "",
								"color": deck_data.theme_color if "theme_color" in deck_data else current_faction.get("color", Color.WHITE),
								"cards": cards_array
							})
							print("[DeckSelection] Loaded deck: %s (%d cards)" % [
								deck_data.deck_name if "deck_name" in deck_data else file_name,
								cards_array.size()
							])
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
	
	# If no decks found for faction, create defaults
	if deck_options.is_empty():
		_create_default_decks()
	
	print("[DeckSelection] Loaded %d decks for faction %s" % [deck_options.size(), faction_id])


func _create_default_decks() -> void:
	var faction_color = current_faction.get("color", Color.GRAY)
	var faction_id = current_faction.get("id", "neutral")
	
	deck_options = [
		{
			"name": "Starter Pack",
			"description": "A balanced 15-card deck to get you started. Contains a mix of minions for all situations.",
			"color": faction_color,
			"cards": _generate_default_cards(faction_id, "balanced")
		},
		{
			"name": "Aggro Rush",
			"description": "Hit fast, hit hard. Low-cost aggressive minions designed to overwhelm quickly.",
			"color": faction_color.lightened(0.1),
			"cards": _generate_default_cards(faction_id, "aggro")
		},
		{
			"name": "Control",
			"description": "Patience is key. Higher cost minions with staying power for the long game.",
			"color": faction_color.darkened(0.1),
			"cards": _generate_default_cards(faction_id, "control")
		}
	]


func _generate_default_cards(faction_id: String, archetype: String) -> Array:
	# Generate placeholder card IDs based on faction and archetype
	# These should be replaced with actual card IDs from your card database
	var cards: Array = []
	
	match archetype:
		"balanced":
			# Mix of costs
			for i in range(5):
				cards.append("%s_common_%02d" % [faction_id, i + 1])
			for i in range(5):
				cards.append("%s_uncommon_%02d" % [faction_id, i + 1])
			for i in range(3):
				cards.append("NEU_%02d" % (i + 1))
			for i in range(2):
				cards.append("%s_rare_%02d" % [faction_id, i + 1])
		"aggro":
			# Mostly low cost
			for i in range(8):
				cards.append("%s_common_%02d" % [faction_id, i + 1])
			for i in range(5):
				cards.append("%s_uncommon_%02d" % [faction_id, i + 1])
			for i in range(2):
				cards.append("NEU_%02d" % (i + 1))
		"control":
			# Higher cost cards
			for i in range(4):
				cards.append("%s_common_%02d" % [faction_id, i + 1])
			for i in range(6):
				cards.append("%s_uncommon_%02d" % [faction_id, i + 1])
			for i in range(3):
				cards.append("%s_rare_%02d" % [faction_id, i + 1])
			for i in range(2):
				cards.append("%s_epic_%02d" % [faction_id, i + 1])
	
	return cards


func _setup_ui() -> void:
	# Main layout
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 15)
	add_child(main_vbox)
	
	# Top spacer
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size.y = 20
	main_vbox.add_child(top_spacer)
	
	# Faction indicator
	faction_indicator = Label.new()
	faction_indicator.text = "%s - %s" % [
		current_faction.get("name", "Unknown"),
		GameManager.get_meta("selected_aspect")["name"] if GameManager.has_meta("selected_aspect") else "No Aspect"
	]
	faction_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	faction_indicator.add_theme_font_size_override("font_size", 18)
	faction_indicator.add_theme_color_override("font_color", current_faction.get("color", Color.WHITE))
	main_vbox.add_child(faction_indicator)
	
	# Title
	title_label = Label.new()
	title_label.text = "Choose Your Deck (15 Cards)"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	main_vbox.add_child(title_label)
	
	# Content area (decks on left, preview on right)
	var content_hbox = HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 30)
	main_vbox.add_child(content_hbox)
	
	# Left spacer
	var left_spacer = Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(left_spacer)
	
	# Deck buttons container
	deck_container = VBoxContainer.new()
	deck_container.add_theme_constant_override("separation", 15)
	content_hbox.add_child(deck_container)
	
	# Create deck buttons
	_create_deck_buttons()
	
	# Right panel - Description & Preview
	var right_panel = VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(350, 0)
	right_panel.add_theme_constant_override("separation", 10)
	content_hbox.add_child(right_panel)
	
	# Description panel
	var desc_panel = PanelContainer.new()
	desc_panel.custom_minimum_size = Vector2(350, 100)
	right_panel.add_child(desc_panel)
	
	description_label = RichTextLabel.new()
	description_label.bbcode_enabled = true
	description_label.fit_content = true
	description_label.scroll_active = false
	description_label.text = "[center]Select a deck to see details[/center]"
	desc_panel.add_child(description_label)
	
	# Deck contents preview
	var contents_panel = PanelContainer.new()
	contents_panel.custom_minimum_size = Vector2(350, 200)
	contents_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(contents_panel)
	
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	contents_panel.add_child(scroll)
	
	deck_contents_label = RichTextLabel.new()
	deck_contents_label.bbcode_enabled = true
	deck_contents_label.fit_content = true
	deck_contents_label.text = "[center][color=gray]Deck contents will appear here[/color][/center]"
	scroll.add_child(deck_contents_label)
	
	# Right spacer
	var right_spacer = Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(right_spacer)
	
	# Button row
	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 20)
	main_vbox.add_child(button_row)
	
	back_button = Button.new()
	back_button.text = "← Back"
	back_button.custom_minimum_size = Vector2(120, 40)
	button_row.add_child(back_button)
	
	select_button = Button.new()
	select_button.text = "Select Deck →"
	select_button.custom_minimum_size = Vector2(150, 40)
	select_button.disabled = true
	button_row.add_child(select_button)
	
	# Bottom spacer
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size.y = 20
	main_vbox.add_child(bottom_spacer)


func _create_deck_buttons() -> void:
	deck_buttons.clear()
	
	for i in range(deck_options.size()):
		var deck = deck_options[i]
		var btn = _create_deck_button(i, deck)
		deck_container.add_child(btn)
		deck_buttons.append(btn)


func _create_deck_button(index: int, deck: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 70)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	panel.add_child(hbox)
	
	# Color indicator
	var color_rect = ColorRect.new()
	color_rect.custom_minimum_size = Vector2(8, 0)
	color_rect.color = deck.get("color", Color.GRAY)
	hbox.add_child(color_rect)
	
	# Text info
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = deck["name"]
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)
	
	var card_count = Label.new()
	card_count.text = "%d cards" % deck["cards"].size()
	card_count.add_theme_font_size_override("font_size", 14)
	card_count.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	vbox.add_child(card_count)
	
	# Make interactive
	panel.gui_input.connect(_on_deck_gui_input.bind(index))
	panel.mouse_entered.connect(_on_deck_hover.bind(index, panel))
	panel.mouse_exited.connect(_on_deck_exit.bind(panel))
	
	panel.set_meta("index", index)
	
	return panel


func _connect_signals() -> void:
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if select_button:
		select_button.pressed.connect(_on_select_pressed)


func _on_deck_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_select_deck(index)


func _select_deck(index: int) -> void:
	selected_index = index
	var deck = deck_options[index]
	
	# Update description
	description_label.text = "[center]%s[/center]" % deck["description"]
	
	# Update deck contents preview
	_update_deck_contents_preview(deck["cards"])
	
	# Update visual selection
	for i in range(deck_buttons.size()):
		_style_deck_button(deck_buttons[i], i == index)
	
	# Enable select button
	select_button.disabled = false


func _update_deck_contents_preview(card_ids: Array) -> void:
	# Count duplicates
	var card_counts: Dictionary = {}
	for card_id in card_ids:
		if card_counts.has(card_id):
			card_counts[card_id] += 1
		else:
			card_counts[card_id] = 1
	
	# Build preview text
	var text = "[center][b]Deck Contents (%d cards)[/b][/center]\n\n" % card_ids.size()
	
	# Sort by card name/id
	var sorted_ids = card_counts.keys()
	sorted_ids.sort()
	
	for card_id in sorted_ids:
		var count = card_counts[card_id]
		var display_name = _get_card_display_name(card_id)
		
		if count > 1:
			text += "• %s x%d\n" % [display_name, count]
		else:
			text += "• %s\n" % display_name
	
	deck_contents_label.text = text


func _get_card_display_name(card_id: String) -> String:
	# Try to load the card and get its actual name
	var card_path = "res://data/cards/%s.tres" % card_id
	if ResourceLoader.exists(card_path):
		var card = load(card_path)
		if card and "card_name" in card:
			return card.card_name
	
	# Fallback: format the ID nicely
	return card_id.replace("_", " ").capitalize()


func _on_deck_hover(index: int, panel: Control) -> void:
	if selected_index != index:
		panel.modulate = Color(1.1, 1.1, 1.1)
	
	# Show hover description
	if selected_index == -1:
		var deck = deck_options[index]
		description_label.text = "[center]%s[/center]" % deck["description"]


func _on_deck_exit(panel: Control) -> void:
	var index = panel.get_meta("index")
	if selected_index != index:
		panel.modulate = Color.WHITE
	
	# Restore description
	if selected_index == -1:
		description_label.text = "[center]Select a deck to see details[/center]"


func _style_deck_button(panel: Control, selected: bool) -> void:
	var style = StyleBoxFlat.new()
	var faction_color = current_faction.get("color", Color(0.4, 0.4, 0.5))
	
	if selected:
		style.bg_color = faction_color.darkened(0.65)
		style.border_color = faction_color
		style.set_border_width_all(3)
		panel.modulate = Color(1.1, 1.1, 1.1)
	else:
		style.bg_color = Color(0.12, 0.14, 0.2)
		style.border_color = Color(0.3, 0.32, 0.38)
		style.set_border_width_all(2)
		panel.modulate = Color.WHITE
	
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/aspect_selection.tscn")


func _on_select_pressed() -> void:
	if selected_index < 0 or selected_index >= deck_options.size():
		return
	
	var selected_deck = deck_options[selected_index]
	
	# Store deck in GameManager
	GameManager.set_meta("selected_deck", {
		"name": selected_deck["name"],
		"cards": selected_deck["cards"].duplicate()
	})
	
	print("[DeckSelection] Selected deck: %s with %d cards" % [
		selected_deck["name"], 
		selected_deck["cards"].size()
	])
	
	# Go to schedule builder
	get_tree().change_scene_to_file("res://scenes/schedule_builder.tscn")


func _apply_styling() -> void:
	# Style deck buttons
	for btn in deck_buttons:
		_style_deck_button(btn, false)
	
	# Style buttons
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.25, 0.35)
	btn_style.border_color = Color(0.5, 0.45, 0.3)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(10)
	
	back_button.add_theme_stylebox_override("normal", btn_style)
	select_button.add_theme_stylebox_override("normal", btn_style)
	
	var disabled_style = btn_style.duplicate()
	disabled_style.bg_color = Color(0.15, 0.15, 0.18)
	disabled_style.border_color = Color(0.3, 0.3, 0.3)
	select_button.add_theme_stylebox_override("disabled", disabled_style)


func get_scale_factor() -> float:
	var viewport_size = DisplayServer.window_get_size()
	return clampf(viewport_size.y / REFERENCE_HEIGHT, 1.0, 3.0)


func _on_viewport_size_changed() -> void:
	var s = get_scale_factor()
	if title_label:
		title_label.add_theme_font_size_override("font_size", int(36 * s))


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
		elif event.keycode == KEY_ENTER and not select_button.disabled:
			_on_select_pressed()
