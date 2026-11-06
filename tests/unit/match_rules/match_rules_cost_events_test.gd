## DD-X29: every cost change the player can see reaches the log, so
## `MatchViewState` stays a pure function of events (design/gdd/match-rules.md
## C10, C15 `auras_recomputed`, F1; rng-event-log §D; match-ui U3 rule 3 and
## table; treasures AC-8).
##
## Each recompute diffs the player's hand and hero power against what the log
## last reported, not against the aura pass's `before`, because a `modify_cost`
## hook moves a cost with no write at all: Vanguard's Banner moves on when a
## tally does. The real `RulesEngine` runs bound to the real `EffectResolver`,
## with hosts installed through `MatchConfig`.
extends GdUnitTestSuite

const SIDE_PLAYER: String = "player"
const SIDE_BOSS: String = "boss"
const ZONE_HAND: String = "hand"
const ZONE_HERO_POWER: String = "hero_power"
const AURAS: String = "auras_recomputed"
const TREASURE: StringName = HookInstaller.HOST_KIND_TREASURE
const PASSIVE: StringName = HookInstaller.HOST_KIND_PASSIVE

const MINION_1: String = "neutral_test_cost_one"
const MINION_3: String = "neutral_test_cost_three"
const SPELL_1: String = "knowledge_test_cost_one_spell"
const SCOUT: String = "knowledge_test_scout"
const WAR_DRUM: String = "neutral_test_cost_war_drum"
const SPELL_LORD: String = "neutral_test_cost_spell_lord"
const POWER: String = "power_test_cost"
const COST_1: int = 1
const COST_3: int = 3
const CHEAPER: Dictionary = {"op": "modify_value", "delta": -1}
const DEARER: Dictionary = {"op": "modify_value", "delta": 1}
const SET_1: Dictionary = {"op": "modify_value", "set": 1}
const ANY_FRIENDLY_CARD: Dictionary = {"card": {"side": "friendly"}}
const FRIENDLY_SPELLS: Dictionary = {"card": {"side": "friendly", "type": "spell"}}
const FRIENDLY_POWER: Dictionary = {"card": {"side": "friendly", "kind": "hero_power"}}
## Vanguard's Banner's condition (treasures R-2).
const FIRST_CARD: Dictionary = {"cmp": [{"ref": "owner.cards_played_this_turn"}, "==", 0]}
## The commands the walk in the purity test takes.
const WALK_COMMANDS: int = 60


## `has` / `card` / `hero_power` from a map (the engine and the resolver ask
## nothing else in a match).
class FakeCardDatabase:
	extends CardDatabase

	var records: Dictionary = {}

	func _init(by_id: Dictionary) -> void:
		records = by_id

	func has(id: String) -> bool:
		return records.has(id)

	func card(id: String) -> Variant:
		return records.get(id)

	func hero_power(id: String) -> Variant:
		return records.get(id)


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


func _db() -> FakeCardDatabase:
	var by_id: Dictionary = {}
	for record: Dictionary in CardFactory.make_fixture_card_set():
		by_id[record.id] = record
	by_id[MINION_1] = CardFactory.make_minion(MINION_1, COST_1, 1, 1)
	by_id[MINION_3] = CardFactory.make_minion(MINION_3, COST_3, 3, 3)
	by_id[SPELL_1] = CardFactory.make_spell(SPELL_1, COST_1)
	by_id[SCOUT] = CardFactory.make_spell(SCOUT, COST_1, [
		{"trigger": "cast", "ops": [
			{"op": "add_to_hand", "card_id": MINION_3},
			{"op": "discover", "pool": "list", "list": ["neutral_test_taunt", "neutral_test_charge", "neutral_test_rush"], "then": "add_to_hand"},
		]},
	])
	by_id[WAR_DRUM] = CardFactory.make_minion(WAR_DRUM, COST_1, 1, 1, ["aura"], {"effects": [
		{"trigger": "aura", "targets": {"selector": "all_friendly_minions", "filter": {"not_self": true}}, "ops": [{"op": "aura", "attack": 1}]},
	]})
	by_id[SPELL_LORD] = CardFactory.make_minion(SPELL_LORD, COST_1, 1, 1, ["aura"], {"effects": [
		{"trigger": "aura", "scope": {"zone": "hand"}, "targets": {"selector": "hand", "filter": {"type": "spell"}}, "ops": [{"op": "aura", "cost": -1}]},
	]})
	by_id[POWER] = CardFactory.make_hero_power_def(POWER)
	return FakeCardDatabase.new(by_id)


