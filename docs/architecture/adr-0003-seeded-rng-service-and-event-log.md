# ADR-0003: Seeded RNG Service and Event Log

## Status

Accepted

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories referencing a `Proposed` ADR are set `Blocked`, and epics require
> `Accepted`, so the field needs a named owner. `technical-director` is the role
> `coordination-rules.md` already escalates technical conflicts to, and an ADR is
> that decision made durable. This does **not** relax the rule that
> `Status: Accepted` is never set without explicit user confirmation.

Review record for this run (2026-11-03, `/architecture-decision`, headless, no
`AskUserQuestion` answerer):

- **Erratum 2026-11-03 (rng-event-log story 003)**: the snapshot carries a fourth key, `fork_points: {fork name: parent draw count at fork time}`; `restore()` replays `stream(parent).fork(label)` at that point (forks keyed by parent + label, per the code-review erratum) and clears cached forks. `snapshot()` keeps `run_seed` as an int in memory; `snapshot_to_json_dict()` persists `run_seed_hex`. `restore()` rejects a snapshot from another run seed or with malformed entries (`ERR_INVALID_DATA`).
- TD-ADR skipped — Lean mode (`review_mode: lean`; TD-ADR is not a PHASE-GATE).
- Engine validation: **NOT ASSESSED** — `godot-specialist` was not spawned (no
  `Agent` tool in this run). Every engine claim below is sourced from
  `docs/engine-reference/godot/` or observed by a headless probe on the installed
  4.7.2; anything else is marked `NOT SOURCEABLE`.
- GDD sync: checked 3 referenced GDDs (`rng-event-log.md`, `match-rules.md`,
  `run-structure.md`) against the Key Interfaces below; no naming inconsistencies
  (the F4 draw names `randi_range` / `shuffle` / `weighted_pick` / `fork`, the
  rule 11 envelope, `snapshot` / `restore`, `subscribe` / `events_since` and
  `to_json` / `from_json` match the GDD and `tests/helpers/` spellings). One
  addition, not a rename: `RngStream.randi32()` is exposed as the primitive F4 is
  defined over (the helper already exposes it); rules code never calls it.
- Numbering fixed by `design/design-decisions.md` DD-X08 (closes rng-event-log
  Open Question 6).
- **TD review 2026-11-03 (acceptance pass over ADR-0001..0011):** rule 7, the
  diagram, two guidelines, a risk mitigation and the Enables row no longer say
  `MatchDriver` *buffers* live-log events — that contradicted ADR-0008 Decision 5
  (no event buffer) and ADR-0006's clone-and-replay protocol; the main-thread
  subscriber rule itself is unchanged. The knob source now cites
  `rng_event_log.json` (DD-T01) consistently, and the Ordering Note says three
  knobs, not two, matching Constraints and the guidelines.
- **Erratum 2026-11-03 (code review)**: the Decision 10(b) lint token list, read as fixed strings, hit the injected-stream calls rules code is required to make (`stream.randi_range(`, `stream.randf(`, `stream.shuffle(`). The lint is now the regex `(^|[^.\w])(randi|randf|randi_range|randf_range|seed|randomize)\(|\.shuffle\(\)|\.pick_random\(|RandomNumberGenerator\.new\(` (look-around-free: `(^|[^.\w])` skips `obj.` calls and identifiers ending in a token; `\.shuffle\(\)` is the argument-less global `Array.shuffle()`), matching ADR-0001's corrected G6 plus `RandomNumberGenerator\.new\(`.
- **Erratum 2026-11-03 (code review)**: two name patterns, not one. The **full stream-name pattern** `^[a-z]+(_[0-9]+)?(/[a-z0-9_]+)*$` (`RngService.STREAM_NAME_PATTERN`, `is_valid_stream_name`) describes every stream's name, forks included (`ai_1/sim_3`). The **`stream()`-accepted pattern** is root names only, `^[a-z]+(_[0-9]+)?$` (`ROOT_STREAM_NAME_PATTERN`): `RngService.stream("ai_1/x")` is refused like `fork("a/b")` (assert in debug, `push_error` in release, returns `null`, creates no stream), because it would share the name `ai_1/x` with `stream("ai_1").fork("x")` under an F2 instead of an F3 seed. `/` names come only from `fork()`; snapshots key a fork by parent + label, never by a top-level `stream()` entry (rng-event-log rule 3; story 003's `snapshot()` / `restore()` must also clear each stream's fork memo on restore). Other off-pattern names keep Decision 2's "logged, still served". `run_seed` and `data_version` are read-only properties (a write is logged and ignored).
- **Accepted 2026-11-03 by technical-director** on the owner's standing approval of the project plan (plan approved 2026-11-03; "accept each" step). Owner may revert to Proposed.

## Date

2026-11-03

## Last Verified

2026-11-03 — against Godot 4.7.2 (`docs/engine-reference/godot/VERSION.md`),
`docs/architecture/architecture.md` v1 and `design/gdd/rng-event-log.md`
(Approved, realigned 2026-11-03). Re-verify on every engine bump: replay
equivalence is per engine version by design (rule 9, QQ-06).

## Decision Makers

Jacob (owner, standing approval for the Foundation ADR set); authored by the
`/architecture-decision` run; `technical-director` acceptance pending.
`engine-programmer` is the named implementer of the probe that rng-event-log
Open Question 1 asked for — it was run as part of this ADR (see Verification).

## Summary

