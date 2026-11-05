## The `config("run_ui")` formulas and validator (run-ui F2, F3, F4, Tuning Knobs).
## Pure and static, so a screen, the shell and a test read the same arithmetic; no
## tuning value lives here, every one comes from the body handed in.
## [codeblock]
## RunUiConfig.t_transition(cfg, &"fade", "fast", false)      # 125
## RunUiConfig.t_toast(cfg, 32)                                # 5960
## RunUiConfig.slot_x(1, 3, 150, 48, cfg.design_width)         # 565
## RunUiConfig.strip_layout(cfg, 8).x0                         # 404
## [/codeblock]
class_name RunUiConfig
extends RefCounted

const SPEED_INSTANT: String = "instant"
const SPEED_FAST: String = "fast"
const SPEED_NORMAL: String = "normal"
const MS_PER_S: float = 1000.0
const KIND_FADE: StringName = &"fade"
const KIND_RUN_START: StringName = &"run_start"
const KIND_INTRO_SLIDE: StringName = &"intro_slide"
const KIND_DRAFT_REVEAL: StringName = &"draft_reveal"
const KIND_FLY_TO_STRIP: StringName = &"fly_to_strip"
const KIND_TOAST: StringName = &"toast_in_out"
## F2's kinds that move something: `reduce_motion` makes them fades at
## `reduce_motion_factor` of their duration (Tuning Knobs).
const MOTION_KINDS: Array[StringName] = [KIND_INTRO_SLIDE, KIND_DRAFT_REVEAL, KIND_FLY_TO_STRIP, KIND_TOAST]
## Every key the body may hold.
const KEYS: Array[String] = [
	"restart_budget_ms", "transition_ms", "speed_factor", "reduce_motion_factor", "run_start_ms",
	"toast_base_ms", "toast_per_char_ms", "toast_min_ms", "toast_max_ms", "toast_gap_ms", "toast_queue_max",
	"copied_flash_ms", "node_d", "seg_len", "seg_len_min", "strip_max_w", "initials_min_seg", "option_gap",
	"option_w", "option_y", "design_width", "preselect_hero", "default_focus", "run_log_page",
	"settings_steps", "palette", "palette_high_contrast", "font_px", "controls", "glossary", "strings",
]
const PRESELECT_VALUES: Array[String] = ["last_played", "war", "none"]
const FOCUS_VALUES: Array[String] = ["new_run_same_hero", "hero_select", "none"]
const SPEEDS: Array[String] = [SPEED_INSTANT, SPEED_FAST, SPEED_NORMAL]
## The F2 `transition_ms` keys.
const TRANSITION_KEYS: Array[String] = ["fade", "intro_slide", "draft_reveal", "fly_to_strip", "toast_in_out"]
const TOKENS_REQUIRED: Array[String] = [
	"bg_edge", "table_dark", "table_lit", "parchment", "ink", "text_light", "text_muted", "text_ink",
	"state_danger", "state_actionable", "neutral", "boss_band_1", "boss_band_2", "boss_band_3",
]


## F2: `round(base_ms[kind] × speed_factor[anim_speed])`, then the `reduce_motion`
## factor on a [constant MOTION_KINDS] kind. An unknown speed reads as `normal`.
static func t_transition(cfg: Dictionary, kind: StringName, anim_speed: String, reduce_motion: bool) -> int:
	var base: float = float(cfg.run_start_ms) if kind == KIND_RUN_START else float((cfg.transition_ms as Dictionary).get(String(kind), 0))
	var factors: Dictionary = cfg.speed_factor
	var ms: float = base * float(factors.get(anim_speed, factors[SPEED_NORMAL]))
	if reduce_motion and MOTION_KINDS.has(kind):
		ms *= float(cfg.reduce_motion_factor)
	return roundi(ms)


## F3: `clamp(toast_base_ms + chars × toast_per_char_ms, toast_min_ms, toast_max_ms)`.
static func t_toast(cfg: Dictionary, chars: int) -> int:
	return clampi(int(cfg.toast_base_ms) + chars * int(cfg.toast_per_char_ms), int(cfg.toast_min_ms), int(cfg.toast_max_ms))


