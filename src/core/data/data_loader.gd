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
## Implemented here: stage 1 (discover), 2 (read and parse), 3 (envelope),
## 4 (per-record schema and the `card_database.json` knobs, through
## `RecordSchemas`), 5 (id uniqueness), 6 (cross-references), the id-sorted
## staging (`LoadResult.staging`) and 7 (the injected validators, 7a configs
## then 7b records, with the database's stage-7 lookups open). Stage 8 slots
## into `run()` at the marked point (card-database story 005); stage 9
## (freeze, `data_version`) is stories 006-007.
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
## after an integer check. The 4.7.2 parser is lenient where CR-1 is strict
## (observed 2026-11-03): it accepts a trailing comma (`{"a": 1,}`, `[1,]`)
## and a duplicate key (`{"a": 1, "a": 2}` keeps `2` silently), so a file
## that parses is also scanned for both and each is `E_PARSE` with its line.
## Single-thread-only; runs synchronously at boot.
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

## Stage 7b record validator keys (card-database CR-5 stage 7): the owner and
## the owner's CR-1 config file, which a missing-validator `E_DELEGATED` entry
## names (`field` is the key), and what the validator covers. Composition
## contract, not data: a missing key fails the load in every build type.
const RECORD_VALIDATORS: Dictionary = {
	"effects": {"owner": "Card Effects", "file": "card_effects.json",
		"validates": "CardDef / HeroPowerDef / TreasureDef `effects` and BossDef `passive`"},
	"ai_profile": {"owner": "Boss AI", "file": "ai_profiles.json", "validates": "BossDef `ai_profile`"},
	"unlock": {"owner": "Meta Progression", "file": "profile_defaults.json",
		"validates": "HeroDef / TreasureDef / BundleDef `unlock`"},
	"treasure": {"owner": "Treasures", "file": "treasures_balance.json", "validates": "TreasureDef `rarity`, `tags`, effect count"},
}
## Config files with no injected validator: the loader's own body, checked at
## stage 4 (card-database CR-1 row, CR-5 stage 7).
const CONFIG_VALIDATOR_EXEMPT: Array[String] = ["card_database.json"]


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
	## The records that passed stages 4-6, built after stage 6 whatever the
	## outcome: `{records: {<record_type>: Array[Dictionary] sorted by id},
	## index_of: {<id>: {type, position}}, files: {<id>: <file name>}}`. Stage 7
	## answers its lookups from it; Story 006 freezes it into the snapshot.
	var staging: Dictionary

	func _init(p_report: ValidationReport, p_snapshot: Variant, p_staging: Dictionary = {}) -> void:
		report = p_report
		snapshot = p_snapshot
		staging = p_staging


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
## it holds no errors, the snapshot. `validators` is the composition-time map
## `{effects, ai_profile, unlock, treasure: Callable, configs: {<name>: Callable}}`
## stage 7 consumes (ADR-0002 Decision 4; a missing entry is `E_DELEGATED`).
## `db` is the `CardDatabase` the validators receive and whose lookups open
## for stage 7 (`CardDatabase.load` passes itself); `null` when a test or a
## tool runs the loader alone — the validators then receive `null`.
## Example: `var result: DataLoader.LoadResult = DataLoader.new().run(validators)`.
func run(validators: Dictionary, db: CardDatabase = null) -> LoadResult:
	var report: ValidationReport = ValidationReport.new()
	# Stage 1 — discover (CR-1): manifest rows by name, plus W_UNKNOWN_FILE.
	_warn_unknown_files(report)
	# Stage 2 — read and parse. Each staged item: {row, body}.
	var staged: Array[Dictionary] = _read_and_parse(report)
	# Stage 3 — envelope.
	staged = _check_envelopes(staged, report)
	# Stage 4 — per-record schema; each definition item gains `records`, the
	# `{index, record}` rows that passed. A failing card_database.json is dropped.
	staged = _check_schemas(staged, report)
	# Stage 5 — one global id namespace: every copy of a repeated id is out.
	var pool: Dictionary = _check_unique(staged, report)
	# Stage 6 — cross-references; records that fail are out, then the
	# id-sorted staging stage 7 reads is built from what is left.
	_check_references(pool, report)
	var staging: Dictionary = _build_staging(pool)
	# Stage 7 — delegated validators: 7a config bodies, 7b staged records.
	staging = _run_validators(validators, staged, pool, staging, db, report)
	# Stage 8 — budget warnings (Story 005) slots in here.
	# Stage 9 — freeze, index_of, data_version (Stories 006-007) replace this.
	if report.has_errors():
		return LoadResult.new(report, null, staging)
	return LoadResult.new(report, _snapshot_of(staged), staging)


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
		var strict_problems: PackedStringArray = _strict_json_problems(text)
		for problem: String in strict_problems:
			report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_PARSE, row.name, null, null, problem)
		if not strict_problems.is_empty():
			continue
		staged.append({"row": row, "body": json.data})
	return staged


