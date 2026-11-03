# Heroes

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
> **Author**: Jacob (owner) + `/design-system` (guided, lean)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 1 (every run builds a deck you couldn't have planned — the hero is the seed of that deck); Pillar 4 (hero powers are DSL effects, logged like any spell)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` No engine reference for the `Scripting` domain under `docs/engine-reference/godot/modules/`; feasibility not checked against the pinned engine (rule-only system, no engine surface). No `Agent` tool in this session: `systems-designer` (Formulas) and `qa-lead` (Acceptance Criteria) not consulted — Lean mode would have spawned both; review those two sections manually before production.

## Summary

Heroes defines the three playable characters the player picks a run with — War, Decay and
Knowledge — as pure data: 30 health, a 2-mana once-per-turn hero power written in the Card
Effects DSL (Whetstone, Rot, Insight), a fixed 15-card starter deck and a ~25-card set the draft
can offer. It exists so each run starts from a different stance against the same bosses, and so
the starter suggests a plan without completing it (Pillar 1). Fortune, Order and Shadow are
sketched as post-v1 unlock heroes, data only.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Card Database, Card Effects`

## Overview

A hero is the player's starting position in a run: a name and a colour, 30 health, a 2-mana
once-per-turn **hero power**, a fixed **15-card starter deck**, and a **card set** of ~25 cards
that the Reward Draft can offer alongside the neutral pool. The player picks one hero on the
hero-select screen and keeps it for the whole run; there is no deck construction (anti-pillar:
not a constructed deck builder). Mechanically a hero is pure data — a `HeroDef` record in
`heroes.json` pointing at a `HeroPowerDef` in `hero_powers.json` whose effect is written in the
Card Effects DSL, exactly like a spell (DD-M13). The system exists so that three runs with three
heroes ask three different questions of the same bosses: War races with weapons, Decay grinds
through Deathrattles and sacrificial Husks, Knowledge out-draws and out-casts. Three launch heroes
(War, Decay, Knowledge — DD-H01) are unlocked by default; three unlock heroes (Fortune, Order,
Shadow — DD-H02) are defined here as identity sketches and ship as data only, after v1. Without
this system every run would start from the same deck and the draft (Pillar 1) would have nothing
to lean against.

## Player Fantasy

Direct engagement: the player chooses the hero and presses its power every turn. The fantasy is
**a known self walking into an unknown dungeon**. The hero is the one thing the player brings; the
draft supplies everything else. Each hero should feel like a stance rather than a class:

- **War — the whetted edge.** "I am the clock." Every turn the hero itself hits something; the
  board is a means to keep the weapon swinging. Reference: Hearthstone Warrior/Rogue weapon turns —
  the small, certain pleasure of a hero attack that is always available.
- **Decay — the gardener of rot.** "Everything I lose feeds me." Deaths on either side of the board
  are harvests; the player wants their own minions to die at the right moment. Reference: Dungeon
  Run's Deathrattle Hunter bundles and Slay the Spire's Necronomicurse-free Exhaust decks — grief
  as resource.
- **Knowledge — the illuminated page.** "I have seen more of my deck than you have of yours."
  Spells chain, cards flow, a Spell Damage minion turns a 2-damage bolt into a 4. Reference:
  Hearthstone Mage spell turns and the lapis-and-gilt manuscript look (art bible §4).

Pillar fit: Pillar 1 ("the draft is the game") means the starter must *suggest* a plan, not
complete it — about a third of each starter is plan-shaped (F2), the rest vanilla so bundles change
what the deck is. Pillar 4: each power's result is one legible log line ("Rot killed Tunnel Rat;
Husk summoned").

`creative-director` not consulted — Lean mode. Review manually before production.

## Detailed Design

### Core Rules

Specialist note: `game-designer` / `systems-designer` / `art-director` / `narrative-director` not
spawned — Lean mode (no Agent tool in this session). Review manually before production.

**H-1 — A hero is a `HeroDef`.** Fields and validation are owned by Card Database CR-3: `id`
(`hero_<name>`), `name`, `set`, `health` (30 for every launch hero — `player_starting_health`,
DD-M02), `hero_power` (a `HeroPowerDef` id), `starter_deck` (exactly 15 ids, `starter_deck_size`,
DD-R03; own set or `neutral`; duplicates allowed; no tokens), `text` (identity line), `art`. This
GDD owns *which* values go in those fields; Match Rules C3 reads `health`, `hero_power` and the
deck list through `MatchConfig`. Nothing about a hero is hardcoded: adding a hero is a data change
plus a card set file.

**H-2 — Launch heroes (DD-H01).** All three are `unlock: null` (available from the first launch;
the first run forces War per the concept's onboarding note — Run Structure owns that rule).

| Hero id | Name | Identity line (`text.en`) | Set | Health | Hero power | Colour (art bible §4) |
|---|---|---|---|---|---|---|
| `hero_war` | Halvard, the Whetted | "Every turn, the blade. The rest is footwork." | `war` | 30 | `power_whetstone` | red-bronze `#9B2F23` / `#B07A3A` |
| `hero_decay` | Mother Wythe | "Nothing in my garden is wasted — least of all the dead." | `decay` | 30 | `power_rot` | green-violet `#355E3B` / `#6B4C8A` |
| `hero_knowledge` | Archivist Ilse | "I have read the ending. I am only checking the page." | `knowledge` | 30 | `power_insight` | blue-gold `#2C4F8A` / `#C9A24A` |

**H-3 — Hero power rules.** The rule is Match Rules C7 and is not restated: cost
`hero_power_cost` (2) through F1 (floor 0), once per turn (`used_this_turn`, reset in the Start
step), targeting as for spells (a `required` power with no legal target is unusable), resolved at
trigger point `hero_power`, one `hero_power_used` event. This GDD owns the **content** of the three
powers. Each is prose (binding) plus a provisional DSL sketch — **to be validated against
`card-effects.md`**; where the DSL differs, the prose wins and the sketch is corrected.

*War — Whetstone (`power_whetstone`, 2).* "Equip a 1/2 Whetstone Blade. If you already have a
weapon, give it +1 Attack this turn instead." Rejected alternatives: a plain "equip a 1/2" would
destroy a drafted weapon (C6 step 2) and so punish the hero's own plan; a plain "+1 Attack" is dead
on an empty slot for the first two turns. The conditional costs one `branch` op and buys a power
that is always useful and never anti-synergistic. The +1 is an enchantment on the weapon with
`expires: end_of_turn` (C1 Weapon has `enchantments[]`; C4 End step 5 removes it).

```json
{ "id": "power_whetstone", "name": "Whetstone", "cost": 2,
  "effects": [ { "trigger": "hero_power", "targeting": { "mode": "none" },
    "ops": [ { "op": "branch", "if": { "has_weapon": "self" },
      "then": [ { "op": "enchant", "target": "self_weapon", "attack_delta": 1, "expires": "end_of_turn" } ],
      "else": [ { "op": "equip_weapon", "side": "self", "def_id": "war_whetstone_blade" } ] } ] } ] }
```

Token: `war_whetstone_blade` — weapon, cost 1, 1 Attack / 2 Durability, `token: true`, set `war`.

*Decay — Rot (`power_rot`, 2).* "Deal 1 damage to a minion. If it dies, summon a 1/1 Husk."
Targets **any** minion, friendly included: rotting your own 1-health Deathrattle minion both
fires the rattle and leaves a Husk, which is the sacrifice fantasy in one click. Rejected: "summon
a Husk" (no decision), "destroy a friendly minion" (unusable on an empty board for the first turns
and never removal). The two ops are sequential steps, so the C10 death check runs between them
and the condition reads whether the target left play.

