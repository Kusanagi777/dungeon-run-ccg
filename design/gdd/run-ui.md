# Run UI

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Review
> **REVISED 2026-11-03** (`/design-review`, lean, option A — revised without a new owner decision): (1) Reward Draft contract aligned to reward-draft.md D1/D8/D9/D11 — `draft_offered{floor, kind, option_ids[], flags[]}`, 1–3 options (`short`), empty offers never reach the shell, `TreasureDef.tags` (not `synergy_tags`), Reward Draft's own synergy numbers, `allow_skip` "Take nothing"; (2) Meta Progression contract aligned to meta-progression.md M1.3/M3.6/M9 — real API names (`unlock_progress`, `stats_for_hero`, `run_log(offset, limit)`, `get_settings`, `pending_notifications` + `ack_notification`, `reset_profile(confirm_token)` with **typed** confirm), `unlock_granted` payload, load-status message and ReadOnly banner, boot waits on `load_profile`, settings screen carries M9's keys; (3) Match UI handoff renamed to `match_view_finished(result)` with the 4 s auto-advance (match-ui.md, confirmed); (4) missing `match → boss_intro` transition on `match_faulted` added (S11b); (5) ui-code rule 7/8: `text_scale` setting and a min/max-resolution AC; (6) art bible §4 fixes — no identification colour as text on a toast, no `state_buff` animation on the deck count; (7) UX spec names aligned to `draft-picker.md`; stale "(concurrent)/(planned)" markers and `max_archived_runs` → `run_log_cap`. Cross-GDD items left open are listed under Open Questions.
> **REVISED 2026-11-03 (cross-review)**: C-08 (event envelope `{seq, turn, type, payload, cause_seq}`), C-12 (`suspend()` adopted by run-structure T21 — pause "Quit to menu" wired, S23), C-20 (Meta defers toast timing to F3), C-30 (`E_HERO_LOCKED`), C-01 / DD-X03 / DD-X07 consumer wording (Meta owns the settings record incl. `reduce_motion`; Match UI and Boss AI read it; `telegraph_mode` → Boss AI `effective_mode`), C-11 / DD-X02 (pre-select confirmed), S-04 ("Attempt n" subtitle on a replayed floor), S-05 (unlock toasts persist across shell transitions, AC-32); accessibility-requirements / interaction-patterns resolutions — F3 toast floor 5000 ms / cap 8000 ms with hover/focus pause and one toast at a time, 2 px `state_actionable` focus ring (3 px offset), `1`/`2`/`3` + Enter and Tab focus cycle on every pick, `text_scale` as three discrete steps (100 / 125 / 150 %).
> **REVISED 2026-11-03 (ux-review)**: (1) U2 / U9 / UI Requirements: victory and defeat summaries carry a compact per-floor strip (8 cells, `attempt > 1` marked, killing boss ringed on defeat); `summary_abandoned` stays one line + New Run · Main Menu; (2) U10 fixtures `abandoned_sample`, `draft_treasure_short`, and the `text_scale` 1.5 variants `draft_bundle_sample_ts150`, `locked_heroes_ts150`, `victory_sample_ts150`; (3) settings screen, Interactions Meta row, Tuning Knobs and UI Requirements: `gamma` slider 0.8–1.4, default 1.0 (DD-X10); (4) U2 / U7 / UI Requirements hero select: stats line in the fixed format "NW · NL · best FN" (wins, losses, best floor) and a one-line set blurb under the identity line.
> **REVISED 2026-11-03 (housekeeping)**: `E_PHASE` → run-structure's `E_BAD_PHASE` (Core Rules `pause` row, Cross-References); U7 pre-selection calls Meta `last_hero_id()` (M1.3), `null` → War, instead of "there is no `last_hero_id`"; AC-26 cites `.claude/docs/technical-preferences.md` Platform Notes target hardware and requires the evidence note to record the measuring machine.
> **REVISED 2026-11-03 (cross-review b)**: N-02 — States table terminal row and S16 read the outcome from Run Structure's nested `result` record (`run_ended{result.outcome}`, `result.outcome: victory | defeat`) instead of a flat `outcome` / `victory|defeat` shorthand, matching run-structure R1 and the RNG catalogue §D row.
> **Author**: Jacob (owner) + `/design-system` (guided, lean, tier standard, docs.density balanced)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 3 (lose fast, learn fast — restart under five seconds, every summary legible); Pillar 4 (readable, deterministic — the seed is on every summary); retention hooks "Curiosity" and "Investment" (locked silhouettes, run log, per-hero wins)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` No Agent tool in this session: `game-designer` / `ux-designer` / `ui-programmer` / `art-director` (Sections C, Visual/Audio), `systems-designer` (D, E), `qa-lead` (H) not consulted — review manually before production.
> **Scope note**: this GDD is the *system-level* contract for every screen outside the match — screen inventory, the screen state machine, intents, timing budgets, layout rules. Per-screen pixel specs come later from `/ux-design` into `design/ux/`; stories cite those specs, not this file.
> **Engine claims**: Godot 4.7.2; `docs/engine-reference/godot/modules/ui.md` read (4.6 dual-focus: keyboard focus is separate from mouse hover — every pick must be reachable by both). Screenshot procedure from `.claude/docs/run-and-observe.md`.

## Summary

Run UI is every screen outside a match — main menu, hero select, boss intro, the treasure and
bundle drafts, the floor progress strip, victory and defeat summaries, run log, settings, resume
prompt, toasts and the data-error screen — built as one `RunShell` whose screen states mirror
Run Structure's phases. Screens are display-only and send intents (`start_run`, `begin_match`,
`pick(index)`, `continue`, `abandon`, …) to a `RunController` that issues Run Structure commands
and renders the event stream back. It exists to make Pillar 3 true on screen: a legible loss and
a restart in under five seconds (1.35 s on the same-hero path), with every draft and summary
keyboard-reachable and every screen reachable from a launch argument for screenshots.

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `Run Structure, Reward Draft, Meta Progression, Card Database, RNG & Event Log, Match UI (handoff)`

## Overview

Run UI is every screen the player sees outside a match: the main menu, hero select, the boss
intro before each floor, the two reward drafts after a win (treasure, then bundle — DD-R04/R05,
run-structure R5), the floor progress strip that persists across all run screens, the victory
and defeat summaries, the run log, settings, the resume prompt, the unlock toast and the
data-error screen Card Database hands to it. Technically it is one `RunShell` scene holding a
screen stack whose states mirror Run Structure's phase machine; every screen is display-only
(`.claude/rules/ui-code.md`) and sends **intents** — `start_run(hero_id, seed_input)`,
`begin_match`, `pick(index)`, `continue`, `abandon`, `return_to_menu` — to a `RunController`
that forwards them as Run Structure commands and renders the run-scope event stream back into
read models. For the player it is the pacing of a run: the quiet pause of a boss intro, the
thirty-second greed of a draft, the one-click restart after a death. It exists because Pillar 3
is a UI promise as much as a rules one — a loss only "teaches fast" if the summary is legible
and the next run is under five seconds away — and because the draft (Pillar 1) is a decision the
player makes *through* these screens; the rules merely record it. Which Godot scene-stack or
signal-bus pattern implements the shell → becomes an ADR.

## Player Fantasy

Direct: the player operates these screens dozens of times per session, so the fantasy is **a
dungeon that is always ready for you**. Hero select should feel like choosing a tool from a rack
(three lit panels, the plan visible before committing — heroes.md UI Requirements); the boss
intro like reading the puzzle on the door before opening it (Pillar 2: the passive text is the
puzzle, so it is the brightest thing on the screen); the draft like greed with a clock in your
head and not on the screen (art bible §2); the defeat summary like a receipt, not a punishment —
"I see why", cold and factual, with the seed to prove it (Pillar 4) and *Run again* already
focused so Enter restarts. Reference feelings: Slay the Spire's death screen and run history (the
loss is information), Hearthstone Dungeon Run's bundle reveal (three choices, nothing else lit),
and speedrun reset culture (the restart is a reflex, never a menu crawl). Anti-reference: any
unskippable summary animation, any "are you sure?" between a death and the next hero select.
`creative-director` not consulted — Lean mode (and no Agent tool).

## Detailed Design

### Core Rules

`game-designer`, `ux-designer`, `ui-programmer`, `art-director` not consulted — Lean mode (no
Agent tool). All durations, sizes and counts below are read from `assets/data/run_ui.json` (new
file; Open Questions) or the art-bible theme resource, never hardcoded.

**U1 — Architecture: one shell, display-only screens, intents out, events in.**
1. `RunShell` is the single root scene for everything outside a match. It owns a **screen stack**
   (one base screen plus zero or more overlays) and a `ShellState` (States and Transitions).
2. `RunController` is the only object that talks to Run Structure, Reward Draft and Meta
   Progression. Screens never hold a `RunState`; they receive a **read model** (a plain
   Dictionary built from `RunState` and the run-scope events) and send **intents**. An intent is
   `intent(name: StringName, args: Dictionary)`; the controller validates the shell state, maps
   the intent to a command (U2 table) and either forwards it or drops it with a
   `ui_intent_rejected{name, reason}` debug event. No screen mutates game state (ui-code rule 1).
3. Every state mutation the player sees is rendered **from an event** (DD-T04): `run_floor_entered`
   → boss intro; `draft_offered` → draft screen; `deck_grew` / `treasure_granted` → strip update;
   `run_ended` → summary; `run_warning` → toast. The controller never infers state from its own
   last command.
4. All user-facing text is a localisation key resolved through `tr()`; data text (`text.en`,
   boss `intro_text.en`, bundle theme label) follows Card Database's rule (key if a string table
   exists, else `text.en`). No literal string in a screen script.

**U2 — Screen inventory.** Base screens (B) replace each other; overlays (O) stack on a base.
Intents are the complete set a screen may send; the command column is what `RunController`
issues (run-structure Core Rules, Meta/Reward contracts marked).

| Id | Kind | Screen | Shows | Intents → command |
|---|---|---|---|---|
| `main_menu` | B | Main Menu | New Run · Continue (only when `load_active_run()` is non-null: hero, floor "n of F", phase, last played — `active_run` header fields only, Meta UI Requirements) · Run Log · Settings · Quit; profile stats line (runs, wins, best floor — `stats` from the loaded profile, Meta M7); **load-status line, once per launch**, when Meta's `load_profile().status` ∉ {`OK`, `FRESH`} ("restored from backup" / "profile could not be read, a copy was kept" / "saved by a newer version", Meta M5); **ReadOnly banner** (persistent top strip, "another copy is open" with Retry, or "newer version") while the profile is `ReadOnly` (Meta M6) | `new_run_requested` → open `hero_select` (T1) · `continue_requested` → open `resume_prompt` · `open_run_log` · `open_settings` · `retry_lock` → Meta Retry (re-check the lock) · `quit_requested` → flush settings, quit |
| `resume_prompt` | O | Resume prompt | "Active run found: <hero>, floor n of F, <phase>" · Continue · Abandon (with "Abandon counts as a loss" line, run-structure R6) | `continue` → `resume()` (T15/T16) · `abandon` → `confirm` then `abandon()` (T13) · `back` |
| `hero_select` | B | Hero Select | Launch heroes as lit panels (name, identity line, set blurb line, colour, hero power name/cost/text, starter-deck preview strip, stats line "NW · NL · best FN" from Meta `stats_for_hero(hero_id)` — U7); locked heroes as desaturated silhouettes with lock glyph, condition text and progress from Meta `unlock_progress(HeroDef.unlock.key)` (M1.3, F6) — shown **only for `HeroDef`s present in data**; seed field (if `allow_custom_seed`) with normalised hex echo; Start; Back | `select_hero(hero_id)` (local, no command) · `start_run(hero_id, seed_input)` → `new_run(hero_id, seed_input)` (T2; after `confirm` if an active run exists) · `back` (T3) |
| `run_start` | B | Run Start transition | Hero colour panel, "Seed <hex16>" (`text_muted`), `run_start_ms` long, skippable | none (auto-advances on `run_floor_entered`; any input skips the remaining time) |
| `boss_intro` | B | Boss Intro | "Floor n of F", band indicator (1–3 pips in band colour, art bible §2), boss portrait placeholder (120x160 band-colour rectangle, initial), name, intro line, **passive text (brightest element)**, boss health, player's hero power text, deck size; subtitle "Attempt n" under the floor line when the read model's `attempt > 1` (a replayed floor after `match_faulted` — "the floor is replayed, not lost", Pillar 4; cross-review S-04); Fight | `begin_match` → `begin_match` (T5) · `open_pause` |
| `match` | B | Match (handoff) | Match UI scene; Run UI is hidden, not freed; the strip is not shown (Match UI owns the HUD) | none; control returns on Match UI's `match_view_finished(result)`, emitted after its end banner on a click or after `MATCH_END_AUTO_S` (4 s) — match-ui.md Core Rules "Match end", **confirmed**. Run Structure has already processed `match_ended` (T6–T9) by then; the shell reads the next run-scope event (S11) |
| `draft_treasure` | B | Treasure Draft | Step indicator "Treasure → Bundle" (current step highlighted) + "floor n"; `len(option_ids)` treasure frames (1–3, spell slot layout, rarity pill, text) in `option_ids` order; on a `short` / `reoffer` flag the missing slots are dimmed placeholders with the one-line reason ("No more treasures in this run"); hover/focus hint "fits your plan" when Reward Draft's per-option `affine` is 1 (never the weight); Deck drawer (current deck list, scrollable, + held treasures); Pick; "Take nothing" only when `allow_skip` | `pick(index)` → `draft_pick(treasure, option_ids[index])` (T11) · `skip_pick` → `draft_pick(treasure, null)` (only when `allow_skip`) · `hover(index)` (local) · `open_deck_drawer` · `open_pause` |
| `draft_bundle` | B | Bundle Draft | Step indicator "Bundle" (or "Treasure → Bundle" with Bundle highlighted) + "floor n"; `len(option_ids)` bundle panels (1–3) each with theme label (`BundleDef.theme`), `BundleDef.text` pitch and 3 compact card rows; hover/focus a row → 1.5x card preview (225x315); hover/focus a panel → hint "N cards in your deck share *theme*" (Reward Draft `n_tag(theme)`) and "Deck 21 → 24" below the panels; `short` placeholders as above; Deck drawer; Pick; "Take nothing" only when `allow_skip` | `pick(index)` → `draft_pick(bundle, option_ids[index])` (T12) · `skip_pick` → `draft_pick(bundle, null)` (only when `allow_skip`) · `hover(index, card)` · `open_deck_drawer` · `open_pause` |
| `summary_victory` | B | Victory Summary | Hero (portrait saturates to primary — the one allowed saturation), "Floors cleared F of F", **compact per-floor strip** (F = 8 cells, one per `match_summaries` row: boss initial, cleared mark, `attempt > 1` cells marked "×n" — U9), seed hex + Copy, top `summary_top_cards` damage table, drafted cards (acquisition order, drafted marked), treasures, new unlocks (Meta contract), duration/turns; buttons **New Run (same hero)** [focused] · Hero Select · Main Menu | `new_run_same_hero` → `new_run(hero_id, "")` (T18) · `go_hero_select` → `return_to_menu` + T1 · `go_main_menu` → `return_to_menu` (T17) · `copy_seed` (local) |
| `summary_defeat` | B | Defeat Summary | As victory on `bg_edge` (torch out, art bible §2): "Fell on floor n — <boss>", reason (`hero_dead` / `both_dead` "the boss wins ties" / `concede` / `turn_cap`), the same compact per-floor strip with the **killing boss's cell** marked (`state_danger` ring, boss initial) and floors after it hollow, `attempt > 1` cells marked; same buttons, **New Run (same hero)** focused | as `summary_victory` |
| `summary_abandoned` | B | Abandon notice | One line (player abandon: "Run abandoned — counted as a loss"; system abandon: the reason, not a loss) + New Run · Main Menu | as summaries minus `go_hero_select` |
| `run_log` | B | Run Log | Archived runs from Meta `run_log(offset, limit)` (newest first, paged — Meta M8/UI Requirements): date, hero, result ("Victory" / "Defeat on floor n by <boss>" / "Abandoned"), floors "n of F", seed hex, "custom seed" tag, `attempt > 1` marker, "details unavailable" for opaque schema rows; header carries the per-hero stats and bests line ("random seeds only"); filter by hero (client-side over loaded pages); Open; Back | `filter_hero(hero_id \| null)` · `load_more` → `run_log(offset + limit, limit)` · `open_run(run_id)` → `run_detail` · `back` |
| `run_detail` | O | Run summary (archived) | The summary layout in read-only form, from the `ArchivedRun` already in the loaded page (there is no `get_run` — Meta M1.3); Copy seed; Back | `copy_seed` · `back` |
| `settings` | B/O | Settings | The DD-X07 player-settings record, owned and persisted by Meta Progression (M9), edited here and read by Match UI and Boss AI: master / music / SFX volume (sliders, 0–1), fullscreen, action delay (slider 0–2000 ms — `action_delay_ms`, consumed by Match UI pacing), animation speed (segmented select `instant` / `fast` / `normal` — each consumer maps the label to its own durations: F2 here, match-ui F3), reduce motion (toggle `reduce_motion` — fades only, no slides or shakes; independent of animation speed), text scale (segmented select **100 % / 125 % / 150 %** = `text_scale` 1.0 / 1.25 / 1.5, three discrete fixture-tested layouts, never a continuous slider — ui-code rule 7, accessibility-requirements Visual), boss telegraph mode (segmented select `full` / `brief` / `off` — consumed by Boss AI as `effective_mode = min(boss.intent_mode, telegraph_mode)`, DD-X03; `full` is the default), high-contrast state colours (`high_contrast_states`, art bible §4), **gamma / brightness** (slider 0.8–1.4, default 1.0, step 0.05 — `gamma`, DD-X10; applied live by Run UI and Match UI as a `CanvasModulate` brightness adjustment, never to colour tokens; a preview swatch row of `bg_edge` / `table_dark` / `table_lit` sits under the slider so the effect is visible on this screen), keep run records + "Clear run records" (confirm; Meta M8.2), Reset profile (**typed confirmation** — the player types the word shown; Meta M1.1 names it the one destructive action and `reset_profile(confirm_token)` takes the typed token); Back | `set_setting(key, value)` → Meta `set_setting` (M9 keys per DD-X07: `volume_*`, `fullscreen`, `action_delay_ms`, `anim_speed`, `reduce_motion`, `text_scale`, `telegraph_mode`, `high_contrast_states`, `gamma` (DD-X10), `keep_run_records`, plus `language`) · `clear_run_records_requested` → `confirm` → Meta "Clear run records" · `reset_profile_requested` → typed `confirm` → Meta `reset_profile(token)` · `back` |
| `pause` | O | Pause (between matches) | Resume · Settings · Abandon run (confirm, "counts as a loss") · Quit to menu (the run stays saved at S1–S4 and reappears as Continue) | `close` · `open_settings` · `abandon` → `confirm` → `abandon()` · `go_main_menu` → `suspend()` (run-structure T21 / R8.7, cross-review C-12: drops the in-memory `RunState` with no event and no save — the last S-save is the resumable state — legal in `hero_select`, `pre_match` and `post_match_reward`, `E_BAD_PHASE` elsewhere) (S23) |
| `confirm` | O | Confirm dialog | Title, body, Confirm / Cancel; Cancel focused by default; an optional typed-token field (Reset profile) keeps Confirm disabled until the text matches | `confirm(token?)` · `cancel` |
| `toast` | O | Unlock / warning toast | Queued one-at-a-time banner at top-right: unlock ("New hero unlocked: Fortune" + the unlock's condition as subtitle — Meta UI Requirements), `run_warning` codes (`save_failed`, `boss_pool_short`, …) | `dismiss` (local); an unlock toast calls Meta `ack_notification(key)` when shown (U5) |
| `data_error` | B | Data error | Card Database `Failed` report: count, rows (file, id, code, message) in a scrollable list, "Copy report", Quit; nothing else is reachable | `copy_report` · `quit_requested` |

**U3 — Input: mouse primary, keyboard complete.** DD-T05 and ui-code rule 3. Every intent is
reachable by keyboard: `1`/`2`/`3` move focus to option *n* on any 3-option screen (hero select,
both drafts) and `Enter` confirms the focused option; `Esc` = `back` / `close` / `cancel`;
`Space`/`Enter` on a focused button activates it; `Tab` / `Shift+Tab` cycle every focusable
control on the screen in the order the screen's UX spec Focus Order table lists (options or
panels left → right → hints → Primary → Secondary / Back → progress strip → treasure chips —
interaction-patterns Focus Management), so every pick action is reachable both by `1`/`2`/`3`
+ `Enter` and by `Tab` + `Enter`; on a draft `Tab` enters at option 1. **Focus ring**: every
focusable Control draws a 2 px `state_actionable` ring offset 3 px from its bounds, always —
including under `anim_speed = instant`; it is distinct from the "actionable" outline (which hugs
the bounds) by the 3 px gap, and hover is a lift with no ring (interaction-patterns Focus
Management; accessibility-requirements colour audit "focus vs hover"). Hover never carries
unique information (art bible §7): the hover preview duplicates card text, the synergy hint is
also shown under the focused treasure. Default focus per screen is the **most likely next
action**: Start on hero select (with the last-played or War pre-selected), Fight on the boss
intro, nothing on a draft (forcing a choice), *New Run (same hero)* on both summaries, Cancel on
every confirm. Gamepad
maps to the same focus graph (`ui_accept`, `ui_cancel`, d-pad as focus neighbours); engine
reference: keyboard focus is separate from mouse hover in 4.6+, so a hovered card that is not
focused is highlighted but not "selected" — selection is focus or click, never hover.

**U4 — Transitions and the input lock.** Each base-screen change runs a transition of
`t_transition` (F2). While `ShellState.transitioning` is true every intent except `skip` is
**dropped** (not queued) and a `ui_intent_rejected{reason: transitioning}` debug event is
emitted; `skip` ends the transition immediately (ui-code rule 4: every animation skippable;
`anim_speed = instant` makes `t_transition = 0`). A screen that has sent a terminal intent
(`pick`, `start_run`, `begin_match`, `continue`) enters its own `committed` sub-state and
ignores further intents until the controller swaps it out — this is what makes a double-click
on Pick a single pick (Edge Cases).

**U5 — Toast queue.** Toasts are enqueued from `run_warning` and from Meta's unlock
notifications, which have two forms (Meta M3.6, **confirmed**): the live signal
`unlock_granted{key, kind: hero|treasure|bundle, id, by_run_id, retro}` on the profile's bus, and
the durable queue `pending_notifications()` that the controller reads on `S1` (boot → menu) and
on every `run_ended`, so a grant whose toast never showed (crash, quit) is shown on the next menu
or summary. The toast text is built from `kind` + `id` through Card Database (`name`), never from
a `name_key` in the payload. When an unlock toast is **shown**, the controller calls
`ack_notification(key)` — once per key, so a key present in both the signal and the queue
produces one toast. Toasts are shown one at a time for `t_toast` (F3) **only while the shell is
idle**: `transitioning == false` and `ShellState ∉ {match, run_start, data_error}`. A toast
raised during a match or a transition waits; the queue drains in arrival order with a
`toast_gap_ms` pause. Toasts are never modal and never steal focus. Queue cap `toast_queue_max`
(default 8): beyond it the oldest *warning* is dropped first, unlocks are never dropped.
**Reading time** (accessibility-requirements "Reading time"; interaction-patterns Toast): exactly
one toast is visible at a time; it stays for `t_toast` ≥ 5 s (F3); hover or keyboard focus on
the toast **pauses** its timer; a click on it, or `Enter` while it is focused, dismisses it early;
a dismissed or expired unlock toast is still acked (it was acked on show). A warning toast is
never the sole channel: every `run_warning` is in the event log, and the latest *actionable*
warning (`save_failed`, `boss_pool_short`) is repeated as a status line on the next summary or
main menu. **Persistence across transitions** (cross-review S-05): an unlock toast that is
visible when a base-screen change begins is not freed with the base — it lives on the toast
layer, rides the transition (summary → `run_start` → `boss_intro`, and the `begin_match` handoff,
where the layer sits above the Match UI scene and clear of its intent banner) and is removed
only when its `t_toast` elapses or the player dismisses it. A *warning* toast caught by a
transition may be cut short (its content is also in the log and the status line). The idle rule
above governs when a *queued* toast may **start**, not when a showing one must stop.

**U6 — Progress strip.** A persistent overlay on `boss_intro`, `draft_treasure`, `draft_bundle`
and `pause`: `F` nodes left to right, each `cleared` (filled, boss initial shown), `current`
(ring in band colour, boss initial shown), or `upcoming` (hollow, **band colour only — never
the boss identity**, run-structure UI Requirements); treasure floors carry a small gem mark
under the node; held treasures as icons at the strip's left; deck size ("24 cards") at its
right. Geometry is F4; it is rendered from the read model (`floor`, `boss_sequence` masked to
`floor`, `treasures`, `len(deck)`), and updates on `deck_grew`, `treasure_granted`,
`run_floor_entered`. The strip, like every Run UI surface except the 150x210 card thumbnail,
scales its text with `text_scale` and must not clip or overlap at 150 % (AC-31).

**U7 — Hero select rules.** Panels are built from `HeroDef`s present in Card Database; a hero
is Available when Meta `is_hero_unlocked(id)` is true (MVP: always), else Locked (heroes.md
States). A locked panel shows the silhouette placeholder (neutral frame grey, lock glyph, name)
and its condition text with live progress ("Win a run with any hero — 0 / 1") from Meta
`unlock_progress(HeroDef.unlock.key) → {met, progress, parts}` (M1.3, F6; `parts` gives the
per-hero ticks for `each_launch`); it is focusable (so the hint is keyboard-reachable) but
`start_run` from it is not sent. If **no** locked hero exists in data (MVP), the locked row is
simply absent — no "coming soon" filler. Pre-selection: Meta `last_hero_id()` (M1.3 — the
argmax of `stats.heroes[*].last_played_at`); when it returns `null` (fresh profile) War (DD-X02: no hero is forced on any run; this GDD pre-selects, never forces —
heroes.md H-2 and run-structure.md now say the same, cross-review C-11). The
seed field accepts any text (RNG & Event Log F1 parses everything) and echoes
the normalised 16-hex form on edit; empty = random. Starting with an active run saved first
raises `confirm` ("This ends your current run — counted as a loss"). **Stats line** (ux-review
2026-11-03): each available panel's corner carries one line in the fixed format
`NW · NL · best FN` — wins, losses and best floor from Meta `stats_for_hero(hero_id)`
(`wins`, `losses`, `best_floor`; Meta M7 / UI Requirements) — e.g. "3W · 5L · best F8"; zeros
are shown ("0W · 0L · best F0" on a fresh profile), never hidden, and the line is ≤ 28
characters at three-digit counts. Under the identity line sits a one-line set blurb from
heroes.md UI Requirements ("War: weapons, aggression, armour").

**U8 — Drafts.** Contract with Reward Draft — **confirmed against reward-draft.md D1, D6–D9,
D11**: on `draft_offered{floor, kind, option_ids[], flags[]}` the controller builds
`len(option_ids)` options (1–3; `option_ids` is already id-sorted and is the display order): for
`treasure`, `TreasureDef` (name, rarity, text); for `bundle`, `BundleDef` (`theme` as the label,
`text` as the pitch, its 3 `CardDef`s). There are no `theme_labels` in the payload and no
`synergy_tags` field — the synergy hint uses Reward Draft's own per-option numbers from its
`Offer` read model (bundle: `n_tag(theme)` → "N cards in your deck share *theme*"; treasure:
`affine` → "fits your plan"; never a weight); if the read model lacks them the hint is hidden,
not blank. `flags[]` ⊆ `{pity_forced, coverage_forced, universal_forced, universal_missing,
reoffer, short}` is **never displayed** except that `short` / `reoffer` draw the empty slots as
dimmed placeholders with the one-line reason. An empty offer (`option_ids == []`) never reaches
the shell — Run Structure skips the step (reward-draft D8c) and the next event decides the
screen. `pick(index)` requires `0 ≤ index < len(option_ids)` and the screen not `committed`; the
controller sends `draft_pick(kind, option_ids[index])`; when `allow_skip` is true (default
false) a "Take nothing" control sends `skip_pick` → `draft_pick(kind, null)`. On
`treasure_granted` / `deck_grew` it plays the fly-to-strip animation, then transitions
(treasure → `draft_bundle`; bundle → `boss_intro` on `run_floor_entered`); a skipped bundle
emits no `deck_grew`, so the bundle screen transitions on `run_floor_entered` alone. A rejection
(`E_NOT_OFFERED`, `E_DRAFT_DONE`, `E_DRAFT_KIND`, `E_UNKNOWN_ID`) uncommits the screen and
shows a toast; it must never happen in normal play (`E_UNKNOWN_ID` is followed by a fresh
`draft_offered`, which rebuilds the screen).

**U9 — Summaries.** Built from `RunRecord.result`, `totals`, `match_summaries`, `drafts`,
`treasures`, `run_seed_hex` (run-structure R6/R10) plus Meta's `unlocks_granted[]` for this run
(contract). Victory and defeat share one layout and differ by palette (art bible §2) and
headline. **New Run (same hero)** is the default focus and sends `new_run(hero_id, "")`
immediately — no confirm, no second screen (Pillar 3; F1 budget). Copy seed writes the
16-hex string to the clipboard and flashes "Copied". **Per-floor strip** (ux-review
2026-11-03): both summaries carry a compact strip of `floors_per_run` cells (8; one 24-px cell
per floor, the same `node_d` as the progress strip, F4) built from `match_summaries` — a cleared
cell shows the boss initial on the band colour, a cell with `attempt > 1` carries a small "×n"
mark, and on a defeat the killing boss's cell is ringed `state_danger` with every later cell
hollow. It is read-only (no focus stop) and its tooltip / Card Inspect text variant on hover or
focus of the block names each floor's boss. `summary_abandoned` does **not** carry it — it stays
one line plus New Run · Main Menu (U2).

**U10 — Debug fixtures and screenshot reachability.** Per `.claude/docs/run-and-observe.md`,
every base screen is reachable from a launch argument: `--run-ui-screen=<id>
--run-ui-fixture=<name>` loads `tests/fixtures/run_ui/<name>.json` (a profile + optional
`RunRecord` + optional draft offer) into an in-memory Meta stub and opens the screen with no
transition. Debug-build only; ignored in export builds. Required fixtures: `fresh_profile`
(no runs, no active run, War only unlocked-and-present), `mid_run_floor4` (F = 8, floor 4,
2 treasures, deck 24, `pre_match`), `victory_sample` (full 8-floor record, 1 unlock granted),
`defeat_sample` (fell on floor 5, `attempt = 2` on floor 3, reason `hero_dead`),
`locked_heroes` (all six `HeroDef`s present, three locked with hints), `abandoned_sample` (a
player abandon from floor 3 — `summary_abandoned`, "counted as a loss"). Derived fixtures that
reuse those records: `draft_treasure_sample`, `draft_bundle_sample` (offers of 3),
`draft_treasure_short` (an offer of 1 with the `short` flag — two dimmed placeholder slots),
`resume_prompt` (from `mid_run_floor4`), `data_error_sample` (a 12-row validation report),
`toast_sample` (3 queued). **Settings variants** (`text_scale = 1.5` in the fixture profile,
everything else equal): `draft_bundle_sample_ts150`, `locked_heroes_ts150`,
`victory_sample_ts150` — the three layouts the 150 % reflow stresses most (compact card rows,
the locked-hero hint, the damage table); AC-31 captures them. Each fixture names the screens it
serves (Acceptance Criteria).

### States and Transitions

`ShellState` is the base screen plus the overlay stack and the `transitioning` flag. Base
states map onto Run Structure phases as shown; overlays do not change the mapped phase.

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| `boot` | App start | Card Database `Ready` ∧ Meta `load_profile()` returned → `main_menu`; Card Database `Failed` → `data_error` | Black `bg_edge`; no input; Meta's "Profile: Unloaded" loading frame (should be one frame) |
| `data_error` | Card Database `Failed` | Quit only | Terminal; report listed; nothing else reachable |
| `main_menu` | Boot OK; `return_to_menu`; back from run log / settings | Any menu intent | Run phase: Menu. Continue visible iff `load_active_run()` non-null |
| `hero_select` | New Run; `go_hero_select` from a summary | `start_run` accepted → `run_start`; `back` | Run phase `hero_select`; in-memory only |
| `run_start` | `run_started` event | `run_floor_entered` received and `run_start_ms` elapsed or skipped | Shows seed; phase `pre_match` (floor 1) |
| `boss_intro` | `run_floor_entered` (any floor, incl. resume into `pre_match`, `match_faulted`) | `begin_match` → `match`; `abandon` → `summary_abandoned` | Phase `pre_match`; strip visible; Fight focused |
| `match` | `begin_match` accepted | Match UI's `match_view_finished(result)` → `draft_treasure` / `draft_bundle` / `boss_intro` / `summary_*` per the run-scope event already received (`draft_offered` / `run_floor_entered` after `match_faulted` or a skipped step / `run_ended`) | Phase `in_match`; Run UI hidden; toasts held; run-scope events arriving while Match UI still shows its banner are **buffered** and applied at `match_view_finished` |
| `draft_treasure` | `draft_offered{kind: treasure}` | `treasure_granted` → `draft_bundle`; `abandon` | Phase `post_match_reward/treasure`; strip visible |
| `draft_bundle` | `draft_offered{kind: bundle}` | `deck_grew` + `run_floor_entered` → `boss_intro`; `abandon` | Phase `post_match_reward/bundle` |
| `summary_victory` / `summary_defeat` / `summary_abandoned` | `run_ended{result.outcome}` | `new_run_same_hero` → `run_start`; `go_hero_select`; `go_main_menu` | Terminal phases; toasts drain here (unlocks) |
| `run_log` / `run_detail` | Menu intent | `back` | Menu; read-only over archived records |
| `settings` | Menu or pause intent | `back` | Menu or overlay on a run screen; settings apply live |
| Overlays `resume_prompt`, `pause`, `confirm`, `toast` | Per U2 | Per U2 | Stack on the base; `Esc` closes the top overlay; `confirm` blocks the base's input, `toast` does not |

**Transition table** (every row implemented and tested; an intent not listed for a state is
dropped with `ui_intent_rejected{reason: bad_state}`):

| # | From | Intent / event | Guard | Effect | To |
|---|---|---|---|---|---|
| S1 | `boot` | Card Database `Ready` | — | build menu read model (`load_active_run`, profile stats) | `main_menu` |
| S2 | `boot` | Card Database `Failed{report}` | — | render report | `data_error` |
| S3 | `main_menu` | `new_run_requested` | — | read hero roster + unlock state | `hero_select` |
| S4 | `main_menu` | `continue_requested` | active run saved | push `resume_prompt` | +`resume_prompt` |
| S5 | `resume_prompt` | `continue` | — | `resume()`; on `OK` → T15 lands in saved phase; on error → reason dialog (T16) | `boss_intro` / `draft_*` / `main_menu` |
| S6 | `resume_prompt` | `abandon` | `confirm` accepted | `abandon()` (T13) | `summary_abandoned` |
| S7 | `hero_select` | `start_run(hero, seed)` | hero Available; not `committed`; if active run: `confirm` accepted | `committed`; `new_run` | `run_start` on `run_started` |
| S8 | `hero_select` | `start_run` rejected (`E_HERO_LOCKED`, `E_CONFIG`) | — | uncommit; toast with reason | `hero_select` |
| S9 | `run_start` | `run_floor_entered` ∧ (timer done ∨ `skip`) | — | transition | `boss_intro` |
| S10 | `boss_intro` | `begin_match` | not `committed`, not transitioning | `committed`; `begin_match`; hand `MatchConfig` to Match UI | `match` |
| S11 | `match` | `match_view_finished(result)` from Match UI | — | apply the buffered run-scope events in `seq` order; the last one decides: `draft_offered` → S12/S13; `run_floor_entered` → S11b; `run_ended` → S16 | — |
| S11b | `match` | `run_floor_entered` (after `match_faulted` — same floor, T9 — or after both draft steps were skipped as empty offers, reward-draft D8c) | — | rebuild the boss intro; on a fault show the toast `run_warning` carried ("the match was reset") and the intro subtitle "Attempt n" (`attempt > 1`, S-04) | `boss_intro` |
| S12 | `match` | `draft_offered{treasure}` | `len(option_ids) ≥ 1` (an empty offer never arrives — the run skips the step) | build `len(option_ids)` treasure options, placeholders for `short` | `draft_treasure` |
| S13 | `match` / `draft_treasure` | `draft_offered{bundle}` | `len(option_ids) ≥ 1` | build `len(option_ids)` bundle options, placeholders for `short` | `draft_bundle` |
| S14 | `draft_treasure` | `pick(i)` / `skip_pick` | `0 ≤ i < len(option_ids)` (or `allow_skip` for `skip_pick`); not `committed`; not transitioning | `committed`; `draft_pick(treasure, option_ids[i] \| null)`; on `treasure_granted` fly-to-strip | `draft_bundle` (S13) |
| S15 | `draft_bundle` | `pick(i)` / `skip_pick` | as S14 | `committed`; `draft_pick(bundle, option_ids[i] \| null)`; on `deck_grew` fly-to-strip; on `run_floor_entered` transition | `boss_intro` |
| S16 | `match` | `run_ended{result.outcome: victory \| defeat}` | — | build summary; focus New Run; enqueue unlocks | `summary_victory` / `summary_defeat` |
| S17 | `boss_intro`, `draft_*`, `pause` | `abandon` | `confirm` accepted | `abandon()`; `run_ended{abandoned}` | `summary_abandoned` |
| S18 | any `summary_*` | `new_run_same_hero` | not `committed` | `new_run(hero_id, "")` | `run_start` |
| S19 | any `summary_*` | `go_hero_select` / `go_main_menu` | — | `return_to_menu` | `hero_select` / `main_menu` |
| S20 | any run base screen except `match` | `open_pause` / `Esc` | — | push `pause` | +`pause` |
| S21 | any idle state per U5 | toast queue non-empty | `transitioning == false` | show head for `t_toast`, then `toast_gap_ms` | same |
| S22 | `main_menu` | `quit_requested` | — | flush settings (Meta contract); quit | — |
| S23 | `pause` (over `boss_intro` / `draft_*`) or `hero_select` | `go_main_menu` / `back` to menu | not transitioning | `suspend()` (run-structure T21: no event, no save; the saved run reappears as Continue) | `main_menu` |

### Interactions with Other Systems

| System | Direction | Data in (to Run UI) | Data out (from Run UI) | Interface owner |
|---|---|---|---|---|
| **Run Structure** | upstream (commands go down, events come up) | Run-scope events (`run_started`, `run_floor_entered`, `run_resumed`, `match_faulted`, `deck_grew`, `treasure_granted`, `run_warning`, `run_saved`, `run_ended`); `RunState` read model (floor, band via `floor_band`, `boss_sequence[0..floor−1]`, deck, treasures, `run_seed_hex`, summary data); rejection codes | Commands `new_run`, `begin_match`, `draft_pick`, `abandon`, `resume`, `suspend`, `return_to_menu` | Run Structure (R1–R10, T1–T21); this GDD owns the intent → command map (U2) |
| **Reward Draft** | upstream | `draft_offered{floor, kind, option_ids[] (1–3, id-sorted), flags[]}`; `draft_picked`; the `Offer` read model's per-option synergy numbers (`n_tag(theme)` for bundles, `affine` for treasures) | `pick(index)` → `draft_pick(kind, option_ids[index])`, `skip_pick` → `draft_pick(kind, null)` (only when `allow_skip`) via the run | **Confirmed against reward-draft.md** D1, D8, D9, D11, UI Requirements: 1–3 offers (`short`), `[]` skips the step inside the run; ids resolve in Card Database; `TreasureDef.tags` (not `synergy_tags`) is Reward Draft's request to Card Database — Run UI never reads tags itself. Reward Draft's UX flag names the spec `design/ux/draft-picker.md`; this GDD now uses the same name (UI Requirements) |
| **Meta Progression** | upstream | `load_profile().status` for the load-status line and ReadOnly banner; `load_active_run()` presence for Continue; `is_hero_unlocked(id)`; `unlock_progress(key) → {met, progress, parts}` (F6) with the condition text from the `unlock` object; `stats_for_hero(hero_id) → HeroStats` and `profile.stats` for the stats line; `run_log(offset, limit) → [ArchivedRun]` (newest first; the detail view reads the same rows — there is no `get_run`); `pending_notifications()` and the `unlock_granted{key, kind, id, by_run_id, retro}` signal; `get_settings()` | `set_setting(key, value)`, `ack_notification(key)`, `reset_profile(confirm_token)`, "Clear run records"; nothing else — all run writes go through Run Structure | **Confirmed against meta-progression.md** M1.3, M3.6, M5, M6, M7, M8, M9: the settings record is the DD-X07 key set — `volume_master/music/sfx` (0–1), `fullscreen`, `action_delay_ms` (0–2000), `anim_speed` (`instant\|fast\|normal`), `reduce_motion`, `text_scale` (1.0 \| 1.25 \| 1.5), `telegraph_mode` (`full\|brief\|off`), `high_contrast_states`, `gamma` (0.8–1.4, DD-X10), `keep_run_records`, `language` — Meta owns and persists it, Run UI edits it, Match UI and Boss AI read it via `get_settings()` / `settings_changed` (cross-review C-01); corrupt save → reason + New run (run-structure R8, Meta M5.4: a system abandon, not a loss) |
| **Card Database** | upstream | `HeroDef`, `HeroPowerDef`, `BossDef` (`name`, `intro_text`, `passive` text, `health`), `TreasureDef`, `BundleDef`, `CardDef`; `data_version`; the `Failed` validation report `[{file, id, code, message}]` | — (read-only) | Card Database (CR-3, UI Requirements) |
| **RNG & Event Log** | upstream | Event envelope `{seq, turn, type, payload, cause_seq}` (rng-event-log rule 11; `cause_seq` groups the summary's lines the way Match UI groups its feed); `run_seed_hex` display form; F1 seed parsing (the UI only echoes the normalised form) | — | RNG & Event Log |
| **Match UI** | sibling (handoff) | `match_view_finished(result)` after its end banner (click or `MATCH_END_AUTO_S` = 4 s); Match UI owns everything from `begin_match` to that signal | `MatchConfig` (built by Run Structure R3, passed through), the `match` scene swap, the shared pause-menu settings panel. Settings are **not** handed over: Match UI reads `anim_speed`, `reduce_motion`, `text_scale`, `high_contrast_states`, `action_delay_ms` and volumes from Meta's record itself (DD-X07; match-ui Interactions "Meta Progression") — Run UI only edits that record | **Confirmed against match-ui.md** Core Rules "Match end", States `Ended`, Dependencies: the banner auto-advances, it does not navigate, and Match UI "does not know about floors or drafts" |
| **Heroes** | upstream (data) | Identity line, colours (art bible §4), hero power text, starter deck for the preview strip; Locked/Available states | — | Heroes (H-2, H-7, UI Requirements) |
| **Boss AI** | indirect (consumer of a setting this GDD edits) | — | none directly: Run UI writes `telegraph_mode` to Meta's settings record; Boss AI reads it via `settings_changed` and clamps its per-boss `intent_mode` to it, `effective_mode = min(boss.intent_mode, telegraph_mode)` over `full > brief ≡ class_only > off ≡ hidden` (DD-X03, boss-ai C8.4); Match UI renders what Boss AI emits | Meta owns the setting (DD-X07); Boss AI owns `effective_mode`; Run UI owns only the control |
| **Art bible** | data | Tokens (§4), mood per state (§2), card slot layout (§4) | — | art-director |

## Formulas

`systems-designer` not consulted — Lean mode (no Agent tool). Formulas are required here
because the system defines timing budgets and layout rules a later pass will tune.

### F1. Restart-time budget (Pillar 3; run-structure AC-29)

The `t_restart` formula is defined as:

```
t_restart(path) = Σ t_machine(step) + Σ t_human(step)                 over the path's steps
path A (defeat → New Run same hero):   fade_out + new_run + run_start + intro_ready
path B (defeat → Hero Select → Start): fade_out + select_ready + t_human_pick + new_run
                                       + run_start + intro_ready