## The CR-1 faults the engine parser lets through, in `text` that has already
## parsed: every trailing comma before `}` or `]` and every duplicate key
## within one object, as `"line N: …"` messages (1-based, the line of the
## comma or of the repeated key). Keys are compared as written, escapes
## undecoded. Strings are skipped whole, so punctuation inside them is never
## read as structure.
func _strict_json_problems(text: String) -> PackedStringArray:
	var problems: PackedStringArray = []
	var quote: int = "\"".unicode_at(0)
	var backslash: int = "\\".unicode_at(0)
	var newline: int = "\n".unicode_at(0)
	var comma: int = ",".unicode_at(0)
	var open_object: int = "{".unicode_at(0)
	var close_object: int = "}".unicode_at(0)
	var open_array: int = "[".unicode_at(0)
	var close_array: int = "]".unicode_at(0)
	var whitespace: Array[int] = [" ".unicode_at(0), "\t".unicode_at(0), "\r".unicode_at(0)]
	# One frame per open container: {object: bool, seen: {raw key: true}}.
	var frames: Array[Dictionary] = []
	var line: int = 1
	var comma_line: int = 1
	var last: int = -1  # the last structural character outside strings
	var i: int = 0
	var size: int = text.length()
	while i < size:
		var c: int = text.unicode_at(i)
		if c == newline:
			line += 1
		elif c == quote:
			var start: int = i + 1
			i = start
			while i < size and text.unicode_at(i) != quote:
				i += 2 if text.unicode_at(i) == backslash else 1
			var in_object: bool = not frames.is_empty() and frames.back()["object"]
			if in_object and (last == open_object or last == comma):
				var key: String = text.substr(start, i - start)
				if frames.back()["seen"].has(key):
					problems.append("line %d: duplicate key \"%s\" in one object (CR-1: keys are unique; the parser would keep the last value silently)" % [line, key])
				frames.back()["seen"][key] = true
			last = quote
		elif c == open_object or c == open_array:
			frames.append({"object": c == open_object, "seen": {}})
			last = c
		elif c == close_object or c == close_array:
			if last == comma:
				problems.append("line %d: trailing comma before '%s' (CR-1: strict JSON)" % [comma_line, String.chr(c)])
			if not frames.is_empty():
				frames.pop_back()
			last = c
		elif c == comma:
			comma_line = line
			last = c
		elif not whitespace.has(c):
			last = c
		i += 1
	return problems


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


