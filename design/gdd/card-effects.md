# Card Effects

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Review (revised after `/design-review` 2026-11-03; a re-review decides Approved)
> **Author**: `/design-system` (game-designer role) for the owner. `systems-designer`, `creative-director`, `qa-lead` and `art-director` not consulted — Lean mode (no `Agent` tool available in this run). Review manually before production.
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 4 (Readable, deterministic rules) primarily; Pillar 1 (Every run builds a deck you couldn't have planned) and Pillar 2 (Bosses are puzzles) secondarily
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` Feasibility: no engine reference for `scripting` under `docs/engine-reference/godot/modules/`; feasibility not checked against the pinned engine (this system is pure GDScript `RefCounted` logic over plain data, DD-T02). No numbered ADRs exist; `docs/architecture/modifier-hook-chain.md` (reverse-documented prototype hook chain) was read as context only.
> **Design decisions honoured**: DD-M09, DD-M11, DD-M13, DD-T01–DD-T04 (`design/design-decisions.md`); match-rules decisions C6, C10, C12, C13 and its primitive API; card-database CR-3/CR-5 stage 7; rng-event-log rules 7–12.
> **REVISED 2026-11-03** (`/design-review`, lean mode at workflow `full`, option A "revise now"): (1) **C6.0 step unit** — one effect pass is one C10 step; ops are not separated by death checks; *dying* entities are excluded from selectors and readable only by reference (`is_dying` predicate, C3); F6 and Edge Cases restate the caps in those units. (2) **C11 rows 8, 16, 25** rewritten to the Heroes GDD's actual powers (Whetstone, Rot, Insight) with registry token ids `war_whetstone_blade` / `decay_husk`; rows 44–46 added (boss hero power, counter Deathrattle, Husk sweep). (3) **C9** defines event triggers on treasure/passive hosts without a hook binding as hero-slot observers (Treasures R-10). (4) Content/Treasures requests answered: `adjacent` gains `of:`; `tag` applies to board minions (R-3); `owner.turns_taken` ref (R-6); `condition` on value triggers (R-2); `scope.card` kind rule (R-13); `aura` on weapons; `buff cost` on deck cards; counters in the raise-time snapshot; `target` ref defined. (5) AC-43–46 added; AC-01/13/15/34 re-pointed; stale "(undesigned)" labels removed; Open Questions updated.
> **REVISED 2026-11-03 (re-review, `/design-review` lean at workflow `full`)**: residual step-unit wording aligned to C6.0 (States `Resolving` row, Edge Cases recursion entry, AC-09 explicit log order, AC-16 one `trigger_resolved` between the hook step and row 34's pass and none between its two pings); `effect_resolved.ops[].outcome` closed set now carries `partial`, `fatigue`, `no_such_trigger` (already used by C5 / Edge Cases); C6.3 / C9 / Tuning Knobs state the End-step exception to "hooks first" (match-rules C4 End steps 2–3: card `turn_end` triggers, then `on_turn_end` hooks) and the minion-played row gains `on_card_played` observers in the spell row's position; `mana` op `this_turn` note corrected (Content's `decay_soul_tithe` uses it — Open Question to Match Rules); C8.1 Match UI overlay wording matches match-ui U3; AC-17 "Scarabs" → Husks; AC-37 names its replay fixture; `then: cast` targeting gap logged in Open Questions.
> **REVISED 2026-11-03 (cross-review)**: C-02 (`mana` op row: permanent `add_mana` at `on_match_start` raises `crystal_bonus`), C-04 (`targeting_spec` derived, confirmed by Match Rules), C-07 / DD-X04 (`discover_offered` ≠ `choice_requested`, pairing stated in C8 and Interactions), C-16 (a/b/c answered by Match Rules C4: card-instance expiry, recipient-controller expiry, player-side-first observer order — C6.3, F3, Edge Cases aligned), C-22 (five primitives landed in Match Rules: C5 rows, C10, C11, Edge Cases, AC-06, Interactions, Dependencies, Tuning Knobs de-provisionalised), C-25 (dependents count: five), V-35 housekeeping (Treasures rows closed via C-26). Open Questions rows closed accordingly.

## Summary

Card Effects is the data language every card, hero power, boss passive and treasure is written
in — a JSON effect of *trigger, condition, targets, operations* — and the resolver that runs those
effects through Match Rules' primitives in one defined order, with every random pick drawn from the
seeded match stream and every outcome written to the event log. For the player it is the card text
kept exactly: Battlecries, Deathrattle chains, auras, Discover picks and boss passives that resolve
visibly and predictably. It exists because ~120 cards, 16 bosses and 20 treasures must be authored
as data rather than code, and because the game's promise of readable, deterministic rules
(Pillar 4) depends on one engine resolving all of them the same way.

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
| `condition` | no | expression | C4. Evaluated once, when the effect starts resolving (not when queued). False → the effect resolves as `fizzled: condition_false` with no ops run. On a **value trigger** (C2) it is evaluated on every fold call, so "the first card you play each turn costs (1) less" reads `owner.cards_played_this_turn` at each F1 evaluation (Treasures R-2); a false condition leaves `context.value` unchanged. |
| `targets` | no | selector | C3. Default target set for ops that need one; an op may override with its own `targets`. |
| `ops` | yes | op[] | 1–`MAX_OPS_PER_EFFECT` (8) operations, C5, run in order. |
| `once_per_turn` | no | bool | Default `false`. When true the effect resolves at most once per global `turn` per source entity (C6.7). |

Rules of the shape:

1. **One `chosen` per play.** A host may contain at most one effect whose trigger is a *play
   trigger* (`battlecry`, `cast`, `hero_power`) and whose effect-level `targets` is `chosen`;
   that selector, with its `filter`, **is the card's targeting spec**. The validator derives
   `targeting_spec(def_id) = {mode, filter}` from it — `mode = required` when the `chosen`
   selector has no `optional: true`, `optional` when it does, `none` when there is no `chosen` —
   and exposes it to Match Rules (C6 validation calls `targeting_spec(def_id)` and reads its
   `mode`). Card Database stores no `targeting` field (CR-3 rejects unknown fields); this
   derivation is the decision that keeps one source of truth (confirmed by Match Rules'
   Dependencies row, cross-review C-04: targeting is derived here, never stored). `chosen` is illegal on any non-play trigger (`E_FX_CHOSEN`).
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
| `modify_cost` | value | — | `modify_cost` | `card: filter` (side, type, cost, `has_trigger`, `kind`). `card` **without** `kind` matches card instances only; `kind: hero_power` matches the hero power only; `kind: any` both (Treasures R-13) | treasure, passive | `context.card`, `context.value` |
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
"Hosts" column fails validation (`E_FX_TRIGGER`). An event trigger whose Hosts column admits
treasure/passive but whose hook column is `—` (`on_play`, `on_summon`, `after_cast`, `on_attack`,
`on_damage_dealt`, `on_heal`, `on_minion_died`, `on_hero_power`, `on_weapon_equipped`, and
`on_damage_taken` with a non-hero `who`) is legal on those hosts and runs as a **hero-slot
observer** (C9), not as a hook step.

#### C3. Target selectors and the filter grammar

A selector is either a bare string (defaults) or `{ "selector": name, "filter": {…}, "n": int,
"optional": bool }`. Selection is evaluated **when the op runs** (not when the effect was queued),
against the live board, in **canonical order**: player board left to right, boss board left to
right, player hero, boss hero, then weapons, then hand/deck positions. Random selectors draw from
that ordered list (F5). "Friendly"/"enemy" are relative to the effect **owner**. Selectors never
yield a **dying** entity — one with `health ≤ 0` or `pending_destroy` that the death check after
this pass will remove (C6.0); a dying entity is reachable only through an explicit reference
(`self`, `target`, `trigger_subject`, `trigger_source`) and is what the `is_dying` predicate tests.

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
| `adjacent` / `left_neighbour` / `right_neighbour` | board neighbours of `of` — `self` (default), `target` (the `chosen` entity) or `trigger_subject` | `{"selector": "adjacent", "of": "target"}` is "a minion and the minions next to it" (the `chosen` op first, the `adjacent` op second). Empty at the board edge or when `of` is not a minion in play; `of: self` on a non-minion host is `E_FX_SELECTOR`. |
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
| `is_dying` | bool — `health ≤ 0` or `pending_destroy`, true only between a lethal op and the death check that follows the pass (C6.0); a popped Divine Shield leaves `health` unchanged, so it stays `false` | characters, via `test` on a reference (selectors never yield dying entities) |
| `attack_le`, `attack_ge`, `health_le`, `health_ge`, `cost_le`, `cost_ge`, `cost_eq` | int or value expression | characters (`cost` = definition cost), cards |
| `type` | `minion \| spell \| weapon` | cards, pools |
| `set`, `tag`, `rarity` | Card Database enum values | cards, pools; `tag` and `set` also apply to minions on the board, reading the definition's `tags` / `set` ("your Husks", Treasures R-3) |
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
spells_cast_this_turn|weapon_attack|weapon_durability|fatigue_counter|turns_taken`,
`opponent.<same>`, `context.amount` (damage/heal amount for `on_damage_*`/`on_heal`),
`context.value` (value triggers), `counter.<key>` (C5 `add_counter`), `match.turn`. `source.*`
and `counter.*` read live values while the source is in play and the raise-time snapshot
afterwards (C6.5), so a Deathrattle can count what its minion saw. `owner.turns_taken` is
match-rules' `PlayerState.turns_taken` ("at the start of your 2nd turn" without depending on
DD-M03's turn order; Treasures R-6). **`target`** is the entity the effect's `chosen` selector
supplied (`E_FX_REF_PATH` under a trigger without `chosen`; the no-op case is `fizzled` /
`no_target` before any ref is read); an op's own `targets` override does **not** rebind it, so
"Destroy a friendly minion. Gain Mana Crystals this turn equal to its Cost" reads `target.cost`
from a `mana` op aimed at `owner`. A per-target ref inside a multi-target op ("deal damage equal
to each minion's Attack to it") is not in v1 (C11 v2 list).

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
| `buff` | `attack`, `health` (values, may be negative), `cost` (card instances only), `keywords[]`, `duration: permanent\|until_end_of_turn` | characters, weapons (attack only), card instances in hand **or deck** (`cost` only; the enchantment travels with the instance, so `buff cost` on `deck_top` followed by `draw` is "Draw a card. It costs (N) more/less", row 25) | `apply_enchantment(target, {attack_delta, health_delta, cost_delta, keywords_added, expires})` | no-op `no_target`; `health < 0` that leaves `health ≤ 0` kills in the next death check (F3) |
| `set_stats` | `attack`, `health` (values; either may be absent) | minions | `set_stats(target, attack, health)` | no-op `no_target`. "Swap Attack and Health" is `set_stats` with `attack: {ref: target.health}, health: {ref: target.attack}` — both refs read before the write |
| `give_keyword` | `keyword` (DD-M09 id, not `battlecry/deathrattle/discover/aura/silence/freeze`) | characters, weapons | `add_keyword` (an enchantment with `keywords_added`) | no-op; granting a keyword already held is a no-op `already_has` |
| `remove_keyword` | `keyword` | characters | `remove_keyword(target, kw)` (match-rules Interactions, added 2026-11-03; emits `keyword_removed`; removing Taunt/Stealth/Divine Shield takes effect at the next legality or damage evaluation) | no-op `no_target`; removing a keyword the target does not hold is a no-op `skipped` |
| `silence` | — | minions | `silence` | no-op `no_target` |
| `freeze` | — | characters | `freeze` | no-op; re-freezing re-stamps (match-rules C13) |
| `destroy` | — | minions, weapons | `destroy` (sets `pending_destroy`; dies in the next death check, so Deathrattles fire) | no-op `no_target` |
| `summon` | `card_id`, `count` (value, 1–`MAX_SUMMON_COUNT`), `position: source_slot\|right_of_source\|end\|chosen_slot` (default `source_slot` for deathrattles, `right_of_source` otherwise; when the source is not a minion in play — spell, hero power, weapon, treasure/passive — both resolve to `end`, so Raise Dead and Rot fill from the right), `side: owner\|opponent` | — (side-scoped) | `summon_minion(side, def_id, position)` × count, left to right | Board full → the engine emits `summon_failed{board_full}` per failed copy; the op continues with the remaining count (each is its own call) |
| `transform` | `card_id` | minions | `transform(target, def_id)` — new `entity_id`, no summoning-sickness reset, enchantments dropped, Battlecry does **not** fire | no-op `no_target`; a transformed source's remaining ops that reference `self` resolve against the new entity (C6.5) |
| `draw` | `count` (value), `side` (default owner) | — | `draw(side, 1)` × count (fatigue/burn per match-rules C11) | Never fails; empty deck → fatigue, full hand → burn, both engine-logged |
| `discover` | `pool: collectible\|list\|deck\|hand`, `list: [card_ids]`, `filter`, `count` (default `DISCOVER_COUNT` 3), `then: add_to_hand\|summon\|cast` (default `add_to_hand`) | — (side-scoped) | `discover(side, options) → ChoiceRequest` (match-rules Choice phase); on `choose`, `add_card_to_hand` / `summon_minion` / resolve the card's `cast` effect | 0 candidates → no-op `empty_pool`, no Choice; 1–2 candidates → offer that many (F4) |
| `add_to_hand` | `card_id` **or** `from: {pool, filter}` (random, F4 pick of 1), `count`, `side` | — | `add_card_to_hand(side, def_id)` × count | Full hand → engine burns (`card_burned`), op outcome `burned` |
| `copy_to_hand` | `count`, `side` | characters (minions), hand/deck cards | `add_card_to_hand(side, target.def_id)` — a copy is the **definition**, never the instance: enchantments, damage and temporary buffs are not copied | no-op `no_target` |
| `return_to_hand` | — | minions | `return_to_hand` (becomes a fresh card instance of its `def_id`; full hand → burned by the engine) | no-op `no_target` |
| `shuffle_into_deck` | `card_id` or `targets` (hand cards / minions), `count`, `position: random\|top\|bottom` | hand cards, minions, or none | `add_card_to_deck(side, def_id, position)` (match-rules Interactions, added 2026-11-03; emits `card_added_to_deck`; `random` draws one `match_<floor>` index — counted in F5) | A targeted instance that left play is skipped (`no_target`); `card_id` form never fails |
| `discard` | `count`, `random: true` (v1 only random), `side` | — | `discard(side, random)` × count (match-rules Interactions, added 2026-11-03; emits `card_discarded`; each random pick draws from `match_<floor>`, F5) | Empty hand → no-op `no_target` |
| `mana` | `amount` (±), `duration: this_turn\|permanent` | — (side) | `add_mana(side, n, temporary)` with `temporary = (duration == this_turn)`; clamps to `MAX_MANA` and ≥ 0 (match-rules C5). `permanent` under `on_match_start` (treasure/passive hosts) raises that side's `crystal_bonus`, which match-rules C4 step 2 / F4 read every Start step (Hollow Crown, Treasures R-1, cross-review C-02); `this_turn` (`temporary=true`) grants `n` **temporary crystals** (match-rules C5: `mana_max` and `mana_current` both rise by `n`, clamped to `MAX_MANA`, `mana_added{temporary: true}`; they expire at that side's End step 5 alongside `end_of_turn` enchantments and the next Start-step refill ignores them) — used by Content's `decay_soul_tithe` ("Gain Mana Crystals this turn equal to its Cost", the C4 `target.cost` example) and `neutral_treasure_map` | Never fails; clamped delta logged |
| `armor` | `amount` | — (side) | `apply_armor` | Never fails |
| `equip` | `card_id` (a weapon def) | — (side) | `equip_weapon(side, def_id)` (old weapon destroyed first, match-rules C6) | Never fails |
| `weapon_durability` | `amount` (±) | weapons | `modify_durability(weapon, delta)` (match-rules Interactions, added 2026-11-03; emits `weapon_durability_changed`; a weapon at ≤ 0 breaks in the next death check) | no-op `no_target` (no weapon equipped) |
| `hero_power_refresh` | — | — (side) | `refresh_hero_power(side)` (match-rules Interactions, added 2026-11-03; emits `hero_power_refreshed`; sets `used_this_turn = false`, no mana refund) | Never fails; refreshing a power not yet used this turn is a no-op `skipped` |
| `retrigger` | `trigger: deathrattle` (v1 allows only `deathrattle`) | minions, weapons | Queues the target's live effects with that trigger as if raised now (`trigger_queued{reason: retrigger}`) | no-op `no_target` or `no_such_trigger` |
| `add_counter` / `set_counter` | `key`, `amount` / `value` | — (source-scoped) | Resolver-owned `EffectRuntime.counters[source_id][key]`; emits `counter_changed` | Never fails; counters live as long as the source's `entity_id` (a treasure/passive id never expires) and are copied into the raise-time snapshot (C6.5), so the source's own queued Deathrattle still reads them |
| `conditional` | `if` (condition), `then: op[]`, `else: op[]` | per inner op | — | The branch not taken is logged as `skipped`; inner ops obey their own semantics |
| `repeat` | `times` (value, 1–`MAX_REPEAT` 10), `ops: op[]` | per inner op | — | Each iteration re-evaluates selectors against the live board (so "deal 1 damage to a random enemy, 3 times" can hit three different or the same target) |
| `choose_one` | `options: [{label_key, ops: op[]}]` (2–4) | per inner op | `discover(side, options)` with `kind: choose_one` → Choice phase; the picked option's ops run | Boss AI picks for the boss; a `chosen` inside an option is illegal (`E_FX_CHOSEN`) — Choose-One cards with targets declare the `chosen` at effect level and both options use it |
| `aura` | `attack`, `health`, `cost`, `keywords[]` | per the effect's `targets` (static, C7): characters, weapons (`attack` only — "your weapons have +1 Attack" on `owner_weapon`), hand cards (`cost` only), as for `buff` | `apply_enchantment(…, is_aura: true)` inside `recompute_auras()` | Only legal under trigger `aura` / `passive_hand` (`E_FX_OP`) |
| `modify_value` | exactly one of `delta` (value), `set` (value), `mul` (int ≥ 0) | — | Returns `context.value` transformed; the engine clamps per its formula | Only legal under value triggers; any other op there is `E_FX_OP` |

#### C6. Resolution

0. **Step unit.** One effect pass (C6.4) is **one C10 step**; each primitive call inside it is
   one *mutation* with one event. The engine's loop — death check, `recompute_auras()`, queue
   pop — runs **after** the pass, never between ops. A minion killed by op 1 is therefore still
   in play with `health ≤ 0` (or `pending_destroy`) while op 2 runs: it is **dying** — excluded
   from every selector (C3), readable through `self`/`target`/`trigger_subject` refs and the
   `is_dying` predicate, and removed by the death check that follows the pass. Deathrattles and
   observers raised during the pass resolve after it, in queue order, each as its own step. A
   hook-hosted effect is likewise one step (C9). This is match-rules C6 step 3 ("the minion's
   Battlecry … as its own step") and C10's `execute(t)` read literally; `RESOLUTION_STEP_CAP`
   counts passes, F6's static bound counts mutations per pass.
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
3. **Resolution order table** — the single table a player or tester needs. Hooks run before
   card triggers at the same point wherever match-rules places them so (match start, Start step,
   play, damage, heal, draw); the **End step is the one exception** — match-rules C4 End steps
   2–3 fire card `turn_end` triggers first, then `on_turn_end` hooks — and this table, not the
   shorthand "hooks first", is what a test asserts. Each numbered item is its own step with the
   full C10 loop after it:

   | Engine point | Order |
   |---|---|
   | Minion / weapon played | 1 host `battlecry` → 2 hooks `on_card_played` (treasures, then passive) → 3 observers `on_card_played` (minion/weapon scope, as in the spell row) → 4 observers `on_play` → 5 hook `on_minion_summoned` → 6 observers `on_summon` (`on_weapon_equipped` for weapons) |
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

   **Observer candidate order**: one order for every trigger point, **including**
   `turn_start`/`turn_end` — player board left to right, player weapon, player hero power/hero
   enchantments, then the boss side in the same per-side order, regardless of whose turn it is
   (match-rules C4 step 5 and C10, unified by cross-review C-16c on 2026-11-03; an "at the start
   of your opponent's turn" effect on the boss side is simply a boss-side candidate). Within one
   entity, `effects[]` index order, definition effects before enchantment-granted ones. Among
   hooks: installation order.
4. **One effect, one pass.** Resolving an effect: evaluate `condition` → for each op in order:
   resolve its selector against the live board, run the primitive per target in canonical order,
   record `{op, targets, values, outcome}` → emit `effect_resolved`. Ops are independent: an op
   with no targets is a no-op and the next op still runs. Content that needs "only if the first
   part happened" writes a `conditional`.
5. **Snapshot and liveness.** When an event trigger is queued the resolver stores
   `{source_id, def_id, owner, attack, health, max_health, board_index, keywords, counters}`. A queued
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
   `discover_offered` when the `ChoiceRequest` is raised and `discover_picked` when resumed;
   these are this GDD's events and are distinct from Match Rules' `choice_requested` /
   `choice_made` phase events (DD-X04, C8.1).
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
    (1000 steps = passes, C6.0 → `resolution_overflow`, boss wins) is the authority, and
    rng-event-log's `max_match_events` (10,000) is the backstop. What this GDD adds is
    **static**: the validator computes each effect's worst-case **mutation** bound (F6) and
    rejects content that could exceed `EFFECT_STATIC_STEP_LIMIT` (250) in one pass, so no single
    pass can flood the log, and an infinite loop can only come from a *cycle* between cards (A
    summons B whose Deathrattle summons A), which the step cap catches.

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
   remaining ops}` in `EffectRuntime.pending_choice`. No RNG is drawn while waiting. Two
   distinct events mark the pause (DD-X04): Match Rules emits `choice_requested` when the engine
   enters `Choice` (its C15 spelling), and this GDD emits `discover_offered` carrying the options
   (`option_card_ids[]` / `option_label_keys[]`); on resume, `choice_made` (Match Rules) and
   `discover_picked` (this GDD) pair the same way. Match UI opens its Choice overlay once both of
   the pair are projected, whichever the engine emits second (match-ui U3); the options ride on
   `discover_offered`.
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
triggers at the same point" true at the Start step and the play points — the End step is the
exception, where match-rules fires card `turn_end` triggers before `on_turn_end` hooks (C6.3).
A hook-hosted **value** trigger is a fold: installation order,
each sees the previous one's output, engine clamps afterwards (F1: floor 0; F2: floor 0). The
`source_id` in every event they emit is the treasure or passive id, so the event feed can name the
treasure as the cause (Pillar 2: passives bend rules visibly). Treasures own *which* hooks exist in
their pool and their magnitudes (Treasures GDD); this GDD owns the fact that they are written in
this DSL and resolve in this order.

**Event triggers without a hook binding** (C2: hook column `—`, Hosts admits treasure/passive —
`on_play`, `on_summon`, `after_cast`, `on_attack`, `on_damage_dealt`, `on_heal`,
`on_minion_died`, `on_hero_power`, `on_weapon_equipped`, and `on_damage_taken` with a non-hero
`who`) run as **observers hosted on the owner's hero slot**: queued like a card trigger when the
engine fires the trigger point, in the candidate order's "hero power / hero enchantments"
position for that side (C6.3), i.e. after the hook steps at that point and after that side's
board and weapon observers. This is Treasures T2.5 / R-10, confirmed; Grave Tithe ("whenever a
friendly minion dies, summon a Husk — once per turn") and boss passives such as "whenever the
player plays a minion" or "whenever the boss's hero attacks" are this shape. A treasure or
passive is always a **live source** while installed — never Silenced, never leaves play — and its
source `entity_id` for `once_per_turn` marks (C6.7) and counters (C5) is the treasure or passive
id.

#### C10. Schema validation (Card Database CR-5 stage 7)

The resolver ships `validate_effects(host_kind, host_id, effects[]) → report[]`, injected into the
Card Database at composition time. Each error is `{code, host_id, effect_id, path, message}` and
is merged by Card Database with severity `E_DELEGATED` (its CR-5). Closed code set:

| Code | Raised when |
|---|---|
| `E_FX_SCHEMA` | Missing/extra field, wrong type, `ops` empty or > `MAX_OPS_PER_EFFECT`, `id` duplicate within host |
| `E_FX_TRIGGER` | Unknown trigger, or trigger not legal for this host kind (C2 Hosts), or unknown `scope` key |
| `E_FX_SELECTOR` / `E_FX_FILTER` | Unknown selector / predicate; `self` on a treasure; `adjacent` with `of: self` on a non-minion host; `of: target` under a trigger without `chosen` |
| `E_FX_OP` | Unknown op; op illegal under this trigger class (`aura` outside static, non-`modify_value` under a value trigger); param out of range |
| `E_FX_OP_TARGET` | Op applied to a selector that can never yield a legal kind (e.g. `freeze` on `hand`) |
| `E_FX_OP_UNAVAILABLE` | Op whose primitive match-rules does not expose. **No v1 op raises it** since the five primitives landed in match-rules Interactions on 2026-11-03 (cross-review C-22); the code stays in the closed set for future ops added here before their primitive exists |
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
| 8 | War hero power (Heroes H-3) | Whetstone: Equip a 1/2 Whetstone Blade. If you already have a weapon, give it +1 Attack this turn instead. | `{"trigger":"hero_power","ops":[{"op":"conditional","if":{"exists":"owner_weapon"},"then":[{"op":"buff","targets":"owner_weapon","attack":1,"duration":"until_end_of_turn"}],"else":[{"op":"equip","card_id":"war_whetstone_blade"}]}]}` (Heroes' sketch vocabulary maps 1:1 — `branch` → `conditional`, `has_weapon` → `exists owner_weapon`, `enchant` → `buff`, `equip_weapon` → `equip`; no `targeting` field, C1 rule 1) |
| 9 | Decay minion | Deathrattle: Summon two 1/1 Husks. | `{"trigger":"deathrattle","ops":[{"op":"summon","card_id":"decay_husk","count":2,"position":"source_slot"}]}` |
| 10 | Decay minion | Battlecry: Destroy a friendly minion. Draw 2 cards. | `{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"destroy"},{"op":"draw","count":2}]}` (no friendly minion → Battlecry does not resolve, no draw) |
| 11 | Decay minion | Whenever a friendly minion dies, gain +1/+1. | `{"trigger":"on_minion_died","scope":{"who":"friendly_minion"},"targets":"self","ops":[{"op":"buff","attack":1,"health":1}]}` |
| 12 | Decay minion | Deathrattle: Deal damage equal to this minion's Attack to the enemy hero. | `{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"source.attack"}}]}` (snapshot, C6.5) |
| 13 | Decay minion | Poisonous. Deathrattle: Add a random Decay card to your hand. | `{"trigger":"deathrattle","ops":[{"op":"add_to_hand","from":{"pool":"collectible","filter":{"set":"decay"}},"count":1}]}` |
| 14 | Decay spell | Trigger a friendly minion's Deathrattle. | `{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly","has_trigger":"deathrattle"}},"ops":[{"op":"retrigger","trigger":"deathrattle"}]}` |
| 15 | Decay spell | Give a minion +2/+2 and Taunt. If it has a Deathrattle, +4/+4 instead. | `{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"conditional","if":{"test":["target",{"has_trigger":"deathrattle"}]},"then":[{"op":"buff","attack":4,"health":4}],"else":[{"op":"buff","attack":2,"health":2}]},{"op":"give_keyword","keyword":"taunt"}]}` |
| 16 | Decay hero power (Heroes H-3) | Rot: Deal 1 damage to a minion. If it dies, summon a 1/1 Husk. | `{"trigger":"hero_power","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"damage","amount":1},{"op":"conditional","if":{"test":["target",{"is_dying":true}]},"then":[{"op":"summon","card_id":"decay_husk","position":"end"}]}]}` (Heroes' `left_play` is `is_dying`, read after the damage and before the pass's death check, C6.0 — so the Husk is summoned *before* the target's Deathrattle resolves; a popped Divine Shield leaves `health` unchanged → no Husk; unusable with both boards empty — spell rule) |
| 17 | Knowledge minion | Spell Damage +1. | `keywords:["spell_damage"], spell_damage: 1, effects: []` |
| 18 | Knowledge spell | Deal 3 damage. | `{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"damage","amount":3}]}` (scales by F1) |
| 19 | Knowledge spell | Deal 2 damage to all enemies. | `{"trigger":"cast","targets":"all_enemy_characters","ops":[{"op":"damage","amount":2}]}` |
| 20 | Knowledge spell | Discover a spell. | `{"trigger":"cast","ops":[{"op":"discover","pool":"collectible","filter":{"type":"spell"}}]}` |
| 21 | Knowledge minion | Whenever you cast a spell, draw a card. | `{"trigger":"on_card_played","scope":{"by":"owner","card":{"type":"spell"}},"ops":[{"op":"draw","count":1}]}` |
| 22 | Knowledge minion | At the end of your turn, if you have 5 or more cards, deal 3 damage to a random enemy. | `{"trigger":"turn_end","scope":{"side":"owner"},"condition":{"cmp":[{"ref":"owner.hand_size"},">=",5]},"targets":{"selector":"random_enemy_character"},"ops":[{"op":"damage","amount":3,"spell_damage":false}]}` |
| 23 | Knowledge spell | Freeze an enemy minion. If it was already Frozen, destroy it. | `{"trigger":"cast","targets":{"selector":"chosen","filter":{"kind":"minion","side":"enemy"}},"ops":[{"op":"conditional","if":{"test":["target",{"is_frozen":true}]},"then":[{"op":"destroy"}],"else":[{"op":"freeze"}]}]}` |
| 24 | Knowledge minion | Your spells cost (1) less. | `{"trigger":"aura","scope":{"zone":"hand"},"targets":{"selector":"hand","filter":{"type":"spell"}},"ops":[{"op":"aura","cost":-1}]}` |
| 25 | Knowledge hero power (Heroes H-3) | Insight: Draw a card. It costs (1) more this turn. | `{"trigger":"hero_power","ops":[{"op":"buff","targets":{"selector":"deck_top","n":1},"cost":1,"duration":"until_end_of_turn"},{"op":"draw","count":1}]}` (Heroes' `bind`/`$drawn` is not needed: the card about to be drawn *is* `deck_top`, and a cost enchantment travels with the instance into hand, C5; empty deck → `ops[0]: no_target`, then fatigue) |
| 26 | Neutral minion | Your other minions have +1/+1. (aura lord) | `{"trigger":"aura","targets":{"selector":"all_friendly_minions","filter":{"not_self":true}},"ops":[{"op":"aura","attack":1,"health":1}]}` |
| 27 | Neutral minion | Adjacent minions have +2 Attack. | `{"trigger":"aura","targets":"adjacent","ops":[{"op":"aura","attack":2}]}` |
| 28 | Neutral minion | Taunt. Divine Shield. (taunt wall) | `keywords:["taunt","divine_shield"], effects: []` |
| 29 | Neutral minion | Battlecry: Silence a minion. | `{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion"}},"ops":[{"op":"silence"}]}` |
| 30 | Neutral minion | Battlecry: Return a friendly minion to your hand. | `{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"friendly"}},"ops":[{"op":"return_to_hand"}]}` |
| 31 | Neutral minion | Battlecry: Transform an enemy minion into a 1/1 Sheep. | `{"trigger":"battlecry","targets":{"selector":"chosen","filter":{"kind":"minion","side":"enemy"}},"ops":[{"op":"transform","card_id":"neutral_sheep"}]}` |
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
| 44 | Boss hero power | Brand: Deal 1 damage. | `{"trigger":"hero_power","targets":{"selector":"chosen","filter":{"kind":"any"}},"ops":[{"op":"damage","amount":1}]}` (host is not a spell → no Spell Damage, F1) |
| 45 | Neutral minion | Deathrattle: Deal 1 damage to the enemy hero for each minion that died while this was in play. | `{"trigger":"on_minion_died","scope":{"who":"any_minion"},"ops":[{"op":"add_counter","key":"seen","amount":1}]}`, `{"trigger":"deathrattle","targets":"enemy_hero","ops":[{"op":"damage","amount":{"ref":"counter.seen"}}]}` (the Deathrattle reads the counter from its raise-time snapshot, C6.5) |
| 46 | Decay spell | Destroy all your Husks. Deal 1 damage to all enemies for each. | `{"trigger":"cast","ops":[{"op":"set_counter","key":"n","value":{"count":{"selector":"all_friendly_minions","filter":{"tag":"husk"}}}},{"op":"destroy","targets":{"selector":"all_friendly_minions","filter":{"tag":"husk"}}},{"op":"damage","targets":"all_enemy_characters","amount":{"ref":"counter.n"}}]}` (`tag` on board minions, C3; the spell's counter lives on the resolving card instance) |

Coverage verdict: every archetype the brief names (weapon buffs, deathrattle summons,
sacrifice-for-value, spell damage, draw engines, discover, taunt walls, aura lords, conditional
battlecries, random pings, Choose One, transforms, boss passives, cost/damage/attack-count hooks)
is expressible with v1 ops and primitives. Rows 8, 16 and 25 are the three launch hero powers
**as Heroes H-3 words them** (prose binding there; `hero_war/decay/knowledge.hero_power` in the
registry), and each row names how Heroes' provisional sketch vocabulary maps onto v1 ops — no
`branch`, `left_play`, `bind` or `enchant_card` primitives are added. Rows 1, 7 and 8 need only
`attack` on weapons; a "+1 Durability" text uses the `weapon_durability` op (primitive
`modify_durability`, in match-rules since 2026-11-03).

**v2 — deliberately not expressible in v1** (each needs either a new match-rules primitive, a new
keyword under DD-M09, or UI the MVP does not have; a card needing one is a GDD change here first):

| Text pattern | Why not v1 | Needs |
|---|---|---|
| ~~"+N Durability", "shuffle X into your deck", "discard", "refresh your hero power", "remove Taunt from"~~ — **moved to v1 on 2026-11-03** (cross-review C-22): primitives `modify_durability`, `add_card_to_deck`, `discard`, `refresh_hero_power`, `remove_keyword` are in match-rules Interactions; ops `weapon_durability`, `shuffle_into_deck`, `discard`, `hero_power_refresh`, `remove_keyword` (C5). "Destroy your weapon" is `destroy` on `owner_weapon` (already v1) | — | — |
| Secrets ("when the enemy attacks, …" hidden until it fires) | Hidden triggered cards in a secret zone; anti-Pillar 4 unless telegraphed | New zone + keyword + UI |
| Quests / multi-turn progress with a hand display | Counters exist (C5) but the UI to show progress does not | Match UI work; a `quest` keyword |
| "Your Battlecries trigger twice", "Deathrattles trigger twice" | A trigger-count modifier over other cards' effects | `modify_trigger_count` value trigger (v2 candidate) |
| "Cast a copy of the last spell you cast", "repeat all spells cast this turn" | History queries beyond per-turn tallies | A spell-history ref set |
| "Deal damage to each minion equal to its own Attack" (per-target value inside one multi-target op) | `target` is the `chosen` entity only (C4) | A `current` ref bound per iteration of a multi-target op |
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
| `Resolving` | Popped, or a play trigger starts | Last op done → `Resolved`; `condition` false → `Fizzled`; `discover`/`choose_one` reached → `AwaitingChoice`; step cap hit → `Aborted` | Runs ops in order through primitives; each primitive call is one **mutation**, the whole pass is the one step (C6.0) |
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
           outcome: applied | partial | no_target | board_full | burned | fatigue | empty_pool
                  | skipped | already_has | no_such_trigger } ]   # closed set; C5 and Edge Cases use no other
}
```

`operation` in the catalogue row is the first op's name (kept for grep compatibility); the full
list is `ops[]`. `discover_offered {side, source_id, effect_id, kind: discover|choose_one,
option_card_ids[] | option_label_keys[]}` and `discover_picked {side, picked_index,
picked_card_id | picked_label_key}` are as catalogued. **Pairing (DD-X04)**: `discover_offered`
and `discover_picked` are Card Effects' events; `choice_requested` and `choice_made` are Match
Rules' phase events (its C15 spelling is authoritative for match events). They are four distinct
events, not aliases: on every Discover / Choose One the log shows `choice_requested` (engine
enters `Choice`) then `discover_offered` (options), and on resume `choice_made` then
`discover_picked`, all under one `cause_seq`. `counter_changed {source_id, key, value}` is new
and owned here. Event names elsewhere in this GDD use Match Rules' spellings (`healed`,
`weapon_destroyed`, `trigger_resolved`, `enchantment_applied`); RNG & Event Log's catalogue
mirrors them.

**Primitives added to Match Rules' API on 2026-11-03 for this GDD**: `remove_keyword(target,
kw)`, `add_card_to_deck(side, def_id, position)`, `modify_durability(weapon, delta)`,
`refresh_hero_power(side)`, `discard(side, hand_index | random)` (match-rules Interactions,
with their events `keyword_removed`, `card_added_to_deck`, `weapon_durability_changed`,
`hero_power_refreshed`, `card_discarded`). Their ops (`remove_keyword`, `shuffle_into_deck`,
`weapon_durability`, `hero_power_refresh`, `discard`) are no longer validator-blocked.

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
| expires | enum | `null \| end_of_turn` | data file (`duration`) | Removed by match-rules C4 End step 5 of the **recipient's controller** (the engine's rule, confirmed intended — cross-review C-16b; see Edge Cases for the enemy-side consequence). Recipients include card instances in hand or deck (`cost` enchantments, rows 25 and 41): match-rules step 5 names "every entity owned by S, including card instances in S's hand and deck" (cross-review C-16a) |
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

The `effect_step_bound` formula bounds the **mutations (primitive calls) in one pass** — the
name is kept for the registry; the C10 step is the pass itself (C6.0). It is defined as:

`effect_step_bound = 1 + Σ_{op ∈ ops} steps(op)` where
`steps(op) = max_targets(op.targets) × count(op)` for leaf ops (`count(op)` = the op's `count`,
1 when absent), `steps(repeat) = times × Σ steps(inner)`, `steps(conditional) = max(Σ then, Σ
else)`, `steps(choose_one) = max over options`, `max_targets(all_*) = 16`,
`max_targets(single) = 1`, `max_targets(adjacent) = 2`, `max_targets(hand) = 10`,
`max_targets(random, n) = n`, `max_targets(side-scoped) = 1`. A non-literal `count`, `n` or
`times` (a value expression, e.g. Raise Dead's `count: {ref: owner.minions_died_this_turn}`) is
taken at its ceiling: `MAX_SUMMON_COUNT` for `summon`, `MAX_REPEAT` for `repeat`, `HAND_SIZE`
(10) otherwise.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| MAX_OPS_PER_EFFECT | int | 4–12 | data file (default 8) | Ops per effect |
| MAX_REPEAT | int | 2–20 | data file (default 10) | `times` ceiling |
| MAX_SUMMON_COUNT | int | 1–7 | data file (default 7) | `count` ceiling (= `BOARD_SIZE`) |
| EFFECT_STATIC_STEP_LIMIT | int | 50–1000 | data file (default 250) | Validator rejects an effect whose bound exceeds it (`E_FX_BUDGET`) |
| RESOLUTION_STEP_CAP | int | 200–5000 | match-rules data file (1000) | Runtime authority, counted in **passes** (C6.0); owned by match-rules |
| max_match_events | int | 2,500–100,000 | rng-event-log (10,000 at defaults) | Log cap; ≈ 1 event per mutation plus the step's own events. A typical pass is 1–3 mutations, so 1000 passes ≈ 2,000–4,000 events; only a chain of passes near the 250 limit trips this cap before the step cap (Edge Cases) |

**Output Range:** a typical card is 1–3 mutations; the worst legal single pass is 250. The step
cap and the log cap are in different units, and whichever trips first ends the match with its
own reason (`resolution_overflow` / `log_overflow`); in practice only a **cycle** between cards
reaches either, which is the content bug both are meant to surface. **Example:** row 34
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
  its neighbours" (`chosen`, then `adjacent` with `of: target`) whose target had no neighbours
  deals the 2 and logs `adjacent: no_target`.
- **If `random_*` asks for `n` and fewer candidates exist**: all candidates are picked, in `k`
  draws (F5); no draw is made for an empty list, so determinism does not depend on empty rolls.
- **If `trigger_subject` has left play by the time a queued observer resolves** ("whenever a
  minion is summoned, give it +1/+1" and the summoned minion died to a Deathrattle first): the
  selector reads the snapshot for refs but the `buff` op finds no live target → `no_target`.
- **If a `conditional` references a target that was destroyed or killed by an earlier op in the
  same effect** (`{"test": ["target", {…}]}` after `destroy` or lethal `damage`): the entity is
  *dying* (C6.0) — still in play until the death check that follows the pass, so `target.*`
  refs and the `is_dying`, `is_damaged` and stat predicates read its live values; no selector
  yields it, so a later `all_enemy_minions` op skips it. This is how Rot (row 16) tells "it
  died" from "it lived". The log's `values` carries the evaluated condition.

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
  step, so it lasts through the enemy's next turn. Match Rules confirmed this as intended
  (cross-review C-16b, 2026-11-03): one turn later than Hearthstone, and the log shows the
  `enchantment_removed` under the boss's `turn_ending`.
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
  no-ops (the dying minion is no longer selectable, C6.0); `effect_resolved.ops` lists three
  entries so the player sees two pings went nowhere.
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
  queues before anything else in this effect continues (match-rules C6); it resolves after the
  pass (C6.0).
- **If `buff cost` on `deck_top` precedes `draw` and the deck is empty** (Insight, row 25):
  `ops[0]: no_target`, then the draw deals fatigue; nothing is enchanted. With one card left,
  that card is enchanted, drawn, and shows the tax in hand.

**Hooks and passives**

- **If a `modify_cost` treasure sets the hero power to 0**: still once per turn
  (`HERO_POWER_USED`, match-rules Edge Cases).
- **If two value hooks disagree** (treasure "spells cost 1 less", passive "spells cost 1 more"):
  fold in installation order → net 0; the engine floors at 0 only at the end (F1).
- **If a boss passive is an event trigger whose scope is the player's action** ("whenever the
  player heals", row 37): `on_heal` has no hook binding (C2), so the passive is a hero-slot
  observer on the boss side (C9) — queued when the heal step fires the trigger point, in the
  boss hero-slot candidate position, i.e. **after** every player-side `on_heal` observer
  (player board, weapon, hero slot first; C6.3). A player minion "whenever you heal, gain +1/+1"
  therefore resolves before the passive's damage; both carry the `healed` event's `cause_seq`
  and the passive's `source_id` names the passive. "Hooks first" applies only to triggers that
  have a hook column (`on_turn_start`, `on_hero_damaged`, `on_card_played`, …).
- **If a treasure effect uses `self`**: rejected at load (`E_FX_SELECTOR`); treasures are not
  entities on the board.
- **If a treasure or boss passive uses an event trigger with no hook binding** (Grave Tithe's
  `on_minion_died`, a boss "whenever the player plays a minion"): hero-slot observer (C9) —
  queued when the trigger point fires, resolving in its side's "hero power / hero enchantments"
  candidate position, after any hook step at that point. Grave Tithe's `once_per_turn` mark is
  keyed on the treasure id, so two friendly deaths in one check summon one Husk.

**Recursion and caps**

- **If card A's Deathrattle summons B whose Deathrattle summons A, and both die to the same
  "destroy all minions" effect each turn**: the loop is bounded by the board (each Deathrattle
  pass is one step and the board empties between deaths) and by `RESOLUTION_STEP_CAP`; a genuinely unbounded
  cycle ("Deathrattle: summon a copy of this and deal 1 to it") ends the match with
  `resolution_overflow`, boss wins (match-rules AC-30). The validator cannot see cycles across
  cards; `/balance-check` runs a cycle lint over `summon`/`retrigger` graphs (Open Questions).
- **If a single effect's static bound exceeds `EFFECT_STATIC_STEP_LIMIT`**: `E_FX_BUDGET` at load
  — never reaches play.
- **If the log would exceed `max_match_events` before the step cap**: rng-event-log's
  `log_overflow` → `match_ended(fault)`; at defaults this precedes the step cap only when a
  cycle chains passes near the 250-mutation limit (F6). Either ending names its reason; both
  are the same content bug.

**Content and validation**

- **If a card lists `deathrattle` in `keywords[]` but has no `deathrattle` effect** (or vice
  versa): `W_FX_KEYWORD_MISMATCH`; load succeeds; the card frame may show a keyword that does
  nothing — Content fixes it.
- **If `summon` names a non-token collectible card**: allowed (Hearthstone does it); the summoned
  minion is a real instance of that card with its own effects (its Battlecry does not fire).
- **If a future op is added here before match-rules exposes its primitive**:
  `E_FX_OP_UNAVAILABLE`; the build fails rather than shipping a card that silently does nothing.
  No v1 op is in this state: `shuffle_into_deck`, `discard`, `weapon_durability`,
  `hero_power_refresh` and `remove_keyword` have had their primitives since 2026-11-03
  (match-rules Interactions; cross-review C-22).
- **If a boss `passive` contains a play trigger** (`battlecry`): `E_FX_TRIGGER` — passives are
  never played.

## Dependencies

Hard = this system cannot resolve a single effect without it (or the dependent cannot function
without this system); soft = works with a null implementation. **Bidirectional check**
(`.claude/rules/design-docs.md`): `systems-index.md` lists Card Effects as depending on Match
Rules, Card Database and RNG & Event Log — consistent with the rows below; it names Card Effects
under *Depends On* for Boss AI, Heroes, Treasures, Match UI and Content — **five dependents**,
the count the index's bottleneck note adopts (cross-review C-25; Run Structure is indirect and is
not counted). Match-rules' and card-database's Dependencies sections already list Card Effects as
a dependent; rng-event-log does too. Heroes, Treasures, Boss AI, Match UI and Content are
Designed (2026-11-03) and each confirms its row below.

| System | Direction | Hard/Soft | Nature of dependency / interface |
|---|---|---|---|
| Match Rules | This depends on Match Rules (and it calls back into this) | Hard | Trigger points and hook points (C2), the primitive API (C5), `MatchState` read access, the Choice phase and `choose` resumption, `recompute_auras()`, `RESOLUTION_STEP_CAP`. This supplies `resolve()`, `legal_targets()`, `targeting_spec()` (Match Rules calls `targeting_spec(def_id)` during C6 validation — derived here, not a stored field, cross-review C-04). The five primitives this GDD asked for are in match-rules' API since 2026-11-03 (Interactions). |
| Card Database | This depends on Card Database | Hard | `effects[]`/`passive` payloads, `type`, `cost`, `spell_damage`; `has(id)`, `card(id)`, `collectible_pool()`, `cards_by_*` for pools (F4). This supplies the CR-5 stage 7 validator and the `E_FX_*` codes. No `targeting` field needed (C1 rule 1). |
| RNG & Event Log | This depends on RNG & Event Log (through the engine) | Hard | `match_<floor>` stream for F4/F5 draws (direct, no forks in v1 — Open Questions); event envelope with `cause_seq`; `max_match_events` backstop. This owns `effect_resolved.values`, `discover_*`, `counter_changed`. |
| Heroes | Heroes depends on this | Hard (for them) | Hero powers are `hero_power`-trigger effects in this DSL (DD-M13); War/Decay/Knowledge identities (DD-H01) rely on rows 1–25 of C11 being expressible, and rows 8, 16 and 25 are the three powers as Heroes H-3 words them (Whetstone, Rot, Insight), using the registry tokens `war_whetstone_blade` and `decay_husk`. |
| Treasures | Treasures depends on this | Hard (for them) | Treasures and boss passives are effects on hook-bound triggers (C2, C9); ordering "hooks first, pick order, passive last". Treasures owns the pool and magnitudes. |
| Boss AI | Boss AI depends on this | Hard (for them) | `legal_targets()` for play enumeration; `ChoiceRequest.options` to answer Discover/Choose One; deterministic `resolve` on `clone()` for look-ahead. |
| Match UI | Match UI depends on this | Soft (engine runs headless) | `effect_resolved` as the playback unit; `discover_offered` for the panel; `targeting_spec` for highlights; `fizzled`/`outcome` reasons for feedback copy. |
| Content | Content depends on this | Hard (for them) | The schema and coverage table are what ~120 cards are authored against; anything in the v2 list is not authorable until this GDD changes. |
| Run Structure | Indirect | Soft | `EffectRuntime` travels inside `MatchState`; no direct interface in v1. |

## Tuning Knobs

`systems-designer` not consulted — Lean mode (knobs derived from the Formulas variable tables).
All knobs live in `assets/data/card_effects.json` (`schema_version` per DD-T01, which lists the
file) and are read once at `RulesEngine.start`. None of them is an
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
| `HOOKS_BEFORE_TRIGGERS` | `true` | `true` only | — | `false` is not designed: match-rules' Start/play procedures hard-order hooks first, and its End step hard-orders card `turn_end` triggers before `on_turn_end` hooks (C6.3) — the order is match-rules C4's, not this knob's, which exists only so the resolver asserts it | C6.3, C9 |

Fixed by design, not knobs: aura recompute frequency is **every step** (match-rules C10 owns
`recompute_auras()`; a lower frequency would let a minion survive a step it should not and is the
exact ambiguity Pillar 4 forbids); random targeting includes Stealth (match-rules C12); ops
within an effect are independent (C6.4). Knobs owned elsewhere that move this system's outcomes
(do not duplicate): `RESOLUTION_STEP_CAP`, `MAX_MANA`, `HAND_SIZE`, `BOARD_SIZE` (match-rules);
`max_match_events` / `log_memory_budget_bytes` (rng-event-log); `min_collectible_pool`
(card-database); treasure magnitudes (Treasures); card numbers (Content).

## Visual/Audio Requirements

`art-director` not consulted — Lean mode (no `Agent` tool). Review manually before production.
This system renders nothing (DD-T02). The primitive events (`damage_dealt`, `minion_summoned`,
`enchantment_applied`…) already carry their feedback in match-rules' table; the rows below are the
events **this** system adds, which the Match UI must present so the player can read effects as
chains (Pillar 4). Art bible "Torchlit Ledger" applies: saturated colour only for state changes,
and the *source* of an effect must be lit while its chain plays.

| Event | Visual feedback | Audio feedback | Priority |
|---|---|---|---|
| `trigger_queued` → `trigger_resolved` | Source card gets a rim-light "armed" glow when queued; on resolve, a short pulse travels from source to each target before the primitive events play | Soft chime on queue; per-trigger-class cue on resolve (Deathrattle low tone, Battlecry bright) | Must |
| `effect_resolved` (whole effect) | Chain bracket in the event feed: source name, trigger, one line per op with targets and numbers; feed groups a chain under its command | None (ops already sounded) | Must |
| `effect_resolved.ops[i].outcome ≠ applied` | Ghost icon at the intended target zone with the reason (`no target`, `board full`, `burned`); feed line greyed | Dull "nothing" tick | Must |
| `effect_resolved{fizzled: condition_false}` | Source card flashes grey once; feed line "condition not met" | Soft deny | Should |
| `discover_offered` / `discover_picked` | Centre panel, 1–3 card options at full card size, rest of board dimmed; picked card flies to hand (or board for `then: summon`) | Reveal cue; card slap on pick | Must |
| `choose_one` offer | Same panel with two to four labelled option plates instead of cards | Reveal cue | Must |
| `auras_recomputed` (from this system's claims) | Buffed stats shown in the art bible's buff colour while an aura applies; an aura source shows a faint ring that reaches its targets | None | Must |
| `counter_changed` | Small counter badge on the source card updates | Tick | Should |
| Hook-hosted effect (`source_id` = treasure / passive) | The treasure icon (player side) or boss passive plate (boss side) lights and pulses toward the target; feed names the treasure | Treasure cue (distinct from cards) | Must |
| Spell Damage applied (`values.requested > amount`) | Hand shows the scaled number on the card while hovering; feed shows "3 (+2 Spell Damage)" | None | Must |

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run
`/asset-spec system:card-effects` to produce per-asset visual descriptions, dimensions, and
generation prompts from this section.

## Game Feel

The resolver is instantaneous; feel is delivered by the Match UI pacing `effect_resolved` chains.
These targets bind how the UI must play effects back so that chains read as *inevitable and
countable*, and how fast the resolver must answer.

### Feel Reference

Hearthstone's Deathrattle cascade (e.g. a board of eggs popping one after another) — each link
visibly caused by the previous one, nothing overlapping. We borrow the **one-link-at-a-time**
cadence and the **source-lights-first** rule. From Slay the Spire we borrow the **numbers-you-can-
check** feel: the card in hand already shows the scaled damage. Anti-reference: Hearthstone's
"Yogg" turns and any auto-battler where ten effects resolve in a blur — if the player cannot
narrate the chain afterwards, the pacing failed.

### Input Responsiveness

| Action | Max input-to-response latency (ms) | Frame budget (60 fps) | Notes |
|---|---|---|---|
| `resolve()` for one effect pass (engine only) | 2 | < 1 frame | Worst case a 16-target op with value expressions |
| `legal_targets()` / `targeting_spec()` | 1 | < 1 frame | Called per hover by the UI and per card by Boss AI |
| `validate_effects()` for all v1 content | 50 total | — (load time) | Inside card-database's 200 ms `data_load_budget_ms` |
| Command accepted → source "armed" glow | 50 | 3 frames | Matches match-rules' first-visual-event budget |

### Animation Feel Targets

| Animation | Startup frames | Active frames | Recovery frames | Feel goal | Notes |
|---|---|---|---|---|---|
| Trigger pulse (source → target) | 4 | 6 | 2 | Causal, directional | Primitive events start after the pulse arrives |
| Discover panel open | 6 | — | 6 | Deliberate pause | No timer; the game waits |
| Chain link spacing | — | 8 | — | Countable | Minimum gap between consecutive ops of one effect |
| Boss passive pulse | 6 | 6 | 6 | Ominous, legible | Slightly slower than card triggers so the player notices the passive |

### Impact Moments

| Impact type | Duration (ms) | Effect description | Configurable? |
|---|---|---|---|
| Chain climax | 120 | Brief hold on the last op of a chain with ≥ 3 ops before the board settles | Yes |
| Board wipe | 200 | All-target damage ops land on the same frame, then one death group | Yes |
| Treasure fires | 150 | Treasure icon flare + screen-edge glow in the hero's colour | Yes |
| Hit-stop / shake | — | Inherited from match-rules' `damage_dealt` rules | — |

### Weight and Responsiveness Profile

- **Weight**: deliberate for chains, light for single ops. A Battlecry that pings one minion should
  feel like a flick; a three-Deathrattle cascade should feel like dominoes.
- **Player control**: total until the command; zero during resolution; restored only at
  `discover_offered` / `choose_one`, where the game visibly waits.
- **Snap quality**: crisp — each op is one visible beat with one number.
- **Acceleration model**: instant start; the UI may compress gaps when a chain exceeds 8 ops, but
  never below one beat per op, and never reorders.
- **Failure texture**: fair. Every no-op is shown with its reason at the place it would have
  happened; nothing "just didn't work".

### Feel Acceptance Criteria

- [ ] After a chain of ≥ 3 effects, playtesters can retell the order of events correctly in
      ≥ 8 of 10 attempts without opening the feed.
- [ ] No playtester describes a Deathrattle cascade as "a blur" or asks "what just happened?".
- [ ] Playtesters correctly predict scaled spell damage from the hand display before casting in
      ≥ 9 of 10 cases.
- [ ] When a boss passive fires, playtesters name the passive as the cause unprompted.

## UI Requirements

Everything below is derivable from `MatchState`, `EffectRuntime` and the event stream.

| Information | Display location | Update frequency | Condition |
|---|---|---|---|
| Scaled damage for a hovered spell (F1) | On the card in hand, replacing the printed number | On hover; every event | Owner's Main; op with `scales` |
| Legal targets for the dragged card (`targeting_spec`, `legal_targets`) | Target highlights + arrow | On drag start | During targeting |
| Armed / queued effect sources | Rim glow on the source card | `trigger_queued` → `trigger_resolved` | Always |
| Effect chain in the event feed (source, trigger, per-op line, outcomes) | Side feed, grouped under the command | `effect_resolved` | Always; replay source |
| Discover / Choose One options | Centre panel | `discover_offered` | Choice phase, player side (boss side hidden by UI policy) |
| Active aura attribution (which source buffs which minion) | Tooltip on a buffed stat | `auras_recomputed` | On hover |
| Treasure / passive activity | Treasure tray (player) and passive plate (boss) | Hook-hosted `effect_resolved` | Always |
| Counter values | Badge on the source card | `counter_changed` | Source has a counter |
| Once-per-turn spent state | Dimmed trigger icon on the card | On mark set / Start step | Effect has `once_per_turn` |
| Card text rendering of effects (`text.en` now; generated text later) | Card frame text slot | Static | Always |

📌 **UX Flag — Card Effects**: This system has UI requirements. In Phase 4 (Pre-Production), run
`/ux-design` to create a UX spec for each screen or HUD element this system contributes to
**before** writing epics (Discover/Choose-One panel, effect chain feed grouping, aura attribution
tooltip, treasure tray, scaled-damage hand display). Stories that reference UI should cite
`design/ux/[screen].md`, not the GDD directly.

## Cross-References

| This document references | Target GDD | Specific element referenced | Nature |
|---|---|---|---|
| Trigger points and hook table bound in C2 | `design/gdd/match-rules.md` | Interactions: trigger points; `HookRegistry` hook table | Rule dependency |
| Primitive API used by every op (C5) | `design/gdd/match-rules.md` | Interactions: engine primitive API | Data dependency |
| Queue semantics, death ordering, aura recompute, step cap (C6, F6) | `design/gdd/match-rules.md` | C10 resolution loop; `RESOLUTION_STEP_CAP`; DD-M11 | Rule dependency |
| Play order Battlecry → hooks → `on_play` → `on_summon`; spell no-target rule; Battlecry fizzle | `design/gdd/match-rules.md` | C6 steps 1–3; decision 7 | Rule dependency |
| Spell Damage total | `design/gdd/match-rules.md` | F7 `spell_damage(side)` | Data dependency |
| `apply_damage` pipeline and `effective_cost` terms | `design/gdd/match-rules.md` | F2, F1 (`card_enchantment_delta`, `hand_aura_delta`, `hook_delta`) | Data dependency |
| Silence clamp and enchantment expiry | `design/gdd/match-rules.md` | F6; C13; C4 End step 5 | Rule dependency |
| Choice phase and `choose` command | `design/gdd/match-rules.md` | States: `Choice`; C2 `choose` | State trigger |
| Keyword semantics and the display-only keyword rule | `design/gdd/match-rules.md` | C12 keyword table (DD-M09) | Rule dependency |
| `effects[]` / `passive` opaque fields; CR-5 stage 7 validator; `has(id)`; pools | `design/gdd/card-database.md` | CR-3 CardDef/HeroPowerDef/BossDef/TreasureDef; CR-5; CR-6 `collectible_pool`, id-ascending order | Ownership handoff (validator) / Data dependency |
| `collectible_pool_size` as the Discover universe | `design/gdd/card-database.md` | Formulas: Collectible pool size | Data dependency |
| Stream draw primitives and draw counts | `design/gdd/rng-event-log.md` | F4 `randi_range`, `shuffle`; rule 8 draw-order documentation | Data dependency |
| Event envelope, `cause_seq`, catalogue rows for `effect_resolved`, `discover_*`, `minion_modified` | `design/gdd/rng-event-log.md` | Rules 11–14; D. catalogue | Ownership handoff |
| `max_match_events` backstop | `design/gdd/rng-event-log.md` | F7 | Data dependency |
| Hero power as a DSL effect, 2 mana once per turn; the three powers' prose | `design/gdd/heroes.md` | H-3 Whetstone / Rot / Insight; tokens `war_whetstone_blade`, `decay_husk` | Ownership handoff |
| Treasure and passive hooks authored in this DSL; hooks-first ordering; hero-slot observers | `design/gdd/treasures.md` | T2.5, T8 pool, T9 sketches, R-2/R-3/R-6/R-10/R-13 | Ownership handoff |
| `legal_targets()`, `ChoiceRequest` answering | `design/gdd/boss-ai.md` | AI command loop | Ownership handoff |
| Playback of `effect_resolved`, Discover panel | `design/gdd/match-ui.md` | Event rendering | Data dependency |
| Card texts written against C11 rows; the two redesigns; boss passives B1 | `design/gdd/content.md` | CN-2 card plan (`Row` column), CN-3 bosses | Data dependency |
| Hero identities War / Decay / Knowledge driving the archetype table | `design/design-decisions.md` DD-H01 | Launch heroes | Rule dependency |
| Card frame text slot size constraining `MAX_OPS_PER_EFFECT` | `design/art/art-bible.md` | §4 Card frame slot layout | Rule dependency |

## Acceptance Criteria

`qa-lead` not consulted — Lean mode (no `Agent` tool). Review manually before production. Every
criterion is a gdUnit4 unit test against the pure engine plus resolver
(`tests/unit/card_effects/`) with an injected fixed seed and a fixture set
`tests/fixtures/cards_effects_test.json` (one card per C11 row that the test names, plus vanilla
minions from match-rules' fixture); no Node, no scene. Event assertions read the log; "row N"
refers to the C11 coverage table.

**Schema and validation**

- [ ] AC-01 **GIVEN** the full v1 fixture set, **WHEN** `validate_effects` runs on every host,
  **THEN** it returns zero errors, and each C11 row 1–46 is present in the fixture and validates.
- [ ] AC-02 **GIVEN** a card with two play effects each using `chosen`, **WHEN** validated,
  **THEN** `E_FX_CHOSEN` names the host and the second effect's id.
- [ ] AC-03 **GIVEN** a boss `passive` with trigger `battlecry`, **WHEN** validated, **THEN**
  `E_FX_TRIGGER`; **GIVEN** a treasure effect with `targets: self`, **THEN** `E_FX_SELECTOR`.
- [ ] AC-04 **GIVEN** `summon` with `card_id: "nope"`, **WHEN** validated, **THEN** `E_FX_REF`;
  **GIVEN** `{"ref": "owner.bananas"}`, **THEN** `E_FX_REF_PATH`.
- [ ] AC-05 **GIVEN** "deal 1 damage to all minions, 20 times" (`repeat 20 × all_minions`),
  **WHEN** validated with `EFFECT_STATIC_STEP_LIMIT = 250`, **THEN** `E_FX_BUDGET` with
  `bound = 321`; with `times: 10` it passes (`161`).
- [ ] AC-06 **GIVEN** an effect using `shuffle_into_deck`, `discard`, `weapon_durability`,
  `hero_power_refresh` or `remove_keyword`, **WHEN** validated, **THEN** no
  `E_FX_OP_UNAVAILABLE` is raised (their primitives exist, match-rules Interactions); **GIVEN** a
  test stub engine whose primitive table lacks `add_card_to_deck`, **WHEN** `shuffle_into_deck`
  is validated against it, **THEN** `E_FX_OP_UNAVAILABLE` names the op and the missing primitive.
- [ ] AC-07 **GIVEN** row 18 (chosen, `kind: any`) and row 10 (chosen friendly minion, Battlecry),
  **WHEN** `targeting_spec` is queried, **THEN** row 18 → `{mode: required, filter: {kind: any}}`
  and `legal_targets` lists every non-Stealth enemy character plus all friendly characters; row 10
  on an empty friendly board → empty list and the minion is still in `legal_commands()`.

**Play triggers and targeting**

- [ ] AC-08 **GIVEN** row 10 with no friendly minion, **WHEN** played, **THEN** mana is paid, the
  minion is on board, no `effect_resolved` and no `card_drawn` is emitted.
- [ ] AC-09 **GIVEN** row 10 with one friendly minion, **WHEN** played targeting it, **THEN** the
  log order is `card_played`, `minion_summoned`, exactly two `card_drawn`, `effect_resolved`,
  then `minion_died` (the death check runs after the pass, C6.0 — the sacrificed minion is
  *dying* while the draws happen), and `effect_resolved.ops` is `[destroy: applied, draw:
  applied ×2]`.
- [ ] AC-10 **GIVEN** row 20 and a War MVP pool of 40 cards with 9 spells, **WHEN** cast with seed
  7, **THEN** `discover_offered.option_card_ids` has 3 distinct spell ids none of which is the
  casting spell, the engine is in `Choice`, exactly 3 stream draws were consumed, and after
  `choose(1)` that card is in hand and `discover_picked` precedes the next event.
- [ ] AC-11 **GIVEN** a Discover whose filter matches 2 cards, **WHEN** cast, **THEN** 2 options
  are offered; **GIVEN** a filter matching 0, **THEN** no `Choice` phase, op outcome
  `empty_pool`, and the following op in the same effect still runs.
- [ ] AC-12 **GIVEN** row 33 cast on an enemy 3/3, **WHEN** `choose(0)` (Smite), **THEN**
  `damage_dealt{amount: 2}` and no `healed`; **WHEN** `choose(1)` instead, **THEN** `healed` and no
  `damage_dealt`.
- [ ] AC-13 **GIVEN** row 44 (hero power "Deal 1") and two Spell Damage +1 minions, **WHEN** used
  on the enemy hero, **THEN** `damage_dealt.amount == 1`; **GIVEN** row 18 cast instead, **THEN**
  `amount == 5` and `effect_resolved.ops[0].values.requested == 5`.
- [ ] AC-14 **GIVEN** row 19 ("Deal 2 to all enemies") with +1 Spell Damage and an enemy board of
  3 plus hero, **WHEN** cast, **THEN** four `damage_dealt{amount: 3}` in canonical order (board
  left to right, then hero).
- [ ] AC-15 **GIVEN** row 8 (War hero power) with no weapon, **WHEN** used, **THEN**
  `weapon_equipped` (1/2 `war_whetstone_blade`) and `ops[0].values.branch == "else"`; **WHEN** used
  next turn with the Blade held, **THEN** `enchantment_applied{attack_delta: 1, expires: end_of_turn}` on
  the weapon and no equip; at that End step the enchantment is removed.

**Event triggers and ordering**

- [ ] AC-16 **GIVEN** a treasure "at the start of your turn gain 1 Armor" (hook) and row 34 on the
  player's board, **WHEN** the player's Start step runs, **THEN** `armor_gained` precedes both
  `damage_dealt` events; exactly one `trigger_resolved{trigger: turn_start}` sits between
  `armor_gained` and the first `damage_dealt` (the hook step, then row 34's queued pass), and
  **no** `trigger_resolved` sits between the two `damage_dealt` (both pings are mutations of one
  pass, C6.0); the step counter rose by 2.
- [ ] AC-17 **GIVEN** an observer with both `on_play` and `on_summon` ("+1/+1 to the played/summoned
  minion") and row 9 dying, **WHEN** a minion is played from hand, **THEN** it receives +2/+2 (two
  `enchantment_applied`); **WHEN** row 9's Husks are summoned, **THEN** each receives +1/+1 only.
- [ ] AC-18 **GIVEN** a minion with `on_damage_taken: draw 1` at 1 health and a Deathrattle, **WHEN**
  hit for 1, **THEN** `card_drawn` precedes its `trigger_resolved{deathrattle}` (match-rules
  AC-28 restated through the DSL).
- [ ] AC-19 **GIVEN** row 11 and two friendly minions dying in one death check, **WHEN** the loop
  completes, **THEN** row 11 has +2/+2 (two queued triggers, two `effect_resolved`); **GIVEN** the
  same effect with `once_per_turn: true`, **THEN** +1/+1 and exactly one `trigger_queued`.
- [ ] AC-20 **GIVEN** row 12 (Deathrattle: damage = this minion's Attack) buffed to 5 Attack by an
  aura lord that dies in the same step, **WHEN** both die, **THEN** the enemy hero takes 5 (the
  raise-time snapshot), not the base Attack.
- [ ] AC-21 **GIVEN** a minion Silenced while its Deathrattle is already queued (killed and
  silenced in one effect: `destroy` then `silence` on a `pending_destroy` target), **WHEN** the
  loop completes, **THEN** the Deathrattle still resolves; **GIVEN** Silence **before** death,
  **THEN** no `trigger_queued` for it.
- [ ] AC-22 **GIVEN** row 21 on board, **WHEN** the owner casts a spell, **THEN** `card_drawn`
  appears after `spell_cast` and after the spell's own `effect_resolved`; **WHEN** the opponent
  casts a spell, **THEN** no draw (scope `by: owner`).
- [ ] AC-23 **GIVEN** row 22 with 4 cards in hand, **WHEN** the owner's End step runs, **THEN**
  `effect_resolved{fizzled: condition_false}` and no damage; with 5 cards, **THEN** one
  `damage_dealt{amount: 3}` on a random enemy character chosen with exactly one stream draw.
- [ ] AC-24 **GIVEN** row 34 and a single enemy minion at 1 health, **WHEN** the Start step runs,
  **THEN** `effect_resolved.ops` has two entries: the first `applied` (minion dies), the second
  `no_target`; the hero is never hit.
- [ ] AC-25 **GIVEN** row 37 (boss passive "whenever the player heals, deal 1 to their hero") and
  a player minion "whenever you heal, gain +1/+1", **WHEN** the player heals, **THEN** the log
  reads `healed`, then the minion's `enchantment_applied`, then the passive's
  `damage_dealt{amount: 1}` with `source_id` equal to the passive id — two
  `trigger_resolved{trigger: on_heal}` in that order (player-side observers before the boss
  hero-slot observer: `on_heal` has no hook, C2 / C9 / C6.3).

**Auras, buffs and transforms**

- [ ] AC-26 **GIVEN** the friendly board `[row 26, row 26, vanilla 1/1, row 27]` left to right,
  **WHEN** auras are recomputed, **THEN** the 1/1 reads 5/3 (`+1 +1` attack from the two lords
  `+2` from adjacency = `+4`; health `+2`), each lord reads +1/+1 from the other only (row 27
  is adjacent to neither), and row 27 reads +2/+2.
- [ ] AC-27 **GIVEN** row 26 buffing a damaged 2/2 (now 3/1 after 2 damage), **WHEN** row 26 is
  Silenced, **THEN** at the next recompute the 2/2 has `health ≤ 0` and dies in the following loop
  pass, with `silenced` → `auras_recomputed` → `minion_died` in the log.
- [ ] AC-28 **GIVEN** a "+4/+4 until end of turn" on a 1/1 that then takes 4 damage, **WHEN** the
  owner's End step runs, **THEN** `enchantment_removed` then `minion_died` (F3).
- [ ] AC-29 **GIVEN** row 24 on board and a 3-cost spell in hand, **WHEN** `effective_cost` is read,
  **THEN** 2; with two copies of row 24 → 1; with a 1-cost spell and two copies → 0, never
  negative.
- [ ] AC-30 **GIVEN** row 31 cast on an enemy 5/5 with Taunt and a Deathrattle, **WHEN** resolved,
  **THEN** the target is a new `entity_id` 1/1 Sheep with no keywords, no `battlecry` of the Sheep
  fires, and when the Sheep later dies no Deathrattle fires.
- [ ] AC-31 **GIVEN** row 32 targeting a friendly minion buffed +2/+2 and damaged 1, **WHEN**
  resolved, **THEN** the card added to hand has the printed cost and, when played, printed stats
  and full health.
- [ ] AC-32 **GIVEN** row 42 (treasure "your minions have Rush") installed, **WHEN** a minion is
  played and attacks an enemy minion the same turn, **THEN** accepted; **WHEN** it attacks the hero,
  **THEN** `RUSH_CANNOT_HIT_HERO`; **WHEN** the treasure is absent, **THEN** `SUMMONING_SICK`.

**Hooks and value triggers**

- [ ] AC-33 **GIVEN** row 36 (passive "+1 cost to enemy minions") and row 39-style treasure
  "minions cost 1 less" installed, **WHEN** the player reads a 3-cost minion's `effective_cost`,
  **THEN** 3 (fold: treasure first −1, passive +1); a 0-cost minion reads 0.
- [ ] AC-34 **GIVEN** row 40 (treasure "spells deal 1 more"), **WHEN** row 18 is cast for 3 with 0
  Spell Damage, **THEN** `damage_dealt.amount == 4`; **WHEN** row 44 (hero power) is used, **THEN**
  1 (scope `type: spell`).
- [ ] AC-35 **GIVEN** row 43 (treasure "hero attacks twice"), **WHEN** the hero with a weapon
  attacks twice, **THEN** both accepted and the third is `CANNOT_ATTACK`.
- [ ] AC-36 **GIVEN** row 38 installed, **WHEN** `start` runs, **THEN** `armor_gained{10}` appears
  before the first `card_drawn`, with `source_id` equal to the treasure id.

**Determinism, bounds, interfaces**

- [ ] AC-37 **GIVEN** the 100-command scripted match `tests/fixtures/replay_card_effects_100.json`
  (decks containing rows 9, 12, 13, 20, 22, 26 and 34; seed and command list in the file),
  **WHEN** replayed with the same seed and commands, **THEN** the two event logs are
  byte-identical, and the number of stream draws equals the sum of F4/F5 draw counts recomputed
  from the log.
- [ ] AC-38 **GIVEN** a Deathrattle "summon a copy of this and deal 1 to it" and
  `RESOLUTION_STEP_CAP = 50`, **WHEN** it dies, **THEN** the match ends `resolution_overflow`
  within 50 steps and fewer than `max_match_events` events were logged.
- [ ] AC-39 **GIVEN** any `effect_resolved` in the fixture matches, **WHEN** inspected, **THEN** it
  carries `effect_id, host_id, host_kind, source_id, owner, trigger, depth, fizzled, ops[]` with
  one `ops` entry per op in the effect, and its `cause_seq` equals that of the command event or
  the `trigger_resolved` that started it.
- [ ] AC-40 **GIVEN** a `clone()` of a mid-match state with a queued trigger and a counter, **WHEN**
  the same command is submitted on the clone and the original, **THEN** both produce identical
  event sequences and the original's `EffectRuntime` is unchanged by the clone's resolution.
- [ ] AC-41 **GIVEN** the resolver source, **WHEN** grepped for the Tuning Knobs constants and for
  global RNG calls (`randi`, `randf`, `shuffle(`, `pick_random`), **THEN** every constant comes from
  `card_effects.json` and no global RNG call exists under the rules tree.
- [ ] AC-42 **GIVEN** a 16-target op (`all_characters` on full boards) with value expressions,
  **WHEN** `resolve` is timed on the CI runner, **THEN** under 2 ms; `validate_effects` over the
  full v1 fixture under 50 ms.

**Hero powers, hosts and counters (added by the 2026-11-03 review)**

- [ ] AC-43 **GIVEN** row 16 (Rot) used on an enemy 2/1, **WHEN** resolved, **THEN** the log reads
  `damage_dealt{amount: 1}`, `minion_summoned{decay_husk}` at the rightmost friendly slot,
  `effect_resolved` (`ops[1].outcome == applied`), then `minion_died` for the target — the Husk
  arrives before the target's Deathrattle resolves; **GIVEN** an enemy 2/3 instead, **THEN**
  damage only, no `minion_summoned`, `ops[1].outcome == skipped`; **GIVEN** a 1/1 with Divine
  Shield, **THEN** `divine_shield_popped`, no summon.
- [ ] AC-44 **GIVEN** row 25 (Insight) with a 3-cost spell on top of the deck, **WHEN** used,
  **THEN** `enchantment_applied{cost_delta: 1, expires: end_of_turn}` precedes `card_drawn`, that
  card's `effective_cost` reads 4 until the owner's End step and 3 after it; **GIVEN** an empty
  deck, **THEN** `ops[0].outcome == no_target` and one fatigue damage event, no enchantment.
- [ ] AC-45 **GIVEN** a treasure "whenever a friendly minion dies, summon a 1/1 Husk — once per
  turn" (`on_minion_died`, hero-slot observer, `once_per_turn`) and a friendly minion with
  "whenever a friendly minion dies, gain +1/+1" (row 11), **WHEN** two friendly minions die in
  one death check, **THEN** exactly one `minion_summoned{decay_husk}` with `source_id` equal to
  the treasure id, its `trigger_resolved` **after** row 11's two, and no `E_FX_TRIGGER` at load.
- [ ] AC-46 **GIVEN** row 45 after three minions (either side) died while it was in play, **WHEN**
  it dies, **THEN** `damage_dealt{amount: 3}` on the enemy hero read from `counter.seen` in the
  raise-time snapshot; **GIVEN** the same minion bounced to hand and replayed, **THEN** its
  counter reads 0.

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Five primitives this GDD needs are not in match-rules' primitive API: `remove_keyword`, `add_card_to_deck`, `modify_durability`, `refresh_hero_power`, `discard`. Add them to match-rules Interactions (their ops stay `E_FX_OP_UNAVAILABLE` until then). | Match Rules GDD (owner) | Before `/create-architecture` | Resolved 2026-11-03 — cross-review C-22: all five are in match-rules Interactions with their events; C5 rows, C10, Edge Cases and AC-06 updated |
| `targeting_spec` is derived from the `chosen` selector rather than stored as a Card Database field; match-rules Dependencies says it reads `targeting {mode, filter}` from the card record. Confirm the derived reading and update that row's wording. | Owner / `/consistency-check` | Before match-rules design-review | Resolved 2026-11-03 — cross-review C-04: match-rules Dependencies now reads `effects[]` and calls `targeting_spec(def_id)` (derived, not stored) |
| Event-name drift between siblings: match-rules `healed` / `weapon_destroyed` / `trigger_resolved` / `enchantment_applied` vs rng-event-log `healing_applied` / `weapon_broken` / `deathrattle_triggered` / `minion_modified`. This GDD uses match-rules' names and emits no `minion_modified` (the primitive's `enchantment_applied` already covers it). One catalogue must win. | RNG & Event Log GDD | Before `/consistency-check` | Resolved 2026-11-03 — DD-X04 (cross-review C-07): Match Rules C15 spelling wins, RNG catalogue mirrors it; `discover_offered` (this GDD) and `choice_requested` (Match Rules) are two distinct events — pairing stated in C8.1 and Interactions |
| Random draws come **directly** from `match_<floor>` (C6.9); rng-event-log's Interactions row proposes `fork("effect_<id>")`. Confirm direct draws for v1 and amend that row. | RNG & Event Log GDD | Before `/consistency-check` | Open — proposed here |
| `until_end_of_turn` on an enemy-controlled recipient expires at the recipient's controller's End step (match-rules C4 step 5), i.e. one turn later than Hearthstone. Intended, or should match-rules expire at the end of the turn in which the enchantment was applied? | Match Rules GDD | Before Card Effects design-review | Resolved 2026-11-03 — cross-review C-16b: intended; match-rules C4 End step 5 documents recipient-controller expiry (F3, Edge Cases updated) |
| Observer candidate order: match-rules C4 says active side first for turn triggers, C10/Interactions say player side first always. This GDD follows both as written (C6.3); match-rules should state one rule. | Match Rules GDD | Before match-rules design-review | Resolved 2026-11-03 — cross-review C-16c: player side first always, including turn triggers (match-rules C4 step 5 amended); C6.3 aligned |
| `assets/data/card_effects.json` is a new data file not listed in DD-T01 — confirm and add it to the register (same ask as match-rules' `match_rules.json`). | Owner (orchestrator) | Before `/create-architecture` | Resolved 2026-11-03 — cross-review C-22: DD-T01 lists `card_effects.json` |
| Boss Discover draws from the **player's** collectible pool (F4). Acceptable for Pillar 2, or do puzzle bosses need their own pool (`cards_by_set(boss)` included)? | Content / Treasures GDD | Alpha content pass | Open — defaulted here |
| Cross-card cycle lint (A summons B summons A) is not a load-time check; proposed as a `/balance-check` pass over `summon`/`retrigger`/`transform` graphs. | Content / `/balance-check` | Before the first 40-card batch | Open — proposed here |
| `retrigger` is limited to `deathrattle` in v1. Decay may want "trigger a Battlecry again" — allow `battlecry` with `chosen` re-targeting? | Heroes / Content | Alpha content pass | Deferred |
| Generated card text from the DSL (so `text.en` cannot drift from the effect) vs authored text. v1 authors text by hand; `W_FX_KEYWORD_MISMATCH` is the only drift check. | Content / Match UI | Vertical Slice | Deferred |
| Systems index says Card Effects has six dependents; five rows list it. Reconcile (Reward Draft or Run Structure?). | `/map-systems` | Next index update | Resolved 2026-11-03 — cross-review C-25: five dependents (Boss AI, Heroes, Treasures, Match UI, Content); the index's bottleneck note is corrected to five, and Run Structure stays indirect (Dependencies intro updated) |
| Heroes H-3 sketches carry a `targeting` field (C1 rule 1 derives it from `chosen`) and assume a death check between Rot's two ops (C6.0: a pass is atomic; `left_play` is `is_dying`). Rows 8, 16, 25 give the v1 encodings; Heroes to correct its sketches per its own rule ("prose wins") and close its DSL open question. | Heroes GDD (`/propagate-design-change`) | Before `hero_powers.json` is authored | Resolved 2026-11-03 — Heroes H-3 sketches are rewritten in card-effects v1 vocabulary (rows 8, 16, 25 verbatim; `is_dying`; one pass per step) and its DSL open question is closed |
| Treasures R-2 (condition on value triggers: C1), R-3 (`tag` on board minions: C3), R-6 (`owner.turns_taken`: C4), R-10 (hero-slot observers: C9), R-13 (`scope.card` without `kind`: C2) and the `aura`-on-`owner_weapon` legality (C5) are answered; Treasures to close them. R-1 (permanent `add_mana`) remains with Match Rules. | Treasures GDD | `/consistency-check` | Resolved 2026-11-03 — cross-review C-26 closes R-2/R-3/R-6/R-10/R-13 and the `aura`-on-weapon row in Treasures; R-1 resolved by cross-review C-02 (match-rules `crystal_bonus`; this GDD's `mana` op row cites it) |
| `until_end_of_turn` enchantments on **card instances** in hand or deck (rows 25, 41): match-rules C4 End step 5 removes those "owned by S characters" — confirm the wording covers card instances held by S, or add them. | Match Rules GDD | Before the Knowledge hero stories | Resolved 2026-11-03 — cross-review C-16a: match-rules C4 End step 5 now names "card instances in S's hand and deck" (F3 variable row updated) |
| Content's two redesigns: `war_cleave_through` ("a minion and the minions next to it") is now expressible with `adjacent` `of: target` (C3); Content may restore the original text or keep the sweep. `war_quartermaster`'s `modify_durability` primitive landed in match-rules on 2026-11-03 (cross-review C-22), so its "+1 Durability" text is authorable. | Content GDD | Alpha content pass | Open — informational |
| `mana` with `duration: this_turn` (`add_mana(side, n, temporary=true)`) is used by Content's `decay_soul_tithe` (Alpha), but match-rules C5 says temporary gain "is not used by v1 content" and defines only the clamp. Match Rules to state the temporary case (adds to `mana_current` only, no crystal; clamp `MAX_MANA`; expires with the Start-step refill) or Content to retext the card. | Match Rules GDD | Before the Decay sacrifice bundle stories | Resolved 2026-11-03 — match-rules C5 now defines `add_mana(side, n, temporary=true)` as `n` **temporary crystals** (`mana_max` and `mana_current` rise, clamped to `MAX_MANA`; expire at that side's End step 5; its AC-45) and names `decay_soul_tithe` / `neutral_treasure_map`. Match Rules chose temporary crystals over the "`mana_current` only" proposal; the C5 `mana` row restates its rule |
| `discover` with `then: cast` on a spell whose derived `targeting_spec.mode` is `required` has no target source at resume time. Proposed: the validator rejects `then: cast` unless every candidate's mode is `none` (`E_FX_OP_TARGET`); no v1 content uses `then: cast`. | Card Effects (this GDD) | Before any `then: cast` card is authored | Open — proposed by the 2026-11-03 re-review |
