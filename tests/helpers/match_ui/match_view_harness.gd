## Drives a real `MatchView` from an integration suite (match-ui stories 004 to 025): the
## shipped data, a real `MatchDriver`, `ImmediatePlannerTask`, and a `MetaStub`, so no
## profile file is read. It boots a fresh `boot.gd` instance through `MatchView.set_launch`
## and never the `Boot` autoload, which `boot_composition_test` needs idle.
##
## The view's `_process` is off and [method run] calls it, so a suite owns the clock and a
## timing assertion does not depend on the machine. Tweens still run on real frames: a
## suite that samples one awaits [method frames].
##
## Input goes in as `MatchView` receives it from the viewport, past the GUI: headless
## window scaling distorts real mouse coordinates, so [method click] and its neighbours
## prove the view and router path, not the viewport's own event delivery.
## [codeblock]
## var view: MatchView = await MatchViewHarness.open(self, "turn1_player")
## MatchViewHarness.action(view, &"ui_accept")
## MatchViewHarness.run(view, 0.5)
## [/codeblock]
class_name MatchViewHarness
extends RefCounted

const VIEW_SCENE: String = "res://src/ui/match/match_view.tscn"
const BOOT_SCRIPT := preload("res://src/core/boot.gd")
## A 60 fps frame on the suite's clock.
const FRAME_S: float = 1.0 / 60.0
## Longer than any drain: a boss turn's `max_turn_playback_s` and planning.
const SETTLE_CAP_S: float = 60.0

static var _db: CardDatabase = null
# The seq of the last event [method inject] made up.
static var _injected_seq: int = 100000


## A task that does its work at once and answers only when the gate lets it: a suite holds
## the planner open past the point it wants to look at. `gate.held` is read on every poll.
class GatedTask:
	extends ImmediatePlannerTask

	var gate: Dictionary = {}

	func _init(shared: Dictionary) -> void:
		gate = shared

	func start(work: Callable) -> void:
		super(work)
		_live = bool(gate.held)

	func poll() -> bool:
		if bool(gate.held):
			return false
		_live = false
		return true


## The shipped database, loaded once with the real validators.
static func database() -> CardDatabase:
	if _db == null:
		var boot: Node = BOOT_SCRIPT.new()
		_db = CardDatabase.new()
		_db.load(boot.call("_collect_validators", null))
		boot.free()
	return _db


## A fresh composition root over [method database] and a [MetaStub] holding [param settings].
static func fresh_boot(settings: Dictionary = {}) -> Node:
	var boot: Node = BOOT_SCRIPT.new()
	var meta: MetaStub = MetaStub.from_fixture(database(), {"settings": settings})
	boot.call("boot", {"card_database": database(), "meta": meta})
	return boot


## A planner source for `set_launch`: the plan is ready when the task starts.
static func immediate_planner() -> Callable:
	return func() -> PlannerTask: return ImmediatePlannerTask.new()


## A planner source whose tasks wait on [param gate], `{held: bool}`.
static func gated_planner(gate: Dictionary) -> Callable:
	return func() -> PlannerTask: return GatedTask.new(gate)


## Launches `match_view.tscn` on fixture [param fixture] under [param host], as the
## command line would, with [param args] after `--fixture` and [param settings] in the
## profile. `anim_speed` is `instant` unless [param settings] says otherwise. The caller
## frees the view with [method close]. [param planner] replaces the immediate one.
static func open(host: Node, fixture: String, args: Array = [], settings: Dictionary = {}, planner: Callable = Callable()) -> MatchView:
	var profile: Dictionary = {"anim_speed": "instant"}
	profile.merge(settings, true)
	var boot: Node = fresh_boot(profile)
	var launch: PackedStringArray = PackedStringArray(["--fixture=" + fixture])
	launch.append_array(PackedStringArray(args))
	return await _enter(host, boot, launch, planner if planner.is_valid() else immediate_planner(), null)


## Starts `match_view.tscn` under [param host] with [param controller], as `RunShell`
## does. [param boot] holds its services, and [param info] is `set_match_info`'s.
static func open_controller(host: Node, boot: Node, controller: MatchController, info: Dictionary) -> MatchView:
	var prepare: Callable = func(view: MatchView) -> void:
		view.set_match_info(info)
		view.set_controller(controller)
	return await _enter(host, boot, PackedStringArray(), Callable(), prepare)


static func _enter(host: Node, boot: Node, args: PackedStringArray, planner: Callable, prepare: Variant) -> MatchView:
	var view: MatchView = (load(VIEW_SCENE) as PackedScene).instantiate()
	view.set_launch(boot, args, planner)
	view.add_child(boot)
	if prepare is Callable:
		(prepare as Callable).call(view)
	host.add_child(view)
	view.set_process(false)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	return view


