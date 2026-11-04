# UX Review — Sprint 4, round 1 (hand, targeting, mulligan, match-end)

**Date**: 2026-11-04
**Reviewer**: ux-review skill, followed by hand. It cannot be model-invoked, so `.claude/skills/ux-review/SKILL.md` was read and applied phase by phase. The owner's standing approval covers it, so no questions were asked.
**Mode**: read-only. No spec or other file was edited, and nothing was committed.

## Method and inputs (Phase 2)

| Input | Resolution |
|---|---|
| Workflow | `resolve_config --keys workflow` → `standard` (rigor standard) |
| Platform / input methods | `project.yaml` has no `platform` block, so the fallback is `.claude/docs/technical-preferences.md` § Input & Platform: Keyboard/Mouse primary, Gamepad Partial (post-v1), Touch None, PC only, 1280x720. All four specs state the same values. |
| Accessibility tier | `design/accessibility-requirements.md` → **Standard**, committed, plus three elevations: reduce-motion, a visual twin for every sound, and the high-contrast state set |
| Pattern library | `design/ux/interaction-patterns.md`, present. Read by section: Card (Hand), Click-to-Select, Targeting Arrow, Card Inspect, Hero Power Button, Pick One of N, Overlay Open / Close, Focus Management, Escape / Cancel, Standard Shortcuts |
| GDDs | match-ui (U2, U3, U4, U5–U11, States, F1–F6, Edge Cases, Tuning Knobs, UI Requirements); match-rules (C2, C3 incl. DD-X13, C6, C7, C8 incl. DD-X11, C14, F1, UI Requirements); card-effects (C1, C7, UI Requirements); treasures (`modify_cost` rows, by grep). All were read by section. None was read whole; every file over 40 KB was read by offset/limit. |
| Siblings / other | `hud.md` (APPROVED): §5, §10.2, Focus Order, §4.2 (by grep). Art bible §4. `design-decisions.md` (whole, 11 KB). Stories MUI-005, 006, 008, 009, 011, 015, 016, 017, 018: AC and notes. **All of them are already `Status: Ready`.** |
| Player journey | `design/player-journey.md` is absent, so context-on-arrival was checked against each spec's own §2 only. Each spec already lists the missing map in §15. |

**Checklist**: 3A for all four. Each file carries `> **Template**: UX Spec`.
**Dimensions not assessed**: none. All four dimensions (Completeness/Quality, GDD Alignment, Accessibility, Pattern Library) had a source of truth, and `/ux-review` itself needs no agents. The art-director sign-offs that the specs request (modified-cost stamp, boss-panel "saturation") are design approvals, not review dimensions. They stay open as routed items.

## Summary

| File | Verdict | Primary issue |
|---|---|---|
| `design/ux/hand.md` | NEEDS REVISION | The 60 % alpha dim on unplayable cards has no compositing rule. With per-node alpha the name band fails 4.5:1, and in a crowded fan neighbouring cards show through. |
| `design/ux/targeting.md` | NEEDS REVISION | In a pointer session a click on a token inside the cast zone (or position zone) matches three rules at once: confirm (irreversible), cancel and re-select. |
| `design/ux/mulligan.md` | NEEDS REVISION | The v1-reachable 5-card row (Bottomless Satchel) covers the boss passive plate, the boss hand count and the player portrait. The header overlaps at 125/150 % text scale, and the cost shown contradicts match-rules F1. |
| `design/ux/match-end.md` | NEEDS REVISION | Input is locked and overlays are closed when `match_ended` is *projected*. That removes pause during a lethal boss turn and spoils the outcome. The 150 % layout is also unspecified. |

On the author's four flagged items:

1. **0–10 card mulligan layout** → mulligan **B1** (n = 5) is blocking; n = 4 and n ≥ 6 are advisory.
2. **Two-step minion play** → the design is sound and is routed correctly to the GDD owner (targeting R1). The click-precedence gap next to it is **B1**. The MUI-008 conflict is advisory A2.
3. **300 ms Continue delay** → advisory only (match-end A1 a–d). The blocking match-end items are elsewhere.
4. **MUI-005 one-click hero power** → routed correctly and **does not block** (targeting R2). The spec agrees with GDD U5, `hud.md` §4.2 ("untargeted still need the confirm press") and the Hero Power Button pattern. Only the story AC disagrees.

