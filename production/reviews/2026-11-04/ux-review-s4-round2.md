# UX Review: Sprint 4, round 2 (hand, targeting, mulligan, match-end)

**Date**: 2026-11-04
**Reviewer**: ux-review skill, followed by hand. The skill cannot be model-invoked, so `.claude/skills/ux-review/SKILL.md` was read and applied phase by phase. The owner's standing approval covers the run, so no questions were asked.
**Mode**: read-only. No spec, story or other repo file was edited and nothing was committed. Scratch files: `uxr4b_*.diff` (the revision diffs) and `uxr4b_py/uxr4b_contrast.py` (contrast re-computation), all in the session scratchpad.
**Scope**: revision 1 of each spec, which is commits 0d1941c (hand), 8d7eeed (targeting), 88219f0 (mulligan) and 5a69524 (match-end), plus ce40c47 (the MUI-005 / 008 / 009 AC amendments). None of the four specs changed after those commits; the merge is c5e6cb0.

## Method and inputs (Phase 2)

| Input | Resolution |
|---|---|
| Workflow | `resolve_config --keys workflow` gives `standard` (rigor standard) |
| Platform / input methods | Same as round 1. `project.yaml` has no `platform` block, so the values come from the `technical-preferences.md` fallback: keyboard/mouse primary, gamepad Partial (post-v1), no touch, PC, 1280x720 |
| Accessibility tier | `design/accessibility-requirements.md`: **Standard**, committed, plus three elevations. "Pause anywhere" (Basic) was read again, at line 205 |
| Pattern library | `interaction-patterns.md`, read by section: Card (Hand), Card Drag-to-Play, Click-to-Select / Keyboard Targeting, Targeting Arrow, Hero Power Button, Event Feed, Overlay Open / Close, Focus Management, Escape / Cancel |
| GDDs | match-ui: U3 (rules 1–5, `match_ended` rows), U4, U6, U8, U9, U10, States, F6, all read by offset/limit. match-rules was not re-read: no round-2 question needed new match-rules text, and round 1's F1 / C3 reading carries over |
| Siblings | `hud.md`: §4 element table (feed ticker row), §5 view-state table (`Menu` row), found by grep. Art bible §1, §2 and §4 (29.7 KB) were read by section |
| Stories | The ce40c47 diff (MUI-005, 008, 009). Grep only for MUI-011 (AC), MUI-014 (ADR summary) and MUI-019 (concede AC) |
| Engine reference | `docs/engine-reference/godot/` has no entry for `InputEventMouseButton.double_click`, `InputEvent.is_echo()`, `CanvasGroup` or HDR 2D. They are **NOT SOURCEABLE** there and are treated as observations, not verdict inputs (see the cross-spec notes) |
| Player journey | `design/player-journey.md` is still absent. Context on arrival is checked against each spec's §2, as in round 1 |

All arithmetic in the revisions was recomputed. That covers the hand dim tokens and the ratios marked †, the mulligan scale, safe-band and stack tables, and the match-end banner stack table. Every figure checks out unless a finding says otherwise.

**Checklist**: 3A for all four, from each file's `> **Template**: UX Spec` line.
**Dimensions not assessed**: none.

## Summary

| File | Verdict | Primary issue |
|---|---|---|
| `design/ux/hand.md` | **APPROVED** | B1 is resolved by the opaque value dim. The art-box exemption is upheld against art bible §1 and §4 for the placeholder art (advisory A1) |
| `design/ux/targeting.md` | **APPROVED** | B1 is resolved by the §7.4 precedence table. Rank 3 is sound; three wording gaps around it are advisory |
| `design/ux/mulligan.md` | **APPROVED** | B1, B2 and B3 are resolved. The 14 px row shift at 150 % is a refinement of F6, not a re-partition (advisory, routed) |
| `design/ux/match-end.md` | **NEEDS REVISION** | **B1 (new)**: under the sources as written, feed lines are projected **on receipt**. The ticker therefore shows the lethal lines during the play-out, which contradicts the spec's "nothing on screen reveals the outcome" claim and makes its pause-through-lethal AC unpassable |

