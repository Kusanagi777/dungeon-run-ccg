## Integration: the shipped MVP-1 data (content stories 002, 003, 004, 005 and
## 010; content.md CN-2 War table and curve summary, F1, F2, CN-3 B2, CN-6 step
## 6; heroes.md H-5, F4; card-effects.md C11 row 45; DD-X20).
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


# --- story 003: band-1 bosses The Rat King and The Gatekeeper --------------------------------

## CN-3 B2 Rat King: 2× 13 MVP neutrals ≤ 5 cost. The two of the 15 MVP
## neutrals left out, a recipe choice accepted as shipped (DD-X24):
## `neutral_gravekeeper` and `neutral_smite_or_mend` (the swarm deck is bodies).
const RAT_KING_NEUTRALS: Array[String] = [
	"neutral_torch_imp", "neutral_tunnel_rat", "neutral_cellar_guard", "neutral_lantern_bearer",
	"neutral_bulwark_smith", "neutral_dungeon_delver", "neutral_hush_owl", "neutral_spark_fiend",
	"neutral_banner_captain", "neutral_wolf_rider", "neutral_shield_golem", "neutral_crypt_brute",
	"neutral_ogre_porter",
]
const RAT_KING_EXCLUDED: Array[String] = ["neutral_gravekeeper", "neutral_smite_or_mend"]
## CN-3 B2 Gatekeeper recipe's 13 neutrals, `neutral_gravekeeper` back in them
## (content story 010, DD-X20).
const GATEKEEPER_NEUTRALS: Array[String] = [
	"neutral_lantern_bearer", "neutral_cellar_guard", "neutral_dungeon_delver", "neutral_shield_golem",
	"neutral_crypt_brute", "neutral_ogre_porter", "neutral_bulwark_smith", "neutral_banner_captain",
	"neutral_gravekeeper", "neutral_hush_owl", "neutral_torch_imp", "neutral_tunnel_rat",
	"neutral_smite_or_mend",
]
## CN-3 B3: [id, T, cost, a, h, keywords, text].
const BOSS_CARD_ROWS: Array = [
	["boss_rat_pack", "M", 2, 1, 1, ["battlecry"], "Battlecry: Summon two 1/1 Rats."],
	["boss_rat_matriarch", "M", 4, 3, 3, ["aura"], "Your Rats have +1/+1."],
	["boss_iron_gate", "M", 3, 1, 6, ["taunt"], "Taunt."],
	["boss_gate_warden", "M", 5, 3, 6, ["taunt", "battlecry"], "Taunt. Battlecry: Give your other minions +0/+2."],
]
const RAT_TOKEN: String = "boss_rat"
## The archetype each band-1 boss override extends (CN-3 B1 `ai_profile` column).
const BAND1_EXTENDS: Dictionary = {"boss_rat_king": "aggro", "boss_gatekeeper": "control", "boss_torchbearer": "aggro"}


func _deck_counts(deck: Array) -> Dictionary:
	var counts: Dictionary = {}
	for id: String in deck:
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


func _card_or_empty(db: CardDatabase, id: String) -> Dictionary:
	for t: String in ["minion", "spell", "weapon"]:
		for c: Dictionary in db.cards_by_type(t):
			if c["id"] == id:
				return c
	return {}


func _all_bosses(db: CardDatabase) -> Array:
	return db.bosses_in_band(1) + db.bosses_in_band(2) + db.bosses_in_band(3)


func _boss_or_empty(db: CardDatabase, id: String) -> Dictionary:
	for b: Dictionary in _all_bosses(db):
		if b["id"] == id:
			return b
	return {}


func test_band_1_holds_rat_king_gatekeeper_and_torchbearer() -> void:
	# Act
	var ids: Array[String] = _ids(_loaded().bosses_in_band(1))
	ids.sort()

	# Assert — D-06: band_split [2, 1, 1] draws 2 of these 3
	assert_array(ids).is_equal(["boss_gatekeeper", "boss_rat_king", "boss_torchbearer"])


func test_rat_king_is_the_cn3_b1_row() -> void:
	# Act
	var boss: Dictionary = _boss_or_empty(_loaded(), "boss_rat_king")

	# Assert
	assert_bool(boss.is_empty()).is_false()
	if boss.is_empty():
		return
	assert_str(boss["name"]).is_equal("The Rat King")
	assert_int(int(boss["band"])).is_equal(1)
	assert_int(int(boss["health"])).is_equal(30)
	assert_that(boss["hero_power"]).is_null()
	assert_that(boss["passive"]).is_equal({"trigger": "turn_start", "scope": {"side": "owner"},
		"ops": [{"op": "summon", "card_id": RAT_TOKEN, "count": 1.0, "position": "end"}]})
	assert_str(boss["passive_text"]["key"]).is_equal("boss.boss_rat_king.passive")
	assert_str(boss["passive_text"]["en"]).is_equal("At the start of the boss's turn, summon a 1/1 Rat.")
	assert_array(Array(boss["tags"])).is_equal(["swarm"])
	assert_str(boss["ai_profile"]).is_equal("boss_rat_king")
	assert_str(boss["intro_text"]["key"]).is_equal("boss.boss_rat_king.intro")
	assert_str(boss["intro_text"]["en"]).contains("Rat")


