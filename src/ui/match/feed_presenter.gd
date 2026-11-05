## The event feed (ADR-0009 `event_feed.tscn`). Stub until match-ui story 014.
class_name FeedPresenter
extends Presenter


func bind(_view_state: MatchViewState) -> void:
	return


func owns(_entity_ids: Array[int]) -> bool:
	return false


func on_step_started(_step: AnimStep, _d_eff: float) -> void:
	return


func apply_final(_step: AnimStep) -> void:
	return


func sync_report() -> Array[String]:
	return []
