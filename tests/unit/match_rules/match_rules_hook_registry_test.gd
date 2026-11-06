## Unit tests for HookRegistry / HookInstaller (story match-rules/story-002;
## design/gdd/match-rules.md Interactions — hook table and fold rule;
## ADR-0005 Decision rules 1–7).
##
## No resolver exists yet: the evaluators are scripted Callables built here.
## A scripted value effect carries its op in `effect.ops[0]` as
## `{mode: delta | set | mul, value: int}` — the treasures F2 modes — and the
## scripted evaluator applies it; it records every call in a shared Array
## (lambdas capture locals by value, so state lives in a reference type).
## The fold numbers below are the acceptance criteria's own examples.
extends GdUnitTestSuite

const SIDE_PLAYER: String = MatchFactory.SIDE_PLAYER
const SIDE_BOSS: String = MatchFactory.SIDE_BOSS
## Fields an entry must never carry (ADR-0005 rules 2 and 6).
const FORBIDDEN_ENTRY_FIELDS: Array[String] = ["priority", "weight", "order", "is_enabled", "duration_turns", "stacks"]
## The match-rules hook table, as the GDD lists it.
const HOOK_TABLE_TRIGGERS: Array[StringName] = [
	&"on_match_start", &"on_turn_start", &"on_turn_end", &"on_card_played",
	&"on_minion_summoned", &"on_hero_damaged", &"on_draw",
]
const HOOK_TABLE_VALUES: Array[StringName] = [
	&"modify_cost", &"modify_damage", &"modify_heal", &"modify_starting_hand_size", &"modify_max_attacks",
]


# --- helpers -----------------------------------------------------------------

## The AC fixture: t_a, t_b (two modify_cost effects each, player), boss_p
## (one on_turn_start, one modify_cost, boss), in MatchConfig order.
func _ac_installers() -> Array[HookInstaller]:
	var config: Dictionary = MatchFactory.make_match_config()
	config.player.hook_installers = [
		MatchFactory.make_hook_installer("t_a", SIDE_PLAYER, [&"modify_cost", &"modify_cost"], {"charges": 1}),
		MatchFactory.make_hook_installer("t_b", SIDE_PLAYER, [&"modify_cost", &"modify_cost"]),
	]
	config.boss.hook_installers = [
		MatchFactory.make_hook_installer("boss_p", SIDE_BOSS, [&"on_turn_start", &"modify_cost"]),
	]
	var ordered: Array[HookInstaller] = []
	ordered.assign(config.player.hook_installers + config.boss.hook_installers)
	return ordered


func _registry_from(installers: Array[HookInstaller]) -> HookRegistry:
	var hooks: HookRegistry = HookRegistry.new()
	for installer: HookInstaller in installers:
		assert_bool(hooks.install(installer)).is_true()
	return hooks


## One host whose effects are value hooks on `point`, one per op.
func _value_installer(host_id: String, side: String, point: StringName, ops: Array) -> HookInstaller:
	var effects: Array[Dictionary] = []
	for i: int in ops.size():
		effects.append({"id": "%s.%d" % [host_id, i], "trigger": str(point), "scope": {}, "condition": {}, "ops": [ops[i]], "once_per_turn": false})
	return HookInstaller.new(HookInstaller.HOST_KIND_TREASURE, host_id, StringName(side), effects)


func _op(mode: String, value: int) -> Dictionary:
	return {"mode": mode, "value": value}


## Scripted `apply_value_hook`: applies `effect.ops[0]` and records the call.
func _scripted_fold(calls: Array) -> Callable:
	return func(entry: Dictionary, side: StringName, value: int, ctx: Dictionary) -> int:
		calls.append({"effect_id": entry.effect_id, "side": side, "input": value, "ctx": ctx})
		var op: Dictionary = entry.effect.ops[0]
		match str(op.mode):
			"delta":
				return value + int(op.value)
			"set":
				return int(op.value)
			"mul":
				return value * int(op.value)
		return value


## Scripted `run_hook_effect`: records the call.
func _scripted_run(calls: Array) -> Callable:
	return func(entry: Dictionary, side: StringName, ctx: Dictionary) -> void:
		calls.append({"effect_id": entry.effect_id, "side": side, "ctx": ctx})


func _effect_ids(entries: Array) -> Array:
	var ids: Array = []
	for entry: Dictionary in entries:
		ids.append(entry.effect_id)
	return ids


