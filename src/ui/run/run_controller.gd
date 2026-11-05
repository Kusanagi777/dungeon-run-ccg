## The only object under `src/ui/run/` that talks to Run Structure, Reward Draft and
## Meta (ADR-0011 Decision 2; run-ui U1, U2, S1-S23). A screen's intent comes in, is
## checked against [constant LEGAL] for the top screen, and goes out as a command; what
## the player sees changes only from the run-scope events that command produced.
##
## **Events are drained, never applied in place.** A subscriber runs inside the command
## that appended the event, when (for `run_ended`) the archive and `unlocks_granted`
## have not happened yet. So events only queue, and [method _drain] runs after the
## command returns; during `match` it waits for `match_view_finished` (S11). The last
## screen-deciding event wins (S11's rule, used everywhere).
##
## Local navigation with no event behind it (menu to run log, opening an overlay) is
## not a run state change, so it opens directly.
## [codeblock]
## var controller := RunController.new(run, run.draft(), services.meta, services.card_database, ui_config)
## controller.screen_requested.connect(shell.open_base)
## controller.intent(&"start_run", {"hero_id": "hero_war", "seed_input": ""})
## [/codeblock]
class_name RunController
extends RefCounted

## Open base screen [param id] with [param read_model], by transition [param kind].
signal screen_requested(id: StringName, read_model: Dictionary, kind: StringName)
## Push overlay [param id].
signal overlay_requested(id: StringName, read_model: Dictionary)
## Pop the top overlay.
signal overlay_closed
## Re-`bind` the open screen [param id].
signal screen_refreshed(id: StringName, read_model: Dictionary)
## Swap `MatchView` in over [param driver]; [param info] is its `set_match_info` body.
signal match_requested(driver: MatchDriver, info: Dictionary)
## Swap the replay of the log at [param path] in over the run log.
signal replay_requested(path: String, hero_id: String, boss_id: String)
## Enqueue a toast (U5). [param kind] is `&"unlock"` or `&"warning"`.
signal toast(kind: StringName, payload: Dictionary)
## The top screen's `committed` sub-state changed (U4).
signal committed_changed(on: bool)
## End a running transition now (U4).
signal skip_requested
## The player quit; settings are flushed.
signal quit_requested
## An intent was dropped; [param reason] is `transitioning`, `bad_state`, `committed` or `bad_index`.
signal ui_intent_rejected(name: StringName, reason: StringName)

