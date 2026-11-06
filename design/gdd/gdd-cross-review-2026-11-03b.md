# Cross-GDD Review Report (second run, same day — `since-last-review`)

Date: 2026-11-03
GDDs Reviewed: 13 of 13 present
Not read: none (every GDD was loaded by section — status header, Detailed Design/Rules, Formulas, Dependencies, Interactions, Tuning Knobs, Cross-References, Acceptance Criteria, Open Questions — via Grep `^#` and ranged Reads; whole-file reads above 40 KB are refused by `validate-read.sh`, as designed)
Focus: since-last-review — **both passes ran**: Phase 2 (cross-GDD consistency, 2a–2f) re-run across all 13 GDDs plus `systems-index.md`, `design/registry/entities.yaml` and `design/design-decisions.md`; Phase 3 (design holism, 3a–3g) re-run for every finding whose inputs changed since the first report (D-02, D-04, D-06, D-07, plus the new `PLAN_MAX 7` / temporary-mana inputs); Phase 4 scenarios re-walked where a prior finding was applied (S-02, S-04, S-05) plus one new walk (suspend → resume)
Systems Covered: Card Database, RNG & Event Log, Match Rules, Card Effects, Boss AI, Heroes, Run Structure, Reward Draft, Treasures, Meta Progression, Match UI, Run UI, Content
Prior report: `design/gdd/gdd-cross-review-2026-11-03.md` (verdict FAIL; Part B C-01…C-30, D-01…D-11, S-01…S-06). This file is named `…-2026-11-03b.md` (no hyphen before the suffix) on purpose: `review-scope.sh` picks the baseline with `sort | tail -1`, and `-b.md` sorts *before* `.md`, so a hyphenated suffix would make the next incremental run baseline on the first report and silently skip everything changed since this one.
Scope input: `bash .claude/scripts/review-scope.sh` → `PRIOR_REVIEW: design/gdd/gdd-cross-review-2026-11-03.md`; CHANGED = all 13 system GDDs; DEPS lines add nothing outside the 13 (the `design-docs.md` / `content.md → content.md` entries are self- or template-references, not GDDs).
Config: workflow `standard` (overrides: match-rules `full`, card-effects `full`), automation `guided`, review_mode `lean`. Engine: Godot 4.7.2 (`project.yaml`); no engine-API claim is made in this report, so nothing is NOT SOURCEABLE here.

Process notes (obligation 3 of `.claude/rules/skill-authoring.md`, stated in the output):
- **Phases 2 and 3 ran inline, not as parallel `game-designer` sub-agents** — this session has no `Agent` tool. Both checklists were worked in full; the independent-reviewer property was not obtained.
- **CD gate skipped — Lean mode.** No `creative-director` consultation on the design-holism findings.
- **`AskUserQuestion` not called** (nobody could answer this run). Each place the skill would ask, the recommended option was taken and is listed under **Decisions taken**.
- **card-effects.md** was read in its current on-disk state while its final `/design-review` pass was finishing concurrently (systems-index row 4 `In Review`; 12 others `Approved`). Its review log may gain an entry after this report; its GDD text was not expected to change and every C-item touching it verified against the text read.
- Pillars are defined (`game-concept.md` §Game Pillars, 4 + 4 anti-pillars), so 3f had a reference.
- Inputs besides the GDDs: `systems-index.md`, `game-concept.md` (whole, 19 KB), `design/registry/entities.yaml` (targeted greps on the entries the first report named), `design/design-decisions.md` (DD-X01…X07, DD-H05, DD-H06, DD-T01, DD-T04), `production/session-state/active.md` (the per-GDD fix notes), the 13 review logs' tails.

---

## Part A — Re-verification of every prior item against the current documents

Legend: **RESOLVED** = the current text carries the change (evidence names file and location). **OPEN** = still needed; severity in the Type column. **n/a** = the prior item required no document change (Info).

### Consistency items C-01 … C-30

