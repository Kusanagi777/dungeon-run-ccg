# Card Effects

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Design
> **Author**: `/design-system` (game-designer role) for the owner. `systems-designer`, `creative-director`, `qa-lead` and `art-director` not consulted — Lean mode (no `Agent` tool available in this run). Review manually before production.
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 4 (Readable, deterministic rules) primarily; Pillar 1 (Every run builds a deck you couldn't have planned) and Pillar 2 (Bosses are puzzles) secondarily
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` Feasibility: no engine reference for `scripting` under `docs/engine-reference/godot/modules/`; feasibility not checked against the pinned engine (this system is pure GDScript `RefCounted` logic over plain data, DD-T02). No numbered ADRs exist; `docs/architecture/modifier-hook-chain.md` (reverse-documented prototype hook chain) was read as context only.
> **Design decisions honoured**: DD-M09, DD-M11, DD-M13, DD-T01–DD-T04 (`design/design-decisions.md`); match-rules decisions C6, C10, C12, C13 and its primitive API; card-database CR-3/CR-5 stage 7; rng-event-log rules 7–12.

## Summary

[To be designed]

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Match Rules, Card Database, RNG & Event Log`

## Overview

Card Effects is the language in which every card, hero power, boss passive and treasure in
Deckdelve says what it does, and the machine that makes it happen. Each `effects[]` entry in a
Card Database record is a small JSON object — *when* it fires (a **trigger** such as `battlecry`,
`deathrattle` or `turn_end`), *whether* it fires (an optional **condition**), *whom* it affects (a
**target selector** such as `chosen`, `all_enemy_minions` or `random_enemy_minion`), and *what*
it does (an ordered list of **operations** such as `damage`, `summon`, `buff`, `draw`,
`discover`). The **resolver** owns the other half: it listens at the trigger points and hook
points Match Rules fires, decides which effects respond and in what order, evaluates selectors
and conditions against the live `MatchState`, runs the operations through the engine's primitive
API (never writing state directly, DD-T02), draws every random number from the `match_<floor>`
stream (DD-T03), and emits one `effect_resolved` event per effect so the event log can explain
every number (DD-T04). The resolver also validates every `effects[]` array at load time as the
Card Database's delegated validator (card-database CR-5 stage 7), so an unexpressible or
malformed card fails the build, not the run.

For the player this system *is* the card text. When a Battlecry wipes the board in the order they
expected, when a Deathrattle chain pays off, when a Discover offers three real choices, when a
boss passive bends a rule and the log shows exactly how — that is Card Effects doing its job
silently. It exists because the systems index names ~120 cards, 16 bosses and ~20 treasures
(DD-H03, DD-H04) and the project cannot afford a bespoke script per card: content must be data,
authored and balanced in JSON (concept: "data-driven card effects"), and the game's promise of
readable, deterministic rules (Pillar 4) requires that every card obeys one resolution order
rather than carrying its own. The risk register names this system's expressiveness as the top
technical risk; §C11 below proves coverage against the archetypal card texts the War, Decay and
Knowledge sets need, and names what is deliberately deferred to v2.

## Player Fantasy

*Framing: Direct — the player reads, chooses and watches this system on every card they play.*
`creative-director` not consulted — Lean mode (no `Agent` tool). Review manually before
production.

**The fantasy is the engine firing.** Pillar 1 says every run builds a deck you couldn't have
planned; the payoff of that promise is the turn where the pieces the dungeon handed you click —
the Decay player who trades a 1/1 into a Taunt, watches its Deathrattle summon two more, and sees
the aura lord drafted on floor 3 turn them into 3/3s before the boss's turn. Card Effects must
make that moment *legible as a chain*: each link resolves visibly, in an order the player could
have predicted, with the event feed as a receipt. The pleasure is not surprise; it is *vindication*
— "I built this, and it did what I built it to do."

- **Reference feeling**: Hearthstone's Deathrattle and Battlecry chains at their best (Dungeon
  Run's treasure-powered turns) — every card reads like a promise and the promise is kept
  exactly. We borrow the **"text is law"** quality: if the card says "all enemy minions", it is
  all of them, every time, in left-to-right order. From Slay the Spire we borrow **counted
  outcomes**: the player can total a Spell Damage turn on their fingers before committing.
- **Anti-reference**: Hearthstone's long tail of undocumented ordering trivia (which Deathrattle
  fires first, whether a buff survives a transform). Pillar 4's design test applies directly:
  *"debating a flashy effect whose ordering is ambiguous vs a plainer effect with clear ordering,
  this pillar picks the clear one."* A Deckdelve effect that needs a forum post to predict is a
  design failure here, not a quirk.
- **The anchor moment**: a Knowledge turn — two Spell Damage minions on board, the player hovers
  a 3-damage spell and the hand shows `5`, casts it into a Divine Shield Taunt, the log reads
  *shield popped, 0 dealt*, and the player immediately knows the second spell will land for 5.
  The secondary moment is the **boss passive revealed by play**: a boss whose "whenever you heal,
  deal 1 to your hero" passive fires, the feed names the passive as the cause, and the player
  rebuilds their plan around it (Pillar 2, Pillar 3 — telegraphed, legible).
- **Emotional texture**: anticipation then confirmation. Effects should feel *inevitable once
  started* — the player commits a card, the engine does the rest without asking anything except
  a Discover or Choose-One pick, and nothing "fizzles" without the log saying why
  (`fizzled: no_legal_target`, `summon_failed: board_full`).

## Detailed Design

### Core Rules

`systems-designer` and `gameplay-programmer` not consulted — Lean mode (no `Agent` tool).
Review manually before production. Terminology: the **host** of an effect is the record that
carries it (a card, hero power, boss passive or treasure); the **source** is the in-match entity
the host became (a minion, weapon, hero power, or the treasure/passive itself); the **owner** is
the source's controller (`PLAYER` or `BOSS`); a **step** is match-rules' unit of resolution
(C10). All `UPPER_CASE` constants are data-driven (`assets/data/card_effects.json`, Tuning Knobs).

#### C1. Where effects live and the effect schema

Every `effects[]` entry (CardDef, HeroPowerDef, TreasureDef) and every BossDef `passive` (an
`effects[]` array under another name) is one **effect object**. Card Database treats it as opaque;
this GDD owns its shape and validates it at load (C10).

```json
{
  "id": "war_iron_vanguard.0",
  "trigger": "battlecry",
  "scope": { },
  "condition": { },
  "targets": { "selector": "chosen", "filter": { "kind": "minion", "side": "enemy" } },
  "ops": [ { "op": "damage", "amount": 2 } ],
  "once_per_turn": false
}
```

| Field | Req | Type | Rule |
|---|---|---|---|
| `id` | no | string | Default `<host_id>.<index>`; must be unique within the host. Appears in every event this effect emits. |
| `trigger` | yes | enum | One of C2. Must be legal for the host kind (C2 "Hosts" column). |
| `scope` | per trigger | object | Narrows *which occurrences* of an observer or value trigger count (C2 "Scope keys"). Absent = the trigger's default scope. |
| `condition` | no | expression | C4. Evaluated once, when the effect starts resolving (not when queued). False → the effect resolves as `fizzled: condition_false` with no ops run. |
| `targets` | no | selector | C3. Default target set for ops that need one; an op may override with its own `targets`. |
| `ops` | yes | op[] | 1–`MAX_OPS_PER_EFFECT` (8) operations, C5, run in order. |
| `once_per_turn` | no | bool | Default `false`. When true the effect resolves at most once per global `turn` per source entity (C6.7). |

Rules of the shape:

1. **One `chosen` per play.** A host may contain at most one effect whose trigger is a *play
   trigger* (`battlecry`, `cast`, `hero_power`) and whose effect-level `targets` is `chosen`;
   that selector, with its `filter`, **is the card's targeting spec**. The validator derives
   `targeting_spec(def_id) = {mode, filter}` from it — `mode = required` when the `chosen`
   selector has no `optional: true`, `optional` when it does, `none` when there is no `chosen` —
   and exposes it to Match Rules (C6 validation reads `targeting.mode`). Card Database stores no
   `targeting` field (CR-3 rejects unknown fields); this derivation is the decision that keeps
   one source of truth. `chosen` is illegal on any non-play trigger (`E_FX_CHOSEN`).
2. **Keywords are not effects.** `taunt`, `charge`, `rush`, `divine_shield`, `windfury`,
   `stealth`, `lifesteal`, `poisonous` and `spell_damage` (with its `spell_damage` int) live in
   `keywords[]` and are interpreted by Match Rules (C12). `battlecry`, `deathrattle`, `discover`,
   `aura`, `freeze` and `silence` are listed in `keywords[]` **for display only** when the card
   has a matching effect/op; the validator warns (`W_FX_KEYWORD_MISMATCH`) when the keyword and
   the effects disagree in either direction. The resolver never reads `keywords[]` to decide
   what fires.
3. **Order is authored.** `effects[]` array order is the resolution order among one host's
   effects (C6). Content authors put the effect the card text names first.
4. **Everything is plain JSON data** (DD-T01): no code references, no callbacks. A card text that
   cannot be written in this schema is a change to this GDD (C11 v2 list), never a special case
   in code.

#### C2. Trigger vocabulary

Triggers fall into four classes, which decide *how* the resolver runs them:

- **Play triggers** resolve immediately as the first step of the command that played the host
  (match-rules C6 step 3a, spells step 3, hero power C7). They are never queued.
- **Event triggers** are raised by an engine trigger point and **queued** on match-rules' Q
  (C10: *triggers queue, never nest*); each resolves as its own step in FIFO order.
- **Static triggers** (`aura`, `passive_hand`) are not events: they are recomputed by
  `recompute_auras()` after every step (C7).
- **Value triggers** (`modify_*`) are pure folds called synchronously inside a formula
  (effective cost F1, damage F2, heal, starting hand, max attacks). They may not mutate state and
  may only contain `modify_value` ops. They exist only on treasure/passive hosts in v1.

