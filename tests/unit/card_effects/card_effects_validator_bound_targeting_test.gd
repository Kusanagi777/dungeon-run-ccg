## card-effects story 004 — the F6 static step bound (`EffectValidator.step_bound`,
## `E_FX_BUDGET`), the derived targeting spec (`derive_targeting_spec`, the
## resolver's memoised `targeting_spec` and `legal_targets`) and
## `E_FX_OP_TARGET` (design/gdd/card-effects.md C1 rule 1, C3 `chosen`, C10, F6;
## AC-05, AC-07; ADR-0007 Decision 8, Key Interfaces).
##
## Effect objects are JSON text parsed with `JSON.parse_string` (numbers arrive
## as floats, as the loader reads them). The validator's database is a
## lookup double (`FixtureDb`: `has`, `card`, `cards_by_type` — stage-7
## lookups); the resolver's is a `CardDatabase` subclass answering from an
## in-memory map and counting lookups. The engine is the real `RulesEngine`
## started from `MatchFactory`'s config with a `TestRngService` and
## `TestEventLog`. Caps come from `TestConstants`; no file is read.
extends GdUnitTestSuite

const SPELL_HOST: String = "knowledge_test_bolt"
## A spell host showing the `discover` display keyword (C1 rule 2).
const DISCOVER_HOST: String = "knowledge_test_study"
const MINION_HOST: String = "decay_test_sacrifice"
const POWER_HOST: String = "power_test_brand"
const PROBE: String = "neutral_test_probe"
const VANILLA: String = "neutral_test_vanilla"
const TARGETED_SPELL: String = "knowledge_test_targeted"
const UNTARGETED_SPELL: String = "knowledge_test_untargeted"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS

## C11 row 18 — "Deal 3 damage." (chosen, `kind: any`).
const ROW_18: String = '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"damage","amount":3}]}'
## C11 row 10 — "Battlecry: Destroy a friendly minion. Draw 2 cards."
const ROW_10: String = '{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"destroy"},{"op":"draw","count":2}]}'
## C11 row 34 — "At the start of your turn, deal 1 damage to a random enemy minion, twice."
const ROW_34: String = '{"trigger":"turn_start","scope":{"side":"owner"},"ops":[{"op":"repeat","times":2,"ops":[{"op":"damage","targets":"random_enemy_minion","amount":1}]}]}'


## Stage-7 lookups over a fixed record set (`has`, `card`, `cards_by_type`).
class FixtureDb:
	extends RefCounted
	var _records: Dictionary = {}

	func _init(records: Array) -> void:
		for r: Dictionary in records:
			_records[r.id] = r

	func has(id: String) -> bool:
		return _records.has(id)

	func card(id: String) -> Variant:
		return _records.get(id)

	func cards_by_type(type: String) -> Array:
		var ids: Array = _records.keys()
		ids.sort()
		var out: Array = []
		for id: Variant in ids:
			if str(_records[id].get("type", "")) == type:
				out.append(_records[id])
		return out


## A `CardDatabase` answering `has` / `card` / `hero_power` from a map and
## counting `card` + `hero_power` lookups per id.
class FakeCardDatabase:
	extends CardDatabase

	var records: Dictionary = {}
	var lookups: Dictionary = {}

	func _init(by_id: Dictionary = {}) -> void:
		records = by_id

	func has(id: String) -> bool:
		return records.has(id)

	func card(id: String) -> Variant:
		lookups[id] = int(lookups.get(id, 0)) + 1
		return records.get(id)

	func hero_power(id: String) -> Variant:
		lookups[id] = int(lookups.get(id, 0)) + 1
		return records.get(id)


## The resolver [method _main_phase] bound (one per test).
var _bound: EffectResolver = null


# --- helpers -------------------------------------------------------------------

func _caps(overrides: Dictionary = {}) -> Dictionary:
	var caps: Dictionary = {
		"max_ops_per_effect": TestConstants.MAX_OPS_PER_EFFECT,
		"max_repeat": TestConstants.MAX_REPEAT,
		"max_summon_count": TestConstants.BOARD_SIZE,
		"effect_static_step_limit": TestConstants.EFFECT_STATIC_STEP_LIMIT,
		"discover_count": TestConstants.DISCOVER_COUNT,
		# match-rules' HAND_SIZE, folded in by `EffectValidator.stage7_caps`.
		"hand_size": TestConstants.HAND_SIZE,
	}
	caps.merge(overrides, true)
	return caps


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