## Stage 4 (CR-3, CR-5 step 4): every record of every definition file through
## `RecordSchemas.check_record`, and the `card_database.json` body through
## `RecordSchemas.check_card_database_config`. Every other config body passes
## untouched (stage 7a). Each definition item gains `records`: the
## `{index: int, record: Dictionary}` rows that passed, in file order; a record
## that failed is left out of stages 6-9, the file itself stays. It also gains
## `ids`: `{index, id}` for every record with a string id, passed or not, so
## stage 5 sees a duplicate even when one copy failed its schema (a `war_` card
## pasted into `cards_neutral.json` fails its prefix *and* is a duplicate).
func _check_schemas(staged: Array[Dictionary], report: ValidationReport) -> Array[Dictionary]:
	var passed: Array[Dictionary] = []
	for item: Dictionary in staged:
		var row: Dictionary = item.row
		if row["class"] == "definition":
			var rows: Array[Dictionary] = []
			var ids: Array[Dictionary] = []
			var records: Array = item.body.records
			for i: int in records.size():
				if RecordSchemas.check_record(row.record_type, row.name, i, records[i], report):
					rows.append({"index": i, "record": records[i]})
				if records[i] is Dictionary and records[i].get("id") is String:
					ids.append({"index": i, "id": records[i]["id"]})
			item["records"] = rows
			item["ids"] = ids
		elif row.name == RecordSchemas.CARD_DATABASE_FILE:
			if not RecordSchemas.check_card_database_config(item.body.config, report):
				continue
		passed.append(item)
	return passed


## Stage 5 (CR-2, CR-5 step 5): one id namespace across every definition
## file and record type. An id seen more than once is one `E_DUP_ID` entry
## (file: the first defining file in manifest order; the message lists every
## `file records[i]`) and **no** copy is kept — there is no "last one wins".
## Returns the pool for stage 6: `{id: {type, record, file}}` for every row
## that passed stage 4 and is unique.
func _check_unique(staged: Array[Dictionary], report: ValidationReport) -> Dictionary:
	var seen: Dictionary = {}  # id -> Array of "file records[i]"
	var first_file: Dictionary = {}
	for item: Dictionary in staged:
		for entry: Dictionary in item.get("ids", []):
			var where: String = "%s records[%d]" % [item.row.name, entry.index]
			if seen.has(entry.id):
				seen[entry.id].append(where)
			else:
				seen[entry.id] = [where]
				first_file[entry.id] = item.row.name
	for id: String in seen:
		var places: Array = seen[id]
		if places.size() > 1:
			report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_DUP_ID, first_file[id], id, "id",
				"id \"%s\" is defined %d times: %s (CR-2: one namespace; no copy is kept)" % [id, places.size(), ", ".join(places)])
	var pool: Dictionary = {}
	for item: Dictionary in staged:
		for row: Dictionary in item.get("records", []):
			var id: String = row.record["id"]
			if seen[id].size() == 1:
				pool[id] = {"type": item.row.record_type, "record": row.record, "file": item.row.name}
	return pool


## Stage 6 (CR-3, CR-5 step 6, Edge Cases "Pools and lists"): hero
## `starter_deck` (exactly the CR-3 count, no tokens, each card of the hero's
## set or `neutral`), hero `hero_power`, the hero's `cards_<set>.json` being
## present in the root, boss `deck` (no tokens, any set) and non-null
## `hero_power`, bundle `cards` (exactly the CR-3 count, no tokens, each of
## the bundle's set and carrying its `theme` tag). References resolve against
## `pool` only, so a record that failed stage 4 or 5 is an unknown reference.
## Every record with a fault is removed from `pool`; one entry per fault, each
## naming the referring record, the field and, in the message, the index and
## the id. Lookups are O(1) in `pool` (no scan per reference).
func _check_references(pool: Dictionary, report: ValidationReport) -> void:
	var failed: Array[String] = []
	for id: String in pool:
		var entry: Dictionary = pool[id]
		var ctx: Dictionary = {"report": report, "pool": pool, "file": entry.file, "id": id, "faults": 0}
		var rec: Dictionary = entry.record
		match String(entry.type):
			"HeroDef":
				var set_file: String = "cards_%s.json" % rec["set"]
				if not FileAccess.file_exists(_root + set_file):
					report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_MISSING_FILE, set_file, id, "set",
						"hero %s has set \"%s\" but %s is not in the data root" % [id, rec["set"], set_file])
					ctx.faults += 1
				_ref(ctx, "hero_power", "hero_power", rec["hero_power"], "HeroPowerDef")
				_check_count(ctx, "starter_deck", rec["starter_deck"], RecordSchemas.HERO_FIELDS.starter_deck["count"])
				_check_card_list(ctx, "starter_deck", rec["starter_deck"], [rec["set"], "neutral"], "")
			"BossDef":
				if rec["hero_power"] != null:
					_ref(ctx, "hero_power", "hero_power", rec["hero_power"], "HeroPowerDef")
				_check_card_list(ctx, "deck", rec["deck"], [], "")
			"BundleDef":
				_check_count(ctx, "cards", rec["cards"], RecordSchemas.BUNDLE_FIELDS.cards["count"])
				_check_card_list(ctx, "cards", rec["cards"], [rec["set"]], rec["theme"])
		if ctx.faults > 0:
			failed.append(id)
	for id: String in failed:
		pool.erase(id)


