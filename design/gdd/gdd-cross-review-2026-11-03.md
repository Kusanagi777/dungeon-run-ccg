# Cross-GDD Review Report

Date: 2026-11-03
GDDs Reviewed: 13 of 13 present
Not read: none (every GDD was loaded by section: Summary, Player Fantasy/Overview, Interactions, Dependencies, Tuning Knobs, Cross-References, Acceptance Criteria, Open Questions, plus the Formulas sections of Match Rules, Heroes, Run Structure, Reward Draft, Treasures and Content and the RNG event catalogue; whole-file reads were refused above 40 KB by `validate-read.sh`, as designed)
Focus: full (consistency + design theory + scenario walkthrough)
Systems Covered: Card Database, RNG & Event Log, Match Rules, Card Effects, Boss AI, Heroes, Run Structure, Reward Draft, Treasures, Meta Progression, Match UI, Run UI, Content
Inputs: `design/gdd/game-concept.md` (pillars), `design/gdd/systems-index.md`, `design/registry/entities.yaml` (read in five ranges), `design/design-decisions.md` (DD-M/R/H/T and DD-X01..X07, all treated as DECIDED), the 13 review logs under `design/gdd/reviews/`, and the orchestrator's collected item list (`cross-gdd-items.md`), each line of which was re-verified against the current documents.
Config: workflow `standard` (overrides: match-rules `full`, card-effects `full`), automation `guided`, review_mode `lean`. Engine: Godot 4.7.2 (`project.yaml`); no engine-API claim is made in this report, so nothing is NOT SOURCEABLE here.
`bash .claude/scripts/review-scope.sh` → `PRIOR_REVIEW: NONE (full review required)`; CHANGED = all 13 GDDs.

Process notes (obligation 3 of `skill-authoring.md`, stated in the output):
- **Phases 2 and 3 ran inline, not as parallel `game-designer` sub-agents.** This session has no `Agent` tool. Both checklists (2a–2f, 3a–3g) were worked through in full; nothing was skipped, but the independent-reviewer property the skill wants from two sub-agents was not obtained.
- **CD gate skipped — Lean mode.** No `creative-director` consultation on the design-holism findings; they are the reviewer's own.
- **`AskUserQuestion` not called** (owner pre-approved this run; nobody could answer). Every place the skill would have asked, the recommended option was taken and is listed under **Decisions taken** at the end.
- Pillars are defined (`game-concept.md` §Game Pillars, 4 pillars + 4 anti-pillars), so pillar drift (3f) had a reference.

---

## Part A — Verification of the collected cross-GDD items

Legend: **RESOLVED** = the current document already carries the change (where, how). **OPEN** = still needed; the finding id in Part B carries the file, section, current text and replacement text. **HOUSEKEEPING** = the fix landed but a sibling's Open Questions / wording row still claims it is open (listed once in C-30).

