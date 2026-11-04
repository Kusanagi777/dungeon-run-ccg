## Board-setup fixtures for the Boss AI scorer and candidate suites
## (boss-ai-match-driver stories 004–006; design/gdd/boss-ai.md Acceptance
## Criteria: "fixtures are board setups under `tests/fixtures/boss_ai/`").
##
## A fixture is `{name, profile, band, weights?, deck_card, cards[], boss:
## {mana, board[], hand[]}, player: {health, board[]}, expect, …}` — card
## records are `{id, type, cost, attack?, health?, keywords?, effects?}`, and
## `board` / `hand` list card ids. [method engine] builds a **live** match on
## the production `EffectResolver` over a [FakeCardDatabase] of those cards:
## `start`, the keep-all mulligan, the player's turn 1 (casting the given
## cards first, so their `card_played` events are in the log), `end_turn`,
## then the boss's Main is laid out from the fixture — boards and hands
## replaced, heroes at the fixture health, the boss's mana set, both hero
## powers marked used unless the fixture names `boss.hero_power` (a card of
## `type: hero_power`; then the boss's power is that one, unused), every
## minion awake. The profile is the committed stub's (`profiles_stub.json`)
## resolved for the fixture's archetype and band, with `weights` and `budgets`
## applied as a `boss_overrides` entry — never `assets/data/`.
## [codeblock]
## var fixture: Dictionary = BossAiBoard.read("f1_worked_example")
## var db: BossAiBoard.FakeCardDatabase = BossAiBoard.database(fixture)
## var engine: RulesEngine = BossAiBoard.engine(fixture, db)
## var profile: Dictionary = BossAiBoard.profile(fixture)
## [/codeblock]
class_name BossAiBoard
extends RefCounted

const FIXTURE_DIR: String = "res://tests/fixtures/boss_ai/"
const STUB_PATH: String = "res://tests/fixtures/boss_ai/profiles_stub.json"
## The `boss_overrides` key a fixture's `weights` are installed under.
const OVERRIDE_KEY: String = "bai_fixture"
## Cards per deck: the starting hands plus a few turns of draws, no fatigue.
const DECK_SIZE: int = 20
## The setup seed (boards are laid out after setup, so it shapes nothing scored).
const SETUP_SEED: int = 4


## A `CardDatabase` answering `has` / `card` / `hero_power` /
## `collectible_pool` from one map (the production resolver's lookups), as
## `match_rules_clone_replay_test.gd` does.
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

	func collectible_pool(_hero_set: String) -> Array:
		return []


## The fixture `<name>.json`, parsed.
static func read(name: String) -> Dictionary:
	var path: String = FIXTURE_DIR + name + ".json"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	GameAssertions.fail_if(not parsed is Dictionary, "fixture %s did not parse" % path)
	return parsed


## The stub `ai_profiles` config body, freshly parsed.
static func stub_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STUB_PATH))
	GameAssertions.fail_if(not parsed is Dictionary, "fixture %s did not parse" % STUB_PATH)
	return (parsed as Dictionary)["config"]


## The resolved profile of [param fixture] (C10 layering over the stub).
static func profile(fixture: Dictionary) -> Dictionary:
	var config: Dictionary = stub_config()
	var key: String = str(fixture.profile)
	if fixture.has("weights") or fixture.has("budgets"):
		config.boss_overrides[OVERRIDE_KEY] = {"extends": key, "weights": fixture.get("weights", {}), "budgets": fixture.get("budgets", {})}
		key = OVERRIDE_KEY
	return ProfileResolver.resolve(config, CardFactory.make_boss_def("boss_test", int(fixture.band), {"ai_profile": key}), int(fixture.band))


## The stub's `keyword_values` (F2 `keyword_mult`).
static func keyword_values() -> Dictionary:
	return stub_config().keyword_values


## A [FakeCardDatabase] of the fixture's `cards` (CR-3 records via [CardFactory]).
static func database(fixture: Dictionary) -> FakeCardDatabase:
	var by_id: Dictionary = {}
	for spec: Dictionary in fixture.cards:
		var id: String = str(spec.id)
		var keywords: Array = spec.get("keywords", [])
		match str(spec.type):
			"minion":
				by_id[id] = CardFactory.make_minion(id, int(spec.cost), int(spec.attack), int(spec.health), keywords, {"effects": spec.get("effects", [])})
			"spell":
				by_id[id] = CardFactory.make_spell(id, int(spec.cost), spec.get("effects", []), {"keywords": keywords})
			"weapon":
				by_id[id] = CardFactory.make_weapon(id, int(spec.cost), int(spec.attack), int(spec.health))
			"hero_power":
				by_id[id] = CardFactory.make_hero_power_def(id, spec.get("effects", []))
	return FakeCardDatabase.new(by_id)