### Rulings on the reviser's five questions

1. **Hand: is the art-box exemption an art-director call?** It is a look decision, but the spec can be implemented either way, so it is **advisory, not blocking** (hand A1). Ruled against art bible §1 and §4 for the v1 placeholder, the exemption is **upheld**:
   - §4 requires 3:1 for text ≥ 18 px bold, which includes the 24 px type initial. Dimming fails it: bronze 2.63 / 2.56, neutral 2.98 on `table_lit` (recomputed).
   - §1 Principle 1's design test is "when an art treatment and text contrast are in tension, the art loses". Here the dim is the art treatment and the initial is the text, so the initial wins.
   - The undimmed fills are hero secondaries, which are identification colours rather than state colours, so rule (b) is not engaged.
   - The playable cue is the outline, not the art box, so the "recede" read survives.

   The one qualification is **bitmap art**. There the stated reason (protecting the type initial) no longer exists. The spec's own bitmap path still draws the art box undimmed, as a sibling above the `CanvasGroup`. Full-colour illustration on an unplayable card does compete for brightness under §1 ("brightness goes to information"). The art-director should rule on that case before Alpha, which the spec's §15 deadline already allows.
2. **Mulligan: the 14 px row shift at 150 % against F6.** This is **not a re-partition**. F6 says UX specs "refine but may not re-partition" its zones. Moving the row stays within the overlay's own space over a dimmed, inert table. It enters no zone the overlay does not already cover, keeps the 723x315 size and stays inside the safe band. F6 already records a `text_scale` relocation for the boss strip at ≥ 125 % (row 607), which is a precedent for a scale note. **Advisory, correctly routed** (mulligan A2). It is not a mulligan-only matter: the Choice overlay shares the same F6 row, so it should adopt the same stack rule.
3. **Match-end: close the pause menu at the `match_ended` step, or hold the step?** **Closing is acceptable and is the GDD-consistent default.**
   - Playback keeps running under the pause menu (match-ui States `Menu` row, `hud.md` §5, MUI-019 ADR summary). The lethal steps therefore play under the menu either way, and holding protects only the menu, not the reading of the board.
   - Holding adds a queue block point that U4 does not have. Today the queue never waits on the pause menu.
   - Closing at the step reveals nothing the board has not already shown.
   - A press that lands as the menu closes falls into Ending (skip only), then Entering (completes the entry, not a Continue), then the 300 ms guard. It cannot dismiss the banner.

   Hold remains a valid fallback if Jacob prefers never to remove a menu from under the player. The residual risks are advisory (match-end A1).
4. **Do feed lines reveal the outcome on receipt? Yes, under the sources as written.** This is **blocking** for match-end (B1). See the finding for the source chain.
5. **Targeting §7.4 rank 3** is sound. It honours the ranking principle (a reversible re-select outranks an irreversible confirm), and it agrees with the Click-to-Select pattern ("click on a *different* legal source (which re-selects it)"). The Phase P claim also holds. Gap index = slot under the pointer in the m + 1 layout the row is moving to, so in the row band the slot under the pointer is always the open gap, and no token is hit. Three wording gaps sit next to it, all advisory (targeting A1–A3).

---

## UX Review: Hand
**Date**: 2026-11-04
**Reviewer**: ux-review skill
**Document**: `design/ux/hand.md`
**Checklist**: 3A (Template line)
**Platform Target**: PC, mouse primary / keyboard complete / gamepad Partial post-v1 / no touch
**Accessibility Tier**: Standard (+3 elevations), committed

