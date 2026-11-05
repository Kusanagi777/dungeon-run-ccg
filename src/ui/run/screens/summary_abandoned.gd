## `summary_abandoned` (run-ui U2): one line, New Run, Main Menu. A player abandon says
## it counted as a loss; a system abandon gives its reason and is not a loss.
extends Screen

var _new_run: Button = null
var _menu: Button = null


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"go_main_menu"
	add_child(UiKit.backdrop(color("bg_edge")))
	var centre: CenterContainer = CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column: VBoxContainer = UiKit.vbox(16)
	centre.add_child(column)
	column.add_child(UiKit.label(str(model.get("line", "")), RunUiTheme.LABEL_HEADING, true))
	var row: HBoxContainer = UiKit.hbox(16)
	column.add_child(row)
	_new_run = UiKit.button(tr("summary.new_run"), true)
	_new_run.disabled = not bool(model.get("hero_available", true))
	_new_run.pressed.connect(send.bind(&"new_run_same_hero", {}))
	row.add_child(_new_run)
	_menu = UiKit.button(tr("summary.main_menu"))
	_menu.pressed.connect(send.bind(&"go_main_menu", {}))
	row.add_child(_menu)
	UiKit.chain_focus([_new_run, _menu])


func default_focus() -> Control:
	return _menu if _new_run.disabled else _new_run
