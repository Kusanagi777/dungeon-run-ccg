## Unit tests for AnimStep and AnimationQueue (match-ui story 002;
## design/gdd/match-ui.md U4 rules 1-8, F3; AC L5, L6, L7, L11; ADR-0009
## Decision 1-2).
##
## Headless and Node-free: the queue's clock is driven by `advance(delta)` with
## fixed deltas (no wall clock — the L6 "300-step flush in 100 ms" clause is in
## `tests/performance/match_ui/`), and a `FakePresenter` records `apply_final`
## order and compares its display with the view-state (`sync_report`).
## Durations, divisors, the threshold and impact extras come from
## `MatchUiTestConfig.body()`; settings from `MatchUiTestConfig.settings()`.
extends GdUnitTestSuite

## One 60 Hz frame — the fake clock's tick (any fixed delta works; this one
## keeps "after step k" close to step boundaries).
const FRAME_S: float = 1.0 / 60.0
## The AC's L6 skip indices: `k in 0..30`.
const SKIP_K_MAX: int = 30
## The L6 burst size the AC names.
const BURST_EVENTS: int = 30
const PLAYER_HERO_ID: int = 1
const BOSS_HERO_ID: int = 2
const PLAYER_MINION_ID: int = 31
const BOSS_MINION_IDS: Array[int] = [51, 52, 53, 54, 55, 56]
const SPELL_INSTANCE: int = 60
## A source id for the AoE pops (L11) and the base of its target ids.
const AOE_SOURCE: int = 900
const AOE_TARGET_BASE: int = 1000


# --- helpers -----------------------------------------------------------------

func _config() -> Dictionary:
	return MatchUiTestConfig.body()


func _queue(settings: Dictionary = {}, config: Dictionary = _config()) -> AnimationQueue:
	return AnimationQueue.new(config, MatchUiTestConfig.settings(settings))


## Appends an envelope to [param events] with the next `seq`; returns that seq.
func _add(events: Array, type: String, payload: Dictionary, cause_seq: int = 0) -> int:
	var seq: int = events.size() + 1
	events.append({"seq": seq, "turn": 1, "type": type, "payload": payload, "cause_seq": cause_seq})
	return seq


## Heroes, a player minion, six boss minions and the spell card in hand.
func _opening() -> Array:
	var events: Array = []
	_add(events, "match_started", {"floor": 1, "hero_id": PLAYER_HERO_ID, "boss_id": BOSS_HERO_ID, "player_deck_size": 3, "boss_deck_size": 0})
	_add(events, "deck_shuffled", {"side": "player", "instance_ids": [SPELL_INSTANCE, 61, 62]})
	_add(events, "card_drawn", {"side": "player", "instance_id": SPELL_INSTANCE, "card_id": "neutral_test_bolt", "hand_size": 1})
	_add(events, "minion_summoned", {"side": "player", "entity_id": PLAYER_MINION_ID, "card_id": "neutral_test_vanilla_2_2", "position": 0, "attack": 2, "health": 3})
	for i: int in BOSS_MINION_IDS.size():
		_add(events, "minion_summoned", {"side": "boss", "entity_id": BOSS_MINION_IDS[i], "card_id": "boss_tinder_imp", "position": i, "attack": 1, "health": 1})
	return events


