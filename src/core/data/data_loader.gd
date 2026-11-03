## The only JSON parser of game data (card-database CR-1, CR-5; ADR-0002
## Decision 1-3). `CardDatabase` composes it; nothing else in `src/` reads
## `assets/data/` (the single-parser grep gate).
##
## Files are discovered **by name** from `FILE_MANIFEST` (the DD-T01 list),
## never by scanning the directory; the directory is listed only to warn about
## a `.json` that is not in the manifest (`W_UNKNOWN_FILE`, not loaded).
## `run()` goes through the CR-5 stages in order, collecting every problem in
## one `ValidationReport` and carrying on (no fail-fast); a file that fails a
## stage is left out of the later stages.
##
## Implemented here: stage 1 (discover), 2 (read and parse), 3 (envelope).
## Stages 4-8 slot into `run()` at the marked points (card-database stories
## 002-005); stage 9 (freeze, `index_of`, `data_version`) is stories 006-007.
##
## [codeblock]
## var loader: DataLoader = DataLoader.new("res://tests/fixtures/data/minimal/")
## var result: DataLoader.LoadResult = loader.run({})
## result.report.has_errors()   # false
## result.snapshot.configs.keys()  # every config file that passed, by name
## [/codeblock]
##
## Engine notes: `FileAccess.open` returns `null` on failure and the reason is
## `FileAccess.get_open_error()` (Probe B: `ERR_FILE_NOT_FOUND` = 7).
## `JSON.new().parse()` is used rather than `JSON.parse_string()` because only
## the instance form exposes `get_error_line()` / `get_error_message()`;
## `get_error_line()` is 0-based on 4.7.2 (observed: an error on the 4th line
## reports 3, a single-line file reports 0), so the report states it + 1.
## `JSON` returns every number as `float`, so `schema_version` is compared
## after an integer check. Single-thread-only; runs synchronously at boot.
class_name DataLoader
extends RefCounted

## card-database CR-5 step 3: the envelope version this build understands.
## The one exempt code literal: it cannot come from the file it validates.
## Older **and** newer versions fail; offline migration lives in `tools/`.
const SCHEMA_VERSION_CURRENT: int = 1

## DD-T01 / card-database CR-1, in CR-1 table order (`rng_event_log.json`, a
## DD-T01 row added 2026-11-03 per ADR-0002, last). Story 007's fingerprint
## walks this order: keep it stable and append new rows. Format knowledge, not
## gameplay data: `class` is `definition` (envelope `records: []`) or `config`
## (envelope `config: {}`); `record_type` is the CR-3 type of a definition
## file's records, `null` for config; `required: false` rows are skipped
## silently when absent; `owner` is the system that owns the file's body.
const FILE_MANIFEST: Array[Dictionary] = [
	{"name": "cards_war.json", "class": "definition", "record_type": "CardDef", "required": true, "owner": "Content"},
	{"name": "cards_neutral.json", "class": "definition", "record_type": "CardDef", "required": true, "owner": "Content"},
	{"name": "cards_boss.json", "class": "definition", "record_type": "CardDef", "required": true, "owner": "Content"},
	{"name": "cards_decay.json", "class": "definition", "record_type": "CardDef", "required": false, "owner": "Content"},
	{"name": "cards_knowledge.json", "class": "definition", "record_type": "CardDef", "required": false, "owner": "Content"},
	{"name": "cards_fortune.json", "class": "definition", "record_type": "CardDef", "required": false, "owner": "Content"},
	{"name": "cards_order.json", "class": "definition", "record_type": "CardDef", "required": false, "owner": "Content"},
	{"name": "cards_shadow.json", "class": "definition", "record_type": "CardDef", "required": false, "owner": "Content"},
	{"name": "heroes.json", "class": "definition", "record_type": "HeroDef", "required": true, "owner": "Heroes"},
	{"name": "hero_powers.json", "class": "definition", "record_type": "HeroPowerDef", "required": true, "owner": "Heroes"},
	{"name": "bosses.json", "class": "definition", "record_type": "BossDef", "required": true, "owner": "Content"},
	{"name": "treasures.json", "class": "definition", "record_type": "TreasureDef", "required": true, "owner": "Treasures"},
	{"name": "bundles.json", "class": "definition", "record_type": "BundleDef", "required": true, "owner": "Content"},
	{"name": "match_rules.json", "class": "config", "record_type": null, "required": true, "owner": "Match Rules"},
	{"name": "card_effects.json", "class": "config", "record_type": null, "required": true, "owner": "Card Effects"},
	{"name": "ai_profiles.json", "class": "config", "record_type": null, "required": true, "owner": "Boss AI"},
	{"name": "run_structure.json", "class": "config", "record_type": null, "required": true, "owner": "Run Structure"},
	{"name": "reward_draft.json", "class": "config", "record_type": null, "required": true, "owner": "Reward Draft"},
	{"name": "treasures_balance.json", "class": "config", "record_type": null, "required": true, "owner": "Treasures"},
	{"name": "heroes_balance.json", "class": "config", "record_type": null, "required": true, "owner": "Heroes"},
	{"name": "match_ui.json", "class": "config", "record_type": null, "required": true, "owner": "Match UI"},
	{"name": "run_ui.json", "class": "config", "record_type": null, "required": true, "owner": "Run UI"},
	{"name": "profile_defaults.json", "class": "config", "record_type": null, "required": true, "owner": "Meta Progression"},
	{"name": "card_database.json", "class": "config", "record_type": null, "required": true, "owner": "Card Database"},
	{"name": "content_budgets.json", "class": "config", "record_type": null, "required": true, "owner": "Content"},
	{"name": "rng_event_log.json", "class": "config", "record_type": null, "required": true, "owner": "RNG & Event Log"},
]


