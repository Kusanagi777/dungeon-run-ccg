## One side's hero panel (ADR-0009 `hero_panel.tscn` ×2; match-ui F6, U3, U5; hud.md
## §4.2): portrait, health and armour stamps, deck pile, and for the player the hero
## power, weapon slot and mana bar, for the boss the hand count, compact mana counter
## and passive plate. Number pops are children spawned per step and freed at its
## `apply_final`. Numbers come from the display only; [method set_power_state] and the
## other setters carry legality, read at `Idle`, which is never a number.
class_name HeroPresenter
extends Presenter

const SIDE_PLAYER: StringName = &"player"
const SIDE_BOSS: StringName = &"boss"
const POWER_INITIAL_CHARS: int = 1
## Portrait fill while nobody has won: the identification colour one step toward the
## table (match-end.md §6 ramps from this to the primary).
const PORTRAIT_DIM: float = 0.3
const PORTRAIT_FONT_PX: int = 24
const STAMP_FONT_PX: int = 24
const COUNT_FONT_PX: int = 16
const SMALL_FONT_PX: int = 14
const STAMP_INSET_PX: float = 4.0
const PASSIVE_INSET: Vector2 = Vector2(4, 0)
const FATIGUE_LINE_PX: float = 18.0
const USED_ALPHA: float = 0.5
const BLOCKED_ALPHA: float = 0.5
const USED_GLYPH: String = "✓"
const LETHAL_RAMP_S: float = 0.4
const TOOLTIP_SIZE: Vector2 = Vector2(260, 96)
const TOOLTIP_GAP: float = 8.0
## hud.md §4.2: the pile is a 0.5x card.
const BURN_CARD_SCALE: float = 0.5
const CARD_FRAME_SCENE: PackedScene = preload("res://src/ui/common/card_frame.tscn")
const TOOLTIP_PADDING: Vector2 = Vector2(16, 12)
## The passive plate holds three 12 px lines only when they are set tight.
const PASSIVE_LINE_SPACING: int = -3
## The empty weapon slot's watermark.
const SLOT_GLYPH_ALPHA: float = 0.24
const SLOT_GLYPH_INSET_PX: float = 12.0
const POWER_ART_INSET_PX: float = 6.0
## The pile: a second card edge showing under the top one.
const PILE_OFFSET: Vector2 = Vector2(3, 3)

## Which side's panel this is; set on the instance in `match_view.tscn`.
@export var side: StringName = SIDE_PLAYER

var _view: MatchViewState = null
var _primary: Color = Color.WHITE
var _power_id: String = ""
var _name_key: String = ""
var _passive_key: String = ""
var _power_state: Dictionary = {}
var _portrait_rect: Rect2 = Rect2()
var _power_rect: Rect2 = Rect2()
var _portrait: Panel = null
var _portrait_art: TextureRect = null
var _portrait_style: StyleBoxFlat = null
var _initial: Label = null
var _health: Label = null
var _armor: Label = null
var _armor_box: Panel = null
var _deck: Label = null
var _fatigue: Label = null
var _power: Panel = null
var _power_style: StyleBoxFlat = null
var _power_glyph: Label = null
var _power_art: TextureRect = null
var _weapon: Panel = null
var _weapon_text: Label = null
var _weapon_slot: TextureRect = null
var _mana_text: Label = null
var _crystals: Array[ColorRect] = []
var _hand_count: Label = null
var _passive: Label = null
var _tooltip: Panel = null
var _tooltip_text: Label = null
var _mana_flash: Panel = null
var _stamp_box: Panel = null
var _passive_box: Panel = null
var _hand_box: Panel = null
# What is on screen now: the fields sync_report compares.
var _shown: Dictionary = {}