## The L6 burst: 30 C15 events after [method _opening] — a player AoE spell
## (7 pops, 4 deaths, a trigger, two parallel buffs, a heal), armour and two
## draws, a boss summon with a freeze and a hit, an attack, a hero power.
func _burst(events: Array) -> Array:
	var first: int = events.size()
	var dmg: Callable = func(source: int, target: int, after: int, cause: int) -> void:
		_add(events, "damage_dealt", {"source": source, "target": target, "requested": 1, "prevented": 0, "armor_absorbed": 0, "dealt": 1, "health_after": after}, cause)
	_add(events, "mana_spent", {"side": "player", "amount": 1, "mana_available": 0})
	_add(events, "card_played", {"side": "player", "instance_id": SPELL_INSTANCE, "card_id": "neutral_test_bolt", "cost_paid": 1, "target_id": null, "board_index": null})
	var cast: int = _add(events, "spell_cast", {"side": "player", "instance_id": SPELL_INSTANCE, "card_id": "neutral_test_bolt", "target_id": null, "spell_damage": 0})
	var effect: int = _add(events, "effect_resolved", {"effect_id": "neutral_test_bolt.0", "host_id": SPELL_INSTANCE, "host_kind": "card", "source_id": SPELL_INSTANCE, "owner": "player", "trigger": "cast", "depth": 0, "fizzled": false, "ops": ["damage"]}, cast)
	for id: int in BOSS_MINION_IDS:
		dmg.call(SPELL_INSTANCE, id, 0 if id < BOSS_MINION_IDS[4] else 1, effect)
	dmg.call(SPELL_INSTANCE, BOSS_HERO_ID, 29, effect)
	var death: int = 0
	for id: int in BOSS_MINION_IDS.slice(0, 4):
		var seq: int = _add(events, "minion_died", {"instance_id": id, "card_id": "boss_tinder_imp", "side": "boss", "board_index": 0}, effect)
		death = seq if death == 0 else death
	var queued: int = _add(events, "trigger_queued", {"instance_id": BOSS_MINION_IDS[4], "card_id": "boss_tinder_imp", "trigger": "on_minion_died"}, death)
	var resolved: int = _add(events, "trigger_resolved", {"instance_id": BOSS_MINION_IDS[4], "card_id": "boss_tinder_imp", "effect_id": "boss_tinder_imp.0", "trigger": "on_minion_died"}, queued)
	_add(events, "enchantment_applied", {"instance_id": BOSS_MINION_IDS[4], "attack_delta": 1, "health_delta": 0, "keywords_added": [], "source_entity_id": BOSS_MINION_IDS[4], "is_aura": false, "expires": null}, resolved)
	_add(events, "enchantment_applied", {"instance_id": BOSS_MINION_IDS[5], "attack_delta": 0, "health_delta": 0, "keywords_added": ["taunt"], "source_entity_id": BOSS_MINION_IDS[4], "is_aura": false, "expires": null}, resolved)
	_add(events, "healed", {"source": BOSS_MINION_IDS[4], "target": BOSS_HERO_ID, "requested": 1, "amount": 1}, resolved)
	var armour: int = _add(events, "armor_gained", {"side": "player", "entity_id": PLAYER_HERO_ID, "amount": 2, "armor": 2})
	_add(events, "card_drawn", {"side": "player", "instance_id": 61, "card_id": "neutral_test_vanilla_1_1", "hand_size": 1}, armour)
	_add(events, "card_drawn", {"side": "player", "instance_id": 62, "card_id": "neutral_test_vanilla_1_1", "hand_size": 2}, armour)
	var summon: int = _add(events, "minion_summoned", {"side": "boss", "entity_id": 57, "card_id": "boss_tinder_imp", "position": 0, "attack": 1, "health": 1})
	_add(events, "frozen", {"entity_id": PLAYER_MINION_ID, "frozen_on_turn": 1}, summon)
	dmg.call(57, PLAYER_MINION_ID, 2, summon)
	var attack: int = _add(events, "attack_declared", {"attacker_id": PLAYER_MINION_ID, "defender_id": BOSS_HERO_ID})
	dmg.call(PLAYER_MINION_ID, BOSS_HERO_ID, 28, attack)
	_add(events, "attack_resolved", {"attacker_id": PLAYER_MINION_ID, "defender_id": BOSS_HERO_ID}, attack)
	_add(events, "hero_power_used", {"side": "player", "power_id": "power_whetstone", "target_id": null})
	return events.slice(first)


