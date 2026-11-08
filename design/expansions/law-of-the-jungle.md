# Law of the Jungle

Date: 2026-11-07. Status: implemented; expansion checks passed. Broader regression
issues are recorded in the iteration log.

## Theme and design pillars

A prehistoric ecosystem has overtaken the dungeon: herd beasts, giant dinosaurs,
carnivorous plants, and explorers compete for the same dwindling resources.
Players use predators whose preferred prey can appear on either side of the
battlefield, then choose between an apex threat, a regenerating canopy, and a
coordinated hunt. Across the eight-boss run, early bundles supply prey and
predators together, later picks add class-specific payoffs, and treasures help
maintain a board or sequence prey before a predator. Keeping prey alive creates
an immediate tactical choice: take the trade now or preserve a future bonus.

- Make prey presence and attack order meaningful on both sides of the board.
- Give each class its own predators, support cards, and legendary pair.
- Make predators playable without their preferred prey.
- Read the visible board; avoid hidden family history or extra resources.
- Expand strategic choices within existing power budgets.

Expansion ID and installed directory: `law-of-the-jungle`,
`assets/data/law-of-the-jungle/`. This is a collection identity; existing card
`set` values continue to express class eligibility.

Original setting: [endgame expansion proposal](../../docs/superpowers/specs/2026-11-07-endgame-expansion-sets-design.md).
This document supersedes that proposal's Jungle card distribution, Food Chain
rules, legendary cycle, boss count, and trial objectives following owner feedback.

## Discovery checklist

- [x] Read `assets/data/heroes.json`: War, Decay, Knowledge, Fortune, Order, Shadow.
- [x] Read all eight `assets/data/cards_*.json` files: 342 records including tokens
  and boss cards. The skill's single `cards.json` does not exist in this build.
- [x] Capture all 15 printed keyword IDs and all 12 effect triggers below.
- [x] Skim all 20 treasures, 98 bundles, and 16 boss definitions for synergy hooks.
- [x] Search `design/` and `docs/` for expansion, set, and keyword conventions;
  read the existing collection proposal and current taxonomy review.
- [x] Inspect test instructions, content validation tests, and unlock tests.
- [x] Read the skill's schema, class-pie, mechanic, legendary, and unlock references;
  populate the current-build class-pie snapshot below instead of relying on its
  unfilled template.

Current printed keywords: `taunt`, `charge`, `rush`, `divine_shield`, `windfury`,
`stealth`, `lifesteal`, `poisonous`, `freeze`, `silence`, `battlecry`, `deathrattle`,
`spell_damage`, `discover`, `aura`.

Current effect triggers: `aura`, `battlecry`, `cast`, `deathrattle`, `on_attack`,
`on_card_played`, `on_damage_taken`, `on_minion_died`, `on_summon`, `passive_hand`,
`turn_end`, `turn_start`.

The runtime schema uses underscore IDs, `set`, `text: {key, en}`, and executable
`effects`; it accepts minions, spells, and weapons, with common, rare, and
legendary rarities. The skill's example `class`, hyphenated card IDs, string
`text`, and additional rarities do not describe the current loader contract.
Legendary playstyles, enablers, package roles, and item groups live in the
validated `collection.json` metadata. Runtime records retain their owning
schemas, with the additional `collection_id` field.

## Current class pie

These identities and limitations are design inferences from current cards,
hero powers, bundle themes, and the Heroes GDD. They are not engine restrictions.
The legendary inventory includes the current uncommitted content.

