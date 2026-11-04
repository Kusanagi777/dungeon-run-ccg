## Unit: the Content validator's F1-F5 checks (content story 008; content.md
## CN-6 step 3, F1 Set composition, F2 Curve targets, F3 Vanilla stat budget,
## F5 Coverage check, AC-4/5/7/9/21; heroes.md F1, F4, Edge Cases
## `W_HERO_HEALTH`).
##
## Most cases build a pool view in-test with `CardFactory` (the
## [method ContentValidator.pool_of] shape: `{cards, heroes, bosses, treasures,
## bundles, match_rules}`) and call one `check_*` with config bodies built by
## [method _budgets] / [method _heroes_balance] (the content.md / heroes.md
## defaults). The fixture roots `content_checks_base/` and
## `content_checks_knobs/` hold the same records and differ only in two
## `content_budgets.json` knobs (`text_max_chars` 90 → 80, `curve.bucket_tol`
## 0.08 → 0.15): AC-4 loads both through a real `CardDatabase` and shows the
## knob, not the code, decides the outcome; the command tests run
## `ContentValidateCommand.run` over them. No test reads `assets/data/`.
## Boundary values (90 / 91 characters) are the point and stay inline.
extends GdUnitTestSuite

const FIXTURES: String = "res://tests/fixtures/data/"
## War hero, 8 War + 6 neutral cards, F1 starter and F1 shares conforming,
## one 85-character card text; shipped-default `content_budgets.json`.
const BASE_ROOT: String = FIXTURES + "content_checks_base/"
## `content_checks_base/` with `text_max_chars` 80 and `curve.bucket_tol` 0.15.
const KNOBS_ROOT: String = FIXTURES + "content_checks_knobs/"
## The card whose `text.en` is 85 characters in both roots.
const LONG_TEXT_CARD: String = "war_long_text"


# --- config bodies and pools ---------------------------------------------------

## `content_budgets.json` `config` at the content.md F1-F6 / Tuning Knobs defaults.
func _budgets() -> Dictionary:
	return {
		"curve": {"avg_min": 2.9, "avg_max": 3.4, "bucket": [0.16, 0.22, 0.24, 0.18, 0.10, 0.10],
			"bucket_tol": 0.08, "early_max": 2.5, "mid_max": 4.0},
		"budget": {
			"tol": {"common": 1.5, "rare": 2.0, "legendary": 3.0},
			"keyword_tax": {"taunt": 1, "rush": 1, "charge": 2, "divine_shield": 2, "windfury": 2,
				"stealth": 1, "lifesteal": 1, "poisonous": 2, "spell_damage": 1.5},
			"effect_points": {"damage_targeted": 1.5, "damage_random": 1.0, "damage_aoe_enemy": 3.0,
				"damage_aoe_own": 1.0, "heal": 0.5, "armor": 0.5, "draw": 2.5, "discover": 2.0,
				"summon_stat_point": 1.0, "buff_point": 1.0, "freeze": 1.5, "silence": 2.0,
				"destroy": 5.0, "destroy_restricted": 3.0, "transform": 4.0, "mana": 1.5,
				"deathrattle_factor": 0.8, "self_destroy": -3.0},
		},
		"pressure": {"band": [7.0, 9.0, 11.5], "tol": 1.0, "passive_cap": [2.0, 3.5, 6.0]},
		"coverage": {"kw_min": 2, "bundle_coverage_min": 0.9, "ops_exempt": [
			"remove_keyword", "shuffle_into_deck", "discard", "weapon_durability", "hero_power_refresh"]},
		"text_max_chars": 90,
		"pick_rate": {"min": 0.15, "max": 0.55, "min_sample": 30},
		"time": {"t_card": 0.42, "t_boss_card": 0.33, "t_boss": 2.5, "t_bundle": 0.2, "t_balance": 4},
		"neutral_set_size": 45,
		"set_share": {"neutral": {"minion": 0.82, "spell": 0.11, "weapon": 0.07},
			"boss": {"minion": 0.56, "spell": 0.41, "weapon": 0.03}},
		"share_tol": 0.08,
	}


## `heroes_balance.json` `config` at the heroes.md F1-F5 defaults.
func _heroes_balance() -> Dictionary:
	return {
		"starter_curve": {"avg_min": 2.4, "avg_max": 2.8, "max_cost": 5, "bucket": {
			"0": [0, 0], "1": [3, 4], "2": [4, 5], "3": [3, 4], "4": [1, 2], "5": [1, 2], "6_plus": [0, 0]}},
		"plan_min": 4, "plan_max": 7,
		"set_share": {"war": {"minion": 0.52, "spell": 0.24, "weapon": 0.24},
			"decay": {"minion": 0.68, "spell": 0.32, "weapon": 0.0},
			"knowledge": {"minion": 0.44, "spell": 0.56, "weapon": 0.0}},
		"set_share_tol": 0.08,
	}


func _pool(cards: Array, heroes: Array = [], bosses: Array = [], treasures: Array = [], bundles: Array = []) -> Dictionary:
	return {"cards": cards, "heroes": heroes, "bosses": bosses, "treasures": treasures, "bundles": bundles,
		"match_rules": {"starting_health_player": TestConstants.PLAYER_STARTING_HEALTH}}


