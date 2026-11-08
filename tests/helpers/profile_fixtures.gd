## Shared fixtures of the Meta Progression suites (design/gdd/meta-progression.md,
## Acceptance Criteria preamble: "an injected `user://`-equivalent temp directory
## and synthetic `RunRecord` fixtures"; ADR-0004 Verification).
##
## A store never reaches the real `user://profile.json`: every factory takes a
## scratch [param root] from [method new_root], and the suite gives it back with
## [method remove_root]. Clocks are [ManualClock], so nothing reads the wall clock.
## The knob and setting values are the GDD's defaults; a test states the knob it
## changes, and `io_retry_ms` is [constant FAST_RETRY_MS] so a failing write does not
## stall the suite.
##
## [codeblock]
## var root: String = ProfileFixtures.new_root()
## var clock := ProfileFixtures.ManualClock.new()
## var store: ProfileStore = ProfileFixtures.store(root, clock)
## store.load_profile()
## store.archive_run(ProfileFixtures.victory("run_a"))
## ProfileFixtures.remove_root(root)
## [/codeblock]
class_name ProfileFixtures
extends RefCounted

## The unix second every [ManualClock] starts on.
const START_TIME: int = 1800000000
const FAST_RETRY_MS: int = 1
const RESET_TOKEN: String = "RESET"

const HERO_WAR: String = "hero_war"
const HERO_DECAY: String = "hero_decay"
const HERO_KNOWLEDGE: String = "hero_knowledge"
const LAUNCH_HEROES: Array[String] = [HERO_WAR, HERO_DECAY, HERO_KNOWLEDGE]
const FORTUNE_KEY: String = "unlock.hero_fortune"
const ORDER_KEY: String = "unlock.hero_order"
const SHADOW_KEY: String = "unlock.hero_shadow"
const DECAY_WIN_KEY: String = "hero_decay_first_win"
const DECAY_FLOOR_KEY: String = "hero_decay_floor_5"
const KNOWLEDGE_WIN_KEY: String = "hero_knowledge_first_win"
const FIRST_VICTORY_KEY: String = "first_victory"
const BOSSES_KEY: String = "bosses_defeated_16"
const BOSSES_N: int = 16
## M10 reserves [constant BOSSES_KEY] with no treasure yet; AC-20 and AC-24 still
## exercise it, so this test-only record carries it.
const RESERVED_TREASURE: String = "treasure_reserved_test"
const TITHE: String = "treasure_grave_tithe"
const BELL: String = "treasure_plague_bell"
const GRIMOIRE: String = "treasure_dogeared_grimoire"
const ARMORY: String = "treasure_living_armory"
const OPEN_TREASURE: String = "treasure_worn_signet"
const BOSS_A: String = "boss_alpha"
const BOSS_B: String = "boss_beta"
const DATA_VERSION: String = "1.0"
const FLOORS_PER_RUN: int = 8
const DECK_SIZE: int = 36

static var _roots_made: int = 0


## A clock tests move by hand; `clock.read` is what a store or lock takes.
class ManualClock:
	extends RefCounted

	var now: int

	func _init(start: int = ProfileFixtures.START_TIME) -> void:
		now = start

	func read() -> int:
		return now

	func advance(seconds: int) -> void:
		now += seconds


## ADR-0004 Verification's fault-injecting writer: [method fail_at] makes a step of
## W2-W8 fail, for [param times] calls of that step or for good.
class FaultWriter:
	extends AtomicFileWriter

	var write_calls: int = 0
	var _failing: Dictionary = {}

	func fail_at(step: String, times: int = -1) -> void:
		_failing[step] = times

	func clear() -> void:
		_failing.clear()

	func write(final_path: String, text: String, backup_path: String = "") -> Error:
		write_calls += 1
		return super(final_path, text, backup_path)

	func _fails_at(step: String) -> bool:
		if not _failing.has(step) or _failing[step] == 0:
			return false
		if _failing[step] > 0:
			_failing[step] -= 1
		return true


## A `CardDatabase` answering from the records given, with no load: for the rules
## suites, which test what `UnlockEvaluator` does with definitions. Whether
## definitions pass a real load is `meta_unlock_stage7_test.gd`'s subject.
class UnlockDatabase:
	extends CardDatabase

	var version: String = ProfileFixtures.DATA_VERSION
	var _heroes: Array
	var _treasures: Array
	var _known_ids: Array

	func _init(heroes_in: Array, treasures_in: Array, extra_ids: Array = []) -> void:
		_heroes = heroes_in
		_treasures = treasures_in
		_known_ids = extra_ids.duplicate()
		for record: Dictionary in heroes_in + treasures_in:
			_known_ids.append(record.id)

	func heroes() -> Array:
		return _heroes

	func treasure_pool(collection_id: String = "") -> Array:
		return _treasures

	func bundle_pool(_hero_set: String, collection_id: String = "") -> Array:
		return []

	func data_version() -> String:
		return version

	func has(id: String) -> bool:
		return _known_ids.has(id)

	func config(config_name: String) -> Variant:
		return ProfileFixtures.defaults_body() if config_name == "profile_defaults" else {}