| Class | Identity and primary / secondary styles | Signature mechanics | Limitation | Existing legendary IDs |
| --- | --- | --- | --- | --- |
| War | Weapon pressure; aggro / tempo | Weapons, Armor, Rush, damaged-minion payoffs | Weapon plans spend hero health; damaged-board payoffs need survivors | `war_pit_champion`, `war_kingsblade`, `war_headsman`, `war_pit_tyrant`, `war_red_reckoning` |
| Decay | Recycle expendable bodies; sacrifice / attrition | Deathrattle, Husks, Poisonous, Lifesteal | Sacrifice spends board presence and depends on replenishment | `decay_husk_mother`, `decay_plaguebearer`, `decay_grave_titan`, `decay_morbane`, `decay_final_contagion` |
| Knowledge | Spell answers and hand resources; control / value | Spell Damage, Freeze, Discover, draw | Spell-heavy hands can lack bodies for family sequencing | `knowledge_star_reader`, `knowledge_grand_grimoire`, `knowledge_forbidden_tome`, `knowledge_ilyra`, `knowledge_whiteout` |
| Fortune | Coins and bounded gambles; value / combo | Coin generation, random damage, Discover | Random outcomes make exact lethal and stabilization less reliable | `fortune_fortunes_favorite`, `fortune_jackpot` |
| Order | Protect and improve a formation; summon / control | Divine Shield, Taunt, healing, adjacent buffs | Board-based bonuses lose value after clears | `order_ivory_bastion`, `order_high_warden`, `order_the_unbroken` |
| Shadow | Conceal threats and sequence burst turns; tempo / combo | Stealth, Poisonous, Rush, cards-played payoffs | Small concealed threats remain vulnerable to untargeted clears | `shadow_night_queen`, `shadow_ancient_wyrm`, `shadow_last_light` |

Rush appears on six non-boss card definitions; Lifesteal appears on three.
Both are candidates for additional support, subject to the mechanic design
pass. Existing rules must remain unchanged. In particular, Rush must not become
immediate hero damage, and Lifesteal must not be described as healing from buffs.

## Collection budget

The expansion has 138 collectible cards: 42 Neutral cards (30.4%) and
96 class-exclusive cards (69.6%). Each class receives 16 cards. No new Neutral
card is legendary.

| Eligibility | Common | Rare | Legendary | Total |
| --- | ---: | ---: | ---: | ---: |
| Neutral | 28 | 14 | 0 | 42 |
| War | 8 | 6 | 2 | 16 |
| Decay | 8 | 6 | 2 | 16 |
| Knowledge | 8 | 6 | 2 | 16 |
| Fortune | 8 | 6 | 2 | 16 |
| Order | 8 | 6 | 2 | 16 |
| Shadow | 8 | 6 | 2 | 16 |
| Total | 76 | 50 | 12 | 138 |

Each class has two six-card playstyle packages and four additional cards
supporting existing mechanics. Each package includes one legendary and five
non-legendary cards; all 16 slots are distinct. Existing canonical Neutral
legendaries are unchanged. Tokens and boss-only cards do not count toward
this budget.

| Per-class allocation | Common | Rare | Legendary | Total |
| --- | ---: | ---: | ---: | ---: |
| First new playstyle | 3 | 2 | 1 | 6 |
| Second new playstyle | 3 | 2 | 1 | 6 |
| First existing mechanic | 1 | 1 | 0 | 2 |
| Second existing mechanic | 1 | 1 | 0 | 2 |
| Total | 8 | 6 | 2 | 16 |

Each playstyle package contains two early enablers, one engine, one answer or
protection card, one recovery or consistency card, and its legendary payoff.
The five non-legendary cards must establish a functioning plan without drawing
the legendary. Shared Neutral cards supplement these packages; they do not
replace the class-exclusive enablers or the four existing-mechanic slots.

### Dedicated support for existing mechanics

| Class | First mechanic: two cards | Second mechanic: two cards |
| --- | --- | --- |
| War | Weapons and hero attacks | Damaged-minion payoffs (`berserk`) |
| Decay | Deathrattle | Sacrifice |
| Knowledge | Freeze | Spell Damage |
| Fortune | Coins (`hoard`) | Coin-flip effects (`gamble`) |
| Order | Divine Shield | Formation and adjacent buffs |
| Shadow | Stealth | Poisonous |

These four cards per class must function in existing decks without requiring
Predator or a new legendary. They may also bridge into a new playstyle, but
cannot be double-counted as one of its six dedicated cards. Existing mechanic
rules remain unchanged. Validate these 24 support slots separately from the
60 non-legendary cards in the new class playstyle packages.

