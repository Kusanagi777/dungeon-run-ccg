# HUD Design

> Authoring guidance: .claude/docs/templates/guidance/hud-design-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Design
> **Author**: Jacob + ux-designer (`/ux-design hud`, automation `guided`, workflow `standard`, density `balanced`; owner pre-approved the run — no `AskUserQuestion` used, recommended options taken and listed in the session report; no Agent tool — `art-director` / `ui-programmer` not spawned)
> **Last Updated**: 2026-11-03
> **Game**: Deckdelve (working title) — the match screen HUD. The match *is* the HUD: a tabletop drawn from the event log, with no world behind it.
> **Platform Targets**: PC (Windows primary, Linux for development and CI); 1280x720 logical, `canvas_items` stretch with `keep` aspect (DD-T05); input: mouse primary, keyboard complete; gamepad `Partial`, post-v1; touch none (`project.yaml` has no `platform` block — values from `.claude/docs/technical-preferences.md` Input & Platform as cited by `design/accessibility-requirements.md`)
> **Related GDDs**: `design/gdd/match-ui.md` (U1–U12, States, F1–F6, Visual/Audio, Game Feel, UI Requirements — the layout owner), `match-rules.md` § UI Requirements, `card-effects.md` § UI Requirements, `boss-ai.md` C8 + § UI Requirements, `heroes.md` H-2/H-3 + § UI Requirements, `treasures.md` § UI Requirements, `rng-event-log.md` § UI Requirements, `run-structure.md` R1 (`MatchConfig` fields) + § UI Requirements, `meta-progression.md` M9 (settings consumed), `card-database.md` § UI Requirements, `content.md` § UI Requirements (text limits), `run-ui.md` U5 (toast layer riding the `begin_match` handoff), `reward-draft.md` (no HUD element — confirmed headless for the match)
> **Related UX Specs**: `design/ux/interaction-patterns.md` (every control below is a pattern reference — this document does not re-specify hover, press, focus or timing); `design/accessibility-requirements.md` (tier); sibling match specs **not yet written** and owned by their own `/ux-design` runs: `hand.md`, `targeting.md`, `mulligan.md`, `choice-overlay.md`, `event-feed.md`, `match-end.md`, `pause-menu.md` (match-ui U12 and UI Requirements name them). Where this document touches one of those elements it places it on the grid and defers behaviour to that spec.
> **Accessibility Tier**: Standard, with reduce-motion, visual-for-every-sound and the high-contrast state set elevated (`design/accessibility-requirements.md` § This Project's Commitment). Screen reader, HUD repositioning and difficulty assists are Known Intentional Limitations there and are **not** promised here.
> **Style Reference**: `design/art/art-bible.md` §4 (tokens, typography, 150x210 card slots, 90x126 token, 120x160 portraits, state colours and their non-colour backups, "lit by state" buttons) and §7 (UI/HUD direction: placeholder art, letter glyphs, instant state changes in v1). §2 Mood: player turn = full `table_lit`, boss turn = light pulled toward the boss side.
> **Template**: HUD Design

> **Sources read for this document** (by section, coordination rule 6): match-ui U1–U12, States, F1–F6, Edge Cases, Tuning Knobs, Visual/Audio, Game Feel, UI Requirements; the UI Requirements section of every system GDD (13 of 13 — see §2.1 denominator); boss-ai C8, Tuning Knobs, UI Requirements; heroes H-1–H-3, Visual/Audio, UI Requirements, AC-16–18; run-structure R1, R6, R10, UI Requirements, Tuning Knobs; meta-progression M3, M8, M9, F6, UI Requirements; run-ui U2 (`match` row), U5, F3, Visual/Audio; art bible §2, §4, §7; accessibility-requirements Tier, Visual, Motor, Cognitive, Auditory, Per-Feature Matrix; interaction-patterns Overview, Catalog, all Game-Specific, Navigation and Feedback entries, Animation and Sound Standards, Gaps, Open Questions; game-concept Core Loop, Pillars, MDA.
> **Player journey**: `design/player-journey.md` does not exist. Player context below is derived from `game-concept.md` Core Loop ("Moment-to-Moment: read the board, spend mana, choose attacks, end turn, watch the boss act") and Flow State Design. Recorded in §13 Open Questions; the file is hand-authored from `.claude/docs/templates/player-journey.md`, no skill writes it.

> **Note — Scope boundary**: This document specifies everything on screen while a match is being played — from `Loading` to `Ended` in match-ui's view state machine. Overlays the player navigates explicitly (mulligan, Choice, pause menu, match-end banner) are placed here on the F6 grid and specified in their own `ux-spec.md` documents. The test used: if it is drawn by a match-ui presenter from `MatchViewState`, it belongs here.

---

## 1. HUD Philosophy

**What is this game's relationship with on-screen information?**

Deckdelve is a card game: there is no world for a HUD to obstruct, so the usual trade between immersion and information does not exist. The screen *is* the information. The stance is **information-dense tabletop** (closest framing: "all decision-relevant data always visible", as in a physical card table): every number the rules engine holds that a player needs to choose a legal command — both heroes' health, armour and weapons, mana, every card's effective cost, every token's stats and keywords, the deck counts, the boss's telegraphed intent, the held treasures — is on screen at rest, as a **number or a glyph, never only a colour** (art bible §4 state-colour rules a–c). Pillar 4 ("Readable, deterministic rules") makes the event feed a permanent HUD element, not a debug panel: it is the player's receipt. Pillar 3 ("Lose fast, learn fast") makes the boss intent banner and the legality highlights load-bearing — the player must be able to see the lesson, not infer it. What the HUD withholds is only what the rules withhold: hidden information (the boss hand, boss Discover options) is a count or a label, never a guess.

**Visibility principle** — when in doubt, show or hide?

**SHOW**, as a readout of engine state. The one restriction is match-ui U3's display-only rule: a presenter may show nothing the view-state cannot reproduce from events, so "show" never means "add a derived hint the engine did not emit". Where the GDDs make something on-demand (card rules text behind Card Inspect, the full feed behind the drawer, the hero power's text behind its tooltip) the trigger is **hover *and* focus**, never hover alone (art bible §7; interaction-patterns rule 3).

**The Rule of Necessity for this game**:

"A HUD element earns its place when it is the readout of a `MatchViewState` field the player needs to choose or judge a legal command, or the receipt of one the engine already executed (Pillar 4) — and it loses its place the moment it shows a number that is not in the projection (match-ui U3) or conveys a state by colour alone (art bible §4)."

---

## 2. Information Architecture

> Categorize EVERY piece of information the game generates — this is the master
> inventory of game information, not just HUD information.

### 2.1 Full Information Inventory

**Denominator.** `design/gdd/*.md` holds 16 files; `game-concept.md`, `systems-index.md` and `gdd-cross-review-2026-11-03.md` are not systems, leaving **13 system GDDs**. All 13 have a `## UI Requirements` section (grep `^#+ .*UI Requirements`, 13 matches) — **no GDD was excluded as headless by assumption**. Three contribute nothing to the match HUD and say so themselves: `reward-draft.md` (draft screen only), `run-ui.md` (shell screens; its one match-time obligation is the toast layer, U5/S-05) and `content.md` (text-length limits that constrain card frames). `card-database.md` supplies data, no element. The remaining nine feed the list below.

| # | Information | Source GDD (section) | Generated by |
|---|---|---|---|
| I1 | Turn side and number; current phase (`PlayerTurn.Main`, `Resolving`, `Choice`, boss turn, `Ended`) | match-rules UI Req; match-ui U3.5 | `turn_started`, `phase_changed` |
| I2 | Floor number, boss name, band | match-ui UI Req (top bar); run-structure R3 `MatchConfig` | `MatchConfig` (static per match) |
| I3 | Player hero health, armour, weapon attack/durability | match-rules UI Req; heroes UI Req | `damage_dealt`, `healed`, `armor_*`, `weapon_*` |
| I4 | Boss hero health, armour, weapon | same | same |
| I5 | Boss passive text | treasures / card-effects UI Req ("passive plate"); match-ui UI Req | `MatchConfig` boss def (static) |
| I6 | Boss hand count (never contents) | boss-ai UI Req; rng-event-log Interactions | `card_drawn`/`card_played` (boss side, count only) |
| I7 | Player mana `available / max`, temporary and locked crystals | match-rules UI Req | `mana_*`, `crystal_gained` |
| I8 | Boss mana `n/m` (compact) | match-rules UI Req ("boss shows a compact counter") | same, boss side |
| I9 | Hand: up to 10 cards, effective cost, playable / unaffordable, Insight tax, scaled spell damage on hover/focus | match-rules UI Req; heroes UI Req; card-effects UI Req | `card_drawn`, `card_played`, `enchantment_*`; `hand()` |
| I10 | Board tokens ×14: attack, health, keywords, Frozen / Stealth / Divine Shield / Taunt / Silenced / summoning-sick / Windfury / Poisonous / Lifesteal badges, can-attack, damaged / buffed numerals | match-rules UI Req; match-ui UI Req | `minion_*`, `frozen`/`thawed`, `silenced`, `stealth_lost`, `enchantment_*`, `auras_recomputed` |
| I11 | Legal summon positions and legal targets for the current source; Taunt-only / Stealth-excluded | match-rules UI Req; card-effects UI Req | `legal_commands()` (query, during targeting only) |
| I12 | Armed / queued effect sources (rim glow) | card-effects UI Req | `trigger_queued` / `trigger_resolved` |
| I13 | Aura attribution (which source buffs which stat) | card-effects UI Req | `auras_recomputed`; `entity().enchantments[]` |
| I14 | Counter values on a source (card-effects C5) | card-effects UI Req | `counter_changed` — **tooltip only in v1, no badge** (match-ui U3 table) |
| I15 | Once-per-turn spent state of an effect | card-effects UI Req ("dimmed trigger icon") | mark set / Start step — **no match-ui projection row exists** (see §13) |
| I16 | Deck counts (both); fatigue-next; burned card | match-rules UI Req | `card_drawn`, `card_added_to_deck`, `card_burned`, `fatigue_damage` |
| I17 | Hero power state `Ready / Blocked{reason} / Used`, name, cost, text; discounted cost | heroes UI Req; match-rules UI Req; treasures UI Req | `hero_power_used`, `hero_power_refreshed`; `hero_power_state()` |
| I18 | Held treasures in pick order; chip tooltip; treasure fired (flare + feed line) | treasures UI Req; card-effects UI Req | `MatchConfig.treasures`; `effect_resolved{host_kind: treasure}` |
| I19 | Boss intent: class, amount, target; `plan changed`; `lethal`; at the emitted `effective_mode` | boss-ai C8, UI Req | `ai_intent_shown`, `ai_intent_committed{kept, effective_mode}` |
| I20 | Boss action playback pacing; skip affordance | boss-ai UI Req; match-ui U6 | `turn_started{boss}`, F4 |
| I21 | Damage / heal / fatigue numbers; Divine Shield burst | match-ui Visual/Audio | `damage_dealt`, `healed`, `divine_shield_popped` |
| I22 | Rejection reason (`reject.<code>`) + related-control flash + feed line | match-rules UI Req; match-ui U3.4a, U5 | player `command_rejected` |
| I23 | Event feed: every event as a localised line, grouped by `cause_seq`; ticker + drawer | rng-event-log UI Req; match-rules UI Req; match-ui U10 | every event |
| I24 | Mulligan hand with keep/replace | match-rules UI Req; match-ui U8 | `mulligan_offered` |
| I25 | Discover / Choose-One options (player); "boss discovers…" (boss) | card-effects UI Req; match-ui U9 | `discover_offered` + `choice_requested` |
| I26 | Match result banner incl. `fault` copy | match-ui U9 | `match_ended`, `log_overflow`, `resolution_overflow` |
| I27 | Concede, settings quick-access | match-rules UI Req; match-ui U9 | pause menu |
| I28 | Unlock toast riding the `begin_match` handoff | run-ui U5, S-05 | Meta `unlock_granted` (persisting toast only; new toasts wait) |
| I29 | AI debug overlay (`ai_decision`) | boss-ai UI Req | debug builds / `--ai-debug` only |
| I30 | Player settings consumed: `anim_speed`, `reduce_motion`, `text_scale`, `high_contrast_states`, `action_delay_ms`, volumes | meta M9 / DD-X07 | `settings_changed` — not shown; they change how everything else renders |

