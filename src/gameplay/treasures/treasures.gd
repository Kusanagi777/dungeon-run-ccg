## Treasures: builds the `HookInstaller`s a match carries and owns the
## `treasure_state` schema, the pool membership predicate and the stage-7b
## treasure validator (design/gdd/treasures.md T3, T4, T5.2, T6, T7; ADR-0005
## Decision rules 5, 8, 10 and Key Interfaces).
##
## A plain `RefCounted`, constructor-injected. It holds no log and draws no RNG,
## and it never reads or writes `RunState` (T5.1): the run hands it the ids and
## the `treasure_state`, and stores what it returns. `treasure_state` is read
## only in [method installers_for] and written only in [method collect_state]
## (T4).
##
## Warnings: ADR-0005 places the `run_warning` append with the caller, so
## [method installers_for] stays pure and the caller asks
## [method installer_warnings] for what to log, with the same arguments.
## [codeblock]
## var treasures := Treasures.new(db, db.config("treasures_balance"))
## var ids: Array = run_state.treasures
## for warning: Dictionary in Treasures.installer_warnings(ids, run_state.treasure_state):
##     run_log.append("run_warning", warning)
## config.player.hook_installers = treasures.installers_for(ids, run_state.treasure_state)
## config.boss.hook_installers = Treasures.passive_installer(boss_def)
## [/codeblock]
class_name Treasures
extends RefCounted

## `run_warning.code` for a repeated id dropped by [method installers_for] (T5.2).
const WARNING_DUPLICATE_TREASURE: String = "duplicate_treasure"
## `run_warning.code` for a `treasure_state` ignored on an unknown version (Edge Cases).
const WARNING_TREASURE_STATE_RESET: String = "treasure_state_reset"
## The `treasure_state.schema_version` this build reads and writes (T4).
const SCHEMA_VERSION: int = 1

## `rarity` is not a treasure rarity (T7).
const E_TR_RARITY: StringName = &"E_TR_RARITY"
## Not exactly one affinity tag, or an unknown tag, or too many others (T1, T7).
const E_TR_TAGS: StringName = &"E_TR_TAGS"
## `effects` empty or over `max_effects_per_treasure` (T7).
const E_TR_EFFECT_COUNT: StringName = &"E_TR_EFFECT_COUNT"
## A card op names a `set: boss` card (T7).
const E_TR_TOKEN_REF: StringName = &"E_TR_TOKEN_REF"
## `text` misses a shipped locale (T7): a warning, by its prefix.
const W_TR_TEXT: StringName = &"W_TR_TEXT"

## T1's vocabularies. They are format knowledge, like the loader's manifest: a new
## tag needs a code or design change, so they are not a tuning knob.
const AFFINITY_TAGS: Array[String] = ["war", "decay", "knowledge", "universal"]
## Heroes H-5's theme set.
const PLAN_TAGS: Array[String] = [
	"weapons", "aggro", "armour", "deathrattle", "sacrifice", "husk", "spells", "spell_damage", "draw",
]
const ARCHETYPE_TAGS: Array[String] = ["economy", "tempo", "value", "defensive", "wild"]
## T1: "plus 0-3" plan and archetype tags beside the one affinity.
const MAX_NON_AFFINITY_TAGS: int = 3
## The ops whose `card_id` T7 checks against the boss set.
const CARD_REF_OPS: Array[String] = ["summon", "add_to_hand", "equip"]
## The `set` boss-only cards carry (card-database CR-3).
const BOSS_SET: String = "boss"
## The `configs` key of the balance body at stage 7b, and the knob read from it.
const CONFIG_TREASURES_BALANCE: String = "treasures_balance"
const KNOB_MAX_EFFECTS: String = "max_effects_per_treasure"

## `treasures_balance.json` knob outside its safe range (Tuning Knobs).
const E_RANGE: StringName = &"E_RANGE"
## The rarity bands of `treasures_balance.json`, low band first.
const KNOB_COMMON_BAND: String = "common_band"
const KNOB_RARE_BAND: String = "rare_band"
## Tuning Knobs: the safe range of [constant KNOB_MAX_EFFECTS].
const MAX_EFFECTS_RANGE: Array[int] = [1, 5]
## Tuning Knobs: a band is at least this wide.
const MIN_BAND_WIDTH: float = 1.0
## The number knobs of `treasures_balance.json`, key to Tuning Knobs safe range:
## format knowledge, never a knob's value, which is the file's (ADR-0002). The
## `v_*` rows are the GDD's stated value ±50 %.
const NUMBER_KNOB_RANGES: Dictionary[String, Array] = {
	"v_card": [0.75, 2.25],
	"v_dmg": [0.25, 0.75],
	"v_hp": [0.175, 0.525],
	"v_stat": [0.25, 0.75],
	"v_token": [0.5, 1.5],
	"v_rush": [0.25, 0.75],
	"eta_mana": [0.4, 1.0],
	"eta_crystal": [0.4, 1.0],
	"eta_first": [0.4, 1.0],
	"eta_overheal": [0.4, 1.0],
}

