## Unit tests for effective cost, mana payment and temporary crystals (story
## match-rules/story-011; design/gdd/match-rules.md C5 Mana and costs, F1
## Effective cost, C4 End step 5, Interactions `modify_cost`; ADR-0005
## Decision 4 — the `modify_cost` fold, clamped once at 0 after the chain).
##
## Matches start through `MatchFactory.make_started_engine` and a "keep all"
## mulligan (turn 1, player Main). Each test replaces the player's hand with
## fixture cards and sets the mana fields (fixture moves). `modify_cost` hooks
## are `HookInstaller`s whose effects carry card-effects C5 `modify_value`
## ops, which `TestEffectResolver.apply_value_hook` applies without clamping.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
const MARKER: StringName = &"test_battlecry_marker"
## Fixture definitions (CR-2-valid ids) and their printed costs.
const DEF_TWO: String = "neutral_test_two_drop"
const TWO_COST: int = 2
const DEF_FOUR: String = "neutral_test_four_spell"
const FOUR_COST: int = 4
const DEF_ONE: String = "neutral_test_one_spell"
const ONE_COST: int = 1
const DEF_POWER: String = "power_test"
## AC-08's numbers: a −2 card enchantment and a −3 `modify_cost` hook.
const ENCHANT_DELTA: int = -2
const HOOK_DELTA: int = -3
## A hand-scoped aura's cost delta (already in `cost_modifiers`, tagged `is_aura`).
const AURA_DELTA: int = -1
## AC-07 / AC-45 mana fixtures.
const MANA_THREE: int = 3
const TEMP_GAIN: int = 2


class FixtureDb extends RefCounted:
	var cards: Dictionary = {}

	func has(id: String) -> bool:
		return cards.has(id)

	func card(id: String) -> Variant:
		return cards.get(id)


# --- helpers -----------------------------------------------------------------

func _db() -> FixtureDb:
	var db: FixtureDb = FixtureDb.new()
	db.cards[DEF_TWO] = CardFactory.make_minion(DEF_TWO, TWO_COST, 2, 2, ["battlecry"])
	db.cards[DEF_FOUR] = CardFactory.make_spell(DEF_FOUR, FOUR_COST)
	db.cards[DEF_ONE] = CardFactory.make_spell(DEF_ONE, ONE_COST)
	return db


## A player treasure whose `modify_cost` effects carry one `modify_value` op
## each — [param ops] is a list of op field dictionaries (`{delta: n}` /
## `{set: n}`), in installation order.
func _cost_hooks(host_id: String, ops: Array) -> HookInstaller:
	var effects: Array[Dictionary] = []
	for i: int in ops.size():
		var op: Dictionary = {"op": TestEffectResolver.OP_MODIFY_VALUE}
		op.merge(ops[i])
		effects.append({
			"id": "%s.%d" % [host_id, i], "trigger": "modify_cost", "scope": {},
			"condition": {}, "ops": [op], "once_per_turn": false,
		})
	return HookInstaller.new(HookInstaller.HOST_KIND_TREASURE, host_id, StringName(SIDE_PLAYER), effects, {})


## A started engine past the mulligan with the player's hand replaced by
## [param hand] (def ids) and mana set to [param current] / [param max_mana].
func _engine(log: TestEventLog, resolver: TestEffectResolver, hand: Array, current: int, max_mana: int, installers: Array = []) -> RulesEngine:
	var overrides: Dictionary = {"player": {"hook_installers": installers}}
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, overrides, {}, resolver, _db())
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var state: MatchState = engine.state()
	var cards: Array = state.players[SIDE_PLAYER].hand
	cards.clear()
	for def_id: Variant in hand:
		cards.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))
	state.players[SIDE_PLAYER].mana_current = current
	state.players[SIDE_PLAYER].mana_max = max_mana
	state.players[SIDE_PLAYER].hero_power.def_id = DEF_POWER
	return engine


func _player(engine: RulesEngine, side: String = SIDE_PLAYER) -> Dictionary:
	return engine.state().players[side]


func _types_after(log: TestEventLog, before: int, types: Array) -> Array[String]:
	var out: Array[String] = []
	for event: Dictionary in log.events.slice(before):
		if types.has(String(event.type)):
			out.append(String(event.type))
	return out