func test_gatekeeper_is_the_cn3_b1_row() -> void:
	# Act
	var boss: Dictionary = _boss_or_empty(_loaded(), "boss_gatekeeper")

	# Assert
	assert_bool(boss.is_empty()).is_false()
	if boss.is_empty():
		return
	assert_str(boss["name"]).is_equal("The Gatekeeper")
	assert_int(int(boss["band"])).is_equal(1)
	assert_int(int(boss["health"])).is_equal(30)
	assert_that(boss["hero_power"]).is_null()
	assert_that(boss["passive"]).is_equal({"trigger": "aura", "targets": "all_friendly_minions",
		"ops": [{"op": "aura", "keywords": ["taunt"]}]})
	assert_str(boss["passive_text"]["key"]).is_equal("boss.boss_gatekeeper.passive")
	assert_str(boss["passive_text"]["en"]).is_equal("The boss's minions have Taunt.")
	assert_array(Array(boss["tags"])).is_equal(["wall"])
	assert_str(boss["ai_profile"]).is_equal("boss_gatekeeper")
	assert_str(boss["intro_text"]["key"]).is_equal("boss.boss_gatekeeper.intro")
	assert_str(boss["intro_text"]["en"]).contains("Taunt")


func test_every_shipped_boss_ai_profile_resolves_with_zero_e_ai_rows() -> void:
	# Arrange — Boot registers the stage-7b `ai_profile` validator at merge
	# (lane 4); until then it is run here directly over every shipped boss row
	var db: CardDatabase = _loaded()
	var profiles: Dictionary = db.config("ai_profiles")
	var configs: Dictionary = {"ai_profiles": profiles}
	var bosses: Array = _all_bosses(db)

	# Act — the 7a config check with every loaded card (op coverage), then 7b per boss
	var rows: Array = BossAI.validate_profiles_config(profiles, db)
	for b: Dictionary in bosses:
		rows.append_array(BossAI.validate_ai_profile(&"boss", b["id"], b["ai_profile"], db, configs))

	# Assert — 5 MVP bosses since content story 004 (Rot Warden, Hollow King)
	assert_array(rows).is_empty()
	assert_int(bosses.size()).is_equal(5)
	for id: String in BAND1_EXTENDS:
		assert_str(profiles["boss_overrides"][id]["extends"]).is_equal(BAND1_EXTENDS[id])
		var archetype: Dictionary = profiles["profiles"][BAND1_EXTENDS[id]]
		var resolved: Dictionary = ProfileResolver.resolve(profiles, _boss_or_empty(db, id), 1)
		assert_float(float(resolved.weights.w_face)).override_failure_message(id).is_equal(float(archetype.weights.w_face))
		assert_str(String(resolved.intent_mode)).override_failure_message(id).is_equal("full")


func test_rat_king_deck_is_two_boss_cards_and_thirteen_neutrals_at_most_5_cost() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var deck: Array = _boss_or_empty(db, "boss_rat_king").get("deck", [])

	# Act
	var counts: Dictionary = _deck_counts(deck)

	# Assert — CN-3 B2
	assert_int(deck.size()).is_equal(30)
	assert_int(int(counts.get("boss_rat_pack", 0))).is_equal(2)
	assert_int(int(counts.get("boss_rat_matriarch", 0))).is_equal(2)
	for id: String in RAT_KING_NEUTRALS:
		assert_int(int(counts.get(id, 0))).override_failure_message("%s ×%d" % [id, int(counts.get(id, 0))]).is_equal(2)
	assert_int(counts.size()).is_equal(15)
	for id: String in counts:
		var card: Dictionary = _card_or_empty(db, id)
		assert_bool(card.is_empty() or card.get("token", false)).override_failure_message(id).is_false()
		if String(card.get("set", "")) == "neutral":
			assert_int(int(card["cost"])).override_failure_message(id).is_less_equal(5)
	assert_array(counts.keys()).not_contains(RAT_KING_EXCLUDED)


func test_gatekeeper_deck_is_its_b2_recipe_with_gravekeeper_back_in_its_neutrals() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var deck: Array = _boss_or_empty(db, "boss_gatekeeper").get("deck", [])

	# Act
	var counts: Dictionary = _deck_counts(deck)

	# Assert — B2 recipe: 2× each boss card + 2× each of the 13 neutrals
	assert_int(deck.size()).is_equal(30)
	assert_int(int(counts.get("boss_iron_gate", 0))).is_equal(2)
	assert_int(int(counts.get("boss_gate_warden", 0))).is_equal(2)
	for id: String in GATEKEEPER_NEUTRALS:
		assert_int(int(counts.get(id, 0))).override_failure_message("%s ×%d" % [id, int(counts.get(id, 0))]).is_equal(2)
	assert_int(counts.size()).is_equal(15)
	for id: String in counts:
		var card: Dictionary = _card_or_empty(db, id)
		assert_bool(card.is_empty() or card.get("token", false)).override_failure_message(id).is_false()


func test_the_four_band_1_boss_cards_match_cn3_b3() -> void:
	# Arrange
	var db: CardDatabase = _loaded()

	# Act / Assert
	for row: Array in BOSS_CARD_ROWS:
		var card: Dictionary = _card_or_empty(db, row[0])
		assert_bool(card.is_empty()).override_failure_message("%s missing" % row[0]).is_false()
		if card.is_empty():
			continue
		assert_str(card["set"]).is_equal("boss")
		assert_str(card["rarity"]).is_equal("common")
		assert_str(card["type"]).override_failure_message(row[0]).is_equal(TYPE[row[1]])
		assert_int(int(card["cost"])).override_failure_message(row[0]).is_equal(row[2])
		assert_int(int(card["attack"])).override_failure_message(row[0]).is_equal(row[3])
		assert_int(int(card["health"])).override_failure_message(row[0]).is_equal(row[4])
		assert_array(Array(card["keywords"])).override_failure_message(row[0]).is_equal(row[5])
		assert_str(card["text"]["en"]).override_failure_message(row[0]).is_equal(row[6])
		assert_str(card["text"]["key"]).is_equal("card.%s.text" % row[0])
		assert_bool(card.get("token", false)).is_false()
	var matriarch: Dictionary = _card_or_empty(db, "boss_rat_matriarch")
	if not matriarch.is_empty():
		assert_that(matriarch["effects"][0]["targets"]).is_equal({"selector": "all_friendly_minions", "filter": {"tag": "rat"}})


