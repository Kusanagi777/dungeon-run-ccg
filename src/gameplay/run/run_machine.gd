## The run's state machine (design/gdd/run-structure.md R2-R10, T1-T21; ADR-0008;
## TR-run-structure-002, 003): one hero and one seed become a gauntlet of boss
## matches, with a draft after every win, ending on the first loss. It owns the
## [RunState], the run-scope [EventLog], the [RngService] and `play_seconds`, and nothing
## else writes them. Pure logic: no Node, no autoload, no coroutine.
##
## **Commands** are the seven of the transition table: [method new_run],
## [method begin_match], [method draft_pick], [method abandon], [method resume],
## [method suspend], [method return_to_menu]. [constant LEGAL_PHASES] is the table;
## a command from any other phase is `E_BAD_PHASE`, with no change and no event.
## Each returns `OK` or a [RunCodes] code, except [method begin_match], which returns
## the driver or null and leaves the code in [member last_error].
##
## `Menu` is not a run state: [member state] is null there and in `hero_select`,
## which is never saved. [method phase] names all of them. T1 is the one trigger with
## no command, so [method open_new_run] takes it, and [method new_run] from `Menu`
## takes T1 and T2 together.
##
## **Saves** go through [MetaApi] and nothing else. A save that fails warns and the
## run goes on; the next save point retries (R7).
##
## **A log per run**: `new_run` and `resume` each open one, so [signal run_log_opened]
## fires before the first event on it, for `RunController` to subscribe.
##
## [codeblock]
## var run := RunMachine.new(db, meta, draft, treasures, run_config, driver_factory)
## run.run_log_opened.connect(controller.on_run_log)
## if run.new_run("hero_war", "") == OK:
##     var driver: MatchDriver = run.begin_match()
## var model: Dictionary = run.read_model()
## [/codeblock]
class_name RunMachine
extends RefCounted

## A new run log was opened, or a saved one reopened. Fires before any new event is
## appended to [param log], so a subscriber misses none.
signal run_log_opened(log: EventLog)

## [method phase] where no run is active: the one value that is not an R1 `status`.
const PHASE_MENU: String = "menu"
## The transition table's triggers and the phases each is legal in (T1-T21).
const LEGAL_PHASES: Dictionary = {
	"new_run": [PHASE_MENU, RunState.STATUS_HERO_SELECT, RunState.STATUS_VICTORY, RunState.STATUS_DEFEAT, RunState.STATUS_ABANDONED],
	"begin_match": [RunState.STATUS_PRE_MATCH],
	"draft_pick": [RunState.STATUS_POST_MATCH_REWARD],
	"abandon": [RunState.STATUS_PRE_MATCH, RunState.STATUS_POST_MATCH_REWARD],
	"resume": [PHASE_MENU],
	"suspend": [RunState.STATUS_HERO_SELECT, RunState.STATUS_PRE_MATCH, RunState.STATUS_POST_MATCH_REWARD],
	"return_to_menu": [RunState.STATUS_VICTORY, RunState.STATUS_DEFEAT, RunState.STATUS_ABANDONED],
}
## The stream that generates the boss sequence (F2); nothing else draws from it.
const STREAM_RUN: String = "run"
## Per-floor stream names.
const STREAM_MATCH: String = "match_%d"
const STREAM_AI: String = "ai_%d"
const STREAM_DRAFT: String = "draft_%d"
const MSEC_PER_SEC: int = 1000
## The two words of a 64-bit seed from the 32-bit `randi()`.
const SEED_WORD_BITS: int = 32

## The run, or null at `Menu` and in `hero_select`. Read-only to everyone else.
var state: RunState = null
## The run-scope log, or null when no run is active.
var run_log: EventLog = null
## The run's RNG service, or null when no run is active.
var rng: RngService = null
## The code of the last rejected [method begin_match]; `OK` after an accepted one.
var last_error: Error = OK
## The unlock keys `archive_run` granted the run that just ended (R6).
var unlocks_granted: Array = []
## A `Callable() -> int` of seconds since the epoch, for the record's times.
var unix_clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())
## A `Callable() -> int` of monotonic milliseconds, for `play_seconds` and `duration_s`.
var ticks_clock: Callable = Time.get_ticks_msec
## A `Callable() -> int` for the F1 empty-seed branch, called once per random run.
var entropy: Callable = _entropy