constraint:  t_restart(A) ≤ restart_budget_ms  and  t_restart(B) ≤ restart_budget_ms
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| restart_budget_ms | int | 3000 – 5000 | data file (default 5000) | Concept: "a loss returns to hero select in under five seconds" — read here as death summary → first boss intro |
| fade_out | int ms | 0 – 400 | data file (`transition_ms.fade`, 250) | Summary → next screen, skippable |
| new_run | int ms | 0 – 300 | measured (budget 200) | Run Structure R2: seed, RNG, boss sequence, S1 save |
| run_start | int ms | 0 – 1000 | data file (`run_start_ms`, 600) | Seed card; skippable; 0 at `anim_speed = instant` |
| intro_ready | int ms | 0 – 300 | measured (budget 300) | Boss intro built from `run_floor_entered` and visible |
| select_ready | int ms | 0 – 300 | measured (budget 300) | Hero select built (roster, previews) and focused |
| t_human_pick | int ms | 500 – 1500 | assumption (1500 for the budget) | Player presses Enter on the pre-selected hero; 0 if they only confirm |

**Output Range:** path A at defaults = 250 + 200 + 600 + 300 = **1350 ms**; path B = 250 + 300
+ 1500 + 200 + 600 + 300 = **3150 ms**; both under 5000 with ≥ 1850 ms headroom. At
`anim_speed = instant` path A is 500 ms. The measured steps (`new_run`, `intro_ready`,
`select_ready`) are the only ones that can grow; a profile run reports them per build.
**Example:** a player who dies on floor 5 and presses Enter twice (New Run focused, Fight
focused) is fighting floor 1 after 1350 ms + one more Fight click — no menu visited.

