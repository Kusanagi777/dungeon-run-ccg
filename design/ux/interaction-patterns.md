# Interaction Pattern Library

> Authoring guidance: .claude/docs/templates/guidance/interaction-pattern-library-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Design
> **Author**: Jacob + ux-designer (`/ux-design patterns`, automation `guided`, workflow `standard`, density `balanced`; no `ui-programmer` / `art-director` agent spawned — no Agent tool in this run)
> **Last Updated**: 2026-11-03
> **Version**: 0.1
> **Engine**: Godot 4.7.2 (GDScript)
> **UI Framework**: Godot Control nodes, `canvas_items` stretch at 1280x720 logical (DD-T05)
> **Related Documents**:
> - `design/art/art-bible.md` §4 — visual standards (colour tokens, typography, state colours and their non-colour backups, card slot layout); §7 UI direction
> - `design/accessibility-requirements.md` — Standard tier with reduce-motion, high-contrast state set and text scale elevated; the requirements every pattern below must satisfy
> - `design/gdd/match-ui.md` (U4–U10, F1–F6), `design/gdd/run-ui.md` (U1–U10, F2–F4), `design/gdd/boss-ai.md` (C8, UI Requirements), `design/gdd/reward-draft.md` (UI Requirements), `design/gdd/rng-event-log.md` (UI Requirements) — the system GDDs these patterns implement
> - `design/ux/[screen].md` — individual screen specs that reference patterns: `hud.md`, `draft-picker.md`, `hero-select.md`, `run-summary.md` exist (2026-11-03); the remaining screens are listed in match-ui and run-ui UI Requirements
>
> **Template**: Interaction Pattern Library
> **REVISED 2026-11-03 (ux-review)**: Mana Bar rect → match-ui F6's two rows (`1060, 652, 196, 20` "n/m" and `1060, 680, 196, 28` crystals) plus the boss compact counter rect `1196, 262, 60, 28`; Treasure Chip → ≤ 3 (`MAX_TREASURES_HELD`), 40x40 visual, 44x44 hit; Segmented Select labels → `Normal / Fast / Instant` (DD-X07), Animation Standards hit-stop "off at `fast`", the label OQ resolved; Escape / Cancel chain, Overlay table and Standard Shortcuts: `Esc` on the match-end banner does nothing and the pause menu is unreachable in `Ended` (DD-X09); stale "proposed / extends / Open Questions" markers on Click-to-Select, Card Inspect, End Turn, Focus Management and Event Feed → "per match-ui U5 / F6 / Tuning Knobs", the matching OQs Resolved; new index rows and short entries for `Deck Drawer`, `Bundle Panel`, `Compact Card Row`, `Curve Strip`, `Locked Hero Panel`, `Top Bar` pointing at their owning specs, and the Gaps rows Top bar / Deck drawer / Compact card row / Gamma slider closed; header "none exist yet" → the four specs; index name `Screen Replace` → `Screen Push / Pop / Replace`; When NOT to Use / Implementation Notes added to Mana Bar, Boss Intent Banner, Progress Strip, Treasure Chip, Event Feed, Rejection Feedback, Skip & Playback, Floating Number; one-line When to Use / Accessibility blocks on every Navigation and Feedback entry; List Item read-only 44 px row rule; "Used In" for Tooltip, Card Inspect, List Item and Scroll Container now names hero-select / run-summary.
> **REVISED 2026-11-03 (ux-review round 3)**: Deck Drawer contract — keyboard open focuses the header "×" first (as both owning specs say); Button (Destructive) no longer lists hero-select Start — the guarded-Primary exception is carved in its When NOT to Use / Accessibility and the index mention moved to Confirmation Dialog; new Screen-Owned **Per-Floor Strip** row + index row (owner `run-summary.md`, reused by `run_detail`) and Progress Strip's When NOT to Use points at it; Standard Shortcuts Implementation Notes moved under the Rules paragraph so "Defaults:" meets its table; Loading State's two Accessibility blocks merged; Scroll Container's run-summary usage corrected to the deck list.

> **Why this document exists**: Every UI screen spec should be able to say
> "uses Button (Primary) pattern" rather than re-specifying hover states,
> press animations, focus behavior, keyboard handling, and screen reader
> announcements from scratch. This library is the single source of truth for
> reusable interaction behaviors. When a screen spec references a pattern name,
> the programmer looks it up here. When the behavior changes, it changes here
> and applies everywhere.
>
> This is a living document. Patterns are added as new screens are designed —
> do not design a new interaction without checking here first. If a new pattern
> is needed, add it here (or propose it to the ux-designer) before writing the
> first screen spec that uses it.
>
> **Status definitions**:
> - **Draft**: Interaction specified but not yet implemented or validated
> - **Stable**: Implemented, tested, and validated in at least one shipped screen
> - **Deprecated**: Being phased out — existing uses will be migrated, do not use in new screens

---

## Overview

Deckdelve's UI is two surfaces with one grammar. The **match** (Match UI) is a tabletop: a
hand fan, two rows of tokens, two portraits, a mana bar and an End Turn button, all driven by
the event log and operated mouse-first with a complete keyboard path (match-ui U5). The **run
shell** (Run UI) is a stack of flat screens — menu, hero select, boss intro, draft, summary,
settings — operated by focus and `1/2/3` + `Enter` (run-ui U3). Both obey the same five rules,
which every pattern below inherits and which a screen spec may not override:

1. **Lit by state, not by hierarchy.** There is no primary button colour (art bible §4 UI
   palette). A control the player can use now carries the `state_actionable` outline; an idle
   one is `table_dark` + `text_muted`. Saturated colour is reserved for `state_danger`,
   `state_buff`, `state_target`, `state_freeze` — readouts of a current state, never animation.
2. **Legality before commitment.** Legal drops, targets and options light up *before* release
   or confirm (match-ui Game Feel "pre-release legality"); a pick is select-then-confirm
   (reward-draft Game Feel). Nothing commits on hover; nothing commits on a single ambiguous
   press.
3. **Hover duplicates, focus equals.** Hover never carries unique information (art bible §7,
   run-ui U3). Everything a hover shows, keyboard focus shows; selection is focus or click,
   never hover.
4. **Every motion is skippable and data-driven.** Any input skips any animation (ui-code rule
   4; match-ui U4.5; run-ui U4); durations come from `match_ui.json` / `run_ui.json`; `anim_speed`
   divides them, `instant` zeroes them, `reduce_motion` removes shakes, slides and loops.
5. **Display only.** Patterns render view-state and emit intents/commands; they never hold game
   state (ui-code rule 1, DD-T02). A rejected command changes nothing on screen except the
   rejection feedback.

Density: this version specifies behaviour, states and accessibility for each pattern at
`balanced` depth; pixel geometry beyond art bible §4 and the F-grids of the GDDs belongs to the
per-screen specs. Status is `Draft` throughout — nothing is implemented.

### How to Use This Library

**If you are designing a screen**: Browse the Pattern Catalog Index below before
inventing new interactions. When a standard pattern fits, reference it by name
in the screen spec (e.g., "The confirm button uses Button (Primary) pattern").
When no existing pattern fits, propose a new one — document it here alongside
or before the screen spec that introduces it.

**If you are implementing a screen**: When a screen spec says "use [PatternName]
pattern," find it in this document for the complete specification. The
implementation notes section contains engine-specific guidance. The accessibility
section contains the requirements that are non-negotiable.

**If you are reviewing a screen spec**: Verify that all interactive elements
reference a pattern from this library or include their own full interaction
specification. "Standard button" or "the usual way" is not a valid reference.

**If you are updating a pattern**: Changing a Stable pattern affects every screen
that uses it. Before changing, audit all usages (search screen specs for the
pattern name), determine the impact, get approval from the ux-designer, and
update this document before or simultaneously with any implementation change.

---

## Pattern Catalog

The catalog keeps the template's pattern names so that `/ux-review` and other projects' habits
still apply, and maps each onto this game. Patterns the game does not use are listed with the
reason rather than dropped, so a reviewer can tell "decided against" from "forgotten".
Screen names in *Used In* are the `design/ux/` files match-ui and run-ui UI Requirements name.

### Pattern Catalog Index

> Add a row here every time a new pattern is added to this document.
> The "Used In" column is the usages audit trail — update it when new screens
> adopt the pattern.

