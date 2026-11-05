## The treasures GDD's shared fixtures (design/gdd/treasures.md Acceptance
## Criteria preamble; story treasures/story-001): the 20 T8 records in
## `tests/fixtures/data/treasures_v1.json` and the boss `boss_test_taxman`.
##
## [method database] loads the records through the real `CardDatabase`
## pipeline: the `clean/` fixture root with its `treasures.json` body swapped
## for the records asked for, so a test gets real schema checks, frozen records
## and the CR-6 id-ascending `treasure_pool()`. The fixture file itself is in T8
## order, which is not id order. The `unlock` keys are not validated here: the
## map is `ValidatorStubs.accept_all()`.
## [codeblock]
## var db: CardDatabase = TreasureFixtures.database()               # all 20
## var mvp: CardDatabase = TreasureFixtures.database(TreasureFixtures.MVP_IDS)
## var scripted: CardDatabase = TreasureFixtures.database([], [CardFactory.make_spell("neutral_test_two", 2)])
## var boss: Dictionary = TreasureFixtures.make_boss_test_taxman()
## [/codeblock]
class_name TreasureFixtures
extends RefCounted

## The 20 T8 records, as a CR-1 definition file.
const TREASURES_V1: String = "res://tests/fixtures/data/treasures_v1.json"
## The root [method database] loads every other file from.
const BASE_ROOT: String = "res://tests/fixtures/data/clean/"
## T8's MVP column, id-ascending. The column is not a record field (CR-3), so
## the fixture cannot carry it.
const MVP_IDS: Array[String] = [
	"treasure_bottomless_satchel", "treasure_hollow_crown", "treasure_iron_constitution",
	"treasure_scholars_candle", "treasure_stampede_horn", "treasure_thornhide_cloak",
	"treasure_twin_grip", "treasure_vanguards_banner", "treasure_whetstone_wheel",
	"treasure_worn_signet",
]
## T8's four unlock keys (meta-progression M10, DD-X12).
const UNLOCK_KEYS: Array[String] = [
	"first_victory", "hero_decay_first_win", "hero_decay_floor_5", "hero_knowledge_first_win",
]


## `DataLoader` over [constant BASE_ROOT] that reads `treasures.json` from
## memory, so a flat fixture file needs no copy of the other 20 files.
class TreasureOverlayLoader:
	extends DataLoader

	var _treasures: Array = []
	var _cards: Array = []

	func _init(treasures: Array, cards: Array = []) -> void:
		super(BASE_ROOT)
		_treasures = treasures
		_cards = cards

	func _read_and_parse(report: ValidationReport) -> Array[Dictionary]:
		var staged: Array[Dictionary] = super(report)
		for item: Dictionary in staged:
			if item.row.name == "treasures.json":
				item.body = CardFactory.make_definition_file(_treasures)
			elif item.row.name == "cards_neutral.json":
				(item.body.records as Array).append_array(_cards)
		return staged


## The 20 records of [constant TREASURES_V1], freshly parsed, in T8 order.
static func records() -> Array:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TREASURES_V1))
	GameAssertions.fail_if(not parsed is Dictionary, "fixture %s did not parse" % TREASURES_V1)
	return parsed.records


## A `Ready` `CardDatabase` whose treasures are the [constant TREASURES_V1]
## records named in [param ids], or all 20 when [param ids] is empty.
## [param cards] are `neutral` CardDefs loaded beside the root's own, for a test
## that scripts a hand the root has no card for.
static func database(ids: Array = [], cards: Array = []) -> CardDatabase:
	var treasures: Array = records()
	if not ids.is_empty():
		treasures = treasures.filter(func(def: Dictionary) -> bool: return ids.has(def.id))
	var db: CardDatabase = CardDatabase.new(TreasureOverlayLoader.new(treasures, cards))
	db.load(ValidatorStubs.accept_all())
	GameAssertions.fail_if(db.state() != CardDatabase.State.READY, "treasure fixture did not load: %s" % str(db.report().entries()))
	return db


## The GDD's boss fixture: a BossDef whose passive is `modify_cost delta +1` on
## all enemy cards and the hero power (`kind: any`, card-effects C2), as the AC
## preamble and story 001 AC-T3.1 word it.
##
## `enemy` resolves relative to the entry's side (treasures T2.4), so this
## passive taxes the player, as treasures AC-2 and AC-16 expect (DD-X28).
static func make_boss_test_taxman() -> Dictionary:
	return CardFactory.make_boss_def("boss_test_taxman", 1, {
		"passive": {
			"trigger": "modify_cost",
			"scope": {"card": {"side": "enemy", "kind": "any"}},
			"ops": [{"op": "modify_value", "delta": 1}],
		},
	})
