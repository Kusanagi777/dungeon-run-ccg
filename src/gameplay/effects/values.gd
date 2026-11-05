## C4 value expressions, references and conditions of one effect pass
## (design/gdd/card-effects.md C4, C6.5, C6.8; ADR-0007 Decisions 4–5).
##
## Static and read-only like [EffectSelectors]: every function reads the pass
## context `run` — `{resolver, owner, source_id, target_id, trigger_subject,
## trigger_source, amount, value, snapshot}`, `resolver` the bound
## [EffectResolver] — and the live state, and writes nothing. It never draws:
## `{count: selector}` and `{exists: selector}` read the selector's
## candidate pool ([method EffectSelectors.pool]), so a random selector in a
## value or a condition counts `min(n, |pool|)` without a stream draw.
##
## - [method eval]: `int | {ref} | {count} | {add} | {sub} | {mul} | {min} |
##   {max} | {clamp}` → int (JSON numbers are floats; anything else is 0 —
##   the validator rejects it at load, `E_FX_REF` / `E_FX_REF_PATH`).
## - [method holds]: `cmp`, `exists`, `test`, `holding`, `is_owner_turn`,
##   `all`, `any`, `not`; absent or `{}` is true.
## [codeblock]
## var amount: int = EffectValues.eval({"add": [2, {"ref": "owner.hand_size"}]}, run)
## if EffectValues.holds({"cmp": [{"ref": "owner.hand_size"}, ">=", 5]}, run): …
## [/codeblock]
class_name EffectValues
extends RefCounted

## The entity reference roots of a ref path and of `test` (C4).
const ENTITY_ROOTS: Array[String] = ["source", "target", "trigger_subject", "trigger_source"]
## The side reference roots of a ref path (C4).
const SIDE_ROOTS: Array[String] = ["owner", "opponent"]
## The per-turn tallies C4 names, kept in `EffectRuntime.per_turn[side]`.
const TALLIES: Array[String] = ["cards_played_this_turn", "minions_died_this_turn", "spells_cast_this_turn"]
## A pass context keys its snapshot of `trigger_subject` / `trigger_source` by the
## root plus this (C3; the resolver's queue entry carries them).
const SNAPSHOT_SUFFIX: String = "_snapshot"
## `effect_resolved.ops[i].values.read_from` (Edge Cases row 45).
const READ_LIVE: String = "live"
const READ_SNAPSHOT: String = "snapshot"


## The int value of [param expr] in pass context [param run] (see the class
## description). Example: `EffectValues.eval({"ref": "target.cost"}, run)`.
static func eval(expr: Variant, run: Dictionary) -> int:
	if typeof(expr) == TYPE_INT or typeof(expr) == TYPE_FLOAT:
		return int(expr)
	if not expr is Dictionary:
		return 0
	var e: Dictionary = expr
	if e.has("ref"):
		return ref(str(e.ref), run)
	if e.has("count"):
		var resolver: EffectResolver = run.resolver
		return EffectSelectors.pick_count(e.count, EffectSelectors.pool(resolver, e.count, run).size())
	var args: Array = []
	for key: String in ["add", "sub", "mul", "min", "max", "clamp"]:
		if e.get(key) is Array:
			for part: Variant in e[key]:
				args.append(eval(part, run))
			match key:
				"add":
					var total: int = 0
					for v: int in args:
						total += v
					return total
				"sub":
					return int(args[0]) - int(args[1]) if args.size() == 2 else 0
				"mul":
					return int(args[0]) * int(args[1]) if args.size() == 2 else 0
				"min":
					return args.min() if not args.is_empty() else 0
				"max":
					return args.max() if not args.is_empty() else 0
				"clamp":
					return clampi(int(args[0]), int(args[1]), int(args[2])) if args.size() == 3 else 0
	return 0


