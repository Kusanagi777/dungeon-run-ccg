## EventLog.reduce_to_summary() — `match_summary` and `damage_by_card`.
##
## Story: production/epics/rng-event-log/story-008-match-summary-reduction.md
## GDD: design/gdd/rng-event-log.md rules 18-19, event catalogue `match_summary`;
## match-rules C14 (`MatchResult`) and C15 (`damage_dealt` payload). ADR-0003
## Decision 9. Every log is built directly; no wall clock, no file I/O.
extends GdUnitTestSuite

const CAP: int = TestConstants.MAX_MATCH_EVENTS
const FLOOR: int = 3
const PLAYER: String = "player"
const BOSS: String = "boss"
## Entity ids (match-rules C1: unique per match, heroes included).
const PLAYER_HERO: int = 1
const BOSS_HERO: int = 2
const MINION: int = 7
const BOSS_MINION: int = 8
const WEAPON: int = 9
const SPELL: int = 10
const UNKNOWN: int = 99
const TURNS: int = 14
const SUMMARY_KEYS: Array[String] = ["floor", "result", "winner", "reason", "turns", "event_count", "cards_played", "damage_by_card"]

const NOT_SEALED: String = "EventLog.reduce_to_summary: the match log is not sealed by match_ended"


func _log() -> EventLog:
	var log: EventLog = EventLog.new(CAP, EventLog.SCOPE_MATCH, {"floor": FLOOR})
	log.append(&"match_started", {"floor": FLOOR, "hero_id": PLAYER_HERO, "boss_id": BOSS_HERO, "player_deck_size": 15, "boss_deck_size": 15})
	return log


func _damage(log: EventLog, source: int, dealt: int, requested: int = -1, prevented: int = 0) -> void:
	var asked: int = dealt + prevented if requested < 0 else requested
	log.append(&"damage_dealt", {
		"source": source, "target": BOSS_HERO, "requested": asked, "prevented": prevented,
		"armor_absorbed": 0, "dealt": dealt, "health_after": 10,
	})


func _end(log: EventLog, result: String = "win", winner: Variant = "PLAYER", reason: String = "hero_dead") -> void:
	log.append(&"match_ended", {"result": result, "winner": winner, "reason": reason, "floor": FLOOR, "turns": TURNS})


# --- AC-1: damage_by_card sums `dealt` for player sources ---------------------

func test_dealt_from_a_player_minion_is_summed_and_boss_sources_are_excluded() -> void:
	# Arrange
	var log: EventLog = _log()
	log.append(&"minion_summoned", {"side": PLAYER, "instance_id": MINION, "card_id": "card_a", "board_index": 0, "attack": 3, "health": 3, "keywords": []})
	log.append(&"minion_summoned", {"side": BOSS, "instance_id": BOSS_MINION, "card_id": "boss_card", "board_index": 0, "attack": 9, "health": 9, "keywords": []})
	_damage(log, MINION, 3)
	_damage(log, MINION, 4)
	_damage(log, MINION, 5, 6, 1)
	_damage(log, BOSS_MINION, 9)
	_end(log)

	# Act
	var summary: Dictionary = log.reduce_to_summary()

	# Assert
	assert_dict(summary.damage_by_card).is_equal({"card_a": 12})


# --- AC-2: the attribution map ------------------------------------------------

func test_weapon_hero_power_and_played_card_attribute_to_their_ids() -> void:
	# Arrange
	var log: EventLog = _log()
	log.append(&"weapon_equipped", {"side": PLAYER, "instance_id": WEAPON, "card_id": "axe", "attack": 3, "durability": 2})
	log.append(&"card_played", {"side": PLAYER, "instance_id": SPELL, "card_id": "fireball", "cost_paid": 4, "target_id": BOSS_HERO, "board_index": -1})
	log.append(&"hero_power_used", {"side": PLAYER, "power_id": "war_power", "target_id": BOSS_HERO})
	_damage(log, WEAPON, 3)
	_damage(log, SPELL, 6)
	_damage(log, PLAYER_HERO, 2)
	_end(log)

	# Act
	var summary: Dictionary = log.reduce_to_summary()

	# Assert
	assert_dict(summary.damage_by_card).is_equal({"axe": 3, "fireball": 6, "war_power": 2})