## A projected opening, a bound presenter, then the burst's steps bound and
## enqueued. Returns `{view, queue, presenter, steps, burst}`.
func _staged(settings: Dictionary = {}) -> Dictionary:
	var view: MatchViewState = MatchViewState.new(_config())
	var events: Array = _opening()
	for event: Dictionary in events:
		view.apply(event)
	var presenter: FakePresenter = FakePresenter.new()
	presenter.bind(view)
	var queue: AnimationQueue = _queue(settings)
	presenter.listen(queue)
	var burst: Array = _burst(events)
	var steps: Array[AnimStep] = []
	for event: Dictionary in burst:
		for step: AnimStep in view.apply(event):
			presenter.bind_step(step)
			steps.append(step)
			queue.enqueue(step)
	return {"view": view, "queue": queue, "presenter": presenter, "steps": steps, "burst": burst}


## Advances the fake clock until [param presenter] saw [param k] finished
## steps or the queue is idle.
func _advance_until(queue: AnimationQueue, presenter: FakePresenter, k: int) -> void:
	while presenter.finished_count < k and not queue.is_idle():
		queue.advance(FRAME_S)


## A pop step on one target, from [param source], in group [param group].
func _pop(target: int, source: int, group: int, seq: int, kind: StringName = AnimStep.DAMAGE_POP) -> AnimStep:
	var step: AnimStep = AnimStep.new(kind, [target], float(_config().d_base[String(kind)]), group, seq)
	step.data = {"amount": 1, "source": source}
	return step


## Enqueues [param n] pops on distinct targets from one source in one group.
func _enqueue_aoe(queue: AnimationQueue, presenter: FakePresenter, n: int) -> Array[AnimStep]:
	var pops: Array[AnimStep] = []
	for i: int in n:
		var pop: AnimStep = _pop(AOE_TARGET_BASE + i, AOE_SOURCE, 1, 2 + i)
		presenter.bind_step(pop)
		pops.append(pop)
		queue.enqueue(pop)
	return pops


func _started_kinds(presenter: FakePresenter) -> Array:
	return presenter.started.map(func(entry: Array) -> String: return String((entry[0] as AnimStep).kind))


# --- L5: a death run plays as one death_group then one gap_close -------------------

func test_four_deaths_sharing_a_cause_play_one_death_group_then_one_gap_close_before_the_next_group() -> void:
	# Arrange: four boss minions die of one effect (cause 20), then a later root draws
	var view: MatchViewState = MatchViewState.new(_config())
	var events: Array = _opening()
	for event: Dictionary in events:
		view.apply(event)
	var presenter: FakePresenter = FakePresenter.new()
	presenter.bind(view)
	var queue: AnimationQueue = _queue()
	presenter.listen(queue)
	var later: Array = []
	for id: int in BOSS_MINION_IDS.slice(0, 4):
		later.append({"seq": 20 + later.size(), "turn": 1, "type": "minion_died", "payload": {"instance_id": id, "card_id": "boss_tinder_imp", "side": "boss", "board_index": 0}, "cause_seq": 19})
	later.append({"seq": 30, "turn": 1, "type": "card_drawn", "payload": {"side": "player", "instance_id": 61, "card_id": "neutral_test_vanilla_1_1", "hand_size": 2}, "cause_seq": 0})

	# Act
	for event: Dictionary in later:
		for step: AnimStep in view.apply(event):
			presenter.bind_step(step)
			queue.enqueue(step)
	_advance_until(queue, presenter, 1_000)

	# Assert
	assert_array(presenter.timeline).is_equal([
		"started death_group", "finished death_group",
		"started gap_close", "finished gap_close",
		"started draw", "finished draw",
		"drained",
	])
	assert_array(presenter.sync_report()).is_empty()


# --- L6: skip-all after every step index ----------------------------------------------

