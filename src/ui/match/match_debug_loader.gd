## The U11 debug seam (ADR-0009 Decision 4): `--fixture=<name>` runs the real engine
## through `tests/fixtures/match_ui/<name>.json`, and the view then projects
## `events_since(0)`. Debug builds only: `MatchView` loads this script by path behind
## `OS.is_debug_build()`, and the release preset excludes it.
##
## A fixture is `{config, profile, commands}` (`tests/fixtures/match_ui/README.md`).
## The driver comes from `Boot.driver_factory`, with the planner its caller passes:
## `tests/helpers/` is not exported, so this script never names `ImmediatePlannerTask`.
## With no override the factory's own planner runs, and the loader ticks it to rest
## after every command, so the state a fixture reaches does not depend on the frame
## rate.
## [codeblock]
## var args: Dictionary = MatchDebugLoader.from_args(OS.get_cmdline_user_args())
## var loader := MatchDebugLoader.new()
## var controller: MatchController = loader.load_fixture(args.fixture)
## view.set_match_info(loader.match_info)
## view.set_controller(controller)
## [/codeblock]
class_name MatchDebugLoader
extends RefCounted

const FIXTURE_ROOT: String = "res://tests/fixtures/match_ui/"
const ARG_FIXTURE: String = "--fixture="
const ARG_POSE: String = "--pose="
const ARG_PAUSE_AT: String = "--pause-at="
const ARG_ANIM_SPEED: String = "--anim-speed="
const ARG_AI_DEBUG: String = "--ai-debug"
## Fixture names: one file name, so the argument cannot point anywhere else.
const FIXTURE_NAME_PATTERN: String = "^[a-z0-9_]+$"
const DEFAULT_FLOOR: int = 1
## How long one settle may run before the fixture is reported stuck.
const SETTLE_TIMEOUT_MS: int = 60000
const SETTLE_POLL_USEC: int = 200
const POSE_HOVER: String = "hover"
## Macro names a `commands` entry may hold in `macro`.
const MACRO_END_TURNS: String = "end_turns"
const MACRO_PLAY_ALL: String = "play_all"
const MACRO_ATTACK_FACE: String = "attack_face"
const MACRO_PLAY_AND_PASS: String = "play_and_pass"
const MACRO_AGGRO_TO_END: String = "aggro_to_end"
## The most turns a macro may run: a floor under a fixture that never ends.
const MAX_MACRO_TURNS: int = 60

## `{floor, boss_def_id, hero_def_id}` of the loaded match, for the top bar.
var match_info: Dictionary = {}
## Every command the engine refused, as `{command, result}`: empty on a good fixture.
var rejections: Array[Dictionary] = []

var _planner_override: Callable


## [param planner_override] is `Boot.driver_factory`'s: a test passes
## `ImmediatePlannerTask`, an export passes nothing.
func _init(planner_override: Callable = Callable()) -> void:
	_planner_override = planner_override


## [param args] as `{fixture, pose, pause_at, anim_speed, ai_debug}`; absent ones are
## `""`, `""`, `-1`, `""` and `false`.
## [codeblock]
## MatchDebugLoader.from_args(["--fixture=mulligan", "--anim-speed=instant"]).anim_speed
## [/codeblock]
static func from_args(args: PackedStringArray) -> Dictionary:
	var parsed: Dictionary = {"fixture": "", "pose": "", "pause_at": -1, "anim_speed": "", "ai_debug": false}
	for arg: String in args:
		if arg.begins_with(ARG_FIXTURE):
			parsed.fixture = arg.trim_prefix(ARG_FIXTURE)
		elif arg.begins_with(ARG_POSE):
			parsed.pose = arg.trim_prefix(ARG_POSE)
		elif arg.begins_with(ARG_PAUSE_AT):
			parsed.pause_at = int(arg.trim_prefix(ARG_PAUSE_AT))
		elif arg.begins_with(ARG_ANIM_SPEED):
			parsed.anim_speed = arg.trim_prefix(ARG_ANIM_SPEED)
		elif arg == ARG_AI_DEBUG:
			parsed.ai_debug = true
	return parsed