func test_boss_rat_is_a_1_1_rat_token_summoned_by_the_passive_and_rat_pack_and_never_listed() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var rat: Dictionary = _card_or_empty(db, RAT_TOKEN)
	var pack: Dictionary = _card_or_empty(db, "boss_rat_pack")

	# Assert — CN-2 tokens line; AC-16
	assert_bool(rat.is_empty() or pack.is_empty()).is_false()
	if rat.is_empty() or pack.is_empty():
		return
	assert_str(rat["set"]).is_equal("boss")
	assert_str(rat["type"]).is_equal("minion")
	assert_str(rat["name"]).is_equal("Rat")
	assert_int(int(rat["cost"])).is_equal(1)
	assert_int(int(rat["attack"])).is_equal(1)
	assert_int(int(rat["health"])).is_equal(1)
	assert_array(Array(rat["tags"])).is_equal(["rat"])
	assert_bool(rat["token"]).is_true()
	assert_bool(_boss_or_empty(db, RAT_TOKEN).is_empty()).is_true()
	assert_str(pack["effects"][0]["ops"][0]["card_id"]).is_equal(RAT_TOKEN)
	assert_int(int(pack["effects"][0]["ops"][0]["count"])).is_equal(2)
	for b: Dictionary in _all_bosses(db):
		assert_array(Array(b["deck"])).override_failure_message(b["id"]).not_contains([RAT_TOKEN])
	assert_array(_ids(db.collectible_pool("war"))).not_contains([RAT_TOKEN])
	for bundle: Dictionary in db.bundle_pool("war"):
		assert_array(Array(bundle["cards"])).not_contains([RAT_TOKEN])


func test_smite_or_mend_is_the_cn2_row_33_choose_one_and_the_neutral_set_is_15() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var card: Dictionary = _card_or_empty(db, "neutral_smite_or_mend")

	# Assert — CN-1's 15 MVP neutrals, `neutral_gravekeeper` included (story 010)
	assert_int(db.cards_by_set("neutral").size()).is_equal(15)
	assert_bool(card.is_empty()).is_false()
	if card.is_empty():
		return
	assert_str(card["name"]).is_equal("Smite or Mend")
	assert_str(card["type"]).is_equal("spell")
	assert_int(int(card["cost"])).is_equal(2)
	assert_str(card["rarity"]).is_equal("common")
	assert_array(Array(card["keywords"])).is_empty()
	assert_array(Array(card["tags"])).is_equal(["tricks"])
	assert_str(card["text"]["en"]).is_equal("Choose One — Deal 2 damage to a character; or Restore 4 Health to it.")
	var effect: Dictionary = card["effects"][0]
	assert_str(effect["trigger"]).is_equal("cast")
	assert_that(effect["targets"]).is_equal({"selector": "chosen", "filter": {"kind": "any"}})
	assert_str(effect["ops"][0]["op"]).is_equal("choose_one")
	assert_int(effect["ops"][0]["options"].size()).is_equal(2)


func test_band_1_boss_passives_and_new_cards_pass_validate_effects_with_zero_rows() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var caps: Dictionary = db.config("card_effects")
	var rows: Array = []

	# Act — both passives, the boss set (token included) and the neutral set
	for id: String in ["boss_rat_king", "boss_gatekeeper"]:
		var boss: Dictionary = _boss_or_empty(db, id)
		if boss.is_empty():
			rows.append({"missing": id})
		else:
			rows.append_array(EffectValidator.validate_effects(&"boss", id, [boss["passive"]], db, caps))
	for c: Dictionary in db.cards_by_set("boss") + db.cards_by_set("neutral"):
		rows.append_array(EffectValidator.validate_effects(&"card", c["id"], c["effects"], db, caps))

	# Assert — zero E_FX_* and W_FX_* (the matriarch's board `tag` filter included);
	# 11 boss-set cards since content story 004 adds the band-2/3 four
	assert_array(rows).is_empty()
	assert_int(db.cards_by_set("boss").size()).is_equal(11)


# --- story 005: the 10 MVP bundles (CN-4, AC-14, AC-15) ------------------------------------