## The owning side of a treasure and of a boss passive (ADR-0005 rule 3).
const _SIDE_PLAYER: StringName = &"player"
const _SIDE_BOSS: StringName = &"boss"

var _db: CardDatabase
## The `treasures_balance` config body, read once at construction.
var _balance_config: Dictionary


## A `Treasures` over [param db]. [param balance_config] is
## `db.config("treasures_balance")`.
func _init(db: CardDatabase, balance_config: Dictionary) -> void:
	_db = db
	_balance_config = balance_config


## One `HookInstaller` per treasure, in the order of [param treasure_ids] (pick
## order, T2.3), each `{host_kind: treasure, host_id, side: player, effects:
## copy of TreasureDef.effects, state: by_treasure[host_id] or {}}` (T3.2). Pure
## and idempotent: no RNG, no event, and [param treasure_state] is left as it
## was. A repeated id keeps its first occurrence; a [param treasure_state] of an
## unknown `schema_version` is ignored. [method installer_warnings] reports both.
## Every id resolves in Card Database: that is a `RunState` invariant
## (run-structure R1).
func installers_for(treasure_ids: Array, treasure_state: Dictionary) -> Array[HookInstaller]:
	var by_treasure: Dictionary = treasure_state.get("by_treasure", {}) if _state_is_known(treasure_state) else {}
	var installers: Array[HookInstaller] = []
	var seen: Dictionary = {}
	for id: String in treasure_ids:
		if seen.has(id):
			continue
		seen[id] = true
		installers.append(HookInstaller.new(HookInstaller.HOST_KIND_TREASURE, id, _SIDE_PLAYER,
			_db.treasure(id).effects, by_treasure.get(id, {})))
	return installers


## What the caller of [method installers_for] logs as `run_warning` for the same
## arguments: `{code: duplicate_treasure, treasure_id}` per dropped occurrence,
## then `{code: treasure_state_reset}` when the state is ignored. A
## `schema_version` that is missing counts as unknown (run-structure R1). Pure.
static func installer_warnings(treasure_ids: Array, treasure_state: Dictionary) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	var seen: Dictionary = {}
	for id: String in treasure_ids:
		if seen.has(id):
			warnings.append({"code": WARNING_DUPLICATE_TREASURE, "treasure_id": id})
		seen[id] = true
	if not _state_is_known(treasure_state):
		warnings.append({"code": WARNING_TREASURE_STATE_RESET})
	return warnings


## The `treasure_state` to store after `match_ended`, before save S2 (T4,
## run-structure R4). No v1 treasure persists state, so this is always the empty
## v1 shape, whatever the installed hosts or the C14 MatchResult
## (`MatchRecords.match_result`).
func collect_state(_hooks: HookRegistry, _result: Dictionary) -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "by_treasure": {}}


## The treasures available to a run, as TreasureDef records in
## `CardDatabase.treasure_pool()` order, which is id-ascending (T6, CR-6): those
## with `unlock == null` or `unlock.key` in [param unlocked_keys], less
## [param exclude_ids]. This is the one membership predicate (ADR-0005 rule 10):
## `RewardDraft.init_run` calls it and never re-derives it. Pure, and it draws no
## RNG. [param unlocked_keys] is a set, keys only; `MetaApi.unlocked_keys()` is
## an Array, so the caller converts once. [param exclude_ids] is held plus
## previously offered, which Reward Draft derives from `drafts[]` (reward-draft
## D7). Unlock state gates offers only: [method installers_for] never reads it
## (T6, Edge Cases "unlock revoked mid-run").
func pool(unlocked_keys: Dictionary, exclude_ids: Array, collection_id: String = "") -> Array:
	var available: Array = []
	for def: Dictionary in _db.treasure_pool(collection_id):
		var unlock: Variant = def.unlock
		if (unlock == null or unlocked_keys.has(unlock.key)) and not exclude_ids.has(def.id):
			available.append(def)
	return available


