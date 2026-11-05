## The boss's half of the banners (ADR-0009 `BannerPresenter` row; match-ui U6, U3; hud.md
## §4.2): the intent plate, its reticle, the turn banner, the "boss discovers…" label and
## the skip hint. `BannerPresenter` keeps the end banner.
##
## The plate renders exactly the `effective_mode` Boss AI emitted (DD-X03): `full` icon,
## label, amount and reticle; `class_only` icon and label; `hidden` a "?" plate. `hidden`
## has no `ai_intent_shown` (C8.4), so a match with no intent yet and no plan under way
## reads as hidden too.
##
## The commit beat brightens the plate from the turn banner to the `ai_intent_committed`
## step (U6.2, DD-X23); past the cap the queue's `boss_thinking_changed` swaps the label.
## `kept: false` shows "Plan changed" for `plan_changed_s`, then the new intent. A skip
## ends every transient and leaves the plate at its view-state final (U6.4).
## [codeblock]
## banner.configure(plan_changed_s)
## queue.boss_thinking_changed.connect(banner.set_thinking)
## # MatchView._process(delta):
## banner.tick(delta, not queue.is_idle(), controller.is_planning())
## [/codeblock]
class_name IntentBanner
extends Presenter

const KEY_LABEL: String = "intent.%s"
const KEY_LONG: String = "intent.%s.long"
const KEY_LETHAL: String = "lethal"
const KEY_PLAN_CHANGED: String = "intent.plan_changed"
const KEY_THINKING: String = "intent.thinking"
const MODE_FULL: String = "full"
const MODE_HIDDEN: String = "hidden"
const TOOLTIP_H: float = 56.0
const TOOLTIP_GAP: float = 4.0
const LABEL_MARGIN_PX: float = 6.0
const HINT_FONT_PX: int = 13
const PULSE_SCALE: float = 1.06

var _view: MatchViewState = null
var _cfg: Dictionary = {}
var _plan_changed_s: float = 0.0
var _plate: Panel = null
var _plate_style: StyleBoxFlat = null
var _icon: Label = null
var _label: Label = null
var _amount: Label = null
var _reticle: Panel = null
var _tooltip: Panel = null
var _tooltip_text: Label = null
var _turn_plate: Panel = null
var _turn_style: StyleBoxFlat = null
var _turn_text: Label = null
var _discovers: Label = null
var _hint: Label = null
var _hint_tween: Tween = null
# The intent and turn of the last display.
var _intent: Variant = null
var _turn: int = 0
var _bright: bool = false
var _thinking: bool = false
var _planning: bool = false
var _plan_left_s: float = 0.0
var _busy_s: float = 0.0
var _hint_on: bool = false
var _skipping: bool = false


## Builds every part at its rect, hidden.
func setup(context: MatchUiContext) -> void:
	super(context)
	_cfg = ui.config.intent
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_plate()
	_build_turn_banner()
	var font_px: int = int(_cfg.font_px)
	_discovers = _text(ui.rect("boss_portrait"), font_px, "text_light", self)
	_discovers.text = tr("hud.boss_discovers")
	_discovers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_discovers.autowrap_mode = TextServer.AUTOWRAP_WORD
	_discovers.visible = false
	_hint = _text(ui.rect("skip_hint"), HINT_FONT_PX, "text_muted", self)
	_hint.text = tr("hud.skip_hint")
	_hint.modulate.a = 0.0


## Stores the projection [method sync_report] compares against.
func bind(view_state: MatchViewState) -> void:
	_view = view_state


## Boss AI's `plan_changed_s`, read by `MatchView` with the rest of its data.
func configure(plan_changed_s: float) -> void:
	_plan_changed_s = plan_changed_s


## Frames the turn banner in the band colour of [param boss_def_id].
func set_boss(boss_def_id: String) -> void:
	_turn_style.border_color = ui.boss_identity(boss_def_id).primary


## The queue's `boss_thinking_changed` (U6.2).
func set_thinking(on: bool) -> void:
	_thinking = on
	_render()


func owns(_entity_ids: Array[int]) -> bool:
	return false


func claims(step: AnimStep) -> bool:
	return step.kind in [AnimStep.TURN_BANNER, AnimStep.INTENT_SHOW, AnimStep.INTENT_COMMIT, AnimStep.BOSS_DISCOVERS]