## Builds this side's nodes at their F6 rects.
func setup(context: MatchUiContext) -> void:
	super(context)
	var player: bool = side == SIDE_PLAYER
	_portrait_rect = ui.rect("player_portrait" if player else "boss_portrait")
	_portrait_style = _style(ui.color("neutral"), 2, ui.color("ink"))
	_portrait = _panel(_portrait_rect, _portrait_style)
	_portrait_art = TextureRect.new()
	_portrait_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The boss passive plate overlaps the portrait's bottom 48px (F6). Keep the
	# stamp above that plate so the passive stays readable.
	var bottom_clear: float = 52.0 if side == SIDE_BOSS else 8.0
	_portrait_art.position = Vector2(4.0, 4.0)
	_portrait_art.size = Vector2(_portrait_rect.size.x - 8.0, _portrait_rect.size.y - bottom_clear - 4.0)
	_portrait_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_art.visible = false
	_portrait.add_child(_portrait_art)
	_initial = _label(Rect2(Vector2.ZERO, _portrait_rect.size - Vector2(0, 48)), PORTRAIT_FONT_PX, "text_light", _portrait)
	_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var stamp: float = float(ui.config.hero.stamp_size)
	var stamp_rect := Rect2(_stamp_origin(stamp), Vector2(stamp, stamp))
	_stamp_box = _panel(stamp_rect, _round_style(ui.color("ink")), _portrait)
	_health = _label(Rect2(Vector2.ZERO, stamp_rect.size), STAMP_FONT_PX, "text_light", _stamp_box)
	_center(_health)
	UiFonts.apply(_health, UiFonts.WEIGHT_BOLD)
	_armor_box = _panel(Rect2(stamp_rect.position - Vector2(stamp + 4, 0), stamp_rect.size), _round_style(ui.color("ink")), _portrait)
	_armor = _label(Rect2(Vector2.ZERO, stamp_rect.size), COUNT_FONT_PX, "text_light", _armor_box)
	_center(_armor)
	UiFonts.apply(_armor, UiFonts.WEIGHT_BOLD)
	var deck_rect: Rect2 = ui.rect("player_deck" if player else "boss_deck")
	var _under: Panel = _panel(Rect2(deck_rect.position + PILE_OFFSET, deck_rect.size), _style(ui.color("ink"), 1, ui.color("stamp_ring")))
	var deck_box: Panel = _panel(deck_rect, _style(ui.color("ink"), 1, ui.color("stamp_ring")))
	_deck = _label(Rect2(Vector2.ZERO, deck_rect.size), STAMP_FONT_PX, "text_light", deck_box)
	_center(_deck)
	UiFonts.apply(_deck, UiFonts.WEIGHT_BOLD)
	_fatigue = _label(Rect2(deck_rect.position + Vector2(0, deck_rect.size.y), Vector2(deck_rect.size.x, 18)), SMALL_FONT_PX, "state_danger")
	_center(_fatigue)
	_fatigue.autowrap_mode = TextServer.AUTOWRAP_WORD
	if player:
		_build_player_slots()
	else:
		_build_boss_strip()
	var tip_style: StyleBoxFlat = _style(ui.color("parchment"), 2, ui.color("ink"))
	_tooltip = _panel(Rect2(Vector2.ZERO, TOOLTIP_SIZE), tip_style)
	ui.art().lay_parchment(_tooltip, tip_style)
	_tooltip_text = _label(Rect2(Vector2(8, 6), TOOLTIP_SIZE - TOOLTIP_PADDING), SMALL_FONT_PX, "text_ink", _tooltip)
	_tooltip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip.visible = false


## Stores the projection [method sync_report] compares against.
func bind(view_state: MatchViewState) -> void:
	_view = view_state


## The panel's identity, from the `MatchConfig`: `{primary: Color, initial: String,
## power_id: String, passive_key: String}`, every key but `primary` optional.
func set_identity(identity: Dictionary) -> void:
	_primary = identity.get("primary", ui.color("neutral"))
	_portrait_style.bg_color = _primary.lerp(ui.color("table_dark"), PORTRAIT_DIM)
	_initial.text = str(identity.get("initial", ""))
	var group: String = "bosses" if side == SIDE_BOSS else "heroes"
	var stamp: Dictionary = ui.art().portrait(group, str(identity.get("id", "")))
	_portrait_art.visible = not stamp.is_empty()
	_initial.visible = stamp.is_empty()
	if not stamp.is_empty():
		_portrait_art.texture = stamp.texture
		_portrait_art.modulate = stamp.tint
	_power_id = str(identity.get("power_id", ""))
	if _power_art != null:
		var mark: Dictionary = ui.art().power_stamp(_power_id)
		_power_art.texture = mark.get("texture")
		_power_art.modulate = mark.get("tint", Color.WHITE)
		_power_style.bg_color = _primary
		_refresh_power_mark(false)
	_name_key = str(identity.get("name_key", ""))
	_passive_key = str(identity.get("passive_key", ""))
	if _power_glyph != null:
		_power_glyph.text = tr(MatchStrings.POWER_NAME_KEY % _power_id).left(POWER_INITIAL_CHARS)
		_power.visible = _power_id != ""
	if _passive != null:
		_passive.text = tr(str(identity.get("passive_key", "")))


