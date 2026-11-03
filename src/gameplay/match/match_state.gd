## The one mutable match record a `RulesEngine` owns (design/gdd/match-rules.md
## C1 Data model, C3 step 1; ADR-0001 Decision 1, ADR-0007 Decision 1).
##
## Fields are exactly C1's: `turn`, `active_side`, `phase`,
## `players{player, boss}`, `pending_choice`, `result`, `next_entity_id`,
## `hooks`, `effects`, `floor`, plus the two references handed over in
## `MatchConfig` — the match `log` and the `rng_match` stream. The engine never
## creates, seeds or forks a stream (DD-T03; rng-event-log rule 3).
##
## Everything but `log`, `rng_match` and `hooks` is plain data: the
## `PlayerState` / Character / Weapon / CardInstance records are Dictionaries
## from [MatchRecords] and [method make_player_state], and `effects` is the
## `EffectRuntime` bag owned by Card Effects' resolver (ADR-0007). No field
## references a Node (DD-T02). Derived values are never stored (C1).
##
## Construction is `from_config(config)`; `RulesEngine.start(config)` creates
## the state this way, sets [member hooks], and runs C3 steps 1–6 on it.
## Tests build fixtures through `MatchFactory` (`make_match_state`, or
## `make_started_engine` for a state after setup).
## [codeblock]
## var state: MatchState = MatchState.from_config(config)
## state.players[MatchRecords.SIDE_PLAYER].hero = MatchRecords.hero(1, "player", 30)
## [/codeblock]
class_name MatchState
extends RefCounted

## Phase spellings (match-rules States and Transitions). A `*Turn.X` state is
## the phase `X` read together with [member active_side]: `PlayerTurn.Main` is
## `phase == PHASE_MAIN` with `active_side == "player"`.
const PHASE_SETUP: String = "setup"
const PHASE_MULLIGAN: String = "mulligan"
const PHASE_START: String = "start"
const PHASE_MAIN: String = "main"
const PHASE_END: String = "end"
const PHASE_RESOLVING: String = "resolving"
const PHASE_CHOICE: String = "choice"
const PHASE_ENDED: String = "ended"
## Every phase, in States-table order.
const PHASES: Array[String] = [
	PHASE_SETUP, PHASE_MULLIGAN, PHASE_START, PHASE_MAIN, PHASE_END,
	PHASE_RESOLVING, PHASE_CHOICE, PHASE_ENDED,
]
## The first entity id of a match (C1: ids are unique per match, assigned at
## creation from `next_entity_id`).
const FIRST_ENTITY_ID: int = 1

## Global turn counter: 0 during Setup and Mulligan, first turn = 1 (C1).
var turn: int = 0
## `"player"` or `"boss"` ([constant MatchRecords.SIDE_PLAYER] / `SIDE_BOSS`).
var active_side: String = MatchRecords.SIDE_PLAYER
## One of [constant PHASES].
var phase: String = PHASE_SETUP
## `{player: PlayerState, boss: PlayerState}` — see [method make_player_state].
var players: Dictionary[String, Dictionary] = {}
## null, or the engine's `ChoiceRequest` while `phase == "choice"` (C1, C2).
var pending_choice: Variant = null
## null until `Ended`, then the `MatchResult` (C14, [method MatchRecords.match_result]).
var result: Variant = null
## The next id handed to a character, weapon or card instance (C1).
var next_entity_id: int = FIRST_ENTITY_ID
## The match's [HookRegistry] (ADR-0005), created by `RulesEngine.start` at
## C3 step 1 before the resolver binds. Null on a bare `from_config` state.
var hooks: HookRegistry = null
## `EffectRuntime {once_marks, counters, per_turn, pending_choice}` — plain
## data whose code lives in `EffectResolver` (ADR-0007); see
## [method make_effect_runtime].
var effects: Dictionary = {}
## The floor this match is played on (`MatchConfig.floor`).
var floor: int = 0
## The match `EventLog` from `MatchConfig.log` (a reference; never owned).
## TODO(rng-event-log): type as `EventLog` once that class exists.
var log: RefCounted = null
## The memoised `match_<floor>` stream from `MatchConfig.rng_match` (a
## reference; never seeded or forked here). Typed `RefCounted` so the
## `RngStream` and its test double both fit.
var rng_match: RefCounted = null


## C3 step 1: the state a `MatchConfig` Dictionary produces before heroes,
## decks and hooks exist — turn 0, phase `setup`, player active, both
## `PlayerState`s empty with `hero = null`, an empty `EffectRuntime`, and the
## config's `floor`, `log` and `rng_match` taken by reference.
## [codeblock]
## var state: MatchState = MatchState.from_config(MatchFactory.make_match_config(1, rng, log))
## assert(state.rng_match == rng.stream("match_1"))
## [/codeblock]
static func from_config(config: Dictionary) -> MatchState:
	var state: MatchState = MatchState.new()
	state.floor = int(config.floor)
	state.log = config.log
	state.rng_match = config.rng_match
	state.effects = make_effect_runtime()
	for side: String in MatchRecords.SIDES:
		state.players[side] = make_player_state()
	return state


## A C1 PlayerState at C3 step 2 values: `hero` (a Character from
## [method MatchRecords.hero], or null before step 2), `mana_current` 0,
## `mana_max` 0, `crystal_bonus` 0 (raised only by
## `add_mana(side, n, temporary=false)` from an `on_match_start` hook — C5, F4),
## `deck` (index 0 is the top), `hand`, `board` (index 0 is leftmost),
## `weapon` (null or a Weapon), `hero_power {def_id, used_this_turn}`,
## `fatigue_counter` 0, `graveyard`, `resolving` (the CardInstance of a spell
## being cast — zone `resolving`, C6 spells step 2 — between `spell_cast` and
## `card_to_graveyard`; empty otherwise; match-rules story 010), `turns_taken`
## 0 and the Run Structure `stats` block.
## [codeblock]
## var ps: Dictionary = MatchState.make_player_state(MatchRecords.hero(1, "player", 30), "power_war")
## [/codeblock]
static func make_player_state(hero: Variant = null, hero_power_def_id: String = "") -> Dictionary:
	return {
		"hero": hero,
		"mana_current": 0,
		"mana_max": 0,
		"crystal_bonus": 0,
		"deck": [] as Array[Dictionary],
		"hand": [] as Array[Dictionary],
		"board": [] as Array[Dictionary],
		"weapon": null,
		"hero_power": {"def_id": hero_power_def_id, "used_this_turn": false},
		"fatigue_counter": 0,
		"graveyard": [] as Array[Dictionary],
		"resolving": [] as Array[Dictionary],
		"turns_taken": 0,
		"stats": MatchRecords.empty_stats(),
	}


## An empty `EffectRuntime` (ADR-0007 Decision 1): `once_marks`, `counters`,
## `per_turn` and `pending_choice`. Never holds a Callable, a Node or an object
## reference — `clone()` copies it by value.
static func make_effect_runtime() -> Dictionary:
	return {"once_marks": {}, "counters": {}, "per_turn": {}, "pending_choice": null}
