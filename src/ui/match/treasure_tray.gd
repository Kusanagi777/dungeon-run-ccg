## The treasure tray (match-ui F6, U5; interaction-patterns Treasure Chip; story 021): one
## 40x40 chip per held treasure, in pick order, on a 44x44 hit rect. Hidden when none is
## held. A chip's tooltip opens on hover or focus, so nothing is hover-only, and a
## hook-hosted `effect_resolved` flares its chip for one step. The ids come from the
## `MatchConfig`; rarity is a word in the tooltip, never the frame colour alone.
## [codeblock]
## tray.set_treasures(["treasure_worn_signet", "treasure_hollow_crown"])
## tray.show_tooltip(1)
## [/codeblock]
class_name TreasureTray
extends Presenter

const NO_CHIP: int = -1

var _cfg: Dictionary = {}
var _ids: Array[String] = []
var _chips: Array[Control] = []
var _tooltip: UiTooltip = null
var _flaring: Dictionary = {}
var _hover_wait: Tween = null


## Builds the tooltip.
func setup(context: MatchUiContext) -> void:
	super(context)
	_cfg = ui.config.treasure
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip = UiTooltip.new()
	add_child(_tooltip)
	_tooltip.configure(ui.color("parchment"), ui.color("text_ink"), int(_cfg.tooltip_font_px), float(_cfg.tooltip_max_w), ui.rect("viewport"))


func bind(_view_state: MatchViewState) -> void:
	return


func owns(_entity_ids: Array[int]) -> bool:
	return false


## A flare names a host, never an entity.
func claims(step: AnimStep) -> bool:
	return step.kind == AnimStep.TREASURE_FLARE


func on_step_started(step: AnimStep, _d_eff: float) -> void:
	_flaring[str(step.data.get("host_id", ""))] = true
	queue_redraw()


func apply_final(step: AnimStep) -> void:
	end_step(step)
	_flaring.erase(str(step.data.get("host_id", "")))
	queue_redraw()


func sync_report() -> Array[String]:
	return []


## Shows [param ids] in pick order; none hides the tray.
func set_treasures(ids: Array) -> void:
	for chip: Control in _chips:
		chip.queue_free()
	_chips.clear()
	_ids.clear()
	for id: Variant in ids:
		_ids.append(str(id))
	for i: int in _ids.size():
		var chip := Control.new()
		var rect: Rect2 = hit_rect(i)
		chip.position = rect.position
		chip.size = rect.size
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.mouse_entered.connect(_on_chip_entered.bind(i))
		chip.mouse_exited.connect(_on_chip_exited)
		add_child(chip)
		_chips.append(chip)
	queue_redraw()


## How many chips show.
func count() -> int:
	return _ids.size()


## Chip [param index]'s 44x44 hit rect, centred on its visual.
func hit_rect(index: int) -> Rect2:
	var hit: float = float(_cfg.hit_px)
	return Rect2(_visual_rect(index).get_center() - Vector2(hit, hit) / 2.0, Vector2(hit, hit))


## Opens chip [param index]'s tooltip now, or closes it for [constant NO_CHIP]: focus
## has no delay (interaction-patterns Tooltip "Focus trigger").
func show_tooltip(index: int) -> void:
	if index < 0 or index >= _ids.size():
		_tooltip.hide_now()
		return
	_tooltip.show_above(hit_rect(index).get_center() - Vector2(0, float(_cfg.hit_px) / 2.0), _tooltip_text(_ids[index]))


func _draw() -> void:
	for i: int in _ids.size():
		var face: Dictionary = ui.treasure_face(_ids[i])
		var rect: Rect2 = _visual_rect(i)
		draw_rect(rect, ui.color("ink"))
		draw_rect(rect, ui.color(str((_cfg.rarity_frame as Dictionary).get(str(face.get("rarity", "")), "neutral"))), false, float(ui.config.targeting.outline_px))
		var font: Font = get_theme_default_font()
		var px: int = int(_cfg.glyph_font_px)
		var baseline: Vector2 = rect.position + Vector2(0, (rect.size.y + font.get_ascent(px) - font.get_descent(px)) / 2.0)
		draw_string(font, baseline, tr(str(face.get("name_key", ""))).left(1), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, px, ui.color("text_light"))
		if _flaring.has(_ids[i]):
			draw_rect(rect.grow(float(_cfg.flare_grow_px)), ui.color("state_actionable"), false, float(ui.config.targeting.ring_px))


func _visual_rect(index: int) -> Rect2:
	var tray: Rect2 = ui.rect("treasure_tray")
	var chip: float = float(_cfg.chip_px)
	return Rect2(tray.position + Vector2(index * float(_cfg.pitch_px), 0), Vector2(chip, chip))


func _tooltip_text(id: String) -> String:
	var face: Dictionary = ui.treasure_face(id)
	var lines: PackedStringArray = [tr(str(face.get("name_key", ""))), tr("treasure.rarity.%s" % str(face.get("rarity", ""))), tr(str(face.get("text_key", "")))]
	var tags: PackedStringArray = []
	for tag: Variant in face.get("tags", []):
		tags.append(str(tag))
	if not tags.is_empty():
		lines.append(" · ".join(tags))
	return "\n".join(lines)


func _on_chip_entered(index: int) -> void:
	_stop_wait()
	_hover_wait = create_tween()
	_hover_wait.tween_interval(float(_cfg.hover_delay_s))
	_hover_wait.tween_callback(show_tooltip.bind(index))


func _on_chip_exited() -> void:
	_stop_wait()
	_tooltip.hide_now()


func _stop_wait() -> void:
	if _hover_wait != null:
		_hover_wait.kill()
		_hover_wait = null
