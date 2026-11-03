# Heroes

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Review (revised after `/design-review` 2026-11-03; re-review decides Approved)
> **Author**: Jacob (owner) + `/design-system` (guided, lean)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 1 (every run builds a deck you couldn't have planned — the hero is the seed of that deck); Pillar 4 (hero powers are DSL effects, logged like any spell)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` No engine reference for the `Scripting` domain under `docs/engine-reference/godot/modules/`; feasibility not checked against the pinned engine (rule-only system, no engine surface). No `Agent` tool in this session: `systems-designer` (Formulas) and `qa-lead` (Acceptance Criteria) not consulted — Lean mode would have spawned both; review those two sections manually before production.
> **REVISED 2026-11-03** (`/design-review`, lean, verdict NEEDS REVISION → revised in place): H-3 DSL sketches rewritten in card-effects v1 vocabulary (Whetstone, Rot, Insight — card-effects C11 rows 8, 16, 25 were rewritten to these powers the same day: `is_dying` for Rot, `buff cost` on `deck_top` then `draw` for Insight) and Rot's resolution order corrected to card-effects C6.0 / match-rules C10 (one effect = one step; death check after it — the Husk arrives before the Deathrattle, and a full board is not freed mid-effect). H-4 `war_quartermaster` and H-5 `war_cleave_through` texts updated to Content's v1 redesigns. F2 example and H-4 plan-card counts corrected (Decay scores 5, not 6). AC-4 fixture corrected (3 weapons, not 1). Rejection codes aligned with their owners (`NOT_ENOUGH_MANA`, `E_HERO_LOCKED`). AC-1 scoped by content batch (DD-H06: War only at MVP). AC-9/10/11/18 rewritten. Open Questions 1, 3, 4, 7 resolved from sibling GDDs; two new rows added (first-run-forces-War ownership; Content's `armour` tag on `war_iron_vanguard`).

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

**H-2 — Launch heroes (DD-H01).** All three are `unlock: null` (available from the first launch).
The concept's onboarding note ("the first run forces War") is **not yet owned by any GDD**:
run-structure R2 guards only `is_hero_unlocked`, and meta-progression gives Decay and Knowledge
`unlock: null`. Either Run Structure adds a first-run rule or Meta Progression keys the two on
`runs_played ≥ 1` — Open Questions; this GDD does not restate it.

| Hero id | Name | Identity line (`text.en`) | Set | Health | Hero power | Colour (art bible §4) |
|---|---|---|---|---|---|---|
| `hero_war` | Halvard, the Whetted | "Every turn, the blade. The rest is footwork." | `war` | 30 | `power_whetstone` | red-bronze `#9B2F23` / `#B07A3A` |
| `hero_decay` | Mother Wythe | "Nothing in my garden is wasted — least of all the dead." | `decay` | 30 | `power_rot` | green-violet `#355E3B` / `#6B4C8A` |
| `hero_knowledge` | Archivist Ilse | "I have read the ending. I am only checking the page." | `knowledge` | 30 | `power_insight` | blue-gold `#2C4F8A` / `#C9A24A` |

**H-3 — Hero power rules.** The rule is Match Rules C7 and is not restated: cost
`hero_power_cost` (2) through F1 (floor 0), once per turn (`used_this_turn`, reset in the Start
step), targeting as for spells (a `required` power with no legal target is unusable), resolved at
trigger point `hero_power`, one `hero_power_used` event. This GDD owns the **content** of the three
powers. Each is prose (binding) plus a DSL sketch in **card-effects v1 vocabulary** (C3 selectors,
C4 conditions, C5 ops), validated against `card-effects.md` on 2026-11-03: all three are
expressible and are card-effects C11 rows 8, 16 and 25 verbatim. A hero power is a
`hero_power`-trigger effect whose host is not a spell, so `damage` never adds Spell Damage
(card-effects C5 `spell_damage: auto`). One effect resolves as **one pass in one step**
(card-effects C6.0/C6.4): ops run in order against the live board, and the match-rules C10 death
check runs **after** the whole power, not between its ops — an entity at 0 health mid-pass is
*dying* (`is_dying`), still occupying its slot.

*War — Whetstone (`power_whetstone`, 2).* "Equip a 1/2 Whetstone Blade. If you already have a
weapon, give it +1 Attack this turn instead." Rejected alternatives: a plain "equip a 1/2" would
destroy a drafted weapon (C6 step 2) and so punish the hero's own plan; a plain "+1 Attack" is dead
on an empty slot for the first two turns. The conditional costs one `conditional` op and buys a
power that is always useful and never anti-synergistic. The +1 is a `buff` enchantment on the
weapon with `duration: until_end_of_turn` (match-rules C1 Weapon has `enchantments[]`; C4 End
step 5 removes it). Card-effects C11 row 8 and its AC-15 already prove this exact shape.

```json
{ "id": "power_whetstone", "name": "Whetstone", "cost": 2,
  "effects": [ { "trigger": "hero_power",
    "ops": [ { "op": "conditional", "if": { "exists": "owner_weapon" },
      "then": [ { "op": "buff", "targets": "owner_weapon", "attack": 1, "duration": "until_end_of_turn" } ],
      "else": [ { "op": "equip", "card_id": "war_whetstone_blade" } ] } ] } ] }
```

Token: `war_whetstone_blade` — weapon, cost 1, 1 Attack / 2 Durability, `token: true`, set `war`.

*Decay — Rot (`power_rot`, 2).* "Deal 1 damage to a minion. If it dies, summon a 1/1 Husk."
Targets **any** minion, friendly included: rotting your own 1-health Deathrattle minion both
fires the rattle and leaves a Husk, which is the sacrifice fantasy in one click. Rejected: "summon
a Husk" (no decision), "destroy a friendly minion" (unusable on an empty board for the first turns
and never removal). **"If it dies" is the card-effects `is_dying` predicate** (health ≤ 0 or
`pending_destroy`, read after the damage and before the death check that follows the pass,
C6.0): the whole power is one step, so the target still occupies its slot when the `conditional`
runs, and the C10 death check (and any Deathrattle) comes after the Husk. A Divine Shield pop
leaves health unchanged, so `is_dying` is false and no Husk (card-effects F2).

```json
{ "id": "power_rot", "name": "Rot", "cost": 2,
  "effects": [ { "trigger": "hero_power",
    "targets": { "selector": "chosen", "filter": { "kind": "minion" } },
    "ops": [ { "op": "damage", "amount": 1 },
      { "op": "conditional", "if": { "test": [ "target", { "is_dying": true } ] },
        "then": [ { "op": "summon", "card_id": "decay_husk", "position": "end" } ] } ] } ] }
```

Token: `decay_husk` — minion, cost 1, 1/1, no text, `token: true`, set `decay`, tag `husk`.

*Knowledge — Insight (`power_insight`, 2).* "Draw a card. It costs (1) more this turn." Chosen
over Spark ("deal 1 damage"): Spark would make two of three heroes pingers (concept risk "heroes
feel samey") and says nothing about Pillar 1, whereas Insight makes every drafted card arrive
sooner — the power is literally "see more of the deck you built". The tax is a sequencing test,
not a penalty: used after spending mana it is free, used first to dig for an answer it costs one.
The 15-card starter makes early overuse self-limiting through fatigue (C11), which no other
cost achieves as legibly. No draw-binding is needed: the card about to be drawn *is* `deck_top`,
and a cost enchantment travels with the card instance into hand (card-effects C5 `buff`, row 25),
so the tax is applied **before** the draw. The earlier fallback ("Draw a card. Your hero takes 2
damage") is withdrawn.

```json
{ "id": "power_insight", "name": "Insight", "cost": 2,
  "effects": [ { "trigger": "hero_power",
    "ops": [ { "op": "buff", "targets": { "selector": "deck_top", "n": 1 }, "cost": 1, "duration": "until_end_of_turn" },
      { "op": "draw", "count": 1 } ] } ] }
```

**H-4 — Starter decks (15 each, DD-R03).** Concept-level list — the first Content batch,
authored in `cards_<set>.json` / `cards_neutral.json` against Card Database CR-3. Every starter
has the same shape (four 1-drops, four 2s, four 3s, two 4s, one 5 — F1) so early turns feel the
same speed and the *difference* is the plan cards (★, tag in brackets). Neutrals are shared (MVP
budget: War's starter needs 7 War cards and 5 distinct neutrals — 8 copies; Content's MVP-0 batch
authors all 7 shared neutrals, of which `neutral_lantern_bearer` sits in no launch starter and is
held for bundles).

Shared neutral cards: `neutral_torch_imp` 1 — 1/2 · `neutral_tunnel_rat` 1 — 2/1 ·
`neutral_cellar_guard` 2 — 2/3 · `neutral_lantern_bearer` 2 — 2/2 Taunt ·
`neutral_dungeon_delver` 3 — 3/4 · `neutral_crypt_brute` 4 — 4/5 · `neutral_ogre_porter` 5 — 5/6.

| Cost | War (`hero_war`) | Decay (`hero_decay`) | Knowledge (`hero_knowledge`) |
|---|---|---|---|
| 1 | `neutral_tunnel_rat` ×2 · ★`war_shield_squire` 1/2, Battlecry: Gain 2 Armour [armour] · ★`war_sharpen` spell: Give your weapon +2 Attack this turn [weapons] | `neutral_torch_imp` ×2 · `neutral_tunnel_rat` · ★`decay_grave_rat` 1/1, Deathrattle: Summon a 1/1 Husk [deathrattle] | `neutral_torch_imp` ×2 · `neutral_tunnel_rat` · ★`knowledge_candle_acolyte` 1/2, Spell Damage +1 [spell_damage] |
| 2 | `neutral_cellar_guard` ×2 · ★`war_rusted_axe` weapon 2/2 [weapons] · ★`war_warcry` spell: Give your minions +1 Attack this turn [aggro] | `neutral_cellar_guard` ×2 · ★`decay_carrion_crow` 2/1, Deathrattle: Draw a card [deathrattle] · ★`decay_culling` spell: Destroy a friendly minion. Draw 2 cards [sacrifice] | `neutral_cellar_guard` ×2 · ★`knowledge_frost_lance` spell: Deal 2 damage to a minion and Freeze it [spells] · ★`knowledge_archive_seeker` 2/2, Battlecry: Discover a spell [discover] |
| 3 | `neutral_dungeon_delver` ×2 · `war_iron_vanguard` 2/4 Taunt · ★`war_quartermaster` 2/3, Battlecry: If you have a weapon, draw a card [weapons] | `neutral_dungeon_delver` ×2 · ★`decay_husk_tender` 2/3, Battlecry: Summon a 1/1 Husk [husk] · `decay_grave_warden` 1/4 Taunt | `neutral_dungeon_delver` ×2 · ★`knowledge_study` spell: Draw 2 cards [draw] · ★`knowledge_lightning_lash` spell: Deal 3 damage to a minion [spells] |
| 4 | `neutral_crypt_brute` · ★`war_pit_brawler` 4/3 Charge [aggro] | `neutral_crypt_brute` · ★`decay_shambling_heap` 3/4, Deathrattle: Summon two 1/1 Husks [deathrattle] | `neutral_crypt_brute` · ★`knowledge_lorekeeper` 3/5, Spell Damage +1 [spell_damage] |
| 5 | `neutral_ogre_porter` | `neutral_ogre_porter` | `neutral_ogre_porter` |

Each starter: 15 cards, total cost 37, average 2.47; plan cards (★) War 6, Decay 5, Knowledge 6
(F1, F2 — F2 counts *cards*, not tags). `war_iron_vanguard` and `decay_grave_warden` are the
deliberate non-plan Taunts and carry **no** theme tag in Content's records; a theme tag on either
pushes its starter over `PLAN_MAX` (Open Questions: Content tags Iron Vanguard `armour`). Each
starter contains exactly one card that interacts with the hero power's output (Quartermaster with
the Whetstone Blade; Culling with a Husk; Candle Acolyte with Frost Lance) so the power is taught
by turn 3. `war_quartermaster` was "Give your weapon +1 Durability" until Content's v1 redesign
(2026-11-03): `weapon_durability` is a v2 op (card-effects C11), so it is a conditional draw.

**H-5 — Card set identity (~25 cards per set, DD-H03).** The set is what Reward Draft can offer
this hero beyond neutrals (`collectible_pool(hero_set)`, `bundle_pool(hero_set)`); it is where the
plan lives. Composition is a Content target checked by F4, not a loader rule.

| Set | Mechanics and keywords | Minions / Spells / Weapons | Theme tags (bundles, DD-H05) | Signature cards (3; text provisional) |
|---|---|---|---|---|
| `war` | Weapons as the damage source; hero attacks trigger things; Armour as the defensive resource; Charge/Rush; Windfury on weapons | 13 / 6 / 6 | `weapons`, `aggro`, `armour` | `war_duelists_edge` 4, weapon 3/3, "Whenever your hero attacks, gain 2 Armour" · `war_pit_champion` 5 legendary 4/6, "Battlecry: Your hero has Windfury this turn" · `war_cleave_through` 3 spell, "Deal 2 damage to all enemy minions. If you have a weapon, deal 3 instead" (Content's v1 redesign — `adjacent` is source-relative only) |
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
| **Hero: Locked** | `HeroDef.unlock` non-null and Meta Progression reports it unmet | Meta Progression grants the key | Shown greyed on hero select with its unlock text; `new_run(hero_id)` rejected `E_HERO_LOCKED` (run-structure R2) |
| **Hero: Available** | `unlock` null, or key met (launch heroes always) | Player selects it | Selectable; preview shows power and starter deck |
| **Hero: Active** | Run Structure starts a run with it | Run ends (death/victory) | Fixed for the run; supplies `MatchConfig.player.hero_def_id` and the deck seed for every match |
| **Power: Ready** | Start step of the hero's turn (`used_this_turn = false`) | `use_hero_power` accepted | Button lit if cost payable and a legal target exists (or targeting `none`) |
| **Power: Blocked** | Ready, but mana < effective cost, or `required` targeting with no legal target | Mana or board changes | Button dimmed with reason (`NOT_ENOUGH_MANA` / `NO_LEGAL_TARGET` — match-rules' closed rejection set); Freeze never blocks a power (match-rules Edge Cases) |
| **Power: Used** | `hero_power_used` | Next own Start step, or a `refresh_hero_power` effect (Edge Cases) | Second use rejected `HERO_POWER_USED` |
| **War weapon slot: Empty** | match start; weapon destroyed | Whetstone (equip mode) or a weapon card | Whetstone takes the *equip* branch |
| **War weapon slot: Held** | `weapon_equipped` | durability 0 or replaced | Whetstone takes the *+1 Attack* branch; playing a weapon card destroys the held one (C6) — the Whetstone Blade has no Deathrattle, so replacing it costs nothing |

### Interactions with Other Systems

| System | Direction | Data in / out | Interface owner |
|---|---|---|---|
| **Card Database** | upstream | In: `HeroDef`, `HeroPowerDef`, card records for starter decks; `heroes()`, `hero(id)`, `hero_power(id)`; load-time validation (15 cards, own set/neutral, no tokens, power id exists) | Card Database owns the shape and the checks; this GDD owns the values |
| **Card Effects** | upstream | In: the v1 DSL that expresses H-3 (`conditional` + `exists: owner_weapon`, `buff` on `owner_weapon` and on `deck_top` cards, `equip`, `damage`, `test: [target, {is_dying: true}]`, `summon`, `draw`). Out: three `hero_powers.json` records = C11 rows 8, 16, 25 (their AC-13/15/43 are the DSL acceptance cases) | Card Effects owns the DSL; this GDD owns the prose and the token ids |
| **Match Rules** | upstream (rule), downstream (data) | In: C7 power rule, C1 `hero_power {def_id, used_this_turn}`, Start-step reset, F1 cost floor. Out: hero `health`, `hero_power` id, deck list via `MatchConfig` | Match Rules owns the rule; Heroes supplies the record (match-rules Dependencies row) |
| **Run Structure** | downstream | Out: `hero_id`, starter deck as the run's initial deck (grows per DD-R06); `E_HERO_LOCKED` rejection via Meta Progression's `is_hero_unlocked`. "First run forces War" is unowned (Open Questions) | Run Structure |
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

**Output Range:** 0–15; launch starters score War 6, Decay 5, Knowledge 6 (a card with two plan
tags counts once). **Example:** Decay: Grave Rat, Carrion Crow, Culling, Husk Tender, Shambling
Heap → 5 → ok; Grave Warden (Taunt, no tag) does not count. Rationale (Pillar 1):
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
- **If the target's health reaches 0 and the player's board is full (7)**: the Husk summon is a
  no-op with `summon_failed{board_full}` (match-rules C10). The whole power is one step, so a
  friendly target at 0 health is **still on the board** when `summon` runs — its slot is not freed
  until the death check after the power. Rotting your own minion on a full board therefore yields
  no Husk; the player must make room first. (Accepted consequence of card-effects C6.4; the
  alternative — a death check between ops — is an engine change this GDD does not request.)
- **If the target has a Deathrattle**: order is `damage_dealt(1)` → `minion_summoned(decay_husk)`
  → `minion_died` (death check) → the Deathrattle resolves. The Husk is on the board when the
  rattle fires, so a rattle that reads the board ("for each friendly minion") counts it.
- **If the target survives at 1 damage but dies later in the same resolution** (an aura source
  died in the same death check): the `conditional` has already read `is_dying` as false during
  the power — no Husk. Rule: the condition reads the live state **immediately after the `damage`
  op**, nothing later.

**Insight**
- **If the deck is empty**: the tax op no-ops first (`deck_top` is empty → `ops[0]: no_target`),
  then the draw deals fatigue damage (C11); nothing is drawn or enchanted. Mana is still spent
  (C5, no refunds). With exactly one card left it is enchanted, drawn and shows the tax in hand.
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
- **If a locked hero id arrives in `new_run`** (edited save): Run Structure rejects
  `E_HERO_LOCKED` after asking Meta Progression `is_hero_unlocked`; no fallback to another hero.
  A *saved* run for a hero that has since become locked still resumes
  (`run_warning{hero_locked_at_resume}`, run-structure Edge Cases).
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
| Card Effects | This depends on Card Effects | Hard | The DSL that expresses H-3; ops listed in Interactions; validator for `hero_powers.json` (CR-5 stage 7). Validated against card-effects.md (Designed, revised) 2026-11-03: all three powers are C11 rows 8, 16, 25 |
| Match Rules | Mutual | Hard | They own the power rule (C7) and read our record (C3); we own the power content and the 30 health value's source row (DD-M02) |
| Run Structure | Run Structure depends on this | Hard | hero select → `MatchConfig`; starter deck copied verbatim as the run's initial deck (R2); `E_HERO_LOCKED`; "first run forces War" not yet placed (Open Questions) |
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
| DSL ops `conditional`, `buff` (incl. `cost` on deck cards), `equip`, `damage`, `summon`, `draw`; selectors `owner_weapon`, `chosen`, `deck_top`; conditions `exists`, `test` + `is_dying`; one-pass step unit; C11 rows 8, 16, 25 | `design/gdd/card-effects.md` | C3, C4, C5, C6.0, C6.4, C11 | Rule dependency |
| Hero identification colours | `design/art/art-bible.md` | §4 Hero and boss identification colours | Data dependency |
| `HeroDef.unlock {key, condition}`; keys `unlock.hero_fortune/order/shadow`; `is_hero_unlocked` | `design/gdd/meta-progression.md` | M2.1, M2 condition grammar, M10 | Ownership handoff (resolved) |
| `new_run` guard, `E_HERO_LOCKED`, `hero_locked_at_resume`; starter deck copied verbatim as the run deck | `design/gdd/run-structure.md` | R2, Edge Cases, AC-23 | Ownership handoff |
| Theme tags per set as `plan_tags(hero)`; `plan_share` target | `design/gdd/reward-draft.md` | F3, Interactions (Heroes row) | Ownership handoff (resolved: no new field) |

## Acceptance Criteria

`qa-lead` not consulted — Lean mode; no Agent tool in this session. Data criteria run in the
headless validate command; behaviour criteria are gdUnit4 unit tests against the rules engine with
a fixed `match` seed and scripted decks (no Node, no scene). AC-1–6 cover H-1/H-2/H-4/H-5 and
F1–F5; AC-7–16 cover H-3 and Edge Cases; AC-17–19 cover H-7 and UI.

**Data validity**
- [ ] AC-1 **GIVEN** the shipped `assets/data/` of a content batch (Content CN-6: MVP-0 ships
  `hero_war` only per DD-H06; `hero_decay` joins at Alpha-A and `hero_knowledge` at Alpha-B),
  **WHEN** the Card Database loads, **THEN** `heroes()` returns exactly that batch's hero ids, each
  with `health = 30`, a `hero_power` id that `hero_power()` resolves, and a `starter_deck` of
  exactly 15 ids, all `token == false` and all with `set ∈ {hero.set, neutral}` (zero `E_*`
  entries in `report()`). A hero whose starter references a card from a later batch must not be
  in that batch's `heroes.json` (it would be `E_UNKNOWN_REF`, CR-8: no main menu).
- [ ] AC-2 **GIVEN** each launch starter, **WHEN** F1 is evaluated, **THEN** avg cost ∈ [2.4, 2.8],
  max cost ≤ 5 and per-cost counts fall inside `BUCKET[k]`; **AND** a test fixture with a 6-cost
  card substituted fails with `E_STARTER_CURVE`.
- [ ] AC-3 **GIVEN** each launch starter, **WHEN** F2 is evaluated, **THEN** plan_cards ∈ [4, 6].
- [ ] AC-4 **GIVEN** `cards_war.json`, **WHEN** F4 is evaluated, **THEN** weapon share is 0.24 ± 0.08
  and `cards_knowledge.json` / `cards_decay.json` contain 0 weapons; **GIVEN** a Knowledge fixture
  with 1 weapon of 25 (0.04, inside ± 0.08), **THEN** no warning; **GIVEN** 3 weapons of 25 (0.12),
  **THEN** `W_SET_SHARE` is emitted and `report()` has zero `E_*` entries.
- [ ] AC-5 **GIVEN** the nine signature cards, **WHEN** F5 is evaluated, **THEN** each has
  synergy ≥ 5.
- [ ] AC-6 **GIVEN** `decay_husk` and `war_whetstone_blade`, **WHEN** `collectible_pool(set)` and
  `bundle_pool(set)` are queried for any set, **THEN** neither token appears.

**Hero power behaviour (fixed seed, scripted hands)**
- [ ] AC-7 **GIVEN** War with no weapon and 2 mana, **WHEN** `use_hero_power`, **THEN** events are
  `hero_power_used`, `weapon_equipped(war_whetstone_blade)`; hero attack = 1, durability 2, mana 0.
- [ ] AC-8 **GIVEN** War holding a 2/2 weapon, **WHEN** `use_hero_power`, **THEN** no
  `weapon_destroyed`; weapon attack = 3 until the End step, 2 afterwards (`enchantment_removed`).
- [ ] AC-9 **GIVEN** Decay and an enemy 2/1, **WHEN** Rot targets it, **THEN** the events are
  `damage_dealt(1)`, `minion_summoned(decay_husk)` on the player side at the rightmost slot,
  `effect_resolved` with `ops[1].values.branch == "then"`, then `minion_died` — in that order;
  **GIVEN** an enemy 2/3 instead, **THEN** it has `damage_taken 1`, `ops[1].outcome == skipped`
  and no `minion_summoned`.
- [ ] AC-10 **GIVEN** Decay and a friendly 1/1 with "Deathrattle: draw a card", **WHEN** Rot
  targets it, **THEN** `minion_summoned(decay_husk)` precedes `minion_died`, which precedes the
  rattle's `card_drawn`; the Husk is at board index 1 (the dead minion's slot has closed up).
- [ ] AC-11 **GIVEN** Decay with 7 friendly minions and an enemy 1/1, **WHEN** Rot kills it,
  **THEN** `summon_failed{board_full}` is emitted and the player board stays at 7; **GIVEN** Decay
  with 7 friendly minions and Rot targeting one of its own 1/1s, **THEN** `summon_failed{board_full}`
  then `minion_died`, and the board ends at 6 with no Husk.
- [ ] AC-12 **GIVEN** an enemy 1/1 with Divine Shield, **WHEN** Rot targets it, **THEN**
  `divine_shield_popped`, the minion lives, no Husk.
- [ ] AC-13 **GIVEN** Knowledge with a 1-cost spell on top of the deck and 4 mana, **WHEN**
  `use_hero_power`, **THEN** `enchantment_applied{cost_delta: 1}` on that card instance precedes
  `card_drawn`, the card sits in hand with effective cost 2 this turn, mana is 2, and the cost is 1
  at the start of the player's next turn (`enchantment_removed` at the End step).
- [ ] AC-14 **GIVEN** Knowledge with an empty deck, **WHEN** `use_hero_power`, **THEN**
  `fatigue_damage(1)` is emitted, hand size is unchanged, mana was spent.
- [ ] AC-15 **GIVEN** any hero with a `modify_cost` hook setting the power to 0, **WHEN** the power
  is used twice in one turn, **THEN** the first succeeds at cost 0 and the second is rejected
  `HERO_POWER_USED`.

**Selection, unlocks, UI**
- [ ] AC-16 **GIVEN** a fresh profile, **WHEN** hero select opens, **THEN** exactly the three launch
  heroes are selectable and any hero with a non-null `unlock` whose key is unmet shows as Locked;
  `new_run` with that id is rejected `E_HERO_LOCKED` (run-structure AC-23 covers the engine side;
  this AC covers the hero-select state).
- [ ] AC-17 **GIVEN** each launch hero on hero select, **WHEN** a screenshot is taken
  (`production/qa/evidence/`), **THEN** the portrait panel uses that hero's primary colour from art
  bible §4 and the power text matches `HeroPowerDef.text.en` exactly.
- [ ] AC-18 **GIVEN** a match in progress, **WHEN** the power is Ready / Blocked / Used, **THEN**
  three retained screenshots (`production/qa/evidence/`) show the button in the three states
  `design/ux/hud.md` specifies (lit / 50 % with tooltip / depressed with dimmed cost stamp), and the
  Blocked tooltip text contains the literal rejection code (`NOT_ENOUGH_MANA` or `NO_LEGAL_TARGET`)
  that `legal_commands()` reports for `use_hero_power`.

**Non-functional**
- [ ] AC-19 No hero value (health, power cost, blade stats, Husk stats, tax, curve bounds) is a
  literal in `src/`; all come from `heroes.json`, `hero_powers.json`, `cards_*.json` or
  `heroes_balance.json`; adding a fourth hero is data only (a fixture hero with an existing power
  loads and plays a scripted turn).

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Does the DSL express Whetstone's branch, Rot's "if it dies" and Insight's tax on the drawn card? | Card Effects GDD | — | **Resolved 2026-11-03**: card-effects C11 rows 8, 16, 25 are these three powers (`conditional`/`exists owner_weapon`; `is_dying`; `buff cost` on `deck_top` then `draw`). Content's open question "which Insight text ships" is thereby answered: the tax text; the "Deal 1 damage" row is gone |
| `refresh_hero_power(side)` primitive and `hero_power_refreshed` event are not in the match-rules API; card-effects lists `hero_power_refresh` as v2 and has filed the primitive request with Match Rules | Match Rules GDD | before any "use your power twice" treasure | Open — no such treasure in v1 content (treasures.md agrees) |
| Where does the hero `unlock` key live? | Card Database + Meta Progression GDDs | — | **Resolved 2026-11-03** by meta-progression M2.1: `HeroDef.unlock {key, condition}` or `null`, keys `unlock.hero_<name>`; conditions M10 match H-7's sketches. Card-database CR-3 still lists no `unlock` on `HeroDef` — that edit is pending on the card-database side |
| Should Reward Draft read a per-hero `preferred_tags` list? | Reward Draft GDD | — | **Resolved 2026-11-03**: reward-draft reads H-5 theme tags directly as `plan_tags(hero)` (its F3); no new `HeroDef` field |
| Boss archetype names in H-6 are placeholders; boss-ai.md's `archetype` key (aggro/control…) names AI profiles, not boss designs, so H-6 stays Content's brief | Content GDD | first `/balance-check` with all 16 bosses | Open — advisory only |
| Hero names (Halvard, Mother Wythe, Archivist Ilse) and identity lines are designer placeholders | owner | before `/asset-spec system:heroes` | Open — change in `heroes.json` only |
| `heroes_balance.json` as the home of F1–F5 constants | owner | — | **Resolved**: DD-T01 lists `heroes_balance.json` (added 2026-11-03) |
| **"First run forces War"** (concept Onboarding curve) has no owner: run-structure R2 only checks `is_hero_unlocked`; meta-progression gives all launch heroes `unlock: null`. Options: Run Structure adds a first-run rule in R2, or Meta Progression keys `hero_decay` / `hero_knowledge` on `runs_played ≥ 1` (moot at MVP, which ships War only) | Run Structure or Meta Progression GDD (owner picks) | before Alpha-A | Open — flagged by `/design-review` 2026-11-03 |
| **Content tags `war_iron_vanguard` `armour`**, which F2 counts as a plan card: War's starter scores 7 > `PLAN_MAX` 6 and the validate command would fail MVP-0. Resolution: Content drops the tag (a vanilla Taunt is not the plan — H-4), or the owner raises `PLAN_MAX` to 7 | Content GDD (or owner for the knob) | MVP-0 | Open — flagged by `/design-review` 2026-11-03 |
