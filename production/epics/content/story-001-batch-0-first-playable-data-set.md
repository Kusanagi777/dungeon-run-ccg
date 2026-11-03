# Story 001: Batch 0 — first-playable data set (War starter, The Torchbearer, every DD-T01 file)

> **Epic**: Content (MVP batch)
> **Status**: Ready
> **Layer**: Feature (data)
> **Type**: Config/Data
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/content.md` (CN-1, CN-2, CN-3 B1/B2/B3, CN-4, CN-6 steps 1–3, AC-9/10/11/14/16/20) · `design/gdd/heroes.md` (H-1 `hero_war`, H-3 Whetstone, H-4 War starter list) · `design/gdd/card-database.md` (CR-1 envelope and file table, CR-3 record shapes, Formulas "Bundle pool size" / "Minimum treasure pool")
**Requirement**: `TR-content-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Data format, effect schema/DSL and `config()` loading; ADR-0007: Effect Resolver / Validator Boundary (every authored `effects[]` / `passive` passes `validate_effects`); ADR-0006: Boss AI Planner Threading (the boss's `ai_profile` key resolves in `ai_profiles.json`)
**ADR Decision Summary**: All data is UTF-8 JSON under `assets/data/`, snake_case keys, CR-1 envelopes (`{schema_version: 1, records: [...]}` for definition files, `{schema_version: 1, config: {...}}` for config files), loaded only by `CardDatabase` through `DataLoader`'s `FILE_MANIFEST`; a missing required file is `E_MISSING_FILE` and any error leaves the database `Failed` — there is no "load what passed" path. Effects are plain JSON validated by the static `EffectValidator.validate_effects` with the closed `E_FX_*` set.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (ADR-0002: GDScript/Core 4.5–4.7 post-cutoff in general) / LOW (the APIs used)
**Engine Notes**: Authoring JSON touches no engine API. ADR-0002 Verification items that bite this story: `JSON` numbers parse as `float` (author integers without a fractional part); `assets/data/*.json` must be in the exported PCK (`include_filter`, card-database story 010) — the first playable is a Windows export.

**Control Manifest Rules (Foundation, data)**:
- Required: all game data is JSON under `assets/data/`, loaded by one `CardDatabase` through `DataLoader` from `FILE_MANIFEST`; `effects[]`, `passive` and config bodies are plain JSON with no code references.
- Forbidden: never one bundled `game_data.json` (CN-6 batch ownership); never GDScript constants as game data; never author a content-version string (`data_version` is derived).
- Guardrail: data load (`Unloaded → Ready`) ≤ `data_load_budget_ms` 200, snapshot ≤ `data_memory_budget_mb` 4.

This is the sprint-1 item from gate `gate-pre-production-2026-11-03.md` (Next Steps 5, entry condition 5): the smallest data set with which the card-database load reaches `Ready` so the first playable (one War match vs one band-1 boss, Windows export) has data. It is CN-6's MVP-0 batch plus the band-1 boss, its deck cards and the three bundles the loader's bundle-pool floor requires, pulled forward from MVP-1. Pulled-forward ids are permanent (CN-6 step 9); the MVP-1 stories author only what is left.

---

## Acceptance Criteria

*From GDD `design/gdd/content.md` (CN-6 MVP-0 row and steps 2–3, AC-9/10/11/14/16/20), `card-database.md` CR-1/CR-3/CR-5, scoped to this story:*

- [ ] **AC-1 (Loads clean — CN-6.3, AC-20 first clause)** GIVEN `assets/data/` after this story, WHEN it is loaded headless through `DataLoader` + `CardDatabase` with the validator map `Boot` composes (an accepting stub only where an owner's validator has not landed yet, each such stub named in the smoke record), THEN every required `FILE_MANIFEST` row is present with a CR-1 envelope (`schema_version` 1; `records` an array or `config` an object), the state is `Ready` with zero `error` entries, the only warnings are `W_POOL_SIZE` (collectible, bundle and treasure pools — CN-6.3 allows it only at MVP-0), and `Unloaded → Ready` takes ≤ `data_load_budget_ms` (200 ms).
- [ ] **AC-2 (War — Heroes H-1/H-3/H-4, AC-20)** GIVEN the loaded data, THEN `heroes.json` holds `hero_war` only (set `war`, health 30, `hero_power` `power_whetstone`, `unlock` null, Heroes H-1 name and flavour), `hero_powers.json` holds `power_whetstone` only (cost 2, Heroes H-3 effects), `cards_war.json` holds the 7 War starters ★ and `war_iron_resolve` as CN-2 rows plus the token `war_whetstone_blade` (weapon, 1/2, `token: true`, referenced by Whetstone's `equip` op), `cards_neutral.json` holds the 14 neutrals listed in Implementation Notes as CN-2 rows, and `hero_war.starter_deck` is the Heroes H-4 War list — exactly 15 ids, each `war` or `neutral`, no token — whose curve passes Heroes F1 (`E_STARTER_CURVE` would not fire against `heroes_balance.json`).
- [ ] **AC-3 (Boss — CN-3, AC-10, AC-11)** GIVEN `bosses.json`, THEN it holds `boss_torchbearer` per CN-3 B1 (band 1, health 30, `hero_power` null, `passive` = `turn_end{side: owner}` → `enemy_hero` → `damage 1` with its `passive_text`, `tags` `["burn"]`, `ai_profile` `boss_torchbearer` resolving through the `ai_profiles.json` `boss_overrides` entry `{extends: aggro}` with zero `E_AI_*`, `intro_text` a placeholder line naming the passive — content OQ "Intro lines"), its `deck` is exactly 30 non-token ids per the CN-3 B2 recipe (2× `boss_ember_bolt`, 2× `boss_tinder_imp`, 2× each of the 13 named neutrals), and `cards_boss.json` holds those two boss cards per CN-3 B3 (set `boss`, rarity `common`).
- [ ] **AC-4 (Effects, text, lists — AC-9, AC-11, AC-14, AC-16)** GIVEN every record in this batch, THEN every `effects[]` and the boss `passive` pass `EffectValidator.validate_effects` with zero `E_FX_*`; every `text.en` is ≤ 90 characters and follows the CN-6 step 6 style guide (keywords first and capitalised, digits, `(N)` for mana); `bundles.json` holds `bundle_neutral_wall`, `bundle_neutral_tempo` and `bundle_war_armour_1` per CN-4 (three cards each, sharing the bundle's set and carrying its theme tag, `unlock` null); no token appears in a starter deck, boss deck or bundle; and the run is recorded as a smoke-check pass in `production/qa/smoke-[date].md` with the load report text.

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines and the GDD tables:*

**Files and what goes in them** (CR-1 envelope; 2-space indent; integers without fractions):

| File | Batch 0 contents | Source |
|---|---|---|
| `cards_war.json` | 7 War starters ★ (`war_shield_squire`, `war_sharpen`, `war_rusted_axe`, `war_warcry`, `war_iron_vanguard`, `war_quartermaster`, `war_pit_brawler`) + `war_iron_resolve` + token `war_whetstone_blade` | CN-2 War table, tokens line |
| `cards_neutral.json` | MVP-0: `neutral_torch_imp`, `neutral_tunnel_rat`, `neutral_cellar_guard`, `neutral_lantern_bearer`, `neutral_dungeon_delver`, `neutral_crypt_brute`, `neutral_ogre_porter`; pulled forward for the Torchbearer deck and the neutral bundles: `neutral_wolf_rider`, `neutral_banner_captain`, `neutral_spark_fiend`, `neutral_bulwark_smith`, `neutral_hush_owl`, `neutral_gravekeeper`, `neutral_shield_golem` (14 of the 15 MVP neutrals; `neutral_smite_or_mend` lands in story 003) | CN-2 neutral table |
| `cards_boss.json` | `boss_ember_bolt`, `boss_tinder_imp` | CN-3 B3 |
| `heroes.json` / `hero_powers.json` | `hero_war` / `power_whetstone` only — a Decay or Knowledge HeroDef here fails CR-5 step 6 (CN-6 MVP-0 row) | Heroes H-1, H-3, H-4 |
| `bosses.json` | `boss_torchbearer` | CN-3 B1/B2 |
| `bundles.json` | `bundle_neutral_wall` (lantern_bearer, bulwark_smith, shield_golem), `bundle_neutral_tempo` (tunnel_rat, wolf_rider, banner_captain), `bundle_war_armour_1` (shield_squire, iron_resolve, iron_vanguard) | CN-4 |
| `treasures.json` | `{"schema_version": 1, "records": []}` — `W_POOL_SIZE` (pool < `min_treasure_pool` 9), allowed at MVP-0; the 10 MVP treasures are story 006 | card-database Formulas |
| Config files seeded here | `run_structure`, `reward_draft`, `treasures_balance`, `heroes_balance`, `match_ui`, `run_ui`, `profile_defaults`, `card_database`, `content_budgets` | see below |

- **Why The Torchbearer is the batch-0 boss.** The gate asks for "one band-1 boss"; CN-6 names none for MVP-0. Of the three MVP band-1 bosses, only Torchbearer's B2 recipe names all 13 neutrals and uses no token: its passive and boss cards are `damage`, `draw` and a `turn_end` trigger (card-effects rows 7, 22). Rat King's recipe says "13 MVP neutrals ≤ 5 cost" without naming them and needs the `boss_rat` token and a `tag`-filtered aura. Gatekeeper's needs `neutral_smite_or_mend` (Choose One). The owner may swap in Rat King, the floor-1 teaching boss, by editing this story before `/dev-story`. Rat King and Gatekeeper ship in story 003 either way.
- **Why three bundles at batch 0.** Card-database stage 8 makes a bundle pool below the DD-R04 hard floor of 3 per hero set an **error** (`E_COUNT`, card-database story 005), so an empty `bundles.json` leaves the load `Failed`. These three are the only CN-4 MVP bundles whose cards are all in batch 0, and getting there pulls forward just one card (`war_iron_resolve`).
- **Config files.** CR-1 requires every config row. Four are written by their owners' stories, which this story depends on: `match_rules.json` (match-rules story 001), `card_effects.json` (card-effects story 002), `ai_profiles.json` (boss-ai-match-driver story 003, which also carries the `boss_torchbearer` override) and `rng_event_log.json` (rng-event-log story 007). No story writes the other nine yet. Card-database Interactions says "Content authors every file in CR-1", so this story seeds them, each body being the owning GDD's Tuning Knobs defaults: `run-structure.md`, `reward-draft.md`, `treasures.md`, `heroes.md` F1–F5, `match-ui.md`, `run-ui.md`, `meta-progression.md` M9, card-database Formulas (`min_bundle_pool` 10, `max_records` 5000, `data_load_budget_ms` 200, `data_memory_budget_mb` 4, `min_collectible_pool` at its Formulas default), and content's own `content_budgets.json` with the CN-6 step 2 key list from content Tuning Knobs. When an owning epic's validator story lands it takes over its file, and the owner GDD's values win over a seed.
- Card rows copy the CN-2 / B3 columns exactly: `id`, `name`, `set`, `type`, `cost`, `attack`/`health`/`durability` per type, `rarity`, `keywords`, `tags`, `text {key: "card.<id>.text", en}`, `effects` (from the card's C11 row; `[]` for `van` and keyword-only cards). Each field is present only for the types CR-3 lists (`E_UNKNOWN_FIELD`), and `art` is left at its default.
- Runtime behaviour of the pulled-forward effects (`neutral_gravekeeper`'s counter Deathrattle, `neutral_spark_fiend`'s twice-random ping, `neutral_banner_captain`'s aura, `neutral_hush_owl`'s Silence) is Card Effects work (stories 008, 009, 012). This story only needs them to **validate**. Say in the PR which of them the first playable exercises.
- Effects are never expressed in GDScript. A text the DSL cannot express is a card-effects GDD change, never a workaround here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the other 17 War cards.
- Stories 003 / 004: the other four MVP bosses, their boss cards, the `boss_rat` / `decay_husk` tokens and `neutral_smite_or_mend`.
- Story 005: the other 7 MVP bundles. Story 006: the 10 MVP treasures.
- Story 007 / 008: `tools/content/validate.gd` and the F1–F5 checks; until they land, AC-1's load runs through the card-database composition (card-database story 010's test path or `tools/print_data_version.gd`).
- Owning epics: the config validators, and `ai_profiles.json` / `match_rules.json` / `card_effects.json` / `rng_event_log.json` themselves.

---

## Files

- `assets/data/cards_war.json`, `assets/data/cards_neutral.json`, `assets/data/cards_boss.json`
- `assets/data/heroes.json`, `assets/data/hero_powers.json`, `assets/data/bosses.json`, `assets/data/bundles.json`, `assets/data/treasures.json`
- `assets/data/run_structure.json`, `assets/data/reward_draft.json`, `assets/data/treasures_balance.json`, `assets/data/heroes_balance.json`, `assets/data/match_ui.json`, `assets/data/run_ui.json`, `assets/data/profile_defaults.json`, `assets/data/card_database.json`, `assets/data/content_budgets.json`
- `production/qa/smoke-[date].md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

*Governed by `qa.level`: `standard` — Config/Data evidence is ADVISORY (testing standards default).*

**Story Type**: Config/Data
**Required evidence**:
- Config/Data: smoke check pass (`production/qa/smoke-[date].md`) holding the headless load report (state, error count, warnings, load ms) and the list of stub validators used.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/card-database/story-001-manifest-parse-envelope.md` … `production/epics/card-database/story-006-freeze-and-queries.md` (the loader that reaches `Ready`); `production/epics/match-rules/story-001-data-model-and-rules-config.md` (`match_rules.json`); `production/epics/card-effects/story-002-runtime-binding-config.md` (`card_effects.json`); `production/epics/card-effects/story-003-validator-schema-codes.md` (`E_FX_*` validation); `production/epics/boss-ai-match-driver/story-003-ai-profiles-mvp-data.md` (`ai_profiles.json`); `production/epics/rng-event-log/story-007-overflow-fault-and-config-knobs.md` (`rng_event_log.json`)
- Unlocks: `production/epics/content/story-002-mvp-1-war-set.md`, `production/epics/content/story-003-mvp-1-band-1-bosses-rat-king-gatekeeper.md`, `production/epics/content/story-006-mvp-1-treasures.md`, `production/epics/card-database/story-010-shipped-data-and-export-inclusion.md` (batch-0 counts); gate entry condition 5 (first playable)
