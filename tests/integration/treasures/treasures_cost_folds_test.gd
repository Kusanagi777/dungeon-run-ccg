## Integration: the cost treasures as the player sees them (treasures story 005;
## design/gdd/treasures.md T8 rows 2, 3, 4, 17, T9, F2, Edge Cases "Value folds and
## clamps", AC-8, AC-16, AC-17; ADR-0005 rule 4; ADR-0007 `apply_value_hook`).
##
## Every case runs the T8 records through the real `CardDatabase` pipeline,
## `Treasures.installers_for`, `MatchConfig`, `RulesEngine.start` and the real
## `EffectResolver`, on the GDD's seed and hero, and reaches its turn by real
## commands. "Displayed" is `effective_cost` / `hero_power_cost`, the value
## `legal_commands()` uses. "Paid" is the `mana_spent` of the accepted command.
##
## The clean root's `match_rules.json` and `card_effects.json` hold no knobs, so
## the bodies are `MatchFactory.make_rules_config()` and [method _effects_config].
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const ZONE_HAND: String = "hand"
const ZONE_HERO_POWER: String = "hero_power"
## The treasures GDD's AC preamble: `run_seed_hex` 00000000000000A7, hero `hero_war`.
const RUN_SEED: int = 0x00000000000000A7
const HERO_WAR: String = "hero_war"
## A boss card of the clean root, for a boss deck the root can look up.
const BOSS_CARD: String = "boss_grave_rat"
## What `installers_for` is handed by a run with no treasure state (T4).
const NO_STATE: Dictionary = {"schema_version": Treasures.SCHEMA_VERSION, "by_treasure": {}}

const SIGNET: String = "treasure_worn_signet"
const BANNER: String = "treasure_vanguards_banner"
const GRIMOIRE: String = "treasure_dogeared_grimoire"
const LEDGER: String = "treasure_quartermasters_ledger"

## The scripted hands' cards; the id carries the printed cost.
const MINION_0: String = "neutral_test_fold_minion_0"
const MINION_3: String = "neutral_test_fold_minion_3"
const SPELL_1: String = "neutral_test_fold_spell_1"
const SPELL_2: String = "neutral_test_fold_spell_2"
const SPELL_5: String = "neutral_test_fold_spell_5"
const COST_0: int = 0
const COST_1: int = 1
const COST_2: int = 2
const COST_3: int = 3
const COST_5: int = 5
## The size of a one-card deck ([method _deck_of]): the starter deck's.
const DECK_SIZE: int = 15

## Worn Signet's `set` and each discount's `delta`, from T9.
const SIGNET_COST: int = 1
const DISCOUNT: int = 1
## The boss fixture's `delta` (DD-X28).
const TAX: int = 1
## AC-17's turn, and what it holds.
const AC17_TURN: int = 4
const AC17_MANA: int = 4

var _engine: RulesEngine = null
var _log: TestEventLog = null


func after_test() -> void:
	if _engine != null:
		_engine.end_match()
	_engine = null
	_log = null


# --- helpers -------------------------------------------------------------------

func _effects_config() -> Dictionary:
	return {
		"discover_count": float(TestConstants.DISCOVER_COUNT),
		"discover_exclude_hand": false,
		"max_ops_per_effect": float(TestConstants.MAX_OPS_PER_EFFECT),
		"max_repeat": float(TestConstants.MAX_REPEAT),
		"max_summon_count": float(TestConstants.BOARD_SIZE),
		"effect_static_step_limit": float(TestConstants.EFFECT_STATIC_STEP_LIMIT),
		"spell_damage_default": "auto",
		"hooks_before_triggers": true,
	}


func _scripted_cards() -> Array:
	return [
		CardFactory.make_minion(MINION_0, COST_0, 1, 1),
		CardFactory.make_minion(MINION_3, COST_3, 3, 3),
		CardFactory.make_spell(SPELL_1, COST_1),
		CardFactory.make_spell(SPELL_2, COST_2),
		CardFactory.make_spell(SPELL_5, COST_5),
	]


func _deck_of(def_id: String) -> Array:
	var deck: Array = []
	deck.resize(DECK_SIZE)
	deck.fill(def_id)
	return deck


