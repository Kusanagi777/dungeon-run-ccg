# Classes, hero powers and archetypes: design

**Date:** 2026-11-06
**Status:** awaiting owner review
**Extends:** `design/gdd/heroes.md` H-7, which sketches Fortune, Order and Shadow as post-v1 heroes.

## Goal

More replay variety and a longer progression path. Deckdelve goes from 3 classes to 6, every class
has 3 hero powers earned through play, and the card pool gains 14 archetypes.

Deckdelve is an ever-growing game. Nothing caps how many classes, cards, bundles, bosses or archetypes it
can hold, and the only balance rule is that classes, bosses and archetypes stay balanced relative to each
other. This release is the first step, so its changes must make the next class a data-only addition.

Success means:

- A new profile starts with 3 classes, one power each, and has 3 classes and 12 powers to earn.
- A player can see everything left to earn, and how, on the Unlocks screen.
- All new content passes the structural validators, and the relative balance report is in tolerance.
- Adding a seventh class later needs new data files and no code changes.
- Each phase below leaves a playable game.

## Owner decisions

| Decision | Choice |
| --- | --- |
| New classes | Fortune, Order, Shadow (the sets the schemas already reserve) |
| Power use | One power per run, picked at hero select. Extra powers unlock through play |
| Archetype reach | New classes, one new archetype per existing class, two neutral archetypes |
| Unlock path | Classes and powers are both earned |
| Growth | No upper limit on content |
| Balance | Only relative: classes, bosses and archetypes against each other |

## Out of scope

- New keywords. Everything here uses the 15 in `RecordSchemas.KEYWORDS`.
- A hard balance gate. The report informs decisions and does not block builds.
- Changing powers during a run, or using more than one power in a match.
- New bosses, and new treasures beyond any the balance pass shows are needed.
- New unlock condition types. `runs_won`, `floor_reached` and `boss_defeated` cover all of this.

## 1. Hero powers

### Data

`HeroDef` keeps `hero_power` as the starting power, and gains `extra_powers`, an array of exactly two
`{power, unlock}` rows. `unlock` has the same `{key, condition}` shape as every other unlock.

```json
"hero_power": "power_rot",
"extra_powers": [
  {"power": "power_harvest", "unlock": {"key": "power_harvest", "condition": {"type": "floor_reached", "n": 5, "hero": "hero_decay"}}},
  {"power": "power_raise", "unlock": {"key": "power_raise", "condition": {"type": "runs_won", "n": 1, "hero": "hero_decay"}}}
]
```

Every class uses the same rule: the second power at floor 5 with that class, the third on a win with
that class.

`UnlockEvaluator` registers these rows under a new record kind, `power`. `RunReadModels.unlocks()`
adds a Powers section, grouped by class.

### Run flow

1. Hero select shows the selected class's three powers. The default is the last power played with
   that class, else the starting power.
2. `start_run` carries `power_id`. `RunMachine.new_run` rejects a power that does not belong to the
   hero or is locked, with a new `E_POWER_LOCKED`.
3. `RunState` stores `hero_power_id`, and `RunRecord` saves it as an optional field.
4. Match setup reads `state.hero_power_id`, not `hero.hero_power`.
5. An archived record with no field reads as the hero's starting power, so the run log and replays
   keep working.

Run records stay at schema version 1: the field is optional and has a default.

**Saved runs.** New data files change `data_version`, and a save from another data version already
ends with "not counted as a loss". So a run in progress when this ships will probably not resume.
That is existing behaviour, but it should be confirmed in phase 2 and mentioned in the patch notes.

### Power list

All cost 2. Boss powers (Mend, Drain, Reinforce, Brand) stay boss-only. `heroes.md` rejected a 1 damage
ping for Knowledge so that two classes would not share that role, and this list keeps to that.

