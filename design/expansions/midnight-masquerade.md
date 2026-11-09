# The Midnight Masquerade

Status: merged 2026-11-08 with owner approval (Phase 6).
Collection id `midnight-masquerade`, data in `assets/data/midnight-masquerade/`,
authored by `tools/content/masquerade_content.py`. Iteration log:
[midnight-masquerade/iterations.md](midnight-masquerade/iterations.md).

## Theme and design pillars

Deep in the dungeon, a ruined manor still holds the ball its owners never
ended. The guests wear masks, and under each mask is something else: an
assassin, a vampire count, a clockwork double, a forgotten heir, or a
terrified footman in a borrowed coat. Many minions in this set are **Masked**.
The first time one survives damage it **Unmasks**, transforming into its
printed true form.

Unmasking cuts both ways. Some guests hide a monster behind a modest mask and
want to be hit. Others are more dangerous in costume than in truth, and an
Unmask is a downgrade the opponent wants to force. Every attack and every ping
becomes a decision for both players.

The theme fits the run structure:
- Early bosses deal little incidental damage, so masks stay on.
- Mid-band bosses with board damage start revealing guests, for good or ill.
- Late bosses demand deliberate reveal timing. The Dungeon Heart's 2 damage to
  every enemy minion each turn reveals a reveal-up deck and strips a mask-keeping one.

**Pillars**

1. **Every hit is a choice.** Unmasking is an upgrade for some guests and a
   downgrade for others, and both kinds are common. Neither player can attack a
   Masked minion on autopilot.
2. **Secrets in plain sight.** Every true form is printed on the card and
   visible to both players. Surprise comes from timing, not hidden information.
3. **Poisoned wine, thirsty hosts.** The set revives two under-used keywords:
   poisonous (7 existing cards) as the ball's poisoners, and lifesteal (6) as
   its vampire hosts.
4. **One mechanic, six interpretations.** See the class pie below.

Not one of the seven themes in
`docs/superpowers/specs/2026-11-07-endgame-expansion-sets-design.md`.

## Unmask

**Rules text (21 words):** Unmask: The first time this survives damage, it
transforms into its printed true form, keeping its board position.

Every Masked minion carries one effect, with no new keyword, resource or zone:

```json
{"trigger": "on_damage_taken", "scope": {"who": "self"},
 "condition": {"cmp": [{"ref": "trigger_subject.health"}, ">", 0]},
 "targets": "self", "ops": [{"op": "transform", "card_id": "<true form>"}]}
```

Masked minions carry the `masked` tag. True forms are non-collectible token
records tagged `unmasked`, in the same file.

**Rules and edge cases** (each is a test in `midnight_masquerade_unmask_test.gd`):

| Case | Result |
| --- | --- |
| Survives damage | Transforms. The true form enters at full health in the same slot. |
| Lethal damage | Dies; no reveal. The engine never reveals a dying minion; the condition is a second guard. |
| Silenced first | Never unmasks. Silence removes the effect, so a strong mask stays strong forever. |
| Divine Shield | The shield absorbs the hit and the mask stays on. The next hit unmasks. |
| True form takes damage | Nothing more happens; a true form has no Unmask. |
| Enemy side | Works the same for either player. |
| Combat | A surviving attacker or defender unmasks after the exchange. |
| Fortune's Gambler's Mask | A seeded coin picks one of two printed forms; replays are identical. |
| Frozen mask | Unmasking thaws it: the true form is a fresh minion. |

**Closest existing mechanics.** Two come closest:
- **War's Berserk** (`on_damage_taken`, gain Attack): Berserk only grows; Unmask
  replaces the whole minion, and the result can be worse.
- **Anime Craze's proposed Arc** (an authored transformation): Arc counts
  surviving turns. Unmask is triggered by damage, so it interacts with combat
  and pings rather than turn count.

**Run structure.**
- Early (band 1): few incidental pings, so Masked minions mostly play as their
  printed bodies.