# --- Scratch directories and files ----------------------------------------------

## A new empty directory under `user://`, unique in this process.
static func new_root() -> String:
	_roots_made += 1
	var root: String = "user://meta_test_%d_%d" % [OS.get_process_id(), _roots_made]
	remove_root(root)
	DirAccess.make_dir_recursive_absolute(root)
	return root


## Deletes [param root], a directory made by [method new_root], and all it holds.
static func remove_root(root: String) -> void:
	if not DirAccess.dir_exists_absolute(root):
		return
	for sub: String in DirAccess.get_directories_at(root):
		remove_root(root.path_join(sub))
	for file: String in DirAccess.get_files_at(root):
		DirAccess.remove_absolute(root.path_join(file))
	DirAccess.remove_absolute(root)


static func write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	GameAssertions.fail_if(file == null, "could not write fixture %s" % path)
	file.store_string(text)
	file.close()


## The bytes of [param path]; empty when the file is absent.
static func read_bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()


## Every file directly in [param root] whose name starts with [param prefix].
static func files_with_prefix(root: String, prefix: String) -> Array:
	return Array(DirAccess.get_files_at(root)).filter(func(name: String) -> bool: return name.begins_with(prefix))


# --- Knobs, defaults, stores ----------------------------------------------------

## The Tuning Knobs table at its defaults, [param overrides] on top.
static func knobs(overrides: Dictionary = {}) -> Dictionary:
	var values: Dictionary = {
		"run_log_cap": 200,
		"archive_top_cards": 10,
		"max_profile_bytes": 2097152,
		"max_save_ms": 50,
		"backup_count": 1,
		"io_retry_ms": FAST_RETRY_MS,
		"settings_write_debounce_ms": 500,
		"lock_heartbeat_s": 30,
		"lock_stale_s": 90,
		"max_condition_depth": 3,
		"max_condition_n": 999,
		"max_condition_fan_out": 8,
		"max_floor_clamp": 12,
		"max_repairs_before_rebuild": 25,
		"max_count": 999999,
		"max_duration_s": 100000000,
		"reset_confirm_token": RESET_TOKEN,
	}
	values.merge(overrides, true)
	return values


## M9's defaults, without `bindings` (ADR-0004 addendum 1).
static func settings_defaults() -> Dictionary:
	return {
		"volume_master": 1.0,
		"volume_music": 0.8,
		"volume_sfx": 1.0,
		"fullscreen": false,
		"anim_speed": "normal",
		"reduce_motion": false,
		"text_scale": 1.0,
		"high_contrast_states": false,
		"telegraph_mode": "full",
		"action_delay_ms": 600,
		"gamma": 1.0,
		"keep_run_records": true,
		"language": "en",
	}


## A `config("profile_defaults")` body.
static func defaults_body(knob_overrides: Dictionary = {}) -> Dictionary:
	var body: Dictionary = settings_defaults()
	body[ProfileStore.KNOBS_KEY] = knobs(knob_overrides)
	return body


## A store over [param root] whose lock file is in [param root] too.
static func store(root: String, clock: ManualClock, knob_overrides: Dictionary = {},
		writer: AtomicFileWriter = null, migrations: ProfileMigrations = null) -> ProfileStore:
	var merged: Dictionary = knobs(knob_overrides)
	var lock: ProfileLock = ProfileLock.new(root.path_join("profile.lock"), int(merged.lock_stale_s), clock.read)
	var used: AtomicFileWriter = writer if writer != null else AtomicFileWriter.new()
	return ProfileStore.new(settings_defaults(), merged, used, lock, clock.read, root, migrations)


## A `MetaFacade` over [param profile_store] and [param db].
static func facade(profile_store: ProfileStore, db: CardDatabase, knob_overrides: Dictionary = {},
		abandon_counts_as_loss: bool = true) -> MetaFacade:
	var evaluator: UnlockEvaluator = UnlockEvaluator.new(db, knobs(knob_overrides))
	return MetaFacade.new(profile_store, evaluator, StatsFold.new(abandon_counts_as_loss))