func _fx(json_text: String) -> Array:
	var parsed: Variant = JSON.parse_string(json_text)
	assert_bool(parsed != null).override_failure_message("fixture JSON does not parse: %s" % json_text).is_true()
	return parsed if parsed is Array else [parsed]


func _effect(json_text: String) -> Dictionary:
	return _fx(json_text)[0]


func _validator_db() -> FixtureDb:
	return FixtureDb.new([
		CardFactory.make_spell(SPELL_HOST, 1, [], {"set": "knowledge"}),
		CardFactory.make_spell(DISCOVER_HOST, 1, [], {"set": "knowledge", "keywords": ["discover"]}),
		CardFactory.make_minion(MINION_HOST, 2, 2, 2, ["battlecry"], {"set": "decay"}),
		CardFactory.make_minion(PROBE, 1, 1, 1),
		CardFactory.make_minion("decay_husk", 1, 1, 1, [], {"set": "decay", "token": true}),
		CardFactory.make_spell(TARGETED_SPELL, 1, _fx(ROW_18), {"set": "knowledge"}),
		CardFactory.make_spell(UNTARGETED_SPELL, 1, _fx('{"trigger":"cast","targets":"all_enemy_minions","ops":[{"op":"damage","amount":1}]}'), {"set": "knowledge"}),
	])


func _validate(host_id: String, json_text: String, caps: Dictionary = _caps()) -> Array:
	return EffectValidator.validate_effects(&"card", host_id, _fx(json_text), _validator_db(), caps)


func _with_code(report: Array, code: String) -> Array:
	return report.filter(func(e: Dictionary) -> bool: return str(e.code) == code)


func _assert_clean(report: Array) -> void:
	assert_array(report).override_failure_message("expected no entries, got %s" % str(report)).is_empty()


## The resolver's database: rows 18 and 10 as cards, a vanilla minion.
func _resolver_db() -> FakeCardDatabase:
	return FakeCardDatabase.new({
		SPELL_HOST: CardFactory.make_spell(SPELL_HOST, 1, _fx(ROW_18), {"set": "knowledge"}),
		MINION_HOST: CardFactory.make_minion(MINION_HOST, 1, 2, 2, ["battlecry"], {"set": "decay", "effects": _fx(ROW_10)}),
		VANILLA: CardFactory.make_minion(VANILLA, 1, 1, 1),
		POWER_HOST: CardFactory.make_hero_power_def(POWER_HOST, _fx('{"trigger":"hero_power","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"damage","amount":1}]}')),
	})


## A started engine bound to a real `EffectResolver` over [param db], past a
## keep-all mulligan (player Main, turn 1), hand replaced by [param hand].
func _main_phase(db: FakeCardDatabase, hand: Array) -> RulesEngine:
	var resolver: EffectResolver = EffectResolver.new(db, _effects_config())
	_bound = resolver
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), TestEventLog.new())
	var engine: RulesEngine = RulesEngine.new(db, MatchFactory.make_rules_config(), resolver)
	engine.start(config)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var state: MatchState = engine.state()
	var cards: Array = state.players[SIDE_PLAYER].hand
	cards.clear()
	for def_id: Variant in hand:
		cards.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))
	state.players[SIDE_PLAYER].mana_current = 10
	return engine


func _source(engine: RulesEngine, hand_index: int) -> Dictionary:
	var card: Dictionary = engine.state().players[SIDE_PLAYER].hand[hand_index]
	return {"side": SIDE_PLAYER, "source_id": int(card.instance_id), "card_id": str(card.def_id)}


# --- AC-05: F6 step bound and E_FX_BUDGET ----------------------------------------