const SCREEN_MENU: StringName = &"main_menu"
const SCREEN_RESUME: StringName = &"resume_prompt"
const SCREEN_HERO: StringName = &"hero_select"
const SCREEN_RUN_START: StringName = &"run_start"
const SCREEN_BOSS: StringName = &"boss_intro"
const SCREEN_MATCH: StringName = &"match"
const SCREEN_DRAFT_TREASURE: StringName = &"draft_treasure"
const SCREEN_DRAFT_BUNDLE: StringName = &"draft_bundle"
const SCREEN_VICTORY: StringName = &"summary_victory"
const SCREEN_DEFEAT: StringName = &"summary_defeat"
const SCREEN_ABANDONED: StringName = &"summary_abandoned"
const SCREEN_LOG: StringName = &"run_log"
const SCREEN_DETAIL: StringName = &"run_detail"
const SCREEN_REPLAYS: StringName = &"replay_list"
const SCREEN_SETTINGS: StringName = &"settings"
const SCREEN_CONTROLS: StringName = &"controls"
const SCREEN_GLOSSARY: StringName = &"glossary"
const SCREEN_PAUSE: StringName = &"pause"
const SCREEN_CONFIRM: StringName = &"confirm"
const SCREEN_NOTICE: StringName = &"notice"
const SCREEN_DATA_ERROR: StringName = &"data_error"
## U2's intent column per screen; every other (screen, intent) pair is `bad_state`
## (AC-11). `skip` is legal anywhere a transition or `run_start` can end.
const LEGAL: Dictionary = {
	SCREEN_MENU: [&"new_run_requested", &"continue_requested", &"open_run_log", &"open_settings", &"retry_lock", &"quit_requested"],
	SCREEN_RESUME: [&"continue", &"abandon", &"back"],
	SCREEN_HERO: [&"start_run", &"back"],
	SCREEN_RUN_START: [],
	SCREEN_BOSS: [&"begin_match", &"open_pause"],
	SCREEN_DRAFT_TREASURE: [&"pick", &"skip_pick", &"open_pause"],
	SCREEN_DRAFT_BUNDLE: [&"pick", &"skip_pick", &"open_pause"],
	SCREEN_VICTORY: [&"new_run_same_hero", &"go_hero_select", &"go_main_menu"],
	SCREEN_DEFEAT: [&"new_run_same_hero", &"go_hero_select", &"go_main_menu"],
	SCREEN_ABANDONED: [&"new_run_same_hero", &"go_main_menu"],
	SCREEN_LOG: [&"load_more", &"open_run", &"open_replays", &"new_run_requested", &"back"],
	SCREEN_DETAIL: [&"back"],
	SCREEN_REPLAYS: [&"play_replay", &"back"],
	SCREEN_SETTINGS: [&"set_setting", &"clear_run_records_requested", &"reset_profile_requested", &"open_controls", &"open_glossary", &"back"],
	SCREEN_CONTROLS: [&"set_binding", &"reset_bindings", &"back"],
	SCREEN_GLOSSARY: [&"back"],
	SCREEN_PAUSE: [&"close", &"open_settings", &"open_glossary", &"set_setting", &"abandon", &"go_main_menu"],
	SCREEN_CONFIRM: [&"confirm", &"cancel"],
	SCREEN_NOTICE: [&"notice_new_run"],
	SCREEN_DATA_ERROR: [&"quit_requested"],
}
## U4's terminal intents: each sets `committed` until the screen is swapped out.
const TERMINAL: Array[StringName] = [&"pick", &"skip_pick", &"start_run", &"begin_match", &"continue", &"new_run_same_hero"]
## `run_warning` codes repeated as a status line (U5).
const ACTIONABLE_WARNINGS: Array[String] = [RunCodes.W_SAVE_FAILED, RunCodes.W_BOSS_POOL_SHORT]
const LOAD_QUIET: Array[StringName] = [&"OK", &"FRESH"]
const FAULT_WARNING: String = "match_faulted"

## What the shell is showing.
var state: ShellState = ShellState.new()

var _run: RunMachine
var _draft: RewardDraft
var _meta: MetaApi
var _db: CardDatabase
var _config: Dictionary
var _models: RunReadModels
## Run-scope events not yet applied.
var _pending: Array[Dictionary] = []
## `run_floor_entered` arrived behind `run_started`: `run_start` may advance (S9).
var _intro_ready: bool = false
var _status_line: String = ""
## The load-status line shows once per launch (U2).
var _load_line_shown: bool = false
var _on_confirm: Callable = Callable()
## Loaded archive rows, newest first.
var _log_rows: Array = []
## Debug builds: the fixture's run read model, standing in for the machine's.
var _debug_model: Dictionary = {}
var _debug_overrides: Dictionary = {}


## ADR-0011 Key Interfaces. [param ui_config] is the `config("run_ui")` body.
func _init(run: RunMachine, draft: RewardDraft, meta: MetaApi, db: CardDatabase, ui_config: Dictionary) -> void:
	_run = run
	_draft = draft
	_meta = meta
	_db = db
	_config = ui_config
	_models = RunReadModels.new(meta, db, ui_config)
	_run.run_log_opened.connect(_on_run_log)
	_meta.unlock_granted.connect(_on_unlock_granted)
	if _meta.settings_bus != null:
		_meta.settings_bus.settings_changed.connect(_on_setting_changed)


## S1: opens the main menu and reads the durable notification queue.
func start() -> void:
	_open_menu(RunUiConfig.KIND_FADE)
	_enqueue_pending_notifications()


## The settings record, for the shell to apply at start (ADR-0011 Decision 4).
func settings() -> Dictionary:
	return _meta.get_settings()