## A match in `Mulligan`: [param treasure_ids] through `installers_for` over the 20
## T8 records, and `boss_test_taxman`'s passive when [param taxman]. An empty
## [param deck] is `hero_war`'s starter deck.
func _start(treasure_ids: Array, taxman: bool = false, deck: Array = []) -> void:
	var db: CardDatabase = TreasureFixtures.database([], _scripted_cards())
	var hero: Dictionary = db.hero(HERO_WAR)
	var boss: Dictionary = TreasureFixtures.make_boss_test_taxman()
	var treasures: Treasures = Treasures.new(db, db.config("treasures_balance"))
	var boss_deck: Array = []
	boss_deck.resize(MatchFactory.STARTED_BOSS_DECK_SIZE)
	boss_deck.fill(BOSS_CARD)
	_log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(RUN_SEED), _log, {
		"player": {
			"hero_def_id": HERO_WAR,
			"deck": deck if not deck.is_empty() else Array(hero.starter_deck),
			"hook_installers": treasures.installers_for(treasure_ids, NO_STATE),
		},
		"boss": {
			"boss_def_id": str(boss.id),
			"deck": boss_deck,
			"hook_installers": Treasures.passive_installer(boss) if taxman else [],
		},
	})
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config(), str(hero.set)))
	_engine.start(config)


## From `Mulligan` to the player's Main of their turn [param turn], by real
## commands: a keep-all mulligan, then both `end_turn`s per turn passed.
func _to_turn(turn: int) -> void:
	_submit(_engine.legal_commands()[0])
	for _i: int in turn - 1:
		_end_round()


func _end_round() -> void:
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	_submit(MatchRecords.end_turn(SIDE_BOSS))


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message("rejected: %s" % str(result.rejection)).is_true()


func _noop() -> void:
	pass


## Replaces the player's hand with [param def_ids] (a scripted hand, story 005's
## Implementation Notes) and runs an empty step, whose C10 loop logs what moved.
func _script_hand(def_ids: Array) -> void:
	var hand: Array = _player().hand
	hand.clear()
	for def_id: String in def_ids:
		hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(_engine.state()), def_id, ZONE_HAND))
	_engine.index_locations()
	_engine.run_action(_noop)


func _player() -> Dictionary:
	return _engine.state().players[SIDE_PLAYER]


func _mana() -> int:
	return int(_player().mana_current)


func _shown(hand_index: int) -> int:
	return _engine.effective_cost(_player().hand[hand_index], SIDE_PLAYER)


func _power_shown() -> int:
	return _engine.hero_power_cost(SIDE_PLAYER)


func _base_power_cost() -> int:
	return _engine.rule("hero_power_cost")


func _legal_of(type: String) -> Array:
	return _engine.legal_commands().filter(func(cmd: Dictionary) -> bool: return str(cmd.type) == type)


func _is_playable(hand_index: int) -> bool:
	return _legal_of(MatchRecords.CMD_PLAY_CARD).any(func(cmd: Dictionary) -> bool: return int(cmd.hand_index) == hand_index)


func _last_seq() -> int:
	return int(_log.events.back().seq)


func _of_type(type: String, from_seq: int = 0) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq and str(e.type) == type)


## What each `mana_spent` after [param from_seq] took.
func _spent(from_seq: int = 0) -> Array:
	return _of_type("mana_spent", from_seq).map(func(e: Dictionary) -> int: return int(e.payload.amount))


## Every hand and hero-power entry of the `auras_recomputed` events after
## [param from_seq], oldest first.
func _cost_entries(from_seq: int = 0) -> Array:
	var out: Array = []
	for event: Dictionary in _of_type("auras_recomputed", from_seq):
		for change: Dictionary in event.payload.changes:
			if change.has("zone"):
				out.append(change)
	return out


## The last hand entry the log holds for [param card], `{}` when it holds none.
func _logged_entry(card: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	for entry: Dictionary in _cost_entries():
		if int(entry.get("instance_id", -1)) == int(card.instance_id):
			found = entry
	return found


func _hand_entry(card: Dictionary, cost: int, hook_delta: int = 0) -> Dictionary:
	var entry: Dictionary = {"instance_id": int(card.instance_id), "zone": ZONE_HAND, "effective_cost": cost}
	if hook_delta != 0:
		entry["hook_delta"] = hook_delta
	return entry


func _power_entries(from_seq: int = 0) -> Array:
	return _cost_entries(from_seq).filter(func(entry: Dictionary) -> bool: return str(entry.zone) == ZONE_HERO_POWER)


# --- AC-16: Worn Signet ----------------------------------------------------------

func test_ac16_signet_shows_one_on_the_button_and_in_the_log() -> void:
	# Act
	_start([SIGNET])

	# Assert — `set 1` replaces the base, before the Mulligan opens
	assert_int(_power_shown()).is_equal(SIGNET_COST)
	assert_array(_power_entries()).is_equal([{
		"side": SIDE_PLAYER, "zone": ZONE_HERO_POWER, "effective_cost": SIGNET_COST,
		"hook_delta": SIGNET_COST - _base_power_cost(),
	}])


func test_ac16_signet_spends_one_mana_on_the_first_turn() -> void:
	# Arrange
	_start([SIGNET])
	_to_turn(1)
	assert_int(_mana()).is_equal(SIGNET_COST)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	assert_array(_spent(before)).is_equal([SIGNET_COST])
	assert_int(_mana()).is_equal(0)


func test_ac16_without_the_signet_the_first_turn_cannot_afford_the_power() -> void:
	# Arrange
	_start([])
	_to_turn(1)

	# Act
	var result: Dictionary = _engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert — the control: the case above is the treasure's doing
	assert_bool(result.accepted).is_false()
	assert_str(str(result.rejection.code)).is_equal("NOT_ENOUGH_MANA")
	assert_array(_legal_of(MatchRecords.CMD_USE_HERO_POWER)).is_empty()


func test_ac16_a_second_use_the_same_turn_is_hero_power_used() -> void:
	# Arrange: turn 2 leaves 1 mana after the first use, enough to pay again
	_start([SIGNET])
	_to_turn(2)
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))
	assert_int(_mana()).is_equal(SIGNET_COST)

	# Act
	var result: Dictionary = _engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	assert_bool(result.accepted).is_false()
	assert_str(str(result.rejection.code)).is_equal("HERO_POWER_USED")
	assert_int(_mana()).is_equal(SIGNET_COST)
	assert_array(_legal_of(MatchRecords.CMD_USE_HERO_POWER)).is_empty()


