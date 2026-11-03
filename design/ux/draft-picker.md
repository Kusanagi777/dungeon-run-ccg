# UX Spec: Draft Picker (treasure and bundle variants)

> Authoring guidance: .claude/docs/templates/guidance/ux-spec-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Design
> **Author**: Jacob + ux-designer (`/ux-design draft-picker`, automation `guided`, workflow `standard`, density `balanced`; owner pre-approved the run — no `AskUserQuestion` used, recommended options taken and listed in the session report; no Agent tool — `art-director` / `ui-programmer` / `game-designer` not spawned)
> **Last Updated**: 2026-11-03
> **Journey Phase(s)**: Short-Term loop, "then a draft (30 seconds): a bundle that pushes the deck toward a plan, or a treasure that bends the rules" (game-concept Core Loop; `design/player-journey.md` does not exist — see §15). Reward phase `post_match_reward/treasure` then `post_match_reward/bundle` (run-structure R5).
> **Screen / Flow Name**: `DraftPicker` — one scene, two variants: `draft_treasure` and `draft_bundle` (run-ui U2 ids). Reward Draft's and Run Structure's UX flags both name this file.
> **Platform Target**: PC (Windows primary, Linux dev/CI); 1280x720 logical, `canvas_items` + `keep` (DD-T05); mouse primary, keyboard complete; gamepad `Partial` post-v1; touch none.
> **Related GDDs**: `design/gdd/run-ui.md` U2 (`draft_treasure`, `draft_bundle` rows), U3, U4, U6, U8, States S12–S15, S17, S20, F2, F4, Edge Cases "Picks and input" / "Short, skipped and skippable drafts" / "Text and layout", Visual/Audio, UI Requirements, AC-5, AC-9, AC-19, AC-21, AC-28, AC-31; `design/gdd/reward-draft.md` D1, D6–D9, D11 (`Offer{option_ids[], flags[]}`), States, Visual/Audio, UI Requirements; `design/gdd/run-structure.md` R5, R1 `DraftRecord`, UI Requirements; `design/gdd/treasures.md` UI Requirements (draft row); `design/gdd/card-database.md` UI Requirements (bundle fields); `design/gdd/content.md` UI Requirements (text ≤ 90 chars, name ≤ 32, pitch ≤ 60); `design/gdd/meta-progression.md` M9 (settings consumed).
> **Related ADRs**: none yet (`/create-architecture` has not run); the scene/node split and the drawer implementation are ADR material.
> **Related UX Specs**: `design/ux/interaction-patterns.md` (Pick One of N, Card (Hand), Card Inspect, Button (Primary/Secondary), Modal Dialog, Toast, Tooltip, List Item, Scroll Container, Progress Strip, Treasure Chip, Screen Replace, Overlay Open / Close, Focus Management, Escape / Cancel, Standard Shortcuts, Empty / Error / Success states); `design/accessibility-requirements.md`; `boss-intro.md` (exit), `pause.md` (overlay), `toast.md`, `progress-strip.md` — not yet written; `hud.md` (sibling, written in this run).
> **Accessibility Tier**: Standard with reduce-motion, visual-for-every-sound and the high-contrast state set elevated (`design/accessibility-requirements.md`). The Per-Feature Matrix's Reward Draft row leaves one item to this spec: the `text_scale` reading path for the bundle panel's compact rows (§12).
> **Template**: UX Spec

> **Sources read** (by section, coordination rule 6): run-ui U1–U10, States, Interactions, F1–F4, Edge Cases, Tuning Knobs, Visual/Audio, Game Feel, UI Requirements, AC; reward-draft Core Rules D1–D12, States, Visual/Audio, Game Feel, UI Requirements; run-structure R1, R5, R6, R10, UI Requirements, Tuning Knobs; treasures / card-database / content UI Requirements; meta M9; art bible §2 (Reward draft mood), §4, §7; accessibility-requirements Visual, Motor, Cognitive, Per-Feature Matrix; interaction-patterns (entries named above), Animation and Sound Standards, Gaps ("Deck drawer", "Compact card row" are assigned to this spec).

> **Note — Scope boundary**: A discrete base screen of the run shell (run-ui U1). It overlays nothing; the Progress Strip and the Pause overlay sit on it. Numbers marked **F4** are run-ui's formula outputs; numbers marked *spec* are this document's decisions inside the space F4 leaves (`content_top` 96, Pick anchored to the bottom).

---

## 1. Purpose & Player Need

**What player need does this screen serve?**

The player has just won a floor and wants the reward to *mean something*: to read three offers quickly, see which one deepens the plan their deck has been forming, and commit without fear of a mis-click or a hidden catch. Pillar 1 says the draft **is** the game, so the screen's job is to make the comparison legible in about thirty seconds (Core Loop) — every card's text readable, the deck's current shape visible on request, the synergy hint present but never a weight or a recommendation — and then to lock the choice decisively (select, then confirm; the save happens right after, DD-R08). If it fails, players pick "the strongest-looking bundle" by stamp numbers alone, which is the design risk the concept names first.

**The player goal** (what the player wants to accomplish):