### F2. Transition duration

The `t_transition` formula is defined as:

```
t_transition(kind) = round(base_ms[kind] × speed_factor[anim_speed])
speed_factor = { instant: 0, fast: 0.5, normal: 1.0 }
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| base_ms[kind] | int | 0 – 1000 | data file: `fade` 250, `run_start` 600, `intro_slide` 300, `draft_reveal` 360 (3 × 120 stagger), `fly_to_strip` 400, `toast_in_out` 200 | Per-transition base |
| anim_speed | enum | `instant \| fast \| normal` | Meta setting (default `normal`) | Player preference (ui-code rule 4: respects motion preference) |

**Output Range:** 0 – 600 ms per transition at defaults; any input during a transition skips it
to its end state (U4). **Example:** bundle reveal at `fast` = 180 ms, cards appearing 60 ms
apart.

### F3. Toast visibility

The `t_toast` formula is defined as:

```
t_toast = clamp(toast_base_ms + chars × toast_per_char_ms, toast_min_ms, toast_max_ms)
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| chars | int | 1 – 200 | calculated | Length of the resolved toast text |
| toast_base_ms, toast_per_char_ms | int | 3000–6000, 20–50 | data file (5000, 30) | Reading-time model (base = the accessibility floor, so every toast is "5 s plus reading time") |
| toast_min_ms, toast_max_ms | int | 5000–6000, 6000–10000 | data file (5000, 8000) | Bounds — the 5000 ms floor is an accessibility requirement (accessibility-requirements "Reading time", WCAG 2.2.1), never lowered; the cap keeps a queue of 8 under 66 s |
| toast_gap_ms | int | 100 – 500 | data file (150) | Pause between queued toasts |

