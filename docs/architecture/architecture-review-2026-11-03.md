## Architecture Review Report
Date: 2026-11-03
Mode: full
Workflow: standard
Engine: Godot 4.7.2 (GDScript; pinned 4.7 — `docs/engine-reference/godot/VERSION.md`; installed 4.7.2 matches the pin)
GDDs Reviewed: 13 (N_gdd = 13 system GDDs under `design/gdd/`; `game-concept.md`, `systems-index.md` and the two cross-review logs are in the directory but are not system GDDs — the two cross-review logs were not read as requirement sources)
ADRs Reviewed: 11 (N_adr = 11; all `Accepted`; 11/11 carry `## Status`, `## Decision`, `## GDD Requirements Addressed`, `## Engine Compatibility`, `## ADR Dependencies` — no structural gaps)

Run conditions: headless pipeline run under the owner's standing approval (no `AskUserQuestion`; guided-mode recommended options taken). No `Agent` tool: the engine-specialist consultation did not run (see Engine Compatibility). Freshness check: `RECEIPT: NONE` — no prior `architecture-review-*.md`; `docs/consistency-failures.md` does not exist, so there are no known conflict-prone areas to carry in. Requirement source: the 70-row provisional baseline in `architecture.md` §Technical Requirements Baseline (its header says 71; the table holds 70), standing in for the per-GDD section extraction as `workflow: standard` allows, plus a targeted scan of `design/accessibility-requirements.md` and a term spot-check across the GDDs (screen reader / gamepad / SFX / audio / threading / autoload) that surfaced one requirement the baseline lacks.