## The boss's installers (T3.1): `[]` when `passive` is null, else one
## `{host_kind: passive, host_id: <boss id>, side: boss, effects: [passive],
## state: {}}`. `BossDef.passive` is one effect object, not an array.
static func passive_installer(boss_def: Dictionary) -> Array[HookInstaller]:
	var passive: Variant = boss_def.get("passive")
	if passive == null:
		return []
	return [HookInstaller.new(HookInstaller.HOST_KIND_PASSIVE, boss_def.id, _SIDE_BOSS, [passive])]


## The T7 checks over [param defs], all of them, none short-circuited (ADR-0005
## `validate_treasure_defs`; treasures T1, T7): one entry
## `{code, host_id, field, message}` per fault, with severity from the prefix
## (`DataLoader._merge_delegated`). Pure, and it allocates its own report.
##
## - [constant E_TR_RARITY]: `rarity` not in `RecordSchemas.TREASURE_RARITIES`.
## - [constant E_TR_TAGS]: not exactly one affinity tag, an unknown tag, or more
##   than [constant MAX_NON_AFFINITY_TAGS] plan and archetype tags.
## - [constant E_TR_EFFECT_COUNT]: `effects` empty, or over
##   `max_effects_per_treasure` in [param balance], the `treasures_balance` body
##   (stage 7 never calls `config()`). A cap that is absent or not a whole number
##   is one `E_DELEGATED` entry per host, never a check against an empty cap
##   (the `Boot._effects_adapter` precedent); an empty `effects` needs no cap.
## - [constant E_TR_TOKEN_REF]: a [constant CARD_REF_OPS] op anywhere in an ops
##   tree naming a `set: boss` card. An unknown `card_id` is not this check's:
##   `EffectValidator` reports it as `E_FX_REF`, and with a null [param db] too.
##   [param db] answers `has` and `card`.
## - [constant W_TR_TEXT]: `text.en` absent. `en` is the one locale CR-3 ships.
##
## `W_TR_POWER`, in ADR-0005's closed set, is **not checked** here: no entry means
## "not looked at", never "in band" (story 013 is Blocked on the GDD's load-time F1).
## [codeblock]
## var rows: Array = Treasures.validate_treasure_defs([def], db, balance)
## rows[0].code   # &"E_TR_TAGS"
## [/codeblock]
static func validate_treasure_defs(defs: Array, db: Variant, balance: Dictionary) -> Array:
	var rows: Array = []
	var knob: Variant = balance.get(KNOB_MAX_EFFECTS)
	var cap: Variant = int(knob) if RecordSchemas.is_whole_number(knob) else null
	for def: Dictionary in defs:
		var id: String = def.get("id", "")
		var effects: Array = def.get("effects", [])
		_check_rarity(rows, id, def.get("rarity"))
		_check_tags(rows, id, def.get("tags", []))
		_check_effect_count(rows, id, effects, cap)
		for i: int in effects.size():
			if effects[i] is Dictionary:
				_check_card_refs(rows, id, effects[i].get("ops"), "effects/%d/ops" % i, db)
		_check_text(rows, id, def.get("text"))
	return rows


## The stage-7b `treasure` validator (ADR-0002 Decision 4): `DataLoader` calls it
## with the whole TreasureDef as [param rec]. It runs
## [method validate_treasure_defs] with the `treasures_balance` body from
## [param bodies], which is absent when that body failed stage 7a.
## Example, the Boot map entry: `"treasure": Treasures.validate_treasure_record`.
static func validate_treasure_record(_host_kind: StringName, _host_id: String, rec: Dictionary, db: Variant, bodies: Dictionary) -> Array:
	return validate_treasure_defs([rec], db, bodies.get(CONFIG_TREASURES_BALANCE, {}))