| DSL trigger | Class | Card host binds to (match-rules trigger point) | Treasure / passive host binds to (hook) | Scope keys | Hosts | Context refs available |
|---|---|---|---|---|---|---|
| `battlecry` | play | `battlecry` | — | — | minion, weapon | `target` (chosen) |
| `cast` | play | `on_cast` | — | — | spell | `target` |
| `hero_power` | play | `hero_power` | — | — | hero power | `target` |
| `deathrattle` | event | `deathrattle(entity)` | — | — | minion, weapon | `source` (snapshot, C6.5) |
| `turn_start` | event | `turn_start(side)` | `on_turn_start` | `side: owner\|opponent\|any` (default `owner`) | minion, weapon, hero power, treasure, passive | — |
| `turn_end` | event | `turn_end(side)` | `on_turn_end` | `side` (default `owner`) | same | — |
| `on_play` | event | `on_play` | — | `by: owner\|opponent\|any`; `card: filter` | minion, weapon, treasure, passive | `trigger_subject` = the minion played |
| `on_summon` | event | `on_summon` | `on_minion_summoned` | `of: friendly_minion\|enemy_minion\|any_minion` (default friendly); `card: filter` | same | `trigger_subject` |
| `on_card_played` | event | `on_card_played` | `on_card_played` | `by` (default owner); `card: filter` (e.g. `type: spell`) | same | `trigger_subject` = the card instance |
| `after_cast` | event | `after_cast` | — | `by`; `card: filter` | minion, treasure, passive | `trigger_subject` = the spell |
| `on_attack` | event | `on_attack(attacker, defender)` | — | `attacker: self\|owner_hero\|friendly\|enemy\|any`; `defender: filter` | minion, weapon, hero power, treasure, passive | `trigger_source` = attacker, `trigger_subject` = defender |
| `on_damage_taken` | event | `on_damage(target, amount, source)` | `on_hero_damaged` (hero scope only) | `who: self\|owner_hero\|friendly\|enemy\|any` (default self); `min_amount` | same | `trigger_subject` = damaged, `trigger_source` = damager, `context.amount` = `dealt` |
| `on_damage_dealt` | event | `on_damage(target, amount, source)` | — | `by: self\|owner_hero\|owner_weapon\|friendly\|any` (default self); `to: filter` | same | as above |
| `on_heal` | event | `on_heal` | — | `who` (default friendly) ; `min_amount` | same | `trigger_subject`, `context.amount` |
| `on_minion_died` | event | `on_minion_died(minion)` | — | `who: friendly_minion\|enemy_minion\|any_minion` (default friendly); `card: filter` | same | `trigger_subject` (snapshot of the dead minion) |
| `on_draw` | event | `on_draw(card)` | `on_draw` | `side` (default owner); `card: filter` | same | `trigger_subject` = the drawn card instance |
| `on_hero_power` | event | observer on `hero_power` | — | `by` (default owner) | same | — |
| `on_weapon_equipped` | event | `on_weapon_equipped` | — | `side` | same | `trigger_subject` = weapon |
| `on_match_start` | event | — | `on_match_start` | — | treasure, passive | — |
| `aura` | static | `recompute_auras()` | `recompute_auras()` (treasure auras are hosted on the owner's hero slot) | `zone: board\|hand` (default board) | minion, weapon, treasure, passive | — |
| `passive_hand` | static | hand-scope self-aura on the card instance (F1 `card_enchantment_delta`) | — | — | minion, spell, weapon | `self` = the card in hand |
| `modify_cost` | value | — | `modify_cost` | `card: filter` (side, type, `kind: hero_power`) | treasure, passive | `context.card`, `context.value` |
| `modify_damage` | value | — | `modify_damage` | `source: filter`; `target: filter` | treasure, passive | `context.value`, `trigger_source`, `trigger_subject` |
| `modify_heal` | value | — | `modify_heal` | `source`, `target` | treasure, passive | as above |
| `modify_starting_hand_size` | value | — | `modify_starting_hand_size` | `side` | treasure, passive | `context.value` |
| `modify_max_attacks` | value | — | `modify_max_attacks` | `who: owner_hero\|friendly_minion\|…` | treasure, passive | `context.value` |

Alignment guarantees: every trigger point match-rules fires (`battlecry, on_play, on_summon,
on_cast/after_cast, hero_power, turn_start, turn_end, on_attack, on_damage, on_heal,
on_minion_died, deathrattle, on_draw, on_card_played, on_weapon_equipped`) and every hook it
exposes (`on_match_start, on_turn_start, on_turn_end, modify_cost, modify_damage, modify_heal,
on_card_played, on_minion_summoned, on_hero_damaged, on_draw, modify_starting_hand_size,
modify_max_attacks`) appears in the table above, so the DSL is a strict superset of both lists and
the Treasures GDD authors against **this** column, not a vocabulary of its own. `on_damage`
splits into `on_damage_taken` / `on_damage_dealt` because the two are different card texts with
different default scopes; both bind to the one engine point. A host using a trigger outside its
"Hosts" column fails validation (`E_FX_TRIGGER`).

#### C3. Target selectors and the filter grammar

A selector is either a bare string (defaults) or `{ "selector": name, "filter": {…}, "n": int,
"optional": bool }`. Selection is evaluated **when the op runs** (not when the effect was queued),
against the live board, in **canonical order**: player board left to right, boss board left to
right, player hero, boss hero, then weapons, then hand/deck positions. Random selectors draw from
that ordered list (F5). "Friendly"/"enemy" are relative to the effect **owner**.

| Selector | Yields | Notes |
|---|---|---|
| `self` | the source entity | For a hand-hosted `passive_hand`: the card instance. Illegal on treasure/passive hosts (`E_FX_SELECTOR`). |
| `owner_hero` / `enemy_hero` | one hero | Always exactly one. |
| `owner_weapon` / `enemy_weapon` | that side's weapon or nothing | Empty → ops no-op (`fizzled: no_target`). |
| `chosen` | the `target_id` supplied with the command | Play triggers only. Filter is the legality spec (C1 rule 1). Enemy Stealth minions are never legal (match-rules C12). **Spell / hero power with `required` and no legal target → unplayable (`NO_LEGAL_TARGET`); Battlecry with no legal target → the whole effect does not resolve** (match-rules C6, decision 7). |
| `trigger_subject` / `trigger_source` | the entity the trigger context names (C2) | Reads the raise-time snapshot if that entity has left play. |
| `all_friendly_minions` / `all_enemy_minions` / `all_minions` | minions in canonical order | Filter `not_self: true` excludes the source ("your *other* minions"). |
| `all_friendly_characters` / `all_enemy_characters` / `all_characters` | minions then hero | |
| `random_friendly_minion` / `random_enemy_minion` / `random_minion` / `random_enemy_character` / `random_friendly_character` / `random_character` | `n` distinct picks (default 1) | F5. Stealth does **not** protect against random selection (match-rules C12). Fewer candidates than `n` → all of them. |
| `adjacent` / `left_neighbour` / `right_neighbour` | board neighbours of the source | Empty at the board edge; source must be a minion in play. |
| `hand` | the owner's hand card instances | With filter; `n` (random) or `all` (default all). |
| `enemy_hand_random` | `n` random enemy hand cards | Reveals nothing beyond what the op logs. |
| `deck_top` | top `n` cards of the owner's deck | Index 0 first; empty deck → empty. |
| `deck_random` | `n` random owner deck cards matching filter | F5 over deck order. |
| `owner` / `opponent` | a side | For side-scoped ops (`draw`, `mana`, `armor`, `discover`, `add_to_hand`). |

**Filter grammar** — a JSON object of predicates, all of which must hold (AND). Unknown keys are
`E_FX_FILTER`.

| Predicate | Values | Applies to |
|---|---|---|
| `kind` | `minion \| hero \| any` (default `any` for character selectors) | characters |
| `side` | `friendly \| enemy \| any` | characters, cards |
| `has_keyword` / `lacks_keyword` | a DD-M09 keyword id (string or array) | characters, cards |
| `has_trigger` | a C2 trigger name (e.g. `deathrattle`, `battlecry`) — true when the entity has a live (unsilenced) effect with that trigger | characters, cards |
| `is_damaged`, `is_frozen`, `is_silenced`, `is_summoning_sick`, `has_divine_shield` | bool | characters |
| `attack_le`, `attack_ge`, `health_le`, `health_ge`, `cost_le`, `cost_ge`, `cost_eq` | int or value expression | characters (`cost` = definition cost), cards |
| `type` | `minion \| spell \| weapon` | cards, pools |
| `set`, `tag`, `rarity` | Card Database enum values | cards, pools |
| `token` | bool | pools (default `false` — tokens never appear in pools) |
| `not_self` | bool | any (default `false`; `true` for "other") |

#### C4. Values, references and conditions

Every numeric parameter accepts a **value expression**: an int literal, or one of
`{"ref": path}`, `{"count": selector}`, `{"add": [v…]}`, `{"sub": [a, b]}`, `{"mul": [a, b]}`,
`{"min": [v…]}`, `{"max": [v…]}`, `{"clamp": [v, lo, hi]}`. Results are ints; a negative result
where the op needs a non-negative amount is clamped to 0 and logged in `values`. Reference paths
(closed set, `E_FX_REF_PATH` otherwise): `source.attack|health|max_health|damage_taken|cost`,
`target.<same>`, `trigger_subject.<same>`, `trigger_source.<same>`, `owner.mana_current|mana_max|
hand_size|deck_size|board_size|armor|hero_health|cards_played_this_turn|minions_died_this_turn|
spells_cast_this_turn|weapon_attack|weapon_durability|fatigue_counter`, `opponent.<same>`,
`context.amount` (damage/heal amount for `on_damage_*`/`on_heal`), `context.value` (value
triggers), `counter.<key>` (C5 `add_counter`), `match.turn`. `source.*` reads live values while
the source is in play and the raise-time snapshot afterwards (C6.5).

**Conditions** are boolean expressions: `{"cmp": [v, op, v]}` with `op ∈ {==, !=, <, <=, >, >=}`;
`{"exists": selector}` (at least one match); `{"test": [entity_ref, filter]}` (apply a filter to
`source`, `target`, `trigger_subject` or `trigger_source`); `{"holding": filter}` (owner's hand has
a match); `{"is_owner_turn": true}`; `{"all": [c…]}`, `{"any": [c…]}`, `{"not": c}`. The per-turn
counters (`cards_played_this_turn` etc.) are match-rules `PlayerState.stats` deltas kept by the
resolver's `EffectRuntime` (C6.8) and reset at that side's Start step; they make Combo-style text
expressible without a keyword.

#### C5. Operations

Each op is `{ "op": name, …params, "targets": selector? }`. "Primitive" is the match-rules call
(Interactions); the primitive emits the mutation event, so the resolver never double-emits.
"Legal targets" names what the validator accepts statically; at runtime a target that no longer
qualifies (left play, wrong kind) is skipped and logged. **Failure semantics**: `no-op` means the
op is skipped, the effect continues, and `effect_resolved.ops[i].outcome` says why; `rejection`
means the command is refused before any mutation (only ever caused by `chosen`, C3).

| Op | Params | Legal targets | Primitive(s) | Failure semantics |
|---|---|---|---|---|
| `damage` | `amount` (value), `spell_damage: auto\|true\|false` (default `auto` = true iff the host is a `spell` card) | characters | `apply_damage(target, requested, source)`; `requested = amount + spell_damage(owner)` when scaling applies (F1) | No targets → no-op `no_target`; amount ≤ 0 → `apply_damage(…, 0)` still called (pops nothing, F2) |
| `heal` | `amount` | characters | `apply_heal` | no-op `no_target`; full health heals 0 (engine logs) |
| `buff` | `attack`, `health` (values, may be negative), `cost` (cards in hand only), `keywords[]`, `duration: permanent\|until_end_of_turn` | characters, weapons (attack only), hand cards (`cost` only) | `apply_enchantment(target, {attack_delta, health_delta, keywords_added, expires})` | no-op `no_target`; `health < 0` that leaves `health ≤ 0` kills in the next death check (F3) |
| `set_stats` | `attack`, `health` (values; either may be absent) | minions | `set_stats(target, attack, health)` | no-op `no_target`. "Swap Attack and Health" is `set_stats` with `attack: {ref: target.health}, health: {ref: target.attack}` — both refs read before the write |
| `give_keyword` | `keyword` (DD-M09 id, not `battlecry/deathrattle/discover/aura/silence/freeze`) | characters, weapons | `add_keyword` (an enchantment with `keywords_added`) | no-op; granting a keyword already held is a no-op `already_has` |
| `remove_keyword` | `keyword` | characters | **none in match-rules v1** — provisional primitive `remove_keyword(target, kw)` requested (Open Questions) | Validator rejects (`E_FX_OP_UNAVAILABLE`) until the primitive exists → v2 list |
| `silence` | — | minions | `silence` | no-op `no_target` |
| `freeze` | — | characters | `freeze` | no-op; re-freezing re-stamps (match-rules C13) |
| `destroy` | — | minions, weapons | `destroy` (sets `pending_destroy`; dies in the next death check, so Deathrattles fire) | no-op `no_target` |
| `summon` | `card_id`, `count` (value, 1–`MAX_SUMMON_COUNT`), `position: source_slot\|right_of_source\|end\|chosen_slot` (default `source_slot` for deathrattles, `right_of_source` otherwise), `side: owner\|opponent` | — (side-scoped) | `summon_minion(side, def_id, position)` × count, left to right | Board full → the engine emits `summon_failed{board_full}` per failed copy; the op continues with the remaining count (each is its own call) |
| `transform` | `card_id` | minions | `transform(target, def_id)` — new `entity_id`, no summoning-sickness reset, enchantments dropped, Battlecry does **not** fire | no-op `no_target`; a transformed source's remaining ops that reference `self` resolve against the new entity (C6.5) |
| `draw` | `count` (value), `side` (default owner) | — | `draw(side, 1)` × count (fatigue/burn per match-rules C11) | Never fails; empty deck → fatigue, full hand → burn, both engine-logged |
| `discover` | `pool: collectible\|list\|deck\|hand`, `list: [card_ids]`, `filter`, `count` (default `DISCOVER_COUNT` 3), `then: add_to_hand\|summon\|cast` (default `add_to_hand`) | — (side-scoped) | `discover(side, options) → ChoiceRequest` (match-rules Choice phase); on `choose`, `add_card_to_hand` / `summon_minion` / resolve the card's `cast` effect | 0 candidates → no-op `empty_pool`, no Choice; 1–2 candidates → offer that many (F4) |
| `add_to_hand` | `card_id` **or** `from: {pool, filter}` (random, F4 pick of 1), `count`, `side` | — | `add_card_to_hand(side, def_id)` × count | Full hand → engine burns (`card_burned`), op outcome `burned` |
| `copy_to_hand` | `count`, `side` | characters (minions), hand/deck cards | `add_card_to_hand(side, target.def_id)` — a copy is the **definition**, never the instance: enchantments, damage and temporary buffs are not copied | no-op `no_target` |
| `return_to_hand` | — | minions | `return_to_hand` (becomes a fresh card instance of its `def_id`; full hand → burned by the engine) | no-op `no_target` |
| `shuffle_into_deck` | `card_id` or `targets` (hand cards / minions), `count`, `position: random\|top\|bottom` | hand cards, minions, or none | **provisional** primitive `add_card_to_deck(side, def_id, position)` requested from match-rules | Validator accepts; flagged `E_FX_OP_UNAVAILABLE` until the primitive lands → v1 content must not use it |
| `discard` | `count`, `random: true` (v1 only random), `side` | — | **provisional** `discard(side, instance)` requested | as above |
| `mana` | `amount` (±), `duration: this_turn\|permanent` | — (side) | `add_mana(side, n, temporary)`; clamps to `MAX_MANA` and ≥ 0 (match-rules C5) | Never fails; clamped delta logged |
| `armor` | `amount` | — (side) | `apply_armor` | Never fails |
| `equip` | `card_id` (a weapon def) | — (side) | `equip_weapon(side, def_id)` (old weapon destroyed first, match-rules C6) | Never fails |
| `weapon_durability` | `amount` (±) | weapons | **provisional** `modify_durability(weapon, delta)` requested | as `shuffle_into_deck` |
| `hero_power_refresh` | — | — (side) | **provisional** `refresh_hero_power(side)` requested | as above |
| `retrigger` | `trigger: deathrattle` (v1 allows only `deathrattle`) | minions, weapons | Queues the target's live effects with that trigger as if raised now (`trigger_queued{reason: retrigger}`) | no-op `no_target` or `no_such_trigger` |
| `add_counter` / `set_counter` | `key`, `amount` / `value` | — (source-scoped) | Resolver-owned `EffectRuntime.counters[source_id][key]`; emits `counter_changed` | Never fails; counters die with the source |
| `conditional` | `if` (condition), `then: op[]`, `else: op[]` | per inner op | — | The branch not taken is logged as `skipped`; inner ops obey their own semantics |
| `repeat` | `times` (value, 1–`MAX_REPEAT` 10), `ops: op[]` | per inner op | — | Each iteration re-evaluates selectors against the live board (so "deal 1 damage to a random enemy, 3 times" can hit three different or the same target) |
| `choose_one` | `options: [{label_key, ops: op[]}]` (2–4) | per inner op | `discover(side, options)` with `kind: choose_one` → Choice phase; the picked option's ops run | Boss AI picks for the boss; a `chosen` inside an option is illegal (`E_FX_CHOSEN`) — Choose-One cards with targets declare the `chosen` at effect level and both options use it |
| `aura` | `attack`, `health`, `cost`, `keywords[]` | per the effect's `targets` (static, C7) | `apply_enchantment(…, is_aura: true)` inside `recompute_auras()` | Only legal under trigger `aura` / `passive_hand` (`E_FX_OP`) |
| `modify_value` | exactly one of `delta` (value), `set` (value), `mul` (int ≥ 0) | — | Returns `context.value` transformed; the engine clamps per its formula | Only legal under value triggers; any other op there is `E_FX_OP` |

#### C6. Resolution

1. **Binding.** At `RulesEngine.start`, the resolver registers itself as the engine's effect
   callback. For each card instance it indexes its host's effects by trigger; for each treasure and
   the boss passive it installs hooks through `hook_installers` (match-rules C3 step 1) in
   installation order — **treasures in pick order, then the boss passive** — one hook per effect.
2. **Who responds.** When the engine fires trigger point `P` with context `ctx`, the resolver
   collects candidates in the engine's candidate order and keeps those whose effect has a trigger
   bound to `P`, whose `scope` matches `ctx`, whose source is in play (or in hand for
   `passive_hand`), is not `silenced`, and whose `once_per_turn` mark is clear. Each kept effect is
   **queued** (event triggers) or **run now** (play triggers). Deathrattles are queued by the
   engine's death check in DD-M11 order; this step only supplies the effects.
3. **Resolution order table** — the single table a player or tester needs (hooks before card
   triggers at the same point is the rule throughout; each numbered item is its own step with
   the full C10 loop after it):

   | Engine point | Order |
   |---|---|
   | Minion / weapon played | 1 host `battlecry` → 2 hooks `on_card_played` (treasures, then passive) → 3 observers `on_play` → 4 hook `on_minion_summoned` → 5 observers `on_summon` (`on_weapon_equipped` for weapons) |
   | Spell cast | 1 host `cast` → 2 hooks `on_card_played` → 3 observers `on_card_played` (spell scope) → 4 observers `after_cast` → card to graveyard |
   | Hero power used | 1 host `hero_power` → 2 observers `on_hero_power` |
   | Minion summoned by an effect | 1 hook `on_minion_summoned` → 2 observers `on_summon` (no `battlecry`, no `on_play`) |
   | Start step | hooks `on_turn_start` → observers `turn_start` → draw (then its `on_draw` chain) |
   | End step | observers `turn_end` → hooks `on_turn_end` → thaw → `until_end_of_turn` expiry → auras |
   | Attack declared | observers `on_attack` (then match-rules re-check) |
   | Damage step | inside F2: `modify_damage` value hooks → `on_hero_damaged` hook (synchronous) ; after the step: `on_damage_taken` / `on_damage_dealt` observers queued in damage order, **before** the death check (so they resolve before Deathrattles from the same hit, match-rules C10) |
   | Heal | `modify_heal` value hooks → `on_heal` observers queued |
   | Death check | `minion_died` group → Deathrattles queued in DD-M11 order → `on_minion_died` observers queued (observers that died in the same check see nothing) |
   | Draw | hook `on_draw` → observers `on_draw` (never on a burn, match-rules C11) |
   | Match start | hooks `on_match_start` only |

   **Observer candidate order**: for `turn_start`/`turn_end`, the active side's board left to
   right, its weapon, its hero power/hero enchantments, then the opponent's in the same order
   (match-rules C4); for every other trigger point, player side first in that same per-side
   order (match-rules C10). Within one entity, `effects[]` index order, definition effects before
   enchantment-granted ones. Among hooks: installation order.
4. **One effect, one pass.** Resolving an effect: evaluate `condition` → for each op in order:
   resolve its selector against the live board, run the primitive per target in canonical order,
   record `{op, targets, values, outcome}` → emit `effect_resolved`. Ops are independent: an op
   with no targets is a no-op and the next op still runs. Content that needs "only if the first
   part happened" writes a `conditional`.
5. **Snapshot and liveness.** When an event trigger is queued the resolver stores
   `{source_id, def_id, owner, attack, health, max_health, board_index, keywords}`. A queued
   effect **always resolves** (match-rules C10) even if its source has since died, been
   transformed, bounced or silenced; `source.*` refs read live values while the source is still
   the same `entity_id` in play, else the snapshot. Exception, also match-rules': nothing is
   queued for a source that was not in play (or in hand for hand triggers) at raise time.
   `transform` mid-effect: later ops that name `self` act on the new entity; queued triggers of
   the old entity still resolve from their snapshot.
6. **Events and causality.** Every primitive call emits its own event with `cause_seq` set by the
   engine to the event that caused this resolution: for play triggers, the command's `card_played`
   / `spell_cast` / `hero_power_used`; for queued triggers, the `trigger_resolved` event the
   engine emits when it pops the trigger (which itself has `cause_seq` of the raising event, e.g.
   `minion_died`). The resolver emits exactly one `effect_resolved` per effect pass (payload in
   Interactions) with the same `cause_seq`, after the ops. `discover` additionally emits
   `discover_offered` when the `ChoiceRequest` is raised and `discover_picked` when resumed.
7. **`once_per_turn`** is keyed `(effect_id, source entity_id, match.turn)`; the mark is set when
   the effect is queued or run, so two raises in one step produce one resolution. Marks live in
   `EffectRuntime` and need no reset (the turn counter moves on).
8. **`EffectRuntime`** is the resolver's only state: `once_marks`, `counters`, per-side per-turn
   tallies (C4), and the `pending_choice` continuation. It is a plain-data member of `MatchState`
   so `clone()` (Boss AI look-ahead) and a future `restore(log)` carry it; it holds no Node or
   callable (DD-T02).
9. **Randomness.** Every random selection and Discover roll calls the `match_<floor>` stream the
   engine holds, **directly**, in resolution order, with the draw counts F4/F5 define. v1 does not
   fork per effect (rng-event-log proposed `fork("effect_<id>")` as provisional); one stream, one
   order, is easier to reason about in a log and is all Pillar 4 needs. Flagged in Open Questions
   for `/consistency-check`.
10. **Bounds.** The resolver adds no cap of its own at runtime: match-rules' `RESOLUTION_STEP_CAP`
    (1000 steps → `resolution_overflow`, boss wins) is the authority, and rng-event-log's
    `max_match_events` (10,000) is the backstop. What this GDD adds is **static**: the validator
    computes each effect's worst-case step bound (F6) and rejects content that could exceed
    `EFFECT_STATIC_STEP_LIMIT` (250) in one pass, so an infinite loop can only come from a
    *cycle* between cards (A summons B whose Deathrattle summons A), which the step cap catches.

#### C7. Auras and hand passives

- An `aura` effect is a **standing claim**: "while my source is in play and not silenced, every
  entity matching `targets` carries this enchantment." The engine's `recompute_auras()` (after
  every step) strips every `is_aura` enchantment and asks the resolver to re-apply all live auras
  in canonical source order (player board left to right, then boss, then treasure auras on the
  hero slot). The resolver evaluates each aura's selector afresh — so a minion that moves next to
  an "adjacent minions have +2 Attack" source gains it on the next step and loses it when it moves.