- Mid (band 2): Frost Hag, Mirror Sage and both new bosses force decisions.
- Late (band 3): the Dungeon Heart reveals everything with 3+ Health.

**Treasure synergy.** `treasure_plague_bell` and `treasure_grave_tithe` reward
Mourning Widow's Husk. `treasure_focusing_prism` makes Curtain Call and Dice of
the Ball lethal to small masks, so it cuts both ways. **Bundle synergy.**
Decay's plague bundles and War's berserk bundles already ping their own
minions.

**Engine work.** The mechanic needed none. Loading a second collection did: the
loader listed Law of the Jungle's files by name, and every collection had to
have a trial. The approved change is small:
- `DataLoader` reads every collection registered in `collections.json`.
- A trial file is required only when `collection.json` names a `trial_id`.
- A trial-less collection's unlock uses the shared
  `UnlockEvaluator.validate_collection_unlock_config`.
- The Expansions screen shows a trial-less collection's requirement text and
  no trial controls.

## Previous-mechanic support

Neither keyword's rules change.

- **Poisonous**, "Destroys any minion damaged by this":
  - Wine Steward and Poisoned Chalice (neutral common)
  - Poison Taster (neutral rare)
  - Beaked Physician (Decay rare)
  - Venom Kiss and Masked Assassin (Shadow)
  - The Nightshade Hostess (Shadow legendary)
- **Lifesteal**, "Damage dealt by this source heals its controller's hero by the
  same amount":
  - Blood Sommelier and Crimson Guest (neutral)
  - Masked Baron (War rare)
  - Sir Aurel's true form (Order legendary)
- **Silence** (bonus) as a positive tool, because silencing your own strong mask
  locks it:
  - Lady of Veils (neutral rare) and Public Unveiling (neutral rare)
  - Hush (Knowledge common)
  - The Archivist of Faces and The Faceless (legendaries)

## Class pie

From `heroes.json` and `docs/superpowers/specs/2026-11-06-classes-powers-archetypes-design.md`.

| Class | Identity in this set | Draft theme | Primary / secondary | Weakness kept |
| --- | --- | --- | --- | --- |
| War | Takes the hits; berserk reveals | `grand_reveal` | aggro / control | Few ways to protect a strong mask |
| Decay | Pings its own guests; Husks and sacrifice | `grand_reveal` | sacrifice / attrition | Self-damage costs board health |
| Knowledge | Silence and freeze; locks strong masks, strips enemy ones | `keep_the_mask` | control / combo | Little self-damage |
| Fortune | Random reveals, coin flips | `grand_reveal` | value / control | Unreliable reveals |
| Order | Divine Shield keeps strong masks on | `keep_the_mask` | control / summon | Board-wide pings still reveal after one hit |
| Shadow | Stealth hides masks; poison trades | `keep_the_mask` | tempo / attrition | Area damage ignores Stealth |

Each class has 5 cards: 2 commons, 1 rare and 2 legendaries. Neutral has 18
cards (12 commons, 6 rares), so the set has 48 collectibles with a 37.5 %
neutral share. Draft access: six bundles per class (36 total), each bundle one
class card plus two neutral cards of the class's theme.

## Card list