The timer counts only while the toast is neither hovered nor focused (U5 pause rule); exactly
one toast is visible at a time (registry formula `toast_visible_ms`: `clamp(5000 + 30·chars,
5000, 8000)`, revised 2026-11-03 from `clamp(2000 + 30·chars, 2000, 6000)` — the registry row
and its `output_range` are updated by the registry owner, not here).

**Output Range:** 5000 – 8000 ms. **Example:** "New hero unlocked: Lady Tallow" (32 chars) →
5960 ms; a 40-row save-failed detail is capped at 8000 ms and the detail lives in the log and
the menu status line. The "Copied" flash after Copy seed is not a toast (1500 ms, non-informational).

### F4. Layout at 1280x720 — option slots and the progress strip

The `slot_x` and `strip` formulas are defined as:

```
slot_x(i, n, w, gap) = (1280 − (n × w + (n − 1) × gap)) / 2 + i × (w + gap)      i ∈ 0..n−1
strip_w(F)   = F × node_d + (F − 1) × seg_len
strip_x0(F)  = (1280 − strip_w(F)) / 2
node_cx(f)   = strip_x0 + node_d / 2 + (f − 1) × (node_d + seg_len)              f ∈ 1..F
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| n, w, gap | int | 3; 150 / 340; 48 / 40 | data file | Treasure draft: 3 card frames 150x210 (art bible §4), gap 48. Bundle draft: 3 panels 340 wide, gap 40 |
| F | int | 3 – 12 | registry `floors_per_run` (8; MVP 4) | Nodes in the strip |
| node_d, seg_len | int | 24; 40 | data file | Node diameter and connector length; strip row is 48 px tall at y 0–48 under the title row |
| content_top | int | 96 | constant (title 48 + strip 48) | First y available to a screen's content |

**Output Range:** treasure slots at x = 367, 565, 763 (y = 240, leaving 96–240 for header and
240–450 for cards, 450–720 for hint and Pick); bundle panels at x = 90, 470, 850 (each panel:
theme label 32 px, three compact card rows 300x64 with 8 px gaps, Pick row), hover preview
225x315 anchored to the panel's outer edge. Strip: **F = 8** → `strip_w = 472`, `x0 = 404`,
node centres at 416, 480, …, 864; **F = 4** → `strip_w = 216`, `x0 = 532`, centres 544, 608,
672, 736. Treasure icons occupy x 40–200 left of the strip, deck size x 1080–1240 right of it;
the strip never exceeds 640 px (F ≤ 10 at these constants; F > 10 shrinks `seg_len` to fit).
**Example:** floor 4 of 8 with two treasures: nodes 1–3 filled with boss initials, node 4
ringed in band-2 rust, nodes 5–8 hollow in their band colours (ochre is never shown past
floor 3), two gem marks under nodes 1 and 3, two treasure icons at left, "24 cards" at right.

## Edge Cases

`systems-designer` not consulted — Lean mode (no Agent tool).

**Saves and resume**
- **If Continue is pressed and the save is corrupt or on another data version** (run-structure
  R8 `E_SCHEMA`/`E_CORRUPT`/`E_DATA_VERSION`): the resume prompt is replaced by a reason dialog
  ("This run cannot be resumed: <reason>") with one button, **New Run**, which opens hero select;
  the Continue card disappears from the menu; no loss is recorded (Meta contract). Never a blank
  screen, never a crash.
- **If the saved run uses a hero that is now locked**: Continue works unchanged (run-structure
  R8.4); the summary later shows the hero normally; hero select would show it locked.
- **If the window is closed during a draft**: nothing to do — the S2/S3 save already holds the
  phase; on next launch the menu shows Continue and resume re-offers the same three options
  (R5.2 contract). The UI never writes a save of its own.
- **If a toast (`save_failed`) arrives while a confirm dialog is open**: it queues; dialogs are
  modal, toasts are not (U5).

**Picks and input**
- **If Pick is double-clicked, or `Enter` is pressed twice**: the first press sets `committed`;
  the second is dropped. Exactly one `draft_pick` is sent (test AC-9 pins it).
- **If a pick arrives during a transition** (`transitioning == true`): dropped with
  `ui_intent_rejected{transitioning}`; the option stays focused so the next press lands.
- **If `1`/`2`/`3` is pressed on a screen with fewer than three focusable options** (locked
  heroes excluded, or a short roster): the key is ignored; focus does not wrap to a hidden slot.
- **If a treasure or bundle id in `option_ids` does not resolve** in Card Database: the option
  renders as an error frame ("missing: <id>") and is not pickable; a `ui_data_missing` warning
  toast is raised. Card Database validation should make this unreachable; the UI still does not
  crash.
- **If the player presses `Esc` on a draft**: the pause overlay opens; the draft is not
  abandoned by `Esc` alone — abandon needs the confirm.

**Toasts and unlocks**
- **If an unlock toast is raised during a transition or a match**: queued until the shell is
  idle (U5); after a victory it therefore shows over the summary, which is where the player
  expects it.
- **If an unlock toast is still showing when the player restarts** (summary → New Run → `run_start`
  → `boss_intro` is < 5 s, cross-review S-05): the toast is not cut short — it persists on the
  toast layer across every transition until its `t_toast` elapses or it is dismissed (U5); the ack
  was already sent on show, so nothing is re-queued. A warning toast in the same position may be
  dropped; its content is in the log and the menu status line.
- **If the player hovers or focuses a toast**: its timer pauses; moving away resumes it; a click
  or `Enter` dismisses it (U5).
- **If more than `toast_queue_max` toasts are pending**: warnings drop oldest-first; unlock
  toasts are never dropped (they are also listed on the summary and in the run log, so a
  dropped toast would still not lose information).

**Summaries and run log**
- **If the run log has been pruned** (Meta's `run_log_cap`, 200) **when a victory summary
  opens**: the summary is built from the in-memory `RunRecord` handed with `run_ended`, never by
  re-reading the archive, so it is unaffected; the run may simply not appear in the log later.
- **If `damage_by_card` is empty** (turn-1 concede): the table shows "no damage dealt"
  (run-structure Edge Cases), not an empty grid.
- **If a run record in the log references an id that no longer exists** (data changed between
  versions): the row shows the raw id in `text_muted` with a "(removed)" suffix; the detail
  view still opens.
- **If there are zero archived runs**: the Run Log shows one line ("No runs yet — your first
  descent is a click away") with New Run focused.

**Seeds and hero select**
- **If the seed field contains characters that are not hex or decimal**: accepted — RNG & Event
  Log F1 hashes any string; the echo shows the resulting 16-hex form so the player can see it is
  not the digits they typed. No validation error exists because no input is invalid.
- **If the seed field holds only whitespace**: trimmed to empty → random seed, echo shows
  "Random".
- **If no locked hero exists in data** (MVP): the locked section is absent; no "coming soon"
  placeholder. **If a locked hero exists but `unlock_progress` has no definition for its key**
  (orphaned or missing `unlock` object): the panel shows the lock without a hint line.
- **If the profile is fresh** (every `stats_for_hero(h).last_played_at` is null): War is
  pre-selected; otherwise the hero with the greatest `last_played_at` (U7).
- **If the profile is `ReadOnly`** (Meta M5.2 / M6): the banner is shown on every base screen
  outside `match`; New Run and Continue still work (the run plays, it is not saved — Meta); the
  Continue card reflects the on-disk `active_run`, which this session cannot update.

**Short, skipped and skippable drafts**
- **If `draft_offered` carries `short` or `reoffer`** (reward-draft D8): `len(option_ids)` is 1
  or 2; the missing slots are drawn as dimmed placeholders with the reason; `1`/`2`/`3` keys past
  the last real option are ignored; F4 slot positions are unchanged (empty slots keep their
  place) so the screen does not reflow.
- **If an offer is empty** (`option_ids == []`): the shell never sees a draft screen — the run
  skips the step and the next event (`draft_offered{bundle}` or `run_floor_entered`) decides;
  from `draft_treasure` a skipped bundle step therefore lands directly on `boss_intro` (S15 path
  without `deck_grew`).
- **If `allow_skip` is true**: "Take nothing" is a fourth focusable control (`Tab`, never a number
  key) and sends `skip_pick`; the deck count does not change and no fly-to-strip plays.

**Text and layout**
- **If a card's rules text exceeds 4 lines at 12 px** (art bible §4): the compact row ellipsises
  the last line and the hover/focus preview shows the full text at 1.5x; the preview itself
  scrolls past 8 lines. Nothing is ever clipped without a way to read it (art bible §7: hover
  duplicates, never replaces).
- **If a boss passive text or intro line overflows its box**: auto-wrap and grow the box down to
  a maximum, then scroll; the Fight button is anchored to the screen bottom, never pushed off.
- **If `floors_per_run > 10`**: `seg_len` shrinks so `strip_w ≤ 640` (F4); below 16 px the boss
  initials are dropped from cleared nodes.

**Accessibility**
- **If a screen has a pick action, it is keyboard-reachable**: `1`/`2`/`3` + `Enter` on all
  three-option screens **and** `Tab` / `Shift+Tab` + `Enter` everywhere (the number keys are a
  shortcut, never the only path — U3); the focused control always shows the 2 px
  `state_actionable` focus ring. A screenshot fixture with keyboard-only navigation proves it
  (AC-19).
- **If `text_scale` is 1.25 or 1.5**: every Run UI text scales (titles, buttons, hints, strip
  labels, toasts, settings rows, summary tables); the 150x210 card thumbnail does not — its
  reading path is the 1.5x preview plus the reading panel (interaction-patterns Card Inspect);
  the bundle panel's compact rows wrap or scroll (Scroll Container) rather than clip (AC-31).
- **If `anim_speed = instant`**: every transition is 0 ms and every `committed` state resolves
  on the next event; the input lock still exists (it is state-based, not time-based), so
  double-picks remain impossible.

## Dependencies

Hard = the shell cannot show its screens without it; soft = a stub suffices. Bidirectional check
against `design/gdd/systems-index.md`: the index lists Run UI as depending on Run Structure,
Reward Draft, Meta Progression, Card Database, RNG & Event Log and Match UI — all below. Run
Structure (its Dependencies and Interactions) already names Run UI as a dependent — consistent.
Card Database (UI Requirements: data-error screen, draft picker, boss intro, hero select) and
Heroes (UI Requirements, Cross-References) name Run UI surfaces — consistent. Reward Draft
(Interactions, Dependencies, UI Requirements), Meta Progression (Interactions, Dependencies, UI
Requirements) and Match UI (Dependencies "Run UI depends on this") each name Run UI back —
consistent as of 2026-11-03. Heroes, Boss AI, Treasures and Content were added to the index row
on 2026-11-03 (cross-review V-42) — consistent.

| System | Direction | Hard/Soft | Nature of dependency / interface |
|---|---|---|---|
| Run Structure | This depends on Run Structure | Hard | The seven commands (incl. `suspend`, T21 — cross-review C-12) and the run-scope events (Interactions). Run UI mirrors its phase machine (States and Transitions) and renders its read model; it never saves, never computes a seed, never decides a phase. |
| Reward Draft | This depends on Reward Draft | Hard (for drafts) | `draft_offered` with 1–3 id-sorted `option_ids` and `flags`; `pick(index)` maps to `draft_pick(kind, id)`, `skip_pick` to `draft_pick(kind, null)` under `allow_skip`. **Confirmed** (U8); the synergy numbers come from its `Offer` read model and are soft (hint hidden if absent). |
| Meta Progression | This depends on Meta Progression | Soft for MVP (in-memory stub: no Continue, all heroes unlocked, no log, session-local settings — answers match-ui.md's open question for MVP), Hard from Vertical Slice | Load status and ReadOnly banner, Continue presence, unlock state and progress, hero stats, run log pages, pending notifications + ack, settings get/set (the DD-X07 record: Meta owns, Run UI edits, Match UI and Boss AI read — M9 carries `anim_speed`, `reduce_motion`, `text_scale`, `high_contrast_states`, `action_delay_ms` as of cross-review C-01), clear run records, typed-confirm reset. **Confirmed** (Interactions); Meta's UI Requirements name these surfaces as Run UI's. |
| Card Database | This depends on Card Database | Hard | All definitions displayed; the `Failed` report for the data-error screen; `text.en` / key fallback rule. |
| RNG & Event Log | This depends on RNG & Event Log | Hard | Event envelope the controller renders from; `run_seed_hex` display form; F1 for the seed echo. |
| Match UI | Mutual (sibling) | Hard | Scene handoff at `begin_match`; control returns on `match_view_finished(result)` (click or 4 s auto) with `match_ended` already processed by Run Structure. **Confirmed in match-ui.md** (Core Rules "Match end", Dependencies). Shared: the pause-menu settings panel and the art-bible theme resource; settings values are not shared between the two — both read Meta's record (DD-X07). |
| Heroes | This depends on Heroes (data) | Hard | Hero select content: identity line, power text, starter deck preview, colours, Locked/Available. |
| Boss AI | Boss AI consumes a setting this GDD edits | Soft | `telegraph_mode` is Meta's setting (DD-X07); Run UI shows the control; Boss AI reads it and derives `effective_mode = min(boss.intent_mode, telegraph_mode)` (DD-X03, boss-ai C8.4). No direct call either way. |
| Treasures | This depends on Treasures (data) | Soft | Treasure name/rarity/text for the draft and summary come through Card Database `TreasureDef`; no direct call. |
| Content | Content depends on this | Soft | Bundle theme labels and boss intro lines must fit the boxes in F4 (≤ 24 chars label, ≤ 2 lines intro at 16 px) — a content authoring constraint this GDD imposes. |

## Tuning Knobs

All in `assets/data/run_ui.json` unless noted; `systems-designer` not consulted — Lean mode.
Interacting knobs: `restart_budget_ms` is a *constraint* on the sum of `transition_ms.fade`,
`run_start_ms` and the measured steps (F1) — raising the transitions eats the budget's headroom;
`anim_speed` scales all of them at once.

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `restart_budget_ms` | 5000 | 3000 – 5000 | Looser AC-1; above 5000 breaks the concept's promise | Tighter; below 3000 forces `run_start_ms` toward 0 |
| `transition_ms.fade` | 250 | 0 – 400 | Softer screen changes; eats restart headroom | Snappier; 0 = hard cut |
| `run_start_ms` | 600 | 0 – 1000 | Longer seed card (more "ceremony"); above 1000 restarts feel slow | Shorter; 0 skips the seed card (seed still on the intro and summary) |
| `transition_ms.intro_slide` / `draft_reveal` / `fly_to_strip` / `toast_in_out` | 300 / 360 / 400 / 200 | 0 – 600 each | More weight per event; the draft reveal above 500 reads as a stall | Instant state changes (art bible §7 v1 default is close to this) |
| `anim_speed` (player setting, Meta M9 / DD-X07) | `normal` | `instant \| fast \| normal` | — | `instant` zeroes every duration; accessibility requirement, never removed |
| `reduce_motion` (player setting, Meta M9 / DD-X07) | false | bool | Slides (fly-to-strip, draft-reveal stagger, toast slide) become fades at half duration; no lift bounce; independent of `anim_speed` (accessibility-requirements Motion) | — |
| `text_scale` (player setting, Meta M9 / DD-X07) | 1.0 | {1.0, 1.25, 1.5} — **three discrete steps** (100 / 125 / 150 %), each a fixture-tested layout; never a continuous slider (accessibility-requirements Visual) | Larger UI text (ui-code rule 7); at 1.25+ the bundle panel's compact rows wrap or scroll and the Card Inspect preview gains the reading panel; 1.5 is the committed maximum (WCAG 1.4.4's 200 % is a Known Intentional Limitation) | 1.0 = the art bible §4 typography table as printed; never below the 12 px minimum |
| `high_contrast_states` (player setting, Meta M9 / DD-X07) | false | bool | Swaps the state set to the art bible §4 colourblind alternates (danger orange, buff blue) — a theme change | — |
| `gamma` (player setting, Meta M9 / DD-X10) | 1.0 | 0.8 – 1.4 (slider, step 0.05) | Brighter scene via `CanvasModulate` on every Run UI screen (Match UI applies the same value to the match scene); above 1.4 `bg_edge` stops reading as near-black and the torch-pool contrast of art bible §2 collapses | Darker; below 0.8 `text_muted` on `table_dark` drops under AA — tokens themselves are never changed |
| `toast_base_ms` / `toast_per_char_ms` / `toast_min_ms` / `toast_max_ms` / `toast_gap_ms` | 5000 / 30 / 5000 / 8000 / 150 | F3 ranges (`toast_min_ms` never below 5000 — accessibility floor) | Longer-lived toasts; an 8 s cap keeps a queue of 8 under 66 s | Toasts vanish before they are read; below 5000 fails accessibility-requirements "Reading time" |
| `toast_queue_max` | 8 | 4 – 16 | More warnings retained | Warnings dropped sooner; unlocks never dropped |
| `summary_top_cards` | 10 | 5 – 36 | Longer damage table | Terser — owned by Run Structure (`run_structure.json`), pointed to, not duplicated |
| `allow_custom_seed` | true | bool | Seed field shown — owned by Run Structure | Field hidden; seeds still shown on summaries |
| `node_d` / `seg_len` / `strip_max_w` | 24 / 40 / 640 | 16–32 / 16–48 / 480–800 | Wider strip; above 640 it collides with the treasure icons and deck count at F = 8 | Denser strip; below 16 px initials are dropped |
| `option_gap.treasure` / `option_gap.bundle` | 48 / 40 | 24 – 64 | More separation; above 64 the bundle panels (340) no longer fit three across | Crowding; hover previews overlap neighbours |
| `preselect_hero` | `last_played` | `last_played \| war \| none` | — | `none` forces a click on every restart via hero select (path B only; path A unaffected) |
| `default_focus.summary` | `new_run_same_hero` | `new_run_same_hero \| hero_select \| none` | — | `none` adds one Tab to every restart |
| Screen palette per state | art bible §2/§4 tokens | theme resource | — | — (owned by the art bible; the high-contrast toggle swaps the state set) |

## Visual/Audio Requirements

Required for `UI`. `art-director` not consulted — Lean mode (no Agent tool); every value is
taken from the approved art bible (§2 mood per state, §4 tokens). Placeholder art in v1: flat
fills, default font, letter glyphs. SFX list is the concept's "minimal" set; one ambient track.

| Event / state | Visual feedback | Audio feedback | Priority |
|---|---|---|---|
| Main menu, hero select | `bg_edge` room, one warm `table_lit` pool behind the hero panels; panels in hero primary with `text_light`; locked = neutral grey `#6F655A` + lock glyph | Ambient loop (low); hover tick; hero-specific select sting (heroes.md) | Must |
| Run start | Hero-colour panel, seed in `text_muted`, fade per F2 | Short "descent" whoosh | Should |
| Boss intro | Band-colour portrait rectangle (ochre / rust / slate-violet), passive text in `text_light` at 16 px on `table_dark` — the brightest text block; band pips; Fight lit with `state_actionable` outline | Boss intro sting, 3 band variants (run-structure Visual/Audio) | Must |
| Treasure / bundle draft | Table cleared: only the three offers on `table_lit`; `parchment` frames; the focused option carries the 2 px `state_actionable` focus ring (3 px offset, U3), a hovered option lifts 8 px without the ring, an option both hovered and focused shows both; Pick lit only when an option is focused | Draft reveal (3 soft card slaps staggered per F2); pick confirm | Must |
| Fly-to-strip | Picked cards/treasure shrink along a straight path to the strip; deck count ticks up ("24 → 27 cards") in `text_light` — no state colour, because art bible §4 rule (c) makes a state colour a readout of a current state, not an animation | Deck thump | Should |
| Progress strip | Cleared nodes filled `text_light`, current ringed in band colour, upcoming hollow in band colour; gem marks for treasure floors | None | Must |
| Victory summary | Full `table_lit` warmth; hero portrait saturates to its primary (the one allowed saturation, art bible §4 rule b) | Victory stinger | Must |
| Defeat summary | Torch out: `bg_edge` everywhere; summary and killing boss lit in `text_light`; no red wash, no shake | Defeat stinger, short (Pillar 3) | Must |
| Unlock toast | `table_dark` banner, `text_light` body and name; the hero/treasure identification colour appears as a small swatch beside the name, never as text colour (art bible §4: light text on dark, no third text colour) | Unlock chime | Should |
| Warning toast | Same banner, `text_muted` body, no colour | None | Low |
| Confirm dialog | `table_dark` panel on dimmed base; Cancel focused | None | Must |
| Data error | `bg_edge`, report rows in `text_light` / `text_muted`, codes in `state_danger` on `ink` pills | None | Must |

