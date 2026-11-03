# ADR-0002: Data format, effect schema/DSL and `config()` loading

## Status

Proposed

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories referencing a `Proposed` ADR are set `Blocked`, and epics require
> `Accepted`, so the field needs a named owner. `technical-director` is the role
> `coordination-rules.md` escalates technical conflicts to.

**Review record (this authoring run, 2026-11-03):**
- Engine validation (`godot-specialist`, Step 5.5): **NOT ASSESSED — not spawned.** The decision relies on no post-cutoff engine API; every engine claim below is either sourced from `docs/engine-reference/godot/` or marked `NOT SOURCEABLE` with the test that proves it. A specialist answering from pre-4.3 training data would add opinion, not evidence (same reasoning as `architecture.md` Document Status).
- TD-ADR (`technical-director`, Step 5.6): **skipped — Lean mode** (`review_mode: lean`; TD-ADR is not a PHASE-GATE).
- GDD sync (Step 5.7): checked 5 referenced GDDs (card-database, card-effects, content, heroes, treasures). No renames. Two **arity** differences between GDD prose and `architecture.md` §API Boundaries are carried here deliberately and are not renames: `validate_effects(host_kind, host_id, effects)` in card-effects C10 is `validate_effects(host_kind, host_id, effects, db, caps)` in code (the last two are injected collaborators), and the loader's `load(validators)` takes the validator map the GDD describes in prose. One **semantic** refinement, not a rename: card-database's States table says queries are illegal before `Ready`; Decision 4 opens lookup queries to validator callbacks during stage 7 (the GDD's own stage 7 requires `has(id)` from the Card Effects and Treasures validators, so the table's wording and its pipeline already disagree — flagged for the card-database owner, no GDD edit here).
- Numbering: fixed by `design/design-decisions.md` DD-X08 (ADR-0002), not by a registry scan.

## Date

2026-11-03

## Last Verified

2026-11-03 — against Godot 4.7.2 (`docs/engine-reference/godot/VERSION.md`, installed `4.7.2.stable.official.ed1daf0bf`) and the Approved GDDs dated 2026-11-03.

## Decision Makers

Authored headlessly by `/architecture-decision` (guided automation, no `AskUserQuestion` answerer); every gated choice took the recommended option and is listed under *Decisions taken* in the run report. Acceptance authority: Jacob (owner) or `technical-director` on his confirmation.

## Summary

Every definition and every tuning knob the game runs on is UTF-8 JSON under `assets/data/` (DD-T01), parsed by exactly one class — `CardDatabase` (`src/core/data/`) — through the nine-stage CR-5 pipeline with validators injected at composition, frozen into an id-sorted snapshot with a SHA-256 `data_version`, and handed to owners through `config(name)`. Effect objects stay opaque to the loader and are owned by Card Effects' `EffectValidator`; `.tres` resources (the prototype's TD-008 failure) and per-system loaders are rejected.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7) |
| **Domain** | Core |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH for GDScript/Core generally (VERSION.md: 4.5–4.7 post-cutoff); the specific APIs this ADR uses are pre-4.4 and LOW, but several are **not covered by the engine reference** and are therefore verified by tests, not assumed (see details) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `breaking-changes.md` (4.3→4.4 Core row: `FileAccess.store_*` return `bool`; 4.6→4.7 GDScript rows), `current-best-practices.md` (GDScript 4.5+/4.7, Command Line section), `deprecated-apis.md` (`duplicate()` for nested *resources* → `duplicate_deep()`; untyped containers pattern); `docs/architecture/spikes/2026-11-03-engine-probes.md` (Probe B: `FileAccess.open` return/`get_open_error`, `store_string → true`, `flush()`/`close()` observed) |
| **Post-Cutoff APIs Used** | None required. Two post-cutoff *rules* apply to the code: an override of a typed method needs an explicit `return` (4.7, sourced) and lambdas capture locals by value (sourced) — both affect how `ValidationReport` subclasses and validator Callables are written, not which API is called |
| **Verification Required** | (1) `JSON.parse()` error line/message on a malformed file; (2) `HashingContext` SHA-256 known-answer across two machines (CI + dev); (3) `Dictionary.make_read_only()` nesting semantics (the freeze walks recursively and the test asserts a nested write is refused); (4) `assets/data/*.json` present in the exported PCK; (5) `Unloaded → Ready` ≤ `data_load_budget_ms` (200) on the reference machine. All are `NOT SOURCEABLE` from the engine reference and are listed with their tests under *Validation Criteria* |

