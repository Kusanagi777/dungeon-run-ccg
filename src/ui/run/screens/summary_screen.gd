## `summary_victory` and `summary_defeat` (run-ui U2, U9; run-summary.md): one layout
## that differs by palette and headline. **New Run (same hero)** holds focus, so `Enter`
## restarts with no confirm (Pillar 3).
extends Screen

const ROW_Y: float = 640.0
const BACK_X: float = 40.0
const MENU_X: float = 216.0
const NEW_RUN_RECT: Rect2 = Rect2(1000, 640, 240, 44)

var _new_run: Button = null
var _hero_select: Button = null
var _menu: Button = null
var _view: SummaryView = null
var _hero_color: Color = Color.WHITE
var _victory: bool = false
var _focus_key: String = ""


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"go_main_menu"
	_victory = str(model.get("outcome")) == RunState.STATUS_VICTORY
	add_child(UiKit.backdrop(color("table_lit" if _victory else "bg_edge")))
	_view = SummaryView.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_view)
	_view.show_summary(cfg, model)
	_hero_color = color(str(model.get("hero_color", "neutral")))
	_hero_select = UiKit.button(tr("summary.hero_select"))
	_hero_select.pressed.connect(send.bind(&"go_hero_select", {}))
	add_child(_hero_select)
	UiKit.place(_hero_select, Rect2(Vector2(BACK_X, ROW_Y), _hero_select.custom_minimum_size))
	_menu = UiKit.button(tr("summary.main_menu"))
	_menu.pressed.connect(send.bind(&"go_main_menu", {}))
	add_child(_menu)
	UiKit.place(_menu, Rect2(Vector2(MENU_X, ROW_Y), _menu.custom_minimum_size))
	_new_run = UiKit.button(tr("summary.new_run"), true)
	_new_run.custom_minimum_size = NEW_RUN_RECT.size
	_new_run.disabled = not bool(model.get("hero_available", true))
	_new_run.pressed.connect(send.bind(&"new_run_same_hero", {}))
	_new_run.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_new_run)
	UiKit.place(_new_run, NEW_RUN_RECT)
	_focus_key = str(model.get("focus", "new_run_same_hero"))
	var order: Array[Control] = [_new_run, _hero_select, _menu]
	order.append_array(_view.focus_stops())
	UiKit.chain_focus(order)


func default_focus() -> Control:
	match _focus_key:
		"hero_select":
			return _hero_select
		"none":
			return null
	return _menu if _new_run.disabled else _new_run


func tab_entry() -> Control:
	return _new_run


func on_revealed() -> void:
	if _victory:
		_view.saturate_portrait(_hero_color, false)