Every sound above is raised as an audio event (`ui_hover`, `ui_select`, `ui_draft_reveal`,
`ui_pick`, `ui_unlock`, `run_start`, `boss_intro_<band>`, `run_victory`, `run_defeat`) through
the audio event bus, never played from a screen script (ui-code rule 5); the bus is shared with
Match UI and owned by the audio ADR.

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run
`/asset-spec system:run-ui` to produce per-asset visual descriptions, dimensions, and generation
prompts from this section.

## Game Feel

Required for `UI`. Run UI has no hitboxes or weight; its feel is **pace** — how quickly the
dungeon answers a click and how little stands between a death and the next floor.

**Feel reference.** Slay the Spire's map-to-fight cadence and death screen (one click, no
ceremony) and speedrun reset reflex; the bundle reveal borrows Hearthstone Dungeon Run's
three-card flourish but at half its length. Anti-reference: Hearthstone's unskippable reward
chests and any menu that fades through black between every screen.

**Input responsiveness.**

| Action | Max input-to-response (ms) | Frames at 60 fps | Notes |
|---|---|---|---|
| Any button press → visible press state | 33 | 2 | Focus outline / press before the command is even sent |
| Pick → option locks, others dim | 50 | 3 | `committed` is visual immediately |
| Fight → Match UI first frame | 500 | 30 | Includes scene swap; Match UI owns the mulligan |
| New Run (same hero) → boss intro visible | 1350 (F1 path A) | — | 5000 hard budget |
| Hover/focus → card preview visible | 100 | 6 | No delay timer; preview appears at once |

