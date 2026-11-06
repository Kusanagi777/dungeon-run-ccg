## SPIKE — throwaway. card-effects story 001 (Pre-Production gate entry condition 6).
##
## The thinnest Effect Resolver that resolves the five hardest C11 rows of
## design/gdd/card-effects.md (rows 16, 20, 26 + 27, 33, 45) *verbatim*. It is
## not story 002's `EffectResolver`: no validator, no binding index, no hooks,
## and only the selectors, predicates and ops those rows use.
##
## It keeps ADR-0007's boundary even though it is throwaway — a spike that
## passes by cheating the boundary proves nothing about the risk:
##   - reads live state only through `engine.state()`;
##   - mutates match state only through engine primitives (`apply_damage`,
##     `apply_heal`, `summon_minion`, `add_card_to_hand`, `apply_enchantment`,
##     `discover`);
##   - emits only through `engine.emit(type, payload)`;
##   - draws only through `engine.rng_match()`;
##   - its only state is plain data in `state().effects` (EffectRuntime:
##     `once_marks`, `counters`, `per_turn`, `pending_choice`).
## One effect pass is one C10 step: nothing here calls the death check or the
## aura recompute; the engine's loop runs them after the pass (C6.0).
##
## Effects are interpreted as data on every pass (never compiled to Callables,
## ADR-0007 Alt 2). The op list runs from an explicit work list, so a
## Discover / Choose One pause stores the *remaining* work list as plain data
## (C8.1 continuation) and `resume` continues it — nested or not.
##
## Never import this file from production code (story AC-S3). Written under
## src/gameplay/effects/spike/ and moved to this test-only folder at close; the
## production resolver is story 002's, built fresh.
extends RefCounted

const SIDE_PLAYER: String = "player"
const SIDE_BOSS: String = "boss"
const KIND_HERO: String = "hero"
const KIND_MINION: String = "minion"

## Card data stand-in: `{cards: {def_id: CardDef}, collectible_pool: [def_id]}`
## (`collectible_pool` is card-database's `collectible_pool(player_hero_set)`).
var _db: Dictionary = {}
## The `card_effects` config body (DISCOVER_COUNT, DISCOVER_EXCLUDE_HAND).
var _config: Dictionary = {}
## The engine this resolver is bound to; null when unbound.
var _engine: RefCounted = null


## `db` is the card-data stand-in; `effects_config` the `card_effects` body.
func _init(db: Dictionary, effects_config: Dictionary) -> void:
	_db = db
	_config = effects_config


## ADR-0007 decision 2: the engine registers itself at start.
func bind(engine: RefCounted) -> void:
	_engine = engine


## ADR-0007 decision 2: breaks the engine <-> resolver RefCounted cycle.
func unbind() -> void:
	_engine = null


## C2 play trigger (`cast`, `hero_power`, `battlecry`): run the host's effects
## bound to `trigger` now, in `effects[]` order (C1 rule 3). `ctx` carries
## `host_id, host_kind, host_type, source_id, owner, target_id`.
## Spike limit: if an effect pauses for a choice, later play effects of the same
## host are not continued (no C11 row needs it — recorded in the spike doc).
func run_play(trigger: String, ctx: Dictionary) -> void:
	var host_id: String = String(ctx.host_id)
	var effects: Array = _effects_of(host_id)
	for i: int in range(effects.size()):
		var effect: Dictionary = effects[i]
		if String(effect.get("trigger", "")) != trigger:
			continue
		var run_ctx: Dictionary = ctx.duplicate(true)
		run_ctx["effect_id"] = _effect_id(host_id, effect, i)
		run_ctx["effect_index"] = i
		run_ctx["trigger"] = trigger
		run_ctx["snapshot"] = {}
		run_ctx["trigger_subject"] = {}
		_start_pass(effect, run_ctx)
		if _runtime().pending_choice != null:
			return