## The C4 reference [param path] (closed set; the validator rejected any
## other at load, so an unknown path asserts in a debug build and reads 0).
## `source.*` / `counter.*` read live while the source is in play, else the
## raise-time snapshot `run.snapshot` ([method reads_snapshot]; a late write to
## the live bucket of a departed source never reaches it, Edge Cases row 45);
## `target` reads the entity in play — a dying one included — else 0;
## `trigger_*` the same, else their raise-time snapshot (C3) when the queue entry
## kept one. Example: `EffectValues.ref("owner.hand_size", run)`.
static func ref(path: String, run: Dictionary) -> int:
	var resolver: EffectResolver = run.resolver
	var engine: RulesEngine = resolver.bound_engine()
	var state: MatchState = engine.state()
	var dot: int = path.find(".")
	var root: String = path.substr(0, dot) if dot >= 0 else path
	var field: String = path.substr(dot + 1) if dot >= 0 else ""
	if ENTITY_ROOTS.has(root):
		return _entity_stat(resolver, entity(root, run), field)
	if SIDE_ROOTS.has(root):
		var owner: String = str(run.owner)
		return _side_stat(engine, state, owner if root == "owner" else EffectSelectors.other_side(owner), field)
	match path:
		"context.amount":
			return _int(run.get("amount"))
		"context.value":
			return _int(run.get("value"))
		"match.turn":
			return int(state.turn)
	if root == "counter":
		if reads_snapshot(run):
			return _int((run.snapshot.counters as Dictionary).get(field))
		return EffectRuntime.counter(state.effects, run.source_id, field)
	assert(false, "EffectValues.ref: unknown path '%s' (E_FX_REF_PATH at load)" % path)
	return 0


## The record entity reference [param root] (`source`, `target`,
## `trigger_subject`, `trigger_source`) names: the entity in play (a dying
## one included — C3 references), else a character view of its raise-time
## snapshot ([method _snapshot_view]): `run.snapshot` for a `source` that is no
## longer the same `entity_id` in play (C6.5: the body it transformed into is not
## the source of a queued pass), `run.<root>_snapshot` for a departed
## `trigger_subject` / `trigger_source` (C3), else `{}`.
static func entity(root: String, run: Dictionary) -> Dictionary:
	if root == "source" and reads_snapshot(run):
		return _snapshot_view(run.snapshot)
	var resolver: EffectResolver = run.resolver
	var state: MatchState = resolver.bound_engine().state()
	var id: Variant = run.get({"source": "source_id", "target": "target_id"}.get(root, root))
	if typeof(id) != TYPE_INT and typeof(id) != TYPE_FLOAT:
		return {}
	var found: Dictionary = EffectSelectors.find(state, int(id))
	if found.is_empty():
		var kept: Variant = run.get(root + SNAPSHOT_SUFFIX)
		if kept is Dictionary and not (kept as Dictionary).is_empty():
			return _snapshot_view(kept)
	return found


## The C6.5 [param snapshot] in a Character record's shape, so stat refs and
## `test` filters read a departed source the way they read a live one:
## `base_attack` / `base_health` hold the snapshot's derived values with no
## enchantments, and `damage_taken` is `max_health − health` (C4 allows
## `source.damage_taken`; C6.5 has no such field). A field C6.5 does not keep
## (`silenced`, `frozen`, …) reads as its default.
static func _snapshot_view(snapshot: Dictionary) -> Dictionary:
	var max_health: int = _int(snapshot.get("max_health"))
	return {
		"entity_id": int(snapshot.source_id),
		"def_id": str(snapshot.def_id),
		"controller": str(snapshot.owner),
		"kind": MatchRecords.KIND_MINION if int(snapshot.board_index) >= 0 else "",
		"base_attack": _int(snapshot.get("attack")),
		"base_health": max_health,
		"damage_taken": max_health - _int(snapshot.get("health")),
		"enchantments": [],
		"keywords": snapshot.keywords,
	}


