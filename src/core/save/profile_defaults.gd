## The stage-7a validator of `assets/data/profile_defaults.json` (ADR-0002
## Decision 4; meta-progression M9, Tuning Knobs, F7). Its owner's entry for
## `Boot._collect_validators`: `configs["profile_defaults"] = ProfileDefaults.validate_config`.
##
## [codeblock]
## var rows: Array = ProfileDefaults.validate_config(db_body, null)   # [] when valid
## [/codeblock]
class_name ProfileDefaults
extends RefCounted

const E_RANGE: StringName = &"E_RANGE"

## Tuning Knobs safe ranges, `[low, high]` inclusive. `max_floor_clamp` must equal
## the top of run-structure's `floors_per_run` range.
const KNOB_RANGES: Dictionary = {
	"run_log_cap": [20, 1000],
	"archive_top_cards": [5, 36],
	"max_profile_bytes": [1048576, 8388608],
	"max_save_ms": [16, 200],
	"backup_count": [1, 3],
	"io_retry_ms": [0, 2000],
	"settings_write_debounce_ms": [0, 2000],
	"lock_heartbeat_s": [10, 120],
	"lock_stale_s": [60, 600],
	"max_condition_depth": [2, 5],
	"max_condition_n": [1, 9999],
	"max_condition_fan_out": [2, 16],
	"max_floor_clamp": [12, 12],
	"max_repairs_before_rebuild": [5, 100],
	"max_count": [1, 999999],
	"max_duration_s": [1, 100000000],
}
const TOKEN_KNOB: String = "reset_confirm_token"
## ADR-0004 addendum 1: `bindings` is never in the defaults.
const ABSENT_SETTING: String = "bindings"


## Stage 7a: every M9 key present and inside its range or enum, no key M9 does not
## name, every knob present and inside its safe range, and
## `lock_stale_s >= 2 * lock_heartbeat_s` (F7). Returns `{code, field, message}`
## rows, `[]` when valid.
## Example: `ProfileDefaults.validate_config({}, null)[0].code   # &"E_MISSING_FIELD"`.
static func validate_config(body: Dictionary, _db: Variant) -> Array:
	var rows: Array = []
	_check_settings(rows, body)
	var knobs: Variant = body.get(ProfileStore.KNOBS_KEY)
	if not knobs is Dictionary:
		rows.append(_row(ValidationReport.E_MISSING_FIELD, ProfileStore.KNOBS_KEY, "the tuning knobs object is missing"))
		return rows
	_check_knobs(rows, knobs)
	return rows


static func _check_settings(rows: Array, body: Dictionary) -> void:
	for key: String in ProfileSchema.SETTINGS:
		if key == ABSENT_SETTING:
			continue
		if not body.has(key):
			rows.append(_row(ValidationReport.E_MISSING_FIELD, key, "M9 setting `%s` has no default" % key))
		elif not ProfileSchema.check_setting(key, body[key]).ok:
			rows.append(_row(E_RANGE, key, "`%s` default %s is outside M9" % [key, str(body[key])]))
	for key: Variant in body:
		var known: bool = ProfileSchema.SETTINGS.has(key) and key != ABSENT_SETTING
		if not known and key != ProfileStore.KNOBS_KEY:
			rows.append(_row(ValidationReport.E_UNKNOWN_FIELD, str(key), "`%s` is not an M9 setting default" % str(key)))


static func _check_knobs(rows: Array, knobs: Dictionary) -> void:
	for key: String in KNOB_RANGES:
		var field: String = "%s.%s" % [ProfileStore.KNOBS_KEY, key]
		if not knobs.has(key):
			rows.append(_row(ValidationReport.E_MISSING_FIELD, field, "knob `%s` is missing" % key))
			continue
		var value: Variant = knobs[key]
		var bounds: Array = KNOB_RANGES[key]
		var whole: bool = (value is int or value is float) and float(value) == floorf(value)
		if not whole or int(value) < int(bounds[0]) or int(value) > int(bounds[1]):
			rows.append(_row(E_RANGE, field, "`%s` is %s, outside %d to %d" % [key, str(value), bounds[0], bounds[1]]))
	var token: Variant = knobs.get(TOKEN_KNOB)
	if not token is String or (token as String).is_empty():
		rows.append(_row(ValidationReport.E_MISSING_FIELD, "%s.%s" % [ProfileStore.KNOBS_KEY, TOKEN_KNOB], "the reset token must be a non-empty string"))
	for key: Variant in knobs:
		if not KNOB_RANGES.has(key) and key != TOKEN_KNOB:
			rows.append(_row(ValidationReport.E_UNKNOWN_FIELD, "%s.%s" % [ProfileStore.KNOBS_KEY, str(key)], "`%s` is not a knob" % str(key)))
	var stale: Variant = knobs.get("lock_stale_s")
	var heartbeat: Variant = knobs.get("lock_heartbeat_s")
	if (stale is int or stale is float) and (heartbeat is int or heartbeat is float) and float(stale) < 2.0 * float(heartbeat):
		rows.append(_row(E_RANGE, "%s.lock_stale_s" % ProfileStore.KNOBS_KEY, "lock_stale_s must be at least twice lock_heartbeat_s (F7)"))


static func _row(code: StringName, field: String, message: String) -> Dictionary:
	return {"code": code, "field": field, "message": message}
