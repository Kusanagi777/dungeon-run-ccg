# Match Rules

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
> **Author**: `/design-system` (game-designer role) for the owner. `systems-designer`, `ai-programmer`, `qa-lead` and `art-director` not consulted — Lean mode (no `Agent` tool available in this run). Review manually before production.
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 4 (Readable, deterministic rules) primarily; Pillar 2 (Bosses are puzzles) and Pillar 3 (Lose fast, learn fast) secondarily
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` Feasibility: no engine reference for `scripting` under `docs/engine-reference/godot/modules/`; feasibility not checked against the pinned engine (this system is pure GDScript `RefCounted` logic with no engine surface, DD-T02). No ADRs exist yet; DD-T02/DD-T03 cite ADR-0001/ADR-0003 as planned.
> **Design decisions honoured**: DD-M01–DD-M13, DD-T02–DD-T04 (`design/design-decisions.md`). Numbers refined only in Tuning Knobs; owner rows unchanged.

## Summary

[To be designed]

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Card Database, RNG & Event Log`

## Overview

Match Rules is the referee of a single Deckdelve duel: the player's hero against one boss, each
with a deck, a hand, a row of up to seven minions, mana crystals that grow by one per turn, and a
hero power. It owns everything that makes a move legal or illegal and everything that happens when
a move resolves — turn structure, mana and costs, playing minions, spells and weapons, attacking,
damage and armour math, the fifteen v1 keywords (DD-M09), death and trigger ordering, hand burn,
fatigue, and the win/loss decision. It is a pure, engine-free `RulesEngine` over a plain
`MatchState` (DD-T02): callers (the Match UI for the player, Boss AI for the boss) send a small set
of **commands** — `mulligan`, `play_card`, `attack`, `use_hero_power`, `choose`, `end_turn`,
`concede` — and receive either an accepted result or a **typed rejection**; every state mutation
emits exactly one event to the RNG & Event Log (DD-T04). The engine never decides what a card
*does* — card text is resolved by Card Effects through hook points this document names — it decides
*when* effects fire, *in what order*, and *what the board looks like afterwards*.

For the player, this system is the whole moment-to-moment game: reading the board, spending mana,
choosing attacks, watching the boss answer. Without it there is no "inner game" for the run to
wrap (systems-index: "two games stacked"); with it done right, every loss is explainable from the
event log alone, which is what Pillar 4 demands and what Pillars 2 and 3 need in order to make
bosses learnable puzzles.

## Player Fantasy

*Framing: Direct — the player operates this system on every turn.* `creative-director` not
consulted — Lean mode. Review manually before production.

**The fantasy is total legibility under pressure.** The player should feel like a chess player
who can see the whole board, not a gambler waiting on a roll: "I have 6 mana, their Taunt has 3
health, my weapon has 2 swings left — if I trade here and go face there, that is exactly lethal."
When the plan works, the pleasure is the plan; when it fails, the player should be able to point
at the event log and say "*that* is the line I missed." This is Pillar 4 verbatim: *"If the player
cannot tell why they lost, the rules failed."*

- **Reference feeling**: Hearthstone's attack-and-trade clarity (one row, attacker and defender both
  hurt, numbers visible on the card) combined with Slay the Spire's telegraphed enemy intents —
  the board tells you what will happen before you commit. We borrow the *certainty of outcome*
  from both.
- **Anti-reference**: hidden-information engines where an off-screen passive or an undocumented
  trigger order changes a result. A boss passive (Pillar 2) is allowed to bend the rules; it is
  never allowed to do so silently.
- **The anchor moment**: the end of a turn where the player counts lethal, executes it in three
  commands, and the engine resolves every step in the order they expected. The secondary moment is
  the *near miss*: the boss survives at 1 because a Divine Shield they forgot ate one point, and the
  log shows exactly that.
- **Emotional texture**: deliberate, never frantic. There are no timers (MDA: Submission — low
  stress), so the engine's job is to be *trustworthy*, not *fast*; speed is the Match UI's job.

## Detailed Design

### Core Rules

Terminology used throughout: a **character** is a hero or a minion; a **side** is `PLAYER` or
`BOSS`; the **controller** of a character is the side whose board or hero slot it occupies; an
**action** is one accepted command or one engine-initiated procedure (turn start, turn end); a
**step** is one indivisible batch of mutations inside an action (see C10). All numeric constants
named in `UPPER_CASE` are data-driven (`assets/data/match_rules.json`, see Tuning Knobs), never
hardcoded.

#### C1. Data model

The engine is a `RulesEngine` that owns one `MatchState`. State is plain data; nothing in it
references a Node (DD-T02). Every field below is observable by tests.

- **MatchState**: `turn` (global counter, first turn = 1), `active_side`, `phase` (see States),
  `players[PLAYER|BOSS]`, `pending_choice` (null or a `ChoiceRequest`), `result` (null until
  Ended), `next_entity_id`, `hooks` (the HookRegistry installed by Treasures and the boss passive),
  a reference to the event log and to the `match` RNG stream (DD-T03).
- **PlayerState**: `hero`, `mana_current`, `mana_max`, `deck` (ordered list, index 0 is the top),
  `hand` (≤ `HAND_SIZE`), `board` (≤ `BOARD_SIZE`, index 0 is leftmost), `weapon` (null or
  Weapon), `hero_power {def_id, used_this_turn}`, `fatigue_counter` (starts 0), `graveyard`,
  `turns_taken`, and `stats {damage_dealt_by_card, damage_taken, cards_played, minions_summoned}`
  for the Run Structure result.
- **Character** (hero or minion): `entity_id` (unique per match, assigned at creation, the stable
  key used by commands, targets and events), `controller`, `base_attack`, `base_health`,
  `enchantments[]`, `damage_taken`, `keywords` (base set from the definition plus keywords granted
  by enchantments), `attacks_used` (this turn), `frozen`, `frozen_on_turn`, `silenced`. Minions
  add `def_id`, `summoning_sick`, `summoned_on_turn`. Heroes add `armor` and `base_attack = 0`.
- **Derived values** (never stored): `max_health = base_health + Σ enchantment.health_delta`,
  `health = max_health − damage_taken`, `attack = max(0, base_attack + Σ attack_delta +
  weapon.attack if hero)`, `max_attacks = 2 if Windfury else 1`, `attacks_remaining = max_attacks −
  attacks_used`.
- **Enchantment**: `{source_entity_id | null, attack_delta, health_delta, keywords_added[],
  is_aura, expires (null | end_of_turn)}`. Auras are enchantments tagged `is_aura` and are
  recomputed, never persisted across steps (C10). Rationale: tracking `damage_taken` instead of
  current health makes buff loss, Silence and aura loss follow one arithmetic rule (F6).
- **Weapon**: `entity_id`, `def_id`, `attack`, `durability`, `keywords`, `enchantments[]`.
- **CardInstance**: `instance_id`, `def_id` (looked up in Card Database), `zone` (deck | hand |
  board | graveyard | resolving), `cost_modifiers[]` (enchantments on the card while in hand).

#### C2. Commands, results and rejections

The engine exposes `submit(command) → CommandResult` and `legal_commands() → Command[]`.
`CommandResult = {accepted, rejection: {code, detail} | null, events: [seq_first, seq_last]}`.
Illegal moves are **data, never exceptions** — the UI greys options out and Boss AI filters by
them. Commands are validated in full before any mutation; an accepted command always resolves to
completion inside the same call (the engine is synchronous).