## C6.2 event trigger: who responds. Returns the queue entries for the engine to
## append to its Q (the engine owns the queue, ADR-0007 decision 1). Each entry
## is plain data and carries the C6.5 raise-time snapshot.
## `ctx`: `{candidates: [entity_id], snapshots: {str(id): entity}, subject: entity}`
## (`snapshots` for `deathrattle`, whose sources already left play).
func resolve(point: String, ctx: Dictionary) -> Array:
	var entries: Array = []
	for candidate: Variant in ctx.get("candidates", []):
		var id: int = int(candidate)
		var entity: Dictionary = ctx.get("snapshots", {}).get(str(id), {}) if point == "deathrattle" else _find(id)
		if entity.is_empty() or bool(entity.get("silenced", false)):
			continue
		var def_id: String = String(entity.get("def_id", ""))
		var effects: Array = _effects_of(def_id)
		for i: int in range(effects.size()):
			var effect: Dictionary = effects[i]
			if String(effect.get("trigger", "")) != point:
				continue
			if not _scope_matches(effect, entity, ctx):
				continue
			entries.append({
				"effect_id": _effect_id(def_id, effect, i),
				"effect_index": i,
				"host_id": def_id,
				"host_kind": "card",
				"host_type": String(_card(def_id).get("type", KIND_MINION)),
				"source_id": id,
				"owner": String(entity.controller),
				"trigger": point,
				"target_id": -1,
				"snapshot": _snapshot(entity),
				"trigger_subject": (ctx.get("subject", {}) as Dictionary).duplicate(true),
			})
	return entries


## Run one queued entry (from `resolve`) as one effect pass (C6.4).
func run_queued(entry: Dictionary) -> void:
	var effect: Dictionary = _effects_of(String(entry.host_id))[int(entry.effect_index)]
	_start_pass(effect, entry.duplicate(true))


## C8.2: the engine received `choose(option_index)` for the pending choice.
## Applies the option, then continues the same pass from the stored work list.
func resume(_choice: Dictionary, option_index: int) -> void:
	var runtime: Dictionary = _runtime()
	var cont: Dictionary = runtime.pending_choice
	runtime["pending_choice"] = null
	var ctx: Dictionary = cont.ctx
	var work: Array = cont.work
	var records: Array = cont.records
	var item: Dictionary = cont.item
	var op: Dictionary = item.op
	var result: Dictionary = {"op": String(op.op), "targets": [], "values": {"picked_index": option_index}, "outcome": "applied"}
	var side: String = String(ctx.owner)
	if String(cont.kind) == "discover":
		var card_id: String = String(cont.options[option_index])
		_engine.emit("discover_picked", {"side": side, "picked_index": option_index, "picked_card_id": card_id})
		result.values["option_card_ids"] = (cont.options as Array).duplicate()
		result.values["card_id"] = card_id
		match String(op.get("then", "add_to_hand")):
			"add_to_hand":
				if _engine.add_card_to_hand(side, card_id) < 0:
					result.outcome = "burned"
			"summon":
				if _engine.summon_minion(side, card_id, -1) < 0:
					result.outcome = "board_full"
			_:
				push_error("spike: discover then '%s' not implemented" % String(op.get("then")))
				result.outcome = "skipped"
	else:
		var picked: Dictionary = op.options[option_index]
		_engine.emit("discover_picked", {"side": side, "picked_index": option_index, "picked_label_key": String(picked.label_key)})
		result.values["picked_label_key"] = String(picked.label_key)
		_push_front(work, picked.get("ops", []), int(item.top), true)
	_record(records, item, result)
	_continue_pass(ctx, work, records)


