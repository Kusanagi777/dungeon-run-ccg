# Match UI

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
> **Author**: Jacob (owner) + Claude (`/design-system match-ui`, tier standard, guided, lean)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **REVISED 2026-11-03** (`/design-review`, lean, verdict NEEDS REVISION → revised in place, status In Review): (1) F1 hand arc inverted — with a bottom-centre pivot, `HAND_BASE_Y` 716 and a 24-px downward dip the outer cards sat at y 740 and their rotated attack stamps were off the 720-px viewport, so O1 was unsatisfiable; `HAND_BASE_Y` is now 696, the centre card rises `ARC_H`, the hand zone is 240, 462, 800, 258 and F2's preview top is y 381; (2) the match-end hand-off is confirmed as Run UI's sibling contract (`match_view_finished(result)` → Run UI, which run-ui.md names) — run-structure.md never names this system, so its row is now indirect (`MatchConfig`, the match driver); (3) treasure tray added (F6 zone, inventory row, `treasure_tray` fixture, `healed{amount: 0}` suppressed) — treasures.md is Designed and places the tray on the match screen; stale "undesigned" / "in progress" wording removed; (4) C15 events this GDD does not draw (`turn_reset`, `card_to_graveyard`) are a declared silent set, not `feed.unknown` lines; (5) `reduce_motion` setting defined (`ui-code.md` rule 4) — shake, hit-stop and lethal slow-down drop; (6) `match_ui.json` is already in DD-T01 and loads through Card Database `config("match_ui")`; (7) U12 cross-reference F7 → F6; Open Questions updated with the cross-GDD items the review found (`intent_banner_s` 1.2 vs 0.3, run-ui's `anim_speed` labels and action-delay slider, `telegraph_mode`, `ui-code.md` gamepad / text-scale deferrals).
> **REVISED 2026-11-03 (cross-review)**: C-01 (`anim_speed` is the DD-X07 label set `instant | fast | normal` with a `SPEED_DIV` table in F3; F4 consumes Meta's `action_delay_ms`; `reduce_motion` and `text_scale` are read from Meta; telegraph rendering follows Boss AI's `effective_mode`, DD-X03), C-07 (the four losing event aliases deleted, the five 2026-11-03 primitive events placed in U3 — DD-X04), S-04 (`fault` end banner copy "floor replayed, not lost", no defeat sting), C-30 housekeeping (`intent_banner_s` OQ, Cross-References status words). Accessibility / pattern-library resolutions (`design/accessibility-requirements.md`, `design/ux/interaction-patterns.md` Open Questions) folded into U5, States, F6, U11, Tuning Knobs and AC: click-to-select mouse path, `end_turn_arm_ms` 300 ms, `Esc` never cancels Mulligan/Choice, `Tab` focus cycling in `Idle` with a 2 px focus ring, 44x44 treasure-chip hit area, hero power `Blocked` reason on focus.
> **REVISED 2026-11-03 (re-review, `/design-review` lean, independent reviewer — blocking items fixed in place)**: (1) F6 mana bar `1000, 676, 256, 32` sat inside the hand zone — for every n ≥ 6 the right-most card (x 890–1040, rotated edge to x 1048 at y 676) covered its first crystals, and the outer cards' rotated top corners reach x 188 / 1092, so O1's "within x 240–1040", O3's "no overlap" and F1's "nothing is clipped" were false by the document's own numbers; the mana bar is now a two-row `1060, 652, 196, 56`, the deck pile `1180, 540, 76, 106`, the tray holds the three v1 slots (`MAX_TREASURES_HELD`, treasures.md; a fourth slot would sit under card 0's corner), `HAND_W` safe range 700–800, F1 states the rotated envelope and O1 tests it; (2) rng-event-log rule 12a's `diagnostic: true` events (`ai_decision`, `ai_plan_aborted`, `ai_fault`) and card-effects' `counter_changed` were in neither the U3 table nor the silent set, so rule 4 would have printed `feed.unknown` lines every boss turn in release — U3.4a filters diagnostics (player `command_rejected` keeps its tooltip **and** gains a `feed.command_rejected` line, accessibility-requirements "Reading time"), `counter_changed` projects to `counters{}` with a feed line and no badge (card-effects Gaps), L9/L18 test it, `--ai-debug` documented in U11; (3) L15 assumed `Space` ends the turn while U5 gives `Idle` focus to the left-most playable card (where `Space` is not End Turn) — precondition added. Also aligned: U5 idle focus order to interaction-patterns Focus Management (the owner it names), `reduce_motion` in the pause-menu row and O15, O17 defined as state equality plus a retained pose pair, Open Questions (accessibility tier → `design/accessibility-requirements.md`; Meta Progression is Designed).
> **REVISED 2026-11-03 (ux-review)**: (1) F6 boss strip `1136, 262, 120, 28` split side by side — hand count `1136, 262, 60, 28`, boss compact mana counter `1196, 262, 60, 28` (hud.md §4.2 proposal accepted); (2) Visual/Audio + States: the player hand dims to 60 % (`table_dark`, art bible §2) for the whole `BossTurn` state; (3) U3 projection row for `trigger_resolved{once_per_turn: true, exhausted: true}` → dimmed once-per-turn trigger icon on the source card; (4) U5 / U9 / States / Edge Cases / O19: `Esc` on the match-end banner does nothing and the pause menu is unreachable in `Ended` (DD-X09) — the former fall-through to "open the pause menu" removed; (5) U11 fixtures: `boss_intent_hidden` added, `match_end_fault` confirmed, `*_ts150` (`text_scale` 1.5) variants of the hud fixtures; (6) Interactions / Dependencies Meta row: `gamma` read setting applied via `CanvasModulate` (DD-X10).
> **REVISED 2026-11-03 (housekeeping)**: Interactions Run UI row — settings are read from Meta Progression (DD-X07), not handed over by Run UI as "current settings values".
> **Implements Pillar**: Pillar 4 (readable, deterministic rules — the UI is a projection of the event log); Pillar 3 (lose fast, learn fast — every loss is legible on screen); Sensation aesthetic (crisp card feedback)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` No `Agent` tool in this run: `game-designer`, `ux-designer`, `ui-programmer`, `art-director`, `systems-designer` and `qa-lead` not consulted — Lean mode. Review manually before production.
> **Scope boundary**: this GDD defines the Match UI as a *system* — what it must do, its architecture and its contracts with the rules engine. Per-screen UX specs (pixel layout, copy, focus order) are produced later by `/ux-design` into `design/ux/` and cite this document.

## Summary

The Match UI is the screen the player plays a match on: hand, board, heroes, mana, targeting
arrow, boss intent, mulligan, Discover overlay, event feed and the end banner. It is a pure
projection of the event log that sends commands to the rules engine and never owns game state,
and it plays what happened as a short, skippable, speed-adjustable queue of animations so the
rules stay readable (Pillar 4) and boss turns stay brisk (Pillar 3). It also defines the
launch-argument fixtures that let every screen be screenshotted unattended for QA evidence.

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `Match Rules, Card Effects, Boss AI, Card Database, RNG & Event Log`

## Overview

The Match UI is the Godot scene layer that turns a match into something the player can see and
touch: a hand fan, two rows of minion tokens, two hero portraits with health, armour, weapon and
hero power, a mana bar, a targeting arrow, the boss's intent banner, a mulligan screen, a Choice
overlay for Discover and Choose One, an event feed, and the end-of-match banner. The player plays
by dragging cards from the hand to the board or onto a target, dragging an attacker onto a
defender, pressing the hero power, and pressing End Turn; everything else on screen is feedback.
Underneath, the system is deliberately thin and one-directional (DD-T02, DD-T04): it **sends
commands** to the rules engine through a `MatchController`, **receives events** from the event log
through `subscribe` / `events_since`, projects those events into a presentation model, and plays
the difference as a queue of short, skippable animations. It never reads or writes `MatchState`
directly; the only read path is a read-only `MatchQuery` for hover text and legal-move
highlighting. The game would lose nothing in its rules without this system — the engine runs
headless — but it would lose the game: Pillar 4 promises that the player can always tell *why*
something happened, and the Match UI is where that promise is kept.

## Player Fantasy

`creative-director` not consulted — Lean mode. Framing: **direct** — the player operates this
system every second of a match.

The feeling is **a table you can read at a glance and a hand that obeys you**. Picking up a card
should feel like picking up a physical card: it lifts, it follows the cursor without lag, legal
places to put it light up, and when it lands it lands with a thump and *does something visible*.
Attacks commit — the attacker lunges, both numbers change on the same frame, the row settles.
The boss's turn is a short, legible sequence of beats the player watches with the intent banner
still in view, so a loss reads as "I saw it and could not stop it" (Pillar 3), never "what just
happened". Reference: Hearthstone's card handling and attack simultaneity; Slay the Spire's
intent icons. Anti-reference: any UI where the player must open a log to find out what a card did
— here the feed is a confirmation, not a necessity, because the board already showed it.
Sensation (concept aesthetic 5) is delivered entirely by this system: snappy drag, impact on
attack, clear effect resolution, and the discipline that nothing on screen ever contradicts the
event log.

## Detailed Design

### Core Rules

`game-designer`, `ux-designer`, `ui-programmer` not consulted — Lean mode. Rules are numbered
U1–U12. Node and class names are design-level handles; `/create-architecture` and the ADRs may
rename them but not re-partition them.

#### U1. Parts and ownership

| Part | Kind | Owns | Never does |
|---|---|---|---|
| `MatchView` | Control scene (`src/ui/match/match_view.tscn`), root | Scene tree, presenters, the input router; starts the subscription | Hold rules state; call `submit` directly |
| `MatchController` | RefCounted, injected | The engine handle; `submit`, `legal_commands`, the boss-turn driver hand-off; the `MatchQuery` | Mutate state outside `submit`; expose `MatchState` |
| `MatchQuery` | RefCounted, read-only facade | Hover text, entity snapshots, effective cost, legal commands, phase, pending choice | Return mutable references |
| `MatchViewState` | RefCounted, pure | The presentation model: a projection of every event seen so far (U3) | Touch a Node; read the engine |
| `AnimationQueue` | RefCounted | Ordered animation steps, skip, speed, coalescing (U4) | Decide *what* changed — only *how long it takes to show* |
| Presenters (`HandPresenter`, `BoardPresenter`, `HeroPresenter`, `FeedPresenter`, `OverlayPresenter`, `TargetingArrow`) | Nodes under `MatchView` | Drawing one zone from `MatchViewState`; emitting input intents | Keep state the view-state does not have |
| `InputRouter` | Node | Mouse/keyboard → intent → command (U5); the global skip | Validate rules (the engine does) |
| `MatchDebugLoader` | Script, debug builds and `--fixture` only | Fixture loading for screenshots (U11) | Exist in a release export |

The UI is **display-only** (`.claude/rules/ui-code.md`): no presenter holds a number the view-state
cannot reproduce from events, and every mutation of the match goes through `submit`.

#### U2. The boundary API

Three channels, nothing else. Signatures are the contract; types come from match-rules C2.

**Commands in** (`MatchController`): `submit(cmd: Command) → CommandResult` where `Command` is one
of match-rules C2's seven (`mulligan`, `play_card`, `attack`, `use_hero_power`, `choose`,
`end_turn`, `concede`); `legal_commands() → Command[]`. `CommandResult = {accepted, rejection:
{code, detail} | null, events: [seq_first, seq_last]}`. The UI issues PLAYER commands only; boss
commands are the Boss AI's, driven by Run Structure's match driver, never by this system.

**Events out** (RNG & Event Log): `subscribe(callback)` delivers `{seq, turn, type, payload,
cause_seq}` once each, in `seq` order; `events_since(seq)` re-reads after a scene (re)load. These
are the UI's **only** source of truth for what happened (DD-T04).

**Queries out** (`MatchQuery`, synchronous, ≤ 2 ms each, match-rules Input Responsiveness):

| Query | Returns | Used for |
|---|---|---|
| `phase()` | `Phase` enum + `active_side` | Enabling End Turn, locking input |
| `pending_choice()` | `{side, kind, options[]} \| null` | Choice overlay |
| `entity(instance_id)` | Snapshot dict: `card_id, side, zone, attack, health, max_health, durability, keywords[], flags{frozen, stealth, divine_shield, silenced, summoning_sick, pending_destroy}, enchantments[{source_id, delta}]` | Tooltips, badges, aura attribution |
| `hand(side)` | `[{instance_id, card_id, effective_cost, playable}]` (boss side: count only) | Hand fan, affordability tint |
| `card_text(card_id)` | `{name_key, text_key, type, cost, attack, health, keywords[]}` via Card Database | Card frames, hover preview, feed names |
| `legal_commands()` | Pass-through | Drop-zone and target highlighting |
| `hero_power_state(side)` | `Ready \| Blocked{reason_code} \| Used` | Hero power button |

A query reads a **copy or a value**, never a live object, so the UI cannot mutate state by
accident. The UI calls queries for hover and highlighting only; it does not poll them to render
numbers — numbers come from the projection (U3) so the screen can lag the engine during playback
without ever disagreeing with it at rest.

#### U3. The projection

`MatchViewState.apply(event) → AnimStep[]` is a pure function: same event sequence, same
view-state, same steps. It is unit-tested headless. The view-state holds, per side: hero
`{health, armor, weapon{attack, durability} | null, power_state}`, `mana{available, max,
temporary}`, `deck_count`, `fatigue_next`, `hand[]` (ids and costs; boss hand = count), `board[]`
(up to `board_size` = 7 tokens with stats, keywords and flags), plus `phase`, `turn`, `intent`
(boss), `pending_choice`, `counters{source_id: {key: value}}` (card-effects `counter_changed`),
`feed_lines[]`, `result`. Projection rules:

1. **Every event is applied immediately**, in `seq` order, on receipt. The view-state is always
   the engine's state as of the last event seen; only the *displayed* state lags (U4).
2. **Hidden information**: boss `card_drawn.card_id` is not stored (rng-event-log Interactions);
   the boss hand is a count. `discover_offered` for `side = boss` stores no options.
3. **One event → zero or more steps.** `mana_refilled` (and the other `mana_*` events) and `auras_recomputed` produce zero steps
   (the number simply updates at the next render); `attack_declared … attack_resolved` produce
   one lunge step; a run of `minion_died` events sharing a `cause_seq` produces **one** removal
   step (match-rules: the row closes the gap after the whole death group).
4. **Unknown event types never fail.** An unrecognised `type` updates nothing, produces no step,
   and adds a feed line with the generic key `feed.unknown` carrying the type name. This is what
   makes the catalogue extension rule (rng-event-log §D) safe for the UI.
4a. **Diagnostic events are filtered, never "unknown".** An event with `payload.diagnostic = true`
   (rng-event-log rule 12a: Match Rules' `command_rejected`, Boss AI's `ai_decision`,
   `ai_plan_aborted`, `ai_fault`) is tested **before** rule 4. It changes no view-state field
   (`ai_decision` only fills the debug overlay's buffer in debug builds), produces no step and no
   feed line — unless the `--ai-debug` flag is set (U11), when it renders as `feed.diag.<type>` in
   `text_muted`. One exception: the **player's own** `command_rejected` produces the
   `reject_shake` step (U5) **and** a feed line `feed.command_rejected` (`{command, code}`),
   because the 1.5 s tooltip may not be the only channel for the reason
   (accessibility-requirements Cognitive "Reading time"); a boss-side `command_rejected` is a plain
   diagnostic. rng-event-log 12a delegates this filter to the UI; this rule is it.
5. **Turn ownership**: `phase_changed` / `turn_started` drive `phase` and `active_side`; the
   player's controls are enabled only when `phase == PlayerTurn.Main` **and** the queue is idle.

Event → projection → step table. Names are match-rules C15's (authoritative, DD-X04 —
rng-event-log §D mirrors it). The legacy aliases this table once tolerated (`mulligan_completed`,
`mana_changed`, `weapon_broken`, `healing_applied`) were deleted on 2026-11-03 (cross-review C-07);
a legacy name now falls to rule 4 like any unknown type.
**Silent set**: C15 events this system does not draw — `turn_reset` and `card_to_graveyard` in v1
— are listed in the data file as `silent_types[]`: no view-state change, no step, **no feed line**.
Rule 4's `feed.unknown` line is only for a type in neither this table, the silent set nor the
diagnostic class (rule 4a). The
events of the five primitives match-rules added on 2026-11-03 (`remove_keyword` →
`keyword_removed`, `add_card_to_deck` → `card_added_to_deck`, `modify_durability` →
`weapon_durability_changed`, `refresh_hero_power` → `hero_power_refreshed`, `discard` →
`card_discarded`) are all in the table:

| Event | View-state change | Animation step (base duration, F3) |
|---|---|---|
| `match_started`, `deck_shuffled` | Deck counts, hero ids | none |
| `mulligan_offered` | `pending_mulligan = ids` | open Mulligan screen (0.2 s) |
| `mulligan_resolved` | Hand replaced | replaced cards flip (0.3 s) |
| `turn_started`, `phase_changed`, `turn_ending`, `turn_ended` | `phase`, `active_side`, `turn` | turn banner (0.4 s, boss turn only) |
| `turn_reset`, `card_to_graveyard` (silent set) | none | none; no feed line |
| `crystal_gained`, `mana_refilled`, `mana_spent`, `mana_added` | `mana` | none |
| `card_drawn` | Hand += id (player) or count (boss); `deck_count` | draw slide deck → hand (0.2 s) |
| `card_added_to_deck` | `deck_count` | deck count tick (0.15 s) |
| `card_burned` | `deck_count` | burn flash over deck (0.4 s) |
| `fatigue_damage` | `fatigue_next` | "Fatigue N" label on hero (0.4 s); the following `damage_dealt` pops as usual |
| `card_played`, `spell_cast` | Hand −= id; (spell) nothing else | card travels to slot / centre (0.25 s) |
| `card_discarded` | Hand −= id (player) or count (boss) | card flies to the graveyard (0.25 s) |
| `minion_summoned` | Board insert at `board_index` | token grows in (0.2 s); row re-spaces |
| `summon_failed` | none | "board full" ghost (0.3 s) |
| `weapon_equipped`, `weapon_durability_changed`, `weapon_destroyed` | `weapon` | slot update (0.2 s) / shatter (0.3 s) |
| `hero_power_used` | `power_state = Used` | button press (0.15 s) |
| `hero_power_refreshed` | `power_state = Ready` (or `Blocked` per `hero_power_state()`) | power button re-lights (0.15 s) |
| `attack_declared` + `attack_resolved` | none / `attacks_used` | lunge (0.35 s); damage steps of this cause land on its active frame |
| `attack_cancelled` | none | attacker returns (0.15 s) |
| `damage_dealt` | `health` / `armor` | number pop `−dealt` (0.4 s), hit-stop per Game Feel; `dealt = 0` with `prevented > 0` → no pop |
| `divine_shield_popped` | flag off | shield burst (0.25 s), no number; precedes the damage step |
| `healed`, `armor_gained`, `armor_lost` | `health` / `armor` | number pop `+n` (0.4 s); `healed{amount: 0}` (treasures Edge Cases: Mending Charm on a full hero) → no pop, feed line only |
| `enchantment_applied/removed`, `auras_recomputed`, `minion_modified`, `silenced`, `frozen`, `thawed`, `stealth_lost` | Stats, keywords, flags | stat digit recolour (0.15 s) or badge add/remove (0.15 s) |
| `keyword_removed` | `keywords` −= keyword | badge drop (0.15 s) |
| `counter_changed` (card-effects C5) | `counters[source_id][key] = value` — read by the source's hover / focus tooltip; **no board badge in v1** (card-effects Gaps: "the UI to show progress does not" exist yet) | none; feed line `feed.counter_changed` |
| `minion_died` (group by `cause_seq`) | Board remove all in group, then re-space | death group (0.3 s) then gap-close (0.2 s) |
| `trigger_queued` / `trigger_resolved` | `armed_sources` | rim glow on/off (0.15 s) |
| `trigger_resolved{once_per_turn: true, exhausted: true}` (card-effects C6.7 / UI Requirements) | `exhausted_sources` += source until the next `turn_started` | once-per-turn trigger icon on the source card dims to 60 % (0.15 s); the rim glow stays off for the rest of the turn; `turn_started` clears the dim with no step |
| `effect_resolved` | none (ops already applied by their own events) | feed group line; `fizzled` → "fizzle" wisp on source (0.2 s) |
| `discover_offered` (Card Effects: `kind`, options) + `choice_requested` (Match Rules: the phase) | `pending_choice` is filled from `discover_offered` (player side only); the overlay step is emitted when the **second** of the pair is projected, whichever order the engine emits them | open Choice overlay (0.2 s) |
| `choice_made` / `discover_picked` | `pending_choice = null` | overlay close (0.15 s) |
| `ai_intent_shown`, `ai_intent_committed` | `intent` (incl. the event's `effective_mode`) | banner show (0.3 s) rendered at the `effective_mode` Boss AI emitted (`full` / `class_only` ≡ `brief` / `hidden` ≡ `off`, DD-X03 — this GDD never re-applies `telegraph_mode` itself) / commit beat `intent_banner_s` / "plan changed" crossfade |
| `command_rejected` (diagnostic, rule 4a) | none | player side: shake + reason tooltip 1.5 s (U5) and a `feed.command_rejected` line; boss side: nothing |
| `ai_decision`, `ai_plan_aborted`, `ai_fault` (diagnostic, rule 4a) | none (`ai_decision` → debug overlay buffer, debug builds only) | none; no feed line unless `--ai-debug` |
| `match_ended` | `result` | end banner (0.6 s) after the queue drains, then hand-off (U9) |
| `log_overflow`, `resolution_overflow` | `result` fault | end banner with fault copy |

#### U4. Animation queue semantics

1. **Unit**: an `AnimStep {kind, entity_ids, base_duration_s, apply_final: Callable, group_id}`.
   `apply_final` is idempotent and sets the presenters to the view-state for that step; it runs
   whether the step animated or was skipped.
2. **Ordering**: steps are appended in `seq` order and played FIFO. Steps with the same
   `group_id` (the `seq` of their command-root event, i.e. the event with `cause_seq = 0`) form a
   **command group**. Steps never reorder across groups; inside a group, steps flagged
   `parallel_ok` (stat recolours, badge changes) play together with the step before them.
3. **Coalescing**: when a group contains more than `COALESCE_THRESHOLD` (8) damage/heal pops on
   distinct targets from one source (an AoE), they play as one simultaneous pop step. Consecutive
   `minion_died` of one cause are always one step (U3.3). Nothing else coalesces — Pillar 4 wants
   effects countable (match-rules Feel Reference anti-reference).
4. **Speed**: `anim_speed ∈ {normal, fast}` selects a divisor (`normal` 1.0, `fast` 2.0) applied
   to every base duration (F3); `instant` skips everything always. It is a settings value
   (Tuning Knobs; the DD-X07 label set) that persists via Meta Progression's settings record once
   that exists; until then it is session-local.
5. **Skip-all**: left click anywhere outside an interactive control, Space, or Enter while the
   queue is busy flushes it: every remaining step's `apply_final` runs in order within one frame,
   hit-stop and slow-down are cancelled, SFX for skipped steps are dropped, and the display equals
   the view-state. Skip latency ≤ 100 ms (boss-ai Input Responsiveness). Skipping is always
   allowed, including during the player's own command playback and the end banner.
6. **Invariant**: when the queue is idle, every presenter equals `MatchViewState` field for field.
   The debug build asserts this after each drain (`MatchView._assert_in_sync`), and the headless
   test suite asserts it after a skip at every step index of a recorded event stream (AC L6).
7. **Command while busy**: a new player command first flushes the queue (rule 5), then submits.
   The player never waits for an animation to make a legal move, and the engine never receives a
   command built against a stale display.
8. **Draining is time-bounded**: the queue's per-step timer runs on process ticks, never on
   `await` chains inside rules code; the UI never blocks the game thread (`ui-code.md`).

#### U5. Input and command issue

- **Drag to play.** Press on a hand card with `playable = true` lifts it; while dragged, the
  board shows the legal summon positions from `legal_commands()` as slot gaps, and for a targeted
  card or spell the arrow (U7) appears from the card with every legal target outlined
  `state_target`. Release over a legal slot/target → `submit(play_card)`. Release anywhere else →
  the card tweens back (0.15 s), no command, no event. Right-click or Esc during a drag cancels.
- **Click to select (mouse alternative to drag — accessibility-requirements Motor,
  interaction-patterns "Click-to-Select / Keyboard Targeting").** A press-and-release that moves
  less than `CLICK_DRAG_PX` (8 px) on a playable card, a legal attacker or a `Ready` hero power
  enters `KeyTargeting` with `entered_by = pointer`: the source lifts, legal positions or targets
  light exactly as in a drag, and the arrow (U7) points at the current target (first legal, or
  the one nearest the cursor). Hovering a lit target moves the ring; LMB on a lit target or slot
  (or `Enter`) confirms and calls `submit`; `Esc`, RMB, a click on empty table or a click on a
  different legal source (which re-selects it) cancels with no command. A single click never
  plays a card: an untargeted play (one legal position, untargeted spell) still needs the second
  click or `Enter`, so a mis-click costs nothing. Click and drag coexist on the same card without
  a setting — the 8 px threshold tells them apart.
- **Attack.** Press on a friendly token with `can_attack` true (via `legal_commands()`) starts the
  arrow; legal defenders outline; Stealth enemies are **not** outlined and not droppable
  (match-rules `TARGET_STEALTHED`); if a Taunt exists only Taunts outline. Release on a legal
  defender → `submit(attack)`.
- **Hero power.** Click the button when `Ready`; targeted powers start the arrow. `Blocked`
  shows the reason (`reason_code` from `hero_power_state()`) in a tooltip on hover **or keyboard
  focus** — never hover-only (art bible §7, `ui-code.md`); `Used` is dimmed. Focus also shows the
  power's name, cost and text.
- **End Turn.** Enabled only in `PlayerTurn.Main` with the queue idle; outline `state_actionable`
  when the player has no legal play other than `end_turn` or no mana left (art bible UI palette).
  Pressing it during `Resolving`, `Choice` or the boss turn does nothing (control disabled); it
  never reaches `submit`. **Arm guard**: End Turn by key (`Space`/`Enter`, below) is armed only
  once the queue has been idle for `end_turn_arm_ms` (300 ms, data file) — a skip press that lands
  on the frame the boss turn drains is swallowed instead of ending the turn. A mouse click on the
  button is never gated (accessibility-requirements Motor "Accidental-activation guard").
- **Rejection handling.** If `submit` returns `accepted = false` anyway (a race the disable
  missed), the UI shakes the originating control (0.2 s) and shows a tooltip at the cursor keyed
  `reject.<code>` for `REJECTION_TOOLTIP_S` = 1.5 s. `MUST_ATTACK_TAUNT` additionally flashes the
  Taunts; `NOT_ENOUGH_MANA` flashes the mana bar. The display is **not** changed by a rejection —
  nothing happened, so nothing is shown as happened.
- **Keyboard (v1, mouse-equivalent, not a second mode):** `Space`/`Enter` = End Turn when enabled
  **and armed** (`end_turn_arm_ms`) and no card, token or hero power holds keyboard focus, else
  skip-all while the queue is busy; `Enter` on a focused playable card, legal attacker or `Ready`
  hero power enters keyboard targeting instead (below). `Esc` = one priority chain, first match
  wins: (1) cancel a drag, click-to-select or keyboard-targeting session; (2) close the feed
  drawer; (3) close the top-most overlay **that has a cancel** (pause menu → Resume, concede
  confirm → Cancel); (4) otherwise open the pause menu (concede + settings). **`Esc` never cancels
  or closes the Mulligan screen, the Choice overlay or the end banner** — they have no cancel (U8,
  U9; a Choice has no legal "back"), so as a cancel it is a no-op there and the chain falls
  through to (4), which keeps concede two presses away — **except on the end banner (`Ended`,
  DD-X09): there `Esc` does nothing at all.** The pause menu is reachable in every view state
  except `Ended`; the banner's Continue click / `Enter` or `MATCH_END_AUTO_S` is the only exit, so
  the chain never falls through to (4) once `result` is set. `1`–`9`,`0` = pick hand card 1–10 into
  **keyboard targeting**: `Tab`/`Shift+Tab` cycle legal positions or targets (the arrow follows),
  `Enter` confirms, `Esc` cancels; `H` = hero power; `L` = toggle the feed panel; `A` then a
  number = pick attacker by board index and cycle defenders with `Tab`. Every action reachable by
  mouse is reachable here (`ui-code.md`, technical-preferences "no hover-only information").
- **Keyboard inspect (focus cycling in `Idle`).** Outside a targeting session `Tab`/`Shift+Tab`
  move keyboard focus over hand (left → right) → player board row (left → right) → hero power →
  player hero portrait → treasure chips → End Turn → feed toggle → menu button → boss intent
  banner → boss row (left → right) → boss portrait and wrap (the full stop list is owned by
  `design/ux/interaction-patterns.md` Focus Management and `design/ux/hud.md`'s Focus Order
  table). The focused element draws a **2 px `state_actionable` focus ring** offset 3 px from its
  bounds, above everything on that element, at every `anim_speed` including `instant`; it is
  distinct from the hugging "actionable" outline by the 3 px gap. Focus opens the same information
  hover does — the 1.5x preview (F2) for cards and tokens, the tooltip for the hero power,
  portraits and treasure chips — so no information is hover-only. On entering `Idle` focus goes to
  End Turn when nothing is lit, else the left-most playable card; if the focused card leaves the
  hand, focus moves to the card now at that index, else End Turn. Hover never moves focus; a click
  does.
- **Gamepad**: post-v1 (technical-preferences: partial). The keyboard targeting mode above is the
  path a gamepad will map onto; nothing in v1 may make that mapping impossible.

#### U6. Boss turn playback and pacing

The Boss AI resolves its whole turn synchronously inside the match driver (boss-ai C2, C9): by the
time the UI sees `turn_started{side: boss}` the entire turn's events may already be in the log.
The Match UI therefore **paces a burst it already holds**:

1. On `turn_started{side: boss}` the player's controls lock (only skip, concede, settings, feed).
2. `ai_intent_committed` plays the commit beat (`intent_banner_s`, boss-ai knob) before the first
   action group; `kept = false` shows the "plan changed" label instead.
3. Command groups (U4.2) play in order with a **gap** between them derived from
   `ai_action_delay_s` — the player's `action_delay_ms / 1000` when Meta's setting is present
   (DD-X07), else Boss AI's `presentation.action_delay_s` 0.6 s — and compressed so the whole turn
   fits `max_turn_playback_s` (F4, F5). Within a group, steps play at normal speed.
4. Skip-all (U4.5) applies at any time; a skipped boss turn still shows the intent banner's final
   state and the turn banner, because those are view-state, not animation.
5. `turn_started{side: player}` unlocks controls once the queue drains.
6. A `Choice` raised for the boss is answered by the AI inside the same synchronous turn; the UI
   shows a 0.4 s "boss discovers…" label on the boss portrait and **no options** (U3.2).

#### U7. Targeting arrow

A quadratic Bezier from the source (card centre or attacker token) to the cursor, control point
lifted by `ARROW_LIFT_PX` (50) above the midpoint, 20 segments, colour `state_target`, with a
triangular head; redrawn each frame while active. Salvage reference:
`prototypes/hearthstone-clone-2026-01/scripts/targeting_arrow.gd` (behaviour kept: single
quadratic curve, head polygon; colour and lift become data). The hovered legal target gains a 3 px
ring (shape is the primary cue — art bible colourblind rule). Right-click or Esc cancels; releasing
on a non-target cancels; the engine is not called on cancel.

#### U8. Mulligan screen

Opens on `mulligan_offered` (player side; the boss has no mulligan, boss-ai C11). Shows the 3
starting cards (`starting_hand_player`) face up at 1.5x in a centre row over a dimmed table; each
card toggles between *keep* and *replace* on click or `1`–`3`; a Confirm button (always enabled —
replacing none is legal) sends `mulligan(keep_mask)`; Concede is reachable from the pause menu.
Salvage reference: `mulligan_screen.gd` (toggle-and-confirm flow kept; the prototype's
"keep exactly N" rule is **not** kept — DD-M05 allows any subset).

#### U9. Choice overlay, match end, concede and settings

- **Choice overlay** opens on `choice_requested` with `pending_choice.side = player`: `discover_count`
  = 3 options as full cards at 1.5x (Discover) or 3 labelled plates (Choose One) in a centre row;
  the rest of the table dims; click or `1`–`3` selects, Confirm or `Enter` sends `choose(i)`.
  No cancel: a Choice has no legal "back" (match-rules States), only concede. Salvage reference:
  `discover_selection.gd` (select-then-confirm kept).
- **Match end**: when `match_ended` is projected the UI finishes draining, plays the end banner
  (victory / defeat / `both_dead` / `concede` / `fault` copy keyed `end.<reason>`), waits for a click
  or `MATCH_END_AUTO_S` = 4 s, then emits `match_view_finished(result)`. The **`fault` variant**
  (`match_ended{result: fault}` after `log_overflow` / `resolution_overflow`; cross-review S-04)
  is not a defeat and must not read as one: `end.fault` copy says "Rules fault — this floor is
  replayed, not lost" (Pillar 4), no `sfx.ui.defeat` stinger fires, no portrait saturates, and the
  banner still auto-advances so Run Structure's `match_faulted` → `pre_match` replay of the same
  boss (Run UI's boss intro, "Attempt 2") follows without the player believing they lost — the one Continue intent
  run-ui.md's `match` screen names (its Interactions "Match UI" row; contract confirmed here). Run
  UI swapped this scene in at `begin_match` and takes control back on that signal; Run Structure
  has already consumed `match_ended` through the engine. The Match UI never navigates and does
  not know about floors or drafts.
- **Concede** lives in the pause menu (`Esc` with nothing open, or the top-bar button) behind a
  confirm dialog; confirming sends `concede`. It is available in every phase except `Ended`,
  including during the boss turn (match-rules C14). **The pause menu itself is unreachable in
  `Ended`** (DD-X09): once the end banner is up, `Esc` and the top-bar menu button do nothing;
  settings wait for Run UI's next screen.
- **Settings quick-access** (same pause menu): master/SFX volume, `anim_speed` and `reduce_motion`.
  Settings are display-and-audio only and never touch the match.

#### U10. Event feed and localization

Every event becomes at most one line, rendered through the localization system with the key
`feed.<type>` and payload fields as parameters (`feed.damage_dealt` → "{source} deals {amount} to
{target}"); entity names resolve through `card_text(card_id).name_key`, never through strings in
the payload. Lines are **grouped under their command root** (`cause_seq` chain) and indented one
level; a group with more than `FEED_GROUP_COLLAPSE` (6) child lines collapses to the first 6 plus
"+N more", expandable. The collapsed feed is a 3-line ticker; `L` or the top-bar button opens the
full panel holding the last `FEED_MAX_LINES` (200). Boss hand contents never appear until played
(rng-event-log UI Requirements). All user-facing strings in this system — feed lines, rejection
reasons, banners, button labels, intent labels — are keys (`ui-code.md`); v1 ships `en` only.

#### U11. Debug entry points (the screenshot contract)

Every screen and state in the inventory (UI Requirements) must be reachable from a launch
argument so `run-and-observe.md` can capture it unattended. `MatchView` reads
`OS.get_cmdline_user_args()` (arguments after `--`) in debug builds:

```
godot --path . --windowed --resolution 1280x720 --write-movie production/qa/evidence/<story>/<nn>-<what>.png \
  --quit-after 60 res://src/ui/match/match_view.tscn -- --fixture=<name> [--anim-speed=instant] [--pose=<pose>]
