## One side's minion row (ADR-0009 `board_row.tscn` ×2; match-ui U3, F6; hud.md §4.2):
## an `HBoxContainer` of [MinionToken]s, centred on the row, so tokens re-space by
## themselves. Motion inside it uses `offset_transform_*`, which the container never
## resets (4.7). Dead tokens stay as empty slots through `death_group` and collapse on
## `gap_close`, and are freed only after that step's `apply_final`.
class_name BoardPresenter
extends Presenter

const TOKEN_SCENE: PackedScene = preload("res://src/ui/match/minion_token.tscn")
const SIDE_PLAYER: StringName = &"player"
const DROP_PX: float = 2.0

## Which side's row this is; set on the instance in `match_view.tscn`.
@export var side: StringName = SIDE_PLAYER

var _view: MatchViewState = null
var _row: HBoxContainer = null
# entity_id → MinionToken in play.
var _tokens: Dictionary = {}
# entity_id → MinionToken on its way out, still holding its slot.
var _leaving: Dictionary = {}
var _order: Array[int] = []
var _gap: Control = null


## Places the row at its F6 rect and builds the container.
func setup(context: MatchUiContext) -> void:
	super(context)
	var rect: Rect2 = ui.rect("player_row" if side == SIDE_PLAYER else "boss_row")
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = rect.position
	size = rect.size
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", int(ui.config.board.gap))
	add_child(_row)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Stores the projection [method sync_report] compares against.
func bind(view_state: MatchViewState) -> void:
	_view = view_state


func owns(entity_ids: Array[int]) -> bool:
	for id: int in entity_ids:
		if _tokens.has(id) or _leaving.has(id) or not _view_token(id).is_empty():
			return true
	return false


func on_step_started(step: AnimStep, d_eff: float) -> void:
	match step.kind:
		AnimStep.DAMAGE_POP, AnimStep.HEAL_POP:
			for pop: AnimStep in (step.members if not step.members.is_empty() else [step] as Array[AnimStep]):
				if not pop.entity_ids.is_empty() and _tokens.has(pop.entity_ids[0]):
					spawn_pop(step, pop, center_of(pop.entity_ids[0]) - global_position, d_eff)
		AnimStep.SUMMON:
			present(step.data.get("display", {}))
			for id: int in step.entity_ids:
				_grow_in(step, id, d_eff)
		AnimStep.ATTACK_LUNGE:
			_lunge(step, d_eff)
		AnimStep.DEATH_GROUP:
			for id: int in step.entity_ids:
				_fade_out(step, id, d_eff)
		AnimStep.GAP_CLOSE:
			for id: int in step.entity_ids:
				_close_slot(step, id, d_eff)
		AnimStep.SHIELD_POP:
			for id: int in step.entity_ids:
				if _tokens.has(id):
					var token: MinionToken = _tokens[id]
					step_tween(step).tween_property(token, "burst", 1.0, d_eff).from(0.0)


func apply_final(step: AnimStep) -> void:
	end_step(step)
	for id: int in step.entity_ids:
		if _tokens.has(id):
			_rest(_tokens[id])
	if step.kind == AnimStep.GAP_CLOSE:
		for id: int in step.entity_ids:
			_free_leaving(id)


func on_skipped() -> void:
	super()
	for token: MinionToken in _tokens.values():
		_rest(token)


func present(state: Dictionary) -> void:
	var data: Dictionary = state.get(String(side), {})
	if data.is_empty():
		return
	var ids: Dictionary = {}
	var order: Array[int] = []
	for entry: Dictionary in data.board:
		var id: int = int(entry.entity_id)
		ids[id] = true
		order.append(id)
		if not _tokens.has(id):
			_add_token(id)
		var token: MinionToken = _tokens[id]
		if token.shown() != entry:
			token.show_token(entry, ui.card_face(str(entry.card_id)))
	for id: Variant in _tokens.keys():
		if not ids.has(id):
			_leave(int(id))
	if order != _order:
		_order = order
		for i: int in _order.size():
			_row.move_child(_tokens[_order[i]], i)


## The queue is idle: any slot still held closes now.
func on_drained() -> void:
	for id: Variant in _leaving.keys():
		_free_leaving(int(id))