## C7: called by the engine's C10 loop after it stripped every `is_aura`
## enchantment. Re-applies every live aura in canonical source order (player
## board left to right, then boss); each source applies one aura at most once
## per target (F2: two sources stack, one source never doubles).
func recompute_auras() -> void:
	for side: String in [SIDE_PLAYER, SIDE_BOSS]:
		for source: Dictionary in _state().players[side].board:
			if bool(source.get("silenced", false)):
				continue
			var def_id: String = String(source.def_id)
			var effects: Array = _effects_of(def_id)
			for i: int in range(effects.size()):
				var effect: Dictionary = effects[i]
				if String(effect.get("trigger", "")) != "aura":
					continue
				if String(effect.get("scope", {}).get("zone", "board")) != "board":
					continue
				var ctx: Dictionary = {
					"effect_id": _effect_id(def_id, effect, i), "host_id": def_id, "source_id": int(source.entity_id),
					"owner": String(source.controller), "target_id": -1, "snapshot": {}, "trigger_subject": {},
				}
				var targets: Array = _unique(_select(effect.get("targets", null), ctx))
				for op: Dictionary in effect.get("ops", []):
					if String(op.op) != "aura":
						continue
					for target_id: int in targets:
						_engine.apply_enchantment(target_id, {
							"source_entity_id": int(source.entity_id),
							"effect_id": String(ctx.effect_id),
							"attack_delta": _value(op.get("attack", 0), ctx),
							"health_delta": _value(op.get("health", 0), ctx),
							"keywords_added": (op.get("keywords", []) as Array).duplicate(),
							"is_aura": true,
							"expires": null,
						})


# --- One effect pass (C6.4) -------------------------------------------------

func _start_pass(effect: Dictionary, ctx: Dictionary) -> void:
	ctx["effect_targets"] = effect.get("targets", null)
	var condition: Dictionary = effect.get("condition", {})
	if not condition.is_empty() and not _eval_condition(condition, ctx):
		_emit_resolved(ctx, [], "condition_false")
		return
	var ops: Array = effect.get("ops", [])
	var records: Array = []
	var work: Array = []
	for i: int in range(ops.size()):
		records.append({"op": String(ops[i].op), "targets": [], "values": {}, "outcome": ""})
		work.append({"op": (ops[i] as Dictionary).duplicate(true), "top": i, "nested": false})
	_continue_pass(ctx, work, records)


func _continue_pass(ctx: Dictionary, work: Array, records: Array) -> void:
	while not work.is_empty():
		var item: Dictionary = work.pop_front()
		var op: Dictionary = item.op
		match String(op.op):
			"conditional":
				var taken: bool = _eval_condition(op["if"], ctx)
				var branch: Array = op.get("then", []) if taken else op.get("else", [])
				var outcome: String = "applied" if not branch.is_empty() else "skipped"
				_record(records, item, {"op": "conditional", "targets": [], "values": {"branch": "then" if taken else "else"}, "outcome": outcome})
				_push_front(work, branch, int(item.top), true)
			"repeat":
				var times: int = _value(op.get("times", 1), ctx)
				for _k: int in range(times):
					_push_front(work, op.get("ops", []), int(item.top), true)
				_record(records, item, {"op": "repeat", "targets": [], "values": {"times": times}, "outcome": "applied"})
			"discover":
				var options: Array = _discover_options(op, ctx)
				if options.is_empty():
					_record(records, item, {"op": "discover", "targets": [], "values": {"option_card_ids": []}, "outcome": "empty_pool"})
					continue
				_pause(ctx, work, records, item, "discover", options)
				return
			"choose_one":
				var labels: Array = []
				for option: Dictionary in op.get("options", []):
					labels.append(String(option.label_key))
				_pause(ctx, work, records, item, "choose_one", labels)
				return
			_:
				_record(records, item, _run_leaf(op, ctx))
	_emit_resolved(ctx, records, null)


## C8.1: store the continuation as plain data, then ask the engine to enter
## `Choice` (it emits `choice_requested`), then emit `discover_offered`.
func _pause(ctx: Dictionary, work: Array, records: Array, item: Dictionary, kind: String, options: Array) -> void:
	_runtime()["pending_choice"] = {
		"effect_id": String(ctx.effect_id), "source_id": int(ctx.source_id), "kind": kind,
		"options": options.duplicate(), "item": item, "work": work, "records": records, "ctx": ctx,
	}
	var side: String = String(ctx.owner)
	_engine.discover(side, {"kind": kind, "options": options.duplicate(), "source_id": int(ctx.source_id), "effect_id": String(ctx.effect_id)})
	var payload: Dictionary = {"side": side, "source_id": int(ctx.source_id), "effect_id": String(ctx.effect_id), "kind": kind}
	payload["option_card_ids" if kind == "discover" else "option_label_keys"] = options.duplicate()
	_engine.emit("discover_offered", payload)