### 2.2 Categorization

| Information Type | Always Show | Contextual (show when relevant) | On Demand (menu/button) | Hidden (environmental / diegetic) | Reasoning |
|-----------------|-------------|--------------------------------|------------------------|----------------------------------|-----------|
| I1 Turn / phase | [x] | [ ] | [ ] | [ ] | Which side acts decides whether any control is live; a turn banner (boss turn only) is the transition cue, the top-bar text is the resting readout |
| I2 Floor / boss name / band | [x] | [ ] | [ ] | [ ] | Pillar 3's "which puzzle am I solving"; static text costs nothing |
| I3 / I4 Hero health, armour, weapon | [x] | [ ] | [ ] | [ ] | Lethal math is the core decision every turn (24 px numerals, art bible §4) |
| I5 Boss passive text | [x] (plate, 14 px) | [ ] | [x] full text via Card Inspect text variant on hover/focus | [ ] | Pillar 2: the passive is the puzzle; the plate is always visible, the full wording one focus away |
| I6 Boss hand count | [x] | [ ] | [ ] | [ ] | Symmetric with what the AI sees (boss-ai UI Req) |
| I7 Player mana | [x] | [ ] | [ ] | [ ] | Every play decision |
| I8 Boss mana | [x] (compact) | [ ] | [ ] | [ ] | Reading the boss's next turn (with the intent banner) |
| I9 Hand | [x] | [ ] | [ ] | [ ] | The player's options; text at 12 px with Card Inspect as the reading path (`design/ux/hand.md`) |
| I10 Board tokens | [x] | [ ] | [ ] | [ ] | Stats and badges always; full card via Card Inspect |
| I11 Legal positions / targets | [ ] | [x] during `Dragging` / `KeyTargeting` only | [ ] | [ ] | Pre-release legality (interaction-patterns rule 2); showing it at rest would light the whole board |
| I12 Armed sources | [ ] | [x] while `trigger_queued` | [ ] | [ ] | Transient by definition |
| I13 Aura attribution | [ ] | [ ] | [x] tooltip on a buffed stat, hover or focus | [ ] | Needed only when a number surprises the player |
| I14 Counter values | [ ] | [ ] | [x] source's Card Inspect / tooltip | [ ] | match-ui U3: no badge in v1 — a HUD badge would be a number the projection does hold, but the GDD defers it |
| I15 Once-per-turn spent | [ ] | [x] on the card while spent (card-effects) | [ ] | [ ] | **Unprojected** — listed so it is not lost (§13) |
| I16 Deck counts / fatigue / burn | [x] count; fatigue label when deck empty | [x] burn flash 0.4 s | [ ] | [ ] | Deck count is a planning number; fatigue is a threat readout; the burn is a receipt |
| I17 Hero power | [x] state | [ ] | [x] name / cost / text / Blocked reason on hover or focus | [ ] | 48x48 button is always there; its text is one focus away |
| I18 Treasures | [x] chips when ≥ 1 held | [x] flare on fire | [x] tooltip | [ ] | Rule-benders the player must remember (Pillar 1); tray hidden when none (Empty State "deliberate absence") |
| I19 Boss intent | [x] whenever `effective_mode ≠ hidden` | [x] "plan changed" for `plan_changed_s` | [x] full sentence tooltip | [ ] | Pillar 3's telegraph; the "?" plate under `hidden` keeps the absence visible |
| I20 Playback pacing / skip hint | [ ] | [x] boss turn; hint after 1 s | [ ] | [ ] | Contextual by nature |
| I21 Floating numbers | [ ] | [x] per event, 0.4 s | [ ] | [ ] | Supplementary — the stamp and the feed line carry the same number (Floating Number pattern) |
| I22 Rejection | [ ] | [x] 1.5 s + feed line | [ ] | [ ] | Specific and brief; persisted in the feed (accessibility "Reading time") |
| I23 Event feed | [x] 3-line ticker | [ ] | [x] 200-line drawer on `L` / button | [ ] | Pillar 4: lit in every state including defeat (art bible §2) |
| I24 Mulligan | [ ] | [x] `Mulligan` state only | [ ] | [ ] | Own spec `mulligan.md` |
| I25 Choice | [ ] | [x] `ChoiceOpen`; boss side = 0.4 s label | [ ] | [ ] | Own spec `choice-overlay.md`; boss options are hidden information |
| I26 End banner | [ ] | [x] `Ended` | [ ] | [ ] | Own spec `match-end.md`; `fault` variant is not a defeat |
| I27 Concede / settings | [ ] | [ ] | [x] pause menu (`Esc`, top-bar button) | [ ] | Own spec `pause-menu.md`; destructive → Confirmation Dialog |
| I28 Unlock toast | [ ] | [x] only a toast already visible at `begin_match` persists; nothing new starts during a match (run-ui U5) | [ ] | [ ] | The summary repeats every unlock |
| I29 AI debug overlay | [ ] | [ ] | [x] `--ai-debug` / debug builds | [ ] | Developer tool; never in a release export |
| I30 Settings | [ ] | [ ] | [ ] | [x] applied, not displayed | Owned by Meta; edited in `settings.md` / `pause-menu.md` |

**Conflict check against §1.** The Always Show set has 14 rows. That is consistent with the stated philosophy (the table is the game); the philosophy's own limit is the display-only rule, and every Always Show row is a projection field. Nothing is demoted.

---

## 3. Layout Zones

The grid is **match-ui F6** — "zones the UX specs refine but may not re-partition". Every rectangle below is F6's (`x, y, w, h`, logical px at 1280x720) or is derived from it as stated; the two rectangles F6 does not give (the top bar's internal controls and the boss compact mana counter) are marked *spec-owned* and raised in §13.

### 3.1 Zone Diagram

```
 x:0        160       320       480       640       800       960      1120     1280
 y:0 ┌───────────────────────────────────────────────────────────────────────────────┐
     │ TOP BAR 0,0,1280,40  [Turn: You · 4]        Floor 4 · Rat King   [L feed][≡] │
  40 ├───────────────────────────────────────────────────────────────────────────────┤
  48 │ {feed ticker 24,48,400,42}           {toast anchor 540,48,400,48 — spec}      │
  52 │                                                   [BOSS INTENT 980,52,276,36] │
  96 │ ┌boss ┐                                                      ┌──boss portrait┐│
     │ │deck │                                                      │ 1136,96,120,160││
     │ │24,96│                                                      │ health 24 px   ││
 176 │ └76x106┘  ┌─────────── BOSS ROW 301,176,678,126 ────────────┐│ passive plate  ││
     │           │ [t][t][t][t][t][t][t]  7 × 90x126, 8 px gaps     ││                ││
 256 │           │                                                  │└────────────────┘│
 262 │           │                                                  │ hand: ▮▮▮▮ 4 · 3/5│
 302 │           └──────────────────────────────────────────────────┘ (1136,262,120,28)│
 296 │                                                              [END TURN 1116,296]│
 334 │ ┌player┐  ┌────────── PLAYER ROW 301,334,678,126 ───────────┐  (140x44)        │
     │ │portr.│  │ [t][t][t][t][t][t][t]                            │                  │
     │ │24,334│  │                                                  │                  │
 390 │ │120x160│[HP]48x48 (152,390)                                  │                  │
 446 │ │      │[W ]48x48 (152,446)                                  │                  │
 460 │ └──────┘  └──────────────────────────────────────────────────┘                  │
 462 │  tray                   HAND ZONE 240,462,800,258                               │
 502 │ [T][T][T]        card centres x 315–965, centre card top y 462                  │
 540 │ 24,502,136,40     ╱╱╱╱  fan of ≤ 10 × 150x210, rot −15°…+15° (F1)  ╲╲╲╲ ┌deck ┐ │
 652 │                                                                     │1180,│n/m │
 680 │                                                                     │540  │◯◯◯◯◯│
 720 └─────────────────────────────────────────────────────────────────────┴─────┴─────┘
                                                             mana 1060,652,196,56 ─┘
```

Overlays on the same grid (own specs): Choice / Mulligan row `278, 202, 723, 315` (3 × 225x315, 24 px gaps); end banner `340, 260, 600, 200`; pause menu `440, 160, 400, 400`; feed drawer `0, 40, 300, 290` (never over the player portrait at y 334).

> The template's "keep the centre 40 % clear" rule is inverted here on purpose: the centre zone (x 384–896, y 216–504) holds the two token rows and the top of the hand — the **content**. No chrome (bar, buttons, piles, banners, mana) enters it; the only transient visitors are the targeting arrow, legal-target rings, floating numbers and the summon gap, all of which belong to the content.

### 3.2 Zone Specification Table

| Zone Name | Screen Position (x, y, w, h) | Safe Zone Compliant | Primary Elements | Max Simultaneous Elements | Notes |
|-----------|----------------|---------------------|-----------------|--------------------------|-------|
| Top bar | 0, 0, 1280, 40 | Yes — PC, no safe zone (letterboxed at other aspects) | Turn indicator, floor/boss name, feed toggle, menu button | 4 | `bg_edge`; internal layout is *spec-owned* (§4.2 Top bar; §13) |
| Feed ticker / drawer | 24, 48, 400, 42 / 0, 40, 300, 290 | Yes | Event Feed (ticker; drawer when open) | 1 | Drawer never covers the player portrait; `event-feed.md` |
| Toast anchor (match) | 540, 48, 400, 48 — *spec-owned* | Yes | One persisting unlock toast (run-ui U5, S-05) | 1 | The Toast pattern says "below the top bar, right; never over the boss intent banner"; the right side is the banner (980–1256) and the boss portrait, so the free band between the ticker (ends x 424) and the banner (starts x 980) is used |
| Boss deck pile | 24, 96, 76, 106 | Yes | Deck count (0.5x card back) | 1 | |
| Boss intent banner | 980, 52, 276, 36 | Yes | Boss Intent Banner | 1 (+ "plan changed" label state) | Grows **left** at `text_scale` > 100 % (pattern) — the free band to its left is 424–980 |
| Boss portrait | 1136, 96, 120, 160 | Yes | Hero Portrait & Health Stamp (boss), passive plate | 1 | Band colour |
| Boss hand / mana strip | 1136, 262, 120, 28 | Yes | Boss hand count; boss compact mana counter (*spec-owned placement*, §13) | 2 | F6 names the strip for the hand count only |
| Boss row | 301, 176, 678, 126 | Yes | 7 Board Tokens | 7 | Centre line y 318 is the mid-point between the rows (F6) |
| End Turn | 1116, 296, 140, 44 | Yes | End Turn Button | 1 | Sits in the 32 px gap between the rows' outer envelope and the right edge |
| Player row | 301, 334, 678, 126 | Yes | 7 Board Tokens, summon gap during targeting | 7 (+1 gap) | |
| Player portrait | 24, 334, 120, 160 | Yes | Hero Portrait & Health Stamp (player) | 1 | Hero primary |
| Hero power / weapon slot | 152, 390, 48, 48 / 152, 446, 48, 48 | Yes | Hero Power Button; weapon slot (display) | 2 | |
| Hand zone | 240, 462, 800, 258 | Yes | Card (Hand) ×≤10 (F1), Card Inspect preview (F2) | 10 (+1 preview) | `design/ux/hand.md`; the rotated envelope reaches x 188 / 1092 for y ≥ 474, which is why the tray stops at x 162 and the mana bar starts at x 1060 |
| Treasure tray | 24, 502, 136, 40 (hit 22, 500, 140, 44) | Yes | Treasure Chip ×≤3 (`MAX_TREASURES_HELD`) | 3 | Hidden when none held; chips never extend — the tray would move (F6) |
| Player deck pile | 1180, 540, 76, 106 | Yes | Deck count, "Fatigue: next N", burn flash | 1 | Moved up 20 px in F6 to clear the two-row mana bar |
| Mana bar | 1060, 652, 196, 56 | Yes | Mana Bar ("n/m" 1060, 652, 196, 20; ten crystals 1060, 680, 196, 28) | 1 | Interaction-patterns' Mana Bar entry still quotes the superseded `1000, 676, 256, 32` — F6 wins (§13) |