## True when the profile is `ReadOnly` (U2 banner).
func read_only_text() -> String:
	if not _meta.is_read_only():
		return ""
	return RunText.t("banner.newer") if _meta.load_status() == &"E_SCHEMA_NEWER" else RunText.t("banner.locked")


## The read model of the run, for tests and the debug loader.
func read_model() -> Dictionary:
	return _run_model()


## U1.2: validates [param name] against the shell state, then issues its command, or
## drops it with [signal ui_intent_rejected].
func intent(name: StringName, args: Dictionary = {}) -> void:
	if name == &"skip":
		_on_skip()
		return
	if state.transitioning:
		_reject(name, &"transitioning")
		return
	var top: StringName = state.top()
	if not (LEGAL.get(top, []) as Array).has(name):
		_reject(name, &"bad_state")
		return
	if state.committed and TERMINAL.has(name):
		_reject(name, &"committed")
		return
	if top == SCREEN_CONFIRM:
		_on_confirm_intent(name)
	else:
		_dispatch(name, args)


## S11: `MatchView` is done. Applies the buffered events; a fault or a skipped step ends
## on `run_floor_entered`, a win on `draft_offered`, a loss on `run_ended`.
func on_match_view_finished(_result: Variant) -> void:
	state.base = &""
	state.committed = false
	_drain()
	if state.base == &"":
		_open_for_phase()


## A toast was shown: acks an unlock, once (U5). `ToastLayer.shown` connects here.
func on_toast_shown(kind: StringName, key: String) -> void:
	if kind == &"unlock":
		_meta.ack_notification(key)


## Debug builds: opens [param screen] from a fixture's [param run_model], with
## [param overrides] over the built read model and no transition (U10).
func debug_open(screen: StringName, run_model: Dictionary, overrides: Dictionary) -> void:
	_debug_model = run_model
	_debug_overrides = overrides
	state.overlays.clear()
	match screen:
		SCREEN_RESUME, SCREEN_SETTINGS, SCREEN_CONTROLS, SCREEN_GLOSSARY:
			_open_menu(&"none")
			_open_overlay(screen)
		SCREEN_PAUSE:
			_open_screen(SCREEN_BOSS, &"none")
			_open_overlay(screen)
		SCREEN_DETAIL:
			_open_menu(&"none")
			_push(SCREEN_DETAIL, overrides)
		_:
			_open_screen(screen, &"none")


func _dispatch(name: StringName, args: Dictionary) -> void:
	match name:
		&"new_run_requested":
			_open_hero_select()
		&"continue_requested":
			_open_overlay(SCREEN_RESUME)
		&"open_run_log":
			_load_log_page(true)
			_open_base(SCREEN_LOG, _log_model(), RunUiConfig.KIND_FADE)
		&"open_settings":
			_open_overlay(SCREEN_SETTINGS)
		&"open_controls":
			_open_overlay(SCREEN_CONTROLS)
		&"open_glossary":
			_open_overlay(SCREEN_GLOSSARY)
		&"retry_lock":
			var _reload: Dictionary = _meta.load_profile()
			_open_menu(&"none")
		&"quit_requested":
			var _flushed: Error = _meta.save_profile()
			quit_requested.emit()
		&"continue":
			_resume(false)
		&"abandon":
			_ask_abandon()
		&"back":
			_on_back()
		&"close":
			_pop()
		&"start_run":
			_on_start_run(str(args.get("hero_id", "")), str(args.get("seed_input", "")))
		&"begin_match":
			_begin_match()
		&"open_pause":
			_open_overlay(SCREEN_PAUSE)
		&"pick":
			_pick(int(args.get("index", -1)))
		&"skip_pick":
			_skip_pick()
		&"new_run_same_hero":
			_commit()
			_new_run(str(_run_model().get("hero", {}).get("id", "")), "")
		&"go_hero_select":
			var _left: Error = _run.return_to_menu()
			_open_hero_select()
		&"go_main_menu":
			_go_main_menu()
		&"load_more":
			_load_log_page(false)
			screen_refreshed.emit(SCREEN_LOG, _log_model())
		&"open_run":
			_open_run_detail(str(args.get("run_id", "")))
		&"open_replays":
			_open_replays(str(args.get("run_id", "")))
		&"play_replay":
			replay_requested.emit(str(args.get("path", "")), str(args.get("hero_id", "")), str(args.get("boss_id", "")))
		&"set_setting":
			var _set: Error = _meta.set_setting(StringName(str(args.get("key", ""))), args.get("value"))
		&"set_binding":
			_set_binding(str(args.get("action", "")), args.get("event", {}))
		&"reset_bindings":
			var _cleared: Error = _meta.set_setting(&"bindings", {})
		&"clear_run_records_requested":
			_ask(RunText.t("settings.clear.title"), RunText.t("settings.clear.body"), RunText.t("settings.clear.confirm"), "", func() -> void:
				var _gone: Error = _meta.clear_run_records())
		&"reset_profile_requested":
			var token: String = str(_models.settings().reset_token)
			_ask(RunText.t("settings.reset.title"), RunText.t("settings.reset.body", {"token": token}), RunText.t("settings.reset.confirm"), token, func() -> void:
				var _reset: Error = _meta.reset_profile(token)
				_open_menu(&"none"))
		&"notice_new_run":
			_pop()
			_open_hero_select()


