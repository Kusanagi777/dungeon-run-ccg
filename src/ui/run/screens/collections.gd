extends Screen

var _back: Button


func bind(model: Dictionary) -> void:
	clear()
	cancel_intent = &"back"
	add_child(UiKit.backdrop(color("bg_edge")))
	var margin: MarginContainer = UiKit.margin(40)
	add_child(margin)
	var column: VBoxContainer = UiKit.vbox(12)
	margin.add_child(column)
	column.add_child(UiKit.label(tr("collection.title"), RunUiTheme.LABEL_TITLE))
	var scroll: ScrollContainer = UiKit.scroll()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body: VBoxContainer = UiKit.vbox(14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var order: Array[Control] = []
	var trial: Dictionary = model.get("trial", {})
	for row: Dictionary in model.get("collections", []):
		body.add_child(UiKit.label(str(row.name), RunUiTheme.LABEL_TITLE))
		body.add_child(UiKit.label(str(row.description), &"", true))
		var has_trial: bool = not str(row.get("trial_id", "")).is_empty()
		var locked_text: String = tr("collection.requirements") if has_trial else str(row.get("requirements", ""))
		body.add_child(UiKit.label(tr("collection.unlocked") if bool(row.unlocked) else locked_text, &"", true))
		if bool(row.unlocked) or not has_trial:
			continue
		var status: String = str(trial.get("status", "idle"))
		var access: Dictionary = trial.get("access", {})
		var active: bool = str(trial.get("trial_id", "")) == str(row.trial_id)
		if active:
			body.add_child(UiKit.label(tr("trial.status").format({"status": status, "n": int(trial.get("encounter_index", 0)) + 1, "total": int(trial.get("encounter_count", 3))}), &"", true))
			var objectives: Dictionary = trial.get("objectives", {})
			body.add_child(UiKit.label(tr("trial.objectives").format({"n": int(objectives.get("predator", 0)), "friendly": int(objectives.get("friendly", 0)), "enemy": int(objectives.get("enemy", 0))}), &"", true))
		body.add_child(UiKit.label(tr("trial.rules"), &"", true))
		body.add_child(UiKit.label("\n".join(model.get("access_rows", [])), &"", true))
		var action: StringName = &"start_trial"
		var label: String = tr("trial.start")
		if active and status == "playing":
			action = &"resume_trial"
			label = tr("trial.resume")
		elif active and status == "encounter_won":
			action = &"next_trial_encounter"
			label = tr("trial.next")
		elif active and status == "failed":
			action = &"retry_trial"
			label = tr("trial.retry")
		elif active and status == "completed":
			action = &"retry_trial_save"
			label = tr("trial.retry_save")
		var button: Button = UiKit.button(label, true)
		button.name = "TrialAction"
		button.disabled = not bool(access.get("met", false))
		button.pressed.connect(send.bind(action, {"trial_id": str(row.trial_id)}))
		body.add_child(button)
		order.append(button)
		if not str(trial.get("error", "")).is_empty():
			body.add_child(UiKit.label(str(trial.error), &"", true))
	if not (model.get("loaner", []) as Array).is_empty():
		body.add_child(UiKit.label("\n".join(model.get("encounters", [])), &"", true))
		body.add_child(UiKit.label(tr("trial.loaner"), RunUiTheme.LABEL_TITLE))
		body.add_child(UiKit.label("\n".join(model.loaner), &"", true))
	_back = UiKit.button(tr("common.back"))
	_back.pressed.connect(send.bind(&"back", {}))
	column.add_child(_back)
	order.append(_back)
	UiKit.chain_focus(order)


func default_focus() -> Control:
	return _back
