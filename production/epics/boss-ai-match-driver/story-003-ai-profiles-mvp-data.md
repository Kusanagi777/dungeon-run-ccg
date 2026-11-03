# Story 003: ai_profiles.json — archetypes, bands, runtime block and the five MVP overrides

> **Epic**: Boss AI + Match Driver
> **Status**: Complete
> **Layer**: Core
> **Type**: Config/Data
> **Estimate**: S
> **Manifest Version**: 2026-11-03
> **Last Updated**: 2026-11-03

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

- `assets/data/ai_profiles.json` (new)
- `tests/integration/boss_ai/boss_ai_profiles_data_test.gd` (new, 16 tests — integration, not `tests/unit/`: it reads versioned repository files through `DataLoader` over a staged `user://` root)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: at `qa.level: minimal` tests are **waived** (advisory, never "must exist and pass"), but a Visual/Feel or UI story's retained screenshot is not.*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-*.md`); the data test above is additional, not the gate.

**Status**: [x] Data test created (16 tests, passing); no `production/qa/smoke-*.md` for sprint 2 yet — `commands.test` and `commands.smoke` were run by hand (Completion Notes)

---

## Dependencies

- Depends on: `production/epics/boss-ai-match-driver/story-002-profile-resolver-and-validator.md`
- Unlocks: `production/epics/boss-ai-match-driver/story-016-sim-harness.md`, `production/epics/boss-ai-match-driver/story-018-windows-planner-a30-and-determinism.md`

---

## Completion Notes
**Completed**: 2026-11-03 (started 21:16:30 UTC, finished 21:20:45 UTC)
**Criteria**: 4/4 passing (`tests/integration/boss_ai/boss_ai_profiles_data_test.gd`, each value pinned to the GDD/registry text it comes from, not to literals) — AC-1 `::test_shipped_file_loads_through_data_loader_with_no_entry_naming_it` (schema_version 1, strict JSON), `::test_op_values_are_f9s_nineteen_card_effects_ops_with_its_values`, `::test_keyword_values_are_the_f2_multipliers`, `::test_default_weights_and_ranges_are_the_f1_table` (also pins `BossAI.RANGES` weight rows to F1), `::test_default_rules_and_intent_are_the_story_list`, `::test_archetypes_carry_exactly_f9s_deltas`; AC-2 `::test_band_overlays_carry_f9s_rules_and_f7s_budgets`, `::test_presentation_and_runtime_are_f9s_lines`; AC-3 `::test_boss_overrides_are_the_five_mvp_bosses_of_content_b1` (the 11 non-MVP B1 bosses absent), `::test_override_ids_are_registry_bosses_split_three_one_one_by_band` (DD-H06), `::test_torchbearer_override_resolves_as_aggro_with_its_band_overlay`, `::test_rot_warden_and_hollow_king_resolve_their_extra_values`, `::test_no_mvp_boss_or_band_overlay_resolves_to_hidden`; AC-4 `::test_shipped_file_reports_zero_e_ai_rows`, plus `commands.smoke` exit 0 with the file present. Format: `::test_sections_are_in_f9_order`, `::test_integer_knobs_are_written_without_a_fractional_part_and_indent_is_two_spaces`.
**Deviations** (all ADVISORY):
- The data test is at `tests/integration/boss_ai/boss_ai_profiles_data_test.gd`, not the story's `tests/unit/boss_ai/` path: it loads the shipped file through `DataLoader`, which needs a complete CR-1 root, so it stages one under `user://` (file writes) — the precedent set by commit `ce5cd52` (match-rules AC-41 checks moved to integration for the same reason). The QA plan's spot checks are all covered.
- `profiles.default` also sets `intent_mode: "full"`, `choice_preference: {}` and `synergy_tags: []`. AC-1 lists only weights and rules, but C8.4 makes `full` the default and no band 2/3 overlay sets an intent, so without it bands 2 and 3 resolve no `intent_mode`; story 002's validator requires it.
- `rules.BV_NORM` / `THREAT_NORM` keep F9's upper-case names, against `.claude/rules/data-files.md` snake_case keys — the GDD schema names them so.
- No `_note` keys: story 002's validator rejects underscore keys (closed sets), so each override's reason stays in content.md CN-3 B1/B2, as the story allows.
- F2's `flat_bonus` (spell_damage, deathrattle, aura) and `taunt_bonus` are "data file" values with no home in F9's schema, so they are not in the file; A29 will need them when the story 004 scorer lands (open item).
- The 7 non-structural Card Effects C5 ops beyond F9's 19 (`remove_keyword`, `shuffle_into_deck`, `discard`, `weapon_durability`, `hero_power_refresh`, `add_counter`, `set_counter`; `conditional`/`repeat`/`choose_one`/`aura`/`modify_value` are valued by rule) have no row: any loaded card using one will report `E_AI_OP_UNVALUED` once card-database exposes `cards_by_type` (story 002 notes). That is the GDD's own design, flagged for the content batches.
- Test evidence gap (ADVISORY at `qa.level: standard`): no sprint-2 `production/qa/smoke-*.md` exists; `/smoke-check` is a sprint-level run and was not run by this lane. `commands.test` (399 test cases, exit 0) and `commands.smoke` (exit 0, no SCRIPT ERROR) were run by hand.
**Test Evidence**: `tests/integration/boss_ai/boss_ai_profiles_data_test.gd` (16 tests); full suite exit 0, 399 test cases, 0 failures, 0 orphans; no new SCRIPT ERROR. Seen failing, one data mutation per run (exit 100, file restored): `boss_torchbearer` extends `control`; band 3 `lethal_max_nodes` 400; band 3 `intent_mode: hidden` (validator rows; the resolver still refuses it); `overextend_cap_aoe: 4.0`; aggro `w_face` 3.5. First run also failed on the test's own F9 parser (a bold label followed by a line break) and was fixed in the test.
**Run result**: N/A — a data file nothing reads at runtime yet (the loader's stage 7 and `config()` are card-database stories 004/006; the match driver is story 013), so nothing a player can see changes
**Reviewed by**: self, no independent review (QL-TEST-COVERAGE skipped — Lean mode; LP-CODE-REVIEW skipped — Lean mode; `/code-review` not run)
