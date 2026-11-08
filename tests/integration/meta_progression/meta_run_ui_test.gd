## Integration: what the Run UI shows of the profile (design/gdd/meta-progression.md
## AC-28, AC-29, UI Requirements; run-ui U2, U5). The shipped data, a real `MetaFacade`
## over scratch files, the real `RunController`, `RunReadModels` and `ToastLayer`: the
## logic half of the two ACs. Their retained screenshots are in
## `production/qa/evidence/meta-progression-ac28-ac29/`.
extends GdUnitTestSuite

const BOOT_SCRIPT_PATH: String = "res://src/core/boot.gd"
const RUN_LOG_SCREEN: String = "res://src/ui/run/screens/run_log.gd"
const SEED_CUSTOM: String = "ABCDEF0123456789"
const SEED_RANDOM: String = "0123456789ABCDEF"
const SEED_RETRIED: String = "FEDCBA9876543210"
const FRAME_S: float = 0.016

var _db: CardDatabase
var _cfg: Dictionary
var _root: String
var _clock: ProfileFixtures.ManualClock
var _boot: Node
var _meta: MetaFacade
var _controller: RunController


func before() -> void:
	var boot: Node = auto_free(load(BOOT_SCRIPT_PATH).new())
	_db = CardDatabase.new()
	_db.load(boot._collect_validators(null))
	_cfg = _db.config("run_ui")
	RunText.install(_cfg)


func before_test() -> void:
	_root = ProfileFixtures.new_root()
	_clock = ProfileFixtures.ManualClock.new()
	_meta = ProfileFixtures.facade(ProfileFixtures.store(_root, _clock), _db)
	_boot = null


func after_test() -> void:
	ProfileFixtures.remove_root(_root)


## Builds the controller after the profile is on disk, as a launch does.
func _launch() -> void:
	_meta.load_profile()
	_boot = auto_free(load(BOOT_SCRIPT_PATH).new())
	_boot.boot({"card_database": _db, "meta": _meta})
	var run: RunMachine = _boot.run_machine()
	_controller = RunController.new(run, run.draft(), _meta, _db, _cfg)


func _boss_id(band: int) -> String:
	return _db.bosses_in_band(band)[0].id


func _card_id(index: int) -> String:
	return _db.cards_by_set("war")[index].id


func _deck(size: int) -> Array:
	var deck: Array = []
	for index: int in size:
		deck.append(_card_id(index % 4))
	return deck


## AC-28's three runs: one custom seed, one with `attempt > 1`, oldest first.
func _archive_three_runs() -> void:
	var damage: Dictionary = {_card_id(0): 40, _card_id(1): 25}
	var custom: Dictionary = ProfileFixtures.victory("run_1")
	custom.merge({"seed_source": "custom", "run_seed_hex": SEED_CUSTOM, "deck": _deck(36),
		"totals": {"turns": 50, "damage_by_card": damage}}, true)
	var plain: Dictionary = ProfileFixtures.defeat("run_2", ProfileFixtures.HERO_DECAY, 5, _boss_id(2))
	plain.merge({"run_seed_hex": SEED_RANDOM, "deck": _deck(27)}, true)
	var retried: Dictionary = ProfileFixtures.abandoned("run_3", ProfileFixtures.HERO_WAR, 3, "player")
	retried.merge({"run_seed_hex": SEED_RETRIED, "deck": _deck(21), "match_attempts": {"2": 2},
		"match_summaries": [{"floor": 2, "attempt": 2, "result": "win", "boss_id": _boss_id(1), "damage_by_card": {}}]}, true)
	_meta.load_profile()
	for record: Dictionary in [custom, plain, retried]:
		_meta.archive_run(record)


func _log_rows() -> Array:
	_controller._load_log_page(true)
	return _controller._log_model().rows


# --- AC-28 ---------------------------------------------------------------------

func test_run_log_ac28_rows_are_newest_first() -> void:
	# Arrange
	_archive_three_runs()
	_launch()

	# Act
	var rows: Array = _log_rows()

	# Assert
	assert_array(rows.map(func(row: Dictionary) -> String: return row.run_id)).is_equal(["run_3", "run_2", "run_1"])


