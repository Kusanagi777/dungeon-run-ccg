## The Choice overlay (ADR-0009 `choice_overlay.tscn`). Stub until match-ui story 013.
class_name OverlayPresenter
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
