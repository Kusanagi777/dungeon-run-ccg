## Treasures: builds the `HookInstaller`s a match carries and owns the
## `treasure_state` schema and the pool membership predicate
## (design/gdd/treasures.md T3, T4, T5.2, T6; ADR-0005 Decision rules 5, 8, 10
## and Key Interfaces).
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
func pool(unlocked_keys: Dictionary, exclude_ids: Array) -> Array:
	var available: Array = []
	for def: Dictionary in _db.treasure_pool():
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


## True when [param treasure_state] is of [constant SCHEMA_VERSION]. A saved
## state comes back through JSON, where every number is a float.
static func _state_is_known(treasure_state: Dictionary) -> bool:
	var version: Variant = treasure_state.get("schema_version")
	return (version is int or version is float) and version == SCHEMA_VERSION
