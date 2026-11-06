## The base of every U2 screen (ADR-0011 Decision 1 and Key Interfaces). Display only:
## a screen renders the read model [method bind] gave it and sends every action as
## [signal intent_requested]. It holds no `RunState`, `MatchDriver` or `MetaApi`.
## Re-`bind` is the update path, so a subclass rebuilds its children in `bind`.
## [codeblock]
## class_name PauseScreen extends Screen
## func bind(model: Dictionary) -> void:
##     clear()
##     add_child(UiKit.label(tr("pause.title")))
## func default_focus() -> Control:
##     return _resume
## [/codeblock]
@abstract class_name Screen
extends Control

## How much of the base shows through a modal's backdrop, as the backdrop's alpha.
const DIM_ALPHA: float = 0.75

## The player asked for [param intent_name]; `RunShell` wires it to `RunController.intent`.
signal intent_requested(intent_name: StringName, args: Dictionary)
## The animation [method play_landing] started has ended by itself.
signal landing_finished

## The `config("run_ui")` body, for geometry only. Set before `bind`.
var cfg: Dictionary = {}
## What `Esc` sends on this screen (interaction-patterns Escape / Cancel); `&""` for nothing.
var cancel_intent: StringName = &""

var _committed: bool = false


## Renders [param read_model]; called on open and on every read-model change.
@abstract func bind(read_model: Dictionary) -> void


## The control the shell focuses after a transition; null for none (drafts, U3).
@abstract func default_focus() -> Control


## The first focus stop, for a `Tab` from no focus. Defaults to [method default_focus].
func tab_entry() -> Control:
	return default_focus()


## U4's terminal-intent sub-state; a subclass shows it if it needs to.
func set_committed(on: bool) -> void:
	_committed = on


## `Esc`: the screen's own step of the chain, then [member cancel_intent].
func handle_cancel() -> void:
	if not close_drawer() and cancel_intent != &"":
		send(cancel_intent)


## Closes a non-modal drawer; true when one was open (Escape chain step 2, and RMB).
func close_drawer() -> bool:
	return false


## `1`/`2`/`3` (U3): focus option [param _index]. Ignored by a screen without options.
func handle_option_key(_index: int) -> void:
	pass


## Plays a pick's fly-to-strip over [param seconds]; [param fade_only] is `reduce_motion`.
## False when this screen has none, and then nothing waits for it.
func play_landing(_index: int, _deck_size: int, _seconds: float, _fade_only: bool) -> bool:
	return false


## Ends a running landing at its last frame, without [signal landing_finished].
func finish_landing() -> void:
	pass


## The transition that revealed this screen has ended.
func on_revealed() -> void:
	pass


## Sends [param intent_name] with [param args].
func send(intent_name: StringName, args: Dictionary = {}) -> void:
	intent_requested.emit(intent_name, args)


## Frees every child now, for a rebuild.
func clear() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()


## A modal's frame: a dimmed backdrop and a centred panel [param width] wide. Returns
## the column to fill.
func modal_body(width: float) -> VBoxContainer:
	var dim: Color = color("bg_edge")
	dim.a = DIM_ALPHA
	add_child(UiKit.backdrop(dim))
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var box: PanelContainer = UiKit.panel(RunUiTheme.PANEL_DARK)
	box.custom_minimum_size.x = width
	centre.add_child(box)
	var column: VBoxContainer = UiKit.vbox(12)
	box.add_child(column)
	return column


## The palette colour of [param token].
func color(token: String) -> Color:
	return RunUiConfig.color(cfg, token)