- **Stacking**: auras from different sources stack additively (F2); one source never applies the
  same aura twice to the same target even if its selector matches twice. Two copies of an aura
  lord are two sources and do stack.
- **Silence** on the source ends its aura at the next recompute (match-rules C13: Silence stops
  emission, not reception). Silence on a *recipient* strips and the recompute re-applies — net no
  change, as match-rules specifies.
- `aura` with `zone: hand` applies `cost` deltas to matching cards in the owner's hand and is
  the `hand_aura_delta` term of F1; `passive_hand` is the self-only special case ("costs (1)
  less for each minion that died this turn" = `aura`-shaped cost delta with a value expression),
  recomputed at every F1 evaluation. Treasure "your spells cost (1) less" is **not** an aura: it
  is a `modify_cost` value trigger, so that F1's three terms keep their owners (card enchantment →
  Card Effects, hand aura → Card Effects, hook → Treasures).
- Auras never grant `battlecry`/`deathrattle` effects, only stats, `cost` and the keyword set
  `give_keyword` allows.

#### C8. Choices: Discover and Choose One

1. `discover` builds its option list (F4), then calls `discover(side, options)`; the engine enters
   `Choice` with `pending_choice.side = owner` (Boss AI answers for the boss, match-rules C2) and
   the resolver stores a **continuation**: `{effect_id, source snapshot, op_index, options,
   remaining ops}` in `EffectRuntime.pending_choice`. No RNG is drawn while waiting.
