# Run UI

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
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
| toast_base_ms, toast_per_char_ms | int | 1000–3000, 20–50 | data file (2000, 30) | Reading-time model |
| toast_min_ms, toast_max_ms | int | 1500–3000, 4000–8000 | data file (2000, 6000) | Bounds |
| toast_gap_ms | int | 100 – 500 | data file (150) | Pause between queued toasts |

**Output Range:** 2000 – 6000 ms. **Example:** "New hero unlocked: Lady Tallow" (32 chars) →
2960 ms; a 40-row save-failed detail is capped at 6000 ms and the detail lives in the log.

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
- **If a treasure or bundle id in `offered_ids` does not resolve** in Card Database: the option
  renders as an error frame ("missing: <id>") and is not pickable; a `ui_data_missing` warning
  toast is raised. Card Database validation should make this unreachable; the UI still does not
  crash.
- **If the player presses `Esc` on a draft**: the pause overlay opens; the draft is not
  abandoned by `Esc` alone — abandon needs the confirm.

**Toasts and unlocks**
- **If an unlock toast is raised during a transition or a match**: queued until the shell is
  idle (U5); after a victory it therefore shows over the summary, which is where the player
  expects it.
- **If more than `toast_queue_max` toasts are pending**: warnings drop oldest-first; unlock
  toasts are never dropped (they are also listed on the summary and in the run log, so a
  dropped toast would still not lose information).

