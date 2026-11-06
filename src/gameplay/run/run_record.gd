## The persisted form of a run (run-structure R1, R7, R8.1; ADR-0004): the
## `RunState` <-> JSON Dictionary mapping and the validation of a loaded record.
## Meta holds the Dictionary and treats it as opaque.
##
## A loaded record is all floats: the JSON parser knows one number type. The
## seed therefore persists as `run_seed_hex` only, and [method normalised] turns every
## whole float back to an int, so `to_dict` -> `from_dict` -> `to_dict` is byte-identical
## JSON (run-structure AC-28). `match_attempts` is the one map keyed by a number:
## [method from_dict] gives it canonical `"<floor>"` keys, however they arrived.
##
## [method from_dict] never fails: a damaged save still has to reach `archive_run`
## (R8.1), so a field of the wrong shape takes its default. [method validate] is what
## decides whether a record may be resumed.
## [codeblock]
## var raw: Variant = meta.load_active_run()
## if raw != null and RunRecord.validate(raw, db) == OK:
##     var state: RunState = RunRecord.from_dict(raw)
## [/codeblock]
class_name RunRecord
extends RefCounted

## R1 `RUN_RECORD_SCHEMA_VERSION`; no migrations in v1.
const SCHEMA_VERSION: int = 1
## F1: a run has three bands, whatever their sizes.
const BAND_COUNT: int = 3
## Edge Cases "record grows past max_run_record_bytes": entries kept per summary.
const TRUNCATED_DAMAGE_ENTRIES: int = 20
## The bucket the rest of a truncated `damage_by_card` is summed into.
const TRUNCATED_DAMAGE_BUCKET: String = "other"

## Required top-level fields and their type after [method normalised]. Nullable
## fields (`reward_step`, `ended_at`, `result`) are checked by value.
const REQUIRED_FIELDS: Dictionary = {
	"data_version": TYPE_STRING,
	"engine_version": TYPE_STRING,
	"run_id": TYPE_STRING,
	"run_seed_hex": TYPE_STRING,
	"seed_source": TYPE_STRING,
	"hero_id": TYPE_STRING,
	"floors_per_run": TYPE_INT,
	"band_split": TYPE_ARRAY,
	"treasure_floors": TYPE_ARRAY,
	"boss_sequence": TYPE_ARRAY,
	"floor": TYPE_INT,
	"status": TYPE_STRING,
	"deck": TYPE_ARRAY,
	"treasures": TYPE_ARRAY,
	"drafts": TYPE_ARRAY,
	"match_attempts": TYPE_DICTIONARY,
	"match_summaries": TYPE_ARRAY,
	"draft_state": TYPE_DICTIONARY,
	"treasure_state": TYPE_DICTIONARY,
	"rng_snapshot": TYPE_DICTIONARY,
	"run_log": TYPE_DICTIONARY,
	"started_at": TYPE_INT,
	"updated_at": TYPE_INT,
	"play_seconds": TYPE_INT,
	"totals": TYPE_DICTIONARY,
}


## [param state] as the JSON Dictionary R7 saves: `RunRecord.to_dict()`. Every
## container is a copy. `run_seed` is left out on purpose (R1).
static func to_dict(state: RunState) -> Dictionary:
	var draft_rows: Array = []
	for record: DraftRecord in state.drafts:
		draft_rows.append(record.to_dict())
	return {
		"schema_version": state.schema_version,
		"data_version": state.data_version,
		"engine_version": state.engine_version,
		"run_id": state.run_id,
		"run_seed_hex": state.run_seed_hex,
		"seed_source": state.seed_source,
		"hero_id": state.hero_id,
		"floors_per_run": state.floors_per_run,
		"band_split": Array(state.band_split).duplicate(),
		"treasure_floors": Array(state.treasure_floors).duplicate(),
		"boss_sequence": Array(state.boss_sequence).duplicate(),
		"floor": state.floor,
		"status": state.status,
		"reward_step": state.reward_step,
		"deck": Array(state.deck).duplicate(),
		"treasures": Array(state.treasures).duplicate(),
		"drafts": draft_rows,
		"match_attempts": state.match_attempts.duplicate(true),
		"match_summaries": Array(state.match_summaries).duplicate(true),
		"draft_state": state.draft_state.duplicate(true),
		"treasure_state": state.treasure_state.duplicate(true),
		"rng_snapshot": state.rng_snapshot.duplicate(true),
		"run_log": state.run_log.duplicate(true),
		"started_at": state.started_at,
		"updated_at": state.updated_at,
		"ended_at": state.ended_at,
		"play_seconds": state.play_seconds,
		"result": (state.result as Dictionary).duplicate(true) if state.result is Dictionary else null,
		"totals": state.totals.duplicate(true),
	}


