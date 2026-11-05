## `run_detail` (run-ui U2): the summary layout, read-only, from the archived row already
## loaded (there is no `get_run`, Meta M1.3). Copy seed and Back.
extends Screen

const BACK_POS: Vector2 = Vector2(40, 640)

var _back: Button = null


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"back"
	add_child(UiKit.backdrop(color("bg_edge")))
	var view: SummaryView = SummaryView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	view.show_summary(cfg, model)
	_back = UiKit.button(tr("common.back"), true)
	_back.pressed.connect(send.bind(&"back", {}))
	add_child(_back)
	UiKit.place(_back, Rect2(BACK_POS, _back.custom_minimum_size))
	var order: Array[Control] = [_back]
	order.append_array(view.focus_stops())
	UiKit.chain_focus(order)


func default_focus() -> Control:
	return _back
