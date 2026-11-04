# Story 001: `Treasures` installers — `installers_for`, `passive_installer`, `collect_state`

> **Epic**: Treasures
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]
> **First Playable path**: yes (for fidelity) — every band-1 boss carries a passive, which reaches the match only through `passive_installer`

## Context

**GDD**: `design/gdd/treasures.md` (T3, T4, T5.2, Edge Cases "Installation and ordering" / "State and persistence", AC-1, AC-4, AC-10)
**Requirement**: `TR-treasures-002`, `TR-treasures-003` (the `collect_state` half)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Owner-scoped hook registry
**ADR Decision Summary**: `Treasures.installers_for(treasure_ids, treasure_state)` is pure and idempotent and returns one `HookInstaller` per treasure in pick order. On a repeated id the first is kept and the caller logs `run_warning{duplicate_treasure}`; on an unknown `treasure_state.schema_version` the state is ignored and the caller logs `run_warning{treasure_state_reset}`. `passive_installer(boss_def)` yields `[]` or one installer with side `"boss"`. `treasure_state` is read only in `installers_for` and written only in `collect_state` (v1: `{schema_version: 1, by_treasure: {}}`).
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (language, by version); LOW for the APIs (`RefCounted`, `Dictionary`, `Array`, `StringName`)
**Engine Notes**: ADR-0005 Engine Compatibility — lambdas capture locals by value (sourced); typed-method overrides return explicitly (4.7). No `NOT SOURCEABLE` item.

**Control Manifest Rules (this layer)**:
- Required: `installers_for(treasure_ids, treasure_state)` pure, idempotent, pick order; `passive_installer(boss_def)` → `[]` when `passive == null`, else one installer, side `"boss"`; `treasure_state` read only in `installers_for`, written only in `collect_state`
- Forbidden: never mutate `RunState` from `src/gameplay/treasures/`; `HookInstaller` never references `RulesEngine`, `EventLog`, `MatchState`, a Node, an autoload or the registry; never a global priority-ordered modifier manager (the prototype's, TD-009)
- Guardrail: ≤ 12 entries per match (F5); `installers_for` draws no RNG and emits no event

This is the first code under `src/gameplay/treasures/`, and it unblocks card-effects story 014, which sprint 4 left blocked on "a treasures `HookInstaller` / `passive_installer`". `HookInstaller` itself already exists (`src/gameplay/match/hook_installer.gd`, match-rules story 002). This story builds installers and does not redefine the type.

---

## Acceptance Criteria

*From GDD `design/gdd/treasures.md` (T3.1–T3.2, T4, T5.2, AC-1, AC-4, AC-10), scoped to this story:*

- [ ] **AC-1** GIVEN ids `[treasure_worn_signet, treasure_hollow_crown]` over the 20-record fixture, WHEN `installers_for` is called twice, THEN both results are equal (by `to_dict()`), in that order, each `{host_kind: treasure, host_id, side: player, effects: copy of TreasureDef.effects, state: treasure_state.by_treasure[host_id] or {}}` (T3.2); no event is emitted and the `treasure_state` passed in is unchanged (`installers_for` receives no `RunState`, T5.1).
- [ ] **AC-4** GIVEN `installers_for([signet, crown, signet])`, THEN two installers are returned, `[signet, crown]`, and the dropped duplicate `treasure_worn_signet` is reported to the caller, who emits `run_warning{code: duplicate_treasure, treasure_id: treasure_worn_signet}` (ADR-0005: the caller logs; `Treasures` holds no log).
- [ ] **AC-10** GIVEN any v1 pool subset, WHEN `collect_state(hooks, match_result)` runs after `match_ended`, THEN it returns `{schema_version: 1, by_treasure: {}}`; GIVEN a `treasure_state` with `schema_version: 99`, WHEN `installers_for` is called, THEN the installers equal a stateless run's (`state == {}` on each) and the reset is reported to the caller, who emits `run_warning{treasure_state_reset}`.
- [ ] **AC-T3.1 (boss passive)** GIVEN a `BossDef` with `passive: null`, WHEN `passive_installer(boss_def)`, THEN `[]`; GIVEN `boss_test_taxman` (passive `modify_cost delta +1` on all friendly cards and the hero power), THEN exactly one installer `{host_kind: passive, host_id: boss_test_taxman, side: boss, effects: [passive], state: {}}`.

---

## Implementation Notes

*Derived from ADR-0005 Decision (rules 2, 5, 8) and Key Interfaces:*

- `class_name Treasures extends RefCounted`; `_init(db: CardDatabase, balance_config: Dictionary)` per ADR-0005 Key Interfaces (`balance_config` = `db.config("treasures_balance")`, read once). Signatures exactly: `installers_for(treasure_ids: Array, treasure_state: Dictionary) -> Array[HookInstaller]`, `collect_state(hooks: HookRegistry, result: MatchResult) -> Dictionary`, `static func passive_installer(boss_def: Dictionary) -> Array[HookInstaller]`.
- Build each installer with `HookInstaller.new(HookInstaller.HOST_KIND_TREASURE, id, &"player", db.treasure(id).effects, state)`. The constructor already copies `effects` and `state` by value.
- **How the caller learns of a dropped duplicate or a reset.** ADR-0005 places the log append with the caller (`RunMachine`) and does not fix the channel. Expose it without logging, either as a side result the caller reads or as a pure helper the caller runs first. The choice is the implementer's; record it in Completion Notes. The `run_warning` events themselves are asserted at the caller (story 011).
- `BossDef.passive` is **one effect object** in `bosses.json` (all five MVP bosses), not an array, so wrap it: `effects = [passive]`. `host_id` = the boss id (ADR-0005 diagram).
- `collect_state` reads `hooks.hosts()` (ADR-0005 rule 8) and returns the v1 shape. No v1 treasure persists state (T4), so the result does not depend on `result`. Never write `RunState`.
- Create the GDD's fixtures here, for every later story to share: `tests/fixtures/data/treasures_v1.json` (the 20 T8 records, transcribed from T8/T9 with `unlock` objects per DD-X01; Living Armory's key is `first_victory`, DD-X12) and a boss fixture `boss_test_taxman` whose passive is `modify_cost delta +1` on all friendly cards and the hero power. This epic's tests use `run_seed_hex` `00000000000000A7` unless a story states otherwise (GDD AC preamble).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: binding installers into a live `HookRegistry` (installation order, `hook_install_skipped`, clone)
- Story 009: `pool(unlocked_keys, exclude_ids)`
- Story 011: the caller (`RunMachine.begin_match` / resume) logging the two `run_warning`s
- Match-rules story 002 (Complete): `HookRegistry`, `HookEntry`, `HookInstaller`

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/gameplay/treasures/treasures.gd` — created (`Treasures`: `_init`, `installers_for`, `passive_installer`, `collect_state`)
- `tests/unit/treasures/treasures_installers_test.gd`
- `tests/fixtures/data/treasures_v1.json` — the 20 T8 records
- `boss_test_taxman` fixture (beside the treasure fixture, or as a `tests/helpers/card_factory.gd` record)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level: standard`.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/treasures/treasures_installers_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None in this epic. Cross-epic (Complete): `production/epics/match-rules/story-002-hook-registry.md`, `production/epics/card-database/story-006-freeze-and-queries.md`
- Unlocks: `production/epics/card-effects/story-014-value-hook-folds.md` (its treasures dependency), `production/epics/card-effects/story-015-hook-trigger-steps-hero-slot-observers.md`; every later treasures story; the First Playable boss passive in `MatchConfig.boss.hook_installers`