## A `RunState` from [param raw], whole numbers as ints and `run_seed` rebuilt from
## `run_seed_hex` (R1). Never fails: see the class notes.
static func from_dict(raw: Dictionary) -> RunState:
	var d: Dictionary = normalised(raw)
	var state: RunState = RunState.new()
	state.schema_version = _int_of(d, "schema_version", SCHEMA_VERSION)
	state.data_version = str(d.get("data_version", ""))
	state.engine_version = str(d.get("engine_version", ""))
	state.run_id = str(d.get("run_id", ""))
	state.run_seed_hex = str(d.get("run_seed_hex", ""))
	if is_seed_hex(state.run_seed_hex):
		state.run_seed = RngService.parse_hex_u64(state.run_seed_hex)
	state.seed_source = str(d.get("seed_source", RunState.SEED_RANDOM))
	state.hero_id = str(d.get("hero_id", ""))
	state.floors_per_run = _int_of(d, "floors_per_run", 0)
	state.band_split.assign(_ints_of(d, "band_split"))
	state.treasure_floors.assign(_ints_of(d, "treasure_floors"))
	state.boss_sequence.assign(_strings_of(d, "boss_sequence"))
	state.floor = _int_of(d, "floor", 1)
	state.status = str(d.get("status", RunState.STATUS_PRE_MATCH))
	var step: Variant = d.get("reward_step")
	state.reward_step = step if step is String else null
	state.deck.assign(_strings_of(d, "deck"))
	state.treasures.assign(_strings_of(d, "treasures"))
	for row: Variant in _array_of(d, "drafts"):
		if row is Dictionary:
			state.drafts.append(DraftRecord.from_dict(row))
	state.match_attempts = _attempts_of(d)
	for row: Variant in _array_of(d, "match_summaries"):
		if row is Dictionary:
			state.match_summaries.append(row)
	state.draft_state = _dictionary_of(d, "draft_state")
	state.treasure_state = _dictionary_of(d, "treasure_state")
	state.rng_snapshot = _dictionary_of(d, "rng_snapshot")
	state.run_log = _dictionary_of(d, "run_log")
	state.started_at = _int_of(d, "started_at", 0)
	state.updated_at = _int_of(d, "updated_at", 0)
	var ended: Variant = d.get("ended_at")
	state.ended_at = ended if ended is int else null
	state.play_seconds = _int_of(d, "play_seconds", 0)
	var result: Variant = d.get("result")
	state.result = result if result is Dictionary else null
	state.totals = _dictionary_of(d, "totals")
	return state


## R8.1: `OK`, or the first problem found, in the order `E_SCHEMA` (wrong
## `schema_version`, a field missing or of the wrong type), `E_DATA_VERSION`,
## `E_UNKNOWN_ID` (a hero, boss, card, treasure or bundle id that does not resolve),
## `E_CORRUPT` (an R1 invariant). A record of other data is reported as that even
## when its ids no longer resolve. A `draft_state` or `treasure_state` of a missing or
## unknown version is repaired on resume and is not rejected here (R1).
static func validate(raw: Dictionary, db: CardDatabase) -> Error:
	var d: Dictionary = normalised(raw)
	var version: Variant = d.get("schema_version")
	if not version is int or version != SCHEMA_VERSION or not _has_required_fields(d):
		return RunCodes.E_SCHEMA
	if d.data_version != db.data_version():
		return RunCodes.E_DATA_VERSION
	if not _ids_resolve(d, db):
		return RunCodes.E_UNKNOWN_ID
	if not _invariants_hold(d):
		return RunCodes.E_CORRUPT
	return OK


## [param value] with every whole float as an int, recursively, in a new container.
## The JSON parser gives floats for every number.
static func normalised(value: Variant) -> Variant:
	if value is float:
		var number: float = value
		return int(number) if is_finite(number) and number == floorf(number) else number
	if value is Dictionary:
		var source: Dictionary = value
		var out: Dictionary = {}
		for key: Variant in source:
			out[key] = normalised(source[key])
		return out
	if value is Array:
		var items: Array = []
		for item: Variant in (value as Array):
			items.append(normalised(item))
		return items
	return value


## True for a 16-digit hex seed, the R1 persisted form.
static func is_seed_hex(text: String) -> bool:
	return text.length() == 16 and text.is_valid_hex_number()