| Class | Starting | Floor 5 | Win |
| --- | --- | --- | --- |
| War | Whetstone (exists) | **Battle Cry:** give a friendly minion +2 Attack this turn | **Brace:** gain 2 Armor. If you have a weapon, gain 2 more |
| Decay | Rot (exists) | **Harvest:** destroy a friendly minion, draw a card | **Raise:** summon a 1/1 Husk |
| Knowledge | Insight (exists) | **Frostbind:** freeze a minion | **Study:** discover a spell that costs 1 or less |
| Fortune | **Toss:** flip a coin. Heads: deal 2 damage to a random enemy. Tails: gain 2 Armor | **Loaded Die:** deal 1 damage to a random enemy, twice | **Stake:** add a Coin to your hand |
| Order | **Ward:** give a friendly minion Divine Shield | **Stand Fast:** give a friendly minion Taunt and +1 Health | **Muster:** summon a 1/2 Recruit with Taunt |
| Shadow | **Garrote:** give a friendly minion +1 Attack and Stealth this turn | **Vanish:** return a friendly minion to your hand. It costs (1) less | **Envenom:** give a friendly minion Poisonous this turn |

These numbers are starting points. The balance report decides whether each power stays level with the
other two in its class.

## 2. Hero select

**Not covered in the earlier design discussion.** The screen holds three 340 px panels, so six classes
do not fit. It becomes a roster and a detail page:

- **Left:** a scrolling column of portrait tabs, one per class, in data order, with no limit on how many.
  Locked classes show a dim portrait and a lock mark, and stay focusable.
- **Right:** one ink panel for the focused class: name, identity line, stats, portrait, cards by cost,
  and the three power stamps with the selected power's text on a parchment plate.
- **Locked class:** the same page shows what to do to earn it, and Start is disabled.
- **Locked power:** its stamp is a faint impression, its text shows the condition, and it cannot be
  selected.
- **Deck drawer:** one drawer that follows the focused class. This replaces the per-hero drawers and
  removes the cause of the stuck drawer bug.
- **Unchanged:** the seed row, Back, Start and Deck stay in place.

`design/ux/hero-select.md` is rewritten to match, along with the acceptance criteria and tests tied to
panel slots. At 150 % text the page scrolls.

## 3. New classes

Each class gets a 25-card set at launch, a 15-card starter deck inside
`starter_curve`, about 8 bundles, and a portrait.

| Class | Hero | Colours | Portrait | Unlock |
| --- | --- | --- | --- | --- |
| Fortune | Lady Tallow | coin gold, soot | `coins` | `hero_fortune`: win a run with any class |
| Order | Warden Cassia | ivory, steel | `helmet` | `hero_order`: reach floor 5 with any class |
| Shadow | The Lamplighter | charcoal, violet | `hood` | `hero_shadow`: defeat 8 bosses |

These unlocks replace the examples in `heroes.md` H-7. Stamps are reused where they fit, and any new
game-icons silhouette gets an entry in `THIRD_PARTY_ART.md`.

### Archetypes

| Class | Archetype | Tag | Plays as | Built from |
| --- | --- | --- | --- | --- |
| Fortune | Gamble | `gamble` | Cheap cards with a random upside | Random selectors, `flip` |
| Fortune | Hoard | `hoard` | Make Coins, then spend or count them | Coin token, `add_to_hand`, counters |
| Fortune | Jackpot | `jackpot` | Expensive swings that pay off big | `discover`, `repeat`, `transform` |
| Order | Formation | `formation` | Rewards for a full, ordered board | `adjacent`, board-size conditions, `aura` |
| Order | Aegis | `aegis` | Divine Shield and rewards for keeping it | `give_keyword`, `divine_shield` |
| Order | Oath | `oath` | Permanent buffs and healing | `buff`, `heal` |
| Shadow | Stealth | `stealth` | Hidden attackers that strike first | `stealth`, `give_keyword` |
| Shadow | Venom | `venom` | Poison trades up into big minions | `poisonous`, `on_attack` |
| Shadow | Ambush | `ambush` | Pay-offs for several cards in a turn | `cards_played_this_turn`, `return_to_hand` |

The Coin is a 0-cost token, `fortune_coin`: "Gain 1 mana this turn."

## 4. Archetypes for existing classes and neutral

