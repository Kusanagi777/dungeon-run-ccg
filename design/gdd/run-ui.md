# Run UI

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Design
> **Author**: Jacob (owner) + `/design-system` (guided, lean, tier standard, docs.density balanced)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 3 (lose fast, learn fast — restart under five seconds, every summary legible); Pillar 4 (readable, deterministic — the seed is on every summary); retention hooks "Curiosity" and "Investment" (locked silhouettes, run log, per-hero wins)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` No Agent tool in this session: `game-designer` / `ux-designer` / `ui-programmer` / `art-director` (Sections C, Visual/Audio), `systems-designer` (D, E), `qa-lead` (H) not consulted — review manually before production.
> **Scope note**: this GDD is the *system-level* contract for every screen outside the match — screen inventory, the screen state machine, intents, timing budgets, layout rules. Per-screen pixel specs come later from `/ux-design` into `design/ux/`; stories cite those specs, not this file.
> **Engine claims**: Godot 4.7.2; `docs/engine-reference/godot/modules/ui.md` read (4.6 dual-focus: keyboard focus is separate from mouse hover — every pick must be reachable by both). Screenshot procedure from `.claude/docs/run-and-observe.md`.

## Summary

[To be designed]

> **Quick reference** — Layer: `Presentation` · Priority: `MVP` · Key deps: `[To be designed]`

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
| `main_menu` | B | Main Menu | New Run · Continue (only when an active run is saved: hero, floor "n of F", phase, last played) · Run Log · Settings · Quit; profile stats line (runs, wins, best floor — Meta contract) | `new_run_requested` → open `hero_select` (T1) · `continue_requested` → open `resume_prompt` · `open_run_log` · `open_settings` · `quit_requested` → save settings, quit |
| `resume_prompt` | O | Resume prompt | "Active run found: <hero>, floor n of F, <phase>" · Continue · Abandon (with "Abandon counts as a loss" line, run-structure R6) | `continue` → `resume()` (T15/T16) · `abandon` → `confirm` then `abandon()` (T13) · `back` |
| `hero_select` | B | Hero Select | Launch heroes as lit panels (name, identity line, colour, hero power name/cost/text, starter-deck preview strip, win count); locked heroes as desaturated silhouettes with lock glyph and unlock hint (Meta contract) — shown **only for `HeroDef`s present in data**; seed field (if `allow_custom_seed`) with normalised hex echo; Start; Back | `select_hero(hero_id)` (local, no command) · `start_run(hero_id, seed_input)` → `new_run(hero_id, seed_input)` (T2; after `confirm` if an active run exists) · `back` (T3) |
| `run_start` | B | Run Start transition | Hero colour panel, "Seed <hex16>" (`text_muted`), `run_start_ms` long, skippable | none (auto-advances on `run_floor_entered`; any input skips the remaining time) |
| `boss_intro` | B | Boss Intro | "Floor n of F", band indicator (1–3 pips in band colour, art bible §2), boss portrait placeholder (120x160 band-colour rectangle, initial), name, intro line, **passive text (brightest element)**, boss health, player's hero power text, deck size; Fight | `begin_match` → `begin_match` (T5) · `open_pause` |
| `match` | B | Match (handoff) | Match UI scene; Run UI is hidden, not freed; the strip is not shown (Match UI owns the HUD) | none; receives `match_ended(MatchResult)` via Match UI's end overlay "Continue" — **contract, to be confirmed in match-ui.md** |
| `draft_treasure` | B | Treasure Draft | Header "Treasure — floor n", 3 treasure frames (spell slot layout, rarity pill, text), hover synergy hint ("in your deck: N cards tagged …"), Pick | `pick(index)` → `draft_pick(treasure, offered_ids[index])` (T11) · `hover(index)` (local) · `open_pause` |
| `draft_bundle` | B | Bundle Draft | Header "Bundle — floor n", 3 bundle panels each with theme label and 3 compact card rows; hover a row → 1.5x card preview (225x315); Pick | `pick(index)` → `draft_pick(bundle, offered_ids[index])` (T12) · `hover(index, card)` · `open_pause` |
| `summary_victory` | B | Victory Summary | Hero (portrait saturates to primary — the one allowed saturation), "Floors cleared F of F", seed hex + Copy, top `summary_top_cards` damage table, drafted cards (acquisition order, drafted marked), treasures, new unlocks (Meta contract), duration/turns; buttons **New Run (same hero)** [focused] · Hero Select · Main Menu | `new_run_same_hero` → `new_run(hero_id, "")` (T18) · `go_hero_select` → `return_to_menu` + T1 · `go_main_menu` → `return_to_menu` (T17) · `copy_seed` (local) |
| `summary_defeat` | B | Defeat Summary | As victory on `bg_edge` (torch out, art bible §2): "Fell on floor n — <boss>", reason (`hero_dead` / `both_dead` "the boss wins ties" / `concede` / `turn_cap`), `attempt > 1` floors marked; same buttons, **New Run (same hero)** focused | as `summary_victory` |
| `summary_abandoned` | B | Abandon notice | One line (player abandon: "Run abandoned — counted as a loss"; system abandon: the reason, not a loss) + New Run · Main Menu | as summaries minus `go_hero_select` |
| `run_log` | B | Run Log | List of archived runs (Meta contract): date, hero, outcome, floor, seed; filter by hero; Open; Back | `filter_hero(hero_id \| null)` · `open_run(run_id)` → `run_detail` · `back` |
| `run_detail` | O | Run summary (archived) | The summary layout in read-only form, from the archived record; Copy seed; Back | `copy_seed` · `back` |
| `settings` | B/O | Settings | Master / music / SFX volume, fullscreen, animation speed (`instant` / `fast` / `normal`), boss telegraph mode (Boss AI knob — passthrough), high-contrast state colours (art bible §4), Reset profile (confirm, typed "RESET" not required — two-step button); Back | `set_setting(key, value)` → Meta `set_setting` (contract) · `reset_profile_requested` → `confirm` → Meta `reset_profile` (contract) · `back` |
| `pause` | O | Pause (between matches) | Resume · Settings · Abandon run (confirm, "counts as a loss") · Quit to menu (saves are already at S1–S4) | `close` · `open_settings` · `abandon` → `confirm` → `abandon()` · `go_main_menu` |
| `confirm` | O | Confirm dialog | Title, body, Confirm / Cancel; Cancel focused by default | `confirm` · `cancel` |
| `toast` | O | Unlock / warning toast | Queued one-at-a-time banner at top-right: unlock ("New hero unlocked: Fortune"), `run_warning` codes (`save_failed`, `boss_pool_short`, …) | `dismiss` (local) |
| `data_error` | B | Data error | Card Database `Failed` report: count, rows (file, id, code, message) in a scrollable list, "Copy report", Quit; nothing else is reachable | `copy_report` · `quit_requested` |

**U3 — Input: mouse primary, keyboard complete.** DD-T05 and ui-code rule 3. Every intent is
reachable by keyboard: `1`/`2`/`3` move focus to option *n* on any 3-option screen (hero select,
both drafts) and `Enter` confirms the focused option; `Esc` = `back` / `close` / `cancel`;
`Space`/`Enter` on a focused button activates it. Hover never carries unique information
(art bible §7): the hover preview duplicates card text, the synergy hint is also shown under the
focused treasure. Default focus per screen is the **most likely next action**: Start on hero
select (with the last-played or War pre-selected), Fight on the boss intro, nothing on a draft
(forcing a choice), *New Run (same hero)* on both summaries, Cancel on every confirm. Gamepad
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

**U5 — Toast queue.** Toasts are enqueued from `run_warning` and Meta's unlock notifications
(contract: `unlock_granted{kind: hero|treasure, id, name_key}`) and shown one at a time for
`t_toast` (F3) **only while the shell is idle**: `transitioning == false` and `ShellState ∉
{match, run_start, data_error}`. A toast raised during a match or a transition waits; the queue
drains in arrival order with a `toast_gap_ms` pause. Toasts are never modal and never steal
focus. Queue cap `toast_queue_max` (default 8): beyond it the oldest *warning* is dropped first,
unlocks are never dropped.

**U6 — Progress strip.** A persistent overlay on `boss_intro`, `draft_treasure`, `draft_bundle`
and `pause`: `F` nodes left to right, each `cleared` (filled, boss initial shown), `current`
(ring in band colour, boss initial shown), or `upcoming` (hollow, **band colour only — never
the boss identity**, run-structure UI Requirements); treasure floors carry a small gem mark
under the node; held treasures as icons at the strip's left; deck size ("24 cards") at its
right. Geometry is F4; it is rendered from the read model (`floor`, `boss_sequence` masked to
`floor`, `treasures`, `len(deck)`), and updates on `deck_grew`, `treasure_granted`,
`run_floor_entered`.

**U7 — Hero select rules.** Panels are built from `HeroDef`s present in Card Database; a hero
is Available when Meta says unlocked (MVP: always), else Locked (heroes.md States). A locked
panel shows the silhouette placeholder (neutral frame grey, lock glyph, name) and its unlock
hint with live progress ("Win a run with any hero — 0/1", Meta contract); it is focusable (so
the hint is keyboard-reachable) but `start_run` from it is not sent. If **no** locked hero exists
in data (MVP), the locked row is simply absent — no "coming soon" filler. On a fresh profile
War is pre-selected (concept onboarding note; heroes.md H-2 says Run Structure owns a *forced*
rule, which run-structure.md does not state — this GDD pre-selects, never forces; Open
Questions). The seed field accepts any text (RNG & Event Log F1 parses everything) and echoes
the normalised 16-hex form on edit; empty = random. Starting with an active run saved first
raises `confirm` ("This ends your current run — counted as a loss").

**U8 — Drafts.** Contract with Reward Draft — **to be confirmed in reward-draft.md**: on
`draft_offered{floor, kind, offered_ids[], theme_labels[]?}` the controller builds three
options: for `treasure`, `TreasureDef` (name, rarity, text, `synergy_tags[]`); for `bundle`,
`BundleDef` (name/theme label, 3 `CardDef`s). The synergy hint counts deck cards whose `tags`
intersect the treasure's `synergy_tags` (contract: both fields exist; if absent the hint is
hidden, not blank). `pick(index)` requires `0 ≤ index < 3` and the screen not `committed`; the
controller sends `draft_pick(kind, offered_ids[index])`; on `treasure_granted` / `deck_grew` it
plays the fly-to-strip animation, then transitions (treasure → `draft_bundle`; bundle →
`boss_intro` on `run_floor_entered`). A rejection (`E_NOT_OFFERED`, `E_DRAFT_DONE`,
`E_DRAFT_KIND`) uncommits the screen and shows a toast; it must never happen in normal play.

**U9 — Summaries.** Built from `RunRecord.result`, `totals`, `match_summaries`, `drafts`,
`treasures`, `run_seed_hex` (run-structure R6/R10) plus Meta's `unlocks_granted[]` for this run
(contract). Victory and defeat share one layout and differ by palette (art bible §2) and
headline. **New Run (same hero)** is the default focus and sends `new_run(hero_id, "")`
immediately — no confirm, no second screen (Pillar 3; F1 budget). Copy seed writes the
16-hex string to the clipboard and flashes "Copied".

**U10 — Debug fixtures and screenshot reachability.** Per `.claude/docs/run-and-observe.md`,
every base screen is reachable from a launch argument: `--run-ui-screen=<id>
--run-ui-fixture=<name>` loads `tests/fixtures/run_ui/<name>.json` (a profile + optional
`RunRecord` + optional draft offer) into an in-memory Meta stub and opens the screen with no
transition. Debug-build only; ignored in export builds. Required fixtures: `fresh_profile`
(no runs, no active run, War only unlocked-and-present), `mid_run_floor4` (F = 8, floor 4,
2 treasures, deck 24, `pre_match`), `victory_sample` (full 8-floor record, 1 unlock granted),
`defeat_sample` (fell on floor 5, `attempt = 2` on floor 3, reason `hero_dead`),
`locked_heroes` (all six `HeroDef`s present, three locked with hints). Derived fixtures that
reuse those records: `draft_treasure_sample`, `draft_bundle_sample` (offers of 3), `resume_prompt`
(from `mid_run_floor4`), `data_error_sample` (a 12-row validation report), `toast_sample`
(3 queued). Each fixture names the screens it serves (Acceptance Criteria).

### States and Transitions

`ShellState` is the base screen plus the overlay stack and the `transitioning` flag. Base
states map onto Run Structure phases as shown; overlays do not change the mapped phase.

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| `boot` | App start | Card Database `Ready` → `main_menu`; `Failed` → `data_error` | Black `bg_edge`; no input |
| `data_error` | Card Database `Failed` | Quit only | Terminal; report listed; nothing else reachable |
| `main_menu` | Boot OK; `return_to_menu`; back from run log / settings | Any menu intent | Run phase: Menu. Continue visible iff `load_active_run()` non-null |
| `hero_select` | New Run; `go_hero_select` from a summary | `start_run` accepted → `run_start`; `back` | Run phase `hero_select`; in-memory only |
| `run_start` | `run_started` event | `run_floor_entered` received and `run_start_ms` elapsed or skipped | Shows seed; phase `pre_match` (floor 1) |
| `boss_intro` | `run_floor_entered` (any floor, incl. resume into `pre_match`, `match_faulted`) | `begin_match` → `match`; `abandon` → `summary_abandoned` | Phase `pre_match`; strip visible; Fight focused |
| `match` | `begin_match` accepted | `match_ended` acknowledged by Match UI → `draft_treasure` / `draft_bundle` / `summary_*` per `run_floor_entered` / `draft_offered` / `run_ended` | Phase `in_match`; Run UI hidden; toasts held |
| `draft_treasure` | `draft_offered{kind: treasure}` | `treasure_granted` → `draft_bundle`; `abandon` | Phase `post_match_reward/treasure`; strip visible |
| `draft_bundle` | `draft_offered{kind: bundle}` | `deck_grew` + `run_floor_entered` → `boss_intro`; `abandon` | Phase `post_match_reward/bundle` |
| `summary_victory` / `summary_defeat` / `summary_abandoned` | `run_ended{outcome}` | `new_run_same_hero` → `run_start`; `go_hero_select`; `go_main_menu` | Terminal phases; toasts drain here (unlocks) |
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
| S11 | `match` | `match_ended` acknowledged | — | next event decides: `draft_offered` → S12/S13; `run_ended` → S16 | — |
| S12 | `match` | `draft_offered{treasure}` | — | build 3 treasure options | `draft_treasure` |
| S13 | `match` / `draft_treasure` | `draft_offered{bundle}` | — | build 3 bundle options | `draft_bundle` |
| S14 | `draft_treasure` | `pick(i)` | `0 ≤ i < 3`; not `committed`; not transitioning | `committed`; `draft_pick(treasure, id_i)`; on `treasure_granted` fly-to-strip | `draft_bundle` (S13) |
| S15 | `draft_bundle` | `pick(i)` | as S14 | `committed`; `draft_pick(bundle, id_i)`; on `deck_grew` fly-to-strip; on `run_floor_entered` transition | `boss_intro` |
| S16 | `match` | `run_ended{victory\|defeat}` | — | build summary; focus New Run; enqueue unlocks | `summary_victory` / `summary_defeat` |
| S17 | `boss_intro`, `draft_*`, `pause` | `abandon` | `confirm` accepted | `abandon()`; `run_ended{abandoned}` | `summary_abandoned` |
| S18 | any `summary_*` | `new_run_same_hero` | not `committed` | `new_run(hero_id, "")` | `run_start` |
| S19 | any `summary_*` | `go_hero_select` / `go_main_menu` | — | `return_to_menu` | `hero_select` / `main_menu` |
| S20 | any run base screen except `match` | `open_pause` / `Esc` | — | push `pause` | +`pause` |
| S21 | any idle state per U5 | toast queue non-empty | `transitioning == false` | show head for `t_toast`, then `toast_gap_ms` | same |
| S22 | `main_menu` | `quit_requested` | — | flush settings (Meta contract); quit | — |

### Interactions with Other Systems

| System | Direction | Data in (to Run UI) | Data out (from Run UI) | Interface owner |
|---|---|---|---|---|
| **Run Structure** | upstream (commands go down, events come up) | Run-scope events (`run_started`, `run_floor_entered`, `run_resumed`, `match_faulted`, `deck_grew`, `treasure_granted`, `run_warning`, `run_saved`, `run_ended`); `RunState` read model (floor, band via `floor_band`, `boss_sequence[0..floor−1]`, deck, treasures, `run_seed_hex`, summary data); rejection codes | Commands `new_run`, `begin_match`, `draft_pick`, `abandon`, `resume`, `return_to_menu` | Run Structure (R1–R10, T1–T18); this GDD owns the intent → command map (U2) |
| **Reward Draft** | upstream | `draft_offered{floor, kind, offered_ids[], theme_labels[]?}`; `draft_picked` | `pick(index)` → `draft_pick(kind, offered_ids[index])` via the run | **Contract — to be confirmed in reward-draft.md**: exactly 3 offers; ids resolve in Card Database; `synergy_tags[]` on `TreasureDef` and `tags[]` on `CardDef` for the hint (hidden if absent) |
| **Meta Progression** | upstream | `load_active_run()` presence for Continue; `is_hero_unlocked(id)`, `unlock_hint(id) → {text_key, progress, target}`; `profile_stats()`; `list_runs(filter) → [RunRecord summary]`, `get_run(run_id)`; `unlock_granted` notifications; `get_setting/set_setting`; `reset_profile()` | `set_setting(key, value)`, `reset_profile()`; nothing else — all run writes go through Run Structure | **Contract — to be confirmed in meta-progression.md**: settings keys `volume_master/music/sfx` (0–1), `fullscreen`, `anim_speed` (`instant\|fast\|normal`), `telegraph_mode`, `high_contrast_states`; corrupt save → reason + New run (run-structure R8) |
| **Card Database** | upstream | `HeroDef`, `HeroPowerDef`, `BossDef` (`name`, `intro_text`, `passive` text, `health`), `TreasureDef`, `BundleDef`, `CardDef`; `data_version`; the `Failed` validation report `[{file, id, code, message}]` | — (read-only) | Card Database (CR-3, UI Requirements) |
| **RNG & Event Log** | upstream | Event envelope `{seq, type, payload}`; `run_seed_hex` display form; F1 seed parsing (the UI only echoes the normalised form) | — | RNG & Event Log |
| **Match UI** | sibling (handoff) | `match_ended(MatchResult)` acknowledgement after its end overlay; Match UI owns everything from `begin_match` to that acknowledgement | `MatchConfig` (built by Run Structure R3, passed through), the `match` scene swap, settings (`anim_speed`, volumes) | **Contract — to be confirmed in match-ui.md**: Match UI's end overlay has one Continue intent that returns control; it does not navigate |
| **Heroes** | upstream (data) | Identity line, colours (art bible §4), hero power text, starter deck for the preview strip; Locked/Available states | — | Heroes (H-2, H-7, UI Requirements) |
| **Boss AI** | passthrough | — | `telegraph_mode` setting value (Boss AI tuning knob) | Boss AI owns the knob; Run UI only stores and displays it |
| **Art bible** | data | Tokens (§4), mood per state (§2), card slot layout (§4) | — | art-director |

## Formulas

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## Game Feel

[To be designed]

## UI Requirements

[To be designed]

## Cross-References

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
