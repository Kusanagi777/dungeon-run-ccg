## `resume_prompt` (run-ui U2, S4-S6): the saved run, Continue, and Abandon with the
## "counts as a loss" line. Abandon goes through `confirm`.
extends Screen

const WIDTH_PX: float = 520.0

var _continue: Button = null


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"back"
	var column: VBoxContainer = modal_body(WIDTH_PX)
	var line: String = tr("resume.found").format({"hero": model.get("hero_name", ""), "n": model.get("floor", 1), "f": model.get("floors", 0), "phase": model.get("phase", "")})
	column.add_child(UiKit.label(line, RunUiTheme.LABEL_HEADING, true))
	column.add_child(UiKit.label(tr("resume.loss"), RunUiTheme.LABEL_MUTED, true))
	_continue = UiKit.button(tr("resume.continue"), true)
	_continue.pressed.connect(send.bind(&"continue", {}))
	column.add_child(_continue)
	var abandon: Button = UiKit.button(tr("resume.abandon"))
	abandon.pressed.connect(send.bind(&"abandon", {}))
	column.add_child(abandon)
	var back: Button = UiKit.button(tr("common.back"))
	back.pressed.connect(send.bind(&"back", {}))
	column.add_child(back)
	UiKit.chain_focus([_continue, abandon, back])


func default_focus() -> Control:
	return _continue
