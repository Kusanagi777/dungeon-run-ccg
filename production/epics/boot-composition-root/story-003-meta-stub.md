# Story 003: MetaStub — the MVP MetaApi implementation

> **Epic**: Boot & Composition Root
> **Status**: Complete
> **Layer**: Foundation (file at `src/gameplay/meta/` per the layer map; shipped as the MVP `Services.meta`)
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/meta-progression.md` (M1.3 Persistence API; M9 Settings — the record, ranges and defaults; M10 "MVP: every treasure `unlock: null`, `is_hero_unlocked` trivially true"); `design/gdd/systems-index.md` §Circular Dependencies ("the MVP ships a Meta stub")
**Requirement**: `TR-systems-index-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Run UI Shell Pattern and the Meta Stub Injection Seam (Decision 4 — the stub's behaviour, `from_fixture`, `calls`); ADR-0004: Save Format and Atomic Profile Write (Decision 9 — path and role; error vocabulary)
**ADR Decision Summary**: The MVP ships `MetaStub` behind `Services.meta`: in-memory, settings from `config("profile_defaults")`, every hero / treasure / key unlocked, one active-run record held in memory (so suspend → Continue works within a session), no run log, no notifications, `calls` recorded for tests; `Boot.boot({meta: stub})` and `RunDebugLoader` use the same seam.
**ADR Version**: 2026-11-03 (ADR-0011 and ADR-0004, both `Last Verified` 2026-11-03)

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0011's rating; this story's engine exposure is the 4.7 typed-return override rule on every method and `@abstract` from 4.5)
**Engine Notes**: Every `MetaApi` override must end in an explicit `return` (4.7 rule, sourced) — a missing one is a parse error, not a warning. `JSON`-sourced numbers in a fixture arrive as `float`; coerce with `int()` where M9 declares `int` (`action_delay_ms`) — never trust `JSON.parse_string` to return an `int` (ADR-0004). No `FileAccess`: fixtures are handed in as a Dictionary (the loader that reads `tests/fixtures/run_ui/<name>.json` is `RunDebugLoader`, Run UI epic).

**Control Manifest Rules (this layer)**:
- Required: Read `config(<name>)` once in the owner's `_init(...)` and keep the reference — ADR-0002
- Required: Interfaces with two implementations are `@abstract` base classes; every override of a typed method ends in an explicit `return` — ADR-0001, ADR-0004, ADR-0011
- Required: Treat every returned Dictionary/Array from `CardDatabase` as read-only; a system that mutates takes `duplicate(true)` first — ADR-0002, ADR-0005
- Forbidden: Never a numeric gameplay default in code — defaults come from `config("profile_defaults")`; never hardcode knobs — ADR-0002, ADR-0004
- Forbidden: Never `MetaStub` as an `in_memory` flag inside `MetaFacade`; never reference `MetaStub` by type outside `Boot`, debug loaders and tests — ADR-0004
- Guardrail: none specific (no I/O, no tick)

---

## Acceptance Criteria

*From `design/gdd/meta-progression.md` M1.3 / M9 / M10 and ADR-0011 Decision 4, scoped to this story:*

- [ ] `MetaStub.new(db)` (`src/gameplay/meta/meta_stub.gd`, `class_name MetaStub extends MetaApi`, `_init(db: CardDatabase, mirror: ProfileStore = null)`) is constructible with a `CardDatabase` alone and overrides every `MetaApi` method with an explicit `return`; `load_status()` is `FRESH`; `is_hero_unlocked(id)` is true for every `HeroDef` in data, `is_treasure_unlocked(id)` true for every treasure, `unlocked_keys()` is every unlock key in data; `stats_for_hero` returns zeros, `last_hero_id()` null, `run_log()` and `pending_notifications()` `[]` (M10 MVP: trivially unlocked).
- [ ] `save_active_run(record)` / `load_active_run()` / `clear_active_run()` round-trip one record in memory within a session (S23 suspend → Continue); `archive_run(record)` returns `{ok: true, unlocks_granted: []}` and leaves `run_log()` empty; every mutator call (`save_active_run`, `clear_active_run`, `archive_run`, `set_setting`, `ack_notification`, `reset_profile`) is appended to `calls` as `{method, args}`.
- [ ] Settings start as the frozen `db.config("profile_defaults")` body read once in `_init` (copied with `duplicate(true)` before any write); `get_settings()` / `get_setting(key)` return them; `set_setting(key, value)` with a value inside M9's declared range or enum returns `OK`, stores it and emits `settings_bus.settings_changed(key, value)` exactly once; an out-of-range float / int, an unknown enum label or an unknown key returns `E_RANGE` (`ERR_PARAMETER_RANGE_ERROR`), stores nothing and emits nothing (M1.3 `set_setting -> OK | E_RANGE`; see Implementation Notes on ADR-0011's "clamps" wording).
- [ ] `MetaStub.from_fixture(db, fixture)` builds a stub whose settings are the fixture's `settings` keys merged over the defaults (unknown keys preserved, known keys range-checked per M5.3) and whose `load_active_run()` returns the fixture's `active_run` when present, `null` otherwise.

