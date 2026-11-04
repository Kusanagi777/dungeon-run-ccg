## Integration: the shipped batch-0 data set (content story 001; content.md
## CN-2 / CN-3 B1-B3 / CN-4 / CN-6 steps 2-3, heroes.md H-2 / H-3 / H-4 / F1).
##
## Loads `res://assets/data/` once per test through the real `DataLoader` +
## `CardDatabase` with the validator map `Boot` composes (a fresh, `auto_free`d
## Boot instance, never the autoload; debug severity), so every `effects[]`
## and the boss `passive` go through the real `EffectValidator`, the boss
## `ai_profile` through the real `BossAI` config validator, and the pending
## owners report `W_VALIDATOR_PENDING` warnings. Every expected id below is a
## GDD row, quoted; counts are the point of the test.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SHIPPED: String = "res://assets/data/"

## CN-2 War table: the 7 starters (★) + `war_iron_resolve`; tokens line.
const WAR_COLLECTIBLE: Array[String] = [
	"war_iron_resolve", "war_iron_vanguard", "war_pit_brawler", "war_quartermaster",
	"war_rusted_axe", "war_sharpen", "war_shield_squire", "war_warcry",
]
const WAR_TOKEN: String = "war_whetstone_blade"
## CN-2 neutral table, the batch-0 rows (`neutral_gravekeeper` deferred to
## MVP-1, story 001 deviation 2026-11-04; `neutral_smite_or_mend` is story 003).
const NEUTRALS: Array[String] = [
	"neutral_banner_captain", "neutral_bulwark_smith", "neutral_cellar_guard", "neutral_crypt_brute",
	"neutral_dungeon_delver", "neutral_hush_owl", "neutral_lantern_bearer", "neutral_ogre_porter",
	"neutral_shield_golem", "neutral_spark_fiend", "neutral_torch_imp", "neutral_tunnel_rat",
	"neutral_wolf_rider",
]
## Heroes H-4, War column.
const WAR_STARTER: Array[String] = [
	"neutral_tunnel_rat", "neutral_tunnel_rat", "war_shield_squire", "war_sharpen",
	"neutral_cellar_guard", "neutral_cellar_guard", "war_rusted_axe", "war_warcry",
	"neutral_dungeon_delver", "neutral_dungeon_delver", "war_iron_vanguard", "war_quartermaster",
	"neutral_crypt_brute", "war_pit_brawler", "neutral_ogre_porter",
]
## CN-3 B2 Torchbearer recipe's 13 neutrals (Gravekeeper → Ogre Porter, deviation).
const TORCH_NEUTRALS: Array[String] = [
	"neutral_tunnel_rat", "neutral_wolf_rider", "neutral_banner_captain", "neutral_spark_fiend",
	"neutral_torch_imp", "neutral_cellar_guard", "neutral_lantern_bearer", "neutral_bulwark_smith",
	"neutral_dungeon_delver", "neutral_hush_owl", "neutral_ogre_porter", "neutral_shield_golem",
	"neutral_crypt_brute",
]
## CN-4 batch-0 bundles: id → [set, theme, cards].
const BUNDLES: Dictionary = {
	"bundle_neutral_tempo": ["neutral", "tempo", ["neutral_tunnel_rat", "neutral_wolf_rider", "neutral_banner_captain"]],
	"bundle_neutral_wall": ["neutral", "wall", ["neutral_lantern_bearer", "neutral_bulwark_smith", "neutral_shield_golem"]],
	"bundle_war_armour_1": ["war", "armour", ["war_shield_squire", "war_iron_resolve", "war_iron_vanguard"]],
}


## The files whose pending validator reports on this batch, derived from Boot:
## one per `PENDING_CONFIG_OWNERS` config, plus `bosses.json` while the
## `ai_profile` record kind is pending (no treasures ship, so `treasure` never
## runs). Sorted. Derived, so the orchestrator's registrations keep it true.
func _pending_files() -> Array[String]:
	var out: Array[String] = []
	for name: String in BOOT_SCRIPT.PENDING_CONFIG_OWNERS:
		out.append(name + ".json")
	if BOOT_SCRIPT.PENDING_RECORD_OWNERS.has("ai_profile"):
		out.append("bosses.json")
	out.sort()
	return out


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


