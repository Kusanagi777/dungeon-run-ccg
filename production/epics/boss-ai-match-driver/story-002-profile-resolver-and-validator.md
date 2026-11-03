# Story 002: ProfileResolver and the ai_profiles validator

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

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

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `src/ai/profile_resolver.gd`
- `src/ai/boss_ai.gd` (static validators only)
- `tests/unit/boss_ai/boss_ai_profile_resolver_test.gd`
- `tests/fixtures/boss_ai/profiles_stub.json`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/boss_ai/boss_ai_profile_resolver_test.gd` — must exist and pass (`/story-done` checks that it EXISTS; pass/fail is established by `/gate-check` and `/smoke-check`, both later)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None inside this epic (`card-database` epic's `CardDatabase.config()` for the live path; tests use the stub)
- Unlocks: `production/epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md`, `production/epics/boss-ai-match-driver/story-004-scorer-features-and-board-value.md`, `production/epics/boss-ai-match-driver/story-013-match-driver-construction-and-command-gate.md`
