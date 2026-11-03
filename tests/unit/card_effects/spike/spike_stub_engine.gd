## SPIKE — throwaway. card-effects story 001 (Pre-Production gate entry condition 6).
##
## A stub of match-rules' `RulesEngine`, exposing only what the five spike rows
## need: `state()`, `emit()`, `rng_match()`, `discover()`, the primitives
## `apply_damage`, `apply_heal`, `summon_minion`, `add_card_to_hand`,
## `apply_enchantment`, `destroy`, two commands (`cast_spell`,
## `use_hero_power`) plus `choose`, and the C10 loop (death check ->
## `recompute_auras()` -> queue pop) that owns time and order (ADR-0007
## decision 1). match-rules stories 001-002 had not merged when the spike ran,
## so this stands in for the engine; it is the *engine* side of the boundary
## and writes `MatchState` itself, which the resolver never does.
##
## State is the C1 Dictionary shape `tests/helpers/match_factory.gd` builds;
## randomness and the log are the injected `match_<floor>` stream and the log
## double (duck-typed so this file names no test class). Gameplay limits come
## from the injected `rules_config` (BOARD_SIZE, HAND_SIZE, RESOLUTION_STEP_CAP).
##
## Never import this file from production code (story AC-S3). Written under
## src/gameplay/effects/spike/ and moved to this test-only folder at close.
extends RefCounted

const SIDE_PLAYER: String = "player"
const SIDE_BOSS: String = "boss"
const PHASE_MAIN: String = "main"
const PHASE_CHOICE: String = "choice"
const KIND_HERO: String = "hero"
const KIND_MINION: String = "minion"

## The C10 units in the order they ran: `{kind: pass|death_check|recompute_auras, ...}`.
## Lets a test assert C6.0 (no death check between the ops of one pass).
var trace: Array = []

var _state: Dictionary = {}
var _db: Dictionary = {}
var _rules: Dictionary = {}
var _rng: RefCounted = null
var _log: RefCounted = null
var _resolver: RefCounted = null
var _queue: Array = []
var _cause_seq: int = 0


## `state` is a C1 MatchState Dictionary; `db` the card-data stand-in
## (`{cards, collectible_pool}`); `rules_config` the match_rules limits; `rng`
## the `match_<floor>` stream; `log` the event log; `resolver` the spike
## resolver, bound here (ADR-0007 decision 2).
func _init(state: Dictionary, db: Dictionary, rules_config: Dictionary, rng: RefCounted, log: RefCounted, resolver: RefCounted) -> void:
	_state = state
	_db = db
	_rules = rules_config
	_rng = rng
	_log = log
	_resolver = resolver
	_state["phase"] = PHASE_MAIN
	_state["pending_choice"] = null
	# EffectRuntime: plain data in MatchState.effects (ADR-0007, card-effects C6.8).
	_state["effects"] = {"once_marks": {}, "counters": {}, "per_turn": {}, "pending_choice": null}
	_resolver.bind(self)


## `match_ended` stand-in: unbinds the resolver (breaks the RefCounted cycle).
func end_match() -> void:
	if _resolver != null:
		_resolver.unbind()
	_resolver = null


# --- Resolver-facing surface (ADR-0007 Key Interfaces) -------------------------

## Live MatchState read (resolver only).
func state() -> Dictionary:
	return _state


## Append one event with the current `cause_seq`; returns its `seq`.
func emit(type: String, payload: Dictionary) -> int:
	return int(_log.append(type, payload.duplicate(true), _cause_seq))


## The injected `match_<floor>` stream.
func rng_match() -> RefCounted:
	return _rng


## Current phase (`main` | `choice`).
func phase() -> String:
	return String(_state.phase)


# --- Commands -------------------------------------------------------------------

