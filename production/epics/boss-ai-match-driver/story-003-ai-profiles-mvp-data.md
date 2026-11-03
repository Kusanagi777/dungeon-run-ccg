# Story 003: ai_profiles.json — archetypes, bands, runtime block and the five MVP overrides

> **Epic**: Boss AI + Match Driver
> **Status**: Ready
> **Layer**: Core
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/boss-ai.md` (F1 default weights, F7 budgets, F9 schema, C10) · `design/gdd/content.md` MVP boss table (`ai_profile` column)
**Requirement**: `TR-boss-ai-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format and `config()` loading (UTF-8 JSON under `assets/data/`, one loader, validators at composition); ADR-0006 (the `runtime` block and its defaults)
**ADR Decision Summary**: Every tuning knob is JSON under `assets/data/`, parsed only by `CardDatabase` and frozen into the snapshot; `ai_profiles.json` carries F9's `op_values`, `keyword_values`, `profiles`, `bands`, `boss_overrides`, `presentation` and ADR-0006's `runtime {planner_mode worker, slice_ms 2, replay_budget_ms 2}`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (version) / LOW (APIs)
**Engine Notes**: ADR-0002 — `assets/data/*.json` must be present in the exported PCK (NOT SOURCEABLE; verified by the Windows export in Story 018). All numbers parse as `float`.

**Control Manifest Rules (this layer)**:
- Required: `slice_ms`, `replay_budget_ms`, `planner_mode` come from the `ai_profiles.json` `runtime` block (ADR-0006 default `replay_budget_ms` **2**; ADR-0008's Performance section says 4 — the data value governs).
- Forbidden: No hardcoded weights, budgets or delays in `src/ai/**` (A29) — every F1–F9 value lives in this file.
- Guardrail: Boss AI worker 50 ms p95 per turn (A22) — `lethal_max_nodes` at band 3 is the first knob to lower if A22 fails (F7).

---

## Acceptance Criteria

*From GDD `design/gdd/boss-ai.md` F1, F7, F9, C8.4 and `content.md` MVP boss rows, scoped to this story:*

- [ ] `assets/data/ai_profiles.json` has `schema_version: 1`, the F9 `op_values` table (19 Card Effects C5 op names with the listed values), `keyword_values` (F2 multipliers), `profiles.default` with F1's default weights and default `rules` (`hero_power spare_mana`, `lethal_search full`, `defensive false`, `assume_aoe false`, `trade_ratio 1.0`, `tie_epsilon 0.05`, `overextend_cap_aoe 4`, `burn_per_mana 1.0`, `defensive_margin 3`, `BV_NORM 10`, `THREAT_NORM 12`, `defensive_multipliers {w_face 0.25, w_self 2, w_heal 2, w_threat 1.5}`), and `aggro`, `control`, `tempo`, `passive_driven` carrying exactly F9's archetype deltas.
- [ ] `bands."1"/"2"/"3"` overlays carry F9's rules (band 1 `w_trade 0.2, w_over 0, lethal_search shallow, defensive false, hero_power always, intent_mode full`; band 2 `defensive false`; band 3 `defensive true`) and F7's budgets (`lethal_max_nodes` 50/500/4000, `max_evals_per_action` 40/120/250, `max_actions_per_turn` 30); `presentation {action_delay_s 0.6, max_turn_playback_s 10, intent_banner_s 0.3, plan_changed_s 1.2}`; `runtime {planner_mode: "worker", slice_ms: 2, replay_budget_ms: 2}`.
- [ ] `boss_overrides` holds the five MVP bosses per `content.md`: `boss_rat_king {extends: aggro}`, `boss_gatekeeper {extends: control}`, `boss_torchbearer {extends: aggro}`, `boss_rot_warden {extends: passive_driven, synergy_tags: [deathrattle], weights: {w_self: 1.5}}`, `boss_hollow_king {extends: control, weights: {w_board: 3.0}}`; no override sets `intent_mode: hidden` and no band overlay resolves to `hidden` (A19 last clause, C8.4); the 11 non-MVP bosses are on the deferred list and absent.
- [ ] `BossAI.validate_profiles_config` (Story 002) reports zero `E_AI_*` rows for the file, and `/smoke-check` passes with it present.

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines:*

- Path `assets/data/ai_profiles.json`, UTF-8, 2-space indent, keys in F9 order; DD-T01 lists it as a `config()` file so `CardDatabase` loads it under the name `ai_profiles` (the `card-database` epic adds the CR-1 entry if it is not there yet — check before adding a second loader; never add one).
- Numbers are written as JSON numbers; int-valued knobs without a fractional part.
- The per-boss `ai_profile` field in `bosses.json` is Content's (`content` epic, batch MVP-1); this story writes only the override entries this GDD owns. Keep each override's reason beside it as a sibling `"_note"` key only if the validator's unknown-field rule allows underscore-prefixed keys — otherwise record reasons in `content.md` B2, not in the file.
- Do not add a `hidden` override at MVP: `boss_shadow_of_the_delve` is Alpha and set to `class_only` by Content anyway.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the validator and resolver code.
- `content` epic: `bosses.json` `ai_profile` fields and boss decks.
- Deferred list: overrides for bosses 6–16.

---

## Files

*The code and test files this story creates or changes. `/create-stories` lists the
planned ones; `/dev-story` replaces the list with the files it changed; `/story-done`
checks scope against it.*

- `assets/data/ai_profiles.json`
- `tests/unit/boss_ai/boss_ai_profiles_data_test.gd` (loads the real file through the Story 002 validator and asserts zero `E_AI_*`)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-*.md`); the data test above is additional, not the gate.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-002-profile-resolver-and-validator.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-016-sim-harness.md`, `production/epics/boss-ai-match-driver/story-018-windows-planner-a30-and-determinism.md`