## A burn has a card's id, which no hero owns: it is claimed by side.
func claims(step: AnimStep) -> bool:
	return super(step) or (step.kind == AnimStep.BURN and str(step.data.get("side", "")) == String(side))


func owns(entity_ids: Array[int]) -> bool:
	var ids: Dictionary = _own_ids()
	for id: int in entity_ids:
		if ids.has(id):
			return true
	return false


func on_step_started(step: AnimStep, d_eff: float) -> void:
	match step.kind:
		AnimStep.DAMAGE_POP, AnimStep.HEAL_POP:
			var hero_id: Variant = _view.side(side).hero.entity_id
			for pop: AnimStep in (step.members if not step.members.is_empty() else [step] as Array[AnimStep]):
				if pop.entity_ids.has(int(hero_id)):
					spawn_pop(step, pop, _portrait_rect.get_center(), d_eff)
		AnimStep.ATTACK_LUNGE:
			_lunge(step, d_eff)
		AnimStep.POWER_PRESS, AnimStep.POWER_RELIGHT:
			if _power != null:
				var press: Tween = step_tween(step)
				press.tween_property(_power, "scale", Vector2.ONE * float(ui.config.hero.power_press_scale), d_eff / 2.0)
				press.tween_property(_power, "scale", Vector2.ONE, d_eff / 2.0)
		AnimStep.WEAPON_SHATTER:
			if _weapon != null:
				step_tween(step).tween_property(_weapon, "modulate:a", 0.0, d_eff)
		AnimStep.BURN:
			_show_burn(step, d_eff)


func apply_final(step: AnimStep) -> void:
	end_step(step)
	_rest()


func on_skipped() -> void:
	super()
	_rest()


func present(state: Dictionary) -> void:
	var data: Dictionary = state.get(String(side), {})
	if data.is_empty():
		return
	var hero: Dictionary = data.hero
	_shown = {
		"health": hero.health, "armor": int(hero.armor), "deck_count": int(data.deck_count),
		"fatigue_next": int(data.fatigue_next), "mana": (data.mana as Dictionary).duplicate(),
		"power_state": str(hero.power_state),
		"weapon": (hero.weapon as Dictionary).duplicate() if hero.weapon != null else null,
		"hand": int(data.hand) if data.hand is int else (data.hand as Array).size(),
	}
	_health.text = str(hero.health) if hero.health != null else ""
	_stamp_box.visible = hero.health != null
	_armor_box.visible = int(hero.armor) > 0
	_armor.text = tr("hud.armor") % int(hero.armor)
	_deck.text = str(int(data.deck_count))
	_fatigue.visible = int(data.deck_count) == 0
	_fatigue.text = tr("hud.fatigue_next") % int(data.fatigue_next)
	if side == SIDE_PLAYER:
		_present_player(hero, data.mana)
	else:
		_hand_count.text = tr("hud.hand") % int(_shown.hand)
		_mana_text.text = "%d/%d" % [int(data.mana.available), int(data.mana.max)]


func sync_report() -> Array[String]:
	var report: Array[String] = []
	var data: Dictionary = _view.side(side)
	var hero: Dictionary = data.hero
	_compare(report, "health", _shown.get("health"), hero.health)
	_compare(report, "armor", _shown.get("armor"), int(hero.armor))
	_compare(report, "deck_count", _shown.get("deck_count"), int(data.deck_count))
	_compare(report, "fatigue_next", _shown.get("fatigue_next"), int(data.fatigue_next))
	_compare(report, "mana", _shown.get("mana"), data.mana)
	_compare(report, "power_state", _shown.get("power_state"), str(hero.power_state))
	_compare(report, "weapon", _shown.get("weapon"), hero.weapon)
	return report


## The portrait's rectangle, for hit tests and the arrow.
func portrait_rect() -> Rect2:
	return _portrait_rect