| # | Item (source review) | Status | Evidence |
|---|---|---|---|
| V-01 | match-rules adopt RNG F4 stream API names / stream handles (rng) | **OPEN** → C-05 | match-rules Interactions L585 still `shuffle(list)`, `pick(list)`, `range(n)`; Cross-References L1111 "shuffle/pick". `MatchConfig.seed` itself is gone (Dependencies L959 passes `rng_match`/`rng_ai`) |
| V-02 | DD-T03 stream wording (rng) | RESOLVED | design-decisions L59: `run`, `match_<floor>`, `draft_<floor>`, `ai_<floor>` |
| V-03 | run-ui event envelope must include `turn`, `cause_seq` (rng) | **OPEN** → C-08 | run-ui Interactions L270 and Cross-References L641 still `{seq, type, payload}` |
| V-04 | boss-ai draw-count ACs: one parent draw per fork label (rng rule 5) | **OPEN** → C-14 | boss-ai C9 L233 "tie-breaks are the only live `ai_<floor>` draws; forecasts and sandboxes use forks" and A5 L762 contradict rng rule 5 / AC ("`fork("x")` … parent's `draws` rose by exactly 1") |
| V-05 | match-rules, boss-ai, match-ui cite diagnostic rule 12a (rng OQ 7) | **OPEN (low)** → C-30 | match-ui L176 fine; match-rules OQ L1296 still "Open"; boss-ai L235 "same channel as `command_rejected`", Cross-Ref L736 "diagnostic channel" — no 12a citation |
| V-06 | registry `keep_match_logs` (optional) | not done; **Info** | optional per the review; no registry entry; no GDD disagrees on the value |
| V-07 | run-ui `synergy_tags[]` → `tags` (card-database, treasures R-19) | RESOLVED | run-ui L175 "not a `synergy_tags` field"; OQ L705 resolved. Treasures R-19 and card-database OQ L638 are now housekeeping |
| V-08 | match-rules Dependencies claims a stored `targeting` field (card-database) | **OPEN** → C-04 | match-rules L955 `targeting {mode: none\|optional\|required, filter}`; Cross-Refs L1109 `targeting`, L1112 `targeting.mode`; card-database Cross-Refs L535 "no stored `targeting` field" |
| V-09 | match-ui / boss-ai loader wording → `config("match_ui")` / `config("ai_profiles")` | match-ui RESOLVED (Tuning Knobs L624–626); boss-ai **OPEN (low)** → C-15 | boss-ai Interactions L318 and Dependencies L608 "Boss AI supplies … the `ai_profiles.json` loader (new data file, DD-T01 addition — Open Questions)" |
| V-10 | registry `data_version` constant (card-database) | RESOLVED | entities.yaml L1852–1864 |
| V-11 | card-database `min_bundle_pool` warning → cite `bundle_pool_min` | **NOT VERIFIED** (advisory) | card-database Formulas "Bundle pool size" not re-read in this pass; AC L607 asserts a hard floor of 3; advisory only |
| V-12 | registry `unlock_keys_v1` keys (meta) | RESOLVED | entities.yaml L662 |
| V-13 | treasures confirm `bosses_defeated_16` = cumulative | RESOLVED | treasures R-14 L848: `boss_defeated(any) ≥ 16`; meta OQ L853(a) can close |
| V-14 | treasures rename `unlock_earned` → `unlock_granted` | **OPEN** → C-19 | treasures States L323 `unlock_earned` |
| V-15 | one universal treasure locked on `runs_won ≥ 1` | **OPEN (design)** → D-03 | nothing changed; no any-hero treasure milestone exists |
| V-16 | run-ui `anim_speed` labels vs Match UI enum | superseded by **DD-X07** (labels win) → C-01 | match-ui F3 L459 / Tuning L631 / Core Rule 4 L193 use `1.0, 1.5, 2.0, instant`; meta M9 L298 stores that enum |
| V-17 | meta M9 add `anim_speed`, `text_scale`, `high_contrast_states`, `reduce_motion` | PARTIAL → **OPEN** C-01 | M9 L297–304 has `anim_speed`, `high_contrast_states`; lacks `text_scale`, `reduce_motion`, `action_delay_ms` (DD-X07 lists all three) |
| V-18 | match-rules C3 `MatchConfig.seed` vs streams (run-structure) | RESOLVED | match-rules Dependencies L959; run-structure OQ L943 is housekeeping |
| V-19 | rng: `treasure_granted` owner → Run Structure | RESOLVED | rng catalogue L173 |
| V-20 | rng: `run_ended.result` `death` → `defeat` | **OPEN** → C-09 | rng L176 `result (victory/death/abandoned)` |
| V-21 | rng rule 18 log folder keyed by `run_id` | RESOLVED | rng L190–193 |
| V-22 | heroes/run-ui `start_run`/`HERO_LOCKED` → `new_run`/`E_HERO_LOCKED` | heroes RESOLVED (L232, L409, L519); run-ui **OPEN (low)** → C-30 | run-ui uses `start_run` as a UI *intent* mapped to `new_run` (U2, S7 L244) — acceptable layering; its Cross-Ref L643 still cites `HERO_LOCKED`; run-structure L408 and OQ L942 still describe heroes as unfixed |
| V-23 | treasures T6 cites superseded `draft_state.offered_treasure_ids` | T6 RESOLVED (L187 "superseded"); States **OPEN (low)** → C-30 | treasures States L326 "In `draft_state.offered_treasure_ids`" |
| V-24 | run-structure add `suspend()` between matches (run-ui) | **OPEN** → C-12 | run-structure has only `new_run, begin_match, draft_pick, abandon, resume, return_to_menu` (L75, L412); `return_to_menu` terminal-only (T17 L387) |
| V-25 | registry `boss_sequence.output_range` [3,12] | RESOLVED | entities.yaml L946 |
| V-26 | reward-draft universal = `"universal" ∈ tags` | RESOLVED | reward-draft F2 L322 |
| V-27 | unify unlock-state interface on meta M1.3 names | PARTIAL → **OPEN** C-10 | meta M1.3 / Interactions L372 / Dependencies L637: `unlocked_keys()`, `is_treasure_unlocked(id)` at `init_run`; treasures uses `unlocked_keys` ✓; reward-draft still `unlocked_ids("treasure")` (L247, L550, L642) and still says Meta reads "at `offer()` time" |
| V-28 | R-1 permanent `add_mana` at match start (Hollow Crown) | **OPEN — Blocking** → C-02 | match-rules C5 L233–235, F4 L728, AC-06 L1149–1150 vs treasures AC-15 L808 |
| V-29 | systems-index Content row 10 treasures; Treasures Depends On + Match Rules, Heroes | RESOLVED | systems-index L85, L77 |
| V-30 | registry `treasure_offers_per_run` [6,9] | RESOLVED | entities.yaml L1177 |
| V-31 | event-name split: C15 wins everywhere (DD-X04) | rng RESOLVED (catalogue L136–167 realigned); match-ui **OPEN** → C-07 | match-ui U3 L152, L155, L162, L168 still carry `/ mulligan_completed`, `/ mana_changed`, `/ weapon_broken`, `/ healing_applied` aliases; match-rules OQ L1292 and card-effects OQ L1379 housekeeping |
| V-32 | DD-M11 wording | RESOLVED | design-decisions L24; match-rules OQ L1293 housekeeping |
| V-33 | heroes `INSUFFICIENT_MANA` → `NOT_ENOUGH_MANA` | RESOLVED | no match in heroes.md |
| V-34 | systems-index rows 6, 9, 13 add Match Rules | RESOLVED | systems-index L74, L77, L81 |
| V-35 | card-effects R-3 tag filter on board, R-10 observers, counters in snapshot | RESOLVED (card-effects); content OQs L856–858 and treasures R-3/R-10 housekeeping → C-30 | card-effects review log; card-effects OQ L1390 says "Treasures to apply" |
| V-36 | boss-ai / `/balance-check` AC-13 target basis | **OPEN (design)** → D-07 | content OQ L859 vs boss-ai OQ L855 — two bases, none chosen |
| V-37 | heroes H-4/H-5 text for `war_quartermaster` / `war_cleave_through` | RESOLVED (heroes); content OQ L849 housekeeping | heroes review log |
| V-38 | `content_budgets.json` schema documented | **OPEN (low)** → C-24 | content L463, L537, L739 name the file; no key list / schema sketch |
| V-39 | content `war_iron_vanguard` `armour` tag → War starter `PLAN_MAX` 7 > 6 | **OPEN — Blocking** → C-03 | content L112 still tags `armour`; heroes F2 L295 scores War 6 on the premise the tag is gone; heroes OQ L611; the card is also in `bundle_war_armour_1` (content L390) under theme `armour` |
| V-40 | content `neutral_lantern_bearer` ★ but in no starter | **OPEN** → C-23 | content L205 ★; heroes L166 "sits in no launch starter" |
| V-41 | meta UI Requirements "acked … after 4 s" defer to Run UI F3 | **OPEN (low)** → C-20 | meta L687 |
| V-42 | systems-index Run UI row add Heroes, Boss AI, Treasures, Content | RESOLVED | systems-index L80 |
| V-43 | rng catalogue add `ai_intent_committed` and `amount` | RESOLVED | rng L165; boss-ai L319, L609, OQ L849 housekeeping |
| V-44 | systems-index Boss AI "priority-scripted" → utility-scored | RESOLVED (index L38); game-concept **OPEN (low)** → C-27 | game-concept L88 "AI priority script", L242 "priority-script AI" |
| V-45 | card-database says boss-ai "(planned)" | RESOLVED | no match in card-database.md |
| V-46 | match-rules boss-mulligan OQ can close | RESOLVED | match-rules OQ L1290 |
| V-47 | run-structure R5.3 `Offer{option_ids[], flags[]}` (DD-X05) | RESOLVED | run-structure Interactions L409; reward-draft OQ L707 housekeeping |
| V-48 | treasures F4/F1 rare-share re-fit (~26 %) | **OPEN (by design — first balance pass)**; wording → C-30 | treasures F4 heading L458 still "(contract — to be confirmed in reward-draft.md)", `w_rarity` L471 "per-slot" |
| V-49 | meta read unlock state at `init_run` not `offer()` | RESOLVED (meta L372, L637); reward-draft's claim that Meta says "at `offer()` time" is stale → C-10 | — |
| V-50 | run-ui Dependencies "exactly 3 ids and optional theme labels" | RESOLVED | run-ui Dependencies L492 "1–3 … `flags`"; OQ L705 resolved |
| V-51 | rng catalogue draft rows need `flags[]` and `option_index` (DD-X05) | **OPEN** → C-09 | rng L172 |
| V-52 | registry `bundle_pool_min` [4,27]; drop over-claimed `referenced_by` on `collectible_pool_size` / `hero_set_size` | range RESOLVED (L1103); referenced_by **OPEN (low)** → C-29 | entities.yaml L700, L1556 still list reward-draft.md |
| V-53 | heroes H-3 sketches (card-effects) | RESOLVED | heroes review log; heroes OQ L603 |
| V-54 | treasures close R-2/R-3/R-6/R-10/R-13 and `aura`-on-weapon | **OPEN (housekeeping)** → C-30 | treasures OQ L836–847, L856 all still "Open" |
| V-55 | match-rules confirm End-step expiry covers card-instance enchantments; enemy-side expiry; observer candidate order | **OPEN (design)** → C-16 | card-effects OQ L1381, L1382, L1391 unanswered; not re-verified against match-rules C4/C10 in this pass |
| V-56 | systems-index Card Effects dependents count | **OPEN** → C-25 | index L147 now says "nine dependents" for both Match Rules and Card Effects; the table lists 7 and 5 |
| V-57 | card-database CR-3 `HeroDef.unlock` | RESOLVED as string (L127–129); shape must become `{key, condition}` per DD-X01 → C-06 | heroes OQ L605 housekeeping |
| V-58 | registry `hero_*` `referenced_by` add reward-draft, match-ui, run-ui, treasures | **OPEN (low)** → C-29 | entities.yaml L72–76, L88–92, L104–108 |
| V-59 | boss-ai `intent_banner_s` 1.2 vs 0.3 | RESOLVED | boss-ai Tuning Knobs L642 `0.3 / 1.2` (`plan_changed_s`); match-ui OQ L895 housekeeping |
| V-60 | run-ui `anim_speed` labels; "action delay" slider not owned by match-ui | superseded by **DD-X07** → C-01 | Match UI must consume `action_delay_ms`; match-ui OQ L896 says it does not own it |
| V-61 | registry over-claimed `referenced_by` for match-ui | **OPEN (low)** → C-29 | entities.yaml L887, L1002, L1018, L1241, L1399, L1515 |
| V-62 | systems-index Match UI Depends On add Run UI, Meta Progression | RESOLVED | systems-index L79 |
| DD-X01 | `unlock: {key, condition}` on HeroDef/TreasureDef/BundleDef | heroes ✓ (L518), meta ✓; card-database and treasures **OPEN — Blocking** → C-06 | card-database L127, L149, L265, OQ L637; treasures T1 L89, R-17 L850 |
| DD-X02 | No forced hero; Run UI pre-selects War | run-ui ✓ (OQ L703), game-concept ✓ (L115); heroes and run-structure **OPEN** → C-11 | heroes H-2 L79–83, Interactions L248, Dependencies L430, OQ L610; run-structure Interactions L408, OQ L941 |
| DD-X03 | `telegraph_mode` consumed by Boss AI as `effective_mode = min(boss.intent_mode, setting)` | run-ui ✓ (L273, L498, L647); boss-ai, meta, match-ui **OPEN** → C-01 | boss-ai defines no setting (OQ L852 pre-writes the rule); meta withdraws Boss AI (L374, L640, M9 L301–304, OQ L854, Cross-Ref L717); match-ui OQ L897 |
| DD-X04 | C15 spelling authoritative; `choice_requested` ≠ `discover_offered` | rng ✓; match-ui U3 pairs the two correctly (L173) but keeps aliases → C-07 | — |
| DD-X05 | `Offer{option_ids[], flags[]}`; `offered_ids[]` only in DraftRecord | run-structure ✓, run-ui ✓, reward-draft ✓; rng catalogue **OPEN** → C-09 | rng L172 lacks `flags[]`, `option_index` |
| DD-X06 | `treasure_short_policy = fewer` ships; `reoffer` debug-only | reward-draft **OPEN** → C-13 | reward-draft Tuning Knobs L574 offers `reoffer` as a plain alternative; D8 not labelled |
| DD-X07 | Settings owned by Meta: `anim_speed` labels, `reduce_motion`, `text_scale`, `high_contrast_states`, `telegraph_mode`, `action_delay_ms`, `volume_*`, `fullscreen`, `keep_run_records` | run-ui ✓ (plus `language`); meta and match-ui **OPEN** → C-01 | see V-16, V-17, V-60 |

