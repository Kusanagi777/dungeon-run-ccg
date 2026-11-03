# UX Spec: Hero Select

> Authoring guidance: .claude/docs/templates/guidance/ux-spec-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Design
> **Author**: Jacob + ux-designer (`/ux-design hero-select`, automation `guided`, workflow `standard`, density `balanced`; owner pre-approved the run — no `AskUserQuestion` used, recommended options taken and listed in the session report; no Agent tool — `art-director` / `ui-programmer` / `game-designer` not spawned)
> **Last Updated**: 2026-11-03
> **Journey Phase(s)**: Session-level loop opening — "One full run: hero select, eight matches…" (game-concept Core Loop) and the Pillar 3 restart path B "defeat → Hero Select → Start" (run-ui F1). Run phase `hero_select` (run-structure States). `design/player-journey.md` does not exist — see §15.
> **Screen / Flow Name**: `HeroSelect` (run-ui U2 id `hero_select`)
> **Platform Target**: PC (Windows primary, Linux dev/CI); 1280x720 logical, `canvas_items` + `keep` (DD-T05); mouse primary, keyboard complete; gamepad `Partial` post-v1; touch none.
> **Related GDDs**: `design/gdd/run-ui.md` U2 (`hero_select` row), U3, U4, U7, States S3, S7, S8, S19, S23, F1 (path B, `select_ready`, `t_human_pick`), F4 (`slot_x`), Edge Cases "Seeds and hero select", Tuning Knobs (`preselect_hero`), Visual/Audio, UI Requirements, AC-2, AC-3, AC-14, AC-18, AC-19, AC-31; `design/gdd/heroes.md` H-1, H-2 (the three launch heroes, identity lines, colours), H-3 (power names / costs / texts), States (Hero: Locked), Visual/Audio, UI Requirements, AC-16, AC-17; `design/gdd/run-structure.md` R2 (`new_run(hero_id, seed_input)`), R9 (seeds), UI Requirements; `design/gdd/meta-progression.md` M1.3 (`is_hero_unlocked`, `unlock_progress`, `stats_for_hero`, `last_hero_id`), M2 (unlock `{key, condition}`), F6 (progress display), UI Requirements; `design/gdd/rng-event-log.md` F1 (seed parsing, 16-hex echo) + UI Requirements; `design/gdd/card-database.md` UI Requirements (`HeroDef` fields); `design/design-decisions.md` DD-H01, DD-H02, DD-X01, DD-X02 (no forced hero; War pre-selected on a fresh profile), DD-R09.
> **Related ADRs**: none yet.
> **Related UX Specs**: `design/ux/interaction-patterns.md` (Pick One of N "hero select" mode, Button (Primary / Secondary / Destructive), Confirmation Dialog, Input Field, Tooltip, Card Inspect, List Item, Scroll Container, Toast, Screen Replace, Focus Management, Escape / Cancel, Standard Shortcuts, Empty State "Hero select with no locked heroes", Success Confirmation); `design/accessibility-requirements.md`; `design/ux/draft-picker.md` (the Deck drawer is reused here for the starter deck); `main-menu.md` (entry; ReadOnly banner shared component), `run-start.md` / `boss-intro.md` (exit), `run-summary.md` (entry via Hero Select) — the first three not yet written.
> **Accessibility Tier**: Standard with reduce-motion, visual-for-every-sound and the high-contrast state set elevated (`design/accessibility-requirements.md`). Hero identification is colour **plus** initial letter and name (audit row "Hero identification").
> **Template**: UX Spec
> **REVISED 2026-11-03 (ux-review)**: (1) a 13 px `text_light` **set blurb** line (`hero.set_blurb.{set}`, ≤ 52 chars / 2 lines — "War: weapons, aggression, armour") sits under the identity line (§5.1, §5.2, §5.3, §8, §13; heroes.md UI Requirements row); (2) stats line → the run-ui U7 format "NW · NL · best FN" rendered "3W · 5L · best F8" (28-char budget; wins **and losses**, Meta `stats_for_hero`), §5.1 / §5.2 / §5.3 / §8 / §13 aligned; (3) §6 and AC 5 cite the run-ui U10 settings variant `locked_heroes_ts150`; (4) §15 gamepad rows for every §11 untick; (5) §6 toast row cites run-ui F3 (5–8 s, hover / focus pause) and inherits the pattern library's toast focus / announcement OQ; Deck Drawer and `LockedHeroPanel` §15 rows resolved against the library's new entries.

> **Sources read** (by section): run-ui U1–U10, States, F1–F4, Edge Cases, Tuning Knobs, Visual/Audio, Game Feel, UI Requirements, AC; heroes H-1–H-3, States, Interactions (Run UI row), Visual/Audio, UI Requirements, AC-16–18; run-structure R2, R9, UI Requirements; meta M1.3, M2, M3.7, F6, UI Requirements; rng-event-log F1 (via run-ui AC-18); art bible §2 (Main menu / hero select mood), §4, §7; accessibility-requirements Visual, Motor, Cognitive, Per-Feature Matrix (Heroes row); interaction-patterns entries named above.

> **Note — Scope boundary**: A base screen of the run shell. It is not a run screen (no Progress Strip, no pause overlay — `Esc` is Back). Numbers marked **F4** come from run-ui's `slot_x`; numbers marked *spec* are this document's decisions.

---

## 1. Purpose & Player Need

**What player need does this screen serve?**

The player wants to choose *who they are going to be* for the next 30–45 minutes and to see, before committing, what that choice means: the hero power they will press every turn, the shape of the fifteen cards they start with, and how they have done with this hero before. On a first launch the need is orientation (three identities, one obviously pre-selected so nothing blocks the first run — DD-X02, nothing forced); on a restart after a death the need is speed (Pillar 3: back in a fight within five seconds, run-ui F1 path B). The screen must serve both without a mode switch: everything readable on request, nothing in the way of `Enter`.

**The player goal** (what the player wants to accomplish):

Confirm the pre-selected hero with one `Enter`, or pick another with `1`/`2`/`3` + `Enter`, after reading its power and starter deck if they want to — and, optionally, type a seed.

**The game goal** (what the game needs to communicate or capture):

Issue exactly one `new_run(hero_id, seed_input)` for an Available hero (after a Confirmation Dialog when an active run is saved), show locked heroes with their live unlock progress so the meta loop is visible (concept Retention Hooks), and echo the normalised 16-hex seed so a typed seed is reproducible (DD-R09).

---

## 2. Player Context on Arrival

