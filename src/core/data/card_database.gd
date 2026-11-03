## The Card Database: the one owner of game data (card-database CR-1..CR-9;
## ADR-0002). It runs `DataLoader` once at boot and holds the result.
##
## The composition root constructs it and calls `load(validators)` (boot
## epic); tests inject a `DataLoader` over a fixture root and a
## `ValidatorStubs` map. Nothing under `src/core/data/` references the
## composition root (ADR-0001, gate G3).
##
## [codeblock]
## var db: CardDatabase = CardDatabase.new(DataLoader.new("res://tests/fixtures/data/clean/"))
## var report: ValidationReport = db.load(validators)
## db.state() == CardDatabase.State.READY   # no errors in the report
## db.collectible_pool("war")               # CardDef[] id-ascending
## [/codeblock]
##
## States: `Unloaded → Loading → Ready | Failed` (States table). Lookups
## (`has`, `card`, `hero`, `hero_power`, `boss`, `treasure`, `bundle`,
## `cards_by_*`, `collectible_pool`, `bundle_pool`, `treasure_pool`,
## `bosses_in_band`, `heroes`) answer in `Ready` and — the one exception to
## "queries are illegal before Ready" (ADR-0002 Decision 4, 2026-11-03) —
## during CR-5 stage 7, for the loader's delegated validators, from the
## staged, id-sorted records that passed stage 6 (`_stage7_lookups_open`).
## `config()` and `data_version()` answer in `Ready` only; called during stage
## 7 they return `null` / `""`, log, and assert in a debug build.
## Every lookup reads one private source ([method _source]); Story 006 swaps
## the `Ready` source for the frozen snapshot (records are not yet read-only)
## and Story 007 computes `data_version`; Story 008 adds `reload()`,
## `Reloading`, `E_NOT_LOADED` and `E_NOT_SUPPORTED`. Single-thread-only.
class_name CardDatabase
extends RefCounted

## card-database States and Transitions. `RELOADING` is debug-only (Story 008).
enum State { UNLOADED, LOADING, READY, FAILED, RELOADING }

## What the stage-7 guard reports when `config()` / `data_version()` is called
## from a delegated validator.
const STAGE7_GUARD_MESSAGE: String = "CardDatabase.%s() is illegal before Ready (only lookups are open during stage 7)"

var _loader: DataLoader
var _state: State = State.UNLOADED
var _report: ValidationReport = ValidationReport.new()
## The loader's snapshot after a clean load, `null` otherwise. Story 006
## freezes it and builds the query tables from it.
var _snapshot: Variant = null
## The lookup source in `Ready`: the loader's staging after a clean load.
var _staging: Dictionary = {}
## The lookup source while `_stage7_lookups_open`.
var _stage7_staging: Dictionary = {}
## True only while the loader runs CR-5 stage 7 (ADR-0002 Decision 4).
var _stage7_lookups_open: bool = false
## CR-9 fingerprint; empty until Story 007 computes it at freeze.
var _data_version: String = ""


## A database that will load through `loader`, or through a `DataLoader` over
## `res://assets/data/` when none is given.
## Example: `CardDatabase.new(DataLoader.new("res://tests/fixtures/data/minimal/"))`.
func _init(loader: DataLoader = null) -> void:
	_loader = loader if loader != null else DataLoader.new()


## Runs the CR-5 load pipeline once, synchronously, and returns its report.
## `validators` is the composition-time map
## `{effects, ai_profile, unlock, treasure: Callable, configs: {<name>: Callable}}`
## (ADR-0002 Decision 4); each validator receives this database, whose
## lookups are open during stage 7. Any error leaves the state `FAILED` with
## no snapshot; none leaves it `READY`.
## Example: `if db.load(validators).has_errors(): show_data_error(db.report())`.
func load(validators: Dictionary) -> ValidationReport:
	_state = State.LOADING
	var result: DataLoader.LoadResult = _loader.run(validators, self)
	_report = result.report
	if _report.has_errors():
		_snapshot = null
		_staging = {}
		_state = State.FAILED
	else:
		_snapshot = result.snapshot
		_staging = result.staging
		_state = State.READY
	return _report


