# RNG & Event Log

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
> **Author**: owner + Claude (`/design-system`, guided automation, Lean review — no specialist agents consulted)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 4 (Readable, deterministic rules); supports Pillar 3 (Lose fast, learn fast)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` `systems-designer` / `qa-lead` not consulted on Formulas and Acceptance Criteria — Lean mode and no Agent tool in this run; review manually before production.
> **Decisions cited**: DD-T03, DD-T04, DD-R09, DD-R08, DD-T01, DD-T02, DD-M06, DD-M07, DD-M11, DD-M12, DD-M13, DD-R01, DD-R02, DD-R04, DD-R05, DD-R06
> **REVISED 2026-11-03** (`/design-review`, lean, verdict NEEDS REVISION → revised in place, status In Review): F4 `weighted_pick` total bounded to the `randi_range` span (was 2^31−1 against a 65,536 span); rule 12a admits flagged diagnostic events (`command_rejected`, `ai_decision`) on the same log — answers match-rules' open question; rule 18 archives keyed by `run_id` (run-structure / meta-progression); rule 19 and AC-14 read Match Rules' actual `damage_dealt` fields (`source`, `dealt`); catalogue §D realigned to the owner GDDs' published names (`mulligan_resolved`, `weapon_destroyed`, `healed`, `enchantment_applied`, `trigger_resolved`; `treasure_granted` owner → Run Structure; Boss AI's four added types and `amount`); Card Effects draws directly (no per-effect fork); floor-retry edge case follows run-structure R8.3 (same streams at `draws = 0`, no `retry_<n>` fork); stale "not yet authored" dependency text removed; Tuning Knobs section added; AC-1/AC-3 made executable; Open Questions 2–3 closed.
> **REVISED 2026-11-03 (cross-review)**: C-09 — catalogue `draft_offered` / `draft_picked` rows carry `flags[]` and `option_index` (DD-X05, reward-draft D11); `run_ended.result` is `victory/defeat/abandoned` with `abandon_reason` (run-structure R6); Interactions table lists `treasure_granted` under Run Structure, matching the catalogue. C-05 — Open Question 8 closed (Match Rules adopts the F4 stream API and stream handles). Verified already in place: `ai_intent_committed` and `amount` on `ai_intent_shown` (V-43), `treasure_granted` owner = Run Structure (V-19), rule 18 keyed by `run_id` (V-21).
> **REVISED 2026-11-03 (re-review, `/design-review` lean)**: catalogue §D re-mirrored to the owner tables once more — `run_ended.abandon_reason` enum is Run Structure's (`player | data_version_mismatch | save_corrupt`, not `player/system`) and the row carries `floor_reached`, `ended_by`; `match_ended` row is the C14 `MatchResult` (`winner`, not `winner_side`; full `reason` enum incl. `event_cap`); `ai_intent_*` rows carry `effective_mode` (DD-X03, boss-ai C8.4); `discover_offered` / `discover_picked` carry Card Effects' `effect_id`, `kind`, label-key and `picked_index` fields; rows added for `deck_grew`, `run_warning` (Run Structure R10), `counter_changed` (Card Effects), `hook_install_skipped` (Treasures). Rule 13 states how `turn` is stamped (`set_turn(n)` by Match Rules); the `max_match_events` edge case names Match Rules as the emitter of the forced `match_ended`. Open Question 7 closed.
> **REVISED 2026-11-03 (housekeeping)**: §D `match_summary.result` defined as match-rules C14 `win | loss | fault` with `winner` and `reason` added; `draft_offered.flags[]` enum re-mirrored to reward-draft D11 (`pity_forced | coverage_forced | universal_forced | universal_missing | reoffer | short`); F7 `run_total_events` reported in the run log summary (Run Structure R10), not `run_ended`; rule 12a states explicitly that the player's own `command_rejected` events are diagnostic (`payload.diagnostic = true`).
> **REVISED 2026-11-03 (cross-review b)**: N-02 — §D `run_ended` row adopts Run Structure's nested `result` Dictionary (`result.outcome: victory | defeat | abandoned`, `result.abandon_reason`, …) with `run_seed_hex` beside it, matching run-structure R1/R6 and the path meta-progression F2 reads; the previous flat `result` enum would not have parsed in Meta's fold.
> **REVISED 2026-11-03 (DSL spike follow-up)**: §D adds `card_added_to_hand {side, instance_id, card_id, hand_size}`, mirroring the event match-rules C15 added for the `add_card_to_hand` primitive (DD-X04; `docs/architecture/spikes/2026-11-03-dsl-effect-spike.md` finding 2).

## Summary

RNG & Event Log is the determinism foundation of Deckdelve: one 64-bit run seed is split into named
streams (`run`, `match_<floor>`, `draft_<floor>`, `ai_<floor>`) that every rule draws from by
injection, and an append-only event log that records exactly one `{seq, turn, type, payload,
cause_seq}` event per state mutation. The player sees it as the seed on the run summary, the match
event feed and the damage-per-card table; the project relies on it for reproducible bug reports,
deterministic headless tests, and the Pillar 4 promise that any loss can be explained and any run
replayed from its seed.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None` (upstream); depended on by Match Rules, Card Effects, Boss AI, Run Structure, Reward Draft, Treasures, Match UI, Run UI, Meta Progression

## Overview

RNG & Event Log is the determinism layer every rule in Deckdelve sits on. The **RNG service** owns
one 64-bit run seed (DD-R09) and hands out *named streams* derived from it — `run`,
`match_<floor>`, `draft_<floor>`, `ai_<floor>` — so that boss order, shuffles, draft offers and AI
tie-breaks each draw from their own reproducible sequence and never from Godot's global RNG
(DD-T03). The **event log** is an append-only list of `{seq, turn, type, payload, cause_seq}`
records; every state mutation in match and run rules emits exactly one event, and the UI renders
only from those events (DD-T04). The player never operates this system directly: they see the seed
on the run summary, the event feed during a match and the per-card damage table at the end of a
run. It exists because Pillar 4 demands that any loss be explainable and any run reproducible from
its seed, and because the test suite's determinism rule (no random seeds, no global RNG) cannot be
enforced without a single injected source of randomness. Without it, bug reports are anecdotes and
boss AI is untestable.

> Deferred to architecture (→ becomes an ADR): whether the service is an injected `RefCounted`
> (DD-T02 says so) or an autoload; where `log_schema_version` lives in the profile save format.

## Detailed Design

### Core Rules

**A. Seeds and streams**

1. A run has exactly one `run_seed`: a 64-bit integer fixed at `run_started` and never changed.
   It is shown as 16 uppercase hex digits (unsigned view) on the run summary and death/victory
   screens (DD-R09) and may be typed into hero select to replay a run.
