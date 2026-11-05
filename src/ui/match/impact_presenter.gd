## The screen shake of an impact (match-ui Game Feel, Impact Moments; ADR-0009: impact
## extras live in the queue's clock and the presenters' tweens). A step whose `impact`
## holds `shake_ms` moves the table root [member target], 3 px and decaying. It uses
## `offset_transform_*`, which a parent container never resets (4.7), and never a camera.
## At `fast`, at `instant` and under `reduce_motion` the queue leaves `live_impact` at 0,
## so nothing moves. A skip ends it like any step's tween.
## [codeblock]
## var impact := ImpactPresenter.new()
## impact.target = table_root
## [/codeblock]
class_name ImpactPresenter
extends Presenter

## The node that shakes; set before [method setup].
var target: Control = null


## Stops being a hit target: this presenter draws nothing of its own.
func setup(context: MatchUiContext) -> void:
	super(context)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.offset_transform_enabled = true


func bind(_view_state: MatchViewState) -> void:
	return


func owns(_entity_ids: Array[int]) -> bool:
	return false


func claims(step: AnimStep) -> bool:
	return float(step.impact.get("shake_ms", 0)) > 0.0


func on_step_started(step: AnimStep, _d_eff: float) -> void:
	var shake_s: float = float(step.live_impact.get("shake_ms", 0.0)) / MS_PER_S
	if shake_s > 0.0:
		step_tween(step).tween_method(_shake, 1.0, 0.0, shake_s)


func apply_final(step: AnimStep) -> void:
	end_step(step)
	target.offset_transform_position = Vector2.ZERO


func on_skipped() -> void:
	super()
	target.offset_transform_position = Vector2.ZERO


func sync_report() -> Array[String]:
	var report: Array[String] = []
	if target.offset_transform_position != Vector2.ZERO:
		report.append("impact: the table rests %s off its place" % str(target.offset_transform_position))
	return report


## [param strength] runs 1 to 0: the swing and its size decay together.
func _shake(strength: float) -> void:
	var cfg: Dictionary = ui.config.impact
	var swing: float = sin(strength * TAU * float(cfg.shake_cycles))
	target.offset_transform_position = Vector2(swing * strength * float(cfg.shake_px), 0.0)
