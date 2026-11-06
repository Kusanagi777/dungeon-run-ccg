# res://scripts/shop_screen.gd
extends Control

## Shop screen where players can buy cards and upgrades
## Accessed during the weekly schedule

const REFERENCE_HEIGHT: float = 720.0

## Shop inventory categories
enum ShopTab { CARDS, UPGRADES, PACKS }

## Current player gold (loaded from GameManager)
var player_gold: int = 0

## Currently selected tab
var current_tab: ShopTab = ShopTab.CARDS

## Shop items - cards available for purchase
var card_shop_items: Array[Dictionary] = []

## Shop items - upgrades available for purchase  
var upgrade_shop_items: Array[Dictionary] = [
	{
		"id": "max_hand_size",
		"name": "Bigger Hands",
		"description": "Increase max hand size by 1",
		"cost": 200,
		"icon": "✋",
		"type": "upgrade"
	},
	{
		"id": "starting_mana",
		"name": "Mana Crystal",
		"description": "Start battles with +1 mana",
		"cost": 300,
		"icon": "💎",
		"type": "upgrade"
	},
	{
		"id": "card_draw",
		"name": "Card Draw",
		"description": "Draw +1 card at start of battle",
		"cost": 250,
		"icon": "🃏",
		"type": "upgrade"
	}
]

## Pack items
var pack_shop_items: Array[Dictionary] = [
	{
		"id": "basic_pack",
		"name": "Basic Pack",
		"description": "Contains 3 random cards",
		"cost": 100,
		"icon": "📦",
		"type": "pack"
	},
	{
		"id": "rare_pack",
		"name": "Rare Pack",
		"description": "Contains 3 cards (1 guaranteed rare)",
		"cost": 200,
		"icon": "🎁",
		"type": "pack"
	}
]

## UI References
var title_label: Label
var gold_label: Label
var tab_container: HBoxContainer
var items_container: GridContainer
var description_label: RichTextLabel
var back_button: Button
var buy_button: Button

## Currently selected item
var selected_item: Dictionary = {}
var selected_item_panel: PanelContainer = null


func _ready() -> void:
	# Load player gold
	if GameManager.has_meta("player_gold"):
		player_gold = GameManager.get_meta("player_gold")
	else:
		player_gold = 200
		GameManager.set_meta("player_gold", player_gold)
	
	# Load cards from the database
	_load_card_database()
	
	_setup_ui()
	_apply_styling()
	_populate_items()
	
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	print("[ShopScreen] Opened with %d gold" % player_gold)

func _process(_delta: float) -> void:
	# Keep gold display in sync with GameManager
	var current_gold: int = GameManager.get_meta("player_gold") if GameManager.has_meta("player_gold") else 0
	if current_gold != player_gold:
		player_gold = current_gold
		gold_label.text = str(player_gold)
		
		# Update buy button state if an item is selected
		if selected_item_panel and not selected_item.is_empty():
			var display_cost: int = selected_item_panel.get_meta("display_cost")
			buy_button.disabled = (player_gold < display_cost)

func _load_card_database() -> void:
	## Load cards from res://data/cards/ directory
	var cards_dir := "res://data/cards/"
	var dir := DirAccess.open(cards_dir)
	
	if dir == null:
		print("[ShopScreen] Warning: Could not open cards directory, using fallback cards")
		_generate_fallback_cards()
		return
	
	var all_cards: Array[Dictionary] = []
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var card_path := cards_dir + file_name
			var card_resource = load(card_path)
			if card_resource and card_resource is CardData:
				var card: CardData = card_resource
				# Calculate price based on stats and rarity
				var price := _calculate_card_price(card)
				all_cards.append({
					"id": card.id,
					"name": card.card_name,
					"description": card.description,
					"cost": price,
					"card_data": card,
					"type": "card"
				})
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Shuffle and take a subset for the shop
	all_cards.shuffle()
	var shop_size := mini(6, all_cards.size())
	for i in range(shop_size):
		card_shop_items.append(all_cards[i])
	
	print("[ShopScreen] Loaded %d cards for shop" % card_shop_items.size())


func _calculate_card_price(card: CardData) -> int:
	var base_price := 50
	
	# Add for stats
	base_price += card.cost * 10
	base_price += card.attack * 5
	base_price += card.health * 5
	
	# Rarity multiplier
	match card.rarity:
		CardData.Rarity.COMMON:
			base_price = int(base_price * 1.0)
		CardData.Rarity.RARE:
			base_price = int(base_price * 1.5)
		CardData.Rarity.EPIC:
			base_price = int(base_price * 2.0)
		CardData.Rarity.LEGENDARY:
			base_price = int(base_price * 3.0)
	
	return base_price


func _generate_fallback_cards() -> void:
	# Generate some basic cards if database can't be loaded
	for i in range(6):
		card_shop_items.append({
			"id": "shop_card_%d" % i,
			"name": "Card %d" % (i + 1),
			"description": "A purchasable card",
			"cost": 50 + (i * 25),
			"card_data": null,
			"type": "card"
		})