var _db: CardDatabase
var _meta: MetaApi
var _draft: RewardDraft
var _treasures: Treasures
var _config: Dictionary
var _driver_factory: Callable
## `menu` or `hero_select` while [member state] is null.
var _idle_phase: String = PHASE_MENU
## The pending offer; memory only, resume regenerates it (R5.3).
var _offer: Offer = null
var _driver: MatchDriver = null
var _match_log: EventLog = null
var _match_started_at: int = 0
## When the running `play_seconds` interval began; -1 outside a match or a draft.
var _clock_mark: int = -1
## Milliseconds of play not yet a whole second.
var _play_msec: int = 0


## ADR-0008 Decision 1. [param run_config] is the `config("run_structure")` body
## plus what the composition root computes: `max_match_events` (F7, the cap of every
## log here) and `engine_version`. [param driver_factory] is a
## `func(config: Dictionary) -> MatchDriver`, `Boot.driver_factory()` in the game.
func _init(db: CardDatabase, meta: MetaApi, draft: RewardDraft, treasures: Treasures, run_config: Dictionary, driver_factory: Callable) -> void:
	_db = db
	_meta = meta
	_draft = draft
	_treasures = treasures
	_config = run_config
	_driver_factory = driver_factory


## The Reward Draft this run asks, which `RunController` also takes (ADR-0011).
func draft() -> RewardDraft:
	return _draft


## Where the machine is: an R1 `status`, or [constant PHASE_MENU].
func phase() -> String:
	return state.status if state != null else _idle_phase


## T1: `Menu` to `hero_select`. Not one of the seven commands: no event, no save.
func open_new_run() -> Error:
	if phase() != PHASE_MENU:
		return RunCodes.E_BAD_PHASE
	_idle_phase = RunState.STATUS_HERO_SELECT
	return OK


## T2 and T18 (R2): starts a run with [param hero_id] from [param seed_input], where
## an empty input means a random seed. Rejected, with no event and no save, as
## `E_CONFIG` (a layout F1 and F2 cannot use), `E_UNKNOWN_ID` or `E_HERO_LOCKED`.
func new_run(hero_id: String, seed_input: String) -> Error:
	if not _is_legal("new_run"):
		return RunCodes.E_BAD_PHASE
	if not _layout_is_usable():
		return RunCodes.E_CONFIG
	var hero: Variant = _hero_def(hero_id)
	if hero == null:
		return RunCodes.E_UNKNOWN_ID
	if not _meta.is_hero_unlocked(hero_id):
		return RunCodes.E_HERO_LOCKED
	var warnings: Array[Dictionary] = []
	var run_seed: int = _resolve_seed(seed_input, warnings)
	var run_state: RunState = _fresh_state(hero, run_seed, seed_input)
	_clear_run()
	state = run_state
	rng = _make_rng(run_seed, state.data_version)
	_open_log(EventLog.new(_max_events(), EventLog.SCOPE_RUN, _log_meta()))
	rng.begin_command()
	state.boss_sequence = _generate_boss_sequence(warnings)
	rng.end_command()
	state.treasure_state = {"schema_version": Treasures.SCHEMA_VERSION, "by_treasure": {}}
	state.draft_state = _draft.init_run(state)
	_emit(RunCodes.EVENT_RUN_STARTED, {
		"run_seed_hex": state.run_seed_hex,
		"hero_id": hero_id,
		"data_version": state.data_version,
		"log_schema_version": EventLog.LOG_SCHEMA_VERSION,
		"boss_ids": Array(state.boss_sequence),
	})
	for warning: Dictionary in warnings:
		RunCodes.warn(run_log, str(warning.code), warning.detail)
	state.status = RunState.STATUS_PRE_MATCH
	_save()
	_enter_pre_match()
	return OK


## T5 (R3; ADR-0008 Decision 1): counts the attempt, builds `MatchConfig` with a
## fresh match log and hands it to the driver factory, `match_ended` connected first.
## Returns the driver, or null with the code in [member last_error].
func begin_match() -> MatchDriver:
	if not _is_legal("begin_match"):
		last_error = RunCodes.E_BAD_PHASE
		return null
	if not _driver_factory.is_valid():
		last_error = RunCodes.E_CONFIG
		return null
	last_error = OK
	state.match_attempts[str(state.floor)] = state.attempts_on(state.floor) + 1
	_rewind_match_streams()
	state.status = RunState.STATUS_IN_MATCH
	_match_log = EventLog.new(_max_events(), EventLog.SCOPE_MATCH, _log_meta(state.floor))
	var config: Dictionary = _build_match_config()
	_match_started_at = ticks_clock.call()
	_start_clock()
	_driver = _driver_factory.call(config)
	_driver.match_ended.connect(_on_match_ended)
	return _driver