---

## Implementation Notes

*Derived from ADR-0011 Decision 4 and Implementation Guidelines, ADR-0004 Decision 9:*

- Behaviour table (ADR-0011 Decision 4, verbatim intent): `load_status()` = `FRESH`; `is_hero_unlocked` = true for every `HeroDef` (`db.heroes()`); `unlocked_keys()` = every unlock key in data (treasure `unlock` fields, hero `unlock` fields — all `null` at MVP, so the array may be empty; the method still answers from data, never from a literal); `is_treasure_unlocked` = true; one in-memory active run; `archive_run` → `{ok: true, unlocks_granted: []}` appending nothing; `run_log()` = `[]`; `pending_notifications()` = `[]`; `stats_for_hero` = zeros; `last_hero_id()` = null (→ War pre-selected, DD-X02); settings = `config("profile_defaults")` held in memory. `unlock_progress` / `unlock_hint` return the F6 shape with `met: true` (everything unlocked); `validate_unlock_defs` returns `[]` at MVP (the real validator is Meta Progression's — leave a `TODO(meta-progression)` and do not invent rules); `reset_profile(token)` resets the in-memory record to defaults and returns `OK`; `save_profile()` returns `OK`.
- **`set_setting` range rule.** M1.3 declares `set_setting(key, value) -> OK | E_RANGE`; M9 gives each key's range / enum / default; ADR-0011 Decision 4 says the stub "clamps per M9 ranges and emits". The GDD is the design authority, so the story takes `E_RANGE`-and-no-emit for a bad value and clamp-on-load only (M9 last sentence, `gamma`). Note this in the `/story-readiness` run; if the owner prefers clamping, it is a one-line GDD change, not a story change.
- M9 ranges to check (read them from the GDD at implementation, do not retype from memory): `volume_*` float 0..1; `fullscreen` bool; `anim_speed` ∈ `instant|fast|normal`; `reduce_motion` bool; `text_scale` ∈ 1.0|1.25|1.5; `high_contrast_states` bool; `telegraph_mode` ∈ `full|brief|off`; `action_delay_ms` int 0..2000; `gamma` float 0.8..1.4; `keep_run_records` bool; `language`; `bindings` (opaque map, absent in defaults, `cancel` key dropped — ADR-0004 addendum; the `InputMap` application is Alpha and not this epic's).
- `calls: Array[Dictionary]` records every mutator for tests (ADR-0004 Decision 9 "records calls for tests"; ADR-0011 Key Interfaces).
- Optional `mirror: ProfileStore` is accepted and stored but unused at MVP ("lets a later build write-through without changing consumers") — do not implement write-through here.
- `settings_bus` is created by the stub in `_init` (ADR-0011: "the implementation persists (or holds) and emits") unless `Boot` later chooses to pass one in; either way `Services.settings_bus` and `MetaApi.settings_bus` must be the same object (story 004 asserts it).
- The test constructs `MetaStub` directly with a `CardDatabase` (never through `Boot`); use `TestConstants` for any gameplay number and `GameAssertions.assert_signal_emitted` for the emit.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004 (`Boot`): the `MetaStub.new(card_database)` construction line and the `{meta: …}` override.
- Run UI epic: `RunDebugLoader` (`--run-ui-screen` / `--run-ui-fixture`, reading `tests/fixtures/run_ui/<name>.json`).
- Meta Progression epic: `MetaFacade`, `ProfileStore`, unlock evaluation (F1), stats fold (F2), `validate_unlock_defs` rules, write-through `mirror`.
- Deferred (index §Deferred): applying `settings.bindings` to `InputMap` (Alpha, TR-accessibility-requirements-001).

---

## Files

- `src/gameplay/meta/meta_stub.gd`
- `tests/unit/boot/boot_meta_stub_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level` (`standard`): tests must exist and pass.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boot/boot_meta_stub_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 50 test functions, passing (full suite exit 0, 2026-11-03)

---

## Dependencies

- Depends on: `production/epics/boot-composition-root/story-001-settings-bus.md`, `production/epics/boot-composition-root/story-002-meta-api-abstract-seam.md`; **cross-epic**: the `card-database` epic's `CardDatabase` class with `config()`, `heroes()`, `treasure_pool()` and a loadable `profile_defaults.json` (story path not known at creation — that epic's stories are being written concurrently)
- Unlocks: `production/epics/boot-composition-root/story-004-boot-composition-root.md`; Run UI epic's `RunDebugLoader` and `tests/unit/run_ui/` stories

---

## Completion Notes
**Completed**: 2026-11-03
**Criteria**: 4/4 passing — AC-1 `boot_meta_stub_test.gd::test_stub_constructs_with_card_database_alone_and_is_meta_api`, `::test_load_status_is_fresh`, `::test_is_hero_unlocked_true_for_every_hero_in_data`, `::test_is_treasure_unlocked_true_for_every_treasure_in_data`, `::test_unlocked_keys_are_every_distinct_unlock_key_in_data`, `::test_stats_for_hero_returns_zero_counts`, `::test_last_hero_id_is_null`, `::test_run_log_and_pending_notifications_are_empty` (+ every override parses with an explicit `return`: parse check exit 0); AC-2 `::test_save_then_load_active_run_round_trips_record`, `::test_clear_active_run_then_load_returns_null`, `::test_archive_run_returns_ok_grants_nothing_and_leaves_run_log_empty`, `::test_every_mutator_call_is_recorded_in_order_with_args`; AC-3 `::test_settings_start_as_profile_defaults_body`, `::test_set_setting_writes_copy_and_leaves_frozen_defaults_untouched`, `::test_set_setting_in_range_float_returns_ok_stores_and_emits_once`, `::test_set_setting_out_of_range_float_returns_e_range`, `::test_set_setting_out_of_range_int_returns_e_range`, `::test_set_setting_unknown_enum_label_returns_e_range`, `::test_set_setting_unknown_key_returns_e_range`; AC-4 `::test_from_fixture_merges_settings_over_defaults_and_keeps_unknown_keys`, `::test_from_fixture_clamps_out_of_range_numbers`, `::test_from_fixture_with_active_run_loads_it`, `::test_from_fixture_without_active_run_loads_null` (50 tests in all)
**Deviations** (all ADVISORY):
- Cross-epic dependency not met (no `CardDatabase`, no `ProfileStore`, no `assets/data/profile_defaults.json`): proceeded with the injected stand-in the story allows — the test's `FakeCardDatabase` (`config`, `heroes`, `treasure_pool`, read-only config body). The constructor is therefore `_init(db: Variant, mirror: RefCounted = null)` and `from_fixture(db: Variant, fixture)`, not `CardDatabase` / `ProfileStore`-typed; `TODO(card-database)` / `TODO(meta-progression)` markers say to tighten the types when those classes land.
- M9's ranges / enums live as `MetaStub.SETTINGS_SCHEMA` (the GDD's declared ranges, cited per key; no default values in code). `TODO(meta-progression)`: move them to the shared `profile_defaults` / M9 validator with `ProfileStore`.
- `set_setting` returns `E_RANGE` and emits nothing for a bad value; clamping happens only on load (`from_fixture`), per M1.3 and M9 — ADR-0011 Decision 4 still says the stub "clamps". The note in Implementation Notes stands; a one-line ADR-0011 wording fix (or a GDD change) is the open item.
- `stats_for_hero` returns zero counts with `fastest_victory_s`, `fewest_turns_victory` and `last_played_at` as `null` (no run played), not `0`.
- The whole `config("profile_defaults")` body is taken as the settings record, as AC-3 says. ADR-0004's diagram reads "defaults + knobs" from the same file; if the data file also carries save knobs, the stub must take only the settings part — open for the card-database / meta-progression epics.
- `reset_profile` restores defaults without emitting; the bus is not seeded with defaults by the stub (architecture.md Data Flow 5 step 4 "publishes the settings record once" is story 004's `Boot`, through `SettingsBus.publish`). A `bindings.cancel` key is dropped with a `push_warning` `profile_repaired{…}` line.
**Test Evidence**: `tests/unit/boot/boot_meta_stub_test.gd` (50 tests); full suite `commands.test` exit 0, 137 test cases, 0 failures; mutation check (gamma max 1.4 → 1.5) observed failing, exit 100, then restored
**Run result**: N/A — an in-memory `RefCounted` with no scene, Node or rendered output; no consumer applies a setting yet, so nothing a player can see changes
**Reviewed by**: self, no independent review (QL-TEST-COVERAGE skipped — Lean mode; LP-CODE-REVIEW skipped — Lean mode; `/code-review` not run)