## The C6.5 raise-time snapshot of the source [param record] (a live minion or
## weapon, or a death record), `{source_id, def_id, owner, attack, health,
## max_health, board_index, keywords, counters}` and nothing more: plain value
## copies, so it survives the source and rides in the queue entry. `board_index`
## is the slot it stood in (−1 for a weapon); `keywords` holds the printed and
## the enchantment-granted ones; `counters` is the live bucket now.
## Example: `EffectValues.source_snapshot(resolver, minion, 12, "war_scout", "player")`.
static func source_snapshot(resolver: EffectResolver, record: Dictionary, source_id: int, def_id: String, owner: String) -> Dictionary:
	var state: MatchState = resolver.bound_engine().state()
	var keywords: Array = []
	keywords.append_array(record.get("keywords", []))
	for enchantment: Dictionary in record.get("enchantments", []):
		for keyword: String in enchantment.keywords_added:
			if not keywords.has(keyword):
				keywords.append(keyword)
	return {
		"source_id": source_id,
		"def_id": def_id,
		"owner": owner,
		"attack": _entity_stat(resolver, record, "attack"),
		"health": _entity_stat(resolver, record, "health"),
		"max_health": _entity_stat(resolver, record, "max_health"),
		"board_index": int(record.get("position", (state.players[owner].board as Array).find(record))),
		"keywords": keywords,
		"counters": EffectRuntime.counters_of(state.effects, source_id),
	}


## True when pass [param run] reads `source.*` / `counter.*` from its raise-time
## snapshot: it has one and the entity snapshotted is no longer in play (C4,
## C6.5). That is the snapshot's own id, not `run.source_id`: a self-transform
## rebinds the pass's `self` to the new body, which is another `entity_id`. A play
## pass has no snapshot: its counters are always live, its source being a spell in
## `resolving` included (row 46); nor has a treasure or passive, always live (C9).
## Example: `if EffectValues.reads_snapshot(run): …`.
static func reads_snapshot(run: Dictionary) -> bool:
	var snapshot: Variant = run.get("snapshot")
	if not snapshot is Dictionary or (snapshot as Dictionary).is_empty():
		return false
	var resolver: EffectResolver = run.resolver
	var raised: int = int((snapshot as Dictionary).get("source_id", EffectSelectors.run_source(run)))
	return EffectSelectors.find(resolver.bound_engine().state(), raised).is_empty()


## `live` or `snapshot` when the value expression [param expr] holds a
## `source.*` or `counter.*` ref, else "": the `values.read_from` of an op that
## read one (Edge Cases: the late-counter case is legible from the log).
## Example: `EffectValues.read_origin({"ref": "counter.seen"}, run)`.
static func read_origin(expr: Variant, run: Dictionary) -> String:
	if not _reads_source(expr):
		return ""
	return READ_SNAPSHOT if reads_snapshot(run) else READ_LIVE


static func _reads_source(expr: Variant) -> bool:
	if expr is Array:
		for part: Variant in expr:
			if _reads_source(part):
				return true
	elif expr is Dictionary:
		var ref_path: String = str((expr as Dictionary).get("ref", ""))
		if ref_path.begins_with("source.") or ref_path.begins_with("counter."):
			return true
		return _reads_source((expr as Dictionary).values())
	return false


