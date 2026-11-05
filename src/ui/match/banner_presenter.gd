## The end banner (ADR-0009 `banner.tscn`; match-ui U9; match-end.md); the turn and
## intent banners are story 015's. The `end_banner` step opens it, and [method settle]
## starts its clock once the queue has drained. Input is swallowed for
## `end_turn_arm_ms`; then a fresh press or `MATCH_END_AUTO_S` continues, once.
## `MATCH_END_AUTO_S` is reading time, so `anim_speed` never divides it.
##
## Copy is `end.<variant>`, the variant read from `result` and `reason` (match-end.md
## §6). A `fault` is not a defeat: neutral frame, no stinger, no saturation.
## [codeblock]
## banner.continued.connect(_finish)
## banner.settle()
## # MatchView._process(delta):
## banner.tick(delta)
## [/codeblock]
class_name BannerPresenter
extends Presenter

## The player continued, or the clock ran out. Emitted once.
signal continued()

const VARIANT_VICTORY: String = "victory"
const VARIANT_DEFEAT: String = "defeat"
const VARIANT_BOTH_DEAD: String = "both_dead"
const VARIANT_CONCEDE: String = "concede"
const VARIANT_TURN_CAP: String = "turn_cap"
const VARIANT_FAULT: String = "fault"
const TITLE_FONT_PX: int = 28
const LINE_FONT_PX: int = 16
const TITLE_Y: float = 32.0
const LINE_Y: float = 76.0
const FACTS_Y: float = 104.0
const TEXT_MARGIN_PX: float = 16.0
const ENTER_SCALE: float = 0.95
const BORDER_PX: int = 2
const MS_PER_S: float = 1000.0

var _view: MatchViewState = null
var _panel: Panel = null
var _style: StyleBoxFlat = null
var _title: Label = null
var _line: Label = null
var _facts: Label = null
var _continue: Button = null
var _boss_name_key: String = ""
var _variant: String = ""
var _shown: bool = false
var _settled: bool = false
var _finished: bool = false
var _elapsed_s: float = 0.0
var _arm_s: float = 0.0
var _auto_s: float = 0.0


## Builds the banner at its F6 rect, hidden.
func setup(context: MatchUiContext) -> void:
	super(context)
	_arm_s = float(ui.config.end_turn_arm_ms) / MS_PER_S
	_auto_s = float(ui.config.match_end_auto_s)
	var rect: Rect2 = ui.rect("end_banner")
	_style = StyleBoxFlat.new()
	_style.bg_color = ui.color("table_dark")
	_style.set_corner_radius_all(4)
	_style.set_border_width_all(BORDER_PX)
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", _style)
	_panel.position = rect.position
	_panel.size = rect.size
	_panel.pivot_offset = rect.size / 2.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	_title = _label(TITLE_Y, TITLE_FONT_PX, "text_light", rect.size.x)
	_line = _label(LINE_Y, LINE_FONT_PX, "text_light", rect.size.x)
	_facts = _label(FACTS_Y, LINE_FONT_PX, "text_muted", rect.size.x)
	var cfg: Dictionary = ui.config.end_screen
	_continue = Button.new()
	_continue.size = Vector2(float(cfg.continue_w), float(cfg.continue_h))
	_continue.position = Vector2((rect.size.x - _continue.size.x) / 2.0, float(cfg.continue_y) - rect.position.y)
	_continue.focus_mode = Control.FOCUS_NONE
	_continue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue.disabled = true
	_continue.add_theme_color_override("font_disabled_color", ui.color("text_muted"))
	_continue.add_theme_color_override("font_color", ui.color("text_light"))
	_panel.add_child(_continue)


## Stores the projection [method sync_report] compares against.
func bind(view_state: MatchViewState) -> void:
	_view = view_state


## The name `{boss}` resolves through (match-ui U10), from the `MatchConfig`.
func set_boss(boss_def_id: String) -> void:
	_boss_name_key = MatchStrings.BOSS_NAME_KEY % boss_def_id


func owns(_entity_ids: Array[int]) -> bool:
	return false


func claims(step: AnimStep) -> bool:
	return step.kind == AnimStep.END_BANNER