## A started engine in `Mulligan` with [param installers]; [param overrides]
## merges into the `MatchConfig`.
func _start(installers: Array, overrides: Dictionary = {}) -> void:
	var db: FakeCardDatabase = _db()
	_log = TestEventLog.new()
	var player: Dictionary = {"hook_installers": installers.filter(func(i: HookInstaller) -> bool: return i.side == &"player")}
	var boss: Dictionary = {"hook_installers": installers.filter(func(i: HookInstaller) -> bool: return i.side == &"boss")}
	player.merge(overrides.get("player", {}), true)
	boss.merge(overrides.get("boss", {}), true)
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), _log, {"player": player, "boss": boss})
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, _effects_config()))
	_engine.start(config)


## Player Main, turn 1, both boards and hands empty, 10 mana, hero power
## [constant POWER].
func _main_phase(installers: Array = []) -> void:
	_start(installers)
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	for side: String in MatchRecords.SIDES:
		_engine.state().players[side].hand.clear()
		_engine.state().players[side].board.clear()
	_engine.state().players[SIDE_PLAYER].mana_current = 10
	_engine.state().players[SIDE_PLAYER].hero_power.def_id = POWER


func _hook(id: String, side: StringName, scope: Dictionary, op: Dictionary, condition: Variant = null) -> HookInstaller:
	var effect: Dictionary = {"trigger": "modify_cost", "scope": scope, "ops": [op]}
	if condition != null:
		effect["condition"] = condition
	return HookInstaller.new(PASSIVE if side == &"boss" else TREASURE, id, side, [effect])


func _banner() -> HookInstaller:
	return _hook("treasure_test_banner", &"player", ANY_FRIENDLY_CARD, CHEAPER, FIRST_CARD)


func _to_hand(side: String, def_id: String) -> Dictionary:
	var card: Dictionary = MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(_engine.state()), def_id, ZONE_HAND)
	_engine.state().players[side].hand.append(card)
	return card


func _noop() -> void:
	pass


## One engine step with nothing in it: its C10 loop reports what moved.
func _settle() -> void:
	_engine.run_action(_noop)


func _submit(command: Dictionary) -> void:
	var result: Dictionary = _engine.submit(command)
	assert_bool(result.accepted).override_failure_message(str(result)).is_true()


func _last_seq() -> int:
	return int(_log.events.back().seq) if not _log.events.is_empty() else 0


func _aura_events(from_seq: int) -> Array:
	return _log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq and str(e.type) == AURAS)


## The hand and hero-power entries of every `auras_recomputed` after [param from_seq].
func _cost_entries(from_seq: int) -> Array:
	var out: Array = []
	for event: Dictionary in _aura_events(from_seq):
		for change: Dictionary in event.payload.changes:
			if change.has("zone"):
				out.append(change)
	return out


func _hand_entry(instance_id: int, cost: int, hook_delta: int = 0) -> Dictionary:
	var entry: Dictionary = {"instance_id": instance_id, "zone": ZONE_HAND, "effective_cost": cost}
	if hook_delta != 0:
		entry["hook_delta"] = hook_delta
	return entry


func _power_entry(cost: int, hook_delta: int = 0) -> Dictionary:
	var entry: Dictionary = {"side": SIDE_PLAYER, "zone": ZONE_HERO_POWER, "effective_cost": cost}
	if hook_delta != 0:
		entry["hook_delta"] = hook_delta
	return entry


# --- hooks on a hand card ----------------------------------------------------------

func test_a_hook_discount_on_the_starting_hand_is_logged_before_the_mulligan_opens() -> void:
	# Act
	_start([_hook("treasure_test_all", &"player", ANY_FRIENDLY_CARD, CHEAPER)], {"player": {"deck": [MINION_3, MINION_3, MINION_3, MINION_3]}})

	# Assert: the mulligan screen shows costs, so they are in the log before it opens
	var offered: Array = _log.events.filter(func(e: Dictionary) -> bool: return str(e.type) == "mulligan_offered")
	var expected: Array = []
	for card: Dictionary in _engine.state().players[SIDE_PLAYER].hand:
		expected.append(_hand_entry(int(card.instance_id), COST_3 - 1, -1))
	assert_array(_cost_entries(0)).is_equal(expected)
	assert_int(int(_aura_events(0)[0].seq)).is_less(int(offered[0].seq))


