## An isolated loaner attempt. Saved counters are never trusted: resume replays
## every encounter's accepted engine commands and derives its objectives anew.
class_name MasteryTrial
extends RefCounted

signal changed(model: Dictionary)

const TRIAL_ID: String = "trial_primal_crown"
const COLLECTION_ID: String = "law-of-the-jungle"
const REQUIRED: Dictionary = {"predator": 3, "friendly": 1, "enemy": 1}
const HERO_IDS: Array[String] = ["hero_war", "hero_decay", "hero_knowledge", "hero_fortune", "hero_order", "hero_shadow"]

var _db: CardDatabase
var _meta: MetaApi
var _planner_factory: Callable
var _definition: Dictionary = {}
var _driver: MatchDriver
var _attempt_id: String = ""
var _history: Array = []
var _index: int = 0
var _status: String = "idle"
var _objectives: Dictionary = {"predator": 0, "friendly": 0, "enemy": 0}
var _error: String = ""
var _replaying: bool = false
var _verified: bool = false
var _rng: RngService


func _init(db: CardDatabase, meta: MetaApi, planner_factory: Callable) -> void:
	_db = db
	_meta = meta
	_planner_factory = planner_factory
	var body: Variant = db.config(COLLECTION_ID + "/trial")
	if body is Dictionary:
		_definition = body


func start(trial_id: String = TRIAL_ID) -> Error:
	if trial_id != _definition.get("id") or not _access().met:
		return SaveErrors.E_RANGE
	if _meta.is_read_only():
		return SaveErrors.E_READONLY
	shutdown()
	_attempt_id = ProfileSchema.new_profile_id()
	_history = []
	_index = 0
	_verified = false
	_error = ""
	_open([])
	return _persist()


func retry() -> Error:
	return start(TRIAL_ID)


func retry_save() -> Error:
	return _persist() if not _attempt_id.is_empty() else SaveErrors.E_RANGE


func resume() -> Error:
	if not _access().met:
		return SaveErrors.E_RANGE
	var saved: Variant = _meta.load_trial()
	if not saved is Dictionary or saved.get("trial_id") != _definition.get("id") or saved.get("version") != 1 or saved.get("data_version") != _db.data_version():
		return SaveErrors.E_RANGE
	if not saved.get("history") is Array or not saved.get("commands") is Array or not saved.get("attempt_id") is String:
		return SaveErrors.E_RANGE
	if saved.history.size() > 3:
		return SaveErrors.E_RANGE
	shutdown()
	_attempt_id = saved.attempt_id
	_history = []
	_index = 0
	_verified = false
	_replaying = true
	for commands: Variant in saved.history:
		if not _valid_commands(commands):
			return _bad_replay()
		_open(commands)
		if not _driver.replay_valid() or _status != "encounter_won":
			return _bad_replay()
		_history.append(commands.duplicate(true))
		_index += 1
	if _index == 3:
		_status = "completed"
		_verified = true
	else:
		if not _valid_commands(saved.commands):
			return _bad_replay()
		_open(saved.commands, saved.get("ai_snapshot", {}), saved.get("continuation", {}))
		if not _driver.replay_valid() or not _error.is_empty():
			return _bad_replay()
		if _status == "encounter_won" and _index == 2:
			_finish_attempt()
	_replaying = false
	return _persist()


func next_encounter() -> Error:
	if _status != "encounter_won" or _index >= 2:
		return SaveErrors.E_RANGE
	_history.append(_driver.commands())
	_index += 1
	_open([])
	return _persist()


func driver() -> MatchDriver:
	return _driver


func tick() -> void:
	if _driver != null and _status == "playing":
		_driver.tick()


func shutdown() -> void:
	if _driver != null:
		_driver.shutdown()
		_driver = null


func view() -> Dictionary:
	return {"trial_id": str(_definition.get("id", TRIAL_ID)), "status": _status,
		"encounter_index": _index, "encounter_count": 3, "objectives": _objectives.duplicate(),
		"required": REQUIRED.duplicate(), "access": _access(), "error": _error}


func record() -> Dictionary:
	var continuation: Dictionary = _driver.continuity() if _driver != null and _index < 3 else {}
	var ai_snapshot: Dictionary = _rng.snapshot_to_json_dict() if _rng != null else {}
	for table: String in ["streams", "fork_points"]:
		if ai_snapshot.has(table):
			for stream: String in ai_snapshot[table].keys():
				if not stream.begins_with("ai_"):
					ai_snapshot[table].erase(stream)
	return {"version": 1, "trial_id": str(_definition.get("id", TRIAL_ID)), "attempt_id": _attempt_id,
		"data_version": _db.data_version(), "history": _history.duplicate(true),
		"ai_snapshot": ai_snapshot,
		"continuation": continuation,
		"commands": _driver.commands() if _driver != null and _index < 3 else []}


