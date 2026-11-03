# Run Structure

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
> **Author**: Jacob (owner) + `/design-system run-structure` (workflow standard, docs.density balanced, automation guided, review lean)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 1 (Every run builds a deck you couldn't have planned) and Pillar 3 (Lose fast, learn fast); Pillar 4 through the seeded boss sequence (DD-R09)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` `game-designer`, `systems-designer`, `economy-designer` (Section C), `systems-designer` (Sections D, E, G) and `qa-lead` (Section H) not consulted — Lean mode, and this session has no `Agent` tool; review manually before production. Technical feasibility: no engine reference for `scripting` under `docs/engine-reference/godot/modules/`; feasibility not checked against the pinned engine (pure GDScript `RefCounted` logic per DD-T02, no engine surface expected).
> **Decision register rows honoured**: DD-R01–R09, DD-H06, DD-M02, DD-M12, DD-T01–T04.

## Summary

Run Structure is the outer state machine of a Deckdelve run: it picks a hero and a seed,
generates the eight-boss gauntlet from three difficulty bands, hands each match to Match Rules,
runs the treasure-then-bundle draft after each win, and ends the run on the first loss or the
final victory. It owns the run record (seed, boss sequence, deck, treasures, per-match
summaries, status) and its save/resume schema, so a run is reproducible from its seed and
resumable from any point between matches. Read this GDD for anything that happens between
matches, the `MatchConfig`/`MatchResult` hand-off, the save contract, or the floor-by-floor
difficulty targets; `floors_per_run` switches the same machine between the MVP's four floors and
the full eight.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Match Rules, Card Database, RNG & Event Log, Heroes (contract), Reward Draft (contract), Treasures (contract), Meta Progression (contract)`

## Overview

Run Structure is the outer game: the state machine that turns one hero and one seed into a
gauntlet of eight boss matches with a draft after every win, and that ends the moment a match is
lost. It owns the `RunState` record — seed, hero, floor, boss sequence, the growing deck, the
treasures held, one summary per match and the run's status — and nothing else writes it: Match
Rules plays one match from the `MatchConfig` it is handed and returns a `MatchResult`; Reward
Draft fills one draft when the run asks; Treasures installs hooks from the id list the run gives
it at match start; Meta Progression receives the finished record. The player meets this system
as the spine of a session: pick a hero (optionally typing a seed), read the boss intro, fight,
draft, descend, and either see the victory summary after floor 8 or the death summary at the
first loss, with "Run again" one click away. It exists so that a run is reproducible from its
seed (DD-R09, Pillar 4), resumable from any point between matches (DD-R08), and short enough that
losing teaches rather than costs (Pillar 3). One knob, `floors_per_run`, lets the same machine
serve the MVP's four-floor cut (DD-H06) and the full eight-floor run.

## Player Fantasy

*Framing: both — a direct layer (hero select, boss intro, the summary screens) over
infrastructure the player never sees (sequence generation, saving, record keeping).*

**The descent.** The run should feel like a dungeon crawl read one room at a time: every boss
intro is a question ("can my weapons out-race a boss that heals 5 a turn?"), every draft is the
answer you commit to, and the progress strip is how far down you have made it. The emotion the
system targets is **"one more floor"** — the pull Hearthstone's Dungeon Run creates with its
eight-boss strip and Slay the Spire creates with its map: the next boss is visible as a threat
(its band), not as a spoiler (its identity).

**Losing is a lesson, not a bill.** Pillar 3 is this system's second job. The death screen is
where a run turns into a story: which floor, which boss, which card carried the deck, and the
seed to try the same gauntlet again. Nothing is lost except the run; the restart is one click and
under five seconds. Reference: Slay the Spire's run history screen (per-run deck, relics, cause of
death) and speedrun reset culture (instant, guilt-free restarts). Anti-reference: roguelites
whose death screen is a currency payout — there is no currency here, so the screen must be worth
reading on its own.

Anchor moments: (1) the boss intro on floor 7, when the passive text reveals it counters the
plan you have been drafting since floor 2; (2) the victory summary showing that the card dealing
40% of your damage was one you took in a floor-2 bundle you almost passed on (Pillar 1 made
visible).

## Detailed Design

### Core Rules

Run Structure is pure logic (`RefCounted`, no Node references, DD-T02). It receives commands
from Run UI (`new_run`, `begin_match`, `draft_pick` forwarded to Reward Draft, `abandon`,
`resume`, `return_to_menu`) and callbacks from Match Rules (`match_ended`) and Reward Draft
(`draft_picked`), mutates `RunState`, and emits exactly one event per mutation (DD-T04).
All numeric values below are read from `assets/data/run_structure.json` (new file, Open
Questions), never hardcoded.

#### R1. RunState (the run record schema)

Run Structure owns this schema; Meta Progression / Persistence owns the file format, path and
atomic write (R7). Every field is JSON-representable (RNG & Event Log rule 14).

| Field | Type | Set by | Notes |
|---|---|---|---|
| `schema_version` | int | run start | `RUN_RECORD_SCHEMA_VERSION` = 1; no migrations in v1 |
| `data_version`, `engine_version` | string | run start | From Card Database and the engine; checked on resume (R8) |
| `run_id` | string | run start | `<run_seed_hex>-<started_at>`; unique even when seeds collide |
| `run_seed` / `run_seed_hex` | int64 / string | run start | RNG & Event Log F1; hex is the 16-digit display form (DD-R09) |
| `seed_source` | enum `random \| custom` | run start | `custom` when the player typed a seed (R9) |
| `hero_id` | string | run start | HeroDef id |
| `floors_per_run`, `band_split[3]`, `treasure_floors[]` | int, int[], int[] | run start | Copied from config so a saved run keeps the layout it started with |
| `boss_sequence[]` | string[] | run start | Length `floors_per_run`; index `f − 1` is floor `f`'s boss (F2) |
| `floor` | int | per floor | 1-based; the floor currently being fought or about to be |
| `status` | enum | per transition | `hero_select \| pre_match \| in_match \| post_match_reward \| victory \| defeat \| abandoned` |
| `reward_step` | enum `treasure \| bundle \| null` | reward phase | Which draft the reward phase is waiting on (R5) |
| `deck[]` | string[] | drafts | Card ids in acquisition order: starter deck (15, DD-R03) then each bundle's 3 cards (DD-R06). No cap, no removal in v1 |
| `treasures[]` | string[] | treasure drafts | Treasure ids in pick order — the order hooks install in (Match Rules hook table) |
| `drafts[]` | DraftRecord[] | drafts | `{floor, kind, offered_ids[], picked_id, card_ids_added[]}`; one per completed draft |
| `match_attempts{}` | {floor: int} | match start | Incremented each `begin_match`; > 1 means a mid-match quit was resumed (R8) |
| `match_summaries[]` | MatchSummary[] | match end | RNG & Event Log `match_summary` plus `boss_id, band, attempt, duration_s`; one per floor played (the last attempt) |
| `draft_state{}` | Dictionary | Reward Draft | Opaque to this system; holds pity counters and `offered_treasure_ids[]` (DD-R05 no-duplicate rule) — **contract, to be confirmed in reward-draft.md** |
| `treasure_state{}` | Dictionary | Treasures | Opaque; cross-match state for a treasure that needs it (none in v1) — **contract, to be confirmed in treasures.md** |
| `rng_snapshot` | Dictionary | each save | RNG & Event Log `snapshot()`: `{run_seed, data_version, streams{name: draws}}` |
| `run_log` | Dictionary | each save | RNG & Event Log `to_json()` of the run-scope log so far (run events + match summaries) |
| `started_at`, `updated_at`, `ended_at` | int (unix s, UTC) | lifecycle | `ended_at` null until the run ends |
| `play_seconds` | int | lifecycle | Accumulated from monotonic ticks only while `in_match` or in a draft; menus do not count |
| `result` | Dictionary or null | run end | `{outcome: victory \| defeat \| abandoned, floors_cleared, floor_reached, total_turns, ended_by: boss_id \| null, abandon_reason: player \| data_version_mismatch \| save_corrupt \| null}` |
| `totals` | Dictionary | run end | `{matches_played, turns, damage_by_card{}, cards_drafted, treasures_taken, play_seconds}` (R10) |

Invariants, checked by `RunRecord.validate()` (R8): `len(boss_sequence) == floors_per_run`;
`sum(band_split) == floors_per_run`; `1 ≤ floor ≤ floors_per_run`;
`len(deck) == starter_deck_size + bundle_card_count × n_bundle_picks(drafts)`;
`len(treasures) == n_treasure_picks(drafts)`; every id resolves in Card Database.

#### R2. Starting a run (`new_run(hero_id, seed_input)`)

1. Guard: `hero_id` is unlocked (Meta Progression `is_hero_unlocked(hero_id)` — **contract**;
   MVP: always true for `hero_war`). If an active run exists the UI has already confirmed
   overwrite; the old run ends as `abandoned / player` (R6) before the new one starts.
2. `run_seed` = RNG & Event Log F1 applied to `seed_input` (empty → entropy). `seed_source` is
   `custom` when the trimmed input is non-empty.
3. The RNG service is created with `(run_seed, data_version)`; the run log is opened.
4. `boss_sequence` is generated with the `run` stream (F2). Exactly three `shuffle` calls are
   made on `run` in v1, in band order; nothing else draws from `run` (floor layout is reserved
   for later). Pool-short bands emit `run_warning{code: boss_pool_short}` (Edge Cases).
5. `deck` = `HeroDef.starter_deck` copied in data order; `treasures` = `[]`; `floor` = 1;
   `drafts`, `match_summaries`, `match_attempts` empty.
6. Emit `run_started{run_seed_hex, hero_id, data_version, log_schema_version, boss_ids[]}`
   (catalogue), set `status = pre_match`, save (R7 point S1).

#### R3. Entering a floor and building the match

1. On entering `pre_match` emit `run_floor_entered{floor, band, boss_id}` with `band = band(floor)`
   (F1). Run UI shows the boss intro and waits for `begin_match`.
2. On `begin_match`: `match_attempts[floor] += 1`, `status = in_match`, and Match Rules receives:

   ```
   MatchConfig {
     floor, band,
     rng_match: rng.stream("match_<floor>"), rng_ai: rng.stream("ai_<floor>"), log,
     player: { hero_def_id: hero_id, deck: deck (copy, list order),
               hook_installers: Treasures.installers_for(treasures) },   # pick order
     boss:   { boss_def_id: boss_sequence[floor-1], deck: BossDef.deck,
               health: boss_health(floor),                                  # F3
               hook_installers: [ passive installer from BossDef.passive ],
               ai_id: BossDef.ai_profile }
   }
   ```

   Match Rules C3 names a `seed` field here; per RNG & Event Log rule 3 (streams are owned and
   memoised) the run passes the stream objects instead. Field name flagged for
   `/consistency-check`; Match Rules settles it.
3. `in_match` is never saved (DD-R08). A quit during a match leaves the S1/S4 save at
   `pre_match` for this floor (R8).

#### R4. Match result

Match Rules returns `MatchResult {winner, reason, turns, turns_per_side, player stats, boss
stats, final health, seed}` (C14) and the log reduces the match to a `match_summary`. The run
appends `{boss_id, band, attempt: match_attempts[floor], duration_s}` and stores it:

- `winner = player` and `floor < floors_per_run` → `status = post_match_reward` (R5), save S2.
- `winner = player` and `floor == floors_per_run` → **victory** (R6).
- `winner = boss` for any reason (`hero_dead`, `both_dead` DD-M12, `concede`, `turn_cap`) →
  **defeat** (R6). The reason is kept in the summary; a concede is a defeat, never an abandon.
- `result = fault` (log overflow, RNG & Event Log Faulted state) → the floor is **not** lost:
  emit `match_faulted{floor, attempt}`, return to `pre_match`, save. A rules bug must not end a
  run; the retry uses the same streams (R8), so a reproducible fault reproduces — which is the
  bug report.

#### R5. Reward phase — treasure first, then bundle

1. Bundle draft happens after every win on floors `1 .. floors_per_run − 1` (DD-R04). Treasure
   draft happens additionally on floors in `treasure_floors` that are `< floors_per_run`
   (DD-R05; default `[1, 3, 5]`). There is no draft after the last floor.
2. **Order on a treasure floor: treasure, then bundle.** Rationale: the treasure is the
   rule-bending pick (Pillar 1's "plan-dependent" choice); taking it first lets the bundle pick
   answer it ("I now have double Battlecry — take the Battlecry bundle"), while the reverse order
   leaves the bigger decision to be made around a smaller one. It also fixes the draw order on
   `draft_<floor>`: Reward Draft draws treasure offers before bundle offers, so a resume between
   the two picks regenerates the same bundle offers from the restored stream position
   (**contract — to be confirmed in reward-draft.md**). Alternative rejected: bundle first, so a
   treasure can complement the new cards — weaker, because 3 cards out of 18–36 shift the deck
   less than one treasure shifts the rules.
3. `reward_step` is `treasure` on a treasure floor, else `bundle`. The run calls
   `RewardDraft.offer(kind, run_state, rng.stream("draft_<floor>")) → offered_ids[]`; Reward
   Draft emits `draft_offered`. The run accepts exactly one `draft_pick(kind, id)` with `id ∈
   offered_ids` and `kind == reward_step`; anything else is rejected (`E_DRAFT_KIND`,
   `E_NOT_OFFERED`, `E_DRAFT_DONE`).
4. On a treasure pick: append to `treasures`, record the DraftRecord, emit
   `treasure_granted{floor, treasure_id}` (this system emits it — the append is its mutation;
   Reward Draft emits `draft_picked`), `reward_step = bundle`, save S3.
5. On a bundle pick: append the bundle's 3 card ids to `deck`, record the DraftRecord, emit
   `deck_grew{floor, card_ids_added[], deck_size}`, `reward_step = null`, `floor += 1`,
   `status = pre_match`, save S4.
6. Treasures take effect only through `hook_installers` at the next match start (Match Rules
   C3 step 4); nothing is applied at pick time. This is what makes resume idempotent (R8).

#### R6. Ending a run

- **Victory** (`floor == floors_per_run` won): `result.outcome = victory`, `floors_cleared =
  floors_per_run`, `ended_by = null`.
- **Defeat** (any boss win): `outcome = defeat`, `floors_cleared = floor − 1`, `floor_reached =
  floor`, `ended_by = boss_sequence[floor − 1]`.
- **Abandon** (`abandon()` from the main-menu Continue card or the pause menu, confirmed; legal
  only in `pre_match` and `post_match_reward`): `outcome = abandoned`, `abandon_reason =
  player`, `floors_cleared = floor − 1`. **Abandon counts as a loss** for Meta Progression's
  per-hero statistics (`abandon_counts_as_loss`, default true): there is no meta currency, so
  the only cost of abandoning is statistical, and without it the run log would overstate win
  rates and let a player discard every bad floor-1 draft for free. A player who wants out of a
  match concedes (Match Rules C14) and takes a defeat; there is no abandon from inside a match
  and no reward for one. System abandons (`data_version_mismatch`, `save_corrupt`, R8) are
  recorded but are **not** losses.
- In every case: compute `totals` (R10), set `ended_at`, emit
  `run_ended{result, floors_cleared, total_turns, run_seed_hex}` (seals the run log), hand the
  record to Meta Progression (`archive_run(record)`), clear the active-run slot, show the
  summary. The summary's "Run again" issues `new_run(hero_id, "")` — a fresh random seed; the
  shown seed is copyable for a deliberate replay (DD-R09).

#### R7. Save points and the persistence contract (DD-R08)

| Point | After | Saved `status` / `reward_step` | Floor saved |
|---|---|---|---|
| S1 | `run_started` | `pre_match` / null | 1 |
| S2 | a won match on floor `< F` | `post_match_reward` / `treasure` or `bundle` | f |
| S3 | a treasure pick | `post_match_reward` / `bundle` | f |
| S4 | a bundle pick | `pre_match` / null | f + 1 |
| S5 | `run_ended` (any outcome) | final; `archive_run` then `clear_active_run` | — |

`in_match` is never saved. The record saved is `RunRecord.to_dict()` (R1) including
`rng_snapshot` and `run_log`. Persistence API this system calls — **contract, to be confirmed
in meta-progression.md**: `save_active_run(dict) → OK | E_IO`, `load_active_run() → dict |
null`, `clear_active_run()`, `archive_run(dict)`, `is_hero_unlocked(id) → bool`. One active run
per profile. A save failure (`E_IO`) does not stop the run: `run_warning{save_failed}` is shown,
the run continues in memory and the next save point retries; quitting after a failed save loses
the floors since the last good save (Edge Cases). Emit `run_saved{floor, phase}` on success.

#### R8. Resume

1. From the main menu, `load_active_run()` → `RunRecord.validate(dict)` → `OK | E_SCHEMA |
   E_DATA_VERSION | E_CORRUPT | E_UNKNOWN_ID`. Any error: the record is ended as `abandoned` with
   `abandon_reason = data_version_mismatch` (E_DATA_VERSION, E_UNKNOWN_ID) or `save_corrupt`
   (E_SCHEMA, E_CORRUPT), archived if it parses at all, the slot is cleared, and the menu offers
   a new run with the reason shown. This matches RNG & Event Log's provisional rule for a
   `data_version` mismatch (its Edge Cases) and is not a loss.
2. On `OK`: rebuild the RNG service, `restore(rng_snapshot)`, reopen the run log from `run_log`
   (a new log instance — a sealed log is never reopened), set `status`/`reward_step`/`floor`
   from the record, emit `run_resumed{floor, phase, attempt: match_attempts[floor] + 1}`, and
   enter that state: `pre_match` shows the boss intro again; `post_match_reward` re-requests the
   pending draft from Reward Draft, which regenerates the same offers from the restored
   `draft_<floor>` position (R5.2).
3. **Resume after a quit mid-match = restart that match.** The latest save is `pre_match` for the
   floor; `begin_match` increments `match_attempts[floor]` and uses the same `match_<floor>` and
   `ai_<floor>` streams, restored at `draws = 0`, so the shuffles, opening hands and the boss's
   responses to identical boards are identical to the abandoned attempt. The player gains
   knowledge (they have seen the boss's first draws) but no new randomness. Alternative
   rejected: forking `match_<floor>/attempt_<k>` per attempt, which would let a player quit until
   an opening suits them — a re-roll is a bigger break of DD-R09 ("same seed reproduces offers")
   than the information leak is of fairness, and the leak is visible in `match_attempts` for
   anyone reading the log. True mid-match restore from the event log is an Open Question for
   Vertical Slice.
4. A locked hero does not block resume: the unlock check gates `new_run` only (R2). If the hero
   or any id no longer exists, rule 1 applies.
5. Treasure idempotency: `treasures[]` holds ids only; hooks are installed fresh at every match
   start from that list (R5.6). A resumed run therefore installs each treasure exactly once per
   match like any other run, and a `draft_pick` for a `(floor, kind)` already in `drafts[]` is
   rejected `E_DRAFT_DONE`, so a replayed pick cannot append twice.
6. A saved `status` of `in_match` (impossible from this system; forward-compatibility) is
   coerced to `pre_match` on the same floor with `run_warning{coerced_status}`.

#### R9. Seeds (DD-R09)

- Hero select shows a seed field when `allow_custom_seed` is true (default). Parsing is RNG &
  Event Log F1; the field accepts anything and the hex form shown on the summary re-parses to the
  same run. `seed_source = custom` is recorded so Meta Progression may exclude custom-seed runs
  from personal bests while still counting unlocks (**contract — Meta Progression decides**).
- Same seed + same hero + same `data_version` ⇒ same `boss_sequence` and, via the restored
  `draft_<floor>` streams, the same offers given the same picks. AI decisions after the player
  diverges are not expected to match (DD-R09 limit, RNG & Event Log rule 9).

#### R10. Run log, summaries and totals

- The run log is the RNG & Event Log run-scope log: `run_started`, `run_floor_entered`,
  `run_resumed`, `match_faulted`, `run_warning`, `draft_offered/picked` (Reward Draft),
  `treasure_granted`, `deck_grew`, `run_saved`, one `match_summary` per match, `run_ended`.
  Own additions to the catalogue (names past tense, payloads JSON-only): `run_resumed{floor,
  phase, attempt}`, `match_faulted{floor, attempt}`, `deck_grew{floor, card_ids_added[],
  deck_size}`, `run_warning{code, detail{}}`.
- Per-match summary fields read by Run UI and Meta: `floor, boss_id, band, result, reason,
  turns, attempt, duration_s, cards_played, damage_by_card{card_id: int}` plus the floor's
  DraftRecords (what was drafted after the win).
- `totals` at run end: `matches_played = len(match_summaries)`, `turns = Σ turns`,
  `damage_by_card` = key-wise sum over summaries, `cards_drafted = 3 × n_bundle_picks`,
  `treasures_taken = len(treasures)`, `play_seconds`. Run UI shows the top
  `summary_top_cards` (default 10) by damage with "and N more"; the record keeps all.

### States and Transitions

`Menu` is not a run state: it is where no `RunState` is active. Every other row is a value of
`RunState.status`; `post_match_reward` carries `reward_step`.

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| `hero_select` | Player opens New Run from the menu | `new_run` accepted, or back to menu | In-memory only, never saved; seed field editable; locked heroes shown but not selectable |
| `pre_match` | Run started, bundle picked, match faulted, or resumed into it | `begin_match`, `abandon` | Boss intro shown; `run_floor_entered` emitted on entry; **saved** (S1/S4) |
| `in_match` | `begin_match` | `match_ended` from Match Rules | Run Structure is passive; Match Rules owns the state; never saved; quit = restart later |
| `post_match_reward` / `treasure` | Won on a treasure floor `< F` | `draft_pick(treasure)`, `abandon` | Treasure offers requested from Reward Draft; **saved** (S2) |
| `post_match_reward` / `bundle` | Won on a non-treasure floor `< F`, or treasure picked | `draft_pick(bundle)`, `abandon` | Bundle offers requested; **saved** (S2/S3) |
| `victory` | Won on floor `F` | `return_to_menu`, `new_run` | Terminal; record archived; summary shown |
| `defeat` | Boss won any match | `return_to_menu`, `new_run` | Terminal; record archived; summary shown |
| `abandoned` | Player abandon, or resume validation failed | `return_to_menu`, `new_run` | Terminal; record archived (if it parsed); summary shown for player abandon, a reason dialog for system abandon |

**Transition table** (`.claude/rules/gameplay-code.md`: explicit, every row implemented and
tested; a trigger not listed for a state is rejected with `E_BAD_PHASE` and emits nothing):

| # | From | Trigger | Guard | Effects (events in order) | Save | To |
|---|---|---|---|---|---|---|
| T1 | Menu | open New Run | — | — | — | `hero_select` |
| T2 | `hero_select` | `new_run(hero, seed_input)` | hero unlocked; no active run or overwrite confirmed (old run → T13 first) | seed (R2), RNG service, boss sequence (F2), `run_started`, `run_warning`* | S1 | `pre_match` (floor 1) |
| T3 | `hero_select` | back | — | — | — | Menu |
| T4 | `pre_match` | (entry) | — | `run_floor_entered` | — | `pre_match` |
| T5 | `pre_match` | `begin_match` | — | `match_attempts[f] += 1`; MatchConfig handed to Match Rules (R3) | — | `in_match` |
| T6 | `in_match` | `match_ended(winner=player)` | `floor < F` | `match_summary` stored | S2 | `post_match_reward` (`treasure` if `f ∈ treasure_floors` else `bundle`) |
| T7 | `in_match` | `match_ended(winner=player)` | `floor == F` | `match_summary`; totals; `run_ended{victory}`; archive; clear slot | S5 | `victory` |
| T8 | `in_match` | `match_ended(winner=boss)` | any reason | `match_summary`; totals; `run_ended{defeat}`; archive; clear slot | S5 | `defeat` |
| T9 | `in_match` | `match_ended(result=fault)` | — | `match_faulted` | S1-shape | `pre_match` (same floor) |
| T10 | `in_match` | app quit / crash | — | nothing (no save) | — | — (resume lands in `pre_match`, T15) |
| T11 | `post_match_reward`/`treasure` | `draft_pick(treasure, id)` | `id ∈ offered`; `(f, treasure) ∉ drafts` | append treasure; DraftRecord; `treasure_granted` | S3 | `post_match_reward`/`bundle` |
| T12 | `post_match_reward`/`bundle` | `draft_pick(bundle, id)` | `id ∈ offered`; `(f, bundle) ∉ drafts` | append 3 cards; DraftRecord; `deck_grew`; `floor += 1` | S4 | `pre_match` (floor f+1) |
| T13 | `pre_match`, `post_match_reward` | `abandon()` | confirmed by UI | totals; `run_ended{abandoned, player}`; archive; clear slot | S5 | `abandoned` |
| T14 | `post_match_reward` | app quit | — | nothing; latest save is S2/S3 | — | — (resume re-offers, T15) |
| T15 | Menu | `resume()` | `validate(dict) == OK` | `restore(snapshot)`; reopen log; `run_resumed` | — | saved `status` |
| T16 | Menu | `resume()` | `validate(dict) != OK` | `run_ended{abandoned, reason}` if parseable; archive; clear slot; reason dialog | S5 | `abandoned` → Menu |
| T17 | `victory`, `defeat`, `abandoned` | `return_to_menu` | — | — | — | Menu |
| T18 | `victory`, `defeat`, `abandoned` | `new_run` ("Run again") | as T2 | as T2 with the same `hero_id`, empty seed | S1 | `pre_match` (floor 1) |

\* `run_warning` only when F2 had to repeat a boss.

Rejections (no state change, no event): `begin_match` outside `pre_match`; `draft_pick` outside
`post_match_reward` or with the wrong `kind`; `abandon` in `in_match` (the UI offers Concede
instead); `resume` while a run is active; `new_run` with a locked hero (`E_HERO_LOCKED`).

### Interactions with Other Systems

Interfaces marked **contract** are defined here because the partner GDD does not exist yet; the
partner GDD must restate or amend them, and `/consistency-check` reconciles.

| System | Direction | Data in (to Run Structure) | Data out (from Run Structure) | Interface owner |
|---|---|---|---|---|
| **Card Database** | upstream | `bosses_in_band(band)` (id-sorted, CR-6), `hero(id)` with `starter_deck`, `boss(id)` with `deck, health, passive, ai_profile, intro_text`, `data_version` | — (read-only) | Card Database owns record shapes; this GDD owns draw-without-replacement (DD-R02) |
| **RNG & Event Log** | upstream | `stream("run")`, `stream("match_<f>")`, `stream("ai_<f>")`, `stream("draft_<f>")`, `snapshot()`, `restore()`, the run log, `match_summary` | `run_seed` at creation; `run_started`, `run_floor_entered`, `run_resumed`, `match_faulted`, `deck_grew`, `treasure_granted`, `run_warning`, `run_saved`, `run_ended` | RNG & Event Log owns the envelope and API; this GDD owns run phase order and its payloads |
| **Match Rules** | mutual | `MatchResult` via `match_ended` (C14) | `MatchConfig` (R3) | Match Rules owns match state; this GDD owns `MatchConfig`/`MatchResult` record shapes beyond the fields Match Rules names |
| **Heroes** | upstream (data) | `HeroDef`: `starter_deck`, `hero_power`, `health` | — | **Contract — to be confirmed in heroes.md**: the run copies `starter_deck` verbatim; Heroes owns composition |
| **Reward Draft** | downstream (invoked by the run) | `offer(kind, run_state, stream) → offered_ids[]`; `draft_picked` callback with `picked_id, card_ids_added[]`; reads/writes `draft_state` | `kind` (treasure before bundle, R5.2), `floor`, read access to `deck`, `treasures`, `hero_id`, `boss_sequence`, `drafts`; the `draft_<floor>` stream | **Contract — to be confirmed in reward-draft.md**: offers are a pure function of `(run_state, stream)`; treasure offers are drawn before bundle offers on the same floor; `draft_state` is JSON-only |
| **Treasures** | downstream (applied by the run at match start) | `installers_for(treasure_ids[]) → hook_installers[]` in list order; reads/writes `treasure_state` | `treasures[]` in pick order at every `begin_match`; nothing at pick time | **Contract — to be confirmed in treasures.md**: a treasure is stateless between matches unless it uses `treasure_state`; applying = installing hooks (Match Rules hook table); no treasure mutates `RunState` |
| **Meta Progression / Persistence** | downstream (record) and upstream (unlock check, storage) | `is_hero_unlocked(id)`, `load_active_run()`, `save_active_run()` result codes | `RunRecord` dict at every save point and `archive_run(record)` at run end; `seed_source`, `abandon_reason` for statistics | **Contract — to be confirmed in meta-progression.md**: Meta owns file format, path, atomic write, `log_schema_version` migration, and how `abandoned/player` counts (this GDD says: as a loss); it never mutates a record |
| **Run UI** | downstream | Commands: `new_run`, `begin_match`, `draft_pick`, `abandon`, `resume`, `return_to_menu` | The run-scope event stream; `RunState` read model (floor, band, boss intro data, progress strip, summary data, `run_seed_hex`); rejection codes | This GDD; UI is display-only (`src/ui/**`) |
| **Boss AI** | indirect | — | `ai_id` and `rng_ai` inside `MatchConfig` | Boss AI; the run never talks to the AI directly |
| **Content** | soft | Pool sizes per band (6/6/4 target, DD-R02; 2/1/1 MVP) | `run_warning{boss_pool_short}` when a band is short | Content authors bosses; this GDD degrades gracefully |

## Formulas

`systems-designer` not consulted — Lean mode and no `Agent` tool in this session; review the
targets in F6–F7 before the first balance pass.

### F1. Floor band

The `band` formula is defined as:

`band(f) = 1 if f ≤ s1; 2 if f ≤ s1 + s2; 3 otherwise`, and
`first_floor_of_band(b) = 1, s1 + 1, s1 + s2 + 1` for `b = 1, 2, 3`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| f | int | 1 – floors_per_run | calculated | Floor number |
| s1, s2, s3 | int | 1 – 6 each; s1 + s2 + s3 = floors_per_run | data file (`band_split`, default `[3, 3, 2]`; MVP `[2, 1, 1]`) | Floors per band (DD-R01) |

**Output Range:** 1–3. **Example:** defaults → floors 1–3 band 1, 4–6 band 2, 7–8 band 3; MVP
→ floors 1–2 band 1, 3 band 2, 4 band 3. A `band_split` whose sum ≠ `floors_per_run` is a config
error (Edge Cases).

### F2. Boss sequence generation (DD-R01, DD-R02)

The `boss_sequence` formula is defined as:

```
for b in 1..3:
    pool_b = sort_by_id(CardDatabase.bosses_in_band(b))
    run.shuffle(pool_b)                      # exactly one shuffle per band, band order
    seq_b  = [ pool_b[i mod len(pool_b)] for i in 0 .. s_b − 1 ]   # wraps only if short
boss_sequence = seq_1 ++ seq_2 ++ seq_3
if no_adjacent_shared_theme: adjacency_pass(boss_sequence)       # no RNG draws
```

`adjacency_pass`: for `i` in `1 .. F − 1`, if `tags(seq[i]) ∩ tags(seq[i−1]) ≠ ∅`, swap `seq[i]`
with the first `j > i` **in the same band** whose tags are disjoint from `tags(seq[i−1])`; if
none exists leave it and emit `run_warning{theme_adjacent, floor: i + 1}`. Deterministic,
draw-free, so turning the knob on or off does not change the band draws.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| pool_b | BossDef[] | 0 – 20 per band | Card Database `bosses_in_band(b)` | Available bosses; 6/6/4 at v1, 2/1/1 at MVP |
| s_b | int | 1 – 6 | data file (`band_split`) | Floors in band b |
| run | stream | — | RNG & Event Log `stream("run")` | The only stream used; draw order fixed as above |
| no_adjacent_shared_theme | bool | — | data file (default `false`) | Requires `BossDef.tags[]`, not in Card Database CR-3 today (Open Questions) |

**Output Range:** `F` boss ids; distinct whenever `len(pool_b) ≥ s_b` for every band (DD-R02);
repeats, flagged by `run_warning{boss_pool_short, band, needed, available}`, only when a band
is short. **Example:** `run_seed = 0x000000000000002A`, pools `[boss_a, boss_b, boss_c, boss_d,
boss_e, boss_f]` per band: the sequence is whatever three shuffles on that seed yield, and the
acceptance tests pin the exact ids once the generator is in place (AC-3). Same seed, same
`data_version`, same ids — forever.

### F3. Boss health (escalation)

The `boss_health` formula is defined as:

`boss_health(f) = BossDef.health + floor_health_bonus × (f − first_floor_of_band(band(f)))`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| BossDef.health | int | 20 – 60 | data file (`bosses.json`; defaults 30/40/50 by band, DD-M02, registry `boss_starting_health_by_band`) | The boss's authored health |
| floor_health_bonus | int | 0 – 5 | data file (default **0**) | Extra health per floor within a band; v1 escalates by band and passive only (Pillar 2: puzzles, not stat walls) |

**Output Range:** 30/40/50 at defaults; with bonus 2 → 30, 32, 34, 40, 42, 44, 50, 52.
**Example:** floor 5, band 2, bonus 0 → 40. The value is passed in `MatchConfig.boss.health`;
Match Rules C3 step 2 reads it as the boss's starting health.

### F4. Deck size by floor (DD-R06)

The `deck_size` formula is defined as:

`deck_size(f) = starter_deck_size + bundle_card_count × (f − 1)` (at match start on floor f)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| starter_deck_size | int | 15 | registry constant (Card Database, DD-R03) | Starter deck |
| bundle_card_count | int | 3 | registry constant (Card Database, DD-R04) | Cards per bundle pick |

**Output Range:** 15 → 36 over floors 1–8; 15 → 24 at MVP (4 floors). `treasures_held(f) = |{t
∈ treasure_floors : t < f}|` → 0, 1, 1, 2, 2, 3, 3, 3. **Example:** floor 6 → 15 + 3 × 5 = 30
cards, 3 treasures.

### F5. Expected run length

The `run_minutes` formula is defined as:

```
match_minutes(f) = turns_to_lethal(H = boss_health(f), k = k_f) × seconds_per_turn_pair / 60
run_minutes(victory) = Σ_{f=1..F} [ intro_s/60 + match_minutes(f) ]
                     + (F − 1) × draft_s/60 + |treasure_floors| × draft_s/60 + select_s/60
run_minutes(expected) = select_s/60 + Σ_{f=1..F} p_reach(f) × [ intro_s/60 + match_minutes(f)
                     + win_rate(f) × drafts_after(f) × draft_s/60 ]
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| turns_to_lethal | int | 6 – 12 | registry formula (Match Rules F8) | Turns per side to lethal at face-damage rate k |
| k_f | float | 0.6 – 0.95 | calculated (model: `0.6 + 0.05 × (f − 1)`) | Player damage density grows with the drafted deck |
| seconds_per_turn_pair | int | 15 – 45 | data file (default 25: ~18 s player, ~7 s boss) | Wall time per player+boss turn; analysis knob only |
| intro_s, draft_s, select_s | int | 5–20, 15–60, 15–60 | data file (defaults 10, 30, 30) | Boss intro, one draft, hero select |
| p_reach(f), win_rate(f) | float | 0 – 1 | F6 | Probability the median player reaches floor f; target win rate on it |

**Output Range:** victory run ≈ **40 min** at defaults (matches ≈ 33 min: turns per side
10, 10, 9, 10, 10, 10, 11, 10 → 4.2 / 4.2 / 3.8 / 4.2 / 4.2 / 4.2 / 4.6 / 4.2; drafts 10 × 0.5 = 5;
intros 1.3; select 0.5), inside the concept's 30–45 min; expected (median, F6 targets) ≈
**22 min**, which is Pillar 3's "lose fast". MVP victory run ≈ 20 min. **Example:** floor 7,
H = 50, k = 0.9 → cumulative 49.5 at turn 10, 58.5 at turn 11 → 11 turns → 4.6 min.

### F6. Floor win-rate targets and measurement

The `win_rate` and `p_reach` formulas are defined as:

```
win_rate(f)  = wins(f) / matches(f)
matches(f)   = count of archived run records with a match_summary for floor f
wins(f)      = count of those whose floor-f summary has result = win
p_reach(f)   = Π_{i<f} win_rate(i)              # p_reach(1) = 1
expected_floors_cleared = Σ_f p_reach(f) × win_rate(f)
p_victory    = p_reach(F) × win_rate(F)
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| target_win_rate_by_floor | float[] | 0.2 – 0.95 | data file (default `[0.90, 0.85, 0.80, 0.70, 0.65, 0.60, 0.50, 0.40]`; MVP `[0.90, 0.80, 0.65, 0.45]`) | Design targets for the median target-audience player; `/balance-check` compares measured vs target |
| min_sample | int | 20 – 200 | data file (default 30) | Below this many `matches(f)` the measured rate is reported `NOT ASSESSED`, not compared |

**Output Range:** with the default targets `p_reach` = 1, .90, .765, .612, .428, .278, .167,
.084; `p_victory` ≈ **3.3 %**; `expected_floors_cleared` ≈ **3.3** (the median run ends on floor
4 or 5). This is deliberately roguelike-steep: the full clear is the mastery goal (Killers,
MDA Challenge #1) while 90 % on floor 1 protects onboarding. Abandoned runs contribute to
`matches(f)` only for floors they actually played; a restarted match (R8) counts once, by its
last attempt. **Example:** 200 runs, 140 reach floor 3, 108 win it → `win_rate(3)` = 0.77 vs
target 0.80 → within tolerance; 25 reach floor 7 → `NOT ASSESSED` (below `min_sample`).

### F7. Difficulty curve by floor (defaults; structure from `templates/difficulty-curve.md`)

Philosophy: *accessible entry, steep optional depth* — floor 1 is near-safe, the full clear is
rare; the player is allowed to feel outmatched for one match, never confused about why (Pillar
3 / Pillar 4). Axes: **decision complexity** (drafts, 100 % player-controlled), **knowledge**
(boss passives, telegraphed; learnable across runs), **resource pressure** (health race, k).

| Floor | Band | Boss health (F3) | Deck at start (F4) | Treasures held | Model turns/side (F5) | Target win rate (F6) | p_reach | Primary challenge | Target player state |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 30 | 15 | 0 | 10 | 0.90 | 1.00 | Knowledge (learn the loop) | Safe, curious |
| 2 | 1 | 30 | 18 | 1 | 10 | 0.85 | 0.90 | Decision (first plan commit) | Building a plan |
| 3 | 1 | 30 | 21 | 1 | 9 | 0.80 | 0.77 | Decision | Confident |
| 4 | 2 | 40 | 24 | 2 | 10 | 0.70 | 0.61 | Knowledge **spike** (first band-2 passive, +10 health) | Tested; first likely death |
| 5 | 2 | 40 | 27 | 2 | 10 | 0.65 | 0.43 | Resource pressure | Invested; plan paying off or not |
| 6 | 2 | 40 | 30 | 3 | 10 | 0.60 | 0.28 | Decision (last treasure, floor 5, **valley**) | Powerful |
| 7 | 3 | 50 | 33 | 3 | 11 | 0.50 | 0.17 | Knowledge **spike** (band-3 passive) | Challenged; mastery check |
| 8 | 3 | 50 | 36 | 3 | 10 | 0.40 | 0.08 | All axes (climax) | Peak; victory earned |

Spikes are band entries (floors 4 and 7); valleys are the treasure floors (1, 3, 5), where the
reward is a rule change rather than three cards. Recovery design after each spike: the next
floor is the same band with a now-known passive family and a bigger deck. Balancing levers and
their owners: `band_split`, `treasure_floors`, `floor_health_bonus` (this GDD); boss health and
passives (Content, Card Database); `k` via card damage density (Content, `/balance-check`);
`STARTING_HEALTH_PLAYER` (Match Rules). MVP (4 floors, `[2, 1, 1]`): the table collapses to
floors 1, 2, 4, 7 of the above with targets `[0.90, 0.80, 0.65, 0.45]`.

## Edge Cases

`systems-designer` not consulted — Lean mode and no `Agent` tool in this session.

**Configuration and content**
- **If `sum(band_split) ≠ floors_per_run`, or `floors_per_run < 1`, or a band split entry is 0**:
  `new_run` is rejected `E_CONFIG` and the menu shows the error; no run starts. A misconfigured
  run would save a layout that F1 cannot interpret.
- **If a band's pool is smaller than its split** (`len(pool_b) < s_b`): F2 wraps the shuffled
  pool so the same boss appears twice in that band, emits `run_warning{boss_pool_short, band,
  needed, available}` once at run start, and the run proceeds. Card Database does not block on
  pool size for bosses, so this is the only place it is checked. An **empty** band pool is
  `E_CONFIG` — nothing can be wrapped.
- **If a treasure floor is `≥ floors_per_run`**: it is ignored (no draft after the last floor);
  MVP's `[1, 3, 5]` therefore yields treasure drafts on floors 1 and 3 only, needing 6 distinct
  treasures (DD-H06's 10 is enough).
- **If `treasure_floors` is empty**: every reward phase is a bundle draft; the run is legal.
- **If the hero's `starter_deck` is not 15 cards or references unknown ids**: Card Database
  refuses to load (`E_COUNT`/`E_UNKNOWN_REF`), so the game never reaches hero select; this GDD
  adds no second check.
- **If `no_adjacent_shared_theme` is on and `BossDef` has no `tags`**: every boss has `∅` tags,
  the pass is a no-op and no warning is emitted — the knob is inert until Card Database adds the
  field (Open Questions).

**Match outcomes**
- **If both heroes reach 0 in the same action**: Match Rules reports `winner = boss, reason =
  both_dead` (DD-M12) → defeat; the summary says "mutual destruction — the boss wins ties".
- **If the player concedes**: defeat with `reason = concede`; counted as a loss. Conceding is
  the only way to leave a match with a recorded result; it is never an abandon.
- **If the match ends by `turn_cap`**: defeat, reason `turn_cap`; a `run_warning{turn_cap}` is
  also emitted because a 100-turn match in normal play is a content or AI problem.
- **If Match Rules reports `result = fault`**: `match_faulted`, back to `pre_match` on the same
  floor, attempt counter unchanged until the next `begin_match`; the floor is not lost (R4).
- **If the player is defeated on floor 1**: a normal defeat record with `floors_cleared = 0`,
  `floor_reached = 1`, `matches_played = 1`; the summary shows one match and the seed; "Run
  again" is offered exactly as after any other defeat (Pillar 3).
- **If a match ends before the player dealt any damage** (turn-1 concede): `damage_by_card` is
  `{}`; the summary shows "no damage dealt" rather than an empty table.

**Saving, quitting, resuming**
- **If the app quits or crashes during a match**: nothing is saved; on resume the run is at
  `pre_match` for that floor; `begin_match` increments `match_attempts[floor]` and replays the
  same streams (R8.3). The summary later shows `attempt: 2` for that floor.
- **If the app quits during a treasure draft (before the pick)**: the S2 save is at
  `post_match_reward / treasure` with `draft_<floor>` at `draws = 0`; resume regenerates the same
  three treasure offers. **If it quits after the treasure pick but before the bundle pick**: the
  S3 save holds the treasure and the stream position; resume regenerates the same bundle offers
  (R5.2 contract). Neither case loses the won match.
- **If `save_active_run` fails** (`E_IO`): `run_warning{save_failed}` is shown once per failure,
  the run continues in memory, the next save point retries; if the player quits before a
  successful save, resume lands at the last good save and the floors since are replayed (same
  streams, same offers — the player loses time, not determinism).
- **If the save has a different `data_version`** than the installed data, or an id no longer
  resolves: `abandoned / data_version_mismatch`, archived, not a loss, dialog "This run was
  started on a different data version and cannot be resumed" with "New run". Matches RNG & Event
  Log's provisional rule.
- **If the save fails `schema_version` or structural validation** (`E_SCHEMA`, `E_CORRUPT`):
  `abandoned / save_corrupt` if any of `run_id, hero_id, started_at` parse (so Meta can record
  that a run existed), otherwise the slot is cleared silently with a console warning; never a
  loss; never a crash.
- **If the saved `status` is `in_match`**: coerced to `pre_match` on the same floor with
  `run_warning{coerced_status}` (R8.6).
- **If the hero is locked at resume** (profile changed, unlock data edited): resume proceeds;
  `run_warning{hero_locked_at_resume}` is logged; the lock gates `new_run` only.
- **If `new_run` is issued while an active run exists**: the UI must have confirmed; the old run
  ends `abandoned / player` (a loss) and is archived before the new one starts. Two active runs
  never exist (DD-R08).
- **If `resume` is issued while a run is active**: rejected `E_BAD_PHASE`; no state change.

**Idempotency and double application**
- **If a treasure would be applied twice** (resume after S3, or a replayed `draft_pick`):
  impossible by construction — treasures are ids installed once per match start from
  `treasures[]`, and a second `draft_pick` for the same `(floor, kind)` is `E_DRAFT_DONE`
  (R8.5). Test AC-17 pins it.
- **If a `draft_pick` names an id that was not offered**: `E_NOT_OFFERED`; the offer stays open.
- **If `match_ended` arrives twice for one match** (engine bug): the second is rejected
  `E_BAD_PHASE` because the run has left `in_match`; a console error is raised.

**Seeds and identity**
- **If two runs share a `run_seed`** (random collision, or a deliberate replay): legal and
  expected; `run_id` includes `started_at` so records and archived log folders stay distinct.
  RNG & Event Log rule 18 keys match-log folders by `run_seed_hex` alone — flagged for that GDD
  (Open Questions) to add `started_at`.
- **If the typed seed re-parses to a different value than displayed**: cannot happen — the
  displayed form is the 16-hex form, which F1 parses back bit-for-bit; the UI shows the
  normalised hex next to the field after entry so the player sees what will be used.
- **If `allow_custom_seed` is off and a seed is passed anyway** (modded UI): ignored,
  `seed_source = random`, `run_warning{seed_ignored}`.

**Bounds and time**
- **If the run record grows past `max_run_record_bytes`** (default 256 KB; eight summaries with
  full `damage_by_card` are ~20–40 KB, so this needs a pathological card pool): each summary's
  `damage_by_card` is reduced to its top 20 entries plus an `other` bucket before saving and
  `run_warning{record_truncated}` is emitted; totals are computed before truncation. The run log
  itself is bounded by the RNG & Event Log caps and is not truncated here.
- **If the system clock moves backwards**: `play_seconds` is monotonic-tick based and
  unaffected; `ended_at < started_at` is stored as-is and Run UI clamps displayed duration at 0.
- **If `floors_per_run` is changed in data while a run is saved**: the saved record carries its
  own `floors_per_run`, `band_split` and `treasure_floors` (R1) and finishes on the layout it
  started with; the new layout applies to the next `new_run`.

## Dependencies

Hard = the run cannot start or finish without it; soft = the run works with a null
implementation. Bidirectional check against `design/gdd/systems-index.md`: the index lists Run
Structure as depending on Match Rules, Heroes, Card Database and RNG & Event Log (all below), and
lists Reward Draft, Treasures, Meta Progression and Run UI as depending on Run Structure (all
below) — consistent. Match Rules (its Dependencies) and RNG & Event Log (its Dependencies) and
Card Database (its Dependencies) each already name Run Structure — consistent. Heroes, Reward
Draft, Treasures, Meta Progression and Run UI have no GDD yet; their rows are provisional.

| System | Direction | Hard/Soft | Nature of dependency / interface |
|---|---|---|---|
| Card Database | This depends on Card Database | Hard | `bosses_in_band(band)` id-sorted for F2; `hero(id).starter_deck` for R2; `boss(id)` fields for `MatchConfig`; `data_version` for the record. This GDD owns draw-without-replacement; Card Database owns record shapes and load-time validation. |
| RNG & Event Log | This depends on RNG & Event Log | Hard | Creates the service with `run_seed`; `run` stream (3 shuffles, F2); `match_<f>`, `ai_<f>`, `draft_<f>` streams handed to partners; `snapshot()`/`restore()` for S1–S4 and R8; the run log lifecycle (`run_started` opens, `run_ended` seals); `match_summary` reduction. |
| Match Rules | Mutual | Hard | Out: `MatchConfig` (R3). In: `MatchResult` via `match_ended` (C14) including `result = fault`. Match Rules owns everything inside a match; this GDD owns what happens before and after, and never saves mid-match. |
| Heroes | This depends on Heroes (data) | Hard | `starter_deck` (15), `hero_power`, `health` through Card Database records. **Contract**: the run never edits the starter list; Heroes owns composition and unlock keys. |
| Reward Draft | Reward Draft depends on this | Hard (for them) | Invoked by the run between floors: `offer(kind, run_state, draft_stream)`; treasure before bundle on the same floor; picks returned via `draft_picked`; `draft_state` persisted opaquely by the run. **Contract** (R5, Interactions). |
| Treasures | Treasures depends on this | Hard (for them) | `installers_for(treasure_ids)` at every `begin_match`, in pick order; `treasure_state` persisted opaquely; no effect at pick time. **Contract** (R5.6, R8.5). |
| Meta Progression / Persistence | Mutual | Soft for starting a run (MVP: `is_hero_unlocked` is always true, saves may be in-memory); Hard for DD-R08 | Receives `RunRecord` at S1–S5 and `archive_run` at run end; owns file format, path, atomic write, migrations; answers `is_hero_unlocked`. **Contract** (R7). This GDD states `abandoned/player` counts as a loss and `seed_source = custom` should be excluded from personal bests; Meta confirms. |
| Run UI | Run UI depends on this | Soft (the machine runs headless in tests) | Issues the six commands; renders hero select, boss intro, progress strip, draft picker (with Reward Draft), summaries from the read model and the run-scope events. |
| Boss AI | Indirect | Soft | Receives `ai_id` and `rng_ai` through `MatchConfig`; no direct interface. |
| Content | Content depends on this | Soft | Pool sizes per band must cover `band_split` (6/6/4 ≥ 3/3/2; MVP 2/1/1 ≥ 2/1/1 exactly — no slack, see Open Questions); `target_win_rate_by_floor` is Content's tuning target. |

## Tuning Knobs

All in `assets/data/run_structure.json` unless noted. Knobs owned elsewhere are pointed to, not
duplicated. `systems-designer` not consulted — Lean mode; `floors_per_run`, `band_split` and
`treasure_floors` interact (changing the first without the other two is `E_CONFIG` or silently
drops treasure floors), so check all three together.

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `floors_per_run` | 8 (MVP 4) | 3 – 12 | Longer runs, larger final decks (F4), lower `p_victory` (F6); above 12 the deck passes 48 cards and drafts stop mattering | Shorter runs; below 3 there is no band progression and treasure cadence collapses |
| `band_split` | `[3, 3, 2]` (MVP `[2, 1, 1]`) | each ≥ 1; sum = `floors_per_run` | More floors in a band = more time at that health tier; a long band 1 makes early runs feel flat | A 1-floor band 3 makes the climax a single coin-flip match |
| `treasure_floors` | `[1, 3, 5]` | subset of `1 .. floors_per_run − 1`; count × 3 ≤ unlocked treasures | More treasures = stronger, stranger decks (Pillar 1), needs a larger pool (Card Database `min_treasure_pool`) | Fewer rule-benders; `[]` is a pure bundle run |
| `floor_health_bonus` | 0 | 0 – 5 | Within-band escalation by stats; above 2 it competes with passives for the escalation role (anti-Pillar 2) | — |
| `no_adjacent_shared_theme` | false | bool | Reduces back-to-back samey bosses; inert until `BossDef.tags` exists | — |
| `allow_custom_seed` | true | bool | Replayable gauntlets, shareable seeds (DD-R09) | Hides the seed field; seeds still shown on summaries |
| `abandon_counts_as_loss` | true | bool | Honest win rates; abandon has a (statistical) cost | Free re-rolls of bad starts; F6 measurements overstate skill |
| `target_win_rate_by_floor` | `[.90, .85, .80, .70, .65, .60, .50, .40]` (MVP `[.90, .80, .65, .45]`) | monotone non-increasing, 0.2 – 0.95 | Easier intended curve; `/balance-check` flags Content as too hard sooner | Steeper; below 0.8 on floor 1 the onboarding promise breaks |
| `min_sample` | 30 | 20 – 200 | Fewer false alarms from F6, slower feedback | Noisier comparisons |
| `seconds_per_turn_pair`, `intro_s`, `draft_s`, `select_s` | 25, 10, 30, 30 | 15–45, 5–20, 15–60, 15–60 | Analysis-only inputs to F5; re-measure from `play_seconds` once real runs exist | — |
| `summary_top_cards` | 10 | 5 – 36 | Longer damage table on the summary screen | Terser summary |
| `max_run_record_bytes` | 262144 | 65536 – 1048576 | Later truncation of `damage_by_card` | Earlier truncation; below 64 KB eight full summaries may not fit |
| `RUN_RECORD_SCHEMA_VERSION` | 1 | constant (code) | Bumped only with a Meta Progression migration | — |
| Boss health by band | 30 / 40 / 50 | Match Rules / `bosses.json` | See `design/gdd/match-rules.md` Tuning Knobs — not duplicated here | — |
| Starter deck size, bundle size | 15, 3 | Card Database | Registry constants; F4 reads them | — |

## Visual/Audio Requirements

Optional for `Progression`; a brief note suffices. `art-director` not consulted — Lean mode.
Everything here is rendered by Run UI from the run-scope events; this system emits no visuals.

| Event | Visual Feedback | Audio Feedback | Priority |
|---|---|---|---|
| `run_floor_entered` | Boss intro card slides in: portrait slot, band pips (1–3, band colour desaturated per art bible), passive text lit, floor "n of F" | Boss intro sting per band (3 variants) | High |
| `deck_grew` / `treasure_granted` | Cards/treasure fly to the deck/treasure tray; progress strip advances one pip | Draft confirm | Medium |
| `run_ended{victory}` | Victory summary: warm full-screen light, deck fanned, seed hex | Victory stinger | High |
| `run_ended{defeat}` | Death summary: cool desaturated board, killing boss highlighted, seed hex | Defeat stinger (short — Pillar 3, not a dirge) | High |
| `run_warning` | Small toast, never modal | None | Low |

## Game Feel

Not applicable: the run is not an operated mechanic (no input latency, frames or impact
moments). The one feel target it owns is **restart speed** — from the defeat summary's "Run
again" to the floor-1 boss intro in under 5 s (concept: "a loss returns to hero select in under
five seconds"); tracked under Acceptance Criteria AC-29.

## UI Requirements

Screens belong to Run UI (`/ux-design` specs); this table says what the run must expose.

| Information | Display Location | Update Frequency | Condition |
|---|---|---|---|
| Hero roster with locked state; selected hero's starter deck preview and hero power | Hero select | On open, on selection | `hero_select` |
| Seed field with normalised hex echo; "Random" default | Hero select | On edit | `allow_custom_seed` |
| Continue card: hero, floor "n of F", phase, last played time; "Abandon run" with confirmation | Main menu | On menu open | Active run saved |
| Resume-failure reason dialog with "New run" | Main menu | Once | `validate() != OK` |
| Boss name, band pips, health, passive text, hero power text, intro line, floor "n of F"; "Fight" | Boss intro | On `run_floor_entered` | `pre_match` |
| Floor progress strip: F pips — cleared / current / upcoming; upcoming shows band only, never the boss identity | Boss intro, draft picker, pause menu | Per floor | Any run state |
| Draft picker: kind header ("Treasure" then "Bundle"), three offers, pick confirm | Reward screen | Per draft | `post_match_reward` |
| Pause menu: Concede (in match) / Abandon run (between matches), Quit to menu with "progress since the last save will be replayed" note when in a match | Pause | On open | `in_match` vs other |
| Summary: outcome, floor reached / cleared, killing boss, matches and turns, duration, deck list in acquisition order with drafted cards marked, treasures, top-N damage by card, seed hex with Copy, `attempt > 1` floors marked; "Run again", "Menu" | Victory / Death summary | Once | Terminal states |
| Warning toasts (`boss_pool_short`, `save_failed`, …) | Overlay | On event | `run_warning` |

> **📌 UX Flag — Run Structure**: This system has UI requirements. In Pre-Production, run
> `/ux-design` for hero select, boss intro, draft picker (with Reward Draft), pause menu and the
> run summary **before** writing epics. Stories that reference UI should cite `design/ux/[screen].md`,
> not this GDD.

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|---|---|---|---|
| `MatchConfig` fields, hook installation order, `on_match_start` | `design/gdd/match-rules.md` | C3 Match setup, Interactions hook table | Ownership handoff |
| `MatchResult` winners and reasons; `fault` result | `design/gdd/match-rules.md` | C14 Win, loss and concede; DD-M12 | State trigger |
| Boss health 30/40/50 default | `design/gdd/match-rules.md` | C3 step 2, registry `boss_starting_health_by_band` | Data dependency |
| Expected match length | `design/gdd/match-rules.md` | F8 `turns_to_lethal` | Data dependency |
| `run_seed` parsing from input | `design/gdd/rng-event-log.md` | F1 | Rule dependency |
| Named streams and ownership, draw-only-in-commands | `design/gdd/rng-event-log.md` | Core Rules A.3, B.8 | Rule dependency |
| `snapshot()` / `restore()` | `design/gdd/rng-event-log.md` | Core Rules B.10, F5 | Data dependency |
| Event catalogue rows this GDD emits; `match_summary`; run log sealing | `design/gdd/rng-event-log.md` | Core Rules D, E.18–19, States | Ownership handoff |
| `data_version` mismatch → abandoned | `design/gdd/rng-event-log.md` | Edge Cases (provisional) | Rule dependency |
| `bosses_in_band(band)` id-sorted; BossDef fields | `design/gdd/card-database.md` | CR-3 BossDef, CR-6 lookups | Data dependency |
| `starter_deck` exactly 15; `starter_deck_size`, `bundle_card_count` | `design/gdd/card-database.md` | CR-3 HeroDef/BundleDef, registry constants | Data dependency |
| `min_treasure_pool` = 9 | `design/gdd/card-database.md` | Formulas | Rule dependency |
| Starter deck composition, unlock keys | `design/gdd/heroes.md` *(planned)* | HeroDef ownership | Data dependency (contract) |
| Offer generation, treasure-before-bundle draw order, `draft_state` | `design/gdd/reward-draft.md` *(planned)* | R5 contract | Ownership handoff (contract) |
| `installers_for`, statelessness, `treasure_state` | `design/gdd/treasures.md` *(planned)* | R5.6 / R8.5 contract | Ownership handoff (contract) |
| Persistence API, `archive_run`, loss accounting for abandon, custom-seed exclusion | `design/gdd/meta-progression.md` *(planned)* | R7 contract | Ownership handoff (contract) |
| Screens and read model | `design/gdd/run-ui.md` *(planned)* | UI Requirements | Data dependency |

## Acceptance Criteria

`qa-lead` not consulted — Lean mode and no `Agent` tool in this session; review testability
before the first sprint. All tests are headless, inject a literal seed through RNG & Event Log,
use a fixture `bosses.json` with 6/6/4 bosses (`boss_a1..a6`, `boss_b1..b6`, `boss_c1..c4`) and a
fixture hero `hero_war` with a 15-card starter deck, and stub Match Rules with a scripted
`match_ended`. Story type: Logic (unit, BLOCKING) unless marked UI.

**Sequence generation and layout (F1–F3)**
- [ ] AC-1 **GIVEN** `band_split = [3, 3, 2]`, **WHEN** `band(f)` is evaluated for f = 1..8, **THEN**
  it returns 1,1,1,2,2,2,3,3 and `first_floor_of_band` returns 1, 4, 7.
- [ ] AC-2 **GIVEN** seed `0x000000000000002A` and the fixture pool, **WHEN** `new_run(hero_war, "42")`
  runs, **THEN** `boss_sequence` has 8 distinct ids, floors 1–3 are from `boss_a*`, 4–6 from
  `boss_b*`, 7–8 from `boss_c*`, and the `run` stream reports exactly 3 shuffle calls.
- [ ] AC-3 **GIVEN** the same seed, hero and `data_version`, **WHEN** `new_run` runs twice (two
  services), **THEN** both `boss_sequence` arrays are identical; **AND** with seed `"43"` the
  sequence differs in at least one position.
- [ ] AC-4 **GIVEN** band 3 holds only `boss_c1`, **WHEN** `new_run` runs, **THEN** floors 7 and 8
  are both `boss_c1`, exactly one `run_warning{boss_pool_short, band: 3, needed: 2, available: 1}`
  is emitted, and the run reaches `pre_match`.
- [ ] AC-5 **GIVEN** band 2 is empty or `band_split = [3, 3, 3]` with `floors_per_run = 8`,
  **WHEN** `new_run` is issued, **THEN** it is rejected `E_CONFIG`, no `run_started` is emitted
  and no save is written.
- [ ] AC-6 **GIVEN** `floors_per_run = 4`, `band_split = [2, 1, 1]`, `treasure_floors = [1, 3, 5]`,
  **WHEN** a run is created, **THEN** `band(f)` = 1,1,2,3, the sequence has 4 ids (2 from band 1),
  and the effective treasure floors are `[1, 3]`.
- [ ] AC-7 **GIVEN** `floor_health_bonus = 2` and `boss_b2.health = 40` on floor 5, **WHEN** the
  `MatchConfig` is built, **THEN** `boss.health = 42`; **AND** with bonus 0 it is 40.
- [ ] AC-8 **GIVEN** `no_adjacent_shared_theme = true` and fixture tags making `seq[1]` share a tag
  with `seq[0]` while `seq[2]` does not, **WHEN** the sequence is generated, **THEN** `seq[1]` and
  `seq[2]` are swapped, no further draw is taken from `run`, and with the knob `false` the
  unswapped order is produced from the same seed.

**Phase machine (T1–T18)**
- [ ] AC-9 **GIVEN** a fresh run in `pre_match` on floor 1, **WHEN** `begin_match` is issued, **THEN**
  Match Rules receives a `MatchConfig` with `floor 1`, `player.deck` of 15 ids equal to the starter
  deck, empty `player.hook_installers`, `boss.boss_def_id = boss_sequence[0]`, the memoised
  `match_1` and `ai_1` streams, and `match_attempts[1] == 1`.
- [ ] AC-10 **GIVEN** `in_match` on floor 2, **WHEN** `match_ended{winner: player}` arrives, **THEN**
  status is `post_match_reward`, `reward_step == bundle` (2 ∉ treasure floors), a
  `match_summary` with `boss_id, band 1, attempt 1` is stored, and `run_saved{floor: 2, phase:
  post_match_reward}` is emitted after it.
- [ ] AC-11 **GIVEN** `in_match` on floor 3 (a treasure floor), **WHEN** the player wins, **THEN**
  `reward_step == treasure`; **WHEN** `draft_pick(treasure, id)` with an offered id follows, **THEN**
  `treasures == [id]`, `treasure_granted` is emitted, `reward_step == bundle`, a save follows;
  **WHEN** `draft_pick(bundle, id2)` follows, **THEN** the deck has 24 ids ending with that bundle's
  3 cards in bundle order, `deck_grew{deck_size: 24}` is emitted, `floor == 4`, status
  `pre_match`, `run_floor_entered{floor: 4, band: 2}` is emitted.
- [ ] AC-12 **GIVEN** `reward_step == treasure`, **WHEN** `draft_pick(bundle, …)` is issued, **THEN**
  it is rejected `E_DRAFT_KIND` with no state change and no event.
- [ ] AC-13 **GIVEN** `in_match` on floor 8 (`floors_per_run = 8`), **WHEN** the player wins, **THEN**
  status is `victory`, `result.floors_cleared == 8`, `run_ended{result: victory}` is the last
  event, `archive_run` was called once with a record whose `deck` has 36 ids, and
  `clear_active_run` was called.
- [ ] AC-14 **GIVEN** `in_match` on floor 1, **WHEN** `match_ended{winner: boss, reason: hero_dead}`
  arrives, **THEN** status is `defeat`, `floors_cleared == 0`, `floor_reached == 1`, `ended_by ==
  boss_sequence[0]`, `matches_played == 1`, and the record is archived.
- [ ] AC-15 **GIVEN** `in_match`, **WHEN** `match_ended{result: fault}` arrives, **THEN** status is
  `pre_match` on the same floor, `match_faulted{floor, attempt: 1}` is emitted, no summary is
  stored, and the next `begin_match` sets `match_attempts[floor] == 2`.
- [ ] AC-16 **GIVEN** `pre_match` on floor 5, **WHEN** `abandon()` is issued, **THEN** status is
  `abandoned`, `result.abandon_reason == player`, `floors_cleared == 4`, the record is archived;
  **AND GIVEN** `in_match`, **WHEN** `abandon()` is issued, **THEN** it is rejected `E_BAD_PHASE`.

**Save and resume (R7–R8)**
- [ ] AC-17 **GIVEN** a run saved at S3 (treasure `t1` picked on floor 3, bundle pending), **WHEN** it
  is resumed and the floor-4 match begins, **THEN** `installers_for` is called exactly once with
  `[t1]`, a repeated `draft_pick(treasure, t1)` on floor 3 is rejected `E_DRAFT_DONE`, and
  `treasures` still equals `[t1]`.
- [ ] AC-18 **GIVEN** a run saved at S2 on floor 3 with `draft_3` at `draws = 0`, **WHEN** it is
  resumed, **THEN** the three treasure ids offered equal the ids offered before the quit (same
  stub Reward Draft, same stream position); **AND** a run saved at S3 regenerates the same bundle
  offers.
- [ ] AC-19 **GIVEN** a run saved at S4 for floor 4 and a match started then abandoned by a
  simulated quit (no save), **WHEN** the run is resumed, **THEN** status is `pre_match`, floor 4,
  `run_resumed{floor: 4, phase: pre_match, attempt: 2}` is emitted, and the next `MatchConfig`
  carries `match_4` restored at `draws = 0`, so a stubbed deck shuffle yields the same order as the
  first attempt.
- [ ] AC-20 **GIVEN** a saved record whose `data_version` differs from the installed data, **WHEN**
  `resume` is issued, **THEN** `validate` returns `E_DATA_VERSION`, the record is archived with
  `outcome: abandoned, abandon_reason: data_version_mismatch`, the slot is cleared, and no loss
  is counted (asserted on the archived record's fields, not on Meta's statistics).
- [ ] AC-21 **GIVEN** a saved record with a corrupted `boss_sequence` (length 7), **WHEN** `resume`
  is issued, **THEN** `validate` returns `E_CORRUPT`, the outcome is `abandoned / save_corrupt`,
  and the game does not crash.
- [ ] AC-22 **GIVEN** `save_active_run` returns `E_IO` at S2, **WHEN** the player picks the bundle,
  **THEN** `run_warning{save_failed}` was emitted once, the run continued, and S4 is attempted
  again (stub returns OK and `run_saved` is emitted).
- [ ] AC-23 **GIVEN** the hero `hero_war` is locked in a stub Meta, **WHEN** `new_run(hero_war)` is
  issued, **THEN** `E_HERO_LOCKED`; **AND WHEN** a saved run for `hero_war` is resumed, **THEN**
  it proceeds with `run_warning{hero_locked_at_resume}`.

**Seeds, records, length (R9–R10, F5–F6)**
- [ ] AC-24 **GIVEN** seed input `"deckdelve"`, **WHEN** the run starts, **THEN** `run_seed_hex ==
  "48A10CC0B2ED54EC"`, `seed_source == custom`, and `new_run(hero, "48A10CC0B2ED54EC")` produces
  the same `boss_sequence`; **AND** with empty input `seed_source == random`.
- [ ] AC-25 **GIVEN** a completed 8-floor victory with scripted summaries, **WHEN** `totals` is
  computed, **THEN** `matches_played == 8`, `turns` equals the sum of the summaries' turns,
  `damage_by_card` equals the key-wise sum, `cards_drafted == 21`, `treasures_taken == 3`.
- [ ] AC-26 **GIVEN** the default targets, **WHEN** F6 is evaluated, **THEN** `p_reach(8)` is 0.084
  ± 0.001 and `expected_floors_cleared` is 3.27 ± 0.01; **AND GIVEN** 200 archived records with
  25 reaching floor 7, **THEN** floor 7 is reported `NOT ASSESSED` and floors 1–6 are reported with
  a rate.
- [ ] AC-27 **GIVEN** the F5 defaults, **WHEN** `run_minutes(victory)` is evaluated, **THEN** it is
  between 35 and 45; and `run_minutes(expected)` between 18 and 26.
- [ ] AC-28 **GIVEN** the full-run record of AC-13, **WHEN** serialised, **THEN** `to_dict()` →
  `from_dict()` → `to_dict()` is byte-identical JSON, under `max_run_record_bytes`, and contains
  no non-JSON value.
- [ ] AC-29 (UI, screenshot evidence) **GIVEN** the defeat summary, **WHEN** "Run again" is clicked,
  **THEN** the floor-1 boss intro of a new run with the same hero and a different seed is visible
  within 5 s.
- [ ] AC-30 Performance: `new_run` including sequence generation completes in under 5 ms headless;
  `validate` + `restore` of an S4 record on floor 8 in under 20 ms.
- [ ] AC-31 No hardcoded values: every knob in Tuning Knobs is read from `run_structure.json`
  (or the registry constant's owner file); a test that overrides `floors_per_run` to 4 through
  data alone produces AC-6's layout.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| `assets/data/run_structure.json` is a new data file not listed in DD-T01 — add it to the register (same situation as `match_rules.json`). | Owner (orchestrator) | Before `/create-architecture` | Open — proposed here |
| `MatchConfig.seed` (Match Rules C3) vs. passing the memoised `match_<floor>` / `ai_<floor>` streams (this GDD R3). One field name must win. | Match Rules GDD / `/consistency-check` | Before `/create-architecture` | Open — this GDD passes streams |
| Treasure-before-bundle on the same floor fixes Reward Draft's draw order on `draft_<floor>`; confirm or amend when Reward Draft is designed. | Reward Draft GDD | `/design-system reward-draft` | Contract proposed (R5.2) |
| `treasure_granted` is emitted by Run Structure (the append is its mutation) although the RNG & Event Log catalogue lists Reward Draft as owner; update the owner column or move the emit. | RNG & Event Log GDD / Reward Draft GDD | `/consistency-check` | Open — proposed: owner = Run Structure |
| Game concept says "the first treasure pick is always offered on floor 2"; DD-R05 says floors 1, 3, 5. This GDD follows DD-R05; the concept line should be corrected or DD-R05 revised with `/propagate-design-change`. | Owner | Before Reward Draft design | Open |
| `no_adjacent_shared_theme` needs `BossDef.tags[]` (`^[a-z_]+$`, may be `[]`), not in Card Database CR-3. Add the field or drop the knob. | Card Database GDD / Content | Alpha content pass | Open — knob inert until then |
| Mid-match restore from the event log (`restore(log)`) so a crash does not restart the match — currently restart with the same streams (R8.3). | Run Structure + Match Rules | Vertical Slice | Deferred; accepted for MVP |
| RNG & Event Log rule 18 keys archived match logs by `run_seed_hex` alone; a replayed seed would overwrite them. Suggest `<run_seed_hex>-<started_at>` (= `run_id`). | RNG & Event Log GDD | `/consistency-check` | Open — proposed here |
| MVP boss pool 2/1/1 equals `band_split [2, 1, 1]` exactly: every MVP run has the same four bosses, only band-1 order varies. Acceptable for the MVP hypothesis, or author one spare band-1 boss? | Owner / Content | MVP content plan | Open |
| Should `abandoned / player` count as a loss (this GDD: yes) and should `seed_source = custom` runs be excluded from personal bests (this GDD: yes, unlocks still count)? | Meta Progression GDD | `/design-system meta-progression` | Contract proposed (R6, R9) |
| Does any v1 treasure need cross-match state (`treasure_state`)? If none, drop the field before implementation. | Treasures GDD | `/design-system treasures` | Open — field reserved |
| `target_win_rate_by_floor` is an analysis knob living in a gameplay data file; move to a `balance/` config if `/balance-check` prefers. | systems-designer | First balance pass | Open |