func test_ac16_against_the_taxman_the_signet_shows_two() -> void:
	# Act
	_start([SIGNET], true)

	# Assert — F2: `set 1` then `+1`, treasure first and the passive last
	var hosts: Array = _engine.state().hooks.entries(&"modify_cost").map(func(entry: Dictionary) -> String: return str(entry.host_id))
	assert_array(hosts).is_equal([SIGNET, "boss_test_taxman"])
	assert_int(_power_shown()).is_equal(SIGNET_COST + TAX)


func test_ac16_against_the_taxman_the_power_is_paid_at_two() -> void:
	# Arrange
	_start([SIGNET], true)
	_to_turn(1)
	assert_array(_legal_of(MatchRecords.CMD_USE_HERO_POWER)).is_empty()
	_end_round()
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	assert_array(_spent(before)).is_equal([SIGNET_COST + TAX])
	assert_int(_mana()).is_equal(0)


func test_ac16_the_taxman_alone_raises_the_base_cost() -> void:
	# Act
	_start([], true)

	# Assert — without the `set`, the `delta` lands on the base
	assert_int(_power_shown()).is_equal(_base_power_cost() + TAX)


func test_ac16_neither_host_moves_the_boss_power() -> void:
	# Act
	_start([SIGNET], true)

	# Assert — T2.4: `friendly` and `enemy` both read from the entry's side
	assert_int(_engine.hero_power_cost(SIDE_BOSS)).is_equal(_base_power_cost())


# --- AC-17: Vanguard's Banner ----------------------------------------------------

## AC-17's GIVEN: player turn 4, the 3-cost minion then the 2-cost spell in hand.
func _banner_hand() -> void:
	_start([BANNER])
	_to_turn(AC17_TURN)
	assert_int(_mana()).is_equal(AC17_MANA)
	_script_hand([MINION_3, SPELL_2])


func test_ac17_both_cards_show_one_less_before_any_play() -> void:
	# Act
	_banner_hand()

	# Assert
	assert_int(_shown(0)).is_equal(COST_3 - DISCOUNT)
	assert_int(_shown(1)).is_equal(COST_2 - DISCOUNT)
	assert_dict(_logged_entry(_player().hand[0])).is_equal(_hand_entry(_player().hand[0], COST_3 - DISCOUNT, -DISCOUNT))
	assert_dict(_logged_entry(_player().hand[1])).is_equal(_hand_entry(_player().hand[1], COST_2 - DISCOUNT, -DISCOUNT))


func test_ac17_after_the_minion_for_two_the_spell_shows_two_and_is_playable() -> void:
	# Arrange
	_banner_hand()
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))

	# Assert
	assert_array(_spent(before)).is_equal([COST_3 - DISCOUNT])
	assert_int(_mana()).is_equal(AC17_MANA - (COST_3 - DISCOUNT))
	assert_int(_shown(0)).is_equal(COST_2)
	assert_bool(_is_playable(0)).is_true()
	assert_dict(_logged_entry(_player().hand[0])).is_equal(_hand_entry(_player().hand[0], COST_2))


func test_ac17_the_spell_at_full_price_ends_the_turn_at_zero_mana() -> void:
	# Arrange
	_banner_hand()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0))

	# Assert
	assert_array(_spent(before)).is_equal([COST_2])
	assert_int(_mana()).is_equal(0)