func _reject(name: StringName, reason: StringName) -> void:
	ui_intent_rejected.emit(name, reason)


func _on_skip() -> void:
	if state.transitioning:
		skip_requested.emit()
	if state.top() == SCREEN_RUN_START and _intro_ready:
		_intro_ready = false
		_open_screen(SCREEN_BOSS, RunUiConfig.KIND_INTRO_SLIDE)


func _on_back() -> void:
	match state.top():
		SCREEN_HERO:
			var _left: Error = _run.suspend()
			_open_menu(RunUiConfig.KIND_FADE)
		SCREEN_LOG:
			_open_menu(RunUiConfig.KIND_FADE)
		_:
			_pop()


func _on_confirm_intent(name: StringName) -> void:
	var then: Callable = _on_confirm
	_on_confirm = Callable()
	_pop()
	if name == &"confirm" and then.is_valid():
		then.call()


## S7 / AC-14: a saved run must be given up first; [method RunMachine.new_run] then
## ends it as `abandoned / player` (R2 step 1).
func _on_start_run(hero_id: String, seed_input: String) -> void:
	if _meta.load_active_run() == null:
		_commit()
		_new_run(hero_id, seed_input)
		return
	_ask(RunText.t("hero.replace.title"), RunText.t("hero.replace.body"), RunText.t("hero.replace.confirm"), "", func() -> void:
		_commit()
		_new_run(hero_id, seed_input))


func _new_run(hero_id: String, seed_input: String) -> void:
	var code: Error = _run.new_run(hero_id, seed_input)
	if code != OK:
		_uncommit_with(code)
		return
	_drain()


func _begin_match() -> void:
	_commit()
	var model: Dictionary = _run_model()
	var driver: MatchDriver = _run.begin_match()
	if driver == null:
		_uncommit_with(_run.last_error)
		return
	state.base = SCREEN_MATCH
	match_requested.emit(driver, {
		"floor": int(model.get("floor", 1)),
		"boss_def_id": str(model.get("boss", {}).get("id", "")),
		"hero_def_id": str(model.get("hero", {}).get("id", "")),
		"treasures": Array(model.get("treasures", [])),
	})


## U8, S14, S15, AC-21, AC-28.
func _pick(index: int) -> void:
	var offer: Variant = _run.current_offer()
	var ids: Array = offer.option_ids if offer is Dictionary else []
	if index < 0 or index >= ids.size() or not _db.has(str(ids[index])):
		_reject(&"pick", &"bad_index")
		return
	_commit()
	_draft_pick(StringName(str(offer.kind)), ids[index])


func _skip_pick() -> void:
	var offer: Variant = _run.current_offer()
	if not offer is Dictionary or not bool(offer.allow_skip):
		_reject(&"skip_pick", &"bad_state")
		return
	_commit()
	_draft_pick(StringName(str(offer.kind)), null)