func _all_points() -> Array[StringName]:
	var points: Array[StringName] = []
	points.append_array(HookRegistry.TRIGGER_POINTS)
	points.append_array(HookRegistry.VALUE_POINTS)
	points.append_array(HookRegistry.GATE_POINTS)
	return points


func _snapshot(hooks: HookRegistry) -> Dictionary:
	var out: Dictionary = {"hosts": hooks.hosts(), "count": hooks.entry_count()}
	for point: StringName in _all_points():
		out[point] = hooks.entries(point)
	return out


## Every Dictionary or Array reachable from `value` (itself included) that is
## not read-only, as path strings.
func _writable_containers(value: Variant, path: String = "<root>", out: Array = []) -> Array:
	if value is Dictionary:
		if not (value as Dictionary).is_read_only():
			out.append(path)
		for key: Variant in value:
			_writable_containers(value[key], "%s.%s" % [path, str(key)], out)
	elif value is Array:
		if not (value as Array).is_read_only():
			out.append(path)
		for i: int in (value as Array).size():
			_writable_containers(value[i], "%s[%d]" % [path, i], out)
	return out


func _collect_objects(value: Variant, out: Array) -> Array:
	if value is Object:
		out.append(value)
	elif value is Dictionary:
		for key: Variant in value:
			_collect_objects(value[key], out)
	elif value is Array:
		for item: Variant in value:
			_collect_objects(item, out)
	return out


# --- catalogue ----------------------------------------------------------------

func test_catalogue_equals_the_match_rules_hook_table() -> void:
	# Assert (ADR-0005 rule 1: 7 trigger points, 5 value points, no gate points)
	assert_array(HookRegistry.TRIGGER_POINTS).is_equal(HOOK_TABLE_TRIGGERS)
	assert_array(HookRegistry.VALUE_POINTS).is_equal(HOOK_TABLE_VALUES)
	assert_array(HookRegistry.GATE_POINTS).is_empty()
	assert_array(HookRegistry.ENTRY_FIELDS).contains_exactly_in_any_order(["host_kind", "host_id", "side", "effect_id", "effect", "state"])


# --- installation order -------------------------------------------------------

func test_install_order_is_player_installers_then_boss_in_effect_order() -> void:
	# Arrange / Act
	var hooks: HookRegistry = _registry_from(_ac_installers())

	# Assert — t_a[0], t_a[1], t_b[0], t_b[1], boss_p[1] on modify_cost
	var cost_entries: Array = hooks.entries(&"modify_cost")
	assert_array(_effect_ids(cost_entries)).is_equal(["t_a.0", "t_a.1", "t_b.0", "t_b.1", "boss_p.1"])
	assert_array(_effect_ids(hooks.entries(&"on_turn_start"))).is_equal(["boss_p.0"])
	assert_int(hooks.entry_count()).is_equal(6)
	for entry: Dictionary in cost_entries + hooks.entries(&"on_turn_start"):
		assert_array(entry.keys()).contains_exactly_in_any_order(HookRegistry.ENTRY_FIELDS)
		for field: String in FORBIDDEN_ENTRY_FIELDS:
			assert_bool(entry.has(field)).override_failure_message("entry has '%s'" % field).is_false()
	for i: int in 4:
		assert_bool(cost_entries[i].side == SIDE_PLAYER).is_true()
		assert_bool(cost_entries[i].host_kind == HookInstaller.HOST_KIND_TREASURE).is_true()
	assert_bool(cost_entries[4].side == SIDE_BOSS).is_true()
	assert_bool(cost_entries[4].host_kind == HookInstaller.HOST_KIND_PASSIVE).is_true()
	assert_dict(cost_entries[0].state).is_equal({"charges": 1})


func test_hosts_lists_each_installer_with_its_state_in_order() -> void:
	# Arrange / Act
	var hosts: Array[Dictionary] = _registry_from(_ac_installers()).hosts()

	# Assert
	assert_int(hosts.size()).is_equal(3)
	var ids: Array = []
	for host: Dictionary in hosts:
		ids.append(host.host_id)
		assert_array(host.keys()).contains_exactly_in_any_order(["host_kind", "host_id", "side", "state"])
	assert_array(ids).is_equal(["t_a", "t_b", "boss_p"])
	assert_dict(hosts[0].state).is_equal({"charges": 1})
	assert_dict(hosts[2].state).is_empty()


func test_installer_with_zero_effects_records_its_host_and_no_entries() -> void:
	# Arrange
	var hooks: HookRegistry = HookRegistry.new()

	# Act
	var installed: bool = hooks.install(MatchFactory.make_hook_installer("t_empty", SIDE_PLAYER, []))

	# Assert
	assert_bool(installed).is_true()
	assert_int(hooks.entry_count()).is_zero()
	assert_int(hooks.hosts().size()).is_equal(1)