## The current state (States table). `UNLOADED` until `load()` is called.
## Example: `db.state() == CardDatabase.State.FAILED`.
func state() -> State:
	return _state


## The last load's report: empty before any load, warnings only when `READY`,
## the full report when `FAILED` (CR-8).
## Example: `print(db.report().to_text())`.
func report() -> ValidationReport:
	return _report


## True when a record with `id` exists (any type). Example: `db.has("war_iron_axe")`.
func has(id: String) -> bool:
	var source: Dictionary = _source("has")
	return not source.is_empty() and source.index_of.has(id)


## The CardDef `id`, or `null` and a logged error. Example: `db.card("war_iron_axe").cost`.
func card(id: String) -> Variant:
	return _record("card", "CardDef", id)


## The HeroDef `id`, or `null` and a logged error. Example: `db.hero("hero_war").starter_deck`.
func hero(id: String) -> Variant:
	return _record("hero", "HeroDef", id)


## The HeroPowerDef `id`, or `null` and a logged error. Example: `db.hero_power("power_sharpen").cost`.
func hero_power(id: String) -> Variant:
	return _record("hero_power", "HeroPowerDef", id)


## The BossDef `id`, or `null` and a logged error. Example: `db.boss("boss_rot_warden").band`.
func boss(id: String) -> Variant:
	return _record("boss", "BossDef", id)


## The TreasureDef `id`, or `null` and a logged error. Example: `db.treasure("treasure_t01").rarity`.
func treasure(id: String) -> Variant:
	return _record("treasure", "TreasureDef", id)


## The BundleDef `id`, or `null` and a logged error. Example: `db.bundle("bundle_war_weapons").cards`.
func bundle(id: String) -> Variant:
	return _record("bundle", "BundleDef", id)


## CardDefs of `set_id`, tokens included, id-ascending. Example: `db.cards_by_set("decay")`.
func cards_by_set(set_id: String) -> Array:
	return _filter("cards_by_set", "CardDef", func(r: Dictionary) -> bool: return r["set"] == set_id)


## CardDefs of `type` (`minion | spell | weapon`), id-ascending. Example: `db.cards_by_type("weapon")`.
func cards_by_type(type: String) -> Array:
	return _filter("cards_by_type", "CardDef", func(r: Dictionary) -> bool: return r["type"] == type)


## CardDefs carrying `tag`, id-ascending. Example: `db.cards_by_tag("weapons")`.
func cards_by_tag(tag: String) -> Array:
	return _filter("cards_by_tag", "CardDef", func(r: Dictionary) -> bool: return Array(r["tags"]).has(tag))


## CardDefs costing `cost`, id-ascending. Example: `db.cards_by_cost(2)`.
func cards_by_cost(cost: int) -> Array:
	return _filter("cards_by_cost", "CardDef", func(r: Dictionary) -> bool: return int(r["cost"]) == cost)


## CardDefs of `rarity`, id-ascending. Example: `db.cards_by_rarity("legendary")`.
func cards_by_rarity(rarity: String) -> Array:
	return _filter("cards_by_rarity", "CardDef", func(r: Dictionary) -> bool: return r["rarity"] == rarity)


## CR-6: CardDefs with `set ∈ {hero_set, neutral}` and `token == false`
## (never `boss`), id-ascending. Example: `db.collectible_pool("war")`.
func collectible_pool(hero_set: String) -> Array:
	return _filter("collectible_pool", "CardDef", func(r: Dictionary) -> bool:
		return (r["set"] == hero_set or r["set"] == "neutral") and not r.get("token", false))