Deckdelve's Pillar 4 ("every run is reproducible and every bug is a log") needs
one seeded randomness source and one append-only event log that every rules
module shares, with no global RNG anywhere under the rules tree (TD-007). This
ADR fixes `RngService` (injected, `(run_seed, data_version)`, memoised named
streams derived by FNV-1a 64 + SplitMix64 per rng-event-log F1–F3, one
`RandomNumberGenerator` per stream, the F4 draw API over `randi32()`,
`snapshot`/`restore` by reseed-and-discard) and `EventLog` (the five-field
envelope `{seq, turn, type, payload, cause_seq}`, synchronous main-thread
subscribers, diagnostic events on the same log per rule 12a, sealing, the
`log_overflow` fault at `max_match_events`, `to_json`/`from_json` with 64-bit
values serialised as hex strings), and defines the determinism contract the test
suite enforces.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7; `docs/engine-reference/godot/VERSION.md`) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH for GDScript 4.5–4.7 language changes (VERSION.md); **NOT SOURCEABLE** for `RandomNumberGenerator`, `JSON` and `int` overflow — no Core/scripting module page exists under `docs/engine-reference/godot/modules/`. Closed by the headless probe in **Verification** rather than by training data. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `current-best-practices.md` (§GDScript 4.5+, §GDScript 4.7, §Tooling, §Command Line), `deprecated-apis.md`, `breaking-changes.md` (4.6→4.7 GDScript rows; 4.3→4.4 Core row), `docs/architecture/spikes/2026-11-03-engine-probes.md` (environment + verified API list); probe D/E outputs recorded below |
| **Post-Cutoff APIs Used** | None required. Language rules that apply: an override of a typed method inherits the return type and needs an explicit `return` (4.7, sourced); lambdas capture locals by value — subscribers share state through a Dictionary or object (sourced); `@abstract` is **not** used here (concrete classes only); variadic `...args` not used. Typed `Array[Dictionary]` / `Array[int]` per `deprecated-apis.md` "Untyped Array" row. |
| **Verification Required** | (1) Same seed ⇒ same `randi()` sequence on the installed engine, and reseed-and-discard equals `state` restore — **observed 2026-11-03, probe D**; re-run on every engine bump (`tests/unit/rng_event_log/rng_stream_test.gd` carries it). (2) Signed-int64 wraparound of the F2/F3 constants — **observed, probe D7** (GDD example values reproduced bit-exactly). (3) `JSON.parse_string` returns `float` for every number and loses precision above 2^53 — **observed, probe E**; hence the hex rule in the Decision. (4) Subscriber re-entrancy and the overflow path — unit tests (Validation Criteria). |

