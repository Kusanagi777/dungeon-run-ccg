# UX Spec: Match End (end banner and the `match_view_finished` hand-off)

> Authoring guidance: .claude/docs/templates/guidance/ux-spec-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Design
> **Author**: Jacob + ux-designer (`/ux-design match-end` followed by hand — the skill is not model-invocable; automation `guided` under the owner's standing approval, workflow `standard`, density `balanced` from `rigor: standard`; no `AskUserQuestion` used — the recommended option was taken at every decision point and is listed in §15; no Agent tool — `art-director` / `ui-programmer` / `narrative-director` not spawned)
> **Last Updated**: 2026-11-04
> **Journey Phase(s)**: The close of every match (game-concept Core Loop "One match (3–6 minutes)") and the hinge into the next run step — a draft (floors 1–7 won), the run summary (a loss, or floor 8 won) or the same boss again after a rules fault ("Attempt 2"). View state `Ended` (match-ui States); engine phase `Ended` (match-rules States). `design/player-journey.md` does not exist — see §15.
> **Screen / Flow Name**: `MatchEndBanner` — the end-banner variant of `banner.tscn` / `BannerPresenter` (ADR-0009: the one place `AnimationPlayer` clips are allowed), plus `MatchView`'s `Ended` state that emits `match_view_finished(result)` (ADR-0008 Decision 8, ADR-0011).
> **Platform Target**: PC (Windows primary, Linux dev/CI); 1280x720 logical, `canvas_items` + `keep` (DD-T05); mouse primary, keyboard complete; gamepad `Partial` post-v1; touch none (`project.yaml` has no `platform` block — values from `.claude/docs/technical-preferences.md` via `design/accessibility-requirements.md`).
> **Related GDDs**: `design/gdd/match-ui.md` U3 (`match_ended`, `log_overflow`, `resolution_overflow` rows), U4.5 (skip allowed during the end banner), U5 (`Esc` does nothing on the end banner; pause unreachable in `Ended`), U9 (Match end, the `fault` variant, `MATCH_END_AUTO_S` 4 s, `match_view_finished(result)`, "the Match UI never navigates"), U11 (`match_end_*` fixtures, `--pose=end:<reason>`), States (`Ended`), F3 (`end_banner` 0.6 s), F6 (end banner 340, 260, 600, 200), Edge Cases (fault, `match_ended` while dragging, `Esc` on the banner), Tuning Knobs (`MATCH_END_AUTO_S` 2–8), Visual/Audio ("Match end" row), UI Requirements ("Match end overlay" → this file), AC O13, O19; `design/gdd/match-rules.md` C14 (outcomes `hero_dead` / `both_dead` / `concede` / `turn_cap`, faults `resolution_overflow` / `event_cap`, `MatchResult` fields), States (`Ended`), Visual/Audio (`match_ended`: "both_dead and concede carry their own copy; a fault shows the rules-error screen with the reason, never a loss banner"); `design/gdd/run-ui.md` U2 `match` row, States S11 / S11b / S16, AC-29 (what follows the hand-off); `design/gdd/run-structure.md` (via run-ui: `match_faulted` → `pre_match` replay; DD-R07 a loss ends the run); `design/design-decisions.md` DD-M12 (both dead → boss wins), DD-R07, DD-R08, DD-X09.
> **Related ADRs**: ADR-0008 (Decision 8: `match_view_finished(result)` after the end banner; Run Structure has already processed `match_ended`); ADR-0009 (`BannerPresenter`); ADR-0011 (`RunShell` consumes `match_view_finished`).
> **Related UX Specs**: `design/ux/hud.md` (APPROVED — §5 `Ended` row, §8 "End banner" notification row, §10.1 victory saturation, §12 match-end rows); `design/ux/run-summary.md` (APPROVED — the summary that follows a loss or the floor-8 win; "Never: a `fault` match"); `design/ux/draft-picker.md` (APPROVED — the draft that follows a floor 1–7 win, entered after "watching the match-end banner for up to 4 s"); `boss-intro.md` (not yet written — "Attempt n" after a fault, run-ui S11b); `pause-menu.md` (not yet written — the concede that can end a match); `design/ux/interaction-patterns.md` (Overlay Open / Close "Match-end banner", Button (Primary), Escape / Cancel step (4a), Skip & Playback "When NOT to Use", Error State "a legal game outcome is never an error state", Animation / Sound Standards); `design/accessibility-requirements.md`.
> **Accessibility Tier**: Standard with reduce-motion, visual-for-every-sound and the high-contrast state set elevated (`design/accessibility-requirements.md`). The banner is one of the four auto-dismissing elements in Cognitive "Reading time" (4 s, acceptable because the next screen repeats the result).
> **Template**: UX Spec

> **Sources read** (by section, coordination rule 6): match-ui Summary, U1–U12, States, Interactions, F3, F6, Edge Cases, Dependencies, Tuning Knobs, Visual/Audio, Game Feel, UI Requirements, AC, Open Questions; match-rules C2, C14, C15, States, Visual/Audio, UI Requirements, Edge Cases (both dead, concede during the boss turn, overflow); run-ui (grep: `match_view_finished`, S10–S16, S11b, AC-29, `match` row, Interactions / Dependencies Match UI rows); design-decisions (all rows); art bible §1–4, §7; accessibility-requirements Commitment, Visual (flash rule), Colour audit ("Victory vs defeat summary"), Motor, Cognitive "Reading time" / "Pause anywhere"; interaction-patterns Catalog, Button (Primary), Overlay Open / Close, Escape / Cancel, Standard Shortcuts, Skip & Playback, Error State, Success Confirmation, Animation / Sound Standards; hud.md §1, §3–§5, §8, §10, §12; run-summary.md §2–§4; draft-picker.md §2–§4; story MUI-011, MUI-019; `production/session-state/active.md` (sibling conventions).

> **Note — Scope boundary**: This document owns the match's last state: from `match_ended` being projected to the single `match_view_finished(result)` emission — the drain, the banner, its six variants, the portrait saturation, Continue and auto-advance. What the run shows next is Run UI's (run-ui S11 / S11b / S16 and its specs); the concede dialog that can end a match is `pause-menu.md`'s. Numbers marked **F6** / **F3** are match-ui's; numbers marked *spec* are this document's.

---

## 1. Purpose & Player Need

**What player need does this screen serve?**

The player needs to know, at once and in words, how the match ended and why — and then to move on quickly. Pillar 3 ("lose fast, learn fast") wants a loss to read as "I see why" (art bible §2 Defeat: "clear-eyed loss, never punishment") and the next attempt to be close; a win wants a moment of release before the draft. Pillar 4 ("readable, deterministic rules") adds two duties the generic "You win / You lose" banner would fail: **both heroes dying is a defeat** (DD-M12) and must say so, and a **rules fault is not a defeat at all** — "this floor is replayed, not lost" (match-ui U9) — so a player who just watched the engine break never believes they lost their run.

**The player goal** (what the player wants to accomplish):

Read the outcome and its reason in one glance, see the final state of the board that produced it, and continue — immediately with a press, or by waiting 4 seconds.

**The game goal** (what the game needs to communicate or capture):

Render `match_ended`'s `MatchResult` truthfully by `result` and `reason`, play the matching stinger (none for a fault), then emit `match_view_finished(result)` **exactly once** so Run UI can show whatever Run Structure has already decided (draft, summary, or the boss intro "Attempt n"). The Match UI never navigates and does not know about floors (U9).

---

## 2. Player Context on Arrival

| Question | Answer |
|----------|--------|
| What was the player just doing? | Winning: landing the lethal hit on their own turn (the lethal slow-down, match-ui Impact Moments). Losing: watching the boss turn deliver the intent the banner forecast, often skipping it with `Space` / clicks. Conceding: confirming Concede in the pause menu (any phase but `Ended`, including the mulligan). Fault: watching a chain that never settled (`resolution_overflow`) or a log cap (`event_cap`). |
| What is their emotional state? | Win: relief; floor 8: "earned relief, a little disbelief" (art bible §2 Victory). Loss: the sting of a run ending (DD-R07) — the banner must be factual, not punishing. Fault: confusion — "did I lose?" — which the copy answers before anything else. |
| What cognitive load are they carrying? | Low — the match is over; the one open question is *why*. |
| What information do they already have? | The final board (it stays visible behind the fill dim), both heroes' health, the feed ticker's last lines. |
| What are they most likely trying to do? | Confirm the outcome and continue; after a loss, take one look at the board that beat them. |
| What are they likely afraid of? | A skip press carrying straight through the banner unread; a fault reading as a run-ending loss; being trapped (no exit). |

**Emotional design target for this screen**:

"Said plainly, then let go" — one headline, one reason, the board still visible, and the next screen one press (or four seconds) away; a fault reads as an apology, not a verdict.

---

## 3. Navigation Position

**Screen hierarchy**:

```
Run shell → Boss Intro → Match scene (hud.md)
  └── … any view state … → match_ended projected → queue drains
        └── Ended: End banner (this spec) — modal, no cancel, no pause
              └── match_view_finished(result) → Run UI applies the buffered run-scope events (run-ui S11):
                    ├── draft_offered        → Draft Picker (floors 1–7 won)          draft-picker.md
                    ├── run_ended            → Run Summary victory / defeat            run-summary.md
                    └── run_floor_entered    → Boss Intro "Attempt n" (after a fault)  boss-intro.md (S11b)
```

**Modal behavior**: Modal with **no cancel and no pause** (DD-X09; Overlay Open / Close row "Match-end banner: Esc — Nothing"; Escape / Cancel step (4a)). The base is input-disabled from the moment `result` is set (match-ui Edge Cases); no command can be issued (match-rules: every command → `MATCH_ENDED`). The only exits are Continue (press) and `MATCH_END_AUTO_S` (4 s). The player cannot be stuck: the auto-advance always fires.

**Reachability — all entry points**:

| Entry Point | Triggered By | Notes |
|-------------|-------------|-------|
| Player win | `match_ended{result: win, winner: PLAYER, reason: hero_dead}` | Fixture `match_end_victory` |
| Player loss | `match_ended{result: loss, reason: hero_dead}` | `match_end_defeat` |
| Both dead | `match_ended{result: loss, reason: both_dead}` (DD-M12) | `match_end_both_dead` |
| Concede | `match_ended{result: loss, reason: concede}` from any phase except `Ended` (incl. `Mulligan`, `Choice`, the boss turn) | `match_end_concede` |
| Turn cap | `match_ended{result: loss, reason: turn_cap}` (`TURN_CAP` 100 — unreachable in normal play, C14) | `--pose=end:turn_cap` (§15) |
| Rules fault | `match_ended{result: fault, winner: null, reason: resolution_overflow \| event_cap}` (U3 rows `log_overflow`, `resolution_overflow`) | `match_end_fault` (scripted `resolution_overflow`); `event_cap` via `--pose=end:event_cap` |

---

## 4. Entry & Exit Points

**Entry table**:

| Trigger | Source Screen / State | Transition Type | Data Passed In | Notes |
|---------|----------------------|-----------------|----------------|-------|
| `match_ended` projected | Any view state | **Input locks at once**; an open targeting session is cancelled; open overlays (pause, concede confirm, Mulligan, Choice) close (`overlay_close` 0.15 s); the queue keeps draining the steps that led here (lethal pop, death group) — skippable | `MatchResult` (§8) | match-ui Edge Cases "`match_ended` while dragging"; U9 "finishes draining" |
| Queue drained with `result` set | `Playback` / `BossTurn` → `Ended` | `end_banner` 0.6 s (F3): table fill steps to `table_dark`, the banner fades and scales 0.95 → 1.0 into 340, 260, 600, 200; winning portrait saturation ramp 0.4 s in parallel; stinger on the banner's first frame | Variant from `result` + `reason` (§6) | `sfx.ui.victory` / `sfx.ui.defeat`; **none** for `fault` |

**Exit table**:

| Exit Action | Destination | Transition Type | Data Returned / Saved | Notes |
|-------------|------------|-----------------|----------------------|-------|
| Continue — LMB anywhere or `Enter` / `Space`, once **armed** (§6) | Run UI's next screen (S11 decides) | Banner holds; `match_view_finished(result)` is emitted on the input frame; Run UI's `fade` 250 ms replaces the match scene | `match_view_finished(result)` — nothing is saved by this screen; Run Structure processed `match_ended` (and saved, DD-R08) before the banner appeared | Emitted **exactly once**; further input ignored |
| Auto-advance | Same | Same, after `MATCH_END_AUTO_S` 4 s from the banner settling | Same | The countdown is shown on the button (§5.1) |
| `Esc` / top-bar menu button | — | **Nothing** (DD-X09) — the frame is pixel-identical to the un-pressed one | — | match-ui O19 |
| Window closed | — | — | Nothing lost: the run state already reflects the match (Run Structure T6–T9 ran first) | A floor-1–7 win resumes into its draft; a loss resumes into nothing (the run is archived) |

---

## 5. Layout Specification

### 5.1 ASCII Wireframe

Victory (fixture `match_end_victory`), War hero, banner at F6 340, 260, 600, 200; the player portrait saturated to War's primary; the board visible on the dimmed fill:

```
 x:0  24      144          340                                        940              1136    1256 1280
 y:0 ┌───────────────────── top bar (lit; menu button inert) ────────────────────────────────── [≡]┐
  48 │ [ticker — last lines, lit]                                                     ┌────────┐     │
  96 │                                                                                │  boss  │     │
 176 │            ┌─ boss row (final state, fill table_dark, tokens unchanged) ─┐     │ (band) │     │
 260 │            ┌═══════════════════════ end banner 600 x 200 ════════════════════┐ └────────┘     │
 276 │            ║                         Victory                (28 px bold)     ║                │
 318 │            ║                The Torchbearer is defeated.    (16 px)          ║                │
 346 │            ║            Turn 9 · You 14 health · Boss 0     (16 px muted)    ║                │
 334 │ ┌────────┐ ║                                                                 ║  border: hero  │
 400 │ │ player │ ║                      ( Continue · 4 )   Primary 160x44 at 560,400 ║  primary 2 px  │
 460 │ │SATURATD│ └═════════════════════════════════════════════════════════════════┘                │
 494 │ └────────┘   (hand fan under the dim — no outlines)                                             │
 720 └─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

Fault (fixture `match_end_fault`): neutral frame, no saturation, no stinger, a detail line instead of the health facts:

```
 260 ┌──────────────────────── end banner 600 x 200 (border `text_muted`, neutral) ───────────────────┐
 276 │                                  Rules fault                         (28 px bold)               │
 318 │                       This floor is replayed, not lost.              (16 px text_light)         │
 346 │                   Error: resolution_overflow · turn 7                (16 px text_muted)         │
 400 │                               ( Continue · 4 )                                                  │
 460 └─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

Inside the banner (*spec*): headline centred, top y 276, 28 px bold `text_light`; reason line top y 318, 16 px `text_light`; facts / detail line top y 346, 16 px `text_muted`; Continue (Button (Primary) 160x44) at **560, 400**, 16 px above the banner's bottom edge. Banner fill `table_dark` with a 2 px border: hero primary on a victory, the boss's band colour on a boss win (defeat, both-dead, concede, turn cap), `text_muted` on a fault.

### 5.2 Layout Zones

| Zone Name | Description | Approximate Size | Scrollable? | Overflow Behavior |
|-----------|-------------|-----------------|-------------|-------------------|
| Dimmed table | The table fill steps `table_lit` → `table_dark`; tokens, hand, piles keep their contrast; **both portraits stay undimmed** so the saturation (and the boss's band fill) read; the feed ticker and the top bar stay lit (art bible §2: the event log is lit in every state) | 1280 x 720 | No | — |
| End banner (F6) | 340, 260, 600, 200 — `table_dark`, 4 px radius (art bible §3), 2 px variant border | 600 x 200 | No | At `text_scale` 150 % on the fault variant (four text rows) the banner grows 20 px upward to 340, 240, 600, 220 (*spec*, §12) |
| Headline | 28 px bold `text_light`, centred, one line | 568 x 34 | No | ≤ 20 chars English; shrinks to 24 px, never wraps |
| Reason line | 16 px `text_light`, centred, ≤ 2 lines | 568 x 20 (40) | No | Wraps to a second line; the facts line moves down by 20 |
| Facts / detail line | 16 px `text_muted`, centred | 568 x 20 | No | Ellipsises the hero / boss names first, never the numbers |
| Continue | Button (Primary) 160x44 at 560, 400; label "Continue · n" with the whole seconds left | 160 x 44 | No | Label grows the button symmetrically (Button pattern) |
| Portraits | F6 24, 334 (player) / 1136, 96 (boss) — the winner's panel at its full identification colour (§6) | 120 x 160 each | No | — |

### 5.3 Component Inventory

| Component Name | Type | Zone | Purpose | Required? | Reuses Existing Component? |
|----------------|------|------|---------|-----------|---------------------------|
| End banner | Modal panel | F6 rect | Outcome, reason, facts, Continue | Yes | Yes — Overlay Open / Close "Match-end banner"; `BannerPresenter` (ADR-0009) |
| Headline | Text | Banner | `end.<variant>.title` | Yes | Plain `Label` |
| Reason line | Text | Banner | `end.<variant>.line` with `{boss}` / `{hero}` | Yes | Plain `Label` |
| Facts line | Text | Banner | "Turn n · You h health · Boss h" from `MatchResult` | Yes (not on fault) | Plain `Label` — **new here** (*spec*) |
| Fault detail line | Text | Banner | "Error: <reason> · turn n" | Fault only | Plain `Label` — **new here**; the Error State "names what happened" rule |
| Continue | Button (Primary) | Banner | Early advance; shows the countdown | Yes | Yes — Button (Primary); End Turn Button "When NOT to Use" names it |
| Countdown | Text (in the label) | Continue | Seconds left of `MATCH_END_AUTO_S` | Yes | **New here** (*spec*) — reading-time aid, no animation |
| Winner portrait saturation | Fill ramp | Portrait | Victory: the hero panel ramps to its primary (art bible's one fill exception) | Yes (not on fault) | Yes — art bible §4 rule b exception; hud.md §10.1 |
| Stinger | Audio | — | `sfx.ui.victory` / `sfx.ui.defeat` | Yes (none on fault) | Yes — match-ui Visual/Audio |

**Primary focus element on open**: **Continue** (Overlay table "Focus on open: Continue"), with the 2 px focus ring; it is the only stop.

### 5.4 Information Hierarchy

1. **Outcome** — the headline: Victory / Defeat / Conceded / Rules fault.
2. **Why** — the reason line: who fell, that a tie goes to the boss, that the floor is replayed.
3. **The receipt** — the facts line (turn and both final health numbers) and, behind the banner, the board exactly as it ended; the feed ticker's last lines.
4. **What to do** — Continue, with the time left.

---

## 6. States & Variants

**Variant key** — `end.<variant>` from `result` + `reason` (match-rules C14). Copy is final English (match-ui U12 gives final copy to `/ux-design`); `{boss}` / `{hero}` resolve through Card Database name keys, never payload strings (match-ui U10).

| Variant | `result` / `reason` | Headline | Reason line | Facts / detail line | Border | Saturation | Stinger |
|---|---|---|---|---|---|---|---|
| `victory` | win / `hero_dead` | "Victory" | "{boss} is defeated." | "Turn {turns} · You {hero_hp} health · {boss} {boss_hp}" | Hero primary | Player portrait → hero primary (0.4 s ramp) | `sfx.ui.victory` |
| `defeat` | loss / `hero_dead` | "Defeat" | "You fell to {boss}." | Same facts line | Band colour | Boss portrait at its band fill, undimmed (§15) | `sfx.ui.defeat` |
| `both_dead` | loss / `both_dead` | "Defeat" | "Both heroes fell — a tie goes to the boss." | Same | Band colour | As defeat | `sfx.ui.defeat` |
| `concede` | loss / `concede` | "Conceded" | "You conceded to {boss}." | Same | Band colour | As defeat | `sfx.ui.defeat` |
| `turn_cap` | loss / `turn_cap` | "Defeat" | "The match reached the turn limit — the boss wins." | Same | Band colour | As defeat | `sfx.ui.defeat` |
| `fault` | fault / `resolution_overflow` \| `event_cap` | "Rules fault" | "This floor is replayed, not lost." | "Error: {reason} · turn {turns}" | `text_muted` (neutral) | **None** (neither portrait) | **None** |

Final health is shown as logged (a hero can end below 0 — "You −3 health" is the truth, Pillar 4).

| State Name | Trigger | What Changes Visually | What Changes Behaviorally | Notes |
|------------|---------|----------------------|--------------------------|-------|
| Draining | `match_ended` projected, queue not empty | Nothing new — the remaining steps (lethal pop, death group) play; overlays close; a session is cancelled | All input except skip is ignored; skip flushes to the end state | Input locked from the moment `result` is set |
| Entering | Queue drained → `Ended` | `end_banner` 0.6 s; saturation ramp 0.4 s; stinger | Any input completes the entry instantly (U4.5 skip) and is **not** a Continue | Prevents a skip press from the boss turn dismissing the banner unread |
| Settled, not armed | Entry complete | Banner static; Continue shows "Continue · 4" with the focus ring | Input ignored for `end_turn_arm_ms` (300 ms) after settling (*spec*, §15) | The same accidental-activation guard End Turn uses |
| Armed | 300 ms after settling | Unchanged | LMB anywhere, `Enter` or `Space` → Continue | U9 "waits for a click"; hud.md §8 "Click / Enter advances early" |
| Counting down | From settling | Label "Continue · 4" → "· 3" → "· 2" → "· 1", once per second | — | No motion; a text change per second is within the flash rule |
| Continued / auto-advanced | Armed input, or `MATCH_END_AUTO_S` elapsed | Continue pressed state; banner holds until Run UI's fade covers it | `match_view_finished(result)` emitted once; every later input ignored | The Match UI does not fade itself out |
| `Esc` / menu button pressed | Any time in `Ended` | **Nothing** | Nothing — no pause menu, no cancel (DD-X09) | O19 |
| Concede from the Mulligan / Choice | `concede` in `Mulligan` / `ChoiceOpen` | The overlay and the pause menu close (0.15 s) before the banner | As above | match-rules C14 |
| `text_scale` 125 % / 150 % | Setting | Headline 35 / 42 px, lines 20 / 24 px, button label scaled; at 150 % the fault variant's banner grows to 340, 240, 600, 220 | — | Fixtures *proposed* `match_end_victory_ts150`, `match_end_fault_ts150` |
| `reduce_motion` | Setting | Banner entry fades (no scale); the saturation ramp stays (a single ramp, not a loop — hud.md §10.3); countdown is text | — | — |
| `anim_speed = instant` / fast | Setting | `end_banner` 0 / 0.3 s; the ramp follows the same divisor; **auto-advance stays 4 s** (it is reading time, not animation) | Arm guard still 300 ms | `MATCH_END_AUTO_S` is not divided by `SPEED_DIV` (§15 confirms) |
| `high_contrast_states` | Setting | Unchanged — no state colour on this screen | — | — |

There is **no empty, loading or error state**: the banner always has a variant (every `MatchResult` maps to one of six), and a fault is a designed variant, not an error screen (Error State: "a legal game outcome … is never an error state"; match-rules Visual/Audio's "rules error screen" is this variant).

---

## 7. Interaction Map

Mapping interactions for: **keyboard + mouse** (Phase 2h — no `platform` block; technical-preferences via accessibility-requirements). Covering **Partial** gamepad support as a post-v1 mapping; touch not supported.

### 7.1 Navigation Inputs

| Input | Platform | Action | Visual Response | Audio Cue | Notes |
|-------|----------|--------|-----------------|-----------|-------|
| `Tab` / `Shift+Tab` | KB | None — Continue is the only stop and already focused | Ring stays | — | Focus is trapped (modal) |
| Mouse hover | PC | Continue: Button hover (lift 2 px) | Lift | `ui_hover` | — |
| `Esc` | KB | **Nothing** | — | — | Escape / Cancel step (4a); DD-X09 |
| RMB | PC | Nothing | — | — | No session, no drawer |
| `L` / feed toggle | KB / PC | Nothing in `Ended` (the ticker stays visible and lit) | — | — | §15 proposes allowing the drawer |
| Gamepad (post-v1) | — | `ui_accept` = Continue; `ui_cancel` = nothing | Same | Same | Not wired in v1 |

### 7.2 Action Inputs

| Input | Platform | Context (What must be focused) | Action | Response | Animation | Audio Cue | Notes |
|-------|----------|-------------------------------|--------|----------|-----------|-----------|-------|
| Any input | all | Draining / Entering | Skip to the settled banner | Steps and entry complete in one frame | 0 | Skipped steps' SFX dropped; the stinger plays once on the settled frame if it had not yet | U4.5 |
| LMB (anywhere) / `Enter` / `Space` | PC / KB | Armed (≥ 300 ms after settling) | Continue | Continue pressed; `match_view_finished(result)` | 60 ms press | `ui_select` | Exactly once |
| LMB / `Enter` / `Space` | PC / KB | Settled, not armed | Nothing (swallowed) | — | — | — | The arm guard |
| No input | — | Settled | Auto-advance after 4 s | As Continue | — | `ui_select` | `MATCH_END_AUTO_S` |
| Top-bar menu button | PC | Any `Ended` state | Nothing | — | — | — | U9 / DD-X09 — the button draws as Disabled (`text_muted`, no hover lift) so it does not invite a click |

### 7.3 State-Specific Behaviors

| State | Input Restriction | Reason |
|-------|------------------|--------|
| Draining / Entering | Skip only | The board that ended the match is shown, never jumped over without the player's input |
| Settled, not armed | Everything swallowed | A skip burst from the boss turn cannot dismiss the banner (*spec*) |
| Armed | Continue only | One exit (DD-X09) |
| After Continue | Everything ignored | `match_view_finished` exactly once (story MUI-011) |

---

## 8. Data Requirements

| Data Element | Source System | Update Frequency | Who Owns It | Format | Null / Missing Handling |
|--------------|--------------|-----------------|-------------|--------|------------------------|
| `result`, `winner`, `reason` | Match Rules `match_ended` → `MatchViewState.result` (U3) | Once | Match Rules (C14) | `result: win \| loss \| fault`; `winner: PLAYER \| BOSS \| null`; `reason: hero_dead \| both_dead \| concede \| turn_cap \| resolution_overflow \| event_cap` | An unknown `reason` → the `defeat` variant for `loss`, `fault` for `fault`, with `??end.<reason>` in the detail line + debug warning (never a blank banner) |
| `turns` (global), final hero health both sides | `MatchResult` (C14 "turns (global) … final hero health both sides") | Once | Match Rules | ints | Missing → the facts line is omitted (headline and reason stand alone) |
| Hero name / primary colour; boss name / band colour | `MatchConfig` + Card Database / Heroes (via `MatchQuery.card_text` / hero records) | Static | Run Structure (config) / Card Database / Heroes | keys, tokens | Missing name → "the boss" / "You"; missing colour → neutral border |
| `MATCH_END_AUTO_S` (4), `end_turn_arm_ms` (300), `d_base.end_banner` (0.6) | `match_ui.json` via `config("match_ui")` | Once at `_ready` | Match UI | numbers | Validated at boot |
| Settings: `text_scale`, `reduce_motion`, `anim_speed`, volumes | Meta Progression (DD-X07) | Read once | Meta | Record | Defaults |
| Floor, run outcome, what comes next | **Not read** — Run UI decides after the hand-off (U9: the Match UI does not know about floors or drafts) | — | Run Structure / Run UI | — | The banner never says "Run over" or "Next: draft" |

> **Rule**: This screen must never write directly to any system listed above. All
> player actions fire events (see Section 9). Systems update their own data and
> notify the UI.

---

## 9. Events Fired

| Player Action | Event Fired | Payload | Receiver System | Notes |
|---------------|-------------|---------|-----------------|-------|
| Continue (press) or auto-advance | `match_view_finished(result)` (signal) | `MatchResult` as projected | Run UI `RunShell` (run-ui S11; ADR-0011) | **Emitted exactly once.** Not a command — Run Structure already consumed `match_ended` and saved (DD-R08); this signal only returns control of the screen. No persistent state changes here |
| Skip during draining / entry | `skip_all` (local) | — | `AnimationQueue` | — |
| `Esc` / menu button / input before armed | none | — | — | Deliberately no event (and no `ui_intent_rejected`) |

No analytics in v1; `match_ended` in the event log is the record.

---

## 10. Transitions & Animations

| Transition | Trigger | Direction / Type | Duration (ms) | Easing | Interruptible? | Skipped by Reduced Motion? |
|------------|---------|-----------------|--------------|--------|----------------|---------------------------|
| Overlays close on `match_ended` | `result` set while Mulligan / Choice / pause is open | `overlay_close` | 150 | ease-out | Yes (skip) | Fade (already) |
| Screen enter (banner) | Queue drained | Fill steps to `table_dark`; banner fades + scales 0.95 → 1.0 | 600 (`end_banner`) ÷ `SPEED_DIV` | ease-out | Yes — any input completes it (not a Continue) | Scale removed → fade |
| Winner portrait saturation | With the banner | Fill ramps from the dimmed panel value to the hero primary | 400 | linear (Animation Standards "The one colour ramp") | Yes (completes) | No — single ramp (hud.md §10.3) |
| Countdown | Each second while settled | Label digit changes | 0 | — | — | — |
| Continue press | Armed input | Button depress | 60 | linear | — | — |
| Screen exit | `match_view_finished` | **Owned by Run UI** — its `fade` 250 ms replaces the match scene (Screen Push / Pop / Replace) | 250 | ease-out | — | — |

Impact moments: the stinger and the saturation are the match's closing beat; no shake, no flash (accessibility-requirements "Screen flash": the saturation is a single 400 ms ramp).

---

## 11. Input Method Completeness Checklist

Platform Target is keyboard + mouse; **Touch** dropped; **Gamepad** unticked as the post-v1 mapping. Every untick has a §15 row.

**Keyboard**
- [x] All interactive elements are reachable using Tab and arrow keys alone (one stop, focused on open)
- [x] Tab order follows visual reading order (single stop)
- [x] Every action achievable by mouse is also achievable by keyboard (Continue by `Enter` / `Space`)
- [x] Focus is visible at all times (2 px ring on Continue, also at `instant`)
- [x] Focus does not escape the screen while it is open (modal trap)
- [x] Esc key closes or cancels — by design it does **nothing** here (DD-X09) and never quits; stated so a tester does not log it

**Gamepad** (post-v1 — documented mapping only)
- [ ] All interactive elements reachable with D-Pad and left stick — §15 "Gamepad: banner"
- [ ] Face button mapping documented and consistent with platform conventions — `ui_accept` = Continue, `ui_cancel` = nothing — §15 "Gamepad: banner"
- [x] No action requires analog stick precision that cannot be replicated with D-Pad
- [ ] Trigger and bumper shortcuts documented if used — none on this screen — §15 "Gamepad: banner"
- [ ] Controller disconnection while screen is open is handled gracefully — the auto-advance still fires — §15 "Controller disconnection"

**Mouse**
- [x] Hover states defined for all interactive elements (Continue)
- [x] Clickable hit targets are at minimum 32x32px (Continue 160x44; an armed click anywhere also continues)
- [x] Right-click behavior defined (no-op)
- [x] Scroll wheel behavior defined in all scrollable zones (none)

**Touch (if applicable)** — not applicable.

---

## 12. Accessibility

Project-wide commitments are in `design/accessibility-requirements.md`. Ratios are art bible §4 figures.

**Text contrast requirements for this screen**:

| Text Element | Background Context | Required Ratio | Current Ratio | Pass? |
|--------------|-------------------|---------------|---------------|-------|
| Headline (28 px bold) | `table_dark` | 3:1 (large) | `text_light` 13.07 | [x] |
| Reason line (16 px) | `table_dark` | 4.5:1 | 13.07 | [x] |
| Facts / detail line (16 px) | `table_dark` | 4.5:1 | `text_muted` 7.03 | [x] |
| Continue label (16 px) | `table_dark` button | 4.5:1 | 13.07 | [x] |
| Banner border (non-text) | `table_dark` fill vs dimmed table | 3:1 not required (decorative; the headline carries the variant) | — | N/A |
| Saturated portrait initial (24 px bold) | Hero primary | 3:1 | `text_light` 6.17 / 6.19 / 6.72 (War / Decay / Knowledge) | [x] |

**Colorblind-unsafe elements and mitigations**:

| Element | Colorblind Risk | Mitigation |
|---------|----------------|------------|
| Victory vs defeat | Portrait saturation (hero colour) and border colour | The headline word is the outcome; colour is decoration (accessibility audit row "Victory vs defeat summary") |
| Fault vs defeat | Neutral border vs band border | Headline "Rules fault" and the line "This floor is replayed, not lost."; no stinger; no saturation — three non-colour cues |
| Both-dead vs defeat | Same headline | The reason line names the tie rule |

**Focus order**: 1. Continue (default, only stop). The base and the top bar are not stops in `Ended`.

**Screen reader announcements for key state changes**: Not committed (AccessKit live regions NOT SOURCEABLE). Accessible name for the banner: "<headline>. <reason line>. <facts line>." on Continue's description, so focusing Continue reads the whole outcome once AccessKit is sourced.

**Reading time** (accessibility-requirements Cognitive): the banner auto-advances after 4 s — acceptable because the next screen restates the outcome (run summary after a loss / the floor-8 win; the boss intro's "Attempt n" after a fault; the draft after a floor 1–7 win, where the outcome is self-evident). The countdown on Continue makes the timeout visible; `MATCH_END_AUTO_S` is a data knob (2–8 s). The arm guard (300 ms) stops a skip burst from consuming the banner unread; there is otherwise no reason to read faster than the player chooses, and Continue is one press.

**Motor**: one discrete press, or none (auto-advance); no hold; the whole screen is a click target once armed.

**Motion / flash**: one fade-in, one 400 ms colour ramp, one text change per second — within the ≤ 3 luminance changes per second rule; no shake.

**`text_scale` 150 %** (*spec*): headline 42 px, lines 24 px, button label 24 px; the content fits the 200 px banner for every variant except the fault (four text rows), for which the banner grows to 340, 240, 600, 220. Like the F6 rect itself (y 260 is inside the boss row, which ends at y 302), the grown banner covers part of the dimmed, inert boss row; it stays clear of both portraits (x 340–940 vs portraits at x ≤ 144 and ≥ 1136).

---

## 13. Localization Considerations

**General rules for this screen**:
- All text elements must tolerate a minimum of 40% expansion from English baseline
- RTL: centred text needs no mirroring; the facts line's segment order mirrors ("Boss h · You h · Turn n")
- CJK: shorter; the banner never shrinks
- All strings are keys: `end.<variant>.title`, `end.<variant>.line`, `end.facts`, `end.fault_detail`, `end.continue` (with `{seconds}`); names through Card Database keys

| Text Element | English Baseline Length | Max Characters | Expansion Budget | RTL Behavior | Overflow Behavior | Risk |
|--------------|------------------------|----------------|-----------------|--------------|-------------------|------|
| Headline ("Victory", "Rules fault") | 6–11 | 20 | 80 % | Centre | Shrink to 24 px bold; never wraps | Low |
| Reason lines (longest: `turn_cap`, 50) | 26–50 | 90 | 80 % | Centre | Wrap to 2 lines; the facts line moves down 20 px (fits: 318 + 40 + 8 + 20 = 386 < 400) | Medium |
| `{boss}` inside a line | ≤ 32 (content.md) | 32 | 0 % (name length is content's) | — | The line wraps | Medium |
| Facts line "Turn 9 · You 14 health · The Torchbearer 0" | ~44 | 70 | 60 % | Mirror segment order | Ellipsise the boss name first, never the numbers | Medium |
| Fault detail "Error: resolution_overflow · turn 7" | 36 | 50 | 40 % | Mirror | The reason code is not translated (it is a code) | Low |
| "Continue · 4" | 12 | 20 | 65 % | Mirror the countdown position | Button grows to ≤ 200 px | Low |

---

## 14. Acceptance Criteria

Fixtures are match-ui U11's `match_end_*` (real engine, scripted to the ending), launched per `.claude/docs/run-and-observe.md` with `--anim-speed=instant`, screenshots retained in `production/qa/evidence/`; *proposed* fixtures and poses are in §15.

**Performance**
- [ ] The banner's first frame appears on the frame the queue drains (≤ 16 ms after the last step) and is settled within 600 ms at `normal` (0 at `instant`)
- [ ] An armed `Enter` / click emits `match_view_finished` on the same frame (≤ 16 ms)

**Layout & Rendering**
- [ ] GIVEN `match_end_victory`, `match_end_defeat`, `match_end_both_dead` and `match_end_concede`, WHEN captured, THEN the banner occupies 340, 260, 600, 200 (±2 px) with the §6 headline, reason line and facts line of its variant, Continue at 560, 400 with the focus ring, and the winning portrait (player on victory) saturated to its primary (match-ui O13)
- [ ] GIVEN `match_end_fault`, WHEN captured, THEN the headline reads "Rules fault", the line "This floor is replayed, not lost.", the detail line "Error: resolution_overflow · turn n", the border is neutral, **neither** portrait is saturated, and the audio log shows no `sfx.ui.defeat` and no `sfx.ui.victory` (O13)
- [ ] GIVEN *proposed* `--pose=end:turn_cap` and `--pose=end:event_cap`, WHEN captured, THEN the `turn_cap` variant reads "Defeat" / "The match reached the turn limit — the boss wins." and the `event_cap` fault reads "Error: event_cap"
- [ ] GIVEN any variant, WHEN captured, THEN the table fill is `table_dark`, the final board tokens and both portraits are at full contrast, and the feed ticker is lit and readable
- [ ] GIVEN *proposed* `match_end_fault_ts150`, WHEN captured, THEN the banner is 340, 240, 600, 220 with no clipped text; GIVEN *proposed* `match_end_victory_ts150`, THEN the banner stays 340, 260, 600, 200 with no clipping

**Input**
- [ ] GIVEN `match_end_victory`, WHEN `Esc` is pressed and the top-bar menu button is clicked, THEN the view is still `Ended`, no pause menu opens, and the capture is pixel-identical to the un-pressed one (O19, DD-X09)
- [ ] GIVEN the banner just settled, WHEN `Space` is pressed 100 ms later, THEN nothing happens; WHEN pressed 300 ms or more after settling, THEN `match_view_finished(result)` is emitted once
- [ ] GIVEN a boss turn ending in the player's death and the player holding a stream of skip presses (`Space` every 100 ms from the boss turn through the banner), THEN the banner settles, stays up for at least 300 ms, and the next press after that continues — the banner is never skipped unrendered
- [ ] GIVEN no input, WHEN 4 s pass after settling, THEN `match_view_finished(result)` is emitted once and the Continue label read "· 4", "· 3", "· 2", "· 1" in the intervening seconds
- [ ] GIVEN a concede confirmed from the pause menu during `Mulligan` (fixture `mulligan` + concede), THEN the Mulligan overlay and the pause menu close and the `concede` variant plays

**Events & Data**
- [ ] GIVEN a `RunShell` test double, WHEN the match ends and the player double-clicks after arming (or clicks and the 4 s also elapse), THEN the double receives `match_view_finished(result)` exactly once, after `driver.match_ended` reached its `RunMachine` listener, and `MatchView` made no scene change itself (story MUI-011)
- [ ] GIVEN each of the six variants, THEN the variant is chosen only from `result` + `reason` (unit test over the C14 table), and an unknown `reason` renders a variant with a `??end.<reason>` detail line, never a blank banner
- [ ] The banner never displays floor, run or "next screen" information (grep: no `RunState` / floor reads in `banner_presenter.gd`)

**Accessibility**
- [ ] With colour removed (Coblis), every variant is identifiable by its headline and reason line alone
- [ ] Every text element in §12 measures at or above its ratio in-engine
- [ ] GIVEN `reduce_motion`, THEN the banner fades in without scale and the saturation ramp still plays once
- [ ] GIVEN `anim_speed = instant`, THEN the banner is settled on its first frame and the auto-advance is still 4 s

**Localization**
- [ ] Zero literal English strings in `banner_presenter.gd` (CI `tr()` grep); every `end.<variant>.*` key in §6 exists
- [ ] Pseudo-locale +40 % with the longest boss name: the reason line wraps to at most 2 lines and the facts line ellipsises the name, never a number

---

## 15. Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Player journey map not yet created — author `design/player-journey.md` from `.claude/docs/templates/player-journey.md`. | Jacob | Before Pre-Production gate | Open |
| **`turn_cap` has no banner copy**: match-rules C14 lists `turn_cap` as a boss-win reason, but match-ui U9 keys copy only for victory / defeat / both_dead / concede / fault and U11 has no `match_end_turn_cap` fixture. This spec adds the `turn_cap` variant and uses `--pose=end:turn_cap` (a 100-turn scripted fixture is impractical). | Match UI GDD owner | Before story MUI-011 readiness | Open — gap |
| **Continue arm guard**: U9 says the banner "waits for a click or `MATCH_END_AUTO_S`"; this spec swallows input for `end_turn_arm_ms` (300 ms) after the banner settles, and treats input during the 0.6 s entry as skip, so a skip burst from the boss turn cannot dismiss the banner unread. Reuse the existing knob or add `MATCH_END_ARM_MS`. | Match UI GDD owner | Before story MUI-011 readiness | Proposed here |
| **Boss portrait "saturation" on a boss win**: match-ui O13 ("the winning hero portrait (if any) is saturated to its primary") and `hud.md` §12 ("the boss's in the second") imply a boss saturation, but the art bible §4 rule b allows only the **hero** portrait to saturate, and band colours are already the boss panel's full fill. This spec shows the boss panel at its band fill, undimmed, with no ramp — which satisfies O13 literally without a new colour. | art-director (art bible §2/§4) + Match UI GDD owner (O13 wording) | `/ux-review match-end` | Proposed here |
| **Countdown on Continue** ("Continue · 4") is spec-owned — not in U9 or the Overlay pattern. | ux-designer (`interaction-patterns.md` Overlay row) | `/ux-review match-end` | Proposed here |
| **Facts line and fault detail line** (turn, both final health values; "Error: <reason> · turn n") are spec-owned additions; match-rules Visual/Audio asks for the fault "with the reason", which the detail line satisfies. Should a fault also offer "Copy report" (Error State "copyable where a report is useful")? This spec says no in v1 — the banner keeps one exit, and the log already holds the fault. | Jacob | `/ux-review match-end` | Proposed here — no copy button |
| **Auto-advance and the feed**: the drawer (`L`) is inert in `Ended` (match-ui States: no input but Continue); a player who wants to read *why* they lost has the ticker only. Proposal: allow the feed drawer in `Ended` and pause the 4 s timer while it is open. | Match UI GDD owner + Jacob | Pre-Production | Proposed — this spec follows the GDD until decided |
| **Hover / focus pausing the auto-advance**: toasts pause on hover; this banner does not (U9). Confirm that the countdown + the next screen restating the result is sufficient (accessibility-requirements Cognitive "Reading time" says yes). | Jacob (a11y owner) | `/ux-review match-end` | Proposed: no pause |
| **`MATCH_END_AUTO_S` and `anim_speed`**: this spec keeps the 4 s at every `anim_speed` (reading time, not animation); match-ui F3 divides "every base duration" — confirm the knob is outside that rule. | Match UI GDD owner | Before story MUI-011 | Proposed here |
| **Concede stinger**: match-ui Visual/Audio plays `sfx.ui.defeat` for every loss; a conceding player chose the outcome. Keep it (consistency) or use none (art bible §2 "never punishment")? | Jacob + audio | Alpha | Provisional: keep `sfx.ui.defeat` |
| New fixtures / poses: `--pose=end:turn_cap`, `--pose=end:event_cap`, `match_end_victory_ts150`, `match_end_fault_ts150`. | Match UI GDD owner / `/qa-plan` | Before story MUI-011 | Proposed |
| Story MUI-011 cites `hud.md` §5 / §12 because this file did not exist; once APPROVED it should cite `design/ux/match-end.md`. | producer | Sprint 5 readiness | Open |
| Gamepad: banner (§11) — `ui_accept` = Continue; nothing else. | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Controller disconnection (§11) — nothing changes; the auto-advance fires. | ux-designer | Before gamepad work (post-v1) | Open |
| AccessKit live regions — inherited NOT SOURCEABLE item. | ux-designer | Before first menu implementation | Open (inherited) |
