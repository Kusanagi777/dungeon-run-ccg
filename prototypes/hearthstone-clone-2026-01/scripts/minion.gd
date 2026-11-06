# res://scripts/minion.gd
class_name Minion
extends Control

## Signals - using 'm' instead of 'minion' to avoid class name conflict
signal minion_clicked(m: Node)
signal minion_targeted(m: Node)
signal minion_drag_started(m: Node)
signal minion_drag_ended(m: Node, global_pos: Vector2)

## Card data
var card_data: CardData

## Owner player ID
var owner_id: int = 0

## Lane position
var lane_index: int = 0
var is_front_row: bool = true

## Current stats (base values before modifiers)
var current_attack: int = 0
var current_health: int = 0
var max_health: int = 0

## Combat flags
var has_attacked: bool = false
var just_played: bool = true
var has_moved_this_turn: bool = false
var attacks_this_turn: int = 0

## Visual state
var is_targetable: bool = false
var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

## Combat Keywords
var has_charge: bool = false       # Can attack immediately when summoned
var has_rush: bool = false         # Can attack minions (not heroes) when summoned
var has_aggressive: bool = false   # Can attack twice per turn
var has_taunt: bool = false        # Protects other minions in same row
var has_pierce: bool = false       # Excess damage goes to enemy hero
var has_snipe: bool = false        # Can attack from back row / target back row
var has_bully: bool = false        # Bonus effect when attacking weaker targets
var has_lethal: bool = false       # Any damage destroys the target
var has_stun: bool = false         # Currently stunned (cannot attack this turn)

## Defensive Keywords
var has_shielded: bool = false     # Next damage instance is reduced to 0
var has_ward: bool = false         # Cannot be targeted by action cards
var has_hidden: bool = false       # Cannot be targeted by opponents
var has_illusion: bool = false     # Dies on any interaction
var resist_value: int = 0          # Takes X less damage

## Trigger Keywords (these are usually effect-based, flag indicates presence)
var has_deploy: bool = false       # Effect on play (on-play)
var has_last_words: bool = false   # Effect on death (on-death)
var has_bounty: bool = false       # Opponent gets reward on death
var has_empowered: bool = false    # Bonus after action card played
var has_fated: bool = false        # Bonus if played same turn as drawn

## Resource Keywords
var has_drain: bool = false        # Damage dealt heals your hero
var has_affinity: bool = false     # Cost reduction based on tags
var affinity_tag: int = 0          # Which tag reduces cost
var has_sacrifice: bool = false    # Sacrifice minions for effect
var sacrifice_cost: int = 0        # Number of minions to sacrifice
var has_ritual: bool = false       # Optional sacrifice for bonus
var ritual_cost: int = 0           # Number of minions for ritual
var has_conduit: bool = false      # Boost action card damage
var conduit_value: int = 0         # Amount of damage boost

## Utility Keywords
var has_echo: bool = false         # Creates copy in hand when played
var has_draft: bool = false        # Choose from 3 random cards
var has_cycle: bool = false        # Can pay 1 mana to shuffle and draw
var has_scout: bool = false        # Look at top card of deck

## Special Keywords
var has_persistent: bool = false   # Returns with 1 HP when destroyed
var has_huddle: bool = false       # Can be played in occupied space
var has_silence: bool = false      # Has been silenced (keywords removed)

## Tracking Variables
var drawn_this_turn: bool = false  # For Fated keyword
# attacks_this_turn is already declared above
var echo_card: bool = false        # Is this an echo copy?
var weakened_amount: int = 0       # Temporary attack reduction

## Huddle Support
var huddled_minion: Node = null    # Reference to huddled minion

## Minion Tags
var role_tag: MinionTags.Role = MinionTags.Role.NONE
var biology_tag: MinionTags.Biology = MinionTags.Biology.HUMANOID