> Knowledge Risk is HIGH/NOT SOURCEABLE: re-validate this ADR if the project
> upgrades engine versions; a changed `RandomNumberGenerator` algorithm breaks
> replay of archived logs (accepted by rule 9 — replay is per engine version).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (rules / presentation split: `RefCounted` rules tree, constructor injection, the grep gates this ADR's rule 7 lint joins) — must be Accepted before implementation starts |
| **Enables** | ADR-0004 (`RngService.snapshot()` shape and `EventLog.to_json()` travel inside the `RunRecord`); ADR-0005 (`cause_seq` attribution of hook effects); ADR-0006 (the main-thread-only subscriber rule the clone-and-replay planner seam relies on — decided here); ADR-0007 (resolver draws directly from `rng_match`, card-effects C6.9); ADR-0008 (`MatchConfig.rng_match` / `rng_ai` / `log` fields); ADR-0009 (`AnimationQueue` groups by `cause_seq` root) |
| **Blocks** | Epic "Foundation — RNG & Event Log" (E1 story set: the `TODO(E1)` swap in `tests/helpers/`); every Core epic (match-rules, card-effects, boss-ai) — they take `rng_match` / `rng_ai` / `log` through `MatchConfig` |
| **Ordering Note** | Write order per architecture.md: 0001 → 0002 → **0003** → 0004 → 0010. ADR-0002 is not a dependency: this ADR reads only three knobs (`log_memory_budget_bytes`, `avg_event_bytes`, `keep_match_logs`) via `CardDatabase.config("rng_event_log")` (DD-T01 row `rng_event_log.json`), and the composition root passes them as plain constructor arguments, so the log class never names the database. |

## Context

### Problem Statement

The January prototype used global unseeded RNG in seven files (deck `shuffle()`,
reward/shop pools, `pick_random()` targeting, `randi()` instance ids,
`randomize()` in `minion_tags.gd` — TD-007), so no match or run could be replayed
or tested deterministically, and it had no event stream at all: views mutated
state and nothing recorded what happened (TD-005/006). Pillar 4, DD-R09 (seed
shown on the summary reproduces boss sequence and offers), DD-T03 (one seeded
service, named streams) and DD-T04 (append-only log, one event per mutation, UI
renders from events) require a Foundation-layer decision before any rules code
exists, because every Core module's constructor signature depends on it
(match-rules C3 `MatchConfig{rng_match, rng_ai, log}`; reward-draft D1
`offer(kind, run_state, stream)`; boss-ai C1 "pure function of state, profile and
stream position"). `rng-event-log.md` (Approved) fixes the design to the formula
level (F1–F7); what remains architectural is: which engine generator, how a
64-bit seed survives GDScript's signed `int` and JSON's `float`, who owns the
subscriber thread contract, how `snapshot`/`restore` is implemented, where the
files go, and how the determinism contract is enforced in the test suite.

### Current State

No production class exists. `tests/helpers/test_rng_stream.gd`,
`test_rng_service.gd` and `test_event_log.gd` already implement the GDD contract
literally as test doubles (self-tested in
`tests/unit/framework/test_helpers_test.gd`: F1/F2 example pins, memoised
streams, fork-once, restore, data_version rejection, overflow path), marked
`TODO(E1 story)` for the swap to the production classes. `project.godot` has the
one `Boot` autoload (`res://src/scenes/boot.tscn` main scene). `project.yaml`
pins Godot 4.7.2 / GDScript.

### Constraints

- Rules purity (DD-T02, ADR-0001): both classes are `RefCounted`, take every
  collaborator in `_init`, reference no Node, no autoload, no scene; they must
  parse with no autoload present (`.claude/scripts/godot-parse-check.gd`).
- Data owns the numbers (DD-T01): `log_memory_budget_bytes`, `avg_event_bytes`
  and `keep_match_logs` come from `assets/data/rng_event_log.json` (DD-T01);
  no literal in code.
- GDScript `int` is signed 64-bit; the GDD's arithmetic is unsigned mod 2^64
  (F2 note). `JSON.parse_string` yields `float` for every number (probe E) and
  cannot carry a 64-bit seed.
- `.claude/rules/ai-code.md` 2 ms/frame and ADR-0006: the planner runs off the
  main thread; this ADR must say what the log guarantees to subscribers.
- Budgets (rng-event-log Acceptance Criteria): 10,000 appends + `events_since(0)`
  under 50 ms headless; `restore()` of 10,000 draws under 5 ms; open match log
  ≤ 2 MB (`log_memory_budget_bytes`).
- Engine reference has no page for `RandomNumberGenerator`, `JSON`, `Time`,
  `FileAccess` details beyond the 4.4 `store_*` → `bool` row; claims about them
  are observed on 4.7.2 or marked NOT SOURCEABLE.

### Requirements

- Must support rng-event-log rules 1–19 and F1–F7 exactly (the GDD is the spec;
  this ADR adds no mechanics).
- Must give two services built with the same `(run_seed, data_version)`
  identical sequences on every stream (AC 1), and reproduce the F1/F2 example
  values bit-exactly (AC 2).
- Must deliver each event to each subscriber once, in `seq` order, after append,
  on the main thread (rule 13; architecture.md Data Flow §2 — the live engine
  is main-thread only).
- Must round-trip `to_json()` → `from_json()` with `replay_equal` holding (F6),
  including 64-bit seeds and `StringName` types.
- Must integrate with `MatchConfig` (match-rules C3), `offer()` (reward-draft
  D1), `RunRecord.rng_snapshot` / `run_log` (run-structure R1/R7) and the
  `AnimationQueue` (`cause_seq` grouping, match-ui U4).

## Decision

**Two concrete `RefCounted` classes under `src/core/`, injected everywhere and
never looked up.** `RngService` (`src/core/rng/rng_service.gd`) plus `RngStream`
(`src/core/rng/rng_stream.gd`) implement rules 1–10 and F1–F5 over one
`RandomNumberGenerator` per stream; `EventLog` (`src/core/log/event_log.gd`)
implements rules 11–19 and F6–F7. Specifically:

1. **Generator and derivation.** Each stream owns one `RandomNumberGenerator`
   whose `seed` is set once to `stream_seed(run_seed, name)` (F2) or
   `fork_seed(parent_draw, parent_name, label)` (F3): FNV-1a 64 over
   `le_bytes8(seed) ++ utf8(name)` then the SplitMix64 finaliser, computed in
   signed `int` with the constants written as their signed equivalents and
   `>>>` emulated as `(x >> n) & ((1 << (64 - n)) - 1)` — exactly the helper's
   `fnv1a64` / `mix64` / `ushr64`, whose outputs match the GDD examples on
   4.7.2 (probe D7). `randi32()` is `RandomNumberGenerator.randi()` (observed
   `[0, 2^32 − 1]`, probe D6) and is the only call that touches the generator;
   every F4 primitive is defined over it so `draws` is exact and
   engine-independent.
2. **Memoisation and forks.** `RngService.stream(name)` validates the rule 3
   pattern (error log, still served — a bad name is a programmer bug, not a
   runtime branch), creates on first use, returns the same object thereafter.
   `RngStream.fork(label)` consumes one parent `randi32()` on the first call,
   memoises `"<name>/<label>"`, and returns the same child on later calls (rule
   5, Edge Cases).
3. **Snapshot and restore by reseed-and-discard (F5), not by `state`.**
   `snapshot()` is `{run_seed, data_version, streams: {name: draws}}`;
   `restore()` rejects a `data_version` mismatch with `ERR_INVALID_DATA` and
   creates nothing, else rebuilds each named stream by setting `seed` and
   discarding `draws` outputs. Probe D4/D5 showed `RandomNumberGenerator.state`
   is a settable `int` and that reseed-and-discard reproduces the same next
   outputs; the discard form is kept because its persisted value (`draws`) is a
   small, human-readable, engine-independent count that JSON carries exactly,
   whereas `state` is an opaque 64-bit value that `JSON.parse_string` would
   corrupt (probe E) and that ties the save to the generator's internals.
   `restore` of 10,000 draws is bounded by the 5 ms AC and measured by a perf
   test; a snapshot requested mid-command is refused (Edge Cases) — the
   service exposes `begin_command()` / `end_command()` that the engine and run
   machine call, and `snapshot()` returns an empty Dictionary with a pushed
   error while a command is open.
4. **64-bit values cross JSON as hex strings.** `run_seed` is persisted and
   logged as `run_seed_hex` (16 uppercase hex digits, unsigned view, F1
   display form) and parsed back with `parse_hex_u64`; `snapshot()` keeps
   `run_seed` as `int` in memory but `RngService.snapshot_to_json_dict()` /
   `from_json_dict()` convert. Reason: probe E — `JSON.parse_string` returns
   `float` for every number and loses precision above 2^53 (`2^53 + 1` →
   `2^53`; a full 64-bit seed came back wrong). The same rule binds every
   persisted 64-bit value in the project (ADR-0004 inherits it). Small
   integers (`draws`, `seq`, `turn`, counts) are coerced back with `int()` on
   load, as the helper's `_coerce_integral_floats` already does.
5. **Event log envelope and writer.** `append(type, payload, cause_seq = 0) ->
   int` is the only writer; it stamps `seq` (1-based, +1 per append) and `turn`
   (from `set_turn`, 0 before the first call), stores `type` as `String` (rule
   14), deep-copies `payload`, appends, then notifies subscribers in
   registration order. It returns `-1` when the log is sealed (release: dropped
   with a `push_warning`; debug: `assert`). Payload values are validated at
   append time in debug (`assert`) and coerced in release: a non-JSON value
   becomes `"<unserializable:ClassName>"` and the key is listed in
   `payload._coerced[]` (Edge Cases).
6. **Diagnostic events share the log (rule 12a).** `command_rejected`,
   `ai_decision`, `ai_plan_aborted`, `ai_fault`, `run_warning` are ordinary
   appends with `payload.diagnostic = true`; they take a `seq`, may be a
   `cause_seq` target, count toward the cap, and are compared by F6. The log
   offers no second channel and no filter: filtering is `MatchViewState`'s job
   (match-ui U3 rule 4a).
7. **Subscribers are synchronous, main-thread, by-value lambdas.**
   `subscribe(callback)` delivers each event once, in `seq` order, immediately
   after the append, on the thread that called `append`. The log itself is
   thread-agnostic (no locks); the rule that makes this safe is architectural:
   a `PlannerTask` (ADR-0006) plans on a `RulesEngine.clone()` with a detached
   scratch log, so **nothing appends to or subscribes to the live log from the
   worker** — `MatchDriver` replays the returned plan into the live engine on
   the main thread in `tick()`, and live subscribers fire there (ADR-0008
   Decision 5: no event buffer). A subscriber that calls `append`
   re-enters: `assert` in debug; in release the append is accepted and tagged
   `payload._reentrant = true` (Edge Cases). Because GDScript lambdas capture
   locals by value (sourced, `current-best-practices.md`), subscriber code that
   accumulates state does so through a Dictionary/object it closes over.
8. **Sealing and the overflow fault.** `match_ended` / `run_ended` seal the
   log. At `max_match_events = floor(log_memory_budget_bytes / avg_event_bytes)`
   (10,000 at defaults) the log appends `log_overflow{cap, seq}`, emits
   `overflowed(cap, seq)`, and accepts **exactly one** more event — which must
   be Match Rules' `match_ended{result: fault, reason: event_cap}`; the log
   never fabricates a Match Rules event (Edge Cases). This settles the wording
   difference the helper's header notes against match-rules Edge Cases: the
   production rule is "overflow event, then one more append, then sealed".
9. **Serialisation and files.** `to_json()` produces `{log_schema_version,
   engine_version, data_version, run_seed_hex, scope, floor, events[]}` using
   `JSON.stringify(dict, "\t")`; canonical form for F6 comparison is sorted
   keys, floats to 6 decimals, `StringName` as `String`
   (`EventLogAssertions.canonical_json` is the reference implementation; on
   4.7.2 `JSON.stringify` already emits sorted keys — observed, probe E4 — but
   the canonicaliser does not rely on it). `reduce_to_summary()` implements rule
   19 (`damage_by_card` from `damage_dealt.source` / `dealt` through the
   `instance_id → card_id` map). Files: `user://logs/<run_id>/floor_<n>_attempt_<k>.json`
   when `keep_match_logs`, and `user://logs/faults/<run_id>_floor_<n>_attempt_<k>.json`
   **always** on a `log_overflow` (Edge Cases). The write itself goes through
   the same `AtomicFileWriter` ADR-0004 defines (`make_dir_recursive_absolute`
   first — probe B: parent directories are not created by `FileAccess.open`),
   so `src/core/log/` and `src/core/save/` remain the only openers of `user://`.
10. **Determinism contract for tests.** (a) Every rules test constructs its own
    `RngService(seed_literal, "test")` and `EventLog` — never through `Boot`.
    (b) The CI lint `tools/lint/no_global_rng.sh` greps `src/` excluding
    `src/ui/` and `src/core/rng/` for the bare global calls `randi(`, `randf(`,
    `randi_range(`, `randf_range(`, `seed(`, `randomize(`, the argument-less
    `.shuffle()`, `.pick_random(` and `RandomNumberGenerator.new(` — the regex
    `(^|[^.\w])(randi|randf|randi_range|randf_range|seed|randomize)\(|\.shuffle\(\)|\.pick_random\(|RandomNumberGenerator\.new\(`
    (erratum 2026-11-03, code review: a fixed-string list hit `stream.randf(`);
    any hit fails the build (rule 7; the one permitted entropy call lives in
    Run Structure's run-creation command for the empty-seed branch of F1 and
    is allow-listed by path). (c) The suite-level determinism rule is F6: a
    test that runs a scripted command sequence twice asserts
    `EventLogAssertions.replay_equal(a, b)`. (d) The helper self-test's seed
    pins (F1/F2 examples) move into `tests/unit/rng_event_log/` and run on
    every engine bump; a failure there means the engine changed, not the code.

### Architecture Diagram

```
RunMachine.new_run(seed_input)                      Boot.boot() → Services{card_database,...}
   │ run_seed = F1(seed_input)  (entropy only here)          │ config("rng_event_log")
   ▼                                                         ▼  {log_memory_budget_bytes, avg_event_bytes, keep_match_logs}
RngService(run_seed, data_version) ──stream("run")──► RngStream{name, draws, rng: RandomNumberGenerator}
   │  stream("match_f") / ("ai_f") / ("draft_f")  (memoised)        │ fork("sim_3") → "ai_f/sim_3" (1 parent draw)
   │  snapshot() {run_seed, data_version, streams{name: draws}}     ▼
   │  restore(snap) → reseed + discard draws                 randi32() ← the only generator call
   ▼
MatchConfig{rng_match, rng_ai, log} ──► RulesEngine ──primitives──► EventLog.append(type, payload, cause_seq)
                                           ▲                            │ seq, turn stamped; sealed? cap?
                                   BossAI (reads stream)                ▼
                                                                 subscribers (main thread, sync, in order)
                                                                 │ MatchViewState.apply → AnimationQueue (cause_seq root)
                                                                 │ (planner writes only its clone's scratch log; replay in tick())
                                                                 ▼
                                             match_ended → sealed → reduce_to_summary() → run log
                                                                 └─ to_json() → user://logs/<run_id>/floor_n_attempt_k.json
```

### Key Interfaces

Signatures match `docs/architecture/architecture.md` §API Boundaries
(Foundation); `tests/helpers/` field names are normative.

```gdscript
# src/core/rng/rng_service.gd — rng-event-log rules 1–6, 10; F1–F3, F5
class_name RngService extends RefCounted
func _init(run_seed: int, data_version: String) -> void
func stream(name: String) -> RngStream          # memoised; name matches ^[a-z]+(_[0-9]+)?(/[a-z0-9_]+)*$
func snapshot() -> Dictionary                   # {run_seed: int, data_version, streams: {name: draws}}; {} + error mid-command
func restore(snapshot: Dictionary) -> Error     # ERR_INVALID_DATA on data_version mismatch; creates nothing then
func begin_command() -> void; func end_command() -> void   # snapshot() is refused between them (Edge Cases)
func snapshot_to_json_dict() -> Dictionary      # run_seed → run_seed_hex (rule: 64-bit values cross JSON as hex)
static func snapshot_from_json_dict(d: Dictionary) -> Dictionary
static func run_seed_from_input(input: String, entropy: Callable) -> int   # F1; entropy() only for the empty branch
static func stream_seed_for(run_seed: int, name: String) -> int           # F2 (FNV-1a 64 + mix64)
static func fork_seed(parent_draw: int, parent_name: String, label: String) -> int   # F3
static func to_hex_u64(v: int) -> String; static func parse_hex_u64(hex16: String) -> int

# src/core/rng/rng_stream.gd — rules 4–5; F4
class_name RngStream extends RefCounted         # one RandomNumberGenerator per stream, seed set once
var name: String; var draws: int
func randi_range(lo: int, hi: int) -> int       # 1 draw; span ≤ 65,536 (assert debug / return lo release, no draw)
func randf() -> float                           # 1 draw; randi32() / 2^32; weight normalisation only
func shuffle(array: Array) -> void              # Fisher–Yates, exactly n − 1 draws (0 for n ≤ 1)
func weighted_pick(weights: Array) -> int       # 1 draw; integer weights, 0 < total ≤ 65,536; -1 + error otherwise, no draw
func fork(label: String) -> RngStream           # 1 parent draw on first call; memoised "<name>/<label>"
func randi32() -> int                           # the F4 primitive; draws += 1; NOT for rules code (lint-gated outside src/core/rng/)

# src/core/log/event_log.gd — rules 11–19; F6, F7
class_name EventLog extends RefCounted
func _init(max_events: int, scope: String, meta: Dictionary = {}) -> void   # max_events from the composition root (F7); meta = {engine_version, data_version, run_seed_hex, floor}
func append(type: StringName, payload: Dictionary, cause_seq: int = 0) -> int   # returns seq; -1 when sealed/dropped
func set_turn(turn: int) -> void
func subscribe(callback: Callable) -> void      # callback(event: Dictionary) once per event, seq order, after append, same thread
func events_since(seq: int) -> Array[Dictionary]  # seq < 0 → all; seq ≥ last → []
func snapshot() -> Dictionary; func to_json() -> String; static func from_json(text: String) -> EventLog
func reduce_to_summary() -> Dictionary          # match_summary incl. damage_by_card (rule 19)
func is_sealed() -> bool; func size() -> int
signal overflowed(cap: int, seq: int)           # the Faulted transition; the engine answers with match_ended(fault)
```

Event shape (rule 11), identical in memory and in `to_json()`:
`{seq: int, turn: int, type: String, payload: Dictionary, cause_seq: int}`.

### Implementation Guidelines

- Must construct `RngService` and `EventLog` in `RunMachine` / `MatchDriver`
  (rules side) and in tests directly; must never obtain them through `Boot`,
  a static, or an autoload.
- Must route every random decision under `src/gameplay/**`, `src/ai/**` through
  an injected `RngStream`; must never call `randi`, `randf`, `randi_range`,
  `randomize`, `Array.shuffle`, `Array.pick_random`, `RandomNumberGenerator.new`
  there (lint `tools/lint/no_global_rng.sh`, CI-blocking).
- Must draw only while a command is being processed (rule 8); must never draw
  in `_init`, in UI code, or in idle frames.
- Must keep `draws` exact: every primitive consumes the F4 count and nothing
  else; must never add a "free" draw for convenience.
- Must emit exactly one event per state mutation, after the mutation, with
  `cause_seq` = the outer event's `seq` during nested resolution; must never
  emit zero or two events for one mutation.
- Must put diagnostics on the same log with `payload.diagnostic = true`; must
  never create a second event channel or a log filter in `src/core/log/`.
- Must keep subscriber callbacks on the main thread; a worker plans on a clone
  and must never append to or subscribe to the live log — the driver replays
  the plan on `tick()` (ADR-0006/0008).
- Must serialise 64-bit values (`run_seed`, any hash) as 16-hex strings and
  must never trust `JSON.parse_string` to return an `int`; must coerce
  integral floats back to `int` on load.
- Must take `max_events`, `keep_match_logs` and `avg_event_bytes` from
  `config("rng_event_log")` at the composition root; must never hardcode them.
- Must override typed methods with an explicit `return` (4.7 inherited-return
  rule) and must type every Array (`Array[Dictionary]`, `Array[int]`).
- Must write `user://logs/**` only through ADR-0004's `AtomicFileWriter` with
  `DirAccess.make_dir_recursive_absolute` first.

## Alternatives Considered

### Alternative 1: Global seeded RNG (`seed()` + `randi()` / `Array.shuffle()`)
- **Description**: Call `seed(run_seed)` once at run start and use the global
  functions everywhere, as the prototype did minus the `randomize()`.
- **Pros**: Zero plumbing; familiar.
- **Cons**: One sequence shared by rules, AI simulation, drafts and any UI
  shuffle means every extra call anywhere shifts every later draw — a Discover
  preview or an AI forecast would change the next floor's offers; untestable in
  isolation; no per-stream `draws` for `snapshot`/`restore`; exactly TD-007.
- **Estimated Effort**: Lowest.
- **Rejection Reason**: Breaks rule 7, rule 10 and DD-R09; it is the pattern
  the tech-debt register exists to retire.

### Alternative 2: One `RandomNumberGenerator`, streams as counters over it
- **Description**: A single generator; "streams" are logical labels that
  record how many draws they made, all pulling from one sequence.
- **Pros**: One engine object; simple snapshot (`state` or total draws).
- **Cons**: Streams are not independent — the boss AI's sandbox forks (`sim_<turn>`)
  would perturb `match_<floor>`; F2's property "`match_1` and `match_2` share no
  bit pattern" is lost; `fork` cannot be memoised deterministically.
- **Estimated Effort**: Low.
- **Rejection Reason**: Violates rule 2 (memoised independent streams) and
  boss-ai C9's sandbox contract.

### Alternative 3: Snapshot via `RandomNumberGenerator.state` instead of `draws`
- **Description**: Persist each stream's `state` (a 64-bit `int`, observed
  settable, probe D4) and restore it directly — O(1) instead of O(draws).
- **Pros**: Faster restore; no discard loop.
- **Cons**: Opaque engine-internal value; **corrupted by JSON** (probe E:
  `parse_string` yields `float`, precision lost above 2^53) unless also hex-
  encoded; ties the save format to the generator algorithm; `draws` is still
  needed for F6/F7 bookkeeping and for the AC "draws increased by 14".
- **Estimated Effort**: Same.
- **Rejection Reason**: F5's 5 ms budget at 10,000 draws is comfortably met by
  the discard loop (probe D showed 100,000 `randi()` calls in well under the
  budget), so the opacity and serialisation cost buys nothing. Kept as an
  allowed optimisation only if a test proves identical next outputs (F5 note),
  which probe D5 already did — recorded, not adopted.

### Alternative 4: Hand-written PRNG in GDScript (xoshiro / PCG) instead of `RandomNumberGenerator`
- **Description**: Implement the generator in script so the sequence is
  independent of engine versions.
- **Pros**: Replay across engine upgrades; algorithm fully specified.
- **Cons**: Slower in GDScript (every draw is several 64-bit multiplies and
  masks); more code to get wrong; the GDD (rule 6, rule 9) deliberately scopes
  replay to "within one engine version".
- **Estimated Effort**: Medium.
- **Rejection Reason**: Solves a problem the design declines to have; QQ-06
  tracks algorithm stability across 4.7.x patches by re-running the seed pins
  on every bump, which is cheaper than owning a PRNG.

### Alternative 5: Signals instead of `subscribe(callback)` for event delivery
- **Description**: `EventLog` emits a `event_appended(event)` signal.
- **Pros**: Idiomatic Godot; automatic disconnection when the receiver is
  freed.
- **Cons**: A signal with a `Dictionary` payload is equivalent in cost but
  loses the "once, in `seq` order, after append" guarantee's testability
  (connection flags and `CONNECT_DEFERRED` can reorder); `Callable` lists make
  the re-entrancy check (Edge Cases) explicit; `TestEventLog` already uses the
  callback form and 66 tests exercise it.
- **Estimated Effort**: Same.
- **Rejection Reason**: The callback contract is the GDD's wording and the
  helpers' shape; the `overflowed` signal is kept where a signal is right (one
  rare transition the engine must answer).