## T11, T12 (R5.3-5): takes one option of the pending offer. In order of the checks:
## `E_BAD_PHASE`, `E_DRAFT_DONE` for a `(floor, kind)` already recorded (a replayed
## pick, R8.5), `E_DRAFT_KIND`, `E_NOT_OFFERED`. A null [param id] is "take nothing",
## which Reward Draft refuses unless `allow_skip` is on.
func draft_pick(kind: StringName, id: Variant) -> Error:
	if not _is_legal("draft_pick"):
		return RunCodes.E_BAD_PHASE
	var step: String = String(kind)
	if not DraftRecord.KINDS.has(step):
		return RunCodes.E_DRAFT_KIND
	if state.has_draft(state.floor, step):
		return RunCodes.E_DRAFT_DONE
	if step != state.reward_step:
		return RunCodes.E_DRAFT_KIND
	if id != null and not _offer.option_ids.has(str(id)):
		return RunCodes.E_NOT_OFFERED
	var pick: Pick = _draft.pick(kind, id, _offer, state)
	if pick.error == RunCodes.E_UNKNOWN_ID:
		_enter_reward_step()
	if pick.error != OK:
		return pick.error
	var offered: Array = Array(_offer.option_ids)
	_offer = null
	state.drafts.append(DraftRecord.make(state.floor, step, offered, pick.picked_id, pick.card_ids_added))
	if step == DraftRecord.KIND_TREASURE:
		if pick.picked_id != null:
			state.treasures.append(str(pick.picked_id))
			_emit(RunCodes.EVENT_TREASURE_GRANTED, {"floor": state.floor, "treasure_id": pick.picked_id})
		state.reward_step = DraftRecord.KIND_BUNDLE
		_save()
		_enter_reward_step()
		return OK
	if pick.picked_id != null:
		state.deck.append_array(pick.card_ids_added)
		_emit(RunCodes.EVENT_DECK_GREW, {"floor": state.floor, "card_ids_added": Array(pick.card_ids_added), "deck_size": state.deck.size()})
	_next_floor()
	return OK


## T13 (R6): the player ends the run, which counts as a loss. A floor won and not yet
## drafted is credited: `floors_cleared` is the floor itself from `post_match_reward`.
func abandon() -> Error:
	if not _is_legal("abandon"):
		return RunCodes.E_BAD_PHASE
	var cleared: int = state.floor if state.status == RunState.STATUS_POST_MATCH_REWARD else state.floor - 1
	_end_run(RunState.STATUS_ABANDONED, cleared, cleared + 1, null, RunState.REASON_PLAYER)
	return OK


## T15, T16 (R8): continues the saved run.
func resume() -> Error:
	if not _is_legal("resume"):
		return RunCodes.E_BAD_PHASE
	return RunCodes.E_NO_SAVE


## T3, T21 (R8.7): "Quit to menu". Drops the run with no event and no save; the last
## S-save stays what Continue resumes.
func suspend() -> Error:
	if not _is_legal("suspend"):
		return RunCodes.E_BAD_PHASE
	_clear_run()
	return OK


## T17: from a finished run back to `Menu`.
func return_to_menu() -> Error:
	if not _is_legal("return_to_menu"):
		return RunCodes.E_BAD_PHASE
	_clear_run()
	return OK


## The pending offer's read model (ADR-0011), or null when none is pending.
func current_offer() -> Variant:
	if _offer == null:
		return null
	return _offer.read_model(state.deck.size(), RecordSchemas.BUNDLE_FIELDS.cards["count"], _draft.allows_skip())


