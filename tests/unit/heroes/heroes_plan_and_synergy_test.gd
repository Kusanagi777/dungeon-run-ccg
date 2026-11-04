## Unit tests for the Heroes F2 plan-card count and F5 signature synergy (heroes
## story 003; heroes.md F2, F5, H-4, H-5, AC-3, AC-5).
##
## The counting rules run over `FakeCardDatabase` below, a `CardDatabase` subclass
## answering the three queries the formulas use from `CardFactory` records. The
## shipped figures load `res://assets/data/` through the real `DataLoader`, a read
## of committed data as `boss_ai_profile_resolver_test.gd` does: the story keeps
## them in this one file.
extends GdUnitTestSuite


class FakeCardDatabase:
	extends CardDatabase

	var _cards: Array
	var _hero: Dictionary

	func _init(cards: Array, hero_record: Dictionary) -> void:
		_cards = cards
		_hero = hero_record

	func card(id: String) -> Variant:
		for record: Dictionary in _cards:
			if record.id == id:
				return record
		return null

	func hero(_id: String) -> Variant:
		return _hero

	func cards_by_set(set_id: String) -> Array:
		return _cards.filter(func(r: Dictionary) -> bool: return r.set == set_id)


const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SHIPPED_ROOT: String = "res://assets/data/"
const HERO_WAR: String = "hero_war"
const HERO_FIXTURE: String = "hero_fixture"

## Heroes H-5: signature cards are not marked in data, so the ids are named here
## (the "exact value IS the point" exception; story 003 notes). Each with the score
## the story checked by hand, recounted independently 2026-11-04.
const WAR_SIGNATURES: Dictionary = {"war_duelists_edge": 17, "war_pit_champion": 19, "war_cleave_through": 19}
## F2: War scores 7, counting Content's `armour` tag on `war_iron_vanguard`.
const WAR_PLAN_CARDS: int = 7
## F2 / F5 bounds in the shipped body, and the out-of-band fixture counts of AC-3.
const PLAN_MIN: int = 4
const PLAN_MAX: int = 7
const SYNERGY_MIN: int = 5

const TAG_A: String = "fixture_tag_a"
const TAG_B: String = "fixture_tag_b"
const TAG_OTHER: String = "fixture_tag_other"


func _shipped() -> CardDatabase:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED_ROOT))
	db.load(boot._collect_validators(null, true))
	return db


func _card(id: String, tags: Array, overrides: Dictionary = {}) -> Dictionary:
	var fields: Dictionary = {"set": "war", "tags": tags}
	fields.merge(overrides, true)
	return CardFactory.make_minion(id, 1, 1, 1, [], fields)


func _db(cards: Array, starter: Array = []) -> FakeCardDatabase:
	return FakeCardDatabase.new(cards, CardFactory.make_hero_def(HERO_FIXTURE, "war", {"starter_deck": starter}))


## [param count] copies of the one plan card, `war_plan`.
func _plan_starter(count: int) -> Array:
	var ids: Array = []
	for _i: int in count:
		ids.append("war_plan")
	return ids


func _body() -> Dictionary:
	return {"plan_min": PLAN_MIN, "plan_max": PLAN_MAX, "synergy_min": SYNERGY_MIN}


# --- AC-3: F2 on the starter ---------------------------------------------------------

func test_wars_shipped_starter_scores_7_plan_cards_inside_the_band() -> void:
	# Arrange
	var db: CardDatabase = _shipped()
	var hero: Dictionary = db.hero(HERO_WAR)
	var balance: Dictionary = db.config("heroes_balance")

	# Act
	var count: int = Heroes.plan_card_count(Array(hero.starter_deck), balance.plan_tags[hero.set], db)

	# Assert
	assert_int(count).is_equal(WAR_PLAN_CARDS)
	assert_bool(Heroes.plan_cards_in_band(count, balance)).is_true()


func test_a_fixture_starter_with_8_plan_cards_is_out_of_band() -> void:
	# Arrange
	var db: FakeCardDatabase = _db([_card("war_plan", [TAG_A])])

	# Act
	var count: int = Heroes.plan_card_count(_plan_starter(PLAN_MAX + 1), [TAG_A], db)

	# Assert
	assert_int(count).is_equal(PLAN_MAX + 1)
	assert_bool(Heroes.plan_cards_in_band(count, _body())).is_false()


func test_a_fixture_starter_with_3_plan_cards_is_out_of_band() -> void:
	# Arrange
	var db: FakeCardDatabase = _db([_card("war_plan", [TAG_A])])

	# Act
	var count: int = Heroes.plan_card_count(_plan_starter(PLAN_MIN - 1), [TAG_A], db)

	# Assert
	assert_int(count).is_equal(PLAN_MIN - 1)
	assert_bool(Heroes.plan_cards_in_band(count, _body())).is_false()


func test_both_ends_of_the_plan_band_are_inside_it() -> void:
	# Act / Assert
	assert_bool(Heroes.plan_cards_in_band(PLAN_MIN, _body())).is_true()
	assert_bool(Heroes.plan_cards_in_band(PLAN_MAX, _body())).is_true()


func test_the_plan_band_is_read_from_the_body_passed_in() -> void:
	# Arrange — a body that moves both bounds
	var body: Dictionary = {"plan_min": PLAN_MAX + 1, "plan_max": PLAN_MAX + 2}

	# Act / Assert
	assert_bool(Heroes.plan_cards_in_band(PLAN_MAX + 1, body)).is_true()
	assert_bool(Heroes.plan_cards_in_band(PLAN_MAX, body)).is_false()


