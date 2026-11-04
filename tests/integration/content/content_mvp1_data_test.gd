## Integration: the shipped MVP-1 data (content stories 002 and 003;
## content.md CN-2 War table and curve summary, F1, F2, CN-6 step 6;
## heroes.md H-5, F4).
##
## Loads `res://assets/data/` once per test through the real `DataLoader` +
## `CardDatabase` with the validator map `Boot` composes (a fresh, `auto_free`d
## Boot instance, never the autoload; debug severity), so every `effects[]`
## goes through the real `EffectValidator`. Every expected row below is a GDD
## row, quoted; the batch-0 rows are pinned again by
## `content_batch0_data_test.gd`.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SHIPPED: String = "res://assets/data/"
const RARITY: Dictionary = {"C": "common", "R": "rare", "L": "legendary"}
const TYPE: Dictionary = {"M": "minion", "S": "spell", "W": "weapon"}

## CN-2 War table, all 25 rows: [id, name, T, cost, a, h/d, keywords, text, R, tags].
## Stats are `-1` for spells.
const WAR_ROWS: Array = [
	["war_shield_squire", "Shield Squire", "M", 1, 1, 2, ["battlecry"], "Battlecry: Gain 2 Armor.", "C", ["armour"]],
	["war_sharpen", "Sharpen", "S", 1, -1, -1, [], "Give your weapon +2 Attack this turn.", "C", ["weapons"]],
	["war_blade_strike", "Blade Strike", "S", 1, -1, -1, [], "Deal damage equal to your weapon's Attack to an enemy minion.", "C", ["weapons", "aggro"]],
	["war_throwing_axe", "Throwing Axe", "W", 1, 1, 1, ["battlecry"], "Battlecry: Deal 1 damage.", "C", ["weapons"]],
	["war_rusted_axe", "Rusted Axe", "W", 2, 2, 2, [], "", "C", ["weapons"]],
	["war_warcry", "Warcry", "S", 2, -1, -1, [], "Give your minions +1 Attack this turn.", "C", ["aggro"]],
	["war_blade_apprentice", "Blade Apprentice", "M", 2, 2, 2, ["battlecry"], "Battlecry: If you have no weapon, equip a 1/2 Whetstone Blade.", "C", ["weapons"]],
	["war_armorer", "Armorer", "M", 2, 2, 3, ["battlecry"], "Battlecry: Gain Armor equal to your weapon's Attack.", "R", ["armour", "weapons"]],
	["war_cellar_raider", "Cellar Raider", "M", 2, 3, 1, ["rush"], "Rush.", "C", ["aggro"]],
	["war_iron_resolve", "Iron Resolve", "S", 2, -1, -1, [], "Gain 4 Armor. Draw a card.", "C", ["armour"]],
	["war_iron_vanguard", "Iron Vanguard", "M", 3, 2, 4, ["taunt"], "Taunt.", "C", ["armour"]],
	["war_quartermaster", "Quartermaster", "M", 3, 2, 3, ["battlecry"], "Battlecry: If you have a weapon, draw a card.", "C", ["weapons"]],
	["war_berserker", "Pit Berserker", "M", 3, 3, 2, [], "Whenever this minion takes damage, gain +2 Attack.", "R", ["aggro"]],
	["war_heavy_maul", "Heavy Maul", "W", 3, 3, 2, ["battlecry"], "Battlecry: Gain 2 Armor.", "C", ["weapons", "armour"]],
	["war_cleave_through", "Cleave Through", "S", 3, -1, -1, [], "Deal 2 damage to all enemy minions. If you have a weapon, deal 3 instead.", "R", ["weapons", "aggro"]],
	["war_rally", "Rally", "S", 3, -1, -1, [], "Give your minions +1/+1.", "C", ["aggro"]],
	["war_pit_brawler", "Pit Brawler", "M", 4, 4, 3, ["charge"], "Charge.", "C", ["aggro"]],
	["war_shieldwall_veteran", "Shieldwall Veteran", "M", 4, 3, 4, ["taunt", "battlecry"], "Taunt. Battlecry: Gain 3 Armor.", "C", ["armour"]],
	["war_shield_maiden", "Shield Maiden", "M", 4, 2, 4, ["taunt", "divine_shield"], "Taunt. Divine Shield.", "R", ["armour"]],
	["war_duelists_edge", "Duelist's Edge", "W", 4, 3, 3, [], "Whenever your hero attacks, gain 2 Armor.", "R", ["weapons", "armour"]],
	["war_pit_champion", "Pit Champion", "M", 5, 4, 6, ["battlecry"], "Battlecry: Your hero has Windfury this turn.", "L", ["aggro", "weapons"]],
	["war_twin_hatchets", "Twin Hatchets", "W", 5, 2, 4, ["windfury"], "Windfury.", "R", ["weapons", "aggro"]],
	["war_warlord", "Warlord of the Pit", "M", 6, 5, 5, ["aura"], "Your other minions have +1 Attack.", "R", ["aggro"]],
	["war_kingsblade", "Kingsblade", "W", 6, 4, 2, ["battlecry"], "Battlecry: Deal 2 damage to all enemy minions.", "L", ["weapons"]],
	["war_headsman", "Headsman", "M", 7, 5, 5, ["battlecry"], "Battlecry: Destroy a damaged minion.", "L", ["aggro"]],
]
const WAR_TOKEN: String = "war_whetstone_blade"
## Heroes H-5 War signature cards (◆).
const WAR_SIGNATURES: Array[String] = ["war_duelists_edge", "war_pit_champion", "war_cleave_through"]
## CN-2 War curve summary: avg 3.16, buckets 1:4 2:6 3:6 4:4 5:2 6:2 7:1.
const WAR_CURVE_AVG: float = 3.16
const WAR_CURVE_BUCKETS: Dictionary = {1: 4, 2: 6, 3: 6, 4: 4, 5: 2, 6: 2, 7: 1}