## What `run()` returns: the report, and the loaded data when the report has
## no errors (`null` otherwise — CR-5 step 9: no "load what passed" path).
## `snapshot` is `{definitions: {<file name>: records Array}, configs:
## {<config name without .json>: body Dictionary}}` until Story 006 replaces it
## with the frozen, id-indexed snapshot.
class LoadResult extends RefCounted:
	## Every problem the run found (warnings only on a clean load).
	var report: ValidationReport
	## The parsed data, or `null` when `report.has_errors()`.
	var snapshot: Variant

	func _init(p_report: ValidationReport, p_snapshot: Variant) -> void:
		report = p_report
		snapshot = p_snapshot


var _root: String


## A loader over `root` (default the shipped data). Tests point it at a
## fixture root. Example: `DataLoader.new("res://tests/fixtures/data/minimal/")`.
func _init(root: String = "res://assets/data/") -> void:
	_root = root if root.ends_with("/") else root + "/"


## The directory this loader reads, always ending in `/`.
## Example: `DataLoader.new("res://x").root() == "res://x/"`.
func root() -> String:
	return _root


## Runs the CR-5 pipeline once over `root()` and returns the report and, when
## it holds no errors, the snapshot. `_validators` is the composition-time map
## `{effects, ai_profile, unlock, treasure: Callable, configs: {<name>: Callable}}`
## that stage 7 (Story 004) consumes; stages 1-3 do not read it.
## Example: `var result: DataLoader.LoadResult = DataLoader.new().run(validators)`.
func run(_validators: Dictionary) -> LoadResult:
	var report: ValidationReport = ValidationReport.new()
	# Stage 1 — discover (CR-1): manifest rows by name, plus W_UNKNOWN_FILE.
	_warn_unknown_files(report)
	# Stage 2 — read and parse. Each staged item: {row, body}.
	var staged: Array[Dictionary] = _read_and_parse(report)
	# Stage 3 — envelope.
	staged = _check_envelopes(staged, report)
	# Stage 4 — per-record schema (Story 002) slots in here.
	# Stages 5-6 — uniqueness and cross-references (Story 003) slot in here.
	# Stage 7 — delegated validators over `_validators` (Story 004) slots in here.
	# Stage 8 — budget warnings (Story 005) slots in here.
	# Stage 9 — freeze, index_of, data_version (Stories 006-007) replace this.
	if report.has_errors():
		return LoadResult.new(report, null)
	return LoadResult.new(report, _snapshot_of(staged))


