# Content

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
> **Author**: Jacob (owner) + `/design-system` (guided, lean)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 1 (every run builds a deck you couldn't have planned — bundles are plan-shaped); Pillar 2 (bosses are puzzles — every boss is a passive first); Pillar 4 (all content is data, loaded and validated, never special-cased)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` Specialists `game-designer`, `economy-designer`, `systems-designer`, `qa-lead` not consulted — Lean mode (no agent spawned); review Formulas F3/F4 and the Acceptance Criteria manually before the first `/balance-check`. Engine feasibility: `Gameplay` → Scripting domain (data only, no engine surface); no `docs/engine-reference/godot/modules/scripting.md` exists, so feasibility was **not checked against the pinned engine** — nothing here touches the engine beyond JSON the Card Database already loads.
> **REVISED 2026-11-03** (`/design-review`, lean, verdict NEEDS REVISION → revised in session): CN-5 rewritten against the Treasures GDD's authoritative T8 table (10 universal / 4 War / 3 Decay / 3 Knowledge; MVP 10 = 7 universal + 2 War + 1 Knowledge; ids named per batch — the 5/5/5/5 split and "5 generic + 5 War" MVP were wrong); CN-6 MVP-0 no longer ships `heroes.json` with three heroes whose starter cards are Alpha records (CR-5 step 6 `E_UNKNOWN_REF` would fail the batch's own "loads clean" gate) — `hero_war` / `power_whetstone` only at MVP-0 per DD-H06, Decay and Knowledge HeroDefs and powers ship with their set batches; hero-power and token batching corrected so no record is orphaned at a batch close (`power_mend` → VS, `neutral_sheep` → Alpha-B; AC-16, `.claude/rules/data-files.md`); AC-20 rescoped to match; F3 Kingsblade budget arithmetic (14, not 13) and F5 op count (25, not 26) fixed; Rot Warden MVP recipe made explicit; the unnumbered AC is now AC-21; Open Questions gained the card-effects R-3 (`tag` filter on board minions) and R-10 (observer-hosted event triggers on passive hosts) dependencies, the `counter`-in-Deathrattle question and the AC-13 target basis.
> **REVISED 2026-11-03 (cross-review)**: C-03 option B (Heroes raised `PLAN_MAX` to 7; Content **keeps** the `armour` tag on `war_iron_vanguard` so `bundle_war_armour_1` stays valid — no card row changed), C-23 (★ removed from `neutral_lantern_bearer`; it is an MVP-0 shared neutral in no starter, Heroes H-4), C-24 (`content_budgets.json` key list in CN-6 step 2), D-06 (MVP ships a spare band-1 boss — `boss_torchbearer` moves from Alpha-A to MVP-1 so the MVP pool is 5 = 3 / 1 / 1 and no two MVP runs need the same boss sequence; CN-1, CN-3, CN-6, F6, AC-2, AC-19), D-07 (AC-13 sim basis = `target_win_rate_by_floor`, harness reports boss win rate per floor; OQ resolved), D-04 (no boss uses `intent_mode: hidden`, noted in CN-3), DD-H05 (neutral bundles 6 → 12, 36 total: six new `bundle_neutral_*_2` rows in CN-4, batch table, CN-1, F5, F6, AC-3, Edge Cases, OQ resolved), C-30 housekeeping (`BossDef.tags` / `passive_text` exist in CR-3; Heroes H-4/H-5 carry the redesigned texts; Insight ships the tax text; card-effects C3 `tag` on board, C9 observers and C6.5 counter snapshot answered; `(concurrent)` labels and "must list Content" clauses dropped — Treasures and Reward Draft both list it).

## Summary

Content is the authored data plan for Deckdelve: 120 collectible cards across War, Decay, Knowledge
and Neutral, 16 bosses in three bands with a passive each, 36 three-card bundles with theme tags,
and the batch pipeline (MVP → Vertical Slice → Alpha) that writes, validates, balances and audits
them. For the player it is the variety they draft and the puzzles they fight; for the team it is
the order of work and the definition of done for the project's largest scope risk. Every card and
passive here stays inside the Card Effects v1 DSL, and the two that did not were redesigned.

> **Quick reference** — Layer: `Feature` · Priority: `MVP → Alpha` · Key deps: `Card Database, Card Effects, Heroes, Boss AI, Treasures, Run Structure, Reward Draft`

## Overview

Framing: both — Content is a data layer (every card, boss, bundle and token is a JSON record the
Card Database loads) and the thing the player actually touches: the 120 cards they draft, the 16
bosses they fight, the 36 bundles they choose between. This GDD is the **authored data plan and its
production pipeline**: which records exist, in which batch they are written (MVP → Vertical Slice
→ Alpha), what each must say at concept level (id, cost, stats, keywords, text, tags), and how a
batch is validated (a clean Card Database load), balanced (`/balance-check` against the curve,
sim win rates and pick rates) and audited (`/content-audit` counts). It does not define rules —
Match Rules, Card Effects, Heroes, Boss AI and the Treasures / Reward Draft GDDs own
those — and it writes **no JSON itself**: Config/Data stories author the files from the tables
here. Every card text below is expressible in the Card Effects v1 DSL and names the archetype row
of its C11 coverage table; the two planned cards that were not (`war_quartermaster`,
`war_cleave_through`) were redesigned rather than special-cased (Pillar 4). Without this
document the 120-card, 16-boss volume — the systems index's biggest scope risk — has no order of
work, no definition of "done" per batch, and no way to tell a balance problem from a missing card.

## Player Fantasy

`creative-director` not consulted — Lean mode. Framing: **indirect** — the player never sees a
batch or a validation report; they feel the content as *variety with a spine*. The fantasy served
is the concept's **improvised mastery**: three bundles fan out and at least one of them talks to
the deck the player already has (theme tags), one tempts them off it, and the boss intro names a
rule that must be answered with what they drafted. The feeling to protect is **recognition
without repetition** — a War player should meet weapons, Armour and Charge in many shapes across
a run, never the same three cards; a returning player should meet a boss they know and still
have to think. The anti-fantasy is the solved pool: if players can rank the 45 neutrals once and
stop reading, the tags and budgets below have failed (Pillar 1 design test). Bosses serve Pillar
2's question-shaped fantasy ("can War out-race a boss that heals 5 a turn?"): each entry names
the puzzle in one line so the Config/Data story cannot ship a stat wall by accident.

## Detailed Design

### Core Rules

Specialist note: `game-designer` / `economy-designer` / `systems-designer` not spawned — Lean
mode. Review manually before production.

#### CN-1. Scope, counts and batches