func _all_cards(db: CardDatabase) -> Array:
	return db.cards_by_type("minion") + db.cards_by_type("spell") + db.cards_by_type("weapon")


func _codes_in(report: ValidationReport, severity: StringName) -> Array[String]:
	var out: Array[String] = []
	for e: Dictionary in report.entries():
		if e.severity == severity:
			out.append(String(e.code))
	return out


# --- AC-1: loads clean ---------------------------------------------------------

func test_shipped_data_loads_ready_with_zero_errors() -> void:
	# Act
	var db: CardDatabase = _loaded()

	# Assert
	assert_array(db.report().errors()).is_empty()
	assert_int(db.state()).is_equal(CardDatabase.State.READY)


func test_shipped_warnings_are_pool_size_and_pending_validators_only() -> void:
	# Act
	var report: ValidationReport = _loaded().report()

	# Assert — CN-6.3 allows W_POOL_SIZE at MVP-0; every E_DELEGATED warning is
	# a pending owner's W_VALIDATOR_PENDING. No W_BAND_HEALTH: match_rules.json
	# carries boss_starting_health_by_band (DD-M02, fix pass 2026-11-04), so
	# stage 8 checks every boss and none deviates (content AC-10).
	var pool_files: Array[String] = []
	var pending_files: Array[String] = []
	for w: Dictionary in report.warnings():
		match String(w.code):
			"W_POOL_SIZE":
				pool_files.append(w.file)
			"E_DELEGATED":
				assert_str(w.message).starts_with("W_VALIDATOR_PENDING: ")
				pending_files.append(w.file)
			_:
				fail("unexpected warning %s" % str(w))
	pool_files.sort()
	pending_files.sort()
	# content story 002 (MVP-1 War set): the War collectible pool is 25 + the
	# neutrals ≥ min_collectible_pool 30, so `cards_war.json` no longer warns.
	assert_array(pool_files).is_equal(["bundles.json", "treasures.json"])
	assert_array(pending_files).is_equal(_pending_files())


# --- AC-2: War --------------------------------------------------------------------

func test_hero_war_is_the_only_hero_with_h2_values() -> void:
	# Act
	var db: CardDatabase = _loaded()

	# Assert
	assert_array(_ids(db.heroes())).is_equal(["hero_war"])
	var hero: Dictionary = db.hero("hero_war")
	assert_str(hero["name"]).is_equal("Halvard, the Whetted")
	assert_str(hero["set"]).is_equal("war")
	assert_int(int(hero["health"])).is_equal(30)
	assert_str(hero["hero_power"]).is_equal("power_whetstone")
	assert_that(hero["unlock"]).is_null()
	assert_str(hero["text"]["en"]).is_equal("Every turn, the blade. The rest is footwork.")


func test_power_whetstone_costs_2_and_carries_the_h3_effect() -> void:
	# Act
	var power: Dictionary = _loaded().hero_power("power_whetstone")

	# Assert — Heroes H-3 / card-effects C11 row 8
	assert_int(int(power["cost"])).is_equal(2)
	var op: Dictionary = power["effects"][0]["ops"][0]
	assert_str(power["effects"][0]["trigger"]).is_equal("hero_power")
	assert_str(op["op"]).is_equal("conditional")
	assert_that(op["if"]).is_equal({"exists": "owner_weapon"})
	assert_str(op["else"][0]["card_id"]).is_equal(WAR_TOKEN)
	assert_str(op["then"][0]["duration"]).is_equal("until_end_of_turn")


func test_war_set_holds_the_eight_batch0_cn2_cards_and_the_whetstone_blade_token() -> void:
	# Act
	var db: CardDatabase = _loaded()

	# Assert — batch 0's rows stay in the set (content story 002 adds the
	# other 17 MVP-1 War cards; `content_mvp1_data_test.gd` pins all 25)
	var expected: Array[String] = WAR_COLLECTIBLE.duplicate()
	expected.append(WAR_TOKEN)
	assert_array(_ids(db.cards_by_set("war"))).contains(expected)
	var blade: Dictionary = db.card(WAR_TOKEN)
	assert_str(blade["type"]).is_equal("weapon")
	assert_int(int(blade["attack"])).is_equal(1)
	assert_int(int(blade["durability"])).is_equal(2)
	assert_bool(blade["token"]).is_true()
	assert_array(_ids(db.collectible_pool("war"))).contains(WAR_COLLECTIBLE)
	assert_array(_ids(db.collectible_pool("war"))).not_contains([WAR_TOKEN])