## One War card per cost 1-6, ids `war_c<cost>`.
func _cost_ladder() -> Array:
	var cards: Array = []
	for cost: int in range(1, 7):
		cards.append(CardFactory.make_minion("war_c%d" % cost, cost, cost, cost, [], {"set": "war"}))
	return cards


## The heroes.md F1 example starter: counts [0, 4, 4, 4, 2, 1], avg 2.47.
func _conforming_starter() -> Array:
	var ids: Array = []
	for pair: Array in [[1, 4], [2, 4], [3, 4], [4, 2], [5, 1]]:
		for i: int in pair[1]:
			ids.append("war_c%d" % pair[0])
	return ids


func _war_hero(starter: Array, overrides: Dictionary = {}) -> Dictionary:
	var fields: Dictionary = {"starter_deck": starter}
	fields.merge(overrides, true)
	return CardFactory.make_hero_def("hero_war", "war", fields)


## `count` cards of `type` in `card_set`, ids `<set>_<type>_<i>` from `start`.
func _cards(card_set: String, type: String, count: int, cost: int = 3, start: int = 0) -> Array:
	var out: Array = []
	for i: int in range(start, start + count):
		var id: String = "%s_%s_%02d" % [card_set, type, i]
		match type:
			"minion": out.append(CardFactory.make_minion(id, cost, 2, 2, [], {"set": card_set}))
			"spell": out.append(CardFactory.make_spell(id, cost, [], {"set": card_set}))
			_: out.append(CardFactory.make_weapon(id, cost, 2, 2, {"set": card_set}))
	return out


func _codes(rows: Array) -> Array:
	var out: Array = []
	for row: Dictionary in rows:
		out.append(row.code)
	return out


func _with_code(rows: Array, code: StringName) -> Array:
	return rows.filter(func(r: Dictionary) -> bool: return r.code == code)


## Every row is a CR-5 report entry whose severity follows its code prefix.
func _assert_cr5_shape(rows: Array) -> void:
	for row: Dictionary in rows:
		assert_array(row.keys()).contains_exactly_in_any_order(["severity", "code", "file", "record_id", "field", "message"])
		var expected: StringName = ValidationReport.SEVERITY_ERROR if String(row.code).begins_with("E_") else ValidationReport.SEVERITY_WARNING
		assert_str(String(row.severity)).override_failure_message("severity of %s" % str(row)).is_equal(String(expected))


func _load(root: String) -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(root))
	db.load(ValidatorStubs.accept_all())
	return db


# --- AC-1: heroes F1 starter curve, W_HERO_HEALTH, F1 set share -----------------

func test_starter_curve_conforming_starter_raises_no_entry() -> void:
	var pool: Dictionary = _pool(_cost_ladder(), [_war_hero(_conforming_starter())])

	var rows: Array = ContentValidator.check_heroes(pool, _budgets(), _heroes_balance())

	assert_array(rows).is_empty()


func test_starter_curve_six_cost_substituted_raises_one_entry_naming_the_hero() -> void:
	# heroes.md AC-2: a 6-cost card substituted fails with E_STARTER_CURVE.
	var starter: Array = _conforming_starter()
	starter[starter.find("war_c3")] = "war_c6"
	var pool: Dictionary = _pool(_cost_ladder(), [_war_hero(starter)])

	var rows: Array = ContentValidator.check_heroes(pool, _budgets(), _heroes_balance())

	assert_array(_codes(rows)).contains_exactly([ContentValidator.E_STARTER_CURVE])
	assert_str(String(rows[0].record_id)).is_equal("hero_war")
	assert_str(String(rows[0].file)).is_equal("heroes.json")
	assert_str(String(rows[0].message)).contains("6")
	_assert_cr5_shape(rows)


func test_starter_curve_average_above_band_raises_entry() -> void:
	# Every 1-drop becomes a 2 and every 3 a 4: counts break and avg 3.27 > 2.8.
	var starter: Array = []
	for pair: Array in [[2, 8], [4, 6], [5, 1]]:
		for i: int in pair[1]:
			starter.append("war_c%d" % pair[0])
	var pool: Dictionary = _pool(_cost_ladder(), [_war_hero(starter)])

	var rows: Array = ContentValidator.check_heroes(pool, _budgets(), _heroes_balance())

	assert_array(_codes(rows)).contains_exactly([ContentValidator.E_STARTER_CURVE])
	assert_str(String(rows[0].message)).contains("avg")


func test_hero_health_other_than_starting_health_warns() -> void:
	var hero: Dictionary = _war_hero(_conforming_starter(), {"health": TestConstants.PLAYER_STARTING_HEALTH + 5})
	var pool: Dictionary = _pool(_cost_ladder(), [hero])

	var rows: Array = ContentValidator.check_heroes(pool, _budgets(), _heroes_balance())

	assert_array(_codes(rows)).contains_exactly([ContentValidator.W_HERO_HEALTH])
	assert_str(String(rows[0].record_id)).is_equal("hero_war")
	assert_str(String(rows[0].field)).is_equal("health")
	_assert_cr5_shape(rows)


