## Rejection Feedback (match-ui U5; interaction-patterns Rejection Feedback; targeting.md
## §6 "Rejected"): the originating control shakes, a `reject.<code>` tooltip shows at the
## cursor or above the source, and the related control flashes. It runs from the
## projected `reject_shake` step, and nothing else on the table changes: nothing happened.
##
## `MatchView` says where the command came from before it submits. The related control is
## `reject_flash` in `match_ui.json`, code to target, and a flash call per target.
## [codeblock]
## reject.set_origin(token, get_global_mouse_position())
## reject.set_flash_targets({"taunts": flash_taunts, "mana_bar": flash_mana})
## [/codeblock]
class_name RejectPresenter
extends Presenter

const SHAKE_STEPS: int = 4
const KEY_FORMAT: String = "reject.%s"
const DETAIL_FORMAT: String = "reject.%s.detail"
const MISSING_FORMAT: String = "??%s"

## Keeps the tooltip and flash up: `--pose=reject:<code>` freezes them for a capture.
var frozen: bool = false
## `reject_shake` becomes the outline flash alone (match-ui story 023 owns the variant).
var reduce_motion: bool = false

var _cfg: Dictionary = {}
var _tooltip: UiTooltip = null
var _origin: Control = null
var _anchor: Vector2 = Vector2.ZERO
# Target name to `func(on: bool)`.
var _flash_targets: Dictionary = {}
var _flashing: Callable = Callable()
# What the coming rejection's detail copy fills in; `{}` for its plain copy.
var _detail: Dictionary = {}
var _outline: Panel = null
var _hide: Tween = null
var _done: Dictionary = {}
# Where the origin rests while it shakes.
var _rest_at: Variant = null


## Builds the tooltip.
func setup(context: MatchUiContext) -> void:
	super(context)
	_cfg = ui.config.reject
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip = UiTooltip.new()
	add_child(_tooltip)
	_tooltip.configure(ui.color("parchment"), ui.color("text_ink"), int(_cfg.font_px), float(_cfg.max_w), ui.rect("viewport"))
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = ui.color("state_danger")
	ring.set_border_width_all(int(_cfg.source_flash_px))
	_outline = Panel.new()
	_outline.add_theme_stylebox_override("panel", ring)
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.top_level = true
	_outline.visible = false
	add_child(_outline)


func bind(_view_state: MatchViewState) -> void:
	return


func owns(_entity_ids: Array[int]) -> bool:
	return false


## `reject_shake` names no entity.
func claims(step: AnimStep) -> bool:
	return step.kind == AnimStep.REJECT_SHAKE


func on_step_started(step: AnimStep, d_eff: float) -> void:
	_begin(step, d_eff)


## At `instant` no step starts, and the reason still shows: it is the only text.
func apply_final(step: AnimStep) -> void:
	_begin(step, 0.0)
	_done.erase(step)
	end_step(step)
	_rest()


func sync_report() -> Array[String]:
	return []


## Where the next rejection points: [param origin] shakes, or null for no control, and
## the tooltip sits at [param anchor].
func set_origin(origin: Control, anchor: Vector2) -> void:
	_origin = origin
	_anchor = anchor


## `{cost, mana}` of the command about to be sent, for `reject.<code>.detail`; `{}` when
## it has no price. Rejections only race on this (targeting.md §12).
func set_detail(detail: Dictionary) -> void:
	_detail = detail


## The outline flash that stands in for the shake, and the danger colour it holds.
func restyle() -> void:
	(_outline.get_theme_stylebox("panel") as StyleBoxFlat).border_color = ui.color("state_danger")


## `{target name: func(on: bool)}`, one per `reject_flash` value.
func set_flash_targets(targets: Dictionary) -> void:
	_flash_targets = targets


func _begin(step: AnimStep, d_eff: float) -> void:
	if _done.has(step):
		return
	_done[step] = true
	var code: String = str(step.data.get("code", ""))
	_show_reason(code)
	_flash(code)
	if reduce_motion:
		_flash_source()
	elif d_eff > 0.0 and is_instance_valid(_origin):
		_shake(step, d_eff)


func _show_reason(code: String) -> void:
	var key: String = KEY_FORMAT % code
	var text: String = tr(key)
	if text == key:
		push_warning("RejectPresenter: no copy for %s" % key)
		text = MISSING_FORMAT % key
	var detail_key: String = DETAIL_FORMAT % code
	if not _detail.is_empty() and tr(detail_key) != detail_key:
		text = tr(detail_key).format(_detail)
	_detail = {}
	_tooltip.show_above(_anchor, text)
	if _hide != null:
		_hide.kill()
		_hide = null
	if not frozen:
		_hide = create_tween()
		_hide.tween_interval(float(ui.config.rejection_tooltip_s))
		_hide.tween_callback(_tooltip.hide_now)


# targeting.md §6: under `reduce_motion` the source's outline flashes for two frames.
func _flash_source() -> void:
	if not is_instance_valid(_origin):
		return
	var rect: Rect2 = _origin.get_global_rect()
	_outline.position = rect.position
	_outline.size = rect.size
	_outline.visible = true
	if not frozen:
		var off: Tween = create_tween()
		off.tween_interval(float(_cfg.source_flash_s))
		off.tween_callback(_outline.hide)


func _flash(code: String) -> void:
	var target: String = str((_cfg.flash as Dictionary).get(code, ""))
	if not _flash_targets.has(target):
		return
	_flashing = _flash_targets[target]
	_flashing.call(true)
	if not frozen:
		var off: Tween = create_tween()
		off.tween_interval(float(_cfg.flash_s))
		off.tween_callback(_flashing.bind(false))


func _shake(step: AnimStep, d_eff: float) -> void:
	var property: String = "offset_transform_position" if _origin is MinionToken else "position"
	var rest: Vector2 = _origin.get(property)
	var push := Vector2(float(_cfg.shake_px), 0)
	var shake: Tween = step_tween(step)
	for i: int in SHAKE_STEPS:
		shake.tween_property(_origin, property, rest + (push if i % 2 == 0 else -push), d_eff / float(SHAKE_STEPS + 1))
	shake.tween_property(_origin, property, rest, d_eff / float(SHAKE_STEPS + 1))
	_rest_at = rest



# A skipped shake leaves the control where it started.
func _rest() -> void:
	if _rest_at != null and is_instance_valid(_origin):
		_origin.set("offset_transform_position" if _origin is MinionToken else "position", _rest_at)
	_rest_at = null
