# Boss AI

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
> **Author**: Jacob (owner) + `/design-system boss-ai` (tier standard, guided, lean)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 2 (bosses are puzzles), Pillar 3 (lose fast, learn fast — telegraphed intent), Pillar 4 (readable, deterministic rules)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` `ai-programmer`, `systems-designer`, `qa-lead` not consulted — Lean mode, single-agent run; review Formulas and Acceptance Criteria manually before production. Technical feasibility: engine domain **Scripting** — no engine reference for `scripting` under `docs/engine-reference/godot/modules/`; feasibility not checked against the pinned engine (the system is pure GDScript logic with no engine surface beyond `RandomNumberGenerator`, already covered by RNG & Event Log).

> **REVISED 2026-11-03** (`/design-review`, lean, independent reviewer — blocking items fixed in place): F1 worked example recomputed (2.45 / 1.87, was 2.31 / 2.2) and A11 updated; C1.3 now forbids reading `card_drawn` and other hidden-payload events (the log records the player's draws) and A4 tests it; C1.5 no longer waives the `.claude/rules/ai-code.md` 2 ms/frame rule — the planner runs off the main thread or time-sliced, A30 measures it; `op_values` keys realigned to Card Effects' real op names, `position_sensitive`/`aoe`/synergy matching derived from selectors and triggers (Card Effects defines no AI annotations), C7 handles `kind: choose_one`; `intent_banner_s` fixed at 0.3 s with a separate `plan_changed_s` 1.2 s (F9 said 1.2, Game Feel and Match UI said 0.3); A6/A7 made testable; C2 pseudocode emits the `ai_decision` A24 requires, counts plan steps and matches F6's armour term; F7 match bound corrected to 1,500; stale "planned/provisional" notes on card-effects.md, DD-T01 and `clone()` hooks resolved; C9 gains a rule-by-rule ai-code.md compliance list.

> **REVISED 2026-11-03 (cross-review)**: C-01 (DD-X03 — `effective_mode = min(intent_mode, telegraph_mode)` in C8.4; Meta Progression added to Interactions, Dependencies, Tuning Knobs, Cross-References; A19 extended), C-14 (one parent `ai_<floor>` draw per new fork label — C9, A3, A5), C-15 (`ai_profiles.json` is loaded by Card Database, read via `config("ai_profiles")` — Interactions, Dependencies), C-30 (intent events are catalogued in rng §D; diagnostics cite rule 12a — C9, Interactions, Dependencies, Cross-References, Open Questions), D-04 (boss `intent_mode` capped at `class_only`; `hidden` is reserved for a boss whose passive text announces concealment and recorded in Content B2 — C8.4, F9, UI Requirements, A19), D-07 (harness win-rate basis = `target_win_rate_by_floor` — Open Questions, C11).

> **REVISED 2026-11-03 (housekeeping)**: Edge Case "`ai_profiles.json` absent" reworded — Card Database CR-1 fails the load with `E_MISSING_FILE`; the headless-test fallback is an injected stub profile, not a runtime default; C8.1 forecast mana `mana_max + 1` → `mana_max_by_turn(t_side + 1)` (includes `crystal_bonus`).

## Summary

Boss AI is the opponent that pilots every boss deck: each boss turn it lists the legal moves,
scores them with data-driven weights (board value, face damage versus trades, threat removal,
mana and card efficiency, over-extension), always takes a proven lethal, and stops when ending the
turn scores best. For the player it shows up as a truthful intent banner at the start of their
turn and as short, evenly paced boss turns; for the studio it is deterministic from the run seed
and logs every decision, which makes bosses balanceable through a seeded AI-vs-AI harness.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Match Rules, Card Effects, Card Database, RNG & Event Log`

## Overview

Boss AI is the opponent in every match: a deterministic turn planner that plays whichever boss
deck Content hands it, competently and legibly. On each boss turn it asks the rules engine for
the full list of legal commands (Match Rules C2), scores every candidate with a weighted
heuristic — board value, face damage versus trades, threat removal, mana efficiency, card
advantage, over-extension risk — executes the best one, and repeats until `end_turn` scores
highest. Before scoring it runs a bounded lethal search ("can I kill the player this turn?") and
always takes lethal when it exists. Every weight, rule and budget comes from the boss's
`ai_profile` in `assets/data/ai_profiles.json`, merged from a default, an archetype (aggro,
control, tempo, passive-driven), a difficulty band and a per-boss override — so a band-1 boss
makes teaching mistakes on purpose and a band-3 boss plays the same deck ruthlessly, with no code
change between them (Pillar 2: the passive and the deck are the puzzle; the AI makes them bite).

