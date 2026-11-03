## Builders for the match-rules C1 / C2 / C14 plain-data records
## (design/gdd/match-rules.md C1 Data model, C2 CommandResult, C14 MatchResult;
## ADR-0001 Decision 1, ADR-0007 guardrail on flat records).
##
## Every record is a plain Dictionary of ints, Strings, bools, nulls and typed
## Arrays/Dictionaries of those, so `duplicate(true)` is the whole copy story
## (`MatchState.clone()`, story 017) and every record is JSON-representable
## (rng-event-log rule 14). Nothing here references a Node, an autoload or the
## engine (DD-T02). Derived values (`max_health`, `health`, `attack`,
## `has_windfury`, `max_attacks`, `attacks_remaining`) are never stored: they
## are functions on `RulesEngine` (C1 "Derived values (never stored)").
##
## Field names are normative and shared with `tests/helpers/match_factory.gd`,
## which builds its fixtures through these functions.
## [codeblock]
## var hero: Dictionary = MatchRecords.hero(1, MatchRecords.SIDE_PLAYER, 30)
## var imp: Dictionary = MatchRecords.minion(3, MatchRecords.SIDE_BOSS, 1, 1, ["taunt"], "imp")
## imp.enchantments.append(MatchRecords.enchantment(0, 2))
## [/codeblock]
class_name MatchRecords
extends RefCounted

## Side names as the event catalogue spells them (rng-event-log rule D);
## `MatchFactory.SIDE_*` mirrors these.
const SIDE_PLAYER: String = "player"
const SIDE_BOSS: String = "boss"
## Both sides in candidate order (player first — C4, C10).
const SIDES: Array[String] = [SIDE_PLAYER, SIDE_BOSS]
## Character kinds: heroes and minions share one representation (C1).
const KIND_HERO: String = "hero"
const KIND_MINION: String = "minion"
## CardInstance zones (C1).
const ZONES: Array[String] = ["deck", "hand", "board", "graveyard", "resolving"]
## Enchantment `expires` values other than null (C1).
const EXPIRES_END_OF_TURN: String = "end_of_turn"
## Keyword spelling of DD-M09 in snake_case (card-database CR-3).
const KEYWORD_WINDFURY: String = "windfury"
## MatchResult `result` values, from the player's side (C14).
const RESULTS: Array[String] = ["win", "loss", "fault"]
## C2 command types (the `Command.type` spellings).
const CMD_MULLIGAN: String = "mulligan"
const CMD_PLAY_CARD: String = "play_card"
const CMD_ATTACK: String = "attack"
const CMD_USE_HERO_POWER: String = "use_hero_power"
const CMD_CHOOSE: String = "choose"
const CMD_END_TURN: String = "end_turn"
const CMD_CONCEDE: String = "concede"
## Every C2 command type, in C2 table order.
const COMMAND_TYPES: Array[String] = [
	CMD_MULLIGAN, CMD_PLAY_CARD, CMD_ATTACK, CMD_USE_HERO_POWER, CMD_CHOOSE,
	CMD_END_TURN, CMD_CONCEDE,
]


## A C2 Command: `{type, issuer, ...args}` — [param type] one of
## [constant COMMAND_TYPES], [param issuer] `"player"` or `"boss"` (stamped by
## `MatchDriver`, ADR-0008), [param args] merged in (e.g. `hand_index`).
## [codeblock]
## var play: Dictionary = MatchRecords.command(MatchRecords.CMD_PLAY_CARD, "player", {"hand_index": 0, "position": 0})
## [/codeblock]
static func command(type: String, issuer: String, args: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"type": type, "issuer": issuer}
	out.merge(args, true)
	return out


## The C2 `mulligan(keep_mask)` command; [param keep_mask] has one bool per
## card in hand, `true` = keep (all `true` is a legal "keep all").
## [codeblock]
## engine.submit(MatchRecords.mulligan([true, false, false]))
## [/codeblock]
static func mulligan(keep_mask: Array, issuer: String = SIDE_PLAYER) -> Dictionary:
	return command(CMD_MULLIGAN, issuer, {"keep_mask": keep_mask.duplicate()})


## The C2 `end_turn` command from [param issuer].
static func end_turn(issuer: String) -> Dictionary:
	return command(CMD_END_TURN, issuer)


## A C1 Character base, shared by heroes and minions: `entity_id`,
## `controller`, `base_attack`, `base_health`, `enchantments[]`,
## `damage_taken`, `keywords`, `attacks_used`, `frozen`, `frozen_on_turn`,
## `silenced`. Use [method hero] or [method minion] for a complete record.
## [codeblock]
## var c: Dictionary = MatchRecords.character(5, "player", 2, 3, ["taunt"])
## [/codeblock]
static func character(entity_id: int, controller: String, base_attack: int, base_health: int, keywords: Array = []) -> Dictionary:
	return {
		"entity_id": entity_id,
		"controller": controller,
		"base_attack": base_attack,
		"base_health": base_health,
		"enchantments": [] as Array[Dictionary],
		"damage_taken": 0,
		"keywords": Array(keywords, TYPE_STRING, &"", null),
		"attacks_used": 0,
		"frozen": false,
		"frozen_on_turn": 0,
		"silenced": false,
	}