2. The RNG service is created with `(run_seed, data_version)` and exposes `stream(name)`. A stream
   is a generator seeded by `stream_seed(run_seed, name)` (F2). Streams are memoised: calling
   `stream("match_3")` twice in one run returns the same object with its draw position intact.
3. Stream names match `^[a-z]+(_[0-9]+)?(/[a-z0-9_]+)*$`. v1 names and owners:

   | Stream | Owner | Used for |
   |---|---|---|
   | `run` | Run Structure | Boss sequence from the banded pool (DD-R01, DD-R02), floor layout |
   | `match_<floor>` | Match Rules, Card Effects | Deck shuffles, random targets, Discover offers |
   | `draft_<floor>` | Reward Draft | Bundle offers (DD-R04), treasure offers (DD-R05), pity rolls |
   | `ai_<floor>` | Boss AI | Tie-breaks between equally scored plays and attacks (live draws); forks `sim_<turn>` / `forecast_<turn>` for sandbox and forecast simulation (Boss AI C9 — each new fork label costs one parent draw, rule 5) |

   `<floor>` is 1–8. A consumer draws only from streams it owns; an owner may pass a fork to a
   callee (rule 5). Ownership is enforced by code review, not at runtime.

   **`stream(name)` takes root names only**, `^[a-z]+(_[0-9]+)?$` (`run`, `match_3`, `draft_2`,
   `ai_1`); the full pattern above, with `/<label>` segments, names forks, and a `/` name comes
   only from `fork(label)` (rule 5). `stream("ai_1/x")` is refused — no stream is created, the
   same treatment as `fork("a/b")` — because it would carry the name of `stream("ai_1").fork("x")`
   under a different seed (F2 instead of F3) and a snapshot keyed by name could not tell them apart
   (code review 2026-11-03, a determinism hazard).
4. The draw API on a stream is exactly `randi_range(lo, hi)` (inclusive), `randf()`
   (`[0, 1)`, weight normalisation only — rules never compare floats for equality),
   `shuffle(array)` (in place), `weighted_pick(weights)` and `fork(label)` — all defined in F4.
   Every call advances the stream's `draws` counter by the generator outputs it consumed.
5. `fork(label)` consumes one draw from the parent and returns a memoised stream named
   `<parent>/<label>` seeded by F3. Forks let a sub-system (a Discover effect, a floor retry) own
   a stream without knowing the parent's draw order; a fork is as deterministic as its parent.
6. The generator behind a stream is Godot 4.7's `RandomNumberGenerator`, one instance per stream,
   `seed` set once from the stream seed. NOT SOURCEABLE: `docs/engine-reference/godot/` has no
   Core module page and does not mention `RandomNumberGenerator`; the implementer verifies the
   seed setter and 64-bit integer wraparound on 4.7.2 (Open Question 1). The design depends only
   on "same seed, same sequence within one engine version" (rule 9), not on the algorithm.

**B. Determinism contract**

7. No code under the rules tree calls `randi`, `randf`, `randi_range`, `randomize`,
   `Array.shuffle`, `Array.pick_random` or any other global-RNG function. Randomness arrives only
   as an injected stream parameter (`.claude/rules/gameplay-code.md`: injection over singletons;
   coding-standards determinism rule). Every rules test constructs its own service with a literal
   seed.
8. Draws happen only while a command is being processed (player command, AI command, or a
   run-phase command such as "enter floor") — never in constructors, UI or idle frames. Within a
   command, draw order is the order the rules resolve mutations (DD-M11), which is fixed; each
   stream's owner GDD documents its draw order.
9. **Replay equivalence** (F6): two executions with the same `run_seed`, hero, `data_version`,
   engine version and command sequence produce byte-identical event logs. The guarantee is per
   command sequence, not per seed: if the player plays differently, the boss's later AI decisions
   follow the new board state and are not expected to match the original run (DD-R09 limit).
10. `snapshot()` returns `{run_seed, data_version, streams: {name: draws}, fork_points: {fork name: parent draws when it was forked}}` in memory, and its persisted form (`snapshot_to_json_dict()`) carries `run_seed_hex` (64-bit values are hex strings in every persisted form — ADR-0003, 2026-11-03). `fork_points` lets `restore()` rebuild each fork with its original seed by replaying `stream(parent).fork(label)` at that parent draw count (added 2026-11-03, rng-event-log story 003); `restore(snapshot)`
    rebuilds each stream by reseeding and discarding `draws` outputs (F5). This is how a saved run
    (DD-R08) resumes mid-sequence without storing engine internals.

**C. Event log**

11. An event is `{seq: int, turn: int, type: StringName, payload: Dictionary, cause_seq: int}`.
    `seq` starts at 1 and increases by exactly 1 per append (F7). `turn` is the match turn at
    emission (0 during mulligan; run-scope events use 0 and carry `floor` in the payload).
    `cause_seq` is the `seq` of the event whose resolution emitted this one, or 0 for the direct
    result of a command.
12. Every state mutation in Match Rules, Card Effects, Boss AI (intent only), Run Structure, Reward
    Draft and Treasures emits exactly one event (DD-T04), after the mutation is applied and before
    the next begins. A mutation emitting zero or two events is a rules bug.
12a. **Diagnostic events.** An event that records no mutation — Match Rules' `command_rejected`
    (the **player's** rejected commands included, per Match UI's request: match-ui U3 rule 4a
    filters them from the feed and shows the shake/tooltip instead), Boss AI's `ai_decision`,
    `ai_plan_aborted`, `ai_fault` — is appended to the **same** log
    with `payload.diagnostic = true`; there is no second channel. It takes the next `seq`, may be
    a `cause_seq` target, counts toward `max_match_events` and is compared by F6 (a rejected
    command is part of `commands[]`, and Boss AI is a pure function of state and stream, so both
    are deterministic). Rationale: one log is the bug report (Pillar 4); a filter is a UI concern.
    Match UI hides `diagnostic` events from the feed unless a debug flag is set.
13. The log is append-only: `append(type, payload, cause_seq)` is the only writer; no edit, no
    remove. The log stamps `seq` and `turn` (match-rules C15): `turn` is the log's `current_turn`,
    which Match Rules sets through `set_turn(n)` immediately before appending `turn_started`; it
    is 0 before the first call and on run-scope logs. `subscribe(callback)` delivers each event once, in `seq` order, after it is appended;
    `events_since(seq)` returns every event with a greater `seq`; `snapshot()` returns the metadata
    block plus the full array.
14. Payload values are JSON-representable only: `int`, `float`, `bool`, `String`, `StringName`
    (serialised as `String`), `null`, and `Array`/`Dictionary` of those. Entities are referenced by
    id — `instance_id` (int, unique per match, assigned by Match Rules to minions, weapons and both
    heroes) and `card_id` (String, Card Database) — never by object.
