# UX Review: Sprint 4, round 3 (match-end)

**Date**: 2026-11-04
**Reviewer**: ux-review skill, followed by hand. The skill cannot be model-invoked, so `.claude/skills/ux-review/SKILL.md` was read and applied phase by phase. The owner's standing approval covers the run, so no questions were asked.
**Mode**: read-only. No spec, story, code or other repo file was edited, and nothing was committed.
**Scope**: `design/ux/match-end.md` at HEAD (29146bf). That commit changes this spec in two places: a new §14 Input AC (line 431) and a rewritten §15 "Feed timing" row (line 465). Nothing else in the spec changed after round 2.

## Method and inputs (Phase 2)

| Input | Resolution |
|---|---|
| Workflow | `resolve_config --keys workflow` gives `standard (rigor:standard)` |
| Platform / input methods | Same as rounds 1 and 2. `project.yaml` has no `platform` block, so the values come from the `technical-preferences.md` fallback: keyboard/mouse primary, gamepad Partial (post-v1), no touch, PC, 1280x720 |
| Accessibility tier | `design/accessibility-requirements.md`: Standard, committed, plus three elevations. The round-2 reading of "Pause anywhere" carries over |
| Pattern library | `interaction-patterns.md`, Event Feed (lines 857–879) and the "Event feed at match start" row (line 1137), both found by grep |
| GDD | match-ui U3 (rule 1 and the event → step table, lines 120–205), U4 (206–236) and U10 (373–384), read by offset/limit |
| Sibling | `hud.md` (Status: Approved, round 3), found by grep: §4.1 ticker row (201), §2.1 I23 (73), §5 `Menu` and `Dragging` rows (374, 378), §4.2 behaviour delegation (361), §10.4 caption claim (548) |
| Stories | MUI-014 (Status: Ready; ADR summary at line 18). MUI-011 (Ready). MUI-001 and MUI-002 are both **Complete** |
| Code (to check the routing) | `src/ui/match/match_view_state.gd` (`_feed`, the `match_ended` branch) and `src/ui/match/animation_queue.gd` (signals, `skip_all`). No feed presenter exists yet |
| Player journey | `design/player-journey.md` is still absent. Context on arrival is checked against §2, as before |

**Checklist**: 3A, from the file's `> **Template**: UX Spec` line.
**Dimensions not assessed**: none.

## UX Review: Match End
**Date**: 2026-11-04
**Reviewer**: ux-review skill
**Document**: `design/ux/match-end.md`
**Checklist**: 3A (Template line)
**Platform Target**: PC, mouse primary / keyboard complete / gamepad Partial post-v1 / no touch
**Accessibility Tier**: Standard (+3 elevations), committed

### Round-2 resolution
| Round 2 | Status | Evidence |
|---|---|---|
| **B1: feed lines appended on receipt reveal the outcome** | **Resolved** | §15 "Feed timing" is now a stated **requirement of this spec**: a line (in both the ticker and the drawer) is appended when the queue plays its step, and lines for queued steps are not shown. The view state is still projected on receipt, and only the feed's release changes. The change is routed to U3.1 / U10, MUI-014 and the `hud.md` ticker row, with the deadline "before MUI-011 / MUI-014 implementation". New AC 431 asserts no line for an unplayed step and in-order lines on skip-all. **Every line that carries the outcome has a step.** Lethal `damage_dealt` (dealt > 0) has a `DAMAGE_POP`, `minion_died` has a death group, `fatigue_damage` has a label step, and `match_ended` has a step (`END_BANNER` in code, line 520). There is no separate hero-death event: `hero_dead` is only a `reason` value. So the §4 claim "Nothing on screen reveals the outcome before those steps show it" and AC 428's "no outcome cue" can now be passed. Gaps around the edges of the rule are advisory (A1–A4 below) |
| A1: menu closing at the step (settings persisted, focus handed to Continue) | Open, carried | §6 Ending is unchanged |
| A2: a concede during the play-out can show Victory | Open, carried | §6 and §15 are unchanged. MUI-019 is not yet routed |
| A3: 1.15 line-box mechanism | Open, carried | Shared with mulligan A1 |
| A4: separate `MATCH_END_ARM_MS` | Routed, unchanged | §15 |
| A5: feed drawer inert in `Ended` | Routed, unchanged | §15 |

