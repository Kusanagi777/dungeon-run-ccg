# UX Spec: Hand (player hand fan, card states and Card Inspect)

> Authoring guidance: .claude/docs/templates/guidance/ux-spec-guide.md (load per-section as you author — do not read entirely).

> **Status**: Approved (`/ux-review` round 2, 2026-11-04)
> **Author**: Jacob + ux-designer (`/ux-design hand` followed by hand — the skill is not model-invocable; automation `guided` under the owner's standing approval, workflow `standard`, density `balanced` from `rigor: standard`; no `AskUserQuestion` used — the recommended option was taken at every decision point and is listed in §15; no Agent tool — `art-director` / `ui-programmer` / `game-designer` not spawned)
> **Last Updated**: 2026-11-04 (revision 1 after `/ux-review` round 1 — B1 dim compositing and contrast; advisories A2 dashed-ring notches, A3 cost-freshness lag, A4 Spell Damage band re-fit, A5 new keys flagged; A1 and A6 routed in §15)
> **Journey Phase(s)**: Moment-to-moment loop — "read the board, spend mana, choose attacks, end turn, watch the boss act" (game-concept Core Loop). Match view states `Idle`, `Dragging`, `KeyTargeting`, `Playback`, `BossTurn` (match-ui States). `design/player-journey.md` does not exist — see §15.
> **Screen / Flow Name**: `HandFan` — a component of the match screen, drawn by `HandPresenter` on `hand_fan.tscn` (ADR-0009), sharing `src/ui/common/card_frame.tscn` with Run UI (ADR-0011). Not a screen: it never opens, closes or takes over navigation.
> **Platform Target**: PC (Windows primary, Linux dev/CI); 1280x720 logical, `canvas_items` + `keep` (DD-T05); mouse primary, keyboard complete; gamepad `Partial` post-v1; touch none (`project.yaml` has no `platform` block — values from `.claude/docs/technical-preferences.md` via `design/accessibility-requirements.md`).
> **Related GDDs**: `design/gdd/match-ui.md` U2 (`hand()`, `card_text()`), U3 (`card_drawn`, `card_played`, `spell_cast`, `card_discarded`, `card_burned`, `enchantment_*`, `auras_recomputed`, `mulligan_resolved`), U4, U5 (Drag to play, Click to select, Keyboard, Keyboard inspect), U6 (BossTurn lock), F1 (hand fan), F2 (hover preview), F3, F6 (hand zone 240, 462, 800, 258; mana bar; tray), States, Edge Cases ("hover active when its card leaves the hand", "hand is full and a draw burns", "number key for an empty slot"), Tuning Knobs (`HAND_W`, `HAND_GAP`, `ARC_H`, `THETA_*`, `HOVER_IN_S`), Visual/Audio (card lift, card drop, boss-turn hand dim), Game Feel, UI Requirements ("Hand fan" row → this file), AC L10, L14, O1, O2, O17, O18, Open Questions ("Hover preview overlaps the player's board row" — owner `/ux-design hand`); `design/gdd/match-rules.md` C5 (effective cost, temporary mana), C6 (playability), C11 (hand order, burn), F1, UI Requirements ("Hand with effective cost (F1) per card, playable cards lit"); `design/gdd/card-effects.md` C7 (hand passives), F1 (Spell Damage), UI Requirements ("Scaled damage for a hovered spell", "Once-per-turn spent state"); `design/gdd/heroes.md` UI Requirements ("Insight tax on the drawn card"); `design/gdd/treasures.md` UI Requirements ("Discounted cost from `modify_cost` on hand cards"); `design/gdd/card-database.md` / `content.md` UI Requirements (name ≤ 32, text ≤ 90).
> **Related ADRs**: ADR-0001 (rules / presentation split — the hand never reads `MatchState`); ADR-0009 (`HandPresenter`, custom layout not a Container, `CardFrame`, `InspectLayer`); ADR-0011 (`CardFrame` shared with Run UI).
> **Related UX Specs**: `design/ux/hud.md` (APPROVED — places the hand zone on the F6 grid, Focus Order stop 1, `BossTurn` dim, §10.2 "cards do not scale"); `design/ux/targeting.md` (written in this run — everything after a card is lifted as a targeting source); `design/ux/mulligan.md` (written in this run — the opening hand before it becomes the fan); `design/ux/interaction-patterns.md` (Card (Hand), Card Drag-to-Play, Click-to-Select / Keyboard Targeting, Card Inspect, Focus Management, Escape / Cancel, Standard Shortcuts, Empty State, Animation and Sound Standards); `choice-overlay.md` (not yet written — a Discover pick flies into this fan); `design/accessibility-requirements.md`.
> **Accessibility Tier**: Standard with reduce-motion, visual-for-every-sound and the high-contrast state set elevated (`design/accessibility-requirements.md`). This spec closes two items that document leaves to `/ux-design hand`: the `text_scale` reading path for card text (Visual "Text scaling", Open Questions) and the unaffordable-card cue (Color-as-Only-Indicator Audit row "Unaffordable card in hand").
> **Template**: UX Spec

> **Sources read** (by section, coordination rule 6): match-ui Summary, U1–U12, States and Transitions, Interactions, F1–F6, Edge Cases, Dependencies, Tuning Knobs, Visual/Audio, Game Feel, UI Requirements, Cross-References, Acceptance Criteria, Open Questions; match-rules C2, C3, C5 (via C2–C8 range), C6, C11, C14, C15, States, F3, Edge Cases (hand / targeting / mulligan), Visual/Audio, Game Feel, UI Requirements; card-effects C1 rule 1, C3, C8, Edge Cases (targeting / Discover), Visual/Audio, Game Feel, UI Requirements; heroes / treasures / card-database / content / rng-event-log / boss-ai UI Requirements (grep of hand / cost rows); art bible §1–4, §7; accessibility-requirements Commitment, Visual, Colour audit, Motor, Cognitive; interaction-patterns Catalog, Card (Hand), Card Drag-to-Play, Click-to-Select, Targeting Arrow, Board Token, Card Inspect, End Turn, Hero Power, Pick One of N, Rejection Feedback, Skip & Playback, Overlay Open / Close, Focus Management, Escape / Cancel, Standard Shortcuts, Loading / Empty / Error / Success, Animation and Sound Standards, Gaps, Open Questions; hud.md header, §1, §3–§5, §10–§13 and its Focus Order table; design-decisions (all rows); stories MUI-006, MUI-008, MUI-009, MUI-017, MUI-018, MUI-020; `production/session-state/active.md` (the hud / draft-picker / hero-select / run-summary conventions).

> **Note — Scope boundary**: This document owns the player's hand from the moment a card is in it to the moment it leaves it: fan layout, every card state, the Card Inspect preview and its `text_scale` reading panel, the hand's animations, and the hand's share of the keyboard model (number keys, `Tab` stop 1). What happens **after** a card is lifted as a play source — slot gaps, the arrow, target rings, confirm and cancel — is `targeting.md`'s. Numbers marked **F1** / **F2** / **F6** are match-ui's; numbers marked *spec* are this document's decisions inside the space those formulas leave.

---

## 1. Purpose & Player Need

**What player need does this screen serve?**

The hand is where the player keeps their options. On every player turn they need to see, without a click, which of up to ten cards they can afford and play right now, what each costs **after** every discount and tax, and — on demand by hover *or* focus — the full rules text of any card. Pillar 4 ("readable, deterministic rules") puts the real number on the stamp: a card that costs 3 because a treasure discounted it must say 3, and say that it was discounted. Pillar 3 ("lose fast, learn fast") needs the player to have *seen* every option they had when they lost. The hand also has to obey: a card lifts the instant it is pressed and follows the cursor with no smoothing (match-ui Player Fantasy, "a hand that obeys you"). If the hand fails, players either misjudge mana ("why can't I play this?") or never read the cards they are holding.

**The player goal** (what the player wants to accomplish):

Scan the hand in one glance — affordable cards stand out, costs are truthful — read any card fully in one hover or one key press, and pick a card up to play it by drag, click or number key.

**The game goal** (what the game needs to communicate or capture):

Render `MatchViewState.hand[]` in hand order (match-rules C11: new cards append right) at the F1 positions; show `effective_cost` and `playable` from `hand()` exactly; never show a number the projection cannot reproduce (match-ui U3); hand the selected card to the targeting session (`targeting.md`) as the source of `play_card(hand_index, …)`.

---

## 2. Player Context on Arrival

The hand is always on screen during a match; "arrival" here means the start of each player turn — the moment the hand becomes actionable.

| Question | Answer |
|----------|--------|
| What was the player just doing? | Watching the boss turn resolve (≤ 8 s typical, match-rules Game Feel) with the hand dimmed one step (`BossTurn`), or — on turn 1 — confirming the mulligan. The turn's draw has just slid in from the deck pile (match-rules C4 Start step 6). |
| What is their emotional state? | Focused calm — art bible §2 "Match — player turn: I can see everything I need"; after a hard boss turn, tense and looking for an answer. |
| What cognitive load are they carrying? | High: board state, boss intent, both heroes, mana and up to ten cards (accessibility-requirements Cognitive "more than 4 things"). The hand must lower it: affordability is pre-computed and lit, so the player never subtracts cost from mana in their head. |
| What information do they already have? | The board and the intent banner (above the hand); mana "n/m" at the right of the hand (F6 1060, 652); their deck's composition from memory. |
| What are they most likely trying to do? | Find the play that answers the intent banner, then the one that spends the rest of the mana; read an unfamiliar card drafted last floor. |
| What are they likely afraid of? | Mis-playing by a stray click (a single click never plays a card — U5), not being able to read a card at 12 px, and a hidden cost change ("it said 4 last turn"). |

**Emotional design target for this screen**:

"My options, plainly" — a fan of lit documents on a warm table where the ones I can play glow and nothing moves under my cursor unless I move it (match-ui Feel Reference: no re-flow under the cursor).

---

## 3. Navigation Position

**Screen hierarchy**:

```
Run shell
  └── Boss Intro → Match (Match UI scene, hud.md)
        ├── Mulligan overlay (mulligan.md) — opening hand shown here, then becomes the fan
        ├── Hand fan (this spec) — player-turn options
        │     └── Targeting session (targeting.md) — a lifted card as the play source
        ├── Choice overlay (choice-overlay.md) — a Discover pick flies into the fan
        ├── Pause menu (pause-menu.md) — over everything except `Ended`
        └── End banner (match-end.md)
```

**Modal behavior**: Not a screen and never modal. The hand is part of the match table (hud.md §3 "Hand zone"); it has no open / close, no back and no `Esc` step of its own — `Esc` on the hand is Escape / Cancel chain step (1) only when a targeting session started from a hand card (`targeting.md`), otherwise it falls through to step (4), the pause menu (hud.md).

**Reachability — all entry points**:

| Entry Point | Triggered By | Notes |
|-------------|-------------|-------|
| Match start (new match) | `mulligan_resolved` → the kept and redrawn cards travel from the Mulligan row into their F1 slots | `mulligan.md` §10 owns the travel; the fan exists from this frame |
| Scene (re)load / fixture | `events_since(0)` projected at `anim_speed = instant` (match-ui Edge Cases "scene is reloaded") | Hand appears at its final layout with no animation |
| Every player turn | `turn_started{side: player}` + the Start-step `card_drawn`, then queue drain → `Idle` | Cards become actionable (outlines) only in `Idle` |
| Keyboard | `Tab` stop 1 (hud.md Focus Order), number keys `1`–`9`, `0` | Number keys go **straight into targeting** (U5), `Tab` only inspects |

---

## 4. Entry & Exit Points

The hand has no screen-level entries and exits; the table below records how **cards** enter and leave it, because each one is an animation and an event the hand must render.

**Entry table** (a card arrives in the hand):

| Trigger | Source Screen / State | Transition Type | Data Passed In | Notes |
|---------|----------------------|-----------------|----------------|-------|
| `card_drawn{side: player}` | Deck pile (F6 1180, 540) | `draw` slide 0.2 s (F3) from the pile to the new F1 slot, face up; existing cards re-space in the same step (*spec*, §10) | `instance_id`, `card_id`; `effective_cost` / `playable` from `hand()` at the next idle | New cards append right (C11) |
| `card_added_to_hand{side: player}` (Discover pick, `add_to_hand`, `copy_to_hand`) | Choice overlay centre (Discover) or the table centre 640, 318 (other effects) | `draw` slide 0.2 s from the source point to the F1 slot | `instance_id`, `card_id`, `hand_size` | **No match-ui U3 row** — §15 (the projection implements it, story MUI-001; the GDD table does not) |
| `minion_returned{burned: false}` (bounce) | The minion's board slot | `draw` slide 0.2 s from the token's position | `entity_id`, `card_id`, `instance_id` | **No match-ui U3 row** — §15 |
| `mulligan_resolved` | Mulligan row (278, 202, 723, 315) | `mulligan.md` §10 (flip 0.3 s, then travel into the fan) | Final hand ids | The only time cards enter from the overlay |
| Fixture / reload | — | None (instant) | Full projected hand | U11 |

**Exit table** (a card leaves the hand):

| Exit Action | Destination | Transition Type | Data Returned / Saved | Notes |
|-------------|------------|-----------------|----------------------|-------|
| Played (`card_played` minion / weapon) | Board slot / weapon slot | `play_card` travel 0.25 s + 4-frame squash on land (`targeting.md` / hud.md); remaining cards re-space in the same step | `play_card(hand_index, position, target_id)` was submitted by the targeting session | Irreversible — mana paid at acceptance (C5) |
| Cast (`spell_cast`) | Table centre "resolving" position (640, 318) then fades as `card_to_graveyard` is silent | `play_card` travel 0.25 s | As above | match-rules Visual/Audio "card travels to a centre resolving position" |
| Discarded (`card_discarded{side: player}`) | Off-table (no graveyard zone in F6) | Rises 40 px and fades, 0.25 s (*spec* — U3 says "flies to the graveyard", F6 has none; §15) | — | Feed line names the card |
| Mulligan replace | Deck | Owned by `mulligan.md` | `mulligan(keep_mask)` | Only during `Mulligan` |
| Drag / select cancelled | Back to its F1 slot | Tween back 0.15 s ease-out, no bounce | Nothing — no command, no event | `targeting.md` |
| Burned (full hand, `card_burned`) | Never enters — shown face up over the deck pile 0.4 s then dissolves (hud.md §4.2 deck piles) | — | — | The fan does not change (match-ui Edge Cases) |

---

## 5. Layout Specification

### 5.1 ASCII Wireframe

Full hand, n = 10 (fixture `hand_10`), player turn, two cards unaffordable, one discounted — F1 centres x = 315 + 72.2·i, rotations −15° … +15°, outer cards' bottoms on `HAND_BASE_Y` 696, centre cards at y 672.3:

```
 x:0  24   144 152 200 240  315   387   459   532   604  676   748   821   893   965   1040 1060    1256 1280
 y:
 334 │ ┌────────┐ [HP]   ┌─ player row 301, 334, 678, 126 (tokens) ──────────────────────────┐   │ [End Turn]│
     │ │ player │ [Wp]   │                                                                  │   │ (296–340) │
 460 │ │portrait│        └──────────────────────────────────────────────────────────────────┘   │
 462 │ └────────┘ hand zone 240, 462, 800, 258 ─ centre cards' tops at y 462.3 ────────────────          │
 502 │ [T][T][T]  tray (x ≤ 162)                                                                         │
     │            ╱▔▔╲ ╱▔▔╲ ╱▔▔╲ ╱▔▔╲ ┌──┐ ┌──┐ ╲▔▔╱ ╲▔▔╱ ╲▔▔╱ ╲▔▔╱                                   │
     │           │④  ││②  ││③ ◌││⑤  ││③ ││⓪ ││④  ││⑥ ◌││①  ││②  │   ◌ = dashed cost ring           │
     │           │NAME││NAME││NAME││NAME││NM││NM││NAME││NAME││NAME││NAME│   (unaffordable)               │
     │           │▒▒▒▒││    ││░░░░││    ││  ││  ││    ││░░░░││    ││    │   ░ = 60 % (not playable)      │
     │           │txt ││txt ││txt ││txt ││tx││tx││txt ││txt ││txt ││txt │   ▒ = outline (playable)       │
 652 │           │③ ②││  ⑤ ││    ││④ ④││  ││  ││    ││    ││② ③││① ①│              ┌ 3/5 ─────────┐   │
 696 │            ╲▁▁╱ ╲▁▁╱ ╲▁▁╱ ╲▁▁╱ └──┘ └──┘ ╱▁▁╲ ╱▁▁╲ ╱▁▁╲ ╱▁▁╲               │ ◆◆◆◇◇ ……     │   │
 715 │  rotated envelope x 188–1092 (y ≥ 474); lowest corner y 715.4                └──────────────┘   │
 720 └──────────────────────────────────────────────────────────────────────────────────────────────────┘
       ⓪ on card 5 = cost stamp on `ink` with a `state_buff` numeral (discounted); ⑥ on card 7 = `ink` stamp with a
       `state_danger` numeral (Insight tax) — both also carry the "printed n" line in Card Inspect (§6, §12)
```

Hover / focus preview (F2) on card 2 of n = 10 — 225x315 upright, bottom on 696, top 381, x clamped to 112.5–1167.5, neighbours unmoved; at `text_scale` 150 % the reading panel sits beside it (*spec* rule below):

```
 y: 334 ┌─ player row ────────────────────────────────────────────┐
    381 │        ┌─────────────────┐ ┌───────────────────────────────┐  ← reading panel 360 wide, bottom y 644,
        │        │ ③        (1.5x) │ │ NAME (ink band, 18 × 1.5 px)  │    height = content (max 360 → top ≥ 284),
        │        │ NAME            │ │ Taunt — reminder line         │    right of the preview when the preview's
        │        │ [art]           │ │ Rules text at 27 px, no line  │    centre x < 640, else left; 8 px gap;
        │        │ Spell Damage +2 │ │ cap; text_ink on parchment    │    right-side x clamped ≤ 748 (ends ≤ 1108,
    460 └────────│ rules text 18px │ │                               │    clear of End Turn at x 1116)
        hand ╱▔▔ │                 │ └───────────────────────────────┘
             │④  │ ②           ⑤  │ ← ink band "Spell Damage +2 · deals 5" only when the scaled value exists (§6)
    696 ─────────└─────────────────┘   2 px focus ring 3 px outside the preview when the preview was opened by focus
```

**Reading panel placement rule** (*spec*; Card Inspect pattern "toward screen centre", made exact here): width 360; bottom edge **y 644** (8 px above the mana bar's top at y 652, so the "n/m" readout is never covered); height = content up to **360** (top ≥ 284), beyond which the panel's own text scrolls (pattern: "scrolls only if > 50 % viewport height"); side = **right** of the preview if the preview's centre x < 640, **left** otherwise; gap 8 px; a right-side panel's x is clamped to ≤ **748** so its right edge stays ≤ 1108 (End Turn starts at x 1116), a left-side panel's x to ≥ 8. Worked values at n = 10: card 0 (preview 202.5–427.5) → panel x 435.5; card 4 (centre 603.9, preview 491.4–716.4) → panel x 724.4; card 9 (preview 852.5–1077.5) → panel x 484.5. At n = 3 the centre card (x 640) → left: panel x 159.5. The panel is drawn on `InspectLayer` (80) with `mouse_filter = MOUSE_FILTER_IGNORE`, so a panel over the player row or a neighbour card never steals the hover.

### 5.2 Layout Zones

| Zone Name | Description | Approximate Size | Scrollable? | Overflow Behavior |
|-----------|-------------|-----------------|-------------|-------------------|
| Hand zone (F6) | The card budget: centres x 315–965 for every n; centre card top y 462; rotated envelope x 188–1092 for y ≥ 474; lowest corner y ≤ 715.4 (F1). Draws above the tray and the mana bar in z | 240, 462, 800, 258 (F6) | No | n > 5 → overlap (F1 crowded branch, visible strip ≥ 72.2 px at n = 10); n 11–12 (`hand_size` safe range) → §15 |
| Hand fill | The table surface behind the cards: `table_lit` on the player turn, **`table_dark` for the whole `BossTurn` state** (match-ui Visual/Audio "Boss turn"; art bible §2 — the fill dims, the cards keep their contrast) | Same rect as the zone, behind the cards | No | — |
| Card Inspect preview (F2) | One 225x315 upright card, bottom on y 696, top y 381, x clamped 112.5–1167.5; on `InspectLayer` (80) above the player row it overlaps (decided, §15) | 225 x 315 | No | Rules text at 18 px holds the 90-char limit (content.md) in the 1.5x text box; longer → the reading panel (125 % / 150 %) or ellipsis at 100 % (never happens with validated content) |
| Reading panel (`text_scale` ≥ 125 %) | `parchment` panel: `ink` name band, keyword reminder lines, rules text at 18 × scale px (22.5 / 27), `text_ink`, unlimited lines; placement rule §5.1 | 360 x content (≤ 360), bottom y 644 | Yes — only past 360 px | Scrolls (wheel while the card is hovered; `Down`/`Up` while it is focused) — never clips |
| Spell Damage band (inside the preview) | 24 px `ink` band inside the preview's art box, **above the keyword icon row**: relative to the preview, x 12–213 (the 1.5x art box is x 12–213, y 96–177) and y 144–168 (the 1.5x keyword icons run ≈ y 168–186 along the art-box bottom edge, so the band ends where they start). "Spell Damage +N · deals X" — 14 px bold `text_light`, X in `state_buff` (re-fitted in revision 1, review A4) | 201 x 24 | No | Shown only when the scaled value exists in the read model — §8, §15 |

### 5.3 Component Inventory

| Component Name | Type | Zone | Purpose | Required? | Reuses Existing Component? |
|----------------|------|------|---------|-----------|---------------------------|
| Hand card ×0–10 | Card (static, interactive) | Hand zone | One card in hand: cost, name, art box, text, attack / health or durability, keyword glyphs | Yes | Yes — Card (Hand); `CardFrame` (art bible §4 slot layout) |
| Cost stamp — printed | Stamp | Card | `effective_cost` = printed cost | Yes | Yes — art bible §4 cost stamp (`#3B5A82` fill, 2 px `ink` ring, 20 px bold `text_light`) |
| Cost stamp — modified | Stamp variant | Card | `effective_cost` ≠ printed: **`ink` fill**, numeral `state_buff` (lower) or `state_danger` (higher) | Yes | **New here** — §15 (art bible §4 has no modified-cost stamp; state colours as text are only legal on `ink`, rule a — `state_buff` on the steel-blue stamp is 2.93:1, fails) |
| Cost stamp — unaffordable ring | Stamp variant | Card | Dashed 2 px **`ink`** ring instead of the solid one when `effective_cost > mana.available`: 4 px dashes, 3 px gaps, and **each gap is cut through to the card body** (the dimmed `parchment` shows in the gap, never the stamp fill). The stamp's edge therefore reads as notched on **both** fills — steel blue and the modified-cost `ink` — at 6.26:1 († dash vs dimmed body over `table_lit`; 5.58 over `table_dark`) | Yes | **Changed here** from the audit's proposed `text_muted` dashed ring (1.65:1 on parchment) — §15; notched gaps added in revision 1 (review A2: a plain dashed `ink` ring on the `ink` stamp was invisible) |
| Playable outline | Outline | Card | 2 px `state_actionable` hugging the card, rotated with it | Yes | Yes — Card (Hand) "Playable" |
| Not-playable dim | **Opaque value dim** (not alpha) | Card | Every dimmed pixel is `0.6 × its own colour + 0.4 × the current hand fill` (`table_lit`, or `table_dark` in `BossTurn`), mixed in sRGB-encoded space (Godot 2D default, no HDR 2D), and the result is **fully opaque**: nothing behind the card — a neighbour in the crowded fan or the table — ever shows through it. Applies to the body, frame border, name band, text box, keyword icon row and bottom stamps. **Two exemptions stay at 100 %: the cost stamp and the art box (its placeholder fill and type initial)** — a dimmed type initial fails 3:1 on the bronze and neutral fills (§12). See the compositing rule below | Yes | Yes — Card (Hand) "Unaffordable / not playable"; the compositing rule and the art-box exemption are **new here** (revision 1, review B1) — §15 |
| Once-per-turn dimmed trigger icon | Glyph | Card keyword row | Hand-hosted `passive_hand` effects that are `once_per_turn` and exhausted (match-ui U3 `exhausted_sources`) | Conditional | Yes — match-ui U3 row (applies to any source card, including in hand) |
| Card Inspect preview | Overlay | `InspectLayer` | 1.5x full card on hover (0.1 s) or focus (immediate) | Yes | Yes — Card Inspect |
| Reading panel | Overlay | `InspectLayer` | Full text at `text_scale` 125 / 150 % | Yes (at ≥ 125 %) | Yes — Card Inspect "Preview + reading panel"; placement rule **new here** (§5.1) |
| Inspect cost line | Text | Preview / reading panel | "Printed cost n" when the stamp is modified | Conditional | **New here** — the non-colour backup for the modified stamp |
| Spell Damage band | Band | Preview | Scaled value of a `scales` op (card-effects F1) | Conditional (data pending, §15) | **New here** |
| Focus ring | Ring | Card / preview | 2 px `state_actionable`, 3 px offset | Yes | Yes — Focus Management |
| Hand fill | Surface | Hand zone | `table_lit` / `table_dark` (boss turn) | Yes | Yes — art bible §2 / hud.md §5 |

**Not-playable dim — compositing rule** (*spec*, revision 1, review B1). The dim is a **value** change on an opaque card, never transparency:

- **Forbidden**: per-node alpha (`modulate.a = 0.6` on each `CardFrame` child, or on the card root without flattening). Per-node alpha lets the parchment body show through the name band (`text_light` on the result 3.63:1 †, below the 4.5:1 a 14 px bold name needs) and lets an overlapped neighbour show through the text box (ghost glyphs ≈ 2.4:1 † under the card's own rules text).
- **v1 implementation (recommended)**: the placeholder frame is flat token fills plus text, so the dimmed slots draw with **pre-mixed dim tokens**, one set per fill. Over `table_lit`: `parchment` → `#A99A85`, `ink` / `text_ink` → `#30251B`, `text_light` → `#AFA191`. Over `table_dark`: `parchment` → `#9C917F`, `ink` / `text_ink` → `#241D16`, `text_light` → `#A2998B`. Frame-border colours are mixed by the same formula. The set swaps with the fill at `BossTurn` entry and exit (instant, §10).
- **Bitmap card art (post-placeholder)**: render the dimmed part of the card into one flattened layer (`CanvasGroup`) at 60 % over an **opaque card-silhouette backing** (150x210, radius 8, rotated with the card) filled with the current hand-fill colour. This gives the same pixels as the formula. The cost stamp and the art box draw as siblings above the group at 100 %.
- **Result either way**: the card is opaque, so in the crowded fan (F1, n ≥ 6) each pixel of an overlapping dimmed card covers its neighbour exactly as a playable card would. Every ratio in §12 is therefore taken against the fill, and there is no overlapped case with a different background.

**Primary focus element on open**: Not applicable as a screen. On entering `Idle` focus goes to the **left-most playable card**, or to End Turn when nothing is lit (match-ui U5; hud.md Focus Order). If the focused card leaves the hand, focus moves to the card now at that index, else End Turn (Focus Management "Element disabled / destroyed").

### 5.4 Information Hierarchy

1. **Which cards I can play now** — the 2 px light outline on playable cards (it is the only light outline in the hand); unplayable cards recede by the 60 % value dim (§5.3), cost stamp and art box excepted.
2. **What each costs, truthfully** — the cost stamp at the top-left corner of every card, visible at every n (F1: the 72.2 px visible strip keeps x 3–37); a modified cost changes the stamp's fill and numeral, never its position.
3. **What it does on the board** — attack (bottom-left, visible at every n) and health / durability (bottom-right, read from the preview when overlapped — F1 Output range).
4. **What it says** — name band and rules text; legible at 12 px only on the outer cards and fully in Card Inspect (hover **or** focus).
5. **Why a number is what it is** — "Printed cost n", Spell Damage band, keyword reminders: one hover / key press deep, never on the resting card.

---

## 6. States & Variants

Card states (per card) and hand states (whole fan). A card's state is computed from the view-state at the last idle, never from a live query during playback (U2: the UI does not poll queries to render numbers).

| State Name | Trigger | What Changes Visually | What Changes Behaviorally | Notes |
|------------|---------|----------------------|--------------------------|-------|
| Card — playable | `hand()` `playable = true`, view state `Idle` | 2 px `state_actionable` outline; full opacity | Press / click / number key starts a targeting session (`targeting.md`) | Not lifted at rest (Card (Hand)) |
| Card — not playable, unaffordable | `playable = false` and `effective_cost > mana.available` | No outline; the 60 % opaque value dim (§5.3 compositing rule) on body, frame, name band, text box, keyword row and bottom stamps; art box and cost stamp at 100 %, the cost stamp with the **dashed**, notched 2 px `ink` ring | Press does nothing (no lift, no command); hover / focus still inspect | Reason line "Not enough mana (needs n, have m)" in Card Inspect (§15: needs the reason field or the fallback comparison) |
| Card — not playable, other reason | `playable = false`, cost affordable (board full, spell with no legal target — C6) | As above but the cost ring stays solid | As above | Reason line from `unplayable_reason` when the read model carries it ("Board full" / "No legal target"); absent → no line (§15) |
| Card — modified cost (lower) | `effective_cost < card_text.cost` (aura, enchantment, treasure `modify_cost`) | Cost stamp fill → `ink`, numeral `state_buff` (`#3DBE5A`; `#4FA3FF` under `high_contrast_states`) | — | Inspect line "Printed cost n" |
| Card — modified cost (higher) | `effective_cost > card_text.cost` (Insight tax, heroes UI Req) | Cost stamp fill → `ink`, numeral `state_danger` (`#FF5A4D`; `#FF8C42` high-contrast) | — | Inspect line "Printed cost n" |
| Card — hovered | Pointer over the card, `Idle` | Card Inspect preview (F2), tween `HOVER_IN_S` 0.1 s; neighbours never move | No selection; no focus move (hover ≠ focus) | Mouse only |
| Card — focused | `Tab` (stop 1) or default `Idle` focus | Preview immediately; 2 px focus ring 3 px outside the **preview** rect (the preview is what is on top); if a hover preview of another card is showing, the most recent input source wins the single `InspectLayer` and the ring stays on the focused fan card | `Enter` on a playable card → targeting session; on a not-playable card → nothing | match-ui U5 "Keyboard inspect" |
| Card — lifted / selected | Drag pickup, click-to-select or number key | Owned by `targeting.md` (drag: 1.0x upright under the cursor; select: lifted 8 px with the outline) | Session owned by `targeting.md` | — |
| Card — once-per-turn exhausted | `exhausted_sources` contains the card (U3) | Its trigger glyph in the keyword row at 60 % (the same opaque value mix as §5.3, applied to the glyph alone; on a not-playable card the glyph is mixed once, not twice) | — | Cleared on `turn_started` with no step |
| Hand — `Idle` | `phase == PlayerTurn.Main`, queue idle | Outlines on playable cards; `table_lit` fill | Full input | — |
| Hand — `Playback` | Queue busy (player's own command resolving) | **No outlines** (legality is stale while the display lags — U2); cards keep their cost stamps | Pointer and number keys are skip-all / flush inputs only; no hover preview (match-ui States lists hover for `Idle` only — §15 proposes inspect during playback) | — |
| Hand — `BossTurn` | `turn_started{side: boss}` until `turn_started{side: player}` + drain | Fill → `table_dark` (instant; not an animation step, so skip does not affect it); no outlines; card contrast unchanged | As `Playback` | hud.md §5; match-ui O9 |
| Hand — `Dragging` / `KeyTargeting` | Session open from a hand card or any other source | The source card per `targeting.md`; the other cards keep their states but show no hover preview while the pointer is owned by a drag | Number keys re-select (`targeting.md` §7) | — |
| Hand — `Mulligan` | `mulligan_offered` | **Fan hidden** — the opening hand is the Mulligan row (hud.md §5) | — | `mulligan.md` |
| Hand — `ChoiceOpen` / `Menu` | Overlay open | Fan visible under the `table_dark` dim; no outlines | Base input disabled | Overlay pattern |
| Hand — empty | `len(hand) == 0` (all cards played; a passive set the starting hand to 0) | **Nothing** — no placeholder, no "empty" text; the fill stays | Number keys ignored; `Tab` skips stop 1 | **Deliberate absence** (Empty State rule) — the deck pile and feed already say why |
| Hand — full (10) | `len(hand) == HAND_SIZE` | No extra marker on the fan; the next draw shows the burn over the deck pile (hud.md) | — | Fixture `hand_10` |
| Hand — 11–12 cards | `hand_size` raised to its safe-range max 12 (match-rules Tuning Knobs) | F1 still lays them out (s = 59.1 / 54.2 px); the stamps (x 3–37) stay visible | Number keys reach 1–10 only; cards 11–12 are reachable by `Tab` and pointer | Not shipped (HAND_SIZE 10) — §15 |
| `text_scale` 125 % / 150 % | Setting | Cards unchanged (fixed 150x210 slot); Card Inspect adds the reading panel (§5.1) | — | Fixture `hand_10_ts150` (match-ui U11) |
| `high_contrast_states` | Setting | Modified-cost numerals swap to `#4FA3FF` / `#FF8C42` | — | Token swap only |
| `reduce_motion` | Setting | Preview fades in at half duration (50 ms) instead of scaling; draw / play travel kept (positional); no squash on land | — | accessibility-requirements Visual "Reduce motion" |
| `anim_speed = instant` | Setting / harness | Every hand step applies its final state; focus ring still drawn | — | Harness default |

---

## 7. Interaction Map

Mapping interactions for: **keyboard + mouse** (Phase 2h — no `platform` block in `project.yaml`; technical-preferences via accessibility-requirements). Covering **Partial** gamepad support as a post-v1 mapping onto the same focus graph and keyboard-targeting model (match-ui U5 "Gamepad"); touch not supported.

### 7.1 Navigation Inputs

| Input | Platform | Action | Visual Response | Audio Cue | Notes |
|-------|----------|--------|-----------------|-----------|-------|
| `Tab` / `Shift+Tab` | KB | In `Idle`: move focus across hand cards left → right (stop 1 of hud.md Focus Order), then on to the player row | Ring + preview | `ui_hover` | Inspect only — `Tab` never selects |
| Mouse hover | PC | Card Inspect preview for the hovered card (`Idle` only) | Preview 0.1 s | `ui_hover` | Never moves focus |
| `1`–`9`, `0` | KB | Select hand card 1–10 **into keyboard targeting** (U5) | Source lift per `targeting.md` | `sfx.ui.card_lift` | Empty slot → ignored (Edge Cases); not-playable card → ignored, its preview opens (focus moves to it) so the reason line is readable |
| Mouse wheel | PC | Over a hovered card whose reading panel overflows: scroll the panel | Panel scrolls | — | No other wheel use on the hand |
| `Down` / `Up` | KB | While a card with an overflowing reading panel is focused: scroll the panel | Panel scrolls | — | Otherwise no-op |
| Gamepad (post-v1) | — | d-pad moves focus along the fan (`focus_neighbor_left/right`); up leaves to the player row | Same | Same | No v1 decision blocks this |

### 7.2 Action Inputs

| Input | Platform | Context (What must be focused) | Action | Response | Animation | Audio Cue | Notes |
|-------|----------|-------------------------------|--------|----------|-----------|-----------|-------|
| LMB press + move > `CLICK_DRAG_PX` (8 px) | PC | Pointer on a playable card, `Idle` | Drag pickup | Card lifts within one frame, then follows the cursor (session in `targeting.md`) | 0 ms pickup | `sfx.ui.card_lift` | match-ui Input Responsiveness: ≤ 16 ms |
| LMB press + release < 8 px | PC | Pointer on a playable card, `Idle` | Click-to-select | `KeyTargeting`, `entered_by = pointer` (`targeting.md`) | Lift 8 px | `sfx.ui.card_lift` | A single click never plays a card |
| LMB on a not-playable card | PC | `Idle` | Nothing (no lift, no command, no rejection — the InputRouter ignores it) | Preview already showing from hover | — | — | Rejection Feedback "When NOT to Use": ignored inputs produce nothing |
| `Enter` / `Space` | KB | A playable hand card focused | Enter keyboard targeting for it | As number key | Lift 8 px | `sfx.ui.card_lift` | `Space` here is **not** End Turn (U5, L15) |
| `Enter` / `Space` | KB | A not-playable card focused | Nothing | — | — | — | — |
| LMB on empty table / `Space` / `Enter` | PC / KB | Queue busy | Skip-all (U4.5) | Every pending hand step applies its final state | 0 | — | Not a hand action, listed because cards mid-slide snap to their slots |
| RMB / `Esc` | PC / KB | A session from a hand card | Cancel — `targeting.md` | Card tweens back 0.15 s | 0.15 s | `ui_select` cancel variant | Escape / Cancel step (1) |

### 7.3 State-Specific Behaviors

| State | Input Restriction | Reason |
|-------|------------------|--------|
| `Playback`, `BossTurn` | Pointer and number keys are skip / flush only; no pickup, no preview, no focus cycling | match-ui States: controls locked except skip, pause, feed |
| `Mulligan` | Fan hidden; number keys belong to the Mulligan row | `mulligan.md` |
| `ChoiceOpen`, `Menu` | Base input disabled recursively | Modal overlays |
| `Ended` | All input locked | match-ui States `Ended` |
| `Dragging` | Hover previews suppressed (the drag owns the pointer) | One session at a time (Card Drag-to-Play) |

---

## 8. Data Requirements

| Data Element | Source System | Update Frequency | Who Owns It | Format | Null / Missing Handling |
|--------------|--------------|-----------------|-------------|--------|------------------------|
| `hand[]` — ids in hand order | Match UI `MatchViewState` (projection of `card_drawn`, `card_added_to_hand`, `card_played`, `spell_cast`, `card_discarded`, `minion_returned`, `mulligan_resolved`) | Every event | Match Rules (state) / Match UI (projection) | `[{instance_id, card_id}]` | Empty → deliberate absence (§6) |
| `effective_cost`, `playable` per card | Match Rules via `MatchQuery.hand(player)` (F1, C6) | Read at each `Idle` entry and after each accepted command's drain. **Stated lag** (revision 1, review A3): stamps are not refreshed during `Playback` or `BossTurn`, so a cost that changes mid-boss-turn (an aura minion dies) shows its old value until the player's `Idle` entry. Reason: U2 forbids polling a query to render numbers, and U3 has no cost-carrying event to project. The match-rules UI Requirements row asks for "every event"; the gap is routed in §15 | Match Rules | `{instance_id, effective_cost: int, playable: bool}` | Missing entry for an id → card drawn at printed cost, not playable, debug warning (desync guard; never shipped) |
| `unplayable_reason` per card | **Not in `hand()` today** — proposed field (`NOT_ENOUGH_MANA` / `BOARD_FULL` / `NO_LEGAL_TARGET`) | As above | Match Rules / Match UI (`MatchQuery` facade) | enum | Absent → the reason line is omitted; the dashed ring falls back to `effective_cost > mana.available` (two projected numbers compared for display only) — §15 |
| Printed card fields: `name_key`, `text_key`, `type`, `cost`, `attack`, `health`, `durability`, `keywords[]` | Card Database via `MatchQuery.card_text(card_id)` | Static per card | Card Database | Record | Unresolved key → `??key` rendered + debug warning (match-ui Edge Cases) |
| `mana{available, max, temporary}` (player) | `MatchViewState` | `mana_*`, `crystal_gained` | Match Rules | ints | Never null in a match |
| Scaled values of `scales` ops on spells (Spell Damage) | **Not in any read model today** | Per hover / focus | Card Effects (F1) | `{op_index, requested, scaled}` | Absent → the Spell Damage band is not drawn (never a guessed number) — §15 |
| `exhausted_sources` | `MatchViewState` (U3 `trigger_resolved{once_per_turn, exhausted}`) | Event | Match UI | set of ids | Empty → no dim |
| View state (`Idle` / `Playback` / `BossTurn` / …), `active_side` | Match UI `InputRouter` + `MatchViewState.phase` | Event / queue drain | Match UI | enum | — |
| Settings: `text_scale`, `high_contrast_states`, `reduce_motion`, `anim_speed` | Meta Progression (DD-X07) | `settings_changed` | Meta | DD-X07 record | Absent (MVP) → defaults (100 %, off, off, normal) |
| Layout knobs: `HAND_W`, `HAND_GAP`, `ARC_H`, `THETA_STEP_MAX`, `THETA_TOTAL_MAX`, `HOVER_IN_S`, `CLICK_DRAG_PX` | `match_ui.json` via `config("match_ui")` | Once at `MatchView._ready` | Match UI (Tuning Knobs) | numbers | Validated at boot by Card Database; the UI never parses JSON |

> **Rule**: This screen must never write directly to any system listed above. All
> player actions fire events (see Section 9). Systems update their own data and
> notify the UI.

---

## 9. Events Fired

The hand issues **no command of its own**: every play is assembled and submitted by the targeting session (`targeting.md` §9). Intents below are `InputRouter` intents (match-ui U1, U5).

| Player Action | Event Fired | Payload | Receiver System | Notes |
|---------------|-------------|---------|-----------------|-------|
| Hover a card | none (local `inspect` intent) | `{instance_id}` | Match UI `InspectLayer` | Deliberately no event — inspection is not game state |
| Focus a card (`Tab`) | none | — | Match UI | — |
| Press / click / number key / `Enter` on a playable card | `select_source{kind: hand, hand_index, entered_by}` (local intent) | `{hand_index, instance_id, entered_by: pointer \| key \| drag}` | Match UI `InputRouter` → targeting session | The command (`play_card`) is fired by `targeting.md` on confirm — **persistent state change** (mana paid, card moved) |
| Number key for an empty slot / not-playable card | none | — | — | Ignored by design (match-ui Edge Cases); no `ui_intent_rejected` |
| Skip-all over a busy hand | `skip_all` (local) | — | `AnimationQueue` | U4.5 |

No analytics system exists in v1; the event log is the record (Pillar 4).

---

## 10. Transitions & Animations

| Transition | Trigger | Direction / Type | Duration (ms) | Easing | Interruptible? | Skipped by Reduced Motion? |
|------------|---------|-----------------|--------------|--------|----------------|---------------------------|
| Hand appears (match start) | `mulligan_resolved` | Cards travel from the Mulligan row into their F1 slots (`mulligan.md` §10) | 200 (`draw`) | ease-out | Yes (skip) | No — positional travel |
| Draw | `card_drawn` / `card_added_to_hand` / `minion_returned` | Slide from the source point to the new slot, face up; the existing cards re-space to their new F1 positions **in the same step** (*spec* — F3 has no re-space duration) | 200 ÷ `SPEED_DIV` | ease-out | Yes | No (positional) |
| Play / cast | `card_played` / `spell_cast` | Card travels to its board slot / weapon slot / centre 640, 318; others re-space in the same step | 250 ÷ `SPEED_DIV` | ease-out; 4-frame squash on land | Yes | Travel kept; squash dropped |
| Discard | `card_discarded{player}` | Rises 40 px, fades | 250 | ease-out | Yes | Yes → fade in place |
| Cost change | `enchantment_*` / `auras_recomputed` / hook change | Stamp fill and numeral swap | 150 (`stat_recolour`) | ease-out | Yes | Not motion |
| Hover preview in / out | Pointer enter / leave (`Idle`) | Scale to 1.5x in place (F2), upright, on top | 100 (`HOVER_IN_S`) / 100 | ease-out | Yes | Yes → 50 ms fade, no scale |
| Focus preview | `Tab` / default focus | Preview appears | 0 (immediate) | — | — | — |
| Reading panel | With the preview at ≥ 125 % | Appears beside it | Same as the preview | ease-out | Yes | Fade |
| Playable outline on / off | Entering / leaving `Idle` | Outline appears / disappears | 0 (state readout, art bible §7 instant state changes) | — | — | — |
| Boss-turn dim | `BossTurn` entry / exit | Fill `table_lit` ↔ `table_dark` | 0 (not an animation step) | — | — | — |
| Drag return | Cancel (`targeting.md`) | Tween back to the F1 slot | 150 | ease-out, no bounce | — | Kept (positional) |

Impact moments on the hand: none — the hand is the quiet half of the table; impact belongs to the board (match-ui Impact Moments). Ease-out only, no ease-in, no bounce (Animation Standards).

---

## 11. Input Method Completeness Checklist

Platform Target is keyboard + mouse; the **Touch** block is dropped (not supported) and the **Gamepad** block is kept unticked as the post-v1 mapping. Every untick has a §15 row.

**Keyboard**
- [x] All interactive elements are reachable using Tab and arrow keys alone (stop 1 of hud.md Focus Order; number keys select directly)
- [x] Tab order follows visual reading order (hand left → right, then the player row — hud.md)
- [x] Every action achievable by mouse is also achievable by keyboard (inspect = `Tab`; pick up = number key / `Enter`; cancel = `Esc`)
- [x] Focus is visible at all times (2 px ring 3 px outside the preview, also at `instant`)
- [x] Focus does not escape the screen while it is open (the hand is part of the match focus graph; overlays trap their own focus)
- [x] Esc key closes or cancels — on the hand it cancels a session from a hand card (step 1) and otherwise falls to the pause menu (step 4); it never quits

**Gamepad** (post-v1 — documented mapping only)
- [ ] All interactive elements reachable with D-Pad and left stick — §15 "Gamepad: hand d-pad graph"
- [ ] Face button mapping documented and consistent with platform conventions — `ui_accept` = `Enter`, `ui_cancel` = `Esc` (Focus Management); no hand-specific button decided — §15 "Gamepad: face buttons"
- [x] No action requires analog stick precision that cannot be replicated with D-Pad (keyboard targeting replaces dragging)
- [ ] Trigger and bumper shortcuts documented if used — library default (shoulders = `Tab` / `Shift+Tab`) — §15 "Gamepad: bumpers"
- [ ] Controller disconnection while screen is open is handled gracefully — §15 "Controller disconnection"

**Mouse**
- [x] Hover states defined for all interactive elements (Card Inspect preview)
- [x] Clickable hit targets are at minimum 32x32px (each card's visible strip is ≥ 72.2 x 210 at n = 10; the top-most card in z owns overlapping pixels)
- [x] Right-click behavior defined (cancels a session; otherwise no-op — Escape / Cancel RMB rule)
- [x] Scroll wheel behavior defined in all scrollable zones (overflowing reading panel only)

**Touch (if applicable)** — not applicable: no touch target (technical-preferences; accessibility-requirements Motor).

---

## 12. Accessibility

Project-wide commitments are in `design/accessibility-requirements.md` (Standard + elevations). This section covers what is specific to the hand. Ratios are the art bible §4 figures; the ones marked † were computed for this spec with the WCAG 2.1 relative-luminance formula from the §4 hex values. A not-playable row uses the §5.3 compositing rule: every dimmed colour is `0.6 × c + 0.4 × fill`, mixed in sRGB-encoded space, on an opaque card. Because the card is opaque, the background of every dimmed pixel is the card's own dimmed slot, never a neighbour. The crowded-fan overlap (n ≥ 6) therefore has the same ratios as an isolated card. Revision 1 re-derived the rows with this rule: the pre-revision figures 5.44 / 5.36 assumed the same flattening without specifying it, and the rows below replace them.

**Text contrast requirements for this screen**:

| Text Element | Background Context | Required Ratio | Current Ratio | Pass? |
|--------------|-------------------|---------------|---------------|-------|
| Cost numeral (20 px bold) — printed | `#3B5A82` stamp | 3:1 (large) | `text_light` 5.86 | [x] |
| Cost numeral — modified | `ink` stamp | 3:1 (large) | `state_buff` 7.16 / `state_danger` 5.61; high-contrast `#4FA3FF` 6.59 † / `#FF8C42` 7.47 † | [x] |
| Attack / health numerals (20 px bold) | `ink` stamp | 3:1 | `text_light` 14.33 | [x] |
| Card name (14 px bold) | `ink` band | 4.5:1 | 14.33 | [x] |
| Rules text (12 px) — playable card | `parchment` | 4.5:1 | `text_ink` 12.72 | [x] |
| Rules text (12 px) — not-playable card | Dimmed `parchment` (`#A99A85` over `table_lit` / `#9C917F` over `table_dark`) | 4.5:1 | dimmed `text_ink`: 5.40 † / 5.39 † | [x] |
| Card name (14 px bold) — not-playable card | Dimmed `ink` band (`#30251B` / `#241D16`) | 4.5:1 | dimmed `text_light`: 5.92 † / 5.94 † (per-node alpha would give 3.63 † / 3.78 † — forbidden, §5.3) | [x] |
| Bottom stamps (20 px bold) — not-playable card | Dimmed `ink` stamp | 3:1 (large) | dimmed `text_light`: 5.92 † / 5.94 † | [x] |
| Keyword glyphs (12 px) — not-playable card | Dimmed `parchment` (v1 letter glyphs in `text_ink`) or a dimmed `ink` pill (glyphs in `text_light`) | 4.5:1 (treated as text, since v1 may use letters) | 5.40 † / 5.39 † (letters) · 5.92 † / 5.94 † (pill) | [x] |
| Art-box type initial (24 px bold) — not-playable card | Art-box fill **at 100 %** (exempt from the dim) | 3:1 (large) | Undimmed art bible values: `text_ink` on bronze 4.68 / gold 7.20; `text_light` on violet 5.76, neutral 4.73, band 1–3 5.47–7.35. Had the art box been dimmed: bronze 2.63 † / 2.56 †, neutral 2.98 † on `table_lit` — **fail**, hence the exemption | [x] |
| Dimmed card silhouette vs the fill (non-text boundary) | `table_lit` / `table_dark` | 3:1 | 4.12 † / 5.09 † | [x] |
| Unaffordable ring dashes vs the gaps (non-text) | Gap = dimmed `parchment` (cut through the stamp, §5.3) | 3:1 | `ink` dash: 6.26 † / 5.58 †, on both the steel-blue and the `ink` stamp | [x] — closes review A2 |
| Preview rules text (18 px) / reading panel (22.5 / 27 px) | `parchment` | 4.5:1 | 12.72 | [x] |
| Spell Damage band text (14 px bold) | `ink` | 4.5:1 | `text_light` 14.33 / `state_buff` 7.16 | [x] |
| Inspect cost line / reason line (`text_ink_muted` 18 px) | `parchment` | 4.5:1 | 5.95 | [x] |

**Colorblind-unsafe elements and mitigations**:

| Element | Colorblind Risk | Mitigation |
|---------|----------------|------------|
| Playable vs not playable | Light outline vs none | The outline is a light value, not a hue; not-playable cards also take the 60 % opaque value dim (§5.3) — Card (Hand) |
| Unaffordable vs otherwise unplayable | Same dim | Unaffordable adds a **dashed** cost ring (shape) whose gaps are cut through to the card body, so it reads on both stamp fills — the audit row's open item, closed here with `ink` dashes (a `text_muted` ring is 1.65:1 † on parchment and would fail the 3:1 non-text rule) |
| Discounted vs taxed cost | `state_buff` green vs `state_danger` red — the deuteranopia pair | The stamp fill change (steel blue → `ink`) says "modified"; the direction is in the numeral itself vs the printed cost in Card Inspect ("Printed cost 4"); `high_contrast_states` swaps to blue / orange |
| Focus vs hover | Both light | Focus = ring 3 px outside the preview; hover = preview with no ring (Focus Management) |
| Boss-turn dim | Fill value | Also End Turn disabled and no outlines anywhere (hud.md) |
| Hero colour on frame borders | Hero primaries | Frame border is identification only; the hero initial is on the portrait (art bible §3) |

**Focus order** (the hand's share of hud.md's Focus Order table — stop 1):

1. Hand card 1 (left-most) → … → hand card n (right-most) — `Tab` inspects; `Enter` on a playable card enters keyboard targeting; number keys `1`–`9`, `0` jump straight into targeting for card 1–10.
2. → player row (hud.md stop 2) … → wraps to hand card 1 after the boss portrait (stop 11).

Default in `Idle`: the left-most **playable** card, else End Turn (hud.md). Empty hand: stop 1 is skipped. Inside a targeting session `Tab` cycles positions / targets only (`targeting.md`).

**Screen reader announcements for key state changes**: Not committed (Standard tier; AccessKit live regions NOT SOURCEABLE — accessibility-requirements Open Questions). Accessible names are still required so nothing blocks a later pass: "Card 3 of 7: <name>, <cost> mana[, costs 1 less than printed][, not enough mana]" (Card (Hand) pattern) and the preview's full text as `tooltip_text`.

**`text_scale` reading path (decision taken here)**: the 150x210 card and its 12 px text box do **not** scale (art bible §4 fixed slots; accessibility-requirements Visual). At 125 % / 150 % Card Inspect shows the 1.5x preview **plus** the reading panel (§5.1 rule) with the name, a reminder line per keyword (string table `keywords.json`, Card Inspect Implementation Notes) and the rules text at 22.5 / 27 px with no line cap. This is the "reading panel on focus rather than reflow" option accessibility-requirements recommends and the pattern library's Open Question asks `/ux-design hand` to settle; §15 records it as taken.

**Cognitive load assessment**: Up to 10 cards × (cost, playability, type, stats, text). Mitigations: playability is pre-computed and lit (no mental subtraction); costs are the effective numbers; text is one hover / key press deep and never needed to *act*; only one preview at a time; no timer; nothing in the hand moves under a resting cursor (F2: neighbours never move). The hover preview covers part of the player row (F2) — accepted because it is transient, on top, and disappears on mouse-out; the row's tokens are inspectable by their own hover / focus.

---

## 13. Localization Considerations

**General rules for this screen**:
- All text elements must tolerate a minimum of 40% expansion from English baseline
- RTL layout: the fan does **not** mirror its order (hand index 1 is the left-most card, which number keys depend on; match-rules C11 order is a rules order) — recorded for the localization engineer; the card frame does not mirror internally (stamp positions fixed, art bible §4); the reading panel's side rule mirrors (left of the preview when its centre < 640)
- CJK: card names are shorter; no stretch
- No text in images — names and rules text come from Card Database `name_key` / `text_key` through `tr()`; reminder lines from `keywords.json`; every UI string is a key (`ui-code.md`, match-ui U10)

| Text Element | English Baseline Length | Max Characters | Expansion Budget | RTL Behavior | Overflow Behavior | Risk |
|--------------|------------------------|----------------|-----------------|--------------|-------------------|------|
| Card name in the 138 px band (14 px bold) | ≤ 32 (content.md) | ~18 fit visibly | 0 % — already ellipsises long English names | N/A (fixed slot) | Ellipsis; full name in Card Inspect | **High** — flag for the localization engineer |
| Rules text in the 134x58 box (12 px, 4 lines) | ≤ 90 (content.md) | ~4 × 24 | ~0 % | N/A | Last line ellipsised; full text in the preview / reading panel | **High** (known — the reading path exists) |
| Preview rules text (18 px in the 1.5x box) | ≤ 90 | ~4–5 × 24 | ~10 % | N/A | Reading panel at ≥ 125 %; at 100 % a longer translation ellipsises the preview and the panel is shown at 100 % too (*spec*: the panel appears at any scale when the preview text would ellipsise) | **High** |
| Reading panel body | ≤ 90 + reminders | Unlimited (scrolls past 360 px) | Unlimited | Right-align | Scrolls | Low |
| Keyword reminder lines | ~40 each | Unlimited | 100 % | Right-align | Wrap | Low |
| "Printed cost n" / reason lines ("Not enough mana (needs 4, have 3)", "Board full", "No legal target") | 14–36 | 56 | 55 % | Right-align | Wrap inside the panel / preview | Medium |
| Spell Damage band "Spell Damage +2 · deals 5" | 25 | 34 | 35 % | Mirror order | Shrink to 12 px bold, then drop "Spell Damage" for the glyph "SD" | **High** (fixed 201 px band) |
| Accessible name "Card 3 of 7: …" | ~40 | — | — | — | Not rendered | Low |

Numbers use the locale's digits; costs are integers only.

---

## 14. Acceptance Criteria

Every observable criterion names a match-ui U11 fixture (`tests/fixtures/match_ui/<name>.json`) launched per `.claude/docs/run-and-observe.md` (`godot --path . --windowed --resolution 1280x720 --write-movie production/qa/evidence/<story>/<nn>-<what>.png --quit-after 60 res://src/ui/match/match_view.tscn -- --fixture=<name> --anim-speed=instant [--pose=…]`), screenshot **retained** in `production/qa/evidence/`. Fixtures not yet in U11 are marked *proposed* and listed in §15.

**Performance**
- [ ] Press on a playable card → card lifted within 16 ms (1 frame); hover → 1.5x preview complete within 100 ms (`HOVER_IN_S` 0.1 from config); focus → preview on the same frame (match-ui Input Responsiveness; `scene_runner()` timing test)
- [ ] A `card_drawn` at `anim_speed = instant` re-lays out the whole fan within the frame the event is applied (no frame shows two cards in one slot)

**Layout & Rendering**
- [ ] GIVEN `hand_10`, WHEN captured, THEN ten cards are visible with every cost stamp and attack stamp unobscured, the centre cards highest, every card centre within x 315–965, no card pixel left of x 188 or right of x 1092, none over the mana bar (x ≥ 1060, y ≥ 652) or the tray (x ≤ 162) (match-ui O1)
- [ ] GIVEN `hand_10 --pose=hover:<id of card 9>`, WHEN captured, THEN the preview is 225x315, upright, bottom on y 696, top y 381, x within 112.5–1167.5, on top of its neighbours, the neighbours unmoved, and the mana bar fully visible (O2)
- [ ] GIVEN `turn1_player` (4 cards, 1/1 mana), WHEN captured, THEN exactly the cards `hand()` reports playable carry the 2 px light outline, every other card carries the 60 % value dim with its cost stamp and art box at 100 %, and every card whose cost exceeds the available mana has a dashed `ink` cost ring whose gaps show the card body
- [ ] GIVEN *proposed* `hand_10_mixed` (n = 10, crowded branch; cards 2, 3, 4 and 7 not playable so that dimmed cards overlap a lit card and each other, card 3 unaffordable with a modified-cost `ink` stamp, one bronze-art card among the dimmed), WHEN captured on the player turn and again in its boss-turn variant (fill `table_dark`; *proposed* pose `--pose=boss_turn`, §15), THEN on every dimmed card: (a) the text-box background samples `#A99A85` (`#9C917F` on the boss-turn capture) ±3 per channel **including where it overlaps its neighbour** — no neighbour glyph, edge or outline is visible through it; (b) the name band samples `#30251B` / `#241D16` ±3 and its name text is legible (§12 ≥ 4.5:1 measured); (c) the cost stamp and art box sample their undimmed values; (d) card 3's dashed ring is visible on the `ink` stamp as notches of card body (review B1, A2)
- [ ] GIVEN *proposed* `hand_costs` (a `modify_cost` treasure discount on one card, the Insight tax on another, one card unchanged), WHEN captured with `--pose=hover:<discounted id>`, THEN the discounted stamp is `ink` with a `state_buff` numeral equal to `effective_cost`, the taxed stamp is `ink` with a `state_danger` numeral, the unchanged stamp is steel blue, and the preview shows "Printed cost n" with the printed value
- [ ] GIVEN `boss_turn_playback --pause-at=<seq>` inside the boss turn, WHEN captured, THEN the hand zone fill is `table_dark`, no hand card has an outline, and every card's text is at its normal contrast (the fill dims, not the cards — art bible §2) (match-ui O9)
- [ ] GIVEN an empty hand (any fixture that plays out the hand), WHEN captured, THEN the hand zone shows only the fill — no placeholder, no text — and `Tab` from the default stop never lands in the hand zone
- [ ] GIVEN `hand_10_ts150` (match-ui U11 settings variant), WHEN captured with `--pose=hover:<card 0>`, `hover:<card 4>` and `hover:<card 9>`, THEN the cards are unscaled, the reading panel is 360 wide with its bottom at y 644, at x 435.5 / 724.4 / 484.5 respectively (±2 px), its right edge ≤ 1108, nothing clipped, and its text is 27 px
- [ ] GIVEN any fixture at 1280x720 and 3840x2160 fullscreen, THEN the fan is the 1280x720 layout scaled uniformly (no re-layout — match-ui Edge Cases)

**Input**
- [ ] GIVEN `turn1_player` with a playable card at index 2, WHEN key `2` is pressed, THEN the view enters `KeyTargeting` for that card (`entered_by = key`) and nothing is submitted; WHEN key `5` is pressed with a 4-card hand, THEN nothing happens
- [ ] GIVEN `Idle` with at least one playable card, WHEN the queue drains, THEN focus is on the left-most playable card with the ring and preview visible (`--pose=focus:<index>` capture retained beside its `hover:` pair — the ring is the only pixel difference, O17); GIVEN nothing playable, THEN focus is on End Turn
- [ ] GIVEN the focused card is played, WHEN the queue drains, THEN focus is on the card now at that index, else End Turn
- [ ] GIVEN a not-playable card, WHEN clicked or `Enter` is pressed on it, THEN no lift, no command and no rejection occur and its preview (with the reason line when available) is shown
- [ ] GIVEN a hover preview showing, WHEN its card leaves the hand (played by keyboard or discarded), THEN the preview is dismissed in the same step — no orphaned 1.5x card (match-ui Edge Cases)
- [ ] GIVEN `Playback` or `BossTurn`, WHEN the pointer rests on a hand card, THEN no preview opens and a left click runs skip-all instead (match-ui States)

**Events & Data**
- [ ] The hand presenter never calls `submit` and never polls `MatchQuery` to render a number: costs and playability come from the projection / the `hand()` snapshot taken at `Idle` entry (grep + `_assert_in_sync` after every drain)
- [ ] GIVEN a recorded stream with `card_drawn`, `card_added_to_hand`, `card_played`, `spell_cast` and `card_discarded` for the player, WHEN projected and skipped at every step index, THEN after each flush the fan's ids and order equal `MatchViewState.hand` (U4.6)
- [ ] GIVEN *proposed* `hand_spell_damage` (a Spell Damage +2 minion on board, a `scales` spell in hand), WHEN hovered, THEN — **only if** the read model carries the scaled value — the band reads "Spell Damage +2 · deals <scaled>"; WITHOUT the field, THEN no band is drawn (this criterion is NOT ASSESSED until the §15 data row is resolved)

**Accessibility**
- [ ] Every text element in §12 measures at or above its ratio in-engine (test plan row 1), including every not-playable row on `table_lit` and `table_dark`, measured on `hand_10_mixed` (an overlapped dimmed card, not an isolated one)
- [ ] `card_frame.gd` / `hand_presenter.gd` never set a per-node alpha below 1.0 for the not-playable state (grep for `modulate.a` / `self_modulate.a` in the not-playable path; the dim is the §5.3 token swap or the flattened `CanvasGroup`)
- [ ] `turn1_player`, `hand_costs` and `boss_turn_playback` pass Coblis (protanopia, deuteranopia, tritanopia) with `high_contrast_states` off and on: playable / unaffordable / modified-cost / boss-turn are identifiable by outline, dash, stamp fill and the printed-cost line
- [ ] GIVEN `reduce_motion`, THEN the preview fades in (no scale), draw and play travel still play, and no squash occurs
- [ ] GIVEN `anim_speed = instant`, THEN the focus ring is still drawn on the focused card / preview

**Localization**
- [ ] Zero literal English strings in `hand_presenter.gd` / `card_frame.gd` (match-ui CI grep for `tr()` keys)
- [ ] Pseudo-locale +40 %: names ellipsise in the band with the full name in the preview; no reading-panel text clips

---

## 15. Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Player journey map not yet created — author `design/player-journey.md` from `.claude/docs/templates/player-journey.md` so the player-turn emotional target is sourced, not inferred from the Core Loop. | Jacob | Before Pre-Production gate | Open |
| **Reading panel as the card-text scaling path** (accessibility-requirements Open Questions row "`text_scale` vs the fixed 134x58 card text slot", interaction-patterns Open Questions "Reading panel at `text_scale` 125/150%") — taken here with the placement rule in §5.1. Close both rows and add the hand placement rule to the Card Inspect pattern. | Jacob (a11y doc) + ux-designer (`interaction-patterns.md`) | `/ux-review hand` | **Decided in this spec** (designer default under standing approval) — the two documents are not edited by this run |
| **Unaffordable cue**: the audit row proposes a `text_muted` dashed cost ring; `text_muted` on `parchment` is 1.65:1 and fails the 3:1 non-text rule. This spec uses the stamp's own 2 px `ink` ring, dashed, with gaps cut through to the card body so it reads on the `ink` stamp too (revision 1, A2). Update the audit row. | ux-designer (`accessibility-requirements.md`, `interaction-patterns.md`) + art-director | `/ux-review hand` round 2 | Proposed here |
| **Not-playable dim compositing** (revision 1, review B1): an opaque value dim (`0.6 c + 0.4 fill`, pre-mixed tokens in v1, a flattened `CanvasGroup` over an opaque backing once there is bitmap art). Per-node alpha is forbidden. The **art box is exempt** with the cost stamp, because a dimmed type initial fails 3:1 on bronze (2.63) and neutral (2.98). This closes the Card (Hand) pattern's "verify … if not, dim only the art box and frame" note **the other way round**: the text holds 4.5:1 under an opaque dim, and it is the art box that must not dim. Write the rule into the Card (Hand) pattern. | ux-designer (`interaction-patterns.md` Card (Hand)) + art-director (the exemption is a look decision; real card art may change it) | `/ux-review hand` round 2 / art-director before Alpha | **Decided in this spec** (designer default); interaction-patterns not edited |
| **Default Idle focus opens a 1.5x preview after every drain** (review A1, inherited): GDD U5 (focus opens the preview; default stop = left-most playable card) plus `hud.md` put a 225x315 preview over the player row at every queue drain and turn start, for mouse players too. Proposed rule: a *programmatic* default focus draws the ring only; the preview opens on focus only once a keyboard input has followed the last pointer input. This spec follows the GDD until decided (§6 "Card — focused", §14 Input AC 2). | Match UI GDD owner (U5) + ux-designer (`interaction-patterns.md` Focus Management) | Before MUI-018 implementation | Open — routed |
| **New match keys `Down` / `Up`** (§7.1, reading-panel scroll; review A5): Standard Shortcuts lists them as "— (no lists in the HUD)" for the match, and additions go through the library. Add a match row: "`Up` / `Down` — scroll the focused card's overflowing reading panel; no-op otherwise". | ux-designer (`interaction-patterns.md` Standard Shortcuts) | `/ux-review hand` round 2 | Proposed here |
| **Cost freshness during `BossTurn`** (review A3): §8 states the lag (stamps refresh at `Idle` entry only). The match-rules UI Requirements row says "every event (costs can change)". Either amend that row to "at every player `Idle` entry", or add a cost-carrying event to U3 (e.g. `hand_costs_changed{instance_id, effective_cost}` emitted when an aura or hook change moves a hand cost) so the projection can update the stamp. | Match Rules + Match UI GDD owners | Before MUI-006 implementation | Open — the spec states the lag until decided |
| **Modified-cost stamp** (`ink` fill + `state_buff` / `state_danger` numeral) is not in art bible §4 (the cost stamp is defined only as steel blue; state colours on the steel blue fail rule a: 2.93 / 2.30). | art-director (art bible §4) | Alpha | Proposed here (spec-owned) |
| **Hover preview overlaps the player's board row** (match-ui Open Questions, owner `/ux-design hand`): keep F2 as written — the preview is on top, transient, and the row is inspectable by its own hover / focus; no alternative anchor. | Match UI GDD owner (close the OQ) | `/ux-review hand` | **Decided in this spec**; match-ui.md not edited |
| **Scaled spell damage** (card-effects UI Requirements "on the card in hand, replacing the printed number"): no read model carries the scaled value (`hand()` has `effective_cost` / `playable` only; `card_text()` is printed data), and card text has no placeholder to substitute into. This spec renders a separate band in the preview when a value exists and nothing otherwise. Needs a `MatchQuery` field (e.g. `hand()[i].scaled_values[]`) or a `card_text` template parameter. | Card Effects + Match UI GDD owners | Before the first spell-damage story | Open — the §14 criterion is NOT ASSESSED until resolved |
| **`unplayable_reason`** for the reason line ("Board full", "No legal target", "Not enough mana (needs n, have m)") — `hand()` returns only `playable: bool`. Proposed: add the first failing C6 code. Until then the dashed ring falls back to comparing two projected numbers (`effective_cost > mana.available`). | Match UI GDD owner (`MatchQuery` facade) + Match Rules | Before MUI-006 implementation (MUI-006 is already Ready — review cross-spec note) | Open |
| **U3 table gaps**: match-rules C15 events `card_added_to_hand`, `minion_returned` and `minion_transformed` (added 2026-11-03) have no row in match-ui U3; by rule 4 they would render `feed.unknown` and not update the hand. `match_view_state.gd` (story MUI-001) already projects `card_added_to_hand`; the GDD table does not. | Match UI GDD owner | Before MUI-006 implementation | Open |
| **`card_discarded` "flies to the graveyard"** (U3) — F6 has no graveyard zone. This spec uses rise-and-fade in place (0.25 s). Add a graveyard rect to F6 or reword U3. | Match UI GDD owner | Pre-Production | Proposed here |
| **Re-space timing**: F3 gives `draw` 0.2 / `play_card` 0.25 but no duration for the remaining cards re-spacing; this spec plays the re-space in the same step as the travel. | Match UI GDD owner | Pre-Production | Proposed here (spec-owned) |
| **Inspect during `Playback` / `BossTurn`**: match-ui States lists hover previews for `Idle` only, so the player cannot read their own hand while the boss acts. Proposal: allow hover / focus inspect (no selection, no outlines) during `BossTurn`, with LMB still meaning skip. | Match UI GDD owner + Jacob | Pre-Production | Proposed — this spec follows the GDD until decided |
| **Hand sizes 11–12** (match-rules `hand_size` safe range 12, match-ui Tuning Knobs "must still fit at 12"): F1 works (visible strip 59.1 / 54.2 px, stamps still visible) but number keys stop at 10 and O1 / L10 test 10 only. | Match UI + Match Rules GDD owners | Only if `HAND_SIZE` is raised | Open (not shipped) |
| Reading panel max height 360 and bottom y 644 are spec-owned (Card Inspect gives only "toward screen centre"); confirm, then add to the pattern. | ux-designer (`interaction-patterns.md`) | `/ux-review hand` | Proposed here |
| New fixtures: `hand_costs` (discount + tax + unchanged), `hand_spell_damage` and `hand_10_mixed` (n = 10, dimmed cards overlapping lit cards and each other, one unaffordable modified-cost stamp, one bronze art box — revision 1), plus a `boss_turn` pose that sets the fill to `table_dark` on any fixture — add to match-ui U11. | Match UI GDD owner / `/qa-plan` | Before MUI-006 implementation | Proposed |
| Story MUI-006 (and MUI-018 / MUI-020 for focus and `text_scale`) cite `hud.md` because this file did not exist; once APPROVED they should cite `design/ux/hand.md`. | producer (story owner) | Before MUI-006 implementation (the stories are already Ready) | Open |
| Gamepad: hand d-pad graph (§11) — `focus_neighbor_left/right` along the fan, up to the player row; not wired in v1. | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Gamepad: face buttons (§11) — `ui_accept` / `ui_cancel` only; is a dedicated "inspect" button wanted? | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Gamepad: bumpers (§11) — library default `Tab` / `Shift+Tab`; confirm no hand-specific binding. | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Controller disconnection (§11) — no GDD or pattern covers it; likely "nothing changes, keyboard and mouse stay live". | ux-designer | Before gamepad work (post-v1) | Open |
| AccessKit live regions — inherited NOT SOURCEABLE item; no announcement is claimed. | ux-designer | Before first menu implementation | Open (inherited) |
