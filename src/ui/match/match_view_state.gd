## The match presentation model: a pure projection of the match event log
## (design/gdd/match-ui.md U3, U1 `MatchViewState` row; ADR-0009 Decision 2 and
## Key Interfaces; ADR-0001 — presenters render numbers from events, not
## queries).
##
## [method apply] takes one rule 11 envelope `{seq, turn, type, payload,
## cause_seq}` (ADR-0003) and returns the `AnimStep`s that show it. Every event
## is applied immediately, in `seq` order (U3.1): the fields always hold the
## engine's state as of the last event seen, and only the *display* lags (the
## `AnimationQueue`, story 002). Same events in, same fields and same steps out —
## no clock, no RNG, no engine read, no Node. Event names and payloads are
## match-rules C15's (authoritative, DD-X04), read where the merged rules
## engine emits them and otherwise from the rng-event-log catalogue.
##
## Filters, in order (U3 rules 4a, the silent set, 4):
## 1. `payload.diagnostic == true` changes nothing and yields no step and no
##    feed line — except the player's own `command_rejected` (one `reject_shake`
##    step carrying the code, one `feed.command_rejected` line). With the debug
##    overlay on ([method set_debug_overlay], `--ai-debug`, story 022) every
##    diagnostic also adds a `feed.diag.<type>` line and `ai_decision` fills
##    [member debug_buffer].
## 2. A type in `config("match_ui").silent_types` changes nothing, no step, no line.
## 3. A type in none of the U3 table, the silent set or the diagnostic class
##    changes nothing but one `feed.unknown` line carrying the type name.
##
## Hidden information (U3.2): a boss `card_drawn` / `card_added_to_hand` stores
## the instance id only, so the boss hand is a count; a boss `discover_offered`
## / `choice_requested` stores no options; their feed-line params drop the same
## fields.
##
## Every step's `base_duration_s` is `config("match_ui").d_base[kind]`, never a
## literal. `group_id` is the `seq` of the event's command root (walk
## `cause_seq` to 0) through a per-turn `seq → root` map, so it is O(1) per
## event; the map is cleared on `turn_started`.
## [codeblock]
## var view := MatchViewState.new(db.config("match_ui"))
## for event: Dictionary in log.events_since(0):
##     for step: AnimStep in view.apply(event):
##         queue.enqueue(step)
## print(view.side(&"player").hero.health)
## [/codeblock]
class_name MatchViewState
extends RefCounted

## The player's `side` value (match-rules C1; rng-event-log catalogue).
const SIDE_PLAYER: String = "player"
## The boss's `side` value.
const SIDE_BOSS: String = "boss"
## Match-rules C4 phase names the projection sets itself, because the engine
## enters them without a `phase_changed` (Start step on `turn_started`, End
## step on `turn_ending`). Every other phase comes from `phase_changed.phase`.
const PHASE_START: String = "start"
const PHASE_END: String = "end"
## `hero.power_state` values (U3 `hero_power_used` / `hero_power_refreshed`).
const POWER_READY: String = "ready"
const POWER_USED: String = "used"
## `result.result` set by `log_overflow` / `resolution_overflow` before their `match_ended`.
const RESULT_FAULT: String = "fault"
## Feed-line keys (U10: `feed.<type>`; rule 4 / 4a keys).
const FEED_PREFIX: String = "feed."
const FEED_UNKNOWN: String = "feed.unknown"
const FEED_DIAG_PREFIX: String = "feed.diag."
const FEED_COMMAND_REJECTED: String = "feed.command_rejected"

const _KEYWORD_DIVINE_SHIELD: String = "divine_shield"
const _KEYWORD_STEALTH: String = "stealth"
## `auras_recomputed` hand entries' `zone` (match-rules C15, DD-X26).
const _ZONE_HAND: String = "hand"
## `auras_recomputed` hero-power entries' `zone` (match-rules C15, DD-X29).
const _ZONE_HERO_POWER: String = "hero_power"
const _ENCHANT_REASON_SET_STATS: String = "set_stats"
const _TYPE_COMMAND_REJECTED: String = "command_rejected"
const _TYPE_AI_DECISION: String = "ai_decision"
const _TYPE_MINION_DIED: String = "minion_died"
const _TYPE_TURN_STARTED: String = "turn_started"
## The first fatigue counter a side can take (match-rules F5 `k` starts at 1).
const _FIRST_FATIGUE: int = 1