func test_starter_curve_missing_knob_reports_not_checked_never_passes() -> void:
	var balance: Dictionary = _heroes_balance()
	balance.erase("starter_curve")
	var pool: Dictionary = _pool(_cost_ladder(), [_war_hero(_conforming_starter())])

	var rows: Array = ContentValidator.check_heroes(pool, _budgets(), balance)

	assert_array(_codes(rows)).contains_exactly([ContentValidator.E_STARTER_CURVE])
	assert_str(String(rows[0].message)).contains("not checked")


func test_set_share_knowledge_one_weapon_of_25_raises_no_warning() -> void:
	# heroes.md AC-4: 1 weapon of 25 = 0.04, inside 0 ± 0.08.
	var cards: Array = _cards("knowledge", "minion", 11) + _cards("knowledge", "spell", 13) + _cards("knowledge", "weapon", 1)

	var rows: Array = ContentValidator.check_set_share(_pool(cards), _budgets(), _heroes_balance())

	assert_array(rows).is_empty()


func test_set_share_knowledge_three_weapons_of_25_warns_naming_set_and_type() -> void:
	# heroes.md AC-4: 3 of 25 = 0.12 → W_SET_SHARE, no E_*. (The spell share of
	# 11 / 25 also misses 0.56; only the weapon row is the AC's point.)
	var cards: Array = _cards("knowledge", "minion", 11) + _cards("knowledge", "spell", 11) + _cards("knowledge", "weapon", 3)

	var rows: Array = ContentValidator.check_set_share(_pool(cards), _budgets(), _heroes_balance())

	assert_array(_codes(rows).filter(func(c: StringName) -> bool: return c != ContentValidator.W_SET_SHARE)).is_empty()
	var weapon: Array = rows.filter(func(r: Dictionary) -> bool: return r.field == "set_share.knowledge.weapon")
	assert_int(weapon.size()).is_equal(1)
	assert_str(String(weapon[0].file)).is_equal("cards_knowledge.json")
	assert_str(String(weapon[0].message)).contains("0.12")
	_assert_cr5_shape(rows)


func test_set_share_neutral_reads_content_budgets_row_and_share_tol() -> void:
	# 6 neutral minions: 1.0 vs 0.82 → miss; widening share_tol to 0.15 still misses
	# minion (0.18) — then lowering the neutral minion target to 0.9 clears it.
	var cards: Array = _cards("neutral", "minion", 6)
	var budgets: Dictionary = _budgets()

	var at_default: Array = ContentValidator.check_set_share(_pool(cards), budgets, _heroes_balance())
	budgets.set_share.neutral = {"minion": 0.95, "spell": 0.03, "weapon": 0.02}
	var retargeted: Array = ContentValidator.check_set_share(_pool(cards), budgets, _heroes_balance())

	assert_array(_codes(at_default)).contains([ContentValidator.W_SET_SHARE])
	assert_array(retargeted).is_empty()


func test_set_share_tokens_excluded_from_the_set() -> void:
	var cards: Array = _cards("war", "minion", 13) + _cards("war", "spell", 6) + _cards("war", "weapon", 6)
	cards.append(CardFactory.make_weapon("war_token_blade", 1, 1, 2, {"set": "war", "token": true}))
	cards.append(CardFactory.make_weapon("war_token_blade_2", 1, 1, 2, {"set": "war", "token": true}))
	cards.append(CardFactory.make_weapon("war_token_blade_3", 1, 1, 2, {"set": "war", "token": true}))

	var rows: Array = ContentValidator.check_set_share(_pool(cards), _budgets(), _heroes_balance())

	assert_array(rows).is_empty()


func test_conforming_pool_raises_none_of_the_three_ac1_codes() -> void:
	var cards: Array = _cost_ladder() + _cards("war", "minion", 9) + _cards("war", "spell", 6) + _cards("war", "weapon", 6)
	var pool: Dictionary = _pool(cards, [_war_hero(_conforming_starter())])

	var rows: Array = ContentValidator.check_heroes(pool, _budgets(), _heroes_balance()) \
		+ ContentValidator.check_set_share(pool, _budgets(), _heroes_balance())

	assert_array(_codes(rows)).not_contains([ContentValidator.E_STARTER_CURVE, ContentValidator.W_HERO_HEALTH, ContentValidator.W_SET_SHARE])


# --- AC-2: F2 curve, F3 budget, text length ------------------------------------

## 25 War cards: bucket counts [4, 6, 6, 4, 3, 2] → shares within 0.08, avg 3.08.
func _conforming_curve_set() -> Array:
	var out: Array = []
	var counts: Array = [[1, 4], [2, 6], [3, 6], [4, 4], [5, 3], [6, 2]]
	var n: int = 0
	for pair: Array in counts:
		for i: int in pair[1]:
			out.append(CardFactory.make_minion("war_curve_%02d" % n, pair[0], 1, 1, [], {"set": "war"}))
			n += 1
	return out


func test_curve_conforming_set_raises_no_warning() -> void:
	var rows: Array = ContentValidator.check_curve(_pool(_conforming_curve_set()), _budgets(), _heroes_balance())

	assert_array(rows).is_empty()


