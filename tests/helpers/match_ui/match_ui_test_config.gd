## The `config("match_ui")` body and the DD-X07 settings the match-ui unit
## tests inject (match-ui stories 001 and 002).
##
## `assets/data/match_ui.json` ships with content story 001 (sprint 3, W3); until
## it merges, MUI-001 / MUI-002 read this fixture body built from
## `design/gdd/match-ui.md` (sprint-003 plan, QA plan "Config"). Every value
## cites its GDD row. When the shipped file lands, re-run L7 against it and keep
## this body in step (QA plan "Rebase").
##
## Key names are snake_case file keys (DD-T01; code review 2026-11-04 renamed
## the three that were UPPER_CASE): `d_base.<step kind>` (F3 table plus the
## U3 table's extra step kinds), `speed_div` (GDD knob `SPEED_DIV`),
## `coalesce_threshold` (`COALESCE_THRESHOLD`), `silent_types` (U3),
## `feed_max_lines` (`FEED_MAX_LINES`, F5) and `impact_ms` (F3 "Impact
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
			# U6.6 / Edge Cases: the 0.4 s "boss discovers…" label (match-ui story 010)
			"boss_discovers": 0.4,
			# match-ui story 021: a hook-hosted `effect_resolved` flares its chip
			"treasure_flare": 0.15,
		},
		# F4 / Tuning Knobs `MIN_ACTION_GAP_S`, `K_MIN` (match-ui story 010)
		"min_action_gap_s": 0.15,
		"k_min": 0.25,
		# F3 / Tuning Knobs `SPEED_DIV`: normal 1.0, fast 2.0 (`instant` never divides)
		"speed_div": {"normal": 1.0, "fast": 2.0},
		# U4.3 / Tuning Knobs `COALESCE_THRESHOLD`
		"coalesce_threshold": 8,
		# U3 "Silent set"
		"silent_types": ["turn_reset", "card_to_graveyard"],
		# F5 / Tuning Knobs `FEED_MAX_LINES`
		"feed_max_lines": 200,
		# F3 "Impact extras (hit-stop 60/90 ms, shake 120 ms, lethal slow-down 400 ms)"
		"impact_ms": {"hit_stop": 60, "hit_stop_heavy": 90, "shake": 120, "slow": 400},
		# Game Feel, Impact Moments: hero damage from 5 is heavy; the shake is 3 px
		"impact": {"heavy_hero_damage": 5, "shake_px": 3, "shake_cycles": 3},
		# Tuning Knobs `CLICK_DRAG_PX`, `END_TURN_ARM_MS`, `MATCH_END_AUTO_S`
		"click_drag_px": 8,
		"end_turn_arm_ms": 300,
		"match_end_auto_s": 4,
		# F5 / Tuning Knobs `FEED_GROUP_COLLAPSE`, `FEED_TICKER_LINES`
		"feed_group_collapse": 6,
		"feed_ticker_lines": 3,
		# U5 `REJECTION_TOOLTIP_S`
		"rejection_tooltip_s": 1.5,
		# F1 / F2 (`HAND_W`, `HAND_GAP`, `ARC_H`, `THETA_*`, `HOVER_*`)
		"hand": {
			"card_w": 150, "card_h": 210, "hand_gap": 8, "hand_w": 800, "hand_cx": 640, "hand_base_y": 696,
			"arc_h": 24, "theta_step_max": 4.0, "theta_total_max": 30.0, "hover_scale": 1.5, "hover_in_s": 0.1,
			"viewport_w": 1280, "return_s": 0.15, "park_top_y": 438, "lift_px": 8,
		},
		# F6 hero slots; `power_press_scale` is the U3 `hero_power_used` press
		"hero": {
			"stamp_size": 40, "crystal_px": 16, "crystal_gap": 4, "crystal_count": 10, "lift_px": 4,
			"power_lift_px": 2, "power_press_scale": 0.9,
		},
	}


## The shipped `config("match_ui")` body, a fresh deep copy, read as the imported JSON
## resource. A suite that drives a presenter needs its layout and palette, which
## [method body] does not carry.
static func shipped() -> Dictionary:
	var resource: JSON = load(SHIPPED)
	return ((resource.data as Dictionary).config as Dictionary).duplicate(true)


## [method shipped] with [method body] over it, section by section, so a presenter runs on
## the values this helper pins. [param overrides] lands last: `{section: {key: value}}`.
static func presenter_body(overrides: Dictionary = {}) -> Dictionary:
	var out: Dictionary = shipped()
	for layer: Dictionary in [body(), overrides]:
		for key: String in layer:
			if layer[key] is Dictionary and out.get(key) is Dictionary:
				(out[key] as Dictionary).merge(layer[key], true)
			else:
				out[key] = layer[key]
	return out


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


## The shipped file [method shipped] reads.
const SHIPPED: String = "res://assets/data/match_ui.json"
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