## Cast spell `def_id` for `side`: `card_played`, `spell_cast`, then the host's
## `cast` effects as the action's first step, then the C10 loop.
func cast_spell(side: String, def_id: String, target_id: int = -1) -> Dictionary:
	if phase() == PHASE_CHOICE:
		return _reject("CHOICE_PENDING")
	var instance_id: int = _alloc_id()
	_cause_seq = 0
	emit("card_played", {"side": side, "instance_id": instance_id, "card_id": def_id, "target_id": target_id, "board_index": -1})
	_cause_seq = emit("spell_cast", {"side": side, "instance_id": instance_id, "card_id": def_id, "target_id": target_id})
	trace.append({"kind": "pass", "trigger": "cast", "host_id": def_id})
	_resolver.run_play("cast", {"host_id": def_id, "host_kind": "card", "host_type": "spell", "source_id": instance_id, "owner": side, "target_id": target_id})
	_run_loop()
	return {"accepted": true, "rejection": null}


## Use hero power `power_def_id` for `side` (source = that side's hero slot).
func use_hero_power(side: String, power_def_id: String, target_id: int = -1) -> Dictionary:
	if phase() == PHASE_CHOICE:
		return _reject("CHOICE_PENDING")
	var hero_id: int = int(_state.players[side].hero.entity_id)
	_cause_seq = 0
	_cause_seq = emit("hero_power_used", {"side": side, "power_id": power_def_id, "target_id": target_id})
	trace.append({"kind": "pass", "trigger": "hero_power", "host_id": power_def_id})
	_resolver.run_play("hero_power", {"host_id": power_def_id, "host_kind": "hero_power", "host_type": "hero_power", "source_id": hero_id, "owner": side, "target_id": target_id})
	_run_loop()
	return {"accepted": true, "rejection": null}


## match-rules `choose`: leave `Choice`, resume the resolver's continuation,
## then let the C10 loop run as usual (card-effects C8.2).
func choose(option_index: int) -> Dictionary:
	if phase() != PHASE_CHOICE:
		return _reject("WRONG_PHASE")
	var pending: Dictionary = _state.pending_choice
	if option_index < 0 or option_index >= (pending.options as Array).size():
		return _reject("INVALID_CHOICE")
	_cause_seq = emit("choice_made", {"side": String(pending.side), "option_index": option_index})
	_state["pending_choice"] = null
	_state["phase"] = PHASE_MAIN
	_resolver.resume(pending, option_index)
	_run_loop()
	return {"accepted": true, "rejection": null}


## Run the C10 loop after a fixture mutation (e.g. `destroy`) — a test seam.
func settle() -> void:
	_run_loop()


# --- Primitives (match-rules Interactions) ----------------------------------------

## F2 subset: Divine Shield, armour, `damage_taken`. Returns the amount dealt.
func apply_damage(target_id: int, requested: int, source_id: int) -> int:
	var target: Dictionary = _find(target_id)
	if target.is_empty():
		return 0
	var keywords: Array = target["keywords"]
	if requested > 0 and keywords.has("divine_shield"):
		keywords.erase("divine_shield")
		emit("divine_shield_popped", {"source": source_id, "target": target_id})
		return 0
	var absorbed: int = 0
	if String(target.kind) == KIND_HERO:
		absorbed = mini(int(target.armor), requested)
		target["armor"] = int(target.armor) - absorbed
	target["damage_taken"] = int(target.damage_taken) + requested - absorbed
	emit("damage_dealt", {
		"source": source_id, "target": target_id, "requested": requested, "prevented": 0,
		"armor_absorbed": absorbed, "dealt": requested, "health_after": _health(target),
	})
	return requested


## C9 heal: `restored = min(amount, damage_taken)`; a full-health target still emits.
func apply_heal(target_id: int, amount: int, source_id: int) -> int:
	var target: Dictionary = _find(target_id)
	if target.is_empty():
		return 0
	var restored: int = mini(amount, int(target.damage_taken))
	target["damage_taken"] = int(target.damage_taken) - restored
	emit("healed", {"source": source_id, "target": target_id, "amount": restored, "health_after": _health(target)})
	return restored