| Class | Card | Rarity | Cost | Stats | Text | Theme |
| --- | --- | --- | ---: | --- | --- | --- |
| Neutral | Masked Reveler | common | 2 | 2/2 | Unmask: Becomes a 4/3 Reveler Unveiled. | grand_reveal |
| Neutral | Borrowed Finery | common | 2 | 3/2 | Unmask: Becomes a 1/1 Trembling Footman. | keep_the_mask |
| Neutral | Candle Page | common | 1 | 1/1 | Battlecry: Deal 1 damage to a minion. | grand_reveal |
| Neutral | Gossiping Duchess | common | 3 | 4/3 | Unmask: Becomes a 2/2 Tattling Maid. | keep_the_mask |
| Neutral | Wine Steward | common | 2 | 2/2 | Battlecry: Give a friendly minion Poisonous. | keep_the_mask |
| Neutral | Poisoned Chalice | common | 1 | spell | Give a friendly minion Poisonous. Deal 1 damage to it. | grand_reveal |
| Neutral | Masked Duelist | common | 3 | 2/4 | Rush. Unmask: Becomes a 5/4 Duelist Revealed with Rush. | grand_reveal |
| Neutral | Velvet Usher | common | 4 | 3/5 | Taunt. Battlecry: Give a friendly minion Divine Shield. | keep_the_mask |
| Neutral | Blood Sommelier | common | 3 | 2/4 | Lifesteal. Unmask: Becomes a 4/4 Thirsting Sommelier with Lifesteal. | grand_reveal |
| Neutral | Curtain Call | common | 2 | spell | Deal 1 damage to all minions. | both |
| Neutral | Mirror Dancer | common | 1 | 2/2 | Unmask: Becomes a 1/1 Shy Dancer. | keep_the_mask |
| Neutral | Crimson Guest | common | 4 | 3/4 | Unmask: Becomes a 5/5 Crimson Count with Lifesteal. | grand_reveal |
| Neutral | Midnight Bell-Ringer | rare | 5 | 3/6 | At the end of your turn, deal 1 damage to your other minions. | grand_reveal |
| Neutral | Lady of Veils | rare | 4 | 3/4 | Battlecry: Silence another friendly minion and give it +1/+1. | keep_the_mask |
| Neutral | Poison Taster | rare | 2 | 1/3 | Unmask: Becomes a 3/2 Hired Poisoner with Poisonous. | grand_reveal |
| Neutral | Public Unveiling | rare | 3 | spell | Silence an enemy minion, then deal 2 damage to it. | keep_the_mask |
| Neutral | Jealous Rival | rare | 3 | 3/2 | Battlecry: Deal 1 damage to another friendly minion and draw a card. | grand_reveal |
| Neutral | Clockwork Double | rare | 4 | 5/4 | Unmask: Becomes a 2/3 Unwound Double. | keep_the_mask |
| War | Scarred Gladiator | common | 3 | 2/4 | Unmask: Becomes a 5/5 that gains +1 Attack whenever it takes damage. | grand_reveal |
| War | Parry and Riposte | common | 1 | spell | Deal 1 damage to a friendly minion. Give it +2 Attack. | grand_reveal |
| War | Masked Baron | rare | 4 | 3/4 | Unmask: Becomes a 6/5 Bloodied Baron with Lifesteal. | grand_reveal |
| War | Count Varrus, the Smiling Blade | legendary | 5 | 4/6 | Unmask: Becomes a 6/6 with Windfury. | grand_reveal |
| War | Madame Steel, the Ringmaster | legendary | 6 | 5/7 | Taunt. At the end of your turn, deal 1 damage to all other minions. | grand_reveal |
| Decay | Mourning Widow | common | 2 | 1/3 | Unmask: Becomes a 3/3 with 'Deathrattle: Summon a 1/1 Husk'. | grand_reveal |
| Decay | Toxic Toast | common | 2 | spell | Deal 1 damage to all friendly minions. Draw a card. | grand_reveal |
| Decay | Beaked Physician | rare | 3 | 2/3 | Unmask: Becomes a 4/4 with Poisonous. | grand_reveal |
| Decay | Lady Ashgrave, the Widow Bride | legendary | 4 | 3/4 | Battlecry: Destroy another friendly minion. Gain its Attack and Health. | grand_reveal |
| Decay | The Last Dancer | legendary | 5 | 4/5 | Deathrattle: Summon two Masked Revelers. | grand_reveal |
| Knowledge | Hush | common | 1 | spell | Silence a minion. Draw a card. | keep_the_mask |
| Knowledge | Frost-Masked Scholar | common | 3 | 4/3 | Unmask: Becomes a 2/3 with Spell Damage +1. | keep_the_mask |
| Knowledge | Mirror Mage | rare | 4 | 3/4 | Battlecry: Deal 2 damage to an enemy minion and Freeze it. | keep_the_mask |
| Knowledge | The Archivist of Faces | legendary | 6 | 4/6 | Battlecry: Silence all enemy minions. | keep_the_mask |
| Knowledge | Velisande, Veiled Sorceress | legendary | 3 | 2/4 | Unmask: Becomes a 4/5 with Spell Damage +2. | keep_the_mask |
| Fortune | Gambler's Mask | common | 2 | 2/2 | Unmask: Flip a coin. Heads: becomes a 5/4. Tails: becomes a 1/1. | grand_reveal |
| Fortune | Dice of the Ball | common | 1 | spell | Deal 1 damage to a random minion twice. | grand_reveal |
| Fortune | Gilded Noble | rare | 3 | 2/3 | Unmask: Becomes a 3/3 with 'Deathrattle: Add two Coins to your hand'. | grand_reveal |
| Fortune | Fortunata, the Lucky Debutante | legendary | 4 | 3/5 | Battlecry: Deal 1 damage to your other minions. Draw 2 cards. | grand_reveal |
| Fortune | The House Always Wins | legendary | 6 | spell | Three times: Heads, deal 3 damage to a random enemy minion. Tails, deal 1 to all minions. | grand_reveal |
| Order | Shielded Debutante | common | 2 | 2/2 | Divine Shield. Unmask: Becomes a 1/1 Blushing Debutante. | keep_the_mask |
| Order | Guard the Guests | common | 1 | spell | Give a friendly minion Divine Shield and +1 Health. | keep_the_mask |
| Order | Steward of the Hall | rare | 4 | 3/4 | Taunt. Battlecry: Give your Masked minions Divine Shield. | keep_the_mask |
| Order | Sir Aurel, the Gilded Mask | legendary | 5 | 4/5 | Taunt. Divine Shield. Unmask: Becomes a 2/4 with Lifesteal. | keep_the_mask |
| Order | Grand Procession | legendary | 5 | spell | Summon two Borrowed Finery and give your minions Divine Shield. | keep_the_mask |
| Shadow | Veiled Cutpurse | common | 2 | 2/2 | Stealth. Unmask: Becomes a 1/2 Caught Cutpurse. | keep_the_mask |
| Shadow | Venom Kiss | common | 1 | spell | Give a friendly minion +1 Attack and Poisonous. | keep_the_mask |
| Shadow | Masked Assassin | rare | 3 | 3/2 | Stealth. Unmask: Becomes a 2/1 with Poisonous. | keep_the_mask |
| Shadow | The Faceless | legendary | 4 | 4/3 | Stealth. Whenever this attacks, Silence the defender. | keep_the_mask |
| Shadow | The Nightshade Hostess | legendary | 5 | 3/6 | At the end of your turn, give a random friendly minion Poisonous. | keep_the_mask |

