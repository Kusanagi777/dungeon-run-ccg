# Law of the Jungle card and balance ledger

The staged source is `tools/content/jungle_content.py`; regenerate with Python,
then run it with `--check` to verify generated JSON and structural invariants.

## Collection and package checks

- 138 collectible cards: 42 Neutral (28 common, 14 rare), 16 per class (8/6/2).
- Each class has two distinct six-card packages and four separate legacy cards.
- All 84 bundles contain three distinct legal cards and a class card. Every class
  card is offered; every legacy slot appears twice; all 42 shared cards appear.
- Bundle themes are Primal Hunt (War/Shadow), Living Canopy (Decay/Order), and
  Apex Succession (Knowledge/Fortune). Only the two generic one-cost prey bridge
  all three themes. Other shared cards retain their actual family.

## Legendary plans and engines

| Class | Legendary | Plan | Non-legendary enablers |
| --- | --- | --- | --- |
| War | Gorath, Crown of the Canopy | tempo | Trail Squire, Redcrest Hatchery, Canopy Challenger, Trophy Quartermaster |
| War | Extinction March | aggro | Spearleaf, Ridge Charger, Stampede Drummer, Rally the Hunt |
| Decay | The Worldroot | attrition | Rotting Bulb, Mire Nibbler, Compost Keeper, Mire Reclaimer |
| Decay | Verdant Reclamation | sacrifice | Spore Offering, Carrion Gardener, Root Feaster, Compost Ledger |
| Knowledge | Tala, Fossil Savant | value | Field Scholar, Amber Specimen, Fossil Reader, Catalogue Keeper |
| Knowledge | The Amber Archive | control | Amber Seed, Quillback Student, Canopy Observer, Shelved Discovery |
| Fortune | Vexa, Trophy Broker | value | Trophy Forager, Gilded Nest, Amber Appraiser, Jungle Pawnbroker |
| Fortune | Winner Takes the Wild | combo | Coinleaf, Prize Raptor, Wager Caller, Cached Winnings |
| Order | Bastionback Matriarch | summon | Nursery Squire, Sacred Seedbed, Herd Captain, Nursery Roll Call |
| Order | The Last Refuge | control | Refuge Sprout, Bastion Grazer, Spring Warden, Canopy Hospitaller |
| Shadow | Sava, the Hundred Tracks | tempo | Reed Whisper, Dusk Hatchling, Shade Raptor, Trail Informant |
| Shadow | The Great Hunt | combo | Scent Leaf, Scent Lurker, Hunt Signaller, Circle Back |

Every dedicated engine has a continuing effect. Challenger generates Armor on
attacks; Root Feaster grows from Plant deaths; Fossil Reader grows Plant boards
from spells; Appraiser converts Beast deaths into Coins; Shade Raptor conceals
another friendly minion after attacking. Each can trigger on later turns without
a legendary. The other seven engines use auras or printed recurring triggers.

## Raw-stat audit

Compare Attack + Health to all current non-token, non-boss canonical minions at
the same cost and rarity. Use population standard deviation; exactly zero
deviation still flags any difference. Legendary bodies are excluded. This is a
screen for review, not an effect valuation or a win-rate simulation.

27 bodies exceed one standard deviation. The three above-curve flags
are intentional and individually compared below. The remaining bodies spend
their budget on the exact printed utility shown; none has a hidden compensation.

