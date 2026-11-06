## One match on the shipped `res://assets/data/` through the real `DataLoader`,
## `CardDatabase`, `EffectResolver` and `RulesEngine`, with the real [RngService] and
## [EventLog], a boss's real passive and its real hero power, as a `MatchConfig` from
## run-structure R3 seats them. No planner runs: a test submits both sides' commands.
##
## [method database] loads the shipped set; a suite keeps the result. A fresh, freed
## `Boot` instance gives the validator map, never the autoload.
## [codeblock]
## var db: CardDatabase = ShippedMatch.database()
## var game := ShippedMatch.new(db, "hero_war", "boss_mirror_sage")
## game.to_player_main()
## game.set_hand(MatchRecords.SIDE_PLAYER, ["neutral_tunnel_rat"])
## game.submit(MatchRecords.play_card(MatchRecords.SIDE_PLAYER, 0, 0))
## game.finish()
## [/codeblock]
class_name ShippedMatch
extends RefCounted

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SHIPPED_ROOT: String = "res://assets/data/"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
const DEFAULT_SEED: int = 42
const DEFAULT_FLOOR: int = 1
## Enough for any card in the data, and within `MAX_MANA`.
const FULL_MANA: int = 10
const SPARE_DECK_CARD: String = "neutral_tunnel_rat"
const SPARE_DECK_SIZE: int = 30

var db: CardDatabase
var engine: RulesEngine
var log: EventLog


## A `Ready` database over the shipped data, with the validators `Boot` composes.
static func database() -> CardDatabase:
	var boot: Node = BOOT_SCRIPT.new()
	var map: Dictionary = boot._collect_validators(null, true)
	var loaded: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED_ROOT))
	@warning_ignore("return_value_discarded")
	loaded.load(map)
	boot.free()
	return loaded


## [constant SPARE_DECK_SIZE] copies of [constant SPARE_DECK_CARD].
static func spare_deck() -> Array:
	var deck: Array = []
	deck.resize(SPARE_DECK_SIZE)
	deck.fill(SPARE_DECK_CARD)
	return deck


## [param player_deck] and [param boss_deck] default to [method spare_deck], so a test's
## opening hand is known. Started, phase Mulligan.
func _init(database_in: CardDatabase, hero_id_in: String, boss_id: String, seed_value: int = DEFAULT_SEED, player_deck: Array = [], boss_deck: Array = []) -> void:
	db = database_in
	var hero: Dictionary = db.hero(hero_id_in)
	var boss: Dictionary = db.boss(boss_id)
	var rng: RngService = RngService.new(seed_value, db.data_version())
	log = EventLog.new(EventLog.max_events_for(db.config("rng_event_log")), EventLog.SCOPE_MATCH)
	var config: Dictionary = {
		"floor": DEFAULT_FLOOR,
		"band": int(boss.band),
		"rng_match": rng.stream("match_%d" % DEFAULT_FLOOR),
		"rng_ai": rng.stream("ai_%d" % DEFAULT_FLOOR),
		"log": log,
		"player": {
			"hero_def_id": hero_id_in,
			"deck": player_deck.duplicate() if not player_deck.is_empty() else ShippedMatch.spare_deck(),
			"hook_installers": [],
		},
		"boss": {
			"boss_def_id": boss_id,
			"deck": boss_deck.duplicate() if not boss_deck.is_empty() else ShippedMatch.spare_deck(),
			"health": int(boss.health),
			"hook_installers": Treasures.passive_installer(boss),
			"hero_power": boss.get("hero_power"),
			"ai_id": str(boss.ai_profile),
		},
	}
	engine = RulesEngine.new(db, db.config("match_rules"), EffectResolver.new(db, db.config("card_effects"), str(hero.set)))
	engine.start(config)


## The keep-all mulligan; the player's Main of turn 1, with empty boards and hands.
func to_player_main() -> void:
	GameAssertions.fail_if(not engine.submit(engine.legal_commands()[0]).accepted, "mulligan rejected")
	set_hand(SIDE_PLAYER, [])
	set_hand(SIDE_BOSS, [])


## The boss's Main of its first turn, with empty boards and hands.
func to_boss_main() -> void:
	to_player_main()
	GameAssertions.fail_if(not engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted, "end_turn rejected")
	set_hand(SIDE_BOSS, [])


## Replaces [param side]'s hand with fresh instances of [param def_ids] and fills its
## mana, so a card's cost is out of the way. Goes through one empty engine action, so a
## hand-scoped aura sees the new cards.
func set_hand(side: String, def_ids: Array) -> void:
	var state: MatchState = engine.state()
	var hand: Array = state.players[side].hand
	hand.clear()
	for def_id: Variant in def_ids:
		hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(def_id), "hand"))
	state.players[side].mana_current = FULL_MANA
	state.players[side].mana_max = FULL_MANA


## A real summon on [param side]'s board, awake; its entity id.
func summon(side: String, def_id: String) -> int:
	var id: Array[int] = [RulesEngine.NO_ENTITY]
	var position: int = (engine.state().players[side].board as Array).size()
	engine.run_action(func() -> void: id[0] = engine.summon_minion(side, def_id, position))
	var minion: Dictionary = minion_of(id[0])
	if not minion.is_empty():
		minion.summoning_sick = false
	return id[0]


## The board record of [param entity_id], `{}` off the board.
func minion_of(entity_id: int) -> Dictionary:
	for side: String in MatchRecords.SIDES:
		for minion: Dictionary in engine.state().players[side].board:
			if int(minion.entity_id) == entity_id:
				return minion
	return {}


## [param side]'s hero's entity id.
func hero_id(side: String) -> int:
	return int(engine.state().players[side].hero.entity_id)


## `engine.submit`, with the `issuer` the command carries, and its `CommandResult`.
func submit(command: Dictionary) -> Dictionary:
	return engine.submit(command)


## Answers every open Choice with its first option; `false` if one was refused.
func answer_choices() -> bool:
	while engine.phase() == MatchState.PHASE_CHOICE:
		var side: String = str(engine.pending_choice().side)
		if not engine.submit(MatchRecords.choose(side, 0)).accepted:
			return false
	return true


## The sequence number of the last event, for [method events_after].
func last_seq() -> int:
	var events: Array[Dictionary] = log.events_since(0)
	return int(events.back().seq) if not events.is_empty() else 0


## Every event after [param seq], oldest first.
func events_after(seq: int = 0) -> Array[Dictionary]:
	return log.events_since(seq)


## The events after [param seq] of [param type].
func of_type(type: String, seq: int = 0) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for event: Dictionary in events_after(seq):
		if str(event.type) == type:
			found.append(event)
	return found


## Ends the engine, so nothing outlives the test.
func finish() -> void:
	engine.end_match()
