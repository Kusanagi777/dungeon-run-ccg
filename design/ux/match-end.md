# UX Spec: Match End (end banner and the `match_view_finished` hand-off)

> Authoring guidance: .claude/docs/templates/guidance/ux-spec-guide.md (load per-section as you author — do not read entirely).

> **Status**: Approved (`/ux-review` round 3, 2026-11-04)
> **Author**: Jacob + ux-designer (`/ux-design match-end` followed by hand — the skill is not model-invocable; automation `guided` under the owner's standing approval, workflow `standard`, density `balanced` from `rigor: standard`; no `AskUserQuestion` used — the recommended option was taken at every decision point and is listed in §15; no Agent tool — `art-director` / `ui-programmer` / `narrative-director` not spawned)
> **Last Updated**: 2026-11-04 (revision 1 after `/ux-review` round 1. Blocking: B1 the input lock and the overlay close now start when the queue reaches the `match_ended` step, not when `match_ended` is received, so pause stays reachable through a lethal boss turn; B2 a banner stack rule with positions at 100 / 125 / 150 % for every variant. Advisories: A1 b–d applied and a routed; A2 turn-0 facts line; A4 wireframe; A5 resolution criterion; A3 stays routed)
> **Journey Phase(s)**: The close of every match (game-concept Core Loop "One match (3–6 minutes)") and the hinge into the next run step — a draft (floors 1–7 won), the run summary (a loss, or floor 8 won) or the same boss again after a rules fault ("Attempt 2"). View state `Ended` (match-ui States); engine phase `Ended` (match-rules States). `design/player-journey.md` does not exist — see §15.
> **Screen / Flow Name**: `MatchEndBanner` — the end-banner variant of `banner.tscn` / `BannerPresenter` (ADR-0009: the one place `AnimationPlayer` clips are allowed), plus `MatchView`'s `Ended` state that emits `match_view_finished(result)` (ADR-0008 Decision 8, ADR-0011).
> **Platform Target**: PC (Windows primary, Linux dev/CI); 1280x720 logical, `canvas_items` + `keep` (DD-T05); mouse primary, keyboard complete; gamepad `Partial` post-v1; touch none (`project.yaml` has no `platform` block — values from `.claude/docs/technical-preferences.md` via `design/accessibility-requirements.md`).
> **Related GDDs**: `design/gdd/match-ui.md` U3 (`match_ended`, `log_overflow`, `resolution_overflow` rows), U4.5 (skip allowed during the end banner), U5 (`Esc` does nothing on the end banner; pause unreachable in `Ended`), U9 (Match end, the `fault` variant, `MATCH_END_AUTO_S` 4 s, `match_view_finished(result)`, "the Match UI never navigates"), U11 (`match_end_*` fixtures, `--pose=end:<reason>`), States (`Ended`), F3 (`end_banner` 0.6 s), F6 (end banner 340, 260, 600, 200), Edge Cases (fault, `match_ended` while dragging, `Esc` on the banner), Tuning Knobs (`MATCH_END_AUTO_S` 2–8), Visual/Audio ("Match end" row), UI Requirements ("Match end overlay" → this file), AC O13, O19; `design/gdd/match-rules.md` C14 (outcomes `hero_dead` / `both_dead` / `concede` / `turn_cap`, faults `resolution_overflow` / `event_cap`, `MatchResult` fields), States (`Ended`), Visual/Audio (`match_ended`: "both_dead and concede carry their own copy; a fault shows the rules-error screen with the reason, never a loss banner"); `design/gdd/run-ui.md` U2 `match` row, States S11 / S11b / S16, AC-29 (what follows the hand-off); `design/gdd/run-structure.md` (via run-ui: `match_faulted` → `pre_match` replay; DD-R07 a loss ends the run); `design/design-decisions.md` DD-M12 (both dead → boss wins), DD-R07, DD-R08, DD-X09.
> **Related ADRs**: ADR-0008 (Decision 8: `match_view_finished(result)` after the end banner; Run Structure has already processed `match_ended`); ADR-0009 (`BannerPresenter`); ADR-0011 (`RunShell` consumes `match_view_finished`).
> **Related UX Specs**: `design/ux/hud.md` (APPROVED — §5 `Ended` row, §8 "End banner" notification row, §10.1 victory saturation, §12 match-end rows); `design/ux/run-summary.md` (APPROVED — the summary that follows a loss or the floor-8 win; "Never: a `fault` match"); `design/ux/draft-picker.md` (APPROVED — the draft that follows a floor 1–7 win, entered after "watching the match-end banner for up to 4 s"); `boss-intro.md` (not yet written — "Attempt n" after a fault, run-ui S11b); `pause-menu.md` (not yet written — the concede that can end a match); `design/ux/interaction-patterns.md` (Overlay Open / Close "Match-end banner", Button (Primary), Escape / Cancel step (4a), Skip & Playback "When NOT to Use", Error State "a legal game outcome is never an error state", Animation / Sound Standards); `design/accessibility-requirements.md`.
> **Accessibility Tier**: Standard with reduce-motion, visual-for-every-sound and the high-contrast state set elevated (`design/accessibility-requirements.md`). The banner is one of the four auto-dismissing elements in Cognitive "Reading time" (4 s, acceptable because the next screen repeats the result).
> **Template**: UX Spec

> **Sources read** (by section, coordination rule 6): match-ui Summary, U1–U12, States, Interactions, F3, F6, Edge Cases, Dependencies, Tuning Knobs, Visual/Audio, Game Feel, UI Requirements, AC, Open Questions; match-rules C2, C14, C15, States, Visual/Audio, UI Requirements, Edge Cases (both dead, concede during the boss turn, overflow); run-ui (grep: `match_view_finished`, S10–S16, S11b, AC-29, `match` row, Interactions / Dependencies Match UI rows); design-decisions (all rows); art bible §1–4, §7; accessibility-requirements Commitment, Visual (flash rule), Colour audit ("Victory vs defeat summary"), Motor, Cognitive "Reading time" / "Pause anywhere"; interaction-patterns Catalog, Button (Primary), Overlay Open / Close, Escape / Cancel, Standard Shortcuts, Skip & Playback, Error State, Success Confirmation, Animation / Sound Standards; hud.md §1, §3–§5, §8, §10, §12; run-summary.md §2–§4; draft-picker.md §2–§4; story MUI-011, MUI-019; `production/session-state/active.md` (sibling conventions).

> **Note — Scope boundary**: This document owns the match's last state: from `match_ended` being received (projected on receipt, U3.1) to the single `match_view_finished(result)` emission — the play-out, the drain, the banner, its six variants, the portrait saturation, Continue and auto-advance. What the run shows next is Run UI's (run-ui S11 / S11b / S16 and its specs); the concede dialog that can end a match is `pause-menu.md`'s. Numbers marked **F6** / **F3** are match-ui's; numbers marked *spec* are this document's.

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
  └── … any view state … → match_ended received (play-out: view state unchanged, pause reachable)
        → queue reaches the match_ended step (overlays close, input locks to skip) → drained
        └── Ended: End banner (this spec) — modal, no cancel, no pause
              └── match_view_finished(result) → Run UI applies the buffered run-scope events (run-ui S11):
                    ├── draft_offered        → Draft Picker (floors 1–7 won)          draft-picker.md
                    ├── run_ended            → Run Summary victory / defeat            run-summary.md
                    └── run_floor_entered    → Boss Intro "Attempt n" (after a fault)  boss-intro.md (S11b)
```

**Modal behavior**: Modal with **no cancel and no pause** (DD-X09; Overlay Open / Close row "Match-end banner: Esc — Nothing"; Escape / Cancel step (4a)). The base is input-disabled from the moment **the queue reaches the `match_ended` step** (revision 1, review B1). Events are applied on receipt (U3.1), so `result` is set before the steps that led to it have played; during that play-out the view state's own rules apply, so pause, the feed and the Menu stay reachable (match-ui States: "any state except `Ended` → Menu"; accessibility-requirements Cognitive "Pause anywhere … including during boss playback"). Only an open targeting session is cancelled on receipt (match-ui Edge Cases "`match_ended` while dragging"). No command can be issued (match-rules: every command → `MATCH_ENDED`), and the UI never submits one after receipt (§6 Playing out). The only exits are Continue (press) and `MATCH_END_AUTO_S` (4 s). The player cannot be stuck: the auto-advance always fires.

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
| `match_ended` **received** (projected on receipt — `result` set) | Any view state | **Play-out** (§6): an open targeting session is cancelled at once; **nothing else changes**. The view state keeps its own input rules (e.g. `BossTurn`: skip, pause, feed), an open pause menu stays open, and the queue keeps playing the steps that led here (the boss's attacks, the lethal pop, the death group) at their normal pacing. Nothing on screen reveals the outcome before those steps show it | `MatchResult` (§8) | match-ui Edge Cases "`match_ended` while dragging" (the drag is cancelled first); U9 "finishes draining"; revision 1, review B1 |
| A confirmed **concede** (the player ends the match) | Pause → Concede → Confirm | The concede is the receipt and the step at once: the concede dialog, the pause menu and any Mulligan / Choice overlay close (`overlay_close` 0.15 s) immediately, then the banner | — | The player chose the outcome, so there is nothing to hide |
| The queue **reaches the `match_ended` step** (every earlier step played or skipped) | Play-out | **Ending** (§6): any open overlay (pause, settings, concede confirm, Choice) closes (`overlay_close` 0.15 s); input locks to skip only; the step itself has no animation | — | The point where the board already shows the outcome |
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
 334 │ ┌────────┐ ║                                                                 ║  border: hero  │
 346 │ │ player │ ║            Turn 9 · You 14 health · Boss 0     (16 px muted)    ║  primary 2 px  │
 400 │ │SATURATD│ ║                      ( Continue · 4 )   Primary 160x44 at 560,400 ║                │
 460 │ │        │ └═════════════════════════════════════════════════════════════════┘                │
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

**Banner stack rule** (*spec*, revision 1, review B2). It is the same for **every variant**: each has three text rows (headline, reason, facts or detail) plus Continue. The pre-revision note that only the fault had "four text rows" was wrong.

- **Fixed points.** The banner's **bottom edge stays at y 460** (F6) and **Continue stays at 560, 400** (16 px above the bottom).
- **Text rows** are top-anchored at banner top + 16: the headline line box `L_H`, a 10 px gap, the reason (`k` lines × `L_r`, k ≤ 2), an 8 px gap, the facts / detail line (`L_r`), then ≥ 14 px to Continue.
- **Line boxes**: headline 32 / 40 / 48 (28 / 35 / 42 px bold); lines 20 / 25 / 30 (16 / 20 / 24 px) at 100 / 125 / 150 %.
- **Banner height** = max(200, 108 + `L_H` + k·`L_r` + `L_r`). The banner **grows upward** from y 460 and stays 600 wide at x 340.

| `text_scale` / reason lines | Banner rect | Headline top | Reason top (bottom) | Facts / detail top (bottom) | Continue |
|---|---|---|---|---|---|
| 100 %, 1 line | **340, 260, 600, 200** (F6) | 276 | 318 (338) | 346 (366) | 560, 400 |
| 100 %, 2 lines | 340, 260, 600, 200 | 276 | 318 (358) | 366 (386) | 560, 400 |
| 125 %, 1 line | 340, 260, 600, 200 | 276 | 326 (351) | 359 (384) | 560, 400 |
| 125 %, 2 lines | 340, 237, 600, 223 | 253 | 303 (353) | 361 (386) | 560, 400 |
| 150 %, 1 line | 340, 244, 600, 216 | 260 | 318 (348) | 356 (386) | 560, 400 |
| 150 %, 2 lines | 340, 214, 600, 246 | 230 | 288 (348) | 356 (386) | 560, 400 |

- **When the reason wraps.** At an average glyph width of 0.5 em (estimate), 568 px holds ~71 / 57 / 47 characters per line at 16 / 20 / 24 px. The English `turn_cap` reason (50 chars) is 1 line at 100 / 125 % and 2 at 150 %. "You conceded to {boss}." with a 32-character boss name (48) is 1 / 1 / 2. Under the +40 % pseudo-locale (≤ 70) every reason fits 2 lines at every scale.
- **More than 2 lines** → the reason drops to 14 × scale px, still inside 2 line boxes.
- **No facts line** (`turns == 0`, review A2 — a concede during the Mulligan): its row is omitted; the text rows keep their tops and Continue keeps its place.
- **What the banner covers.** The tallest banner (150 %, 2 lines) reaches y 214. Like the F6 rect itself (y 260 is inside the boss row, which ends at y 302), it covers more of the dimmed, inert boss row. It stays clear of both portraits (x 340–940 vs x ≤ 144 and ≥ 1136) and of the ticker (y ≤ 90).

### 5.2 Layout Zones

| Zone Name | Description | Approximate Size | Scrollable? | Overflow Behavior |
|-----------|-------------|-----------------|-------------|-------------------|
| Dimmed table | The table fill steps `table_lit` → `table_dark`; tokens, hand, piles keep their contrast; **both portraits stay undimmed** so the saturation (and the boss's band fill) read; the feed ticker and the top bar stay lit (art bible §2: the event log is lit in every state) | 1280 x 720 | No | — |
| End banner (F6) | 340, 260, 600, 200 — `table_dark`, 4 px radius (art bible §3), 2 px variant border | 600 x 200 (min) | No | Grows **upward** from its fixed bottom y 460 by the §5.1 banner stack rule, for every variant, when `text_scale` or a 2-line reason needs it (up to 340, 214, 600, 246 at 150 % with 2 lines) |
| Headline | 28 px bold × `text_scale` `text_light`, centred, one line | 568 x 32 / 40 / 48 | No | ≤ 20 chars English; shrinks to 24 × scale px, never wraps |
| Reason line | 16 px × `text_scale` `text_light`, centred, ≤ 2 lines | 568 x 1–2 line boxes (20 / 25 / 30 each) | No | Wraps to a second line; the facts line moves down by one line box (§5.1 table); a third line drops the font to 14 × scale px |
| Facts / detail line | 16 px × `text_scale` `text_muted`, centred | 568 x 20 / 25 / 30 | No | Ellipsises the hero / boss names first, never the numbers; omitted when `turns == 0` (a concede during the Mulligan, review A2) |
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
| Playing out | `match_ended` **received**; the queue has not yet reached its `match_ended` step | **Nothing new.** The remaining steps (a boss turn's attacks, the lethal pop, the death group) play at their normal pacing; an open targeting session is cancelled at once; an open pause menu **stays open** | **Unchanged** from the current view state (`Playback` / `BossTurn`): skip, pause (`Esc` / menu button), feed drawer and Menu all work. The UI submits nothing: a Concede confirmed in this state sends **no** `concede` (the engine would reject `MATCH_ENDED`, and the rejection would reveal the outcome). It is treated as "end now": the pause menu closes and the queue is flushed (skip-all) to the `match_ended` step, so the banner shows the real result | Revision 1, review B1. match-ui States "any state except `Ended` → Menu"; `hud.md` Menu row "underlying playback keeps running"; accessibility-requirements "Pause anywhere … including during boss playback" (Basic). The GDD edge-case line "Input is locked from the moment `result` is set" was written about dragging; §15 routes its wording |
| Ending | The queue **reaches the `match_ended` step** (all earlier steps played or skipped) | Any open overlay (pause, settings, concede confirm, Choice) closes, `overlay_close` 0.15 s | Input locked to skip only; the view enters `Ended` when the step completes | The board now shows the outcome, so closing the menu gives nothing away |
| Entering | Queue drained → `Ended` | `end_banner` 0.6 s; saturation ramp 0.4 s; stinger | Any input completes the entry instantly (U4.5 skip) and is **not** a Continue | Prevents a skip press from the boss turn dismissing the banner unread |
| Settled, not armed | Entry complete | Banner static; Continue draws **Disabled** (Button pattern: `text_muted` label, no outline, no hover lift) with the focus ring, label "Continue · 4" (revision 1, review A1 c — a swallowed click now has visible feedback) | Input ignored for `end_turn_arm_ms` (300 ms) after settling (*spec*, §15) | The same accidental-activation guard End Turn uses |
| Armed | 300 ms after settling | Continue switches to Actionable (`text_light`, 2 px `state_actionable` outline): one state change, no motion | A **fresh** LMB press anywhere, or an `Enter` / `Space` press with `is_echo() == false` → Continue. Key-repeat echoes are never a Continue, so a key held since the boss turn cannot reach the banner (review A1 d) | U9 "waits for a click"; hud.md §8 "Click / Enter advances early" |
| Counting down | From settling | Label "Continue · 4" → "· 3" → "· 2" → "· 1", once per second | — | No motion; a text change per second is within the flash rule |
| Continued / auto-advanced | Armed input, or `MATCH_END_AUTO_S` elapsed | Continue pressed state; banner holds until Run UI's fade covers it | `match_view_finished(result)` emitted once; every later input ignored | The Match UI does not fade itself out |
| `Esc` / menu button pressed | Any time in `Ended` | **Nothing** | Nothing — no pause menu, no cancel (DD-X09) | O19 |
| Concede from the Mulligan / Choice | `concede` in `Mulligan` / `ChoiceOpen` | The overlay and the pause menu close (0.15 s) at once, before the banner (the concede is its own `match_ended` step); at `turns == 0` the facts line is omitted | As above | match-rules C14 |
| `text_scale` 125 % / 150 % | Setting | Headline 35 / 42 px, lines 20 / 24 px, button label scaled; positions from the §5.1 banner stack rule. The banner grows upward from y 460 for **any** variant that needs it (150 %: 340, 244, 600, 216 with a 1-line reason; 340, 214, 600, 246 with 2 lines) | — | Fixtures *proposed* `match_end_victory_ts150`, `match_end_fault_ts150`, `match_end_concede_ts150` (32-character boss name) |
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
| Inputs of the current view state | all | Playing out | As that view state (skip, pause, feed, Menu) | As usual | — | — | Revision 1, review B1. A confirmed Concede here flushes to the end instead of submitting (§6) |
| Any input | all | Ending / Entering | Skip to the settled banner | Steps and entry complete in one frame | 0 | Skipped steps' SFX dropped; the stinger plays once on the settled frame if it had not yet | U4.5 |
| LMB (anywhere) / `Enter` / `Space` (not an echo) | PC / KB | Armed (≥ 300 ms after settling) | Continue | Continue pressed; `match_view_finished(result)` | 60 ms press | `ui_select` | Exactly once |
| LMB / `Enter` / `Space` | PC / KB | Settled, not armed | Nothing (swallowed); Continue is visibly Disabled | — | — | — | The arm guard |
| `Enter` / `Space` echo (`is_echo()`) | KB | Any `Ended` state | Nothing | — | — | — | A held key never continues |
| No input | — | Settled | Auto-advance after 4 s | As Continue | — | `ui_select` | `MATCH_END_AUTO_S` |
| Top-bar menu button | PC | Any `Ended` state | Nothing | — | — | — | U9 / DD-X09 — the button draws as Disabled (`text_muted`, no hover lift) so it does not invite a click |

### 7.3 State-Specific Behaviors

| State | Input Restriction | Reason |
|-------|------------------|--------|
| Playing out | The current view state's own rules (no extra lock); pause, feed and Menu reachable; no command submitted | Pause anywhere; the outcome is not revealed before its steps play (review B1) |
| Ending / Entering | Skip only | The board that ended the match is shown, never jumped over without the player's input |
| Settled, not armed | Everything swallowed | A skip burst from the boss turn cannot dismiss the banner (*spec*) |
| Armed | Continue only | One exit (DD-X09) |
| After Continue | Everything ignored | `match_view_finished` exactly once (story MUI-011) |

---

## 8. Data Requirements

| Data Element | Source System | Update Frequency | Who Owns It | Format | Null / Missing Handling |
|--------------|--------------|-----------------|-------------|--------|------------------------|
| `result`, `winner`, `reason` | Match Rules `match_ended` → `MatchViewState.result` (U3) | Once | Match Rules (C14) | `result: win \| loss \| fault`; `winner: PLAYER \| BOSS \| null`; `reason: hero_dead \| both_dead \| concede \| turn_cap \| resolution_overflow \| event_cap` | An unknown `reason` → the `defeat` variant for `loss`, `fault` for `fault`, with `??end.<reason>` in the detail line + debug warning (never a blank banner) |
| `turns` (global), final hero health both sides | `MatchResult` (C14 "turns (global) … final hero health both sides") | Once | Match Rules | ints | Missing, or `turns == 0` (a concede during the Mulligan — "Turn 0 · You 30 health" would be noise), → the facts line is omitted (headline and reason stand alone) |
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
| Overlays close at the end | The queue reaches the `match_ended` step while pause / settings / concede confirm / Choice is open, or a concede is confirmed (immediate) | `overlay_close` | 150 | ease-out | Yes (skip) | Fade (already) |
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

**Reading time** (accessibility-requirements Cognitive): the banner auto-advances after 4 s — acceptable because the next screen restates the outcome (run summary after a loss / the floor-8 win; the boss intro's "Attempt n" after a fault; the draft after a floor 1–7 win, where the outcome is self-evident). The countdown on Continue makes the timeout visible; `MATCH_END_AUTO_S` is a data knob (2–8 s). The arm guard (300 ms) guarantees only that the banner is **rendered** and visibly settled before a press can leave it: it stops a skip burst from consuming the banner before it is drawn. It does **not** guarantee that the banner is **read**. That is acceptable only because the next screen restates the result, as above (revision 1, review A1 b). Continue draws Disabled during the guard, so a swallowed press is visibly explained. There is otherwise no reason to read faster than the player chooses, and Continue is one press.

**Pause during the ending** (revision 1, review B1): the pause menu stays reachable until the queue reaches the `match_ended` step, so "Pause anywhere … including during boss playback" holds through a lethal boss turn (up to `max_turn_playback_s`). The banner and `Ended`'s "no pause" (DD-X09) begin only once the board has shown the outcome.

**Motor**: one discrete press, or none (auto-advance); no hold; the whole screen is a click target once armed.

**Motion / flash**: one fade-in, one 400 ms colour ramp, one text change per second — within the ≤ 3 luminance changes per second rule; no shake.

**`text_scale` 125 / 150 %** (*spec*, revision 1, review B2): headline 35 / 42 px, lines 20 / 24 px, button label 20 / 24 px. Every variant has the same three text rows, and every position comes from the §5.1 banner stack rule: the bottom stays at y 460 and Continue at 560, 400, while the banner grows upward when needed. At 150 % that is 340, 244, 600, 216 for a 1-line reason and 340, 214, 600, 246 for 2 lines. At 125 % the banner stays at F6 unless the reason wraps (then 340, 237, 600, 223). The pre-revision rule (only the fault grows, to 220) is withdrawn: its "four text rows" premise was wrong, and it left the headline's 50 px line box overlapping the reason line. Like the F6 rect itself, a grown banner covers more of the dimmed, inert boss row, and it stays clear of both portraits and the ticker.

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
| Reason lines (longest: `turn_cap`, 50) | 26–50 | 90 | 80 % | Centre | Wrap to 2 lines (§5.1 stack rule: ~71 / 57 / 47 chars per line at 100 / 125 / 150 %, so the 90-char maximum needs 2 lines at every scale and still fits 2 at 150 %, 94 ≥ 90); the facts line moves down one line box and the banner grows upward if needed; a third line → 14 × scale px | Medium |
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
- [ ] GIVEN *proposed* `match_end_victory_ts150` and `match_end_fault_ts150` (1-line reasons), WHEN captured, THEN each banner is **340, 244, 600, 216** (±2 px) with the headline top at 260, the reason at 318, the facts / detail line at 356 and Continue at 560, 400, and no two text boxes overlap and nothing clips (review B2)
- [ ] GIVEN *proposed* `match_end_concede_ts150` (a 32-character boss name, so the reason wraps to 2 lines), WHEN captured, THEN the banner is **340, 214, 600, 246** with the headline at 230, the reason at 288–348, the facts line at 356 and Continue at 560, 400, with no overlap or clipping; at 125 % the same fixture gives 340, 237, 600, 223 if the reason wraps, else the F6 rect
- [ ] GIVEN any variant at `text_scale` 125 %, WHEN captured, THEN the positions match the §5.1 125 % rows (±2 px)
- [ ] GIVEN a concede during the Mulligan (`turns == 0`), WHEN the banner settles, THEN no facts line is drawn and the headline, reason and Continue keep their positions (review A2)
- [ ] GIVEN any fixture above at 1280x720 windowed and 3840x2160 fullscreen, THEN the banner is the 1280x720 layout scaled uniformly (review A5)

**Input**
- [ ] GIVEN `match_end_victory`, WHEN `Esc` is pressed and the top-bar menu button is clicked, THEN the view is still `Ended`, no pause menu opens, and the capture is pixel-identical to the un-pressed one (O19, DD-X09)
- [ ] **Pause through a lethal boss turn** (review B1) — GIVEN *proposed* `match_end_defeat --pause-at=<seq of the first boss attack>` (a boss turn whose attacks kill the player, so `match_ended` is already received), WHEN `Esc` is pressed, THEN the pause menu opens, no banner and no saturation are drawn, the player's health still shows its pre-lethal value, and the capture shows no outcome cue. WHEN Resume is chosen, THEN the remaining steps play and the banner follows the drain
- [ ] GIVEN the pause menu open during that play-out with no further input (playback continues under it, `hud.md` Menu row), WHEN the queue reaches the `match_ended` step, THEN the pause menu closes (0.15 s) and the `defeat` banner enters; no frame before that step shows the banner or closes the menu
- [ ] GIVEN the same play-out, WHEN Concede is confirmed from the pause menu, THEN **no** `concede` command is submitted, no rejection tooltip or feed line appears, the queue flushes, and the banner shows the real variant (`defeat`)
- [ ] GIVEN a lethal boss turn whose `match_ended` has been received but whose attack steps are still queued, WHEN the ticker and the feed drawer are read at any point before the lethal step plays, THEN neither shows a line for an unplayed step (no lethal damage line, no death line, no `match_ended` line); each line appears as its step plays, and skip-all appends the remaining lines in order (round 2, review B1)
- [ ] GIVEN `match_ended` received while the player drags a card (fixture with a scripted race), THEN the drag is cancelled on receipt and nothing else changes until the `match_ended` step (match-ui Edge Cases)
- [ ] GIVEN the banner just settled, WHEN `Space` is pressed 100 ms later, THEN nothing happens and Continue is drawn Disabled (`text_muted`, no outline); WHEN pressed 300 ms or more after settling, THEN `match_view_finished(result)` is emitted once and Continue was Actionable from 300 ms
- [ ] GIVEN `Space` held down from the boss turn through the banner (key-repeat echoes only after the first press), THEN no echo continues the banner; a fresh press after arming does (review A1 d)
- [ ] GIVEN a boss turn ending in the player's death and the player holding a stream of skip presses (`Space` every 100 ms from the boss turn through the banner), THEN the banner settles, stays up for at least 300 ms, and the next press after that continues — the banner is never skipped unrendered
- [ ] GIVEN no input, WHEN 4 s pass after settling, THEN `match_view_finished(result)` is emitted once and the Continue label read "· 4", "· 3", "· 2", "· 1" in the intervening seconds
- [ ] GIVEN a concede confirmed from the pause menu during `Mulligan` (fixture `mulligan` + concede), THEN the Mulligan overlay and the pause menu close at once and the `concede` variant plays with no facts line

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
| **`turn_cap` has no banner copy**: match-rules C14 lists `turn_cap` as a boss-win reason, but match-ui U9 keys copy only for victory / defeat / both_dead / concede / fault and U11 has no `match_end_turn_cap` fixture. This spec adds the `turn_cap` variant and uses `--pose=end:turn_cap` (a 100-turn scripted fixture is impractical). | Match UI GDD owner | Before MUI-011 implementation (the story is already Ready) | Open — gap |
| **Input lock and overlay close timing** (revision 1, review B1): this spec now locks input and closes overlays when the queue **reaches the `match_ended` step**, not on receipt. Until then the view state's own rules apply (pause, feed, Menu reachable), and only a targeting session is cancelled on receipt. Reword the match-ui Edge Cases line "Input is locked from the moment `result` is set" to "a drag is cancelled when `match_ended` is received; input locks when the queue reaches the `match_ended` step". match-ui States already agrees ("any state except `Ended` → Menu"). | Match UI GDD owner | Before MUI-011 implementation | **Decided in this spec**; match-ui.md not edited |
| **Concede while playing out** (§6): a Concede confirmed after `match_ended` was received but before its step sends no command and flushes to the banner. Alternatively, disable Concede in the pause menu once `result` is set — but that disabled state would itself reveal the outcome. Confirm with the `pause-menu.md` author. | ux-designer (`pause-menu.md`, not yet written) | When `pause-menu.md` is authored | Proposed here |
| **Pause menu at the `match_ended` step**: the menu closes under the player when playback reaches the step (review fix as recommended). An alternative is to **hold** the step until the menu is closed, which never yanks a menu the player opened. | Jacob + Match UI GDD owner | `/ux-review match-end` round 2 | Proposed: close (designer default); hold is the fallback |
| **Feed timing** (round 2, review B1): **requirement of this spec** — a feed line (ticker and drawer) is appended when the animation queue **plays its step**, not when the event is received; lines for steps still queued are not shown. Otherwise the ticker reveals the lethal lines before the boss turn plays them. This changes match-ui U3.1 ("applied on receipt") for the feed only — the view state is still projected on receipt — and needs U10's feed source, story MUI-014 and the `hud.md` ticker row to read lines from the queue's played steps. Skip-all flushes the queued lines in order. | Match UI GDD owner; producer (MUI-014); `hud.md` owner | Before MUI-011 / MUI-014 implementation | **Decided in this spec** (2026-11-04); match-ui.md, hud.md and MUI-014 not edited |
| **Continue arm guard**: U9 says the banner "waits for a click or `MATCH_END_AUTO_S`"; this spec swallows input for `end_turn_arm_ms` (300 ms) after the banner settles, and treats input during the 0.6 s entry as skip, so a skip burst from the boss turn cannot dismiss the banner unread. Revision 1 makes Continue draw Disabled during the guard (A1 c), ignores key echoes (A1 d), and states that the guard ensures rendering, not reading (A1 b). **Still open (A1 a)**: reusing `end_turn_arm_ms` couples End Turn's 150–600 ms safe range and rationale to the banner. A separate `MATCH_END_ARM_MS` (default 300, same range) is preferred, but it is a GDD Tuning Knobs entry. | Match UI GDD owner (Tuning Knobs) | Before MUI-011 implementation | Proposed here — recommend `MATCH_END_ARM_MS` |
| **Boss portrait "saturation" on a boss win**: match-ui O13 ("the winning hero portrait (if any) is saturated to its primary") and `hud.md` §12 ("the boss's in the second") imply a boss saturation, but the art bible §4 rule b allows only the **hero** portrait to saturate, and band colours are already the boss panel's full fill. This spec shows the boss panel at its band fill, undimmed, with no ramp — which satisfies O13 literally without a new colour. | art-director (art bible §2/§4) + Match UI GDD owner (O13 wording) | `/ux-review match-end` | Proposed here |
| **Countdown on Continue** ("Continue · 4") is spec-owned — not in U9 or the Overlay pattern. | ux-designer (`interaction-patterns.md` Overlay row) | `/ux-review match-end` | Proposed here |
| **Facts line and fault detail line** (turn, both final health values; "Error: <reason> · turn n") are spec-owned additions; match-rules Visual/Audio asks for the fault "with the reason", which the detail line satisfies. Should a fault also offer "Copy report" (Error State "copyable where a report is useful")? This spec says no in v1 — the banner keeps one exit, and the log already holds the fault. | Jacob | `/ux-review match-end` | Proposed here — no copy button |
| **Auto-advance and the feed**: the drawer (`L`) is inert in `Ended` (match-ui States: no input but Continue); a player who wants to read *why* they lost has the ticker only. Proposal: allow the feed drawer in `Ended` and pause the 4 s timer while it is open. | Match UI GDD owner + Jacob | Pre-Production | Proposed — this spec follows the GDD until decided |
| **Hover / focus pausing the auto-advance**: toasts pause on hover; this banner does not (U9). Confirm that the countdown + the next screen restating the result is sufficient (accessibility-requirements Cognitive "Reading time" says yes). | Jacob (a11y owner) | `/ux-review match-end` | Proposed: no pause |
| **`MATCH_END_AUTO_S` and `anim_speed`**: this spec keeps the 4 s at every `anim_speed` (reading time, not animation); match-ui F3 divides "every base duration" — confirm the knob is outside that rule. | Match UI GDD owner | Before MUI-011 implementation | Proposed here |
| **Concede stinger**: match-ui Visual/Audio plays `sfx.ui.defeat` for every loss; a conceding player chose the outcome. Keep it (consistency) or use none (art bible §2 "never punishment")? | Jacob + audio | Alpha | Provisional: keep `sfx.ui.defeat` |
| New fixtures / poses: `--pose=end:turn_cap`, `--pose=end:event_cap`, `match_end_victory_ts150`, `match_end_fault_ts150`, `match_end_concede_ts150` (32-character boss name), and `match_end_defeat` with `--pause-at=<seq>` inside the lethal boss turn (revision 1). | Match UI GDD owner / `/qa-plan` | Before MUI-011 implementation | Proposed |
| Story MUI-011 cites `hud.md` §5 / §12 because this file did not exist; once APPROVED it should cite `design/ux/match-end.md`. Its AC does not contradict revision 1 (review). | producer | Before `/dev-story` on MUI-011 (already Ready) | Open |
| Gamepad: banner (§11) — `ui_accept` = Continue; nothing else. | ux-designer | Before gamepad work (post-v1) | Open — post-v1 |
| Controller disconnection (§11) — nothing changes; the auto-advance fires. | ux-designer | Before gamepad work (post-v1) | Open |
| AccessKit live regions — inherited NOT SOURCEABLE item. | ux-designer | Before first menu implementation | Open (inherited) |