## The hero power's rectangle; an empty one on the boss panel.
func power_rect() -> Rect2:
	return _power_rect if _power != null and _power.visible else Rect2()


## Legality at `Idle`: `hero_power_state(player)`, or `{}` outside `Idle` (U2).
func set_power_state(state: Dictionary) -> void:
	_power_state = state
	if _power == null:
		return
	var lit: bool = str(state.get("state", "")) == MatchQuery.POWER_READY
	_power_style.border_color = ui.color("state_actionable") if lit else ui.color("ink")
	_power.queue_redraw()
	var dim: bool = str(state.get("state", "")) == MatchQuery.POWER_BLOCKED
	_power.modulate.a = BLOCKED_ALPHA if dim else (USED_ALPHA if str(_shown.get("power_state", "")) == MatchViewState.POWER_USED else 1.0)


## The fatigue label and the flash outline hold a state colour from build.
func restyle() -> void:
	_fatigue.add_theme_color_override("font_color", ui.color("state_danger"))
	if _mana_flash != null:
		(_mana_flash.get_theme_stylebox("panel") as StyleBoxFlat).border_color = ui.color("state_danger")


## hud.md §10.2 at [param scale]: the tooltip grows, and from `boss_mana_moves_at` the
## boss's mana leaves the strip for a pill inside the portrait panel.
func set_text_scale(scale: float) -> void:
	_tooltip.size = TOOLTIP_SIZE * scale
	_tooltip_text.size = _tooltip.size - TOOLTIP_PADDING
	_fit_stamps(scale)
	if side == SIDE_BOSS:
		var moved: bool = scale >= float(ui.config.text_scale.boss_mana_moves_at)
		var rect: Rect2 = ui.rect("boss_mana_scaled" if moved else "boss_mana")
		var box: Control = _mana_text.get_parent()
		box.position = rect.position
		box.size = rect.size
		_mana_text.size = rect.size
		var hand: Rect2 = ui.rect("boss_hand_count")
		_hand_box.size.x = hand.size.x + (ui.rect("boss_mana").size.x if moved else 0.0)
		_hand_count.size.x = _hand_box.size.x
		var plate: Rect2 = ui.rect("boss_passive")
		var top: float = float(ui.config.text_scale.passive_top_y) if scale >= float(ui.config.text_scale.full) else plate.position.y
		_passive_box.position.y = top
		_passive_box.size.y = plate.end.y - top
		_passive.size.y = _passive_box.size.y - PASSIVE_INSET.y * 2.0


## The health and armour stamps grow with their numerals, anchored to the portrait's
## corner, and the pile's fatigue label takes its extra lines (hud.md §10.2).
func _fit_stamps(scale: float) -> void:
	var cfg: Dictionary = ui.config.text_scale
	var stamp: float = minf(float(ui.config.hero.stamp_size) * scale, float(cfg.stamp_max_px))
	var at: Vector2 = _stamp_origin(stamp)
	for box: Panel in [_stamp_box, _armor_box]:
		box.size = Vector2.ONE * stamp
		(box.get_child(0) as Control).size = box.size
		(box.get_theme_stylebox("panel") as StyleBoxFlat).set_corner_radius_all(int(stamp))
	_stamp_box.position = at
	_armor_box.position = at - Vector2(stamp + STAMP_INSET_PX, 0)
	var lines: int = 1 if scale <= 1.0 else int(cfg.fatigue_lines)
	_fatigue.size.y = FATIGUE_LINE_PX * scale * lines


# The player's stamps sit on the portrait's bottom corner. The boss's bottom edge is the
# passive plate, which must stay readable, so its stamps sit on the top corner.
func _stamp_origin(stamp: float) -> Vector2:
	var y: float = STAMP_INSET_PX if side == SIDE_BOSS else _portrait_rect.size.y - stamp - STAMP_INSET_PX
	return Vector2(_portrait_rect.size.x - stamp - STAMP_INSET_PX, y)


## Rejection Feedback: the mana bar's outline flashes while [param on].
func flash_mana(on: bool) -> void:
	if _mana_flash != null:
		_mana_flash.visible = on


## The hero power button, for the rejection shake; null on the boss panel.
func power_control() -> Control:
	return _power


## The portrait, for the rejection shake.
func portrait_control() -> Control:
	return _portrait


