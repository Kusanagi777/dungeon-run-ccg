# Story 025: Hero power by drag — an untargeted Ready hero power is dragged to the cast zone (Phase C)

> **Epic**: Match UI
> **Status**: In Review
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: 2026-11-04
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

Sprint 6 Goal Prerequisites row 11. War's only hero power, Whetstone (`power_whetstone`, cost 2), is untargeted. MUI-005 AC-4 makes a single click on the button select it but never play it, and says the confirm "is Story 017's `KeyTargeting` session". MUI-017 depends on MUI-008 and MUI-012, while MUI-012 AC-1 plays the hero power "through `InputRouter` mouse intents". As written, nothing the first playable can use plays Whetstone with the mouse.

What the mouse path needs, from the specs:

- `design/ux/targeting.md` §3 lists the hero power as picked up by "press + move / click on the button". §6 gives an untargeted power Phase C ("confirm on the button itself or the cast zone"). The click route (select, then a second click on the button or in the cast zone) is `KeyTargeting` with `entered_by = pointer`, which MUI-017 builds. The **drag route** is §7.4's drag-release table, Phase C: release inside the cast zone confirms, anywhere else cancels. It needs only the `Dragging` state.
- match-ui States: `Dragging` is entered by "press-and-move on a playable card or legal attacker / hero power". `Dragging` and the cast zone (301, 176, 678, 284) are built by MUI-008. Its AC-1 covers an untargeted spell or weapon, its AC-2 a **targeted** hero power; the untargeted hero power is in neither.

So one small slice closes it without touching `KeyTargeting`: let the untargeted `Ready` hero power be a drag source for Phase C. It lands after MUI-008 and before MUI-012, and no existing story needs to be rewritten (the dependency changes MUI-012 needs are listed below).

**DD-X34 (owner, 2026-11-05):** drag-only hero power is accepted for playtest #1, and click-to-select follows with MUI-017 after First Playable. A single click on the button does nothing until MUI-017: it plays nothing and builds no command, and this drag is the only way to cast Whetstone.

**GDD**: `design/gdd/match-ui.md` U5 (Hero power, Drag), States and Transitions (`Dragging`), U7 · UX: `design/ux/targeting.md` §3, §5.1 D, §6 (source → phases), §7.4 (drag release, Phase C), §11; `design/ux/hud.md` §4.2 Hero power button · `design/design-decisions.md` DD-X34
**Requirement**: `TR-match-ui-005` (latency: pickup 16 ms, drag 16 ms, release to first event 50 ms), `TR-match-ui-001`; `TR-design-decisions-003` (mouse primary)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`InputRouter` turns mouse input into intents and commands; legality read from `legal_commands()` on pickup only); ADR-0001 (only `submit`)
**ADR Decision Summary**: `InputRouter` is the only producer of `command_requested`; any (state, input) pair not listed is ignored, never forwarded; the engine is not called on cancel.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH (UI 4.5–4.7)
**Engine Notes**: Mouse events by type (`InputEventMouseButton`, `InputEventMouseMotion`), never `event.device == 0`. Line and outline widths explicit (ADR-0010 rule 6). `--headless --write-movie` crashes: capture through `tools/capture.sh` only.

**Control Manifest Rules (Presentation layer, v2026-11-04)**:
- Required: mouse and keyboard identified by event type; every threshold from `config("match_ui")` (`CLICK_DRAG_PX` 8); fixtures reach every captured state through the real engine.
- Forbidden: forwarding an unlisted (state, input) pair to `submit`; hand-built view-states in fixtures; `.submit(` outside the controller path.
- Guardrail: pickup and drag ≤ 16 ms, release to first event ≤ 50 ms.

---

## Acceptance Criteria

*From match-ui States (`Dragging`), U5 and `design/ux/targeting.md` §6 / §7.4, scoped to this story:*

- [ ] GIVEN `Idle`, `hero_power_state(player)` `Ready` and a `use_hero_power(null)` entry in `legal_commands()`, WHEN the button is pressed and moved more than `CLICK_DRAG_PX` (8), THEN the view enters `Dragging` for the hero power within one frame: the button shows lifted (look per open question 1), the cast zone 301, 176, 678, 284 draws its dashed 2 px `state_actionable` outline, no arrow is drawn, and End Turn is disabled.
- [ ] GIVEN that `Dragging`, WHEN the button is released inside the cast zone (including over a friendly token that can attack), THEN exactly one `use_hero_power` with `target_id = null` is submitted and the first visual step starts ≤ 50 ms later; WHEN it is released anywhere else, or RMB or `Esc` is pressed, THEN nothing is submitted and no event appears; and a press-and-release moving under 8 px still submits nothing (MUI-005 AC-4 is unchanged; DD-X34: a single click does nothing until MUI-017).
- [ ] GIVEN the hero power `Blocked`, `Used`, or with no `use_hero_power` entry, or any phase but `PlayerTurn.Main` with an idle queue, WHEN the button is pressed and moved, THEN no `Dragging` begins, no outline appears and no command is built; and WHEN the scripted player of MUI-012 drives `drag_start(hero_power)`, `drag_move`, `drag_release(cast zone)` through `InputRouter` intents on the `first_playable` fixture, THEN one `use_hero_power` is accepted and `hero_power_used` reaches the view.
- [ ] GIVEN a fixture where Whetstone is `Ready` (turn 2 or later with 2 mana: `turn1_player` has 1 mana and shows it `Blocked`), WHEN a hero-power drag is captured, THEN the retained frame shows the cast zone lit and the button in its dragged look, and the owner's sign-off is on file (UI gate, BLOCKING).

---

## Implementation Notes

*Derived from ADR-0009 and `design/ux/targeting.md` §6–§7.4:*