**Summaries and run log**
- **If the run log has been pruned** (Meta's `max_archived_runs`) **when a victory summary
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
  placeholder. **If a locked hero exists but Meta cannot answer `unlock_hint`**: the panel shows
  the lock without a hint line.
- **If the profile is fresh and `last_hero` is null**: War is pre-selected; otherwise the
  last-played hero (Meta contract `last_hero_id`).

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
  three-option screens, Tab/arrows elsewhere (U3). A screenshot fixture with keyboard-only
  navigation proves it (AC-19).
- **If `anim_speed = instant`**: every transition is 0 ms and every `committed` state resolves
  on the next event; the input lock still exists (it is state-based, not time-based), so
  double-picks remain impossible.

## Dependencies

Hard = the shell cannot show its screens without it; soft = a stub suffices. Bidirectional check
against `design/gdd/systems-index.md`: the index lists Run UI as depending on Run Structure,
Reward Draft, Meta Progression, Card Database and RNG & Event Log — all below. Run Structure
(its Dependencies and Interactions) already names Run UI as a dependent — consistent. Card
Database (UI Requirements: data-error screen, draft picker, boss intro, hero select) and Heroes
(UI Requirements, Cross-References) name Run UI surfaces — consistent. Reward Draft, Meta
Progression and Match UI GDDs are being authored concurrently or do not exist; their rows are
provisional and must name Run UI back.

| System | Direction | Hard/Soft | Nature of dependency / interface |
|---|---|---|---|
| Run Structure | This depends on Run Structure | Hard | The six commands and the run-scope events (Interactions). Run UI mirrors its phase machine (States and Transitions) and renders its read model; it never saves, never computes a seed, never decides a phase. |
| Reward Draft | This depends on Reward Draft | Hard (for drafts) | `draft_offered` with exactly 3 ids and optional theme labels; `pick(index)` maps to `draft_pick(kind, id)`. **Contract** (U8); `synergy_tags`/`tags` for the hint are soft (hint hidden if absent). |
| Meta Progression | This depends on Meta Progression | Soft for MVP (in-memory stub: no Continue, all heroes unlocked, no log), Hard from Vertical Slice | Continue presence, unlock state and hints, profile stats, run log list/detail, unlock notifications, settings get/set, reset profile. **Contract** (Interactions). Meta's own UI Requirements should name these surfaces as Run UI's. |
| Card Database | This depends on Card Database | Hard | All definitions displayed; the `Failed` report for the data-error screen; `text.en` / key fallback rule. |
| RNG & Event Log | This depends on RNG & Event Log | Hard | Event envelope the controller renders from; `run_seed_hex` display form; F1 for the seed echo. |
| Match UI | Mutual (sibling) | Hard | Scene handoff at `begin_match`; control returns on the end overlay's Continue with `match_ended` already processed by Run Structure. **Contract — to be confirmed in match-ui.md.** Shared: settings values, art-bible theme resource. |
| Heroes | This depends on Heroes (data) | Hard | Hero select content: identity line, power text, starter deck preview, colours, Locked/Available. |
| Boss AI | Passthrough | Soft | `telegraph_mode` setting stored and shown; Boss AI reads it. |
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
| `anim_speed` (player setting) | `normal` | `instant \| fast \| normal` | — | `instant` zeroes every duration; accessibility requirement, never removed |
| `toast_base_ms` / `toast_per_char_ms` / `toast_min_ms` / `toast_max_ms` / `toast_gap_ms` | 2000 / 30 / 2000 / 6000 / 150 | F3 ranges | Longer-lived toasts; a 6 s cap keeps a queue of 8 under 50 s | Toasts vanish before they are read |
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
| Treasure / bundle draft | Table cleared: only the three offers on `table_lit`; `parchment` frames; focused/hovered option gets the `state_actionable` outline and lifts 8 px; Pick lit only when an option is focused | Draft reveal (3 soft card slaps staggered per F2); pick confirm | Must |
| Fly-to-strip | Picked cards/treasure shrink along a straight path to the strip; deck count ticks up in `state_buff` for one beat | Deck thump | Should |
| Progress strip | Cleared nodes filled `text_light`, current ringed in band colour, upcoming hollow in band colour; gem marks for treasure floors | None | Must |
| Victory summary | Full `table_lit` warmth; hero portrait saturates to its primary (the one allowed saturation, art bible §4 rule b) | Victory stinger | Must |
| Defeat summary | Torch out: `bg_edge` everywhere; summary and killing boss lit in `text_light`; no red wash, no shake | Defeat stinger, short (Pillar 3) | Must |
| Unlock toast | `table_dark` banner, `text_light`, hero/treasure name in its identification colour | Unlock chime | Should |
| Warning toast | Same banner, `text_muted` body, no colour | None | Low |
| Confirm dialog | `table_dark` panel on dimmed base; Cancel focused | None | Must |
| Data error | `bg_edge`, report rows in `text_light` / `text_muted`, codes in `state_danger` on `ink` pills | None | Must |

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
| New Run / Continue card / Run Log / Settings / Quit; profile stats line | `main-menu.md` | On open; Continue on `load_active_run` | Always; Continue iff an active run is saved |
| Active run found: hero, floor n of F, phase; Continue / Abandon ("counts as a loss") | `main-menu.md` (resume prompt) | Once | Continue pressed |
| Hero roster (name, identity line, colour, power, 15-card preview strip, win count); locked silhouettes with unlock hint and progress; seed field with hex echo; Start / Back | `hero-select.md` | On open; on selection; on seed edit | `hero_select`; locked rows only when locked `HeroDef`s exist |
| Seed hex on a hero-colour panel | `run-start.md` (may fold into `boss-intro.md`) | Once per run | `run_started` |
| Floor n of F, band pips, boss portrait placeholder, name, intro line, passive text, boss health, hero power text, deck size; Fight | `boss-intro.md` | `run_floor_entered` | `pre_match` |
| Progress strip: F nodes (cleared / current / upcoming by band), gem marks, treasure icons, deck size | `progress-strip.md` (shared component) | `deck_grew`, `treasure_granted`, `run_floor_entered` | Any run screen except match |
| Treasure draft: 3 frames with rarity and text, synergy hint, Pick; `1`/`2`/`3` + Enter | `draft-treasure.md` | `draft_offered{treasure}` | `post_match_reward/treasure` |
| Bundle draft: 3 panels × (theme label + 3 compact card rows), hover/focus 1.5x preview, Pick | `draft-bundle.md` | `draft_offered{bundle}` | `post_match_reward/bundle` |
| Summary: outcome headline, hero, floors cleared, killing boss and reason, seed + Copy, top-N damage, drafted cards, treasures, new unlocks, duration/turns, `attempt > 1` marks; New Run (same hero) / Hero Select / Main Menu | `run-summary.md` (victory + defeat + abandoned variants) | `run_ended` | Terminal phases |
| Archived runs list (date, hero, outcome, floor, seed), hero filter, Open; read-only summary | `run-log.md` | On open; on filter | Menu |
| Volumes, fullscreen, animation speed, boss telegraph mode, high-contrast state colours, Reset profile (confirm) | `settings.md` | On change (live) | Menu or pause |
| Pause: Resume / Settings / Abandon run (confirm) / Quit to menu | `pause.md` | On open | Any run screen except match |
| Toast: unlock or warning text, queued | `toast.md` (shared component) | Per queue drain | Shell idle (U5) |
| Data error: validation report rows, Copy report, Quit | `data-error.md` | Once at boot | Card Database `Failed` |

📌 **UX Flag — Run UI**: This system has UI requirements. In Phase 4 (Pre-Production), run
`/ux-design` for each screen above **before** writing epics; `progress-strip` and `toast` are
shared components and belong in `design/ux/interaction-patterns.md` or their own specs. Stories
that reference UI should cite `design/ux/[screen].md`, not this GDD directly. Note this in the
systems index for this system if you update it.

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|---|---|---|---|
| Six commands; phases `hero_select`…`abandoned`; T1–T18; `E_HERO_LOCKED`, `E_DRAFT_*` | `design/gdd/run-structure.md` | Core Rules R2–R6, R8, States and Transitions | State trigger |
| `RunRecord` fields for summaries (`result`, `totals`, `match_summaries`, `drafts`, `run_seed_hex`); `summary_top_cards` | `design/gdd/run-structure.md` | R1, R10, Tuning Knobs | Data dependency |
| Treasure before bundle; resume re-offers the same options; `allow_custom_seed` | `design/gdd/run-structure.md` | R5.2, R8.2, R9 | Rule dependency |
| Restart under 5 s | `design/gdd/run-structure.md` | Game Feel, AC-29 | Rule dependency (this GDD owns the budget breakdown, F1) |
| Upcoming floors show band only, never boss identity; Continue card contents; pause menu split | `design/gdd/run-structure.md` | UI Requirements | Rule dependency |
| `floors_per_run` (8 / MVP 4), `floor_band`, `boss_sequence` | `design/gdd/run-structure.md` | Registry constants/formulas | Data dependency |
| Seed parsing of any input; 16-hex display form | `design/gdd/rng-event-log.md` | F1 | Rule dependency |
| Event envelope `{seq, type, payload}`; render-from-events | `design/gdd/rng-event-log.md` | Core Rules D; DD-T04 | Rule dependency |
| `HeroDef`, `BossDef` (`intro_text`, `passive`), `TreasureDef`, `BundleDef`, `CardDef`; `Failed` report; `text.en` fallback | `design/gdd/card-database.md` | CR-3, States, UI Requirements | Data dependency |
| Identity lines, colours, power text, Locked/Available, win counts on hero select; `HERO_LOCKED` | `design/gdd/heroes.md` | H-2, H-7, States, UI Requirements | Data dependency |
| `draft_offered` shape; 3 offers; `synergy_tags` | `design/gdd/reward-draft.md` *(concurrent)* | Offer contract (U8) | Ownership handoff (contract) |
| Persistence API, unlock hints, run log queries, settings keys, `unlock_granted`, corrupt-save handling, `last_hero_id` | `design/gdd/meta-progression.md` *(concurrent)* | Interactions contract | Ownership handoff (contract) |
| Scene handoff; end overlay Continue returns control | `design/gdd/match-ui.md` *(planned)* | Match end handoff (U2 `match`) | Ownership handoff (contract) |
| `telegraph_mode` setting | `design/gdd/boss-ai.md` | Tuning Knobs (telegraph) | Data dependency |
| Mood per state; tokens; card slot layout 150x210 / 225x315; portrait 120x160; typography; high-contrast swap | `design/art/art-bible.md` | §2, §4, §5, §7 | Data dependency |
| Screenshot procedure, launch-argument reachability | `.claude/docs/run-and-observe.md` | Godot row; "Reaching the state" | Rule dependency |

## Acceptance Criteria

`qa-lead` not consulted — Lean mode (no Agent tool). AC-1–8 are observable states for
screenshots (fixture named; `production/qa/evidence/` per run-and-observe); AC-9–22 are logic
criteria for the shell state machine (unit tests with a stubbed `RunController`); AC-23–26
cover formulas and performance.

**Observable (screenshot per fixture)**
- [ ] **AC-1** GIVEN fixture `fresh_profile`, WHEN launched with `--run-ui-screen=main_menu`, THEN New Run, Run Log, Settings, Quit are visible, **no Continue**, and the stats line reads 0 runs.
- [ ] **AC-2** GIVEN `fresh_profile` and `--run-ui-screen=hero_select`, WHEN rendered, THEN exactly the heroes present in data appear, War is pre-selected with its power text and 15-card preview, no locked row exists, and the seed field shows "Random".
- [ ] **AC-3** GIVEN fixture `locked_heroes`, WHEN hero select renders, THEN Fortune, Order and Shadow appear as grey silhouettes with a lock glyph and an unlock hint with progress, and Start is disabled while one of them is focused.
- [ ] **AC-4** GIVEN fixture `mid_run_floor4` and `--run-ui-screen=boss_intro`, WHEN rendered, THEN "Floor 4 of 8", two band pips in rust, the passive text, the hero power text and "24 cards" are visible, the strip shows nodes 1–3 filled with initials, node 4 ringed, 5–8 hollow with no initials, two treasure icons and two gem marks, and Fight is focused.
- [ ] **AC-5** GIVEN `draft_treasure_sample` / `draft_bundle_sample`, WHEN rendered, THEN three options sit at the F4 slot positions (±2 px), rarity/theme labels are legible at 1280x720, no card text is clipped without a preview, and Pick is dim until an option is focused.
- [ ] **AC-6** GIVEN fixture `victory_sample`, WHEN `summary_victory` renders, THEN the hero panel is in its full primary colour, "8 of 8", the 16-hex seed with Copy, a 10-row damage table, drafted cards marked, treasures, one "New hero unlocked" line, and **New Run (same hero)** carries the focus outline.
- [ ] **AC-7** GIVEN fixture `defeat_sample`, WHEN `summary_defeat` renders, THEN the background is `bg_edge`, the headline names floor 5 and the boss, floor 3 shows "attempt 2", no `state_danger` fill larger than a stamp exists on screen, and New Run (same hero) is focused.
- [ ] **AC-8** GIVEN fixture `data_error_sample`, WHEN launched, THEN 12 report rows are listed with file, id, code and message, Copy report and Quit are the only controls, and no other screen is reachable by any key.

**Shell state machine (logic)**
- [ ] **AC-9** GIVEN `draft_bundle` with an option focused, WHEN `pick(1)` is sent twice within 100 ms, THEN exactly one `draft_pick(bundle, offered_ids[1])` reaches the controller and the second intent logs `ui_intent_rejected`.
- [ ] **AC-10** GIVEN `transitioning == true`, WHEN any intent other than `skip` arrives, THEN it is dropped, no command is issued, and `skip` ends the transition immediately.
- [ ] **AC-11** GIVEN every ShellState, WHEN each intent in U2 is sent, THEN only the rows in S1–S22 produce a command; every other (state, intent) pair is rejected with `bad_state` and changes nothing.
- [ ] **AC-12** GIVEN a `main_menu` with an active run saved, WHEN `continue` is accepted and `resume()` returns `OK` with `status = post_match_reward/treasure`, THEN the shell enters `draft_treasure` with the three re-offered ids, no `hero_select` or `run_start` in between.
- [ ] **AC-13** GIVEN `resume()` returns `E_CORRUPT`, WHEN Continue was pressed, THEN a reason dialog with a single New Run button appears, the Continue card is gone on return to the menu, and no `abandon()` command was sent by the UI.
- [ ] **AC-14** GIVEN `hero_select` with an active run saved, WHEN `start_run` is sent, THEN `confirm` opens first and `new_run` is issued only after `confirm`; `cancel` leaves the run untouched.
- [ ] **AC-15** GIVEN the shell in `match`, WHEN an `unlock_granted` arrives, THEN no toast is shown until the shell reaches a summary, where it shows for `t_toast` and then drains the next.
- [ ] **AC-16** GIVEN a queue of `toast_queue_max + 2` warnings and 1 unlock, WHEN drained, THEN the two oldest warnings were dropped and the unlock was shown.
- [ ] **AC-17** GIVEN a summary, WHEN `new_run_same_hero` is sent, THEN `new_run(hero_id, "")` is issued with no confirm and the next state is `run_start`.
- [ ] **AC-18** GIVEN `hero_select`, WHEN the seed field holds `"deckdelve"`, THEN the echo shows `48A10CC0B2ED54EC` (RNG & Event Log F1 example) and `start_run` passes the raw string, not the echo.
- [ ] **AC-19** GIVEN any three-option screen, WHEN keys `2` then `Enter` are pressed with no mouse input, THEN option index 1 is picked/selected; GIVEN a full run driven only by keyboard, THEN every screen in U2 is reached and left without a mouse event.
- [ ] **AC-20** GIVEN `anim_speed = instant`, WHEN any transition runs, THEN its duration is 0 ms, `committed` still blocks a second intent, and the result is identical to `normal`.
- [ ] **AC-21** GIVEN an `offered_ids` entry that does not resolve in Card Database, WHEN the draft renders, THEN that slot shows the missing-id frame, is not pickable, and the other two are.
- [ ] **AC-22** GIVEN every user-visible string in `src/ui/run/**`, WHEN scanned, THEN each is a `tr()` key or data `text` — zero literal English strings (CI grep).

**Formulas and performance**
- [ ] **AC-23** GIVEN defaults, WHEN defeat → New Run (same hero) is timed from the Enter key to the boss intro's first rendered frame, THEN it is ≤ 1350 ms + 15 % and never above `restart_budget_ms`; path B via hero select with a 1500 ms scripted pause is ≤ 5000 ms (F1).
- [ ] **AC-24** GIVEN F = 8 and F = 4, WHEN the strip lays out, THEN node centres are at 416 + 64·(f−1) and 544 + 64·(f−1) respectively (F4), and the strip width never exceeds 640 for F ≤ 12.
- [ ] **AC-25** GIVEN toast texts of 10 and 200 chars, WHEN `t_toast` is computed, THEN the results are 2300 ms and 6000 ms (F3 bounds).
- [ ] **AC-26** Performance: every base screen builds and renders its first frame within 100 ms on the reference machine from its read model; building the victory summary from a 36-card, 8-summary record stays under 50 ms; no screen allocates per frame while idle.
- [ ] **AC-27** No hardcoded values: every duration, size and count in F1–F4 is read from `assets/data/run_ui.json` or the theme resource; a test changes `node_d` and observes the strip move.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| `assets/data/run_ui.json` is a new data file not in DD-T01 — add it (same situation as `run_structure.json`). | Owner (orchestrator) | Before `/create-architecture` | Open — proposed here |
| "First run forces War" (heroes.md H-2 says Run Structure owns it; run-structure.md does not state it). This GDD pre-selects War on a fresh profile and never disables other available heroes. Confirm pre-select is enough. | Owner / Run Structure GDD | `/consistency-check` | Decision taken here: pre-select, not force |
| Bundle panels show three **compact card rows** (300x64) plus a 1.5x preview rather than three full 150x210 cards, because 9 full cards do not fit 1280 px at the 12 px text minimum. Confirm with `/ux-design draft-bundle`; alternative is a two-step bundle screen (pick a bundle, then see its cards). | ux-designer | `/ux-design draft-bundle` | Decision taken here: compact rows + preview |
| `draft_offered` payload: does Reward Draft send `theme_labels[]` or does the UI read `BundleDef.name`? Does `TreasureDef.synergy_tags[]` / `CardDef.tags[]` exist for the hint? | Reward Draft + Card Database GDDs | `/design-system reward-draft` | Contract proposed (U8); hint hidden if absent |
| Meta API names used here (`unlock_hint`, `profile_stats`, `list_runs`, `get_run`, `get_setting/set_setting`, `reset_profile`, `last_hero_id`, `unlock_granted`) and the settings key list. | Meta Progression GDD | `/design-system meta-progression` | Contract proposed (Interactions) |
| Match UI handoff: does the match end overlay belong to Match UI (assumed) with a single Continue returning control, or does Run UI draw the overlay over the frozen board? | Match UI GDD | `/design-system match-ui` | Contract proposed (U2 `match`) |
| Pause during a match is Match UI's (Concede); between matches it is Run UI's (Abandon). One pause scene with two modes, or two scenes? | ux-designer / ui-programmer | `/ux-design pause` | Open — this GDD specifies behaviour only |
| Debug fixture loading via `--run-ui-fixture` needs a Meta stub; whether that is a `RunController` injection seam or an autoload flag → ADR. | technical-director | `/create-architecture` | → ADR |
| Gamepad is mapped to the same focus graph (U3); DD-T05 names mouse + keyboard only. Is gamepad a v1 requirement (ui-code rule 3 says yes) or Alpha? | Owner | Pre-production | Open — designed as reachable, not tested in MVP |
| Abandoned-run summary: full summary (as victory/defeat) or the one-line notice specified here? | Owner | `/ux-design run-summary` | Decision taken here: one line + buttons |