| Card | Stat total | Canonical mean ± σ | Review / compensation |
| --- | ---: | ---: | --- |
| Nest Tender | 3 | 3.91 ± 0.77 | Lower body pays for: Battlecry: Summon a 1/1 Beast. |
| Amber Grazer | 5 | 3.91 ± 0.77 | Vanilla 2/3 matches core Cellar Guard; Beast is a sidegrade that can enable either player's Predator. |
| Fossil Excavator | 8 | 8.91 ± 0.67 | Lower body pays for: Battlecry: Draw a card. |
| Sheltered Colossus | 13 | 14.00 ± 0.00 | Lower body pays for: Predator (Plant): Restore 4 Health to your hero. |
| Spore Nursery | 3 | 3.91 ± 0.77 | Lower body pays for: Battlecry: Summon a 1/1 Plant. |
| Jungle Pathfinder | 3 | 3.91 ± 0.77 | Lower body pays for: Battlecry: Add a 1/1 Beast to your hand. |
| Chase Caller | 6 | 7.05 ± 0.88 | Lower body pays for: Battlecry: Give another friendly Beast Rush. |
| Razorbeak | 8 | 8.91 ± 0.67 | Lower body pays for: Rush. Predator (Beast): Gain +1/+1. |
| Redcrest Hatchery | 3 | 3.91 ± 0.77 | Lower body pays for: Battlecry: Summon a 1/1 Beast. |
| Ridge Bladesmith | 6 | 5.12 ± 0.73 | 2/4 defensive weapon engine: requires an actual hero attack; +1 Attack capped once per turn. No immediate attack or free weapon. |
| Scarhide Veteran | 8 | 7.05 ± 0.88 | 3/5 at four mana is within core common body ranges; its class-rare bonus needs damaged survivors and adds no Health or direct damage. |
| Rotting Bulb | 2 | 2.55 ± 0.50 | Lower body pays for: Deathrattle: Summon a 1/1 Plant. |
| Mire Reclaimer | 8 | 8.91 ± 0.67 | Lower body pays for: Predator (Beast): Add two 1/1 Plants to your hand. |
| Carrion Gardener | 3 | 3.91 ± 0.77 | Lower body pays for: Battlecry: Summon a 1/1 Plant. |
| Fossil Reader | 4 | 5.33 ± 0.77 | Lower body pays for: Predator (Beast): Draw a card. After you cast a spell, summon a 1/1 Plant. (1/turn) |
| Amber Seed | 2 | 2.55 ± 0.50 | Lower body pays for: Deathrattle: Add a 1/1 Plant to your hand. |
| Prism Moth | 3 | 3.91 ± 0.77 | Lower body pays for: Spell Damage +1. |
| Coinleaf | 2 | 2.55 ± 0.50 | Lower body pays for: Deathrattle: Add a Coin to your hand. |
| Nursery Squire | 2 | 2.55 ± 0.50 | Lower body pays for: At the end of your turn, restore 1 Health to adjacent minions. |
| Sacred Seedbed | 3 | 3.91 ± 0.77 | Lower body pays for: Battlecry: Summon a 1/1 Plant. |
| Refuge Sprout | 2 | 2.55 ± 0.50 | Lower body pays for: Deathrattle: Gain 2 Armor. |
| Canopy Hospitaller | 8 | 8.91 ± 0.67 | Lower body pays for: Predator (Beast): Restore 5 Health to your hero. |
| Amber Aegis | 3 | 3.91 ± 0.77 | Lower body pays for: Divine Shield. |
| Reed Whisper | 2 | 2.55 ± 0.50 | Lower body pays for: Stealth. |
| Dusk Hatchling | 3 | 3.91 ± 0.77 | Lower body pays for: Deathrattle: Summon a 1/1 Beast. |
| Scent Leaf | 2 | 2.55 ± 0.50 | Lower body pays for: Deathrattle: Draw a card. |
| Sap Viper | 3 | 3.91 ± 0.77 | Lower body pays for: Poisonous. |

Legendary envelope review: Gorath and Extinction March need a board and offer
bounded tempo; Worldroot has removable recurring bodies and Reclamation resets
its own board; Tala/Vexa draw finite cards, while Archive transforms rather than
silences opposing Deathrattles. Matriarch is board-cap limited; Last Refuge cannot
revive a cleared board. Sava is one shielded trade; Great Hunt and Winner require
paid sequencing for their additional burst. No legendary reduces its own cost,
repeats hero damage indefinitely, or creates an unbounded mana loop.

## Run-item audit

All three are new treasure IDs, offered only under the collection's eligibility
and existing treasure selection rules. Duplicate IDs install once. They carry no
extra persistent counters; save/resume uses the normal treasure IDs/state path.