## The current match-rules phase (`phase_changed.phase`, or Start / End above).
var phase: String = ""
## The side whose turn it is (`turn_started.side` / `phase_changed.side`).
var active_side: String = ""
## The global turn number (`turn_started.turn`).
var turn: int = 0
## The boss's current telegraph (`ai_intent_shown` / `ai_intent_committed` payload, incl. `effective_mode`), or null.
var intent: Variant = null
## `{side, kind, options, source_id, effect_id}` for a player Choice, `{side, kind}` for a boss one, or null.
var pending_choice: Variant = null
## The instance ids offered by `mulligan_offered`, until `mulligan_resolved`; else null.
var pending_mulligan: Variant = null
## Card-effects C5 per-source counters: `{source_id: {key: value}}` (`counter_changed`).
var counters: Dictionary = {}
## Sources with a queued trigger (rim glow on): `{instance_id: true}`.
var armed_sources: Dictionary = {}
## Once-per-turn trigger sources spent this turn (dimmed): `{instance_id: true}`; cleared on `turn_started`.
var exhausted_sources: Dictionary = {}
## Feed content `{key, params, group_id}`, newest last, at most `feed_max_lines`; rendering is story 014.
var feed_lines: Array[Dictionary] = []
## The `match_ended` payload (match-rules C14 `MatchResult`), or null while the match runs.
var result: Variant = null
## `ai_decision` events `{seq, type, payload}`, filled only while the debug overlay is on.
var debug_buffer: Array[Dictionary] = []

var _d_base: Dictionary = {}
var _silent: Dictionary = {}
var _feed_max: int = 0
var _debug_overlay: bool = false
# Per side: hero, mana, deck (instance id → true), fatigue_next, hand, board.
var _sides: Dictionary = {}
# Per-turn command-root map: seq → the seq of its root (ADR-0009 Decision 2).
var _roots: Dictionary = {}
# The open run of consecutive `minion_died` sharing a cause: its cause and the
# death_group / gap_close steps it already returned (grown in place).
var _death_cause: int = -1
var _death_steps: Array[AnimStep] = []
# The discover_offered + choice_requested pair of the open player Choice.
var _choice_offered: bool = false
var _choice_requested: bool = false


## A fresh projection over the `config("match_ui")` body [param ui_config]
## (`d_base`, `silent_types`, `feed_max_lines` — the GDD's `FEED_MAX_LINES`
## knob, snake_case per DD-T01; match-ui Tuning Knobs).
## [codeblock]
## var view := MatchViewState.new(db.config("match_ui"))
## [/codeblock]
func _init(ui_config: Dictionary) -> void:
	_d_base = (ui_config.get("d_base", {}) as Dictionary).duplicate(true)
	for type: Variant in ui_config.get("silent_types", []):
		_silent[String(type)] = true
	_feed_max = int(ui_config.get("feed_max_lines", 0))
	for side_name: String in [SIDE_PLAYER, SIDE_BOSS]:
		_sides[side_name] = {
			"hero": {
					"entity_id": null, "health": null, "armor": 0, "weapon": null, "power_state": POWER_READY,
					"power_cost": null, "power_hook_delta": 0, "frozen": false,
				},
			"mana": {"available": 0, "max": 0, "temporary": 0},
			"deck": {},
			"fatigue_next": _FIRST_FATIGUE,
			"hand": [],
			"board": [],
		}


## U3: projects [param event] and returns the steps that show it (possibly
## none). An unknown type never raises (rule 4); a missing payload number
## reads as 0 and an id in play nowhere is ignored.
## [codeblock]
## var steps: Array[AnimStep] = view.apply({"seq": 9, "turn": 3, "type": "card_drawn",
##         "payload": {"side": "player", "instance_id": 12, "card_id": "war_sharpen", "hand_size": 4}, "cause_seq": 0})
## [/codeblock]
func apply(event: Dictionary) -> Array[AnimStep]:
	var type: String = str(event.get("type", ""))
	var seq: int = int(event.get("seq", 0))
	var cause: int = int(event.get("cause_seq", 0))
	var payload: Dictionary = event.get("payload", {}) if event.get("payload") is Dictionary else {}
	if type == _TYPE_TURN_STARTED:
		_roots.clear()
	var group: int = seq if cause == 0 else int(_roots.get(cause, cause))
	_roots[seq] = group
	if type != _TYPE_MINION_DIED:
		_death_cause = -1
		_death_steps = []
	var steps: Array[AnimStep] = []
	# Rule 4a: diagnostics before anything else.
	if payload.get("diagnostic", false) == true:
		_apply_diagnostic(type, seq, group, payload, steps)
		return steps
	if _silent.has(type):
		return steps
	if not _project(type, seq, group, cause, payload, steps):
		_feed(FEED_UNKNOWN, {"type": type}, group)
		return steps
	_feed(FEED_PREFIX + type, _public_params(type, payload), group)
	return steps