## CN-4 MVP rows: id → [name, set, theme, cards].
const MVP_BUNDLES: Dictionary = {
	"bundle_war_weapons_1": ["Whetted Steel", "war", "weapons", ["war_sharpen", "war_rusted_axe", "war_blade_apprentice"]],
	"bundle_war_weapons_2": ["Armoury", "war", "weapons", ["war_blade_strike", "war_heavy_maul", "war_quartermaster"]],
	"bundle_war_weapons_3": ["Kingsguard", "war", "weapons", ["war_duelists_edge", "war_twin_hatchets", "war_kingsblade"]],
	"bundle_war_aggro_1": ["First Blood", "war", "aggro", ["war_cellar_raider", "war_warcry", "war_pit_brawler"]],
	"bundle_war_aggro_2": ["The Pit", "war", "aggro", ["war_berserker", "war_rally", "war_pit_champion"]],
	"bundle_war_aggro_3": ["Warband", "war", "aggro", ["war_warlord", "war_headsman", "war_cleave_through"]],
	"bundle_war_armour_1": ["Shield Wall", "war", "armour", ["war_shield_squire", "war_iron_resolve", "war_iron_vanguard"]],
	"bundle_war_armour_2": ["Bulwark", "war", "armour", ["war_armorer", "war_shieldwall_veteran", "war_shield_maiden"]],
	"bundle_neutral_wall": ["Hold the Line", "neutral", "wall", ["neutral_lantern_bearer", "neutral_bulwark_smith", "neutral_shield_golem"]],
	"bundle_neutral_tempo": ["Quick March", "neutral", "tempo", ["neutral_tunnel_rat", "neutral_wolf_rider", "neutral_banner_captain"]],
}
## Heroes H-5 War plan tags (Reward Draft's pity rule wants ≥ 2 bundles each).
const WAR_PLAN_TAGS: Array[String] = ["weapons", "aggro", "armour"]
## CN-4 / AC-15: War's F2 band split, 3 early / 3 mid / 2 late.
const WAR_BAND_SPLIT: Dictionary = {"early": 3, "mid": 3, "late": 2}
## Reward Draft F5 at MVP: `B_min = 9` for any `W ≥ 2` (reward-draft.md F5).
## Reward Draft has no config validator yet, so `bundle_pool_min` is not
## registered; story 005 AC-3 checks against this GDD value (sprint-004
## Goal Prerequisites, option (a)).
const REWARD_DRAFT_MVP_BUNDLE_POOL_MIN: int = 9


func _band(bundle: Dictionary, db: CardDatabase, curve: Dictionary) -> String:
	var total: int = 0
	for id: String in bundle["cards"]:
		total += int(db.card(id)["cost"])
	var avg: float = float(total) / Array(bundle["cards"]).size()
	if avg <= float(curve["early_max"]):
		return "early"
	return "mid" if avg <= float(curve["mid_max"]) else "late"


func test_bundles_json_is_the_ten_cn4_mvp_bundles_with_set_theme_and_pitch() -> void:
	# Arrange
	var expected: Array = MVP_BUNDLES.keys()
	expected.sort()

	# Act
	var db: CardDatabase = _loaded()
	var pool: Array = db.bundle_pool("war")

	# Assert — CN-4 rows verbatim; 8 war + 2 neutral; cards share set and theme
	assert_array(_ids(pool)).is_equal(expected)
	assert_int(pool.filter(func(b: Dictionary) -> bool: return b["set"] == "war").size()).is_equal(8)
	assert_int(pool.filter(func(b: Dictionary) -> bool: return b["set"] == "neutral").size()).is_equal(2)
	for b: Dictionary in pool:
		var row: Array = MVP_BUNDLES[b["id"]]
		var id: String = b["id"]
		assert_str(b["name"]).override_failure_message(id).is_equal(row[0])
		assert_str(b["set"]).override_failure_message(id).is_equal(row[1])
		assert_str(b["theme"]).override_failure_message(id).is_equal(row[2])
		assert_array(Array(b["cards"])).override_failure_message(id).is_equal(row[3])
		assert_that(b["unlock"]).override_failure_message(id).is_null()
		assert_str(b["text"]["key"]).override_failure_message(id).is_equal("bundle.%s.text" % id)
		var en: String = b["text"]["en"]
		assert_bool(en.is_empty() or en.contains("\n")).override_failure_message(id).is_false()
		for card_id: String in b["cards"]:
			var card: Dictionary = db.card(card_id)
			assert_str(card["set"]).override_failure_message(card_id).is_equal(b["set"])
			assert_bool(Array(card["tags"]).has(b["theme"])).override_failure_message(card_id).is_true()
			assert_bool(card.get("token", false)).override_failure_message(card_id).is_false()
	for e: Dictionary in db.report().entries():
		assert_bool(["E_COUNT", "E_TOKEN_IN_LIST", "E_TAG_MISMATCH"].has(String(e.code))).override_failure_message(str(e)).is_false()


func test_mvp_bundles_cover_every_war_signature_and_plan_tag_with_a_3_3_2_band_split() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var curve: Dictionary = db.config("content_budgets")["curve"]
	var war: Array = db.bundle_pool("war").filter(func(b: Dictionary) -> bool: return b["set"] == "war")

	# Act
	var bundled: Dictionary = {}
	var per_theme: Dictionary = {}
	var per_band: Dictionary = {}
	for b: Dictionary in war:
		for id: String in b["cards"]:
			bundled[id] = true
		per_theme[b["theme"]] = int(per_theme.get(b["theme"], 0)) + 1
		var band: String = _band(b, db, curve)
		per_band[band] = int(per_band.get(band, 0)) + 1

	# Assert — AC-14 coverage and plan tags; AC-15 F2 band split (cut-offs from content_budgets)
	for id: String in WAR_SIGNATURES:
		assert_bool(bundled.has(id)).override_failure_message(id).is_true()
	for tag: String in WAR_PLAN_TAGS:
		assert_int(int(per_theme.get(tag, 0))).override_failure_message(tag).is_greater_equal(2)
	assert_that(per_band).is_equal(WAR_BAND_SPLIT)


