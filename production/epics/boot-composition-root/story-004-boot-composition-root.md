# Story 004: Boot — the one autoload and lazy composition root

> **Epic**: Boot & Composition Root
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: — (no system GDD; `docs/architecture/architecture.md` §Dependency injection and the composition root — the "Boot does / never does" table; §Data Flow 5 Initialisation order, steps 1–4; §Module Ownership Foundation row `Boot`; §API Boundaries Foundation `boot.gd` block; §Tech-debt retirement mapping rows TD-001, TD-009)
**Requirement**: `TR-design-decisions-001` (also `TR-tech-debt-001` — TD-001, TD-009; `TR-systems-index-001` — the MVP stub in `Services.meta`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Rules / Presentation Split (Decision 4 — the one autoload, lazy, idempotent; Key Interfaces `Boot`, `Services`, `BootResult`); ADR-0011: Run UI Shell Pattern and the Meta Stub Injection Seam (Decision 4 — `Boot.boot({meta: …})`, the MVP `MetaStub.new(card_database)` line)
**ADR Decision Summary**: `src/core/boot.gd` (`class_name Boot extends Node`) is the single `project.godot [autoload]` entry and a lazy composition root: `_ready()` does nothing; `boot(overrides) -> BootResult` constructs `CardDatabase` (+ `load(validators)`), the `MetaApi` implementation (`MetaStub` for the MVP) and `SettingsBus`, is idempotent, and `services()` returns a plain `Services` bag `{card_database, profile_store, meta, settings_bus}`; `Boot` owns no game state, runs no tick, and is referenced only by scene roots, debug loaders and tests.
**ADR Version**: 2026-11-03 (ADR-0001 and ADR-0011, both `Last Verified` 2026-11-03)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0001's rating — 4.5–4.7 GDScript; the autoload mechanics themselves are LOW per architecture.md Module Ownership)
**Engine Notes**: `Node` autoload (LOW); `OS.get_cmdline_user_args()` (LOW, pre-cutoff). **NOT SOURCEABLE** (ADR-0001 verification 2 / architecture QQ-04): whether a `godot --headless -s GdUnitCmdTool.gd` run instantiates `[autoload]` entries — the integration test asserts `Boot.booted == false` after the suite starts, and story 005's per-file parse check proves rules files load with no autoload present either way. Typed-return override rule (4.7) applies to nothing here; `@abstract` applies only through `MetaApi`.

**Control Manifest Rules (this layer)**:
- Required: `Boot` (`src/core/boot.gd`, `class_name Boot extends Node`) is the one autoload and a lazy composition root: `_ready()` does nothing; `boot(overrides)` is idempotent and returns `BootResult`; `services()` returns a plain `Services` bag `{card_database, profile_store, meta: MetaApi, settings_bus}`; `project.godot [autoload]` contains exactly `Boot` (gate G4) — ADR-0001
- Required: Scene roots and `*_debug_loader.gd` are the only non-test callers of `Boot.services()`; they pass services down by argument — ADR-0001
- Required: Tests under `tests/unit/**` construct rules objects directly, never through `Boot` — ADR-0001, ADR-0003
- Forbidden: Never a service-locator autoload (`Boot.card_database` read on demand) — it is TD-001 again; never a second autoload; never a second composition path — ADR-0001 (Alt 1, Alt 2)
- Forbidden: Never reference `Boot` or `Services` from `src/gameplay/**`, `src/ai/**`, `src/core/**` (minus `boot.gd`) — gate G3
- Guardrail: Data load (`Boot.boot()` → `CardDatabase` `Unloaded → Ready`) ≤ `data_load_budget_ms` 200 (expected < 50 ms), synchronous at boot; frozen snapshot ≤ `data_memory_budget_mb` 4 — ADR-0002, ADR-0001

---

## Acceptance Criteria

*From `docs/architecture/architecture.md` §Dependency injection and the composition root, §Data Flow 5, and ADR-0001 Decision 4 / Key Interfaces, scoped to this story:*

- [ ] `src/core/boot.gd` declares `class_name Boot extends Node` and is the only `^[A-Za-z_]+=` line under `[autoload]` in `project.godot`, named `Boot`; `_ready()` does nothing (no `load()`, no timer, no process tick); `booted` is `false` after the gdUnit4 suite starts and until `boot()` is called (QQ-04).
- [ ] `boot(overrides: Dictionary = {}) -> BootResult` runs initialisation steps 2–4 in order: constructs `CardDatabase` and calls `load(validators)` with the validators the composition root collects (see Implementation Notes), places `MetaStub.new(card_database)` in `Services.meta` (the MVP line; `Services.profile_store` stays `null` until the Meta Progression epic), creates / wires `SettingsBus` so that `Services.settings_bus` is the same object as `Services.meta.settings_bus`, sets `booted = true`, and returns `BootResult {ok: bool, report: ValidationReport, load_status: StringName}`; a second `boot()` call returns a `BootResult` for the same state, re-runs no `load()`, and `services()` returns the same `Services` instance (idempotent).
- [ ] `boot({meta: MetaStub.new(...)})` and `boot({card_database: <instance>})` place the given object in the bag instead of constructing one, and `services()` is a `class_name Services extends RefCounted` bag with exactly the four fields `card_database`, `profile_store`, `meta: MetaApi`, `settings_bus` and no methods.
- [ ] When `CardDatabase.load()` ends `Failed`, `boot()` returns `ok == false` with the `ValidationReport` in `report` and `load_status == &"Failed"` (no crash, no partial `Services.meta` construction that reads data), and `Boot` holds no `MatchState`, `RunState`, deck, floor or other game state field; the `Unloaded → Ready` load inside `boot()` completes within `data_load_budget_ms` (200 ms) on the MVP data set, measured and printed by the integration test (advisory until the card-database performance test owns it).

---

## Implementation Notes

*Derived from ADR-0001 Decision 4 and Implementation Guidelines, ADR-0011 Decision 4, architecture.md §Dependency injection:*

- Files: `src/core/boot.gd` (`Boot`), `src/core/services.gd` (`class_name Services extends RefCounted` — plain bag, no behaviour), `src/core/boot_result.gd` (`class_name BootResult extends RefCounted` — `{ok, report, load_status}`). `project.godot`: `[autoload]` `Boot="*res://src/core/boot.gd"` and nothing else.
- Signature (ADR-0001 Key Interfaces): `func boot(overrides: Dictionary = {}) -> BootResult`, `func services() -> Services`, `var booted: bool`. Overrides keys: `meta: MetaApi`, `card_database: CardDatabase` (others may be added by later epics; unknown keys are an error in debug builds, logged, never silently ignored).
- **Validator collection.** ADR-0001 Decision 4 lists `EffectValidator`, `BossAI`, `Treasures`, `MetaProgression` and each config owner; architecture.md Data Flow 5 step 2 lists the exact `validators` Dictionary shape `{effects, ai_profile, unlock, treasure, configs: {match_rules, card_effects, ai_profiles, run_structure, reward_draft, treasures_balance, heroes_balance, match_ui, run_ui, profile_defaults, content_budgets, rng_event_log}}`. **None of those owners exists when this story is built**, and a missing validator is `E_DELEGATED` → `Failed` in every build type (ADR-0002, manifest). So: `boot.gd` holds one assembly point (`_collect_validators() -> Dictionary`) that returns the validators of every owner that exists; `unlock` comes from `MetaApi.validate_unlock_defs` (the stub's returns `[]`, story 003); each later epic adds its own line there (one line per epic — the TODO list is the Data Flow 5 block). The integration test does not depend on the real data set validating: it passes `{card_database: <CardDatabase loaded with explicit `func(...): return []` stubs>}` for the happy path (manifest: "tests inject `func(...): return []` stubs explicitly") and a `CardDatabase` pointed at a broken fixture for the `Failed` path. Flag for `/story-readiness`: the real `boot()` with no override goes green only once the card-database epic's loader and the `profile_defaults.json` data file exist.
- `Boot` reads `config("rng_event_log")` and `config("profile_defaults")` knobs **only** to hand them to the services it constructs (manifest: knobs come from the composition root); it keeps no copy for its own use and never exposes a per-field getter (service-locator shape, Alt 2).
- `Boot` never names `MatchState`, `RunState`, a deck, gold or floor; `MatchDriver.tick()` is driven by `MatchView._process`, not by `Boot`.
- ADR-0004 Decision 6/8 gives `Boot` two `Timer` children (lock heartbeat, settings debounce) and the `NOTIFICATION_WM_CLOSE_REQUEST` / `_exit_tree` → `release_lock()` hook, started in `boot()` not `_ready()`. They exist only once `ProfileStore` does — leave the hook points named in a comment and implement them in the Meta Progression epic. Story 007 lists them.
- Test (`tests/integration/boot/boot_composition_test.gd`, gdUnit4): `test_boot_autoload_is_not_booted_before_boot_call` (QQ-04), `test_boot_twice_returns_same_services_without_reload`, `test_boot_meta_override_is_placed_in_services`, `test_boot_card_database_override_is_used`, `test_boot_failed_load_returns_not_ok_with_report`, `test_boot_settings_bus_is_shared_with_meta`, `test_boot_data_load_within_budget_ms` (threshold from `TestConstants`, sourced from `config("content_budgets")` / architecture §Performance budgets — never a literal). Use `auto_free` on any Node the test adds; the autoload itself is owned by the tree.
- `Boot` is referenced only from `src/scenes/`, `src/ui/**/*_view.gd`, `src/ui/**/run_shell.gd`, `*_debug_loader.gd` and `tests/` — story 005's gate G3 enforces it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: the grep gates (G3, G4) and the per-file parse check that enforce this story's rules in CI.
- Story 006: `src/scenes/main.tscn` calling `Boot.boot()` and the `RunShell` stub.
- Story 007: the written "Boot responsibilities" list for the control manifest.
- Meta Progression epic: `ProfileStore` + `MetaFacade` construction (the one-line switch, TODO in `boot.gd`), the heartbeat / debounce `Timer` children, `release_lock()` on exit.
- Card Database epic: `CardDatabase`, `DataLoader`, `ValidationReport`, `FILE_MANIFEST`.
- Each later epic: its own validator line in `_collect_validators()`.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/core/boot.gd`
- `src/core/services.gd`
- `src/core/boot_result.gd`
- `project.godot` (`[autoload]` section — exactly `Boot`)
- `tests/integration/boot/boot_composition_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level` (`standard`): tests must exist and pass.*

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/boot/boot_composition_test.gd` — must exist and pass (the epic's Definition of Done names `tests/integration/boot/` proving `boot()` idempotence, `BootResult` on a Failed data load, and the `{meta: MetaStub.new(...)}` override)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boot-composition-root/story-001-settings-bus.md`, `production/epics/boot-composition-root/story-003-meta-stub.md`; **cross-epic**: the `card-database` epic's `CardDatabase` + `ValidationReport` (`load(validators)`, `state()`, `report()`, `config()`) — story path not known at creation
- Unlocks: `production/epics/boot-composition-root/story-005-lint-gates-ci.md`, `production/epics/boot-composition-root/story-006-main-scene-composition-entry.md`, `production/epics/boot-composition-root/story-007-boot-responsibilities-manifest.md`; every other epic's scene root / debug loader
