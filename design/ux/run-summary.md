# UX Spec: Run Summary (victory, defeat and abandoned variants)

> Authoring guidance: .claude/docs/templates/guidance/ux-spec-guide.md (load per-section as you author — do not read entirely).

> **Status**: Approved (`/ux-review` round 4, 2026-11-03)
> **Author**: Jacob + ux-designer (`/ux-design run-summary`, automation `guided`, workflow `standard`, density `balanced`; owner pre-approved the run — no `AskUserQuestion` used, recommended options taken and listed in the session report; no Agent tool — `art-director` / `ui-programmer` / `narrative-director` not spawned)
> **Last Updated**: 2026-11-03
> **Journey Phase(s)**: Session-level loop close — "victory screen or death screen with a run summary" (game-concept Core Loop) and the Pillar 3 restart path A "defeat → New Run (same hero)" (run-ui F1, 1350 ms). Terminal run phases `victory` / `defeat` / `abandoned` (run-structure R6). `design/player-journey.md` does not exist — see §15.
> **Screen / Flow Name**: `RunSummary` — one scene, three variants: `summary_victory`, `summary_defeat`, `summary_abandoned` (run-ui U2 ids). Also rendered read-only as `run_detail` from the Run Log (`run-log.md`, not this spec).
> **Platform Target**: PC (Windows primary, Linux dev/CI); 1280x720 logical, `canvas_items` + `keep` (DD-T05); mouse primary, keyboard complete; gamepad `Partial` post-v1; touch none.
> **Related GDDs**: `design/gdd/run-ui.md` U2 (`summary_victory` / `summary_defeat` / `summary_abandoned` rows), U3, U5 (toasts drain here; S-05 persistence), U9, States S16–S19, F1 (path A), F3, Edge Cases "Summaries and run log" / "Toasts and unlocks", Tuning Knobs (`default_focus.summary`, `summary_top_cards`), Visual/Audio, UI Requirements, AC-6, AC-7, AC-15, AC-17, AC-23, AC-26, AC-31, AC-32; `design/gdd/run-structure.md` R1 (`result`, `totals`, `match_summaries`, `drafts`, `deck`, `treasures`, `run_seed_hex`, `seed_source`, `match_attempts`), R6 (ending a run; abandon rules; `unlocks_granted`), R10 (summary fields, top-N damage, "and N more"), UI Requirements, Tuning Knobs (`summary_top_cards` 10); `design/gdd/meta-progression.md` M3.6 (`pending_notifications`, `ack_notification`, `unlock_granted`), M7 (abandon counts as a loss), M8 (archive), UI Requirements; `design/gdd/rng-event-log.md` UI Requirements (seed copyable, damage per card); `design/gdd/treasures.md` UI Requirements (treasures held on the summary); `design/gdd/match-ui.md` U9 (the `fault` path never reaches a summary); `design/design-decisions.md` DD-R07, DD-R09, DD-M12 (both dead → boss wins ties).
> **Related ADRs**: none yet.
> **Related UX Specs**: `design/ux/interaction-patterns.md` (Button (Primary / Secondary), Toast, Treasure Chip, Card Inspect, List Item, Scroll Container, Tooltip, Screen Push / Pop / Replace, Focus Management, Escape / Cancel, Standard Shortcuts, Success Confirmation "Copied", Empty State, Error State "Save failed"); `design/accessibility-requirements.md`; `hero-select.md` (exit; written in this run), `run-start.md` / `boss-intro.md` (exit via New Run), `main-menu.md`, `run-log.md` (`run_detail` reuses this layout), `toast.md` — not yet written.
> **Accessibility Tier**: Standard with reduce-motion, visual-for-every-sound and the high-contrast state set elevated (`design/accessibility-requirements.md`). The Run UI matrix row's requirement for this screen: "the defeat summary must say why you lost".
> **Template**: UX Spec
> **REVISED 2026-11-03 (ux-review)**: (1) abandoned variant is **one line + New Run · Main Menu** everywhere — no columns (§4, §5.1, §5.3, §6, §12, consistent with run-ui U2 `summary_abandoned`); (2) floors block kept and cited to run-ui U9's per-floor strip (§5.2, §15 resolved); (3) damage list → **8 visible rows at 44 px** (List Item rule) from y 108 to 460, "and N more" at y 468 — nothing reaches the status line at y 560; 7 / 6 rows at 125 / 150 % (§5.1, §5.2, §5.3, §6, §11, §14); (4) floors zone corrected to 72–292 (header 72, eight 24 px rows 100–292; deck header stays at 304); (5) fixtures `abandoned_sample` and `victory_sample_ts150` are run-ui U10 names (§4, §6, §14, §15); (6) §15 gamepad rows for every §11 untick; (7) `text_muted` on `table_lit` is now in art bible §4 at 5.08:1 — the victory variant's `text_light` substitution is **dropped**; `text_muted` is used on both backgrounds (§5.1, §12, §14, §15).
> **REVISED 2026-11-03 (ux-review round 3)**: (1) the seed row is **44 px tall at every scale** with a 44x44-or-larger Copy Control (80x44 with a 32 px visual at 100 / 125 %, a 44x44 glyph button at 150 %) and the left column is restated at 100 % (seed 380–424 defeat / 356–400 victory, Treasures 424–468 / 400–444, unlocks ≤ 2 / ≤ 3 lines ending 540), 125 % (seed 364–408 … "and n more" 512–532) and 150 % (seed 388–432, Treasures 432–476, header 476–500, line 500–524, "and n more" 524–548) — closes the round-3 blocker; §11 and the `defeat_sample_ts150` AC follow, and a 100 % Copy-size AC is added; (2) `defeat_sample_ts150` no longer asks for a `save_failed` warning the U10 variant does not carry; (3) strip zone 72–140 (392 x 68) covers the "×n" marks, which do not scale; (4) §2 / §12 retire the "floor list" / "✕ fell row" wording — strip cells have accessible names, §11 tab order and arrow keys include the strip; (5) `victory_sample` AC adds the eight cleared cells, no ring; (6) §5.3 cites the library's new Screen-Owned **Per-Floor Strip** row; §15 notes run-ui U9's wording fix.

> **Sources read** (by section): run-ui U1–U10, States, F1–F3, Edge Cases, Tuning Knobs, Visual/Audio, Game Feel, UI Requirements, AC; run-structure R1, R6, R10, UI Requirements, Tuning Knobs; meta M3, M7 (via R6), M8, F6, UI Requirements; rng-event-log and treasures UI Requirements; art bible §2 (Victory / Defeat moods), §4, §7; accessibility-requirements Visual, Motor, Cognitive, Per-Feature Matrix; interaction-patterns entries named above, Animation and Sound Standards.

> **Note — Scope boundary**: A terminal base screen of the run shell. Not a run screen (no Progress Strip, no pause overlay). Numbers marked *spec* are this document's; run-ui gives this screen no F-formula.

---

## 1. Purpose & Player Need

**What player need does this screen serve?**

After a loss the player needs to understand *why* — legibly, without punishment (art bible §2 "clear-eyed loss; never punishment"; Pillar 3 "every loss should teach something legible") — and then to be one key away from trying again. After a victory they need a moment of earned relief and a record worth keeping: what the deck became, which cards did the work, what they unlocked. In both cases the seed must be copyable so the run can be shared or replayed (DD-R09), and any unlock earned must be impossible to miss but never in the way of the restart.

**The player goal** (what the player wants to accomplish):

Read the outcome and its reason in one glance, optionally inspect the deck / damage table / treasures and copy the seed, and restart with the same hero in a single `Enter` (or switch hero / return to the menu in two).

**The game goal** (what the game needs to communicate or capture):

Render the sealed `RunRecord` (R6: `result`, `totals`, `match_summaries`, `deck`, `treasures`, `drafts`, `run_seed_hex`) plus Meta's `unlocks_granted[]` for this run, drain the unlock toast queue (acking each on show), repeat the latest actionable warning as a status line, and issue one of three exits — `new_run(hero_id, "")` with **no confirm** (U9; F1 path A), `return_to_menu` → hero select, or `return_to_menu`.

---

## 2. Player Context on Arrival

| Question | Answer |
|----------|--------|
| What was the player just doing? | Watching the match-end banner (victory, defeat, both-dead or concede) for up to 4 s; `run_ended` was buffered and applied at `match_view_finished` (S11 → S16). Abandoned: they confirmed Abandon from the pause menu or the resume prompt (S6, S17), or a system abandon ended the run on resume (R8). |
| What is their emotional state? | Defeat: frustration or resignation, but short-lived if the screen is quick and factual; Pillar 3 wants the restart reflex. Victory: relief, "a little disbelief" (art bible §2). Abandoned: usually neutral — they chose it. |
| What cognitive load are they carrying? | Low after a victory; after a defeat they are replaying the last turn in their head — the damage table and the per-floor strip should answer "what went wrong" without a search. |
| What information do they already have? | The result (banner), the killing boss (they just fought it), their deck (roughly). They do **not** yet know what they unlocked. |
| What are they most likely trying to do? | Press `Enter` (New Run, same hero). Second: read why they lost / what did the damage. Third: copy the seed. |
| What are they likely afraid of? | Losing the record (it is archived before this screen shows, R6); being punished visually (no red wash, no shake, no slow motion — run-ui Game Feel); a restart that goes through menus. |