func test_mvp_bundles_clear_the_f5_war_bundle_coverage_floor() -> void:
	# Arrange
	var db: CardDatabase = _loaded()

	# Act
	var rows: Array[Dictionary] = ContentValidator.run_checks(db, db.config("content_budgets"), db.config("heroes_balance"))

	# Assert — 17 / 18 non-starter War cards bundled (war_throwing_axe is the
	# Edge Cases Discover-only card), above coverage.bundle_coverage_min 0.90
	for r: Dictionary in rows:
		assert_str(String(r.field)).override_failure_message(str(r)).is_not_equal("coverage.bundle_coverage_min.war")


func test_min_bundle_pool_meets_the_mvp_bundle_pool_min_and_the_war_pool_raises_no_pool_size() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var min_bundle_pool: int = int(db.config("card_database")["min_bundle_pool"])
	# Reward Draft F5 `B_min = 3 + (F − 2) + 2 × min(F − 2, W)` over the shipped knobs
	var floors: int = int(db.config("run_structure")["floors_per_run"])
	var reoffer: int = int(db.config("reward_draft")["reoffer_after_floors"])
	var b_min: int = 3 + (floors - 2) + 2 * mini(floors - 2, reoffer)

	# Act
	var pool_size: int = db.bundle_pool("war").size()

	# Assert — AC-3 against the GDD value (bundle_pool_min is not registered yet)
	assert_int(b_min).is_equal(REWARD_DRAFT_MVP_BUNDLE_POOL_MIN)
	assert_int(min_bundle_pool).is_greater_equal(REWARD_DRAFT_MVP_BUNDLE_POOL_MIN)
	assert_int(pool_size).is_equal(10)
	assert_int(pool_size).is_greater_equal(min_bundle_pool)
	for w: Dictionary in db.report().warnings():
		assert_bool(String(w.code) == "W_POOL_SIZE" and String(w.file) == "bundles.json").override_failure_message(str(w)).is_false()


# --- story 004: The Rot Warden (band 2), The Hollow King (band 3), decay_husk ---------------

## CN-3 B2 Rot Warden MVP recipe: 2× 12 MVP neutrals led by `neutral_gravekeeper`
## and `neutral_shield_golem`, plus the other 10 (story 004 Implementation
## Notes). `neutral_crypt_brute` gave Gravekeeper its two slots back (content
## story 010, DD-X20); the exclusions stand (DD-X24).
const ROT_WARDEN_NEUTRALS: Array[String] = [
	"neutral_gravekeeper", "neutral_shield_golem", "neutral_torch_imp", "neutral_tunnel_rat",
	"neutral_cellar_guard", "neutral_lantern_bearer", "neutral_bulwark_smith", "neutral_dungeon_delver",
	"neutral_hush_owl", "neutral_spark_fiend", "neutral_banner_captain", "neutral_wolf_rider",
]
const ROT_WARDEN_EXCLUDED: Array[String] = ["neutral_crypt_brute", "neutral_ogre_porter", "neutral_smite_or_mend"]
## CN-3 B2 Hollow King MVP-1 recipe's 11 neutrals, `neutral_gravekeeper` back in
## them (content story 010, DD-X20).
const HOLLOW_KING_NEUTRALS: Array[String] = [
	"neutral_shield_golem", "neutral_lantern_bearer", "neutral_bulwark_smith", "neutral_crypt_brute",
	"neutral_ogre_porter", "neutral_dungeon_delver", "neutral_cellar_guard", "neutral_banner_captain",
	"neutral_gravekeeper", "neutral_hush_owl", "neutral_torch_imp",
]
## CN-3 B3: [id, T, cost, a, h, keywords, text].
const BOSS_CARD_ROWS_B23: Array = [
	["boss_rot_zombie", "M", 3, 2, 3, ["deathrattle"], "Deathrattle: Summon a 1/1 Husk."],
	["boss_mass_rites", "S", 4, -1, -1, [], "Trigger the Deathrattles of all friendly minions."],
	["boss_hollow_knight", "M", 4, 3, 4, ["divine_shield"], "Divine Shield."],
	["boss_crown_of_thorns", "S", 3, -1, -1, [], "Give your minions +1/+1 and Taunt."],
]
const HUSK_TOKEN: String = "decay_husk"


func test_bands_2_and_3_hold_the_rot_warden_and_the_hollow_king() -> void:
	# Act
	var db: CardDatabase = _loaded()

	# Assert — CN-3 MVP: 3 / 1 / 1 bosses by band
	assert_array(_ids(db.bosses_in_band(2))).is_equal(["boss_rot_warden"])
	assert_array(_ids(db.bosses_in_band(3))).is_equal(["boss_hollow_king"])


func test_rot_warden_is_the_cn3_b1_row() -> void:
	# Act
	var boss: Dictionary = _boss_or_empty(_loaded(), "boss_rot_warden")

	# Assert
	assert_bool(boss.is_empty()).is_false()
	if boss.is_empty():
		return
	assert_str(boss["name"]).is_equal("The Rot Warden")
	assert_int(int(boss["band"])).is_equal(2)
	assert_int(int(boss["health"])).is_equal(40)
	assert_that(boss["hero_power"]).is_null()
	assert_that(boss["passive"]).is_equal({"trigger": "on_minion_died", "scope": {"who": "friendly_minion"},
		"targets": "enemy_hero", "ops": [{"op": "damage", "amount": 1.0}]})
	assert_str(boss["passive_text"]["key"]).is_equal("boss.boss_rot_warden.passive")
	assert_str(boss["passive_text"]["en"]).is_equal("Whenever a boss minion dies, deal 1 damage to the enemy hero.")
	assert_array(Array(boss["tags"])).is_equal(["deathrattle"])
	assert_str(boss["ai_profile"]).is_equal("boss_rot_warden")
	assert_str(boss["intro_text"]["key"]).is_equal("boss.boss_rot_warden.intro")
	assert_str(boss["intro_text"]["en"]).contains("dies")