### Round-1 resolution
| Round 1 | Status | Evidence |
|---|---|---|
| B1: dim compositing | **Resolved** | §5.3 adds the opaque value-dim rule (`0.6 c + 0.4 fill`, sRGB, opaque). Per-node alpha is forbidden, with pre-mixed tokens in v1 and a `CanvasGroup` over an opaque backing for bitmap art. §12 is re-derived, with name band, keyword glyphs, art box, silhouette and dash rows added. The `hand_10_mixed` AC tests the overlapped case on both fills. A grep AC bans `modulate.a` in the not-playable path. Every † figure was recomputed and matches: tokens `#A99A85` / `#30251B` / `#AFA191` and `#9C917F` / `#241D16` / `#A2998B`; 5.40 / 5.39, 5.92 / 5.94, silhouette 4.12 / 5.09, dash 6.26 / 5.58, per-node 3.63 / 3.78 |
| A1: default focus opens the preview | Routed | §15 row added (Match UI GDD owner, before MUI-018 implementation) |
| A2: dashed ring on the `ink` stamp | Resolved | Gaps are cut through to the card body. The `ink` dash against the dimmed parchment gap is 6.26 / 5.58 on both stamp fills |
| A3: cost freshness | Resolved | §8 states the lag and its reason; §15 routes the `hand_costs_changed` / row-wording choice |
| A4: Spell Damage band | Resolved | x 12–213, y 144–168 (201x24) sits inside the 1.5x art box and above the keyword row. The §13 width is updated |
| A5: `Up` / `Down` keys | Resolved | Flagged in §15 for Standard Shortcuts |
| A6: scaled spell damage | Routed (unchanged) | The §14 criterion stays NOT ASSESSED until a read model exists |

### Completeness: 15/15 sections present

### Quality Issues: 0 blocking, 4 advisory
1. **A1: Art-box exemption is upheld for placeholder art; the bitmap-art case needs the art-director** [ADVISORY]
   - What's wrong: see ruling 1. In the bitmap path (§5.3) the art box still draws as an undimmed sibling, although the reason for the exemption (the type initial) no longer applies there.
   - Where: §5.3 compositing rule, "Bitmap card art"; §15 compositing row.
   - Fix: scope the exemption to placeholder fills, or leave the bitmap case explicitly open for the art-director (the "real card art may change it" note already points there).
2. **A2: An exhausted trigger glyph on a not-playable card is invisible** [ADVISORY]
   - What's wrong: §6 says that on a not-playable card the exhausted glyph is "mixed once, not twice". It then looks identical to every other dimmed glyph on that card, so the match-ui U3 cue ("dimmed once-per-turn trigger icon on the source card") disappears exactly where a hand-hosted passive is most likely to sit. No v1 content uses `passive_hand` (grep of `assets/data/`: 0 hits), hence advisory.
   - Where: §6 "Card — once-per-turn exhausted".
   - Fix: give the exhausted glyph a non-value cue (for example a slash or a ✓ badge), or mix it twice and check that it stays ≥ 3:1 as a non-text glyph.
3. **A3: Keyword glyph backing is unspecified where the icon row overlaps the art box** [ADVISORY]
   - What's wrong: the art bible slot puts 12 px icons "along the art-box bottom edge" with a 4 px overlap tolerated. With the art box now undimmed, a dimmed letter glyph that straddles the edge partly sits on an undimmed bronze or neutral fill, which is not one of §12's two backgrounds.
   - Fix: state that keyword glyphs always draw on their own `ink` pill (the second §12 row), or that the icon row lies wholly below y 118.
4. **A4: Pattern and audit updates are still pending outside the spec** [ADVISORY: route]
   - What's wrong: these §15 rows are "Proposed here" with a "round 2" deadline, and none of the target documents has been edited (correctly, since the lane is spec-only): the Card (Hand) "verify" note → the compositing rule; the audit row → the notched ring; Standard Shortcuts → `Up` / `Down`. The Card (Hand) pattern still says "body dimmed to 60% alpha", which now contradicts the spec.
   - Fix: the ux-designer applies the three rows to `interaction-patterns.md` and `accessibility-requirements.md` before MUI-006 implementation.

