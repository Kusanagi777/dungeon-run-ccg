## The `config("match_ui")` body and the DD-X07 settings the match-ui unit
## tests inject (match-ui stories 001 and 002).
##
## `assets/data/match_ui.json` ships with content story 001 (sprint 3, W3); until
## it merges, MUI-001 / MUI-002 read this fixture body built from
## `design/gdd/match-ui.md` (sprint-003 plan, QA plan "Config"). Every value
## cites its GDD row. When the shipped file lands, re-run L7 against it and keep
## this body in step (QA plan "Rebase").
##
## Key names are the GDD's own handles: `d_base.<step kind>` (F3 table plus the
## U3 table's extra step kinds), `SPEED_DIV`, `COALESCE_THRESHOLD`,
## `silent_types` (U3), `FEED_MAX_LINES` (F5) and `impact_ms` (F3 "Impact
## extras", match-rules Game Feel).
## [codeblock]
## var view: MatchViewState = MatchViewState.new(MatchUiTestConfig.body())
## var queue: AnimationQueue = AnimationQueue.new(MatchUiTestConfig.body(), MatchUiTestConfig.settings({"anim_speed": "fast"}))
## [/codeblock]
class_name MatchUiTestConfig
extends RefCounted


## The `match_ui` config body (a fresh deep copy each call).
static func body() -> Dictionary:
	return {
		"d_base": {
			# F3 "Base durations (data file)" — the 17 named kinds
			"play_card": 0.25, "attack_lunge": 0.35, "damage_pop": 0.4, "heal_pop": 0.4,
			"death_group": 0.3, "gap_close": 0.2, "draw": 0.2, "burn": 0.4, "shield_pop": 0.25,
			"badge": 0.15, "stat_recolour": 0.15, "turn_banner": 0.4, "intent_show": 0.3,
			"overlay_open": 0.2, "overlay_close": 0.15, "reject_shake": 0.2, "end_banner": 0.6,
			# U3 event → step table: kinds the table times but F3 does not name
			"mulligan_open": 0.2, "mulligan_flip": 0.3, "deck_tick": 0.15, "fatigue_label": 0.4,
			"discard": 0.25, "summon": 0.2, "summon_failed": 0.3, "weapon_update": 0.2,
			"weapon_shatter": 0.3, "power_press": 0.15, "power_relight": 0.15, "attack_return": 0.15,
			"rim_glow": 0.15, "fizzle": 0.2,
			# U3 `ai_intent_committed` "commit beat `intent_banner_s`" (Boss AI data, 0.3)
			"intent_commit": 0.3,
		},
		# F3 / Tuning Knobs `SPEED_DIV`: normal 1.0, fast 2.0 (`instant` never divides)
		"SPEED_DIV": {"normal": 1.0, "fast": 2.0},
		# U4.3 / Tuning Knobs `COALESCE_THRESHOLD`
		"COALESCE_THRESHOLD": 8,
		# U3 "Silent set"
		"silent_types": ["turn_reset", "card_to_graveyard"],
		# F5 / Tuning Knobs `FEED_MAX_LINES`
		"FEED_MAX_LINES": 200,
		# F3 "Impact extras (hit-stop 60/90 ms, shake 120 ms, lethal slow-down 400 ms)"
		"impact_ms": {"hit_stop": 60, "hit_stop_heavy": 90, "shake": 120, "slow": 400},
	}


## The `config("match_ui")` envelope `{schema_version, config}` around [method body].
static func file() -> Dictionary:
	return CardFactory.make_config_file(body())


## The DD-X07 settings dictionary `AnimationQueue` takes: the M9
## `profile_defaults` values (meta-progression M9; `boot_meta_stub_test.gd`
## `_profile_defaults`) for the keys Match UI reads, with [param overrides]
## merged over them.
static func settings(overrides: Dictionary = {}) -> Dictionary:
	var out: Dictionary = {"anim_speed": "normal", "reduce_motion": false, "action_delay_ms": 600}
	out.merge(overrides, true)
	return out


## The fixture stream for L1 (a committed fixture, read-only).
const FULL_MATCH_STREAM: String = "res://tests/fixtures/match_ui/streams/full_match_torchbearer.json"


## The events of [constant FULL_MATCH_STREAM], rebuilt through
## `EventLog.from_json` (so the fixture is also checked as rule 11 envelopes).
static func full_match_events() -> Array[Dictionary]:
	var text: String = FileAccess.get_file_as_string(FULL_MATCH_STREAM)
	var log: EventLog = EventLog.from_json(text)
	if log == null:
		push_error("MatchUiTestConfig: %s did not load" % FULL_MATCH_STREAM)
		return []
	return log.events_since(0)