func _mark(engine: RulesEngine, _ctx: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	engine.emit(MARKER, {})


func _has_command(engine: RulesEngine, type: String) -> bool:
	for command: Dictionary in engine.legal_commands():
		if str(command.type) == type:
			return true
	return false


# --- AC-07: payment ------------------------------------------------------------

func test_a_two_cost_card_at_three_mana_leaves_one_and_pays_before_any_effect() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.scripts[&"battlecry"] = [_mark]
	var engine: RulesEngine = _engine(log, resolver, [DEF_TWO], MANA_THREE, MANA_THREE)
	var before: int = log.events.size()

	# Act
	var result: Dictionary = engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))

	# Assert
	assert_bool(result.accepted).is_true()
	assert_int(int(_player(engine).mana_current)).is_equal(MANA_THREE - TWO_COST)
	assert_array(_types_after(log, before, ["mana_spent", String(MARKER)])).is_equal(["mana_spent", String(MARKER)])
	EventLogAssertions.assert_payload(log.events.slice(before), &"mana_spent", {"amount": TWO_COST})


func test_a_battlecry_with_no_legal_target_still_costs_its_mana() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	resolver.specs_by_def[DEF_TWO] = {"mode": RulesEngine.TARGETING_REQUIRED, "filter": {}}
	resolver.targets_by_def[DEF_TWO] = []
	var engine: RulesEngine = _engine(log, resolver, [DEF_TWO], MANA_THREE, MANA_THREE)

	# Act
	var result: Dictionary = engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null))

	# Assert — the body is played, the Battlecry never fires, nothing refunded
	assert_bool(result.accepted).is_true()
	assert_int(int(_player(engine).mana_current)).is_equal(MANA_THREE - TWO_COST)
	assert_int(EventLogAssertions.count_type(log, &"mana_added")).is_zero()


# --- AC-08: F1 -----------------------------------------------------------------

func test_effective_cost_folds_enchantment_then_hook_and_clamps_once_at_zero() -> void:
	# Arrange — 4-cost card, −2 enchantment, −3 hook: max(0, 4 − 2 − 3) = 0
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, [DEF_FOUR], 0, MANA_THREE, [_cost_hooks("treasure_test_discount", [{"delta": HOOK_DELTA}])])
	var card: Dictionary = _player(engine).hand[0]
	card.cost_modifiers.append({"cost_delta": ENCHANT_DELTA})
	resolver.hook_calls.clear()

	# Act
	var cost: int = engine.effective_cost(card, SIDE_PLAYER)

	# Assert — the hook saw the enchanted cost (4 − 2) as its input, the clamp came after
	assert_int(cost).is_zero()
	assert_array(resolver.fold_inputs(&"modify_cost")).is_equal([FOUR_COST + ENCHANT_DELTA])


func test_a_card_whose_effective_cost_is_zero_is_playable_at_zero_mana() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, [DEF_FOUR], 0, MANA_THREE, [_cost_hooks("treasure_test_discount", [{"delta": HOOK_DELTA}])])
	(_player(engine).hand[0] as Dictionary).cost_modifiers.append({"cost_delta": ENCHANT_DELTA})
	var before: int = log.events.size()

	# Act
	var listed: bool = _has_command(engine, MatchRecords.CMD_PLAY_CARD)
	var result: Dictionary = engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, null, null))

	# Assert — never below 0, never refunded
	assert_bool(listed).is_true()
	assert_bool(result.accepted).is_true()
	assert_int(int(_player(engine).mana_current)).is_zero()
	EventLogAssertions.assert_payload(log.events.slice(before), &"mana_spent", {"amount": 0})


func test_cost_hooks_fold_in_installation_order_with_no_clamp_between_entries() -> void:
	# Arrange — 1-cost card, hooks −3 then +2: a clamp between entries would give 2
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var hooks: HookInstaller = _cost_hooks("treasure_test_chain", [{"delta": -3}, {"delta": 2}])
	var engine: RulesEngine = _engine(log, resolver, [DEF_ONE], 0, MANA_THREE, [hooks])
	var card: Dictionary = _player(engine).hand[0]
	resolver.hook_calls.clear()

	# Act
	var cost: int = engine.effective_cost(card, SIDE_PLAYER)

	# Assert
	assert_int(cost).is_zero()
	assert_array(resolver.fold_inputs(&"modify_cost")).is_equal([ONE_COST, ONE_COST - 3])


func test_a_set_hook_then_a_delta_hook_apply_in_installation_order() -> void:
	# Arrange — set 0 then +1 is 1; the reverse order would be 0
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var hooks: HookInstaller = _cost_hooks("treasure_test_order", [{"set": 0}, {"delta": 1}])
	var engine: RulesEngine = _engine(log, resolver, [DEF_FOUR], 0, MANA_THREE, [hooks])

	# Act
	var cost: int = engine.effective_cost(_player(engine).hand[0], SIDE_PLAYER)

	# Assert
	assert_int(cost).is_equal(1)