func test_hollow_king_is_the_cn3_b1_row() -> void:
	# Act
	var boss: Dictionary = _boss_or_empty(_loaded(), "boss_hollow_king")

	# Assert
	assert_bool(boss.is_empty()).is_false()
	if boss.is_empty():
		return
	assert_str(boss["name"]).is_equal("The Hollow King")
	assert_int(int(boss["band"])).is_equal(3)
	assert_int(int(boss["health"])).is_equal(50)
	assert_that(boss["hero_power"]).is_null()
	assert_that(boss["passive"]).is_equal({"trigger": "turn_start", "scope": {"side": "owner"},
		"targets": "all_friendly_minions", "ops": [{"op": "buff", "attack": 1.0, "health": 1.0}]})
	assert_str(boss["passive_text"]["key"]).is_equal("boss.boss_hollow_king.passive")
	assert_str(boss["passive_text"]["en"]).is_equal("At the start of the boss's turn, give the boss's minions +1/+1.")
	assert_array(Array(boss["tags"])).is_equal(["wall"])
	assert_str(boss["ai_profile"]).is_equal("boss_hollow_king")
	assert_str(boss["intro_text"]["key"]).is_equal("boss.boss_hollow_king.intro")
	assert_str(boss["intro_text"]["en"]).contains("+1/+1")


func test_rot_warden_and_hollow_king_profiles_resolve_through_their_overrides_with_zero_e_ai_rows() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var profiles: Dictionary = db.config("ai_profiles")
	var rot: Dictionary = _boss_or_empty(db, "boss_rot_warden")
	var hollow: Dictionary = _boss_or_empty(db, "boss_hollow_king")
	assert_bool(rot.is_empty() or hollow.is_empty()).is_false()
	if rot.is_empty() or hollow.is_empty():
		return

	# Act — stage 7b as Boot registers it, and the F9 resolution
	var rows: Array = BossAI.validate_ai_profile(&"boss", rot["id"], rot["ai_profile"], db, {"ai_profiles": profiles})
	rows.append_array(BossAI.validate_ai_profile(&"boss", hollow["id"], hollow["ai_profile"], db, {"ai_profiles": profiles}))
	var rot_profile: Dictionary = ProfileResolver.resolve(profiles, rot, 2)
	var hollow_profile: Dictionary = ProfileResolver.resolve(profiles, hollow, 3)

	# Assert — zero E_AI_* directly and through the load; B1 override column
	assert_array(rows).is_empty()
	for e: Dictionary in db.report().entries():
		assert_bool(String(e.code).begins_with("E_AI_")).override_failure_message(str(e)).is_false()
	assert_str(profiles["boss_overrides"]["boss_rot_warden"]["extends"]).is_equal("passive_driven")
	assert_str(profiles["boss_overrides"]["boss_hollow_king"]["extends"]).is_equal("control")
	assert_float(float(rot_profile.weights.w_self)).is_equal(1.5)
	assert_array(Array(rot_profile.synergy_tags)).is_equal(["deathrattle"])
	assert_float(float(hollow_profile.weights.w_board)).is_equal(3.0)
	assert_str(String(rot_profile.get("intent_mode", "full"))).is_not_equal("hidden")
	assert_str(String(hollow_profile.get("intent_mode", "full"))).is_not_equal("hidden")


func test_rot_warden_deck_is_its_mvp_recipe_led_by_gravekeeper() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var deck: Array = _boss_or_empty(db, "boss_rot_warden").get("deck", [])

	# Act
	var counts: Dictionary = _deck_counts(deck)

	# Assert — CN-3 B2 MVP recipe: rot_zombie ×3, mass_rites ×3, 12 neutrals ×2
	assert_int(deck.size()).is_equal(30)
	assert_int(int(counts.get("boss_rot_zombie", 0))).is_equal(3)
	assert_int(int(counts.get("boss_mass_rites", 0))).is_equal(3)
	for id: String in ROT_WARDEN_NEUTRALS:
		assert_int(int(counts.get(id, 0))).override_failure_message("%s ×%d" % [id, int(counts.get(id, 0))]).is_equal(2)
	assert_int(counts.size()).is_equal(14)
	assert_array(counts.keys()).not_contains(ROT_WARDEN_EXCLUDED)
	for id: String in counts:
		var card: Dictionary = _card_or_empty(db, id)
		assert_bool(card.is_empty() or card.get("token", false)).override_failure_message(id).is_false()


func test_hollow_king_deck_is_its_mvp1_recipe_with_gravekeeper_back_in_its_neutrals() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var deck: Array = _boss_or_empty(db, "boss_hollow_king").get("deck", [])

	# Act
	var counts: Dictionary = _deck_counts(deck)

	# Assert — CN-3 B2 MVP-1 recipe: every id ×2
	assert_int(deck.size()).is_equal(30)
	assert_int(int(counts.get("boss_hollow_knight", 0))).is_equal(2)
	assert_int(int(counts.get("boss_crown_of_thorns", 0))).is_equal(2)
	assert_int(int(counts.get("war_shield_maiden", 0))).is_equal(2)
	assert_int(int(counts.get("war_shieldwall_veteran", 0))).is_equal(2)
	for id: String in HOLLOW_KING_NEUTRALS:
		assert_int(int(counts.get(id, 0))).override_failure_message("%s ×%d" % [id, int(counts.get(id, 0))]).is_equal(2)
	assert_int(counts.size()).is_equal(15)
	for id: String in counts:
		var card: Dictionary = _card_or_empty(db, id)
		assert_bool(card.is_empty() or card.get("token", false)).override_failure_message(id).is_false()