func test_hookless_event_trigger_effect_installs_no_entry() -> void:
	# Arrange — Grave Tithe-style on_minion_died: a hero-slot observer, not a hook (rule 9)
	var hooks: HookRegistry = HookRegistry.new()

	# Act
	hooks.install(MatchFactory.make_hook_installer("t_tithe", SIDE_PLAYER, [&"on_minion_died", &"modify_heal"]))

	# Assert — only the modify_heal effect is a hook; its id keeps its array index
	assert_int(hooks.entry_count()).is_equal(1)
	assert_array(_effect_ids(hooks.entries(&"modify_heal"))).is_equal(["t_tithe.1"])
	assert_array(hooks.entries(&"on_minion_died")).is_empty()


func test_effect_without_id_defaults_to_host_id_and_index() -> void:
	# Arrange (card-effects C1: id defaults to <host_id>.<index>)
	var hooks: HookRegistry = HookRegistry.new()
	var installer: HookInstaller = HookInstaller.new(HookInstaller.HOST_KIND_TREASURE, "t_noid", &"player",
		[{"trigger": "modify_damage", "ops": []}, {"trigger": "modify_damage", "ops": []}])

	# Act
	hooks.install(installer)

	# Assert
	assert_array(_effect_ids(hooks.entries(&"modify_damage"))).is_equal(["t_noid.0", "t_noid.1"])


# --- duplicate host / idempotence ---------------------------------------------

func test_duplicate_host_install_returns_false_and_changes_nothing() -> void:
	# Arrange
	var hooks: HookRegistry = _registry_from(_ac_installers())
	var before: Dictionary = _snapshot(hooks)

	# Act
	var installed: bool = hooks.install(MatchFactory.make_hook_installer("t_a", SIDE_PLAYER, [&"modify_cost", &"on_draw"]))

	# Assert
	assert_bool(installed).is_false()
	assert_int(hooks.entry_count()).is_equal(before.count)
	assert_dict(_snapshot(hooks)).is_equal(before)


func test_same_installer_list_on_a_fresh_registry_yields_an_equal_registry() -> void:
	# Arrange / Act
	var first: HookRegistry = _registry_from(_ac_installers())
	var second: HookRegistry = _registry_from(_ac_installers())

	# Assert
	assert_dict(_snapshot(second)).is_equal(_snapshot(first))


# --- fold semantics -----------------------------------------------------------

func test_fold_chains_three_deltas_without_clamping() -> void:
	# Arrange — delta −1 three times; input 1
	var calls: Array = []
	var hooks: HookRegistry = HookRegistry.new()
	hooks.install(_value_installer("t_minus", SIDE_PLAYER, &"modify_cost", [_op("delta", -1), _op("delta", -1), _op("delta", -1)]))
	hooks.set_evaluators(_scripted_fold(calls), _scripted_run([]))
	var ctx: Dictionary = {"card": {"instance_id": 7}}

	# Act
	var result: int = hooks.fold(&"modify_cost", &"player", 1, ctx)

	# Assert — 1 − 1 − 1 − 1 → −2, not 0: the caller clamps once
	assert_int(result).is_equal(-2)
	assert_int(calls.size()).is_equal(3)
	assert_array(calls.map(func(c: Dictionary) -> int: return c.input)).is_equal([1, 0, -1])
	for call: Dictionary in calls:
		assert_bool(call.side == &"player").is_true()
		assert_bool(is_same(call.ctx, ctx)).is_true()


func test_fold_on_a_point_without_entries_returns_the_input() -> void:
	# Arrange
	var calls: Array = []
	var hooks: HookRegistry = _registry_from(_ac_installers())
	hooks.set_evaluators(_scripted_fold(calls), _scripted_run([]))

	# Act / Assert
	for point: StringName in [&"modify_heal", &"modify_damage", &"modify_starting_hand_size", &"modify_max_attacks"]:
		assert_int(hooks.fold(point, &"boss", 5, {})).is_equal(5)
	assert_array(calls).is_empty()


func test_set_then_mul_folds_to_six() -> void:
	# Arrange — set 2, then mul 3
	var hooks: HookRegistry = HookRegistry.new()
	hooks.install(_value_installer("t_set", SIDE_PLAYER, &"modify_max_attacks", [_op("set", 2)]))
	hooks.install(_value_installer("boss_mul", SIDE_BOSS, &"modify_max_attacks", [_op("mul", 3)]))
	hooks.set_evaluators(_scripted_fold([]), _scripted_run([]))

	# Act / Assert
	assert_int(hooks.fold(&"modify_max_attacks", &"player", 1, {})).is_equal(6)


