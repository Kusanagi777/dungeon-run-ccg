# DSL spike — the five hardest effect types (2026-11-03)

> **Spike record, not an ADR.** It has no Status and follows no ADR lifecycle.
> It is the evidence for Pre-Production gate entry condition 6
> (`production/gate-checks/gate-pre-production-2026-11-03.md`, owner
> lead-programmer) and the AC-S2 output of
> `production/epics/card-effects/story-001-dsl-spike-five-hardest.md`.

## Outcome

**PROCEED.**

All five effect types resolved headless from their C11 DSL text **verbatim**,
with every rule taken as written: one pass per C10 step and no death check
between ops (C6.0), and one outstanding `ChoiceRequest` (C8). The DSL needed
**no change**: no new op, trigger, selector, filter predicate or value form, no
`targeting` field, and no C1–C9 rule rewritten. Stories 006–016 of the
card-effects epic are **not** re-blocked. The findings below are wording
clarifications, interface notes and gate fixes, each with its owner. None of
them changes the grammar, so none goes to `/propagate-design-change`.

## How it ran

| Item | Value |
|---|---|
| Engine under test | **Stub engine** (`spike_stub_engine.gd`). match-rules stories 001–002 (`RulesEngine`) were not merged. The stub has only `state()`, `emit()`, `rng_match()`, `discover()`, the primitives `apply_damage`, `apply_heal`, `summon_minion`, `add_card_to_hand`, `apply_enchantment`, `destroy`, the commands `cast_spell`, `use_hero_power`, `choose`, and the C10 loop (death check → `recompute_auras()` → queue pop). The engine owns the loop and the queue. |
| Resolver | `spike_effect_resolver.gd`. It interprets effects as data on every pass and never compiles them to Callables. It reads state only through `engine.state()`, writes only through primitives, emits only through `engine.emit`, draws only through `engine.rng_match()`, and keeps its only state in `state().effects`. |
| Code location | Written to `src/gameplay/effects/spike/` as the story names (commit `0e672cc`). At close (AC-S3) it was deleted from there and kept only as a test-only fixture: `tests/unit/card_effects/spike/spike_effect_resolver.gd` and `spike_stub_engine.gd`. The evidence test keeps running, nothing remains under `src/gameplay/effects/` (G7 has nothing to scan), and no production class, scene or data file references it. Neither story 002 nor 006 promotes it; both build fresh against the verdict. |
| Data | Each effect object is the C11 row's JSON text pasted into the test and parsed with `JSON.parse_string`, the same way the loader will read it. Records come from `CardFactory`, state from `MatchFactory` (C1 Dictionaries). The AC-10 pool is a 40-card War pool: 31 minions and 9 spells, one of them the casting spell. |
| Randomness / log | `TestRngStream.seeded("match_1", 7)` (AC-10's seed) or `TestRngStream.scripted(...)`; `TestEventLog`. No Node, no scene. |
| Tests | `tests/unit/card_effects/card_effects_dsl_spike_test.gd`, 17 test cases, all passing. Full suite: 83 test cases, exit 0 (Godot 4.7.2, gdUnit4 6.2.3). |
| Watched fail | Four mutations, each applied alone and then reverted: **M1** a death check inside `apply_damage` (between ops) → the row 16 order test fails. **M2** counter refs always read the live bucket → the late-counter snapshot test fails. **M3** the engine stops stripping `is_aura` enchantments → the row 27 recompute-idempotence test fails. **M4** Discover draws with replacement → the F4 scripted-draw test fails. |

## Per effect type

### 1. Row 20 — "Discover a spell" (AC-10, AC-11)

- **Worked.** `discover_offered.option_card_ids` held 3 distinct spell ids, none of them the casting spell. The engine was in `Choice`, and exactly 3 stream draws were used (`TestRngStream.draws`). After `choose(1)`, that card was in hand and the log read `choice_made`, `discover_picked`, `card_added_to_hand`, `effect_resolved` with nothing in between. No draw happened while waiting or on resume. With a scripted stream the draws were `randi_range(0,7)`, `(0,6)`, `(0,5)` over the 8 candidates in ascending id order, which matches F4's own example. AC-11: a pool with 2 candidates offered 2 options. A pool with 0 candidates gave no `Choice`, op outcome `empty_pool`, and the next op still ran.
- **What the DSL needed:** nothing new. The pause is the C8.1 continuation, stored as plain data in `EffectRuntime.pending_choice`, and it passes `assert_json_representable`.
- **Also shown:** a `repeat` around a `discover` (C8.4) produced two choices in sequence, each after the previous `choose`, with one `effect_resolved` at the end. A second command during `Choice` was rejected with `CHOICE_PENDING` and drew nothing.

### 2. Row 33 — Choose One "Deal 2 / Restore 4" (AC-12)

- **Worked.** `choose(0)` gave `damage_dealt` with `requested 2, dealt 2` on the chosen 3/3 and no `healed`. `choose(1)` gave `healed` on the same target and no `damage_dealt`. `discover_offered` carried `kind: choose_one` and `option_label_keys`. No RNG was drawn.
- **What the DSL needed:** nothing. The options carry no targets of their own and both use the effect-level `chosen` (C8.3).

### 3. Row 16 — Rot "Deal 1. If it dies, summon a Husk" (AC-43)

- **Worked.** On an enemy 2/1 the log read `hero_power_used`, `damage_dealt`, `minion_summoned{decay_husk, player, board_index 1}` (the rightmost friendly slot), `effect_resolved` (`ops[1].outcome == applied`), and only then `minion_died`. The Husk arrived before the target's Deathrattle resolved. The first three of those events are consecutive, and the engine trace shows the pass, then the death check. On a 2/3: damage only, no `minion_summoned`, `ops[1].outcome == skipped`. On a 1/1 with Divine Shield: `divine_shield_popped`, no `damage_dealt`, no summon.
- **What the DSL needed:** nothing. `{"test": ["target", {"is_dying": true}]}` reads the live target between op 1 and the death check, as C6.0 and the C3 `is_dying` row describe.

### 4. Row 45 — counter + snapshot Deathrattle (AC-46)

- **Worked.** Three minions died (one player-side, two boss-side) while row 45 was in play. That gave three `counter_changed` events (1, 2, 3). When row 45 died, its Deathrattle dealt `dealt: 3` to the enemy hero, and `effect_resolved.ops[0].values.read_from == "snapshot"`. A new instance (new `entity_id`) that saw no deaths dealt 0, so counters are keyed per entity.
- **What the DSL needed:** nothing. Two effects on one host, `add_counter` into `EffectRuntime.counters`, and `counter.seen` read from the raise-time snapshot (C4, C5, C6.5).
- **Edge found** (finding 4 below): a death raised *before* row 45 died but resolved *after* is not in the snapshot.

### 5. Rows 26 + 27 — aura lord and adjacency aura, stacked (AC-26)

- **Worked.** On `[26, 26, vanilla 1/1, 27]` the 1/1 read 5/3, each lord read +1/+1 (from the other only), and row 27 read +2/+2, with one `auras_recomputed`. When the 1/1 died, row 27's new left neighbour (the second lord) gained +2 Attack on the next recompute. A further recompute changed nothing: strip-and-reapply is idempotent.
- **What the DSL needed:** nothing. `recompute_auras()` is engine-called; it strips every `is_aura` enchantment and asks the resolver to re-apply live auras in canonical source order. Each source applies an aura at most once per target, and separate sources stack (C7, F2).

## Findings (non-blocking — no grammar change)

| # | Finding | Where it changes | Owner / story |
|---|---|---|---|
| 1 | card-effects AC-12, AC-13, AC-43 and AC-46 write `damage_dealt{amount: N}`, but the payload is `{source, target, requested, prevented, armor_absorbed, dealt, health_after}` (match-rules C15, rng-event-log catalogue). The tests read `dealt`. | card-effects §Acceptance Criteria wording | card-effects GDD owner; stories 006/009/010 |
| 2 | match-rules C15 names **no event** for the `add_card_to_hand` primitive. The stub emitted the provisional `card_added_to_hand {side, instance_id, card_id, hand_size}`, and AC-10's "`discover_picked` precedes the next event" depends on it existing. | match-rules C15 event vocabulary and the rng-event-log index | match-rules owner; match-rules primitive story |
| 3 | ADR-0007 Key Interfaces gives `resolve(point, ctx) -> void`, but match-rules Interactions says `resolve(trigger_point, context) → steps` and ADR-0007 has the engine own Q. The spike's `resolve` **returns the queue entries** (plain data with the C6.5 snapshot) and the engine appends them, which keeps the queue engine-owned. | ADR-0007 Key Interfaces erratum | technical-director; card-effects story 008 |
| 4 | **Late counter vs snapshot:** if a death queues row 45's `add_counter` and something else kills row 45 before that counter op resolves (e.g. the dead minion's own Deathrattle, which is queued first), then row 45's Deathrattle snapshot is taken with `seen` still 0. The late `add_counter` raises only the live bucket, and the Deathrattle deals 0 even though a minion died "while this was in play". Under C6.5 as written this is deterministic, and it is pinned by `test_row45_counter_raised_before_death_but_resolved_after_is_not_in_snapshot`. It may read badly in the log (Pillar 4). | card-effects §Edge Cases: state it (or change C6.5 so a counter op on a source that has left play updates its pending snapshot) | card-effects GDD owner; story 009 |
| 5 | C3 says selectors never yield a dying entity, yet `chosen` is listed as a selector, and later ops reuse the effect-level `chosen` (rows 15, 33). The spike treats `chosen`, like `self`, as the explicit `target` **reference**, so it may yield a dying target. | card-effects C3 wording | card-effects GDD owner; story 007 |
| 6 | C8.1's continuation `{…, op_index, remaining ops}`: `op_index` alone cannot resume a `discover` nested inside `repeat`/`conditional`. The spike stores the **remaining work list** (flattened ops still to run), which covers `op_index` and makes C8.4 work (tested). C8.1's "remaining ops" already allows this. | none (implementation note) | story 010 |
| 7 | The continuation does not carry the **later play effects of the same host**. If effect 0 pauses, effect 1 of the same card is not resumed. No C11 row needs it (spike limit). | C8.1 wording or story 010 design | story 010 |
| 8 | Aura re-application calls `apply_enchantment(…, is_aura: true)` per target on every recompute. Emitting `enchantment_applied` each time would flood the log, so the stub keeps aura enchantments silent and emits one `auras_recomputed` with net changes, **only when the changes are non-empty**. match-rules C10 does not say whether an empty recompute emits. | match-rules C10 wording | match-rules owner; story 012 |
| 9 | **Grep gate G7 does not see subscript writes.** The stub engine (engine side) holds 7 direct state writes in `x["damage_taken"] = …` / `(x["enchantments"] as Array).append(…)` form, and G7's regex reports only 1 hit (`log.append`). The resolver has zero G7 hits and, checked separately, no subscript writes outside its own `EffectRuntime` (`pending_choice`). G7 should add the subscript forms, or production state should be typed classes where the dot form is the only form. | ADR-0007 decision 9 / control manifest Core Forbidden | technical-director; story 016 or the CI gate |
| 10 | `EffectRuntime.counters` is keyed by `str(entity_id)`. Int keys fail rng-event-log rule 14 (`assert_json_representable`). | none (implementation note) | story 002 / 009 |
| 11 | JSON numbers arrive as floats, so the resolver casts every numeric param with `int()`. | none (implementation note) | stories 002 / 007 |
| 12 | A dead source's live counter bucket is never dropped, because nothing tells the resolver an entity left play. Harmless here, since a new instance gets a new id. | none (lifecycle) | story 009 |

## Not exercised (and why)

- `DISCOVER_EXCLUDE_HAND`, boss-side `Choice` (Boss AI answers), Discover `then: summon | cast`: out of the five rows; story 010.
- F1 Spell Damage scaling with a non-zero total: row 33 ran with no Spell Damage minion; story 007.
- Silence of an aura source, treasure auras, hand auras: story 012.
- The `RulesEngine.submit() ≤ 5 ms` guardrail: not measured. A stub engine's timing says nothing about the real one (story 016). The 17 spike tests ran in about 0.26 s in total.
- The validator (`E_FX_*`, F6 bound): spike scope allowed skipping it (stories 003–004).