## U1 / ADR-0009: [param name]'s zone values as a deep value copy —
## `{hero{entity_id, health, armor, weapon, power_state, power_cost,
## power_hook_delta, frozen}, mana{available, max, temporary}, deck_count,
## fatigue_next, hand, board}`. `hand` is `[{instance_id, card_id}]` for the
## player, plus `effective_cost` once an `auras_recomputed` entry has set it (the
## printed cost until then, DD-X26) and `hook_delta` while hooks moved it (DD-X29),
## and an int count for the boss. `hero.power_cost` is null until an entry sets it
## (`hero_power_cost` until then, DD-X29);
## `board` is `[{entity_id, card_id, attack, health, max_health, keywords,
## frozen, silenced, attacks_used}]` left to right. `hero.health` is null until
## an event reports it (`damage_dealt.health_after`). An unknown side gives `{}`.
## [codeblock]
## var mana: int = view.side(&"player").mana.available
## [/codeblock]
func side(name: StringName) -> Dictionary:
	var key: String = String(name)
	if not _sides.has(key):
		return {}
	var raw: Dictionary = _sides[key]
	var hand: Variant = raw.hand.size() if key == SIDE_BOSS else (raw.hand as Array).duplicate(true)
	return {
		"hero": (raw.hero as Dictionary).duplicate(true),
		"mana": (raw.mana as Dictionary).duplicate(true),
		"deck_count": (raw.deck as Dictionary).size(),
		"fatigue_next": raw.fatigue_next,
		"hand": hand,
		"board": (raw.board as Array).duplicate(true),
	}


## Every field of the view-state as one deep copy, for field-for-field
## comparison (match-ui AC L1) and the idle-invariant reports (U4.6).
## [codeblock]
## assert(view_a.snapshot() == view_b.snapshot())
## [/codeblock]
func snapshot() -> Dictionary:
	return {
		"phase": phase,
		"active_side": active_side,
		"turn": turn,
		"intent": _copy(intent),
		"pending_choice": _copy(pending_choice),
		"pending_mulligan": _copy(pending_mulligan),
		"counters": counters.duplicate(true),
		"armed_sources": armed_sources.duplicate(true),
		"exhausted_sources": exhausted_sources.duplicate(true),
		"feed_lines": feed_lines.duplicate(true),
		"result": _copy(result),
		"debug_buffer": debug_buffer.duplicate(true),
		"sides": _sides.duplicate(true),
	}


## A value copy of the hero, board token or weapon with id [param id] (with
## its `side` added), or `{}` when no such entity is in play.
## [codeblock]
## var token: Dictionary = view.entity(7)   # {entity_id: 7, side: "boss", attack: 3, …}
## [/codeblock]
func entity(id: int) -> Dictionary:
	for side_name: String in [SIDE_PLAYER, SIDE_BOSS]:
		var raw: Dictionary = _sides[side_name]
		var found: Dictionary = {}
		if raw.hero.entity_id != null and int(raw.hero.entity_id) == id:
			found = raw.hero
		elif raw.hero.weapon != null and int(raw.hero.weapon.entity_id) == id:
			found = raw.hero.weapon
		else:
			found = _token_in(raw.board, id)
		if not found.is_empty():
			var copy: Dictionary = found.duplicate(true)
			copy["side"] = side_name
			return copy
	return {}


## The ids of every hero, weapon and board token in play, player side first.
## [codeblock]
## for id: int in view.entity_ids(): print(view.entity(id))
## [/codeblock]
func entity_ids() -> Array[int]:
	var ids: Array[int] = []
	for side_name: String in [SIDE_PLAYER, SIDE_BOSS]:
		var raw: Dictionary = _sides[side_name]
		if raw.hero.entity_id != null:
			ids.append(int(raw.hero.entity_id))
		if raw.hero.weapon != null:
			ids.append(int(raw.hero.weapon.entity_id))
		for token: Dictionary in raw.board:
			ids.append(int(token.entity_id))
	return ids


## U3.4a / U11 `--ai-debug`: while [param on], diagnostics add a
## `feed.diag.<type>` line and `ai_decision` fills [member debug_buffer].
## [codeblock]
## view.set_debug_overlay(args.ai_debug)
## [/codeblock]
func set_debug_overlay(on: bool) -> void:
	_debug_overlay = on


# --- rule 4a -------------------------------------------------------------------

func _apply_diagnostic(type: String, seq: int, group: int, payload: Dictionary, steps: Array[AnimStep]) -> void:
	if type == _TYPE_COMMAND_REJECTED and str(payload.get("side", "")) == SIDE_PLAYER:
		var shake: AnimStep = _step(AnimStep.REJECT_SHAKE, [], group, seq)
		shake.data = {"code": str(payload.get("code", ""))}
		steps.append(shake)
		_feed(FEED_COMMAND_REJECTED, {"command": _copy(payload.get("command")), "code": str(payload.get("code", ""))}, group)
		return
	if not _debug_overlay:
		return
	if type == _TYPE_AI_DECISION:
		debug_buffer.append({"seq": seq, "type": type, "payload": payload.duplicate(true)})
	_feed(FEED_DIAG_PREFIX + type, payload.duplicate(true), group)


# --- the U3 table ------------------------------------------------------------------

