## L2: the projection equals the engine at every step (match-ui story 003;
## design/gdd/match-ui.md AC L2, U3). A `MatchViewState` subscribed to the log of a
## real `RulesEngine`, playing full matches of the shipped decks through the real
## `EffectResolver`, is compared with `MatchQuery.snapshot` after every `seq`.
##
## Both sides are played by [method _next_command] straight on the engine: no boss
## planner is under test here, so the suite does not depend on the driver's schedule.
## "Hand ids" means the player's: L3 stores no boss `card_id`, so the boss's is a
## count. `hero.health` stays null in the view until an event reports it (MUI-001),
## so a null reads as "nothing to disagree with" and is counted, not compared.
##
## Token `keywords` are compared at every `seq` that compares boards: `minion_summoned`
## reports the effective set (match-rules story 020). The null `hero.health` skip stays
## until the starting health is on an event, which waits on that story's open question.
extends GdUnitTestSuite

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const SHIPPED_ROOT: String = "res://assets/data/"
const HERO_WAR: String = "hero_war"
const SIDE_PLAYER: String = MatchRecords.SIDE_PLAYER
const SIDE_BOSS: String = MatchRecords.SIDE_BOSS
## Far more commands than a match of these decks takes; the rest is conceded.
const COMMAND_CAP: int = 600
## Spreads the pick over a legal list, so the seeds play different matches.
const PICK_STRIDE: int = 7
## Each row: a shipped boss and the seed of one full match against it.
const MATCHES: Array = [["boss_torchbearer", 11], ["boss_rat_king", 12], ["boss_gatekeeper", 13], ["boss_rot_warden", 14]]
## Events the engine sends part-way through a batch it already applied: every death
## of a pass leaves the board before the first `minion_died`, and the Start step's
## reset comes after the view applied it on `turn_started`. Boards are not compared
## on these; every other `seq` compares them, so a wrong projection is still caught.
const MID_BATCH: Array[String] = ["minion_died", "card_to_graveyard", "turn_started", "crystal_gained", "mana_refilled"]
## Token fields compared once a command has run: `attacks_used` moves at the attack's
## damage step, and the `attack_resolved` that reports it follows the triggers.
const SETTLED_ONLY: Array[String] = ["attacks_used"]
## Event types the matches must reach, or the parity above says little.
const MUST_SEE: Array[String] = ["minion_summoned", "attack_declared", "damage_dealt", "minion_died", "card_played", "weapon_equipped"]

var _engine: RulesEngine
var _query: MatchQuery
var _view: MatchViewState
var _log: TestEventLog
var _mismatches: Array[String] = []
var _reported: Dictionary = {}
## True between commands, when no batch is open.
var _settled: bool = false
var _compared: int = 0
var _health_compared: int = 0
var _seen: Dictionary = {}


func before_test() -> void:
	_engine = null
	_mismatches = []
	_reported = {}
	_settled = false
	_compared = 0
	_health_compared = 0
	_seen = {}


func after_test() -> void:
	if _engine != null:
		_engine.end_match()
	_engine = null


func _loaded() -> CardDatabase:
	var boot: Node = auto_free(BOOT_SCRIPT.new())
	var db: CardDatabase = CardDatabase.new(DataLoader.new(SHIPPED_ROOT))
	db.load(boot._collect_validators(null, true))
	return db


## An engine over [param db] with a view on its log from the first event on.
func _start(db: CardDatabase, boss_id: String, seed_value: int) -> void:
	var hero: Dictionary = db.hero(HERO_WAR)
	var boss: Dictionary = db.boss(boss_id)
	_log = TestEventLog.new()
	var config: Dictionary = MatchFactory.make_started_config(TestRngService.new(seed_value), _log, {
		"player": {"hero_def_id": HERO_WAR, "deck": Array(hero.starter_deck)},
		"boss": {"boss_def_id": boss_id, "deck": Array(boss.deck)},
	})
	_engine = RulesEngine.new(db, db.config("match_rules"), EffectResolver.new(db, db.config("card_effects"), str(hero.set)))
	_query = MatchQuery.new(_engine, db, {})
	_view = MatchViewState.new(db.config("match_ui"))
	_log.subscribe(_on_event)
	_engine.start(config)


## The subscriber: the view takes the event and the two are compared at this `seq`.
func _on_event(event: Dictionary) -> void:
	@warning_ignore("return_value_discarded")
	_view.apply(event)
	_seen[str(event.type)] = true
	_settled = false
	_compare("seq %d %s" % [int(event.seq), str(event.type)], not MID_BATCH.has(str(event.type)))