## The portrait's `state_actionable` outline: the hero can attack (targeting.md §6).
func set_can_attack(on: bool) -> void:
	_set_portrait_border("state_actionable" if on else "ink", on)


## The portrait's `state_target` outline; [param ring] is the 3 px hover ring (U7).
func set_targeted(on: bool, ring: bool = false) -> void:
	var width: int = int(ui.config.targeting.ring_px) if ring else int(ui.config.targeting.outline_px)
	_portrait_style.set_border_width_all(width)
	_portrait_style.border_color = ui.color("state_target") if on else ui.color("ink")
	_portrait.queue_redraw()


## MUI-025: the button lifted 2 px in place while it is dragged (targeting.md §6, Phase T's look).
func set_power_lifted(on: bool) -> void:
	if _power != null:
		_power.position = _power_rect.position - Vector2(0, float(ui.config.hero.power_lift_px) if on else 0.0)


## The portrait lifted 4 px with its outline while it is a dragged attacker.
func set_portrait_lifted(on: bool) -> void:
	_portrait.position = _portrait_rect.position - Vector2(0, float(ui.config.hero.lift_px) if on else 0.0)


## Hover: the hero power's name, cost and text, and the reason when `Blocked` (U5). The
## one `MatchQuery` read here is the hover's own (`hero_power_state`).
func show_power_tooltip(on: bool) -> void:
	_tooltip.visible = on and _power != null and _power_id != ""
	if not _tooltip.visible:
		return
	var state: Dictionary = ui.query.hero_power_state(String(side))
	var lines: PackedStringArray = [tr(MatchStrings.POWER_NAME_KEY % _power_id)]
	lines.append(tr("hud.power.cost") % int(_shown_power_cost()))
	lines.append(tr(MatchStrings.POWER_TEXT_KEY % _power_id))
	if str(state.state) == MatchQuery.POWER_BLOCKED:
		lines.append(tr("reject." + str(state.reason_code)))
	elif str(state.state) == MatchQuery.POWER_USED:
		lines.append(tr("hud.power.used"))
	_tooltip_text.text = "\n".join(lines)
	_tooltip.position = _power_rect.position + Vector2(_power_rect.size.x + TOOLTIP_GAP, 0)


## Focus: name, health, armour, weapon and the boss's passive text (hud.md Focus Order
## stops 4 and 11), from the display.
func show_portrait_tooltip(on: bool) -> void:
	_tooltip.visible = on
	if not on:
		return
	var lines: PackedStringArray = [tr(_name_key)]
	if _shown.get("health") != null:
		lines.append(tr("hud.portrait.health") % int(_shown.health))
	if int(_shown.get("armor", 0)) > 0:
		lines.append(tr("hud.portrait.armor") % int(_shown.armor))
	var weapon: Variant = _shown.get("weapon")
	if weapon != null:
		lines.append(tr("hud.portrait.weapon") % [int(weapon.attack), int(weapon.durability)])
	if _passive_key != "":
		lines.append(tr(_passive_key))
	_tooltip_text.text = "\n".join(lines)
	var left: float = _portrait_rect.position.x - TOOLTIP_SIZE.x - TOOLTIP_GAP
	var right: float = _portrait_rect.end.x + TOOLTIP_GAP
	_tooltip.position = Vector2(right if side == SIDE_PLAYER else left, _portrait_rect.position.y)


## match-end.md §6: the winner's portrait ramps to its identification colour, once.
func saturate(duration_s: float) -> void:
	if duration_s <= 0.0:
		_portrait_style.bg_color = _primary
		_portrait.queue_redraw()
		return
	var ramp: Tween = create_tween()
	ramp.tween_method(func(fill: Color) -> void:
		_portrait_style.bg_color = fill
		_portrait.queue_redraw(), _portrait_style.bg_color, _primary, duration_s)


func _shown_power_cost() -> int:
	var cost: Variant = _view.side(side).hero.power_cost
	return int(cost) if cost != null else ui.power_cost(_power_id)