The player feels this system twice. Directly, as the **intent banner**: at the start of their own
turn they see what the boss plans to do next ("will attack your hero for 7", "will play a big
minion"), derived from a real dry run of the planner against the current board, not a scripted
bluff; if their turn breaks that plan the banner says so (Pillar 3: every loss teaches something
legible). Indirectly, as pacing: the planner decides the whole turn synchronously inside the
engine, and the Match UI replays the already-decided actions one at a time at a readable cadence,
so boss turns are short and never "think". Everything the AI does is reproducible from the run
seed — tie-breaks come from the `ai_<floor>` stream and every decision is logged with its top
alternatives — which is what makes the AI-vs-AI simulation harness, and therefore boss balance,
possible (Pillar 4). Without this system the bosses are decks with no pilot; with a bad one they
are either random or trivial, and the gauntlet stops being a puzzle.

## Detailed Design

### Core Rules

#### C1. Architecture and lifecycle

1. `BossAI` is a `RefCounted` with no Node references (DD-T02), constructed per match by Run
   Structure's match driver with `(boss_def, resolved_profile, band, ai_stream, op_values)`.
   `ai_stream` is the injected `ai_<floor>` stream (RNG & Event Log rule 3); the AI never calls
   `stream()` itself and never touches `match_<floor>`.
2. The AI is a **pure function of (observable state, profile, stream position)**. It reads
   `MatchState` through `legal_commands()` and `MatchState.clone()` (Match Rules C2) and mutates
   nothing except through `submit(command)`. Identical state, profile and seed produce identical
   commands (Acceptance Criteria A1–A3).
3. **Hidden information is not read.** The evaluation never reads `player.hand[*].def_id`,
   either `deck` order, or `pending` Discover options of the player. It may read hand *counts*,
   both boards, both heroes, weapons, graveyards and mana. From the event log it may read only
   **public** events — `card_played`, `effect_resolved`, combat and death events — and never
   `card_drawn`, `card_burned`, `discover_offered` or any payload field naming a card that is
   still in the player's hand or deck (the log records hidden information for replay — RNG &
   Event Log's Match UI row says the same; a human opponent does not see it). The one thing the
   AI remembers across turns is `aoe_seen` (F5), derived from `card_played`. A test with a decoy
   player hand that has also been *drawn* through the engine, so it is in the log (A4), enforces
   this.
4. Entry points, all synchronous: `forecast(engine) → Intent` (called by the driver when
   `PlayerTurn.Main` begins), `play_turn(engine)` (called when `BossTurn.Main` begins; returns
   when the engine leaves `BossTurn.Main`), `choose(engine, choice_request) → option_index`
   (called whenever `phase == Choice` and `pending_choice.side == BOSS`, including mid-`play_turn`).
5. The whole boss turn is decided and executed inside `play_turn` — the events land in the log at
   once. The Match UI then plays them back one action at a time (UI Requirements).
   **`.claude/rules/ai-code.md` budget — 2 ms per frame on the main thread.** The planner's own
   budget is C9's counts, but it may not hold the main thread for more than 2 ms in any frame:
   the driver runs `play_turn` and `forecast` **off the main thread** (a worker task the driver
   polls once per frame) or time-sliced across frames. The mechanism is chosen by ADR
   (`/create-architecture`); it is NOT SOURCEABLE here — no scripting or threading page exists
   under `docs/engine-reference/godot/modules/`. Either mechanism is safe by construction:
   `BossAI` and the engine touch no Node, the UI reads the log only after the call returns, and
   budgets are counts, so the result is identical on and off the main thread. A30 measures it.
   Playback is UI work and is budgeted by Match UI.

#### C2. The action loop (`play_turn`)

```
play_turn(engine):
  mode = NORMAL; actions = 0; rejections = 0
  emit ai_intent_committed(intent_from_plan(first_plan), kept = matches(forecast))
  while engine.phase == BossTurn.Main:
    cmds = engine.legal_commands()
    if cmds == [end_turn] or actions >= budgets.max_actions_per_turn:
        emit ai_decision(end_turn, [], mode, reason)   # reason: only_move | action_cap (A24, A27)
        submit(end_turn); break
    plan = lethal_search(engine)                       # C3; null when none within budget
    if plan: mode = LETHAL; actions += execute_plan(plan); continue  # one ai_decision per step; re-plans if a step is rejected
    if band_rules.defensive and threat_estimate(engine) >= boss_health + boss_armor - rules.defensive_margin:
        mode = DEFENSIVE                               # F6; weights overridden per profile
    best, top3 = score_all(cmds, mode)                 # C4–C6
    emit ai_decision(best, top3, mode)                 # diagnostic event, C10
    result = engine.submit(best); actions += 1
    if not result.accepted: rejections += 1; exclude(best); if rejections >= 3: submit(end_turn)
    while engine.phase == Choice and pending_choice.side == BOSS: engine.submit(choose(...))
```

`end_turn` is always a candidate and is scored like any other action (its features are the
"do nothing" deltas plus the mana-waste penalty, F1), so the AI stops when nothing improves its
position rather than when it runs out of cards.

#### C3. Lethal search

A depth-first search over the **damage subset** of legal commands: attacks, `play_card` for
minions with Charge (any target) or Rush (Taunt clearing), spells and hero power whose effect
spec contains a `damage` op that can target the enemy hero, and weapon plays followed by a hero
attack. Each node clones the state and submits one command; a leaf where `player.hero.health ≤
0` is lethal. Pruning: a node is cut when the upper bound F4 (`potential − taunt_hp <
player_health`) fails. Node budget `budgets.lethal_max_nodes` per band (Formulas F7); on
exhaustion the search returns null and the turn proceeds normally — the AI may still stumble into
lethal through scoring, it just did not *prove* it. A found plan executes step by step against
the live engine; if any step is rejected or the live state diverges from the search path (a
Deathrattle summoned a Taunt), the plan is discarded, `ai_plan_aborted` is emitted and the loop
re-enters at the top (one more search is allowed per turn, then scoring only).

#### C4. Scoring by one-ply simulation

Each candidate `a` is scored as `score(a) = Σ w_i · f_i(a)` (F1). The features are deltas between
the state before and after `a`, measured by submitting `a` on `MatchState.clone()` inside a
**sandbox engine** that shares nothing with the live match: it is given the fork
`ai_stream.fork("sim_<turn>")` for any random effect, so simulated randomness is an estimate, not
a peek at the live stream, and the sandbox auto-answers any Discover it raises with C7. When
`legal_commands()` yields more than `budgets.max_evals_per_action` candidates, the list is
pre-ranked by the cheap `op_value` estimate (C6) and only the top `max_evals_per_action` are
simulated — the rest are never chosen. `end_turn` is always simulated.

#### C5. Heuristic components

Each is a feature `f_i ∈ [−1, 1]` (normalised as defined in F1) with a profile weight:

| Component | Feature | What it rewards |
|---|---|---|
| Board value | `f_board` | Net change in F2 board value (own gain minus enemy gain) |
| Aggression | `f_face` | Damage to the player's hero as a fraction of their health |
| Self-preservation | `f_self` | Penalises damage taken by the boss hero (negative) |
| Trade quality | `f_trade` | +1 favourable / 0 even / −1 unfavourable trade (F3) |
| Threat removal | `f_threat` | F2 threat of enemy minions removed, Taunts and high-attack first |
| Mana efficiency | `f_mana` | Mana spent this action; `end_turn` is charged for unspent mana |
| Card advantage | `f_card` | Net change in (hand + board) count, own minus enemy |
| Over-extension | `f_over` | Penalises own board above the F5 cap once the player has shown AoE |
| Healing | `f_heal` | Healing to the boss hero, counted only against missing health |
| Hero power rule | `f_hp` | +1 when the action is the hero power and `rules.hero_power` allows it |
| Passive synergy | `f_passive` | +1 when the played card matches one of the profile's `synergy_tags` — a Card Database `tags` entry, a DD-M09 keyword, or a Card Effects trigger name such as `deathrattle` (C6 `synergy_match`) |

Teaching mistakes for band 1 are not separate code: they are weight settings (`w_trade` low,
`w_face` high, `rules.lethal_search = shallow`, `w_over = 0`), so the same planner reads as a
reckless brawler on floor 1 and a careful pilot on floor 8.

#### C6. Target and position selection; the op value table

`legal_commands()` already expands every (card × target × position) combination, so target choice
emerges from scoring: "Fireball the 6/6, not the 1/1" is simply the candidate with the higher
`f_threat`. The **op value table** (`op_values` in `ai_profiles.json`, keyed on the Card Effects
C5 op names — `damage`, `heal`, `buff`, `set_stats`, `give_keyword`, `silence`, `freeze`,
`destroy`, `summon`, `transform`, `draw`, `discover`, `add_to_hand`, `copy_to_hand`,
`return_to_hand`, `mana`, `armor`, `equip`, `retrigger`; the structural ops `conditional`,
`repeat` and `choose_one` are valued as the sum of their inner ops, `aura` and `modify_value` as
`buff`) is used in two places only: as the pre-filter rank when candidates exceed the eval budget
(C4), and to value options that cannot be simulated (C7). An op's value is multiplied by the
number of targets its selector yields on the current board (`all_*` selectors, `n` picks), so a
three-target `damage` outranks a one-target one without an AoE row of its own. It is a hint,
never the decision. Three **derived annotations** are computed by Boss AI from the effect spec at
load — Card Effects adds no AI-only fields: `position_sensitive` = any effect on the card uses an
`adjacent`, `left_neighbour` or `right_neighbour` selector (Card Effects C3); `aoe` = any
`damage`, `destroy`, `freeze`, `silence` or negative `buff`/`set_stats` op whose selector is
`all_enemy_minions`, `all_minions`, `all_enemy_characters` or `all_characters` from the caster's
side; `synergy_match(card, tags)` = `card.tags ∩ tags ≠ ∅` (Card Database `tags`) or any keyword
or effect trigger name of the card is in `tags`. Summon **position** is the rightmost slot
(`position = board.size`) unless the card is `position_sensitive`, in which case every position
is a separate candidate.

#### C7. Choice phase (`choose`)

For a `ChoiceRequest` of `kind: discover` the AI scores each option as `op_value(option) ×
cost_fit + preference`, where `op_value(option)` is the card's C6 value (a vanilla body counts as
`buff` value `(attack + health) / 4`), `cost_fit = 1` if the option's cost ≤ the boss's
`mana_max` next turn else 0.5, and
`preference` is the profile's `choice_preference` bonus for the option's tags (aggro: `charge`,
`weapon`; control: `taunt`, `heal`, `damage_all`; tempo: lowest cost; passive-driven: its
`synergy_tags`). For `kind: choose_one` (Card Effects C5: options are `{label_key, ops[]}` with
no card and no cost) each option scores `Σ op_value(op) × targets_now(op)` with `cost_fit = 1`
and `preference` looked up by the option's op names. Identical options (same `def_id`, or
identical `ops[]`) are collapsed to the lowest index **before** tie-breaking, so duplicates
consume no RNG. The decision is logged as an `ai_decision` with `kind = choice`.

#### C8. Telegraphing — the intent is the plan

1. **Forecast.** When `PlayerTurn.Main` begins, the driver calls `forecast(engine)`: the AI runs
   the planner on a clone **as if** it were its own turn with next turn's mana
   (`mana_max_by_turn(t_side + 1)` = `min(t_side + 1 + crystal_bonus, MAX_MANA)`, F4 of Match
   Rules, so a boss `crystal_bonus` is forecast too) and its current hand, using `ai_stream.fork("forecast_<turn>")`, and emits
   `ai_intent_shown {boss_id, intent_key, target_id, amount, effective_mode}` describing the plan's **dominant
   action** — the first lethal step if lethal is proven, else the highest-scoring action class.
2. **Commit.** When `BossTurn.Main` begins the AI plans for real and emits
   `ai_intent_committed {intent_key, target_id, amount, kept, effective_mode}`. `kept = true` when the committed
   intent class equals the forecast; otherwise the UI shows "plan changed" — the player's turn
   broke the plan, which is the lesson Pillar 3 wants them to see.
3. **Intent keys** (closed set): `lethal`, `attack_face`, `attack_minion`, `play_big_minion`
   (cost ≥ 5), `develop_board`, `cast_removal`, `cast_aoe`, `heal`, `hero_power`, `equip_weapon`,
   `pass`. `amount` is the forecast face damage for `attack_face`/`lethal` (attackers that exist
   now; cards in hand are not revealed), `target_id` for `attack_minion`/`cast_removal`.
