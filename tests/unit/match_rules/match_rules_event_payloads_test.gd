## Unit tests for the fields a view needs on an engine event (story
## match-rules/story-020; design/gdd/match-rules.md C15, rng-event-log §D;
## ADR-0003: a field the view needs is on the event, never read back).
##
## `minion_summoned` has two emit sites, the C6 play and the `summon_minion`
## primitive, and every case runs at both. The fixture holds a minion with
## several printed keywords out of order, one that prints a keyword twice, and
## one with none. A new minion has no enchantment yet at either site, so its
## effective set is its printed set.
##
## `match_started` reports `starting_health {player, boss}` (DD-X35), read after
## the `on_match_start` hooks. Each side's hook deals a different amount, so a
## value read before the hooks, or from the wrong side, shows.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
const DEF_MANY: String = "neutral_test_many_keywords"
const DEF_TWICE: String = "neutral_test_keyword_twice"
const DEF_PLAIN: String = "neutral_test_no_keywords"
const MINION_COST: int = 1
const MINION_ATTACK: int = 2
const MINION_HEALTH: int = 3
## [constant DEF_MANY]'s printed order, and the set an event must report.
const PRINTED: Array = ["windfury", "taunt", "lifesteal"]
const SORTED: Array = ["lifesteal", "taunt", "windfury"]
const MANA_POOL: int = 10
## `MatchConfig.boss.health`, unlike any band default, and each hook's damage.
const BOSS_HEALTH: int = 42
const PLAYER_WOUND: int = 3
const BOSS_WOUND: int = 5
## What a hook gives its hero, which `match_started` must not report.
const HOOK_ARMOR: int = 4


class FixtureDb extends RefCounted:
	var cards: Dictionary = {}

	func has(id: String) -> bool:
		return cards.has(id)

	func card(id: String) -> Variant:
		return cards.get(id)


# --- helpers -----------------------------------------------------------------

func _db() -> FixtureDb:
	var db: FixtureDb = FixtureDb.new()
	db.cards[DEF_MANY] = CardFactory.make_minion(DEF_MANY, MINION_COST, MINION_ATTACK, MINION_HEALTH, PRINTED)
	db.cards[DEF_TWICE] = CardFactory.make_minion(DEF_TWICE, MINION_COST, MINION_ATTACK, MINION_HEALTH, ["taunt", "taunt"])
	db.cards[DEF_PLAIN] = CardFactory.make_minion(DEF_PLAIN, MINION_COST, MINION_ATTACK, MINION_HEALTH)
	return db


## A started engine past the mulligan, the player's hand holding [param def_id].
func _engine(log: TestEventLog, def_id: String) -> RulesEngine:
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, {}, {}, TestEffectResolver.new(), _db())
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var state: MatchState = engine.state()
	var player: Dictionary = state.players[SIDE_PLAYER]
	player.hand.clear()
	player.hand.append(MatchFactory.make_card_instance(MatchFactory.alloc_entity_id(state), def_id, "hand"))
	player.mana_current = MANA_POOL
	return engine


## The one `minion_summoned` after [param before], with its payload checked as JSON.
func _summoned(log: TestEventLog, before: int) -> Dictionary:
	var found: Array[Dictionary] = []
	for event: Dictionary in log.events.slice(before):
		if String(event.type) == "minion_summoned":
			found.append(event)
	assert_int(found.size()).is_equal(1)
	if found.size() != 1:
		return {}
	GameAssertions.assert_json_representable(found[0].payload, "minion_summoned payload")
	return found[0].payload


## The payload of playing [param def_id] from hand to board slot 0.
func _played(def_id: String) -> Dictionary:
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log, def_id)
	var before: int = log.events.size()
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0)).accepted).is_true()
	return _summoned(log, before)


## The payload of [param def_id] arriving through the primitive, on the boss's side.
func _primitive(def_id: String) -> Dictionary:
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log, DEF_PLAIN)
	var before: int = log.events.size()
	assert_int(engine.summon_minion(SIDE_BOSS, def_id, 0)).is_not_equal(RulesEngine.NO_ENTITY)
	return _summoned(log, before)


# --- minion_summoned.keywords (C15, §D) -----------------------------------------

func test_played_minion_reports_its_printed_keywords_sorted() -> void:
	# Arrange, Act
	var payload: Dictionary = _played(DEF_MANY)

	# Assert
	assert_array(payload.get("keywords")).is_equal(SORTED)


func test_summoned_minion_reports_its_printed_keywords_sorted() -> void:
	# Arrange, Act
	var payload: Dictionary = _primitive(DEF_MANY)

	# Assert
	assert_array(payload.get("keywords")).is_equal(SORTED)


func test_played_minion_without_keywords_reports_an_empty_array() -> void:
	# Arrange, Act
	var payload: Dictionary = _played(DEF_PLAIN)

	# Assert: present and empty, not absent
	assert_bool(payload.has("keywords")).is_true()
	assert_array(payload.get("keywords")).is_empty()


func test_summoned_minion_without_keywords_reports_an_empty_array() -> void:
	# Arrange, Act
	var payload: Dictionary = _primitive(DEF_PLAIN)

	# Assert: present and empty, not absent
	assert_bool(payload.has("keywords")).is_true()
	assert_array(payload.get("keywords")).is_empty()


func test_a_keyword_printed_twice_is_reported_once_at_both_sites() -> void:
	# Arrange, Act
	var played: Dictionary = _played(DEF_TWICE)
	var summoned: Dictionary = _primitive(DEF_TWICE)

	# Assert
	assert_array(played.get("keywords")).is_equal(["taunt"])
	assert_array(summoned.get("keywords")).is_equal(["taunt"])