## C10 summon: insert at `position` (-1 or past the end = rightmost); full
## board -> `summon_failed`. Returns the new entity id or -1.
func summon_minion(side: String, def_id: String, position: int) -> int:
	var board: Array = _state.players[side].board
	if board.size() >= int(_rules.BOARD_SIZE):
		emit("summon_failed", {"side": side, "card_id": def_id, "reason": "board_full"})
		return -1
	var def: Dictionary = _db.cards[def_id]
	var id: int = _alloc_id()
	var minion: Dictionary = {
		"entity_id": id, "controller": side, "kind": KIND_MINION, "def_id": def_id,
		"base_attack": int(def.attack), "base_health": int(def.health), "enchantments": [],
		"damage_taken": 0, "keywords": (def.get("keywords", []) as Array).duplicate(), "attacks_used": 0,
		"frozen": false, "frozen_on_turn": 0, "silenced": false, "summoning_sick": true,
		"summoned_on_turn": int(_state.turn),
	}
	var index: int = board.size() if position < 0 or position > board.size() else position
	board.insert(index, minion)
	emit("minion_summoned", {
		"side": side, "instance_id": id, "card_id": def_id, "board_index": index,
		"attack": int(def.attack), "health": int(def.health), "keywords": minion.keywords.duplicate(),
	})
	return id


## Add a fresh card instance of `def_id` to `side`'s hand; full hand -> burn.
## Event name `card_added_to_hand` is PROVISIONAL: match-rules C15 names no
## event for this primitive (recorded in the spike doc).
func add_card_to_hand(side: String, def_id: String) -> int:
	var hand: Array = _state.players[side].hand
	var id: int = _alloc_id()
	if hand.size() >= int(_rules.HAND_SIZE):
		emit("card_burned", {"side": side, "instance_id": id, "card_id": def_id})
		return -1
	hand.append({"instance_id": id, "def_id": def_id, "zone": "hand", "cost_modifiers": []})
	emit("card_added_to_hand", {"side": side, "instance_id": id, "card_id": def_id, "hand_size": hand.size()})
	return id


## Append an enchantment. Aura enchantments are silent here: the recompute
## emits one `auras_recomputed` with the net changes (match-rules C10).
func apply_enchantment(target_id: int, enchantment: Dictionary) -> void:
	var target: Dictionary = _find(target_id)
	if target.is_empty():
		return
	(target["enchantments"] as Array).append(enchantment.duplicate(true))
	if not bool(enchantment.get("is_aura", false)):
		emit("enchantment_applied", {"instance_id": target_id, "attack": _attack(target), "health": _health(target), "max_health": _max_health(target), "reason": "effect"})


## `destroy`: sets `pending_destroy`; the next death check removes it.
func destroy(target_id: int) -> void:
	var target: Dictionary = _find(target_id)
	if not target.is_empty():
		target["pending_destroy"] = true


## Enter `Choice` with one pending request (match-rules' single slot).
func discover(side: String, request: Dictionary) -> void:
	_state["pending_choice"] = {
		"side": side, "kind": String(request.kind), "options": (request.options as Array).duplicate(),
		"source_id": int(request.source_id), "effect_id": String(request.effect_id),
	}
	_state["phase"] = PHASE_CHOICE
	emit("choice_requested", {"side": side, "kind": String(request.kind), "option_count": (request.options as Array).size()})


# --- C10 loop (engine-owned) ----------------------------------------------------

func _run_loop() -> void:
	var steps: int = 0
	while true:
		if phase() == PHASE_CHOICE:
			return
		var dead: Array = _death_check()
		_recompute_auras()
		if dead.is_empty() and _queue.is_empty():
			break
		if _queue.is_empty():
			continue
		steps += 1
		if steps > int(_rules.RESOLUTION_STEP_CAP):
			emit("resolution_overflow", {"steps": steps})
			return
		var entry: Dictionary = _queue.pop_front()
		_cause_seq = emit("trigger_resolved", {"instance_id": int(entry.source_id), "card_id": String(entry.host_id), "effect_id": String(entry.effect_id), "trigger": String(entry.trigger)})
		trace.append({"kind": "pass", "trigger": String(entry.trigger), "host_id": String(entry.host_id)})
		_resolver.run_queued(entry)