func test_a_card_drawn_under_a_hook_is_reported_with_its_discount() -> void:
	# Arrange
	_main_phase([_hook("treasure_test_all", &"player", ANY_FRIENDLY_CARD, CHEAPER)])
	var before: int = _last_seq()
	var card: Dictionary = _to_hand(SIDE_PLAYER, MINION_3)

	# Act
	_settle()

	# Assert
	assert_array(_cost_entries(before)).is_equal([_hand_entry(int(card.instance_id), COST_3 - 1, -1)])


func test_a_reported_cost_that_has_not_moved_is_not_reported_again() -> void:
	# Arrange
	_main_phase([_hook("treasure_test_all", &"player", ANY_FRIENDLY_CARD, CHEAPER)])
	_to_hand(SIDE_PLAYER, MINION_3)
	_settle()
	var before: int = _last_seq()

	# Act
	_settle()

	# Assert
	assert_array(_aura_events(before)).is_empty()


func test_a_hook_that_leaves_a_card_at_its_printed_cost_logs_no_entry() -> void:
	# Arrange
	_main_phase([_hook("treasure_test_spells", &"player", FRIENDLY_SPELLS, CHEAPER)])
	var before: int = _last_seq()
	_to_hand(SIDE_PLAYER, MINION_3)

	# Act
	_settle()

	# Assert
	assert_array(_aura_events(before)).is_empty()


func test_a_condition_that_turns_off_reports_the_hand_back_at_printed_cost() -> void:
	# Arrange: Banner discounts every card until one is played
	_main_phase([_banner()])
	_to_hand(SIDE_PLAYER, MINION_1)
	var later: Dictionary = _to_hand(SIDE_PLAYER, MINION_3)
	_settle()
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))

	# Assert: no write touched `later`, and its absolute entry carries no hook_delta
	assert_array(_cost_entries(before)).is_equal([_hand_entry(int(later.instance_id), COST_3)])
	assert_int(_engine.effective_cost(later, SIDE_PLAYER)).is_equal(COST_3)


func test_the_discount_coming_back_on_the_next_turn_is_reported() -> void:
	# Arrange
	_main_phase([_banner()])
	_to_hand(SIDE_PLAYER, MINION_1)
	var later: Dictionary = _to_hand(SIDE_PLAYER, MINION_3)
	_settle()
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))
	var before: int = _last_seq()

	# Act: round to the player's next Main
	_submit(MatchRecords.end_turn(SIDE_PLAYER))
	_submit(MatchRecords.end_turn(SIDE_BOSS))

	# Assert
	var mine: Array = _cost_entries(before).filter(func(e: Dictionary) -> bool: return int(e.get("instance_id", 0)) == int(later.instance_id))
	assert_array(mine).is_equal([_hand_entry(int(later.instance_id), COST_3 - 1, -1)])


func test_a_card_added_before_a_choice_pause_is_costed_while_the_choice_is_open() -> void:
	# Arrange
	_main_phase([_hook("treasure_test_all", &"player", ANY_FRIENDLY_CARD, CHEAPER)])
	_to_hand(SIDE_PLAYER, SCOUT)
	_settle()
	var before: int = _last_seq()

	# Act: the Discover pauses the cast, so no C10 loop follows the added card
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0))

	# Assert
	assert_str(_engine.state().phase).is_equal(MatchState.PHASE_CHOICE)
	var added: Dictionary = _engine.state().players[SIDE_PLAYER].hand.back()
	assert_array(_cost_entries(before)).is_equal([_hand_entry(int(added.instance_id), COST_3 - 1, -1)])


# --- hook_delta: treasures AC-8 ------------------------------------------------------

func test_hook_delta_is_the_raw_net_of_the_fold_floored_once_for_the_cost() -> void:
	# Arrange: treasures AC-8, Banner and Grimoire on a 1-cost spell
	var grimoire: HookInstaller = _hook("treasure_test_grimoire", &"player", FRIENDLY_SPELLS, CHEAPER)
	_main_phase([_banner(), grimoire])
	var before: int = _last_seq()
	var card: Dictionary = _to_hand(SIDE_PLAYER, SPELL_1)

	# Act
	_settle()

	# Assert: fold 1 - 1 - 1 = -1, floored to 0 once
	assert_array(_cost_entries(before)).is_equal([_hand_entry(int(card.instance_id), 0, -2)])