15. A match log is **sealed** by `match_ended`, a run log by `run_ended`. Appending to a sealed
    log is an error (asserted in debug; dropped with a console warning in release).
16. Size bounds (F7): a typical match emits under 2,000 events and a run under 20,000.
    `max_match_events` (derived from the data-file knob `log_memory_budget_bytes`; 10,000 at
    defaults) is a hard cap; reaching it is a rules fault (Edge Cases).

**D. Event type catalogue v1**

Envelope fields omitted. `side` ∈ {`player`, `boss`}; `*_id` fields follow rule 14. Owner is the
system whose mutation emits the event; this GDD owns only the envelope, `log_overflow` and
`match_summary`. **The owner GDD's own table is authoritative for its names and payloads**
(match-rules C15, card-effects `effect_resolved`, boss-ai C10, reward-draft D11); the rows below
are the cross-system index and were realigned to those tables on 2026-11-03. Match Rules emits
further events not indexed here (`deck_shuffled`, `turn_reset`, `phase_changed`, `crystal_gained`,
`mana_spent`, `spell_cast`, `card_to_graveyard`, `summon_failed`, `weapon_durability_changed`,
`attack_resolved`, `divine_shield_popped`, `armor_*`, `frozen`/`thawed`, `silenced`,
`stealth_lost`, `auras_recomputed`, `trigger_queued`, `choice_requested`/`choice_made`,
`resolution_overflow`); all obey rules 11–14.