func _setup_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.1, 0.14)
	add_child(bg)
	
	# Main layout
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)
	
	# Header
	var header = HBoxContainer.new()
	main_vbox.add_child(header)
	
	title_label = Label.new()
	title_label.text = "🛒 Shop"
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	
	var gold_container = HBoxContainer.new()
	gold_container.add_theme_constant_override("separation", 8)
	header.add_child(gold_container)
	
	var gold_icon = Label.new()
	gold_icon.text = "💰"
	gold_icon.add_theme_font_size_override("font_size", 28)
	gold_container.add_child(gold_icon)
	
	gold_label = Label.new()
	gold_label.text = str(player_gold)
	gold_label.add_theme_font_size_override("font_size", 28)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	gold_container.add_child(gold_label)
	
	main_vbox.add_child(HSeparator.new())
	
	# Tabs
	tab_container = HBoxContainer.new()
	tab_container.add_theme_constant_override("separation", 10)
	main_vbox.add_child(tab_container)
	
	var tabs = ["Cards", "Upgrades", "Packs"]
	for i in range(tabs.size()):
		var tab_btn = Button.new()
		tab_btn.text = tabs[i]
		tab_btn.toggle_mode = true
		tab_btn.button_pressed = (i == 0)
		tab_btn.pressed.connect(_on_tab_pressed.bind(i))
		tab_container.add_child(tab_btn)
	
	# Items grid
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	items_container = GridContainer.new()
	items_container.columns = 3
	items_container.add_theme_constant_override("h_separation", 15)
	items_container.add_theme_constant_override("v_separation", 15)
	scroll.add_child(items_container)
	
	# Description panel
	var desc_panel = PanelContainer.new()
	desc_panel.custom_minimum_size = Vector2(0, 80)
	main_vbox.add_child(desc_panel)
	
	description_label = RichTextLabel.new()
	description_label.bbcode_enabled = true
	description_label.text = "[center]Select an item to see details[/center]"
	description_label.fit_content = true
	desc_panel.add_child(description_label)
	
	# Bottom buttons
	var button_container = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 20)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(button_container)
	
	back_button = Button.new()
	back_button.text = "Leave Shop"
	back_button.custom_minimum_size = Vector2(150, 45)
	back_button.pressed.connect(_on_back_pressed)
	button_container.add_child(back_button)
	
	buy_button = Button.new()
	buy_button.text = "Buy"
	buy_button.custom_minimum_size = Vector2(150, 45)
	buy_button.disabled = true
	buy_button.pressed.connect(_on_buy_pressed)
	button_container.add_child(buy_button)


func _apply_styling() -> void:
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.25, 0.35)
	btn_style.border_color = Color(0.5, 0.45, 0.3)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(10)
	
	for btn in [back_button, buy_button]:
		if btn:
			btn.add_theme_stylebox_override("normal", btn_style)
	
	var disabled_style = btn_style.duplicate()
	disabled_style.bg_color = Color(0.15, 0.15, 0.18)
	disabled_style.border_color = Color(0.3, 0.3, 0.3)
	buy_button.add_theme_stylebox_override("disabled", disabled_style)


func _populate_items() -> void:
	# Clear existing items
	for child in items_container.get_children():
		child.queue_free()
	
	var items: Array[Dictionary] = []
	match current_tab:
		ShopTab.CARDS:
			items.assign(card_shop_items)
		ShopTab.UPGRADES:
			items.assign(upgrade_shop_items)
		ShopTab.PACKS:
			items.assign(pack_shop_items)
	
	for item in items:
		var panel = _create_item_panel(item)
		items_container.add_child(panel)


func _create_item_panel(item: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(180, 120)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.18, 0.25)
	style.border_color = Color(0.35, 0.3, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)
	
	# Icon/Name row
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var icon = Label.new()
	icon.text = item.get("icon", "🃏")
	icon.add_theme_font_size_override("font_size", 24)
	header.add_child(icon)
	
	var name_lbl = Label.new()
	name_lbl.text = item.get("name", "Item")
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 14)
	header.add_child(name_lbl)
	
	# Description
	var desc = Label.new()
	desc.text = item.get("description", "")
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Price - with modifier support
	var base_cost: int = item.get("cost", 100)
	var display_cost := _get_modified_cost(item, base_cost)
	
	var price_lbl = Label.new()
	if display_cost < base_cost:
		price_lbl.text = "💰 [s]%d[/s] %d" % [base_cost, display_cost]
		price_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		price_lbl.text = "💰 %d" % display_cost
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	price_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(price_lbl)
	
	# Store item reference
	panel.set_meta("item_data", item)
	panel.set_meta("display_cost", display_cost)
	
	# Make clickable
	panel.gui_input.connect(_on_item_clicked.bind(panel, item))
	
	return panel


## Get the modified cost for an item (with shop discount modifiers)
func _get_modified_cost(item: Dictionary, base_cost: int) -> int:
	if not ModifierManager:
		return base_cost
	
	var item_type: String = item.get("type", "card")
	var activity_type := "shop_" + item_type  # e.g., "shop_card", "shop_upgrade", "shop_pack"
	
	return ModifierManager.apply_schedule_effect_modifiers(activity_type, base_cost)