func _build_player_slots() -> void:
	_power_rect = ui.rect("hero_power")
	_power_style = _style(ui.color("war"), 2, ui.color("ink"))
	_power = _panel(_power_rect, _power_style)
	_power.pivot_offset = _power_rect.size / 2.0
	_power_art = TextureRect.new()
	_power_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_power_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_power_art.position = Vector2.ONE * POWER_ART_INSET_PX
	_power_art.size = _power_rect.size - Vector2.ONE * POWER_ART_INSET_PX * 2.0
	_power.add_child(_power_art)
	_power_glyph = _label(Rect2(Vector2.ZERO, _power_rect.size), 20, "text_light", _power)
	_center(_power_glyph)
	UiFonts.apply(_power_glyph, UiFonts.WEIGHT_BOLD)
	var weapon_rect: Rect2 = ui.rect("weapon_slot")
	_weapon = _panel(weapon_rect, _style(ui.color("ink"), 1, ui.color("stamp_ring")))
	_weapon_slot = TextureRect.new()
	_weapon_slot.texture = ui.art().glyph_texture("attack")
	_weapon_slot.modulate = Color(ui.color("text_light"), SLOT_GLYPH_ALPHA)
	_weapon_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon_slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon_slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon_slot.position = Vector2.ONE * SLOT_GLYPH_INSET_PX
	_weapon_slot.size = weapon_rect.size - Vector2.ONE * SLOT_GLYPH_INSET_PX * 2.0
	_weapon.add_child(_weapon_slot)
	_weapon_text = _label(Rect2(Vector2.ZERO, weapon_rect.size), COUNT_FONT_PX, "text_light", _weapon)
	_center(_weapon_text)
	UiFonts.apply(_weapon_text, UiFonts.WEIGHT_BOLD)
	_mana_text = _label(ui.rect("mana_text"), COUNT_FONT_PX, "text_light")
	_mana_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFonts.apply(_mana_text, UiFonts.WEIGHT_BOLD)
	var flash_style: StyleBoxFlat = _style(Color.TRANSPARENT, int(ui.config.targeting.outline_px), ui.color("state_danger"))
	flash_style.draw_center = false
	_mana_flash = _panel(ui.rect("mana_bar"), flash_style)
	_mana_flash.visible = false
	var row: Rect2 = ui.rect("mana_crystals")
	var px: float = float(ui.config.hero.crystal_px)
	var gap: float = float(ui.config.hero.crystal_gap)
	for i: int in int(ui.config.hero.crystal_count):
		var crystal := ColorRect.new()
		crystal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crystal.position = row.position + Vector2(i * (px + gap), 0)
		crystal.size = Vector2(px, px)
		add_child(crystal)
		_crystals.append(crystal)


func _build_boss_strip() -> void:
	var hand_rect: Rect2 = ui.rect("boss_hand_count")
	var hand_box: Panel = _panel(hand_rect, _style(ui.color("ink"), 0, ui.color("ink")))
	_hand_count = _label(Rect2(Vector2.ZERO, hand_rect.size), SMALL_FONT_PX, "text_light", hand_box)
	_center(_hand_count)
	var mana_rect: Rect2 = ui.rect("boss_mana")
	var mana_box: Panel = _panel(mana_rect, _style(ui.color("ink"), 0, ui.color("ink")))
	_mana_text = _label(Rect2(Vector2.ZERO, mana_rect.size), SMALL_FONT_PX, "text_light", mana_box)
	_center(_mana_text)
	var plate: Rect2 = ui.rect("boss_passive")
	_passive_box = _panel(plate, _style(ui.color("ink"), 0, ui.color("ink")))
	_passive = _label(Rect2(PASSIVE_INSET, plate.size - PASSIVE_INSET * 2.0), 12, "text_light", _passive_box)
	_passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_passive.clip_text = true
	_passive.add_theme_constant_override("line_spacing", PASSIVE_LINE_SPACING)
	_hand_box = hand_box
	# hud.md §4.2: the stamps sit over the plate's corner, and the plate is drawn later.
	_stamp_box.z_index = 1
	_armor_box.z_index = 1