## Consequences

### Positive
- Every rules test is deterministic by construction: literal seeds, exact draw
  counts, `replay_equal` as the suite's determinism rule (TD-012 determinism
  half).
- One log is the bug report: diagnostics, rejected commands and mutations are
  one ordered stream with causal links; `AnimationQueue` grouping and the
  replay viewer read the same data.
- The save format carries only `draws` counts and hex seeds — small, readable,
  engine-internal-free — and a `data_version` mismatch is detected before any
  stream is rebuilt.
- The helpers' `TODO(E1)` swap is a type change, not a rename: `MatchFactory`,
  `RunFactory`, `EventLogAssertions` keep working against the production
  classes.

### Negative
- Replay equivalence is per engine version: an engine bump invalidates replay
  of archived logs (labelled "not replayable (engine changed)", Edge Cases).
  Accepted by rule 9.
- The reseed-and-discard restore is O(draws); at the AC ceiling (10,000 per
  stream) it is bounded at 5 ms per stream, and a resume rebuilds up to four
  streams per floor — still inside run-ui's `restart_budget_ms`.
- The hex rule for 64-bit values is one more thing every persister must
  remember; the lint cannot catch a forgotten conversion, only the round-trip
  tests can.
- The subscriber contract pushes the thread-safety burden onto `MatchDriver`
  (ADR-0006) rather than into the log; a future subscriber added on the worker
  side would be a silent bug until the debug `assert` on thread id fires.