## CR-6: BundleDefs with `set ∈ {hero_set, neutral}`, id-ascending. Example: `db.bundle_pool("war")`.
func bundle_pool(hero_set: String) -> Array:
	return _filter("bundle_pool", "BundleDef", func(r: Dictionary) -> bool:
		return r["set"] == hero_set or r["set"] == "neutral")


## CR-6: every TreasureDef, id-ascending. Example: `db.treasure_pool().size()`.
func treasure_pool() -> Array:
	return _filter("treasure_pool", "TreasureDef", Callable())


## CR-6: BossDefs of `band`, id-ascending (DD-R02 pool). Example: `db.bosses_in_band(1)`.
func bosses_in_band(band: int) -> Array:
	return _filter("bosses_in_band", "BossDef", func(r: Dictionary) -> bool: return int(r["band"]) == band)


## CR-6: every HeroDef, locked included, id-ascending. Example: `db.heroes()`.
func heroes() -> Array:
	return _filter("heroes", "HeroDef", Callable())


## The `config` body of `<config_name>.json` in `Ready`; `null` and a logged
## error for an unknown name or before `Ready` (during stage 7 the guard also
## asserts in a debug build — config bodies reach validators as the 7b
## `configs` argument instead). Example: `db.config("match_rules").board_size`.
func config(config_name: String) -> Variant:
	if _state != State.READY:
		_illegal_before_ready("config")
		return null
	var body: Variant = _snapshot.configs.get(config_name)
	if body == null:
		push_error("CardDatabase.config(): no config file \"%s.json\"" % config_name)
	return body


## The CR-9 fingerprint in `Ready` (empty until Story 007 computes it); `""`
## and a logged error before `Ready` (asserting during stage 7 in a debug
## build). Example: `RngService.new(run_seed, db.data_version())`.
func data_version() -> String:
	if _state != State.READY:
		_illegal_before_ready("data_version")
		return ""
	return _data_version


## Loader-only: opens the stage-7 lookups over `staging` (`LoadResult.staging`
## shape). Called by `DataLoader.run` before 7a.
func _begin_stage7(staging: Dictionary) -> void:
	_stage7_staging = staging
	_stage7_lookups_open = true


## Loader-only: closes the stage-7 lookups. Called by `DataLoader.run` after 7b.
func _end_stage7() -> void:
	_stage7_lookups_open = false
	_stage7_staging = {}


## The one lookup source: the stage-7 staging while open, the clean load's
## staging in `Ready`; otherwise `{}` and a logged error naming `caller`.
func _source(caller: String) -> Dictionary:
	if _stage7_lookups_open:
		return _stage7_staging
	if _state == State.READY:
		return _staging
	push_error("CardDatabase.%s(): queries are illegal in state %s (before Ready)" % [caller, State.keys()[_state]])
	return {}


func _record(caller: String, record_type: String, id: String) -> Variant:
	var source: Dictionary = _source(caller)
	if source.is_empty():
		return null
	var at: Variant = source.index_of.get(id)
	if at == null or at.type != record_type:
		push_error("CardDatabase.%s(): no %s \"%s\"" % [caller, record_type, id])
		return null
	return source.records[record_type][at.position]


func _filter(caller: String, record_type: String, keep: Callable) -> Array:
	var source: Dictionary = _source(caller)
	if source.is_empty():
		return []
	var records: Array = source.records[record_type]
	return records.duplicate() if not keep.is_valid() else records.filter(keep)


## Caller-bug report for `config()` / `data_version()` before `Ready`: during
## stage 7 the `_stage7_lookups_open` guard asserts in debug builds (the assert
## aborts only this function, so the caller still returns its fallback) and
## logs in release; otherwise it logs.
func _illegal_before_ready(caller: String) -> void:
	var message: String = STAGE7_GUARD_MESSAGE % caller
	if _stage7_lookups_open:
		assert(false, message)
		push_error(message)
		return
	push_error("CardDatabase.%s() is illegal in state %s (before Ready)" % [caller, State.keys()[_state]])