## What Run UI renders, for every phase (ADR-0011; run-structure UI Requirements):
## always `phase`, `status`, `allow_custom_seed`, `summary_top_cards` and `offer`.
## At `Menu` and in `hero_select`: `heroes` (the roster with `unlocked`) and
## `saved_run` (the Continue card, or null). With a run: [method RunState.read_model],
## and in a terminal phase `unlocks_granted`.
func read_model() -> Dictionary:
	var model: Dictionary = {}
	if state != null:
		model = state.read_model(_db, _config)
		model["unlocks_granted"] = unlocks_granted.duplicate()
	else:
		model["heroes"] = _roster()
		model["saved_run"] = _continue_card()
	model["phase"] = phase()
	model["status"] = phase()
	model["offer"] = current_offer()
	model["allow_custom_seed"] = bool(_config.allow_custom_seed)
	model["summary_top_cards"] = int(_config.summary_top_cards)
	return model


## The 16-digit hex a typed seed resolves to, for the field's echo (UI Requirements);
## `""` for an empty input, which is a random seed.
static func seed_preview(seed_input: String) -> String:
	if seed_input.strip_edges().is_empty():
		return ""
	return RngService.to_hex_u64(RngService.run_seed_from_input(seed_input, Callable()))


## Builds the run's RNG service. The one construction seam: a test double overrides it
## to record the draws.
func _make_rng(run_seed: int, data_version: String) -> RngService:
	return RngService.new(run_seed, data_version)


## T6-T9 (R4; ADR-0008 Decision 8), connected first by [method begin_match].
func _on_match_ended(result: Dictionary) -> void:
	if state == null or state.status != RunState.STATUS_IN_MATCH:
		return
	_stop_clock()
	var driver: MatchDriver = _driver
	var attempt: int = state.attempts_on(state.floor)
	if str(result.get("result")) == MatchRecords.RESULT_FAULT:
		_driver = null
		_match_log = null
		_emit(RunCodes.EVENT_MATCH_FAULTED, {"floor": state.floor, "attempt": attempt})
		state.status = RunState.STATUS_PRE_MATCH
		_save()
		_enter_pre_match()
		return
	_store_summary(result, attempt)
	state.treasure_state = _treasures.collect_state(driver.hooks(), result)
	_driver = null
	_match_log = null
	if result.get("winner") != MatchRecords.SIDE_PLAYER:
		_end_run(RunState.STATUS_DEFEAT, state.floor - 1, state.floor, state.boss_sequence[state.floor - 1], null)
	elif state.floor == state.floors_per_run:
		_end_run(RunState.STATUS_VICTORY, state.floors_per_run, state.floors_per_run, null, null)
	else:
		state.status = RunState.STATUS_POST_MATCH_REWARD
		state.reward_step = DraftRecord.KIND_TREASURE if state.is_treasure_floor(state.floor) else DraftRecord.KIND_BUNDLE
		_save()
		_start_clock()
		_enter_reward_step()


## R4, R10: the log's reduction, with the run's fields on top. A match the log could
## not reduce still gets a row, from the `MatchResult`.
func _store_summary(result: Dictionary, attempt: int) -> void:
	var summary: Dictionary = {
		"floor": state.floor,
		"result": result.get("result"),
		"reason": result.get("reason"),
		"turns": int(result.get("turns", 0)),
		"cards_played": 0,
		"damage_by_card": {},
	}
	summary.merge(_match_log.reduce_to_summary(), true)
	summary["boss_id"] = state.boss_sequence[state.floor - 1]
	summary["band"] = state.band(state.floor)
	summary["attempt"] = attempt
	@warning_ignore("integer_division")
	summary["duration_s"] = (int(ticks_clock.call()) - _match_started_at) / MSEC_PER_SEC
	var stored: Dictionary = RunRecord.normalised(summary)
	state.match_summaries.append(stored)
	_emit(RunCodes.EVENT_MATCH_SUMMARY, stored)
	if str(result.get("reason")) == MatchRecords.REASON_TURN_CAP:
		RunCodes.warn(run_log, RunCodes.W_TURN_CAP, {"floor": state.floor})