## A profile in the M1.2 shape, as a file would hold it.
static func profile_dict(overrides: Dictionary = {}) -> Dictionary:
	var profile: Dictionary = ProfileSchema.new_profile(ProfileStore.PROFILE_SCHEMA_VERSION, settings_defaults(), START_TIME)
	profile.merge(overrides, true)
	return profile


## Writes [param profile] as [param file_name] in [param root]; returns its text.
static func write_profile(root: String, profile: Dictionary, file_name: String = "profile.json") -> String:
	var text: String = JSON.stringify(profile, "\t", false, true)
	write_text(root.path_join(file_name), text)
	return text


## A `profile.lock` body held by another instance, its heartbeat [param age_s] old.
static func write_foreign_lock(root: String, clock: ManualClock, age_s: int, instance_id: String = "other_instance") -> void:
	write_text(root.path_join("profile.lock"), JSON.stringify({
		"instance_id": instance_id, "pid": 1, "heartbeat_at": clock.now - age_s}))


## The M4.4 worked example: v1 to v2 adds `stats.heroes[*].best_turns_victory`, the
## minimum `totals.turns` over that hero's random-seed victories in `run_log`.
static func worked_v1_to_v2(profile: Dictionary) -> Dictionary:
	var out: Dictionary = profile.duplicate(true)
	for hero_id: Variant in out.stats.heroes:
		var best: Variant = null
		for entry: Dictionary in out.run_log:
			var counts: bool = entry.hero_id == hero_id and entry.seed_source == "random" and entry.result.outcome == "victory"
			if counts:
				var turns: int = int(entry.totals.turns)
				best = turns if best == null else mini(int(best), turns)
		out.stats.heroes[hero_id]["best_turns_victory"] = best
	out["schema_version"] = 2
	return out


# --- Data definitions (M10) -----------------------------------------------------

static func runs_won(n: int, hero: String = "") -> Dictionary:
	var condition: Dictionary = {"type": "runs_won", "n": n}
	if not hero.is_empty():
		condition["hero"] = hero
	return condition


static func floor_reached(n: int, hero: String = "") -> Dictionary:
	var condition: Dictionary = {"type": "floor_reached", "n": n}
	if not hero.is_empty():
		condition["hero"] = hero
	return condition


static func boss_defeated(boss_id: String, n: int = 1) -> Dictionary:
	return {"type": "boss_defeated", "boss_id": boss_id, "n": n}


static func hero_record(id: String, key: String = "", condition: Dictionary = {}) -> Dictionary:
	return {"id": id, "set": id.trim_prefix("hero_"), "unlock": null if key.is_empty() else {"key": key, "condition": condition}}


static func treasure_record(id: String, key: String = "", condition: Dictionary = {}) -> Dictionary:
	return {"id": id, "unlock": null if key.is_empty() else {"key": key, "condition": condition}}


## The three launch heroes, then M10's three post-v1 heroes.
static func m10_heroes() -> Array:
	var shadow: Dictionary = {"type": "any_of", "of": [runs_won(1, HERO_DECAY), runs_won(1, HERO_KNOWLEDGE)]}
	return [
		hero_record(HERO_WAR), hero_record(HERO_DECAY), hero_record(HERO_KNOWLEDGE),
		hero_record("hero_fortune", FORTUNE_KEY, runs_won(1)),
		hero_record("hero_order", ORDER_KEY, runs_won(1, HERO_WAR)),
		hero_record("hero_shadow", SHADOW_KEY, shadow),
	]


## M10's table: four locked treasures, one open one, and the reserved key's carrier.
static func m10_treasures() -> Array:
	return [
		treasure_record(OPEN_TREASURE),
		treasure_record(TITHE, DECAY_WIN_KEY, runs_won(1, HERO_DECAY)),
		treasure_record(BELL, DECAY_FLOOR_KEY, floor_reached(5, HERO_DECAY)),
		treasure_record(GRIMOIRE, KNOWLEDGE_WIN_KEY, runs_won(1, HERO_KNOWLEDGE)),
		treasure_record(ARMORY, FIRST_VICTORY_KEY, runs_won(1)),
		treasure_record(RESERVED_TREASURE, BOSSES_KEY, boss_defeated("any", BOSSES_N)),
	]


static func m10_database() -> UnlockDatabase:
	return UnlockDatabase.new(m10_heroes(), m10_treasures(), [BOSS_A, BOSS_B])


## `stats` with [param overrides] over a zero record. `heroes` values are partial
## HeroStats; a missing field reads 0 (F1).
static func stats(overrides: Dictionary = {}) -> Dictionary:
	var values: Dictionary = ProfileSchema.empty_stats()
	values.merge(overrides, true)
	return values