## The `card_effects` config body the production resolver reads (TestConstants).
static func effects_config() -> Dictionary:
	return {
		"discover_count": float(TestConstants.DISCOVER_COUNT),
		"discover_exclude_hand": false,
		"max_ops_per_effect": float(TestConstants.MAX_OPS_PER_EFFECT),
		"max_repeat": float(TestConstants.MAX_REPEAT),
		"max_summon_count": float(TestConstants.BOARD_SIZE),
		"effect_static_step_limit": float(TestConstants.EFFECT_STATIC_STEP_LIMIT),
		"spell_damage_default": "auto",
		"hooks_before_triggers": true,
	}


## The live engine at the boss's Main with [param fixture] laid out (see the
## class doc). [param player_casts] are card ids the player casts on turn 1
## (0-cost spells with no chosen target); [param log] receives every event.
static func engine(fixture: Dictionary, db: FakeCardDatabase, player_casts: Array = [], log: TestEventLog = null) -> RulesEngine:
	var deck: Array = []
	for _i: int in DECK_SIZE:
		deck.append(str(fixture.deck_card))
	var event_log: TestEventLog = log if log != null else TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(SETUP_SEED), event_log, {"player": {"deck": deck}, "boss": {"deck": deck.duplicate()}})
	var engine: RulesEngine = RulesEngine.new(db, MatchFactory.make_rules_config(), EffectResolver.new(db, effects_config(), ""))
	engine.start(config)
	GameAssertions.fail_if(not engine.submit(engine.legal_commands()[0]).accepted, "mulligan rejected")
	var state: MatchState = engine.state()
	for card_id: Variant in player_casts:
		var hand: Array = state.players[MatchRecords.SIDE_PLAYER].hand
		hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), str(card_id), "hand"))
		var played: Dictionary = engine.submit(MatchRecords.play_card(MatchRecords.SIDE_PLAYER, hand.size() - 1, null, null))
		GameAssertions.fail_if(not played.accepted, "player cast of %s rejected: %s" % [card_id, str(played.rejection)])
	GameAssertions.fail_if(not engine.submit(MatchRecords.end_turn(MatchRecords.SIDE_PLAYER)).accepted, "player end_turn rejected")
	GameAssertions.fail_if(engine.phase() != MatchState.PHASE_MAIN or String(engine.active_side()) != MatchRecords.SIDE_BOSS, "not at the boss's Main")
	_lay_out(engine, fixture, db)
	return engine


## Places [param def_id] on [param side]'s board of [param engine]'s state,
## awake, and returns the minion.
static func place(engine: RulesEngine, db: FakeCardDatabase, side: String, def_id: String) -> Dictionary:
	var def: Dictionary = db.card(def_id)
	var minion: Dictionary = MatchFactory.summon(engine.state(), side, int(def.attack), int(def.health), -1, def.keywords, def_id)
	GameAssertions.fail_if(minion.is_empty(), "board full placing %s" % def_id)
	minion.summoning_sick = false
	return minion


## Adds [param def_id] to the end of [param side]'s hand.
static func add_to_hand(engine: RulesEngine, side: String, def_id: String) -> Dictionary:
	var state: MatchState = engine.state()
	var card: Dictionary = MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), def_id, "hand")
	state.players[side].hand.append(card)
	return card


## Entity ids of [param side]'s board minions of [param def_id], in board order.
static func ids_of(engine: RulesEngine, side: String, def_id: String) -> Array[int]:
	var ids: Array[int] = []
	for minion: Dictionary in engine.state().players[side].board:
		if str(minion.def_id) == def_id:
			ids.append(int(minion.entity_id))
	return ids


static func _lay_out(engine: RulesEngine, fixture: Dictionary, db: FakeCardDatabase) -> void:
	var state: MatchState = engine.state()
	for side: String in MatchRecords.SIDES:
		var player: Dictionary = state.players[side]
		(player.board as Array).clear()
		(player.hand as Array).clear()
		player.hero_power.used_this_turn = true
	var boss: Dictionary = fixture.boss
	for def_id: Variant in boss.board:
		place(engine, db, MatchRecords.SIDE_BOSS, str(def_id))
	for def_id: Variant in boss.hand:
		add_to_hand(engine, MatchRecords.SIDE_BOSS, str(def_id))
	state.players[MatchRecords.SIDE_BOSS].mana_current = int(boss.mana)
	state.players[MatchRecords.SIDE_BOSS].mana_max = int(boss.mana)
	if boss.has("hero_power"):
		state.players[MatchRecords.SIDE_BOSS].hero_power = {"def_id": str(boss.hero_power), "used_this_turn": false}
	var player_spec: Dictionary = fixture.player
	for def_id: Variant in player_spec.board:
		place(engine, db, MatchRecords.SIDE_PLAYER, str(def_id))
	var hero: Dictionary = state.players[MatchRecords.SIDE_PLAYER].hero
	hero.damage_taken = engine.max_health(hero) - int(player_spec.health)