func test_a_hook_delta_that_moves_under_a_floored_cost_is_reported() -> void:
	# Arrange
	var grimoire: HookInstaller = _hook("treasure_test_grimoire", &"player", FRIENDLY_SPELLS, CHEAPER)
	_main_phase([_banner(), grimoire])
	_to_hand(SIDE_PLAYER, MINION_1)
	var card: Dictionary = _to_hand(SIDE_PLAYER, SPELL_1)
	_settle()
	var before: int = _last_seq()

	# Act: Banner moves on; the spell stays at 0 but only Grimoire discounts it
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))

	# Assert
	assert_array(_cost_entries(before)).is_equal([_hand_entry(int(card.instance_id), 0, -1)])


# --- enchantments on a hand card -----------------------------------------------------

func test_a_non_aura_cost_enchantment_and_its_expiry_are_reported() -> void:
	# Arrange
	_main_phase()
	var card: Dictionary = _to_hand(SIDE_PLAYER, MINION_3)
	var id: int = int(card.instance_id)
	var before: int = _last_seq()

	# Act
	_engine.run_action(func() -> void: _engine.apply_enchantment(id, {"cost_delta": -1, "expires": MatchRecords.EXPIRES_END_OF_TURN}))
	var applied: Array = _cost_entries(before)
	before = _last_seq()
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert: an enchantment is not a hook, so no hook_delta
	assert_array(applied).is_equal([_hand_entry(id, COST_3 - 1)])
	assert_array(_cost_entries(before)).is_equal([_hand_entry(id, COST_3)])


# --- the hero power ------------------------------------------------------------------

func test_a_hook_on_the_hero_power_is_reported_as_a_hero_power_entry() -> void:
	# Arrange
	_main_phase([_hook("treasure_test_signet", &"player", FRIENDLY_POWER, SET_1)])
	var before: int = _last_seq()

	# Act
	_settle()

	# Assert
	assert_array(_cost_entries(before)).is_equal([_power_entry(1, 1 - TestConstants.HERO_POWER_COST)])
	assert_int(_engine.hero_power_cost(SIDE_PLAYER)).is_equal(1)


func test_a_hero_power_condition_that_turns_off_reports_the_base_cost() -> void:
	# Arrange
	_main_phase([_hook("treasure_test_early_power", &"player", FRIENDLY_POWER, CHEAPER, FIRST_CARD)])
	_to_hand(SIDE_PLAYER, MINION_1)
	_settle()
	var before: int = _last_seq()

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))

	# Assert
	assert_array(_cost_entries(before)).is_equal([_power_entry(TestConstants.HERO_POWER_COST)])


func test_a_side_with_no_hero_power_reports_none() -> void:
	# Arrange
	_main_phase([_hook("treasure_test_signet", &"player", FRIENDLY_POWER, SET_1)])
	_engine.state().players[SIDE_PLAYER].hero_power.def_id = ""

	# Act
	_settle()

	# Assert: from the start of the match, when the hook was already installed
	assert_array(_aura_events(0)).is_empty()


func test_a_boss_tax_on_the_players_cards_and_power_is_reported() -> void:
	# Arrange: DD-X28: `enemy` from the boss's entry is the player
	var taxman: HookInstaller = _hook("boss_test_taxman", &"boss", {"card": {"side": "enemy", "kind": "any"}}, DEARER)
	_main_phase([taxman])
	var before: int = _last_seq()
	var card: Dictionary = _to_hand(SIDE_PLAYER, MINION_3)

	# Act
	_settle()

	# Assert: the hand first, then the power
	assert_array(_cost_entries(before)).is_equal([
		_hand_entry(int(card.instance_id), COST_3 + 1, 1),
		_power_entry(TestConstants.HERO_POWER_COST + 1, 1),
	])


# --- what stays out ------------------------------------------------------------------

func test_a_boss_hand_card_never_appears_however_its_cost_moves() -> void:
	# Arrange: U3 rule 2. The toll really moves this cost; a scan of the boss hand
	# folds as the player, and the discount would then list the card
	var toll: HookInstaller = _hook("treasure_test_toll", &"player", {"card": {"side": "enemy"}}, DEARER)
	var discount: HookInstaller = _hook("treasure_test_all", &"player", ANY_FRIENDLY_CARD, CHEAPER)
	_main_phase([toll, discount])
	var before: int = _last_seq()
	var card: Dictionary = _to_hand(SIDE_BOSS, MINION_3)

	# Act
	_settle()

	# Assert
	assert_int(_engine.effective_cost(card, SIDE_BOSS)).is_equal(COST_3 + 1)
	assert_array(_aura_events(before)).is_empty()