### GDD Alignment: ALIGNED (routed gaps unchanged from round 1)
The round-1 routed gaps (U3 rows, graveyard rect, re-space timing, inspect in `BossTurn`, sizes 11–12, `unplayable_reason`) now carry "before MUI-006 implementation" deadlines, which corrects the round-1 note about passed readiness deadlines.

### Accessibility: COMPLIANT
- Target tier: Standard.
- B1 is closed, and every not-playable row in §12 meets its ratio on both fills.
- A2 and A3 are advisory edge cases.

### Pattern Library: CONSISTENT
- New patterns are flagged (the compositing rule, art-box exemption, notched ring, keys).
- A4 tracks the pending pattern edits.

### Verdict: APPROVED
**Blocking issues**: 0
**Advisory issues**: 4
**Dimensions not assessed**: 0

This spec is ready for handoff to `/team-ui` Phase 2 (Visual Design).

---

## UX Review: Targeting
**Date**: 2026-11-04
**Reviewer**: ux-review skill
**Document**: `design/ux/targeting.md`
**Checklist**: 3A (Template line)
**Platform Target**: PC, mouse primary / keyboard complete / gamepad Partial post-v1 / no touch
**Accessibility Tier**: Standard (+3 elevations), committed

### Targeting — Round-1 resolution
| Round 1 | Status | Evidence |
|---|---|---|
| B1: click precedence | **Resolved** | §7.4 is a ranked table per phase (P / T / C) with first-match semantics. The principle is stated: reversible outranks irreversible, with lit targets in T as the one exception. Hover pre-signals rank 3. There is a separate drag-release table, and §7.2's four overlapping rows are replaced. Six ACs cover the C / P / T resolutions, the double-click and drag release. Rank 3 analysis: ruling 5 |
| A1: hero weapon by key | Unticked and routed (still open, high priority) | §11 rows unticked; the §14 completion AC adds the weapon attack and says it cannot pass yet; §15 offers an `A`-badge "0" alternative |
| A2: MUI-008 conflict | Partly resolved | The ce40c47 MUI-008 AC now matches parking at y 438, the cast zone and "drag release never re-selects". The Battlecry P → T case is explicitly excluded and routed |
| A3: `A` + number | Resolved | Slot position = index + 1, badges on legal attackers only, an unbadged number is ignored and the state stays armed. Two ACs |
| A4: double-click, `H` in session | Resolved | The OS double-click flag on rank 2; `H` re-selects, or is ignored in its own session; a knob is proposed if playtests need one |
| A5: Phase T filtered by position | Resolved | §6 re-derives from the chosen `position`, plus the `(p, null)` auto-submit; AC added |
| A6: 150 % | Resolved | Pill sizes 20 / 24 / 28; the chip widens; fixture `targeting_taunt_ts150` and AC |
| A7: Escape chain | Routed | §15 row |
| A8: resolution criterion | Resolved | §14 AC |

### Targeting — Completeness: 15/15 sections present

### Quality Issues: 0 blocking, 5 advisory
1. **A1: Rank 6's examples are overridden by rank 4 inside a zone** [ADVISORY]
   - What's wrong: rank 6 ("Anywhere else") lists "an unlit or Stealth token" and "a not-playable hand card". First-match puts rank 4 ahead of rank 6 for any spot inside the phase's zone, so:
     - in Phase C, every enemy or summoning-sick token sits inside the cast zone and resolves to **Confirm**;
     - in Phase P, a not-playable hand card in the strip y 462–484 resolves to **Place**.

     The table is deterministic, but a QA tester reading rank 6's list would expect Cancel. The Phase P case is also a small irreversible commit from a click on a card the player may have meant to inspect.
   - Where: §7.4 click table, ranks 4 and 6.
   - Fix: qualify rank 6's list as "outside the zone (and, in Phase T, anywhere not lit)". Then either accept the strip case, or exclude the hand strip from the position zone for clicks (drags already cancel below y 484). Add one AC for each.