Counts: **RESOLVED 31 · OPEN 33 (of which 6 Blocking, 15 Warning, 12 low/housekeeping) · NOT VERIFIED 1 · Info 1.** OPEN by file (a finding may touch several): match-rules 5, match-ui 4, meta-progression 4, boss-ai 4, treasures 4, reward-draft 3, run-structure 3, card-database 2, content 4, rng-event-log 2, run-ui 2, heroes 2, card-effects 2, systems-index 2, game-concept 1, design-decisions 1, registry 2.

---

## Part B — Consistency Issues (Phase 2)

Every finding names the file, the section heading, the current text and the replacement text so it can be applied mechanically. Line numbers are as of this review.

### Blocking (must resolve before architecture begins)

🔴 **C-01 — Player settings record disagrees with DD-X07 and DD-X03 in three GDDs** (2b rule contradiction, 2d ownership)
Involved: `meta-progression.md`, `match-ui.md`, `boss-ai.md` (`run-ui.md` already matches).
Why blocking: the settings record is persisted (Meta M9) and read by three systems; architecture will freeze its schema. Today Meta stores Match UI's numeric enum, lacks three DD-X07 keys, and names no consumer for `telegraph_mode`; Match UI's F3 divides by a number that DD-X07 replaces with labels and ignores `action_delay_ms`; Boss AI has no `effective_mode`.
1. `meta-progression.md` §Detailed Design › **M9. Settings** (L297–304). Current: `anim_speed: 1.0 | 1.5 | 2.0 | "instant" (1.0) — Match UI's animation speed (… Match UI owns the enum — run-ui.md's instant|fast|normal labels map onto it …); high_contrast_states: bool (false) …; telegraph_mode: "full" | "brief" | "off" ("full") — the intent-banner verbosity Run UI lists as a settings key (**owner open**: …)`. Replace with: `anim_speed: "instant" | "fast" | "normal" ("normal") — DD-X07; Match UI and Run UI map the label to their own durations (match-ui F3, run-ui F2); reduce_motion: bool (false) — Match UI drops shake, hit-stop and lethal slow-down (match-ui Tuning Knobs); text_scale: 1.0 | 1.25 | 1.5 (1.0) — Run UI and Match UI typography (ui-code rule 7); high_contrast_states: bool (false) — art bible §4 alternate state set; telegraph_mode: "full" | "brief" | "off" ("full") — consumed by Boss AI as effective_mode = min(boss.intent_mode, telegraph_mode) (DD-X03); action_delay_ms: int 0..2000 (600) — Match UI boss-turn pacing override of Boss AI's presentation.action_delay_s (DD-X07, match-ui F4); keep_run_records: bool (true); language: "en"`.
2. `meta-progression.md` §Interactions row **Boss AI** (L374) and §Dependencies row **Boss AI** (L640). Current: `none at v1 … row kept so the earlier telegraph_mode attribution is visibly withdrawn` / `Withdrawn: boss-ai.md defines no player setting`. Replace both with: `Boss AI | downstream (setting) | Soft | reads settings.telegraph_mode via settings_changed and clamps its per-boss intent_mode to it (DD-X03, boss-ai C8.4 effective_mode)`.
3. `meta-progression.md` §Tuning Knobs row `profile_defaults (M9)` (L665). Current: `anim_speed 1.0, high_contrast_states false, telegraph full`. Replace with: `anim_speed normal, reduce_motion false, text_scale 1.0, high_contrast_states false, telegraph_mode full, action_delay_ms 600`.
4. `meta-progression.md` §Cross-References row `anim_speed enum …` (L716). Replace "`anim_speed` enum" with "`anim_speed` label set (DD-X07)". §Open Questions rows L854 (`telegraph_mode` owner) and L855 (`anim_speed` labels): mark **Resolved 2026-11-03 — DD-X03 / DD-X07**.
5. `match-ui.md` §Detailed Design › Core Rules rule 4 (L193). Current: `anim_speed ∈ {1.0, 1.5, 2.0} divides every base duration (F3); instant skips`. Replace with: `anim_speed ∈ {normal, fast} selects a divisor (normal 1.0, fast 2.0) applied to every base duration (F3); instant skips`.
6. `match-ui.md` §Formulas › **F3. Effective animation duration** (L454, L459). Current: `d_eff(step) = 0 if skipped or anim_speed = instant; else d_base(step) / anim_speed` and variable row `anim_speed | enum | 1.0, 1.5, 2.0, instant | settings (data file default 1.0)`. Replace with: `d_eff(step) = 0 if skipped or anim_speed = instant; else d_base(step) / SPEED_DIV[anim_speed]` and rows `anim_speed | enum | instant, fast, normal | Meta settings (DD-X07; default normal)` and `SPEED_DIV | table | normal 1.0, fast 2.0 | data file (match_ui.json)`. L466 "dropped entirely at `anim_speed ≥ 2.0`" → "dropped entirely at `anim_speed = fast`". L467 example "attack at 1.5× → 0.233 s" → "attack at `fast` → 0.175 s".
7. `match-ui.md` §Formulas › **F4. Boss-turn gap and compression** variable row `ai_action_delay_s` (L483). Current: `0.3–1.2 (0.6) | Boss AI data (presentation.action_delay_s) | Preferred gap between boss actions`. Replace with: `0.0–2.0 | settings.action_delay_ms / 1000 when the Meta setting is present (DD-X07), else Boss AI data presentation.action_delay_s (0.6) | Preferred gap between boss actions; the clamp floor MIN_ACTION_GAP_S still applies`.
8. `match-ui.md` §Tuning Knobs row `anim_speed (default)` (L631). Current: `1.0 | 1.0–2.0, instant | …`. Replace with: `normal | instant \| fast \| normal (DD-X07) | fast halves every d_base and drops impact extras; instant applies final states only | — | SPEED_DIV, F3`. §Interactions row **Meta Progression** (L388) and §Dependencies row **Meta Progression** (L618): append `, action_delay_ms, text_scale` to the key list and change "(this GDD's enum, meta-progression M9)" to "(label set per DD-X07)". §Open Questions L896 and L897: mark **Resolved 2026-11-03 — DD-X07 (labels; Match UI consumes action_delay_ms) / DD-X03 (Boss AI owns effective_mode; this GDD renders what Boss AI emits)**.
9. `boss-ai.md` §Detailed Design › **C8.4 Shown vs hidden** (L216–219). After the sentence defining `intent_mode` add: `A player setting telegraph_mode ∈ {full, brief, off} (Meta Progression M9, DD-X03) further restricts it: effective_mode = min(intent_mode, telegraph_mode) over the order full > class_only ≡ brief > hidden ≡ off; ai_intent_* events carry effective_mode, and Match UI renders exactly what is emitted. The default is full; off is the player's choice, never a boss's (Pillar 3).` §Dependencies: add row `Meta Progression | This depends on Meta Progression | Soft | settings.telegraph_mode via settings_changed (DD-X03); absent at MVP → full`. §Tuning Knobs: add row `telegraph_mode (player setting, Meta) | full | full \| brief \| off | — | brief hides amount/target; off hides the banner (player opt-in) | effective_mode, Match UI banner`. §Open Questions L852: mark **Resolved 2026-11-03 — DD-X03, rule added to C8.4**.
10. `systems-index.md` §Systems Enumeration row 5 Boss AI "Depends On": append `, Meta Progression`.

