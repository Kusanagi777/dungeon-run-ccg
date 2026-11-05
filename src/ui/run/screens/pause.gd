## `pause` (run-ui U2, S17, S20, S23; accessibility "Independent volume controls"):
## Resume, the music slider, Settings, Glossary, Abandon run and Quit to menu, with the
## strip above. Quit keeps the run saved; Abandon goes through `confirm`.
extends Screen

const WIDTH_PX: float = 420.0
const SLIDER_H: float = 44.0

var _resume: Button = null


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"close"
	var column: VBoxContainer = modal_body(WIDTH_PX)
	var strip: ProgressStrip = ProgressStrip.new()
	add_child(strip)
	strip.show_strip(cfg, model.get("strip", {}))
	column.add_child(UiKit.label(tr("pause.title"), RunUiTheme.LABEL_TITLE))
	_resume = _add(column, tr("pause.resume"), &"close", true)
	var music: VBoxContainer = UiKit.vbox(2)
	column.add_child(music)
	music.add_child(UiKit.label(tr("settings.key.volume_music"), RunUiTheme.LABEL_SMALL))
	var slider: HSlider = HSlider.new()
	slider.max_value = 1.0
	slider.step = float(cfg.settings_steps.volume)
	slider.value = float(model.get("volume_music", 0.0))
	slider.custom_minimum_size.y = SLIDER_H
	slider.value_changed.connect(func(value: float) -> void: send(&"set_setting", {"key": "volume_music", "value": value}))
	music.add_child(slider)
	var settings: Button = _add(column, tr("pause.settings"), &"open_settings", false)
	var glossary: Button = _add(column, tr("pause.glossary"), &"open_glossary", false)
	var abandon: Button = _add(column, tr("pause.abandon"), &"abandon", false)
	var quit: Button = _add(column, tr("pause.quit"), &"go_main_menu", false)
	var order: Array[Control] = [_resume, slider, settings, glossary, abandon, quit]
	order.append_array(strip.focus_stops())
	UiKit.chain_focus(order)


func default_focus() -> Control:
	return _resume


func _add(column: Control, text: String, intent: StringName, primary: bool) -> Button:
	var button: Button = UiKit.button(text, primary)
	button.pressed.connect(send.bind(intent, {}))
	column.add_child(button)
	return button