- Extend `InputRouter`'s `drag_start` with a `hero_power` source and give Phase C a source-agnostic release test: the card path MUI-008 builds (`Dragging — card, Phase C`) already shows the cast zone and submits on a release inside it. Reuse that code; the new input is the source, not a new zone or state.
- Derive the phase from `legal_commands()` as §6 says: only an entry `use_hero_power(null)` and no targeted entry means Phase C. A targeted power is MUI-008 AC-2 and is not changed.
- **Not here** (MUI-017's): `KeyTargeting`, the click-then-click or click-then-zone confirm, `Enter`, the `H` key, the double-click guard and the §7.4 click table. When MUI-017 lands, its Phase C rules for the hero power sit on this cast zone with no change to this story.
- Pose for the capture: MUI-008 defines `--pose=drag:<id>` for attackers and cards. A hero-power pose name is not defined anywhere (open question 2); until MUI-022 fixes the pose list, use the name the dev picks and record it in the evidence README.
- Fixture: one where the power is `Ready`. `midgame_full_board` (MUI-007) or `first_playable` advanced past turn 1; pick at readiness from what has merged. Do not hand-build a view-state.
- **Playtest #1 (DD-X34):** until MUI-017 lands, after MUI-012, the player cannot click Whetstone twice to cast it. The owner accepted this for playtest #1; the report records it as a known limit.

**Open design questions — flagged, not decided (ux-designer / Match UI GDD owner):**

1. **The dragged button's look in Phase C.** `targeting.md` §6 states "button lifted 2 px in place" for a hero power in Phase T and a card following the cursor in Phase C, but has no row for a hero power dragged in Phase C. Does the button stay lifted in place (as in Phase T) or follow the cursor? Answer before `/dev-story`; AC-1 and AC-4 wait on it.
2. **Pose name and fixture** for the evidence frame (see above): MUI-022 owns the pose list.
3. **MUI-005's selected-source lift.** MUI-005's "lifts 2 px as the selected source" names a selected-source state that nothing builds before MUI-017; how MUI-005 shows the lift without `KeyTargeting` is its readiness question, and is not answered here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- `production/epics/match-ui/story-017-click-to-select-and-keyboard-targeting.md`: the click and keyboard confirm of the hero power (`KeyTargeting`, `H`, `Enter`, the double-click guard).
- `production/epics/match-ui/story-008-drag-to-play-attack-and-targeting-arrow.md`: the `Dragging` state, the cast zone, the arrow, targeted hero powers.
- `production/epics/match-ui/story-005-hero-panels-mana-and-end-turn.md`: the button, its states and the Blocked tooltip.
- `production/epics/match-ui/story-016-rejection-feedback.md`: a rejected `use_hero_power` (a race) beyond returning to `Idle`.

---

## Files

- `src/ui/match/input_router.gd` (a `hero_power` drag source)
- `src/ui/match/hero_presenter.gd` (the dragged look, only as far as AC-1 needs)
- `src/ui/match/match_debug_loader.gd` (the pose, if the dev adds one; one editor per wave: MUI-008 holds `drag:` there)
- `tests/unit/match_ui/input_router_test.gd` (hero-power cases; the file MUI-017 extends)
- `tests/integration/match_ui/hero_power_drag_test.gd` (the scripted drag on `first_playable`)
- `production/qa/evidence/story-025-hero-power-drag-to-cast-zone/` (frame, README, sign-off)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above (QL-STORY-READY skipped — Lean mode).*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: a retained screenshot of the hero-power drag in `production/qa/evidence/story-025-hero-power-drag-to-cast-zone/` via `tools/capture.sh`, its `README.md` (command, renderer line, what was checked by eye) and the owner's sign-off
- Also: `tests/integration/match_ui/hero_power_drag_test.gd` passes; `tests/unit/match_ui/input_router_test.gd` hero-power cases pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-005-hero-panels-mana-and-end-turn.md` (the button and `hero_power_state`), `production/epics/match-ui/story-008-drag-to-play-attack-and-targeting-arrow.md` (the `Dragging` state and the cast zone); `production/epics/card-effects/story-011-hero-powers.md` and `production/epics/heroes/story-001-war-hero-seated-from-herodef.md` (Whetstone and War, done)
- Unlocks: `production/epics/match-ui/story-012-first-playable-windows-match.md` (AC-1 plays the hero power by mouse intents)
- **What existing stories must change:**
  - `production/epics/match-ui/story-012-first-playable-windows-match.md`: this story is added to "Depends on" (done 2026-11-05). Without it, AC-1's hero power has no mouse path. Nothing else in 012 changes.
  - `production/epics/match-ui/story-008-drag-to-play-attack-and-targeting-arrow.md`: add this story to "Unlocks" (a note only). Not edited yet; do it at readiness.
  - `production/epics/match-ui/story-005-hero-panels-mana-and-end-turn.md` and `production/epics/match-ui/story-017-click-to-select-and-keyboard-targeting.md`: no dependency change. MUI-005's "that confirm path is Story 017's" stays true for the click route.
  - `production/sprints/sprint-006.md`: Must Have gains this story (row 11 fix (b), done 2026-11-05); it is not MUI-017, which stays out.
- **Sprint 6 placement**: lane 1, W3, after MUI-008 and before MUI-012, merged with them at M3. It needs MUI-008's `Dragging`, which merges at M3 in the same lane, so no other lane or wave can take it, and it adds no merge point. It adds about 0.5 link, so L1 goes from 6.5 to 7.0, the measured ceiling, on the chain that sets the date (decision point at M3). It adds one UI sign-off (≈ 0.25 to 0.5 h) to the W3 stack of 3.75 h, against a 0.75 h reserve. Not [S] or [C].