func sync_report() -> Array[String]:
	var report: Array[String] = []
	var truth: Array = _view.side(side).board
	if truth.size() != _tokens.size():
		report.append("%s board size: shows %d, view-state %d" % [side, _tokens.size(), truth.size()])
		return report
	if not _leaving.is_empty():
		report.append("%s board: %d freed tokens remain" % [side, _leaving.size()])
	for i: int in truth.size():
		var entry: Dictionary = truth[i]
		if i >= _order.size() or _order[i] != int(entry.entity_id):
			report.append("%s board[%d]: wrong token" % [side, i])
		elif (_tokens[_order[i]] as MinionToken).shown() != entry:
			report.append("%s board[%d]: shows %s, view-state %s" % [side, i, str((_tokens[_order[i]] as MinionToken).shown()), str(entry)])
	return report


## The token under [param point], or -1.
func token_at(point: Vector2) -> int:
	for id: Variant in _tokens:
		if (_tokens[id] as MinionToken).get_global_rect().has_point(point):
			return int(id)
	return -1


## True when this row draws entity [param id] now.
func has_token(id: int) -> bool:
	return _tokens.has(id)


## The card a token shows, or `""`.
func card_of(id: int) -> String:
	return (_tokens[id] as MinionToken).card_id if _tokens.has(id) else ""


## The screen centre of token [param id].
func center_of(id: int) -> Vector2:
	if _tokens.has(id):
		return (_tokens[id] as MinionToken).get_global_rect().get_center()
	return get_global_rect().get_center()


## Legality at `Idle`: [param attackers] holds the ids `legal_commands()` lets attack,
## and [param sick] the summoning-sick ones.
func set_attackers(attackers: Dictionary, sick: Dictionary) -> void:
	for id: Variant in _tokens:
		var token: MinionToken = _tokens[id]
		token.set_lit(attackers.has(id))
		token.set_summoning_sick(sick.has(id))


## The token of entity [param id], or null, for the rejection shake.
func token(id: int) -> MinionToken:
	return _tokens.get(id)


## Rejection Feedback: every Taunt's frame flashes while [param on].
func flash_taunts(on: bool) -> void:
	for id: Variant in _tokens:
		var minion: MinionToken = _tokens[id]
		minion.set_flash(on and minion.has_taunt())


## The `A` numerals: [param badges] maps entity id to numeral; `{}` clears them.
func set_attack_badges(badges: Dictionary) -> void:
	for id: Variant in _tokens:
		(_tokens[id] as MinionToken).set_attack_badge(int(badges.get(id, 0)))


## The `state_target` outlines of a session; [param hovered] carries the 3 px ring.
func set_targets(targets: Dictionary, hovered: int = -1) -> void:
	for id: Variant in _tokens:
		(_tokens[id] as MinionToken).set_target(targets.has(id), int(id) == hovered)


## The dragged attacker's 4 px lift, through `offset_transform` (the row is a Container).
func set_lifted(id: int, on: bool) -> void:
	if _tokens.has(id):
		(_tokens[id] as MinionToken).offset_transform_position = Vector2(0, -float(ui.config.hero.lift_px) if on else 0.0)


## Opens the summon gap at [param index], or closes it for -1 (targeting.md §6 Phase P).
func set_gap(index: int) -> void:
	if index < 0:
		if _gap != null:
			_gap.queue_free()
			_gap = null
		return
	if _gap == null:
		_gap = Control.new()
		_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gap.custom_minimum_size = Vector2(float(ui.config.board.token_w), float(ui.config.board.token_h))
		_row.add_child(_gap)
	_row.move_child(_gap, index)


## The screen rect of the open gap, or an empty one.
func gap_rect() -> Rect2:
	return _gap.get_global_rect() if _gap != null else Rect2()


## Where gap [param index] sits in the m + 1 layout the row is moving to (targeting.md
## §7.4), from the layout and never from mid-tween token pixels.
func gap_rect_at(index: int) -> Rect2:
	var board: Dictionary = ui.config.board
	var token_w: float = float(board.token_w)
	var spacing: float = float(board.gap)
	var m: int = _order.size()
	var row: Rect2 = get_global_rect()
	var left: float = row.get_center().x - ((m + 1) * token_w + m * spacing) / 2.0
	return Rect2(left + index * (token_w + spacing), row.position.y, token_w, float(board.token_h))