## UI References
@onready var frame: Panel = $Frame
@onready var art_panel: Panel = $Frame/VBox/ArtPanel
@onready var card_art: TextureRect = $Frame/VBox/ArtPanel/CardArt
@onready var name_label: Label = $Frame/VBox/NameLabel
@onready var attack_icon: Panel = $Frame/AttackIcon
@onready var attack_label: Label = $Frame/AttackIcon/AttackLabel
@onready var health_icon: Panel = $Frame/HealthIcon
@onready var health_label: Label = $Frame/HealthIcon/HealthLabel
@onready var taunt_border: Panel = $Frame/TauntBorder
@onready var divine_shield_effect: ColorRect = $Frame/DivineShieldEffect
@onready var highlight: ColorRect = $Frame/Highlight
@onready var sleeping_icon: Label = $Frame/SleepingIcon
@onready var damage_label: Label = $Frame/DamageLabel
@onready var huddle_indicator: Panel = $Frame/HuddleIndicator

## Sizing constants
const BASE_MINION_SIZE := Vector2(80, 100)
const BASE_FONT_SIZES := {
	"name": 10,
	"stats": 14,
	"damage": 18,
	"sleeping": 24
}

const REFERENCE_HEIGHT := 720.0


func _ready() -> void:
	GameManager.turn_started.connect(_on_turn_started)
	
	var scale_factor := get_scale_factor()
	_apply_scaling(scale_factor)
	_apply_default_styling()
	
	_update_visuals()
	
	gui_input.connect(_on_gui_input)


func get_scale_factor() -> float:
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	return clampf(viewport_height / REFERENCE_HEIGHT, 0.8, 2.0)


func _apply_scaling(scale_factor: float) -> void:
	custom_minimum_size = BASE_MINION_SIZE * scale_factor
	
	if name_label:
		name_label.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["name"] * scale_factor))
	if attack_label:
		attack_label.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["stats"] * scale_factor))
	if health_label:
		health_label.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["stats"] * scale_factor))
	if damage_label:
		damage_label.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["damage"] * scale_factor))
	if sleeping_icon:
		sleeping_icon.add_theme_font_size_override("font_size", int(BASE_FONT_SIZES["sleeping"] * scale_factor))


func _apply_default_styling() -> void:
	if frame and not frame.has_theme_stylebox_override("panel"):
		var frame_style := StyleBoxFlat.new()
		frame_style.bg_color = Color(0.2, 0.18, 0.15)
		frame_style.border_color = Color(0.4, 0.35, 0.25)
		frame_style.set_border_width_all(2)
		frame_style.set_corner_radius_all(5)
		frame.add_theme_stylebox_override("panel", frame_style)
	
	if art_panel and not art_panel.has_theme_stylebox_override("panel"):
		var art_style := StyleBoxFlat.new()
		art_style.bg_color = Color(0.35, 0.4, 0.45)
		art_style.set_corner_radius_all(3)
		art_panel.add_theme_stylebox_override("panel", art_style)
	
	if attack_icon and not attack_icon.has_theme_stylebox_override("panel"):
		var attack_style := StyleBoxFlat.new()
		attack_style.bg_color = Color(0.8, 0.6, 0.1)
		attack_style.set_corner_radius_all(10)
		attack_icon.add_theme_stylebox_override("panel", attack_style)
	
	if health_icon and not health_icon.has_theme_stylebox_override("panel"):
		var health_style := StyleBoxFlat.new()
		health_style.bg_color = Color(0.8, 0.2, 0.2)
		health_style.set_corner_radius_all(10)
		health_icon.add_theme_stylebox_override("panel", health_style)


func initialize(data: CardData, player: int) -> void:
	card_data = data
	owner_id = player
	
	current_attack = data.attack
	current_health = data.health
	max_health = data.health
	
	_parse_keywords()
	_update_visuals()