func test_neutral_set_holds_the_batch0_rows() -> void:
	# Act / Assert — content story 003 adds `neutral_smite_or_mend`
	# (`content_mvp1_data_test.gd` pins the whole set)
	assert_array(_ids(_loaded().cards_by_set("neutral"))).contains(NEUTRALS)


func test_war_starter_is_the_h4_list_and_passes_heroes_f1() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var balance: Dictionary = db.config("heroes_balance")
	var curve: Dictionary = balance["starter_curve"]

	# Act
	var starter: Array = db.hero("hero_war")["starter_deck"]
	var buckets: Dictionary = {}
	var total: int = 0
	var max_cost: int = 0
	for id: String in starter:
		var card: Dictionary = db.card(id)
		var cost: int = int(card["cost"])
		total += cost
		max_cost = maxi(max_cost, cost)
		var key: String = str(cost) if cost < 6 else "6_plus"
		buckets[key] = int(buckets.get(key, 0)) + 1
		assert_bool(card.get("token", false)).is_false()
		assert_bool(["war", "neutral"].has(card["set"])).is_true()

	# Assert — F1 against heroes_balance.json (the E_STARTER_CURVE inputs)
	assert_array(Array(starter)).is_equal(WAR_STARTER)
	var avg: float = float(total) / starter.size()
	assert_bool(avg >= float(curve["avg_min"]) and avg <= float(curve["avg_max"])).is_true()
	assert_int(max_cost).is_less_equal(int(curve["max_cost"]))
	for key: String in curve["bucket"]:
		var count: int = int(buckets.get(key, 0))
		var allowed: Array = curve["bucket"][key]
		assert_bool(count >= int(allowed[0]) and count <= int(allowed[1])).override_failure_message(
			"bucket %s: %d not in %s" % [key, count, str(allowed)]).is_true()


# --- AC-3: The Torchbearer ------------------------------------------------------------

func test_torchbearer_is_the_cn3_b1_row() -> void:
	# Act
	var db: CardDatabase = _loaded()

	# Assert
	# content story 003 adds The Rat King and The Gatekeeper to band 1
	assert_array(_ids(db.bosses_in_band(1))).contains(["boss_torchbearer"])
	var boss: Dictionary = db.boss("boss_torchbearer")
	assert_int(int(boss["health"])).is_equal(30)
	assert_that(boss["hero_power"]).is_null()
	assert_that(boss["passive"]).is_equal({"trigger": "turn_end", "scope": {"side": "owner"},
		"targets": "enemy_hero", "ops": [{"op": "damage", "amount": 1.0}]})
	assert_str(boss["passive_text"]["key"]).is_equal("boss.boss_torchbearer.passive")
	assert_array(Array(boss["tags"])).is_equal(["burn"])
	assert_str(boss["ai_profile"]).is_equal("boss_torchbearer")
	assert_str(boss["intro_text"]["en"]).contains("1")


func test_torchbearer_ai_profile_resolves_through_its_aggro_override_with_no_e_ai_rows() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var profiles: Dictionary = db.config("ai_profiles")

	# Act — the config check with this batch's cards (op coverage) and the
	# record-level key check Boss AI will register under `ai_profile`
	var rows: Array = BossAI.validate_profiles_config(profiles, db)
	rows.append_array(BossAI.validate_ai_profile(&"boss", "boss_torchbearer", "boss_torchbearer", db, {"ai_profiles": profiles}))
	var profile: Dictionary = ProfileResolver.resolve(profiles, db.boss("boss_torchbearer"), 1)

	# Assert
	assert_array(rows).is_empty()
	assert_str(profiles["boss_overrides"]["boss_torchbearer"]["extends"]).is_equal("aggro")
	assert_float(float(profile.weights.w_face)).is_equal(float(profiles.profiles.aggro.weights.w_face))