## The C4 condition [param condition] in pass context [param run] (see the
## class description); absent or `{}` is true.
## Example: `EffectValues.holds({"not": {"is_owner_turn": true}}, run)`.
static func holds(condition: Variant, run: Dictionary) -> bool:
	if not condition is Dictionary or (condition as Dictionary).is_empty():
		return true
	var c: Dictionary = condition
	var resolver: EffectResolver = run.resolver
	if c.has("all"):
		for part: Variant in c.all:
			if not holds(part, run):
				return false
		return true
	if c.has("any"):
		for part: Variant in c.any:
			if holds(part, run):
				return true
		return false
	if c.has("not"):
		return not holds(c.get("not"), run)
	if c.has("is_owner_turn"):
		return (String(resolver.bound_engine().active_side()) == str(run.owner)) == bool(c.is_owner_turn)
	if c.get("cmp") is Array and (c.cmp as Array).size() == 3:
		return _cmp(eval(c.cmp[0], run), str(c.cmp[1]), eval(c.cmp[2], run))
	if c.has("exists"):
		# A reference selector (`owner_weapon`, `self`, …) has no pool: it
		# exists when it names something in play (row 8 `{exists:
		# owner_weapon}`; story 011). References draw nothing.
		if EffectSelectors.REFERENCE_SELECTORS.has(EffectSelectors.selector_name(c.exists)):
			return not EffectSelectors.entities(resolver.bound_engine().state(), c.exists, run).is_empty()
		return not EffectSelectors.pool(resolver, c.exists, run).is_empty()
	if c.get("test") is Array and (c.test as Array).size() == 2:
		var record: Dictionary = entity(str(c.test[0]), run)
		var filter: Variant = c.test[1]
		return not record.is_empty() and filter is Dictionary and EffectSelectors.matches(resolver, record, filter, str(run.owner), EffectSelectors.run_source(run), run)
	if c.get("holding") is Dictionary:
		return not EffectSelectors.hand_cards(resolver, str(run.owner), c.holding, run).is_empty()
	return false


static func _cmp(a: int, op: String, b: int) -> bool:
	match op:
		"==":
			return a == b
		"!=":
			return a != b
		"<":
			return a < b
		"<=":
			return a <= b
		">":
			return a > b
		">=":
			return a >= b
	return false


## `<entity>.attack | health | max_health | damage_taken | cost` (C4); `cost`
## is the definition's. 0 for an empty record.
static func _entity_stat(resolver: EffectResolver, record: Dictionary, field: String) -> int:
	if record.is_empty():
		return 0
	var engine: RulesEngine = resolver.bound_engine()
	match field:
		"attack":
			return engine.attack(record) if record.has("base_attack") else _weapon_attack(record)
		"health":
			return engine.health(record) if record.has("base_health") else _int(record.get("health"))
		"max_health":
			return engine.max_health(record) if record.has("base_health") else _int(record.get("max_health"))
		"damage_taken":
			return _int(record.get("damage_taken"))
		"cost":
			return _int(resolver.definition(str(record.get("def_id", ""))).get("cost"))
	assert(false, "EffectValues: unknown entity field '%s'" % field)
	return 0


## `owner.* | opponent.*` (C4) for [param side].
static func _side_stat(engine: RulesEngine, state: MatchState, side: String, field: String) -> int:
	var player: Dictionary = state.players[side]
	if TALLIES.has(field):
		return EffectRuntime.tally(state.effects, side, field)
	match field:
		"mana_current", "mana_max", "fatigue_counter", "turns_taken":
			return _int(player.get(field))
		"hand_size":
			return (player.hand as Array).size()
		"deck_size":
			return (player.deck as Array).size()
		"board_size":
			return (player.board as Array).size()
		"armor":
			return _int(player.hero.armor) if player.hero != null else 0
		"hero_health":
			return engine.health(player.hero) if player.hero != null else 0
		"weapon_attack":
			if player.weapon == null:
				return 0
			return _weapon_attack(player.weapon)
		"weapon_durability":
			return _int(player.weapon.durability) if player.weapon != null else 0
	assert(false, "EffectValues: unknown side field '%s'" % field)
	return 0


## A weapon's Attack with its enchantments (card-effects story 011: Whetstone).
static func _weapon_attack(weapon: Dictionary) -> int:
	var total: int = _int(weapon.get("attack"))
	for enchantment: Variant in weapon.get("enchantments", []):
		total += _int((enchantment as Dictionary).get("attack_delta"))
	return maxi(0, total)


static func _int(value: Variant) -> int:
	return int(value) if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT else 0