**Emotional design target for this screen**:

Defeat: cold, still, factual, legible — "I see why" — with restart one click away. Victory: warm and generous, the one time the hero colour saturates, then quiet.

---

## 3. Navigation Position

**Screen hierarchy**:

```
Main Menu
  └── Hero Select → Run Start → Boss Intro → Match → (drafts) → … → Match
        └── Run Summary  ← this screen (terminal base)
              ├── → Run Start (New Run, same hero — no confirm)
              ├── → Hero Select
              ├── → Main Menu
              └── Toast layer (unlock toasts drain here; they persist across the New Run transition)
  └── Run Log → Run detail (read-only reuse of this layout — run-log.md)
```

**Modal behavior**: Non-modal base screen. There is no "back" — the run is over. `Esc` on a summary maps to Escape / Cancel step 5 (`back` on a run base screen) = **Main Menu** (the same as the Main Menu button); it never restarts a run and never opens a pause menu (there is nothing to pause).

**Reachability — all entry points**:

| Entry Point | Triggered By | Notes |
|-------------|-------------|-------|
| Match → summary | `run_ended{victory}` / `run_ended{defeat}` buffered during the match, applied at `match_view_finished` (S16) | Victory on winning floor `floors_per_run`; defeat on any boss win, incl. `both_dead` and `concede` |
| Pause / resume prompt → Abandon → confirm | `abandon()` → `run_ended{abandoned, abandon_reason: player}` (S6, S17) | Counts as a loss (R6) |
| Resume failure | `resume()` → `E_SCHEMA` / `E_CORRUPT` / `E_DATA_VERSION` → system abandon (`abandon_reason: data_version_mismatch | save_corrupt`) | run-ui Edge Cases: the **reason dialog** with New Run replaces the summary in the menu flow; the abandoned summary variant covers the case where Run Structure emits `run_ended{abandoned}` for a system reason (R6 "recorded but not losses") |
| Launch argument | `--run-ui-screen=summary_victory --run-ui-fixture=victory_sample`; `summary_defeat` + `defeat_sample`; `summary_abandoned` + `abandoned_sample`; `summary_victory` + `victory_sample_ts150` for the 150 % layout | run-ui U10 |
| Never | A `fault` match (`match_ended{result: fault}`) | Goes to the boss intro "Attempt n" (S11b), never here — stated so no fault copy is expected on this screen |

---

## 4. Entry & Exit Points

**Entry table**:

| Trigger | Source Screen / State | Transition Type | Data Passed In | Notes |
|---------|----------------------|-----------------|----------------|-------|
| `run_ended{result, floors_cleared, total_turns, run_seed_hex}` | `match` | Screen Replace `fade` 250 ms; victory adds the 400 ms portrait saturation ramp after the fade | The in-memory `RunRecord` handed with `run_ended` (never re-read from the archive — run-ui Edge Cases): `hero_id`, `result{outcome, floors_cleared, floor_reached, total_turns, ended_by, abandon_reason}`, `totals{matches_played, turns, damage_by_card{}, cards_drafted, treasures_taken, play_seconds}`, `match_summaries[]{floor, boss_id, band, result, reason, turns, attempt, duration_s, cards_played, damage_by_card{}}`, `deck[]`, `drafts[]`, `treasures[]`, `run_seed_hex`, `seed_source`, `floors_per_run`; Meta `unlocks_granted[]`; `summary_top_cards` (10); latest actionable `run_warning` | Toasts queued during the match start draining here (U5) |
| `run_ended{abandoned}` | `pause` / `resume_prompt` confirm | `fade` 250 | Same record; `abandon_reason` — only the headline is rendered | One-line variant (run-ui U2): one line + New Run · Main Menu, no columns |
| Fixture | `victory_sample` (8-floor record, 1 unlock), `defeat_sample` (fell on floor 5, floor 3 `attempt = 2`, reason `hero_dead`), `abandoned_sample` (player abandon from floor 3), `victory_sample_ts150` and `defeat_sample_ts150` (`text_scale` 1.5) | None | Fixture record | AC-6, AC-7, AC-31 |

**Exit table**:

| Exit Action | Destination | Transition Type | Data Returned / Saved | Notes |
|-------------|------------|-----------------|----------------------|-------|
| **New Run (same hero)** — default focus | `run_start` on `run_started` (S18) | `committed` → `fade` 250 → `run_start` 600 (skippable) → boss intro: **1350 ms at defaults, 500 ms at `instant`** (F1 path A) | `new_run(hero_id, "")` — a fresh random seed; S1 save | **No confirm, no second screen** (U9, Pillar 3). Not offered on a system-abandon summary when the hero is now locked (R8.4 covers resume, not new runs — Start would be `E_HERO_LOCKED`): the button is Disabled with the reason |
| Hero Select | `hero_select` (S19) | `fade` 250 | `return_to_menu` then T1 | Path B; absent on `summary_abandoned` (U2) |
| Main Menu / `Esc` | `main_menu` (S19) | `fade` 250 | `return_to_menu` | The archived run is already in the log |
| Copy seed | Same screen | Label flashes "Copied" 1.5 s | Clipboard ← 16-hex (local) | Success Confirmation; not a toast |
| Toast dismiss / expiry | Same screen | Fade 200 | `ack_notification(key)` was sent **on show**, once per key | A toast still showing when New Run fires rides the transition (S-05, AC-32) |
| Window closed | — | — | Nothing (the run is archived; `pending_notifications` keeps un-shown unlocks) | — |

---

## 5. Layout Specification

### 5.1 ASCII Wireframe