func test_opposing_deltas_fold_back_to_the_input_through_a_negative() -> void:
	# Arrange — card-effects Edge Cases: two disagreeing value hooks net 0;
	# the intermediate −1 is not floored (the engine floors only after the fold)
	var calls: Array = []
	var hooks: HookRegistry = HookRegistry.new()
	hooks.install(_value_installer("t_down", SIDE_PLAYER, &"modify_damage", [_op("delta", -1)]))
	hooks.install(_value_installer("t_up", SIDE_PLAYER, &"modify_damage", [_op("delta", 1)]))
	hooks.set_evaluators(_scripted_fold(calls), _scripted_run([]))

	# Act
	var result: int = hooks.fold(&"modify_damage", &"player", 0, {})

	# Assert
	assert_int(result).is_zero()
	assert_array(calls.map(func(c: Dictionary) -> int: return c.input)).is_equal([0, -1])


func test_run_triggers_calls_each_entry_in_order_with_side_and_ctx() -> void:
	# Arrange
	var calls: Array = []
	var hooks: HookRegistry = HookRegistry.new()
	hooks.install(MatchFactory.make_hook_installer("t_a", SIDE_PLAYER, [&"on_turn_start", &"on_turn_start"]))
	hooks.install(MatchFactory.make_hook_installer("boss_p", SIDE_BOSS, [&"on_turn_start"]))
	hooks.set_evaluators(_scripted_fold([]), _scripted_run(calls))
	var ctx: Dictionary = {}

	# Act
	hooks.run_triggers(&"on_turn_start", &"boss", ctx)

	# Assert
	assert_array(calls.map(func(c: Dictionary) -> String: return c.effect_id)).is_equal(["t_a.0", "t_a.1", "boss_p.0"])
	for call: Dictionary in calls:
		assert_bool(call.side == &"boss").is_true()
		assert_bool(is_same(call.ctx, ctx)).is_true()


# --- copy by value ------------------------------------------------------------

func test_copy_is_by_value_with_evaluators_unset() -> void:
	# Arrange — evaluators set, three entries
	var fold_calls: Array = []
	var run_calls: Array = []
	var hooks: HookRegistry = HookRegistry.new()
	hooks.install(_value_installer("t_minus", SIDE_PLAYER, &"modify_cost", [_op("delta", -1), _op("delta", -1)]))
	hooks.install(MatchFactory.make_hook_installer("boss_p", SIDE_BOSS, [&"on_turn_end"]))
	hooks.set_evaluators(_scripted_fold(fold_calls), _scripted_run(run_calls))
	assert_int(hooks.entry_count()).is_equal(3)

	# Act
	var copied: HookRegistry = hooks.copy()
	var copied_effect: Dictionary = copied.entries(&"modify_cost")[0].effect

	# Assert — the copy owns its own containers (duplicate(true)), deep
	# read-only like the original's, so a write through it changes neither
	var original_effect: Dictionary = hooks.entries(&"modify_cost")[0].effect
	assert_bool(is_same(copied_effect, original_effect)).is_false()
	assert_bool(is_same(copied_effect.ops[0], original_effect.ops[0])).is_false()
	assert_array(_writable_containers(copied.entries(&"modify_cost"))).is_empty()
	assert_bool((copied_effect.ops[0] as Dictionary).set("value", 50)).is_false()
	assert_bool(copied_effect.set("trigger", "mutated")).is_false()
	assert_int(copied_effect.ops[0].value).is_equal(-1)
	assert_int(original_effect.ops[0].value).is_equal(-1)
	assert_str(original_effect.trigger).is_equal("modify_cost")
	assert_int(copied.entry_count()).is_equal(hooks.entry_count())
	assert_array(_effect_ids(copied.entries(&"modify_cost"))).is_equal(_effect_ids(hooks.entries(&"modify_cost")))
	assert_array(copied.hosts()).is_equal(hooks.hosts())
	# Evaluators unset on the copy: fold returns the input, run_triggers runs nothing
	assert_int(copied.fold(&"modify_cost", &"player", 4, {})).is_equal(4)
	copied.run_triggers(&"on_turn_end", &"boss", {})
	assert_array(fold_calls).is_empty()
	assert_array(run_calls).is_empty()
	# The original keeps its evaluators
	assert_int(hooks.fold(&"modify_cost", &"player", 4, {})).is_equal(2)
	# No gate points in v1: gate is true for every point
	assert_array(HookRegistry.GATE_POINTS).is_empty()
	for point: StringName in _all_points():
		assert_bool(copied.gate(point, &"player", {})).is_true()
		assert_bool(hooks.gate(point, &"boss", {})).is_true()