func _draft_pick(kind: StringName, id: Variant) -> void:
	var code: Error = _run.draft_pick(kind, id)
	if code != OK:
		_uncommit_with(code)
	_drain()


## S5, S6, T15, T16. [param then_abandon] is the resume prompt's Abandon: T13 is legal
## from the resumed phase, never from `Menu`, so the saved run is resumed first and the
## events of both commands drain as one, `run_ended` deciding.
func _resume(then_abandon: bool) -> void:
	_commit()
	var code: Error = _run.resume()
	if code != OK:
		_on_resume_failed(code)
		return
	_pop()
	if then_abandon:
		var _ended: Error = _run.abandon()
	_drain()


## AC-13: a reason dialog with one New Run button. The record is already archived as a
## system abandon, so the run is closed here and the Continue card is gone.
func _on_resume_failed(code: Error) -> void:
	_pending.clear()
	state.committed = false
	committed_changed.emit(false)
	if _run.state != null:
		var _left: Error = _run.return_to_menu()
	_pop()
	_push(SCREEN_NOTICE, {"title": RunText.t("notice.resume.title"), "body": RunText.t("notice.resume.body", {"reason": RunText.t("notice.reason.%s" % RunCodes.code_name(code))})})


func _ask_abandon() -> void:
	var from_prompt: bool = state.top() == SCREEN_RESUME
	_ask(RunText.t("abandon.title"), RunText.t("abandon.body"), RunText.t("abandon.confirm"), "", func() -> void:
		if from_prompt:
			_resume(true)
			return
		var code: Error = _run.abandon()
		if code == OK:
			state.overlays.clear()
			_drain())


## S23 from pause, S19 from a summary: `suspend` keeps the save, `return_to_menu` ends.
func _go_main_menu() -> void:
	var left: Error = _run.suspend() if state.top() == SCREEN_PAUSE else _run.return_to_menu()
	if left == OK:
		_open_menu(RunUiConfig.KIND_FADE)


func _ask(title: String, body: String, confirm_label: String, token: String, then: Callable) -> void:
	_on_confirm = then
	_push(SCREEN_CONFIRM, {"title": title, "body": body, "confirm_label": confirm_label, "token": token})


func _commit() -> void:
	state.committed = true
	committed_changed.emit(true)


## S8, U8: a rejected terminal intent uncommits the screen and says why.
func _uncommit_with(code: Error) -> void:
	state.committed = false
	committed_changed.emit(false)
	toast.emit(&"warning", {"title": RunText.t("rejected.%s" % RunCodes.code_name(code))})


func _on_run_log(log: EventLog) -> void:
	log.subscribe(_on_event)


func _on_event(event: Dictionary) -> void:
	_pending.append(event)


## U1.3, S11: applies the queued events; the last screen-deciding one opens its screen.
func _drain() -> void:
	if state.base == SCREEN_MATCH:
		return
	var target: StringName = &""
	var ended: bool = false
	for event: Dictionary in _pending:
		var payload: Dictionary = event.get("payload", {})
		match StringName(str(event.get("type", ""))):
			RunCodes.EVENT_RUN_STARTED:
				target = SCREEN_RUN_START
				_intro_ready = false
			RunCodes.EVENT_FLOOR_ENTERED:
				if target == SCREEN_RUN_START:
					_intro_ready = true
				else:
					target = SCREEN_BOSS
			RunCodes.EVENT_DRAFT_OFFERED:
				target = SCREEN_DRAFT_BUNDLE if str(payload.get("kind")) == DraftRecord.KIND_BUNDLE else SCREEN_DRAFT_TREASURE
			RunCodes.EVENT_RUN_ENDED:
				target = _summary_of(str(payload.get("result", "")))
				ended = true
			RunCodes.EVENT_MATCH_FAULTED:
				_warn(FAULT_WARNING)
			RunCodes.EVENT_RUN_WARNING:
				_warn(str(payload.get("code", "")))
	_pending.clear()
	if target != &"":
		state.overlays.clear()
		_open_screen(target, _kind_for(target))
	if ended:
		_enqueue_pending_notifications()