func _parse_keywords() -> void:
	if not card_data:
		return
	
	# Reset all keyword flags
	_reset_keyword_flags()
	
	# Combat Keywords
	has_charge = card_data.has_keyword("Charge")
	has_rush = card_data.has_keyword("Rush")
	has_aggressive = card_data.has_keyword("Aggressive")
	has_taunt = card_data.has_keyword("Taunt")
	has_pierce = card_data.has_keyword("Pierce")
	has_snipe = card_data.has_keyword("Snipe")
	has_bully = card_data.has_keyword("Bully")
	has_lethal = card_data.has_keyword("Lethal")
	
	# Defensive Keywords
	has_shielded = card_data.has_keyword("Shielded")
	has_ward = card_data.has_keyword("Ward")
	has_hidden = card_data.has_keyword("Hidden")
	has_illusion = card_data.has_keyword("Illusion")
	resist_value = _parse_keyword_value("Resist")
	
	# Trigger Keywords
	has_deploy = card_data.has_keyword("Deploy") or card_data.has_keyword("On-play")
	has_last_words = card_data.has_keyword("Last words") or card_data.has_keyword("On-death")
	has_bounty = card_data.has_keyword("Bounty")
	has_empowered = card_data.has_keyword("Empowered")
	has_fated = card_data.has_keyword("Fated")
	
	# Resource Keywords
	has_drain = card_data.has_keyword("Drain")
	has_affinity = card_data.has_keyword_base("Affinity")
	has_sacrifice = card_data.has_keyword_base("Sacrifice")
	sacrifice_cost = _parse_keyword_value("Sacrifice")
	has_ritual = card_data.has_keyword("Ritual")
	ritual_cost = _parse_keyword_value("Ritual") if _parse_keyword_value("Ritual") > 0 else 1
	has_conduit = card_data.has_keyword_base("Conduit")
	conduit_value = _parse_keyword_value("Conduit")
	
	# Utility Keywords
	has_echo = card_data.has_keyword("Echo")
	has_draft = card_data.has_keyword("Draft")
	has_cycle = card_data.has_keyword("Cycle")
	has_scout = card_data.has_keyword("Scout")
	
	# Special Keywords
	has_persistent = card_data.has_keyword("Persistent")
	has_huddle = card_data.has_keyword("Huddle")
	
	# Charge removes summoning sickness
	if has_charge:
		just_played = false

func _reset_keyword_flags() -> void:
	has_charge = false
	has_rush = false
	has_aggressive = false
	has_taunt = false
	has_pierce = false
	has_snipe = false
	has_bully = false
	has_lethal = false
	has_stun = false
	has_shielded = false
	has_ward = false
	has_hidden = false
	has_illusion = false
	resist_value = 0
	has_deploy = false
	has_last_words = false
	has_bounty = false
	has_empowered = false
	has_fated = false
	has_drain = false
	has_affinity = false
	has_sacrifice = false
	sacrifice_cost = 0
	has_ritual = false
	ritual_cost = 0
	has_conduit = false
	conduit_value = 0
	has_echo = false
	has_draft = false
	has_cycle = false
	has_scout = false
	has_persistent = false
	has_huddle = false
	has_silence = false
	weakened_amount = 0


func _parse_keyword_value(keyword: String) -> int:
	if card_data and card_data.has_method("get_keyword_value"):
		return card_data.get_keyword_value(keyword)
	
	# Fallback parsing
	for kw in card_data.keywords:
		var kw_lower := kw.to_lower()
		var base := keyword.to_lower()
		if kw_lower.begins_with(base):
			var remainder := kw_lower.replace(base, "").strip_edges()
			remainder = remainder.trim_prefix("(").trim_suffix(")")
			if remainder.is_valid_int():
				return remainder.to_int()
	return 0

## Apply Silence - removes all keywords and text
func apply_silence() -> void:
	has_silence = true
	
	# Remove all keyword flags
	has_charge = false
	has_rush = false
	has_aggressive = false
	has_taunt = false
	has_pierce = false
	has_snipe = false
	has_bully = false
	has_lethal = false
	has_shielded = false
	has_ward = false
	has_hidden = false
	has_illusion = false
	resist_value = 0
	has_deploy = false
	has_last_words = false
	has_bounty = false
	has_empowered = false
	has_fated = false
	has_drain = false
	has_affinity = false
	has_sacrifice = false
	has_ritual = false
	has_conduit = false
	conduit_value = 0
	has_echo = false
	has_draft = false
	has_cycle = false
	has_scout = false
	has_persistent = false
	has_huddle = false
	
	# Clear huddled minion reference
	if huddled_minion:
		huddled_minion = null
	
	_update_visuals()
	print("[Minion] %s has been Silenced!" % card_data.card_name)