func test_skip_all_after_every_step_k_syncs_the_presenter_and_runs_each_final_once_in_seq_order() -> void:
	for k: int in range(SKIP_K_MAX + 1):
		# Arrange
		var staged: Dictionary = _staged()
		var queue: AnimationQueue = staged.queue
		var presenter: FakePresenter = staged.presenter
		var steps: Array[AnimStep] = staged.steps
		assert_int(staged.burst.size()).is_equal(BURST_EVENTS)
		_advance_until(queue, presenter, k)

		# Act
		queue.skip_all()

		# Assert
		assert_array(presenter.sync_report()).override_failure_message("k=%d: %s" % [k, presenter.sync_report()]).is_empty()
		assert_array(presenter.final_seqs).is_equal(steps.map(func(s: AnimStep) -> int: return s.seq))
		assert_int(presenter.final_counts.size()).is_equal(steps.size())
		for count: int in presenter.final_counts.values():
			assert_int(count).is_equal(1)
		assert_int(presenter.skipped_count).is_equal(1)
		assert_bool(queue.is_idle()).is_true()


func test_the_burst_out_of_sync_before_playback_and_in_sync_once_drained() -> void:
	# Arrange
	var staged: Dictionary = _staged()
	var queue: AnimationQueue = staged.queue
	var presenter: FakePresenter = staged.presenter
	var before: Array[String] = presenter.sync_report()

	# Act: play to the end on the fake clock, no skip (U4.6 idle invariant)
	_advance_until(queue, presenter, 1_000)

	# Assert
	assert_array(before).is_not_empty()
	assert_array(presenter.sync_report()).is_empty()
	assert_int(presenter.drained_count).is_equal(1)
	assert_int(presenter.skipped_count).is_equal(0)
	assert_array(presenter.final_seqs).is_equal(staged.steps.map(func(s: AnimStep) -> int: return s.seq))


func test_skip_all_emits_skipped_before_any_final_and_drained_after() -> void:
	# Arrange
	var staged: Dictionary = _staged()
	var presenter: FakePresenter = staged.presenter
	staged.queue.advance(FRAME_S)

	# Act
	staged.queue.skip_all()

	# Assert: the skip is announced first (presenters kill tweens), drained is last
	var after_skip: Array = presenter.timeline.slice(presenter.timeline.find("skipped"))
	assert_str(after_skip[0]).is_equal("skipped")
	assert_str(after_skip[-1]).is_equal("drained")
	assert_int(presenter.drained_count).is_equal(1)


func test_skip_all_on_an_idle_queue_emits_skipped_once_and_no_drained() -> void:
	# Arrange
	var queue: AnimationQueue = _queue()
	var presenter: FakePresenter = FakePresenter.new()
	presenter.listen(queue)

	# Act
	queue.skip_all()

	# Assert
	assert_array(presenter.timeline).is_equal(["skipped"])


# --- L7: F3 speed divisor, instant and reduce_motion ---------------------------------------

func test_effective_durations_follow_f3_for_every_base_duration_and_speed() -> void:
	# Arrange
	var config: Dictionary = _config()
	var impact: Dictionary = {
		"hit_stop_ms": int(config.impact_ms.hit_stop),
		"shake_ms": int(config.impact_ms.shake),
		"slow_ms": int(config.impact_ms.slow),
	}
	var none: Dictionary = {"hit_stop_ms": 0, "shake_ms": 0, "slow_ms": 0}
	var cases: Array = [
		# [settings, divisor or 0 for instant, extras kept]
		[{"anim_speed": "normal"}, float(config.SPEED_DIV.normal), true],
		[{"anim_speed": "fast"}, float(config.SPEED_DIV.fast), false],
		[{"anim_speed": "instant"}, 0.0, false],
		[{"anim_speed": "normal", "reduce_motion": true}, float(config.SPEED_DIV.normal), false],
	]
	for case: Array in cases:
		var queue: AnimationQueue = _queue(case[0])
		for kind: String in config.d_base:
			var step: AnimStep = AnimStep.new(StringName(kind), [1], float(config.d_base[kind]), 1, 1)
			step.impact = impact.duplicate()

			# Act
			var d_eff: float = queue.effective_duration(step)
			var extras: Dictionary = queue.effective_impact(step)

			# Assert
			var expected: float = 0.0 if case[1] == 0.0 else float(config.d_base[kind]) / float(case[1])
			assert_float(d_eff).override_failure_message("%s %s" % [case[0], kind]).is_equal_approx(expected, 1e-9)
			assert_dict(extras).override_failure_message("%s %s" % [case[0], kind]).is_equal(impact if case[2] else none)


