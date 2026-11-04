# Handoff: cloud session → local Claude Code (2026-11-04)

**For:** a Claude Code session on Jacob's machine, started in the repo root of
`Kusanagi777/dungeon-run-ccg` (so `CLAUDE.md`, hooks and deny rules load).
**From:** the cloud orchestrator session that ran sprints 1–4 and started sprint 5.
**Read this whole file first, then `CLAUDE.md`.**

## 1. Where things stand

| Item | Value |
|---|---|
| Branch | `bootstrap/ccgs-template` (long-lived; PR [#1](https://github.com/Kusanagi777/dungeon-run-ccg/pull/1), not merged to `main`) |
| Head at handoff | the commit that adds this file (on top of `2904dbd`, the sprint 5 plan) |
| Stage | Pre-Production (`production/stage.txt`, `project.yaml`) — modes: rigor standard, review lean, automation guided; match-rules and card-effects at `full` |
| Tests | 1403 blocking tests green (gdUnit4 6.2.3); perf job non-blocking (two gates fail by design until story 019) |
| Data | `validate.gd`: Ready, 0 errors, 51 warnings, 69 records |
| CI | Green on both workflows (`tests.yml`, `windows-export.yml`) |
| Sprints | 1–4 closed (sprint 4: 21/22 committed + 1/3 stretch). Sprint 5 **planned and started** — see §4 |
| First Playable | Target sprint 6 (ends 2026-12-08), fallback sprint 7. Declare 7 if boss-ai story 015 has not merged by sprint 5 merge point M3 |

## 2. Read these, in order

1. `production/sprints/sprint-005.md` — lanes, waves, merge order, "Where the shared files fall", readiness notes.
2. `production/sprint-status.yaml` — story status (sprint 5 active).
3. `design/design-decisions.md` — rows DD-X11…X25 are this week's rulings (owner decisions and designer defaults).
4. `docs/architecture/control-manifest.md` (version 2026-11-04) — must-do / never-do rules per layer.
5. `production/retrospectives/retro-sprint-4-2026-11-04.md` — action items.
6. `production/reviews/2026-11-04/` — the code and UX review reports the sprint-5 fix lanes work from, plus `lane-rules.md` (the rules every implementation lane followed; paths in it point at the cloud scratchpad — read them as this folder).
7. `docs/engine-reference/godot/current-best-practices.md` — observed Godot 4.7.2 pitfalls (below).

`production/session-state/active.md` is **gitignored**, so the cloud checkpoint does not reach you; §4–§6 here replace it. Start your own `active.md` from `.claude/docs/templates/session-state.md`.

## 3. How work is done here (keep doing it this way)

- **Per story:** `/story-readiness` → `/dev-story` → `/code-review` → `/story-done`. Tests first; every new test is seen failing before it passes (against missing code or a deliberate mutant). Record start/end UTC in Completion Notes.
- **After every story and every merge:** `godot --headless --path . --import`, then `bash tools/lint/gates.sh`, `bash tools/lint/no_global_rng.sh`, `bash tools/lint/parse-check.sh`, then the full suite exactly as `project.yaml` `commands.test`, then `commands.smoke`. Use `-c` on the test command when diagnosing (otherwise a suite stops at its first failure). The data validator: `godot --headless --path . -s tools/content/validate.gd`.
- **Commits:** Conventional Commits, body `Story: <epic>/story-NNN`. **Author Jacob, committer Claude** — a repo hook flags commits whose committer email is not `noreply@anthropic.com`:
  `GIT_COMMITTER_NAME=Claude GIT_COMMITTER_EMAIL=noreply@anthropic.com git -c user.name="Jacob" -c user.email="jseyfried7@gmail.com" commit …`
  End messages with the `Co-Authored-By` trailer for the model in use. Never force-push (deny-listed).
- **Orchestrator-owned:** `src/core/boot.gd` `_collect_validators()` and the `PENDING_*` lists. Stories expose a `static func` validator and the merger adds the registration line.
- **Lanes ([S]/[C]):** [S] stories touch shared test helpers (keep edits additive); [C] stories change shipped data/contracts and merge last.
- **No wall-clock assertions in the blocking suite.** Timing lives in `tests/performance/` (non-blocking CI job; exit 100 → warning).
- **Design docs:** read by section (Grep `^#`, then Read offset/limit); `validate-read.sh` refuses whole reads over 40 KB. Every rule change gets a dated note "(YYYY-MM-DD, DD-Xnn)".
- **Godot 4.7.2 pitfalls:** a bare call to a method named like a global function resolves to `@GlobalScope` (use `self.`); an autoload script must not declare a `class_name` equal to its autoload name (Boot has none); JSON parse-error lines are 0-based; gdUnit4 run with `-s` creates autoloads; `make_read_only()` is shallow; ripgrep 14 has no look-around (lint gates avoid it).
- **Release vs debug export:** pending config validators emit `W_VALIDATOR_PENDING`, an error in release builds, so the release export opens on the data-error screen by design. The **debug** export (`deckdelve-windows-debug-<sha>` artifact) is the playtest build.
- **Local setup:** `tools/setup.sh` (bash; installs Godot 4.7.2 + export templates under `~/.local`). On Windows, hooks and lints need Git Bash; Godot must be on PATH as `godot`. `.claude/settings.json` now pre-allows the routine git/godot/lint commands.

## 4. Sprint 5 — what was in flight when this was written

The cloud session launched **wave 1** in its own container. These branches exist **only in the cloud container** until that session merges and pushes them to `bootstrap/ccgs-template`:

| Lane | Branch | Work |
|---|---|---|
| L1 (critical) | `s5/l1-w1` | boss-ai 007 → 008 (planner, sandbox `sim_<turn>` stream) |
| L2 | `s5/l2-w1` | boss-ai 010 (choose scoring) + `planner_target_ms: 500` runtime knob in `ai_profiles.json` |
| L3 (critical) | `s5/l3-w1` | heroes 001 → 002 → 003 → 004 |
| L4 (critical) | `s5/l4-w1` | treasures 001 → 009 |
| L5 | `s5/l5-w1` | card-effects 009 (DD-X21: destroy-then-silence fires the Deathrattle) |
| L6 | `s5/l6-w1` | perf harness: 500 ms planner gate, perf job runs all gates, event-log budget 80 ms |
| L7 | `s5/l7-w1` | sprint-4 review fix buffer — Mass Rites `retrigger` op first, then Discover/event-cap, DD-X25, `hand n:1`, lint gate G7, two missing tests |
| QA | `s5/qa-plan` | `production/qa/qa-plan-sprint-005-2026-11-04.md` |
| Design | (report only) | proposal for review finding S3: how aura keyword/cost changes reach the log and the match view |

**Before starting any sprint-5 story locally, `git pull` and check `git log` for "merge: sprint 5 L…" commits.** If a wave-1 story is not merged yet, ask Jacob whether the cloud session is still running — do not redo it in parallel (the two would conflict in `rules_engine.gd`, `boss_ai.gd`, `effect_resolver.gd`, `ops.gd`). If the cloud session is gone, those stories are still Ready on trunk; re-run them from their story files.

**After wave 1 (per `sprint-005.md`):** merge in the plan's M1 order; register `heroes_balance` in Boot after heroes 004; then wave 2 (boss-ai 013 → 015 critical, match-rules 019 perf pass as the only `rules_engine.gd` editor in W2, card-effects 014 → 013, treasures 003, content 010, card-effects 017); then wave 3 (match-ui 003 → 010 — the first UI stories needing retained screenshots in `production/qa/evidence/`). Each wave ends with an independent `/code-review` of its stories (the retro found 13 of 23 sprint-4 stories had gone unreviewed until late).

## 5. Open items for Jacob

| Item | Status |
|---|---|
| **NC-5 Windows check** — launch the latest `deckdelve-windows-debug-<sha>` (Actions → Windows Export → artifacts), confirm the boot screen and main menu, and read the data fingerprint (known answer `4667ce6e5d01302f`; see `production/qa/qa-plan-sprint-004-2026-11-04.md` NC-5) | Owner said "later today" |
| **S3 aura projection** — pick an option from the design proposal (aura keyword/cost changes are not logged; the match view ignores aura stat changes; Gatekeeper's Taunt passive needs it for First Playable) | Proposal ready: `production/reviews/2026-11-04/proposal-s3-aura-projection.md` — recommends option C (enrich the existing `auras_recomputed` event with each changed entity's full values). Awaiting Jacob's pick |
| **Content 010 Torchbearer line** — Gravekeeper also returns to The Torchbearer's deck (consistent with DD-X20's intent) | Keep unless Jacob strikes it |
| `planner_target_ms` source for match-ui 010 | Decided: runtime knob in `ai_profiles.json` (lane 2) |

Decided this week (already in `design/design-decisions.md`): DD-X18 planner 500 ms per run; DD-X19 event-log budget 80 ms; DD-X20 Boss AI values `add_counter` (0.5); DD-X21 destroy-then-silence fires the Deathrattle, content lists Silence first; DD-X22 non-lethal face attacks + "vulnerable"; DD-X23 commit beat stretches over planning; DD-X24 content sign-off; Torchlit Ledger art direction approved (art bible §1–4). Designer defaults Jacob can overturn: DD-X15 (hero is the weapon-swing damage source), DD-X16 / DD-X25 (no aura-granted Stealth / Divine Shield), DD-X17 (`submit` rejects arguments `legal_commands()` never lists).

## 6. Known risks

- **Engine speed:** worst-case `submit` 20–25 ms vs 5 ms; clone + one submit ≈ 0.37 ms (release). Band 1 fits the 500 ms planner target (~140 ms); band 2 needs story 019; band 3 needs lower node counts afterwards (`/propagate-design-change` on boss-ai F7 once 019 re-measures).
- **Duplicate commit** `bb2d9f7` on trunk (a lane merged a pre-amend copy of the story-016 AC fix) — harmless, same content.
- **Treasures 013** is Blocked on a treasures-GDD gap (no definition of the power figure).
- Stories that cannot start yet: treasures 011, rng-event-log 009/011, card-database 010 (their dependencies have no stories).