func on_step_started(step: AnimStep, d_eff: float) -> void:
	match step.kind:
		AnimStep.TURN_BANNER:
			_bright = true
			_render()
			_turn_text.text = tr("hud.turn_banner") % int(step.data.get("display", {}).get("turn", _turn))
			_turn_plate.visible = true
			_turn_plate.modulate.a = 1.0
			step_tween(step).tween_property(_turn_plate, "modulate:a", 0.0, d_eff)
		AnimStep.INTENT_SHOW:
			_intent = step.data.get("display", {}).get("intent", _intent)
			_render()
			_plate.modulate.a = 0.0
			step_tween(step).tween_property(_plate, "modulate:a", 1.0, d_eff)
			_pulse_if_lethal(step, d_eff)
		AnimStep.BOSS_DISCOVERS:
			_discovers.visible = true


func apply_final(step: AnimStep) -> void:
	end_step(step)
	match step.kind:
		AnimStep.TURN_BANNER:
			_turn_plate.visible = false
		AnimStep.INTENT_SHOW:
			_plate.modulate.a = 1.0
			_plate.scale = Vector2.ONE
		AnimStep.INTENT_COMMIT:
			_bright = false
			var committed: Variant = step.data.get("display", {}).get("intent")
			var kept: bool = not committed is Dictionary or (committed as Dictionary).get("kept", true) != false
			_plan_left_s = 0.0 if kept else _plan_changed_s
		AnimStep.BOSS_DISCOVERS:
			_discovers.visible = false


func on_skipped() -> void:
	super()
	_skipping = true
	_turn_plate.visible = false
	_discovers.visible = false
	_plate.modulate.a = 1.0
	_plate.scale = Vector2.ONE


func on_drained() -> void:
	_bright = false
	if _skipping:
		_skipping = false
		_plan_left_s = 0.0
	_render()


func present(state: Dictionary) -> void:
	_intent = state.get("intent")
	_turn = int(state.get("turn", 0))
	_render()


func sync_report() -> Array[String]:
	var report: Array[String] = []
	if _intent != _view.intent:
		report.append("intent: shows %s, view-state %s" % [str(_intent), str(_view.intent)])
	return report


## True while the "?" plate is up, for tests.
func is_hidden_plate() -> bool:
	return _plate.visible and _icon.text == str(_cfg.hidden_glyph)


## The label on the plate now, for tests.
func label_text() -> String:
	return _label.text


## Advances the transients: [param busy] is a queue with steps left (the skip hint's
## 1 s), [param planning] a planner under way (no "?" while a forecast is on its way).
func tick(delta: float, busy: bool, planning: bool) -> void:
	if planning != _planning:
		_planning = planning
		_render()
	if _plan_left_s > 0.0:
		_plan_left_s = maxf(_plan_left_s - delta, 0.0)
		if _plan_left_s == 0.0:
			_render()
	_busy_s = _busy_s + delta if busy else 0.0
	_set_hint(busy and _busy_s >= float(ui.config.skip_hint.delay_s))
	if _reticle.visible:
		_reticle.position = ui.locate.call(int(_intent.target_id)) - _reticle.size / 2.0


func _build_plate() -> void:
	var rect: Rect2 = ui.rect("intent_banner")
	var font_px: int = int(_cfg.font_px)
	var icon_w: float = float(_cfg.icon_w)
	_plate_style = StyleBoxFlat.new()
	_plate_style.bg_color = ui.color("table_dark")
	_plate_style.set_corner_radius_all(4)
	_plate = Panel.new()
	_plate.position = rect.position
	_plate.size = rect.size
	_plate.pivot_offset = rect.size / 2.0
	_plate.add_theme_stylebox_override("panel", _plate_style)
	# PASS, not STOP: a click on the plate is still a skip.
	_plate.mouse_filter = Control.MOUSE_FILTER_PASS
	_plate.mouse_entered.connect(_show_tooltip.bind(true))
	_plate.mouse_exited.connect(_show_tooltip.bind(false))
	_plate.visible = false
	add_child(_plate)
	_icon = _text(Rect2(0, 0, icon_w, rect.size.y), font_px, "text_light", _plate)
	_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var label_w: float = rect.size.x - icon_w * 2.0
	_label = _text(Rect2(icon_w, 0, label_w, rect.size.y), font_px, "text_light", _plate)
	_label.clip_text = true
	_amount = _text(Rect2(rect.size.x - icon_w, 0, icon_w - LABEL_MARGIN_PX, rect.size.y), font_px, "text_light", _plate)
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var ring := StyleBoxFlat.new()
	var reticle_px: float = float(_cfg.reticle_px)
	ring.draw_center = false
	ring.border_color = ui.color("state_target")
	ring.set_border_width_all(int(ui.config.targeting.ring_px))
	ring.set_corner_radius_all(int(reticle_px))
	_reticle = Panel.new()
	_reticle.size = Vector2.ONE * reticle_px
	_reticle.add_theme_stylebox_override("panel", ring)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.visible = false
	add_child(_reticle)
	var tip := StyleBoxFlat.new()
	tip.bg_color = ui.color("parchment")
	tip.set_corner_radius_all(4)
	_tooltip = Panel.new()
	_tooltip.position = rect.position + Vector2(0, rect.size.y + TOOLTIP_GAP)
	_tooltip.size = Vector2(rect.size.x, TOOLTIP_H)
	_tooltip.add_theme_stylebox_override("panel", tip)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	add_child(_tooltip)
	_tooltip_text = _text(Rect2(Vector2.ONE * LABEL_MARGIN_PX, _tooltip.size - Vector2.ONE * LABEL_MARGIN_PX * 2.0), HINT_FONT_PX, "text_ink", _tooltip)
	_tooltip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _build_turn_banner() -> void:
	var rect: Rect2 = ui.rect("turn_banner")
	_turn_style = StyleBoxFlat.new()
	_turn_style.bg_color = ui.color("table_dark")
	_turn_style.set_corner_radius_all(4)
	_turn_style.set_border_width_all(2)
	_turn_plate = Panel.new()
	_turn_plate.position = rect.position
	_turn_plate.size = rect.size
	_turn_plate.add_theme_stylebox_override("panel", _turn_style)
	_turn_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_plate.visible = false
	add_child(_turn_plate)
	_turn_text = _text(Rect2(Vector2.ZERO, rect.size), int(_cfg.font_px), "text_light", _turn_plate)
	_turn_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _text(rect: Rect2, font_px: int, token: String, parent: Control) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_color", ui.color(token))
	parent.add_child(label)
	return label


