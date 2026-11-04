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
