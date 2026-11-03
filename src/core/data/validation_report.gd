## The Card Database load report (card-database CR-5 "Report entry shape";
## ADR-0002 Key Interfaces).
##
## Every stage of the load pipeline adds what it finds here and carries on, so
## one report lists every problem (CR-5: no fail-fast). An entry is a plain
## Dictionary with exactly six keys:
## `{severity, code, file, record_id, field, message}` — `severity` is
## `&"error"` or `&"warning"`, `record_id` and `field` are `null` when the
## problem concerns the whole file.
##
## [codeblock]
## var report: ValidationReport = ValidationReport.new()
## report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_PARSE,
##         "cards_war.json", null, null, "line 4: Expected '}' or ','")
## report.has_errors()          # true
## report.entries()[0].file     # "cards_war.json"
## print(report.to_text())      # what the data_error screen and validate command show
## [/codeblock]
##
## Single-thread-only: the report is built by one synchronous load.
class_name ValidationReport
extends RefCounted

## `severity` of an entry that makes the load `Failed` (CR-5 step 9).
const SEVERITY_ERROR: StringName = &"error"
## `severity` of an entry that never blocks the load (CR-5 step 8).
const SEVERITY_WARNING: StringName = &"warning"

## A required CR-1 file could not be opened (CR-5 step 1).
const E_MISSING_FILE: StringName = &"E_MISSING_FILE"
## Malformed JSON, or an envelope of the wrong shape (CR-5 steps 2-3).
const E_PARSE: StringName = &"E_PARSE"
## `schema_version` is not `DataLoader.SCHEMA_VERSION_CURRENT` (CR-5 step 3).
const E_SCHEMA_VERSION: StringName = &"E_SCHEMA_VERSION"
## A record field of the wrong type, out of range or off its pattern, or a
## cross-field rule broken; a `card_database.json` knob fault (CR-3, CR-5 step 4).
const E_SCHEMA: StringName = &"E_SCHEMA"
## A required record field absent or `null` (CR-3, CR-5 step 4).
const E_MISSING_FIELD: StringName = &"E_MISSING_FIELD"
## A field CR-3 does not list for the record type, or one its by-type rule
## forbids (CR-3, CR-5 step 4).
const E_UNKNOWN_FIELD: StringName = &"E_UNKNOWN_FIELD"
## A value outside a CR-3 / CR-4 enumeration (CR-5 step 4).
const E_BAD_ENUM: StringName = &"E_BAD_ENUM"
## A card `set` that is not its file's set, or an id prefix that disagrees
## with the record type or set (CR-2, CR-5 step 4).
const E_SET_MISMATCH: StringName = &"E_SET_MISMATCH"
## A `text.key` that is not `card.<id>.text` (or `passive_text.key` not
## `boss.<id>.passive`) (CR-3, Edge Cases).
const E_TEXT_KEY: StringName = &"E_TEXT_KEY"
## One id defined more than once, in one file or across files and record
## types; the entry names every `file records[i]` and no copy is kept (CR-5 step 5).
const E_DUP_ID: StringName = &"E_DUP_ID"
## A list entry or `hero_power` naming no record of the expected type; the
## message names the list index and the id (CR-5 step 6).
const E_UNKNOWN_REF: StringName = &"E_UNKNOWN_REF"
## A list of the wrong length (starter deck 15, bundle 3), found and expected
## in the message (CR-5 step 6).
const E_COUNT: StringName = &"E_COUNT"
## A token card in a starter deck, bundle or boss deck (CR-5 step 6).
const E_TOKEN_IN_LIST: StringName = &"E_TOKEN_IN_LIST"
## A bundle card without the bundle's `theme` tag (CR-5 step 6).
const E_TAG_MISMATCH: StringName = &"E_TAG_MISMATCH"
## Stage 7 (CR-5 step 7): a validator the composition did not register (or
## registered as a non-Callable), a validator returning something other than
## an Array of entries, or one entry an owner's validator returned. An owner
## entry's message is `"<owner code>: <owner message>"` (e.g.
## `E_FX_OP: unknown op "bogus" (at effects/0/ops/1/op)`); an owner code
## starting `W_` is merged with severity `warning`, every other one `error`.
const E_DELEGATED: StringName = &"E_DELEGATED"
## Stage 8 (Formulas): a pool under its threshold — a hero set's collectible
## pool under `min_collectible_pool`, its bundle pool under `min_bundle_pool`,
## the default-unlocked treasures under `min_treasure_pool` — or, with "not
## checked" in the message, a pool check whose inputs were absent (CR-5 step 8).
const W_POOL_SIZE: StringName = &"W_POOL_SIZE"
## Stage 8: a boss `health` that differs from its band default (DD-M02), or a
## "not checked" note when the band defaults are absent (CR-5 step 8).
const W_BAND_HEALTH: StringName = &"W_BAND_HEALTH"
## Stage 8: a `cards_<set>.json` that parsed with `records: []` (Edge Cases).
const W_EMPTY_SET: StringName = &"W_EMPTY_SET"
## Stage 8: two different card ids with the same `name` (Edge Cases).
const W_DUP_NAME: StringName = &"W_DUP_NAME"
## A `.json` file not in `DataLoader.FILE_MANIFEST`; it is not loaded (CR-1).
const W_UNKNOWN_FILE: StringName = &"W_UNKNOWN_FILE"
## Stage 7 owner code (merged as `E_DELEGATED`, message
## `"W_VALIDATOR_PENDING: …"`): the composition registered a *pending*
## validator because the owner named in the message has not shipped its real
## one — one entry per config file, and one per record host kind for a pending
## record validator. The body or field is **not checked**. The pending
## validator gives it severity `warning` in a debug build and `error` in an
## exported one, so a shipped load with a pending validator fails instead of
## passing (ADR-0002 Decision 4: a missing validator never passes silently;
## code review 2026-11-03).
const W_VALIDATOR_PENDING: StringName = &"W_VALIDATOR_PENDING"