**Animation feel targets.** Transitions are fades and slides with no startup frames (they begin
on the input frame) and are skippable: fade 250 ms, intro slide 300 ms, draft reveal 3 × 120 ms
stagger, fly-to-strip 400 ms, toast 200 ms in/out (F2). Nothing bounces; easing is ease-out
only (art bible §7: instant state changes are the v1 default and these are the only motions).

**Impact moments.** Exactly two: the draft reveal (three soft slaps, 360 ms, configurable) and
the victory portrait saturation (one 400 ms colour ramp). The defeat screen has deliberately
none — no shake, no slow-motion, no red (art bible §2). No hit-stop, no camera, no rumble.

**Weight and responsiveness profile.** Light and immediate; the player is in full control at
every moment (any input skips any motion); snap is binary — a screen is either here or the next
one is; acceleration is arcade (instant start, short ease-out). Failure texture: the UI never
rejects an input loudly — a locked hero shows why, a double-click is silently one click, an
unavailable button is dim with its reason; the only "error" surface is the data-error screen,
and that is factual.

**Feel acceptance criteria.**
- [ ] Playtesters restart after a death without comment; nobody asks "how do I play again?"
- [ ] No tester calls a transition "slow" or asks to skip the summary; nobody notices the
      transitions at `fast`.