The three themes remain Apex Succession (large threats), Living Canopy
(resilience and recovery), and Primal Hunt (pressure and attack sequencing).
Each receives 14 Neutral cards: six early plays or prey producers, three
engines, three answers or protection cards, and two recovery or consistency
cards. This provides 42 shared cards with no shared legendary finishers.
Each class builds its two six-card packages around its two legendary directions
below, drawing on these themes. No class is required to have an exclusive
finisher for every theme.

Build 14 distinct three-card bundles per class: seven for each new playstyle.
This yields 84 class bundle definitions; Neutral support is reused across legal
bundles. Each bundle contains a class-exclusive card and legal class or Neutral
support. Across each class's bundle library, include all 16 exclusive cards and
place each existing-mechanic support card in at least two compatible bundles.
Prey and predator access must be established in early bundles without requiring
a legendary. The 14 definitions are offer variety, not extra picks: the run
still has seven bundle picks alongside its starter deck and core offers.
The previous guarantee of three universally complete Neutral archetypes is retired.

Each class can use 58 distinct expansion cards (42 Neutral plus 16 exclusive).
Draft construction must verify actual offers and repeat-card behavior before
claiming a viable 36-card run deck; starter and core cards remain relevant.
Three themed treasures and two new dungeon bosses complete the package.

### Class-exclusive legendary directions

The original six shared finishers move to class ownership; six additional
finishers provide the remaining class pairs.

| Class | Legendary minion | Playstyle | Legendary spell | Playstyle |
| --- | --- | --- | --- | --- |
| War | Gorath, Crown of the Canopy | tempo | Extinction March | aggro |
| Decay | The Worldroot | attrition | Verdant Reclamation | sacrifice |
| Knowledge | Tala, Fossil Savant | value | The Amber Archive | control |
| Fortune | Vexa, Trophy Broker | value | Winner Takes the Wild | combo |
| Order | Bastionback Matriarch | summon | The Last Refuge | control |
| Shadow | Sava, the Hundred Tracks | tempo | The Great Hunt | combo |

Each legendary has four named legal non-legendary enablers in the
[card and balance ledger](law-of-the-jungle/card-ledger.md), which contains the
complete card list, package roles, recurring engines, and balance reviews.
The loader validates those references, ownership, and non-legendary rarity.

## Predator

**Rules text:** Predator (tribe): When played, resolve the listed bonus if
another minion of that tribe is on either side of the battlefield.

Choose prey presence over mandatory sacrifice. It lets players establish prey
on their own board, exploit an opponent's board, and decide when to kill a
matching minion. Sacrificing any enemy prey would combine a payoff with removal
and punish ordinary tribe choices too heavily. Consuming friendly bodies remains
available to Decay through its existing sacrifice tools.

Predator is a named Battlecry pattern, not a new turn counter or persistent
resource. Each predator prints one preferred prey tribe and one bonus. Test the
live board once when that Battlecry effect resolves, before the card's bonus
operations; no other effect on that card should change the board before its
Predator check. A successful check applies the bonus once and spends no prey.

- Either player's matching minion qualifies; the predator itself never does.
- More than one matching prey still grants only one bonus.
- Tokens qualify by printed tribe. Multi-tribe minions qualify if any tribe matches.
- A silenced prey keeps its printed tribes. Stealthed prey also qualifies because
  this is a presence check, not a chosen target. Normal targeting still applies
  to any separately targeted bonus.
- Dying, destroyed, bounced, or transformed-away prey does not qualify when the
  check resolves. A later prey departure does not revoke a resolved bonus.
- Direct summons, copies summoned into play, and transformations do not trigger
  Predator. Returning a predator to hand and paying to play it again checks anew.
- Silencing a predator removes removable stat or keyword buffs normally; it
  cannot undo an already completed draw, heal, or damage effect.
- No prey means a normal body with no Predator bonus. Cards must be costed to
  remain reasonable in that state, with modest, bounded bonuses when enabled.

Teaching common: **Canopy Stalker**, a 3-mana 3/3 Beast with
`Predator (Plant): Gain +1/+1.` A friendly Seedling or an enemy Plant enables
the bonus; a second Beast does not. This replaces the earlier Canopy Scout example.
Dinosaurs use the existing Beast tribe; Plant is already registered. No new
family or Dinosaur tribe is required for this design.

### Existing implementation path