## One `match` over the U3 table; false when [param type] is not in it.
func _project(type: String, seq: int, group: int, cause: int, p: Dictionary, steps: Array[AnimStep]) -> bool:
	match type:
		"match_started":
			_sides[SIDE_PLAYER].hero.entity_id = p.get("hero_id")
			_sides[SIDE_BOSS].hero.entity_id = p.get("boss_id")
		"deck_shuffled":
			var deck: Dictionary = {}
			for id: Variant in p.get("instance_ids", []):
				deck[int(id)] = true
			_raw(p).deck = deck
		"mulligan_offered":
			pending_mulligan = _copy(p.get("instance_ids", []))
			steps.append(_step(AnimStep.MULLIGAN_OPEN, _ids(p.get("instance_ids", [])), group, seq))
		"mulligan_resolved":
			var replaced: Array[int] = _ids(p.get("replaced_instance_ids", []))
			for id: int in replaced:
				_remove_from_hand(_raw(p), id)
			pending_mulligan = null
			steps.append(_step(AnimStep.MULLIGAN_FLIP, replaced, group, seq))
		"turn_started":
			turn = int(p.get("turn", turn))
			active_side = str(p.get("side", active_side))
			phase = PHASE_START
			exhausted_sources.clear()
			var raw: Dictionary = _raw(p)
			if not raw.is_empty():
				# The Start step's bulk reset (its `turn_reset` event is in the silent set).
				raw.hero.power_state = POWER_READY
				for token: Dictionary in raw.board:
					token.attacks_used = 0
			if active_side == SIDE_BOSS:
				steps.append(_step(AnimStep.TURN_BANNER, [], group, seq))
		"phase_changed":
			phase = str(p.get("phase", phase))
			active_side = str(p.get("side", active_side))
		"turn_ending":
			phase = PHASE_END
		"turn_ended":
			pass
		"crystal_gained":
			_raw(p).mana.max = int(p.get("mana_max", 0))
		"mana_refilled":
			_raw(p).mana.available = int(p.get("mana_available", 0))
			_raw(p).mana.max = int(p.get("mana_max", 0))
		"mana_spent":
			var mana: Dictionary = _raw(p).mana
			mana.available = int(p.get("mana_available", int(mana.available) - int(p.get("amount", 0))))
		"mana_added":
			if p.get("temporary", false) == true:
				_raw(p).mana.temporary = int(_raw(p).mana.temporary) + int(p.get("n", 0))
				_raw(p).mana.available = int(_raw(p).mana.available) + int(p.get("n", 0))
		"card_drawn", "card_added_to_hand":
			var raw: Dictionary = _raw(p)
			var id: int = int(p.get("instance_id", 0))
			(raw.deck as Dictionary).erase(id)
			if p.has("returned_entity_id"):
				_remove_token(raw, int(p.returned_entity_id))
			var card: Dictionary = {"instance_id": id}
			if str(p.get("side", "")) == SIDE_PLAYER:
				card["card_id"] = str(p.get("card_id", ""))
			(raw.hand as Array).append(card)
			steps.append(_step(AnimStep.DRAW, [id], group, seq))
		"card_burned":
			var raw: Dictionary = _raw(p)
			(raw.deck as Dictionary).erase(int(p.get("instance_id", 0)))
			if p.has("returned_entity_id"):
				_remove_token(raw, int(p.returned_entity_id))
			steps.append(_step(AnimStep.BURN, [int(p.get("instance_id", 0))], group, seq))
		"card_added_to_deck":
			_raw(p).deck[int(p.get("instance_id", 0))] = true
			steps.append(_step(AnimStep.DECK_TICK, [int(p.get("instance_id", 0))], group, seq))
		"fatigue_damage":
			_raw(p).fatigue_next = int(p.get("counter", 0)) + 1
			steps.append(_step(AnimStep.FATIGUE_LABEL, _hero_ids(_raw(p)), group, seq))
		"card_played", "spell_cast":
			# A spell may log both; the card travels once, on the event that removes it.
			var id: int = int(p.get("instance_id", 0))
			if _remove_from_hand(_raw(p), id):
				steps.append(_step(AnimStep.PLAY_CARD, [id], group, seq))
		"card_discarded":
			var id: int = int(p.get("instance_id", 0))
			_remove_from_hand(_raw(p), id)
			steps.append(_step(AnimStep.DISCARD, [id], group, seq))
		"minion_summoned":
			var board: Array = _raw(p).board
			var id: int = _entity_id_of(p)
			var token: Dictionary = {
				"entity_id": id, "card_id": str(p.get("card_id", "")),
				"attack": int(p.get("attack", 0)), "health": int(p.get("health", 0)), "max_health": int(p.get("health", 0)),
				"keywords": (p.get("keywords", []) as Array).duplicate(), "frozen": false, "silenced": false, "attacks_used": 0,
			}
			var index: int = int(p.get("position", p.get("board_index", board.size())))
			board.insert(clampi(index, 0, board.size()), token)
			steps.append(_step(AnimStep.SUMMON, [id], group, seq))
		"summon_failed":
			var ghost: AnimStep = _step(AnimStep.SUMMON_FAILED, [], group, seq)
			ghost.data = {"side": str(p.get("side", ""))}
			steps.append(ghost)
		"weapon_equipped":
			_raw(p).hero.weapon = {
				"entity_id": int(p.get("entity_id", 0)), "card_id": str(p.get("card_id", "")),
				"attack": int(p.get("attack", 0)), "durability": int(p.get("durability", 0)),
			}
			steps.append(_step(AnimStep.WEAPON_UPDATE, [int(p.get("entity_id", 0))], group, seq))
		"weapon_durability_changed":
			var weapon: Variant = _raw(p).hero.weapon
			if weapon != null:
				weapon.durability = int(p.get("durability", weapon.durability))
			steps.append(_step(AnimStep.WEAPON_UPDATE, [int(p.get("entity_id", 0))], group, seq))
		"weapon_destroyed":
			var raw: Dictionary = _raw(p)
			if raw.hero.weapon != null and int(raw.hero.weapon.entity_id) == int(p.get("entity_id", 0)):
				raw.hero.weapon = null
			steps.append(_step(AnimStep.WEAPON_SHATTER, [int(p.get("entity_id", 0))], group, seq))
		"hero_power_used":
			_raw(p).hero.power_state = POWER_USED
			steps.append(_step(AnimStep.POWER_PRESS, _hero_ids(_raw(p)), group, seq))
		"hero_power_refreshed":
			_raw(p).hero.power_state = POWER_READY
			steps.append(_step(AnimStep.POWER_RELIGHT, _hero_ids(_raw(p)), group, seq))
		"attack_declared":
			steps.append(_step(AnimStep.ATTACK_LUNGE, _ids([_attacker_of(p), _defender_of(p)]), group, seq))
		"attack_resolved":
			_count_attack(int(_attacker_of(p)))
		"attack_cancelled":
			_count_attack(int(_attacker_of(p)))
			steps.append(_step(AnimStep.ATTACK_RETURN, _ids([_attacker_of(p)]), group, seq))
		"damage_dealt":
			var target: int = int(p.get("target", 0))
			var hit: Dictionary = _character(target)
			if not hit.is_empty():
				hit.health = int(p.get("health_after", 0))
			var dealt: int = int(p.get("dealt", 0))
			if not (dealt == 0 and int(p.get("prevented", 0)) > 0):
				var pop: AnimStep = _step(AnimStep.DAMAGE_POP, [target], group, seq)
				pop.data = {"amount": dealt, "source": _copy(p.get("source"))}
				steps.append(pop)
		"divine_shield_popped":
			var shielded: Dictionary = _character(int(p.get("entity_id", 0)))
			if shielded.has("keywords"):
				(shielded.keywords as Array).erase(_KEYWORD_DIVINE_SHIELD)
			steps.append(_step(AnimStep.SHIELD_POP, [int(p.get("entity_id", 0))], group, seq))
		"healed":
			var target: int = int(p.get("target", 0))
			var amount: int = int(p.get("amount", 0))
			var healed: Dictionary = _character(target)
			if not healed.is_empty() and healed.health != null:
				healed.health = int(healed.health) + amount
			if amount != 0:
				var pop: AnimStep = _step(AnimStep.HEAL_POP, [target], group, seq)
				pop.data = {"amount": amount, "source": _copy(p.get("source"))}
				steps.append(pop)
		"armor_gained":
			_raw(p).hero.armor = int(p.get("armor", 0))
			var pop: AnimStep = _step(AnimStep.HEAL_POP, _hero_ids(_raw(p)), group, seq)
			pop.data = {"amount": int(p.get("amount", 0)), "source": null}
			steps.append(pop)
		"armor_lost":
			# No pop of its own: the `damage_dealt` that follows pops `dealt`,
			# which already includes `armor_absorbed`.
			_raw(p).hero.armor = int(p.get("armor", 0))
		"enchantment_applied", "enchantment_removed":
			_apply_enchantment(type == "enchantment_applied", p, group, seq, steps)
		"minion_modified":
			var token: Dictionary = _character(_entity_id_of(p))
			if token.has("max_health"):
				for field: String in ["attack", "health", "max_health"]:
					if p.has(field):
						token[field] = int(p[field])
				steps.append(_parallel(_step(AnimStep.STAT_RECOLOUR, [int(token.entity_id)], group, seq)))
		"silenced", "frozen", "thawed", "stealth_lost", "keyword_removed":
			var id: int = _entity_id_of(p)
			var flagged: Dictionary = _character(id)
			match type:
				"silenced":
					if flagged.has("silenced"):
						_apply_silence(flagged, p)
				"frozen", "thawed":
					if flagged.has("frozen"):
						flagged.frozen = type == "frozen"
				"stealth_lost":
					if flagged.has("keywords"):
						(flagged.keywords as Array).erase(_KEYWORD_STEALTH)
				"keyword_removed":
					if flagged.has("keywords"):
						(flagged.keywords as Array).erase(str(p.get("keyword", "")))
			steps.append(_parallel(_step(AnimStep.BADGE, [id], group, seq)))
		"auras_recomputed":
			for change: Variant in p.get("changes", []):
				_apply_aura_change(change, group, seq, steps)
		"counter_changed":
			var source: Variant = p.get("source_id")
			if not counters.has(source):
				counters[source] = {}
			counters[source][str(p.get("key", ""))] = _copy(p.get("value"))
		"minion_died":
			_apply_death(p, group, seq, cause, steps)
		"trigger_queued":
			var id: int = _entity_id_of(p)
			armed_sources[id] = true
			steps.append(_step(AnimStep.RIM_GLOW, [id], group, seq))
		"trigger_resolved":
			var id: int = _entity_id_of(p)
			armed_sources.erase(id)
			if p.get("once_per_turn", false) == true and p.get("exhausted", false) == true:
				exhausted_sources[id] = true
			steps.append(_step(AnimStep.RIM_GLOW, [id], group, seq))
		"effect_resolved":
			# card-effects Interactions: `fizzled` is null, or the reason
			# String (`condition_false`, …) — never `true` (code review
			# 2026-11-03). Any value but null (or a stray `false`) is a fizzle;
			# the reason rides on the step for display.
			var fizzled: Variant = p.get("fizzled")
			if fizzled != null and not (fizzled is bool and fizzled == false):
				var wisp: AnimStep = _step(AnimStep.FIZZLE, _ids([p.get("source_id")]), group, seq)
				wisp.data = {"reason": _copy(fizzled)}
				steps.append(wisp)
		"discover_offered", "choice_requested":
			_apply_choice_open(type == "discover_offered", p, group, seq, steps)
		"choice_made", "discover_picked":
			if pending_choice != null:
				var was_player: bool = str(pending_choice.get("side", "")) == SIDE_PLAYER
				pending_choice = null
				_choice_offered = false
				_choice_requested = false
				if was_player:
					steps.append(_step(AnimStep.OVERLAY_CLOSE, [], group, seq))
		"ai_intent_shown":
			intent = p.duplicate(true)
			steps.append(_step(AnimStep.INTENT_SHOW, [], group, seq))
		"ai_intent_committed":
			intent = p.duplicate(true)
			steps.append(_step(AnimStep.INTENT_COMMIT, [], group, seq))
		"match_ended":
			result = p.duplicate(true)
			steps.append(_step(AnimStep.END_BANNER, [], group, seq))
		"log_overflow", "resolution_overflow":
			# The fault's own `match_ended` follows and carries the banner step.
			result = {"result": RESULT_FAULT, "reason": type}
		_:
			return false
	return true