2. On `choose(i)`, the resolver applies the option (`then`), then continues the same effect from
   `op_index + 1`, then the C10 loop runs as usual. The rest of the queue waited; nothing resolves
   out of order.
3. `choose_one` is the same mechanism with `kind: choose_one` and option labels instead of card
   ids; the picked option's `ops` run inline. A Choose-One Battlecry whose options need a target
   declares the `chosen` at effect level, so the player targets first (command) and picks second
   (Choice) — one rule, no special UI case.
4. At most one `ChoiceRequest` is outstanding at a time (match-rules' `pending_choice` is a single
   slot). A second `discover` reached while one is pending cannot happen: the resolver is
   synchronous and the engine is in `Choice`. A `repeat` around a `discover` therefore produces
   sequential choices, each after the previous `choose`.
5. `concede` during `Choice` abandons the continuation (match-rules States).

#### C9. Treasure hooks and boss passives

Treasures and passives are ordinary effect objects whose host is a treasure/passive; what differs
is binding (C2 hook column) and ordering (hooks first). A hook-hosted **event** trigger runs its
effect **synchronously as its own step at the hook point**, not queued (match-rules runs hooks as
steps inside the Start/End/play procedures), which is exactly what makes "hooks before card
triggers at the same point" true. A hook-hosted **value** trigger is a fold: installation order,
each sees the previous one's output, engine clamps afterwards (F1: floor 0; F2: floor 0). The
`source_id` in every event they emit is the treasure or passive id, so the event feed can name the
treasure as the cause (Pillar 2: passives bend rules visibly). Treasures own *which* hooks exist in
their pool and their magnitudes (Treasures GDD); this GDD owns the fact that they are written in
this DSL and resolve in this order.

#### C10. Schema validation (Card Database CR-5 stage 7)

The resolver ships `validate_effects(host_kind, host_id, effects[]) → report[]`, injected into the
Card Database at composition time. Each error is `{code, host_id, effect_id, path, message}` and
is merged by Card Database with severity `E_DELEGATED` (its CR-5). Closed code set:

| Code | Raised when |
|---|---|
| `E_FX_SCHEMA` | Missing/extra field, wrong type, `ops` empty or > `MAX_OPS_PER_EFFECT`, `id` duplicate within host |
| `E_FX_TRIGGER` | Unknown trigger, or trigger not legal for this host kind (C2 Hosts), or unknown `scope` key |
| `E_FX_SELECTOR` / `E_FX_FILTER` | Unknown selector / predicate; `self` on a treasure; `adjacent` on a non-minion host |
| `E_FX_OP` | Unknown op; op illegal under this trigger class (`aura` outside static, non-`modify_value` under a value trigger); param out of range |
| `E_FX_OP_TARGET` | Op applied to a selector that can never yield a legal kind (e.g. `freeze` on `hand`) |
| `E_FX_OP_UNAVAILABLE` | Op whose primitive match-rules does not expose yet (C5 provisional rows) |
| `E_FX_REF` | `card_id` in `summon`/`transform`/`equip`/`add_to_hand`/`discover.list` not found via `has(id)`; `summon`/`transform` of a non-minion; `equip` of a non-weapon |
| `E_FX_REF_PATH` | Unknown `ref` path or a context ref not available under this trigger (C2 last column) |
| `E_FX_CHOSEN` | More than one `chosen` play effect per host; `chosen` on a non-play trigger or inside `choose_one` options |
| `E_FX_BUDGET` | Static step bound (F6) > `EFFECT_STATIC_STEP_LIMIT` |
| `W_FX_KEYWORD_MISMATCH` | Display keyword present without a matching effect, or vice versa (warning) |
| `W_FX_UNREACHABLE` | `condition` is a constant false, or a `repeat` with `times: 0` (warning) |

A `Failed` load shows these in the data-error screen like any other (card-database CR-8). Tests
inject a stub validator that accepts everything, per card-database CR-5.

#### C11. Expressiveness check — archetype coverage

The risk register's top technical risk is "the DSL may not express needed effects". The table
below writes the archetypal card texts the War, Decay, Knowledge and Neutral sets, hero powers,
boss passives and treasures need (DD-H01 identities) in the DSL above. Ids are illustrative;
`effects` arrays shortened to the entry shown. Keywords are listed only where they matter.

