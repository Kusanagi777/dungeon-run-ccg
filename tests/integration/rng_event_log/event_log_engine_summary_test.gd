## EventLog.reduce_to_summary() over a log the real `RulesEngine` wrote.
##
## Story: production/epics/rng-event-log/story-008-match-summary-reduction.md
## (code-review fix, sprint 4 L4: the summary read `instance_id` on
## `minion_summoned` / `weapon_equipped`; the engine emits `entity_id` —
## match-rules C15, the authoritative catalogue, DD-X04).
## GDD: design/gdd/rng-event-log.md rules 18-19.
##
## Every event here is the engine's own: real `play_card` (minion, weapon,
## spell) and `use_hero_power` commands, each play trigger's pass dealing
## damage through the `apply_damage` primitive with the engine's
## `ctx.source` — the summoned minion's / equipped weapon's `entity_id`, the
## spell's instance, the hero — and, since match-rules 012/013 merged, real
## `attack` commands (a minion, then the hero swinging its weapon: the hero
## is the source, DD-X15 — so the swing credits no card). No wall clock, no
## file I/O.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
const DEF_MINION: String = "summary_minion"
const DEF_WEAPON: String = "summary_weapon"
const DEF_SPELL: String = "summary_spell"
const DEF_POWER: String = "summary_power"
const CHEAP: int = 1
## Mana for the three plays plus the hero power.
const MANA_POOL: int = 3 * CHEAP + TestConstants.HERO_POWER_COST
## Damage each host's play pass deals to the boss hero — distinct, so a
## misattribution shows in the sums. The total stays under band-1 boss health.
const DAMAGE_BY_HOST: Dictionary = {DEF_MINION: 1, DEF_WEAPON: 2, DEF_SPELL: 3, DEF_POWER: 4}


class FixtureDb extends RefCounted:
	var cards: Dictionary = {}

	func has(id: String) -> bool:
		return cards.has(id)

	func card(id: String) -> Variant:
		return cards.get(id)


func _db() -> FixtureDb:
	var db: FixtureDb = FixtureDb.new()
	db.cards[DEF_MINION] = CardFactory.make_minion(DEF_MINION, CHEAP, 2, 2)
	db.cards[DEF_WEAPON] = CardFactory.make_weapon(DEF_WEAPON, CHEAP, 2, 2)
	db.cards[DEF_SPELL] = CardFactory.make_spell(DEF_SPELL, CHEAP)
	return db


## The play pass of every host: hit the boss hero from the engine's source.
func _hit_boss(engine: RulesEngine, ctx: Dictionary) -> void:
	var boss_hero: int = int(engine.state().players[SIDE_BOSS].hero.entity_id)
	engine.apply_damage(boss_hero, int(DAMAGE_BY_HOST[str(ctx.card_id)]), ctx.source)


## A started engine on a production EventLog, past a keep-all mulligan, the
## player's hand replaced by minion, weapon, spell and its mana topped up.
func _engine(log: EventLog) -> RulesEngine:
	var resolver: TestEffectResolver = TestEffectResolver.new()
	for point: StringName in [&"battlecry", &"on_cast", &"hero_power"]:
		resolver.scripts[point] = [_hit_boss]
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), null, {"log": log})
	var engine: RulesEngine = RulesEngine.new(_db(), MatchFactory.make_rules_config(), resolver)
	engine.start(config)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var state: MatchState = engine.state()
	var hand: Array = state.players[SIDE_PLAYER].hand
	hand.clear()
	for def_id: String in [DEF_MINION, DEF_WEAPON, DEF_SPELL]:
		hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), def_id, "hand"))
	state.players[SIDE_PLAYER].mana_current = MANA_POOL
	state.players[SIDE_PLAYER].hero_power.def_id = DEF_POWER
	return engine


func test_engine_summon_equip_spell_and_power_damage_attributes_to_each_card() -> void:
	# Arrange
	var log: EventLog = EventLog.new(TestConstants.MAX_MATCH_EVENTS, EventLog.SCOPE_MATCH)
	var engine: RulesEngine = _engine(log)

	# Act — every damage_dealt below is emitted by the engine
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.use_hero_power(SIDE_PLAYER)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.concede(SIDE_PLAYER)).accepted).is_true()
	var summary: Dictionary = log.reduce_to_summary()

	# Assert — the engine's summon / equip events carry `entity_id`, and the
	# minion's and weapon's damage is credited to their cards
	var events: Array[Dictionary] = log.events_since(0)
	var summoned: Dictionary = events[events.find_custom(func(e: Dictionary) -> bool: return e.type == "minion_summoned")].payload
	assert_bool(summoned.has("entity_id")).is_true()
	assert_int(EventLogAssertions.count_type(events, &"damage_dealt")).is_equal(DAMAGE_BY_HOST.size())
	assert_dict(summary.damage_by_card).is_equal(DAMAGE_BY_HOST)
	assert_int(summary.cards_played).is_equal(3)


func test_engine_minion_attack_attributes_to_its_card_and_a_hero_weapon_swing_to_none() -> void:
	# Arrange — a resolver with no scripts: every damage_dealt is an attack's
	var log: EventLog = EventLog.new(TestConstants.MAX_MATCH_EVENTS, EventLog.SCOPE_MATCH)
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(), null, {"log": log})
	var engine: RulesEngine = RulesEngine.new(_db(), MatchFactory.make_rules_config(), TestEffectResolver.new())
	engine.start(config)
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var state: MatchState = engine.state()
	var player: Dictionary = state.players[SIDE_PLAYER]
	player.hand.clear()
	for def_id: String in [DEF_MINION, DEF_WEAPON]:
		player.hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), def_id, "hand"))
	player.mana_current = MANA_POOL
	var boss_hero: int = int(state.players[SIDE_BOSS].hero.entity_id)
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0)).accepted).is_true()
	var minion_id: int = int(player.board[0].entity_id)
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_PLAYER)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.end_turn(SIDE_BOSS)).accepted).is_true()
	player.mana_current = MANA_POOL

	# Act — the minion attacks, then the hero equips and swings
	assert_bool(engine.submit(MatchRecords.attack(SIDE_PLAYER, minion_id, boss_hero)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.attack(SIDE_PLAYER, int(player.hero.entity_id), boss_hero)).accepted).is_true()
	assert_bool(engine.submit(MatchRecords.concede(SIDE_PLAYER)).accepted).is_true()
	var summary: Dictionary = log.reduce_to_summary()

	# Assert — the minion 2/2 (FixtureDb) is credited its attack; the hero's
	# weapon swing is the hero's damage (DD-X15), which no card is credited
	var minion_attack: int = int(_db().card(DEF_MINION).attack)
	assert_dict(summary.damage_by_card).is_equal({DEF_MINION: minion_attack})