func test_curve_average_outside_band_warns() -> void:
	var cards: Array = _cards("war", "minion", 25, 5)

	var rows: Array = ContentValidator.check_curve(_pool(cards), _budgets(), _heroes_balance())

	var avg_rows: Array = rows.filter(func(r: Dictionary) -> bool: return r.field == "curve.avg")
	assert_int(avg_rows.size()).is_equal(1)
	assert_str(String(avg_rows[0].code)).is_equal(String(ContentValidator.W_CURVE))
	assert_str(String(avg_rows[0].file)).is_equal("cards_war.json")
	assert_str(String(avg_rows[0].message)).contains("5.00")
	_assert_cr5_shape(rows)


func test_curve_bucket_missing_target_warns_naming_the_bucket() -> void:
	# The two 6-drops become a 5 and a 4: bucket 6+ 0.00 vs 0.10 (miss 0.10);
	# bucket 5 0.16 (0.06) and 4 0.20 (0.02) stay inside; avg 74 / 25 = 2.96.
	var cards: Array = _conforming_curve_set()
	var moved: Array = [5, 4]
	for card: Dictionary in cards:
		if card.cost == 6:
			card.cost = moved.pop_front()

	var rows: Array = ContentValidator.check_curve(_pool(cards), _budgets(), _heroes_balance())

	var fields: Array = rows.map(func(r: Dictionary) -> String: return String(r.field))
	assert_array(fields).contains_exactly(["curve.bucket[5]"])
	assert_str(String(rows[0].code)).is_equal(String(ContentValidator.W_CURVE))


func test_curve_tokens_and_boss_cards_are_not_a_collectible_set() -> void:
	var cards: Array = _conforming_curve_set()
	cards.append(CardFactory.make_minion("war_token_9", 9, 9, 9, [], {"set": "war", "token": true}))
	cards.append_array(_cards("boss", "minion", 3, 8))

	var rows: Array = ContentValidator.check_curve(_pool(cards), _budgets(), _heroes_balance())

	assert_array(rows).is_empty()


func test_budget_vanilla_minion_on_budget_raises_no_warning() -> void:
	# 3 mana 3/4: 7 points vs budget 2 × 3 + 1 = 7.
	var card: Dictionary = CardFactory.make_minion("neutral_vanilla", 3, 3, 4)

	var rows: Array = ContentValidator.check_budget(_pool([card]), _budgets(), _heroes_balance())

	assert_array(rows).is_empty()


func test_budget_over_tolerance_warns_naming_card_and_points() -> void:
	# 3 mana 5/5: 10 points vs 7, Δ 3 > common 1.5.
	var card: Dictionary = CardFactory.make_minion("neutral_overstat", 3, 5, 5)

	var rows: Array = ContentValidator.check_budget(_pool([card]), _budgets(), _heroes_balance())

	assert_array(_codes(rows)).contains_exactly([ContentValidator.W_BUDGET])
	assert_str(String(rows[0].record_id)).is_equal("neutral_overstat")
	assert_str(String(rows[0].message)).contains("10.0").contains("7.0")
	_assert_cr5_shape(rows)


func test_budget_tolerance_follows_rarity() -> void:
	# 3 mana 4/5: 9 vs 7, Δ 2 — outside common 1.5, inside legendary 3.0.
	var common: Dictionary = CardFactory.make_minion("neutral_common_big", 3, 4, 5)
	var legendary: Dictionary = CardFactory.make_minion("neutral_legend_big", 3, 4, 5, [], {"rarity": "legendary"})

	var rows: Array = ContentValidator.check_budget(_pool([common, legendary]), _budgets(), _heroes_balance())

	assert_array(rows.map(func(r: Dictionary) -> String: return String(r.record_id))).contains_exactly(["neutral_common_big"])


func test_card_value_matches_the_f3_worked_examples() -> void:
	var pool: Dictionary = _pool([])
	var veteran: Dictionary = CardFactory.make_minion("war_shieldwall_veteran", 4, 3, 4, ["taunt", "battlecry"], {"set": "war",
		"effects": [CardFactory.make_effect("battlecry", [CardFactory.make_op("armor", {"amount": 3})], {}, {"targets": "owner"})]})
	var kingsblade: Dictionary = CardFactory.make_weapon("war_kingsblade", 6, 4, 2, {"set": "war", "rarity": "legendary",
		"effects": [CardFactory.make_effect("on_attack", [CardFactory.make_op("damage", {"amount": 2})], {"selector": "all_enemy_minions"})]})
	var meteor: Dictionary = CardFactory.make_spell("neutral_meteor_bolt", 4,
		[CardFactory.make_effect("play", [CardFactory.make_op("damage", {"amount": 6})], {"selector": "chosen"})])
	var mammoth: Dictionary = CardFactory.make_minion("neutral_war_mammoth", 7, 7, 7, ["taunt"])
	var culling: Dictionary = CardFactory.make_spell("neutral_culling", 2, [
		CardFactory.make_effect("play", [CardFactory.make_op("destroy")], {"selector": "chosen", "filter": {"side": "friendly"}}),
		CardFactory.make_effect("play", [CardFactory.make_op("draw", {"count": 2})], {}, {"targets": "owner"})])

	assert_float(ContentValidator.card_value(veteran, pool, _budgets()).points).is_equal_approx(9.5, 0.0001)
	assert_float(ContentValidator.card_value(kingsblade, pool, _budgets()).points).is_equal_approx(14.0, 0.0001)
	assert_float(ContentValidator.card_value(kingsblade, pool, _budgets()).budget).is_equal_approx(14.0, 0.0001)
	assert_float(ContentValidator.card_value(meteor, pool, _budgets()).points).is_equal_approx(9.0, 0.0001)
	assert_float(ContentValidator.card_value(meteor, pool, _budgets()).budget).is_equal_approx(8.0, 0.0001)
	assert_float(ContentValidator.card_value(mammoth, pool, _budgets()).points).is_equal_approx(15.0, 0.0001)
	assert_float(ContentValidator.card_value(culling, pool, _budgets()).points).is_equal_approx(2.0, 0.0001)