| # | Set / kind | Card text | DSL |
|---|---|---|---|
| 1 | War minion | Battlecry: Give your weapon +1 Attack. | `{"trigger":"battlecry","targets":"owner_weapon","ops":[{"op":"buff","attack":1}]}` |
| 2 | War minion | Battlecry: Equip a 3/2 Axe. | `{"trigger":"battlecry","ops":[{"op":"equip","card_id":"war_token_axe"}]}` |
| 3 | War minion | Charge. Battlecry: Deal 1 damage to all enemy minions. | `keywords:["charge"]`, `{"trigger":"battlecry","targets":"all_enemy_minions","ops":[{"op":"damage","amount":1}]}` |
| 4 | War minion | Taunt. Battlecry: If you have a weapon, gain +2/+2. | `{"trigger":"battlecry","condition":{"exists":"owner_weapon"},"targets":"self","ops":[{"op":"buff","attack":2,"health":2}]}` |
| 5 | War minion | Whenever your hero attacks, gain 2 Armor. | `{"trigger":"on_attack","scope":{"attacker":"owner_hero"},"targets":"owner","ops":[{"op":"armor","amount":2}]}` |
| 6 | War spell | Deal damage equal to your weapon's Attack to an enemy minion. | `{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"enemy"}},"ops":[{"op":"damage","amount":{"ref":"owner.weapon_attack"},"spell_damage":false}]}` |
| 7 | War weapon | 2/2. Deathrattle: Deal 2 damage to the enemy hero. | `{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":2}]}` |
| 8 | War hero power | Sharpen: Give your weapon +1 Attack this turn; if you have none, equip a 1/2 Blade. | `{"trigger":"hero_power","ops":[{"op":"conditional","if":{"exists":"owner_weapon"},"then":[{"op":"buff","targets":"owner_weapon","attack":1,"duration":"until_end_of_turn"}],"else":[{"op":"equip","card_id":"war_token_blade"}]}]}` |
| 9 | Decay minion | Deathrattle: Summon two 1/1 Scarabs. | `{"trigger":"deathrattle","ops":[{"op":"summon","card_id":"decay_token_scarab","count":2,"position":"source_slot"}]}` |
| 10 | Decay minion | Battlecry: Destroy a friendly minion. Draw 2 cards. | `{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"destroy"},{"op":"draw","count":2}]}` (no friendly minion → Battlecry does not resolve, no draw) |
| 11 | Decay minion | Whenever a friendly minion dies, gain +1/+1. | `{"trigger":"on_minion_died","scope":{"who":"friendly_minion"},"targets":"self","ops":[{"op":"buff","attack":1,"health":1}]}` |
| 12 | Decay minion | Deathrattle: Deal damage equal to this minion's Attack to the enemy hero. | `{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"source.attack"}}]}` (snapshot, C6.5) |
| 13 | Decay minion | Poisonous. Deathrattle: Add a random Decay card to your hand. | `{"trigger":"deathrattle","ops":[{"op":"add_to_hand","from":{"pool":"collectible","filter":{"set":"decay"}},"count":1}]}` |
| 14 | Decay spell | Trigger a friendly minion's Deathrattle. | `{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly","has_trigger":"deathrattle"}},"ops":[{"op":"retrigger","trigger":"deathrattle"}]}` |
| 15 | Decay spell | Give a minion +2/+2 and Taunt. If it has a Deathrattle, +4/+4 instead. | `{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"conditional","if":{"test":["target",{"has_trigger":"deathrattle"}]},"then":[{"op":"buff","attack":4,"health":4}],"else":[{"op":"buff","attack":2,"health":2}]},{"op":"give_keyword","keyword":"taunt"}]}` |
| 16 | Decay hero power | Sacrifice: Destroy a friendly minion; summon a 2/2 Ghoul. | `{"trigger":"hero_power","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"destroy"},{"op":"summon","card_id":"decay_token_ghoul","position":"end"}]}` (unusable with no friendly minion — spell rule) |
| 17 | Knowledge minion | Spell Damage +1. | `keywords:["spell_damage"], spell_damage: 1, effects: []` |
| 18 | Knowledge spell | Deal 3 damage. | `{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"damage","amount":3}]}` (scales by F1) |
| 19 | Knowledge spell | Deal 2 damage to all enemies. | `{"trigger":"cast","targets":"all_enemy_characters","ops":[{"op":"damage","amount":2}]}` |
| 20 | Knowledge spell | Discover a spell. | `{"trigger":"cast","ops":[{"op":"discover","pool":"collectible","filter":{"type":"spell"}}]}` |
| 21 | Knowledge minion | Whenever you cast a spell, draw a card. | `{"trigger":"on_card_played","scope":{"by":"owner","card":{"type":"spell"}},"ops":[{"op":"draw","count":1}]}` |
| 22 | Knowledge minion | At the end of your turn, if you have 5 or more cards, deal 3 damage to a random enemy. | `{"trigger":"turn_end","scope":{"side":"owner"},"condition":{"cmp":[{"ref":"owner.hand_size"},">=",5]},"targets":{"selector":"random_enemy_character"},"ops":[{"op":"damage","amount":3,"spell_damage":false}]}` |
| 23 | Knowledge spell | Freeze an enemy minion. If it was already Frozen, destroy it. | `{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"enemy"}},"ops":[{"op":"conditional","if":{"test":["target",{"is_frozen":true}]},"then":[{"op":"destroy"}],"else":[{"op":"freeze"}]}]}` |
| 24 | Knowledge minion | Your spells cost (1) less. | `{"trigger":"aura","scope":{"zone":"hand"},"targets":{"selector":"hand","filter":{"type":"spell"}},"ops":[{"op":"aura","cost":-1}]}` |
| 25 | Knowledge hero power | Insight: Deal 1 damage. | `{"trigger":"hero_power","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"damage","amount":1}]}` (host is not a spell → no Spell Damage) |
| 26 | Neutral minion | Your other minions have +1/+1. (aura lord) | `{"trigger":"aura","targets":{"selector":"all_friendly_minions","filter":{"not_self":true}},"ops":[{"op":"aura","attack":1,"health":1}]}` |
| 27 | Neutral minion | Adjacent minions have +2 Attack. | `{"trigger":"aura","targets":"adjacent","ops":[{"op":"aura","attack":2}]}` |
| 28 | Neutral minion | Taunt. Divine Shield. (taunt wall) | `keywords:["taunt","divine_shield"], effects: []` |
| 29 | Neutral minion | Battlecry: Silence a minion. | `{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"silence"}]}` |
| 30 | Neutral minion | Battlecry: Return a friendly minion to your hand. | `{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"return_to_hand"}]}` |
| 31 | Neutral minion | Battlecry: Transform an enemy minion into a 1/1 Sheep. | `{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"enemy"}},"ops":[{"op":"transform","card_id":"neutral_token_sheep"}]}` |
| 32 | Neutral minion | Battlecry: Add a copy of a friendly minion to your hand. | `{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"copy_to_hand"}]}` |
| 33 | Neutral spell | Choose One — Deal 2 damage to a character; or Restore 4 Health to it. | `{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"choose_one","options":[{"label_key":"opt.smite","ops":[{"op":"damage","amount":2}]},{"label_key":"opt.mend","ops":[{"op":"heal","amount":4}]}]}]}` |
| 34 | Neutral minion | At the start of your turn, deal 1 damage to a random enemy minion, twice. | `{"trigger":"turn_start","scope":{"side":"owner"},"ops":[{"op":"repeat","times":2,"ops":[{"op":"damage","targets":"random_enemy_minion","amount":1}]}]}` |
| 35 | Boss passive | At the start of the boss's turn, restore 5 Health to the boss. | `{"trigger":"turn_start","scope":{"side":"owner"},"targets":"owner_hero","ops":[{"op":"heal","amount":5}]}` |
| 36 | Boss passive | Your opponent's minions cost (1) more. | `{"trigger":"modify_cost","scope":{"card":{"side":"enemy","type":"minion"}},"ops":[{"op":"modify_value","delta":1}]}` |
| 37 | Boss passive | Whenever the player heals, deal 1 damage to their hero. | `{"trigger":"on_heal","scope":{"who":"enemy","min_amount":1},"targets":"enemy_hero","ops":[{"op":"damage","amount":1}]}` |
| 38 | Treasure | At the start of the match, gain 10 Armor. | `{"trigger":"on_match_start","targets":"owner","ops":[{"op":"armor","amount":10}]}` |
| 39 | Treasure | Your hero power costs (0). | `{"trigger":"modify_cost","scope":{"card":{"side":"friendly","kind":"hero_power"}},"ops":[{"op":"modify_value","set":0}]}` |
| 40 | Treasure | Your spells deal 1 more damage. | `{"trigger":"modify_damage","scope":{"source":{"side":"friendly","type":"spell"}},"ops":[{"op":"modify_value","delta":1}]}` |
| 41 | Treasure | Whenever you draw a card, it costs (1) less. | `{"trigger":"on_draw","scope":{"side":"owner"},"targets":"trigger_subject","ops":[{"op":"buff","cost":-1}]}` |
| 42 | Treasure | Your minions have Rush. | `{"trigger":"aura","targets":"all_friendly_minions","ops":[{"op":"aura","keywords":["rush"]}]}` |
| 43 | Treasure | Your hero can attack twice each turn. | `{"trigger":"modify_max_attacks","scope":{"who":"owner_hero"},"ops":[{"op":"modify_value","set":2}]}` |

Coverage verdict: every archetype the brief names (weapon buffs, deathrattle summons,
sacrifice-for-value, spell damage, draw engines, discover, taunt walls, aura lords, conditional
battlecries, random pings, Choose One, transforms, boss passives, cost/damage/attack-count hooks)
is expressible with v1 ops and primitives. Rows 1, 7 and 8 need only `attack` on weapons; a
"+1 Durability" text needs the provisional `weapon_durability` op.

**v2 — deliberately not expressible in v1** (each needs either a new match-rules primitive, a new
keyword under DD-M09, or UI the MVP does not have; a card needing one is a GDD change here first):

| Text pattern | Why not v1 | Needs |
|---|---|---|
| "+N Durability", "destroy your weapon", "shuffle X into your deck", "discard", "refresh your hero power", "remove Taunt from" | No match-rules primitive | Primitives `modify_durability`, `add_card_to_deck`, `discard`, `refresh_hero_power`, `remove_keyword` (requested, Open Questions) |
| Secrets ("when the enemy attacks, …" hidden until it fires) | Hidden triggered cards in a secret zone; anti-Pillar 4 unless telegraphed | New zone + keyword + UI |
| Quests / multi-turn progress with a hand display | Counters exist (C5) but the UI to show progress does not | Match UI work; a `quest` keyword |
| "Your Battlecries trigger twice", "Deathrattles trigger twice" | A trigger-count modifier over other cards' effects | `modify_trigger_count` value trigger (v2 candidate) |
| "Cast a copy of the last spell you cast", "repeat all spells cast this turn" | History queries beyond per-turn tallies | A spell-history ref set |
| Outcast / hand-position text, Echo, Twinspell, Magnetic | Hand position and card-return semantics not modelled | New keywords (DD-M09 change) |
| Immune, Elusive/spell immunity, Reborn, Mega-Windfury | Deferred by match-rules Open Questions | DD-M09 change |
| Adapt-style "Discover an enchantment" | Options must be cards in v1 | `discover` with non-card options |
| Hero replacement ("become a Lich") | Hero identity is fixed per run (Heroes) | Out of scope for v1 |

### States and Transitions

Two state machines: the **effect instance** (one per raise of an event trigger, or per play of a
play trigger) and the **aura claim** (one per static effect per source). Both are plain data in
`EffectRuntime`; every transition emits the event named, or is implied by an engine event.

**Effect instance**

| State | Entry condition | Exit condition | Behaviour |
|---|---|---|---|
| `Armed` | Source enters play / hand with the effect; `silenced = false`; `once_per_turn` mark clear | Trigger point fires with matching scope → `Queued` or `Resolving`; Silence or source leaves play → `Disarmed` | Listens; no state of its own beyond the mark |
| `Queued` | Resolver raises the effect for an event trigger (`trigger_queued`) | Engine pops it (`trigger_resolved`) → `Resolving` | Holds the raise-time snapshot (C6.5); survives the source leaving play |
| `Resolving` | Popped, or a play trigger starts | Last op done → `Resolved`; `condition` false → `Fizzled`; `discover`/`choose_one` reached → `AwaitingChoice`; step cap hit → `Aborted` | Runs ops in order through primitives; each primitive is one step |
| `AwaitingChoice` | `ChoiceRequest` raised (`discover_offered`) | `choose(i)` (`discover_picked`) → `Resolving`; `concede` → `Aborted` | Continuation stored; engine phase is `Choice`; no RNG draws |
| `Resolved` | All ops attempted (`effect_resolved`) | — (terminal) | Per-op outcomes recorded in the payload, including `no_target` no-ops |
| `Fizzled` | `condition` false, or a Battlecry whose `chosen` had no legal target (never started) | — | `effect_resolved{fizzled: reason}` for the condition case; **no event** for the never-started Battlecry (match-rules AC-13: no `battlecry` trigger event) |
| `Aborted` | `resolution_overflow` or `concede` mid-choice | — | Match has ended; nothing further is emitted by this effect |
| `Disarmed` | Source Silenced (`silenced`), transformed, returned to hand, or died with no pending raise | Source re-enters play as a new instance → a new `Armed` instance | Never fires again; queued instances of it still resolve (C6.5) |