func _map() -> Dictionary:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	return boot._collect_validators(null, true)


func _loaded() -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED))
	db.load(_map())
	return db


func _ids(records: Array) -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in records:
		out.append(String(r["id"]))
	return out


func _war_collectible(db: CardDatabase) -> Array:
	return db.cards_by_set("war").filter(func(c: Dictionary) -> bool: return not c.get("token", false))


# --- story 002 AC-1: records ---------------------------------------------------------

func test_war_set_is_the_25_cn2_rows_plus_the_whetstone_blade_token() -> void:
	# Arrange
	var expected: Array[String] = []
	for row: Array in WAR_ROWS:
		expected.append(row[0])
	expected.append(WAR_TOKEN)
	expected.sort()

	# Act
	var db: CardDatabase = _loaded()

	# Assert
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_array(db.report().errors()).is_empty()
	assert_array(_ids(db.cards_by_set("war"))).is_equal(expected)
	assert_int(_war_collectible(db).size()).is_equal(25)
	assert_bool(db.card(WAR_TOKEN)["token"]).is_true()


func test_every_war_card_matches_its_cn2_row() -> void:
	# Arrange
	var by_id: Dictionary = {}
	for c: Dictionary in _loaded().cards_by_set("war"):
		by_id[c["id"]] = c

	# Act / Assert — id, name, type, cost, stats, keywords, text, rarity, tags
	for row: Array in WAR_ROWS:
		var card: Dictionary = by_id.get(row[0], {})
		var id: String = row[0]
		assert_bool(card.is_empty()).override_failure_message("%s missing" % id).is_false()
		if card.is_empty():
			continue
		assert_str(card["name"]).override_failure_message(id).is_equal(row[1])
		assert_str(card["set"]).override_failure_message(id).is_equal("war")
		assert_str(card["type"]).override_failure_message(id).is_equal(TYPE[row[2]])
		assert_int(int(card["cost"])).override_failure_message(id).is_equal(row[3])
		match String(card["type"]):
			"minion":
				assert_int(int(card["attack"])).override_failure_message(id).is_equal(row[4])
				assert_int(int(card["health"])).override_failure_message(id).is_equal(row[5])
			"weapon":
				assert_int(int(card["attack"])).override_failure_message(id).is_equal(row[4])
				assert_int(int(card["durability"])).override_failure_message(id).is_equal(row[5])
		assert_array(Array(card["keywords"])).override_failure_message(id).is_equal(row[6])
		assert_str(card["text"]["en"]).override_failure_message(id).is_equal(row[7])
		assert_str(card["text"]["key"]).override_failure_message(id).is_equal("card.%s.text" % id)
		assert_str(card["rarity"]).override_failure_message(id).is_equal(RARITY[row[8]])
		assert_array(Array(card["tags"])).override_failure_message(id).is_equal(row[9])
		assert_bool(card.get("token", false)).override_failure_message(id).is_false()


