## Integration: `main.tscn`'s composition seam and `RunShell`
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


## The screen instanced under [param shell] as [param node_name], or null.
func _screen_node(shell: RunShell, node_name: String) -> Control:
	return shell.find_child(node_name, true, false) as Control


## The text of every report row `data_error` listed, in order.
func _error_rows(shell: RunShell) -> Array[String]:
	var rows: Array[String] = []
	for label: Node in _screen_node(shell, "DataError").find_children("*", "Label", true, false):
		if (label as Label).text.contains("  ["):
			rows.append((label as Label).text)
	return rows


## The row text `data_error` draws for each entry of [param report] (run-ui U2).
func _expected_rows(report: ValidationReport) -> Array[String]:
	var rows: Array[String] = []
	for row: Dictionary in RunReadModels.data_error(report).rows:
		rows.append("%s  %s  [%s]  %s" % [row.file, row.id, row.code, row.message])
	return rows


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
	assert_bool(_screen_node(shell, "MainMenu").visible).is_true()
	assert_object(_screen_node(shell, "DataError")).is_null()


func test_shell_over_a_failed_load_shows_data_error_with_every_report_row() -> void:
	# Arrange
	var services: Services = _services(FAILED_FIXTURE)
	var lines: PackedStringArray = services.card_database.report().to_text().split("\n")

	# Act
	var shell: RunShell = await _shell(services)

	# Assert — Failed has no main menu (TD-008); one Label per CR-8 row
	assert_str(String(shell.screen())).is_equal("data_error")
	assert_object(_screen_node(shell, "MainMenu")).is_null()
	assert_bool(_screen_node(shell, "DataError").visible).is_true()
	var rows: Array[String] = _error_rows(shell)
	assert_int(rows.size()).is_equal(lines.size())
	assert_array(rows).is_equal(_expected_rows(services.card_database.report()))
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


func test_shell_over_the_shipped_data_with_the_release_map_shows_main_menu() -> void:
	# Arrange — an exported (release) build: a pending validator would be an error and
	# fail the load (ADR-0002 Decision 4). None is pending, so the shipped data is Ready
	# and a release build reaches the menu (sprint-006 prerequisite 15)
	var services: Services = _shipped_services(false)

	# Act
	var shell: RunShell = await _shell(services)

	# Assert
	assert_array(services.card_database.report().errors()).override_failure_message(services.card_database.report().to_text()).is_empty()
	assert_str(String(shell.screen())).is_equal("main_menu")
	assert_bool(_screen_node(shell, "MainMenu").visible).is_true()
	assert_object(_screen_node(shell, "DataError")).is_null()


func test_shell_stores_services_on_the_root_only() -> void:
	# Arrange
	var services: Services = _services(READY_FIXTURE)

	# Act
	var shell: RunShell = await _shell(services)

	# Assert — the bag is held by the shell root and handed nowhere deeper
	assert_object(shell.services()).is_same(services)
	for child: Node in shell.find_children("*", "", true, false):
		for property: Dictionary in child.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				assert_bool(child.get(property.name) is Services) \
					.override_failure_message("%s holds the bag in %s" % [child.name, property.name]).is_false()


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
