# Card Database

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
> **Author**: owner + systems-designer (via /design-system, guided mode)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 4 (Readable, deterministic rules) — indirectly Pillar 1 (every run builds a deck you couldn't have planned) by owning the draft pools
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` Specialists (`systems-designer`, `gameplay-programmer`, `engine-programmer`) not spawned — Lean mode; the author performed the specialist pass inline. Review manually before production.

## Summary

The Card Database loads every card, hero, hero power, boss, treasure and bundle definition from
JSON once at startup, validates the whole set as one unit, and serves typed read-only records and
draft pools to every other system. The player never sees it except as "cards do what they say and
the same seed gives the same offers"; it exists so that one loud validation report at boot replaces
thirteen systems each guessing at bad data mid-run.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None upstream; depended on by Match Rules, Card Effects, Boss AI, Heroes, Run Structure, Reward Draft, Treasures, Meta Progression, Content, Match UI, Run UI`

## Overview

The Card Database is the game's single reader of content data. At startup it loads every JSON
definition file under `assets/data/` (DD-T01) — card sets, heroes, hero powers, bosses, treasures
and bundles — validates the whole set as one unit, and freezes it into typed, read-only records
that every other system queries by id, set, type, tag, cost or rarity. It also computes the draft
pools (the collectible cards and bundles for a hero, the treasure pool) that Reward Draft draws
from. The player never touches it directly; they feel it as "every card does exactly what its text
says and the same seed produces the same offers" (Pillar 4). It exists because thirteen systems
read the same ~200 records: one loader with one loud validation report means a typo in a boss deck
is caught at boot with a file name and a line, not mid-run as a crash. Load failure is total — the
game never starts on partial data.

## Detailed Design

### Core Rules

Specialist note: `systems-designer` / `gameplay-programmer` / `engine-programmer` not spawned —
Lean mode. Design-level only; file I/O and class layout belong to an ADR.

**CR-1 — Files and envelope.** Every file under `assets/data/` is UTF-8 JSON with snake_case keys
(DD-T01) and the envelope `{ "schema_version": <int>, "records": [ ... ] }`. The loader discovers
files by name; an unknown file in the folder is a warning, a missing required file is an error.

| File | Record type | Required at v1 | Notes |
|------|-------------|----------------|-------|
| `cards_<set>.json` | CardDef | `war`, `neutral`, `boss` (MVP); `decay`, `knowledge` (Alpha) | `<set>` is the set id; `fortune`, `order`, `shadow` load when present (DD-H02) |
| `heroes.json` | HeroDef | yes | locked heroes are still loaded; Meta Progression decides availability |
| `hero_powers.json` | HeroPowerDef | yes | shared by heroes and bosses so power ids can be validated (DD-M13) |
| `bosses.json` | BossDef | yes | |
| `treasures.json` | TreasureDef | yes | |
| `bundles.json` | BundleDef | yes | |

Rationale: `hero_powers.json` and set `boss` are additions to the DD-T01 list. Powers need their
own records because bosses and heroes reference them by id (the brief requires those ids to be
validated); boss-only cards need a set that is never collectible (Pillar 2: boss decks are puzzles,
not the player's pool). Both are flagged for DD-T01 in Open Questions.

**CR-2 — Identifiers.** One global id namespace across all record types. Pattern
`^[a-z][a-z0-9_]{2,47}$`. The prefix encodes the type and, for cards, the set; a prefix/field
mismatch is an error (`E_SET_MISMATCH`).

| Record | Pattern | Example |
|--------|---------|---------|
| CardDef | `<set>_<name_snake>` | `war_iron_vanguard`, `neutral_torch_imp`, `boss_bone_shard` |
| HeroDef | `hero_<name>` | `hero_war` |
| HeroPowerDef | `power_<name>` | `power_sharpen` |
| BossDef | `boss_<name>` (a `boss`-set card is also `boss_<name>`; CR-5 step 5 rejects any collision) | `boss_rot_warden` |
| TreasureDef | `treasure_<name>` | `treasure_second_wind` |
| BundleDef | `bundle_<set>_<theme>` | `bundle_war_weapons` |

**CR-3 — Record schemas.** "Req" = required. Fields not listed for a type must be absent
(`E_UNKNOWN_FIELD`) so typos are caught rather than ignored.

*CardDef*

| Field | Type | Req | Rule |
|-------|------|-----|------|
| `id` | string | yes | CR-2 |
| `name` | string | yes | 1–32 chars, English; the string table key `card.<id>.name` is derived, not stored |
| `set` | enum | yes | `war \| decay \| knowledge \| neutral \| boss \| fortune \| order \| shadow`; must equal the file's set |
| `type` | enum | yes | `minion \| spell \| weapon` (DD-M08) |
| `cost` | int | yes | 0–10 (DD-M04: 10 crystals max) |
| `attack` | int | minion, weapon | 0–99; absent for spells |
| `health` | int | minion | 1–99; absent otherwise |
| `durability` | int | weapon | 1–9; absent otherwise |
| `rarity` | enum | yes | `common \| rare \| legendary` — see CR-4 |
| `keywords` | string[] | yes (may be `[]`) | each in the DD-M09 keyword id list; no duplicates |
| `spell_damage` | int | no | 0–5, default 0; the magnitude for the `spell_damage` keyword (the one parametrised keyword in v1) |
| `effects` | object[] | yes (may be `[]`) | opaque here; validated by the Card Effects schema validator (CR-5 stage 7) |
| `tags` | string[] | yes (may be `[]`) | theme tags, `^[a-z_]+$`; bundles reference them (DD-H05) |
| `text` | object | yes | `{ "key": "card.<id>.text", "en": "<rules text>" }`; `en` may be empty for vanilla minions |
| `token` | bool | no | default `false`; a token is never in any pool (CR-6) and never in a starter deck, bundle or boss deck |
| `art` | string | no | asset key, default `cards/<id>`; existence is not checked here (`/asset-audit` does) |

*HeroDef* — `id`, `name`, `set` (the hero's card set: one of the non-neutral, non-boss sets),
`health` int (30, DD-M02; data-driven so a hero could differ later), `hero_power` string (a
HeroPowerDef id), `starter_deck` string[] (exactly 15 card ids, DD-R03; duplicates allowed;
no tokens; cards must be from the hero's set or `neutral`), `text` object (flavour line), `art`.

*HeroPowerDef* — `id`, `name`, `cost` int (default 2, DD-M13, range 0–10), `effects` object[]
(opaque, Card Effects), `text` object, `art`.

*BossDef* — `id`, `name`, `band` int 1–3 (DD-R01), `health` int (default per band from DD-M02:
30/40/50; stored explicitly so a boss may deviate, warned when it does), `hero_power` string
(HeroPowerDef id, or `null` for a boss with a passive only), `passive` object or `null` (opaque,
Card Effects), `deck` string[] (≥ 1 card id, no tokens, any set including hero sets — Edge Cases),
`ai_profile` string (opaque key, validated by the Boss AI validator), `intro_text` object
(localizable), `art`.

*TreasureDef* — `id`, `name`, `rarity` enum (`common \| rare` only in v1, DD-H04), `effects`
object[] (opaque, Treasures/Card Effects hook definitions), `unlock` string or `null` (an unlock
condition key validated by the Meta Progression validator; `null` = available from the start),
`text` object, `art`.

*BundleDef* — `id`, `name`, `set` enum (a hero set or `neutral`; never `boss`), `theme` string
(one tag; every card in the bundle must carry it), `cards` string[] (exactly 3 card ids, DD-R04;
no tokens; each card's set must equal the bundle's set), `text` object (one-line pitch shown in
the draft picker).

**CR-4 — Enumerations.** Sets, types and keywords are as above; the keyword id list is the
DD-M09 set in snake_case (`taunt, charge, rush, divine_shield, windfury, stealth, lifesteal,
poisonous, freeze, silence, battlecry, deathrattle, spell_damage, discover, aura`) and is owned by
Match Rules; this GDD only enforces membership. **Rarity is three tiers, not four**: there is no
pack economy (anti-pillar), so rarity is a readability signal on the card frame and a Content
authoring budget; `epic` would add a tier with no rule attached. Reward Draft does not weight by
rarity; it weights by theme tag (DD-H05).

**CR-5 — Load pipeline.** Runs once at startup before the main menu. Each stage collects every
problem it finds and continues; a record that fails a stage is excluded from later stages but the
later stages still run on the rest, so one report lists everything.

1. **Discover** files per CR-1 (missing required file → `E_MISSING_FILE`).
2. **Parse** each file (`E_PARSE` with file and, where the parser gives it, line/column).
3. **Envelope**: `schema_version` must equal `schema_version_current` = 1 (`E_SCHEMA_VERSION`
   naming file, found and expected; both older and newer fail — Edge Cases).
4. **Schema** per record: required fields, types, ranges, enums, unknown fields, id pattern.
5. **Uniqueness**: ids across all files (`E_DUP_ID` names the id and every file that defines it).
6. **Cross-references**: hero `starter_deck`, `hero_power`; boss `deck`, `hero_power`; bundle
   `cards` and `theme`; counts (15, 3) and the no-token rule (`E_UNKNOWN_REF`, `E_COUNT`,
   `E_TOKEN_IN_LIST`, `E_TAG_MISMATCH`).
7. **Delegated validators**, injected at composition time: Card Effects (`effects[]`, `passive`),
   Boss AI (`ai_profile`), Meta Progression (`unlock`). Each returns its own errors, which are
   merged with severity `E_DELEGATED` plus the owner's code. A validator that is not registered
   is itself an error in release builds; unit tests inject stubs.
8. **Budget warnings** (never block): pool sizes under the thresholds in Formulas (`W_POOL_SIZE`),
   a boss `health` differing from its band default (`W_BAND_HEALTH`), unknown file (`W_UNKNOWN_FILE`).
9. **Freeze**: with zero errors the records become immutable and the state is `Ready`; otherwise
   `Failed` with the report. There is no "load what passed" path.

Report entry shape: `{ severity: error|warning, code, file, record_id|null, field|null, message }`,
sorted by file then record id. Rationale for loudness: a silent partial load would make a
missing card look like a rules bug three systems downstream (Pillar 4).

**CR-6 — Queries.** All queries are pure reads on the frozen snapshot and return results ordered
by id ascending, regardless of file order — Reward Draft and Run Structure draw from these lists
with the seeded RNG (DD-T03), so order must not depend on authoring order (DD-R09).

| Query | Returns | Notes |
|-------|---------|-------|
| `card(id)`, `hero(id)`, `hero_power(id)`, `boss(id)`, `treasure(id)`, `bundle(id)` | the record | unknown id → `null` and a logged error; callers that must have a record assert in debug |
| `has(id)` | bool | used by the Card Effects validator for summon/token references |
| `cards_by_set(set)`, `cards_by_type(type)`, `cards_by_tag(tag)`, `cards_by_cost(cost)`, `cards_by_rarity(rarity)` | CardDef[] | include tokens; filters compose on the caller's side |
| `collectible_pool(hero_set)` | CardDef[] | `set ∈ {hero_set, neutral}` and `token == false`; `boss` is never included |
| `bundle_pool(hero_set)` | BundleDef[] | `set ∈ {hero_set, neutral}` |
| `treasure_pool()` | TreasureDef[] | all treasures; Reward Draft filters by Meta Progression's unlocked keys and the run's already-offered list |
| `bosses_in_band(band)` | BossDef[] | DD-R02 pool per band |
| `heroes()` | HeroDef[] | all, locked included |
| `report()` | ValidationReport | the last load's report (empty on a clean load) |

**CR-7 — Immutability and instances.** Records are definitions, never game state. Match Rules
copies `attack`/`health`/`durability` into its own card instances; Treasures and Card Effects read
`effects[]` and never write to it. No system other than the Card Database parses JSON (systems
index, Card Database paragraph).

**CR-8 — Failure is visible.** In a desktop build a `Failed` load shows a data-error screen (Run
UI) listing the report and offers only Quit; in headless/CI the process prints the report and exits
non-zero. There is no main menu over bad data.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|-----------------|----------------|----------|
| `Unloaded` | process start | `load()` called by the boot sequence | queries are illegal (debug assert; release returns `null`/empty and logs `E_NOT_LOADED`) |
| `Loading` | `load()` | pipeline CR-5 finishes | synchronous; nothing else runs; must finish within `data_load_budget_ms` (Formulas) |
| `Ready` | zero errors | `reload()` in a debug build, or process exit | snapshot frozen; all queries valid; `report()` holds warnings only |
| `Failed` | one or more errors | process exit (release) or `reload()` (debug) | queries illegal as in `Unloaded`; `report()` holds the full report; CR-8 applies |
| `Reloading` (debug only) | `reload()` from `Ready` or `Failed` | pipeline finishes | builds a **new** snapshot; on success it replaces the old one atomically, on failure the previous `Ready` snapshot stays active and the new report is shown; a match in progress keeps the snapshot handle it started with |

`Ready → Loading` never happens: a release build loads exactly once per process, and `reload()`
there is a no-op returning `E_NOT_SUPPORTED`.

### Interactions with Other Systems

Nothing flows *into* the Card Database at runtime except the three injected validators and the
`load()`/`reload()` calls. Every other arrow points out. All downstream GDDs are undesigned, so
each row is a **provisional contract** this GDD proposes and the dependent GDD confirms.

| System | Data out (what they read) | Data in (what they give us) | Interface owner |
|--------|---------------------------|-----------------------------|-----------------|
| Match Rules | `card()` for every card instance; `type`, `cost`, stats, `keywords`, `spell_damage`; `hero()` health; `hero_power()` cost | keyword id list (DD-M09) used by CR-4 | Match Rules owns keyword semantics; this GDD owns the record shape |
| Card Effects | `effects[]` and boss `passive` as opaque arrays; `has(id)` for summon targets | the effects schema validator (CR-5 stage 7) | Card Effects owns the effect schema and its error codes |
| Boss AI | `boss().ai_profile`, `boss().deck` | the `ai_profile` key validator | Boss AI owns profile keys |
| Heroes | `heroes()`, `hero()` with `starter_deck`, `hero_power`, `set` | starter-deck composition rules beyond CR-3 (e.g. curve) if any | Heroes owns which 15 cards; this GDD owns "exactly 15, no tokens, own set or neutral" |
| Run Structure | `bosses_in_band(band)` for sequence generation; `hero()` at hero select | — | Run Structure owns draw-without-replacement (DD-R02) |
| Reward Draft | `collectible_pool(hero_set)`, `bundle_pool(hero_set)`, `treasure_pool()`, `cards_by_tag()` | — | Reward Draft owns weighting and pity rules; this GDD owns pool membership and ordering (CR-6) |
| Treasures | `treasure()` records and their `effects[]`; `unlock` key | treasure hook schema (via the Card Effects validator or its own) | Treasures owns hook semantics |
| Meta Progression | `treasure().unlock`, `heroes()` for unlock state display | the unlock-key validator | Meta Progression owns unlock keys and which ids are locked |
| Match UI / Run UI | `name`, `text.key` / `text.en`, `art`, `rarity`, `intro_text`, bundle `text`; the `report()` on `Failed` (data-error screen) | — | UI renders; it never reads JSON |
| Content | authors every file in CR-1 against CR-3; reads `report()` from the headless validate command | the data itself | Content owns values; this GDD owns the schema and the checks |
| RNG & Event Log | nothing — the database is deterministic data; it emits no events and uses no RNG | — | — |

## Formulas

Specialist note: `systems-designer` not spawned — Lean mode (Section D is HIGH-risk per the skill,
but the owner pre-approved a lean run); values below are derived from DD rows, not invented.
Review manually before production.

### Lookup

The `lookup` formula is defined as:

`record = records[index_of[id]]` — `null` when `id ∉ index_of`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| id | string | CR-2 pattern | calculated | the id requested by a caller |
| index_of | map string→int | one entry per record | calculated | built once at freeze (CR-5 step 9) from the sorted record list |
| records | array | 0–`max_records` | data file | the frozen, id-sorted record list |

**Output Range:** exactly one record or `null`; cost O(1), no allocation. Determinism: the same
data files produce the same `index_of` on every machine, because `records` is sorted by id, not by
file order.
**Example:** `index_of["war_iron_vanguard"] = 112` → `records[112]` is that CardDef.

### Collectible pool size

The `collectible_pool_size` formula is defined as:

`collectible_pool_size(hero_set) = n_nontoken(hero_set) + n_nontoken(neutral)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| n_nontoken(hero_set) | int | 0–200 | data file | cards in the hero's set with `token == false`; ~25 at v1 (DD-H03) |
| n_nontoken(neutral) | int | 0–200 | data file | neutral non-token cards; ~45 at v1 (DD-H03) |
| min_collectible_pool | int | 10–100 | data file (tuning knob, default 30) | below this a `W_POOL_SIZE` warning is raised |

**Output Range:** 0 to 400; ~70 at v1 per hero, ~40 at MVP (DD-H06: War + neutral subset). The
pool is the universe for Discover-style effects and `/balance-check`; bundles are authored, not
sampled from it, so a small pool degrades variety rather than breaking a draft.
**Example:** War at v1: 25 + 45 = 70 ≥ 30, no warning. MVP: 18 + 22 = 40, no warning.

### Bundle pool size

The `bundle_pool_size` formula is defined as:

`bundle_pool_size(hero_set) = n_bundles(hero_set) + n_bundles(neutral)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| n_bundles(hero_set) | int | 0–50 | data file | ~8 per hero at v1 (DD-H05) |
| n_bundles(neutral) | int | 0–50 | data file | ~6 at v1 (DD-H05) |
| min_bundle_pool | int | 3–30 | data file (tuning knob, default 10) | warning threshold; 3 is the hard floor for one draft (DD-R04) and is an error below it |

**Output Range:** 0 to 100; 14 at v1, 10 at MVP (DD-H06). Below 3, Reward Draft cannot fill one
offer, so that case is `E_COUNT`, not a warning.
**Example:** War v1: 8 + 6 = 14 ≥ 10, clean.

### Minimum treasure pool

The `min_treasure_pool` formula is defined as:

`min_treasure_pool = treasure_drafts_per_run × treasure_offers_per_draft`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| treasure_drafts_per_run | int | 0–7 | constant (DD-R05: floors 1, 3, 5 → 3) | treasure drafts in one run |
| treasure_offers_per_draft | int | 1–5 | constant (DD-R05 → 3) | offers per treasure draft |
| n_unlocked_default | int | 0–100 | data file | treasures with `unlock == null` |

**Output Range:** 9 under DD-R05, because offers never repeat within a run, so a fresh profile
needs 9 distinct unlocked treasures to fill every draft. `n_unlocked_default < min_treasure_pool`
raises `W_POOL_SIZE`. **At MVP (8 treasures, DD-H06) this warning fires** — see Open Questions.
**Example:** 3 × 3 = 9; v1 with 20 treasures and ≥ 9 unlocked by default is clean.

### Validation cost and load budget

The `validation_checks` formula is defined as:

`validation_checks = n_records + n_refs`, where
`n_refs = n_heroes × 15 + n_bundles × 3 + Σ boss_deck_size + n_heroes + n_bosses`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| n_records | int | 0–`max_records` (knob, 5000) | data file | all records across all files; ~212 at v1 |
| n_refs | int | 0–50000 | calculated | every id reference checked in CR-5 step 6 |
| boss_deck_size | int | 1–60 | data file | per boss; Content decides the target |
| data_load_budget_ms | int | 50–1000 | data file (tuning knob, default 200) | wall-clock budget for `Unloaded → Ready` on target hardware (mid-range desktop, SSD, release build) |
| data_memory_budget_mb | int | 1–32 | data file (tuning knob, default 4) | resident size of the frozen snapshot |

**Output Range:** ~750 O(1) checks at v1 (212 + 90 + 90 + ~320 + 22), far inside budget; the
budget exists so that the JSON parse of ~150 KB plus the delegated validators cannot creep past a
perceptible boot stall. Load time is measured, logged and asserted in the performance test.
**Example:** v1 estimate: 212 records, 522 refs → 734 checks; parse + validate measured < 50 ms
expected, budget 200 ms.

## Edge Cases

Specialist note: `systems-designer` not spawned — Lean mode. Review manually before production.

**Identity and references**
- **If the same id appears twice** (in one file or across files): `E_DUP_ID` naming the id and every
  file (and record index) that defines it; load fails. Neither copy wins — a "last one wins" rule
  would hide the error.
- **If a starter deck, bundle, boss deck or `hero_power` references an id that does not exist**:
  `E_UNKNOWN_REF` naming the referring record, the field, the index in the list and the missing id;
  load fails. Rationale: a missing card found mid-run would be a rules bug to the player (Pillar 4).
- **If a card id's prefix disagrees with its `set` or with the file it is in**: `E_SET_MISMATCH`;
  load fails. Cheap to check, catches copy-paste between set files.
- **If a card's `text.key` is not `card.<id>.text`**: `E_TEXT_KEY`; load fails (keys are derived
  everywhere else, a divergent key would silently miss localisation).
- **If two different cards share a `name`**: `W_DUP_NAME` warning; load succeeds (names are display
  text, ids are identity), but Content should rename.

**Enums and shapes**
- **If `keywords` contains an id outside the DD-M09 list**: `E_BAD_ENUM`; load fails. New keywords
  are added to the list in Match Rules first, then used in data.
- **If `keywords` repeats an id, or `spell_damage > 0` appears without the `spell_damage` keyword
  (or vice versa)**: `E_SCHEMA`; load fails.
- **If a spell has `attack`/`health`, a minion lacks `health`, or a weapon lacks `durability`**:
  `E_MISSING_FIELD` / `E_UNKNOWN_FIELD` per CR-3; load fails.
- **If a minion has `health: 0` or a weapon `durability: 0`**: out of range (CR-3), `E_SCHEMA`;
  a 0-health minion would die on summon, which is an effect, not a stat.
- **If `cost` is outside 0–10**: `E_SCHEMA`. DD-M04 caps crystals at 10; cost reductions are
  effects at runtime, not data values.
- **If a record carries a field not in CR-3**: `E_UNKNOWN_FIELD`; load fails. Typos such as
  `durabilty` must not be ignored.

**Versions and files**
- **If `schema_version` is older than `schema_version_current`**: `E_SCHEMA_VERSION` (found,
  expected, file); load fails. There is no in-engine migration in v1 — a data migration script in
  `tools/` upgrades files offline; if a future version needs runtime migration it is added here as a
  per-version step before stage 4.
- **If `schema_version` is newer, missing, or `records` is not an array**: `E_SCHEMA_VERSION` /
  `E_PARSE`; load fails. The build does not understand the data; guessing would violate "never a
  partial silent load".
- **If a set file exists but `records` is empty**: `W_EMPTY_SET`; load succeeds unless a hero,
  bundle or boss references that set (then `E_UNKNOWN_REF` / `E_COUNT` fire as usual).
- **If a hero's `set` has no `cards_<set>.json`**: `E_MISSING_FILE` naming the hero and the file.
- **If an unexpected `.json` file sits in `assets/data/`**: `W_UNKNOWN_FILE`; it is not loaded.

**Pools and lists**
- **If a token card appears in a starter deck, bundle or boss deck**: `E_TOKEN_IN_LIST`; load fails.
  Tokens exist only through effects (summon, discover-from-list).
- **If a boss deck references hero-set cards** (e.g. a War weapon): allowed, no warning. Bosses may
  use any non-token card from any set, including `boss`; the player's pools never include `boss`.
- **If a bundle's card is from a different set than the bundle, or lacks the bundle's `theme`
  tag**: `E_SET_MISMATCH` / `E_TAG_MISMATCH`; load fails. Theme tags drive Reward Draft weighting,
  so an untagged card breaks "plan-shaped offers" (Pillar 1).
- **If a starter deck has 14 or 16 entries, or a bundle 2 or 4**: `E_COUNT` with found/expected
  (15 per DD-R03, 3 per DD-R04). Duplicate ids inside a starter deck are allowed (two copies).
- **If a boss `health` differs from its band default (DD-M02)**: `W_BAND_HEALTH`; allowed, so a
  puzzle boss can be tuned (Pillar 2), but visible.
- **If a hero has `hero_power: null`**: `E_MISSING_FIELD` (heroes always have a power, DD-M13); a
  boss may be `null` only when `passive` is non-null, otherwise `E_SCHEMA`.
- **If fewer than 9 treasures are unlocked by default** (Formulas): `W_POOL_SIZE`; load succeeds.

**Runtime** (query-before-`Ready` and release `reload()` are covered by the States table)
- **If `reload()` is called in a debug build during a match**: a new snapshot is built; the running
  match keeps its old snapshot handle until it ends; the next match uses the new one. If the reload
  fails, the old snapshot stays active and the report is shown as a debug overlay.
- **If a delegated validator is not registered at load**: `E_DELEGATED` naming the owner; release
  load fails. Tests inject stub validators that accept everything.

## Dependencies

Upstream: **none**. The Card Database is a Foundation system; it reads files and three injected
validators, nothing else. Every row below is a downstream dependent. **Hard** = cannot function
without this system; **Soft** = reads display data only.

| System | Direction | Hard/Soft | Nature of Dependency |
|--------|-----------|-----------|----------------------|
| Match Rules | depends on this | Hard | card, hero and hero-power records for every instance it creates; supplies the keyword id list (DD-M09) |
| Card Effects | depends on this | Hard | `effects[]`/`passive` payloads and `has(id)`; supplies the effects schema validator |
| Boss AI | depends on this | Hard | boss decks and `ai_profile`; supplies the profile validator |
| Heroes | depends on this | Hard | hero records, starter decks, hero set |
| Run Structure | depends on this | Hard | `bosses_in_band()` for sequence generation; `hero()` at select |
| Reward Draft | depends on this | Hard | `collectible_pool()`, `bundle_pool()`, `treasure_pool()`, `cards_by_tag()`; relies on id-sorted order for seeded draws |
| Treasures | depends on this | Hard | treasure records and hook payloads |
| Meta Progression | depends on this | Hard | `unlock` keys and hero ids; supplies the unlock-key validator |
| Content | depends on this | Hard | the schema it authors against; the headless validate command |
| Match UI | depends on this | Soft | `name`, `text`, `art`, `rarity` for rendering |
| Run UI | depends on this | Soft | boss `intro_text`, bundle `text`, hero art; the data-error screen renders `report()` |
| RNG & Event Log | none | — | no RNG, no events |

**Bidirectional note (design-docs.md):** none of the dependent GDDs exist yet. Each one, when
authored, must list "depends on Card Database" in its own Dependencies section. The systems index
currently names Card Database as a dependency only for Match Rules, Card Effects, Heroes, Reward
Draft and Content; **Boss AI, Run Structure, Treasures, Meta Progression, Match UI and Run UI rows
should add it** — flagged for the index owner (`/map-systems`), not edited here.

## Visual/Audio Requirements

Optional for `Core`; `art-director` not consulted — Lean mode. The system has one visible moment.

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|-----------------|----------------|----------|
| Load `Failed` (CR-8) | Full-screen data-error panel owned by Run UI: title, error count, scrollable report rows (`file · record_id · code · message`), Quit button; "Torchlit Ledger" rule applies — the report text is the lit element | none | MVP |
| Load `Ready` with warnings | Debug builds: console lines plus a small overlay badge with the warning count; release: log file only | none | MVP (debug) |
| Debug `reload()` | Overlay toast "Data reloaded: N records, W warnings" or the failure report | none | Vertical Slice |

Card art keys (`art`) are *provided* by this system but rendered by Match UI / Run UI against the
art bible; no art requirement originates here.

## Game Feel

N/A — `Core` infrastructure with no player-operated surface; feel targets for card play, attack
impact and draft picks belong to Match UI and Run UI. The one feel-adjacent requirement is boot
latency, covered by `data_load_budget_ms` (Formulas) so the main menu appears without a stall.

## UI Requirements

This system owns no screen. It supplies the data below; Run UI and Match UI display it.

| Information | Display Location | Update Frequency | Condition |
|-------------|------------------|------------------|-----------|
| Validation report (errors) | Data-error screen (Run UI) | once, at boot | state `Failed` |
| Warning count and rows | Debug overlay / log | once per load or reload | state `Ready` with warnings, debug builds |
| Card `name`, `text.en`, `cost`, `attack`, `health`, `durability`, `rarity`, `keywords`, `art` | Card frame (Match UI, draft picker) | on render | always |
| Bundle `name`, `text.en`, theme, 3 card frames | Draft picker (Run UI) | per draft | Reward Draft offers it |
| Boss `name`, `intro_text.en`, band | Boss intro (Run UI) | per floor | Run Structure enters a floor |
| Hero `name`, `health`, hero power text | Hero select (Run UI) | per run start | always; locked state from Meta Progression |

Localisation: UI reads `text.key` when a string table is present and falls back to `text.en`;
string tables are post-v1 (`/localize`).

📌 **UX Flag — Card Database**: the data-error screen is a UI surface. In Pre-Production, run
`/ux-design` for `design/ux/data-error.md` (or fold it into the main-menu spec) before writing
epics; stories should cite that spec, not this GDD.

## Cross-References

Target GDDs marked *(planned)* do not exist yet; the referenced element is the DD row the planned
GDD will own. `/review-all-gdds` should re-check these once those GDDs are written.

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|-----------|-----------------------------|--------|
| card `type` enum | `design/gdd/match-rules.md` *(planned)* | DD-M08 card types Minion/Spell/Weapon | Rule dependency |
| `keywords` id list, `spell_damage` | `design/gdd/match-rules.md` *(planned)* | DD-M09 keyword set v1 | Rule dependency |
| `cost` range 0–10 | `design/gdd/match-rules.md` *(planned)* | DD-M04 mana cap 10 | Rule dependency |
| hero `health` 30, boss band health 30/40/50 | `design/gdd/match-rules.md` *(planned)* | DD-M02 starting health | Data dependency |
| hero-power `cost` default 2 | `design/gdd/match-rules.md` *(planned)* | DD-M13 hero power | Data dependency |
| `effects[]`, `passive` schema and validator | `design/gdd/card-effects.md` *(planned)* | effect object schema | Ownership handoff |
| `ai_profile` validator | `design/gdd/boss-ai.md` *(planned)* | profile key set | Ownership handoff |
| `starter_deck` exactly 15 | `design/gdd/heroes.md` *(planned)* | DD-R03 starter deck | Rule dependency |
| boss `band` 1–3, `bosses_in_band()` | `design/gdd/run-structure.md` *(planned)* | DD-R01 bands, DD-R02 pool 6/6/4 | Data dependency |
| bundle `cards` exactly 3, `theme` tag | `design/gdd/reward-draft.md` *(planned)* | DD-R04 bundle draft, DD-H05 theme weighting | Rule dependency |
| `min_treasure_pool` = 9 | `design/gdd/reward-draft.md` *(planned)* | DD-R05 three treasure drafts, no duplicate offers | Rule dependency |
| id-sorted query order | `design/gdd/rng-event-log.md` (in design) | DD-R09 seed reproducibility, DD-T03 named streams | Rule dependency |
| treasure `rarity` common/rare, `unlock` key | `design/gdd/treasures.md`, `design/gdd/meta-progression.md` *(planned)* | DD-H04 treasure pool, unlock conditions | Ownership handoff |
| data-error screen | `design/gdd/run-ui.md` *(planned)* | boot failure presentation (CR-8) | State trigger |
| file list and envelope | `design/design-decisions.md` | DD-T01 (+ proposed `hero_powers.json`, set `boss`) | Data dependency |

## Acceptance Criteria

Specialist note: `qa-lead` not spawned — Lean mode (Section H is HIGH-risk per the skill; the
owner pre-approved a lean run). Review manually before production. Tests live in
`tests/unit/card_database/` and `tests/integration/card_database/`; fixtures are small JSON sets
under the test root, never the shipped data, except where "shipped data set" is stated.

**Loading and failure (CR-1, CR-5, CR-8)**
- [ ] **GIVEN** the shipped data set, **WHEN** the game boots, **THEN** state is `Ready`, `report()`
  has zero errors, and every record count matches the Content manifest.
- [ ] **GIVEN** the shipped data set with one card id duplicated into a second set file, **WHEN**
  loading, **THEN** the report contains one `E_DUP_ID` naming the id and both file paths, state is
  `Failed`, and in a desktop build the data-error screen is shown instead of the main menu; in
  headless mode the process exits non-zero.
- [ ] **GIVEN** three files each with one distinct error (a parse error, an unknown keyword, a
  missing starter-deck card), **WHEN** loading, **THEN** all three errors appear in one report
  (no fail-fast) and no record is queryable.
- [ ] **GIVEN** a file whose `schema_version` is 0, and another run where it is 2, **WHEN** loading,
  **THEN** each produces `E_SCHEMA_VERSION` with found and expected values and state `Failed`.
- [ ] **GIVEN** `cards_decay.json` with `records: []`, **WHEN** loading, **THEN** `W_EMPTY_SET` is
  reported, state is `Ready`, and `cards_by_set("decay")` returns an empty list.
- [ ] **GIVEN** a record with field `durabilty`, **WHEN** loading, **THEN** `E_UNKNOWN_FIELD` names
  the file, record id and field.

**Schema and references (CR-2, CR-3, CR-6)**
- [ ] **GIVEN** a hero whose `starter_deck` has 14 ids, **WHEN** loading, **THEN** `E_COUNT`
  reports found 14, expected 15.
- [ ] **GIVEN** a bundle whose third card lacks the bundle's `theme` tag, **WHEN** loading, **THEN**
  `E_TAG_MISMATCH` names the bundle, the card and the tag.
- [ ] **GIVEN** a boss deck containing a card with `token: true`, **WHEN** loading, **THEN**
  `E_TOKEN_IN_LIST` names the boss, the index and the card id.
- [ ] **GIVEN** a boss deck containing a War-set weapon, **WHEN** loading, **THEN** no error or
  warning is raised for that reference.
- [ ] **GIVEN** a `Ready` database, **WHEN** `card("no_such_id")` is called, **THEN** it returns
  `null` and logs one error line; in a debug build an assert fires.

**Pools and determinism (CR-6, Formulas)**
- [ ] **GIVEN** a fixture with 4 War cards (one token), 3 neutral cards and 2 boss-set cards,
  **WHEN** `collectible_pool("war")` is called, **THEN** it returns exactly the 6 non-token
  War+neutral cards, sorted by id ascending.
- [ ] **GIVEN** the same records authored in two different file orders, **WHEN** both are loaded,
  **THEN** every query returns identical sequences (same ids, same order).
- [ ] **GIVEN** a fixture with 8 treasures all `unlock: null`, **WHEN** loading, **THEN**
  `W_POOL_SIZE` reports 8 < 9 and state is `Ready`.
- [ ] **GIVEN** a fixture with 2 bundles for a hero set and 0 neutral bundles, **WHEN** loading,
  **THEN** `E_COUNT` reports a bundle pool of 2 below the hard floor 3.

**Delegation and runtime (CR-5 step 7, States)**
- [ ] **GIVEN** a stub effects validator that rejects any effect with `op: "bogus"`, **WHEN** a card
  with that effect loads, **THEN** the report contains `E_DELEGATED` with the stub's code and the
  card id.
- [ ] **GIVEN** a release-configured load with no Boss AI validator registered, **WHEN** loading,
  **THEN** `E_DELEGATED` names the missing owner and state is `Failed`.
- [ ] **GIVEN** a debug build in `Ready` with a match in progress, **WHEN** a card's `attack` is
  edited on disk and `reload()` is called, **THEN** the running match still reads the old value, the
  next match reads the new one, and the overlay reports the record count.
- [ ] **GIVEN** a debug build in `Ready`, **WHEN** `reload()` runs against a file with a parse
  error, **THEN** the previous snapshot remains queryable and the new report is shown.

**Performance and standards**
- [ ] Performance: **GIVEN** the shipped v1 data set on target hardware (release build, SSD), **WHEN**
  `load()` runs, **THEN** `Unloaded → Ready` completes in ≤ `data_load_budget_ms` (200 ms) and the
  frozen snapshot is ≤ `data_memory_budget_mb` (4 MB); the test logs both numbers.
- [ ] No hardcoded values: `schema_version_current`, pool thresholds and budgets are read from
  config, not literals in the loader; no file outside the Card Database parses `assets/data/*.json`
  (a grep-based test enforces this).

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| DD-T01 lists five file kinds; this GDD adds `hero_powers.json` and set `boss` (`cards_boss.json`). Accept and update the register? | owner | before `/design-system match-rules` | Proposed here (CR-1); needs a DD-T01 edit + `/propagate-design-change` |
| MVP ships 8 treasures (DD-H06) but DD-R05 needs 9 distinct unlocked treasures per run (Formulas). Raise MVP to 9, or let Reward Draft re-offer treasures that were offered but not taken? | owner + Reward Draft GDD | `/design-system reward-draft` | Open; loader warns (`W_POOL_SIZE`), does not block |
| Should the DD-M02 band-default boss health live in data (`bosses.json` per record, as here) or only in Match Rules config, with the record field optional? | Match Rules GDD | `/design-system match-rules` | Resolved here as "explicit per record, warned on deviation"; Match Rules may overturn |
| Runtime schema migration vs offline script when `schema_version` changes | engine-programmer (ADR) | first schema bump | Resolved for v1: offline script in `tools/`, loader rejects old versions |
| Does Discover need a per-effect card list, or is `collectible_pool(hero_set)` its universe? | Card Effects GDD | `/design-system card-effects` | Open; both are supported by CR-6 |
| Rarity three tiers (common/rare/legendary) vs four | owner | `/design-system content` | Resolved here as three (CR-4); revisit only if a rule needs a fourth tier |