func _check_count(ctx: Dictionary, field: String, items: Array, expected: int) -> void:
	if items.size() != expected:
		_ref_fault(ctx, ValidationReport.E_COUNT, field, "`%s` found %d, expected %d (CR-3)" % [field, items.size(), expected])


## Each entry of a card-id list: a known CardDef, not a token, of one of
## `sets` (any set when empty), carrying `theme` (unchecked when empty).
func _check_card_list(ctx: Dictionary, field: String, items: Array, sets: Array, theme: String) -> void:
	for i: int in items.size():
		var where: String = "%s[%d]" % [field, i]
		var card: Variant = _ref(ctx, field, where, items[i], "CardDef")
		if card == null:
			continue
		if card.get("token", false):
			_ref_fault(ctx, ValidationReport.E_TOKEN_IN_LIST, field,
				"%s \"%s\" is a token; tokens exist only through effects" % [where, items[i]])
		if not sets.is_empty() and not sets.has(card["set"]):
			_ref_fault(ctx, ValidationReport.E_SET_MISMATCH, field,
				"%s \"%s\" is from set %s; expected %s" % [where, items[i], card["set"], " or ".join(sets)])
		if not theme.is_empty() and not Array(card["tags"]).has(theme):
			_ref_fault(ctx, ValidationReport.E_TAG_MISMATCH, field,
				"%s \"%s\" lacks the theme tag \"%s\"" % [where, items[i], theme])


## The referenced record when `target` names a `record_type` record in the
## pool; otherwise one `E_UNKNOWN_REF` and `null`.
func _ref(ctx: Dictionary, field: String, where: String, target: String, record_type: String) -> Variant:
	var hit: Variant = ctx.pool.get(target)
	if hit == null:
		_ref_fault(ctx, ValidationReport.E_UNKNOWN_REF, field,
			"%s: no %s \"%s\" (unknown id, or its record failed validation)" % [where, record_type, target])
		return null
	if hit.type != record_type:
		_ref_fault(ctx, ValidationReport.E_UNKNOWN_REF, field,
			"%s: \"%s\" is a %s, not a %s" % [where, target, hit.type, record_type])
		return null
	return hit.record


func _ref_fault(ctx: Dictionary, code: StringName, field: String, message: String) -> void:
	ctx.report.add(ValidationReport.SEVERITY_ERROR, code, ctx.file, ctx.id, field, message)
	ctx.faults += 1


## The records that passed stages 4-6, per CR-3 type, sorted by id ascending
## (never file order — CR-6), with `index_of` `{id: {type, position}}` into
## those lists and `files` `{id: file name}`. Built once; stage 7's lookups
## and Story 006's freeze read it.
func _build_staging(pool: Dictionary) -> Dictionary:
	var records: Dictionary = {}
	for record_type: String in RecordSchemas.SCHEMAS:
		var empty: Array[Dictionary] = []
		records[record_type] = empty
	var ids: Array = pool.keys()
	ids.sort()
	var index_of: Dictionary = {}
	var files: Dictionary = {}
	for id: String in ids:
		var entry: Dictionary = pool[id]
		var list: Array[Dictionary] = records[entry.type]
		index_of[id] = {"type": entry.type, "position": list.size()}
		files[id] = entry.file
		list.append(entry.record)
	return {"records": records, "index_of": index_of, "files": files}