## The stage-7a validator of `treasures_balance.json` (ADR-0002 Decision 4;
## Tuning Knobs; card-database CR-5): `[]` for a body holding exactly the shipped
## keys, of the right type and inside their safe ranges. Otherwise one
## `{code, host_id: null, field, message}` per fault: `E_MISSING_FIELD` for an
## absent key, `E_UNKNOWN_FIELD` for an extra one, `E_SCHEMA` for a wrong type,
## [constant E_RANGE] for a value outside its range. A band that is not a
## `[low, high]` pair of numbers is `E_SCHEMA`; one narrower than
## [constant MIN_BAND_WIDTH] is [constant E_RANGE]; `common_band` reaching past
## the start of `rare_band` is one [constant E_RANGE] on `common_band`, and the
## two bands may touch. Static and pure, and it reads no default.
## Example, the Boot map entry: `configs.treasures_balance = Treasures.validate_config`.
## [codeblock]
## Treasures.validate_config(db.config("treasures_balance"), null)   # []
## Treasures.validate_config({}, null)[0].code                       # &"E_MISSING_FIELD"
## [/codeblock]
static func validate_config(body: Dictionary, _db: Variant) -> Array:
	var rows: Array = []
	for key: Variant in body:
		if key != KNOB_MAX_EFFECTS and key != KNOB_COMMON_BAND and key != KNOB_RARE_BAND and not NUMBER_KNOB_RANGES.has(key):
			rows.append(_config_row(ValidationReport.E_UNKNOWN_FIELD, str(key), "`%s` is not a treasures_balance key" % key))
	_check_max_effects(rows, body)
	var common_ok: bool = _check_band(rows, body, KNOB_COMMON_BAND)
	var rare_ok: bool = _check_band(rows, body, KNOB_RARE_BAND)
	if common_ok and rare_ok and float(body[KNOB_COMMON_BAND][1]) > float(body[KNOB_RARE_BAND][0]):
		rows.append(_config_row(E_RANGE, KNOB_COMMON_BAND, "`%s` %s overlaps `%s` %s" % [KNOB_COMMON_BAND, str(body[KNOB_COMMON_BAND]), KNOB_RARE_BAND, str(body[KNOB_RARE_BAND])]))
	for knob: String in NUMBER_KNOB_RANGES:
		_check_number_knob(rows, body, knob, NUMBER_KNOB_RANGES[knob])
	return rows


static func _check_max_effects(rows: Array, body: Dictionary) -> void:
	if not body.has(KNOB_MAX_EFFECTS):
		rows.append(_config_row(ValidationReport.E_MISSING_FIELD, KNOB_MAX_EFFECTS, "missing `%s`" % KNOB_MAX_EFFECTS))
	elif not RecordSchemas.is_whole_number(body[KNOB_MAX_EFFECTS]):
		rows.append(_config_row(ValidationReport.E_SCHEMA, KNOB_MAX_EFFECTS, "`%s` must be a whole number, found %s" % [KNOB_MAX_EFFECTS, str(body[KNOB_MAX_EFFECTS])]))
	elif int(body[KNOB_MAX_EFFECTS]) < MAX_EFFECTS_RANGE[0] or int(body[KNOB_MAX_EFFECTS]) > MAX_EFFECTS_RANGE[1]:
		rows.append(_config_row(E_RANGE, KNOB_MAX_EFFECTS, "`%s` is %s, outside the safe range %s" % [KNOB_MAX_EFFECTS, str(body[KNOB_MAX_EFFECTS]), str(MAX_EFFECTS_RANGE)]))


## True when [param knob] is a well-formed band wide enough to compare with its
## neighbour; a fault adds one row and returns false.
static func _check_band(rows: Array, body: Dictionary, knob: String) -> bool:
	if not body.has(knob):
		rows.append(_config_row(ValidationReport.E_MISSING_FIELD, knob, "missing `%s`" % knob))
		return false
	var band: Variant = body[knob]
	if not band is Array or (band as Array).size() != 2 or not _is_number(band[0]) or not _is_number(band[1]):
		rows.append(_config_row(ValidationReport.E_SCHEMA, knob, "`%s` must be a [low, high] pair of numbers, found %s" % [knob, str(band)]))
		return false
	if float(band[1]) - float(band[0]) < MIN_BAND_WIDTH:
		rows.append(_config_row(E_RANGE, knob, "`%s` %s is narrower than %s" % [knob, str(band), str(MIN_BAND_WIDTH)]))
		return false
	return true


static func _check_number_knob(rows: Array, body: Dictionary, knob: String, safe: Array) -> void:
	if not body.has(knob):
		rows.append(_config_row(ValidationReport.E_MISSING_FIELD, knob, "missing `%s`" % knob))
	elif not _is_number(body[knob]):
		rows.append(_config_row(ValidationReport.E_SCHEMA, knob, "`%s` must be a number, found %s" % [knob, str(body[knob])]))
	elif float(body[knob]) < float(safe[0]) or float(body[knob]) > float(safe[1]):
		rows.append(_config_row(E_RANGE, knob, "`%s` is %s, outside the safe range %s" % [knob, str(body[knob]), str(safe)]))


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