### Neutral
- `EventLog` takes `max_events` as a constructor argument rather than reading a
  config itself; the composition root does the F7 division. This keeps the log
  free of any database reference at the cost of one more argument.
- `RngStream.randi32()` is public (the helpers need it for scripted doubles and
  the F3 parent draw) but lint-gated outside `src/core/rng/` and `tests/`.

## Risks
- **`RandomNumberGenerator` algorithm changes in a 4.7.x patch** — replay of
  archived logs breaks silently. *Mitigation*: the F1/F2 seed pins and a
  100-draw golden sequence (`tests/unit/rng_event_log/rng_engine_pins_test.gd`)
  fail on the bump; `engine_version` is in every `to_json()` header so the
  viewer refuses rather than mis-replays.
- **A subscriber runs off the main thread** once ADR-0006 lands — UI code on a
  worker. *Mitigation*: debug-build `assert(OS.get_thread_caller_id() ==
  OS.get_main_thread_id())` inside the notify loop (API verified in probe A);
  the clone-and-replay rule (ADR-0006/0008; `architecture.md` Data Flow §2).
- **Payload drift makes two logs of one run differ in float formatting**.
  *Mitigation*: canonical JSON (6 decimals) in both `to_json()` and the test
  assertion; gameplay quantities are ints by design.
