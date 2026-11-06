# res://scripts/victory_selection.gd
extends Control

## Victory screen shown after winning a battle
## Allows player to choose card rewards

const REFERENCE_HEIGHT: float = 720.0
const CARDS_PER_BUCKET: int = 3
const NUM_BUCKETS: int = 3

## Available cards for rewards
var reward_pool: Array[CardData] = []

## Generated buckets of cards
var reward_buckets: Array[Array] = []

## UI References
var title_label: Label
var gold_label: Label
var buckets_container: HBoxContainer
var skip_button: Button

## Track if selection has been made
var selection_made: bool = false


func _ready() -> void:
	_load_card_pool()
	_generate_reward_buckets()
	_setup_ui()
	_apply_styling()
	
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	print("[VictorySelection] Showing %d reward buckets" % reward_buckets.size())


func _load_card_pool() -> void:
	# Load cards from database
	var cards_dir := "res://data/cards/"
	var dir := DirAccess.open(cards_dir)
	
	if dir == null:
		print("[VictorySelection] Warning: Could not open cards directory")
		_generate_fallback_pool()
		return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var card_path := cards_dir + file_name
			var card_resource = load(card_path)
			if card_resource and card_resource is CardData:
				reward_pool.append(card_resource)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# Shuffle the pool
	reward_pool.shuffle()
	
	print("[VictorySelection] Loaded %d cards for reward pool" % reward_pool.size())


func _generate_fallback_pool() -> void:
	# Generate some basic cards if database can't be loaded
	for i in range(15):
		var card := CardData.new()
		card.id = "reward_%d" % i
		card.card_name = "Reward Card %d" % (i + 1)
		card.cost = (i % 5) + 1
		card.attack = (i % 4) + 1
		card.health = (i % 4) + 2
		card.card_type = CardData.CardType.MINION
		card.rarity = (i % 4) as CardData.Rarity
		reward_pool.append(card)


func _generate_reward_buckets() -> void:
	reward_buckets.clear()
	
	# MODIFIER HOOK: Check if modifiers affect reward quantity
	var cards_per_bucket := CARDS_PER_BUCKET
	if ModifierManager:
		cards_per_bucket = ModifierManager.apply_schedule_effect_modifiers("reward_cards_per_bucket", CARDS_PER_BUCKET)
	
	var num_buckets := NUM_BUCKETS
	if ModifierManager:
		num_buckets = ModifierManager.apply_schedule_effect_modifiers("reward_bucket_count", NUM_BUCKETS)
	
	var pool_copy := reward_pool.duplicate()
	pool_copy.shuffle()
	
	for i in range(num_buckets):
		var bucket: Array[CardData] = []
		for j in range(cards_per_bucket):
			if pool_copy.is_empty():
				break
			bucket.append(pool_copy.pop_back())
		if not bucket.is_empty():
			reward_buckets.append(bucket)


func _setup_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.08, 0.12)
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
	main_vbox.add_theme_constant_override("separation", 20)
	margin.add_child(main_vbox)
	
	# Victory header
	title_label = Label.new()
	title_label.text = "🏆 Victory!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	main_vbox.add_child(title_label)
	
	# Gold earned display
	var gold_earned := _get_gold_reward()
	
	var gold_container = HBoxContainer.new()
	gold_container.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_container.add_theme_constant_override("separation", 10)
	main_vbox.add_child(gold_container)
	
	var gold_icon = Label.new()
	gold_icon.text = "💰"
	gold_icon.add_theme_font_size_override("font_size", 28)
	gold_container.add_child(gold_icon)
	
	gold_label = Label.new()
	gold_label.text = "+%d Gold" % gold_earned
	gold_label.add_theme_font_size_override("font_size", 28)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	gold_container.add_child(gold_label)
	
	# Instructions
	var instruction = Label.new()
	instruction.text = "Choose a reward bundle:"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_font_size_override("font_size", 18)
	instruction.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	main_vbox.add_child(instruction)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer1)
	
	# Buckets container
	buckets_container = HBoxContainer.new()
	buckets_container.alignment = BoxContainer.ALIGNMENT_CENTER
	buckets_container.add_theme_constant_override("separation", 30)
	main_vbox.add_child(buckets_container)
	
	# Create bucket displays
	for i in range(reward_buckets.size()):
		var bucket_panel = _create_bucket_panel(reward_buckets[i], i)
		buckets_container.add_child(bucket_panel)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(spacer2)
	
	# Skip button
	skip_button = Button.new()
	skip_button.text = "Skip Rewards"
	skip_button.custom_minimum_size = Vector2(150, 40)
	skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip_button.pressed.connect(_on_skip_pressed)
	main_vbox.add_child(skip_button)


func _get_gold_reward() -> int:
	var base_gold := 50
	var battle_type: String = GameManager.get_meta("battle_type") if GameManager.has_meta("battle_type") else "normal"
	
	if battle_type == "elite":
		base_gold = 100
	
	# MODIFIER HOOK: Apply modifier to gold reward
	if ModifierManager:
		base_gold = ModifierManager.apply_schedule_effect_modifiers("victory_gold", base_gold)
	
	return base_gold


