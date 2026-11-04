# Code Review: match-rules 012 / 013 / 014 + staged attack handler (sprint 4 lane 1)

**Date**: 2026-11-04 · **Reviewer**: independent pass. `/code-review` was followed by hand from `.claude/skills/code-review/SKILL.md`, because a model cannot invoke it.
**Scope**: `760076b` (merge: sprint 4 L1), covering `feb0c3d` (012), `126b547` (013), `c8f3575` (014) and `5c61083` (refactor: staged model). Files: `src/gameplay/match/rules_engine.gd` (+240), `src/gameplay/match/match_records.gd` (+15), `tests/helpers/test_effect_resolver.gd` (+31), three new suites under `tests/unit/match_rules/`.
**Workflow tier**: match-rules `full` (`project.yaml workflow_overrides`).
**Inputs**: all present (FOUND): the three stories; GDD C8, C9, C12, C13, C14, F2, F3 and Edge Cases "Combat" (read by section); DD-X11 (`design/design-decisions.md:76`); ADR-0007 Status/errata and Decision; ADR-0008 errata (one, MatchQuery; none on attack or Choice); control manifest Core Layer; card-effects C2 rows `on_attack` / `on_damage_dealt`, `scope.gd`.

## Run results (this review)

| Check | Command | Result |
|---|---|---|
| Import | `godot --headless --import` | exit 0. One warning: the nested `prototypes/hearthstone-clone-2026-01/project.godot` is ignored, as expected. |
| Full suite | `project.yaml commands.test` | **1198 test cases, 0 failures, 0 errors, 0 orphans, 73/73 suites, exit 0**. 85 `SCRIPT ERROR` lines, all intentional negatives elsewhere. **None** fall inside the three attack suites' output ranges. Attack suites: legality 16 / resolution 9 / keywords 10, all pass. |
| Smoke | `godot --headless --quit-after 5` | exit 0, no SCRIPT ERROR |
| Probes | `scratchpad/rv4b_probe.gd`, `rv4b_perf.gd` (run headless, read-only) | 7 scenarios. Two DIFFs, see S1 and S2. |
| Perf (observation) | `legal_commands()` with 8 attackers × 8 defenders, a Taunt and a weapon, no hooks | 0.48 ms/call against the 2 ms guardrail |

Working tree after the review: clean. Nothing was edited and nothing was committed.

## Engine Specialist Findings: NOT ASSESSED (specialist not spawnable)

`godot-gdscript-specialist` could not be spawned. I checked engine behaviour myself instead. The diff uses only pre-4.3 GDScript: `Dictionary`, `Array.pop_front` / `assign` / `duplicate(true)`, `Callable.bind`, `clampi`, typed `Array[int]` / `Array[Dictionary]`. It uses no post-cutoff API. The behaviour was confirmed by a headless import, the full suite and probe scripts run under Godot 4.7.2.stable.

## Testability: TESTABLE (qa-tester not spawnable, so assessed by hand)

Every AC has a named test, and the legality expansion is asserted against an explicit expected pair list, not a tautology. The story notes record mutant runs. Gaps are listed under S1, S2, S4 and N3.

## ADR Compliance: COMPLIANT (minor deviations)

- **ADR-0007**: compliant. The engine owns `on_attack` timing and its candidates (`_candidates_in_order()`). Each `on_attack` response is a queued step with the full C10 loop. Both hits sit in one step, with no death check or `recompute_auras` between them. The resolver only answers.
- **ADR-0005**: compliant. `max_attacks` runs the whole fold and then clamps once (`rules_engine.gd:1503-1508`). The ctx is reused, so nothing is allocated. **MINOR DEVIATION** (recorded in the story): ctx `who` is an entity id, where the ADR example uses the record. See also N2.
- **ADR-0008 / story-016 staged model**: compliant. The parked attack is plain data. Probe P7 dumped `suspended_action = {cause_seq, frame:{attacker, cause, defender, side}, origin_phase, stages:[attack_damage, attack_resolved]}`, which is JSON-clean, so it is safe for `clone()` and a boss `choose` sandbox.
- **ADR-0003**: AC-16's "consecutive seq" holds for the AC fixture only. See N3.