func test_repeat_20_over_all_minions_is_e_fx_budget_with_bound_321() -> void:
	# Arrange — max_repeat 20 (its safe-range ceiling) so `times: 20` is legal
	# and E_FX_BUDGET is the only problem.
	var json: String = '{"trigger":"cast","ops":[{"op":"repeat","times":20,"ops":[{"op":"damage","targets":"all_minions","amount":1}]}]}'

	# Act
	var report: Array = _validate(SPELL_HOST, json, _caps({"max_repeat": 20}))

	# Assert
	var budget: Array = _with_code(report, "E_FX_BUDGET")
	assert_int(budget.size()).override_failure_message(str(report)).is_equal(1)
	assert_int(report.size()).override_failure_message(str(report)).is_equal(1)
	if not budget.is_empty():
		assert_str(str(budget[0].message)).contains("321")
		assert_str(str(budget[0].message)).contains("250")
		assert_str(str(budget[0].path)).is_equal("effects/0")
		assert_str(str(budget[0].effect_id)).is_equal("%s.0" % SPELL_HOST)
	assert_int(EffectValidator.step_bound(_effect(json), _caps({"max_repeat": 20}))).is_equal(321)


func test_repeat_10_over_all_minions_passes_with_bound_161() -> void:
	var json: String = '{"trigger":"cast","ops":[{"op":"repeat","times":10,"ops":[{"op":"damage","targets":"all_minions","amount":1}]}]}'

	_assert_clean(_validate(SPELL_HOST, json))
	assert_int(EffectValidator.step_bound(_effect(json), _caps())).is_equal(161)


func test_a_bound_exactly_at_the_limit_passes_and_one_over_fails() -> void:
	# Boundary: limit 161 accepts 161; limit 160 rejects it.
	var json: String = '{"trigger":"cast","ops":[{"op":"repeat","times":10,"ops":[{"op":"damage","targets":"all_minions","amount":1}]}]}'

	_assert_clean(_validate(SPELL_HOST, json, _caps({"effect_static_step_limit": 161})))
	assert_int(_with_code(_validate(SPELL_HOST, json, _caps({"effect_static_step_limit": 160})), "E_FX_BUDGET").size()).is_equal(1)


func test_step_bound_of_row_34_is_3() -> void:
	assert_int(EffectValidator.step_bound(_effect(ROW_34), _caps())).is_equal(3)


func test_a_non_literal_summon_count_is_taken_at_max_summon_count() -> void:
	# Raise Dead: count = owner.minions_died_this_turn → MAX_SUMMON_COUNT (7).
	var json: String = '{"trigger":"cast","ops":[{"op":"summon","card_id":"decay_husk","count":{"ref":"owner.minions_died_this_turn"}}]}'

	assert_int(EffectValidator.step_bound(_effect(json), _caps())).is_equal(1 + TestConstants.BOARD_SIZE)
	assert_int(EffectValidator.step_bound(_effect(json), _caps({"max_summon_count": 3}))).is_equal(4)


func test_a_non_literal_times_is_taken_at_max_repeat() -> void:
	var json: String = '{"trigger":"cast","ops":[{"op":"repeat","times":{"ref":"owner.hand_size"},"ops":[{"op":"damage","targets":"enemy_hero","amount":1}]}]}'

	assert_int(EffectValidator.step_bound(_effect(json), _caps())).is_equal(1 + TestConstants.MAX_REPEAT)


func test_any_other_non_literal_is_taken_at_hand_size() -> void:
	# A `draw` count and a random selector's `n`, both value expressions → HAND_SIZE.
	var draw: String = '{"trigger":"cast","ops":[{"op":"draw","count":{"ref":"owner.board_size"}}]}'
	var pings: String = '{"trigger":"cast","ops":[{"op":"damage","targets":{"selector":"random_enemy_minion","n":{"ref":"opponent.board_size"}},"amount":1}]}'

	assert_int(EffectValidator.step_bound(_effect(draw), _caps())).is_equal(1 + TestConstants.HAND_SIZE)
	assert_int(EffectValidator.step_bound(_effect(pings), _caps())).is_equal(1 + TestConstants.HAND_SIZE)
	assert_int(EffectValidator.step_bound(_effect(draw), _caps({"hand_size": 6}))).is_equal(7)