| Question | Answer |
|----------|--------|
| What was the player just doing? | Either pressing New Run on the main menu (S3) — a cold start — or pressing Hero Select on a victory / defeat summary (S19), seconds after a run ended. |
| What is their emotional state? | Cold start: anticipation, "a deliberate, unhurried choice" (art bible §2). After a defeat: impatient — they came here *instead of* New Run (same hero) because they want to switch, so the pick should take one key. |
| What cognitive load are they carrying? | Low. At most the memory of the deck that just failed. |
| What information do they already have? | On a fresh profile: nothing — the identity lines and power texts are the pitch. Later: per-hero wins / best floor remind them. |
| What are they most likely trying to do? | Press `Enter` on the pre-selected hero (last played, else War). Secondary: inspect the three powers; type a seed shared by someone. |
| What are they likely afraid of? | Starting a run while one is saved and losing it silently (hence the Confirmation Dialog, run-ui U7); not knowing why a hero is locked; typing a seed and not knowing whether it "took" (hence the live echo). |

**Emotional design target for this screen**:

Expectant and uncluttered — one warm pool of light on the hero panels in a cool dark room (art bible §2), with the next action already under the player's finger.

---

## 3. Navigation Position

**Screen hierarchy**:

```
Main Menu
  ├── Hero Select  ← this screen (base)
  │     ├── Confirmation Dialog ("Start a new run?" — only when an active run is saved)
  │     ├── Deck drawer (starter deck, non-blocking — reused from draft-picker.md)
  │     ├── Toast layer
  │     └── → Run Start → Boss Intro …
  ├── Run Log · Settings · Continue (resume prompt)
  └── (Run Summary → Hero Select is the second entry path)
```

**Modal behavior**: Non-modal base screen; dismissable with Back / `Esc` → Main Menu (Escape / Cancel chain step 5). Nothing on it blocks except the Confirmation Dialog.

**Reachability — all entry points**:

| Entry Point | Triggered By | Notes |
|-------------|-------------|-------|
| Main Menu → New Run | `new_run_requested` (S3) | Primary entry; the controller reads the roster + unlock state |
| Run Summary (victory / defeat) → Hero Select | `go_hero_select` → `return_to_menu` + T1 (S19) | Pillar 3 path B; the previous run is already archived |
| Launch argument | `--run-ui-screen=hero_select --run-ui-fixture=fresh_profile` / `locked_heroes` | Screenshot path (run-ui U10) |

---

## 4. Entry & Exit Points

**Entry table**:

| Trigger | Source Screen / State | Transition Type | Data Passed In | Notes |
|---------|----------------------|-----------------|----------------|-------|
| New Run | `main_menu` | Screen Replace `fade` 250 ms (F2) | Roster: every `HeroDef` present in data with `is_hero_unlocked(id)`; per locked hero `unlock_progress(HeroDef.unlock.key) → {met, progress, parts}` + the condition text; `stats_for_hero(id)` (wins, best floor); `last_hero_id()`; `load_active_run()` presence; `allow_custom_seed` | Focus → Start; pre-selected hero per U7 |
| Hero Select from a summary | `summary_victory` / `summary_defeat` | `fade` 250 ms | Same | `select_ready` budget 300 ms (F1) |
| Fixture | `fresh_profile` (War only present, no locked row), `locked_heroes` (six `HeroDef`s, three locked with hints) | None | Fixture profile | AC-2, AC-3 |

**Exit table**:

| Exit Action | Destination | Transition Type | Data Returned / Saved | Notes |
|-------------|------------|-----------------|----------------------|-------|
| Start (`Enter` on Start / click / `Enter` in the seed field while Start is Actionable) | `run_start` on `run_started` (S7) | `committed` ≤ 50 ms → `fade` 250 | `new_run(hero_id, seed_input)` — Run Structure R2: seed, RNG, boss sequence, **S1 save**; `seed_input` is the **raw** string, not the echo (AC-18) | Irreversible once `run_started` arrives; a saved active run is ended first (below) |
| Start while an active run is saved | Confirmation Dialog first; on confirm as above | Overlay open → confirm → as Start | On confirm the old run is abandoned by Run Structure (counts as a loss, R6) then `new_run` | Start acts as Button (Destructive) in this case (pattern "Start a new run while one is saved"); Cancel leaves the run untouched (AC-14) |
| Start rejected (`E_HERO_LOCKED`, `E_CONFIG`) | Same screen (S8) | Toast | Screen un-commits | Should not happen for an Available hero |
| Back / `Esc` | `main_menu` (S23) | `fade` 250 | `suspend()` when a `RunState` is in memory (none normally on this path); no save, no event | Focus returns to New Run on the menu (Screen Replace focus rule) |
| Deck drawer | Same screen | Drawer slide / fade | Local | Non-blocking |
| Window closed | — | — | Nothing (no run exists yet) | — |

---

## 5. Layout Specification

### 5.1 ASCII Wireframe

Three launch heroes present, three locked (fixture `locked_heroes`). Panels use F4's `slot_x(i, 3, 340, 40)` = 90 / 470 / 850 — the same x as the bundle panels, so the eye learns one row geometry across the run.

```
 x:0     40    90                430 470               810 850              1190   1280
 y:0 ┌───────────────────────────────────────────────────────────────────────────────────┐
     │                          CHOOSE YOUR HERO                                         │  title 0–48
  72 │         ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐               │
     │         │┌────┐ HALVARD   │ │┌────┐ MOTHER    │ │┌────┐ ARCHIVIST │               │  panel 340x340
     │         ││ W  │ the Whet. │ ││ D  │ WYTHE     │ ││ K  │ ILSE      │               │  portrait 120x160
     │         ││    │ "Every    │ ││    │ "Nothing  │ ││    │ "I have   │               │  identity line
     │         ││    │  turn…"   │ ││    │  in my…"  │ ││    │  read…"   │               │
     │         ││    │ War: weap.│ ││    │ Decay: … │ ││    │ Knowl.: … │               │  set blurb 13 px
     │         │└────┘3W·5L·bF8  │ │└────┘0W·0L·bF0  │ │└────┘1W·2L·bF5  │               │  stats "3W · 5L · best F8"
     │         │┌───────────────┐│ │┌───────────────┐│ │┌───────────────┐│               │  power plate
     │         ││(2) Whetstone  ││ ││(2) Rot        ││ ││(2) Insight    ││               │  parchment 308x96
     │         ││Equip a 1/2 …  ││ ││Deal 1 damage… ││ ││Draw a card…   ││               │
     │         │└───────────────┘│ │└───────────────┘│ │└───────────────┘│               │
     │         │ 1 2 3 4 5 6+    │ │ curve strip     │ │ curve strip     │               │  curve 308x28
 412 │         └─────●───────────┘ └─────────────────┘ └─────────────────┘               │
 428 │         ┌─🔒 FORTUNE ─────┐ ┌─🔒 ORDER ───────┐ ┌─🔒 SHADOW ──────┐               │  locked 340x88
     │         │ Win a run with  │ │ Defeat 16 bosses│ │ Reach floor 8   │               │  (neutral grey,
 516 │         │ any hero — 0/1  │ │ — 8/16          │ │ with Decay — 0/1│               │  text_light)
 540 │                 Seed (optional) [________________________________] ×               │  field 332x36
 580 │                                 → Random                                           │  echo 13 px
 640 │ [Back]                      ( Start )                             [Deck (15)]     │  buttons 160x44
 720 └───────────────────────────────────────────────────────────────────────────────────┘
     ● = selected (pre-selected hero: last played, else War); Start carries the focus ring on open
```

