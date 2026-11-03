# Meta Progression

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
> **Author**: Jacob (owner) + `/design-system` (guided, lean, tier standard, docs.density balanced)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 3 (lose fast, learn fast — the run log is where a loss becomes a lesson); Pillar 4 (readable, deterministic — seeds are kept and copyable); retention hooks "Curiosity" and "Investment" (game-concept.md)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` No Agent tool in this session: `systems-designer` (Sections C/D/E) and `qa-lead` (Section H) not consulted — review manually before production.
> **Engine claims**: Godot 4.7.2; `docs/engine-reference/godot/modules/` has no `core.md`, so file-system behaviour below is marked **NOT SOURCEABLE** unless cited to `breaking-changes.md`.
> **REVISED 2026-11-03** (`/design-review`, lean, revise-now): (1) M10 locked-treasure table replaced by the four ids and keys `treasures.md` T8 actually locks (`treasure_grave_tithe`, `treasure_plague_bell`, `treasure_dogeared_grimoire`, `treasure_living_armory`); counts 16 unlocked / 4 locked; F1/F5/F6 examples and AC-19–21, AC-24 rewritten on those keys. (2) M2.1 key-format rule relaxed so Treasures' milestone keys (`hero_decay_first_win` …) are valid; `unlock.<kind>_<id>` stays the default for new content. (3) M1.3 API gains `unlocked_keys()` (Treasures `pool()` contract), `is_treasure_unlocked(id)` (Reward Draft `init_run` contract), `unlock_hint()` and `last_hero_id()` (Run UI contract); M3.7, Interactions, Dependencies and Cross-References updated — Treasures and Reward Draft GDDs exist and are no longer "planned". (4) M9 settings aligned to the consumers' keys: `anim_speed` (Match UI enum) replaces the invented `action_delay_ms`; `high_contrast_states` added; `telegraph_mode` kept for Run UI with its owner marked open (Boss AI defines no player-side mode). (5) Profile `Loading` order fixed: the M6 lock check runs **before** migration and retro-grant writes.
> **REVISED 2026-11-03 (cross-review)**: C-01 (M9 settings record now matches DD-X07 exactly — `anim_speed` labels `instant|fast|normal`, `reduce_motion`, `text_scale`, `high_contrast_states`, `telegraph_mode` consumed by Boss AI per DD-X03, `action_delay_ms` consumed by Match UI, `volume_*`, `fullscreen`, `keep_run_records`; Boss AI restored as a settings dependent in Interactions, Dependencies and Cross-References; Tuning Knobs `profile_defaults` row updated), C-10 (unlock-state API confirmed on the M1.3 names `unlocked_keys()` / `is_treasure_unlocked(id)` read at `init_run` — no text change needed here; Reward Draft adopts them), C-19 (`unlock_granted` note), C-20 (toast ack timing deferred to run-ui F3), C-21 (`assets/data/profile.json` → `assets/data/profile_defaults.json` everywhere), C-30 (Open Questions on DD-X01, `bosses_defeated_16` reading, R6 `floor_reached`, rule 18 marked resolved). D-03 (one universal treasure on `runs_won ≥ 1`) is flagged, not applied — content choice, Open Questions.
> **REVISED 2026-11-03 (ux-review)**: M9 record and Tuning Knobs `profile_defaults` gain `gamma: float 0.8–1.4 (1.0)`, consumed by Match UI and Run UI (DD-X10; Interactions Match UI row and UI Requirements settings row list it); UI Requirements hero-select corner wording confirmed as wins / losses / best floor ("NW · NL · best FN", run-ui U7).
> **REVISED 2026-11-03 (housekeeping)**: M7.3, Interactions, Dependencies and Cross-References — "R6 leaves `floor_reached` unset / amendment proposed" → R6 sets it, F3 is the fallback for older records; "amends CR-3" / "CR-3 amendment (proposed)" → adopted (DD-X01); "rule 18 amendment (proposed)" → adopted (rng-event-log rule 18); UI Requirements toast row cites run-ui F3 for duration without numbers. L380 keeps both `unlock_hint` / `unlock_progress` — both are M1.3 names.

## Summary

Meta Progression is the single local profile file (`user://profile.json`) that outlives a run:
settings, the one in-progress run slot, an archive of the last 200 runs, lifetime statistics per
hero and boss, and the unlock state of every hero, treasure and bundle. For the player it is the
Continue card, the per-hero win counts, the Run Log with copyable seeds, and the "New treasure
unlocked" toast; it exists because Deckdelve's long-term progression is milestones rather than a
collection, and because losing a save is the one failure a roguelike cannot apologise for.

> **Quick reference** — Layer: `Feature` · Priority: `Vertical Slice` · Key deps: `Run Structure, Card Database, Heroes, RNG & Event Log, Treasures (contract), Reward Draft (contract)`

## Overview

Meta Progression is the one thing in Deckdelve that outlives a run: a single local **profile** file
that holds the player's settings, the in-progress run slot (DD-R08), an archive of finished runs,
lifetime statistics per hero and per boss, and the state of every **unlock**. It is the storage
owner for Run Structure's persistence contract (`save_active_run` / `load_active_run` /
`clear_active_run` / `archive_run` / `is_hero_unlocked`, run-structure.md R7) and the authority on
unlock keys that Heroes (H-7) and Card Database (`TreasureDef.unlock`) hand off to it. The player
never operates it directly; they see it as the Continue card on the main menu, the per-hero win
counts on hero select, the Run Log screen, and the "New treasure unlocked" toast after a run.
It exists because the game's long-term progression is milestones, not a collection
(anti-pillar: no pack economy): three more heroes and a handful of treasures are earned by
winning, reaching floors and beating bosses, and the run log is the player's own evidence of
getting better (retention hooks "Curiosity" and "Investment"). Framing: infrastructure first —
players feel what it enables, not the system itself. Engine-specific choices (Autoload vs.
injected service, `FileAccess` vs. `ConfigFile`) → become an ADR, not this GDD.

## Player Fantasy