func test_copy_of_an_entry_free_registry_after_set_evaluators_runs_nothing() -> void:
	# Arrange
	var hooks: HookRegistry = HookRegistry.new()
	hooks.set_evaluators(_scripted_fold([]), _scripted_run([]))

	# Act
	var copied: HookRegistry = hooks.copy()

	# Assert
	assert_int(copied.entry_count()).is_zero()
	assert_int(copied.fold(&"modify_heal", &"player", 3, {})).is_equal(3)


func test_entries_view_is_deep_read_only_and_a_nested_write_changes_nothing() -> void:
	# Arrange — a value hook whose effect nests ops[0] {mode, value}, and a nested state blob
	var hooks: HookRegistry = HookRegistry.new()
	var installer: HookInstaller = _value_installer("t_minus", SIDE_PLAYER, &"modify_cost", [_op("delta", -1)])
	installer.state = {"charges": {"left": 1}}
	hooks.install(installer)
	hooks.set_evaluators(_scripted_fold([]), _scripted_run([]))
	var view: Array = hooks.entries(&"modify_cost")

	# Act — a write at every nesting level, through the view
	var wrote_op: bool = (view[0].effect.ops[0] as Dictionary).set("value", 99)
	var wrote_effect: bool = (view[0].effect as Dictionary).set("trigger", "on_draw")
	var wrote_entry: bool = (view[0] as Dictionary).set("side", &"boss")
	var wrote_state: bool = (view[0].state.charges as Dictionary).set("left", 7)

	# Assert — no write landed; the registry still folds -1 on the player side
	assert_array(_writable_containers(view)).is_empty()
	assert_array([wrote_op, wrote_effect, wrote_entry, wrote_state]).is_equal([false, false, false, false])
	var entry: Dictionary = hooks.entries(&"modify_cost")[0]
	assert_int(entry.effect.ops[0].value).is_equal(-1)
	assert_str(entry.effect.trigger).is_equal("modify_cost")
	assert_bool(entry.side == &"player").is_true()
	assert_int(entry.state.charges.left).is_equal(1)
	assert_int(hooks.fold(&"modify_cost", &"player", 4, {})).is_equal(3)
	# The installer's own data stays writable: install copies before freezing
	assert_bool((installer.effects[0].ops[0] as Dictionary).is_read_only()).is_false()


# --- plain data, no back-references ------------------------------------------

func test_registry_entries_and_hosts_hold_no_object_reference() -> void:
	# Arrange
	var hooks: HookRegistry = _registry_from(_ac_installers())
	hooks.set_evaluators(_scripted_fold([]), _scripted_run([]))

	# Act
	var objects: Array = []
	for point: StringName in _all_points():
		_collect_objects(hooks.entries(point), objects)
	_collect_objects(hooks.hosts(), objects)

	# Assert — no engine, log, MatchState, Node or registry inside (rule 6)
	assert_array(objects).is_empty()
	for point: StringName in _all_points():
		GameAssertions.assert_json_representable(hooks.entries(point), str(point))
		assert_bool(hooks.entries(point).is_read_only()).is_true()


func test_hook_installer_round_trips_through_to_dict() -> void:
	# Arrange
	var installer: HookInstaller = MatchFactory.make_hook_installer("boss_p", SIDE_BOSS, [&"on_turn_start"], {"seen": 2})

	# Act
	var restored: HookInstaller = HookInstaller.from_dict(installer.to_dict())

	# Assert
	assert_dict(restored.to_dict()).is_equal(installer.to_dict())
	assert_bool(restored.host_kind == HookInstaller.HOST_KIND_PASSIVE).is_true()
	assert_bool(restored.side == SIDE_BOSS).is_true()
	GameAssertions.assert_json_representable(installer.to_dict(), "installer")


func test_factory_match_state_carries_an_empty_hook_registry() -> void:
	# Act
	var state: MatchState = MatchFactory.make_match_state()

	# Assert
	assert_object(state.hooks).is_not_null()
	assert_int(state.hooks.entry_count()).is_zero()
	assert_bool(state.hooks.install(MatchFactory.make_hook_installer("t_a", SIDE_PLAYER, [&"modify_cost"]))).is_true()