Reviewed-Content-Hash: docs/architecture/adr-0001-rules-presentation-split.md f8cc209bd665e73125fc1b8bb398c15b9c429780
Reviewed-Content-Hash: docs/architecture/adr-0002-data-format-effect-schema-config-loading.md 98b071216910d22af0af98be42726a9f9d35e0fc
Reviewed-Content-Hash: docs/architecture/adr-0003-seeded-rng-service-and-event-log.md 515f546c059dc87a0af87b04677a89fb1300349c
Reviewed-Content-Hash: docs/architecture/adr-0004-save-format-and-atomic-profile-write.md 0e5dd80028daccc730424aef3a940e959ccd8e27
Reviewed-Content-Hash: docs/architecture/adr-0005-owner-scoped-hook-registry.md 70f37df3af3abd48250c5abde329ffb57facdcb8
Reviewed-Content-Hash: docs/architecture/adr-0006-boss-ai-planner-threading.md 0c188f9c6d0f19cffebff2523afab2f8797b740d
Reviewed-Content-Hash: docs/architecture/adr-0007-effect-resolver-validator-boundary.md da86245bd98845cc4c8fd986f2297da339af0dfa
Reviewed-Content-Hash: docs/architecture/adr-0008-match-driver-ownership-and-handoff.md 426de165e7de90b479fdbc3bece0ea0b3e3dd51d
Reviewed-Content-Hash: docs/architecture/adr-0009-match-ui-animation-queue-and-scene-partition.md 1037bdf5204cff3864f362069917a7be94e2de67
Reviewed-Content-Hash: docs/architecture/adr-0010-renderer-choice-vs-xvfb-screenshot-capture.md d3de59f06d1cc6b99a3260cac0ff27f0844d1be9
Reviewed-Content-Hash: docs/architecture/adr-0011-run-ui-shell-and-meta-stub-seam.md b675064f5a18b3df1939d1626eb9ab6626b17ea5
Reviewed-Content-Hash: design/gdd/boss-ai.md 52a22dfc786a4c0156c98feeba1c8876a1afe00a
Reviewed-Content-Hash: design/gdd/card-database.md 7a70a98d988e62a56929d4c06fe1bdf328016712
Reviewed-Content-Hash: design/gdd/card-effects.md 3ad4c403613cbe3ea2799f6e4df4ca8861ceaae1
Reviewed-Content-Hash: design/gdd/content.md 071d41dba1dbf65601f29f65ef3aca42d4b6ef15
Reviewed-Content-Hash: design/gdd/game-concept.md 7b53c9052605f0613e566bd3d056e5518b37a5c8
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03.md c735c9738a373e58a095ba1c942ee89f0de6685a
Reviewed-Content-Hash: design/gdd/gdd-cross-review-2026-11-03b.md d39029f51d61bb8853932afe786b799292652ad5
Reviewed-Content-Hash: design/gdd/heroes.md a18f9b8b028f70794e33af62739d86f0298096ec
Reviewed-Content-Hash: design/gdd/match-rules.md 7af4351b32a419195d38bf274c2a68b9c63aa804
Reviewed-Content-Hash: design/gdd/match-ui.md 75d9de982aa1a6b590b04e9e06d078c53f60faff
Reviewed-Content-Hash: design/gdd/meta-progression.md 5ff5ad7343c2a160e5b36ede1818b4784bf341ac
Reviewed-Content-Hash: design/gdd/reward-draft.md 341815e715e44e157e38e94eb7d19d62c59d6f13
Reviewed-Content-Hash: design/gdd/rng-event-log.md 0ebe62aa31f6a301dcaa9f3209fe6ce7e3d58010
Reviewed-Content-Hash: design/gdd/run-structure.md b2fd1a52241c7d60c2a7dae6114751fecd454b4d
Reviewed-Content-Hash: design/gdd/run-ui.md 878fda8a901a9e4b97e494771273b5753f911538
Reviewed-Content-Hash: design/gdd/systems-index.md 583c81ca47b0e1a9b60cc37a1b755ead97e5f64a
Reviewed-Content-Hash: design/gdd/treasures.md b50806cc8b2b5117b0064b934122be5ecaced4ad
Reviewed-Content-Hash: docs/architecture/tr-registry.yaml 2b4d4fe9fb6743819a9f3b60556b659258c5764c
Reviewed-Content-Hash: docs/architecture/architecture.md 95e2d53e479b850f7ef1fc67a595c3e0393371f7
Reviewed-Content-Hash: docs/engine-reference/godot/VERSION.md bd96636f87d8fe8039cdec688d3c580d347a823a
Reviewed-Content-Hash: docs/engine-reference/godot/breaking-changes.md 4bc55e16796664ff88c7582c9f08e3530f7c94d4
Reviewed-Content-Hash: docs/engine-reference/godot/current-best-practices.md a45cd2c39a8ec53eaa3e924f39f93594e62085fd
Reviewed-Content-Hash: docs/engine-reference/godot/deprecated-apis.md 6a1353983e1db0d7bc0cc41a568b039495b5413c
Reviewed-Content-Hash: docs/engine-reference/godot/modules/animation.md ee51f50a46f8c63b771f62fe438947d4d84c59e3
Reviewed-Content-Hash: docs/engine-reference/godot/modules/audio.md c72af247505908a04f84a1dd3e765939efe700bd
Reviewed-Content-Hash: docs/engine-reference/godot/modules/input.md 3406b1b813858898696e510ea0accfcc7df98af8
Reviewed-Content-Hash: docs/engine-reference/godot/modules/navigation.md 7ae18ffbd2c3230cb19d610373225bfba187a472
Reviewed-Content-Hash: docs/engine-reference/godot/modules/networking.md 6606880462a2241014f77feb9610c5611e659ec6
Reviewed-Content-Hash: docs/engine-reference/godot/modules/physics.md 3b6ac8947f3f3e8c9ac9e6e0ff6cac06fdb8d805
Reviewed-Content-Hash: docs/engine-reference/godot/modules/rendering.md 2a303185bb57eed31dd1151a036784820747b211
Reviewed-Content-Hash: docs/engine-reference/godot/modules/ui.md 30ad166ab8c4e92c15aa37ed3464483b92b7845b
Reviewed-Content-Hash: project.yaml 75715dd41c97e6ce2d111ac1efbf1d02ecd8a813
Reviewed-Content-Hash: .claude/docs/technical-preferences.md dc34aff1c3705e041c8d016bb7f24b2a0bcb8571
Reviewed-Content-Hash: .claude/skills/architecture-review/SKILL.md 1a9d28aadbcbd26b5fc6b8ed1c64d73ae82b7b73
Reviewed-Content-Hash: .claude/skills/architecture-review/references/1-load.md 9a65759ebdbb2cb1f9744775bfed18cb25e76347
Reviewed-Content-Hash: .claude/skills/architecture-review/references/2-extract-requirements.md d08ea0b0e9ab9760b0d8bfe0cd9115f0bc40f8e2
Reviewed-Content-Hash: .claude/skills/architecture-review/references/3-traceability.md bb7b6b65c5e5e5b8869fa692413aa831615dede7
Reviewed-Content-Hash: .claude/skills/architecture-review/references/4-conflicts.md 0d30f8173b23248a32523a365b606dd1ce9642ab
Reviewed-Content-Hash: .claude/skills/architecture-review/references/5-engine.md 318ecbc1361d430badaf5dd8ce4cfc6ab0dff0ca
Reviewed-Content-Hash: .claude/skills/architecture-review/references/6-document-coverage.md dcce78482ec2ce60048989b6f9d1f797dd0a9a0e
Reviewed-Content-Hash: .claude/skills/architecture-review/references/7-report.md a007fd66bdac87812dc272e4b14cd231174e979d
Reviewed-Content-Hash: .claude/skills/architecture-review/references/8-write.md bf6d8946fc7b9e19eda7f65503a5c8f593a0d2b1
Reviewed-Content-Hash: .claude/skills/architecture-review/references/9-handoff.md fd5f681f4c3517c6a2e388c6d78075d82dded22e
(`docs/consistency-failures.md`: not stamped, no such file — optional input.)