## A hero (C1): the Character shape plus `kind = "hero"` and `armor`, with
## `base_attack = 0`. Its current health is always derived from
## [param base_health] (the starting health) and `damage_taken` — there is no
## stored hero `health` (C1, C9, F2).
## [codeblock]
## var hero: Dictionary = MatchRecords.hero(1, "player", 30)
## [/codeblock]
static func hero(entity_id: int, controller: String, base_health: int) -> Dictionary:
	var record: Dictionary = character(entity_id, controller, 0, base_health)
	record["kind"] = KIND_HERO
	record["armor"] = 0
	return record


## A minion (C1): the Character shape plus `kind = "minion"`, `def_id`,
## `summoning_sick` (true on entering play, DD-M10) and `summoned_on_turn`.
## [codeblock]
## var m: Dictionary = MatchRecords.minion(4, "boss", 3, 2, ["rush"], "raider", 5)
## [/codeblock]
static func minion(entity_id: int, controller: String, base_attack: int, base_health: int, keywords: Array = [], def_id: String = "", summoned_on_turn: int = 0) -> Dictionary:
	var record: Dictionary = character(entity_id, controller, base_attack, base_health, keywords)
	record["kind"] = KIND_MINION
	record["def_id"] = def_id
	record["summoning_sick"] = true
	record["summoned_on_turn"] = summoned_on_turn
	return record


## A Weapon (C1): `entity_id`, `def_id`, `attack`, `durability`, `keywords`,
## `enchantments[]`. Lives in `PlayerState.weapon`; the hero's derived attack
## adds its `attack` (C1).
## [codeblock]
## var axe: Dictionary = MatchRecords.weapon(9, "war_axe", 2, 2, ["windfury"])
## [/codeblock]
static func weapon(entity_id: int, def_id: String, attack: int, durability: int, keywords: Array = []) -> Dictionary:
	return {
		"entity_id": entity_id,
		"def_id": def_id,
		"attack": attack,
		"durability": durability,
		"keywords": Array(keywords, TYPE_STRING, &"", null),
		"enchantments": [] as Array[Dictionary],
	}


## An Enchantment (C1): `{source_entity_id | null, attack_delta,
## health_delta, keywords_added[], is_aura, expires (null | "end_of_turn")}`.
## Auras are recomputed each step, never persisted (C10).
## [codeblock]
## var buff: Dictionary = MatchRecords.enchantment(1, 1, [], 7, true)
## [/codeblock]
static func enchantment(attack_delta: int = 0, health_delta: int = 0, keywords_added: Array = [], source_entity_id: Variant = null, is_aura: bool = false, expires: Variant = null) -> Dictionary:
	return {
		"source_entity_id": source_entity_id,
		"attack_delta": attack_delta,
		"health_delta": health_delta,
		"keywords_added": Array(keywords_added, TYPE_STRING, &"", null),
		"is_aura": is_aura,
		"expires": expires,
	}


## A CardInstance (C1): `instance_id` (from `next_entity_id`), `def_id`
## (looked up in the Card Database), `zone` (one of [constant ZONES]) and
## `cost_modifiers[]` (enchantments on the card while in hand).
## [codeblock]
## var card: Dictionary = MatchRecords.card_instance(12, "war_starter_01", "hand")
## [/codeblock]
static func card_instance(instance_id: int, def_id: String, zone: String = "deck") -> Dictionary:
	return {"instance_id": instance_id, "def_id": def_id, "zone": zone, "cost_modifiers": [] as Array[Dictionary]}


## A CommandResult (C2): `{accepted, rejection: null | {code, detail},
## events: [seq_first, seq_last]}`. Illegal moves are data, never exceptions.
## [codeblock]
## var r: Dictionary = MatchRecords.command_result(false, "NOT_ENOUGH_MANA", "cost 3, mana 2")
## [/codeblock]
static func command_result(accepted: bool, code: String = "", detail: String = "", seq_first: int = 0, seq_last: int = 0) -> Dictionary:
	return {
		"accepted": accepted,
		"rejection": null if accepted else {"code": code, "detail": detail},
		"events": [seq_first, seq_last] as Array[int],
	}


## Per-side Run Structure stats (C1 `PlayerState.stats`, C14), all zero.
static func empty_stats() -> Dictionary:
	return {"damage_dealt_by_card": {}, "damage_taken": 0, "cards_played": 0, "minions_summoned": 0}


## A MatchResult (C14): `{result: win | loss | fault, winner: player | boss |
## null, reason, floor, turns, turns_per_side, stats{player, boss},
## final_health{player, boss}}`. A fault always carries `winner = null`. The
## record carries no seed (DD-R09).
## [codeblock]
## var res: Dictionary = MatchRecords.match_result("win", "player", "hero_dead", 3, 14)
## [/codeblock]
static func match_result(result: String, winner: Variant, reason: String, floor_number: int, turns: int) -> Dictionary:
	return {
		"result": result,
		"winner": null if result == "fault" else winner,
		"reason": reason,
		"floor": floor_number,
		"turns": turns,
		"turns_per_side": {SIDE_PLAYER: 0, SIDE_BOSS: 0},
		"stats": {SIDE_PLAYER: empty_stats(), SIDE_BOSS: empty_stats()},
		"final_health": {SIDE_PLAYER: 0, SIDE_BOSS: 0},
	}