## Stage 7 (CR-5 step 7; ADR-0002 Decision 4; ADR-0007 Decision 8): the
## injected validators. First every required key is checked — each absent or
## non-Callable one is one `E_DELEGATED` error naming its owner, in every build
## type (`OS.is_debug_build()` relaxes nothing) — then the present ones run,
## none short-circuited:
## - **7a**, each config file in manifest order except
##   [constant CONFIG_VALIDATOR_EXEMPT]: `configs[name].call(body, db)`; the
##   bodies whose validator returned no error form `configs_bodies`
##   (`{<name>: body}`; `card_database` joins them, checked at stage 4);
## - **7b**, each staged record in type then id order:
##   `call(host_kind, host_id, value, db, configs_bodies)` — `effects` for a
##   CardDef / HeroPowerDef / TreasureDef `effects` and a BossDef `passive`
##   (wrapped as a one-effect list; a `null` passive is skipped), `treasure`
##   for the whole TreasureDef after its `effects`, `ai_profile` for a BossDef
##   `ai_profile`, `unlock` for a HeroDef / TreasureDef / BundleDef `unlock`
##   (`null` included; the owner decides).
## While it runs, `db` (when given) answers lookups from `staging` and nothing
## else (`CardDatabase._begin_stage7` / `_end_stage7`). Each returned entry is
## merged by [method _merge_delegated]. A record any validator failed is removed
## from `pool`, and the staging is rebuilt for stage 8. Returns the staging.
func _run_validators(validators: Dictionary, staged: Array[Dictionary], pool: Dictionary, staging: Dictionary, db: CardDatabase, report: ValidationReport) -> Dictionary:
	var present: Dictionary = {}
	for key: String in RECORD_VALIDATORS:
		var spec: Dictionary = RECORD_VALIDATORS[key]
		if validators.get(key) is Callable:
			present[key] = validators[key]
		else:
			report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_DELEGATED, spec.file, null, key,
				"no `%s` record validator registered (owner: %s; %s) — %s" % [key, spec.owner, spec.validates, _absent_or(validators.get(key))])
	var config_validators: Variant = validators.get("configs", {})
	if not config_validators is Dictionary:
		config_validators = {}
	for row: Dictionary in FILE_MANIFEST:
		if row["class"] != "config" or CONFIG_VALIDATOR_EXEMPT.has(row.name):
			continue
		var name: String = String(row.name).get_basename()
		if not config_validators.get(name) is Callable:
			report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_DELEGATED, row.name, null, null,
				"no config validator registered under configs.%s (owner: %s) — %s" % [name, row.owner, _absent_or(config_validators.get(name))])

	if db != null:
		db._begin_stage7(staging)
	# 7a — config validators.
	var bodies: Dictionary = {}
	for item: Dictionary in staged:
		var row: Dictionary = item.row
		if row["class"] != "config":
			continue
		var name: String = String(row.name).get_basename()
		if CONFIG_VALIDATOR_EXEMPT.has(row.name):
			bodies[name] = item.body.config
			continue
		var validator: Variant = config_validators.get(name)
		if validator is Callable and _merge_delegated(validator.call(item.body.config, db), row.name, null, null, "configs." + name, report):
			bodies[name] = item.body.config
	# 7b — record validators.
	var failed: Array[String] = []
	for record_type: String in staging.records:
		for rec: Dictionary in staging.records[record_type]:
			var id: String = rec["id"]
			var file: String = staging.files[id]
			var ok: bool = true
			for c: Array in _record_calls(record_type, rec):
				var key: String = c[0]
				if present.has(key):
					var result: Variant = present[key].call(c[1], id, c[2], db, bodies)
					ok = _merge_delegated(result, file, id, c[3], key, report) and ok
			if not ok:
				failed.append(id)
	if db != null:
		db._end_stage7()
	if failed.is_empty():
		return staging
	for id: String in failed:
		pool.erase(id)
	return _build_staging(pool)


