# Story 008: Windows Desktop export in CI, uploaded as an artifact

> **Epic**: Boot & Composition Root
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: — (no system GDD; sprint 2 `TASK-WINEXP` in `production/sprints/sprint-002.md`; Pre-Production gate entry condition 8)
**Requirement**: — (no TR-ID; CI/release tooling. The shipped build is the Windows export, ADR-0010 Context)

**ADR Governing Implementation**: ADR-0010: Renderer choice vs Xvfb screenshot capture (the shipped build is the Windows export on Forward+; debug fixture loaders are absent from release exports); ADR-0001 (rules / presentation split: no test or prototype code in the shipped build)
**ADR Decision Summary**: The shipped renderer stays Forward+ (`project.godot` unchanged); the Windows export is built with `--export-release`, so `--fixture` debug loaders are not present. CI proves the export builds; the owner plays it on Windows.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: LOW (`--export-release` and `--import` are long-standing CLI; templates layout `export_templates/4.7.2.stable/` is observed locally and encoded in `tools/setup.sh`)
**Engine Notes**: Export needs `windows_release_x86_64.exe` from the 4.7.2 templates and the `.godot` class cache from a prior `--import` (first clean import may exit 139, so import twice as `tests.yml` does). The preset embeds the PCK (`binary_format/embed_pck=true`) and also emits a console wrapper `.exe` (`debug/export_console_wrapper=1`).

**Control Manifest Rules (this layer)**:
- Required: CI never skips or disables steps to go green (testing standards, CI/CD Rules)
- Forbidden: shipping `tests/`, `addons/gdUnit4/`, `prototypes/`, `production/`, `design/`, `docs/` in the export
- Guardrail: job timeout 30 min; warm run downloads nothing (cache)

---

## Acceptance Criteria

- [x] `.github/workflows/windows-export.yml` runs on push to `main` and on every `pull_request`, as its own workflow, so a failure shows as a separate red check and never blocks or cancels the `tests.yml` job.
- [x] The job installs Godot 4.7.2 and its export templates with `EXPORT_TEMPLATES=1 bash tools/setup.sh`, caching `~/.local/share/godot/4.7.2-stable` and `~/.local/share/godot/export_templates` keyed on the version and `tools/setup.sh`; it imports twice, runs `commands.build` verbatim, and fails unless `build/windows/deckdelve.exe` exists and is at least 50 MB.
- [x] The job uploads `build/windows/*.exe` (and `*.pck` if the preset ever stops embedding it) with `actions/upload-artifact@v4`, artifact `deckdelve-windows-<sha>` (downloads as a zip), retention 14 days, `if-no-files-found: error`.
- [x] `export_presets.cfg` `exclude_filter` excludes `tests/*`, `addons/gdUnit4/*`, `prototypes/*`, `production/*`, `design/*`, `docs/*` (plus `studio-tests/*`, `tools/*`, `reports/*`, `*.md`), and a local export with it succeeds.

---

## Implementation Notes

- A separate workflow file (not a job in `tests.yml`) because sprint 2 flags `tests.yml` as a three-way collision file (BOOT-005, RNG-004, TASK-WINEXP) and because separation gives the "visible but non-blocking" behaviour without `continue-on-error`, which would hide failures. Making it a required check is a branch-protection decision for the owner.
- `exclude_filter` was empty before this story; the filters above are new. `addons/gdUnit4/plugin.cfg` still appears as a string in `project.binary` (the `editor_plugins` setting); that is inert at runtime.
- `actions/upload-artifact@v4` and `actions/cache@v4` as specified; `tests.yml` uses `@v7` for checkout/upload. Align versions in a later chore.

---

## Out of Scope

- Owner's first-light launch and `production/qa/evidence/windows-first-light-<date>/` (gate condition 8 follow-through).
- Code signing, icons, release tagging, publishing a GitHub Release.
- Adding the job to branch protection.

---

## Files

- `.github/workflows/windows-export.yml` (new)
- `export_presets.cfg` (`exclude_filter`)
- `production/epics/boot-composition-root/story-008-windows-export-ci.md`
- `production/epics/boot-composition-root/EPIC.md`, `production/epics/index.md` (row updates)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check (advisory by default)

**Local proof (2026-11-03)**: templates present at `~/.local/share/godot/export_templates/4.7.2.stable/`; `godot --headless --path . --import` twice, then `godot --headless --path . --export-release 'Windows Desktop' build/windows/deckdelve.exe` exited 0 and produced `build/windows/deckdelve.exe` of 109176608 bytes (about 104 MiB, PCK embedded). A string scan of the exe found no `res://tests`, `prototypes`, `production`, `design` or `docs` paths. `build/` is gitignored.

**CI run**: verified 2026-11-03 by the orchestrator — run https://github.com/Kusanagi777/dungeon-run-ccg/actions/runs/41714090015 (head 85ba444, `pull_request`) completed **success**; artifact `deckdelve-windows-0da81e779bcd7f55850d2f6bd55b00ab4bf9f635` (the PR merge-ref sha), 38,964,535 bytes zipped, expires 2026-11-17. The first run on ac76506 was cancelled by `cancel-in-progress` when 85ba444 was pushed (expected). Cache hit on a second run: to be confirmed on the next push. Owner first-launch screenshot: pending (`production/qa/evidence/windows-first-light-<date>/`).

**Status**: [x] Local build passes; [x] CI run green with artifact; [ ] owner first launch on Windows

---

## Dependencies

- Depends on: none (`export_presets.cfg`, `tools/setup.sh`, `project.yaml commands.build` exist)
- Unlocks: gate condition 8 (owner's Windows first-light launch)

## Completion Notes

Closed by hand per story-done: all four criteria met by file and local-run evidence; the only open item is the CI run, verified after push. No ADR deviation. Scope addition: extra exclude filters (`studio-tests/*`, `tools/*`, `reports/*`, `*.md`).