4. **Shown vs hidden.** Shown: action class, face damage from visible attackers, a named target.
   Hidden: which card will be played, Discover picks, anything that would reveal the hand. The
   profile's `intent_mode` is `full` (default) or `class_only` (no target/amount — bosses whose
   passive is built on concealment, e.g. a Stealth boss). **Boss-imposed intent is capped at
   `class_only`** (cross-review D-04: Pillar 3's own test picks telegraphed over hidden): no band
   overlay sets `hidden`, and band 3 is `full` unless a `boss_override` says `class_only`. The
   third value `hidden` (no banner) is legal in a `boss_overrides` entry **only** for a boss whose
   passive text itself announces concealment (Stealth / fog theme — Content B2 records the reason
   beside the override; at v1 the only candidate is `boss_shadow_of_the_delve`, which Content
   currently sets to `class_only`). Band 1 is always `full`. A player setting `telegraph_mode ∈
   {full, brief, off}` (Meta Progression M9, DD-X03) further restricts it: `effective_mode =
   min(intent_mode, telegraph_mode)` over the order `full > class_only ≡ brief > hidden ≡ off`;
   `ai_intent_*` events carry `effective_mode`, and Match UI renders exactly what is emitted. The
   default is `full`; `off` is the player's choice, never a boss's (Pillar 3). The setting is read
   from `settings_changed` at construction and whenever it fires; absent at MVP → `full`.
5. The intent is **never fabricated**: it is a projection of a plan the planner would execute on
   the forecast state. A4 asserts that on an unchanged board the committed action equals the
   forecast.

#### C9. Budgets, determinism and logging

- All budgets are **counts** (nodes, evaluations, actions), never milliseconds. A wall-clock
  budget would make play differ between machines and break DD-R09/Pillar 4. The 50 ms per turn
  target is an acceptance measurement (A22) and a knob that tunes the counts, not a runtime switch.
- Tie-breaks: candidates within `rules.tie_epsilon` of the best score form the tie set, sorted by
  canonical command order (command type, then `hand_index`, `attacker_id`, `target_id`,
  `position`); one `ai_stream.randi_range` picks among them (F8). A tie set of size 1 consumes
  nothing. These, plus exactly one parent draw per new fork label (rng-event-log rule 5:
  `fork("sim_<turn>")` / `fork("forecast_<turn>")` each consume one `ai_<floor>` draw the first
  time the label is created), are the **only** live `ai_<floor>` draws; the sandboxes themselves
  draw from their forks.
- Every decision emits `ai_decision {kind: action|choice, chosen, mode, alternatives[≤3] of
  {command, score, features{}}}` flagged `diagnostic: true` on the same log as every other
  event (rng-event-log rule 12a, which names `ai_decision`, `ai_plan_aborted` and `ai_fault`
  beside `command_rejected`).
  Mode transitions (NORMAL → LETHAL/DEFENSIVE and back) are included in the payload so the
  `.claude/rules/ai-code.md` "log every transition" rule holds from the log alone.
- **`.claude/rules/ai-code.md`, rule by rule** (stated so a skipped rule is visible rather than
  silent): 2 ms/frame → C1.5 and A30; parameters tunable from data → F9 and A29; debuggable with
  visualisation hooks → the debug overlay (Visual/Audio, UI Requirements) fed by
  `ai_decision.features`; telegraph intentions → C8; utility over hard-coded if/else chains →
  C4–C5 (the only branches are lethal-first and the mode switch); state-machine transitions
  logged → this rule; group AI (formation, flanking, role assignment) → **not applicable**, one
  opponent with no spatial movement; network input validation → **not applicable**,
  single-player with no network.

#### C10. Profiles, bands and validation

`assets/data/ai_profiles.json` (schema in Formulas F9): `op_values`, `profiles` (`default`,
`aggro`, `control`, `tempo`, `passive_driven`, each with `weights`, `rules`, `budgets`,
`intent_mode`, `choice_preference`, `synergy_tags`), `bands` (`"1"`, `"2"`, `"3"` overlays) and
`boss_overrides` (keyed by boss id, `extends` a profile). A BossDef's `ai_profile` names a key in
`profiles` or `boss_overrides`; the resolved profile is `default ⊕ archetype ⊕ bands[band] ⊕
boss_override` (later wins, shallow per section). Boss AI supplies the `ai_profile` validator
that Card Database injects at CR-5 stage 7: unknown key → `E_AI_PROFILE_UNKNOWN`; a weight
outside its Tuning Knobs range or non-finite → `E_AI_WEIGHT_RANGE`; unknown field →
`E_AI_UNKNOWN_FIELD`; a missing file is Card Database CR-1's `E_MISSING_FILE` (the load fails;
no runtime default — Edge Cases). Any `E_AI_*` error falls back to `default` at runtime so a
match still runs in release; CI treats every `E_AI_*` as a failure.

#### C11. Boss mulligan and simulation harness

The boss does not mulligan in v1 (closes Match Rules' open question: its 4th card, DD-M03, is
its compensation; a mulligan heuristic is deferred to Open Questions). The **simulation harness**
(`tests/integration/boss_ai/sim_harness.gd`, headless) runs N seeded matches of a boss against a
*hero-script* — a second `BossAI` instance piloting a given hero deck with the `default` profile
— or boss vs boss, and writes `production/qa/sim/<boss_id>_<date>.json` with win rate, mean
turns, mean final health, decision count, planner time p50/p95, and the count of rejected AI
commands (must be 0). It is how Content tunes bands and how `/balance-check` reads boss strength.
The single difficulty basis is Content's `target_win_rate_by_floor` (cross-review D-07): the
harness reports boss win rate per floor and Content AC-13 passes when `1 − boss_win_rate(f)` is
within ±0.10 of the floor's target; band-level boss win rates are derived from that, not a
second knob (Open Questions).

### States and Transitions

The AI has a **turn state** (where it is in its loop) and an orthogonal **mode** (which weight
set it scores with). Both are observable in `ai_decision` payloads; neither is stored in
`MatchState`.

| State | Entry condition | Exit condition | Behaviour |
|---|---|---|---|
| `Idle` | Construction; any turn finished | Driver calls `forecast` or `play_turn` | Holds the resolved profile and the last forecast only |
| `Forecasting` | `PlayerTurn.Main` begins | `ai_intent_shown` emitted | Dry-run plan on a clone with next-turn mana; no live stream draws |
| `Planning` | `BossTurn.Main` begins, or a plan was aborted | Lethal found → `Executing`; else candidates scored → `Executing` | Lethal search, threat estimate, mode selection, scoring |
| `Executing` | A command chosen | `submit` returns; phase checked | Emits `ai_decision`, submits; rejection → excluded candidate, back to `Planning` |
| `Choosing` | Engine phase is `Choice` with `pending_choice.side == BOSS` | `choose` accepted | C7 option scoring; may re-enter immediately if a second Choice is raised |
| `Ending` | `end_turn` chosen, action cap hit, or 3 rejections | Engine leaves `BossTurn.Main` | Submits `end_turn`; emits final `ai_decision` with `mode` |
| `Faulted` | `end_turn` itself rejected, or the engine is `Ended` mid-loop | Match over | Logs `ai_fault`; returns control; never loops |