- [ ] A keyboard-only tester completes a full run (hero select → drafts → summary) without touching the mouse.
- [ ] Nobody describes the defeat screen as punishing; at least one says it told them why they lost.

## UI Requirements

This system *is* the UI outside the match; the table is the screen inventory (U2) as a
display contract. Per-screen layout, focus graphs and pixel specs come from `/ux-design` into
`design/ux/` — one spec per row below.

| Information | Display Location (`design/ux/…`) | Update Frequency | Condition |
|---|---|---|---|
| New Run / Continue card / Run Log / Settings / Quit; profile stats line; one-time load-status line; ReadOnly banner with Retry | `main-menu.md` (banner is a shared component) | On open; Continue on `load_active_run`; banner on Meta state change | Always; Continue iff an active run is saved; status line iff `load_profile().status ∉ {OK, FRESH}`; banner iff `ReadOnly` |
| Active run found: hero, floor n of F, phase; Continue / Abandon ("counts as a loss") | `main-menu.md` (resume prompt) | Once | Continue pressed |
| Hero roster (name, identity line, set blurb, colour, power, 15-card preview strip, stats line "NW · NL · best FN"); locked silhouettes with unlock hint and progress; seed field with hex echo; Start / Back | `hero-select.md` | On open; on selection; on seed edit | `hero_select`; locked rows only when locked `HeroDef`s exist |
| Seed hex on a hero-colour panel | `run-start.md` (may fold into `boss-intro.md`) | Once per run | `run_started` |
| Floor n of F, band pips, boss portrait placeholder, name, intro line, passive text, boss health, hero power text, deck size; Fight | `boss-intro.md` | `run_floor_entered` | `pre_match` |
| Progress strip: F nodes (cleared / current / upcoming by band), gem marks, treasure icons, deck size | `progress-strip.md` (shared component) | `deck_grew`, `treasure_granted`, `run_floor_entered` | Any run screen except match |
| Treasure draft: step indicator, 1–3 frames with rarity and text (placeholders for `short`), "fits your plan" hint, deck drawer, Pick (+ "Take nothing" under `allow_skip`); `1`/`2`/`3` + Enter | `draft-picker.md` (treasure variant — the name Reward Draft's and Run Structure's UX flags use) | `draft_offered{treasure}` | `post_match_reward/treasure` |
| Bundle draft: step indicator, 1–3 panels × (theme label + pitch + 3 compact card rows), hover/focus 1.5x preview, "N cards share *theme*" + "Deck 21 → 24" hints, deck drawer, Pick (+ "Take nothing") | `draft-picker.md` (bundle variant) | `draft_offered{bundle}` | `post_match_reward/bundle` |
| Summary: outcome headline, hero, floors cleared, compact per-floor strip (8 cells; `attempt > 1` and the killing boss marked — U9), killing boss and reason, seed + Copy, top-N damage, drafted cards, treasures, new unlocks, duration/turns; New Run (same hero) / Hero Select / Main Menu; abandoned = one line + New Run · Main Menu | `run-summary.md` (victory + defeat + abandoned variants) | `run_ended` | Terminal phases |
| Archived runs list (date, hero, result, floors n of F, seed, "custom seed" tag, `attempt > 1` marker), per-hero stats and bests header, hero filter, paging, Open; read-only summary | `run-log.md` | On open; on filter; on page | Menu |
| Volumes, fullscreen, action delay, animation speed (3 labels), reduce motion, text scale (100 / 125 / 150 %), boss telegraph mode, high-contrast state colours, gamma slider 0.8–1.4 (DD-X10), keep run records + Clear run records (confirm), Reset profile (typed confirm) — the DD-X07 record | `settings.md` | On change (live; Meta debounces the write) | Menu or pause |
| Pause: Resume / Settings / Abandon run (confirm) / Quit to menu | `pause.md` | On open | Any run screen except match |
| Toast: unlock (name + condition subtitle, acked to Meta when shown) or warning text, queued | `toast.md` (shared component) | Per queue drain | Shell idle (U5) |
| Data error: validation report rows, Copy report, Quit | `data-error.md` | Once at boot | Card Database `Failed` |

📌 **UX Flag — Run UI**: This system has UI requirements. In Phase 4 (Pre-Production), run
`/ux-design` for each screen above **before** writing epics; `progress-strip` and `toast` are
shared components and belong in `design/ux/interaction-patterns.md` or their own specs. Stories
that reference UI should cite `design/ux/[screen].md`, not this GDD directly. Note this in the
systems index for this system if you update it.

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|---|---|---|---|
| Seven commands (incl. `suspend`); phases `hero_select`…`abandoned`; T1–T21; `E_HERO_LOCKED`, `E_DRAFT_*`, `E_BAD_PHASE` | `design/gdd/run-structure.md` | Core Rules R2–R6, R8 (R8.7), States and Transitions (T21) | State trigger |
| `RunRecord` fields for summaries (`result`, `totals`, `match_summaries`, `drafts`, `run_seed_hex`); `summary_top_cards` | `design/gdd/run-structure.md` | R1, R10, Tuning Knobs | Data dependency |
| Treasure before bundle; resume re-offers the same options; `allow_custom_seed` | `design/gdd/run-structure.md` | R5.2, R8.2, R9 | Rule dependency |
| Restart under 5 s | `design/gdd/run-structure.md` | Game Feel, AC-29 | Rule dependency (this GDD owns the budget breakdown, F1) |
| Upcoming floors show band only, never boss identity; Continue card contents; pause menu split | `design/gdd/run-structure.md` | UI Requirements | Rule dependency |
| `floors_per_run` (8 / MVP 4), `floor_band`, `boss_sequence` | `design/gdd/run-structure.md` | Registry constants/formulas | Data dependency |
| Seed parsing of any input; 16-hex display form | `design/gdd/rng-event-log.md` | F1 | Rule dependency |
| Event envelope `{seq, turn, type, payload, cause_seq}`; render-from-events | `design/gdd/rng-event-log.md` | Core Rules D, rule 11; DD-T04 | Rule dependency |
| `HeroDef`, `BossDef` (`intro_text`, `passive`), `TreasureDef`, `BundleDef`, `CardDef`; `Failed` report; `text.en` fallback | `design/gdd/card-database.md` | CR-3, States, UI Requirements | Data dependency |
| Identity lines, colours, power text, Locked/Available, win counts on hero select; `E_HERO_LOCKED`; no forced hero (DD-X02) | `design/gdd/heroes.md` | H-2, H-7, States, UI Requirements | Data dependency |
| `draft_offered{floor, kind, option_ids[], flags[]}`; 1–3 offers; `short` / `reoffer` placeholders; empty offer skipped by the run; `allow_skip`; `Offer` synergy numbers; `E_UNKNOWN_ID` | `design/gdd/reward-draft.md` | D1, D8, D9, D11, States `Short`/`Empty`, UI Requirements | Ownership handoff (**confirmed**) |
| `load_profile` statuses, `load_active_run`, `is_hero_unlocked`, `unlock_progress`, `stats_for_hero`, `run_log(offset, limit)`, `pending_notifications` / `ack_notification`, `unlock_granted` payload, `get_settings` / `set_setting`, `reset_profile(confirm_token)`, M9 settings keys (the DD-X07 record), `run_log_cap`, ReadOnly banner | `design/gdd/meta-progression.md` | M1.1, M1.3, M3.6, M5, M6, M7.1, M8, M9, States, UI Requirements | Ownership handoff (**confirmed**; M9 carries all DD-X07 keys — cross-review C-01) |
| Scene handoff; `match_view_finished(result)` after the end banner (click or `MATCH_END_AUTO_S`); shared pause settings panel | `design/gdd/match-ui.md` | Core Rules "Match end", States `Ended`, Dependencies, Tuning Knobs `MATCH_END_AUTO_S` | Ownership handoff (**confirmed**) |
| `telegraph_mode` setting consumed as `effective_mode = min(intent_mode, telegraph_mode)` (DD-X03) | `design/gdd/boss-ai.md` | C8.4, Tuning Knobs (`telegraph_mode`) | Data dependency (Boss AI consumes; Meta owns the value) |
| Toast floor 5 s / cap 8 s, hover/focus pause, one visible at a time; focus ring 2 px `state_actionable` offset 3 px; `text_scale` three steps; Pick One of N `1/2/3` + Tab | `design/accessibility-requirements.md`, `design/ux/interaction-patterns.md` | "Reading time", Visual `text_scale`; Toast / Notification, Focus Management, Pick One of N | Rule dependency (applied 2026-11-03) |
| Mood per state; tokens; card slot layout 150x210 / 225x315; portrait 120x160; typography; high-contrast swap | `design/art/art-bible.md` | §2, §4, §5, §7 | Data dependency |
| Screenshot procedure, launch-argument reachability | `.claude/docs/run-and-observe.md` | Godot row; "Reaching the state" | Rule dependency |

## Acceptance Criteria

`qa-lead` not consulted — Lean mode (no Agent tool). AC-1–8 are observable states for
screenshots (fixture named; `production/qa/evidence/` per run-and-observe); AC-9–22 are logic
criteria for the shell state machine (unit tests with a stubbed `RunController`); AC-23–26
cover formulas and performance; AC-27–32 were added by the design and cross reviews.

**Observable (screenshot per fixture)**
- [ ] **AC-1** GIVEN fixture `fresh_profile`, WHEN launched with `--run-ui-screen=main_menu`, THEN New Run, Run Log, Settings, Quit are visible, **no Continue**, and the stats line reads 0 runs.
- [ ] **AC-2** GIVEN `fresh_profile` and `--run-ui-screen=hero_select`, WHEN rendered, THEN exactly the heroes present in data appear, War is pre-selected with its power text and 15-card preview, no locked row exists, and the seed field shows "Random".
- [ ] **AC-3** GIVEN fixture `locked_heroes`, WHEN hero select renders, THEN Fortune, Order and Shadow appear as grey silhouettes with a lock glyph and an unlock hint with progress, and Start is disabled while one of them is focused.
- [ ] **AC-4** GIVEN fixture `mid_run_floor4` and `--run-ui-screen=boss_intro`, WHEN rendered, THEN "Floor 4 of 8", two band pips in rust, the passive text, the hero power text and "24 cards" are visible, the strip shows nodes 1–3 filled with initials, node 4 ringed, 5–8 hollow with no initials, two treasure icons and two gem marks, and Fight is focused.
- [ ] **AC-5** GIVEN `draft_treasure_sample` / `draft_bundle_sample`, WHEN rendered, THEN three options sit at the F4 slot positions (±2 px), rarity/theme labels are legible at 1280x720, no card text is clipped without a preview, and Pick is dim until an option is focused.
- [ ] **AC-6** GIVEN fixture `victory_sample`, WHEN `summary_victory` renders, THEN the hero panel is in its full primary colour, "8 of 8", the 16-hex seed with Copy, a 10-row damage table, drafted cards marked, treasures, one "New hero unlocked" line, and **New Run (same hero)** carries the 2 px `state_actionable` focus ring at a 3 px offset.
- [ ] **AC-7** GIVEN fixture `defeat_sample`, WHEN `summary_defeat` renders, THEN the background is `bg_edge`, the headline names floor 5 and the boss, floor 3 shows "attempt 2", no `state_danger` fill larger than a stamp exists on screen, and New Run (same hero) is focused.
- [ ] **AC-8** GIVEN fixture `data_error_sample`, WHEN launched, THEN 12 report rows are listed with file, id, code and message, Copy report and Quit are the only controls, and no other screen is reachable by any key.

