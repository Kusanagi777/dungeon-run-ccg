# The Midnight Masquerade — iteration log

Windows 11, Godot 4.7.2 debug binary, gdUnit4. Commands:
- Content validator: `godot --headless --path . -s res://tools/content/validate.gd`
- Authoring and audit: `python tools/content/masquerade_content.py [--check]`

## Iteration 0 — engine probe (2026-11-08)

- **Run:** sandbox suite `tests/sandboxes/unmask_probe_test.gd` (gitignored), 4 cases.
- **Result:** the Unmask effect pattern works from data alone:
  - survive → transform
  - lethal → dies
  - silenced → stays masked
  - enemy side → same rule
- **Escalated:** a second collection needed loader code. The owner chose
  "loader only, no trial" and "easier than Jungle" unlock.

## Iteration 1 — first build (2026-11-08)

- **Validator run 1:** Failed, 8 errors.
  - The `spell_damage` keyword needs a `spell_damage` field (2 true forms).
  - A name was over 32 characters (Madame Steel).
  - Two follow-on reference errors.
- **Change:** added `spell_damage: 1|2` and renamed her "Madame Steel, the
  Ringmaster". Added `silence` and `freeze` keywords where the effect shape
  needs them.
- **Validator run 2:** Failed, 1 error. The House Always Wins text was 109
  characters, over the 90 limit.
- **Change:** shortened the text. Sir Aurel moved from 4 mana 5/5 to 5 mana 4/5:
  his budget was +8 over, too strong for a Taunt with Divine Shield.
- **Validator run 3:** Ready, 0 errors, 847 records, 310.67 ms (budget 500).
- **1-SD curve pass:** 17 flags at first. Reveal-up masks and the masks with
  Divine Shield or Stealth were above curve for no reason:
  - Gladiator, Baron, Physician, Gilded Noble, Gambler's Mask
  - Mirror Mage, Steward, Bell-Ringer
  - Debutante, Cutpurse, Assassin

  Each lost 1 stat point. **6 flags remain**, all justified in the design doc:
  five strong masks priced against their downgrade, and Candle Page's
  Battlecry.
- **Loader regression:** `law_of_the_jungle_collections_test` expected exactly
  one collection; it now expects two.
  - A first version of the shared unlock validator also covered Jungle's unlock,
    which would hide a missing Jungle validator.
  - Fixed: the shared validator applies only to collections with no `trial_id`.
- **Mechanic, boss and item suite:** `midnight_masquerade_unmask_test.gd`, 20 of
  20 pass.
- **Mutation check:** the suite must fail against broken data.
  - Three edits caused 5 failures:
    - Finery's true form changed to the upgrade
    - the Dance Card turn changed
    - the Reveler's survive condition removed
  - The lethal test still passed with the survive condition removed. The engine
    never reveals a dying minion, so the condition is a second guard, not the
    rule. The lethal test guards the rule either way.
  - Data restored by re-running the authoring script.
- **Content suite:** `midnight_masquerade_content_test.gd`, 14 of 14 pass,
  including both 48-card sweeps.

## Iteration 2 — playtest read-through fixes (2026-11-08)

- **Velisande's enablers listed Hush.** Silence stops her reveal, so the
  enabler was wrong.
  - **Change:** her enablers are now Frost-Masked Scholar and Curtain Call.
  - Curtain Call is tagged with both themes, so Knowledge bundles can offer it.
- **Smelling Salts against the Dungeon Heart** undoes 2 damage per turn on every
  surviving minion. Too much for a common.
  - **Change:** raised it to rare.
- **Frozen masks:** the playtest notes claimed a frozen mask keeps its Freeze
  when it unmasks. A new test showed the claim was wrong: transform makes a
  fresh, unfrozen minion.
  - **Change:** corrected the doc to "unmasking thaws". The test now pins that
    behavior, and the edge-case table lists it.

## Iteration 3 — full suite and regressions (2026-11-08)

- **Full suite:** 4505 cases; 160 failures and 9209 errors, almost all from one
  cause.
  - `ValidatorStubs.config_names()` only listed configs in the fixed manifest, so
    `accept_all()` had no validator for the new shared `collection_unlock` key.
  - Every fixture database built over the shipped data failed to load: the
    reward-draft, treasure and run suites.
  - **Change:** the stub also registers `DataLoader.COLLECTION_UNLOCK_VALIDATOR`.
- **Other real failures, each fixed:**
  - `boot_validator_map_test` and `card_database_validators_test`: the
    validator map has one more key (14 → 15).
  - `card_database_single_parser_test`: two new loader constants
    (`COLLECTION_FILES`, `COLLECTION_UNLOCK_VALIDATOR`) join its allowed list.
  - `law_of_the_jungle_ui_test`: the collection picker now has 3 entries.
  - `content_shipped_cards_play_test`: Reveler Unveiled had no tribe. Now it
    is Human.
  - `card_database_shipped_budget_test` and `card_database_load_budget_test`:
    missed by the earlier budget change. `TestConstants` and the `clean` fixture
    now mirror 500 ms / 12 MB.
- **Re-runs:**
  - reward_draft, treasures, run, card_database, boot, content, expansions and
    meta_progression suites: 1187 cases; all pass apart from the 3 failures
    above.
  - Those 3, plus the run and treasure perf suites: 330 cases; only the 2 known
    Treasures AC-14 performance failures remain.
- **Remaining performance failures**, unchanged owner decisions in
  `production/qa/v1-test-pass-2026-11-06.md`:
  - card_effects AC-42 (2)
  - Deathrattle chain submit (1)
  - Treasures AC-14 (2)
  - perf_gate_harness (2)
- **Validator:** Ready, 0 errors, 246 warnings, 847 records, 268 ms.
  The Jungle and Masquerade audits both pass.

**Phase 4 gates:** schema, mechanic, items, bosses, unlock, smoke, legendary
and balance all pass. Masquerade: 21 rule, boss and item tests plus 14
content tests.
