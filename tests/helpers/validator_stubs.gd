## Stub validator maps for `CardDatabase.load(validators)` /
## `DataLoader.run(validators)` (story card-database/story-004; card-database
## CR-5 stage 7; ADR-0002 Decision 4; ADR-0007 Decision 8).
##
## Unit tests inject these explicitly: a missing validator is `E_DELEGATED`
## in every build type, so a test that wants a clean load passes
## [method accept_all]. Record validators take the stage-7b five arguments
## `(host_kind, host_id, value, db, configs)`; config validators the stage-7a
## two `(body, db)` — a lambda with fewer parameters fails at call time.
## Recording stubs close over a caller-owned Dictionary (lambdas capture locals
## by value, 4.5+).
##
## [codeblock]
## var db: CardDatabase = CardDatabase.new(DataLoader.new("res://tests/fixtures/data/clean/"))
## db.load(ValidatorStubs.accept_all())                   # Ready
## var map: Dictionary = ValidatorStubs.accept_all()
## map.effects = ValidatorStubs.rejecting_effects("bogus", "E_FX_OP")
## var calls: Dictionary = {}
## map.unlock = ValidatorStubs.recording(calls)           # calls.calls: [{host_kind, host_id, value, db, configs}]
## [/codeblock]
class_name ValidatorStubs
extends RefCounted

## The four stage-7b record validator keys (card-database CR-5 stage 7).
const RECORD_KEYS: Array[String] = ["effects", "ai_profile", "unlock", "treasure"]


## The full map: an accepting stub for each record key and for every
## `DataLoader.FILE_MANIFEST` config row the loader does not check itself
## (every config file except `card_database.json`). A fresh map each call.
static func accept_all() -> Dictionary:
	var configs: Dictionary = {}
	for name: String in config_names():
		configs[name] = accept_config()
	var map: Dictionary = {"configs": configs}
	for key: String in RECORD_KEYS:
		map[key] = accept_record()
	return map


## The config names `configs` must cover: each manifest config row's name
## without `.json`, except `card_database` (stage 4 checks it).
static func config_names() -> Array[String]:
	var names: Array[String] = []
	for row: Dictionary in DataLoader.FILE_MANIFEST:
		if row["class"] == "config" and row.name != "card_database.json":
			names.append(String(row.name).get_basename())
	return names


## A stage-7b record validator that accepts everything.
static func accept_record() -> Callable:
	return func(_host_kind: StringName, _host_id: String, _value: Variant, _db: Variant, _configs: Dictionary) -> Array:
		return []


## A stage-7a config validator that accepts everything.
static func accept_config() -> Callable:
	return func(_body: Dictionary, _db: Variant) -> Array:
		return []


## An `effects` validator that rejects every effect holding an op named `op`
## (in its `ops[]`) with one `{code, host_id, effect_id, path, message}` entry
## (the ADR-0007 shape) per offending op.
static func rejecting_effects(op: String, code: String) -> Callable:
	return func(_host_kind: StringName, host_id: String, effects: Variant, _db: Variant, _configs: Dictionary) -> Array:
		var out: Array = []
		for i: int in Array(effects).size():
			var ops: Array = effects[i].get("ops", [])
			for j: int in ops.size():
				if ops[j].get("op") == op:
					out.append({"code": code, "host_id": host_id, "effect_id": "%s.%d" % [host_id, i],
						"path": "effects[%d].ops[%d].op" % [i, j], "message": "unknown op \"%s\"" % op})
		return out


## A record validator that appends `{host_kind, host_id, value, db, configs}`
## to `calls["calls"]` (created when absent), runs `probe` (if given) with the
## same five arguments storing its return in the entry's `probe` key, and
## returns `[]`.
static func recording(calls: Dictionary, probe: Callable = Callable()) -> Callable:
	if not calls.has("calls"):
		calls["calls"] = []
	return func(host_kind: StringName, host_id: String, value: Variant, db: Variant, configs: Dictionary) -> Array:
		var entry: Dictionary = {"host_kind": host_kind, "host_id": host_id, "value": value, "db": db, "configs": configs}
		if probe.is_valid():
			entry["probe"] = probe.call(host_kind, host_id, value, db, configs)
		calls.calls.append(entry)
		return []


## A config validator that returns a deep copy of `entries` for any body.
static func config_returning(entries: Array) -> Callable:
	return func(_body: Dictionary, _db: Variant) -> Array:
		return entries.duplicate(true)


## A record validator that returns a deep copy of `entries` for any record.
static func record_returning(entries: Array) -> Callable:
	return func(_host_kind: StringName, _host_id: String, _value: Variant, _db: Variant, _configs: Dictionary) -> Array:
		return entries.duplicate(true)
