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
## The shipped data, for a suite that needs the real War power and real cards.
const SHIPPED_ROOT: String = "res://assets/data/"
## The treasures GDD's AC preamble: `run_seed_hex` 00000000000000A7, hero `hero_war`.
const RUN_SEED: int = 0x00000000000000A7
const HERO_WAR: String = "hero_war"
## A shipped band-1 boss: its deck is a real deck, and nothing of it acts uninvited.
const BOSS_ID: String = "boss_torchbearer"
## What `installers_for` is handed by a run with no treasure state (T4).
const NO_STATE: Dictionary = {"schema_version": 1, "by_treasure": {}}
const CROWN: String = "treasure_hollow_crown"
const SIGNET: String = "treasure_worn_signet"
const CLOAK: String = "treasure_thornhide_cloak"
const CANDLE: String = "treasure_scholars_candle"
const CONSTITUTION: String = "treasure_iron_constitution"
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


# --- Shipped data and a real match (treasures stories 002, 007, 008, 010, 012) ---

## A `Ready` database over [constant SHIPPED_ROOT] with `ValidatorStubs.accept_all()`:
## what a suite reaches for when it needs the real War power, the real cards and the
## 20 shipped treasures. [param record_edits] is `{treasure id: {key: value}}`, merged
## over the matching records; [param cards] are `neutral` CardDefs loaded beside the
## root's own, for a scripted hand; [param no_legendaries] makes every Legendary card
## Rare, for a collectible pool that holds none (treasures AC-26).
static func shipped_database(record_edits: Dictionary = {}, cards: Array = [], no_legendaries: bool = false) -> CardDatabase:
	var db: CardDatabase = CardDatabase.new(ShippedOverlayLoader.new(record_edits, cards, no_legendaries))
	db.load(ValidatorStubs.accept_all())
	GameAssertions.fail_if(db.state() != CardDatabase.State.READY, "shipped fixture did not load: %s" % str(db.report().entries()))
	return db


## `DataLoader` over the shipped root that edits `treasures.json` and adds cards in
## memory, so no test writes a data file.
class ShippedOverlayLoader:
	extends DataLoader

	var _edits: Dictionary = {}
	var _cards: Array = []
	var _no_legendaries: bool = false

	func _init(record_edits: Dictionary, cards: Array, no_legendaries: bool) -> void:
		super(SHIPPED_ROOT)
		_edits = record_edits
		_cards = cards
		_no_legendaries = no_legendaries

	func _read_and_parse(report: ValidationReport) -> Array[Dictionary]:
		var staged: Array[Dictionary] = super(report)
		for item: Dictionary in staged:
			if item.row.name == "treasures.json":
				for record: Dictionary in item.body.records:
					if _edits.has(record.id):
						record.merge(_edits[record.id], true)
			elif item.row.name == "cards_neutral.json":
				(item.body.records as Array).append_array(_cards)
			if _no_legendaries and str(item.row.name).begins_with("cards_"):
				for record: Dictionary in item.body.records:
					if record.get("rarity") == "legendary":
						record["rarity"] = "rare"
		return staged


## One real match over [param database]: [param treasure_ids] through
## `Treasures.installers_for`, a real `EffectResolver`, the `match_rules` and
## `card_effects` bodies of the data, on the GDD's seed and hero. It stops in
## `Mulligan`. Call [method end] from `after_test`.
## [param options]: `deck`, `boss_deck`, `boss_installers`, `installers` (replaces the
## `installers_for` result), `seed`.
## [codeblock]
## var game := TreasureFixtures.Match.new(db, [TreasureFixtures.CROWN])
## game.to_turn(2)
## game.player().mana_max
## [/codeblock]
class Match:
	extends RefCounted

	var db: CardDatabase
	var engine: RulesEngine
	var log: TestEventLog

	func _init(database: CardDatabase, treasure_ids: Array, options: Dictionary = {}) -> void:
		db = database
		log = TestEventLog.new()
		var hero: Dictionary = db.hero(HERO_WAR)
		var treasures: Treasures = Treasures.new(db, db.config("treasures_balance"))
		var installers: Array = options.get("installers", treasures.installers_for(treasure_ids, NO_STATE))
		var overrides: Dictionary = {
			"player": {
				"hero_def_id": HERO_WAR,
				"deck": options.get("deck", Array(hero.starter_deck)),
				"hook_installers": installers,
			},
			"boss": {
				"boss_def_id": BOSS_ID,
				"deck": options.get("boss_deck", Array(db.boss(BOSS_ID).deck)),
				"hook_installers": options.get("boss_installers", []),
			},
		}
		var rng := TestRngService.new(int(options.get("seed", RUN_SEED)))
		var config: Dictionary = MatchFactory.make_started_config(rng, log, overrides)
		var resolver := EffectResolver.new(db, db.config("card_effects"), str(hero["set"]))
		engine = RulesEngine.new(db, db.config("match_rules"), resolver)
		engine.start(config)

	## Tears the engine down: it and its resolver reference each other.
	func end() -> void:
		engine.end_match()

	func player() -> Dictionary:
		return engine.state().players[MatchRecords.SIDE_PLAYER]

	func boss() -> Dictionary:
		return engine.state().players[MatchRecords.SIDE_BOSS]

	## Submits [param command], failing the test on a rejection.
	func play(command: Dictionary) -> Dictionary:
		var result: Dictionary = engine.submit(command)
		GameAssertions.fail_if(not result.accepted, "rejected: %s" % str(result.rejection))
		return result

	## The code of the rejection of [param command], `""` when it was accepted.
	func rejection_of(command: Dictionary) -> String:
		var result: Dictionary = engine.submit(command)
		return "" if result.accepted else str(result.rejection.code)

	## From `Mulligan` to the player's Main of their turn [param turn], by a keep-all
	## mulligan and both `end_turn`s per turn passed.
	func to_turn(turn: int) -> void:
		play(engine.legal_commands()[0])
		for _i: int in turn - 1:
			end_round()

	func end_round() -> void:
		play(MatchRecords.end_turn(MatchRecords.SIDE_PLAYER))
		play(MatchRecords.end_turn(MatchRecords.SIDE_BOSS))

	## Replaces the player's hand with [param def_ids] and runs an empty step, whose
	## C10 loop logs what moved.
	func script_hand(def_ids: Array) -> void:
		var hand: Array = player().hand
		hand.clear()
		for def_id: String in def_ids:
			hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(engine.state()), def_id, "hand"))
		engine.index_locations()
		engine.run_action(_noop)

	## Summons [param def_id] on [param side] in one action. Returns its entity id.
	func summon(side: String, def_id: String) -> int:
		var made: Array[int] = []
		engine.run_action(func() -> void: made.append(engine.summon_minion(side, def_id, -1)))
		return made[0]

	func last_seq() -> int:
		return int(log.events.back().seq)

	## The events of [param type] after [param from_seq].
	func of_type(type: String, from_seq: int = 0) -> Array:
		return log.events.filter(func(e: Dictionary) -> bool: return int(e.seq) > from_seq and str(e.type) == type)

	## The event with [param seq], `{}` when there is none.
	func event_at(seq: int) -> Dictionary:
		for event: Dictionary in log.events:
			if int(event.seq) == seq:
				return event
		return {}

	func _noop() -> void:
		pass