- **Developers forget the hex rule** for a new 64-bit field. *Mitigation*:
  `RngService.snapshot_to_json_dict()` is the only sanctioned path for the seed;
  round-trip tests on `RunRecord` (ADR-0004) include a seed above 2^53.
- **`avg_event_bytes` estimate (200) is wrong** so the 2 MB budget is
  mis-converted. *Mitigation*: the knob is data; the Vertical Slice measures
  real logs and `/balance-check` reports the mean (rng-event-log Tuning Knobs).

## GDD Requirements Addressed

TR-IDs are the provisional ids from `docs/architecture/architecture.md`
§Technical Requirements Baseline; `/architecture-review` registers them.

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| rng-event-log.md | TR-rng-event-log-001 — rules 1–6: one `RngService(run_seed, data_version)`, memoised named streams, `fork`, F4 draw API | `RngService.stream()` memoisation, `RngStream` over one `RandomNumberGenerator`, F2/F3 derivation verified bit-exact (probe D7) |
| rng-event-log.md | TR-rng-event-log-002 — rule 7: no global RNG under the rules tree | CI lint `tools/lint/no_global_rng.sh`; randomness only as an injected `RngStream`; the single entropy call allow-listed by path |
| rng-event-log.md | TR-rng-event-log-003 — rules 9–10: replay equivalence, `snapshot()` / `restore()` by `draws` | Reseed-and-discard restore (F5), `data_version` rejection, `begin_command`/`end_command` guard; F6 `replay_equal` as the suite rule |
| rng-event-log.md | TR-rng-event-log-004 — rules 11–15: envelope, one event per mutation, JSON-only payloads, sealing, `subscribe` / `events_since` | `EventLog.append` as the only writer, synchronous ordered subscribers, sealing on `match_ended` / `run_ended`, payload coercion rules |
| rng-event-log.md | TR-rng-event-log-005 — rule 12a: diagnostics on the same log | Decision item 6: `payload.diagnostic = true`, no second channel, no filter in core |
| rng-event-log.md | TR-rng-event-log-006 — F7 / rule 18: `max_match_events` from the byte budget; `user://logs/<run_id>/…` when `keep_match_logs` | `max_events` computed at the composition root from `config("rng_event_log")`; fault logs always written; archive via `AtomicFileWriter` |
| match-rules.md | TR-match-rules-007 (C15 event vocabulary, DD-X04) and TR-match-rules-004 (`MatchConfig{rng_match, rng_ai, log}`) | The log stores whatever C15 names; `MatchConfig` carries `RngStream` handles and one `EventLog` (no `seed` field) |
| run-structure.md | TR-run-structure-004 — R7/R8: `rng_snapshot` in the `RunRecord`, resume restores streams, reopens a **new** run log; retry at `draws = 0` | `snapshot_to_json_dict()` / `restore()`; `EventLog.from_json` builds a new instance; `match_<f>` / `ai_<f>` are simply re-requested after restore |
| match-ui.md | TR-match-ui-002 — U4: `AnimStep` groups by `cause_seq` root; TR-match-ui-003 — U6: boss turn already in the log | `cause_seq` stamped by the caller, `seq` by the log; events are in the log before any subscriber or buffer sees them |
| boss-ai.md | TR-boss-ai-001 — pure function of (state, profile, stream position) | `ai_<f>` stream and memoised `fork("sim_<turn>")` give the planner a deterministic, isolated source |
| design-decisions.md | DD-T03, DD-T04, DD-R09 | The decision is these three rows made concrete |
| reward-draft.md | TR-reward-draft-001 — D1: `init_run(run_state) → draft_state`, `offer(kind, run_state, stream) → Offer{option_ids[], flags[]}`, `pick(kind, id, offer, run_state) → Pick`; `offer` is a pure function of (run_state, stream position) and mutates nothing | `offer` draws only from the injected `draft_<floor>` stream (`RngService.stream("draft_<f>")`, rule 1–6) — never a global RNG (rule 7 lint `no_global_rng.sh` covers `src/gameplay/`); purity over (run_state, stream position) is the F6 `replay_equal` property applied to the draft: same `RunRecord` + same `draws` ⇒ same `Offer`; `draft_offered` / `draft_pick` land on the run log (rule 11) |
| reward-draft.md | TR-reward-draft-002 — D3, D7: exclusion and pity derived from `run_state.drafts[]`; pool snapshot once at `init_run` | Rules side of the derivation: `drafts[]` is a JSON-only field of the persisted `RunRecord` (rule 14; `rng_snapshot` beside it), so pity needs no separate state — restore rebuilds the stream by `draws` and `drafts[]` reads back verbatim, and the next `offer` is identical (F6); pool half in ADR-0005 |
| content.md | TR-content-002 — CN-6.4: archived run logs and sim outputs are the inputs of `/balance-check` | The archives this ADR produces: `user://runs/<run_id>.json` (via `archive_run`, `to_json()`) and `user://logs/<run_id>/floor_<n>_attempt_<k>.json` (rule 18, `keep_match_logs`), plus `production/qa/sim/<boss_id>_<date>.json` from the ADR-0006 harness — all JSON with the rule-11 envelope, so the tooling reads one format |