func test_conditional_takes_the_larger_branch() -> void:
	# then: one op over all_minions (16); else: two single-target ops (2).
	var json: String = '{"trigger":"cast","ops":[{"op":"conditional","if":{"exists":"owner_weapon"},"then":[{"op":"damage","targets":"all_minions","amount":1}],"else":[{"op":"damage","targets":"enemy_hero","amount":1},{"op":"heal","targets":"owner_hero","amount":1}]}]}'
	var flipped: String = '{"trigger":"cast","ops":[{"op":"conditional","if":{"exists":"owner_weapon"},"then":[{"op":"damage","targets":"enemy_hero","amount":1}],"else":[{"op":"damage","targets":"all_minions","amount":1},{"op":"heal","targets":"owner_hero","amount":1}]}]}'

	assert_int(EffectValidator.step_bound(_effect(json), _caps())).is_equal(17)
	assert_int(EffectValidator.step_bound(_effect(flipped), _caps())).is_equal(18)


func test_choose_one_takes_the_largest_option() -> void:
	var json: String = '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"choose_one","options":[{"label_key":"opt.a","ops":[{"op":"damage","amount":2}]},{"label_key":"opt.b","ops":[{"op":"damage","targets":"all_enemy_characters","amount":1},{"op":"draw","count":2}]}]}]}'

	assert_int(EffectValidator.step_bound(_effect(json), _caps())).is_equal(1 + 16 + 2)


func test_max_targets_follow_the_f6_table() -> void:
	# adjacent 2, hand 10 (HAND_SIZE), side-scoped 1, single 1, all_* 16,
	# random n → n; an op-level `targets` overrides the effect's.
	var json: String = '{"trigger":"battlecry","targets":"all_friendly_minions","ops":[{"op":"buff","targets":"adjacent","attack":1},{"op":"buff","targets":"hand","cost":-1},{"op":"armor","amount":1},{"op":"heal","targets":"owner_hero","amount":1},{"op":"buff","attack":1},{"op":"damage","targets":{"selector":"random_enemy_character","n":3},"amount":1}]}'

	assert_int(EffectValidator.step_bound(_effect(json), _caps())).is_equal(1 + 2 + TestConstants.HAND_SIZE + 1 + 1 + 16 + 3)


func test_a_bound_needing_hand_size_without_it_in_caps_fails_closed() -> void:
	# The `card_effects` body alone has no HAND_SIZE (match-rules' knob): the
	# bound cannot be computed, which is reported, never passed.
	var json: String = '{"trigger":"cast","ops":[{"op":"buff","targets":"hand","cost":-1}]}'
	var caps: Dictionary = _caps()
	caps.erase("hand_size")

	var report: Array = _validate(SPELL_HOST, json, caps)

	assert_int(EffectValidator.step_bound(_effect(json), caps)).is_equal(-1)
	var budget: Array = _with_code(report, "E_FX_BUDGET")
	assert_int(budget.size()).override_failure_message(str(report)).is_equal(1)
	if not budget.is_empty():
		assert_str(str(budget[0].message)).contains("hand_size")


func test_stage7_caps_fold_match_rules_hand_size_into_the_card_effects_body() -> void:
	# Arrange — frozen bodies, as stage 7b passes them.
	var effects_body: Dictionary = _effects_config()
	effects_body.make_read_only()
	var rules_body: Dictionary = MatchFactory.make_rules_config()

	# Act
	var caps: Dictionary = EffectValidator.stage7_caps({"card_effects": effects_body, "match_rules": rules_body})
	var without_rules: Dictionary = EffectValidator.stage7_caps({"card_effects": effects_body})

	# Assert — every knob kept, hand_size added; the frozen body is untouched
	for key: String in effects_body:
		assert_that(caps.get(key)).is_equal(effects_body[key])
	assert_int(int(caps.get("hand_size", -1))).is_equal(TestConstants.HAND_SIZE)
	assert_bool(effects_body.has("hand_size")).is_false()
	assert_bool(without_rules.has("hand_size")).is_false()
	assert_int(without_rules.size()).is_equal(effects_body.size())


# --- AC-07: derived targeting_spec, legal_targets, legal_commands ----------------

func test_row_18_targeting_spec_is_required_with_kind_any() -> void:
	var spec: Dictionary = EffectValidator.derive_targeting_spec(_fx(ROW_18))

	assert_dict(spec).is_equal({"mode": "required", "filter": {"kind": "any"}})