# --- AC-F2: the counting rule --------------------------------------------------------

func test_a_card_with_two_plan_tags_counts_once() -> void:
	# Arrange
	var db: FakeCardDatabase = _db([_card("war_both", [TAG_A, TAG_B])])

	# Act
	var count: int = Heroes.plan_card_count(["war_both"], [TAG_A, TAG_B], db)

	# Assert
	assert_int(count).is_equal(1)


func test_a_card_with_no_plan_tag_does_not_count() -> void:
	# Arrange — a tagged neutral and an untagged card, neither on the plan
	var db: FakeCardDatabase = _db([_card("neutral_other", [TAG_OTHER], {"set": "neutral"}), _card("war_plain", [])])

	# Act
	var count: int = Heroes.plan_card_count(["neutral_other", "war_plain"], [TAG_A], db)

	# Assert
	assert_int(count).is_equal(0)


func test_duplicates_in_the_starter_count_per_copy() -> void:
	# Arrange
	var db: FakeCardDatabase = _db([_card("war_plan", [TAG_A])])

	# Act
	var count: int = Heroes.plan_card_count(["war_plan", "war_plan"], [TAG_A], db)

	# Assert
	assert_int(count).is_equal(2)


# --- AC-5: F5 on the signature cards -------------------------------------------------

func test_wars_signature_cards_score_their_synergy_at_or_above_the_minimum() -> void:
	# Arrange
	var db: CardDatabase = _shipped()
	var balance: Dictionary = db.config("heroes_balance")

	# Act / Assert
	for card_id: String in WAR_SIGNATURES:
		var score: int = Heroes.synergy(card_id, HERO_WAR, db)
		assert_int(score).override_failure_message("%s scored %d" % [card_id, score]).is_equal(int(WAR_SIGNATURES[card_id]))
		assert_bool(Heroes.synergy_in_band(score, balance)).is_true()


func test_a_signature_card_whose_tags_nothing_shares_scores_0_and_is_below_the_minimum() -> void:
	# Arrange
	var db: FakeCardDatabase = _db([_card("war_lonely", [TAG_OTHER]), _card("war_plan", [TAG_A])])

	# Act
	var score: int = Heroes.synergy("war_lonely", HERO_FIXTURE, db)

	# Assert
	assert_int(score).is_equal(0)
	assert_bool(Heroes.synergy_in_band(score, _body())).is_false()


func test_synergy_minimum_is_inclusive_and_read_from_the_body() -> void:
	# Act / Assert
	assert_bool(Heroes.synergy_in_band(SYNERGY_MIN, _body())).is_true()
	assert_bool(Heroes.synergy_in_band(SYNERGY_MIN - 1, _body())).is_false()
	assert_bool(Heroes.synergy_in_band(SYNERGY_MIN - 1, {"synergy_min": SYNERGY_MIN - 1})).is_true()


# --- F5: the counting rule -----------------------------------------------------------

func test_synergy_excludes_the_card_itself() -> void:
	# Arrange — it is in the set and the starter
	var db: FakeCardDatabase = _db([_card("war_sig", [TAG_A]), _card("war_plan", [TAG_A])], ["war_sig"])

	# Act
	var score: int = Heroes.synergy("war_sig", HERO_FIXTURE, db)

	# Assert
	assert_int(score).is_equal(1)


func test_synergy_counts_a_starter_neutral_through_the_union() -> void:
	# Arrange — no `war` card shares the tag; a starter neutral does
	var db: FakeCardDatabase = _db([_card("war_sig", [TAG_A]), _card("neutral_ally", [TAG_A], {"set": "neutral"})], ["neutral_ally"])

	# Act
	var score: int = Heroes.synergy("war_sig", HERO_FIXTURE, db)

	# Assert
	assert_int(score).is_equal(1)


func test_synergy_ignores_a_neutral_outside_the_starter() -> void:
	# Arrange
	var db: FakeCardDatabase = _db([_card("war_sig", [TAG_A]), _card("neutral_ally", [TAG_A], {"set": "neutral"})])

	# Act
	var score: int = Heroes.synergy("war_sig", HERO_FIXTURE, db)

	# Assert
	assert_int(score).is_equal(0)


func test_synergy_counts_distinct_ids_not_copies() -> void:
	# Arrange — in the set, and twice in the starter: one partner
	var db: FakeCardDatabase = _db([_card("war_sig", [TAG_A]), _card("war_plan", [TAG_A])], ["war_plan", "war_plan"])

	# Act
	var score: int = Heroes.synergy("war_sig", HERO_FIXTURE, db)

	# Assert
	assert_int(score).is_equal(1)


func test_synergy_counts_a_card_sharing_two_tags_once() -> void:
	# Arrange
	var db: FakeCardDatabase = _db([_card("war_sig", [TAG_A, TAG_B]), _card("war_plan", [TAG_A, TAG_B])])

	# Act
	var score: int = Heroes.synergy("war_sig", HERO_FIXTURE, db)

	# Assert
	assert_int(score).is_equal(1)


func test_synergy_leaves_tokens_out_of_the_set() -> void:
	# Arrange
	var db: FakeCardDatabase = _db([_card("war_sig", [TAG_A]), _card("war_token", [TAG_A], {"token": true})])

	# Act
	var score: int = Heroes.synergy("war_sig", HERO_FIXTURE, db)

	# Assert
	assert_int(score).is_equal(0)
