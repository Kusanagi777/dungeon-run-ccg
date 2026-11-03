# Story 001: SettingsBus

> **Epic**: Boot & Composition Root
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: — (no system GDD; `docs/architecture/architecture.md` §Module Ownership → Foundation layer, row `SettingsBus`; §Data Flow 5 Initialisation order, step 4; `design/gdd/meta-progression.md` M9 for the key set the bus carries)
**Requirement**: `TR-design-decisions-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Save Format and Atomic Profile Write (the class is ADR-0004's); ADR-0011: Run UI Shell Pattern and the Meta Stub Injection Seam (its consumers and the `get_setting` read)
**ADR Decision Summary**: Settings reach every consumer (Run UI, Match UI, Boss AI) through one `SettingsBus` — a `RefCounted` whose only job is the `settings_changed(key, value)` signal; the profile owner (`ProfileStore`, or `MetaStub` for the MVP) emits, nothing reads settings from Run UI.
**ADR Version**: 2026-11-03 (ADR-0004 and ADR-0011, both `Last Verified` 2026-11-03)

**Engine**: Godot 4.7.2 | **Risk**: MEDIUM (ADR-0004's rating; this story uses only Godot signals — LOW per architecture.md Module Ownership — and no post-cutoff API)
**Engine Notes**: Godot signals (LOW). Lambdas capture locals by value (4.5+, `current-best-practices.md` §GDScript 4.5+) — a subscriber that accumulates state closes over a Dictionary or object. No `FileAccess`, no `user://` in this class.

**Control Manifest Rules (this layer)**:
- Required: Every class under `src/core/**` `extends RefCounted`; every collaborator arrives through `_init(...)` or an explicit `bind(...)` — ADR-0001
- Required: `Services` bag field `settings_bus`; `SettingsBus` is ADR-0004's class, `signal settings_changed(key: StringName, value: Variant)` — ADR-0004, ADR-0011
- Forbidden: Never reference `Boot` or `Services` from `src/core/**` (minus `boot.gd`) — gate G3; never a second event channel in `src/core/` — ADR-0001, ADR-0003
- Guardrail: none specific (the bus holds no data and runs no tick)

---

## Acceptance Criteria

*From `docs/architecture/architecture.md` §Module Ownership (Foundation, `SettingsBus` row), ADR-0004 Decision 9 / Key Interfaces and ADR-0011 Decision 4, scoped to this story:*

- [ ] `src/core/save/settings_bus.gd` declares `class_name SettingsBus extends RefCounted` with exactly one signal, `settings_changed(key: StringName, value: Variant)`, and `get_setting(key: StringName) -> Variant`; it owns nothing beyond the last value published per key (architecture.md: "Nothing — a `RefCounted` with one signal") and takes no collaborator.
- [ ] Publishing a value for a key (the publish entry point the profile owner calls — architecture.md Data Flow 5 step 4 "publishes the settings record once"; ADR-0011 fixes only `settings_changed` and `get_setting`, so `/dev-story` names it) fires `settings_changed` exactly once with `(key, value)`, synchronously, and `get_setting(key)` then returns that value; `get_setting` of a key never published returns `null`.
- [ ] The file passes `.claude/scripts/godot-parse-check.gd` on its own and contains no `Boot`, `Services`, Node, `Timer`, `get_tree()` or `await` token (gates G1–G3, G2b).

---

## Implementation Notes

*Derived from ADR-0004 Decision 9 and Implementation Guidelines, ADR-0011 Decision 4 / Key Interfaces:*

- `src/core/save/settings_bus.gd` — `class_name SettingsBus extends RefCounted`; `signal settings_changed(key: StringName, value: Variant)`; `func get_setting(key: StringName) -> Variant`. The path is fixed by ADR-0011 ("`src/core/save/settings_bus.gd` — ADR-0004's class").
- The bus stores only what was last published, so `get_setting` can answer consumers that connect late (Match UI mounts after the profile is published). It performs no clamping and no validation — that is the profile owner's (`MetaStub` M9 ranges in story 003; `ProfileStore` later).
- Emitting is the owner's responsibility: `ProfileStore.set_setting` (debounced write, ADR-0004 Decision 8) or `MetaStub.set_setting` (story 003) emits; `RunShell` applies `anim_speed`, `text_scale`, `gamma`, `high_contrast_states`, volumes, `fullscreen`; `MatchView` and `BossAI` apply their own keys (ADR-0011 Decision 4). Nothing in this story subscribes.
- Settings are read only through `SettingsBus` / `get_settings()`; Run UI never passes settings to Match UI (ADR-0011 Implementation Guidelines).
- No Node, no `Timer`, no `SceneTree` reference: the debounce `Timer` for `set_setting` belongs to `Boot` (ADR-0004 Decision 8) and is out of this epic's MVP scope (no `ProfileStore` yet).
- Test with gdUnit4 `assert_signal` / `GameAssertions.assert_signal_emitted` from `tests/helpers/game_assertions.gd`; construct the bus directly, never through `Boot`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003 (`MetaStub`): M9 clamping and the `set_setting` → `settings_changed` emit for the MVP profile owner.
- Story 004 (`Boot`): placing the bus in `Services.settings_bus`.
- Meta Progression epic: `ProfileStore.set_setting`, the 500 ms debounce `Timer` on `Boot`, `flush_settings()`.
- Run UI / Match UI epics: every subscriber that applies a key.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/core/save/settings_bus.gd`
- `tests/unit/boot/boot_settings_bus_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level` (`standard`): tests must exist and pass.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boot/boot_settings_bus_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/boot-composition-root/story-002-meta-api-abstract-seam.md`, `production/epics/boot-composition-root/story-003-meta-stub.md`, `production/epics/boot-composition-root/story-004-boot-composition-root.md`