func test_an_optional_chosen_is_mode_optional() -> void:
	var spec: Dictionary = EffectValidator.derive_targeting_spec(_fx('{"trigger":"battlecry","targets":{"selector":"chosen","optional":true,"filter":{"kind":"minion"}},"ops":[{"op":"damage","amount":1}]}'))

	assert_dict(spec).is_equal({"mode": "optional", "filter": {"kind": "minion"}})


func test_a_host_without_a_play_chosen_is_mode_none() -> void:
	var none: Dictionary = EffectValidator.derive_targeting_spec(_fx('{"trigger":"cast","targets":"all_enemy_characters","ops":[{"op":"damage","amount":2}]}'))
	var empty: Dictionary = EffectValidator.derive_targeting_spec([])
	# `chosen` under a non-play trigger is E_FX_CHOSEN, never a targeting spec.
	var non_play: Dictionary = EffectValidator.derive_targeting_spec(_fx('{"trigger":"deathrattle","targets":{"selector":"chosen"},"ops":[{"op":"damage","amount":1}]}'))
	var bare: Dictionary = EffectValidator.derive_targeting_spec(_fx('{"trigger":"hero_power","targets":"chosen","ops":[{"op":"damage","amount":1}]}'))

	assert_dict(none).is_equal({"mode": "none", "filter": {}})
	assert_dict(empty).is_equal({"mode": "none", "filter": {}})
	assert_dict(non_play).is_equal({"mode": "none", "filter": {}})
	assert_dict(bare).is_equal({"mode": "required", "filter": {}})


func test_targeting_modes_are_the_engine_spellings() -> void:
	assert_str(EffectSchema.TARGETING_NONE).is_equal(RulesEngine.TARGETING_NONE)
	assert_str(EffectSchema.TARGETING_OPTIONAL).is_equal(RulesEngine.TARGETING_OPTIONAL)
	assert_str(EffectSchema.TARGETING_REQUIRED).is_equal(RulesEngine.TARGETING_REQUIRED)


func test_resolver_targeting_spec_is_the_derivation_memoised_per_def_id() -> void:
	# Arrange
	var db: FakeCardDatabase = _resolver_db()
	var resolver: EffectResolver = EffectResolver.new(db, _effects_config())

	# Act
	var first: Dictionary = resolver.targeting_spec(SPELL_HOST)
	var second: Dictionary = resolver.targeting_spec(SPELL_HOST)
	var power: Dictionary = resolver.targeting_spec(POWER_HOST)
	var vanilla: Dictionary = resolver.targeting_spec(VANILLA)
	var effects: Array = resolver.effects_of(SPELL_HOST)

	# Assert — one lookup per def_id (a hero power through `hero_power`), the same Dictionary
	assert_dict(first).is_equal(EffectValidator.derive_targeting_spec(_fx(ROW_18)))
	assert_bool(is_same(first, second)).is_true()
	assert_str(str(power.mode)).is_equal("required")
	assert_dict(vanilla).is_equal({"mode": "none", "filter": {}})
	assert_int(effects.size()).is_equal(1)
	assert_dict(db.lookups).is_equal({SPELL_HOST: 1, POWER_HOST: 1, VANILLA: 1})


func test_a_def_id_the_database_lacks_has_no_targeting_and_is_not_looked_up() -> void:
	var db: FakeCardDatabase = _resolver_db()
	var resolver: EffectResolver = EffectResolver.new(db, _effects_config())

	assert_dict(resolver.targeting_spec("neutral_test_missing")).is_equal({"mode": "none", "filter": {}})
	assert_bool(db.lookups.has("neutral_test_missing")).is_false()