### Consistency of the change with the rest of the spec
- **§6 states table.** Consistent. In Playing out, "skip, pause, feed drawer and Menu all work" still holds, and the drawer shows only lines for played steps, as AC 431 requires. The Concede flush is skip-all (U4.5), so it appends the remaining lines in order. That matches AC 431, but its wording clashes with AC 430 (A3).
- **§4 Entry & Exit.** Consistent. Row 2's "nothing on screen reveals the outcome" is now backed by §15. Neither §4 nor §6 cites the requirement, though (A4). In Ending, the menu closes at the `match_ended` step, by which point the lethal steps, and therefore their lines, have already played. Nothing leads the board.
- **Accessibility, "Pause anywhere".** Consistent. The pause menu does not stop playback (`hud.md` Menu row: "underlying playback keeps running … the ticker keeps updating"). Lines therefore keep arriving under the menu, step by step, in lockstep with the board. The ticker (24, 48, 400, 42) sits outside the menu rect (440–840) and can still be read, which is the intent. Step gating also helps the visual-for-every-sound elevation: `hud.md` §10.4 makes the feed line the caption for every SFX, and that caption now arrives with its SFX instead of ahead of it.
- **Skip-all.** Consistent with U4.5 and with the Complete queue code. `skip_all()` runs each remaining `apply_final` in order and emits `step_finished` once per step, so "skip-all appends the remaining lines in order" can be implemented directly.
- **U4.6 invariant.** Unaffected. When the queue is idle, every line has been released, so the feed presenter equals `feed_lines[]` and `_assert_in_sync` still holds.

### `hud.md` (Approved): contradiction and routing
- **There is a contradiction.** The §4.1 ticker row (line 201) gives the data source as `feed_lines[]` and the update frequency as "Every event". Read with U3.1 ("applied immediately … on receipt"), that means a line appears on receipt, which match-end now forbids. The Event Feed pattern's implementation note says the same ("`EventFeed` renders `MatchViewState.feed_lines[]`", line 876). So does MUI-014's ADR summary ("Feed lines are view-state (`feed_lines[]` recorded by the projection)"). `hud.md`'s other feed rules agree with match-end: I23 ("every event as a localised line" is about content, not timing), Menu and Dragging ("ticker keeps updating") and §10.4.
- **It does not block approval, and it is correctly routed.**
  1. `hud.md` does not own feed behaviour. §4.2 (line 361) hands it to the Event Feed pattern and the `event-feed.md` spec, so its row is a summary.
  2. The match-end §15 row names the owners (Match UI GDD owner, the producer for MUI-014, the `hud.md` owner) and a deadline that has not passed: MUI-014 and MUI-011 are both Ready and not started, and there is no feed presenter in `src/ui/match/`.
  3. Round 2 accepted the same pattern for the input-lock row, where a decision taken in the spec is routed to the GDD with a deadline.
- **The routing is incomplete** (A2). It does not name the Event Feed pattern or the future `event-feed.md` spec. It also does not say that the projection's line record (MUI-001, Complete) has no `seq` field.
- **Residual risk.** Until those documents are amended, a `/dev-story` on MUI-014 that follows the GDD, the pattern and `hud.md` would build the receipt-time feed and fail AC 431. The producer should amend MUI-014's AC before the story is picked up.

### Completeness: 15/15 sections present

### Quality Issues: 0 blocking, 9 advisory
1. **A1: The release rule is silent on step-less lines and on the release point** [ADVISORY, high priority]
   - What's wrong: the rule ties each line to "its step". Several U3 events produce a feed line but no step:
     - `match_started`, `crystal_gained` / `mana_*`, `counter_changed`, `effect_resolved` (the group line, with a step only if it fizzled), `healed{amount: 0}`, `damage_dealt` with dealt 0 and prevented > 0, `log_overflow` / `resolution_overflow`, and every unknown type (`feed.unknown`, rule 4).
     - The pattern's "Event feed at match start" row (line 1137) promises the `match_started` line, which has no step.

     For these lines the spec gives neither a time nor an order, and the round-2 fix (a) named the case ("zero-step events with the next step in `seq` order"). "Plays its step" is also ambiguous between the start and the end of the step. The Complete queue emits no `step_started` at `instant` (animation_queue.gd header), so a presenter that keys on `step_started` would never show lines at `instant`. None of the step-less lines carries the outcome, so B1 stays closed.
   - Where: §15 "Feed timing"; §14 AC 431.
   - Fix: state the rule as a `seq` cursor. A line is released when a step with a `seq` at or after its own finishes (`step_finished`, which is emitted on play, on skip and at `instant` alike). Every pending line is released when the queue drains or is idle. That gives step-less lines in `seq` order with the next step, and it gives "on receipt" whenever nothing is queued.