## match-rules C10 death check: every minion with health <= 0 or
## `pending_destroy` leaves play in one step (DD-M11 order), then Deathrattles
## are queued, then `on_minion_died` observers still in play.
func _death_check() -> Array:
	var dead: Array = []
	var snapshots: Dictionary = {}
	for side: String in [SIDE_PLAYER, SIDE_BOSS]:
		var board: Array = _state.players[side].board
		for i: int in range(board.size()):
			var minion: Dictionary = board[i]
			if _health(minion) <= 0 or bool(minion.get("pending_destroy", false)):
				dead.append(int(minion.entity_id))
				var snapshot: Dictionary = minion.duplicate(true)
				snapshot["board_index"] = i
				snapshots[str(int(minion.entity_id))] = snapshot
	if dead.is_empty():
		return dead
	trace.append({"kind": "death_check", "dead": dead.duplicate()})
	for id: int in dead:
		var snapshot: Dictionary = snapshots[str(id)]
		var board: Array = _state.players[String(snapshot.controller)].board
		board.erase(_find(id))
		emit("minion_died", {"instance_id": id, "card_id": String(snapshot.def_id), "side": String(snapshot.controller), "board_index": int(snapshot.board_index)})
	# Deathrattles first — the resolver supplies the effects and the snapshots.
	_enqueue(_resolver.resolve("deathrattle", {"candidates": dead, "snapshots": snapshots}))
	for id: int in dead:
		_enqueue(_resolver.resolve("on_minion_died", {"candidates": _observer_candidates(), "subject": snapshots[str(id)]}))
	return dead


func _recompute_auras() -> void:
	var before: Dictionary = _stat_map()
	for character: Dictionary in _all_characters():
		character["enchantments"] = (character.enchantments as Array).filter(_is_not_aura)
	_resolver.recompute_auras()
	var after: Dictionary = _stat_map()
	var changes: Array = []
	for key: Variant in after:
		if not before.has(key) or before[key] != after[key]:
			changes.append({"instance_id": int(key), "attack": after[key][0], "health": after[key][1]})
	trace.append({"kind": "recompute_auras"})
	if not changes.is_empty():
		emit("auras_recomputed", {"changes": changes})


func _enqueue(entries: Array) -> void:
	for entry: Dictionary in entries:
		_queue.append(entry)
		emit("trigger_queued", {"instance_id": int(entry.source_id), "card_id": String(entry.host_id), "effect_id": String(entry.effect_id), "trigger": String(entry.trigger)})


## Observer candidate order (card-effects C6.3): player board L->R, then boss.
func _observer_candidates() -> Array:
	var ids: Array = []
	for side: String in [SIDE_PLAYER, SIDE_BOSS]:
		for minion: Dictionary in _state.players[side].board:
			ids.append(int(minion.entity_id))
	return ids


# --- Helpers ----------------------------------------------------------------------

func _reject(code: String) -> Dictionary:
	emit("command_rejected", {"code": code, "diagnostic": true})
	return {"accepted": false, "rejection": {"code": code, "detail": ""}}


func _alloc_id() -> int:
	var id: int = int(_state.next_entity_id)
	_state["next_entity_id"] = id + 1
	return id


func _all_characters() -> Array:
	var out: Array = []
	for side: String in [SIDE_PLAYER, SIDE_BOSS]:
		out.append(_state.players[side].hero)
		out.append_array(_state.players[side].board)
	return out


func _find(entity_id: int) -> Dictionary:
	for character: Dictionary in _all_characters():
		if int(character.entity_id) == entity_id:
			return character
	return {}


func _stat_map() -> Dictionary:
	var out: Dictionary = {}
	for character: Dictionary in _all_characters():
		out[str(int(character.entity_id))] = [_attack(character), _health(character)]
	return out


static func _is_not_aura(enchantment: Variant) -> bool:
	return not bool((enchantment as Dictionary).get("is_aura", false))


func _max_health(character: Dictionary) -> int:
	var total: int = int(character.base_health)
	for enchantment: Dictionary in character.enchantments:
		total += int(enchantment.health_delta)
	return total


func _health(character: Dictionary) -> int:
	return _max_health(character) - int(character.damage_taken)


func _attack(character: Dictionary) -> int:
	var total: int = int(character.base_attack)
	for enchantment: Dictionary in character.enchantments:
		total += int(enchantment.attack_delta)
	return maxi(0, total)