```

| Argument | Meaning |
|---|---|
| `--fixture=<name>` | `MatchDebugLoader` loads `tests/fixtures/match_ui/<name>.json`: a `MatchConfig` (hero, boss, seed) plus a scripted command list; it runs the real engine headless through those commands, then the view projects `events_since(0)` with animations instant. **Fixtures use the real engine** — no hand-built view-states — so a screenshot can never show a state the rules cannot reach. |
| `--pose=<pose>` | A view-only pose applied after loading: `drag:<instance_id>` (card lifted, arrow to screen centre, legal targets lit), `hover:<instance_id>` (1.5x preview), `reject:<code>` (shake + tooltip frozen), `menu:concede` / `menu:settings`, `feed:open`, `choice:open` (requires a fixture that ends in `Choice`), `end:<reason>`, `focus:<element>` (keyboard focus on a hand index, token instance id, `hero_power`, `end_turn` or `treasure:<n>` — ring + the focus-opened preview/tooltip), `select:<instance_id>` (click-to-select session, arrow on the first legal target) |
| `--pause-at=<seq>` | Stop playback with the queue holding every step after `seq` — for mid-animation and boss-turn captures |
| `--anim-speed=instant\|fast\|normal` | Overrides the `anim_speed` setting for this launch (DD-X07 labels) |
| `--ai-debug` | Debug builds only: shows the `ai_decision` overlay and renders `diagnostic: true` events as `feed.diag.<type>` lines (U3.4a); without it they never reach the feed |

Required fixtures (one JSON each): `mulligan`, `turn1_player`, `midgame_full_board` (7 v 7),
`hand_10`, `targeting_taunt`, `targeting_stealth`, `choice_discover`, `choice_choose_one`,
`boss_intent_full`, `boss_intent_plan_changed`, `boss_intent_hidden` (a band-3 boss with
`effective_mode = hidden` — the "?" banner frame), `boss_turn_playback`, `fatigue_and_burn`,
`treasure_tray` (two held treasures, one hook firing), `divine_shield_hit`, `simultaneous_deaths`, `match_end_victory`, `match_end_defeat`,
`match_end_both_dead`, `match_end_concede`, `match_end_fault` (a scripted `resolution_overflow`).
**Settings variants**: every fixture `hud.md` cites (`turn1_player`, `midgame_full_board`,
`hand_10`, `boss_intent_full`, `boss_turn_playback`, `treasure_tray`, `fatigue_and_burn`) also
exists as `<name>_ts150` — the same command list with the profile `text_scale = 1.5` — so the
§10.2 reflow is captured, not asserted (accessibility-requirements Visual "Text scale"). A story that adds a screen adds its fixture in the same
story; `/qa-plan` lists them.

#### U12. What this GDD does not decide

Pixel positions beyond the reference grid in F6, final copy, icon art, focus order and the
accessibility tier are `/ux-design`'s (`design/ux/hud.md`, `mulligan.md`, `targeting.md`,
`choice-overlay.md`, `event-feed.md`, `match-end.md`, and `design/accessibility-requirements.md`).
Scene/node architecture and the tween library choice are ADRs. This GDD binds the contracts those
documents must respect.

### States and Transitions

The view has its own state machine, **orthogonal to the engine's phase** (match-rules States):
the engine says what is legal; the view state says what the player is currently doing with the
screen. `playing` is true whenever the `AnimationQueue` is non-empty and overlays every state
below except `Ended`.

| State | Entry condition | Exit condition | Behaviour |
|---|---|---|---|
| `Loading` | Scene ready; `MatchController` injected | `events_since(0)` projected and queue drained | Blank table; no input; fixtures (U11) finish here with animations instant |
| `Mulligan` | `mulligan_offered` projected | `mulligan` accepted | Mulligan screen; no cancel — `Esc` opens the pause menu (U5), never closes the screen |
| `Idle` | `phase == PlayerTurn.Main`, queue idle, no overlay | Any input intent, or an event arriving | Full controls; hover previews; `Tab` focus cycling with the 2 px focus ring (U5); End Turn enabled, armed after `end_turn_arm_ms` |
| `Dragging` | Press-and-move (> `CLICK_DRAG_PX`) on a playable card or legal attacker / hero power | Release, right-click, Esc | Arrow or lifted card; legal drops lit; End Turn disabled |
| `KeyTargeting` | Number key / `A` + number / `H`; a click (< `CLICK_DRAG_PX`) on a playable card, legal attacker or `Ready` hero power; `Enter` on such a focused source | Enter or LMB on a lit target/slot (submit); Esc, RMB, click on empty table | Same visuals as `Dragging`, cursor-free or pointer-entered (`entered_by`); `Tab` or hover over a lit target cycles |
| `Playback` | Queue non-empty | Queue drained | Controls locked except skip, pause menu, feed; `playing = true` |
| `BossTurn` | `turn_started{side: boss}` | `turn_started{side: player}` and queue drained | Intent banner commit beat; paced groups (U6); skip; the player's hand dims to 60 % (one step to `table_dark`, art bible §2) for the whole state and restores on exit |
| `ChoiceOpen` | `choice_requested{side: player}` | `choose` accepted or concede | Overlay; table dimmed; no cancel — `Esc` is a no-op as a cancel and opens the pause menu instead (U5) |
| `Menu` | `Esc` with nothing open, or top-bar button | `Esc`, Resume, or a confirmed concede | Concede confirm + settings; underlying playback keeps running |
| `Ended` | `match_ended` projected and queue drained | `match_view_finished` emitted | End banner; click or `MATCH_END_AUTO_S`; no commands; `Esc` does nothing and the pause menu is unreachable (DD-X09) |

Transitions (explicit): `Loading → Mulligan` (fixture/new match with `mulligan_offered`) or
`Loading → Idle` (resume/fixture past mulligan); `Mulligan → Playback → Idle`; `Idle → Dragging`
(press), `Dragging → Idle` (cancel, no command) or `Dragging → Playback` (accepted command);
`Idle → KeyTargeting → Idle | Playback` likewise (entered by number key, `A` + number, `H`, a
click on a legal source, or `Enter` on a focused source); `Idle → Playback` on any event burst (e.g. a
start-of-turn trigger); `Playback → Idle` on drain when `phase == PlayerTurn.Main`; `Playback →
BossTurn` on `turn_started{boss}`; `BossTurn → Playback → Idle` on `turn_started{player}`; any
state except `Ended` `→ ChoiceOpen` on a player `choice_requested`, `ChoiceOpen → Playback` on
`choose`; any state **except `Ended`** `→ Menu` and back (DD-X09); any state `→ Ended` once `match_ended` is drained. A command
issued from `Playback` flushes the queue first (U4.7). Any (state, input) pair not listed is
ignored by the `InputRouter` — never forwarded to `submit`.

### Interactions with Other Systems

| System | Direction | Data in (to Match UI) | Data out (from Match UI) | Interface owner |
|---|---|---|---|---|
| **Match Rules** | upstream | `CommandResult` with rejection codes; `legal_commands()`; `MatchQuery` facts (`phase`, `pending_choice`, `effective_cost`, `can_attack` via legal moves, `hero_power_state`) | PLAYER commands via `submit` | Match Rules owns commands, codes and the query facts; this GDD owns the `MatchQuery` facade shape |
| **RNG & Event Log** | upstream | Every match event via `subscribe` / `events_since`; the envelope `{seq, turn, type, payload, cause_seq}` | Nothing — the UI never appends (a subscriber calling `append` is a bug, rng-event-log Edge Cases) | RNG & Event Log |
| **Card Effects** | upstream | `effect_resolved` (the feed's playback unit, per-op `outcome`), `discover_offered` options and `kind`, `trigger_queued/resolved` for armed glow, `counter_changed` (tooltip value on the source and a feed line — no badge in v1, U3), `targeting_spec` via `legal_commands()` | Nothing | Card Effects owns payloads; this GDD owns how they are drawn |
| **Boss AI** | upstream | `ai_intent_shown`, `ai_intent_committed{kept}` carrying `effective_mode` = min(boss `intent_mode`, player `telegraph_mode`) — Boss AI computes it (DD-X03, boss-ai C8.4); this GDD renders exactly what is emitted; knobs `presentation.action_delay_s` (= `ai_action_delay_s` unless Meta's `action_delay_ms` overrides it, F4), `max_turn_playback_s`, `intent_banner_s`; `ai_decision` / `ai_plan_aborted` / `ai_fault` (diagnostic — debug overlay only, never the feed, U3.4a) | Nothing; skip is local to the UI (events are already logged) | Boss AI owns intents and pacing knobs; this GDD owns compression (F4) |
| **Card Database** | upstream | `card_text` fields (name/text keys, type, printed stats, keywords) by `card_id`, read through `MatchQuery` | Nothing | Card Database |
| **Heroes** | upstream (data) | Hero primary/secondary colour, power name/cost/text keys, weapon token stats | Nothing | Heroes |
| **Treasures** | upstream (display) | Held treasure ids in pick order (from `MatchConfig`) for the tray (F6 zone); hook-hosted `effect_resolved` with `host_kind = treasure` for the tray flare and feed attribution; `healed{amount: 0}` suppressed (treasures.md Edge Cases); boss `passive` plate | Nothing | Treasures (data and tray order); card-effects (event) |
| **Run Structure** | upstream (indirect) | `MatchConfig` (R3: hero, boss, floor, band, held treasures) reaches this system through Run UI's `begin_match` scene swap; the match driver that calls Boss AI is Run Structure's (boss-ai Interactions) and is wrapped by `MatchController` | Nothing directly — `concede` goes through `submit`; the end-of-match hand-off goes to Run UI | Run Structure owns `MatchConfig` and the driver; it never references this system (run-structure.md, verified 2026-11-03) |
| **Run UI** | mutual (sibling hand-off) | Scene swap at `begin_match` with the `MatchConfig` and `MatchController`; this GDD reads settings from Meta Progression (DD-X07), not from Run UI | `match_view_finished(result)` after the end banner (run-ui.md `match` screen and Interactions "Match UI" — contract confirmed); shared theme tokens and the pause-menu settings panel | Run UI reuses, never imports, match presenters |
| **Meta Progression** | upstream (soft) | Persisted `anim_speed` (label set per DD-X07), `high_contrast_states`, `reduce_motion`, `action_delay_ms`, `text_scale`, `gamma` (0.8–1.4, DD-X10 — applied to the match scene through a `CanvasModulate` brightness adjustment, never to colour tokens), volumes via `settings_changed` | Settings changes to persist (`set_setting`) | Meta Progression owns the settings record; absent at MVP → session-local |

Every partner GDD exists (verified 2026-11-03): treasures.md places the tray on the match screen
(its UI Requirements), run-ui.md names the `match_view_finished` hand-off and the shared settings
panel, meta-progression.md M9 stores the `anim_speed` label set and `action_delay_ms` (DD-X07).

## Formulas

`systems-designer` not consulted — Lean mode (no `Agent` tool; HIGH-risk section drafted
in-skill — review before production). Layout maths use the art bible's 150x210 card, 90x126
token and the 1280x720 logical viewport (DD-T05). Every variable marked `data file` lives in
`assets/data/match_ui.json` (DD-T01; loaded by Card Database, read via `config("match_ui")`).

### F1. Hand fan layout

The `hand_fan_layout` formula is defined as, for card `i` of `n` (0-based, left to right), with
the card's pivot at its bottom centre:

```
c      = (n − 1) / 2
s(n)   = CARD_W + HAND_GAP                    if (n − 1) · (CARD_W + HAND_GAP) + CARD_W ≤ HAND_W
       = (HAND_W − CARD_W) / (n − 1)          otherwise (n ≥ 2)