func test_war_signature_cards_are_collectible_war_cards() -> void:
	# Act
	var pool: Array[String] = _ids(_loaded().collectible_pool("war"))

	# Assert — Heroes H-5; story 005's bundles and story 004's decks cite them
	for id: String in WAR_SIGNATURES + ["war_shield_maiden", "war_shieldwall_veteran"]:
		assert_bool(pool.has(id)).override_failure_message(id).is_true()


# --- story 002 AC-2: effects and text ---------------------------------------------------

func test_every_war_effect_list_passes_validate_effects_with_zero_rows() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var caps: Dictionary = db.config("card_effects")
	var rows: Array = []

	# Act
	for c: Dictionary in db.cards_by_set("war"):
		rows.append_array(EffectValidator.validate_effects(&"card", c["id"], c["effects"], db, caps))

	# Assert — no E_FX_* and no W_FX_* (W_FX_KEYWORD_MISMATCH is fixed before close)
	assert_array(rows).is_empty()


func test_war_load_raises_no_dup_name_and_no_keyword_mismatch() -> void:
	# Act
	var report: ValidationReport = _loaded().report()

	# Assert
	for e: Dictionary in report.entries():
		assert_str(String(e.code)).override_failure_message(str(e)).is_not_equal("W_DUP_NAME")
		assert_str(String(e.code)).override_failure_message(str(e)).is_not_equal("W_FX_KEYWORD_MISMATCH")


func test_every_war_text_is_at_most_text_max_chars() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var limit: int = int(db.config("content_budgets")["text_max_chars"])

	# Act / Assert
	for c: Dictionary in db.cards_by_set("war"):
		var en: String = c["text"]["en"]
		assert_int(en.length()).override_failure_message("%s: %d chars" % [c["id"], en.length()]).is_less_equal(limit)


# --- story 002 AC-3: set balance (F1, F2) --------------------------------------------------

func test_war_type_shares_are_within_set_share_tolerance() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var balance: Dictionary = db.config("heroes_balance")
	var share: Dictionary = balance["set_share"]["war"]
	var tol: float = float(balance["set_share_tol"])
	var cards: Array = _war_collectible(db)

	# Act
	var counts: Dictionary = {"minion": 0, "spell": 0, "weapon": 0}
	for c: Dictionary in cards:
		counts[c["type"]] = int(counts[c["type"]]) + 1

	# Assert — F1 / Heroes F4; CN-2 states 13 M / 6 S / 6 W
	assert_that(counts).is_equal({"minion": 13, "spell": 6, "weapon": 6})
	for type: String in counts:
		var s: float = float(counts[type]) / cards.size()
		assert_bool(absf(s - float(share[type])) <= tol + 1e-9).override_failure_message(
			"%s share %.3f vs %.2f ± %.2f" % [type, s, float(share[type]), tol]).is_true()


func test_war_curve_matches_the_cn2_summary_and_f2_targets() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var curve: Dictionary = db.config("content_budgets")["curve"]
	var cards: Array = _war_collectible(db)

	# Act
	var total: int = 0
	var by_cost: Dictionary = {}
	for c: Dictionary in cards:
		var cost: int = int(c["cost"])
		total += cost
		by_cost[cost] = int(by_cost.get(cost, 0)) + 1
	var avg: float = float(total) / cards.size()

	# Assert — CN-2 summary, then F2 avg band and per-bucket share ± tol
	assert_int(by_cost.size()).is_equal(WAR_CURVE_BUCKETS.size())
	for cost: int in WAR_CURVE_BUCKETS:
		assert_int(int(by_cost.get(cost, 0))).override_failure_message("cost %d" % cost).is_equal(WAR_CURVE_BUCKETS[cost])
	assert_float(avg).is_equal_approx(WAR_CURVE_AVG, 0.005)
	assert_bool(avg >= float(curve["avg_min"]) and avg <= float(curve["avg_max"])).is_true()
	var bucket_counts: Array[int] = [0, 0, 0, 0, 0, 0]  # k<=1, 2, 3, 4, 5, 6+
	for cost: int in by_cost:
		bucket_counts[clampi(cost, 1, 6) - 1] += int(by_cost[cost])
	for k: int in 6:
		var s: float = float(bucket_counts[k]) / cards.size()
		assert_bool(absf(s - float(curve["bucket"][k])) <= float(curve["bucket_tol"]) + 1e-9).override_failure_message(
			"bucket %d share %.3f vs %.2f" % [k + 1, s, float(curve["bucket"][k])]).is_true()
