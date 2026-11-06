# UX Spec: Targeting (play, attack and hero-power sessions, arrow, rejection feedback)

> Authoring guidance: .claude/docs/templates/guidance/ux-spec-guide.md (load per-section as you author — do not read entirely).

> **Status**: Approved (`/ux-review` round 2, 2026-11-04)
> **Author**: Jacob + ux-designer (`/ux-design targeting` followed by hand — the skill is not model-invocable; automation `guided` under the owner's standing approval, workflow `standard`, density `balanced` from `rigor: standard`; no `AskUserQuestion` used — the recommended option was taken at every decision point and is listed in §15; no Agent tool — `art-director` / `ui-programmer` / `game-designer` not spawned)
> **Last Updated**: 2026-11-04 (revision 1 after `/ux-review` round 1 — B1 pointer click precedence per phase, §7.4; advisories A1 §11 unticked, A3 `A` + number defined, A4 double-click and `H` in session, A5 Phase T filtered by position, A6 150 % rule and fixture, A7 / A2 routed, A8 resolution criterion)
> **Journey Phase(s)**: Moment-to-moment loop — "spend mana, choose attacks" (game-concept Core Loop); art bible §2 "Targeting / attack moment: commitment; a decision about to become irreversible". Match view states `Dragging` and `KeyTargeting` (match-ui States). `design/player-journey.md` does not exist — see §15.
> **Screen / Flow Name**: `TargetingSession` — the one `InputRouter` session object (match-ui U1, U5) with `entered_by: drag | pointer | key`, drawn by `TargetingArrow` (`targeting_arrow.tscn`, ADR-0009) plus the hand, board and hero presenters' "lit" states. A flow on the match table, not a screen.
> **Platform Target**: PC (Windows primary, Linux dev/CI); 1280x720 logical, `canvas_items` + `keep` (DD-T05); mouse primary, keyboard complete; gamepad `Partial` post-v1; touch none (`project.yaml` has no `platform` block — values from `.claude/docs/technical-preferences.md` via `design/accessibility-requirements.md`).
> **Related GDDs**: `design/gdd/match-ui.md` U2 (`legal_commands()`, `entity()`), U4.7 (command while busy), U5 (Drag to play, Click to select, Attack, Hero power, Rejection handling, Keyboard), U7 (targeting arrow), States (`Dragging`, `KeyTargeting`, transitions), Edge Cases (Stealth, Taunt, release outside, rejection, `match_ended` while dragging), Tuning Knobs (`CLICK_DRAG_PX`, `ARROW_LIFT_PX`, `REJECTION_TOOLTIP_S`), Visual/Audio (card lift, card drop, attack lunge, rejection), Game Feel (Input Responsiveness, Weight and Responsiveness Profile), UI Requirements ("Targeting arrow" and "Rejection tooltip" rows → this file), AC L17, O4, O5, O10, O17; `design/gdd/match-rules.md` C2 (seven commands, closed rejection-code set, `legal_commands()` expansion), C6 (play validation order, Battlecry with no legal target), C7 (hero power), C8 (attacking, DD-X11 — a defending hero never hits back), F3 (`can_attack`), C12 / Edge Cases (Stealth, Taunt, Rush, Windfury), Visual/Audio (`command_rejected`), UI Requirements ("Legal targets for the dragged card / attacker", "Rejection reason"); `design/gdd/card-effects.md` C1 rule 1 (`targeting_spec` derived from `chosen`: `required` / `optional` / `none`), C3 (`chosen`, Stealth never legal), C8.3 (Choose One: target first, pick second), Edge Cases ("Targeting and selection"), UI Requirements ("Legal targets for the dragged card").
> **Related ADRs**: ADR-0001 (only `submit`; the UI never validates rules); ADR-0009 (`TargetingArrow extends Presenter`, `_draw` per frame, line width from data; `InputRouter`); ADR-0008 (`MatchController` is the submit path).
> **Related UX Specs**: `design/ux/hud.md` (APPROVED — §5 `Dragging / KeyTargeting` row, Focus Order stops 1–4, §12 Notifications rejection row); `design/ux/hand.md` (written in this run — the hand card as a source); `design/ux/interaction-patterns.md` (Card Drag-to-Play, Click-to-Select / Keyboard Targeting, Targeting Arrow, Board Token, Hero Power Button, Hero Portrait & Health Stamp, Rejection Feedback, Tooltip, Focus Management, Escape / Cancel, Standard Shortcuts, Animation and Sound Standards); `choice-overlay.md` (not yet written — a Choose-One with a target opens it after this session submits); `design/accessibility-requirements.md`.
> **Accessibility Tier**: Standard with reduce-motion, visual-for-every-sound and the high-contrast state set elevated (`design/accessibility-requirements.md`). Motor rows this flow carries: "Hold-to-press alternatives" (click-to-select), "One-hand mode", "Aim assist — N/A" (discrete targets, keyboard cycling).
> **Template**: UX Spec

> **Sources read** (by section, coordination rule 6): match-ui Summary, U1–U12, States and Transitions, Interactions, F1–F6, Edge Cases, Tuning Knobs, Visual/Audio, Game Feel, UI Requirements, AC, Open Questions; match-rules C2, C3, C6, C7, C8, C14, C15, States, F3, Edge Cases (Targeting and playing, Windfury, Rush, Stealth Taunt), Visual/Audio, Game Feel, UI Requirements; card-effects C1 rules 1–2, C3, C8, Edge Cases (Targeting and selection, Discover), Visual/Audio, Game Feel, UI Requirements; design-decisions (all rows, incl. DD-M10, DD-X11); art bible §1–4, §7; accessibility-requirements Commitment, Visual, Colour audit, Motor, Cognitive "Reading time"; interaction-patterns Catalog and every Game-Specific / Navigation / Feedback entry named above, Animation and Sound Standards, Gaps, Open Questions; hud.md §3–§5, §10, §12, Focus Order; stories MUI-008, MUI-016, MUI-017, MUI-005, MUI-018; `production/session-state/active.md` (sibling-spec conventions).

> **Note — Scope boundary**: This document owns every **targeting session** — from the moment a play source is lifted (hand card, attacking token, attacking hero, hero power) to `submit` or cancel — and the **rejection tooltip** match-ui UI Requirements assigns here. It does not own the resting look of the sources (`hand.md` for cards, `hud.md` for tokens, portraits and the hero power button), the resolution that follows an accepted command (`hud.md` playback), or the Choice overlay a Choose-One opens after its target is chosen (`choice-overlay.md`). Numbers marked **F1** / **F6** / **U7** are match-ui's; numbers marked *spec* are this document's.

---

## 1. Purpose & Player Need

**What player need does this screen serve?**

Targeting is the moment a decision becomes irreversible (art bible §2). The player needs to know **before** releasing anything exactly where the card can go and what it can hit — legality is shown, never guessed (match-ui Game Feel "pre-release legality"; Weight profile "a release is never a guess") — and they need a way back that costs nothing. Pillar 4 makes the rules visible at the point of use: a Taunt that forces the attack is lit and nothing else is; a Stealth minion is visibly present and visibly not a target; a Rush minion cannot reach the hero and the hero is simply not lit. Pillar 3 needs every loss to be "I chose that", never "the game put it somewhere I didn't mean". And the motor commitments require that none of this needs a held mouse button: the same session is reachable by click or by keys.

**The player goal** (what the player wants to accomplish):

Pick up a card, an attacker or the hero power; see every legal slot or target lit; put it exactly there with one release, one click or one key press; or back out with `Esc` / right-click and lose nothing.

**The game goal** (what the game needs to communicate or capture):

Issue exactly one well-formed PLAYER command — `play_card(hand_index, position, target_id)`, `attack(attacker_id, target_id)` or `use_hero_power(target_id)` — built only from entries of the `legal_commands()` snapshot taken at session start, so the engine never receives a command the UI already knew was illegal (match-ui Edge Cases "a Taunt exists": never submit a known `MUST_ATTACK_TAUNT`). When the engine rejects anyway (a race), say why, in words, and change nothing else.

---

## 2. Player Context on Arrival

| Question | Answer |
|----------|--------|
| What was the player just doing? | Reading the board in `Idle`: hovering or `Tab`-inspecting cards and tokens, checking the intent banner and mana. The session starts from a press, a click or a key on a lit source. |
| What is their emotional state? | Committed and alert — "sharp, single-point, decisive" (art bible §2); the room does not change, only the amber arrow and rings appear. |
| What cognitive load are they carrying? | One question at a time: *where* (slot) and then *what* (target). Everything else on the table holds still. |
| What information do they already have? | Which sources are playable (outlines — `hand.md`, `hud.md`), the board, the intent banner's reticle (what the boss will hit next turn). |
| What are they most likely trying to do? | Kill or trade with a specific minion, go face, place a minion next to the one it buffs, answer the boss's lethal intent. |
| What are they likely afraid of? | Dropping on the wrong token, a misread Taunt, losing a card to a stray release, and — for players without a sustained hold — not being able to drag at all. |

**Emotional design target for this screen**:

"Snap, not slide" — the target is lit or it is not (match-ui Weight profile "snap quality: binary"); the release does exactly what the lit ring promised; a cancel is a shrug.

---

## 3. Navigation Position

**Screen hierarchy**:

```
Match table (hud.md, view state Idle)
  └── Targeting session (this spec) — Dragging | KeyTargeting(entered_by: pointer | key)
        ├── Phase P — choose a position (minion plays)
        ├── Phase T — choose a target (targeted cards, attacks, targeted hero power)
        ├── Phase C — confirm an untargeted play (spells, weapons, untargeted hero power)
        └── → submit → Playback (hud.md) [→ Choice overlay for a Choose-One / Discover, choice-overlay.md]
            or → cancel → Idle
```

**Modal behavior**: Not modal and not an overlay — the table stays fully visible and nothing dims (art bible §2 "no lighting change"). The session is **Escape / Cancel step (1)**: `Esc` or right-click cancels it before anything else in the chain; nothing else in the match handles `Esc` while a session is open. The player cannot be stuck: every phase has a cancel, and a phase with no legal entry is never entered (a source with no legal command is never lit — §6).

**Reachability — all entry points**:

| Entry Point | Triggered By | Notes |
|-------------|-------------|-------|
| Hand card (playable) | Press + move > `CLICK_DRAG_PX` 8 px (`Dragging`); press + release < 8 px (`KeyTargeting`, `entered_by = pointer`); `1`–`9`, `0`; `Enter` on the focused card (`entered_by = key`) | match-ui U5; `hand.md` §7 |
| Player token that can attack | Press + move / click; `A` then `1`–`7`; `Enter` on the focused token | `legal_commands()` has an `attack` for it |
| Player hero with a weapon (can attack) | Press + move / click on the player portrait; `Enter` on the focused portrait (*proposed* — hud.md Focus Order stop 4 says "Nothing"; §15) | DD-M08 / match-rules F3 (`A is hero`) |
| Hero power (`Ready`) | Press + move / click on the button; `H`; `Enter` on the focused button | match-ui U5 "Hero power" |
| Re-selection | A click or key on a *different* legal source while a session is open | Cancels the current session and opens the new one (Click-to-Select "Cancel" row) |
| Never | View state other than `Idle`; a source with no entry in `legal_commands()` | Pressing an unlit source does nothing (§7.3) |

---

## 4. Entry & Exit Points

**Entry table**:

| Trigger | Source Screen / State | Transition Type | Data Passed In | Notes |
|---------|----------------------|-----------------|----------------|-------|
| Drag pickup | `Idle` | Source lifts in ≤ 16 ms, no tween-in (match-ui Input Responsiveness) | `legal_commands()` snapshot (cached for the session), the source's `instance_id` / `hand_index` | `Dragging` |
| Click-to-select | `Idle` | Source lifts 8 px with its outline; arrow / gaps / cast zone light at once | Same; `entered_by = pointer`; initial target = the legal one nearest the cursor | `KeyTargeting` |
| Number key / `A`+n / `H` / `Enter` on a focused source | `Idle` | Same as click-to-select | Same; `entered_by = key`; initial target / position per §7.1 | `KeyTargeting` |

**Exit table**:

| Exit Action | Destination | Transition Type | Data Returned / Saved | Notes |
|-------------|------------|-----------------|----------------------|-------|
| Confirm (release on a lit slot / target / inside the cast zone; LMB on a lit target; `Enter`) | `Playback` (hud.md) | First visual step ≤ 50 ms after the input (match-ui Input Responsiveness); arrow, rings and gaps vanish on the same frame | `submit(play_card / attack / use_hero_power)` — **persistent state change** (mana paid, card moved, attack spent) | Irreversible — no undo (C5: mana never refunded) |
| Confirm on a Choose-One / Discover play | `Playback` → `ChoiceOpen` | As above; the overlay opens after the card-play step (match-ui Edge Cases) | As above | The target was chosen here first (card-effects C8.3) |
| Cancel (`Esc`, RMB, release / click on an unlit spot or empty table) | `Idle` | Source tweens back 0.15 s ease-out, no bounce; arrow, rings, gaps vanish at once | **Nothing** — no command, no event | Escape / Cancel step (1); a mis-click costs nothing |
| Re-select (click / key on another legal source) | `KeyTargeting` with the new source | Old source settles (0.15 s) while the new one lifts | Nothing | — |
| `match_ended` arrives (cannot happen from the player's own idle turn, kept for the race) | `Ended` | Session cancelled first, then the queue drains and the banner plays (match-ui Edge Cases) | Nothing | — |
| Engine rejects the submit (race) | `Idle` | Rejection Feedback (§5.1, §6): source shakes 0.2 s, tooltip 1.5 s, related flash, feed line | Nothing changes — no event was emitted | Should never happen from a correct snapshot |

---

## 5. Layout Specification

### 5.1 ASCII Wireframe

**A — Attack with a Taunt on the boss side** (fixture `targeting_taunt`, `--pose=drag:<attacker>`): the attacker stays in its slot lifted 4 px with its outline; the arrow is U7's quadratic Bezier from the token's centre to the cursor (control point `ARROW_LIFT_PX` 50 above the midpoint, 20 segments, `state_target`, triangular head); only Taunts carry the 2 px `state_target` outline; the one under the cursor adds the 3 px ring; the boss hero is not lit.

```
 x:0     301      399      497      595      693      791      889    979   1136     1256
 y:176 ┌─ boss row 301, 176, 678, 126 ───────────────────────────────────┐   ┌────────┐
       │ ┌──────┐ ┌──────┐ ┏━━━━━━┓ ┌──────┐ ┏━━━━━━┓                     │   │  boss  │  not lit:
       │ │ 3 2  │ │ 1 1 ◐│ ┃ 2 5 T┃ │ 4 4  │ ┃ 1 3 T┃◉← 3 px ring       │   │portrait│  a Taunt
       │ │      │ │stealth│ ┃taunt ┃ │      │ ┃taunt ┃   (cursor)        │   │        │  exists
 302   │ └──────┘ └──────┘ ┗━━━━━━┛ └──────┘ ┗━━━━━━┛    ╲              │   └────────┘
       └──────────────────────────────────────────────────╲──────────────┘
                                         ╭─────────────────╯  ← quadratic Bezier, control point
 334   ┌─ player row ────────────────────│──────────────────────────────┐   50 px above the midpoint
       │ ┌──────┐ ┏━━━━━━┓ ┌──────┐      │                              │
       │ │ 2 1 z│ ┃ 3 3  ┃◄── attacker: lifted 4 px, outline, arrow foot │
 460   └─┴──────┴─┺━━━━━━┹─┴──────┴─────────────────────────────────────┘
          z = summoning sick (not lit)   ◐ = Stealth badge — visible, never outlined
```

**B — Minion play, Phase P (position)**: the dragged card follows the cursor at 1.0x upright; the player row re-centres for m + 1 slots and opens a 90 px gap at the insertion index nearest the cursor; every legal index is valid (0 … m); the hovered gap shows a dashed 2 px `state_actionable` slot outline (*spec*).

```
 334 ┌─ player row: 3 tokens → laid out as 4 slots while dragging ─────────────────┐
     │          ┌──────┐ ┌──────┐ ┌ ─ ─ ─ ┐ ┌──────┐                              │
     │          │ 2 1  │ │ 3 3  │   gap ③   │ 4 2  │      position zone (*spec*):  │
     │          │      │ │      │ │ dashed │ │      │      x 253–1027, y 310–484   │
 460 │          └──────┘ └──────┘ └ ─ ─ ─ ┘ └──────┘                              │
     └──────────────────────────────▲──────────────────────────────────────────────┘
                              ┌───────────┐  dragged card 150x210, 1.0x, upright,
                              │ ② NAME    │  centred on the cursor (pickup offset kept)
                              └───────────┘
```

**C — Minion with a targeted Battlecry, Phase T** (after a release on gap index 2): a **ghost token** (90x126, 60 % alpha, dashed `state_actionable` outline) holds the gap; the arrow starts from the ghost; legal targets outlined; one more release-free click (or `Enter`) on a target submits `play_card(i, 2, target)`.

```
 176 ┌─ boss row ─────────────────────────────────────────┐
     │ ┏━━━━━━┓ ┏━━━━━━┓ ┌──────┐                          │  ← legal Battlecry targets (filter from
     │ ┃      ┃ ┃      ┃◉│ ◐    │ stealth: not lit         │    targeting_spec, enemy Stealth excluded)
 302 └─┺━━━━━━┹─┺━━━━━━┹─┴──────┴─────╲────────────────────┘
 334 ┌─ player row ────────────────────╲───────────────────┐
     │ ┏━━━━━━┓ ┌──────┐ ┌ ─ ghost ─┐ ┏━━━━━━┓             │  ← friendly targets lit too when the
     │ ┃      ┃ │      │   (60 %)    ┃      ┃             │    filter allows them
 460 └─┺━━━━━━┹─┴──────┴─└ ─ ─ ─ ─ ─┘─┺━━━━━━┹─────────────┘
          (player portrait / boss portrait outlined when the filter admits heroes)
```

**D — Untargeted spell, weapon or hero power, Phase C**: the **cast zone** — the table rect **301, 176, 678, 284** (both rows and the gap between them, *spec*) — draws a dashed 2 px `state_actionable` outline; drag: release inside it; click-to-select / key: a click inside it, a second click on the lifted source, or `Enter` — a click on a friendly token that can attack re-selects instead, and a double-click never confirms (§7.4). No arrow (Targeting Arrow "When NOT to Use").

```
 176 ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ cast zone 301, 176, 678, 284 (dashed) ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
     ╎  boss row tokens (unchanged, not lit)                                              ╎
     ╎                                                                                    ╎
     ╎  player row tokens (unchanged, not lit)                                            ╎
 460 └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
          lifted source: card 8 px above its F1 slot with the outline / hero power button lifted 2 px
```

**E — Rejection tooltip** (fixture pose `--pose=reject:MUST_ATTACK_TAUNT`): Tooltip pattern's rejection variant — `parchment` panel, 14 px `text_ink`, max 300 px wide, 8 px padding; pointer-issued: anchored 16 px right of and 16 px below the cursor, flipped left / up to stay inside x 8–1272, y 48–712; key-issued: centred 8 px **above** the source's bounds, clamped the same way; shown for `REJECTION_TOOLTIP_S` 1.5 s; the source shakes 0.2 s (3 px); the related control flashes (Taunt frames / mana bar outline); the feed gains `feed.command_rejected`.

```
            ┌────────────────────────────────────┐
     ↖ ✛    │ A Taunt minion must be attacked    │   parchment, text_ink 14 px, ≤ 300 wide
            │ first.                             │   1.5 s, never steals focus or input
            └────────────────────────────────────┘
```

### 5.2 Layout Zones

| Zone Name | Description | Approximate Size | Scrollable? | Overflow Behavior |
|-----------|-------------|-----------------|-------------|-------------------|
| Boss row (targets) | F6 301, 176, 678, 126; every token's full 90x126 is its drop / click rect | 678 x 126 | No | — |
| Player row (targets, positions, attackers) | F6 301, 334, 678, 126; re-centres for m + 1 slots during Phase P | 678 x 126 | No | Board full (7) → minions are not playable, Phase P never opens (C6 `BOARD_FULL`) |
| Position zone (Phase P drop area) | x 253–1027, y 310–484 (*spec*: the player row plus 48 px either side and 24 px above / below) — a release here picks the gap nearest the cursor | 774 x 174 | No | Release outside → cancel. It overlaps the player row's tokens and the top 22 px of the hand (y 462–484); which one a click means is fixed by §7.4 |
| Cast zone (Phase C) | 301, 176, 678, 284 (*spec*). It contains both minion rows, so a click on a friendly token inside it is resolved by §7.4 (re-select outranks confirm) | 678 x 284 | No | — |
| Hero targets | Portraits F6 24, 334, 120, 160 (player) / 1136, 96, 120, 160 (boss) — the whole panel is the rect | 120 x 160 each | No | — |
| Arrow layer | Top `CanvasLayer` (`TargetingArrow`); drawn above tokens and cards, below `InspectLayer` 80 and `TooltipLayer` 90 | Full screen | No | Head stops at the current target's ring (never covers its stamps) |
| Parked source (Phase T from a hand card) | The card at 1.0x upright, centred on its F1 x, top y 438 (*spec* — 24 px above the hand line so the arrow's foot is visible over the player row) | 150 x 210 | No | — |
| "No target" chip (Phase T, `optional` targeting only) | Secondary button 120x44 centred above the parked source / ghost / hero power (`x_c − 60`, top 8 px above the source) (*spec*); at `text_scale` 125 / 150 % its width grows to the label width + 24 px, still centred (revision 1, review A6) | 120 x 44 (min) | No | No v1 card uses `optional` (§15) |
| Rejection tooltip | §5.1 E | ≤ 300 x content | No | Wraps; 1.5 s |

### 5.3 Component Inventory

| Component Name | Type | Zone | Purpose | Required? | Reuses Existing Component? |
|----------------|------|------|---------|-----------|---------------------------|
| Targeting session | State object | — | One session, `entered_by: drag \| pointer \| key`, phases P / T / C, cached `legal_commands()` snapshot | Yes | Yes — Click-to-Select / Keyboard Targeting + Card Drag-to-Play (one `InputRouter` session, pattern Implementation Notes) |
| Targeting arrow | Line + head | Arrow layer | Source → cursor (drag / pointer) or → current target's centre (key) | Phase T | Yes — Targeting Arrow (U7) |
| Legal-target outline | Outline | Tokens / portraits | 2 px `state_target` on every legal target | Phase T | Yes — Board Token "Legal target", Targeting Arrow |
| Current-target ring | Ring | Target | 3 px `state_target`, 2 px outside the outline | Phase T | Yes — Targeting Arrow "Over legal target" |
| Summon gap | Slot | Player row | 90 px gap at the insertion index; dashed 2 px `state_actionable` slot outline on the hovered / current gap | Phase P | Yes — Board Token "Summon gap"; dashed slot outline **new here** |
| Ghost token | Token (60 %) | Player row gap | Holds the chosen position while a Battlecry target is chosen | Phase T after P | **New here** — §15 (a two-phase minion play is not in U5) |
| Cast zone | Dashed outline | Table | Untargeted confirm area | Phase C | **New here** (Targeting Arrow names a "cast affordance" without a rect) |
| Attacker "armed" state | Lift 4 px + outline | Player token / portrait | The attacking source | Attack sessions | Yes — Board Token "Can attack" outline |
| `A` attacker badges | Numeral badges | Above legal attackers | While `A` waits for a number: each **legal attacker** shows its **slot position** counted 1–7 from the left of the player row (rules board index + 1). A token that cannot attack shows no badge, so the numerals may skip (e.g. "1", "3", "4"). 14 × `text_scale` px bold `text_light` on `ink` pills; the pill is square, 20 / 24 / 28 px at 100 / 125 / 150 %, centred 6 px above each legal attacker (the 28 px pill fits over a 90 px token with the 8 px row gap to spare) | Key path | **New here** (*spec*; mapping defined in revision 1, review A3) |
| "No target" chip | Button (Secondary) | Above the source | Chooses `target_id = null` for `optional` targeting | Conditional | Yes — Button (Secondary) |
| Rejection tooltip | Tooltip (rejection variant) | At cursor / above source | `reject.<code>` copy, 1.5 s | Yes | Yes — Rejection Feedback + Tooltip |
| Source shake / related flash | Animation | Source / Taunts / mana bar | Rejection channels | Yes | Yes — Rejection Feedback |

**Primary focus element on open**: Keyboard focus does not move into the board when a session opens; the **current target / position** is shown by the 3 px ring (targets) or the dashed slot (positions), and `Tab` cycles only those (Focus Management "Tab order — targeting"). On close, focus returns to the source if it still exists (a cancelled card / token), else to the hand card now at the played index, else End Turn (Focus Management "Element disabled / destroyed").

### 5.4 Information Hierarchy

1. **What I can hit / where I can put it** — the amber outlines and gaps: binary, all lit at once, nothing else changes colour (art bible §2 "the one saturated targeting colour").
2. **What I am about to hit** — the 3 px ring and the arrow head on the current target.
3. **What I picked up** — the lifted source with its outline (and, for a Battlecry, the ghost in its gap).
4. **What will happen** — not shown as a forecast: the source's own text is one hover away (Card Inspect on the parked card), and the target's numbers are on its stamps. The UI predicts no damage (display-only, match-ui U3).
5. **How to back out** — implicit and universal (`Esc`, right-click, release elsewhere), never a visible button.

---

## 6. States & Variants

**Source → phases.** The session derives its phases only from the `legal_commands()` entries for the source (match-rules C2 expansion), never from card text: *positions* = distinct `position` values; *targets* = distinct non-null `target_id`s; *null allowed* = an entry with `target_id = null` exists alongside targeted ones (card-effects `optional`). **After Phase P** (revision 1, review A5), targets, null-allowed and the "No target" chip are re-derived from **only the entries whose `position` equals the chosen one**. No v1 selector depends on position, but card-effects C3 `adjacent` selectors would, so the filter makes a later adjacency card light the right targets with no UI change. If the chosen position's only entry is `(p, null)` (C6: a Battlecry with no legal target is still playable), choosing the position submits it and Phase T never opens.

| Source | Entries in `legal_commands()` | Phases |
|---|---|---|
| Minion, no Battlecry target (or `required` with no legal target — still playable, card-effects C3) | `(position p, null)` | **P** |
| Minion, Battlecry `required`, targets exist | `(p, t)` for every p × t | **P → T** |
| Minion, Battlecry `optional` | `(p, t)` and `(p, null)` | **P → T** with the "No target" chip |
| Spell / weapon, untargeted | `(—, null)` | **C** |
| Spell / weapon Battlecry, `required` | `(—, t)` | **T** |
| Spell / weapon, `optional` | `(—, t)` and `(—, null)` | **T** with the chip |
| Attacker (token or hero) | `attack(A, t)` | **T** (enemies only, Taunt / Stealth / Rush already applied by the engine) |
| Hero power, untargeted | `use_hero_power(null)` | **C** (confirm on the button itself or the cast zone) |
| Hero power, targeted | `use_hero_power(t)` | **T** |

| State Name | Trigger | What Changes Visually | What Changes Behaviorally | Notes |
|------------|---------|----------------------|--------------------------|-------|
| Dragging — card, Phase P | Pickup of a minion card | Card 1.0x under the cursor; row re-centres; nearest gap opens with the dashed slot outline | Release in the position zone → gap chosen (submit, or → Phase T); elsewhere → cancel | End Turn Disabled (hud.md §5) |
| Dragging — card, Phase C | Pickup of an untargeted spell / weapon | Card under the cursor; cast zone dashed | Release inside → submit; outside → cancel | — |
| Dragging — card / attacker / hero power, Phase T | Pickup of a targeted source | Source parked (card: §5.2) or lifted in place (token 4 px, button 2 px); arrow to the cursor; legal targets outlined | Release on a lit target → submit; elsewhere → cancel | match-ui U5 / U7 |
| KeyTargeting — pointer, any phase | Click (< 8 px) on a source | Same visuals; the arrow points at the **current** target (initially the legal one nearest the cursor); hovering a lit target moves the ring | A click is resolved by the **§7.4 precedence table** (confirm / re-select / ignore / cancel, first matching rank wins); `Enter` confirms the current one; RMB or `Esc` cancels | A single click never plays a card (U5) |
| KeyTargeting — key, any phase | Number key / `A`+n / `H` / `Enter` on a focused source | Same; arrow to the current target's centre (snap tween 80 ms, 0 under `reduce_motion` / `instant`) | `Tab` / `Shift+Tab` cycle; `Enter` confirms; `Esc` cancels | Initial picks §7.1 |
| Phase P → T (Battlecry) | Position chosen | Ghost token in the gap; the card returns into the parked position, then the arrow starts from the ghost | `Esc` / RMB / empty click cancels **the whole play** (card back to hand, gap closes) — there is no "back to positions" step | *spec*, §15 |
| Over a lit target / gap | Pointer over it, or current in the key cycle | 3 px ring / dashed slot outline; arrow head full opacity | Confirm here submits | — |
| Over an unlit spot | Pointer elsewhere (Phase T) | No ring; arrow head dims to 60 % | Release / click here cancels | Targeting Arrow "Over illegal / empty" |
| Taunt present | Defending side has a non-Stealth Taunt (F3 `taunters ≠ ∅`) | Only the Taunts are outlined (attacks); the hero and other minions are not | A release on a non-Taunt cancels client-side; the engine never sees `MUST_ATTACK_TAUNT` from a correct snapshot | match-ui Edge Cases |
| Stealth enemy | Enemy minion with Stealth | Its Stealth badge stays visible; **never** outlined, never a drop target, skipped by `Tab` | Release over it cancels like empty table | "Cannot be targeted", not "cannot be seen" |
| Stealth Taunt only | The only Taunt also has Stealth (F3) | Treated as no Taunt: every other enemy is lit, the Stealth Taunt is not | — | match-rules Edge Cases |
| Rush, summoned this turn | `A.rush ∧ A.summoning_sick` | Enemy minions lit, enemy hero not lit | — | `RUSH_CANNOT_HIT_HERO` never reachable from the UI |
| Windfury second attack | `attacks_remaining = 1` after the first | The token keeps its can-attack outline after the first attack; a new session is a new command | — | match-rules Edge Cases |
| Hero attacking | Player hero `can_attack` (weapon) | Portrait lifts 4 px with the outline; arrow from the portrait's centre | — | A defending hero never hits back (DD-X11) — no counter-damage forecast is drawn either way |
| `optional` targeting | Null and targeted entries both exist | "No target" chip shown; it is the last stop of the `Tab` cycle | Chip click / `Enter` on it → submit with `target_id = null` | No v1 content (§15) |
| No legal entry | Source has no `legal_commands()` entry | Source is not lit; pressing it does nothing | No session opens; no rejection (ignored input) | Rejection Feedback "When NOT to Use" |
| Rejected (race) | `submit` → `accepted = false` | Source shake 0.2 s (2-frame outline flash under `reduce_motion`), tooltip 1.5 s, related flash (`MUST_ATTACK_TAUNT` → Taunt frames; `NOT_ENOUGH_MANA` → mana bar outline), feed line `feed.command_rejected`; the dragged card returns to its F1 slot | Display otherwise unchanged; back to `Idle` | match-ui U5 / U3.4a; Rejection Feedback |
| `high_contrast_states` | Setting | Unchanged — `state_target` amber is not swapped (accessibility-requirements) | — | — |
| `reduce_motion` | Setting | Arrow snaps without the 80 ms tween; shake → outline flash; lift kept (it is a state readout) | — | — |
| `anim_speed = instant` | Setting / harness | Cancel return and snap tweens are 0 ms; arrow and rings still draw (they are state, not animation) | — | — |

---

## 7. Interaction Map

Mapping interactions for: **keyboard + mouse** (Phase 2h — no `platform` block; technical-preferences via accessibility-requirements). Covering **Partial** gamepad support as a post-v1 mapping onto this same keyboard-targeting model (match-ui U5 "Gamepad: the keyboard targeting mode above is the path a gamepad will map onto"); touch not supported.

### 7.1 Navigation Inputs

| Input | Platform | Action | Visual Response | Audio Cue | Notes |
|-------|----------|--------|-----------------|-----------|-------|
| Mouse move (Dragging) | PC | Card / arrow follows the cursor exactly, every frame, no easing | Position update ≤ 16 ms | — | match-ui Input Responsiveness |
| Mouse hover (KeyTargeting, pointer) | PC | Moves the ring / gap to the lit target under the pointer | Ring moves | `ui_hover` | Hover never moves keyboard focus |
| `Tab` / `Shift+Tab` | KB | Cycle the current target / position (cyclic, so `Shift` is optional) | Ring / gap moves; arrow snaps (80 ms) | `ui_hover` | Leaving the set requires `Esc` (Focus Management) |
| Target cycle order (*spec*) | — | **Enemy row left → right, enemy hero, friendly row left → right, friendly hero, "No target" chip** — legal entries only | — | — | Extends the pattern's "boss row left → right, then boss hero" to friendly targets |
| Position cycle order | — | Gaps left → right (index 0 … m), wrapping | — | — | Pattern "player row slots left → right" |
| Initial target / position (key entry) | — | Target: the first in the cycle order. Position: the **right-most** gap (index m — appending is the common play) (*spec*) | — | — | Pointer entry: the one nearest the cursor |
| `A` | KB | Arm attacker selection: number badges appear over legal attackers | Badges | `ui_hover` | Any non-number key disarms it (consumed, no other effect); `Esc` disarms without reaching the Escape chain (§15 pattern row) |
| `A` then a number | KB | Key `n` (`1`–`7`) selects the token in **slot position n** counted from the left — rules board index n − 1, the numeral its badge shows → Phase T | Token lifts 4 px; arrow; outlines | `sfx.ui.card_lift` | A number with **no badge** (a token that cannot attack, an empty slot, or `8` / `9` / `0`) is **ignored and the state stays armed**, so a mis-press costs nothing (revision 1, review A3) |
| `1`–`9`, `0` during a session | KB | Re-select hand card n (cancels the current session) | Old source settles, new lifts | `sfx.ui.card_lift` | Click-to-Select "a different legal source re-selects" |
| `H` | KB | Hero power → Phase T or C | Button lifts 2 px | `sfx.ui.card_lift` | Not `Ready` → ignored. **During a session** (revision 1, review A4): from any other source, `H` re-selects the hero power; during the hero power's own session, `H` is **ignored** (consumed). It never confirms; `Enter` does |
| Gamepad (post-v1) | — | Shoulders = `Tab` cycle, `ui_accept` = confirm, `ui_cancel` = `Esc` | Same | Same | Not wired in v1 |

### 7.2 Action Inputs

| Input | Platform | Context (What must be focused) | Action | Response | Animation | Audio Cue | Notes |
|-------|----------|-------------------------------|--------|----------|-----------|-----------|-------|
| LMB release over a lit gap / target / inside the cast zone (§7.4 drag-release table) | PC | Dragging | Confirm the phase (submit, or P → T) | Arrow / rings vanish; card travels / attacker lunges | `play_card` 0.25 s / `attack_lunge` 0.35 s (hud.md) | `sfx.ui.card_play` / `sfx.ui.attack_whoosh` | First visual ≤ 50 ms |
| LMB release elsewhere | PC | Dragging | Cancel | Source tweens back | 150 ms ease-out | `ui_select` cancel variant | No command, no event |
| LMB click (any spot) | PC | KeyTargeting (any `entered_by`) | Resolved by the **§7.4 precedence table**: confirm, re-select, ignore or cancel | Confirm: as above. Re-select: old settles, new lifts. Cancel: source settles | As above / 150 ms | As above / `sfx.ui.card_lift` / cancel variant | Replaces the four overlapping rows of the pre-revision table (review B1) |
| LMB on the "No target" chip / `Enter` on it | PC / KB | Phase T, `optional` | Submit with `target_id = null` | As confirm | — | `sfx.ui.card_play` | — |
| `Enter` | KB | Any session | Confirm the current gap / target / cast | As above | — | As above | `Space` is **not** confirm (it stays skip / End Turn, U5) |
| `Esc` / RMB | KB / PC | Any session | Cancel (Escape / Cancel step 1) | Source back; nothing else in the chain runs | 150 ms | cancel variant | RMB never opens the pause menu |
| LMB on End Turn | PC | Any session | Nothing (End Turn is Disabled during a session) | — | — | — | hud.md §5 |

### 7.3 State-Specific Behaviors

| State | Input Restriction | Reason |
|-------|------------------|--------|
| Any view state other than `Idle` | No session can open; presses on sources are skip / ignored | match-ui States: `Dragging` / `KeyTargeting` enter from `Idle` only |
| Session open | End Turn Disabled; `Tab` cycles the session's set only; hover previews of other cards suppressed while dragging | hud.md §5; Focus Management |
| Phase T after P (ghost in place) | Positions can no longer be changed except by cancelling the whole play | One-step cancel keeps the model shallow (*spec*) |
| Source with no legal entry | Press / key ignored, no session | Never submit a command the snapshot does not contain |
| Rejection tooltip showing | Input fully live; the tooltip takes no focus and no clicks (`MOUSE_FILTER_IGNORE`) | Rejection Feedback: "nothing happened" |

### 7.4 Pointer precedence inside a session (*spec*, revision 1, review B1)

The cast zone contains both minion rows. The position zone contains the player row and the top 22 px of the hand. A single pointer input could therefore match more than one rule. These tables fix the meaning: **the first matching rank wins**. The ranking principle is that a **reversible** outcome (re-select, ignore, cancel) outranks an **irreversible** one (confirm: mana is never refunded, match-rules C5; the hero power is once per turn). The single exception is a lit target in Phase T, which must win because it is the phase's whole purpose and is marked by its outline and ring before the click.

**Click** (press and release moving < `CLICK_DRAG_PX`, resolved at the release point; the same table applies whatever the session's `entered_by`):

| Rank | The click lands on… | Phase P (position) | Phase T (target) | Phase C (untargeted) |
|---|---|---|---|---|
| 1 | A **lit target** (outlined, in the session's target set) | — (no targets in P) | **Confirm** that target (submit) | — (no targets in C) |
| 2 | The **lifted source itself**, or the ghost token | **Ignored** | **Ignored** | **Confirm**, unless the press is the second press of an OS double-click (`InputEventMouseButton.double_click == true`), which is **ignored**. A double-click on a source therefore only selects it (review A4) |
| 3 | A **different legal source**: a playable hand card, a friendly token or the player hero with an `attack` entry, or the `Ready` hero power button | **Re-select**. Player-row tokens are never hit here in Phase P: the row is hit-tested against its m + 1 layout, where the slot under a pointer in the row band is always the open gap (rank 4). Rank 3 in Phase P therefore reaches only the hand (including the strip y 462–484), the hero power and the player portrait. To re-select an attacker from Phase P, cancel first, or press `A` + number | **Re-select** | **Re-select**, even inside the cast zone |
| 4 | Inside the phase's own zone (any spot not taken by ranks 1–3) | **Place** at the current gap (§6 Phase P). The gap index comes from the pointer's x against the m + 1 layout the row is **moving to**, never from mid-tween token pixels. While the pointer is in the row band the open gap is the slot under it, so a click on the row means "here" | — (Phase T has no zone) | **Confirm** (submit) |
| 5 | End Turn | Nothing (Disabled, hud.md §5) | Nothing | Nothing |
| 6 | Anywhere else: empty table outside the zone, an unlit or Stealth token, a not-playable hand card, a portrait that is not a target | **Cancel** | **Cancel** | **Cancel** |

**Hover tells the player the meaning before the click.** While the pointer is over a rank-3 source, the phase's own affordance is withdrawn:
- **Phase C**: the cast-zone outline drops to 60 %, the existing "over an unlit spot" treatment.
- **Phase P**: the gap stays at its last index and does not track onto the source. In practice this happens only over the hand strip y 462–484.
- **Phase T**: the arrow head dims to 60 %, as over any unlit spot.

**Drag release** (the pointer is held, so nothing can be re-selected; a release never selects a new source):

| Phase | Release inside the zone / on a lit target | Release anywhere else |
|---|---|---|
| P | Inside the position zone → **place** at the current gap (or → Phase T for a Battlecry with targets) | **Cancel** — including over a hand card or the hero power |
| T | On a lit target → **confirm** | **Cancel** — including over another legal source |
| C | Inside the cast zone → **confirm**, including over a friendly token that can attack. The drag is a deliberate gesture carrying the card, and the dashed zone shows throughout | **Cancel** |

---

## 8. Data Requirements

| Data Element | Source System | Update Frequency | Who Owns It | Format | Null / Missing Handling |
|--------------|--------------|-----------------|-------------|--------|------------------------|
| `legal_commands()` | Match Rules via `MatchController` | **Once per session**, at pickup / select (cached — Card Drag-to-Play Implementation Notes; ≤ 2 ms) | Match Rules (C2) | `Command[]` (`play_card{hand_index, position, target_id}`, `attack{attacker_id, target_id}`, `use_hero_power{target_id}`, `end_turn`) | No entry for the source → no session (§6) |
| Board layout (token ids per slot, m per side), hero ids | `MatchViewState` | Event | Match UI | ids | — |
| Target names and stats for accessible names | `MatchQuery.entity(instance_id)` + `card_text(card_id)` | Per current-target change | Match Rules / Card Database | snapshot dict | Missing → accessible name falls back to "Target n of N" |
| Taunt / Stealth / Rush facts | **Not read by this flow** — they are already applied in `legal_commands()`; badges come from the view-state | — | Match Rules | — | The UI never re-derives F3 |
| `CommandResult.rejection{code, detail}` | Match Rules (`submit` return) and the player's `command_rejected` diagnostic event (U3.4a) | On a rejected submit | Match Rules | `{code, detail}` | Unknown code → key renders `??reject.<code>` + debug warning (match-ui Edge Cases) |
| Knobs: `CLICK_DRAG_PX` 8, `ARROW_LIFT_PX` 50, `REJECTION_TOOLTIP_S` 1.5, arrow line width | `match_ui.json` via `config("match_ui")` | Once at `_ready` | Match UI | numbers | Validated at boot |
| Settings: `reduce_motion`, `anim_speed`, `high_contrast_states` | Meta Progression (DD-X07) | `settings_changed` | Meta | DD-X07 record | Defaults |

> **Rule**: This screen must never write directly to any system listed above. All
> player actions fire events (see Section 9). Systems update their own data and
> notify the UI.

---

## 9. Events Fired

Commands go through `InputRouter` → `command_requested` → `MatchController.submit` (ADR-0009 / ADR-0008); local intents never reach the engine.

| Player Action | Event Fired | Payload | Receiver System | Notes |
|---------------|-------------|---------|-----------------|-------|
| Pick up / select a source | `select_source` (local intent) | `{kind: hand \| token \| hero \| hero_power, id, entered_by}` | Match UI `InputRouter` | No engine call; `legal_commands()` read once |
| Cycle / hover a target or gap | `cycle_target` (local) | `{index}` | Match UI | — |
| Confirm a minion / weapon / spell play | `play_card` | `{hand_index, position (minions), target_id \| null}` | Match Rules C6 → events `mana_spent`, `card_played` / `spell_cast`, `minion_summoned` / `weapon_equipped`, effects… | **Persistent state change** (mana, hand, board) |
| Confirm an attack | `attack` | `{attacker_id, target_id}` | Match Rules C8 → `attack_declared` … `attack_resolved` | **Persistent** (attacks used, damage) |
| Confirm the hero power | `use_hero_power` | `{target_id \| null}` | Match Rules C7 → `hero_power_used` … | **Persistent** (once per turn) |
| Cancel | none | — | — | Deliberate: a cancel is not an event (U7: "the engine is not called on cancel") |
| Rejected submit | (incoming) `command_rejected{diagnostic: true}` → `reject_shake` step + `feed.command_rejected` | `{command, code}` | Match UI | Debug / feed only |

A command issued while the queue is busy cannot come from this flow (sessions open only in `Idle`); U4.7's flush-then-submit still guards it.

---

## 10. Transitions & Animations

| Transition | Trigger | Direction / Type | Duration (ms) | Easing | Interruptible? | Skipped by Reduced Motion? |
|------------|---------|-----------------|--------------|--------|----------------|---------------------------|
| Pickup | Press on a source | Card lifts and attaches to the cursor; token / portrait lifts 4 px; button 2 px | 0 (no tween-in) | — | — | No (instant already) |
| Lights on | Session opens | Outlines, gaps, cast zone, arrow appear | 0 | — | — | No |
| Gap open / move | Pointer crosses an index boundary / `Tab` | Tokens slide to the m + 1 layout | 80 (*spec*, `stat_recolour`-class short move) | ease-out | Yes | Yes → instant |
| Arrow follow (drag / pointer) | Mouse move | Redrawn every frame | per frame | — | — | No |
| Arrow snap (key cycle) | `Tab` | Head moves to the next target | 80 | ease-out | Yes | Yes → instant (pattern) |
| Phase P → T | Gap chosen | Ghost appears in the gap; card returns to the parked position | 150 | ease-out | Yes | Card travel kept, ghost instant |
| Confirm | Release / click / `Enter` | Lights off; card travels / lunge (hud.md owns the playback) | 0 + playback | — | Skip-all | Positional travel kept |
| Cancel | `Esc` / RMB / unlit release | Source tweens back to its F1 slot / row slot | 150 | ease-out, no bounce | — | Kept (positional), no bounce anyway |
| Rejection | Rejected submit | Source shake 3 px; tooltip in 120 / out 80 after 1.5 s; related flash 2 frames | 200 / 1500 | linear (shake) / ease-out | — | Shake → 2-frame outline flash |

The targeting moment is a "brief spike, then release" (art bible §2) — no slow-motion, no zoom, no dim. Ease-out only, no bounce (Animation Standards).

---

## 11. Input Method Completeness Checklist

Platform Target is keyboard + mouse; **Touch** dropped (not supported); **Gamepad** kept unticked as the post-v1 mapping. Every untick has a §15 row.

**Keyboard**
- [ ] All interactive elements are reachable using Tab and arrow keys alone — **not met**: number keys / `A`+n / `H` / `Enter` open every session and `Tab` cycles every legal target and gap, but the player hero as an attacker has no key path. War is the only MVP hero (DD-H06) and weapons are its identity, so this fails the One-hand mode commitment (keyboard-only completes a run). §15 "Hero attack by key" (unticked in revision 1, review A1)
- [x] Tab order follows visual reading order (enemy row left → right, enemy hero, friendly row, friendly hero)
- [ ] Every action achievable by mouse is also achievable by keyboard (pick, place, target, confirm, cancel, "No target") — **not met** for the same reason: a hero weapon attack. §15 "Hero attack by key"
- [x] Focus is visible at all times (the 3 px ring / dashed gap is the session's focus indicator; the ring is drawn at `instant`)
- [x] Focus does not escape the screen while it is open (`Tab` is confined to the session's set)
- [x] Esc key closes or cancels (Escape / Cancel step 1) and does not quit the game

**Gamepad** (post-v1 — documented mapping only)
- [ ] All interactive elements reachable with D-Pad and left stick — §15 "Gamepad: target cycling"
- [ ] Face button mapping documented and consistent with platform conventions — `ui_accept` / `ui_cancel` (Focus Management); no dedicated "attack mode" button decided — §15 "Gamepad: face buttons"
- [x] No action requires analog stick precision that cannot be replicated with D-Pad (keyboard targeting is discrete)
- [ ] Trigger and bumper shortcuts documented if used — shoulders = `Tab` cycle (library default) — §15 "Gamepad: bumpers"
- [ ] Controller disconnection while screen is open is handled gracefully — §15 "Controller disconnection"

**Mouse**
- [x] Hover states defined for all interactive elements (ring / gap / dimmed head)
- [x] Clickable hit targets are at minimum 32x32px (tokens 90x126, portraits 120x160, hero power 48x48, chip 120x44, cast zone 678x284)
- [x] Right-click behavior defined (cancels the session; never opens the pause menu)
- [x] Scroll wheel behavior defined in all scrollable zones (none — no scrolling in a session)

**Touch (if applicable)** — not applicable.

---

## 12. Accessibility

Project-wide commitments are in `design/accessibility-requirements.md`. Ratios are art bible §4 figures; † were computed for this spec from the §4 hex values (WCAG 2.1 relative luminance).

**Text contrast requirements for this screen**:

| Text Element | Background Context | Required Ratio | Current Ratio | Pass? |
|--------------|-------------------|---------------|---------------|-------|
| Rejection tooltip (14 px) | `parchment` | 4.5:1 | `text_ink` 12.72 | [x] |
| `A` attacker badge numerals (14 px bold) | `ink` pill | 4.5:1 | `text_light` 14.33 | [x] |
| "No target" chip label (16 px) | `table_dark` | 4.5:1 | `text_light` 13.07 | [x] |
| Legal-target outline / ring (non-text) | `table_lit` / token `ink` frames | 3:1 | `state_target` 7.01 / 10.65 | [x] |
| Dashed slot / cast-zone outline (non-text) | `table_lit` | 3:1 | `state_actionable` 9.43 | [x] |
| Arrow (non-text) | `table_lit` / `table_dark` / tokens | 3:1 | 7.01 / 9.71 † / ≥ 7 | [x] |

**Colorblind-unsafe elements and mitigations**:

| Element | Colorblind Risk | Mitigation |
|---------|----------------|------------|
| Legal vs not-legal target | Amber outline | Shape first: the outline exists or not, the current target adds a 3 px ring, and the arrow points at it (art bible §4 targeting backup) — amber is unchanged by `high_contrast_states` |
| Legal gap vs cast zone vs target | Light vs amber | Different shapes: a dashed **slot** (90x126), a dashed **table rect**, a solid **outline + ring** on a token |
| Stealth enemy | Not outlined | Its Stealth badge glyph is always drawn — the player sees *why* it is not lit |
| Taunt-only highlighting | Amber on some tokens | Taunt tokens also carry the thicker Taunt frame (Board Token) and the "T" badge; the rejection copy names the rule if a race happens |
| Ghost token | 60 % alpha + dashed outline | Value and shape, not hue |
| Arrow head over an unlit spot | Head dims to 60 % | Also no ring anywhere — absence is the cue |

**Focus order** (session-local — the board's idle order is hud.md's):

1. Current target / position (ring or dashed gap) — `Tab` → next legal one in §7.1's cycle order; wraps.
2. "No target" chip — last stop, only under `optional` targeting.
3. `Esc` leaves the cycle (cancel); focus returns to the source, or the card now at the played index, or End Turn.

**Screen reader announcements for key state changes**: Not committed (AccessKit live regions NOT SOURCEABLE — accessibility-requirements Open Questions). Accessible names still required: "Target 2 of 3: <name>, <attack>/<health>[, Taunt]" (Click-to-Select pattern), "Position 3 of 4" for gaps, "Cast <card name>" for the cast zone, the rejection copy as the tooltip's `tooltip_text`.

**Motor**: every session can be completed with discrete presses only — click / click, or key / `Tab` / `Enter` — and no step requires a hold (accessibility-requirements Motor "Hold-to-press alternatives"); targets are whole tokens and portraits (≥ 90x126), so no aim precision is needed (Motor "Aim assist — N/A"); the only chord, `Shift+Tab`, is optional because the cycle wraps.

**Cognitive**: one question per phase (where, then what); nothing else on the table changes while a session is open; illegal choices are not offered, so the player never has to remember a rule to avoid a rejection; the rejection, if it ever happens, is in words (tooltip) **and** persists in the feed (accessibility-requirements Cognitive "Reading time": the 1.5 s tooltip is acceptable only because the feed line persists).

**Rejection copy** (`reject.<code>`, the `detail` fields are parameters when the engine provides them, otherwise the bracketed part is dropped) — final copy owned here per match-ui U12:

| Code | English copy | Reachable from the UI? |
|---|---|---|
| `NOT_ENOUGH_MANA` | "Not enough mana[ (needs {cost}, have {mana})]." | Race only (unaffordable cards are not lit) |
| `BOARD_FULL` | "Your board is full (7 minions)." | Race only |
| `MUST_ATTACK_TAUNT` | "A Taunt minion must be attacked first." | Race only |
| `TARGET_STEALTHED` | "Stealthed minions can't be targeted." | Race only |
| `ILLEGAL_TARGET` | "That can't be targeted." | Race only |
| `TARGET_REQUIRED` | "Choose a target for this card." | Race only |
| `NO_LEGAL_TARGET` | "There is no legal target for this card." | Race only |
| `INVALID_POSITION` | "A minion can't go there." | Race only |
| `CANNOT_ATTACK` | "This character can't attack right now." | Race only |
| `ATTACKER_FROZEN` | "Frozen characters can't attack." | Race only |
| `SUMMONING_SICK` | "This minion needs a turn before it can attack." | Race only |
| `RUSH_CANNOT_HIT_HERO` | "Rush minions can't attack heroes the turn they're played." | Race only |
| `HERO_POWER_USED` | "Your hero power is used this turn." | Race only |
| `NOT_YOUR_TURN` / `WRONG_PHASE` | "Wait for your turn." | Race only |
| `CHOICE_PENDING` | "Make your choice first." | Race only |
| `ENGINE_BUSY` | "Still resolving — try again." | Race only (concede's `concede_queued` is `pause-menu.md`'s) |
| `MATCH_ENDED` | "The match is over." | Race only |
| `INVALID_INDEX` / `INVALID_MASK` / `INVALID_CHOICE` | "That choice is no longer available." | UI bug only |

---

## 13. Localization Considerations

**General rules for this screen**:
- All text elements must tolerate a minimum of 40% expansion from English baseline
- RTL: the board and the cycle order do **not** mirror (board index 0 is a rules position — match-rules C1; positions left → right are table geometry); the tooltip right-aligns and anchors to the left of the cursor
- CJK: rejection copy is shorter; the tooltip shrinks to its content
- Every string is a key (`reject.<code>`, `targeting.no_target`, accessible-name templates) — no literals (match-ui U10)

| Text Element | English Baseline Length | Max Characters | Expansion Budget | RTL Behavior | Overflow Behavior | Risk |
|--------------|------------------------|----------------|-----------------|--------------|-------------------|------|
| Rejection copy (longest: `RUSH_CANNOT_HIT_HERO`) | 57 | 120 | 110 % | Right-align; tooltip left of cursor | Wraps inside 300 px (≤ 5 lines at 14 px); never truncates | Medium |
| `NOT_ENOUGH_MANA` with parameters | 42 | 80 | 90 % | Mirror parameter order per locale | Wraps | Low |
| "No target" chip | 9 | 16 | 75 % | Right-align | Chip grows to 160 px, then shrinks the label to 14 px | Medium (120 px chip) |
| `A` badges "1"–"7" | 1 | 1 | — | — | Locale digits | Low |
| Accessible names | ~40 | — | — | — | Not rendered | Low |

---

## 14. Acceptance Criteria

Every observable criterion names a match-ui U11 fixture (`tests/fixtures/match_ui/<name>.json`) launched per `.claude/docs/run-and-observe.md` (`… res://src/ui/match/match_view.tscn -- --fixture=<name> --anim-speed=instant [--pose=…]`), screenshot **retained** in `production/qa/evidence/`. *Proposed* fixtures / poses are listed in §15.

**Performance**
- [ ] Pickup within 16 ms; drag position update every frame (≤ 16 ms); release on a legal target → first visual step ≤ 50 ms; rejection → shake + tooltip ≤ 50 ms (match-ui Input Responsiveness; `scene_runner()` timing tests)
- [ ] `legal_commands()` is called exactly once per session (spy on the controller), not per frame or per hover

**Layout & Rendering**
- [ ] GIVEN `targeting_taunt --pose=drag:<attacker>`, WHEN captured, THEN the quadratic Bezier arrow (control point 50 px above the midpoint, triangular head) runs from the attacker's centre to screen centre, only the Taunt minions carry the 2 px `state_target` outline, and the boss hero is not outlined (match-ui O4)
- [ ] GIVEN `targeting_stealth --pose=drag:<attacker>`, WHEN captured, THEN the Stealth minion shows its badge and has no outline (O5)
- [ ] GIVEN `targeting_taunt --pose=select:<attacker>`, WHEN captured beside the `drag:` capture, THEN the arrow ends at the current target's centre with the 3 px ring on it, and the two captures differ only in the arrow's end point and the ring (O17 pair)
- [ ] GIVEN *proposed* `targeting_battlecry` with *proposed* `--pose=place:<card id>:2`, WHEN captured, THEN a 90x126 ghost token at 60 % with a dashed outline holds gap index 2 of the re-centred player row, the arrow starts from the ghost, and the legal Battlecry targets (friendly and enemy as the filter allows; enemy Stealth excluded) are outlined
- [ ] GIVEN *proposed* `targeting_spell_untargeted` with `--pose=select:<card id>`, WHEN captured, THEN the cast zone 301, 176, 678, 284 shows a dashed 2 px `state_actionable` outline, no arrow is drawn, and no token is outlined
- [ ] GIVEN *proposed* `targeting_rush` (a Rush minion played this turn), WHEN the attack session opens, THEN enemy minions are outlined and the enemy hero is not
- [ ] GIVEN any fixture above at 1280x720 windowed and at 3840x2160 fullscreen, THEN the session's arrow, rings, gaps, zones and badges are the 1280x720 layout scaled uniformly, and the §7.4 hit-tests resolve the same logical coordinates at both sizes (review A8)
- [ ] GIVEN `--pose=reject:MUST_ATTACK_TAUNT`, WHEN captured, THEN the tooltip reads "A Taunt minion must be attacked first." on `parchment` inside the viewport, the Taunt frames are flashed, and the feed ticker holds a `feed.command_rejected` line (O10)

**Input**
- [ ] GIVEN a playable minion card and a 3-token player row, WHEN dragged into the position zone over the gap between tokens 2 and 3 and released, THEN exactly one `play_card(hand_index, 2, null)` is submitted; WHEN released below y 484 instead, THEN nothing is submitted and the card tweens back in 150 ms
- [ ] GIVEN a playable card, WHEN a press-and-release moves < 8 px, THEN the view enters `KeyTargeting` (`entered_by = pointer`) and nothing is submitted; WHEN a second click lands on a lit gap / target / the cast zone, THEN exactly one command is submitted; WHEN `Esc`, RMB or a click on empty table follows instead, THEN nothing is submitted (match-ui L17)
- [ ] GIVEN `targeting_taunt` and keys `A`, `2`, `Tab`, `Enter` with no mouse input, THEN the token in **slot position 2 from the left** (rules board index 1, badge "2") attacks the second Taunt in cycle order and exactly one `attack` is submitted; GIVEN `A` then `Esc`, THEN nothing happens and the badges disappear
- [ ] GIVEN `targeting_taunt` with a summoning-sick token in slot 1, WHEN `A` is pressed, THEN slot 1 shows no badge; WHEN `1`, then `8`, then `0` are pressed, THEN nothing is selected and the badges stay visible (still armed); WHEN the badge number of a legal attacker follows, THEN that token's session opens (review A3)
- [ ] **Click precedence, Phase C** — GIVEN *proposed* `targeting_spell_untargeted` with the spell selected by click and a friendly token that can attack inside the cast zone: WHEN that token is clicked, THEN the session re-selects to that token's attack (nothing submitted, the spell settles); WHEN instead an empty spot inside the cast zone is clicked, THEN exactly one `play_card` is submitted; WHEN instead a spot outside the cast zone (not a source, not End Turn) is clicked, THEN nothing is submitted and the session cancels (review B1)
- [ ] **Click precedence, Phase C double-click** — GIVEN an untargeted spell or the untargeted hero power, WHEN its source is double-clicked from `Idle`, THEN the session is open and nothing is submitted; WHEN a further single click lands on the source after the OS double-click interval, THEN exactly one command is submitted (review A4)
- [ ] **Click precedence, Phase P** — GIVEN a minion selected by click and a 3-token player row in which every token can attack: WHEN a click lands on the row band at the x of the second token's resting position, THEN exactly one `play_card` is submitted at the gap under the pointer and no re-select occurs; WHEN instead a click lands on another playable hand card in the strip y 462–484, THEN the session re-selects to that card and nothing is submitted (review B1)
- [ ] **Click precedence, Phase T** — GIVEN *proposed* `targeting_spell_friendly` with a friendly token that is both a legal target and a legal attacker, WHEN it is clicked, THEN the spell is submitted on it (rank 1 wins); GIVEN a friendly attacker that is **not** a target, WHEN it is clicked, THEN the session re-selects to its attack and nothing is submitted
- [ ] **Drag release** — GIVEN an untargeted spell dragged into the cast zone and released over a friendly token that can attack, THEN exactly one `play_card` is submitted; GIVEN a minion dragged and released over another hand card, THEN nothing is submitted (cancel)
- [ ] GIVEN *proposed* `targeting_battlecry` with a Battlecry whose entries differ by position (headless test with a stub `legal_commands()`), WHEN position p is chosen, THEN only the targets of entries with `position == p` are outlined (review A5)
- [ ] `H` during the hero power's own session submits nothing and leaves the session open; `H` during a card session re-selects the hero power (review A4)
- [ ] GIVEN a targeted spell and key `1` then `Tab` ×N, THEN the ring visits every legal target exactly once per cycle in the order enemy row → enemy hero → friendly row → friendly hero, skipping Stealth enemies
- [ ] GIVEN a minion with a targeted Battlecry, WHEN a position is chosen and then `Esc` is pressed, THEN the whole play is cancelled: the ghost disappears, the gap closes, the card is back in its F1 slot and nothing was submitted
- [ ] GIVEN an untargeted hero power, WHEN the button is clicked once, THEN nothing is submitted and the cast zone lights; WHEN clicked again (or `Enter`), THEN exactly one `use_hero_power(null)` is submitted (match-ui U5 "a single click never plays" — see §15 on story MUI-005)
- [ ] GIVEN any open session, WHEN `Esc` is pressed, THEN the session cancels and the pause menu does **not** open; a second `Esc` opens it (Escape / Cancel steps 1 → 4)
- [ ] GIVEN a session open, WHEN End Turn is clicked, THEN nothing is submitted

**Events & Data**
- [ ] For every fixture above, every submitted command equals an entry of the session's cached `legal_commands()` snapshot (headless assertion); no command is ever built from a source / target outside the snapshot
- [ ] GIVEN a forced engine rejection (a `scene_runner()` race test), THEN the display after the tooltip clears equals the pre-session view-state (`sync_report()` empty) and the feed holds exactly one `feed.command_rejected` line (match-ui L9)
- [ ] O17 (headless): the keyboard path and the mouse path to the same command leave identical `MatchViewState` and `InputRouter` states (fixtures `turn1_player`, `targeting_taunt`)

**Accessibility**
- [ ] `targeting_taunt` and `targeting_stealth` drag captures pass Coblis (protanopia, deuteranopia, tritanopia) with `high_contrast_states` off and on: legal vs not-legal is identifiable by outline + ring + arrow alone (test plan row "Colour-as-only-indicator" lists `targeting_taunt`)
- [ ] GIVEN `reduce_motion`, THEN the key-cycle arrow snaps without tween and a rejection shows the 2-frame outline flash instead of the shake
- [ ] A mouse-only tester and a keyboard-only tester each complete: a minion play into a chosen position, a targeted spell on a friendly minion, an attack into a Taunt, a targeted hero power, **and a hero weapon attack** (accessibility-requirements Test Plan "Keyboard-only completion" / Motor "One-hand mode"). The keyboard-only hero weapon attack **cannot pass** until §15 "Hero attack by key" is resolved (review A1)
- [ ] GIVEN *proposed* `targeting_taunt_ts150` (`targeting_taunt` at `text_scale` 150 %), WHEN captured with `--pose=reject:MUST_ATTACK_TAUNT` and with `A` armed, THEN the tooltip text is 21 px and wraps inside 300 px within the viewport clamp, each `A` badge is a 28 px pill holding a 21 px numeral, unclipped, with no two badges overlapping; the "No target" chip (when present) widens to its label + 24 px (review A6)

**Localization**
- [ ] Every `reject.<code>` in §12 exists as a key; GIVEN a missing key, THEN `??reject.<code>` renders and a debug warning fires (match-ui Edge Cases)
- [ ] Pseudo-locale +40 %: the longest rejection copy wraps inside the 300 px tooltip with no clipping

---

## 15. Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Player journey map not yet created — author `design/player-journey.md` from `.claude/docs/templates/player-journey.md` so the "commitment" moment is sourced. | Jacob | Before Pre-Production gate | Open |
| **Two-phase minion play (position, then Battlecry target)**: `play_card` needs both `position` and `target_id`, but match-ui U5 only says "for a targeted card the arrow appears from the card"; it does not say how a position is chosen first. This spec adds Phase P → T with a ghost token, and one-step cancel of the whole play. Record the sequence in U5 / States (`KeyTargeting` sub-phase). **Story conflict** (revision 1, review A2): story MUI-008 (Ready) has the targeted card "follow the cursor" and only `Idle` / `Dragging` `InputRouter` states, while this spec parks targeted cards at top y 438 and turns a Battlecry drag release into Phase T, which needs `KeyTargeting` (MUI-017). GDD States also lists no `Dragging → KeyTargeting` transition. The story AC must change once the GDD records the sequence. | Match UI GDD owner + **producer** (MUI-008 AC) | Before MUI-008 implementation (MUI-008 is already Ready) | Proposed here — the targeting part of the MUI-008 AC is routed to the producer, not amended in this lane |
| **Pointer click precedence** (§7.4, revision 1, review B1): a ranked table per phase. Reversible outcomes outrank confirm, except a lit target in Phase T. Player-row tokens are not hit-tested in Phase P. Drag release never re-selects. Record it in the Click-to-Select / Keyboard Targeting pattern (rule 2 "a different legal source re-selects" needs the ranking) and in match-ui U5. | ux-designer (`interaction-patterns.md`) + Match UI GDD owner | `/ux-review targeting` round 2 | **Decided in this spec**; neither document edited |
| **Cast zone** rect 301, 176, 678, 284 and the position zone x 253–1027, y 310–484 are spec-owned; F6 has neither. Accept into F6 or leave to this spec. | Match UI GDD owner | Pre-Production | Proposed here (spec-owned) |
| **Untargeted hero power needs a confirm** (match-ui U5 click-to-select, Hero Power Button "after confirm per rule 2"), but story MUI-005's AC says one click on War's untargeted power "submits exactly one `use_hero_power`". The two disagree; this spec follows the GDD (review R2: does not block). | producer (story MUI-005 owner) + Match UI GDD owner | Before MUI-005 implementation | **MUI-005 AC amended** in the same lane (`prod(story)` commit, sprint-004 L7 round 1) to require the confirm click |
| **Hero attack by key**: the player hero can attack with a weapon (DD-M08, F3), but match-ui U5's key list has `A` + board index only, and `hud.md` Focus Order stop 4 says `Enter` on the player portrait does "Nothing". Proposal: `Enter` on the focused portrait opens the attack session when the hero can attack (no new key). An alternative that needs no `hud.md` change is an `A` badge "0" on the player portrait when the hero can attack, since `0` is otherwise unused after `A` (§7.1). | Match UI GDD owner + ux-designer (`hud.md`, APPROVED — not edited here) | **Before MUI-017 implementation** (the story is already Ready; the readiness deadline has passed) — high priority: War is the only MVP hero (DD-H06) | Open — conflict. §11's two keyboard rows are **unticked** (revision 1, review A1), and the §14 completion AC includes a hero weapon attack |
| **`A`-armed state in the Escape chain** (review A7): the armed state consumes `Esc` (§7.1) but Escape / Cancel step (1) lists sessions only. Add "`A` armed (attacker badges showing)" to step (1). | ux-designer (`interaction-patterns.md` Escape / Cancel) | `/ux-review targeting` round 2 | Proposed here |
| **Double-click guard** (§7.4 rank 2, review A4) uses the OS double-click flag instead of a new knob. If playtests show tremor users still committing by a slow double-click, add a `CONFIRM_REPEAT_GUARD_MS` knob to match-ui Tuning Knobs. | Match UI GDD owner | After the first accessibility playtest | Proposed here |
| **Target cycle order** (enemy row → enemy hero → friendly row → friendly hero → "No target") extends the Targeting Arrow pattern's enemy-only order; initial key position = right-most gap. Add both to the pattern. | ux-designer (`interaction-patterns.md`) | `/ux-review targeting` | Proposed here |
| **`optional` targeting** (card-effects C1 rule 1) has no UI in match-ui U5. This spec adds a "No target" chip; no v1 card uses `optional: true` (grep of the GDDs and `assets/data/` found none). | Match UI GDD owner + Card Effects GDD owner | When the first `optional` card is authored | Proposed here — chip specified, not required for v1 |
| `A` attacker badges (numerals over legal attackers while `A` waits) are new; add to the Click-to-Select pattern with the revision-1 mapping: slot position 1–7 from the left (rules index + 1), badges on legal attackers only, an unbadged number ignored while staying armed, and pill sizes 20 / 24 / 28 px. | ux-designer (`interaction-patterns.md`) | `/ux-review targeting` round 2 | Proposed here |
| Rejection copy (§12) is final English copy for all 21 match-rules C2 codes; `NOT_ENOUGH_MANA` uses `{cost}` / `{mana}` only if `rejection.detail` carries them — match-rules C2 does not define `detail`'s shape. | Match Rules GDD owner | Before story MUI-016 | Open |
| New fixtures / poses: `targeting_battlecry`, `targeting_spell_untargeted`, `targeting_spell_friendly` (a heal with friendly and enemy targets), `targeting_rush`, `targeting_hero_weapon`, `targeting_taunt_ts150` (settings variant, revision 1), and the pose `--pose=place:<instance_id>:<index>` (Phase T after a chosen position). Add to match-ui U11. | Match UI GDD owner / `/qa-plan` | Before MUI-008 implementation | Proposed |
| Stories MUI-008 / MUI-016 / MUI-017 cite `hud.md` and the patterns because this file did not exist; once APPROVED they should cite `design/ux/targeting.md`. | producer | Before `/dev-story` on each (the stories are already Ready) | Open |
| Gamepad: target cycling (§11) — shoulders / d-pad over the §7.1 cycle; not wired in v1. | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Gamepad: face buttons (§11) — `ui_accept` / `ui_cancel`; is an "attack mode" button (the `A` equivalent) wanted? | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Gamepad: bumpers (§11) — library default; confirm. | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Controller disconnection during a session (§11) — proposal: cancel the session, keyboard and mouse stay live. | ux-designer | Before gamepad work (post-v1) | Open |
| AccessKit live regions — inherited NOT SOURCEABLE item; no announcement is claimed. | ux-designer | Before first menu implementation | Open (inherited) |