func _apply_enchantment(applied: bool, p: Dictionary, group: int, seq: int, steps: Array[AnimStep]) -> void:
	var target: Dictionary = _character(int(p.get("instance_id", 0)))
	if target.is_empty():
		return
	var direction: int = 1 if applied else -1
	var attack_delta: int = int(p.get("attack_delta", 0))
	var health_delta: int = int(p.get("health_delta", 0))
	if target.has("max_health"):
		target.attack = int(target.attack) + direction * attack_delta
		target.max_health = int(target.max_health) + direction * health_delta
		if applied:
			target.health = int(target.health) + health_delta
			if str(p.get("reason", "")) == _ENCHANT_REASON_SET_STATS:
				target.health = target.max_health
		else:
			target.health = mini(int(target.health), int(target.max_health))
		var keywords: Array = target.keywords
		for keyword: Variant in p.get("keywords_added", []):
			if applied and not keywords.has(str(keyword)):
				keywords.append(str(keyword))
			elif not applied:
				keywords.erase(str(keyword))
	elif target.health != null:
		target.health = int(target.health) + direction * health_delta
	var kind: StringName = AnimStep.STAT_RECOLOUR if attack_delta != 0 or health_delta != 0 else AnimStep.BADGE
	steps.append(_parallel(_step(kind, [int(target.entity_id)], group, seq)))