## [param boards]: false at a [constant MID_BATCH] event.
func _compare(at: String, boards: bool = true) -> void:
	_compared += 1
	for side: String in MatchRecords.SIDES:
		var shown: Dictionary = _view.side(StringName(side))
		var truth: Dictionary = _query.snapshot(side)
		_expect(at, side, "armor", shown.hero.armor, truth.hero.armor)
		_expect(at, side, "mana", shown.mana.available, truth.mana.available)
		_expect(at, side, "mana_max", shown.mana.max, truth.mana.max)
		_expect(at, side, "deck_count", shown.deck_count, truth.deck_count)
		_expect(at, side, "hand", _hand_ids(shown.hand), truth.hand)
		if boards:
			_expect_board(at, side, _tokens(shown.board), _tokens(truth.board))
		if shown.hero.health != null:
			_health_compared += 1
			_expect(at, side, "hero_health", shown.hero.health, truth.hero.health)


## One board at a time, field by field, so a failure names the field that moved.
func _expect_board(at: String, side: String, shown: Array, truth: Array) -> void:
	_expect(at, side, "board ids", shown.map(_id_of), truth.map(_id_of))
	if shown.size() != truth.size():
		return
	for index: int in shown.size():
		for field: String in (truth[index] as Dictionary).keys():
			if _settled or not SETTLED_ONLY.has(field):
				_expect(at, side, "token %s" % field, shown[index][field], truth[index][field])


static func _id_of(token: Dictionary) -> int:
	return int(token.entity_id)


## Records the first mismatch of each field at each event type.
func _expect(at: String, side: String, field: String, shown: Variant, truth: Variant) -> void:
	if shown == truth:
		return
	var key: String = "%s %s" % [at.get_slice(" ", 2), field]
	if not _reported.has(key):
		_reported[key] = true
		_mismatches.append("%s: %s %s view %s engine %s" % [at, side, field, str(shown), str(truth)])


## The player's hand as ids, or the boss's count as it stands.
static func _hand_ids(hand: Variant) -> Variant:
	if hand is Array:
		return (hand as Array).map(func(card: Dictionary) -> int: return int(card.instance_id))
	return hand


## [param board] with only the token fields and sorted keywords, so two sources compare.
static func _tokens(board: Array) -> Array:
	var out: Array = []
	for token: Dictionary in board:
		var keywords: Array = (token.keywords as Array).duplicate()
		keywords.sort()
		out.append({
			"entity_id": token.entity_id, "card_id": token.card_id, "attack": token.attack,
			"health": token.health, "max_health": token.max_health, "keywords": keywords,
			"frozen": token.frozen, "silenced": token.silenced, "attacks_used": token.attacks_used,
		})
	return out


## Keeps every card at the mulligan; else the first type that has a legal command, in
## the order that makes the most happen, picked by [param step].
func _next_command(step: int) -> Dictionary:
	var legal: Array = _engine.legal_commands()
	for type: String in [MatchRecords.CMD_MULLIGAN, MatchRecords.CMD_CHOOSE, MatchRecords.CMD_PLAY_CARD, MatchRecords.CMD_USE_HERO_POWER, MatchRecords.CMD_ATTACK]:
		var of_type: Array = legal.filter(func(c: Dictionary) -> bool: return str(c.type) == type)
		if not of_type.is_empty():
			return of_type[(step * PICK_STRIDE) % of_type.size()]
	return MatchRecords.end_turn(String(_engine.active_side()))


## Plays to `Ended`, or concedes at [constant COMMAND_CAP]. A rejection stops the run.
func _play_out() -> void:
	for step: int in COMMAND_CAP:
		if _engine.phase() == MatchState.PHASE_ENDED:
			return
		var result: Dictionary = _engine.submit(_next_command(step))
		assert_bool(result.accepted).override_failure_message("policy command rejected: %s" % str(result.rejection)).is_true()
		if not result.accepted:
			return
		_settled = true
		_compare("after command %d" % step)
	@warning_ignore("return_value_discarded")
	_engine.submit(MatchRecords.concede(SIDE_PLAYER))


func test_the_projection_equals_the_engine_after_every_seq_of_full_shipped_matches() -> void:
	# Arrange
	var db: CardDatabase = _loaded()

	# Act
	for row: Array in MATCHES:
		_start(db, str(row[0]), int(row[1]))
		_play_out()
		_settled = true
		_compare("the end of %s" % str(row[0]))
		_engine.end_match()

	# Assert
	assert_array(_mismatches).is_empty()
	assert_int(_compared).override_failure_message("no event reached the view").is_greater(1000)
	assert_int(_health_compared).override_failure_message("hero health was never compared").is_greater(0)
	for type: String in MUST_SEE:
		assert_bool(_seen.has(type)).override_failure_message("no %s in any match" % type).is_true()


func test_a_view_rebuilt_from_events_since_zero_equals_the_engine_at_the_end() -> void:
	# Arrange
	var db: CardDatabase = _loaded()
	_start(db, str(MATCHES[0][0]), int(MATCHES[0][1]))
	_play_out()
	var fresh: MatchViewState = MatchViewState.new(db.config("match_ui"))

	# Act
	for event: Dictionary in _log.events_since(0):
		@warning_ignore("return_value_discarded")
		fresh.apply(event)
	_view = fresh
	_settled = true
	_compare("rebuilt")

	# Assert
	assert_array(_mismatches).is_empty()