🔴 **C-02 — Hollow Crown needs a permanent crystal at match start that Match Rules' mana formula and AC-06 forbid** (2b floor/ceiling contradiction, 2f AC cross-check; Treasures R-1)
Involved: `match-rules.md` C5, F4, AC-06; `treasures.md` T8 row 1, AC-15, R-1.
Current: match-rules §Core Rules C5 (L233–235): `There is no Overload, no temporary crystal gain and no crystal destruction in v1; Card Effects may add operations gain_mana(n, temporary) later through the engine API add_mana, which clamps to MAX_MANA.`; F4 (L728): `mana_max(t) = min(t_side, MAX_MANA)`; AC-06 (L1149–1150): `mana_max is 10 for both and was min(turns_taken, 10) at every Start step (F4)`. Treasures AC-15 (L808): `Hollow Crown: WHEN match_started, THEN mana_changed{source_id: treasure_hollow_crown} precedes the first card_drawn; player turn 1 reads 2/2, turn 8 reads 9/9, turn 9 and 10 read 10/10`. These cannot both pass. Hollow Crown is an **MVP** treasure (registry `mvp: true`).
Replacement (match-rules is the owner; Treasures' reading is adopted):
- C5 bullet (L233–235) → `mana_current never exceeds mana_max and never drops below 0. There is no Overload and no crystal destruction in v1. add_mana(side, n, temporary=false) at on_match_start (hook table) raises that side's crystal_bonus permanently (Treasures R-1, Hollow Crown); temporary gain (temporary=true) is not used by v1 content. Both clamp to MAX_MANA.`
- C4 Start step 2 (L197) → `mana_max = min(turns_taken + crystal_bonus, MAX_MANA)` (replace the incremental `min(mana_max + 1, MAX_MANA)`), emitting `crystal_gained` when it rose.
- F4 (L728) → `mana_max(t) = min(t_side + crystal_bonus, MAX_MANA)` with a new variable row `crystal_bonus | int | 0–2 | state (set only by add_mana(…, temporary=false) hooks at on_match_start; 0 by default) | Permanent extra crystals (Treasures Hollow Crown)`; example: `with crystal_bonus 1 the player reads 2/2 on turn 1 and 10/10 from turn 9`.
- AC-06 (L1149–1150) → `… mana_max is 10 for both and was min(turns_taken + crystal_bonus, 10) at every Start step (F4); GIVEN crystal_bonus = 1 for the player (an on_match_start add_mana hook), THEN the player reads 2/2 on turn 1 and 10/10 from turn 9 while the boss is unchanged.`
- `PlayerState` C1 (L96): add `crystal_bonus` to the field list.
- Treasures: R-1 (L835) → **Resolved** once the above lands; Treasures AC-15 unchanged.

🔴 **C-03 — Content tags the War starter card `war_iron_vanguard` `armour`, which makes Heroes F2's plan-share validator fail MVP-0** (2f AC cross-check; Heroes OQ L611)
Involved: `content.md` CN-2 L112 and bundle `bundle_war_armour_1` L390; `heroes.md` F2 L295, OQ L611.
Current: content L112 `| war_iron_vanguard ★ | Iron Vanguard | M | 3 | 2/4 | taunt | Taunt. | kw | C | armour |`; heroes F2 "launch starters score War 6" (true only without the tag); heroes H-4 note L182–184 says the tag "pushes its starter over PLAN_MAX".
Complication: Card Database CR-5 stage 6 raises `E_TAG_MISMATCH` when a bundle card lacks the bundle's `theme`, and `war_iron_vanguard` sits in `bundle_war_armour_1` (theme `armour`). Dropping the tag alone breaks that bundle.
Replacement (decision taken — see Decisions): **Option B, raise the knob**: heroes §Formulas F2 row `PLAN_MIN / PLAN_MAX | int | 4 / 6` → `4 / 7`; §Tuning Knobs row `PLAN_MIN–PLAN_MAX (F2) | 4–6 | 3–8 |` → `4–7 | 3–8 |`; F2 output line → `launch starters score War 7, Decay 5, Knowledge 6`; OQ L611 → **Resolved 2026-11-03 — PLAN_MAX 7 (cross-review C-03); Content keeps the tag so bundle_war_armour_1 stays valid**; H-4 note L182–184: delete the "pushes its starter over PLAN_MAX" clause. Alternative A (design-preferred by Heroes, two Content edits): drop `armour` from L112 and replace `war_iron_vanguard` in `bundle_war_armour_1` with `war_shield_maiden` (L120, `armour`) — the orchestrator may choose A instead; both are mechanical.

🔴 **C-04 — Match Rules reads a Card Database `targeting {mode, filter}` field that does not exist** (2c stale reference to a non-existent field — Blocking by the skill's rule)
Involved: `match-rules.md` §Dependencies row Card Database (L955), §Cross-References rows L1109 and L1112; `card-database.md` Cross-References L535 and OQ L639; `card-effects.md` C1 rule 1 / OQ L1378.
Current (L955): `Reads card, hero, boss and weapon records by def_id: cost, type, attack, health, durability, keywords[], effect (opaque to this GDD), targeting {mode: none|optional|required, filter}.` Replace with: `Reads card, hero, boss and weapon records by def_id: cost, type, attack, health, durability, keywords[], effects[] (opaque to this GDD). Targeting is not a stored field: Card Effects derives targeting_spec(def_id) → {mode: none|optional|required, filter} from the effect's chosen selector (card-effects C1 rule 1) and this GDD calls it during C6 validation.` L1109: replace `(cost, type, stats, keywords, targeting)` with `(cost, type, stats, keywords, effects[])`. L1112: `Resolver contract; targeting.mode; ChoiceRequest for Discover` → `Resolver contract; targeting_spec(def_id) (derived, not stored); ChoiceRequest for Discover`. Then card-database OQ L639 and card-effects OQ L1378 → **Resolved**.

🔴 **C-05 — Match Rules names an RNG API (`pick(list)`, `range(n)`) that RNG & Event Log does not define** (2c stale reference; RNG OQ 8)
Involved: `match-rules.md` §Interactions row RNG & Event Log (L585), §Cross-References L1111; `rng-event-log.md` F4 defines `randi_range(lo, hi)`, `shuffle(list)`, `weighted_pick(weights[])`, `fork(label)`.
Current (L585): `The match stream (shuffle(list), pick(list), range(n)); the append-only log`. Replace with: `The injected match_<floor> stream handle from MatchConfig (rng-event-log F4: randi_range(lo, hi), shuffle(list), weighted_pick(weights[]); no forks in v1 — card-effects C6.9); the append-only log with cause_seq`. L1111: `match stream shuffle/pick; log.append with seq` → `match_<floor> stream randi_range / shuffle (F4); log.append with seq, turn, cause_seq (rules 11–14)`. Then rng OQ 8 (L586) and run-structure OQ L943 → **Resolved**.

🔴 **C-06 — `unlock` is still a string in Card Database CR-3 and Treasures T1; DD-X01 decided the `{key, condition}` object** (2b contradiction with a decided row)
Involved: `card-database.md` CR-3 HeroDef (L127–129), TreasureDef (L149), Interactions row Meta Progression (L265), OQ L637; `treasures.md` T1 row `unlock` (L89), OQ R-17 (L850); `heroes.md` and `meta-progression.md` already carry the object.
Replacement: card-database L127–129 and L149: `unlock string or null (an unlock condition key …)` → `unlock: {key: string, condition: object} or null (meta-progression M2.1 grammar; null = always unlocked; the key must be unique across heroes, treasures and bundles; validated by the injected Meta Progression validator) — DD-X01`. Add the same field to `BundleDef` in CR-3 with the note `null for every v1 bundle`. L265: replace `the string-vs-object shape of unlock is an open owner question (Open Questions)` with `unlock is the {key, condition} object (DD-X01)`. OQ L637 → **Resolved 2026-11-03 — DD-X01: object form on HeroDef, TreasureDef, BundleDef**. Treasures L89: `string or null | Meta Progression | Unlock-condition key; null = available from the first run. This GDD names keys; Meta Progression defines and validates them` → `{key, condition} or null (DD-X01) | Meta Progression | T8's Unlock column is the key; the condition object follows meta-progression M2.2; null = available from the first run`. R-17 L850 → **Resolved — DD-X01**. Registry `items.treasure_*.unlock` attributes may stay as the key string (they record the key, not the field shape).

### Warnings (should resolve, but won't block)

⚠️ **C-07 — Match UI U3 still carries the losing event-name aliases** (DD-X04)
`match-ui.md` §Detailed Design › Core Rules › U3 event table L152 `mulligan_resolved / mulligan_completed`, L155 `mana_refilled / mana_changed`, L162 `weapon_destroyed / weapon_broken`, L168 `healed / healing_applied` → delete each `/ <alias>`; place the five 2026-11-03 primitive events (`keyword_removed`, `card_added_to_deck`, `weapon_durability_changed` — already present —, `hero_power_refreshed`, `card_discarded`) in the table (`hero_power_refreshed` → power button re-lights 0.15 s; `card_discarded` → card flies to graveyard 0.25 s; `keyword_removed` → badge drop 0.15 s; `card_added_to_deck` → deck count tick 0.15 s). OQ L893 → **Resolved**. Also close match-rules OQ L1292 and card-effects OQ L1379 as **Resolved — DD-X04**.

⚠️ **C-08 — Run UI cites the pre-revision event envelope**
`run-ui.md` §Interactions row RNG & Event Log (L270) and §Cross-References (L641): `{seq, type, payload}` → `{seq, turn, type, payload, cause_seq}` (rng-event-log rule 11; `cause_seq` groups the summary's lines as Match UI does).

⚠️ **C-09 — RNG catalogue rows lag DD-X05 and Run Structure's `run_ended` enum**
`rng-event-log.md` §D catalogue L172: `draft_offered / draft_picked | Reward Draft | floor, kind (bundle/treasure), option_ids[] / floor, kind, picked_id, card_ids_added[]` → `… option_ids[] (1–3, id-sorted), flags[] (short | pity_forced | universal_forced | coverage) / floor, kind, picked_id, option_index, card_ids_added[]` (reward-draft D11, DD-X05). L176: `result (victory/death/abandoned)` → `result (victory/defeat/abandoned), abandon_reason (player/system) when abandoned` (run-structure R6, meta-progression F2). Interactions L227: move `treasure_granted` from the Reward Draft row to the Run Structure row (L226) to match catalogue L173.

⚠️ **C-10 — Reward Draft still names the unlock-state call `unlocked_ids("treasure")` and misquotes Meta's timing** (2c; Treasures R-18)
`reward-draft.md` §Interactions row Meta Progression (L247): `unlocked_ids("treasure") → id[] (Meta Progression's Interactions row; read once at init_run, never at offer() — Meta's row says "at offer() time", an amendment flagged in Open Questions; MVP: everything unlocked)` → `unlocked_keys() → Set[string] (meta-progression M1.3) read once at init_run; a treasure is in the pool iff unlock == null or unlock.key ∈ unlocked_keys() (treasures T6 predicate); Meta confirms init_run timing (its Interactions and Dependencies rows); MVP: everything unlocked`. §Dependencies row Meta Progression (L550): same substitution, drop the "amendment" clause. §Cross-References L642: `unlocked_ids("treasure") at init_run` → `unlocked_keys() at init_run`. OQ L708 → **Resolved**. Treasures R-18 (L851) → **Resolved — meta M1.3 `unlocked_keys()`; `is_treasure_unlocked(id)` is the membership helper**.

⚠️ **C-11 — Heroes and Run Structure still treat "first run forces War" as unowned** (DD-X02)
`heroes.md` H-2 (L79–83): replace the paragraph `The concept's onboarding note ("the first run forces War") is not yet owned by any GDD: … this GDD does not restate it.` with `No hero is forced on any run (DD-X02): all three launch heroes are unlock: null and Run UI pre-selects War on a fresh profile (run-ui U7).` §Interactions row Run Structure (L248): delete `"First run forces War" is unowned (Open Questions)`. §Dependencies row Run Structure (L430): delete `; "first run forces War" not yet placed (Open Questions)`. OQ L610 → **Resolved 2026-11-03 — DD-X02 (pre-select, Run UI)**. `run-structure.md` §Interactions row Heroes (L408): replace the `Open: …` clause with `heroes.md now uses new_run / E_HERO_LOCKED; run-ui.md's start_run is a UI intent that issues new_run (its U2 map). No first-run hero rule exists (DD-X02).` OQ L941 → **Resolved — DD-X02**; OQ L942 → **Resolved — heroes adopted the names; Run UI's intent name is a UI-layer alias**.

⚠️ **C-12 — No Run Structure command for "Quit to menu" between matches** (Run UI OQ L701)
`run-structure.md` §Core Rules R-command list (L75) and §States T-table: add command `suspend` — legal in `pre_match` and `post_match_reward` (and `hero_select`), rejected `E_PHASE` elsewhere; effect: drops the in-memory run without an event or a save (the last S-save is the resumable state), state → Menu; the saved run reappears as Continue (R8). Add transition row `T21 | pre_match, post_match_reward | suspend | — | none | none | Menu`. §Interactions row Run UI (L412): command list becomes seven (`new_run, begin_match, draft_pick, abandon, resume, suspend, return_to_menu`). AC: `GIVEN post_match_reward after save S3, WHEN suspend then resume, THEN the run re-enters the same draft with the identical offer (R8.2)`. `run-ui.md` OQ L701 → **Resolved**; its Dependencies row "the six commands" → "seven".

⚠️ **C-13 — `treasure_short_policy = reoffer` is presented as a shipping option** (DD-X06)
`reward-draft.md` §Tuning Knobs row `treasure_short_policy` (L574): `fewer | fewer \| reoffer | reoffer keeps three options but shows a treasure the player already declined | fewer is honest about a thin pool` → `fewer | fewer only in shipping builds; reoffer is debug-only (DD-X06 — it violates DD-R05's no-repeat rule) | — | —`. §Detailed Design D8: add the sentence `reoffer is a debug fixture value and is rejected by the config validator in release builds (E_CONFIG).`

⚠️ **C-14 — Boss AI's `ai_<floor>` draw accounting ignores the one-draw cost of each fork** (RNG rule 5; 2e)
`boss-ai.md` §Core Rules C9 (L233): `These are the only live ai_<floor> draws; forecasts and sandboxes use forks.` → `These, plus exactly one parent draw per new fork label (rng-event-log rule 5: fork("sim_<turn>") / fork("forecast_<turn>") each consume one ai_<floor> draw the first time the label is created), are the only live ai_<floor> draws; the sandboxes themselves draw from their forks.` A5 (L762–763) → `… the live match_<floor> stream's draws counter is unchanged by the planner, and the ai_<floor> counter rises by (tie-set draws + number of new fork labels this turn).` A3 (not re-read here) should assert the same arithmetic.

⚠️ **C-15 — Boss AI still says it "supplies the `ai_profiles.json` loader"** (card-database single-parser rule)
`boss-ai.md` §Interactions row Card Database (L318): `The ai_profile validator (CR-5 stage 7) and the ai_profiles.json loader (new data file, DD-T01 addition — Open Questions)` → `The ai_profile validator (CR-5 stage 7) and the config validator for ai_profiles.json; the file is loaded by Card Database and read once via config("ai_profiles") (CR-1; DD-T01 lists it)`. §Dependencies row Card Database (L608): `Boss AI supplies the ai_profile validator (CR-5 stage 7) and the ai_profiles.json loader` → `… and the ai_profiles.json config validator; reads config("ai_profiles")`.

⚠️ **C-16 — Three Card Effects questions to Match Rules remain unanswered** (2b; may change a rule Card Effects depends on)
`match-rules.md` must state, in C4 End step 5 / C10: (a) whether `until_end_of_turn` enchantments on **card instances in hand or deck** owned by S expire at S's End step (card-effects rows 25, 41 — Insight's tax depends on it); (b) whether an `until_end_of_turn` enchantment applied to an enemy-controlled recipient expires at the recipient's controller's End step (current reading) or the applier's; (c) one observer candidate order (C4 "active side first for turn triggers" vs C10/Interactions "player side first always"). Proposed answers (take unless Match Rules objects): (a) yes — End step 5 removes `until_end_of_turn` enchantments on every entity **owned by S, including card instances in S's hand and deck**; (b) recipient's controller's End step (keep; document as intended, one turn later than Hearthstone); (c) player side first always, including turn triggers — amend C4 to match C10. Then card-effects OQ L1381, L1382, L1391 → Resolved.

⚠️ **C-17 — Who constructs and drives Boss AI is stated three ways** (2a ownership)
`boss-ai.md` Dependencies L610: "Run Structure constructs BossAI from MatchConfig.boss.ai_id … drives forecast / play_turn / choose"; `run-structure.md` Interactions L413: "the run never talks to the AI directly"; `match-ui.md` Interactions L386: "the match driver that calls Boss AI is Run Structure's … wrapped by MatchController". Proposed: `run-structure.md` §Interactions row Boss AI (L413) → `indirect | — | ai_id and rng_ai inside MatchConfig | Run Structure owns the match driver interface (begin_match constructs the engine, the BossAI(ai_id, rng_ai, config("ai_profiles")) and the driver that calls forecast / play_turn / choose at the Match Rules phase transitions); the driver is rules-side code (DD-T02), wrapped but not owned by Match UI's MatchController`. Match UI L386 then reads correctly; Boss AI L610 unchanged.

⚠️ **C-18 — Match Rules' `MAX_ATTACKS_CAP` rationale contradicts Treasures F3** (2d)
`match-rules.md` §Tuning Knobs row `MAX_ATTACKS_CAP` (L985): `Lets stacked modify_max_attacks hooks (Twin Grip on a Windfury weapon) grant more swings; … At 2 a hook can never exceed Windfury — Twin Grip plus Windfury collapses to 2` → `Bounds any future delta-style modify_max_attacks hook; Twin Grip is set 2 (treasures F3) so Twin Grip plus Windfury is 2 regardless of the cap | At 2 no hook can ever exceed Windfury`.

⚠️ **C-19 — Treasures names the grant event `unlock_earned`**
`treasures.md` §States row Locked (L323): `Meta Progression grants the key (unlock_earned)` → `Meta Progression grants the key (unlock_granted, meta-progression M3.6)`. Meta OQ L856 → Resolved.

⚠️ **C-20 — Meta's toast wording overrides Run UI's F3**
`meta-progression.md` §UI Requirements row Victory / defeat summary additions (L687): `(one per key, acked when dismissed or after 4 s)` → `(one per key; Run UI acks each on show and owns the visible duration, run-ui F3 2–6 s)`. Run UI OQ L702 → Resolved.

⚠️ **C-21 — `assets/data/profile.json` collides with `user://profile.json` and is missing from DD-T01**
Decision taken: rename. `meta-progression.md` M9 (L305) and §Tuning Knobs intro (L645): `assets/data/profile.json` → `assets/data/profile_defaults.json`; `design/design-decisions.md` DD-T01 file list: add `profile_defaults.json`; `card-database.md` CR-1 config-file list: add `profile_defaults` (owner Meta Progression, served by `config("profile_defaults")`). Meta OQ L857 → Resolved.

⚠️ **C-22 — Card Effects' Dependencies still call five designed GDDs "undesigned" and its primitive requests "provisional"**
`card-effects.md` §Dependencies intro (L1021): `Heroes, Treasures, Boss AI, Match UI and Content are undesigned, so their rows are the contract this GDD proposes and they confirm.` → `Heroes, Treasures, Boss AI, Match UI and Content are Designed (2026-11-03) and each confirms its row below.` §Interactions L659–662: `Primitive requests to Match Rules (provisional; the ops stay validator-blocked until the match-rules GDD adds them …)` → `Primitives added to Match Rules' API on 2026-11-03 for this GDD: remove_keyword, add_card_to_deck, modify_durability, refresh_hero_power, discard (match-rules Interactions); their ops are no longer validator-blocked.` §Tuning Knobs L1039–1040: delete `(… a new data file, flagged for DD-T01 in Open Questions)`. OQ L1377, L1383 → Resolved; L1388 → see C-25.

⚠️ **C-23 — Content stars `neutral_lantern_bearer` as a starter card; no launch starter contains it**
`content.md` CN-2 L205: remove the ★ from `neutral_lantern_bearer` (heroes H-4 L166, L170 list the 7 shared starter neutrals without it), or — if the ★ marks "MVP-0 batch" rather than "starter" — say so in the table legend. Decision taken: remove the ★.

⚠️ **C-24 — `content_budgets.json` has no documented schema**
`content.md` §Detailed Design CN-6 (after L463): add a key list: `{schema_version, curve: {avg_min, avg_max, bucket[k], bucket_tol, early_max, mid_max}, budget: {tol: {common, rare, legendary}, keyword_tax{}, effect_points{}}, pressure: {band[1..3], tol, passive_cap[1..3]}, coverage: {kw_min, bundle_coverage_min}, text_max_chars, pick_rate: {min, max, min_sample}, time: {t_card, t_boss_card, t_boss, t_bundle, t_balance}, neutral_set_size}` with a note that hero-set rows live in `heroes_balance.json`.

⚠️ **C-25 — Systems index bottleneck count and layer map are stale**
`systems-index.md` §Dependency Map (L147): `Match Rules (nine dependents) and Card Effects (nine dependents)` → `Match Rules (seven dependents in the table: Card Effects, Boss AI, Heroes, Run Structure, Treasures, Match UI, Content) and Card Effects (five: Boss AI, Heroes, Treasures, Match UI, Content)`. Regenerate the layer lists L118–141 from the enumeration table (e.g. Boss AI also depends on Card Database and RNG; Heroes on Match Rules; Treasures on Card Database, RNG, Match Rules, Heroes; Run Structure on Card Database, Meta Progression; Match UI on all ten table entries). Fix §Recommended Design Order row 13 (L169), which is a pasted enumeration row, to `| 13 | Content | MVP → Alpha | Feature | game-designer, systems-designer, economy-designer | L |`. §Progress Tracker L202–203 `MVP systems designed 0/12`, `Vertical Slice 0/1` → `12/12`, `1/1` (all In Review). Card-effects OQ L1388 → Resolved.

⚠️ **C-26 — Treasures still marks its Reward Draft / Meta contracts "to be confirmed" and reads the unlock set "at offer time"**
`treasures.md` §Interactions rows Reward Draft (L349) and Meta Progression (L350), §Dependencies rows (L623, L624): delete `(**contract — to be confirmed in …**)`; replace `unlocked_keys (set of strings) at offer time` with `unlocked_keys() read once at init_run (reward-draft D3, meta M3.7)`. §Formulas F4 heading (L458): drop `(contract — to be confirmed in reward-draft.md)`; row `w_rarity` (L471): `Per-slot rarity weight` → `Per-item rarity weight (reward-draft F2); p_seen is an approximation until re-fitted`. §Tuning Knobs intro (L640): `MAX_ATTACKS_CAP once R-5 lands` → `MAX_ATTACKS_CAP = 4`; F2 row `clamp_h` (L433): delete `(**R-4**: not yet stated in match-rules)` and `(**R-5**)` markers (both landed in match-rules Interactions). Close R-2, R-3, R-4, R-5, R-6, R-7, R-9, R-10, R-11, R-13, R-14, R-16, R-19, R-20 and the `aura`-on-weapon row as **Resolved 2026-11-03** (each is answered in card-effects C1–C9, match-rules Interactions, card-database CR-3, rng L173, run-structure R4, meta M10, reward-draft F2, run-ui L175, content CN-5 respectively).

⚠️ **C-27 — Game concept carries four lines the GDDs have overtaken**
`game-concept.md`: MVP Definition item 5 (L272) `bundles and 8 treasures` and Scope Tiers MVP row (L284) `8 treasures` → `10 treasures (DD-H06)`; Core Mechanics 3 (L88) `an AI priority script` → `a utility-scored AI with telegraphed intents`; Technical Risks (L242) `a priority-script AI may play some boss decks badly` → `a utility-scored AI may still misplay drafted decks; mitigated by the AI-vs-AI harness`; Open Questions (L254–258): mark treasure cadence **resolved — DD-R05 (1, 3, 5)**, boss count per band **resolved — DD-R02 (6/6/4)**, mulligan **resolved — DD-M05**.

⚠️ **C-28 — Reward Draft still "requests" two things that already exist**
`reward-draft.md` §Dependencies row Card Database (L546): delete `**Requests**: TreasureDef.tags field; reward_draft.json in CR-1/DD-T01.` (CR-3 has `tags`; DD-T01 lists the file). §Interactions L257–259: delete `… requested of Card Database CR-3 as Treasures R-7; until the CR-3 edit lands the loader cannot validate it, and a record without tags is treated as [universal] …`. OQ L704, L711 → Resolved. Also reconcile the universal floor: Interactions L269 says `n_universal ≥ treasure_drafts_per_run (3)`, F6 L402 "recommended ≥ 5", Dependencies L552 `n_universal ≥ 5` — state one rule: `hard floor 3 (one per draft), recommended 7 (= 3K − 2, slot guaranteed)`.

⚠️ **C-29 — Registry `referenced_by` hygiene** (`design/registry/entities.yaml`)
Add `design/gdd/reward-draft.md`, `design/gdd/match-ui.md`, `design/gdd/run-ui.md`, `design/gdd/treasures.md` to `hero_war`, `hero_decay`, `hero_knowledge` (L72–76, L88–92, L104–108). Remove `design/gdd/match-ui.md` from `action_score` (L887), `spell_damage_requested` (L1002), `discover_pool` (L1018), `transition_duration` (L1241), `player_starting_health` (L1399), `ai_planner_target_ms` (L1515). Remove `design/gdd/reward-draft.md` from `collectible_pool_size` (L700) and `hero_set_size` (L1556). Remove `design/gdd/run-structure.md` from the 16 `boss_*` entities, `hero_decay`, `hero_knowledge` and `stream_seed` (run-structure review: the document never names them) — or add the names to run-structure; removal is the mechanical choice.

⚠️ **C-30 — Housekeeping: Open-Questions rows whose answer already landed elsewhere**
Mark **Resolved 2026-11-03 (cross-review)** with the pointer: match-rules OQ L1293 (DD-M11), L1296 (rng rule 12a — cite it in C15's diagnostics sentence L512); boss-ai L319/L609 "proposed additions / four new types" → "catalogued (rng §D)", OQ L849, Cross-Ref L736 "diagnostic channel" → "rule 12a"; card-database OQ L638 (Run UI renamed), L636 (match-ui done; boss-ai see C-15); heroes OQ L604 (`refresh_hero_power` exists), L605 (CR-3 has `HeroDef.unlock`); run-structure OQ L943, L945 (catalogue fixed; `defeat` see C-09), L947 (CR-3 has `BossDef.tags`), L949 (rule 18 fixed), L952 (T6 fixed; States L326 → `drafts[] (reward-draft D7)`); run-ui Cross-Ref L643 `HERO_LOCKED` → `E_HERO_LOCKED`; match-ui OQ L895 (0.3 / `plan_changed_s`), Cross-Refs L799 `(undesigned)` → `(Designed)`, L801 `(in progress)` → `(Designed)`; content OQ L848 (CR-3 has `BossDef.tags`, `passive_text`), L849, L850 (Insight text settled: the tax), L856–858 (card-effects C3 `tag` on board, C9 observers, C6.5 counters in snapshot); content Interactions L527–528 `(concurrent)` labels and Dependencies L729 "Treasures GDD must list Content" / L732 "Reward Draft's Dependencies must list Content" (both already do); meta OQ L850 (DD-X01), L853(a), L858 (run-structure R6 sets `floor_reached` on victory), L859 (rule 18); reward-draft OQ L703, L707; treasures see C-26.

---

## Game Design Issues (Phase 3)

Pillar map (3f): every system's Player Fantasy (or Overview, for the three without one) maps to at least one pillar — Card Database/RNG/Card Effects/Match Rules → P4; Boss AI/Content → P2, P3; Heroes/Reward Draft/Treasures/Content → P1; Run Structure/Run UI/Match UI → P3; Meta Progression → Retention (Achievers) and anti-pillar "no collection" (its fantasy is explicitly "a ledger, not an inventory"). No anti-pillar violation found: no PvP, no collection or pack economy, no constructed builder (starters fixed, no removal), no narrative branching. Player fantasies (3g) are coherent — "improvised mastery" and "legibility" recur in all thirteen without conflict.

### Blocking
None.

### Warnings

⚠️ **D-01 — Universal economy treasures are the generically-good pick Pillar 1 warns about** (3c)
Hollow Crown (5.4) and Vanguard's Banner (5.0) sit at the top of the Rare band, carry no plan tag, and are eligible for the guaranteed universal slot in every treasure draft; Treasures' own fantasy wants "roughly half the pool plan-dependent", but the two strongest items are the plan-free ones. Risk: the floor-1 treasure pick is solved ("take Crown if offered"). Mitigation already designed: reward-draft's `/balance-check` rule (pick rate > 60 % over ≥ 30 offers). Recommendation: keep, but add to `/balance-check`'s first pass a per-treasure win-rate delta and be ready to move Crown to `ETA_CRYSTAL 0.5` (4.5) or give it a drawback. No GDD change now.

⚠️ **D-02 — Affinity + pity make late drafts rails; Discovery (aesthetic #2) depends on the coverage slot alone** (3c, Pillar 1)
At `AFFINITY_CAP` 8 an on-plan bundle weighs 3.0× an off-plan one; by floor 5+ the two free slots are almost always on-plan and only the coverage slot offers a second plan. That delivers "the game knows my deck" (reward-draft fantasy) at the cost of the off-plan temptation the same fantasy wants to protect. Recommendation: `/balance-check` should report `top_tag_share` and the share of drafts whose only off-plan option is the coverage slot; if the latter exceeds ~70 % from floor 5, lower `AFFINITY_CAP` to 6 (the knob's safe range covers it). No GDD change now.

⚠️ **D-03 — The v1 Curiosity hook starves: four locked treasures, none reachable on a War run** (3a/3d)
Meta Progression's v1 unlockables are four treasures (`hero_decay_first_win`, `hero_decay_floor_5`, `hero_knowledge_first_win`, `bosses_defeated_16`); heroes are post-v1 and no bundle locks. A player who mains War (the pre-selected hero) sees nothing unlock until 16 boss kills (≈ 5 median runs), and the concept promises milestones for "first win with each hero, bosses defeated, floors reached". Recommendation (meta OQ L853b): Treasures locks one more universal treasure on `runs_won ≥ 1` (e.g. Living Armory moves to `runs_won_any_1`, Stampede Horn to `bosses_defeated_16`) and one on `floor_reached ≥ 5` for any hero; Content CN-5 and meta M10 follow. Content choice — flagged, not applied.

⚠️ **D-04 — Band-3 `intent_mode = hidden` contradicts Pillar 3's own design test** (3f)
Boss AI C8.4 allows `hidden` ("no banner; band 3 only") as a designer-imposed mode; Pillar 3's test says "debating a hidden boss mechanic vs a telegraphed one, this pillar picks telegraphed". Recommendation: cap band 3 at `class_only`, reserve `hidden` for a boss whose passive text itself announces concealment (Stealth/fog theme), and say so in boss-ai C8.4 and content B2. `telegraph_mode = off` is the player's opt-in and is fine.

⚠️ **D-05 — "Done" is far away at the designed curve** (3e)
Run Structure F6 gives `p_victory ≈ 3.3 %` for the median player; the concept's long-term goal is "every hero has beaten the gauntlet" and "~8 hours to see most content". At 22 min per median run that is ~11 h per hero before skill growth. Not a contradiction (Challenge is aesthetic #1 and skill rises), but the first playtest should measure floor-4/5 win rates against the 0.70/0.65 targets before Content tunes to them; if the median audience sits lower, the 0.90 floor-1 onboarding promise is the one to protect, not `p_victory`.

⚠️ **D-06 — Every MVP run has the same four bosses** (3e; run-structure OQ L950)
MVP boss pool 2/1/1 equals `band_split [2, 1, 1]`, so only the band-1 order varies. The MVP hypothesis is "players want to immediately replay a run"; with no boss variety, Discovery is absent from the test and the result will under-read. Recommendation: author one spare band-1 boss in MVP-1 (`+1 boss ≈ 2.5 h` by content F6). Content plan change — flagged.

⚠️ **D-07 — Two incompatible bases for the boss-difficulty sim** (3e; V-36)
Content AC-13 compares the hero-script win rate to `target_win_rate_by_floor` (median-player targets); Boss AI OQ L855 proposes script-relative band targets (boss wins 20–30 / 40–50 / 55–65 %). Decision taken: one basis — the player targets. `boss-ai.md` OQ L855 → `Resolved: the harness reports boss win rate per floor; Content AC-13 passes when 1 − boss_win_rate(f) is within PRESSURE_TOL-equivalent tolerance (±0.10) of target_win_rate_by_floor[f]`; `content.md` OQ L859 → Resolved the same way. Band targets become derived numbers (band 1 ≈ 0.10–0.20 boss wins), not a second knob.

### Info

ℹ️ **D-08 — Economy** (3d). Resources: cards (source 3/floor from bundles; no sink by design — DD-R06; dilution modelled in reward-draft F8), treasures (3 per run, no sink), health/armour/mana (per match), unlock keys (one-way). No currency exists (anti-pillar), so there is no source/sink imbalance to flag; the one positive-feedback loop (plan cards → affinity → more plan cards) is capped at 3.0× and broken every draft by the coverage slot. v2 sinks (card removal, "forge") are already parked in reward-draft OQ.

ℹ️ **D-09 — Attention budget** (3b). In-match active systems: mana/card economy (Match Rules), combat targeting incl. Taunt/Stealth/Divine Shield (Match Rules), hero-power timing (Heroes), boss intent/threat reading (Boss AI) = 4, plus an intermittent fifth (Discover/Choose-One, Card Effects). Passive: treasure tray, event feed, counters, log. Between matches: one active system (the draft). Within the 3–4 comfortable band; the intermittent fifth is bounded (one `ChoiceRequest` at a time).

ℹ️ **D-10 — Progression loops** (3a). One primary loop (the run: +3 cards per floor, 3 treasures) and one supporting loop (the profile: records plus four keys). They do not compete; Meta's fantasy explicitly refuses accumulation.

ℹ️ **D-11 — Difficulty curve** (3e). Boss side: +10 health per band and passive cap 2 → 3.5 → 6; player side: +3 cards per floor, treasures on 1/3/5 (none after 5), `k_f` +0.05 per floor. Run Structure F7's modelled turns stay flat (10, 10, 9, 10, 10, 10, 11, 10) and the spikes land on band entries (floors 4 and 7) by design. At MVP (`[2, 1, 1]`) floor 3 is a band-2 boss faced with a 21-card deck and one treasure, harsher than v1's floor 4 — intended, covered by the MVP targets `[.90, .80, .65, .45]`.

---

## Cross-System Scenario Issues (Phase 4)

Scenarios walked: 6
1. Win on a treasure floor → treasure draft → bundle draft → next match start
2. Match start with Hollow Crown + Bottomless Satchel, then the boss forecast
3. Boss passive (Rot Warden) + Grave Tithe + a wide Deathrattle chain
4. Resolution fault mid-boss-turn → retry
5. Run ends with a first Decay win → unlock → toast → restart → next run's pool
6. Resume from a save taken between the treasure pick and the bundle offer

#### Blockers
🔴 **S-02 — Match start with Hollow Crown — Match Rules, Treasures, Card Effects, Match UI**
Trigger `begin_match` → Run Structure `installers_for([crown, satchel])` → C3 step 4 `on_match_start` hooks fire in pick order: Crown calls `add_mana(player, 1, temporary=false)`, Satchel's `modify_starting_hand_size` folds 3 → 5 (clamped to `[0, HAND_SIZE]`) → step 5 starting hands → mulligan → first Start step. **Step 4 → first Start step is undefined behaviour**: C4 Start step 2 computes `mana_max = min(mana_max + 1, MAX_MANA)` incrementally (so the +1 would persist) while F4 and AC-06 define `mana_max = min(turns_taken, 10)` (so it would not); Treasures AC-15 asserts 2/2 on turn 1. Same finding as C-02; blocking because an MVP treasure's core effect depends on which reading the engine implements. Secondary (Info): a 5-card mulligan screen — Treasures' Tuning Knobs note "mulligan screen must fit 6"; Match UI's mulligan fixture should include a 5-card case.

#### Cross-System Scenario Warnings
⚠️ **S-04 — Resolution fault → retry — Match Rules, RNG & Event Log, Run Structure, Match UI, Run UI, Boss AI**
`resolution_overflow` → `match_ended{result: fault, winner: null}` → Run Structure `match_faulted{floor, attempt}` → `pre_match`, same streams at `draws = 0` → Run UI S11b `match → boss_intro`. Gap: Match UI's end banner has copy for win/loss/concede; nothing read in this pass names a **fault** banner, and the banner auto-advances after `MATCH_END_AUTO_S` into a *boss intro for the same boss*, which reads as "I lost and the game is replaying the floor" unless the banner says "rules fault — floor replayed, not lost" (Pillar 4). Recommendation: `match-ui.md` U9 end banner: add a `fault` variant with that copy and no defeat sting; `run-ui.md` boss intro after `match_faulted`: subtitle "Attempt 2". Not re-verified against match-ui U9 text; flagged for the Match UI owner.

⚠️ **S-05 — First Decay win → unlock → restart — Run Structure, Meta Progression, Run UI, Reward Draft, Treasures**
`run_ended` → `archive_run` → `unlocks_granted: [hero_decay_first_win]` → `pending_notifications` → Run UI victory summary drains a toast (F3 2–6 s) while *Run again* is focused and the restart budget is 5 s → `new_run` → `init_run` snapshots `unlocked_keys()` including Grave Tithe. Data flow is correct (read at `init_run`, so the grant is visible to the very next run). Messaging overlap: a toast that outlives the summary screen must survive the scene change or be re-shown on the next summary; run-ui F3 queues toasts per screen but the summary → hero select → intro path is < 5 s. Recommendation: `run-ui.md` toast rule: unlock toasts persist across shell transitions until acked or expired (warnings may drop). Also the Meta/Run UI ack-timing wording conflict (C-20).

⚠️ **S-03 — Rot Warden + Grave Tithe + wide Deathrattle chain — Card Effects, Treasures, Match Rules, Boss AI, Match UI**
Player AoE kills four boss minions and two of their own: C10 per-step death check → deaths in board order, player side first → Deathrattles queue; Grave Tithe (`on_minion_died`, hero-slot observer, `once_per_turn` keyed on host id) summons one Husk on the first friendly death; Rot Warden's passive (last in hook order) deals 1 to the player's hero per boss-minion death → four `damage_dealt` events in one `cause_seq` group. Ordering is fully defined after the 2026-11-03 revisions (C9 observers, treasures before passive). Compounding spike: Rot Warden + Thornhide-style "when your hero takes damage" effects could chain; both capped by `EFFECT_STATIC_STEP_LIMIT` 250 / `RESOLUTION_STEP_CAP` 1000 and `max_match_events`. Only residual: Boss AI's sandbox must see the Grave Tithe `once_per_turn` counter as already spent when forecasting — `EffectRuntime` rides inside `MatchState` and `clone()` is a deep copy, so yes. Info-level; no change.

#### Cross-System Scenario Info
ℹ️ **S-01 — Treasure-floor win → drafts → next match — Run Structure, Reward Draft, Treasures, Run UI, Match UI, Meta**
`match_ended(win)` → Treasures `collect_state` → save S2 → `offer(treasure)` draws 0–2 on `draft_<f>` → Run UI picker → `pick` → `treasure_granted` (Run Structure) → save S3 → `offer(bundle)` draws 3–5 → `pick` → `deck_grew` → save → `begin_match` installs hooks. Every hand-off is confirmed in both partners after the revisions (R2.5/R5/R8.2, D1–D3/D8/D9, T3–T5). Match UI's 4 s end-banner auto-advance happens *after* Run Structure has already saved S2 — correct, no race. No issue.

ℹ️ **S-06 — Resume between treasure pick and bundle offer — Run Structure, Reward Draft, RNG & Event Log, Run UI**
Save S3 holds `draft_state` and the `draft_<f>` snapshot at `draws = 3`; `resume` → `restore` → `offer(bundle)` regenerates the identical three bundles (reward-draft F4/D12); Run UI re-enters the draft screen with the treasure already in the strip. Defined and tested by reward-draft AC and run-structure AC-18. No issue.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|---|---|---|---|
| match-rules.md | C-02 permanent `add_mana` / F4 / AC-06; C-04 `targeting` field; C-05 RNG API names; C-16; C-18; housekeeping | Consistency | Blocking |
| meta-progression.md | C-01 settings record (DD-X07/X03); C-20; C-21; housekeeping | Consistency | Blocking |
| match-ui.md | C-01 `anim_speed` labels + `action_delay_ms`; C-07 aliases; S-04 fault banner; housekeeping | Consistency | Blocking |
| boss-ai.md | C-01 `effective_mode` (DD-X03); C-14 fork draws; C-15 loader wording; D-04; D-07 | Consistency | Blocking |
| card-database.md | C-06 `unlock` object (DD-X01); C-21 config file; housekeeping | Consistency | Blocking |
| treasures.md | C-06 `unlock` object; C-19; C-26 | Consistency | Blocking |
| content.md | C-03 (if option A); C-23; C-24; D-06; D-07; housekeeping | Consistency | Blocking (C-03) |
| heroes.md | C-03 `PLAN_MAX` 7 (option B); C-11 (DD-X02); housekeeping | Consistency | Blocking (C-03) |
| reward-draft.md | C-10 unlock-state name; C-13 (DD-X06); C-28 | Consistency | Warning |
| run-structure.md | C-11 (DD-X02); C-12 `suspend`; C-17 driver owner; housekeeping | Consistency | Warning |
| rng-event-log.md | C-09 catalogue rows (DD-X05, `defeat`) | Consistency | Warning |
| run-ui.md | C-08 envelope; S-05 toast persistence; housekeeping | Consistency | Warning |
| card-effects.md | C-22 stale wording | Consistency | Warning |
| systems-index.md | C-01 (Boss AI row); C-25 | Consistency | Warning |
| game-concept.md | C-27 | Consistency | Warning |
| design-decisions.md | C-21 DD-T01 `profile_defaults.json` | Consistency | Warning |
| design/registry/entities.yaml | C-29 | Consistency | Warning |

Systems index statuses were **not** changed (orchestrator applies fixes next; the skill's "mark Needs Revision" step was skipped by instruction).

---

### Verdict: FAIL

Six blocking consistency findings (C-01 … C-06) must be resolved before `/create-architecture`; no blocking design-theory finding; one blocking scenario (S-02, the same root cause as C-02). Both review passes ran; nothing is NOT ASSESSED. One advisory item (V-11) was not re-verified and is labelled as such.

### If FAIL — required actions before re-running
1. `match-rules.md`: C-02 (`crystal_bonus` in C1, C4, C5, F4, AC-06), C-04, C-05.
2. `meta-progression.md`, `match-ui.md`, `boss-ai.md`, `systems-index.md`: C-01 (DD-X07 labels and keys; `action_delay_ms` consumer; DD-X03 `effective_mode` and Meta dependency).
3. `card-database.md`, `treasures.md`: C-06 (DD-X01 `unlock` object; `BundleDef.unlock`).
4. `heroes.md` (option B) or `content.md` (option A): C-03.
5. Then the Warnings in C-07 … C-29 in any order, C-30 housekeeping last; re-run `/design-review` on match-rules, meta-progression, match-ui, boss-ai, card-database, treasures, heroes (and content if option A), then `/review-all-gdds since-last-review`.

---

## Decisions taken (in place of `AskUserQuestion`, owner pre-approved)

1. Wrote this report to `design/gdd/gdd-cross-review-2026-11-03.md` (ISO date) without asking.
2. Did **not** update `systems-index.md` statuses to "Needs Revision" — the orchestrator applies fixes next and owns that file in this run.
3. C-03: recommended **option B** (raise Heroes `PLAN_MAX` to 7) as the mechanical fix because option A (drop the `armour` tag) also requires swapping `war_iron_vanguard` out of `bundle_war_armour_1` to avoid `E_TAG_MISMATCH`; option A remains available and is the Heroes GDD's design preference.
4. C-02: adopted Treasures' reading (permanent `add_mana` at `on_match_start` is legal; Match Rules gains `crystal_bonus`) rather than Treasures' fallback text, because Hollow Crown is MVP content and the hook table already lists "mana" under `on_match_start`.
5. C-01: `anim_speed` divisor mapping `normal 1.0 / fast 2.0` (Match UI owns the numbers; DD-X07 fixed only the labels); `action_delay_ms` is a player override of Boss AI's `presentation.action_delay_s` with the `MIN_ACTION_GAP_S` floor kept; `telegraph_mode` order `full > brief ≡ class_only > off ≡ hidden`.
6. C-12: adopted Run UI's proposed `suspend()` (no event, no save).
7. C-16: proposed answers (card instances expire at the owner's End step; recipient-controller expiry kept; player-side-first observer order) — Match Rules may overturn at its re-review.
8. C-17: Run Structure owns the match-driver interface.
9. C-21: rename to `profile_defaults.json` and add the DD-T01 row.
10. C-23: remove the ★ from `neutral_lantern_bearer` rather than add it to a starter.
11. D-07: single sim basis = `target_win_rate_by_floor` (player targets).
12. Phases 2 and 3 run inline (no `Agent` tool); CD gate skipped (Lean mode) — both stated above rather than silently.
13. Phase 7 handoff widget not shown; recommended next action: apply C-01 … C-06, re-run `/design-review` on the seven blocking GDDs, then `/review-all-gdds since-last-review`, then `/gate-check`.