Defeat variant (`defeat_sample`: fell on floor 5, floor 3 attempt 2). Background `bg_edge` everywhere ("torch out"); every text `text_light` / `text_muted` (both tokens pass on `bg_edge` and on the victory variant's `table_lit` — art bible §4, `text_muted` on `table_lit` 5.08:1). The damage table shows **8 rows at 44 px** (y 108–460) plus "and N more" at y 468; the wireframe below abbreviates rows 4–7.

```
 x:0     40            400 424                824 848              1240 1280
 y:0 ┌──────────────────────────────────────────────────────────────────────────┐
     │        FELL ON FLOOR 5 — BONE COLLECTOR                       [toast ▸]  │  title row 0–48
  72 │ ┌──────┐                  DAMAGE BY CARD            FLOORS                │
 100 │ │  W   │ Halvard,         1 Whetstone Blade    42   R  G  B  S  ✕  ·  ·  · │  per-floor strip: 8 cells
     │ │      │ the Whetted      2 Cleave Through     31         ×2              │  24 px (node_d), y 100–124
 140 │ │      │                  3 Iron Vanguard      27   DECK · 27 CARDS       │  deck header 140
     │ │      │                  4 …                       ┌──────────────────┐  │
 232 │ └──────┘                  …                         │ (1) Whetstone…   │  │  scroll 848,168,
 284 │ Your hero fell             8 Tunnel Rat          4   │ (2) Shield Wall  │  │  392,432; rows 44
     │ Floors cleared 4 of 8     and 9 more                 │ (3) Cleave…  D f1│  │  facts 24 px rows;
     │ 5 matches · 41 turns                                 │ (4) …            │  │  damage rows 44 px
     │ 23:14 played                                         │ …                │  │  (8 rows 108–460;
     │ Seed 48A10CC0B2ED54EC [Copy]                        │                  │  │  "and N more" 468)
 424 │ Treasures  [T][T]                                   │                  │  │  seed row 380–424 (44 px)
     │ New unlocks                                         │                  │  │
     │  ■ New hero unlocked: Mother Wythe                  │                  │  │
 560 │ ! Run could not be saved — check disk space         │                  │  │  status line
 600 │                                                     └──────────────────┘  │
 640 │ [Hero Select] [Main Menu]                          ( New Run (same hero) )│  buttons y 640
 720 └──────────────────────────────────────────────────────────────────────────┘
      ■ = identification swatch (hero/treasure colour) beside the name, never text colour
      Strip cells: R / G / B / S = cleared (boss initial on the band colour); ✕ = the killing cell (boss initial inside a
      2 px `state_danger` ring — a ring, never a fill); · = hollow upcoming cell (no initial, no band colour); "×2" = the
      attempt mark under floor 3. Every cell is focusable (one Tab stop, `Left`/`Right` over cells) with a tooltip.
```

Victory variant: identical geometry; background `table_lit` warmth; headline "FLOORS CLEARED 8 OF 8"; the portrait panel ramps to the hero's full primary over 400 ms; the per-floor strip shows all 8 cells cleared (initials on band colour, no ring); no reason line. Abandoned variant (`abandoned_sample`): **one line and two buttons, nothing else** (run-ui U2 `summary_abandoned`) — the headline "RUN ABANDONED — COUNTED AS A LOSS" (player) or the system reason ("Run ended — save could not be read; not counted as a loss") centred at y 320 on `bg_edge`, and the action row with Main Menu (Secondary, 160x44 at 40, 640) and **New Run (same hero)** (Primary, 240x44 at 1000, 640, focused). No portrait, columns, floors, deck, seed or toasts-on-summary; the record is still archived and readable from the Run Log (`run_detail`).

### 5.2 Layout Zones

| Zone Name | Description | Approximate Size | Scrollable? | Overflow Behavior |
|-----------|-------------|-----------------|-------------|-------------------|
| Title row | Headline 28 px bold `text_light`, centred: victory `summary.headline.victory` "Floors cleared {F} of {F}"; defeat `summary.headline.defeat` "Fell on floor {n} — {boss}"; abandoned `summary.headline.abandoned.player` / `.system.{reason}` | 1280 x 48 (0–48) | No | Shrink to 24 px, then ellipsise the boss name (full name in the killing cell's tooltip) |
| Left column — hero & facts | Portrait 120x160 at (40, 72) in hero primary (saturates on victory — the one allowed fill); name 16 px bold + identity 14 px right of it (x 176, w 224); facts list from y 284, 24 px rows, 16 px: reason line (defeat only: `summary.reason.hero_dead` "Your hero fell" / `.both_dead` "Both fell — the boss wins ties" / `.concede` "Conceded" / `.turn_cap` "Turn cap reached"), "Floors cleared {n} of {F}", "{m} matches · {t} turns", "{mm:ss} played" (`play_seconds`) — the facts run 284–380 on a defeat (four rows) and 284–356 on a victory (no reason line); **seed row, 44 px tall at every scale** (defeat 380–424 / victory 356–400): "Seed {hex}" 13 px `text_muted` + Copy (Secondary, **Control 80x44 with a 32 px visual** — 44x44 is the committed floor for every focusable `Control`, accessibility-requirements Motor "Minimum target size") + "custom seed" tag when `seed_source = custom`; Treasures row (Treasure Chips in pick order, 40x40 / 44 hit, tooltips; **locked treasures carry the Treasure Chip lock glyph — treasures.md UI Requirements marks this "(Alpha)", so v1 renders no locked state, §15**) 424–468 (victory 400–444; a 44 px hit row); "New unlocks" header 468–492 (victory 444–468) and lines (one per `unlocks_granted[]`: swatch 12x12 + "New {kind} unlocked: {name}" 16 px, 24 px rows) from 492 (victory 468): **≤ 2 lines on a defeat, ≤ 3 on a victory, both ending 540**; beyond that the last 24 px row becomes "and {n} more" (defeat: one line + "and n more"; victory: two lines + "and n more"), so the column always ends ≤ 540, 20 px above the status line at 560. **150 % layout, laid out row by row (defeat = worst case, five fact-type rows; x 40–400, every bottom edge ≤ 628)**: portrait 120x160 at (40, 72) unchanged → 232 (name 24 px + identity 21 px × ≤ 4 lines stay inside its 160 px); facts start at **y 244** (the gap under the portrait shrinks from 52 to 12 px) at 36 px rows — reason 244–280, "Floors cleared" 280–316, "matches · turns" 316–352, "played" 352–388; **seed row 388–432 (44 px)** (hex 19.5 px, Copy shrinks to a **44x44 glyph button** "⧉" with accessible name "Copy seed" — label "Copied" still flashes in a tooltip-sized pill — and the "custom seed" pill follows on the same line: 180 + 44 + 100 px + gaps ≤ 360); Treasures **432–476** (44 px hit row); "New unlocks" header **476–500** (24 px); **one** unlock line **500–524**; "and {n} more" **524–548** (n = `len(unlocks_granted) − 1`; the toasts and the run log carry the rest); the status line stays at **y 560** (36 px tall → 596; it spans 40–800 under both columns); action row 640. If the headline wraps (title row 72, columns from 96 — not the case for the English headlines at 42 px, ≤ 740 px wide) the facts start at 268 (→ 412), the seed row is 412–456, Treasures 456–500 and the unlocks block collapses to its header reading "{n} new unlocks" (500–524), so the column still ends ≤ 548. **125 %**: same order at 30 px rows (facts 244–364, **seed 364–408** (44 px; Copy Control 80x44), Treasures **408–452**, header **452–472**, two unlock lines **472–512**, "and n more" **512–532**) — no other change | 360 x 528 (40–400, 72–600) | No | Unlocks > 2 lines on a defeat / > 3 on a victory (100 %) / > 2 (125 %) / > 1 (150 %) → the last row becomes "and N more"; the toasts and the run log carry the rest |
| Centre column — damage table | Header "Damage by card" 16 px bold at y 72; **8 visible rows** from y 108, **44 px** each (List Item rule — the rows are focusable for Card Inspect, so they are hit targets): rank 2 ch, card name — Card Inspect on hover / focus, damage numeral right-aligned 16 px bold → rows end at y 460; "and {N} more" 14 px `text_muted` at y 468 (N = `len(damage_by_card) − 8`; the record still carries `summary_top_cards` = 10, the Run Log detail shows them all); empty: "no damage dealt" (run-ui Edge Cases). The column ends at y 486, 74 px above the status line at y 560 | 400 x 414 (424–824, 72–486) | No (fixed 8 rows) | Card name ellipsises at 240 px; full card in Card Inspect; 7 rows at 125 % (55 px, ends 493 + "and N more" 501–519), 6 rows at 150 % (66 px, ends 504 + 512–533) — never past y 540 |
| Right column — per-floor strip | Header "Floors" at y 72; **run-ui U9's compact per-floor strip**, adopted as specified there (ux-review round 2): one **24 px cell** per floor 1..F (`node_d`, the Progress Strip's node geometry — the same `run_ui.json` key, so `hud.md` / `boss-intro.md` strip code is reused) on one row at y 100–124, cells 20 px apart — pitch 44, each 24 px visual centred in a **44x44 focusable hit Control** (y 90–134) so the accessibility 44 px target rule holds (*spec*: the progress strip's `seg_len` 40 would need 472 px; 8 × 24 + 7 × 20 = 332 px, x 848–1180, fits the 392 px column), cell centres x = 860 + 40·(f − 1). **Cleared cell**: band-colour fill with the boss initial 12 px bold `text_light`. **Killing cell** (defeat only): the boss initial inside a 2 px `state_danger` **ring** on a `bg_edge` fill — a ring, not a fill, so AC-7's "no `state_danger` fill larger than a stamp" holds. **Upcoming cells** (after the killing floor): hollow — 1 px `text_muted` outline, no initial, no band colour (run-structure UI Req: never the boss identity). **Attempt mark**: a 10 px "×{n}" in `text_light` centred 2 px under any cell with `match_attempts[floor] > 1` (y 126–136; the mark is a glyph like the cells and does **not** scale with `text_scale`, so it never reaches the deck header at y 140 — "attempt n" in the tooltip is the scaled text). Every cell is **focusable**: the strip is one Tab stop (§12 stop 8), `Left`/`Right` move between cells, and a Tooltip (300 ms hover / immediate on focus) reads "Floor {f} — {boss} (band {b}) · {t} turns · attempt {a}" plus "— you fell here" on the killing cell; upcoming cells read "Floor {f} — band {b}". Band is also carried by position (floors 1–3 / 4–6 / 7–8 are fixed bands, run-structure F1), so the swatch colour is never the only cue. Absent on `summary_abandoned` (U9) | 392 x 68 (848–1240, 72–140 — the zone includes the "×n" marks at 126–136; the same at every `text_scale`) | No | F > 9 → cell gap shrinks to 8 px (F ≤ 12 per run-structure safe range: 12 × 24 + 11 × 8 = 376 px); cells never shrink below `node_d` |
| Right column — deck | Header "Deck · {n} cards" at **y 140** (the space the expanded floors rows used is reclaimed by the deck list); Scroll Container **848, 168, 392, 432** with List Item rows 44 px in acquisition order (15 starter, then each bundle's 3): cost stamp, name, type initial; non-starter cards carry a "D f{floor}" tag (`drafts[]`) — drafted cards marked by glyph + text, not colour; Card Inspect on hover / focus; 9 rows visible (396 px) at 100 % | 392 x 460 (848–1240, 140–600) | Yes — vertical (36 cards = 1584 px) | Bar always shown when > 9 rows |
| Status line | Latest actionable `run_warning` (`save_failed`, `boss_pool_short`) repeated as text with a "!" glyph, 14 px `text_light`, at (40, 560, 760, 24) | 760 x 24 | No | Hidden when none (deliberate absence); one line, ellipsised with the full text in a tooltip |
| Action row | Hero Select (Secondary, 160x44 at 40, 640 — absent on abandoned), Main Menu (Secondary, 160x44 at 216, 640; at 40 when Hero Select is absent), **New Run (same hero)** (Primary, 240x44 at 1000, 640) | 1280 x 80 (640–720) | No | Buttons grow left / right, never clip |
| Toast layer | Top-right 400 x ≥ 48 at (856, 56); one at a time; persists across the New Run transition (S-05) | — | No | Queue drains with `toast_gap_ms` 150 between |

### 5.3 Component Inventory

| Component Name | Type | Zone | Purpose | Required? | Reuses Existing Component? |
|----------------|------|------|---------|-----------|---------------------------|
| Headline | Text | Title row | Outcome in words (the non-colour outcome cue) | Yes | Yes — `Label` |
| Hero portrait panel | Panel | Left | Identification; victory saturation | Yes | Yes — same placeholder as `hero-select.md` / HUD portrait |
| Facts list | Text rows | Left | Reason, floors, matches / turns, time | Yes | Yes — `Label`s |
| Seed + Copy | Text + Button | Left | Copyable 16-hex (DD-R09) | Yes | Yes — Button (Secondary) + Success Confirmation "Copied" |
| "custom seed" tag | Text pill | Left | `seed_source = custom` (bests exclude it — Meta M7.4) | Conditional | Yes — `Label` on `ink` pill |
| Treasure chips | Chip row | Left | Treasures held, pick order | Yes (0–3) | Yes — Treasure Chip |
| Unlock lines | Text rows + swatch | Left | `unlocks_granted[]` | Yes (0–n) | Yes — same row style as the Toast's title + swatch |
| Damage table | Table (8 visible List Item rows at 44 px, read-only, focusable) | Centre | Top-N damage by card (+ "and N more") | Yes (victory / defeat; absent on abandoned) | Yes — List Item + Card Inspect |
| "and N more" / "no damage dealt" | Text | Centre | Overflow / empty | Yes | Yes — Empty State text |
| Per-floor strip | Compound: 8 focusable cells on one row (24 px visual in 44x44 hit Controls, pitch 44) | Right | Per-floor result (boss initial on band colour), "×n" attempt marks, killing cell ringed `state_danger`, hollow upcoming cells; tooltip per cell (run-ui U9) | Yes (victory / defeat; absent on abandoned) | **Owned here** — library Screen-Owned entry **Per-Floor Strip** (this spec §5.2 / §5.3 / §12 stop 8; reused by `run_detail`, `run-log.md`): Progress Strip node geometry (`node_d`, same drawing code as the run screens' strip) + Tooltip; read-only, cells focusable, no connectors, no gem marks / chips / deck size |
| Deck list | Scroll Container of List Item rows | Right | Final deck in acquisition order, drafted marked | Yes | Yes — Scroll Container + List Item + Card Inspect |
| Status line | Text | Left/bottom | Actionable warning repeated (accessibility "Reading time") | Conditional | Yes — Error State "Save failed" persistent line |
| New Run (same hero) | Button | Action row | Restart | Yes | Yes — Button (Primary) |
| Hero Select | Button | Action row | Switch hero | Victory / defeat only | Yes — Button (Secondary) |
| Main Menu | Button | Action row | Leave | Yes | Yes — Button (Secondary); `Esc` duplicates |
| Toast | Banner | Toast layer | Unlock / warning | Yes | Yes — Toast / Notification |

**Primary focus element on open**: **New Run (same hero)** (run-ui U3, U9; `default_focus.summary` knob) on every variant, including deep-link / fixture. If it is Disabled (hero now locked on a system-abandon summary) focus goes to Main Menu.

### 5.4 Information Hierarchy

1. **The outcome and its reason** — headline + reason line + the killing floor's ringed cell on the per-floor strip: Pillar 3's legible lesson, readable in one glance (the accessibility matrix's requirement for this screen).
2. **The restart** — New Run (same hero), focused, bottom-right: the Core Loop's "players restart immediately".
3. **New unlocks** — rare, high-value, in the left column and as a toast; never blocking.
4. **What did the work** — the damage table: the evidence for "why".
5. **The record** — deck list, treasures, seed, time: for the player who wants to keep or share the run; the Run Log holds it afterwards.
6. **Warnings** — the status line: present only when actionable.

---

## 6. States & Variants

| State Name | Trigger | What Changes Visually | What Changes Behaviorally | Notes |
|------------|---------|----------------------|--------------------------|-------|
| Loading | `fade` in | Content appears with the fade | Intents except `skip` dropped | Build from a 36-card, 8-summary record ≤ 50 ms (run-ui AC-26) |
| Victory | `result.outcome = victory` | `table_lit` warmth; portrait ramps to hero primary over 400 ms (linear; the one colour ramp); headline "Floors cleared F of F"; all eight strip cells cleared (initials on band colour, no ring); no reason line; `run_victory` stinger | New Run focused | Fixture `victory_sample` (AC-6, AC-17) |
| Defeat | `outcome = defeat` | `bg_edge` everywhere (torch out); headline names floor and boss; reason line; the killing boss's strip cell ringed `state_danger` (initial inside, hollow cells after it); **no `state_danger` fill larger than a stamp** (the ring is a 2 px outline on a 24 px cell), no shake, no red wash; short `run_defeat` stinger | New Run focused | Fixture `defeat_sample` (AC-7) |
| Defeat — `both_dead` | `reason = both_dead` | Reason "Both fell — the boss wins ties" (DD-M12) | Same | Copy is the only difference |
| Defeat — `concede` | `reason = concede` | Reason "Conceded" | Same | |
| Defeat — `turn_cap` | `reason = turn_cap` | Reason "Turn cap reached" | Same | Match Rules `TURN_CAP` |
| Abandoned — player | `abandon_reason = player` | **One line only**: headline "Run abandoned — counted as a loss" centred at y 320 on `bg_edge`; no portrait, columns, floors, deck or seed (run-ui U2 `summary_abandoned`) | Hero Select button absent; New Run (focused) + Main Menu | Fixture `abandoned_sample` (run-ui U10) |
| Abandoned — system | `abandon_reason ∈ {data_version_mismatch, save_corrupt}` | Same one-line layout; the headline gives the reason and "not counted as a loss" | New Run Disabled with reason if the hero is now locked; else as player-abandon | R6 "system abandons are not losses" |
| Attempt marks | `match_attempts[f] > 1` | "×n" mark under that floor's strip cell and "attempt n" in its tooltip (defeat_sample: floor 3 "×2") | — | AC-7; replayed floors after `match_faulted` or a mid-match quit |
| Custom seed | `seed_source = custom` | "custom seed" pill beside the seed | — | Bests exclude it (Meta M7.4) — tooltip says so |
| Damage table empty | `damage_by_card == {}` (turn-1 concede) | "no damage dealt" instead of rows | Rows not focusable | run-ui Edge Cases |
| Damage table overflow | `> 8` entries (the record holds `summary_top_cards` = 10) | "and N more" line at y 468 (N = entries − 8) | — | R10; the Run Log detail lists all ten |
| Unlocks present | `unlocks_granted[]` non-empty | Lines in the left column **and** toasts draining one at a time (5–8 s each, hover (or LMB hold) pauses — toasts take no focus) | `ack_notification(key)` once per key on show; a key in both the signal and the queue → one toast (AC-15) | `victory_sample`: one "New hero unlocked" line |
| No unlocks | empty | "New unlocks" header absent (deliberate absence) | — | |
| No treasures | `treasures == []` | "Treasures" row absent | — | Deliberate absence |
| Status line | Latest actionable `run_warning` | "!" line at y 560 | Tooltip holds the full text | `save_failed`, `boss_pool_short` |
| Removed id | A card / treasure id no longer in data | Row shows the raw id in `text_muted` + "(removed)" | Card Inspect unavailable for it | run-ui Edge Cases (run log case; applies here after a data update between crash and resume) |
| Copy seed pressed | Copy | Label "Copied" 1.5 s | Clipboard written | Success Confirmation |
| Committed (New Run) | `Enter` / click | Button pressed; nothing dims (the screen is leaving) | Further intents ignored; `new_run` issued once (AC-17) | |
| Toast riding out | New Run while a toast shows | Toast stays on the toast layer through `run_start` and the floor-1 boss intro until `t_toast` elapses | Not re-acked | AC-32 |
| `text_scale` 125 % / 150 % | Setting | **Left column laid out explicitly in §5.2** (150 %: facts from y 244 at 36 px rows, 44 px seed row 388–432 with the 44x44 Copy glyph button, Treasures 432–476, unlocks header + one line + "and n more" 476–548; every bottom ≤ 548 — the rule is ≤ 628; 125 %: 30 px rows, 44 px seed row 364–408, two unlock lines, column ends 532); the status line stays at **y 560** (36 px tall at 150 %, ends 596); damage rows 55 / 66 px → **7 / 6 rows visible** (ending y 493 / 504) with "and N more" counting the rest — never past y 540; the per-floor strip's 24 px cells and its 10 px "×n" marks do **not** scale (`node_d` is fixed; only the tooltip text scales), so the strip zone stays 72–140 and the deck header stays at y 140 and the scroll at 168–600; deck rows 55 / 66 px (7 / 6 visible); headline 42 px fits one line in English (≤ 740 px) — if a locale wraps it, the title row grows to 72, columns start at 96 and the unlocks block collapses to "{n} new unlocks" (§5.2) | — | AC-31; fixtures **`victory_sample_ts150`** and **`defeat_sample_ts150`** (run-ui U10 settings variants, `settings.text_scale` 1.5 — the defeat variant is the five-row worst case) |
| `reduce_motion` / `instant` | Setting | No slide anywhere (there is none); the saturation ramp is kept (single ramp, not motion); 0 ms transitions at `instant` — the ramp is skipped to its end state | `committed` still blocks a second New Run | AC-20 |
| Read-only (`run_detail`) | Opened from the Run Log | Same layout; action row = Copy seed + Back only | No run commands | `run-log.md` owns the entry; noted so the layout is built once |

---

## 7. Interaction Map

Mapping interactions for: **keyboard + mouse**. Covering **Partial** gamepad support as a post-v1 mapping; touch not supported.

### 7.1 Navigation Inputs

| Input | Platform | Action | Visual Response | Audio Cue | Notes |
|-------|----------|--------|-----------------|-----------|-------|
| `Tab` / `Shift+Tab` | KB | Cycle the §12 focus order (starts at New Run) | Ring moves | `ui_hover` | |
| `Down` / `Up` / `Home` / `End` | KB | Inside the damage table and the deck list: rows (Card Inspect per row); `Tab` leaves the list | Row ring; preview | `ui_hover` | List Item rule |
| Mouse hover | PC | Lift 2 px on buttons; Card Inspect on table / deck rows; chip tooltip | No ring | `ui_hover` | Never moves focus |
| Mouse click | PC | Activate a button; focus a row (no action) | Press / ring | `ui_select` | |
| Mouse wheel | PC | Scroll the deck list (3 rows per notch) | — | — | Only scrollable zone |
| RMB | PC | No-op (no drawers here) | — | — | Never navigates |
| `Esc` | KB | Main Menu (`back`, chain step 5) | `fade` | `ui_select` cancel variant | Never restarts; no pause exists |
| `1` / `2` / `3` | KB | No-op — this is not a 3-option screen (run-ui U3 scopes the number keys to those) | — | — | Stated so a reviewer does not expect them |
| Gamepad (post-v1) | — | d-pad over the same graph; `ui_accept` / `ui_cancel` | — | — | — |

### 7.2 Action Inputs

| Input | Platform | Context (What must be focused) | Action | Response | Animation | Audio Cue | Notes |
|-------|----------|-------------------------------|--------|----------|-----------|-----------|-------|
| `Enter` / `Space` | KB | New Run (same hero) focused — **the default** | `new_run_same_hero` → `new_run(hero_id, "")` | `committed`; `fade` | 60 ms press | `ui_select` | **The one-key restart** (path A 1350 ms); no confirm |
| LMB | PC | — (pointer over New Run) | As above | | | | |
| `Enter` / LMB | KB / PC | Hero Select | `go_hero_select` | `fade` | | `ui_select` | Not present on abandoned |
| `Enter` / LMB / `Esc` | KB / PC | Main Menu (or anywhere for `Esc`) | `go_main_menu` | `fade` | | `ui_select` cancel | |
| `Enter` / LMB | KB / PC | Copy | `copy_seed` (local) | Label "Copied" 1.5 s | | `ui_select` | `Ctrl+C` with the seed focused is a *proposed* duplicate (Standard Shortcuts) |
| LMB | PC | Toast hovered (toasts never take focus — no key path; hover or LMB hold pauses, release dismisses, per the Toast pattern) | Dismiss early | Fade 200 | | — | Ack already sent on show |
| `Left` / `Right` | KB | Per-floor strip focused | Move between cells (tooltip follows) | Focus ring moves | — | `ui_hover` | Read-only; `Enter` does nothing |
| `Enter` | KB | A damage / deck row focused | Nothing (read-only rows) | — | — | — | Card Inspect is already open on focus |
| Any input | all | During `transitioning` | `skip` | — | 0 | — | U4 |

### 7.3 State-Specific Behaviors

| State | Input Restriction | Reason |
|-------|------------------|--------|
| Loading / `transitioning` | All but `skip` dropped | U4 |
| Committed | All intents ignored until `run_started` / the menu swap | One `new_run` per press (double-activation guard) |
| New Run Disabled (hero locked after a system abandon) | `Enter` on it inert; reason tooltip | Avoids an `E_HERO_LOCKED` round trip |
| Read-only (`run_detail`) | No run commands | Archived record |

---

## 8. Data Requirements

| Data Element | Source System | Update Frequency | Who Owns It | Format | Null / Missing Handling |
|--------------|--------------|-----------------|-------------|--------|------------------------|
| `result{outcome, floors_cleared, floor_reached, total_turns, ended_by, abandon_reason}` | Run Structure (`RunRecord` with `run_ended`) | Once | Run Structure (R1, R6) | Dictionary | `ended_by` null on victory / abandon → no boss in the headline |
| `totals{matches_played, turns, damage_by_card{}, cards_drafted, treasures_taken, play_seconds}` | Run Structure | Once | Run Structure (R10) | Dictionary | Empty `damage_by_card` → "no damage dealt" |
| `match_summaries[]{floor, boss_id, band, result, reason, turns, attempt, duration_s, cards_played, damage_by_card{}}` | Run Structure (from RNG & Event Log `match_summary` events) | Once | Run Structure | Array (last attempt per floor) | Floors never played → rows show "band n" only |
| `match_attempts{floor: n}` | Run Structure | Once | Run Structure (R1) | Dictionary | Absent floor → attempt 1 |
| `deck[]` (acquisition order), `drafts[]{floor, kind, offered_ids[], picked_id, card_ids_added[]}` | Run Structure | Once | Run Structure | Arrays | Drafted marking derives from `drafts[]`; a skipped step (`picked_id: null`) adds no mark |
| `treasures[]` (pick order) | Run Structure | Once | Run Structure | Array | Empty → row absent |
| `run_seed_hex`, `seed_source` | Run Structure (RNG & Event Log F1 display form) | Once | Run Structure (R9) | 16-hex string; enum | Always present |
| `hero_id`, `floors_per_run` | Run Structure | Once | Run Structure | id; int | Always present |
| `HeroDef`, `CardDef`, `TreasureDef`, `BossDef` names / colours by id | Card Database | On build | Card Database | Records | Unresolved id → raw id + "(removed)" in `text_muted` |
| `unlocks_granted[]` for this run | Meta Progression via Run Structure (`archive_run` return, exposed on the summary read model — R6) | Once | Meta (M3) | `[{key, kind, id}]` | Empty → header absent |
| `pending_notifications()` + `unlock_granted` signal | Meta Progression | Shell idle | Meta (M3.6) | `{key, kind, id, by_run_id, retro}` | Empty → no toasts |
| Latest actionable `run_warning` | Run Structure (`run_warning{code, detail}`) | Once | Run Structure (R10) | `{code, detail}` | None → status line absent |
| `summary_top_cards` | Run Structure data (`run_structure.json`) | Static | Run Structure (Tuning Knobs, 10) | int | Absent → 10 |
| Settings (`anim_speed`, `reduce_motion`, `text_scale`, `high_contrast_states`, volumes) | Meta Progression | `settings_changed` | Meta (M9) | DD-X07 record | Defaults |

> **Rule**: This screen must never write directly to any system listed above. All
> player actions fire events (see Section 9). Systems update their own data and
> notify the UI. The summary is built from the in-memory record, never by
> re-reading the archive (run-ui Edge Cases) — pruning cannot affect it.

---

## 9. Events Fired

| Player Action | Event Fired | Payload | Receiver System | Notes |
|---------------|-------------|---------|-----------------|-------|
| New Run (same hero) | `new_run_same_hero` → `new_run(hero_id, "")` | `{hero_id, seed_input: ""}` | Run Structure T18 → `run_started` → S1 save | **Persistent**: new run record, active-run slot; the previous run is already archived (R6) so nothing is lost — hence no confirm |
| Hero Select | `go_hero_select` → `return_to_menu` then T1 | — | Run Structure / Run UI | Menu phase |
| Main Menu / `Esc` | `go_main_menu` → `return_to_menu` | — | Run Structure | — |
| Copy seed | `copy_seed` (local) | — | OS clipboard via Run UI | No game event; `DisplayServer.clipboard_set` |
| Toast shown (not a player action) | controller calls `ack_notification(key)` | `{key}` | Meta Progression | **Persistent** (profile write); once per key; the UI never calls Meta from a screen script — the controller does |
| Toast dismissed | `dismiss` (local) | — | Run UI | — |
| Focus / hover rows | none | — | — | Deliberate: inspection is local |

No analytics system exists in v1; the archived run is the record.

---

## 10. Transitions & Animations

| Transition | Trigger | Direction / Type | Duration (ms) | Easing | Interruptible? | Skipped by Reduced Motion? |
|------------|---------|-----------------|--------------|--------|----------------|---------------------------|
| Screen enter | `run_ended` | Cross-fade `fade` | 250 × `speed_factor` | ease-out | Yes (any input skips) | No (fade); 0 at `instant` |
| Victory portrait saturation | After the fade, victory only | Colour ramp hero-primary-desaturated → full primary (the one allowed fill; run-ui Game Feel impact moment 2 of 2) | 400 | linear | Yes — skip jumps to full colour | **Not skipped** — a single ramp, not motion (≤ 3 luminance changes / s); 0 at `instant` |
| Defeat enter | `run_ended{defeat}` | Fade only — **deliberately no shake, no slow motion, no red** (run-ui Game Feel; art bible §2) | 250 | ease-out | Yes | — |
| Toast in / out | Queue drain | Fade (+ slide without `reduce_motion`) | 200 | ease-out | — | Fade only |
| Copy → "Copied" | Copy | Label swap, reverts after 1500 | 0 / 0 | — | — | — |
| Button hover / press | Mouse / key | Lift 2 px / press | 80 / 60 | ease-out / linear | Yes | — |
| Card Inspect | Hover 0.1 s / focus 0 ms | 1.5x card beside the row (toward screen centre) | 100 | ease-out | Yes | Without tween |
| Screen exit → run start (path A) | New Run | `fade` 250 → `run_start` panel 600 (skippable) → boss intro | 250 | ease-out | Yes | — ; the whole path is 1350 ms at defaults, 500 at `instant` (F1) |
| Screen exit → hero select / menu | Buttons / `Esc` | `fade` 250 | 250 | ease-out | Yes | — |
| Deck list scroll | Wheel / keys | Scroll step | 100 | ease-out | — | 0 at `instant` |

---

## 11. Input Method Completeness Checklist

Platform Target is keyboard + mouse; **Touch** dropped (not supported); **Gamepad** kept as the post-v1 mapping.

**Keyboard**
- [x] All interactive elements are reachable using Tab and arrow keys alone (§12 order; `Up`/`Down` in the two lists; `Left`/`Right` over the per-floor strip's cells)
- [x] Tab order follows visual reading order after the default stop (New Run first, then Hero Select, Main Menu, Copy, chips, damage rows, deck rows, per-floor strip)
- [x] Every action achievable by mouse is also achievable by keyboard
- [x] Focus is visible at all times (2 px ring, 3 px offset, also at `instant`)
- [x] Focus does not escape the screen while it is open (no modals; lists are one stop in / one stop out)
- [x] Esc key closes or cancels (→ Main Menu) and does not quit the game

**Gamepad** (post-v1 — mapping only)
- [ ] All interactive elements reachable with D-Pad and left stick — mapping defined, not implemented (§15 "Gamepad: d-pad graph")
- [ ] Face button mapping documented — `ui_accept` / `ui_cancel` only (§15 "Gamepad: face buttons")
- [x] No action requires analog stick precision
- [ ] Trigger and bumper shortcuts — library default (shoulders = Tab) (§15 "Gamepad: bumpers")
- [ ] Controller disconnection handling — not specified (§15 "Controller disconnection")

**Mouse**
- [x] Hover states defined for all interactive elements
- [x] Clickable hit targets are at minimum 32x32px — the project floor is 44x44 on every focusable `Control` (accessibility-requirements Motor): buttons 160x44 / 240x44; Copy Control 80x44 (32 px visual) at 100 / 125 %, a 44x44 glyph button at 150 %, always in a 44 px seed row; strip cells 24 px (`node_d`, the same inspect-only stops as the Progress Strip's nodes — keyboard `Left`/`Right`, tooltip, no action); chips 44x44; damage rows 44 px and deck rows 44 px — both focusable for Card Inspect, so both meet the List Item interactive-row rule)
- [x] Right-click behavior defined (no-op)
- [x] Scroll wheel behavior defined (deck list)

**Touch (if applicable)** — not applicable.

---

## 12. Accessibility

**Text contrast requirements for this screen**:

| Text Element | Background Context | Required Ratio | Current Ratio | Pass? |
|--------------|-------------------|---------------|---------------|-------|
| Headline (28 px bold) | `bg_edge` (defeat / abandoned) / `table_lit` (victory) | 3:1 | `text_light` 14.75 / 9.43 | [x] |
| Facts, headers, rows (16 / 14 px) | `bg_edge` / `table_lit` | 4.5:1 | 14.75 / 9.43 | [x] |
| Seed (13 px), "and N more" (14 px), removed ids | `bg_edge` / `table_lit` | 4.5:1 | `text_muted` 7.94 / **5.08** (art bible §4 Text table row "`text_muted` on `table_lit`", added 2026-11-03 — AA at every size) — `text_muted` is used on both variants; no substitution | [x] |
| Hero name / identity on the portrait panel | Hero primary | 4.5:1 | `text_light` 6.17–6.72 | [x] |
| Card name on a stamp / cost numeral | `ink` | 4.5:1 | 14.33 | [x] |
| Status line ("!" + text) | `bg_edge` / `table_lit` | 4.5:1 | `text_light` 14.75 / 9.43 | [x] — never `state_danger` text on a surface (art bible rule a) |
| Button labels | `table_dark` | 4.5:1 | 13.07 | [x] |
| Toast title / subtitle | `table_dark` | 4.5:1 | 13.07 / 7.03 | [x] |

**Colorblind-unsafe elements and mitigations**:

| Element | Colorblind Risk | Mitigation |
|---------|----------------|------------|
| Victory vs defeat | Warm fill vs dark; portrait saturation | Headline text ("Floors cleared F of F" / "Fell on floor n — boss"), reason line, the ringed killing cell on the per-floor strip and its tooltip "you fell here" (audit row "Victory vs defeat summary") |
| Band colour on the strip cells | Ochre / rust / slate-violet fills | Boss initial in the cell; "band n" in every cell's tooltip; band is fixed by floor position (1–3 / 4–6 / 7–8, run-structure F1) |
| Drafted vs starter cards | None by colour | "D f{n}" tag + glyph |
| Unlock swatches | Hero / treasure colour | Decoration beside the name text (audit row "Unlock toast swatch") |
| Killing floor | `state_danger` ring on one cell | The ring is a shape (the only ringed cell; cells after it are hollow, cells before it filled), the headline names the floor and boss, and the cell's tooltip reads "you fell here" |
| Primary vs Secondary buttons | Outline vs none | Outline + position (right-most) |

**Focus order** (Tab key sequence, numbered):

1. **New Run (same hero)** — default on open
2. Hero Select (absent on abandoned — the abandoned variant has exactly two stops: New Run, Main Menu)
3. Main Menu
4. Copy seed
5. Treasure chips, left → right (0–3 stops; tooltips)
6. Damage table (one stop; `Up`/`Down` over its rows with Card Inspect; `Tab` leaves) — skipped when "no damage dealt"
7. Deck list (one stop; `Up`/`Down`; Scroll Container follows focus)
8. Per-floor strip (one stop; `Left`/`Right` over its 8 cells, each with its tooltip immediate on focus; `Tab` leaves) — absent on abandoned
→ cycles to 1. Not stops: headline, facts, unlock lines, status line (all text; the status line's full text is a tooltip on hover **and** is also written in full in the run log / menu status line, so nothing is hover-only). Toasts never take focus; `Tab`-ing onto one is not possible — they are pausable by hover (or LMB hold) only, per the Toast pattern (decided 2026-11-03: acceptable because the toast is never the sole channel).

**Screen reader announcements for key state changes**: Not committed (Standard tier; AccessKit live regions NOT SOURCEABLE — accessibility-requirements). Required accessible names so a later pass is unblocked: the screen's name is the headline + reason; New Run "New run as <hero>"; damage rows "n of 10: <card>, <damage> damage"; deck rows "<cost> <name>, drafted on floor f" / "starter"; chips "<treasure>, <rarity>: <text>, picked on floor f"; per-floor strip cells "Floor {f} of {F}: {boss}, band {b}, cleared, {t} turns, attempt {a}" / "Floor {f} of {F}: {boss}, band {b}, fell here, attempt {a}" (the killing cell) / "Floor {f} of {F}: band {b}, not reached" (hollow cells — never the boss name); unlock lines as their text.

**Cognitive load assessment**:

Streams: (1) outcome + reason, (2) per-floor strip, (3) damage table, (4) deck list, (5) treasures, (6) unlocks, (7) seed / time facts, (8) a possible warning — eight, at the top of 7±2. Mitigations: the resting read is one headline and one focused button; every other stream is a labelled column the player chooses to read; the deck is behind a scroll; unlocks are repeated as toasts (one at a time, 5–8 s, pausable) so they are not lost if the player restarts immediately; no timer and no auto-advance anywhere on this screen (the 4 s auto-advance was the match banner, and this screen repeats everything it said — accessibility Cognitive "Reading time"). The defeat variant adds **nothing** visual to the loss (no shake, no red) so the reading is calm.

---

## 13. Localization Considerations

**General rules for this screen**:
- All text elements must tolerate a minimum of 40% expansion from English baseline
- RTL layout: the three columns mirror (hero column at the right), the action row mirrors (New Run bottom-left in RTL), numerals and the seed stay LTR
- CJK: shorter text simply leaves space; row heights are fixed
- Do not use text in images — all text from `tr()` keys or Card Database `text.key` / `text.en` (run-ui AC-22); boss, card and treasure names come from data

| Text Element | English Baseline Length | Max Characters | Expansion Budget | RTL Behavior | Overflow Behavior | Risk |
|--------------|------------------------|----------------|-----------------|--------------|-------------------|------|
| Headline victory "Floors cleared 8 of 8" | 21 | 40 | 90 % | Centre | Shrink to 24 px | Low |
| Headline defeat "Fell on floor 5 — Bone Collector" | ~32 | 56 (1200 px at 28 px bold ≈ 60 chars) | 75 % | Centre | Shrink to 24 px, then ellipsise the boss name (full in the killing cell's tooltip) | Medium |
| Headline abandoned (player / system) | 33 / ~55 | 60 / 80 | 45 % | Centre | Wraps to 2 lines (title row grows to 72) | Medium |
| Reason lines ("Both fell — the boss wins ties") | ≤ 32 | 44 (360 px column) | 40 % | Right-align | Wraps to 2 rows | Low |
| Facts rows ("5 matches · 41 turns", "23:14 played") | ≤ 22 | 36 | 60 % | Mirror | Wrap | Low |
| "Seed" + 16-hex + "custom seed" | 4 + 16 + 11 | 8 + 16 + 18 | 60 % | Label leads; hex LTR | Tag wraps under | Low |
| Unlock line "New hero unlocked: Mother Wythe" | ~32 | 50 | 55 % | Right-align | Wraps to 2 rows | Low |
| Damage table card name | ≤ 32 (content.md) | ~24 at 16 px in 240 px | −25 % — **tighter than the content limit** | Right-align | Ellipsise; full name in Card Inspect | **High** — flag for the localization engineer |
| Strip cell tooltip "Floor 3 — Bog Witch (band 1) · 7 turns · attempt 2" | ~48 | 80 (tooltip wraps to 2 lines) | 60 % | Mirror | Tooltip wraps; never ellipsised | Low |
| Deck row name | ≤ 32 | ~26 at 16 px in 260 px | −20 % | Right-align | Ellipsise; Card Inspect | **High** |
| Status line | ≤ 80 | 100 (760 px at 14 px) | 25 % | Right-align | Ellipsise; full text in the tooltip | Medium |
| Buttons "New Run (same hero)" / "Hero Select" / "Main Menu" / "Copy" | 19 / 11 / 9 / 4 | 30 / 18 / 16 / 10 | 55 % | Mirror positions | Primary grows left (240 → ≤ 320 px), Secondaries grow right | Medium — German "Neuer Lauf (gleicher Held)" ≈ 27 chars |
| Toast title / subtitle | ≤ 40 / ≤ 80 | 56 / 112 | 40 % | Right-align | Toast grows down; `t_toast` scales | Low |

---

## 14. Acceptance Criteria

Fixtures: run-ui U10 `victory_sample` (`--run-ui-screen=summary_victory`), `defeat_sample` (`summary_defeat`), `abandoned_sample` (`summary_abandoned`) and the settings variants `victory_sample_ts150` and `defeat_sample_ts150` (`text_scale` 1.5), captured per `.claude/docs/run-and-observe.md` into `production/qa/evidence/`.

**Performance**
- [ ] Building the summary from a 36-card, 8-summary record takes ≤ 50 ms and the first frame renders within 100 ms (run-ui AC-26)
- [ ] GIVEN `defeat_sample`, WHEN `Enter` is pressed on open (New Run focused), THEN the floor-1 boss intro's first frame is visible within 1350 ms + 15 % at defaults and never above `restart_budget_ms` 5000 (run-ui AC-23 path A)
- [ ] Button press → visible press state within 33 ms (run-ui Game Feel)

**Layout & Rendering**
- [ ] GIVEN `victory_sample`, THEN the hero panel at (40, 72) is in its full primary, the headline reads "Floors cleared 8 of 8", the 16-hex seed with Copy, an 8-row damage table (44 px rows, y 108–460) with "and 2 more" at y 468, the deck list with drafted cards marked "D f{n}", the treasures row, one "New hero unlocked" line, the per-floor strip shows eight filled cells with boss initials on band colour and no `state_danger` ring, and New Run (same hero) at (1000, 640) carries the 2 px `state_actionable` ring at a 3 px offset (run-ui AC-6)
- [ ] GIVEN `defeat_sample`, THEN the background is `bg_edge`, the headline names floor 5 and the boss, the reason reads "Your hero fell", the per-floor strip shows cells 1–4 filled with boss initials on band colour, floor 3's cell carries "×2" (tooltip "attempt 2"), floor 5's cell is the only cell ringed `state_danger` (initial inside, no fill), cells 6–8 are hollow with no initial and their tooltips read "band n" only (no boss name), **no `state_danger` fill larger than a stamp exists on screen**, and New Run is focused (run-ui AC-7)
- [ ] GIVEN a fixture with `damage_by_card == {}`, THEN the centre column reads "no damage dealt" and has no focusable rows
- [ ] GIVEN a 36-card deck, THEN the deck list scrolls with a visible bar and `Up`/`Down` keeps the focused row visible
- [ ] GIVEN the window at 3840x2160, THEN the layout is the 1280x720 layout uniformly scaled (AC-31)
- [ ] GIVEN `victory_sample_ts150` (`settings.text_scale = 1.5` in the fixture profile), THEN no text clips or overlaps: the damage table shows 6 rows + "and N more" ending above y 540, the left column's last row ends ≤ 548, the status line (if any) sits at y 560 and ends ≤ 596, and the per-floor strip's cells are still 24 px at y 100–124 (AC-31)
- [ ] GIVEN `defeat_sample_ts150` (run-ui U10: `defeat_sample` with `text_scale = 1.5`, everything else equal — the five-row left column: reason, floors, matches · turns, played, seed), THEN the facts rows sit at y 244 / 280 / 316 / 352 (36 px), the seed row at 388–432 with the 44x44 Copy glyph button, Treasures at 432–476, the unlocks header at 476, one unlock line and "and n more" ending at y 548, and no left-column pixel lies at y ≥ 548 or overlaps Hero Select / Main Menu at y 640 (AC-31). (The status line's 150 % geometry, 560–596, is asserted in §5.2; no U10 fixture carries a warning on a summary, so it has no retained capture — the 100 % "`save_failed` warning" criterion under Events & Data covers its presence)
- [ ] GIVEN `victory_sample` and `defeat_sample`, THEN the Copy seed Control measures 80x44 (32 px visual) and sits in a 44 px seed row at y 356–400 / 380–424, the Treasures hit row at 400–444 / 424–468, and the left column ends ≤ 540 (automated "Target sizes" walk: every focusable Control ≥ 44x44)
- [ ] GIVEN `abandoned_sample`, THEN the screen shows only the headline "Run abandoned — counted as a loss" at y 320, Main Menu at (40, 640) and New Run (same hero) focused at (1000, 640); no portrait, column, floors row, deck list, seed or Hero Select button exists (run-ui U2)
- [ ] GIVEN `defeat_sample`, THEN the per-floor strip occupies 848, 72, 392, 68 with eight 24 px cells at y 100–124 centred on x = 860 + 40·(f − 1), floor 3's "×2" mark at y 126–136, the deck header sits at y 140 and the deck scroll at 848, 168, 392, 432 (run-ui AC-6 "per-floor strip")
- [ ] GIVEN `victory_sample` with the strip focused (`Tab` to stop 8) and `Right` pressed twice, THEN cell 3 carries the 2 px focus ring at a 3 px offset and its tooltip names floor 3's boss, band and turns
- [ ] GIVEN `defeat_sample` with `seed_source = custom`, THEN the "custom seed" pill sits beside the seed and its tooltip states that bests exclude custom seeds; GIVEN a fixture with an unresolvable card id in `deck[]`, THEN that deck row shows the raw id in `text_muted` with "(removed)" and opens no Card Inspect
- [ ] The `fault` outcome has no copy on this screen

**Input**
- [ ] GIVEN any summary, WHEN `Enter` is pressed once with no mouse input, THEN `new_run(hero_id, "")` is issued with **no confirm** and the next state is `run_start` (run-ui AC-17)
- [ ] GIVEN New Run pressed twice within 100 ms, THEN one `new_run` is issued and the second logs `ui_intent_rejected`
- [ ] GIVEN `Esc`, THEN the main menu appears; GIVEN Hero Select, THEN hero select appears with the same hero pre-selected (it is now `last_hero_id`)
- [ ] GIVEN Copy pressed, THEN the clipboard holds exactly the 16-hex string and the label reads "Copied" for 1.5 s
- [ ] GIVEN a keyboard-only pass, THEN focus visits the §12 stops in order with the ring visible at each (retained screenshot), also at `instant` (AC-19)

**Events & Data**
- [ ] The screen issues only the intents in §9; the summary is built from the record handed with `run_ended`, never from `run_log()` (verify: no archive read on open)
- [ ] GIVEN the shell was in `match` when `unlock_granted` arrived, THEN the toast shows **here** for `t_toast`, `ack_notification(key)` is called exactly once, and the next queued toast follows after `toast_gap_ms`; a key also in `pending_notifications()` at the next boot produces no second toast (run-ui AC-15)
- [ ] GIVEN an unlock toast showing for 1 s, WHEN New Run is pressed, THEN the toast is still visible on `run_start` and the floor-1 boss intro and disappears when its `t_toast` elapses; `ack_notification` was called once (run-ui AC-32)
- [ ] GIVEN a `save_failed` warning during the run, THEN the status line repeats it here and its full text is in the tooltip

**Accessibility**
- [ ] All text passes the §12 ratios in-engine, including `text_muted` on the victory variant's `table_lit` (art bible §4: 5.08:1)
- [ ] With colour removed (Coblis, both `high_contrast_states` values), victory vs defeat, band, drafted vs starter and the killing floor are identifiable from text and glyphs
- [ ] GIVEN `reduce_motion`, THEN the toast fades without sliding and nothing else changes (there is no motion on this screen beyond the single saturation ramp)
- [ ] GIVEN `anim_speed = instant`, THEN transitions are 0 ms, the saturation is applied immediately, and `committed` still blocks a double New Run (AC-20)

**Localization**
- [ ] Zero literal English strings in the scene scripts (AC-22); reason, headline and button copy are keys
- [ ] Pseudo-locale +40 %: card names in the damage table and deck list ellipsise with Card Inspect available; nothing else overflows

---

## 15. Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Player journey map not yet created — author `design/player-journey.md` from `.claude/docs/templates/player-journey.md`; the "earned relief" / "clear-eyed loss" targets are taken from the art bible §2 and the Core Loop, not a journey map. | Jacob | Before Pre-Production gate | Open |
| Three-column geometry (left 40–400, centre 424–824, right 848–1240; damage rows **44 px** (8 visible, y 108–460); per-floor strip cells 24 px at y 100–124, 20 px apart (44x44 hit Controls); deck header y 140, deck scroll 848, 168, 392, 432; action row y 640; Primary 240x44 at 1000, 640) is this spec's — run-ui gives the summary no F-formula. Record in run-ui or keep spec-owned? | Run UI GDD owner | Pre-Production | Proposed here (spec-owned) |
| `text_muted` on `table_lit` is not in the art bible §4 Text table; the victory variant uses `text_light` for the seed and "and N more" instead. Ask the art bible to add the ratio (or confirm the substitution). | art-director | Alpha | **Resolved 2026-11-03** — art bible §4 Text table now carries `text_muted` on `table_lit` at 5.08:1 (AA at every size); the substitution is dropped and `text_muted` is used on both variants (§12) |
| New fixture `abandoned_sample` (player abandon from `post_match_reward`, `floors_cleared = floor`) — add to run-ui U10's required list; also a `text_scale` 1.5 variant of `victory_sample`. | Run UI GDD owner / `/qa-plan` | Before the first summary story | **Resolved 2026-11-03** — run-ui U10 lists `abandoned_sample`, `victory_sample_ts150` and (round 2) `defeat_sample_ts150` — the defeat variant is the 150 % worst case (five fact rows) |
| System-abandon summary with a now-locked hero: New Run (same hero) Disabled with a reason vs hidden. This spec: Disabled with the reason tooltip (consistent with hero-select's locked rule). | Run UI GDD owner | Pre-Production | Proposed here |
| Floors list on the summary (per-floor boss, turns, attempt, killing floor) is implied by run-structure UI Requirements ("`attempt > 1` floors marked", "killing boss") but not listed as a block by run-ui U2/U9. Confirm it belongs here rather than only in `run_detail`. | Run UI GDD owner | `/ux-review run-summary` | **Resolved 2026-11-03** (round 2) — run-ui U2 / U9 / AC-6 specify a compact per-floor strip (one 24 px cell per floor at `node_d`, boss initials, "×n" attempt mark, killing cell ringed `state_danger`, later cells hollow, tooltip on hover / focus); this spec **adopts that strip as written** (§5.1, §5.2 "Right column — per-floor strip", §5.3, §12 stop 8, §14) — the earlier expanded text-row rendering is withdrawn so a tester holding AC-6 and this spec look for the same component, and the strip reuses the Progress Strip's node drawing. The reclaimed height goes to the deck list (header y 140, scroll 168–600). `summary_abandoned` carries no strip. **Round 3 (2026-11-03)**: run-ui U9's "(no focus stop)" phrase was removed — the cells are one focus stop for inspection (tooltip on focus, `Enter` does nothing), as this spec and the Tooltip pattern require; the strip is now indexed in the library as the Screen-Owned **Per-Floor Strip** (owner: this spec) so `run_detail` can cite it |
| Gamepad: d-pad graph (§11) — spatial `focus_neighbor_*` wiring over New Run → Hero Select → Main Menu → Copy → chips → damage rows → deck rows is not specified per element. | ux-designer | Before gamepad work (post-v1) | Open — post-v1; v1 may not make the 1:1 mapping impossible |
| Gamepad: face buttons (§11) — `ui_accept` = activate the focused button / nothing on read-only rows, `ui_cancel` = Main Menu; a button for Copy seed is undecided. | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Gamepad: bumpers (§11) — library default (shoulders = Tab / Shift+Tab); no screen-specific binding proposed. | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Toast focusability: the Toast pattern says hover **or focus** pauses the timer, yet toasts "never take focus". Which key path reaches a toast to pause / dismiss it? Not decidable here — `toast.md`. | ux-designer (`toast.md`) | `/ux-design toast` | **Resolved 2026-11-03** — the library's Toast entry and accessibility-requirements now say the same thing: hover (or LMB hold) pauses, LMB dismisses, toasts take no focus and have no key path; acceptable because a toast is never the sole channel (unlocks repeat here and on hero select; warnings in the status line). §7.2 and §12 updated |
| Locked-treasure glyph on the summary's chips — treasures.md UI Requirements "locked ones shown with a lock glyph **(Alpha)**". v1 renders no locked state on this screen; the Treasure Chip pattern owner adds the glyph state at Alpha and this row cites it. | Treasure Chip pattern owner (`interaction-patterns.md`) + ux-designer | Alpha | Open — Alpha scope, acknowledged in §5.2 |
| `Ctrl+C` on the focused seed as a Copy duplicate — proposed in Standard Shortcuts, not adopted. | Jacob | Pre-Production | Open (inherited) |
| Controller disconnection handling (§11) — gamepad is post-v1. | ux-designer | Post-v1 | Open |
| AccessKit live regions — inherited NOT SOURCEABLE item; no announcement is claimed. | ux-designer | Before first menu implementation | Open (inherited) |