## R6: every way a run ends. The status is final first, so the record says so;
## `run_ended` seals the log; then the archive and the empty slot (S5).
func _end_run(outcome: String, floors_cleared: int, floor_reached: int, ended_by: Variant, abandon_reason: Variant) -> void:
	_stop_clock()
	_offer = null
	state.status = outcome
	state.reward_step = null
	state.totals = state.compute_totals()
	var total_turns: int = state.totals.turns
	state.result = {
		"outcome": outcome,
		"floors_cleared": floors_cleared,
		"floor_reached": floor_reached,
		"total_turns": total_turns,
		"ended_by": ended_by,
		"abandon_reason": abandon_reason,
	}
	state.ended_at = int(unix_clock.call())
	state.updated_at = state.ended_at
	_emit(RunCodes.EVENT_RUN_ENDED, {
		"result": outcome,
		"abandon_reason": abandon_reason,
		"floors_cleared": floors_cleared,
		"total_turns": total_turns,
		"run_seed_hex": state.run_seed_hex,
	})
	_capture_streams_and_log()
	var archived: Dictionary = _meta.archive_run(_record_to_store())
	if not bool(archived.get("ok", false)):
		push_warning("RunMachine: archive_run refused run %s" % state.run_id)
	unlocks_granted = Array(archived.get("unlocks_granted", [])).duplicate()
	_meta.clear_active_run()


## T4: entering `pre_match` says so; Run UI shows the boss intro on it (R3.1).
func _enter_pre_match() -> void:
	_emit(RunCodes.EVENT_FLOOR_ENTERED, {
		"floor": state.floor,
		"band": state.band(state.floor),
		"boss_id": state.boss_sequence[state.floor - 1],
	})


## R5.3, T19, T20: asks Reward Draft for the pending step, always after the save that
## precedes it, so the saved stream position regenerates the offer. An empty offer
## records the skip and moves on, which may land on the next step's empty offer.
func _enter_reward_step() -> void:
	while state.status == RunState.STATUS_POST_MATCH_REWARD:
		var step: String = str(state.reward_step)
		rng.begin_command()
		var offer: Offer = _draft.offer(StringName(step), state, rng.stream(STREAM_DRAFT % state.floor))
		rng.end_command()
		if not offer.option_ids.is_empty():
			_offer = offer
			return
		_offer = null
		state.drafts.append(DraftRecord.skipped(state.floor, step))
		if step == DraftRecord.KIND_BUNDLE:
			_next_floor()
			return
		state.reward_step = DraftRecord.KIND_BUNDLE
		_save()


## The end of T12 and T20: on to the next floor, saved (S4).
func _next_floor() -> void:
	_stop_clock()
	state.reward_step = null
	state.floor += 1
	state.status = RunState.STATUS_PRE_MATCH
	_save()
	_enter_pre_match()


## R3.2 `MatchConfig`: the treasures in pick order, the boss at its F3 health.
func _build_match_config() -> Dictionary:
	var boss_id: String = state.boss_sequence[state.floor - 1]
	var boss_def: Dictionary = _db.boss(boss_id)
	for warning: Dictionary in Treasures.installer_warnings(state.treasures, state.treasure_state):
		var detail: Dictionary = warning.duplicate()
		detail.erase("code")
		RunCodes.warn(run_log, str(warning.code), detail)
	return {
		"floor": state.floor,
		"band": state.band(state.floor),
		"rng_match": rng.stream(STREAM_MATCH % state.floor),
		"rng_ai": rng.stream(STREAM_AI % state.floor),
		"log": _match_log,
		"player": {
			"hero_def_id": state.hero_id,
			"deck": Array(state.deck),
			"hook_installers": _treasures.installers_for(state.treasures, state.treasure_state),
		},
		"boss": {
			"boss_def_id": boss_id,
			"deck": Array(boss_def.deck).duplicate(),
			"health": RunState.boss_health_at(boss_def, state.floor, state.band_split, int(_config.floor_health_bonus)),
			"hook_installers": Treasures.passive_installer(boss_def),
			"ai_id": boss_def.ai_profile,
		},
	}


## R8.3, ADR-0008 Decision 9: a retry of a floor plays the same streams from
## `draws = 0`. Dropping them from a snapshot and restoring it is the service's own
## way to rewind; the next `stream()` makes them anew.
func _rewind_match_streams() -> void:
	var names: Array[String] = [STREAM_MATCH % state.floor, STREAM_AI % state.floor]
	if not rng.has_stream(names[0]) and not rng.has_stream(names[1]):
		return
	var snap: Dictionary = rng.snapshot()
	for table: Dictionary in [snap.streams, snap.fork_points]:
		for key: String in table.keys():
			if names.has(key) or key.begins_with(names[0] + "/") or key.begins_with(names[1] + "/"):
				table.erase(key)
	var rewound: Error = rng.restore(snap)
	assert(rewound == OK, "RunMachine: a snapshot of this service was refused")