---

## UX Review: Hand
**Date**: 2026-11-04
**Reviewer**: ux-review skill
**Document**: `design/ux/hand.md`
**Checklist**: 3A (Template line)
**Platform Target**: PC, mouse primary / keyboard complete / gamepad Partial post-v1 / no touch
**Accessibility Tier**: Standard (+3 elevations), committed

### Completeness: 15/15 sections present
All required sections are present. States cover reload (no loading state applies), empty (a deliberate absence), the error / desync guard, and every view state. A resolution criterion is present (1280x720 and 3840x2160).

### Quality Issues: 1 blocking, 6 advisory
1. **B1 — The 60 % "not playable" dim has no compositing rule, so §12's ratios do not hold** [BLOCKING]
   - What's wrong: §5.3 and §6 put "60 % alpha on frame, art box, text box and bottom stamps". §12 computes the ratios as "60 % alpha composited over the fill", which is only true if each card is flattened as one group over the table. Two cases break it.
     - **Per-node alpha.** A plain `modulate` on each node blends every node separately, so the parchment body shows through the `ink` name band. `text_light` on the result is ≈ 3.6:1, below the 4.5:1 that §12 itself requires for 14 px bold names. §12's not-playable rows also leave out the name band.
     - **The crowded fan** (F1 overlap from n = 6, visible strip 72–158 px). A 60 % card lets the overlapped neighbour show through, putting ghost glyphs (≈ 2.4:1) under its own rules text. The background is then a card, not the table, so "5.44 over `table_lit`" is not the case that ships.
     - The Card (Hand) pattern asked for exactly this check ("verify … if not, dim only the art box and frame").
   - Where: §5.3 "Not-playable dim", §6 card states, §12 contrast table, §14 Accessibility AC 1.
   - Fix: specify the compositing. Use either:
     - a group alpha (one flattened layer per card, e.g. a `CanvasGroup`) over an opaque backing in the hand-fill colour, or
     - an opaque value dim (lerp toward `table_lit` / `table_dark`) instead of alpha.

     Then add the name band (and keyword glyphs) to the 60 % rows of §12, re-derive the ratios against the overlapped case, and name an n = 10 fixture with mixed playability for the AC.
2. **A1 — The default Idle focus opens a 1.5x preview after every action** [ADVISORY — inherited, route]
   - What's wrong: §6 "Card — focused" (default Idle focus → preview immediately) and AC 441 together put a 225x315 preview (top y 381) over the player row (y 334–460) at every queue drain and every turn start. Mouse players get it too, right where they just placed a minion. The cause is GDD U5 (focus opens the preview; default stop = left-most playable card) combined with `hud.md`, not this spec alone.
   - Fix: proposed rule — a programmatic default focus draws the ring only; the preview opens on focus only once a keyboard input has followed the last pointer input. Route it to the Match UI GDD owner and to `interaction-patterns.md` Focus Management.
3. **A2 — The unaffordable dashed `ink` ring disappears on the modified-cost stamp** [ADVISORY]
   - What's wrong: a card can be both modified-cost (`ink` fill) and unaffordable. A dashed `ink` ring on an `ink` fill cannot be told apart from the solid one, so AC 432 ("every card whose cost exceeds the available mana has a dashed `ink` cost ring") cannot be observed on those cards.
   - Fix: draw the dashed ring just outside the stamp fill, on parchment (≈ 12.7:1), for both stamp variants, or give the `ink` variant its own cue.
4. **A3 — Cost freshness** [ADVISORY]
   - What's wrong: the match-rules UI Requirements row says "Hand with effective cost … every event (costs can change)". §8 reads `hand()` only at Idle entry and after drains, so stamps can stay stale through `BossTurn` (for example when an aura minion dies). This follows U2's no-polling rule, but the spec does not state the lag.
   - Fix: state the lag and its reason, or project cost changes from the events, since U3's view-state holds the hand costs. Note it against the match-rules row.
5. **A4 — Spell Damage band geometry** [ADVISORY]
   - What's wrong: the band is 213 px wide, but the 1.5x art box is 201 px (x 12–213). At y 153–177 it also overlaps the keyword icon row that runs along the art-box bottom edge (≈ y 168–186 at 1.5x).
   - Fix: re-fit it when the data row is resolved.