2. **A2: `A` inside a session is undefined, yet rank 3 relies on it** [ADVISORY]
   - What's wrong: rank 3 (Phase P) says "to re-select an attacker from Phase P, cancel first, or press `A` + number". §7.1 defines `A` only as an entry from `Idle` (§4 row 93), while "`1`–`9`, `0` during a session" re-selects **hand card n**. In a session, `A` then `2` could mean attacker 2 or hand card 2.
   - Fix: define `A` in a session (it arms; the following badge number re-selects that attacker and does not re-select a hand card), or drop the hint.
3. **A3: Triple-click and the double-click guard** [ADVISORY]
   - What's wrong: the guard ignores only the press flagged `double_click`. Whether a third rapid press is flagged is engine behaviour that `docs/engine-reference/godot/` does not cover (NOT SOURCEABLE). If it is not flagged, a triple-click commits an untargeted play, which is the tremor case A4 was about.
   - Fix: the ui-programmer verifies the third-press behaviour in 4.7.2. If it is unflagged, also ignore a press within the OS interval of a flagged one. The §15 knob row is already the escalation path.
4. **A4: Hero weapon attack by keyboard is still unresolved** [ADVISORY, carried, high priority]
   - What's wrong: correctly unticked and routed (round-1 A1). One-hand mode fails for War until the GDD owner picks the portrait-`Enter` or the badge-"0" path.
   - Fix: decide it before MUI-017 implementation.
5. **A5: MUI-008 still excludes the Battlecry P → T case** [ADVISORY: route]
   - What's wrong: the amended AC states the exclusion honestly. The case stays uncovered until match-ui U5 / States record the sequence (R1).
   - Fix: the producer tracks it with the GDD owner.

### GDD Alignment: ALIGNED (routed gaps)
- There are no new GDD conflicts.
- R2 (MUI-005 one-click hero power) is **closed**: the amended MUI-005 AC requires the confirm and cites §7.4 rank 2.

### Accessibility: GAPS (advisory)
- Target tier: Standard.
- A4 (keyboard-only weapon attack) is routed and not owned by the spec.
- A3 (triple-click) needs an engine check.
- The rest is as in round 1: shape-first cues, discrete presses, contrast. The 150 % case is now covered.

### Targeting — Pattern Library: CONSISTENT
- §7.4 is flagged for Click-to-Select rule 2 and match-ui U5.
- The badges and the Escape-chain row are flagged.

### Targeting — Verdict: APPROVED
**Blocking issues**: 0
**Advisory issues**: 5
**Dimensions not assessed**: 0

This spec is ready for handoff to `/team-ui` Phase 2 (Visual Design).

---

## UX Review: Mulligan
**Date**: 2026-11-04
**Reviewer**: ux-review skill
**Document**: `design/ux/mulligan.md`
**Checklist**: 3A (Template line)
**Platform Target**: PC, mouse primary / keyboard complete / gamepad Partial post-v1 / no touch
**Accessibility Tier**: Standard (+3 elevations), committed