| Item | Group / rarity | Missing role and closest existing item | Limits and budget |
| --- | --- | --- | --- |
| Trailkeeper's Compass | Mechanic support / rare | Deliberate cross-tribe opening. Bottomless Satchel gives two real cards but no guaranteed prey; Compass gives a Plant body and a low-power Beast token in hand. | Once at match start; board and hand caps apply. No hidden Predator payoff. Removing the Plant disables Plant bonuses. |
| Patient Watchglass | Independent gap fill / common | Rewards holding Mana. Mending Charm heals every turn; this stores Armor but requires sacrificing at least two available Mana. | Exactly 2 Armor at owner end step if Mana ≥ 2. No damage trigger and no requirement for a minion or Predator. |
| Last Ration | Independent gap fill / rare | Empty-hand recovery for low-curve decks. Scholar's Candle guarantees two timed draws; Ration can draw over multiple turns but only when empty before the normal draw. | One extra card at owner start step, existing deck/fatigue/hand rules. No cost reduction, bonus Mana, or automatic emptying of hand. |

## Encounters and trial

Briarjaw (band 1, 30 Health) supplies Plant tokens; Veyra (band 2, 40 Health)
supplies Beast tokens. Each deck has 30 real cards, cheap prey and multiple
Predators. Tokens appear at boss turn end, allowing the player to clear them
before the next Predator. Intent text exposes this timing and counterplay.

The three Primal Crown encounters use Briarjaw, Veyra, and a faster mixed-prey
Veyra deck variant. The 36-card Order loaner is legal without owning the set.
Its fixed opening/draw prefix includes three cheap predators and friendly prey.
Each encounter explicitly begins with both enemy prey tribes, and Compass
provides friendly Plant prey plus a Beast in hand. The objective counts bonuses
once even when both boards qualify; it also requires winning each encounter.

## Roster read-through and limits

These are design checks, not observed class win rates. All six class pairs are
draftable through their own seven-bundle package libraries and work without
drawing their legendary. Starter/core cards still provide the other run picks.

| Opponent group | Plans and counterplay |
| --- | --- |
| Torchbearer / Rat King | Small prey contest the opening. War/Shadow trade then pressure; Decay/Order recover; Knowledge/Fortune draw with real bodies. Expensive legends are finishers, never required early. |
| Gatekeeper / Hollow King / Cellar Hermit / Blood Abbess | Wide spell damage and finite transform/removal answer protection and recovery. War/Shadow need to trade through Taunt; Decay/Order rebuild, Knowledge/ Fortune replenish resources. Tokens and conditional stats alone do not bypass defense. |
| Rot Warden / Bog Witch | Deathrattle boards punish indiscriminate clears. War/Shadow use initiative; Decay/Order can match replacement bodies; Knowledge's Archive and Fortune's bounce let the player select favorable trades without requiring a specific enemy tribe. |
| Frost Hag / Lich Archivist / Mirror Sage / Shadow of the Delve / Dungeon Heart | Canopy deathrattles replenish prey; core draw and Archive/Ration recover resources. War's wide buff and Shadow's burst need surviving bodies; Decay/Order can grind but are vulnerable to clears; Knowledge/Fortune need proactive bodies alongside draw. Shield and Stealth do not stop untargeted damage. |
| Scrap Golem / Pyre Sergeant / Iron Tollman | Taunts, healing, Watchglass and initiative offer counterplay to weapon pressure and Armor. War/Shadow can apply sustained attacks; Decay/Order can recover; Knowledge/Fortune need actual board damage. Fragile prey and repeat engines are removable; no card disables all hero attacks. |
| Briarjaw / Veyra | All six classes can play against enemy-provided prey. Clear end-step prey to deny bonuses; leaving it alive rewards sequencing at a real board cost. The bosses also carry their own baseline bodies. |

No card needs an enemy-only tribe to function: Predator cards have normal bodies,
and every preferred tribe has cheap friendly access. No unconditional spell kills
a boss hero or ignores its Health. Effects remain finite under board/hand/Mana
caps. Actual runtime sweep, item rules, boss windows, unlock replay, and authored
trial reachability are separate test gates and must be reported from their runs.

## Complete card ledger