func test_run_log_ac28_rows_show_hero_result_and_floors_n_of_f() -> void:
	# Arrange
	_archive_three_runs()
	_launch()

	# Act
	var rows: Array = _log_rows()

	# Assert
	var decay: Dictionary = rows[1]
	assert_str(decay.hero).is_equal((_db.hero(ProfileFixtures.HERO_DECAY) as Dictionary).name)
	assert_str(decay.result).contains("floor 5")
	assert_str(decay.floors).is_equal("4 of %d" % ProfileFixtures.FLOORS_PER_RUN)
	assert_str(rows[2].result).is_equal("Victory")
	assert_str(rows[2].floors).is_equal("%d of %d" % [ProfileFixtures.FLOORS_PER_RUN, ProfileFixtures.FLOORS_PER_RUN])


func test_run_log_ac28_rows_show_deck_size_and_top_damage_cards() -> void:
	# Arrange
	_archive_three_runs()
	_launch()

	# Act
	var victory: Dictionary = _log_rows()[2]

	# Assert
	assert_int(victory.deck_size).is_equal(36)
	var first_name: String = (_db.any_record(_card_id(0)) as Dictionary).name
	assert_str(victory.top_cards).starts_with(first_name)


func test_run_log_ac28_custom_seed_tag_marks_only_the_custom_run() -> void:
	# Arrange
	_archive_three_runs()
	_launch()

	# Act
	var rows: Array = _log_rows()

	# Assert
	assert_array(rows.map(func(row: Dictionary) -> bool: return row.custom_seed)).is_equal([false, false, true])


func test_run_log_ac28_attempt_marker_marks_only_the_replayed_run() -> void:
	# Arrange
	_archive_three_runs()
	_launch()

	# Act
	var rows: Array = _log_rows()

	# Assert
	assert_array(rows.map(func(row: Dictionary) -> bool: return row.retried)).is_equal([true, false, false])


func test_run_log_ac28_copy_control_carries_the_rows_seed_which_reparses() -> void:
	# Arrange: headless has no clipboard, so the control's bound seed is what is read
	_archive_three_runs()
	_launch()
	var model: Dictionary = _controller._models.run_log(_meta.run_log(0, 3), 3)
	var screen: Control = auto_free(load(RUN_LOG_SCREEN).new())
	screen.cfg = _cfg
	add_child(screen)
	screen.bind(model)

	# Act
	var copy_label: String = tr("summary.copy")
	var seeds: Array = []
	for button: Button in screen.find_children("*", "Button", true, false):
		if button.text == copy_label:
			seeds.append(button.pressed.get_connections()[0].callable.get_bound_arguments()[0])

	# Assert
	assert_array(seeds).contains_exactly_in_any_order([SEED_CUSTOM, SEED_RANDOM, SEED_RETRIED])
	for seed_hex: String in seeds:
		assert_bool(RunRecord.is_seed_hex(seed_hex)).is_true()
		assert_str(RngService.to_hex_u64(RngService.parse_hex_u64(seed_hex))).is_equal(seed_hex)


func test_run_log_opaque_schema_row_says_details_unavailable() -> void:
	# Arrange (UI Requirements; M4.4)
	var newer: Dictionary = ProfileFixtures.victory("run_1")
	newer["schema_version"] = ProfileMigrations.RUN_RECORD_SCHEMA_VERSION + 1
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"run_log": [newer]}))
	_launch()

	# Act
	var row: Dictionary = _log_rows()[0]

	# Assert
	assert_bool(row.details).is_false()
	assert_str(row.result).is_equal(RunText.t("log.details_unavailable"))


func test_run_log_pages_from_the_newest_end() -> void:
	# Arrange: one more run than a page
	var page: int = int(_cfg.run_log_page)
	var log: Array = []
	for index: int in page + 1:
		log.append(ProfileFixtures.victory("run_%03d" % index))
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"run_log": log}))
	_launch()

	# Act
	var first_page: Dictionary = {}
	_controller._load_log_page(true)
	first_page = _controller._log_model()
	_controller._load_log_page(false)
	var both: Dictionary = _controller._log_model()

	# Assert
	assert_int(first_page.rows.size()).is_equal(page)
	assert_str(first_page.rows[0].run_id).is_equal("run_%03d" % page)
	assert_bool(first_page.more).is_true()
	assert_int(both.rows.size()).is_equal(page + 1)
	assert_str(both.rows[page].run_id).is_equal("run_000")
	assert_bool(both.more).is_false()