func belongs_to(meta: MetaApi) -> bool:
	return meta == _meta and not _attempt_id.is_empty()


func verified_complete() -> bool:
	return _verified and _status == "completed"


func source_id() -> String:
	return "%s:v1:%s" % [TRIAL_ID, _attempt_id]


func _access() -> Dictionary:
	var evaluator: UnlockEvaluator = UnlockEvaluator.new(_db, {})
	return evaluator.read_model(access_condition(), _meta.get_stats())


static func access_condition() -> Dictionary:
	var parts: Array = [{"type": "runs_won", "hero": "any", "n": 20}]
	for hero_id: String in HERO_IDS:
		parts.append({"type": "runs_won", "hero": hero_id, "n": 2})
	return {"type": "all_of", "of": parts}


func _open(commands: Array, ai_snapshot: Dictionary = {}, continuation: Dictionary = {}) -> void:
	shutdown()
	_error = ""
	_status = "playing"
	var encounter: Dictionary = _definition.encounters[_index]
	var boss: Dictionary = _db.boss(str(encounter.boss_id))
	var rng: RngService = RngService.new(_index + 71, _db.data_version())
	_rng = rng
	if not ai_snapshot.is_empty():
		var restored: Error = rng.restore(RngService.snapshot_from_json_dict(ai_snapshot))
		if restored != OK:
			_error = "Trial random state could not be restored."
	var logging: Dictionary = _db.config("rng_event_log")
	var log: EventLog = EventLog.new(EventLog.max_events_for(logging), EventLog.SCOPE_MATCH)
	var treasures: Treasures = Treasures.new(_db, _db.config("treasures_balance"))
	var player_deck: Array = _ordered_deck(_definition.deck, encounter.get("player_draw_order", _definition.get("player_draw_order", [])))
	var boss_deck: Array = _ordered_deck(encounter.deck, encounter.get("boss_draw_order", []))
	var config: Dictionary = {
		"floor": _index + 1, "band": int(encounter.band),
		"featured_collection_id": COLLECTION_ID, "scripted_decks": true,
		"opening_board": {"player": encounter.get("player_opening_board", []), "boss": encounter.get("enemy_opening_board", [])},
		"rng_match": rng.stream("match_%d" % (_index + 1)), "rng_ai": rng.stream("ai_%d" % (_index + 1)),
		"log": log, "commands": commands, "continuation": continuation,
		"player": {"hero_def_id": _definition.hero_id, "deck": player_deck,
			"hook_installers": treasures.installers_for(_definition.treasures, {})},
		"boss": {"boss_def_id": encounter.boss_id, "deck": boss_deck, "health": int(encounter.health),
			"ai_id": boss.ai_profile, "hook_installers": Treasures.passive_installer(boss)},
	}
	_driver = MatchDriver.new(config, _db, _meta.get_settings(), _planner_factory)
	_driver.command_committed.connect(_on_command)
	_driver.match_ended.connect(_on_ended)
	_derive()


static func _ordered_deck(deck: Array, order: Array) -> Array:
	var rest: Array = deck.duplicate()
	var result: Array = []
	for id: String in order:
		if rest.has(id):
			rest.erase(id)
			result.append(id)
	result.append_array(rest)
	return result


static func _valid_commands(commands: Variant) -> bool:
	if not commands is Array:
		return false
	for command: Variant in commands:
		if not command is Dictionary or not command.get("type") is String or not ["player", "boss"].has(command.get("issuer")):
			return false
	return true


func _derive() -> void:
	if _verified:
		_status = "completed"
		return
	_objectives = {"predator": 0, "friendly": 0, "enemy": 0}
	for event: Dictionary in _driver.events_since(0):
		var payload: Dictionary = event.payload
		if event.type == "effect_resolved" and payload.get("owner") == "player" and payload.get("predator") is Dictionary:
			var predator: Dictionary = payload.predator
			if predator.get("friendly", false) or predator.get("enemy", false):
				_objectives.predator += 1
				_objectives.friendly += 1 if predator.get("friendly", false) else 0
				_objectives.enemy += 1 if predator.get("enemy", false) else 0
		if event.type == "match_ended":
			_status = "encounter_won" if payload.get("result") == "win" and _objectives_met() else "failed"


func _objectives_met() -> bool:
	return _objectives.predator >= REQUIRED.predator and _objectives.friendly >= REQUIRED.friendly and _objectives.enemy >= REQUIRED.enemy


func _on_command(_command: Dictionary) -> void:
	_derive()
	if _status == "encounter_won" and _index == 2:
		_finish_attempt()
	if not _replaying:
		_persist()