## Boots, builds a real driver from fixture [param fixture_name] and runs its commands.
## Null, with the reason logged, on a bad name, a failed boot or an unreadable file.
func load_fixture(fixture_name: String) -> MatchController:
	if RegEx.create_from_string(FIXTURE_NAME_PATTERN).search(fixture_name) == null:
		push_error("MatchDebugLoader: bad fixture name '%s'" % fixture_name)
		return null
	var fixture: Variant = _read(FIXTURE_ROOT + fixture_name + ".json")
	if not fixture is Dictionary:
		return null
	var booted: BootResult = Boot.boot()
	if not booted.ok:
		push_error("MatchDebugLoader: the data load failed, so no fixture can run")
		return null
	var services: Services = Boot.services()
	for key: String in fixture.get("profile", {}):
		services.meta.set_setting(StringName(key), fixture.profile[key])
	var settings: Dictionary = fixture.get("config", {})
	var config: Dictionary = _match_config(settings, services.card_database)
	var factory: Callable = Boot.driver_factory(_planner_override, OS.get_cmdline_user_args())
	var controller := MatchController.new(factory.call(config))
	match_info = {"floor": int(config.floor), "boss_def_id": str(config.boss.boss_def_id), "hero_def_id": str(config.player.hero_def_id)}
	for entry: Dictionary in fixture.get("commands", []):
		_run(controller, entry)
	for rejection: Dictionary in rejections:
		push_error("MatchDebugLoader: fixture '%s' command refused: %s" % [fixture_name, str(rejection)])
	return controller