| Type | Owner | Payload fields |
|---|---|---|
| `match_started` | Match Rules | `floor, hero_id, boss_id, player_deck_size, boss_deck_size` |
| `mulligan_offered` / `mulligan_resolved` | Match Rules | `side, instance_ids[]` / `side, replaced_instance_ids[]` |
| `turn_started` / `turn_ended` | Match Rules | `turn, side, mana_max, mana_available` / `turn, side` |
| `mana_refilled` / `mana_added` | Match Rules | `side, mana_available, mana_max` (match-rules C15 splits the former `mana_changed` into `crystal_gained`, `mana_refilled`, `mana_spent`, `mana_added`) |
| `command_rejected` | Match Rules | `side, command, code` + `diagnostic: true` (rule 12a) |
| `card_drawn` | Match Rules | `side, instance_id, card_id, hand_size` |
| `card_burned` | Match Rules | `side, instance_id, card_id` (DD-M06) |
| `card_added_to_hand` | Match Rules | `side, instance_id, card_id, hand_size` (match-rules C15, added 2026-11-03 from the DSL spike; the `add_card_to_hand` primitive — Discover pick, `add_to_hand`, `copy_to_hand`; a full hand emits `card_burned` instead) |
| `fatigue_damage` | Match Rules | `side, amount` (DD-M07; followed by `damage_dealt`) |
| `card_played` | Match Rules | `side, instance_id, card_id, cost_paid, target_id, board_index` |
| `minion_summoned` | Match Rules | `side, instance_id, card_id, board_index, attack, health, keywords[]` |
| `weapon_equipped` / `weapon_destroyed` | Match Rules | `side, instance_id, card_id, attack, durability` / `side, instance_id` |
| `hero_power_used` | Match Rules | `side, power_id, target_id` (DD-M13) |
| `attack_declared` / `attack_resolved` | Match Rules | `attacker_id, defender_id` / `attacker_id, defender_id` |
| `damage_dealt` | Match Rules | `source, target, requested, prevented, armor_absorbed, dealt, health_after` (match-rules C15; rule 19 reads `source` and `dealt`) |
| `healed` | Match Rules | `source, target, amount, health_after` |
| `enchantment_applied` / `enchantment_removed` | Match Rules (primitive; Card Effects and Treasures cause it) | `instance_id, attack, health, max_health, keywords_added[], keywords_removed[], reason` |
| `minion_died` | Match Rules | `instance_id, card_id, side, board_index` (order per DD-M11) |
| `trigger_resolved` | Match Rules | `instance_id, card_id, effect_id, trigger` (covers Deathrattle; the former `deathrattle_triggered`) |
| `effect_resolved` | Card Effects | `effect_id, host_id, host_kind, source_id, owner, trigger, depth, fizzled, ops[]` — extension point; card-effects owns the shape |
| `discover_offered` / `discover_picked` | Card Effects | `side, source_id, effect_id, kind (discover/choose_one), option_card_ids[] | option_label_keys[]` / `side, picked_index, picked_card_id | picked_label_key` (card-effects Interactions payload block; Match Rules' `choice_requested` / `choice_made` wrap the pause/resume, all under one `cause_seq` — DD-X04) |
| `counter_changed` | Card Effects | `source_id, key, value` (card-effects C6.5 per-source counters; Match UI badges) |
| `hook_install_skipped` | Treasures | `host_id, reason (duplicate)` (treasures T3; emitted through the resolver at `begin_match`) |
| `ai_intent_shown` / `ai_intent_committed` | Boss AI | `boss_id, intent_key, target_id, amount, effective_mode` / `intent_key, target_id, amount, kept, effective_mode` (boss-ai C8.4; `effective_mode = min(boss.intent_mode, settings.telegraph_mode)`, DD-X03 — Match UI renders exactly what is emitted) |
| `ai_decision` / `ai_plan_aborted` / `ai_fault` | Boss AI | per boss-ai C10; all `diagnostic: true` (rule 12a) |
| `match_ended` | Match Rules | the C14 `MatchResult`: `result (win/loss/fault, from the player's side), winner (PLAYER/BOSS/null), reason (hero_dead/both_dead/concede/turn_cap/resolution_overflow/event_cap), floor, turns, turns_per_side, player stats, boss stats, final hero health both sides` (match-rules C14; DD-M12) |
| `log_overflow` | this system | `cap, seq` |
| `run_started` | Run Structure | `run_seed_hex, hero_id, data_version, log_schema_version, boss_ids[]` |
| `run_floor_entered` | Run Structure | `floor, band, boss_id` |
| `match_summary` | this system | `floor, result (win \| loss \| fault — match-rules C14 `MatchResult.result`), winner (PLAYER \| BOSS \| null on fault), reason (the C14 `MatchResult.reason` enum), turns, event_count, cards_played, damage_by_card{card_id: int}` |
| `draft_offered` / `draft_picked` | Reward Draft | `floor, kind (bundle/treasure), option_ids[] (1–3, id-sorted), flags[] ⊆ {pity_forced \| coverage_forced \| universal_forced \| universal_missing \| reoffer \| short}` (reward-draft D11) / `floor, kind, picked_id, option_index, card_ids_added[]` (reward-draft D11, DD-X05: `Offer{option_ids[], flags[]}` on events; `offered_ids[]` only inside the persisted DraftRecord) |
| `treasure_granted` | Run Structure | `floor, treasure_id` (the append is Run Structure's mutation, R5.4; offered by Reward Draft, applied by Treasures) |
| `match_faulted` / `run_resumed` | Run Structure | `floor, attempt` / `floor, phase, attempt` |
| `run_saved` | Run Structure | `floor, phase` (DD-R08) |
| `run_ended` | Run Structure | `result {outcome: victory \| defeat \| abandoned, abandon_reason: player \| data_version_mismatch \| save_corrupt \| null (only player counts as a loss, R6), floor_reached, ended_by, floors_cleared, total_turns}, run_seed_hex` (run-structure R1/R6 result record; meta-progression F2 reads `result.outcome`) |
| `deck_grew` | Run Structure | `floor, card_ids_added[], deck_size` (R10; the append is Run Structure's mutation after a bundle `draft_picked`) |
| `run_warning` | Run Structure | `code, detail{}` (R10; codes raised by Reward Draft D8 and Treasures); records no mutation, so rule 12a applies (`diagnostic: true`) |

Extension rule: an owner GDD adds new types in its own catalogue table; names are `snake_case`
past tense (`project.yaml` naming: signals past tense) and payloads obey rule 14. Card Effects
puts operation-specific detail inside `effect_resolved.values`, adding a top-level type only when
the UI needs a distinct animation hook.

**E. Serialization and the run log**

17. `to_json()` produces `{log_schema_version, engine_version, data_version, run_seed_hex, scope
    (match/run), floor, events[]}` — the bug-report attachment and the replay input. `from_json()`
    rebuilds a log for the replay viewer and for tests.
18. The run log holds run-scope events plus one `match_summary` per match. The full match log is
    kept in memory for the current match only; on `match_ended` it is reduced to a summary and the
    raw log is written to `user://logs/<run_id>/floor_<n>_attempt_<k>.json` when `keep_match_logs`
    (data file; default true in debug builds, false in release) is set. `run_id` is Run
    Structure's `<run_seed_hex>-<started_at>` so a replayed seed never overwrites an archive
    (run-structure R8, meta-progression M8.2); `k` is `match_attempts[floor]`.
19. `damage_by_card` is computed by this system from `damage_dealt` events using Match Rules'
    C15 payload (`source`, `target`, `requested`, `prevented`, `armor_absorbed`, `dealt`,
    `health_after`): for each event whose `source` is an instance owned by the player, add
    `dealt` (damage actually applied, after prevention and armour) under that instance's
    `card_id`, resolved through the `instance_id → card_id` map built from `minion_summoned`,
    `weapon_equipped`, `card_played` and `hero_power_used`. Hero power and weapon damage
    attribute to the power's or weapon's `card_id`; fatigue to nothing.

### States and Transitions

| Object | State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|---|
| Stream | `Unrequested` | Service created | First `stream(name)` or `fork(label)` | Does not exist; no memory cost |
| Stream | `Fresh` | Derived from seed, `draws = 0` | First draw call | Seeded; `snapshot()` records `draws: 0` |
| Stream | `Consumed` | `draws > 0` | Run ends (service discarded) | Each call advances `draws`; `restore` recreates this state by skipping |
| Match log | `Open` | `match_started` appended | `match_ended` appended | Accepts `append`; notifies subscribers |
| Match log | `Faulted` | `log_overflow` appended | Forced `match_ended(result: fault)` | Accepts exactly one more event |
| Match log | `Sealed` | `match_ended` appended | Reduced to `match_summary` | Read-only; `to_json()` allowed; `append` is an error |
| Run log | `Open` | `run_started` appended | `run_ended` appended | Accepts run-scope events and `match_summary` |
| Run log | `Sealed` | `run_ended` appended | Handed to Meta Progression | Read-only; persisted with the profile |

Valid transitions: `Unrequested → Fresh → Consumed`; `Open → Sealed`; `Open → Faulted → Sealed`.
Nothing returns to `Open`: a resumed run (DD-R08) opens a new match log and restores stream
positions from the snapshot rather than reopening a sealed log.

### Interactions with Other Systems

| System | Data in (to this system) | Data out (from this system) | Interface owner |
|---|---|---|---|
| Match Rules | `append` for every match mutation; `instance_id` assignment | `stream("match_<floor>")`; `seq` values for `cause_seq` chaining | This GDD owns envelope and API; Match Rules owns its payload fields |
| Card Effects | `effect_resolved`, `discover_offered` / `discover_picked`, `counter_changed`; nested emissions (`trigger_resolved`, `enchantment_*` are Match Rules primitives it causes) | The engine's `match_<floor>` stream, drawn **directly** in resolution order (card-effects C6.9 — no per-effect fork in v1); `cause_seq` of the triggering event | Card Effects owns the `effect_resolved` shape |
| Boss AI | `ai_intent_shown`, `ai_intent_committed` (intent) and `ai_decision`, `ai_plan_aborted`, `ai_fault` (diagnostic, rule 12a) — AI reads state, it does not mutate it | `stream("ai_<floor>")` for tie-breaks; `fork("sim_<turn>")` / `fork("forecast_<turn>")` for sandboxes; the AI must be a pure function of (state, stream) | Boss AI documents its draw order (C9) |
| Run Structure | `run_started`, `run_floor_entered`, `run_saved`, `treasure_granted` (R5.4), `deck_grew`, `run_warning`, `match_faulted`, `run_resumed`, `run_ended` (R10 catalogue); `run_seed` at creation; `restore(snapshot)` on resume | `stream("run")`; `snapshot()` for save files (DD-R08); the run log instance | Run Structure owns run phase order |
| Reward Draft | `draft_offered`, `draft_picked` (`Offer{option_ids[], flags[]}`, DD-X05) | `stream("draft_<floor>")` for offers and pity rolls | Reward Draft owns offer payloads |
| Treasures | Hooks emit `effect_resolved` with `source_id` = treasure; `hook_install_skipped` at `begin_match` | `cause_seq` so a treasure-caused mutation is attributable | Treasures owns hook naming and its two event types |
| Match UI | `subscribe(callback)`; `events_since(seq)` after a scene reload | Every match event in `seq` order; UI must not render boss `card_drawn.card_id` while the card is in hand (hidden information is logged for replay, not display) | UI is display-only (`src/ui/**`) |
| Run UI | `events_since` on the run log; `match_summary.damage_by_card` | Run summary data; `run_seed_hex` for display and copy | Run UI |
| Meta Progression | Sealed run log (`to_json()`) at `run_ended` | Nothing — it stores and aggregates, never reopens a log | Meta Progression owns profile schema and `log_schema_version` migration |
| Content / balance tooling | Archived logs under `user://logs/` | JSON for `/balance-check` (pick rates from `draft_picked`, damage per card) | Tooling reads only |

## Formulas

All arithmetic is unsigned 64-bit modulo 2^64; `>>>` is a logical shift. GDScript's `int` is
signed, so an implementation writes the constants as signed equivalents and masks after shifts —
NOT SOURCEABLE against `docs/engine-reference/godot/`; verify wraparound on 4.7.2 (Open Question
1). The only data-file knob here is `log_memory_budget_bytes` (F7); nothing else is a balance value.

### F1 — Run seed from player input

The `run_seed` formula is defined as:

```
run_seed = entropy_u64()                 if trim(input) == ""
         = parse_hex_u64(input)          if input matches ^(0x)?[0-9A-Fa-f]{16}$
         = parse_i64(input) mod 2^64     if input matches ^-?[0-9]{1,19}$
         = fnv1a64(utf8(input))          otherwise
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| input | String | any, trimmed | player (hero select) or empty | Seed field contents |
| run_seed | int | 0 – 2^64−1 (stored signed) | calculated | The run's single seed; displayed as 16 hex digits |

**Output Range:** the full 64-bit space; every input maps to one seed and the displayed hex
re-parses to the same bits.
**Example:** `"42"` → `000000000000002A`; `"-1"` → `FFFFFFFFFFFFFFFF`; `"deckdelve"` →
`48A10CC0B2ED54EC`.

### F2 / F3 — Stream seed and fork seed

The `stream_seed` formula is defined as:

```
stream_seed(run_seed, name) = mix64( fnv1a64( le_bytes8(run_seed) ++ utf8(name) ) )
fork_seed(parent, label)    = mix64( fnv1a64( le_bytes8(parent.randi32()) ++ utf8(parent.name + "/" + label) ) )

fnv1a64(bytes): h = 0xCBF29CE484222325; for each byte b: h = (h XOR b) × 0x00000100000001B3
mix64(x):       z = (x XOR (x >>> 30)) × 0xBF58476D1CE4E5B9
                z = (z XOR (z >>> 27)) × 0x94D049BB133111EB
                return z XOR (z >>> 31)
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| run_seed | int | 0 – 2^64−1 | F1 | Run seed, little-endian 8 bytes |
| name | String | rule 3 regex | constant per owner | Stream name, UTF-8 |
| parent.randi32() | int | 0 – 2^32−1 | calculated | One draw from the parent (consumed) |
| label | String | `[a-z0-9_]+` | constant per caller | Fork label |
| stream_seed | int | 0 – 2^64−1 | calculated | Seed given to the stream's generator |

**Output Range:** full 64-bit space. FNV-1a digests (seed, name) deterministically; the SplitMix64
finaliser adds avalanche so `match_1` and `match_2` share no bit pattern.
**Example:** `run_seed = 42`: `fnv1a64(le8(42) ++ "run") = D2063F87976A8AC8` → `mix64` →
`60FB31FFA0FECE9A`; `match_1 → 8E28D71DC7508C82`; `match_2 → 3FC25FB4D7E5C7F5`;
`draft_1 → FFC74EA120AA040F`; `ai_1 → 89527D2C36D9A252`. `run_seed = 0`: `run → 8AE616A7F56EA560`.

### F4 — Draw primitives

Every API call is defined over `randi32()`, one 32-bit output of the stream's generator, so the
`draws` counter is exact and engine-independent:

```
randi_range(lo, hi) = lo + (randi32() mod (hi − lo + 1))                               1 draw
randf()             = randi32() / 2^32                                                  1 draw
shuffle(a)          : for i = n−1 down to 1: j = randi_range(0, i); swap a[i], a[j]     n−1 draws
weighted_pick(w)    : total = Σ w; r = randi_range(0, total − 1);
                      return smallest i with (w[0] + … + w[i]) > r                      1 draw
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| lo, hi | int | `hi − lo + 1 ≤ 65,536` (asserted in debug) | caller | Inclusive bounds; modulo bias < 2^−16 at this span |
| a | Array | length 0 – 1,000 | caller | Shuffled in place (decks are ≤ 36 cards, DD-R06) |
| w | Array[int] | each ≥ 0, total 1 – 65,536 | caller (data-file weights) | Weights; the total is a `randi_range` span so it shares that bound; total 0 or > 65,536 is an error (Edge Cases). Reward Draft keeps bundle totals well inside this (its D5/F1) |
| draws | int | 0 – ~10,000 per stream per run | calculated | Count of `randi32()` calls, recorded in `snapshot()` |

**Output Range:** `randi_range` ∈ [lo, hi]; `weighted_pick` ∈ [0, len(w)−1].
**Example (algorithmic trace, draws hypothetical):** `shuffle([A,B,C,D])` with draws giving
`j = 1, 0, 1` → `[A,D,C,B]` → `[C,D,A,B]` → `[C,D,A,B]`; 3 draws. `weighted_pick([5, 0, 15])`
with `r = 7` → cumulative `5, 5, 20` → index 2.

### F5 — Restore

```
restore(stream, draws): generator.seed = stream_seed; repeat draws times: randi32()
```

`draws` as in F4; cost O(draws), under 5 ms at 10,000 in GDScript (the AC budget). An implementation may copy the
generator's internal state instead if 4.7.2 exposes it, provided a test shows both methods yield
identical next outputs (NOT SOURCEABLE — Open Question 1).

### F6 — Replay equivalence

```
replay_equal(A, B) ⇔ canonical_json(A.events) == canonical_json(B.events)
given equal (run_seed, hero_id, data_version, engine_version, commands[])
canonical_json: keys sorted, floats printed with 6 decimals, StringName as String
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| commands[] | Array | ≤ ~2,000 per run | player and run phases | Ordered player and run-phase commands; AI commands are derived, not inputs |
| events | Array | per F7 | event log | Fields `seq, turn, type, payload, cause_seq` only |

**Output:** boolean. The test suite's determinism rule is this predicate applied to two runs of the
same test. It says nothing about runs with different `commands[]` (DD-R09 limit).

### F7 — Sequence and size bounds

```
seq(n) = n   for the n-th appended event;   cause_seq(n) ∈ [0, n−1]
max_match_events = floor(log_memory_budget_bytes / avg_event_bytes)
run_total_events = Σ_floors match.event_count + run_scope_events
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| log_memory_budget_bytes | int | 500,000 – 20,000,000 | data file (default 2,000,000) | In-memory budget for the open match log; the one tuning knob |
| avg_event_bytes | int | 100 – 400 | constant (200, estimate) | Mean serialised event size; re-measure once real logs exist |
| max_match_events | int | 2,500 – 100,000 | calculated (10,000 at defaults) | Hard cap; hit ⇒ `log_overflow` |
| run_total_events | int | typical 3,000 – 20,000 | calculated | Reported in the run log summary (Run Structure R10); not capped |

**Output Range:** a 20-turn match emits 300 – 2,000 events (~60 – 400 KB); eight matches plus
~40 run events stay under 20,000. At the minimum budget the cap (2,500) still exceeds a typical
match. **Example:** defaults → `floor(2,000,000 / 200) = 10,000`.

## Edge Cases

**Seeds**

- **If the run seed is 0**: valid. Streams pass through F2, so zero still yields well-mixed stream
  seeds; the summary shows `0000000000000000`.
- **If the player types a negative decimal seed** (`-1`): taken as the two's-complement 64-bit
  pattern and displayed as unsigned hex (`FFFFFFFFFFFFFFFF`); re-entering the hex reproduces the
  run. Rationale: Godot's `int` is signed; the player-facing form is unsigned so equal bits never
  display differently.
- **If the seed field holds a non-numeric string**: the seed is `fnv1a64(utf8(string))` (F1) and
  the summary shows the resulting hex, not the string.
- **If the seed field is empty**: one draw from OS entropy — the only permitted global-RNG call in
  the project, made in Run Structure's run-creation command, not in rules code.

**Streams**

- **If the same stream name is requested twice in one run**: the same memoised stream is returned,
  position intact. A fresh sequence requires `fork` with a new label.
- **If `fork(label)` is called twice with the same label**: the first call consumes one parent draw
  and creates the fork; later calls return it and consume nothing. Rationale: idempotence keeps
  draw counts stable under retries.
- **If a floor must be replayed** (rules fault below, or resume after a quit mid-match): Run
  Structure owns the policy (R8.3): the retry restores the pre-match snapshot, so `match_<floor>`
  and `ai_<floor>` start again at `draws = 0` and the opening is identical. No `retry_<n>` fork —
  a fresh sequence per attempt would let a player quit until an opening suits them (DD-R09).
  `match_attempts[floor]` makes the information leak visible.
- **If `randi_range(lo, hi)` has `lo > hi` or a span above 65,536**: assert in debug; return `lo`
  in release without a draw. Never swap silently — a swapped range hides a caller bug.
- **If `weighted_pick` receives an empty array, a negative weight, a total of 0 or a total above
  65,536**: assert in debug; return `-1` in release without a draw. Callers (Reward Draft) must
  guarantee a positive in-range total; this system invents no fallback pick.
- **If `shuffle` receives 0 or 1 elements**: no draws are consumed (F4). Draw counts are part of
  the determinism contract, so this is stated rather than left to the algorithm.
- **If a snapshot is requested mid-command**: refused (error return). DD-R08 saves only after a
  match or a draft, so a draw sequence is never split across a save.
- **If the engine version differs between record and replay**: replay is attempted only when
  `engine_version` matches; otherwise the log is shown read-only, labelled "not replayable (engine
  changed)". Rationale: rule 6 guarantees the sequence only within one engine version.

**Events**

- **If an event is emitted during another event's resolution** (deathrattle chains, DD-M11): it
  takes the next `seq` with `cause_seq` = the outer event's `seq`. Rule 12 appends the outer event
  before resolution begins, so `cause_seq < seq` always. Example: `minion_died` (40) →
  `trigger_resolved` (41, cause 40) → `effect_resolved` (42, cause 41) → `damage_dealt`
  (43, cause 42) → `minion_died` (44, cause 43).
- **If a subscriber callback calls `append`**: assert in debug; in release the append is accepted
  and tagged `payload._reentrant: true`. Rules code never subscribes, so this only ever marks a
  display-layer bug.
- **If the match log reaches `max_match_events`**: the log appends `log_overflow{cap, seq}` and
  accepts exactly one more event; Match Rules stops its resolution loop and emits
  `match_ended{result: fault, winner: null, reason: event_cap}` as that event (match-rules Edge
  Cases) — the log never fabricates a Match Rules event; the log goes `Faulted → Sealed` and is
  written to `user://logs/faults/<run_id>_floor_<n>_attempt_<k>.json` regardless of
  `keep_match_logs`. This system does **not** end the run; Run Structure emits `match_faulted`,
  returns to `pre_match` and the floor is not lost (run-structure R5). Rationale: the first line
  of defence is Match Rules' `RESOLUTION_STEP_CAP` (1,000 steps → `resolution_overflow`, boss
  wins) plus Card Effects' static `EFFECT_STATIC_STEP_LIMIT` (250); card-effects F6 shows the
  event cap cannot be reached before the step cap at default knobs, so a `log_overflow` means a
  knob was lowered or a primitive emits more than ~3 events per step — a rules bug, and Pillar 3
  says the player should not pay for one.
- **If a payload holds a non-JSON value** (Object, Callable, Vector2, Color…): assert in debug; in
  release the value becomes the String `"<unserializable:ClassName>"` and the key is listed in
  `payload._coerced[]`. Rationale: a bug report must still serialise.
- **If a payload holds a float**: serialised with 6 decimal places so two logs of one run compare
  byte-equal (F6). Gameplay quantities are ints; floats appear only where a GDD allows them.
- **If `events_since(seq)` is called with `seq` ≥ the last `seq`**: empty array; with `seq < 0`,
  every event. Neither is an error.

**Persistence**

- **If a profile's run logs carry an older `log_schema_version`**: Meta Progression migrates them
  before this system reads them; this system never reads a schema it does not match.
- **If a run log carries a newer `log_schema_version`** (profile from a newer build): kept opaque —
  the run-log screen shows date, hero, result and seed from the profile index plus "details
  unavailable"; the log is never rewritten or discarded.
- **If a saved in-progress run has a different `data_version` than the installed data**:
  `restore(snapshot)` returns an error and Run Structure ends the run as `abandoned`, no loss
  recorded (provisional). Rationale: the saved stream positions no longer correspond to the same
  decks and offers; resuming would be a different run wearing the old seed.
- **If a finished run log has a different `data_version`**: the summary is displayed; replay is
  disabled and the log is flagged `replayable: false`.

## Dependencies

This system has **no upstream dependencies** — it reads no card data and no save file; `card_id`
strings pass through payloads opaquely. Every row below is a downstream dependent. All of these
GDDs now exist and each restates the interface in its own Dependencies section; where a sibling
refined a provisional interface (Card Effects' direct draws, Run Structure's retry policy and
`run_id`, Boss AI's event set, Match Rules' event names) this GDD was realigned on 2026-11-03.

| System | Direction | Hard/Soft | Nature of Dependency |
|---|---|---|---|
| Match Rules | Match Rules depends on this | Hard | Injected `match_<floor>` stream; emits every match event; assigns `instance_id` |
| Card Effects | Card Effects depends on this | Hard | Draws directly from the engine's `match_<floor>` stream (F4 draw counts); emits `effect_resolved` and Discover events; relies on `cause_seq` nesting |
| Boss AI | Boss AI depends on this | Hard | Injected `ai_<floor>` stream for tie-breaks and forks for simulation; emits intent events and `diagnostic` decision events (rule 12a); AI-vs-AI simulation harness uses fixed seeds |
| Run Structure | Run Structure depends on this | Hard | Creates the service with `run_seed`; `run` stream for the boss sequence; `snapshot()`/`restore()` for save and resume (DD-R08); owns the run log lifecycle |
| Reward Draft | Reward Draft depends on this | Hard | Injected `draft_<floor>` stream for offers and pity rolls; emits draft and treasure events |
| Treasures | Treasures depends on this | Soft | Hooks emit `effect_resolved` attributable through `cause_seq`; works without the log but is then invisible to the player |
| Match UI | Match UI depends on this | Hard | `subscribe` / `events_since` are its only data source (DD-T04); hidden-information filter on boss `card_drawn` |
| Run UI | Run UI depends on this | Hard | `match_summary` for the summary screen; `run_seed_hex` display and seed-entry field |
| Meta Progression | Meta Progression depends on this | Soft | Stores sealed run logs with the profile; owns `log_schema_version` migration; works without logs (unlocks only) |
| Content / balance tooling | Tooling depends on this | Soft | `/balance-check` reads archived JSON logs for pick rates and damage per card |

**Bidirectional check** (`.claude/rules/design-docs.md`): `design/gdd/systems-index.md` lists RNG
& Event Log under *Depends On* for Match Rules, Card Effects, Boss AI, Run Structure, Reward
Draft, Treasures, Meta Progression, Match UI and Run UI — every dependent above (checked
2026-11-03). Each of those GDDs names this system in its own Dependencies table; Card Database
and Content correctly list "none".

## Tuning Knobs

The system has no balance values; these are engineering budgets, all read from `assets/data/`
(DD-T01) and none hardcoded.

| Knob | Default | Safe range | Affects | Out of range |
|---|---|---|---|---|
| `log_memory_budget_bytes` | 2,000,000 | 500,000 – 20,000,000 | `max_match_events` (F7) and so when a runaway match faults; peak memory of the open log | Below: a legitimate long match can fault (cap 2,500 < worst-case ~3,000 at the step cap); above: memory only |
| `avg_event_bytes` | 200 (constant, estimate) | 100 – 400 | Converts the byte budget to an event cap | Re-measure from real logs before changing |
| `keep_match_logs` | debug `true`, release `false` | boolean | Whether full match logs are archived under `user://logs/` for `/balance-check` and bug reports | Release `true` costs ~60–400 KB per match on disk (Open Question 5) |
| `randi_range` span / `weighted_pick` total | 65,536 (fixed) | not tunable | Modulo bias bound (F4) | Raising it is a formula change, not a knob |

## Visual/Audio Requirements

N/A — Core/Foundation system with no feedback of its own. Every catalogue event is a *hook* for
Match UI and Run UI feedback; those GDDs own the per-event visual and audio tables.

## Game Feel

N/A — the player never operates this system. Feel targets for the event feed (scroll pacing,
batching of nested events) belong to Match UI.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|---|---|---|---|
| Run seed (16 hex digits, copyable) | Run summary, death and victory screens (Run UI) | Once per screen | Always (DD-R09) |
| Seed entry field | Hero select (Run UI) | On input | Optional; empty → random seed |
| Event feed (one readable line per event) | Match UI side panel | Per event, in `seq` order | Always; boss hand contents hidden until played |
| Damage per card, turns, result | Run summary (Run UI) | Once per run | From `match_summary` events |
| "Not replayable (data/engine changed)" label | Run log screen (Run UI) | On load | `replayable == false` |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|---|---|---|---|
| One seeded service, named streams, injected seeds | `design/design-decisions.md` | DD-T03 | Rule dependency |
| Append-only `{seq, type, payload}`, one event per mutation, UI renders from events | `design/design-decisions.md` | DD-T04 (this GDD extends the envelope with `turn`, `cause_seq`) | Rule dependency |
| 64-bit seed shown to the player; reproduces sequence and offers, not AI after divergence | `design/design-decisions.md` | DD-R09 | Rule dependency |
| Save after every match and draft; snapshot only between commands | `design/design-decisions.md` | DD-R08 | State trigger |
| Death resolution order fixes nested event order; event names and payloads | `design/gdd/match-rules.md` | DD-M11 death and trigger ordering; C15 event vocabulary | Rule dependency |
| `match_ended` result and double-zero rule; `RESOLUTION_STEP_CAP` | `design/gdd/match-rules.md` | DD-M12 win/loss; `resolution_overflow` | State trigger |
| Step caps as first defence against `log_overflow`; direct draws | `design/gdd/card-effects.md` | C6.9 randomness, C6.10 bounds, F6 | Rule dependency |
| Boss sequence drawn from `run`; retry policy on fault; `run_id` | `design/gdd/run-structure.md` | R5, R8.3, DD-R01/DD-R02 | Ownership handoff |
| Offers drawn from `draft_<floor>` with integer weights | `design/gdd/reward-draft.md` | D5–D6, DD-R04/DD-R05 | Ownership handoff |
| `log_schema_version` migration and run-log storage under `user://runs/<run_id>.json` | `design/gdd/meta-progression.md` | M4.4, M8.2 | Ownership handoff |
| Event feed, hidden-information and `diagnostic` filters | `design/gdd/match-ui.md` | U3 projection rules | Data dependency |
| Tie-break draws, forks and diagnostic events | `design/gdd/boss-ai.md` | C9, C10 | Ownership handoff |
| `card_id` strings in payloads | `design/gdd/card-database.md` | Card id format | Data dependency |

## Acceptance Criteria

Each criterion is a gdUnit4 test unless marked *manual*; all run headless with literal seeds.

- [ ] **GIVEN** two services created with `run_seed = 42`, **WHEN** `stream("run").randi_range(0,
  65535)` is called 100 times on each, **THEN** the two 100-value sequences are identical and
  each stream reports `draws == 100` (F2, F4, rule 6).
- [ ] **GIVEN** `run_seed = 42`, **WHEN** `stream_seed` is computed for `run`, `match_1`,
  `match_2`, `draft_1`, `ai_1`, **THEN** the values equal the F2 example exactly.
- [ ] **GIVEN** two runs created with seed 42 and hero War, **WHEN** both reach floor 1 and win
  it with the same command sequence, **THEN** `run_started.boss_ids[]` and the floor-1
  `draft_offered.option_ids[]` are equal between the two logs (integration test,
  `tests/integration/rng_event_log/`, with Run Structure and Reward Draft).
- [ ] **GIVEN** a 15-card deck and a stream snapshot, **WHEN** the deck is shuffled, the stream
  restored, and the same deck shuffled again, **THEN** both orders are identical and `draws`
  increased by 14 each time (F4, F5).
- [ ] **GIVEN** a stream with `draws = 37`, **WHEN** `snapshot()` then `restore()` into a fresh
  service, **THEN** the next 20 outputs match the original's next 20.
- [ ] **GIVEN** a stream, **WHEN** `fork("x")` is called twice, **THEN** the same object is returned
  and the parent's `draws` rose by exactly 1 in total.
- [ ] **GIVEN** the rules source tree (`src/` excluding `src/ui/`), **WHEN** grepped with the pattern
  `(^|[^.\w])(randi|randf|randi_range|randf_range|seed|randomize)\(|\.shuffle\(\)|pick_random\(`
  (bare global calls only — `stream.randf()` is legitimate) outside the RNG service file,
  **THEN** zero matches (CI lint; rule 7; pattern per ADR-0001/0003 errata 2026-11-03). *No rules test uses global RNG.*
- [ ] **GIVEN** `weighted_pick([5, 0, 15])` over 10,000 draws from seed 42, **WHEN** counted,
  **THEN** index 1 is never picked and index 2 is picked 7,200 – 7,800 times.
- [ ] **GIVEN** an open match log, **WHEN** 5 events are appended, **THEN** `seq` is 1..5,
  `events_since(3)` returns exactly seq 4 and 5, and each subscriber received each event once in
  order (rule 13, F7).
- [ ] **GIVEN** an event appended with `cause_seq = 40` while event 40 resolves, **WHEN**
  inspected, **THEN** its `seq > 40` and `cause_seq == 40`.
- [ ] **GIVEN** a log at `max_match_events`, **WHEN** another append is attempted, **THEN** the log
  holds `log_overflow` then `match_ended{result: fault}`, is sealed, and further appends are
  dropped.
- [ ] **GIVEN** a payload containing a `Vector2`, **WHEN** appended in a release build and
  serialised, **THEN** `to_json()` succeeds, the value reads `"<unserializable:Vector2>"` and
  `_coerced` lists the key.
- [ ] **GIVEN** a match log, **WHEN** `to_json()` then `from_json()`, **THEN** `replay_equal` holds
  between the original and the round-tripped log (F6).
- [ ] **GIVEN** a sealed match log with a `minion_summoned{instance_id: 7, card_id: "card_a"}`,
  three player `damage_dealt` events with `source: 7` and `dealt` 3, 4, 5 (one with `requested:
  6, prevented: 1`), and one `damage_dealt` whose `source` is a boss instance, **WHEN** reduced
  to `match_summary`, **THEN** `damage_by_card == {"card_a": 12}` (rule 19).
- [ ] **GIVEN** an open match log, **WHEN** `append("command_rejected", {diagnostic: true, …}, 0)`
  is called, **THEN** it receives the next `seq`, `events_since` returns it, and `to_json()`
  round-trips it with `replay_equal` holding (rule 12a).
- [ ] **GIVEN** a snapshot with `data_version = "1.0"` and installed data `"1.1"`, **WHEN**
  `restore()` is called, **THEN** it returns an error and no stream is created.
- [ ] Performance: appending 10,000 events and reading `events_since(0)` completes in under 50 ms
  headless; `restore()` of a stream with `draws = 10,000` in under 5 ms.
- [ ] *Manual:* the death screen shows a 16-hex-digit seed; typing it into hero select with the
  same hero yields the same floor-1 boss and first offers (DD-R09).
- [ ] No hardcoded values: `log_memory_budget_bytes` and `keep_match_logs` are read from a data
  file under `assets/data/` (DD-T01).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| 1. Does Godot 4.7.2 `RandomNumberGenerator` expose settable `seed`/`state` as assumed, and does GDScript `int` wrap on overflow for F2's multiplications? NOT SOURCEABLE from `docs/engine-reference/godot/`. | engine-programmer | `/create-architecture` | Open — verify with a 5-line headless script; record in the RNG ADR |
| 2. After `match_ended{result: fault}`, does Run Structure replay the floor via the retry fork or count it as a win? | game-designer (Run Structure GDD) | Run Structure GDD | **Resolved 2026-11-03** — run-structure R5/R8.3: `match_faulted`, back to `pre_match`, same streams at `draws = 0`, no loss; this GDD's Edge Cases updated |
| 3. What trigger depth / per-action event limit does Card Effects enforce, so `log_overflow` is a second line of defence? | systems-designer (Card Effects GDD) | Card Effects GDD | **Resolved 2026-11-03** — match-rules `RESOLUTION_STEP_CAP` 1,000 (`resolution_overflow`) + card-effects `EFFECT_STATIC_STEP_LIMIT` 250; `max_match_events` is the backstop |
| 7. `diagnostic` events on the same log (rule 12a) answers match-rules' open question; match-rules, boss-ai and match-ui should cite rule 12a and drop their "whatever channel" wording. | `/consistency-check` | Before `/create-architecture` | **Resolved 2026-11-03 — re-review**: match-rules C15 and its OQ, boss-ai C9/Interactions/Cross-References cite rule 12a; match-ui U3 labels `command_rejected` diagnostic |
| 8. Match Rules' Interactions row names the stream API as `shuffle(list)`, `pick(list)`, `range(n)` and C3 names a `MatchConfig.seed`; F4's API is `randi_range`, `shuffle`, `weighted_pick`, `fork`, and Run Structure passes streams (its R3). Match Rules should adopt F4 names and the stream handles. | Match Rules GDD | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-05**: match-rules Interactions / Cross-References adopt the injected `match_<floor>` stream handle from `MatchConfig` and the F4 names (`randi_range`, `shuffle`, `weighted_pick`; no forks in v1); `MatchConfig.seed` is gone (match-rules Dependencies passes `rng_match` / `rng_ai`) |
| 4. Should bug-report JSON redact boss hand contents (`card_drawn.card_id`, `side = boss`) when shared mid-run? | game-designer | Match UI GDD | Open — default: no redaction |
| 5. Should `keep_match_logs` default to true in release for the first public build to gather balance data? | owner | Alpha sprint plan | Open |
| 6. `design/design-decisions.md` cites ADR-0001 and ADR-0003, but no such files exist under `docs/architecture/`; the RNG ADR should take the next id from `registry.sh next-id adr`. | technical-director | `/create-architecture` | Open |