## Phase T after P: the 60 % ghost of [param card_id] holds the open gap (targeting.md
## §5.3). It goes when the gap closes.
func show_ghost(card_id: String) -> void:
	if _gap == null:
		return
	var face: Dictionary = ui.card_face(card_id)
	var ghost: MinionToken = TOKEN_SCENE.instantiate()
	_gap.add_child(ghost)
	ghost.configure(ui)
	var attack: int = int(face.get("attack", 0)) if face.get("attack") != null else 0
	var health: int = int(face.get("health", 0)) if face.get("health") != null else 0
	ghost.show_token({"entity_id": 0, "card_id": card_id, "attack": attack, "health": health, "max_health": health, "keywords": []}, face)
	ghost.modulate.a = float(ui.config.targeting.unlit_alpha)


## targeting.md §7.4: the gap under [param x], from the m + 1 layout the row is moving
## to, never from token pixels. [param m] is the tokens in the row.
static func gap_index(x: float, m: int, row: Rect2, token_w: float, gap: float) -> int:
	var width: float = (m + 1) * token_w + m * gap
	var left: float = row.get_center().x - width / 2.0
	return clampi(int(floor((x - left) / (token_w + gap))), 0, m)


func _add_token(id: int) -> void:
	var token: MinionToken = TOKEN_SCENE.instantiate()
	_row.add_child(token)
	token.configure(ui)
	_tokens[id] = token


func _leave(id: int) -> void:
	var token: MinionToken = _tokens[id]
	_tokens.erase(id)
	_order.erase(id)
	token.modulate.a = 0.0
	_leaving[id] = token


func _free_leaving(id: int) -> void:
	if _leaving.has(id):
		(_leaving[id] as MinionToken).queue_free()
		_leaving.erase(id)


func _rest(token: MinionToken) -> void:
	token.offset_transform_position = Vector2.ZERO
	token.offset_transform_scale = Vector2.ONE
	token.burst = 0.0


func _grow_in(step: AnimStep, id: int, d_eff: float) -> void:
	if _tokens.has(id):
		var token: MinionToken = _tokens[id]
		token.offset_transform_scale = Vector2.ZERO
		step_tween(step).tween_property(token, "offset_transform_scale", Vector2.ONE, d_eff)


func _lunge(step: AnimStep, d_eff: float) -> void:
	if step.entity_ids.size() < 2 or not _tokens.has(step.entity_ids[0]):
		return
	var board: Dictionary = ui.config.board
	var token: MinionToken = _tokens[step.entity_ids[0]]
	var aim: Vector2 = ui.locate.call(step.entity_ids[1]) - token.get_global_rect().get_center()
	var out_s: float = d_eff * float(board.lunge_out)
	var hold_s: float = d_eff * float(board.lunge_hold)
	var lunge: Tween = step_tween(step)
	lunge.tween_property(token, "offset_transform_position", aim * float(board.lunge_reach), out_s)
	lunge.tween_interval(hold_s)
	lunge.tween_property(token, "offset_transform_position", Vector2.ZERO, maxf(d_eff - out_s - hold_s, 0.0))


func _fade_out(step: AnimStep, id: int, d_eff: float) -> void:
	if not _tokens.has(id):
		return
	var token: MinionToken = _tokens[id]
	var fade: Tween = step_tween(step).set_parallel()
	fade.tween_property(token, "modulate:a", 0.0, d_eff)
	fade.tween_property(token, "offset_transform_position", Vector2(0, DROP_PX), d_eff)


func _close_slot(step: AnimStep, id: int, d_eff: float) -> void:
	if _leaving.has(id):
		step_tween(step).tween_property(_leaving[id], "custom_minimum_size:x", 0.0, d_eff)


func _view_token(id: int) -> Dictionary:
	for entry: Dictionary in _view.side(side).board:
		if int(entry.entity_id) == id:
			return entry
	return {}