## Standards Compliance: 5/6

- Doc comments: present on every new public and private function.
- **Complexity**: `_attack_rejection` (`rules_engine.gd:1563`) has about 19 decision points (10 `if` plus `and`/`or`/ternary), well over the threshold of 10. It mirrors F3 term for term, so this is accepted as a nit (N4).
- Methods are 40 lines or fewer: pass. Dependency injection and no singletons: pass. Config-driven: `max_attacks_windfury` and `max_attacks_cap` come from `rule()` (pass). `ATTACKS_PER_TURN = 1` is pre-existing.

## Architecture: CLEAN · SOLID: COMPLIANT

The attack is four stage kinds plus one `_run_stage` arm, which matches the play and hero-power pattern. `_attack_rejection` is shared by `can_attack` and `legal_commands`, so legality cannot drift between the two paths.

## Verified behaviour (focus items)

| Focus | Result | Evidence |
|---|---|---|
| C8 step order 1→7 | OK | AC-16 test order: `attack_declared, trigger_resolved, marker, damage_dealt×2, attack_resolved`. `attack_resolved` is last; `submit` then runs `_win_loss_check`. |
| Simultaneous damage, no death check between hits | OK | `_attack_damage_step:1713`: both `apply_damage` calls in one step. Poisonous attacker killed by its defender still poisons it (014 test). |
| DD-X11: defending hero deals nothing back; defender weapon untouched | OK | `if d_atk > 0 and defender_is_minion`. Durability is only touched on `_weapon_of(attacker)`. Test asserts one hit, no `weapon_durability_changed`. |
| Snapshot at the damage step | OK | `a_atk` / `d_atk` are read before either hit. The test mutates D's attack inside the step (inline `on_damage` script) and it still strikes for 2. |
| Re-check after `on_attack`, Taunt not re-evaluated | OK | Tests for defender removed, attacker removed, and Taunt summoned mid-attack. P6: a cancelled hero attack keeps weapon durability 2. |
| Discover in `on_attack` through the staged model | OK | Test plus P3 (continuation destroys the defender → `attack_cancelled`, `attacks_used 1`, a single `attack_resolved`). P4: Discover from an `on_damage` trigger in the damage step parks only `attack_resolved` and emits it once after `choose`. |
| `max_attacks` fold then clamp | OK | set 9 → 4, set −1 → 0, chain −2,+2 → 1 (catches a clamp placed between entries). |
| Stealth / Taunt / Rush / Charge / Windfury legality | OK, with S1 and S2 | F3 order test covers each code. Stealth Taunt is excluded from `taunters`. Rush gets `RUSH_CANNOT_HIT_HERO`. Charge supersedes Rush. |
| Deviation: unknown attacker → `CANNOT_ATTACK` | Accept | F3 has no term for it. The phase term cannot be evaluated without `A.controller`. Record it in GDD C2/F3 (N1). |
| Deviation: Rush plus unknown target → `SUMMONING_SICK` | Accept | This is the literal false term of F3 line 744 (`D is minion` is false). The UI may show "summoning sick" for a stale target id (N1). |
| Deviation: weapon as damage source | **Needs a decision**: S3 | |

## Findings

### Blocking

None.

### Should-fix

