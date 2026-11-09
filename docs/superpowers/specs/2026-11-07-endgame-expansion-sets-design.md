# Endgame expansion sets

Date 2026-11-07. Proposed design for owner review.

Law of the Jungle has been revised in its
[dedicated design](../../../design/expansions/law-of-the-jungle.md).
That document supersedes the Jungle distribution, legendary cycle, Food Chain
mechanic, boss count, and trial objectives below. The other six sets remain
initial proposals and still need review against the updated expansion skill.
Law of the Jungle is now implemented; its dedicated design and iteration log
record the final card pool, progression, and validation.

The Midnight Masquerade (2026-11-08) is an additional collection outside these
seven proposals, with an early unlock and no mastery trial. See
[its design](../../../design/expansions/midnight-masquerade.md).

This proposal treats the seven requested themes as expansion collections for the six existing classes. Each collection adds its own setting, mechanic, three complete archetypes, bosses, and mastery trial. Card ownership still belongs to a class or Neutral. The proposed `collection_id` records the expansion a card belongs to.

The numerical values and sample card text below are starting designs for playtesting. This document defines the content and progression contract. It does not register the collections in the running game.

## What the Hearthstone research changes

Hearthstone's official set history lists three major expansions in each year from 2017 through 2026. The published 2026 months are March, July, and October. Its first 2026 expansion also accompanies a Standard rotation and Core Set update. This is a useful model for a substantial release followed by experimentation and balance work. [Official set history](https://hearthstone.blizzard.com/en-us/expansions-adventures), [35.0 patch notes](https://hearthstone.blizzard.com/en-us/news/24267727)

The midcycle format has changed. Blizzard's 2025 roadmap names expansions and Mini-Sets. In April 2026, Blizzard announced Class Sets in place of Mini-Sets, with four focused class packages per wave and a wave after each major expansion that year. The relevant lesson is to support complete strategies between major releases. A fixed Mini-Set schedule would misstate the current format. [2025 roadmap](https://hearthstone.blizzard.com/en-us/news/24177978/welcome-to-the-year-of-the-raptor), [2026 Class Sets](https://hearthstone.blizzard.com/en-gb/news/24267730/take-a-first-look-at-hearthstone-s-new-class-sets)

The following are design inferences from Blizzard's examples.

| Example | Connection between setting and play | Application here |
| --- | --- | --- |
| Journey to Un'Goro | Dinosaurs gain selectable adaptations. Dean Ayala describes narrowing the possible upgrades so choices remain understandable and interactive. | Give Jungle a bounded decision about ecosystem diversity. Start its reveal with one common that demonstrates the rule. |
| Voyage to the Sunken City | Dredge finds cards at the bottom of the deck, while Colossal minions make enormous sea creatures occupy multiple bodies. | Make Depths about the timing of something waiting underwater. |
| The Great Dark Beyond | Destroyed Starship Pieces contribute to a ship the player can later launch. | Make Stars about committing a crew to a fleet and choosing its orders. |
| Festival of Legends | Classes receive musician and song identities. Finale rewards spending the last available mana. | Let a genre change sequencing and give its characters signature finishing spells. |
| Whispers of the Old Gods | Cultists build toward a recognizable god payoff. | Give the cult a visible investment resource and several ways to spend it. |
| The Grand Tournament | Inspire makes the tournament's heroic theme interact with Hero Powers. | Make tournament victories happen through deliberate combat decisions. |

