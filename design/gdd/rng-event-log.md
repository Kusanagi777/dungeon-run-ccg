# RNG & Event Log

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
> **Author**: owner + Claude (`/design-system`, guided automation, Lean review — no specialist agents consulted)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 4 (Readable, deterministic rules); supports Pillar 3 (Lose fast, learn fast)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` `systems-designer` / `qa-lead` not consulted on Formulas and Acceptance Criteria — Lean mode and no Agent tool in this run; review manually before production.
> **Decisions cited**: DD-T03, DD-T04, DD-R09, DD-R08, DD-T01, DD-T02, DD-M06, DD-M07, DD-M11, DD-M12, DD-M13, DD-R01, DD-R02, DD-R04, DD-R05, DD-R06

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
   | `ai_<floor>` | Boss AI | Tie-breaks between equally scored plays and attacks; nothing else |

   `<floor>` is 1–8. A consumer draws only from streams it owns; an owner may pass a fork to a
   callee (rule 5). Ownership is enforced by code review, not at runtime.
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
10. `snapshot()` returns `{run_seed, data_version, streams: {name: draws}}`; `restore(snapshot)`
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
13. The log is append-only: `append(type, payload, cause_seq)` is the only writer; no edit, no
    remove. `subscribe(callback)` delivers each event once, in `seq` order, after it is appended;
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
`match_summary`.

| Type | Owner | Payload fields |
|---|---|---|
| `match_started` | Match Rules | `floor, hero_id, boss_id, player_deck_size, boss_deck_size` |
| `mulligan_offered` / `mulligan_completed` | Match Rules | `side, instance_ids[]` / `side, replaced_instance_ids[]` |
| `turn_started` / `turn_ended` | Match Rules | `turn, side, mana_max, mana_available` / `turn, side` |
| `mana_changed` | Match Rules | `side, mana_available, mana_max, delta` |
| `card_drawn` | Match Rules | `side, instance_id, card_id, hand_size` |
| `card_burned` | Match Rules | `side, instance_id, card_id` (DD-M06) |
| `fatigue_damage` | Match Rules | `side, amount` (DD-M07; followed by `damage_dealt`) |
| `card_played` | Match Rules | `side, instance_id, card_id, cost_paid, target_id, board_index` |
| `minion_summoned` | Match Rules | `side, instance_id, card_id, board_index, attack, health, keywords[]` |
| `weapon_equipped` / `weapon_broken` | Match Rules | `side, instance_id, card_id, attack, durability` / `side, instance_id` |
| `hero_power_used` | Match Rules | `side, power_id, target_id` (DD-M13) |
| `attack_declared` | Match Rules | `attacker_id, defender_id` |
| `damage_dealt` | Match Rules | `source_id, target_id, amount, health_after, lethal` |
| `healing_applied` | Match Rules | `source_id, target_id, amount, health_after` |
| `minion_modified` | Card Effects | `instance_id, attack, health, max_health, keywords_added[], keywords_removed[], reason` |
| `minion_died` | Match Rules | `instance_id, card_id, side, board_index` (order per DD-M11) |
| `deathrattle_triggered` | Card Effects | `instance_id, card_id, effect_id` |
| `effect_resolved` | Card Effects | `effect_id, source_id, operation, targets[], values{}` — extension point |
| `discover_offered` / `discover_picked` | Card Effects | `side, source_id, option_card_ids[]` / `side, picked_card_id` |
| `ai_intent_shown` | Boss AI | `boss_id, intent_key, target_id` |
| `match_ended` | Match Rules | `result (win/loss/fault), winner_side, turns, reason` (DD-M12) |
| `log_overflow` | this system | `cap, seq` |
| `run_started` | Run Structure | `run_seed_hex, hero_id, data_version, log_schema_version, boss_ids[]` |
| `run_floor_entered` | Run Structure | `floor, band, boss_id` |
| `match_summary` | this system | `floor, result, turns, event_count, cards_played, damage_by_card{card_id: int}` |
| `draft_offered` / `draft_picked` | Reward Draft | `floor, kind (bundle/treasure), option_ids[]` / `floor, kind, picked_id, card_ids_added[]` |
| `treasure_granted` | Reward Draft | `floor, treasure_id` (applied by Treasures) |
| `run_saved` | Run Structure | `floor, phase` (DD-R08) |
| `run_ended` | Run Structure | `result (victory/death/abandoned), floors_cleared, total_turns, run_seed_hex` |

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
    raw log is written to `user://logs/<run_seed_hex>/floor_<n>.json` when `keep_match_logs`
    (data file; default true in debug builds, false in release) is set.
