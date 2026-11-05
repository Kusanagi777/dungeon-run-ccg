## What a screen point means (targeting.md §7.4; match-ui F6): the one place that turns
## a pixel into a drag source, a target or a zone. Presenters answer for their own
## pixels, so the router stays free of geometry and a test can drive it with a double.
## [codeblock]
## var hit := MatchHitTest.new(ui, hand, player_row, boss_row, player_panel, boss_panel)
## var source: Dictionary = hit.source_at(point)   # {kind: "card", id: 12}, or {}
## var target: int = hit.target_at(point)          # an entity id, or -1
## [/codeblock]
class_name MatchHitTest
extends RefCounted

## Sentinel of [method target_at]: nothing there.
const NO_TARGET: int = -1

var _ui: MatchUiContext
var _hand: HandPresenter
var _player_row: BoardPresenter
var _boss_row: BoardPresenter
var _player_panel: HeroPresenter
var _boss_panel: HeroPresenter
var _view: MatchViewState


## Wraps the presenters that own the pixels; [param view] names the heroes.
func _init(ui: MatchUiContext, view: MatchViewState, hand: HandPresenter, player_row: BoardPresenter, boss_row: BoardPresenter, player_panel: HeroPresenter, boss_panel: HeroPresenter) -> void:
	_ui = ui
	_view = view
	_hand = hand
	_player_row = player_row
	_boss_row = boss_row
	_player_panel = player_panel
	_boss_panel = boss_panel


## The drag source at [param point]: `{kind, id}`, or `{}`. Legality is the router's.
func source_at(point: Vector2) -> Dictionary:
	var card: int = _hand.card_at(point)
	if card != -1:
		return {"kind": InputRouter.SOURCE_CARD, "id": card}
	var token: int = _player_row.token_at(point)
	if token != -1:
		return {"kind": InputRouter.SOURCE_ATTACKER, "id": token}
	if _player_panel.power_rect().has_point(point):
		return {"kind": InputRouter.SOURCE_HERO_POWER, "id": -1}
	if _player_panel.portrait_rect().has_point(point):
		return {"kind": InputRouter.SOURCE_ATTACKER, "id": _hero_id(&"player")}
	return {}


## The entity at [param point] that a target could be, or [constant NO_TARGET].
func target_at(point: Vector2) -> int:
	var token: int = _boss_row.token_at(point)
	if token == -1:
		token = _player_row.token_at(point)
	if token != -1:
		return token
	if _boss_panel.portrait_rect().has_point(point):
		return _hero_id(&"boss")
	if _player_panel.portrait_rect().has_point(point):
		return _hero_id(&"player")
	return NO_TARGET


## True inside the dashed cast zone (F6 301, 176, 678, 284).
func in_cast_zone(point: Vector2) -> bool:
	return _ui.rect("cast_zone").has_point(point)


## True inside the position zone: the player row and the top of the hand (§7.4).
func in_position_zone(point: Vector2) -> bool:
	return _ui.rect("position_zone").has_point(point)


## True over End Turn, which a session click leaves alone (§7.4 rank 5).
func in_end_turn(point: Vector2) -> bool:
	return _ui.rect("end_turn").has_point(point)


## The screen centre of entity [param id], where the arrow's head rests.
func centre_of(id: int) -> Vector2:
	return _ui.locate.call(id)


## The summon gap under [param point] for a row of [param tokens].
func gap_at(point: Vector2, tokens: int) -> int:
	var board: Dictionary = _ui.config.board
	return BoardPresenter.gap_index(point.x, tokens, _ui.rect("player_row"), float(board.token_w), float(board.gap))


func _hero_id(side_name: StringName) -> int:
	var id: Variant = _view.side(side_name).hero.entity_id
	return int(id) if id != null else NO_TARGET