[Un'Goro design discussion](https://hearthstone.blizzard.com/en-us/news/20659256), [Sunken City announcement](https://hearthstone.blizzard.com/en-us/news/23765277/announcing-voyage-to-the-sunken-city-hearthstone-s-next-expansion.), [Great Dark Beyond](https://hearthstone.blizzard.com/en-us/expansions-adventures/the-great-dark-beyond), [Festival of Legends](https://hearthstone.blizzard.com/en-gb/news/23935243/festival-of-legends-is-now-live/), [Old Gods announcement](https://hearthstone.blizzard.com/en-us/news/20058061/heed-the-whispers-of-the-old-gods-3-11-2016), [Grand Tournament design discussion](https://hearthstone.blizzard.com/en-gb/news/19819220/the-grand-tournament-get-inspired-7-30-2015)

## Collection size and run access

Law of the Jungle now has 138 collectible cards: 42 Neutral and 16 for each
class. Its dedicated design defines the new distribution and bundle counts.
The other six initial proposals retain a 72-card planning budget each; the
original format below applies to those proposals pending their own revisions.

- Three archetypes have 21 shared Neutral cards each. Each archetype has seven distinct three-card bundles, so any class can fill all seven draft slots with that strategy if offered the necessary bundles.
- Six class cards give each existing class one interpretation of the collection's mechanic. These are bundled with shared support from that collection.
- Three shared utility cards provide interaction, recovery, and consistency. They remain usable without a developed theme.
- Each collection has 27 bundle definitions. Twenty-one belong to the three main archetypes. Six support bundles each contain one class card and two of the shared utility cards. Every class receives its own support bundle. The three utility cards are reused across those six bundles.
- Tokens, alternate forms, and boss-only cards are additional records outside the 72 collectible cards. Each collection also supplies three boss encounters and three themed treasures.

The current planning total across all seven collections is 570 collectible
cards. The six initial proposals each describe three archetypes with a legendary
minion and spell; Jungle instead has two class-exclusive legendaries per class.

The role budget within each archetype is six early plays, four enablers or engines, four answers or protection cards, three recovery or consistency cards, two transitional threats, and two legendary finishers. Those categories allocate 21 cards. The initial mana curve target is six cards costing 1-2, seven costing 3-4, five costing 5-6, and three costing 7-9. Individual cards can perform more than one role.

Before starting a standard run, the player can select one unlocked featured collection. That adds its legal card, bundle, treasure, and encounter pools to the run. The selection is saved with the run. Unlocking further collections expands that choice. This controls pool dilution as the library grows.

Unlocking a collection grants its full supporting package together. The featured collection's three archetypes appear in the same draft preference and drought handling used by existing themes. The guaranteed starter remains 15 cards, with up to 21 cards added by seven bundle picks. Seven themed bundles are available, and normal weighted drafts still determine which ones appear.

## Unlock progression

All seven collections occupy the highest progression tier. Their rewards broaden the strategies available to the player. Their power budgets are measured against the existing cards at the same mana cost.

Each gate requires all three items in its row. The per-class count applies separately to War, Decay, Knowledge, Fortune, Order, and Shadow. Existing lifetime victory counters provide the first two requirements, using their current counting rules. New mastery trials provide the skill requirement.

| Collection | Lifetime run victories | Victories with each of the six existing classes | Mastery trial |
| --- | --- | --- | --- |
| Law of the Jungle | 20 | 2 each | Primal Crown |
| From the Depths | 25 | 2 each | The Last Descent |
| To the Stars | 30 | 3 each | Captain's Commission |
| Night City | 35 | 3 each | Ghost Protocol |
| Anime Craze | 40 | 4 each | Final Examination |
| Old Gods | 45 | 4 each | The Seventh Seal |
| Coliseum | 50 | 5 each | Crown of Crowns |

Trials become available after the lifetime prerequisites are met. Each trial contains three consecutive authored encounters with a curated 36-card loaner deck and three loaner treasures. The loaner exposes the new mechanic before its collection is unlocked. Players can inspect their deck, objectives, and encounter rules before beginning. The trial is turn based, and a failed attempt can be retried immediately. Granting the collection requires completing all encounters and objectives in one attempt.

Each trial's objective uses fixed, visible information. Loaner decks provide every required enabler. Card access and prescribed draws must make the objectives reachable. Trials require their own authored balance pass, especially given the current Dungeon Heart matchup results.

The sets are independently earnable once their prerequisites are satisfied. Coliseum's collection has the highest cumulative gate. Its trial demonstrates mastery of the base game's combat and can be completed with its loaner package.

## Law of the Jungle

### Fantasy and mechanical identity

A prehistoric ecosystem of herd beasts, giant dinosaurs, carnivorous plants, and explorers who have become part of the food chain. The player builds a working ecosystem and decides which species to establish next.

**Food Chain** records which of three families the player has summoned during their current turn. The families are Beast, Dinosaur, and Plant. A minion has one printed family for this mechanic. The first summon of each family raises the chain by one, to a maximum of three. Further copies of a family keep the current value.

**Chain N** on a played card resolves its bonus when Food Chain is at least N. A played minion's family is recorded before its Chain bonus is checked. Tokens can establish a family for a later play. A Chain bonus runs once for that play. The family history resets at the start of each player's own turn. The board need not retain a family after it has been recorded that turn.

| Archetype | Main plan and useful partners | Engine and utility | Legendary finishers |
| --- | --- | --- | --- |
| Apex Succession | Dinosaur midrange with War or Fortune | Nest Warden turns Chain 2 into card selection. Thickhide Herd guards the early board. | Gorath, Crown of the Canopy supplies a durable apex threat. Extinction March grants the current ecosystem a decisive attack turn. |
| Living Canopy | Plant growth and recovery with Decay or Order | Root Exchange trades small bodies for healing and replacement seedlings. Creeper Warden protects engines. | The Worldroot rebuilds a resilient board. Verdant Reclamation converts a developed chain into a recovery swing. |
| Primal Hunt | Beast pressure with Shadow or War | Trail Matriarch rewards alternating families. Vine Snare removes a blocker. | Sava, the Hundred Tracks turns an established board into attack pressure. The Great Hunt supplies burst damage and replenishment. |

The teaching common is **Canopy Scout**, a 2-mana 2/2 Beast with `Chain 2: Draw a card.` It teaches the player to establish a different family first. A 1-mana Plant can enable it, while a second Beast cannot raise the chain.

Primal Crown requires winning each of its three encounters with all three families represented on the final friendly board and having reached Chain 3 during that encounter. The loaner has several interchangeable examples of every family.

Its strongest turns require sequencing and multiple card commitments. Removal of a key payoff, hand pressure, and surviving the burst turn are its intended checks.

## From the Depths

### Fantasy and mechanical identity

Bioluminescent reefs descend into pressure trenches, drowned observatories, and immense beings moving below the visible battlefield. The player invests mana now and plans around a public resurfacing schedule.

**Submerge N** gives a minion an alternative way to enter play from hand, with N from one to three. Pay two less than its current mana cost, with a minimum payment of one, and place it in the public Trench zone. It counts down at the start of each of its controller's turns. On reaching zero it surfaces as a normal summon and resolves its printed **Surface** effect. Playing it normally pays its normal cost and bypasses Surface.

The Trench holds at most two minions per player. Submerged cards occupy no board slots, cannot attack, and have no active auras. Their identities and countdowns are visible. A due minion waits if the board is full and surfaces at the next action boundary where there is space, in Trench entry order. A surfaced minion has normal summoning sickness. Summoning a copy directly uses its ordinary form. Silence after surfacing removes ongoing effects normally.

| Archetype | Main plan and useful partners | Engine and utility | Legendary finishers |
| --- | --- | --- | --- |
| Trench Titans | Delayed large bodies with Order or Knowledge | Pressure Tender protects the hero while Leviathan Surveyor improves upcoming Surface effects. | Thaloryx, the Lightless Crown surfaces with a major board swing. Abyssal Emergence brings a scheduled threat forward and stabilizes its controller. |
| Reef Chorus | Several coordinated surfacing turns with Decay or Order | Coral Nursery replaces small threats. Reef Bastion buys the turn needed for a coordinated wave. | The Cathedral Reef fills a lasting board. Bloom Beneath the Black Sea converts that board into pressure and recovery. |
| Drowned Oracles | Timing, card selection, and spell control with Knowledge or Shadow | Lantern Oracle finds the answer needed for the surfacing turn. Blackwater Seal disrupts a dangerous enemy. | Nhal, the Last Witness gives recurring value after surfacing. The Sea Remembers converts delayed preparation into a finishing spell. |

The teaching common is **Trench Grazer**, a 4-mana 3/5 with `Submerge 2. Surface: Gain Taunt.` Its alternative costs two mana and exposes a two-turn interval for the opponent to exploit.

The Last Descent requires surfacing at least two minions in each encounter and winning with an empty Trench. The three encounters test early defense, full-board scheduling, and a final coordinated surfacing turn.

Fast pressure can punish committed mana before a threat appears. Public timers allow opponents to preserve a board clear for a known arrival. Trench capacity keeps stored threats bounded.

## To the Stars

### Fantasy and mechanical identity

Survey fleets, industrial Mechs, carriers, and warships explore a frontier of artificial moons and lost stations. The player commands a working crew and chooses between attacking and operating a ship.

**Crew N** on a Ship gives it up to N crew assignments during its controller's turn, with N between one and three. A ready friendly Mech that is not a Ship can spend one available attack to crew it. Frozen and summoning-sick minions cannot crew. Each Mech crews at most once per turn.

Each assignment supplies one Power to that Ship. The Ship's printed **Order** spends a stated amount of Power and its own available attack. An Order is a once-per-turn action for that Ship. Power clears at the end of the controller's turn. Ships remain ordinary targetable minions. All normal requirements for being ready apply to Order activation, and generated Power cannot transfer between Ships.

| Archetype | Main plan and useful partners | Engine and utility | Legendary finishers |
| --- | --- | --- | --- |
| Carrier Group | Mechs provide crew and carriers provide replacement drones, especially with Order | Dockmaster rotates crew efficiently. Emergency Bulkheads protect a key Ship. | Arkship Meridian deploys a fleet. All Wings, Launch! turns spare crew into a coordinated attack. |
| Siege Fleet | Concentrate Power into large Orders, especially with War | Gunnery Automaton prepares firing turns. Point Defense handles small attackers. | Helios, the Last Dreadnought offers a costly siege Order. Orbital Verdict spends a prepared fleet's resources for a finishing strike. |
| Deep Space Logistics | Invest crew in cards, repair, and efficient deployment, especially with Knowledge or Fortune | Survey Tender produces card selection. Repair Dock restores a damaged hull. | The Far Horizon converts a supported fleet into sustained advantage. A Thousand New Suns is its expensive final deployment spell. |

The teaching common is **Survey Skiff**, a 3-mana 2/4 Ship with `Crew 1. Order 1: Draw a card.` A ready Mech can give up an attack, but the Skiff also spends its own attack to execute the Order.

Captain's Commission requires at least two Order activations in each encounter and allows at most one friendly Ship destruction across the entire trial. The encounters test escorting a small ship, choosing between combat and repair, and committing a fleet to a decisive firing turn.

Ships and crews expose separate pieces to removal. A board clear can remove their infrastructure, and immediate pressure can force Mechs to fight instead of crew.

## Night City

### Fantasy and mechanical identity

Rain, neon, black-market augmentations, street crews, and corporate ICE. The player takes calculated risks by pushing hardware beyond its safe limits.

**Overclock N** is an optional enhanced play mode. Pay the card's normal mana cost, gain N Heat, and resolve its printed Overclock bonus. Heat belongs to the player and ranges from zero to nine. The enhanced mode is unavailable if it would exceed nine, while the ordinary play remains available.

After the player's ordinary end-of-turn effects resolve, Heat of six or more causes **Redline**, dealing three damage to that player's hero and setting Heat to three. At lower Heat, reduce Heat by one instead. Redline deals normal non-spell damage, so Armor applies. **Vent N** removes N Heat to a minimum of zero. The interface previews the projected end-turn outcome before the player commits to an Overclock.

| Archetype | Main plan and useful partners | Engine and utility | Legendary finishers |
| --- | --- | --- | --- |
| Redline Runners | Efficient attacks and burst turns with Shadow or War | Street Capacitor rewards controlled high Heat. Emergency Coolant makes an extended turn possible. | Kestrel, Redline Saint converts a prepared Heat window into attack pressure. Burn the Grid ends a planned burst sequence. |
| Ghost Circuit | Alternate hacking effects with venting and card selection, especially with Knowledge | Ghost Router rewards precise sequencing. ICEbreaker strips an enemy defense. | The Untraceable supplies a recurring hacking engine. Citywide Blackout opens one decisive turn against a defended board. |
| Chrome Syndicate | Durable augmented minions and repair with Order or Fortune | Street Surgeon keeps investments alive. Firmware Broker trades Heat for flexible upgrades. | The Neon Sovereign anchors a developed board. Full Body Replacement rebuilds and upgrades surviving threats. |

The teaching common is **Street Spark**, a 1-mana spell that deals one damage to a minion, with `Overclock 2: Deal 3 instead.` A player at Heat four can take the immediate gain and plan a Vent before turn end.

Ghost Protocol requires at least three Overclock plays in every encounter and permits at most one Redline across the trial. It tests resource planning with finite cooling tools and opposing pressure.

Heat is public. Opponents can pressure the hero when venting costs tempo. The Heat ceiling limits repeated enhanced plays in a single turn.

## Anime Craze

### Fantasy and mechanical identity

Tournament exams, found families, transformations, melodramatic rivals, and techniques with extravagant names. Original characters embody recognizable anime tropes. The player protects developing protagonists and earns their transformation over several turns.

**Arc** minions have two progress marks and an authored Awakened form. At the end of their controller's turn they gain one mark if they were already controlled at that turn's start and the player played a card whose printed cost differs from the Arc minion's printed cost. At most one mark is earned this way per minion per turn.

The first mark grants +1/+1. The second transforms the minion into its printed Awakened form. The new form enters at full Health while retaining attack-use, summoning-sickness, and Frozen state from the original entity. It resolves no new Battlecry. Returning to hand resets Arc progress. A copied base definition starts fresh. Silence disables further Arc progression while it applies. Awakened forms are tokens and cannot be drafted directly.

| Archetype | Main plan and useful partners | Engine and utility | Legendary finishers |
| --- | --- | --- | --- |
| Training Arc | Protect and develop a few protagonists, especially with War or Knowledge | Patient Mentor provides training support. Last-Minute Rescue protects a developing champion. | Ren, Tomorrow's Champion awakens into a major combat threat. Beyond My Limits! turns an earned transformation into a finishing turn. |
| Found Family | Several allies grow together behind protection and healing, especially with Order | Clubroom Captain rewards varied-cost plays. Promise to Return recovers an important ally. | The Seventh Member pays off a developed team. Everyone Is Counting on You converts the team into a coordinated attack. |
| Final Rival | Plan alternating plays around two complementary rivals, especially with Shadow or Fortune | Rivalry Tutor finds the other half of the plan. Dramatic Entrance enables the required sequence. | The Twin Eclipse provides the paired payoff. This Is Our Final Form rewards having two Awakened allies. |

The teaching common is **Transfer Student**, a 2-mana 2/3 Arc minion that becomes **Campus Defender**, a 4/5 Taunt, at its second mark. It must survive at least two later friendly turn endings to complete its ordinary Arc.

Final Examination requires awakening two different champion definitions during every encounter and permits at most one friendly champion destruction across the trial. It supplies several recovery routes and public objectives for the remaining champions.

Removing or silencing developing champions interrupts the investment. The turn restriction makes protection and sequencing matter even when the player has many cheap cards available.

## Old Gods

### Fantasy and mechanical identity

Buried solar temples, forgotten names, cult processions, and divine bargains. The player gives up present board resources to prepare miracles and eventually manifest a god.

**Offer** voluntarily destroys a chosen friendly minion as a printed cost and grants Devotion equal to its printed mana cost, clamped between one and three. The sacrifice must succeed before Devotion is granted. Devotion is a public match resource from zero to twelve. Ordinary minion deaths grant none. Every Offer card prints its mana cost and other effects normally.

**Ritual N** is an optional empowered mode that spends N Devotion in addition to the card's mana cost. Spending happens before resolution, and a copied effect cannot pay or grant the same cost a second time. The ordinary play is always available if its ordinary requirements are met. Devotion resets between matches. Each god has a strong ordinary form and a distinct Ritual payoff.

| Archetype | Main plan and useful partners | Engine and utility | Legendary finishers |
| --- | --- | --- | --- |
| Hollow Sun | Sacrifice guards to prepare a large divine avatar, especially with War or Order | Sunless Acolyte converts bodies into Devotion. Funeral Guard protects the transition. | Oruun, the Hollow Sun manifests as the major combat threat. Eclipse of the Living empowers the surviving congregation. |
| Unwritten Gospel | Prepare high-impact spell rituals and precise disruption, especially with Knowledge or Shadow | Scripture Broker selects the next spell. Erase the Name handles a key enemy ability. | Ithra, the Unwritten makes the final ritual turn possible. The Last Sentence converts stored Devotion into a finishing spell. |
| Last Harvest | Replace sacrificial bodies and recover life, especially with Decay or Fortune | Tithe Orchard grows the next offering. Mercy of Ash restores the hero while setting up the next turn. | Veyra of the Last Harvest produces a lasting divine board. Heaven Must Be Fed spends the prepared resource for a recovery and pressure swing. |

The teaching common is **Sunless Acolyte**, a 2-mana 2/3 with `Battlecry: You may Offer another friendly minion. If you do, gain 2 Armor.` A four-cost offering grants three Devotion. Its current buffed mana cost does not change that amount.

The Seventh Seal requires spending at least nine Devotion through at least two Ritual cards in every encounter, then winning the final encounter with a god alive. The loaner guarantees access to multiple gods and the required offering engine.

The opponent can punish a board weakened by an offering. Healing, replacement bodies, and careful timing make the investment sustainable. Spending Devotion on an early answer delays the largest Ritual.

## Coliseum

### Fantasy and mechanical identity

Gladiators, handlers, heralds, beasts of spectacle, and champions from across the seven settings. The player chooses fights, preserves a contender, and wins the crowd before attempting a championship finish.

**Challenge** marks one enemy minion until the end of the current turn. A new Challenge replaces the previous mark. Minions still attack through normal targeting, Taunt, readiness, and combat rules.

If a friendly minion's attack destroys the marked enemy and the attacker survives the entire attack resolution, including queued deaths and Deathrattles, the player earns one Favor. The player can earn Favor once per own turn and store up to three. A spell or triggered damage kill earns none.

**Champion N** lets a card spend N Favor for its enhanced play effect, in addition to its mana cost. Favor is public, and a successful claim consumes the mark. Challenge can be useful as setup even when the player chooses not to attempt the marked fight that turn.

| Archetype | Main plan and useful partners | Engine and utility | Legendary finishers |
| --- | --- | --- | --- |
| Grand Melee | Durable fighters earn Favor through efficient trades, especially with War or Order | Veteran Handler finds a favorable target. Sand Medic preserves the contender between fights. | Valka, Crown of the Arena converts Favor into a champion attack turn. The Final Bell opens the finishing combat sequence. |
| Underdog Circuit | Tricks let inexpensive contenders win difficult fights, especially with Fortune or Shadow | Back-Alley Second protects a small fighter. Pocket Sand creates an opening against a stronger opponent. | Pip, the Unlikely Victor supplies the underdog payoff. Upset of the Century rewards a prepared Favor spend. |
| Masters' Bracket | Removal preparation and defensive trades control which fights happen, especially with Knowledge or Decay | Bracket Scribe rewards successful challenges. Arena Adjudicator removes an obstacle to combat. | The Sevenfold Champion converts accumulated preparation into sustained pressure. Standing Ovation turns earned Favor into a final board swing. |

The teaching common is **Arena Challenger**, a 3-mana 3/4 with `Battlecry: Challenge an enemy minion.` It creates a target for an already-ready ally to defeat. It does not gain an immediate attack from the mark.

Crown of Crowns uses three sequential encounters with health carried between fights and healing available through the loaner deck. Each encounter requires at least three successful challenged combats. The final victory must have a champion alive. The player can review the next opponent before continuing.

Control of the marked fight belongs to the player, while enemy removal and unfavorable combat can deny the survivor requirement. The once-per-turn reward limits how quickly a single established board can earn the final payoff.

## Release cycle proposal

Use the following order to introduce complexity gradually.

| Release | Collection | What it introduces | Follow-up story and support |
| --- | --- | --- | --- |
| 1 | Law of the Jungle | Family tracking and sequencing | Heart of the Canopy strengthens the least consistent family package. |
| 2 | From the Depths | A public delayed zone | Below the Last Light adds ways to defend the investment. |
| 3 | To the Stars | Crew assignments and activated Orders | The Derelict Armada adds alternatives for small fleets. |
| 4 | Night City | Optional power with visible risk | After Midnight supports a weaker Heat strategy. |
| 5 | Anime Craze | Stateful minion progression | The Final Episode adds recovery and rival support. |
| 6 | Old Gods | A resource built from voluntary sacrifice | The Broken Covenant diversifies how Devotion can be spent. |
| 7 | Coliseum | Combat objectives and an earned reward | Legends' Invitational revisits the most successful characters. |

For each expansion, announce the setting and demonstrate its mechanic on a simple card first. Reveal a complete engine, its utility, and its finishing pair together so the player can judge a strategy. Launch the three complete archetypes simultaneously. After enough games to assess the release, tune its existing cards. A proposed nine-card follow-up then adds one support bundle per archetype using the established mechanic. It unlocks with its parent collection.

This order is a product roadmap, with release dates dependent on implementation and playtest capacity. The Hearthstone pattern supplies a model for alternating major releases, concentrated support, and balance work. Each collection's release must pass its gameplay criteria before the next one enlarges the active development scope.

## Required systems and current implementation gaps

The current `set` field controls class eligibility. `DataLoader.in_collectible_pool` and `in_bundle_pool` use the class or Neutral. Treating a collection name as that field would require a matching hero and exclude it from existing classes. Add a separate `collection_id` to proposed expansion records, with absent values representing current core content.

The current unlock evaluator reads heroes, extra powers, treasures, and bundles. It supports lifetime wins, best floor, boss defeats, treasure picks, and grouped conditions. It has no collection record type or trial-completion condition. The current ordinary bundle offer loop also does not filter candidates by their unlock state. A complete collection unlock therefore needs explicit enforcement throughout the draft and generation paths.

| Area | Required behavior |
| --- | --- |
| Collection registry | Store collection ID, presentation, content membership, three archetype tags, mastery trial, and unlock condition. |
| Unlock evaluation | Add collection records and a `trial_completed` leaf with validated trial IDs. Use explicit IDs for all six current classes. `each_launch` currently refers to the three initially available heroes. |
| Profile and trials | Persist versioned trial completion and progress. Grant once after an authoritative completed attempt. Retrying or resuming an attempt must preserve its state and prevent duplicate grants. |
| Run start and resume | Save selected collection and the legal unlocked content snapshot with the run. Exclude newly unlocked content from an already-started run. |
| Draft and generation | Apply the run's eligibility snapshot to bundle offers, collectible pools, Discover, random generation, and treasures. Printed token references remain available to cards legally in the run. |
| Boss pool | Add collection encounters when the collection is featured. Mastery trial encounters use their prescribed challenge lineup. |
| Effects and UI | Add each mechanic's event history, resources or zones, commands, validation, intent previews, and save/replay support. Expand glossary text independently of short card text. |
| AI | Teach planning and forecasting about delayed surfacing, Crew/Order actions, Heat, Arc value, Devotion spending, and Challenge rewards before claiming balance from automated results. |

A proposed Jungle gate has eight leaves under `all_of`, which fits the current fan-out limit of eight. Those leaves are 20 total wins, two wins for each of the six explicit current hero IDs, and completion of `trial_primal_crown`. The last leaf requires implementation. The same construction works for all seven thresholds. The current depth limit of three and maximum numeric target of 999 accommodate this design.

Food Chain uses existing summon events plus new family history. Depths requires a new Trench zone and due-card resolution. Stars requires commands and attack-budget accounting for crew and Orders. Night City requires the Heat resource and optional-play preview. Anime requires per-entity Arc state and carefully defined transformations. Old Gods requires Offer costs and Devotion. Coliseum requires attack-resolution provenance, survivor checks, and Favor. All are gameplay features that need more than card-data entries.

## Acceptance criteria before implementation is considered complete

1. Every collection contains three archetypes with at least 21 legal collectible cards each, seven sound bundles per archetype, a working engine, useful answers, recovery, and the two finishing card types.
2. Every collection can produce a 36-card standard run deck through the ordinary offer and pick path. Tests include its treasure draws and the run's actual eligibility snapshot.
3. An ineligible profile cannot access the collection's collectible cards through drafting or generation. A newly eligible profile earns the complete package. Existing core records remain loadable with no collection field.
4. Each mastery trial is reachable before its collection is unlocked, meets its objective through the loaner package, and grants progress correctly across save/resume and retries.
5. New mechanics are deterministic under replay. The Trench's full-board case, crew attack spending, Heat ceiling, bounced Arc minions, failed Offer costs, and challenged attackers killed by Deathrattles have explicit verification.
6. Player and boss AI can use and respond to each mechanic. Automated reports distinguish faults, decision errors, sample size, and match outcomes.
7. Compare each archetype against baseline decks using identical seeds and treasure access, then conduct human playtests. Target results by boss band and floor using the game's balance settings. The existing Dungeon Heart performance needs resolution before trial difficulty or final-floor viability can be approved.
8. The hardest gates are beatable through demonstrated mastery. Lifetime thresholds are tuned after measuring actual play time, and every challenge can be retried immediately.
