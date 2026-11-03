# Story 002: MetaApi abstract seam

> **Epic**: Boot & Composition Root
> **Status**: Complete
> **Layer**: Foundation (file lives at `src/gameplay/meta/` per the layer map; the seam is a Foundation contract)
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/meta-progression.md` (M1.3 Persistence API — the method list; M1.3 "Name mapping" paragraph); `design/gdd/systems-index.md` §Circular Dependencies (Run Structure <-> Meta); `docs/architecture/architecture.md` §Dependency injection and the composition root (`@abstract` bases)
**Requirement**: `TR-systems-index-001` (also `TR-design-decisions-001`)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Save Format and Atomic Profile Write (Decision 9 — the seam); ADR-0011: Run UI Shell Pattern and the Meta Stub Injection Seam (Decision 4 — injection, `unlock_granted`, `settings_bus`); ADR-0001: Rules / Presentation Split (Decision 7 — `@abstract` bases, typed-return rule)
**ADR Decision Summary**: `MetaApi` is an `@abstract class_name MetaApi extends RefCounted` declaring the whole meta-progression M1.3 surface (persistence subset and rules half) plus `load_status()`; two implementations exist, `MetaFacade` (later) and `MetaStub` (MVP), and Run Structure, Reward Draft and Run UI code against `MetaApi` only, never downcasting.
**ADR Version**: 2026-11-03 (ADR-0004, ADR-0011, ADR-0001 — all `Last Verified` 2026-11-03)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0001: `@abstract` is 4.5, the typed-return override rule is 4.7 — both post-cutoff)
**Engine Notes**: `@abstract` class and `@abstract func` (4.5, sourced in `current-best-practices.md` §GDScript 4.5+); an override of a typed method inherits the return type and needs an explicit `return` (4.7, `breaking-changes.md` 4.6→4.7). Engine validation 2026-11-03 observed: one-line `@abstract class_name` is equivalent to the two-line form (static enforcement only). ADR-0001 Verification (1): the first unit test that instantiates a concrete subclass proves `@abstract` parses and refuses direct instantiation on 4.7.2 — this story's test is that test.

**Control Manifest Rules (this layer)**:
- Required: Interfaces with two implementations are `@abstract` base classes (`MetaApi`, …); every override of a typed method ends in an explicit `return` (4.7 rule) — ADR-0001, ADR-0004, ADR-0011
- Required: Every class under `src/gameplay/**` `extends RefCounted`; collaborators arrive through `_init(...)` or `bind(...)` — ADR-0001
- Forbidden: Never reference `Boot` or `Services` from `src/gameplay/**` — gate G3; never `MetaStub` as an `in_memory` flag inside `MetaFacade` — the seam is "inject a different object" — ADR-0004 (Alt 6)
- Guardrail: none (an abstract declaration runs nothing)

---

## Acceptance Criteria

*From `design/gdd/meta-progression.md` M1.3 and ADR-0004 Decision 9 / ADR-0011 Key Interfaces, scoped to this story:*

- [ ] `src/gameplay/meta/meta_api.gd` declares `@abstract class_name MetaApi extends RefCounted` with every M1.3 method as an `@abstract func` carrying M1.3's typed return: `load_profile`, `save_profile`, `save_active_run`, `load_active_run`, `clear_active_run`, `archive_run`, `is_hero_unlocked`, `is_unlocked`, `unlocked_ids`, `unlocked_keys`, `is_treasure_unlocked`, `unlock_progress`, `unlock_hint`, `set_setting`, `get_setting`, `get_settings`, `stats_for_hero`, `last_hero_id`, `run_log`, `run_log_entry`, `pending_notifications`, `ack_notification`, `validate_unlock_defs`, `reset_profile`, plus `load_status()` returning one of `OK | RECOVERED_BAK | FRESH | FRESH_AFTER_CORRUPT | E_SCHEMA_NEWER | E_LOCKED` (ADR-0004 Decision 9; ADR-0011).
- [ ] It declares `signal unlock_granted(key: String, kind: StringName, id: String, by_run_id: String, retro: bool)` and `var settings_bus: SettingsBus` (ADR-0011 Key Interfaces) and nothing else: no state, no default behaviour, no collaborator.
- [ ] `MetaApi.new()` is refused on Godot 4.7.2 while a minimal concrete subclass declared inside the test (every override with an explicit `return`) instantiates and is `is MetaApi` (ADR-0001 Engine Compatibility verification 1); the file passes `.claude/scripts/godot-parse-check.gd` on its own and holds no `Boot`, `Services`, Node or `await` token (gates G1–G3).

---

## Implementation Notes

*Derived from ADR-0004 Decision 9 and Implementation Guidelines, ADR-0011 Decision 4 and Key Interfaces, ADR-0001 Decision 7:*

- Path and name are fixed: `src/gameplay/meta/meta_api.gd`, `@abstract class_name MetaApi extends RefCounted`. Method names are the GDD's (M1.3 is authoritative over run-ui.md's proposed names — the M1.3 "Name mapping" paragraph).
- Return types follow M1.3 literally: `load_profile() -> Dictionary` (`{status, profile}`), `save_profile() -> Error`, `save_active_run(record: Dictionary) -> Error`, `load_active_run() -> Variant` (Dictionary or null), `clear_active_run() -> void`, `archive_run(record: Dictionary) -> Dictionary` (`{ok, unlocks_granted}`), `is_hero_unlocked(hero_id: String) -> bool`, `is_unlocked(key: String) -> bool`, `unlocked_ids(kind: StringName) -> Array`, `unlocked_keys() -> Array` (the set `Treasures.pool()` takes), `is_treasure_unlocked(treasure_id: String) -> bool`, `unlock_progress(key: String) -> Dictionary`, `unlock_hint(key_or_id: String) -> Dictionary`, `set_setting(key: StringName, value: Variant) -> Error` (`OK | E_RANGE`), `get_setting(key: StringName) -> Variant`, `get_settings() -> Dictionary`, `stats_for_hero(hero_id: String) -> Dictionary`, `last_hero_id() -> Variant`, `run_log(offset: int, limit: int) -> Array`, `run_log_entry(run_id: String) -> Variant`, `pending_notifications() -> Array`, `ack_notification(key: String) -> void`, `validate_unlock_defs(defs: Array) -> Array`, `reset_profile(confirm_token: String) -> Error`, `load_status() -> StringName`.
- `E_RANGE` is `ERR_PARAMETER_RANGE_ERROR`, `E_READONLY` is `ERR_LOCKED`, `E_IO` is `ERR_CANT_CREATE` — mapped once in `src/core/save/save_errors.gd` (ADR-0004). That file belongs to the Meta Progression epic; until it lands, compare against the `Error` constants directly and leave a `TODO(meta-progression)` marker, never a literal.
- `unlock_granted` is the signal `ToastLayer` and `RunController` subscribe to (ADR-0011 Decision 2/3); the base declares it so both implementations emit the same signal.
- Run Structure, Reward Draft and Run UI take `MetaApi` as a constructor argument and never downcast; `MetaStub` / `MetaFacade` are named by type only in `Boot`, debug loaders and tests (ADR-0004 Implementation Guidelines).
- Doc-comment every method (coding standard: public APIs carry doc comments); cite the M-rule each one serves.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003 (`MetaStub`): the MVP implementation and its `calls` recorder / `from_fixture`.
- Meta Progression epic: `MetaFacade`, `ProfileStore`, `UnlockEvaluator`, `StatsFold`, `save_errors.gd`.
- Story 004 (`Boot`): placing an implementation in `Services.meta`.

---

## Files

- `src/gameplay/meta/meta_api.gd`
- `tests/unit/boot/boot_meta_api_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level` (`standard`): tests must exist and pass.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boot/boot_meta_api_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 11 test functions, passing (full suite exit 0, 2026-11-03)

---

## Dependencies

- Depends on: `production/epics/boot-composition-root/story-001-settings-bus.md` (the `settings_bus: SettingsBus` field needs the class)
- Unlocks: `production/epics/boot-composition-root/story-003-meta-stub.md`; the Meta Progression epic's `MetaFacade` story; Run Structure / Reward Draft / Run UI stories that take `MetaApi`

---

## Completion Notes
**Completed**: 2026-11-03
**Criteria**: 3/3 passing — AC-1 `boot_meta_api_test.gd::test_meta_api_declares_exactly_the_m13_methods_plus_load_status`, `::test_meta_api_methods_carry_m13_typed_returns`, `::test_every_meta_api_method_is_abstract`; AC-2 `::test_meta_api_declares_only_unlock_granted_with_five_typed_args`, `::test_meta_api_declares_only_settings_bus_variable_typed_settings_bus`, `::test_concrete_subclass_settings_bus_starts_null`; AC-3 `::test_meta_api_new_is_refused_at_parse_time`, `::test_subclass_missing_overrides_is_refused_at_parse_time`, `::test_concrete_subclass_instantiates_and_is_meta_api`, `godot-parse-check.gd` exit 0 on the file alone, G1/G2/G2b/G3 grep on it: no hits
**Engine observations (4.7.2)**: `@abstract` refusal is parse-time — `MetaApi.new()` written in source fails with `Cannot construct abstract class "MetaApi"`, so the test compiles it from a string (`GDScript.reload()` != OK, captured with `assert_error(...).is_runtime_error(...)`); `load(path).new()` is NOT refused at runtime (matches engine-validation-2026-11-03.md). `Script.can_instantiate()` returns true for the abstract script, so `godot-parse-check.gd` passes it. `@abstract func` sets `METHOD_FLAG_VIRTUAL_REQUIRED` (128) — observed, not in `docs/engine-reference/`.
**Deviations**: None. `load_status()` values are documented `StringName`s (`&"FRESH"` …); no constants were declared, because AC-2 allows nothing beyond the signal and `settings_bus`. `save_errors.gd` is still absent: the doc comment carries the `TODO(meta-progression)` marker.
**Test Evidence**: `tests/unit/boot/boot_meta_api_test.gd` (11 tests); full suite `commands.test` exit 0, 87 test cases, 0 failures; mutation check (`load_status` made concrete) observed failing, exit 100, then restored
**Run result**: N/A — an abstract declaration with no scene, Node or rendered output; nothing a player can see changes
**Reviewed by**: self, no independent review (QL-TEST-COVERAGE skipped — Lean mode; LP-CODE-REVIEW skipped — Lean mode; `/code-review` not run)