func test_torchbearer_deck_is_thirty_non_token_ids_per_the_b2_recipe() -> void:
	# Arrange
	var db: CardDatabase = _loaded()

	# Act
	var deck: Array = db.boss("boss_torchbearer")["deck"]
	var counts: Dictionary = {}
	for id: String in deck:
		counts[id] = int(counts.get(id, 0)) + 1
		assert_bool(db.card(id).get("token", false)).is_false()

	# Assert — 2× each boss card + 2× each of the 13 neutrals
	assert_int(deck.size()).is_equal(30)
	assert_int(int(counts.get("boss_ember_bolt", 0))).is_equal(2)
	assert_int(int(counts.get("boss_tinder_imp", 0))).is_equal(2)
	for id: String in TORCH_NEUTRALS:
		assert_int(int(counts.get(id, 0))).override_failure_message("%s ×%d" % [id, int(counts.get(id, 0))]).is_equal(2)
	assert_int(counts.size()).is_equal(15)


func test_boss_cards_hold_the_two_torchbearer_b3_rows() -> void:
	# Act
	var db: CardDatabase = _loaded()

	# Assert — content story 003 adds the Rat King / Gatekeeper cards and `boss_rat`
	assert_array(_ids(db.cards_by_set("boss"))).contains(["boss_ember_bolt", "boss_tinder_imp"])
	for c: Dictionary in db.cards_by_set("boss"):
		assert_str(c["rarity"]).is_equal("common")


# --- AC-4: effects, text, lists ----------------------------------------------------------

func test_every_effect_list_passes_validate_effects_with_zero_rows() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var caps: Dictionary = db.config("card_effects")
	var rows: Array = []

	# Act — every host this batch authors (cards, the power, the boss passive)
	for c: Dictionary in _all_cards(db):
		rows.append_array(EffectValidator.validate_effects(&"card", c["id"], c["effects"], db, caps))
	var power: Dictionary = db.hero_power("power_whetstone")
	rows.append_array(EffectValidator.validate_effects(&"hero_power", power["id"], power["effects"], db, caps))
	var boss: Dictionary = db.boss("boss_torchbearer")
	rows.append_array(EffectValidator.validate_effects(&"boss", boss["id"], [boss["passive"]], db, caps))

	# Assert — no E_FX_* and no W_FX_* (CN-6.3 fixes W_FX_KEYWORD_MISMATCH before close)
	assert_array(rows).is_empty()


func test_every_text_is_at_most_text_max_chars_and_keyed_by_id() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	var limit: int = int(db.config("content_budgets")["text_max_chars"])
	var texts: Array[Dictionary] = []
	for c: Dictionary in _all_cards(db):
		texts.append({"id": c["id"], "text": c["text"]})
	texts.append({"id": "hero_war", "text": db.hero("hero_war")["text"]})
	texts.append({"id": "power_whetstone", "text": db.hero_power("power_whetstone")["text"]})
	var boss: Dictionary = db.boss("boss_torchbearer")
	texts.append({"id": "boss_torchbearer", "text": boss["passive_text"]})
	texts.append({"id": "boss_torchbearer", "text": boss["intro_text"]})
	for b: Dictionary in db.bundle_pool("war"):
		texts.append({"id": b["id"], "text": b["text"]})

	# Act / Assert
	for t: Dictionary in texts:
		var en: String = t.text["en"]
		assert_int(en.length()).override_failure_message("%s: %d chars" % [t.id, en.length()]).is_less_equal(limit)
		assert_bool(String(t.text["key"]).contains(t.id)).is_true()


func test_bundles_are_the_three_cn4_rows_with_set_theme_and_no_token() -> void:
	# Arrange
	var db: CardDatabase = _loaded()

	# Act
	var pool: Array = db.bundle_pool("war")

	# Assert
	assert_array(_ids(pool)).is_equal(BUNDLES.keys())
	for b: Dictionary in pool:
		var row: Array = BUNDLES[b["id"]]
		assert_str(b["set"]).is_equal(row[0])
		assert_str(b["theme"]).is_equal(row[1])
		assert_array(Array(b["cards"])).is_equal(row[2])
		assert_that(b["unlock"]).is_null()
		for id: String in b["cards"]:
			var card: Dictionary = db.card(id)
			assert_str(card["set"]).is_equal(b["set"])
			assert_bool(Array(card["tags"]).has(b["theme"])).is_true()
			assert_bool(card.get("token", false)).is_false()


func test_treasure_pool_is_empty_at_batch0() -> void:
	# Act / Assert — the 10 MVP treasures are story 006 (W_POOL_SIZE allowed)
	assert_array(_loaded().treasure_pool()).is_empty()