## Apply Stun - prevents attacking this turn
func apply_stun() -> void:
	has_stun = true
	_update_visuals()
	print("[Minion] %s has been Stunned!" % card_data.card_name)


## Apply Weakened - reduces attack temporarily
func apply_weakened(amount: int) -> void:
	weakened_amount += amount
	_update_visuals()
	print("[Minion] %s is Weakened by %d!" % [card_data.card_name, amount])


## Clear Weakened at end of turn
func clear_weakened() -> void:
	weakened_amount = 0
	_update_visuals()


## Clear Stun at end of turn
func clear_stun() -> void:
	has_stun = false
	_update_visuals()


## Get effective attack (accounting for Weakened)
func apply_pierce_damage(target_minion: Minion, damage_dealt: int) -> void:
	if not has_pierce:
		return
	
	var overkill := damage_dealt - target_minion.current_health
	if overkill > 0 and target_minion.owner_id != owner_id:
		var enemy_id := target_minion.owner_id
		print("[Minion] %s Pierce deals %d to enemy hero!" % [card_data.card_name, overkill])
		GameManager.damage_hero(enemy_id, overkill)


## Handle death (with Persistent, Bounty, Last Words)
func die() -> void:
	# Persistent - revive with 1 HP
	if has_persistent:
		has_persistent = false
		current_health = 1
		print("[Minion] %s Persistent triggered - revived with 1 HP!" % card_data.card_name)
		_update_visuals()
		return
	
	# Bounty - reward enemy player
	if has_bounty:
		var enemy_id := 1 - owner_id
		_trigger_bounty(enemy_id)
	
	# Last Words / On-death effect
	if has_last_words and not has_silence:
		_trigger_last_words()
	
	# Huddle - transfer to huddled minion
	if huddled_minion and is_instance_valid(huddled_minion):
		_transfer_to_huddled()
	
	# Signal death
	emit_signal("minion_died", self)
	
	# Remove from board
	GameManager.remove_minion_from_board(owner_id, self)
	queue_free()


func _trigger_bounty(enemy_id: int) -> void:
	# Default bounty: draw a card
	print("[Minion] %s Bounty triggered - Player %d draws a card!" % [card_data.card_name, enemy_id])
	GameManager._draw_card(enemy_id)


func _trigger_last_words() -> void:
	# Trigger deathrattle effect through effect system
	print("[Minion] %s Last Words triggered!" % card_data.card_name)
	# Effect handling would be done by CardEffectBase subclass


func _transfer_to_huddled() -> void:
	print("[Minion] %s transfers position to huddled minion!" % card_data.card_name)
	huddled_minion.lane_index = lane_index
	huddled_minion.is_front_row = is_front_row
	# Reveal the huddled minion
	GameManager.register_minion_on_board(owner_id, huddled_minion, lane_index, 0 if is_front_row else 1)

## =============================================================================
## STAT GETTERS (WITH MODIFIER SUPPORT)
## =============================================================================

## Get effective attack value (base + modifiers)
func get_effective_attack() -> int:
	var base := current_attack
	
	# Apply Weakened reduction
	base -= weakened_amount
	
	if ModifierManager:
		base = ModifierManager.apply_minion_attack_modifiers(self, base)
	
	return maxi(0, base)


## Get effective health value (base + modifiers)
func get_effective_health() -> int:
	var base := current_health
	if ModifierManager:
		return ModifierManager.apply_minion_health_modifiers(self, base)
	return base


## Get effective max health (base + modifiers)
func get_effective_max_health() -> int:
	var base := max_health
	if ModifierManager:
		return ModifierManager.apply_minion_health_modifiers(self, base)
	return base


## =============================================================================
## DAMAGE AND HEALING
## =============================================================================