## One place decides what the plate says, from the display and the transients.
func _render() -> void:
	var has_intent: bool = _intent is Dictionary
	var mode: String = str(_intent.get("effective_mode", MODE_FULL)) if has_intent else MODE_HIDDEN
	var hidden: bool = mode == MODE_HIDDEN
	_plate.visible = _turn > 0 and (has_intent or _thinking or not _planning)
	var key: String = str(_intent.get("intent_key", "")) if has_intent else ""
	var lethal: bool = key == KEY_LETHAL and not hidden
	var amount: Variant = _intent.get("amount") if has_intent and mode == MODE_FULL else null
	var target: Variant = _intent.get("target_id") if has_intent and mode == MODE_FULL else null
	_icon.text = str(_cfg.hidden_glyph) if hidden else str((_cfg.glyphs as Dictionary).get(key, ""))
	_label.text = "" if hidden else tr(KEY_LABEL % key)
	_amount.text = str(int(amount)) if amount != null else ""
	if _plan_left_s > 0.0:
		_label.text = tr(KEY_PLAN_CHANGED)
	elif _thinking:
		_label.text = tr(KEY_THINKING)
	var danger: bool = lethal and _plan_left_s == 0.0
	_plate_style.bg_color = ui.color("ink" if danger else "table_dark")
	_label.add_theme_color_override("font_color", ui.color("state_danger" if danger else "text_light"))
	_plate.self_modulate = Color.WHITE * float(_cfg.beat_bright) if _bright else Color.WHITE
	_reticle.visible = target != null and _plate.visible and _plan_left_s == 0.0 and ui.locate.is_valid()


## `lethal` pulses once, and is static under `reduce_motion` (hud.md §4.2).
func _pulse_if_lethal(step: AnimStep, d_eff: float) -> void:
	if ui.reduce_motion or not _intent is Dictionary or str(_intent.get("intent_key", "")) != KEY_LETHAL:
		return
	var pulse: Tween = step_tween(step)
	pulse.tween_property(_plate, "scale", Vector2.ONE * PULSE_SCALE, d_eff / 2.0)
	pulse.tween_property(_plate, "scale", Vector2.ONE, d_eff / 2.0)


func _show_tooltip(on: bool) -> void:
	var known: bool = _intent is Dictionary and str(_intent.get("effective_mode", MODE_HIDDEN)) != MODE_HIDDEN
	_tooltip.visible = on and known
	if _tooltip.visible:
		var amount: Variant = _intent.get("amount")
		_tooltip_text.text = tr(KEY_LONG % str(_intent.intent_key)).format({"amount": int(amount) if amount != null else 0})


## hud.md §4.2: fade 120 ms in, 80 ms out.
func _set_hint(on: bool) -> void:
	if on == _hint_on:
		return
	_hint_on = on
	if _hint_tween != null:
		_hint_tween.kill()
	var cfg: Dictionary = ui.config.skip_hint
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 1.0 if on else 0.0, float(cfg.fade_in_s if on else cfg.fade_out_s))
