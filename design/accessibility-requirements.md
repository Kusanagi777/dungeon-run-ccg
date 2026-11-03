# Accessibility Requirements

> Authoring guidance: .claude/docs/templates/guidance/accessibility-requirements-guide.md (load per-section as you author — do not read entirely).

> **Status**: Committed (tier committed 2026-11-03 under the owner's pre-approval for this `/ux-design accessibility` run; feature rows are Not Started until implemented)
> **Author**: Jacob + ux-designer (`/ux-design accessibility`, automation `guided`, workflow `standard`, density `balanced`; no `accessibility-specialist` agent spawned — no Agent tool in this run)
> **Last Updated**: 2026-11-03
> **Accessibility Tier Target**: Standard (with three Comprehensive-tier features elevated — see This Project's Commitment)
> **Platform(s)**: PC (Windows primary; Linux for development and CI). No console, no mobile, no web.
> **External Standards Targeted**:
> - WCAG 2.1 Level AA (contrast, text resize, keyboard operability, focus visibility — applied as design criteria, not as a conformance claim)
> - AbleGamers CVAA Guidelines — N/A (no communication features: single-player, no chat)
> - Xbox Accessibility Guidelines (XAG) — No (no Xbox release)
> - PlayStation Accessibility (Sony Guidelines) — No
> - Apple / Google Accessibility Guidelines — N/A (no mobile release)
> **Accessibility Consultant**: None engaged (solo portfolio project; AbleGamers Player Panel listed under External Resources as the option if budget appears)
> **Linked Documents**: `design/gdd/systems-index.md`, `design/ux/interaction-patterns.md`, `design/art/art-bible.md` §4, `design/design-decisions.md` (DD-T05, DD-X03, DD-X07, DD-X09, DD-X10), `.claude/rules/ui-code.md`
> **REVISED 2026-11-03 (ux-review)**: Motor rows "Hold-to-press alternatives", "Minimum target size" and "Accidental-activation guard" → Designed, citing match-ui U5 / F6 / Tuning Knobs; Matrix rows Treasures and Match UI → Designed; `sfx.ui.deny` feed line → Designed (match-ui U3.4a / U10); Open Questions click-to-select, `end_turn_arm_ms`, Esc priority (now DD-X09), Tab-in-idle, chip hit area and gamma → Resolved 2026-11-03, hover-only question split (match-ui resolved; card-effects and heroes still open); Cognitive "up to 4 treasures" → 3 (`MAX_TREASURES_HELD`); Brightness / gamma row → owner Meta M9 `gamma` + Run UI settings (DD-X10); Pause-anywhere row notes DD-X09. Toast rows already read 5–8 s and `anim_speed` rows already read `instant | fast | normal` — none left to change. Audit History gains a housekeeping row.
> **REVISED 2026-11-03 (ux-review rounds 2–3)**: round 2 — Matrix Heroes note cites heroes.md "Open / hover or focus"; Addressed column normalised to Yes / Partial; `cancel` / `Esc` excluded from the rebindable set (Motor, Open Questions); toast pause hover-only (or LMB hold), toasts take no focus. Round 3 — Test Plan "Reduce motion" pass criterion and the Visual `reduce_motion` row aligned with match-ui Tuning Knobs (`d_base` positional travel still plays; run-shell slides and toasts fade); Matrix Reward Draft note points at the designed reading panel (Partial only on the approval OQ), Run UI note names its remainder (glossary owner, pause music slider), Card Effects note names the card-effects.md lines as a GDD wording item. Audit History row added.
> **Template**: Accessibility Requirements

> **Why this document exists**: Per-screen accessibility annotations belong in
> UX specs. This document captures the project-wide accessibility commitments,
> the feature matrix across all systems, the test plan, and the audit history.
> It is created once during Technical Setup by the UX designer with
> `/ux-design accessibility` — you pick the tier, against the criteria
> accessibility-specialist sets and audits against — then updated as features
> are added and audits are completed. If a feature conflicts with a commitment
> made here, this document wins — change the feature, not the commitment,
> unless the producer approves a formal revision.
>
> **When to update**: After each `/gate-check` pass, after any accessibility
> audit, and whenever a new game system is added to `systems-index.md`.

> **Sources read for this document** (by section, per coordination rule 6):
> `game-concept.md` (platform, target player, pillars, MDA "Submission: turn-based, no timers");
> `design-decisions.md` DD-T05, DD-X03, DD-X07; `art-bible.md` §4 (tokens, WCAG ratios, state
> colours and their non-colour backups, typography floor, card slots) and §7; `match-ui.md`
> U4–U10, F2–F6, Visual/Audio, Game Feel, UI Requirements, Open Questions; `run-ui.md` U1–U10,
> F2–F4, Visual/Audio, Game Feel, UI Requirements; `boss-ai.md` C8 and UI Requirements;
> `rng-event-log.md` UI Requirements; `reward-draft.md` UI Requirements; `meta-progression.md`
> M9; `treasures.md`, `heroes.md`, `card-effects.md` hover rows (grep); `technical-preferences.md`
> Input & Platform; `docs/engine-reference/godot/current-best-practices.md` § Accessibility.
> `design/player-journey.md` does not exist — player context is taken from the concept's Target
> Player Profile and Flow State Design instead.

---

## Accessibility Tier Definition

This project commits to the **Standard** tier below, with three features elevated from the
Comprehensive tier because the design already requires them and they cost little in a
turn-based 2D card game. The tier is a floor, not a description of the whole plan: the feature
tables in the sections that follow are the binding list, and each row names the tier it
belongs to so a reader can tell "baseline" from "elevated" from "out of scope".

### Tier Definitions

| Tier | Core Commitment | Typical Effort |
|------|----------------|----------------|
| **Basic** | Critical player-facing text is readable at standard resolution. No feature requires color discrimination alone. Volume controls exist for music, SFX, and voice independently. The game is completable without photosensitivity risk. | Low — primarily design constraints |
| **Standard** | All of Basic, plus: full input remapping on all platforms, subtitle support with speaker identification, adjustable text size, at least one colorblind mode, and no timed input that cannot be extended or toggled. | Medium — requires dedicated implementation work |
| **Comprehensive** | All of Standard, plus: screen reader support for menus, mono audio option, difficulty assist modes, HUD element repositioning, reduced motion mode, and visual indicators for all gameplay-critical audio. | High — requires platform API integration and significant UI architecture |
| **Exemplary** | All of Comprehensive, plus: full subtitle customization (font, size, color, background, position), high contrast mode, cognitive load assist tools, tactile/haptic alternatives for all audio-only cues, and external third-party accessibility audit. | Very High — requires dedicated accessibility budget and specialist consultation |

### This Project's Commitment

**Target Tier**: Standard

**Rationale**: Deckdelve is a turn-based, single-player card battler for PC with a mouse-primary,
keyboard-complete input model (DD-T05, technical-preferences) and no timers anywhere in play
(concept MDA: "turn-based, no timers"), so the severe motor barriers of action games do not
exist and the cost of Standard's motor rows is small. The real barriers are **visual and
cognitive**: the game is read — card text at a 12 px floor on a 1280x720 logical viewport
(art bible §4), five saturated state colours including a red/green pair, a boss turn that
resolves many effects quickly, and a board that asks the player to track mana, hand, two rows,
treasures and the boss's intent at once. Standard's text scaling, a colourblind-safe state set
and "no timed input" address those directly; the Comprehensive items the design already needs
(reduce-motion, visual duplicates of every sound) are elevated below, while the Comprehensive
items a solo portfolio project cannot carry (screen reader, HUD repositioning, difficulty
assists) are listed as intentional limitations rather than promised. Dropping to Basic would
drop text scaling and the high-contrast state set, which excludes the ~8% of male players with
red/green colour-vision deficiency from reading damage vs buff at a glance and anyone who
cannot read 12 px rules text — the two groups most likely in the target audience (mid-core PC
card-game players, 18–40). Gamepad is `Partial` and post-v1 (technical-preferences), so the
Standard commitment is made for keyboard + mouse; the gamepad path is a documented limitation.

**Features explicitly in scope (beyond tier baseline)**:
- **Reduce-motion mode** (Comprehensive) — DD-X07 already stores `reduce_motion`; match-ui F3 and
  Game Feel drop hit-stop, screen shake and lethal slow-down under it; run-ui transitions are
  fades only. Elevated because the toggle exists and the remaining work is a list, not a feature.
- **Visual indicator for every gameplay-critical sound** (Comprehensive) — elevated because it is
  already true by construction: every SFX in match-ui and run-ui Visual/Audio tables is the
  audio half of an event that also has a visual row. The commitment here is to *keep* it true
  (the Gameplay-Critical SFX Audit below is the gate).
- **Selectable high-contrast state colour set** (the state-colour half of Exemplary's "high
  contrast mode") — `high_contrast_states` (DD-X07, meta-progression M9) swaps `state_danger` →
  `#FF8C42` and `state_buff` → `#4FA3FF` as the art bible §4 proposes; a theme change, not a
  code change. This is the project's "at least one colourblind mode". Full high-contrast
  *surfaces* (opaque panels, outlined controls) are **not** committed.
- **Animation speed / instant mode** — `anim_speed ∈ {instant | fast | normal}` (DD-X07; match-ui F3 maps the label to durations)
  plus skip-all on any input: a cognitive-pacing aid the tier table does not name, kept here
  so it cannot be cut as "polish".

**Features explicitly out of scope** (each also appears in Known Intentional Limitations):
- Screen reader support for menus (Comprehensive) — Godot 4.7's AccessKit integration covers
  stock `Control` nodes (engine reference), but every card, token and stamp is custom-drawn and
  would need accessible names and live regions. Not committed for v1; see Open Questions.
- HUD element repositioning (Comprehensive) — the match layout is a fixed reference grid
  (match-ui F6) that the hover preview, hand fan and targeting arrow are tuned against.
- Difficulty assist modes (Comprehensive) — bosses are hand-tuned puzzles (Pillar 2); banded
  health is content, not a slider.
- Gamepad parity (Standard's "all platforms" remapping) — v1 ships keyboard + mouse; the
  keyboard targeting mode is designed as the surface a gamepad maps onto later (match-ui U5).
- Subtitles and subtitle customisation — N/A: there is no voiced or spoken content.

---

## Visual Accessibility

Sizes below are **logical pixels at the 1280x720 viewport** (DD-T05, `canvas_items` stretch);
the template's 1080p figures convert at ×1.5, so its 24 px menu floor is 16 px here, its 20 px
critical-HUD floor is 13.3 px, and its 32 px subtitle floor does not apply (no subtitles).
Contrast ratios are the art bible's own WCAG 2.1 figures — this document does not re-derive
them and does not add colours.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum text size — menu / run screens | Standard | All Run UI base screens and overlays | Not Started | Buttons 16 px, screen titles 28 px, boss passive text 16 px (run-ui Visual/Audio), run-log rows ≥ 14 px, settings labels 16 px — all meet the 16 px (= 24 px @1080p) menu floor at `text_scale` 100%. Seed hex and timestamps in `text_muted` may be 13 px (secondary information). |
| Minimum text size — match HUD | Standard | Match HUD (portraits, mana, End Turn, feed, banners) | Not Started | Hero health 24 px, mana counter 16 px, End Turn 16 px, intent banner ≥ 16 px (match-ui F6 banner is 36 px tall — size the label 16 px), **event feed 13 px** — on the 13.3 px critical floor at 100%; the feed is a duplicate channel (the board is primary) and scales with `text_scale`. Nothing readable renders below 12 px (art bible §4 floor). |
| Minimum text size — card text | Standard | Cards in hand, draft options, deck drawer | Not Started | Card rules text is 12 px in a fixed 134x58 slot (art bible §4) — **below the 13.3 px critical floor on purpose**: the slot is a document thumbnail and the committed reading path is the **Card Inspect** pattern (interaction-patterns.md): 1.5x preview (18 px body) on hover *and* on keyboard focus. At `text_scale` > 100% the preview adds a reading panel (next row). A card must never be the only place its text can be read. |
| Text scaling (`text_scale`) | Standard | All UI text except the in-hand card thumbnail | Not Started | Discrete steps **100% / 125% / 150%** (DD-X07 key; run-ui settings row; three fixture-testable layouts rather than a continuous slider). Scales: Run UI screens, settings, toasts, tooltips, event feed, intent banner, mana counter, button labels, hero health, run summary tables. Does **not** scale the 150x210 card thumbnail or the 90x126 board token (fixed slots, art bible §4). Instead the Card Inspect preview shows the full card at 1.5x and, at 125%/150%, a parchment **reading panel** beside it with the rules text at 18 px × scale (22.5 / 27 px), unlimited lines, `text_ink` on `parchment` — so every card's full text is readable at the chosen scale. Layouts must not clip or overlap at 150%: each `/ux-design` screen spec names its 150% fixture (Accessibility Test Plan). WCAG 1.4.4 asks for 200%; the project commits to 150% because the 1280x720 reference grid (match-ui F6, run-ui F4) cannot hold 200% without re-partitioning — recorded as a Known Intentional Limitation. |
| Text contrast — UI text on backgrounds | Standard | All UI text | Not Started | Art bible §4 Text table: `text_light` on `bg_edge` 14.75 / `table_dark` 13.07 / `table_lit` 9.43 / `ink` 14.33; `text_muted` on `bg_edge` 7.94 / `table_dark` 7.03; `text_ink` on `parchment` 12.72; `text_ink_muted` on `parchment` 5.95. All ≥ 4.5:1. Rule: light text on dark, ink on parchment, no third text colour. New surfaces must be checked before use (test plan row 1). |
| Text contrast — state colours as numerals | Standard | Card stamps, floating numbers, data-error codes | Not Started | State colours sit as text **only on `ink`** (art bible rule a): `state_danger` 5.61, `state_buff` 7.16, `state_target` 10.65, `state_freeze` 8.86. Never on `parchment` (danger 2.27, buff 1.78, target 1.19 — all fail). High-contrast alternates `#FF8C42` and `#4FA3FF` must be re-measured on `ink` and on `table_lit` before the toggle ships (Open Questions). |
| Colorblind mode — Protanopia / Deuteranopia | Standard | All state-coloured UI | Not Started | One mode, `high_contrast_states` (DD-X07): danger → orange `#FF8C42`, buff → blue `#4FA3FF`, target/freeze/actionable unchanged. Separates the red/green pair by hue *and* by the glyph backups below. Verify every match fixture (match-ui U11) in Coblis with the toggle on and off. |
| Colorblind mode — Tritanopia | Standard | All state-coloured UI | Not Started | No separate palette. Risk pair under the high-contrast set: `state_freeze` `#5AC8E0` vs buff-alt `#4FA3FF` — both carry glyph backups (snowflake vs "+"/up-arrow) so meaning survives; verify in Coblis tritanopia on `midgame_full_board` and `divine_shield_hit`. |
| Color-as-only-indicator audit | Basic | All UI and gameplay | Not Started | See the table below. Every state colour in the art bible already names a non-colour backup; this audit adds the UI states the GDDs introduced (playable vs unaffordable card, focus vs hover, progress strip, rarity). |
| UI scaling | Standard | All UI | Not Started | Covered by `text_scale` (above) plus the window's `canvas_items` stretch: the whole UI scales with window size at fixed aspect. No independent HUD/menu scale slider. |
| High contrast mode | Comprehensive | — | Out of scope | Only the state-colour set is committed (toggle above). Full opaque-panel high contrast is a Known Intentional Limitation. |
| Brightness / gamma controls | Basic | Global | Designed (DD-X10) | Owner: **Meta Progression M9 `gamma`** (float 0.8–1.4, default 1.0) stored in the profile; **Run UI `settings`** exposes the slider (step 0.05, live preview swatches); Match UI and Run UI apply it as a `CanvasModulate` brightness adjustment — colour tokens are never changed, so the art bible §4 ratios hold at 1.0 and the test plan's contrast check runs at the default. The game is dark by design (art bible §2 "torch pool"), which makes this more important, not less. |
| Screen flash / strobe warning | Basic | All VFX | Not Started | No full-screen flashes exist: the brightest transient is the 3 px, 120 ms screen shake and a 2-frame card shake. Rule for production: no element may alternate luminance more than 3 times per second; the victory portrait saturation is a single 400 ms ramp. A pre-launch photosensitivity screen is **not** required at this flash budget — re-audit if any strobe-like VFX is added. |
| Motion / animation reduction mode (`reduce_motion`) | Comprehensive (elevated) | Match UI, Run UI | Not Started | Under `reduce_motion`: no hit-stop, no screen shake, no lethal slow-down (match-ui F3, Impact Moments); no card-lift bounce; `reject_shake` becomes a 2-frame outline flash; slides (fly-to-strip, draft reveal stagger, toast slide) become fades at half duration; match-ui's positional gameplay travel (card-to-slot, attack lunge, draw, death drop — match-ui Tuning Knobs `reduce_motion`, `d_base` unchanged) is kept because its end position is information; the hover preview appears with a half-duration fade, no travel; looping indicators (skip hint pulse, intent `lethal` pulse) become static. Independent from `anim_speed` — a player may want slow *and* still. |
| Subtitles — on/off | Basic | — | N/A | No voiced content. Boss intro lines are on-screen text already. |
| Subtitles — speaker identification | Standard | — | N/A | No voiced content. |
| Subtitles — style customization | Comprehensive | — | N/A | No voiced content. |
| Subtitles — sound effect captions | Comprehensive | — | Not required | Every SFX has a visual twin (Gameplay-Critical SFX Audit). |

### Color-as-Only-Indicator Audit

> Fill in every gameplay or UI element where color is currently the sole
> differentiator. Resolve each before shipping. A resolved entry has a non-color
> backup that works in all three colorblind modes above. See guide for example rows.

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| Health / durability stamp numeral | `state_danger` | Value is below max; hero in lethal range | Leading "−" on the change pop; crack glyph on the stamp while below max; numeral itself is the readout (art bible §4) | Designed (art bible) |
| Attack / health numeral | `state_buff` | Value is above printed | Leading "+" on the pop; up-arrow glyph beside the numeral | Designed (art bible) |
| Legal target / hovered target | `state_target` | Can be dropped on / attacked | The arrow itself; 3 px ring on the hovered or focused target (shape is primary) | Designed (art bible, match-ui U7) |
| Frozen / Silenced token | `state_freeze` outline | Cannot act / text removed | Snowflake glyph (Freeze); slash glyph + grey-out (Silence); badge row on the token (match-ui UI Requirements) | Designed (art bible) |
| Actionable control (playable card, legal attacker, End Turn ready, Fight, Pick) | `state_actionable` 2 px outline | Can be used now | The outline is `#F2E9D8` light, not a hue; hand cards also lift 8 px; End Turn's label stays, only its outline changes | Designed (art bible UI palette) |
| Unaffordable card in hand | Dimmed (no outline) | Cost > mana | Cost stamp numeral and the mana counter "n/m" are both visible; dimming is a value change, not a hue; **add**: the cost stamp ring switches to `text_muted` dashed when unaffordable (proposed, `/ux-design hand`) | Open |
| Keyboard focus vs mouse hover | Both use the light outline | Which element Enter/Space will act on | **Rule (interaction-patterns Focus Management)**: focus = 2 px `state_actionable` outline offset 3 px; hover = 8 px lift without ring; hovered + focused shows both | Designed (this pass) |
| Hero identification (War / Decay / Knowledge) | Hero primary / secondary | Whose card or portrait | Hero initial letter in v1, silhouette family later (art bible §3); War and Decay primaries also differ in value | Designed (art bible) |
| Boss band (floors 1–3 / 4–6 / 7–8) | Ochre / rust / slate-violet | Difficulty band | 1–3 band pips (run-ui `boss_intro`); "Floor n of F" text; boss health number | Designed (run-ui) |
| Progress strip nodes | Band colour on current / upcoming | Cleared vs current vs upcoming | Filled (cleared, boss initial) / ringed (current) / hollow (upcoming) — three shapes | Designed (run-ui U6) |
| Treasure rarity | Rarity pill colour | Common vs Rare | The word "Common"/"Rare" in the pill (treasures.md UI Requirements) | Designed (treasures) |
| Draft "fits your plan" / synergy | None (text hint) | Option affinity | Text under the focused/hovered option (run-ui U3); not colour-coded | Designed (run-ui) |
| Boss intent `lethal` | `state_danger` pulse | Boss can kill you next turn | Intent icon per `intent_key` + amount + target reticle + the word (boss-ai UI Requirements); pulse static under `reduce_motion` | Designed (boss-ai, match-ui) |
| Victory vs defeat summary | Portrait saturates / torch out | Outcome | Headline text ("Floors cleared F of F" / "Fell on floor n") | Designed (run-ui U9) |
| Data-error codes | `state_danger` on `ink` pills | Validation failure code | The code text itself; row count in header | Designed (run-ui) |
| Unlock toast swatch | Hero/treasure colour swatch | Which hero/treasure | Name text is the content; swatch is decoration (run-ui Visual/Audio) | Designed (run-ui) |
| Taunt / Divine Shield / Stealth / Windfury / Poisonous / Lifesteal / summoning-sick badges | Badge glyphs | Keyword state | Glyphs (letters in v1) — not colour-coded; **rule**: no two badges may differ by colour alone | Designed (match-ui UI Requirements) |

---

## Motor Accessibility

Input model (DD-T05, technical-preferences, match-ui U5, run-ui U3): mouse primary, keyboard
complete, gamepad post-v1, touch none. Turn-based with no timed input anywhere; the only
hold input is the drag-to-play gesture, and the only chord is `Shift+Tab`.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Full input remapping | Standard | All keyboard shortcuts (interaction-patterns "Standard Shortcuts") | Not Started (Alpha) | Every shortcut is a Godot `InputMap` action (`end_turn`, `skip`, `hero_power`, `feed_toggle`, `attacker_mode`, `hand_1`…`hand_10`, `option_1`…`option_3`, `focus_next`, `focus_prev`); a Controls page in `settings` rebinds them with conflict warning and "Reset to defaults"; bindings persist in the profile (needs a Meta M9 key — Open Questions). **`cancel` (`Esc`) is never rebound** — it is fixed like the mouse buttons so the Escape / Cancel chain (interaction-patterns "Escape / Cancel", "Standard Shortcuts") always has one guaranteed key, which is what makes a bad rebind recoverable. Mouse buttons are fixed (LMB act, RMB cancel) because RMB is never the only path (Esc duplicates it). MVP ships defaults only; remapping lands by Alpha. |
| Input method switching | Standard | PC | Not Started | Keyboard and mouse are simultaneous, not modes: a drag can be cancelled with Esc, a keyboard-targeting session can be finished with a click (match-ui `KeyTargeting` accepts a click on a lit target). No prompt-icon swapping is needed until gamepad arrives. |
| One-hand mode | Standard | Whole game | Not Started | **Mouse-only** and **keyboard-only** must each complete a full run (run-ui Feel AC; match-ui O17). Mouse-only requires the click-to-select alternative to drag (next row). Keyboard-only: all sequences are sequential (`A` then a number; number then `Tab` then `Enter`), the one chord `Shift+Tab` is optional because `Tab` cycles. |
| Hold-to-press alternatives | Standard | Drag-to-play, drag-to-attack, drag hero power | Designed (match-ui U5 "Click to select", `CLICK_DRAG_PX` 8 px in Tuning Knobs) | **Click-to-select** (interaction-patterns "Click-to-Select / Keyboard Targeting"): a press-and-release under `CLICK_DRAG_PX` on a playable card, legal attacker or `Ready` hero power enters the same `KeyTargeting` state the number keys use (`entered_by = pointer`); legal slots/targets light; click a target or `Enter` submits; click elsewhere, RMB or Esc cancels; a single click never plays a card. No other hold inputs exist (no hold-to-confirm, no hold-to-skip). |
| Rapid input alternatives | Standard | — | N/A | No input requires more than one press; skip-all is a single press. |
| Input timing adjustments | Standard | — | N/A by design | No QTEs, no timed choices, no turn timer (concept MDA). Boss-turn playback is watch-only and skippable; `MATCH_END_AUTO_S` (4 s) advances to a summary that repeats everything the banner said (Cognitive, "Reading time"). |
| Aim assist | Standard | Targeting | N/A | Targets are discrete 90x126 tokens and 120x160 portraits; the drop zone is the whole token; keyboard cycling removes pointing entirely. |
| Auto-sprint / movement assists | Standard | — | N/A | No movement. |
| Platforming / traversal assists | — | — | N/A | No platforming. |
| HUD element repositioning | Comprehensive | — | Out of scope | Fixed reference grid (match-ui F6). Known Intentional Limitation. |
| Minimum target size | Standard | All interactive elements | Designed (match-ui F6 treasure tray row) | ≥ 44x44 logical px hit area. Checked: hero power 48x48, End Turn 140x44, tokens 90x126, cards 150x210, strip nodes non-interactive. Treasure tray chips: 40 px visual with a **44x44 hit rect** centred on each chip (chip centres 48 px apart, so hit rects never overlap; tray hit zone 22, 500, 140, 44 — match-ui F6, O18 measures it). Feed ticker lines (13 px tall) are not click targets — the drawer toggle is. |
| Accidental-activation guard — End Turn | Standard | Match | Designed (match-ui U5 "Arm guard", Tuning Knobs `end_turn_arm_ms` 300 ms, safe range 150–600) | `Space`/`Enter` is both skip-all and End Turn (match-ui U5). A skip press that lands the frame the queue drains would end the turn. **Rule**: End Turn by key is armed only after the queue has been idle for `end_turn_arm_ms` (300 ms, `match_ui.json`); a click on the button is never gated; a press inside the window is swallowed (match-ui Edge Cases). |
| Double-activation guard | Standard | Draft Pick, Start, Fight, Continue | Designed | run-ui U4 `committed` sub-state makes a double-click one pick; match-ui U4.7 flushes then submits once. |

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Difficulty options | Standard | — | Fixed by design | No difficulty slider: bosses are authored puzzles (Pillar 2) in three bands with banded health (DD-M02). Justification: a damage multiplier would turn "read the passive" into "out-stat the passive" and void Pillar 2. The assist the game *does* offer is pacing: `anim_speed`, `action_delay_ms`, skip-all, and an unlimited think time. Documented as a Known Intentional Limitation. |
| Pause anywhere | Basic | All states | Designed | Match: pause menu (`Esc` with nothing open) in every phase except `Ended`, including during boss playback (match-ui U9; on the end banner `Esc` does nothing — DD-X09 — and the banner's Continue / 4 s auto-advance is the only exit). Run: `pause` overlay on every run screen (run-ui U2). The game is turn-based, so "pause" never races anything; the one state without a pause is the 600 ms `run_start` card, which any input skips. |
| Tutorial persistence | Standard | Keywords and rules | Not Started | There is no tutorial in v1 (concept). The persistent help the game needs is a **keyword glossary** (Taunt, Charge, Rush, Divine Shield, Windfury, Stealth, Lifesteal, Poisonous, Freeze, Silence, Battlecry, Deathrattle, Spell Damage, Discover, Aura — DD-M09) reachable from the pause menu and settings, plus keyword reminder text in the Card Inspect reading panel. **Not in any GDD** — Open Questions. |
| Quest / objective clarity | Standard | Boss passive, floor, intent | Designed | Boss passive text is the brightest element of `boss_intro` (run-ui U2) and lives on the boss portrait's passive plate in the match (match-ui UI Requirements); "Floor n of F" on the top bar; boss intent banner forecast every player turn (boss-ai C8). All within one glance, zero presses. |
| Visual indicators for audio-only information | Standard | All SFX | Designed | See Auditory — every sound is the audio half of a visible event. |
| Reading time for UI | Standard | Toasts, rejection tooltip, match-end banner, "boss discovers…" | Not Started | Inventory of auto-dismissing elements: **unlock / warning toast** 5–8 s (run-ui F3 `toast_min_ms` 5000, `toast_max_ms` 8000 — resolved 2026-11-03, meets the 5 s floor), hover (or LMB hold) pauses the timer — toasts never take focus, so there is no focus pause; acceptable because the toast is never the sole channel, making the pause a convenience, not information — click dismisses, and any *actionable* warning (`save_failed`, `boss_pool_short`) also persists in a non-toast place (main-menu status line / run summary) so the toast is never the sole channel; **rejection tooltip** 1.5 s (match-ui U5) — acceptable only because the rejection is also written to the event feed as a `command_rejected` line (requirement; feed retains 200 lines); **match-end banner** 4 s auto-continue — acceptable because the run summary that follows repeats the result and the player may click earlier; **"boss discovers…"** 0.4 s label — informational only; **skip hint** appears after 1 s and stays. All three durations are data-file knobs, not constants. |
| Cognitive load documentation | Comprehensive | Per system | Partial | Match asks the player to track: own mana, up to 10 hand cards, 7 + 7 board tokens with badges, two heroes' health/armour/weapons, boss intent, up to 3 treasures (`MAX_TREASURES_HELD`, treasures.md) — more than 4 things, which triggers review. Compensations already designed: legal-move highlighting before any commitment (match-ui U5), the targeting arrow shows legality before release, the event feed as a readable log (rng-event-log UI Requirements, Pillar 4), the intent banner, hover/focus preview of any card, unlimited think time, skip-all and `anim_speed`. Run screens track ≤ 3 things each (hero / floor / offer). See Per-Feature Matrix. |
| Navigation assists | Standard | — | N/A | No world navigation. The progress strip (run-ui U6) is the only "map" and is always visible on run screens. |
| Telegraph verbosity (`telegraph_mode`) | — | Boss intent banner | Open | DD-X03 defines `full / brief / off` as a player setting; `full` is the default and is the accessible setting. `off` is a self-imposed challenge, never a default. Owner of the semantics is open across match-ui / boss-ai / meta (meta-progression Open Questions) — this document only requires that the default stay `full` and that `brief` still names the action class. |

---

## Auditory Accessibility

Audio is minimal (concept: "card play, attack, win/lose stingers; one ambient track") and
carries no unique information. Buses are master / music / SFX (meta M9) — there is no voice
bus because there is no voice; UI sounds share the SFX bus.

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Subtitles for all spoken dialogue | Basic | — | N/A | No spoken dialogue. Boss intro lines are text. |
| Closed captions for gameplay-critical SFX | Comprehensive | — | Not required | Audit below finds no SFX whose information is not already on screen. Re-run the audit whenever `/asset-spec` adds a sound. |
| Mono audio option | Comprehensive | Global | Out of scope (v1) | Stereo positioning is not used to convey anything (no off-screen events; the board is always fully visible), so mono is a comfort option, not an information one. Evaluate for post-v1; Known Intentional Limitation. |
| Independent volume controls | Basic | master / music / SFX | Designed | Three sliders 0–1 (meta M9 `volume_*`), in settings and the match pause menu (match-ui U9 lists master/SFX; **music must be added** to the pause quick-access for parity — minor, `/ux-design pause-menu`). Four buses (voice, UI) are not needed at this audio scale. |
| Visual representations for directional audio | Comprehensive | — | N/A | Nothing happens off-screen. |
| Hearing aid compatibility mode | Standard | All cues | Designed | No cue is high-frequency-only *and* informational; `sfx.ui.heartbeat` (fatigue) is low-frequency and twinned with the "Fatigue N" label. Audit new SFX against this at `/asset-spec`. |

### Gameplay-Critical SFX Audit

> Identify every sound effect that communicates state the player needs to act on.
> Each entry in this table requires either a confirmed visual backup or a caption.
> See guide for example rows.

| Sound Effect | What It Communicates | Visual Backup | Caption Required | Status |
|-------------|---------------------|--------------|-----------------|--------|
| `sfx.ui.card_lift` / `card_play` | Card picked up / played | Card lifts 8 px; travels to slot with squash (match-ui Visual/Audio) | No | Designed |
| `sfx.ui.attack_whoosh`, `impact_light/heavy` | Attack landed, heavy if ≥ 5 | Lunge animation; damage pops; hit-stop | No | Designed |
| `sfx.ui.damage` / `heal` | Value changed | `−n` / `+n` pop on `ink` pill; stamp recolour with glyph | No | Designed |
| `sfx.ui.shield_pop` | Divine Shield consumed | Ring burst; badge removed | No | Designed |
| `sfx.ui.death_thud` | Minions died | Tokens fade and drop; gap-close; feed line | No | Designed |
| `sfx.ui.draw` / `burn` / `heartbeat` | Drew / burned a card / fatigue damage | Card slides to hand / dissolves over deck / "Fatigue N" label + damage pop | No | Designed |
| `sfx.ui.end_turn` / `turn_chime` | Turn ended / boss turn began | Button depress; turn banner in band colour | No | Designed |
| `sfx.ui.page_turn` / `plan_changed` | Intent shown / boss changed plan | Intent banner; "plan changed" label for `plan_changed_s` | No | Designed |
| `sfx.ui.deny` | Command rejected | 0.2 s shake + `reject.<code>` tooltip + related control flash + `feed.command_rejected` feed line (match-ui U3.4a; U10 keys it `feed.<type>`) | No | Designed |
| `sfx.ui.overlay` | Choice / mulligan / menu opened | Table dims; cards scale in | No | Designed |
| `sfx.ui.victory` / `defeat` | Match result | End banner; portrait saturation | No | Designed |
| `ui_hover`, `ui_select`, `ui_pick` | Focus moved / selected / picked | Focus outline; lift; `committed` lock + others dim | No | Designed |
| `ui_draft_reveal` | Offers revealed | Three options appear (staggered or at once) | No | Designed |
| `ui_unlock` | New hero / treasure unlocked | Unlock toast; also listed on the summary and hero select | No | Designed |
| `run_start`, `boss_intro_<band>` | Run began / boss introduced | Full screens | No | Designed |
| `run_victory` / `run_defeat` | Run ended | Summary screen | No | Designed |
| `music.match_ambient` | — (mood) | None needed | No | Designed |

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| Xbox (GDK) | Xbox Game Core Accessibility / XAG | — | N/A | No Xbox release. |
| PlayStation 5 | Sony Accessibility Guidelines / AccessibilityNode API | — | N/A | No PlayStation release. |
| Steam (PC) | Steam Accessibility Features / SDL | — | N/A | Distribution is itch.io (concept). If a Steam build appears, Steam Input remapping would be in addition to, not instead of, in-game remapping. |
| iOS | UIAccessibility / VoiceOver | — | N/A | No mobile release. |
| Android | AccessibilityService / TalkBack | — | N/A | No mobile release. |
| PC (Screen Reader) | AccessKit via Godot 4.7 (`docs/engine-reference/godot/current-best-practices.md` § Accessibility; `breaking-changes.md`: `Control.accessibility_live` is typed `AccessibilityServer.AccessibilityLiveMode` in 4.7) | Not committed (out of tier). **Do not block it**: use stock `Button`, `CheckButton`, `HSlider`, `LineEdit`, `ItemList` for settings, menus, run log and dialogs so they expose names and roles for free; give every custom-drawn card/token `Control` a `tooltip_text`/accessible name string that equals its Card Inspect text. | Not Started | Whether AccessKit announces live-region changes (toasts, feed lines) without focus is **NOT SOURCEABLE** from `docs/engine-reference/godot/` beyond the `accessibility_live` property's existence — see Open Questions. |
| PC (OS display settings) | Windows text scaling / high-contrast themes | None inherited — Godot renders its own UI; the game's own `text_scale` and `high_contrast_states` are the equivalents. | Not Started | Document in the itch.io page that OS settings do not apply inside the game. |

---

## Per-Feature Accessibility Matrix

> When a new system is added to systems-index.md, a row must be added here. If a
> system has an unaddressed accessibility concern, it cannot be marked Approved
> in the systems index. See guide for example rows.

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| Card Database | None (no UI) — but validation report is shown by Run UI `data_error` | None | Error report must be copyable, not transcribed | None | Yes | "Copy report" button exists (run-ui U2) |
| RNG & Event Log | Seed hex at `text_muted` 13 px | Copy seed must be a button, not a selection drag | Event feed is the readable log (Pillar 4) | None | Yes | Copy button exists (run-ui U9) |
| Match Rules | State colours on stamps (danger/buff) | None (pure logic) | Resolution ordering must be legible in the feed; deaths grouped per cause | None | Yes | Non-colour backups per art bible; feed grouping match-ui U10 |
| Card Effects | Scaled spell damage shown "while hovering" (card-effects UI Requirements); aura attribution tooltip "on hover" | None | Chains and auras are the hardest thing to follow | None | Partial | Both hover rows must also show on keyboard focus (Card Inspect) — covered by the pattern and by `hud.md` (hover **or** focus); the gap is GDD wording only: card-effects.md UI Requirements still reads "while hovering" / "On hover" (lines ~1124 / 1199 / 1204) — a Card Effects GDD item routed via `/consistency-check` (Open Questions), not a UX-spec gap; the row stays Partial until that edit lands |
| Boss AI | Intent banner colour pulse on `lethal` | None | `intent_mode: hidden` (band 3 only) removes the forecast — a deliberate difficulty element, recorded per boss in Content | None | Yes | Icon + text + amount; pulse static under `reduce_motion`; `telegraph_mode` default `full` |
| Heroes | Hero colours are identification only | None | Hero power text must be readable at select and in match | Hero select sting is decoration | Yes | Initial letter / silhouette backup; power tooltip on hover **and focus** (heroes.md UI Requirements reads "Open / hover or focus" — amended 2026-11-03; Card Inspect pattern gives the mechanism) |
| Run Structure | Band colour for floor progress | None | Abandon counts as a loss — must be stated before confirming | None | Yes | Pips + text; confirm dialog states consequence (run-ui U2) |
| Reward Draft | Three options compared at once; synergy hint | Pick is select-then-confirm (no accidental pick) | Reading three bundles × 3 cards is the densest read in the game | None | Partial | `1/2/3` + Enter; hint on focus; `text_scale` reading panel for compact card rows **designed** in `draft-picker.md` §5.3 / §12 (fixture `draft_bundle_sample_ts150`; library Compact Card Row contract) — Partial only until the reading-panel path is approved (Open Questions "`text_scale` vs the fixed 134x58 card text slot"); flip to Yes on that resolution |
| Treasures | Rarity colour; 40x40 chips | Chip hit area (44x44 on a 40 px visual) | Treasure text only on chip tooltip in match | None | Yes | Designed (match-ui F6 / U5 / O18): rarity word present; 44x44 hit rect per chip and the tooltip on hover **or focus** (`--pose=focus:treasure:<n>`) |
| Meta Progression | None (no UI) | Typed confirmation for Reset profile requires typing a word | Destructive actions need plain-language consequence lines | None | Yes | Typed token is the one destructive action (meta M1.1); acceptable because it is a once-ever action, and the word is shown on screen |
| Match UI | 12 px card text; five state colours; animation density | Drag plus click-to-select; Space/Enter overload guarded | Boss turn pacing; many things to track | All SFX twinned | Yes | Designed in match-ui.md 2026-11-03: Card Inspect on focus (U5 "Keyboard inspect"); click-to-select (U5, `CLICK_DRAG_PX`); `end_turn_arm_ms` (U5, Tuning Knobs); `feed.command_rejected` line (U3.4a); 44x44 chip hit rect (F6); `Esc` on the end banner does nothing (DD-X09) |
| Run UI | Toast 5–8 s (run-ui F3); seed in `text_muted` | None | Defeat summary must say why you lost | All SFX twinned | Partial | `toast_min_ms` 5000 met (run-ui F3); keyboard-complete per U3; "why you lost" designed in `run-summary.md` (headline + reason line + ringed killing cell with tooltip). **Remainder**: the keyword glossary overlay has no owner (Open Questions) and the pause-menu music slider is open — both Run UI settings / overlay items; Yes when both resolve |
| Content | Boss `intent_mode: class_only / hidden` per boss; card text length vs the 4-line slot | None | 16 bosses × passives to learn | None | Yes | Reading panel removes the line cap; hidden intent recorded with a reason per boss (boss-ai C8.4) |

---

## Accessibility Test Plan

Evidence rule (coding-standards): visual and UI evidence is a **retained screenshot** in
`production/qa/evidence/`; the fixtures named are match-ui U11 and run-ui U10 debug entry
points, which is what makes these tests repeatable headlessly.

| Feature | Test Method | Test Cases | Pass Criteria | Responsible | Status |
|---------|------------|------------|--------------|-------------|--------|
| Text contrast ratios | Automated — contrast check of every text/background token pair in the theme resource, plus a screenshot sampler over the fixture set | Every pair in art bible §4 Text and State tables, both `high_contrast_states` values; every new pair a UX spec introduces | Body text ≥ 4.5:1; large text and non-text boundaries ≥ 3:1; no state colour as text on `parchment` | ux-designer | Not Started |
| Colour-as-only-indicator | Manual — Coblis (protanopia, deuteranopia, tritanopia) on fixture screenshots with the toggle off and on | `midgame_full_board`, `divine_shield_hit`, `targeting_taunt`, `boss_intent_full`, `draft_bundle_sample`, `mid_run_floor4`, `victory_sample`, `defeat_sample` | Every row of the audit table is distinguishable by its backup in all three simulations | ux-designer | Not Started |
| Keyboard-only completion | Manual — unplug the mouse; complete hero select → mulligan → a full match incl. a Discover and a targeted spell → both drafts → summary → new run | Full run at F = 4 (MVP) and F = 8 | Every mouse-reachable state reached (match-ui O17 screenshots match); run-ui Feel AC "keyboard-only tester completes a full run" | qa-tester | Not Started |
| Mouse-only completion with click-to-select | Manual — no keyboard; play a match using click-to-select only (no drags) | `turn1_player` → full match | Every play, attack and hero power is issuable without a sustained button hold; Esc-less cancel works via RMB and click-away | qa-tester | Not Started |
| Text scale 100 / 125 / 150 | Automated screenshots — every base screen and overlay fixture at each step | All run-ui U10 fixtures; match fixtures `hand_10`, `boss_turn_playback`, `--pose=feed:open`, `--pose=hover:<id>` | No clipped or overlapping text; no horizontal scroll; Card Inspect reading panel shows full rules text at 150% | ux-designer | Not Started |
| Reduce motion | Manual + automated — `reduce_motion = true`; play a boss turn with lethal, a draft reveal, a toast | `boss_turn_playback`, `draft_bundle_sample`, `toast_sample` | No shake, hit-stop, slow-down, run-shell slide or looping pulse; run-shell and toast transitions are fades; match-ui positional travel (card-to-slot, lunge, draw, death drop) still plays with `d_base` unchanged; final display equals view-state | ux-designer | Not Started |
| Instant animation equivalence | Automated — match-ui AC L6 (`_assert_in_sync` after skip at every step index) | Recorded event streams for all match fixtures | Presenter state equals `MatchViewState` after every skip; zero diffs | qa-tester (CI) | Not Started |
| Input remapping | Manual — rebind every action to non-default keys; complete a match and a draft | Controls page; conflict case; reset to defaults | All actions usable after rebind; conflict warned; bindings persist across restart | qa-tester | Alpha |
| Reading time | Automated — read `toast_min_ms`, `toast_max_ms`, `REJECTION_TOOLTIP_S`, `MATCH_END_AUTO_S` from data and assert the floors above; manual — hover (or LMB hold) pauses a toast (toasts take no focus, so no focus case) | `toast_sample`; `--pose=reject:NOT_ENOUGH_MANA` | Toast ≥ 5 s and pausable by hover; rejection appears in the feed drawer | qa-tester | Not Started |
| Target sizes | Automated — walk every focusable `Control` in each fixture and assert hit-rect ≥ 44x44 | All fixtures | No interactive element under 44x44 logical px | qa-tester | Not Started |
| Focus visibility and order | Manual — Tab through every screen; screenshot each focus stop | All run-ui fixtures; match idle, `KeyTargeting`, each overlay | Focus ring visible at every stop; order matches the screen's UX spec Focus Order table; modals trap focus and return it | ux-designer | Not Started |
| Stock-control screen reader smoke | Manual — NVDA on Windows; navigate main menu, settings, confirm dialog, run log | `fresh_profile`, `locked_heroes` | Stock controls announce name/role/state (informational — not a tier commitment) | ux-designer | Not Started |
| User testing — colour vision | User testing with ≥ 2 colour-vision-deficient players | One full run each, toggle on | No request for colour clarification; both read damage vs buff correctly | producer (Jacob) | Not Started |

---

## Known Intentional Limitations

> Every entry here is a risk — assess it honestly. See guide for example rows.

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| Gamepad parity | Standard ("all platforms") | technical-preferences marks gamepad `Partial`, post-v1; the solo schedule puts keyboard parity first | Players who play PC with a controller (couch setups, some motor-impaired players) have no v1 path | Keyboard targeting mode is designed as the gamepad surface (match-ui U5); run-ui U3 already maps `ui_accept`/`ui_cancel`/d-pad; no v1 decision may make a 1:1 mapping impossible |
| Screen reader support (menus and game) | Comprehensive | Custom-drawn cards and tokens need accessible names, roles and live regions; unverified AccessKit live-region behaviour (NOT SOURCEABLE from the engine reference) | Blind and low-vision players cannot play; low-vision players are partially served by `text_scale` and Card Inspect | Stock controls for all menus/dialogs (free announcements); every custom Control carries its inspect text as its accessible name so a later pass is wiring, not redesign |
| HUD element repositioning | Comprehensive | Fixed 1280x720 reference grid (match-ui F6) that the fan, preview and arrow are tuned to | Players with reduced peripheral vision or eye-gaze hardware cannot bring elements together | Layout keeps the hand, End Turn and mana in the lower band and both portraits at the sides; intent banner sits beside the boss, not across the screen |
| Difficulty assist modes | Comprehensive | Pillar 2: bosses are puzzles; a damage slider would void the design | Players who cannot win the hard band do not see floors 7–8 | Unlimited think time, telegraphed intents, pacing controls; "lose fast, learn fast" keeps retries cheap (< 5 s to restart) |
| Text scaling above 150% | Standard (WCAG 1.4.4 names 200%) | The reference grids cannot hold 200% without re-partitioning | Players needing 200% get 150% plus the reading panel | Reading panel has no line cap; window scaling (`canvas_items`) multiplies on top of `text_scale` on larger displays |
| Full high-contrast surface mode | Exemplary | Only the state-colour set is swappable | Low-vision players who need opaque panels and outlined controls | All text already ≥ 5.9:1; panels are opaque by art direction (no translucency in v1) |
| Mono audio | Comprehensive | Not in v1 settings; stereo carries no information | Single-sided-deafness players lose nothing informational, only comfort | Evaluate post-v1 |
| Dyslexia-friendly / custom font | — | v1 uses Godot's default font (art bible §4); no font pipeline | Players with dyslexia | `text_scale`, generous line height 1.3, ink-on-parchment; font swap is a theme change later |
| Continuous UI scale slider | Standard | Three discrete `text_scale` steps keep layouts fixture-testable | A player whose ideal is 115% picks 125% | Window scaling provides continuous size at fixed aspect |

---

## Audit History

> See guide for example rows.

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| 2026-11-03 | Internal — ux-designer (`/ux-design accessibility`, this document's authoring pass) | Design review against GDDs | match-ui, run-ui, boss-ai, reward-draft, rng-event-log, treasures, heroes, card-effects UI rows; art bible §4/§7 | 9 findings routed to GDD owners: toast floor 2 s vs 5 s (run-ui F3); no click-to-select alternative to drag (match-ui U5); Space/Enter skip vs End Turn race (match-ui U5); Esc "close overlay" step on non-cancellable overlays (match-ui U5 vs U9); hover-only rows (match-ui hero power "Blocked", card-effects aura/spell-damage, heroes power tooltip); treasure chip 40 px hit area; `text_scale` vs fixed card text slot; no gamma control in any settings list; no keyword glossary. All logged under Open Questions. | Open |
| 2026-11-03 | Internal — housekeeping pass | Cross-document alignment | Reading time rows, Per-Feature Matrix Run UI row, `anim_speed` enum | Toast duration rows updated to run-ui F3's resolved 5–8 s; `anim_speed` enum aligned to DD-X07 (`instant \| fast \| normal`); toast Open Question marked resolved. | Closed |
| 2026-11-03 | Internal — housekeeping after `/ux-review` (hud, interaction-patterns, draft-picker, hero-select, run-summary) | Status sync with match-ui.md / DD-X09 / DD-X10 | Motor rows, Matrix Treasures + Match UI, SFX `sfx.ui.deny`, Cognitive load count, Brightness/gamma owner, Open Questions | Click-to-select, `end_turn_arm_ms`, Esc priority (DD-X09), Tab-in-idle and chip hit area moved to Designed / Resolved against match-ui U5 / F6 / Tuning Knobs; hover-only question split (match-ui done; card-effects and heroes open); treasures counted as 3 (`MAX_TREASURES_HELD`); gamma owned by Meta M9 + Run UI settings (DD-X10). Verified no toast row below 5–8 s and no `anim_speed` row outside `instant \| fast \| normal` remained. | Closed |
| 2026-11-03 | Internal — housekeeping after `/ux-review` rounds 2–3 (accessibility-requirements, interaction-patterns, hero-select, run-summary) | Cross-document alignment | Matrix Heroes / Reward Draft / Run UI / Card Effects notes, Motor remapping exception, Reading time pause, Visual `reduce_motion` row, Test Plan "Reduce motion" | Round 2: Heroes note cites heroes.md "Open / hover or focus"; Addressed column Yes / Partial only; `cancel` / `Esc` excluded from remapping; toast pause hover-only. Round 3: "Reduce motion" pass criterion no longer fails the match's kept positional travel (match-ui Tuning Knobs `reduce_motion`, `d_base` unchanged) and the feature row says the same; Reward Draft Partial rests only on the reading-panel approval OQ; Run UI Partial names its remainder; Card Effects Partial is the card-effects.md hover-only wording (GDD item). Per-screen 44x44 and 150 % findings (hero-select panel interior, run-summary Copy seed) were fixed in those specs the same day. | Closed |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| WCAG 2.1 (Web Content Accessibility Guidelines) | https://www.w3.org/TR/WCAG21/ | Contrast ratios (1.4.3), text resize (1.4.4), keyboard (2.1.1), no keyboard trap (2.1.2), focus visible (2.4.7) — the criteria this document borrows |
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Game-specific checklist by cost; the source for "no hold inputs without alternative" and "no information by colour alone" |
| AbleGamers Player Panel | https://ablegamers.org/player-panel/ | The user-testing option if budget appears (consultant row above) |
| Colour Blindness Simulator (Coblis) | https://www.color-blindness.com/coblis-color-blindness-simulator/ | Test plan rows 2 and 12 |
| Accessible Games Database | https://accessible.games | Reference decisions from comparable turn-based and card games |
| Godot engine reference (local, version-pinned) | `docs/engine-reference/godot/current-best-practices.md` § Accessibility; `breaking-changes.md`; `deprecated-apis.md` | AccessKit facts this project may cite; anything not in these files is NOT SOURCEABLE |
| Xbox / PlayStation / CVAA | (see template) | Not applicable to this release — retained in the template for a future platform decision |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Toast reading time: raise run-ui F3 `toast_min_ms` to 5000 and `toast_max_ms` to 8000 (both outside F3's stated ranges 1500–3000 / 4000–8000) and add hover/focus-pauses-timer; persist actionable warnings outside the toast. | Run UI GDD (`/propagate-design-change`) | Before `/ux-design toast` | **Resolved 2026-11-03** — run-ui F3 now floors at 5000 ms and caps at 8000 ms with hover (or LMB hold) pause and one toast at a time (toasts take no focus); actionable warnings persist outside the toast |
| Click-to-select alternative to drag (motor): add to match-ui U5 as a pointer entry into the existing `KeyTargeting` state. | Match UI GDD | Before `/ux-design targeting` | **Resolved 2026-11-03** — match-ui U5 "Click to select" (`CLICK_DRAG_PX` 8 px, `entered_by = pointer`), States `KeyTargeting`, `--pose=select:<id>` |
| `end_turn_arm_ms` guard so a skip keypress cannot end the turn the frame the queue drains; or split skip (Space) from End Turn (Enter). | Match UI GDD + Jacob | Before `/ux-design hud` | **Resolved 2026-11-03** — guard adopted: match-ui U5 "Arm guard", Tuning Knobs `end_turn_arm_ms` 300 ms (150–600); click never gated |
| Esc priority (match-ui U5 "cancel drag → close overlay → pause menu") must skip overlays with no cancel (Choice, Mulligan, End banner) and open the pause menu instead. | Match UI GDD | Before `/ux-design choice-overlay` | **Resolved 2026-11-03** — match-ui U5 chain skips Mulligan and Choice (pause menu opens over them, O19); on the end banner `Esc` does nothing and the pause menu is unreachable in `Ended` (**DD-X09**) |
| Hover-only rows to amend to "hover or keyboard focus": match-ui U5 hero power "Blocked shows the reason on hover"; card-effects UI Requirements (scaled spell damage, aura attribution); heroes.md UI Requirements (hero power tooltip "Open / hover"). Card Inspect pattern gives the mechanism. | Match UI, Card Effects, Heroes GDDs | `/consistency-check` | **Split 2026-11-03** — match-ui resolved (U5: `Blocked` reason "on hover **or keyboard focus** — never hover-only"; focus opens the same preview / tooltip hover does); **heroes resolved 2026-11-03** (UI Requirements row now "Open / hover or focus"); card-effects rows still open (Matrix row Partial) |
| Keyboard inspect: match-ui defines `Tab` only inside `KeyTargeting`. Define `Tab`/`Shift+Tab` in `PlayerTurn.Main` idle as focus cycling over hand → player row → hero power → portraits → treasure chips → boss row (opening Card Inspect), as interaction-patterns.md Focus Management specifies. | Match UI GDD | Before `/ux-design hud` | **Resolved 2026-11-03** — match-ui U5 "Keyboard inspect (focus cycling in `Idle`)" with the 2 px `state_actionable` ring at a 3 px offset; `--pose=focus:<element>`, O17 / O18 |
| `text_scale` vs the fixed 134x58 card text slot: approve the reading-panel design (preview + side panel at 125/150%) or allow the thumbnail text to reflow with fewer visible lines. | Jacob | `/ux-design hand` | Open — reading panel recommended |
| Gamma control: add a `gamma` key to meta M9 and a slider to run-ui `settings`? Basic-tier row currently has no owner. | Meta Progression + Run UI GDDs | Pre-Production | **Resolved 2026-11-03 — DD-X10**: meta M9 `gamma` 0.8–1.4 (1.0); run-ui `settings` slider; Match UI and Run UI apply it via `CanvasModulate` |
| Keyword glossary (tutorial persistence): a `glossary` overlay from pause and settings listing DD-M09 keywords with reminder text; who owns it (Run UI or Match UI)? | Jacob | Pre-Production | Open |
| Input remapping storage: a `bindings` map in meta M9, or Godot's `InputMap` serialised to `user://bindings.cfg` by Run UI? | Meta Progression GDD | Alpha | **Resolved 2026-11-03** — storage is `settings.bindings` in the profile record (meta M9, DD-X07), applied to `InputMap` at Boot; ADR-0004 Decision addendum 2026-11-03. `cancel` / `Esc` is excluded from the rebindable set (Motor "Full input remapping"; interaction-patterns "Standard Shortcuts" states the same exception) |
| High-contrast alternates `#FF8C42` / `#4FA3FF`: measure on `ink` and `table_lit` and record ratios in art bible §4 before the toggle is implemented. | art-director (manual pass) | Before `/asset-spec system:match-ui` | Open |
| Does Godot 4.7 AccessKit announce `Control.accessibility_live` region changes (toasts, feed lines) without focus? NOT SOURCEABLE from `docs/engine-reference/godot/` beyond the property's existence. | ux-designer (web check, then update the engine reference) | Before any screen-reader work | Unresolved |
| Treasure tray chip hit area 40 → 44 px while keeping the 40 px visual and 8 px gaps (match-ui F6). | `/ux-design hud` | Pre-Production | **Resolved 2026-11-03** — match-ui F6 treasure tray row: 44x44 hit rect per chip, centres 48 px apart, tray hit zone 22, 500, 140, 44; O18 measures it; `hud.md` Treasure chips block follows |
| Add music volume to the match pause quick-access (match-ui U9 lists master/SFX only). | `/ux-design pause-menu` | Pre-Production | Open |