## F2: one shuffle per band on `run`, in band order, the band wrapped only if short,
## then the draw-free adjacency pass.
func _generate_boss_sequence(warnings: Array[Dictionary]) -> Array[String]:
	var stream: RngStream = rng.stream(STREAM_RUN)
	var sequence: Array[String] = []
	for index: int in range(state.band_split.size()):
		var band: int = index + 1
		var needed: int = state.band_split[index]
		var pool: Array = []
		for boss: Dictionary in _db.bosses_in_band(band):
			pool.append(boss.id)
		stream.shuffle(pool)
		for i: int in range(needed):
			sequence.append(str(pool[i % pool.size()]))
		if pool.size() < needed:
			warnings.append({"code": RunCodes.W_BOSS_POOL_SHORT, "detail": {"band": band, "needed": needed, "available": pool.size()}})
	if bool(_config.no_adjacent_shared_theme):
		_adjacency_pass(sequence, warnings)
	return sequence


## F2 `adjacency_pass`: a boss sharing a tag with the one before swaps with the first
## later boss of its band that does not. Draws nothing.
func _adjacency_pass(sequence: Array[String], warnings: Array[Dictionary]) -> void:
	for i: int in range(1, sequence.size()):
		if not _share_tags(sequence[i], sequence[i - 1]):
			continue
		var swapped: bool = false
		for j: int in range(i + 1, sequence.size()):
			if state.band(j + 1) == state.band(i + 1) and not _share_tags(sequence[j], sequence[i - 1]):
				var held: String = sequence[i]
				sequence[i] = sequence[j]
				sequence[j] = held
				swapped = true
				break
		if not swapped:
			warnings.append({"code": RunCodes.W_THEME_ADJACENT, "detail": {"floor": i + 1}})


func _share_tags(boss_a: String, boss_b: String) -> bool:
	var tags: Array = _db.boss(boss_b).get("tags", [])
	for tag: Variant in _db.boss(boss_a).get("tags", []):
		if tags.has(tag):
			return true
	return false


## Edge Cases "Configuration and content": F1 needs three positive bands summing to
## `floors_per_run`, and F2 needs a boss in each.
func _layout_is_usable() -> bool:
	var split: Array = _config.band_split
	var floors: int = int(_config.floors_per_run)
	if floors < 1 or split.size() != RunRecord.BAND_COUNT:
		return false
	var total: int = 0
	for index: int in range(split.size()):
		if int(split[index]) < 1 or _db.bosses_in_band(index + 1).is_empty():
			return false
		total += int(split[index])
	return total == floors


## The HeroDef [param hero_id], or null: `CardDatabase.hero` asserts on other ids.
func _hero_def(hero_id: String) -> Variant:
	for hero: Dictionary in _db.heroes():
		if hero.id == hero_id:
			return hero
	return null


## R2 step 2, R9: a typed seed, unless `allow_custom_seed` is off (Edge Cases), when
## it is ignored with a warning. The one entropy call is behind [member entropy].
func _resolve_seed(seed_input: String, warnings: Array[Dictionary]) -> int:
	if bool(_config.allow_custom_seed):
		return RngService.run_seed_from_input(seed_input, entropy)
	if not seed_input.strip_edges().is_empty():
		warnings.append({"code": RunCodes.W_SEED_IGNORED, "detail": {}})
	return RngService.run_seed_from_input("", entropy)


## R2 steps 2 and 5 up to the fields that need the RNG service: the layout is copied
## from config, so a saved run keeps what it started with.
func _fresh_state(hero: Dictionary, run_seed: int, seed_input: String) -> RunState:
	var run_state: RunState = RunState.new()
	var custom: bool = bool(_config.allow_custom_seed) and not seed_input.strip_edges().is_empty()
	run_state.data_version = _db.data_version()
	run_state.engine_version = str(_config.get("engine_version", ""))
	run_state.run_seed = run_seed
	run_state.run_seed_hex = RngService.to_hex_u64(run_seed)
	run_state.seed_source = RunState.SEED_CUSTOM if custom else RunState.SEED_RANDOM
	run_state.hero_id = hero.id
	run_state.floors_per_run = int(_config.floors_per_run)
	for s: Variant in _config.band_split:
		run_state.band_split.append(int(s))
	for f: Variant in _config.treasure_floors:
		run_state.treasure_floors.append(int(f))
	run_state.deck.assign(hero.starter_deck)
	run_state.started_at = int(unix_clock.call())
	run_state.updated_at = run_state.started_at
	run_state.run_id = "%s-%d" % [run_state.run_seed_hex, run_state.started_at]
	return run_state