**Direction split.** 22 Masked minions print 23 true forms:
- **13 upgrades:** Reveler, Duelist, Sommelier, Crimson Guest, Poison Taster,
  Gladiator, Baron, Varrus, Widow, Physician, Gilded Noble, Velisande, and the
  Gambler's heads form.
- **10 downgrades:** Finery, Duchess, Mirror Dancer, Clockwork Double, Scholar,
  Debutante, Sir Aurel, Cutpurse, Assassin, and the Gambler's tails form.

## Legendary cycle

| Class | Legendary | Playstyle | Non-legendary enablers |
| --- | --- | --- | --- |
| War | Count Varrus, the Smiling Blade | aggro: hit him yourself for a turn-one 6/6 Windfury | Parry and Riposte, Scarred Gladiator |
| War | Madame Steel, the Ringmaster | control: a Taunt wall that pings both boards every turn | Masked Baron, Scarred Gladiator |
| Decay | Lady Ashgrave, the Widow Bride | sacrifice: eat a revealed true form for its stats | Mourning Widow, Toxic Toast |
| Decay | The Last Dancer | attrition: two fresh masks when she dies | Beaked Physician, Toxic Toast |
| Knowledge | The Archivist of Faces | control: silence the enemy board, locking or stripping its masks | Hush, Mirror Mage |
| Knowledge | Velisande, Veiled Sorceress | combo: reveal her with your own area spell, then cast with Spell Damage +2 | Frost-Masked Scholar, Curtain Call |
| Fortune | Fortunata, the Lucky Debutante | value: reveal your board and draw 2 | Gambler's Mask, Gilded Noble |
| Fortune | The House Always Wins | control: random removal that may also reveal your masks | Dice of the Ball, Gilded Noble |
| Order | Sir Aurel, the Gilded Mask | control: a shielded Taunt that stays strong until hit twice | Guard the Guests, Steward of the Hall |
| Order | Grand Procession | summon: two strong masks and a shield for the whole board | Shielded Debutante, Guard the Guests |
| Shadow | The Faceless | tempo: a Stealth attacker that silences what it hits | Veiled Cutpurse, Venom Kiss |
| Shadow | The Nightshade Hostess | attrition: Poisonous spreads every turn | Masked Assassin, Venom Kiss |

