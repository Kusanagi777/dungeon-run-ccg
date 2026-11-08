# Law of the Jungle — test iterations

## 2026-11-07 — Predator prototype, iteration 1

Environment: Godot 4.7.2, repository `tools/bin/godot` wrapper with isolated
user data. Expansion content is still a design; no canonical data was changed.

### Completed checks

- Run `report_116`, 2026-11-07 14:29 America/New_York:
  `tests/integration/expansions/law_of_the_jungle_predator_test.gd` passed
  **22/22**, with zero errors, failures, skipped tests, or orphan nodes; exit 0.
- The real record and effect validators accept the inline prototype definitions.
  Runtime checks cover matching and nonmatching prey, both owners, multiple prey,
  self-exclusion, token and multi-tribe prey, Stealth, Silence, removed/dying/
  bounced/transformed prey, persistent resolved bonuses, direct summons,
  transformation into predators, paid replay from hand, boss-side play, and
  AI clone parity and isolation.
- Run `report_117`, 2026-11-07 14:30 America/New_York: the existing
  `tests/unit/card_effects` regression suites passed **448/448**, with zero
  reported test errors, failures, skipped tests, or orphan nodes; exit 0.
  Godot separately reported 72 leaked ObjectDB instances and 10 resources still
  in use during process shutdown. This run excludes the new prototype suite;
  the cleanup diagnostics are a baseline concern, not a clean runtime sign-off.
- Run `report_118`, 2026-11-07 14:32 America/New_York: the existing
  `tests/integration/content` suites passed **117/117**, with zero errors,
  failures, skipped tests, or orphan nodes; exit 0.
- Headless boot smoke (`--headless --path . --quit-after 5`) passed with exit 0
  and no runtime errors or warnings. This boots the current game, not the
  absent expansion. In total, the three test runs passed **587/587** cases.
- The current shipped content validator returned `Ready`, **0 errors and
  137 warnings**, covering 504 existing records; exit 0. These are current-pool
  results, not expansion schema or balance results.
- Design-budget checks passed: 138 collectible cards, 16 exclusive cards per
  class, 42 Neutral cards (30.4%), 12 class legendaries, no Neutral legendaries,
  and the documented rarity totals. These are planned allocations, not counts
  from authored expansion records.

Failing prototype tests: none. Flagged expansion cards: not assessed because
the card pool is absent. Change from this iteration: add executable contract
coverage for the proposed conditional Battlecry; no gameplay fix was needed.
Re-run after a fix: not required; the first prototype run passed. No balance
changes were made or validated.

### Gates that cannot run yet

| Gate | Missing prerequisite |
| --- | --- |
| Full expansion schema and legendary validation | `assets/data/law-of-the-jungle/cards.json` and actual per-card design annotations |
| New boss activation, decks, eligibility, and encounter balance | The two new boss definitions and their actual decks |
| New run-item behavior, group counts, eligibility, and persistence | Authored run items, including 1–2 mechanic-support items and 1–2 additional gap-filling items |
| Expansion unlock and trial tests | `unlock.json`, collection integration, and the Primal Crown trial implementation |
| Expansion loading, draft access, save/resume, and replay | A staged pool and the collection integration |
| Stat/effect balance, item-combination balance, and boss playtesting | The complete authored cards, items, and encounters |

Next iteration must author and integrate the required staged content, then run
the remaining gates against real records. Prototype success does not complete
Phase 4 or authorize canonical publication.

## 2026-11-07 — complete implementation, iteration 2

The owner authorized the complete expansion implementation. The runtime now
registers separate collection files through the existing loader: 138 collectible
cards, three tokens, 84 class-legal bundles, two bosses, and three treasures.
Core records keep their class identities; normal runs require an unlocked,
explicitly selected featured collection. The skill now requires expansion bosses,
both groups of run items, and class-exclusive legendaries.

### Failures and refinements

- Reports 119–120: retained the trial fixture's manual clock so the profile
  writer's callable remained valid; all nine initial trial tests then passed.