## F4 `slot_x`: the left edge of option [param i] of [param n] in a [param width] wide
## screen, for options [param w] wide and [param gap] apart.
static func slot_x(i: int, n: int, w: int, gap: int, width: int) -> int:
	@warning_ignore("integer_division")
	return (width - (n * w + (n - 1) * gap)) / 2 + i * (w + gap)


## F4 strip geometry for [param floors] nodes: `{node_d, seg_len, width, x0, initials}`.
## `seg_len` shrinks to keep `width <= strip_max_w`; under `initials_min_seg` the boss
## initials are dropped (Edge Cases "floors_per_run > 10").
static func strip_layout(cfg: Dictionary, floors: int) -> Dictionary:
	var node_d: int = int(cfg.node_d)
	var seg_len: int = int(cfg.seg_len)
	var gaps: int = maxi(floors - 1, 1)
	var max_w: int = int(cfg.strip_max_w)
	if floors * node_d + (floors - 1) * seg_len > max_w:
		@warning_ignore("integer_division")
		seg_len = maxi((max_w - floors * node_d) / gaps, int(cfg.seg_len_min))
	var width: int = floors * node_d + (floors - 1) * seg_len
	@warning_ignore("integer_division")
	var x0: int = (int(cfg.design_width) - width) / 2
	return {"node_d": node_d, "seg_len": seg_len, "width": width, "x0": x0, "initials": seg_len >= int(cfg.initials_min_seg)}


## The centre x of floor [param f] (1-based) in a [method strip_layout] result (F4 `node_cx`).
static func node_cx(layout: Dictionary, f: int) -> int:
	@warning_ignore("integer_division")
	return int(layout.x0) + int(layout.node_d) / 2 + (f - 1) * (int(layout.node_d) + int(layout.seg_len))


## The colour of [param token]; `palette_high_contrast` wins when [param high_contrast]
## is on (art bible §4). An unknown token reports and reads as magenta.
static func color(cfg: Dictionary, token: String, high_contrast: bool = false) -> Color:
	var swapped: Dictionary = cfg.get("palette_high_contrast", {})
	if high_contrast and swapped.has(token):
		return Color.html(str(swapped[token]))
	var palette: Dictionary = cfg.get("palette", {})
	if palette.has(token):
		return Color.html(str(palette[token]))
	push_error("RunUiConfig: no palette token '%s'" % token)
	return Color.MAGENTA


## The `run_ui` config validator (card-database CR-5 stage 7a; ADR-0002 Decision 4:
## `call(body, db) -> Array`): every Tuning Knobs row against its safe range, F2's
## kinds, and the palette tokens the theme needs. Static and pure.
## [codeblock]
## RunUiConfig.validate_config({"toast_min_ms": 100}, null)   # rows, E_RANGE among them
## [/codeblock]
static func validate_config(body: Dictionary, _db: Variant) -> Array:
	var rows: Array[Dictionary] = []
	ConfigRows.check_unknown_keys(rows, body, KEYS)
	ConfigRows.check_int(rows, body, "restart_budget_ms", 3000, 5000)
	ConfigRows.check_int(rows, body, "run_start_ms", 0, 1000)
	ConfigRows.check_int(rows, body, "toast_base_ms", 3000, 6000)
	ConfigRows.check_int(rows, body, "toast_per_char_ms", 20, 50)
	ConfigRows.check_int(rows, body, "toast_min_ms", 5000, 6000)
	ConfigRows.check_int(rows, body, "toast_max_ms", 6000, 10000)
	ConfigRows.check_int(rows, body, "toast_gap_ms", 100, 500)
	ConfigRows.check_int(rows, body, "toast_queue_max", 4, 16)
	ConfigRows.check_int(rows, body, "copied_flash_ms", 500, 3000)
	ConfigRows.check_int(rows, body, "node_d", 16, 32)
	ConfigRows.check_int(rows, body, "seg_len", 16, 48)
	ConfigRows.check_int(rows, body, "seg_len_min", 4, 16)
	ConfigRows.check_int(rows, body, "initials_min_seg", 8, 16)
	ConfigRows.check_int(rows, body, "strip_max_w", 480, 800)
	ConfigRows.check_int(rows, body, "design_width", 1280, 1280)
	ConfigRows.check_int(rows, body, "run_log_page", 5, 100)
	ConfigRows.check_number(rows, body, "reduce_motion_factor", 0.0, 1.0)
	_check_transitions(rows, body.get("transition_ms"))
	_check_speeds(rows, body.get("speed_factor"))
	_check_gaps(rows, body.get("option_gap"))
	_check_enum(rows, "preselect_hero", body.get("preselect_hero"), PRESELECT_VALUES)
	var focus: Variant = body.get("default_focus")
	_check_enum(rows, "default_focus.summary", focus.get("summary") if focus is Dictionary else null, FOCUS_VALUES)
	_check_palette(rows, body.get("palette"))
	if not body.get("strings") is Dictionary:
		rows.append(ConfigRows.error(ConfigRows.E_BAD_VALUE, "strings", "`strings` must map keys to text"))
	return rows