19. `damage_by_card` is computed by this system from `damage_dealt` events: for each event whose
    `source_id` is a card instance owned by the player, add `amount` under that `card_id`. Hero
    power and weapon damage attribute to the power's or weapon's `card_id`; fatigue to nothing.

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
| Card Effects | `effect_resolved`, `deathrattle_triggered`, `minion_modified`, Discover events; nested emissions | Forks of `match_<floor>` passed in by Match Rules (`fork("effect_<effect_id>")`); `cause_seq` of the triggering event | Card Effects owns `effect_resolved.values` |
| Boss AI | `ai_intent_shown` only — AI reads state, it does not mutate it | `stream("ai_<floor>")` for tie-breaks; the AI must be a pure function of (state, stream) | Boss AI documents which decisions may tie-break |
| Run Structure | `run_started`, `run_floor_entered`, `run_saved`, `run_ended`; `run_seed` at creation; `restore(snapshot)` on resume | `stream("run")`; `snapshot()` for save files (DD-R08); the run log instance | Run Structure owns run phase order |
| Reward Draft | `draft_offered`, `draft_picked`, `treasure_granted` | `stream("draft_<floor>")` for offers and pity rolls | Reward Draft owns offer payloads |
| Treasures | Hooks emit `effect_resolved` with `source_id` = treasure | `cause_seq` so a treasure-caused mutation is attributable | Treasures owns hook naming |
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
| lo, hi | int | `hi − lo + 1 ≤ 65,536` | caller | Inclusive bounds; modulo bias < 2^−16 at this span |
| a | Array | length 0 – 1,000 | caller | Shuffled in place (decks are ≤ 36 cards, DD-R06) |
| w | Array[int] | each ≥ 0, total 1 – 2^31−1 | caller (data-file weights) | Weights; total 0 is an error (Edge Cases) |
| draws | int | 0 – ~10,000 per stream per run | calculated | Count of `randi32()` calls, recorded in `snapshot()` |

**Output Range:** `randi_range` ∈ [lo, hi]; `weighted_pick` ∈ [0, len(w)−1].
**Example (algorithmic trace, draws hypothetical):** `shuffle([A,B,C,D])` with draws giving
`j = 1, 0, 1` → `[A,D,C,B]` → `[C,D,A,B]` → `[C,D,A,B]`; 3 draws. `weighted_pick([5, 0, 15])`
with `r = 7` → cumulative `5, 5, 20` → index 2.

### F5 — Restore

```
restore(stream, draws): generator.seed = stream_seed; repeat draws times: randi32()
```

`draws` as in F4; cost O(draws), sub-millisecond at 10,000. An implementation may copy the
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
| run_total_events | int | typical 3,000 – 20,000 | calculated | Reported in `run_ended` diagnostics; not capped |

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
- **If a floor must be replayed** (rules fault, below): the retry uses
  `stream("match_<floor>").fork("retry_<n>")`, never the consumed `match_<floor>`.
- **If `randi_range(lo, hi)` has `lo > hi`**: assert in debug; return `lo` in release without a
  draw. Never swap silently — a swapped range hides a caller bug.
- **If `weighted_pick` receives an empty array, a negative weight or a total of 0**: assert in
  debug; return `-1` in release without a draw. Callers (Reward Draft pity rules) must guarantee a
  positive total; this system invents no fallback pick.
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
  `deathrattle_triggered` (41, cause 40) → `effect_resolved` (42, cause 41) → `damage_dealt`
  (43, cause 42) → `minion_died` (44, cause 43).
- **If a subscriber callback calls `append`**: assert in debug; in release the append is accepted
  and tagged `payload._reentrant: true`. Rules code never subscribes, so this only ever marks a
  display-layer bug.
- **If the match log reaches `max_match_events`**: append `log_overflow{cap, seq}`, then force
  `match_ended{result: fault, reason: "event_cap"}`; the log goes `Faulted → Sealed` and is
  written to `user://logs/faults/<run_seed_hex>_floor_<n>.json` regardless of `keep_match_logs`.
  This system does **not** end the run; Run Structure decides (provisional: replay the floor via
  the retry fork, no loss recorded). Rationale: a cap hit is an unbounded trigger loop that Card
  Effects' own depth limit missed (provisional — Open Question 3); Pillar 3 says the player should
  not pay for a rules bug.
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
strings pass through payloads opaquely. Every row below is a downstream dependent. None of these
GDDs exists yet (this is the second system in the design order), so every interface here is
**provisional** and each dependent GDD must restate it in its own Dependencies section.

| System | Direction | Hard/Soft | Nature of Dependency |
|---|---|---|---|
| Match Rules | Match Rules depends on this | Hard | Injected `match_<floor>` stream; emits every match event; assigns `instance_id` |
| Card Effects | Card Effects depends on this | Hard | Forked streams for effects with independent draws; emits effect, deathrattle, modification and Discover events; relies on `cause_seq` nesting |
| Boss AI | Boss AI depends on this | Hard | Injected `ai_<floor>` stream for tie-breaks; emits `ai_intent_shown`; AI-vs-AI simulation harness uses fixed seeds |
| Run Structure | Run Structure depends on this | Hard | Creates the service with `run_seed`; `run` stream for the boss sequence; `snapshot()`/`restore()` for save and resume (DD-R08); owns the run log lifecycle |
| Reward Draft | Reward Draft depends on this | Hard | Injected `draft_<floor>` stream for offers and pity rolls; emits draft and treasure events |
| Treasures | Treasures depends on this | Soft | Hooks emit `effect_resolved` attributable through `cause_seq`; works without the log but is then invisible to the player |
| Match UI | Match UI depends on this | Hard | `subscribe` / `events_since` are its only data source (DD-T04); hidden-information filter on boss `card_drawn` |
| Run UI | Run UI depends on this | Hard | `match_summary` for the summary screen; `run_seed_hex` display and seed-entry field |
| Meta Progression | Meta Progression depends on this | Soft | Stores sealed run logs with the profile; owns `log_schema_version` migration; works without logs (unlocks only) |
| Content / balance tooling | Tooling depends on this | Soft | `/balance-check` reads archived JSON logs for pick rates and damage per card |

