## Unit tests for SettingsBus (story boot-composition-root/story-001).
##
## The bus is constructed directly, never through Boot (ADR-0001: tests under
## tests/unit/** build rules objects themselves). Keys are M9 setting names
## (design/gdd/meta-progression.md M9); the published values are arbitrary
## test payloads — the bus validates nothing, so no M9 range is asserted here.
extends GdUnitTestSuite


const KEY_GAMMA: StringName = &"gamma"
const KEY_ANIM_SPEED: StringName = &"anim_speed"
const KEY_BINDINGS: StringName = &"bindings"
const KEY_NEVER_PUBLISHED: StringName = &"telegraph_mode"


## Connects a recorder to `bus.settings_changed`. A lambda captures locals by
## value (4.5+, current-best-practices.md), so the record is a shared Dictionary.
func _record_emits(bus: SettingsBus) -> Dictionary:
	var record: Dictionary = {"count": 0, "args": []}
	bus.settings_changed.connect(func(key: StringName, value: Variant) -> void:
		record.count += 1
		record.args.append([key, value]))
	return record


# --- AC-1: shape ---------------------------------------------------------------

func test_settings_bus_constructs_with_no_collaborator_and_is_refcounted() -> void:
	# Arrange / Act
	var bus: SettingsBus = SettingsBus.new()

	# Assert
	assert_object(bus).is_not_null()
	assert_bool(bus is RefCounted).is_true()


func test_settings_bus_declares_exactly_one_signal_settings_changed() -> void:
	# Arrange
	var bus: SettingsBus = SettingsBus.new()

	# Act
	var signals: Array[Dictionary] = bus.get_script().get_script_signal_list()

	# Assert
	assert_int(signals.size()).is_equal(1)
	assert_str(String(signals[0].name)).is_equal("settings_changed")
	assert_int((signals[0].args as Array).size()).is_equal(2)


# --- AC-2: publish → one synchronous emit, get_setting answers -----------------

func test_publish_emits_settings_changed_once_with_key_and_value() -> void:
	# Arrange
	var bus: SettingsBus = SettingsBus.new()
	var record: Dictionary = _record_emits(bus)
	var value: float = 1.2

	# Act
	bus.publish(KEY_GAMMA, value)

	# Assert — counted before publish() returned: the emit is synchronous
	assert_int(record.count).is_equal(1)
	assert_that(record.args[0][0]).is_equal(KEY_GAMMA)
	assert_float(record.args[0][1]).is_equal(value)


func test_publish_is_seen_by_game_assertions_signal_watch() -> void:
	# Arrange
	var bus: SettingsBus = SettingsBus.new()

	# Act / Assert
	GameAssertions.assert_signal_emitted(bus, "settings_changed",
		func() -> void: bus.publish(KEY_ANIM_SPEED, "fast"))


func test_publish_then_get_setting_returns_published_value() -> void:
	# Arrange
	var bus: SettingsBus = SettingsBus.new()

	# Act
	bus.publish(KEY_ANIM_SPEED, "instant")

	# Assert
	assert_str(bus.get_setting(KEY_ANIM_SPEED)).is_equal("instant")


func test_publish_dictionary_value_get_setting_returns_it() -> void:
	# Arrange — `bindings` is an opaque map (M9; ADR-0004 addendum)
	var bus: SettingsBus = SettingsBus.new()
	var bindings: Dictionary = {"end_turn": []}

	# Act
	bus.publish(KEY_BINDINGS, bindings)

	# Assert
	assert_dict(bus.get_setting(KEY_BINDINGS)).is_equal(bindings)


func test_publish_same_key_twice_get_setting_returns_latest_and_emits_twice() -> void:
	# Arrange
	var bus: SettingsBus = SettingsBus.new()
	var record: Dictionary = _record_emits(bus)

	# Act
	bus.publish(KEY_ANIM_SPEED, "fast")
	bus.publish(KEY_ANIM_SPEED, "normal")

	# Assert
	assert_int(record.count).is_equal(2)
	assert_str(bus.get_setting(KEY_ANIM_SPEED)).is_equal("normal")


func test_get_setting_of_never_published_key_returns_null() -> void:
	# Arrange
	var bus: SettingsBus = SettingsBus.new()
	bus.publish(KEY_GAMMA, 1.0)

	# Act
	var value: Variant = bus.get_setting(KEY_NEVER_PUBLISHED)

	# Assert
	assert_that(value).is_null()


func test_get_setting_on_fresh_bus_returns_null_and_emits_nothing() -> void:
	# Arrange
	var bus: SettingsBus = SettingsBus.new()
	var record: Dictionary = _record_emits(bus)

	# Act
	var value: Variant = bus.get_setting(KEY_GAMMA)

	# Assert — a read never emits
	assert_that(value).is_null()
	assert_int(record.count).is_equal(0)


func test_get_setting_accepts_string_key_for_string_name_publish() -> void:
	# Arrange — callers may hold a String key (JSON-sourced); StringName converts
	var bus: SettingsBus = SettingsBus.new()
	bus.publish(&"reduce_motion", true)

	# Act
	var value: Variant = bus.get_setting("reduce_motion")

	# Assert
	assert_bool(value).is_true()