Indirect. The player should feel that **the game remembers**: "I quit at floor 6 last night and
it is exactly where I left it", "that seed where Decay beat the Lamplighter is still in my log",
"I have 4 wins with War and 0 with Knowledge — time to fix that". The fantasy is the ledger of a
dungeon-delver, not the inventory of a collector: nothing accumulates except history and a few
keys. Unlocks must read as *recognition* ("you beat ten bosses, here is a treasure that was
always in the dungeon") rather than as a grind gate; the condition is shown on the locked
item with live progress so the player always knows what the next key costs. Reference feeling:
Slay the Spire's run history and per-character win counts (investment through record-keeping),
not Hearthstone's collection (acquisition). The negative fantasy to avoid: a corrupted or lost
profile — the single worst thing this system can do, which is why most of Core Rules is about
never losing the file. `creative-director` not consulted — Lean mode (and no Agent tool).

## Detailed Design

### Core Rules

Numbered rules are the contract; the partner GDDs that proposed pieces of it (run-structure R6,
R7, R9; heroes H-7; card-database CR-3 `unlock`; rng-event-log rules 17–18) are confirmed or
amended by name. All paths are under `user://`, Godot's per-user writable directory
(**NOT SOURCEABLE** against the pinned reference — no `core.md`; the path scheme itself is a
design choice and holds whatever the engine maps it to).

#### M1. One profile, one file

1. v1 has exactly one profile per OS user: `user://profile.json`, UTF-8, pretty-printed JSON
   with `schema_version` as its first key. Companion files: `user://profile.bak` (the previous
   good version), `user://profile.json.tmp` (write staging, never read), `user://profile.lock`
   (M6), `user://profile.corrupt-<unix_ts>.json` (M5), and `user://runs/<run_id>.json` (M8 full
   records). No cloud sync, no encryption, no multiple profiles; "Reset profile" is the only
   destructive action and requires a typed confirmation in Run UI.
2. Top-level shape (`PROFILE_SCHEMA_VERSION` = 1):

| Key | Type | Notes |
|---|---|---|
| `schema_version` | int | 1. Checked first; M4 migrations, M5 newer-than-game |
| `profile_id` | string | random 128-bit hex at creation; identifies the file in bug reports |
| `created_at`, `updated_at` | int (unix s, UTC) | informational; never used for ordering (Edge Cases: clock skew) |
| `write_seq` | int | +1 per successful write; diagnostics and M6 |
| `settings{}` | object | M9; unknown keys preserved, known keys clamped |
| `stats{}` | object | M7 lifetime aggregates — the unlock evaluation input; never pruned |
| `run_log[]` | ArchivedRun[] | M8; newest last; capped at `run_log_cap` |
| `unlocks{}` | `{key: {unlocked: bool, at: int\|null, by_run_id: string\|null, retro: bool}}` | M2–M3; a key absent = locked with no history |
| `pending_notifications[]` | `{key, kind, id, by_run_id}` | M3.6; drained by Run UI acks |
| `active_run` | object or null | the `RunRecord.to_dict()` blob from run-structure R7, stored verbatim and opaque |
| `data_versions_seen[]` | string[] | every Card Database `data_version` this profile was loaded under; drives retro-grants (M3.5) |

3. Persistence API (the run-structure R7 contract, **confirmed**, plus the rest of the surface).
   Every mutator persists before returning unless the profile is `ReadOnly` (States):

```
load_profile() -> {status: OK | RECOVERED_BAK | FRESH | FRESH_AFTER_CORRUPT | E_SCHEMA_NEWER | E_LOCKED, profile}
save_profile() -> OK | E_IO | E_READONLY                       # atomic write, M4
save_active_run(dict) -> OK | E_IO     load_active_run() -> dict | null     clear_active_run()
archive_run(dict) -> {ok: bool, unlocks_granted: [key]}         # M7 + M8 + M3
is_hero_unlocked(hero_id) -> bool      is_unlocked(key) -> bool      unlocked_ids(kind) -> [id]
unlocked_keys() -> Set[key]            # the set Treasures.pool(unlocked_keys, exclude_ids) takes (treasures.md T6)
is_treasure_unlocked(treasure_id) -> bool   # = TreasureDef.unlock == null or key unlocked; Reward Draft init_run
unlock_progress(key) -> {met: bool, progress: float, parts: [...]}  # F6, for the UI
unlock_hint(key_or_id) -> {text_key, progress, target}   # Run UI's name for the same read model (F6 + condition text)
set_setting(key, value) -> OK | E_RANGE     get_setting(key)     get_settings() -> dict
stats_for_hero(hero_id) -> HeroStats        last_hero_id() -> hero_id | null   # argmax stats.heroes[*].last_played_at
run_log(offset, limit) -> [ArchivedRun]     run_log_entry(run_id) -> ArchivedRun | null
pending_notifications() -> [...]            ack_notification(key)
validate_unlock_defs(defs[]) -> [error]     # the validator Card Database injects (CR-5 stage), M2.4
reset_profile(confirm_token) -> OK
```

   Name mapping for the names run-ui.md proposed in its Interactions row (this GDD's names are
   authoritative): `profile_stats()` → `stats_for_hero(id)` per hero plus the global counters of
   `get_stats()`; `list_runs(filter)` → `run_log(offset, limit)`; `get_run(run_id)` →
   `run_log_entry(run_id)`; `unlock_hint(id)` accepts a hero/treasure id as well as a key.

#### M2. Unlock definitions (data-driven)

1. Any `HeroDef`, `TreasureDef` or `BundleDef` may carry `unlock: {key, condition}` or
   `unlock: null` (always available). Card-database CR-3 carries this object shape (DD-X01,
   adopted — `TreasureDef.unlock` was once "string or null"; the string became the `key` field);
   it also **answers heroes.md's
   open question**: the hero key lives on `HeroDef.unlock`, symmetric with treasures. A key is a
   snake_case string (dots allowed), **unique across all three files** and carried by exactly one
   record. Two naming styles are in use and both are valid: heroes use `unlock.hero_<id-suffix>`
   (heroes.md H-7: `unlock.hero_fortune`), treasures use the milestone names treasures.md T8
   assigns (`hero_decay_first_win`, `hero_decay_floor_5`, `hero_knowledge_first_win`,
   `bosses_defeated_16`). New content defaults to `unlock.<kind>_<id-suffix>`; the validator
   checks uniqueness and shape, never the style.
2. **Condition grammar** (JSON; `n` ≥ 1 int; `hero` is a hero id, `"any"` (default) or
   `"each_launch"` = every hero whose own `unlock` is null):

```
condition := {"type": "always"}
           | {"type": "runs_won",           "n": N, "hero"?: HERO}        # victories; HERO scopes them
           | {"type": "boss_defeated",      "boss_id": ID | "any", "n"?: N}   # default n = 1
           | {"type": "floor_reached",      "n": N, "hero"?: HERO}        # best_floor_reached ≥ n
           | {"type": "treasure_picked",    "treasure_id": ID, "n"?: N}   # picks across all runs
           | {"type": "all_of", "of": [condition, ...]}
           | {"type": "any_of", "of": [condition, ...]}
```

   `runs_won_with_hero(h) >= n` from the brief is `runs_won` with `hero: h`; `floor_reached` with
   `hero: "each_launch"` is "floor n with every launch hero". Nesting depth ≤ `max_condition_depth`
   (3); `of` has 1–8 members.
3. Evaluation is a pure function `met(condition, stats) -> bool` over `profile.stats` (F1). It
   never reads `run_log` (which is pruned) and never reads the current run directly: `archive_run`
   first folds the record into `stats` (M7), then evaluates.
4. `validate_unlock_defs` (injected into Card Database, which calls it as one of its stage
   validators): every `key` well-formed and unique; every `hero_id`/`boss_id`/`treasure_id`
   referenced resolves in the loaded data (`E_UNLOCK_UNKNOWN_ID`, load fails — a condition no one
   can meet is a content bug, not a runtime case); depth and fan-out limits (`E_UNLOCK_SHAPE`);
   a treasure whose condition requires picking itself (`W_UNLOCK_SELF`, warning: reachable only
   by retro-grant); and `n_unlocked_default` treasures ≥ card-database `min_treasure_pool` (9)
   — Card Database already emits `W_POOL_SIZE` for that; this validator does not duplicate it.

#### M3. Granting unlocks

1. Keys are evaluated at two moments only: (a) inside `archive_run`, after M7 folds the record,
   for every key not yet unlocked; (b) inside `load_profile`, when the loaded Card Database
   `data_version` is not in `data_versions_seen[]` — a data update may add conditions the player
   already satisfies (**retro-grant**). Settings changes, resume and menu navigation never
   evaluate.
2. A key met in (a) is written `{unlocked: true, at: now, by_run_id: record.run_id, retro: false}`;
   in (b) `{..., by_run_id: null, retro: true}`.
3. **Unlocks never regress.** A key once `unlocked: true` stays true even if its condition later
   changes, its stats are clamped (M5) or the definition disappears (the entry is kept, orphaned,
   hidden from UI).
4. **Custom-seed runs count for unlocks** (`seed_source == custom`, run-structure R9) — the
   conditions are about having done the thing, and a replayed seed is still the thing done. They
   are excluded from *personal bests* only (M7.4). Rationale: Pillar 4 invites seed sharing; punishing
   it with no unlock progress would make the feature feel like a sandbox.
5. System abandons (`abandon_reason ∈ {data_version_mismatch, save_corrupt}`) fold nothing into
   `stats` except `runs_started` and `runs_void`; they cannot grant.
6. Every grant appends `{key, kind, id, by_run_id}` to `pending_notifications[]` and persists in
   the same write as the grant. Run UI drains the queue on the run summary (or on the main menu
   for retro-grants) and calls `ack_notification(key)` per toast shown. **Event**:
   `unlock_granted{key, kind: hero|treasure|bundle, id, by_run_id, retro}` is emitted on the
   profile's own signal bus (not the run log — the run log is sealed by then, rng-event-log rule
   15); the queue is the durable form, the signal the live form.
