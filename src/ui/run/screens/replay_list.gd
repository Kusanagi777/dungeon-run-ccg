## `replay_list` (rng-event-log rules 17-18, Edge Cases; UI Requirements "Not replayable"
## row): the archived match logs of one run, opened over `run_log`. A log that can play is
## a button; one that cannot stays listed with its reason, never hidden.
extends Screen

const WIDTH_PX: float = 560.0
const LIST_H_PX: float = 320.0

var _first: Control = null
var _back: Button = null


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"back"
	var column: VBoxContainer = modal_body(WIDTH_PX)
	column.add_child(UiKit.label(tr("replay.title"), RunUiTheme.LABEL_HEADING))
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.custom_minimum_size.y = LIST_H_PX
	column.add_child(scroll)
	var rows: VBoxContainer = UiKit.vbox(6)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var order: Array[Control] = []
	for row: Dictionary in model.get("rows", []):
		var stop: Button = _add_row(rows, row)
		if stop != null:
			order.append(stop)
	_back = UiKit.button(tr("common.back"))
	_back.pressed.connect(send.bind(&"back", {}))
	column.add_child(_back)
	order.append(_back)
	_first = order[0]
	UiKit.chain_focus(order)


func default_focus() -> Control:
	return _first


func _add_row(rows: VBoxContainer, row: Dictionary) -> Button:
	if bool(row.replayable):
		var play: Button = UiKit.button(str(row.label))
		play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		play.pressed.connect(send.bind(&"play_replay", {"path": row.path, "hero_id": row.hero_id, "boss_id": row.boss_id}))
		rows.add_child(play)
		return play
	rows.add_child(UiKit.label(str(row.label), &"", true))
	rows.add_child(UiKit.label(str(row.reason), RunUiTheme.LABEL_SMALL, true))
	return null