Each pair differs. In each class, one legendary pushes the class's primary
playstyle. No legendary is a strict upgrade of an existing card: none of the
existing legendaries transforms on damage, mass-silences, or eats a friendly
minion's stats.

## New dungeon bosses

Both use the existing `tempo` AI and the existing passive system. Their decks
are 30 real collection cards and supply their own masks; neither relies on the
player's cards.

| Boss | Band / Health | Mechanic use | Readable intent | Counterplay |
| --- | --- | --- | --- | --- |
| Madame Veil, Hostess of the Ball (`boss_masq_hostess`) | 1 / 30 | Reveal-up deck (Revelers, Duelists, Sommeliers, Tasters) plus her passive: at the end of her turn, 1 damage to one of her Masked minions. | Her passive text; a mask on her board will be a bigger minion next turn. | Kill a mask before her turn ends, or silence it so it never reveals. |
| The Faceless Count (`boss_masq_faceless_count`) | 2 / 40 | Strong-mask deck (Finery, Duchess, Mirror Dancer, Clockwork Double) plus his passive: at the start of his turn, Divine Shield on one unshielded mask. | His passive text; shielded masks stay strong. | Pop the shield with a ping, then hit again to force the weak true form. Silencing his masks helps him. |

With no Masked minion on board, each passive does nothing (tested). Both
bosses enter band pools only when Masquerade is the featured collection.

## New run items