Compare the 1–3 offers (every card's full text reachable by hover *or* focus), optionally check the current deck, and commit one pick with `1`/`2`/`3` + `Enter` or two clicks, within the 30-second budget the Core Loop assumes.

**The game goal** (what the game needs to communicate or capture):

Render Reward Draft's `Offer{option_ids[], flags[]}` in `option_ids` order (which carries no information about forced slots, reward-draft D6.4), capture exactly one `pick(index)` (or `skip_pick` under `allow_skip`) per `(floor, kind)`, and show the deck growing so the fly-to-strip confirms what was taken.

---

## 2. Player Context on Arrival

| Question | Answer |
|----------|--------|
| What was the player just doing? | Watching the match-end banner (victory) for up to `MATCH_END_AUTO_S` 4 s after a 3–6 minute match; Run UI took control back on `match_view_finished` and the buffered `draft_offered{treasure}` (floors 1, 3, 5) or `draft_offered{bundle}` (every floor 1–7) decided this screen (run-ui S11–S13). On a treasure floor the bundle variant follows the treasure pick directly (S14). |
| What is their emotional state? | Relief and curiosity — art bible §2 "curiosity and greed, pleasantly"; the match's tension is spent. On resume (R8.2) they arrive cold from the main menu into the same offer. |
| What cognitive load are they carrying? | Moderate: the shape of their deck and the boss just beaten; a bundle screen asks them to read up to 9 cards — accessibility-requirements calls it "the densest read in the game". |
| What information do they already have? | Their deck (by memory — the drawer confirms it), held treasures (strip icons), the floor (strip), and that the next boss is unknown beyond its band (upcoming nodes show band only). |
| What are they most likely trying to do? | Find the offer that fits the plan they committed to around floor 3–4 (concept Key Dynamics) and take it; early floors: take the strongest general option. |
| What are they likely afraid of? | Picking by accident (a single stray click), not being able to read a card's rules text, missing that a slot is empty for a reason, and losing the pick to a crash (DD-R08 saves right after). |

**Emotional design target for this screen**:

Tempted and unhurried — three lit objects on a cleared table, a 30-second clock in the player's head and none on screen (art bible §2), with the confirm step making the choice feel deliberate rather than risky.

---

## 3. Navigation Position

**Screen hierarchy**:

```
Main Menu
  └── Hero Select → Run Start → Boss Intro → Match
        └── Draft Picker — treasure variant (floors in treasure_floors: 1, 3, 5)
              └── Draft Picker — bundle variant (floors 1 … floors_per_run − 1)
                    └── Boss Intro (next floor)
                    ├── Pause overlay (Resume · Settings · Abandon run → Confirm · Quit to menu → suspend)
                    ├── Deck drawer (non-blocking)
                    └── Toast layer (non-modal)
```

**Modal behavior**: Base screen (run-ui U1); not dismissable — there is no "back" from a draft (the run is in `post_match_reward`). `Esc` opens the Pause overlay (Escape / Cancel chain step 4 → step 5 does not apply: a draft is a run base screen whose `back` is the pause menu, run-ui Edge Cases "If the player presses `Esc` on a draft"). Leaving without picking is only Abandon (counts as a loss, confirmed) or Quit to menu (`suspend()`, the S2/S3 save holds the phase and resume re-offers the same options). The player cannot be stuck: Pick is always reachable for every real option.

**Reachability — all entry points**:

| Entry Point | Triggered By | Notes |
|-------------|-------------|-------|
| Match → `draft_treasure` | `draft_offered{kind: treasure, floor ∈ treasure_floors}` buffered during the match, applied at `match_view_finished` (S11 → S12) | Floors 1, 3, 5 by default (DD-R05; `treasure_floors`) |
| Match → `draft_bundle` | `draft_offered{kind: bundle}` (S11 → S13) | Floors 1–7; on a non-treasure floor this is the first reward screen |
| `draft_treasure` → `draft_bundle` | `treasure_granted` then the second `draft_offered{bundle}` (S14 → S13) | Same scene, variant swap with the fly-to-strip in between |
| Main Menu → Continue → `draft_*` | `resume()` returns `OK` with `status = post_match_reward/<kind>` (S5; run-ui AC-12) | Same `option_ids` re-generated (reward-draft D12, run-structure R8.2); no `hero_select` or `run_start` in between |
| Never | `option_ids == []` | An empty offer never reaches the shell — Run Structure skips the step (reward-draft D8c); this screen has **no empty state** by contract and says so (§6) |

---

## 4. Entry & Exit Points

**Entry table**:

| Trigger | Source Screen / State | Transition Type | Data Passed In | Notes |
|---------|----------------------|-----------------|----------------|-------|
| `draft_offered{floor, kind: treasure, option_ids[1–3], flags[]}` | `match` (after `match_view_finished`) | Screen Replace, `fade` 250 ms then `draft_reveal` 3 × 120 ms stagger (F2) | Read model: `floor`, `floors_per_run`, `kind`, `option_ids`, `flags`, per-option `affine` (Offer read model), `TreasureDef` per id, `deck[]`, `treasures[]`, `boss_sequence[0..floor−1]`, `allow_skip` | Treasure first on a treasure floor (R5.2) |
| `draft_offered{…, kind: bundle}` | `match` or `draft_treasure` | Same; from `draft_treasure` the fly-to-strip (400 ms) plays first | As above with `BundleDef` (`theme`, `text`, 3 `CardDef`s) and per-option `n_tag(theme)`; "Deck a → b" numbers from `len(deck)` and `bundle_card_count` 3 | `option_ids` already id-sorted = display order (U8) |
| `resume()` → `OK` | `main_menu` / `resume_prompt` | Screen Replace `fade`; **no reveal stagger** (the offer is re-shown, not new) | Same read model, same ids | run-ui AC-12 |
| Launch argument | `--run-ui-screen=draft_treasure --run-ui-fixture=draft_treasure_sample` (also `draft_bundle_sample`) | None (U10: no transition) | Fixture profile + `RunRecord` + offer | Screenshot path (run-and-observe) |

**Exit table**:

| Exit Action | Destination | Transition Type | Data Returned / Saved | Notes |
|-------------|------------|-----------------|----------------------|-------|
| Pick (second `Enter` / Pick button / double-click) on treasure option *i* | `draft_bundle` (S14 → S13) | `committed` ≤ 50 ms → on `treasure_granted` fly-to-strip 400 ms → `fade` | `draft_pick(treasure, option_ids[i])`; Run Structure appends `treasures[]`, records the `DraftRecord`, saves S3 | Irreversible: no undo (reward-draft Game Feel) |
| Pick on bundle option *i* | `boss_intro` (S15) | `committed` → on `deck_grew` fly-to-strip 400 ms → on `run_floor_entered` `fade` | `draft_pick(bundle, option_ids[i])`; deck += 3 cards; save | Irreversible |
| Take nothing (only when `allow_skip`, default false) | Next step / `boss_intro` | `committed` → `fade` (no fly-to-strip, no `deck_grew`) | `draft_pick(kind, null)`; `DraftRecord{picked_id: null}` | Secondary button, `Tab`-reachable, never a number key |
| Abandon run (Pause → Abandon → Confirm) | `summary_abandoned` (S17) | Overlay close → `fade` | `abandon()`; `run_ended{abandoned}`; **counts as a loss** (R6); `floors_cleared = floor` from `post_match_reward` | Confirmation Dialog states the consequence |
| Quit to menu (Pause → Quit to menu) | `main_menu` (S23) | `fade` | `suspend()` — no event, no save; the last S-save (S2/S3) is the resumable state; Continue re-offers the same options | Secondary (nothing is lost) |
| Window closed | — | — | Nothing to do (run-ui Edge Cases "window is closed during a draft") | Resume regenerates the offer |
| Rejection (`E_NOT_OFFERED`, `E_DRAFT_DONE`, `E_DRAFT_KIND`, `E_UNKNOWN_ID`) | Same screen, un-committed | Toast | No state change; `E_UNKNOWN_ID` is followed by a fresh `draft_offered` that rebuilds the screen | Should never fire from a correct UI (reward-draft UI Requirements "debugging honesty") |

---

## 5. Layout Specification

### 5.1 ASCII Wireframe

Treasure variant (`draft_treasure`), floor 3 of 8, three offers — F4 slots at x 367 / 565 / 763, y 240:

```
 x:0     40        200   367      517 565      715 763      913        1080     1240 1280
 y:0 ┌────────────────────────────────────────────────────────────────────────────────────┐
     │ Floor 3                  TREASURE → Bundle                                  [≡]    │  title row 0–48
  48 │ [T][T]   ○──○──◉──○──○──○──○──○   (strip x0 404, nodes 416 + 64·(f−1))  27 cards  │  strip row 48–96
  96 │                                                                                    │
     │                                                                                    │  header 96–240
 240 │            ┌─────────┐      ┌─────────┐      ┌─────────┐                           │
     │            │ (cost)  │      │  ● ring │      │         │                           │  3 × 150x210
     │            │ NAME    │      │ NAME    │      │ NAME    │                           │  gap 48 (F4)
     │            │ [Rare]  │      │ [Common]│      │ [Rare]  │                           │
     │            │ text…   │      │ text…   │      │ text…   │                           │
 450 │            └─────────┘      └─────────┘      └─────────┘                           │
 470 │                             fits your plan                                         │  hint line (spec)
     │                                                                                    │
 640 │ [Take nothing]*            ( Pick )                              [Deck (27)]       │  buttons y 640–684
 720 └────────────────────────────────────────────────────────────────────────────────────┘
       * only when allow_skip                 ●  = focused option (2 px ring, 3 px offset)
```

Bundle variant (`draft_bundle`), F4 panels 340 wide at x 90 / 470 / 850, gap 40:

```
 x:0     40    90                430 470               810 850              1190   1280
 y:0 ┌───────────────────────────────────────────────────────────────────────────────────┐
     │ Floor 3                  Treasure → BUNDLE                                  [≡]   │  0–48
  48 │ [T][T]   ○──○──◉──○──○──○──○──○                                        27 cards   │  48–96
 136 │         ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐               │
     │         │ THEME LABEL     │ │ THEME LABEL     │ │ THEME LABEL     │               │  label 32 (F4)
     │         │ pitch ≤ 60 ch   │ │ pitch           │ │ pitch           │               │  pitch 36 (spec)
     │         │ ┌─ card row ──┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │               │  3 × 300x64
     │         │ ├─ card row ──┤ │ │ ├─────────────┤ │ │ ├─────────────┤ │               │  gaps 8 (F4)
     │         │ └─ card row ──┘ │ │ └─────────────┘ │ │ └─────────────┘ │               │
 456 │         └─────────────────┘ └─────────────────┘ └─────────────────┘               │  panel 340x320
 470 │                      4 cards in your deck share *weapons*                         │  hint (spec)
 494 │                               Deck 27 → 30                                         │  hint 2 (spec)
 640 │ [Take nothing]*            ( Pick )                              [Deck (27)]      │  640–684
 720 └───────────────────────────────────────────────────────────────────────────────────┘
     Hover/focus on a card row → 225x315 Card Inspect preview anchored to the panel's outer edge
```

Deck drawer open (either variant): right drawer 320 px (*spec*) at 960, 96, 320, 624 over the content; the title and strip rows stay visible; Pick (560–720) stays clear of it; the covered option (bundle panel 3 / nothing in the treasure variant) is still focusable — focusing it closes the drawer.

### 5.2 Layout Zones

| Zone Name | Description | Approximate Size | Scrollable? | Overflow Behavior |
|-----------|-------------|-----------------|-------------|-------------------|
| Title row | "Floor n" (`text_muted` 16 px, x 40); step indicator centred (28 px bold screen title — `Treasure → Bundle` with the current step in `text_light`, the other in `text_muted`; bundle-only floors show `Bundle`); menu button 44x44 at (1212, 2) | 1280 x 48 (0–48) | No | Step indicator never wraps (≤ 20 chars in English; §13) |
| Progress strip row | Progress Strip pattern: held-treasure chips x 40–200, F nodes (F4: `strip_w` 472, `x0` 404, node centres 416 + 64·(f−1) for F = 8; 544 + 64·(f−1) for F = 4), deck size x 1080–1240 | 1280 x 48 (48–96) | No | F > 10 shrinks `seg_len` (F4); initials dropped below 16 px |
| Header (treasure) | Empty breathing space per F4's "96–240 for header" — holds the *reoffer/short* reason line when present (centred, 16 px `text_muted`, y 200) | 1280 x 144 (96–240) | No | — |
| Option row (treasure) | 3 slots 150x210 at x 367, 565, 763, y 240 (F4) — Card (Hand) static variant with the spell slot layout (text box y 122–200), rarity pill ("Common"/"Rare" word, 12 px on `ink`) overlapping the name band's right end | 723 x 210 (240–450) | No | Text > 4 lines ellipsises; full text in Card Inspect (run-ui Edge Cases) |
| Option row (bundle) | 3 panels 340x320 at x 90, 470, 850, y 136–456 (*spec* y inside F4's x): `parchment`-framed `table_dark` panel; theme label 32 px band (16 px bold `text_light` on `ink`); pitch 2 lines 14 px `text_light` (36 px); three compact card rows 300x64 with 8 px gaps (x 110, y 212 / 284 / 356): cost stamp 34 px, name 14 px bold, type initial, attack/health stamps 26 px, first text line 12 px `text_ink` on `parchment`, ellipsised | 1100 x 320 | No (rows fixed at 3) | At `text_scale` ≥ 125 % the first-line text is dropped from the row (name + stamps stay) and the reading panel carries it (§12) |
| Hint zone | Line 1 under the focused/hovered option (treasure: "fits your plan" iff `affine` = 1; bundle: "N cards in your deck share *theme*"); line 2 (bundle only) "Deck a → b"; 16 px `text_light`, centred under the option; hidden (not blank) when the read model lacks the number | 1280 x 72 (450/456–528) | No | ≤ 48 chars English; wraps to 2 lines at 150 % |
| Action row | Take nothing (Secondary, 160x44 at 40, 640 — only under `allow_skip`); **Pick** (Primary, 160x44 at 560, 640); Deck drawer toggle (Secondary, 160x44 at 1080, 640, label "Deck (n)") | 1280 x 80 (640–720) | No | Labels grow the button, never clip (Button pattern) |
| Deck drawer (overlay, non-blocking) | 960, 96, 320, 624 (*spec*): header "Deck · n cards" + "Treasures" chip row (held, pick order); List Item rows 44 px (cost stamp, name, type initial, a "drafted f3" tag for non-starter cards) in acquisition order; Scroll Container | 320 x 624 | Yes — vertical | Bar always shown when > 13 rows; focus follows scroll |
| Toast layer | Top-right (Toast pattern): 400 x ≥ 48 at (856, 56) — below the title row, clear of the menu button | — | No | One at a time (run-ui U5) |

### 5.3 Component Inventory

| Component Name | Type | Zone | Purpose | Required? | Reuses Existing Component? |
|----------------|------|------|---------|-----------|---------------------------|
| Floor label | Text | Title row | "Floor n" orientation | Yes | Yes — plain `Label` |
| Step indicator | Text | Title row | "Treasure → Bundle" / "Bundle", current step lit | Yes | Yes — plain `Label`, two spans |
| Menu button | Button | Title row | Opens Pause overlay | Yes | Yes — Button (Secondary); `Esc` duplicates |
| Progress strip | Compound | Strip row | Floor progress, held treasures, deck size | Yes | Yes — Progress Strip (`progress-strip.md`) |
| Treasure chips (strip) | Chip | Strip row | Held treasures, tooltip | Yes when ≥ 1 held | Yes — Treasure Chip |
| Treasure option frame ×1–3 | Card (static) | Option row | One offer: name, rarity pill, text | Yes | Yes — Card (Hand) static variant + Pick One of N slot |
| Bundle panel ×1–3 | Compound | Option row | Theme label, pitch, 3 compact rows | Yes | **No — new** `BundlePanel` (Gaps row "Compact card row"; composed of List Item rows + Card Inspect) |
| Compact card row ×3 per panel | List Item (read-only, focusable) | Bundle panel | One card of the bundle; Card Inspect on hover/focus | Yes | **No — new** `CompactCardRow` 300x64 (Gaps) |
| Short-offer placeholder ×0–2 | Panel | Option row | Dimmed frame with the one-line reason | Yes | Yes — Empty State "Draft with `short` offers" |
| Missing-id error frame | Panel | Option row | "missing: <id>", not pickable | Yes | Yes — Error State |
| Synergy hint | Text | Hint zone | "fits your plan" / "N cards share *theme*" | Yes | Yes — Pick One of N hint line |
| Deck growth hint | Text | Hint zone | "Deck a → b" (bundle) | Yes | Yes — Pick One of N hint line |
| Pick | Button | Action row | Confirms the selected option | Yes | Yes — Button (Primary) |
| Take nothing | Button | Action row | `skip_pick` under `allow_skip` | Conditional | Yes — Button (Secondary) |
| Deck drawer toggle | Button | Action row | Opens / closes the drawer | Yes | Yes — Button (Secondary) |
| Deck drawer | Drawer | Overlay | Current deck + held treasures | Yes | **New** `DeckDrawer` (Gaps row) built from Scroll Container + List Item + Treasure Chip; non-blocking Overlay Open / Close row "Deck drawer (draft)" |
| Card Inspect preview (+ reading panel) | Overlay | Over the content | 225x315 card on hover / focus | Yes | Yes — Card Inspect |
| Reason line (short/reoffer) | Text | Header | "No more treasures in this run" / "…bundles…" | Conditional | Yes — Empty State |
| Pause overlay | Modal | Over everything | Resume / Settings / Abandon / Quit to menu | Yes | Yes — Modal Dialog (`pause.md`) |
| Confirm dialog | Modal | Over everything | Abandon consequence | Yes | Yes — Confirmation Dialog |
| Toast | Banner | Toast layer | Rejection / warning / unlock | Yes | Yes — Toast / Notification |
| ReadOnly banner | Strip | Above the title row | "another copy is open" while Meta is `ReadOnly` | Conditional | Yes — shared component (`main-menu.md`) |

**Primary focus element on open**: **Nothing** — a draft forces a choice (run-ui U3, Focus Management "drafts → nothing; Tab enters at option 1"). `1`/`2`/`3` focus option *n* directly. Deep-link (resume) and short-offer cases are identical: no focus until the player acts; `Tab` enters at the first **real** option (placeholders are not focusable).

### 5.4 Information Hierarchy

1. **The offers themselves** — three lit objects on a cleared `table_lit` pool (art bible §2); everything else is `bg_edge` or `table_dark`. For a treasure that is name + text; for a bundle the theme label first, then the three cards.
2. **Which step this is and what it costs** — the step indicator and "Deck a → b": the player should never wonder whether a bundle follows.
3. **The synergy hint** — shown only for the focused / hovered option, so it informs a comparison the player is already making rather than ranking the row (reward-draft UI Requirements: the number, never the weight; Open Questions there still asks whether to show it at all — this spec shows it, §15).
4. **The run context** — strip, held treasures, deck size: glanceable, non-interactive.
5. **The deck** — behind the drawer; needed for a deliberate comparison, not every pick.
6. **Pick** — dim until a selection exists; it is the consequence of the comparison, not a call to action.

---

## 6. States & Variants

| State Name | Trigger | What Changes Visually | What Changes Behaviorally | Notes |
|------------|---------|----------------------|--------------------------|-------|
| Loading / revealing | `draft_offered` applied; `transitioning == true` | `fade` 250 ms in, then options appear left → right, 120 ms apart (one fade under `reduce_motion`; 0 ms at `instant`) | Every intent except `skip` is dropped (U4); any input skips to the end state | ≤ 100 ms to first frame from the read model (run-ui AC-26) |
| Populated — treasure | `kind = treasure`, `len(option_ids) = 3` | Three frames at F4 slots; Pick Idle (`text_muted`, no outline) | `1/2/3`, `Tab`, click select; nothing focused | Fixture `draft_treasure_sample` |
| Populated — bundle | `kind = bundle`, 3 options | Three panels; "Deck a → b" hidden until an option is focused/hovered | As above | Fixture `draft_bundle_sample` |
| Option hovered | Mouse over a frame / panel / row | Lift 8 px, **no ring**; Card Inspect for the card / row; hint line appears | Hover never moves focus or selects (U3) | |
| Option focused | `1/2/3`, `Tab`, or click | 2 px `state_actionable` ring offset 3 px; Card Inspect (immediate); hint line | First `Enter` or click = **select** | Fixture pose: `--run-ui-fixture=draft_bundle_sample` + keyboard `2` (AC-19) |
| Option selected | `Enter` / click on a focused option | Outline persists when focus leaves; siblings stay at full brightness | Pick becomes Actionable (outline, `text_light`) | Pick One of N "Selected" |
| Committed | Pick / second `Enter` / double-click | Selected option locks (stays lifted), siblings dim 60 %, Pick stays pressed; `ui_pick` | Every further intent ignored until the swap (U4 `committed`); exactly one `draft_pick` (AC-9) | ≤ 50 ms to the lock (Game Feel) |
| Fly-to-strip | `treasure_granted` / `deck_grew` | Picked frame / the three card rows shrink along a straight path to the strip (treasure → chip slot at left; cards → the deck-size label at right); deck size ticks "27 → 30" in `text_light` | 400 ms, skippable; fade under `reduce_motion` | `deck_thump` audio |
| Short offer (`short` / `reoffer` flag) | `len(option_ids)` 1–2 | Missing slots drawn as dimmed `table_dark` placeholders at their F4 positions (no reflow) with the one-line reason inside ("No more treasures in this run" / "No more bundles in this run"); the header shows nothing extra | Placeholders not focusable; `1/2/3` past the last real option ignored; `pick(i ≥ len)` never sent | run-ui AC-28; fixture **`draft_treasure_short`** (new — §15) |
| Reoffer (debug only, treasure) | `treasure_short_policy = reoffer` | Same as short placeholders but the re-filled slots render normally | `E_CONFIG` in release (DD-X06) | Fixture only |
| Empty offer | `option_ids == []` | **Never shown** — the run skips the step (D8c) | — | Stated so a reviewer does not look for a missing state |
| Missing id | An `option_ids` entry fails to resolve in Card Database | That slot is an error frame "missing: <id>" (`text_muted` on `table_dark`), the others normal; `ui_data_missing` warning toast | Not pickable; not focusable | run-ui AC-21 |
| Take-nothing available | `allow_skip = true` | Fourth control at bottom-left | `Tab`-reachable, `skip_pick`; no fly-to-strip | Default off (reward-draft D9) |
| Deck drawer open | Deck button / `Enter` on it | Right drawer 320 px slides in (fade under `reduce_motion`); covers bundle panel 3 | Non-blocking: options, Pick stay live; `Esc` / RMB / the toggle closes it first (Escape chain step 2); focus enters the drawer only when opened by key | Gaps row resolved here |
| Pause open | `Esc` (chain step 4) / menu button | Modal over a `table_dark`-dimmed base; Resume focused | Base input disabled; a toast arriving queues | `pause.md` |
| Abandon confirm | Pause → Abandon run | Confirmation Dialog: "Abandon this run?" / "Abandon counts as a loss." / [Cancel ●] [Abandon run] | Cancel focused | Destructive pattern |
| Rejected pick | `E_NOT_OFFERED` / `E_DRAFT_DONE` / `E_DRAFT_KIND` / `E_UNKNOWN_ID` | Toast "That option is no longer offered."; the committed option un-locks, siblings brighten | Screen un-committed; `E_UNKNOWN_ID` → fresh `draft_offered` rebuilds | Error State row |
| Resume into a draft | `resume()` OK | Same offer, no reveal stagger; strip and deck from the record | Identical behaviour | run-ui AC-12 |
| Toast showing | Unlock / warning queued while idle | Banner top-right for `t_toast` 5–8 s; hover/focus pauses | Never steals focus | Unlocks are rare here (granted at `archive_run`) — mostly `save_failed` |
| ReadOnly profile | Meta `ReadOnly` | Banner strip above the title row | Picks still work; the run is not saved (Meta M6) | run-ui Edge Cases |
| `text_scale` 125 % / 150 % | Setting | §12 narrative: title and hints grow; compact rows drop their text line; reading panel on Card Inspect | — | Fixture variant `draft_bundle_sample` with `settings.text_scale` 1.5 (AC-31) |
| `reduce_motion` / `instant` | Setting | Stagger → one fade / 0 ms; fly-to-strip → fade; drawer slide → fade | `committed` still blocks a second intent (state-based) | run-ui AC-20 |

---

## 7. Interaction Map

Mapping interactions for: **keyboard + mouse** (resolved in Phase 2h from technical-preferences via accessibility-requirements; `project.yaml` has no `platform` block). Covering **Partial** gamepad support as a post-v1 mapping onto the same focus graph (Focus Management "Gamepad"); touch not supported.

### 7.1 Navigation Inputs

| Input | Platform | Action | Visual Response | Audio Cue | Notes |
|-------|----------|--------|-----------------|-----------|-------|
| `1` / `2` / `3` | KB | Focus option *n* (not select) | Ring moves; Card Inspect; hint line | `ui_hover` | Ignored past the last real option (short offer); never "Take nothing" |
| `Tab` / `Shift+Tab` | KB | Cycle the §12 focus order; enters at option 1 from the no-focus start | Ring moves | `ui_hover` | Inside a bundle panel: `Down` / `Up` step through its three card rows (List Item); `Tab` leaves the panel |
| `Down` / `Up` | KB | Within a focused bundle panel: row 1 → 2 → 3 (Card Inspect per row); within the open drawer: list rows; `Home` / `End` first / last | Row ring; preview | `ui_hover` | Rows are read-only; `Enter` on a row selects its panel |
| Mouse hover | PC | Highlight (lift 8 px) + Card Inspect + hint — **without** moving focus or selecting | Lift, no ring | `ui_hover` | Hover and focus may differ; both shown when both |
| Mouse click | PC | Focus **and** select the clicked option (first click); on a bundle card row: selects the panel | Ring + persistent outline; Pick lights | `ui_select` | A single click never commits (Pick One of N) |
| Mouse wheel | PC | Scroll the deck drawer when open (3 rows per notch); no-op elsewhere | — | — | Scroll Container |
| Right mouse button | PC | Close the drawer if open; otherwise no-op (never opens pause, never navigates) | — | `ui_select` cancel variant | Escape / Cancel RMB rule |
| `Esc` | KB | Chain: (2) close the drawer → (3) cancel the open confirm / close pause → (4) open the pause menu | — | — | Never abandons; never picks |
| Gamepad d-pad / A / B / shoulders | post-v1 | `focus_neighbor_*` over the same graph / Enter / Esc / Tab | Same | Same | No v1 decision blocks this |

### 7.2 Action Inputs

| Input | Platform | Context (What must be focused) | Action | Response | Animation | Audio Cue | Notes |
|-------|----------|-------------------------------|--------|----------|-----------|-----------|-------|
| `Enter` / `Space` (first) | KB | An option (frame / panel / row) focused, not yet selected | Select it | Outline persists; Pick → Actionable | 80 ms ease-out | `ui_select` | |
| `Enter` / `Space` (second) | KB | The selected option still focused | **Pick** (confirm) | `committed`: lock, siblings dim 60 % | ≤ 50 ms | `ui_pick` | Equivalent to pressing Pick |
| `Enter` / `Space` | KB | Pick focused (Actionable) | Pick | As above | | `ui_pick` | Idle Pick: no response (reason tooltip on focus: "Choose an option first") |
| LMB | PC | — (pointer over Pick, Actionable) | Pick | As above | | `ui_pick` | |
| LMB ×2 (double-click) | PC | Pointer over an option | Select + Pick in one gesture | As above | | `ui_select` + `ui_pick` | Shortcut, not the only path; the second click within the OS double-click time |
| `Enter` / LMB | KB / PC | Take nothing focused / hovered (`allow_skip` only) | `skip_pick` | `committed`; no fly-to-strip | | `ui_select` | |
| `Enter` / LMB | KB / PC | Deck drawer toggle | Open / close the drawer | Slide 250 ms (fade under `reduce_motion`) | | `ui_select` | Keyboard open moves focus into the drawer's first row; close returns it to the toggle |
| `Enter` / LMB | KB / PC | Menu button, or `Esc` with nothing open | Open Pause | Modal open `fade` 250 ms | | `sfx.ui.overlay` | Resume focused |
| `Enter` / LMB | KB / PC | Toast focused / hovered | Dismiss early | Fade 200 ms | | — | Unlock already acked on show |
| Any input | all | During `transitioning` | `skip` the transition to its end state | Instant | 0 | — | The only intent accepted while transitioning (U4) |

### 7.3 State-Specific Behaviors

| State | Input Restriction | Reason |
|-------|------------------|--------|
| Loading / revealing (`transitioning`) | Everything except `skip` dropped (`ui_intent_rejected{transitioning}`) | No half-built screen can take a pick; the option stays focused so the next press lands (Edge Cases) |
| Committed | All intents ignored until the swap | One pick per `(floor, kind)` (AC-9; reward-draft `E_DRAFT_DONE` is the engine-side guard) |
| Short offer | `1/2/3` beyond `len(option_ids)` ignored; placeholders unfocusable | `pick(i)` requires `0 ≤ i < len(option_ids)` (U8) |
| Pause / Confirm open | Base input disabled recursively; focus trapped | Modal Dialog |
| Drawer open | None on the base — non-blocking | Overlay Open / Close row "Deck drawer" |
| Rejected pick | Screen un-commits; all inputs restored | Nothing happened |

---

## 8. Data Requirements

| Data Element | Source System | Update Frequency | Who Owns It | Format | Null / Missing Handling |
|--------------|--------------|-----------------|-------------|--------|------------------------|
| `floor`, `floors_per_run`, `kind`, `option_ids[]`, `flags[]` | Reward Draft via Run Structure (`draft_offered`) | Once per screen | Reward Draft (`Offer`) / Run Structure (`RunState`) | `{floor: int, kind: "treasure"|"bundle", option_ids: string[1–3], flags: string[] ⊆ {pity_forced, coverage_forced, universal_forced, universal_missing, reoffer, short}}` | `[]` never arrives (D8c); `flags` never displayed except `short`/`reoffer` placeholders |
| `TreasureDef` per id: `name`, `rarity`, `text`, `tags` | Card Database | On build | Card Database | Record (CR-3) | Unresolved id → error frame, `ui_data_missing` toast (AC-21) |
| `BundleDef` per id: `theme`, `text` (pitch ≤ 60 chars), 3 `CardDef` ids | Card Database | On build | Card Database | Record | As above |
| `CardDef` per bundle card: `name` (≤ 32), `text` (≤ 90), `cost`, `attack`, `health`, `durability`, `type`, `keywords`, `rarity` | Card Database | On build | Card Database | Record | As above |
| Per-option `affine` (treasure) / `n_tag(theme)` (bundle) | Reward Draft `Offer` read model | On build | Reward Draft | `{affine: 0|1}` / `{n_tag: int}` | Absent → hint **hidden**, not blank (U8); the weight is never exposed |
| `deck[]` (acquisition order), `len(deck)` | Run Structure `RunState` | On build; `deck_grew` | Run Structure | `string[]` | Never null in `post_match_reward` |
| `treasures[]` (pick order) | Run Structure | On build; `treasure_granted` | Run Structure | `string[]` | Empty → no chips (deliberate absence) |
| `boss_sequence[0..floor−1]`, `floor_band` per floor, `treasure_floors` | Run Structure | `run_floor_entered` | Run Structure | masked `string[]`, int[] | Upcoming nodes: band only (never identity) |
| `bundle_card_count` (3) | Registry / Card Database | Static | Card Database | int | "Deck a → b" uses it |
| `allow_skip` | Reward Draft data (`reward_draft.json`) | Static | Reward Draft | bool (default false) | Absent → false |
| Settings: `anim_speed`, `reduce_motion`, `text_scale`, `high_contrast_states`, volumes | Meta Progression | `settings_changed` | Meta (M9) | DD-X07 record | Absent (MVP) → defaults |
| `pending_notifications()` / `unlock_granted` | Meta Progression | Shell idle | Meta | `{key, kind, id, by_run_id, retro}` | Empty queue → nothing |
| Profile `ReadOnly` status | Meta Progression | On state change | Meta | enum | OK → no banner |

> **Rule**: This screen must never write directly to any system listed above. All
> player actions fire events (see Section 9). Systems update their own data and
> notify the UI.

---

## 9. Events Fired

Intents (run-ui U2) → commands issued by `RunController`; no screen script calls Run Structure or Reward Draft.

| Player Action | Event Fired | Payload | Receiver System | Notes |
|---------------|-------------|---------|-----------------|-------|
| Hover an option / row | `hover(index[, card])` (local intent) | `{index, card_id?}` | Run UI (local) | No command, no event; drives the hint and Card Inspect |
| Focus / select an option | none | — | — | Local view-state (`selected_index`); deliberate — selection is not persisted (resume starts unselected) |
| Pick option *i* | `pick(index)` → `draft_pick(kind, option_ids[index])` | `{kind, id}` | Run Structure T11/T12 → Reward Draft `pick` → `draft_picked{floor, kind, picked_id, option_index, card_ids_added[]}` then `treasure_granted` / `deck_grew{floor, card_ids_added[], deck_size}` and the S3 save | **Persistent state change** (deck / treasures / `DraftRecord`; DD-R08 save) — architecture attention: the UI shows the result only from the event |
| Take nothing | `skip_pick` → `draft_pick(kind, null)` | `{kind}` | Run Structure | Only when `allow_skip`; `DraftRecord{picked_id: null}` |
| Open / close drawer | `open_deck_drawer` (local) | — | Run UI | No event |
| Menu / `Esc` | `open_pause` | — | Run UI (pushes `pause`) | S20 |
| Abandon (confirmed) | `abandon` → `abandon()` | — | Run Structure T13 → `run_ended{abandoned}` → Meta `archive_run` | **Persistent, counts as a loss** |
| Quit to menu (pause) | `go_main_menu` → `suspend()` | — | Run Structure T21 | No event, no save (S23) |
| Dismiss toast | `dismiss` (local) | — | Run UI | `ack_notification(key)` was already sent on show |
| Pick rejected | (incoming) `ui_intent_rejected{name, reason}` debug event; Reward Draft / Run Structure rejection code | `{code}` | Run UI | Toast + un-commit; analytics-grade only |
| Any intent while transitioning | `ui_intent_rejected{reason: transitioning}` | — | Debug log | Silent to the player |

No analytics system exists in v1; the run log (`draft_offered` / `draft_picked`, Pillar 4) is the record `/balance-check` reads.

---

## 10. Transitions & Animations

| Transition | Trigger | Direction / Type | Duration (ms) | Easing | Interruptible? | Skipped by Reduced Motion? |
|------------|---------|-----------------|--------------|--------|----------------|---------------------------|
| Screen enter | `draft_offered` applied | Cross-fade (`fade`, F2) | 250 × `speed_factor` | ease-out | Yes — any input skips to the end state (U4) | Not skipped (it is a fade already); 0 at `instant` |
| Draft reveal | After the fade | Options appear left → right, 120 ms stagger (`draft_reveal` 360) + `ui_draft_reveal` ×3 | 360 (180 at `fast`) | ease-out | Yes | Yes → one fade |
| Hover lift | Mouse over an option | Lift 8 px | 80 | ease-out | Yes | Lift kept, bounce none (there is none) |
| Card Inspect in / out | Hover (0.1 s tween) / focus (immediate) | 1.5x preview beside the option | 100 / 100 | ease-out | Yes | Appears without tween |
| Select | First `Enter` / click | Outline appears | instant | — | — | — |
| Commit | Pick | Siblings dim to 60 %; Pick pressed | 60 | linear | No (state) | — |
| Fly-to-strip | `treasure_granted` / `deck_grew` | Straight path to the strip; deck count ticks | 400 × `speed_factor` | ease-out | Yes — skip jumps to the end state | Yes → fade at half duration (positional information kept by the count tick) |
| Variant swap (treasure → bundle) / screen exit to boss intro | Second `draft_offered` / `run_floor_entered` | `fade` 250 (then `intro_slide` 300 on the boss intro, its own spec) | 250 | ease-out | Yes | — |
| Drawer open / close | Toggle | Slide in from the right 250 / out 250 | 250 | ease-out | Yes | Yes → fade at half duration |
| Pause open / close | `Esc` / menu | Base dims to `table_dark`; panel scale 0.95 → 1 | 250 / 150 | ease-out | — | Scale removed; fade only |
| Toast in / out | Queue drain | Fade (+ slide without `reduce_motion`) | 200 | ease-out | — | Fade only |
| Rejection un-commit | Rejection code | Siblings brighten | 60 | linear | — | — |

Impact moments on this screen: exactly one — the draft reveal (run-ui Game Feel "exactly two" counts it and the victory saturation). Easing is ease-out only, no bounce (Animation Standards).

---

## 11. Input Method Completeness Checklist

Platform Target is keyboard + mouse; the **Touch** block is dropped (not supported) and the **Gamepad** block is kept unticked as the post-v1 mapping (Partial). A tick means §7 above specifies it; an untick is an open implementation question listed in §15.

**Keyboard**
- [x] All interactive elements are reachable using Tab and arrow keys alone (§12 focus order; `Down`/`Up` inside panels and the drawer)
- [x] Tab order follows visual reading order (options left → right, then the action row, then the strip)
- [x] Every action achievable by mouse is also achievable by keyboard (select, pick, skip, drawer, pause, toast dismiss)
- [x] Focus is visible at all times (2 px `state_actionable` ring, 3 px offset, also at `instant`)
- [x] Focus does not escape the screen while it is open (pause / confirm trap; the drawer is non-modal and keeps focus within the shell)
- [x] Esc key closes or cancels (drawer → confirm/pause → opens pause) and does not quit the game from within this screen

**Gamepad** (post-v1 — documented mapping only)
- [ ] All interactive elements reachable with D-Pad and left stick — mapping defined (Focus Management), not implemented in v1
- [ ] Face button mapping documented and consistent with platform conventions — `ui_accept` / `ui_cancel` only
- [x] No action requires analog stick precision that cannot be replicated with D-Pad
- [ ] Trigger and bumper shortcuts documented if used — shoulders = Tab / Shift+Tab (library default), nothing screen-specific
- [ ] Controller disconnection while screen is open is handled gracefully — not specified anywhere yet (§15)

**Mouse**
- [x] Hover states defined for all interactive elements (lift; Button patterns)
- [x] Clickable hit targets are at minimum 32x32px (options ≥ 150x210; buttons 160x44; chips 44x44; drawer rows 44 px)
- [x] Right-click behavior defined (closes the drawer; otherwise no-op)
- [x] Scroll wheel behavior defined in all scrollable zones (drawer only)

**Touch (if applicable)** — not applicable: no touch target (technical-preferences; accessibility-requirements Motor).

---

## 12. Accessibility

Project-wide commitments are in `design/accessibility-requirements.md` (Standard tier + elevations). This section covers only what is specific to the draft picker. Ratios are the art bible §4 figures.

**Text contrast requirements for this screen**:

| Text Element | Background Context | Required Ratio | Current Ratio | Pass? |
|--------------|-------------------|---------------|---------------|-------|
| Step indicator (28 px bold) / floor label | `bg_edge` | 3:1 (large) / 4.5:1 | `text_light` 14.75 / `text_muted` 7.94 | [x] per art bible — verify in-engine |
| Theme label (16 px bold) | `ink` band | 4.5:1 | `text_light` 14.33 | [x] |
| Pitch, hints, button labels | `table_dark` | 4.5:1 | `text_light` 13.07 / `text_muted` 7.03 | [x] |
| Card name (14 px bold) | `ink` | 4.5:1 | 14.33 | [x] |
| Card rules text (12 px) / reading panel (18 px × scale) | `parchment` | 4.5:1 | `text_ink` 12.72 | [x] |
| Rarity pill word (12 px) | `ink` | 4.5:1 | `text_light` 14.33 | [x] |
| Placeholder reason line | `table_dark` (dimmed slot) | 4.5:1 | `text_muted` 7.03 | [x] — the slot is dimmed by fill, not by lowering text alpha |
| Drawer rows | `table_dark` | 4.5:1 | 13.07 / 7.03 | [x] |

**Colorblind-unsafe elements and mitigations**:

| Element | Colorblind Risk | Mitigation |
|---------|----------------|------------|
| Treasure rarity frame | Tint-only rarity | The word "Common" / "Rare" in the pill (treasures UI Req; accessibility audit) |
| Focused vs hovered vs selected option | All light | Focus = ring with a 3 px gap; hover = lift with no ring; selected = hugging outline that persists; committed = siblings dim |
| Synergy hint | None — text | Not colour-coded by design (run-ui U3) |
| Progress strip nodes | Band colour | Filled / ringed / hollow shapes + boss initial; tooltips with floor numbers |
| Card stamps | `state_*` numerals never appear on draft cards (printed values only) | N/A |
| Step indicator current step | `text_light` vs `text_muted` | Also an arrow glyph "→" and the current step rendered bold; the floor label repeats the context |

**Focus order** (Tab key sequence, numbered; `1`/`2`/`3` jump to stops 1–3):

1. Option 1 (treasure frame / bundle panel — within a panel `Down`/`Up` visits rows 1–3)
2. Option 2
3. Option 3 (stops for placeholders and missing-id frames are **skipped**)
4. Pick (Primary) — focusable even when Idle so its reason tooltip is reachable
5. Deck drawer toggle (Secondary) — when the drawer is open by key, focus is inside it: header → rows (Up/Down) → `Tab` returns to this stop and closes nothing; `Esc` closes
6. Take nothing (Secondary) — only when `allow_skip`
7. Menu button (title row)
8. Progress strip nodes, left → right (inspect only: tooltips)
9. Held treasure chips on the strip, left → right (tooltips)
→ cycles back to 1. Hint lines, the deck-size label and the floor label are not stops (they are text, nothing hover-only). Default: **no focus** on open; `Tab` enters at stop 1.

**Screen reader announcements for key state changes**: Not committed (Standard tier; AccessKit live-region behaviour is NOT SOURCEABLE from the engine reference — accessibility-requirements Open Questions). The spec still requires the accessible names so nothing blocks a later pass: options announce "Option n of N: <name> — <rarity> — <text>" (bundle: "<theme>: <card 1>, <card 2>, <card 3>"); Pick's Disabled reason "Choose an option first"; placeholders "No more treasures in this run". Stock `Button` / `ItemList` are used for Pick, toggles and drawer rows so names and roles come free (accessibility-requirements Platform table).

**Cognitive load assessment**:

Streams on the bundle variant: (1) three theme labels, (2) nine card texts, (3) the synergy count, (4) deck size before/after, (5) which step this is, (6) the held treasures — six, at the upper end of 7±2 and the densest read in the game (accessibility-requirements Per-Feature Matrix). Mitigations: only the focused option's hint is shown (one comparison at a time); card text is behind Card Inspect so the resting view is name + stamps; no timer anywhere; the drawer is on demand; the reveal stagger orders the reading left → right; a mis-click costs nothing (select-then-confirm). **`text_scale` reading path for compact rows** (the matrix's pending item): at 125 % / 150 % the 300x64 row keeps the cost stamp, name and stamps (which scale with the row to 80 / 96 px tall — the panel grows to 368 / 416 px, y 136–504 / 136–552, pushing the hint lines down to 520 / 568 and leaving the action row at 640 untouched), drops its 12 px first text line, and the Card Inspect preview plus `parchment` **reading panel** (18 × scale px body, unlimited lines, max 360 px wide, toward screen centre) carries the full text on hover or focus — rows never clip and never need a scroll container at three rows. This is the "reading panel on focus rather than reflow" option the pattern library's Gaps row anticipated; it is now chosen (§15 lists it as a decision taken).

---

## 13. Localization Considerations

**General rules for this screen**:
- All text elements must tolerate a minimum of 40% expansion from English baseline
- RTL layout (Arabic, Hebrew): mirrored layout required — the option row order stays `option_ids` order left → right in LTR and mirrors to right → left in RTL (so `1` is always the first option in reading order); the action row mirrors (Pick stays centre, Take nothing / Deck swap sides); the strip mirrors; card frames do **not** mirror internally (stamp positions are fixed, art bible §4)
- CJK languages: text may be 20–30% shorter — the hint lines and pitch simply centre; nothing stretches to fill
- Do not use text in images — all text must be from localization strings (`tr()` keys or Card Database `text.key` / `text.en`; run-ui AC-22)

| Text Element | English Baseline Length | Max Characters | Expansion Budget | RTL Behavior | Overflow Behavior | Risk |
|--------------|------------------------|----------------|-----------------|--------------|-------------------|------|
| Step indicator "Treasure → Bundle" | 17 | 28 | 65 % | Mirror arrow direction; centre | Shrink to 24 px bold, then ellipsise the inactive step | Low |
| Floor label "Floor 3" | 7 | 14 | 100 % | Right-align | Never truncates | Low |
| Theme label (`BundleDef.theme`) | ~8 ("weapons") | 20 | 150 % | Right-align in band | Ellipsise; full theme in the panel tooltip | Medium |
| Bundle pitch (`text.en` ≤ 60, content.md) | ≤ 60 | 84 | 40 % | Right-align, wrap | Wraps to 3 lines inside the 36 px → 54 px pitch zone; panel grows 18 px | Medium |
| Card name (≤ 32, content.md) | ≤ 32 | 32 (slot) | 0 % — the 138 px name band holds ~18 chars at 14 px | N/A (fixed slot) | Ellipsise; full name in Card Inspect | **High** — flag for the localization engineer |
| Card rules text (≤ 90) | ≤ 90 | 4 lines × ~22 chars | ~0 % | N/A | Ellipsise last line; full text in Card Inspect / reading panel | **High** (known; the reading path exists) |
| Treasure text | ≤ 90 | as card text | ~0 % | N/A | As above | **High** |
| Rarity word "Common" / "Rare" | 6 / 4 | 10 | 66 % | Pill right-aligns | Pill grows left over the name band (ellipsises the name first) | Medium |
| Hint "N cards in your deck share *theme*" | ~35 | 56 | 60 % | Right-align | Wraps to 2 lines (zone 72 px) | Low |
| Hint "fits your plan" / "Deck 27 → 30" | 14 / 12 | 24 | 70 % | Mirror arrow | Never truncates | Low |
| Placeholder reason "No more treasures in this run" | 30 | 48 | 60 % | Centre | Wraps inside the 150 px slot (3 lines) | Medium |
| Buttons "Pick" / "Take nothing" / "Deck (27)" | 4 / 12 / 9 | 20 | 65 % | Mirror positions | Button grows (Button pattern), never clips | Low |
| Toast copy | ≤ 60 | 84 | 40 % | Right-align | Toast grows down; `t_toast` scales with chars | Low |

---

## 14. Acceptance Criteria

Fixtures are run-ui U10's (`--run-ui-screen=<id> --run-ui-fixture=<name>`), captured per `.claude/docs/run-and-observe.md` into `production/qa/evidence/`. Two fixtures this spec needs are **not** in U10's list and are named as new: `draft_treasure_short` and the `text_scale` 1.5 variant of `draft_bundle_sample` (§15).

**Performance**
- [ ] Screen builds and renders its first frame within 100 ms of `draft_offered` on the reference machine (run-ui AC-26) and is fully interactive when the reveal ends (≤ 360 ms at `normal`, 0 at `instant`)
- [ ] Pick → `committed` visual (lock + siblings dim) within 50 ms (run-ui Game Feel)
- [ ] Hover / focus → Card Inspect preview complete within 100 ms

**Layout & Rendering**
- [ ] GIVEN `draft_treasure_sample`, THEN three 150x210 frames sit at x 367 / 565 / 763, y 240 (±2 px), each with a rarity word pill, and Pick is dim with no outline (run-ui AC-5)
- [ ] GIVEN `draft_bundle_sample`, THEN three 340-wide panels sit at x 90 / 470 / 850 (±2 px), each with a theme label, a pitch and three 300x64 rows, and no card text is clipped without a preview (AC-5)
- [ ] GIVEN F = 8, THEN the strip's node centres are at 416 + 64·(f−1) (AC-24) with the current floor ringed and upcoming nodes hollow with no initials
- [ ] GIVEN the window at 3840x2160 fullscreen, THEN the layout is the 1280x720 layout scaled uniformly, nothing re-flowed (AC-31)
- [ ] GIVEN `settings.text_scale = 1.5` in the fixture profile, THEN no text clips, the compact rows show name + stamps without their text line, and focusing a row opens the preview **and** the reading panel (AC-31; accessibility matrix)
- [ ] All states in §6 that have a fixture render correctly; the Empty state does not exist and no "no offers" copy is reachable

**Input**
- [ ] GIVEN `draft_bundle_sample` and keys `2` then `Enter` then `Enter` with no mouse input, THEN option index 1 is picked and exactly one `draft_pick(bundle, option_ids[1])` is issued (run-ui AC-19, AC-9)
- [ ] GIVEN the same screen and `Tab` twice from the no-focus start then `Enter` twice, THEN the same pick occurs (AC-19)
- [ ] GIVEN a double-click on option 3, THEN one pick is issued; GIVEN Pick clicked twice within 100 ms, THEN one pick is issued and the second logs `ui_intent_rejected` (AC-9)
- [ ] GIVEN `draft_treasure_short` (`option_ids: [a, b]`, `flags: [short]`), THEN frames sit at slots 0 and 1, slot 2 is a dimmed placeholder with the reason, key `3` does nothing, `Tab` never lands on the placeholder, and `pick(2)` is never sent (AC-28)
- [ ] GIVEN a focused option, WHEN `Esc` is pressed, THEN the pause overlay opens, the draft is not abandoned, and on Resume the same option is still focused
- [ ] GIVEN the drawer open, WHEN `Esc` or RMB is pressed, THEN the drawer closes and the pause overlay does **not** open
- [ ] Focus is visible (2 px ring, 3 px offset) at every stop in the retained keyboard-only screenshot, also at `anim_speed = instant`

**Events & Data**
- [ ] Every exit path in §4 issues exactly the command listed and nothing else; the screen never calls Run Structure, Reward Draft or Meta directly (grep: intents only)
- [ ] GIVEN a `draft_pick` rejected `E_NOT_OFFERED`, THEN a toast shows, the screen un-commits, and no second command is issued without a new player action
- [ ] GIVEN resume into `post_match_reward/treasure`, THEN the same three ids render with no reveal stagger and no `hero_select` / `run_start` in between (AC-12)
- [ ] GIVEN an unresolvable id in `option_ids`, THEN that slot is the missing-id frame, not pickable, and the others are (AC-21)

**Accessibility**
- [ ] All text passes the §12 ratios (in-engine measurement; test plan row 1)
- [ ] Rarity, focus/hover/selected and strip states are identifiable with colour removed (Coblis on `draft_treasure_sample` and `draft_bundle_sample`, `high_contrast_states` off and on)
- [ ] GIVEN `reduce_motion`, THEN the reveal is one fade, the fly-to-strip is a fade, and the drawer fades
- [ ] GIVEN `anim_speed = instant`, THEN every transition is 0 ms and `committed` still blocks a second pick (AC-20)

**Localization**
- [ ] Zero literal English strings in the scene scripts (run-ui AC-22 CI grep)
- [ ] GIVEN the longest German pitch and theme label in the content set, THEN nothing overflows its container (pseudo-locale +40 % pass)

---

## 15. Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Player journey map not yet created — author `design/player-journey.md` from `.claude/docs/templates/player-journey.md` to source the "30-second draft" emotional target instead of inferring it from the Core Loop. | Jacob | Before Pre-Production gate | Open |
| reward-draft UI Requirements still asks "whether to show the synergy count at all". This spec shows it on focus / hover only, never as a ranking. Confirm, then close that OQ. | Jacob + Reward Draft GDD owner | `/ux-review draft-picker` | **Decision taken here**: show on focus/hover |
| `text_scale` reading path for compact rows — reading panel on focus, rows drop their text line (no reflow, no scroll). Approve as the resolution of the pattern library's Gaps row and the accessibility matrix's pending item. | Jacob | `/ux-review draft-picker` | **Decision taken here**: reading panel |
| Deck drawer geometry (right drawer 960, 96, 320, 624; covers bundle panel 3; non-blocking) — accept, then move the Gaps row into a `Deck Drawer` pattern entry (also reused by `hero-select.md` for the starter deck). | ux-designer (`interaction-patterns.md`) | Before the first draft story | Proposed here |
| New fixtures: `draft_treasure_short` (`option_ids` of 2, `flags: [short]`) and a `text_scale` 1.5 profile variant of `draft_bundle_sample` — add to run-ui U10's required list. | Run UI GDD owner / `/qa-plan` | Before the first draft story | Proposed here |
| Bundle panel vertical geometry (y 136–456 at 100 %; 136–504 / 136–552 at 125 / 150 %) and the hint-zone y (470 / 494) are this spec's — F4 fixes only x. Record in run-ui F4 or leave to the spec? | Run UI GDD owner | Pre-Production | Proposed here (spec-owned) |
| Controller disconnection handling (checklist §11) — no GDD or pattern covers it; gamepad is post-v1, so the answer may be "nothing changes: keyboard and mouse remain live". | ux-designer | Before gamepad work (post-v1) | Open |
| Step indicator at 28 px bold is the art bible's "screen title" size; the inactive step in `text_muted` at the same size — art-director pass owed (run-ui Visual/Audio says the same). | art-director | Alpha | Open |
| Does the title row's menu button duplicate `Esc` on every run base screen (consistent with the HUD's top bar)? This spec assumes yes; `boss-intro.md` and `hero-select.md` should match. | ux-designer | `/ux-review` of the run specs | Proposed here |
| AccessKit live regions — inherited NOT SOURCEABLE item; no announcement is claimed. | ux-designer | Before first menu implementation | Open (inherited) |
