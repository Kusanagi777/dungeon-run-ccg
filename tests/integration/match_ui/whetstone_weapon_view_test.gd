## Whetstone's +1 reaches the weapon the player sees (owner playtest, 2026-11-06). The
## engine has always counted it; the view state dropped an enchantment on a weapon, so
## the weapon's stamp never changed. Real engine, real power, real projection.
extends GdUnitTestSuite

const BLADE: String = "war_whetstone_blade"
const BLADE_ATTACK: int = 1
const WHETSTONE_DELTA: int = 1


func _project(view: MatchViewState, game: ShippedMatch, after_seq: int) -> void:
	for event: Dictionary in game.events_after(after_seq):
		var _steps: Array[AnimStep] = view.apply(event)


func test_the_view_shows_the_buffed_weapon_and_drops_it_at_the_end_step() -> void:
	# Arrange
	var game: ShippedMatch = ShippedMatch.new(ShippedMatch.database(), "hero_war", "boss_torchbearer")
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.shipped())
	game.to_player_main()
	game.set_hand(ShippedMatch.SIDE_PLAYER, [])
	var _blade: int = game.engine.equip_weapon(ShippedMatch.SIDE_PLAYER, BLADE)
	_project(view, game, 0)
	var seen: int = game.last_seq()
	assert_int(int(view.side(&"player").hero.weapon.attack)).is_equal(BLADE_ATTACK)

	# Act
	assert_bool(bool(game.submit(MatchRecords.use_hero_power(ShippedMatch.SIDE_PLAYER)).accepted)).is_true()
	_project(view, game, seen)
	seen = game.last_seq()

	# Assert
	assert_int(int(view.side(&"player").hero.weapon.attack)).is_equal(BLADE_ATTACK + WHETSTONE_DELTA)

	# Act: the End step
	assert_bool(bool(game.submit(MatchRecords.end_turn(ShippedMatch.SIDE_PLAYER)).accepted)).is_true()
	_project(view, game, seen)

	# Assert
	assert_int(int(view.side(&"player").hero.weapon.attack)).is_equal(BLADE_ATTACK)