**Bidirectional check** (`.claude/rules/design-docs.md`): `design/gdd/systems-index.md` lists RNG
& Event Log under *Depends On* for Match Rules, Card Effects, Run Structure and Reward Draft —
consistent. It does **not** list it for Boss AI, Treasures, Match UI, Run UI or Meta Progression,
all named as dependents above. Flagged for `/map-systems` to correct; this GDD does not edit the
index.

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
| Death resolution order fixes nested event order | `design/gdd/match-rules.md` (not yet authored) | DD-M11 death and trigger ordering | Rule dependency |
| `match_ended` result and double-zero rule | `design/gdd/match-rules.md` (not yet authored) | DD-M12 win/loss | State trigger |
| Trigger depth limit as first defence against `log_overflow` | `design/gdd/card-effects.md` (not yet authored) | Effect resolver depth limit | Rule dependency (provisional) |
| Boss sequence drawn from `run`; retry policy on fault | `design/gdd/run-structure.md` (not yet authored) | Run state machine, DD-R01/DD-R02 | Ownership handoff |
| Offers and pity rolls drawn from `draft_<floor>` | `design/gdd/reward-draft.md` (not yet authored) | Offer weighting, DD-R04/DD-R05 | Ownership handoff |
| `log_schema_version` migration and run-log storage | `design/gdd/meta-progression.md` (not yet authored) | Profile save format | Ownership handoff |
| Event feed and hidden-information filter | `design/gdd/match-ui.md` (not yet authored) | Event feed rendering | Data dependency |
| `card_id` strings in payloads | `design/gdd/card-database.md` (authored concurrently) | Card id format | Data dependency |

## Acceptance Criteria

Each criterion is a gdUnit4 test unless marked *manual*; all run headless with literal seeds.

- [ ] **GIVEN** two services created with `run_seed = 42`, **WHEN** `stream("run")` is drawn 100
  times from each, **THEN** the two sequences are identical (F2, rule 6).
- [ ] **GIVEN** `run_seed = 42`, **WHEN** `stream_seed` is computed for `run`, `match_1`,
  `match_2`, `draft_1`, `ai_1`, **THEN** the values equal the F2 example exactly.
- [ ] **GIVEN** two runs created with seed 42 and hero War, **WHEN** both reach floor 1, **THEN**
  their boss sequences and floor-1 bundle offers are identical (integration test with Run
  Structure and Reward Draft once they exist; until then assert `run` and `draft_1` equality).
- [ ] **GIVEN** a 15-card deck and a stream snapshot, **WHEN** the deck is shuffled, the stream
  restored, and the same deck shuffled again, **THEN** both orders are identical and `draws`
  increased by 14 each time (F4, F5).
- [ ] **GIVEN** a stream with `draws = 37`, **WHEN** `snapshot()` then `restore()` into a fresh
  service, **THEN** the next 20 outputs match the original's next 20.
- [ ] **GIVEN** a stream, **WHEN** `fork("x")` is called twice, **THEN** the same object is returned
  and the parent's `draws` rose by exactly 1 in total.
- [ ] **GIVEN** the rules source tree (`src/` excluding `src/ui/`), **WHEN** grepped for `randi(`,
  `randf(`, `randi_range(`, `randomize(`, `.shuffle(`, `.pick_random(` outside the RNG service
  file, **THEN** zero matches (CI lint; rule 7). *No rules test uses global RNG.*
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
- [ ] **GIVEN** a sealed match log with three player `damage_dealt` events from `card_a` (3, 4, 5)
  and one from the boss, **WHEN** reduced to `match_summary`, **THEN** `damage_by_card ==
  {"card_a": 12}` (rule 19).
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
| 2. After `match_ended{result: fault}`, does Run Structure replay the floor via the retry fork or count it as a win? | game-designer (Run Structure GDD) | Run Structure GDD | Open — provisional: replay, no loss |
| 3. What trigger depth / per-action event limit does Card Effects enforce, so `log_overflow` is a second line of defence? | systems-designer (Card Effects GDD) | Card Effects GDD | Open |
| 4. Should bug-report JSON redact boss hand contents (`card_drawn.card_id`, `side = boss`) when shared mid-run? | game-designer | Match UI GDD | Open — default: no redaction |
| 5. Should `keep_match_logs` default to true in release for the first public build to gather balance data? | owner | Alpha sprint plan | Open |
| 6. `design/design-decisions.md` cites ADR-0001 and ADR-0003, but no such files exist under `docs/architecture/`; the RNG ADR should take the next id from `registry.sh next-id adr`. | technical-director | `/create-architecture` | Open |