| From | Trigger | Guard | To |
|---|---|---|---|
| `Idle` | `forecast(engine)` | `phase == PlayerTurn.Main` | `Forecasting` → `Idle` |
| `Idle` | `play_turn(engine)` | `phase == BossTurn.Main` | `Planning` |
| `Planning` | lethal plan found | nodes ≤ `lethal_max_nodes` | `Executing` (mode `LETHAL`) |
| `Planning` | threat ≥ `boss_health − defensive_margin` | `band_rules.defensive` | `Executing` (mode `DEFENSIVE`) |
| `Planning` | best candidate scored | — | `Executing` (mode `NORMAL`) |
| `Executing` | `submit` accepted, phase still `BossTurn.Main` | `actions < max_actions_per_turn` | `Planning` |
| `Executing` | `submit` accepted, phase `Choice`, side `BOSS` | — | `Choosing` |
| `Executing` | `submit` rejected | `rejections < 3` | `Planning` (candidate excluded) |
| `Executing` | `submit` rejected | `rejections == 3` | `Ending` |
| `Executing` | plan step diverged | second search not yet used | `Planning` (`ai_plan_aborted`) |
| `Choosing` | `choose` accepted | phase returns to `BossTurn.Main` | `Planning` |
| `Choosing` | `choose` accepted | phase is `Ended` | `Idle` |
| `Choosing` | `choose` accepted | phase is `PlayerTurn.*` (the Choice was raised by a boss trigger during the player's turn; the driver called `choose` directly) | `Idle` |
| `Planning` | `cmds == [end_turn]` or `end_turn` scores best | — | `Ending` |
| `Ending` | engine phase ≠ `BossTurn.Main` | — | `Idle` |
| any | engine phase `Ended` | — | `Idle` |
| `Ending` | `end_turn` rejected | — | `Faulted` |

Modes: `NORMAL` (profile weights as resolved), `LETHAL` (no scoring; executes the found plan),
`DEFENSIVE` (profile weights multiplied by `rules.defensive_multipliers`, default `w_face ×0.25,
w_self ×2, w_heal ×2, w_threat ×1.5`; Taunt minions gain `+0.5` board value in F2). Mode is
re-evaluated at every `Planning` entry, so a successful clear drops the AI back to `NORMAL`
within the same turn.

### Interactions with Other Systems

| System | Direction | Data in | Data out | Owner of the interface |
|---|---|---|---|---|
| **Match Rules** | upstream | `legal_commands()`, `MatchState.clone()`, `submit() → CommandResult`, typed rejection codes, `ChoiceRequest`, phase | Commands (`play_card`, `attack`, `use_hero_power`, `choose`, `end_turn`); never `concede` or `mulligan` | Match Rules (C2); the AI is "just another command issuer". **Provisional requirement**: `clone()` must carry the installed `HookRegistry` (boss passive, treasures) so the sandbox resolves effects as the live match would |
| **Card Effects** | upstream | Effect specs read through Card Database for pre-filtering: op names (Card Effects C5, the `op_values` keys), `targets.selector` and filters (C3), trigger names (C2), `ChoiceRequest.kind`. Boss AI derives `position_sensitive`, `aoe` and synergy matches from them (C6) — Card Effects adds no AI-only fields | None | Card Effects owns the op vocabulary; this GDD owns the value table keyed on it. An op type with no `op_values` row defaults to 1.0 and logs `E_AI_OP_UNVALUED` at load |
| **Card Database** | upstream | `boss(id)` → `band`, `health`, `hero_power`, `passive`, `deck[]`, `ai_profile`; `card(id)` for cost/stats/effect spec | The `ai_profile` validator (CR-5 stage 7) and the config validator for `ai_profiles.json`; the file is loaded by Card Database and read once via `config("ai_profiles")` (CR-1; DD-T01 lists it) | Card Database owns the record shape and load pipeline; Boss AI owns profile keys and the schema in F9 |
| **RNG & Event Log** | upstream | Injected `ai_<floor>` stream; `fork(label)` | `ai_intent_shown`, `ai_intent_committed`, `ai_decision` (diagnostic), `ai_plan_aborted`, `ai_fault` via `log.append`; all five are catalogued (rng §D), the three diagnostic types under rule 12a | RNG & Event Log owns the envelope; Boss AI owns these payloads and documents its draw order (C9) |
| **Meta Progression** | upstream (setting) | `settings.telegraph_mode` (`full` / `brief` / `off`) via `settings_changed` (DD-X03, DD-X07) | None | Meta Progression stores the setting; Boss AI owns `effective_mode = min(intent_mode, telegraph_mode)` (C8.4); absent at MVP → `full` |
| **Run Structure** | upstream | `MatchConfig.boss.ai_id` (= BossDef `ai_profile`), `floor`, `band` | None (match result flows from Match Rules) | Run Structure constructs the driver that calls `forecast`/`play_turn`/`choose` |
| **Match UI** | downstream | — | The event stream: intent banner from `ai_intent_*`, action playback pacing from the command events, debug overlay from `ai_decision` | UI is display-only (`src/ui/**`); pacing values in UI Requirements are read from `ai_profiles.json.presentation` |
| **Content** | downstream | — | Profile archetypes and `boss_overrides` schema; harness output for band tuning | Content authors each boss's `ai_profile` and override; Boss AI owns what the keys mean |
| **Heroes / Treasures** | indirect | Hero decks for the harness's hero-script; treasure hooks present in the cloned state | None | No direct interface; a treasure that changes rules changes the sandbox's outcomes automatically |

## Formulas

`systems-designer` not consulted — Lean mode, single-agent run. Every weight below is a `data
file` value from `assets/data/ai_profiles.json`; the numbers shown are the `default` profile.

### F1. Action score

The `action_score` formula is defined as:

`action_score(a) = Σ_i w_i · f_i(a)` over the eleven features of C5, each computed from the
one-ply sandbox delta (`before` → `after`):

```
f_board  = clamp((ΔBV_boss − ΔBV_player) / BV_NORM, −1, 1)            BV from F2, BV_NORM = 10
f_face   = dmg_to_player_hero / player_health_before                   (0 when no damage)
f_self   = −dmg_to_boss_hero / boss_health_before
f_trade  = trade_quality(a) ∈ {−1, 0, +1}                              F3; 0 for non-attacks
f_threat = Σ_{m removed} threat(m) / THREAT_NORM                       threat from F2, THREAT_NORM = 12
f_mana   = cost_paid(a) / mana_max         ;  for end_turn: −mana_left / mana_max
f_card   = clamp((Δcount_boss − Δcount_player) / 3, −1, 1)              count = hand + board
f_over   = −max(0, boss_board_after − overextend_cap) / BOARD_SIZE      cap from F5
f_heal   = heal_to_boss_hero / max(1, missing_health_before)            capped at 1
f_hp     = 1 if a is use_hero_power and hero_power_rule allows, −1 if it forbids, else 0
f_passive= 1 if synergy_match(card(a), profile.synergy_tags) else 0                  C6
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| w_board | float | 0–5 | data file | default 2.0; aggro 1.5, control 2.5, tempo 2.5 |
| w_face | float | 0–5 | data file | default 1.5; aggro 3.0, control 0.5, tempo 1.5 |
| w_self | float | 0–5 | data file | default 1.0; control 2.0 |
| w_trade | float | 0–3 | data file | default 1.0; band 1 overlay 0.2 (teaching mistake) |
| w_threat | float | 0–5 | data file | default 2.0; control 3.0 |
| w_mana | float | 0–3 | data file | default 1.0; tempo 1.5 |
| w_card | float | 0–3 | data file | default 0.8; control 1.5 |
| w_over | float | 0–3 | data file | default 1.0; band 1 overlay 0 |
| w_heal | float | 0–3 | data file | default 0.6; control 1.5 |
| w_hp | float | 0–2 | data file | default 0.5 |
| w_passive | float | 0–5 | data file | default 0; passive_driven 2.5 |
| BV_NORM, THREAT_NORM | float | 5–20 | data file (`rules`) | Normalisers so features stay in [−1, 1] for a typical 2–3 minion swing |

**Output Range:** roughly −8 to +12 with default weights; `end_turn` on a full-mana turn scores
≈ −w_mana. **Example** (aggro profile: `w_board 1.5, w_face 3.0, w_trade 1.0, w_threat 2.0,
w_mana 1.0, w_card 0.8`; 6 mana; player hero at 20 with a 2/3 Taunt; the boss has a 3/3 on board
that can attack and a 4-cost vanilla 4/4 in hand). Candidate "play the 4/4": `f_board = (8 −
0)/10 = 0.8`, `f_mana = 4/6 = 0.667`, `f_card = ((−1 hand + 1 board) − 0)/3 = 0`, all else 0 →
`1.5·0.8 + 1.0·0.667 = 1.87`. Candidate "attack the Taunt with the 3/3" (the Taunt dies, the 3/3
survives as a 3/1): `ΔBV_boss = (3+1) − (3+3) = −2`, `ΔBV_player = 0 − (2+3)·1.2 = −6` →
`f_board = (−2 − (−6))/10 = 0.4`; `f_trade = +1`; `f_threat = (2 + 1.5)/12 = 0.292`; `f_card =
(0 − (−1))/3 = 0.333`; `f_mana = 0` → `1.5·0.4 + 1.0·1 + 2.0·0.292 + 0.8·0.333 = 2.45`.
`end_turn` scores `−6/6 · 1.0 = −1.0`. The trade is chosen first (2.45), then the 4/4 (1.87 — its
features are unchanged by the trade), then `end_turn` (now `−2/6 = −0.33`, the best remaining
move).

### F2. Board value and threat

```
BV(m)     = (attack(m) + health(m)) · Π keyword_mult(k) + Σ flat_bonus(k)
threat(m) = attack(m) · (1 + 0.5·windfury) + taunt_bonus + (deathrattle ? 1 : 0)
BV(weapon)= attack · durability · 0.8
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| keyword_mult | float | 1.0–1.5 | data file (`keyword_values`) | taunt 1.2, divine_shield 1.3, windfury 1.3, lifesteal 1.15, poisonous 1.25, stealth 1.1 |
| flat_bonus | float | 0–3 | data file | spell_damage +2 per point, deathrattle +1, aura +2 |
| taunt_bonus | float | 0–3 | data file | 1.5 (Taunt blocks the boss's own face plan) |
| attack, health | int | 0–99 | calculated | Match Rules C1 derived values |

**Output Range:** BV 0–~60 per minion; a 7-minion board ≤ ~200. **Example:** a 3/2 Divine Shield
Taunt: `(3+2)·1.3·1.2 = 7.8`; threat `3 + 1.5 = 4.5`.

### F3. Trade quality

```
trade_quality(attack(A, D)), both minions:
  kills_D ∧ ¬A_dies                       → +1
  kills_D ∧ A_dies ∧ BV(D) ≥ BV(A)·trade_ratio → +1
  kills_D ∧ A_dies ∧ |BV(D) − BV(A)| ≤ 0.2·BV(A) → 0
  otherwise (A dies for nothing, or neither dies) → −1
attack on a hero, or by a hero → 0 (scored by f_face / f_self instead)
```

**Variables:** `trade_ratio` float 0.5–2.0, data file — default 1.0; aggro 1.3 (needs a better
body to trade), control 0.8 (trades down happily). **Output Range:** {−1, 0, +1}. **Example:** a
4/4 into a 5/2 (both die): `BV(D) = 7 ≥ 8·1.0`? No → is `|7−8| ≤ 1.6`? Yes → 0 (even).

### F4. Lethal upper bound (prune test)

```
potential = Σ_{a ∈ boss attackers, can_attack} attack(a)·attacks_remaining(a)
          + Σ_{c ∈ hand damage cards, Σcost ≤ mana} face_damage(c)      (greedy by damage/cost)
taunt_hp  = Σ_{t ∈ taunters(player)} health(t)
prune iff potential − taunt_hp < player_health + player_armor
```

**Variables:** all `calculated` from Match Rules state; `face_damage(c)` is the op's `amount` plus
the boss's Spell Damage total (Match Rules F7). **Output Range:** 0–~80. **Example:** attackers
5+4, hand has a 3-damage spell, 4 mana → `potential = 12`; player Taunt 2/5 → `taunt_hp = 5`;
player at 8 → `12 − 5 = 7 < 8` → pruned, no search; the planner trades instead.

### F5. Over-extension cap

`overextend_cap = aoe_seen ? overextend_cap_aoe : BOARD_SIZE`, where `aoe_seen` is true once the
player has played any card (`card_played`) whose effect spec is `aoe` by the C6 derivation this
match, **or** the profile
sets `assume_aoe` (band 3 overlay against the Knowledge hero). **Variables:** `overextend_cap_aoe`
int 2–7, data file, default 4; `BOARD_SIZE` 7 (registry). **Example:** after the player Flamestrikes,
the 5th boss minion scores `f_over = −1/7`; with `w_over = 1` that is a −0.14 nudge, enough to
prefer a trade of equal value, not enough to stop a lethal setup.

### F6. Threat estimate (defensive trigger)

`incoming = Σ_{m ∈ player.board} attack(m)·max_attacks(m) + hero_weapon_attack +
burn_per_mana · mana_max_player_next_turn`; defensive mode when `incoming ≥ boss_health +
boss_armor − defensive_margin`. **Variables:** `burn_per_mana` float 0–2, data file, default 1.0
(an unknown hand is assumed to hold one damage per mana); `defensive_margin` int 0–10, default 3.
Frozen minions that will thaw count; summoning-sick ones count (they wake up). **Example:** player
board 4/4 + 3/2 Windfury, 6 mana next turn → `4 + 6 + 6 = 16`; boss at 18 → `16 ≥ 15` → DEFENSIVE.

### F7. Budgets and expected planner time

| Budget | Band 1 | Band 2 | Band 3 | Unit |
|---|---|---|---|---|
| `lethal_max_nodes` | 50 | 500 | 4000 | sandbox nodes per search |
| `max_evals_per_action` | 40 | 120 | 250 | simulated candidates |
| `max_actions_per_turn` | 30 | 30 | 30 | submitted commands |
| `prefilter` | op_value | op_value | op_value | ranking when candidates exceed the eval cap |

`planner_time ≈ (actions · evals + lethal_nodes) · t_sim`, with `t_sim` = clone + one `submit`
(Match Rules budgets `submit` at ≤ 5 ms worst case, typically ≪ 0.1 ms for a 2-step action). At
band 3 worst case `(8·250 + 4000)·0.01 ms ≈ 60 ms`; the 50 ms target (`planner_target_ms`, Tuning
Knobs) is met by lowering `lethal_max_nodes` if A22 fails — the knob changes counts, never the
clock. `TURN_CAP` (100 global turns, Match Rules C14 — 50 boss turns) and `max_actions_per_turn`
together bound a match at 1,500 AI commands. `forecast` (C8) runs the same planner once per
player turn under the same count budgets; A22 measures it together with `play_turn` (one forecast
plus one real turn per round ≈ 2× the worst case above, which is why band 3's `lethal_max_nodes`
is the first knob to lower).

### F8. Tie-break

`ties = sort_canonical({a : score(best) − score(a) ≤ tie_epsilon})`;
`pick = ties[ai_stream.randi_range(0, |ties| − 1)]` when `|ties| > 1`, else `ties[0]` with no
draw. `tie_epsilon` float 0–0.5, data file, default 0.05. Draw count per turn is therefore
deterministic given the state — tie-set draws plus one parent draw per new fork label (C9,
rng-event-log rule 5) — which is what `restore()` (RNG & Event Log F5) relies on.

### F9. `ai_profiles.json` schema (summary)

```
schema_version: 1
op_values:      {<op name>: float 0–5}      damage 1.0, destroy 2.0, heal 0.6, buff 0.8, set_stats 1.0,
                                            give_keyword 0.8, summon 1.0, draw 1.2, silence 1.2, freeze 0.7,
                                            discover 1.0, add_to_hand 1.0, copy_to_hand 1.0, armor 0.5,
                                            return_to_hand 1.0, transform 1.2, mana 1.5, equip 1.2,
                                            retrigger 1.5      (Card Effects C5 names; × targets yielded, C6)
keyword_values: {<keyword>: float 1.0–1.5}  F2 multipliers
profiles:       {<key>: Profile}            default, aggro, control, tempo, passive_driven
bands:          {"1"|"2"|"3": Profile overlay}
boss_overrides: {<boss id>: Profile overlay with required "extends"}
presentation:   {action_delay_s 0.6, max_turn_playback_s 10, intent_banner_s 0.3, plan_changed_s 1.2}
runtime:        {planner_mode worker|time_sliced|immediate (default worker), slice_ms 2, replay_budget_ms 2}
                (owned here, consumed by the match driver's PlannerTask seam — ADR-0006; added 2026-11-03)

Profile = { extends?: key,
            weights:  {w_board, w_face, w_self, w_trade, w_threat, w_mana, w_card, w_over, w_heal, w_hp, w_passive},
            rules:    {hero_power: always|spare_mana|never|value, trade_ratio, tie_epsilon, overextend_cap_aoe,
                       assume_aoe, defensive, defensive_margin, burn_per_mana, defensive_multipliers{w_*: float},
                       lethal_search: shallow|full|off, BV_NORM, THREAT_NORM},
            budgets:  {lethal_max_nodes, max_evals_per_action, max_actions_per_turn},
            intent_mode: full|class_only|hidden,   (hidden: boss_overrides only, concealment passive — C8.4, D-04)
            choice_preference: {<tag>: float 0–1},
            synergy_tags: [string] }
```

Archetype deltas from `default` (F1's table holds the default weights; default `rules` are
`hero_power spare_mana`, `lethal_search full`, `defensive false`, `assume_aoe false`): **aggro** `w_face 3.0, w_board
1.5, trade_ratio 1.3, hero_power always, choice_preference {charge 0.5, weapon 0.4}`; **control**
`w_face 0.5, w_threat 3.0, w_self 2.0, w_card 1.5, w_heal 1.5, w_board 2.5, trade_ratio 0.8,
choice_preference {taunt 0.5, heal 0.4, damage_all 0.6}`; **tempo** `w_mana 1.5, w_board 2.5,
choice_preference {low_cost 0.5}`; **passive_driven** `w_passive 2.5` with `synergy_tags` set per
boss override (e.g. `boss_rot_warden: {extends: passive_driven, synergy_tags: [deathrattle],
weights: {w_self: 1.5}}`). Band overlays: **1** `w_trade 0.2, w_over 0, lethal_search shallow,
defensive false, hero_power always, intent_mode full`; **2** `defensive false`; **3** `defensive
true` — budgets per F7. `hero_power` values: `always` (whenever legal), `spare_mana` (only when
no card is playable with the remaining mana, via `f_hp`), `never`, `value` (ordinary candidate,
`f_hp = 0`). `lethal_search`: `shallow` (depth 1: direct attacks and one burn), `full` (C3 within
budget), `off`.

## Edge Cases

**Legality and the command loop**

- **If `legal_commands()` returns only `end_turn`**: the AI submits `end_turn` without scoring,
  emits one `ai_decision {chosen: end_turn, alternatives: []}`, intent for that turn is `pass`.
- **If `legal_commands()` returns an empty list**: a rules fault (Match Rules guarantees
  `end_turn` in `Main`); the AI emits `ai_fault {reason: no_legal_commands}`, submits `end_turn`
  once, and if that is rejected enters `Faulted` and returns. It never spins.
- **If a submitted command is rejected** (stale list, cannot happen single-threaded but is
  guarded): log `ai_decision.rejection = code`, exclude that exact command for the rest of the
  turn, re-query and re-plan; after 3 rejections in one turn submit `end_turn`. A23 asserts zero
  rejections across 1,000 seeded matches, so any rejection in CI is a bug, not a recovery.
- **If a Discover (Choice phase) is raised during the boss's turn**: the loop detects
  `phase == Choice ∧ pending_choice.side == BOSS` after `submit` and answers with `choose` (C7)
  before planning its next action; the player's commands are meanwhile `CHOICE_PENDING` (Match
  Rules). A Choice raised during the **player's** turn for the boss (a boss Deathrattle that
  Discovers) is answered by the same `choose` entry point, called by the driver.