## The stage-7b calls for one record, in order: `[key, host_kind, value, field]`.
func _record_calls(record_type: String, rec: Dictionary) -> Array:
	match record_type:
		"CardDef":
			return [["effects", &"card", rec["effects"], "effects"]]
		"HeroPowerDef":
			return [["effects", &"hero_power", rec["effects"], "effects"]]
		"TreasureDef":
			return [
				["effects", &"treasure", rec["effects"], "effects"],
				["treasure", &"treasure", rec, "treasure"],
				["unlock", &"treasure", rec["unlock"], "unlock"],
			]
		"BossDef":
			var calls: Array = []
			if rec["passive"] != null:
				calls.append(["effects", &"boss", [rec["passive"]], "passive"])
			calls.append(["ai_profile", &"boss", rec["ai_profile"], "ai_profile"])
			return calls
		"HeroDef":
			return [["unlock", &"hero", rec["unlock"], "unlock"]]
		"BundleDef":
			return [["unlock", &"bundle", rec["unlock"], "unlock"]]
	return []


## Merges one validator's result into `report` and returns true when it held
## no error. Each entry `{code, host_id | record_id, field, message}` (the
## ADR-0002 shape; ADR-0007's `{code, host_id, effect_id, path, message}` and
## RulesEngine's report-shaped entries fit it) becomes one `E_DELEGATED` entry:
## `file` and `record_id` from the call site (the entry's `host_id` /
## `record_id` when the call site has none), `field` the entry's `field`, else
## `default_field` (the record field for 7b, `null` for 7a), and `message`
## `"<owner code>: <message>"` with ` (at <path>)` appended when the entry
## carries a `path`. `label` names the validator in a malformed-result entry.
## An owner code starting `W_` (or an entry with `severity` `warning`) merges
## as a warning and does not fail the record; anything else is an error. A
## result that is not an Array, or an entry that is not a Dictionary, is one
## `E_DELEGATED` error (a validator called with the wrong arity returns null).
func _merge_delegated(result: Variant, file: String, record_id: Variant, default_field: Variant, label: String, report: ValidationReport) -> bool:
	if not result is Array:
		report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_DELEGATED, file, record_id, default_field,
			"%s returned %s, expected an Array of entries" % [label, type_string(typeof(result))])
		return false
	var ok: bool = true
	for entry: Variant in result:
		if not entry is Dictionary:
			report.add(ValidationReport.SEVERITY_ERROR, ValidationReport.E_DELEGATED, file, record_id, default_field,
				"%s returned a malformed entry %s" % [label, str(entry)])
			ok = false
			continue
		var code: String = str(entry.get("code", "E_UNSPECIFIED"))
		var warning: bool = code.begins_with("W_") or entry.get("severity") == ValidationReport.SEVERITY_WARNING
		var rid: Variant = record_id
		if rid == null:
			rid = entry.get("host_id", entry.get("record_id"))
		var field: Variant = entry.get("field")
		if field == null:
			field = default_field
		var message: String = "%s: %s" % [code, str(entry.get("message", ""))]
		if entry.get("path") != null:
			message += " (at %s)" % str(entry.path)
		report.add(ValidationReport.SEVERITY_WARNING if warning else ValidationReport.SEVERITY_ERROR,
			ValidationReport.E_DELEGATED, file, rid, field, message)
		if not warning:
			ok = false
	return ok


func _absent_or(value: Variant) -> String:
	return "absent" if value == null else "found %s, not a Callable" % type_string(typeof(value))


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
