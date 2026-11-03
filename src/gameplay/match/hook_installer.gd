## One host's hook effects, as Treasures and the boss passive hand them to a
## match (design/gdd/treasures.md T3.2; ADR-0005 Key Interfaces; match-rules
## Interactions hook table).
##
## Plain data with no behaviour: the host (`host_kind`, `host_id`), the side
## that owns it (`side`, `"player"` for treasures, `"boss"` for the passive),
## its `effects[]` in definition order (a copy of `TreasureDef.effects` or
## `BossDef.passive`; card-effects C1 effect objects) and its run-tier `state`
## blob (`treasure_state.by_treasure[host_id]`, `{}` in v1). It references no
## engine, registry, log or Node (ADR-0005 rule 6). Treasures builds these
## (`Treasures.installers_for`, `passive_installer`); `MatchConfig` carries
## them in `player.hook_installers` then `boss.hook_installers`.
## [codeblock]
## var signet := HookInstaller.new(HookInstaller.HOST_KIND_TREASURE, "treasure_worn_signet",
##         &"player", treasure_def.effects)
## var same := HookInstaller.from_dict(signet.to_dict())
## [/codeblock]
class_name HookInstaller
extends RefCounted

## `host_kind` of a treasure installer.
const HOST_KIND_TREASURE: StringName = &"treasure"
## `host_kind` of the boss passive's installer.
const HOST_KIND_PASSIVE: StringName = &"passive"

## `&"treasure"` or `&"passive"`.
var host_kind: StringName = &""
## The treasure id or the boss id; unique per match (ADR-0005 rule 5).
var host_id: String = ""
## The owning side, `&"player"` or `&"boss"` (ADR-0005 rule 3).
var side: StringName = &""
## The host's effect objects, in array order (installation order, rule 2).
var effects: Array[Dictionary] = []
## Run-tier state blob, read-only to the match (ADR-0005 rule 8).
var state: Dictionary = {}


## Builds an installer. [param host_effects] is copied by value.
func _init(kind: StringName = &"", id: String = "", owner_side: StringName = &"", host_effects: Array = [], host_state: Dictionary = {}) -> void:
	host_kind = kind
	host_id = id
	side = owner_side
	effects.assign(host_effects.duplicate(true))
	state = host_state.duplicate(true)


## A by-value Dictionary `{host_kind, host_id, side, effects, state}`.
func to_dict() -> Dictionary:
	return {
		"host_kind": host_kind,
		"host_id": host_id,
		"side": side,
		"effects": effects.duplicate(true),
		"state": state.duplicate(true),
	}


## The inverse of [method to_dict]; `effects` and `state` default to empty.
static func from_dict(data: Dictionary) -> HookInstaller:
	return HookInstaller.new(
		StringName(data.host_kind), str(data.host_id), StringName(data.side),
		data.get("effects", []), data.get("state", {}))