- **If all Discover options are identical**: collapsed to index 0, no RNG draw, logged as a
  choice with one alternative.
- **If an effect requires a target but none is legal**: Match Rules already excludes it from
  `legal_commands()` (spells → `NO_LEGAL_TARGET` not offered; Battlecry minion offered with no
  target). The AI scores the minion as a body (`f_board` only), never synthesises a target.
- **If the boss hero or all its minions are Frozen**: attack commands are absent from the list;
  the AI develops the board or passes; the intent becomes `develop_board` or `pass`, never a
  fabricated `attack_face`. Forecast respects thaw: a character that will thaw at the player's
  End step is counted for the boss's forecast only if the thaw rule (Match Rules C13) says so on
  the cloned state.
- **If the boss board is full (7)**: minion plays are absent (`BOARD_FULL` is never offered); the
  AI values removal of its own low-value minions only through trades (no self-destroy heuristic).
  If the **player's** board is full, `f_threat` already rewards removal; `w_threat` is raised by
  `×1.25` while `player.board.size == BOARD_SIZE` (closes Match Rules' board-fill denial note).
- **If an action would exceed `max_actions_per_turn` (30)**: `end_turn` is forced and logged with
  `reason: action_cap`. Reachable only with degenerate zero-cost loops; a content bug surfaced,
  not hidden.

**Lethal and defence**

- **If lethal exists only through a Taunt**: the search includes trades that kill the Taunt
  first; the prune test subtracts `taunt_hp`, so a Taunt wall the boss cannot clear prunes the
  search quickly and the turn is played normally.
- **If lethal requires a weapon equip then a hero attack**: `play_card(weapon)` is in the damage
  subset and the hero attack follows; the search depth bound covers both steps.
- **If a Charge minion is lethal only at an exact position** (adjacency buff): positions are
  enumerated only when the card is `position_sensitive` (derived from its own `adjacent` /
  `*_neighbour` selectors, C6); otherwise rightmost. A card whose adjacency effect lives on
  *another* minion already in play (an "adjacent minions have +2 Attack" lord) is not flagged, so
  a lethal that needs the new minion placed beside that lord is missed — accepted for v1 and
  listed in Open Questions (A17).
- **If lethal search exhausts its node budget**: returns null, `ai_decision.mode` records
  `lethal_search_exhausted`, normal scoring continues (band 1 will thereby "miss" lethals a band 3
  boss finds — intended).
- **If the player has lethal next turn** (F6) and no defensive play changes the estimate: the AI
  still plays the best-scoring DEFENSIVE action (often racing, since `f_face` is reduced not
  zeroed); it does not resign or stall.
- **If both lethal and defensive conditions hold**: lethal wins (checked first, C2).
- **If the planner's forecast and the real turn disagree** (player changed the board): the
  committed intent carries `kept = false`; the forecast is never retro-edited (log is append-only).

**Data and determinism**

- **If `ai_profile` is missing or names an unknown key**: Card Database reports
  `E_AI_PROFILE_UNKNOWN` at load; at runtime the boss plays the `default` profile with its band
  overlay; the intent banner still works. Debug/CI builds fail the load.
- **If a profile weight is outside its range or non-finite**: `E_AI_WEIGHT_RANGE`; that single
  weight is clamped to its safe range at runtime (never silently zeroed) and the error is logged.
- **If `ai_profiles.json` is absent**: Card Database CR-1 fails the whole load with
  `E_MISSING_FILE` naming the file — there is no runtime default and the match never starts
  (card-database Edge Cases: "no built-in defaults path"). Headless tests that need an AI without
  the data file **inject a stub profile** (a `default`-shaped dictionary passed to the planner's
  constructor, C1), the same way they inject a seed; the stub never ships in the loader. Release
  builds ship the file, so a missing file is a CI condition.
- **If an op type appears in a card that has no `op_values` row**: valued 1.0, `E_AI_OP_UNVALUED`
  logged once per op type per load.
- **If the sandbox simulation itself raises `resolution_overflow`**: that candidate scores
  `−∞` (never chosen) and `ai_decision` records `sim_overflow`; the live engine is untouched.
- **If two seeded runs diverge in AI play**: by construction only if state or stream position
  differ; the harness diffs the first differing `ai_decision` payload to localise the cause (A3).
- **If the boss deck is empty**: no change — fatigue is Match Rules'; `f_card` naturally stops
  valuing draw ops because the sandbox draw produces fatigue damage, raising `f_self`.
- **If the boss passive changes the rules mid-match** (hook installed by Content): the sandbox
  inherits it through the cloned `HookRegistry` (Interactions, provisional); if `clone()` cannot
  carry hooks, scoring is wrong for that boss — A20 covers it.

## Dependencies

Hard = the AI cannot take a turn without it; soft = degraded but playable. Bidirectionality:
Match Rules lists Boss AI as a downstream dependent (its Dependencies table), RNG & Event Log
lists it with the `ai_<floor>` stream and `ai_intent_shown`, Card Database lists the
`ai_profile` validator hand-off, and the systems index lists Match UI and Content as depending
on Boss AI. Card Effects' GDD lists Boss AI as a downstream dependent (`legal_targets()`,
`ChoiceRequest.options`, deterministic `resolve` on a clone) — mirrored; its row below was
re-checked against `design/gdd/card-effects.md` on 2026-11-03.