**S1. Windfury granted to a weapon by an enchantment is ignored.** (`rules_engine.gd:1494`, story 012/014) — VERIFIED (probe P1)
- Evidence: `has_windfury` reads `weapon.keywords.has(WINDFURY)`, which is the definition set only. `add_keyword(weapon_id, "windfury")` (card-effects `give_keyword`, whose targets are "characters, weapons") lands in `weapon.enchantments[].keywords_added`. Probe P1: `add_keyword` lands on the weapon enchantment, but the hero's `max_attacks` is **1, expected 2**.
- Failure scenario: a card or treasure "Give your weapon Windfury" does nothing. The engine is also inconsistent with itself: `_source_has` (`:3185`) reads weapon definition plus enchantment keywords for Poisonous and Lifesteal on the same weapon.
- Fix: `return weapon != null and _has_keyword(weapon, MatchRecords.KEYWORD_WINDFURY)`. Add a case to `test_windfury_from_a_keyword_an_enchantment_or_the_hero_weapon_gives_two_attacks` with a weapon that gains Windfury through an enchantment, and watch it fail first.

**S2. Stealth granted by an aura comes back right after declaration.** (`rules_engine.gd:1686-1692`, `_strip_keyword` `:3215`, story 014 AC-26) — VERIFIED (probe P2)
- Evidence: `_declare_attack_step` erases `stealth` from the definition and from every enchantment, including `is_aura` ones. The step's own C10 loop then runs `_recompute_auras()` (`:2818`), which strips every aura enchantment and re-applies it from its live source, Stealth included. Probe P2 (an aura applying `keywords_added: ["stealth"]`): `stealth_lost` is emitted, yet after the attack the attacker **still has Stealth**, and on the boss turn `can_attack(enemy, it)` returns **`TARGET_STEALTHED`**.
- Failure scenario: an aura "your minions have Stealth" is legal DSL (card-effects op table, `aura` takes `keywords[]`, `design/gdd/card-effects.md:333`; content row 42 already uses `aura` with `rush`). It produces minions that attack from Stealth forever and log a false `stealth_lost`. GDD C12 says Stealth is "lost when the minion attacks".
- Fix: pick one, and record it in GDD C12 with a test.
  - (a) A per-character `stealth_broken` flag set at declaration, honoured by the Stealth read (and cleared by Silence or when the minion leaves play).
  - (b) Have `EffectValidator` reject `stealth` in `aura.keywords[]` (a new `E_FX_*` code needs a card-effects GDD change, per the manifest).
  - (c) Rule in the GDD that aura Stealth persists and suppress `stealth_lost` in that case.
- No shipped content hits this today (no data file grants Stealth through an aura), so it is not blocking.

**S3. Weapon-as-source changes card-effects scope semantics without a recorded decision.** (`rules_engine.gd:1720`; `src/gameplay/effects/scope.gd:173-176`; story 013 Decisions) — VERIFIED by code reading and probe P5
- Evidence: a hero weapon attack emits `damage_dealt {source: <weapon id>}` and raises `on_damage {source: weapon}`. The `modify_damage` fold ctx `source` and the `on_hero_damaged` hook `source` are both the weapon. `EffectScope._character_in` matches `owner_hero` only when `id == hero.entity_id`. So an `on_damage_dealt by: owner_hero` trigger ("whenever your hero deals damage") never fires on a hero weapon attack, and only `by: owner_weapon` does. The same applies to a `modify_damage source:` filter naming the hero. Stats credit the weapon `def_id` (P5: `{"neutral_test_axe": 1}`), while story 013's note says "the hero as the damage dealer for stats". The story records the contradiction but no GDD or ADR text resolves it.
- Failure scenario: the first treasure or hero card written as "after your hero attacks/deals damage" silently never triggers on weapon swings. No test would catch it, because no test asserts `source` on a hero hit.
- Fix: record the rule in GDD C8 step 4 and C9, and in card-effects C2 `on_damage_dealt`. Then either:
  - keep weapon-as-source and document that `owner_hero` excludes weapon hits, or
  - pass the hero as `source` and have F2 read keywords from the hero's weapon when the source is a weapon-wielding hero.
  
  Either way, assert `damage_dealt.source` in `test_a_hero_weapon_attack_takes_the_minions_strike_back_and_spends_durability` (`attack_resolution_test.gd:164`) and add a weapon Poisonous/Lifesteal hero-attack test. Today nothing in the suite would catch a swap back to the hero id that loses the weapon's keywords.

