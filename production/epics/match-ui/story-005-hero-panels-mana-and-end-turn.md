# Story 005: Hero panels, mana bar, deck piles, top bar, hero power and End Turn

> **Epic**: Match UI
> **Status**: In Review
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: L
> **Manifest Version**: 2026-11-03
> **Last Updated**: [set by /dev-story when implementation begins]

## Context

**GDD**: `design/gdd/match-ui.md` U3 rows (`damage_dealt`, `healed`, `armor_*`, `weapon_*`, `hero_power_used/refreshed`, `crystal_gained`, `mana_*`, `card_drawn`), U5 (Hero power, End Turn), F6 (portrait, hero power, weapon, mana bar, deck piles, top bar, End Turn, boss strip), UI Requirements · UX: `design/ux/hud.md` §3.2, §4.1–4.2, §5 `Idle`; `design/ux/interaction-patterns.md` End Turn Button, Hero Power Button, Hero Portrait & Health Stamp, Mana Bar, Floating Number
**Requirement**: `TR-match-ui-001`, `TR-design-decisions-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (`hero_panel.tscn` ×2 — `HeroPresenter` owns portrait, health / armour, weapon slot, mana bar, hero-power button, deck count, fatigue label; number pops are children spawned per step); ADR-0001 (numbers from events)
**ADR Decision Summary**: Presenters draw one zone from `MatchViewState`, tween on `step_started`, and are authoritative only at `apply_final`; number pops are presenter children freed after `apply_final`.
**ADR Version**: 2026-11-03

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: `create_tween()` on the presenter (4.0, LOW); tweens killed on `skipped` and `apply_final`. `queue_free` only for pop children after `apply_final`. Line / outline widths explicit (4.7: no antialiasing feather).

**Control Manifest Rules (this layer)**:
- Required: Presenters subscribe to `step_started`, check `owns(entity_ids)`, tween, kill tweens on `skipped` / `apply_final`. `sync_report()` compares every displayed field.
- Forbidden: Never let presenters poll `MatchQuery` to render numbers. A presenter never stores a value the view-state does not have.
- Guardrail: `MatchQuery` only on hover (hero power tooltip).

---

## Acceptance Criteria

*From match-ui O3 (zones part), U5, U3 and hud.md §12 Layout & Visibility:*

- [ ] GIVEN `--fixture=turn1_player`, WHEN captured, THEN both portraits (120x160 at 24,334 and 1136,96), health and armour stamps, hero power 152,390 and weapon slot 152,446, the two-row mana bar 1060,652,196,56, deck piles 24,96 and 1180,540, the boss hand count 1136,262,60,28 and compact mana counter 1196,262,60,28, the top bar 0,0,1280,40 reading "Your turn · 1", and End Turn 1116,296,140,44 sit at their F6 rects ±2 px with no overlap.
- [ ] GIVEN `damage_dealt`, `healed`, `armor_gained` / `armor_lost` and `weapon_*` events on a hero, WHEN their steps play at `normal` and when skipped, THEN the pop shows `−dealt` / `+n`, `dealt = 0` with `prevented > 0` and `healed{amount: 0}` produce no pop, and after `apply_final` the displayed numbers equal the view-state (`sync_report()` empty).
- [ ] GIVEN `phase == PlayerTurn.Main` and an idle queue, WHEN End Turn is clicked, THEN exactly one `end_turn` is submitted (a click is never gated by `end_turn_arm_ms`); GIVEN `Playback`, `BossTurn`, `ChoiceOpen` or `Mulligan`, THEN End Turn is disabled and a click reaches no `submit`; GIVEN no legal play but `end_turn` or no mana left, THEN it carries the `state_actionable` outline.
- [ ] GIVEN `hero_power_state(player)` `Ready` for War's Whetstone (untargeted), WHEN the button is clicked **once**, THEN **no** `use_hero_power` is submitted: a single click never plays (match-ui U5 click-to-select; `hud.md` §4.2 "untargeted still need the confirm press"; Hero Power Button "after confirm"). The button lifts 2 px as the selected source. The confirm (a second click on the button outside an OS double-click, a click in the cast zone, or `Enter`) submits exactly one `use_hero_power(null)`; that confirm path is Story 017's `KeyTargeting` session (`design/ux/targeting.md` §7.4 rank 2, §14). On `hero_power_used` the button dims to `Used`; `Blocked` shows its `reason_code` tooltip on hover. *(amended 2026-11-04 to match design/ux/targeting.md, ux-review round 1)*

---

## Implementation Notes

*Derived from ADR-0009 Implementation Guidelines:*

- `src/ui/match/hero_presenter.gd` on `hero_panel.tscn`, instanced twice (`side` export). The boss instance hides hero power / weapon if `hero_power` is null (Torchbearer has none) and shows the hand count from the view-state count.
- Top bar text from `MatchConfig` (floor, boss name via `card_text`) and `turn_started`; all strings are `tr()` keys.
- End Turn enable rule lives in `InputRouter` (`phase == PlayerTurn.Main` and `queue.is_idle()` and no overlay); the button only reflects it. Keyboard arming (`end_turn_arm_ms`) is Story 017.
- Targeted hero powers start the arrow — Story 008. Hero-power tooltip on keyboard focus — Story 018.
- Number pops: `damage_pop` / `heal_pop` `d_base` 0.4 from config; impact extras are Story 023.
- Captures: `CAPTURE_LABEL=01-turn1_player bash tools/capture.sh res://src/ui/match/match_view.tscn production/qa/evidence/story-005-hero-panels-mana-and-end-turn 60 -- --fixture=turn1_player --anim-speed=instant`; a second frame from a fixture after a hero hit if one exists by then (else `midgame_full_board`, Story 007).

---

## Out of Scope

- Story 014: the fatigue label copy and burn flash checks (O11) beyond rendering `fatigue_next`.
- Story 015: boss intent banner (anchored on the boss panel).
- Story 021: treasure tray.

---

## Files

- `src/ui/match/hero_panel.tscn`, `src/ui/match/hero_presenter.gd`
- `src/ui/match/number_pop.tscn`
- `src/ui/match/input_router.gd` (End Turn / hero-power intents)
- `tests/integration/match_ui/hero_presenter_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: retained screenshots in `production/qa/evidence/story-005-hero-panels-mana-and-end-turn/` captured via `tools/capture.sh` (Compatibility/llvmpipe; Windows confirmation row advisory, ADR-0010)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/match-ui/story-004-match-view-skeleton-and-fixture-loader.md`; `production/epics/card-effects/story-011-hero-powers.md` (Whetstone); `production/epics/match-rules/story-010-play-card-and-hero-power.md`
- Unlocks: `production/epics/match-ui/story-008-drag-to-play-attack-and-targeting-arrow.md`, `production/epics/match-ui/story-011-match-end-banner-and-handoff.md`, `production/epics/match-ui/story-015-boss-intent-banner-and-boss-turn-view.md`