6. **A5 — `Down` / `Up` scroll keys are new match keys** [ADVISORY]
   - What's wrong: Standard Shortcuts lists `Up` / `Down` as "— (no lists in the HUD)" for the match, and says "additions go through this library". §15 does not flag the addition.
   - Fix: add a §15 row for the library.
7. **A6 — Scaled spell damage deviates from card-effects** [ADVISORY — correctly routed]
   - What's wrong: card-effects UI Requirements asks for the scaled value "on the card in hand, replacing the printed number". The spec draws a band in the preview, and only when a read model exists; the AC marks itself NOT ASSESSED. The routing is correct. Listed so the GDD gap stays visible.

### GDD Alignment: GAPS FOUND (routed)
- match-ui UI Requirements "Hand fan": 4/4 covered (F1, effective cost, lit / dimmed, F2 hover, drag hand-off).
- match-rules UI Requirements "Hand with effective cost … playable lit": covered; update frequency per A3.
- card-effects UI Requirements: once-per-turn dim covered; scaled damage partially covered and routed (A6).
- heroes (Insight tax) and treasures (`modify_cost` discount) covered by the modified stamp.
- **Routed, non-blocking (correct owners in §15)**:
  - match-ui U3 has no rows for `card_added_to_hand`, `minion_returned` or `minion_transformed`.
  - `card_discarded` "flies to the graveyard", but F6 has no graveyard rect.
  - Re-space timing.
  - Inspect during `BossTurn`.
  - Hand sizes 11–12.
  - `unplayable_reason`.
  - Modified-cost stamp (art-director).
  - Closing the match-ui open question on the hover overlap.

  Many §15 deadlines say "before MUI-006 readiness", but **MUI-006 is already Ready**. Re-target them to "before MUI-006 implementation".

### Accessibility: GAPS
- Target tier: Standard (+ elevations).
- B1 (contrast of the dimmed cards); A2 (non-colour backup lost in one combination).
- Text scaling is well specified: the reading panel placement rule is exact, `hand_10_ts150` is named, and the placement and clamp arithmetic was verified (x 435.5 / 724.4 / 484.5; right edge ≤ 1108; bottom y 644).
- Focus order matches `hud.md` stop 1. Colourblind backups (outline value, dash, stamp fill, printed-cost line) are present, apart from A2.

### Pattern Library: INCONSISTENCIES FOUND
- A5 (unflagged new keys).
- The Card (Hand) "verify" note is closed incorrectly (B1).
- New patterns are flagged correctly in §15: modified-cost stamp, unaffordable ring, reading-panel placement.

### Verdict: NEEDS REVISION
**Blocking issues**: 1 — must be resolved before implementation
**Advisory issues**: 6 — recommended but not blocking
**Dimensions not assessed**: 0

Address the 1 blocking issue above, then re-run `/ux-review`.

---

## UX Review: Targeting
**Date**: 2026-11-04
**Reviewer**: ux-review skill
**Document**: `design/ux/targeting.md`
**Checklist**: 3A (Template line)
**Platform Target**: PC, mouse primary / keyboard complete / gamepad Partial post-v1 / no touch
**Accessibility Tier**: Standard (+3 elevations), committed

### Completeness: 15/15 sections present
All required sections are present. The rejection copy covers all 21 match-rules C2 codes (counted). There is no resolution / scaled-window criterion; see A8.

### Quality Issues: 1 blocking, 8 advisory
1. **B1 — Pointer-session click precedence is undefined inside the cast and position zones** [BLOCKING]
   - What's wrong: the cast zone (301, 176, 678, 284) contains both minion rows.
     - §6 (KeyTargeting — pointer) and §7.2 say "LMB on … cast zone → Confirm".
     - They also say "LMB on empty table / an unlit token → Cancel".
     - And "LMB on a different legal source → Re-select". A friendly token that can attack is such a source, and it sits inside the zone.

     So in Phase C one click on a token matches three rules, and one of them is irreversible: mana is never refunded (match-rules C5) and the hero power is once per turn. Phase P has the same problem: the position zone (x 253–1027, y 310–484) contains the player row's tokens, so the same click could mean "place at the nearest gap" or "re-select that attacker".
   - Where: §5.2 Cast / Position zone, §6 KeyTargeting rows, §7.2.
   - Fix: add a precedence rule per phase (P / T / C × pointer click), for example:
     - Phase C — re-select a legal source > confirm anywhere else in the cast zone > cancel outside it, or confirm only on the dashed outline or a second click on the source.
     - Phase P — re-select > nearest gap.

     Give the drag-release case its own row too, and add one AC per resolution.