func test_the_four_band_2_and_3_boss_cards_match_cn3_b3() -> void:
	# Arrange
	var db: CardDatabase = _loaded()

	# Act / Assert
	for row: Array in BOSS_CARD_ROWS_B23:
		var card: Dictionary = _card_or_empty(db, row[0])
		assert_bool(card.is_empty()).override_failure_message("%s missing" % row[0]).is_false()
		if card.is_empty():
			continue
		assert_str(card["set"]).is_equal("boss")
		assert_str(card["rarity"]).is_equal("common")
		assert_str(card["type"]).override_failure_message(row[0]).is_equal(TYPE[row[1]])
		assert_int(int(card["cost"])).override_failure_message(row[0]).is_equal(row[2])
		if row[1] == "M":
			assert_int(int(card["attack"])).override_failure_message(row[0]).is_equal(row[3])
			assert_int(int(card["health"])).override_failure_message(row[0]).is_equal(row[4])
		assert_array(Array(card["keywords"])).override_failure_message(row[0]).is_equal(row[5])
		assert_str(card["text"]["en"]).override_failure_message(row[0]).is_equal(row[6])
		assert_str(card["text"]["key"]).is_equal("card.%s.text" % row[0])
		assert_bool(card.get("token", false)).is_false()
	var rites: Dictionary = _card_or_empty(db, "boss_mass_rites")
	if not rites.is_empty():
		assert_that(rites["effects"]).is_equal([{"trigger": "cast", "targets": "all_friendly_minions",
			"ops": [{"op": "retrigger", "trigger": "deathrattle"}]}])
	var crown: Dictionary = _card_or_empty(db, "boss_crown_of_thorns")
	if not crown.is_empty():
		assert_that(crown["effects"]).is_equal([{"trigger": "cast", "targets": "all_friendly_minions",
			"ops": [{"op": "buff", "attack": 1.0, "health": 1.0}, {"op": "give_keyword", "keyword": "taunt"}]}])


func test_decay_husk_is_the_one_decay_record_a_1_1_token_summoned_by_rot_zombie_and_never_listed() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var husk: Dictionary = _card_or_empty(db, HUSK_TOKEN)
	var zombie: Dictionary = _card_or_empty(db, "boss_rot_zombie")

	# Assert — CN-2 tokens line; CN-6 MVP-1 one-record cards_decay.json; AC-16
	assert_array(_ids(db.cards_by_set("decay"))).is_equal([HUSK_TOKEN])
	assert_bool(husk.is_empty() or zombie.is_empty()).is_false()
	if husk.is_empty() or zombie.is_empty():
		return
	assert_str(husk["name"]).is_equal("Husk")
	assert_str(husk["type"]).is_equal("minion")
	assert_int(int(husk["cost"])).is_equal(1)
	assert_int(int(husk["attack"])).is_equal(1)
	assert_int(int(husk["health"])).is_equal(1)
	assert_array(Array(husk["tags"])).is_equal(["husk"])
	assert_bool(husk["token"]).is_true()
	assert_that(zombie["effects"]).is_equal([{"trigger": "deathrattle",
		"ops": [{"op": "summon", "card_id": HUSK_TOKEN, "count": 1.0, "position": "source_slot"}]}])
	for b: Dictionary in _all_bosses(db):
		assert_array(Array(b["deck"])).override_failure_message(b["id"]).not_contains([HUSK_TOKEN])
	assert_array(_ids(db.collectible_pool("war"))).not_contains([HUSK_TOKEN])
	for bundle: Dictionary in db.bundle_pool("war"):
		assert_array(Array(bundle["cards"])).not_contains([HUSK_TOKEN])
	# a hero set present with no HeroDef: stage 8 computes pools per heroes.json set only
	for e: Dictionary in db.report().entries():
		var on_decay: bool = String(e.file) == "cards_decay.json" or String(e.message).contains("decay")
		assert_bool(on_decay and ["E_COUNT", "W_POOL_SIZE"].has(String(e.code))).override_failure_message(str(e)).is_false()


func test_band_2_and_3_passives_and_new_cards_pass_validate_effects_with_zero_rows() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var caps: Dictionary = db.config("card_effects")
	var rows: Array = []

	# Act — both passives (on_minion_died on a passive host is a C9 observer),
	# the boss set and the decay set
	for id: String in ["boss_rot_warden", "boss_hollow_king"]:
		var boss: Dictionary = _boss_or_empty(db, id)
		if boss.is_empty():
			rows.append({"missing": id})
		else:
			rows.append_array(EffectValidator.validate_effects(&"boss", id, [boss["passive"]], db, caps))
	for c: Dictionary in db.cards_by_set("boss") + db.cards_by_set("decay"):
		rows.append_array(EffectValidator.validate_effects(&"card", c["id"], c["effects"], db, caps))

	# Assert — zero E_FX_* and W_FX_*; the load stays Ready with zero errors
	assert_array(rows).is_empty()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)
	assert_array(db.report().errors()).is_empty()


# --- story 010: Gravekeeper returns to the boss decks (DD-X20) -------------------------------

## CN-2 row: [id, name, T, cost, a, h, keywords, text, R, tags].
const GRAVEKEEPER_ROW: Array = [
	"neutral_gravekeeper", "Gravekeeper", "M", 3, 2, 3, ["deathrattle"],
	"Deathrattle: Deal 1 damage to the enemy hero per minion that died while this was in play.", "R", ["pings"],
]
const CARD_EFFECTS_GDD: String = "res://design/gdd/card-effects.md"
const GRAVEKEEPER: String = "neutral_gravekeeper"
const VANILLA: String = "neutral_test_vanilla"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS


