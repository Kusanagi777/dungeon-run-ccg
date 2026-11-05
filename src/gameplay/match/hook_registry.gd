## The owner-scoped hook registry of one match (design/gdd/match-rules.md
## Interactions — hook points table and the fold rule, C1 `hooks`;
## design/gdd/treasures.md T2–T3, F5; ADR-0005 Decision rules 1–8).
##
## A plain `RefCounted` that lives on `MatchState.hooks`. It stores, per hook
## point, the `HookEntry` Dictionaries
## `{host_kind, host_id, side, effect_id, effect, state}` in installation order
## and nothing else: no log, no engine, no `MatchState`, no Node, no autoload,
## no reference to itself in any entry (rule 6). It evaluates nothing: the
## resolver registers two evaluator Callables with [method set_evaluators] at
## `bind`, and the registry calls them per entry.
##
## - **Order** is installation order only: no priority, no sort (rule 2).
## - **Value points fold**: entry *n*'s output is entry *n + 1*'s input; the
##   fold neither clamps nor allocates — the engine clamps once after it
##   (rule 4).
## - **`side`** is passed through on every call; the resolver evaluates each
##   entry's `scope` relative to `entry.side` (rule 3).
## - **`copy()`** is by value with the evaluators unset (rule 7).
## - **Entries are deep read-only** from installation on (rule 8: the effect is
##   frozen DSL, the state blob read-only): every nested Dictionary and Array
##   of an entry is `make_read_only()`, so neither [method entries] nor an
##   evaluator can change the registry through an entry. [method copy]
##   re-applies it, because `duplicate(true)` returns writable containers.
##
## [codeblock]
## var hooks := HookRegistry.new()
## hooks.install(installer)                                   # false on a duplicate host_id
## hooks.set_evaluators(resolver.apply_value_hook, resolver.run_hook_effect)
## var cost: int = clampi(hooks.fold(&"modify_cost", &"player", base_cost, {"card": ci}), 0, 1 << 30)
## hooks.run_triggers(&"on_turn_start", &"player", {})
## [/codeblock]
class_name HookRegistry
extends RefCounted

## Trigger points (match-rules hook table): each entry runs as its own step.
const TRIGGER_POINTS: Array[StringName] = [
	&"on_match_start", &"on_turn_start", &"on_turn_end", &"on_card_played",
	&"on_minion_summoned", &"on_hero_damaged", &"on_draw",
]
## The DSL triggers whose hook point has another name (card-effects C2, hook
## column). `on_damage_taken` is not here: it binds only under a hero scope
## ([method hook_point]). Every other hook-bound trigger is spelled as its point.
const DSL_HOOK_POINTS: Dictionary[String, StringName] = {
	"turn_start": &"on_turn_start",
	"turn_end": &"on_turn_end",
	"on_summon": &"on_minion_summoned",
}
## The DSL trigger bound to `on_hero_damaged` under the hero scope (C2).
const TRIGGER_DAMAGE_TAKEN: String = "on_damage_taken"
## The `who` value that is C2's "hero scope only": any other can name a minion,
## so it is a hero-slot observer (C9).
const SCOPE_OWNER_HERO: String = "owner_hero"
## Value points (match-rules hook table): entries fold an `int`.
const VALUE_POINTS: Array[StringName] = [
	&"modify_cost", &"modify_damage", &"modify_heal",
	&"modify_starting_hand_size", &"modify_max_attacks",
]
## Gate points: a reserved kind (AND, short-circuit); none in v1 (rule 1).
const GATE_POINTS: Array[StringName] = []
## The keys of every `HookEntry` — exactly these (rule 6).
const ENTRY_FIELDS: Array[String] = ["host_kind", "host_id", "side", "effect_id", "effect", "state"]
## Debug-build bound on installed entries: treasures F5,
## `(MAX_TREASURES_HELD + 1) × MAX_EFFECTS_PER_TREASURE = 4 × 3`. A guardrail
## on the fold budget, asserted in debug only — never a gameplay rule.
const DEBUG_MAX_ENTRIES: int = 12

const _NO_ENTRIES: Array[Dictionary] = []

var _entries: Dictionary[StringName, Array] = {}
var _hosts: Array[Dictionary] = []
var _fold_entry: Callable = Callable()
var _run_entry: Callable = Callable()