func _summary_of(outcome: String) -> StringName:
	match outcome:
		RunState.STATUS_VICTORY:
			return SCREEN_VICTORY
		RunState.STATUS_ABANDONED:
			return SCREEN_ABANDONED
	return SCREEN_DEFEAT


func _kind_for(id: StringName) -> StringName:
	match id:
		SCREEN_BOSS:
			return RunUiConfig.KIND_INTRO_SLIDE
		SCREEN_DRAFT_TREASURE, SCREEN_DRAFT_BUNDLE:
			return RunUiConfig.KIND_DRAFT_REVEAL
	return RunUiConfig.KIND_FADE


func _warn(code: String) -> void:
	var text: String = RunText.t("warning.%s" % code)
	toast.emit(&"warning", {"title": text})
	if ACTIONABLE_WARNINGS.has(code):
		_status_line = text


func _on_unlock_granted(key: String, kind: StringName, id: String, _by_run_id: String, _retro: bool) -> void:
	toast.emit(&"unlock", _models.unlock_toast(key, String(kind), id))


func _enqueue_pending_notifications() -> void:
	for note: Variant in _meta.pending_notifications():
		if note is Dictionary:
			toast.emit(&"unlock", _models.unlock_toast(str(note.get("key", "")), str(note.get("kind", "")), str(note.get("id", ""))))


func _on_setting_changed(key: StringName, _value: Variant) -> void:
	if key == &"bindings" and state.top() == SCREEN_CONTROLS:
		screen_refreshed.emit(SCREEN_CONTROLS, _models.controls())


## Rebinds [param action]'s device type to [param stored], keeping its other devices,
## so a keyboard rebind does not cost the action its gamepad button.
func _set_binding(action: String, stored: Variant) -> void:
	if not stored is Dictionary or stored.is_empty() or not InputMap.has_action(action):
		return
	var bindings: Dictionary = {}
	var current: Variant = _meta.get_setting(&"bindings")
	if current is Dictionary:
		bindings = (current as Dictionary).duplicate(true)
	var kept: Array = []
	for event: InputEvent in InputMap.action_get_events(action):
		var row: Dictionary = InputBindings.to_dict(event)
		if not row.is_empty() and row.type != stored.get("type"):
			kept.append(row)
	kept.append(stored)
	bindings[action] = kept
	var _set: Error = _meta.set_setting(&"bindings", bindings)


func _load_log_page(reset: bool) -> void:
	if reset:
		_log_rows.clear()
	var total: int = _meta.run_log_count()
	var page: int = int(_config.run_log_page)
	var end: int = total - _log_rows.size()
	var start: int = maxi(end - page, 0)
	var rows: Array = _meta.run_log(start, end - start)
	rows.reverse()
	_log_rows.append_array(rows)


func _log_model() -> Dictionary:
	return _models.run_log(_log_rows, _meta.run_log_count())


func _open_run_detail(run_id: String) -> void:
	for row: Variant in _log_rows:
		if row is Dictionary and str(row.get("run_id")) == run_id and int(row.get("schema_version", 0)) == RunRecord.SCHEMA_VERSION:
			_push(SCREEN_DETAIL, _models.run_detail(row))
			return


func _open_replays(run_id: String) -> void:
	for row: Variant in _log_rows:
		if row is Dictionary and str(row.get("run_id")) == run_id:
			_push(SCREEN_REPLAYS, _models.replays(row))
			return


func _open_hero_select() -> void:
	var _opened: Error = _run.open_new_run()
	_open_screen(SCREEN_HERO, RunUiConfig.KIND_FADE)


func _open_menu(kind: StringName) -> void:
	state.overlays.clear()
	_open_screen(SCREEN_MENU, kind)