Transition table (explicit): `Armed → Queued` (event trigger raised, guard: scope match ∧ not
silenced ∧ mark clear; side effect `trigger_queued`); `Armed → Resolving` (play trigger; guard:
`chosen` legal or absent); `Queued → Resolving` (engine pop; `trigger_resolved`); `Resolving →
AwaitingChoice` (`discover_offered`); `AwaitingChoice → Resolving` (`choose`; `discover_picked`);
`Resolving → Resolved` (`effect_resolved`); `Resolving → Fizzled` (`effect_resolved{fizzled}`);
`Resolving | AwaitingChoice → Aborted` (`match_ended`); `Armed → Disarmed` (`silenced` /
`minion_died` / `transform` / `return_to_hand`). Any other transition is a resolver bug and
asserts in debug.

**Aura claim**

| State | Entry condition | Exit condition | Behaviour |
|---|---|---|---|
| `Inactive` | Source not in play (hand, deck, dead) | Source enters play → `Active` | Not consulted by `recompute_auras()` |
| `Active` | Source in play, not silenced | Source leaves play → `Inactive`; Silence → `Suppressed` | Re-applied on every recompute to the current selector matches; one `auras_recomputed` event per recompute lists net changes |
| `Suppressed` | Source Silenced | Never (Silence is permanent, match-rules C13) | Skipped by recompute; recipients lose the enchantment at the next pass (F3) |

### Interactions with Other Systems

Card Effects has one upstream data source (Card Database), one upstream service pair (Match
Rules' primitives and trigger points; RNG & Event Log's stream and log, both reached through the
engine), and six downstream dependents that author against or read from it.

| System | Direction | Data in | Data out | Owner of the interface |
|---|---|---|---|---|
| **Match Rules** | upstream (calls us) and we call back | Trigger point fires with context; `MatchState` read access; the primitive API; the `match_<floor>` stream handle; `choose` resumption | `resolve(trigger_point, ctx)` (queues or runs effects), `legal_targets(def_id, source) → entity_id[]` and `targeting_spec(def_id)` for C6 validation, `recompute_auras()` callback, `ChoiceRequest`s, `effect_resolved`/`discover_*`/`counter_changed` events | Match Rules owns the primitives and trigger points; this GDD owns the DSL, the responder selection and the order among responders |
| **Card Database** | upstream | `effects[]`, `passive`, `spell_damage`, `type`, `cost`; `has(id)`, `collectible_pool(hero_set)`, `cards_by_set/type/tag` for pools; `card(id)` for summon/transform defs | `validate_effects()` injected as the CR-5 stage 7 validator; the `E_FX_*` code set | Card Database owns record shapes and the load pipeline; this GDD owns the effect schema and its errors |
| **RNG & Event Log** | upstream (via the engine) | `match_<floor>` stream: `randi_range`, `shuffle` (F4, F5) | `effect_resolved`, `discover_offered`, `discover_picked`, `counter_changed` payloads; `cause_seq` chaining through the engine | RNG & Event Log owns the envelope; this GDD owns `effect_resolved.values` and its own types |
| **Heroes** | downstream | Hero power `effects[]` (`hero_power` trigger) | The `hero_power` trigger semantics; the rule that a hero power is "a spell-like effect that is not a spell" (no Spell Damage by default) | Heroes owns what each power does and its numbers |
| **Treasures** | downstream | Treasure `effects[]` and boss `passive` using the hook-bound triggers (C2) | Trigger vocabulary, hook binding and ordering (C9); `source_id` = treasure id in events | Treasures owns the pool, rarity and magnitudes |
| **Boss AI** | downstream | — | `legal_targets()` to enumerate plays; `ChoiceRequest.options` to pick; `effect_resolved` payloads for look-ahead scoring on a `clone()` | This GDD guarantees `resolve` is deterministic on a clone; Boss AI owns the heuristics |
| **Match UI** | downstream | — | `effect_resolved` (one per effect, per-op detail) as the playback unit; `discover_offered` options; `targeting_spec` for drag highlights; `fizzled`/`outcome` reasons for feedback | UI is display-only |
| **Content** | downstream | Authors `effects[]` for ~120 cards, 16 bosses, 20 treasures | The schema (C1–C5), the coverage table (C11) and the v2 list | Content owns values; a new op or trigger is a change here |
| **Run Structure** | indirect | — | Nothing directly; `EffectRuntime` rides inside `MatchState` for any future mid-match restore | — |

**`effect_resolved` payload** (extends rng-event-log's catalogue row `effect_id, source_id,
operation, targets[], values{}`):

```
effect_resolved {
  effect_id, host_id, host_kind (card|hero_power|passive|treasure), source_id, owner (side),
  trigger, depth,                       # depth = length of the cause_seq chain to the command
  fizzled: null | condition_false,
  ops: [ { op, targets: [entity_id], values: { amount, requested, count, card_id, … },
           outcome: applied | no_target | board_full | burned | empty_pool | skipped | already_has } ]
}
```

`operation` in the catalogue row is the first op's name (kept for grep compatibility); the full
list is `ops[]`. `discover_offered {side, source_id, effect_id, kind: discover|choose_one,
option_card_ids[] | option_label_keys[]}` and `discover_picked {side, picked_index,
picked_card_id | picked_label_key}` are as catalogued. `counter_changed {source_id, key, value}`
is new and owned here.

**Primitive requests to Match Rules** (provisional; the ops stay validator-blocked until the
match-rules GDD adds them to its primitive API): `remove_keyword(target, kw)`,
`add_card_to_deck(side, def_id, position)`, `modify_durability(weapon, delta)`,
`refresh_hero_power(side)`, `discard(side, instance_id)`. Listed in Open Questions.

## Formulas

`systems-designer` not consulted — Lean mode (no `Agent` tool). Review manually before
production. `Source = data file` variables live in `assets/data/card_effects.json` and are listed
in Tuning Knobs; formulas owned by other GDDs are referenced, not redefined.

### F1. Spell Damage scaling

The `spell_damage_requested` formula is defined as:

`spell_damage_requested = amount + (scales ? spell_damage(owner) : 0)` where
`scales = (op.spell_damage == true) ∨ (op.spell_damage == auto ∧ host.type == spell)` and
`spell_damage(owner)` is match-rules F7 (`Σ_{m ∈ owner.board} m.spell_damage` + hero
enchantments).

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| amount | int | 0–30 | data file (card effect, after value expression) | Printed damage of the op |
| spell_damage(owner) | int | 0–10 | calculated (match-rules F7) | Owner's Spell Damage total at resolution time, re-read per op |
| scales | bool | — | data file (`spell_damage: auto\|true\|false`) | Whether this op scales; `auto` follows the host type |
| requested | int | 0–40 | calculated | Passed to `apply_damage` as `requested` (match-rules F2) |

**Output Range:** 0 to 40 under v1 content (max printed 30 is a boss-only card; player spells
≤ 10). Scaling is added once per op, not per target: "deal 2 to all enemies" with +1 Spell Damage
deals 3 to each. Hero powers, minion Battlecries and Deathrattles do not scale unless the op says
`spell_damage: true`. **Example:** Knowledge "Deal 3 damage" with two Spell Damage +1 minions →
`3 + 2 = 5`; the same board casting the Insight hero power → `1 + 0 = 1`.

### F2. Aura stacking

The `aura_stack` formula is defined, for a recipient `r` and stat `s ∈ {attack, health, cost}`, as:

`aura_delta_s(r) = Σ_{a ∈ live_auras, a.source ≠ silenced, r ∈ select(a.targets)} a.s`
(each source counted once; `max_health` then follows match-rules F6: `health = base_health +
Σ health_delta − damage_taken`).

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| live_auras | set | 0–16 entries | calculated | Static effects whose source is in play (board, weapon, treasure/passive slot) |
| a.attack / a.health / a.cost | int | −3 to +3 each | data file (card effect) | Per-aura deltas; negative auras ("enemy minions have −1 Attack") are legal |
| recompute_cost | int | 0–256 | calculated | `|live_auras| × |candidates|` selector evaluations per recompute; ≤ 16 × 16 |

**Output Range:** per-stat delta −9 to +9 in practice (three overlapping aura lords is the
realistic ceiling); attack is floored at 0 by match-rules C1's derived `attack`. **Example:** two
"other minions +1/+1" lords and an "adjacent +2 Attack" minion: a minion adjacent to the third and
other than both lords has `+4/+2`; each lord buffs the other (`+1/+1`), not itself.

### F3. Enchantment lifecycle: temporary buffs, Silence and death

The `buff_health_after` rule reuses match-rules F6 and adds expiry:

```
on buff(attack a, health h, duration d):  enchantment {attack_delta a, health_delta h,
                                           expires = (d == until_end_of_turn ? end_of_turn : null)}
on expiry / aura loss:                    damage_taken unchanged → health may drop ≤ 0 → dies next death check
on Silence of the recipient:              damage_taken' = max(0, damage_taken − (max_health_old − max_health_new))   (match-rules F6)
on negative health buff:                  same as aura loss (no clamp): a 3/3 with 2 damage given −2 health → health −1 → dies
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| attack_delta / health_delta | int | −10 to +10 | data file (card effect) | Per-enchantment change |
| expires | enum | `null \| end_of_turn` | data file (`duration`) | Removed by match-rules C4 End step 5 of the **recipient's controller** (the engine's rule; see Edge Cases for the enemy-side consequence) |
| damage_taken | int | 0–∞ | state (match-rules) | Never written by this system |

**Output Range:** as match-rules F6. **Example:** "+4/+4 until end of turn" on a 1/1 that then
takes 4 → `damage_taken 4`, health 1; at expiry `1 + 0 − 4 = −3` → it dies at the End step's
death check. The log shows `enchantment_removed` then `minion_died`, which is the legible outcome.

### F4. Discover pool construction and offer draw

The `discover_pool` formula is defined as:

```
candidates = distinct_by_def_id( filter( base(pool), op.filter ) \ { source.def_id } )
base(collectible) = collectible_pool(player_hero_set)       # both sides; tokens and `boss` set excluded by Card Database
base(list)        = op.list ∩ has(id)                        # tokens allowed here (authored)
base(deck)        = owner.deck instances                     # offers instances; pick moves it to hand
base(hand)        = owner.hand instances
if DISCOVER_EXCLUDE_HAND: candidates \= { def_ids currently in owner.hand }
n_options = min(DISCOVER_COUNT, |candidates|)
for i in 1..n_options: j = randi_range(0, |candidates| − 1); options.append(candidates[j]); candidates.remove(j)
```

Candidates are kept in Card Database's id-ascending order (CR-6) before drawing, so the draw is
independent of file order.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| collectible_pool(hero_set) | CardDef[] | size 0–400 | calculated (card-database `collectible_pool_size`) | ~40 at MVP, ~70 per hero at v1 |
| DISCOVER_COUNT | int | 1–5 | data file (default 3) | Options offered |
| DISCOVER_EXCLUDE_HAND | bool | — | data file (default `false`) | Whether cards already in hand are excluded |
| n_options | int | 0–DISCOVER_COUNT | calculated | 0 → no Choice phase (op no-op `empty_pool`) |
| draws | int | 0–DISCOVER_COUNT | calculated | Exactly `n_options` stream draws |