func test_card_value_deathrattle_summon_and_nested_branches() -> void:
	# 1/1 token summoned by a Deathrattle: 2 × 0.8 = 1.6; repeat 2 × draw 1 = 5; choose_one max(3 armor 1.5, draw 2.5).
	var token: Dictionary = CardFactory.make_minion("neutral_rat_token", 1, 1, 1, [], {"token": true})
	var pool: Dictionary = _pool([token])
	var rattler: Dictionary = CardFactory.make_minion("neutral_rattler", 1, 1, 1, ["deathrattle"], {"effects": [
		CardFactory.make_effect("deathrattle", [CardFactory.make_op("summon", {"card_id": "neutral_rat_token"})])]})
	var looper: Dictionary = CardFactory.make_spell("neutral_looper", 2, [CardFactory.make_effect("play", [
		CardFactory.make_op("repeat", {"times": 2, "ops": [CardFactory.make_op("draw", {"count": 1})]})], {}, {"targets": "owner"})])
	var chooser: Dictionary = CardFactory.make_spell("neutral_chooser", 1, [CardFactory.make_effect("play", [
		CardFactory.make_op("choose_one", {"options": [
			{"label_key": "opt.a", "ops": [CardFactory.make_op("armor", {"amount": 3})]},
			{"label_key": "opt.b", "ops": [CardFactory.make_op("draw", {"count": 1})]}]})], {}, {"targets": "owner"})])

	assert_float(ContentValidator.card_value(rattler, pool, _budgets()).points).is_equal_approx(3.6, 0.0001)
	assert_float(ContentValidator.card_value(looper, pool, _budgets()).points).is_equal_approx(5.0, 0.0001)
	assert_float(ContentValidator.card_value(chooser, pool, _budgets()).points).is_equal_approx(2.5, 0.0001)


func test_budget_unvalued_op_reports_not_checked_never_passes() -> void:
	var card: Dictionary = CardFactory.make_spell("neutral_copycat", 2, [CardFactory.make_effect("play",
		[CardFactory.make_op("copy_to_hand")], {"selector": "chosen"})])

	var rows: Array = ContentValidator.check_budget(_pool([card]), _budgets(), _heroes_balance())

	assert_array(_codes(rows)).contains_exactly([ContentValidator.W_BUDGET])
	assert_str(String(rows[0].message)).contains("not checked").contains("copy_to_hand")


func test_text_exactly_ninety_characters_passes() -> void:
	var card: Dictionary = CardFactory.make_minion("neutral_wordy", 1, 1, 1, [], {"text": {"key": "card.neutral_wordy.text", "en": "a".repeat(90)}})

	var rows: Array = ContentValidator.check_text(_pool([card]), _budgets(), _heroes_balance())

	assert_array(rows).is_empty()


func test_text_ninety_one_characters_fails_naming_the_card() -> void:
	var card: Dictionary = CardFactory.make_minion("neutral_wordy", 1, 1, 1, [], {"text": {"key": "card.neutral_wordy.text", "en": "a".repeat(91)}})

	var rows: Array = ContentValidator.check_text(_pool([card]), _budgets(), _heroes_balance())

	assert_array(_codes(rows)).contains_exactly([ContentValidator.E_TEXT_LENGTH])
	assert_str(String(rows[0].record_id)).is_equal("neutral_wordy")
	assert_str(String(rows[0].field)).is_equal("text.en")
	assert_str(String(rows[0].message)).contains("91").contains("90")
	_assert_cr5_shape(rows)


func test_text_counts_characters_not_bytes() -> void:
	# 90 em-dashes are 270 UTF-8 bytes but 90 characters.
	var card: Dictionary = CardFactory.make_minion("neutral_dashes", 1, 1, 1, [], {"text": {"key": "card.neutral_dashes.text", "en": "—".repeat(90)}})

	assert_array(ContentValidator.check_text(_pool([card]), _budgets(), _heroes_balance())).is_empty()


# --- AC-3: F5 coverage ---------------------------------------------------------