func test_a_hand_aura_modifier_is_counted_once_before_the_hooks() -> void:
	# Arrange — enchantment −2 and an `is_aura` hand modifier −1 on a 4-cost card
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, [DEF_FOUR], 0, MANA_THREE, [_cost_hooks("treasure_test_seen", [{"delta": 0}])])
	var card: Dictionary = _player(engine).hand[0]
	card.cost_modifiers.append({"cost_delta": ENCHANT_DELTA})
	card.cost_modifiers.append({"cost_delta": AURA_DELTA, "is_aura": true})
	resolver.hook_calls.clear()

	# Act
	var cost: int = engine.effective_cost(card, SIDE_PLAYER)

	# Assert
	assert_int(cost).is_equal(FOUR_COST + ENCHANT_DELTA + AURA_DELTA)
	assert_array(resolver.fold_inputs(&"modify_cost")).is_equal([FOUR_COST + ENCHANT_DELTA + AURA_DELTA])


func test_the_cost_fold_context_names_the_card_and_its_kind() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, [DEF_FOUR], 0, MANA_THREE, [_cost_hooks("treasure_test_seen", [{"delta": 0}])])
	var card: Dictionary = _player(engine).hand[0]
	resolver.hook_calls.clear()

	# Act
	@warning_ignore("return_value_discarded")
	engine.effective_cost(card, SIDE_PLAYER)
	@warning_ignore("return_value_discarded")
	engine.hero_power_cost(SIDE_PLAYER)

	# Assert
	assert_int(resolver.hook_calls.size()).is_equal(2)
	var card_ctx: Dictionary = resolver.hook_calls[0].ctx
	assert_str(str(card_ctx.kind)).is_equal(RulesEngine.COST_KIND_CARD)
	assert_int(int(card_ctx.card.instance_id)).is_equal(int(card.instance_id))
	var power_ctx: Dictionary = resolver.hook_calls[1].ctx
	assert_str(str(power_ctx.kind)).is_equal(RulesEngine.COST_KIND_HERO_POWER)
	assert_str(str(power_ctx.card.def_id)).is_equal(DEF_POWER)


func test_the_hero_power_cost_goes_through_the_same_fold() -> void:
	# Arrange — `set 0` (Worn Signet's shape): usable at 0 mana, still pays 0
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, [], 0, MANA_THREE, [_cost_hooks("treasure_test_signet", [{"set": 0}])])
	var before: int = log.events.size()

	# Act
	var listed: bool = _has_command(engine, MatchRecords.CMD_USE_HERO_POWER)
	var result: Dictionary = engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER, null))

	# Assert
	assert_int(engine.hero_power_cost(SIDE_PLAYER)).is_zero()
	assert_bool(listed).is_true()
	assert_bool(result.accepted).is_true()
	assert_int(int(_player(engine).mana_current)).is_zero()
	EventLogAssertions.assert_payload(log.events.slice(before), &"mana_spent", {"amount": 0})


func test_a_raised_hero_power_cost_is_not_payable_at_the_printed_cost() -> void:
	# Arrange — `delta +1`: 2 + 1 = 3 with 2 mana available
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, [], TestConstants.HERO_POWER_COST, MANA_THREE, [_cost_hooks("treasure_test_tax", [{"delta": 1}])])

	# Act
	var listed: bool = _has_command(engine, MatchRecords.CMD_USE_HERO_POWER)
	var result: Dictionary = engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER, null))

	# Assert
	assert_int(engine.hero_power_cost(SIDE_PLAYER)).is_equal(TestConstants.HERO_POWER_COST + 1)
	assert_bool(listed).is_false()
	assert_bool(result.accepted).is_false()
	assert_str(str(result.rejection.code)).is_equal(RulesEngine.R_NOT_ENOUGH_MANA)


# --- AC-45: temporary crystals -------------------------------------------------