> If Knowledge Risk is MEDIUM or HIGH, this ADR must be re-validated when the project upgrades engine versions.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (rules / presentation split — `docs/architecture/adr-0001-rules-presentation-split.md`, **Proposed** as of 2026-11-03; this ADR assumes its layer map, grep gates and the `Boot` composition root). The acceptance route refuses to accept this ADR while ADR-0001 is `Proposed` |
| **Enables** | ADR-0003 (RNG service takes `data_version` as a constructor argument), ADR-0004 (`config("profile_defaults")`), ADR-0005 (treasure records and the stage-7 slot), ADR-0007 (the `EffectValidator` injection point and the effect schema it validates); every Config/Data story (content CN-6 batches MVP-0 onward) |
| **Blocks** | Card Database epic (loader, `config()`, validate command), Content MVP-0 batch, every system story that reads `config(<name>)` at construction |
| **Ordering Note** | Written second (DD-X08 numbering, `architecture.md` priority order 0001 → 0002). `tools/content/validate.gd` (content CN-6.3) is a story under this ADR, not a separate ADR. The per-file JSON Schema documents are deferred to the MVP-1 validator story (`architecture.md` "Can defer") |

## Context

### Problem Statement

Thirteen GDDs describe their numbers, records and effect texts as data, and the prototype shows what happens without a schema and a single loader: 35 `.tres` cards carried only a name and a description, seven starter decks referenced ids no resource defined, and the game fell back to generated "Test Minion" cards (TD-008); mulligan counts were literals in a screen script (TD-011); no card effect existed because there was no data shape to write one in (TD-004). Before the first rules story can be written, the project needs one decided answer to: what format, which files, who parses, how records are validated, how an effect is written, how a tuning knob reaches the code that uses it, and how two machines know they run the same content.

### Current State

`assets/data/` does not exist yet; `project.godot`, gdUnit4 (`addons/gdUnit4`, 6.2.3) and `tests/helpers/` (`TestConstants`, `CardFactory`, `MatchFactory`) are in place. The prototype under `prototypes/hearthstone-clone-2026-01/` is archived and is not ported (`.claude/rules/prototype-code.md`). Card-database CR-1..CR-9, card-effects C1–C5/C10, content CN-6, heroes H-1 and DD-T01 are Approved and already agree on JSON, envelopes and injected validators; this ADR fixes the engine-level mechanics the GDDs left to architecture ("file I/O and class layout belong to an ADR" — card-database Core Rules note).

### Constraints

- DD-T01: all definitions are JSON under `assets/data/`, snake_case keys, `schema_version` field; `.claude/rules/data-files.md` requires `[system]_[name].json` naming, valid JSON, documented schema and snake_case keys.
- Systems index / card-database CR-1 / match-rules Dependencies: **nothing else parses `assets/data/*.json`**.
- Architecture principle 5: "Data owns the numbers; code owns the verbs" — `schema_version_current` is the one exempt literal (card-database CR-5 step 3).
- Architecture principle 6 and `Boot`: `CardDatabase.load()` is called once by `Boot.boot()` with the validators collected from `EffectValidator`, `BossAI`, `Treasures`, `MetaProgression` and each config owner (`architecture.md` Data Flow §5); the loader is a `RefCounted` with constructor injection and runs headless under gdUnit4 and under `godot --headless -s`.
- Engine: `FileAccess.store_*` return `bool` since 4.4 (sourced) — relevant only to the validate command's report file, if any; the loader itself only reads. `JSON`, `HashingContext`, `Dictionary.make_read_only()` are **not covered** by `docs/engine-reference/godot/` (NOT SOURCEABLE); they predate the 4.3 cutoff and are verified on 4.7.2 by the tests named below.
- Budget: `Unloaded → Ready` ≤ `data_load_budget_ms` (200), snapshot ≤ `data_memory_budget_mb` (4), synchronous at boot (card-database Formulas; TR-card-database-005).

### Requirements

- Must implement card-database CR-1..CR-9 exactly: two envelopes, DD-T01 name-list discovery, one global id namespace, CR-3 record schemas, nine-stage pipeline collecting every error, id-ascending queries, frozen snapshot, `config(name)`, `data_version`, `Failed` with no main menu (TR-card-database-001..005).
- Must treat `effects[]` / `passive` as opaque and delegate their validation to `EffectValidator.validate_effects` with the closed `E_FX_*` set (card-effects C10; TR-card-effects-001, -005); `targeting_spec` is derived from the one `chosen` selector, never stored (C1 rule 1).
- Must serve twelve config bodies (`match_rules`, `card_effects`, `ai_profiles`, `run_structure`, `reward_draft`, `treasures_balance`, `heroes_balance`, `match_ui`, `run_ui`, `profile_defaults`, `card_database`, `content_budgets`) each validated by its owner's injected validator, except `card_database.json` which the loader schema-checks itself at stage 4.
- Must provide the headless validate command content CN-6.3 relies on: prints the report, exits non-zero on any error (TR-content-001).
- Must make `data_version` stable across machines (CR-9) — Run Structure refuses to resume across versions (R8), Meta keeps `data_versions_seen[]` (M3.5).

## Decision