2. **A1 — Hero weapon attack by keyboard: the §11 rows are ticked although unmet** [ADVISORY — correctly routed, high priority]
   - What's wrong: §11 ticks "every action … by keyboard" and states an exception in the same line. War is the only MVP hero (DD-H06), and weapons are War's identity. With no key path, the accessibility One-hand mode commitment (keyboard-only completes a full run) fails. The routing (GDD U5 key list; `hud.md` stop 4 "Nothing") is correct.
   - Fix: untick the two §11 rows. Add "a hero weapon attack" to the §14 keyboard-only / mouse-only completion AC. Resolve the conflict before MUI-017 is *implemented*: the story is already Ready, so the "before MUI-017 readiness" deadline has passed.
3. **A2 — Story MUI-008 (Ready) conflicts with the spec** [ADVISORY — route to producer]
   - What's wrong: MUI-008's AC has the card "follow the cursor … (or, for a targeted card, the arrow and every legal target …)", and its `InputRouter` states are `Idle` / `Dragging` only. The spec instead:
     - parks targeted cards at top y 438 (§5.2), and
     - turns a Battlecry drag release into Phase T, which needs `KeyTargeting` (Story 017).

     GDD States also lists no `Dragging → KeyTargeting` transition, and "any pair not listed is ignored".
   - Fix: §15 routes this only to the GDD owner "before MUI-008 readiness". Add the producer, because the story's AC has to change.
4. **A3 — `A` + number mapping is ambiguous** [ADVISORY]
   - What's wrong:
     - Key `n` → "board index n", while rules indices are 0-based (C1, C6). The AC "`A`, `2` … the attacker at board index 2" can be read either way.
     - Do the badges show slot positions, or count 1…k over legal attackers only?
     - `A` then `8` / `9` / `0`, or the index of a non-attacker: does the state stay armed or disarm?
   - Fix: define all three.
5. **A4 — A double-click can commit an untargeted play** [ADVISORY]
   - What's wrong: "a second click on the lifted source" confirms Phase C, so a double-click on a spell, weapon or hero power commits it. That weakens U5's "a mis-click costs nothing" for tremor users. A second `H` during a hero-power session is also undefined (confirm, re-select or ignore).
   - Fix: consider a minimum interval for the second click, or confirm on the cast zone only. Define `H`-in-session.
6. **A5 — Phase T after Phase P should filter targets by the chosen position** [ADVISORY]
   - What's wrong: §6 derives *targets* as the distinct `target_id`s across all entries. After a position is chosen, Phase T should offer only the entries with that `position`.
   - Fix: say so. No v1 selector seems position-dependent, but card-effects C3 has `adjacent` selectors.
7. **A6 — No 150 % text-scale fixture or AC** [ADVISORY]
   - What's wrong: accessibility-requirements says each spec "names its 150 % fixture". The rejection tooltip, the "No target" chip and the `A` badges scale. A 20x20 badge pill cannot hold a 21 px numeral.
   - Fix: add a `_ts150` reject capture and the badge size rule.
8. **A7 — Escape chain** [ADVISORY]
   - What's wrong: the `A`-armed state consumes `Esc` (§7.1, AC), but Escape / Cancel step (1) lists sessions only.
   - Fix: add the armed state to the pattern request in §15.
9. **A8 — No resolution criterion** [ADVISORY]
   - What's wrong: §14 has no 1280x720 / uniformly scaled fullscreen criterion (`hand.md` has one).
   - Fix: add one.