# --- AC-29 ---------------------------------------------------------------------

func _queue_treasure_key() -> void:
	ProfileFixtures.write_profile(_root, ProfileFixtures.profile_dict({"pending_notifications": [
		{"key": ProfileFixtures.FIRST_VICTORY_KEY, "kind": "treasure", "id": ProfileFixtures.ARMORY, "by_run_id": "run_1"}]}))


## A toast layer wired as `RunShell` wires it, idle.
func _toast_layer() -> ToastLayer:
	var layer: ToastLayer = auto_free(ToastLayer.new())
	layer.configure(_cfg)
	add_child(layer)
	_controller.toast.connect(layer.enqueue)
	layer.shown.connect(_controller.on_toast_shown)
	layer.set_idle(true)
	return layer


func test_toast_ac29_names_the_treasure_and_its_condition() -> void:
	# Arrange
	_queue_treasure_key()
	_launch()
	var toasts: Array = []
	_controller.toast.connect(func(kind: StringName, payload: Dictionary) -> void:
		if kind == &"unlock":
			toasts.append(payload))

	# Act
	_controller._enqueue_pending_notifications()

	# Assert
	var name: String = (_db.treasure(ProfileFixtures.ARMORY) as Dictionary).name
	assert_int(toasts.size()).is_equal(1)
	assert_str(toasts[0].title).is_equal("New treasure unlocked: %s" % name)
	assert_str(toasts[0].subtitle).is_equal(RunText.t("unlock.condition.runs_won", {"n": 1}))


func test_toast_ac29_queue_is_empty_once_shown_and_after_a_restart() -> void:
	# Arrange
	_queue_treasure_key()
	_launch()
	var layer: ToastLayer = _toast_layer()
	_controller._enqueue_pending_notifications()

	# Act
	layer._process(FRAME_S)

	# Assert
	assert_bool(layer.is_showing()).is_true()
	assert_array(_meta.pending_notifications()).is_empty()
	_meta.store().release_lock()
	var next: ProfileStore = ProfileFixtures.store(_root, _clock)
	next.load_profile()
	assert_array(next.pending_notifications()).is_empty()


func test_toast_ac29_a_toast_never_shown_keeps_its_entry() -> void:
	# Arrange
	_queue_treasure_key()
	_launch()
	var layer: ToastLayer = _toast_layer()
	layer.set_idle(false)
	_controller._enqueue_pending_notifications()

	# Act
	layer._process(FRAME_S)

	# Assert: M3.6, acked per toast shown
	assert_int(_meta.pending_notifications().size()).is_equal(1)


func test_toast_a_key_from_the_signal_and_the_queue_shows_once() -> void:
	# Arrange: an archive both emits and queues
	_launch()
	var layer: ToastLayer = _toast_layer()

	# Act
	var archived: Dictionary = _meta.archive_run(ProfileFixtures.victory("run_1"))
	_controller._enqueue_pending_notifications()

	# Assert
	assert_array(layer.queued().map(func(row: Dictionary) -> String: return row.key)).contains_exactly_in_any_order(archived.unlocks_granted)
	assert_array(archived.unlocks_granted).contains([ProfileFixtures.FIRST_VICTORY_KEY])


func test_every_shipped_locked_treasure_has_condition_text() -> void:
	# Arrange
	_launch()

	for treasure: Dictionary in _db.treasure_pool():
		if treasure.unlock == null:
			continue

		# Act
		var toast: Dictionary = _controller._models.unlock_toast(treasure.unlock.key, "treasure", treasure.id)

		# Assert: a raw key on screen would be a missing string
		assert_str(toast.subtitle).override_failure_message(treasure.id).is_not_empty()
		assert_bool(String(toast.subtitle).begins_with(UnlockEvaluator.TEXT_KEY_PREFIX)).override_failure_message(treasure.id).is_false()
		assert_bool(String(toast.title).contains(str(treasure.name))).override_failure_message(treasure.id).is_true()


func test_retro_grant_toast_opens_on_the_main_menu() -> void:
	# Arrange (M3.6: the main menu for retro-grants)
	_queue_treasure_key()
	_launch()
	var toasts: Array = []
	_controller.toast.connect(func(kind: StringName, _payload: Dictionary) -> void: toasts.append(kind))

	# Act
	_controller.start()

	# Assert
	assert_array(toasts).is_equal([&"unlock"])