**All game data is JSON under `assets/data/`, loaded by one `CardDatabase` through a `DataLoader` that discovers files from a code-owned manifest of the DD-T01 names, parses with `JSON`, validates in the nine CR-5 stages with injected validators, freezes the result recursively, and computes `data_version` with `HashingContext` SHA-256 over a canonical `JSON.stringify(..., sort_keys = true)` of every file body.** The effect schema is Card Effects' (ADR-0007 fixes the resolver side; this ADR fixes that the validator is a static, side-effect-free function injected under the key `effects`). Config bodies reach their owners **once**, at the owner's construction, as frozen Dictionaries; owners keep the reference and never re-query per frame.

Specifics, in pipeline order:

1. **Manifest, not directory scan.** `DataLoader.FILE_MANIFEST` is a constant array of `{name, class: definition|config, record_type|null, required: bool, owner}` rows mirroring the card-database CR-1 table (set files `cards_<set>.json` for `war, neutral, boss` required at MVP; `decay, knowledge, fortune, order, shadow` optional). The manifest is *format knowledge* — the same exemption as `schema_version_current` — and carries no gameplay number. A `.json` under `assets/data/` not in the manifest is `W_UNKNOWN_FILE` and is not loaded; a required file missing is `E_MISSING_FILE`. Adding a system's knob file means a DD-T01 row **and** a manifest row, never a new parser. One such row is already owed: ADR-0003 reads `log_memory_budget_bytes`, `avg_event_bytes` and `keep_match_logs` through `config("rng_event_log")`, and rng-event-log F7 calls them data-file knobs, but DD-T01 lists no `rng_event_log.json`; the manifest gains that config row (owner: RNG & Event Log, validator `EventLog.validate_config`) **when the owner adds the DD-T01 row** — until then the knobs have no file, which is an open point, not something this loader papers over.
2. **Read and parse.** `FileAccess.open("res://assets/data/<name>", FileAccess.READ)`; a `null` return reports `FileAccess.get_open_error()` (Probe B observed `ERR_FILE_NOT_FOUND = 7` for a missing file) as `E_MISSING_FILE`. Text goes to `JSON.new()` + `parse(text)`, chosen over `JSON.parse_string()` because the instance form exposes `get_error_line()` / `get_error_message()` for the CR-5 stage-2 `E_PARSE` entry ("file and, where the parser gives it, line/column"). `NOT SOURCEABLE — JSON.parse error location on 4.7.2`; the unit test below proves it.
3. **Envelope, schema, uniqueness, cross-references** (stages 3–6) run in `DataLoader` over plain Dictionaries with the closed code set from card-database CR-5 and Edge Cases (`E_SCHEMA_VERSION`, `E_PARSE`, `E_SCHEMA`, `E_MISSING_FIELD`, `E_UNKNOWN_FIELD`, `E_BAD_ENUM`, `E_SET_MISMATCH`, `E_TEXT_KEY`, `E_DUP_ID`, `E_UNKNOWN_REF`, `E_COUNT`, `E_TOKEN_IN_LIST`, `E_TAG_MISMATCH`, `E_MISSING_FILE`, `E_DELEGATED`, `E_NOT_LOADED`, `E_NOT_SUPPORTED`; warnings `W_UNKNOWN_FILE`, `W_EMPTY_SET`, `W_DUP_NAME`, `W_POOL_SIZE`, `W_BAND_HEALTH`). `schema_version_current = 1` is a `const` in `DataLoader`; `TestConstants.SCHEMA_VERSION_CURRENT` mirrors it. Both older and newer `schema_version` fail; offline migration lives in `tools/`, never in the loader.
4. **Delegated validators** (stage 7) arrive as `load(validators: Dictionary)` with the shape `architecture.md` Data Flow §5 shows: `{effects: Callable, ai_profile: Callable, unlock: Callable, treasure: Callable, configs: {<name>: Callable}}`. Record validators receive `(host_kind, host_id, record_field, db, caps)`-style arguments per their GDD (`EffectValidator.validate_effects(host_kind, host_id, effects, db, caps)`; `BossAI.validate_profile_key(key, profiles)`; `MetaProgression.validate_unlock_defs(defs, db)`; `Treasures.validate_treasure_defs(defs, db)`); config validators receive the frozen body and return `[{code, host_id|null, field, message}]`. Each result is merged with severity `E_DELEGATED` plus the owner's code. **A missing validator for any record field or externally owned config file is itself `E_DELEGATED` in release builds**; `OS.is_debug_build()` does not relax it — unit tests inject accepting stubs explicitly. `card_database.json` (five integer knobs: `min_collectible_pool`, `min_bundle_pool`, `max_records`, `data_load_budget_ms`, `data_memory_budget_mb`) is schema-checked at stage 4 and needs no injection.
   **Stage-7 calling convention (answers ADR-0007's open point "stage-7 `caps` availability").** Stage 7 runs in two sub-steps: **7a** every config validator, as `callable.call(body: Dictionary, db: CardDatabase) -> Array`; **7b** every record validator, as `callable.call(host_kind: StringName, host_id: String, value: Variant, db: CardDatabase, configs: Dictionary) -> Array`, where `configs` is the map of parsed config bodies that passed 7a (`{match_rules: {...}, card_effects: {...}, …}`, read-only). Config bodies **are** readable before freeze — the loader hands them over itself, so `Boot` never parses a file to pre-bind anything. `Boot` registers `effects` as a one-line adapter, `func(kind, id, fx, db, configs): return EffectValidator.validate_effects(kind, id, fx, db, configs["card_effects"])`, which keeps ADR-0007's `validate_effects(host_kind, host_id, effects, db, caps)` signature intact; the other record validators ignore `configs`. During stage 7 the `CardDatabase` is in `Loading` and answers **lookup** queries (`has`, `card`, `hero_power`, `boss`, `treasure`, `bundle`, `cards_by_*`, `collectible_pool`, `treasure_pool`) from the staged, id-sorted records that passed stage 6 — the one exception to card-database's "queries are illegal before `Ready`" (States table), scoped to validator callbacks and asserted in debug by a `_stage7_lookups_open` flag. `config()` and `data_version()` stay illegal until `Ready`.
5. **Freeze and fingerprint** (stage 9). With zero errors the loader sorts every record list by id (CR-6 ordering; `index_of` built once), calls `make_read_only()` recursively on every record and config body (`NOT SOURCEABLE — whether Dictionary/Array.make_read_only() applies to nested containers`; the loader walks and the test asserts nested writes are refused), and computes `data_version`: for each manifest row in CR-1 table order, `update(name.to_utf8_buffer())` then `update(JSON.stringify(parsed_body, "", true, true).to_utf8_buffer())` into one `HashingContext` opened with `HASH_SHA256`; `finish().hex_encode().substr(0, 16)`. Sorted keys and no indent make key order and whitespace irrelevant; `full_precision = true` keeps any float stable; CR-3 data is integer-valued by schema. `NOT SOURCEABLE — JSON.stringify sort_keys / compact output and HashingContext on 4.7.2`; the known-answer test proves it on two machines.
6. **Queries and `config()`** are pure reads on the frozen snapshot and return the frozen Dictionary (records) or a frozen `Array` copy of the id-sorted list (pools); an unknown id or config name returns `null` and logs `E_NOT_LOADED`-class errors through `push_error`, never throws. Owners that need mutable copies take `duplicate(true)` themselves (plain containers — the `deprecated-apis.md` `duplicate_deep()` row concerns nested *Resources*, which never occur here).
7. **Failure is visible** (CR-8): `load()` returns the `ValidationReport`; `state()` is `Failed`; `Boot` hands the report to `RunShell` for the `data_error` screen; the headless validate command prints it and exits 1.
8. **`reload()`** builds a new snapshot in a debug build and swaps it atomically on success (a match holds the handle it started with); in release it returns `E_NOT_SUPPORTED`.
9. **Effect schema ownership.** The loader never inspects `effects[]`, `passive` or any config body beyond "is an array / is an object". The effect object shape (card-effects C1: `id, trigger, scope, condition, targets, ops[], once_per_turn`), the trigger vocabulary (C2), selectors (C3), values (C4), ops (C5), caps (`MAX_OPS_PER_EFFECT` 8, `EFFECT_STATIC_STEP_LIMIT` 250 from `config("card_effects")`) and the closed `E_FX_*` / `W_FX_*` set are owned by `EffectValidator` (`src/gameplay/effects/`). The v1 schema documents required by `data-files.md` are the GDD tables (card-database CR-3, card-effects C1–C5); machine-readable JSON Schema files land at `tools/content/schemas/<file>.schema.json` with the MVP-1 validator story and must agree with the loader, not replace it.
10. **Export inclusion.** `.json` files are not scenes or imported resources; `export_presets.cfg` carries `include_filter="assets/data/*.json"` so the PCK holds them regardless of the export mode. `NOT SOURCEABLE — default export inclusion of .json files`; the smoke check reads `data_version()` from an exported build.

### Architecture Diagram

```
assets/data/*.json  (DD-T01: 7 definition files incl. cards_<set>, 12 config files)
        │  FileAccess.open(READ) → get_as_text()           [stage 1–2]
        ▼
   DataLoader (src/core/data/data_loader.gd)
        │  JSON.new().parse(text)  ──► E_PARSE{file, line, message}
        │  envelope → schema → uniqueness → cross-refs    [stage 3–6]
        │  delegated validators (injected Callables)       [stage 7]
        │      effects ──► EffectValidator.validate_effects   (card-effects C10, ADR-0007)
        │      ai_profile ► BossAI.validate_profile_key
        │      unlock ───► MetaProgression.validate_unlock_defs
        │      treasure ─► Treasures.validate_treasure_defs   (ADR-0005)
        │      configs{name} ► owner's config validator (12 files; card_database.json self-checked)
        │  budget warnings                                  [stage 8]
        │  sort by id · make_read_only (recursive) · SHA-256 [stage 9]
        ▼
   CardDatabase snapshot  { records_by_type, index_of, config_bodies, data_version, report, state }
        │
        ├── card()/hero()/…/pools  (id-ascending, frozen)  → Match Rules, Reward Draft, Run Structure, UI
        ├── config(name)            (frozen body, read once) → every config owner at _init
        └── data_version()                                 → RngService(run_seed, data_version), RunRecord, Meta

   Boot.boot() ──► CardDatabase.load(validators)  (once, synchronous, ≤ 200 ms)
   tools/content/validate.gd (SceneTree script) ──► same DataLoader, prints report, exit 0 | 1
```

### Key Interfaces

Signatures match `architecture.md` §API Boundaries; record Dictionaries use the CR-3 field names exactly.

```gdscript
# src/core/data/card_database.gd — card-database CR-1..CR-9
class_name CardDatabase extends RefCounted
enum State { UNLOADED, LOADING, READY, FAILED, RELOADING }
func _init(loader: DataLoader = null) -> void              # default DataLoader.new(); tests inject a loader over fixture paths
func load(validators: Dictionary) -> ValidationReport      # {effects, ai_profile, unlock, treasure: Callable; configs: {name: Callable}}
#   stage 7a: configs[name].call(body, db) -> Array                                   (owner's config validator)
#   stage 7b: <record>.call(host_kind, host_id, value, db, configs_bodies) -> Array   (db in Loading answers lookups only)
func reload() -> ValidationReport                          # debug builds only; E_NOT_SUPPORTED in release
func card(id: String) -> Dictionary;  func hero(id: String) -> Dictionary;  func hero_power(id: String) -> Dictionary
func boss(id: String) -> Dictionary;  func treasure(id: String) -> Dictionary;  func bundle(id: String) -> Dictionary
func has(id: String) -> bool
func cards_by_set(s: String) -> Array; func cards_by_type(t: String) -> Array; func cards_by_tag(t: String) -> Array
func cards_by_cost(c: int) -> Array;   func cards_by_rarity(r: String) -> Array
func collectible_pool(hero_set: String) -> Array; func bundle_pool(hero_set: String) -> Array
func treasure_pool() -> Array; func bosses_in_band(band: int) -> Array; func heroes() -> Array   # all id-ascending
func config(name: String) -> Dictionary                    # frozen body of <name>.json; null + logged error if unknown
func data_version() -> String; func report() -> ValidationReport; func state() -> State

# src/core/data/data_loader.gd — the only JSON parser in the project
class_name DataLoader extends RefCounted
const SCHEMA_VERSION_CURRENT: int = 1                      # the one exempt literal (CR-5 step 3)
const FILE_MANIFEST: Array[Dictionary] = [ ... ]          # DD-T01 rows: {name, class, record_type, required, owner}
func _init(root: String = "res://assets/data/") -> void    # tests point it at tests/fixtures/data/<case>/
func run(validators: Dictionary) -> LoadResult             # {report: ValidationReport, snapshot: Dictionary|null}
static func canonical_json(value: Variant) -> String       # JSON.stringify(value, "", true, true)
static func fingerprint(bodies: Array[Dictionary]) -> String   # SHA-256 over name + canonical body, first 16 hex

# src/core/data/validation_report.gd — CR-5 report shape
class_name ValidationReport extends RefCounted
func add(severity: StringName, code: StringName, file: String, record_id: Variant, field: Variant, message: String) -> void
func entries() -> Array[Dictionary]                        # sorted by file, then record id
func errors() -> Array[Dictionary]; func warnings() -> Array[Dictionary]; func has_errors() -> bool
func to_text() -> String                                   # the data_error screen and the validate command print this

# src/gameplay/effects/effect_validator.gd — card-effects C10 (resolver side fixed by ADR-0007)
class_name EffectValidator extends RefCounted
static func validate_effects(host_kind: StringName, host_id: String, effects: Array, db: CardDatabase, caps: Dictionary) -> Array
#   → [{code, host_id, effect_id, path, message}] with the closed E_FX_* / W_FX_* set
static func targeting_spec(effects: Array) -> Dictionary   # {mode: none|optional|required, filter}; derived, never stored (C1 rule 1)

# tools/content/validate.gd — content CN-6.3 headless validate command
# godot --headless --path . -s res://tools/content/validate.gd [-- --data-root res://assets/data/]
# exit 0: Ready (warnings printed) · exit 1: Failed (report printed) · exit 2: could not run (bad root, no project)
```

Validator Callables bound at composition (`Boot.boot()`), with their owners: `effects → EffectValidator.validate_effects` (bound with `db` and `config("card_effects")` caps), `ai_profile → BossAI.validate_profile_key` (bound with `config("ai_profiles")`), `unlock → MetaProgression.validate_unlock_defs`, `treasure → Treasures.validate_treasure_defs`, `configs → {match_rules: RulesEngine.validate_config, card_effects: EffectValidator.validate_config, ai_profiles: BossAI.validate_profiles_config, run_structure: RunMachine.validate_config, reward_draft: RewardDraft.validate_config, treasures_balance: Treasures.validate_config, heroes_balance: Heroes.validate_config, match_ui: MatchViewState.validate_config, run_ui: RunController.validate_config, profile_defaults: MetaProgression.validate_profile_defaults, content_budgets: ContentValidator.validate_config}`. Each is a `static func` so the validate command can compose them without `Boot`.

### Implementation Guidelines

- **Must** route every read of `assets/data/*.json` through `CardDatabase`; **must never** call `FileAccess.open("res://assets/data/…")`, `JSON.parse_string`, `JSON.new().parse` or `load("res://assets/data/…")` anywhere else in `src/` (control-manifest grep gate; `tools/content/validate.gd` is allowed because it composes `DataLoader`).
- **Must** read `config(<name>)` once in the owner's `_init(...)` (or `bind`) and keep the reference; **must never** call `config()` per frame, per command or per hook invocation.
- **Must** keep `schema_version_current` and `FILE_MANIFEST` the only data-shaped literals in `src/core/data/`; **must never** add a numeric gameplay default to loader code — a missing knob is `E_DELEGATED` from the owner's validator, not a fallback.
- **Must** register a validator for every record field and every externally owned config file; **must never** make a missing validator pass silently in any build type. Tests inject `func(...): return []` stubs explicitly.
- **Must** return `null` + `push_error` for unknown ids / names and `ValidationReport` entries for data faults; **must never** `assert()` on data in release paths or throw.
- **Must** treat every returned Dictionary/Array as read-only; a system that mutates takes `duplicate(true)` first (Match Rules copies `attack`/`health`/`durability` into instances per CR-7).
- **Must** write `effects[]`, `passive` and config bodies as plain JSON with no code references (card-effects C1 rule 4); **must never** express a card text in GDScript — an inexpressible text is a card-effects GDD change.
- **Must** keep `data_version` derived (CR-9); **must never** author a content-version string in any file.
- **Must** sort every list query by id before freezing; **must never** depend on file order or authoring order (seeded draws, CR-6).
- **Must** keep `export_presets.cfg` `include_filter="assets/data/*.json"`; the smoke check asserts `data_version()` is non-empty in an exported build.
- Overrides of typed methods (`ValidationReport` subclasses in tests) **must** `return` explicitly (4.7 inherited-return rule, sourced).

## Alternatives Considered

### Alternative 1: Godot `Resource` files (`.tres` / `.res`) with `@export` scripts (the prototype's approach)
- **Description**: `CardDef extends Resource` with `@export` fields; one `.tres` per card; decks as `Array[CardDef]`; `load()` at runtime.
- **Pros**: Inspector editing; typed fields; engine-native.
- **Cons**: TD-008 is the record of how this fails without a schema gate — `.tres` enforces nothing about completeness or references, and a missing field is silently default-valued. Validation requires the editor import step (a fresh clone needs `godot --headless --path . --import` first — `current-best-practices.md` Command Line, with observed 4.7.x crashes on first import), which is exactly the path CI content checks must avoid. Nested resources bring the `duplicate()` → `duplicate_deep()` deprecation (`deprecated-apis.md`). `.tres` diffs are noisy for Content review, tooling outside Godot (`/balance-check`, `/content-audit`) cannot read them, and the format is engine-locked against `data-files.md`.
- **Estimated Effort**: Similar to write; much higher to validate and to tool.
- **Rejection Reason**: DD-T01 is an owner decision for JSON, `data-files.md` mandates JSON, and the schema/cross-reference gate is the whole point of retiring TD-008.

### Alternative 2: Per-system loaders (each GDD parses its own file)
- **Description**: `RulesEngine` reads `match_rules.json`, `BossAI` reads `ai_profiles.json`, and so on; `CardDatabase` handles only definition files.
- **Pros**: No injection map; each owner validates in place.
- **Cons**: Cross-reference checks (hero `starter_deck`, boss `deck`, `hero_power` ids, bundle cards) need every file loaded together; twelve parsers mean twelve `E_PARSE` paths, twelve envelope checks and no single `Failed` state (CR-8 "no main menu over bad data" becomes unenforceable); `data_version` could not cover config bodies, so a balance edit would not change the fingerprint and resume-across-versions (R8) would silently break; it violates the systems-index rule "nothing else parses JSON".
- **Estimated Effort**: Lower upfront, higher ongoing.
- **Rejection Reason**: Card-database CR-1's config class exists precisely so one parser serves twelve knob files; the fingerprint and the single failure state depend on it.

### Alternative 3: One bundled data file (`game_data.json`)
- **Description**: A single file with every record type and config body under top-level keys.
- **Pros**: One parse, trivial discovery, one `schema_version`.
- **Cons**: Content batches ship per set and per system (content CN-6 table) and are owned by different roles; one file concentrates merge conflicts and makes `W_UNKNOWN_FILE`-style ownership checks impossible; DD-T01 names the files.
- **Estimated Effort**: Lowest to write.
- **Rejection Reason**: DD-T01 and CN-6 batch ownership.

### Alternative 4: GDScript data (`const CARDS := {...}`)
- **Description**: Records as GDScript dictionaries or class constants.
- **Pros**: No parser; typed constants.
- **Cons**: Not data — every balance change is a code change and a parse-check run; Content cannot author it; `/balance-check` tooling cannot read it; violates DD-T01 and principle 5.
- **Rejection Reason**: Contradicts the design record outright.

## Consequences

### Positive
- One parser, one report, one failure state: a bad id is found at boot with file, record and field, not three systems downstream (Pillar 4; TD-008 retired).
- Every tuning knob has a file and an owner; `TestConstants` mirrors the registry so tests never carry inline numbers while production reads only `config()`.
- `data_version` makes "same content" a checkable fact for resume, retro-grants and bug reports.
- The validate command gives Content a zero-error gate in CI without the editor.
- Effect texts are authorable data validated at load; the resolver (ADR-0007) never meets an unexpressible effect at runtime.

### Negative
- A twelve-entry validator map is composition boilerplate `Boot` and the validate command must keep in step; a forgotten entry is a loud `E_DELEGATED`, which is the intended failure.
- Synchronous boot load: ~150 KB of JSON plus ~900 checks must stay under 200 ms; the budget is asserted by a performance test and will need re-measurement as content grows.
- JSON has no comments; `data-files.md`'s "numbers must be explained" obligation is met by the GDD Tuning Knobs tables and the `[system]_[name]` file split, not inline.
- Five engine behaviours this decision leans on are not in the engine reference and are carried as tests rather than citations.

### Neutral
- Records are frozen Dictionaries, not typed classes; typing lives in the schema stage and in the record wrappers (`MatchConfig`, `RunRecord`) that other ADRs define.
- `reload()` exists only in debug builds.

## Risks
- **`make_read_only()` may not freeze nested containers** → the loader walks recursively regardless; test `card_database_freeze_test.gd` asserts a nested write fails on 4.7.2.
- **`JSON.stringify` output differs across platforms (float formatting)** → data is integer by schema; `full_precision = true`; known-answer test compares a committed hash on Linux CI and a Windows dev machine; a mismatch is a release blocker until canonicalisation is hand-rolled.
- **Exported PCK omits `.json`** → explicit `include_filter`; smoke test on the exported build.
- **Boot stall over budget as content grows** → performance test asserts `data_load_budget_ms`; if breached, the first lever is skipping stage-8 pool warnings in release, the second is a lazy per-set index — neither changes this ADR's contract.
- **Validator arity drift between GDD prose and code** → the two deviations are recorded above; `/architecture-review` checks signatures against `architecture.md`.
- **`rng_event_log` knobs have no DD-T01 file** (Decision 1; ADR-0003 already reads `config("rng_event_log")`) → until DD-T01 gains a row, `EventLog` cannot read `log_memory_budget_bytes` through `config()` as rng-event-log F7 requires; the owner adds the row, the manifest follows.
- **Stage-7 lookup exception misused at runtime** → `_stage7_lookups_open` is set only inside stage 7; a lookup in `Loading` outside it is `E_NOT_LOADED` as the States table says.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| card-database.md | CR-1 files and envelopes; "no other code parses JSON" (TR-card-database-001) | Manifest-driven discovery, two envelopes, `DataLoader` as the single parser with a grep gate |
| card-database.md | CR-2 id namespace, CR-3 record schemas, CR-4 enums | Stage 4 schema checks with the closed error set; `E_UNKNOWN_FIELD` for typos |
| card-database.md | CR-5 nine-stage pipeline with delegated validators (TR-card-database-002) | `load(validators)` map, stage order, `E_DELEGATED` for missing validators in every build |
| card-database.md | CR-6 pure id-ascending queries; `config(name)` (TR-card-database-003) | Sorted-at-freeze lists, `index_of`, frozen config bodies read once |
| card-database.md | CR-7 immutability, CR-8 failure visible, CR-9 `data_version` (TR-card-database-004) | Recursive `make_read_only`, `Failed` state + report, SHA-256 fingerprint over canonical JSON |
| card-database.md | Formulas: load ≤ 200 ms, snapshot ≤ 4 MB (TR-card-database-005) | Synchronous load with a performance test; knobs in `card_database.json` |
| card-effects.md | C1 effect object shape, rule 1 derived targeting (TR-card-effects-001) | Effects opaque to the loader; `EffectValidator.targeting_spec` derived, no stored field |
| card-effects.md | C5 ops as data; C10 `validate_effects` injected at stage 7, closed `E_FX_*` set (TR-card-effects-005) | `effects` validator key; static pure function; stub injection in tests |
| content.md | CN-6.3 headless validate command, zero-error batches (TR-content-001) | `tools/content/validate.gd` exit contract 0 / 1 / 2 |
| heroes.md | H-1 heroes are `HeroDef` data; nothing hero-specific in code (TR-heroes-001) | HeroDef records and `hero_powers.json` effects go through the same loader and validator |
| design-decisions.md | DD-T01 JSON under `assets/data/`, snake_case, `schema_version` (TR-design-decisions-002) | The format decision itself; manifest mirrors the DD-T01 list |
| tech-debt-register.md | TD-008, TD-011, TD-004 (schema half) (TR-tech-debt-001) | Schema + cross-reference gate; mulligan counts from `config("match_rules")`; effect schema exists |

## Performance Implications
- **CPU**: one synchronous parse + ~900 O(1) checks at v1 (card-database Formulas); budget 200 ms, expected < 50 ms; queries O(1) via `index_of`; `config()` is a Dictionary lookup, called once per owner.
- **Memory**: frozen snapshot ≤ `data_memory_budget_mb` (4); `reload()` in debug briefly holds two snapshots.
- **Load Time**: adds the data load to boot (`architecture.md` Data Flow §5 step 2) ahead of the profile load; this is the one place a boot stall can originate.
- **Network**: none.

## Migration Plan
Greenfield under `src/core/data/`; nothing from `prototypes/` is ported. Order of stories: (1) `DataLoader` stages 1–6 with fixture directories under `tests/fixtures/data/`; (2) `ValidationReport` and the validate command; (3) stage 7 injection with stub validators; (4) freeze + `data_version` with the known-answer test; (5) Content MVP-0 batch loads clean. `TestConstants.SCHEMA_VERSION_CURRENT` and `DATA_LOAD_BUDGET_MS` already mirror the values.

**Rollback plan**: the format decision is DD-T01's and is not expected to roll back; the mechanics (manifest vs scan, `JSON.parse` vs `parse_string`, `HashingContext` vs a hand-rolled hash) are each local to `DataLoader` and can be swapped behind the `CardDatabase` API without touching any consumer.

## Validation Criteria
Tests under `tests/unit/card_database/` (gdUnit4, names per `test-standards.md`):
- `card_database_pipeline_test.gd`: each CR-5 error code is raised by its fixture and the pipeline continues to collect the rest; a clean fixture reaches `Ready` with an empty error list.
- `card_database_parse_error_test.gd`: a malformed fixture yields `E_PARSE` with a non-zero line (proves `JSON.parse` location on 4.7.2 — NOT SOURCEABLE item 1).
- `card_database_fingerprint_test.gd`: a committed fixture set hashes to a committed 16-hex string; key order and whitespace permutations hash equal; one changed value hashes different (NOT SOURCEABLE item 2; run on CI and on a Windows machine before Accept).
- `card_database_freeze_test.gd`: writing to a record, a nested `effects[0]` and a config body is refused after `Ready` (NOT SOURCEABLE item 3).
- `card_database_queries_test.gd`: every pool is id-ascending regardless of file order; tokens excluded from `collectible_pool`; `config("unknown")` is `null` with a logged error.
- `card_database_validators_test.gd`: a missing validator for a config file is `E_DELEGATED`; a stub that returns errors surfaces them with the owner's code.
- `card_database_load_budget_test.gd` (performance): `Unloaded → Ready` ≤ `TestConstants.DATA_LOAD_BUDGET_MS` on the real MVP data.
- Integration: `tests/integration/content/validate_command_test.gd` runs `tools/content/validate.gd` via `OS.execute` on a clean and a broken fixture root and asserts exit 0 / 1 and the printed report.
- Smoke: exported build prints `data_version()` (NOT SOURCEABLE item 4) — part of the test-rig story.
- Engine-reference gap closure: when any of items 1–4 fails on 4.7.2, this ADR is revised before Accept, not after.

## Related
- Supersedes nothing; prior art: the prototype's `data/card_data.gd` and `data/cards/*.tres` (TD-008) — not ported.
- Depends on ADR-0001 (layer map, `Boot`); enables ADR-0003, ADR-0004, ADR-0005, ADR-0007.
- `design/gdd/card-database.md`, `design/gdd/card-effects.md` (C1–C5, C10), `design/gdd/content.md` (CN-6), `design/gdd/heroes.md` (H-1), `design/design-decisions.md` (DD-T01, DD-X01, DD-X08).
- `docs/architecture/architecture.md` §Technical Requirements Baseline (TR-card-database-001..005, TR-card-effects-001/-005, TR-content-001, TR-heroes-001, TR-design-decisions-002), §Data Flow 5–6, §API Boundaries Foundation.
- `docs/tech-debt-register.md` TD-004, TD-008, TD-011.
- `.claude/rules/data-files.md`, `.claude/rules/engine-code.md`.
- Code once implemented: `src/core/data/card_database.gd`, `src/core/data/data_loader.gd`, `src/core/data/validation_report.gd`, `src/gameplay/effects/effect_validator.gd`, `tools/content/validate.gd`.