func test_a_match_with_no_cost_change_logs_no_auras_recomputed() -> void:
	# Arrange
	_main_phase()
	_to_hand(SIDE_PLAYER, MINION_1)

	# Act
	_submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0))
	_submit(MatchRecords.end_turn(SIDE_PLAYER))

	# Assert
	assert_array(_aura_events(0)).is_empty()


# --- one event, after the characters -------------------------------------------------

func test_an_aura_change_and_a_cost_change_share_one_event_characters_first() -> void:
	# Arrange
	_main_phase()
	var ally: int = int(MatchFactory.summon(_engine.state(), SIDE_PLAYER, 1, 1, -1, [], MINION_1).entity_id)
	var card: Dictionary = _to_hand(SIDE_PLAYER, MINION_3)
	var id: int = int(card.instance_id)
	var before: int = _last_seq()

	# Act: one step, so one recompute sees both
	_engine.run_action(func() -> void:
		_engine.summon_minion(SIDE_PLAYER, WAR_DRUM, 1)
		_engine.apply_enchantment(id, {"cost_delta": -1})
	)

	# Assert: DD-X26, one event per non-empty recompute
	var events: Array = _aura_events(before)
	assert_int(events.size()).is_equal(1)
	var changes: Array = events[0].payload.changes
	assert_int(int(changes[0].entity_id)).is_equal(ally)
	assert_dict(changes.back()).is_equal(_hand_entry(id, COST_3 - 1))


func test_hand_entries_stay_left_to_right_when_an_aura_and_a_hook_move_them_together() -> void:
	# Arrange: the minion's cost moves by enchantment, the spell's by the aura
	_main_phase()
	var minion: Dictionary = _to_hand(SIDE_PLAYER, MINION_3)
	var spell: Dictionary = _to_hand(SIDE_PLAYER, SPELL_1)
	var id: int = int(minion.instance_id)
	_engine.run_action(func() -> void: _engine.summon_minion(SIDE_PLAYER, SPELL_LORD, 0))
	var before: int = _last_seq()

	# Act: the aura goes as the enchantment lands
	_engine.run_action(func() -> void:
		_engine.apply_enchantment(id, {"cost_delta": -1})
		_engine.destroy(int(_engine.state().players[SIDE_PLAYER].board[0].entity_id))
	)

	# Assert
	assert_array(_cost_entries(before)).is_equal([_hand_entry(id, COST_3 - 1), _hand_entry(int(spell.instance_id), COST_1)])


func test_a_card_that_enters_the_hand_inside_the_aura_pass_is_listed_at_its_printed_cost() -> void:
	# Arrange: the DD-X26 behaviour the `aura_passes` golden pins (`draw` scenario)
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var db: FakeCardDatabase = _db()
	_log = TestEventLog.new()
	var deck: Array = [MINION_3, MINION_3, MINION_3, MINION_3, MINION_3]
	_engine = RulesEngine.new(db, MatchFactory.make_rules_config(), resolver)
	_engine.start(MatchFactory.make_started_config(TestRngService.new(), _log, {"player": {"deck": deck}}))
	assert_bool(_engine.submit(_engine.legal_commands()[0]).accepted).is_true()
	var once: Array[bool] = [true]
	resolver.aura_scripts.append(func(e: RulesEngine) -> void:
		if once[0]:
			once[0] = false
			e.draw(SIDE_PLAYER, 1))
	var before: int = _last_seq()

	# Act
	_settle()

	# Assert
	var drawn: Dictionary = _engine.state().players[SIDE_PLAYER].hand.back()
	assert_array(_cost_entries(before)).is_equal([_hand_entry(int(drawn.instance_id), COST_3)])


# --- the ledger ----------------------------------------------------------------------

func test_a_clone_inherits_what_was_reported_and_moves_on_alone() -> void:
	# Arrange
	_main_phase([_banner()])
	_to_hand(SIDE_PLAYER, MINION_1)
	var later: Dictionary = _to_hand(SIDE_PLAYER, MINION_3)
	_settle()

	# Act: a planner clone repeats nothing already reported, then diverges
	var sandbox: RulesEngine = _engine.clone()
	sandbox.run_action(_noop)
	var repeated: int = sandbox.state().log.events_since(0).filter(func(e: Dictionary) -> bool: return str(e.type) == AURAS).size()
	assert_bool(sandbox.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0)).accepted).is_true()
	var moved: Array = sandbox.state().log.events_since(0).filter(func(e: Dictionary) -> bool: return str(e.type) == AURAS)
	sandbox.end_match()
	var before: int = _last_seq()
	_settle()

	# Assert
	assert_int(repeated).is_equal(0)
	assert_array(moved[0].payload.changes).is_equal([_hand_entry(int(later.instance_id), COST_3)])
	assert_array(_aura_events(before)).is_empty()