### GDD Alignment: ALIGNED (routed gaps)
- match-ui UI Requirements "Targeting arrow" and "Rejection tooltip": covered.
- match-rules UI Requirements "Legal targets", "Rejection reason": covered.
- C6 (Battlecry with no legal target → Phase P only): covered.
- C7: covered.
- C8 with **DD-X11**: no counter-damage forecast; the defending hero never hits back. Covered.
- card-effects C1 rule 1 `targeting_spec` (required / optional / none): covered.
- **Routed, non-blocking**:
  - **R1** — the two-phase minion play is a GDD gap. The design is coherent; record it in U5 / States.
  - **R2** — MUI-005's AC submits War's untargeted power on one click. GDD U5, `hud.md` §4.2 and the Hero Power Button pattern all require a confirm, and the spec follows them. The producer amends the MUI-005 AC (Ready) before implementation.
  - Cast and position zones into F6.
  - Target cycle order.
  - `optional` "No target" chip (no v1 content).
  - `rejection.detail` shape (match-rules owner).
  - New fixtures and poses.

### Accessibility: GAPS
- Target tier: Standard.
- A1 (keyboard-only completion for War), A6 (no 150 % fixture).
- Click-to-select gives every step as a discrete press, satisfying Hold-to-press alternatives.
- Shape-first colourblind cues: outline + ring + arrow, dashed slot vs dashed rect vs solid outline. `high_contrast_states` is handled. Contrast table OK.

### Pattern Library: CONSISTENT (minor)
- The spec references the patterns and does not re-specify them. Its additions are flagged in §15: ghost token, cast zone, `A` badges, extended cycle order, initial position = right-most gap.
- A7.

### Verdict: NEEDS REVISION
**Blocking issues**: 1 — must be resolved before implementation
**Advisory issues**: 8 — recommended but not blocking
**Dimensions not assessed**: 0

Address the 1 blocking issue above, then re-run `/ux-review`.

---

## UX Review: Mulligan
**Date**: 2026-11-04
**Reviewer**: ux-review skill
**Document**: `design/ux/mulligan.md`
**Checklist**: 3A (Template line)
**Platform Target**: PC, mouse primary / keyboard complete / gamepad Partial post-v1 / no touch
**Accessibility Tier**: Standard (+3 elevations), committed

### Completeness: 15/15 sections present
All required sections are present. Empty (n = 0), error (rejected), opening / closing and the setting variants are documented. There is no resolution criterion (A6).

