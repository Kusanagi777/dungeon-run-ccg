# Story 007: Boot responsibilities list for the control manifest (gate condition 12)

> **Epic**: Boot & Composition Root
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: — (no system GDD; `docs/architecture/architecture.md` §Dependency injection and the composition root — the "Boot does / Boot never does" table; `production/gate-checks/gate-pre-production-2026-11-03.md` entry condition 12: "`Boot` responsibilities listed in the control manifest on its next revision (guard against TD-001 regrowth) — technical-director")
**Requirement**: `TR-tech-debt-001` (TD-001 regrowth guard)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Rules / Presentation Split (Decision 4 — what `Boot` does; the manifest's Foundation rows are generated from it); ADR-0004 Decision 6 / 8 and addendum step 4 (the `Timer` children, exit hook and `InputMap` application `Boot` will own later); ADR-0011 Decision 4 (the `MetaStub` → `MetaFacade` one-line switch)
**ADR Decision Summary**: `Boot` is a composition root and nothing else; the control manifest carries the Required / Forbidden rows programmers read instead of the ADRs, and the Pre-Production gate requires the manifest's next revision to list `Boot`'s responsibilities explicitly so TD-001 (an autoload god object) cannot regrow unnoticed.
**ADR Version**: 2026-11-03 (ADR-0001, ADR-0004, ADR-0011 — all `Last Verified` 2026-11-03)

**Engine**: Godot 4.7.2 | **Risk**: LOW (a documentation deliverable; no engine API)
**Engine Notes**: none — the list cites the engine facts the ADRs already source (`Timer`, `NOTIFICATION_WM_CLOSE_REQUEST`, `_exit_tree`, `InputMap.action_erase_events` / `action_add_event` observed 2026-11-03) without adding new ones.

**Control Manifest Rules (this layer)**:
- Required: `Boot` is the one autoload and a lazy composition root (the row this story expands into an explicit responsibilities list) — ADR-0001
- Forbidden: Never a service-locator autoload; never a second autoload; never a second composition path — ADR-0001
- Guardrail: none

---

## Acceptance Criteria

*From `production/gate-checks/gate-pre-production-2026-11-03.md` condition 12 and `docs/architecture/architecture.md` §Dependency injection, scoped to this story:*

- [ ] `production/epics/boot-composition-root/boot-responsibilities.md` lists every `Boot` "does" and "never does" row from architecture.md §Dependency injection, ADR-0001 Decision 4 (construct `CardDatabase` + `load(validators)`, the `MetaApi` implementation, `SettingsBus`; `services()` to scene roots and debug loaders only; idle `_ready()`; the single `[autoload]` entry; no game state, no tick), ADR-0004 Decision 6 / 8 (`Timer` children for the lock heartbeat and the settings debounce; `NOTIFICATION_WM_CLOSE_REQUEST` / `_exit_tree` → `release_lock()`; timers start in `boot()`), ADR-0004 addendum step 4 (apply `settings.bindings` to `InputMap` after the profile loads; re-apply on `settings_changed{bindings}` — Alpha) and ADR-0011 Decision 4 (the `MetaStub` → `MetaFacade` one-line switch; `RunDebugLoader` uses the same `boot(overrides)` seam) — each row citing its ADR and decision number and tagged `MVP` or `later (<epic>)`.
- [ ] The list matches the implemented `src/core/boot.gd` from stories 004–006: every public member of `Boot` (`boot`, `services`, `booted`, `_collect_validators`, the override keys) appears in it, nothing in the `MVP` rows is absent from the code, and TD-001 / TD-009 are named as the regressions the rows guard (architecture.md §Tech-debt retirement mapping).
- [ ] The file is handed to `/create-control-manifest update` as the input for a Foundation Required Patterns "Boot responsibilities" row (and the matching Forbidden rows), closing gate condition 12 for the technical-director; the story records the resulting `Manifest Version` so that stories stamped `2026-11-03` can be re-stamped by `/story-done`'s staleness check rather than surprised by it.

---

## Implementation Notes

*Derived from ADR-0001 Decision 4, ADR-0004 Decision 6 / 8 / addendum, ADR-0011 Decision 4, and the gate report:*

- The list is a Markdown table with the columns `Responsibility | MVP / later | Source (ADR-NNNN Dn) | Guards (TD-ID)`; two sections, "Boot does" and "Boot never does", mirroring architecture.md's table so `/create-control-manifest` can lift rows verbatim.
- Write it **after** stories 004–006 close, from the code: `rg -n "^func |^var |^signal |^const " src/core/boot.gd` is the member list; every row's `MVP` tag must point at a member or a test in `tests/integration/boot/boot_composition_test.gd`.
- `later` rows and the epic that lands each: heartbeat / debounce `Timer`s, `release_lock()` and `MetaFacade` switch → Meta Progression; `bindings` → `InputMap` → deferred (index §Deferred, TR-accessibility-requirements-001, Alpha); `RunDebugLoader` overrides → Run UI; `--fixture` for `MatchView` → Match UI; per-epic validator lines in `_collect_validators()` → each epic.
- "Never does" rows (do not soften): owns no `MatchState` / `RunState` / deck / gold / floor (TD-001, TD-009); runs no `load()` in `_ready()`; drives no `MatchDriver.tick()`; exposes no per-field getter (`Boot.card_database`) — the service-locator shape; is never named by `src/gameplay/**`, `src/ai/**`, `src/core/**` minus itself (G3); has no sibling autoload (G4).
- This story changes no code and does not run `/create-control-manifest` itself (that is the technical-director's `update` run, a separate approval); its output is the input file plus the row in the epic's `EPIC.md` noting condition 12 as handed over.
- Test evidence for a Config/Data story is a smoke-check pass: the next `/smoke-check` after the hand-over is the evidence (the list changes no behaviour, so the smoke is the proof nothing regressed while the manifest was revised).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 004–006: the code the list describes.
- `/create-control-manifest update` (technical-director, separate run): the manifest revision itself and its new `Manifest Version`.
- Re-stamping other epics' stories after the manifest bump — `/story-done` / `/story-readiness` per story.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `production/epics/boot-composition-root/boot-responsibilities.md` (new)
- `production/epics/boot-composition-root/EPIC.md` (Gate Entry Conditions Carried — condition 12 marked handed over, with the date)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level` (`standard`).*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-*.md`) — the first `/smoke-check` after the hand-over

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boot-composition-root/story-004-boot-composition-root.md`, `production/epics/boot-composition-root/story-005-lint-gates-ci.md`, `production/epics/boot-composition-root/story-006-main-scene-composition-entry.md`
- Unlocks: `/create-control-manifest update` (gate condition 12 closure); none within this epic