| Command | Arguments | Legal when | What it does |
|---|---|---|---|
| `mulligan` | `keep_mask: bool[]` (length = hand size) | phase = Mulligan; issuer = PLAYER | Returns unkept cards to deck, shuffles, redraws the same count (C3) |
| `play_card` | `hand_index`, `position` (minions only), `target_id` (optional) | phase = Main of issuer; cost payable; type-specific rules (C6) | Pays mana, moves the card, resolves battlecry/spell/equip |
| `attack` | `attacker_id`, `target_id` | phase = Main of issuer; `can_attack(A, D)` true (F3) | Combat step (C8) |
| `use_hero_power` | `target_id` (optional) | phase = Main; `hero_power.used_this_turn = false`; cost payable; target legal | Pays cost, marks used, resolves the hero power's effect (C7) |
| `choose` | `option_index` | phase = Choice; issuer = the side named in `pending_choice` | Resumes the paused resolution with the chosen option |
| `end_turn` | — | phase = Main of issuer | Runs the End step, hands the turn over (C4) |
| `concede` | — | any phase except Ended; issuer = PLAYER | Ends the match: winner BOSS, reason `concede` (C14) |

Rejection codes (closed set; a programmer adds none without a GDD change):
`MATCH_ENDED`, `NOT_YOUR_TURN`, `WRONG_PHASE`, `CHOICE_PENDING`, `ENGINE_BUSY`,
`INVALID_INDEX`, `INVALID_POSITION`, `INVALID_MASK`, `INVALID_CHOICE`, `NOT_ENOUGH_MANA`,
`BOARD_FULL`, `TARGET_REQUIRED`, `NO_LEGAL_TARGET`, `ILLEGAL_TARGET`, `TARGET_STEALTHED`,
`MUST_ATTACK_TAUNT`, `CANNOT_ATTACK` (attack 0 or no attacks remaining), `ATTACKER_FROZEN`,
`SUMMONING_SICK`, `RUSH_CANNOT_HIT_HERO`, `HERO_POWER_USED`. Checks run in the order listed in
each command's row so the first failing reason is deterministic (tests assert the code).

`legal_commands()` expands every accepted command for the active side: each playable hand card ×
each valid position × each legal target, each attacker × each legal defender, hero power × each
legal target, plus `end_turn`. Boss AI consumes this list; the UI may use it to pre-compute
highlights. `MatchState.clone()` returns a deep copy with no shared references so Boss AI can
look ahead without touching the live match.

#### C3. Match setup

1. Run Structure supplies a `MatchConfig`: `{seed, floor, player: {hero_def_id, deck: def_id[],
   hook_installers (treasures)}, boss: {boss_def_id, deck: def_id[], hook_installers (passive),
   ai_id}}`. The engine seeds the `match` RNG stream from `seed` (DD-T03).
2. Heroes are created. Player health = `STARTING_HEALTH_PLAYER` (30); boss health comes from the
   boss definition, defaulting to DD-M02's band values (30 / 40 / 50). Armour 0, mana 0/0,
   `fatigue_counter` 0.
3. Each deck list is instantiated to `CardInstance`s in list order, then shuffled with the `match`
   stream — player deck first, then boss deck (order matters for determinism). `deck_shuffled`
   is emitted per side with the resulting instance order.
4. `on_match_start` hooks run (Treasures, boss passive) **before** any card is drawn, so a hook
   may alter starting health, armour, mana or hand size (hook list in Interactions).
5. Starting hands: the player draws `STARTING_HAND_PLAYER` (3), then the boss draws
   `STARTING_HAND_BOSS` (4). The fourth boss card is DD-M03's compensation for the player always
   acting first; there is no Coin.
6. Phase → **Mulligan**; `mulligan_offered` lists the player's hand. The boss does not mulligan in
   v1 (Boss AI may request one later; see Open Questions).
7. On `mulligan(keep_mask)`: cards whose mask bit is false are returned to the deck, the deck is
   shuffled, and the same number of cards is drawn. Per DD-M05 the return happens **before** the
   redraw, so a returned card can be drawn again — this is intended, not a bug. One round only
   (`MULLIGAN_ROUNDS` = 1). A mask of all `true` is a legal "keep all".
8. `match_started` is emitted and the engine runs the Start step for PLAYER on turn 1 (DD-M03).

#### C4. Turn structure

**Start step** for side S (engine-initiated; no commands accepted until Main):

1. `phase = Start(S)`, `turn += 1` (the very first Start sets it to 1), `S.turns_taken += 1`;
   emit `turn_started`.
2. Mana: `mana_max = min(mana_max + 1, MAX_MANA)`, then `mana_current = mana_max` (DD-M04). Emit
   `crystal_gained` when `mana_max` rose and `mana_refilled` always. Turn 1 therefore starts with
   1/1 for the player and, on the boss's first turn, 1/1 for the boss.
3. Reset: for every S character `attacks_used = 0`; for every S minion `summoning_sick = false`;
   `hero_power.used_this_turn = false`. These bulk resets emit one `turn_reset` event listing the
   affected entity ids (DD-T04 counts the reset as one mutation).