x_i    = HAND_CX + (i − c) · s(n)
y_i    = HAND_BASE_Y − ARC_H · (1 − ((i − c) / max(c, 1))²)
rot_i  = (i − c) · min(THETA_STEP_MAX, THETA_TOTAL_MAX / max(n − 1, 1))
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| n | int | 0–10 (`hand_size`) | calculated | Cards in the player's hand |
| CARD_W | int | 150 | constant (art bible §4) | Card width at 1x |
| HAND_GAP | int | 4–16 (8) | data file | Gap between cards when the hand is not crowded |
| HAND_W | int | 700–900 (800) | data file | Width budget of the hand zone |
| HAND_CX | int | 640 | constant | Horizontal centre of the viewport |
| HAND_BASE_Y | int | 696 | constant | Baseline the outer cards' bottoms sit on: 720 − ⌈CARD_W / 2 · sin 15°⌉ − 4, so a rotated card's lowest corner (+19.4 px) stays on screen |
| ARC_H | int | 0–26 (24) | data file | How far the centre card rises above the outer cards (the arc lifts; no card ever sits below the baseline) |
| THETA_STEP_MAX | float | 2–6° (4°) | data file | Rotation between neighbours when few cards |
| THETA_TOTAL_MAX | float | 20–40° (30°) | data file | Total spread, end card to end card, when crowded |