## One stage-7a entry: a config fault has no host.
static func _config_row(code: StringName, field: String, message: String) -> Dictionary:
	return {"code": code, "host_id": null, "field": field, "message": message}


static func _check_rarity(rows: Array, id: String, rarity: Variant) -> void:
	if not RecordSchemas.TREASURE_RARITIES.has(str(rarity)):
		rows.append(_row(E_TR_RARITY, id, "rarity", "rarity `%s` is not one of %s" % [str(rarity), str(RecordSchemas.TREASURE_RARITIES)]))


## [param tags] comes from a passed schema check: a list of strings.
static func _check_tags(rows: Array, id: String, tags: Array) -> void:
	var affinities: int = 0
	var others: int = 0
	var unknown: Array[String] = []
	for tag: String in tags:
		if AFFINITY_TAGS.has(tag):
			affinities += 1
		elif PLAN_TAGS.has(tag) or ARCHETYPE_TAGS.has(tag):
			others += 1
		else:
			unknown.append(tag)
	if affinities != 1:
		rows.append(_row(E_TR_TAGS, id, "tags", "%d affinity tags, expected exactly one of %s" % [affinities, str(AFFINITY_TAGS)]))
	if not unknown.is_empty():
		rows.append(_row(E_TR_TAGS, id, "tags", "unknown tags %s" % str(unknown)))
	if others > MAX_NON_AFFINITY_TAGS:
		rows.append(_row(E_TR_TAGS, id, "tags", "%d plan and archetype tags, at most %d" % [others, MAX_NON_AFFINITY_TAGS]))


## [param cap] is the whole-number knob, or `null` when it could not be read.
static func _check_effect_count(rows: Array, id: String, effects: Array, cap: Variant) -> void:
	if effects.is_empty():
		rows.append(_row(E_TR_EFFECT_COUNT, id, "effects", "`effects` is empty"))
	elif cap == null:
		rows.append(_row(ValidationReport.E_DELEGATED, id, "effects",
			"not checked: `%s` is absent or not a whole number in the %s config, so the effect cap is unknown (owner: Treasures)" % [KNOB_MAX_EFFECTS, CONFIG_TREASURES_BALANCE]))
	elif effects.size() > cap:
		rows.append(_row(E_TR_EFFECT_COUNT, id, "effects", "%d effects, at most %d" % [effects.size(), cap]))


## Walks an ops tree, nested `then` / `else` / `ops` / `options` included, as
## `EffectValidator` does. Shapes it does not understand are that validator's.
static func _check_card_refs(rows: Array, id: String, ops: Variant, path: String, db: Variant) -> void:
	if not ops is Array:
		return
	for i: int in ops.size():
		var op: Variant = ops[i]
		if not op is Dictionary:
			continue
		var at: String = "%s/%d" % [path, i]
		if CARD_REF_OPS.has(str(op.get("op"))) and _is_boss_card(op.get("card_id"), db):
			rows.append(_row(E_TR_TOKEN_REF, id, "effects", "`%s` of boss-only card `%s` at %s/card_id" % [op.op, op.card_id, at]))
		for key: String in ["then", "else", "ops"]:
			_check_card_refs(rows, id, op.get(key), "%s/%s" % [at, key], db)
		var options: Variant = op.get("options")
		if options is Array:
			for j: int in options.size():
				if options[j] is Dictionary:
					_check_card_refs(rows, id, options[j].get("ops"), "%s/options/%d/ops" % [at, j], db)


static func _is_boss_card(card_id: Variant, db: Variant) -> bool:
	if not card_id is String or db == null or not db.has(card_id):
		return false
	var record: Variant = db.card(card_id)
	return record is Dictionary and record.get("set") == BOSS_SET


static func _check_text(rows: Array, id: String, text: Variant) -> void:
	if not text is Dictionary or not text.has("en"):
		rows.append(_row(W_TR_TEXT, id, "text", "`text` has no `en`, the one locale CR-3 ships"))


## One stage-7b entry.
static func _row(code: StringName, id: String, field: String, message: String) -> Dictionary:
	return {"code": code, "host_id": id, "field": field, "message": message}


## True when [param treasure_state] is of [constant SCHEMA_VERSION]. A saved
## state comes back through JSON, where every number is a float.
static func _state_is_known(treasure_state: Dictionary) -> bool:
	var version: Variant = treasure_state.get("schema_version")
	return (version is int or version is float) and version == SCHEMA_VERSION