## The `MetaApi` the view writes through.
static func meta(view: MatchView) -> MetaApi:
	return view.get("_meta")


## Frees [param view] now, with its `_exit_tree`.
static func close(view: MatchView) -> void:
	if is_instance_valid(view):
		view.get_parent().remove_child(view)
		view.free()


## Runs the view's `_process` for [param seconds] on the suite's clock.
static func run(view: MatchView, seconds: float, step: float = FRAME_S) -> void:
	var left: float = seconds
	while left > 0.0:
		view.call("_process", minf(step, left))
		left -= step


## Runs until the queue is idle and the planner rests; true unless the cap ran out.
static func settle(view: MatchView) -> bool:
	var left: float = SETTLE_CAP_S
	view.call("_process", 0.0)
	while left > 0.0:
		if view.queue().is_idle() and not (view.get("_controller") as MatchController).is_planning():
			view.call("_process", 0.0)
			return true
		view.call("_process", FRAME_S)
		left -= FRAME_S
	return false


## Awaits [param count] real frames, for container sorts and tweens.
static func frames(view: MatchView, count: int = 1) -> void:
	for i: int in count:
		await view.get_tree().process_frame


## Sends [param event] down the path the viewport would: `_input`, then, unless a session
## took it, `_unhandled_input`.
static func send(view: MatchView, event: InputEvent) -> void:
	if view.router().in_session():
		view.call("_input", event)
		return
	view.call("_unhandled_input", event)


## Presses input action [param name] once.
static func action(view: MatchView, name: StringName) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	send(view, event)


## A press and release at [param at], with no motion.
static func click(view: MatchView, at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT, double: bool = false) -> void:
	send(view, mouse_button(at, button, true, double))
	send(view, mouse_button(at, button, false, false))


## A left press at [param from], moved in steps to [param to], and released there.
static func drag(view: MatchView, from: Vector2, to: Vector2) -> void:
	send(view, mouse_button(from, MOUSE_BUTTON_LEFT, true, false))
	send(view, motion(from.lerp(to, 0.5)))
	send(view, motion(to))
	send(view, mouse_button(to, MOUSE_BUTTON_LEFT, false, false))


## A mouse button event at [param at].
static func mouse_button(at: Vector2, button: MouseButton, pressed: bool, double: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = at
	event.button_index = button
	event.pressed = pressed
	event.double_click = double
	return event


## A mouse motion event at [param at].
static func motion(at: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	return event


## The End Turn control's click: true when the button took it. A disabled `Button` emits
## nothing, so neither does this.
static func press_end_turn(view: MatchView) -> bool:
	var button: Button = view.get("_end_turn")
	if button.disabled:
		return false
	button.pressed.emit()
	return true


## Hands the view an event the engine did not make, as if it had just arrived: for a
## state the fixtures cannot reach. Answers its `seq`.
static func inject(view: MatchView, type: String, payload: Dictionary, cause: int = 0) -> int:
	_injected_seq += 1
	view.call("_on_event", {"seq": _injected_seq, "turn": view.view_state().turn, "type": type, "payload": payload, "cause_seq": cause})
	return _injected_seq


## A point on hand card [param id] that no neighbour covers: left of centre, where a later
## card does not reach.
static func card_point(view: MatchView, id: int) -> Vector2:
	var slot: Dictionary = (view.hand().get("_slots") as Dictionary)[id]
	var cfg: Dictionary = view.hand().get("_cfg")
	var local := Vector2(-float(cfg.card_w) * 0.4, -float(cfg.card_h) / 2.0)
	return Vector2(float(slot.x), float(slot.y)) + local.rotated(deg_to_rad(float(slot.rot)))


## The id of the player's hand card [param index].
static func hand_id(view: MatchView, index: int) -> int:
	return int(view.view_state().side(&"player").hand[index].instance_id)


## The commands the router asks for from now on, filled in as they happen.
static func spy_commands(view: MatchView) -> Array[Dictionary]:
	var sent: Array[Dictionary] = []
	view.router().command_requested.connect(func(command: Dictionary) -> void: sent.append(command))
	return sent


## Every event type the match log holds, in order.
static func event_types(view: MatchView) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in (view.get("_controller") as MatchController).events_since(0):
		out.append(str(event.type))
	return out


## The player's commands now, of [param type].
static func legal(view: MatchView, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for command: Dictionary in view.router().player_commands():
		if str(command.type) == type:
			out.append(command)
	return out


## Everything `sync_report` says across the presenters, for an assertion.
static func sync_lines(view: MatchView) -> Array[String]:
	var lines: Array[String] = []
	for presenter: Presenter in view.get("_presenters"):
		lines.append_array(presenter.sync_report())
	return lines