| Set | Archetype | Tag | Plays as | Size |
| --- | --- | --- | --- | --- |
| War | Berserk | `berserk` | Minions that get stronger when damaged | 6 cards, 2 bundles |
| Decay | Plague | `plague` | Small damage to everything at end of turn | 6 cards, 2 bundles |
| Knowledge | Frost | `frost` | Freeze, with pay-offs against frozen enemies | 6 cards, 2 bundles |
| Neutral | Pack | `pack` | Cheap creatures that reward a wide board | 6 cards, 2 bundles |
| Neutral | Salvage | `salvage` | Value from returned and discarded cards | 6 cards, 2 bundles |

### New card counts

Existing classes keep every card they have and simply grow. War and Knowledge reach 32 cards, Decay
reaches 34, and new classes start at 25. None of those numbers is a limit.

Totals: about 75 class cards, 18 for existing classes, 12 neutral (105 new cards), and about 34 bundles.

## 5. Open growth and relative balance

### No content ceilings

| Today | Change |
| --- | --- |
| `hero_set_size`, `hero_set_size_tol`, `neutral_set_size` knobs | Deleted. No check ever counted cards against them; only the config values were range-checked (`neutral_set_size` to 35 to 60) |
| `max_records` fails the load above 5000 records | Removed |
| `RecordSchemas.SETS`, `HERO_SETS`, `BUNDLE_SETS` and the schema `enum` lists name every set | Derived from the `cards_<set>.json` files present |
| `MatchUiContext.SET_PRIMARY` and `SET_SECONDARY` map sets by hand | Read the `<set>` and `<set>2` palette tokens, with `neutral` as the fallback |
| Bundle themes and tags are checked against fixed lists | Derived from the tags the cards declare |
| Run log hero filters are a fixed row of buttons | Become one control that handles any number of classes |

Lower limits stay, because they keep the game working rather than limit growth: minimum draft pools, and a
class needing a starter deck and three powers.

### Checks that stay

These protect correctness, not balance, so they keep failing the build:

- Schemas, missing files, and references to ids that do not exist
- Effect validation
- Game rules: 15-card starter decks, 3-card bundles, three powers per class
- `text_max_chars`, because it decides whether rules text fits on a card

### Absolute balance checks are retired

Card budgets, curves and set share (`W_BUDGET`, `W_CURVE`, `W_SET_SHARE`) are already warnings and stay
that way, because a card far outside its point budget is still useful to know about.

The one absolute balance check that fails the build today is `E_STARTER_CURVE`. It becomes
`W_STARTER_CURVE`. `E_COVERAGE` stays: it is a minimum (keywords and ops have cards, bundles cover the
pool), not a ceiling.

### The relative balance report

A new `tools/balance.sh`, built on the `tools/sim.sh` match harness, plays AI matches and compares each
group with its own peers:

| Group | Compared with | Starting tolerance |
| --- | --- | --- |
| Class | Median win rate of all classes | 5 points |
| Hero power | Median of the three powers in its class | 5 points |
| Archetype | Median of all archetypes in its class or neutral pool | 7 points |
| Boss | Median of the bosses in its band | 7 points |

- **Decks:** a class plays its starter deck, plus bundles of one archetype when testing that archetype. It
  plays matches against bosses rather than full runs, so no draft bot is needed.
- **Scale:** tolerances are relative to the median, so they work at any content size. Knobs live in
  `heroes_balance.json`.
- **Cost:** the number of matchups grows with content, so the tool samples them from a fixed seed, and
  `--class`, `--boss` or `--archetype` limit a run to what changed.
- **Result:** the report lists each group's rate, its gap from the median and any out of tolerance. The
  tool emits observations and a person decides what to do, which follows the project's helper script rule.
  It does not block a build.

AI matches measure how the AI plays, not how people play, so real pick and win data should replace or
adjust these numbers once it exists.

## 6. Engine and data changes

