## One screen transition (run-ui F2, U4; ADR-0011 Decision 1): `t_transition` as a
## single reveal tween on the shell's `TransitionLayer`. The layer starts opaque and
## fades out, so the new screen is up from the input frame and any input can end the
## fade at once. Shares ADR-0009's tween convention: no `AnimationPlayer`.
## [codeblock]
## var transition := Transition.new(layer, ui_config)
## transition.set_motion("fast", false)
## transition.finished.connect(_on_done)
## transition.run(&"fade")
## [/codeblock]
class_name Transition
extends RefCounted

## The transition ended, by running out or by [method skip]. At zero duration it fires
## inside [method run].
signal finished

var _layer: CanvasItem
var _config: Dictionary
var _speed: String = RunUiConfig.SPEED_NORMAL
var _reduce_motion: bool = false
var _tween: Tween = null


## [param layer] is what fades; [param ui_config] the `config("run_ui")` body.
func _init(layer: CanvasItem, ui_config: Dictionary) -> void:
	_layer = layer
	_config = ui_config


## Sets the `anim_speed` label and `reduce_motion` flag later runs use.
## Example: `transition.set_motion("instant", false)`.
func set_motion(anim_speed: String, reduce_motion: bool) -> void:
	_speed = anim_speed
	_reduce_motion = reduce_motion


## True while a transition is running.
func is_running() -> bool:
	return _tween != null


## Runs [param kind] (a `transition_ms` key). Returns [signal finished].
func run(kind: StringName) -> Signal:
	skip()
	var ms: int = RunUiConfig.t_transition(_config, kind, _speed, _reduce_motion)
	if ms <= 0:
		_layer.modulate.a = 0.0
		finished.emit()
		return finished
	_layer.modulate.a = 1.0
	_tween = _layer.create_tween()
	_tween.tween_property(_layer, "modulate:a", 0.0, ms / RunUiConfig.MS_PER_S).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(skip)
	return finished


## Ends a running transition at its end state now; does nothing when none runs.
func skip() -> void:
	if _tween == null:
		return
	_tween.kill()
	_tween = null
	_layer.modulate.a = 0.0
	finished.emit()
