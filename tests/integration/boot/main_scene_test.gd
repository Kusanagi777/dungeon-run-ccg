## Integration: `main.tscn`'s composition seam and the `RunShell` stub
## (boot-composition-root story 006; ADR-0001 Decision 4, ADR-0011 Decision 1,
## architecture.md §Data Flow 5 steps 1 and 5).
##
## No test here instantiates `main.tscn`: its `_ready()` boots the shared
## `Boot` autoload, and `boot_composition_test.gd` relies on no suite booting
## it. The seam is tested piecewise instead: `Main.boot_overrides()` (the debug
## command-line override, a pure function) and `RunShell` bound by argument to
## a `Services` bag over a real `CardDatabase` loaded from a committed fixture
## root — `Ready` shows `main_menu`, `Failed` shows `data_error` with the
## report's CR-8 rows. Scenes are `auto_free`d.
extends GdUnitTestSuite

const RUN_SHELL_SCENE := preload("res://src/ui/run/run_shell.tscn")
const READY_FIXTURE: String = "res://tests/fixtures/data/minimal/"
const FAILED_FIXTURE: String = "res://tests/fixtures/data/parse_error/"
const BOOT_SCRIPT := preload("res://src/core/boot.gd")
## The shipped data set (content story 001), read-only.
const SHIPPED_ROOT: String = "res://assets/data/"


func _services(root: String) -> Services:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(root))
	db.load(ValidatorStubs.accept_all())
	var services: Services = Services.new()
	services.card_database = db
	return services


## A shell bound to [param services] before it enters the tree, as `main.gd` does.
func _shell(services: Services) -> RunShell:
	var shell: RunShell = auto_free(RUN_SHELL_SCENE.instantiate())
	shell.bind(services)
	add_child(shell)
	await get_tree().process_frame
	return shell


# --- Main.boot_overrides: the debug command-line seam ------------------------------

func test_boot_overrides_are_empty_without_arguments() -> void:
	# Act / Assert
	assert_dict(Main.boot_overrides([], true)).is_empty()


func test_boot_fail_fixture_argument_overrides_the_card_database_in_a_debug_build() -> void:
	# Act
	var overrides: Dictionary = Main.boot_overrides(["--boot-fail-fixture=parse_error"], true)

	# Assert — an unloaded database over the fixture root: Boot loads it with
	# its own validator map (one composition path)
	var db: CardDatabase = overrides.get("card_database")
	assert_object(db).is_not_null()
	assert_int(db.state()).is_equal(CardDatabase.State.UNLOADED)
	db.load(ValidatorStubs.accept_all())
	assert_int(db.state()).is_equal(CardDatabase.State.FAILED)


func test_boot_fail_fixture_argument_is_ignored_in_a_release_build() -> void:
	# Act / Assert
	assert_dict(Main.boot_overrides(["--boot-fail-fixture=parse_error"], false)).is_empty()


func test_boot_fail_fixture_name_outside_the_fixture_pattern_is_refused() -> void:
	# Act / Assert — no path escapes the fixture folder
	assert_dict(Main.boot_overrides(["--boot-fail-fixture=../../assets/data"], true)).is_empty()
	assert_dict(Main.boot_overrides(["--boot-fail-fixture="], true)).is_empty()


# --- RunShell: the two placeholder states ------------------------------------------------

func test_shell_over_a_ready_load_shows_main_menu() -> void:
	# Act
	var shell: RunShell = await _shell(_services(READY_FIXTURE))

	# Assert
	assert_str(String(shell.screen())).is_equal("main_menu")
	assert_bool((shell.get_node("%MainMenu") as Control).visible).is_true()
	assert_bool((shell.get_node("%DataError") as Control).visible).is_false()
	assert_str((shell.get_node("%TitleLabel") as Label).text).is_equal(tr(RunShell.TITLE_TEXT))
	assert_str((shell.get_node("%PendingLabel") as Label).text).is_equal(tr(RunShell.PENDING_TEXT))


func test_shell_over_a_failed_load_shows_data_error_with_every_report_row() -> void:
	# Arrange
	var services: Services = _services(FAILED_FIXTURE)
	var lines: PackedStringArray = services.card_database.report().to_text().split("\n")

	# Act
	var shell: RunShell = await _shell(services)

	# Assert — Failed has no main menu (TD-008); one Label per CR-8 row
	assert_str(String(shell.screen())).is_equal("data_error")
	assert_bool((shell.get_node("%MainMenu") as Control).visible).is_false()
	assert_bool((shell.get_node("%DataError") as Control).visible).is_true()
	var rows: Array[Node] = shell.get_node("%ErrorRows").get_children()
	assert_int(rows.size()).is_equal(lines.size())
	for i: int in rows.size():
		assert_str((rows[i] as Label).text).is_equal(lines[i])
	assert_str(lines[0]).starts_with("[error] E_PARSE")


# --- RunShell over the shipped data and Boot's own validator map ------------------------

## Services over the shipped `assets/data/` loaded with the validator map a
## fresh Boot instance builds for [param debug_build] (never the autoload).
func _shipped_services(debug_build: bool) -> Services:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED_ROOT))
	db.load(boot._collect_validators(null, debug_build))
	var services: Services = Services.new()
	services.card_database = db
	return services


func test_shell_over_the_shipped_data_with_the_debug_map_shows_main_menu() -> void:
	# Act — a debug build: pending validators are warnings, the load is Ready
	var shell: RunShell = await _shell(_shipped_services(true))

	# Assert
	assert_str(String(shell.screen())).override_failure_message(shell.services().card_database.report().to_text()).is_equal("main_menu")


func test_shell_over_the_shipped_data_with_the_release_map_shows_data_error() -> void:
	# Arrange — an exported (release) build: every pending validator is an
	# error, so the shipped load fails by design (ADR-0002 Decision 4)
	var services: Services = _shipped_services(false)
	var lines: PackedStringArray = services.card_database.report().to_text().split("\n")

	# Act
	var shell: RunShell = await _shell(services)

	# Assert — no main menu; every error row is a pending validator (the loader
	# files an error-severity pending entry as `E_DELEGATED`, message prefixed
	# `W_VALIDATOR_PENDING:`)
	assert_str(String(shell.screen())).is_equal("data_error")
	assert_bool((shell.get_node("%MainMenu") as Control).visible).is_false()
	assert_int(shell.get_node("%ErrorRows").get_child_count()).is_equal(lines.size())
	var pending_errors: Array = Array(lines).filter(func(l: String) -> bool:
		return l.begins_with("[error] E_DELEGATED") and l.contains("W_VALIDATOR_PENDING"))
	assert_int(pending_errors.size()).is_equal(services.card_database.report().errors().size())
	assert_int(pending_errors.size()).is_greater(0)


func test_shell_stores_services_on_the_root_only() -> void:
	# Arrange
	var services: Services = _services(READY_FIXTURE)

	# Act
	var shell: RunShell = await _shell(services)

	# Assert — the bag is held by the shell root and handed nowhere deeper
	assert_object(shell.services()).is_same(services)
	for child: Node in shell.find_children("*", "", true, false):
		assert_bool(child.get_script() == null).override_failure_message("%s has a script" % child.name).is_true()


func test_shell_frees_without_orphans() -> void:
	# Arrange — not auto_free'd: this test frees it
	var shell: RunShell = RUN_SHELL_SCENE.instantiate()
	shell.bind(_services(READY_FIXTURE))
	add_child(shell)
	await get_tree().process_frame

	# Act
	shell.free()

	# Assert
	assert_bool(is_instance_valid(shell)).is_false()