- Reports 121–125: collection eligibility and authored-card checks passed.
  Fixed test fixtures that submitted a spell with a minion position or read armor
  outside the hero snapshot. Extended save/replay coverage to interrupted AI plans.
- Reports 123 and 125–129: legal loaner play exposed a weak late curve and
  excessive Veyra attrition. Added durable Neutral threats and both Order
  finishers to the 36-card loaner; Veyra now replenishes a Beast only when it has
  none. Players retain a removal window before its next turn.
- Report 130: all 12 trial cases passed. The legal three-encounter playthrough
  achieved 11, seven, and ten successful Predator bonuses respectively, with
  friendly and enemy prey in every victory. No forced damage or victory grants.
- Final feature checks added forecast-boundary persistence, restored intent
  without further AI RNG draws, and retrying a failed completion save. The UI
  offers **Save trial completion** instead of discarding a completed attempt.
- The broad regression exposed stale core counts, reference-budget formulas,
  archetype tags, and tests for the previous hero-screen controls. Updated those
  expectations against current source data. Fixed `ReplayQuery.hero_power_id()`
  to remain independent of a live engine. Added the expansion UI suite's missing
  shared-Boot teardown so subsequent lifecycle tests stay isolated.

### Design and balance evidence

`python tools/content/jungle_content.py --check` passes the authored budgets:
42 Neutral cards (30.4%, none legendary), 16 exclusive cards per class,
exactly two distinct legendary plans per class, 24 legacy-support slots,
84 bundles, two bosses, three distinct items, and the trial's 36/3/3 counts.
The generated card ledger records all 27 raw-stat outliers beyond one standard
deviation of the existing same-cost/rarity curve and their individual rationale.
It also records legendary enablers, both item groups' closest existing comparisons,
and a read-through against the complete core and expansion boss roster.

The actual content command returns `Ready`, **734 records, zero errors and
212 warnings**. These include approximate effect-budget and coverage warnings;
the measured load of 226.54 ms exceeds the advisory 200 ms budget. This is not
a warning-free or performance-budget sign-off. Human balance and measured class
win-rate parity remain future checks.

An exported Windows game pack contains all eight collection/registry JSON files
and boots headlessly with exit 0 and no runtime diagnostics. Pack creation exits
0, with the existing Godot shutdown diagnostics (eight ObjectDB instances and
seven retained resources). Screenshots of Expansions and featured selection are
under `production/qa/evidence/law-of-the-jungle/` and were visually inspected.

### Final expansion gates

`reports/jungle-final/report_4`: **70/70 passed**, zero errors, failures,
skips, flaky cases, or orphan nodes; exit 0 (40.214 seconds, Godot 4.7.2).
The five suites cover 17 collection cases, 12 authored-content cases,
22 Predator rules cases, six UI cases, and 13 trial cases.

| Gate | Result and evidence |
| --- | --- |
| Schema and structure | Passed: real loader/validators, generator audit, all record references and budgets. |
| Mechanic and run items | Passed: all 22 Predator contracts; actual Compass, Watchglass and Ration effects and limits. |
| Boss mechanics | Passed: both actual decks, both prey owners, absent prey, deterministic passives and removal windows. |
| Unlock and persistence | Passed: access below/at thresholds, replay-derived objectives, disk resume, mid-plan/forecast continuity, atomic grant and save-failure retry. |
| Smoke and packaging | Passed: exported game pack contains every collection file and boots without runtime diagnostics. |
| Legendary cycle | Passed: two per class with distinct plans and legal nonlegendary enablers; no Neutral legendary. |
| Balance review | Passed structural/stat review with all 27 flags documented; three-encounter legal-play simulation wins. Human balance remains a watchlist item. |

The focused regression report `jungle-final/report_1` ran 229 cases and found
two remaining failures (shared-Boot teardown and the old hero-tab keyboard flow).
Report 2 confirms the teardown fix, other affected UI, and the updated 19-record
unlock list. Report 3 passes all **41/41 keyboard and sound cases** after wiring
Enter on a hero tab to focus Start. This preserves the chosen hero while offering
the keyboard path the previous screen tests expected.