The audit of the 20 core treasures found:
- seven cost reductions or extra mana
- two card-draw items (Scholar's Candle, Bottomless Satchel)
- two hero heals or Armor (Mending Charm, Thornhide Cloak)
- three weapon items
- three Deathrattle or Husk items
- three Rush or Attack items

None offers card *selection* (Discover), and none heals minions.

| Item | Group | Rarity | Effect | Closest existing item and difference | Limits |
| --- | --- | --- | --- | --- | --- |
| Ballroom Invitation | Mechanic support | rare | Start each match with a Masked Reveler in play. | Living Armory (a free legendary in hand): this is a small body on board that wants a ping. Without a ping it is a 2/2. | Once per match; duplicates install once. |
| Hostess's Hand-Bell | Mechanic support | common | At the start of your turn, deal 1 damage to a random friendly Masked minion. | Plague Bell (Husks +1 Attack): this is a reveal engine. Without masks it does nothing. Bad for mask-keeping decks, by design. | Once per own turn, Masked targets only. |
| Dance Card | Gap fill | rare | At the start of your 3rd turn, Discover a card. | Scholar's Candle (draws on turns 2 and 4): this is one chosen card, any collection-legal card. | Once per match. |
| Smelling Salts | Gap fill | rare | At the end of your turn, restore 2 Health to your minions. | Mending Charm (heals the hero): this heals minions. Healing never re-masks. | Once per own turn. |

Both items enter the treasure pool only for a run featuring the collection.
Save and resume reuse the treasure system's existing installer path; the run
test saves and resumes a featured run.

## Unlock

| Requirement | Rationale |
| --- | --- |
| Win 3 lifetime runs (`runs_won` 3) | Early and discoverable: a new player gets there within a few sessions. |
| Defeat the Mirror Sage once (`boss_defeated` `boss_mirror_sage` 1) | Skill-expressive and on theme: a band-2 boss that copies your minions, a mirror at the masquerade. It appears in ordinary runs. |

`unlock_mode` is `all`. `retroactive` is true: existing profiles that already
meet both requirements get the set on their next load, through the existing
retro-grant. There are no unlock rewards beyond the set itself, and no
mastery trial (an owner decision, 2026-11-08). This is easier than Law of the
Jungle on purpose.

## Test results

All seven skill checks pass. The detail is in the iteration log.

| Check | Where | Result |
| --- | --- | --- |
| Schema | `validate.gd` (real loader); `midnight_masquerade_content_test.gd` structure tests | Ready, 0 errors |
| Mechanic and run items | `midnight_masquerade_unmask_test.gd`: 11 rule tests, 5 item tests | Pass |
| Bosses | Same suite: activation, absent prerequisite, replay | Pass |
| Unlock | `midnight_masquerade_content_test.gd`: met, each part unmet, locked run rejected | Pass |
| Smoke | Headless validator load, both card sweeps (48 cards x 2 boards x 2 sides) | Pass |
| Legendary | 2 per class, distinct playstyles, real enablers, no neutral legendary | Pass |
| Balance | `masquerade_content.py` 1-SD curve pass; content validator budgets | 6 flags, each justified below |

**Balance flags (1 SD from the base curve):**
- **Above curve, all strong masks priced against their downgrade:**
  - Borrowed Finery: 2 mana 3/2, becomes a 1/1.
  - Gossiping Duchess: 3 mana 4/3, becomes a 2/2.
  - Mirror Dancer: 1 mana 2/2, becomes a 1/1.
  - Clockwork Double: 4 mana 5/4, becomes a 2/3.
  - Frost-Masked Scholar: 3 mana 4/3, becomes a 2/3.
- **Below curve:** Candle Page, a 1/1 that pays for its Battlecry ping.

## Playtest notes

A read-through against all 16 core bosses and both new bosses.

**Core bosses:**
- **Torchbearer, Pyre Sergeant, Blood Abbess and Scrap Golem** never hit
  minions; masks stay on. Mask-keeping decks are at their best here, and
  reveal-up decks rely on their own pings.
- **Rat King and Bog Witch** flood small boards. Curtain Call and Madame Steel
  clear 1/1s and reveal your masks at the same time.
- **Gatekeeper:** all boss minions have Taunt. The Faceless silences what it
  attacks, which strips that Taunt.
- **Rot Warden:** boss deaths ping your hero. Lifesteal support offsets it.
- **Hollow King:** +1/+1 every turn. The Archivist of Faces strips the stacked
  enchantments; strong, but six mana, and the king rebuffs.
- **Iron Tollman:** minions cost 1 more. Keep the Mask's cheap strong masks
  suffer; the spells (Hush, Guard the Guests, Venom Kiss) do not.
- **Lich Archivist:** big spells reveal or kill your masks; Divine Shield is the
  answer.
- **Frost Hag:** freezes a random minion. Unmasking thaws it: transform makes a
  fresh minion (tested). Pinging your own frozen mask is a way out of the Freeze.
- **Shadow of the Delve:** boss minions have Stealth. Targeted Hush and Public
  Unveiling cannot reach them; Curtain Call, Dice of the Ball and The House
  Always Wins can.
- **Mirror Sage:** copies each minion you play. It gets your masks, so playing
  strong masks hands it strong masks. Reveal-up decks hand it monsters only if
  they then ping its board. This is the unlock boss: a deliberate lesson.
- **Dungeon Heart:** 2 damage to every enemy minion each turn.
  - A reveal-up board with 3+ Health becomes its true forms on the boss's first
    turn: Duelist, Sommelier, Gladiator, Baron, Varrus, Widow, Crimson Guest,
    Poison Taster.
  - Keep the Mask needs Divine Shield (Steward, Procession, Sir Aurel) or loses
    its masks to death or downgrade.
  - This is the strongest test of the theme's both-ways rule.

**New bosses:**
- **Madame Veil:** her reveals land on a known schedule. Removal and silence
  answer them. Reveal-up player decks can also ping her masks first, but that
  only helps her.
- **The Faceless Count:** shield-pop then strike is the intended lesson. Decay,
  War and Fortune do it naturally; Knowledge and Shadow should avoid silencing
  his masks.

**Legendaries, reachability and usefulness:**
- Every legendary sits in one or two of its class's six bundles.
- Varrus and Velisande need a ping. Every class with them carries one.
- The Archivist is weakest against boards of strong masks you would rather
  reveal. Use it against Hollow King or buffed boards.

**Dead cards:** none against every boss. Lady of Veils is still a 3/4 with a
+1/+1 buff when you have no mask worth locking.

**Trivializing:** none found. Smelling Salts against the Dungeon Heart was the
closest. It undoes 2 damage per turn on survivors but cannot save minions with
2 or less Health. It was raised from common to rare (iteration 2).

**Run items:**
- Ballroom Invitation with Hand-Bell makes a 4/3 on turn 2. That is bounded:
  one minion, once per match.
- Hand-Bell is bad in a Keep the Mask deck. Its common rarity reflects that it
  helps only one of the two themes.
- Dance Card and Smelling Salts work with no Masked minion (tested).

## Watchlist

- **Dungeon Heart:** watch for a reveal-up deck making it too easy, and check
  that Keep the Mask decks still beat it. Measure with the sim harness once the
  boss AI is taught to value Unmask.
- **Boss AI:** it does not yet predict reveals. Today the AI treats a mask as its
  printed body, so it may ping a strong mask it should leave alone.
- **Gambler's Mask:** 50 % for a 5/4 on a 2-mana card is swingy. Watch its win
  rate.
- **Mirror Sage:** strong masks copied by Mirror Sage may make the unlock boss
  harder for Order and Shadow.

## Finalization checklist

- [x] Theme locked and documented, with the owner's "both directions" requirement.
- [x] One new mechanic (Unmask) with rules text, edge cases and passing tests.
- [x] Two previous mechanics supported: poisonous (7 cards) and lifesteal (3
      cards plus Sir Aurel's true form), plus silence.
- [x] Neutral and class cards in `assets/data/midnight-masquerade/cards.json`:
      48 collectibles, 37.5 % Neutral.
- [x] No Neutral legendary; exactly 2 legendaries per class with different
      playstyles, documented with enablers.
- [x] Two new bosses use Unmask and are tested with and without masks.
- [x] Two mechanic-support items and two gap-filling items, tested.
- [x] `unlock.json` exists, both requirements resolve against real data, and
      the unlock test passes.
- [x] Schema, mechanic, boss, unlock, smoke, legendary and balance checks pass.
- [x] This document and `iterations.md` are complete.
- [x] The owner approved the merge (2026-11-08). The collection is registered in
      `assets/data/collections.json`.
- [x] The README expansion table and the endgame spec reference the set.