func take_damage(amount: int) -> void:
	# Illusion - dies on any interaction
	if has_illusion:
		print("[Minion] %s Illusion triggered - dies on interaction!" % card_data.card_name)
		die()
		return

	var actual_damage := amount
	if actual_damage <= 0:
		return
	
	# Shielded absorbs the first damage instance
	if has_shielded and actual_damage > 0:
		has_shielded = false
		_update_visuals()
		_play_damage_effect(0)  # Shield absorbed
		
		# MODIFIER HOOK: Keyword triggered
		if ModifierManager:
			ModifierManager.trigger_keyword("Shielded", self, {"blocked": actual_damage})
		return
	
	# Apply Resist reduction
	if resist_value > 0:
		actual_damage = maxi(0, actual_damage - resist_value)
		print("[Minion] %s Resist reduced damage by %d!" % [card_data.card_name, resist_value])
	
	# Note: Damage modification is handled in GameManager.execute_combat()
	# This function receives already-modified damage
	current_health -= actual_damage
	_update_visuals()
	_play_damage_effect(actual_damage)

	if current_health <= 0:
		die()


func heal(amount: int) -> void:
	if amount <= 0:
		return
	
	# MODIFIER HOOK: Modify healing amount
	var modified_amount := amount
	if ModifierManager:
		modified_amount = ModifierManager.apply_healing_modifiers(amount, null, self)
	
	var old_health := current_health
	current_health = mini(current_health + modified_amount, max_health)
	var actual_heal := current_health - old_health
	
	_update_visuals()
	
	# MODIFIER HOOK: Healing applied
	if ModifierManager and actual_heal > 0:
		ModifierManager.trigger_healing_applied(actual_heal, null, self)


func buff_stats(attack_bonus: int, health_bonus: int) -> void:
	current_attack += attack_bonus
	current_health += health_bonus
	max_health += health_bonus
	_update_visuals()


func remove_shielded() -> void:
	"""Called when Shielded is consumed by damage"""
	has_shielded = false
	_update_visuals()


func break_hidden() -> void:
	"""Called when Hidden minion attacks - reveals it"""
	has_hidden = false
	_update_visuals()


func remove_persistent() -> void:
	"""Called after Persistent triggers - prevents infinite loop"""
	has_persistent = false
	if card_data:
		card_data.remove_keyword("Persistent")


func get_card_data() -> CardData:
	return card_data


## =============================================================================
## COMBAT HELPERS
## =============================================================================

func can_attack() -> bool:
	# Stunned minions can't attack
	if has_stun:
		return false

	# MODIFIER HOOK: Check if modifiers prevent attacking
	if ModifierManager:
		# We'll check with a dummy target - the actual target check happens elsewhere
		if not ModifierManager.can_minion_attack(self, null):
			return false
	
	if just_played and not has_charge and not has_rush:
		return false
	
	# Already attacked check (Aggressive allows 2 attacks)
	if has_aggressive:
		if attacks_this_turn >= 2:
			return false
	else:
		if has_attacked:
			return false
	
	return true


func can_attack_target(target: Node) -> bool:
	if not can_attack():
		return false
	
	# Rush can only attack minions on the turn played
	if just_played and has_rush and not has_charge:
		if target == null or not target is Minion:
			return false
	
	# MODIFIER HOOK: Check if modifiers prevent attacking this specific target
	if ModifierManager:
		if not ModifierManager.can_minion_attack(self, target):
			return false
	
	return true


func can_attack_from_row() -> bool:
	# Can always attack from front row
	if is_front_row:
		return true
	# Can attack from back row with Snipe
	if has_snipe:
		return true
	return false


## =============================================================================
## VISUAL UPDATES
## =============================================================================