## U3 `auras_recomputed` (match-rules C15, DD-X26, DD-X29): [param change] holds
## absolute values, so its fields replace the view's and re-applying it changes
## nothing. One parallel step per entry: a recolour when a stat or cost changed,
## else a badge. A board token takes `attack`, `health`, `max_health` and
## `keywords`; a hero `health` (U1 keeps no other of them); a weapon `attack`
## and `keywords`, its durability staying with `weapon_durability_changed`; a
## player hand card `effective_cost` and `hook_delta`; the hero power entry
## `hero.power_cost` and `hero.power_hook_delta`, its step on the hero. A
## `hook_delta` absent from an entry is 0. An id in play nowhere is ignored.
func _apply_aura_change(change: Dictionary, group: int, seq: int, steps: Array[AnimStep]) -> void:
	var zone: String = str(change.get("zone", ""))
	if zone == _ZONE_HERO_POWER:
		var raw: Dictionary = _raw(change)
		if raw.is_empty():
			return
		raw.hero.power_cost = int(change.get("effective_cost", 0))
		raw.hero.power_hook_delta = int(change.get("hook_delta", 0))
		steps.append(_parallel(_step(AnimStep.STAT_RECOLOUR, _hero_ids(raw), group, seq)))
		return
	if zone == _ZONE_HAND:
		var instance_id: int = int(change.get("instance_id", 0))
		for card: Dictionary in _sides[SIDE_PLAYER].hand:
			if int(card.instance_id) == instance_id:
				card["effective_cost"] = int(change.get("effective_cost", 0))
				if change.has("hook_delta"):
					card["hook_delta"] = int(change.hook_delta)
				else:
					card.erase("hook_delta")
				steps.append(_parallel(_step(AnimStep.STAT_RECOLOUR, [instance_id], group, seq)))
		return
	var id: int = int(change.get("entity_id", 0))
	var weapon: Dictionary = _weapon(id)
	var target: Dictionary = weapon if not weapon.is_empty() else _character(id)
	if target.is_empty():
		return
	var kind: StringName = AnimStep.STAT_RECOLOUR
	if not weapon.is_empty():
		if int(weapon.attack) == int(change.get("attack", 0)):
			kind = AnimStep.BADGE
		weapon.attack = int(change.get("attack", 0))
		weapon["keywords"] = (change.get("keywords", []) as Array).duplicate()
	elif target.has("max_health"):
		var stats_same: bool = true
		for field: String in ["attack", "health", "max_health"]:
			stats_same = stats_same and int(target[field]) == int(change.get(field, 0))
			target[field] = int(change.get(field, 0))
		if stats_same:
			kind = AnimStep.BADGE
		target.keywords = (change.get("keywords", []) as Array).duplicate()
	else:
		target.health = int(change.get("health", 0))
	steps.append(_parallel(_step(kind, [id], group, seq)))