| Item | Prior severity | Status | Evidence in the current documents |
|---|---|---|---|
| C-01 settings record vs DD-X07/X03 | Blocking | **RESOLVED** | meta-progression M9 L302–308 (`anim_speed` labels, `reduce_motion`, `text_scale 1.0/1.25/1.5`, `telegraph_mode` → Boss AI `effective_mode`, `action_delay_ms 0..2000 (600)`), Interactions L380 / Dependencies L646 Boss AI rows, Tuning Knobs L671, Cross-Refs L722–724, OQs L861–862 Resolved; match-ui Core Rule 4 L216, F3 L527–533 (`SPEED_DIV` normal 1.0 / fast 2.0), F4 L557 (`action_delay_ms / 1000`, `MIN_ACTION_GAP_S` kept), Tuning Knobs L712–713, L729–732, OQs L1020–1021; boss-ai C8.4 L230–233 (`effective_mode = min(intent_mode, telegraph_mode)` over `full > class_only ≡ brief > hidden ≡ off`), Interactions L345, Dependencies L640, Tuning Knobs L674, A19 L845–851; systems-index row 5 lists Meta Progression; run-ui L107, L298 use the same order |
| C-02 Hollow Crown permanent crystal | Blocking | **RESOLVED** | match-rules C1 L98 (`crystal_bonus`), C4 step 2 L201–205, C5 L248–255, F4 L755–769, AC-06 L1179–1181; treasures T8 row 1 L233, T9 L276, Edge Cases L573–576, AC-15 L811, R-1 L838 Resolved; card-effects `mana` op L318 |
| C-03 `war_iron_vanguard` `armour` tag vs `PLAN_MAX` | Blocking | **RESOLVED** (option B) | heroes F2 L298 `4 / 7`, L300 "War 7", Tuning Knobs L453, OQ L622 Resolved; content L118 keeps the tag, CN-1 wording; reward-draft re-derived its F1/F7/AC-20 on 7 plan cards (L9, L309–313) |
| C-04 stored `targeting` field | Blocking | **RESOLVED** | match-rules Interactions L611, Dependencies L984, Cross-Refs L1141 (`targeting_spec(def_id)` derived); card-database Cross-Refs L556; card-effects C1 L137–139, OQ L1432 Resolved |
| C-05 RNG API names | Blocking | **RESOLVED** | match-rules Interactions L612 (`match_<floor>` handle, `randi_range`, `shuffle`, `weighted_pick`), Dependencies L985, Cross-Refs L1140; rng OQ 8 closed (header L13) |
| C-06 `unlock` object (DD-X01) | Blocking | **RESOLVED** | card-database CR-3 L135–138 (HeroDef), L158–159 (TreasureDef), L164–165 (BundleDef), Interactions L283, Dependencies L489, AC L621–623; treasures T1 L91, R-17 L853 Resolved |
| C-07 Match UI event aliases | Warning | **RESOLVED** | match-ui U3 L153–163 (aliases deleted), rows L174, L178, L181, L183, L190 for the five primitive events; OQ L1017 Resolved; match-rules and card-effects OQs closed (card-effects L1433) |
| C-08 Run UI envelope | Warning | **RESOLVED** | run-ui Interactions L295 `{seq, turn, type, payload, cause_seq}` |
| C-09 RNG catalogue draft rows / `defeat` / `treasure_granted` owner | Warning | **RESOLVED** (but see **N-02** — the `run_ended` row's shape) | rng §D L181 (`flags[]`, `option_index`), L185 (`victory/defeat/abandoned`, `abandon_reason`), L182 and Interactions L237 (`treasure_granted` under Run Structure) |
| C-10 `unlocked_ids("treasure")` → `unlocked_keys()` | Warning | **RESOLVED** | reward-draft D3 L106, Interactions L251, Dependencies L570, Cross-Refs L662, OQ L731 Resolved; treasures R-18 L854 Resolved |
| C-11 "first run forces War" (DD-X02) | Warning | **RESOLVED** | heroes H-2 L83–84, Interactions L253, Dependencies L435, OQ L621 Resolved; run-structure Interactions L422, OQs resolved (§Open Questions) |
| C-12 `suspend` command | Warning | **RESOLVED** | run-structure Core Rules L76–81, R8.7 L326–331, States L366–370, T21 L400, Interactions L426 ("seven"), Dependencies L716, Edge Cases L641, UI row L778; run-ui `pause` row L108, S23 L285, Dependencies L535, Cross-Refs L679; rejection code unified on `E_BAD_PHASE` in both (run-ui housekeeping L8) |
| C-13 `treasure_short_policy = reoffer` (DD-X06) | Warning | **RESOLVED** | reward-draft D8 L167 (`E_CONFIG` in release), Edge Cases L488, Tuning Knobs L594, AC-11 L691 |
| C-14 fork draw accounting | Warning | **RESOLVED** | boss-ai C9 L248–250, F8 L497, A3 L790, A5 L799 |
| C-15 `ai_profiles.json` loader wording | Warning | **RESOLVED** | boss-ai Interactions L343, Dependencies L638, Edge Cases L606–610 (`config("ai_profiles")`, Card Database loads) |
| C-16 three Card Effects questions | Warning | **RESOLVED** | match-rules C4 L211–214 (player side first everywhere), L230–233 (card instances in hand/deck; recipient's controller's End step); card-effects F3 L760, Edge Cases L924, OQ L1436 Resolved |
| C-17 who drives Boss AI | Warning | **RESOLVED** | run-structure Interactions L427, Dependencies L717; boss-ai Dependencies L641; match-ui L95 ("driven by Run Structure's match driver") |
| C-18 `MAX_ATTACKS_CAP` rationale | Warning | **RESOLVED** | match-rules Tuning Knobs L1014; treasures F2 L435, L643, L663 agree (`= 4`, Twin Grip `set 2`) |
| C-19 `unlock_earned` → `unlock_granted` | Warning | **RESOLVED** | treasures States L325; meta OQ L863 Resolved |
| C-20 Meta toast wording | Warning | **RESOLVED** | meta UI Requirements L693 ("Run UI … owns the visible duration — run-ui F3 sets the floor and cap", no numbers); run-ui F3 L360–377 (5000–8000 ms); registry `toast_visible_ms` [5000, 8000] |
| C-21 `profile_defaults.json` | Warning | **RESOLVED** | meta M9 L310–311, Tuning Knobs L651, AC-30 L850, OQ L864; card-database CR-1 L79, L83, Dependencies L489, AC L587; design-decisions DD-T01 L57 |
| C-22 Card Effects "undesigned"/"provisional" | Warning | **RESOLVED** | card-effects Interactions L688 ("Primitives added … 2026-11-03"), C10 L514, Dependencies L1060 ("five dependents"), L1068, OQ L1431 Resolved; no `undesigned`/`provisional` left outside the history header |
| C-23 `neutral_lantern_bearer` ★ | Warning | **RESOLVED** | content L101 (legend: ★ = starter membership only), L214 (no ★) |
| C-24 `content_budgets.json` schema | Warning | **RESOLVED** (key list present) — see **N-01** for where the file is registered | content CN-6 L491–495 |
| C-25 systems-index bottlenecks / layer map / row 13 / tracker | Warning | **OPEN (low) — partial** | Bottleneck counts L147 ✓ (7 and 5 match the table), layer map L118–141 ✓ regenerated, Progress Tracker counts ✓. Still wrong: §Recommended Design Order row 13 (L169) is a pasted enumeration row `\| 13 \| Content \| Gameplay \| MVP → Alpha \| Approved \| design/gdd/content.md \| Card Database, …` instead of `\| 13 \| Content \| MVP → Alpha \| Feature \| game-designer, systems-designer, economy-designer \| L \|`; Progress Tracker L202–203 label both counts "(In Review)" although 12 rows are Approved; header L5 "reviews pending" is stale |
| C-26 Treasures contract markers | Warning | **RESOLVED** | treasures Interactions L351–352, Dependencies L622, L627, F4 heading L460 ff., `w_rarity` L473 ("Per-item"), F2 `clamp_h` L435, Tuning Knobs L643 (`MAX_ATTACKS_CAP = 4`); R-2…R-20 rows Resolved (§Open Questions) |
| C-27 game-concept stale lines | Warning | **RESOLVED** | game-concept L96 (utility-scored AI), L253 (technical risk), L299 and L311 (10 treasures, DD-H06), Resolved list L278–282 |
| C-28 Reward Draft "requests" / universal floor | Warning | **RESOLVED** | reward-draft Interactions L272–273 (hard floor 3, recommended 7 = 3K − 2), F6 L415–416, Dependencies L572; "Requests" clause gone; content CN-5 L461 cites the same rule |
| C-29 registry `referenced_by` hygiene | Warning | **OPEN (low) — partial** | Done: `hero_war/decay/knowledge` now list reward-draft, match-ui, run-ui (L77–79, L97–99, L117–119); match-ui removed from `action_score`, `spell_damage_requested`, `discover_pool`, `transition_duration`, `player_starting_health`, `ai_planner_target_ms`; reward-draft removed from `collectible_pool_size`, `hero_set_size`. Not done: `design/gdd/run-structure.md` still appears under all 16 `boss_*` entities (L175–359), `hero_decay` (L94), `hero_knowledge` (L114) and `stream_seed` (L742) although run-structure.md names none of them (it names only fixture ids `boss_a1…`, `hero_war`). Mechanical choice stands: remove those 19 lines |
| C-30 housekeeping OQ rows | low | **RESOLVED** | spot-checked: match-rules OQs L1332, L1335; boss-ai L890–896 and C9 L254 (rule 12a); card-database OQ L672; heroes L615–616; run-structure §Open Questions (all named rows Resolved/Confirmed); run-ui Cross-Refs L679 `E_HERO_LOCKED`; match-ui no `(undesigned)`/`(in progress)` left; content `(concurrent)` and "must list" gone; meta L860(a), L863–864; treasures States L328 `drafts[]`; reward-draft L731 |
| V-11 (first report: NOT VERIFIED) | advisory | **RESOLVED** | card-database Formulas "Bundle pool size" L342 now cites Reward Draft's registered `bundle_pool_min` |

### Design-holism items D-01 … D-07 (Phase 3 re-run where inputs changed)

| Item | Prior severity | Status | Evidence / re-assessment |
|---|---|---|---|
| D-01 universal economy treasures are the generic pick | Warning | **OPEN (by design — first balance pass)** | Inputs unchanged (treasures F1 Hollow Crown 5.4, Vanguard's Banner 5.0, both `universal`). Reward-draft OQ L742 carries the 60 % pick-rate rule; the per-treasure win-rate delta is not yet a `/balance-check` metric anywhere. No document change was asked for; stays a standing Warning for the balance pass |
| D-02 affinity + pity rails | Warning | **RESOLVED (applied)** | reward-draft `AFFINITY_CAP` 8 → 6 (F1 L291–299, Tuning Knobs L586, AC-20 L705), rails metric in AC-29 L718 and OQ L743. Re-assessed at cap 6 / step 0.25: an on-plan bundle tops at 2.5× — the coverage slot remains the only guaranteed off-plan option from ~floor 5, which is what the AC-29 metric now measures; the ~70 % trigger is stated. Owner may restore 8 (OQ L743 says so) |
| D-03 Curiosity hook starves on a War run | Warning | **RESOLVED 2026-11-03 (owner: any-hero treasure — Living Armory re-keyed to `first_victory`, DD-X12)** | treasures T8 locks the same four treasures (L245–250); meta OQ L860(b) still Open and names this item; meta Tuning Knobs L670 states the risk. Flagged, not applied — Content/Meta choice |
| D-04 band-3 `hidden` vs Pillar 3 | Warning | **RESOLVED** | boss-ai C8.4 L223–230 (boss `intent_mode` capped at `class_only`; `hidden` only via `boss_overrides` for a concealment passive), F9 L521, A19 L851; content CN-3 L290 ("no boss uses `hidden`"), Shadow of the Delve `class_only` L314 |
| D-05 "done" is far away | Warning | **OPEN (by design — measure at first playtest)** | game-concept Open Questions L266–270 now records the ~11 h/hero figure and the measurement plan; run-structure F6 unchanged. Nothing to change in a GDD |
| D-06 every MVP run has the same four bosses | Warning | **RESOLVED** | content CN-1 L72, B1 L303 (`boss_torchbearer` → MVP-1), CN-6 L481, AC-2 L880; DD-H06 L51 (5 = 3/1/1); run-structure F2 L473, Dependencies L718, OQ resolved; systems-index L85; game-concept L295, L311. Re-assessed: band-1 pool 3 over 2 floors gives 6 distinct sequences — Discovery is present in the MVP test |
| D-07 two bases for the difficulty sim | Warning | **RESOLVED** | boss-ai C11 L290, OQ L896; content AC-13 L891, OQ L917 — single basis `target_win_rate_by_floor`, ±0.10 |
| D-08 … D-11 (Info) | Info | n/a | Economy, attention budget, loop count and curve unchanged by the revisions; temporary mana (match-rules C5 housekeeping, `decay_soul_tithe` / `neutral_treasure_map`) adds a per-match source that expires at the End step — no new source/sink imbalance (3d) |

### Scenario items S-01 … S-06 (Phase 4 re-walk)

| Item | Prior severity | Status | Evidence |
|---|---|---|---|
| S-02 match start with Hollow Crown | Blocker | **RESOLVED** (root cause C-02); **Info residual OPEN** | Re-walked: `begin_match` → C3 step 4 hooks → `add_mana(PLAYER, 1, temporary=false)` → `crystal_bonus = 1` → C4 step 2 reads it every Start step; `mana_added` precedes the first `card_drawn` (match-rules AC-06, treasures AC-15 agree). Residual Info: match-ui's required fixture list (L396) still names one `mulligan` fixture; no 5-card case (Bottomless Satchel folding 3 → 5) is listed; treasures' "mulligan screen must fit 6" note stands |
| S-04 resolution fault → retry | Warning | **RESOLVED** | match-ui U9 L348–353 (`end.fault` "Rules fault — this floor is replayed, not lost", no `sfx.ui.defeat`, fixture `match_end_fault`, O13 L991–992); run-ui `boss_intro` L98 and S11b L273 ("Attempt n") |
| S-05 first Decay win → toast → restart | Warning | **RESOLVED** | run-ui U5 L162–168 (unlock toasts persist across transitions), Edge Cases L446–449, AC-32; C-20 wording settled |
| S-01, S-03, S-06 | Info | n/a | No change was required; hand-offs re-checked unchanged. New walk — **suspend between matches then resume**: `suspend()` from `post_match_reward` after S3 → Menu → `resume` → `restore` → `offer(bundle)` regenerates the identical offer (reward-draft F4/D12, run-structure R8.7, AC-36). Defined; no issue |

**Counts (prior items): RESOLVED 37 (28 C + 4 D + 3 S + V-11 + one Blocker root cause) · OPEN 6 (C-25 low, C-29 low, D-01 Warning-by-design, D-03 Warning, D-05 Warning-by-design, S-02 Info residual) · n/a 7 (D-08…D-11, S-01, S-03, S-06). Blocking still open: 0.**

---

## Part B — New findings from the re-run Phase 2 pass

Each names file, section, current text and replacement text so it can be applied mechanically. Line numbers are as of this review.

### Blocking
None.

### Warnings

⚠️ **N-01 — `content_budgets.json` is declared a Card Database CR-1 config file, but CR-1 and DD-T01 do not list it** (2c stale reference)
Involved: `content.md` §Detailed Design › CN-6 step 2 (L491–495): "`content_budgets.json` keys (a config file, Card Database CR-1, served by `config("content_budgets")`; read by the Content validator and `/balance-check`, never by the game)"; also L576–577 and Tuning Knobs L796. `card-database.md` §Core Rules CR-1 config-file table (L70–80) lists eleven files — `match_rules`, `card_effects`, `ai_profiles`, `run_structure`, `reward_draft`, `treasures_balance`, `heroes_balance`, `match_ui`, `run_ui`, `profile_defaults`, `card_database` — and no `content_budgets`; its shipped-data AC (L584–588) enumerates the same eleven; `design/design-decisions.md` DD-T01 (L57) omits it too. Card Database's own rule is "nothing else parses JSON" and `config(<unknown>)` returns `null` with a logged error (CR-6 L229), so as written the Content validate command (content AC-1, AC-21) has no sanctioned way to read its constants.
Replacement: `card-database.md` CR-1 table — add the row `| content_budgets.json | config | yes | Content | F1–F6 validator and /balance-check constants (content CN-6 step 2); read by the validate command and tooling, never at runtime |`, append `config("content_budgets")` to the AC at L584–588 and to Content's row in Interactions (L282 ff.) / Dependencies; `design/design-decisions.md` DD-T01 — add `content_budgets.json` to the file list. Alternatively `content.md` L491 drops the CR-1 claim and states the file is tooling-only, read by the validate command directly — then AC-21's "no literal outside `content_budgets.json`" still holds. The first is the mechanical choice (the file already follows the CR-1 envelope per L489–491). Warning, not Blocking: the serving mechanism exists and the consumer is authoring tooling, not a runtime rule; apply before `/create-architecture` freezes DD-T01's list.

⚠️ **N-02 — `run_ended` payload shape differs between Run Structure / Meta and the RNG catalogue / Run UI** (2c; introduced by the C-09 wording)
Involved: `run-structure.md` R1 L116 defines `result` as a Dictionary `{outcome: victory | defeat | abandoned, floors_cleared, floor_reached, total_turns, ended_by, abandon_reason}` and R6 L238–243 / Core Rules L262 emit `run_ended{result, floors_cleared, total_turns, run_seed_hex}`; `meta-progression.md` F2 L429 and F3 L461 read `R.result.outcome` and `R.result.abandon_reason` (consistent with Run Structure). `rng-event-log.md` §D catalogue L185 flattens it: `result (victory/defeat/abandoned), abandon_reason (…), floor_reached, ended_by, floors_cleared, total_turns, run_seed_hex` — `result` is the enum there, not the dictionary. `run-ui.md` States L252 writes `run_ended{outcome}` and S16 L278 `run_ended{victory|defeat}`; run-structure's own T7/T8/T13 rows (`run_ended{victory}`, `run_ended{abandoned, player}`) and AC L862 (`run_ended{result: victory}`) use shorthand. Meta's fold depends on the nested path, so the catalogue — which `/design-review` and Match/Run UI treat as the mirror of record (DD-T04) — currently documents a shape Meta would not parse.
Replacement: `rng-event-log.md` L185 → `| run_ended | Run Structure | result {outcome: victory \| defeat \| abandoned, abandon_reason: player \| data_version_mismatch \| save_corrupt \| null (only player counts as a loss, R6), floor_reached, ended_by, floors_cleared, total_turns}, run_seed_hex (run-structure R1/R6 result record; meta-progression F2 reads result.outcome) |`. `run-ui.md` L252 → `run_ended{result.outcome}`; S16 L278 → `run_ended{result.outcome: victory \| defeat}`. Optional tidy in `run-structure.md`: T7/T8/T13 and AC L862 shorthand → `run_ended{result.outcome: …}` so the three tables agree letter for letter. Warning: the data exists under one owner; only the path spelling diverges.

### Info

ℹ️ **N-03 — Content cites "DD-H06's 4" after DD-H06 was raised to 5.** `content.md` CN-1 L72 and L78 read "5 (3 / 1 / 1 — DD-H06's 4 plus one spare band-1 boss, cross-review D-06 …)" / "5 bosses (DD-H06's 4 plus the D-06 spare)"; `design-decisions.md` DD-H06 L51 now says 5 (raised from 4 on 2026-11-03). Replace with "5 (3 / 1 / 1, DD-H06 — raised from 4 per cross-review D-06)". Numbers agree everywhere (content, run-structure F2/Dependencies, concept, index, DD-H06); only the attribution is stale.

ℹ️ **N-04 — Card Database's config-file count is written three ways.** `card-database.md` header L11 "nine", L12 "nine → ten", L90 and Cross-Refs L568 "eleven", OQ L672 "nine per-system knob files"; the CR-1 table holds eleven rows (twelve once N-01 lands). Settle on the table's count in L90/L568 and leave the history notes dated.

ℹ️ **N-05 — New open rule question with a cross-GDD consequence.** `match-rules.md` OQ L1337 (raised by its housekeeping pass): a defending hero holding a weapon deals weapon attack back to the attacker (C8 step 4), where Hearthstone's rule is 0. The row already names that Boss AI F3 trade quality follows if the reading changes. Not a contradiction today — both GDDs read C8 as written — but it is the one open rule question that would ripple; decide before Boss AI implementation stories.

ℹ️ **N-06 — Index and concept status lines.** `systems-index.md` is covered under C-25 above. `game-concept.md` L4 now reads `Status: Approved` and L346 "12 Approved, Card Effects In Review" — consistent with the index table; no action.

Phase 2 checks with no finding (stated so a silent skip is distinguishable): 2a dependency bidirectionality re-verified for every row the revisions touched (Boss AI ↔ Meta Progression, Run Structure ↔ Run UI `suspend`, Reward Draft ↔ Meta `unlocked_keys()`, Treasures ↔ Match Rules `crystal_bonus`, Card Effects ↔ Match Rules primitives) — all reciprocal; 2b floor/ceiling and state transitions (`E_BAD_PHASE` for `suspend`, `crystal_bonus` 0–2 clamp to `MAX_MANA`, `telegraph_mode` order identical in boss-ai, meta, match-ui, run-ui, `action_delay_ms` 0–2000 in all four) agree; 2d no duplicate knob ownership introduced (`SPEED_DIV` Match UI only; `telegraph_mode` Meta only; `AFFINITY_CAP` Reward Draft only — not a registry constant, correctly, since it is internal to one GDD); 2e formula ranges (reward-draft F5 `B_min` 4–27 = registry `bundle_pool_min`; MVP `B_min` 9 ≤ 10 bundles; `n_universal` 7 ≥ recommended 7; run-ui F3 5000–8000 = registry `toast_visible_ms`) compatible; 2f acceptance criteria — match-rules AC-06 and treasures AC-15 now assert the same turn-1/turn-9 readings; content AC-2/AC-3 and concept Scope Tiers agree on 5 bosses / 10 bundles / 36 bundles / 10–20 treasures.

---

## Game Design Issues (Phase 3 — re-run for changed inputs only)

Pillar map (3f) unchanged from the first report; the D-04 fix removes the one Pillar 3 tension (no boss-imposed `hidden`). Player fantasies (3g) unchanged. 3a/3b unchanged. 3c: `PLAN_MAX 7` leaves War's starter the most plan-heavy of the three (7 / 5 / 6) — reward-draft re-derived F1 so War's floor-1 affinity does not over-pull (`armour` 150 vs `weapons` 175); no dominant strategy introduced. 3d: temporary mana is a bounded source with an automatic sink (expires at End step). 3e: unchanged except D-06 (resolved).

### Game Design Blocking
None.

### Game Design Warnings
D-01, D-03, D-05 remain open as listed in Part A (none asks for a GDD change this run; D-03 awaits the owner).

---

## Cross-System Scenario Issues (Phase 4)

Scenarios walked: 4 (S-02, S-04, S-05 re-walked; suspend → resume new)

#### Blockers
None.

#### Cross-System Scenario Warnings
None.

#### Cross-System Scenario Info
ℹ️ S-02 residual — match-ui fixture list has no 5-card mulligan case (Bottomless Satchel); see Part A.

---

## GDDs Flagged for Revision

| GDD / file | Reason | Type | Priority |
|---|---|---|---|
| card-database.md | N-01 add `content_budgets.json` to CR-1 + AC; N-04 count wording | Consistency | Warning |
| design/design-decisions.md | N-01 DD-T01 add `content_budgets.json` | Consistency | Warning |
| rng-event-log.md | N-02 `run_ended` row shape (`result.outcome`) | Consistency | Warning |
| run-ui.md | N-02 `run_ended{outcome}` → `result.outcome` (L252, L278) | Consistency | Warning |
| content.md | N-03 "DD-H06's 4" attribution; (N-01 if the tooling-only alternative is chosen instead) | Consistency | Info |
| systems-index.md | C-25 residual: design-order row 13, tracker labels, header note | Consistency | Low |
| design/registry/entities.yaml | C-29 residual: drop run-structure.md from 16 `boss_*`, `hero_decay`, `hero_knowledge`, `stream_seed` | Consistency | Low |
| match-ui.md | S-02 residual: add a 5-card `mulligan` fixture case | Scenario | Info |
| treasures.md / meta-progression.md / content.md | D-03 — owner decision on a `runs_won ≥ 1` any-hero treasure key | Design Theory | Warning (deferred) |

Systems index statuses were **not** changed (no `Needs Revision` written — nothing here is blocking, and the owner applies small fixes next; stated rather than asked).

---

### Verdict: CONCERNS

All six prior Blocking consistency findings (C-01 … C-06) and the one Blocking scenario (S-02) are resolved in the current documents; 28 of 30 C-items, 4 of 7 D-items and all 3 actionable S-items are resolved. Nothing blocking remains. Open: two new Warnings (N-01 `content_budgets.json` registration, N-02 `run_ended` payload path), two low residuals (C-25, C-29), three standing design warnings that by their own text wait on the balance pass or the owner (D-01, D-05, D-03), and three Info items. Both review passes ran; nothing is NOT ASSESSED; no advisory item is unverified (V-11 closed).

PASS: not reached — warnings present. FAIL: not reached — no blocking issue. NOT ASSESSED: no phase skipped and every GDD was readable.

### Recommended before `/create-architecture`
1. N-01 (three small edits: card-database CR-1 row + AC, DD-T01) and N-02 (rng catalogue row, two run-ui cells) — ~10 minutes, no design decision.
2. C-25 and C-29 residuals — mechanical.
3. D-03 — owner picks (one any-hero treasure key, or accept the starved first session); then meta M10 / AC-19 and treasures T8 follow.
Then `/gate-check` (Systems Design → Technical Setup). `/create-architecture` may start on CONCERNS; N-01 is the one item that should land first because DD-T01's file list is an architecture input.

---

## Decisions taken (in place of `AskUserQuestion`, nobody available to answer)

1. Wrote this report to `design/gdd/gdd-cross-review-2026-11-03b.md` — ISO date kept, suffix `b` without a hyphen so `review-scope.sh`'s `sort | tail -1` selects it as the next baseline (a `-b` suffix sorts before `.md` and would be skipped); the first report was not overwritten.
2. Did **not** edit `systems-index.md` statuses (no blocking findings; the skill's "Needs Revision" step would mark five files for Warnings/low items the owner applies next).
3. Did **not** edit any GDD, the index, the registry or the decisions file; only this report and an append to `production/session-state/active.md` were written. No commit.
4. N-01 severity set to Warning rather than the 2c "non-existent mechanic" Blocking — the `config()` mechanism exists and the consumer is the authoring validator; the rationale is in the finding so the owner can promote it.
5. N-02 replacement adopts Run Structure's nested `result.outcome` (its R1 record; Meta already reads that path) over the catalogue's flat enum.
6. D-01 and D-05 counted as OPEN (by design) rather than RESOLVED: their own text asked for measurement, not a GDD edit, so a "resolved" would be an assertion with no evidence.
7. Phases 2 and 3 run inline (no `Agent` tool); CD gate skipped (Lean mode) — stated above rather than silently.
8. Phase 7 handoff widget not shown; recommended next action: apply N-01 and N-02, then `/gate-check`.
