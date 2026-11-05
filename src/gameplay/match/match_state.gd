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
## The action a pending choice paused (match-rules story 016; ADR-0007
## Decision 1), all plain data so `clone()` is a `duplicate(true)` (story 017).
## `suspended_queue`: the C10 trigger queue Q at the pause — step Dictionaries
## `{point, ctx, cause_seq}`, front first. `suspended_steps`: the action's step
## count so far (`resolution_step_cap` counts across the pause).
## `suspended_action`: `{}` when nothing is paused, else `{origin_phase,
## cause_seq, frame, stages}` — the phase `choose` returns to, the `cause_seq`
## of the paused step (the resumed effect's events keep it), and the rest of
## the command as `RulesEngine` stages (see `RulesEngine.choose` docs). The
## resolver's own continuation lives in `effects.pending_choice`.
var suspended_queue: Array[Dictionary] = []
var suspended_steps: int = 0
var suspended_action: Dictionary = {}
## null until `Ended`, then the `MatchResult` (C14, [method MatchRecords.match_result]).
var result: Variant = null
## The next id handed to a character, weapon or card instance (C1).
var next_entity_id: int = FIRST_ENTITY_ID
## The match's [HookRegistry] (ADR-0005), created by `RulesEngine.start` at
## C3 step 1 before the resolver binds. Null on a bare `from_config` state.
var hooks: HookRegistry = null
## `EffectRuntime {once_marks, counters, per_turn, pending_choice, aura_hosts}` — plain
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


## The state-level half of `RulesEngine.clone()` (C2 `MatchState.clone()`;
## ADR-0007 Decision 3, ADR-0005 Decision 7; match-rules story 017): a new
## `MatchState` with every plain-data field copied **by value**
## (`duplicate(true)` — `players` with every record and zone, `pending_choice`,
## the paused action `suspended_queue` / `suspended_steps` /
## `suspended_action`, `result`, `effects` — the `EffectRuntime` with its
## counters, marks and the resolver's `pending_choice` continuation) and the
## scalars; `hooks` is `hooks.copy()` (same entries, new Dictionaries,
## evaluators unset — the clone's resolver registers its own at `bind`). The
## two references are **not** copied: [param scratch_log] and [param stream]
## replace `log` and `rng_match` (the engine builds the detached scratch log
## and the stream copy). Nothing in the result is shared with this state.
## `suspended_queue` must stay a **deep** copy: `choose` on the clone clears
## the parked queue in place and stamps `ctx.queued` on each step it runs, so
## a shared or shallow copy would empty or alter the live engine's waiting
## triggers (code review 2026-11-04, MR-017 S5; pinned by the clone-replay
## suite's queued-Choice test).
## [codeblock]
## var copy: MatchState = state.clone(EventLog.new(cap, EventLog.SCOPE_MATCH), stream_copy)
## copy.players["boss"].hero.damage_taken = 99   # this state is unchanged
## [/codeblock]
func clone(scratch_log: RefCounted, stream: RefCounted) -> MatchState:
	var out: MatchState = MatchState.new()
	out.turn = turn
	out.active_side = active_side
	out.phase = phase
	out.players = players.duplicate(true)
	out.pending_choice = pending_choice.duplicate(true) if pending_choice is Dictionary else pending_choice
	out.suspended_queue = suspended_queue.duplicate(true)
	out.suspended_steps = suspended_steps
	out.suspended_action = suspended_action.duplicate(true)
	out.result = result.duplicate(true) if result is Dictionary else result
	out.next_entity_id = next_entity_id
	out.hooks = hooks.copy() if hooks != null else null
	out.effects = effects.duplicate(true)
	out.floor = floor
	out.log = scratch_log
	out.rng_match = stream
	return out


## A C1 PlayerState at C3 step 2 values: `hero` (a Character from
## [method MatchRecords.hero], or null before step 2), `mana_current` 0,
## `mana_max` 0, `crystal_bonus` 0 (raised only by
## `add_mana(side, n, temporary=false)` from an `on_match_start` hook — C5, F4),
## `temporary_crystals` 0 (this turn's crystals from `add_mana(side, n,
## temporary=true)`, removed again at the side's End step — C5; match-rules
## story 011), `deck` (index 0 is the top), `hand`, `board` (index 0 is leftmost),
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
		"temporary_crystals": 0,
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
	return {"once_marks": {}, "counters": {}, "per_turn": {}, "pending_choice": null, "aura_hosts": []}
