## Unit tests for the `migrate_v{k}_to_v{k+1}` chain (design/gdd/meta-progression.md
## M4.4; ADR-0004 Decision 7): steps are injected, since schema 1 ships none. The
## chain through a real load is `tests/integration/save/profile_migration_load_test.gd`.
extends GdUnitTestSuite

const TARGET_V3: int = 3


func _advance_to(version: int, marker: String) -> Callable:
	return func(profile: Dictionary) -> Dictionary:
		var out: Dictionary = profile.duplicate(true)
		out["schema_version"] = version
		(out.get_or_add("steps", []) as Array).append(marker)
		return out


func test_migrate_at_target_returns_the_profile_untouched() -> void:
	# Arrange
	var calls: Array = []
	var step: Callable = func(profile: Dictionary) -> Dictionary:
		calls.append(1)
		return profile
	var chain: ProfileMigrations = ProfileMigrations.new({2: step}, 2)
	var profile: Dictionary = {"schema_version": 2}

	# Act
	var migrated: Variant = chain.migrate(profile)

	# Assert
	assert_dict(migrated).is_equal(profile)
	assert_array(calls).is_empty()


func test_migrate_applies_steps_in_sequence() -> void:
	# Arrange
	var chain: ProfileMigrations = ProfileMigrations.new({1: _advance_to(2, "1to2"), 2: _advance_to(TARGET_V3, "2to3")}, TARGET_V3)

	# Act
	var migrated: Dictionary = chain.migrate({"schema_version": 1})

	# Assert
	assert_int(migrated.schema_version).is_equal(TARGET_V3)
	assert_array(migrated.steps).is_equal(["1to2", "2to3"])


func test_migrate_starts_from_the_profile_version() -> void:
	# Arrange
	var chain: ProfileMigrations = ProfileMigrations.new({1: _advance_to(2, "1to2"), 2: _advance_to(TARGET_V3, "2to3")}, TARGET_V3)

	# Act
	var migrated: Dictionary = chain.migrate({"schema_version": 2})

	# Assert
	assert_array(migrated.steps).is_equal(["2to3"])


func test_migrate_missing_step_has_no_path() -> void:
	# Arrange
	var chain: ProfileMigrations = ProfileMigrations.new({2: _advance_to(TARGET_V3, "2to3")}, TARGET_V3)

	# Act / Assert
	assert_that(chain.migrate({"schema_version": 1})).is_null()


func test_migrate_step_that_does_not_advance_the_version_fails() -> void:
	# Arrange
	var chain: ProfileMigrations = ProfileMigrations.new({1: _advance_to(1, "stuck")}, 2)

	# Act / Assert
	assert_that(chain.migrate({"schema_version": 1})).is_null()


func test_shipped_chain_is_empty_at_schema_one() -> void:
	# Act / Assert (a shipped step needs a schema bump: AC-30's one constant)
	assert_dict(ProfileMigrations.shipped_steps()).is_empty()
	assert_int(ProfileStore.PROFILE_SCHEMA_VERSION).is_equal(1)


func test_worked_v1_to_v2_is_pure_and_takes_the_smaller_random_seed_turn_count() -> void:
	# Arrange: M4.4's worked example
	var profile: Dictionary = ProfileFixtures.profile_dict({"run_log": [
		ProfileFixtures.victory("run_a", ProfileFixtures.HERO_WAR, 70),
		ProfileFixtures.victory("run_b", ProfileFixtures.HERO_WAR, 55),
		ProfileFixtures.victory("run_c", ProfileFixtures.HERO_WAR, 30, 600, "custom"),
	]})
	profile.stats.heroes[ProfileFixtures.HERO_WAR] = ProfileSchema.empty_hero_stats()
	var before: Dictionary = profile.duplicate(true)

	# Act
	var migrated: Dictionary = ProfileFixtures.worked_v1_to_v2(profile)

	# Assert
	assert_int(migrated.schema_version).is_equal(2)
	assert_int(migrated.stats.heroes[ProfileFixtures.HERO_WAR].best_turns_victory).is_equal(55)
	assert_dict(profile).is_equal(before)