7. `is_hero_unlocked(id)` = `HeroDef.unlock == null or unlocks[key].unlocked`. Run Structure asks
   it at `new_run` only; a locked hero in `active_run` resumes (run-structure R8.4, confirmed).
   Treasure availability is read **once per run, at run start**: Reward Draft calls
   `is_treasure_unlocked(id)` (or `unlocked_keys()`) inside `init_run` (reward-draft.md,
   Run Structure R2 step 5) to build `draft_state.treasure_pool`; Treasures' `pool(unlocked_keys,
   exclude_ids)` (treasures.md T6) takes the same set. Because keys are granted only at
   `archive_run` or `load_profile` (M3.1), a grant can never change a run already in progress
   (reward-draft Edge Cases "unlocked mid-run", confirmed).

#### M4. Writing the file (atomic) and migrating it

1. Write protocol: serialise → write `profile.json.tmp` → flush and close → if `profile.json`
   exists, rename it to `profile.bak` (replacing the old `.bak`) → rename `.tmp` to
   `profile.json`. `FileAccess.store_string` returns `bool` since 4.4 (`breaking-changes.md`,
   4.3 → 4.4 Core row — **sourced**); a `false` or a non-OK `get_error()` at any step aborts
   with `E_IO`, the `.tmp` is deleted, and the previous `profile.json`/`.bak` are left as they
   were. Rename atomicity on the target OS is **NOT SOURCEABLE** here and is an ADR item.
2. Write triggers: `save_active_run` (run-structure S1–S4), `archive_run` (S5),
   `clear_active_run`, `set_setting` (debounced `settings_write_debounce_ms`, 500, so a volume
   slider does not write per tick), `ack_notification`, `reset_profile`. One `E_IO` is retried
   once after `io_retry_ms` (250) before being returned (brief: "retry once, then log"); the
   caller decides what to tell the player (Run Structure shows `run_warning{save_failed}`).
3. The write must complete within `max_save_ms` (50) at `run_log_cap` records (F5); a save is
   synchronous on the main thread in v1 and never shows a spinner — if F5 cannot hold the budget,
   the cap drops, not the UX.
4. **Migrations**: `load_profile` reads `schema_version` first. `< PROFILE_SCHEMA_VERSION` →
   apply `migrate_v{k}_to_v{k+1}` in sequence, each a pure dict → dict function with its own
   unit test, then write once (the pre-migration file becomes `.bak`). Worked example, the first
   real migration: *v1 → v2 adds `stats.heroes[*].best_turns_victory`*; the migration sets it to
   the minimum `totals.turns` over that hero's victories in `run_log` (random seeds only) or
   `null`, and sets `schema_version = 2`. Run-structure's `RUN_RECORD_SCHEMA_VERSION` and
   rng-event-log's `log_schema_version` inside `active_run` and `run_log[]` entries migrate here
   too (**confirmed**: this GDD owns both migrations); an entry whose `log_schema_version` is
   newer than the game's is kept opaque, per rng-event-log Edge Cases.

#### M5. Loading, validation and corruption

1. Load order: `profile.json` → if missing or unparseable or `schema_version` missing →
   `profile.bak` → if that also fails → fresh profile (`FRESH` if neither file existed,
   `FRESH_AFTER_CORRUPT` otherwise). A file that parsed but failed is first copied to
   `profile.corrupt-<unix_ts>.json` (the `.bak` to `profile.bak.corrupt-<ts>.json`), never
   deleted, and the player is told once: "Your profile could not be read; a copy was kept."
2. `schema_version > PROFILE_SCHEMA_VERSION` → `E_SCHEMA_NEWER`: the file is not touched, not
   backed up over, not migrated; the game runs on an in-memory fresh profile in `ReadOnly` with
   the banner "This profile was saved by a newer version of Deckdelve. Progress will not be
   saved." Rationale: a downgrade must never destroy the newer profile.
3. **Tamper tolerance** (single-player; no anti-cheat — `/security-audit` later covers save
   tampering as a *robustness* topic only): every known field is type-checked; a wrong type is
   replaced by its default; numbers are clamped (counts to `0..999999`, floors to
   `0..max_floor_clamp` (12 = the top of run-structure's `floors_per_run` range), durations to
   `0..10^8`, volumes to `0..1`); unknown keys are preserved verbatim (forward compatibility);
   each repair is logged `profile_repaired{path, from, to}` to the console and counted in
   `load.repairs`. A profile with > `max_repairs_before_rebuild` (25) repairs has its `stats`
   **rebuilt from `run_log`** (M7.5) and the result is flagged `stats.rebuilt_at`.
4. `active_run` is **not** validated here beyond "object or null": `RunRecord.validate()` is Run
   Structure's (R8), and its verdicts (`E_SCHEMA`, `E_DATA_VERSION`, `E_CORRUPT`,
   `E_UNKNOWN_ID`) come back to this system as an `archive_run` of a system-abandoned record
   followed by `clear_active_run` — exactly R8.1, confirmed.

#### M6. Two instances

1. On `load_profile` the game writes `profile.lock = {instance_id, pid, heartbeat_at}` and
   refreshes `heartbeat_at` every `lock_heartbeat_s` (30). A second instance that finds a lock
   whose heartbeat is younger than `lock_stale_s` (90) loads the profile **`ReadOnly`**
   (`E_LOCKED`): it can play, but every mutator returns `E_READONLY` (Run Structure sees it as
   `E_IO`), and a persistent banner says "Another copy of the game is open; this session will not
   be saved." A stale lock is taken over (crash recovery). The lock is deleted on clean exit.
2. Chosen over last-writer-wins because the alternative silently loses one instance's run; the
   banner is honest and cheap. The 90 s window is the one cost: after a crash the next launch
   within 90 s is read-only — acceptable, and the banner offers "Retry" which re-checks the lock.

#### M7. Statistics (folded at `archive_run`)

1. `stats` shape: `{runs_started, runs_won, runs_lost, runs_void, total_turns, total_play_seconds,
   heroes{hero_id: HeroStats}, bosses{boss_id: {defeated, defeated_by}}, treasures{treasure_id:
   {picked, offered}}, bests{...}}`; `HeroStats = {runs_started, runs_won, runs_lost,
   best_floor_reached, fastest_victory_s, fewest_turns_victory, last_played_at}`.
2. Fold rules (F2) per archived record: `runs_started` +1 always; outcome `victory` → `runs_won`
   +1 (global and hero); `defeat` → `runs_lost` +1; `abandoned/player` → `runs_lost` +1
   (**confirmed**: run-structure R6 `abandon_counts_as_loss`, read from Run Structure's knob,
   not duplicated); `abandoned/<system>` → `runs_void` +1 and nothing else. Each
   `match_summary` with `result == player` → `bosses[boss_id].defeated` +1; the `ended_by` boss
   → `defeated_by` +1. Each `drafts[]` entry of kind `treasure` → `treasures[picked_id].picked` +1
   and `offered` +1 for each `offered_ids[]`.
3. `floor_reached` for conditions and bests: `result.floor_reached` on defeat/abandon;
   `floors_per_run` of that record on victory (run-structure R6 sets
   `floor_reached = floors_per_run` on victory; F3 is the fallback for older records).
4. **Personal bests** (`fastest_victory_s`, `fewest_turns_victory`, global `bests`) update only
   when `seed_source == random` (run-structure R9, **confirmed**); `best_floor_reached` and all
   counts update for every non-void run. A custom-seed victory is shown in the run log with a
   "custom seed" tag and excluded from the bests line.
5. `rebuild_stats()` recomputes every counter by folding `run_log[]` from empty; because the log
   is capped it can only *under*-count lifetime totals, so it is used for repair (M5.3) and
   tests, never routinely, and the rebuilt profile keeps `max(old, rebuilt)` for monotone
   counters and the rebuilt value for bests.

#### M8. The run archive

1. `archive_run(record)` stores an **ArchivedRun** — the R1 record minus the heavy or opaque
   fields: drop `run_log`, `rng_snapshot`, `draft_state`, `treasure_state`; truncate each
   `match_summaries[i].damage_by_card` to its top `archive_top_cards` (10) entries plus
   `_others: int`; keep `totals.damage_by_card` whole (≤ 36 keys). Everything else (`run_id`,
   seed fields, `hero_id`, `boss_sequence`, `deck`, `treasures`, `drafts`, `match_attempts`,
   timestamps, `play_seconds`, `result`, `totals`, `schema_version`, `data_version`) is kept
   verbatim. Appended newest-last; when `len(run_log) > run_log_cap` (200) the oldest entries by
   **array position** are removed (F4). Pruning never touches `stats` or `unlocks`.
2. When `keep_run_records` (settings, default true) is set, the **full** record (`run_log`
   included) is written to `user://runs/<run_id>.json` before the profile write — the replay and
   bug-report input (rng-event-log rule 17). This also answers run-structure's open question on
   rng-event-log rule 18's `<run_seed_hex>` key: archives are keyed by `run_id`
   (`<run_seed_hex>-<started_at>`), so a replayed seed never overwrites. These files are not
   capped by this system; a "Clear run records" button in settings deletes the folder.