### Mulligan — Round-1 resolution
| Round 1 | Status | Evidence |
|---|---|---|
| B1: 5-card row covers base elements | **Resolved** | Safe band x 208–1072, y ≥ 98, centred on 640, 864 px wide. Its clearances check out: End Turn 1116 (44 px), hero power 152–200 (8 px), ticker bottom 90 (8 px). The card-scale rule gives n ≤ 3 at 1.5x (723 ≤ 864), n = 4 at 1.2x (768, x 256–1024) and n = 5 at 1.0x (814, x 233–1047). A pixel-equality AC covers the unobstructed rects at 100 % and 150 % |
| B2: header collision at 125 / 150 % | **Resolved** | The top-anchored stack rule was recomputed and matches. Title 98 / 32-40-48 → sub-line 136 / 144 / 152 → 2-line block ends 172 / 190 / 208 → R = 202 / 202 / 216. Pills, status and Confirm are derived for n = 1–5 at each scale, all verified. There are ts125 and ts150 ACs, and the pseudo-locale AC runs at each scale |
| B3: printed vs effective cost | **Resolved** | §8 reads `hand(player)` at the `mulligan_offered` step and again at `mulligan_resolved`, with the modified-cost stamp and the Printed-cost line. A `mulligan_discount` AC is mirrored in MUI-009. The reasoning holds: the engine is waiting for the mulligan command at that step, so `hand()` and the projection agree |
| A1: drop overlaps the pill | Resolved | Pills sit 16 px below the row, leaving 4 px clear after the 12 px drop. n ≥ 6 uses a 4 px drop |
| A2: "one press" | Resolved | The claim is corrected (one click, or `Shift+Tab` + `Enter`); the reflexive-`Enter` risk is routed |
| A3 / A5 | Resolved | Keys flagged; mulligan-specific rejection copy and key added |
| A4: n = 4 and n ≥ 6 | Resolved / routed | n = 4 is fixed by the rule; n ≥ 6 at 125 / 150 % is routed as unspecified |
| A6: resolution criterion | Resolved | §14 AC |

### Mulligan — Completeness: 15/15 sections present

### Mulligan — Quality Issues: 0 blocking, 5 advisory
1. **A1: The stack rule assumes 1.15 line boxes without saying how they are enforced** [ADVISORY; shared with match-end A3]
   - What's wrong: every y in the stack table depends on line box = 1.15 × font size. The art bible names "Godot's built-in default theme font", whose natural line height this repo does not source. If it is taller than 1.15 em, an unadjusted `Label` overruns the reserved boxes and the "no two boxes overlap" ACs fail.
   - Fix: state the mechanism (for example, line spacing set on the label so that its line box is 1.15 × size) and measure glyph-ink bounds in the ts125 / ts150 ACs.
2. **A2: 14 px row shift at 150 % (ruling 2)** [ADVISORY, routed]
   - What's wrong: this is a refinement, not an F6 re-partition. The GDD owner should record it as a `text_scale` note on the Choice / Mulligan row, with the same rule for the Choice overlay, which shares the rect.
3. **A3: n ≥ 6 is reachable at a legal tuning** [ADVISORY]
   - What's wrong: `STARTING_HAND_PLAYER`'s safe range is 3–4, and Bottomless Satchel adds 2, so a tuned value of 4 gives n = 6. That is "not reachable with v1 content" only at the default 3. Its 125 / 150 % layout is unspecified (§15).
   - Fix: note the dependency against the knob's safe range in §15, or cap the knob at 3 while the Satchel is in the pool.
4. **A4: The safe-band claim includes 12 px of the mana bar** [ADVISORY, cosmetic]
   - What's wrong: the band (x ≤ 1072, y ≥ 98) contains the mana bar's left edge (x 1060–1072, y 652–708). No overlay element draws there, and mana is 0/0 during the mulligan.
   - Fix: say so, or set the band's lower-right exclusion.
5. **A5: Stale MUI-009 implementation note** [ADVISORY: producer]
   - What's wrong: after the amendment, MUI-009's Implementation Notes still say "this story wires `1`–`3` toggles", while the amended AC requires `1`–`5`.
   - Fix: correct the note.

### Mulligan — GDD Alignment: ALIGNED (routed gaps)
- The F1 contradiction (round-1 B3) is gone.
- U8 / F6 still assume 3 cards. The conflict is routed, and the MUI-009 ACs are amended.
- The `hand()`-in-`Mulligan` confirmation is routed.

### Mulligan — Accessibility: COMPLIANT
- Target tier: Standard.
- Text scaling is fully specified for n ≤ 5.
- The context promised under the dim stays visible at every v1 hand size and scale.
- The modified-cost cue has its colour-blind backup.