## [param defeated] kills spread evenly over [param boss_count] ids.
static func bosses_map(defeated: int, boss_count: int) -> Dictionary:
	var map: Dictionary = {}
	for index: int in boss_count:
		@warning_ignore("integer_division")
		var kills: int = defeated / boss_count + (1 if index < defeated % boss_count else 0)
		map["boss_%02d" % index] = {"defeated": kills, "defeated_by": 0}
	return map


# --- Run records (R1, trimmed to what this system reads) ------------------------

## A random-seed War victory on [constant FLOORS_PER_RUN] floors, [param overrides]
## replacing whole top-level keys.
static func run_record(run_id: String, overrides: Dictionary = {}) -> Dictionary:
	var record: Dictionary = {
		"schema_version": 1,
		"data_version": DATA_VERSION,
		"run_id": run_id,
		"run_seed_hex": "00000000000000aa",
		"seed_source": "random",
		"hero_id": HERO_WAR,
		"floors_per_run": FLOORS_PER_RUN,
		"status": "victory",
		"boss_sequence": [],
		"deck": [],
		"treasures": [],
		"drafts": [],
		"match_attempts": {},
		"match_summaries": [],
		"started_at": START_TIME,
		"ended_at": START_TIME + 600,
		"play_seconds": 600,
		"result": {"outcome": "victory", "floors_cleared": FLOORS_PER_RUN, "floor_reached": FLOORS_PER_RUN,
			"ended_by": null, "abandon_reason": null},
		"totals": {"turns": 50, "damage_by_card": {}},
	}
	record.merge(overrides, true)
	return record


static func victory(run_id: String, hero_id: String = HERO_WAR, turns: int = 50, seconds: int = 600, seed_source: String = "random") -> Dictionary:
	return run_record(run_id, {"hero_id": hero_id, "seed_source": seed_source, "play_seconds": seconds,
		"totals": {"turns": turns, "damage_by_card": {}}})


static func defeat(run_id: String, hero_id: String, floor: int, boss_id: String, summaries: Array = []) -> Dictionary:
	return run_record(run_id, {"hero_id": hero_id, "status": "defeat", "match_summaries": summaries, "result": {"outcome": "defeat",
		"floors_cleared": floor - 1, "floor_reached": floor, "ended_by": boss_id, "abandon_reason": null}})


static func abandoned(run_id: String, hero_id: String, floor: int, reason: String) -> Dictionary:
	return run_record(run_id, {"hero_id": hero_id, "status": "abandoned", "result": {"outcome": "abandoned", "floors_cleared": floor - 1,
		"floor_reached": floor, "ended_by": null, "abandon_reason": reason}})


static func match_summary(boss_id: String, won: bool, damage: Dictionary = {}) -> Dictionary:
	return {"floor": 1, "result": "win" if won else "loss", "boss_id": boss_id, "turns": 8, "damage_by_card": damage}


## [param count] cards `card_00`, `card_01`… with descending damage, all distinct.
static func damage_map(count: int) -> Dictionary:
	var map: Dictionary = {}
	for index: int in count:
		map["card_%02d" % index] = (count - index) * 3
	return map


## AC-11's record: every heavy field present, [constant FLOORS_PER_RUN] summaries of
## [param damage_keys] `damage_by_card` entries, a [constant DECK_SIZE]-card deck.
static func full_record(run_id: String, damage_keys: int = 30) -> Dictionary:
	var summaries: Array = []
	var drafts: Array = []
	var deck: Array = []
	var bosses: Array = []
	for floor: int in FLOORS_PER_RUN:
		bosses.append("boss_%02d" % floor)
		var summary: Dictionary = match_summary(bosses[floor], true, damage_map(damage_keys))
		summary["floor"] = floor + 1
		summaries.append(summary)
	for index: int in 10:
		var kind: String = "treasure" if index % 3 == 0 else "bundle"
		drafts.append({"floor": index + 1, "kind": kind, "offered_ids": ["option_a_long_id", "option_b_long_id", "option_c_long_id"],
			"picked_id": "option_a_long_id", "card_ids_added": []})
	for index: int in DECK_SIZE:
		deck.append("neutral_card_with_a_long_id_%02d" % index)
	return run_record(run_id, {
		"boss_sequence": bosses,
		"deck": deck,
		"drafts": drafts,
		"match_summaries": summaries,
		"totals": {"turns": 90, "damage_by_card": damage_map(DECK_SIZE)},
		"run_log": {"events": ["a sealed log"]},
		"rng_snapshot": {"run_seed_hex": "00000000000000aa"},
		"draft_state": {"treasure_pool": ["treasure_a"]},
		"treasure_state": {"by_treasure": {}},
	})