3. `archive_run` is idempotent on `run_id`: a second call with an already-archived `run_id`
   returns `{ok: true, unlocks_granted: []}` and changes nothing (guards the "run ended during
   save, retried" path).

#### M9. Settings

The record is exactly the DD-X07 key set (owned here; Run UI edits it; Match UI and Boss AI read
it): `settings = {volume_master, volume_music, volume_sfx: float 0..1 (1.0, 0.8, 1.0); fullscreen:
bool (false); anim_speed: "instant" | "fast" | "normal" ("normal") — DD-X07; Match UI and Run UI
map the label to their own durations (match-ui F3, run-ui F2); reduce_motion: bool (false) —
Match UI drops shake, hit-stop and lethal slow-down (match-ui Tuning Knobs); text_scale: 1.0 |
1.25 | 1.5 (1.0) — Run UI and Match UI typography (ui-code rule 7); high_contrast_states: bool
(false) — art bible §4 alternate state set; telegraph_mode: "full" | "brief" | "off" ("full") —
consumed by Boss AI as effective_mode = min(boss.intent_mode, telegraph_mode) (DD-X03);
action_delay_ms: int 0..2000 (600) — Match UI boss-turn pacing override of Boss AI's
presentation.action_delay_s (DD-X07, match-ui F4); gamma: float 0.8..1.4 (1.0) — brightness,
consumed by Match UI and Run UI as a CanvasModulate adjustment (DD-X10; added 2026-11-03 to the
DD-X07 key set); keep_run_records: bool (true); language: "en"; bindings: {action: [InputEvent as
Dictionary]} ({} = engine defaults) — key bindings per `InputMap` action, applied by Boot after the
profile loads, `cancel`/Esc never rebindable, absent in `profile_defaults.json` (DD-X07; ADR-0004
decision addendum 2026-11-03; accessibility-requirements Motor, Alpha)}`. An out-of-range `gamma` is
clamped to 0.8..1.4 on load (M5.3 treats it like an enum default).
Defaults live in `assets/data/profile_defaults.json` (DD-T01 data file `profile_defaults`,
served by `config("profile_defaults")`; renamed from `profile.json` on 2026-11-03, cross-review
C-21, so it no longer shares a basename with `user://profile.json`), not in code. An unknown
value for an enum key is replaced by the default (M5.3). Settings are applied by their owning
systems on change via `settings_changed{key, value}`; this system only stores them.

#### M10. v1 unlock content

- **Launch heroes** War, Decay, Knowledge: `unlock: null` (heroes H-2). **MVP** (DD-H06): every
  treasure `unlock: null`; this system runs with an empty unlock table and `is_hero_unlocked`
  is trivially true, so MVP needs only M1, M4, M5, M8 and M9.
- **Vertical Slice / Alpha**: 4 of the 20 treasures locked, 16 default-unlocked (≥ 9,
  card-database `min_treasure_pool`; treasures.md T8 counts). The ids and keys are the ones
  treasures.md T8 names (its R-14 asks this GDD to define them — **defined here**); the
  conditions are this GDD's, expressed in the M2.2 grammar:

| Treasure (treasures.md T8) | Key | Condition | Milestone it rewards |
|---|---|---|---|
| `treasure_grave_tithe` (#13, Rare, decay) | `hero_decay_first_win` | `runs_won ≥ 1, hero: hero_decay` | First victory with Decay |
| `treasure_plague_bell` (#15, Common, decay) | `hero_decay_floor_5` | `floor_reached ≥ 5, hero: hero_decay` | Fought the floor-5 boss with Decay (F3: cleared four) |
| `treasure_dogeared_grimoire` (#17, Rare, knowledge) | `hero_knowledge_first_win` | `runs_won ≥ 1, hero: hero_knowledge` | First victory with Knowledge |
| `treasure_living_armory` (#18, Rare, universal) | `bosses_defeated_16` | `boss_defeated(any) ≥ 16` | Sixteen bosses down — the size of the boss pool (DD-R02), ≈ 2 full victories or 4–6 runs. Read as a cumulative count, not "every boss once": `all_of` fan-out is 8 (M2.2), so the 16-distinct form is inexpressible; Treasures to confirm the reading (Open Questions) |

  Milestones from the earlier draft that no treasure currently rewards — first victory with any
  hero, ten bosses down, floor 5 with every launch hero, a win with every launch hero (the
  concept's "done" line) — remain the content brief for any further locks Treasures/Content add;
  the grammar already expresses each (`hero: "each_launch"`, `all_of`). `unlock.hero_fortune`
  below covers "first victory with any hero" for the Curiosity hook until then.

- **Post-v1 heroes** (DD-H02, data only; conditions from heroes H-7 sketches, **confirmed**):
  `unlock.hero_fortune` = `runs_won ≥ 1`; `unlock.hero_order` = `runs_won(hero_war) ≥ 1`;
  `unlock.hero_shadow` = `any_of[ runs_won(hero_decay) ≥ 1, runs_won(hero_knowledge) ≥ 1 ]`.
  Bundles: no locked bundles in v1 (the grammar supports them; Reward Draft would filter).

### States and Transitions

Three small machines: the profile session, each unlock key, and each notification.

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| **Profile: Unloaded** | App start | `load_profile()` called | No API answers; Run UI shows a loading frame (should be one frame) |
| **Profile: Loading** | `load_profile()` | Lock check, load, backup fallback, migration and retro-grant complete | **M6 (lock) → M5 → M4.4 → M3.1(b)**, in that order: the lock is taken (or `E_LOCKED` decided) before anything that writes, so a second instance never migrates, backs up or retro-grants a file another instance owns; under `ReadOnly` M4.4 migrates and M3.1(b) grants in memory only. A failure at any step routes to `Ready` (fresh) or `ReadOnly` |
| **Profile: Ready** | Load status `OK`, `RECOVERED_BAK`, `FRESH`, `FRESH_AFTER_CORRUPT` | `reset_profile()` (→ Loading on a fresh file) or app exit | All mutators persist; heartbeat running; `RECOVERED_BAK` and `FRESH_AFTER_CORRUPT` show their one-time message first |
| **Profile: ReadOnly** | `E_LOCKED` (M6) or `E_SCHEMA_NEWER` (M5.2) | "Retry" finds the lock stale (→ Loading) or app exit; `E_SCHEMA_NEWER` never exits | In-memory profile behaves normally; every write returns `E_READONLY`; banner persistent; `active_run` may be played but not saved |
| **Write: Idle** | `Ready` | A mutator called | — |
| **Write: Staging** | Mutator called | `.tmp` written and closed, or `E_IO` | On `E_IO`: delete `.tmp`, wait `io_retry_ms`, retry once; second failure → return `E_IO`, state back to Idle, profile unchanged on disk |
| **Write: Committing** | `.tmp` complete | Renames done | `profile.json → .bak`, `.tmp → profile.json`; `write_seq` +1 in memory only after success |
| **Unlock key: Locked** | Key defined in data, absent or `unlocked: false` in `unlocks{}` | `met(condition, stats)` true at an M3.1 evaluation point | `unlock_progress(key)` reports progress; the item is greyed with its condition text |
| **Unlock key: Unlocked** | M3.2 written | Never (M3.3) | Item available; `at`/`by_run_id` shown in the run log entry that earned it |
| **Unlock key: Orphaned** | `unlocked: true` but no definition carries the key in the loaded data | Data defines the key again (→ Unlocked) | Hidden from UI; kept in the file |
| **Notification: Pending** | Grant appended to `pending_notifications[]` | `ack_notification(key)` | Survives crash; Run UI shows the toast on the next summary or menu |
| **Notification: Acked** | Ack persisted | — | Removed from the queue |

Transition order inside `archive_run` (one write at the end): idempotency check (M8.3) →
write `user://runs/<run_id>.json` if enabled (M8.2) → fold stats (M7) → append ArchivedRun and
prune (M8.1) → evaluate locked keys and queue notifications (M3) → `clear_active_run` is a
separate call by Run Structure (R6), so a crash between the two leaves an archived run *and* an
active slot: on next load, `load_active_run()` returns a record whose `run_id` is already in
`run_log[]` → the slot is cleared silently (Edge Cases).

### Interactions with Other Systems

| System | Direction | Data in (to Meta) | Data out (from Meta) | Interface owner |
|---|---|---|---|---|
| **Run Structure** | mutual | `RunRecord` dicts at S1–S5; `archive_run(record)`; `seed_source`, `abandon_reason`, `result`, `match_summaries`, `drafts` read from the record | `save_active_run` result codes; `load_active_run()` blob; `is_hero_unlocked(id)`; `abandon_counts_as_loss` read from `run_structure.json` | Run Structure owns the record schema (R1) and `validate()`; this GDD owns storage, archive shape (M8.1), stats and unlocks — **all R7/R9 contract points confirmed above** |
| **Heroes** | upstream (data) | `HeroDef.unlock {key, condition}`; hero ids | `is_hero_unlocked`; `stats_for_hero` for hero select | Heroes owns which heroes exist and their identity; this GDD owns keys, grammar, evaluation (answers heroes OQ: `HeroDef.unlock`) |
| **Card Database** | upstream | `heroes()`, `treasure_pool()`, `bundle_pool()` with `unlock` fields; `data_version`; `boss(id)`/`has(id)` for the validator | `validate_unlock_defs` (injected validator, CR-5 stage) | Card Database owns schemas and load; this GDD owns the `unlock` object shape (adopted in CR-3, DD-X01) and the validator's rules |
| **Treasures** | downstream | treasure ids picked/offered (via the record's `drafts[]`); the four keys T8 names | `unlocked_keys()` for `pool(unlocked_keys, exclude_ids)` (T6); `treasures[id].picked` for display | **Confirmed against treasures.md** (T1 `unlock`, T6, T8, R-14): Treasures names the keys, this GDD defines their conditions (M10). The grant event is `unlock_granted` (M3.6, also Run UI's); treasures.md's States row renames its `unlock_earned` to it (cross-review C-19) |
| **Reward Draft** | downstream | — | `is_treasure_unlocked(id)` / `unlocked_keys()` at `init_run` (run start), building `draft_state.treasure_pool` once; `unlocked_ids("bundle")` likewise when bundles lock | **Confirmed against reward-draft.md** (Interactions, Dependencies, AC-27): read at `init_run` only, before any seeded draw, so a locked treasure never consumes a draw and a mid-run grant is invisible to the running run |
| **RNG & Event Log** | upstream (format) | Sealed run log inside the record (`to_json()`, rule 17), `log_schema_version` | Nothing at runtime; `user://runs/` files for the replay viewer and `/balance-check` | RNG & Event Log owns the log format; this GDD owns `log_schema_version` migration and the archive key `run_id` (rng-event-log rule 18, adopted) |
| **Boss AI** | downstream (setting) | — | Soft: reads `settings.telegraph_mode` via `settings_changed` and clamps its per-boss `intent_mode` to it (DD-X03, boss-ai C8.4 `effective_mode`) | Boss AI owns `effective_mode` and what `ai_intent_*` carries; this GDD only stores the setting (default `full`) |
| **Match UI** | indirect | — | `settings.anim_speed` (label set per DD-X07), `reduce_motion`, `text_scale`, `high_contrast_states`, `action_delay_ms`, `gamma` (DD-X10), volumes via `settings_changed` (match-ui.md Interactions, Dependencies) | Match UI owns the label → duration mapping (F3) and pacing (F4); this GDD only stores the value |
| **Run UI** | downstream | Commands: `set_setting`, `ack_notification`, `reset_profile`, "Clear run records", "Copy seed" | Read models: Continue card (`active_run` header fields), hero stats, `last_hero_id`, run log pages, `unlock_hint` / `unlock_progress`, `pending_notifications` + `unlock_granted`, load-status messages, ReadOnly banner | This GDD; UI is display-only (`src/ui/**`). run-ui.md's proposed names map per M1.3; its `anim_speed` labels `instant\|fast\|normal` are the stored values (DD-X07) |
| **Content** | soft | Authors `unlock` objects in `treasures.json`/`heroes.json`/`bundles.json` | Validator errors at load | Content owns which items are locked and their milestones; this GDD owns the grammar |

## Formulas

`systems-designer` not consulted — Lean mode (no Agent tool). All numbers below are data-file
values in `assets/data/profile_defaults.json` unless marked constant.

### F1. Unlock condition evaluation

The `met` formula is defined as:

```
met(c, S) =
  always            : true
  runs_won          : wins(S, c.hero) ≥ c.n
  boss_defeated     : (c.boss_id == "any" ? Σ_b S.bosses[b].defeated : S.bosses[c.boss_id].defeated) ≥ n
  floor_reached     : best(S, c.hero) ≥ c.n
  treasure_picked   : S.treasures[c.treasure_id].picked ≥ n
  all_of            : ∀ x ∈ c.of : met(x, S)
  any_of            : ∃ x ∈ c.of : met(x, S)
where wins(S, "any") = S.runs_won;  wins(S, h) = S.heroes[h].runs_won;
      wins(S, "each_launch") = min over launch heroes h of S.heroes[h].runs_won  (≥ n ⇔ each ≥ n)
      best(S, ·) likewise over best_floor_reached;  a missing map entry reads as 0;  n defaults to 1
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| c | Condition | grammar M2.2, depth ≤ 3 | data file (`unlock.condition`) | The condition node being evaluated |
| S | Stats | M7.1 shape | calculated (profile) | Lifetime aggregates after the current fold |
| c.n | int | 1 – 999 | data file | Threshold; `max_condition_n` caps authoring at 999 |
| launch heroes | set | 3 in v1 | calculated | Heroes whose own `unlock` is null |

**Output Range:** boolean; monotone in S (every counter only grows, so a met condition stays
met — the basis of M3.3). **Example:** `unlock.hero_shadow` = `any_of[ runs_won(hero_decay) ≥ 1,
runs_won(hero_knowledge) ≥ 1 ]` with `S.heroes = {war: 2 wins, decay: 0, knowledge: 0}` →
false ∨ false = **false**; after one Knowledge win → **true**, granted with that run's `run_id`
(and `hero_knowledge_first_win` is granted in the same `archive_run`).

### F2. Statistics fold

The `fold` formula is defined as:

```
fold(S, R):
  S.runs_started += 1;  H = S.heroes[R.hero_id];  H.runs_started += 1;  H.last_played_at = R.ended_at
  outcome = R.result.outcome;  reason = R.result.abandon_reason
  if outcome == victory:                          S.runs_won += 1;  H.runs_won += 1
  elif outcome == defeat or (outcome == abandoned and reason == player and abandon_counts_as_loss):
                                                  S.runs_lost += 1; H.runs_lost += 1
  elif outcome == abandoned:                      S.runs_void += 1; return S        # system abandon: stop here
  S.total_turns += R.totals.turns;  S.total_play_seconds += R.play_seconds
  H.best_floor_reached = max(H.best_floor_reached, floor_reached(R))               # F3
  for m in R.match_summaries: if m.result == player: S.bosses[m.boss_id].defeated += 1
  if R.result.ended_by: S.bosses[R.result.ended_by].defeated_by += 1
  for d in R.drafts where d.kind == treasure: S.treasures[d.picked_id].picked += 1; for o in d.offered_ids: S.treasures[o].offered += 1
  if outcome == victory and R.seed_source == random:
      H.fastest_victory_s = min(H.fastest_victory_s ?? ∞, R.play_seconds)
      H.fewest_turns_victory = min(H.fewest_turns_victory ?? ∞, R.totals.turns)
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| R | RunRecord | run-structure R1 | Run Structure | The record passed to `archive_run` |
| abandon_counts_as_loss | bool | true/false | data file (`run_structure.json`, Run Structure's knob) | Whether `abandoned/player` is a loss (default true) |
| R.seed_source | enum | random / custom | Run Structure | Personal-best gate (M7.4) |
| counters | int | 0 – 999999 | calculated | Clamped on load (M5.3) |

**Output Range:** every counter non-decreasing; bests non-increasing. **Example:** a Decay
defeat on floor 4 after 3 wins: `runs_started 1, runs_lost 1, bosses[b1..b3].defeated +1,
bosses[b4].defeated_by +1, best_floor_reached = max(prev, 4)`; no best times touched.

### F3. Floor reached

The `floor_reached` formula is defined as:

```
floor_reached(R) = R.floors_per_run                     if R.result.outcome == victory
                 = R.result.floor_reached               otherwise  (= R.result.floors_cleared + 1)
```

**Variables:** `R.floors_per_run` int 3–12 (copied into the record at run start, R1);
`R.result.floor_reached` int 1–`floors_per_run` (Run Structure). **Output Range:** 1 – 12.
**Example:** victory on an 8-floor run → 8; defeat on floor 5 → 5. A `floor_reached ≥ 5`
condition is therefore "fought the floor-5 boss", i.e. cleared four.

### F4. Run log cap and pruning

The `prune` formula is defined as:

```
run_log' = run_log[ max(0, len(run_log) − run_log_cap) : ]      # drop oldest by array position
```

**Variables:** `run_log_cap` int 20–1000, data file (default 200). **Output Range:**
`len(run_log') ≤ run_log_cap`; stats and unlocks unaffected. **Example:** 201 entries, cap 200
→ the entry at index 0 is dropped; its `user://runs/<run_id>.json` (if any) is not.

### F5. Profile size and save budget

The `profile_bytes` formula is defined as:

```
archived_run_bytes ≈ header_bytes + deck_size × id_bytes + n_drafts × draft_bytes + n_matches × (summary_base + archive_top_cards × entry_bytes) + totals_bytes
profile_bytes      ≈ base_bytes + run_log_cap × archived_run_bytes + n_unlock_keys × unlock_entry_bytes
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| header_bytes | int | ~600 | constant (estimate) | ids, seeds, timestamps, result, boss_sequence (8 ids) |
| deck_size, id_bytes | int | 36, ~28 | run-structure F4; constant | 36 ids × `"war_whetstone_blade",` (the longest v1 id, `treasure_quartermasters_ledger`, is 33 bytes quoted) |
| n_drafts, draft_bytes | int | 10, ~160 | DD-R04/R05; constant | 7 bundle + 3 treasure DraftRecords |
| n_matches, summary_base | int | 8, ~180 | DD-R01; constant | one summary per floor |
| archive_top_cards, entry_bytes | int | 10 (5–36), ~32 | data file; constant | truncated `damage_by_card` |
| totals_bytes | int | ~1,300 | constant | full `damage_by_card` (≤ 36 keys) + scalars |
| base_bytes, unlock_entry_bytes | int | ~2,000; ~110 | constant | settings, stats (3 heroes, 16 bosses, 20 treasures), one unlock row |
| max_profile_bytes | int | 1–8 MB | data file (2,097,152) | Load-time warning threshold |

**Output Range:** `archived_run_bytes ≈ 600 + 1,008 + 1,600 + 8 × (180 + 320) + 1,300 ≈ 8.5 KB`;
`profile_bytes ≈ 2,000 + 200 × 8,500 + 30 × 110 ≈ 1.7 MB < 2 MB` at defaults. Pretty-printing
adds ~15 %; if measured size exceeds `max_profile_bytes`, the loader logs `W_PROFILE_SIZE` and
the knob owner lowers `run_log_cap` or `archive_top_cards` — never silently. **Example:** cap
100 → ≈ 0.85 MB; `archive_top_cards` 36 → ≈ 15 KB per run, 3 MB at cap 200 (over budget).
`max_save_ms` (50) is the paired budget: a 2 MB serialise-and-write must fit it on the minimum
spec; measured at Vertical Slice (Open Questions).

### F6. Unlock progress (display only)

The `progress` formula is defined as:

```
progress(c, S) = min(1, current(c, S) / c.n)         for leaf conditions (always → 1)
               = mean over c.of of progress(x, S)    for all_of
               = max  over c.of of progress(x, S)    for any_of
```

**Variables:** `current` = the left-hand quantity of F1's comparison (for `each_launch`, the
minimum across launch heroes); `c.n` as F1. **Output Range:** 0.0 – 1.0; `progress == 1 ⇔
met` for leaves and `any_of`, and for `all_of` by construction (mean of 1s). **Example:**
`bosses_defeated_16` with 8 bosses defeated → 0.5, shown as "8 / 16 bosses defeated".

### F7. Lock staleness

The `lock_is_live` formula is defined as:

```
lock_is_live = (now − lock.heartbeat_at) < lock_stale_s
```

**Variables:** `lock_stale_s` int 60–600, data file (90); `lock_heartbeat_s` int 10–120, data
file (30); constraint `lock_stale_s ≥ 2 × lock_heartbeat_s`. **Output Range:** boolean; a
crashed instance's lock expires after ≤ 90 s. **Example:** heartbeat 40 s ago → live →
`ReadOnly`; 100 s ago → stale → taken over.

## Edge Cases

`systems-designer` not consulted — Lean mode (no Agent tool).

**Files and the OS**

- **If two game instances run at once**: the second finds a live lock (F7) and loads `ReadOnly`
  with the banner; its `save_active_run` returns `E_READONLY`, which Run Structure treats as
  `E_IO` (`run_warning{save_failed}`). No last-writer-wins: one instance owns the file.
- **If the lock is stale** (crash, power loss): taken over silently; a console line records the
  previous `instance_id`.
- **If `profile.json` has `schema_version` newer than the game**: `E_SCHEMA_NEWER`; the file is
  never read further, written, renamed or backed up over; `ReadOnly` with the "newer version"
  banner. Rationale: a downgrade must not destroy progress made on the newer build.
- **If `profile.json` is missing but `profile.bak` exists**: load `.bak` as `RECOVERED_BAK`, tell
  the player "restored from backup; the last save may be missing", write it as `profile.json`
  on the next mutation.
- **If both files are unparseable**: each is copied to `profile.corrupt-<ts>.json` /
  `profile.bak.corrupt-<ts>.json`; a fresh profile starts (`FRESH_AFTER_CORRUPT`); the player is
  told once that a copy was kept. Nothing is deleted.
- **If the disk is full during a save**: the `.tmp` write fails (`store_string == false` or
  `get_error() != OK`), `.tmp` is deleted, one retry after `io_retry_ms`, then `E_IO`. The
  on-disk `profile.json` is untouched; the in-memory profile keeps the change and the next
  mutator retries the whole write.
- **If the profile is deleted while the game runs**: the in-memory profile is authoritative; the
  next write recreates `profile.json` (there is no `.bak` to rotate, which is fine). A console
  warning notes the missing file.
- **If the run ends during a save** (`archive_run` arrives while a `save_active_run` write is
  in `Staging`): writes are serialised on the main thread, so the second call waits; if the first
  returns `E_IO` the second still runs (its own retry) — the archive is the write that matters.
- **If `archive_run` is called twice for one `run_id`** (crash after the archive write, before
  `clear_active_run`; or Run Structure's own retry): M8.3 idempotency — no second fold, no
  second notification.
- **If `active_run.run_id` is already in `run_log[]` at load**: the slot is cleared silently;
  it is the half-finished S5 above, not a resumable run.
- **If `user://runs/` cannot be written** (`keep_run_records` on, disk full): the profile write
  still proceeds; `run_warning{run_record_not_kept}` is logged, not shown.

**Versions and data**

- **If `active_run` carries an older `data_version`** than the installed data: this system
  returns it unchanged from `load_active_run()`; Run Structure's `validate()` returns
  `E_DATA_VERSION`, archives it `abandoned / data_version_mismatch` and clears the slot (R8.1).
  Here that archive folds as **void** (F2) — not a loss — and grants nothing.
- **If an unlock condition references a missing boss, hero or treasure id**: Card Database load
  fails with `E_UNLOCK_UNKNOWN_ID` from the injected validator; it never reaches runtime. A
  key that disappears from data while `unlocked: true` becomes Orphaned (kept, hidden).
- **If a data update adds or loosens a condition the player already satisfies**: the new
  `data_version` is not in `data_versions_seen[]` → every locked key is re-evaluated at load;
  grants are written `retro: true, by_run_id: null` and queued, so the main menu shows the toast.
- **If a data update tightens a condition already met**: no change (M3.3, unlocks never regress).
- **If a profile's `run_log[]` entries carry an older `log_schema_version` or
  `RUN_RECORD_SCHEMA_VERSION`**: migrated in M4.4 before anything reads them; a newer one is kept
  opaque and the run log row shows "details unavailable" (rng-event-log Edge Cases, confirmed).
- **If `floors_per_run` differs between archived runs** (config changed between versions): every
  record carries its own `floors_per_run` (R1), so F3 and `best_floor_reached` compare raw floor
  numbers; the run log shows "n of F" per row, and the hero-select best shows the raw number.

**Statistics and unlocks**

- **If a counter is impossible on load** (negative, > 999999, `runs_won > runs_started`,
  `best_floor_reached > max_floor_clamp`): clamped to its range (and `runs_started` raised to
  `runs_won + runs_lost + runs_void` if lower), each repair logged; above
  `max_repairs_before_rebuild` repairs the stats are rebuilt from `run_log` (M7.5). Nothing is
  re-locked.
- **If `unlocks{}` says `unlocked: true` for a key whose condition is unmet** (edited file):
  honoured. Single-player; the file is the player's.
- **If a hero is locked while `active_run` uses it** (profile edited, data changed): resume
  proceeds; Run Structure logs `run_warning{hero_locked_at_resume}` (R8.4). The lock gates
  `new_run` only.
- **If the only runs are custom-seed**: counts, `best_floor_reached` and unlocks accrue;
  `fastest_victory_s` / `fewest_turns_victory` stay `null` and the bests line reads "— (random
  seeds only)".
- **If `abandon_counts_as_loss` is false** (Run Structure knob): `abandoned/player` folds as
  **void**; the run log row still shows "Abandoned".
- **If a run record has zero `match_summaries`** (abandoned at S1 before any match): folds as a
  started + lost (or void) run with `best_floor_reached = max(prev, 1)` and no boss counts.
- **If the system clock moves backwards** (`ended_at < started_at`, or `at` earlier than the
  previous grant): nothing orders by timestamps — the run log orders by array position, pruning
  by position, bests by `play_seconds` (monotonic ticks, R1). Negative displayed durations show
  "—". `created_at > updated_at` is left as-is.
- **If `run_log_cap` is lowered in data below the current length**: the next `archive_run`
  prunes to the new cap in one step; stats are unaffected.
- **If `pending_notifications[]` holds a key no longer in data**: dropped on load with a console
  line (there is nothing to show).

## Dependencies

Hard = this system cannot do its job without it; soft = it degrades to a default. **Bidirectional
check** against `design/gdd/systems-index.md`: the index lists Meta Progression as depending on
Run Structure, Heroes, Treasures, Card Database and RNG & Event Log (all below) and lists Run UI
as depending on it (below). Run Structure, Heroes, Card Database and RNG & Event Log each already
name Meta Progression in their Dependencies — consistent. This table adds **Reward Draft, Boss
AI, Match UI** as dependents (settings and pool filter) — flagged for `/map-systems`, not edited
here (cross-review C-01 adds Meta Progression to the index's Boss AI row). Treasures and Reward Draft are Designed (treasures.md, reward-draft.md); both name Meta
Progression as a contract and their rows below are confirmed against those files.

| System | Direction | Hard/Soft | Nature of dependency / interface |
|---|---|---|---|
| Run Structure | Mutual | Hard | In: `RunRecord` at S1–S5, `archive_run`; reads `seed_source`, `result`, `match_summaries`, `drafts`, `floors_per_run`, `play_seconds`, and the `abandon_counts_as_loss` knob. Out: `save_active_run`/`load_active_run`/`clear_active_run` codes, `is_hero_unlocked`. Confirms R6 (abandon = loss), R7 (API), R8.4 (locked hero resumes), R9 (custom seeds: no bests, yes unlocks); R6 sets `floor_reached` on victory (F3 is the fallback for older records). |
| Card Database | This depends on Card Database | Hard | `unlock {key, condition}` on hero/treasure/bundle records (CR-3, DD-X01); `data_version` for retro-grants; `has(id)` for the validator; supplies `validate_unlock_defs` to it. |
| Heroes | This depends on Heroes (data) | Soft | Hero ids for `stats.heroes{}`; `HeroDef.unlock` for Fortune/Order/Shadow (null at MVP → trivially unlocked). Answers heroes.md OQ: the key lives on `HeroDef.unlock`. |
| RNG & Event Log | This depends on RNG & Event Log (format) | Soft | Sealed run log and `match_summary` shapes inside the record; `log_schema_version` migrated here; `user://runs/<run_id>.json` keyed by `run_id` (rng-event-log rule 18). Works without logs (unlocks and counts only). |
| Treasures | Mutual | Soft | In: the four locked ids and their keys (T8); Out: `unlocked_keys()` for `pool()`, `stats.treasures{}` for display. **Confirmed** against treasures.md T1/T6/T8/R-14 (conditions in M10). |
| Reward Draft | Reward Draft depends on this | Soft (MVP: everything unlocked) | `is_treasure_unlocked(id)` / `unlocked_keys()` read once at `init_run`, before any seeded draw; locked ids never consume a draw. **Confirmed** against reward-draft.md Interactions / AC-27. |
| Match UI | Match UI depends on this | Soft | `settings.anim_speed` (label set per DD-X07), `reduce_motion`, `text_scale`, `high_contrast_states`, `action_delay_ms`, volumes (match-ui.md Interactions); session-local defaults until this system exists (MVP). |
| Run UI | Run UI depends on this | Hard (for them) | Continue card, hero stats, Run Log screen, unlock progress and toasts, settings screen, load-status and ReadOnly messages; commands `set_setting`, `ack_notification`, `reset_profile`. |
| Boss AI | Boss AI depends on this (setting) | Soft | Reads `settings.telegraph_mode` via `settings_changed` and clamps its per-boss `intent_mode` to it (DD-X03, boss-ai C8.4 `effective_mode`); absent at MVP → `full`. |
| Content | Content depends on this | Soft | The grammar and key format for authoring `unlock`; the 4 v1 treasure keys (M10) and the unmapped milestones are the content brief. |

## Tuning Knobs

All in `assets/data/profile_defaults.json` (DD-T01 file `profile_defaults`) unless noted; `systems-designer` not
consulted — Lean mode. Interacting pair: `run_log_cap` × `archive_top_cards` sets F5's size —
raise one, check the other against `max_profile_bytes`. Owned elsewhere, pointed to not
duplicated: `abandon_counts_as_loss`, `allow_custom_seed`, `floors_per_run` (Run Structure);
`min_treasure_pool` (Card Database); `keep_match_logs`, `log_memory_budget_bytes` (RNG & Event Log).

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `run_log_cap` | 200 | 20 – 1000 | Longer history on the Run Log screen; file grows ~8.5 KB per entry (F5); above ~230 the 2 MB budget breaks at default `archive_top_cards` | Shorter history; below 50 the "Investment" hook weakens; stats never affected |
| `archive_top_cards` | 10 | 5 – 36 | Fuller per-match damage tables in old runs; 36 triples the profile | Terser archive rows; below 5 the run log's "top damage cards" loses meaning |
| `max_profile_bytes` | 2,097,152 | 1 – 8 MB | Later `W_PROFILE_SIZE` warning | Earlier warning; a diagnostic, never a behaviour change |
| `max_save_ms` | 50 | 16 – 200 | Tolerates slower disks before the AC-27 budget fails | Forces a smaller cap on weak hardware |
| `backup_count` | 1 (`profile.bak`) | 1 – 3 | `.bak`, `.bak2` … rotate; survives two consecutive bad writes | 1 is the minimum: zero would make corruption unrecoverable |
| `io_retry_ms` | 250 | 0 – 2000 | Longer stall on a failing disk before `E_IO` | Faster failure; 0 = no retry |
| `settings_write_debounce_ms` | 500 | 0 – 2000 | Fewer writes while dragging a slider; a crash inside the window loses the last change | More writes; 0 writes per tick |
| `lock_heartbeat_s` / `lock_stale_s` | 30 / 90 | 10–120 / 60–600, stale ≥ 2 × heartbeat | Longer read-only window after a crash | Faster takeover; too low risks a live instance being treated as stale on a laptop that slept |
| `max_condition_depth` / `max_condition_n` / fan-out | 3 / 999 / 8 | 2–5 / 1–9999 / 2–16 | More elaborate conditions; harder to display as one progress line | Simpler authoring surface |
| `max_floor_clamp` | 12 | = top of run-structure `floors_per_run` range | Must track that range; a lower value re-clamps honest records | — |
| `max_repairs_before_rebuild` | 25 | 5 – 100 | Tolerates more hand edits before a stats rebuild | Rebuilds sooner; a rebuild can only under-count (M7.5) |
| Unlock thresholds (M10 table) | per key | `n` 1 – 999; first key should be met inside ~3 runs (today that is `unlock.hero_fortune` at the first victory; the four treasure keys all need a Decay/Knowledge result or 16 boss kills — see Open Questions) | Later unlocks; the "Curiosity" hook starves if nothing opens in the first session | Everything opens at once; locked treasures stop reading as milestones |
| `profile_defaults` (M9) | volumes 1.0/0.8/1.0, `anim_speed` normal, `reduce_motion` false, `text_scale` 1.0, `high_contrast_states` false, `telegraph_mode` full, `action_delay_ms` 600, `gamma` 1.0 (0.8–1.4, DD-X10) | per field in M9 | — | — |

## Visual/Audio Requirements

Not applicable — this system has no visual or audio surface of its own. The unlock toast and run log screen are Run UI surfaces (UI Requirements below); their styling follows `design/art/art-bible.md`.

## Game Feel

Not applicable — persistence has no moment-to-moment feel target. The one feel constraint it imposes is on others: a save must never be perceptible (UI Requirements: no save spinner; writes complete under `max_save_ms`).

## UI Requirements

Screens belong to Run UI (`/ux-design` specs); this table says what the profile must expose.

| Information | Display Location | Update Frequency | Condition |
|---|---|---|---|
| Continue card: hero, floor "n of F", phase, last played (from `active_run` header fields only — never parsed deeper here) | Main menu | On menu open | `active_run != null` |
| Load-status message: restored from backup / profile could not be read, copy kept / saved by a newer version | Main menu, once per launch | On load | status ≠ `OK`/`FRESH` |
| ReadOnly banner ("another copy is open" with Retry; "newer version") | Persistent top strip | On state change | `ReadOnly` |
| Per-hero **wins / losses / best floor** (hero-select corner line "NW · NL · best FN", run-ui U7 — wording confirmed 2026-11-03); bests line (fastest victory, fewest turns) with "random seeds only" note | Hero select corner (heroes.md UI row), Run Log header | On screen open | Always (zeros allowed) |
| Locked hero or treasure: condition text + progress "7 / 10" or bar (F6); `each_launch` lists per-hero ticks | Hero select; treasure codex / draft offer tooltip | On screen open | key Locked |
| Run Log screen: newest first — date, hero, result (Victory / Defeat on floor n by <boss> / Abandoned), floors "n of F", deck size, treasures, top-`archive_top_cards` damage cards, seed hex with **Copy**, "custom seed" tag, `attempt > 1` marker, "details unavailable" for opaque schema rows; pagination `run_log(offset, limit)` | Run Log (from main menu) | On open, on page | Always; empty state "No runs yet" |
| Victory / defeat summary additions: "New treasure unlocked: <name>" toasts drained from `pending_notifications` (one per key; Run UI acks each on show and owns the visible duration — run-ui F3 sets the floor and cap); unlock's condition shown as the toast subtitle | Run summary (run-structure UI row), main menu for `retro` grants | On summary open | queue non-empty |
| Settings: volumes, fullscreen, animation speed (`anim_speed` labels, DD-X07), reduce motion, text scale, high-contrast states, telegraph mode, action delay, gamma (0.8–1.4, DD-X10), keep run records, "Clear run records", "Reset profile" (typed confirm) | Settings screen | On change (debounced write) | Always |
| `save_failed` / `run_record_not_kept` toasts | Overlay | On event | Run Structure's `run_warning` path |

> **📌 UX Flag — Meta Progression**: This system has UI requirements. In Pre-Production, run
> `/ux-design` for the Run Log screen, the settings screen, the unlock toast and the locked-item
> progress pattern (shared by hero select and the treasure codex) **before** writing epics.
> Stories that reference UI should cite `design/ux/[screen].md`, not this GDD.

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|---|---|---|---|
| Persistence API `save_active_run` / `load_active_run` / `clear_active_run` / `archive_run` / `is_hero_unlocked` (M1.3) | `design/gdd/run-structure.md` | R7 save points and contract | Ownership handoff (confirmed here) |
| `RunRecord` fields read by the fold and archive (F2, M8.1) | `design/gdd/run-structure.md` | R1 schema; `RUN_RECORD_SCHEMA_VERSION` = 1 (registry constant) | Data dependency |
| `abandoned/player` counts as a loss; system abandons are void (F2) | `design/gdd/run-structure.md` | R6, `abandon_counts_as_loss` knob | Rule dependency |
| Custom seeds excluded from bests, counted for unlocks (M3.4, M7.4) | `design/gdd/run-structure.md` | R9 `seed_source` | Rule dependency (confirmed) |
| Locked hero resumes; lock gates `new_run` only (M3.7) | `design/gdd/run-structure.md` | R8.4, R2 | Rule dependency |
| Resume validation outcomes arrive as system-abandoned archives (M5.4) | `design/gdd/run-structure.md` | R8.1 | State trigger |
| `floor_reached` on victory set to `floors_per_run` (F3 is the fallback for older records) | `design/gdd/run-structure.md` | R6 Victory result fields | Rule dependency (R6 sets it) |
| `floors_per_run` range 3–12 → `max_floor_clamp` | `design/gdd/run-structure.md` | Tuning Knobs `floors_per_run` | Data dependency |
| `HeroDef.unlock {key, condition}`; keys `unlock.hero_fortune/order/shadow` and their sketched conditions (M2.1, M10) | `design/gdd/heroes.md` | H-2, H-7, Open Questions (field location) | Ownership handoff (resolved: `HeroDef.unlock`) |
| Hero ids `hero_war`, `hero_decay`, `hero_knowledge` in `stats.heroes{}` | `design/gdd/heroes.md` | H-2 table (registry entities) | Data dependency |
| `TreasureDef.unlock` becomes an object; validator injection; `min_treasure_pool` = 9 (M2.1, M2.4, M10) | `design/gdd/card-database.md` | CR-3 TreasureDef, CR-5 validator stages, Formulas "Minimum treasure pool" | Ownership handoff (adopted in CR-3, DD-X01) |
| `data_version` drives retro-grants (M3.1b) | `design/gdd/card-database.md` | `data_version` field | Data dependency |
| Run log `to_json()` shape; `log_schema_version` migration; archive key `run_id` instead of `run_seed_hex` (M4.4, M8.2) | `design/gdd/rng-event-log.md` | Rules 17, 18; Edge Cases "Persistence" | Ownership handoff (rule 18 keyed by `run_id`, adopted) |
| Sealed run log never reopened; `unlock_granted` not on the run log (M3.6) | `design/gdd/rng-event-log.md` | Rule 15 | Rule dependency |
| `replay_equivalence` requires same `data_version`; `user://runs/` files are the replay input | `design/gdd/rng-event-log.md` | F6 (registry formula) | Data dependency |
| `match_summary.result`, `damage_by_card` used by F2 and M8.1 | `design/gdd/rng-event-log.md` | Rule 19, catalogue `match_summary` | Data dependency |
| `anim_speed` label set (DD-X07), `reduce_motion`, `text_scale`, `high_contrast_states`, `action_delay_ms` stored in `settings` (M9) | `design/gdd/match-ui.md` | Core Rules 4, F3 `SPEED_DIV`, F4 `ai_action_delay_s`, Tuning Knobs `anim_speed`, Interactions "Meta Progression" | Data dependency (Match UI owns semantics) |
| `telegraph_mode` settings key consumed as `effective_mode = min(intent_mode, telegraph_mode)` (M9) | `design/gdd/boss-ai.md` | C8.4 `effective_mode`, Dependencies "Meta Progression" | Data dependency (DD-X03; Boss AI owns semantics) |
| `telegraph_mode` settings key; Run UI's proposed API names and settings list (M1.3, M9) | `design/gdd/run-ui.md` | Interactions "Meta Progression" row, Open Questions | Contract (resolved by the M1.3 mapping; `telegraph_mode` owner is Boss AI, DD-X03) |
| `is_treasure_unlocked(id)` at `init_run`; pool filter before seeded draws (M3.7) | `design/gdd/reward-draft.md` | `init_run`, Interactions "Meta Progression", AC-27 | Rule dependency (confirmed) |
| The four locked treasure ids and their keys (M10); `pool(unlocked_keys, exclude_ids)` | `design/gdd/treasures.md` | T1 `unlock`, T6, T8 rows 13/15/17/18, R-14 | Ownership handoff (keys named there, conditions defined here) |

## Acceptance Criteria

`qa-lead` not consulted — Lean mode (no Agent tool). Logic criteria run headless under gdUnit4
with an injected `user://`-equivalent temp directory and synthetic `RunRecord` fixtures
(`tests/unit/meta-progression/fixtures/`); UI criteria need a retained screenshot.

**File protocol (M1, M4, M5)**

- [ ] AC-1 **GIVEN** a fresh install, **WHEN** `load_profile()` runs, **THEN** status is `FRESH`,
  `schema_version == 1`, `profile_id` is 32 hex chars, `run_log == []`, `active_run == null`, and
  the file is written only on the first mutator, not on load.
- [ ] AC-2 **GIVEN** any profile in memory, **WHEN** `save_profile()` then `load_profile()` run,
  **THEN** the loaded dict equals the saved dict key-for-key (round-trip equality), including
  unknown keys injected into `settings` and a 36-card `active_run` blob.
- [ ] AC-3 **GIVEN** a profile on disk, **WHEN** a save succeeds, **THEN** `profile.bak` equals the
  previous `profile.json` byte-for-byte, no `.tmp` remains, and `write_seq` increased by 1.
- [ ] AC-4 **GIVEN** a write where the staged `.tmp` write is forced to fail, **WHEN** `save_profile()`
  runs, **THEN** it retries once after `io_retry_ms`, returns `E_IO`, `profile.json` and `.bak`
  are byte-identical to before, and no `.tmp` remains.
- [ ] AC-5 **GIVEN** `profile.json` truncated mid-file and a valid `.bak`, **WHEN** loading, **THEN**
  status is `RECOVERED_BAK`, the profile equals `.bak`, and `profile.corrupt-<ts>.json` equals
  the truncated file.
- [ ] AC-6 **GIVEN** both files unparseable, **WHEN** loading, **THEN** status is
  `FRESH_AFTER_CORRUPT`, two `*.corrupt-<ts>.json` copies exist, and nothing was deleted.
- [ ] AC-7 **GIVEN** a profile with `schema_version: 99`, **WHEN** loading, **THEN** status is
  `E_SCHEMA_NEWER`, the file's bytes and mtime are unchanged after `set_setting` and
  `save_active_run` (both return `E_READONLY`), and state is `ReadOnly`.
- [ ] AC-8 **GIVEN** a v1 profile fixture with three archived victories (two random-seed, one
  custom) for `hero_war`, **WHEN** loaded by a build with `PROFILE_SCHEMA_VERSION == 2` and the
  worked v1→v2 migration, **THEN** `schema_version == 2`,
  `stats.heroes.hero_war.best_turns_victory` equals the smaller of the two random-seed turn
  counts, the pre-migration file is now `.bak`, and loading the result again applies no migration.
- [ ] AC-9 **GIVEN** a live `profile.lock` (heartbeat 10 s old), **WHEN** a second `load_profile()`
  runs, **THEN** status is `E_LOCKED`, state `ReadOnly`; **AND GIVEN** heartbeat 100 s old, **THEN**
  status is `OK` and the lock now carries the new `instance_id`.

**Run slot and archive (M8)**

- [ ] AC-10 **GIVEN** `save_active_run(dict)` returned `OK`, **WHEN** the process restarts and
  `load_active_run()` runs, **THEN** it returns a dict equal to the one saved; **AND** after
  `clear_active_run()` it returns `null`.
- [ ] AC-11 **GIVEN** a full 8-floor victory record with `run_log`, `rng_snapshot`,
  `draft_state`, `treasure_state` and 30-key `damage_by_card` per summary, **WHEN** `archive_run`
  runs, **THEN** the stored ArchivedRun lacks those four keys, each summary has ≤ 10
  `damage_by_card` entries plus `_others` equal to the dropped sum, `totals.damage_by_card` is
  intact, and `user://runs/<run_id>.json` holds the complete original record.
- [ ] AC-12 **GIVEN** `run_log_cap = 200` and 200 archived runs, **WHEN** one more is archived,
  **THEN** `len(run_log) == 200`, the entry previously at index 0 is gone, index 199 is the new
  run, and `stats.runs_started == 201`.
- [ ] AC-13 **GIVEN** a record already archived, **WHEN** `archive_run` is called again with the
  same `run_id`, **THEN** it returns `{ok: true, unlocks_granted: []}` and `stats`, `run_log` and
  `pending_notifications` are unchanged.
- [ ] AC-14 **GIVEN** `active_run.run_id` equal to a `run_log[]` entry, **WHEN** loading, **THEN**
  `active_run` is `null` and no archive or fold happened.

**Statistics (M7, F2, F3)**

- [ ] AC-15 **GIVEN** synthetic records — a War victory (random seed, 61 turns, 1,400 s), a War
  custom-seed victory (40 turns, 900 s), a Decay defeat on floor 4 by `boss_x`, a Knowledge
  `abandoned/player` at floor 2, and a Knowledge `abandoned/data_version_mismatch` — **WHEN** all
  are archived, **THEN** `runs_started 5, runs_won 2, runs_lost 2, runs_void 1`;
  `heroes.hero_war = {runs_won 2, fastest_victory_s 1400, fewest_turns_victory 61}`;
  `heroes.hero_decay.best_floor_reached == 4`; `heroes.hero_knowledge = {runs_lost 1,
  best_floor_reached 2}`; `bosses.boss_x.defeated_by == 1`; and the custom-seed run's 900 s is
  nowhere in `bests`.
- [ ] AC-16 **GIVEN** `abandon_counts_as_loss = false` in `run_structure.json`, **WHEN** an
  `abandoned/player` record is archived, **THEN** `runs_void` +1 and `runs_lost` unchanged.
- [ ] AC-17 **GIVEN** a victory record on `floors_per_run = 8`, **WHEN** folded, **THEN**
  `best_floor_reached == 8`; **AND GIVEN** a defeat with `result.floor_reached = 5`, **THEN** it is 5.
- [ ] AC-18 **GIVEN** a profile edited to `runs_won: -3, best_floor_reached: 40, volume_master: 7`,
  **WHEN** loading, **THEN** the values are `0, 12, 1.0`, three `profile_repaired` lines are logged,
  `load.repairs == 3`, and no unlock changed state.

**Unlocks (M2, M3, F1, F6)**

- [ ] AC-19 **GIVEN** the four M10 treasure definitions and the three hero definitions, **WHEN**
  `met` is evaluated against each of these synthetic stats — `{}` ; `{runs_won: 1, heroes:
  war runs_won 1}` ; `{runs_won: 1, heroes: decay runs_won 1}` ; `{heroes: decay best_floor 5,
  knowledge best_floor 5}` ; `{bosses: 16 defeated across 8 ids}` ; `{bosses: 15 defeated across
  16 ids}` ; `{runs_won: 3, heroes: war/decay/knowledge runs_won 1/1/1}` — **THEN** the met sets
  are exactly: ∅ ; {hero_fortune, hero_order} ; {hero_decay_first_win, hero_fortune, hero_shadow} ;
  {hero_decay_floor_5} ; {bosses_defeated_16} ; ∅ (cumulative count, not distinct ids) ;
  {hero_decay_first_win, hero_knowledge_first_win, hero_fortune, hero_order, hero_shadow}.
- [ ] AC-20 **GIVEN** stats one kill short of `bosses_defeated_16` (15 bosses), **WHEN** a defeat
  record whose first match was a player win is archived, **THEN** `archive_run` returns
  `unlocks_granted == ["bosses_defeated_16"]`, `unlocks[key] == {unlocked: true, at > 0,
  by_run_id: <that run_id>, retro: false}`, `pending_notifications` holds one entry for it, and
  `unlock_granted` was emitted once.
- [ ] AC-21 **GIVEN** a custom-seed Decay victory as the player's first win, **WHEN** archived,
  **THEN** `hero_decay_first_win` and `unlock.hero_fortune` are granted (unlocks count custom
  seeds), `is_treasure_unlocked("treasure_grave_tithe")` is `true`, `unlocked_keys()` contains
  `hero_decay_first_win`, and `fastest_victory_s` stays `null` (bests do not).
- [ ] AC-22 **GIVEN** a profile with `runs_won: 1` saved under `data_version "1.0"` and a data
  set `"1.1"` that newly defines `unlock.hero_fortune`, **WHEN** loading, **THEN** the key is
  granted with `retro: true, by_run_id: null`, a notification is queued, `"1.1"` is appended to
  `data_versions_seen`, and loading again under `"1.1"` evaluates nothing.
- [ ] AC-23 **GIVEN** a key `unlocked: true` whose condition is now unmet (stats clamped or
  condition tightened), **WHEN** loading and evaluating, **THEN** it remains `unlocked: true`.
- [ ] AC-24 **GIVEN** `heroes.json` with `hero_fortune.unlock` set and unmet, **WHEN**
  `is_hero_unlocked("hero_fortune")` and `is_hero_unlocked("hero_war")` are called, **THEN** they
  return `false` and `true`; **AND** `unlock_progress("bosses_defeated_16")` with 8 bosses
  defeated returns `{met: false, progress: 0.5}`, and `unlock_hint("treasure_living_armory")`
  returns the same progress with `target == 16`.
- [ ] AC-25 **GIVEN** a treasure whose condition references `boss_id: "boss_nope"`, **WHEN** Card
  Database loads with the injected validator, **THEN** load fails with `E_UNLOCK_UNKNOWN_ID`
  naming the key; **AND GIVEN** a condition nested 4 deep, **THEN** `E_UNLOCK_SHAPE`.
- [ ] AC-26 **GIVEN** a queued notification, **WHEN** `ack_notification(key)` runs and the process
  restarts, **THEN** the queue is empty; **AND GIVEN** a crash before the ack, **THEN** the entry is
  still queued after restart.

**Budget and UI**

- [ ] AC-27 Performance: **GIVEN** a profile at `run_log_cap` with full ArchivedRuns, **WHEN**
  `save_profile()` runs 20 times on the minimum spec, **THEN** the median completes within
  `max_save_ms` (50 ms) and the file is under `max_profile_bytes` (2 MB).
- [ ] AC-28 **GIVEN** the Run Log screen with 3 archived runs (one custom seed, one with
  `attempt > 1`), **WHEN** opened, **THEN** a retained screenshot shows newest-first rows with
  hero, result, "n of F", deck size, top damage cards, the "custom seed" tag, the attempt marker,
  and a Copy control whose clipboard output re-parses to the row's `run_seed`.
- [ ] AC-29 **GIVEN** `pending_notifications` holding one treasure key, **WHEN** the run summary
  opens, **THEN** a retained screenshot shows the "New treasure unlocked" toast with the
  treasure name and condition text, and the queue is empty after dismissal.
- [ ] AC-30 No hardcoded values: every knob in Tuning Knobs is read from `assets/data/profile_defaults.json`;
  `PROFILE_SCHEMA_VERSION` is the one code constant.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| CR-3 amendment: `TreasureDef.unlock` from "string or null" to `{key, condition} or null`, and the same field on `HeroDef` and `BundleDef`. Accept, or keep string keys in defs and move conditions to a separate `unlocks.json`? | Card Database GDD owner + Jacob | before `/create-architecture` | **Resolved 2026-11-03 — cross-review C-30 / DD-X01**: the `{key, condition}` object on HeroDef, TreasureDef and BundleDef (M2.1 grammar); Card Database CR-3 and Treasures T1 adopt it (C-06) |
| Rename atomicity of `.tmp → profile.json` on Windows/macOS/Linux under Godot 4.7 (`DirAccess.rename_absolute` or equivalent) — **NOT SOURCEABLE** from the pinned reference | `engine-programmer` via ADR | Technical Setup | Open; ADR must cite the 4.7 docs |
| Is `max_save_ms` 50 achievable with a synchronous 2 MB pretty-printed write on the minimum spec, or do we need a background thread / compact JSON / a split `runs.json`? | `gameplay-programmer` | Vertical Slice (measure, AC-27) | Open; fallback is lowering `run_log_cap` |
| ~~The six locked-treasure ids are placeholders~~ Resolved 2026-11-03: M10 now carries treasures.md T8's four ids and keys. Remaining: (a) does `bosses_defeated_16` mean 16 cumulative kills (this GDD's reading) or every one of the 16 bosses once (inexpressible at fan-out 8)? (b) no treasure rewards an any-hero milestone, so a War-only player sees no treasure unlock until 16 kills — should Treasures lock one more universal treasure on `runs_won ≥ 1`? | Treasures GDD + Content | `/review-all-gdds` | (a) **Resolved 2026-11-03 — cross-review C-30 (V-13)**: treasures.md R-14 confirms `boss_defeated(any) ≥ 16`, cumulative. (b) Open — content choice; cross-review D-03 recommends Treasures lock one universal treasure on `runs_won ≥ 1` (e.g. Living Armory → `runs_won_any_1`, Stampede Horn → `bosses_defeated_16`) and one on `floor_reached ≥ 5` for any hero; when Treasures/Content decide, the M10 table and AC-19 follow |
| `telegraph_mode` is a settings key Run UI lists and this GDD stores, but no GDD owns its semantics: Boss AI's `intent_mode` is per-boss data, Match UI renders the intent banner. Assign to Match UI, or drop the key? | Match UI + Run UI GDDs | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-01 / DD-X03**: Boss AI consumes it as `effective_mode = min(boss.intent_mode, telegraph_mode)` (boss-ai C8.4); Match UI renders what Boss AI emits; stored here with default `full` (M9) |
| run-ui.md labels `anim_speed` as `instant\|fast\|normal`; match-ui.md (owner) defines `1.0 \| 1.5 \| 2.0 \| instant`. This GDD stores the owner's enum; Run UI should map labels | Run UI GDD | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-01 / DD-X07**: the labels `instant\|fast\|normal` are the stored values (M9); Match UI maps them to durations (`SPEED_DIV`, match-ui F3) |
| treasures.md States names the grant event `unlock_earned`; this GDD and run-ui.md use `unlock_granted` | Treasures GDD | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-19**: treasures.md States renames to `unlock_granted` (M3.6) |
| `assets/data/profile.json` (defaults) and `user://profile.json` (the profile) share a basename; rename the data file `profile_defaults.json` and add it to DD-T01's list? | Jacob + design-decisions.md | before `/create-architecture` | **Resolved 2026-11-03 — cross-review C-21**: renamed `assets/data/profile_defaults.json` (M9, Tuning Knobs, AC-30); DD-T01 lists it; Card Database CR-1 serves `config("profile_defaults")` |
| Run-structure R6 does not set `result.floor_reached` on victory; this GDD derives it (F3). Should R6 set it instead? | Run Structure GDD | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-30**: run-structure R6 sets `floor_reached` on victory; F3 remains the fallback for older records |
| rng-event-log rule 18 keys match logs by `run_seed_hex`; this GDD keys full run records by `run_id`. Align rule 18 to `run_id`? | RNG & Event Log GDD | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-30**: rng-event-log rule 18 keys the log folder by `run_id` (M8.2) |
| Should the profile also keep a tiny `profile.index.json` (last run, hero, floor) so the main menu can render before parsing 2 MB? | Run UI `/ux-design` + `ui-programmer` | Pre-Production | Open; only if AC-1 load time is visible |
| Multiple profiles / Steam Cloud: out of v1 by brief. If added, `profile_id` and the lock scheme already allow `user://profiles/<id>/` | Jacob | Full Vision | Deferred |