static func _check_transitions(rows: Array[Dictionary], value: Variant) -> void:
	if not value is Dictionary:
		rows.append(ConfigRows.error(ConfigRows.E_BAD_VALUE, "transition_ms", "`transition_ms` must be an object"))
		return
	for key: String in TRANSITION_KEYS:
		var high: int = 400 if key == "fade" else 600
		var ms: Variant = value.get(key)
		if not ConfigRows.is_whole(ms) or int(ms) < 0 or int(ms) > high:
			rows.append(ConfigRows.error(ConfigRows.E_RANGE, "transition_ms.%s" % key, "`%s` is outside 0-%d" % [str(ms), high]))


static func _check_speeds(rows: Array[Dictionary], value: Variant) -> void:
	if not value is Dictionary:
		rows.append(ConfigRows.error(ConfigRows.E_BAD_VALUE, "speed_factor", "`speed_factor` must be an object"))
		return
	for key: String in SPEEDS:
		var factor: Variant = value.get(key)
		if not (factor is int or factor is float) or float(factor) < 0.0 or float(factor) > 1.0:
			rows.append(ConfigRows.error(ConfigRows.E_RANGE, "speed_factor.%s" % key, "`%s` is outside 0-1" % str(factor)))
	if value.get(SPEED_INSTANT) != null and float(value[SPEED_INSTANT]) != 0.0:
		rows.append(ConfigRows.error(ConfigRows.E_RANGE, "speed_factor.instant", "`instant` must be 0 (F2)"))


static func _check_gaps(rows: Array[Dictionary], value: Variant) -> void:
	if not value is Dictionary:
		rows.append(ConfigRows.error(ConfigRows.E_BAD_VALUE, "option_gap", "`option_gap` must be an object"))
		return
	for key: String in ["treasure", "bundle"]:
		var gap: Variant = value.get(key)
		if not ConfigRows.is_whole(gap) or int(gap) < 24 or int(gap) > 64:
			rows.append(ConfigRows.error(ConfigRows.E_RANGE, "option_gap.%s" % key, "`%s` is outside 24-64" % str(gap)))


static func _check_enum(rows: Array[Dictionary], field: String, value: Variant, allowed: Array[String]) -> void:
	if not allowed.has(str(value)):
		rows.append(ConfigRows.error(ConfigRows.E_BAD_VALUE, field, "`%s` is not one of %s" % [str(value), str(allowed)]))


static func _check_palette(rows: Array[Dictionary], value: Variant) -> void:
	if not value is Dictionary:
		rows.append(ConfigRows.error(ConfigRows.E_BAD_VALUE, "palette", "`palette` must map tokens to colours"))
		return
	for token: String in TOKENS_REQUIRED:
		if not Color.html_is_valid(str(value.get(token, ""))):
			rows.append(ConfigRows.error(ConfigRows.E_BAD_VALUE, "palette.%s" % token, "no valid colour for `%s`" % token))