## One collectible neutral card using every OPS_COVERED op, one keyword pair per
## DD-M09 keyword, and a treasure using modify_value: full coverage.
func _covered_pool(extra_heroes: Array = []) -> Dictionary:
	var ops: Array = []
	for op: String in ContentValidator.ops_covered(_budgets()):
		ops.append(CardFactory.make_op(op))
	var cards: Array = [CardFactory.make_spell("neutral_everything", 1, [CardFactory.make_effect("play", ops)])]
	for kw: String in RecordSchemas.KEYWORDS:
		for i: int in 2:
			cards.append(CardFactory.make_minion("neutral_kw_%s_%d" % [kw, i], 1, 1, 1, [kw]))
	var treasure: Dictionary = CardFactory.make_treasure_def("treasure_t01", "common", ["universal"],
		{"effects": [CardFactory.make_effect("modify_cost", [CardFactory.make_op("modify_value", {"delta": -1})])]})
	return _pool(cards, extra_heroes, [], [treasure])


func _decay_hero() -> Dictionary:
	return CardFactory.make_hero_def("hero_decay", "decay")


func _without(pool: Dictionary, op: String) -> Dictionary:
	var effect: Dictionary = pool.cards[0].effects[0]
	effect.ops = effect.ops.filter(func(o: Dictionary) -> bool: return o.op != op)
	return pool


func test_ops_covered_is_effect_schema_minus_exempt_and_modify_value() -> void:
	var covered: Array = ContentValidator.ops_covered(_budgets())

	var expected: Array = EffectSchema.OPS.keys().filter(func(op: String) -> bool:
		return op != "modify_value" and not _budgets().coverage.ops_exempt.has(op))
	assert_array(covered).contains_exactly_in_any_order(expected)


func test_coverage_full_pool_reports_only_unused_exempt_ops() -> void:
	var rows: Array = ContentValidator.check_coverage(_covered_pool(), _budgets(), _heroes_balance())

	assert_array(_codes(rows).filter(func(c: StringName) -> bool: return c != ContentValidator.W_COVERAGE_UNUSED)).is_empty()
	assert_int(_with_code(rows, ContentValidator.W_COVERAGE_UNUSED).size()).is_equal(_budgets().coverage.ops_exempt.size())


func test_coverage_unused_op_at_mvp_pool_is_w_coverage() -> void:
	var rows: Array = ContentValidator.check_coverage(_without(_covered_pool(), "freeze"), _budgets(), _heroes_balance())

	var unmet: Array = _with_code(rows, ContentValidator.W_COVERAGE)
	assert_int(unmet.size()).is_equal(1)
	assert_str(String(unmet[0].field)).contains("freeze")
	assert_array(_with_code(rows, ContentValidator.E_COVERAGE)).is_empty()
	_assert_cr5_shape(rows)


func test_coverage_unused_op_at_alpha_pool_is_e_coverage() -> void:
	var rows: Array = ContentValidator.check_coverage(_without(_covered_pool([_decay_hero()]), "freeze"), _budgets(), _heroes_balance())

	var unmet: Array = _with_code(rows, ContentValidator.E_COVERAGE)
	assert_int(unmet.size()).is_equal(1)
	assert_str(String(unmet[0].field)).contains("freeze")
	_assert_cr5_shape(rows)


func test_coverage_unused_exempt_op_is_w_coverage_unused_even_at_alpha() -> void:
	var rows: Array = ContentValidator.check_coverage(_covered_pool([_decay_hero()]), _budgets(), _heroes_balance())

	assert_array(_with_code(rows, ContentValidator.E_COVERAGE)).is_empty()
	var fields: Array = _with_code(rows, ContentValidator.W_COVERAGE_UNUSED).map(func(r: Dictionary) -> String: return String(r.field))
	assert_array(fields).contains(["coverage.ops_exempt.discard"])


func test_coverage_op_inside_conditional_counts_as_used() -> void:
	var pool: Dictionary = _without(_covered_pool(), "freeze")
	pool.cards.append(CardFactory.make_spell("neutral_maybe_freeze", 1, [CardFactory.make_effect("play", [
		CardFactory.make_op("conditional", {"if": {"is_owner_turn": true}, "then": [CardFactory.make_op("freeze")]})])]))

	var rows: Array = ContentValidator.check_coverage(pool, _budgets(), _heroes_balance())

	assert_array(_with_code(rows, ContentValidator.W_COVERAGE)).is_empty()


func test_coverage_op_used_only_by_a_token_or_boss_card_is_unmet() -> void:
	var pool: Dictionary = _without(_covered_pool(), "freeze")
	pool.cards.append(CardFactory.make_spell("boss_icy", 1, [CardFactory.make_effect("play", [CardFactory.make_op("freeze")])], {"set": "boss"}))
	pool.cards.append(CardFactory.make_spell("neutral_icy_token", 1, [CardFactory.make_effect("play", [CardFactory.make_op("freeze")])], {"token": true}))

	var rows: Array = ContentValidator.check_coverage(pool, _budgets(), _heroes_balance())

	assert_int(_with_code(rows, ContentValidator.W_COVERAGE).size()).is_equal(1)