## An empty registry with one entry list per trigger, value and gate point.
func _init() -> void:
	for point: StringName in TRIGGER_POINTS + VALUE_POINTS + GATE_POINTS:
		_entries[point] = [] as Array[Dictionary]


## The hook point card-effects C2 binds [param effect] to on a treasure or
## passive host, or `&""` when it has none. This reads the binding table only:
## evaluating an entry's `scope` stays the resolver's.
## Example: `HookRegistry.hook_point({"trigger": "turn_end"}) == &"on_turn_end"`.
static func hook_point(effect: Dictionary) -> StringName:
	var trigger: String = str(effect.get("trigger", ""))
	if trigger == TRIGGER_DAMAGE_TAKEN:
		var scope: Variant = effect.get("scope")
		var who: String = str((scope as Dictionary).get("who", "")) if scope is Dictionary else ""
		return &"on_hero_damaged" if who == SCOPE_OWNER_HERO else &""
	var point: StringName = DSL_HOOK_POINTS.get(trigger, StringName(trigger))
	return point if TRIGGER_POINTS.has(point) or VALUE_POINTS.has(point) else &""


## Installs [param installer]: one `HookEntry` per effect in its `effects[]`,
## in array order, appended to the list of its [method hook_point] (2026-11-04,
## card-effects story 015: `turn_start` keys on `on_turn_start`, not on the raw
## trigger). `effect_id` is the effect's `id`, defaulting to `<host_id>.<index>`
## (card-effects C1). An effect with no hook point (a hook-less event trigger
## such as `on_minion_died`, or an `aura`) is not a hook: it stays with the
## resolver's hero-slot hosts (ADR-0005 rule 9) and installs nothing here.
## The host itself is recorded for [method hosts] either way.
## Returns `false`, and installs nothing, when the `host_id` is already
## installed; the engine logs `hook_install_skipped` (the registry has no log).
## [codeblock]
## assert(hooks.install(signet))
## assert(not hooks.install(signet))   # duplicate host_id
## [/codeblock]
func install(installer: HookInstaller) -> bool:
	for host: Dictionary in _hosts:
		if host.host_id == installer.host_id:
			return false
	_hosts.append({
		"host_kind": installer.host_kind,
		"host_id": installer.host_id,
		"side": installer.side,
		"state": installer.state.duplicate(true),
	})
	for index: int in installer.effects.size():
		var effect: Dictionary = installer.effects[index]
		var point: StringName = hook_point(effect)
		if not _entries.has(point):
			continue
		_entries[point].append(_frozen({
			"host_kind": installer.host_kind,
			"host_id": installer.host_id,
			"side": installer.side,
			"effect_id": str(effect.get("id", "%s.%d" % [installer.host_id, index])),
			"effect": effect.duplicate(true),
			"state": installer.state.duplicate(true),
		}))
	assert(entry_count() <= DEBUG_MAX_ENTRIES, "HookRegistry holds %d entries (treasures F5 bound %d)" % [entry_count(), DEBUG_MAX_ENTRIES])
	return true


## Registers the evaluators (ADR-0007: the resolver's bound methods
## `apply_value_hook(entry, side, value, ctx) -> int` and
## `run_hook_effect(entry, side, ctx) -> void`). Each takes everything it needs
## as arguments — lambdas capture locals by value. Pass empty `Callable()`s to
## clear them (`EffectResolver.unbind`).
func set_evaluators(fold_entry: Callable, run_entry: Callable) -> void:
	_fold_entry = fold_entry
	_run_entry = run_entry


## The entries on [param point], in installation order, as a read-only array
## of deep read-only entries (an empty one for an unknown point). A write
## through the view — `view[0].effect.ops[0].set("value", 9)` — fails (returns
## `false`, logs "read-only state") and leaves the registry unchanged.
func entries(point: StringName) -> Array:
	var view: Array = (_entries.get(point, _NO_ENTRIES) as Array).duplicate()
	view.make_read_only()
	return view


