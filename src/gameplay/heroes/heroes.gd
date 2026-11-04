## Heroes: thin data access over `CardDatabase` (heroes story 002; heroes.md H-1,
## H-2, H-5, H-7; ADR-0002; architecture.md API Boundaries, Heroes row). A hero is
## pure data, so nothing hero-specific lives here: Run Structure copies the starter
## deck from [method hero], Reward Draft weights bundles by [method plan_tags] and
## Run UI lists [method launch_heroes].
##
## Unlock state is not part of this class. `MetaApi.is_hero_unlocked` is consulted
## by Run Structure and Run UI, which own `E_HERO_LOCKED` and the Locked display.
## [codeblock]
## var heroes := Heroes.new(db)
## var deck: Array = heroes.hero("hero_war").starter_deck
## [/codeblock]
class_name Heroes
extends RefCounted

var _db: CardDatabase
## The frozen `heroes_balance` body, read once here (ADR-0002).
var _balance: Dictionary


## Keeps [param db], the frozen `CardDatabase`, and reads `heroes_balance` once.
func _init(db: CardDatabase) -> void:
	_db = db
	_balance = db.config("heroes_balance")


## The frozen `HeroDef` [param id], the record `db.hero(id)` returns: treat it as
## read-only, `duplicate(true)` for a writable copy (CR-7). An unknown id is `null`
## and whatever `db.hero` reports for it.
## [codeblock]
## heroes.hero("hero_war").health   # 30 with the shipped data
## [/codeblock]
func hero(id: String) -> Variant:
	return _db.hero(id)


## The launch heroes, id-ascending: every `HeroDef` with `unlock` null (H-2). A
## hero with an `unlock {key, condition}` object (H-7) is never listed, whatever
## Meta Progression reports for it.
## [codeblock]
## heroes.launch_heroes()   # [the hero_war record] with the shipped data
## [/codeblock]
func launch_heroes() -> Array:
	return _db.heroes().filter(func(record: Dictionary) -> bool: return record.unlock == null)


## A writable copy of the plan tags of the set of [param hero_id]: the list at
## `heroes_balance.plan_tags[hero.set]` (H-5, reward-draft F3). An unknown hero, or
## a set with no row, is a logged error and `[]`, as `CardDatabase` answers a query
## it cannot, and never an assert.
## [codeblock]
## heroes.plan_tags("hero_war")   # ["weapons", "aggro", "armour"] with the shipped data
## [/codeblock]
func plan_tags(hero_id: String) -> Array:
	if not _db.has(hero_id):
		push_error("Heroes.plan_tags(): no HeroDef \"%s\"" % hero_id)
		return []
	var hero_set: String = str(_db.hero(hero_id).set)
	var by_set: Dictionary = _balance.plan_tags
	if not by_set.has(hero_set):
		push_error("Heroes.plan_tags(): heroes_balance has no plan_tags row for set \"%s\"" % hero_set)
		return []
	return Array(by_set[hero_set]).duplicate()


# --- Story 003: the F2 and F5 design-time checks -------------------------------
#
# Static and pure, so the content validate command can compose them later the way
# it composes `ContentValidator`'s checks. They return a value and an in-band
# verdict and add no report code: F2 and F5 name none, and no record marks a
# signature card (heroes GDD gap, story 003 Completion Notes).


## Heroes F2: how many of [param starter_ids] carry at least one of [param tags],
## the `heroes_balance.plan_tags` list of the hero's set. It counts cards, not tags:
## a card with two plan tags counts once, and each copy in the starter counts.
## [codeblock]
## var body: Dictionary = db.config("heroes_balance")
## Heroes.plan_card_count(db.hero("hero_war").starter_deck, body.plan_tags.war, db)   # 7
## [/codeblock]
static func plan_card_count(starter_ids: Array, tags: Array, db: CardDatabase) -> int:
	var count: int = 0
	for card_id: Variant in starter_ids:
		if _shares_a_tag(db.card(str(card_id)), tags):
			count += 1
	return count


## Whether [param count] is inside F2's band, `[plan_min, plan_max]` of
## [param body], the `heroes_balance` config body.
## [codeblock]
## Heroes.plan_cards_in_band(8, db.config("heroes_balance"))   # false with the shipped data
## [/codeblock]
static func plan_cards_in_band(count: int, body: Dictionary) -> bool:
	return count >= int(body.plan_min) and count <= int(body.plan_max)


## Heroes F5: how many distinct cards of `set(hero) ∪ starter(hero)`, other than
## [param card_id], share a tag with it. `set(hero)` leaves tokens out; the
## starter's neutrals join through the union.
## [codeblock]
## Heroes.synergy("war_pit_champion", "hero_war", db)   # 19 with the shipped data
## [/codeblock]
static func synergy(card_id: String, hero_id: String, db: CardDatabase) -> int:
	var hero_record: Dictionary = db.hero(hero_id)
	var partners: Dictionary = {}
	for record: Dictionary in db.cards_by_set(str(hero_record.set)):
		if not record.get("token", false):
			partners[record.id] = record
	for starter_id: Variant in hero_record.starter_deck:
		partners[str(starter_id)] = db.card(str(starter_id))
	partners.erase(card_id)
	var tags: Array = Array(db.card(card_id).tags)
	var score: int = 0
	for partner: Dictionary in partners.values():
		if _shares_a_tag(partner, tags):
			score += 1
	return score


## Whether [param score] meets F5's `synergy_min` of [param body], the
## `heroes_balance` config body.
## [codeblock]
## Heroes.synergy_in_band(0, db.config("heroes_balance"))   # false with the shipped data
## [/codeblock]
static func synergy_in_band(score: int, body: Dictionary) -> bool:
	return score >= int(body.synergy_min)


static func _shares_a_tag(card: Dictionary, tags: Array) -> bool:
	return Array(card.tags).any(func(tag: Variant) -> bool: return tags.has(tag))