func test_coverage_modify_value_checked_against_passives_and_treasures() -> void:
	var pool: Dictionary = _covered_pool()
	pool.treasures = []
	var unmet: Array = ContentValidator.check_coverage(pool, _budgets(), _heroes_balance())
	var boss: Dictionary = CardFactory.make_boss_def("boss_taxman", 1, {"passive":
		CardFactory.make_effect("modify_cost", [CardFactory.make_op("modify_value", {"delta": 1})])})
	pool.bosses = [boss]
	var met: Array = ContentValidator.check_coverage(pool, _budgets(), _heroes_balance())

	var fields: Array = _with_code(unmet, ContentValidator.W_COVERAGE).map(func(r: Dictionary) -> String: return String(r.field))
	assert_array(fields).contains_exactly(["coverage.modify_value"])
	assert_array(_with_code(met, ContentValidator.W_COVERAGE)).is_empty()


func test_coverage_keyword_below_kw_min_is_reported() -> void:
	var pool: Dictionary = _covered_pool()
	pool.cards = pool.cards.filter(func(c: Dictionary) -> bool: return c.id != "neutral_kw_stealth_1")

	var rows: Array = ContentValidator.check_coverage(pool, _budgets(), _heroes_balance())

	var fields: Array = _with_code(rows, ContentValidator.W_COVERAGE).map(func(r: Dictionary) -> String: return String(r.field))
	assert_array(fields).contains_exactly(["coverage.kw_min.stealth"])


func test_coverage_hero_set_bundle_coverage_below_min_is_reported_with_its_value() -> void:
	# 10 non-starter War cards, 8 in a bundle → 0.80 < 0.90.
	var pool: Dictionary = _covered_pool([_war_hero(["war_starter_only"])])
	var war: Array = _cards("war", "minion", 10)
	pool.cards.append_array(war)
	pool.cards.append(CardFactory.make_minion("war_starter_only", 1, 1, 1, [], {"set": "war"}))
	var ids: Array = war.map(func(c: Dictionary) -> String: return c.id)
	pool.bundles = [
		CardFactory.make_bundle_def("bundle_war_a", "war", "aggro", ids.slice(0, 3)),
		CardFactory.make_bundle_def("bundle_war_b", "war", "aggro", ids.slice(3, 6)),
		CardFactory.make_bundle_def("bundle_war_c", "war", "aggro", [ids[6], ids[7], ids[0]]),
	]

	var rows: Array = ContentValidator.check_coverage(pool, _budgets(), _heroes_balance())

	var bundle_rows: Array = _with_code(rows, ContentValidator.W_COVERAGE).filter(func(r: Dictionary) -> bool: return String(r.field) == "coverage.bundle_coverage_min.war")
	assert_int(bundle_rows.size()).is_equal(1)
	assert_str(String(bundle_rows[0].message)).contains("0.80").contains("8 / 10")
	assert_str(String(bundle_rows[0].file)).is_equal("bundles.json")


# --- AC-4: no literals; knobs in fixture content_budgets.json decide ----------

func test_text_max_chars_knob_in_fixture_changes_the_outcome() -> void:
	var base: CardDatabase = _load(BASE_ROOT)
	var knobs: CardDatabase = _load(KNOBS_ROOT)
	assert_int(base.state()).is_equal(CardDatabase.State.READY)
	assert_int(knobs.state()).is_equal(CardDatabase.State.READY)

	var at_90: Array = _with_code(ContentValidator.run_checks(base, base.config("content_budgets"), base.config("heroes_balance")), ContentValidator.E_TEXT_LENGTH)
	var at_80: Array = _with_code(ContentValidator.run_checks(knobs, knobs.config("content_budgets"), knobs.config("heroes_balance")), ContentValidator.E_TEXT_LENGTH)

	assert_array(at_90).is_empty()
	assert_array(at_80.map(func(r: Dictionary) -> String: return String(r.record_id))).contains_exactly([LONG_TEXT_CARD])


func test_bucket_tol_knob_in_fixture_changes_the_outcome() -> void:
	# War costs [1,1,2,2,3,3,4,5]: bucket ≤1 0.25 (miss 0.09) and 6+ 0.00 (miss 0.10) —
	# outside 0.08, inside 0.15.
	var base: CardDatabase = _load(BASE_ROOT)
	var knobs: CardDatabase = _load(KNOBS_ROOT)
	var is_war_bucket: Callable = func(r: Dictionary) -> bool:
		return r.code == ContentValidator.W_CURVE and r.file == "cards_war.json" and String(r.field).begins_with("curve.bucket")

	var at_008: Array = ContentValidator.run_checks(base, base.config("content_budgets"), base.config("heroes_balance")).filter(is_war_bucket)
	var at_015: Array = ContentValidator.run_checks(knobs, knobs.config("content_budgets"), knobs.config("heroes_balance")).filter(is_war_bucket)

	assert_array(at_008.map(func(r: Dictionary) -> String: return String(r.field))).contains_exactly_in_any_order(["curve.bucket[0]", "curve.bucket[5]"])
	assert_array(at_015).is_empty()


func test_fixture_base_root_raises_no_ac1_code() -> void:
	var db: CardDatabase = _load(BASE_ROOT)

	var rows: Array = ContentValidator.run_checks(db, db.config("content_budgets"), db.config("heroes_balance"))

	assert_array(_codes(rows)).not_contains([ContentValidator.E_STARTER_CURVE, ContentValidator.W_HERO_HEALTH, ContentValidator.W_SET_SHARE])
	_assert_cr5_shape(rows)