## TD Items Retired

| TD | Prototype root cause | How this ADR rules it out |
|---|---|---|
| **TD-007** (retired) | Unseeded global RNG in `game_manager.gd`, `victory_selection.gd`, `shop_screen.gd`, `start_screen.gd`, `card_effect_base.gd`, `card_data.gd`, `minion_tags.gd` | One injected `RngService`; the rule 7 lint fails CI on any global-RNG call under `src/` outside `src/ui/` and `src/core/rng/`; `instance_id` assignment is Match Rules' counter, not `randi()` |
| TD-012 (determinism half; the rest is ADR-0001 / `/test-setup`) | No tests, and nothing could have been deterministic | Literal seeds per test, exact draw counts, `replay_equal` as the suite's determinism rule; the helpers already model this |

## Engine Compatibility Details

| Claim | Source / status |
|---|---|
| `RandomNumberGenerator.seed` set twice to 42 ⇒ identical 100-value `randi()` sequences across two instances; reseed restores the sequence | **Observed**, probe D1/D2 (`godot --headless --path . -s res://probe_rng.gd`, 4.7.2, 2026-11-03) |
| `seed` accepts negative / full-range int64 values; different seeds give different first outputs | **Observed**, probe D3 |
| `RandomNumberGenerator.state` is a settable `int`; state restore and reseed-and-discard yield the same next 5 outputs | **Observed**, probe D4/D5 — not relied on (Alternative 3) |
| `randi()` ∈ `[0, 2^32 − 1]` (100,000 samples) | **Observed**, probe D6 |
| GDScript `int` wraps mod 2^64 on multiply/add; F2 example `fnv1a64(le8(42)++"run") = D2063F87976A8AC8`, `mix64 → 60FB31FFA0FECE9A` | **Observed**, probe D7 — matches rng-event-log F2 examples |
| `JSON.parse_string` returns `float` for every number; exact only up to 2^53; `StringName` serialises as `String`; `JSON.stringify(d, "\t")` pretty-prints with sorted keys on 4.7.2; `parse_string` returns `null` and logs on bad input, `JSON.new().parse()` gives line + message | **Observed**, probe E |
| Typed-method overrides need an explicit `return`; lambdas capture by value; typed Arrays preferred | **Sourced**: `breaking-changes.md` 4.6→4.7, `current-best-practices.md` §GDScript, `deprecated-apis.md` Patterns |
| `OS.get_thread_caller_id()` / `OS.get_main_thread_id()` exist | **Observed**, spike probe A (verified API list) |
| `DirAccess.make_dir_recursive_absolute` needed before writing into `user://logs/<run_id>/` | **Observed**, spike probe B |
| `RandomNumberGenerator` algorithm identity / stability across 4.7.x patches | **NOT SOURCEABLE** — no Core page in `docs/engine-reference/godot/`; covered by the golden-sequence test on every bump (QQ-06) |
| `Time.get_ticks_usec()` for the perf tests | Pre-4.0 API (`deprecated-apis.md` row: use `Time`, not `OS.get_ticks_msec`) — LOW |

Probe D/E scripts and raw output: scratch, outside the repo
(`…/scratchpad/probes/probe_rng/probe_rng.gd`, `probe_rng.out`, `probe_json.gd`,
`probe_json.out`); the durable record is this section plus
`tests/unit/rng_event_log/rng_engine_pins_test.gd` once E1 lands.

## Verification — How We Know

