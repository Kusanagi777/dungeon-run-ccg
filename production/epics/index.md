# Epics Index

Last Updated: 2026-11-04
Engine: Godot 4.7.2
Scope: MVP only (DD-H06) — War hero, 5 bosses (3/1/1), ~40 cards + ~10 boss cards, 10 treasures, 10 bundles
Order: riskiest first, following the ADR implementation order (gate `gate-pre-production-2026-11-03.md` entry conditions 1 and 2)
Review: PR-EPIC skipped — Lean mode

| Epic | Layer | System | GDD | Stories | Status |
|------|-------|--------|-----|---------|--------|
| Boot & Composition Root | Foundation | Boot (composition root) | — (architecture.md §Dependency injection; ADR-0001) | 8 stories | Ready |
| RNG & Event Log | Foundation | RNG & Event Log | design/gdd/rng-event-log.md | 11 stories | Ready |
| Card Database | Foundation | Card Database | design/gdd/card-database.md | 10 stories | Ready |
| Match Rules | Core | Match Rules | design/gdd/match-rules.md | 19 stories | Ready |
| Card Effects | Core | Card Effects | design/gdd/card-effects.md | 17 stories (story 017 added 2026-11-04, DD-X21) | Ready |
| Boss AI + Match Driver | Core | Boss AI (+ Run Structure's `MatchDriver`) | design/gdd/boss-ai.md | 19 stories | Ready |
| Match UI | Presentation | Match UI | design/gdd/match-ui.md | 24 stories | Ready |
| Run Structure | Feature | Run Structure | design/gdd/run-structure.md | Not yet created | Ready |
| Reward Draft | Feature | Reward Draft | design/gdd/reward-draft.md | Not yet created | Ready |
| Treasures | Feature | Treasures | design/gdd/treasures.md | 13 stories | Ready |
| Heroes | Feature | Heroes | design/gdd/heroes.md | 4 stories | Ready |
| Run UI | Presentation | Run UI | design/gdd/run-ui.md | Not yet created | Ready |
| Meta Progression (persistence + seam) | Feature / Foundation code | Meta Progression | design/gdd/meta-progression.md | Not yet created | Ready |
| Content (MVP batch) | Feature (data) | Content | design/gdd/content.md | 10 stories (story 010 added 2026-11-04, DD-X20) | Ready |

## Build order and plan mapping (E1–E10)

| Order | Slug | Plan epic | Governing ADRs | TR-IDs (own + carried) | Size / risk |
|---|---|---|---|---|---|
| 1 | `boot-composition-root` | E1 Foundation | 0001, 0004, 0011 | 3 (carried cross-cutting) | S / HIGH (language; guards TD-001) |
| 2 | `rng-event-log` | E1 Foundation | 0003, 0001 | 6 | M / HIGH, NOT SOURCEABLE (golden pin first) |
| 3 | `card-database` | E1 Foundation | 0002, 0001 | 5 + 1 | M / LOW APIs (HIGH general) |
| 4 | `match-rules` | E2 | 0007, 0005, 0001, 0003, 0006, 0008 | 8 | L / HIGH design risk (bottleneck, 7 dependents) |
| 5 | `card-effects` | E3 | 0007, 0002, 0005 | 6 | L / HIGHEST (top technical risk; sprint-1 spike) |
| 6 | `boss-ai-match-driver` | E4 | 0008, 0006, 0001, 0003, 0002 | 6 + 1 | L / HIGH, NOT SOURCEABLE (threading; Windows gated) |
| 7 | `match-ui` | E5 | 0009, 0008, 0001, 0010, 0003, 0011 | 6 + 3 | L / HIGH (first playable surface; `/perf-profile` at first story) |
| 8 | `run-structure` | E6 | 0008, 0004, 0003, 0011, 0006 | 5 | M / MEDIUM |
| 9 | `reward-draft` | E6 | 0005, 0003, 0011 | 2 + 1 | M / design risk (bundle collapse) |
| 10 | `treasures` | E6 | 0005, 0007, 0002 | 4 + 1 | M / LOW APIs (retires TD-009) |
| 11 | `heroes` | E6 | 0002, 0007 | 1 | S / LOW |
| 12 | `run-ui` | E7 | 0011, 0008, 0001, 0010, 0009 | 5 + 2 | L / HIGH (UI 4.5–4.7; one NOT SOURCEABLE property) |
| 13 | `meta-progression` | E8 | 0004, 0011, 0003, 0001 | 6 + 2 | M / MEDIUM, NOT SOURCEABLE (Windows atomic write gates close) |
| 14 | `content` | E9 | 0002, 0003, 0007, 0006 | 2 | L / scope risk (batch 0 pulled into sprint 1) |
| — | *(none)* | E10 Polish & release prep | — | — | Not an architectural module; the skill creates no epic for it. Carry it as gate conditions 8 and 10 plus `/release-checklist` once the MVP build exists. |

Module split notes: the skill's one-epic-per-architectural-module rule splits plan E1 (Boot, RNG & Event Log, Card Database) and E6 (Run Structure, Reward Draft, Treasures, Heroes); E4 keeps `MatchDriver` with Boss AI because ADR-0008 governs both and the first playable needs them together. The nine cross-cutting TR-IDs (`design-decisions`, `systems-index`, `tech-debt`, `game-concept`, `accessibility-requirements`) are carried by the epic whose module satisfies them (see each EPIC.md); all 71 registry rows are covered by an Accepted ADR, no epic has an Untraced row.

Gate entry conditions carried (owner / deadline in the gate report): 3 → `match-rules` (N-05), `meta-progression` (D-03); 5 → `match-rules`, `card-effects`, `boss-ai-match-driver`, `match-ui`, `heroes`, `content` batch 0; 6 → `card-effects`, `boss-ai-match-driver`, `rng-event-log`; 7 → `rng-event-log`; 8 and 10 → `match-ui`; 9 → `boss-ai-match-driver`, `meta-progression`; 11 → `match-ui`, `reward-draft`, `run-ui`; 12 → `boot-composition-root`.

Prototype salvage (`prototypes/hearthstone-clone-2026-01/`, never imported, ideas only): card_ui hover/drag and targeting_arrow bezier → `match-ui`; mulligan_screen (rules fixed to Hearthstone) → `match-ui`; discover_selection / victory_selection pick-1-of-N → `match-ui` Choice overlay and `run-ui` draft picker; ModifierManager → owner-scoped hook registry (ADR-0005) → `treasures`.

## Deferred list (not in MVP epics — Vertical Slice / Alpha / Full Vision)

| Item | Target tier | Source | Lands in (when scheduled) |
|---|---|---|---|
| Decay and Knowledge heroes (data, starter decks, sets, balance) | Alpha | DD-H01, heroes.md | `heroes`, `content` (VS/Alpha batches) |
| Fortune, Order, Shadow unlock heroes | post-v1 | DD-H02 | `content`, `meta-progression` facade |
| Bosses 6–16 (full three-band pool) and their `ai_profile` overrides | Vertical Slice → Alpha | content.md, DD-H03 | `content`, `boss-ai-match-driver` |
| Cards 41–120, boss-only cards beyond the MVP ~10, bundles 11–36 | Vertical Slice → Alpha | content.md, DD-H04 | `content`, `reward-draft` |
| Treasures 11–20 and unlock-gated treasures | Alpha | treasures.md | `content`, `treasures`, `meta-progression` facade |
| Full eight-floor run (`floors_per_run` 8) and save/resume across restarts | Vertical Slice | run-structure.md, DD-R08 | `run-structure` + `meta-progression` |
| `MetaFacade` rules half: `UnlockEvaluator`, `StatsFold`, 200-run archive, run-log pages, per-hero stats, unlock toasts | Vertical Slice (required for v1 / Alpha) | meta-progression.md, ADR-0004, ADR-0011 | new VS epic or `meta-progression` reopened |
| Run log screen beyond the MVP stub | Vertical Slice | run-ui.md U2 | `run-ui` |
| Input remapping / controls screen, bindings in profile M9 applied to `InputMap` | Alpha (Standard a11y tier) | TR-accessibility-requirements-001, ADR-0004 addendum, ADR-0011 U2 row | `meta-progression`, `run-ui`, `boot-composition-root` |
| Gamepad mapped to the focus graph (beyond keyboard completeness) | Alpha | run-ui.md U3, a11y Motor | `run-ui`, `match-ui` |
| Ops the full card pool needs beyond the MVP effect set; v2 DSL deferrals | Vertical Slice → Alpha | card-effects.md C11 | `card-effects` |
| Replay viewer and `keep_match_logs` default per build type | Vertical Slice | architecture.md "Can defer", ADR-0003 | `rng-event-log`, `match-ui` |
| Mid-match restore from the event log | Vertical Slice design change | QQ-07, run-structure R8.3 | design first (`/quick-design`) |
| Pause music slider, glossary owner (a11y remainder) | Alpha | accessibility-requirements.md | `run-ui` |
| Hard-band modifiers, accessibility beyond Standard, custom art | Full Vision | systems-index Priority Tiers | — |
| Polish & release prep (plan E10): Windows export in CI as a download, first-light evidence, perf-profile confirmation, release checklist | MVP exit | gate conditions 8, 10; `/release-checklist` | not an epic — sprint tasks |

Next: `/create-stories boot-composition-root` (then in build order); `/qa-plan sprint`; `/sprint-plan new` (one-week calibration sprint, gate condition 4). Foundation and Core epics are what the Pre-Production → Production gate needs; `/gate-check production` checks readiness after the Vertical Slice.