func on_step_started(step: AnimStep, d_eff: float) -> void:
	_open(step.data.get("display", {}).get("result"))
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * ENTER_SCALE
	var enter: Tween = step_tween(step).set_parallel()
	enter.tween_property(_panel, "modulate:a", 1.0, d_eff)
	enter.tween_property(_panel, "scale", Vector2.ONE, d_eff)


func apply_final(step: AnimStep) -> void:
	end_step(step)
	_open(step.data.get("display", {}).get("result"))
	_panel.modulate.a = 1.0
	_panel.scale = Vector2.ONE


func on_skipped() -> void:
	super()
	if _shown:
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE


func sync_report() -> Array[String]:
	var report: Array[String] = []
	if _view.result != null and not _shown:
		report.append("end banner: not shown, view-state has a result")
	return report


## `MatchResult` → the `end.<variant>` key (match-end.md §6).
static func variant_of(result: Dictionary) -> String:
	var reason: String = str(result.get("reason", ""))
	if str(result.get("result", "")) == MatchRecords.RESULT_FAULT:
		return VARIANT_FAULT
	match reason:
		MatchRecords.REASON_BOTH_DEAD:
			return VARIANT_BOTH_DEAD
		MatchRecords.REASON_CONCEDE:
			return VARIANT_CONCEDE
		MatchRecords.REASON_TURN_CAP:
			return VARIANT_TURN_CAP
	return VARIANT_VICTORY if str(result.get("result", "")) == MatchRecords.RESULT_WIN else VARIANT_DEFEAT


## The variant shown, or `""`.
func variant() -> String:
	return _variant


## True once the banner is up.
func is_shown() -> bool:
	return _shown


## The queue drained: the arm guard and the countdown start.
func settle() -> void:
	_settled = true
	_elapsed_s = 0.0
	_refresh_continue()


## Advances the banner's clock; `MatchView._process` drives it, so a test can too.
func tick(delta: float) -> void:
	if not _settled or _finished:
		return
	_elapsed_s += delta
	_refresh_continue()
	if _elapsed_s >= _auto_s:
		_finish()


## An LMB press, or `Enter` / `Space` that is not an echo. Before the guard arms it is
## swallowed, so a skip burst from the boss turn cannot dismiss the banner.
func press_continue() -> void:
	if _settled and not _finished and _elapsed_s >= _arm_s:
		_finish()


func _finish() -> void:
	_finished = true
	continued.emit()


func _open(result: Variant) -> void:
	if _shown or not result is Dictionary:
		return
	_shown = true
	var data: Dictionary = result
	_variant = variant_of(data)
	var fault: bool = _variant == VARIANT_FAULT
	var boss: String = tr(_boss_name_key)
	_title.text = tr("end.%s.title" % _variant)
	_line.text = tr("end.%s.line" % _variant).format({"boss": boss})
	_style.border_color = ui.color("text_muted") if fault else ui.color("state_actionable")
	var health: Dictionary = data.get("final_health", {})
	var turns: int = int(data.get("turns", 0))
	if fault:
		_facts.text = tr("end.fault_detail").format({"reason": str(data.get("reason", "")), "turns": turns})
	elif turns > 0:
		_facts.text = tr("end.facts").format({
			"turns": turns, "boss": boss,
			"hero_hp": int(health.get(MatchRecords.SIDE_PLAYER, 0)), "boss_hp": int(health.get(MatchRecords.SIDE_BOSS, 0)),
		})
	_refresh_continue()
	_panel.visible = true


func _refresh_continue() -> void:
	var left: int = ceili(maxf(_auto_s - _elapsed_s, 0.0))
	_continue.text = tr("end.continue") % left
	_continue.disabled = not _settled or _elapsed_s < _arm_s


func _label(top: float, font_px: int, token: String, width: float) -> Label:
	var label := Label.new()
	label.position = Vector2(TEXT_MARGIN_PX, top)
	label.size = Vector2(width - TEXT_MARGIN_PX * 2.0, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_px)
	label.add_theme_color_override("font_color", ui.color(token))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(label)
	return label
