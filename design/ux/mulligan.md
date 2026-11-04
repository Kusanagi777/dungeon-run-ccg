# UX Spec: Mulligan (opening hand — keep / replace any subset, Confirm)

> Authoring guidance: .claude/docs/templates/guidance/ux-spec-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Design
> **Author**: Jacob + ux-designer (`/ux-design mulligan` followed by hand — the skill is not model-invocable; automation `guided` under the owner's standing approval, workflow `standard`, density `balanced` from `rigor: standard`; no `AskUserQuestion` used — the recommended option was taken at every decision point and is listed in §15; no Agent tool — `art-director` / `ui-programmer` / `game-designer` not spawned)
> **Last Updated**: 2026-11-04
> **Journey Phase(s)**: The first beat of every match — between the boss intro ("Fight") and the player's turn 1 (game-concept Core Loop "One match (3–6 minutes)"). Engine phase `Mulligan` (match-rules States); view state `Mulligan` (match-ui States). `design/player-journey.md` does not exist — see §15.
> **Screen / Flow Name**: `MulliganScreen` — `mulligan_screen.tscn` / `MulliganPresenter` (ADR-0009), opened by the `mulligan_offered` step (match-ui U3).
> **Platform Target**: PC (Windows primary, Linux dev/CI); 1280x720 logical, `canvas_items` + `keep` (DD-T05); mouse primary, keyboard complete; gamepad `Partial` post-v1; touch none (`project.yaml` has no `platform` block — values from `.claude/docs/technical-preferences.md` via `design/accessibility-requirements.md`).
> **Related GDDs**: `design/gdd/match-ui.md` U3 (`mulligan_offered`, `mulligan_resolved` rows), U5 (`Esc` never closes the Mulligan screen — the pause menu opens over it), U8 (Mulligan screen), U9 (concede from the pause menu), U11 (`mulligan` fixture), States (`Mulligan`; `Loading → Mulligan`, `Mulligan → Playback → Idle`), F6 (Choice / Mulligan row 278, 202, 723, 315), Edge Cases (`Esc` on the Mulligan screen), UI Requirements ("Mulligan screen" row → this file), AC O6, O17, O19; `design/gdd/match-rules.md` C2 (`mulligan(keep_mask)`, `INVALID_MASK`), C3 steps 5–8 (starting hands 3 / 4, one round, return-before-redraw, **DD-X13** — setup draws and mulligan redraws fire no `on_draw` hooks), C14 (concede legal in `Mulligan`), States (`Mulligan` row, transitions), Edge Cases "Mulligan and setup" (same card redrawn is legal; mask length follows a hook-modified hand size), Tuning Knobs (`STARTING_HAND_PLAYER` 3, safe 3–4), UI Requirements ("Mulligan hand with keep/replace toggles"); `design/gdd/treasures.md` (`treasure_bottomless_satchel` — `modify_starting_hand_size` +2; R-5 clamp `[0, HAND_SIZE]`); `design/gdd/card-effects.md` C9 (`modify_starting_hand_size` hook); `design/design-decisions.md` DD-M03 (player always first; boss compensates with a fourth card), DD-M05 (any subset, once), DD-X13.
> **Related ADRs**: ADR-0001 (the screen issues `mulligan` through `submit` only); ADR-0009 (`MulliganPresenter`, `CardFrame`, `ModalLayer` / `InspectLayer`).
> **Related UX Specs**: `design/ux/hud.md` (APPROVED — §5 `Mulligan` row: the row over a `table_dark`-dimmed table, hand fan hidden, End Turn Disabled, intent banner not yet shown, ticker lit); `design/ux/hand.md` (written in this run — where the kept cards go); `design/ux/interaction-patterns.md` (Pick One of N "Toggle variant (Mulligan)", Card (Hand), Card Inspect, Button (Primary), Overlay Open / Close "Mulligan / Choice overlay", Focus Management "mulligan → card 1", Escape / Cancel step (4), Standard Shortcuts, Rejection Feedback, Animation / Sound Standards); `pause-menu.md` (not yet written — Concede lives there); `design/accessibility-requirements.md`.
> **Accessibility Tier**: Standard with reduce-motion, visual-for-every-sound and the high-contrast state set elevated (`design/accessibility-requirements.md`). No timer (concept MDA "no timed input"): the boss waits indefinitely.
> **Template**: UX Spec

> **Sources read** (by section, coordination rule 6): match-ui U1–U12, States, F1, F2, F6, Edge Cases, Tuning Knobs, Visual/Audio, UI Requirements, AC, Open Questions; match-rules C2, C3, C11, C14, C15, States, Edge Cases (Mulligan and setup; Hand, draw and fatigue), Tuning Knobs (starting-hand rows), Visual/Audio, UI Requirements; treasures (grep: `modify_starting_hand_size`, Bottomless Satchel, R-5, AC-13); card-effects C8, C9 (hook table row); design-decisions (all rows); art bible §1–4, §7; accessibility-requirements Commitment, Visual, Motor, Cognitive; interaction-patterns Catalog, Card (Hand), Card Inspect, Pick One of N, Button (Primary), Overlay Open / Close, Focus Management, Escape / Cancel, Standard Shortcuts, Rejection Feedback, Animation / Sound Standards, Gaps; hud.md §3–§5, §10, Focus Order; story MUI-009; `production/session-state/active.md` (sibling conventions).

> **Note — Scope boundary**: A modal overlay on the match table that exists only in the `Mulligan` view state. It owns the opening-hand row, the keep / replace toggles, Confirm, and the hand-off animation into the fan. It does not own the pause menu or concede (`pause-menu.md`) or the fan the cards land in (`hand.md`). Numbers marked **F6** are match-ui's; numbers marked *spec* are this document's.

---

## 1. Purpose & Player Need

**What player need does this screen serve?**

The player wants a fair start. Before turn 1 they see their opening cards once and decide which to send back, knowing the rules exactly: **any** subset, **once**, the returned cards go back into the deck **before** the redraw so a card can come back (DD-M05, match-rules C3 step 7). The decision is small but it is the first read of the match — "what is my curve, what does this boss punish?" — and a mulligan screen that hides the boss's passive, rushes the player, or makes a toggle ambiguous turns a skill moment into a coin flip. Pillar 3 ("lose fast, learn fast") wants this beat short: the default action (keep everything) is one press.

**The player goal** (what the player wants to accomplish):

Read the opening cards (and the boss portrait with its passive), mark any to replace with a click or a number key, and confirm — in a few seconds when the hand is fine, as long as they like when it is not.

**The game goal** (what the game needs to communicate or capture):

Capture exactly one `mulligan(keep_mask)` whose length equals the offered hand size (match-rules C2 `INVALID_MASK`; Edge Cases: the length follows a hook-modified hand), show the result of the redraw card by card, and hand the final hand to the fan.

---

## 2. Player Context on Arrival

| Question | Answer |
|----------|--------|
| What was the player just doing? | Reading the boss intro (run-ui `boss_intro`: floor, band pips, boss name, intro line, **passive text — the brightest element**) and pressing Fight; the match scene loaded (≤ 500 ms, Loading State) and projected `mulligan_offered`. |
| What is their emotional state? | Anticipation with a plan forming — the boss passive is fresh in mind; first floor of a run: curious; a later floor with a strong deck: brisk. |
| What cognitive load are they carrying? | Low to moderate: 3 cards (5 with Bottomless Satchel), the boss passive, their deck's shape. |
| What information do they already have? | The boss and its passive (boss intro), their deck (from drafting), held treasures (tray on the table, still visible under the dim). They do **not** know the boss's cards; the boss's hand count (4, DD-M03) is visible on the boss strip. |
| What are they most likely trying to do? | Keep a curve of cheap plays; send back expensive cards or cards the boss passive neuters. |
| What are they likely afraid of? | Not knowing whether a toggled card is kept or replaced; replacing a card they meant to keep by a stray click; a timer (there is none). |

**Emotional design target for this screen**:

"A calm deal" — the cards are dealt face up on the dimmed table, every toggle reads as a word, and nothing happens until I say so.

---

## 3. Navigation Position

**Screen hierarchy**:

```
Run shell → Boss Intro (Fight) → Match scene
  └── Loading (projection, no input)
        └── Mulligan overlay (this spec) — modal, no cancel
              ├── Pause menu (Esc / top-bar menu button) → Resume · Settings · Concede → Confirm
              └── Confirm → Playback (redraw flip, cards into the fan) → Idle (player turn 1)
```

**Modal behavior**: Modal with **no cancel** (Overlay Open / Close row "Mulligan / Choice overlay": modal, dims the base, `Esc` opens Pause over it, focus on open = first option, closes on confirm). The base table is input-disabled recursively; the top bar's menu button and `Esc` reach the pause menu (match-ui U5: the chain skips a modal without a cancel and falls to step (4)). The only ways out are Confirm and Concede (pause menu → confirm dialog). The player cannot be stuck: Confirm is **always** enabled (replacing none is legal — U8).

**Reachability — all entry points**:

| Entry Point | Triggered By | Notes |
|-------------|-------------|-------|
| New match | `mulligan_offered` projected after `Loading` (match-ui States `Loading → Mulligan`) | Every match; the boss never mulligans (match-rules C3 step 6, boss-ai C11) |
| Fixture | `--fixture=mulligan` (match-ui U11: `MatchConfig` only, empty command list — the match rests at `mulligan_offered`) | Screenshot path |
| Never | Resume of a half-played match | Mid-match resume is out of v1 (match-ui Open Questions); a reload re-projects `events_since(0)` and, if the log ends at `mulligan_offered`, lands here again |

---

## 4. Entry & Exit Points

**Entry table**:

| Trigger | Source Screen / State | Transition Type | Data Passed In | Notes |
|---------|----------------------|-----------------|----------------|-------|
| `mulligan_offered` | `Loading` (table drawn, hand hidden) | `overlay_open` 0.2 s (F3): table fill steps to `table_dark`; cards scale 0.95 → 1.0 into the row; `sfx.ui.overlay` | `pending_mulligan` = the offered instance ids in hand order; `card_text` per card; boss and hero panels from the projection | Cards appear already face up — the deal happened in `Loading` |
| Fixture `mulligan` | Launch argument | None (U11: animations instant) | As above | — |

**Exit table**:

| Exit Action | Destination | Transition Type | Data Returned / Saved | Notes |
|-------------|------------|-----------------|----------------------|-------|
| Confirm (click, `Enter` on Confirm, or double-click is **not** a shortcut here — §7) | `Playback` → `Idle` | `committed` ≤ 50 ms → `mulligan_resolved` flip 0.3 s for each replaced card → `overlay_close` 0.15 s → cards travel into their F1 fan slots (`draw` 0.2 s) → turn 1 start (`card_drawn` slides the fourth card in) | `mulligan(keep_mask)` with one bit per offered card (true = keep) | **Irreversible** — one round only (`MULLIGAN_ROUNDS` 1) |
| Concede (pause menu → Concede → Confirm) | `Ended` (`match-end.md`, reason `concede`) | Pause and the Mulligan overlay close, the end banner plays | `concede` (`pause-menu.md`) | Counts as a loss — the run ends (DD-R07); legal in `Mulligan` (match-rules C14) |
| `Esc` / top-bar menu button | Pause menu **over** this overlay | Pause `fade` / scale 250 ms | Nothing | The overlay stays open with its toggles unchanged (match-ui O19) |
| Rejected `mulligan` (`INVALID_MASK`, `WRONG_PHASE`, `MATCH_ENDED` — a UI bug or a race) | Same overlay, un-committed | Rejection Feedback on Confirm (shake + tooltip + feed line) | Nothing changes | Should never fire from a correct UI |
| Window closed | — | — | Nothing — the run's last save is the pre-match save (DD-R08); resume returns to `pre_match` (boss intro) | No mid-match save in v1 |

---

## 5. Layout Specification

### 5.1 ASCII Wireframe

Default: three cards (`STARTING_HAND_PLAYER` 3), card 2 marked Replace — the F6 row 278, 202, 723, 315 (3 × 225x315, 24 px gaps) over the dimmed table:

```
 x:0  24          278            503 527            752 776            1001          1136     1256 1280
 y:0 ┌──────────────────────────────── top bar 0–40 (lit, `bg_edge`) ─────────────────────────────── [≡]┐
  48 │ [ticker: setup lines, lit]                                                     ┌──────────┐      │
  124 │                              Starting hand                  (28 px bold)      │   boss   │      │
  164 │      You go first. Replace any cards — they return to your deck first. (16 px)│ portrait │      │
 202 │            ┌────────────────┐ ┌────────────────┐ ┌────────────────┐             │ passive  │      │
     │            │ ③              │ │ ⑤  ╲ ╱ ╲ ╱ ╲ ╱ │ │ ②              │             └──────────┘      │
     │            │ NAME           │ │ NAME  hatch    │ │ NAME           │              hand ▮▮▮▮ 4     │
     │            │ [art]          │ │ [art]  (✕)     │ │ [art]          │                              │
     │            │ rules text     │ │ rules text     │ │ rules text     │       (table fill: table_dark)│
     │            │ 18 px          │ │ (readable)     │ │                │                              │
 517 │            └────────────────┘ └────────────────┘ └────────────────┘                              │
 525 │                 [  Keep  ]       [ ✕ Replace ]        [  Keep  ]     pills 24 px (*spec*)         │
 557 │                                Replacing 1 of 3                       (16 px, *spec*)              │
 589 │                                 ( Confirm )            Primary 160x44 at 560, 589 (*spec*)         │
 720 └─────────────────────────────────────────────────────────────────────────────────────────────────────┘
       Focus on open: card 1 (ring 3 px outside the card).  Card 2 replaced: dropped 12 px, hatch over the
       art box and frame only (text box stays clear), ✕ glyph, pill reads "Replace".
```

**Hand-size variants** (the offered hand size is `len(pending_mulligan)`, which a `modify_starting_hand_size` hook can change — match-rules Edge Cases; Bottomless Satchel makes it 5):

| n | Card size | Rows | Row geometry (*spec* unless F6) | Title / sub-line y | Pills y | Status y | Confirm |
|---|---|---|---|---|---|---|---|
| 0 | — | — | No row; the sub-line reads "No cards in your opening hand." | 124 / 164 | — | — | 560, 589, 160, 44, label "Start" |
| 1 | 225x315 | 1 | x 527.5, y 202 | 124 / 164 | 525–549 | 557–577 | 560, 589, 160, 44 |
| 2 | 225x315 | 1 | x 403 / 652, y 202 (width 474, centred) | 124 / 164 | 525–549 | 557–577 | 560, 589 |
| **3** | 225x315 | 1 | **F6 278, 202, 723, 315** — x 278 / 527 / 776 | 124 / 164 | 525–549 | 557–577 | 560, 589 |
| 4 | 225x315 | 1 | width 972 → x 154 + 249·i, y 202 | 124 / 164 | 525–549 | 557–577 | 560, 589 |
| 5 (Bottomless Satchel — the v1 maximum) | 225x315 | 1 | width 1221 → x 29.5 + 249·i, y 202 (29.5 px margins) | 124 / 164 | 525–549 | 557–577 | 560, 589 |
| 6–10 (not reachable with v1 content) | 150x210 | 2 — row 1 = ⌈n/2⌉ cards, row 2 = the rest, 16 px gaps, each row centred | row 1 y 136–346, row 2 y 392–602 | 60 / 100 | 352–376 / 608–632 | 640–660 | 560, 668, 160, 44 |

For n ≥ 6 the cards are thumbnails (12 px text), so hover / focus opens Card Inspect's 1.5x preview centred on the card and clamped to y 48–712 (on `InspectLayer`, `MOUSE_FILTER_IGNORE`). For n ≤ 5 the cards are already the 1.5x size (18 px text) and need no preview at 100 % `text_scale`.

**Reading panel at `text_scale` ≥ 125 %** (n ≤ 5; same rule as `hand.md` §5.1 adapted to the row): 360 wide, top y 202 (the row's top), height = content up to 315 then the panel's text scrolls; right of the card if the card's centre x < 640, else left; 8 px gap; x clamped to 8–912. At n = 3: card 1 → panel x 511 (over card 2, on top), card 2 (centre 639.5) → right x 760, card 3 → left x 408. At n ≥ 6 the panel sits beside the 1.5x preview by the same side rule.

### 5.2 Layout Zones

| Zone Name | Description | Approximate Size | Scrollable? | Overflow Behavior |
|-----------|-------------|-----------------|-------------|-------------------|
| Dimmed table (base) | Everything under the overlay: the table fill steps `table_lit` → `table_dark`; **portraits, the boss passive plate, the boss hand count, the tray and the top bar keep their contrast** (art bible §2: dimming lowers the fill, not the contrast) — the player can read the boss passive while deciding; feed ticker lit | 1280 x 720 | No | — |
| Title | "Starting hand", 28 px bold `text_light` (art bible screen title), centred, y 124 (n ≤ 5) / 60 (n ≥ 6) | ≤ 600 x 34 | No | Never wraps (≤ 24 chars English) |
| Sub-line | 16 px `text_muted`, centred, y 164 / 100: "You go first. Replace any cards — they return to your deck first." | ≤ 900 x 20 | No | Wraps to at most 2 lines at an 18 px line height (pushes nothing — the row is fixed; 2 lines end at y 200, 2 px above the row top at y 202) |
| Card row | F6 for n = 3; §5.1 table otherwise | 723 x 315 (n = 3) | No | — |
| Toggle pills | One per card, centred under it, 24 px tall: Keep = `table_dark` pill, 14 px `text_light` "Keep"; Replace = `ink` pill, 14 px bold `text_light` "✕ Replace" | card width x 24 | No | Pill grows to the card width, then the label shrinks to 12 px |
| Status line | 16 px `text_light`, centred: "Keeping all 3" / "Replacing 1 of 3" / "Replacing all 3" | ≤ 400 x 20 | No | — |
| Confirm | Button (Primary) 160x44, always Actionable (2 px `state_actionable` outline, `text_light`) | 160 x 44 | No | Label grows the button (Button pattern) |

### 5.3 Component Inventory

| Component Name | Type | Zone | Purpose | Required? | Reuses Existing Component? |
|----------------|------|------|---------|-----------|---------------------------|
| Opening-hand card ×n | Card (interactive toggle) | Card row | One offered card, face up; click / key toggles keep ↔ replace | Yes | Yes — Card (Hand) at 1.5x (`CardFrame`) + Pick One of N "Toggle variant" |
| Replace overlay | Overlay on the card | Card | Hatch (2 px `ink` lines at 45°, ~25 % coverage) over the **art box and frame only**, a 48 px `✕` glyph in `text_light` on a 56 px `ink` circle centred on the art box, card dropped 12 px | Yes (when replaced) | Yes — Pick One of N toggle "crossed card-back overlay + Replace word", **refined here**: the text box stays readable (§15) |
| Toggle pill | Label | Under each card | "Keep" / "✕ Replace" — the word is the state | Yes | **New here** (*spec*) — the toggle's text half |
| Title / sub-line | Text | Header | Orientation and the DD-M05 rule in one line | Yes | Plain `Label`s |
| Status line | Text | Under the pills | Count of replacements — the consequence of Confirm in words | Yes | Plain `Label` |
| Confirm | Button (Primary) | Footer | Sends `mulligan(keep_mask)` | Yes | Yes — Button (Primary); Pick One of N "Mulligan: Confirm always Actionable" |
| Card Inspect preview (+ reading panel) | Overlay | `InspectLayer` 80 | Full text at n ≥ 6, reading panel at ≥ 125 % | Conditional | Yes — Card Inspect (inspect draws above modals — Overlay Implementation Notes) |
| Pause menu | Modal | Over everything | Resume / Settings / Concede | Yes | Yes — `pause-menu.md` |
| Rejection tooltip | Tooltip | Above Confirm | Race only | Yes | Yes — Rejection Feedback (`targeting.md` §12 copy) |

**Primary focus element on open**: **Card 1** (Focus Management "mulligan → card 1"; Overlay table "First option"). For n = 0, Confirm ("Start").

### 5.4 Information Hierarchy

1. **The cards** — face up, 1.5x, the brightest objects on the dimmed table (art bible §1: "everything the player must read is lit").
2. **Keep or replace, per card** — the word under each card plus the drop and the ✕; never only an overlay.
3. **What Confirm will do** — the status line ("Replacing 1 of 3").
4. **The rule** — the sub-line: any cards, returned before the draw, you go first.
5. **Context under the dim** — boss portrait with its passive, boss hand count 4, the tray: readable, not interactive.

---

## 6. States & Variants

| State Name | Trigger | What Changes Visually | What Changes Behaviorally | Notes |
|------------|---------|----------------------|--------------------------|-------|
| Opening | `mulligan_offered` projected | `overlay_open` 0.2 s: fill dims, cards scale in, all pills "Keep", status "Keeping all n" | Input accepted once the 0.2 s open completes (any input during it skips it — U4.5) | Fixture `mulligan` |
| Default (all keep) | Open | No overlays on cards; Confirm Actionable | Confirm sends an all-`true` mask (legal "keep all", C3 step 7) | One press from open: Tab ×n then `Enter`, or one click |
| Card hovered | Pointer over a card | Lift 8 px, no ring (n ≤ 5); Card Inspect preview (n ≥ 6) | Hover never toggles and never moves focus | — |
| Card focused | Open default, `Tab`, number key | 2 px focus ring 3 px outside the card (or outside its preview at n ≥ 6) | `Enter` / `Space` toggles it | — |
| Card replaced | Click / `Enter` / number key on a kept card | Replace overlay (hatch on art + frame, ✕, drop 12 px), pill "✕ Replace", status count updates | Same input again → keep | 80 ms ease-out drop |
| Some / all replaced | Toggles | Status "Replacing k of n" / "Replacing all n" | Confirm sends the mask | All-replace is legal (DD-M05) |
| Committed | Confirm | Confirm pressed state stays; cards lock (no hover lift); toggles ignored | Exactly one `mulligan(keep_mask)`; every further input ignored until the overlay closes | ≤ 50 ms; double-activation guard (Pick One of N `committed`) |
| Resolving (flip) | `mulligan_resolved` | Each replaced card flips to its back (0.15 s) and up as the newly drawn card (0.15 s) **in its own slot**; kept cards hold; `sfx.ui.draw` once | Input = skip only | The same card coming back is legal and shows the same face — not a bug (match-rules Edge Cases) |
| Closing | After the flip | `overlay_close` 0.15 s, then the n cards travel into their F1 fan slots (`draw` 0.2 s); fill returns to `table_lit` | Input = skip only | Hand-off to `hand.md` |
| Empty opening hand | `len(pending_mulligan) == 0` (a hook set the size to 0 — clamp `[0, HAND_SIZE]`, treasures R-5) | No row, no pills, no status; sub-line "No cards in your opening hand."; Confirm labelled "Start", focused | Confirm sends `mulligan([])` | Reachable only with test data in v1 |
| 4–5 cards | Bottomless Satchel (+2) or `STARTING_HAND_PLAYER` 4 | Wider single row (§5.1 table) | `1`–`5` toggle | Fixture *proposed* `mulligan_satchel` |
| 6–10 cards | Test data only | Two rows of 150x210 cards; Card Inspect on hover / focus | `1`–`9`, `0` toggle cards 1–10 | Not reachable with v1 content (§15) |
| Pause open | `Esc` / menu button | Pause modal over this overlay (both dimmed layers stack) | Mulligan input disabled; focus → Resume; on close focus returns to the card / Confirm it left | match-ui O19 |
| Concede confirm | Pause → Concede | Confirmation Dialog (`pause-menu.md`) | Cancel focused | Destructive pattern |
| Rejected | `submit` → `accepted = false` | Confirm shakes 0.2 s; tooltip above Confirm 1.5 s (`reject.<code>`, `targeting.md` §12); feed line | Un-committed; toggles keep their states | Race / bug only |
| `text_scale` 125 / 150 % | Setting | Title, sub-line, pills, status, Confirm label grow; cards do not (fixed slots); reading panel on hover / focus (§5.1) | — | Fixture *proposed* `mulligan_ts150`; at 150 % the sub-line wraps to 2 lines at 18 px line height |
| `reduce_motion` | Setting | Open / close: fade only (no scale); flip → cross-fade back-to-new face (0.15 s); card travel into the fan kept (positional); replace drop kept but instant | — | Animation Standards |
| `anim_speed = instant` | Setting / harness | Every transition 0 ms; focus ring still drawn | `committed` still blocks a second Confirm | — |

---

## 7. Interaction Map

Mapping interactions for: **keyboard + mouse** (Phase 2h — no `platform` block; technical-preferences via accessibility-requirements). Covering **Partial** gamepad support as a post-v1 mapping onto the same focus graph; touch not supported.

### 7.1 Navigation Inputs

| Input | Platform | Action | Visual Response | Audio Cue | Notes |
|-------|----------|--------|-----------------|-----------|-------|
| `Tab` / `Shift+Tab` | KB | Cycle: card 1 → … → card n → Confirm → wrap | Ring moves | `ui_hover` | Focus is trapped in the overlay (modal) |
| `Left` / `Right` | KB | Move focus between cards in the row (row 1 / row 2 wrap at n ≥ 6) | Ring moves | `ui_hover` | Convenience; `Tab` alone is sufficient |
| Mouse hover | PC | Lift 8 px (n ≤ 5) / Card Inspect (n ≥ 6) | — | `ui_hover` | Never toggles |
| Mouse wheel | PC | Scroll an overflowing reading panel | — | — | Only at ≥ 125 % with long text |
| Gamepad (post-v1) | — | d-pad over the row and Confirm; `ui_accept` toggles / confirms | Same | Same | Not wired in v1 |

### 7.2 Action Inputs

| Input | Platform | Context (What must be focused) | Action | Response | Animation | Audio Cue | Notes |
|-------|----------|-------------------------------|--------|----------|-----------|-----------|-------|
| LMB | PC | Pointer over a card or its pill | Toggle keep ↔ replace; focus moves to the card | Overlay / pill / status update | 80 ms drop / rise | `ui_select` | A click is a toggle, never a commit |
| `1`–`9`, `0` | KB | Overlay open | Toggle card 1–10 and focus it | As click | 80 ms | `ui_select` | match-ui U8 names `1`–`3`; `4`–`0` are this spec's extension for n > 3 (§15); a key past n is ignored |
| `Enter` / `Space` | KB | A card focused | Toggle it | As click | 80 ms | `ui_select` | `Space` is not skip here (nothing is animating — Skip & Playback "When NOT to Use") |
| `Enter` / `Space` / LMB | KB / PC | Confirm focused / under the pointer | Confirm | `committed` | ≤ 50 ms | `ui_select` (weighted) | Always enabled |
| LMB ×2 on a card | PC | — | Two toggles (back to the original state) — **not** a confirm shortcut | — | — | `ui_select` ×2 | Unlike drafts, double-click here would be ambiguous with toggling (§15) |
| `Esc` | KB | Any | Open the pause menu over the overlay (chain step 4) | Pause opens | 250 ms | `sfx.ui.overlay` | Never closes or confirms the mulligan (U5, O19) |
| Top-bar menu button | PC | — | Same as `Esc` | — | — | — | The bar stays lit and clickable above the dim |
| RMB | PC | Any | Nothing (no session, no drawer to close — Escape / Cancel RMB steps 1–2 only) | — | — | — | — |
| Any input | all | During open / flip / close | Skip that transition to its end state | Instant | 0 | — | U4.5 |

### 7.3 State-Specific Behaviors

| State | Input Restriction | Reason |
|-------|------------------|--------|
| Opening (0.2 s) | Any input skips the open; it does not also toggle | No toggle lands on a half-drawn row |
| Committed / Resolving / Closing | Toggles and Confirm ignored; skip allowed | One `mulligan` per match (`MULLIGAN_ROUNDS` 1) |
| Pause / concede confirm open | Mulligan input disabled recursively; focus trapped in the top modal | Modal stack |
| Base table | Disabled (End Turn Disabled, hand hidden, tokens / portraits not interactive; hover tooltips on portraits off) | The overlay is modal; the boss passive is readable as plain text on the plate |

---

## 8. Data Requirements

| Data Element | Source System | Update Frequency | Who Owns It | Format | Null / Missing Handling |
|--------------|--------------|-----------------|-------------|--------|------------------------|
| `pending_mulligan` — offered instance ids in hand order | `MatchViewState` from `mulligan_offered` (match-ui U3) | Once | Match Rules (C3) / Match UI (projection) | `[{instance_id, card_id}]`, length 0–10 | Length 0 → empty variant (§6) |
| Card fields per id (`name_key`, `text_key`, `type`, `cost`, `attack`, `health`, `durability`, `keywords`) | Card Database via `MatchQuery.card_text` | Once | Card Database | Record | Unresolved key → `??key` + debug warning |
| Effective cost per offered card | **Not projected before turn 1** — the opening hand shows printed cost (no aura or hook has run on hand cards before `match_started`; `on_match_start` hooks that touch costs would be shown from `Idle` on) | — | Match Rules | — | Printed cost shown; §15 confirms with the Match Rules owner |
| Keep / replace toggles | Local view-state of `MulliganPresenter` | Per input | Match UI (UI-local) | `bool[n]` | All `true` on open |
| Redrawn ids | `MatchViewState` from `mulligan_resolved` (hand replaced) | Once | Match Rules | ids | — |
| Boss portrait, passive text, boss hand count, tray, top bar | `MatchViewState` / `MatchConfig` | Static here | Boss AI / Card Database / Treasures | — | As hud.md |
| Settings: `text_scale`, `reduce_motion`, `anim_speed`, `high_contrast_states` | Meta Progression (DD-X07) | `settings_changed` | Meta | Record | Defaults |

> **Rule**: This screen must never write directly to any system listed above. All
> player actions fire events (see Section 9). Systems update their own data and
> notify the UI.

The toggles are the one piece of UI-local state on the match screen that is not a projection; they are not game state (nothing in the engine changes until `mulligan`), they are not persisted (a reload re-opens the overlay with all "Keep"), and they are cleared on close.

---

## 9. Events Fired

| Player Action | Event Fired | Payload | Receiver System | Notes |
|---------------|-------------|---------|-----------------|-------|
| Toggle a card | none (local) | `{index, keep}` | `MulliganPresenter` | Deliberate: the choice is not game state until Confirm |
| Confirm | `mulligan` | `{keep_mask: bool[n]}` (true = keep; length = n) | Match Rules C3 step 7 → `mulligan_resolved`, `match_started`, turn 1 Start step | **Persistent state change** (deck and hand); DD-X13: the redraws fire no `on_draw` hooks — no treasure flare or trigger glow is expected during the flip |
| `Esc` / menu button | `open_pause` (local) | — | Match UI | — |
| Concede (via pause) | `concede` | — | Match Rules C14 → `match_ended{reason: concede}` | **Persistent** — loss, run ends (`pause-menu.md` owns the dialog) |
| Rejected Confirm | (incoming) `command_rejected{diagnostic}` → `reject_shake` + `feed.command_rejected` | `{command: mulligan, code}` | Match UI | — |

No analytics in v1; the event log records `mulligan_offered` / `mulligan_resolved` (Pillar 4).

---

## 10. Transitions & Animations

| Transition | Trigger | Direction / Type | Duration (ms) | Easing | Interruptible? | Skipped by Reduced Motion? |
|------------|---------|-----------------|--------------|--------|----------------|---------------------------|
| Overlay open | `mulligan_offered` | Fill dims; cards scale 0.95 → 1.0 | 200 (`overlay_open`) ÷ `SPEED_DIV` | ease-out | Yes (any input) | Scale removed → fade |
| Toggle to replace / keep | Click / key | Card drops 12 px / rises; hatch and ✕ appear / disappear; pill word swaps | 80 | ease-out | Yes | Drop instant |
| Commit | Confirm | Confirm pressed; cards lose hover lift | 60 | linear | No (state) | — |
| Redraw flip | `mulligan_resolved` | Each replaced card: to its back (150) and up as the new card (150), all replaced cards together | 300 (`mulligan_resolved` row, U3) | ease-out | Yes | Flip → cross-fade 150 |
| Overlay close | After the flip | Fill returns to `table_lit`; row fades | 150 (`overlay_close`) | ease-out | Yes | Fade (already) |
| Cards into the fan | After close | Each card travels from its row slot to its F1 fan slot, scaling 1.5 → 1.0 (n ≥ 6: 1.0 → 1.0) and rotating to `rot_i` | 200 (`draw`) | ease-out | Yes | Kept — positional travel |
| Turn 1 draw | `card_drawn` | `hand.md` §10 | 200 | ease-out | Yes | Kept |

`sfx.ui.overlay` on open; `ui_select` per toggle and on Confirm; one `sfx.ui.draw` for the flip group; no sound on close. Every sound is the twin of a visible change (accessibility-requirements SFX audit row `sfx.ui.overlay` "Choice / mulligan / menu opened").

---

## 11. Input Method Completeness Checklist

Platform Target is keyboard + mouse; **Touch** dropped; **Gamepad** unticked as the post-v1 mapping. Every untick has a §15 row.

**Keyboard**
- [x] All interactive elements are reachable using Tab and arrow keys alone (cards, Confirm; number keys toggle directly)
- [x] Tab order follows visual reading order (cards left → right, row 1 then row 2, then Confirm)
- [x] Every action achievable by mouse is also achievable by keyboard (toggle, confirm, pause / concede)
- [x] Focus is visible at all times (2 px ring 3 px outside the card / preview / Confirm, also at `instant`)
- [x] Focus does not escape the screen while it is open (modal trap; the pause menu traps its own)
- [x] Esc key closes or cancels — here it opens the pause menu (the overlay has no cancel, U5) and never quits

**Gamepad** (post-v1 — documented mapping only)
- [ ] All interactive elements reachable with D-Pad and left stick — §15 "Gamepad: mulligan d-pad graph"
- [ ] Face button mapping documented and consistent with platform conventions — `ui_accept` toggles / confirms; a "Confirm from anywhere" button (Start / Menu) is undecided — §15 "Gamepad: face buttons"
- [x] No action requires analog stick precision that cannot be replicated with D-Pad
- [ ] Trigger and bumper shortcuts documented if used — library default — §15 "Gamepad: bumpers"
- [ ] Controller disconnection while screen is open is handled gracefully — §15 "Controller disconnection"

**Mouse**
- [x] Hover states defined for all interactive elements (lift on cards; Button pattern on Confirm)
- [x] Clickable hit targets are at minimum 32x32px (cards 225x315 / 150x210 including their pill; Confirm 160x44)
- [x] Right-click behavior defined (no-op)
- [x] Scroll wheel behavior defined in all scrollable zones (overflowing reading panel only)

**Touch (if applicable)** — not applicable.

---

## 12. Accessibility

Project-wide commitments are in `design/accessibility-requirements.md`. Ratios are art bible §4 figures; † computed for this spec from the §4 hex values.

**Text contrast requirements for this screen**:

| Text Element | Background Context | Required Ratio | Current Ratio | Pass? |
|--------------|-------------------|---------------|---------------|-------|
| Title (28 px bold) | `table_dark` (dimmed fill) | 3:1 (large) | `text_light` 13.07 | [x] |
| Sub-line (16 px) | `table_dark` | 4.5:1 | `text_muted` 7.03 | [x] |
| Status line (16 px) | `table_dark` | 4.5:1 | `text_light` 13.07 | [x] |
| "Keep" pill (14 px) | `table_dark` pill | 4.5:1 | 13.07 | [x] |
| "✕ Replace" pill (14 px bold) | `ink` pill | 4.5:1 | 14.33 | [x] |
| Card text (18 px at 1.5x) under no overlay / beside the hatch | `parchment` | 4.5:1 | `text_ink` 12.72 — the hatch never covers the text box | [x] |
| ✕ glyph | `ink` circle | 3:1 (non-text) | 14.33 | [x] |
| Confirm label (16 px) | `table_dark` | 4.5:1 | 13.07 | [x] |
| Boss passive plate under the dim | Plate unchanged (the fill dims, not the plate) | as hud.md | as hud.md | [x] |

**Colorblind-unsafe elements and mitigations**:

| Element | Colorblind Risk | Mitigation |
|---------|----------------|------------|
| Keep vs replace | None used — no hue distinguishes them | Word in the pill, ✕ glyph, hatch, 12 px drop, and the status count: five redundant cues, none of them colour |
| Focus vs hover | Both light | Focus ring 3 px outside; hover lift, no ring |
| Hero-coloured card frames | Identification only | Not a state |

**Focus order** (Tab key sequence; trapped while open):

1. Card 1 (default on open) → 2. Card 2 → … → n. Card n (row 1 left → right, then row 2 at n ≥ 6) → n+1. Confirm → wraps to card 1.
`1`–`9`, `0` toggle-and-focus card 1–10; `Esc` opens the pause menu (its Resume takes focus; closing it returns focus here). Base-table elements and the top bar's feed toggle are **not** stops while the modal is open; the top-bar menu button is reachable by pointer and its function by `Esc`.

**Screen reader announcements for key state changes**: Not committed (AccessKit live regions NOT SOURCEABLE). Accessible names required: "Card 2 of 3: <name>, <cost> mana — keep" / "— replace"; Confirm: "Confirm — replacing 1 of 3".

**Cognitive load assessment**: Three things to read (cards) and one rule (sub-line); the decision is per card and binary; the consequence is counted in words; no timer, no hidden state (the toggle is visible on the card *and* in words); the boss's passive stays readable under the dim so the decision can be informed without memory. Reading time: unlimited (no auto-advance).

**Motor**: every action is a single discrete press; no hold; the mis-press cost is one more press (toggle back); Confirm is the only commit and is a separate, always-same control.

---

## 13. Localization Considerations

**General rules for this screen**:
- All text elements must tolerate a minimum of 40% expansion from English baseline
- RTL: the card row does **not** mirror (hand index 1 is the left-most card; number keys and the mask order depend on it — the mask is in hand order); title, sub-line and status centre; pills centre under their card
- CJK: shorter; nothing stretches
- All strings are keys (`mulligan.title`, `mulligan.rule`, `mulligan.keep`, `mulligan.replace`, `mulligan.status_keep_all`, `mulligan.status_replacing`, `mulligan.confirm`, `mulligan.start`, `mulligan.empty`); card text through Card Database keys

| Text Element | English Baseline Length | Max Characters | Expansion Budget | RTL Behavior | Overflow Behavior | Risk |
|--------------|------------------------|----------------|-----------------|--------------|-------------------|------|
| Title "Starting hand" | 13 | 24 | 85 % | Centre | Shrink to 24 px bold | Low |
| Sub-line rule | 64 | 110 | 70 % | Centre | Wraps to 2 lines at 18 px line height (ends y 200 at n ≤ 5, above the row top at 202); a translation that would need a third line drops to 14 px, at which the 110-char budget fits two 900 px lines; the sub-line never exceeds 2 lines / 36 px | **High** — layout-critical above the F6 row |
| "Keep" / "✕ Replace" pills | 4 / 9 | 16 | 75 % | Centre | Pill grows to the card width; then 12 px | Medium (150 px cards at n ≥ 6) |
| Status "Replacing 1 of 3" / "Keeping all 3" | 16 / 13 | 28 | 75 % | Centre; numbers per locale | Never truncates (400 px) | Low |
| Confirm / Start | 7 / 5 | 16 | 130 % | Centre | Button grows | Low |
| "No cards in your opening hand." | 30 | 56 | 85 % | Centre | Wraps | Low |
| Card names / text | per `hand.md` §13 | — | — | — | At 1.5x the 18 px text box holds ~4–5 lines; longer → reading panel | **High** (inherited) |

---

## 14. Acceptance Criteria

Fixtures are match-ui U11's (`--fixture=<name>`), captured per `.claude/docs/run-and-observe.md` into `production/qa/evidence/`; *proposed* fixtures and poses are listed in §15.

**Performance**
- [ ] The overlay is fully drawn and interactive within 200 ms (`overlay_open`) of `mulligan_offered` being projected at `normal` (0 at `instant`); a toggle shows its new state within 50 ms of the input
- [ ] Confirm → `committed` visual within 50 ms; `mulligan_resolved` flip + close + travel complete within 650 ms at `normal` (300 + 150 + 200)

**Layout & Rendering**
- [ ] GIVEN `--fixture=mulligan`, WHEN captured, THEN three 225x315 cards sit at x 278 / 527 / 776, y 202 (±2 px) over a `table_dark` table fill, each with a "Keep" pill under it, the status reads "Keeping all 3", and Confirm (160x44 at 560, 589) carries the actionable outline (match-ui O6)
- [ ] GIVEN the same capture, THEN the boss portrait, its passive plate and the boss hand count "4" are at full contrast (only the table fill is dimmed), and the hand fan is not drawn
- [ ] GIVEN *proposed* `--pose=mulligan:010` on `mulligan`, WHEN captured, THEN card 2 is dropped 12 px with the hatch over its art box and frame only, a ✕ glyph and the pill "✕ Replace", its rules text still readable, and the status reads "Replacing 1 of 3"
- [ ] GIVEN *proposed* `mulligan_satchel` (Bottomless Satchel held — 5 cards), WHEN captured, THEN five 225x315 cards sit at x 29.5 + 249·i (±2 px), y 202, nothing clipped, and keys `4` / `5` toggle cards 4 / 5
- [ ] GIVEN *proposed* `mulligan_ts150`, WHEN captured with `--pose=focus:mulligan:1`, THEN title, sub-line (≤ 2 lines, above y 202), pills, status and Confirm are scaled with no clipping or overlap, the cards are unscaled, and the reading panel sits at x 511, y 202, 360 wide with 27 px text
- [ ] GIVEN a hand size of 0 (test data), WHEN the overlay opens, THEN no row is drawn, the sub-line reads "No cards in your opening hand.", and Confirm reads "Start" and holds focus

**Input**
- [ ] GIVEN `mulligan`, WHEN each of the 8 keep / replace subsets is produced by clicks and, separately, by keys `1`–`3`, and Confirm is pressed, THEN exactly one `mulligan(keep_mask)` with that mask is submitted and accepted, including all-keep and all-replace (story MUI-009)
- [ ] GIVEN `mulligan` with no input, WHEN `Tab` ×3 then `Enter` is pressed, THEN an all-`true` mask is submitted (keep-all in four presses; one click on Confirm also does it)
- [ ] GIVEN focus on card 1 at open, WHEN `Enter` is pressed, THEN card 1 toggles to Replace and nothing is submitted
- [ ] GIVEN Confirm double-clicked (two clicks within 100 ms), THEN exactly one `mulligan` is submitted (committed guard)
- [ ] GIVEN `mulligan`, WHEN `Esc` is pressed, THEN the overlay is still open with its toggles unchanged and the pause menu is open above it with Resume focused; `Esc` again closes the pause menu and focus returns to the element it left (match-ui O19)
- [ ] GIVEN the pause menu over the mulligan, WHEN Concede is confirmed, THEN `concede` is submitted, the match ends with reason `concede`, and the end banner (`match-end.md`) plays
- [ ] O17 (headless): the keyboard-only and mouse-only paths to the same mask leave identical `MatchViewState` and `InputRouter` states (fixture `mulligan`)

**Events & Data**
- [ ] The submitted `keep_mask` length equals `len(pending_mulligan)` for n ∈ {0, 3, 5} (no `INVALID_MASK` from a correct UI)
- [ ] GIVEN `mulligan_resolved`, WHEN projected at `normal`, THEN only the replaced cards flip (0.3 s), the overlay closes (0.15 s), the cards travel into their F1 slots, and the view moves `Mulligan → Playback → Idle` with `_assert_in_sync` clean after the drain
- [ ] GIVEN a held treasure with an `on_draw` hook, WHEN cards are replaced, THEN no tray flare, trigger glow or feed line for that hook appears during the redraw (DD-X13); the first such flare can appear only from turn 1's Start-step draw
- [ ] GIVEN the redraw returns a card that was replaced, THEN it is shown as the new card with no error state (legal per DD-M05)

**Accessibility**
- [ ] With colour removed (Coblis, all three simulations, `high_contrast_states` off and on), keep vs replace is identifiable on `mulligan --pose=mulligan:010` by the word, the ✕ and the drop alone
- [ ] Every text element in §12 measures at or above its ratio in-engine
- [ ] GIVEN `reduce_motion`, THEN open / close are fades, the flip is a cross-fade, the toggle drop is instant, and the travel into the fan still plays
- [ ] The focus ring is visible on every stop in the retained keyboard-only screenshots, also at `anim_speed = instant`

**Localization**
- [ ] Zero literal English strings in `mulligan_presenter.gd` (CI `tr()` grep)
- [ ] Pseudo-locale +40 %: the sub-line stays above y 202 (2 lines max, else 14 px) and no pill clips

---

## 15. Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Player journey map not yet created — author `design/player-journey.md` from `.claude/docs/templates/player-journey.md`. | Jacob | Before Pre-Production gate | Open |
| **Opening hand size is not always 3**: match-ui U8 ("Shows the 3 starting cards"), F6 (one 3-card row) and story MUI-009 ("the 3 starting cards", "8 subsets") assume 3, but `modify_starting_hand_size` (match-rules C3 / Edge Cases; Treasures R-5 clamp 0–10) and `treasure_bottomless_satchel` (+2 → 5) are v1 content, and `STARTING_HAND_PLAYER` has safe range 3–4. This spec lays out n = 0–5 in one row (n = 4–5 widen past the F6 rect, same y) and n = 6–10 in two rows of 1.0x cards. Record the variants in F6 / U8. | Match UI GDD owner (F6, U8) + producer (MUI-009 AC) | Before story MUI-009 readiness | Open — conflict |
| **Number keys beyond 3**: U8 and the Standard Shortcuts table name `1`–`3` for the Mulligan; this spec extends to `1`–`9`, `0` for n > 3 (same keys as the hand). | ux-designer (`interaction-patterns.md` Standard Shortcuts) + Match UI GDD owner | `/ux-review mulligan` | Proposed here |
| **Replace overlay refined**: Pick One of N's toggle variant says "crossed card-back overlay"; a card back would hide the text the player is deciding on. This spec hatches only the art box and frame, adds a ✕ glyph, a 12 px drop and the pill word — the text box stays readable. Update the pattern row. | ux-designer (`interaction-patterns.md`) | `/ux-review mulligan` | Proposed here |
| **Double-click is not a shortcut here** (it would toggle twice); Pick One of N's Confirm row lists double-click as a shortcut for all its variants. Exclude the toggle variant in the pattern. | ux-designer (`interaction-patterns.md`) | `/ux-review mulligan` | Proposed here |
| **Printed vs effective cost before turn 1**: the opening hand is shown before `match_started`; does any `on_match_start` hook or hand passive change a card's effective cost that early (match-rules C3 step 4 runs hooks before the draw)? This spec shows the printed cost; if effective cost can differ, `mulligan_offered` (or `hand()` in `Mulligan`) must carry it. | Match Rules GDD owner + Match UI GDD owner | Before story MUI-009 | Open |
| Header copy, pill words, status line and the n-variant geometry (title y 124 / 60, sub-line y 164 / 100, pills, status, Confirm 560, 589 / 668) are spec-owned. | Jacob | `/ux-review mulligan` | Proposed here (spec-owned) |
| **Portraits and the passive plate stay undimmed** under the Mulligan dim (only the table fill steps to `table_dark`) so the boss passive is readable while deciding; hud.md §5 says "rows dimmed under the overlay" and the Overlay pattern says "dims the base". This spec reads both as a fill change (art bible §2 rule), not an alpha veil. | ux-designer (`hud.md` APPROVED — not edited; `interaction-patterns.md`) + art-director | `/ux-review mulligan` | Proposed here |
| New fixtures / poses: `mulligan_satchel` (Bottomless Satchel in `MatchConfig.player.hook_installers`), `mulligan_ts150`, `--pose=mulligan:<mask>` (e.g. `010`), `--pose=focus:mulligan:<n>`. n ≥ 6 and n = 0 need test-only data (v1 content tops out at 5) — decide whether a test-data fixture is allowed by U11's "fixtures use the real engine". | Match UI GDD owner / `/qa-plan` | Before story MUI-009 | Proposed |
| Story MUI-009 cites `hud.md` §5 because this file did not exist; once APPROVED it should cite `design/ux/mulligan.md`, and its "8 subsets" AC should name n = 3 (the fixture) explicitly. | producer | Sprint 5 readiness | Open |
| Gamepad: mulligan d-pad graph (§11) — left / right over the row, down to Confirm. | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Gamepad: face buttons (§11) — is a "Confirm from anywhere" button (Start) wanted, or `ui_accept` on Confirm only? | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Gamepad: bumpers (§11) — library default. | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Controller disconnection (§11) — nothing to cancel; keyboard and mouse stay live. | ux-designer | Before gamepad work (post-v1) | Open |
| AccessKit live regions — inherited NOT SOURCEABLE item. | ux-designer | Before first menu implementation | Open (inherited) |