| Card | Class | Rarity | Cost | Body | Package / role |
| --- | --- | --- | ---: | --- | --- |
| Seedling Keeper | neutral | common | 1 | 1/2 | apex_succession / enabler |
| Nest Tender | neutral | common | 2 | 1/2 | apex_succession / enabler |
| Canopy Stalker | neutral | common | 3 | 3/3 | apex_succession / enabler |
| Amber Grazer | neutral | common | 2 | 2/3 | apex_succession / enabler |
| Thornback Yearling | neutral | common | 3 | 2/4 | apex_succession / enabler |
| Fossil Sprout | neutral | common | 2 | 1/3 | apex_succession / enabler |
| Trophy Sifter | neutral | common | 4 | 3/4 | apex_succession / engine |
| Ancient Browser | neutral | common | 5 | 4/5 | apex_succession / engine |
| Canopy Cartographer | neutral | rare | 4 | 2/5 | apex_succession / engine |
| Crushing Tail | neutral | common | 4 | Spell | apex_succession / answer |
| Boulderhide | neutral | rare | 6 | 4/7 | apex_succession / answer |
| Amber Shell | neutral | rare | 2 | Spell | apex_succession / answer |
| Fossil Excavator | neutral | rare | 5 | 3/5 | apex_succession / recovery |
| Sheltered Colossus | neutral | common | 7 | 6/7 | apex_succession / recovery |
| Fern Hopper | neutral | common | 1 | 1/2 | living_canopy / enabler |
| Spore Nursery | neutral | common | 2 | 1/2 | living_canopy / enabler |
| Root Watcher | neutral | common | 2 | 2/2 | living_canopy / enabler |
| Shelter Fern | neutral | common | 3 | 1/5 | living_canopy / enabler |
| Regrowth Runner | neutral | common | 3 | 3/2 | living_canopy / enabler |
| Scattered Seeds | neutral | common | 2 | Spell | living_canopy / enabler |
| Rainfall Herbalist | neutral | rare | 3 | 2/3 | living_canopy / engine |
| Waking Banyan | neutral | common | 5 | 3/6 | living_canopy / engine |
| Mossjaw | neutral | rare | 4 | 3/4 | living_canopy / engine |
| Vine Sentry | neutral | common | 4 | 2/5 | living_canopy / answer |
| Tangled Path | neutral | common | 3 | Spell | living_canopy / answer |
| Canopy Medic | neutral | rare | 4 | 3/4 | living_canopy / answer |
| Seed Reserve | neutral | rare | 3 | Spell | living_canopy / recovery |
| Rain Drinker | neutral | rare | 6 | 4/6 | living_canopy / recovery |
| Reed Ambusher | neutral | common | 2 | 2/2 | primal_hunt / enabler |
| Trail Falcon | neutral | common | 1 | 2/1 | primal_hunt / enabler |
| Nest Guard | neutral | common | 2 | 2/2 | primal_hunt / enabler |
| Brush Raptor | neutral | common | 3 | 3/2 | primal_hunt / enabler |
| Thorn Runner | neutral | common | 3 | 2/3 | primal_hunt / enabler |
| Jungle Pathfinder | neutral | common | 2 | 2/1 | primal_hunt / enabler |
| Pack Outrider | neutral | rare | 4 | 3/4 | primal_hunt / engine |
| Scent Tracker | neutral | rare | 3 | 2/3 | primal_hunt / engine |
| Chase Caller | neutral | rare | 4 | 3/3 | primal_hunt / engine |
| Coordinated Pounce | neutral | common | 2 | Spell | primal_hunt / answer |
| Razorbeak | neutral | rare | 5 | 4/4 | primal_hunt / answer |
| Guard the Nest | neutral | common | 2 | Spell | primal_hunt / answer |
| Expedition Supplier | neutral | common | 4 | 3/3 | primal_hunt / recovery |
| Follow the Tracks | neutral | rare | 3 | Spell | primal_hunt / recovery |
| Trail Squire | war | common | 1 | 1/2 | crown_tempo / enabler |
| Redcrest Hatchery | war | common | 2 | 2/1 | crown_tempo / enabler |
| Canopy Challenger | war | common | 3 | 3/3 | crown_tempo / engine |
| Hold the Ridge | war | rare | 2 | Spell | crown_tempo / answer |
| Trophy Quartermaster | war | rare | 4 | 3/4 | crown_tempo / recovery |
| Gorath, Crown of the Canopy | war | legendary | 7 | 6/6 | crown_tempo / legendary |
| Spearleaf | war | common | 1 | 2/1 | extinction_aggro / enabler |
| Ridge Charger | war | common | 2 | 2/2 | extinction_aggro / enabler |
| Stampede Drummer | war | common | 3 | 2/3 | extinction_aggro / engine |
| Break the Thicket | war | rare | 3 | Spell | extinction_aggro / answer |
| Rally the Hunt | war | rare | 3 | Spell | extinction_aggro / recovery |
| Extinction March | war | legendary | 7 | Spell | extinction_aggro / legendary |
| Bone Honing | war | common | 1 | Spell | legacy_weapons / legacy_support |
| Ridge Bladesmith | war | rare | 3 | 2/4 | legacy_weapons / legacy_support |
| Battle Scars | war | common | 2 | Spell | legacy_berserk / legacy_support |
| Scarhide Veteran | war | rare | 4 | 3/5 | legacy_berserk / legacy_support |
| Rotting Bulb | decay | common | 1 | 1/1 | worldroot_attrition / enabler |
| Mire Nibbler | decay | common | 2 | 2/2 | worldroot_attrition / enabler |
| Compost Keeper | decay | common | 3 | 2/3 | worldroot_attrition / engine |
| Strangling Roots | decay | rare | 4 | Spell | worldroot_attrition / answer |
| Mire Reclaimer | decay | rare | 5 | 3/5 | worldroot_attrition / recovery |
| The Worldroot | decay | legendary | 8 | 5/8 | worldroot_attrition / legendary |
| Spore Offering | decay | common | 1 | 1/2 | verdant_sacrifice / enabler |
| Carrion Gardener | decay | common | 2 | 1/2 | verdant_sacrifice / enabler |
| Root Feaster | decay | common | 3 | 2/3 | verdant_sacrifice / engine |
| Feed the Thicket | decay | rare | 2 | Spell | verdant_sacrifice / answer |
| Compost Ledger | decay | rare | 3 | Spell | verdant_sacrifice / recovery |
| Verdant Reclamation | decay | legendary | 6 | Spell | verdant_sacrifice / legendary |
| Sporebound Relic | decay | common | 2 | 1/3 | legacy_deathrattle / legacy_support |
| Buried Echo | decay | rare | 3 | Spell | legacy_deathrattle / legacy_support |
| Fertile Bargain | decay | common | 1 | Spell | legacy_sacrifice / legacy_support |
| Offering Warden | decay | rare | 4 | 3/4 | legacy_sacrifice / legacy_support |
| Field Scholar | knowledge | common | 1 | 1/2 | fossil_value / enabler |
| Amber Specimen | knowledge | common | 2 | Spell | fossil_value / enabler |
| Fossil Reader | knowledge | common | 3 | 1/3 | fossil_value / engine |
| Amber Encasement | knowledge | rare | 3 | Spell | fossil_value / answer |
| Catalogue Keeper | knowledge | rare | 4 | 3/4 | fossil_value / recovery |
| Tala, Fossil Savant | knowledge | legendary | 6 | 4/6 | fossil_value / legendary |
| Amber Seed | knowledge | common | 1 | 1/1 | archive_control / enabler |
| Quillback Student | knowledge | common | 2 | 2/2 | archive_control / enabler |
| Canopy Observer | knowledge | common | 3 | 2/4 | archive_control / engine |
| Amberwave | knowledge | rare | 5 | Spell | archive_control / answer |
| Shelved Discovery | knowledge | rare | 4 | Spell | archive_control / recovery |
| The Amber Archive | knowledge | legendary | 8 | Spell | archive_control / legendary |
| Cold Fossil | knowledge | common | 2 | Spell | legacy_frost / legacy_support |
| Rime Excavator | knowledge | rare | 4 | 3/4 | legacy_frost / legacy_support |
| Prism Moth | knowledge | common | 2 | 1/2 | legacy_spell_damage / legacy_support |
| Fossil Burst | knowledge | rare | 4 | Spell | legacy_spell_damage / legacy_support |
| Trophy Forager | fortune | common | 1 | 1/2 | trophy_value / enabler |
| Gilded Nest | fortune | common | 2 | 1/3 | trophy_value / enabler |
| Amber Appraiser | fortune | common | 3 | 2/3 | trophy_value / engine |
| Trophy Exchange | fortune | rare | 3 | Spell | trophy_value / answer |
| Jungle Pawnbroker | fortune | rare | 4 | 3/4 | trophy_value / recovery |
| Vexa, Trophy Broker | fortune | legendary | 6 | 4/5 | trophy_value / legendary |
| Coinleaf | fortune | common | 1 | 1/1 | wild_combo / enabler |
| Prize Raptor | fortune | common | 2 | 2/2 | wild_combo / enabler |
| Wager Caller | fortune | common | 3 | 2/3 | wild_combo / engine |
| Weighted Snare | fortune | rare | 2 | Spell | wild_combo / answer |
| Cached Winnings | fortune | rare | 3 | Spell | wild_combo / recovery |
| Winner Takes the Wild | fortune | legendary | 6 | Spell | wild_combo / legendary |
| Amber Prospector | fortune | common | 2 | 2/2 | legacy_hoard / legacy_support |
| Buried Purse | fortune | rare | 2 | Spell | legacy_hoard / legacy_support |
| Fossil Gambler | fortune | common | 3 | 3/3 | legacy_gamble / legacy_support |
| Wild Odds | fortune | rare | 3 | Spell | legacy_gamble / legacy_support |
| Nursery Squire | order | common | 1 | 1/1 | matriarch_summon / enabler |
| Sacred Seedbed | order | common | 2 | 1/2 | matriarch_summon / enabler |
| Herd Captain | order | common | 3 | 2/3 | matriarch_summon / engine |
| Shelter the Young | order | rare | 2 | Spell | matriarch_summon / answer |
| Nursery Roll Call | order | rare | 3 | Spell | matriarch_summon / recovery |
| Bastionback Matriarch | order | legendary | 7 | 4/7 | matriarch_summon / legendary |
| Refuge Sprout | order | common | 1 | 1/1 | refuge_control / enabler |
| Bastion Grazer | order | common | 2 | 2/2 | refuge_control / enabler |
| Spring Warden | order | common | 3 | 2/4 | refuge_control / engine |
| Keeper's Judgment | order | rare | 4 | Spell | refuge_control / answer |
| Canopy Hospitaller | order | rare | 5 | 3/5 | refuge_control / recovery |
| The Last Refuge | order | legendary | 7 | Spell | refuge_control / legendary |
| Amber Aegis | order | common | 2 | 1/2 | legacy_aegis / legacy_support |
| Renew the Guard | order | rare | 3 | Spell | legacy_aegis / legacy_support |
| Trail Standard | order | common | 2 | 1/3 | legacy_formation / legacy_support |
| Canopy Marshal | order | rare | 4 | 3/4 | legacy_formation / legacy_support |
| Reed Whisper | shadow | common | 1 | 1/1 | tracks_tempo / enabler |
| Dusk Hatchling | shadow | common | 2 | 2/1 | tracks_tempo / enabler |
| Shade Raptor | shadow | common | 3 | 2/3 | tracks_tempo / engine |
| Unseen Pounce | shadow | rare | 2 | Spell | tracks_tempo / answer |
| Trail Informant | shadow | rare | 4 | 3/4 | tracks_tempo / recovery |
| Sava, the Hundred Tracks | shadow | legendary | 6 | 5/5 | tracks_tempo / legendary |
| Scent Leaf | shadow | common | 1 | 1/1 | great_hunt_combo / enabler |
| Scent Lurker | shadow | common | 2 | 2/2 | great_hunt_combo / enabler |
| Hunt Signaller | shadow | common | 3 | 2/3 | great_hunt_combo / engine |
| Mark the Quarry | shadow | rare | 2 | Spell | great_hunt_combo / answer |
| Circle Back | shadow | rare | 3 | Spell | great_hunt_combo / recovery |
| The Great Hunt | shadow | legendary | 6 | Spell | great_hunt_combo / legendary |
| Veil Gecko | shadow | common | 2 | 2/2 | legacy_stealth / legacy_support |
| Veiled Supply | shadow | rare | 3 | Spell | legacy_stealth / legacy_support |
| Sap Viper | shadow | common | 2 | 1/2 | legacy_venom / legacy_support |
| Venom Handler | shadow | rare | 4 | 3/4 | legacy_venom / legacy_support |