**Output range:** `s` 72.2 px (n = 10) to 158 px (n ≤ 5); `rot` −15° to +15°; the visible strip
of each overlapped card is ≥ 72 px, which keeps the cost stamp (x 3–37) and attack stamp fully
visible (art bible: stamps at the corners "where a fanned hand still shows them"); health is read
from the hover preview when overlapped. Vertically, the lowest corner of any card is at
y ≤ 715.4 (outer card: 696 + 75 · sin 15°) and the centre card's top is at y 462, clear of the
player row (ends y 460). Horizontally, card centres stay within x 315–965 for every n (the crowded
branch applies from n = 6, so the outer cards always sit at the budget's ends), the bottom corners
within x 243–1037, and the rotated **top** corners reach x 188 / 1092 for y ≥ 474 (210 · sin 15° =
54 px past the unrotated edge; card 9's right edge is at x 1054 at y 652 and 1048 at y 676). F6
keeps the mana bar (x ≥ 1060, y ≥ 652) and the treasure chips (x ≤ 162) outside that envelope, so
nothing is clipped or covered at 1280x720.
**Example:** n = 10 → c = 4.5, s = 650 / 9 = 72.2, card 0 at x = 640 − 4.5 · 72.2 = 315, rot −15°,
y = 696; cards 4 and 5 at y = 696 − 24 · (1 − (0.5 / 4.5)²) = 672.3; card 9 at x = 965, rot +15°.
n = 3 → s = 158, rots −4°, 0°, +4°, centre card y = 672.

### F2. Hover preview transform

`hover_transform(card) = {scale: HOVER_SCALE, rot: 0, y: HAND_BASE_Y, x: clamp(x_i,
HOVER_SCALE · CARD_W / 2, 1280 − HOVER_SCALE · CARD_W / 2), z: top}` applied over `HOVER_IN_S`;
neighbours do not move (salvage reference `card_ui.gd`: "card hovers in place").

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| HOVER_SCALE | float | 1.5 | constant (art bible: 225x315 preview) | Preview scale; text ×1.5 |
| HOVER_IN_S | float | 0.05–0.2 (0.1) | data file | Hover in/out tween |

**Output:** a 225x315 preview whose bottom sits on the baseline and whose top reaches y = 381,
overlapping the player's board row by design (it is on top and disappears on mouse-out).

### F3. Effective animation duration

`d_eff(step) = 0 if skipped or anim_speed = instant; else d_base(step) / SPEED_DIV[anim_speed]`

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| d_base | float | 0.15–0.6 s | data file (table in U3; durations below) | Authored duration per step kind |
| anim_speed | enum | instant, fast, normal | Meta settings (DD-X07; default normal) | Player's animation speed label |
| SPEED_DIV | table | normal 1.0, fast 2.0 | data file (match_ui.json) | Divisor per label (`instant` never divides — it skips) |

Base durations (data file): `play_card` 0.25 · `attack_lunge` 0.35 · `damage_pop` 0.4 ·
`heal_pop` 0.4 · `death_group` 0.3 · `gap_close` 0.2 · `draw` 0.2 · `burn` 0.4 · `shield_pop`
0.25 · `badge` 0.15 · `stat_recolour` 0.15 · `turn_banner` 0.4 · `intent_show` 0.3 ·
`overlay_open` 0.2 · `overlay_close` 0.15 · `reject_shake` 0.2 · `end_banner` 0.6. Impact
extras (hit-stop 60/90 ms, shake 120 ms, lethal slow-down 400 ms — match-rules Game Feel) scale
the same way and are dropped entirely at `anim_speed = fast` or when `reduce_motion` is set.
**Example:** attack at `fast` → 0.175 s; at `normal` → 0.35 s; at `instant` → 0, `apply_final` only.

### F4. Boss-turn gap and compression

```
D   = Σ d_eff over all steps of the boss turn
A   = number of command groups in the turn
gap = clamp((max_turn_playback_s − intent_banner_s − D) / max(A − 1, 1), MIN_ACTION_GAP_S, ai_action_delay_s)
T   = intent_banner_s + D + gap · (A − 1)
k   = 1 if T ≤ max_turn_playback_s else max(max_turn_playback_s / T, K_MIN)
```
Every step duration and every gap is multiplied by `k`. If `k = K_MIN` and the clock still reaches
`max_turn_playback_s`, the queue auto-skips the remainder (U4.5).

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| ai_action_delay_s | float | 0.0–2.0 | `settings.action_delay_ms / 1000` when the Meta setting is present (DD-X07), else Boss AI data `presentation.action_delay_s` (0.6) | Preferred gap between boss actions; the clamp floor `MIN_ACTION_GAP_S` still applies |
| max_turn_playback_s | float | 6–20 (10) | Boss AI data | Budget for the whole boss turn |
| intent_banner_s | float | 0.3 | Boss AI data | Commit beat before the first action |
| MIN_ACTION_GAP_S | float | 0.1–0.3 (0.15) | data file | Floor so actions never blur (match-rules anti-reference) |
| K_MIN | float | 0.25–0.5 (0.25) | data file | Hardest compression before auto-skip |
| A | int | 1–30 (`max_actions_per_turn`) | calculated | Boss commands this turn incl. `end_turn` |

**Output range:** `T` ≤ `max_turn_playback_s` always; typical turn (A = 5, D = 2.5 s) → gap 0.6,
T = 5.2 s; busy turn (A = 12, D = 7 s) → gap 0.245, T = 10.0 s; degenerate (A = 30, D = 15 s) →
gap 0.15, T would be 19.65 → k = 0.509, played in 10 s. Satisfies match-rules' "≤ 8 s typical,
≤ 15 s hard cap".

### F5. Event-feed line budget

`lines(group) = min(children, FEED_GROUP_COLLAPSE) + [children > FEED_GROUP_COLLAPSE]` rendered
per command group; the panel retains the newest `FEED_MAX_LINES` lines, the ticker shows the
newest `FEED_TICKER_LINES`.

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| FEED_GROUP_COLLAPSE | int | 4–10 (6) | data file | Child lines shown before "+N more" |
| FEED_MAX_LINES | int | 100–500 (200) | data file | Retained lines; older lines drop (the log keeps everything) |
| FEED_TICKER_LINES | int | 2–4 (3) | data file | Collapsed strip height in lines |

**Output:** a 20-minion AoE renders 7 lines, not 21; panel memory ≤ 200 × ~120 chars.

### F6. Reference layout grid (1280x720)

Zones the UX specs refine but may not re-partition. Rectangles are `x, y, w, h` in logical
pixels; the board is seven 90-px tokens with 8-px gaps = 678 px, centred (art bible §4).

| Zone | Rect | Note |
|---|---|---|
| Top bar (turn, floor/boss name, feed toggle, menu) | 0, 0, 1280, 40 | `bg_edge` |
| Feed ticker / feed drawer (open) | 24, 48, 400, 42 / 0, 40, 300, 290 | drawer never covers the player portrait |
| Boss deck pile + count | 24, 96, 76, 106 | 0.5x card back |
| Boss intent banner | 980, 52, 276, 36 | above the boss portrait |
| Boss portrait (120x160, art bible §5) + hand / mana strip | 1136, 96, 120, 160 / 1136, 262, 120, 28 | band colour; the strip is split side by side (ux-review 2026-11-03, `hud.md` §4.2): **boss hand count** 1136, 262, 60, 28 (left half) and **boss compact mana counter** "n/m" 1196, 262, 60, 28 (right half) — the counter match-rules and this GDD's UI Requirements list now has an F6 rect; at `text_scale` ≥ 125 % the mana half relocates into the portrait panel's bottom-right corner (`hud.md` §10.2) and the strip holds the hand count alone |
| Boss row (7 slots) | 301, 176, 678, 126 | centre line y = 318 |
| End Turn button | 1116, 296, 140, 44 | lit by state |
| Player row (7 slots) | 301, 334, 678, 126 | summon-position gap opens during drag |
| Player portrait | 24, 334, 120, 160 | hero primary |
| Hero power button / weapon slot | 152, 390, 48, 48 / 152, 446, 48, 48 | right of the portrait |
| Hand zone (centre budget) | 240, 462, 800, 258 | F1: card centres x 315–965, centre card top y 462, rotated bottom corners ≤ y 715; the **rotated envelope** at n = 10 (±15°) reaches x 188 and 1092 for y ≥ 474, which is why the mana bar starts at x 1060 and the tray has no fourth slot (rows below); the hand draws above the tray and the mana bar in z |
| Treasure tray (3 chips — `MAX_TREASURES_HELD`, treasures.md; 40x40 visual, 8-px gaps; treasures.md UI Requirements) | 24, 502, 136, 40 | below the player portrait; hidden when no treasure is held; **each chip's hit rect is 44x44** centred on its 40 px visual (chip centres 48 px apart, so hit rects never overlap) — accessibility-requirements Motor "Minimum target size"; the tray's hit zone is therefore 22, 500, 140, 44; chips 1–3 (hit x 22–162) are clear of the hand at every n, whereas a fourth slot (x 168–208) would lie under card 0's rotated top corner (x ≥ 188, y ≥ 512) at n = 10 — if `treasure_floors` ever grows, the tray moves, it does not extend |
| Player deck pile + count / fatigue | 1180, 540, 76, 106 | moved up 20 px to clear the two-row mana bar |
| Mana bar ("n/m" row over 10 crystals) | 1060, 652, 196, 56 | two rows: "n/m" 16 px bold at 1060, 652, 196, 20; ten 16-px crystals with 4-px gaps (full / spent / temporary / locked) at 1060, 680, 196, 28; starts at x 1060 because card 9's rotated right edge reaches x 1054 at y 652 (F1) — the earlier 1000, 676 zone sat under the right-most card for every n ≥ 6 |
| Choice / Mulligan row (3 × 225x315, 24-px gaps) | 278, 202, 723, 315 | over a dimmed table |
| End banner / pause menu | 340, 260, 600, 200 / 440, 160, 400, 400 | |

## Edge Cases

`systems-designer` not consulted — Lean mode.

- **If events arrive faster than they can be animated** (a 40-step Deathrattle chain lands in one
  frame): the projection applies them all at once (U3.1) and the queue holds the steps; the
  display catches up at F3 pace with U4.3 coalescing. The queue is unbounded in count but bounded
  in time by skip-all; no event is ever dropped from the projection.
- **If the player skips mid-animation**: every pending `apply_final` runs in `seq` order within
  one frame; the frame after, presenters equal the view-state (U4.6). A tween interrupted halfway
  is killed, never left to finish later over the final state.
- **If a command is rejected**: shake + `reject.<code>` tooltip for 1.5 s; the dragged card returns
  to its F1 slot; the view-state is untouched because no event was emitted (the diagnostic
  `command_rejected` produces only the tooltip step). A rejection can never desync the display.
- **If a Choice is raised during the boss turn**: `pending_choice.side = boss`; no overlay, no
  options stored; a 0.4 s "boss discovers…" label plays in that command's group. The player never
  sees the options (hidden information).
- **If a Choice is raised during the player's own command** (Discover Battlecry): the overlay
  opens after the card-play step of that group has played, not before — the player sees the card
  land, then chooses. Skipping jumps straight to the overlay; the overlay itself is not skippable.
- **If the hand is full and a draw burns** (`card_burned`, DD-M06): the burned card is shown face
  up over the deck pile for 0.4 s, then dissolves; the hand fan does not change; the feed line
  names the card (the player is allowed to know what they lost).
- **If the deck is empty**: the deck pile shows "Fatigue: next N" from `fatigue_next` (F5 of
  match-rules); `fatigue_damage` plays the label, the following `damage_dealt` pops normally.
- **If the window is resized or the aspect changes**: `canvas_items` stretch with `keep` aspect
  (DD-T05, technical-preferences) letterboxes; all hit-testing is in logical coordinates; no
  layout recalculation occurs — the grid (F6) is fixed at 1280x720 by design.
- **If Divine Shield absorbs a hit**: the step order is `divine_shield_popped` (burst, no number)
  then `damage_dealt{dealt: 0, prevented: n}` (no pop, U3). If the same event group also damages
  an unshielded target, that target's pop plays with the lunge's active frame as usual.
- **If several minions die at once**: one `death_group` step for all `minion_died` sharing a
  `cause_seq`; tokens fade together; the gap-close runs once after. Deathrattle steps queued
  behind them play after the gap-close (match-rules C10 order is the `seq` order).
- **If the player drags toward a Stealth enemy**: it is not outlined and the drop zone ignores it;
  releasing over it cancels like empty table. Stealth is still visible as a badge — the rule is
  "cannot be targeted", not "cannot be seen".
- **If a drag is released outside the board**: cancel; the card tweens back over 0.15 s; nothing
  is submitted.
- **If End Turn is pressed during `Resolving`, `Choice` or playback**: the control is disabled, the
  input is consumed, nothing happens. `Space` in that state means skip-all, never End Turn.
- **If `Space`/`Enter` lands within `end_turn_arm_ms` (300 ms) of the queue draining** (the skip
  press that arrives the frame the boss turn finishes): the key is consumed and nothing happens —
  it is neither a skip (nothing left to skip) nor an End Turn (not yet armed). A click on the
  button is never gated.
- **If `Esc` is pressed on the Mulligan screen or the Choice overlay**: nothing is
  cancelled or closed (no cancel exists); the pause menu opens over the overlay instead (U5).
- **If `Esc` (or the top-bar menu button) is pressed on the end banner**: nothing happens — no
  cancel, no pause menu (DD-X09); the banner waits for Continue or `MATCH_END_AUTO_S`.
- **If the player presses a number key for an empty hand slot**: ignored.
- **If a hover is active when its card leaves the hand** (played by keyboard, or burned): the
  preview is dismissed in the same step; no orphaned 1.5x card remains.
- **If the scene is reloaded mid-match** (resume, crash recovery in a later milestone, or a
  fixture): the view projects `events_since(0)` with `anim_speed = instant`, drains, and enters
  `Idle`/`Mulligan`/`ChoiceOpen`/`BossTurn` according to the projected phase. There is no
  "catch-up animation" of a half-played match — a fresh view is always built from the full log.
- **If the event log reports `log_overflow` or the engine `resolution_overflow`**: the match ends
  (`match_ended{reason}`); the end banner uses `end.fault` copy ("Rules fault — this floor is
  replayed, not lost"), fires no defeat stinger, and still hands off normally so the replay of
  the same boss follows (U9, cross-review S-04). The UI never hides a fault behind a generic defeat.
- **If `match_ended` arrives while the player is dragging**: the drag is cancelled first, then the
  queue finishes, then the end banner plays. Input is locked from the moment `result` is set.
- **If a Taunt exists and the player starts an attack**: only Taunts outline; dropping on a
  non-Taunt cancels client-side (never submits a command the UI knows is `MUST_ATTACK_TAUNT`).
  The rejection path still handles the race where the board changed under the drag.
- **If `anim_speed = instant` and the boss takes a turn**: F4 degenerates to `T = 0`; the intent
  banner final state and turn banner still render (view-state), so the player can read what
  happened from the board and the feed. This is the mode the harness screenshots use.
- **If localization lacks a key** (`feed.<new_type>`, `reject.<code>`): the key itself renders,
  prefixed `??`, and a debug warning fires — never a blank line or a crash.

## Dependencies

Hard = a match cannot be played on screen without it; soft = degrades to a default or a stub.
**Bidirectional check** (`.claude/rules/design-docs.md`): the systems index lists Match UI as
depending on Match Rules, Card Effects, Boss AI, Card Database and RNG & Event Log — all five
rows below agree, and each of those GDDs already lists Match UI as a dependent (match-rules,
card-effects, boss-ai, rng-event-log Dependencies tables; heroes lists "Run UI / Match UI";
treasures, card-database, meta-progression and run-ui list Match UI too). The index also carries
Heroes, Treasures and Run Structure; rows this table **adds**: Run UI (mutual) and Meta
Progression (soft) — flagged for `/map-systems`, not edited here. run-structure.md has no Match
UI row and needs none: the hand-off partner is Run UI (see its row).

| System | Direction | Hard/Soft | Nature of dependency / interface |
|---|---|---|---|
| Match Rules | This depends on Match Rules | Hard | `submit`, `legal_commands`, `CommandResult` rejection codes (closed set, C2), the phase machine incl. `Choice`, `MatchQuery` facts; event vocabulary C15 |
| RNG & Event Log | This depends on RNG & Event Log | Hard | `subscribe` / `events_since`; envelope `{seq, turn, type, payload, cause_seq}`; `cause_seq` is what groups the queue (U4.2) and the feed (U10); hidden-information rule on boss `card_drawn` |
| Card Effects | This depends on Card Effects | Hard | `effect_resolved` (per-op `outcome`, `fizzled`), `discover_offered{kind, options}`, `trigger_queued/resolved`, `counter_changed`; `discover_count` = 3 |
| Boss AI | This depends on Boss AI | Hard | `ai_intent_shown/committed{kept, effective_mode}` (DD-X03 — Boss AI clamps `intent_mode` to the player's `telegraph_mode`; this GDD renders what is emitted), `presentation.action_delay_s` (= `ai_action_delay_s` 0.6 unless Meta's `action_delay_ms` overrides it), `max_turn_playback_s`, `intent_banner_s`; `ai_decision` for the debug overlay |
| Card Database | This depends on Card Database | Hard | Name/text keys, type, printed stats, keywords by `card_id` through `MatchQuery.card_text` |
| Heroes | This depends on Heroes | Soft | Hero colours (via art bible tokens), power name/cost/text, weapon token; defaults to neutral frame if absent |
| Treasures | This depends on Treasures | Soft | Tray contents in pick order and `source_id` for feed lines / tray flare (treasures.md Dependencies lists Match UI); no treasure held → tray hidden |
| Run Structure | This depends on Run Structure | Hard (indirect) | `MatchConfig` fields (hero, boss, floor, band, treasures) and the match driver, delivered through Run UI's scene swap; nothing flows back to Run Structure from this system, so run-structure.md needs no Match UI row |
| Run UI | Mutual (sibling) | Hard | Run UI swaps this scene in at `begin_match` and takes control back on `match_view_finished(result)` (run-ui.md Interactions and Dependencies — bidirectional); shared theme and the pause-menu settings panel |
| Meta Progression | This depends on Meta Progression | Soft | Persisted `anim_speed` (label set per DD-X07), `high_contrast_states`, `reduce_motion`, `action_delay_ms`, `text_scale`, `gamma` (DD-X10, applied via `CanvasModulate`), volumes (meta-progression.md M9 stores them and lists Match UI); absent at MVP → session-local defaults |
| Content | Indirect | Soft | Card text length is bounded by the card frame (art bible) and `MAX_OPS_PER_EFFECT` (card-effects); no runtime interface |

## Tuning Knobs

`systems-designer` not consulted — Lean mode (knobs derived from the F1–F5 variable tables). All
live in `assets/data/match_ui.json` (`schema_version`; listed in DD-T01), loaded and validated by
Card Database and read once at `MatchView._ready` through `config("match_ui")` (card-database CR-1
— the UI never reads JSON itself); `anim_speed`, `reduce_motion` and volumes are also exposed in
the settings menu.

| Parameter | Current value | Safe range | Effect of increase | Effect of decrease | Interacts with |
|---|---|---|---|---|---|
| `anim_speed` (default) | normal | instant \| fast \| normal (DD-X07) | fast halves every d_base and drops impact extras; instant applies final states only | — | SPEED_DIV, F3 |
| `SPEED_DIV` | normal 1.0, fast 2.0 | fast 1.5–3.0 (normal fixed at 1.0) | `fast` snappier; above 3.0 effects blur (match-rules anti-reference) | `fast` barely differs from `normal` | F3, `anim_speed` |
| `reduce_motion` (setting) | false | true / false | Drops screen shake, hit-stop and lethal slow-down at every `anim_speed` (`ui-code.md` rule 4); `d_base` unchanged | n/a | Impact Moments, F3 |
| `end_turn_arm_ms` | 300 | 150–600 | Longer dead window after a drain before `Space`/`Enter` can end the turn (keyboard play feels gated above 500) | Accidental End Turn on the drain frame returns below 150 | U5, Edge Cases; mouse click never gated |
| `CLICK_DRAG_PX` | 8 | 4–12 | Small drags read as clicks (enter click-to-select) | Tremor presses read as drags | U5 click-to-select vs drag |
| `d_base.*` (17 step kinds, F3) | per F3 | 0.1–0.8 s each | More weight; boss turns compress sooner (F4) | Snappier; below 0.15 s effects blur (match-rules anti-reference) | `MIN_ACTION_GAP_S`, `max_turn_playback_s` |
| `MIN_ACTION_GAP_S` | 0.15 | 0.1–0.3 | Busy boss turns hit `K_MIN` sooner | Actions run together | `ai_action_delay_s`, `K_MIN` |
| `K_MIN` | 0.25 | 0.25–0.5 | Auto-skip engages earlier on degenerate turns | Very fast playback instead of a jump | F4 |
| `HAND_W` | 800 | 700–800 | Less overlap; above 800 the right card's rotated edge crosses the mana bar (x 1060) | More overlap; below 700 the attack stamp is partly covered at 10 cards | F1, F6 hand zone and mana bar |
| `HAND_GAP` / `ARC_H` / `THETA_*` | 8 / 24 / 4°, 30° | per F1 | More "fan"; above ARC_H 26 the centre card's top (486 − ARC_H) crosses into the player row | Flat strip; cards look like a toolbar | F1 |
| `HOVER_IN_S` | 0.1 | 0.05–0.2 | Hover feels laggy above 0.15 | Pops | F2 |
| `REJECTION_TOOLTIP_S` | 1.5 | 1.0–3.0 | Reason lingers over the next action | Players miss the reason | match-rules UI Requirements (1.5 s) |
| `MATCH_END_AUTO_S` | 4 | 2–8 | Longer forced pause after a match (Pillar 3 restart speed) | Banner gone before it is read | Run UI hand-off |
| `FEED_GROUP_COLLAPSE` / `FEED_MAX_LINES` / `FEED_TICKER_LINES` | 6 / 200 / 3 | per F5 | Longer chains visible; more memory; taller ticker covers the boss deck | Chains truncated; replay source still complete in the log | F5, F6 |
| `COALESCE_THRESHOLD` | 8 | 4–14 | Big AoEs play pop-by-pop (countable but slow) | Small AoEs collapse into one pop | U4.3 |
| `ARROW_LIFT_PX` | 50 | 20–100 | Loopier arrow | Straight line | U7 |

Knobs owned elsewhere that move this system (not duplicated): `ai_action_delay_s`,
`max_turn_playback_s`, `intent_banner_s`, `intent_mode` / `effective_mode` (Boss AI);
`action_delay_ms` 0–2000 (600), `telegraph_mode`, `text_scale`, `high_contrast_states` (Meta
Progression M9, DD-X07 — `action_delay_ms` overrides `ai_action_delay_s` in F4; `telegraph_mode`
is consumed by Boss AI, not here); `hand_size`, `board_size`
(Match Rules — the hand fan and row must still fit at their safe-range maxima 12 and 7);
`discover_count` (Card Effects); card slot geometry and colour tokens (art bible §4).

## Visual/Audio Requirements

`art-director` not consulted — Lean mode (no `Agent` tool; this is a `UI` system whose feedback
the player reads to play, so a manual art-director pass is owed before production). Per-event
visual feedback for rules events is **owned by match-rules' Visual/Audio table** and boss-ai's
intent rows; the rows below are what this system adds, and the SFX list is the minimal v1 set
the concept allows ("card play, attack, win/lose stingers; one ambient track"). All sounds fire
through the audio event system by key (`ui-code.md`), never from a presenter directly; skipped
steps fire no sound. Visual rules: art bible §4 tokens only; saturated colour only for
`state_*`; placeholder shapes and letter glyphs in v1 (art bible §7).

| Event / moment | Visual feedback (this system) | Audio key | Priority |
|---|---|---|---|
| Card lift (drag start) | Card lifts 8 px then follows the cursor at 1.0x; shadow; legal slots open as gaps; legal targets `state_target` outline + 3 px ring on hover | `sfx.ui.card_lift` | Must |
| Card drop / play | Travels to slot (0.25 s), thump squash 4 frames | `sfx.ui.card_play` | Must |
| Attack lunge | 6/3/9 frames (match-rules); hit-stop 60 ms; both numbers change on the active frame | `sfx.ui.attack_whoosh` + `sfx.ui.impact_light` / `impact_heavy` (dealt ≥ 5) | Must |
| Damage / heal pop | `−n` in `state_danger` / `+n` in `state_buff` on an `ink` pill, rises 20 px, 0.4 s | `sfx.ui.damage` / `sfx.ui.heal` | Must |
| Divine Shield pop | Ring burst in `text_light`, no number | `sfx.ui.shield_pop` | Must |
| Death group | Tokens fade + 2-px drop together; gap-close after | `sfx.ui.death_thud` (one per group) | Must |
| Draw / burn / fatigue | Card back slides deck → hand / burned card dissolves over deck / "Fatigue N" label | `sfx.ui.draw` / `sfx.ui.burn` / `sfx.ui.heartbeat` | Must / Should / Should |
| End Turn press; turn start | Button depress; turn banner (boss turn only) in band colour | `sfx.ui.end_turn` / `sfx.ui.turn_chime` | Must |
| Boss turn (whole `BossTurn` state) | Player hand dims to 60 % (one step to `table_dark`, art bible §2 "Match — boss turn"); restores on `turn_started{player}`; not a step, so skip does not affect it | none | Must |
| Once-per-turn trigger exhausted (`trigger_resolved{once_per_turn, exhausted}`) | Trigger icon on the source card dims to 60 % until the next `turn_started`; rim glow off (U3) | none | Should |
| Intent shown / committed / plan changed | Banner per boss-ai rows; `lethal` pulses `state_danger` once | `sfx.ui.page_turn` / none / `sfx.ui.plan_changed` | Must |
| Rejection | 0.2 s shake, tooltip, related control flash | `sfx.ui.deny` (soft) | Must |
| Overlay open / close (Choice, Mulligan, Menu) | Table dims to `table_dark`; cards scale in 0.2 s | `sfx.ui.overlay` | Should |
| Match end | Banner; winning hero portrait saturates to its primary (art bible's one fill exception); `fault` banner: neutral frame, no saturation (U9) | `sfx.ui.victory` / `sfx.ui.defeat`; **none** for `fault` | Must |
| Ambient | — | `music.match_ambient` loop, ducked under stingers | Should |
| Debug overlay (`ai_decision`) | Collapsible panel, monospace, never in release | none | Dev only |

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run
`/asset-spec system:match-ui` to produce per-asset visual descriptions, dimensions, and
generation prompts from this section (card back, token frame, badges for 8 keywords/states,
intent banner frame, 14 SFX, ambient loop).

## Game Feel

Match-rules' Game Feel section sets the engine-side and pacing targets; this section binds the
UI side of the same numbers and the handling feel the engine cannot express.

### Feel Reference
Hearthstone's hand and board handling: a card lifts the instant it is pressed, follows the cursor
with no smoothing lag, and legal drops are obvious before release; attacks lunge and land
simultaneously. Borrowed: **zero-latency pickup, pre-release legality, simultaneity**.
Anti-reference: Slay the Spire's accelerated multi-hit enemy turns (effects blur), and any card
UI where the hand re-flows under the cursor while hovering (salvage lesson from `card_ui.gd`).

### Input Responsiveness
| Action | Max input-to-response latency (ms) | Frame budget (60 fps) | Notes |
|---|---|---|---|
| Press on card → card lifted | 16 | 1 frame | No tween-in on pickup; the lift is immediate, the hover tween is for mouse-over only |
| Drag → card position update | 16 | 1 frame | Follows the cursor exactly; no easing |
| Release on legal target → first visual event | 50 | 3 frames | match-rules target: `submit` ≤ 5 ms + step start |
| Rejection → shake + tooltip | 50 | 3 frames | |
| Skip-all → display equals view-state | 100 | 6 frames | boss-ai target |
| End Turn → boss intent commit beat visible | 300 | 18 frames | boss-ai target |
| Hover → 1.5x preview complete | 100 | 6 frames | `HOVER_IN_S` |

### Animation Feel Targets
| Animation | Startup | Active | Recovery | Feel goal | Notes |
|---|---|---|---|---|---|
| Card play to board | 4 | 8 | 4 | Snappy, decisive | match-rules; Battlecry steps start after recovery |
| Attack lunge | 6 | 3 | 9 | Committed, weighty | Damage pops on the first active frame |
| Death group | 6 | 6 | 6 | Deliberate | One removal per group; gap-close after |
| Hover in / out | 0 | 6 | 0 | Light, immediate | Neighbours never move |
| Drag return (cancel) | 0 | 9 | 0 | Forgiving | Ease-out; no bounce |
| Boss action gap | — | 36 (0.6 s) | — | Brisk cadence | Compressed by F4, floored at 9 frames |

### Impact Moments
| Impact type | Duration (ms) | Effect | Configurable? |
|---|---|---|---|
| Hit-stop | 60 (minion) / 90 (hero, dealt ≥ 5) | Attacker and defender freeze on contact | Yes (`d_base`), off at `anim_speed = fast` or `reduce_motion` |
| Screen shake | 120 | Hero damage ≥ 5 or lethal; 3 px, decaying | Yes; off when `reduce_motion` |
| Lethal slow-down | 400 | Time-scale 0.5 on the lethal `damage_dealt` step only | Yes; off when `reduce_motion` |
| Intent commit beat | 300 | Banner brightens, hold | Yes (`intent_banner_s`, Boss AI) |

### Weight and Responsiveness Profile
- **Weight**: light in the hand, heavy on the table. Picking up costs nothing; landing thumps.
- **Player control**: total until release; the UI shows legality before the drop so a release is
  never a guess. After release, zero — playback is watchable and skippable, never steerable.
- **Snap quality**: binary. A slot is open or it is not; a target is lit or it is not.
- **Acceleration model**: instant start, short ease-out (arcade) for every UI motion; no ease-in
  anywhere, because ease-in reads as lag on a 0.25 s tween.
- **Failure texture**: fair and specific. A rejection names its rule; a cancel costs nothing; a
  loss can be reconstructed from the feed without opening it.

### Feel Acceptance Criteria
- [ ] No playtester describes card pickup or dragging as "laggy", "floaty" or "sticky".
- [ ] Playtesters never ask "who attacked first?" (shared with match-rules).
- [ ] No playtester calls a boss turn "long" at default knobs; none calls it "a blur" at `fast`.
- [ ] Skipping never produces a visible pop to a different state than the one the animation was
      heading to (verified by the U4.6 assertion during playtests).
- [ ] Testers state why they lost from the board and ticker alone in ≥ 8 of 10 losses.

## UI Requirements

For this system the table is the **screen and component inventory**: what exists, what drives
it, and which fixture (U11) captures it. Per-element information rows for rules facts are in
match-rules', card-effects', boss-ai's and heroes' UI Requirements tables and are not repeated.

| Screen / component | Contents | Driven by (events / queries) | Fixture(s) | UX spec |
|---|---|---|---|---|
| **Match HUD — top bar** | Turn indicator (side + number), floor/boss name, feed toggle, menu button | `turn_started`, `phase_changed`; match config | `turn1_player` | `design/ux/hud.md` |
| **Hero portraits** (both) | Health 24 px, armour, weapon slot (attack/durability), hero power button (`Ready/Blocked/Used`; `Blocked` reason and name/cost/text in a tooltip on hover **or focus**), boss hand count, boss passive plate | `damage_dealt`, `healed`, `armor_*`, `weapon_*`, `hero_power_used`; `hero_power_state()` | `midgame_full_board`, `fatigue_and_burn` | `hud.md` |
| **Treasure tray** | Held treasures as chips in pick order (3 in v1, `MAX_TREASURES_HELD`; 40 px visual, 44x44 hit rect — F6), tooltip with the treasure `text` on hover or focus, flare on a hook-hosted `effect_resolved` | `MatchConfig` treasures; `effect_resolved{host_kind: treasure}` | `treasure_tray` | `hud.md` |
| **Mana bar** (player) + boss compact counter | 10 crystals (full/spent/temporary/locked), "n/m" (F6 `1060, 652, 196, 56`); boss "n/m" in the right half of the boss strip (F6 `1196, 262, 60, 28`) | `mana_*`, `crystal_gained` | `turn1_player`, `midgame_full_board`, `*_ts150` | `hud.md` |
| **Deck piles** | Count, fatigue-next label, burn flash | `card_drawn`, `card_burned`, `fatigue_damage` | `fatigue_and_burn` | `hud.md` |
| **End Turn button** | Enabled / disabled / actionable-outline states; key-armed after `end_turn_arm_ms` (click never gated) | `phase()`, `legal_commands()`, queue idle + arm timer | `turn1_player`, `boss_turn_playback` | `hud.md` |
| **Hand fan** | Up to 10 cards (F1), effective cost (`effective_cost`), playable lit / unaffordable dimmed, hover preview (F2), drag | `card_drawn`, `card_played`, `card_burned`, `enchantment_*`; `hand()` | `hand_10`, `--pose=hover:<id>` | `design/ux/hand.md` |
| **Board rows** | 7 slots per side, 90x126 tokens, summon-position gap, badges: Taunt, Divine Shield, Frozen, Stealth, Windfury, Silenced, summoning-sick, Poisonous/Lifesteal glyphs; can-attack outline; damage numbers | `minion_summoned`, `minion_died`, `minion_modified`, `frozen/thawed`, `silenced`, `stealth_lost`; `entity()` | `midgame_full_board`, `simultaneous_deaths`, `divine_shield_hit` | `hud.md` |
| **Targeting arrow** | Bezier (U7), legal-target rings, Taunt-only / Stealth-excluded highlighting, keyboard cycling, click-to-select entry (U5) | `legal_commands()` | `targeting_taunt`, `targeting_stealth`, `--pose=drag:<id>`, `--pose=select:<id>` | `design/ux/targeting.md` |
| **Mulligan screen** | 3 cards at 1.5x, keep/replace toggles, Confirm | `mulligan_offered` → `mulligan(mask)` | `mulligan` | `design/ux/mulligan.md` |
| **Choice overlay** | 3 Discover cards or 3 Choose-One plates, Confirm; boss-side "boss discovers…" label | `choice_requested`, `discover_offered` → `choose(i)` | `choice_discover`, `choice_choose_one` | `design/ux/choice-overlay.md` |
| **Boss intent banner** | Icon per `intent_key`, amount, target reticle, "plan changed"; rendered at the emitted `effective_mode` (`full` / `class_only` ≡ `brief` / `hidden` ≡ `off`, DD-X03) | `ai_intent_shown/committed{effective_mode}` | `boss_intent_full`, `boss_intent_plan_changed` | `hud.md` |
| **Boss-turn playback** | Locked controls, paced groups, skip affordance ("click or Space to skip" hint after 1 s) | `turn_started{boss}`; F4 | `boss_turn_playback`, `--pause-at=<seq>` | `hud.md` |
| **Event feed** | 3-line ticker; drawer with grouped, collapsible lines; localised | every event; U10 | `--pose=feed:open` | `design/ux/event-feed.md` |
| **Rejection tooltip** | `reject.<code>` copy at the cursor, 1.5 s; control shake | `command_rejected` | `--pose=reject:<code>` | `targeting.md` |
| **Match end overlay** | Victory / defeat / both-dead / concede / fault banner ("floor replayed, not lost" copy, no stinger — U9); continue | `match_ended` → `match_view_finished` | `match_end_*` incl. `match_end_fault` | `design/ux/match-end.md` |
| **Pause menu** | Concede (with confirm), Resume, settings quick-access (volumes, `anim_speed`, `reduce_motion`); unreachable in `Ended` (DD-X09) | — | `--pose=menu:concede`, `menu:settings` | `design/ux/pause-menu.md` |
| **AI debug overlay** | `ai_decision` panel; debug builds / `--ai-debug` only | `ai_decision` | `boss_turn_playback --ai-debug` | none (dev tool) |

📌 **UX Flag — Match UI**: This system has UI requirements. In Phase 4 (Pre-Production), run
`/ux-design` for each spec in the last column **before** writing epics, and
`/ux-design accessibility` for `design/accessibility-requirements.md` (keyboard tier, motion
reduction, high-contrast state set). Stories that reference UI should cite `design/ux/[screen].md`,
not this GDD directly. Note this in the systems index for this system if you update it.

## Cross-References

| This document references | Target GDD | Specific element referenced | Nature |
|---|---|---|---|
| Seven commands, `CommandResult`, closed rejection-code set | `design/gdd/match-rules.md` | C2 | Data dependency |
| Phase machine incl. `Resolving`, `Choice`, `Ended`; End Turn only in `PlayerTurn.Main` | `design/gdd/match-rules.md` | States and Transitions | State trigger |
| Event vocabulary, `damage_dealt` payload, death-group ordering | `design/gdd/match-rules.md` | C15, C10, F2 | Data dependency |
| `effective_cost` for the cost stamp; `can_attack` for the attack outline; `fatigue_damage` label | `design/gdd/match-rules.md` | F1, F3, F5 | Data dependency |
| Hero power rule (2 mana, once per turn) behind `hero_power_state` | `design/gdd/match-rules.md` | C7 | Rule dependency |
| Concede legal in every phase but `Ended`; `both_dead` | `design/gdd/match-rules.md` | C14 | Rule dependency |
| Feel targets (frames, hit-stop, shake, slow-down, ≤ 8 s / 15 s boss turn) | `design/gdd/match-rules.md` | Game Feel | Rule dependency |
| Per-event visual table and 1.5 s rejection tooltip | `design/gdd/match-rules.md` | Visual/Audio; UI Requirements | Ownership handoff (they specify, we render) |
| Envelope `{seq, turn, type, payload, cause_seq}`; `subscribe` / `events_since`; subscriber must not `append` | `design/gdd/rng-event-log.md` | Rules 11–14; Edge Cases | Data dependency |
| Hidden boss `card_drawn.card_id`; catalogue extension rule; `diagnostic: true` class filtered from the feed (U3.4a) | `design/gdd/rng-event-log.md` | Interactions; §D; rule 12a | Rule dependency |
| `log_overflow` ends the match | `design/gdd/rng-event-log.md` | Edge Cases | State trigger |
| `effect_resolved{ops[].outcome, fizzled}`, `discover_offered{kind}`, `discover_picked`, `counter_changed`, `trigger_queued/resolved` | `design/gdd/card-effects.md` | Interactions payload block; C6 | Data dependency |
| One `ChoiceRequest` at a time; Choose-One targets first, picks second; concede abandons | `design/gdd/card-effects.md` | C8 | Rule dependency |
| `discover_count` = 3 | `design/gdd/card-effects.md` | F4 / registry | Data dependency |
| Intent events, keys, `intent_mode` and the emitted `effective_mode` (DD-X03); "plan changed" | `design/gdd/boss-ai.md` | C8, C8.4 | Data dependency |
| Synchronous boss turn; skip jumps to final state; `max_actions_per_turn` | `design/gdd/boss-ai.md` | C2, C9, Game Feel | Rule dependency |
| `presentation.action_delay_s` (= `ai_action_delay_s`), `max_turn_playback_s`, `intent_banner_s` | `design/gdd/boss-ai.md` | Tuning Knobs; Impact Moments | Data dependency |
| Boss Choice answered by the AI | `design/gdd/boss-ai.md` | C7 | State trigger |
| `card_text` fields by `card_id`; single loader | `design/gdd/card-database.md` | Record schema; DD-T01 | Data dependency |
| Power state `Ready / Blocked / Used`; weapon slot; hero colours | `design/gdd/heroes.md` | UI Requirements; H-3 | Data dependency |
| Treasure tray | `design/gdd/treasures.md` (Designed) | Hook-hosted `effect_resolved`; UI Requirements tray | Data dependency |
| Match driver, `MatchConfig`, what follows a match | `design/gdd/run-structure.md` | R-rules for match start/end | Ownership handoff |
| Persisted settings (`anim_speed` labels, `reduce_motion`, `text_scale`, `high_contrast_states`, `action_delay_ms`) | `design/gdd/meta-progression.md` (Designed) | M9 settings record | Data dependency |
| Colour tokens, typography, 150x210 slot layout, 90x126 token, 120x160 portraits, "lit by state" buttons, no hover-only info | `design/art/art-bible.md` | §4, §5, §7 | Rule dependency |
| 1280x720, `canvas_items`, mouse primary, keyboard end-turn/cancel; board 7; hand 10; mulligan any subset; `anim_speed` label set and `action_delay_ms` (DD-X07); `effective_mode` rendering (DD-X03); C15 event spelling (DD-X04) | `design/design-decisions.md` | DD-T05, DD-M01, DD-M06, DD-M05, DD-T02, DD-T04, DD-X03, DD-X04, DD-X07 | Rule dependency |
| Click-to-select, focus ring and tab order, `Esc` chain, `end_turn_arm_ms`, treasure chip hit area | `design/ux/interaction-patterns.md`; `design/accessibility-requirements.md` | Click-to-Select, End Turn Button, Hero Power Button, Treasure Chip, Focus Management, Escape / Cancel; Motor table and Open Questions | Rule dependency (resolved into U5, States, F6 on 2026-11-03) |
| Pillars 3 and 4; Sensation aesthetic; "opponent's turn resolves quickly" | `design/gdd/game-concept.md` | Pillars; MDA; Core Loop | Rule dependency |
| Launch-argument reachability and retained screenshots | `.claude/docs/run-and-observe.md` | Procedure steps 2 and 5 | Rule dependency |

## Acceptance Criteria

`qa-lead` not consulted — Lean mode (HIGH-risk section drafted in-skill). Two groups: **Logic**
criteria run headless against `MatchViewState` and `AnimationQueue` with recorded event streams
(`tests/unit/match_ui/`, gate BLOCKING); **Observable** criteria are retained screenshots from the
U11 fixtures in `production/qa/evidence/` (UI gate, BLOCKING per coding standards).

**Logic (headless, no rendering)**

- [ ] **L1** GIVEN a recorded event stream of a full match, WHEN projected twice from `seq` 1,
  THEN the two `MatchViewState`s are field-for-field equal (projection is pure).
- [ ] **L2** GIVEN any stream, WHEN each event is applied, THEN hero health/armour, mana, deck
  counts, hand ids and board tokens equal the `MatchQuery` snapshot taken after the same `seq`
  (projection matches the engine at every step).
- [ ] **L3** GIVEN a boss `card_drawn` event, WHEN projected, THEN the boss hand count increments
  and no `card_id` is stored anywhere in the view-state.
- [ ] **L4** GIVEN an event of an unknown `type`, WHEN projected, THEN the view-state is unchanged
  except one feed line keyed `feed.unknown`, and no exception is raised.
- [ ] **L5** GIVEN four `minion_died` events sharing one `cause_seq`, WHEN projected, THEN exactly
  one `death_group` step and one `gap_close` step are produced, in that order.
- [ ] **L6** GIVEN a queue holding the steps of a 30-event burst, WHEN skip-all is invoked after
  step *k* for every *k* in 0..30, THEN after the flush every presenter-facing value equals the
  view-state (U4.6 invariant) and every `apply_final` ran exactly once in `seq` order.
- [ ] **L7** GIVEN `anim_speed = fast` (`SPEED_DIV` 2.0), WHEN `d_eff` is computed for every base
  duration, THEN each equals `d_base / 2` and hit-stop / shake / slow-down extras are 0; GIVEN
  `normal`, THEN each equals `d_base`.
- [ ] **L8** GIVEN a boss turn with A = 12 groups and D = 7.0 s at defaults, WHEN F4 runs, THEN
  gap = 0.245 s (±0.001) and T = 10.0 s; GIVEN A = 30, D = 15 s, THEN k = 0.509 and T = 10.0 s.
- [ ] **L9** GIVEN a player-side `command_rejected` diagnostic, WHEN projected, THEN no view-state
  field other than `feed_lines` changes, exactly one `reject_shake` step with the code is produced
  and exactly one `feed.command_rejected` line is appended; GIVEN a boss-side `command_rejected`,
  THEN no step and no line.
- [ ] **L10** GIVEN n = 10 and n = 3, WHEN F1 runs, THEN spacings are 72.2 px and 158 px, end-card
  rotations ±15° and ±4°, and no card centre lies outside the hand zone.
- [ ] **L11** GIVEN a command group with 10 `damage_dealt` on distinct targets from one source,
  WHEN steps are built, THEN they coalesce into one pop step; GIVEN 7, THEN seven steps.
- [ ] **L12** GIVEN `events_since(0)` of a match that ended in `Choice` for the player, WHEN
  projected with `anim_speed = instant`, THEN the resulting view state is `ChoiceOpen` with 3
  options and the queue is empty.
- [ ] **L13** Performance: projecting 2,000 events completes in < 50 ms; a skip-all over 200
  pending steps completes in < 100 ms; every `MatchQuery` call returns in ≤ 2 ms on a 7 v 7 board.
- [ ] **L14** No hardcoded values: every constant in F1–F5 and every `d_base` is read through
  `config("match_ui")`; a test that injects a config with `HAND_W = 700` changes F1's output.
- [ ] **L15** GIVEN the queue drains at time *t* in `PlayerTurn.Main` **with no playable card lit**
  (so `Idle` focus lands on End Turn, U5), WHEN `Space` is pressed at *t* + 100 ms, THEN
  `InputRouter` forwards nothing to `submit`; WHEN pressed at *t* + 300 ms (`end_turn_arm_ms`),
  THEN exactly one `end_turn` is submitted; a simulated click on the button at *t* + 0 ms submits
  `end_turn` (never gated). GIVEN instead a playable card is lit (focus on it), WHEN `Space` is
  pressed at *t* + 300 ms, THEN nothing is submitted, and `Enter` enters `KeyTargeting` for that
  card.
- [ ] **L16** GIVEN `settings.action_delay_ms = 1200` and a boss turn with A = 5, D = 2.5 s,
  WHEN F4 runs, THEN gap = 1.2 s and T = 7.6 s; GIVEN the setting absent, THEN gap = 0.6 s
  (Boss AI's `presentation.action_delay_s`).
- [ ] **L17** GIVEN a playable card, WHEN a press-and-release moving < 8 px lands on it, THEN the
  view enters `KeyTargeting` with `entered_by = pointer` and no command is submitted; WHEN a second
  click lands on a lit slot, THEN exactly one `play_card` is submitted; WHEN `Esc` or a click on
  empty table follows instead, THEN nothing is submitted.
- [ ] **L18** GIVEN `ai_decision`, `ai_plan_aborted` and `ai_fault` events (`diagnostic: true`) and
  the silent-set events `turn_reset` and `card_to_graveyard`, WHEN projected without `--ai-debug`,
  THEN no step, no feed line and no view-state change (the debug overlay buffer excepted); GIVEN
  `counter_changed{source_id, key, value}`, THEN `counters[source_id][key] == value`, exactly one
  `feed.counter_changed` line and no step.

**Observable (retained screenshots; each names its fixture)**

- [ ] **O1** GIVEN `--fixture=hand_10`, WHEN captured, THEN ten cards are visible with every cost
  stamp and attack stamp unobscured, the centre card highest, every card centre within x 315–965,
  no card pixel left of x 188 or right of x 1092, and no card pixel over the mana bar zone
  (x ≥ 1060, y ≥ 652) or the treasure chips (x ≤ 162).
- [ ] **O2** GIVEN `hand_10 --pose=hover:<id>`, WHEN captured, THEN the hovered card is 225x315,
  upright, bottom on the baseline, on top of its neighbours, and the neighbours have not moved.
- [ ] **O3** GIVEN `midgame_full_board`, WHEN captured, THEN 7 tokens per side sit in the F6 rows
  with 8-px gaps, each showing attack and health numerals ≥ 14 px, and portraits, mana bar, deck
  piles and End Turn occupy their F6 zones with no overlap.
- [ ] **O4** GIVEN `targeting_taunt --pose=drag:<attacker>`, WHEN captured, THEN the Bezier arrow
  runs from the attacker to screen centre, only Taunt minions carry the `state_target` outline, and
  the boss hero is not outlined.
- [ ] **O5** GIVEN `targeting_stealth --pose=drag:<attacker>`, WHEN captured, THEN the Stealth
  minion shows its badge and no outline.
- [ ] **O6** GIVEN `mulligan`, WHEN captured, THEN three 225x315 cards are centred over a dimmed
  table with keep/replace toggles and an enabled Confirm button.
- [ ] **O7** GIVEN `choice_discover` and `choice_choose_one`, WHEN captured, THEN three options and
  a Confirm are shown and the End Turn button is disabled.
- [ ] **O8** GIVEN `boss_intent_full`, WHEN captured, THEN the banner above the boss portrait shows
  an intent icon, amount and a reticle on the named target; GIVEN `boss_intent_plan_changed`, THEN
  the "plan changed" label is visible.
- [ ] **O9** GIVEN `boss_turn_playback --pause-at=<seq>`, WHEN captured mid-turn, THEN the End
  Turn button is disabled, the skip hint is visible, and the hand is dimmed to `table_dark`.
- [ ] **O10** GIVEN `--pose=reject:MUST_ATTACK_TAUNT`, WHEN captured, THEN the tooltip text is
  the localised reason and the Taunt minions are flashed.
- [ ] **O11** GIVEN `fatigue_and_burn`, WHEN captured, THEN the player deck pile reads "Fatigue:
  next N" and the feed ticker names the burned card.
- [ ] **O12** GIVEN `divine_shield_hit --pause-at=<seq>` on the shield-pop step, WHEN captured,
  THEN a ring burst is visible and no damage number is shown on that target.
- [ ] **O13** GIVEN `match_end_victory`, `match_end_defeat`, `match_end_both_dead`,
  `match_end_concede`, WHEN captured, THEN each banner carries its own copy and the winning hero
  portrait (if any) is saturated to its primary; GIVEN `match_end_fault`, THEN the banner reads the
  `end.fault` "floor replayed, not lost" copy, neither portrait is saturated, and the audio log
  shows no `sfx.ui.defeat`.
- [ ] **O14** GIVEN `--pose=feed:open` on `simultaneous_deaths`, WHEN captured, THEN the deaths are
  indented under their command root and a chain longer than 6 shows "+N more".
- [ ] **O15** GIVEN `--pose=menu:settings`, WHEN captured, THEN volume sliders, the `anim_speed`
  selector and the `reduce_motion` toggle are visible and the match behind is still rendered.
- [ ] **O16** GIVEN any fixture, WHEN the window is 1920x1080 or 1024x768, THEN the capture is
  letterboxed with the F6 grid intact and no element clipped (`ui-code.md`: min and max resolutions).
- [ ] **O17** GIVEN any fixture, WHEN every interactive element is reached by keyboard only
  (`Tab`, numbers, `Enter`, `Space`, `Esc`), THEN for each state the `MatchViewState` and
  `InputRouter` state after the keyboard path equal those after the mouse path (headless
  assertion), and the `--pose=focus:*` / `select:*` captures are retained beside their `hover:` /
  `drag:` pairs with the focus ring as the only permitted pixel difference.
- [ ] **O18** GIVEN `turn1_player --pose=focus:hero_power` with the power `Blocked`, WHEN captured,
  THEN a 2 px `state_actionable` ring sits 3 px outside the button and the tooltip names the
  `Blocked` reason without any pointer hover; GIVEN `--pose=focus:0` (first hand card), THEN the
  ring and the 1.5x preview are both visible; GIVEN `treasure_tray --pose=focus:treasure:1`, THEN
  the chip's tooltip is shown and its hit rect (debug outline) measures 44x44 around the 40 px chip.
- [ ] **O19** GIVEN `choice_discover`, WHEN `Esc` is pressed, THEN the Choice overlay is still open
  with its options unchanged and the pause menu is open above it; the same holds for `mulligan`.
  GIVEN `match_end_victory`, WHEN `Esc` is pressed, THEN the view state is still `Ended`, no pause
  menu is open and the capture is pixel-identical to the un-pressed one (DD-X09).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Event names: match-rules C15 is authoritative and rng-event-log §D was realigned to it on 2026-11-03 (`mulligan_resolved`, `crystal_gained`/`mana_refilled`/`mana_spent`/`mana_added`, `weapon_destroyed`, `healed`). `choice_requested` (Match Rules, the phase) and `discover_offered` (Card Effects, the options) are two events, not two names — U3 pairs them. ~~Remaining: delete the legacy aliases from U3 and place the five new primitive events.~~ | — | — | Resolved 2026-11-03 — cross-review C-07 (DD-X04): aliases deleted; `keyword_removed`, `card_added_to_deck`, `weapon_durability_changed`, `hero_power_refreshed`, `card_discarded` are in the U3 table |
| ~~`assets/data/match_ui.json` needs a DD-T01 row and a loader hand-off~~ — DD-T01 lists it; card-database CR-1 loads it as a config file read via `config("match_ui")`. | — | — | Resolved 2026-11-03 |
| boss-ai.md gives `intent_banner_s` two values: 1.2 s in the `ai_profiles.json` sketch and 300 ms in its Impact Moments table (no Tuning Knobs row). F4, U6 and L8 assume 0.3 s. | — | — | Resolved 2026-11-03 — cross-review C-30: boss-ai Tuning Knobs now carries `intent_banner_s` 0.3 and `plan_changed_s` 1.2; L8's numbers stand |
| run-ui.md's settings screen labels `anim_speed` as `instant \| fast \| normal` and adds an "action delay" slider (0–2000 ms, "Match UI pacing"). | — | — | Resolved 2026-11-03 — DD-X07 (cross-review C-01): the labels win (F3 `SPEED_DIV` maps them); Match UI consumes `action_delay_ms` as the F4 override of Boss AI's `presentation.action_delay_s` |
| `telegraph_mode` is a settings key Run UI lists and Meta stores; Boss AI's `intent_mode` is per-boss data. Who owns the player-side banner mode? | — | — | Resolved 2026-11-03 — DD-X03 (cross-review C-01): Boss AI owns `effective_mode = min(intent_mode, telegraph_mode)` and emits it on `ai_intent_*`; this GDD renders what Boss AI emits and never reads `telegraph_mode` |
| `ui-code.md` rules 3 and 7 make gamepad input, scalable text and colourblind modes mandatory; this GDD ships v1 keyboard + mouse only (technical-preferences: gamepad partial), `high_contrast_states` and `text_scale` as stored settings (DD-X07; the thumbnail-reflow vs reading-panel choice for `text_scale` is accessibility-requirements' open question). Record the v1 gamepad deferral in `ui-code.md` / technical-preferences, or pull it into MVP? | Jacob | Pre-Production | Open |
| Gamepad mapping (post-v1): does keyboard targeting (U5) map 1:1 to stick + buttons, or does a cursor-emulation mode serve better? | `/ux-design accessibility` | Alpha | Deferred — post-v1 |
| Accessibility tier: motion reduction (drop shake/hit-stop), high-contrast state set, text scale — which are MVP vs Alpha? | — | — | Resolved 2026-11-03 — `design/accessibility-requirements.md` Visual table: `reduce_motion` Comprehensive (elevated), `text_scale` 100/125/150 % and `high_contrast_states` Standard, all Pre-Production scope per its Test Plan; this GDD reads the three keys (Interactions) and applies `reduce_motion` (F3, Impact Moments); how `text_scale` (reading panel) and `high_contrast_states` (token swap) render is `/ux-design hud` / `hand` |
| Who owns settings persistence at MVP when Meta Progression is Vertical Slice — session-local (this GDD's default) or a tiny `user://settings.json` written by Run UI? | Meta Progression GDD (Designed; M9) | Vertical Slice | Provisional: session-local |
| Hover preview overlaps the player's board row (F2). Acceptable, or should the preview anchor beside the hand when the board is full? | `/ux-design hand` | Pre-Production | Open |
| `intent_mode = hidden` (band 3): show an empty banner frame ("?") or no banner at all? | Boss AI / Content | Alpha | Provisional: "?" frame so the HUD layout is stable |
| Tween/animation implementation (Godot `Tween` vs `AnimationPlayer` vs custom stepper driven by the queue) and the scene partition in U1 | `/architecture-decision` | Technical Setup | → becomes an ADR |
| Mid-match save/resume is out of v1 (match-rules); the `events_since(0)` fresh-view path already supports it — confirm when Run Structure revisits DD-R08. | Run Structure | Vertical Slice | Deferred |