## The Edge Cases fallback for a record over `max_run_record_bytes`: in [param record],
## each summary's `damage_by_card` keeps its [constant TRUNCATED_DAMAGE_ENTRIES]
## highest entries (ties by id) plus the rest summed under
## [constant TRUNCATED_DAMAGE_BUCKET]. Returns true if anything was cut. Totals are
## not touched: they are computed before truncation.
static func truncate_summaries(record: Dictionary) -> bool:
	var changed: bool = false
	for summary: Dictionary in record.match_summaries:
		var damage: Dictionary = summary.get("damage_by_card", {})
		if damage.size() <= TRUNCATED_DAMAGE_ENTRIES:
			continue
		var ids: Array = damage.keys()
		ids.sort_custom(func(a: Variant, b: Variant) -> bool:
			return damage[a] > damage[b] or (damage[a] == damage[b] and str(a) < str(b)))
		var kept: Dictionary = {}
		var rest: int = 0
		for i: int in range(ids.size()):
			if i < TRUNCATED_DAMAGE_ENTRIES:
				kept[ids[i]] = damage[ids[i]]
			else:
				rest += int(damage[ids[i]])
		kept[TRUNCATED_DAMAGE_BUCKET] = rest
		summary["damage_by_card"] = kept
		changed = true
	return changed


static func _has_required_fields(d: Dictionary) -> bool:
	for field: String in REQUIRED_FIELDS:
		if not d.has(field) or typeof(d[field]) != REQUIRED_FIELDS[field]:
			return false
	return true


static func _ids_resolve(d: Dictionary, db: CardDatabase) -> bool:
	if not db.heroes().any(func(hero: Dictionary) -> bool: return hero.id == d.hero_id):
		return false
	for list_name: String in ["boss_sequence", "deck", "treasures"]:
		for id: Variant in d[list_name]:
			if not id is String or not db.has(id):
				return false
	for row: Variant in d.drafts:
		if row is Dictionary and row.get("picked_id") is String and not db.has(row.picked_id):
			return false
	return true


static func _invariants_hold(d: Dictionary) -> bool:
	var floors: int = d.floors_per_run
	var split: Array = d.band_split
	if d.boss_sequence.size() != floors or split.size() != BAND_COUNT:
		return false
	var split_sum: int = 0
	for s: Variant in split:
		if not s is int or int(s) < 1:
			return false
		split_sum += int(s)
	if split_sum != floors or d.floor < 1 or d.floor > floors:
		return false
	if not RunState.STATUSES.has(d.status) or not _reward_step_fits(d):
		return false
	if not is_seed_hex(d.run_seed_hex) or str(d.rng_snapshot.get("run_seed_hex")) != d.run_seed_hex:
		return false
	if not d.run_log.get("events") is Array:
		return false
	return _drafts_fit(d)


## `reward_step` names a kind exactly in `post_match_reward`.
static func _reward_step_fits(d: Dictionary) -> bool:
	var step: Variant = d.get("reward_step")
	if d.status == RunState.STATUS_POST_MATCH_REWARD:
		return DraftRecord.KINDS.has(step)
	return step == null


## R1: every DraftRecord is sound and unique per `(floor, kind)`, and the deck and
## treasure counts follow from the non-null picks.
static func _drafts_fit(d: Dictionary) -> bool:
	var seen: Dictionary = {}
	var bundle_picks: int = 0
	var treasure_picks: int = 0
	for row: Variant in d.drafts:
		if not DraftRecord.validate(row):
			return false
		var key: String = "%d/%s" % [row.floor, row.kind]
		if seen.has(key):
			return false
		seen[key] = true
		if row.picked_id != null:
			if row.kind == DraftRecord.KIND_BUNDLE:
				bundle_picks += 1
			else:
				treasure_picks += 1
	var starter_size: int = RecordSchemas.HERO_FIELDS.starter_deck["count"]
	var bundle_size: int = RecordSchemas.BUNDLE_FIELDS.cards["count"]
	return d.deck.size() == starter_size + bundle_size * bundle_picks and d.treasures.size() == treasure_picks


static func _int_of(d: Dictionary, key: String, fallback: int) -> int:
	return d[key] if d.get(key) is int else fallback


static func _array_of(d: Dictionary, key: String) -> Array:
	return d[key] if d.get(key) is Array else []


static func _dictionary_of(d: Dictionary, key: String) -> Dictionary:
	return d[key] if d.get(key) is Dictionary else {}


## `match_attempts` as [RunState] holds it: `"<floor>"` keys and int counts. A key may
## arrive as an int, a float or a number's text, by whichever road the record took; an
## entry that names no whole floor, or counts nothing whole, is dropped.
static func _attempts_of(d: Dictionary) -> Dictionary:
	var source: Dictionary = _dictionary_of(d, "match_attempts")
	var attempts: Dictionary = {}
	for key: Variant in source:
		var text: String = str(key)
		var floor_number: float = text.to_float()
		if text.is_valid_float() and floor_number == floorf(floor_number) and source[key] is int:
			attempts[str(int(floor_number))] = source[key]
	return attempts


static func _ints_of(d: Dictionary, key: String) -> Array:
	return _array_of(d, key).filter(func(item: Variant) -> bool: return item is int)


static func _strings_of(d: Dictionary, key: String) -> Array:
	return _array_of(d, key).filter(func(item: Variant) -> bool: return item is String)
