## One animation step (match-ui U4.1; ADR-0009 Key Interfaces): what to show,
## for which entities, for how long at `anim_speed = normal`, and the
## idempotent `apply_final` that sets the presenters to the view-state for it.
##
## Steps are built by [method MatchViewState.apply] (pure, from events only) and
## scheduled by the `AnimationQueue` (match-ui story 002). A step holds no Node
## and no rules object: `entity_ids` are the engine's entity / instance ids,
## `data` carries the few payload numbers a presenter draws (`amount`, `code`,
## `source`), and `apply_final` is bound by `MatchView` to its presenters
## (story 004) — an unbound step's `apply_final` is an empty `Callable`.
## [codeblock]
## var steps: Array[AnimStep] = view_state.apply(event)
## for step: AnimStep in steps:
##     print(step.kind, step.entity_ids, step.base_duration_s, step.group_id)
## [/codeblock]
class_name AnimStep
extends RefCounted

## Step kinds (match-ui F3 base-duration names plus the U3 table's extra
## kinds). The `config("match_ui").d_base` key for a kind is its name.
const PLAY_CARD: StringName = &"play_card"
const ATTACK_LUNGE: StringName = &"attack_lunge"
const DAMAGE_POP: StringName = &"damage_pop"
const HEAL_POP: StringName = &"heal_pop"
const DEATH_GROUP: StringName = &"death_group"
const GAP_CLOSE: StringName = &"gap_close"
const DRAW: StringName = &"draw"
const BURN: StringName = &"burn"
const SHIELD_POP: StringName = &"shield_pop"
const BADGE: StringName = &"badge"
const STAT_RECOLOUR: StringName = &"stat_recolour"
const TURN_BANNER: StringName = &"turn_banner"
const INTENT_SHOW: StringName = &"intent_show"
const INTENT_COMMIT: StringName = &"intent_commit"
const OVERLAY_OPEN: StringName = &"overlay_open"
const OVERLAY_CLOSE: StringName = &"overlay_close"
const REJECT_SHAKE: StringName = &"reject_shake"
const END_BANNER: StringName = &"end_banner"
const MULLIGAN_OPEN: StringName = &"mulligan_open"
const MULLIGAN_FLIP: StringName = &"mulligan_flip"
const DECK_TICK: StringName = &"deck_tick"
const FATIGUE_LABEL: StringName = &"fatigue_label"
const DISCARD: StringName = &"discard"
const SUMMON: StringName = &"summon"
const SUMMON_FAILED: StringName = &"summon_failed"
const WEAPON_UPDATE: StringName = &"weapon_update"
const WEAPON_SHATTER: StringName = &"weapon_shatter"
const POWER_PRESS: StringName = &"power_press"
const POWER_RELIGHT: StringName = &"power_relight"
const ATTACK_RETURN: StringName = &"attack_return"
const RIM_GLOW: StringName = &"rim_glow"
const FIZZLE: StringName = &"fizzle"
## U6.6: the boss's Choice, the "boss discovers…" label, with no options.
const BOSS_DISCOVERS: StringName = &"boss_discovers"
## A treasure's hook resolved: its tray chip flares (`data.host_id`).
const TREASURE_FLARE: StringName = &"treasure_flare"

## What the step shows (one of the kind constants above).
var kind: StringName
## The entities the step animates; presenters claim a step through `owns(entity_ids)`.
var entity_ids: Array[int] = []
## The authored duration at `anim_speed = normal` (F3 `d_base`), from `config("match_ui")`.
var base_duration_s: float = 0.0
## Idempotent; sets the presenters to the view-state for this step. Bound by `MatchView`.
var apply_final: Callable = Callable()
## The `seq` of the step's command-root event (U4.2): steps sharing it form a command group.
var group_id: int = 0
## The `seq` of the event that produced the step.
var seq: int = 0
## Plays together with the step before it in the same group (U4.2: stat recolours, badges).
var parallel_ok: bool = false
## Payload values a presenter draws (`amount`, `code`, `source`, …); never a hidden `card_id`.
var data: Dictionary = {}
## Impact extras at `normal` speed, `{hit_stop_ms, shake_ms, slow_ms}` (F3; match-rules
## Game Feel). The queue drops them at `fast`, `instant` and under `reduce_motion`.
var impact: Dictionary = {}
## What the queue kept of [member impact] when the step started, in ms on its clock:
## `{hit_stop_ms, shake_ms, slow_ms}`, 0 where dropped. Presenters read this, never
## [member impact]; it is outside [method signature], being the queue's and not the view's.
var live_impact: Dictionary = {}
## For a coalesced pop (U4.3): the original steps, in `seq` order; their
## `apply_final`s run, in that order, when this step ends. Empty otherwise.
var members: Array[AnimStep] = []

var _final_ran: bool = false


## A step of [param step_kind] for [param ids], lasting [param duration_s] at
## `normal`, in command group [param group], produced by event [param event_seq].
## [codeblock]
## var step := AnimStep.new(AnimStep.DAMAGE_POP, [7], 0.4, 12, 14)
## [/codeblock]
func _init(step_kind: StringName = &"", ids: Array[int] = [], duration_s: float = 0.0, group: int = 0, event_seq: int = 0) -> void:
	kind = step_kind
	entity_ids = ids.duplicate()
	base_duration_s = duration_s
	group_id = group
	seq = event_seq


## Ends the step: calls `apply_final` (no arguments — `MatchView` binds the
## step into it) at most once, after every member's [method run_final] in
## order. Idempotent (U4.1): a second call does nothing. Called only by the
## `AnimationQueue`'s clock or its `skip_all`.
## [codeblock]
## step.apply_final = presenter.apply_final.bind(step)
## step.run_final()   # presenter.apply_final(step), once
## [/codeblock]
func run_final() -> void:
	if _final_ran:
		return
	_final_ran = true
	for member: AnimStep in members:
		member.run_final()
	if apply_final.is_valid():
		apply_final.call()


## True once [method run_final] has run.
func final_ran() -> bool:
	return _final_ran


## The fields two projections of one stream must agree on (match-ui AC L1:
## kind, entity ids, base duration, group id), plus `seq`, `parallel_ok` and
## `data` — as a plain Dictionary, so step lists compare with `==`.
## [codeblock]
## assert(a.signature() == b.signature())
## [/codeblock]
func signature() -> Dictionary:
	return {
		"kind": kind,
		"entity_ids": entity_ids.duplicate(),
		"base_duration_s": base_duration_s,
		"group_id": group_id,
		"seq": seq,
		"parallel_ok": parallel_ok,
		"data": data.duplicate(true),
	}