| Pattern Name | Category | Description | Used In (Screens) | Status |
|-------------|----------|-------------|------------------|--------|
| Button (Primary) | Input | The screen's default-focus action, lit by `state_actionable` outline when pressable. One per screen. | main-menu (New Run), hero-select (Start), boss-intro (Fight), draft-picker (Pick), run-summary (New Run same hero), mulligan / choice-overlay (Confirm), settings (Back) | Draft |
| Button (Secondary) | Input | Alternative or back action; `table_dark` + `text_light`, no outline unless focused. | All dialogs (Cancel), Back everywhere, Hero Select / Main Menu on summaries, Take nothing | Draft |
| Button (Destructive) | Input | Ends or discards something: always opens Confirmation Dialog. | pause (Abandon run, Concede), main-menu (Abandon in resume prompt), settings (Clear run records, Reset profile) — not hero-select Start, a guarded Primary (see the entry's When NOT to Use) | Draft |
| Toggle | Input | Binary setting as a `CheckButton`. | settings (fullscreen, reduce_motion, high_contrast_states, keep_run_records) | Draft |
| Slider | Input | Continuous value with numeric readout. | settings and pause-menu (master / music / SFX volume), settings (action delay 0–2000 ms, gamma 0.8–1.4 — DD-X10) | Draft |
| Dropdown / Select | Input | **Replaced by Segmented Select** for 3–4 option settings; no dropdown in v1. | settings (anim_speed, text_scale, telegraph_mode) | Draft |
| List Item | Layout / Input | Selectable or read-only row in a scrollable list. | run-log (archived runs), draft-picker deck drawer + compact card rows, hero-select deck drawer, run-summary damage list, data-error rows, event-feed drawer lines | Draft |
| Grid Item | Layout / Input | **Not used** — all collections are single rows (hand fan, board row, 3-option rows) or vertical lists. | — | N/A |
| Modal Dialog | Feedback / Layout | Blocking overlay with focus trap. | pause-menu, confirm, resume prompt, glossary (proposed); the deck drawer is a Drawer, not a modal | Draft |
| Confirmation Dialog | Feedback / Layout | Two-button consequence dialog, Cancel focused; typed-token variant for Reset profile. | Abandon, Concede, Clear run records, Reset profile, hero-select (Start while a run is saved — the dialog is the whole destructive guard for that Primary) | Draft |
| Toast / Notification | Feedback | Queued top-right banner, ≥ 5 s, pausable, never modal. | toast (unlocks, run warnings, draft rejections) | Draft |
| Tooltip | Feedback | Parchment panel on hover **and** focus; 300 ms delay on hover, immediate on focus. | hero power, treasure chips, settings rows, rejection tooltip (variant), buffed-stat aura attribution, hero-select (locked-panel progress, curve strip), run-summary (status line full text, custom-seed pill, Disabled New Run reason, per-floor strip cells) | Draft |
| Progress Bar | Feedback / Layout | **Not used** — no loading bars; floor progress is the Progress Strip pattern. | — | N/A |
| Input Field | Input | `LineEdit` with visible label. | hero-select (seed), confirm (typed token), settings Controls page (key capture — Alpha) | Draft |
| Tab Bar | Navigation | **Not used in v1** — settings is one scrollable list; revisit if a Controls page is added. | — | N/A |
| Scroll Container | Layout | Vertical scroll with visible bar and focus-follows-scroll. | run-log, deck drawer (draft-picker, hero-select), event-feed drawer, data-error, settings, run-summary (deck list — 36 cards at every `text_scale`; the damage list is a fixed 8 / 7 / 6 rows and never scrolls) | Draft |
| Card (Hand) | Game-Specific | The 150x210 hand card: playable / unaffordable / hovered / focused / lifted / targeting source. | hand | Draft |
| Card Drag-to-Play | Game-Specific | Press-drag-release play and attack gesture with pre-release legality. | hand, hud (board), targeting | Draft |
| Click-to-Select / Keyboard Targeting | Game-Specific | The hold-free path: select a source (click or number key), cycle or click a target, confirm. | hand, hud, targeting | Draft |
| Targeting Arrow | Game-Specific | Bezier arrow + 3 px ring on the current legal target; follows cursor or keyboard cycle. | targeting | Draft |
| Board Token | Game-Specific | 90x126 minion token with stamps, badge row, can-attack outline, summon-gap behaviour. | hud | Draft |
| Card Inspect | Game-Specific | 1.5x preview on hover or focus; reading panel at `text_scale` > 100%. | hand, hud, draft-picker, mulligan, choice-overlay, hero-select (power plate, deck drawer rows), run-summary, run-log | Draft |
| End Turn Button | Game-Specific | 140x44 control lit when nothing is left to do; key path with arm guard. | hud | Draft |
| Hero Power Button | Game-Specific | 48x48 ability button: Ready / Blocked / Used; tooltip with reason. | hud | Draft |
| Hero Portrait & Health Stamp | Game-Specific | 120x160 panel with 24 px health, armour, weapon slot, passive plate (boss), hand count (boss). | hud | Draft |
| Mana Bar | Game-Specific | 10 crystals (full / spent / temporary / locked) + "n/m" — match-ui F6 `1060, 652, 196, 20` (count) / `1060, 680, 196, 28` (crystals); boss compact counter `1196, 262, 60, 28`. | hud | Draft |
| Boss Intent Banner | Game-Specific | Forecast / committed / plan-changed banner with icon, amount, reticle; `class_only` and `hidden` modes. | hud | Draft |
| Pick One of N (Option Row) | Game-Specific | 1–3 option slots, `1/2/3` focus, select-then-confirm, no accidental pick. | mulligan (toggle variant), choice-overlay, draft-picker (treasure + bundle), hero-select | Draft |
| Progress Strip | Game-Specific | F nodes (cleared / current / upcoming), gem marks, treasure icons, deck size. | progress-strip (shared) on boss-intro, draft-picker, pause | Draft |
| Treasure Chip | Game-Specific | 40x40 visual, 44x44 hit rect, ≤ 3 held (`MAX_TREASURES_HELD`), tooltip on hover/focus, flare on trigger. | hud (treasure tray), progress-strip, run-summary | Draft |
| Event Feed | Game-Specific | 3-line ticker + 200-line drawer, grouped under command roots, collapsible. | event-feed, hud | Draft |
| Rejection Feedback | Game-Specific | 0.2 s shake + `reject.<code>` tooltip + related-control flash + feed line; display unchanged. | targeting, hand, hud | Draft |
| Skip & Playback | Game-Specific | Skip-all on any non-control input; boss-turn pacing with skip hint. | hud | Draft |
| Floating Number | Game-Specific | `−n` / `+n` pop on an `ink` pill; coalesced for AoE. | hud | Draft |
| Dialogue Box | Game-Specific | **Not used** — boss intro lines are static text on `boss-intro` (concept: no dialogue). | — | N/A |
| Context Action Prompt | Game-Specific | **Not used** — no world interaction; the skip hint is part of Skip & Playback. | — | N/A |
| Minimap / Quest Tracker | Game-Specific | **Not used** — the Progress Strip and the boss passive plate cover orientation. | — | N/A |
| Health / Resource Bar | Game-Specific | Replaced by Hero Portrait & Health Stamp and Mana Bar (numbers, not bars). | — | N/A |
| Deck Drawer | Screen-owned compound | Non-blocking right drawer `960, 96, 320, 536` (toggle at y 640 stays visible): header with "×" close, Treasure Chip row, 44 px List Item rows with Card Inspect. Owning spec: `draft-picker.md` §5.2 / §6. | draft-picker, hero-select (starter deck) | Draft |
| Bundle Panel | Screen-owned compound | 340x320 option panel: theme label band, pitch, 3 Compact Card Rows, Pick One of N slot. Owning spec: `draft-picker.md` §5.2 / §5.3. | draft-picker (bundle variant) | Draft |
| Compact Card Row | Screen-owned compound | 300x64 read-only List Item: cost stamp, name, type initial; Card Inspect (+ reading panel) on hover / focus. Owning spec: `draft-picker.md` §5.3 / §12. | draft-picker, deck drawer rows | Draft |
| Curve Strip | Screen-owned compound | 308x28 six-column starter-deck cost curve (numerals + bars; numerals carry the count). Owning spec: `hero-select.md` §5.2 / §5.3. | hero-select | Draft |
| Locked Hero Panel | Screen-owned compound | Focusable, non-selectable silhouette panel: name, condition text, progress "n / m" from Meta `unlock_progress`. Owning spec: `hero-select.md` §5.3 / §6; the "locked-item progress pattern" meta-progression's UX flag asks for. | hero-select (later: treasure codex) | Draft |
| Top Bar | Screen-owned compound | `0, 0, 1280, 40` `bg_edge` strip: turn indicator, floor / boss name, feed toggle and menu button (44x44 hits, focus stops 7–8). Owning spec: `hud.md` §4.2 "Top bar". | hud | Draft |
| Per-Floor Strip | Screen-owned compound | One 24 px cell per floor (`node_d`) in a 44x44 hit Control, 20 px apart (pitch 44), no connectors: boss initial on band colour, "×n" attempt mark, `state_danger` ring on the killing cell, hollow cells after it; focusable cells with tooltips, one Tab stop. Owning spec: `run-summary.md` §5.2 / §5.3 / §12. | run-summary (victory / defeat), run-log (`run_detail`) | Draft |
| Screen Push / Pop / Replace | Navigation | Run base screens replace each other with a skippable fade; no push/pop slide. | All Run UI base screens | Draft |
| Overlay Open / Close | Navigation | Dims the base to `table_dark`, stacks, restores focus. | pause-menu, confirm, resume prompt, deck drawer, feed drawer, mulligan, choice-overlay, match-end | Draft |
| Focus Management | Navigation | Where focus starts, moves and returns, per screen; focus ring rules. | All screens | Draft |
| Escape / Cancel | Navigation | One priority chain for Esc / RMB across match and run. | All screens | Draft |
| Standard Shortcuts | Navigation | The keyboard table every screen inherits; all rebindable except Esc/cancel (Alpha). | All screens | Draft |
| Loading State | Feedback | Boot data load and scene swaps. | data-error (on failure), match handoff, run-start | Draft |
| Empty State | Feedback | Empty run log, hidden tray, short offers, absent locked row. | run-log, hud, draft-picker, hero-select | Draft |
| Error State | Feedback | data-error screen, warning toasts, rejections. | data-error, toast, targeting | Draft |
| Success Confirmation | Feedback | "Copied", pick lock, settings applied live. | run-summary, draft-picker, settings | Draft |
| Optimistic UI | Feedback | **Not used** — no network; every state shown is an event already in the log. | — | N/A |

---

## Patterns

[Entries below are the project's specifications. Each is written against art bible §4 tokens and the GDD rules it cites; values marked *proposed* are this library's additions that a GDD does not yet hold and are listed in Open Questions.]

### Standard Control Patterns

> Full reference specifications for every pattern in this section (state tables
> with timing/audio values, accessibility requirements, implementation notes)
> are in `.claude/docs/templates/guidance/interaction-pattern-library-guide-standard-controls.md` —
> load only the pattern(s) currently being specified.

---

#### Button (Primary)

**Category**: Input
**Status**: Draft
**When to Use**: The one action a screen exists for: Start, Fight, Pick, Confirm, New Run (same hero), Continue. It receives default focus (Focus Management) unless the screen deliberately forces a choice first (drafts).
**When NOT to Use**: Back / Cancel (Secondary); anything that ends a run or discards data (Destructive); the End Turn control (its own pattern — it is lit by game state, not by screen role).

**Interaction Specification**:

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Idle (not pressable yet — e.g. Pick with no option focused) | `table_dark` fill, 4 px radius, `text_muted` 16 px label | — | No response; cursor stays default | — | — |
| Actionable | `table_dark` fill, `text_light` label, 2 px `state_actionable` outline | Becomes legal | Outline appears | instant (art bible §7: v1 state changes are instant) | — |
| Hovered | Actionable + label `text_light`, lift 2 px (no scale; no hue change) | Mouse over | — | 80 ms ease-out | `ui_hover` |
| Focused | Actionable + focus ring (2 px `state_actionable`, 3 px offset — distinct from the outline by the gap) | Tab / `1`–`3` routing / default focus | — | 80 ms ease-out | `ui_hover` |
| Pressed | Fill darkens to `bg_edge`, label unchanged; action fires on release | LMB / Enter / Space | Visible press ≤ 33 ms (run-ui Game Feel) | 60 ms | `ui_select` (Run) / `sfx.ui.end_turn`-class key per screen |
| Committed (post-press on terminal intents) | Stays pressed-looking; siblings dim | After Pick / Start / Fight / Continue | Ignores further input until the screen swaps (run-ui U4) | until swap | — |
| Disabled | `table_dark` fill, `text_muted` at 60% alpha, no outline, reason in Tooltip on hover/focus | — | No response | — | — |

**Accessibility**: Keyboard: Tab-reachable, Enter and Space activate. Focus ring always visible; never suppressed by `anim_speed = instant`. Label is the accessible name (stock `Button` → AccessKit exposes it). Primary is distinguished from Secondary by the outline and by position (right-most / bottom-centre per screen spec), never by hue. Hit area ≥ 44x44 (labels may be shorter; pad the Control). Disabled reason is a Tooltip on focus, not hover-only. Label text scales with `text_scale`; buttons grow in width, never clip.

**Implementation Notes**: Stock `Button` with a project theme (`StyleBoxFlat` per state from the art bible theme resource); `focus_mode = FOCUS_ALL`; no `_draw()` override needed in v1. Use the theme's `focus` stylebox for the ring so it draws for every Control the same way. "Lit" is a theme variation (`actionable`), toggled by the screen from view-state, not by the button polling the game.

---

#### Button (Secondary)

**Category**: Input
**Status**: Draft
**When to Use**: Back, Cancel, Resume, Hero Select / Main Menu on summaries, "Take nothing" (when `allow_skip`), Copy seed, Copy report, Load more.
**When NOT to Use**: The screen's main action; anything that needs a Confirmation Dialog.

**Interaction Specification**:

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | `table_dark` fill, `text_light` label, **no outline** | — | — | — | — |
| Hovered | Lift 2 px | Mouse over | — | 80 ms ease-out | `ui_hover` |
| Focused | Focus ring (2 px `state_actionable`, 3 px offset) | Tab / Esc-target | — | 80 ms ease-out | `ui_hover` |
| Pressed | Fill `bg_edge` | LMB / Enter / Space; **Esc activates the screen's Secondary that means back/cancel** | Fires on release (Esc fires on press) | 60 ms | `ui_select` (pitch-down "cancel" variant) |
| Disabled | `text_muted` 60% alpha | — | Tooltip with reason on focus/hover | — | — |

**Accessibility**: Same baseline as Primary. In a dialog the Cancel Secondary is the Esc target and the default focus (Confirmation Dialog). Secondary and Primary are never visually identical: Primary has the outline when actionable; if a screen's Primary is not yet actionable (draft before a choice), Secondary still has no outline, so the pair never both read as "lit".

**Implementation Notes**: Same `Button` scene with the `secondary` theme variation. Place Cancel/Back **left** of Primary in dialogs and bottom-left on screens; keep this constant across every screen so muscle memory holds (reviewed by `/ux-review`).

---

#### Button (Destructive)

**Category**: Input
**Status**: Draft
**When to Use**: Abandon run (pause, resume prompt), Concede (match pause), Clear run records, Reset profile. Anything that ends a run or deletes profile data.
**When NOT to Use**: Quit to menu with the run saved (run-ui `pause.go_main_menu` — the run reappears as Continue, nothing is lost: Secondary); Take nothing in a draft (a legal choice, not a loss: Secondary); **hero-select Start while a run is saved** — a Primary whose destructive branch is fully guarded by a Confirmation Dialog (Cancel focused, run-ui U7) keeps its Primary visual, no "!" glyph and the screen's default focus, and takes only the critical rule below (never executes directly). The recorded deviation lives in `hero-select.md` §5.3 / §15; its accessible name carries the consequence ("Start run as <hero> — ends your current run"). Carved 2026-11-03 (ux-review round 3).

**Interaction Specification**:

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | As Secondary, label names the consequence ("Abandon run", "Concede", "Reset profile") plus a leading ⚠-class glyph (letter "!" in v1) | — | — | — | — |
| Hovered / Focused | As Secondary | — | — | 80 ms | `ui_hover` |
| Pressed | As Secondary | LMB / Enter / Space | **Opens Confirmation Dialog — never executes directly** | 60 ms | `ui_select` |

> **Critical rule**: A Button (Destructive) NEVER executes its action directly.
> It always triggers a Confirmation Dialog. There are no exceptions.

**Accessibility**: Accessible name includes the consequence ("Abandon run — counts as a loss"). No red fill: `state_danger` is reserved for game-state readouts (art bible rule b); destructiveness is carried by the glyph, the label and the dialog. Never the default focus on any screen (the guarded Primary in When NOT to Use is not a Destructive button and keeps its default focus — the dialog's Cancel default makes a reflexive `Enter` safe).

**Implementation Notes**: Same `Button` scene, `destructive` variation; the `pressed` handler only calls `open_confirm(spec)`.

---

#### Toggle

**Category**: Input
**Status**: Draft
**When to Use**: `fullscreen`, `reduce_motion`, `high_contrast_states`, `keep_run_records` (settings).
**When NOT to Use**: Three-way settings (Segmented Select); one-shot actions.

**Interaction Specification**:

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Off | Row: label left (`text_light` 16 px), `CheckButton` right; knob left, track `table_dark`, state word "Off" (`text_muted`) beside it | — | — | — | — |
| On | Knob right, track `table_dark` with `state_actionable` outline, state word "On" | — | — | — | — |
| Hovered / Focused | Row gains focus ring; description Tooltip appears (focus: immediate; hover: 300 ms) | Tab / mouse | — | 80 ms | `ui_hover` |
| Toggling | Knob slides (or jumps under `reduce_motion` / `instant`) | LMB / Enter / Space / Left / Right | `set_setting(key, value)` immediately — live, no Apply button (run-ui settings "On change (live)") | 100 ms ease-out | `ui_select` |

**Accessibility**: State is shown by knob position **and** the word On/Off — never colour alone. Stock `CheckButton` exposes the switch role and checked state. `reduce_motion` and `high_contrast_states` take effect on the very next frame so the player sees what they chose.

**Implementation Notes**: `CheckButton` in an `HBoxContainer` row scene shared by all settings rows; the row, not the control, owns the Tooltip.

---

#### Slider

**Category**: Input
**Status**: Draft
**When to Use**: Volumes (0–100% shown; stored 0–1), action delay (0–2000 ms), gamma (0.8–1.4, step 0.05, default 1.0 — Meta M9 `gamma` / run-ui `settings`, DD-X10; the slider row carries three preview swatches so the effect is visible in place).
**When NOT to Use**: `text_scale` and `anim_speed` — three discrete steps are a Segmented Select, so each step is a tested layout.

**Interaction Specification**:

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | Label, `HSlider` (track `table_dark`, grabber `text_light`), numeric readout right ("80%", "600 ms") | — | — | — | — |
| Focused / Hovered | Focus ring on the row; grabber grows 2 px | Tab / mouse | — | 80 ms | `ui_hover` |
| Adjusting | Readout updates live; volume sliders play a sample tick at the new level | Drag; Left/Right = 1 step (5% / 50 ms); PageUp/PageDown = 5 steps; Home/End = min/max | Live `set_setting`; Meta debounces the write | — | `ui_slider_tick` per step |
| Disabled | `text_muted` | — | — | — | — |

**Accessibility**: Always a numeric readout (value is never only a position). Keyboard steps as above; stock `HSlider` exposes value/min/max. Hit area of the grabber ≥ 44 px tall via the row.

**Implementation Notes**: `HSlider` with `step` set per setting; readout `Label` bound to `value_changed`.

---

#### Dropdown / Select

**Category**: Input
**Status**: Draft
**When to Use**: 3–4 mutually exclusive options whose names are short: `anim_speed` (**Normal / Fast / Instant** — the DD-X07 label set `normal | fast | instant`; match-ui F3 `SPEED_DIV` and run-ui F2 map each label to their own durations), `text_scale` (100% / 125% / 150%), `telegraph_mode` (Full / Brief / Off).
**When NOT to Use**: Lists longer than 4 (none exist in v1); binary settings (Toggle).

**Interaction Specification**:

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | Label left; a row of equal-width `Button`s in a `ButtonGroup`; the selected one has the `state_actionable` outline and `text_light`, others `text_muted` | — | — | — | — |
| Focused | Focus ring on the selected segment; Left/Right move the selection (and apply) | Tab enters the group once | — | 80 ms | `ui_hover` |
| Selecting | Outline moves | LMB on a segment / Left / Right / Enter | Live `set_setting` | instant | `ui_select` |

**Accessibility**: Selected state = outline + text colour + (for `text_scale`) the segment labels themselves rendered at their own scale as a preview. Tab treats the group as one stop (WAI radio-group behaviour); stock `Button`s in a `ButtonGroup` expose radio semantics.

**Implementation Notes**: `HBoxContainer` of toggle-mode `Button`s sharing a `ButtonGroup`; `focus_neighbor_left/right` wired within the group, `focus_next/previous` jump out of it.

---

#### List Item

**Category**: Layout / Input
**Status**: Draft
**When to Use**: Run log rows (selectable → `run_detail`), deck drawer rows (read-only, Card Inspect on focus/hover), data-error rows (read-only), event-feed drawer lines (read-only, expandable groups).
**When NOT to Use**: Option rows of 1–3 cards (Pick One of N).

**Interaction Specification**:

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | Row ≥ 44 px tall on `table_dark`; columns per screen spec; `text_light` / `text_muted` | — | — | — | — |
| Hovered (selectable rows) | Lift 2 px | Mouse over | — | 80 ms | `ui_hover` |
| Focused | Focus ring; row scrolled into view | Up/Down/Tab; Home/End | Card Inspect / Tooltip for rows that have one | 80 ms | `ui_hover` |
| Activated | Press state | LMB / Enter | Opens detail / expands group | 60 ms | `ui_select` |
| Expandable group (feed) | "+N more" affordance as a trailing Secondary-styled text button | LMB / Enter on it | Group expands in place; focus stays on the affordance | instant | — |

**Accessibility**: Up/Down are the primary keys inside a list; Tab leaves the list (one stop in / one stop out). Row position is announced for stock `ItemList`/`Tree`; custom rows carry "row n of N" in their accessible name. Read-only lists are still focusable so Card Inspect works by keyboard.

**Row-height rule**: the 44 px minimum applies to **interactive rows** (selectable, expandable, or focusable-for-inspect — run-log rows, deck drawer rows, compact card rows, the run-summary damage list, feed groups with "+N more"), because they are hit targets (accessibility-requirements Motor "Minimum target size"). A purely read-only row with no focus stop and no hover content (a plain feed line in the ticker, a settings caption) may be as short as its text's line height × 1.3; it must still never be the only place its information appears.

**Implementation Notes**: `ItemList` or `Tree` for text-only lists (free accessibility); custom row scenes inside a `VBoxContainer` for the deck drawer and feed (they host card thumbnails). `ScrollContainer.ensure_control_visible()` on focus.

---

#### Grid Item

**Category**: Layout / Input
**Status**: N/A — not used
**When to Use**: No two-dimensional selectable grid exists in v1 (DD-M01 single rows; drafts are rows of ≤ 3). If a card collection view is ever added (anti-pillar: no collection), start from the template guide.

---

#### Modal Dialog

**Category**: Feedback / Layout
**Status**: Draft
**When to Use**: Pause menu (match and run), Confirmation Dialog, Resume prompt, Glossary (proposed), Mulligan and Choice overlays (modal, no cancel), Match-end banner (modal, auto-advances).
**When NOT to Use**: Toasts; the deck drawer and feed drawer (non-blocking **drawers** — Overlay Open / Close without a focus trap; the base keeps working, Esc closes them first).

**Interaction Specification**:

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Opening | Base dims to `table_dark` (match: the table; run: the screen); panel `table_dark` with 4 px radius centred (match-ui F6: pause 440,160,400,400; end banner 340,260,600,200); scales 0.95 → 1.0 | `Esc`, top-bar menu button, event (`mulligan_offered`, `choice_requested`, `match_ended`) | Focus moves to the dialog's default (Cancel in confirms; Resume in pause; first option in Mulligan/Choice) | `overlay_open` 0.2 s (match) / fade 250 ms (run); scale removed under `reduce_motion` | `sfx.ui.overlay` |
| Active | Base non-interactive; **focus trapped** inside | Tab cycles within; Esc = the dialog's cancel if it has one | — | — | — |
| Dismissing (confirmed) | Panel fades; base brightens | Primary pressed | Action; focus returns to the trigger element | `overlay_close` 0.15 s | per action |
| Dismissing (cancelled) | Same | Cancel / Esc | No action; focus returns to the trigger | 0.15 s | `ui_select` cancel variant |
| Cannot dismiss | No Cancel control; Esc opens the pause menu *over* it instead (Mulligan, Choice) or does nothing (data error) | — | — | — | — |

> **Focus trap rule**: While a modal dialog is open, focus navigation must cycle
> within the dialog only, and focus must return to the trigger element on close.

**Accessibility**: Every dialog has a title (`text_light` 16–20 px) that is its accessible name. Enter = Primary, Esc = Cancel, **except** Confirmation Dialog where Enter on first open is intercepted (see there). Under `reduce_motion`: no scale, fade at half duration. Dialog text scales with `text_scale`; the panel grows downward, never clips (min panel height from content).

**Implementation Notes**: One `ModalLayer` (`CanvasLayer` 60 — layer table in Overlay Open / Close) owning the dim `ColorRect` and a stack of panels; `Viewport.gui_disable_input` is not used — instead the base's root Control gets its mouse/focus recursively disabled (engine reference: "recursive Control disable" exists in 4.5+). Store `return_focus` on open. Match UI's underlying playback keeps running behind the pause menu (match-ui States `Menu`).

---

#### Confirmation Dialog

**Category**: Feedback / Layout
**Status**: Draft
**When to Use**: Every Button (Destructive). Also Start when an active run is saved ("This ends your current run — counted as a loss", run-ui U7).
**When NOT to Use**: Picks and confirms that are legal choices (Mulligan Confirm, Pick); informational notices.

> **Label rule**: The confirm button must be labeled with the specific action,
> not a generic "OK" or "Yes."

**Structure**:
- Title: the action as a question — "Abandon this run?", "Concede the match?", "Reset profile?"
- Body: one sentence of consequence — "Abandon counts as a loss." / "The run is recorded as a defeat on floor n." / "All runs, stats and unlocks are deleted. This cannot be undone."
- Confirm button: Button (Primary) labelled with the action — "Abandon run", "Concede", "Reset profile"
- Cancel button: Button (Secondary) — "Cancel", placed left
- Default focus: **Cancel**
- Typed-token variant (Reset profile only, meta M1.1): an Input Field under the body showing the required word; Confirm stays Disabled until the text matches exactly; Enter in the field moves focus to Confirm (does not confirm). Not used anywhere else — it is friction by design for the one irreversible action.

**States**: Inherits Modal Dialog (Opening / Open / Closing, focus trap and return); the one addition is Confirm **Disabled** until the typed token matches (typed variant only).

**Accessibility**: Inherits Modal Dialog. Default focus on Cancel is required. Because Cancel is focused, a reflexive Enter cancels — the safe outcome. The consequence sentence is in the dialog's accessible description. No countdown, no auto-dismiss.

**Implementation Notes**: One `confirm.tscn` parameterised by `{title_key, body_key, confirm_key, token: String | null}`; run-ui's `confirm` overlay and match-ui's concede confirm are the same scene.

---

#### Toast / Notification

**Category**: Feedback
**Status**: Draft
**When to Use**: Unlock notifications, `run_warning` codes (`save_failed`, `boss_pool_short`, …), draft rejections (`E_*`, debugging honesty — reward-draft UI Requirements), "Copied" (short variant).
**When NOT to Use**: Anything needing a decision (Modal); anything the player must act on *now* with no other channel — an actionable warning also persists elsewhere (main-menu status line / summary), accessibility-requirements "Reading time".

**Interaction Specification**:

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Entering | `table_dark` banner at top-right (run) / below the top bar, right (match; never over the boss intent banner); `text_light` title ("New hero unlocked: Fortune"), `text_muted` subtitle (unlock condition / warning detail); identification swatch for unlocks; fades in (slides only if not `reduce_motion`) | Queue drain while the shell is idle (run-ui U5) | — | `toast_in_out` 200 ms | `ui_unlock` / none (warning) / `ui_select` (Copied) |
| Displayed | Static; dismiss "×" affordance at right | Hover (or LMB hold) **pauses the timer** — toasts take no focus, so there is no focus pause (acceptable because the toast is never the sole channel); LMB release anywhere on it dismisses | — | `t_toast` = clamp(5000 + 30·chars, **5000**, **8000**) ms (run-ui F3 `toast_min_ms` 5000 / `toast_max_ms` 8000); "Copied" variant 1500 ms (non-informational) | — |
| Auto-dismiss | Fade out | Timer | Next toast after `toast_gap_ms` 150 | 200 ms | — |
| Queue overflow | — | > `toast_queue_max` 8 | Oldest *warning* dropped first; unlocks never dropped (run-ui U5) | — | — |

**Accessibility**: Toasts never take focus and never block (run-ui U5). They are not the sole channel: unlocks also appear on the run summary and hero select; warnings also in the main-menu status line. Minimum 5 s, pausable, dismissable. Under `reduce_motion` fade only. Screen-reader announcement without focus depends on AccessKit live regions — **NOT SOURCEABLE** from the engine reference beyond `Control.accessibility_live`'s existence (accessibility-requirements Open Questions); until verified, do not claim it.

**Implementation Notes**: `ToastLayer` (`CanvasLayer` 50, below modals) with a `VBoxContainer` anchored top-right; one visible at a time per run-ui U5. Match UI reuses the same scene for draft-rejection toasts only; match rejections are Rejection Feedback, not toasts.

---

#### Tooltip

**Category**: Feedback
**Status**: Draft
**When to Use**: Hero power (name, cost, text, and the `Blocked` reason); treasure chips (name, rarity word, text, tags, "picked on floor f" — treasures.md); settings rows (what the setting does); buffed stat → aura attribution (card-effects); disabled buttons (reason); the Rejection Feedback tooltip (variant below).
**When NOT to Use**: Card text (Card Inspect — a tooltip is too small for a card); information needed to complete an action that is not also visible somewhere.

**Interaction Specification**:

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Hidden | — | — | — | — | — |
| Hover trigger | — | Mouse enters | 300 ms delay (treasures.md budgets 100 ms to *visible* once triggered; the delay guards against sweep-over) | — | — |
| Focus trigger | — | Element receives keyboard focus | **Immediate** (0 ms) — navigation is intentional | — | — |
| Displayed | `parchment` panel, `text_ink` 14 px × `text_scale` body, optional `ink` title band; max width 300 px; positioned above the element, flipped to stay on screen; never covers the element itself | — | — | fade 120 ms (0 under `instant`) | — |
| Hiding | Fade | Mouse leaves / focus moves / any command issued | — | 80 ms | — |

**Rejection variant**: at the cursor (mouse) or above the originating control (keyboard), `reject.<code>` text, `REJECTION_TOOLTIP_S` 1.5 s then fade; see Rejection Feedback.

**Accessibility**: Everything in a tooltip is reachable by focus (rule 3). Tooltip text ≥ 4.5:1 (`text_ink` on `parchment` 12.72). The focusable element's accessible description carries the tooltip text. Tooltips never contain controls.

**Implementation Notes**: One `TooltipLayer` (`CanvasLayer` 90) with a single reusable panel; triggers call `TooltipService.show(anchor_rect, content, mode)`. Do not use Godot's built-in `tooltip_text` popup for the visual (it is not themeable enough and ignores focus), but **do set `tooltip_text`** on the Control as well so AccessKit has the description.

---

#### Progress Bar

**Category**: Feedback / Layout
**Status**: N/A — not used
**When to Use**: No determinate progress exists (boot load is < 2 s or fails to `data_error`; there is no XP). Floor progress is the Progress Strip. If a long load ever appears, the Loading State pattern names the fallback.

---

#### Input Field

**Category**: Input
**Status**: Draft
**When to Use**: Seed entry on hero select (any text; echoes the normalised 16-hex form, run-ui U7); typed confirmation token (Reset profile); key capture on the Controls page (Alpha).
**When NOT to Use**: Anything selectable from a list.

**Interaction Specification**:

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Default | Visible label left ("Seed (optional)"); `LineEdit` on `table_dark`, `text_light` 16 px; placeholder `text_muted` ("random") — placeholder is not the label | — | — | — | — |
| Focused | Focus ring; caret | Tab / click | — | 80 ms | `ui_hover` |
| Typing | Live echo line under the field: "→ 3F2A…" normalised hex (`text_muted`) | Keys; standard editing shortcuts (Ctrl+A/C/V/X, Home/End) | Local only; no command until Start | — | — |
| Value present | Clear "×" affordance | LMB / Delete on the affordance | Clears | — | — |
| Token mismatch (confirm variant) | Confirm stays Disabled; no red border — the Disabled Confirm is the signal | — | — | — | — |
| Token match | Confirm becomes Actionable | Text equals the shown word | Enter in field → focus Confirm | — | `ui_hover` |

**Accessibility**: Label is always visible and bound (accessible name). The seed field is never required; Enter in it activates Start only if Start is Actionable (so Enter from a hero-less state does nothing). Text scales.

**Implementation Notes**: Stock `LineEdit`; `text_changed` → `RngService.parse_seed()` echo (rng-event-log F1). Key capture (Alpha) uses `InputEventKey` capture in `_unhandled_input` with Esc to cancel capture.

---

#### Tab Bar

**Category**: Navigation
**Status**: N/A — not used in v1
**When to Use**: Not needed: settings is one scrollable list ≤ 14 rows; run log filters by hero with a Segmented Select, not tabs. Revisit if a Controls page splits settings.

---

#### Scroll Container

**Category**: Layout
**Status**: Draft
**When to Use**: Run log, deck drawer, event-feed drawer, data-error report, settings list, bundle panel card rows if they overflow at 150% text.
**When NOT to Use**: Fixed rows (hand, board, option rows) — they fit by construction (match-ui F1, run-ui F4).

**Interaction Specification**:

| State | Visual | Input | Response | Duration | Audio |
|-------|--------|-------|----------|----------|-------|
| Content fits | No bar | — | — | — | — |
| Scrollable | Visible 8 px bar (`text_muted` thumb on `bg_edge` track), always shown when content overflows; fade top/bottom edge hint | — | — | — | — |
| Scrolling | — | Wheel (3 rows), drag bar, PageUp/PageDown, Home/End | — | 100 ms ease-out (0 under `instant`) | — |
| Focus follows scroll | Focused item always fully visible | Up/Down/Tab | `ensure_control_visible` | 100 ms | — |

**Accessibility**: Never hide the bar on PC. Keyboard scroll works without a focusable child (container itself focusable when it has none). Scroll position is not information: nothing is reachable *only* by scrolling that is not also reachable by focus.

**Implementation Notes**: `ScrollContainer` with `vertical_scroll_mode = SCROLL_MODE_SHOW_ALWAYS` when overflowing; call `ensure_control_visible()` on `focus_entered` of children.

---

### Game-Specific UI Patterns

> Full reference specifications for every pattern in this section are in
> `.claude/docs/templates/guidance/interaction-pattern-library-guide-game-specific.md` — load only the
> pattern(s) currently being specified.

---

#### Card (Hand)

**Category**: Game-Specific
**Status**: Draft
**When to Use**: Every card in the hand fan (match-ui F1), mulligan and Choice rows (at 1.5x), draft treasure frames, deck drawer thumbnails (static variant).
**When NOT to Use**: Minions on the board (Board Token), treasure chips (Treasure Chip), static run-summary drafted-card marks (a text row, Card Inspect on focus is enough), hero panels (Pick One of N option).

**States**:

| State | Visual | Notes |
|-------|--------|-------|
| Playable | Full card (art bible §4 slots); 2 px `state_actionable` outline; **not** lifted | `playable = true` from `hand()`; effective cost shown on the cost stamp (`effective_cost`, card-effects) |
| Unaffordable / not playable | No outline; body dimmed to 60% alpha; cost stamp ring `text_muted` dashed (*proposed*, accessibility audit) | Numbers remain readable (dim is alpha on the whole card, text contrast still ≥ 4.5:1 on `parchment` at 60%? — **verify in test plan row 1**; if not, dim only the art box and frame) |
| Hovered | Card Inspect preview (1.5x in place, neighbours do not move — F2); hover tween 0.1 s | Mouse only; no selection |
| Focused | Focus ring + Card Inspect preview immediately | Keyboard: `Tab` cycle (idle) or `1`–`0` (which also selects) |
| Lifted / selected | Card at 1.0x following the cursor (drag) or lifted 8 px with the outline (click-to-select / key targeting); shadow | Source of a Targeting session |
| Leaving | Travels to slot 0.25 s with 4-frame squash; or tweens back 0.15 s on cancel | match-ui Visual/Audio |

**Accessibility**: Playability = outline (light, not hue) + lift behaviour; cost vs mana is always numerically visible. Card text readable via Card Inspect by focus. Number-key selection `1`–`9`,`0` maps to fan position left→right; positions are announced in the accessible name ("Card 3 of 7: Fireblast, 2 mana").

**Implementation Notes**: `CardView` Control, `_draw()` for stamps; `focus_mode = FOCUS_ALL`; `accessibility_name`/`tooltip_text` set to the Card Inspect text. The fan layout (F1) owns positions; the hover transform (F2) is applied on a duplicate preview layer so the fan never reflows.

---

#### Card Drag-to-Play

**Category**: Game-Specific
**Status**: Draft
**When to Use**: Mouse play of a hand card, mouse attack from a token, mouse-targeted hero power (match-ui U5).
**When NOT to Use**: As the only path for any player — a player without a sustained hold routes through Click-to-Select / Keyboard Targeting; never on run screens (drafts and hero select are Pick One of N, no drag anywhere in the run shell).

**States and behaviors**:

| State | Visual | Input | Response | Duration |
|-------|--------|-------|----------|---------|
| Pickup | Card lifts instantly (≤ 16 ms), follows cursor exactly, no easing | LMB press on a playable card / legal attacker / Ready hero power | Legal summon positions open as slot gaps in the player row; targeted cards and attacks start the Targeting Arrow with legal targets outlined `state_target` | 0 |
| Dragging | Card at 1.0x under the cursor; End Turn disabled | Move | Legality shown live; hovered legal slot/target gets the 3 px ring | per frame |
| Drop (legal) | Card travels to slot 0.25 s / attack lunge | Release over a lit slot or target | `submit(play_card / attack / hero_power)` | ≤ 50 ms to first visual |
| Drop (illegal) | Card tweens back 0.15 s, ease-out, no bounce | Release elsewhere | No command, no event | 0.15 s |
| Cancel | Same as illegal drop | RMB / Esc during drag | No command | 0.15 s |

**Accessibility**: Drag is a hold input, so it is **never the only path** — Click-to-Select / Keyboard Targeting provides the hold-free equivalent for the same three sources. Drop zones are whole tokens/slots (≥ 90x126), not edges. Under `reduce_motion` the squash is dropped; the card-to-slot travel remains (it is positional information, like match-ui's other kept gameplay travel — lunge, draw, death drop; it is the travel `reduce_motion` keeps — Animation Standards "Motion reduction overrides"; run-shell slides such as fly-to-strip become fades).

**Implementation Notes**: `InputRouter` (match-ui U1) owns a single `Dragging` session; the dragged visual is a duplicate on a top `CanvasLayer`; `legal_commands()` is queried once on pickup and cached for the session (match-rules budgets it at < 1 frame per hover).

---

#### Click-to-Select / Keyboard Targeting

**Category**: Game-Specific
**Status**: Draft (per match-ui U5 "Click to select" and Tuning Knobs `CLICK_DRAG_PX` 8 px — both entries, pointer and key, are in the GDD; `--pose=select:<id>` captures it)
**When to Use**: The hold-free path for playing, attacking and targeted hero powers. One state machine, two entries: pointer click or number key.
**When NOT to Use**: Run-shell picks (drafts, hero select) — those are Pick One of N's select-then-confirm, not a targeting session; Mulligan / Choice toggles (Pick One of N toggle / select variants).

**States and behaviors**:

| State | Visual | Input | Response | Duration |
|-------|--------|-------|----------|---------|
| Select source | Card lifts 8 px with outline / token or hero power gains the outline; legal positions or targets light exactly as in a drag; the Targeting Arrow starts from the source and points at the **current** target (first legal, or nearest to cursor) | **Click** (press+release without moving > 8 px) on a playable card, legal attacker or Ready hero power; or `1`–`9`,`0` (hand index), `A` then `1`–`7` (attacker by board index), `H` (hero power) | Enter `KeyTargeting` (match-ui States); End Turn disabled | 0 |
| Cycle target / position | Ring moves; arrow follows | `Tab` / `Shift+Tab` (cyclic, so Shift is optional); mouse hover over a lit target also moves the ring | — | per press |
| Confirm | As drop (legal) | `Enter`, or LMB click on a lit target/slot | `submit(...)` | ≤ 50 ms |
| Cancel | Source settles back | `Esc`, RMB, click on empty table, or click on a *different* legal source (which re-selects it) | No command | 0.15 s |
| Untargeted play (minion with one legal position, untargeted spell) | Source lifts; a single lit position/“cast” affordance | Click source | **Still requires Confirm** (Enter / second click) — a single click never plays a card, so a mis-click costs nothing (rule 2) | — |

**Accessibility**: This is the one-hand and tremor path (accessibility-requirements Motor). Every step is a discrete press; the only chord (`Shift+Tab`) is optional. Current target is shown by the 3 px ring and the arrow (shape), with its name in the accessible announcement ("Target 2 of 3: Bone Guard"). Taunt-only and Stealth-excluded rules apply identically to cycling (match-ui U5).

**Implementation Notes**: Same `KeyTargeting` session object as the GDD's keyboard mode with `entered_by: pointer | key`; a click is distinguished from a drag by the 8 px threshold on press→release, so both gestures coexist on the same card without a setting.

---

#### Targeting Arrow

**Category**: Game-Specific
**Status**: Draft
**When to Use**: Any targeting session (drag, click-to-select, keyboard) whose source is a targeted card, an attacker or a targeted hero power (match-ui U7).
**When NOT to Use**: Untargeted plays (a minion into a slot gap, an untargeted spell — the lit slot / "cast" affordance is the cue, no arrow); anywhere in the run shell.

**States**:

| State | Visual | Notes |
|-------|--------|-------|
| Active | Quadratic Bezier from source centre to the cursor (drag) or to the current target's centre (click/keyboard), control point `ARROW_LIFT_PX` 50 above the midpoint, 20 segments, `state_target`, triangular head; redrawn per frame | Colour is secondary: the arrow's shape and the ring are the cue (art bible colourblind rule) |
| Over legal target | Target gains a 3 px `state_target` ring | Only legal targets are lit; Stealth never; Taunt-only when a Taunt exists |
| Over illegal / empty | Arrow stays, no ring, head dims to 60% | Release here cancels |
| Keyboard cycling | Arrow snaps between targets (tween 80 ms, 0 under `reduce_motion`/`instant`) | Cyclic order: boss row left→right, then boss hero; for positions: player row slots left→right |

**Accessibility**: Shape-first; works unchanged under `high_contrast_states` (target amber is unchanged). The arrow never obscures the target's stamps (head stops at the ring).

**Implementation Notes**: Salvage `prototypes/hearthstone-clone-2026-01/scripts/targeting_arrow.gd` (match-ui U7); `Line2D` on the top `CanvasLayer`; data-driven lift and colour.

---

#### Board Token

**Category**: Game-Specific
**Status**: Draft
**When to Use**: Every minion on either row (match-ui UI Requirements "Board rows").
**When NOT to Use**: Cards in the hand or any card-shaped option (Card (Hand)); heroes (Hero Portrait & Health Stamp); treasures (Treasure Chip).

**States**:

| State | Visual | Notes |
|-------|--------|-------|
| Default | 90x126: art box, attack and health stamps (26 px circles, 14 px numerals), keyword badge row (12 px glyphs; letters in v1) | No name band, no rules text — Card Inspect shows the full card |
| Can attack (player) | 2 px `state_actionable` outline | From `legal_commands()` |
| Summoning sick / already attacked | No outline; small "z"/"✓" badge (*letters in v1*) | Non-colour |
| Damaged / buffed | Stamp numeral `state_danger` with crack glyph / `state_buff` with up-arrow; stays while the state holds (art bible rule c) | |
| Frozen / Silenced / Stealth / Divine Shield / Taunt / Windfury / Poisonous / Lifesteal | Badge glyph each; Frozen adds `state_freeze` outline + snowflake; Silence greys the art box + slash glyph; Taunt adds a thicker frame (shape) | No two badges differ by colour alone |
| Hovered / Focused | Card Inspect preview above the row; focus ring | Keyboard focus reaches tokens in idle (Focus Management) |
| Legal target | 3 px `state_target` ring | Targeting Arrow |
| Dying | Fade + 2 px drop with its death group; gap-close after | Grouped per cause (match-ui U3.3) |
| Summon gap | Row opens a gap at the hovered/cycled legal index | During targeting of a minion play |

**Accessibility**: All stats numeric; all keywords glyphs; Card Inspect on focus supplies name and text. Hit area is the full 90x126.

**Implementation Notes**: `TokenView` shares the stamp drawing code with `CardView` at 0.6x; `apply_final` from `AnimStep` sets state idempotently (match-ui U4.1).

---

#### Card Inspect

**Category**: Game-Specific
**Status**: Draft (per match-ui F2 for the hover preview and U5 "Keyboard inspect" for the focus path; the `text_scale` reading panel is accessibility-requirements Visual "Text scaling")
**When to Use**: Any card-shaped thing: hand cards, board tokens, mulligan/Choice/draft options, bundle compact rows, deck drawer rows, run-summary drafted cards, hero power and boss passive plates (text-only variant).
**When NOT to Use**: Hero power / treasure / status text that fits a Tooltip (a name plus 1–2 lines) — the Tooltip pattern owns those; non-card controls (buttons, sliders, seed pill).

**States and behaviors**:

| State | Visual | Input | Response | Duration |
|-------|--------|-------|----------|---------|
| Preview (100% text) | Full card at 1.5x (225x315, text ×1.5 = 18 px body) in place for hand cards (F2: bottom on the baseline, clamped to the viewport, on top; neighbours do not move) or anchored beside the element elsewhere (bundle rows: per draft-picker.md §5.1 anchoring table — toward screen centre, clamped to the viewport; run-ui F4) | Hover (tween `HOVER_IN_S` 0.1 s) or **keyboard focus (immediate)** | — | ≤ 100 ms to complete |
| Preview + reading panel (125% / 150%) | The 1.5x card **plus** a `parchment` panel beside it (toward screen centre) with name (`ink` band), keyword reminder lines, and rules text at 18 px × `text_scale`, no line cap, `text_ink`; max width 360 px, scrolls only if > 50% viewport height | As above | — | as above |
| Token inspect | Preview above the row (boss row: below) with the full card including name and text | Hover / focus on a token | — | as above |
| Dismiss | Preview fades 0.1 s (0 under `instant`) | Mouse out / focus move / any command / card leaves hand (match-ui Edge Cases) | — | 0.1 s |

**Accessibility**: This is the committed reading path for the 12 px card thumbnail (accessibility-requirements Visual). Hover and focus produce the **same** content. Scaled spell damage and aura attribution (card-effects UI Requirements) render inside the preview/panel, so they are focus-reachable. The preview never requires a hold.

**Implementation Notes**: One `InspectLayer` (`CanvasLayer` 80) hosting a `CardView` at 1.5x and an optional `ReadingPanel`; callers pass `{card_id, anchor_rect, side}`. Reading-panel keyword reminders come from a `keywords.json` string table (also the Glossary's source — Gaps).

---

#### End Turn Button

**Category**: Game-Specific
**Status**: Draft
**When to Use**: The one End Turn control (match-ui F6: 1116, 296, 140, 44).
**When NOT to Use**: Any run-screen Primary (Fight, Pick, Start, Continue are Button (Primary)); the match-end banner's Continue (Button (Primary)); never duplicated as a second "pass" control.

**States**:

| State | Visual | Notes |
|-------|--------|-------|
| Disabled | `table_dark`, `text_muted` "End Turn" | Boss turn, `Resolving`, `Choice`, `Dragging`/`KeyTargeting`, queue busy; a press does nothing and never reaches `submit` (match-ui U5) |
| Enabled | `table_dark`, `text_light` | `PlayerTurn.Main`, queue idle, plays remain |
| Actionable ("nothing left to do") | + 2 px `state_actionable` outline | No legal play other than `end_turn`, or mana 0 (art bible UI palette) |
| Hovered / Focused | Lift 2 px / focus ring | |
| Pressed | Depress; `sfx.ui.end_turn`; boss intent commit beat visible ≤ 300 ms after | `submit(end_turn)` |

**Keyboard**: `Space`/`Enter` = End Turn when Enabled **and the queue has been idle ≥ `end_turn_arm_ms` (300 ms, match-ui Tuning Knobs, safe range 150–600)**; otherwise the same key is Skip (Skip & Playback). The arm guard exists so a skip press cannot end the turn on the frame the boss turn finishes (match-ui U5 "Arm guard"; accessibility-requirements Motor "Accidental-activation guard"). A mouse click is never gated.

**Accessibility**: State by label colour value + outline (never hue); accessible name "End Turn" with state "nothing left to do" appended when Actionable. Hit area 140x44.

**Implementation Notes**: Stock `Button` with the three theme variations; `InputRouter` resolves the key between skip and end turn from queue state + arm timer.

---

#### Hero Power Button

**Category**: Game-Specific
**Status**: Draft
**When to Use**: The player's hero power (match-ui F6: 152, 390, 48, 48); the weapon slot below it is display-only.
**When NOT to Use**: The boss's hero power (display-only plate on the boss portrait, Hero Portrait & Health Stamp); the hero-select power preview (text on the Pick One of N option, Tooltip / Card Inspect text-only variant) — neither is a control.

**States**:

| State | Visual | Notes |
|-------|--------|-------|
| Ready | Hero primary fill (the one place the hero colour is a control — art bible §4 "hero power button"), cost "2" stamp, `state_actionable` outline when affordable | Click / `H` enters Click-to-Select or submits directly if untargeted (after confirm per rule 2) |
| Blocked | Dimmed; reason in Tooltip on **hover or focus** (match-ui U5) | e.g. not enough mana, a treasure rule |
| Used | Dimmed, "✓" letter badge | Once per turn (DD-M13) |
| Focused | Focus ring; Tooltip (name, cost, text) immediately | Tab order after the player row |

**Accessibility**: Name, cost and text on focus; reason for Blocked never hover-only. 48x48 meets the 44 px floor.

**Implementation Notes**: `Button` subclass drawing the stamp; `hero_power_state()` from view-state.

---

#### Hero Portrait & Health Stamp

**Category**: Game-Specific
**Status**: Draft
**When to Use**: Both portraits (120x160; player at 24,334; boss at 1136,96 — match-ui F6).
**When NOT to Use**: Hero panels on hero select (Pick One of N option with the Curve Strip); the run-summary hero portrait (static image + name, no stamps, no targeting); the boss-intro portrait (run-ui U2, static).

**States and behaviors**:

| Event | Visual | Audio | Duration |
|-------|--------|-------|---------|
| Health decrease | 24 px numeral turns `state_danger` with crack glyph while below max; Floating Number `−n`; 2-frame card shake (dropped under `reduce_motion`) | `sfx.ui.damage` | 0.4 s pop |
| Health increase | Numeral `state_buff` only while above printed max (rare); `+n` pop | `sfx.ui.heal` | 0.4 s |
| Armour gained / lost | Armour pill beside health with shield glyph + number | — | 0.15 s badge |
| Weapon equipped | Weapon slot shows attack/durability stamps | — | 0.25 s |
| Lethal range (player) | Health stamp ring `state_danger` + "!" glyph; boss intent `lethal` (Boss Intent Banner) | — | static |
| Boss hand count | Strip under the boss portrait: card-back glyph × n or "n" | — | per event |
| Boss passive plate | `table_dark` plate with the passive text 14 px; Card Inspect (text-only) on hover/focus for the full text | — | static |
| Victory | Winning portrait saturates to its primary (the one fill exception) | `sfx.ui.victory` | 0.4 s ramp |
| Hovered / Focused | Tooltip: hero name, health/armour numerically, weapon, passive | — | immediate on focus |

**Accessibility**: Numbers are the readout; colour is additive. Portraits are focusable (so the boss passive is keyboard-readable) and are legal targets with the 3 px ring.

**Implementation Notes**: `PortraitView` with stamps drawn like cards; the boss passive text comes from `ai_profiles.json`/bosses data via Card Database.

---

#### Mana Bar

**Category**: Game-Specific
**Status**: Draft
**When to Use**: Player mana — match-ui F6's two-row zone `1060, 652, 196, 56`: the "n/m" count at **`1060, 652, 196, 20`** (16 px bold) and the ten 16-px crystals with 4-px gaps at **`1060, 680, 196, 28`**. The boss has the **compact counter** only: "n/m" 14 px bold with a 12 px crystal glyph in the right half of the boss strip, **`1196, 262, 60, 28`** (F6; the left half `1136, 262, 60, 28` is the boss hand count); at `text_scale` ≥ 125 % it relocates into the boss portrait's bottom-right corner (`hud.md` §10.2).
**When NOT to Use**: Any other resource (there is none — health and armour are the Hero Portrait & Health Stamp, deck size is a pile pill); never as a bar or fill fraction (art bible: numbers, not bars); never in the run shell.

**States**:

| State | Visual | Notes |
|-------|--------|-------|
| Full crystal | `#3B5A82` steel-blue fill, `ink` ring | Mana stamp colour (art bible §4 identification table) |
| Spent | Hollow ring only | Shape |
| Temporary | Fill + "+" glyph | |
| Locked / overloaded | Hatched fill + lock glyph | |
| Count | "n/m" 16 px bold `text_light` always shown | The numeric readout is primary |
| `NOT_ENOUGH_MANA` rejection | Bar flashes outline 0.2 s (Rejection Feedback) | |

**Accessibility**: Four crystal states differ by shape/glyph, not hue. "n/m" scales with `text_scale` (the crystal row does not).

**Implementation Notes**: `ManaBar` scene = `Label` ("n/m") over an `HBoxContainer` of ten `TextureRect` crystals swapping between four textures; driven by `MatchViewState.mana{available, max, temporary}` and locked count at render, never per event (match-ui U3: `mana_*` events produce no step). The boss `CompactManaCounter` is the same `Label` style without the crystal row.

---

#### Boss Intent Banner

**Category**: Game-Specific
**Status**: Draft
**When to Use**: The banner above the boss portrait (match-ui F6: 980, 52, 276, 36) driven by `ai_intent_shown` / `ai_intent_committed` (boss-ai C8).
**When NOT to Use**: Player-side forecasts (none exist), the turn banner (a separate 0.4 s view-state label), or any run-shell screen — the boss intro's passive text is static copy, not an intent.

**States**:

| State | Visual | Notes |
|-------|--------|-------|
| Forecast (`full`) | Icon per `intent_key` (letters in v1) + localised label + amount ("Attack face for 6") + a reticle glyph on the named target token | `intent_show` 0.3 s |
| Forecast (`class_only`) | Icon + label only | Boss data |
| Hidden | No banner; a "?" plate so the absence is visibly deliberate | Band 3 only, reason recorded per boss; fixture `boss_intent_hidden` (match-ui U11) |
| Committed, kept | Banner brightens (commit beat `intent_banner_s`) | |
| Committed, plan changed | "Plan changed" label for `plan_changed_s`, then the new intent | The Pillar 3 lesson |
| Lethal | `state_danger` text on `ink` + a single pulse (static under `reduce_motion`) + the word "Lethal" | Word + icon are the cue |
| Hovered / Focused | Tooltip: full sentence ("The boss plans to attack your hero with its 3 minions for 6") | Focusable in idle |

**Accessibility**: Text + icon always; amount numeric; `telegraph_mode` default `full` (DD-X03) — `brief`/`off` are player choices; Boss AI owns `effective_mode = min(intent_mode, telegraph_mode)` and the banner renders exactly what it emits (match-ui U3). Banner text scales; the banner grows left.

**Implementation Notes**: `IntentBanner` scene reads `MatchViewState.intent{intent_key, amount, target, effective_mode, kept}`; the icon is a `TextureRect` keyed by `intent_key` (letters in v1), the label a localised `feed`-style key; the reticle is a child of the target token, not of the banner, so it survives row re-spacing.

---

#### Pick One of N (Option Row)

**Category**: Game-Specific
**Status**: Draft
**When to Use**: Mulligan (3 cards, toggle keep/replace, Confirm), Choice overlay (Discover 3 cards / Choose One 3 plates, select-then-Confirm, no cancel), Treasure draft (1–3 frames), Bundle draft (1–3 panels), Hero select (hero panels, Start). Geometry: match-ui F6 Choice row and run-ui F4 slots.
**When NOT to Use**: Lists longer than 3 (List Item in a Scroll Container — run log, deck drawer, settings); a single button (Button (Primary / Secondary)); targeting in the match (Click-to-Select / Keyboard Targeting).

**States and behaviors**:

| State | Visual | Input | Response | Duration |
|-------|--------|-------|----------|---------|
| Revealed | Options left→right in `option_ids` order (run-ui U8); staggered reveal 3 × 120 ms (one fade under `reduce_motion`); **no option focused on drafts** (forcing a choice), first option focused on Mulligan/Choice, **Start** focused on hero select with the hero pre-selected per run-ui U7 (Focus Management "Screen open") | Event | Primary (Pick / Confirm / Start) Idle until a selection exists (except Mulligan: Confirm always Actionable, replacing none is legal) | `draft_reveal` 360 ms |
| Focused / hovered option | `state_actionable` outline + lift 8 px; Card Inspect for card options; the hint line under the option ("fits your plan" / "N cards share *theme*" / "Deck 21 → 24") | `1`/`2`/`3` move focus; Tab cycles; mouse hover highlights **without selecting** (run-ui U3) | — | 80 ms |
| Selected | Outline persists after focus leaves; others at full brightness still (not dimmed until committed) | Click on the option / `Enter` on a focused option (first Enter = select) | Primary becomes Actionable | — |
| Toggle variant (Mulligan) | Each card toggles keep ↔ replace: replace shows a crossed card-back overlay + "Replace" word | Click / `1`–`3` | — | — |
| Confirm | Selected option lifts and flies (fly-to-strip 400 ms / Choice: to hand); others dim; screen `committed` | Primary / `Enter` with a selection (second Enter) / **double-click** on an option | `pick(index)` / `choose(i)` / `mulligan(mask)` | ≤ 50 ms to lock |
| Short offer | Missing slots as dimmed placeholders with the one-line reason | `short`/`reoffer` flag | Not focusable | — |
| Take nothing | Secondary button, only when `allow_skip` | | `skip_pick` | |

**Accessibility**: Two-step everywhere (select, then confirm) so a single press never commits; double-click is a shortcut, not the only path. `1/2/3` are focus moves, consistent across run screens; in the match Choice overlay `1`–`3` select (same two-step). Hints appear on focus as well as hover. Options are ≥ 150x210 targets. No cancel on Choice — Esc opens the pause menu over it (Escape / Cancel).

**Implementation Notes**: `OptionRow` scene parameterised by `n`, option scene and `mode: select | toggle`; owns the `committed` flag (run-ui U4) and the `1/2/3` routing.

---

#### Progress Strip

**Category**: Game-Specific
**Status**: Draft
**When to Use**: Shared overlay on `boss_intro`, `draft_treasure`, `draft_bundle`, `pause` (run-ui U6, F4).
**When NOT to Use**: The match (Match UI owns the HUD and the top bar carries "Floor n"), the summaries (they use the Screen-Owned **Per-Floor Strip**, run-ui U9 — a read-only variant that reuses this pattern's node drawing: focusable cells with tooltips, `attempt > 1` and the killing boss marked, but no connectors, gem marks, chips or deck size), hero select and the main menu.

**States**:

| State | Visual | Notes |
|-------|--------|-------|
| Cleared node | Filled `text_light` 24 px disc with the boss initial | |
| Current node | Ring in band colour with the boss initial | Shape + letter |
| Upcoming node | Hollow ring in band colour, **no identity** | Band colour only (run-structure) |
| Treasure floor | Gem mark (letter "T" in v1) under the node | |
| Held treasures | Treasure Chips at the strip's left | Focusable |
| Deck size | "24 cards" at the right; ticks up with fly-to-strip | `text_light`, never state colour (run-ui Visual/Audio) |
| Hovered / Focused node | Tooltip: "Floor 3 — cleared: Rat King" / "Floor 4 — current" / "Floor 6 — band 2" | Nodes are focusable for inspection; each node's 24 px visual sits in a 44x48 hit Control (pitch 64) so the 44 px target rule holds |

**Accessibility**: Three node shapes; floor numbers in tooltips; deck size numeric. Inspect-only stops with full-size (44x48) hit Controls — Tab reaches them after the screen's actions.

**Implementation Notes**: `ProgressStrip` scene (`progress-strip.md`) built from run-ui F4 (`node_d` 24, `seg_len` 40, `strip_w ≤ 640`); nodes are 44x48 `Control`s (`focus_mode = FOCUS_ALL`, tooltip on hover/focus) drawing the 24 px node centred inside; rendered from the `RunState` read model (`floor`, `boss_sequence` masked to cleared + current) so upcoming floors never leak identity.

---

#### Treasure Chip

**Category**: Game-Specific
**Status**: Draft
**When to Use**: Treasure tray in the match (**≤ 3** held — `MAX_TREASURES_HELD`, treasures.md; 40x40 visual, 44x44 hit rect; match-ui F6 tray `24, 502, 136, 40`, hit zone `22, 500, 140, 44`), Progress Strip left, run summary treasures block.
**When NOT to Use**: Draft option frames (those are the Card (Hand) static variant with a rarity pill — a chip is a *held* treasure), the boss passive plate, or any list where the name is already written out beside it.

**States**:

| State | Visual | Notes |
|-------|--------|-------|
| Held | 40x40 chip: rarity frame + letter glyph; **hit rect 44x44** centred on the visual (chip centres 48 px apart, so hit rects never overlap) | match-ui F6; accessibility-requirements Motor "Minimum target size" |
| Hovered / Focused | Tooltip: name, rarity word, text, tags as pills, "picked on floor f" (treasures.md) | Immediate on focus |
| Triggered | Flare: outline flash 0.15 s on a hook-hosted `effect_resolved` (static brightening under `reduce_motion`) | |
| Tray empty | Tray hidden (Empty State) | |

**Accessibility**: Tooltip on focus as well as hover (match-ui U5 "Keyboard inspect"; `--pose=focus:treasure:<n>`, O18 measures the 44x44 rect); rarity is a word in the tooltip, never the frame colour alone.

**Implementation Notes**: `TreasureChip` is a 44x44 `Control` (the hit rect) drawing a centred 40x40 visual; the tray is an `HBoxContainer` with 4 px separation (44 + 4 = 48 px pitch). If `treasure_floors` ever grows past 3 the tray moves, it does not extend (match-ui F6).

---

#### Event Feed

**Category**: Game-Specific
**Status**: Draft
**When to Use**: The readable log (rng-event-log UI Requirements; match-ui U10, F5, F6).
**When NOT to Use**: Run-shell screens (they have no event feed — warnings are toasts, results are summaries) and diagnostics: `diagnostic: true` events never reach the feed outside `--ai-debug` (match-ui U3.4a).

**States and behaviors**:

| State | Visual | Input | Response |
|-------|--------|-------|----------|
| Ticker (collapsed) | 3 newest lines, 13 px × `text_scale`, `text_light`/`text_muted` on `table_dark` at 24,48,400,42; non-interactive | — | — |
| Drawer (open) | Panel 0,40,300,290 (never over the player portrait); last 200 lines grouped under command roots, children indented; groups > 6 collapse to "+N more" (List Item expandable) | `L` / top-bar button toggles; Esc closes it first (Escape / Cancel) | Non-blocking: play continues; focus enters the drawer only when the toggle was by keyboard |
| New line | Appended at the bottom; auto-scroll unless the player has scrolled up (then a "↓ new" affordance) | — | — |
| Rejection line | The player's own `command_rejected` renders as a `text_muted` line keyed `feed.command_rejected` `{command, code}` ("— rejected: not enough mana") — match-ui U3.4a; a boss-side rejection is a plain diagnostic and never prints | — | — |
| Boss hand | Never shown until played | — | — |

**Accessibility**: The feed is the non-animated, non-timed record of everything (Pillar 4); line height ≥ 1.3; scales with `text_scale` (the drawer grows to 360 px wide at 150%, still clear of the portrait). Drawer is a Scroll Container.

**Implementation Notes**: `EventFeed` renders `MatchViewState.feed_lines[]` (already localised keys + params, grouped by `cause_seq`); the ticker and the drawer are two views of the same ring buffer (`FEED_MAX_LINES` 200), so opening the drawer never re-reads the log. Group collapse (`FEED_GROUP_COLLAPSE` 6) is a List Item expandable row.

---

#### Rejection Feedback

**Category**: Game-Specific
**Status**: Draft
**When to Use**: `submit` returns `accepted = false` (match-ui U5); run-shell intents dropped while `transitioning` are **silent** debug events, not this pattern (run-ui U4).
**When NOT to Use**: Inputs the `InputRouter` ignores by state (a disabled End Turn, a number key for an empty slot) — those produce *nothing*, not a rejection; run-shell `E_*` draft rejections, which are a Toast plus uncommit (run-ui U8); and boss-side `command_rejected`, which is a diagnostic.

**Behavior** (all simultaneous, ≤ 50 ms after the rejection):
- Originating control shakes 0.2 s `reject_shake` (3 px horizontal; under `reduce_motion` a 2-frame outline flash instead).
- Tooltip (rejection variant) at the cursor / above the control: `reject.<code>` for 1.5 s.
- Related-control flash: `MUST_ATTACK_TAUNT` → Taunt tokens' frames flash; `NOT_ENOUGH_MANA` → Mana Bar outline flash.
- Event Feed rejection line (persistent record).
- `sfx.ui.deny`, soft.
- **The display does not change otherwise** — nothing happened.

**Accessibility**: Reason is text (tooltip + feed), never a colour or a sound alone; the 1.5 s tooltip is acceptable only because the feed line persists. Works identically for keyboard-issued commands (tooltip anchors to the source).

**Implementation Notes**: One `reject_shake` `AnimStep` emitted by the projection for the player's `command_rejected` (match-ui U3); the tooltip is the Tooltip rejection variant via `TooltipService.show(anchor, "reject.<code>", mode)`; `--pose=reject:<code>` freezes it for capture.

---

#### Skip & Playback

**Category**: Game-Specific
**Status**: Draft
**When to Use**: Any time the animation queue is busy (player command playback, boss turn, end banner) — match-ui U4.5, U6.
**When NOT to Use**: As a substitute for `anim_speed = instant` (skip is per-moment, the setting is persistent); on the Mulligan / Choice overlays (nothing is animating — their keys select); and the end banner's *exit* is Continue / auto-advance, not a skip — `Esc` there does nothing (DD-X09).

**Behavior**:
- **Skip-all** triggers: LMB anywhere outside an interactive control, `Space`, `Enter` (while busy), and any new command (flush then submit). Latency ≤ 100 ms; every remaining `apply_final` runs in order within one frame; impact extras cancelled; skipped SFX dropped.
- **Boss turn**: controls lock (skip, concede/pause, settings, feed stay live); commit beat `intent_banner_s`; command groups paced by F4 within `max_turn_playback_s`; a "Click or Space to skip" hint (`text_muted`, static — no pulse under `reduce_motion`, and never a pulse faster than 1 Hz anyway) appears after 1 s under the boss portrait.
- **Run shell**: any input during a transition skips it to its end state (run-ui U4); `run_start` is skippable.
- **Settings interplay**: `anim_speed` divides durations; `instant` = always skipped; `reduce_motion` removes hit-stop/shake/slow-down/slides/loops and keeps only match-ui's positional gameplay travel — card-to-slot, attack lunge, draw, death drop (run-shell slides, fly-to-strip included, become fades — run-ui F2); `action_delay_ms` (Meta) paces boss groups.

**Accessibility**: Skipping never produces a state the animation was not heading to (match-ui U4.6 invariant, AC L6). The skip input is the same key as End Turn, hence the `end_turn_arm_ms` guard (End Turn Button).

**Implementation Notes**: `AnimationQueue.skip_all()` runs every remaining step's `apply_final` in `seq` order inside one frame (match-ui U4.5); the skip hint is a `Label` at `hud.md`'s rect shown by a 1 s timer the queue owns; `--pause-at=<seq>` captures mid-playback.

---

#### Floating Number

**Category**: Game-Specific
**Status**: Draft
**When to Use**: Damage, heal and stat-change pops on tokens and portraits (match-ui Visual/Audio).
**When NOT to Use**: Mana changes (the bar simply updates — match-ui U3 `mana_*` → no step), deck-count ticks (pile pill), `dealt = 0` with `prevented > 0` or `healed{amount: 0}` (no pop, feed line only), and anything in the run shell ("Deck 21 → 24" is a hint line, not a pop).

**Variants**:

| Variant | Visual | Notes |
|---------|--------|-------|
| Damage | "−n" `state_danger` 20 px bold on an `ink` pill; rises 20 px over 0.4 s | Sign is the non-colour cue |
| Heal / buff | "+n" `state_buff` on `ink` pill | |
| Divine Shield absorbed | Ring burst in `text_light`, no number | |
| Fatigue | "Fatigue n" label + damage pop | |
| Coalesced (AoE > 8 targets) | All pops in one step (match-ui U4.3) | Countable, never blurred |

**Behavior**: One pop per event; max simultaneous = board size + 2; under `reduce_motion` the rise is replaced by a fade in place. Pools of `Label` on the top layer.

**Accessibility**: Supplementary — the stamp numeral and the feed line carry the same number; pops may be disabled by `anim_speed = instant` without losing information.

**Implementation Notes**: `FloatingNumberPool` of pre-instanced `Label`s on the top `CanvasLayer`; one `number_pop` `AnimStep` per `damage_dealt` / `healed` / `armor_*` event, coalesced past `COALESCE_THRESHOLD` (8) into one step (match-ui U4.3); `reduce_motion` swaps the rise tween for a fade in place.

---

### Screen-Owned Compound Patterns

Compound components a single screen spec introduced and owns. They are indexed here so a second screen can reuse them by name and so `/ux-review` can find them; the **owning spec holds the full specification** (geometry, states, focus order) and this library holds only the contract a reuser must respect. Promote one into a full entry above when a third screen adopts it.

| Pattern | Owning spec | Contract for reusers |
|---|---|---|
| **Deck Drawer** | `draft-picker.md` §5.2 "Deck drawer", §6 "Deck drawer open", §7.2 | Non-blocking right drawer `960, 96, 320, 536` (ends y 632, so the "Deck (n)" toggle at y 640 stays visible and clickable while open) over the content, 250 ms slide (fade under `reduce_motion`); header "Deck · n cards" (or "Starter deck · 15 cards" on hero select) with a **"×" close button at its right end (44x44 hit, focus stop, accessible name "Close deck")**; Treasure Chip row; 44 px List Item rows (cost stamp, name, type initial) with Card Inspect on hover / focus; Overlay Open / Close row "Deck drawer"; `Esc` / RMB / the toggle / the "×" closes it first, focus returning to the toggle; **keyboard open moves focus to the header "×" (the drawer's first stop), then `Down` into the rows**; mouse open does not move focus (aligned 2026-11-03, round 3, with both owning specs). Reused by `hero-select.md`. |
| **Bundle Panel** | `draft-picker.md` §5.2 "Option row (bundle)", §5.3 | 340x320 `parchment`-framed `table_dark` panel at run-ui F4 slot x (90 / 470 / 850): 32 px theme-label band, pitch text, three Compact Card Rows, then a 36 px theme-tag chip band (the panel's y 420–456 at 100 %); the hint lines ("N cards share *theme*", "Deck a → b") render **outside** the panel in the screen's hint zone (draft-picker.md §5.2, y 470 / 494), not inside it; one Pick One of N slot (select-then-confirm); hover / focus a panel shows both hints. |
| **Compact Card Row** | `draft-picker.md` §5.3, §12 | 300x64 read-only List Item: cost stamp, name, type initial; focusable for Card Inspect (+ reading panel at ≥ 125 % `text_scale`, which is why the row never reflows); never selectable on its own — selection is the panel's. Also the Deck Drawer's row type. |
| **Curve Strip** | `hero-select.md` §5.2, §5.3, §12 | 308x28 six-column cost curve (columns 0 / 1 / 2 / 3 / 4 / 5 — heroes F1 `BUCKET`, `STARTER_MAX_COST` 5, so the ≥ 6 bucket is always 0 and has no column) of the starter deck: numerals carry the count, bars are decoration (no colour meaning); not focusable on its own — the hero panel's tooltip / Deck Drawer is the reading path. |
| **Locked Hero Panel** | `hero-select.md` §5.3, §6 "Locked", §12 | Desaturated silhouette panel with lock glyph, name, condition text and progress "n / m" (Meta `unlock_progress`, F6); **focusable, never selectable** (Start stays disabled while it is focused, run-ui AC-3); tooltip immediate on focus; the "locked-item progress pattern" meta-progression's UX flag asks for — the treasure codex reuses it. |
| **Top Bar** | `hud.md` §4.2 "Top bar", §3.2 | `0, 0, 1280, 40` `bg_edge` strip: turn indicator (16 px), floor / boss name (ellipsised at x 1150), feed toggle and menu button as Button (Secondary) with 44x44 hits and `L` / `Esc` equivalents; focus stops 7–8 of the match idle order. Match only — run screens have the title row. The menu button, like `Esc`, does nothing in `Ended` (DD-X09). |
| **Per-Floor Strip** | `run-summary.md` §5.2 "Right column — per-floor strip", §5.3, §12 stop 8 (reused by `run_detail`, `run-log.md`) | One **24 px cell** per floor 1..F (`node_d` — the Progress Strip's node drawing, reused), **20 px apart on one row (pitch 44, so each cell's 44x44 focusable hit Control tiles without overlap), no connectors, no gem marks, no chips, no deck size** (8 × 24 + 7 × 20 = 332 px; F > 9 → pitch 36 with 36x44 hit Controls, cells never below `node_d`); cleared cell = boss initial 12 px bold `text_light` on the band colour; killing cell (defeat) = initial inside a 2 px `state_danger` **ring** on `bg_edge` (never a fill); upcoming cells hollow (1 px `text_muted` outline, no initial — never the boss identity); "×n" 10 px attempt mark 2 px under a cell with `attempt > 1`; cells and marks do not scale with `text_scale`. **Every cell is focusable**: one Tab stop, `Left`/`Right` between cells, Tooltip 300 ms on hover / immediate on focus ("Floor f — boss (band b) · t turns · attempt a", "— you fell here" on the killing cell, "Floor f — band b" on hollow cells); `Enter` does nothing. Accessible names per cell (run-summary §12). Absent on `summary_abandoned`. |

---

### Navigation Patterns

> Full reference specifications for this section and the next are in
> `.claude/docs/templates/guidance/interaction-pattern-library-guide-navigation-feedback.md` — load
> only the pattern(s) currently being specified.

---

#### Screen Push / Pop / Replace

**Category**: Navigation
**Status**: Draft
**When to Use**: Every Run UI base-screen change (run-ui U2 inventory) and the `begin_match` / `match_view_finished` hand-off; never inside the match, which has no screens, only overlays.
**Accessibility**: Transitions are skippable by any input, fade-only under `reduce_motion`, 0 at `instant`; focus always lands on a named default (Focus Management), never on nothing except on drafts by design.

The run shell has **one base screen at a time plus overlays** (run-ui U1): base screens *replace* each other; there is no push/pop slide stack, because every base transition is event-driven (`run_floor_entered`, `draft_offered`, `run_ended`) and the only "back" is to the main menu. Overlays use Overlay Open / Close.

| Pattern | Trigger | Animation | Stack Behavior | Focus Behavior |
|---------|---------|-----------|---------------|----------------|
| Replace (fade) | Any base-screen change: menu → hero select → run start → boss intro → match → drafts → summary; Back from run log / settings | Cross-fade `fade` 250 ms (F2: × `anim_speed` factor; 0 at `instant`); `run_start` 600 ms; `intro_slide` 300 ms is a slide **only** without `reduce_motion` | Previous base freed (match scene hidden, not freed, during `match`) | New screen's default per Focus Management; Back returns focus to the element that left (main menu remembers New Run / Run Log / Settings) |
| Overlay open | Pause, confirm, resume prompt, deck drawer, feed drawer, mulligan, choice, match end | See Overlay Open / Close | Stacked on the base | Trapped (modal) / not trapped (drawer) |
| Push / Pop | **Not used** | — | — | — |

**Animation durations**: run-ui F2 values; match overlays `overlay_open` 0.2 s / `overlay_close` 0.15 s (match-ui F3).

**Motion reduction**: slides become fades at half duration; stagger collapses to one fade.

**Implementation Notes**: `RunShell` screen stack (run-ui U1) with `ShellState.transitioning`; intents other than `skip` are dropped during a transition (U4) — a dropped intent is a debug event, never user-facing feedback.

---

#### Overlay Open / Close

**Category**: Navigation
**Status**: Draft
**When to Use**: Anything stacked on a base screen or the match table — modals (pause, confirm, resume prompt, Mulligan, Choice, match end) and non-blocking drawers (deck, feed); toasts are their own pattern.
**Accessibility**: Modals trap focus and return it to the trigger; drawers never steal focus unless opened by keyboard; the dim is `table_dark` (a value change, not a hue), and every modal's `Esc` behaviour is in the table below.

| Overlay | Modal? | Dims base | Esc | Focus on open | Focus on close |
|---------|--------|-----------|-----|---------------|----------------|
| Pause (match / run) | Yes | Yes | Closes (Resume) | Resume | Trigger (menu button) or last focused |
| Confirmation Dialog | Yes | Yes | Cancel | Cancel | Trigger |
| Resume prompt | Yes | Yes | Back | Continue | Continue button on menu |
| Mulligan / Choice overlay | Yes, **no cancel** | Yes | Opens Pause over it | First option | n/a (closes on confirm) |
| Match-end banner | Yes, auto-advance 4 s | Yes | **Nothing** (banner continues; the pause menu is unreachable in `Ended` — DD-X09, match-ui U5 / U9) | Continue | n/a |
| Deck drawer (draft) | No | No | Closes it | Drawer only if opened by key | Trigger |
| Feed drawer (match) | No | No | Closes it | Drawer only if opened by `L` | Trigger / previous |
| Toast | No | No | Ignored | Never | — |
| Glossary (proposed) | Yes | Yes | Closes | First entry | Trigger |

Rule: an overlay's open/close is `overlay_open`/`overlay_close` (match) or `fade` (run); the base behind a modal is input-disabled recursively; the base behind a drawer keeps working.

**Implementation Notes**: Layer table (one source of truth): `DrawerLayer` 40 · `ToastLayer` 50 · `ModalLayer` 60 · `InspectLayer` 80 · `TooltipLayer` 90 — inspect and tooltips always draw above modals so the reading path survives on Mulligan / Choice. `ModalLayer` (`CanvasLayer` 60) and `DrawerLayer` (`CanvasLayer` 40) each hold one stack; opening a modal calls `base.propagate_call("set_process_input", [false])`-style recursive disable on the base and stores `return_focus`; a drawer only records `return_focus` when opened by key. The table above is the data for one `OverlayPolicy` resource per overlay (`modal`, `dims`, `esc_step`, `focus_on_open`).

---

#### Focus Management

**Category**: Navigation
**Status**: Draft
**When to Use**: Every screen and overlay — each `/ux-design` spec's Focus Order table is an instance of these rules, never a replacement for them.
**Accessibility**: The focus ring is the one non-negotiable visual (2 px `state_actionable`, 3 px offset, at every `anim_speed`); focus never lands on an element with no visible ring and never disappears when its element does.

> Focus management is the most common keyboard and gamepad accessibility failure
> in game UIs. These rules must be implemented consistently.

| Rule | Description |
|------|-------------|
| Focus ring | 2 px `state_actionable` outline offset 3 px from the element's bounds, drawn above everything on that element, on every focusable Control, always — including under `anim_speed = instant`. Distinct from the "actionable" outline (which hugs the bounds) by the 3 px gap; hover = 8 px lift (cards/options) or 2 px lift (buttons) with no ring. |
| Screen open | Focus goes to the **most likely next action** (run-ui U3): main menu → Continue if a run is saved else New Run; hero select → Start (pre-selected hero per U7); boss intro → Fight; drafts → **nothing** (forces a choice; Tab enters at option 1); summaries → New Run (same hero); settings → first row; run log → first row (or Back when empty); pause → Resume; confirm → Cancel; mulligan → card 1; Choice → option 1; match idle → End Turn **only when nothing is lit**, else the left-most playable card. |
| Screen close / replace | Focus returns to the element that triggered the navigation when it still exists (Back from settings → the Settings button); otherwise to the new screen's default. |
| Modal open / close | Trapped inside; returns to the trigger (Modal Dialog). |
| Element disabled / destroyed | Focus moves to the next element in tab order; if a focused hand card is played or burned, focus goes to the card now at that index, else End Turn. |
| Tab order — run screens | Title-less: options/panels left→right → hints → Primary → Secondary (Back) → Progress Strip → chips. Each `/ux-design` screen spec includes a **Focus Order table** listing every stop in order; `/ux-review` checks it. |
| Tab order — match idle (`PlayerTurn.Main`, queue idle) | Hand left→right → player row left→right → hero power → player portrait → treasure chips → End Turn → feed toggle → menu button → boss intent banner → boss row left→right → boss portrait → (wrap). `Tab` here *inspects* (Card Inspect / Tooltip); `Enter` on a playable card or legal attacker enters Click-to-Select — per match-ui U5 "Keyboard inspect (focus cycling in `Idle`)", which names this table as the owner of the stop list; `hud.md` Focus Order holds the per-element stops. |
| Tab order — targeting | `Tab` cycles legal targets/positions only (match-ui U5); leaving the set requires Esc. |
| Number keys | Run screens: `1/2/3` focus option *n* (run-ui U3). Match: `1`–`9`,`0` select hand card *n* (into targeting); Mulligan/Choice: `1`–`3` toggle/select option *n*. Always "focus/select", never "commit". |
| Gamepad (post-v1) | d-pad = `focus_neighbor_*` spatial moves over the same graph; `ui_accept` = Enter; `ui_cancel` = Esc; shoulder = `Tab`/`Shift+Tab`. No v1 decision may require a pointer with no focus equivalent. |
| Mouse hover vs focus | Hover never moves keyboard focus (engine reference: focus and hover are separate in 4.6+); a click does. A hovered-but-unfocused element is highlighted, not selected. |

**Implementation Notes**: Each screen scene wires `focus_neighbor_*` / `focus_next` / `focus_previous` from its Focus Order table at `_ready()`; the ring is one `FocusRing` overlay `Control` that follows `get_viewport().gui_get_focus_owner()` rather than per-widget theme styleboxes; `ModalLayer` stores and restores `return_focus`; the match idle order is built by `InputRouter` from the live view-state each time the queue goes idle.

---

#### Escape / Cancel

**Category**: Navigation
**Status**: Draft
**When to Use**: Every `Esc` / RMB / (post-v1) B press anywhere in the game resolves through this one chain; a screen spec states which step applies to it, never a different behaviour.
**Accessibility**: `Esc` is the universal "undo my last intent" and is never rebound, never commits, and never traps — from every state except `Ended` and `data_error` it reaches the pause menu within two presses.

> The "go back" action is the most-used navigation input in all menu systems.
> It must be consistent across every screen with no exceptions.

| Platform | Input | Behavior |
|----------|-------|---------|
| PC (keyboard) | `Esc` | One priority chain, first match wins: (1) cancel an active drag / click-to-select / keyboard-targeting session; (2) close a non-modal drawer (feed, deck); (3) cancel/close the top-most modal **that has a cancel** (confirm → Cancel, pause → Resume, resume prompt → Back, glossary); (4) on a modal with no cancel (Mulligan, Choice) or with nothing open: open the **pause menu**; (4a) **on the match-end banner (`Ended`): nothing** — no cancel, no pause menu; Continue / `Enter` / the 4 s auto-advance is the only exit (DD-X09; match-ui U5, U9, Edge Cases, O19); (5) on a run base screen: `back` (settings/run log → menu; hero select → menu); (6) on the main menu: Quit confirm. |
| PC (mouse) | RMB | Steps (1) and (2) only — RMB cancels a targeting session or closes a drawer; it never opens the pause menu and never navigates (so a stray right-click during play costs nothing). |
| PC (gamepad, post-v1) | B / Circle | Same chain as `Esc`. |

**Implementation Notes**: `InputRouter` (match) and `RunShell` (run) each implement the chain as one ordered function; a screen or overlay registers only which step it answers (`cancel_session`, `close_drawer`, `close_modal`, `back`) and never handles `Esc` itself; RMB calls the same function with `max_step = 2`.

**Rules**: `Esc` is never rebound to anything else (the one shortcut excluded from the Controls page — Standard Shortcuts) and never commits an action. Every screen's UX spec states its `Esc` behaviour explicitly, including "opens pause menu" for Mulligan / Choice and "nothing" for the match-end banner — per match-ui U5 (its chain skips the no-cancel overlays to step (4)) and DD-X09 (the banner is the one modal where the chain stops). A Choice has no legal "back" (match-rules States); the only way out is concede from the pause menu, which the chain makes reachable in two presses.

---

#### Standard Shortcuts

**Category**: Navigation
**Status**: Draft
**When to Use**: Every screen inherits this table unchanged; a spec may say which rows apply, never add a key — additions go through this library.
**Accessibility**: No chord except the optional `Shift+Tab`; no shortcut commits a destructive action; every key is an `InputMap` action rebindable by Alpha **except `Esc` (`cancel`), which is fixed like LMB / RMB** so the Escape / Cancel chain always has one guaranteed key, and every action it triggers is also reachable by mouse.

All shortcuts are `InputMap` actions (rebindable by Alpha, except `cancel` / `Esc` — accessibility-requirements Motor "Full input remapping" states the same exception). Defaults:

| Key | Match (Match UI) | Run screens (Run UI) | Source |
|-----|------------------|----------------------|--------|
| `Enter` / `Space` | End Turn when Enabled and armed (`end_turn_arm_ms`); otherwise Skip-all; in `KeyTargeting`: `Enter` confirms; on a focused button: activate | Activate the focused button; second `Enter` on a selected option confirms (Pick / Start) | match-ui U5; run-ui U3 |
| `Esc` | Priority chain (Escape / Cancel); **nothing on the match-end banner** (DD-X09) | Priority chain | match-ui U5, U9; run-ui U3 |
| RMB | Cancel targeting; close drawer | Close drawer | match-ui U5, U7 |
| `1`–`9`, `0` | Select hand card 1–10 into targeting; in Mulligan/Choice `1`–`3` toggle/select option | `1`/`2`/`3` focus option *n* on any 3-option screen | match-ui U5, U8, U9; run-ui U3 |
| `Tab` / `Shift+Tab` | Idle: focus cycle (inspect); targeting: cycle legal targets/positions | Focus cycle | match-ui U5 (+ this library) |
| `A` then `1`–`7` | Pick attacker by board index, then cycle defenders with `Tab` | — | match-ui U5 |
| `H` | Hero power (enters targeting if targeted) | — | match-ui U5 |
| `L` | Toggle the event-feed drawer | — | match-ui U5 |
| `Space` during playback | Skip-all (also LMB on empty table) | Skip transition | match-ui U4.5; run-ui U4 |
| `Up` / `Down` / `Home` / `End` | — (no lists in the HUD) | List navigation inside lists; slider steps with `Left`/`Right`/`PageUp`/`PageDown` | this library |
| `F11` (*proposed*) | Toggle fullscreen (mirrors the setting) | Same | proposed — Open Questions |
| `Ctrl+C` on a focused seed / report | — | Copy (same as the Copy button) | proposed |

Rules: no shortcut is a chord except the optional `Shift+Tab` and the clipboard conveniences; no shortcut commits a destructive action; the pause menu (via `Esc` or the top-bar menu button) is reachable from every state except `Ended` (DD-X09 — the banner's Continue / auto-advance is the only exit) and `data_error`. Any new screen must map onto this table rather than add keys; additions go through this library.

**Implementation Notes**: One `shortcuts.json` string table maps action names → default keys for the Controls page; `InputRouter` (match) and `RunShell` (run) read actions, never key codes; `cancel` is omitted from the rebindable list the Controls page builds.

---

### Feedback and Loading Patterns

---

#### Loading State

**Category**: Feedback
**Status**: Draft
**When to Use**: The four waits below and nothing else — there are no other loads in a single-player, local-data game; a wait a spec cannot place in this table is a bug, not a new loading state.
**Accessibility**: Text, never a spinner alone; every wait is either under 2 s or labelled and skippable; nothing times out into a blank screen, and a failed load is a screen the player can act on (copy report, quit), never a hang.

| Scope | Pattern | Notes |
|-------|---------|-------|
| Boot (Card Database load + validation) | Black `bg_edge` with the title in `text_light`; no bar (< 2 s expected). If validation fails → `data_error` base screen (Error State). If load exceeds 2 s, show "Loading cards…" in `text_muted`. | Never a blank frame longer than 2 s without text |
| Match handoff (`begin_match` → Match UI first frame) | ≤ 500 ms (run-ui Game Feel); the boss intro stays visible until the match scene is ready, then `fade` | No loading screen; the Run shell hides, never frees, itself |
| Run start | The `run_start` panel (hero colour, seed) for 600 ms, skippable | Doubles as the one "transition" screen |
| Background async (profile save) | Nothing; failure surfaces as a `save_failed` toast + status line | Saves are small; no spinner |

**Implementation Notes**: Boot is `boot.tscn` with a 2 s `Timer` that reveals the `loading_cards` label; match handoff is `RunShell.hide()` after `MatchScene.ready` (never `queue_free`); `run_start` is the run-ui U2 scene; the profile save is a `WorkerThreadPool` task whose failure emits `run_warning(save_failed)`.

---

#### Empty State

**Category**: Feedback
**Status**: Draft
**When to Use**: Any list, row or tray whose count can be zero; the table below is the inventory, and a new screen with a zero-able collection adds a row here.
**Accessibility**: An empty state is text the player can read and, where an action exists, a focusable button; a "deliberate absence" row must say so in its screen spec so a tester does not log a missing element.

> Every empty list and grid must have a designed empty state. The empty state
> is not an error — it is a starting point.

| Location | Empty State Content | Notes |
|----------|--------------------|----|
| Run log (no archived runs) | Glyph (scroll letter), "No runs yet.", "Finish or fall in a run and it will be recorded here." + New Run (Secondary) | Back keeps focus when the list is empty |
| Run log filtered to a hero with no runs | "No runs with Decay yet." + "Show all heroes" affordance | Mirror the filter back |
| Treasure tray (no treasures) | Tray hidden entirely (match-ui F6) | Hidden, not an empty box; the Progress Strip shows "no treasures" implicitly by absence |
| Draft with `short` offers | Dimmed placeholder slot(s) with "No more treasures in this run" | Not focusable; the remaining options still work |
| Hero select with no locked heroes (MVP) | Locked row absent — no "coming soon" filler (run-ui U7) | Deliberate absence |
| Continue on main menu (no active run) | Button absent | Deliberate absence, not disabled |
| Event feed at match start | Ticker shows the three setup lines (`match_started`, mulligan, turn 1) — never blank | The log always has events by the time the HUD shows |
| Settings Controls page (Alpha) before any rebind | Defaults listed; "Reset to defaults" disabled with reason | — |

**Rule**: Every empty state must include an icon, a message, and either a sub-message or an action button — except the four "deliberate absence" rows above, where showing nothing *is* the design and the spec says so.

**Implementation Notes**: One `empty_state.tscn` (glyph `Label`, message, sub-message, optional Button) with string keys `empty.<location>.*`; a list scene swaps its `ScrollContainer` for the empty scene when `count == 0`; the "deliberate absence" rows are plain `visible = false` on the container and need no scene.

---

#### Error State

**Category**: Feedback
**Status**: Draft
**When to Use**: Anything that went wrong outside the rules of play — data, profile, save, a rejected command or pick; a legal game outcome (defeat, `fault` replay) is never an error state.
**Accessibility**: Every error is text that names what happened and what to do next, persists somewhere non-timed (screen, status line, feed), and is copyable where a report is useful; colour (`state_danger` pills) is decoration on the code, never the message.

| Error Type | Pattern | Tone |
|-----------|---------|------|
| Data validation at boot | `data_error` base screen: count, scrollable rows (file, id, code on `ink` pill in `state_danger`, message), Copy report, Quit (run-ui U2) | Factual: "12 problems in card data. Copy the report and send it along." |
| Profile load problems | One-time status line on the main menu ("restored from backup" / "a copy was kept" / "saved by a newer version") + ReadOnly banner with Retry (meta M5/M6) | Calm; names what happened and what still works |
| Save failed during a run | Warning toast (≥ 5 s, pausable) **and** a persistent line on the next summary/menu | Actionable: "Run could not be saved. Check disk space; the run continues." |
| Rejected match command | Rejection Feedback (shake + tooltip + feed line) | Specific: "Not enough mana (needs 4, have 3)" — never "invalid" |
| Rejected draft pick (`E_*`) | Toast + screen uncommits (run-ui U8) | "That option is no longer offered." (should never happen) |
| Dropped intent during a transition | Silent (debug event only) | Not an error the player made |

**Principle**: Error messages are never the player's fault. They tell the player what happened and what to do next.

**Implementation Notes**: `data_error` is its own base scene (run-ui U2) fed by the Card Database validation report; profile problems set `MainMenu.status_line` from meta M5/M6 codes; `save_failed` goes through `ToastLayer` and the summary / menu status line; match rejections are `RejectionFeedback` keyed `reject.<code>`; draft rejections reuse `ToastLayer` with keys `E_*`. Every message is a string-table key, never a literal.

---

#### Success Confirmation

**Category**: Feedback
**Status**: Draft
**When to Use**: An action whose effect is not itself visible within 50 ms (copy, save-less settings, a pick that waits on an event); never for actions the screen change already confirms.
**Accessibility**: The confirmation is a visible state on the control the player used (label change, pressed lock) that focus can read, with sound as a duplicate channel only; no "Saved" toast competes with the unlock / warning toasts.

| Action | Confirmation | Notes |
|--------|--------------|-------|
| Copy seed / Copy report | Button label flashes "Copied" 1.5 s (`text_light`), short toast variant optional | Label change is the primary cue |
| Pick / Start / Fight | `committed` visual: the chosen locks, siblings dim, Primary stays pressed until the swap | Immediate (≤ 50 ms) |
| Setting changed | Live effect (text grows, motion stops, colours swap) + the control's own state; no "Saved" toast | Meta debounces the write silently |
| Rebind (Alpha) | Row shows the new key; conflict shows the other action's name inline | — |
| Unlock earned | Unlock toast + row on the summary + hero select panel changes | Three channels |

**Implementation Notes**: "Copied" is a 1.5 s `Timer` swapping the button's `text` key (`copy` → `copied`) with no scene change; `committed` is the `OptionRow` flag (Pick One of N); settings rows apply through the Meta setter and read back the live value; the rebind row is the Controls page `List Item` re-rendering its key label.

---

## Animation Standards

> These timing values apply to ALL patterns in this library. When a pattern says
> "150ms ease-out," the easing function is defined here. Consistency in timing
> makes the UI feel like a single designed system rather than a collection of
> individual decisions.

Values are the GDDs' data-file defaults (match-ui F3 `d_base`, run-ui F2 `base_ms`); the
template's generic table is replaced by them. **Project-wide easing rule: ease-out only, no
ease-in, no bounce** (match-ui Game Feel; run-ui Game Feel) — ease-in reads as lag on a
0.25 s tween. Every value is divided by `anim_speed` (match) or multiplied by its
`speed_factor` (run), is 0 at `instant`, and is skippable.

| Animation Type | Duration (ms) | Easing Function | Notes |
|---------------|--------------|----------------|-------|
| Button hover / focus enter | 80 | ease-out | Lift 2 px; no scale |
| Button hover / focus exit | 60 | ease-out | — |
| Button press | 60 | linear | Visible ≤ 33 ms after input (run-ui) |
| Card pickup (drag) | 0 | — | Instant; no tween-in |
| Card hover preview in / out | 100 | ease-out | `HOVER_IN_S`; neighbours never move |
| Card play to board | 250 | ease-out | `play_card`; 4-frame squash on land |
| Drag return (cancel) | 150 | ease-out | No bounce |
| Attack lunge | 350 | ease-out | 6/3/9 frames; hit-stop 60/90 ms (off at `anim_speed = fast` — which drops impact extras, match-ui Tuning Knobs — at `instant`, or under `reduce_motion`) |
| Damage / heal pop | 400 | ease-out | Rises 20 px; fade in place under `reduce_motion` |
| Death group | 300 | ease-out | Then `gap_close` 200 |
| Draw / burn / shield pop / badge / stat recolour | 200 / 400 / 250 / 150 / 150 | ease-out | — |
| Turn banner / intent show / end banner | 400 / 300 / 600 | ease-out | — |
| Overlay open / close (match) | 200 / 150 | ease-out | Scale 0.95→1 removed under `reduce_motion` |
| Reject shake | 200 | linear | 3 px; outline flash under `reduce_motion` |
| Screen fade (run) | 250 | ease-out | `fade` |
| Run start panel | 600 | ease-out | Skippable |
| Boss intro slide | 300 | ease-out | Fade under `reduce_motion` |
| Draft reveal | 3 × 120 stagger | ease-out | One fade under `reduce_motion` |
| Fly-to-strip | 400 | ease-out | Straight path; fade under `reduce_motion` |
| Toast in / out | 200 | ease-out | Fade only under `reduce_motion` |
| Tooltip appear / disappear | 120 / 80 | ease-out | Hover delay 300 ms; focus 0 ms |
| Scroll step | 100 | ease-out | — |
| Victory portrait saturation | 400 | linear | The one colour ramp |
| Boss action gap | 600 (compressed by F4, floor 150) | — | Paced, not eased |

**Motion reduction overrides**: When `reduce_motion` is enabled (see accessibility-requirements.md), all slide and scale animations are replaced with fades at half duration; hit-stop, screen shake and lethal slow-down are removed; looping or pulsing indicators (skip hint, `lethal` banner pulse) are static; the positional gameplay travel kept is match-ui's (card-to-slot, attack lunge, draw, death drop — match-ui Tuning Knobs `reduce_motion`, `d_base` unchanged; un-squashed, because the end position is information) — run-shell slides, including fly-to-strip, become fades per the table row above, run-ui F2 and accessibility-requirements Visual "Reduce motion". `reduce_motion` is independent of `anim_speed`.

---

## Sound Standards

> Every interactive event should have audio feedback. Sound is a primary feedback
> channel, not a decoration. The sounds defined here are event categories — the
> specific audio assets are defined in `design/audio/sound-bible.md` (or
> `design/gdd/sound-bible.md`, where earlier versions put it). This table maps
> interaction events to sound categories so the sound designer and UI programmer
> use the same vocabulary.

No sound bible exists yet. Keys below are the GDDs' own: match-ui uses dotted `sfx.ui.*`
keys, run-ui uses snake `ui_*` event names — **two naming styles that the audio ADR must
unify** (Open Questions). All sounds fire through the audio event bus by key (ui-code rule 5);
skipped animation steps fire no sound; every sound is the audio half of a visible event
(accessibility-requirements SFX Audit). Volume: SFX bus (UI shares it), music bus, master.

| Interaction Event | Sound Category / key | Notes |
|------------------|---------------|-------|
| Focus move / hover enter | `ui_hover` | Very short, quiet; non-fatiguing on rapid Tab |
| Button (Primary) activate | `ui_select` / `ui_pick` (draft) | Confirm feel |
| Button (Secondary) back / cancel; drawer close | `ui_select` cancel variant (pitch-down) | Same family |
| Button (Destructive) → confirm opens | `sfx.ui.overlay` | No warning buzzer — the dialog is the warning |
| Confirmation confirmed | `ui_select` weighted variant | Final |
| Toggle / Segmented change | `ui_select` | — |
| Slider step | `ui_slider_tick` | One per step; volume sliders tick at the new level |
| Overlay open / close (match) | `sfx.ui.overlay` | — |
| Toast — unlock / warning / Copied | `ui_unlock` / none / `ui_select` | Warnings are silent by design (run-ui Visual/Audio) |
| Card lift / play | `sfx.ui.card_lift` / `sfx.ui.card_play` | — |
| Attack | `sfx.ui.attack_whoosh` + `sfx.ui.impact_light` / `impact_heavy` (≥ 5) | — |
| Damage / heal / shield / death | `sfx.ui.damage` / `heal` / `shield_pop` / `death_thud` | One `death_thud` per group |
| Draw / burn / fatigue | `sfx.ui.draw` / `burn` / `heartbeat` | — |
| End Turn / boss turn start | `sfx.ui.end_turn` / `sfx.ui.turn_chime` | — |
| Intent shown / plan changed | `sfx.ui.page_turn` / `sfx.ui.plan_changed` | — |
| Rejection | `sfx.ui.deny` | Soft "no", not a buzzer |
| Match end | `sfx.ui.victory` / `sfx.ui.defeat` | — |
| Draft reveal / pick | `ui_draft_reveal` / `ui_pick` | Rare treasure: brighter variant |
| Run start / boss intro / run end | `run_start` / `boss_intro_<band>` / `run_victory` / `run_defeat` | — |
| Hero selected | hero-specific sting (heroes.md) | — |
| Ambient | `music.match_ambient` | Ducked under stingers |

---

## Gaps & Patterns Needed

Patterns the screens will need that this version does not fully specify, or that need a
GDD change before they are real:

| Gap | Needed by | What is missing | Proposed owner |
|-----|-----------|-----------------|----------------|
| Keyword Glossary overlay | pause-menu, settings, Card Inspect reading panel | Not in any GDD; needs a `keywords.json` string table (DD-M09 set) and an overlay spec | Jacob to assign Run UI or Match UI (accessibility-requirements Open Questions) |
| Controls / rebinding page | settings (Alpha) | Key-capture Input Field, conflict rule, storage key (meta M9) | Meta Progression + Run UI |
| ~~Gamma slider~~ | settings | **Closed 2026-11-03 — DD-X10**: Meta M9 `gamma` 0.8–1.4 (1.0), run-ui `settings` slider, `CanvasModulate` hook in Match UI and Run UI | — |
| ~~Deck drawer~~ | draft-picker, hero-select | **Closed 2026-11-03** — `Deck Drawer` entry under Screen-Owned Compound Patterns; owning spec `draft-picker.md` §5.2 / §6 (960, 96, 320, 536 with a header "×" close — rect shortened 2026-11-03 so the toggle stays visible; non-blocking) | — |
| ~~Compact card row (bundle panel)~~ | draft-picker | **Closed 2026-11-03** — `Compact Card Row` entry; the reading panel on focus is the 150 % path (`draft-picker.md` §12, fixture `draft_bundle_sample_ts150`) | — |
| ~~Top bar~~ | hud | **Closed 2026-11-03** — `Top Bar` entry; layout and focus stops 7–8 in `hud.md` §4.2 | — |
| Settings-quick-access in match pause | pause-menu | Add music volume; decide which Segmented Selects appear in-match (anim_speed, reduce_motion only per match-ui U9) | `/ux-design pause-menu` |
| Screen-reader naming convention | all | A rule for `accessibility_name` strings per pattern once AccessKit live-region behaviour is sourced | ux-designer |
| Consolidation check | — | Match Choice `1`–`3` *selects* while run `1`–`3` *focuses*; both are two-step, but the words differ — unify wording in both GDDs | `/consistency-check` |
| Audio key naming | all | `sfx.ui.*` vs `ui_*` | Audio ADR |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Does Godot 4.7 AccessKit announce `Control.accessibility_live` changes (toasts, feed lines) without focus? NOT SOURCEABLE from `docs/engine-reference/godot/` beyond the property's existence. | ux-designer | Before first menu implementation | Unresolved |
| Click-to-Select pointer entry into `KeyTargeting` and the 8 px click/drag threshold: amend match-ui U5? | Match UI GDD | Before `/ux-design targeting` | **Resolved 2026-11-03** — match-ui U5 "Click to select", Tuning Knobs `CLICK_DRAG_PX` 8 (4–12), States `KeyTargeting` `entered_by` |
| `Tab` in match idle as inspect-cycle (extends match-ui U5 where `Tab` exists only in targeting). | Match UI GDD | Before `/ux-design hud` | **Resolved 2026-11-03** — match-ui U5 "Keyboard inspect (focus cycling in `Idle`)"; this library's Focus Management owns the stop list, `hud.md` the per-element order |
| `end_turn_arm_ms` (300 ms proposed) to separate skip from End Turn on the same key; alternative: Space = skip only, Enter = End Turn. | Match UI GDD + Jacob | Before `/ux-design hud` | **Resolved 2026-11-03** — guard adopted: match-ui U5 "Arm guard", Tuning Knobs `end_turn_arm_ms` 300 (150–600) |
| Esc on Mulligan / Choice / end banner → pause menu (not "close overlay"). | Match UI GDD | Before `/ux-design choice-overlay` | **Resolved 2026-11-03** — Mulligan / Choice: pause menu opens over them (match-ui U5, O19); end banner: **`Esc` does nothing**, pause unreachable in `Ended` (DD-X09) — chain step (4a) |
| Toast floor 5000 ms / cap 8000 ms and hover-pauses-timer (run-ui F3 ranges widen). | Run UI GDD | Before `/ux-design toast` | **Resolved 2026-11-03** — run-ui F3 `toast_min_ms` 5000 / `toast_max_ms` 8000, hover (or LMB hold) pause — toasts take no focus — one toast at a time |
| Unaffordable-card cue: dashed `text_muted` cost ring (proposed) and whether 60% alpha keeps `text_ink` on `parchment` ≥ 4.5:1. | `/ux-design hand` + art-director manual pass | Pre-Production | Open |
| `F11` fullscreen and `Ctrl+C` copy conveniences — adopt as default `InputMap` actions? | Jacob | Pre-Production | Proposed |
| Reading panel at `text_scale` 125/150% — approve as the card-text scaling path. | Jacob | `/ux-design hand` | Open (accessibility-requirements recommends it) |
| Audio key naming (`sfx.ui.*` vs `ui_*`) — pick one before `/asset-spec`. | Audio ADR | Before `/create-architecture` | Open |
| Which Segmented labels for `anim_speed` (Normal / Fast / Fastest / Instant) map onto match-ui's `1.0 / 1.5 / 2.0 / instant`, and does run-ui's `action delay` slider stay? | Run UI + Match UI GDDs | `/consistency-check` | **Resolved 2026-11-03 — DD-X07**: three labels `Normal / Fast / Instant` (`normal | fast | instant`); match-ui F3 `SPEED_DIV` maps them (normal 1.0, fast 2.0, instant = final states); the `action_delay_ms` slider stays and overrides Boss AI's `presentation.action_delay_s` (match-ui F4) |
| Maximum visible toasts: run-ui U5 says one at a time; template suggests 3. Keep one (less load) — confirm in playtest. | ux-designer | First playtest | Provisional: one |