func test_pool_of_reads_every_record_type_from_a_ready_database() -> void:
	var db: CardDatabase = _load(BASE_ROOT)

	var pool: Dictionary = ContentValidator.pool_of(db)

	assert_int((pool.cards as Array).size()).is_equal(14)
	assert_int((pool.heroes as Array).size()).is_equal(1)
	assert_int(int(pool.match_rules.starting_health_player)).is_equal(TestConstants.PLAYER_STARTING_HEALTH)


func test_command_merges_check_entries_and_exits_one_on_a_check_error() -> void:
	var base: Dictionary = ContentValidateCommand.run(BASE_ROOT, ValidatorStubs.accept_all())
	var knobs: Dictionary = ContentValidateCommand.run(KNOBS_ROOT, ValidatorStubs.accept_all())

	assert_int(base.exit_code).is_equal(ContentValidateCommand.EXIT_READY)
	assert_str(String(base.report_text)).contains("W_CURVE").not_contains("E_TEXT_LENGTH")
	assert_int(knobs.exit_code).is_equal(ContentValidateCommand.EXIT_FAILED)
	assert_str(String(knobs.report_text)).contains("[error] E_TEXT_LENGTH cards_war.json#%s.text.en" % LONG_TEXT_CARD)


## The F1-F6 constant names, as a declaration in GDScript code.
const CONSTANT_DECL: String = "\\b(const|var)\\s+(CURVE_\\w+|BUDGET_TOL\\w*|PRESSURE_\\w+|PASSIVE_CAP\\w*|KW_MIN|BUNDLE_COVERAGE_MIN|TEXT_MAX_CHARS|PICK_RATE_\\w+)\\b"
## The F1-F6 default values that are distinctive enough to grep: CURVE_AVG
## 2.9 / 3.4, CURVE_BUCKET 0.16 / 0.22 / 0.24 / 0.18, BUCKET_TOL and SHARE_TOL
## 0.08, PRESSURE_BAND 11.5, PICK_RATE_MAX 0.55, BUNDLE_COVERAGE_MIN 0.9(0),
## TEXT_MAX_CHARS 90. Not mechanically crisp, so kept as a list: the other
## defaults (1.5, 2, 3, 7, 9, 1.0, 3.5, 6, 0.10, 0.15) are also safe-range
## bounds in `BUDGETS_SPEC` or ordinary numbers elsewhere in `src/`, and a
## pattern over them would fire on unrelated code. Extend this list when a
## knob with a distinctive default is added to CN-6 step 2.
const DEFAULT_LITERAL: String = "(?<![\\w.])(2\\.9|3\\.4|0\\.16|0\\.22|0\\.24|0\\.18|0\\.08|11\\.5|0\\.55|0\\.90?|90)(?![\\w.])"
const SCAN_ROOTS: Array[String] = ["res://src/", "res://tools/content/"]


## The code part of each line of [param text] (from the first `#` on is dropped).
func _literal_hits(text: String) -> Array[String]:
	var decl: RegEx = RegEx.create_from_string(CONSTANT_DECL)
	var literal: RegEx = RegEx.create_from_string(DEFAULT_LITERAL)
	var hits: Array[String] = []
	for line: String in text.split("\n"):
		var hash_at: int = line.find("#")
		var code: String = line if hash_at < 0 else line.substr(0, hash_at)
		if decl.search(code) != null or literal.search(code) != null:
			hits.append(line.strip_edges())
	return hits


func _gd_files_under(dir: String) -> Array[String]:
	var out: Array[String] = []
	for file_name: String in DirAccess.get_files_at(dir):
		if file_name.ends_with(".gd"):
			out.append(dir.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files_under(dir.path_join(sub)))
	return out


func test_literal_matcher_catches_each_forbidden_form() -> void:
	for line: String in ["const TEXT_MAX_CHARS: int = 80", "var CURVE_AVG_MIN := 1.0", "if n > 90:",
			"var tol: float = 0.08", "return avg <= 3.4", "const KW_MIN = 1"]:
		assert_array(_literal_hits(line)).override_failure_message("not caught: %s" % line).has_size(1)
	for line: String in ["## TEXT_MAX_CHARS, safe 70-110", "var x: int = 190", "var y: float = 10.08",
			"\"row\": \"CURVE_AVG_MIN, safe 2.6-3.8\"", "budgets.text_max_chars"]:
		assert_array(_literal_hits(line)).override_failure_message("false hit: %s" % line).is_empty()


func test_no_f1_f6_constant_or_default_literal_in_tools_content_or_src() -> void:
	var hits: Array[String] = []
	var scanned: int = 0
	for root: String in SCAN_ROOTS:
		for path: String in _gd_files_under(root):
			scanned += 1
			for hit: String in _literal_hits(FileAccess.get_file_as_string(path)):
				hits.append("%s: %s" % [path, hit])

	assert_int(scanned).override_failure_message("scan found no .gd file — the gate did not run").is_greater(10)
	assert_array(hits).is_empty()
