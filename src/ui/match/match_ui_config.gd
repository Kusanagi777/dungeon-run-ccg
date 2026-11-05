## The stage-7a check of `config("match_ui")` (ADR-0002 Decision 4; match-ui Tuning
## Knobs): every knob the match view reads once in `_ready`, present and inside its
## GDD safe range, and every `layout` value a rect. The view trusts the body after this.
## [codeblock]
## MatchUiConfig.validate_config({"click_drag_px": 99}, null)[0].code   # &"E_RANGE"
## [/codeblock]
class_name MatchUiConfig
extends RefCounted

## A value is outside its safe range, or of the wrong shape.
const E_RANGE: StringName = &"E_RANGE"
const RECT_SIZE: int = 4
## `path: [min, max]`, from the GDD's Tuning Knobs table.
const RANGES: Dictionary = {
	"click_drag_px": [4, 12],
	"end_turn_arm_ms": [150, 600],
	"match_end_auto_s": [2, 8],
	"min_action_gap_s": [0.1, 0.3],
	"k_min": [0.25, 0.5],
	"coalesce_threshold": [4, 14],
	"hand.hand_w": [700, 800],
	"hand.hand_gap": [4, 16],
	"hand.arc_h": [0, 26],
	"hand.theta_step_max": [2.0, 6.0],
	"hand.theta_total_max": [20.0, 40.0],
	"hand.hover_in_s": [0.05, 0.2],
	"targeting.arrow_lift_px": [20, 100],
	"feed_group_collapse": [4, 10],
	"feed_ticker_lines": [2, 4],
}
## Sections and keys the view reads with no range of their own.
const REQUIRED: Array[String] = [
	"d_base", "speed_div", "silent_types", "feed_max_lines", "layout", "palette", "strings", "glyphs",
	"hero", "board", "pop", "mulligan", "end_screen",
]


## One `{code, host_id, field, message}` row per fault, all of them reported.
static func validate_config(body: Dictionary, _db: Variant) -> Array:
	var rows: Array[Dictionary] = []
	for key: String in REQUIRED:
		if not body.has(key):
			rows.append(_row(ValidationReport.E_MISSING_FIELD, key, "`%s` is missing" % key))
	for path: String in RANGES:
		var value: Variant = _at(body, path)
		var bounds: Array = RANGES[path]
		if value == null:
			rows.append(_row(ValidationReport.E_MISSING_FIELD, path, "`%s` is missing" % path))
		elif not (value is int or value is float) or float(value) < float(bounds[0]) or float(value) > float(bounds[1]):
			rows.append(_row(E_RANGE, path, "`%s` is %s, outside %s to %s" % [path, str(value), str(bounds[0]), str(bounds[1])]))
	var layout: Variant = body.get("layout")
	if layout is Dictionary:
		for zone: String in layout:
			var rect: Variant = layout[zone]
			if not rect is Array or (rect as Array).size() != RECT_SIZE:
				rows.append(_row(E_RANGE, "layout." + zone, "`layout.%s` is not an x, y, w, h rect" % zone))
	return rows


static func _at(body: Dictionary, path: String) -> Variant:
	var value: Variant = body
	for key: String in path.split("."):
		if not value is Dictionary:
			return null
		value = (value as Dictionary).get(key)
	return value


static func _row(code: StringName, field: String, message: String) -> Dictionary:
	return {"code": code, "host_id": null, "field": field, "message": message}