## U11: a view-only pose after loading. `hover:<instance_id>` is the 1.5x preview. Poses
## arrive with the stories that need them; an unknown one is reported and skipped.
func apply_pose(view: MatchView, pose: String) -> void:
	if pose == "":
		return
	var parts: PackedStringArray = pose.split(":", true, 1)
	var value: String = parts[1] if parts.size() > 1 else ""
	match parts[0]:
		POSE_HOVER:
			view.hand().set_hover(int(value), 0.0)
		_:
			push_warning("MatchDebugLoader: unknown pose '%s'" % pose)


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("MatchDebugLoader: no fixture at %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("MatchDebugLoader: %s line %d: %s" % [path, json.get_error_line() + 1, json.get_error_message()])
		return null
	return json.data


## The `MatchConfig` (run-structure R3) of a fixture's [param settings], which holds
## `{hero, boss, seed, floor, band, treasures}` and, for a state the shipped lists
## cannot reach quickly, `player_deck`, `boss_deck`, `boss_health` and `max_events`.
func _match_config(settings: Dictionary, db: CardDatabase) -> Dictionary:
	var floor_number: int = int(settings.get("floor", DEFAULT_FLOOR))
	var hero_id: String = str(settings.get("hero", ""))
	var boss_def: Dictionary = db.boss(str(settings.get("boss", "")))
	var hero_deck: Array = []
	for hero: Dictionary in db.heroes():
		if hero.id == hero_id:
			hero_deck = (hero.starter_deck as Array).duplicate()
	var rng := RngService.new(int(settings.get("seed", 0)), db.data_version())
	var cap: int = int(settings.get("max_events", EventLog.max_events_for(db.config("rng_event_log"))))
	var treasures := Treasures.new(db, db.config("treasures_balance"))
	return {
		"floor": floor_number,
		"band": int(settings.get("band", boss_def.band)),
		"rng_match": rng.stream("match_%d" % floor_number),
		"rng_ai": rng.stream("ai_%d" % floor_number),
		"log": EventLog.new(cap, EventLog.SCOPE_MATCH, {"floor": floor_number}),
		"player": {
			"hero_def_id": hero_id,
			"deck": (settings.get("player_deck", hero_deck) as Array).duplicate(),
			"hook_installers": treasures.installers_for(settings.get("treasures", []), {}),
		},
		"boss": {
			"boss_def_id": str(boss_def.id),
			"deck": (settings.get("boss_deck", boss_def.deck) as Array).duplicate(),
			"health": int(settings.get("boss_health", boss_def.health)),
			"hook_installers": Treasures.passive_installer(boss_def),
			"ai_id": str(boss_def.get("ai_id", "default")),
		},
	}


## One `commands` entry: a C2 command as its fields (`issuer` is stamped by the
## driver), or `{macro: …}`, which expands against the live `legal_commands()`.
func _run(controller: MatchController, entry: Dictionary) -> void:
	if not entry.has("macro"):
		_submit(controller, entry)
		return
	match str(entry.macro):
		MACRO_END_TURNS:
			for _turn: int in int(entry.get("count", 1)):
				_end_turn(controller)
		MACRO_PLAY_ALL:
			_play_all(controller, int(entry.get("keep_mana", 0)))
		MACRO_ATTACK_FACE:
			_attack_face(controller)
		MACRO_PLAY_AND_PASS:
			for _turn: int in int(entry.get("count", 1)):
				_play_all(controller, 0)
				_end_turn(controller)
		MACRO_AGGRO_TO_END:
			for _turn: int in MAX_MACRO_TURNS:
				_play_all(controller, 0)
				_attack_face(controller)
				if not _end_turn(controller):
					return
		_:
			push_error("MatchDebugLoader: unknown macro '%s'" % str(entry.macro))


## Submits [param command] and ticks until the planner rests.
func _submit(controller: MatchController, command: Dictionary) -> void:
	var sent: Dictionary = command.duplicate(true)
	sent["issuer"] = MatchRecords.SIDE_PLAYER
	var result: Dictionary = controller.submit(sent)
	if not result.accepted:
		rejections.append({"command": sent, "result": result})
	_settle(controller)


func _settle(controller: MatchController) -> void:
	var started: int = Time.get_ticks_msec()
	controller.tick()
	while controller.is_planning():
		if Time.get_ticks_msec() - started > SETTLE_TIMEOUT_MS:
			push_error("MatchDebugLoader: the planner did not rest within %d ms" % SETTLE_TIMEOUT_MS)
			return
		OS.delay_usec(SETTLE_POLL_USEC)
		controller.tick()


func _player_commands(controller: MatchController, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for command: Dictionary in controller.legal_commands():
		if str(command.type) == type and str(command.issuer) == MatchRecords.SIDE_PLAYER:
			out.append(command)
	return out


## True when the player's turn came back.
func _end_turn(controller: MatchController) -> bool:
	var legal: Array[Dictionary] = _player_commands(controller, MatchRecords.CMD_END_TURN)
	if legal.is_empty():
		return false
	_submit(controller, legal[0])
	return not _player_commands(controller, MatchRecords.CMD_END_TURN).is_empty()


## Plays the last legal entry, so the last board position, until none is left or the
## mana falls to [param keep_mana].
func _play_all(controller: MatchController, keep_mana: int) -> void:
	while true:
		var legal: Array[Dictionary] = _player_commands(controller, MatchRecords.CMD_PLAY_CARD)
		if legal.is_empty() or int(controller.query().snapshot(MatchRecords.SIDE_PLAYER).mana.available) <= keep_mana:
			return
		_submit(controller, legal[legal.size() - 1])


## Every attack that can go at the boss hero does; a Taunt takes it otherwise.
func _attack_face(controller: MatchController) -> void:
	while true:
		var legal: Array[Dictionary] = _player_commands(controller, MatchRecords.CMD_ATTACK)
		if legal.is_empty():
			return
		var boss_id: int = int(controller.query().snapshot(MatchRecords.SIDE_BOSS).hero.entity_id)
		var chosen: Dictionary = legal[0]
		for command: Dictionary in legal:
			if int(command.target_id) == boss_id:
				chosen = command
		_submit(controller, chosen)