The current effect language already supports a `battlecry`, an `exists`
condition, `all_minions`, and the `tribe` and `not_self` filters. For example,
the teaching card's effect can use:

```json
{
  "trigger": "battlecry",
  "condition": {
    "exists": {
      "selector": "all_minions",
      "filter": {"tribe": "plant", "not_self": true}
    }
  },
  "targets": "self",
  "ops": [{"op": "buff", "attack": 1, "health": 1}]
}
```

The installed cards use this effect pattern and the existing `battlecry`
keyword. Real-engine tests cover the pattern and every authored card. Successful
Predator resolutions record the enabling board or boards in `effect_resolved`;
the trial derives its objectives from those events rather than UI counters.

The closest existing mechanic is a conditional Battlecry. Predator gives that
pattern a consistent cross-board prey condition, using printed tribes instead
of draft tags, hand size, or cards played this turn. Its novelty is the board
decision and card ecosystem, not a new engine resource.

### Run support and counterplay

Early picks offer prey producers with independently useful predators. Mid-run
picks add class-specific answers and protection. Late bosses demand useful
baseline bodies and recoverable prey sources so sweepers do not disable the
entire deck. Avoid compulsory prey dependencies on legendary cards.

`treasure_bottomless_satchel` and `treasure_vanguards_banner` help sequence a
prey card before its predator. Existing `pack` bundles supply Beast bodies for
Beast-prey predators; the `pack` draft tag itself is not a tribe. Plant prey
needs new, accessible producers because only one current unit definition is Plant.

Rush retains its existing rule: "May attack minions on the turn it enters play."
Brush Raptor, Thorn Runner, and Razorbeak supply shared Rush support, with
additional class finishers in Gorath and Sava. Lifesteal retains its existing
rule: "Damage dealt by this source heals its controller's hero by the same
amount." Mossjaw and Rain Drinker combine that recovery with Predator bonuses.
Neither mechanic's rules have changed.

## New run items

These items enter the featured collection's ordinary treasure pool. The existing
treasure installer prevents duplicate installation; each recurring effect has
its normal owner-turn timing and no additional activation path.

| Item | Group / rarity | Effect and design purpose |
| --- | --- | --- |
| Trailkeeper's Compass | Mechanic support / rare | Start each match with a 1/1 Plant in play and a 1/1 Beast in hand. Establishes prey without requiring a legendary; provides bodies even without Predator. |
| Patient Watchglass | Gap filling / common | Ending your turn with at least two unspent Mana grants two Armor. Makes holding mana a defensive choice, with an opportunity cost absent from Mending Charm. |
| Last Ration | Gap filling / rare | If your hand is empty at your turn's start, draw one additional card before the ordinary draw. Supports depleted hands instead of Scholar's Candle's fixed turn schedule. |

No item counts toward both groups or toward the 138 collectible cards. The
ledger records closest-item comparisons; runtime tests cover effects, duplicate
installation, owner timing, thresholds, and operation without Predator.

## New dungeon bosses

Two new bosses actively play Predator cards. Their complete 30-card decks
supply their own prey and can also benefit from matching player minions. Briarjaw
has 30 Health in band 1; Veyra has 40 Health in band 2. Both use the existing
tempo AI. Briarjaw grows a Plant at the end of its turn; Veyra replenishes a
Beast only when none remains on its board. That condition avoids an unlimited
extra swarm while preserving its prey supply and a player removal window.

| Boss | Band | New-mechanic plan | Player counterplay |
| --- | ---: | --- | --- |
| Briarjaw, Nursery Stalker (`boss_briarjaw`) | 1 | Cheap Plants enable Plant-prey predators with small stat bonuses. The deck includes multiple Plant producers and predators, teaching the condition before larger payoffs. | Remove Plants before the next boss turn, contest the modest baseline bodies, or save an answer for a buffed predator. |
| Veyra, Keeper of the Hunt (`boss_veyra`) | 2 | Beast prey supports a mixed pack of Beast-prey predators with bounded defensive and pressure bonuses. AI should play prey first and evaluate player Beasts as alternative enablers. | Deny the boss's prey and time removal of your own endangered Beasts; use durable bodies and recovery to outlast its finite payoffs. |