func test_fast_halves_playback_on_the_fake_clock() -> void:
	# Arrange: the F3 example — an attack lunge at fast
	var config: Dictionary = _config()
	var queue: AnimationQueue = _queue({"anim_speed": "fast"})
	var presenter: FakePresenter = FakePresenter.new()
	presenter.listen(queue)
	var lunge: AnimStep = AnimStep.new(AnimStep.ATTACK_LUNGE, [1, 2], float(config.d_base.attack_lunge), 1, 1)
	var d_fast: float = float(config.d_base.attack_lunge) / float(config.SPEED_DIV.fast)
	queue.enqueue(lunge)

	# Act / Assert: still running just before d_eff, finished at d_eff
	queue.advance(d_fast * 0.9)
	assert_int(presenter.finished_count).is_equal(0)
	assert_float(float(presenter.started[0][1])).is_equal_approx(d_fast, 1e-9)
	queue.advance(d_fast * 0.1)
	assert_int(presenter.finished_count).is_equal(1)
	assert_bool(lunge.final_ran()).is_true()


func test_instant_runs_apply_final_only() -> void:
	# Arrange
	var staged: Dictionary = _staged({"anim_speed": "instant"})
	var presenter: FakePresenter = staged.presenter

	# Act: one zero-length tick drains everything
	staged.queue.advance(0.0)

	# Assert
	assert_array(presenter.started).is_empty()
	assert_int(presenter.finished_count).is_equal(staged.steps.size())
	assert_array(presenter.sync_report()).is_empty()
	assert_bool(staged.queue.is_idle()).is_true()


func test_set_speed_and_set_reduce_motion_apply_to_later_steps() -> void:
	# Arrange
	var config: Dictionary = _config()
	var queue: AnimationQueue = _queue()
	var step: AnimStep = AnimStep.new(AnimStep.DAMAGE_POP, [1], float(config.d_base.damage_pop), 1, 1)
	step.impact = {"hit_stop_ms": int(config.impact_ms.hit_stop), "shake_ms": 0, "slow_ms": 0}

	# Act / Assert
	queue.set_speed(&"fast")
	assert_float(queue.effective_duration(step)).is_equal_approx(float(config.d_base.damage_pop) / float(config.SPEED_DIV.fast), 1e-9)
	queue.set_speed(&"normal")
	queue.set_reduce_motion(true)
	assert_float(queue.effective_duration(step)).is_equal_approx(float(config.d_base.damage_pop), 1e-9)
	assert_int(int(queue.effective_impact(step).hit_stop_ms)).is_equal(0)


# --- L11: coalescing AoE pops -------------------------------------------------------------

func test_ten_pops_on_distinct_targets_from_one_source_coalesce_into_one_step() -> void:
	# Arrange
	var queue: AnimationQueue = _queue()
	var presenter: FakePresenter = FakePresenter.new()
	presenter.listen(queue)

	# Act
	var pops: Array[AnimStep] = _enqueue_aoe(queue, presenter, 10)
	_advance_until(queue, presenter, 1_000)

	# Assert: one simultaneous pop, every original final once, in seq order
	assert_int(presenter.started.size()).is_equal(1)
	var merged: AnimStep = presenter.started[0][0]
	assert_int(merged.entity_ids.size()).is_equal(10)
	assert_array(presenter.final_seqs).is_equal(pops.map(func(s: AnimStep) -> int: return s.seq))
	assert_int(int(merged.data.source)).is_equal(AOE_SOURCE)