| System | Direction | Hard/Soft | Nature of dependency / interface |
|---|---|---|---|
| Match Rules | This depends on Match Rules | Hard | `legal_commands()`, `MatchState.clone()` (must carry hooks — provisional), `submit()`, rejection codes, `ChoiceRequest`, phase/`pending_choice`; `can_attack` (F3), `mana_max_by_turn` (F4), `TURN_CAP` for the harness. Match Rules' open question on boss mulligan is closed here: none in v1 |
| Card Effects | This depends on Card Effects | Hard | Op names (C5) for `op_values`; selectors and filters (C3) and trigger names (C2) for the C6 derivations; `ChoiceRequest.kind` (`discover` / `choose_one`); the sandbox relies on effects resolving identically on a clone (Card Effects guarantees it) |
| Card Database | This depends on Card Database | Hard | `boss(id)` fields `band`, `health`, `hero_power`, `passive`, `deck`, `ai_profile`; `card(id)` for cost/stats/effect spec. Boss AI supplies the `ai_profile` validator (CR-5 stage 7) and the `ai_profiles.json` config validator; reads `config("ai_profiles")` |
| RNG & Event Log | This depends on RNG & Event Log | Hard | Injected `ai_<floor>` stream and `fork()` (one parent draw per new fork label, rule 5); `log.append` for `ai_intent_shown`, `ai_intent_committed`, `ai_decision`, `ai_plan_aborted`, `ai_fault` (all catalogued, rng §D; diagnostics per rule 12a) |
| Meta Progression | This depends on Meta Progression | Soft | `settings.telegraph_mode` via `settings_changed` (DD-X03); clamps the per-boss `intent_mode` to it (C8.4 `effective_mode`); absent at MVP → `full` |
| Run Structure | Run Structure depends on this | Hard (for them) | Constructs `BossAI` from `MatchConfig.boss.ai_id`, `floor`, `band`; drives `forecast` / `play_turn` / `choose` at the phase transitions in States |
| Match UI | Match UI depends on this | Soft | Intent banner from `ai_intent_*`, playback pacing from `presentation`, debug overlay from `ai_decision`; the engine runs headless without it |
| Content | Content depends on this | Soft | Authors `ai_profile` keys and `boss_overrides`; uses the harness output to tune bands; `synergy_tags` per passive-driven boss |
| Heroes | Indirect | Soft | Hero decks pilot the harness's hero-script; no runtime interface |
| Treasures | Indirect | Soft | Hooks ride along in the cloned state; no runtime interface |

## Tuning Knobs

Not required at `standard`; authored because every knob is a data value Content will touch. All
live in `assets/data/ai_profiles.json`, resolved per boss (C10). Weight ranges are the validator's
`E_AI_WEIGHT_RANGE` bounds.

The eleven weights `w_*` are listed with current values and safe ranges in F1's variable table;
the pairs that interact most are `w_face`/`w_trade` (raise both and the boss races *and*
trades, which reads as random), `w_board`/`w_over` (the cap is inert when `w_over = 0`) and
`w_self`/`w_heal` (a heal weight above `w_self` makes the boss heal at full health — `f_heal`'s
missing-health gate prevents the worst of it). Non-weight knobs:

| Parameter | Current value | Safe range | Effect of increase | Effect of decrease | Interacts with |
|---|---|---|---|---|---|
| `rules.hero_power` | `spare_mana` | enum | `always`: hero power every turn | `never`: hero identity lost | `w_hp`, Heroes' power strength |
| `synergy_tags` | per boss | — | More tags: boss tunnels on its passive even when losing | Empty: passive never fed; Pillar 2 weakens | `w_passive`, Content |
| `trade_ratio` | 1.0 | 0.5–2.0 | Only trades up | Trades down freely | `w_trade` |
| `overextend_cap_aoe` | 4 | 2–7 | Cap irrelevant at 7 | At 2 the boss never commits | `w_over`, `BOARD_SIZE` |
| `defensive_margin` / `burn_per_mana` | 3 / 1.0 | 0–10 / 0–2 | Defensive mode earlier and more often | Boss ignores lethal threats | F6, `defensive_multipliers` |
| `tie_epsilon` | 0.05 | 0–0.5 | More RNG in play; less predictable | Fully deterministic ordering by canonical sort | `ai_<floor>` draw count |
| `lethal_max_nodes` | 50 / 500 / 4000 | 10–20,000 | Finds deeper lethals; planner time up | Misses multi-step lethals | `planner_target_ms` |
| `max_evals_per_action` | 40 / 120 / 250 | 10–1,000 | Better target choice on wide boards; time up | Pre-filter decides more; weaker play | `op_values`, `planner_target_ms` |
| `max_actions_per_turn` | 30 | 10–100 | Longer degenerate turns possible | Legit token turns cut short | Match Rules `TURN_CAP` |
| `planner_target_ms` | 50 | 20–200 | Allows larger budgets | Forces smaller budgets | F7 (measurement only; never a runtime switch) |
| `presentation.action_delay_s` | 0.6 | 0.3–1.2 | Boss turns read slower; risk "long opponent turns" | Actions blur together | `max_turn_playback_s` |
| `presentation.max_turn_playback_s` | 10 | 6–20 | Long turns play in full | Delay compresses on busy turns | `action_delay_s` |
| `presentation.intent_banner_s` / `plan_changed_s` | 0.3 / 1.2 | 0.2–0.6 / 0.6–2.0 | Longer commit beat / longer "plan changed" label; the first boss action starts later | Beat unreadable / label missed | Match UI `boss_turn_gap` (reads `intent_banner_s`) |
| `telegraph_mode` (player setting, Meta Progression M9 — not in `ai_profiles.json`) | `full` | `full` \| `brief` \| `off` | — | `brief` hides amount/target; `off` hides the banner (player opt-in, DD-X03) | `effective_mode` (C8.4), Match UI banner |

Knobs owned elsewhere that move this system's outcomes (not duplicated): `BOARD_SIZE`,
`MAX_MANA`, `TURN_CAP` (Match Rules); boss health by band (DD-M02, read from the boss def);
Content's deck quality and passive strength; the AoE density of the player's card pool.

## Visual/Audio Requirements

`art-director` not consulted — Lean mode (the AI's own visual surface is the intent banner and
the pacing of events Match Rules already specifies). Card, attack and effect feedback belong to
Match Rules' table; rows here are the AI-specific additions, placeholder art in v1.