func test_row_18_legal_targets_are_non_stealth_enemies_and_all_friendlies_in_canonical_order() -> void:
	# Arrange — friendly: a 1/1 and a Stealth 1/1; enemy: a 2/2, a Stealth 2/2, a 3/3.
	var engine: RulesEngine = _main_phase(_resolver_db(), [SPELL_HOST])
	var state: MatchState = engine.state()
	var f1: int = int(MatchFactory.summon(state, SIDE_PLAYER, 1, 1).entity_id)
	var f_stealth: int = int(MatchFactory.summon(state, SIDE_PLAYER, 1, 1, -1, ["stealth"]).entity_id)
	var e1: int = int(MatchFactory.summon(state, SIDE_BOSS, 2, 2).entity_id)
	var e_stealth: int = int(MatchFactory.summon(state, SIDE_BOSS, 2, 2, -1, ["stealth"]).entity_id)
	var e3: int = int(MatchFactory.summon(state, SIDE_BOSS, 3, 3).entity_id)
	var player_hero: int = int(state.players[SIDE_PLAYER].hero.entity_id)
	var boss_hero: int = int(state.players[SIDE_BOSS].hero.entity_id)

	# Act
	var legal: Array[int] = _bound.legal_targets(SPELL_HOST, _source(engine, 0))

	# Assert — player board L→R, boss board L→R, player hero, boss hero; no enemy Stealth
	assert_array(legal).is_equal([f1, f_stealth, e1, e3, player_hero, boss_hero])
	assert_bool(legal.has(e_stealth)).is_false()


func test_stealth_granted_by_an_enchantment_also_protects_an_enemy() -> void:
	var engine: RulesEngine = _main_phase(_resolver_db(), [SPELL_HOST])
	var state: MatchState = engine.state()
	var enemy: Dictionary = MatchFactory.summon(state, SIDE_BOSS, 2, 2)
	(enemy.enchantments as Array).append(MatchFactory.make_enchantment(0, 0, ["stealth"]))

	var legal: Array[int] = _bound.legal_targets(SPELL_HOST, _source(engine, 0))

	assert_bool(legal.has(int(enemy.entity_id))).is_false()


func test_row_10_on_an_empty_friendly_board_has_no_legal_target_and_is_still_playable() -> void:
	# Arrange — an enemy minion exists; no friendly minion.
	var engine: RulesEngine = _main_phase(_resolver_db(), [MINION_HOST])
	MatchFactory.summon(engine.state(), SIDE_BOSS, 2, 2)
	var resolver: EffectResolver = _bound

	# Act
	var legal: Array[int] = resolver.legal_targets(MINION_HOST, _source(engine, 0))
	var commands: Array = engine.legal_commands()

	# Assert — no target; the minion is listed (target_id null) at position 0
	assert_array(legal).is_empty()
	assert_dict(resolver.targeting_spec(MINION_HOST)).is_equal({"mode": "required", "filter": {"kind": "minion", "side": "friendly"}})
	var plays: Array = commands.filter(func(c: Dictionary) -> bool: return c.type == MatchRecords.CMD_PLAY_CARD)
	assert_array(plays).is_equal([MatchRecords.play_card(SIDE_PLAYER, 0, 0, null)])


func test_row_10_with_a_friendly_minion_lists_it_as_the_only_target() -> void:
	var engine: RulesEngine = _main_phase(_resolver_db(), [MINION_HOST])
	var friend: int = int(MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1).entity_id)
	MatchFactory.summon(engine.state(), SIDE_BOSS, 2, 2)

	var legal: Array[int] = _bound.legal_targets(MINION_HOST, _source(engine, 0))

	assert_array(legal).is_equal([friend])


func test_a_dying_minion_is_never_a_legal_target() -> void:
	var engine: RulesEngine = _main_phase(_resolver_db(), [MINION_HOST])
	var friend: Dictionary = MatchFactory.summon(engine.state(), SIDE_PLAYER, 1, 1)
	friend["pending_destroy"] = true

	assert_array(_bound.legal_targets(MINION_HOST, _source(engine, 0))).is_empty()


func test_legal_targets_of_a_def_without_chosen_is_empty() -> void:
	var engine: RulesEngine = _main_phase(_resolver_db(), [VANILLA])
	MatchFactory.summon(engine.state(), SIDE_BOSS, 2, 2)

	assert_array(_bound.legal_targets(VANILLA, _source(engine, 0))).is_empty()


# --- AC-3: E_FX_OP_TARGET ----------------------------------------------------------

func test_freeze_on_hand_is_e_fx_op_target() -> void:
	var report: Array = _validate(SPELL_HOST, '{"trigger":"cast","ops":[{"op":"freeze","targets":"hand"}]}')

	var target: Array = _with_code(report, "E_FX_OP_TARGET")
	assert_int(target.size()).override_failure_message(str(report)).is_equal(1)
	if not target.is_empty():
		assert_str(str(target[0].path)).is_equal("effects/0/ops/0/targets")