Keep prey IDs and conditional bonuses visible in card text and normal intent
previews. No encounter may secretly consume or destroy player minions to pay
for Predator. Boss-only cards stay outside the collectible budget.

Tests exercise Predator cards from both actual decks with friendly prey, enemy
prey, and no prey. Both bosses enter the featured encounter pool, and the
authored loaner playthrough faces their real AI and passives.

## Unlock and mastery trial

Unlocking the collection requires all of:

- 20 lifetime run victories.
- Two victories with each of `hero_war`, `hero_decay`, `hero_knowledge`,
  `hero_fortune`, `hero_order`, and `hero_shadow`.
- Completion of the three-encounter **Primal Crown** mastery trial in one attempt.

In each trial encounter, resolve
at least three Predator bonuses, including one enabled by friendly prey and one
enabled by enemy prey, then win. Count a successful activation once even if
both boards contain matching prey. The trial uses a curated 36-card loaner deck
and three loaner treasures, with immediate retry. Its scripted deck access and
enemy lineups must make both prey sources available; no objective may rely on
a random tribe appearing. The legal Order/Neutral loaner includes durable late
threats, recovery, and both Order legendaries, with a prescribed draw prefix.

The trial faces Briarjaw, Veyra, and a Veyra rematch with a curated deck variant.
The rematch is a trial configuration, not a third new dungeon boss. Its loaner,
treasures, encounter rules, starting prey, and access progress can be inspected
from the Expansions screen before beginning.

The installed gate uses `all_of`, existing `runs_won` leaves, and the new
`trial_completed` condition. This is the selected endgame design's explicit
exception to the skill's first-three-runs accessibility default. Total wins
establish experience, wins with every class establish breadth, and the trial
requires using the new mechanic successfully in combat.

### Runtime and persistence

`collections.json` registers the expansion's separate data files with the sole
game-data loader. Class `set` still controls class legality. Starting an ordinary
run checks the unlock, saves its featured collection, and snapshots eligible
bundle and treasure pools. Core-only runs exclude expansion rewards and bosses;
Discover and generation obey the match's collection context, including AI clones.

The trial has its own `active_trial` profile slot and never enters ordinary run
statistics. Resume replays accepted commands to reconstruct objectives and
state; saved counters are not trusted. Completed encounters, pending AI plans,
AI RNG state, and forecasts survive resume. Collection grants and trial completion
are written atomically and announced only after a successful save, with a
versioned attempt source ID preventing duplicate rewards.

Reach the collection selector and Primal Crown through **New run → Expansions**.
After unlocking, select Law of the Jungle beside the seed field before starting
an ordinary run. An existing run's selection does not change when more content
is unlocked.

## Validation

The real content validator loads 734 records with zero errors. Structural audits
check 138 collectibles, all package and rarity budgets, 84 legal bundles, two
bosses, three distinct run items, and the 36-card trial. Authored card tests sweep
rich and bare boards from both sides; additional tests cover the mechanic,
engines, items, boss activation, collection access, resume, and atomic grants.
The final regression results and seven skill gates are recorded in the
[iteration log](law-of-the-jungle/iterations.md).

## Playtest notes

The automated loaner test completes all three authored encounters using legal
commands against the real enemy AI. Every victory meets all objectives; ordinary
run victories remain unchanged. The earlier loaner was too concentrated in small
minions, and Veyra's unconditional spawn created excessive attrition. The final
loaner adds late threats and Order finishers, and Veyra only replenishes missing
prey. The test does not force damage, skip objectives, or grant wins.

The ledger contains the full boss-roster read-through and class-specific risks.
Its raw-stat audit flags 27 bodies beyond one standard deviation of the existing
same-cost/rarity curve and documents their utility costs or bounded advantages.
Legendary effect reviews and item comparisons remain qualitative; this is not
a claim of measured class win-rate parity or completed human balance testing.

## Watchlist

Monitor recurring engine snowballs, Veyra's band-2 pressure, the lifetime unlock
thresholds, and card-draw interactions with Last Ration. New cards use the
existing art fallback. Existing approximate-budget warnings and Godot shutdown
resource diagnostics are tracked separately from failing gameplay checks.