| Question | Proof | Where |
|---|---|---|
| Same seed, same sequence on this engine | probe D1/D2 passed; becomes `test_same_seed_produces_identical_100_draws` | `tests/unit/rng_event_log/rng_stream_test.gd` |
| F1/F2 constants survive signed int64 | probe D7 matched the GDD examples; helper pins exist (`test_stream_seed_matches_gdd_f2_examples`, `test_run_seed_from_input_matches_gdd_f1_examples`) | `tests/unit/framework/test_helpers_test.gd` → moves to `tests/unit/rng_event_log/` |
| Golden sequence pinned against engine drift | 100 `randi()` outputs after `seed = 42` (first three: 492690617, 1919685028, 3561993920 on 4.7.2) asserted; a failure names the engine, not the code | `tests/unit/rng_event_log/rng_engine_pins_test.gd` (new) |
| `restore` reproduces the next 20 outputs after `draws = 37`; shuffle twice gives identical order and +14 draws each | GDD AC 4–5 | `rng_service_test.gd` |
| `fork` memoised, one parent draw | GDD AC 6 (helper already passes `test_fork_twice_returns_same_object_and_one_parent_draw`) | `rng_stream_test.gd` |
| No global RNG under rules | lint over `src/` (rule 7 AC) | `tools/lint/no_global_rng.sh` in CI; `tests/unit/rng_event_log/rng_lint_test.gd` runs it headless |
| Envelope, ordering, `events_since`, subscriber once-in-order | GDD AC 9–10 | `event_log_test.gd` |
| Overflow: `log_overflow` then one more append then sealed | GDD AC 11 | `event_log_test.gd` with `max_events = 5` |
| Non-JSON payload coerced with `_coerced[]` (release path) | GDD AC 12 | `event_log_test.gd` |
| `to_json` → `from_json` is `replay_equal`, including a `run_seed` above 2^53 and `StringName` types | GDD AC 13 + the hex rule | `event_log_serialization_test.gd` |
| rule 19 `damage_by_card == {"card_a": 12}` | GDD AC 14 | `event_log_summary_test.gd` |
| Diagnostic `command_rejected` round-trips (rule 12a) | GDD AC 15 | `event_log_test.gd` |
| `data_version` mismatch → error, nothing created | GDD AC 16 (helper passes `test_restore_rejects_data_version_mismatch`) | `rng_service_test.gd` |
| Perf: 10,000 appends + `events_since(0)` < 50 ms; `restore(10,000)` < 5 ms | GDD AC 17 | `rng_event_log_perf_test.gd` (thresholds fail the test) |
| Two runs, seed 42, hero War, same commands ⇒ equal `run_started.boss_ids[]` and floor-1 `draft_offered.option_ids[]` | GDD AC 3 (needs Run Structure + Reward Draft) | `tests/integration/rng_event_log/replay_equivalence_test.gd` |
| Manual: seed shown on the death screen reproduces floor-1 boss and offers | GDD AC 18 | playtest note under `production/qa/evidence/` when run-ui lands |

## Performance Implications
- **CPU**: one `randi()` per draw plus integer arithmetic — negligible; a 36-card
  shuffle is 35 draws. `append` deep-copies the payload (typically < 10 keys);
  10,000 appends measured against the 50 ms AC. `restore` ≤ 5 ms per stream at
  10,000 draws.
- **Memory**: one `RandomNumberGenerator` per requested stream (≈ 4 per floor,
  plus forks) — bytes. Open match log ≤ `log_memory_budget_bytes` (2 MB) by
  construction of `max_events`; typical 60–400 KB.
- **Load Time**: none at boot (streams are created lazily on first request —
  rule "Unrequested" state). Resume: O(total draws) once.
- **Network**: n/a.

## Migration Plan

No production code exists; this is greenfield under `src/core/rng/` and
`src/core/log/`. Steps for the E1 stories: (1) land `RngStream`, `RngService`,
`EventLog` with the unit suites above; (2) swap `tests/helpers/test_rng_stream.gd`
seeded mode, `test_rng_service.gd` and `test_event_log.gd` to wrap or extend the
production classes (the `TODO(E1)` markers), keeping the scripted/constant
doubles; (3) move the F1/F2 pins and add the golden-sequence test; (4) add the
rule 7 lint to CI; (5) `MatchFactory.make_match_config` passes production
streams. The prototype's RNG call sites are not ported (TD register rule: retired
by the rewrite, never edited).

**Rollback plan**: the helpers remain a complete implementation of the contract;
if the production classes prove wrong, tests keep running on the doubles while
the classes are fixed. A change of generator or derivation is a new ADR
superseding this one (it invalidates every archived log).

## Validation Criteria

This decision is correct when: every test in the Verification table passes on
4.7.2 headless (`commands.test`, exit 0); the rule 7 lint finds zero hits
across `src/gameplay/`, `src/ai/`, `src/core/` (minus `src/core/rng/`); two
scripted runs of the Vertical Slice produce `replay_equal` logs; the seed pins
still pass after the first 4.7.x patch bump (or fail and are re-recorded with a
dated note — the test's job is to make the change visible); and the measured
`avg_event_bytes` on real match logs is within 100–400 so the 2 MB budget
converts to a cap above a real match's event count.

## Related
- Depends on: ADR-0001 (rules / presentation split). Enables: ADR-0004,
  ADR-0005, ADR-0006, ADR-0007, ADR-0008, ADR-0009 (see ADR Dependencies).
- `design/gdd/rng-event-log.md` (spec; Open Questions 1 and 6 closed by this
  ADR); `design/gdd/match-rules.md` C3, C15; `design/gdd/run-structure.md`
  R7–R9; `design/gdd/boss-ai.md` C1, C9; `design/gdd/match-ui.md` U3, U4;
  `design/design-decisions.md` DD-T03, DD-T04, DD-R09, DD-X04, DD-X08.
- `docs/architecture/architecture.md` §API Boundaries (Foundation), §Data Flow
  1–4, §Persistence paths, §Performance budgets, §Tech-debt retirement mapping.
- `docs/architecture/spikes/2026-11-03-engine-probes.md` (environment, probes
  A/B verified API list); probe D/E recorded in this ADR.
- `docs/tech-debt-register.md` TD-007, TD-012.
- Code (once implemented): `src/core/rng/rng_service.gd`,
  `src/core/rng/rng_stream.gd`, `src/core/log/event_log.gd`,
  `tools/lint/no_global_rng.sh`, `tests/unit/rng_event_log/`,
  `tests/integration/rng_event_log/`; today: `tests/helpers/test_rng_stream.gd`,
  `test_rng_service.gd`, `test_event_log.gd`, `event_log_assertions.gd`.