**Safe zone margins by platform**:

| Platform | Top | Bottom | Left | Right | Notes |
|----------|-----|--------|------|-------|-------|
| PC — windowed 1280x720 (reference) | 0 % | 0 % | 0 % | 0 % | F6's own margins: 24 px at left (ticker, piles, portrait, tray), 24 px at right (every right-aligned element ends at x 1256), 4 px at the bottom (hand baseline 696 + rotated corner ≤ 715.4) |
| PC — fullscreen, any aspect up to 3840x2160 | 0 % | 0 % | 0 % | 0 % | `canvas_items` + `keep`: the 1280x720 canvas scales uniformly and letterboxes; no element moves (match-ui Edge Cases "window resized"); run-ui AC-31 retains 2160p screenshots |
| Console / Steam Deck / mobile | — | — | — | — | Not targets (accessibility-requirements Platform table) |

---

## 4. HUD Element Specifications

### 4.1 Element Overview Table

| Element Name | Zone | Always Visible | Visibility Trigger | Data Source | Update Frequency | Max Size (% screen W) | Min Readable Size | Overlap Priority | Accessibility Alt |
|-------------|------|---------------|-------------------|-------------|-----------------|----------------------|------------------|-----------------|------------------|
| Top bar — turn indicator | Top bar | Yes | N/A | `MatchViewState.phase/turn/active_side` | `turn_started`, `phase_changed` | 16 % | 16 px | 3 | Text ("Your turn · 4" / "Boss turn · 4"); the turn banner duplicates the change |
| Top bar — floor / boss name | Top bar | Yes | N/A | `MatchConfig` (floor, boss id → name via Card Database) | Static | 30 % | 16 px | 4 | Text |
| Top bar — feed toggle, menu button | Top bar | Yes | N/A | — | — | 2 × 3.4 % | 44x44 hit | 2 | `L` / `Esc` keyboard equivalents; focus stops 7–8 |
| Event feed ticker | Feed | Yes | N/A | `feed_lines[]` | Every event | 31 % | 13 px × `text_scale` | 5 | Drawer (Scroll Container); every line is text |
| Boss deck pile | Boss deck | Yes | N/A | `deck_count` (boss) | `card_drawn` etc. | 6 % | 16 px count | 6 | Numeral |
| Boss intent banner | Intent | When `effective_mode ≠ hidden` | `ai_intent_shown` | `intent{key, amount, target_id, kept, effective_mode}` | `ai_intent_shown`, `ai_intent_committed` | 21.6 % | 16 px label | 2 | Icon + word + numeral + reticle; "?" plate when hidden; tooltip sentence on focus |
| Boss portrait + health stamp | Boss portrait | Yes | N/A | hero `{health, armor, weapon}` (boss) | `damage_dealt`, `healed`, `armor_*`, `weapon_*` | 9.4 % | 24 px health | 1 | Numerals; crack / shield glyphs; focusable, tooltip |
| Boss passive plate | Boss portrait (lower 48 px of the panel) | Yes | N/A | `MatchConfig` boss `passive` text | Static | 9.4 % | 14 px | 1 | Card Inspect text variant on hover / focus |
| Boss hand count | Hand/mana strip (left 60 px) | Yes | N/A | boss hand count | `card_drawn`, `card_played` (boss) | 4.7 % | 14 px | 4 | Numeral + card-back glyphs |
| Boss mana counter | Hand/mana strip (right 60 px) — *spec-owned* | Yes | N/A | `mana{available, max}` (boss) | `mana_*` (boss) | 4.7 % | 14 px | 4 | "n/m" numeral |
| Board tokens (boss row) | Boss row | Yes (when present) | `minion_summoned` | `board[]` (boss) | Every token event | 7 × 7 % | 14 px numerals, 12 px badges | 1 | Numerals + glyph badges; Card Inspect on focus; `targeting.md` for rings |
| End Turn button | End Turn | Yes | N/A | `phase`, queue idle, arm timer, `legal_commands()` | `phase_changed`; every event | 10.9 % | 16 px | 2 | Label value + outline; `Space`/`Enter` armed |
| Board tokens (player row) + summon gap | Player row | Yes (when present) | `minion_summoned`; gap during targeting | `board[]` (player); `legal_commands()` | Every token event | 7 × 7 % | as above | 1 | as above; can-attack = outline + lift behaviour |
| Player portrait + health stamp | Player portrait | Yes | N/A | hero `{health, armor, weapon}` (player) | as boss | 9.4 % | 24 px | 1 | Numerals; lethal-range "!" glyph |
| Hero power button | Hero power | Yes | N/A | `power_state`; `hero_power_state()` for the reason | `hero_power_used`, `hero_power_refreshed`, Start step | 3.75 % | 48x48 | 2 | Tooltip (name, cost, text, Blocked reason) on hover **or focus**; `H` |
| Weapon slot | Weapon slot | Yes (empty frame when no weapon) | `weapon_equipped` | hero `weapon{attack, durability}` | `weapon_*` | 3.75 % | 14 px stamps | 3 | Numerals; sword / shield glyphs |
| Hand fan | Hand | Yes | N/A | `hand[]`, `effective_cost`, `playable` | `card_drawn`, `card_played`, `card_burned`, `enchantment_*`; `hand()` | 62.5 % (zone) | 20 px stamps, 12 px text (Card Inspect) | 1 | `design/ux/hand.md` |
| Treasure tray | Tray | When ≥ 1 held | `MatchConfig.treasures` | treasure ids in pick order | Static per match; flare per `effect_resolved{host_kind: treasure}` | 10.6 % | 40 px visual, 44x44 hit | 3 | Tooltip on hover / focus; letter glyph |
| Player deck pile | Player deck | Yes | N/A | `deck_count`, `fatigue_next` | `card_drawn`, `card_added_to_deck`, `card_burned`, `fatigue_damage` | 6 % | 16 px | 3 | Numerals; "Fatigue: next N" text; burned card shown face up 0.4 s |
| Mana bar | Mana | Yes | N/A | `mana{available, max, temporary}` + locked | `mana_*`, `crystal_gained` | 15.3 % | 16 px "n/m" | 2 | "n/m" numeral is primary; four crystal shapes |
| Turn banner | Over the boss row (centre, 400x48 at 440, 215 — *spec-owned*, inside the row's own rect so no zone is added) | No | `turn_started{side: boss}` only | `turn` | 0.4 s per boss turn | 31 % | 16 px | transient | Text "Boss turn 4" in band colour frame; also in the top bar |
| Skip hint | Under the boss portrait: 1136, 262 strip is occupied → text at 980, 92, 276, 20 (*spec-owned*, under the intent banner) | No | 1 s into `BossTurn` or any `Playback` ≥ 1 s | queue busy | per playback | 21.6 % | 13 px `text_muted` | transient | Static text (no pulse > 1 Hz; none under `reduce_motion`) |
| Floating numbers | Over the target token / portrait | No | `damage_dealt`, `healed`, `fatigue_damage`, `divine_shield_popped` | event payload | 0.4 s each | ≤ 5 % each | 20 px bold | transient | Sign + stamp numeral + feed line |
| Targeting arrow + legal rings | Content | No | `Dragging` / `KeyTargeting` | `legal_commands()` | per frame | — | 3 px ring | transient | `design/ux/targeting.md` |
| Rejection tooltip | At cursor / above the source | No | player `command_rejected` | `{command, code}` | 1.5 s | 23 % (300 px) | 14 px | transient | Feed line persists; `design/ux/targeting.md` |
| Match toast (persisting unlock) | Toast anchor | No | Visible at `begin_match` | run-ui toast layer | until `t_toast` elapses | 31 % | 16 px | 2 | Not match data; `toast.md` |
| AI debug overlay | Left half, over the ticker and boss deck (0, 40, 400, 300 — *spec-owned*, debug only) | No | `--ai-debug` | `ai_decision` | per decision | 31 % | monospace 13 px | dev | Never in a release export |

### 4.2 Element Detail Blocks

Each block names the pattern that owns its behaviour; the block adds only placement on F6, data binding and anything the pattern leaves to the screen.

---

**Top bar** (pattern: Button (Secondary) ×2, Standard Shortcuts; the layout is this spec's — the pattern library's Gaps table assigns "Top bar" to `/ux-design hud`)

- Visual description: `bg_edge` strip 0, 0, 1280, 40. Left: turn indicator at x 24, 16 px bold `text_light`, "Your turn · 4" / "Boss turn · 4" (locale keys `hud.turn.player` / `hud.turn.boss` with `{n}`), followed by the phase word in `text_muted` when not `Main` ("· resolving", "· choice"). Centre: floor and boss name centred on x 640, 16 px `text_light`, "Floor 4 of 8 · Rat King" (`hud.floor` with `{n}`, `{F}`, boss name via Card Database). Right: two 44x32 buttons at (1160, 4) and (1212, 4) — feed toggle (letter glyph "L" in v1, label `hud.feed`) and menu (glyph "≡", label `hud.menu`) — whose **hit rects are 44x44 at y 0–44**: the bar is 40 px (F6) and the 4 px below it (y 40–48) are free before the ticker, so the 44 px minimum target (accessibility-requirements Motor) is met without touching F6. Buttons are `table_dark` with `text_light` glyphs, no outline (Secondary); the right edge x 1256 aligns with the banner, portrait, End Turn and mana bar.
- Data displayed: `phase`, `active_side`, `turn` (view-state); `MatchConfig.floor`, `floors_per_run`, `boss_id`.
- Update behavior: text swaps instantly on `turn_started` / `phase_changed` (no step; art bible §7 "instant state changes"); the turn **banner** (below) is the animated cue.
- Urgency states: none. The bar never changes colour.
- Interaction: the two buttons (click; `L` and `Esc` are the key paths — Escape / Cancel chain step 4 opens the menu). The text is not interactive.
- Player customization: none; scales with `text_scale` — the centre text ellipsises the boss name before it reaches x 1150 (keeps clear of the buttons).

---

**Boss intent banner** (pattern: Boss Intent Banner)

- Visual description: 980, 52, 276, 36 `table_dark` plate, 4 px radius. Left 36 px: intent icon (letter glyph per `intent_key` in v1: `L` lethal, `F` attack face, `M` attack minion, `B` big minion, `D` develop, `R` removal, `A` AoE, `H` heal, `P` hero power, `W` weapon, `—` pass). Then the label 16 px `text_light` (`intent.<key>` with `{amount}`); amount and target only when `effective_mode = full`. When `target_id` is set, a reticle glyph (3 px `state_target` ring, shape-first) is drawn on the named token in the player row or on the player portrait. Under `hidden` (boss-ai C8.4: legal only for a concealment-passive boss, or the player's own `telegraph_mode = off`): a "?" plate of the same size so the absence is deliberate. Under `class_only` ≡ `brief`: icon + label, no amount, no reticle.
- Data displayed: `intent{key, amount, target_id, kept, effective_mode}` exactly as emitted (DD-X03 — the HUD never re-applies `telegraph_mode`).
- Update behavior: `intent_show` 0.3 s on `ai_intent_shown`; commit beat `intent_banner_s` (0.3 s, boss-ai) brightens the plate on `ai_intent_committed{kept: true}`; `kept: false` crossfades to "Plan changed" (`intent.plan_changed`) for `plan_changed_s` (1.2 s, boss-ai) then shows the new intent. `lethal`: label in `state_danger` on `ink` pill + the word "Lethal" + one pulse (static under `reduce_motion`). Skipping a boss turn still leaves the banner's final state (match-ui U6.4 — view-state, not animation).
- Urgency states: `lethal` only, as above; backup is the word and the icon (accessibility audit row "Boss intent `lethal`").
- Interaction: focusable in `Idle` (stop 9); tooltip with the full sentence (`intent.<key>.long`) on hover or focus. Not clickable.
- Player customization: `telegraph_mode` (settings — consumed upstream by Boss AI, DD-X03); `text_scale` grows the banner leftward into the free band (max x 432, i.e. up to 824 px wide), never down into the portrait.

---

**Hero portraits — player and boss** (pattern: Hero Portrait & Health Stamp)

- Visual description: 120x160 panels — player 24, 334 in hero primary (`#9B2F23` War, `#355E3B` Decay, `#2C4F8A` Knowledge); boss 1136, 96 in band colour (`#6B5B3C` / `#7A4A3A` / `#4E4660`). Top 112 px: placeholder art (hero initial 24 px bold `text_light`, art bible §3/§5 v1). Bottom-right corner: health stamp — 24 px bold `text_light` on an `ink` circle (40 px) overlapping the corner like a card stamp. Armour: `ink` pill with shield glyph + number left of the health stamp, present only while armour > 0. Boss panel's lower 48 px is the **passive plate**: `table_dark` strip with the passive text at 14 px `text_light`, ellipsised to two lines; Card Inspect (text variant) opens the full text on hover or focus. Weapon (both): see Weapon slot; the boss's weapon stamps draw inside its panel's lower-left corner (26 px circles) because F6 gives the boss no weapon slot.
- Data displayed: `health`, `armor`, `weapon{attack, durability}`; boss `passive` text; hero / boss name in the tooltip.
- Update behavior: per the pattern — numeral turns `state_danger` with a crack glyph while below max, Floating Number `−n` / `+n`, 2-frame shake dropped under `reduce_motion`; on `match_ended` the **winning** portrait saturates to its primary over 0.4 s (the art bible's one fill exception); never on `fault`.
- Urgency states: player in lethal range (boss intent `lethal`) → health stamp ring `state_danger` + "!" glyph; boss at ≤ 0 in a `both_dead` result is drawn like any defeat.
- Interaction: both focusable (stops 4 and 11) — the tooltip reads name, health / armour numerically, weapon, passive; both are legal targets with the 3 px ring during targeting (`targeting.md`).
- Player customization: none; the tooltip and plate scale with `text_scale` (plate grows to three lines at 150 %, pushing nothing — it overlays the art area).

---

**Boss hand count and boss mana counter** (pattern: Hero Portrait & Health Stamp "Boss hand count" row; Mana Bar "compact counter")

- Visual description: the F6 strip 1136, 262, 120, 28 split in two: left 60 px — card-back glyph ×n up to 5, then "n" numeral 14 px `text_light` (`hud.boss_hand`); right 60 px — "n/m" 14 px bold `text_light` with a 12 px steel-blue (`#3B5A82`) crystal glyph (`hud.boss_mana`). **F6 names this strip for the hand count only; the boss compact mana counter that match-rules and match-ui UI Requirements both list has no F6 rect** — placing it here is this spec's decision, raised for match-ui F6 in §13.
- Data displayed: boss hand count; boss `mana{available, max}`.
- Update behavior: instant on the event (no step; match-ui U3 `mana_*` → none).
- Urgency states: none.
- Interaction: display-only; its content is also in the boss portrait tooltip (stop 11), so keyboard users read it there.
- Player customization: `text_scale` — at 150 % the two readouts stack into two 14 px lines within a 56 px-tall strip (y 262–318), which stays above the End Turn button's top edge at y 296 only at x ≥ 1136, i.e. no overlap (End Turn spans x 1116–1256 and y 296–340 — the strip's right half x 1196–1256 would collide: at 150 % the mana half moves **inside the portrait panel's bottom-right corner** instead, see §10.2).

---

**Board rows and tokens** (pattern: Board Token; Card Inspect; Targeting Arrow for rings)

- Visual description: 7 slots per row, 90x126 tokens at x = 301 + i·98 (i = 0..6; 90 px + 8 px gap, 678 px total), boss row y 176, player row y 334. Tokens re-space to stay centred when fewer than 7 (`minion_summoned` "row re-spaces", `gap_close` after deaths). Token frame colour: hero primary (player) / band colour (boss) / neutral `#6F655A`; art box placeholder with type initial; attack stamp centre (15, 111), health stamp centre (75, 111), 26 px circles, 14 px numerals; keyword badge row of 12 px letter glyphs along the art-box bottom (T, DS, S, W, P, L, F, Si, z/✓). No name band, no text (art bible §4).
- Data displayed: `board[]` snapshot per token — `attack`, `health`, `max_health`, `keywords[]`, `flags{}`; enchantment deltas via Card Inspect / aura tooltip.
- Update behavior: match-ui U3 steps — grow-in 0.2 s, death group 0.3 s then gap-close 0.2 s, badge add/remove 0.15 s, stat recolour 0.15 s, lunge 0.35 s (attacker), rim glow on/off 0.15 s for armed sources (I12).
- Urgency states: damaged numeral `state_danger` + crack glyph while below max; buffed `state_buff` + up-arrow; Frozen `state_freeze` outline + snowflake; Silenced grey art box + slash — all glyph-backed (accessibility audit).
- Interaction: player tokens with `can_attack` carry the `state_actionable` outline and start a Targeting session on press / click / `A`+index / `Enter` when focused; every token is a focus stop in `Idle` (stops 2 and 10, left → right) and opens Card Inspect above the row (boss row: below). Legal-target rings, summon gap and Stealth / Taunt rules are `targeting.md`'s.
- Player customization: none; tokens do not scale with `text_scale` (fixed 90x126 — accessibility-requirements Visual) and Card Inspect's reading panel carries the text instead.

---

**End Turn button** (pattern: End Turn Button)

- Visual description: 1116, 296, 140, 44; label "End Turn" 16 px (`hud.end_turn`); states Disabled (`text_muted`) / Enabled (`text_light`) / Actionable (+ 2 px `state_actionable` outline when no legal play other than `end_turn` remains or mana is 0) / Pressed.
- Data displayed: derived from `phase == PlayerTurn.Main`, queue idle, `legal_commands()`.
- Update behavior: instant state swaps; depress 60 ms on press; the boss intent commit beat must be visible ≤ 300 ms after (match-ui Input Responsiveness).
- Urgency states: Actionable is the only emphasis — it is a "nothing left to do" readout, not an alarm.
- Interaction: click (never gated); `Space` / `Enter` when Enabled **and armed** (`end_turn_arm_ms` 300 ms after the queue drained) and no card / token / hero power holds focus; otherwise those keys are Skip & Playback. Focus stop 6. Accessible name "End Turn" + "nothing left to do" when Actionable.
- Player customization: none; label scales with `text_scale` — the button grows **left** (right edge fixed at 1256), to at most 200 px wide, staying clear of the boss row's right edge at x 979.

---

**Hero power button and weapon slot** (pattern: Hero Power Button; Tooltip)

- Visual description: power 152, 390, 48, 48 — hero primary fill, 2 px frame, cost stamp "2" (steel blue, 14 px) at its top-left corner, glyph = power initial (W / R / I) 20 px `text_light`; Ready adds the `state_actionable` outline when affordable; Blocked dims to 50 % with the reason in the tooltip; Used dims and shows a "✓" letter badge. Weapon slot 152, 446, 48, 48 — `table_dark` frame; empty: dashed `text_muted` ring; equipped: sword glyph + attack stamp (bottom-left) and shield glyph + durability stamp (bottom-right), 14 px numerals on `ink` 22 px circles. A `modify_cost` discount from a treasure (treasures UI Req) shows on the power's cost stamp as the effective number in `state_buff` with a leading "−" glyph beside it.
- Data displayed: `power_state`; `hero_power_state()` reason code; `HeroPowerDef` name / cost / text (Card Database); `weapon{attack, durability}`.
- Update behavior: press 0.15 s on `hero_power_used`, re-light 0.15 s on `hero_power_refreshed`; weapon slot update 0.2 s / shatter 0.3 s on `weapon_destroyed`; heroes.md Visual/Audio hero-specific flourishes (bronze flash on Whetstone equip, etc.) are `asset-spec` work and change no geometry.
- Urgency states: none beyond Blocked / Used.
- Interaction: click or `H` on Ready (targeted powers start a Targeting session; untargeted still need the confirm press, interaction-patterns rule 2); focus stop 3 opens the tooltip immediately (name, cost, text, Blocked reason) — heroes.md UI Requirements says "Open / hover"; the Hero Power Button pattern and accessibility matrix add focus, and match-ui U5 now agrees. Weapon slot is display-only; its numbers are repeated in the portrait tooltip (stop 4). 48x48 meets the 44 px floor.
- Player customization: none.

---

**Treasure tray** (pattern: Treasure Chip; Empty State "deliberate absence")

- Visual description: tray 24, 502, 136, 40 (hidden when no treasure is held); chips 40x40 at x 24, 72, 120 (8 px gaps), rarity frame (word in the tooltip — never colour alone) + letter glyph; **hit rect 44x44 per chip** centred on the visual (x 22–66, 70–114, 118–162; y 500–544) — F6's resolution of accessibility-requirements Motor "Minimum target size". Three slots is `MAX_TREASURES_HELD` (treasures.md; F6) — interaction-patterns' Treasure Chip entry and accessibility-requirements Cognitive say "≤ 4" / "up to 4"; F6 and treasures.md win (§13).
- Data displayed: `MatchConfig.treasures` ids in pick order (= installation order); tooltip: name, rarity word, text, tags as pills, "picked on floor f" (treasures UI Req).
- Update behavior: populated at open, no animation; flare 0.15 s outline flash on a hook-hosted `effect_resolved{host_kind: treasure}` (static brightening under `reduce_motion`); the feed line names the treasure and result ("… (no effect)" for zero-effect firings).
- Urgency states: none.
- Interaction: hover / focus tooltip (stop 5, chips left → right); not clickable.
- Player customization: none; at `text_scale` 150 % the tooltip grows, the chips do not.

---

**Deck piles** (pattern: none needed — display-only readouts; Floating Number for the fatigue label)

- Visual description: boss 24, 96, 76, 106 and player 1180, 540, 76, 106 — a 0.5x card back (75x105 placeholder: `table_dark` fill, band / hero frame) with the count 16 px bold `text_light` on an `ink` pill centred on the pile. Player pile, deck empty: the pill reads "Fatigue: next N" (`hud.fatigue_next`, 13 px, two lines) from `fatigue_next`. A burned card (`card_burned`) is shown face up over the player pile for 0.4 s, then dissolves (match-ui Edge Cases).
- Data displayed: `deck_count` (both), `fatigue_next` (player).
- Update behavior: count tick 0.15 s on `card_added_to_deck`; draw slide 0.2 s deck → hand (player) or deck → boss hand strip (boss); burn 0.4 s; fatigue label 0.4 s then the damage pop.
- Urgency states: deck empty → the fatigue label replaces the count; no colour change.
- Interaction: display-only; not focus stops (the numbers are text, nothing is hover-only).
- Player customization: none; the pill text scales with `text_scale` (pill grows, stays inside the pile's 76 px width by wrapping to three lines at 150 %).

---

**Mana bar** (pattern: Mana Bar)

- Visual description: 1060, 652, 196, 56 in two rows: "n/m" 16 px bold `text_light` at 1060, 652, 196, 20 (left-aligned, `hud.mana` "{n}/{m}"); ten 16 px crystals with 4 px gaps at 1060, 680, 196, 28 — full (steel-blue fill, `ink` ring), spent (hollow ring), temporary (fill + "+" glyph), locked (hatched + lock glyph). The bar starts at x 1060 because card 9's rotated edge reaches x 1054 at y 652 (F1 / F6).
- Data displayed: `mana{available, max, temporary}`, locked crystals.
- Update behavior: instant on `mana_*` (no animation step, match-ui U3); `NOT_ENOUGH_MANA` rejection flashes the bar's outline 0.2 s (Rejection Feedback).
- Urgency states: none — "0/5" is the readout.
- Interaction: display-only; not a focus stop.
- Player customization: "n/m" scales with `text_scale` (crystal row fixed); at 150 % the 24 px text still fits the 196 px width.

---

**Turn banner** (pattern: Skip & Playback context; Animation Standards `turn_banner`)

- Visual description: a 400x48 `table_dark` plate framed in the band colour, centred over the boss row at 440, 215 (inside the row rect 301–979 × 176–302, so no new zone), text "Boss turn 4" 16 px `text_light`. Boss turn only (match-ui U3 table). Under `reduce_motion` it fades instead of sliding.
- Data displayed: `turn`.
- Update behavior: 0.4 s, then gone; skippable; survives a skipped boss turn as view-state text in the top bar (the banner itself is animation and is skipped).
- Interaction / customization: none.

---

**Skip hint** (pattern: Skip & Playback)

- Visual description: "Click or Space to skip" (`hud.skip_hint`) 13 px `text_muted` at 980, 92, 276, 20 — directly under the intent banner, above the boss portrait (y 96) — appearing 1 s into any busy queue and staying until the drain; static (no pulse under `reduce_motion`, and never faster than 1 Hz anyway).
- Data displayed: none.
- Update behavior: fade 120 ms in / 80 ms out (0 under `instant`).
- Interaction / customization: none.

---

**Floating numbers, targeting arrow, rejection tooltip, feed ticker, hand fan, overlays** — placed in §3 and §4.1; behaviour is owned by Floating Number, Targeting Arrow / Click-to-Select (`targeting.md`), Rejection Feedback (`targeting.md`), Event Feed (`event-feed.md`), Card (Hand) / Card Drag-to-Play / Card Inspect (`hand.md`), Modal Dialog / Pick One of N (`mulligan.md`, `choice-overlay.md`, `match-end.md`, `pause-menu.md`). This document adds no behaviour to them.

---

## 5. HUD States by Gameplay Context

The contexts are match-ui's view states (States and Transitions), which are orthogonal to the engine phase. The template's four mandatory contexts map as: **exploration** = `Idle` (player's own turn, nothing in flight), **combat** = `Dragging` / `KeyTargeting` / `Playback`, **dialogue / cutscene** = `BossTurn` (watch-only, skippable), **paused / menu** = `Menu`. `playing` (queue non-empty) overlays every state except `Ended`.

| Context | Elements Shown | Elements Hidden | Elements Modified | Transition Into This State |
|---------|---------------|-----------------|------------------|---------------------------|
| `Loading` (scene ready, `events_since(0)` projecting) | Top bar (text from `MatchConfig`), both deck piles, portraits, mana bar — all at their projected final values, table `table_lit` | Hand, rows, banner, feed lines (until projected); tray until `MatchConfig` is read | Nothing animates (`anim_speed` forced `instant` while loading); no input | Scene swap at `begin_match` (run-ui S10), ≤ 500 ms to first frame; fixtures (U11) end here with everything projected |
| `Mulligan` | Everything above plus the Mulligan row 278, 202, 723, 315 over a table dimmed to `table_dark` (own spec `mulligan.md`) | Hand fan (the 3 starting cards are the row), End Turn (Disabled), intent banner (not yet shown — forecast comes at `PlayerTurn.Main`) | Rows dimmed under the overlay; feed ticker lit (art bible §2: the log is lit in every state) | `mulligan_offered` → `overlay_open` 0.2 s; `Esc` opens the pause menu over it, never closes it |
| `Idle` — **exploration equivalent** | Full set: top bar, ticker, piles, intent banner (forecast), portraits, strip, both rows, End Turn (Enabled / Actionable), hand with playable outlines, hero power, weapon slot, tray, mana bar | Turn banner, skip hint, floating numbers, arrow, rings, summon gap | Table at full `table_lit` (art bible §2 player turn); focus ring on the current stop; Card Inspect for the hovered / focused element | Queue drained with `phase == PlayerTurn.Main`; focus → End Turn if nothing lit else the left-most playable card |
| `Dragging` / `KeyTargeting` — **combat equivalent** | Idle set + Targeting Arrow, legal-target rings, summon gap, lifted source | — | End Turn → Disabled; non-legal targets unchanged (never dimmed — Stealth is "cannot be targeted", not "cannot be seen"); ticker keeps updating | Press-and-move > 8 px / click / number key / `A`+n / `H` / `Enter` on a focused source; 0 ms (pickup is instant) |
| `Playback` (player's own command resolving) | Idle set + floating numbers, lunges, draw slides, rim glows; skip hint after 1 s | Arrow, rings | Controls locked except skip, pause menu, feed; End Turn Disabled | First `AnimStep` enqueued; ≤ 50 ms after release |
| `BossTurn` — **cutscene equivalent** | Everything in Playback; turn banner 0.4 s; intent banner commit beat; skip hint after 1 s; "boss discovers…" label 0.4 s on the boss portrait when the AI answers a Choice | Player-side legality (no outlines on hand cards or tokens) | **Light pulled toward the boss**: the hand zone's fill drops one step to `table_dark` (art bible §2 "player hand dimmed one step") — card contrast unchanged; End Turn Disabled; hero power dimmed as not-Ready | `turn_started{side: boss}`; groups paced by F4 (`gap` 0.6 s default, floor 0.15 s, compressed to fit `max_turn_playback_s` 10 s) |
| `ChoiceOpen` | Idle/Playback set under the Choice row 278, 202, 723, 315 (own spec `choice-overlay.md`) | — | Table dims to `table_dark`; End Turn Disabled; no cancel (`Esc` → pause menu) | `choice_requested{side: player}` + `discover_offered` → `overlay_open` 0.2 s, after the card-play step of its group |
| `Menu` — **paused equivalent** | Pause menu 440, 160, 400, 400 (own spec `pause-menu.md`): Resume, Concede (Destructive → Confirmation Dialog), settings quick-access (volumes incl. music — accessibility Auditory, `anim_speed`, `reduce_motion`) | — | Base dims to `table_dark`; base input disabled recursively; **underlying playback keeps running** (match-ui States) and the ticker keeps updating | `Esc` (chain step 4) or the top-bar menu button; focus → Resume; returns to the trigger on close |
| `Ended` | End banner 340, 260, 600, 200 (own spec `match-end.md`): victory / defeat / both-dead / concede / **`fault`** copy | Arrow, rings, skip hint | Winning portrait saturates (0.4 s) — **not** on `fault`; `fault` uses a neutral frame and fires no stinger ("Rules fault — this floor is replayed, not lost"); all commands locked | `match_ended` projected and queue drained → `end_banner` 0.6 s; click or `MATCH_END_AUTO_S` 4 s → `match_view_finished(result)` |
| Feed drawer open (any state) | Drawer 0, 40, 300, 290 over the ticker and boss deck | Boss deck pile (covered) | Non-blocking; play continues; `Esc` / `L` / RMB closes it first | `L` or the feed button |
| Rejection (any input state) | Rejection Feedback: shake, `reject.<code>` tooltip 1.5 s, related-control flash (Taunts / mana bar), feed line | — | **Nothing else changes** — the display is the view-state, and no event was emitted | `submit` returned `accepted = false` |
| `effective_mode = hidden` (per boss or `telegraph_mode = off`) | "?" plate in the banner rect | Intent icon, label, amount, reticle | — | `ai_intent_shown{effective_mode: hidden}` |
| `reduce_motion` (setting) | Same elements | — | No hit-stop, shake, lethal slow-down, lift bounce; `reject_shake` → 2-frame outline flash; pops fade in place; banners fade not slide; `lethal` pulse and skip hint static | `settings_changed` |
| `anim_speed = instant` (setting; the harness default) | Same elements; focus ring still drawn | Every animation step (`apply_final` only) | Boss turn degenerates to T = 0: banner final state and turn text still render (view-state) | `settings_changed` / `--anim-speed=instant` |
| `text_scale` 125 % / 150 % | Same elements | — | §10.2 matrix: bar text, banner, tooltips, feed, "n/m", health, End Turn label, pile pills grow; cards and tokens do not (Card Inspect reading panel instead) | `settings_changed` |
| Persisting unlock toast (run-ui S-05) | Toast at 540, 48, 400, 48 | — | Nothing moves; the toast is above the HUD layer and below the intent banner's priority (never overlaps it by placement) | Toast visible when `begin_match` fired; removed when its `t_toast` elapses or on click / `Enter` |
| `--ai-debug` (debug builds) | AI debug overlay 0, 40, 400, 300; `feed.diag.<type>` lines in `text_muted` | Ticker and boss deck (covered while open; collapsible) | — | Launch flag only |

---

## 6. Information Hierarchy

Tiers decide what drops first if a state would exceed the §7 budget; nothing in this HUD is dropped automatically in v1, because every element below MUST KEEP is contextual by construction.

| Element | Priority Tier | Reasoning | What Replaces It If Hidden |
|---------|--------------|-----------|---------------------------|
| Player hero health / armour / weapon | MUST KEEP | Lethal math; the loss condition | Nothing — N/A |
| Boss hero health / armour / weapon | MUST KEEP | The win condition | N/A |
| Board rows and tokens | MUST KEEP | They are the game state | N/A |
| Hand fan with costs and playability | MUST KEEP | The player's options | N/A |
| Mana bar "n/m" | MUST KEEP | Every play decision; the crystals row is SHOULD KEEP (the numeral suffices) | Numeral alone |
| End Turn | MUST KEEP | The only way to pass | `Space`/`Enter` still works, but the control must be visible |
| Boss intent banner | MUST KEEP while `effective_mode ≠ hidden` | Pillar 3's telegraph; the lesson | The "?" plate — and only when the rules (boss-ai C8.4) or the player said so |
| Event feed ticker | MUST KEEP | Pillar 4's receipt; lit in every state (art bible §2) | The drawer is the same data, not a replacement; never both hidden |
| Boss passive plate | MUST KEEP | Pillar 2: the puzzle statement | Boss portrait tooltip (focus) — but the plate stays |
| Turn / phase text (top bar) | SHOULD KEEP | Which side acts is also readable from End Turn's state and the banner | End Turn state + turn banner |
| Floor / boss name (top bar) | SHOULD KEEP | Orientation; also on the boss intro before the match | Boss intro / progress strip (run screens) |
| Hero power button | SHOULD KEEP | A legal command source; `H` reaches it blind, but the state must be visible | `H` + feed lines |
| Weapon slot | SHOULD KEEP | Weapon attack is part of lethal math; also in the portrait tooltip | Portrait tooltip |
| Deck counts / fatigue | SHOULD KEEP | Planning numbers; fatigue is a threat | Feed lines (`card_drawn`, `fatigue_damage`) |
| Boss hand count / boss mana | SHOULD KEEP | Reading the next boss turn | Boss portrait tooltip |
| Treasure tray | SHOULD KEEP | Reminder of held rule-benders; chips fire with a feed line | Feed lines + progress strip between matches |
| Floating numbers | CAN HIDE | Supplementary (stamp numeral + feed line carry the number); `anim_speed = instant` already removes them | Stamp numeral, feed |
| Turn banner | CAN HIDE | Duplicate of top-bar text; skipped with the queue | Top bar |
| Skip hint | CAN HIDE | Discoverability aid; the skip works without it | Nothing needed |
| Feed toggle / menu buttons | CAN HIDE (never actually hidden) | `L` / `Esc` duplicate them; kept for mouse-only play (accessibility Motor "One-hand mode") | Keys |
| Persisting unlock toast | CAN HIDE | Repeated on the summary and hero select | Summary |
| AI debug overlay | ALWAYS HIDE in release | Developer tool | N/A |
| Legal rings / arrow / summon gap | ALWAYS HIDE outside a targeting session | Stale legality would mislead (match-ui "legality before commitment") | N/A |

---

## 7. Visual Budget

The template's percentages assume a world behind the HUD. Here the play surface (rows, hand, portraits) is the content, so the budget is split into **chrome** (bar, ticker, banners, buttons, piles, mana, tray, strip) and **play surface**, and both are measured against F6. Current estimates are computed from the F6 rectangles (sum of zone areas ÷ 921 600 px); they are not measured screenshots, so every row is "To verify" against the named fixture.

| Budget Constraint | Limit | Measurement Method | Current Estimate | Status |
|------------------|-------|--------------------|-----------------|--------|
| Maximum simultaneous persistent HUD elements (§4.1 rows that are Always Visible or present in `Idle` with a full board and 3 treasures) | 18 named elements (+14 tokens, +10 cards counted as content) | Count non-faded elements in one `Idle` frame of `midgame_full_board` with `treasure_tray`'s treasures | 18 (top bar ×3 incl. buttons as one, ticker, 2 piles, banner, 2 portraits, passive plate, hand/mana strip, End Turn, power, weapon, tray, mana bar, turn text, floor text) | To verify |
| Chrome area, excluding portraits | ≤ 15 % | Pixel area of top bar + ticker + piles + banner + hand/mana strip + End Turn + power + weapon + tray + mana bar ÷ total | 124 592 px = **13.5 %** | To verify |
| Chrome area, including both portraits | ≤ 20 % | Above + 2 × 19 200 | 162 992 px = **17.7 %** | To verify |
| Zone envelope incl. play surface (rows, hand zone) at 7 v 7 and 10 cards | ≤ 60 % — the remainder is the lit table | All F6 zone rects ÷ total | 540 248 px = **58.6 %** | To verify (`midgame_full_board` + `hand_10`) |
| Centre zone (x 384–896, y 216–504) occupied by **chrome** | 0 % | No bar, button, pile, banner or mana pixel inside the rect | 0 % (End Turn ends at x 1256 start 1116; banner y 52–88; nothing else) | To verify |
| Largest modal overlay | ≤ 20 % | Pause 400x400 = 17.4 %; end banner 600x200 = 13.0 %; Choice row 723x315 = 24.7 % — **the Choice row exceeds 20 % by design** (three 1.5x cards must be readable; F6 fixes it) | 24.7 % max | Accepted — recorded, not a breach to fix |
| Minimum contrast — HUD text on any background | 4.5:1 body / 3:1 ≥ 18 px bold | Art bible §4 figures: `text_light` on `bg_edge` 14.75, `table_dark` 13.07, `table_lit` 9.43, `ink` 14.33, hero primaries 6.17–6.72, band colours 5.47–7.35; `text_muted` on `bg_edge` 7.94 / `table_dark` 7.03; state colours as numerals only on `ink` (danger 5.61, buff 7.16, target 10.65, freeze 8.86) | All pass per the art bible | To verify in-engine (test plan row 1 of accessibility-requirements) |
| Maximum dim for panels behind HUD text | The dim **is** `table_dark` (opaque surface swap, not alpha) | Overlay states swap the table fill to `table_dark`; cards keep `parchment` | N/A — no translucency in v1 | — |
| Minimum element size at 1280x720 | 12 px text floor (art bible); 44x44 interactive hit | Measure every §4.1 "Min Readable Size" and every hit rect | Smallest text 12 px (card rules, Card Inspect path); smallest hit 44x44 (top-bar buttons, chips) | To verify |

---

## 8. Feedback & Notification Systems

Everything transient on the match screen is an `AnimStep` in match-ui's `AnimationQueue` (U4) except the toast, which lives on run-ui's toast layer. "Queue behavior" below therefore means the queue's own rules: FIFO in `seq` order, command groups never reorder, `parallel_ok` steps play with their predecessor, skip-all flushes everything in one frame.

| Notification Type | Trigger System | Screen Position | Duration (ms) | Animation In / Out | Max Simultaneous | Priority | Queue Behavior | Dismissible? |
|------------------|---------------|-----------------|--------------|-------------------|-----------------|----------|---------------|-------------|
| Floating number (damage / heal) | Match Rules via `damage_dealt` / `healed` | On the target token or portrait, rises 20 px | 400 | ease-out rise / fade (fade in place under `reduce_motion`) | board size + 2; AoE > 8 targets coalesce into one step (U4.3) | Normal (queue) | FIFO per `seq`; lands on the lunge's active frame for attacks; `dealt = 0, prevented > 0` and `healed{amount: 0}` produce no pop | Skip-all |
| Divine Shield burst | Match Rules | On the token | 250 | ring burst `text_light` | 1 per token | Normal | Precedes its damage step | Skip-all |
| Fatigue label | Match Rules `fatigue_damage` | Player deck pile / portrait | 400 | fade | 1 | Normal | Then the damage pop | Skip-all |
| Burn flash | Match Rules `card_burned` | Over the player deck pile, face up | 400 | dissolve | 1 | Normal | FIFO | Skip-all |
| Turn banner | Match Rules `turn_started{boss}` | 440, 215, 400, 48 | 400 | slide (fade under `reduce_motion`) | 1 | Normal | First step of the boss turn, before the commit beat | Skip-all (view-state text remains in the top bar) |
| Intent shown / commit beat / plan changed | Boss AI | Banner 980, 52, 276, 36 | 300 / `intent_banner_s` 300 / `plan_changed_s` 1200 | fade / brighten / crossfade | 1 | High — the first thing in a boss turn | Commit beat plays before the first action group (U6.2); skip leaves the final banner state | Skip-all; the final state is not dismissible (it is a readout) |
| "Boss discovers…" label | Card Effects (boss Choice) | On the boss portrait | 400 | fade | 1 | Normal | Inside its command group | Skip-all |
| Treasure chip flare | Card Effects `effect_resolved{host_kind: treasure}` | The chip | 150 | outline flash (static brighten under `reduce_motion`) | 3 | Low | `parallel_ok` with the hosted effect's steps | Skip-all |
| Rim glow (armed source) | Card Effects `trigger_queued` → `trigger_resolved` | The source token / card | 150 in / 150 out | fade | many | Low | `parallel_ok` | — |
| Skip hint | Match UI | 980, 92, 276, 20 | until drain | 120 / 80 fade | 1 | Low | Appears 1 s into a busy queue; not a step | Disappears on drain |
| Rejection feedback | Match Rules `command_rejected` (player side) | Source control shake; tooltip at cursor / above the control; related control flash; feed line | 200 shake / 1500 tooltip | shake (outline flash under `reduce_motion`) | 1 | **Immediate — never queued** (it is not a step with a `seq` worth waiting for; the display does not change) | Bypasses the queue; the feed line is the persistent record | Tooltip fades on its own or on the next command |
| End banner | Match Rules `match_ended` | 340, 260, 600, 200 | 600 in; holds for click or `MATCH_END_AUTO_S` 4000 | `end_banner` ease-out | 1 | Terminal | After the queue drains (U9); the only step that holds | Click / `Enter` advances early; cannot be cancelled |
| Unlock toast (persisting) | Meta via run-ui toast layer | 540, 48, 400, 48 | `t_toast` = clamp(5000 + 30·chars, 5000, 8000) | 200 fade (slide only without `reduce_motion`) | **1** (run-ui U5) | Low | Not part of the match queue; only a toast already visible at `begin_match` is shown — toasts raised during a match **wait** for the summary (run-ui U5, S21); hover or focus pauses its timer | Click / `Enter` when focused |
| Warning toast | Run Structure `run_warning` | Same anchor | — | — | — | — | **Held** during `match` (run-ui U5); a warning caught by the handoff may be cut short — its content is in the log and the next summary's status line | — |
| AI debug lines | Boss AI diagnostics | Feed drawer (`--ai-debug` only) | persistent | — | — | Dev | Rendered as `feed.diag.<type>` in `text_muted`; never in release | — |

**Notification queue rules**:
1. **Combat-aware rule (boss turn / playback)**: nothing player-informational is held back during playback — pops, banners and feed lines *are* the playback. What is held is the run-shell's toast queue: no new toast starts while `ShellState = match` (run-ui U5); it drains on the summary or boss intro. The skip hint is the only element gated by time (1 s).
2. **Merge rule**: a run of `minion_died` sharing one `cause_seq` is one death step (U3.3); more than `COALESCE_THRESHOLD` (8) damage / heal pops on distinct targets from one source play as one simultaneous pop step (U4.3). **Nothing else merges** — Pillar 4 wants effects countable. Toasts never merge (one at a time).
3. **Critical bypass rule**: Rejection Feedback is never queued and never merged; the `lethal` intent pulse plays even when the rest of the boss turn is skipped (the banner state is view-state). Skip-all (any LMB on empty table, `Space`, `Enter`, or a new command) flushes every queued step within 100 ms — no notification can delay a legal move (U4.7).

---

## 9. Platform Adaptation

| Platform | Safe Zone | Resolution Range | Input Method | HUD-Specific Notes |
|----------|-----------|-----------------|-------------|-------------------|
| PC — Windows (primary), Linux (dev / CI) | 0 % — F6's own 24 px side margins | 1280x720 logical, fixed; window 1280x720 min to 3840x2160 max via `canvas_items` + `keep` (letterboxed at non-16:9) | Mouse primary + keyboard complete (DD-T05); every mouse action has a key path (match-ui U5; Standard Shortcuts) | Hit-testing in logical coordinates; nothing re-flows on resize (match-ui Edge Cases). The harness captures at `--resolution 1280x720`; run-ui AC-31 adds a 2160p capture per fixture at `text_scale` 1.5 |
| PC — gamepad (post-v1, `Partial`) | as above | as above | d-pad = `focus_neighbor_*` over the §10 focus order; `ui_accept` = Enter; `ui_cancel` = Esc; shoulders = Tab / Shift+Tab | No v1 element may require a pointer with no focus equivalent (Focus Management "Gamepad"); the Click-to-Select / Keyboard Targeting state machine is the surface a pad maps onto |
| Steam Deck / console / mobile | — | — | — | Not targets (concept Core Identity; accessibility-requirements Platform API table) |

**HUD repositionability requirement**: **Not committed.** `design/accessibility-requirements.md` lists HUD element repositioning as a Known Intentional Limitation (Comprehensive tier; the fixed F6 grid is what the hand fan, hover preview and arrow are tuned against). The template's console-driven requirement does not apply to a PC-only title; if a console target is ever added, this row is reopened. What the player *can* change is listed in §10.5.

---

## 10. Accessibility

> HUD-specific requirements only — refer to the project's
> `design/accessibility-requirements.md` for the full project standard.

### 10.1 Colorblind Modes

One mode exists: `high_contrast_states` (DD-X07) swaps `state_danger` → `#FF8C42` and `state_buff` → `#4FA3FF`; target, freeze and actionable are unchanged. Every row below also has a non-colour backup, so the HUD reads correctly in Coblis protanopia / deuteranopia / tritanopia with the toggle **off** as well (accessibility-requirements Visual: verify every match-ui U11 fixture both ways).

| Element | Color-Only Information Risk | Colorblind Mode Fix |
|---------|----------------------------|---------------------|
| Health / durability numerals | `state_danger` = below max; `state_buff` = above printed | Leading "−" / "+" on the pop; crack glyph / up-arrow beside the numeral; the numeral itself is the readout |
| Boss intent `lethal` | `state_danger` text | The word "Lethal", the `L` icon, the amount, the reticle |
| Legal target / hovered target | `state_target` ring and arrow | The arrow's shape and the 3 px ring (shape-first, art bible §4) |
| Frozen / Silenced tokens | `state_freeze` outline | Snowflake glyph; slash glyph + greyed art box |
| Playable card / legal attacker / End Turn ready / Ready hero power | `state_actionable` outline | It is `#F2E9D8` light, not a hue; cards also lift 8 px on hover; End Turn's label value changes |
| Keyboard focus vs hover | Both light | Focus = 2 px ring **offset 3 px**; hover = lift with no ring; both shown when both (Focus Management) |
| Hero vs boss ownership (frames, portraits) | Hero primary vs band colour | Side of the table; hero initial letter; War / Decay primaries also differ in value |
| Boss band (portrait, token frames) | Ochre / rust / slate-violet | Top bar "Floor n of F"; the boss intro's band pips before the match |
| Mana crystal states | Steel-blue fill vs hollow | Four shapes: filled / hollow / "+" glyph / hatched + lock; "n/m" numeral |
| Keyword badges | Letter glyphs on `ink` | Glyphs only — no two badges differ by colour alone (rule from the accessibility audit) |
| Treasure rarity on chips | Rarity frame tint | The word Common / Rare in the tooltip (treasures UI Req) |
| Victory portrait saturation | Hero primary fill | The end banner headline (`match-end.md`) |

### 10.2 Text Scaling

`text_scale` ∈ {1.0, 1.25, 1.5} (DD-X07; three fixture-tested layouts, never a slider). At 150 %: top-bar text (24 px) still fits — the centre label ellipsises the boss name at x 1150; the intent banner's 24 px label grows the plate **left** into the 424–980 band (up to 824 px wide, F6 banner height unchanged); the feed ticker's 13 px → 19.5 px lines make the 42 px ticker hold two lines instead of three (the drawer keeps all; it grows to 360 px wide, still clear of the player portrait at y 334 because it ends at y 330); tooltips and Card Inspect add the reading panel (18 × 1.5 = 27 px body, max 360 px wide, toward screen centre); hero health 36 px stays inside the 120 px portrait; "n/m" 24 px fits 196 px; End Turn's label grows the button left to ≤ 200 px; deck pills wrap to three lines inside 76 px; the boss hand / mana strip **does not fit two 21 px readouts in 120x28** — at 125 % and 150 % the mana half moves into the boss portrait's bottom-right corner (an `ink` pill like the player's health stamp, left of the health stamp) and the strip holds the hand count alone. **Architecturally not scaled**: the 150x210 card, the 90x126 token and the 40x40 chip (fixed slots, art bible §4; accessibility-requirements Visual) — Card Inspect and tooltips are their reading path.

**Text scaling test matrix** (fixture: `midgame_full_board` with the fixture profile's `settings.text_scale` at each step — match-ui U11 has no `--text-scale` argument, so the scale rides in the fixture's settings; see §13):

| Element | 100% (baseline) | 125% | 150% | Overflow behavior |
|---------|----------------|------|------|-------------------|
| Top bar turn / floor text | TBD | TBD | TBD | Boss name ellipsised at x 1150; turn text never ellipsised (≤ 14 chars) |
| Boss intent banner label | TBD | TBD | TBD | Plate grows left to x ≥ 432; label never wraps |
| Feed ticker | TBD | TBD | TBD | Shows 2 lines at 150 %; drawer keeps 200 |
| Hero health / armour numerals | TBD | TBD | TBD | Stamp circle grows to 56 px, stays in the 120 px panel |
| Boss passive plate | TBD | TBD | TBD | 2 → 3 lines, plate grows up over the art area, never below y 256 |
| Boss hand / mana strip | TBD | TBD | TBD | Mana half relocates into the portrait at ≥ 125 % |
| End Turn label | TBD | TBD | TBD | Button grows left to ≤ 200 px |
| Mana "n/m" | TBD | TBD | TBD | Fits; crystals fixed |
| Deck pile pills | TBD | TBD | TBD | Wrap to 3 lines inside 76 px |
| Tooltips / Card Inspect | TBD | TBD | TBD | Reading panel; scrolls only above 50 % viewport height |
| Hand cards / tokens / chips | Pass (fixed) | N/A (fixed) | N/A (fixed) | Not scaled by design; Card Inspect |

### 10.3 Motion Sensitivity

| Animation / Motion Element | Severity | Disabled by Reduced Motion Setting? | Replacement Behavior |
|---------------------------|----------|-------------------------------------|---------------------|
| Hit-stop 60 / 90 ms | Mild | Yes (also off at `anim_speed = fast`) | None — numbers land on the active frame regardless |
| Screen shake 3 px / 120 ms (hero damage ≥ 5, lethal) | Moderate | Yes | None |
| Lethal slow-down 400 ms | Mild | Yes | Normal speed |
| `reject_shake` 3 px / 200 ms | Mild | Yes | 2-frame outline flash on the source |
| Floating number rise 20 px | Mild | Yes | Fade in place |
| Card-lift bounce (hover 8 px) | Mild | Yes (bounce) — the lift itself stays (it is a state readout) | Instant lift |
| Turn banner slide | Mild | Yes | Fade |
| Boss intent `lethal` pulse | Mild | Yes | Static `state_danger` text + word |
| Skip hint pulse | — | Never pulses faster than 1 Hz; static under `reduce_motion` | Static text |
| Card play travel, lunge, draw slide, death drop | Mild | **No** — positional travel carries information (Animation Standards) | Un-squashed; durations unchanged (`anim_speed` governs speed) |
| Victory portrait saturation (0.4 s ramp) | Mild | No — a single ramp, not a loop; within the ≤ 3 luminance changes/s rule | — |
| Overlay scale 0.95 → 1.0 | Mild | Yes | Fade only |

No element on the match screen alternates luminance more than 3 times per second (accessibility-requirements "Screen flash / strobe").

### 10.4 Subtitles Specification

**N/A — no voiced or spoken content exists** (accessibility-requirements Auditory; concept: boss intro lines are on-screen text on `boss-intro.md`). Every SFX fired by the HUD is the audio half of a visible event (Gameplay-Critical SFX Audit) — the HUD's "caption" is the event feed line, which exists for every event regardless of audio. Default settings and the other fields are therefore not specified; if voiced content is ever added this subsection is authored from the template.

### 10.5 HUD Opacity and Visibility Controls

The player-adjustable settings are **exactly the DD-X07 record** (meta-progression M9), edited in `settings.md` and (a subset) in `pause-menu.md`. Settings the template suggests that are **not** in DD-X07 are listed as not committed so the gap is visible, not silent.

| Setting | Range | Default | Effect |
|---------|-------|---------|--------|
| `anim_speed` | `instant` / `fast` / `normal` (Segmented Select) | `normal` | Divides every `d_base` (F3: fast ÷ 2.0); `instant` applies final states only; impact extras off at `fast` |
| `reduce_motion` | On / Off | Off | §10.3 column; independent of `anim_speed` |
| `text_scale` | 100 % / 125 % / 150 % | 100 % | §10.2 |
| `high_contrast_states` | On / Off | Off | §10.1 state-colour swap |
| `action_delay_ms` | 0–2000 ms (Slider, 50 ms steps) | 600 | Boss action gap in F4 (`ai_action_delay_s`); floor `MIN_ACTION_GAP_S` 0.15 s still applies |
| `telegraph_mode` | `full` / `brief` / `off` | `full` | Consumed by Boss AI (`effective_mode`, DD-X03); the HUD renders what is emitted; `off` is a self-imposed challenge, never a default |
| `volume_master` / `volume_music` / `volume_sfx` | 0–100 % | 100 / 80 / 100 | Audio buses; music **must** join master and SFX in the pause quick-access (accessibility Auditory — `pause-menu.md`) |
| HUD opacity — global | — | — | **Not committed** — no DD-X07 key; no world behind the HUD to reveal, so the setting has no purpose here |
| Damage number visibility | — | — | **Not committed** — `anim_speed = instant` removes pops without losing information (Floating Number); a dedicated toggle would need an M9 key |
| Notification verbosity | — | — | **Not committed** — toasts never start during a match (run-ui U5); the one persisting toast is dismissible |
| Gamma | 0.8–1.4 | 1.0 | **Proposed, not committed** (accessibility-requirements Visual "Brightness / gamma" — needs an M9 key; §13) |

---

## 11. Tuning Knobs

All match-side values live in `assets/data/match_ui.json` and are owned by match-ui's Tuning Knobs table; Boss AI's live in `ai_profiles.json`; player settings in Meta's record. This table lists the ones that change what the HUD looks like, with the player-adjustable column the template asks for; ranges are the owning GDD's safe ranges, not re-derived.

| Parameter | Current Value | Range | Effect of Increase | Effect of Decrease | Player Adjustable? | Notes |
|-----------|-------------|-------|-------------------|-------------------|-------------------|-------|
| `anim_speed` | normal | instant / fast / normal | — | — | Yes — settings and pause quick-access | DD-X07; match-ui F3 `SPEED_DIV` |
| `SPEED_DIV.fast` | 2.0 | 1.5–3.0 | Snappier `fast` | `fast` ≈ `normal` | No | match-ui |
| `reduce_motion` | false | bool | — | — | Yes | §10.3 |
| `text_scale` | 1.0 | {1.0, 1.25, 1.5} | Larger HUD text | — | Yes | §10.2 |
| `high_contrast_states` | false | bool | — | — | Yes | §10.1 |
| `action_delay_ms` | 600 | 0–2000 | Slower boss cadence | Blur risk (floored at 150 ms) | Yes — slider | Meta M9; match-ui F4 |
| `telegraph_mode` | full | full / brief / off | — | Less shown in the banner | Yes | Boss AI consumes (DD-X03) |
| `end_turn_arm_ms` | 300 | 150–600 | Longer dead window after a drain for `Space`/`Enter` | Accidental End Turn risk below 150 | No | match-ui; click never gated |
| `CLICK_DRAG_PX` | 8 | 4–12 | Small drags read as clicks | Tremor presses read as drags | No | match-ui U5 |
| `d_base.*` (17 step kinds) | F3 table | 0.1–0.8 s | More weight; boss turns compress sooner | Below 0.15 s effects blur | No | match-ui F3 |
| `MIN_ACTION_GAP_S` / `K_MIN` | 0.15 / 0.25 | 0.1–0.3 / 0.25–0.5 | Busy turns hit auto-skip sooner | Actions run together | No | match-ui F4 |
| `presentation.action_delay_s` / `max_turn_playback_s` / `intent_banner_s` / `plan_changed_s` | 0.6 / 10 / 0.3 / 1.2 | 0.3–1.2 / 6–20 / 0.2–0.6 / 0.6–2.0 | Slower, longer boss turns; longer beats | Blur / missed beats | No (`action_delay_ms` overrides the first) | Boss AI |
| `HOVER_IN_S` | 0.1 | 0.05–0.2 | Laggy above 0.15 | Pops | No | match-ui F2 |
| `REJECTION_TOOLTIP_S` | 1.5 | 1.0–3.0 | Reason lingers | Reason missed (feed line persists either way) | No | match-ui |
| `MATCH_END_AUTO_S` | 4 | 2–8 | Longer forced pause before the summary | Banner gone before read | No | match-ui; Pillar 3 restart budget |
| `FEED_TICKER_LINES` / `FEED_GROUP_COLLAPSE` / `FEED_MAX_LINES` | 3 / 6 / 200 | 2–4 / 4–10 / 100–500 | Taller ticker (covers the boss deck above 4) | Chains truncated | No | match-ui F5 |
| `COALESCE_THRESHOLD` | 8 | 4–14 | Big AoEs play pop by pop | Small AoEs collapse | No | match-ui U4.3 |
| `HAND_W` / `HAND_GAP` / `ARC_H` / `THETA_*` | 800 / 8 / 24 / 4°, 30° | match-ui F1 | More fan | Toolbar look | No | `hand.md` |
| `ARROW_LIFT_PX` | 50 | 20–100 | Loopier arrow | Straight | No | `targeting.md` |
| `MAX_TREASURES_HELD` | 3 | treasures.md | **The tray moves, it does not extend** (F6) | — | No | treasures / F6 |
| Skip-hint delay | 1 s (match-ui UI Requirements) | — | Hint later | Hint sooner | No | Not yet a data-file key — §13 |
| Toast `t_toast` floor / cap | 5000 / 8000 ms | run-ui F3 | Longer toasts | Below 5000 fails the accessibility floor | No | run-ui |

---

## 12. Acceptance Criteria

Every observable criterion names the match-ui U11 fixture (`tests/fixtures/match_ui/<name>.json`) and, where needed, the `--pose`, launched per `.claude/docs/run-and-observe.md` (Godot row: `godot --path . --windowed --resolution 1280x720 --write-movie production/qa/evidence/<story>/<nn>-<what>.png --quit-after 60 res://src/ui/match/match_view.tscn -- --fixture=<name> --anim-speed=instant [--pose=…]`) with the screenshot **retained** in `production/qa/evidence/`. A criterion whose fixture does not yet exist says so.

**Layout & Visibility**
- [ ] GIVEN fixture `midgame_full_board` (7 v 7), WHEN captured, THEN every §3.2 zone sits at its F6 rect ±2 px (top bar 0,0,1280,40; boss row 301,176; player row 334; End Turn 1116,296,140,44; player portrait 24,334; hero power 152,390; mana bar 1060,652,196,56; player deck 1180,540), no two elements overlap, and the 14 tokens are at x = 301 + 98·i.
- [ ] GIVEN fixture `hand_10` with `--pose=hover:<id>` on card 9, WHEN captured, THEN the mana bar "n/m" and crystals are fully visible to the right of the hand (card 9's rotated edge ≤ x 1054 at y 652) and the 1.5x preview is clamped inside the viewport.
- [ ] GIVEN fixture `treasure_tray`, WHEN captured, THEN the tray shows two chips at x 24 and 72, y 502, 40x40, with no fourth slot, the chip hit rects (debug outline pose or inspector) are 44x44, and one chip carries the flare frame.
- [ ] GIVEN fixture `turn1_player`, WHEN captured, THEN the tray is absent (no empty box), the top bar reads "Your turn · 1" and "Floor n of F · <boss>", End Turn is Enabled, and the boss intent banner shows the forecast at the fixture's `effective_mode`.
- [ ] GIVEN any fixture at 1280x720 and at 3840x2160 fullscreen, WHEN captured, THEN the layout is pixel-identical after uniform scaling (letterboxed at non-16:9) — no element moved.
- [ ] GIVEN the chrome rectangles of §7, WHEN measured on `midgame_full_board`, THEN chrome excluding portraits is ≤ 15 % of the frame and no chrome pixel lies inside x 384–896, y 216–504.

**Per-Context Correctness**
- [ ] GIVEN fixture `boss_turn_playback` with `--pause-at=<seq>` inside the boss turn, WHEN captured, THEN End Turn is Disabled, no hand card or token carries the actionable outline, the hand zone fill is `table_dark`, the turn banner or the skip hint is visible (per the paused `seq`), and the intent banner shows the committed intent.
- [ ] GIVEN fixtures `boss_intent_full` and `boss_intent_plan_changed`, WHEN captured, THEN the first shows icon + label + amount + a reticle on the named target and the second shows the "Plan changed" label inside 980,52,276,36.
- [ ] GIVEN a fixture whose boss emits `effective_mode: hidden` (none in U11's required list — **needs `boss_intent_hidden`**, §13), WHEN captured, THEN a "?" plate occupies the banner rect and no icon, amount or reticle is drawn.
- [ ] GIVEN fixture `fatigue_and_burn`, WHEN captured at the burn step, THEN the player deck pill reads "Fatigue: next N" and the burned card is face up over the pile; the feed line names it.
- [ ] GIVEN fixtures `match_end_victory` / `match_end_defeat` / `match_end_fault`, WHEN captured, THEN the winning portrait is saturated to its primary in the first, the boss's in the second, and **neither** portrait is saturated and the banner frame is neutral in the third ("floor replayed, not lost" copy).
- [ ] GIVEN `--pose=menu:concede`, WHEN captured, THEN the pause menu occupies 440,160,400,400 over a `table_dark`-dimmed table, the ticker is still lit, and Cancel holds the focus ring.
- [ ] GIVEN `--pose=feed:open`, WHEN captured, THEN the drawer occupies 0,40,300,290 and the player portrait at 24,334 is fully visible.

**Focus & Input**
- [ ] GIVEN fixture `midgame_full_board` with `--pose=focus:end_turn`, `focus:hero_power`, `focus:treasure:1`, `focus:<token id>` and `focus:<hand index>`, WHEN captured, THEN each shows a 2 px `state_actionable` ring offset 3 px from the element's bounds, drawn above everything on that element, plus the focus-opened preview or tooltip — also with `--anim-speed=instant`.
- [ ] GIVEN `Idle`, WHEN `Tab` is pressed repeatedly from the default stop, THEN focus visits the §10 Focus Order stops in order (hand → player row → hero power → player portrait → chips → End Turn → feed toggle → menu → intent banner → boss row → boss portrait → wrap) and never lands on a pile, the mana bar or the top-bar text.
- [ ] GIVEN the top-bar feed and menu buttons, WHEN clicked anywhere in y 0–44 over their 44 px columns, THEN they activate (hit rect 44x44 although the bar is 40 px tall).
- [ ] GIVEN `Space` pressed within `end_turn_arm_ms` (300 ms) of the queue draining, THEN no `end_turn` is submitted; a click on End Turn at the same instant is.

**Accessibility**
- [ ] GIVEN every text element in §4.1 on its documented background, WHEN measured in-engine, THEN the ratio equals the art bible §4 figure and is ≥ 4.5:1 (≥ 3:1 for ≥ 18 px bold).
- [ ] GIVEN each `high_contrast_states` value, WHEN `midgame_full_board`, `divine_shield_hit` and `boss_intent_full` are run through Coblis (protanopia, deuteranopia, tritanopia), THEN every state in §10.1 is still identifiable by its glyph / word / shape.
- [ ] GIVEN `reduce_motion = true` in the fixture profile, WHEN `divine_shield_hit` and `simultaneous_deaths` play at `normal`, THEN no hit-stop, shake or slow-down occurs, pops fade in place, and the `lethal` banner pulse is static.
- [ ] GIVEN `text_scale = 1.5` in the fixture profile, WHEN `midgame_full_board` and `boss_intent_full` are captured, THEN no text clips, no element overlaps another, the intent banner has grown left, and the boss mana readout sits inside the portrait panel.
- [ ] GIVEN every setting in §10.5 marked "Yes", WHEN changed in the pause quick-access or settings, THEN the HUD reflects it on the next frame and it persists across a relaunch (Meta M9).

**Notifications**
- [ ] GIVEN fixture `simultaneous_deaths`, WHEN played at `normal`, THEN the dying tokens fade in **one** step and one gap-close follows; GIVEN an AoE on > 8 targets, THEN the pops are one simultaneous step.
- [ ] GIVEN a rejection (`--pose=reject:NOT_ENOUGH_MANA`), WHEN captured, THEN the mana bar outline is flashed, the tooltip reads the `reject.NOT_ENOUGH_MANA` copy, the display is otherwise unchanged, and the ticker holds a `feed.command_rejected` line.
- [ ] GIVEN an unlock toast visible when `begin_match` fires (run-ui AC-32 scenario), WHEN the match HUD renders, THEN the toast sits at 540,48,400,48, overlaps no HUD element, and disappears when its `t_toast` elapses — and no new toast starts during the match.
- [ ] GIVEN skip-all during `boss_turn_playback`, WHEN the frame after the input is captured, THEN every presenter equals `MatchViewState` (match-ui U4.6 assertion) and the intent banner shows its final state.

---

## 13. Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Player journey map does not exist — author `design/player-journey.md` from `.claude/docs/templates/player-journey.md` so the match's emotional targets (Core Loop "Moment-to-Moment") are sourced, not inferred. | Jacob | Before Pre-Production gate | Open |
| **Boss compact mana counter has no F6 rect** (match-rules and match-ui UI Requirements both list it). This spec places it in the right half of the boss hand strip 1136,262,120,28 at 100 % and inside the portrait at ≥ 125 % `text_scale`. Accept into match-ui F6? | Match UI GDD owner | Before `hud` story | Proposed here |
| **Top bar internal layout** (turn text x 24; floor/boss centred; 44x32 buttons at 1160,4 and 1212,4 with 44x44 hit rects y 0–44) — the pattern library's Gaps table assigns it here; confirm, then close the Gaps row. | Jacob / ux-designer | `/ux-review hud` | Proposed here |
| **Match toast anchor** 540,48,400,48 (the Toast pattern's "right, never over the intent banner" has no free right-side band on this grid). | Jacob / `toast.md` | `/ux-design toast` | Proposed here |
| Art bible §2 dims the player hand to `table_dark` during the boss turn; match-ui's Visual/Audio and States say nothing. This spec follows the art bible — add a row to match-ui Visual/Audio? | Match UI GDD owner + art-director pass | Pre-Production | Proposed here |
| interaction-patterns Mana Bar entry still quotes the superseded rect `1000, 676, 256, 32`; Treasure Chip says "≤ 4" chips; Segmented Select lists four `anim_speed` labels (DD-X07 has three). F6 / treasures.md / DD-X07 win here; the library rows need the edit (not made in this run). | ux-designer (`interaction-patterns.md`) | Before `/ux-review hud` | Open |
| card-effects UI Requirements "once-per-turn spent state — dimmed trigger icon on the card" has no projection row in match-ui U3 (I15). Either match-ui adds a step from the mark event or card-effects drops the row. | Card Effects + Match UI GDD owners | `/consistency-check` | Open |
| Fixtures this spec needs that match-ui U11 does not list: `boss_intent_hidden` (a concealment-passive boss or `telegraph_mode: off` in the fixture profile), and the settings variants (`text_scale` 1.25 / 1.5, `reduce_motion`, `high_contrast_states`) — proposal: the fixture JSON's profile `settings` block carries them (no new launch argument), named `<fixture>__ts150` etc. | Match UI GDD owner / `/qa-plan` | Before the first HUD story | Proposed here |
| Skip-hint delay (1 s) is prose in match-ui UI Requirements, not a `match_ui.json` key — add `SKIP_HINT_DELAY_S`? | Match UI GDD owner | Pre-Production | Open |
| Gamma slider (accessibility-requirements Visual) — needs a Meta M9 key before any UI shows it. | Meta Progression GDD owner + Jacob | Pre-Production | Open (inherited) |
| AccessKit live-region behaviour for toasts / feed lines — NOT SOURCEABLE from `docs/engine-reference/godot/` (accessibility-requirements, interaction-patterns). Until sourced, no screen-reader announcement is claimed by this spec. | ux-designer | Before first menu implementation | Open (inherited) |
| Keyword glossary overlay (accessibility Cognitive "Tutorial persistence") — not in any GDD; reachable from the pause menu would put it on this screen's `Esc` chain. | Jacob (assign Run UI or Match UI) | Pre-Production | Open (inherited) |
| Panel name / hero name sizes above 16 px are not in the art bible §4 typography table (placeholder v1); this document stays within the table — an art-director pass is owed before production (match-ui Visual/Audio says the same). | art-director | Alpha | Open |

**Focus Order (match `Idle`, `PlayerTurn.Main`, queue idle)** — the table match-ui U5 says this document owns; `Tab` inspects, `Enter` acts (Focus Management):

| # | Stop | Opens on focus | `Enter` / `Space` does |
|---|---|---|---|
| 1 | Hand cards, left → right (index 1–10; also `1`–`9`,`0` select directly into targeting) | Card Inspect preview (+ reading panel at ≥ 125 %) | Playable card → Click-to-Select / Keyboard Targeting; else nothing |
| 2 | Player row tokens, left → right | Card Inspect above the row | Legal attacker → targeting session; else nothing |
| 3 | Hero power button | Tooltip (name, cost, text, Blocked reason) | Ready → targeting session or confirm step; else nothing |
| 4 | Player portrait | Tooltip (name, health, armour, weapon) | Nothing |
| 5 | Treasure chips, left → right (0–3 stops) | Chip tooltip | Nothing |
| 6 | End Turn | — | End Turn when Enabled and armed |
| 7 | Feed toggle (top bar) | — | Toggle the drawer (focus enters the drawer only when opened by key) |
| 8 | Menu button (top bar) | — | Open the pause menu |
| 9 | Boss intent banner (or "?" plate) | Tooltip (full sentence) | Nothing |
| 10 | Boss row tokens, left → right | Card Inspect below the row | Nothing |
| 11 | Boss portrait | Tooltip (name, health, armour, weapon, passive text) | Nothing |
| → | wraps to 1 | | |

Not stops: piles, mana bar, boss hand / mana strip, top-bar text, turn banner, skip hint, floating numbers — all are text readouts with nothing hover-only. Default stop on entering `Idle`: End Turn when nothing is lit, else the left-most playable card; a played / burned focused card hands focus to the card now at its index, else End Turn (match-ui U5). Inside a targeting session `Tab` cycles legal targets / positions only; `Esc` leaves (Escape / Cancel chain step 1).