| Event | Visual Feedback | Audio Feedback | Priority |
|---|---|---|---|
| `ai_intent_shown` (player turn start) | Intent banner over the boss portrait: icon per `intent_key`, `amount` as a number, `target_id` highlighted with a dim reticle; desaturated band colour (Torchlit Ledger: lit because the player must read it) | Soft "page turn" | Must |
| `ai_intent_committed`, `kept = true` | Banner brightens briefly, then the first action plays | None (the action's own sound) | Must |
| `ai_intent_committed`, `kept = false` | Banner crossfades to the new intent with a "plan changed" label for `plan_changed_s` | Short low tone | Must |
| Each boss action during playback | Match Rules' normal card/attack feedback, spaced by `action_delay_s` | Match Rules' sounds | Must |
| `ai_decision` (debug builds) | Debug overlay panel: chosen command, mode, top-3 alternatives with feature bars (`.claude/rules/ai-code.md`: visualisation hooks for AI state) | None | Should (dev only) |
| `ai_plan_aborted`, `ai_fault` | Debug overlay line only; nothing player-facing | None | Should (dev only) |

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run
`/asset-spec system:boss-ai` to produce per-asset visual descriptions, dimensions, and generation
prompts from this section (11 intent icons, banner frame, "plan changed" label).

## Game Feel

### Feel Reference
Slay the Spire's enemy intent icons — the boss's plan is public, so a loss is "I saw it and
could not stop it", never "where did that come from". Anti-reference: Hearthstone's AI opponents
pausing with a "thinking" emote; the boss here never thinks on screen.

### Input Responsiveness
| Action | Max latency (ms) | Frame budget (60 fps) | Notes |
|---|---|---|---|
| Player `end_turn` → boss planner complete | 50 | 3 frames | F7 target, measured off the main thread (C1.5); main-thread cost ≤ 2 ms in any frame (A30) |
| Planner complete → first boss action on screen | 300 | 18 frames | Banner commit beat, then playback |
| Each subsequent boss action | `action_delay_s` = 600 | 36 frames | Compressed to fit `max_turn_playback_s` on busy turns |
| Player click "skip" during playback | 100 | 6 frames | Playback jumps to the final state (events already logged) |

### Animation Feel Targets
Not applicable — the AI animates nothing; playback reuses Match Rules' targets.

### Impact Moments
| Impact Type | Duration (ms) | Effect Description | Configurable? |
|---|---|---|---|
| Intent commit beat | 300 | Banner brightens, short hold before the first action | Yes (`intent_banner_s`) |
| Lethal intent (`intent_key = lethal`) | 600 | Banner pulses red once; no other emphasis — the board already says it | Yes |

### Weight and Responsiveness Profile
- **Weight**: deliberate — each boss action lands as a discrete beat, never a flurry.
- **Player control**: during the boss turn, only skip; the plan was readable before it ran.
- **Snap quality**: binary — actions are either playing or done; no partial animations overlap.
- **Acceleration**: constant cadence; compression on long turns shortens every gap equally.
- **Failure texture**: fair by design — the forecast told the player what was coming; a `kept =
  false` turn tells them their play changed it.

### Feel Acceptance Criteria
- [ ] Playtesters can say what the boss "was going to do" after a loss without prompting.
- [ ] No playtester describes boss turns as "long" or "slow" at the default 0.6 s cadence.
- [ ] No playtester uses "random" or "cheating" about a boss decision in band 2–3 sessions.
- [ ] "Plan changed" is recognised as a consequence of the player's own turn by at least 4 of 5
  first-session testers.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|---|---|---|---|
| Boss intent (icon, text, amount, target reticle) | Banner above the boss portrait | At `ai_intent_shown`, re-rendered at `ai_intent_committed` | `effective_mode ≠ hidden` (C8.4: boss `intent_mode` clamped by the player's `telegraph_mode`); `class_only` omits amount/target |
| "Plan changed" label | Same banner | At `ai_intent_committed` with `kept = false` | Shown for `plan_changed_s`, then normal banner |
| Boss action playback | Board/hand (Match Rules UI) | One action per `action_delay_s`; total ≤ `max_turn_playback_s` | During boss turn; skip button always available |
| Boss hand count | Boss portrait (Match Rules UI) | Per event | Always — the AI sees only the player's count too, so the display is symmetric |
| AI debug overlay (chosen command, mode, top-3 alternatives, feature bars, planner time) | Collapsible dev panel | Per `ai_decision` | Debug builds or `--ai-debug` flag only |
| Harness summary (win rate, turns, p95 planner time, rejections) | Not in-game: `production/qa/sim/*.json` + console table | Per harness run | Developer tooling |

> **📌 UX Flag — Boss AI**: This system has UI requirements. In Phase 4 (Pre-Production), run
> `/ux-design` to create a UX spec for the intent banner and boss-turn playback (as part of the
> match HUD) **before** writing epics. Stories that reference UI should cite `design/ux/hud.md`,
> not the GDD directly. Note this in the systems index for this system if you update it.

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|---|---|---|---|
| Command loop consumes legal moves and submits | `design/gdd/match-rules.md` | C2 `legal_commands()`, `submit()`, `MatchState.clone()`, rejection codes | Data dependency |
| Lethal search attack legality | `design/gdd/match-rules.md` | F3 `can_attack` | Rule dependency |
| Forecast uses next-turn mana | `design/gdd/match-rules.md` | F4 `mana_max_by_turn`, `MAX_MANA` | Data dependency |
| Choice phase answered by the AI | `design/gdd/match-rules.md` | States: `Choice`, `pending_choice.side == BOSS`; C12 Discover row | State trigger |
| Thaw handling in forecast | `design/gdd/match-rules.md` | C13 thaw rule | Rule dependency |
| Board-fill denial valuation; `TURN_CAP` for the harness | `design/gdd/match-rules.md` | Edge Cases "Board-fill denial"; C14 `TURN_CAP` | Rule dependency |
| Boss mulligan question closed (none in v1) | `design/gdd/match-rules.md` | Open Questions row 1 | Ownership handoff |
| Boss record fields | `design/gdd/card-database.md` | BossDef `band`, `health`, `hero_power`, `passive`, `deck`, `ai_profile` | Data dependency |
| Profile validator supplied | `design/gdd/card-database.md` | CR-5 stage 7 delegated validators | Ownership handoff |
| Tie-break stream | `design/gdd/rng-event-log.md` | `ai_<floor>` stream, `fork(label)`, F2 `stream_seed` | Data dependency |
| Intent and decision events | `design/gdd/rng-event-log.md` | Event catalogue §D (`ai_intent_shown`, `ai_intent_committed`, `ai_decision`, `ai_plan_aborted`, `ai_fault`); envelope rules 11–14; diagnostic events rule 12a; fork cost rule 5 | Data dependency |
| Player telegraph setting | `design/gdd/meta-progression.md` | M9 `settings.telegraph_mode`, `settings_changed` | Data dependency |
| `effective_mode` rule and settings ownership | `design/design-decisions.md` | DD-X03, DD-X07 | Rule dependency |
| Op names, selectors, filters, trigger names, `ChoiceRequest.kind` | `design/gdd/card-effects.md` | C2 triggers, C3 selectors, C5 ops (the `choose_one` row names Boss AI) | Data dependency |
| Boss health, bands, starting hand | `design/design-decisions.md` | DD-M02, DD-M03, DD-R01, DD-R09 | Rule dependency |
| Telegraphed intent, puzzle bosses | `design/gdd/game-concept.md` | Pillars 2, 3, 4 | Rule dependency |

## Acceptance Criteria

`qa-lead` not consulted — Lean mode, single-agent run. Every criterion uses a fixed seed and the
headless engine (`tests/unit/boss_ai/`, `tests/integration/boss_ai/`); fixtures are board setups
under `tests/fixtures/boss_ai/`, never inline numbers except where the number is the point.

**Determinism and purity**
- [ ] **A1 GIVEN** the same `MatchConfig` and `run_seed = 42`, **WHEN** the boss plays 10 full
  turns against a scripted player sequence twice, **THEN** the two `ai_decision` sequences are
  byte-identical (canonical JSON).
- [ ] **A2 GIVEN** two matches identical except `run_seed`, **WHEN** a turn produces a tie set of
  size > 1, **THEN** the chosen commands may differ, and every other decision with a tie set of
  size 1 is identical.
- [ ] **A3 GIVEN** a logged match, **WHEN** replayed from its `stream_seed` and command list,
  **THEN** the AI's `ai_<floor>` draw count per turn equals the original and equals (tie-set
  draws + number of new fork labels created that turn) (F8, C9; rng-event-log rule 5).
- [ ] **A4 GIVEN** a fixture where the player's hand contains a decoy "if the AI reads this,
  play X" card — drawn through the engine so its `card_drawn.card_id` is in the log — and the
  board is otherwise unchanged between forecast and boss turn, **WHEN** the boss plays, **THEN**
  the committed intent equals the forecast (`kept = true`), X is not played, and no decision
  payload references any player hand `def_id`; **AND GIVEN** a second fixture identical except
  for the player's hand and deck contents, **THEN** the `ai_decision` sequence is byte-identical.
- [ ] **A5 GIVEN** any state, **WHEN** `play_turn` runs, **THEN** the live `match_<floor>` stream's
  `draws` counter is unchanged by the planner (it moves only by the engine's own draws), and the
  `ai_<floor>` counter rises by (tie-set draws + number of new fork labels this turn) — sandboxes
  draw from their forks (A3 confirms).

**Lethal**
- [ ] **A6 GIVEN** boss attackers summing to ≥ player health with no Taunt, **WHEN** the boss
  turn runs with any band overlay (every band has `lethal_search ≠ off`), **THEN** the player's hero is at ≤ 0 when the turn ends and
  the first `ai_decision.mode` is `LETHAL`.
- [ ] **A7 GIVEN** lethal that requires killing a 2/3 Taunt with a 3/3 first then attacking face
  with two others, **WHEN** band 2 or 3 plays, **THEN** lethal is taken and the first
  `ai_decision.mode` is `LETHAL`; **WHEN** band 1 plays (`lethal_search = shallow`, depth 1),
  **THEN** no `ai_decision` on that turn has `mode = LETHAL` and the first one records
  `lethal_search: shallow_none` (whether normal scoring still kills the player is not asserted).
- [ ] **A8 GIVEN** lethal only via weapon equip + hero attack + 3-damage spell within mana,
  **WHEN** band 3 plays, **THEN** lethal is taken in that or an equivalent order.
- [ ] **A9 GIVEN** `potential − taunt_hp < player_health` (F4), **WHEN** the turn runs, **THEN** the
  lethal search expands 0 nodes (the prune fires at the root).
- [ ] **A10 GIVEN** a lethal plan whose first step's Deathrattle summons a player Taunt, **WHEN**
  executed live, **THEN** `ai_plan_aborted` is emitted once and the turn completes with normal
  scoring (no rejected command).

**Scoring and heuristics**
- [ ] **A11 GIVEN** the F1 worked example (aggro, 6 mana, player 2/3 Taunt, boss 3/3, 4/4 in
  hand), **WHEN** scored, **THEN** the action order is trade, play 4/4, `end_turn`, and the logged
  scores equal 2.45 and 1.87 (±0.01).
- [ ] **A12 GIVEN** `rules.hero_power = spare_mana`, 3 mana, a 3-cost card in hand, **WHEN**
  scored, **THEN** the card is played and the hero power is not used; **GIVEN** 2 mana and no
  2-cost card, **THEN** the hero power is used.
- [ ] **A13 GIVEN** the player cast an `aoe`-tagged spell earlier this match and the boss has 4
  minions, **WHEN** a 5th minion play is scored with `w_over = 1`, **THEN** its score is lower by
  exactly `1/7` than the same play with `aoe_seen = false`.
- [ ] **A14 GIVEN** the control profile and a Fireball-class spell with legal targets 6/6, 1/1
  and the player's hero at 30, **WHEN** scored, **THEN** the 6/6 is targeted.
- [ ] **A15 GIVEN** F6's example board (incoming 16, boss at 18, band 3), **WHEN** the turn plans,
  **THEN** `mode = DEFENSIVE` is logged and a Taunt in hand is played before a non-Taunt of equal
  stats; **GIVEN** the same board with band 2 (`defensive = false`), **THEN** `mode = NORMAL`.
- [ ] **A16 GIVEN** a Discover with options [2-cost, 2-cost identical, 7-cost] and `mana_max = 4`,
  **WHEN** the boss chooses, **THEN** index 0 is picked, no `ai_<floor>` draw is consumed, and the
  `ai_decision {kind: choice}` lists 2 alternatives.
- [ ] **A17 GIVEN** a minion whose own effect uses the `adjacent` selector (derived
  `position_sensitive`, C6), **WHEN** `legal_commands` offers 4 positions, **THEN** 4 candidates
  are simulated; **GIVEN** a plain minion, **THEN** exactly 1 position (rightmost) is simulated.
- [ ] **A18 GIVEN** the player's board is full (7), **WHEN** removal and a face attack of equal
  base score are available, **THEN** the removal is chosen (`w_threat × 1.25`).

**Telegraphing**
- [ ] **A19 GIVEN** boss attackers 4 + 3 and `intent_mode = full`, **WHEN** the player's turn
  starts (`telegraph_mode = full`), **THEN** `ai_intent_shown {intent_key: attack_face, amount: 7,
  effective_mode: full}` is emitted; **GIVEN** `class_only`, **THEN** `amount` and `target_id`
  are null; **GIVEN** `intent_mode = full` and `telegraph_mode = brief`, **THEN** `effective_mode =
  class_only` and `amount`/`target_id` are null; **GIVEN** `telegraph_mode = off` (or a
  `boss_overrides` entry with `intent_mode = hidden`), **THEN** `effective_mode = hidden`, no
  `ai_intent_shown` is emitted and `ai_intent_committed` still is; **GIVEN** the band-1, band-2
  and band-3 overlays with no `boss_override`, **THEN** none resolves to `hidden` (C8.4, D-04).
- [ ] **A20 GIVEN** a boss passive that doubles the boss's healing (hook installed), **WHEN** a
  heal is scored in the sandbox, **THEN** `f_heal` reflects the doubled amount (clone carries
  hooks).
- [ ] **A21 GIVEN** the player kills the boss's only attacker after an `attack_face` forecast,
  **WHEN** the boss turn starts, **THEN** `ai_intent_committed.kept = false` and the new
  `intent_key ≠ attack_face`.

**Robustness and performance**
- [ ] **A22 GIVEN** the harness at band 3 budgets on the target machine (headless, release
  template), **WHEN** 200 seeded matches run, **THEN** planner time per round (one `forecast` plus
  one `play_turn`) is p95 ≤ 50 ms and the match's total `ai_decision` events are ≤ 400.
- [ ] **A23 GIVEN** 1,000 seeded matches (mixed bands, boss vs hero-script), **WHEN** complete,
  **THEN** zero `command_rejected` events have `side = boss`, zero `ai_fault`, zero
  `resolution_overflow`, and every match ends by `hero_dead` or `turn_cap`.
- [ ] **A24 GIVEN** a state where `legal_commands() == [end_turn]`, **WHEN** `play_turn` runs,
  **THEN** exactly one command is submitted and exactly one `ai_decision` is logged.
- [ ] **A25 GIVEN** a BossDef with `ai_profile = "does_not_exist"`, **WHEN** Card Database loads,
  **THEN** `E_AI_PROFILE_UNKNOWN` is reported; **WHEN** a match starts anyway (release), **THEN**
  the boss plays with `default ⊕ bands[band]` and A6 still holds.
- [ ] **A26 GIVEN** `w_face = 9` in a profile, **WHEN** loaded, **THEN** `E_AI_WEIGHT_RANGE` is
  reported and the effective weight is 5 (clamped), visible in `ai_decision.features`.
- [ ] **A27 GIVEN** a zero-cost card loop fixture, **WHEN** the turn runs, **THEN** `end_turn` is
  submitted after 30 actions with `reason: action_cap`.
- [ ] **A28 GIVEN** the harness, **WHEN** run with `--boss boss_x --seeds 100`, **THEN** it writes
  `production/qa/sim/boss_x_<date>.json` with `win_rate`, `mean_turns`, `p95_planner_ms`,
  `rejections = 0`, and a second run with the same seeds produces an identical file.
- [ ] **A29** No hardcoded weights, budgets or delays in `src/ai/**` — every value in F1–F9 is
  read from `ai_profiles.json` (grep gate in CI for numeric literals outside normalisers).
- [ ] **A30 GIVEN** a debug build with the profiler attached, **WHEN** 20 band-3 boss rounds run
  through the real match driver (windowed, not headless), **THEN** no frame attributes more than
  2 ms of main-thread time to `src/ai/**` (`.claude/rules/ai-code.md`), and the `ai_decision`
  sequence equals the headless run of the same seed (A1).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| `MatchState.clone()` must carry the `HookRegistry` (boss passive, treasures) for sandbox scoring to be correct. | Match Rules GDD / `/create-architecture` | Before Boss AI stories | Confirmed 2026-11-03: `hooks` is a `MatchState` field and `clone()` is a deep copy with no shared references (match-rules C1, C2); Treasures guarantees hook entries are plain data (treasures.md rule 6). A20 stays as the test |
| `ai_intent_committed` and the `amount` field on `ai_intent_shown` extend RNG & Event Log's v1 catalogue (its rule 12a already names `ai_decision`, `ai_plan_aborted`, `ai_fault` as diagnostic events in the same log). | RNG & Event Log GDD | Before `/consistency-check` | Resolved 2026-11-03 — cross-review C-30: both are catalogued (rng §D) |
| `assets/data/ai_profiles.json` added to DD-T01. | Owner (orchestrator) | — | Resolved: DD-T01 lists it (2026-11-03) |
| Card Effects annotations: op names realigned to its C5, `position_sensitive` / `aoe` / synergy matching derived by Boss AI from C3 selectors and C2 triggers (C6). Residual: Card Effects' Dependencies row for Boss AI should also name op names and selectors as consumed. | Card Effects GDD / `/consistency-check` | Before `/create-architecture` | Resolved here 2026-11-03; cross-GDD row wording pending |
| `telegraph_mode` player setting (`full \| brief \| off`): meta-progression.md (Dependencies, Cross-References) and run-ui.md attribute it to Boss AI, while meta-progression's own Interactions row withdraws it. This GDD defines only per-boss `intent_mode`. Does a player-side setting exist, and may it be `off` (Pillar 3 argues against hiding)? | Owner | Before `/ux-design` HUD | Resolved 2026-11-03 — cross-review C-01 / DD-X03: the setting exists (Meta M9), `off` is a player opt-in, rule added to C8.4 (`effective_mode`), Meta Progression (soft) added to Dependencies; boss-imposed `hidden` capped per D-04 |
| Adjacency lethal through a lord already in play is missed (Edge Cases, A17). Extend `position_sensitive` to "any friendly minion in play has an `adjacent` aura" if the harness shows missed lethals. | ai-programmer | Alpha balance pass | Deferred |
| Boss mulligan: none in v1 (closes Match Rules' question). Revisit if the harness shows band-1 bosses bricking (> 15% of matches with no play by turn 3). | Content / Boss AI | Alpha balance pass | Resolved for v1 |
| Band win-rate targets for the harness (provisional: boss win rate vs the hero-script 20–30% band 1, 40–50% band 2, 55–65% band 3; rationale: a mid-skill pilot who beats the script by ~10 points completes a run roughly 1 in 8). | Content GDD / `/balance-check` | Alpha balance pass | Resolved 2026-11-03 — cross-review D-07: one basis, the player targets. The harness reports boss win rate per floor; Content AC-13 passes when `1 − boss_win_rate(f)` is within `PRESSURE_TOL`-equivalent tolerance (±0.10) of `target_win_rate_by_floor[f]`. Band targets are derived numbers (band 1 ≈ 0.10–0.20 boss wins), not a second knob |
| Should `tie_epsilon` be 0 in band 3 (fully canonical play) so expert players can learn exact lines? | game-designer | After first playtest | Open |
| Two-ply lookahead (player's best reply) for band 3 trades — out of v1; the F6 threat estimate stands in. | ai-programmer | Full Vision | Deferred |
