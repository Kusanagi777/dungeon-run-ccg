## One zone of the match view (ADR-0009 Decision 3 and Key Interfaces). A presenter
## draws its zone from what `MatchView` hands it, tweens on `step_started` and is
## authoritative only when a step's `apply_final` has run. The queue's clock ends a
## step, never a tween.
##
## `MatchView` calls, in this order: [method setup] once, [method bind] once, then
## [method on_step_started] and [method apply_final] for the steps
## [method claims] takes, [method present] after every step's final, and
## [method sync_report] after every drain in a debug build.
##
## The base class keeps the tweens and the spawned children (number pops) of each
## live step, so a subclass asks [method step_tween] and [method keep_for_step] and
## calls [method end_step] from `apply_final`. A tween never outlives its step.
## [codeblock]
## func on_step_started(step: AnimStep, d_eff: float) -> void:
##     step_tween(step).tween_property(self, "modulate:a", 1.0, d_eff)
##
## func apply_final(step: AnimStep) -> void:
##     end_step(step)
## [/codeblock]
@abstract class_name Presenter
extends Control

## The floating number every zone shares (story 005).
const NUMBER_POP_SCENE: PackedScene = preload("res://src/ui/match/number_pop.tscn")

## The shared read-only values of this view: config, palette, query.
var ui: MatchUiContext = null

# AnimStep → the Tweens it runs.
var _step_tweens: Dictionary = {}
# AnimStep → the child Nodes spawned for it.
var _step_children: Dictionary = {}


## Stores the [param context] every presenter reads from. Runs before [method bind].
func setup(context: MatchUiContext) -> void:
	ui = context


## Stores the projection this presenter reports against.
@abstract func bind(view_state: MatchViewState) -> void


## True when any id of [param entity_ids] is drawn by this presenter.
@abstract func owns(entity_ids: Array[int]) -> bool


## A step of this zone began: start its tween. Not called at `instant`.
@abstract func on_step_started(step: AnimStep, d_eff: float) -> void


## Idempotent: the step's visuals end. The numbers follow in [method present].
@abstract func apply_final(step: AnimStep) -> void


## One line per field whose display differs from the view-state; `[]` when equal.
@abstract func sync_report() -> Array[String]


## True when this presenter acts on [param step]. Steps with no entity (a banner)
## are claimed by kind, in the override.
func claims(step: AnimStep) -> bool:
	return owns(step.entity_ids)


## Shows [param state], the view-state as of the step that just ended:
## `{player, boss, turn, active_side, phase, pending_mulligan, pending_choice, result}`, its sides in
## the shape of [method MatchViewState.side]. Runs for every presenter after every
## step, so it must be cheap and idempotent.
func present(_state: Dictionary) -> void:
	return


## `AnimationQueue.drained`, after the final [method present]: one layout pass.
func on_drained() -> void:
	return


## `AnimationQueue.skipped`: every live tween dies and every pop goes, now.
func on_skipped() -> void:
	for step: Variant in _step_tweens.keys():
		end_step(step)
	for step: Variant in _step_children.keys():
		end_step(step)


## A tween on this presenter that lives and dies with [param step].
func step_tween(step: AnimStep) -> Tween:
	var tween: Tween = create_tween()
	if not _step_tweens.has(step):
		_step_tweens[step] = []
	(_step_tweens[step] as Array).append(tween)
	return tween


## Frees [param child] when [param step] ends.
func keep_for_step(step: AnimStep, child: Node) -> void:
	if not _step_children.has(step):
		_step_children[step] = []
	(_step_children[step] as Array).append(child)


## Kills [param step]'s tweens and frees its children: nothing of it outlives its
## `apply_final` (ADR-0009 Implementation Guidelines).
func end_step(step: AnimStep) -> void:
	for tween: Tween in _step_tweens.get(step, []):
		tween.kill()
	_step_tweens.erase(step)
	for child: Node in _step_children.get(step, []):
		if is_instance_valid(child):
			child.queue_free()
	_step_children.erase(step)


## U3 pops: [param pop]'s `amount`, as `−n` or `+n`, on an `ink` pill rising from
## [param centre] for [param d_eff] seconds, a child of this presenter until
## [param step] ends. [param centre] is in this presenter's coordinates.
func spawn_pop(step: AnimStep, pop: AnimStep, centre: Vector2, d_eff: float) -> void:
	var damage: bool = pop.kind == AnimStep.DAMAGE_POP
	var text: String = ("−%d" if damage else "+%d") % int(pop.data.get("amount", 0))
	var number: NumberPop = NUMBER_POP_SCENE.instantiate()
	add_child(number)
	number.show_number(text, ui.color("state_danger" if damage else "state_buff"), ui.color("ink"), int(ui.config.pop.font_px), centre)
	keep_for_step(step, number)
	var rise: Vector2 = number.position - Vector2(0, float(ui.config.pop.rise_px))
	step_tween(step).tween_property(number, "position", rise, d_eff)