func _present_player(hero: Dictionary, mana: Dictionary) -> void:
	var used: bool = str(hero.power_state) == MatchViewState.POWER_USED
	_power_glyph.text = USED_GLYPH if used else tr(MatchStrings.POWER_NAME_KEY % _power_id).left(POWER_INITIAL_CHARS)
	_refresh_power_mark(used)
	if used:
		_power.modulate.a = USED_ALPHA
	var weapon: Variant = hero.weapon
	_weapon.modulate.a = 1.0
	_weapon_slot.visible = weapon == null
	_weapon_text.text = "%d/%d" % [int(weapon.attack), int(weapon.durability)] if weapon != null else ""
	_mana_text.text = "%d/%d" % [int(mana.available), int(mana.max)]
	var available: int = int(mana.available)
	var temporary: int = int(mana.temporary)
	var full: int = maxi(available - temporary, 0)
	for i: int in _crystals.size():
		var token: String = "bg_edge"
		if i < full:
			token = "mana_stamp"
		elif i < available:
			token = "crystal_temporary"
		elif i < int(mana.max):
			token = "crystal_spent"
		_crystals[i].color = ui.color(token)


# The power's stamp, or its letter when none resolves; the used tick always shows.
func _refresh_power_mark(used: bool) -> void:
	var has_art: bool = _power_art.texture != null
	_power_art.visible = has_art and not used
	_power_glyph.visible = used or not has_art


## hud.md §4.2: the burned card face up over the player's pile, dissolving. A boss burn
## is told by the feed alone.
func _show_burn(step: AnimStep, d_eff: float) -> void:
	var face: Dictionary = ui.card_face(str(step.data.get("card_id", "")))
	if side != SIDE_PLAYER or face.is_empty():
		return
	var card: CardFrame = CARD_FRAME_SCENE.instantiate()
	add_child(card)
	card.configure(ui)
	card.show_card(face, int(face.get("cost", 0)) if face.get("cost") != null else 0)
	card.scale = Vector2.ONE * BURN_CARD_SCALE
	card.position = ui.rect("player_deck").get_center() - CardFrame.SIZE * BURN_CARD_SCALE / 2.0
	keep_for_step(step, card)
	step_tween(step).tween_property(card, "modulate:a", 0.0, d_eff)


func _lunge(step: AnimStep, d_eff: float) -> void:
	if step.entity_ids.is_empty() or step.entity_ids.size() < 2 or not _is_hero(step.entity_ids[0]):
		return
	var board: Dictionary = ui.config.board
	var home: Vector2 = _portrait_rect.position
	var aim: Vector2 = ui.locate.call(step.entity_ids[1]) - _portrait_rect.get_center()
	var out_s: float = d_eff * float(board.lunge_out)
	var contact_s: float = d_eff * float(board.lunge_hold)
	var lunge: Tween = step_tween(step)
	lunge.tween_property(_portrait, "position", home + aim * float(board.lunge_reach), out_s)
	lunge.tween_interval(lunge_hold_s(step, d_eff))
	lunge.tween_property(_portrait, "position", home, maxf(d_eff - out_s - contact_s, 0.0))


func _is_hero(id: int) -> bool:
	var hero_id: Variant = _view.side(side).hero.entity_id
	return hero_id != null and int(hero_id) == id


func _rest() -> void:
	_portrait.position = _portrait_rect.position
	if _power != null:
		_power.scale = Vector2.ONE
	if _weapon != null:
		_weapon.modulate.a = 1.0


func _own_ids() -> Dictionary:
	var ids: Dictionary = {}
	var hero: Dictionary = _view.side(side).hero
	if hero.entity_id != null:
		ids[int(hero.entity_id)] = true
	if hero.weapon != null:
		ids[int(hero.weapon.entity_id)] = true
	return ids


func _set_portrait_border(token: String, thick: bool) -> void:
	_portrait_style.set_border_width_all(int(ui.config.targeting.outline_px) if thick else 2)
	_portrait_style.border_color = ui.color(token)
	_portrait.queue_redraw()


func _compare(report: Array[String], field: String, shown: Variant, truth: Variant) -> void:
	if shown != truth:
		report.append("%s %s: shows %s, view-state %s" % [side, field, str(shown), str(truth)])


func _style(fill: Color, border: int, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(border)
	style.border_color = border_color
	style.set_corner_radius_all(4)
	return style


func _round_style(fill: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = _style(fill, 2, ui.color("stamp_ring"))
	style.set_corner_radius_all(int(ui.config.hero.stamp_size))
	return style


func _panel(rect: Rect2, style: StyleBoxFlat, parent: Control = self) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _label(rect: Rect2, font_px: int, token: String, parent: Control = self) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_color", ui.color(token))
	parent.add_child(label)
	return label


func _center(label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