## F4: candidates = distinct(filter(base(pool))) minus the source's def, in
## id-ascending order; `min(count, |candidates|)` draws of `randi_range`.
func _discover_options(op: Dictionary, ctx: Dictionary) -> Array:
	var base: Array = []
	match String(op.get("pool", "collectible")):
		"collectible":
			base = _db.get("collectible_pool", [])
		"list":
			for id: Variant in op.get("list", []):
				if _db.cards.has(String(id)):
					base.append(String(id))
		_:
			push_error("spike: discover pool '%s' not implemented" % String(op.get("pool")))
	var filter: Dictionary = op.get("filter", {})
	var exclude: Dictionary = {String(ctx.host_id): true}
	var candidates: Array = []
	for id: Variant in base:
		var def_id: String = String(id)
		if exclude.has(def_id):
			continue
		exclude[def_id] = true
		if _card_matches(_card(def_id), filter):
			candidates.append(def_id)
	candidates.sort()
	var count: int = mini(_value(op.get("count", _config.get("DISCOVER_COUNT", 0)), ctx), candidates.size())
	var rng: RefCounted = _engine.rng_match()
	var options: Array = []
	for _i: int in range(count):
		var j: int = rng.randi_range(0, candidates.size() - 1)
		options.append(candidates[j])
		candidates.remove_at(j)
	return options


func _run_leaf(op: Dictionary, ctx: Dictionary) -> Dictionary:
	var name: String = String(op.op)
	var result: Dictionary = {"op": name, "targets": [], "values": {}, "outcome": "applied"}
	var source_id: int = int(ctx.source_id)
	var owner: String = String(ctx.owner)
	match name:
		"damage":
			var amount: int = maxi(0, _value(op.get("amount", 0), ctx))
			var mode: Variant = op.get("spell_damage", "auto")
			var scales: bool = (mode is bool and mode) or (String(mode) == "auto" and String(ctx.get("host_type", "")) == "spell")
			var requested: int = amount + (_spell_damage(owner) if scales else 0)
			result.values = {"amount": amount, "requested": requested}
			_note_ref_origin(op.get("amount", 0), ctx, result.values)
			var targets: Array = _select(_targets_of(op, ctx), ctx)
			if targets.is_empty():
				result.outcome = "no_target"
			for target_id: int in targets:
				_engine.apply_damage(target_id, requested, source_id)
				result.targets.append(target_id)
		"heal":
			var amount: int = maxi(0, _value(op.get("amount", 0), ctx))
			result.values = {"amount": amount}
			var targets: Array = _select(_targets_of(op, ctx), ctx)
			if targets.is_empty():
				result.outcome = "no_target"
			for target_id: int in targets:
				_engine.apply_heal(target_id, amount, source_id)
				result.targets.append(target_id)
		"summon":
			var card_id: String = String(op.card_id)
			var count: int = _value(op.get("count", 1), ctx)
			var side: String = owner if String(op.get("side", "owner")) == "owner" else _other(owner)
			var position: int = _summon_position(String(op.get("position", "")), ctx)
			var made: int = 0
			for _i: int in range(count):
				var id: int = _engine.summon_minion(side, card_id, position)
				if id >= 0:
					made += 1
					result.targets.append(id)
					if position >= 0:
						position += 1
			result.values = {"card_id": card_id, "count": count}
			if made == 0:
				result.outcome = "board_full"
			elif made < count:
				result.outcome = "partial"
		"add_to_hand":
			var card_id: String = String(op.card_id)
			var side: String = owner if String(op.get("side", "owner")) == "owner" else _other(owner)
			result.values = {"card_id": card_id}
			for _i: int in range(_value(op.get("count", 1), ctx)):
				if _engine.add_card_to_hand(side, card_id) < 0:
					result.outcome = "burned"
		"add_counter":
			# C5: resolver-owned EffectRuntime data; one `counter_changed` per change.
			var key: String = String(op.key)
			var counters: Dictionary = _runtime().counters
			var bucket: String = str(source_id)
			if not counters.has(bucket):
				counters[bucket] = {}
			var value: int = int(counters[bucket].get(key, 0)) + _value(op.get("amount", 1), ctx)
			counters[bucket][key] = value
			_engine.emit("counter_changed", {"source_id": source_id, "key": key, "value": value})
			result.values = {"key": key, "value": value}
		_:
			push_error("spike: op '%s' not implemented" % name)
			result.outcome = "skipped"
	return result