func test_ac17_the_hero_power_cost_is_unaffected_throughout() -> void:
	# Arrange
	_banner_hand()
	var shown: Array = [_power_shown()]

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))
	shown.append(_power_shown())
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0))
	shown.append(_power_shown())

	# Assert — R-13: `scope.card` without `kind` matches card instances only
	assert_array(shown).is_equal([_base_power_cost(), _base_power_cost(), _base_power_cost()])
	assert_array(_power_entries()).is_empty()


func test_ac17_a_hero_power_is_not_a_card_so_the_discount_stays() -> void:
	# Arrange
	_banner_hand()

	# Act
	_submit(MatchRecords.use_hero_power(SIDE_PLAYER))

	# Assert
	assert_int(_shown(1)).is_equal(COST_2 - DISCOUNT)


func test_ac17_the_discount_comes_back_on_the_next_turn() -> void:
	# Arrange: the minion takes this turn's discount; the spell is held
	_banner_hand()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))
	var held: Dictionary = _player().hand[0]
	assert_int(_engine.effective_cost(held, SIDE_PLAYER)).is_equal(COST_2)

	# Act
	_end_round()

	# Assert — "each turn": the Start step dropped the tally
	assert_int(_engine.effective_cost(held, SIDE_PLAYER)).is_equal(COST_2 - DISCOUNT)
	assert_dict(_logged_entry(held)).is_equal(_hand_entry(held, COST_2 - DISCOUNT, -DISCOUNT))


# --- AC-8: stacked discounts, floored once ---------------------------------------

## AC-8's GIVEN: Banner then Grimoire, a deck of the 1-cost spell, so the cards
## reach the hand through the real deal and the real log.
func _stacked_first_turn() -> void:
	_start([BANNER, GRIMOIRE], false, _deck_of(SPELL_1))
	_to_turn(1)


func test_ac8_the_stacked_spell_displays_zero() -> void:
	# Act
	_stacked_first_turn()

	# Assert
	assert_int(_shown(0)).is_equal(0)
	assert_bool(_is_playable(0)).is_true()


func test_ac8_the_stacked_spell_is_paid_at_zero_with_nothing_refunded() -> void:
	# Arrange
	_stacked_first_turn()
	var mana: int = _mana()
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0))

	# Assert — the fold reads -1, the clamp 0, and the pool neither falls nor rises
	assert_array(_spent(before)).is_equal([0])
	assert_int(_mana()).is_equal(mana)


func test_ac8_the_hand_entry_logs_hook_delta_minus_two() -> void:
	# Act
	_stacked_first_turn()

	# Assert — DD-X29: the raw net of the fold, not the 1 the clamp left visible
	for card: Dictionary in _player().hand:
		assert_dict(_logged_entry(card)).is_equal(_hand_entry(card, 0, -2 * DISCOUNT))


func test_ac8_after_the_first_card_only_the_grimoire_is_left_in_the_entry() -> void:
	# Arrange
	_stacked_first_turn()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0))

	# Assert — the cost stays 0, but the fold moved, so the log hears of it
	for card: Dictionary in _player().hand:
		assert_int(_engine.effective_cost(card, SIDE_PLAYER)).is_equal(COST_1 - DISCOUNT)
		assert_dict(_logged_entry(card)).is_equal(_hand_entry(card, COST_1 - DISCOUNT, -DISCOUNT))


func test_f2_three_discounts_on_a_five_cost_spell_read_two() -> void:
	# Arrange
	_start([BANNER, LEDGER, GRIMOIRE])
	_to_turn(1)

	# Act
	_script_hand([SPELL_5])

	# Assert — F2's worked example
	var card: Dictionary = _player().hand[0]
	assert_int(_shown(0)).is_equal(COST_5 - 3 * DISCOUNT)
	assert_dict(_logged_entry(card)).is_equal(_hand_entry(card, COST_5 - 3 * DISCOUNT, -3 * DISCOUNT))


# --- Edge Cases "Value folds and clamps": a 0-cost card still counts -----------------

func test_a_printed_zero_cost_card_takes_the_banner_so_the_next_pays_full_cost() -> void:
	# Arrange
	_start([BANNER])
	_to_turn(AC17_TURN)
	_script_hand([MINION_0, MINION_3])
	assert_int(_shown(0)).is_equal(0)
	assert_int(_shown(1)).is_equal(COST_3 - DISCOUNT)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 1))

	# Assert
	assert_array(_spent(before)).is_equal([0, COST_3])


func test_a_card_discounted_to_zero_takes_the_banner_so_the_next_pays_full_cost() -> void:
	# Arrange
	_start([BANNER])
	_to_turn(AC17_TURN)
	_script_hand([SPELL_1, MINION_3])
	assert_int(_shown(0)).is_equal(0)
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0))
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))

	# Assert
	assert_array(_spent(before)).is_equal([0, COST_3])
