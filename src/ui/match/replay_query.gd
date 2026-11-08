## The read model of a replay (rng-event-log rule 17): the same questions as [MatchQuery]
## with no engine behind them. Card text still comes from the database; the hand comes
## from the projection; legality is always "nothing", because a replay takes no input.
## [codeblock]
## var query := ReplayQuery.new(db)
## query.bind_view(view_state)
## [/codeblock]
class_name ReplayQuery
extends MatchQuery

var _projection: MatchViewState = null


## A query over [param db] alone.
func _init(db: CardDatabase) -> void:
	super(null, db, {})


## The projection [method hand] reads.
func bind_view(view_state: MatchViewState) -> void:
	_projection = view_state


func phase() -> String:
	return _projection.phase if _projection != null else ""


func active_side() -> String:
	return _projection.active_side if _projection != null else ""


func pending_choice() -> Variant:
	return null


func entity(_instance_id: int) -> Dictionary:
	return {}


## The player's hand as the log left it, at printed or `auras_recomputed` cost, and the
## boss's as a count. Nothing is playable.
func hand(side: String) -> Variant:
	if _projection == null:
		return []
	var cards: Variant = _projection.side(StringName(side)).get("hand", [])
	if not cards is Array:
		return cards
	var out: Array[Dictionary] = []
	for card: Dictionary in cards:
		var cost: Variant = card.get("effective_cost", card_text(str(card.get("card_id", ""))).get("cost"))
		out.append({
			"instance_id": int(card.instance_id), "card_id": str(card.get("card_id", "")),
			"effective_cost": int(cost) if cost != null else 0, "playable": false,
		})
	return out


func legal_commands() -> Array:
	return []


func hero_power_state(_side: String) -> Dictionary:
	return _power(POWER_READY)


func hero_power_cost(_side: String) -> int:
	return 0


func hero_power_id(_side: String) -> String:
	return ""


func snapshot(_side: String) -> Dictionary:
	return {}