func _emit_resolved(ctx: Dictionary, records: Array, fizzled: Variant) -> void:
	_engine.emit("effect_resolved", {
		"effect_id": String(ctx.effect_id), "host_id": String(ctx.host_id), "host_kind": String(ctx.get("host_kind", "card")),
		"source_id": int(ctx.source_id), "owner": String(ctx.owner), "trigger": String(ctx.trigger), "depth": 0,
		"fizzled": fizzled, "ops": records.duplicate(true),
	})


## A top-level op writes its own record; a nested op (inside conditional,
## repeat, choose_one) appends to its top-level record's `values.inner`.
func _record(records: Array, item: Dictionary, result: Dictionary) -> void:
	var record: Dictionary = records[int(item.top)]
	if bool(item.nested):
		if not record.values.has("inner"):
			record.values["inner"] = []
		record.values.inner.append(result)
		return
	record["targets"] = result.targets
	record["values"].merge(result.values, true)
	record["outcome"] = result.outcome


func _push_front(work: Array, ops: Array, top: int, nested: bool) -> void:
	for i: int in range(ops.size() - 1, -1, -1):
		work.push_front({"op": (ops[i] as Dictionary).duplicate(true), "top": top, "nested": nested})


# --- Selectors, filters, conditions, values (C3, C4) ------------------------

func _targets_of(op: Dictionary, ctx: Dictionary) -> Variant:
	return op.get("targets", ctx.get("effect_targets", null))


## C3: evaluated when the op runs, against the live board, canonical order.
## Selectors never yield a dying entity; `chosen` and `self` are explicit
## references and may.
func _select(selector: Variant, ctx: Dictionary) -> Array:
	var out: Array = []
	if selector == null:
		return out
	var name: String = String(selector) if selector is String else String(selector.selector)
	var filter: Dictionary = {} if selector is String else selector.get("filter", {})
	var owner: String = String(ctx.owner)
	match name:
		"chosen":
			var target: Dictionary = _find(int(ctx.get("target_id", -1)))
			if not target.is_empty() and _matches(target, filter, ctx):
				out.append(int(target.entity_id))
		"self":
			if _in_play(int(ctx.source_id)):
				out.append(int(ctx.source_id))
		"owner_hero":
			out.append(int(_state().players[owner].hero.entity_id))
		"enemy_hero":
			out.append(int(_state().players[_other(owner)].hero.entity_id))
		"all_friendly_minions", "all_enemy_minions", "all_minions":
			var sides: Array = [owner] if name == "all_friendly_minions" else ([_other(owner)] if name == "all_enemy_minions" else [SIDE_PLAYER, SIDE_BOSS])
			for side: String in sides:
				for minion: Dictionary in _state().players[side].board:
					if not _is_dying(minion) and _matches(minion, filter, ctx):
						out.append(int(minion.entity_id))
		"adjacent":
			var of: String = String(selector.get("of", "self")) if selector is Dictionary else "self"
			var anchor: int = int(ctx.source_id) if of == "self" else int(ctx.get("target_id", -1))
			for side: String in [SIDE_PLAYER, SIDE_BOSS]:
				var board: Array = _state().players[side].board
				for i: int in range(board.size()):
					if int(board[i].entity_id) != anchor:
						continue
					for j: int in [i - 1, i + 1]:
						if j >= 0 and j < board.size() and not _is_dying(board[j]) and _matches(board[j], filter, ctx):
							out.append(int(board[j].entity_id))
		_:
			push_error("spike: selector '%s' not implemented" % name)
	return out