## R7: writes the record at a save point. A refusal warns and the run goes on.
func _save() -> void:
	_fold_play_time()
	state.updated_at = int(unix_clock.call())
	_capture_streams_and_log()
	var saved: Error = _meta.save_active_run(_record_to_store())
	if saved == OK:
		_emit(RunCodes.EVENT_RUN_SAVED, {"floor": state.floor, "phase": state.status})
	else:
		RunCodes.warn(run_log, RunCodes.W_SAVE_FAILED, {"floor": state.floor, "code": String(RunCodes.code_name(saved))})


## The record as Meta receives it.
func _record_to_store() -> Dictionary:
	return RunRecord.to_dict(state)


## Refreshes the two fields a save carries from their owners (R1). The log's text is
## parsed so the record stays one JSON tree.
func _capture_streams_and_log() -> void:
	if rng != null:
		state.rng_snapshot = RunRecord.normalised(rng.snapshot_to_json_dict())
	if run_log != null:
		state.run_log = RunRecord.normalised(JSON.parse_string(run_log.to_json()))


func _open_log(log: EventLog) -> void:
	run_log = log
	_draft.set_run_log(log)
	run_log_opened.emit(log)


## The `meta` of a log of this run; a match log adds its [param floor_number].
func _log_meta(floor_number: int = 0) -> Dictionary:
	var meta: Dictionary = {
		"engine_version": state.engine_version,
		"data_version": state.data_version,
		"run_seed_hex": state.run_seed_hex,
	}
	if floor_number > 0:
		meta["floor"] = floor_number
	return meta


func _max_events() -> int:
	return int(_config.max_match_events)


func _emit(type: StringName, payload: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	run_log.append(type, payload)


func _is_legal(trigger: String) -> bool:
	return (LEGAL_PHASES[trigger] as Array).has(phase())


## Back to `Menu`, keeping nothing of the run.
func _clear_run() -> void:
	state = null
	rng = null
	run_log = null
	_draft.set_run_log(null)
	_offer = null
	_driver = null
	_match_log = null
	_clock_mark = -1
	_play_msec = 0
	unlocks_granted = []
	_idle_phase = PHASE_MENU


## `play_seconds` counts only a match or a draft (R1), from monotonic ticks.
func _start_clock() -> void:
	_clock_mark = ticks_clock.call()


func _stop_clock() -> void:
	_fold_play_time()
	_clock_mark = -1


func _fold_play_time() -> void:
	if _clock_mark < 0:
		return
	var now: int = ticks_clock.call()
	_play_msec += now - _clock_mark
	_clock_mark = now
	@warning_ignore("integer_division")
	state.play_seconds += _play_msec / MSEC_PER_SEC
	_play_msec %= MSEC_PER_SEC


## The heroes the roster shows, locked ones included (UI Requirements).
func _roster() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for hero: Dictionary in _db.heroes():
		rows.append({
			"id": hero.id,
			"name": hero.name,
			"set": hero["set"],
			"health": hero.health,
			"hero_power": hero.hero_power,
			"starter_deck": Array(hero.starter_deck).duplicate(),
			"unlocked": _meta.is_hero_unlocked(hero.id),
		})
	return rows


## The Continue card (UI Requirements): hero, "floor n of F", phase, last played.
func _continue_card() -> Variant:
	var raw: Variant = _meta.load_active_run()
	if not raw is Dictionary:
		return null
	var saved: Dictionary = RunRecord.normalised(raw)
	return {
		"hero_id": saved.get("hero_id"),
		"floor": saved.get("floor"),
		"floors_per_run": saved.get("floors_per_run"),
		"phase": saved.get("status"),
		"updated_at": saved.get("updated_at"),
	}


## F1's empty-seed entropy (ADR-0003 Decision 10(b)): the one permitted global RNG
## call, allow-listed for this file by `tools/lint/no_global_rng.sh`.
static func _entropy() -> int:
	return (randi() << SEED_WORD_BITS) | randi()