4. `on_turn_start(S)` hooks run in installation order, each as its own step.
5. Triggers: the engine fires the trigger point `turn_start` with `side = S`; Card Effects selects
   which board effects respond. Candidate order is fixed: S's board left to right, S's weapon,
   S's hero power/hero enchantments, then the opponent's board left to right (for "at the start of
   your opponent's turn" effects). Each trigger resolves as its own step (C10).
6. Draw one card (C11). Yes, on turn 1 too — the player ends turn 1 with 4 cards in hand.
7. Win/loss check (C14). If the match has not ended, `phase = Main(S)`.

**Main step**: the engine accepts commands from S until `end_turn`, `concede`, or the match ends.
There is no action limit and no timer.

**End step** (entered by `end_turn`):

1. `phase = End(S)`; emit `turn_ending`.
2. Triggers: fire `turn_end` with `side = S`, same candidate order as step 5 above.
3. `on_turn_end(S)` hooks run.
4. Thaw: apply the thaw rule (C13) to every S character.
5. Enchantments with `expires = end_of_turn` owned by S characters are removed (one
   `enchantment_removed` each); auras recomputed.
6. Win/loss check; emit `turn_ended`; `active_side` flips; the Start step runs for the other side.

#### C5. Mana and costs

- A card's **effective cost** is F1: base cost plus all modifiers, floored at 0. Modifier sources,
  applied in this order: enchantments on the card instance (Card Effects, e.g. "costs 1 less
  this turn"), auras from minions in play whose aura scope is `hand`, then every `modify_cost`
  hook (Treasures, boss passive) in installation order.
- Mana is paid at command acceptance, before any effect resolves, and is never refunded — a
  Battlecry that fizzles still cost its mana. Rationale: refunds make the log harder to read than
  the occasional wasted play.
- `mana_current` never exceeds `mana_max` and never drops below 0. There is no Overload, no
  temporary crystal gain and no crystal destruction in v1; Card Effects may add operations
  `gain_mana(n, temporary)` later through the engine API `add_mana`, which clamps to `MAX_MANA`.
- The hero power's cost is `HERO_POWER_COST` (2, DD-M13) and goes through the same F1 pipeline.

#### C6. Playing cards

**Minions** (`play_card` with `position`):

1. Validation order: phase/turn → `hand_index` in range → card is a minion → effective cost ≤
   `mana_current` → `board.size < BOARD_SIZE` else `BOARD_FULL` → `0 ≤ position ≤ board.size`
   (an insertion index; `board.size` means rightmost) else `INVALID_POSITION` → targeting: if the
   minion's Battlecry declares `targeting = required` and at least one legal target exists, a
   legal `target_id` must be supplied (`TARGET_REQUIRED` / `ILLEGAL_TARGET`); if **no** legal
   target exists the minion is still playable and the Battlecry will not resolve (Hearthstone
   rule — a body is still a body); `targeting = optional` accepts null; `targeting = none`
   ignores `target_id`.
2. Pay mana. Move the card to `board[position]`; create the minion with `summoning_sick = true`,
   `attacks_used = 0`, `summoned_on_turn = turn`; emit `card_played` then `minion_summoned`
   (played minions emit both; minions summoned by effects emit only `minion_summoned`).
3. Resolve in this fixed order, each as its own step: (a) the minion's **Battlecry** (trigger
   point `battlecry`, target as chosen), (b) `on_card_played` hooks, (c) observer triggers
   `on_play` (minion played), (d) observer triggers `on_summon`. Rationale: Battlecry-first is
   what players expect from Hearthstone and keeps "whenever you summon" effects from seeing a
   half-resolved board.
4. The resolution loop (C10) runs after each step; the command returns when it is stable.

**Spells**:

1. Validation: phase/turn → index → type → cost → targeting: `required` with no legal target →
   `NO_LEGAL_TARGET` (the spell is **not playable**; the UI shows it dimmed); `required` with
   targets → `target_id` must be legal; `optional` → null allowed; `none` → ignored.
2. Pay mana; the card moves to zone `resolving`; emit `spell_cast` (payload includes the
   caster's current Spell Damage total, F7, so the log explains the numbers).
3. Resolve the spell's effect through Card Effects (one or more steps). Then `after_cast`
   observer triggers. The card then moves to the graveyard (`card_to_graveyard`).
4. A spell's "no legal target" test ignores enemy Stealth characters (they are not legal targets)
   but counts friendly ones. There is no spell immunity or "Elusive" in v1 (DD-M09).

**Weapons**:

1. Validation: phase/turn → index → type → cost → targeting as for minions (weapon Battlecries
   follow the minion rule).
2. Pay mana. If a weapon is already equipped it is destroyed first (`weapon_destroyed`; its
   Deathrattle is queued, C10). Then the new weapon is created and `weapon_equipped` is emitted.
3. The weapon's Battlecry (if any) resolves after equip, then `on_card_played` hooks.
4. Equipping never resets the hero's `attacks_used`; because `attacks_remaining` is derived
   (C1), equipping a Windfury weapon after one attack leaves one more attack available, and
   replacing it with a non-Windfury weapon leaves none.

#### C7. Hero power

The hero power is a 2-mana, once-per-turn effect defined in the effect DSL exactly like a spell
(DD-M13). Validation: phase/turn → `used_this_turn` is false else `HERO_POWER_USED` → effective
cost ≤ mana → targeting rules identical to spells (a `required` power with no legal target is not
usable). On acceptance: pay cost, set `used_this_turn = true`, emit `hero_power_used`, resolve
through Card Effects (trigger point `hero_power`). Its content (what War's power does) lives in
Heroes and Card Effects, not here.

#### C8. Attacking

An attack is legal when the predicate `can_attack(A, D)` (F3) is true. In words, honouring
DD-M10:

- Only the active side's characters attack, only in Main.
- The attacker needs `attack > 0`, `attacks_remaining > 0`, and must not be Frozen.
- A summoning-sick minion may attack only with Charge (any target) or Rush (minions only).
- The defender must be an enemy character that is alive and in play; an enemy minion with
  Stealth cannot be chosen.
- **Taunt rule**: if the defending side has at least one minion with Taunt that does **not** also
  have Stealth, the defender must be one of those minions.
- A hero attacks with `attack = weapon.attack + hero attack enchantments`; a hero with no weapon
  and no attack buff has attack 0 and cannot attack.

Resolution of an accepted `attack(A, D)`, in order:

1. Emit `attack_declared`. If A has Stealth, remove it now (`stealth_lost`).
2. Fire trigger point `on_attack` (A, D). Each response is a step with the full loop (C10).
3. **Re-check**: if A or D is no longer in play (died, bounced, transformed), the attack is
   cancelled — emit `attack_cancelled` — and A's `attacks_used` is still incremented (the swing
   was committed). If both are still in play the attack proceeds **even if** a Taunt appeared or
   D lost Taunt in step 2; legality is evaluated once, at declaration.
4. **Simultaneous damage** (one step, DD-M11): A deals `A.attack` to D, and D deals `D.attack` to
   A if `D.attack > 0` (a hero with no weapon deals 0). Both `damage_dealt` events are emitted
   in that order; no death check runs between them. Divine Shield, Poisonous and Lifesteal are
   applied per F2 inside this step. If A is a hero with a weapon, `weapon.durability −= 1`
   (`weapon_durability_changed`) in the same step.
5. `A.attacks_used += 1`.
6. Run the resolution loop (C10): `on_damage` triggers, deaths, deathrattles, auras. A weapon at
   durability ≤ 0 is destroyed in the death check.
7. Emit `attack_resolved`; win/loss check.

Windfury: `max_attacks = 2`, so the same attacker may be submitted again as a new command; if
its first target died, the second attack simply needs a new legal target (see Edge Cases).

#### C9. Damage, healing and armour

- **Damage** always goes through F2 (`apply_damage`), whatever its source (attack, spell, fatigue,
  hero power, trigger). Order inside F2: `modify_damage` hooks → Divine Shield → armour →
  `damage_taken`. Only the amount that reached `damage_taken` or armour counts as "dealt" for
  Lifesteal and for `stats.damage_dealt_by_card`.
- **Divine Shield**: if the target has it and the incoming amount is > 0, the shield is removed
  (`divine_shield_popped`) and **no** damage is dealt — no `on_damage` trigger, no Poisonous, no
  Lifesteal heal. A 0-damage hit does not pop a shield.
- **Armour** (heroes only): absorbed first; `armor_lost` is emitted; the remainder goes to health.
  Armour has no cap.
- **Poisonous**: if the source has Poisonous and the target is a minion that received > 0 damage,
  the target is marked `pending_destroy` and dies in the next death check regardless of health.
  Heroes are immune to Poisonous.
- **Lifesteal**: after damage is dealt, the source's controller's hero is healed by the amount
  dealt (armour absorbed counts as dealt). Lifesteal on a weapon applies to hero attacks with it.
- **Healing** (`apply_heal`): minions: `damage_taken = max(0, damage_taken − amount)`; heroes:
  `health = min(max_health, health + amount)`. The amount actually restored is in the `healed`
  event (a full-health target heals 0 and still emits). `modify_heal` hooks run first.
- **Gain armour** (`apply_armor`): `armor += amount`, uncapped, emit `armor_gained`.
- **Set/raise health** and stat buffs go through `apply_enchantment`; the engine never writes
  `base_*` after creation except via Silence (C13) or a `transform` operation that recreates the
  character with a new `entity_id`.

#### C10. Death resolution and trigger ordering

This is the rule that makes Pillar 4 true. Every action runs the same loop:

```
run_action(initial_step):
  execute(initial_step)                       # mutations + events; may raise triggers → Q (raise order)
  loop:
    dead = death_check()                      # see below; queues deathrattles onto Q
    recompute_auras()
    if dead is empty and Q is empty: break
    if Q is empty: continue                   # aura loss may have killed something → re-check
    t = Q.pop_front()
    execute(t)                                # one step; may raise more triggers (appended)
  win_loss_check()
```

- **death_check()** marks every minion with `health ≤ 0` or `pending_destroy`, and every weapon
  with `durability ≤ 0`. All marked entities leave play in the **same** step (they do not see each
  other die): `minion_died` / `weapon_destroyed` events in order player board left to right,
  boss board left to right, player weapon, boss weapon (DD-M11). Their Deathrattles are appended
  to Q in exactly that order; a character with several Deathrattles queues them in enchantment
  order (base first). Then `on_minion_died` observer triggers are raised for every observer still
  in play — a minion that died in the same check observes nothing.
- **Triggers queue, never nest.** Anything raised while a step executes (e.g. `on_damage` from
  combat) is appended to Q and resolves after the current step and its death check. Because
  combat's `on_damage` triggers are queued before the death check runs, they resolve **before**
  the Deathrattles of minions that died from the same hit.
- **A queued trigger always resolves**, even if its source has since left play (it was earned
  when raised). Its effect reads a snapshot of the source's stats taken at raise time. Exception:
  nothing is queued for a source that was not in play at raise time. Rationale: "did it fire or
  not" must be answerable from the log without knowing Hearthstone trivia.
- **recompute_auras()** strips every `is_aura` enchantment, then re-applies auras from every
  living aura source in board order (player left to right, then boss). Aura loss reduces
  `max_health` while `damage_taken` is untouched (F6), so a minion kept alive by an aura dies in
  the next pass of the loop. One `auras_recomputed` event lists net stat changes.
- **Summons during the loop** (Deathrattle "summon a 2/2") go through `summon_minion(side,
  def_id, position)`, which inserts at the dead minion's former index when it still fits, else at
  the rightmost slot; a full board makes the summon a no-op with a `summon_failed` event.
- **Loop safety**: the loop aborts the match with reason `resolution_overflow` after
  `RESOLUTION_STEP_CAP` steps (default 1000) — a content bug, surfaced loudly rather than hung.

#### C11. Hand, draw, burn and fatigue

```
draw(side):
  if deck is empty:
    fatigue_counter += 1
    apply_damage(hero, fatigue_counter, source = FATIGUE)   # armour applies (F2); emit fatigue_damage
    return
  card = deck.pop_front()
  if hand.size >= HAND_SIZE:
    card → graveyard; emit card_burned; return               # no on_draw triggers (DD-M06)
  hand.append(card); emit card_drawn; raise on_draw triggers
```

- Fatigue (DD-M07) deals 1, 2, 3… per draw from an empty deck, per side, for the rest of the
  match; the counter never resets. Burned cards are logged with their definition id so the UI can
  show what was lost. Effects that "draw N" call `draw` N times, so a 2-card draw with 1 card left
  draws one and takes 1 fatigue.
- `HAND_SIZE` is 10. The hand is ordered (new cards append right); position in hand has no rules
  meaning beyond `hand_index`.

#### C12. Keyword semantics (v1 set, DD-M09)

| Keyword | Applies to | Effect | Interaction notes |
|---|---|---|---|
| **Taunt** | Minion | Enemy attackers must target a Taunt minion if one exists | Ignored while the same minion has Stealth; Silence removes it; a Taunt gained mid-attack does not redirect that attack |
| **Charge** | Minion | May attack any target on the turn it enters play | Overrides summoning sickness fully; irrelevant from the next turn |
| **Rush** | Minion | May attack **minions** on the turn it enters play | Hero target → `RUSH_CANNOT_HIT_HERO` that turn only; Charge supersedes Rush if both |
| **Divine Shield** | Minion | The next instance of damage > 0 is prevented and the shield is removed | Prevents Poisonous, Lifesteal heal and `on_damage`; not consumed by 0 damage; Silence removes it |
| **Windfury** | Minion, Weapon | `max_attacks = 2` per turn | Derived live: gaining Windfury mid-turn after one attack grants one more; losing it after one attack leaves none |
| **Stealth** | Minion | Cannot be targeted by enemy attacks or enemy targeted effects | Lost when the minion attacks (at declaration); random and area effects still hit it; does not enforce its own Taunt |
| **Lifesteal** | Minion, Weapon, Spell | Damage dealt by this source heals its controller's hero by the same amount | Heal is one step after the damage; heals 0 when the damage was fully prevented by Divine Shield |
| **Poisonous** | Minion, Weapon | Any damage > 0 to a minion destroys it | No effect on heroes; blocked by Divine Shield; the kill resolves in the death check, so a Deathrattle still fires |
| **Freeze** | Character (status) | Frozen characters cannot attack | Thaw rule in C13; Silence thaws; freezing an already-frozen character re-stamps `frozen_on_turn` |
| **Silence** | Minion (operation) | Removes keywords, enchantments, Deathrattles, triggered and aura effects from the target | Does not remove summoning sickness, damage already taken, or `pending_destroy`; C13 |
| **Battlecry** | Minion, Weapon | Effect when **played** from hand | Does not fire when summoned by an effect; first step of a play (C6); fizzles without a required target |
| **Deathrattle** | Minion, Weapon | Effect when it leaves play by dying/breaking | Queued in board order (C10); fires even if the source was Silenced **after** it died (impossible) but not if Silenced before |
| **Spell Damage +N** | Minion | Spells cast by the controller deal N more damage | Summed over the controller's board (F7); applied by Card Effects to spell damage operations only |
| **Discover** | Spell/Battlecry (operation) | Offer 3 options, the controller picks 1 | Options drawn from the `match` RNG stream; enters the Choice phase (States); Boss AI chooses for the boss |
| **Aura** | Minion | Static buff while the source is in play | Recomputed after every step (C10); never stacks with itself from the same source; source Silence ends it |

Summoning sickness (DD-M10) is a state, not a keyword: a minion that entered play this turn has
`summoning_sick = true` until its controller's next Start step.

#### C13. Freeze and Silence semantics

**Freeze.** `freeze(target)` sets `frozen = true` and `frozen_on_turn = turn`, emitting `frozen`.
A frozen character fails `can_attack` (`ATTACKER_FROZEN`); a frozen hero cannot swing its weapon
but keeps it. **Thaw rule**, applied in the controller's End step: the character thaws
(`thawed`) if `frozen_on_turn < turn` (it was frozen before this turn began — it has now missed
its attack) **or** `attacks_remaining == 0` (it had already used its attacks when frozen). Otherwise
it was frozen during its own turn before attacking, stays Frozen through the next turn, and thaws
at that turn's End step. This matches Hearthstone's three cases with one rule and no hidden
counter.

**Silence.** `silence(target)` on a minion, in one step: (1) remove every non-aura enchantment on
the target (aura enchantments it *receives* from other sources are re-applied by the next
`recompute_auras()` — Silence stops the target's own aura **emission**, not its reception);
(2) clear all keywords, Deathrattles and triggered effects granted by the definition or by
enchantments; (3) set `silenced = true` so Card Effects skips the definition's triggers for this
entity; (4) clamp damage with F6's Silence rule — `damage_taken = max(0, damage_taken −
(old_max_health − new_max_health))` — so a buffed, damaged minion keeps its current health where
possible but never exceeds its new maximum; (5) `frozen = false`; (6) emit `silenced`. Silence
does **not** clear `summoning_sick`, `attacks_used` or `pending_destroy`, and does not restore
health lost to damage.

#### C14. Win, loss and concede

- `win_loss_check()` runs at the end of every action's resolution loop (C10) and at the points
  named in C4, never mid-loop — "a hero at 0 or less health loses when the current action finishes
  resolving" (DD-M12). Deathrattles queued before the hero dropped to 0 still resolve first.
- Outcomes: both heroes ≤ 0 → **boss wins**, reason `both_dead` (DD-M12). Only the player's hero
  ≤ 0 → boss wins, `hero_dead`. Only the boss's hero ≤ 0 → player wins, `hero_dead`.
- `concede` is accepted from the player in any phase except Ended, including Mulligan, Choice and
  during the boss's turn (the engine is synchronous, so the boss's in-flight command completes
  before the concede is processed). Winner BOSS, reason `concede`.
- `TURN_CAP` (default 100 global turns): when the Start step would begin turn `TURN_CAP + 1`, the
  match ends with winner BOSS, reason `turn_cap`. This is a termination guarantee for AI-vs-AI
  simulation; fatigue makes it unreachable in normal play.
- On end: `phase = Ended`, `result = {winner, reason, turns (global), turns_per_side, player
  stats, boss stats, final hero health both sides, seed}` is emitted as `match_ended` and returned
  to Run Structure. Every later command is rejected `MATCH_ENDED`.

#### C15. Event vocabulary

Every mutation emits exactly one event `{seq, type, payload}` (DD-T04); the UI renders from
events only. The v1 event types, grouped: **lifecycle** `match_started`, `deck_shuffled`,
`mulligan_offered`, `mulligan_resolved`, `turn_started`, `turn_reset`, `turn_ending`,
`turn_ended`, `phase_changed`, `match_ended`; **resources** `crystal_gained`, `mana_refilled`,
`mana_spent`, `mana_added`; **cards** `card_drawn`, `card_burned`, `fatigue_damage`,
`card_played`, `spell_cast`, `card_to_graveyard`, `minion_summoned`, `summon_failed`,
`weapon_equipped`, `weapon_destroyed`, `weapon_durability_changed`, `hero_power_used`;
**combat** `attack_declared`, `attack_cancelled`, `attack_resolved`, `damage_dealt`,
`divine_shield_popped`, `armor_lost`, `healed`, `armor_gained`; **status** `enchantment_applied`,
`enchantment_removed`, `auras_recomputed`, `frozen`, `thawed`, `silenced`, `stealth_lost`,
`minion_died`, `trigger_queued`, `trigger_resolved`, `choice_requested`, `choice_made`;
**diagnostics** `command_rejected` (logged, not a mutation — flagged `diagnostic: true`),
`resolution_overflow`. Payloads always carry the acting `entity_id`s and the resulting numbers
(e.g. `damage_dealt {source, target, requested, prevented, armor_absorbed, dealt, health_after}`)
so the log alone explains the outcome.

### States and Transitions

**Match phase state machine.** `phase` is one of the states below. `Resolving` is a real state —
the engine is in it for the whole of a `submit()` call — but it is never observable between calls
because the engine is synchronous; it exists so that re-entrant command submission (a UI event
handler calling `submit` from inside an event callback) is rejected rather than corrupting state.
`Choice` pauses a resolution mid-step and stores a continuation; `choose` resumes it.

| State | Entry condition | Exit condition | Behaviour / commands accepted |
|---|---|---|---|
| `Setup` | `RulesEngine.start(config)` called | Starting hands dealt | No commands; runs C3 steps 1–5 |
| `Mulligan` | Setup complete | `mulligan` accepted or `concede` | Accepts `mulligan` (PLAYER), `concede` |
| `PlayerTurn.Start` | Mulligan resolved, or `BossTurn.End` complete | C4 Start step finished | No commands; engine-driven |
| `PlayerTurn.Main` | Start step finished, match not ended | `end_turn`, `concede`, or match ended | Accepts `play_card`, `attack`, `use_hero_power`, `end_turn`, `concede` from PLAYER |
| `PlayerTurn.End` | `end_turn` accepted | C4 End step finished | No commands |
| `BossTurn.Start` | `PlayerTurn.End` complete | Start step finished | No commands |
| `BossTurn.Main` | Start step finished | Boss AI `end_turn`, player `concede`, or match ended | Accepts the same command set from BOSS; `concede` from PLAYER |
| `BossTurn.End` | `end_turn` accepted | End step finished | No commands |
| `Resolving` | Any accepted command or engine step begins | The C10 loop reaches stable | Any nested `submit` → `ENGINE_BUSY`; returns to the phase it came from |
| `Choice` | Card Effects raises a `ChoiceRequest` (Discover) during resolution | `choose` with a valid index | Accepts `choose` from the side named in `pending_choice` and `concede`; everything else → `CHOICE_PENDING` |
| `Ended` | `win_loss_check` finds a dead hero, `concede`, `turn_cap`, or `resolution_overflow` | Never (terminal) | Every command → `MATCH_ENDED`; `result` is populated |

**Transition table** (explicit, per `.claude/rules/gameplay-code.md`):

| From | Trigger | Guard | To | Side effects |
|---|---|---|---|---|
| `Setup` | hands dealt | — | `Mulligan` | `mulligan_offered` |
| `Mulligan` | `mulligan(mask)` | mask length = hand size | `PlayerTurn.Start` | `mulligan_resolved`, `match_started` |
| `Mulligan` | `concede` | — | `Ended` | `match_ended(reason=concede)` |
| `PlayerTurn.Start` | Start step done | no hero ≤ 0, `turn ≤ TURN_CAP` | `PlayerTurn.Main` | `phase_changed` |
| `PlayerTurn.Start` | Start step done | a hero ≤ 0 | `Ended` | `match_ended` |
| `PlayerTurn.Start` | Start step begins | `turn > TURN_CAP` | `Ended` | `match_ended(reason=turn_cap)` |
| `*Turn.Main` | any accepted command | — | `Resolving` | (events of the command) |
| `Resolving` | loop stable | no hero ≤ 0 | the originating `Main` / `Start` / `End` | `phase_changed` only if the phase differs |
| `Resolving` | loop stable | a hero ≤ 0 | `Ended` | `match_ended` |
| `Resolving` | `ChoiceRequest` raised | — | `Choice` | `choice_requested` |
| `Choice` | `choose(i)` | `0 ≤ i < options.size` | `Resolving` | `choice_made`; continuation resumes |
| `Choice` | `concede` | — | `Ended` | `match_ended(reason=concede)` |
| `PlayerTurn.Main` | `end_turn` | — | `PlayerTurn.End` | `turn_ending` |
| `PlayerTurn.End` | End step done | no hero ≤ 0 | `BossTurn.Start` | `turn_ended`, `active_side = BOSS` |
| `BossTurn.Start` | Start step done | no hero ≤ 0 | `BossTurn.Main` | `phase_changed` |
| `BossTurn.Main` | `end_turn` (Boss AI) | — | `BossTurn.End` | `turn_ending` |
| `BossTurn.Main` | `concede` (player) | — | `Ended` | `match_ended(reason=concede)` |
| `BossTurn.End` | End step done | no hero ≤ 0 | `PlayerTurn.Start` | `turn_ended`, `active_side = PLAYER` |
| `*Turn.Start` / `*Turn.End` | step done | a hero ≤ 0 | `Ended` | `match_ended` |
| `Resolving` | step count > `RESOLUTION_STEP_CAP` | — | `Ended` | `resolution_overflow`, `match_ended(reason=resolution_overflow, winner=BOSS)` |

Any (state, command) pair not in the tables above is rejected with `WRONG_PHASE`, or
`NOT_YOUR_TURN` when the phase is right but the issuer is not the active side.

**Character status sub-states** (orthogonal flags on a character, all observable):
`summoning_sick` (set on entering play, cleared at the controller's next Start step),
`frozen` (set by `freeze`, cleared by the thaw rule or Silence), `stealth` (keyword; cleared at
attack declaration or by Silence), `divine_shield` (keyword; cleared by the first damage > 0 or
Silence), `pending_destroy` (set by Poisonous or a `destroy` operation; cleared only by leaving
play), `silenced` (set once, never cleared).

### Interactions with Other Systems

The engine has exactly two kinds of boundary: **commands in / events out** (UI, AI, Run
Structure) and **the effect boundary** (Card Effects, Treasures, Heroes), where other systems
mutate state only through the engine's primitives so that DD-T04 holds.

| System | Direction | Data in | Data out | Owner of the interface |
|---|---|---|---|---|
| **Card Database** | upstream | Card, hero, boss and weapon definitions by `def_id` (cost, type, attack, health, durability, keywords, effect spec, targeting spec) | None — read-only | Card Database defines the record shapes; this GDD names the fields it reads |
| **RNG & Event Log** | upstream | The `match` stream (`shuffle(list)`, `pick(list)`, `range(n)`); the append-only log | Every event in C15 via `log.append(type, payload)`; `seq` assigned by the log | RNG & Event Log; this GDD never seeds or reseeds |
| **Card Effects** | downstream (calls back in) | The resolver: `resolve(trigger_point, context) → steps`, `legal_targets(targeting_spec, source) → entity_id[]`, `ChoiceRequest`s | The engine **primitive API** listed below; `MatchState` read access | This GDD owns the primitive API and trigger points; Card Effects owns the DSL |
| **Boss AI** | downstream | Commands via `submit`; reads `legal_commands()` and `MatchState.clone()` | `CommandResult`s, `ChoiceRequest`s for the boss | This GDD; AI is just another command issuer |
| **Heroes** | upstream (data) | Hero definition: starting health, hero power def, starter deck list | None | Heroes (via Card Database records) |
| **Treasures** | upstream (installs hooks) | `hook_installers` in `MatchConfig`; hook implementations | Hook invocations with context (table below) | This GDD owns the hook points; Treasures owns what they do |
| **Match UI** | downstream | Commands from the player; `legal_commands()` for highlighting | The event stream; `command_rejected` diagnostics with codes for messaging | This GDD; UI is display-only over events |
| **Run Structure** | upstream & downstream | `MatchConfig` (C3 step 1) | `MatchResult` (C14) when `Ended` | Run Structure owns the config and result record shapes beyond the fields named here |

**Engine primitive API** — the only way anyone mutates match state (each call = one step or one
mutation with one event): `draw(side, n)`, `apply_damage(target, amount, source)`,
`apply_heal(target, amount, source)`, `apply_armor(side, amount)`, `apply_enchantment(target,
enchantment)`, `remove_enchantment(target, id)`, `summon_minion(side, def_id, position)`,
`destroy(target)`, `silence(target)`, `freeze(target)`, `add_keyword(target, kw)`,
`return_to_hand(target)`, `transform(target, def_id)`, `add_mana(side, n, temporary)`,
`equip_weapon(side, def_id)`, `discover(side, options) → ChoiceRequest`, `add_card_to_hand(side,
def_id)`, `set_stats(target, attack, health)`. Card Effects composes card text from these; it
never writes a field directly.

**Trigger points the engine fires** (Card Effects decides who responds): `battlecry`, `on_play`,
`on_summon`, `on_cast` / `after_cast`, `hero_power`, `turn_start(side)`, `turn_end(side)`,
`on_attack(attacker, defender)`, `on_damage(target, amount, source)`, `on_heal`,
`on_minion_died(minion)`, `deathrattle(entity)`, `on_draw(card)`, `on_card_played(card)`,
`on_weapon_equipped`. Candidate ordering is always board order, player side first (C4, C10).

**Hook points exposed to Treasures and boss passives** (`HookRegistry`; hooks run in installation
order — treasures in pick order, then the boss passive — and may call primitives):

| Hook | Signature | Called when | May return |
|---|---|---|---|
| `on_match_start` | `(state, side)` | C3 step 4, before starting hands | — (mutates via primitives: starting health, armour, mana, extra draws) |
| `on_turn_start` | `(state, side)` | C4 Start step 4 | — |
| `on_turn_end` | `(state, side)` | C4 End step 3 | — |
| `modify_cost` | `(card_instance, side, cost_so_far) → int` | Every F1 evaluation (display and payment) | New cost (engine floors at 0) |
| `modify_damage` | `(source, target, amount) → int` | First stage of F2 | New amount (engine floors at 0) |
| `modify_heal` | `(source, target, amount) → int` | Before `apply_heal` | New amount |
| `on_card_played` | `(card_instance, side)` | C6 after the card's own Battlecry/cast | — |
| `on_minion_summoned` | `(minion)` | After any `summon_minion` or play | — |
| `on_hero_damaged` | `(side, amount_dealt, source)` | After F2 when the target is a hero | — |
| `on_draw` | `(side, card_instance)` | After a successful draw (not a burn) | — |
| `modify_starting_hand_size` | `(side, n) → int` | C3 step 5 | New count |
| `modify_max_attacks` | `(character, n) → int` | Each `max_attacks` evaluation | New count (e.g. a "your hero has Windfury" treasure) |

A hook that needs a rule not in this table is a GDD change here, not a workaround in Treasures.

## Formulas

`systems-designer` not consulted — Lean mode. Review manually before production. All `Source =
data file` variables live in `assets/data/match_rules.json` and are listed in Tuning Knobs.

### F1. Effective cost

The `effective_cost` formula is defined as:

`effective_cost = max(0, base_cost + Σ card_enchantment_delta + Σ hand_aura_delta + Σ hook_delta)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| base_cost | int | 0–10 | data file (card definition) | Printed cost |
| card_enchantment_delta | int | −10 to +10 | calculated | Sum of cost enchantments on the card instance (Card Effects) |
| hand_aura_delta | int | −10 to +10 | calculated | Sum of hand-scoped auras from minions in play |
| hook_delta | int | −10 to +10 | calculated | Net change applied by `modify_cost` hooks in installation order |

**Output Range:** 0 to 10 under normal play; negative sums clamp to 0 (a free card, never refunded
mana). **Example:** a 4-cost spell with "costs 2 less" and a treasure "spells cost 1 less" →
`max(0, 4 − 2 − 1) = 1`.

### F2. Damage application

The `apply_damage` formula is defined as a pipeline evaluated in one step:

```
amount    = max(0, hooks.modify_damage(source, target, requested))
if target.divine_shield and amount > 0: prevented = amount; amount = 0; remove shield
armor_absorbed = min(target.armor, amount)          (heroes only; 0 for minions)
target.armor  -= armor_absorbed
to_health      = amount - armor_absorbed
target.damage_taken += to_health                     (hero: health -= to_health)
dealt          = armor_absorbed + to_health
if source.poisonous and target is minion and dealt > 0: target.pending_destroy = true
if source.lifesteal and dealt > 0: apply_heal(source.controller.hero, dealt)
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| requested | int | 0–99 | calculated | Damage asked for by the attack, spell (after Spell Damage, F7) or effect |
| amount | int | 0–99 | calculated | After `modify_damage` hooks, floored at 0 |
| prevented | int | 0–99 | calculated | Amount eaten by Divine Shield (logged) |
| armor | int | 0–∞ | state | Hero armour before the hit |
| dealt | int | 0–99 | calculated | What counts for Lifesteal, stats and `on_damage` |

**Output Range:** `dealt` ∈ [0, requested]; `health_after` may be negative (a 10-damage hit on 3
health records −7; death resolves at ≤ 0). **Example:** boss hero with 2 armour takes 5 from a
Lifesteal weapon: `armor_absorbed = 2`, `to_health = 3`, `dealt = 5`, player hero heals 5.

### F3. Attack legality predicate

The `can_attack` formula is defined as a conjunction evaluated left to right; the first false
term yields the rejection code in brackets:

```
can_attack(A, D) =
    phase == Main(A.controller)                                  [NOT_YOUR_TURN / WRONG_PHASE]
  ∧ A.attack > 0 ∧ attacks_remaining(A) > 0                      [CANNOT_ATTACK]
  ∧ ¬A.frozen                                                    [ATTACKER_FROZEN]
  ∧ (A is hero ∨ ¬A.summoning_sick ∨ A.charge ∨ (A.rush ∧ D is minion))
                                                                 [SUMMONING_SICK / RUSH_CANNOT_HIT_HERO]
  ∧ D.controller ≠ A.controller ∧ D in play                      [ILLEGAL_TARGET]
  ∧ ¬(D is minion ∧ D.stealth)                                   [TARGET_STEALTHED]
  ∧ (taunters(D.controller) = ∅ ∨ D ∈ taunters(D.controller))    [MUST_ATTACK_TAUNT]
where taunters(side) = { m ∈ side.board : m.taunt ∧ ¬m.stealth }
      attacks_remaining(A) = max_attacks(A) − A.attacks_used
      max_attacks(A) = hooks.modify_max_attacks(A, 2 if A.windfury else 1)
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| A.attack | int | 0–99 | calculated | Derived attack (C1); hero = weapon + buffs |
| attacks_used | int | 0–2 | state | Attacks this turn, reset at Start |
| max_attacks | int | 1–2 | calculated | 2 with Windfury (minion keyword or hero's weapon), else 1 |
| taunters | set | 0–7 entries | calculated | Enemy Taunt minions without Stealth |

**Output Range:** boolean. **Example:** a 3/2 Rush minion played this turn vs. an enemy board with
a Stealth Taunt: `taunters = ∅` (Stealth excludes it), so any enemy *minion* is legal; the enemy
hero is rejected `RUSH_CANNOT_HIT_HERO`.

### F4. Mana available by turn

The `mana_max(t)` formula is defined as:

`mana_max(t) = min(t_side, MAX_MANA)` where `t_side` is that side's own turn count (`turns_taken`)

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| t_side | int | 1–∞ | state | Number of Start steps this side has had |
| MAX_MANA | int | 7–10 | data file | Crystal cap (DD-M04: 10) |

**Output Range:** 1 to `MAX_MANA`; the player's crystals on their 10th turn and every turn after
equal 10. Total mana available over the first n turns is `Σ_{t=1..n} min(t, 10)` — 55 through
turn 10. **Example:** at global turn 7 (the player's 4th own turn, since the global counter
advances on every Start step) the player has 4 crystals; the boss reaches 4 at global turn 8.

### F5. Fatigue damage

The `fatigue_damage(k)` formula is defined as:

`fatigue_damage(k) = FATIGUE_BASE + (k − 1) × FATIGUE_STEP` for the k-th empty-deck draw by that side

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| k | int | 1–∞ | state | `fatigue_counter` after increment |
| FATIGUE_BASE | int | 1–3 | data file | First fatigue hit (DD-M07: 1) |
| FATIGUE_STEP | int | 1–2 | data file | Increase per subsequent hit (DD-M07: 1) |

**Output Range:** 1, 2, 3, … (cumulative 1, 3, 6, 10, 15 — a 30-health hero with no deck dies on
the 8th fatigue draw, cumulative 36). Armour absorbs fatigue (F2). **Example:** `k = 4` →
`1 + 3 × 1 = 4` damage.

### F6. Health, buff loss and Silence clamp

The `health` formula is defined as:

`health = base_health + Σ health_delta(enchantments) − damage_taken`

On **aura loss / enchantment removal**: `damage_taken` is unchanged, so `health` can fall to ≤ 0
and the minion dies at the next death check. On **Silence**:
`damage_taken' = max(0, damage_taken − (max_health_old − max_health_new))`.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| base_health | int | 1–30 | data file (card definition) | Printed health |
| health_delta | int | −10 to +20 | calculated | Per-enchantment health change |
| damage_taken | int | 0–∞ | state | Accumulated unhealed damage |

**Output Range:** `health` ≤ `max_health`; may be ≤ 0 transiently. **Example:** a 2/2 buffed to
2/4 and damaged to 2/1 (`damage_taken = 3`): aura leaves → `2 − 3 = −1`, dies; Silenced instead →
`damage_taken = max(0, 3 − 2) = 1`, health `2 − 1 = 1`, lives.

### F7. Spell Damage total

`spell_damage(side) = Σ_{m ∈ side.board} m.spell_damage_bonus` (plus hero enchantments); Card
Effects adds it to each spell damage operation's `requested` before F2. Range 0–10 in v1 content.

### F8. Expected match length model

The `turns_to_lethal` model is defined as the smallest n with cumulative face damage ≥ hero
health:

`cumulative_damage(n) = k × Σ_{t=1..n} min(t, MAX_MANA)` → `turns_to_lethal = min{ n : cumulative_damage(n) ≥ H }`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| k | float | 0.4–1.0 | calculated (Content/`/balance-check`) | Average face damage per mana actually spent, after trades |
| H | int | 25–50 | data file | Defending hero's starting health (DD-M02) |
| n | int | 1–∞ | calculated | Turns for that side |

**Output Range:** the design target is **6–10 turns per side (3–6 minutes)**. With H = 30:
k = 0.6 → n = 10 (cum. 33 at turn 10); k = 0.8 → n = 8 (cum. 28.8 at turn 8, 36 at 9 → 9);
k = 1.0 → n = 8 (cum. 36 at turn 8). Band-3 bosses at H = 50 with k = 0.8 → n = 11, which is
why band 3 should also raise the player's k (stronger drafted deck) rather than only H. The knobs
that move n: `STARTING_HEALTH_PLAYER`, boss band health, `MAX_MANA` (lower cap flattens the sum),
starting hand size (card advantage raises k), and Content's damage density (k itself).

### F9. Limits (constants)

`BOARD_SIZE = 7`, `HAND_SIZE = 10`, `STARTING_HAND_PLAYER = 3`, `STARTING_HAND_BOSS = 4`,
`MAX_MANA = 10`, `HERO_POWER_COST = 2`, `MULLIGAN_ROUNDS = 1`, `TURN_CAP = 100`,
`RESOLUTION_STEP_CAP = 1000`. Insert positions are `0..board.size` inclusive; hand indices are
`0..hand.size − 1`.

## Edge Cases

`systems-designer` not consulted — Lean mode. Review manually before production. Each entry
names the exact outcome; "the engine decides" is not an answer here.

**Win/loss**

- **If both heroes reach ≤ 0 health in the same action** (e.g. a Deathrattle that damages both
  heroes, or fatigue on a turn where a Lifesteal trade kills the boss): the loop finishes, then
  `win_loss_check` finds both dead → **boss wins, reason `both_dead`** (DD-M12). The log shows both
  `damage_dealt` events, so the player can see it was a tie broken by rule.
- **If the player's hero drops to ≤ 0 mid-loop and a later Deathrattle in the same loop heals it
  above 0**: the check runs only at the end of the loop, so the hero survives. Legible and
  consistent with "when the current action finishes resolving".
- **If `concede` is issued during the boss's turn**: it is accepted; the engine is synchronous so
  the boss's current command has already returned; the match ends immediately with `concede`,
  the boss's remaining planned actions never happen, and Run Structure receives a result with
  `winner = BOSS`.
- **If a command arrives while the engine is Resolving** (re-entrant call from an event
  handler): rejected `ENGINE_BUSY`, no state change, `command_rejected` logged as diagnostic.
- **If a command arrives after Ended**: rejected `MATCH_ENDED`.
- **If a resolution loop exceeds `RESOLUTION_STEP_CAP`**: match ends, winner BOSS, reason
  `resolution_overflow`; the UI shows a "rules error" screen and the run continues as a loss. This
  is a content bug surfaced, not a design outcome.

**Board and summoning**

- **If a Deathrattle summons a minion onto a full board** (7 after other deaths resolved in the
  same check): `summon_minion` is a no-op and emits `summon_failed {reason: board_full}`. Death
  checks remove all dead minions **before** their Deathrattles run, so a board of 7 where one
  dies and its Deathrattle summons one does fit (6 + 1).
- **If a minion is played with `position > board.size`**: rejected `INVALID_POSITION`; negative
  positions likewise. `position == board.size` is the rightmost slot and legal.
- **If a Deathrattle summons and the dead minion's former index is now beyond the board end**
  (minions to its left also died): the summon goes to the rightmost slot.
- **If an aura source dies in the same step as the minions it buffs are damaged**: the death
  check removes the source, `recompute_auras` drops the buff, the loop re-runs the death check and
  buffed minions now at ≤ 0 die in the **next** pass — their Deathrattles queue after the source's
  Deathrattle. The log shows two `minion_died` groups in sequence.
- **If two auras from different sources overlap**: both apply (auras stack across sources, never
  from the same source twice).

**Combat**

- **If a Windfury attacker's first target dies**: the first `attack` command resolves normally
  (`attacks_used = 1`); the second attack is a new command that must name a new legal target
  (Taunt rule re-evaluated). There is no "continue attacking the same target" state.
- **If the hero is Frozen and holds a weapon**: `attack` is rejected `ATTACKER_FROZEN`; the weapon
  loses no durability; the hero power is still usable (Freeze affects attacks only).
- **If a Taunt minion is summoned or gains Taunt during `on_attack` triggers**: the declared
  attack proceeds against its original target (legality is checked once at declaration); the
  Taunt applies to the next attack.
- **If the defender dies or leaves play during `on_attack` triggers**: `attack_cancelled`, no
  damage either way, `attacks_used` still incremented.
- **If an attacker has 0 attack** (debuffed after being chosen in the UI): rejected
  `CANNOT_ATTACK`; a minion whose attack drops to 0 **during** combat still deals the attack value
  snapshotted at the damage step (step 4 reads `attack` once).
- **If the defender has Divine Shield and the attacker Poisonous**: the shield pops, 0 damage,
  the defender survives, the attacker still takes the defender's damage.
- **If the defender has Divine Shield and the attacker Lifesteal**: 0 dealt → 0 healed; the
  `healed` event is not emitted (there is no heal step when `dealt = 0`).
- **If a Rush minion is targeted at the enemy hero on its first turn**: `RUSH_CANNOT_HIT_HERO`;
  next turn it attacks anything (summoning sickness gone).
- **If the only enemy Taunt minion also has Stealth**: it is excluded from `taunters`, so the
  attacker may hit anything *except* that minion (Stealth still protects it).

**Keywords and status**

- **If Silence hits a minion with Divine Shield, Taunt and a Deathrattle**: all three are removed
  in one step; when it later dies no Deathrattle fires; a shield already popped is not restored.
- **If Silence hits a minion that was buffed by an aura from another minion**: the buff is removed
  by Silence and immediately re-applied by `recompute_auras` — net no change to received auras;
  only the Silenced minion's own emitted aura stops.
- **If a Frozen minion is Silenced**: it thaws immediately and may attack this turn if it has
  attacks remaining and is not summoning-sick.
- **If a character is Frozen twice in one turn**: `frozen_on_turn` is re-stamped; the thaw rule
  still evaluates once at the End step.
- **If a minion gains Windfury after attacking once this turn**: `attacks_remaining` becomes 1
  (derived); it may attack again.
- **If a Poisonous minion is killed by its defender in the simultaneous-damage step**: its poison
  still applies (both damages are in one step before any death check); both die together.

**Hand, draw and fatigue**

- **If the last card is drawn and a later draw happens in the same turn**: the first draw adds a
  card, the second applies fatigue 1 (counter 1). Drawing two from an empty deck in one effect
  applies 1 then 2.
- **If a Battlecry draws while the hand is full**: the drawn card is burned (`card_burned`),
  `on_draw` triggers do not fire, no fatigue is involved unless the deck is also empty — in which
  case fatigue damage applies and nothing is burned (there was no card).
- **If the hand is full at the Start-step draw**: the card is burned; the turn continues.
- **If the deck is empty at match start** (a 0-card deck from a malformed config): starting-hand
  draws apply fatigue 1, 2, 3 to that hero before the mulligan; the engine does not special-case
  it. Card Database validation should make this unreachable.

**Mulligan and setup**

- **If the mulligan returns cards and redraws one of the same cards**: allowed. DD-M05 returns
  cards before the redraw; the redraw is a fresh shuffle of the whole deck. Tests must not assert
  "never redraws the same card".
- **If `keep_mask` length differs from the hand size**: rejected `INVALID_MASK`.
- **If the boss has a 4-card hand and a treasure grants the player an extra starting card**:
  `modify_starting_hand_size` changes only the side it is called for; the mask length follows
  the resulting hand size.

**Targeting and playing**

- **If a spell requires a target and no legal target exists**: not playable (`NO_LEGAL_TARGET`).
  Optional-target spells are playable with `target_id = null`. A Battlecry minion with no legal
  target **is** playable and its Battlecry does not resolve. A hero power follows the spell rule.
- **If a chosen target becomes illegal between the UI's highlight and `submit`** (cannot happen
  in a single-threaded turn, but Boss AI may compute stale lists): rejected `ILLEGAL_TARGET`; the
  AI re-queries `legal_commands()`.
- **If a weapon is equipped while another is held**: the old weapon is destroyed first and its
  Deathrattle queues before the new weapon's Battlecry resolves.
- **If the hero power's cost is reduced to 0 by hooks**: still once per turn; `HERO_POWER_USED` on
  the second attempt.
- **If a Discover is raised during the boss's turn**: `Choice` is entered with
  `pending_choice.side = BOSS`; Boss AI must `choose`; the player's commands are rejected
  `CHOICE_PENDING` (except `concede`).

**Degenerate strategies** (identified, accepted or constrained)

- **Infinite heal/armour stalling**: fatigue grows without bound and `TURN_CAP` ends the match, so
  a stall always ends in a boss win; Content should avoid repeatable armour > fatigue rate.
- **Board-fill denial** (keeping 7 tokens so the boss cannot summon): legal; the boss AI should
  value removal when the player's board is full (Boss AI GDD).

## Dependencies

Hard = the engine cannot run a match without it; soft = the engine runs with a null
implementation. Bidirectionality: the systems index already lists every downstream row below as
depending on Match Rules; the sibling GDDs are expected to mirror these rows (checked by
`/consistency-check` once they land).

| System | Direction | Hard/Soft | Nature of dependency / interface |
|---|---|---|---|
| Card Database | This depends on Card Database | Hard | Reads card, hero, boss and weapon records by `def_id`: `cost`, `type`, `attack`, `health`, `durability`, `keywords[]`, `effect` (opaque to this GDD), `targeting {mode: none\|optional\|required, filter}`. Never parses JSON itself (DD-T01). |
| RNG & Event Log | This depends on RNG & Event Log | Hard | `match` stream for every shuffle and random pick (DD-T03); `log.append` for every event in C15 (DD-T04); `seq` numbering is the log's. Tests inject a fixed seed through it. |
| Card Effects | Card Effects depends on this | Hard (for them) | They implement the resolver behind the trigger points and call only the primitive API (Interactions). They never touch `MatchState` fields directly. Provisional: the resolver returns steps synchronously, or raises exactly one `ChoiceRequest` per Discover. |
| Boss AI | Boss AI depends on this | Hard (for them) | Consumes `legal_commands()`, `MatchState.clone()`, `submit()`, `ChoiceRequest`; receives typed rejections. Provisional: AI never relies on state outside `MatchState`. |
| Run Structure | Mutual | Hard | In: `MatchConfig` (C3). Out: `MatchResult` (C14). Run Structure owns save/resume **between** matches; an in-progress match is not saved in v1 (Open Questions). |
| Heroes | This depends on Heroes (data) | Hard | Player hero record: starting health (defaults to `STARTING_HEALTH_PLAYER`), hero power `def_id`, starter deck list. Heroes depends on this for the hero-power rule (2 mana, once per turn). |
| Treasures | Treasures depends on this | Soft | Installs hooks via `hook_installers`; with none installed every hook is identity. The hook table in Interactions is the contract; boss passives use the same table. |
| Match UI | Match UI depends on this | Soft (engine runs headless) | Sends player commands, renders the event stream, uses `command_rejected` codes for feedback and `legal_commands()` for highlights. Display-only. |
| Content | Content depends on this | Soft | Card text must be expressible as trigger points + primitives listed here; a card needing a new primitive is a GDD change here first. |

## Tuning Knobs

[To be designed]

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