func test_pops_up_to_the_threshold_play_one_by_one() -> void:
	var threshold: int = int(_config().COALESCE_THRESHOLD)
	for n: int in [7, threshold]:
		# Arrange
		var queue: AnimationQueue = _queue()
		var presenter: FakePresenter = FakePresenter.new()
		presenter.listen(queue)

		# Act
		_enqueue_aoe(queue, presenter, n)
		_advance_until(queue, presenter, 1_000)

		# Assert: U4.3 "more than COALESCE_THRESHOLD" — n ≤ threshold is n steps
		assert_int(presenter.started.size()).is_equal(n)


func test_one_pop_beyond_the_threshold_coalesces_and_the_threshold_is_read_from_config() -> void:
	# Arrange: a config threshold of 4 → 5 pops coalesce, 4 do not
	var config: Dictionary = _config()
	config.COALESCE_THRESHOLD = 4
	var counts: Array = []
	for n: int in [int(config.COALESCE_THRESHOLD), int(config.COALESCE_THRESHOLD) + 1]:
		var queue: AnimationQueue = _queue({}, config)
		var presenter: FakePresenter = FakePresenter.new()
		presenter.listen(queue)

		# Act
		_enqueue_aoe(queue, presenter, n)
		_advance_until(queue, presenter, 1_000)
		counts.append(presenter.started.size())

	# Assert
	assert_array(counts).is_equal([4, 1])


func test_pops_from_different_sources_or_groups_never_coalesce() -> void:
	# Arrange: ten pops alternating two sources, then ten pops each in its own group
	var queue: AnimationQueue = _queue()
	var presenter: FakePresenter = FakePresenter.new()
	presenter.listen(queue)
	for i: int in 10:
		queue.enqueue(_pop(AOE_TARGET_BASE + i, AOE_SOURCE + (i % 2), 1, 2 + i))
	for i: int in 10:
		queue.enqueue(_pop(AOE_TARGET_BASE + i, AOE_SOURCE, 100 + i, 100 + i))

	# Act
	_advance_until(queue, presenter, 1_000)

	# Assert
	assert_int(presenter.started.size()).is_equal(20)


# --- U4.2: groups FIFO, parallel_ok ------------------------------------------------------------

func test_a_parallel_ok_step_starts_with_the_step_before_it() -> void:
	# Arrange: a pop, then a parallel badge of the same group, then a new group
	var config: Dictionary = _config()
	var queue: AnimationQueue = _queue()
	var presenter: FakePresenter = FakePresenter.new()
	presenter.listen(queue)
	var pop: AnimStep = _pop(1, 2, 10, 10)
	var badge: AnimStep = AnimStep.new(AnimStep.BADGE, [1], float(config.d_base.badge), 10, 11)
	badge.parallel_ok = true
	var next: AnimStep = AnimStep.new(AnimStep.BADGE, [1], float(config.d_base.badge), 12, 12)
	next.parallel_ok = true
	for step: AnimStep in [pop, badge, next]:
		presenter.bind_step(step)
		queue.enqueue(step)

	# Act
	_advance_until(queue, presenter, 1_000)

	# Assert: the badge starts with the pop; the next group's parallel step does not
	assert_array(presenter.timeline).is_equal([
		"started damage_pop", "started badge",
		"finished damage_pop", "finished badge",
		"started badge", "finished badge",
		"drained",
	])
	assert_array(presenter.final_seqs).is_equal([10, 11, 12])


func test_run_final_is_idempotent() -> void:
	# Arrange
	var presenter: FakePresenter = FakePresenter.new()
	presenter.bind(MatchViewState.new(_config()))
	var step: AnimStep = _pop(1, 2, 1, 1)
	presenter.bind_step(step)

	# Act
	step.run_final()
	step.run_final()

	# Assert
	assert_array(presenter.final_seqs).is_equal([1])
