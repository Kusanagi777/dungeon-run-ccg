# Story 002: ProfileResolver and the ai_profiles validator

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

## Context

**GDD**: `design/gdd/boss-ai.md` (C10, F9, Edge Cases "Data and determinism")
**Requirement**: `TR-boss-ai-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Boss AI Planner Threading (owns the `runtime` block and names `BossAI.validate_profiles_config`); ADR-0002: Data format and `config()` loading (CR-5 stage-7 validator injection, `config("ai_profiles")`, frozen snapshot)
**ADR Decision Summary**: `ai_profiles.json` is loaded once by `CardDatabase` through the CR-5 pipeline and handed out as `config("ai_profiles")`; Boss AI supplies the `ai_profile` validator injected at stage 7 and the config validator for the file, including ADR-0006's `runtime {planner_mode, slice_ms, replay_budget_ms}` block. `ProfileResolver.resolve(config, boss_def, band)` returns `default ⊕ archetype ⊕ bands[band] ⊕ boss_override` (later wins, shallow per section).
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (version) / LOW (APIs: `Dictionary`, `is_finite`, `JSON` numbers are `float`)
**Engine Notes**: ADR-0002 — `JSON.parse_string` returns `float` for every number (Probe E), so int-ranged fields (`lethal_max_nodes`, `overextend_cap_aoe`, `defensive_margin`) are validated as integral floats. Validator Callables are written as bound methods, not closures (lambdas capture by value, sourced). `Dictionary.make_read_only()` freeze semantics are NOT SOURCEABLE and tested by Card Database; the resolver must not mutate the snapshot.

**Control Manifest Rules (this layer)**:
- Required: `MatchDriver._init` calls `ProfileResolver.resolve(...)` first, then builds the resolver, engine and `BossAI.new(boss_def, resolved_profile, band, config.rng_ai, op_values, config.log)`. `slice_ms`, `replay_budget_ms`, `planner_mode` come from the `ai_profiles.json` `runtime` block, validated by `BossAI.validate_profiles_config`. Tests inject the five-parameter accept-all stub `func(_k, _id, _fx, _db, _configs): return []` into `CardDatabase.load` where they do not test this validator.
- Forbidden: Never make the validator a `RefCounted` instance with cached database access (ADR-0007 Alt 3 — static, pure, allocates its own report). Never read hidden state; profiles are data only.
- Guardrail: none specific — load-time only.

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` A25, A26, C10, F9 and Edge Cases, scoped to this story:*