## `has` / `card` / `hero_power` from a map: the engine and the resolver ask
## nothing else in a match, and `MatchFactory`'s decks are fixture ids.
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


## The `effects[]` the C11 table gives on row [param row]: its backticked JSON
## objects, parsed, so a design change that is not mirrored in the data fails.
func _c11_effects(row: int) -> Array:
	var out: Array = []
	for line: String in FileAccess.get_file_as_string(CARD_EFFECTS_GDD).split("\n"):
		if line.begins_with("| %d |" % row):
			for m: RegExMatch in RegEx.create_from_string("`(\\{.*?\\})`").search_all(line):
				out.append(JSON.parse_string(m.get_string(1)))
	return out


func test_gravekeeper_is_the_cn2_row_with_c11_row_45_verbatim() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var row: Array = GRAVEKEEPER_ROW
	var expected_effects: Array = _c11_effects(45)

	# Act
	var card: Dictionary = _card_or_empty(db, row[0])

	# Assert — the two C11 effects, `text.en` from CN-2 (it fits text_max_chars)
	assert_int(expected_effects.size()).is_equal(2)
	assert_bool(card.is_empty()).is_false()
	if card.is_empty():
		return
	assert_str(card["name"]).is_equal(row[1])
	assert_str(card["set"]).is_equal("neutral")
	assert_str(card["type"]).is_equal(TYPE[row[2]])
	assert_int(int(card["cost"])).is_equal(row[3])
	assert_int(int(card["attack"])).is_equal(row[4])
	assert_int(int(card["health"])).is_equal(row[5])
	assert_array(Array(card["keywords"])).is_equal(row[6])
	assert_str(card["text"]["key"]).is_equal("card.neutral_gravekeeper.text")
	assert_str(card["text"]["en"]).is_equal(row[7])
	assert_str(card["rarity"]).is_equal(RARITY[row[8]])
	assert_array(Array(card["tags"])).is_equal(row[9])
	assert_str(JSON.stringify(card["effects"], "", true)).is_equal(JSON.stringify(expected_effects, "", true))


func test_gravekeeper_validates_with_zero_fx_rows_and_zero_e_ai_op_unvalued() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var card: Dictionary = _card_or_empty(db, GRAVEKEEPER)
	assert_bool(card.is_empty()).is_false()
	if card.is_empty():
		return

	# Act — zero E_AI_OP_UNVALUED: the config check runs over every loaded card
	var fx_rows: Array = EffectValidator.validate_effects(&"card", GRAVEKEEPER, card["effects"], db, db.config("card_effects"))
	var ai_rows: Array = BossAI.validate_profiles_config(db.config("ai_profiles"), db)

	# Assert
	assert_array(fx_rows).is_empty()
	assert_array(ai_rows).is_empty()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_shipped_gravekeeper_deals_the_minions_that_died_in_play_to_the_enemy_hero() -> void:
	# Arrange — the shipped record on the real engine and resolver; three
	# minions, either side, die while it is in play (QA plan runtime check,
	# card-effects AC-46 on shipped data)
	var loaded: CardDatabase = _loaded()
	var shipped: Dictionary = _card_or_empty(loaded, GRAVEKEEPER)
	assert_bool(shipped.is_empty()).is_false()
	if shipped.is_empty():
		return
	var by_id: Dictionary = {GRAVEKEEPER: shipped, VANILLA: CardFactory.make_minion(VANILLA, 1, 1, 1)}
	for record: Dictionary in CardFactory.make_fixture_card_set():
		by_id[record.id] = record
	var db: FakeCardDatabase = FakeCardDatabase.new(by_id)
	var event_log: TestEventLog = TestEventLog.new()
	var resolver: EffectResolver = EffectResolver.new(db, loaded.config("card_effects"))
	var engine: RulesEngine = RulesEngine.new(db, MatchFactory.make_rules_config(), resolver)
	engine.start(MatchFactory.make_started_config(TestRngService.new(), event_log))
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var state: MatchState = engine.state()
	var keeper: int = int(MatchFactory.summon(state, SIDE_PLAYER, 2, 3, -1, ["deathrattle"], GRAVEKEEPER).entity_id)
	var fodder: Array = [
		int(MatchFactory.summon(state, SIDE_PLAYER, 1, 1, -1, [], VANILLA).entity_id),
		int(MatchFactory.summon(state, SIDE_BOSS, 1, 1, -1, [], VANILLA).entity_id),
		int(MatchFactory.summon(state, SIDE_BOSS, 1, 1, -1, [], VANILLA).entity_id),
	]
	var destroy: Callable = func(ids: Array) -> void:
		engine.run_action(func() -> void:
			for id: Variant in ids:
				engine.destroy(int(id)))
	destroy.call(fodder)
	var before: int = int(event_log.events[-1].seq)

	# Act
	destroy.call([keeper])

	# Assert
	var hits: Array = event_log.events.filter(func(e: Dictionary) -> bool:
		return int(e.seq) > before and str(e.type) == "damage_dealt")
	assert_int(hits.size()).is_equal(1)
	assert_int(int(hits[0].payload.target)).is_equal(int(state.players[SIDE_BOSS].hero.entity_id))
	assert_int(int(hits[0].payload.dealt)).is_equal(3)
	engine.end_match()