func _on_ended(_result: Dictionary) -> void:
	_derive()
	if _status == "encounter_won" and _index == 2:
		_finish_attempt()
	if not _replaying:
		_persist()


func _finish_attempt() -> void:
	_history.append(_driver.commands())
	_index = 3
	_verified = true
	_status = "completed"


func _persist() -> Error:
	var outcome: Error = _meta.save_trial(self)
	_error = "" if outcome == OK else "Trial progress could not be saved."
	changed.emit(view())
	return outcome


func _bad_replay() -> Error:
	shutdown()
	_status = "failed"
	_error = "This trial attempt could not be replayed. Retry to begin a new attempt."
	_replaying = false
	changed.emit(view())
	return SaveErrors.E_RANGE


static func validate_config(body: Dictionary, db: Variant) -> Array:
	var issues: Array = []
	if body.get("id") != TRIAL_ID or body.get("collection") != COLLECTION_ID or not HERO_IDS.has(str(body.get("hero_id", ""))):
		issues.append(_issue("identity", "Unknown trial, collection, or loaner hero."))
	if not body.get("deck") is Array or body.get("deck", []).size() != 36:
		issues.append(_issue("deck", "A trial needs exactly 36 loaner cards."))
	if not body.get("treasures") is Array or body.get("treasures", []).size() != 3:
		issues.append(_issue("treasures", "A trial needs three loaner treasures."))
	if not body.get("encounters") is Array or body.get("encounters", []).size() != 3:
		issues.append(_issue("encounters", "A trial needs three encounters."))
	if not issues.is_empty():
		return issues
	var hero: Variant = db.hero(str(body.hero_id))
	for id: Variant in body.deck:
		var card: Variant = db.card(str(id))
		if not card is Dictionary or not hero is Dictionary or not ["neutral", hero.get("set")].has(card.get("set")):
			issues.append(_issue("deck", "Loaner cards must be Neutral or match the loaner hero."))
	for id: Variant in body.treasures:
		if not db.treasure(str(id)) is Dictionary:
			issues.append(_issue("treasures", "Unknown loaner treasure."))
	for encounter: Variant in body.encounters:
		if not encounter is Dictionary:
			issues.append(_issue("encounters", "Encounter must be an object."))
			continue
		if not db.boss(str(encounter.get("boss_id", ""))) is Dictionary or not encounter.get("deck") is Array or encounter.get("deck", []).is_empty() or int(encounter.get("health", 0)) < 1 or not [1, 2].has(int(encounter.get("band", 0))):
			issues.append(_issue("encounters", "Encounter requires a known boss, deck, band and positive health."))
		for id: Variant in encounter.get("deck", []):
			if not db.card(str(id)) is Dictionary:
				issues.append(_issue("encounters.deck", "Unknown encounter card."))
		if encounter.get("enemy_opening_board", []).is_empty():
			issues.append(_issue("encounters.enemy_opening_board", "Guaranteed enemy prey is required."))
		for id: Variant in encounter.get("enemy_opening_board", []):
			if not db.card(str(id)) is Dictionary:
				issues.append(_issue("encounters.enemy_opening_board", "Unknown opening prey."))
	return issues


static func validate_unlock_config(body: Dictionary, db: Variant) -> Array:
	var rows: Array = UnlockEvaluator.validate_defs([{"host_kind": "collection", "host_id": COLLECTION_ID, "unlock": body}], db,
		{"max_condition_depth": 8, "max_condition_n": 100000, "max_condition_fan_out": 16})
	var condition: Variant = body.get("condition")
	if not condition is Dictionary or condition.get("type") != "all_of" or not condition.get("of") is Array:
		rows.append(_issue("condition", "Collection unlock must require all mastery gates."))
		return rows
	var needed: Dictionary = {"any": 20}
	for hero_id: String in HERO_IDS:
		needed[hero_id] = 2
	var trial_required: bool = false
	for part: Variant in condition.of:
		if not part is Dictionary:
			continue
		if part.get("type") == "runs_won":
			var hero_id: String = str(part.get("hero", "any"))
			if needed.has(hero_id) and int(part.get("n", 0)) >= needed[hero_id]:
				needed.erase(hero_id)
		elif part.get("type") == "trial_completed" and part.get("trial_id") == TRIAL_ID:
			trial_required = true
	if not needed.is_empty() or not trial_required:
		rows.append(_issue("condition", "Collection unlock needs twenty wins, two with every class, and the Primal Crown."))
	return rows


static func _issue(field: String, message: String) -> Dictionary:
	return {"severity": "error", "code": &"E_TRIAL_CONFIG", "file": COLLECTION_ID + "/trial.json", "record_id": TRIAL_ID, "field": field, "message": message}