**Shell state machine (logic)**
- [ ] **AC-9** GIVEN `draft_bundle` with an option focused, WHEN `pick(1)` is sent twice within 100 ms, THEN exactly one `draft_pick(bundle, option_ids[1])` reaches the controller and the second intent logs `ui_intent_rejected`.
- [ ] **AC-10** GIVEN `transitioning == true`, WHEN any intent other than `skip` arrives, THEN it is dropped, no command is issued, and `skip` ends the transition immediately.
- [ ] **AC-11** GIVEN every ShellState, WHEN each intent in U2 is sent, THEN only the rows in S1–S23 produce a command; every other (state, intent) pair is rejected with `bad_state` and changes nothing.
- [ ] **AC-12** GIVEN a `main_menu` with an active run saved, WHEN `continue` is accepted and `resume()` returns `OK` with `status = post_match_reward/treasure`, THEN the shell enters `draft_treasure` with the three re-offered ids, no `hero_select` or `run_start` in between.
- [ ] **AC-13** GIVEN `resume()` returns `E_CORRUPT`, WHEN Continue was pressed, THEN a reason dialog with a single New Run button appears, the Continue card is gone on return to the menu, and no `abandon()` command was sent by the UI.
- [ ] **AC-14** GIVEN `hero_select` with an active run saved, WHEN `start_run` is sent, THEN `confirm` opens first and `new_run` is issued only after `confirm`; `cancel` leaves the run untouched.
- [ ] **AC-15** GIVEN the shell in `match`, WHEN an `unlock_granted` arrives, THEN no toast is shown until the shell reaches a summary, where it shows for `t_toast`, calls `ack_notification(key)` exactly once, and then drains the next; GIVEN the same key also present in `pending_notifications()` at the next boot, THEN no second toast is shown.
- [ ] **AC-16** GIVEN a queue of `toast_queue_max + 2` warnings and 1 unlock, WHEN drained, THEN the two oldest warnings were dropped and the unlock was shown.
- [ ] **AC-17** GIVEN a summary, WHEN `new_run_same_hero` is sent, THEN `new_run(hero_id, "")` is issued with no confirm and the next state is `run_start`.
- [ ] **AC-18** GIVEN `hero_select`, WHEN the seed field holds `"deckdelve"`, THEN the echo shows `48A10CC0B2ED54EC` (RNG & Event Log F1 example) and `start_run` passes the raw string, not the echo.
- [ ] **AC-19** GIVEN any three-option screen, WHEN keys `2` then `Enter` are pressed with no mouse input, THEN option index 1 is picked/selected; GIVEN the same screen, WHEN `Tab` is pressed twice from the no-focus start then `Enter`, THEN option index 1 is picked/selected the same way; GIVEN a full run driven only by keyboard, THEN every screen in U2 is reached and left without a mouse event, and at every focus stop a 2 px `state_actionable` ring offset 3 px is visible in the retained screenshot (also at `anim_speed = instant`).
- [ ] **AC-20** GIVEN `anim_speed = instant`, WHEN any transition runs, THEN its duration is 0 ms, `committed` still blocks a second intent, and the result is identical to `normal`.
- [ ] **AC-21** GIVEN an `option_ids` entry that does not resolve in Card Database, WHEN the draft renders, THEN that slot shows the missing-id frame, is not pickable, and the other two are.
- [ ] **AC-22** GIVEN every user-visible string in `src/ui/run/**`, WHEN scanned, THEN each is a `tr()` key or data `text` — zero literal English strings (CI grep).

**Formulas and performance**
- [ ] **AC-23** GIVEN defaults, WHEN defeat → New Run (same hero) is timed from the Enter key to the boss intro's first rendered frame, THEN it is ≤ 1350 ms + 15 % and never above `restart_budget_ms`; path B via hero select with a 1500 ms scripted pause is ≤ 5000 ms (F1).
- [ ] **AC-24** GIVEN F = 8 and F = 4, WHEN the strip lays out, THEN node centres are at 416 + 64·(f−1) and 544 + 64·(f−1) respectively (F4), and the strip width never exceeds 640 for F ≤ 12.
- [ ] **AC-25** GIVEN toast texts of 10 and 200 chars, WHEN `t_toast` is computed, THEN the results are 5300 ms and 8000 ms (F3 bounds); GIVEN `toast_min_ms` read from `run_ui.json`, THEN it is ≥ 5000 (accessibility-requirements test plan "Reading time"); GIVEN a showing toast, WHEN it is hovered for 2 s, THEN it disappears 2 s later than its unhovered twin.
- [ ] **AC-26** Performance: every base screen builds and renders its first frame within 100 ms on the reference machine (the target hardware named in `.claude/docs/technical-preferences.md` Platform Notes — the same machine the card-database and meta-progression ACs measure on; until a target is set there, the evidence note in `production/qa/evidence/` records the machine the measurement was taken on: CPU, GPU, RAM, OS) from its read model; building the victory summary from a 36-card, 8-summary record stays under 50 ms; no screen allocates per frame while idle (profiler: zero allocations over 60 idle frames on `main_menu`).
- [ ] **AC-27** No hardcoded values: every duration, size and count in F1–F4 is read from `assets/data/run_ui.json` or the theme resource; a test changes `node_d` and observes the strip move.
- [ ] **AC-28** GIVEN `draft_offered{kind: treasure, option_ids: [a, b], flags: [short]}`, WHEN `draft_treasure` renders, THEN two frames sit at F4 slots 0 and 1, slot 2 is a dimmed placeholder with the reason text, key `3` does nothing, and `pick(1)` sends `draft_pick(treasure, b)`; GIVEN `pick(2)`, THEN it is rejected `bad_index` and no command is issued.
- [ ] **AC-29** GIVEN the shell in `match` and a buffered `match_faulted` + `run_floor_entered{floor: 4}`, WHEN `match_view_finished` arrives, THEN the shell enters `boss_intro` for floor 4 (S11b) with the strip unchanged, the subtitle "Attempt 2" under the floor line (S-04) and a `run_warning` toast queued; no draft screen is shown.
- [ ] **AC-30** GIVEN `reset_profile_requested`, WHEN the confirm dialog opens, THEN Confirm is disabled until the typed field equals the shown token, and `reset_profile(token)` is called only after Confirm; `Esc` or Cancel calls nothing.
- [ ] **AC-31** (ui-code rule 8) GIVEN the window at 1280x720 and at the largest supported fullscreen resolution (3840x2160, `canvas_items` stretch) and `text_scale = 1.5`, WHEN each base screen in U2 renders from its fixture, THEN no text is clipped, no control is off-screen, and screenshots of both sizes are retained per fixture; GIVEN the settings screen, THEN text scale offers exactly the three segments 100 % / 125 % / 150 % and no intermediate value can be stored.
- [ ] **AC-32** GIVEN `summary_victory` with an unlock toast showing for 1 s, WHEN `new_run_same_hero` is sent, THEN the toast is still visible on `run_start` and on the floor-1 `boss_intro`, disappears when its `t_toast` elapses (not at the transition), and `ack_notification(key)` was called exactly once (S-05); GIVEN `pause` over `boss_intro`, WHEN `go_main_menu` is sent, THEN `suspend()` is issued, no `abandon()` and no `run_ended` occur, and the menu shows Continue for the same floor (C-12).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| `assets/data/run_ui.json` is a new data file not in DD-T01 — add it (same situation as `run_structure.json`). | Owner (orchestrator) | Before `/create-architecture` | **Resolved 2026-11-03** — DD-T01 already lists `run_ui.json` |
| **Meta M9 settings keys**: this GDD (and match-ui.md Dependencies) store `anim_speed`, `text_scale` and `high_contrast_states` through `set_setting`, but meta-progression.md M9 lists neither key nor default. Meta must add them (defaults `normal`, 1.0, false) or Run UI keeps them in a UI-owned `user://ui_settings.json`. | Meta Progression GDD | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-01 / DD-X07**: Meta M9 stores the label set `anim_speed`, plus `reduce_motion`, `text_scale` (1.0 \| 1.25 \| 1.5), `high_contrast_states`, `action_delay_ms`; Run UI edits, Match UI and Boss AI read |
| **Pause → Quit to menu** between matches needs a Run Structure command that drops the in-memory run without ending it (the saved run reappears as Continue). run-structure.md has none: `return_to_menu` is legal only in terminal phases (T17) and `abandon` ends the run. Proposed `suspend()` from `pre_match` / `post_match_reward`: no event, no save, state → Menu. | Run Structure GDD | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-12**: run-structure adopted `suspend` (T21, R8.7); wired as S23 |
| Meta's UI Requirements say unlock toasts are "acked when dismissed or after 4 s"; this GDD owns toast timing (F3, 2–6 s) and acks when shown. Meta should defer to F3. | Meta Progression GDD | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-20**: Meta's UI Requirements defer to F3; F3 is now 5–8 s (accessibility floor), ack on show unchanged |
| "First run forces War" (heroes.md H-2 says Run Structure owns it; run-structure.md does not state it). This GDD pre-selects War on a fresh profile and never disables other available heroes. Confirm pre-select is enough. | Owner / Run Structure GDD | `/consistency-check` | **Resolved 2026-11-03 — DD-X02 (cross-review C-11)**: pre-select, never force; heroes.md and run-structure.md aligned |
| Bundle panels show three **compact card rows** (300x64) plus a 1.5x preview rather than three full 150x210 cards, because 9 full cards do not fit 1280 px at the 12 px text minimum. Confirm with `/ux-design draft-bundle`; alternative is a two-step bundle screen (pick a bundle, then see its cards). | ux-designer | `/ux-design draft-bundle` | Decision taken here: compact rows + preview |
| `draft_offered` payload: does Reward Draft send `theme_labels[]` or does the UI read `BundleDef.name`? Does `TreasureDef.synergy_tags[]` / `CardDef.tags[]` exist for the hint? | Reward Draft + Card Database GDDs | `/design-system reward-draft` | **Resolved 2026-11-03** — payload is `{floor, kind, option_ids[], flags[]}`; label is `BundleDef.theme`; hints come from Reward Draft's `Offer` numbers; `TreasureDef.tags` is Reward Draft's request to Card Database (its open question, not this GDD's) |
| Meta API names used here (`unlock_hint`, `profile_stats`, `list_runs`, `get_run`, `get_setting/set_setting`, `reset_profile`, `last_hero_id`, `unlock_granted`) and the settings key list. | Meta Progression GDD | `/design-system meta-progression` | **Resolved 2026-11-03** — replaced by Meta M1.3's names (Interactions); only the three M9 keys above remain open |
| Match UI handoff: does the match end overlay belong to Match UI (assumed) with a single Continue returning control, or does Run UI draw the overlay over the frozen board? | Match UI GDD | `/design-system match-ui` | **Resolved 2026-11-03** — Match UI owns the banner and emits `match_view_finished(result)` after a click or 4 s (U2 `match`, S11) |
| Hover preview anchoring on the bundle draft: the right panel's "outer edge" (x 1075+225) leaves the viewport and the middle panel's preview overlaps a neighbour either way. Proposed: left panel → preview on its right, right panel → on its left, middle panel → above the row on top of the strip area, all drawn on the overlay layer. | ux-designer | `/ux-design draft-picker` | Open — this GDD specifies behaviour only |
| Pause during a match is Match UI's (Concede); between matches it is Run UI's (Abandon). One pause scene with two modes, or two scenes? | ux-designer / ui-programmer | `/ux-design pause` | Open — this GDD specifies behaviour only |
| Debug fixture loading via `--run-ui-fixture` needs a Meta stub; whether that is a `RunController` injection seam or an autoload flag → ADR. | technical-director | `/create-architecture` | → ADR |
| Gamepad is mapped to the same focus graph (U3); DD-T05 names mouse + keyboard only. Is gamepad a v1 requirement (ui-code rule 3 says yes) or Alpha? | Owner | Pre-production | Open — designed as reachable, not tested in MVP |
| Abandoned-run summary: full summary (as victory/defeat) or the one-line notice specified here? | Owner | `/ux-design run-summary` | Decision taken here: one line + buttons |