### Mulligan — Pattern Library: CONSISTENT
- The safe band, refined overlay, keys and rejection-copy override are all flagged in §15.

### Mulligan — Verdict: APPROVED
**Blocking issues**: 0
**Advisory issues**: 5
**Dimensions not assessed**: 0

This spec is ready for handoff to `/team-ui` Phase 2 (Visual Design).

---

## UX Review: Match End
**Date**: 2026-11-04
**Reviewer**: ux-review skill
**Document**: `design/ux/match-end.md`
**Checklist**: 3A (Template line)
**Platform Target**: PC, mouse primary / keyboard complete / gamepad Partial post-v1 / no touch
**Accessibility Tier**: Standard (+3 elevations), committed

### Match End — Round-1 resolution
| Round 1 | Status | Evidence |
|---|---|---|
| B1: lock / close on projection | **Resolved for pause and overlays** | Play-out → Ending → Entering. Pause, feed and Menu stay reachable until the queue reaches the `match_ended` step; only a targeting session is cancelled on receipt; a confirmed concede is immediate. This agrees with match-ui States, `hud.md` Menu and "Pause anywhere". The outcome-hiding half depends on the feed (new B1 below) |
| B2: no 150 % layout | **Resolved** | Banner stack rule. Height = max(200, 108 + L_H + (k+1)·L_r), bottom fixed at 460, Continue at 560, 400. All six rows of the table were recomputed and match. The "four text rows" error is withdrawn. The wrap estimates (71 / 57 / 47 chars) check out |
| A1 (a–d) | b, c, d resolved; a routed | Guard ensures rendering, not reading; Continue drawn Disabled during the guard; `is_echo()` ignored; separate `MATCH_END_ARM_MS` recommended |
| A2: turn 0 | Resolved | Facts line omitted; AC |
| A3: feed in `Ended` | Routed (unchanged) | — |
| A4: wireframe | Resolved | — |
| A5: resolution criterion | Resolved | — |

### Match End — Completeness: 15/15 sections present

### Quality Issues: 1 blocking, 5 advisory
1. **B1: Feed lines are projected on receipt, so the ticker shows the outcome during the play-out** [BLOCKING]
   - What's wrong: §4 (row "`match_ended` received") says "Nothing on screen reveals the outcome before those steps show it", and the §14 pause-through-lethal AC asserts "the capture shows no outcome cue". §15 only *assumes* "feed lines follow their steps (U4)". The sources say otherwise:
     - match-ui U3 lists `feed_lines[]` as a `MatchViewState` field, and U3.1 applies every event "immediately … on receipt";
     - the Event Feed pattern's implementation note: "`EventFeed` renders `MatchViewState.feed_lines[]`";
     - MUI-014's ADR summary: "Feed lines are view-state (`feed_lines[]` recorded by the projection)";
     - `hud.md`'s element table gives the ticker an update frequency of "Every event", and its `Menu` row says "the ticker keeps updating";
     - nothing in U4 or U10 holds a line back until its step.

     U6 delivers the whole boss turn as one burst at `turn_started{boss}`. So on a lethal boss turn, the ticker's three newest lines (24, 48, 400, 42, lit in every state, outside the 440–840 pause-menu rect) show the end of the turn, including the lethal damage, before the first attack plays. An implementation that follows the GDD and MUI-014 fails this spec's AC.
   - Where: §4 entry table, row 2; §6 Playing out; §14 Input AC "Pause through a lethal boss turn"; §15 "Feed timing".
   - Fix (either is a small edit):
     - (a) Make it a stated requirement with a dependency: feed lines are released when their step's `apply_final` runs, and zero-step events with the next step in `seq` order. Route the change to the match-ui U10 owner, the Event Feed pattern and MUI-014 (producer) before MUI-011 / MUI-014 implementation. Have the AC cite that dependency.
     - (b) Narrow the claim and the AC to the board, the portraits and the banner, and accept that the ticker leads the playback.

     Either way, note that this affects **every** boss turn, not only the lethal one: it is a cross-spec feed question, and match-end is only where it is asserted.