func test_temporary_mana_raises_max_and_current_and_expires_at_the_end_step() -> void:
	# Arrange — player Main on turn 3 at 1/3 (three own turns taken)
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, [], 1, MANA_THREE)
	var player: Dictionary = _player(engine)
	player.turns_taken = MANA_THREE
	var at_turn_ended: Array = []
	log.subscribe(func(event: Dictionary) -> void:
		if event.type == &"turn_ended" and event.payload.side == SIDE_PLAYER:
			at_turn_ended.append([int(player.mana_max), int(player.mana_current)]))
	var before: int = log.events.size()

	# Act 1 — the effect grants two temporary crystals
	engine.run_action(func() -> void: engine.add_mana(SIDE_PLAYER, TEMP_GAIN, true))

	# Assert 1
	EventLogAssertions.assert_payload(log.events.slice(before), &"mana_added", {"side": SIDE_PLAYER, "n": TEMP_GAIN, "temporary": true})
	assert_int(int(player.mana_current)).is_equal(1 + TEMP_GAIN)
	assert_int(int(player.mana_max)).is_equal(MANA_THREE + TEMP_GAIN)
	assert_int(int(player.crystal_bonus)).is_zero()

	# Act 2 — the player's End step, then the boss's turn
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Assert 2 — back to 3 crystals before turn_ended, no crystal_gained for the player
	assert_array(at_turn_ended).is_equal([[MANA_THREE, 1]])
	for event: Dictionary in log.events.slice(before):
		if event.type == &"crystal_gained":
			assert_str(str(event.payload.side)).is_not_equal(SIDE_PLAYER)
	assert_int(int(player.temporary_crystals)).is_zero()

	# Act 3 — the boss ends its turn; the player's Start step refills (F4)
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()

	# Assert 3
	assert_int(int(player.mana_max)).is_equal(MANA_THREE + 1)
	assert_int(int(player.mana_current)).is_equal(MANA_THREE + 1)
	assert_int(int(player.crystal_bonus)).is_zero()


func test_temporary_mana_is_clamped_to_max_mana() -> void:
	# Arrange — 9/10
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var full: int = TestConstants.MAX_MANA_CRYSTALS
	var engine: RulesEngine = _engine(log, resolver, [], full - 1, full)
	var player: Dictionary = _player(engine)

	# Act
	engine.run_action(func() -> void: engine.add_mana(SIDE_PLAYER, TEMP_GAIN, true))

	# Assert — 10/10, never over mana_max; nothing to expire
	assert_int(int(player.mana_current)).is_equal(full)
	assert_int(int(player.mana_max)).is_equal(full)
	assert_int(int(player.temporary_crystals)).is_zero()

	# Act 2 — the End step leaves the clamped pool alone
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Assert 2
	assert_int(int(player.mana_max)).is_equal(full)


func test_temporary_crystals_granted_on_the_opponents_turn_never_cut_mana_below_f4() -> void:
	# Arrange — a real match past the mulligan: player turn 1 (1/1), then the
	# boss's turn 1 (code review MR-011 S5, probe P4)
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {}, {}, resolver, _db())
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var player: Dictionary = _player(engine)
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Act 1 — on the boss's turn the player gains two temporary crystals
	engine.run_action(func() -> void: engine.add_mana(SIDE_PLAYER, TEMP_GAIN, true))
	assert_int(int(player.mana_max)).is_equal(1 + TEMP_GAIN)

	# Act 2 — the player's turn 2 Start step refills by F4: the off-turn
	# crystals are gone and none stay recorded for a later expiry
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()

	# Assert 2 — F4 for turns_taken 2
	assert_int(int(player.mana_max)).is_equal(2)
	assert_int(int(player.mana_current)).is_equal(2)
	assert_int(int(player.temporary_crystals)).is_zero()

	# Act 3 — the player's End step, then the boss's turn and the player's turn 3
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Assert 3 — the End step took nothing back (P4: 0/0, below F4's 2)
	assert_int(int(player.mana_max)).is_equal(2)
	var before: int = log.events.size()
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()
	EventLogAssertions.assert_payload(log.events.slice(before), &"crystal_gained", {"side": SIDE_PLAYER, "mana_max": 3, "gained": 1})
	assert_int(int(player.mana_current)).is_equal(3)


func test_temporary_crystals_cannot_take_current_mana_below_zero_at_expiry() -> void:
	# Arrange — 0/3, +2 temporary, then all of it spent
	var log: TestEventLog = TestEventLog.new()
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var engine: RulesEngine = _engine(log, resolver, [DEF_TWO], 0, MANA_THREE)
	var player: Dictionary = _player(engine)
	engine.run_action(func() -> void: engine.add_mana(SIDE_PLAYER, TEMP_GAIN, true))
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0, null)).accepted).is_true()

	# Act
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()

	# Assert
	assert_int(int(player.mana_max)).is_equal(MANA_THREE)
	assert_int(int(player.mana_current)).is_zero()