## Folds [param value] through the entries on value point [param point]:
## `value = fold_entry.call(entry, side, value, ctx)` per entry, in
## installation order, with the same [param side] and the same [param ctx]
## object every call. No clamp (the caller clamps once after the fold) and no
## allocation. Returns [param value] unchanged when the point has no entries
## or no evaluator is set (e.g. on a fresh [method copy]).
## [codeblock]
## var n: int = hooks.fold(&"modify_max_attacks", &"player", 1, {"who": hero})
## var atks: int = clampi(n, 0, engine.rule("max_attacks_cap"))
## [/codeblock]
func fold(point: StringName, side: StringName, value: int, ctx: Dictionary) -> int:
	if not _fold_entry.is_valid():
		return value
	for entry: Dictionary in _entries.get(point, _NO_ENTRIES):
		value = _fold_entry.call(entry, side, value, ctx)
	return value


## Runs the entries on trigger point [param point] in installation order:
## `run_entry.call(entry, side, ctx)` each, back to back — the engine's form
## for a hook point reached inside a primitive (`on_draw`, `on_hero_damaged`,
## `on_minion_summoned`), which belongs to the current step. Runs nothing when
## no evaluator is set.
func run_triggers(point: StringName, side: StringName, ctx: Dictionary) -> void:
	if not _run_entry.is_valid():
		return
	for entry: Dictionary in _entries.get(point, _NO_ENTRIES):
		_run_entry.call(entry, side, ctx)


## Runs the one entry at [param index] (installation order) on trigger point
## [param point]: `run_entry.call(entry, side, ctx)`. The engine's form at a
## step boundary (C3 step 4, C4 Start 4 / End 3, C6 `on_card_played`): it runs
## each entry as its own step and its C10 loop after it (ADR-0005 rule 4;
## match-rules story 009). An index outside the list, or no evaluator, runs
## nothing.
## [codeblock]
## for i in hooks.entries(&"on_turn_start").size():
##     engine_step(hooks.run_trigger_entry.bind(&"on_turn_start", i, &"player", {}))
## [/codeblock]
func run_trigger_entry(point: StringName, index: int, side: StringName, ctx: Dictionary) -> void:
	var list: Array = _entries.get(point, _NO_ENTRIES)
	if not _run_entry.is_valid() or index < 0 or index >= list.size():
		return
	_run_entry.call(list[index], side, ctx)


## Gate check (reserved kind: AND over a gate point's entries, short-circuit,
## `true` when there are none). v1 has no gate points ([constant GATE_POINTS]
## is empty), so this is `true` for every point; adding one is a match-rules
## hook-table change plus its evaluator here (ADR-0005 rule 1).
func gate(point: StringName, _side: StringName, _ctx: Dictionary) -> bool:
	assert(not GATE_POINTS.has(point), "gate point '%s' has no evaluator in v1" % point)
	return true


## The installed hosts in installation order, as value copies
## `[{host_kind, host_id, side, state}]` — the input of
## `Treasures.collect_state` (ADR-0005 rule 8).
func hosts() -> Array[Dictionary]:
	return _hosts.duplicate(true)


## A by-value copy: every entry and host `duplicate(true)`, evaluators unset
## (the clone's resolver registers its own at `bind` — ADR-0005 rule 7,
## ADR-0007 Decision 3). The copied entries are made deep read-only again.
func copy() -> HookRegistry:
	var out: HookRegistry = HookRegistry.new()
	for point: StringName in _entries:
		var list: Array[Dictionary] = []
		for entry: Dictionary in _entries[point]:
			list.append(_frozen(entry.duplicate(true)))
		out._entries[point] = list
	out._hosts = _hosts.duplicate(true)
	return out


## The number of installed entries across all points (≤ [constant DEBUG_MAX_ENTRIES]).
func entry_count() -> int:
	var total: int = 0
	for point: StringName in _entries:
		total += (_entries[point] as Array).size()
	return total


## [param value] with every nested Dictionary and Array made read-only,
## innermost first (`make_read_only()` is shallow on 4.7.2, observed
## 2026-11-03). Returns [param value].
static func _frozen(value: Variant) -> Variant:
	if value is Dictionary:
		for key: Variant in value:
			_frozen(value[key])
		(value as Dictionary).make_read_only()
	elif value is Array:
		for item: Variant in value:
			_frozen(item)
		(value as Array).make_read_only()
	return value