func test_a_clone_mulliganing_leaves_the_live_ledger_as_it_was() -> void:
	# Arrange: the one in-place write to the ledger, on a clone taken in Mulligan
	var deck: Array = [MINION_3, MINION_3, MINION_3]
	_start([_hook("treasure_test_all", &"player", ANY_FRIENDLY_CARD, CHEAPER)], {"player": {"deck": deck}})
	var sandbox: RulesEngine = _engine.clone()
	assert_bool(sandbox.submit(MatchRecords.mulligan([false, true, true])).accepted).is_true()
	sandbox.end_match()
	var before: int = _last_seq()

	# Act
	_settle()

	# Assert: the live engine still knows it reported that card
	assert_array(_aura_events(before)).is_empty()


func test_a_card_mulliganed_and_redrawn_is_reported_again() -> void:
	# Arrange: a deck the size of the hand, so the card put back is the card drawn
	var deck: Array = [MINION_3, MINION_3, MINION_3]
	_start([_hook("treasure_test_all", &"player", ANY_FRIENDLY_CARD, CHEAPER)], {"player": {"deck": deck}})
	var hand: Array = _engine.state().players[SIDE_PLAYER].hand
	assert_int(hand.size()).is_equal(deck.size())
	var replaced: int = int(hand[0].instance_id)
	var before: int = _last_seq()

	# Act: the view drops the old card and adds a bare one, so the stamp must come again
	_submit(MatchRecords.mulligan([false, true, true]))

	# Assert
	assert_array(_cost_entries(before)).contains([_hand_entry(replaced, COST_3 - 1, -1)])


# --- the point of DD-X29 -------------------------------------------------------------

## Every hand card and the hero power, projected from the log alone, against
## the engine's own answer.
func _assert_view_matches_engine(view: MatchViewState, base_power_cost: int) -> void:
	var shown: Dictionary = view.side(&"player")
	var by_id: Dictionary = {}
	for card: Dictionary in shown.hand:
		by_id[int(card.instance_id)] = card
	var db: FakeCardDatabase = _db()
	for card: Dictionary in _engine.state().players[SIDE_PLAYER].hand:
		var id: int = int(card.instance_id)
		assert_bool(by_id.has(id)).override_failure_message("card %d is not in the view" % id).is_true()
		var want: int = _engine.effective_cost(card, SIDE_PLAYER)
		var got: int = int(by_id[id].get("effective_cost", db.card(str(card.def_id)).cost))
		assert_int(got).override_failure_message("view shows %d for %s, engine says %d" % [got, card.def_id, want]).is_equal(want)
	var power: int = base_power_cost if shown.hero.power_cost == null else int(shown.hero.power_cost)
	assert_int(power).is_equal(_engine.hero_power_cost(SIDE_PLAYER))


func test_the_view_built_from_the_log_alone_agrees_with_the_engine_at_every_rest() -> void:
	# Arrange
	var deck: Array = []
	for i: int in TestConstants.STARTER_DECK_SIZE:
		deck.append([MINION_1, MINION_3, SPELL_1][i % 3])
	var grimoire: HookInstaller = _hook("treasure_test_grimoire", &"player", FRIENDLY_SPELLS, CHEAPER)
	var signet: HookInstaller = _hook("treasure_test_signet", &"player", FRIENDLY_POWER, CHEAPER, FIRST_CARD)
	_start([_banner(), grimoire, signet], {"player": {"deck": deck}, "boss": {"deck": deck}})
	_engine.state().players[SIDE_PLAYER].hero_power.def_id = POWER
	var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())
	var applied: int = 0

	# Act and assert: at every rest, whatever the commands were
	for i: int in WALK_COMMANDS:
		if _engine.state().phase == MatchState.PHASE_ENDED:
			break
		var legal: Array = _engine.legal_commands().filter(func(c: Dictionary) -> bool: return str(c.type) != MatchRecords.CMD_CONCEDE)
		_submit(legal[i % legal.size()])
		while applied < _log.events.size():
			view.apply(_log.events[applied])
			applied += 1
		_assert_view_matches_engine(view, TestConstants.HERO_POWER_COST)