Godot still reports 276 ObjectDB instances and 29 resources retained at the end
of the final feature test process. These are process-shutdown diagnostics,
separate from gdUnit's zero orphan-node count; no clean resource-lifetime claim
is made.

### Finalization checklist

- [x] Owner authorized the full implementation.
- [x] Installed all 138 cards, 84 bundles, two bosses and three items.
- [x] Integrated Predator, collection eligibility, trial, unlock and save/resume.
- [x] All seven expansion gates passed with the limitations above.
- [x] Updated the skill, design, ledger, iteration log, README and collection index.
- [x] Inspected the new screens and verified exported content.
- [x] The four older failing suites below are fixed (2026-11-08); a repository-wide run has not been repeated.

### Repository-wide regression limitations

`reports/report_131` executed **4,426 cases in 243 suites** (25m 1s):
48 assertion failures and 26 runtime errors, with no skips or orphan nodes.
That process discovered/compiled tests before the incremental regression fixes;
the focused reports above verify those fixes. It is not a final green full run.

`reports/jungle-final/report_5` independently reproduces the remaining failures:
95 cases, **27 failing cases** containing 32 assertion failures and one runtime
error. These four older suites do not test the new expansion's rules:

| Suite | Failing cases | Diagnosed cause |
| --- | ---: | --- |
| `tests/unit/content/content_budget_checks_test.gd` | 4 | Knowledge share fixtures omit the now-required explicit share row; the literal scan also mistakes UI color/opacity values for gameplay budgets. |
| `tests/unit/content/content_validate_command_test.gd` | 17 | Its supposedly valid fixture still includes the removed `neutral_set_size` setting, contaminating single-fault assertions. |
| `tests/unit/heroes/heroes_plan_and_synergy_test.gd` | 1 | Exact signature synergy counts predate the expanded core archetype pool. |
| `tests/unit/heroes/heroes_validate_config_test.gd` | 5 | Boundary/shape tests still treat removed `hero_set_size` and `hero_set_size_tol` settings as accepted fields. |

The owning Content/Heroes validator implementations were unchanged by this
expansion. These failures remain explicit follow-up work; the full-suite gate
has not been waived or reported as passing. Generator drift and `git diff
--check` both pass on the final files.

## 2026-11-08 — older suite fixes, iteration 3

Before committing, the expansion suites were re-run: **70/70** passed, plus
**232/232** card-database unit cases. Content validate returned `Ready`, 0 errors,
212 warnings, loading in 197.63 ms. The expansion was then committed as `5d6b821`.

The four suites from `jungle-final/report_5` reproduced as 95 cases with 32
failures and one runtime error. All four test files were stale; no validator
code changed.

| Suite | Fix |
| --- | --- |
| `content_budget_checks_test.gd` | Set-share pools now include a hero of the set, because a set counts as a hero set only when a pool hero owns it. The literal scan checks `src/ui/` files for F1–F6 constant names only, not bare default values; new matcher cases cover both. Removed `neutral_set_size`. |
| `content_validate_command_test.gd` | Removed `neutral_set_size` from the valid fixture and from the safe-range test. |
| `heroes_plan_and_synergy_test.gd` | The +2 per War signature comes from two Jungle War cards (`war_jungle_bone_honing`, `war_jungle_ridge_bladesmith`), not the core archetype pool as iteration 2 said. Heroes F5 counts every card in the hero's set, so the expected scores are now 19/21/21. |
| `heroes_validate_config_test.gd` | Removed `hero_set_size` and `hero_set_size_tol`. The unknown-set case now uses `set_share.boss`; any hero-shaped set id is allowed (AC-19). |

Result: `tests/unit/content` and `tests/unit/heroes` passed **103/103**, with zero
errors, failures, skips or orphans.