**S4. No test covers a pause after the damage step, or the cancel path after `choose`.** (`match_rules_attack_resolution_test.gd:278`) — VERIFIED (probes P3 and P4 pass today)
- Evidence: the single Discover test pauses at the `on_attack` point and resumes into the damage path. The two other parked shapes are untested: a continuation that removes D, so the re-check cancels after `choose`; and a Discover from an `on_damage` trigger, which parks only `attack_resolved` with `attacks_used` already 1. A regression that, for example, re-ran `attack_damage` on resume, or dropped `attack_resolved` when only it was parked, would pass the suite.
- Fix: add P3 and P4 as tests (scripts in `scratchpad/rv4b_probe.gd`, `_p3_…` / `_p4_…`).

### Nits

- **N1. Record the two legality deviations in the GDD.** (`rules_engine.gd:1566-1578`) Unknown attacker gives `CANNOT_ATTACK`, and a summoning-sick Rush minion with an unknown target gives `SUMMONING_SICK`. Both are defensible, but they exist only in the story notes. Add one line to GDD F3 or C2 so the UI and Boss AI teams code against them.
- **N2. `_max_attacks_ctx` is shared and mutable.** (`:1506`) A value hook whose condition re-enters `max_attacks` for another character (for example a future `attacks_remaining` value ref) would overwrite `who` mid-fold. Note "not re-entrant" in the doc, or save and restore `who` around the fold.
- **N3. AC-16 "consecutive `damage_dealt`" holds only for a bare fixture.** P4 shows `damage_dealt, trigger_queued, damage_dealt` whenever D has an `on_damage` responder. `divine_shield_popped`, `armor_lost` and Lifesteal `healed` also land between the two hits. This is GDD-legal (C8 forbids only a death check between them), but match-ui's "both numbers update at the same frame" must not key on adjacency. Say so in the AC-16 test comment or in the match-ui story.
- **N4. `_attack_rejection` exceeds the complexity threshold of 10** (about 19). It is acceptable as a 1:1 transcription of F3. If it ever grows, split the attacker terms from the target terms.
- **N5. Stale `TODO(stories 012, 016)` in `_validate`.** Self-reported in story 012. Remove it at the next touch.

## Positive observations

- The staged refactor is small and correct. The declare step writes `cause` into the live frame (`_declare_attack_step.bind(payload, _frame)`), so `on_attack` runs under `attack_declared` both before and after a park. Probe P7 shows the parked state is pure data.
- One predicate (`_attack_rejection`) serves both `submit` validation and the `legal_commands` expansion, and `taunters` is computed once per call.
- The tests were watched failing and mutant-checked, which is recorded per story: the snapshot mutant, the DD-X11 "minion only" mutant, and the fold-chain clamp mutant. The legality expansion test hard-codes its expected pairs rather than deriving them from `can_attack`.
- DD-X11 is implemented exactly, and the defender-weapon durability case is asserted.

## Verdict per story

| Story | Verdict | Open items |
|---|---|---|
| 012 Attack legality | **APPROVED WITH SUGGESTIONS** | S1, N1, N2, N4 |
| 013 Attack resolution (DD-X11) + staged follow-up | **APPROVED WITH SUGGESTIONS** | S3, S4, N3 |
| 014 Combat keywords | **APPROVED WITH SUGGESTIONS** | S2 (S1 also touches the AC-18 Windfury row for weapons) |

**Overall (SKILL.md first-match rule): NOT ASSESSED.** There are no Required Changes, but the engine-specialist and qa-tester agents could not be spawned. With those two parts substituted by headless verification, the result is APPROVED WITH SUGGESTIONS: nothing blocking, and four should-fix items.