---

### Traceability Summary
Total requirements: 71 (70 baseline rows registered under the IDs the ADRs already cite — no provisional-ID renames; 1 new: `TR-accessibility-requirements-001`)
✅ Covered: 63 (all by `Accepted` ADRs; 🟡 Covered-by-Proposed: 0; ❓ Not assessed: 0)
⚠️ Partial: 7
❌ Gaps: 1

The full matrix is in `docs/architecture/requirements-traceability.md`. The TR registry now holds all 71 IDs (`bash .claude/scripts/registry.sh validate`: 71 entries, duplicate 0, path_missing 0, status 0, layout 0). ID renames: none — every provisional `TR-<system>-NNN` the ADRs cite was free and is now permanent.

### Coverage Gaps (no ADR exists)

  ❌ TR-accessibility-requirements-001: accessibility-requirements.md → Accessibility (Motor, Standard tier) → full input remapping with bindings that persist across restarts; storage undecided (meta M9 `bindings` map vs `InputMap` serialised to `user://bindings.cfg` by Run UI)
     Suggested ADR: "/architecture-decision input-remapping-storage"
     Domain: Presentation / Persistence
     Engine Risk: LOW (`InputMap` is pre-4.3; the 4.5 SDL3 gamepad driver matters only post-v1)
     Layer / timing: Feature-Presentation, due Alpha — not a Foundation/Core gap, so not blocking.