func test_unmapped_sources_attribute_to_nothing_without_an_error() -> void:
	# Arrange — fatigue (no source instance), an unknown id, the hero before any hero power
	var log: EventLog = _log()
	log.append(&"fatigue_damage", {"side": PLAYER, "amount": 1})
	_damage(log, PLAYER_HERO, 1)
	_damage(log, UNKNOWN, 4)
	log.append(&"hero_power_used", {"side": BOSS, "power_id": "boss_power", "target_id": PLAYER_HERO})
	_damage(log, BOSS_HERO, 2)
	_end(log, "loss", "BOSS")
	var out: Dictionary = {}

	# Act
	await assert_error(func() -> void: out.summary = log.reduce_to_summary()).is_success()

	# Assert
	assert_dict(out.summary.damage_by_card).is_empty()


# --- AC-3: summary shape ------------------------------------------------------

func test_summary_has_exactly_the_catalogue_fields_copied_from_match_ended() -> void:
	# Arrange
	var log: EventLog = _log()
	log.append(&"card_played", {"side": PLAYER, "instance_id": SPELL, "card_id": "fireball", "cost_paid": 4, "target_id": BOSS_HERO, "board_index": -1})
	log.append(&"card_played", {"side": PLAYER, "instance_id": MINION, "card_id": "card_a", "cost_paid": 2, "target_id": null, "board_index": 0})
	log.append(&"card_played", {"side": BOSS, "instance_id": BOSS_MINION, "card_id": "boss_card", "cost_paid": 3, "target_id": null, "board_index": 0})
	log.append(&"command_rejected", {"side": PLAYER, "command": "play_card", "code": "NOT_ENOUGH_MANA", "diagnostic": true})
	_end(log, "win", "PLAYER", "concede")

	# Act
	var summary: Dictionary = log.reduce_to_summary()

	# Assert
	assert_array(summary.keys()).contains_exactly_in_any_order(SUMMARY_KEYS)
	assert_int(summary.floor).is_equal(FLOOR)
	assert_str(summary.result).is_equal("win")
	assert_str(summary.winner).is_equal("PLAYER")
	assert_str(summary.reason).is_equal("concede")
	assert_int(summary.turns).is_equal(TURNS)
	assert_int(summary.event_count).is_equal(log.size())
	assert_int(summary.cards_played).is_equal(2)
	assert_dict(summary.damage_by_card).is_empty()
	assert_bool(GameAssertions.is_json_representable(summary)).is_true()


func test_a_fault_result_copies_a_null_winner() -> void:
	# Arrange
	var log: EventLog = _log()
	_end(log, "fault", null, "resolution_overflow")

	# Act
	var summary: Dictionary = log.reduce_to_summary()

	# Assert
	assert_str(summary.result).is_equal("fault")
	assert_that(summary.winner).is_null()
	assert_str(summary.reason).is_equal("resolution_overflow")


func test_an_unsealed_log_gives_an_empty_summary_and_an_error() -> void:
	# Arrange
	var log: EventLog = _log()
	_damage(log, MINION, 3)
	var out: Dictionary = {}

	# Act
	await assert_error(func() -> void: out.summary = log.reduce_to_summary()).is_push_error(NOT_SEALED)

	# Assert
	assert_dict(out.summary).is_empty()


func test_reduction_leaves_the_log_unchanged_and_survives_a_json_round_trip() -> void:
	# Arrange
	var log: EventLog = _log()
	log.append(&"minion_summoned", {"side": PLAYER, "instance_id": MINION, "card_id": "card_a", "board_index": 0, "attack": 3, "health": 3, "keywords": []})
	_damage(log, MINION, 3)
	_end(log)
	var before: String = log.to_json()

	# Act
	var summary: Dictionary = log.reduce_to_summary()
	var round_trip: Dictionary = EventLog.from_json(before).reduce_to_summary()

	# Assert
	assert_str(log.to_json()).is_equal(before)
	assert_dict(round_trip).is_equal(summary)