```json
{ "id": "power_rot", "name": "Rot", "cost": 2,
  "effects": [ { "trigger": "hero_power", "targeting": { "mode": "required", "filter": "any_minion" },
    "ops": [ { "op": "damage", "target": "chosen", "amount": 1 },
      { "op": "summon", "side": "self", "def_id": "decay_husk", "position": "rightmost",
        "if": { "left_play": "chosen" } } ] } ] }
```

Token: `decay_husk` — minion, cost 1, 1/1, no text, `token: true`, set `decay`, tag `husk`.

*Knowledge — Insight (`power_insight`, 2).* "Draw a card. It costs (1) more this turn." Chosen
over Spark ("deal 1 damage"): Spark would make two of three heroes pingers (concept risk "heroes
feel samey") and says nothing about Pillar 1, whereas Insight makes every drafted card arrive
sooner — the power is literally "see more of the deck you built". The tax is a sequencing test,
not a penalty: used after spending mana it is free, used first to dig for an answer it costs one.
The 15-card starter makes early overuse self-limiting through fatigue (C11), which no other
cost achieves as legibly. If the DSL cannot bind the drawn card (Open Questions), the fallback is
"Draw a card. Your hero takes 2 damage."

```json
{ "id": "power_insight", "name": "Insight", "cost": 2,
  "effects": [ { "trigger": "hero_power", "targeting": { "mode": "none" },
    "ops": [ { "op": "draw", "side": "self", "n": 1, "bind": "drawn" },
      { "op": "enchant_card", "target": "$drawn", "cost_delta": 1, "expires": "end_of_turn",
        "if": { "in_hand": "$drawn" } } ] } ] }
```

**H-4 — Starter decks (15 each, DD-R03).** Concept-level list — the first Content batch,
authored in `cards_<set>.json` / `cards_neutral.json` against Card Database CR-3. Every starter
has the same shape (four 1-drops, four 2s, four 3s, two 4s, one 5 — F1) so early turns feel the
same speed and the *difference* is the plan cards (★, tag in brackets). Neutrals are shared (MVP
budget: 7 neutrals + 8 War cards covers War's starter).

Shared neutral cards: `neutral_torch_imp` 1 — 1/2 · `neutral_tunnel_rat` 1 — 2/1 ·
`neutral_cellar_guard` 2 — 2/3 · `neutral_lantern_bearer` 2 — 2/2 Taunt ·
`neutral_dungeon_delver` 3 — 3/4 · `neutral_crypt_brute` 4 — 4/5 · `neutral_ogre_porter` 5 — 5/6.

| Cost | War (`hero_war`) | Decay (`hero_decay`) | Knowledge (`hero_knowledge`) |
|---|---|---|---|
| 1 | `neutral_tunnel_rat` ×2 · ★`war_shield_squire` 1/2, Battlecry: Gain 2 Armour [armour] · ★`war_sharpen` spell: Give your weapon +2 Attack this turn [weapons] | `neutral_torch_imp` ×2 · `neutral_tunnel_rat` · ★`decay_grave_rat` 1/1, Deathrattle: Summon a 1/1 Husk [deathrattle] | `neutral_torch_imp` ×2 · `neutral_tunnel_rat` · ★`knowledge_candle_acolyte` 1/2, Spell Damage +1 [spell_damage] |
| 2 | `neutral_cellar_guard` ×2 · ★`war_rusted_axe` weapon 2/2 [weapons] · ★`war_warcry` spell: Give your minions +1 Attack this turn [aggro] | `neutral_cellar_guard` ×2 · ★`decay_carrion_crow` 2/1, Deathrattle: Draw a card [deathrattle] · ★`decay_culling` spell: Destroy a friendly minion. Draw 2 cards [sacrifice] | `neutral_cellar_guard` ×2 · ★`knowledge_frost_lance` spell: Deal 2 damage to a minion and Freeze it [spells] · ★`knowledge_archive_seeker` 2/2, Battlecry: Discover a spell [discover] |
| 3 | `neutral_dungeon_delver` ×2 · `war_iron_vanguard` 2/4 Taunt · ★`war_quartermaster` 2/3, Battlecry: Give your weapon +1 Durability [weapons] | `neutral_dungeon_delver` ×2 · ★`decay_husk_tender` 2/3, Battlecry: Summon a 1/1 Husk [husk] · `decay_grave_warden` 1/4 Taunt | `neutral_dungeon_delver` ×2 · ★`knowledge_study` spell: Draw 2 cards [draw] · ★`knowledge_lightning_lash` spell: Deal 3 damage to a minion [spells] |
| 4 | `neutral_crypt_brute` · ★`war_pit_brawler` 4/3 Charge [aggro] | `neutral_crypt_brute` · ★`decay_shambling_heap` 3/4, Deathrattle: Summon two 1/1 Husks [deathrattle] | `neutral_crypt_brute` · ★`knowledge_lorekeeper` 3/5, Spell Damage +1 [spell_damage] |
| 5 | `neutral_ogre_porter` | `neutral_ogre_porter` | `neutral_ogre_porter` |

Each starter: 15 cards, total cost 37, average 2.47, 6 plan cards (F1, F2). Each starter contains
exactly one card that interacts with the hero power's output (Quartermaster with the Whetstone
Blade; Culling with a Husk; Candle Acolyte with Frost Lance) so the power is taught by turn 3.

**H-5 — Card set identity (~25 cards per set, DD-H03).** The set is what Reward Draft can offer
this hero beyond neutrals (`collectible_pool(hero_set)`, `bundle_pool(hero_set)`); it is where the
plan lives. Composition is a Content target checked by F4, not a loader rule.

| Set | Mechanics and keywords | Minions / Spells / Weapons | Theme tags (bundles, DD-H05) | Signature cards (3; text provisional) |
|---|---|---|---|---|
| `war` | Weapons as the damage source; hero attacks trigger things; Armour as the defensive resource; Charge/Rush; Windfury on weapons | 13 / 6 / 6 | `weapons`, `aggro`, `armour` | `war_duelists_edge` 4, weapon 3/3, "Whenever your hero attacks, gain 2 Armour" · `war_pit_champion` 5 legendary 4/6, "Battlecry: Your hero has Windfury this turn" · `war_cleave_through` 3 spell, "Deal 2 damage to a minion and the minions next to it" |
| `decay` | Deathrattle, sacrifice ("destroy a friendly minion" as a cost), Husk swarm, Poisonous, Lifesteal on a few finishers | 17 / 8 / 0 | `deathrattle`, `sacrifice`, `husk` | `decay_husk_mother` 5 legendary 3/6, "Whenever a friendly minion dies, summon a 1/1 Husk" · `decay_plague_of_rot` 4 spell, "Destroy all your Husks. Deal 1 damage to all enemies for each" · `decay_feast_of_worms` 3 spell, "Destroy a friendly minion. Summon three 1/1 Husks" |
| `knowledge` | Spell damage scaling, draw, Discover, Freeze, cost reduction in hand (F1 `hand_aura_delta`), few but efficient minions | 11 / 14 / 0 | `spells`, `draw`, `spell_damage`, `discover` | `knowledge_grand_grimoire` 6 legendary 4/6, "Spell Damage +2. Battlecry: Discover a spell" · `knowledge_chain_lightning` 4 spell, "Deal 3 damage to a minion, then 2 to a random enemy minion" · `knowledge_apprentice` 2, 2/2, "Your spells cost (1) less" |

**H-6 — Matchups (strengths / weaknesses vs boss archetypes).** Archetype names are provisional
until Boss AI and Content define the boss pool; the table is a design intent for Content's boss
mix (every hero should have at least one bad band-1 matchup and no unwinnable one, Pillar 2).

| Boss archetype | War | Decay | Knowledge |
|---|---|---|---|
| **Healer** (restores 3–5 health per turn) | Strong — weapon face damage out-races a heal | Weak — wide 1/1s rarely push face damage through | Even — burn spells race, but the deck runs thin (Insight fatigue) |
| **Swarm** (many small minions) | Weak — one weapon swing per turn clears one body | Strong — Rot plus Husk trades, Plague of Rot | Strong — Spell Damage makes pings into clears |
| **Wall** (big Taunts) | Weak early (must attack into Taunt), strong with Cleave Through | Even — Husks chump, sacrifice spells ignore the wall | Strong — Freeze and targeted damage |
| **Burn** (face damage every turn) | Even — Armour from Shield Squire / Duelist's Edge | Weak — no healing, slow board | Weak — low minion count, Insight tax slows answers |
| **Control** (removal, board clears) | Strong — weapons are not minions | Strong — Deathrattles profit from clears | Even — card advantage keeps pace |

**H-7 — Unlock heroes (DD-H02), data only, out of v1 scope.** Each ships as a `HeroDef` with a
non-null `unlock` key owned by Meta Progression (field location: Open Questions). None has a set
file at v1, so the records are added together with their set files (`E_MISSING_FILE`). Power
sketches are intent only, **not** valid DSL yet.

- **Fortune — "Lady Tallow"** (coin-gold / soot). Gambling, random outcomes made legible by the
  event log: coin flips, "a random enemy", Discover from the neutral pool, cheap cards with
  upside. Power sketch *Toss* (2): "Flip a coin. Heads: deal 2 damage to a random enemy. Tails:
  gain 2 Armour." Unlock reference: `unlock.hero_fortune` (e.g. first victory with any hero).
- **Order — "Warden Cassia"** (ivory / steel). Divine Shield, Taunt, healing, buff auras; wins by
  not losing. Power sketch *Ward* (2): "Give a friendly minion Divine Shield." Unlock:
  `unlock.hero_order` (e.g. win with War).
- **Shadow — "The Lamplighter"** (charcoal / violet). Stealth, Poisonous, burst from hand,
  return-to-hand tricks. Power sketch *Garrote* (2): "Give a friendly minion +1 Attack and Stealth
  this turn." Unlock: `unlock.hero_shadow` (e.g. win with Decay or Knowledge).

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| **Hero: Locked** | `HeroDef.unlock` non-null and Meta Progression reports it unmet | Meta Progression grants the key | Shown greyed on hero select with its unlock text; `start_run(hero_id)` rejected `HERO_LOCKED` |
| **Hero: Available** | `unlock` null, or key met (launch heroes always) | Player selects it | Selectable; preview shows power and starter deck |
| **Hero: Active** | Run Structure starts a run with it | Run ends (death/victory) | Fixed for the run; supplies `MatchConfig.player.hero_def_id` and the deck seed for every match |
| **Power: Ready** | Start step of the hero's turn (`used_this_turn = false`) | `use_hero_power` accepted | Button lit if cost payable and a legal target exists (or targeting `none`) |
| **Power: Blocked** | Ready, but mana < effective cost, or `required` targeting with no legal target | Mana or board changes | Button dimmed with reason (`INSUFFICIENT_MANA` / `NO_LEGAL_TARGET`); Freeze never blocks a power (match-rules Edge Cases) |
| **Power: Used** | `hero_power_used` | Next own Start step, or a `refresh_hero_power` effect (Edge Cases) | Second use rejected `HERO_POWER_USED` |
| **War weapon slot: Empty** | match start; weapon destroyed | Whetstone (equip mode) or a weapon card | Whetstone takes the *equip* branch |
| **War weapon slot: Held** | `weapon_equipped` | durability 0 or replaced | Whetstone takes the *+1 Attack* branch; playing a weapon card destroys the held one (C6) — the Whetstone Blade has no Deathrattle, so replacing it costs nothing |

### Interactions with Other Systems

| System | Direction | Data in / out | Interface owner |
|---|---|---|---|
| **Card Database** | upstream | In: `HeroDef`, `HeroPowerDef`, card records for starter decks; `heroes()`, `hero(id)`, `hero_power(id)`; load-time validation (15 cards, own set/neutral, no tokens, power id exists) | Card Database owns the shape and the checks; this GDD owns the values |
| **Card Effects** | upstream | In: the DSL that expresses H-3 (`branch`, `enchant` on weapon, `equip_weapon`, `damage`, `summon` with `left_play` condition, `draw` with `bind`, `enchant_card` cost delta). Out: three `hero_powers.json` records as the first DSL acceptance cases | Card Effects owns the DSL; this GDD files the required ops (Open Questions) |
| **Match Rules** | upstream (rule), downstream (data) | In: C7 power rule, C1 `hero_power {def_id, used_this_turn}`, Start-step reset, F1 cost floor. Out: hero `health`, `hero_power` id, deck list via `MatchConfig` | Match Rules owns the rule; Heroes supplies the record (match-rules Dependencies row) |
| **Run Structure** | downstream | Out: `hero_id`, starter deck as the run's initial deck (grows per DD-R06), "first run forces War" (its rule); `HERO_LOCKED` rejection | Run Structure |
| **Reward Draft** | downstream | Out: `hero.set` selects `collectible_pool` / `bundle_pool`; theme tags in H-5 are the bundle themes it weights | Reward Draft owns weighting; this GDD owns which tags exist per set |
| **Content** | downstream | Out: the starter lists (H-4), set composition targets (H-5, F4), signature cards, tokens `war_whetstone_blade` / `decay_husk` | Content authors the files; this GDD is the brief |
| **Meta Progression** | downstream | Out: hero ids for per-hero stats; unlock keys for Fortune/Order/Shadow. In: unlock state at hero select | Meta Progression owns keys and conditions |
| **Run UI** | downstream | Out: name, identity line, colour tokens, power text, starter preview, locked state | Run UI renders; `/ux-design hero-select` |
| **Match UI** | downstream | Out: power name/cost/text/art for the button; per-hero power VFX colour | Match UI |
| **Treasures / Boss AI** | sideways / none | Treasures may modify power cost (F1 hooks) or refresh it (Edge Cases); bosses may reference the same `hero_powers.json` ids (CR-1); H-6 is advisory to Content | Treasures / — |

## Formulas

`systems-designer` not consulted — Lean mode; no Agent tool in this session. Values are designer
defaults from Hearthstone rates and the match-rules F8 pacing model; `/balance-check` revisits
them once Content exists. Constants live in `assets/data/heroes_balance.json` (DD-T01), read by
the Content validate command, never by the rules engine.

### F1. Starter deck curve

The `starter_curve_ok` predicate is defined as:

`starter_curve_ok = (Σ cost_i / N = avg_cost ∈ [AVG_MIN, AVG_MAX]) ∧ (max cost_i ≤ STARTER_MAX_COST) ∧ (∀k: count_k ∈ BUCKET[k])`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| cost_i | int | 0–10 | data file (`cards_*.json`) | Base cost of starter card i |
| N | int | 15 | constant (`starter_deck_size`) | Starter deck size (DD-R03) |
| AVG_MIN / AVG_MAX | float | 2.4 / 2.8 | data file | Average-cost band; 2.47 for all three launch starters |
| STARTER_MAX_COST | int | 5 | data file | No starter card above this; 6+ drops come from drafts |
| count_k | int | 0–15 | calculated | Number of starter cards with cost k |
| BUCKET[k] | int range | k=0: 0 · 1: 3–4 · 2: 4–5 · 3: 3–4 · 4: 1–2 · 5: 1–2 · ≥6: 0 | data file | Allowed count per cost |

**Output Range:** boolean; a failing starter is a Content error (`E_STARTER_CURVE`, emitted by
the Content validator, not the loader). **Example:** War starter counts [0,4,4,4,2,1], sum 37,
avg 2.47 → ok. Rationale: with 3 starting cards and 1 draw per turn the player sees ~7 cards by
turn 4; a 2.4–2.8 average means a play every turn from turn 1 (F8 `k` stays near 0.8 → 8–9 turn
matches at H = 30).

### F2. Plan-card share

`plan_cards = |{ i : tags(card_i) ∩ PLAN_TAGS(hero) ≠ ∅ }|`, required `plan_cards ∈ [PLAN_MIN, PLAN_MAX]`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| PLAN_TAGS(hero) | string[] | 3–4 tags | data file (H-5 theme tags) | The hero set's theme tags |
| PLAN_MIN / PLAN_MAX | int | 4 / 6 | data file | Share of the 15 that "shows the plan" |

**Output Range:** 0–15; launch starters all score 6. **Example:** Decay: Grave Rat, Carrion Crow,
Culling, Husk Tender, Shambling Heap plus Grave Rat's second tag → 6 → ok. Rationale (Pillar 1):
below 4 the hero has no identity on turn 1; above 6 the starter *is* the plan and the draft only
adds copies.

### F3. Hero power value per use

The `power_value` model is defined in damage-equivalent points:

`power_value = E[damage_dealt] × 1.0 + E[cards_gained] × 2.0 + E[bodies_summoned] × BODY_VALUE(stats) − E[self_cost_points]`

with `BODY_VALUE(a/h) = a + h` for tokens and required `power_value ∈ [HP_VALUE_MIN, HP_VALUE_MAX]`.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| E[damage_dealt] | float | 0–3 | calculated | Expected damage to enemy characters per use |
| E[cards_gained] | float | 0–1 | calculated | Expected cards added to hand |
| E[bodies_summoned] | float | 0–1 | calculated | Expected tokens entering play |
| p_kill | float | 0.3–0.6 | calculated (`/balance-check` from run logs; 0.45 default) | Chance Rot's target dies |
| E[self_cost_points] | float | 0–1 | calculated | Tax, self-damage or lost tempo in points |
| HP_VALUE_MIN / HP_VALUE_MAX | float | 1.5 / 2.5 | data file | Target band per use |
| VANILLA_2DROP | float | 5.0 | constant | 2/3 for 2 mana + a card, the comparison baseline |

**Output Range:** 1.5–2.5 points per 2 mana. The baseline is a 2-drop's 5 points, but a power
spends no card and is available every turn; Hearthstone's powers sit at ~40–50 % of a card's rate,
so the band is 0.3–0.5 × `VANILLA_2DROP`. **Examples:** Whetstone equip mode: 2 swings × 1 = 2.0
(minus retaliation, ~1.7); +1 mode: 1.0, or 2.0 on a Windfury weapon → average ≈ 1.6. Rot:
1.0 + p_kill × 2 = 1.9 at p_kill 0.45. Insight: 2.0 − ~0.3 (tax, often 0) = 1.7. All in band.

### F4. Set composition

`share_type = count(set, type) / |set|`, required within `SET_SHARE[set][type] ± 0.08` (H-5 targets: war 0.52/0.24/0.24, decay 0.68/0.32/0, knowledge 0.44/0.56/0; |set| = `HERO_SET_SIZE` 25 ± 3).

**Variables:** `count(set, type)` int 0–28 (calculated from `cards_by_set`), `HERO_SET_SIZE` int 25
(data file, DD-H03), `SET_SHARE` float table (data file). **Output Range:** 0–1 per type; a miss is
a Content warning (`W_SET_SHARE`), not an error. **Example:** War with 6 weapons of 25 → 0.24 → ok;
one Knowledge weapon → 0.04, inside the ±0.08 tolerance of 0, so tolerated but reviewed (Edge Cases).

### F5. Signature synergy count

`synergy(card) = |{ c ∈ set(hero) ∪ starter(hero), c ≠ card : tags(c) ∩ tags(card) ≠ ∅ }|`, required `synergy(signature) ≥ SYNERGY_MIN`

**Variables:** `SYNERGY_MIN` int 5 (data file); tags from card records. **Output Range:** 0–40.
**Example:** `decay_husk_mother` [husk, deathrattle] partners with Grave Rat, Husk Tender,
Shambling Heap, Feast of Worms, Plague of Rot and the power's Husks → ≥ 6 → ok. Rationale: a
signature card that nothing else talks to is a stat stick (Pillar 1 design test).

## Edge Cases

`systems-designer` not consulted — Lean mode. Match Rules already resolves the generic power
cases (no legal target, Frozen hero, cost 0); they are restated only where this GDD adds content.

**Hero power — generic**
- **If a `required` power has no legal target** (Rot with both boards empty): the button is
  dimmed `NO_LEGAL_TARGET` and the command is rejected; no mana is spent (match-rules C7).
- **If the hero is Frozen**: powers remain usable — Whetstone still equips or sharpens (the
  weapon just cannot swing this turn), Rot and Insight are unaffected (match-rules Edge Cases).
- **If hooks reduce the power's cost to 0**: allowed, floor 0 (F1), still once per turn;
  `HERO_POWER_USED` on the second attempt. A treasure may *not* grant a second use per turn by
  cost alone.
- **If an effect refreshes the hero power** (a treasure "your hero power can be used twice"):
  implemented as a `refresh_hero_power(side)` primitive that sets `used_this_turn = false` and
  emits `hero_power_refreshed`; each refresh grants exactly one more use. The primitive is **not**
  in the match-rules API today — filed in Open Questions as a Match Rules GDD change; until then
  no such treasure exists.
- **If the hero's `health` in data is not 30**: loaded as written (CR-3 says data-driven); the
  Content validator warns `W_HERO_HEALTH` so an accidental deviation is visible. Launch heroes
  are 30 (`player_starting_health`).

**Whetstone**
- **If a weapon is held**: always the +1 branch; the power never destroys a weapon. The +1 is one
  enchantment per use (once per turn, so it cannot stack within a turn) and expires at End step 5.
- **If the held weapon has Windfury**: +1 applies to both swings — intended, it is the weapon
  plan paying off.
- **If the player plays a weapon card over the Whetstone Blade**: the blade is destroyed
  (`weapon_destroyed`), no Deathrattle, then the new weapon equips (C6). No refund.

**Rot**
- **If the target has Divine Shield**: the shield pops, 0 damage dealt, the target does not die,
  no Husk (C9). The log shows `divine_shield_popped` so the player sees why.
- **If the target is a friendly minion with Stealth**: legal — Stealth blocks *enemy* targeting
  only (C12).
- **If the target dies and the player's board is full (7)**: the Husk summon is a no-op with
  `summon_failed` (C10). Killing a friendly minion first frees the slot, so the order is: damage
  step → death check (slot freed) → summon step; a friendly 1-health target therefore always
  leaves room for its own Husk.
- **If the target survives at 1 damage but dies later in the same resolution** (an aura source
  died in the same step): `left_play` is evaluated when the summon step executes, after the C10
  loop has settled the preceding step — the Husk **is** summoned. Rule: the condition reads the
  state at the start of the summon step, not the damage result. A target with a Deathrattle
  therefore has its rattle resolve before the Husk arrives.

**Insight**
- **If the deck is empty**: the draw deals fatigue damage (C11), nothing is drawn, the tax op
  skips (`in_hand` false). Mana is still spent (C5, no refunds).
- **If the hand is full (10)**: the card burns (`card_burned`); no tax; mana spent.
- **If the drawn card already has a cost enchantment** (a treasure's "spells cost 1 less"):
  deltas sum per F1 (`card_enchantment_delta`), floored at 0; the tax can net to zero.

**Data and selection**
- **If a starter deck references a missing card id**: `E_UNKNOWN_REF` at load (Card Database
  CR-5 stage 6); the game never reaches the main menu (CR-8). Never a runtime check.
- **If a starter deck contains a token** (e.g. `decay_husk`): `E_TOKEN_IN_LIST`; load fails.
- **If a set contains a weapon for a hero whose power never equips** (a Knowledge weapon): legal
  data; F4 tolerates one and `W_SET_SHARE` flags more. Rule of thumb: Knowledge and Decay ship 0
  weapons at v1 so "weapon" reads as War's word.
- **If a locked hero id arrives in `start_run`** (edited save): Run Structure rejects
  `HERO_LOCKED` after asking Meta Progression; no fallback to another hero.
- **If a hero's set file is missing** (`cards_fortune.json` before Fortune ships): `E_MISSING_FILE`
  — so unlock heroes are added to `heroes.json` only together with their set file (H-7).
- **Same hero picked twice**: n/a — single player, one hero per run.
- **If a boss references a player power** (a boss with `power_rot`): allowed (shared
  `hero_powers.json`); the Husk is summoned on the boss side (`side: self` resolves to the user).

## Dependencies

Hard = cannot function without; soft = degrades to defaults. Bidirectionality: Card Database and
Match Rules already list Heroes; the index lists Run Structure, Meta Progression and Content as
dependents, and this table adds **Reward Draft, Run UI, Match UI, Treasures** — flagged for
`/map-systems`, not edited here.

| System | Direction | Hard/Soft | Nature of dependency / interface |
|---|---|---|---|
| Card Database | This depends on Card Database | Hard | `HeroDef` / `HeroPowerDef` records and starter-deck validation (CR-3, CR-5 stage 6); queries `heroes()`, `hero()`, `hero_power()` |
| Card Effects | This depends on Card Effects | Hard | The DSL that expresses H-3; ops listed in Interactions; validator for `hero_powers.json` (CR-5 stage 7). **Provisional** — card-effects.md is being written concurrently |
| Match Rules | Mutual | Hard | They own the power rule (C7) and read our record (C3); we own the power content and the 30 health value's source row (DD-M02) |
| Run Structure | Run Structure depends on this | Hard | hero select → `MatchConfig`; starter deck as the run's initial deck; `HERO_LOCKED`; "first run forces War" |
| Reward Draft | Reward Draft depends on this | Hard | `hero.set` picks the pools; H-5 theme tags are the bundle themes |
| Content | Content depends on this | Hard | H-4 lists, H-5 targets, F1–F5 checks in the validate command |
| Meta Progression | Meta Progression depends on this | Soft | hero ids for stats; unlock keys for H-7 (absent at MVP — all heroes available) |
| Treasures | Treasures depends on this | Soft | cost hooks and (future) `refresh_hero_power` act on the power; heroes read nothing from treasures |
| Run UI / Match UI | UI depends on this | Soft | display fields (name, text, colour, power text/cost/state) |
| Boss AI | none | — | advisory matchup table only |

## Tuning Knobs

Derived from the Formulas tables (`systems-designer` not consulted — Lean mode). Owned elsewhere,
**not duplicated**: `HERO_POWER_COST`, `STARTING_HEALTH_PLAYER` (match-rules), `starter_deck_size`
(Card Database), bundle weighting (Reward Draft).

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `AVG_MIN`–`AVG_MAX` (F1) | 2.4–2.8 | 2.2–3.2 | Slower starters; turn 1–2 passes; band-1 bosses feel harder | Starters flood early then top-deck 1-drops at turn 6 |
| `STARTER_MAX_COST` (F1) | 5 | 4–6 | A 6-drop in the starter is a dead card until turn 6 of a 6–10 turn match | At 4 every late turn is two cheap plays; Pillar 1 weaker (drafts must supply all top end) |
| `PLAN_MIN`–`PLAN_MAX` (F2) | 4–6 | 3–8 | Hero identity louder; draft matters less (anti-Pillar 1) | Heroes feel samey until floor 3 |
| Whetstone Blade stats | 1/2 | 1–2 Attack / 1–3 Durability | 2/2 makes equip mode 4 points — above band; weapon bundles redundant | 1/1 makes equip mode 1 point; power feels like a tax |
| Rot damage | 1 | 1 | 2 damage kills most 2-drops: p_kill → 0.8, value 2.6, above band | — |
| Insight tax | +1 cost this turn | 0–2 | +2 makes the drawn card unplayable most turns; power becomes end-of-turn only | 0 is Life Tap without the life cost: value 2.0, strongest power (watch win rates) |
| `HP_VALUE_MIN`–`MAX` (F3) | 1.5–2.5 | 1.0–3.0 | Powers dominate turns 2–4; minions matter less | Powers skipped in favour of any 2-drop; identity fades |
| `SET_SHARE` tolerance (F4) | ±0.08 | 0.04–0.15 | Sets drift toward neutral-like mixes | Content authoring friction; rejects reasonable sets |
| `SYNERGY_MIN` (F5) | 5 | 3–8 | Signatures need big tag clusters; fewer viable signature designs | Signatures become stat sticks |

## Visual/Audio Requirements

`art-director` not consulted — Lean mode (no Agent tool); hero colours are taken from the art
bible §4 as approved. Rule: identification colour (hero primary/secondary) marks *whose* thing it
is; state colours (art bible §4 "State colours") mark *what happened*. Placeholder art in v1.

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Hero select card shown | Portrait panel in hero primary, frame in secondary; identity line in `text_light`; locked heroes desaturated to the neutral frame grey with a lock glyph | Hover tick; select: one hero-specific sting (anvil / wet crack / page turn) | Must |
| `hero_power_used` (any) | Button depresses, cost stamp dims, a short pulse in the hero primary toward the target or the hero | Shared "power" chime pitched per hero | Must |
| Whetstone — equip | Blade appears in the weapon slot with a bronze flash; attack/durability stamp 1/2 | Steel draw | Must |
| Whetstone — +1 | Weapon attack stamp ticks up in the buff state colour, reverts at end of turn | Short scrape | Must |
| Rot — damage and Husk | Target flashes damage state colour; on death the Husk rises at the rightmost slot in violet | Drip, then a dry rattle on summon | Must |
| Insight | Card draws with a gold edge; the taxed cost stamp shows the +1 in the debuff state colour until end of turn | Page turn | Must |
| Power blocked (dimmed) | Button at 50 % with reason tooltip | None (no error buzz — the state is visible) | Should |

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run
`/asset-spec system:heroes` to produce per-asset visual descriptions, dimensions, and generation
prompts from this section.

## Game Feel

Heroes add no input beyond the hero power button; the match-rules Game Feel section governs.
Hero-specific targets: **reference** — Hearthstone's hero power button, one click that does
exactly what its text says, readable in under a second (anti-reference: Dungeon Run powers hidden
behind long animations); **responsiveness** — press → `hero_power_used` rendered within 50 ms
(3 frames), full effect within 400 ms; **weight** — Whetstone light and metallic, Rot slow-wet
with a dry snap on the Husk, Insight weightless; **failure texture** — a dimmed button with its
reason, never a rejected click, and Insight's tax visible on the card before it is played;
**feel acceptance** — a playtester can name the hero from the power's sound alone, and nobody
calls a power "slow" after floor 3.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|-----------------|-----------|
| Hero name, identity line, portrait colour | Hero select (Run UI) | On screen open | Always; locked heroes show unlock text instead of the line |
| Hero power name, cost, text | Hero select preview; Match UI button tooltip | Open / hover | Always |
| Starter deck preview (15 cards, curve strip) | Hero select, expandable | On selection | Always — the player should see the plan before committing |
| Set identity blurb and theme tags | Hero select preview | On selection | Always (one line: "War: weapons, aggression, armour") |
| Power state (Ready / Blocked + reason / Used) | Beside the hero portrait (Match UI) | `hero_power_used`, Start step, mana or board change | Always |
| Weapon slot with Whetstone Blade stats | Hero portrait (Match UI) | `weapon_equipped`, `weapon_durability_changed`, enchantment events | War only in practice |
| Insight tax on the drawn card | Cost stamp on the card in hand | `card_drawn`, enchantment added/removed | Knowledge |
| Per-hero run stats (wins, best floor) | Hero select corner; run log | On screen open | Meta Progression present |

📌 **UX Flag — Heroes**: This system has UI requirements. In Phase 4 (Pre-Production), run
`/ux-design` for `hero-select` (Run UI) and for the hero power button within `hud` (Match UI)
**before** writing epics. Stories that reference UI should cite `design/ux/[screen].md`, not the
GDD directly.

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|-----------|----------------------------|--------|
| HeroDef / HeroPowerDef fields, 15-card and no-token checks, `E_UNKNOWN_REF`, `E_TOKEN_IN_LIST`, `E_MISSING_FILE` | `design/gdd/card-database.md` | CR-3, CR-5 stage 6, CR-6 pools | Data dependency |
| `collectible_pool(hero_set)`, `bundle_pool(hero_set)` keyed on `hero.set` | `design/gdd/card-database.md` | CR-6 queries | Data dependency |
| Hero power rule: cost 2, once per turn, spell targeting, `hero_power` trigger point; Start-step reset; End-step expiry of `end_of_turn` enchantments | `design/gdd/match-rules.md` | C7, C5, C4 (Start 3, End 5), F1, F9 `HERO_POWER_COST` | Rule dependency |
| Weapon replace-on-equip; hero attack from weapon; Windfury; death check between steps; `summon_failed`; Divine Shield; draw into empty deck / full hand | `design/gdd/match-rules.md` | C6, C8, C9, C10, C11, C12 | Rule dependency |
| Frozen hero may still use its power; cost 0 still once per turn | `design/gdd/match-rules.md` | Edge Cases | Rule dependency |
| Player starting health 30; boss health by band; match length model for F1 pacing; primitive API (`equip_weapon`, `summon_minion`, `draw`, `apply_enchantment`) | `design/gdd/match-rules.md` | `player_starting_health`, `boss_starting_health_by_band`, F8, Interactions | Data dependency |
| DSL ops `branch`, `enchant`, `equip_weapon`, `damage`, `summon` + `left_play`, `draw` + `bind`, `enchant_card` | `design/gdd/card-effects.md` (concurrent) | Operation and condition vocabulary | Rule dependency (provisional) |
| Hero identification colours | `design/art/art-bible.md` | §4 Hero and boss identification colours | Data dependency |
| Unlock keys `unlock.hero_*` | `design/gdd/meta-progression.md` (undesigned) | Unlock condition table | Ownership handoff |
| First run forces War; `HERO_LOCKED`; starter deck → run deck | `design/gdd/run-structure.md` (undesigned) | Hero select rules | Ownership handoff |
| Theme tags per set as bundle themes | `design/gdd/reward-draft.md` (undesigned) | Bundle weighting input | Ownership handoff |

## Acceptance Criteria

`qa-lead` not consulted — Lean mode; no Agent tool in this session. Data criteria run in the
headless validate command; behaviour criteria are gdUnit4 unit tests against the rules engine with
a fixed `match` seed and scripted decks (no Node, no scene). AC-1–6 cover H-1/H-2/H-4/H-5 and
F1–F5; AC-7–16 cover H-3 and Edge Cases; AC-17–19 cover H-7 and UI.

**Data validity**
- [ ] AC-1 **GIVEN** the shipped `assets/data/`, **WHEN** the Card Database loads, **THEN** `heroes()`
  returns `hero_war`, `hero_decay`, `hero_knowledge`, each with `health = 30`, a `hero_power` id
  that `hero_power()` resolves, and a `starter_deck` of exactly 15 ids, all `token == false` and
  all with `set ∈ {hero.set, neutral}` (zero `E_*` entries in `report()`).
- [ ] AC-2 **GIVEN** each launch starter, **WHEN** F1 is evaluated, **THEN** avg cost ∈ [2.4, 2.8],
  max cost ≤ 5 and per-cost counts fall inside `BUCKET[k]`; **AND** a test fixture with a 6-cost
  card substituted fails with `E_STARTER_CURVE`.
- [ ] AC-3 **GIVEN** each launch starter, **WHEN** F2 is evaluated, **THEN** plan_cards ∈ [4, 6].
- [ ] AC-4 **GIVEN** `cards_war.json`, **WHEN** F4 is evaluated, **THEN** weapon share is 0.24 ± 0.08
  and `cards_knowledge.json` / `cards_decay.json` contain 0 weapons (a 1-weapon fixture yields
  `W_SET_SHARE`, not an error).
- [ ] AC-5 **GIVEN** the nine signature cards, **WHEN** F5 is evaluated, **THEN** each has
  synergy ≥ 5.
- [ ] AC-6 **GIVEN** `decay_husk` and `war_whetstone_blade`, **WHEN** `collectible_pool(set)` and
  `bundle_pool(set)` are queried for any set, **THEN** neither token appears.

**Hero power behaviour (fixed seed, scripted hands)**
- [ ] AC-7 **GIVEN** War with no weapon and 2 mana, **WHEN** `use_hero_power`, **THEN** events are
  `hero_power_used`, `weapon_equipped(war_whetstone_blade)`; hero attack = 1, durability 2, mana 0.
- [ ] AC-8 **GIVEN** War holding a 2/2 weapon, **WHEN** `use_hero_power`, **THEN** no
  `weapon_destroyed`; weapon attack = 3 until the End step, 2 afterwards (`enchantment_removed`).
- [ ] AC-9 **GIVEN** Decay and an enemy 2/1, **WHEN** Rot targets it, **THEN** `damage_dealt(1)`,
  `minion_died`, `minion_summoned(decay_husk)` on the player side, in that order; **GIVEN** an
  enemy 2/3 instead, **THEN** it has `damage_taken 1` and no Husk is summoned.
- [ ] AC-10 **GIVEN** Decay and a friendly 1/1 with "Deathrattle: draw a card", **WHEN** Rot
  targets it, **THEN** the rattle resolves (`card_drawn`) before `minion_summoned(decay_husk)`.
- [ ] AC-11 **GIVEN** Decay with 7 friendly minions and an enemy 1/1, **WHEN** Rot kills it,
  **THEN** `summon_failed` is emitted and the board stays at 7.
- [ ] AC-12 **GIVEN** an enemy 1/1 with Divine Shield, **WHEN** Rot targets it, **THEN**
  `divine_shield_popped`, the minion lives, no Husk.
- [ ] AC-13 **GIVEN** Knowledge with a 1-cost spell on top of the deck and 4 mana, **WHEN**
  `use_hero_power`, **THEN** the card is drawn with effective cost 2 this turn, mana is 2, and the
  cost is 1 at the start of the player's next turn.
- [ ] AC-14 **GIVEN** Knowledge with an empty deck, **WHEN** `use_hero_power`, **THEN**
  `fatigue_damage(1)` is emitted, hand size is unchanged, mana was spent.
- [ ] AC-15 **GIVEN** any hero with a `modify_cost` hook setting the power to 0, **WHEN** the power
  is used twice in one turn, **THEN** the first succeeds at cost 0 and the second is rejected
  `HERO_POWER_USED`.

**Selection, unlocks, UI**
- [ ] AC-16 **GIVEN** a fresh profile, **WHEN** hero select opens, **THEN** exactly the three launch
  heroes are selectable and any hero with a non-null `unlock` whose key is unmet shows as Locked;
  `start_run` with that id is rejected `HERO_LOCKED`.
- [ ] AC-17 **GIVEN** each launch hero on hero select, **WHEN** a screenshot is taken
  (`production/qa/evidence/`), **THEN** the portrait panel uses that hero's primary colour from art
  bible §4 and the power text matches `HeroPowerDef.text.en` exactly.
- [ ] AC-18 **GIVEN** a match in progress, **WHEN** the power is Ready / Blocked / Used, **THEN**
  the button renders the three states distinguishably and a Blocked tooltip names the reason code.

**Non-functional**
- [ ] AC-19 No hero value (health, power cost, blade stats, Husk stats, tax, curve bounds) is a
  literal in `src/`; all come from `heroes.json`, `hero_powers.json`, `cards_*.json` or
  `heroes_balance.json`; adding a fourth hero is data only (a fixture hero with an existing power
  loads and plays a scripted turn).

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Does the DSL support `branch` with a `has_weapon` condition, a `left_play` condition evaluated at step start, and `bind`/`$drawn` references? If not, Rot and Insight need alternative encodings (Insight fallback: "Draw a card. Your hero takes 2 damage") | Card Effects GDD | `/design-system card-effects` (concurrent) | Open — H-3 sketches marked provisional |
| `refresh_hero_power(side)` primitive and `hero_power_refreshed` event are not in the match-rules API; needed before any "use your power twice" treasure | Match Rules GDD | `/design-system treasures` | Open — no such treasure in v1 content until added |
| Where does the hero `unlock` key live: a new `unlock` field on `HeroDef` (mirrors `TreasureDef`, needs a card-database CR-3 edit) or a hero-id table inside Meta Progression? Recommendation: `HeroDef.unlock` for symmetry | Card Database + Meta Progression GDDs | `/design-system meta-progression` | Open — H-7 written assuming `HeroDef.unlock` |
| Should Reward Draft read a per-hero `preferred_tags` list, or is set membership (`bundle_pool(hero_set)`) enough? H-5 tags are the proposal; adding a field needs CR-3 | Reward Draft GDD | `/design-system reward-draft` | Open — no field added here |
| Boss archetype names in H-6 are placeholders; confirm or rename when the boss pool is designed | Boss AI / Content GDDs | `/design-system boss-ai` | Open |
| Hero names (Halvard, Mother Wythe, Archivist Ilse) and identity lines are designer placeholders | owner | before `/asset-spec system:heroes` | Open — change in `heroes.json` only |
| `heroes_balance.json` as the home of F1–F5 constants (a sixth data file beyond DD-T01's list, read only by the validate command) | owner | `/design-system content` | Proposed here; needs a DD-T01 note |