func _on_item_clicked(event: InputEvent, panel: PanelContainer, item: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_item(panel, item)


func _select_item(panel: PanelContainer, item: Dictionary) -> void:
	# Deselect previous
	if selected_item_panel:
		var old_style = selected_item_panel.get_theme_stylebox("panel").duplicate()
		old_style.border_color = Color(0.35, 0.3, 0.25)
		selected_item_panel.add_theme_stylebox_override("panel", old_style)
	
	# Select new
	selected_item = item
	selected_item_panel = panel
	
	var new_style = panel.get_theme_stylebox("panel").duplicate()
	new_style.border_color = Color(0.8, 0.7, 0.3)
	panel.add_theme_stylebox_override("panel", new_style)
	
	# Update description
	var desc_text := "[center][b]%s[/b]\n%s[/center]" % [
		item.get("name", "Item"),
		item.get("description", "")
	]
	description_label.text = desc_text
	
	# Update buy button
	var display_cost: int = panel.get_meta("display_cost")
	buy_button.disabled = (player_gold < display_cost)
	buy_button.text = "Buy (%d 💰)" % display_cost


func _on_tab_pressed(tab_index: int) -> void:
	current_tab = tab_index as ShopTab
	
	# Update tab button states
	for i in range(tab_container.get_child_count()):
		var btn = tab_container.get_child(i) as Button
		if btn:
			btn.button_pressed = (i == tab_index)
	
	# Clear selection
	selected_item = {}
	selected_item_panel = null
	description_label.text = "[center]Select an item to see details[/center]"
	buy_button.disabled = true
	buy_button.text = "Buy"
	
	_populate_items()


func _on_buy_pressed() -> void:
	if selected_item.is_empty():
		return
	
	var display_cost: int = selected_item_panel.get_meta("display_cost") if selected_item_panel else selected_item.get("cost", 100)
	
	if player_gold < display_cost:
		print("[ShopScreen] Not enough gold!")
		return
	
	# Deduct gold
	player_gold -= display_cost
	GameManager.set_meta("player_gold", player_gold)
	gold_label.text = str(player_gold)
	
	# Handle purchase based on type
	var item_type: String = selected_item.get("type", "card")
	match item_type:
		"card":
			_purchase_card(selected_item)
		"upgrade":
			_purchase_upgrade(selected_item)
		"pack":
			_purchase_pack(selected_item)
	
	print("[ShopScreen] Purchased %s for %d gold" % [selected_item.get("name", "item"), display_cost])
	
	# Remove from shop if it's a card (one-time purchase)
	if item_type == "card":
		var idx := card_shop_items.find(selected_item)
		if idx != -1:
			card_shop_items.remove_at(idx)
	
	# Clear selection and refresh
	selected_item = {}
	selected_item_panel = null
	description_label.text = "[center]Purchase complete![/center]"
	buy_button.disabled = true
	buy_button.text = "Buy"
	
	_populate_items()


func _purchase_card(item: Dictionary) -> void:
	var card_data: CardData = item.get("card_data")
	if not card_data:
		return
	
	# Add to player's deck
	var current_deck_meta = {}
	if GameManager.has_meta("selected_deck"):
		current_deck_meta = GameManager.get_meta("selected_deck")
	
	if not current_deck_meta.has("cards"):
		current_deck_meta["cards"] = []
	
	current_deck_meta["cards"].append(card_data.id)
	GameManager.set_meta("selected_deck", current_deck_meta)
	
	print("[ShopScreen] Added card to deck: %s" % card_data.card_name)


func _purchase_upgrade(item: Dictionary) -> void:
	var upgrade_id: String = item.get("id", "")
	
	# Store purchased upgrades
	var upgrades: Array = []
	if GameManager.has_meta("purchased_upgrades"):
		upgrades = GameManager.get_meta("purchased_upgrades")
	
	upgrades.append(upgrade_id)
	GameManager.set_meta("purchased_upgrades", upgrades)
	
	# Apply upgrade effect (could also be done via modifiers!)
	match upgrade_id:
		"max_hand_size":
			# This would integrate with your game rules
			print("[ShopScreen] Upgrade: Max hand size +1")
		"starting_mana":
			print("[ShopScreen] Upgrade: Starting mana +1")
		"card_draw":
			print("[ShopScreen] Upgrade: Starting cards +1")


func _purchase_pack(item: Dictionary) -> void:
	var pack_id: String = item.get("id", "")
	
	# Generate random cards based on pack type
	# This would integrate with your card database
	print("[ShopScreen] Opening pack: %s" % pack_id)
	
	# TODO: Show pack opening UI with generated cards


func _on_back_pressed() -> void:
	# Return to week runner if we came from there
	if GameManager.has_meta("return_to_week_runner") and GameManager.get_meta("return_to_week_runner"):
		GameManager.set_meta("return_to_week_runner", false)
		
		# Advance the day
		var current_day: int = GameManager.get_meta("current_day_index") if GameManager.has_meta("current_day_index") else 0
		current_day += 1
		GameManager.set_meta("current_day_index", current_day)
		
		get_tree().change_scene_to_file("res://scenes/week_runner.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _on_viewport_size_changed() -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_back_pressed()