func _matches(entity: Dictionary, filter: Dictionary, ctx: Dictionary) -> bool:
	for key: Variant in filter:
		var want: Variant = filter[key]
		match String(key):
			"kind":
				if String(want) != "any" and String(entity.get("kind", "")) != String(want):
					return false
			"side":
				var friendly: bool = String(entity.controller) == String(ctx.owner)
				if (String(want) == "friendly" and not friendly) or (String(want) == "enemy" and friendly):
					return false
			"not_self":
				if bool(want) and int(entity.entity_id) == int(ctx.source_id):
					return false
			"is_dying":
				if _is_dying(entity) != bool(want):
					return false
			"has_divine_shield":
				if (entity.keywords as Array).has("divine_shield") != bool(want):
					return false
			_:
				push_error("spike: filter predicate '%s' not implemented" % String(key))
				return false
	return true


func _card_matches(def: Dictionary, filter: Dictionary) -> bool:
	if bool(def.get("token", false)) and not bool(filter.get("token", false)):
		return false
	for key: Variant in filter:
		match String(key):
			"type", "set", "rarity":
				if String(def.get(String(key), "")) != String(filter[key]):
					return false
			"token":
				pass
			_:
				push_error("spike: pool predicate '%s' not implemented" % String(key))
				return false
	return true


func _eval_condition(condition: Dictionary, ctx: Dictionary) -> bool:
	if condition.is_empty():
		return true
	if condition.has("test"):
		var entity: Dictionary = _ref_entity(String(condition.test[0]), ctx)
		return not entity.is_empty() and _matches(entity, condition.test[1], ctx)
	if condition.has("exists"):
		return not _select(condition.exists, ctx).is_empty()
	if condition.has("not"):
		return not _eval_condition(condition["not"], ctx)
	push_error("spike: condition %s not implemented" % str(condition))
	return false


func _value(expr: Variant, ctx: Dictionary) -> int:
	if expr is int or expr is float:
		return int(expr)
	if expr is Dictionary and expr.has("ref"):
		return _ref(String(expr.ref), ctx)
	push_error("spike: value expression %s not implemented" % str(expr))
	return 0


## C4 refs: `source.*` and `counter.*` read live values while the source is the
## same entity in play, the raise-time snapshot afterwards (C6.5).
func _ref(path: String, ctx: Dictionary) -> int:
	var parts: PackedStringArray = path.split(".", true, 1)
	var head: String = parts[0]
	var field: String = parts[1] if parts.size() > 1 else ""
	match head:
		"counter":
			var source_id: int = int(ctx.source_id)
			if _in_play(source_id):
				return int(_runtime().counters.get(str(source_id), {}).get(field, 0))
			return int(ctx.get("snapshot", {}).get("counters", {}).get(field, 0))
		"source", "target", "trigger_subject":
			var entity: Dictionary = _ref_entity(head, ctx)
			match field:
				"attack":
					return _attack(entity)
				"health":
					return _health(entity)
	push_error("spike: ref path '%s' not implemented" % path)
	return 0


func _note_ref_origin(expr: Variant, ctx: Dictionary, values: Dictionary) -> void:
	if expr is Dictionary and expr.has("ref") and String(expr.ref).begins_with("counter."):
		values["read_from"] = "live" if _in_play(int(ctx.source_id)) else "snapshot"


func _ref_entity(name: String, ctx: Dictionary) -> Dictionary:
	match name:
		"target":
			return _find(int(ctx.get("target_id", -1)))
		"source":
			var live: Dictionary = _find(int(ctx.source_id))
			return live if not live.is_empty() else ctx.get("snapshot", {})
		"trigger_subject":
			return ctx.get("trigger_subject", {})
	push_error("spike: reference '%s' not implemented" % name)
	return {}


func _scope_matches(effect: Dictionary, observer: Dictionary, ctx: Dictionary) -> bool:
	var scope: Dictionary = effect.get("scope", {})
	if String(effect.trigger) != "on_minion_died":
		return true
	var subject: Dictionary = ctx.get("subject", {})
	var friendly: bool = String(subject.get("controller", "")) == String(observer.controller)
	match String(scope.get("who", "friendly_minion")):
		"any_minion":
			return true
		"friendly_minion":
			return friendly
		"enemy_minion":
			return not friendly
	return false