2. **A1: Closing the menu at the step, not holding (ruling 3)** [ADVISORY]
   - What's wrong: the choice is accepted. Two residual risks remain unstated:
     - the menu may close while the player is in the settings quick-access, so state that any setting already changed is persisted (`set_setting` per change), not dropped on close;
     - the closing menu should hand focus to Continue (the Focus on close rule "trigger or last focused" no longer applies).
   - Fix: add both to §6 Ending.
3. **A2: A concede during the play-out can produce a Victory banner** [ADVISORY]
   - What's wrong: §6 flushes a confirmed concede to the real result. If the player's own lethal command is still playing, a player who just confirmed "Concede" gets "Victory". That is correct but surprising.
   - Fix: say so in §6 and route it to `pause-menu.md`, whose confirm copy should not promise a loss. Also route the "no `concede` after receipt" rule to **MUI-019** (producer). Its concede AC covers the pre-receipt case only, and `pause-menu.md` is not yet written.
4. **A3: The banner stack assumes 1.15 line boxes** [ADVISORY; shared with mulligan A1]
   - What's wrong: same mechanism gap as mulligan A1, for the headline and line boxes.
5. **A4: Separate arm knob (round-1 A1 a)** [ADVISORY, routed, unchanged]
6. **A5: Feed drawer inert in `Ended` (round-1 A3)** [ADVISORY, routed, unchanged]

### GDD Alignment: GAPS FOUND
- B1: the spec's outcome-hiding claim conflicts with U3.1 / U10 as written, and with MUI-014.
- The Edge Cases wording change ("Input is locked from the moment `result` is set") is routed.
- The other round-1 routed gaps are unchanged.

### Match End — Accessibility: COMPLIANT
- Target tier: Standard.
- "Pause anywhere … including during boss playback" now holds through a lethal boss turn.
- Text scale is fully specified.
- B1 is a spoiler and consistency issue, not an accessibility gap.

### Match End — Pattern Library: CONSISTENT
- Overlay, Escape / Cancel (4a), Button and Disabled-during-guard follow their patterns.
- The Event Feed pattern's implementation note is the source B1 cites. A fix of type (a) needs it amended.

### Verdict: NEEDS REVISION
**Blocking issues**: 1
**Advisory issues**: 5
**Dimensions not assessed**: 0

Address the 1 blocking issue above, then re-run `/ux-review`.

---

## Cross-spec notes (advisory)
- **Engine APIs the specs depend on are not in the engine reference**: `InputEventMouseButton.double_click` (targeting rank 2), `InputEvent.is_echo()` (match-end), `CanvasGroup` and sRGB 2D blending without HDR 2D (hand). All of them predate the model's cutoff, but `docs/engine-reference/godot/` does not cover them (NOT SOURCEABLE there). The ui-programmer verifies them against 4.7.2 at implementation. None changes a verdict.
- **The line-box mechanism** (mulligan A1, match-end A3) should be one rule in the pattern library (Typography / Label), not two per-spec assumptions.
- **The feed-timing decision** (match-end B1) belongs to match-ui U10, the Event Feed pattern and MUI-014. Whichever way it goes, `hud.md`'s "Every event" ticker row should say whether that means receipt or step.
- **Stories**: MUI-005 is now consistent. MUI-008 is consistent except for the routed Battlecry case. MUI-009 is consistent except for the stale note (mulligan A5). MUI-011 does not contradict the spec. MUI-019 needs the post-receipt concede rule (match-end A2).
- Once APPROVED, hand, targeting and mulligan should be cited in MUI-006 / 008 / 009 / 016 / 017 / 018 in place of `hud.md` (each spec's §15).