func test_an_op_inheriting_an_illegal_effect_level_selector_is_e_fx_op_target() -> void:
	# `silence` needs minions; the effect's `owner_hero` can never be one.
	var report: Array = _validate(SPELL_HOST, '{"trigger":"cast","targets":"owner_hero","ops":[{"op":"heal","amount":2},{"op":"silence"}]}')

	var target: Array = _with_code(report, "E_FX_OP_TARGET")
	assert_int(target.size()).override_failure_message(str(report)).is_equal(1)
	if not target.is_empty():
		assert_str(str(target[0].path)).is_equal("effects/0/ops/1")


func test_a_chosen_filter_narrowing_to_heroes_rules_out_a_minion_op() -> void:
	var report: Array = _validate(SPELL_HOST, '{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"hero"}},"ops":[{"op":"destroy"}]}')

	assert_int(_with_code(report, "E_FX_OP_TARGET").size()).override_failure_message(str(report)).is_equal(1)


func test_a_targeted_op_with_no_selector_at_all_is_e_fx_op_target() -> void:
	var report: Array = _validate(SPELL_HOST, '{"trigger":"cast","ops":[{"op":"damage","amount":2}]}')

	assert_int(_with_code(report, "E_FX_OP_TARGET").size()).override_failure_message(str(report)).is_equal(1)


func test_legal_selector_and_op_pairs_are_clean() -> void:
	# Side-scoped ops ignore the effect-level `chosen` (row 10's `draw`); `buff`
	# reaches weapons and card instances; `trigger_subject` may be anything.
	_assert_clean(_validate(MINION_HOST, ROW_10))
	_assert_clean(_validate(SPELL_HOST, '{"trigger":"cast","ops":[{"op":"buff","targets":{"selector":"deck_top","n":1},"cost":1},{"op":"draw","count":1},{"op":"buff","targets":"owner_weapon","attack":1}]}'))
	_assert_clean(_validate(SPELL_HOST, '{"trigger":"cast","ops":[{"op":"shuffle_into_deck","card_id":"neutral_test_probe"}]}'))


func test_discover_then_cast_over_a_list_with_a_targeted_spell_is_e_fx_op_target() -> void:
	var targeted: Array = _validate(DISCOVER_HOST, '{"trigger":"cast","ops":[{"op":"discover","pool":"list","list":["%s","%s"],"then":"cast"}]}' % [UNTARGETED_SPELL, TARGETED_SPELL])
	var untargeted: Array = _validate(DISCOVER_HOST, '{"trigger":"cast","ops":[{"op":"discover","pool":"list","list":["%s"],"then":"cast"}]}' % UNTARGETED_SPELL)
	var to_hand: Array = _validate(DISCOVER_HOST, '{"trigger":"cast","ops":[{"op":"discover","pool":"list","list":["%s"]}]}' % TARGETED_SPELL)

	var codes: Array = _with_code(targeted, "E_FX_OP_TARGET")
	assert_int(codes.size()).override_failure_message(str(targeted)).is_equal(1)
	if not codes.is_empty():
		assert_str(str(codes[0].message)).contains(TARGETED_SPELL)
	_assert_clean(untargeted)
	_assert_clean(to_hand)


func test_discover_then_cast_over_the_filtered_load_time_pool_is_checked() -> void:
	# The collectible pool's spells after the filter: cost 1 knowledge spells
	# include the targeted one; a filter excluding it (set war) is clean.
	var report: Array = _validate(DISCOVER_HOST, '{"trigger":"cast","ops":[{"op":"discover","pool":"collectible","filter":{"set":"knowledge"},"then":"cast"}]}')
	var none_left: Array = _validate(DISCOVER_HOST, '{"trigger":"cast","ops":[{"op":"discover","pool":"collectible","filter":{"set":"war"},"then":"cast"}]}')

	assert_int(_with_code(report, "E_FX_OP_TARGET").size()).override_failure_message(str(report)).is_equal(1)
	_assert_clean(none_left)