func _summon_position(position: String, ctx: Dictionary) -> int:
	var source_in_play: bool = _in_play(int(ctx.source_id)) and String(_find(int(ctx.source_id)).get("kind", "")) == KIND_MINION
	var resolved: String = position
	if resolved.is_empty():
		resolved = "source_slot" if String(ctx.trigger) == "deathrattle" else "right_of_source"
	match resolved:
		"source_slot":
			return int(ctx.get("snapshot", {}).get("board_index", -1)) if String(ctx.trigger) == "deathrattle" else -1
		"right_of_source":
			return _board_index(int(ctx.source_id)) + 1 if source_in_play else -1
	return -1


# --- Read-only state access ---------------------------------------------------

func _state() -> Dictionary:
	return _engine.state()


func _runtime() -> Dictionary:
	return _engine.state().effects


func _card(def_id: String) -> Dictionary:
	return _db.cards.get(def_id, {})


func _effects_of(def_id: String) -> Array:
	return _card(def_id).get("effects", [])


func _effect_id(host_id: String, effect: Dictionary, index: int) -> String:
	return String(effect.get("id", "%s.%d" % [host_id, index]))


func _find(entity_id: int) -> Dictionary:
	for side: String in [SIDE_PLAYER, SIDE_BOSS]:
		var player: Dictionary = _state().players[side]
		if int(player.hero.entity_id) == entity_id:
			return player.hero
		for minion: Dictionary in player.board:
			if int(minion.entity_id) == entity_id:
				return minion
	return {}


func _in_play(entity_id: int) -> bool:
	return not _find(entity_id).is_empty()


func _board_index(entity_id: int) -> int:
	for side: String in [SIDE_PLAYER, SIDE_BOSS]:
		var board: Array = _state().players[side].board
		for i: int in range(board.size()):
			if int(board[i].entity_id) == entity_id:
				return i
	return -1


## C6.5 raise-time snapshot, counters included.
func _snapshot(entity: Dictionary) -> Dictionary:
	var id: int = int(entity.entity_id)
	return {
		"source_id": id, "def_id": String(entity.get("def_id", "")), "owner": String(entity.controller),
		"controller": String(entity.controller), "kind": String(entity.get("kind", KIND_MINION)),
		"entity_id": id, "attack": _attack(entity), "health": _health(entity),
		"max_health": _max_health(entity), "base_attack": int(entity.base_attack), "base_health": int(entity.base_health),
		"damage_taken": int(entity.damage_taken), "enchantments": (entity.enchantments as Array).duplicate(true),
		"board_index": int(entity.get("board_index", _board_index(id))),
		"keywords": (entity.keywords as Array).duplicate(),
		"counters": (_runtime().counters.get(str(id), {}) as Dictionary).duplicate(true),
	}


func _is_dying(entity: Dictionary) -> bool:
	return _health(entity) <= 0 or bool(entity.get("pending_destroy", false))


func _max_health(entity: Dictionary) -> int:
	var total: int = int(entity.base_health)
	for enchantment: Dictionary in entity.enchantments:
		total += int(enchantment.health_delta)
	return total


func _health(entity: Dictionary) -> int:
	return _max_health(entity) - int(entity.damage_taken)


func _attack(entity: Dictionary) -> int:
	var total: int = int(entity.base_attack)
	for enchantment: Dictionary in entity.enchantments:
		total += int(enchantment.attack_delta)
	return maxi(0, total)


## F1 / match-rules F7: Σ spell_damage over the owner's board.
func _spell_damage(owner: String) -> int:
	var total: int = 0
	for minion: Dictionary in _state().players[owner].board:
		total += int(_card(String(minion.get("def_id", ""))).get("spell_damage", 0))
	return total


func _other(side: String) -> String:
	return SIDE_BOSS if side == SIDE_PLAYER else SIDE_PLAYER


func _unique(ids: Array) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for id: Variant in ids:
		if not seen.has(id):
			seen[id] = true
			out.append(id)
	return out