## U3 `silenced` (match-rules C13; code review 2026-11-04, MR-015 S1): Silence
## strips enchantments and keywords with no `enchantment_removed` /
## `keyword_removed` of its own, so the projection replays C13 from the
## payload: each `removed_enchantments[]` delta comes off attack and maximum
## health, every `removed_keywords[]` entry is erased, `frozen` clears, and
## health follows F6 — `damage' = max(0, damage − max(0, old_max − new_max))`,
## `health = new_max − damage'`. Received auras are never in the payload, so
## they stay. A payload without the arrays (an older fixture) only flags.
func _apply_silence(token: Dictionary, p: Dictionary) -> void:
	token.silenced = true
	token.frozen = false
	var old_max: int = int(token.max_health)
	var damage: int = old_max - int(token.health)
	for removed: Variant in p.get("removed_enchantments", []):
		token.attack = int(token.attack) - int((removed as Dictionary).get("attack_delta", 0))
		token.max_health = int(token.max_health) - int((removed as Dictionary).get("health_delta", 0))
	var keywords: Array = token.keywords
	for keyword: Variant in p.get("removed_keywords", []):
		keywords.erase(str(keyword))
	var new_max: int = int(token.max_health)
	token.health = new_max - maxi(0, damage - maxi(0, old_max - new_max))


## U3.3: a run of consecutive `minion_died` sharing a `cause_seq` is one
## `death_group` step then one `gap_close` step; later deaths of the run join
## the steps already returned (they are still queued: the run arrives in one
## synchronous burst) and return none.
func _apply_death(p: Dictionary, group: int, seq: int, cause: int, steps: Array[AnimStep]) -> void:
	var id: int = _entity_id_of(p)
	for side_name: String in [SIDE_PLAYER, SIDE_BOSS]:
		_remove_token(_sides[side_name], id)
	if _death_cause == cause and not _death_steps.is_empty():
		for step: AnimStep in _death_steps:
			step.entity_ids.append(id)
		return
	_death_cause = cause
	_death_steps = [_step(AnimStep.DEATH_GROUP, [id], group, seq), _step(AnimStep.GAP_CLOSE, [id], group, seq)]
	steps.append_array(_death_steps)