Partial rows (implicit or half coverage; close by citing the row in the named ADR's `## GDD Requirements Addressed` table — no new ADR required at `standard`):

| TR | What is covered | What is not | Close in |
|---|---|---|---|
| TR-match-rules-008 | ADR-0009 cites it (caller side); ADR-0007 Performance Implications (`targeting_spec` memo keeps `legal_commands()` ≤ 2 ms) | No ADR decides how the engine meets ≤ 5 ms / ≤ 2 ms — a budget proven by the Match Rules performance test | ADR-0007 |
| TR-boss-ai-004 | ADR-0008 Decision 3 (`ai_intent_shown` appended by the driver), Decision 7 (`telegraph_mode` forwarded to `BossAI`); ADR-0006 main-thread append | Neither table cites it; `effective_mode = min(...)` is BossAI logic (no ADR needed) | ADR-0008 |
| TR-boss-ai-005 | ADR-0002 serves `config("ai_profiles")` and the stage-7 validator slot; ADR-0008 `ProfileResolver.resolve(...)` call site | The `runtime{planner_mode, slice_ms, replay_budget_ms}` block ADR-0006 proposes has no data owner (open since acceptance) | ADR-0002 / ADR-0006 after the owner is assigned |
| TR-reward-draft-001 | ADR-0011 (`Offer` read model; `pick(index)` → `draft_pick`); purity follows ADR-0003's rule-7 lint; API in `architecture.md` §API Boundaries | No ADR decides the Reward Draft API or its `draft_<f>` stream injection | ADR-0003 row, or a small Feature-layer ADR if the contract should be binding |
| TR-reward-draft-002 | ADR-0005 Decision 10 (`Treasures.pool()` called once from `init_run`) | Pity/exclusion derived from `run_state.drafts[]` (no separate pity state) is in no ADR | ADR-0005 row |
| TR-content-002 | ADR-0003 produces the archives, ADR-0006 the harness output | Tooling input contract only; none needed | ADR-0003 row |
| TR-systems-index-003 | ADR-0005 (QQ-08 pool edge); ADR-0011 routes `treasure_granted` | The emitter of `treasure_granted` (RunMachine per systems-index) is named in no ADR table | ADR-0005 row |

Audio: no requirement extracted — systems-index assigns minimal SFX to Match UI / Run UI stories; the 4.7 `area_mask` default change does not apply to a plain `AudioStreamPlayer` (architecture.md). Screen reader: `accessibility-requirements.md` records it as informational, not a tier commitment — no TR.

### Cross-ADR Conflicts

Registry baseline (`docs/registry/architecture.yaml`, 10 state / 13 interfaces / 7 budgets / 8 api / 17 forbidden): no state has two owners; no interface is declared with two patterns; no total frame budget is registered and the only per-frame allocation is `boss_ai_main_thread` 2.0 ms, so no budget sum can exceed a total; every forbidden pattern names its ADR. No 🔴 conflict was found; one 🟡 numeric drift and three advisories:

## Conflict: ADR-0006 vs ADR-0008 — 🟡 minor
Type: Performance (documented default)
ADR-0006 claims: `replay_budget_ms` defaults to **2** (Decision text line 227, Performance Implications, `ai_profiles.json` `runtime` proposal; registry `boss_ai_main_thread` notes say "default 2")
ADR-0008 claims: Performance Implications — "`replay_budget_ms` (ADR-0006 default **4** ms, data-driven; A30 asserts the 2 ms AI share)"
Impact: none at runtime (the value is data-driven and the registry carries 2); doc drift only, but at 4 ms the A30 "≤ 2 ms AI per frame" assertion ADR-0008 cites in the same sentence cannot hold.
Resolution options:
  1. Correct ADR-0008 §Performance Implications to "default 2 ms" (one-line consistency edit, no decision change) — recommended.
  2. If 4 ms was intended, revise ADR-0006 and the registry note, and re-derive A30.

Advisories (not conflicts):
- **Soft dependency edges not declared.** ADR-0008 lists only ADR-0001 under `Depends On`, yet its Ordering Note asks for ADR-0007 to be accepted first, ADR-0004 says it enables 0008 (`save_active_run` at S1–S4) and ADR-0005 says it enables 0008 (`hook_installers`). The acceptance order actually used (0007, 0005 before 0008) honoured them; the script-derived implementation order below does not. Declaring 0007 (and optionally 0004, 0005) in ADR-0008's `Depends On` would make the graph say what the authors meant.
- **"No event buffer" wording in ADR-0008.** §Performance says the driver keeps "no event buffer"; Decision 8 has `RunShell` buffering run-scope events during a match. Both are true of different objects (driver vs shell); a reader of the Performance line alone could miss the shell rule. Clarify on the next edit.
- **`Boot` surface growth.** ADR-0001 fixes `Boot` as a composition root owning no game state; ADR-0004 gives it the lock heartbeat and settings-debounce `Timer`s plus the exit hook. Compatible (timers are not game state) but `/create-control-manifest` should list the allowed `Boot` responsibilities explicitly so the autoload does not re-grow into TD-001.

Carried open points from the acceptance checkpoint, not re-adjudicated here (GDD-side, not ADR-vs-ADR): run-structure R4 vs match-rules C14 on whether the seed rides in `MatchResult` (ADR-0003 has `MatchConfig` carry no `seed` field); DD-T01 note omitting `avg_event_bytes`; card-database States table vs stage-7 lookups.

### ADR Dependency Order

`bash .claude/scripts/adr-dep-graph.sh`: ADRS 11; 18 `Depends On` edges; `NO_DEPS_SECTION`: none; `UNFILLED_DEPS`: none (every ADR has a filled row — the graph is clean, not merely silent); `CYCLE`: none; `BLOCKED_BY_CYCLE`: none. All 11 ADRs are `Accepted`, so no edge points at a `Proposed` or missing ADR.

Recommended ADR Implementation Order (topologically sorted, as emitted):
Foundation (no dependencies):
  1. ADR-0001: Rules / Presentation Split
  2. ADR-0010: Renderer Choice vs Xvfb Screenshot Capture (position 5 in the emitted order; no dependencies)
Depends on Foundation:
  3. ADR-0002: Data format, effect schema/DSL and `config()` loading (requires 0001)
  4. ADR-0003: Seeded RNG Service and Event Log (requires 0001)
  5. ADR-0008: Match Driver Ownership and the Run ↔ Match ↔ UI Hand-off (requires 0001 — see the soft-edge advisory: in practice build after 0007)
  6. ADR-0004: Save Format and Atomic Profile Write (requires 0001, 0003)
  7. ADR-0006: Boss AI Planner Threading (requires 0001, 0008)
  8. ADR-0007: Effect Resolver / Validator Boundary (requires 0001, 0002)
Feature / Presentation layer:
  9. ADR-0009: Match UI Animation Queue and Scene Partition (requires 0001, 0003, 0008)
  10. ADR-0005: Owner-scoped Hook Registry (requires 0001, 0007)
  11. ADR-0011: Run UI Shell Pattern and the Meta Stub Injection Seam (requires 0001, 0004, 0008)

Emitted `ORDER:` adr-0001, adr-0002, adr-0003, adr-0008, adr-0010, adr-0004, adr-0006, adr-0007, adr-0009, adr-0005, adr-0011.

### GDD Revision Flags (Architecture → Design Feedback)

These GDD assumptions conflict with verified engine behaviour or accepted ADRs. The GDD should be revised before its system enters implementation.

| GDD | Assumption | Reality (from ADR/engine-reference) | Action |
|---|---|---|---|
| run-structure.md (R1 field table) | `run_seed` is an `int64` field of the `RunRecord` beside `run_seed_hex` | `JSON.parse_string` returns `float` for every number and is exact only to 2^53 (observed, ADR-0003 probe E on 4.7.2); ADR-0003 `persisted_int64` rule and ADR-0004 impose "every 64-bit value in JSON is a 16-hex string" on the record. The in-memory int is fine; the persisted form may carry `run_seed_hex` only (int re-derived on load) | Revise GDD — state the persisted form in R1; rng-event-log F-table rows 268/292 already say "displayed as 16 hex digits" and need only a "persisted as hex" note |

No other flags: `device == 0` appears in no GDD; meta-progression mentions power loss only for lock staleness, not as a durability claim (ADR-0004 Decision 5 does not claim it); match-ui U6's "already in the log" wording was reconciled by ADR-0009 (F4 computed at the first boss action group).

**Systems-index update: not applied.** This run was instructed not to edit GDDs; `design/gdd/systems-index.md` therefore still shows Run Structure as `Approved`. Apply `Status: Needs Revision` on the Run Structure row by hand or via `/propagate-design-change run-structure` when the R1 wording is fixed.

### Engine Compatibility Issues

### Engine Audit Results
Engine: Godot 4.7.2 (pinned 4.7)
ADRs with Engine Compatibility section: 11 / 11 total

Version consistency: all 11 ADRs cite 4.7.2 (0006/0009/0011 as "4.7, installed 4.7.2 stable"). No stale version references.

Deprecated API References:
  - None. The sweep (`yield(`, `.instance()`, `OS.get_ticks_msec`, `TileMap`, string `connect(`, `get_world()`, `width_in_percent`, `device == 0`, `DisplayServer.AccessibilityLiveMode`, `tap_back_pos`, `VisibilityNotifier`, `YSort`, `AssetLib`) matched only ban lists and "use instead" notes. `duplicate(true)` in ADR-0002/0005 is on plain containers; both ADRs state that the `duplicate_deep()` row concerns nested Resources — consistent with `deprecated-apis.md`.

Stale Version References:
  - None.

Post-Cutoff API Conflicts:
  - None. The shared post-cutoff facts — `@abstract` (4.5), typed-return overrides need `return` (4.7), lambdas capture by value, dual focus (4.6), `Control.offset_transform_*` (4.7), `Tween.tween_await()` (4.7), `InputEvent.DEVICE_ID_*` (4.7), `FileAccess.store_* -> bool` (4.4) — are stated identically across ADR-0001/0002/0003/0004/0005/0008/0009/0011 and each is present in the module docs the ADRs name (`modules/ui.md`, `modules/input.md`, `modules/animation.md`, `current-best-practices.md`, `breaking-changes.md`). ADR-0003's "`@abstract` not used here" and ADR-0001's use of it for `MetaApi`/`Screen`/`Presenter`/`PlannerTask` do not contradict.

NOT SOURCEABLE items the ADRs carry (each closed by an observed probe or gated by a named test — listed so the gate reads them as open engine risk, not as verified):
  - ADR-0006: `WorkerThreadPool` on Windows (probe A was Linux-only) — gated on the Windows export before the Boss AI epic closes; concurrent read-only `CardDatabase` access from a worker — `test_forecast_concurrency.gd`.
  - ADR-0004: `DirAccess.rename_absolute` over an existing target on Windows; no `fsync` on `flush()`/`close()` (durability gap accepted, not claimed) — `atomic_write_platform_test.gd` gated to the Vertical Slice.
  - ADR-0003: `RandomNumberGenerator` algorithm stability across 4.7.x — golden-sequence test on every engine bump (QQ-06).
  - ADR-0010: Forward+/D3D12 parity with Compatibility CI frames; lavapipe untested — per-UI-story Windows playtest row.
  - ADR-0009: export-filter syntax that excludes `match_debug_loader` — CI greps the `.pck` instead.
  - ADR-0011: exact API for recursive `Control` disable (feature sourced, name not); clipboard under Xvfb — tests assert the call, not the OS clipboard.
  - accessibility-requirements.md OQ: whether AccessKit announces `accessibility_live` regions without focus — informational only.

### Engine Specialist Findings
Engine validation: **NOT ASSESSED** — `godot-specialist` was not spawned: this session has no `Agent` tool. The audit above is the reference-doc cross-check only; no domain-expert second opinion on engine anti-patterns was obtained. This is a named gap, not a pass.

### Architecture Document Coverage

`docs/architecture/architecture.md` exists (103 KB, read by section).
- Systems in the layer map: 13 / 13 from `systems-index.md` (Meta Progression split persistence/rules; Content as data + tooling) — none missing.
- Data flow: §1–6 cover the player command path, the boss-turn thread boundary, Run ↔ Match ↔ UI hand-off, save/load, initialisation and data load — every cross-system edge the GDDs' Interactions sections and systems-index Circular Dependencies define (Run ↔ Meta, Match UI ↔ Run UI, Treasures ↔ Reward Draft) appears.
- API boundaries: Foundation, Core (Match Rules, Card Effects, Boss AI), Feature and Presentation sections exist; `RewardDraft`, `Treasures`, `Heroes` have API boundaries here even where no ADR cites them (the Partial rows above).
- Orphaned architecture: none — `Boot`, `SettingsBus`, `MatchDriver`, `AtomicFileWriter`, `PlannerTask` are modules of indexed systems, not systems without a GDD.
- **Stale sections (the document predates the ADRs' acceptance and was only partly refreshed):**
  - §Document Status: "ADRs Referenced: none exist yet" and "TR registry … empty"; §ADR Audit: "No numbered ADR exists … 0 of 71 provisional requirements are covered" — all eleven ADRs are Accepted and the registry is populated.
  - §Threading model heading still reads "placeholder — resolved by ADR-0006" and its closing paragraph still says the mechanism is undecided with time-slicing as the sole implementation; the table rows were updated to plan-over-clone, the prose was not. ADR-0006 decided `WorkerThreadPool` default with `TimeSlicedPlannerTask` as the data-selected fallback.
  - §Technical Requirements Baseline header says 71 requirements; the table holds 70.
  - §Data Flow 5 lists eleven `configs:` keys without `rng_event_log`; ADR-0002 (after the acceptance edit) serves thirteen and ADR-0003 reads `config("rng_event_log")`. §Module Ownership and §Required ADRs still say `JSON.parse_string` where ADR-0002 decided `JSON.new().parse()` inside `DataLoader`.
  - §Data Flow 3 line "RulesEngine → match_ended → RunMachine._on_match_ended" — ADR-0008 forbids connecting `RulesEngine.match_ended` in production; the driver's own signal is connected (the preceding line already shows `driver.match_ended.connect`).
  Action: `/propagate-design-change` is for GDD-triggered staleness; these are ADR-triggered, so refresh `architecture.md` by hand (or re-run `/create-architecture` in update mode) before `/create-epics` reads it.

---

### Verdict: CONCERNS

Basis: 63 of 71 requirements are covered by Accepted ADRs; 7 are partial and 1 (Alpha-scope input-remapping storage) has no ADR; the one cross-ADR conflict is a one-line numeric drift, not blocking; no deprecated APIs and no post-cutoff contradictions; the dependency graph is complete and acyclic; one GDD revision flag; `architecture.md` carries stale pre-acceptance prose. Two named NOT ASSESSED line items keep this from PASS independently of the gaps: engine-specialist consultation (no `Agent` tool) and the systems-index update (GDD edits withheld by instruction). No Foundation or Core requirement is uncovered, so not FAIL.

### Blocking Issues (must resolve before PASS)
None at FAIL severity. To reach PASS: cover the 7 partial rows (table citations) and the 1 gap (ADR or an explicit "InputMap to `user://bindings.cfg`" decision recorded in ADR-0004 or ADR-0011), fix ADR-0008's `replay_budget_ms` line, revise run-structure R1, refresh `architecture.md`, and obtain the `godot-specialist` pass in a session that can spawn it.

### Required ADRs
Prioritised, most foundational first:
1. (Optional, Feature) "Reward Draft purity and draft-state ownership" — closes TR-reward-draft-001/-002 and TR-systems-index-003 as binding contracts rather than table citations. Not required at `standard`; recommended if `/create-stories` for the Reward Draft epic needs an ADR to cite.
2. (Alpha, Presentation/Persistence) "Input remapping storage" — closes TR-accessibility-requirements-001. Could instead be a decision row appended to ADR-0004 (bindings in the profile) or ADR-0011 (`InputMap` → `user://bindings.cfg`).

No Foundation or Core ADR is missing.

---

### Handoff

Immediate actions:
1. One-line fixes on next ADR touch: ADR-0008 `replay_budget_ms` default (4 → 2); add the seven partial-row citations to ADR-0002/0003/0005/0007/0008 tables; declare 0007 (and 0004/0005) in ADR-0008 `Depends On`.
2. Refresh `architecture.md` (§Document Status, §ADR Audit, §Threading model prose, baseline count, Data Flow 5 configs, parser name).
3. Revise run-structure R1 (`run_seed` persisted as hex) and set its systems-index row to `Needs Revision` until done.

Pre-gate checklist (Glob, 2026-11-03):
- ✅ `tests/unit/` and `tests/integration/`
- ✅ `.github/workflows/tests.yml`
- ✅ `design/accessibility-requirements.md`
- ✅ `design/ux/interaction-patterns.md`

Rerun trigger: re-run `/architecture-review` after each new ADR is written (or after the ADR-0008 / architecture.md edits) to verify coverage improves; the receipt above lets the next run scope itself.

Next step options (no answerer in this run; none taken): [A] `/architecture-decision input-remapping-storage` or the Reward Draft ADR in a fresh session · [B] `/gate-check pre-production` — all pre-gate items are ✅ and no Foundation/Core gap remains, so it may run; expect it to read this CONCERNS verdict and the two NOT ASSESSED items · [C] stop.