- [ ] GIVEN `config("ai_profiles")` with `default`, an archetype, `bands` and a `boss_overrides` entry with `extends`, WHEN `ProfileResolver.resolve(config, boss_def, band)` runs, THEN the result is `default ⊕ archetype ⊕ bands[band] ⊕ boss_override` with later sections winning shallowly per section (`weights`, `rules`, `budgets`, `intent_mode`, `choice_preference`, `synergy_tags`), and the F9 example `boss_rot_warden: {extends: passive_driven, synergy_tags: [deathrattle], weights: {w_self: 1.5}}` resolves to `w_passive 2.5`, `w_self 1.5`, the band's `budgets` and `defensive`, and `synergy_tags == ["deathrattle"]`.
- [ ] **A25** GIVEN a BossDef with `ai_profile = "does_not_exist"`, WHEN Card Database loads with the injected stage-7 validator, THEN `E_AI_PROFILE_UNKNOWN` is reported; WHEN a match starts anyway (release), THEN the boss plays with `default ⊕ bands[band]` (resolver fallback; A6 still holds in Story 007's fixture).
- [ ] **A26** GIVEN `w_face = 9` in a profile, WHEN loaded, THEN `E_AI_WEIGHT_RANGE` is reported and the effective weight is 5 (clamped to the Tuning Knobs range, never zeroed), visible in `ai_decision.features`; a non-finite weight reports the same code.
- [ ] GIVEN the file, WHEN `BossAI.validate_profiles_config` runs, THEN an unknown field reports `E_AI_UNKNOWN_FIELD`; an op type used by a loaded card with no `op_values` row is valued 1.0 and reports `E_AI_OP_UNVALUED` once per op type per load; the `runtime` block accepts `planner_mode ∈ {worker, time_sliced, immediate}` (default `worker`), `slice_ms` and `replay_budget_ms` (defaults 2 and 2) and rejects anything else; a missing file is Card Database CR-1's `E_MISSING_FILE` (no runtime default).

---

## Implementation Notes

*Derived from ADR-0002 and ADR-0006 Implementation Guidelines:*

- Files: `src/ai/profile_resolver.gd` (`class_name ProfileResolver extends RefCounted`, `static func resolve(config: Dictionary, boss_def: Dictionary, band: int) -> Dictionary`) and the static validators on `src/ai/boss_ai.gd`: `validate_ai_profile(host_kind, host_id, ...)` in the five-parameter shape Card Database injects at stage 7, and `validate_profiles_config(config) -> Array` returning report rows with the closed `E_AI_*` code set (`E_AI_PROFILE_UNKNOWN`, `E_AI_WEIGHT_RANGE`, `E_AI_UNKNOWN_FIELD`, `E_AI_OP_UNVALUED`). Any `E_AI_*` falls back to `default` at runtime; CI treats every `E_AI_*` as a failure (C10).
- Weight ranges are F1's table (`w_board` 0–5, `w_face` 0–5, `w_self` 0–5, `w_trade` 0–3, `w_threat` 0–5, `w_mana` 0–3, `w_card` 0–3, `w_over` 0–3, `w_heal` 0–3, `w_hp` 0–2, `w_passive` 0–5; `BV_NORM`/`THREAT_NORM` 5–20; `trade_ratio` 0.5–2.0; `tie_epsilon` 0–0.5; `overextend_cap_aoe` 2–7; `burn_per_mana` 0–2; `defensive_margin` 0–10) — carry them as one `const RANGES` table that names its F1 row, the only numbers allowed in `src/ai/**` outside normalisers (A29 grep gate, Story 012).
- The resolver reads the frozen snapshot and allocates a new Dictionary; it never writes back. `intent_mode` `hidden` is legal only in a `boss_overrides` entry (C8.4) — the validator reports `E_AI_UNKNOWN_FIELD`-class error if a `profiles` or `bands` entry sets it (closed set per section).
- Headless tests that need an AI without the data file inject a stub `default`-shaped Dictionary into the constructor (Edge Cases); the stub never ships in the loader.
- The validator's injection point (CR-5 stage 7) is Card Database's code (`card-database` epic); this story delivers the Callable and tests it directly.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: the shipped `assets/data/ai_profiles.json` contents and the five MVP overrides.
- Story 004: how the weights are used in scoring.
- `card-database` epic: wiring the validator into CR-5 stage 7 and `E_MISSING_FILE`.

---

## Files

- `src/ai/profile_resolver.gd` (new)
- `src/ai/boss_ai.gd` (new — schema constants and static validators only)
- `src/core/boot.gd` (`_collect_validators`: `configs.ai_profiles` registered; TODO line renamed)
- `tests/unit/boss_ai/boss_ai_profile_resolver_test.gd` (new, 46 tests)
- `tests/fixtures/boss_ai/profiles_stub.json` (new)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_profile_resolver_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [x] Created — 46 tests, passing

---

## Dependencies

- Depends on: None inside this epic (`card-database` epic's `CardDatabase.config()` for the live path; tests use the stub)
- Unlocks: `production/epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md`, `production/epics/boss-ai-match-driver/story-004-scorer-features-and-board-value.md`, `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`

---

## Completion Notes
**Completed**: 2026-11-03 (started 21:00:39 UTC, finished 21:14:43 UTC)
**Criteria**: 4/4 passing (all in `tests/unit/boss_ai/boss_ai_profile_resolver_test.gd`) — AC-1 layering `::test_resolve_rot_warden_example_layers_default_archetype_band_and_override` (F9 example: `w_passive 2.5`, `w_self 1.5`, band budgets/`defensive`, `synergy_tags == ["deathrattle"]`), `::test_resolve_band_overlay_wins_over_archetype_and_keeps_its_other_keys`, `::test_resolve_override_wins_over_band_overlay`, `::test_resolve_nested_rule_dictionary_is_replaced_whole_not_merged`, `::test_resolve_synergy_tags_are_replaced_not_concatenated`, `::test_resolve_archetype_key_without_override_is_default_archetype_band`, `::test_resolve_never_writes_to_the_config_it_reads`; A25 `::test_validate_ai_profile_unknown_key_reports_profile_unknown`, `::test_resolve_unknown_profile_key_falls_back_to_default_and_band`, `::test_resolve_missing_ai_profile_field_falls_back_to_default_and_band`, `::test_resolve_override_with_unknown_extends_falls_back_to_default_and_band`, `::test_validate_ai_profile_without_the_ai_profiles_body_reports_instead_of_passing`; A26 `::test_validate_weight_above_range_reports_weight_range`, `::test_resolve_weight_above_range_is_clamped_to_its_max_not_zeroed` (9 → 5), `::test_validate_non_finite_or_non_number_weight_reports_weight_range`, `::test_resolve_non_finite_or_non_number_value_keeps_the_earlier_layer`; AC-4 `::test_validate_unknown_field_at_every_level_reports_unknown_field`, `::test_op_coverage_reports_each_unvalued_op_once_including_nested_ops`, `::test_op_coverage_values_aura_and_modify_value_as_buff`, `::test_validate_profiles_config_reads_cards_through_the_stage7_lookup`, `::test_validate_runtime_accepts_each_planner_mode`, `::test_validate_runtime_rejects_anything_else`, `::test_ai_profiles_is_a_required_manifest_config_so_absence_is_e_missing_file`, `::test_resolve_with_an_empty_config_supplies_no_built_in_defaults`; plus `::test_boot_registers_the_validator_as_the_ai_profiles_config_validator`. Deferred to later stories by their own text: A25's "A6 still holds" (story 007 fixture) and A26's "visible in `ai_decision.features`" (story 004 scorer).
**Deviations** (all ADVISORY):
- Closed code set mapping (the story lists four codes and no others): every numeric fault — missing where required, not a number, non-finite, fractional integer knob, out of range — is `E_AI_WEIGHT_RANGE`, also for budgets, `op_values`, `keyword_values`, `choice_preference`, `presentation` and the `runtime` timings, which are not weights; every other schema fault (unknown or underscore key, missing section or enum/bool field, wrong container type, enum value outside its set, `hidden` outside `boss_overrides`, `extends` outside `boss_overrides`) is `E_AI_UNKNOWN_FIELD`; an override's missing/unknown `extends` is `E_AI_PROFILE_UNKNOWN`. All rows are severity `error`, `E_AI_OP_UNVALUED` included (C10: CI fails on every `E_AI_*`).
- Completeness checks added from A29 (no code defaults): `profiles.default` must set all 11 weights, all 12 rules and `intent_mode`; each band must set all three budgets; `presentation` and `runtime` must set every key. F9's Profile shows `extends?` on any profile — rejected outside `boss_overrides`, since the resolver formula never reads it there.
- `runtime.slice_ms` / `replay_budget_ms` have no sourced range (F9, ADR-0006, Tuning Knobs give none): checked as positive finite numbers.
- Resolver repair rule: only a finite out-of-range number is clamped (A26); a non-number, non-finite, fractional-integer, wrong-type or bad-enum value is skipped so the earlier layer (ultimately `default`) stands — C10's "falls back to `default`"; the GDD does not say what clamping NaN means.
- `E_AI_OP_UNVALUED`: `validate_op_coverage(op_values, cards)` is the pure check; `validate_profiles_config(body, db)` feeds it from `db.cards_by_type(minion|spell|weapon)` only when `db` has that method. `CardDatabase` gains it in card-database story 006 (stage-7 lookups, story 004), so in the live load today the check sees no cards — tested through a fake lookup db. The "valued 1.0" half is scoring (story 004); no fallback literal was added under `src/ai/`.
- Names: ADR-0002 calls the record validator `BossAI.validate_profile_key(key, profiles)`, the story `validate_ai_profile(host_kind, host_id, …)`; both exist — the 7b adapter over the pure key check, which takes the whole body (it needs `profiles` and `boss_overrides`). `validate_profiles_config(body, db = null)` is the 7a two-argument shape (the story wrote one argument).
- `Boot`: only `configs.ai_profiles` is registered (the lane's one line); `ai_profile` is not, as stage 7b does not run yet — its TODO line now names `BossAI.validate_ai_profile`.
- The unit suite reads its committed fixture with `JSON.parse_string` (precedent: `card_effects_dsl_spike_test.gd`); it is a test fixture, not `assets/data/`.
**Test Evidence**: `tests/unit/boss_ai/boss_ai_profile_resolver_test.gd` (46 tests); full suite `commands.test` exit 0, 383 test cases, 0 failures, 0 orphans; no new SCRIPT ERROR; smoke exit 0. Seen failing: the whole suite against the missing classes (exit 105, `BossAI` / `ProfileResolver` not declared), then one mutation per run, each exit 100, restored: clamp → skip; `hidden` from any layer; override applied before the band; map sections replaced whole; validator `hidden` check off; no recursion into structural ops; no `default` completeness check; integral check off.
**Run result**: N/A — two static `RefCounted` classes and one validator registration; nothing calls the resolver yet (MatchDriver is story 013) and the loader's stage 7 does not run, so nothing a player can see changes
**Reviewed by**: self, no independent review (QL-TEST-COVERAGE skipped — Lean mode; LP-CODE-REVIEW skipped — Lean mode; `/code-review` not run; engine-specialist check NOT ASSESSED — no agent spawned)