**One new effect condition.** There is no coin flip today. Add a condition form `{"flip": 50}` to
`EffectSchema.CONDITION_FORMS`, the validator and `EffectValues.holds`. It draws from
`engine.rng_match()`, like random selectors, so seeds and replays stay deterministic. The feed logs the
result.

**Data each new set adds.** After section 5, these are data entries and not code changes:

- `heroes_balance.json`: `plan_tags` and the balance tolerances
- `run_ui.json`, `match_ui.json`: palette tokens and strings (`theme.*`, `hero.blurb.*`, power text)
- `art_map.json`: `heroes`, `cards`, `fallback_set`, `powers`, and `treasures` if any are added
- Hero sting audio: `hero_sting_<id>` plays if present and is silently skipped if not

**Copy fix.** `unlock.condition.boss_defeated` reads "Defeat the boss {n} times", which is wrong when
any boss counts. Add an any-boss wording ("Defeat {n} bosses").

`owner.cards_played_this_turn` and `owner.board_size` are existing value references, so Ambush and
Formation need no engine work.

Divine Shield and Stealth can be granted by `give_keyword` and `buff`, so Ward, Garrote and Aegis need
no change. They cannot be granted by an aura (`AURA_UNGRANTABLE_KEYWORDS`), so Formation auras must not
use them.

**To confirm while planning**, each with a fallback:

| Check | If it fails |
| --- | --- |
| A card can read a counter held elsewhere, for Hoard | Count Coins in hand with a filter instead |
| A damaged-minion filter exists, for Berserk | Use `on_damage_taken` triggers only |
| The boss AI can evaluate `flip` and new powers | Score a flip as its average outcome |

## 7. Build order

1. **Open growth.** Remove the ceilings, derive sets from data, turn absolute checks into warnings, and
   build `tools/balance.sh`, with a baseline report for the three existing classes.
2. **Power system.** Data, unlocks, run flow, hero select redesign, and the six new powers for existing
   classes. Playable with 3 classes.
3. **Fortune.** The set, `flip`, Coin, bundles, unlock, powers, then a balance report.
4. **Order**, with a balance report.
5. **Shadow**, with a balance report.
6. **Archetypes.** Berserk, Plague, Frost, Pack, Salvage, with a balance report.
7. **Final balance and docs.** Tune classes, powers, archetypes and bosses against each other, then update
   `heroes.md`, `content.md`, the art bible, and `game-concept.md`, whose "Small" target is replaced by the
   open-growth rule.

## 8. Risks

- **Bosses need retuning.** They were tuned against three classes. The report shows whether any boss now
  sits apart from its band, and whether a new class outpaces them all.
- **Relative balance has a blind spot.** If everything drifts stronger together, every comparison stays
  level while the game gets easier. The report also prints overall win rates so that drift is visible,
  though no rule acts on it.
- **Nothing automatic stops a bad card.** With budgets as warnings, an overtuned card can ship if
  nobody reads the report.
- **Draft dilution.** More bundles means fewer chances of seeing a given archetype. Bundle offers are
  already filtered by class, so this mainly affects the growing neutral pool.
- **Load time.** Data load grows with content and nothing limits it. The final phase records a baseline
  so growth can be watched.
- **Test volume.** About 135 test files name existing hero ids, and some assume three heroes. Tests for
  retired ceilings and the hero select slots change with this spec, as a decided change of behaviour.

## 9. Testing

- **Each phase:** run the affected suites in the foreground, in chunks, because the full suite takes
  longer than one command allows.
- **Unit:** `flip` determinism from a fixed seed, power ownership and lock rejection, unlock rows,
  saved power round trip, default for old records.
- **Integration:** a locked power cannot start a run, a chosen power reaches the match, the hero select
  roster by keyboard and gamepad, and the drawer following the focused class.
- **Content:** structural validators across the new sets, and a fixture proving that a new set made only
  of data files loads and appears at hero select.
- **Balance tool:** a fixed-seed run gives the same report twice, and a deliberately overtuned fixture
  shows as out of tolerance.
- **Visual:** retained screenshots of hero select at 100 % and 150 %, the Unlocks screen, and a match for
  each new class.