### Quality Issues: 3 blocking, 6 advisory
1. **B1 — The v1-reachable 5-card row covers what the spec promises stays readable** [BLOCKING]
   - What's wrong: Bottomless Satchel is v1 content and gives n = 5. The row then spans x 29.5 + 249·i, so card 5 sits at x 1025.5–1250.5, y 202–517. It covers:
     - the lower 54 px of the boss portrait (F6 1136, 96, 120, 160);
     - essentially the whole **boss passive plate** (`hud.md`: the panel's lower 48 px, y 208–256);
     - the boss hand count (1136, 262, 60, 28);
     - End Turn (1116, 296).

     Card 1 (x 29.5–254.5) covers the player portrait (24, 334, 120, 160), the hero power and weapon slot (152, 390 / 446), and the top of the treasure tray (y 502–517). §2, §5.2, §5.4 item 5 and §6 all promise that the passive plate, the hand count "4" and the tray stay readable while the player decides. The `mulligan_satchel` AC asserts "nothing clipped".
   - Where: §5.1 hand-size table (n = 5 row), §5.2, §14 Layout AC 2 and 4.
   - Fix: keep the row inside the clear band between the portrait columns (≈ x 152–1128) for n = 4–5. For example, cards at 1.2x (180x252, 14.4 px text) with 16 px gaps put n = 5 at x 158–1122, y 202–454; Card Inspect covers full text as it already does for n ≥ 6. Then restate which base elements are covered, and add an AC that the passive plate and hand count are unobstructed at n = 5.
2. **B2 — The header collides at `text_scale` 125 / 150 %** [BLOCKING]
   - What's wrong: the header positions are fixed for every scale: title top y 124 (28 → 35 / 42 px), sub-line top y 164, card row top y 202.
     - At 150 % the title's line box (≈ 50 px) reaches ≈ y 174, over the sub-line.
     - §6 and §13 say the sub-line "wraps to 2 lines at 18 px line height" — impossible for 24 px glyphs. Two real lines need ≈ 58 px, which ends at ≈ y 222, past the row top.
     - At 125 % it also fails: the title just touches the sub-line, and two 20 px lines end at ≈ y 212.

     The `mulligan_ts150` AC ("≤ 2 lines, above y 202 … no clipping or overlap") and the pseudo-locale AC cannot be met from the spec's numbers. Text scaling is a committed Standard-tier feature.
   - Where: §5.1 table (title / sub-line y), §5.2 Sub-line, §6 `text_scale` row, §13 Sub-line row, §14 Layout AC 5, Localization AC 2.
   - Fix: give the 125 / 150 % header positions and line heights (for example, raise the header toward the n ≥ 6 positions, then re-check against the ticker rect 24, 48, 400, 42), or cap the header's scale. Re-derive the 2-line and 14 px fallback budget at each scale.
3. **B3 — Showing printed cost contradicts match-rules F1** [BLOCKING]
   - What's wrong: §8 shows printed cost because "no aura or hook has run on hand cards before `match_started`". But `modify_cost` hooks are value folds inside F1 (`hook_delta`, applied at every evaluation), not events that "run". They are installed with the `MatchConfig` hook installers before the deal (C3 steps 1 and 4). Four v1 treasures discount opening-hand cards during the mulligan:
     - Quartermaster's Ledger (5+ costs 1 less)
     - Dog-eared Grimoire (spells)
     - Rotting Bargain (Deathrattle minions)
     - Vanguard's Banner (`cards_played_this_turn == 0` is true here)

     The screen would show a 5 that becomes a 4 in the fan — the "hidden cost change" `hand.md` §2 names as a player fear — and on the decision the screen exists for ("send back expensive cards"). `MatchQuery.hand(side)` returns `effective_cost` with no phase restriction (match-ui U2).
   - Where: §8 "Effective cost" row, §15 "Printed vs effective cost".
   - Fix: read `hand(player)` when the overlay opens and render `hand.md`'s modified-cost stamp, with "Printed cost n" in Card Inspect. Route only the remaining confirmation (that `hand()` answers in phase `Mulligan`) to the owners.
4. **A1 — The Replace drop overlaps the pill** [ADVISORY]
   - What's wrong: the card bottom is at y 517 and the pills start at y 525. A 12 px drop takes the card to y 529, 4 px over the pill. In the n ≥ 6 rows (bottom 346, pill 352) the overlap is 6 px.
   - Fix: state the z-order, or reduce the drop / widen the gap.
5. **A2 — "One press" claim and Enter on open** [ADVISORY]
   - What's wrong: §1 and §6 say keep-all is "one press". The keyboard path is `Tab` ×n then `Enter` (n + 1 presses; the AC says four). Focus opens on card 1 (pattern rule), so a reflexive `Enter` replaces card 1.
   - Fix: correct the claim. Note the risk against the Focus Management rule; changing it belongs to the pattern owner.
6. **A3 — `Left` / `Right` are new match keys, unflagged** [ADVISORY]
   - What's wrong: §7.1 uses them, but Standard Shortcuts has no such row, and only the `1`–`9`, `0` extension is in §15.
   - Fix: add a §15 row.
7. **A4 — n = 4 and n ≥ 6 variants** [ADVISORY]
   - What's wrong: at n = 4, card 1 (x 154) covers the hero power / weapon slot (152–200) and 6 px of tray chip 3. At n ≥ 6, the header (y 60 / 100) against the row (y 136) has B2's problem. These are not v1-reachable, so they are advisory. They are covered if B1 / B2 are fixed by a rule rather than per-row numbers.
8. **A5 — Rejected-mask copy** [ADVISORY]
   - What's wrong: `INVALID_MASK` reuses "That choice is no longer available." That works for a race but reads oddly on a toggle screen.
   - Fix: optional mulligan-specific copy.
9. **A6 — No resolution criterion** [ADVISORY]
   - Fix: add 1280x720 plus a uniformly scaled fullscreen criterion.

### GDD Alignment: GAPS FOUND (B3 is the spec's; the rest routed)
- match-ui U8, F6 row 278, 202, 723, 315, O6, U5 / O19 (`Esc` → pause over the overlay): covered.
- match-rules C2 (`INVALID_MASK`, mask length), C3 steps 5–8 incl. **DD-X13** (no `on_draw` flare during the redraw; AC present), DD-M03, DD-M05, C14 (concede in `Mulligan`): covered.
- match-rules F1: contradicted (B3).
- **Routed, non-blocking**:
  - The opening hand is not always 3 (U8, F6, MUI-009).
  - Number keys beyond 3.
  - Refined replace overlay.
  - Double-click exclusion.
  - Portraits undimmed (vs `hud.md` §5 "rows dimmed") — art-director + pattern.
  - Test-data fixtures vs U11's "real engine".
  - MUI-009 citation.

  The deadlines say "before MUI-009 readiness", but MUI-009 is already Ready. Its "3 cards / 8 subsets" AC must be amended before implementation.

### Accessibility: GAPS
- Target tier: Standard.
- B2 (text scale), B1 (context the spec relies on for cognitive load is hidden at n = 5).
- Keep vs replace has five non-colour cues. No timer. Focus is trapped. Contrast table OK.

### Pattern Library: INCONSISTENCIES FOUND
- A3 (unflagged keys).
- Other deviations are flagged correctly: overlay refinement, double-click, `1`–`9`, `0`, base-dim reading.

### Verdict: NEEDS REVISION
**Blocking issues**: 3 — must be resolved before implementation
**Advisory issues**: 6 — recommended but not blocking
**Dimensions not assessed**: 0

Address the 3 blocking issues above, then re-run `/ux-review`.

---

## UX Review: Match End
**Date**: 2026-11-04
**Reviewer**: ux-review skill
**Document**: `design/ux/match-end.md`
**Checklist**: 3A (Template line)
**Platform Target**: PC, mouse primary / keyboard complete / gamepad Partial post-v1 / no touch
**Accessibility Tier**: Standard (+3 elevations), committed

### Completeness: 15/15 sections present
All required sections are present. The absence of empty, loading and error states is justified explicitly: the fault is a designed variant. The auto-advance has a duration (4 s) and a visible countdown. There is no resolution criterion (A5).

### Quality Issues: 2 blocking, 5 advisory
1. **B1 — Input lock and overlay closure keyed to *projection*, not to `Ended`** [BLOCKING]
   - What's wrong: §4 (entry row) and §6 (Draining) lock all input except skip and close open overlays — pause, concede confirm, Mulligan, Choice — when `match_ended` is *projected*. Two GDD rules make that moment early:
     - U3.1: events are applied on receipt.
     - U6: the boss turn is already in the log at `turn_started{boss}`.

     So in a lethal boss turn, `result` is set **before its playback starts**. For up to `max_turn_playback_s` (10 s), pause is unreachable and an open pause menu snaps shut. That gives the outcome away before the board shows it.

     This contradicts:
     - match-ui States ("any state **except `Ended`** → Menu and back"),
     - `hud.md` (APPROVED) Menu row ("underlying playback keeps running"),
     - accessibility-requirements Cognitive "Pause anywhere … including during boss playback" (Basic).

     The source is the GDD edge-case line "Input is locked from the moment `result` is set", which was written about dragging. The spec generalises it to closing overlays and blocking pause.
   - Where: §4 Entry table row 1, §6 Draining, §7.3 Draining row.
   - Fix: keep cancelling an open targeting session at once (the GDD's drag case). Leave pause, the feed and the Menu reachable while draining; commands already reject `MATCH_ENDED`. Close the overlays and lock input when the queue reaches the `match_ended` step or the view enters `Ended`. A confirmed concede stays immediate. Route the edge-case wording to the Match UI GDD owner.
2. **B2 — No 150 % layout; the 100 % row tops overlap** [BLOCKING]
   - What's wrong:
     - Only sizes are given for 150 % (headline 42 px, lines 24 px). Row tops stay at 276 / 318 / 346 / 400 (§5.1). The headline's line box (≈ 50 px) reaches ≈ y 326, over the reason line at 318.
     - A reason that wraps at 24 px in the 568 px width — the `turn_cap` copy (50 chars), or "You conceded to {boss}." with a 32-char boss name — adds ≈ 29 px and no longer fits the 200 px banner.
     - The rationale for growing only the fault banner ("four text rows") contradicts §5.1, where every variant has three text rows plus Continue.

     As written, `match_end_victory_ts150` "no clipping" cannot be met.
   - Where: §5.1, §5.2 End banner overflow, §6 `text_scale` row, §12 "`text_scale` 150 %", §14 Layout AC 5.
   - Fix: give the 125 / 150 % row tops (or a stack rule with fixed gaps). Derive the banner growth per variant, including 2-line reasons and the +40 % pseudo-locale.
3. **A1 — The 300 ms arm guard (author flag)** [ADVISORY]
   - (a) It reuses `end_turn_arm_ms`, so End Turn's safe range (150–600) and rationale now also tune the banner. Prefer the §15 option of a separate `MATCH_END_ARM_MS` knob.
   - (b) 300 ms guarantees the banner *renders*, not that it is *read* (§2 fear "unread"; AC "never skipped unrendered"). That is acceptable only because the next screen restates the result. Say so in §12 rather than implying the guard prevents an unread skip.
   - (c) A deliberate click *on Continue* inside the window is swallowed with no feedback. End Turn's precedent is "a click on the button is never gated". Either exempt clicks inside the Continue rect, or draw Continue as Disabled until armed.
   - (d) State key-repeat handling (`is_echo()`). A held `Space` from the boss turn reaches the banner through echo events at +300 ms, the same as the 100 ms-mash AC.
4. **A2 — Concede during the mulligan** [ADVISORY]
   - What's wrong: the facts line would read "Turn 0 · You 30 health · {boss} 30".
   - Fix: specify what shows at `turns = 0` (omit the facts line, or a concede-specific line).
5. **A3 — Feed drawer inert in `Ended`** [ADVISORY — correctly routed]
   - What's wrong: the drawer is the only way to read *why* the match was lost. §15 proposes allowing it and pausing the timer. Listed because it interacts with A1 (b).
6. **A4 — Wireframe** [ADVISORY]
   - What's wrong: the y labels are out of order (row 334 printed after 346). Cosmetic.
7. **A5 — No resolution criterion** [ADVISORY]
   - Fix: add 1280x720 plus a uniformly scaled fullscreen criterion.

### GDD Alignment: ALIGNED (routed gaps)
- match-ui U9 (variants, the fault copy and the "no stinger / no saturation / still auto-advances" rule, `MATCH_END_AUTO_S`, exactly-once `match_view_finished`, never navigates), U5 / DD-X09 (`Esc` and the menu button do nothing), U4.5 (skip during the banner), F3, F6 rect, O13, O19, UI Requirements "Match end overlay": covered.
- match-rules C14 (`hero_dead` / `both_dead` / `concede` / `turn_cap`, faults `resolution_overflow` / `event_cap`, `MatchResult` fields): covered. DD-M12 tie copy covered.
- B1 conflicts with match-ui States.
- **Routed, non-blocking**:
  - `turn_cap` copy and fixture gap.
  - Boss-panel "saturation" reading of O13 (art-director).
  - Countdown label.
  - Facts and fault-detail lines.
  - `MATCH_END_AUTO_S` outside `SPEED_DIV`.
  - Concede stinger.
  - MUI-011 citation. MUI-011 is already Ready; its AC does not contradict the arm guard.

### Accessibility: GAPS
- Target tier: Standard.
- B1 (Pause anywhere), B2 (text scale).
- Reading time is justified against the Cognitive row. The flash budget is respected (one 400 ms ramp; one text change per second). Every variant has non-colour cues. Contrast table OK.

### Pattern Library: CONSISTENT
- Overlay row "Match-end banner", Escape / Cancel step (4a), Button (Primary) and the Error State rule are all followed. The countdown is flagged as new.

### Verdict: NEEDS REVISION
**Blocking issues**: 2 — must be resolved before implementation
**Advisory issues**: 5 — recommended but not blocking
**Dimensions not assessed**: 0

Address the 2 blocking issues above, then re-run `/ux-review`.

---

## Cross-spec notes for the producer (advisory)
- All the consuming stories (MUI-005, 006, 008, 009, 011, 016, 017, 018) are already `Status: Ready`. The specs' §15 deadlines of "before story readiness" have therefore passed. Re-target them to "before `/dev-story`". The story ACs that conflict with the specs are:
  - MUI-005: one-click untargeted hero power.
  - MUI-008: targeted card follows the cursor; no Phase P → T.
  - MUI-009: 3 cards, `1`–`3`, "8 subsets".
- After revision, the specs should be cited in the stories in place of `hud.md` (each spec's §15 already says so).
