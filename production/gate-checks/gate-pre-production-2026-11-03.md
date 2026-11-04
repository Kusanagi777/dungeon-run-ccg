# Gate Check: Technical Setup → Pre-Production — 2026-11-03

**Verdict: CONCERNS (accepted) — stage advanced to Pre-Production.**
Workflow standard · review lean · panel TD + PR · automation guided (owner's standing approval of the plan, 2026-11-03; entry conditions that could be closed in-session were closed before the stage write, the rest are carried with owners and deadlines).

## Artifact checklist (`gate-pre-production.md`, standard reductions)
- [x] Engine chosen — Godot 4.7.2 (`project.yaml` `engine`, `docs/engine-reference/godot/VERSION.md`, installed binary agree)
- [x] Project config populated — `project.yaml` engine / specialists / naming / commands; `performance.*` set 2026-11-03 (enforce warn, 60 fps, 16.6 ms, 500 draw calls, 1024 MB — provisional until the first `/perf-profile`)
- [x] Art bible §1–4 — `design/art/art-bible.md` (recommended at standard; present)
- [x] Critical Foundation-layer ADRs — ADR-0001 (composition root / rules-presentation split), ADR-0002 (data + effect schema + config loading), ADR-0003 (seeded RNG + event log), ADR-0004 (save format + atomic write), ADR-0010 (renderer vs capture); all 11 ADRs **Accepted 2026-11-03**
- [x] Engine reference docs — `docs/engine-reference/godot/` (VERSION.md, modules/, breaking-changes.md, deprecated-apis.md, current-best-practices.md)
- [x] Test framework — `tests/unit/`, `tests/integration/boot/`, `tests/smoke/`, `tests/helpers/`; gdUnit4 6.2.3
- [x] CI workflow — `.github/workflows/tests.yml`, green on every push (66 tests)
- [x] Example test — `tests/unit/framework/*`, `tests/integration/boot/boot_scene_test.gd`, `tests/smoke/project_boot_smoke_test.gd`
- [x] Master architecture document — `docs/architecture/architecture.md` (v1 + 2026-11-03 post-review refresh)
- [x] Traceability index — `docs/architecture/requirements-traceability.md`; `tr-registry.yaml` v3, 71 TR-IDs, validate clean
- [x] `/architecture-review` run — `architecture-review-2026-11-03.md` (Mode: full, CONCERNS) and `architecture-review-2026-11-03b.md` (Mode: full, 71/71 covered, 0 conflicts; NOT ASSESSED only for the engine-specialist consultation — closed by `docs/architecture/engine-validation-2026-11-03.md`, see Engine validation below)
- [x] `design/accessibility-requirements.md` — tier **Standard** committed (+3 elevated rows)
- [x] `design/ux/interaction-patterns.md` — pattern library, APPROVED by `/ux-review` (round 4)

## Quality checks
- [x] ADRs cover core systems — rendering (ADR-0010), input/UI (ADR-0009, ADR-0011, ADR-0004 bindings addendum), state management (ADR-0001, ADR-0007, ADR-0008)
- [x] Naming conventions and performance budgets — `project.yaml` `naming`, `performance`; `architecture.md` §Performance budgets incl. minimum spec
- [x] Accessibility tier defined — Standard
- [x] UX specs started — hud, draft-picker, hero-select, run-summary all **APPROVED** by `/ux-review` (rounds 3–4); accessibility-requirements: see UX status below
- [x] Engine Compatibility section with version stamp on all 11 ADRs
- [x] GDD Requirements Addressed on all 11 ADRs (71 TR-IDs cited)
- [x] No deprecated APIs (review engine audit, both runs)
- [x] HIGH RISK engine domains (4.5 / 4.6 / 4.7) addressed or flagged — threading, atomic rename, Forward+ under Xvfb probed on Linux; Windows halves gated by named tests
- [x] Zero Foundation-layer traceability gaps (03b: 0 gaps at any layer)
- [x] ADR dependency graph — `adr-dep-graph.sh`: 11 ADRs, 21 edges, no cycles, no unfilled sections; order 0001, 0002, 0003, 0010, 0004, 0007, 0005, 0008, 0006, 0009, 0011

## Engine validation
- [x] Post-cutoff APIs flagged with Knowledge Risk on every ADR; all ADRs stamp 4.7.2
- [x] Engine audit shows no deprecated API usage
- [x] Engine-specialist consultation — `docs/architecture/engine-validation-2026-11-03.md` (godot-specialist, 2026-11-03): ADR-0010 APPROVE; ADR-0003 / 0004 addendum / 0009 / 0011 APPROVE WITH NOTES (ADR-0011's two NOT SOURCEABLE items now observed on 4.7.2); ADR-0006 and ADR-0001 G2b REVISE — both applied as dated errata the same day (coroutine task Callable built by `BossAI.plan_task`; G2b look-around-free deny-list). No deprecated APIs, no best-practice violations. Closes the NOT ASSESSED item of both review reports.

## UX status at the gate
| Document | Latest `/ux-review` | Round |
|---|---|---|
| design/ux/hud.md | APPROVED | 3 |
| design/ux/draft-picker.md | APPROVED | 3 |
| design/ux/hero-select.md | APPROVED | 4 |
| design/ux/run-summary.md | APPROVED | 4 |
| design/ux/interaction-patterns.md | APPROVED | 4 |
| design/accessibility-requirements.md | APPROVED | 5 |

All six UX documents APPROVED (verbatim verdicts retained in the session scratchpad `reports/ux-review-round*.md`; advisories carried into the first UI stories).

## Director panel
| Director | Gate | Verdict |
|---|---|---|
| technical-director | TD-PHASE-GATE | **CONCERNS** — Foundation decisions complete and sound, rig works (ran `commands.test`: 66 pass); not READY because budgets were TBD (closed in-session), review not re-run (closed: 03b), specialist not consulted (closed: engine validation), Windows never run |
| producer | PR-PHASE-GATE | **CONCERNS** — design + architecture stable enough to decompose; not READY because capacity is unmeasured and nobody has played the game |

Escalation: two CONCERNS, no NOT READY → CONCERNS. Full assessments retained in the session scratchpad (`reports/gate-preprod-td.md`, `reports/gate-preprod-pr.md`) and summarised here.

## Technical Setup exit criteria (from the previous gate) — closure
1. Critical ADRs — **CLOSED** (11 Accepted, each lists the TD items it retires)
2. Control manifest + architecture review + TR registry — **CLOSED** (`control-manifest.md` 2026-11-03; reviews 03 / 03b; 71 TRs)
3. Test rig — **CLOSED** (export preset, main scene, integration test, capture proof); Windows export not yet in CI (entry condition 8)
4. UX per-screen specs reviewed — **CLOSED** for hud, draft-picker, hero-select, run-summary; accessibility doc per table above
5. TD-001..012 closed against ADRs — **CLOSED** (register reconciled 2026-11-03)
6. Performance budgets — **CLOSED** (provisional draw-call / memory / min-spec values recorded; confirm at first `/perf-profile`)
7. Carry-forwards — Meta stub CLOSED (ADR-0011 `MetaStub`); first playable → goal 5; spikes + harness → goal 6; owner items carried below

### Accepted Risks (owner standing approval, 2026-11-03)
- Capacity unmeasured — weekly hours not given; sprint 1 is a one-week calibration sprint unless the owner supplies hours (PR condition 7)
- No human playtest yet — first playable Windows build is Pre-Production goal 5
- Windows-only engine facts unverified (`WorkerThreadPool`, `rename_absolute`, Forward+/D3D12 parity) — gated tests scheduled before Vertical Slice (TD conditions 4–5)
- CI screenshots render Compatibility/llvmpipe, not the shipped renderer — per-UI-story Windows confirmation row is advisory (ADR-0010)
- RNG engine-drift pin test does not exist yet — first RNG story (TD condition 3)
- Ephemeral cloud container; long-lived PR #1 — merge before gameplay code lands
- ADR acceptance and this override rest on the owner's standing plan approval, not a per-item confirmation; each ADR Status block says so and is revertable

## Pre-Production entry conditions (owners, deadlines)
1. `/create-epics` E1–E10 covers MVP systems only (DD-H06 cut); Vertical Slice / Alpha items go on a deferred list — producer, at `/create-epics`
2. Epic order follows the ADR implementation order, riskiest first: Foundation → Match Rules → Card Effects → Match driver + Boss AI → Match UI → Run, Draft, Treasures → Run UI — producer
3. Owner decisions with deadlines: ~~**weekly hours**~~ **decided 2026-11-04: 12 hours/week** for review and playtesting; ~~N-05~~ **decided 2026-11-03** (defending hero deals no damage back — DD-X11); ~~D-03~~ **decided 2026-11-03** (any-hero treasure: Living Armory → `first_victory` — DD-X12); **Torchlit Ledger** confirmation before `/asset-spec` — Jacob
4. Sprint 1 = one-week calibration sprint; sprint 2 planned from measured velocity — producer
5. **First playable**: Windows export, one War match vs one band-1 boss, mouse-played, within sprints 1–2; the owner plays it = playtest #1 — producer / Jacob
6. Sprint 1 spikes: five hardest DSL effect types; Boss AI planner on the Windows export; headless AI-vs-AI harness deterministic per seed — lead-programmer
7. First RNG story adds the 100-draw golden-sequence pin test (`tests/unit/rng_event_log/rng_engine_pins_test.gd`, ADR-0003) — gameplay-programmer
8. CI builds the Windows export and publishes it as a download; owner launches it once and retains `production/qa/evidence/windows-first-light-<date>/` — devops-engineer / Jacob
9. `atomic_write_platform_test.gd` (ADR-0004) and ADR-0006's worker-vs-main-thread determinism + A30 on Windows scheduled before the Meta Progression and Boss AI epics close — technical-director
10. Draw calls / memory ceiling confirmed by `/perf-profile` at the first Match UI story; `architecture.md` §Performance budgets updated — performance-analyst
11. Every UX doc must be APPROVED before its stories pass `/story-readiness` — ux-designer
12. `Boot` responsibilities listed in the control manifest on its next revision (guard against TD-001 regrowth) — technical-director

## Next
`/create-epics` → `/create-stories <epic>` (riskiest first) → `/qa-plan sprint` → `/sprint-plan new` (calibration sprint) → `/gate-check production` after the Vertical Slice.

### Owner decisions recorded after the gate
- 2026-11-04 — **First Playable date accepted:** sprint 6 (ends 2026-12-08), fallback sprint 7 (re-dated from measured lane throughput, retro sprint 3).
- 2026-11-04 — **Owner capacity:** 12 hours per week for review and playtesting (entry condition 3 closed).
- 2026-11-04 — **Entry condition 12 closed** (technical-director, owner standing approval): `docs/architecture/control-manifest.md` Manifest Version **2026-11-04** lists `Boot`'s responsibilities — Foundation Required "Boot responsibilities" and Forbidden "Never give `Boot` game state, …" rows, lifted from `production/epics/boot-composition-root/boot-responsibilities.md` (boot-composition-root story 007).