func _create_bucket_panel(cards: Array, bucket_index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 300)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.22)
	style.border_color = Color(0.4, 0.35, 0.25)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	# Bundle label
	var bundle_label = Label.new()
	bundle_label.text = "Bundle %d" % (bucket_index + 1)
	bundle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bundle_label.add_theme_font_size_override("font_size", 16)
	bundle_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	vbox.add_child(bundle_label)
	
	vbox.add_child(HSeparator.new())
	
	# Card list
	for card in cards:
		var card_entry = _create_card_entry(card as CardData)
		vbox.add_child(card_entry)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Select button
	var select_btn = Button.new()
	select_btn.text = "Choose"
	select_btn.custom_minimum_size = Vector2(0, 35)
	select_btn.pressed.connect(_on_bucket_selected.bind(cards))
	vbox.add_child(select_btn)
	
	# Hover effect
	panel.mouse_entered.connect(func():
		var hover_style = style.duplicate()
		hover_style.border_color = Color(0.8, 0.7, 0.3)
		panel.add_theme_stylebox_override("panel", hover_style)
	)
	panel.mouse_exited.connect(func():
		panel.add_theme_stylebox_override("panel", style)
	)
	
	return panel


func _create_card_entry(card: CardData) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	
	# Rarity indicator
	var rarity_color := _get_rarity_color(card.rarity)
	var rarity_dot = Label.new()
	rarity_dot.text = "●"
	rarity_dot.add_theme_color_override("font_color", rarity_color)
	rarity_dot.add_theme_font_size_override("font_size", 12)
	hbox.add_child(rarity_dot)
	
	# Mana cost
	var mana = Label.new()
	mana.text = "[%d]" % card.cost
	mana.add_theme_font_size_override("font_size", 12)
	mana.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	hbox.add_child(mana)
	
	# Name
	var name_lbl = Label.new()
	name_lbl.text = card.card_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", rarity_color)
	name_lbl.clip_text = true
	hbox.add_child(name_lbl)
	
	# Stats for minions
	if card.card_type == CardData.CardType.MINION:
		var stats = Label.new()
		stats.text = "%d/%d" % [card.attack, card.health]
		stats.add_theme_font_size_override("font_size", 11)
		stats.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		hbox.add_child(stats)
	
	return hbox


func _get_rarity_color(rarity: CardData.Rarity) -> Color:
	match rarity:
		CardData.Rarity.COMMON: return Color(0.7, 0.7, 0.7)
		CardData.Rarity.RARE: return Color(0.3, 0.5, 0.9)
		CardData.Rarity.EPIC: return Color(0.6, 0.3, 0.8)
		CardData.Rarity.LEGENDARY: return Color(1.0, 0.7, 0.2)
		_: return Color.WHITE


func _apply_styling() -> void:
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.22, 0.28)
	btn_style.border_color = Color(0.4, 0.35, 0.25)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(8)
	
	if skip_button:
		skip_button.add_theme_stylebox_override("normal", btn_style)


func _on_bucket_selected(cards: Array) -> void:
	if selection_made:
		return
	selection_made = true
	
	var cards_typed: Array[CardData] = []
	for card in cards:
		if card is CardData:
			cards_typed.append(card)
	
	print("[VictorySelection] Selected bucket with %d cards" % cards_typed.size())
	
	# Add cards to deck
	var current_deck_meta = {}
	if GameManager.has_meta("selected_deck"):
		current_deck_meta = GameManager.get_meta("selected_deck")
	
	if not current_deck_meta.has("cards"):
		current_deck_meta["cards"] = []
	
	for card in cards_typed:
		var card_id = card.id if not card.id.is_empty() else card.card_name.to_lower()
		current_deck_meta["cards"].append(card_id)
		print("[VictorySelection] Added card: %s" % card_id)
	
	GameManager.set_meta("selected_deck", current_deck_meta)
	
	_finalize_victory()


func _on_skip_pressed() -> void:
	if selection_made:
		return
	selection_made = true
	
	print("[VictorySelection] Skipped rewards")
	_finalize_victory()


func _finalize_victory() -> void:
	# Award gold
	var gold_reward := _get_gold_reward()
	var player_gold: int = GameManager.get_meta("player_gold") if GameManager.has_meta("player_gold") else 0
	player_gold += gold_reward
	GameManager.set_meta("player_gold", player_gold)
	print("[VictorySelection] Awarded %d gold. Total: %d" % [gold_reward, player_gold])
	
	# Reset game state for next battle
	GameManager.reset_game()
	
	# Check if we should return to week runner
	if GameManager.has_meta("return_to_week_runner") and GameManager.get_meta("return_to_week_runner"):
		GameManager.set_meta("return_to_week_runner", false)
		
		# Advance the day
		var current_day: int = GameManager.get_meta("current_day_index") if GameManager.has_meta("current_day_index") else 0
		current_day += 1
		GameManager.set_meta("current_day_index", current_day)
		
		print("[VictorySelection] Returning to week runner, advancing to day %d" % (current_day + 1))
		
		get_tree().change_scene_to_file("res://scenes/week_runner.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/start_screen.tscn")


func _on_viewport_size_changed() -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_skip_pressed()