| Kind | v1 total | MVP | VS (cumulative) | Alpha (cumulative) | Owner of the schema |
|---|---|---|---|---|---|
| Collectible cards | 120 (war 25, decay 25, knowledge 25, neutral 45) | 40 (war 25 + neutral 15) | 60 (+20 neutral) | 120 (+decay 25, knowledge 25, neutral 10) | Card Database CR-3 |
| Tokens (never in pools) | 7 | 3 | 3 | 7 | Card Database CR-3 `token` |
| Boss-only cards (`cards_boss.json`) | 32 (2 per boss) | 10 | 18 | 32 | Card Database CR-3, set `boss` |
| Bosses | 16 (band 6 / 6 / 4, DD-R02) | 5 (3 / 1 / 1 — DD-H06's 4 plus one spare band-1 boss, cross-review D-06, so the MVP boss sequence varies between runs) | 9 (4 / 3 / 2 — one full run) | 16 | Card Database BossDef |
| Bundles | 36 (8 per hero + 12 neutral, DD-H05) | 10 (8 war + 2 neutral) | 16 (+6 neutral) | 36 (+8 decay, +8 knowledge, +4 neutral) | Card Database BundleDef |
| Treasures | 20 (Treasures GDD) | 10 (DD-H06) | 12 | 20 | Treasures GDD |
| Hero powers | 3 hero + 4 boss | 1 (`power_whetstone` — DD-H06 is War-only at MVP) | 3 (+`power_mend`, `power_drain` with their bosses) | 7 (+`power_rot` Alpha-A; +`power_insight`, `power_reinforce`, `power_brand` Alpha-B) | Heroes (hero) / this GDD (boss) |

Batch definitions are in CN-6. Priorities follow the systems index: Content is MVP for the first
40 cards, 5 bosses (DD-H06's 4 plus the D-06 spare) and 10 bundles and grows to Alpha scope.

**Decision — starter cards are part of the hero set and collectible.** The 7 War, 6 Decay and 6
Knowledge starter cards count toward their set's 25 and may appear in bundles and Discover.
Rationale: (a) `hero_set_size` 25 is the whole set by DD-H03 and Card Database's
`collectible_pool_size` formula counts every non-token set card; (b) a second Grave Rat or Rusted
Axe in a bundle is a *good* plan-shaped offer, not a dud (Dungeon Run does the same); (c) the
alternative — 25 non-starter cards plus 19 starter-only cards — is 139 cards for the price of 120
and raises the scope risk the index flags. The 7 shared neutrals Heroes H-4 authors likewise count
toward 45 — six of them are starter cards; the seventh, `neutral_lantern_bearer`, ships in MVP-0
with them but sits in no launch starter (cross-review C-23), so it is a plain collectible.

**Decision — tokens are not counted and never pooled.** `token: true` cards (Card Database CR-6)
sit in their owner set's file, carry no rarity weight in audits, and are referenced only by
`summon` / `equip` / `transform` ops.

#### CN-2. Card plan

Column key — **T**: M minion · S spell · W weapon. **Stats**: attack/health, or attack/durability
for weapons. **Row**: the Card Effects C11 archetype row the text is written with (`van` =
vanilla, no effect; `kw` = keywords only; an op name = same pattern as the row's op without a
dedicated row). **R**: C common · R rare · L legendary. **Tags** are the theme tags bundles
reference (CN-4). **Batch**: MVP · VS · Alpha; ★ = starter card (Heroes H-4); ◆ = signature card
(Heroes H-5). ★ marks starter membership only, not the MVP-0 batch: `neutral_lantern_bearer` is
MVP-0 but unstarred (cross-review C-23). All text obeys the style guide in CN-6 and is ≤ 90 characters.

*War set — `cards_war.json`, 25 cards (13 M / 6 S / 6 W), all MVP.*

| id | Name | T | Cost | Stats | Keywords | Text | Row | R | Tags |
|---|---|---|---|---|---|---|---|---|---|
| `war_shield_squire` ★ | Shield Squire | M | 1 | 1/2 | battlecry | Battlecry: Gain 2 Armor. | armor | C | armour |
| `war_sharpen` ★ | Sharpen | S | 1 | — | — | Give your weapon +2 Attack this turn. | 1 | C | weapons |
| `war_blade_strike` | Blade Strike | S | 1 | — | — | Deal damage equal to your weapon's Attack to an enemy minion. | 6 | C | weapons, aggro |
| `war_throwing_axe` | Throwing Axe | W | 1 | 1/1 | battlecry | Battlecry: Deal 1 damage. | 3 | C | weapons |
| `war_rusted_axe` ★ | Rusted Axe | W | 2 | 2/2 | — | — | van | C | weapons |
| `war_warcry` ★ | Warcry | S | 2 | — | — | Give your minions +1 Attack this turn. | 15 | C | aggro |
| `war_blade_apprentice` | Blade Apprentice | M | 2 | 2/2 | battlecry | Battlecry: If you have no weapon, equip a 1/2 Whetstone Blade. | 2 + 4 | C | weapons |
| `war_armorer` | Armorer | M | 2 | 2/3 | battlecry | Battlecry: Gain Armor equal to your weapon's Attack. | 5 + 6 | R | armour, weapons |
| `war_cellar_raider` | Cellar Raider | M | 2 | 3/1 | rush | Rush. | kw | C | aggro |
| `war_iron_resolve` | Iron Resolve | S | 2 | — | — | Gain 4 Armor. Draw a card. | armor, draw | C | armour |
| `war_iron_vanguard` ★ | Iron Vanguard | M | 3 | 2/4 | taunt | Taunt. | kw | C | armour |
| `war_quartermaster` ★ | Quartermaster | M | 3 | 2/3 | battlecry | Battlecry: If you have a weapon, draw a card. | 4 | C | weapons |
| `war_berserker` | Pit Berserker | M | 3 | 3/2 | — | Whenever this minion takes damage, gain +2 Attack. | 11 | R | aggro |
| `war_heavy_maul` | Heavy Maul | W | 3 | 3/2 | battlecry | Battlecry: Gain 2 Armor. | armor | C | weapons, armour |
| `war_cleave_through` ◆ | Cleave Through | S | 3 | — | — | Deal 2 damage to all enemy minions. If you have a weapon, deal 3 instead. | 3 + 4 | R | weapons, aggro |
| `war_rally` | Rally | S | 3 | — | — | Give your minions +1/+1. | 15 | C | aggro |
| `war_pit_brawler` ★ | Pit Brawler | M | 4 | 4/3 | charge | Charge. | kw | C | aggro |
| `war_shieldwall_veteran` | Shieldwall Veteran | M | 4 | 3/4 | taunt, battlecry | Taunt. Battlecry: Gain 3 Armor. | armor | C | armour |
| `war_shield_maiden` | Shield Maiden | M | 4 | 2/4 | taunt, divine_shield | Taunt. Divine Shield. | 28 | R | armour |
| `war_duelists_edge` ◆ | Duelist's Edge | W | 4 | 3/3 | — | Whenever your hero attacks, gain 2 Armor. | 5 | R | weapons, armour |
| `war_pit_champion` ◆ | Pit Champion | M | 5 | 4/6 | battlecry | Battlecry: Your hero has Windfury this turn. | 15 (buff keywords, until_end_of_turn) | L | aggro, weapons |
| `war_twin_hatchets` | Twin Hatchets | W | 5 | 2/4 | windfury | Windfury. | kw | R | weapons, aggro |
| `war_warlord` | Warlord of the Pit | M | 6 | 5/5 | aura | Your other minions have +1 Attack. | 26 | R | aggro |
| `war_kingsblade` | Kingsblade | W | 6 | 4/2 | battlecry | Battlecry: Deal 2 damage to all enemy minions. | 3 | L | weapons |
| `war_headsman` | Headsman | M | 7 | 5/5 | battlecry | Battlecry: Destroy a damaged minion. | destroy (`is_damaged`) | L | aggro |

Redesigns (v1 expressiveness): `war_quartermaster` was "Give your weapon +1 Durability" (Heroes
H-4) — `weapon_durability` is a provisional op (`E_FX_OP_UNAVAILABLE`), so the text becomes a
conditional draw that still rewards holding the Whetstone Blade; the durability text returns as a
new card when `modify_durability` lands. `war_cleave_through` was "a minion and the minions next to
it" — `adjacent` is source-relative only, so the card becomes a conditional board sweep. Both keep
their ids; Heroes H-4/H-5 carry the redesigned texts since 2026-11-03 (cross-review C-30).

*Decay set — `cards_decay.json`, 25 cards (17 M / 8 S / 0 W), all Alpha.*

| id | Name | T | Cost | Stats | Keywords | Text | Row | R | Tags |
|---|---|---|---|---|---|---|---|---|---|
| `decay_grave_rat` ★ | Grave Rat | M | 1 | 1/1 | deathrattle | Deathrattle: Summon a 1/1 Husk. | 9 | C | deathrattle, husk |
| `decay_plague_rat` | Plague Rat | M | 1 | 1/1 | poisonous | Poisonous. | kw | C | sacrifice |
| `decay_soul_tithe` | Soul Tithe | S | 1 | — | — | Destroy a friendly minion. Gain Mana Crystals this turn equal to its Cost. | 10 + mana (`ref target.cost`) | R | sacrifice |
| `decay_last_rites` | Last Rites | S | 1 | — | — | Trigger a friendly minion's Deathrattle. | 14 | C | deathrattle |
| `decay_carrion_crow` ★ | Carrion Crow | M | 2 | 2/1 | deathrattle | Deathrattle: Draw a card. | 7 | C | deathrattle |
| `decay_culling` ★ | Culling | S | 2 | — | — | Destroy a friendly minion. Draw 2 cards. | 10 | C | sacrifice |
| `decay_rot_beetle` | Rot Beetle | M | 2 | 1/3 | deathrattle | Deathrattle: Give a random friendly minion +2/+2. | 9 + 15 | C | deathrattle |
| `decay_grave_robber` | Grave Robber | M | 2 | 2/2 | battlecry | Battlecry: Destroy a friendly minion to gain +2/+2. | 10 (ops: destroy, buff self) | R | sacrifice |
| `decay_mass_grave` | Mass Grave | S | 2 | — | — | Summon two 1/1 Husks. | 9 | C | husk |
| `decay_husk_tender` ★ | Husk Tender | M | 3 | 2/3 | battlecry | Battlecry: Summon a 1/1 Husk. | 9 | C | husk |
| `decay_grave_warden` ★ | Grave Warden | M | 3 | 1/4 | taunt | Taunt. | kw | C | — |
| `decay_husk_herder` | Husk Herder | M | 3 | 3/3 | battlecry | Battlecry: Give your Husks +1/+1. | 15 (filter `tag: husk`) | C | husk |
| `decay_crypt_leech` | Crypt Leech | M | 3 | 2/3 | lifesteal, deathrattle | Lifesteal. Deathrattle: Restore 3 Health to your hero. | 7 (heal) | C | deathrattle |
| `decay_relic_keeper` | Relic Keeper | M | 3 | 2/2 | deathrattle | Deathrattle: Add a random Decay card to your hand. | 13 | R | deathrattle |
| `decay_feast_of_worms` ◆ | Feast of Worms | S | 3 | — | — | Destroy a friendly minion. Summon three 1/1 Husks. | 16 | R | sacrifice, husk |
| `decay_raise_dead` | Raise Dead | S | 3 | — | — | Summon a 1/1 Husk for each friendly minion that died this turn. | 9 (`count: ref owner.minions_died_this_turn`) | C | husk |
| `decay_shambling_heap` ★ | Shambling Heap | M | 4 | 3/4 | deathrattle | Deathrattle: Summon two 1/1 Husks. | 9 | C | deathrattle, husk |
| `decay_corpse_collector` | Corpse Collector | M | 4 | 3/4 | — | Whenever a friendly minion dies, gain +1/+1. | 11 | R | deathrattle, sacrifice |
| `decay_tomb_spider` | Tomb Spider | M | 4 | 1/5 | taunt, poisonous | Taunt. Poisonous. | kw | R | sacrifice |
| `decay_blight` | Blight | S | 4 | — | — | Deal 2 damage to all minions. | 19 (`all_minions`) | C | deathrattle, sacrifice |
| `decay_plague_of_rot` ◆ | Plague of Rot | S | 4 | — | — | Destroy all your Husks. Deal 1 damage to all enemies for each. | 12 (`set_counter` husks → destroy → damage `ref counter`) | R | husk |
| `decay_husk_mother` ◆ | Husk Mother | M | 5 | 3/6 | — | Whenever a friendly minion dies, summon a 1/1 Husk. | 11 + 9 | L | husk, deathrattle |
| `decay_boneyard_brute` | Boneyard Brute | M | 5 | 3/4 | deathrattle | Deathrattle: Summon a 3/3 Skeleton. | 9 | C | deathrattle |
| `decay_plaguebearer` | Plaguebearer | M | 6 | 5/5 | deathrattle | Deathrattle: Deal 2 damage to all enemy minions. | 7 + 3 | L | deathrattle |
| `decay_grave_titan` | Grave Titan | M | 7 | 6/6 | deathrattle | Deathrattle: Summon two 2/2 Ghouls. | 9 | L | deathrattle |

*Knowledge set — `cards_knowledge.json`, 25 cards (11 M / 14 S / 0 W), all Alpha.*

| id | Name | T | Cost | Stats | Keywords | Text | Row | R | Tags |
|---|---|---|---|---|---|---|---|---|---|
| `knowledge_candle_acolyte` ★ | Candle Acolyte | M | 1 | 1/2 | spell_damage (1) | Spell Damage +1. | 17 | C | spell_damage |
| `knowledge_spark` | Spark | S | 1 | — | — | Deal 1 damage. Draw a card. | 18 + draw | C | spells, draw |
| `knowledge_lost_page` | Lost Page | S | 1 | — | — | Discover a spell that costs (3) or less. | 20 (`cost_le: 3`) | C | discover |
| `knowledge_glyph_wards` | Glyph Wards | S | 1 | — | — | Summon two 0/2 Wards with Taunt. | 9 | C | spells |
| `knowledge_ink_sprite` | Ink Sprite | M | 1 | 1/1 | — | Whenever you cast a spell, gain +1/+1. | 21 (buff self) | C | spells |
| `knowledge_frost_lance` ★ | Frost Lance | S | 2 | — | — | Deal 2 damage to a minion and Freeze it. | 18 + 23 | C | spells |
| `knowledge_archive_seeker` ★ | Archive Seeker | M | 2 | 2/2 | battlecry, discover | Battlecry: Discover a spell. | 20 | C | discover |
| `knowledge_apprentice` ◆ | Apprentice | M | 2 | 2/2 | aura | Your spells cost (1) less. | 24 | R | spells |
| `knowledge_scrying` | Scrying | S | 2 | — | — | Discover a Knowledge card. | 20 (`set: knowledge`) | C | discover |
| `knowledge_study` ★ | Study | S | 3 | — | — | Draw 2 cards. | draw | C | draw |
| `knowledge_lightning_lash` ★ | Lightning Lash | S | 3 | — | — | Deal 3 damage to a minion. | 18 | C | spells |
| `knowledge_rune_warden` | Rune Warden | M | 3 | 2/3 | taunt, spell_damage (1) | Taunt. Spell Damage +1. | 17 | C | spell_damage |
| `knowledge_glacial_wind` | Glacial Wind | S | 3 | — | — | Freeze all enemy minions. | 23 (`all_enemy_minions`) | R | spells |
| `knowledge_lorekeeper` ★ | Lorekeeper | M | 4 | 3/5 | spell_damage (1) | Spell Damage +1. | 17 | C | spell_damage |
| `knowledge_scribe` | Scribe | M | 4 | 3/4 | — | Whenever you cast a spell, draw a card. | 21 | R | draw |
| `knowledge_meteor_bolt` | Meteor Bolt | S | 4 | — | — | Deal 6 damage. | 18 | C | spells |
| `knowledge_chain_lightning` ◆ | Chain Lightning | S | 4 | — | — | Deal 3 damage to a minion, then 2 damage to a random enemy minion. | 18 + 34 | R | spells, spell_damage |
| `knowledge_transmute` | Transmute | S | 4 | — | — | Transform an enemy minion into a 1/1 Sheep. | 31 | R | spells |
| `knowledge_rime_elemental` | Rime Elemental | M | 4 | 3/5 | battlecry, freeze | Battlecry: Freeze an enemy minion. | 23 | C | spells |
| `knowledge_flamewave` | Flamewave | S | 5 | — | — | Deal 3 damage to all enemy minions. | 19 | R | spell_damage |
| `knowledge_deep_study` | Deep Study | S | 5 | — | — | Draw 3 cards. | draw | C | draw |
| `knowledge_star_reader` | Star Reader | M | 5 | 3/5 | — | At the end of your turn, if you have 5 or more cards, deal 3 damage to a random enemy. | 22 | L | draw |
| `knowledge_grand_grimoire` ◆ | Grand Grimoire | M | 6 | 4/6 | spell_damage (2), battlecry, discover | Spell Damage +2. Battlecry: Discover a spell. | 17 + 20 | L | spell_damage, discover |
| `knowledge_forbidden_tome` | Forbidden Tome | S | 6 | — | — | Discover a spell. Repeat twice more. | 20 + 34 (`repeat` 3 → sequential choices, C8.4) | L | discover, draw |
| `knowledge_vault_golem` | Vault Golem | M | 7 | 6/7 | — | Costs (1) less for each spell you've cast this turn. | 24 (`passive_hand`, `mul spells_cast_this_turn`) | R | spells |

*Neutral set — `cards_neutral.json`, 45 cards (37 M / 5 S / 3 W). Neutral theme tags: `wall`
(Taunt / Divine Shield bodies), `tempo` (cheap Charge / Rush / Stealth), `value` (draw, copy,
Discover), `tricks` (Silence, swap, return, Freeze), `pings` (random and board damage), `big`
(5+ drops). Starter neutrals carry tags where useful so neutral bundles may include them.*

| id | Name | T | Cost | Stats | Keywords | Text | Row | R | Tags | Batch |
|---|---|---|---|---|---|---|---|---|---|---|
| `neutral_torch_imp` ★ | Torch Imp | M | 1 | 1/2 | — | — | van | C | — | MVP |
| `neutral_tunnel_rat` ★ | Tunnel Rat | M | 1 | 2/1 | — | — | van | C | tempo | MVP |
| `neutral_cellar_guard` ★ | Cellar Guard | M | 2 | 2/3 | — | — | van | C | — | MVP |
| `neutral_lantern_bearer` | Lantern Bearer | M | 2 | 2/2 | taunt | Taunt. | kw | C | wall | MVP |
| `neutral_bulwark_smith` | Bulwark Smith | M | 2 | 2/2 | battlecry | Battlecry: Give a friendly minion Taunt. | give_keyword | C | wall | MVP |
| `neutral_smite_or_mend` | Smite or Mend | S | 2 | — | — | Choose One — Deal 2 damage to a character; or Restore 4 Health to it. | 33 | C | tricks | MVP |
| `neutral_dungeon_delver` ★ | Dungeon Delver | M | 3 | 3/4 | — | — | van | C | — | MVP |
| `neutral_hush_owl` | Hush Owl | M | 3 | 2/3 | battlecry, silence | Battlecry: Silence a minion. | 29 | C | tricks | MVP |
| `neutral_spark_fiend` | Spark Fiend | M | 3 | 1/4 | — | At the start of your turn, deal 1 damage to a random enemy minion, twice. | 34 | R | pings | MVP |
| `neutral_gravekeeper` | Gravekeeper | M | 3 | 2/3 | deathrattle | Deathrattle: Deal 1 damage to the enemy hero per minion that died while this was in play. | `add_counter` on `on_minion_died any` → 12 with `ref counter` | R | pings | MVP |
| `neutral_banner_captain` | Banner Captain | M | 3 | 2/2 | aura | Your other minions have +1/+1. | 26 | R | tempo | MVP |
| `neutral_wolf_rider` | Wolf Rider | M | 3 | 3/1 | charge | Charge. | kw | C | tempo | MVP |
| `neutral_shield_golem` | Shield Golem | M | 4 | 3/3 | taunt, divine_shield | Taunt. Divine Shield. | 28 | C | wall | MVP |
| `neutral_crypt_brute` ★ | Crypt Brute | M | 4 | 4/5 | — | — | van | C | — | MVP |
| `neutral_ogre_porter` ★ | Ogre Porter | M | 5 | 5/6 | — | — | van | C | big | MVP |
| `neutral_rusty_dagger` | Rusty Dagger | W | 1 | 1/2 | — | — | van | C | tempo | VS |
| `neutral_novice_scout` | Novice Scout | M | 2 | 1/2 | battlecry | Battlecry: Draw a card. | draw | C | value | VS |
| `neutral_tunnel_shaman` | Tunnel Shaman | M | 2 | 2/2 | battlecry | Battlecry: Return a friendly minion to your hand. | 30 | C | tricks | VS |
| `neutral_cutpurse` | Cutpurse | M | 2 | 2/2 | stealth | Stealth. | kw | C | tempo | VS |
| `neutral_charging_boar` | Charging Boar | M | 2 | 2/1 | charge | Charge. | kw | C | tempo | VS |
| `neutral_field_medic` | Field Medic | M | 2 | 1/3 | battlecry | Battlecry: Restore 3 Health. | heal (`chosen any`) | C | value | VS |
| `neutral_powder_keg` | Powder Keg | M | 2 | 0/2 | deathrattle | Deathrattle: Deal 2 damage to all minions. | 7 + 19 | R | pings | VS |
| `neutral_muzzle` | Muzzle | S | 2 | — | — | Silence a minion. Draw a card. | 29 + draw | C | tricks | VS |
| `neutral_treasure_map` | Treasure Map | S | 2 | — | — | Draw a card. Gain 1 Mana Crystal this turn. | draw + mana | C | value | VS |
| `neutral_mimic` | Mimic | M | 3 | 2/3 | battlecry | Battlecry: Add a copy of a friendly minion to your hand. | 32 | R | value | VS |
| `neutral_hex_doctor` | Hex Doctor | M | 3 | 3/2 | battlecry | Battlecry: Swap a minion's Attack and Health. | set_stats (C5 swap) | R | tricks | VS |
| `neutral_temple_guard` | Temple Guard | M | 3 | 2/3 | divine_shield | Divine Shield. | kw | C | wall | VS |
| `neutral_blood_tick` | Blood Tick | M | 3 | 3/3 | lifesteal | Lifesteal. | kw | R | value | VS |
| `neutral_miners_pick` | Miner's Pick | W | 3 | 2/3 | battlecry | Battlecry: Draw a card. | draw | R | value | VS |
| `neutral_rockfall` | Rockfall | S | 3 | — | — | Deal 3 damage to a random enemy minion, twice. | 34 | R | pings | VS |
| `neutral_storm_harpy` | Storm Harpy | M | 4 | 3/4 | windfury | Windfury. | kw | R | tempo | VS |
| `neutral_stone_sentinel` | Stone Sentinel | M | 5 | 3/7 | taunt | Taunt. | kw | C | wall, big | VS |
| `neutral_great_cleaver` | Great Cleaver | W | 5 | 4/3 | — | — | van | R | big | VS |
| `neutral_hill_giant` | Hill Giant | M | 6 | 6/7 | — | — | van | C | big | VS |
| `neutral_war_mammoth` | War Mammoth | M | 7 | 7/7 | taunt | Taunt. | kw | C | big, wall | VS |
| `neutral_ember_sprite` | Ember Sprite | M | 1 | 1/1 | stealth, deathrattle | Stealth. Deathrattle: Deal 1 damage to a random enemy. | 7 (`random_enemy_character`) | C | pings | Alpha |
| `neutral_gate_guardian` | Gate Guardian | M | 2 | 1/4 | taunt | Taunt. | kw | C | wall | Alpha |
| `neutral_hedge_wizard` | Hedge Wizard | M | 3 | 2/3 | spell_damage (1) | Spell Damage +1. | 17 | C | pings | Alpha |
| `neutral_relic_hunter` | Relic Hunter | M | 3 | 2/2 | battlecry, discover | Battlecry: Discover a minion. | 20 (`type: minion`) | C | value | Alpha |
| `neutral_pit_hound` | Pit Hound | M | 4 | 4/3 | rush | Rush. | kw | C | tempo | Alpha |
| `neutral_battle_plan` | Battle Plan | S | 4 | — | — | Draw 2 cards. Gain 2 Armor. | draw + armor | C | value | Alpha |
| `neutral_old_lamplighter` | Old Lamplighter | M | 4 | 3/3 | — | At the end of your turn, restore 2 Health to all friendly characters. | heal on `turn_end` | L | wall | Alpha |
| `neutral_the_collector` | The Collector | M | 5 | 4/4 | battlecry | Battlecry: Add a copy of each other friendly minion to your hand. | 32 (`all_friendly_minions`, `not_self`) | L | value | Alpha |
| `neutral_hourglass_mage` | Hourglass Mage | M | 5 | 4/5 | battlecry, freeze | Battlecry: Freeze all enemy minions. | 23 | L | tricks | Alpha |
| `neutral_dungeon_warden` | Dungeon Warden | M | 8 | 8/8 | taunt, battlecry | Taunt. Battlecry: Gain 5 Armor. | armor | L | big, wall | Alpha |

*Tokens (`token: true`, no rarity weight, never pooled).* `war_whetstone_blade` W 1 — 1/2
(Heroes H-3; registry) · `decay_husk` M 1 — 1/1, tag `husk` (Heroes; registry) · `decay_skeleton`
M 3 — 3/3 · `decay_ghoul` M 2 — 2/2 · `knowledge_ward` M 0 — 0/2 Taunt · `neutral_sheep` M 1 — 1/1
(card-effects row 31) · `boss_rat` M 1 — 1/1, tag `rat`. MVP ships three: `war_whetstone_blade`
(MVP-0, with `power_whetstone`), `boss_rat` and `decay_husk` (MVP-1, with the Rat King and
`boss_rot_zombie`; the Husk ships in a `cards_decay.json` holding only that record until Alpha-A —
CR-1 loads a set file whenever it is present). The Sheep lands with `knowledge_transmute`
(Alpha-B), the Skeleton and Ghoul with Decay (Alpha-A), the Ward with Knowledge (Alpha-B): a token
is never in a batch before the first op that references it, or AC-16 fails at that batch's close.

**Signature cards (3 per hero, Heroes H-5)**: War — Duelist's Edge, Pit Champion, Cleave Through
(redesigned text). Decay — Husk Mother, Plague of Rot, Feast of Worms. Knowledge — Grand
Grimoire, Chain Lightning, Apprentice. Each must pass Heroes F5 (`synergy ≥ 5`); CN-4 puts every
signature card in at least one bundle.

**Mana curve and keyword summary (checked by F2 / F5):** War avg 3.16 (buckets 1:4 2:6 3:6 4:4
5:2 6:2 7:1), Decay 3.12 (4/5/7/5/2/1/1), Knowledge 3.32 (5/4/4/6/3/2/1), Neutral 3.16
(4/13/14/6/5/1/1/1). Rarity: hero sets 15 C / 7 R / 3 L; neutral 30 / 11 / 4. Every DD-M09 keyword
appears on ≥ 2 collectible cards (Stealth: Cutpurse, Ember Sprite; Rush: Cellar Raider, Pit Hound;
Windfury: Twin Hatchets, Storm Harpy; the rest ≥ 3) and every non-provisional C5 op is used by ≥ 1
collectible card except `modify_value`, which is legal only on treasure/passive hosts and is
covered by boss passives (CN-3).

#### CN-3. Boss plan

16 bosses, 6 / 6 / 4 by band (DD-R02), health 30 / 40 / 50 (`boss_starting_health_by_band`; no
boss deviates, so `W_BAND_HEALTH` never fires at v1 — escalation is the passive, Pillar 2). Every
boss has a **passive** (a BossDef `passive` effects array, Card Effects C9) or a hero power, and
exactly one `theme` tag for Run Structure's `no_adjacent_shared_theme` knob, stored in
`BossDef.tags[]` (Card Database CR-3; the passive's player-facing line is `passive_text`, key
`boss.<id>.passive`). `ai_profile` names a key in `ai_profiles.json` (Boss AI C10); the
resolved profile is `default ⊕ archetype ⊕ band overlay ⊕ boss override`. Band 1 is always
`intent_mode: full`; the one `class_only` boss is band 3 with its reason recorded here (Boss AI
C8.4), and **no boss uses `hidden`** — it is reserved for a boss whose own passive text announces
concealment, and v1 has none (cross-review D-04; `telegraph_mode = off` is the player's opt-in,
DD-X03). Boss hero powers live in `hero_powers.json` beside the hero ones: `power_mend` (2) "Restore
3 Health to your hero" · `power_brand` (2) "Deal 2 damage to the enemy hero" · `power_drain` (2)
"Deal 2 damage to a minion. Restore 2 Health to your hero" · `power_reinforce` (2) "Gain 3 Armor".

*B1 — identity, passive and AI.* DSL column: trigger → targets → ops (every entry is a C11 pattern).

| id | Name | Band | HP | Hero power | Passive text (`passive`) | DSL hook sketch | `ai_profile` (+ override) | Theme | Batch |
|---|---|---|---|---|---|---|---|---|---|
| `boss_rat_king` | The Rat King | 1 | 30 | — | At the start of the boss's turn, summon a 1/1 Rat. | `turn_start{side:owner}` → `summon boss_rat ×1 position:end` (row 9) | `aggro` | swarm | MVP |
| `boss_gatekeeper` | The Gatekeeper | 1 | 30 | — | The boss's minions have Taunt. | `aura` → `all_friendly_minions` → `aura keywords:[taunt]` (row 42) | `control` | wall | MVP |
| `boss_cellar_hermit` | The Cellar Hermit | 1 | 30 | `power_mend` | — | hero power: `heal 3` → `owner_hero` (row 35 shape) | `default` + `hero_power: always` | heal | VS |
| `boss_torchbearer` | The Torchbearer | 1 | 30 | — | At the end of the boss's turn, deal 1 damage to the enemy hero. | `turn_end{side:owner}` → `enemy_hero` → `damage 1` (row 7 shape) | `aggro` | burn | MVP (D-06 spare band-1 boss; was Alpha-A) |
| `boss_scrap_golem` | The Scrap Golem | 1 | 30 | `power_reinforce` | At the start of the match, the boss gains 5 Armor. | `on_match_start` → `owner` → `armor 5` (row 38) | `control` | armour | Alpha |
| `boss_bog_witch` | The Bog Witch | 1 | 30 | — | Whenever a boss minion dies, the boss draws a card. | `on_minion_died{who:friendly_minion}` → `draw 1` (row 11 shape) | `passive_driven` + `synergy_tags:[deathrattle]` | deathrattle | Alpha |
| `boss_rot_warden` | The Rot Warden | 2 | 40 | — | Whenever a boss minion dies, deal 1 damage to the enemy hero. | `on_minion_died{who:friendly_minion}` → `enemy_hero` → `damage 1` | `passive_driven` + `synergy_tags:[deathrattle], w_self 1.5` (Boss AI F9 example) | deathrattle | MVP |
| `boss_blood_abbess` | The Blood Abbess | 2 | 40 | — | At the start of the boss's turn, restore 5 Health to the boss. | row 35 verbatim | `control` | heal | VS |
| `boss_iron_tollman` | The Iron Tollman | 2 | 40 | — | The player's minions cost (1) more. | `modify_cost{card:{side:enemy,type:minion}}` → `modify_value delta:1` (row 36) | `tempo` | control | VS |
| `boss_frost_hag` | The Frost Hag | 2 | 40 | — | At the end of the boss's turn, Freeze a random enemy minion. | `turn_end{side:owner}` → `random_enemy_minion` → `freeze` (row 23 op) | `control` | freeze | Alpha |
| `boss_pyre_sergeant` | The Pyre Sergeant | 2 | 40 | `power_brand` | Whenever the boss's hero attacks, deal 1 damage to the enemy hero. | `on_attack{attacker:owner_hero}` → `enemy_hero` → `damage 1` (row 5 shape) | `aggro` + `choice_preference:{weapon 0.6}` | weapons | Alpha |
| `boss_mirror_sage` | The Mirror Sage | 2 | 40 | — | Whenever the player plays a minion, the boss adds a copy of it to its hand. | `on_play{by:opponent}` → `trigger_subject` → `copy_to_hand side:owner` (row 32 op) | `tempo` | spells | Alpha |
| `boss_hollow_king` | The Hollow King | 3 | 50 | — | At the start of the boss's turn, give the boss's minions +1/+1. | `turn_start{side:owner}` → `all_friendly_minions` → `buff +1/+1` (row 15 op) | `control` + `w_board 3.0` | wall | MVP |
| `boss_lich_archivist` | The Lich Archivist | 3 | 50 | `power_drain` | The boss's spells deal 2 more damage. | `modify_damage{source:{side:friendly,type:spell}}` → `modify_value delta:2` (row 40) | `control` + `assume_aoe` | spells | VS |
| `boss_shadow_of_the_delve` | The Shadow of the Delve | 3 | 50 | — | The boss's minions have Stealth. | `aura` → `all_friendly_minions` → `aura keywords:[stealth]` (row 42) | `aggro` + `intent_mode: class_only` (reason: a Stealth boss naming its attacker reveals the hidden board) | stealth | Alpha |
| `boss_dungeon_heart` | The Dungeon Heart | 3 | 50 | `power_mend` | At the start of the boss's turn, deal 2 damage to all enemy minions. | `turn_start{side:owner}` → `all_enemy_minions` → `damage 2` (row 3 op) | `control` + `w_threat 3.5` | control | Alpha |

*B2 — puzzle, deck recipe and teaching.* A deck is 30 ids (duplicates allowed, no tokens, any
non-`boss` set plus the boss's own 2 cards, Card Database Edge Cases). Recipes name buckets; the
Config/Data story expands them to ids drawn only from the boss's batch or earlier (Edge Cases).

| id | Puzzle the player must answer (Pillar 2) | Deck recipe (30) | Teaching note (band 1) / design note |
|---|---|---|---|
| `boss_rat_king` | A free body every turn: trade efficiently or go face and race? | 2× each boss card (4) + 2× 13 MVP neutrals ≤ 5 cost (26) | Floor-1 teaching: Taunt stops attacks, small minions trade; `w_trade 0.2` makes it feed Rats into Taunts |
| `boss_gatekeeper` | Everything has Taunt: removal and board damage matter more than face damage. | 2× boss cards (4) + 2× wall/vanilla neutrals (lantern_bearer, cellar_guard, dungeon_delver, shield_golem, crypt_brute, ogre_porter, bulwark_smith, banner_captain, gravekeeper, hush_owl, torch_imp, tunnel_rat, smite_or_mend) (26) | Teaches the Taunt rule and that Silence/sweepers answer walls; War learns Cleave Through's purpose |
| `boss_cellar_hermit` | 3 heal a turn: a tempo clock — damage must outpace 1.5 health/turn. | 2× boss cards + 2× value/wall neutrals + 2× field_medic, blood_tick | Teaches the hero power exists and is used every turn (`hero_power: always`) |
| `boss_torchbearer` | 1 face damage a turn: the player's health is a resource, Armour and Lifesteal pay. | 2× boss cards (4) + 2× each of 13 MVP neutrals led by the tempo and pings cards (tunnel_rat, wolf_rider, banner_captain, spark_fiend, torch_imp, cellar_guard, lantern_bearer, bulwark_smith, dungeon_delver, hush_owl, gravekeeper, shield_golem, crypt_brute) (26); `ember_sprite` replaces two fillers in Alpha-B (Edge Cases) | Teaches the race; intent banner shows the damage counting down. Third MVP band-1 boss (D-06): with `band_split [2, 1, 1]` the MVP run draws 2 of 3, so the sequence varies |
| `boss_scrap_golem` | 5 Armour plus Reinforce: burst is wasted, sustained pressure wins. | 2× boss cards + 2× wall/big neutrals (gate_guardian, temple_guard, stone_sentinel, hill_giant …) | Teaches Armour as extra health |
| `boss_bog_witch` | Killing its minions draws it cards: pick the order of kills; Silence stops nothing here, tempo does. | 2× boss cards + 2× deathrattle neutrals/decay (ember_sprite, powder_keg, carrion_crow, grave_rat, rot_beetle …) | Introduces Deathrattle as a boss plan; first `passive_driven` boss |
| `boss_rot_warden` | Every death pings the player: sweepers hurt you, Silence and single big trades do not. | 2× boss cards + 2× decay deathrattle cards (grave_rat, carrion_crow, rot_beetle, shambling_heap, boneyard_brute …) + neutral filler; at MVP (no Decay set) the recipe is `boss_rot_zombie` ×3 + `boss_mass_rites` ×3 + 2× each of 12 MVP neutrals led by `neutral_gravekeeper` (the only MVP Deathrattle) and `neutral_shield_golem` (30); Decay cards replace neutrals in Alpha-A (Edge Cases) | Band-2 knowledge spike (run-structure F7 floor 4); the AI tunnels on Deathrattle (`w_passive`) |
| `boss_blood_abbess` | Heals 5 a turn: only burst or a weapon clock wins (Heroes H-6 Healer row). | 2× boss cards + 2× lifesteal/heal neutrals + wall bodies | War strong, Decay weak by design |
| `boss_iron_tollman` | Minions cost 1 more: spells, weapons and cheap drops are the answer. | 2× boss cards + tempo neutrals + rusty_dagger, miners_pick | Knowledge strong, War even; punishes greedy curves |
| `boss_frost_hag` | One freeze a turn: go wide, or win with spells and Rush. | 2× boss cards + knowledge freeze spells (frost_lance, glacial_wind) + wall neutrals | AI freezes the highest-attack target (op value table) |
| `boss_pyre_sergeant` | Weapon pressure plus a 2-damage power: Taunt walls and Armour or lose the race. | 2× boss cards + war weapons (rusted_axe, heavy_maul, duelists_edge) + war aggro minions | Uses hero-set cards in a boss deck (allowed) |
| `boss_mirror_sage` | Every minion you play, it gets a copy: play minions that are bad for it (sacrifice fodder) or spells. | 2× boss cards + tricks/value neutrals, few of its own minions | Decay and Knowledge strong, War even |
| `boss_hollow_king` | Its board grows +1/+1 a turn: kill minions the turn they land, never leave two. | 2× boss cards + 2× sticky bodies (shield_golem, temple_guard, stone_sentinel, shield_maiden, war_mammoth …) | Band-3 spike; MVP's hardest War puzzle (one weapon swing a turn) — Cleave Through and Charge are the outs |
| `boss_lich_archivist` | +2 spell damage and Drain: narrow boards die, wide boards die faster; weapons and Armour do not. | 2× boss cards + knowledge damage spells + control neutrals | `assume_aoe` makes it hold removal |
| `boss_shadow_of_the_delve` | Stealth everything: targeted removal is dead; random pings, sweepers and Taunt answer it. | 2× boss cards + stealth/tempo neutrals + cutpurse, ember_sprite | `class_only` intent (reason above) |
| `boss_dungeon_heart` | 2 damage to all your minions every turn: only 3+ health bodies, weapons and burn survive. | 2× boss cards + big/wall neutrals + lamplighter, hourglass_mage | Final-floor climax; `w_threat` high so it races when ahead |

*B3 — boss-only cards (`cards_boss.json`, set `boss`, 2 per boss; ids must not collide with
BossDef ids, Card Database CR-2).* Rarity is `common` for all (never shown to the player); batch =
the boss's batch.

| id | Boss | T | Cost | Stats | Text | Row |
|---|---|---|---|---|---|---|
| `boss_rat_pack` | rat_king | M | 2 | 1/1 | Battlecry: Summon two 1/1 Rats. | 9 |
| `boss_rat_matriarch` | rat_king | M | 4 | 3/3 | Your Rats have +1/+1. | 26 (`tag: rat`) |
| `boss_iron_gate` | gatekeeper | M | 3 | 1/6 | Taunt. | kw |
| `boss_gate_warden` | gatekeeper | M | 5 | 3/6 | Taunt. Battlecry: Give your other minions +0/+2. | 15 |
| `boss_moss_poultice` | cellar_hermit | S | 1 | — | Restore 4 Health to your hero. | heal |
| `boss_hermit_crab` | cellar_hermit | M | 3 | 2/5 | Deathrattle: Restore 3 Health to your hero. | 7 shape |
| `boss_ember_bolt` | torchbearer | S | 1 | — | Deal 1 damage to the enemy hero. Draw a card. | 7 + draw |
| `boss_tinder_imp` | torchbearer | M | 2 | 2/2 | At the end of your turn, deal 1 damage to the enemy hero. | 22 shape |
| `boss_scrap_plating` | scrap_golem | S | 2 | — | Gain 5 Armor. | armor |
| `boss_junk_golem` | scrap_golem | M | 4 | 3/5 | Battlecry: Gain 3 Armor. | armor |
| `boss_bog_toad` | bog_witch | M | 2 | 1/3 | Deathrattle: Draw a card. | 7 |
| `boss_witchs_brew` | bog_witch | S | 3 | — | Destroy a friendly minion. Draw 3 cards. | 10 |
| `boss_rot_zombie` | rot_warden | M | 3 | 2/3 | Deathrattle: Summon a 1/1 Husk. | 9 (`decay_husk`) |
| `boss_mass_rites` | rot_warden | S | 4 | — | Trigger the Deathrattles of all friendly minions. | 14 (`all_friendly_minions`) |
| `boss_blood_chalice` | blood_abbess | S | 2 | — | Restore 4 Health to your hero. Deal 2 damage to the enemy hero. | heal + damage |
| `boss_sister_of_blood` | blood_abbess | M | 4 | 3/4 | Lifesteal. | kw |
| `boss_toll_collector` | iron_tollman | M | 3 | 3/3 | Battlecry: Deal 2 damage to all enemy minions that cost (3) or more. | 3 (`cost_ge: 3`) |
| `boss_tollgate` | iron_tollman | M | 4 | 2/6 | Taunt. | kw |
| `boss_frostbite` | frost_hag | S | 3 | — | Destroy a Frozen minion. | destroy (`is_frozen`) |
| `boss_hag_servant` | frost_hag | M | 4 | 3/5 | Battlecry: Freeze an enemy minion. | 23 |
| `boss_signal_torch` | pyre_sergeant | W | 2 | 2/2 | Whenever your hero attacks, deal 1 damage to the enemy hero. | 5 shape |
| `boss_pyre_bomb` | pyre_sergeant | S | 3 | — | Deal 3 damage to the enemy hero. | 7 shape |
| `boss_reflection` | mirror_sage | S | 2 | — | Add a copy of a random enemy minion to your hand. | 32 (`random_enemy_minion`) |
| `boss_mirror_golem` | mirror_sage | M | 5 | 3/3 | Battlecry: Gain +1/+1 for each enemy minion. | 15 (`count all_enemy_minions`) |
| `boss_hollow_knight` | hollow_king | M | 4 | 3/4 | Divine Shield. | kw |
| `boss_crown_of_thorns` | hollow_king | S | 3 | — | Give your minions +1/+1 and Taunt. | 15 |
| `boss_bone_shard` | lich_archivist | S | 1 | — | Deal 1 damage to all enemy minions. | 19 |
| `boss_soul_bolt` | lich_archivist | S | 2 | — | Deal 2 damage. Restore 2 Health to your hero. | 18 + heal |
| `boss_lurker` | shadow_of_the_delve | M | 2 | 3/2 | Stealth. | kw |
| `boss_knife_in_the_dark` | shadow_of_the_delve | S | 3 | — | Deal 4 damage to a damaged minion. | 18 (`is_damaged`) |
| `boss_heartbeat` | dungeon_heart | S | 2 | — | Deal 1 damage to all enemy minions. Draw a card. | 19 + draw |
| `boss_heart_guardian` | dungeon_heart | M | 6 | 5/7 | Taunt. Deathrattle: Deal 2 damage to all enemy minions. | 7 + 3 |

**MVP bosses and their puzzles**: Rat King (band 1, swarm — trade or race), Gatekeeper (band 1,
wall — removal over face), Torchbearer (band 1, burn — race or armour up; the D-06 spare so two
MVP runs rarely share a sequence), Rot Warden (band 2, deathrattle — every death pings you), Hollow
King (band 3, snowball — kill on landing). Two band-1 War-weak matchups (swarm, wall — Heroes H-6)
and one War-even (burn) are deliberate: band 1's AI mistakes keep them at the 0.90 / 0.80 targets
while teaching the rule. DD-H06 still reads "4 bosses (2 band 1, 1 band 2, 1 band 3)"; the fifth
is the cross-review's addition and DD-H06 should be amended to match (design-decisions.md).

#### CN-4. Bundle plan

36 BundleDefs (`bundle_<set>_<theme>[_n]`, Card Database CR-2; 8 per hero + 12 neutral, DD-H05 as
raised on 2026-11-03): every card carries the bundle's
`theme` tag and is from the bundle's set (`E_TAG_MISMATCH` / `E_SET_MISMATCH` otherwise). **Band
suitability** is derived from the three cards' average cost (F2): early ≤ 2.5, mid 2.5–4.0, late
> 4.0 — Reward Draft reads it from the cards, it is not stored. Every signature card and ≥ 90 % of
non-starter collectible cards appear in at least one bundle (F5 coverage); the remainder are
reachable through Discover / `add_to_hand` only and are listed in Edge Cases.

| id | Name (`text.en` pitch) | Theme | Cards | Avg cost → band | Batch |
|---|---|---|---|---|---|
| `bundle_war_weapons_1` | Whetted Steel | weapons | war_sharpen, war_rusted_axe, war_blade_apprentice | 1.67 early | MVP |
| `bundle_war_weapons_2` | Armoury | weapons | war_blade_strike, war_heavy_maul, war_quartermaster | 2.33 early | MVP |
| `bundle_war_weapons_3` | Kingsguard | weapons | war_duelists_edge, war_twin_hatchets, war_kingsblade | 5.00 late | MVP |
| `bundle_war_aggro_1` | First Blood | aggro | war_cellar_raider, war_warcry, war_pit_brawler | 2.67 mid | MVP |
| `bundle_war_aggro_2` | The Pit | aggro | war_berserker, war_rally, war_pit_champion | 3.67 mid | MVP |
| `bundle_war_aggro_3` | Warband | aggro | war_warlord, war_headsman, war_cleave_through | 5.33 late | MVP |
| `bundle_war_armour_1` | Shield Wall | armour | war_shield_squire, war_iron_resolve, war_iron_vanguard | 2.00 early | MVP |
| `bundle_war_armour_2` | Bulwark | armour | war_armorer, war_shieldwall_veteran, war_shield_maiden | 3.33 mid | MVP |
| `bundle_decay_deathrattle_1` | Carrion | deathrattle | decay_grave_rat, decay_carrion_crow, decay_last_rites | 1.33 early | Alpha |
| `bundle_decay_deathrattle_2` | Grave Goods | deathrattle | decay_rot_beetle, decay_crypt_leech, decay_relic_keeper | 2.67 mid | Alpha |
| `bundle_decay_deathrattle_3` | The Boneyard | deathrattle | decay_boneyard_brute, decay_plaguebearer, decay_grave_titan | 6.00 late | Alpha |
| `bundle_decay_husk_1` | Husk Tide | husk | decay_mass_grave, decay_husk_tender, decay_raise_dead | 2.67 mid | Alpha |
| `bundle_decay_husk_2` | Mother's Brood | husk | decay_husk_herder, decay_shambling_heap, decay_husk_mother | 4.00 mid | Alpha |
| `bundle_decay_husk_3` | Rot Bloom | husk | decay_grave_rat, decay_feast_of_worms, decay_plague_of_rot | 2.67 mid | Alpha |
| `bundle_decay_sacrifice_1` | Tithe | sacrifice | decay_plague_rat, decay_soul_tithe, decay_culling | 1.33 early | Alpha |
| `bundle_decay_sacrifice_2` | Offering | sacrifice | decay_grave_robber, decay_tomb_spider, decay_blight | 3.33 mid | Alpha |
| `bundle_knowledge_spells_1` | Cantrips | spells | knowledge_spark, knowledge_frost_lance, knowledge_apprentice | 1.67 early | Alpha |
| `bundle_knowledge_spells_2` | Evocation | spells | knowledge_lightning_lash, knowledge_meteor_bolt, knowledge_glacial_wind | 3.33 mid | Alpha |
| `bundle_knowledge_spells_3` | Deep Vault | spells | knowledge_transmute, knowledge_rime_elemental, knowledge_vault_golem | 5.00 late | Alpha |
| `bundle_knowledge_draw_1` | Open Books | draw | knowledge_spark, knowledge_study, knowledge_scribe | 2.67 mid | Alpha |
| `bundle_knowledge_draw_2` | Long Reading | draw | knowledge_deep_study, knowledge_star_reader, knowledge_forbidden_tome | 5.33 late | Alpha |
| `bundle_knowledge_spell_damage_1` | Kindling | spell_damage | knowledge_candle_acolyte, knowledge_rune_warden, knowledge_lorekeeper | 2.67 mid | Alpha |
| `bundle_knowledge_spell_damage_2` | Conflagration | spell_damage | knowledge_chain_lightning, knowledge_flamewave, knowledge_grand_grimoire | 5.00 late | Alpha |
| `bundle_knowledge_discover_1` | Lost Library | discover | knowledge_lost_page, knowledge_archive_seeker, knowledge_scrying | 1.67 early | Alpha |
| `bundle_neutral_wall` | Hold the Line | wall | neutral_lantern_bearer, neutral_bulwark_smith, neutral_shield_golem | 2.67 mid | MVP |
| `bundle_neutral_tempo` | Quick March | tempo | neutral_tunnel_rat, neutral_wolf_rider, neutral_banner_captain | 2.33 early | MVP |
| `bundle_neutral_tricks` | Sleight of Hand | tricks | neutral_hush_owl, neutral_tunnel_shaman, neutral_hex_doctor | 2.67 mid | VS |
| `bundle_neutral_value` | Supply Line | value | neutral_novice_scout, neutral_treasure_map, neutral_mimic | 2.33 early | VS |
| `bundle_neutral_pings` | Sparks | pings | neutral_spark_fiend, neutral_rockfall, neutral_powder_keg | 2.67 mid | VS |
| `bundle_neutral_big` | Heavy Hitters | big | neutral_stone_sentinel, neutral_hill_giant, neutral_war_mammoth | 6.00 late | VS |
| `bundle_neutral_tempo_2` | Skirmishers | tempo | neutral_rusty_dagger, neutral_cutpurse, neutral_storm_harpy | 2.33 early | VS |
| `bundle_neutral_value_2` | Field Kit | value | neutral_field_medic, neutral_blood_tick, neutral_miners_pick | 2.67 mid | VS |
| `bundle_neutral_wall_2` | Stone and Lamp | wall | neutral_gate_guardian, neutral_temple_guard, neutral_old_lamplighter | 3.00 mid | Alpha-B |
| `bundle_neutral_tricks_2` | Hush and Hex | tricks | neutral_smite_or_mend, neutral_muzzle, neutral_hourglass_mage | 3.00 mid | Alpha-B |
| `bundle_neutral_pings_2` | Embers | pings | neutral_ember_sprite, neutral_gravekeeper, neutral_hedge_wizard | 2.33 early | Alpha-B |
| `bundle_neutral_big_2` | Siege Train | big | neutral_ogre_porter, neutral_great_cleaver, neutral_dungeon_warden | 6.00 late | Alpha-B |

Theme balance per hero (DD-H05; Reward Draft's pity rule wants ≥ 2 bundles per plan tag): War
3 / 3 / 2, Decay 3 / 3 / 2, Knowledge 3 / 2 / 2 / 1 — `discover` has one bundle, and its pity floor
is covered by the Discover cards inside the `spells` and `draw` bundles (Open Questions). Neutral:
two bundles per theme (wall, tempo, tricks, value, pings, big), so every neutral theme also meets
the ≥ 2 floor. Bundle slots: 108 for 95 non-starter collectible cards (56 hero-set + 39 neutral,
`neutral_lantern_bearer` now counted as non-starter). Hero sets are covered 52 / 56 (F5; the four
Discover-only cards are listed in Edge Cases). Neutral coverage: the 12 neutral bundles (36 slots,
`neutral_ogre_porter` is a starter and does not count) reach 34 of the 39 non-starter neutrals —
the remaining 5 (`neutral_charging_boar`, `neutral_pit_hound`, `neutral_relic_hunter`,
`neutral_battle_plan`, `neutral_the_collector`) are draftable only through Discover /
`add_to_hand` and are listed in Edge Cases. The `_2` bundles were drawn from existing neutral rows
to cover cards the first six missed; the second-batch bundles ship when their last card does
(VS for `tempo_2` / `value_2`, Alpha-B for the four that hold an Alpha neutral), per the Edge Cases
rule that a bundle never precedes its cards. (The earlier finding — 6 bundles reached 16 of 38 —
was resolved by raising DD-H05 to 12 neutral bundles on 2026-11-03; +1.2 h by F6.)

#### CN-5. Treasure plan (contract with the Treasures GDD)

Content does not define treasures; it consumes the Treasures GDD's 20 ids and tags (T8 is the
authority; the registry mirrors its `treasure_*` rows). Actual split: **10 universal, 4 War,
3 Decay, 3 Knowledge**; 11 Common / 9 Rare; 16 `unlock: null`, 4 unlockable. Content owns only
*which batch* each treasure ships in:

| Batch | Treasures (cumulative count) | Note |
|---|---|---|
| MVP-1 | `treasure_hollow_crown`, `treasure_worn_signet`, `treasure_vanguards_banner`, `treasure_bottomless_satchel`, `treasure_iron_constitution`, `treasure_thornhide_cloak`, `treasure_stampede_horn` (universal) · `treasure_whetstone_wheel`, `treasure_twin_grip` (War) · `treasure_scholars_candle` (Knowledge affinity, a draw hook any hero can hold) (10) | T8's MVP column; all `unlock: null`, so 10 ≥ `min_treasure_pool` 9 and `n_universal` 7 ≥ Reward Draft's 5 |
| VS | + `treasure_quartermasters_ledger`, `treasure_mending_charm` (universal) (12) | |
| Alpha-A | + `treasure_grave_tithe`, `treasure_rotting_bargain`, `treasure_plague_bell` (Decay) · `treasure_sprinters_boots` (War) (16) | Grave Tithe summons `decay_husk`; Plague Bell's `tag` filter on board minions is legal (card-effects C3, answered 2026-11-03) |
| Alpha-B | + `treasure_focusing_prism`, `treasure_dogeared_grimoire` (Knowledge) · `treasure_captured_standard` (War) · `treasure_living_armory` (universal) (20) | |

Treasure tags are two-part (affinity · plan). The plan half reuses this GDD's theme tags where a
hook is plan-shaped (`weapons`, `aggro`, `armour`, `husk`, `deathrattle`, `sacrifice`, `spells`,
`spell_damage`, `draw`, `value`, `tempo`) so Reward Draft can weight a treasure toward the plan in
the deck; Treasures adds tags no card carries (`universal`, `war` / `decay` / `knowledge`,
`economy`, `defensive`, `wild`). Any treasure whose hook needs a provisional op is Alpha+ (Edge
Cases); T8 records that all 20 are v1-expressible.

#### CN-6. Production pipeline

1. **Batch order** (each batch is one or more Config/Data stories; a batch closes when every row
   in the table below is true):

| Batch | Contents | Loads clean | `/balance-check` | `/content-audit` counts |
|---|---|---|---|---|
| MVP-0 (with the Card Database stories) | `war_whetstone_blade` token, the 7 shared neutrals of Heroes H-4 (6 starters + `neutral_lantern_bearer`), 7 War starters, `hero_powers.json` (`power_whetstone` only), `heroes.json` (`hero_war` only — DD-H06 is War-only at MVP, and a Decay or Knowledge HeroDef here would fail CR-5 step 6 with `E_UNKNOWN_REF` on starter cards that are Alpha records) | required | curve F2 on the starter (Heroes F1) | 14 cards |
| MVP-1 | remaining 18 War + 8 neutral, tokens `boss_rat` and `decay_husk` (the latter in a one-record `cards_decay.json`), 4 bosses + 8 boss cards, `ai_profiles.json` overrides, 10 bundles, the 10 CN-5 MVP treasures | required | F2, F3 (all 40), F4 (4 bosses via sim harness), F5 (MVP coverage) | 40 / 4 / 10 / 10 |
| VS | +20 neutral, +4 bosses (`cellar_hermit`, `blood_abbess`, `iron_tollman`, `lich_archivist`) + 8 boss cards + `power_mend`, `power_drain`, +4 neutral bundles, +2 treasures (CN-5) | required | F2–F5; sim win rate per floor 1–8 | 60 / 8 / 14 / 12 |
| Alpha-A | Decay 25 + tokens `decay_skeleton`, `decay_ghoul` (the full `cards_decay.json`), `hero_decay` + `power_rot`, 8 Decay bundles, bosses `torchbearer`, `bog_witch`, `frost_hag`, `shadow_of_the_delve` + 8 boss cards, 4 treasures (CN-5) | required | F2–F5; sim for War and Decay | 85 / 12 / 22 / 16 |
| Alpha-B | Knowledge 25 + tokens `knowledge_ward`, `neutral_sheep`, `hero_knowledge` + `power_insight`, `power_reinforce`, `power_brand`, 8 Knowledge bundles, +10 neutral, bosses `scrap_golem`, `pyre_sergeant`, `mirror_sage`, `dungeon_heart` + 8 boss cards, 4 treasures (CN-5) | required | full pass; sim for all three heroes; AC-18 pick rates | 120 / 16 / 30 / 20 |

2. **File layout** (DD-T01, Card Database CR-1): `assets/data/cards_war.json`, `cards_decay.json`,
   `cards_knowledge.json`, `cards_neutral.json`, `cards_boss.json`, `heroes.json`,
   `hero_powers.json`, `bosses.json`, `bundles.json`, `treasures.json` (Treasures GDD),
   `ai_profiles.json` (Boss AI), `heroes_balance.json` (Heroes F1–F5 constants) and this GDD's
   own `content_budgets.json` (F2–F6 constants; `[system]_[name]` rule). Envelope
   `{ "schema_version": 1, "records": [...] }`, snake_case keys, UTF-8.
3. **Validation**: every batch must load with **zero errors** through the headless validate
   command (Card Database CR-8 prints the report and exits non-zero); warnings are triaged —
   `W_DUP_NAME` and `W_FX_KEYWORD_MISMATCH` are fixed before close, `W_POOL_SIZE` is accepted
   only at MVP-0. The Content validator (`tools/content/validate.gd`, a story in MVP-1) adds
   `E_STARTER_CURVE`, `W_SET_SHARE` (Heroes), `W_CURVE`, `W_BUDGET`, `E_TEXT_LENGTH`,
   `E_COVERAGE` (this GDD, F2–F5). It emits observations, never verdicts.
4. **`/balance-check` cadence**: once per batch close and once per sprint during Alpha. Metrics:
   curve per set (F2), budget outliers (F3, listed, not auto-fixed), boss pressure by band (F4,
   from `production/qa/sim/<boss_id>_<date>.json`, Boss AI C11), sim win rate per floor against
   `target_win_rate_by_floor` ±10 pts, pick rate per bundle from archived run records (Run
   Structure R10) once `min_sample` is met.
5. **`/content-audit`**: planned counts are the CN-1 table; the audit reads
   `cards_by_set`, `bosses_in_band`, `bundle_pool` and `treasure_pool` and reports planned vs
   built per batch.
6. **Card text style guide** (`text.en`, ≤ 90 characters, `E_TEXT_LENGTH` above): keywords
   capitalised and first (`Taunt. Divine Shield.`), trigger words followed by a colon
   (`Battlecry:`, `Deathrattle:`), numbers as digits, mana in parentheses (`costs (1) less`),
   stats as `+1/+1`, `Deal N damage` / `Restore N Health` / `Draw N cards` / `Gain N Armor`,
   "your hero" and "the enemy hero" (owner-relative; boss cards use the same words and the UI
   renders them from the boss's side), "a minion" = any minion, "a friendly minion" / "an enemy
   minion" otherwise; Choose One options separated by "; or". American spelling in rules text
   (`Armor`), British in tags and prose is fine (`armour` tag). Localisation keys are derived:
   `card.<id>.name` / `card.<id>.text`, `boss.<id>.name` / `boss.<id>.intro`,
   `bundle.<id>.name` / `bundle.<id>.text`, `opt.<key>` for Choose One labels.
7. **Naming conventions**: ids per Card Database CR-2, ≤ 32-character display names, no two
   collectible cards share a name (`W_DUP_NAME`), boss names carry "The" in `name` only, tokens
   are named for what the card text calls them (Husk, Rat, Sheep, Ward).
8. **Art keys**: every record uses the default `art` key (`cards/<id>`, `bosses/<id>`); v1 ships a
   placeholder per rarity frame and per set colour (art bible §4) — no per-card art is authored
   in any batch (`/asset-audit` checks existence later).
9. **Ids are permanent**: once a story cites an id it is never renamed; a mistaken card is
   deprecated (`token: true` plus removal from every bundle and deck, Edge Cases).

### States and Transitions

Content has no runtime states; records are immutable once loaded (Card Database CR-7). The
lifecycle below is the authoring state of each record and batch, tracked in the story and the
batch's `/content-audit` output.

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| `Planned` | row exists in this GDD | a Config/Data story writes the record | counted by `/content-audit` as planned, not built |
| `Authored` | record present in its JSON file | headless load reports zero errors for the file | may still carry warnings; not yet in any batch close |
| `Validated` | zero errors, warnings triaged | `/balance-check` for its batch run | playable in dev builds; sim harness may use it |
| `Balanced` | `/balance-check` reports no outlier for the record, or an accepted deviation is noted in the story | batch closes | ships in the batch |
| `Shipped` | batch closed | a later `/balance-check` flags it, or a redesign | changes are value edits only; text and id stable |
| `Deprecated` | id must leave the pool | never (ids are permanent) | `token: true`, removed from bundles / decks / starters; kept so old run records resolve |

Batch transitions: `Open → Loads clean → Balanced → Closed`; a batch cannot close with a record
below `Balanced` unless the story records an accepted deviation; a later batch may not reference
an id from an unclosed batch (Edge Cases).

### Interactions with Other Systems

| System | Direction | Data in / out | Interface owner |
|---|---|---|---|
| **Card Database** | upstream (schema), downstream (data) | In: CR-2 ids, CR-3 record shapes, CR-5 load report and error codes, CR-6 queries used by the audit. Out: every file in CN-6 step 2, authored to CR-3; `report()` read by the validate command | Card Database owns shape and checks; Content owns values |
| **Card Effects** | upstream | In: C1 schema, C2 triggers, C5 op table, C11 archetype rows and the v2 list — the expressiveness fence every text in CN-2/CN-3 stays inside. Out: `effects[]` / `passive` arrays and the two redesigns as feedback | Card Effects owns the DSL |
| **Heroes** | upstream | In: starter lists (H-4), set composition and tags (H-5, F4), signature cards (F5), tokens. Out: the authored set files; the `war_quartermaster` / `war_cleave_through` text changes | Heroes is the brief; Content the files |
| **Boss AI** | upstream | In: archetype keys, band overlays, override schema (C10, F9), the sim harness output format (C11). Out: each boss's `ai_profile` and `boss_overrides` entry; `synergy_tags` | Boss AI owns key meanings |
| **Match Rules** | upstream | In: keyword list (DD-M09), `max_mana_crystals`, `turns_to_lethal` for F4. Out: nothing | Match Rules |
| **Run Structure** | upstream | In: `band_split`, `boss_starting_health_by_band`, F7 floor curve and `target_win_rate_by_floor` (F4 targets). Out: boss `theme` for `no_adjacent_shared_theme` once `BossDef.tags` exists | Run Structure |
| **Treasures** (concurrent) | sideways | In: 20 treasure ids + tags; which treasures need provisional ops. Out: theme tag vocabulary; batch in which each treasure ships (CN-5) | Treasures owns treasure semantics |
| **Reward Draft** (concurrent) | downstream | Out: bundle triples, theme tags, band suitability rule (CN-4), tag counts per hero for the pity rule. In: pick rates from run records for `/balance-check` | Reward Draft owns weighting |
| **Meta Progression** | downstream | Out: nothing at v1 (unlock keys are on treasures / heroes, not cards) | — |
| **Match UI / Run UI** | downstream | Out: names, text, art keys, intro lines via Card Database; the style guide guarantees text fits the card frame (UI Requirements) | UI renders |
| **RNG & Event Log** | none | Content is deterministic data; the sim harness it reads uses Boss AI's streams | — |

## Formulas

`systems-designer` / `economy-designer` not consulted — Lean mode. Values are designer defaults
taken from Hearthstone vanilla rates and the sibling GDDs' pacing model; `/balance-check` revisits
them per batch. Constants live in `assets/data/content_budgets.json`, read by the Content
validator and `/balance-check`, never by the rules engine.

### F1. Set composition (Heroes F4, extended to neutral and boss)

`share_type(set) = count(set, type) / |set|`, required within `SET_SHARE[set][type] ± SHARE_TOL`

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| count(set, type) | int | 0–45 | calculated (`cards_by_set` ∩ `cards_by_type`, tokens excluded) | Cards of that type in the set |
| SET_SHARE[set] (M / S / W) | float | war 0.52 / 0.24 / 0.24 · decay 0.68 / 0.32 / 0 · knowledge 0.44 / 0.56 / 0 · neutral 0.82 / 0.11 / 0.07 · boss 0.56 / 0.41 / 0.03 | data file (hero rows owned by Heroes `heroes_balance.json`; neutral and boss rows here) | Target shares |
| SHARE_TOL | float | 0.08 | data file | Tolerance (Heroes F4) |
| HERO_SET_SIZE / NEUTRAL_SET_SIZE | int | 25 ± 3 / 45 ± 5 | registry `hero_set_size`; data file | Set sizes |

**Output Range:** 0–1 per type; a miss is `W_SET_SHARE`. **Example:** Neutral 37 / 45 = 0.82 M,
5 / 45 = 0.11 S, 3 / 45 = 0.07 W → all on target. War 13 / 25 = 0.52 ✓.

### F2. Curve targets

`avg_cost(set) = Σ cost_i / |set|` and `bucket_share(set, k) = count_k / |set|`; required
`avg_cost ∈ [CURVE_AVG_MIN, CURVE_AVG_MAX]` and `bucket_share ∈ CURVE_BUCKET[k] ± BUCKET_TOL`.
Bundle band: `band(bundle) = early if avg(cost of 3) ≤ 2.5, mid if ≤ 4.0, else late`.

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| cost_i | int | 0–10 | data file (`cards_*.json`) | Base cost, tokens excluded |
| CURVE_AVG_MIN / MAX | float | 2.9 / 3.4 (collectible sets); starters use Heroes F1 2.4–2.8 | data file | Set average band |
| CURVE_BUCKET[k] | float | k≤1: 0.16 · 2: 0.22 · 3: 0.24 · 4: 0.18 · 5: 0.10 · ≥6: 0.10 | data file | Target share per cost bucket |
| BUCKET_TOL | float | 0.08 | data file | Tolerance per bucket |
| EARLY_MAX / MID_MAX | float | 2.5 / 4.0 | data file | Bundle band cut-offs |

**Output Range:** avg 2.9–3.4; a miss is `W_CURVE`. **Example:** Knowledge Σ = 83 / 25 = 3.32 ✓;
bucket 4: 6 / 25 = 0.24 vs 0.18 ± 0.08 ✓. `bundle_war_weapons_3`: (4 + 5 + 6) / 3 = 5.0 → late.
Rationale: drafted decks average 2.5 at floor 1 and ~3.2 by floor 8 (`deck_size_by_floor` grows
by late bundles), matching Run Structure F5's `k_f` growth.

### F3. Vanilla stat budget and taxes

`budget(cost) = 2 × cost + 1` points for minions; `budget_w(cost) = 2 × cost + floor(cost / 3)` for
weapons (attack × durability); `budget_s(cost) = 2 × cost` for spells.
`value(card) = stat_points + Σ keyword_tax + Σ effect_points`; required `|value − budget| ≤ BUDGET_TOL(rarity)`.

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| stat_points | int | 0–20 | calculated | minion: attack + health; weapon: attack × durability; spell: 0 |
| keyword_tax | float | taunt 1 · rush 1 · charge 2 · divine_shield 2 · windfury 2 · stealth 1 · lifesteal 1 · poisonous 2 · spell_damage 1.5 per +1 | data file | Points a keyword is worth |
| effect_points | float | damage 1.5 per targeted point, 1.0 per random point, 3.0 per point of enemy-board AoE (expected 3 bodies), 1.0 per AoE point that also hits own board · heal 0.5 · armor 0.5 · draw 2.5 per card · discover 2.0 · summon = token stat points · buff = points granted · freeze 1.5 · silence 2.0 · destroy 5.0 (restricted target 3.0) · transform 4.0 · mana 1.5 per crystal · conditional / repeat: value of the expected branch · deathrattle: × 0.8 (delayed) · self-cost (destroy own minion) −3 | data file | Conversion table; the designer's model, not the engine's |
| BUDGET_TOL | float | common 1.5 · rare 2.0 · legendary 3.0 | data file | Allowed deviation; legendaries may run +1 over budget on purpose |

**Output Range:** 0–25 points; outside tolerance is `W_BUDGET` (listed by `/balance-check`, never
auto-fixed). **Examples:** `war_shieldwall_veteran` 4: 3 + 4 + taunt 1 + armor 3 × 0.5 = 9.5 vs
budget 9 ✓. `war_kingsblade` 6 (legendary): 4 × 2 + AoE 2 × 3 = 14 vs `budget_w` 2 × 6 + 2 = 14 ✓. `decay_culling` 2:
draw 5 − self-cost 3 = 2 vs 4 → −2 (Culling is a starter the hero power compensates; recorded as
an accepted deviation, Edge Cases). `knowledge_meteor_bolt` 4: 6 × 1.5 = 9 vs 8 ✓. `neutral_war_mammoth`
7: 14 + 1 = 15 vs 15 ✓.

### F4. Boss deck pressure by band

`avg_points(boss) = Σ_{deck} value(card_i) / 30`
`boss_pressure(boss) = avg_points × (starting_hand_boss + T) / T + passive_points`
required `boss_pressure ∈ PRESSURE_BAND[band] ± PRESSURE_TOL` and `passive_points ≤ PASSIVE_CAP[band]`

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| value(card_i) | float | F3 | calculated | Points per deck card (boss-only cards included) |
| starting_hand_boss | int | 4 | registry constant (Match Rules) | Boss's opening hand |
| T | int | 6–12 | registry formula `turns_to_lethal` (model: 10 / 10 / 11 per band, Run Structure F7) | Turns per side the match is expected to last |
| passive_points | float | 0–6 | calculated with F3 rates per boss turn (heal 5 → 2.5; summon 1/1 → 2; +1/+1 to n minions → 2n with n = 2 expected; 2 AoE → 6) | Value the passive adds per turn |
| PRESSURE_BAND[band] | float | 1: 7.0 · 2: 9.0 · 3: 11.5 | data file | Target points per turn |
| PRESSURE_TOL | float | 1.0 | data file | Tolerance |
| PASSIVE_CAP[band] | float | 1: 2.0 · 2: 3.5 · 3: 6.0 | data file | Pillar 2 / Pillar 3 guard: the passive is the puzzle, not the whole fight |

**Output Range:** 5–14 points per turn. **Example:** Rat King — avg_points 5.4 (cheap neutrals),
T = 10: 5.4 × 1.4 = 7.56 + passive 2.0 (a 1/1 a turn) = 9.56 → above band 1's 7 ± 1 → the recipe
drops Rat Matriarch to ×1 and adds two Torch Imps, or band 1's `w_trade 0.2` is trusted and the
deviation is recorded after the sim. Blood Abbess: 6.0 × 1.4 = 8.4 + 2.5 = 10.9 vs 9 ± 1 → trim.
The model is a pre-sim sanity check; the sim harness win rate (F7 of Run Structure, AC-13) is the
measurement that decides.

### F5. Coverage check

`op_coverage = |{ op ∈ OPS_V1 : used_by(op) ≥ 1 }| / |OPS_V1|` with `OPS_V1` = C5 ops minus
provisional (`remove_keyword`, `shuffle_into_deck`, `discard`, `weapon_durability`,
`hero_power_refresh`) and minus value-only `modify_value` (counted against passives + treasures);
`kw_coverage = ∀ k ∈ DD-M09 : cards_with_keyword(k) ≥ KW_MIN`;
`bundle_coverage(set) = |non-starter cards of set in ≥ 1 bundle| / |non-starter cards of set|`.

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| used_by(op) | int | 0–120 | calculated from `effects[]` (recursively through `conditional` / `repeat` / `choose_one`) | Collectible cards (per batch: cards + that batch's bosses and treasures) using the op |
| KW_MIN | int | 2 | data file | Minimum cards per keyword |
| BUNDLE_COVERAGE_MIN | float | 0.90 (hero sets); neutral reported, no threshold at v1 (Open Questions) | data file | Share of non-starter cards reachable through a bundle |

**Output Range:** required `op_coverage = 1.0` at Alpha (`E_COVERAGE` otherwise; at MVP and VS the
unmet ops are listed as `W_COVERAGE`), `kw_coverage` true at Alpha, `bundle_coverage(hero set)
≥ 0.90`. **Example:** Alpha plan — 25 of 25 v1 ops used (C5 lists 30 op rows; the 5 provisional ones and `modify_value` are excluded, `add_counter` and `set_counter` count separately); Stealth 2 ✓; hero sets 52 / 56 = 0.93 ✓
(4 Discover-only cards, Edge Cases); neutral 16 / 38 = 0.42, reported (CN-4 finding).

### F6. Content volume vs time

`hours = n_cards × T_CARD + n_boss_cards × T_BOSS_CARD + n_bosses × T_BOSS + n_bundles × T_BUNDLE + n_batches × T_BALANCE`

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| T_CARD | float | 0.3–0.6 h (default 0.42) | data file | Author, validate, one sim glance per collectible card |
| T_BOSS_CARD | float | 0.2–0.4 h (0.33) | data file | Boss-only card |
| T_BOSS | float | 1.5–4 h (2.5) | data file | Passive, deck, override, 50-match sim, puzzle check |
| T_BUNDLE | float | 0.1–0.3 h (0.2) | data file | Triple, pitch text, tag check |
| T_BALANCE | float | 2–6 h (4) | data file | One `/balance-check` pass with fixes per batch |

**Output Range:** v1 ≈ 120 × 0.42 + 32 × 0.33 + 16 × 2.5 + 30 × 0.2 + 5 × 4 = 50.4 + 10.6 + 40 +
6 + 20 ≈ **127 h**; MVP (MVP-0 + MVP-1) ≈ 40 × 0.42 + 8 × 0.33 + 4 × 2.5 + 10 × 0.2 + 2 × 4 ≈
**40 h**. Against the concept's 4–7 months part-time, content is roughly a quarter of the budget,
which is why the index calls it the largest scope risk; the batch order front-loads what the MVP
hypothesis needs.

## Edge Cases

`systems-designer` not consulted — Lean mode.

**Expressiveness**
- **If a planned card needs a v2 op or selector** (card-effects C11 v2 list, or `E_FX_OP_UNAVAILABLE`
  at load): the card is redesigned within v1 in this GDD **or** moved to Alpha+ with the needed
  primitive named; it is never shipped with a code special case. Applied twice already:
  `war_quartermaster` (durability → conditional draw) and `war_cleave_through` (adjacent → sweep).
- **If a boss passive needs a v2 op**: same rule, and the boss keeps its band slot with a v1
  passive — a band may not fall below its DD-R02 count because of a passive.
- **If a treasure's hook needs a provisional op** (CN-5): the treasure ships in Alpha-B at the
  earliest and MVP's 10 must all be v1-expressible, or `min_treasure_pool` fails at MVP.
- **If the Insight hero power cannot bind the drawn card** (Heroes H-3 vs card-effects row 25, which
  writes Insight as "Deal 1 damage"): `hero_powers.json` carries whichever text Heroes and Card
  Effects agree on; Content does not decide it (Open Questions), and no Knowledge card in CN-2
  depends on the tax.

**References and ordering**
- **If a boss deck references hero-set cards** (`boss_pyre_sergeant` → War weapons,
  `boss_lich_archivist` → Knowledge spells): allowed with no warning (Card Database Edge Cases);
  the boss's batch must be the same as or later than the set file's batch, so `pyre_sergeant` and
  `lich_archivist` cannot move earlier than Alpha-B / VS respectively without a recipe change.
- **If a bundle references a card not yet authored**: `E_UNKNOWN_REF` at load, so a batch cannot
  close; bundles are therefore the **last** records written in a batch and reference only cards in
  the same or an earlier batch (CN-6 batch table is ordered that way).
- **If `bosses.json` lists a VS boss while `cards_boss.json` lacks its two cards**: `E_UNKNOWN_REF`;
  the boss and its cards ship in one story.
- **If a boss deck recipe cannot reach 30 ids from its batch** (e.g. Rot Warden at MVP without the
  Decay file): the recipe's fallback bucket (named in B2) fills with duplicates up to ×3 of a boss
  card; `/balance-check` F4 is re-run when the intended cards land.
- **If an id is renamed after a story cites it**: never — ids are permanent (CN-6 step 9); a wrong
  id is deprecated (`token: true`, pulled from every list) and a new id added, and the old id stays
  so archived run records and the event log resolve.

**Names, text and pools**
- **If two cards across sets share a `name`** (`W_DUP_NAME`): the later batch renames; MVP names
  win. Boss-only cards may share a name with nothing (they appear in the opponent's event feed).
- **If `text.en` exceeds 90 characters**: `E_TEXT_LENGTH` from the Content validator — the batch
  does not close; shorten per the style guide. **If a translation expands past the frame**: the
  localisation pass (`/localize`) may use a smaller type size down to 80 %, then abbreviates the
  numbers' nouns ("dmg" is not allowed; "Health" → "HP" is) — the 90-char English limit leaves
  ~30 % headroom for German-length strings.
- **If a token card appears in a pool, starter, bundle or boss deck**: `E_TOKEN_IN_LIST`; tokens
  reach play only through `summon` / `equip` / `transform` ops (Card Database CR-6).
- **If a hero-set collectible card is in no bundle** (F5): allowed up to the 10 % floor; at Alpha
  these are `war_throwing_axe`, `decay_corpse_collector`, `knowledge_ink_sprite`,
  `knowledge_glyph_wards` — reachable by Discover (`neutral_relic_hunter`, Knowledge Discover
  spells) or `decay_relic_keeper`. Neutral cards outside the 6 bundles (22 at Alpha) are the CN-4
  finding; until DD-H05 is revisited they are Discover-only and `/content-audit` reports them.
- **If two cards share a theme tag but no bundle pairs them**: fine — tags also feed Discover
  filters and Reward Draft's deck-theme count; a tag with fewer than 3 cards in a set is `W_TAG_THIN`
  (cannot form a bundle).
- **If a Discover pool filter matches fewer than 3 cards** (e.g. `knowledge_lost_page` at MVP, where
  no Knowledge file exists): Card Effects F4 offers fewer options; Content guarantees ≥ 3 matches
  for every authored filter at the card's own batch (`neutral_relic_hunter` → minions, trivially).

**Balance**
- **If a card's F3 value is outside tolerance**: `W_BUDGET` lists it; the story either changes a
  number or records an accepted deviation with a reason (`decay_culling`: starter sacrifice card,
  paid back by the Husk the power leaves).
- **If sim win rate on a floor is outside `target_win_rate_by_floor` ± 10 pts** (AC-13): the boss on
  that floor is tuned by deck recipe first, `boss_overrides` second, passive magnitude third;
  `BossDef.health` is changed only with a `W_BAND_HEALTH` accepted in the story (Pillar 2).
- **If a bundle's pick rate exceeds `PICK_RATE_MAX` or falls under `PICK_RATE_MIN`** (Tuning Knobs)
  once `min_sample` is met: the bundle's weakest or strongest card is swapped for a same-tag card
  of adjacent cost; the bundle id and theme never change.

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|---------------------|
| Card Database | This depends on Card Database (hard) | Record schemas, id rules, load report; every batch's "loads clean" gate. Card Database Interactions already lists Content as the author of every file |
| Card Effects | This depends on Card Effects (hard) | v1 DSL vocabulary and the v2 fence; `effects[]` / `passive` validation. Card Effects Dependencies lists Content (its C11 table was written from the planned pool) |
| Heroes | This depends on Heroes (hard) | Starter lists, set composition, tags, signature cards, tokens. Heroes Interactions lists Content as downstream |
| Boss AI | This depends on Boss AI (hard) | Profile keys, overrides, sim harness output for F4 / AC-13. Boss AI Dependencies lists Content (soft) |
| Treasures | This depends on Treasures (soft, concurrent) | 20 ids and tags; MVP needs 10 v1-expressible. Treasures GDD must list Content as a consumer of its ids and tags |
| Run Structure | This depends on Run Structure (soft) | `band_split`, boss health by band, floor curve and win-rate targets; `no_adjacent_shared_theme` consumes this GDD's boss themes once `BossDef.tags` exists. Run Structure lists Content as the owner of boss health and passives |
| Match Rules | This depends on Match Rules (soft) | Keyword list, mana cap, `turns_to_lethal` for F4; Match Rules' registry entries already list content.md |
| Reward Draft | Reward Draft depends on this (hard) | Bundle triples, theme tags, band suitability, tag counts per hero. Reward Draft's Dependencies must list Content |
| Match UI / Run UI | UI depends on this (soft) | Text that fits the frame (style guide), art keys, intro lines; no UI reads JSON directly |
| Meta Progression | none at v1 | Unlock keys live on treasures and heroes, not on content records |
| RNG & Event Log | none | Content draws no RNG and emits no events |

## Tuning Knobs

Every knob lives in `assets/data/content_budgets.json` unless its owner is named; knobs owned by
Heroes (`heroes_balance.json`) and Run Structure are referenced, not duplicated.

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `HERO_SET_SIZE` (Heroes) / `NEUTRAL_SET_SIZE` | 25 / 45 | 20–30 / 35–60 | More variety, more authoring hours (F6), thinner bundle coverage | Pool repeats within a run; Discover offers shrink |
| `BATCH_SIZE_CARDS` | 20–40 per batch (CN-6) | 15–60 | Fewer balance passes, later feedback | More passes (`T_BALANCE` × batches), earlier feedback |
| `CURVE_AVG_MIN` / `MAX` | 2.9 / 3.4 | 2.6–3.8 | Slower decks; floor-8 matches run long (Run Structure F5) | Faster, more aggro; band-3 puzzles lose teeth |
| `CURVE_BUCKET[k]`, `BUCKET_TOL` | F2 table / 0.08 | tol 0.04–0.15 | Looser shape per set | Sets forced to the same shape; identity flattens |
| `BUDGET_TOL` (C / R / L) | 1.5 / 2.0 / 3.0 | 1–4 | More outliers tolerated; power variance rises | Vanilla-only cards; Pillar 1 plan cards get cut |
| keyword / effect point table (F3) | per F3 | ±50 % per entry | A keyword valued higher is printed on fewer cards | Printed on more; interacts with `BUDGET_TOL` |
| `PRESSURE_BAND[band]`, `PRESSURE_TOL` | 7 / 9 / 11.5, ±1 | 5–14 | Harder bosses before sim; lowers win rates toward targets | Easier; `target_win_rate_by_floor` overshoots |
| `PASSIVE_CAP[band]` | 2 / 3.5 / 6 | 1–8 | Passives dominate (Pillar 2 ↑, Pillar 3 ↓ when they feel unfair) | Stat-wall bosses — the anti-pattern Pillar 2 names |
| `KW_MIN`, `BUNDLE_COVERAGE_MIN` | 2 / 0.90 | 1–4 / 0.7–1.0 | Forces more cards per keyword / more bundles | Dead keywords; Discover-only cards multiply |
| `TEXT_MAX_CHARS` | 90 | 70–110 | Richer text; frame overflow in translation | Terse cards; some archetypes unprintable |
| `PICK_RATE_MIN` / `MAX` | 0.15 / 0.55 (share of offers taken, per bundle, `min_sample` 30) | 0.05–0.25 / 0.4–0.7 | Tolerates dominant bundles (Reward Draft risk) | More churn in bundle composition |
| `EARLY_MAX` / `MID_MAX` | 2.5 / 4.0 | 2–3 / 3.5–5 | More bundles count as early; late offers rarer | Late bundles offered on floor 2 |
| `T_CARD`, `T_BOSS`, `T_BUNDLE`, `T_BALANCE` | 0.42 / 2.5 / 0.2 / 4 h | per F6 | Planning only — `/estimate` reads them | — |
| Boss deck size | 30 | 20–40 | Boss fatigues later; recipes need more ids | Fatigue in long band-3 matches (Match Rules C11) |
| Boss-only cards per boss | 2 | 1–4 | Stronger boss identity; +`T_BOSS_CARD` each | Bosses feel like neutral piles |

## Visual/Audio Requirements

`art-director` not consulted — Lean mode; Content's visual surface is the per-record `art` key
only, so a brief note suffices.

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Any card rendered (v1) | Placeholder frame per rarity (C / R / L border) tinted by set colour (art bible §4: War red-bronze, Decay green-violet, Knowledge blue-gold, Neutral parchment, Boss desaturated band colour); `art` key `cards/<id>` resolves to the placeholder until `/asset-spec` | — | MVP |
| Boss intro | Placeholder portrait `bosses/<id>` in the band's desaturated colour; `intro_text` one line (style: a threat that names the passive, ≤ 120 chars) | Band stinger (Match UI owns) | MVP |
| Bundle offered | Three card frames plus the `text.en` pitch; theme tag shown as a label (Run UI) | — | MVP |

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run
`/asset-spec system:content` to produce per-asset visual descriptions, dimensions, and generation
prompts from this section (card frames per rarity and set, 16 boss portraits, 7 token frames).

## Game Feel

Not applicable — Content is authored data with no input, animation or impact of its own. The feel
of playing a card belongs to Match Rules / Match UI; what Content owes feel is **legible text**
(style guide, CN-6 step 6) so that a card reads in under two seconds, and **budgets** (F3) so that
no card feels like a mistake to draft. Feel acceptance: a playtester reads any card text once and
can say what it does (AC-9).

## UI Requirements

Content has no screens; it constrains the ones that show it.

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|-----------------|-----------|
| Card text ≤ 90 chars, name ≤ 32 | Card frame text box (Match UI, Run UI draft picker) | static | Every collectible, token and boss card |
| Boss name, passive text, intro line | Boss intro screen (Run UI) | per floor | `BossDef.passive` text comes from `boss.<id>.passive` key, derived like card text (Open Questions: not in CR-3 today) |
| Bundle pitch (`text.en`, ≤ 60 chars) and theme label | Draft picker (Run UI) | per draft | Every bundle |
| Validation report | Data-error screen (Run UI) / stdout (headless) | at load | `Failed` load (Card Database CR-8) |

📌 **UX Flag — Content**: no dedicated screen; `/ux-design draft-picker` and `/ux-design boss-intro`
(Run UI) must honour the text-length limits above.

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|-----------|----------------------------|--------|
| Record shapes, id prefixes, `token`, `tags`, `text.key` | `design/gdd/card-database.md` | CR-2, CR-3, CR-6 | Rule dependency |
| "Every batch loads with zero errors"; error codes | `design/gdd/card-database.md` | CR-5 pipeline, CR-8, Edge Cases (`W_DUP_NAME`, `E_TOKEN_IN_LIST`, boss decks may use hero sets) | Rule dependency |
| Pool sizes the audit checks | `design/gdd/card-database.md` | `collectible_pool_size`, `bundle_pool_size`, `min_treasure_pool` | Data dependency |
| Every card text's DSL shape; the redesign rule | `design/gdd/card-effects.md` | C1 schema, C2 triggers, C5 op table (incl. provisional rows), C11 archetype rows 1–43 and v2 list | Rule dependency |
| Passive and hero-power hosting | `design/gdd/card-effects.md` | C9 treasure hooks and boss passives; `modify_value` value triggers | Rule dependency |
| Starter decks, tokens, set composition, tags, signatures | `design/gdd/heroes.md` | H-3 (tokens), H-4, H-5, F1, F4, F5 | Data dependency |
| Hero matchup intent for the boss mix | `design/gdd/heroes.md` | H-6 | Rule dependency |
| Profile archetypes, band overlays, overrides, intent modes, sim harness | `design/gdd/boss-ai.md` | C8.4, C10, C11, F9 | Rule dependency |
| Boss health by band; floors per band; floor curve; win-rate targets | `design/gdd/run-structure.md` | F2 (`no_adjacent_shared_theme`), F3, F6 (`min_sample`), F7 | Data dependency |
| Keyword list; mana cap; turns to lethal; boss starting hand | `design/gdd/match-rules.md` | DD-M09 keyword ids, `max_mana_crystals`, `turns_to_lethal`, `starting_hand_boss` | Data dependency |
| Treasure ids, tags, batch split | `design/gdd/treasures.md` (concurrent) | treasure pool of 20, `tags[]` | Data dependency |
| Bundle triples and theme tags consumed by weighting | `design/gdd/reward-draft.md` (concurrent) | theme weighting, pity rule, band bending | Ownership handoff |
| Counts and batches | `design/design-decisions.md` | DD-H03, DD-H05, DD-H06, DD-R02, DD-M09, DD-T01 | Data dependency |

## Acceptance Criteria

`qa-lead` not consulted — Lean mode. Evidence type per criterion: **Data** = headless validate
command output retained in `production/qa/`; **Sim** = `production/qa/sim/*.json` from the Boss AI
harness; **Audit** = `/content-audit` or `/balance-check` report; **Play** = playtest note.

- [ ] **AC-1 (Data)** GIVEN the files of any closed batch, WHEN the headless validate command runs, THEN it exits 0 with zero `error` entries and only triaged warnings (none of `W_DUP_NAME`, `W_FX_KEYWORD_MISMATCH`, `E_TEXT_LENGTH`).
- [ ] **AC-2 (Audit)** GIVEN the MVP-1 batch closed, WHEN `/content-audit` runs, THEN it reports 40 collectible cards (war 25, neutral 15), 4 bosses (2 / 1 / 1), 8 boss-only cards, 10 bundles (8 war, 2 neutral) and 10 treasures.
- [ ] **AC-3 (Audit)** GIVEN the Alpha-B batch closed, WHEN `/content-audit` runs, THEN it reports 120 collectible cards (25 / 25 / 25 / 45), 7 tokens, 32 boss cards, 16 bosses (6 / 6 / 4), 30 bundles and 20 treasures, and the counts equal CN-1.
- [ ] **AC-4 (Data)** GIVEN any closed batch, WHEN F1 is evaluated per set present, THEN every type share is within `SET_SHARE ± 0.08`, or the story records the `W_SET_SHARE` deviation.
- [ ] **AC-5 (Data)** GIVEN the Alpha pool, WHEN F2 is evaluated per set, THEN each set's average cost is within 2.9–3.4 and no cost bucket misses its target by more than 0.08; GIVEN any starter deck, THEN Heroes F1 passes (`E_STARTER_CURVE` never fires).
- [ ] **AC-6 (Audit)** GIVEN any closed batch, WHEN `/balance-check` evaluates F3, THEN every card outside `BUDGET_TOL` is listed in the report and each listed card has an accepted-deviation note in its story; no silent outliers.
- [ ] **AC-7 (Data)** GIVEN the Alpha pool, WHEN F5 runs, THEN every non-provisional v1 op (`modify_value` via passives) is used by at least one record and every DD-M09 keyword appears on at least two collectible cards; GIVEN the MVP pool, THEN the unmet ops are exactly those listed as `W_COVERAGE` in the MVP-1 story.
- [ ] **AC-8 (Data)** GIVEN the Alpha pool, WHEN hero-set bundle coverage is computed, THEN ≥ 90 % of non-starter hero-set cards are in ≥ 1 bundle and the exceptions equal the four named in Edge Cases; neutral coverage is reported with its value.
- [ ] **AC-9 (Data + Play)** GIVEN every `text.en`, WHEN measured, THEN none exceeds 90 characters and every one follows the style guide (keyword capitalisation, digits, `(N)` for mana); GIVEN a first-time playtester shown 10 random cards, THEN they state each card's effect correctly after one reading for ≥ 9 of 10.
- [ ] **AC-10 (Data)** GIVEN `bosses.json`, WHEN loaded, THEN every boss has a non-null `passive` or `hero_power`, `health` equals its band default (no `W_BAND_HEALTH` at v1), its `ai_profile` resolves (no `E_AI_*`), and its deck has exactly 30 non-token ids from its batch or earlier.
- [ ] **AC-11 (Data)** GIVEN every boss passive and boss-only card, WHEN validated by the Card Effects validator, THEN zero `E_FX_OP_UNAVAILABLE` and zero `E_FX_*` errors — nothing in CN-3 relies on a v2 op.
- [ ] **AC-12 (Sim)** GIVEN each boss and the `default`-profile hero script for every hero whose set is in the batch, WHEN the harness runs ≥ 50 seeded matches per pairing, THEN rejected AI commands = 0 and F4 `boss_pressure` is within its band ± 1.0, or the deviation is recorded.
- [ ] **AC-13 (Sim)** GIVEN a closed VS or Alpha batch, WHEN the harness simulates full runs (hero script drafting the highest-theme-match bundle), THEN the per-floor win rate is within ±10 points of `target_win_rate_by_floor` for every floor with ≥ `min_sample` matches; floors below the sample are reported `NOT ASSESSED`, never passed.
- [ ] **AC-14 (Data)** GIVEN `bundles.json`, WHEN loaded, THEN every bundle's three cards share its set and carry its theme tag, every signature card appears in ≥ 1 bundle, and every hero plan tag except `discover` has ≥ 2 bundles.
- [ ] **AC-15 (Data)** GIVEN a bundle's three cards, WHEN the band is derived by F2, THEN each hero has ≥ 2 early, ≥ 3 mid and ≥ 1 late bundle at Alpha (War: 3 / 3 / 2 as planned).
- [ ] **AC-16 (Data)** GIVEN any token card, WHEN pools, starters, bundles and boss decks are scanned, THEN it appears in none of them and is referenced by at least one `summon` / `equip` / `transform` op.
- [ ] **AC-17 (Data)** GIVEN a record deprecated after a story cited its id, WHEN the pool is loaded, THEN the id still resolves (`token: true`), appears in no list, and archived run records that name it still replay.
- [ ] **AC-18 (Audit)** GIVEN ≥ `min_sample` archived runs after Alpha, WHEN pick rates per bundle are computed, THEN no bundle is outside `PICK_RATE_MIN`–`PICK_RATE_MAX`, or a composition change is scheduled in the next batch's story.
- [ ] **AC-19 (Play)** GIVEN each of the 4 MVP bosses, WHEN a tester reads the intro passive and plays once, THEN they can name the puzzle (CN-3 B2 column) in one sentence after the match — the loss teaches (Pillar 3).
- [ ] **AC-20 (Data)** GIVEN the MVP-0 batch, WHEN loaded, THEN the Card Database reaches `Ready` within `data_load_budget_ms` (200 ms) and the War starter deck validates (15 ids, `war` or `neutral`, no tokens); GIVEN Alpha-A / Alpha-B closed, THEN the Decay / Knowledge starter decks validate the same way.
- [ ] **AC-21 (Data)** GIVEN the shipped code, WHEN it is searched for the F1–F6 constants (`CURVE_*`, `BUDGET_TOL`, `PRESSURE_*`, `PASSIVE_CAP`, `KW_MIN`, `BUNDLE_COVERAGE_MIN`, `TEXT_MAX_CHARS`, `PICK_RATE_*`), THEN none appears as a literal outside `content_budgets.json` / `heroes_balance.json`: the validator and `/balance-check` read them from those files.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| DD-H05 revisit: 6 neutral bundles reach 16 of 38 non-starter neutrals (CN-4 finding). Raise to 12 neutral bundles (36 total) or accept Discover-only neutrals? | Owner + Reward Draft | before VS batch (first neutral bundle story after MVP) | Open — plan holds 30 |
| `BossDef.tags[]` (for `no_adjacent_shared_theme`) and `BossDef.passive_text` / `boss.<id>.passive` key are not in Card Database CR-3; add both or keep the theme in this GDD only | Card Database GDD | MVP-1 boss story | Open — Run Structure Open Questions already asks for `tags[]` |
| `war_quartermaster` and `war_cleave_through` text changed here; Heroes H-4 / H-5 must be updated via `/propagate-design-change` | Heroes GDD | before MVP-0 | Open — ids unchanged |
| Insight hero power: Heroes H-3 ("Draw a card. It costs (1) more this turn") vs card-effects C11 row 25 ("Deal 1 damage"); the DSL has no draw-binding. Which text ships in `hero_powers.json`? | Heroes + Card Effects | Alpha-B (Knowledge batch) | Open — Content authors whichever is agreed; fallback per Heroes is "Draw a card. Your hero takes 2 damage." |
| `war_pit_champion` grants Windfury to the hero via `buff keywords` with `until_end_of_turn`: confirm Match Rules' `can_attack` reads Windfury on a hero (not only on a weapon, DD-M08) | Match Rules | MVP-1 | Open — if not, text becomes "Your weapon has Windfury this turn" |
| Knowledge's `discover` tag has one bundle; does Reward Draft's pity rule need ≥ 2 per tag, or is the Discover-in-other-bundles cover enough? | Reward Draft | Alpha-B | Open |
| Boss hero powers in `hero_powers.json` (`power_mend`, `power_brand`, `power_drain`, `power_reinforce`) — Heroes owns the file; confirm Content may add boss rows | Heroes | MVP-1 | Open — Card Database CR-1 says the file is shared |
| `T_*` estimates (F6) are unmeasured; recalibrate after MVP-1 closes | Producer / `/estimate` | MVP-1 close | Open |
| Intro lines (`intro_text`, ≤ 120 chars) for 16 bosses: authored in the boss story or by a `writer` pass? | Owner | VS | Open — boss stories carry a placeholder line naming the passive |
| Card-effects R-3 (raised by Treasures): does the `tag` filter apply to **board minions**? C3 lists `tag` for cards and pools only, yet `boss_rat_matriarch` (MVP), `decay_husk_herder` and `decay_plague_of_rot` filter the board by `tag` | Card Effects | MVP-1 boss story | Open — if not by MVP-1, `boss_rat_matriarch` ships as "Your other minions have +1/+1" (row 26) and the Decay pair wait for the answer |
| Card-effects R-10 (raised by Treasures): event triggers with no hook column (`on_minion_died`, `on_play`, `on_attack`) on a **passive** host — `boss_rot_warden` (MVP), `boss_bog_witch`, `boss_pyre_sergeant`, `boss_mirror_sage` rely on the Treasures T2.5 hero-slot-observer reading of C2/C6.2 | Card Effects | MVP-1 boss story | Open — Rot Warden's fallback is a `turn_end` passive "deal 1 damage to the enemy hero for each boss minion that died this turn" (`ref owner.minions_died_this_turn`), same puzzle, one step later |
| `neutral_gravekeeper` reads `counter.deaths` inside its own Deathrattle; C5 says counters die with the source — confirm the deathrattle step (raise-time snapshot, C6.5) still reads them | Card Effects | MVP-1 | Open — fallback text "…per minion that died this turn" |
| AC-13 compares the hero-script win rate to `target_win_rate_by_floor` (median-player targets); Boss AI's Open Questions propose script-relative band targets (boss wins 20–30 / 40–50 / 55–65 %). One basis must be picked before the first VS sim | Boss AI + `/balance-check` | VS close | Open — AC-13 reads the player targets until then |