func _warn_unknown_files(report: ValidationReport) -> void:
	var known: Dictionary = {}
	for row: Dictionary in FILE_MANIFEST:
		known[row.name] = true
	for file_name: String in DirAccess.get_files_at(_root):
		if file_name.get_extension().to_lower() == "json" and not known.has(file_name):
			report.add(ValidationReport.SEVERITY_WARNING, ValidationReport.W_UNKNOWN_FILE, file_name, null, null,
				"not in the DD-T01 file manifest; not loaded")


func _read_and_parse(report: ValidationReport) -> Array[Dictionary]:
	var staged: Array[Dictionary] = []
	for row: Dictionary in FILE_MANIFEST:
		var file: FileAccess = FileAccess.open(_root + row.name, FileAccess.READ)
		if file == null:
			var open_error: Error = FileAccess.get_open_error()
			if row.required or open_error != ERR_FILE_NOT_FOUND:
				report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_MISSING_FILE, row.name, null, null,
					"cannot open %s (open error %d: %s)" % [_root + row.name, open_error, error_string(open_error)])
			continue
		var text: String = file.get_as_text()
		file.close()
		var json: JSON = JSON.new()
		if json.parse(text) != OK:
			var message: String = "line %d" % (json.get_error_line() + 1)
			if not json.get_error_message().is_empty():
				message += ": " + json.get_error_message()
			report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_PARSE, row.name, null, null, message)
			continue
		staged.append({"row": row, "body": json.data})
	return staged


func _check_envelopes(staged: Array[Dictionary], report: ValidationReport) -> Array[Dictionary]:
	var passed: Array[Dictionary] = []
	for item: Dictionary in staged:
		var file_name: String = item.row.name
		if not item.body is Dictionary:
			report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_PARSE, file_name, null, null,
				"top level must be an object {schema_version, %s}" % _body_key(item.row))
			continue
		var body: Dictionary = item.body
		var ok: bool = _check_schema_version(file_name, body, report)
		var key: String = _body_key(item.row)
		var payload: Variant = body.get(key)
		var shape_ok: bool = payload is Array if key == "records" else payload is Dictionary
		if not shape_ok:
			var found: String = "missing" if not body.has(key) else type_string(typeof(payload))
			var hint: String = ""
			if key == "config" and body.has("records"):
				hint = "; a config file carries `config`, not `records`"
			elif key == "records" and body.has("config"):
				hint = "; a definition file carries `records`, not `config`"
			report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_PARSE, file_name, null, key,
				"`%s` must be %s, found %s%s" % [key, "an array" if key == "records" else "an object", found, hint])
			ok = false
		if ok:
			passed.append(item)
	return passed


func _check_schema_version(file_name: String, body: Dictionary, report: ValidationReport) -> bool:
	var found: String
	if not body.has("schema_version"):
		found = "missing"
	else:
		var raw: Variant = body.schema_version
		var is_number: bool = typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT
		if is_number and float(raw) == floorf(float(raw)):
			if int(raw) == SCHEMA_VERSION_CURRENT:
				return true
			found = str(int(raw))
		else:
			found = "%s (not an integer)" % str(raw)
	report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_SCHEMA_VERSION, file_name, null, "schema_version",
		"schema_version found %s, expected %d" % [found, SCHEMA_VERSION_CURRENT])
	return false


func _body_key(row: Dictionary) -> String:
	return "records" if row["class"] == "definition" else "config"


func _snapshot_of(staged: Array[Dictionary]) -> Dictionary:
	var definitions: Dictionary = {}
	var configs: Dictionary = {}
	for item: Dictionary in staged:
		if item.row["class"] == "definition":
			definitions[item.row.name] = item.body.records
		else:
			configs[String(item.row.name).get_basename()] = item.body.config
	return {"definitions": definitions, "configs": configs}