func _open_for_phase() -> void:
	match _run.phase():
		RunState.STATUS_PRE_MATCH:
			_open_screen(SCREEN_BOSS, RunUiConfig.KIND_FADE)
		RunState.STATUS_POST_MATCH_REWARD:
			var offer: Variant = _run.current_offer()
			var bundle: bool = offer is Dictionary and str(offer.kind) == DraftRecord.KIND_BUNDLE
			_open_screen(SCREEN_DRAFT_BUNDLE if bundle else SCREEN_DRAFT_TREASURE, RunUiConfig.KIND_FADE)
		RunState.STATUS_VICTORY, RunState.STATUS_DEFEAT, RunState.STATUS_ABANDONED:
			_open_screen(_summary_of(_run.phase()), RunUiConfig.KIND_FADE)
		_:
			_open_menu(RunUiConfig.KIND_FADE)


func _open_screen(id: StringName, kind: StringName) -> void:
	_open_base(id, _model_for(id), kind)


func _open_base(id: StringName, model: Dictionary, kind: StringName) -> void:
	state.base = id
	state.committed = false
	screen_requested.emit(id, _with_overrides(model), kind)


func _open_overlay(id: StringName) -> void:
	_push(id, _model_for(id))


func _push(id: StringName, model: Dictionary) -> void:
	state.overlays.append(id)
	overlay_requested.emit(id, _with_overrides(model))


func _pop() -> void:
	if not state.overlays.is_empty():
		state.overlays.pop_back()
		state.committed = false
		overlay_closed.emit()


func _with_overrides(model: Dictionary) -> Dictionary:
	if _debug_overrides.is_empty():
		return model
	var merged: Dictionary = model.duplicate()
	merged.merge(_debug_overrides, true)
	return merged


func _run_model() -> Dictionary:
	if _debug_model.is_empty():
		return _run.read_model()
	var model: Dictionary = _run.read_model()
	model.merge(_debug_model, true)
	return model


func _model_for(id: StringName) -> Dictionary:
	var run_model: Dictionary = _run_model()
	match id:
		SCREEN_MENU:
			return _models.main_menu(run_model, _take_load_line(), _status_line)
		SCREEN_RESUME:
			return _models.resume_prompt(run_model)
		SCREEN_HERO:
			return _models.hero_select(run_model, RunMachine.seed_preview)
		SCREEN_RUN_START:
			var settings_row: Dictionary = _meta.get_settings()
			return _models.run_start(run_model, RunUiConfig.t_transition(_config, RunUiConfig.KIND_RUN_START, str(settings_row.get("anim_speed", RunUiConfig.SPEED_NORMAL)), false))
		SCREEN_BOSS:
			return _models.boss_intro(run_model)
		SCREEN_DRAFT_TREASURE, SCREEN_DRAFT_BUNDLE:
			return _models.draft(run_model, _reveal_step_ms())
		SCREEN_VICTORY, SCREEN_DEFEAT:
			return _models.summary(run_model, run_model.get("unlocks_granted", []), _status_line)
		SCREEN_ABANDONED:
			return _models.summary_abandoned(run_model)
		SCREEN_SETTINGS:
			return _models.settings()
		SCREEN_CONTROLS:
			return _models.controls()
		SCREEN_GLOSSARY:
			return _models.glossary()
		SCREEN_PAUSE:
			return _models.pause(run_model)
		SCREEN_LOG:
			return _log_model()
	return {}


## F2's `draft_reveal` over the slots; 0 under `reduce_motion`, where it is one fade.
func _reveal_step_ms() -> int:
	var row: Dictionary = _meta.get_settings()
	if bool(row.get("reduce_motion", false)):
		return 0
	var total: int = RunUiConfig.t_transition(_config, RunUiConfig.KIND_DRAFT_REVEAL, str(row.get("anim_speed", RunUiConfig.SPEED_NORMAL)), false)
	@warning_ignore("integer_division")
	return total / RunReadModels.DRAFT_SLOTS


func _take_load_line() -> String:
	if _load_line_shown:
		return ""
	_load_line_shown = true
	var status: StringName = _meta.load_status()
	return "" if LOAD_QUIET.has(status) else RunText.t("load.%s" % status)