MVP (`fresh_profile`, `hero_war` only): one panel centred at `slot_x(0, 1, 340, 40)` = 470; no locked row — the band y 428–516 is empty by design (Empty State "Hero select with no locked heroes": deliberate absence, no "coming soon").

### 5.2 Layout Zones

| Zone Name | Description | Approximate Size | Scrollable? | Overflow Behavior |
|-----------|-------------|-----------------|-------------|-------------------|
| Title row | "Choose your hero" 28 px bold `text_light` on `bg_edge`, centred | 1280 x 48 (0–48) | No | Ellipsise (never expected) |
| Hero panel row | n = 1–3 panels 340x340 (*spec* height) at F4 `slot_x(i, n, 340, 40)` (n = 3: 90 / 470 / 850; n = 2: 280 / 660; n = 1: 470), y 72–412; one warm `table_lit` pool 1140x380 behind them (art bible §2) | 1100 x 340 | No | > 3 launch heroes is not a v1 case (DD-H01); §15 |
| Hero panel (each) | Fill hero primary, 2 px frame hero secondary, 4 px radius. Portrait placeholder 120x160 at (+16, +16): secondary fill + hero initial 24 px bold. Right of it (x +152, w 172): name 16 px bold `text_light`, identity line (`HeroDef.text`) 14 px `text_light` wrapped (≤ 3 lines), **set blurb** 13 px `text_light` (key `hero.set_blurb.{set}` — "War: weapons, aggression, armour" / "Decay: deaths, swarms, drain" / "Knowledge: spells, draw, tempo"; ≤ 52 chars, wraps to 2 lines in the 172 px column; heroes.md UI Requirements "Set identity blurb and theme tags"), stats line 13 px `text_light` in the run-ui U7 format `NW · NL · best FN` — "3W · 5L · best F8" (wins, losses, best floor from Meta `stats_for_hero`; zeros shown, "0W · 0L · best F0"; ≤ 28 chars at three-digit counts; at 150 % the word "best" is dropped — "3W · 5L · F8" — if the line would wrap). The column stacks name 20 / identity 54 / blurb 34 / stats 16 = 124 px inside the portrait's 160 px height. Power plate `parchment` 308x96 at (+16, +196): cost stamp "2" (34 px steel blue) + power name 14 px bold `text_ink`, power text 12 px `text_ink` (≤ 4 lines); Card Inspect text variant (1.5x) on hover / focus. Curve strip 308x28 at (+16, +300): one column per cost 1–6+ with the count numeral 12 px `text_light` over a bar whose height ∝ count (max 15) | 340 x 340 | No | Identity line > 3 lines ellipsises; full line in the panel tooltip |
| Locked row | 0–3 panels 340x88 at the same x, y 428–516: neutral `#6F655A` fill (desaturated silhouette), lock glyph (letter "L" in a ring, v1) + name 16 px bold `text_light`, condition text + progress "— 0 / 1" 14 px `text_light` (Meta F6: "8 / 16 bosses defeated"; `each_launch` lists per-hero ticks in the tooltip) | 1100 x 88 | No | Absent when no locked `HeroDef` exists (U7); > 3 locked → §15 |
| Seed row | Input Field: label "Seed (optional)" 16 px at (400, 548); `LineEdit` 332x36 at (548, 540) with placeholder "random"; clear "×" affordance; echo line "→ 48A10CC0B2ED54EC" / "→ Random" 13 px `text_muted` at (548, 580) | 480 x 60 (540–600) | No | Any text accepted (RNG F1 hashes everything); long input scrolls inside the field |
| Action row | Back (Secondary, 160x44 at 40, 640); **Start** (Primary, 160x44 at 560, 640); Deck (Secondary, 160x44 at 1080, 640, label "Deck (15)") | 1280 x 80 (640–720) | No | Buttons grow, never clip |
| Deck drawer (overlay, non-blocking) | Reused from `draft-picker.md`: 960, 96, 320, 624; header "Starter deck · 15 cards"; 15 List Item rows (cost stamp, name, type initial) in `starter_deck` order; Card Inspect on hover / focus; no "Treasures" section (none held) | 320 x 624 | Yes | Scroll Container |
| Toast layer | Top-right 400 x ≥ 48 at (856, 56) | — | No | One at a time |
| ReadOnly banner | Shared strip above the title row when Meta is `ReadOnly` | 1280 x 28 | No | Pushes nothing (overlays the title row's top) |

### 5.3 Component Inventory

| Component Name | Type | Zone | Purpose | Required? | Reuses Existing Component? |
|----------------|------|------|---------|-----------|---------------------------|
| Screen title | Text | Title row | Orientation | Yes | Yes — `Label` |
| Hero panel ×1–3 | Compound option | Hero row | Name, identity, stats, power, curve; selectable | Yes | Yes — Pick One of N (hero-select mode) slot; **new** `HeroPanel` scene composed from existing parts |
| Portrait placeholder | Panel | Hero panel | Identification (colour + initial) | Yes | Yes — same placeholder rule as the HUD portrait (`hud.md`) |
| Power plate | Panel + text | Hero panel | Hero power cost / name / text | Yes | Yes — Card Inspect text variant for the full text |
| Curve strip | Compound | Hero panel | Starter-deck cost curve at a glance | Yes | **No — new** `CurveStrip` (6 columns, numerals + bars) |
| Set blurb line | Text | Hero panel | One-line set identity under the identity line ("War: weapons, aggression, armour") | Yes | Yes — `Label`, key `hero.set_blurb.{set}` |
| Stats line | Text | Hero panel | wins · losses · best floor — "3W · 5L · best F8" (run-ui U7) | Yes (zeros allowed) | Yes — `Label` |
| Locked panel ×0–3 | Compound (focusable, not selectable) | Locked row | Name, condition, progress | Conditional | **New** `LockedHeroPanel` — the "locked-item progress pattern" meta-progression's UX flag asks for (shared later by the treasure codex) |
| Seed field | Input Field | Seed row | Optional seed | Conditional (`allow_custom_seed`) | Yes — Input Field (seed variant) |
| Seed echo | Text | Seed row | Normalised 16-hex / "Random" | Conditional | Yes — Input Field "Typing" state |
| Back | Button | Action row | To main menu | Yes | Yes — Button (Secondary); `Esc` duplicates |
| Start | Button | Action row | `start_run` | Yes | Yes — Button (Primary); Destructive behaviour when a run is saved |
| Deck | Button | Action row | Opens the starter-deck drawer | Yes | Yes — Button (Secondary) |
| Deck drawer | Drawer | Overlay | 15 starter cards | Yes | Yes — `DeckDrawer` from `draft-picker.md` (proposed pattern entry) |
| Confirmation Dialog | Modal | Overlay | "Start a new run?" | Conditional | Yes — Confirmation Dialog |
| Toast | Banner | Toast layer | `E_HERO_LOCKED` / `E_CONFIG` rejection; retro unlock toasts drained on the menu may still be showing | Yes | Yes — Toast |
| ReadOnly banner | Strip | Top | Meta `ReadOnly` | Conditional | Yes — shared (`main-menu.md`) |

**Primary focus element on open**: **Start**, with the pre-selected hero already Selected (Meta `last_hero_id()`; `null` on a fresh profile → War, DD-X02; `preselect_hero` knob). Fixture `fresh_profile`: Start focused, War selected. Fixture `locked_heroes`: same; locked panels are focusable but never pre-selected. Deep-link / fixture cases are identical.

### 5.4 Information Hierarchy

1. **The three heroes as identities** — primary colour, initial, name, identity line: a screenshot identifies the hero without reading (art bible Visual Identity Anchor).
2. **The pre-selected hero and Start** — the restart path must read as "press Enter" (Pillar 3; run-ui F1 path B budgets 1.5 s of human time here).
3. **The hero power** — the plan in one sentence (heroes.md: "the player should see the plan before committing").
4. **The starter curve and stats** — supporting evidence, glanceable.
5. **Locked heroes with progress** — the meta loop made visible without competing with the launch row (smaller, grey, below).
6. **The seed field** — optional and quiet (`text_muted` echo); a feature for the sharing minority (DD-R09).
7. **The starter deck list** — behind the Deck drawer.

---

## 6. States & Variants

| State Name | Trigger | What Changes Visually | What Changes Behaviorally | Notes |
|------------|---------|----------------------|--------------------------|-------|
| Loading | `fade` in; `select_ready` ≤ 300 ms | Panels appear with the fade (no stagger — this is not a reveal) | Intents except `skip` dropped while `transitioning` | run-ui F1 |
| Populated — MVP | One `HeroDef` present | One panel centred at x 470; locked row absent | `1` focuses it; `2`/`3` ignored | Fixture `fresh_profile` (AC-2) |
| Populated — launch roster | Three `HeroDef`s, none locked | Three panels; locked band empty | `1`/`2`/`3` | Alpha-B content (heroes AC-16) |
| Populated — with locked heroes | Locked `HeroDef`s present | Locked row of grey panels with lock glyph, condition and progress | Locked panels focusable (hint keyboard-reachable), **not** selectable; Start Disabled while one is focused | Fixture `locked_heroes` (AC-3) |
| Locked without a hint | `unlock_progress` has no definition for the key (orphaned `unlock`) | Lock glyph + name, no hint line | As locked | run-ui Edge Cases |
| Hero hovered | Mouse over a panel | Lift 8 px, no ring; power plate shows Card Inspect text variant | No selection | |
| Hero focused | `1`/`2`/`3`, `Tab`, click | Focus ring; tooltip (identity line in full) | `Enter` selects (and keeps focus) | |
| Hero selected | Click / `Enter` on a focused panel; or pre-selection on open | Hugging `state_actionable` outline persists; hero-specific sting (`heroes.md`: anvil / wet crack / page turn) | Start Actionable; Deck drawer shows this hero's deck | Pick One of N "Selected" |
| Committed | Start | Start pressed; panels dim 60 % except the chosen; `ui_select` | Further intents ignored until `run_started` (U4) | ≤ 50 ms |
| Confirm pending | Start with an active run saved | Confirmation Dialog "Start a new run?" / "This ends your current run — counted as a loss." / [Cancel ●] [Start new run] | Base disabled; Cancel focused | run-ui U7, AC-14 |
| Rejected | `E_HERO_LOCKED` / `E_CONFIG` (S8) | Toast with the reason; panels brighten; Start returns to Actionable | Un-committed | Error State |
| Seed typing | Any keys in the field | Echo updates live to the normalised 16-hex; "×" appears | Local only | AC-18: "deckdelve" → `48A10CC0B2ED54EC` |
| Seed empty / whitespace | Field empty or spaces | Echo "→ Random" | `seed_input = ""` → random seed | run-ui Edge Cases |
| Seed field hidden | `allow_custom_seed = false` | Seed row absent; buttons unchanged | — | run-structure knob |
| Deck drawer open | Deck button | Right drawer over the panels (covers panel 3 and locked panel 3) | Non-blocking; `Esc` / RMB / toggle closes it first | Reused from `draft-picker.md` |
| ReadOnly profile | Meta `ReadOnly` | Banner strip | Start still works; the run is not saved (Meta M6) | run-ui Edge Cases |
| Saved run uses a now-locked hero | Not this screen's concern | That hero shows locked here; Continue on the menu still works (R8.4) | — | Noted so the apparent contradiction is expected |
| Toast showing | Retro unlock drained on the menu; rejection | Banner top-right; visible 5–8 s (run-ui F3 `toast_min_ms` 5000 / `toast_max_ms` 8000), hover / focus pauses the timer, one at a time | Never steals focus | Inherits the pattern library's Toast open question (focus / live-region announcement — AccessKit NOT SOURCEABLE) |
| `text_scale` 125 % / 150 % | Setting | Panel text grows; the identity line wraps to 4 lines, the set blurb and the stats line move under the portrait (stats drops "best" → "3W · 5L · F8"); power plate text goes to the reading panel on hover / focus (plate keeps name + cost + first line); locked hint wraps to 2 lines (row 88 → 112 px, pushing the seed row to 564 and the echo to 604 — still above the action row) | — | AC-31; fixture **`locked_heroes_ts150`** (run-ui U10 settings variant, `settings.text_scale` 1.5) |
| `reduce_motion` / `instant` | Setting | Lifts instant; drawer fades; 0 ms transitions | `committed` still blocks a double Start | AC-20 |
| Empty | — | **Cannot occur**: Card Database refuses a data set with no `HeroDef` (`Failed` → `data_error`); this screen is never built without ≥ 1 hero | — | Stated for the reviewer |

---

## 7. Interaction Map

Mapping interactions for: **keyboard + mouse**. Covering **Partial** gamepad support as a post-v1 mapping onto the same focus graph; touch not supported.

### 7.1 Navigation Inputs

| Input | Platform | Action | Visual Response | Audio Cue | Notes |
|-------|----------|--------|-----------------|-----------|-------|
| `1` / `2` / `3` | KB | Focus hero panel *n* (launch row only; never a locked panel) | Ring + tooltip | `ui_hover` | Ignored past the roster size (MVP: `2`/`3` do nothing) |
| `Tab` / `Shift+Tab` | KB | Cycle the §12 focus order (starts at Start) | Ring moves | `ui_hover` | |
| `Down` / `Up` | KB | Inside the open drawer: rows; elsewhere no-op | Row ring + Card Inspect | `ui_hover` | |
| Mouse hover | PC | Lift; power-plate Card Inspect; tooltip | Lift, no ring | `ui_hover` | Never selects |
| Mouse click | PC | Focus + select a hero panel; focus a locked panel (no selection) | Outline persists; sting | hero-specific sting / `ui_hover` (locked) | A click never starts the run |
| Mouse wheel / RMB | PC | Drawer scroll / close the drawer | — | — | RMB never navigates |
| `Esc` | KB | Chain: (2) close drawer → (3) cancel the confirm → (5) **Back** to main menu | `fade` | `ui_select` cancel variant | Step 4 (pause) does not exist on this screen — it is not a run screen |
| Gamepad (post-v1) | — | d-pad over the same graph; `ui_accept` / `ui_cancel` | — | — | — |

### 7.2 Action Inputs

| Input | Platform | Context (What must be focused) | Action | Response | Animation | Audio Cue | Notes |
|-------|----------|-------------------------------|--------|----------|-----------|-----------|-------|
| `Enter` / `Space` | KB | A launch hero panel focused | Select it (Start was already Actionable if a hero was pre-selected; stays so) | Outline moves to this panel; Deck label updates | 80 ms | hero sting | A second `Enter` on the panel = Start (Pick One of N second-Enter rule) |
| `Enter` / `Space` | KB | Start focused (Actionable) | `start_run(hero_id, seed_input)` → confirm or `new_run` | `committed` | 60 ms press | `ui_select` | **The one-key restart** (F1 path B) |
| `Enter` | KB | Seed field focused | Activates Start **only if** Start is Actionable (Input Field rule); otherwise nothing | As Start | | | A fresh profile always has War pre-selected, so this always starts |
| LMB | PC | Pointer over Start | As Start | | | `ui_select` | |
| LMB ×2 | PC | Pointer over a hero panel | Select + Start | As Start | | sting + `ui_select` | Shortcut |
| `Enter` / LMB | KB / PC | Locked panel focused | Nothing (not selectable); its tooltip shows the condition and `parts` | — | — | — | Start is Disabled while it holds focus (AC-3) with the reason tooltip "Locked — <condition>" |
| `Enter` / LMB | KB / PC | Deck button | Open / close the drawer for the **selected** hero | Slide / fade 250 | | `ui_select` | |
| `Enter` / LMB | KB / PC | Back | `back` → main menu | `fade` | | `ui_select` cancel | |
| `Enter` / LMB | KB / PC | Confirmation Dialog: Cancel (default) / "Start new run" | Cancel → nothing; confirm → `new_run` | | | `ui_select` | Enter on first open lands on Cancel (safe) |
| Typing / `Ctrl+V` / `Delete` on "×" | KB | Seed field | Edit; echo updates | — | — | — | Standard editing shortcuts |
| Any input | all | During `transitioning` | `skip` | — | 0 | — | U4 |

### 7.3 State-Specific Behaviors

| State | Input Restriction | Reason |
|-------|------------------|--------|
| Loading / `transitioning` | All but `skip` dropped | U4 |
| Committed | All ignored until `run_started` (or S8 un-commit) | One `new_run` per press (double-activation guard, accessibility Motor) |
| Locked panel focused | Start Disabled; `Enter` on the panel inert | `start_run` from a locked hero is never sent (U7); engine guard `E_HERO_LOCKED` stays unreachable |
| Confirm open | Base disabled; focus trapped | Modal |
| Drawer open | None on the base | Non-blocking |

---

## 8. Data Requirements

| Data Element | Source System | Update Frequency | Who Owns It | Format | Null / Missing Handling |
|--------------|--------------|-----------------|-------------|--------|------------------------|
| Roster: `HeroDef` per hero present — `id`, `name`, `text` (identity line), `set`, `health`, `hero_power`, `starter_deck[15]`, `art`, `unlock {key, condition} | null` | Card Database | On open | Card Database (CR-3; heroes H-1) | Zero heroes cannot load (`Failed`); `art` missing → placeholder (always, v1) |
| `HeroPowerDef` — `name`, `cost` (2), `text` | Card Database | On open | Card Database / Heroes H-3 | Record | Must exist for every hero (validation) |
| Starter deck `CardDef`s (cost for the curve; name / text / stamps for the drawer) | Card Database | On open; on selection change | Card Database | Records | Validation guarantees 15 resolvable ids |
| Available / Locked per hero | Meta Progression `is_hero_unlocked(id)` | On open | Meta (M3.7) | bool | Absent Meta (MVP) → Available |
| Unlock hint: condition text from the `unlock` object + `unlock_progress(key) → {met, progress, parts}` | Meta Progression | On open | Meta (M2, F6) | `{met: bool, progress: 0–1, parts: {hero_id: bool}}` + current / target numbers ("8 / 16") | No definition for the key → lock without a hint |
| `stats_for_hero(id)` → wins, losses, best floor (stats line "NW · NL · best FN", run-ui U7) | Meta Progression | On open | Meta (M7, UI Requirements) | `HeroStats` | Zeros allowed ("0W · 0L · best F0"); absent Meta → line hidden |
| Set blurb per hero set (`hero.set_blurb.{set}`) | Localisation string table (heroes.md UI Requirements) | On open | Heroes | string ≤ 52 chars | Missing key → line hidden, never the raw key |
| `last_hero_id()` | Meta Progression | On open | Meta (M1.3) | id or null | null → War (DD-X02) |
| `load_active_run()` non-null | Meta Progression | On open | Meta | header fields | Null → Start needs no confirm |
| `allow_custom_seed` | Run Structure data | Static | Run Structure | bool | false → seed row hidden |
| Seed echo | RNG & Event Log `parse_seed(text)` | On every edit | RNG & Event Log (F1) | 16-hex string | Empty / whitespace → "Random" |
| Settings (`anim_speed`, `reduce_motion`, `text_scale`, `high_contrast_states`, volumes) | Meta Progression | `settings_changed` | Meta (M9) | DD-X07 record | Defaults when absent |
| Profile `ReadOnly` | Meta | On change | Meta (M6) | enum | OK → no banner |

> **Rule**: This screen must never write directly to any system listed above. All
> player actions fire events (see Section 9). Systems update their own data and
> notify the UI.

---

## 9. Events Fired

| Player Action | Event Fired | Payload | Receiver System | Notes |
|---------------|-------------|---------|-----------------|-------|
| Focus / select a hero | `select_hero(hero_id)` (local intent) | `{hero_id}` | Run UI (local) | No command; drives the Deck drawer and Start's target |
| Hover | none | — | — | Deliberate: hover is display only |
| Start (no active run) | `start_run(hero_id, seed_input)` → `new_run(hero_id, seed_input)` | `{hero_id, seed_input: raw string}` | Run Structure T2 → `run_started` → S1 save | **Persistent**: creates the run record and the active-run slot (DD-R08) — architecture attention: the UI only reacts to `run_started` |
| Start (active run saved) | `start_run` → `confirm` → on confirm `new_run` | as above | Run Structure (the old run is abandoned first: `run_ended{abandoned}`, Meta `archive_run`, **counts as a loss**) | AC-14 |
| Cancel in the confirm | `cancel` | — | Run UI | Nothing issued |
| Back / `Esc` | `back` → (`suspend()` if a `RunState` is in memory) | — | Run Structure T21 / Run UI | S23; no save, no event |
| Deck button | `open_deck_drawer` (local) | — | Run UI | — |
| Seed edit | none (local echo) | — | — | The raw text travels only with `start_run` |
| Rejection | (incoming) `E_HERO_LOCKED` / `E_CONFIG` → toast | `{code}` | Run UI | S8 |
| Toast dismiss | `dismiss` (local) | — | Run UI | Unlock already acked on show |

---

## 10. Transitions & Animations

| Transition | Trigger | Direction / Type | Duration (ms) | Easing | Interruptible? | Skipped by Reduced Motion? |
|------------|---------|-----------------|--------------|--------|----------------|---------------------------|
| Screen enter | New Run / Hero Select | Cross-fade `fade` | 250 × `speed_factor` | ease-out | Yes (any input skips) | No (already a fade); 0 at `instant` |
| Panel hover lift | Mouse over | Lift 8 px | 80 | ease-out | Yes | Lift kept, no bounce |
| Selection | Click / `Enter` | Outline moves; sting | instant | — | — | — |
| Card Inspect (power plate / drawer rows) | Hover 0.1 s / focus 0 ms | 1.5x text panel beside the element | 100 | ease-out | Yes | Without tween |
| Commit | Start | Press 60 ms; siblings dim | 60 | linear | No | — |
| Screen exit → run start | `run_started` | `fade` 250, then the `run_start` panel 600 ms (its own spec), skippable | 250 | ease-out | Yes | — |
| Screen exit → main menu | Back | `fade` 250 | 250 | ease-out | Yes | — |
| Confirmation Dialog open / close | Start with a saved run | Base dims to `table_dark`; panel scale 0.95 → 1 | 250 / 150 | ease-out | — | Scale removed; fade only |
| Drawer open / close | Deck | Slide 250 / 250 | 250 | ease-out | Yes | Fade at half duration |
| Toast in / out | Queue | Fade (+ slide) | 200 | ease-out | — | Fade only |

No impact moments on this screen (run-ui Game Feel counts exactly two for the whole shell, neither here). Restart budget: path B total ≤ 3150 ms at defaults (F1) — this screen's share is `select_ready` 300 ms + the player's `Enter`.

---

## 11. Input Method Completeness Checklist

Platform Target is keyboard + mouse; **Touch** dropped (not supported); **Gamepad** kept as the post-v1 mapping.

**Keyboard**
- [x] All interactive elements are reachable using Tab and arrow keys alone (§12 order; `Up`/`Down` in the drawer)
- [x] Tab order follows visual reading order after the default stop (Start first, then panels left → right, locked row, seed, Back, Deck)
- [x] Every action achievable by mouse is also achievable by keyboard
- [x] Focus is visible at all times (2 px ring, 3 px offset, also at `instant`)
- [x] Focus does not escape the screen while it is open (confirm traps; drawer stays in the shell)
- [x] Esc key closes or cancels (drawer → confirm → Back) and does not quit the game

**Gamepad** (post-v1 — mapping only)
- [ ] All interactive elements reachable with D-Pad and left stick — mapping defined, not implemented (§15 "Gamepad: d-pad graph")
- [ ] Face button mapping documented — `ui_accept` / `ui_cancel` only (§15 "Gamepad: face buttons")
- [x] No action requires analog stick precision
- [ ] Trigger and bumper shortcuts — library default (shoulders = Tab), nothing screen-specific (§15 "Gamepad: bumpers")
- [ ] Controller disconnection handling — not specified anywhere (§15 "Controller disconnection")

**Mouse**
- [x] Hover states defined for all interactive elements
- [x] Clickable hit targets are at minimum 32x32px (panels 340x340 / 340x88; buttons 160x44; field 332x36 inside a 44 px row; drawer rows 44 px)
- [x] Right-click behavior defined (closes the drawer; otherwise no-op)
- [x] Scroll wheel behavior defined (drawer only)

**Touch (if applicable)** — not applicable.

---

## 12. Accessibility

**Text contrast requirements for this screen**:

| Text Element | Background Context | Required Ratio | Current Ratio | Pass? |
|--------------|-------------------|---------------|---------------|-------|
| Title (28 px bold) | `bg_edge` | 3:1 | `text_light` 14.75 | [x] |
| Hero name, identity line, stats (16 / 14 / 13 px) | Hero primary (War `#9B2F23` / Decay `#355E3B` / Knowledge `#2C4F8A`) | 4.5:1 | `text_light` 6.17 / 6.19 / 6.72 (art bible §4) | [x] |
| Hero initial (24 px bold) on the portrait placeholder | Hero secondary (bronze `#B07A3A` / violet `#6B4C8A` / gold `#C9A24A`) | 3:1 | `text_ink` on bronze 4.68, gold 7.20; `text_light` on violet 5.76 (art bible rule per secondary) | [x] |
| Power name / text (14 / 12 px) | `parchment` plate | 4.5:1 | `text_ink` 12.72 | [x] |
| Curve numerals (12 px) | Hero primary | 4.5:1 | `text_light` ≥ 6.17 | [x] |
| Locked name / condition (16 / 14 px) | Neutral `#6F655A` | 4.5:1 | `text_light` 4.73 | [x] — the narrowest margin on the screen; never use `text_muted` here |
| Seed label / field text (16 px) | `bg_edge` / `table_dark` | 4.5:1 | 14.75 / 13.07 | [x] |
| Seed echo (13 px) | `bg_edge` | 4.5:1 | `text_muted` 7.94 | [x] (secondary information, 13 px allowed) |
| Button labels | `table_dark` | 4.5:1 | 13.07 / `text_muted` 7.03 (Idle) | [x] |

**Colorblind-unsafe elements and mitigations**:

| Element | Colorblind Risk | Mitigation |
|---------|----------------|------------|
| Hero identity by primary colour (War red vs Decay green — the classic pair) | Protanopia / deuteranopia | Initial letter on the portrait, name, identity line; War and Decay primaries differ in value (art bible); panel position is stable |
| Locked vs available | Grey vs colour | Lock glyph, smaller row, condition text; not selectable |
| Selected vs focused vs hovered | All light | Selected = hugging outline; focus = ring with a 3 px gap; hover = lift |
| Start Actionable vs Disabled | Outline vs `text_muted` | Label value + outline; Disabled reason tooltip on focus |
| Curve strip bars | None — numerals carry the count | — |

**Focus order** (Tab key sequence, numbered; `1`/`2`/`3` jump to stops 2–4):

1. **Start** (default on open; Disabled while a locked panel is focused)
2. Hero panel 1 (… up to 4. panel 3) — within a panel the power plate is not a separate stop; Card Inspect opens on the panel's focus
5. Locked panel 1 … 7. locked panel 3 (when present; inspect only — tooltip with condition and `parts`)
8. Seed field (when `allow_custom_seed`)
9. Back
10. Deck (when the drawer is open by key: header → rows with `Up`/`Down` → `Tab` returns here)
→ cycles to 1. The echo line, stats line and curve strip are not stops (text; nothing hover-only). Focus returns to Start after the Confirmation Dialog closes (trigger element).

**Screen reader announcements for key state changes**: Not committed (Standard tier; AccessKit live regions NOT SOURCEABLE — accessibility-requirements). Accessible names are still required so nothing blocks a later pass: hero panel "Hero n of N: <name> — <identity line> — power <name>, 2 mana: <text> — <wins> wins, best floor <f>" (+ "selected"); locked panel "<name>, locked — <condition> — <progress>"; Start "Start run as <hero>" ("Disabled — locked hero" when so); seed field "Seed, optional — current: <echo>". Stock `Button` / `LineEdit` expose roles for free.

**Cognitive load assessment**:

Streams: (1) three identities, (2) three powers, (3) three curves / stats, (4) locked heroes and their progress, (5) the seed field, (6) whether a saved run exists — six, within 7±2, and the resting view asks for one decision (`Enter`). Mitigations: pre-selection makes the default path zero-read; the locked row is visually subordinate; the seed field is quiet; the drawer is on demand; the confirm dialog states the one consequence ("counted as a loss") in one sentence (accessibility matrix, Run Structure row).

---

## 13. Localization Considerations

**General rules for this screen**:
- All text elements must tolerate a minimum of 40% expansion from English baseline
- RTL layout: the panel row and action row mirror (`1` is still the first panel in reading order); the seed field becomes RTL-aware (`LineEdit` handles bidi) but the **echo stays LTR** (hex digits); portrait placeholder stays at the panel's leading edge
- CJK: identity lines and power texts shorten — plates keep their size; nothing stretches
- Do not use text in images — all text from `tr()` keys or Card Database `text.key` / `text.en` (run-ui AC-22)

| Text Element | English Baseline Length | Max Characters | Expansion Budget | RTL Behavior | Overflow Behavior | Risk |
|--------------|------------------------|----------------|-----------------|--------------|-------------------|------|
| Title "Choose your hero" | 16 | 30 | 85 % | Centre | Shrink to 24 px then ellipsise | Low |
| Hero name ("Halvard, the Whetted") | 20 | 24 (172 px at 16 px bold ≈ 20 chars) | 20 % | Right-align | Ellipsise; full name in the tooltip | **High** — "Mother Wythe" fits, long translated epithets will not; flag for the localization engineer |
| Identity line (`HeroDef.text`, ~45–55) | 55 | 3 lines × ~22 = 66 | 20 % | Right-align, wrap | Ellipsise line 3; full line in the tooltip | Medium |
| Stats "3W · 5L · best F8" (`hero.stats` = "{w}W · {l}L · best F{f}") | 18 | 28 | 55 % | Mirror (numerals stay LTR) | Drops "best " ("3W · 5L · F8"), then moves under the portrait | Low |
| Set blurb "War: weapons, aggression, armour" (`hero.set_blurb.war`) | 32 | 52 (2 lines × 26 at 13 px in 172 px) | 60 % | Right-align, wrap | Ellipsise line 2; full line in the panel tooltip | Low |
| Power name ("Whetstone") | 9 | 20 | 120 % | Right-align | Ellipsise | Low |
| Power text (≤ 90, content.md) | ≤ 90 | 4 lines × ~40 at 12 px in 296 px = 160 | 75 % | Right-align, wrap | Ellipsise; full text in Card Inspect | Medium |
| Locked condition + progress ("Win a run with any hero — 0 / 1") | ~32 | 2 lines × 40 | 150 % | Right-align | Row grows 88 → 112 px (pushes the seed row 24 px) | Low |
| Seed label / placeholder / "Random" | 15 / 6 / 6 | 24 / 12 / 12 | 60 % | Label leads | Label ellipsises before the field shrinks | Low |
| Buttons "Back" / "Start" / "Deck (15)" | 4 / 5 / 9 | 16 | 200 % | Mirror positions | Button grows | Low |
| Confirm dialog title / body / button ("Start a new run?" / "This ends your current run — counted as a loss." / "Start new run") | 16 / 48 / 13 | 28 / 80 / 22 | 65 % | Mirror | Dialog grows downward | Low |
| Toast `E_HERO_LOCKED` copy | ≤ 60 | 84 | 40 % | — | Toast grows | Low |

---

## 14. Acceptance Criteria

Fixtures: run-ui U10 `fresh_profile`, `locked_heroes` and the settings variant `locked_heroes_ts150` (`text_scale` 1.5) with `--run-ui-screen=hero_select`, captured per `.claude/docs/run-and-observe.md` into `production/qa/evidence/`.

**Performance**
- [ ] First frame within 100 ms of the read model (run-ui AC-26) and `select_ready` ≤ 300 ms (F1) on the reference machine
- [ ] GIVEN a defeat summary, WHEN Hero Select → `Enter` on the pre-selected hero is timed with a scripted 1500 ms human pause, THEN the boss intro is visible within 5000 ms (run-ui AC-23 path B)
- [ ] Start press → `committed` visual within 50 ms

**Layout & Rendering**
- [ ] GIVEN `fresh_profile`, THEN exactly the heroes present in data appear (War only), centred at x 470, War is pre-selected with its power text and the 15-card curve / drawer, no locked row exists, and the seed field shows "→ Random" (run-ui AC-2)
- [ ] GIVEN `locked_heroes`, THEN three launch panels sit at x 90 / 470 / 850, y 72 (±2 px); Fortune, Order and Shadow appear as `#6F655A` panels at y 428 with a lock glyph and a condition + progress line; Start is Disabled while one of them is focused (run-ui AC-3)
- [ ] GIVEN each launch hero, THEN its panel fill is that hero's primary from art bible §4 and the power text equals `HeroPowerDef.text.en` exactly (heroes AC-17)
- [ ] GIVEN the window at 3840x2160, THEN the layout is the 1280x720 layout uniformly scaled (AC-31)
- [ ] GIVEN `settings.text_scale = 1.5` in the fixture profile, THEN no text clips, the locked row grows to 112 px, the seed row sits at y 564, and the power plate's full text is in the reading panel on focus (AC-31)
- [ ] All §6 states with a fixture render correctly; no "coming soon" filler exists when no hero is locked

**Input**
- [ ] GIVEN `locked_heroes` and keys `2` then `Enter` then `Enter` with no mouse input, THEN Mother Wythe is selected and `new_run("hero_decay", "")` is issued once (run-ui AC-19)
- [ ] GIVEN a fresh profile, WHEN `Enter` is pressed once on open, THEN `new_run("hero_war", "")` is issued (Start is the default focus with War pre-selected)
- [ ] GIVEN the seed field holding `"deckdelve"`, THEN the echo reads `48A10CC0B2ED54EC` and `start_run` passes the raw string (run-ui AC-18)
- [ ] GIVEN an active run saved, WHEN Start is pressed, THEN the Confirmation Dialog opens with Cancel focused and `new_run` is issued only after "Start new run"; `Esc` or Cancel issues nothing (run-ui AC-14)
- [ ] GIVEN a locked panel focused, WHEN `Enter` is pressed, THEN nothing is issued and Start's tooltip names the condition
- [ ] GIVEN `Esc` with nothing open, THEN the main menu appears with focus on New Run; GIVEN the drawer open, `Esc` closes it first
- [ ] Focus ring (2 px, 3 px offset) visible at every stop in a keyboard-only retained screenshot, also at `instant`

**Events & Data**
- [ ] The screen issues only the intents in §9; no direct call to Run Structure, Meta or Card Database from a screen script
- [ ] GIVEN `start_run` rejected `E_HERO_LOCKED`, THEN a toast shows, the screen un-commits and no second command is sent without a new press (S8)
- [ ] GIVEN a hero whose `unlock` key has no progress definition, THEN its panel shows the lock without a hint and the screen does not crash

**Accessibility**
- [ ] All text passes the §12 ratios in-engine (locked-row text on `#6F655A` measured explicitly)
- [ ] With colour removed (Coblis, both `high_contrast_states` values), War / Decay / Knowledge are identifiable by initial and name, and locked vs available by the glyph and row
- [ ] GIVEN `reduce_motion`, THEN the drawer and dialog fade, no lift bounce occurs
- [ ] GIVEN `anim_speed = instant`, THEN transitions are 0 ms and `committed` still blocks a double Start (AC-20)

**Localization**
- [ ] Zero literal English strings in the scene scripts (AC-22)
- [ ] Pseudo-locale +40 %: hero names ellipsise with the full name in the tooltip; nothing else overflows

---

## 15. Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Player journey map not yet created — author `design/player-journey.md` from `.claude/docs/templates/player-journey.md`; this screen's two arrival moods (cold start vs post-defeat) are inferred from the Core Loop and run-ui F1. | Jacob | Before Pre-Production gate | Open |
| Panel geometry (340x340 at F4's `slot_x`, locked row 340x88 at y 428, seed row y 540, action row y 640) is this spec's; run-ui F4 fixes only `slot_x`. Record in run-ui or keep spec-owned? | Run UI GDD owner | Pre-Production | Proposed here (spec-owned) |
| Starter-deck "expandable" preview (heroes UI Requirements) is resolved as the curve strip in-panel + the reused Deck drawer. Confirm, and add `DeckDrawer` to the pattern library (also used by `draft-picker.md`). | Jacob / ux-designer | `/ux-review hero-select` | **Decision taken here** |
| `LockedHeroPanel` as the "locked-item progress pattern" meta-progression's UX flag asks for (shared with the treasure codex / draft tooltip) — add to the pattern library. | ux-designer (`interaction-patterns.md`) | Before the treasure codex spec | Proposed here |
| More than 3 launch heroes or more than 3 locked heroes present in data (DD-H01/H02 give 3 + 3; "Full Vision" lists 6 heroes). `slot_x` handles n ≤ 3 per row; beyond that the rows need a second line or a scroll. | Run UI GDD owner + Jacob | Before any 4th launch hero | Open |
| Hero-specific select sting (heroes Visual/Audio) vs `ui_select` — which fires on selection and which on Start? This spec: sting on select, `ui_select` on Start. | Audio ADR | Before `/asset-spec system:heroes` | Proposed here |
| Hero name at 16 px bold in a 172 px column is the tightest text slot on the screen (≈ 20 chars) — art-director pass may widen the panel text column by shrinking the portrait placeholder to 96x128. | art-director | Alpha | Open |
| Controller disconnection handling (§11) — gamepad is post-v1. | ux-designer | Post-v1 | Open |
| AccessKit live regions — inherited NOT SOURCEABLE item. | ux-designer | Before first menu implementation | Open (inherited) |