2. **A2: The routing omits the pattern, `event-feed.md` and the Complete projection** [ADVISORY: route]
   - What's wrong:
     - §15 does not route the change to the Event Feed pattern (interaction-patterns.md line 876), which round 2's fix (a) listed, or to `event-feed.md`, which `hud.md` names as the feed's own spec and which is not yet written.
     - In code, `_feed()` records `{key, params, group_id}` with no `seq`, so step gating needs a small change to Complete story MUI-001's file. Gating by `group_id` alone would release a whole command group at once.
   - Where: §15 "Feed timing".
   - Fix: add the pattern owner (ux-designer) and the `event-feed.md` author to the owners. Note for the producer that MUI-014 must add `seq` to the feed record (`match_view_state.gd`, `_feed`) or carry the lines on their steps.
3. **A3: AC 430 contradicts AC 431, and AC 431 has no observable fixture** [ADVISORY]
   - What's wrong:
     - AC 430 (Concede during the play-out) says "no rejection tooltip or **feed line** appears", yet the flush is skip-all, and AC 431 requires skip-all to append the remaining lines (lethal damage, deaths, `match_ended`). Read literally, a correct implementation fails AC 430.
     - AC 431 names no fixture. §14 runs fixtures at `--anim-speed=instant`, where the whole play-out completes in one frame, so "at any point before the lethal step plays" cannot be observed.
   - Fix:
     - In AC 430, write "no `feed.command_rejected` line".
     - Give AC 431 *proposed* `match_end_defeat --pause-at=<seq>` at `normal`, or a headless unit test: after step k finishes, the presented lines are exactly those with `seq` ≤ k, and after `skip_all()` they equal `feed_lines[]` in order.
4. **A4: The requirement lives only in §15 and §14** [ADVISORY]
   - What's wrong: §6 Playing out, §4 row 2 and §7.3 claim that nothing reveals the outcome, but do not cite the feed rule that makes it true. §8 has no row for the ticker lines, although the ticker is displayed and asserted (AC 419), and its source now differs from `hud.md`'s.
   - Fix: add one clause to §6 Playing out ("feed lines follow played steps, §15"). Add an §8 row: ticker / drawer lines, source = projection lines released by played steps, update = per finished step, owner Match Rules (event log), null = no line.
5. **A5 (round-2 A1)**: Closing the menu at the step. Persist settings that were already changed, and hand focus to Continue. [ADVISORY, carried]
6. **A6 (round-2 A2)**: A concede during the play-out can produce Victory. Route this to `pause-menu.md` and MUI-019. [ADVISORY, carried]
7. **A7 (round-2 A3)**: The banner stack assumes 1.15 line boxes. [ADVISORY, carried; shared with mulligan A1]
8. **A8 (round-2 A4)**: Separate `MATCH_END_ARM_MS`. [ADVISORY, routed, unchanged]
9. **A9 (round-2 A5)**: Feed drawer inert in `Ended`. [ADVISORY, routed, unchanged]

### GDD Alignment: GAPS FOUND (decided in the spec, routed, not blocking)
- This spec deliberately departs from match-ui U3.1 ("applied on receipt") for the feed, and from U10 as read by the Event Feed pattern and MUI-014. It routes the change with owners and a deadline that has not passed.
- The input-lock wording and the other routed gaps from round 1 are unchanged.

### Accessibility: COMPLIANT
- Target tier: Standard.
- "Pause anywhere … including during boss playback" holds through a lethal boss turn, and the ticker under the menu now tracks the board.
- The caption for every SFX (visual-for-every-sound elevation) is now in sync with its sound.

### Pattern Library: CONSISTENT (pattern amendment pending)
- The spec changes the Event Feed pattern's behaviour (receipt → played step) and flags it in §15, but does not route it to the pattern owner (A2). This is the same kind of pending pattern edit as round-2 hand A4, so it is advisory.

### Verdict: APPROVED
**Blocking issues**: 0
**Advisory issues**: 9
**Dimensions not assessed**: 0

This spec is ready for handoff to `/team-ui` Phase 2 (Visual Design).

---

## Notes (advisory)
- **Before `/dev-story` on MUI-014 or MUI-011**:
  - the producer amends MUI-014's ADR summary and ACs to require step-released lines, and adds a `seq` to the feed record;
  - the ux-designer amends the Event Feed pattern note and the `hud.md` §4.1 ticker row ("Every event" → "each finished step; step-less lines with the next step").

  The best place for A1's cursor rule is the Event Feed pattern, so that every spec inherits it.
- **Observation, outside the B1 scope**: in the Complete projection, `match_ended` enqueues an `END_BANNER` step with the `end_banner` duration (match_view_state.gd line 520). Spec §4 / §6 instead treats the `match_ended` step as having no animation, and starts the banner only after the queue drains. The two models give the same visual order, but MUI-011 should pick one. Either the Ending hook fires at the start of `END_BANNER`, or the step is split.
- On APPROVED, MUI-011 should cite `design/ux/match-end.md` in place of `hud.md` §5 / §12 (§15 row).