var _entries: Array[Dictionary] = []


## Records one problem. `record_id` and `field` are `null` for a file-level
## problem. Example:
## `report.add(SEVERITY_WARNING, W_UNKNOWN_FILE, "stray.json", null, null, "not in FILE_MANIFEST; not loaded")`.
func add(severity: StringName, code: StringName, file: String, record_id: Variant, field: Variant, message: String) -> void:
	_entries.append({
		"severity": severity,
		"code": code,
		"file": file,
		"record_id": record_id,
		"field": field,
		"message": message,
	})


## Every entry, sorted by `file`, then `record_id` (`null` first), then the
## order they were added. Returns copies: editing them does not change the
## report. Example: `for e: Dictionary in report.entries(): print(e.code)`.
func entries() -> Array[Dictionary]:
	var order: Array[int] = []
	for i: int in _entries.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return _precedes(a, b))
	var out: Array[Dictionary] = []
	for i: int in order:
		out.append(_entries[i].duplicate(true))
	return out


## The entries whose severity is `error`, in `entries()` order.
## Example: `report.errors().size()`.
func errors() -> Array[Dictionary]:
	return _with_severity(SEVERITY_ERROR)


## The entries whose severity is `warning`, in `entries()` order.
## Example: `report.warnings().size()`.
func warnings() -> Array[Dictionary]:
	return _with_severity(SEVERITY_WARNING)


## True when at least one entry is an error — the load is then `Failed`.
## Example: `if report.has_errors(): show_data_error(report)`.
func has_errors() -> bool:
	for e: Dictionary in _entries:
		if e.severity == SEVERITY_ERROR:
			return true
	return false


## The report as text, one entry per line in `entries()` order, after a count
## line. This is what the `data_error` screen and the headless validate command
## print (CR-8). Example line:
## `error E_PARSE cards_war.json: line 4: Expected '}' or ','`.
func to_text() -> String:
	var lines: PackedStringArray = []
	var error_count: int = _with_severity(SEVERITY_ERROR).size()
	lines.append("Data validation: %d error(s), %d warning(s)" % [error_count, _entries.size() - error_count])
	for e: Dictionary in entries():
		var where: String = e.file
		if e.record_id != null:
			where += " [%s]" % str(e.record_id)
		if e.field != null:
			where += " (%s)" % str(e.field)
		lines.append("%s %s %s: %s" % [e.severity, e.code, where, e.message])
	return "\n".join(lines)


func _with_severity(severity: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in entries():
		if e.severity == severity:
			out.append(e)
	return out


func _precedes(a: int, b: int) -> bool:
	var ea: Dictionary = _entries[a]
	var eb: Dictionary = _entries[b]
	if ea.file != eb.file:
		return ea.file < eb.file
	if ea.record_id != eb.record_id:
		if ea.record_id == null:
			return true
		if eb.record_id == null:
			return false
		return str(ea.record_id) < str(eb.record_id)
	return a < b