**Output Range:** 0–3 distinct options at defaults. The boss discovers from the **player's** pool
too (one pool, no second query; the boss's own `boss`-set cards are never offered because Card
Database excludes that set), which also keeps what the boss gets legible. **Example:** "Discover a
spell" for War at MVP: 40-card pool → 9 spells → remove the casting spell itself → 8 → 3 draws
with `randi_range(0,7)`, `(0,6)`, `(0,5)`.

### F5. Random target selection

The `random_target` formula is defined as:

```
cands = canonical_order( select(base_selector) filtered by op.filter )     # player L→R, boss L→R, player hero, boss hero
k     = min(n, |cands|)
for i in 1..k: j = randi_range(0, |cands| − 1); picks.append(cands[j]); cands.remove(j)
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| n | int | 1–16 | data file (`n`, default 1) | Picks requested |
| cands | list | 0–16 | calculated | Legal candidates; Stealth does not exclude (match-rules C12) |
| k / draws | int | 0–16 | calculated | Picks made; exactly `k` stream draws, 0 when `cands` is empty |

**Output Range:** `k` distinct entities in pick order; the op then applies to them in **pick
order** (so a "deal 1 to two random enemies" log reads in the order the dice fell). Within one
`repeat`, each iteration re-selects from the live board with replacement across iterations.
**Example:** `random_enemy_minion` with `n: 2` over an enemy board [A, B, C] and draws `1, 1` →
picks B then C.

### F6. Static step bound and the caps

The `effect_step_bound` formula is defined as:

`effect_step_bound = 1 + Σ_{op ∈ ops} steps(op)` where
`steps(op) = max_targets(op.targets) × (op is summon ? count : 1)` for leaf ops,
`steps(repeat) = times × Σ steps(inner)`, `steps(conditional) = max(Σ then, Σ else)`,
`steps(choose_one) = max over options`, `max_targets(all_*) = 16`, `max_targets(single) = 1`,
`max_targets(hand) = 10`, `max_targets(random, n) = n`.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| MAX_OPS_PER_EFFECT | int | 4–12 | data file (default 8) | Ops per effect |
| MAX_REPEAT | int | 2–20 | data file (default 10) | `times` ceiling |
| MAX_SUMMON_COUNT | int | 1–7 | data file (default 7) | `count` ceiling (= `BOARD_SIZE`) |
| EFFECT_STATIC_STEP_LIMIT | int | 50–1000 | data file (default 250) | Validator rejects an effect whose bound exceeds it (`E_FX_BUDGET`) |
| RESOLUTION_STEP_CAP | int | 200–5000 | match-rules data file (1000) | Runtime authority; owned by match-rules |
| max_match_events | int | 2,500–100,000 | rng-event-log (10,000 at defaults) | Log cap; ≈ 3 events per step worst case → 1000 steps ≈ 3,000 events, inside the cap |

**Output Range:** a typical card is 1–3 steps; the worst legal single effect is 250. Four such
effects chained still sit under the 1000-step cap, so a `resolution_overflow` in play means a
**cycle** between cards, which is the content bug it is meant to surface. **Example:** row 34
(`repeat 2 × random_enemy_minion damage`) → `1 + 2 × 1 = 3`; "deal 1 to all minions, 10 times"
→ `1 + 10 × 16 = 161`, legal; the same with `times: 20` fails validation (`321 > 250`).

## Edge Cases

`systems-designer` not consulted — Lean mode (no `Agent` tool). Review manually before
production. Every entry names the exact outcome and the event the log shows; where match-rules
already decides the case, the entry says so and adds only what this system contributes.

**Targeting and selection**

- **If a Battlecry's `chosen` has no legal target** (e.g. "Destroy a friendly minion" on an empty
  board): the minion is played, mana is paid, and the whole effect never starts — no draw, no
  `effect_resolved`, no `battlecry` event (match-rules C6, AC-13). Rationale: a body is still a
  body; the ops are one promise, not two.
- **If a spell's or hero power's `chosen` has no legal target**: `NO_LEGAL_TARGET`, not playable;
  with `optional: true` it is playable with `target_id = null` and ops that need `target` are
  no-ops `no_target`.
- **If a targeted effect names an enemy Stealth minion**: `chosen` never offers it; `all_*`,
  `adjacent` and `random_*` selectors include it (match-rules C12: random and area effects still
  hit Stealth). The log's `targets[]` shows it.
- **If an op's selector resolves to an empty set at run time** (the only enemy minion died to the
  previous op): the op is `no_target`; later ops still run. "Deal 2 damage to a minion and 1 to
  its neighbours" whose target had no neighbours deals the 2 and logs `adjacent: no_target`.
- **If `random_*` asks for `n` and fewer candidates exist**: all candidates are picked, in `k`
  draws (F5); no draw is made for an empty list, so determinism does not depend on empty rolls.
- **If `trigger_subject` has left play by the time a queued observer resolves** ("whenever a
  minion is summoned, give it +1/+1" and the summoned minion died to a Deathrattle first): the
  selector reads the snapshot for refs but the `buff` op finds no live target → `no_target`.
- **If a `conditional` references a target that was destroyed by an earlier op in the same
  effect** (`{"test": ["target", {…}]}` after `destroy`): `pending_destroy` minions are still in
  play until the death check, so the test reads them as alive; `is_damaged`/stats read live
  values. The log's `values` carries the evaluated condition.

**Summons, transforms and copies**

- **If a Deathrattle summons onto a full board**: the engine's `summon_failed{board_full}` per
  copy; the op records `board_full` and later ops continue (match-rules: deaths are removed
  before Deathrattles run, so a 7-wide board where one dies does fit one summon).
- **If `summon` with `count: 3` finds room for 1**: one `minion_summoned`, two `summon_failed`,
  op outcome `partial` with `values.summoned = 1`.
- **If a minion is transformed during resolution of its own Battlecry** ("Battlecry: transform
  this into a random 5-cost minion; gain Taunt"): `transform` creates a new `entity_id`; the
  remaining ops' `self` is the new entity, so Taunt lands on the new body; the new body's own
  Battlecry does **not** fire (C5). Queued triggers of the old entity resolve from snapshot.
- **If `transform` hits a minion with queued triggers** (its `on_damage_taken` was raised in the
  same step): those triggers still resolve (match-rules C10: queued = earned) using the snapshot.
- **If `copy_to_hand` copies a minion carrying temporary buffs, damage or Silence**: the copy is
  the bare definition — no enchantments, full health, unsilenced. Rationale: instances are not
  serialisable as cards (match-rules C1); "copy" means the card, not the body.
- **If `return_to_hand` bounces a minion with `until_end_of_turn` buffs**: it becomes a fresh
  card instance; the enchantments are gone; cost is the printed cost (hand auras then apply).
- **If a summoned minion's `on_summon` observer is the minion itself** ("whenever a minion is
  summoned" on a card that was just summoned): it does not observe its own entry — candidates are
  collected after the summon but a source must have been in play *before* the raising event
  (C6.5, match-rules "a minion that died in the same check observes nothing" mirrored).

**Buffs, auras and Silence**

- **If a buff is applied to a minion that dies later in the same resolution** ("give a minion
  +2/+2, then deal 4 to it"): the enchantment applies, the damage kills, death check removes it;
  the log shows `enchantment_applied`, `damage_dealt`, `minion_died` in that order.
- **If an aura source is Silenced**: its claim becomes `Suppressed`; at the next
  `recompute_auras()` recipients lose the stats; a recipient whose `health ≤ 0` after the loss dies
  in the next pass of the loop (match-rules F6), **after** any Deathrattles already queued.
- **If two aura lords buff each other and one dies**: the survivor loses +1/+1 at the next
  recompute; if that drops it to ≤ 0 it dies in the following pass and the log shows two death
  groups (match-rules Edge Cases, aura source dies).
- **If an `until_end_of_turn` buff is given to an *enemy* minion during the owner's turn**: per
  match-rules C4 End step 5 the enchantment is removed at the **recipient's controller's** End
  step, so it lasts through the enemy's next turn. This GDD records the consequence rather than
  overriding it and asks match-rules to confirm the intended reading (Open Questions): Hearthstone
  expires at the end of the current turn.
- **If a hand-cost aura would take a card below 0**: F1 clamps to 0; `effective_cost` never
  refunds.
- **If `give_keyword: taunt` targets a minion that already has Taunt**: outcome `already_has`, no
  `enchantment_applied`.
- **If a negative `buff` (`attack: −2`) takes attack below 0**: the enchantment is stored as is;
  match-rules' derived `attack` floors at 0; a later `+1` makes it `max(0, base − 2 + 1)`.

**Resolution order and the queue**

- **If a treasure hook and a card trigger respond to the same point** (treasure "at the start of
  your turn gain 1 Armor" and a minion "at the start of your turn deal 1 to a random enemy"): the
  hook runs first as its own step, then the card trigger (match-rules C4 steps 4–5; C6.3 table).
  Two treasures run in pick order; the boss passive after all treasures.
- **If an `on_damage_taken` trigger and the Deathrattle of the same minion are raised by one hit**:
  `on_damage_taken` is queued at the damage step, the Deathrattle at the death check, so the
  `on_damage` effect resolves first (match-rules C10, AC-28).
- **If a Battlecry summons a minion and an observer has both `on_play` and `on_summon`**: the
  played minion raises `on_play` then `on_summon` (two queued triggers, C6.3 rows 3 and 5); the
  summoned token raises only `on_summon`.
- **If a source is Silenced while its trigger is already queued**: the queued instance resolves
  (earned when raised); the source fires nothing afterwards (`Disarmed`).
- **If `once_per_turn` is raised twice in one step** ("whenever a minion dies, draw a card —
  once per turn" and two minions die together): one `trigger_queued`, one draw; the second raise
  is dropped silently (no event — nothing mutated).
- **If a `repeat` changes the board between iterations** ("deal 1 to a random enemy minion,
  3 times" and the first ping kills the only enemy minion): iteration 2 and 3 are `no_target`
  no-ops; `effect_resolved.ops` lists three entries so the player sees two pings went nowhere.
- **If a hero power's effect would act while the hero is Frozen**: Freeze blocks attacks only
  (match-rules C13); the hero power is usable and resolves normally. A hero power that *equips* a
  weapon still equips; the hero still cannot swing it this turn.
- **If the spell's own ops change Spell Damage mid-effect** ("summon a Spell Damage +1 minion,
  then deal 2 damage"): F1 re-reads `spell_damage(owner)` per op, so the second op deals 3. Legible
  because `spell_cast`'s payload shows the total at cast and `effect_resolved.values.requested`
  shows what each op used.
- **If a value expression yields a negative amount for `damage`/`heal`/`armor`/`draw`**: clamped
  to 0 and logged (`values.clamped_from`); `apply_damage(…, 0)` pops no shield (match-rules C9).
- **If a `counter.<key>` is read on a source that was never given one**: 0. Counters die with the
  source's `entity_id`; a bounced-and-replayed minion starts at 0.

**Choices**

- **If `discover` finds fewer than `DISCOVER_COUNT` candidates**: 2 → offer 2, 1 → offer 1 (the
  player still confirms), 0 → no Choice phase, op `empty_pool`, later ops run. Rationale: a forced
  single option is still shown so the player sees what they got (Pillar 4).
- **If `discover` with `pool: deck` runs on an empty deck**: `empty_pool`, no fatigue (nothing was
  drawn).
- **If the boss reaches a `discover` or `choose_one`**: `pending_choice.side = BOSS`; Boss AI
  must `choose`; the player's commands are `CHOICE_PENDING` (match-rules Edge Cases). The option
  list is emitted in `discover_offered` for the boss too; the UI may hide it (hidden information
  policy belongs to Match UI).
- **If the player concedes during a Choice**: the continuation is dropped; `match_ended(concede)`;
  no `discover_picked`.
- **If a Choose-One spell is cast with a `chosen` target and the target dies before `choose`
  returns**: impossible — nothing resolves between `discover_offered` and `choose` (the engine is
  paused in `Choice`); the target is live when the option runs.

**Hand, deck and resources**

- **If `draw` runs with an empty deck**: match-rules C11 fatigue per draw (1, 2, 3…); the op
  outcome is `fatigue` per copy. "Draw 2" with one card left → one card, one fatigue (match-rules
  AC-33).
- **If `add_to_hand` / `discover` / `copy_to_hand` / `return_to_hand` hits a full hand**: the
  engine burns the card (`card_burned`); op outcome `burned`. A Discover pick into a full hand is
  still a pick — the player is shown the burn.
- **If `mana` would exceed `MAX_MANA` or drop below 0**: the engine clamps (match-rules C5);
  `values.applied` shows the real delta.
- **If `equip` runs while a weapon is held**: the old weapon is destroyed first and its Deathrattle
  queues before anything else in this effect continues (match-rules C6).

**Hooks and passives**

- **If a `modify_cost` treasure sets the hero power to 0**: still once per turn
  (`HERO_POWER_USED`, match-rules Edge Cases).
- **If two value hooks disagree** (treasure "spells cost 1 less", passive "spells cost 1 more"):
  fold in installation order → net 0; the engine floors at 0 only at the end (F1).
- **If a boss passive is an event trigger whose scope is the player's action** ("whenever the
  player heals"): it resolves as a hook step immediately after the heal step, before any
  player-card `on_heal` observer (hooks first).
- **If a treasure effect uses `self`**: rejected at load (`E_FX_SELECTOR`); treasures are not
  entities on the board.

**Recursion and caps**

- **If card A's Deathrattle summons B whose Deathrattle summons A, and both die to the same
  "destroy all minions" effect each turn**: the loop is bounded by the board (each summon is one
  step and the board empties between deaths) and by `RESOLUTION_STEP_CAP`; a genuinely unbounded
  cycle ("Deathrattle: summon a copy of this and deal 1 to it") ends the match with
  `resolution_overflow`, boss wins (match-rules AC-30). The validator cannot see cycles across
  cards; `/balance-check` runs a cycle lint over `summon`/`retrigger` graphs (Open Questions).
- **If a single effect's static bound exceeds `EFFECT_STATIC_STEP_LIMIT`**: `E_FX_BUDGET` at load
  — never reaches play.
- **If the log would exceed `max_match_events` before the step cap**: rng-event-log's
  `log_overflow` → `match_ended(fault)`; at defaults this cannot precede the step cap (F6).

**Content and validation**

- **If a card lists `deathrattle` in `keywords[]` but has no `deathrattle` effect** (or vice
  versa): `W_FX_KEYWORD_MISMATCH`; load succeeds; the card frame may show a keyword that does
  nothing — Content fixes it.
- **If `summon` names a non-token collectible card**: allowed (Hearthstone does it); the summoned
  minion is a real instance of that card with its own effects (its Battlecry does not fire).
- **If an effect uses an op whose primitive is provisional** (`shuffle_into_deck`, `discard`,
  `weapon_durability`, `hero_power_refresh`, `remove_keyword`): `E_FX_OP_UNAVAILABLE`; the build
  fails rather than shipping a card that silently does nothing.
- **If a boss `passive` contains a play trigger** (`battlecry`): `E_FX_TRIGGER` — passives are
  never played.

## Dependencies

Hard = this system cannot resolve a single effect without it (or the dependent cannot function
without this system); soft = works with a null implementation. **Bidirectional check**
(`.claude/rules/design-docs.md`): `systems-index.md` lists Card Effects as depending on Match
Rules, Card Database and RNG & Event Log — consistent with the rows below; it names Card Effects
under *Depends On* for Boss AI, Heroes, Treasures, Match UI and Content (five rows; the index's
bottleneck note says "six dependents" — flagged for `/map-systems`, not edited here). Match-rules'
and card-database's Dependencies sections already list Card Effects as a dependent; rng-event-log
does too. Heroes, Treasures, Boss AI, Match UI and Content are undesigned, so their rows are the
contract this GDD proposes and they confirm.

| System | Direction | Hard/Soft | Nature of dependency / interface |
|---|---|---|---|
| Match Rules | This depends on Match Rules (and it calls back into this) | Hard | Trigger points and hook points (C2), the primitive API (C5), `MatchState` read access, the Choice phase and `choose` resumption, `recompute_auras()`, `RESOLUTION_STEP_CAP`. This supplies `resolve()`, `legal_targets()`, `targeting_spec()`. Five primitives requested (Interactions). |
| Card Database | This depends on Card Database | Hard | `effects[]`/`passive` payloads, `type`, `cost`, `spell_damage`; `has(id)`, `card(id)`, `collectible_pool()`, `cards_by_*` for pools (F4). This supplies the CR-5 stage 7 validator and the `E_FX_*` codes. No `targeting` field needed (C1 rule 1). |
| RNG & Event Log | This depends on RNG & Event Log (through the engine) | Hard | `match_<floor>` stream for F4/F5 draws (direct, no forks in v1 — Open Questions); event envelope with `cause_seq`; `max_match_events` backstop. This owns `effect_resolved.values`, `discover_*`, `counter_changed`. |
| Heroes | Heroes depends on this | Hard (for them) | Hero powers are `hero_power`-trigger effects in this DSL (DD-M13); War/Decay/Knowledge identities (DD-H01) rely on rows 1–25 of C11 being expressible. |
| Treasures | Treasures depends on this | Hard (for them) | Treasures and boss passives are effects on hook-bound triggers (C2, C9); ordering "hooks first, pick order, passive last". Treasures owns the pool and magnitudes. |
| Boss AI | Boss AI depends on this | Hard (for them) | `legal_targets()` for play enumeration; `ChoiceRequest.options` to answer Discover/Choose One; deterministic `resolve` on `clone()` for look-ahead. |
| Match UI | Match UI depends on this | Soft (engine runs headless) | `effect_resolved` as the playback unit; `discover_offered` for the panel; `targeting_spec` for highlights; `fizzled`/`outcome` reasons for feedback copy. |
| Content | Content depends on this | Hard (for them) | The schema and coverage table are what ~120 cards are authored against; anything in the v2 list is not authorable until this GDD changes. |
| Run Structure | Indirect | Soft | `EffectRuntime` travels inside `MatchState`; no direct interface in v1. |

## Tuning Knobs

`systems-designer` not consulted — Lean mode (knobs derived from the Formulas variable tables).
All knobs live in `assets/data/card_effects.json` (`schema_version` per DD-T01; a new data file,
flagged for DD-T01 in Open Questions) and are read once at `RulesEngine.start`. None of them is an
owner row in `design/design-decisions.md`; all are designer defaults.

| Parameter | Current value | Safe range | Effect of increase | Effect of decrease | Interacts with |
|---|---|---|---|---|---|
| `DISCOVER_COUNT` | 3 | 1–5 | More agency per Discover; Discover becomes the best draw effect; UI panel must fit 5 at 1280×720 | 1 = "add a random card" with a confirm click; weakens Knowledge's identity | F4, Match UI Discover panel, Content's Discover density |
| `DISCOVER_EXCLUDE_HAND` | `false` | `true`/`false` | `true`: never offers a card already held — fewer "dead" offers in a 40-card MVP pool but one more hidden rule for the player to learn | `false`: Hearthstone-faithful; occasional duplicate offers | F4, pool size (`collectible_pool_size`) |
| `MAX_OPS_PER_EFFECT` | 8 | 4–12 | Longer card texts possible; harder to read on a 150×210 frame (art bible slot layout) | Forces splitting into several effects; no gameplay change | C1, `EFFECT_STATIC_STEP_LIMIT` |
| `MAX_REPEAT` | 10 | 2–20 | Bigger "N times" cards; step bounds grow linearly | Caps multi-hit designs | F6 |
| `MAX_SUMMON_COUNT` | 7 | 1–7 | Must not exceed `BOARD_SIZE` (7); no effect above it | Caps token swarms (Decay) | `BOARD_SIZE` (match-rules) |
| `EFFECT_STATIC_STEP_LIMIT` | 250 | 50–1000 | Allows denser single effects; at 1000 one effect could alone hit `RESOLUTION_STEP_CAP` | Rejects legitimate wide-board loops ("deal 1 to all, 10 times" is 161) | F6, `RESOLUTION_STEP_CAP` |
| `SPELL_DAMAGE_DEFAULT` | `auto` | `auto`/`false` | n/a | `false`: every spell must opt in explicitly — safer for Content review, noisier JSON | F1, Content |
| `HOOKS_BEFORE_TRIGGERS` | `true` | `true` only | — | `false` is not designed: match-rules' Start/play procedures hard-order hooks first | C6.3, C9 |

Fixed by design, not knobs: aura recompute frequency is **every step** (match-rules C10 owns
`recompute_auras()`; a lower frequency would let a minion survive a step it should not and is the
exact ambiguity Pillar 4 forbids); random targeting includes Stealth (match-rules C12); ops
within an effect are independent (C6.4). Knobs owned elsewhere that move this system's outcomes
(do not duplicate): `RESOLUTION_STEP_CAP`, `MAX_MANA`, `HAND_SIZE`, `BOARD_SIZE` (match-rules);
`max_match_events` / `log_memory_budget_bytes` (rng-event-log); `min_collectible_pool`
(card-database); treasure magnitudes (Treasures); card numbers (Content).

## Visual/Audio Requirements

[To be designed]

## Game Feel

[To be designed]

## UI Requirements

[To be designed]

## Cross-References

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