## U3 `discover_offered` + `choice_requested`: the player's options come from
## `discover_offered` (or `choice_requested` when it is first); the overlay
## step is emitted on the second of the pair, whichever order. A boss Choice
## stores `{side, kind}` only and has no step.
func _apply_choice_open(offered: bool, p: Dictionary, group: int, seq: int, steps: Array[AnimStep]) -> void:
	var owner: String = str(p.get("side", ""))
	if owner != SIDE_PLAYER:
		pending_choice = {"side": owner, "kind": str(p.get("kind", ""))}
		return
	var options: Variant = p.get("option_card_ids", p.get("option_label_keys", [])) if offered else p.get("options", [])
	if offered or pending_choice == null:
		pending_choice = {
			"side": owner, "kind": str(p.get("kind", "")), "options": _copy(options),
			"source_id": _copy(p.get("source_id")), "effect_id": str(p.get("effect_id", "")),
		}
	if offered:
		_choice_offered = true
	else:
		_choice_requested = true
	if _choice_offered and _choice_requested:
		_choice_offered = false
		_choice_requested = false
		steps.append(_step(AnimStep.OVERLAY_OPEN, [], group, seq))


# --- helpers -------------------------------------------------------------------------

func _step(kind: StringName, ids: Array[int], group: int, seq: int) -> AnimStep:
	if not _d_base.has(String(kind)):
		push_error("MatchViewState: config(\"match_ui\").d_base has no '%s'" % kind)
	return AnimStep.new(kind, ids, float(_d_base.get(String(kind), 0.0)), group, seq)


func _parallel(step: AnimStep) -> AnimStep:
	step.parallel_ok = true
	return step


func _feed(key: String, params: Dictionary, group: int) -> void:
	feed_lines.append({"key": key, "params": params, "group_id": group})
	if _feed_max > 0 and feed_lines.size() > _feed_max:
		feed_lines.pop_front()


## Feed-line params for a table event: the payload, minus what the player may
## not see (U3.2; U10 "Boss hand contents never appear until played").
func _public_params(type: String, p: Dictionary) -> Dictionary:
	var params: Dictionary = p.duplicate(true)
	if str(p.get("side", "")) == SIDE_BOSS:
		match type:
			"card_drawn", "card_added_to_hand":
				params.erase("card_id")
			"discover_offered":
				params.erase("option_card_ids")
				params.erase("option_label_keys")
			"choice_requested":
				params.erase("options")
	return params


## The raw side record named by `payload.side`, or `{}`.
func _raw(p: Dictionary) -> Dictionary:
	return _sides.get(str(p.get("side", "")), {})


## The live hero or board token with [param id], or `{}`.
func _character(id: int) -> Dictionary:
	for side_name: String in [SIDE_PLAYER, SIDE_BOSS]:
		var raw: Dictionary = _sides[side_name]
		if raw.hero.entity_id != null and int(raw.hero.entity_id) == id:
			return raw.hero
		var token: Dictionary = _token_in(raw.board, id)
		if not token.is_empty():
			return token
	return {}


## The live weapon with [param id] on either side, or `{}`.
func _weapon(id: int) -> Dictionary:
	for side_name: String in [SIDE_PLAYER, SIDE_BOSS]:
		var held: Variant = _sides[side_name].hero.weapon
		if held != null and int(held.entity_id) == id:
			return held
	return {}


static func _token_in(board: Array, id: int) -> Dictionary:
	for token: Dictionary in board:
		if int(token.entity_id) == id:
			return token
	return {}


static func _remove_token(raw: Dictionary, id: int) -> void:
	var board: Array = raw.board
	for i: int in board.size():
		if int(board[i].entity_id) == id:
			board.remove_at(i)
			return


## Removes instance [param id] from the side's hand; true when it was there.
static func _remove_from_hand(raw: Dictionary, id: int) -> bool:
	if raw.is_empty():
		return false
	var hand: Array = raw.hand
	for i: int in hand.size():
		if int(hand[i].instance_id) == id:
			hand.remove_at(i)
			return true
	return false


func _count_attack(attacker: int) -> void:
	var token: Dictionary = _character(attacker)
	if token.has("attacks_used"):
		token.attacks_used = int(token.attacks_used) + 1


## The acting entity of a payload: C15 names it `entity_id` (engine) or
## `instance_id` (catalogue rows for `minion_died`, `trigger_*`).
static func _entity_id_of(p: Dictionary) -> int:
	return int(p.get("entity_id", p.get("instance_id", 0)))


## The attacker of a payload: the engine names it `attacker`, the catalogue
## (rng-event-log §D) `attacker_id` (MUI-003 L2; the engine's spelling is C15's).
static func _attacker_of(p: Dictionary) -> Variant:
	return p.get("attacker", p.get("attacker_id", 0))


## The defender of a payload, as [method _attacker_of].
static func _defender_of(p: Dictionary) -> Variant:
	return p.get("defender", p.get("defender_id", 0))


static func _hero_ids(raw: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	if not raw.is_empty() and raw.hero.entity_id != null:
		ids.append(int(raw.hero.entity_id))
	return ids


## The ints of [param values], skipping nulls and non-numbers.
static func _ids(values: Variant) -> Array[int]:
	var ids: Array[int] = []
	if values is Array:
		for value: Variant in values:
			if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
				ids.append(int(value))
	return ids


static func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