func _update_visuals() -> void:
	if card_art and card_data and card_data.texture:
		card_art.texture = card_data.texture
	
	if name_label and card_data:
		name_label.text = card_data.card_name
	
	# Get effective stats (with modifiers)
	var display_attack := get_effective_attack()
	var display_health := get_effective_health()
	
	if attack_label:
		attack_label.text = str(display_attack)
		# Color based on comparison to base
		if card_data and display_attack > card_data.attack:
			attack_label.add_theme_color_override("font_color", Color.GREEN)
		elif card_data and display_attack < card_data.attack:
			attack_label.add_theme_color_override("font_color", Color.RED)
		else:
			attack_label.add_theme_color_override("font_color", Color.WHITE)
	
	if health_label:
		health_label.text = str(display_health)
		# Color based on damage taken
		if card_data and display_health > card_data.health:
			health_label.add_theme_color_override("font_color", Color.GREEN)
		elif current_health < max_health:
			health_label.add_theme_color_override("font_color", Color.RED)
		else:
			health_label.add_theme_color_override("font_color", Color.WHITE)
	
	# Taunt border visibility
	if taunt_border:
		taunt_border.visible = has_taunt
	
	# Shielded effect (golden glow)
	if divine_shield_effect:
		divine_shield_effect.visible = has_shielded
	
	# Sleeping icon for just-played minions
	if sleeping_icon:
		sleeping_icon.visible = just_played and not has_charge
	
	# Hidden visual indicator (semi-transparent)
	if has_hidden:
		modulate.a = 0.6
	else:
		modulate.a = 1.0
	
	# Huddle indicator
	if huddle_indicator:
		huddle_indicator.visible = huddled_minion != null
	
	_update_can_attack_visual()


func _update_can_attack_visual() -> void:
	if highlight:
		var can_act := can_attack_from_row() and can_attack() and GameManager.is_player_turn(owner_id)
		highlight.visible = can_act


func _play_damage_effect(amount: int) -> void:
	if damage_label:
		damage_label.text = "-%d" % amount if amount > 0 else "⛨"
		damage_label.visible = true
		damage_label.modulate.a = 1.0
		damage_label.position = Vector2(20, 30)
		
		var tween := create_tween()
		tween.tween_property(damage_label, "position:y", damage_label.position.y - 25, 0.5)
		tween.parallel().tween_property(damage_label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): damage_label.visible = false)


## =============================================================================
## TURN MANAGEMENT
## =============================================================================

func refresh_for_turn() -> void:
	has_attacked = false
	has_moved_this_turn = false
	attacks_this_turn = 0
	just_played = false
	drawn_this_turn = false
	clear_stun()
	clear_weakened()
	_update_visuals()


func _on_turn_started(turn_player_id: int) -> void:
	if turn_player_id == owner_id:
		just_played = false
			# Echo cards disappear at end of turn
	if echo_card:
		print("[Minion] Echo copy %s disappears!" % card_data.card_name)
		# This would be handled in hand, not on board
		if sleeping_icon:
			sleeping_icon.visible = false
		_update_can_attack_visual()


## =============================================================================
## INPUT HANDLING
## =============================================================================

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			minion_clicked.emit(self)
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _is_dragging:
				_is_dragging = false
				minion_drag_ended.emit(self, get_global_mouse_position())


func set_targetable(targetable: bool) -> void:
	is_targetable = targetable
	# Visual feedback for targetable state
	if highlight:
		if targetable:
			highlight.modulate = Color(1.0, 0.3, 0.3, 0.5)  # Red tint for enemy targets
		else:
			highlight.modulate = Color(0.3, 1.0, 0.3, 0.5)  # Green for friendly


## =============================================================================
## HUDDLE SUPPORT
## =============================================================================

func set_huddled_minion(m: Node) -> void:
	huddled_minion = m
	_update_visuals()


func promote_huddled_minion() -> Node:
	"""When this minion dies, promote the huddled minion to take its place"""
	if huddled_minion and is_instance_valid(huddled_minion):
		var promoted := huddled_minion
		huddled_minion = null
		promoted.is_front_row = is_front_row
		promoted.lane_index = lane_index
		print("[Minion] Promoted huddled minion: %s" % promoted.card_data.card_name)
		return promoted
	return null


## =============================================================================
## HELPER FOR MINION IDENTIFICATION
## =============================================================================

func is_minion() -> bool:
	return true