func test_played_payload_changes_no_other_field() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log, DEF_MANY)
	var before: int = log.events.size()

	# Act
	assert_bool(engine.submit(MatchRecords.play_card(SIDE_PLAYER, 0, 0)).accepted).is_true()

	# Assert: the five earlier fields as they were, and only `keywords` beside them
	var minion: Dictionary = engine.state().players[SIDE_PLAYER].board[0]
	assert_dict(_summoned(log, before)).is_equal({
		"side": SIDE_PLAYER, "entity_id": int(minion.entity_id), "card_id": DEF_MANY, "position": 0,
		"attack": MINION_ATTACK, "health": MINION_HEALTH, "keywords": SORTED,
	})


func test_summoned_payload_changes_no_other_field() -> void:
	# Arrange
	var log: TestEventLog = TestEventLog.new()
	var engine: RulesEngine = _engine(log, DEF_PLAIN)
	var before: int = log.events.size()

	# Act
	var id: int = engine.summon_minion(SIDE_BOSS, DEF_MANY, 0)

	# Assert: the five earlier fields as they were, and only `keywords` beside them
	assert_dict(_summoned(log, before)).is_equal({
		"side": SIDE_BOSS, "entity_id": id, "card_id": DEF_MANY, "position": 0,
		"attack": MINION_ATTACK, "health": MINION_HEALTH, "keywords": SORTED,
	})


# --- match_started.starting_health (C3 step 8, C15, §D, DD-X35) -------------------

## Hook script: [constant PLAYER_WOUND] or [constant BOSS_WOUND] to its own hero.
func _wound(engine: RulesEngine, _entry: Dictionary, side: StringName, _ctx: Dictionary) -> void:
	var amount: int = PLAYER_WOUND if String(side) == SIDE_PLAYER else BOSS_WOUND
	@warning_ignore("return_value_discarded")
	engine.apply_damage(int(engine.state().players[String(side)].hero.entity_id), amount, null)


## Hook script: [constant HOOK_ARMOR] to its own hero.
func _armor(engine: RulesEngine, _entry: Dictionary, side: StringName, _ctx: Dictionary) -> void:
	engine.apply_armor(String(side), HOOK_ARMOR)


## The `MatchConfig` overrides of one `on_match_start` hook per side running [param script].
func _hooked(resolver: TestEffectResolver, script: Callable) -> Dictionary:
	var player_hook: HookInstaller = MatchFactory.make_hook_installer("t_start", SIDE_PLAYER, [&"on_match_start"])
	var boss_hook: HookInstaller = MatchFactory.make_hook_installer("boss_start", SIDE_BOSS, [&"on_match_start"])
	resolver.hook_scripts["t_start.0"] = script
	resolver.hook_scripts["boss_start.0"] = script
	return {"player": {"hook_installers": [player_hook]}, "boss": {"hook_installers": [boss_hook], "health": BOSS_HEALTH}}


## The `match_started` payload of a match started with [param overrides], the
## mulligan kept, with [param log] taking the events.
func _started(log: TestEventLog, resolver: TestEffectResolver, overrides: Dictionary) -> Dictionary:
	var engine: RulesEngine = MatchFactory.make_started_engine(null, log, overrides, {}, resolver, _db())
	assert_bool(engine.submit(engine.legal_commands()[0]).accepted).is_true()
	var found: Array[Dictionary] = log.of_type(&"match_started")
	assert_int(found.size()).is_equal(1)
	if found.size() != 1:
		return {}
	GameAssertions.assert_json_representable(found[0].payload, "match_started payload")
	return found[0].payload


func test_match_started_reports_the_health_each_hook_left() -> void:
	# Arrange
	var resolver: TestEffectResolver = TestEffectResolver.new()

	# Act
	var payload: Dictionary = _started(TestEventLog.new(), resolver, _hooked(resolver, _wound))

	# Assert
	assert_dict(payload.get("starting_health", {})).is_equal({
		"player": TestConstants.PLAYER_STARTING_HEALTH - PLAYER_WOUND, "boss": BOSS_HEALTH - BOSS_WOUND,
	})


func test_match_started_without_hooks_reports_the_seated_health() -> void:
	# Arrange, Act
	var payload: Dictionary = _started(TestEventLog.new(), TestEffectResolver.new(), {"boss": {"health": BOSS_HEALTH}})

	# Assert
	assert_dict(payload.get("starting_health", {})).is_equal({
		"player": TestConstants.PLAYER_STARTING_HEALTH, "boss": BOSS_HEALTH,
	})


func test_match_started_adds_only_starting_health_even_when_a_hook_gives_armour() -> void:
	# Arrange: a hook gives armour, which DD-X35 leaves off the event
	var resolver: TestEffectResolver = TestEffectResolver.new()
	var log: TestEventLog = TestEventLog.new()
	var overrides: Dictionary = _hooked(resolver, _armor)

	# Act
	var payload: Dictionary = _started(log, resolver, overrides)

	# Assert: exactly the five earlier keys and `starting_health`
	assert_int(log.count(&"armor_gained")).is_equal(2)
	var keys: Array = payload.keys()
	keys.sort()
	assert_array(keys).is_equal(["boss_deck_size", "boss_id", "floor", "hero_id", "player_deck_size", "starting_health"])
	assert_dict(payload.get("starting_health", {})).is_equal({
		"player": TestConstants.PLAYER_STARTING_HEALTH, "boss": BOSS_HEALTH,
	})
