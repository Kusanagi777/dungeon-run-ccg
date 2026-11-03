# Treasures

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: Designed
> **Author**: Jacob (owner) + Claude (`/design-system treasures`, tier standard, guided, lean)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 1 (every run builds a deck you couldn't have planned) · Pillar 4 (readable, deterministic rules)
> **REVISED 2026-11-03** (`/design-review`, lean, verdict NEEDS REVISION → revised in session): T6 pool contract restated against the now-designed reward-draft.md (pool snapshot at `init_run`, exclusions derived from `drafts[]`, per-item rarity weights — `draft_state.offered_treasure_ids` no longer exists); T8 affinity tally corrected (10 universal / 4 war / 3 decay / 3 knowledge); Dependencies paragraph updated — every partner GDD now exists and bidirectionality was re-verified; R-8 closed (`treasures_balance.json` is already in DD-T01); AC-13 split into deterministic pre/post-R-5 forms; AC-14's "reference machine" replaced by a ratio; AC-17 tied to R-13; Open Questions gained the cross-GDD conflicts the review found (universal-tag detection, `unlock` field shape, unlock-state interface name, `once_per_turn` key for hosts without an `entity_id`, Run UI `synergy_tags`, Content CN-5 split) and R-14 now records that meta-progression M2.1 already accepts this GDD's four keys while its M10 table and the registry's `unlock_keys_v1` still list six placeholders.
> **REVISED 2026-11-03 (cross-review)**: C-06 (T1 `unlock` is the `{key, condition}` object, DD-X01; R-17 resolved) · C-02 (Hollow Crown rides match-rules' new `crystal_bonus`: T8 row 1, T9 sketch, Edge Cases, AC-9, AC-15 reworded to `mana_added` / `crystal_gained`; R-1 resolved) · C-19 (States: `unlock_granted`, meta M3.6) · C-26 ("contract — to be confirmed" markers removed from Interactions, Dependencies, F4; `unlocked_keys()` read once at `init_run`; `w_rarity` per item; F2 clamp markers and `MAX_ATTACKS_CAP = 4`; R-2, R-3, R-4, R-5, R-6, R-7, R-9, R-10, R-11, R-13, R-14, R-16, R-19, R-20 and the `aura`-on-weapon row closed against card-effects / match-rules / card-database / rng / run-structure / meta / reward-draft / run-ui / content; AC-13 re-issued in its post-R-5 form, AC-17's R-13 clause settled) · C-30 (States "Passed" row cites `drafts[]`; systems-index row closed per V-29). D-01 and D-03 assign no change to this GDD (D-03 is a Content/Meta choice still open with the owner).
> **REVISED 2026-11-03 (housekeeping)**: tray capacity is three chips (match-ui F6; ≤ 3 treasures per run, DD-R05) — Tuning Knobs `MAX_TREASURES_HELD` row and UI Requirements no longer say "≤ 4" / "fits 4"; T6 signature unified as `pool(unlocked_keys, exclude_ids)`; Dependencies paragraph's stale "undesigned / provisional" sentence dropped.
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` `systems-designer` and `qa-lead` not consulted for Formulas / Acceptance Criteria — Lean mode, no Agent tool in this session; review manually before production. Technical feasibility: category `Gameplay`, rule-only → Scripting domain; no engine reference for `scripting` under `docs/engine-reference/godot/modules/`, so feasibility was **not** checked against the pinned engine (the design has no engine surface: plain `RefCounted` data, DD-T02). Prior art: `docs/architecture/modifier-hook-chain.md` (reverse-documented prototype, not an ADR).

## Summary

Treasures are the passive, run-long rule changes the player picks after winning on floors 1, 3
and 5 — "your hero power costs (1)", "your minions have Rush", "start each match with an extra
Mana Crystal". Each is a data record whose effects are written in the Card Effects DSL and
installed, at every match start and in pick order, into the match's own hook chain (boss passives
use the same chain and install last). This GDD owns the data model, the owner-scoped hook-chain
semantics that retire the prototype's global modifier manager (TD-009), the 20-treasure v1 pool
with its rarity power budget, and the pool/unlock contracts Reward Draft and Meta Progression
build on.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Card Effects, Match Rules, Run Structure, Card Database, RNG & Event Log, Heroes; Reward Draft, Meta Progression`

## Overview

A treasure is a passive, run-long rule change the player picks after winning on floors 1, 3 and 5
(DD-R05): "your hero power costs (1)", "your minions have Rush", "start each match with an extra
Mana Crystal". The player does nothing with a treasure during a match — it sits in a tray on the
HUD and bends the rules in their favour every match for the rest of the run. Mechanically a
treasure is a `TreasureDef` record whose `effects[]` are written in the Card Effects DSL using the
hook-hosted triggers; at every match start Run Structure hands Treasures the run's picked ids in
pick order, Treasures returns one hook installer per treasure, and Match Rules installs them into
the match's own `HookRegistry` — treasures first in pick order, the boss passive last. Nothing is
applied at pick time and nothing survives the match except the id list, which is what makes
save/resume and restart idempotent. The system exists because Pillar 1 needs a draft pick that
changes *how the deck plays*, not just what is in it (the concept doc: "treasures are run-defining
rather than stat bumps"), and because boss passives need the same machinery from the other side of
the board (Pillar 2). It retires TD-009 — the prototype's global, singleton-backed modifier
manager — with a per-match, owner-scoped chain that holds no Node and no back-reference.

## Player Fantasy

`creative-director` not consulted — Lean mode. Review manually before production.

**Framing: direct.** The player chooses a treasure, reads it on the HUD every match and watches
the event feed credit it by name ("Thornhide Cloak: +1 Armour"). The feeling is **getting away
with something**: the rules everyone else plays by have one clause crossed out for you. A treasure
pick should feel like the moment in Monster Train or Dungeon Run where you stop asking "is this
card good?" and start asking "what does my run *do* now?" — the pick that turns a pile of drafted
cards into a plan. Pillar 1's design test applies verbatim: between a treasure that is "generically
good" and one that is "strong only with a plan", the pool leans to the plan-dependent one, so
roughly half the pool carries a hero or plan tag (Husks, weapons, spells) and the universal half
still changes a decision every turn (first card cheaper, hero power cheaper) rather than adding a
number nobody notices.

Three anchor moments: (1) **the reveal** — three cards face up after a win, each one sentence,
each obviously bending a different rule; (2) **the first fire** — the next match's first turn,
when the treasure visibly does its thing before any card is drawn (an extra crystal, a bigger
hand, a flare on the tray); (3) **the lean-in** — two floors later, passing a stronger bundle for
the one that feeds the treasure. Anti-reference: Slay the Spire's early-act relics that only add
+N to a stat — legible, but they never change a decision. Pillar 4 keeps the fantasy honest: every
treasure effect is one log line with the treasure as `source_id`, so "why did that cost 1?" is
always answerable.

## Detailed Design

### Core Rules

`game-designer` / `systems-designer` not consulted — Lean mode. Review manually before production.
Rules are numbered T1–T9. "Hook table" means match-rules Interactions; "C2" / "C5" / "C9" are
card-effects Core Rules; "R1" / "R5" / "R8" are run-structure Core Rules.

#### T1. Data model — `TreasureDef`

One record per treasure in `assets/data/treasures.json` (DD-T01), loaded and shape-validated by
Card Database (CR-3) and effect-validated by Card Effects (C10). Card Database's row is
`id, name, rarity, tags, effects, unlock, text, art`; `tags` was this GDD's request and CR-3 now
carries it (R-7, resolved 2026-11-03).

| Field | Type | Owner of semantics | Rule |
|---|---|---|---|
| `id` | string | Card Database | `treasure_<name>`, unique across all definition files |
| `name` | string | Content | Display name; ≤ 24 characters so the tray chip fits |
| `rarity` | enum `common \| rare` | **this GDD** | Sets the power band (F1) and the per-item offer weight (reward-draft F2, `RARITY_W` 70/30) |
| `tags` | string[] | **this GDD** | Exactly one **affinity** tag from `war \| decay \| knowledge \| universal`, plus 0–3 **plan** tags from the Heroes H-5 theme set (`weapons, aggro, armour, deathrattle, sacrifice, husk, spells, spell_damage, draw`) and/or **archetype** tags (`economy, tempo, value, defensive, wild`). Affinity weights offers towards the run's hero; it never gates an offer |
| `effects` | object[] | Card Effects (shape), this GDD (content) | 1–3 effect objects (C1), each using a trigger whose C2 "Hosts" column includes `treasure`. Opaque to Card Database |
| `unlock` | `{key, condition}` or `null` (DD-X01) | Meta Progression | T8's Unlock column is the `key`; the `condition` object follows meta-progression M2.2; `null` = available from the first run. This GDD names keys; Meta Progression defines their conditions (M10) and validates them (M2.4) |
| `text` | object | Content | Localizable one-line rules text shown on the offer card and tray tooltip; must match `effects` (reviewed, not validated) |
| `art` | string | Content | Icon path; placeholder shape + initial in v1 |

A treasure is **not a card**: it has no cost, no zone, no `entity_id`, cannot be targeted, Silenced
or copied, and never enters hand, deck or board. `self` is illegal in its effects (card-effects
`E_FX_SELECTOR`); its auras are hosted on the owner's hero slot (C2 `aura` row).

#### T2. The hook chain — per match, owner-scoped

1. **One registry per match.** `MatchState.hooks` (match-rules C1) is a `HookRegistry`: a plain
   `RefCounted` holding, for each of the 12 hook points in the hook table, an ordered list of
   `HookEntry {host_kind: treasure|passive, host_id, side, effect_id, effect}`. It is created with
   the match and discarded with it. There is no autoload, no global list and no `Node` anywhere in
   the chain (DD-T02). An entry never holds a reference to its registry or to the match — removal,
   if a future treasure needs it, is the registry's job (the TD-009 back-reference is gone).
2. **Three hook kinds, two in v1.** *Trigger* hooks (`on_match_start`, `on_turn_start`,
   `on_turn_end`, `on_card_played`, `on_minion_summoned`, `on_hero_damaged`, `on_draw`) run each
   entry's effect synchronously as its own step at the hook point (C9). *Value* hooks
   (`modify_cost`, `modify_damage`, `modify_heal`, `modify_starting_hand_size`,
   `modify_max_attacks`) fold: entry *n*'s output is entry *n + 1*'s input; the engine clamps once
   after the fold (F2). *Gate* hooks (boolean, AND, short-circuit) are **defined but have no hook
   point in v1** — the pool needs none; adding one is a match-rules hook-table change.
3. **Ordering is installation order and nothing else.** Decision: the prototype's `priority` field
   is dropped. Treasures install in `RunState.treasures[]` order (pick order, R1), each treasure's
   `effects[]` in array order, then the boss passive. The tray shows treasures in that order, so the
   fold order is on screen (Pillar 4). Rationale: a priority field lets two treasures compose in an
   order the player cannot see; pick order is visible and already persisted.
4. **Owner scope is baked in.** `HookEntry.side` is the installer's side (PLAYER for treasures,
   BOSS for a passive). Every `friendly` / `owner` / `enemy` in the effect resolves relative to it,
   and every hook invocation carries the side it concerns (hook table signatures); an entry whose
   scope does not match the invocation's side is skipped by the resolver before it runs. A
   treasure therefore cannot affect the boss's costs by accident — the prototype's defect.
5. **Event triggers without a hook binding.** C2 allows some event triggers on treasure hosts with
   no hook column (`on_play`, `after_cast`, `on_attack`, `on_damage_dealt`, `on_heal`,
   `on_minion_died`, `on_hero_power`, `on_weapon_equipped`). These run as **observers hosted on
   the owner's hero slot**: queued like a card trigger, in the candidate order's "hero power / hero
   enchantments" position for that side (match-rules C4 step 5, C10), after the hook steps.
   Confirmed by card-effects C9 (R-10, resolved 2026-11-03); a treasure host's `once_per_turn`
   mark is keyed on the treasure id (card-effects Edge Cases). Only Grave Tithe (T8) uses one in v1.

#### T3. Installation and lifecycle

1. At `begin_match` Run Structure calls `Treasures.installers_for(treasure_ids) -> HookInstaller[]`
   (R3) and places the result in `MatchConfig.player.hook_installers`; `BossDef.passive` becomes
   the boss's single installer the same way.
2. `HookInstaller = {host_kind: "treasure", host_id, side: PLAYER, effects: copy of
   TreasureDef.effects, state: treasure_state.by_treasure[host_id] or {}}`. `installers_for` is a
   pure function of `(ids, Card Database)`: no RNG, no events, no RunState writes.
3. Card Effects' resolver binds each installer at `RulesEngine.start` (C6.1): one `HookEntry` per
   effect, appended to that trigger's hook list in installer order. This happens in match-rules C3
   step 1, **before** step 4 (`on_match_start`), so match-start treasures see a fully installed
   chain.
4. **Idempotent.** Installing the same id list onto a fresh match always yields the same registry.
   An installer whose `host_id` is already present in the registry is skipped with one
   `hook_install_skipped{host_id, reason: duplicate}` event and no other effect.
5. Entries live until the match is `Ended` and die with `MatchState`. No treasure is removed,
   disabled or expired mid-match in v1; the prototype's `is_enabled`, `duration_turns` and
   `stacks` are dropped.
6. `MatchState.clone()` (Boss AI look-ahead) copies the registry by value — entries are data, so
   the clone's hooks fire identically and emit nothing to the real log (boss-ai GDD).

#### T4. State — two tiers

| Tier | Where | Reset | Written by | v1 use |
|---|---|---|---|---|
| **Match state** | `EffectRuntime.counters[treasure_id]` and `once_marks` (card-effects C6.7–8) | New match | DSL ops (`add_counter`, `once_per_turn`) | `once_per_turn` on Grave Tithe |
| **Run state** | `RunState.treasure_state` (R1): `{schema_version: 1, by_treasure: {treasure_id: {…}}}` | New run | `Treasures.collect_state(hooks, match_result) -> Dictionary`, called by the run after `match_ended` and before save S2 (run-structure R4, confirmed — R-11) | **None** — no v1 treasure persists state |

Rules: `treasure_state` is read only at `installers_for` and written only at match end, so a
quit-and-restart (R8.3) reverts to the match-start snapshot with no special code, and resume after
S2/S3 sees the post-match value. It is JSON-only (RNG & Event Log rule 14). The v1 DSL has no op
that writes run state; a cross-match counter treasure ("+1 Attack for every boss you have beaten")
needs a `persist: true` flag on `add_counter` — an Open Question, not assumed.

#### T5. Granting and holding

1. Run Structure appends the picked id to `treasures[]` and emits `treasure_granted` (R5.4).
   Treasures never mutates `RunState`.
2. **No duplicates.** Reward Draft never offers a held or previously offered id (DD-R05; reward-draft D7).
   If `installers_for` nevertheless receives a repeated id (hand-edited save), it keeps the first
   occurrence, drops the rest and emits `run_warning{code: duplicate_treasure, treasure_id}`; the
   registry's own duplicate skip (T3.4) is the second guard.
3. **Count.** The only bound is `|treasure_floors ∩ [1, floors_per_run − 1]|` — 3 in v1, 2 at
   MVP (R5.1). There is no treasure removal, trade or upgrade in v1.
4. **Same treasure twice is impossible; different treasures stack** per F3.

#### T6. Pool query — the Reward Draft contract (restated against reward-draft.md D3/D7/F2)

- **Membership predicate (this GDD owns it).** A treasure is *available* to a run when
  `unlock == null` or `unlock.key ∈ MetaProgression.unlocked_keys()` (meta-progression M1.3;
  `is_treasure_unlocked(id)` is its membership helper — R-18 resolved), and it is neither held
  (`run_state.treasures[]`) nor previously offered this run. `Treasures.pool(unlocked_keys, exclude_ids)
  -> TreasureDef[]` implements the predicate over Card Database `treasure_pool()` and returns
  id-ascending order (CR-6) so a seeded draw is reproducible (DD-R09). It is a pure function.
- **When it is evaluated (Reward Draft owns this).** Reward Draft snapshots the unlock-filtered pool
  once, at `init_run` (reward-draft D3, `draft_state.treasure_pool`), and derives the exclusion set
  per draft from the run record: `seen = treasures ∪ {t : d ∈ drafts, d.kind == treasure, t ∈
  d.offered_ids}` (reward-draft D7). The `draft_state.offered_treasure_ids[]` list run-structure R1
  sketched is **superseded** by that derivation — nothing in this GDD reads it.
- **Weights.** Reward Draft draws 3 distinct offers per treasure draft with **per-item** weights
  `treasure_weight(t) = RARITY_W[rarity] × (100 + TREASURE_AFFINITY × affine(t)) / 100`
  (reward-draft F2; defaults `RARITY_W` common 70 / rare 30, registry `treasure_rarity_weights`),
  a universal slot 1 when `universal_slot` is on, and the short-pool rules of its D8. `affine(t)`
  reads this GDD's **plan** tags against the hero's H-5 tags; the **affinity** tag is for display
  and for Reward Draft's universal slot (reward-draft F2 tests `"universal" ∈ tags` — R-16 resolved). Weights,
  pity and the universal slot are Reward Draft's knobs; F1's bands and F4's odds take 70/30 as the
  per-item ratio and are therefore approximations of the per-slot share (reward-draft F2 puts rares
  at ≈ 22–24 % of slots with this pool).
- Minimum pool: `min_treasure_pool = 9` unlocked by default (Card Database Formulas); v1 ships 16
  of 20 unlocked by default, MVP 10 of 10 (DD-H06). Content keeps `n_universal ≥ 3` so the
  universal slot is satisfiable (reward-draft's universal-slot floor) — T8 has 10.

#### T7. Validation at data load (Card Database CR-5 stage 7)

Card Effects' `validate_effects("treasure", id, effects)` runs first and catches every DSL error,
including an effect whose trigger has no treasure binding (`E_FX_TRIGGER`) and `self`
(`E_FX_SELECTOR`). Treasures injects a second stage-7 validator with this closed code set:

| Code | Raised when |
|---|---|
| `E_TR_RARITY` | `rarity` not `common` or `rare` (legendary is a card rarity, never a treasure rarity in v1) |
| `E_TR_TAGS` | Zero or more than one affinity tag; unknown tag |
| `E_TR_EFFECT_COUNT` | `effects` empty or > `MAX_EFFECTS_PER_TREASURE` (3) |
| `E_TR_TOKEN_REF` | A `summon` / `add_to_hand` / `equip` `card_id` whose record has `set: boss` — boss-only tokens never come from a player treasure |
| `W_TR_POWER` | F1 power outside the rarity's band (warning; an observation for `/balance-check`, never a block) |
| `W_TR_TEXT` | `text` missing a locale the project ships (warning) |

Unlock keys are validated by Meta Progression's validator (M2.4); an unknown key is its error,
surfaced by Card Database's data-error screen like any other (CR-8).

#### T8. The v1 pool (20 treasures, 10 MVP)

Every entry is expressible in the card-effects v1 DSL and the 12 hook points; where an entry leans
on an interpretation or needed a primitive, the "Hook" column says so and Open Questions records the
request and its 2026-11-03 resolution. Power is F1's estimate in mana-equivalent per match; bands: Common 1.5–3.5, Rare 3.5–6.5
(a value on the boundary takes the lower rarity). MVP treasures all have `unlock: null` so the
MVP pool is 10/10 unlocked (DD-H06 ≥ `min_treasure_pool` 9). Unlock keys are named here and
their conditions defined by Meta Progression (M10; the record's field is `unlock: {key, condition}`, DD-X01).

| # | id | Name | Rarity | Tags (affinity · plan/archetype) | Text | Hook (DSL trigger → binding) | Power | MVP | Unlock |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `treasure_hollow_crown` | Hollow Crown | Rare | universal · economy | Start each match with an extra Mana Crystal. | `on_match_start` → `on_match_start`; op `mana` permanent → `add_mana(owner, 1, temporary=false)` raises `PlayerState.crystal_bonus` to 1 (match-rules C5, C4 Start step 2, F4; R-1 resolved) | 5.4 | ✔ | null |
| 2 | `treasure_worn_signet` | Worn Signet | Common | universal · economy | Your hero power costs (1). | `modify_cost` (hero_power) → `modify_cost`; `set 1` | 2.8 | ✔ | null |
| 3 | `treasure_quartermasters_ledger` | Quartermaster's Ledger | Common | universal · economy | Your cards that cost (5) or more cost (1) less. | `modify_cost` (`cost_ge 5`) → `modify_cost`; `delta −1` | 2.1 | — | null |
| 4 | `treasure_vanguards_banner` | Vanguard's Banner | Rare | universal · tempo | The first card you play each turn costs (1) less. | `modify_cost` + `condition cards_played_this_turn == 0` (R-2, resolved: card-effects C1 evaluates it per fold call) | 5.0 | ✔ | null |
| 5 | `treasure_sprinters_boots` | Sprinter's Boots | Common | war · aggro, tempo | Your minions that cost (3) or less have Rush. | `aura` (board, `cost_le 3`) → hero-slot aura | 2.5 | — | null |
| 6 | `treasure_scholars_candle` | Scholar's Candle | Common | knowledge · draw, value | At the start of your 2nd and 4th turns, draw a card. | `turn_start` (owner) + `condition match.turn ∈ {3, 7}` → `on_turn_start` | 3.0 | ✔ | null |
| 7 | `treasure_bottomless_satchel` | Bottomless Satchel | Rare | universal · value | Your opening hand has 2 extra cards. | `modify_starting_hand_size` → same; `delta +2` | 3.9 | ✔ | null |
| 8 | `treasure_iron_constitution` | Iron Constitution | Common | universal · defensive, armour | Your hero has +10 Health. | `on_match_start`; op `buff health +10` on `owner_hero` | 3.5 | ✔ | null |
| 9 | `treasure_thornhide_cloak` | Thornhide Cloak | Common | universal · defensive, armour | Whenever your hero takes damage, gain 1 Armour. | `on_damage_taken` (`who: owner_hero`) → `on_hero_damaged` | 2.1 | ✔ | null |
| 10 | `treasure_mending_charm` | Mending Charm | Common | universal · defensive | At the end of your turn, restore 2 Health to your hero. | `turn_end` (owner) → `on_turn_end`; op `heal 2` | 3.2 | — | null |
| 11 | `treasure_whetstone_wheel` | Whetstone Wheel | Common | war · weapons | Your weapons have +1 Attack. | `aura` on `owner_weapon`; `attack +1` (+1 Durability is v2 — see note) | 2.5 | ✔ | null |
| 12 | `treasure_twin_grip` | Twin Grip | Rare | war · weapons, aggro | Your hero can attack twice each turn. | `modify_max_attacks` (`owner_hero`) → same; `set 2` | 4.5 | ✔ | null |
| 13 | `treasure_grave_tithe` | Grave Tithe | Rare | decay · husk, deathrattle | Whenever a friendly minion dies, summon a 1/1 Husk. *(Once per turn.)* | `on_minion_died` (friendly), `once_per_turn` → hero-slot observer (T2.5); summons `decay_husk` | 5.0 | — | `hero_decay_first_win` |
| 14 | `treasure_rotting_bargain` | Rotting Bargain | Common | decay · deathrattle | Your Deathrattle minions cost (1) less. | `modify_cost` (`type minion, has_trigger deathrattle`) → `modify_cost` | 2.8 | — | null |
| 15 | `treasure_plague_bell` | Plague Bell | Common | decay · husk, sacrifice | Your Husks have +1 Attack. | `aura` (`tag: husk`) on board (R-3, resolved: card-effects C3 reads `tag` on board minions) | 3.0 | — | `hero_decay_floor_5` |
| 16 | `treasure_focusing_prism` | Focusing Prism | Common | knowledge · spell_damage, spells | Your spells deal 1 more damage. | `modify_damage` (`source: friendly spell`) → `modify_damage`; `delta +1` | 2.6 | — | null |
| 17 | `treasure_dogeared_grimoire` | Dog-eared Grimoire | Rare | knowledge · spells | Your spells cost (1) less. | `modify_cost` (`type spell`) → `modify_cost`; `delta −1` | 4.2 | — | `hero_knowledge_first_win` |
| 18 | `treasure_living_armory` | Living Armory | Rare | universal · wild | Start each match with a random Legendary minion in your hand. | `on_match_start`; op `add_to_hand from {pool collectible, rarity legendary, type minion}` | 4.0 | — | `bosses_defeated_16` |
| 19 | `treasure_stampede_horn` | Stampede Horn | Rare | universal · wild, aggro | Your minions have Rush. | `aura` (`all_friendly_minions`) → hero-slot aura (card-effects row 42) | 4.0 | ✔ | null |
| 20 | `treasure_captured_standard` | Captured Standard | Rare | war · aggro | Your minions have +1 Attack. | `aura` (`all_friendly_minions`); `attack +1` | 4.0 | — | null |

Counts: 11 Common / 9 Rare; affinity 10 universal, 4 war, 3 decay, 3 knowledge; 16 unlocked by
default (≥ 9), 4 unlockable (DD-H04 "some unlockable"). Archetype coverage from the brief: economy
(1–3), tempo (4–5), value (6–7), defensive (8–10), hero-affine War (5, 11–12, 20), Decay (13–15),
Knowledge (6, 16–17), wild (18–19). Content CN-5 expected a 5/5/5/5 split; this table is the
authority (CN-5 says Content consumes these ids) and CN-5 now records this split (R-20, resolved).

**Deviations from the brief, recorded.** *War "+1 Durability"*: card-effects lists
`weapon_durability` as a provisional op (v2); Whetstone Wheel uses `+1 Attack` instead and the
durability version is deferred, not requested. *Decay "25% → summon a Husk"*: the DSL has no random
chance in conditions, and Pillar 4 prefers determinism; Grave Tithe is `once_per_turn` instead.
*"First minion you play"*: the C4 ref set has `cards_played_this_turn` but no
`minions_played_this_turn`; Vanguard's Banner is "first card". *"Random Legendary on board"*:
`summon` takes a `card_id`, not a pool; Living Armory puts it in hand (`add_to_hand … from`). *"+10
health"*: kept, as the one pure stat treasure, at Common.

#### T9. DSL sketches

One effect per treasure (C1 shape; `id` defaults to `<treasure_id>.0`). Ops and scope keys are
from C2–C5 verbatim; `R-n` marks a request listed in Open Questions (all resolved 2026-11-03).

```json
{"id":"treasure_hollow_crown","effects":[{"trigger":"on_match_start","targets":"owner",
  "ops":[{"op":"mana","amount":1,"duration":"permanent"}]}]}   // R-1: add_mana(PLAYER, 1, temporary=false) → crystal_bonus 1 (match-rules C5, F4)
{"id":"treasure_worn_signet","effects":[{"trigger":"modify_cost","scope":{"card":{"side":"friendly","kind":"hero_power"}},
  "ops":[{"op":"modify_value","set":1}]}]}
{"id":"treasure_quartermasters_ledger","effects":[{"trigger":"modify_cost","scope":{"card":{"side":"friendly","cost_ge":5}},
  "ops":[{"op":"modify_value","delta":-1}]}]}
{"id":"treasure_vanguards_banner","effects":[{"trigger":"modify_cost","scope":{"card":{"side":"friendly"}},
  "condition":{"cmp":[{"ref":"owner.cards_played_this_turn"},"==",0]},"ops":[{"op":"modify_value","delta":-1}]}]}  // R-2: condition per fold call (card-effects C1)
{"id":"treasure_sprinters_boots","effects":[{"trigger":"aura","scope":{"zone":"board"},
  "targets":{"selector":"all_friendly_minions","filter":{"cost_le":3}},"ops":[{"op":"aura","keywords":["rush"]}]}]}
{"id":"treasure_scholars_candle","effects":[{"trigger":"turn_start","scope":{"side":"owner"},
  "condition":{"any":[{"cmp":[{"ref":"match.turn"},"==",3]},{"cmp":[{"ref":"match.turn"},"==",7]}]},
  "targets":"owner","ops":[{"op":"draw","count":1}]}]}                                           // player turn n = match.turn 2n−1 (DD-M03)
{"id":"treasure_bottomless_satchel","effects":[{"trigger":"modify_starting_hand_size","scope":{"side":"owner"},
  "ops":[{"op":"modify_value","delta":2}]}]}
{"id":"treasure_iron_constitution","effects":[{"trigger":"on_match_start","targets":"owner_hero",
  "ops":[{"op":"buff","health":10,"duration":"permanent"}]}]}
{"id":"treasure_thornhide_cloak","effects":[{"trigger":"on_damage_taken","scope":{"who":"owner_hero","min_amount":1},
  "targets":"owner","ops":[{"op":"armor","amount":1}]}]}
{"id":"treasure_mending_charm","effects":[{"trigger":"turn_end","scope":{"side":"owner"},"targets":"owner_hero",
  "ops":[{"op":"heal","amount":2}]}]}
{"id":"treasure_whetstone_wheel","effects":[{"trigger":"aura","targets":"owner_weapon","ops":[{"op":"aura","attack":1}]}]}
{"id":"treasure_twin_grip","effects":[{"trigger":"modify_max_attacks","scope":{"who":"owner_hero"},
  "ops":[{"op":"modify_value","set":2}]}]}
{"id":"treasure_grave_tithe","effects":[{"trigger":"on_minion_died","scope":{"who":"friendly_minion"},"once_per_turn":true,
  "targets":"owner","ops":[{"op":"summon","card_id":"decay_husk","count":1,"position":"end"}]}]}   // observer-hosted, T2.5
{"id":"treasure_rotting_bargain","effects":[{"trigger":"modify_cost",
  "scope":{"card":{"side":"friendly","type":"minion","has_trigger":"deathrattle"}},"ops":[{"op":"modify_value","delta":-1}]}]}
{"id":"treasure_plague_bell","effects":[{"trigger":"aura","targets":{"selector":"all_friendly_minions","filter":{"tag":"husk"}},
  "ops":[{"op":"aura","attack":1}]}]}                                                              // R-3: tag on board minions (card-effects C3)
{"id":"treasure_focusing_prism","effects":[{"trigger":"modify_damage","scope":{"source":{"side":"friendly","type":"spell"}},
  "ops":[{"op":"modify_value","delta":1}]}]}
{"id":"treasure_dogeared_grimoire","effects":[{"trigger":"modify_cost","scope":{"card":{"side":"friendly","type":"spell"}},
  "ops":[{"op":"modify_value","delta":-1}]}]}
{"id":"treasure_living_armory","effects":[{"trigger":"on_match_start","targets":"owner",
  "ops":[{"op":"add_to_hand","from":{"pool":"collectible","filter":{"type":"minion","rarity":"legendary"}},"count":1}]}]}
{"id":"treasure_stampede_horn","effects":[{"trigger":"aura","targets":"all_friendly_minions","ops":[{"op":"aura","keywords":["rush"]}]}]}
{"id":"treasure_captured_standard","effects":[{"trigger":"aura","targets":"all_friendly_minions","ops":[{"op":"aura","attack":1}]}]}
```

The sketches omit `name`, `rarity`, `tags`, `unlock`, `text` and `art` — T8 carries them. A
record whose `rarity` disagrees with its F1 band loads with `W_TR_POWER`, never an error.

### States and Transitions

A treasure *definition* has a per-profile and a per-run state; a *hook entry* has a per-match
state. Both are tables of data, not objects with behaviour.

| State | Scope | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|---|
| **Locked** | profile | `unlock != null` and key not in the profile's unlocked set | Meta Progression grants the key (`unlock_granted`, meta-progression M3.6) | Excluded from `pool()`; shown greyed in the run log's treasure list (Run UI) |
| **Available** | profile + run | `unlock == null`, or key unlocked; id not held or offered this run | Drawn as an offer, or the run ends | Eligible for `pool()`; nothing happens |
| **Offered** | run | Reward Draft draws it (`draft_offered`) | `draft_pick` picks it → Held; picks another → **Passed** | Displayed on the draft screen with name, rarity, text, tags |
| **Passed** | run | Offered and not picked | Run ends | Recorded in the run's `drafts[]` (reward-draft D7 derives the exclusion set from it); never offered again this run (DD-R05) |
| **Held** | run | `treasure_granted` (R5.4) appended it to `treasures[]` | Run ends (S5) | Shown in the HUD tray in pick order; no effect outside a match |
| **Installed** | match | `begin_match` → `installers_for` → resolver binding (T3) | `match_ended` (any reason) → registry discarded → back to Held | Its hook entries fire at their points; `source_id` = treasure id in every event |

Transitions that do **not** exist in v1: Held → removed, Installed → disabled, Installed →
expired, Held → upgraded. A mid-match quit leaves the treasure Held; the next `begin_match`
installs it again from the id list (R8.3, R8.5). A profile reset while a run is active moves the
definition to Locked for *future* offers only — the Held copy stays Held (Edge Cases).

### Interactions with Other Systems

Interfaces first defined here as contracts (while the partner GDD was being written) have all
been confirmed by their partners as of the 2026-11-03 cross-review; each row cites the confirming
section.

| System | Direction | Data in (to Treasures) | Data out (from Treasures) | Interface owner |
|---|---|---|---|---|
| **Card Database** | upstream | `treasure(id)`, `treasure_pool()` (id-ascending), `has(id)` for token refs, `data_version` | The stage-7 validator (T7) injected at composition | Card Database owns record shape and load order; this GDD owns `rarity`/`tags` semantics; CR-3 carries the `tags` field (R-7) |
| **Card Effects** | upstream (language) | Trigger vocabulary and hook bindings (C2), op table (C5), `validate_effects`, resolver binding of installers (C6.1), hooks-first ordering (C9) | `effects[]` content for 20 treasures; the installer record shape (T3.2) | Card Effects owns the DSL and binding; this GDD owns which triggers the pool uses and their magnitudes |
| **Match Rules** | upstream (hook points) | The 12 hook points and their signatures; clamps after value folds (F1 floor 0, F2 floor 0); `MatchState.hooks` as the registry's home; primitives the ops call | Installed `HookEntry`s via `MatchConfig.player.hook_installers`; R-1 (`crystal_bonus`, C5/F4), R-4 (`modify_heal` floor) and R-5 (hook-table clamps) landed in match-rules 2026-11-03 | Match Rules owns the hook table and clamps; a new hook is a change there, never a workaround here |
| **Run Structure** | mutual | `treasures[]` in pick order at every `begin_match`; `treasure_state` (R1) | `installers_for(ids) → HookInstaller[]` (pure, idempotent); `collect_state(hooks, match_result) → Dictionary` after `match_ended` (run-structure R4, confirmed); `run_warning{duplicate_treasure}` | Run Structure owns the run record and when it calls; this GDD owns installer content and the `treasure_state` schema |
| **RNG & Event Log** | upstream | Nothing drawn directly — ops that randomise (`add_to_hand from`) use the `match` stream through the resolver | `effect_resolved` and `hook_install_skipped` with `source_id` = treasure id and `cause_seq` | RNG & Event Log owns the envelope; this GDD owns the two treasure-specific event types |
| **Heroes** | upstream (data) | H-5 theme tags (the plan-tag vocabulary); tokens `decay_husk`, `war_whetstone_blade`; hero affinity names | Affinity tags per treasure (Reward Draft weighting) | Heroes owns tags and tokens; this GDD only references them |
| **Reward Draft** | downstream | `unlocked_keys()` read once at `init_run` (reward-draft D3, meta M3.7), `exclude_ids` derived from `drafts[]` (D7), the `draft_<floor>` stream it draws with | `pool(unlocked_keys, exclude_ids)`; `rarity` and `tags` per record; per-item `RARITY_W` 70/30 and the no-duplicate rule (reward-draft F2, D7) | Reward Draft owns weights, pity and the draw; this GDD owns pool membership |
| **Meta Progression** | mutual | `unlocked_keys()` read once at `init_run` (reward-draft D3, meta M3.7); the unlock-key validator (M2.4) | The unlock keys this pool names (T8; conditions in meta M10); `treasures_taken` statistics come from the run record, not from here (confirmed in meta-progression Interactions / Dependencies) | Meta Progression owns key definitions, grant conditions and persistence |
| **Boss AI** | sideways | — | Boss passives use the same installer shape and registry; `MatchState.clone()` copies hook entries by value | Boss AI relies on clones firing identically (boss-ai GDD); this GDD guarantees entries are plain data |
| **Match UI** | downstream | — | Tray contents (ids in pick order), per-event `source_id` for the feed and tray flare | Match UI is display-only over events and the `RunState` read model |
| **Run UI** | downstream | — | Offer card content: `name`, `rarity`, `text`, `tags`; locked treasures for the run log | Run UI is display-only |
| **Content** | downstream | Authors `treasures.json` entries beyond this pool | T7 validation codes, F1 budget bands, `W_TR_POWER` | Content owns future entries; this GDD owns the 20 above and the bands |

## Formulas

`systems-designer` not consulted — Lean mode. Review manually before production. All `Source =
data file` variables live in `assets/data/treasures_balance.json` (listed in DD-T01) and are
listed in Tuning Knobs. F1 is a **design-time estimate** used to assign rarity
and to seed `/balance-check`; it is never computed at runtime.

### F1. Treasure power (mana-equivalent per match)

The `treasure_power` formula is defined as:

`treasure_power(t) = Σ_{e ∈ effects(t)} n_triggers(e) × value_per_trigger(e) × efficiency(e)`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| n_triggers | float | 0–12 | calculated (match model below) | Expected times the effect does something in one match |
| value_per_trigger | float | 0.35–3.0 | calculated from conversion constants | Mana-equivalent of one firing |
| efficiency | float | 0.5–1.0 | data file | Fraction of the nominal value a player actually realises |
| V_MANA | float | 1.0 | data file | 1 mana saved or gained, spent on-curve |
| V_CARD | float | 1.5 | data file | 1 card drawn (Arcane-Intellect rate: 3 mana / 2 cards) |
| V_DMG | float | 0.5 | data file | 1 damage, face or minion |
| V_HP | float | 0.35 | data file | 1 hero Health or Armour (only matters in losing games) |
| V_STAT | float | 0.5 | data file | +1 Attack or +1 Health on one minion |
| V_TOKEN | float | 1.0 | data file | One 1/1 token (`decay_husk` costs 1) |
| V_RUSH | float | 0.5 | data file | Rush on one minion that gets to use it |
| ETA_MANA / ETA_CRYSTAL / ETA_FIRST / ETA_OVERHEAL | float | 0.7 / 0.6 / 0.8 / 0.5 | data file | Spendability of a card-specific discount / of an odd extra crystal / turns where the first card costs ≥ 1 / healing not wasted |
| T_TURNS | int | 9 | data file | Player turns per match (match-rules F8: 6–10) |
| N_MINIONS, N_CHEAP, N_BIG, N_DEATHRATTLE, N_HUSKS | int | 8, 5, 3, 4, 6 | data file | Minions played per match: all / cost ≤ 3 / cost ≥ 5 / with Deathrattle (Decay) / Husks (Decay) |
| N_SPELLS, N_DMG_SPELLS, AOE_FACTOR | int, int, float | 6, 4, 1.3 | data file | Spells cast (Knowledge) / damaging spells / average targets per damaging spell |
| N_POWER, N_HITS, N_SWINGS, N_DEATH_TURNS | int | 4, 6, 5, 5 | data file | Hero power uses / times the hero takes damage / weapon swings / turns with a friendly death |
| LEGENDARY_SURPLUS | float | 2.5 | data file | Mana-equivalent a Legendary minion is worth above its cost |
| COMMON_BAND, RARE_BAND | [float, float] | [1.5, 3.5], [3.5, 6.5] | data file | Rarity assignment; boundary value → lower rarity |

**Output Range:** 1.5–6.5 for the v1 pool; a value outside both bands is a `W_TR_POWER` warning.
**Worked estimates** (the T8 "Power" column):

| # | Treasure | Computation | Power | Band |
|---|---|---|---|---|
| 1 | Hollow Crown | +1 mana on turns 1–9 (turn 10 capped): 9 × V_MANA × ETA_CRYSTAL = 9 × 1 × 0.6 | 5.4 | Rare |
| 2 | Worn Signet | N_POWER × 1 × ETA_MANA = 4 × 1 × 0.7 | 2.8 | Common |
| 3 | Quartermaster's Ledger | N_BIG × 1 × ETA_MANA = 3 × 0.7 | 2.1 | Common |
| 4 | Vanguard's Banner | T_TURNS × 1 × ETA_MANA × ETA_FIRST = 9 × 0.7 × 0.8 | 5.0 | Rare |
| 5 | Sprinter's Boots | N_CHEAP × V_RUSH = 5 × 0.5 | 2.5 | Common |
| 6 | Scholar's Candle | 2 cards × V_CARD = 2 × 1.5 | 3.0 | Common |
| 7 | Bottomless Satchel | 2 × V_CARD × 1.3 (turn-1 tempo) = 3.9 | 3.9 | Rare |
| 8 | Iron Constitution | 10 × V_HP = 3.5 | 3.5 | Common (boundary) |
| 9 | Thornhide Cloak | N_HITS × 1 × V_HP = 6 × 0.35 | 2.1 | Common |
| 10 | Mending Charm | T_TURNS × 2 × V_HP × ETA_OVERHEAL = 9 × 2 × 0.35 × 0.5 | 3.2 | Common |
| 11 | Whetstone Wheel | N_SWINGS × 1 × V_DMG = 5 × 0.5 | 2.5 | Common |
| 12 | Twin Grip | 5 extra swings × 2 dmg × V_DMG − 0.5 (durability spent) = 5.0 − 0.5 | 4.5 | Rare |
| 13 | Grave Tithe | N_DEATH_TURNS × V_TOKEN = 5 × 1.0 | 5.0 | Rare |
| 14 | Rotting Bargain | N_DEATHRATTLE × 1 × ETA_MANA = 4 × 0.7 | 2.8 | Common |
| 15 | Plague Bell | N_HUSKS × V_STAT = 6 × 0.5 | 3.0 | Common |
| 16 | Focusing Prism | N_DMG_SPELLS × AOE_FACTOR × 1 × V_DMG = 4 × 1.3 × 0.5 | 2.6 | Common |
| 17 | Dog-eared Grimoire | N_SPELLS × 1 × ETA_MANA = 6 × 0.7 | 4.2 | Rare |
| 18 | Living Armory | V_CARD + LEGENDARY_SURPLUS = 1.5 + 2.5 | 4.0 | Rare |
| 19 | Stampede Horn | N_MINIONS × V_RUSH = 8 × 0.5 | 4.0 | Rare |
| 20 | Captured Standard | N_MINIONS × 1 × V_STAT = 8 × 0.5 | 4.0 | Rare |

**Edge case:** hero-affine treasures are estimated for their hero (N_SPELLS = 6 is Knowledge's
count; War casts ~3, so Grimoire is worth ~2.1 to War). That is intended — affinity weighting
(T6) makes the hero that values it see it more often; `/balance-check` reads pick and win rates
per hero from the run log to correct the constants.

### F2. Value-hook fold and clamps

The `hook_fold` formula is defined as:

`v_out = clamp_h( fold(entries_h, v_in) )` where `fold([], v) = v` and `fold([e, …rest], v) = fold(rest, apply(e, v))`, `apply(delta δ) = v + δ`, `apply(set s) = s`, `apply(mul m) = v × m`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| v_in | int | 0–99 | calculated (engine) | The engine's value before hooks (printed cost, requested damage, 3 cards, 1 attack) |
| entries_h | HookEntry[] | 0–12 | calculated | Entries bound to hook `h`, in installation order: treasures in pick order, then the boss passive |
| δ, s, m | int | −10..10, 0..99, 0..10 | data file (treasure `effects`) | `modify_value` parameters (C5); each effect has exactly one |
| clamp_h | function | per hook | constant (match-rules) | `modify_cost`: `max(0, ·)` (F1) · `modify_damage`: `max(0, ·)` (F2) · `modify_heal`: `max(0, ·)` · `modify_starting_hand_size`: `clamp(·, 0, HAND_SIZE)` · `modify_max_attacks`: `clamp(·, 0, MAX_ATTACKS_CAP = 4)` (all stated in match-rules' hook table) |

**Output Range:** cost 0–10; damage 0–99; heal 0–99; starting hand 0–10; max attacks 0–4. The clamp
runs **once, after the whole fold**, never between entries — so two −1s on a 1-cost card read as
`1 − 1 − 1 = −1 → 0`, not `0 → 0`. **Example:** Worn Signet (`set 1`) then a boss passive "hero
powers cost (1) more" (`delta +1`): `fold = 2`; the reverse order cannot occur (passive last).
Vanguard's Banner + Quartermaster's Ledger + Dog-eared Grimoire on a 5-cost spell played first:
`5 − 1 − 1 − 1 = 2`.

### F3. Stacking across treasures

The `stacked_delta` formula is defined as:

`stacked_delta_h = Σ_{i} δ_i` over all `delta` entries on hook `h`; a `set` entry replaces the running value and later `delta`s apply on top; `mul` entries multiply in order (none in v1)

**Variables:** as F2. **Output Range:** v1 pool: cost delta −3 to 0 per card, damage +1, hand +2,
max attacks `set 2`. The same treasure never appears twice (T5), so stacking is only ever across
*different* treasures; two treasures with the same hook stack **additively** unless an effect
uses `mul` — the v1 pool has none, and Content adds one only with a Formulas note here.
**Example:** Twin Grip (`set 2`) and a Windfury weapon (engine base 2): `fold(2) = 2` — no third
attack; Twin Grip on a plain weapon: `fold(1) = 2`. **Expected held power** at floors 6–8:
`3 × (0.7 × 2.8 + 0.3 × 4.5) ≈ 10` mana-equivalent per match, i.e. roughly one extra card's
worth of value every turn — the scale at which treasures feel run-defining without replacing the
deck (run-structure F7 "Powerful" target at floor 6).

### F4. Offers and the chance to see a treasure

The `treasure_offers_per_run` and `p_seen` formulas are defined as:

`treasure_offers_per_run = |{f ∈ treasure_floors : f < floors_per_run}| × offers_per_draft`
`p_seen(t) ≈ min(1, treasure_offers_per_run × w_rarity(t) / N_rarity(t))`

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| treasure_floors | int[] | `[1, 3, 5]` | run-structure (registry `treasure_floors`) | Floors with a treasure draft |
| floors_per_run | int | 8 (MVP 4) | run-structure | — |
| offers_per_draft | int | 3 | constant (DD-R05) | Offers per treasure draft |
| w_rarity | float | 0.7 / 0.3 | Reward Draft (`RARITY_W`) | Per-item rarity weight (reward-draft F2); `p_seen` is an approximation until re-fitted |
| N_rarity | int | 1–40 | calculated | Unlocked, not-yet-offered treasures of that rarity |

**Output Range:** `treasure_offers_per_run` = 9 (v1) = registry `min_treasure_pool`; 6 at MVP.
`p_seen`: v1 all unlocked (11 C / 9 R) → common 6.3/11 ≈ **0.57**, rare 2.7/9 ≈ **0.30**; MVP
(5 C / 5 R, 6 offers) → common 0.84, rare 0.36. Expected rares offered per draft = 0.9;
`P(no rare in a draft) = 0.7³ ≈ 0.34` — a pity candidate for Reward Draft. **Treasures held per
run** = `treasures_held(floors_per_run)` from run-structure F4 = **3** (MVP 2). **Example:** a
player who wants Twin Grip in a full-unlock run sees it in ~30% of runs; the pool must therefore
carry at least two treasures per plan (T8 does: weapons 11/12/20, husks 13/15, spells 16/17).

### F5. Hook-chain cost bound

`hook_calls_per_match ≤ n_entries × calls_h`, with `n_entries ≤ (MAX_TREASURES_HELD + 1) ×
MAX_EFFECTS_PER_TREASURE = 4 × 3 = 12` and `modify_cost` the hottest point (every F1 evaluation:
≤ 10 hand cards + hero power per step). **Output Range:** ≤ 12 entries, each a dictionary lookup
and an integer op; budget in Acceptance Criteria: a 12-entry fold completes in < 0.05 ms, and a
full match with 3 treasures installed adds < 2 ms total over an empty registry (headless, reference
machine). No allocation in the fold.

## Edge Cases

`systems-designer` not consulted — Lean mode. Review manually before production.

**Data and validation**

- **If an effect's trigger has no treasure binding or is unknown** (`battlecry`, `deathrattle`, a
  misspelling): `E_FX_TRIGGER` at data load (card-effects C10); the load is `Failed` and the
  data-error screen names the treasure and effect. Never a runtime check — a treasure that reaches
  a match is valid.
- **If a treasure references a boss-only token** (`summon` of a card with `set: boss`):
  `E_TR_TOKEN_REF` at load. Living Armory's pool filter never yields tokens (`token: false`
  default), so it cannot hit this by accident.
- **If an effect's static step bound exceeds `EFFECT_STATIC_STEP_LIMIT`** ("deal 1 to all minions,
  20 times"): `E_FX_BUDGET` from card-effects F6; Treasures adds no cap of its own.
- **If a record's `rarity` disagrees with its F1 band**: `W_TR_POWER`, load succeeds; the warning
  is `/balance-check` input, not a verdict.
- **If `text` disagrees with `effects`**: not detectable by the validator; design review and content
  QA own it. The event feed names what actually happened, so the player is never misled for long
  (Pillar 4).

**Installation and ordering**

- **If a treasure hook and the boss passive respond to the same event** (Thornhide Cloak and a
  passive "whenever the player's hero takes damage, deal 1 to a random friendly minion", both on
  `on_hero_damaged`): both run as hook steps at that point, treasures in pick order first, the
  passive last, each with the full C10 loop after it. The Armour from the cloak exists before the
  passive's damage resolves. Same rule for two treasures on one hook.
- **If a boss passive `set`s a value a treasure also `set`s** (Worn Signet `set 1`, passive "hero
  powers cost (3)" `set 3`): the passive wins — it installs last (F2). Content guidance: passives
  prefer `delta` so treasures still show; a `set` passive is a deliberate "this boss turns your
  treasure off" puzzle and its intro text must say so (Pillar 3).
- **If `installers_for` receives a repeated id**: first occurrence kept, `run_warning
  {duplicate_treasure}`; if a duplicate still reaches the registry, `hook_install_skipped
  {reason: duplicate}` and no second entry. Reward Draft (no duplicate offers) and Run Structure
  (`E_DRAFT_DONE`) make both paths unreachable in normal play.
- **If a treasure is granted mid-match** (impossible from Run Structure; forward-compatibility):
  it takes effect at the next `begin_match` — `treasures[]` is read only there (R5.6).
- **If the match faults or is conceded**: the registry dies with `MatchState`; a retry (R4) or the
  next floor re-installs from the id list.

**Value folds and clamps**

- **If two treasures take a cost below 0** (Grimoire −1 and Banner −1 on a 1-cost spell played
  first): `fold = −1`, the engine floors to 0 once after the fold (F1); no mana is refunded and the
  event logs `hook_delta: −2`. A 0-cost card still counts as "played" for `cards_played_this_turn`,
  so Banner's discount then moves to nothing.
- **If `modify_starting_hand_size` exceeds `HAND_SIZE`** (Bottomless Satchel +2 plus a passive +6
  → 11): clamp to `HAND_SIZE` (match-rules hook table — R-5 landed 2026-11-03), so setup never
  burns a card. The mulligan mask length follows the resulting hand (match-rules Edge Cases).
- **If `modify_max_attacks` meets Windfury** (Twin Grip `set 2` on a Windfury weapon, base 2):
  result 2, no third swing. **If the hero has no weapon and no Attack**: `max_attacks` 2 is
  irrelevant — `attack > 0` fails the F3 predicate.
- **If Twin Grip's first swing destroys the weapon** (durability 1): the hero's Attack is 0 for the
  second swing; `attacks_remaining` is 1 but no legal attack exists. Shown by the hero portrait's
  attack state, not an error.
- **If `modify_heal` yields a negative value** (a passive "the player's heals restore 3 less"):
  engine floors at 0 (match-rules hook table — R-4 landed); `apply_heal(…, 0)` emits `healed 0`.

**State and persistence**

- **If the player quits mid-match and resumes** (R8.3 = restart the floor): `EffectRuntime`
  (counters, `once_per_turn` marks) is gone with the match; `treasure_state` is unchanged because
  it is written only at match end (T4); the restart installs the same ids in the same order and the
  match replays identically up to the player's divergence.
- **If `treasure_state.schema_version` is unknown on resume**: the blob is ignored,
  `run_warning{treasure_state_reset}`, installers start stateless. Nothing in v1 reads it, so no
  v1 run can be affected.
- **If an unlock is revoked mid-run** (profile reset while a run holding Grave Tithe is active):
  the run keeps it — `treasures[]` is the authority for Held and the unlock check gates offers
  only (T6; mirrors run-structure R8.4 for heroes). The current run's offers are also unchanged,
  because Reward Draft snapshotted the pool at `init_run` (T6); the next run's `pool()` excludes
  it, and the run log shows it with a lock glyph afterwards (Run UI). Rationale: a run is a sealed contract; pulling a
  treasure out of a live deck is an unexplained loss (anti-Pillar 3).
- **If Meta Progression is absent** (MVP): `unlocked_keys = ∅` and every `unlock: null` treasure is
  available — the 10 MVP treasures are all `null` (T8).

**Content specifics**

- **If Hollow Crown runs on a turn where `mana_max` is already 10**: nothing more to gain — the
  crystal is `crystal_bonus = 1`, set once at match start, and every Start step reads
  `mana_max = min(turns_taken + crystal_bonus, MAX_MANA)` (match-rules C4 step 2, F4): turn 1
  gives 2/2, the benefit covers turns 1–9 and `MAX_MANA` caps turn 10 onward. Logged once as
  `mana_added` at match start, then `crystal_gained` at each Start step where `mana_max` rose.
- **If Scholar's Candle runs under a turn order other than DD-M03** (a future "boss first" mode):
  `match.turn ∈ {3, 7}` would be boss turns. The mapping is a Tuning Knob; card-effects C4 now
  exposes `owner.turns_taken` (R-6, resolved), so switching the sketch to `owner.turns_taken ∈
  {2, 4}` is a data change that removes the dependency when such a mode arrives.
- **If Grave Tithe fires with a full board**: `summon_failed{board_full}`; the `once_per_turn`
  mark is still consumed (set when queued, C6.7). **If several friendly minions die together**:
  one Husk. **If the Husk dies**: it is a friendly minion death and may trigger next turn — one per
  turn by construction, so no loop. "Once per turn" counts global `match.turn`, so the player's
  turn and the boss's turn each allow one Husk.
- **If Living Armory finds no Legendary minion in the collectible pool** (possible at MVP's ~40
  cards): `add_to_hand … from` is a no-op `empty_pool`, logged; the treasure does nothing that
  match. Content keeps ≥ 2 Legendary minions in every hero's collectible pool once the treasure is
  unlockable (it is non-MVP). The random pick draws from `match_<floor>` after the deck shuffles
  (C3 step 3 → 4), so it is seed-reproducible.
- **If Thornhide Cloak's hero takes fatigue damage or damage fully absorbed by Armour**:
  `on_hero_damaged` fires with `amount_dealt ≥ 1` in both cases (F2: `dealt` includes
  `armor_absorbed`), so the cloak grants Armour. Intended and legible ("Thornhide Cloak: +1
  Armour" after a fatigue tick).
- **If Mending Charm heals a full-health hero**: `healed 0` is emitted; Match UI may suppress
  zero heals in the feed, the log keeps them.
- **If Focusing Prism meets an AoE spell**: +1 per target (each `apply_damage` passes F2) — same
  as Spell Damage. **If a spell's damage is already raised by Spell Damage minions**: F7 adds to
  `requested` before F2, the Prism adds inside F2; both apply, additively.
- **If a Captured Standard / Stampede Horn / Plague Bell recipient is Silenced**: the aura is
  stripped and re-applied at the next recompute (card-effects C7) — net no change, as for any aura.
- **If Iron Constitution meets a passive "the player starts at 20 Health"** (`buff health −10`):
  treasure first, passive last: `30 + 10 − 10 = 30`, both enchantments visible in the log.

## Dependencies

The systems index lists Treasures as depending on Card Effects, Run Structure, Card Database and
RNG & Event Log, and as depended on by Reward Draft, Meta Progression and Content. This table adds
**Match Rules** (the hook points — the index folds it under Card Effects) and **Heroes** (tags and
tokens) upstream, and **Boss AI, Match UI, Run UI** downstream; the index was updated 2026-11-03 (cross-review V-29).
Bidirectionality re-checked 2026-11-03 — every partner GDD now exists: Card Database, Card
Effects, Match Rules, Run Structure, RNG & Event Log, Heroes and Boss AI name Treasures in their
Dependencies; Reward Draft lists Treasures upstream (data) and carries the T6 contract; Meta
Progression lists Treasures as Mutual/Soft; Match UI and Run UI list Treasures as Soft (Run UI
reads `TreasureDef` through Card Database only); Content lists Treasures as a soft concurrent
dependency (CN-5).

| System | Direction | Hard/Soft | Nature of Dependency |
|--------|-----------|-----------|---------------------|
| Card Database | This depends on Card Database | Hard | `TreasureDef` records (`treasure()`, `treasure_pool()` id-ascending), `has(id)` for token refs, CR-5 stage 7 slot for the T7 validator; the `tags` field (CR-3, R-7 resolved). |
| Card Effects | This depends on Card Effects | Hard | The DSL every effect is written in; hook bindings per trigger (C2); `validate_effects`; resolver binding of installers in pick order, passive last (C6.1, C9); `once_per_turn` and counters (`EffectRuntime`). |
| Match Rules | This depends on Match Rules | Hard | The 12 hook points and signatures; `MatchState.hooks` as the registry's home; post-fold clamps (F1, F2); primitives the ops call. R-1 (`crystal_bonus`, C5/F4), R-4 (`modify_heal` floor) and R-5 (clamps, `MAX_ATTACKS_CAP` 4) landed 2026-11-03. Match Rules lists this as Soft from its side (identity hooks when none installed) — consistent. |
| Run Structure | This depends on Run Structure | Hard | `treasures[]` in pick order at every `begin_match` (R3), `treasure_state` persisted opaquely (R1), `treasure_granted` (R5.4), restart = re-install (R8.3, R8.5). Run Structure calls `installers_for` and `collect_state` (R4, confirmed). |
| RNG & Event Log | This depends on RNG & Event Log | Soft | Events `effect_resolved` (`source_id` = treasure id, `cause_seq`), `hook_install_skipped`; no direct stream use. Works without the log but is then invisible (its own words). |
| Heroes | This depends on Heroes | Soft | H-5 theme tags as the plan-tag vocabulary; tokens `decay_husk` (Grave Tithe) and the weapon slot semantics Whetstone Wheel and Twin Grip act on; affinity names War/Decay/Knowledge. |
| Reward Draft | Reward Draft depends on this | Hard (for them) | `pool(unlocked_keys, exclude_ids)`; `rarity` for the 70/30 weights; `tags` for affinity/plan weighting; no-duplicate rule. Confirmed in reward-draft D3, D7, F2. |
| Meta Progression | Mutual | Soft | In: `unlocked_keys()` read once at `init_run` (reward-draft D3, meta M3.7); the unlock-key validator (M2.4). Out: the four keys T8 names (conditions in meta M10). Confirmed in meta-progression Interactions / Dependencies. |
| Boss AI | Boss AI depends on this | Soft | `MatchState.clone()` must carry hook entries by value so look-ahead sees treasure and passive effects (boss-ai GDD provisional note). |
| Match UI | Match UI depends on this | Soft | Tray contents in pick order; `source_id` for feed lines and tray flare. |
| Run UI | Run UI depends on this | Soft | Offer card fields (`name`, `rarity`, `text`, `tags`); locked/held display in the run log and summary. |
| Content | Content depends on this | Hard (for them) | The 20 v1 records are authored here; Content extends `treasures.json` under T7 validation and F1 bands. |

## Tuning Knobs

`systems-designer` not consulted — Lean mode. Review manually before production. Knobs live in
`assets/data/treasures_balance.json` (conversion constants, bands, limits) and in each record's
`effects` (magnitudes) in `assets/data/treasures.json`. **Interacting knobs**: the three cost
discounts (Banner, Ledger, Grimoire) compose on one card — raising any one of them above 1 makes
0-cost first cards routine; `treasure_floors` (run-structure) × `offers_per_draft` must stay ≤
unlocked treasures or Reward Draft runs dry; `COMMON_BAND`/`RARE_BAND` and the `V_*` constants
move every rarity at once — change the bands, not the constants, to re-tier the pool. Knobs owned
elsewhere and only cited: rarity weights 70/30 and pity (Reward Draft), `treasure_floors` (Run
Structure), `HAND_SIZE`, `MAX_MANA`, `MAX_ATTACKS_CAP = 4` (Match Rules).

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `MAX_EFFECTS_PER_TREASURE` | 3 | 1–5 | Richer treasures, harder to read on one line | 1 forces every treasure to a single clause |
| `COMMON_BAND` / `RARE_BAND` | [1.5, 3.5] / [3.5, 6.5] | overlap-free, ≥ 1.0 wide | Wider rare band → more treasures qualify as Rare, offers feel swingier | Narrow bands → more `W_TR_POWER` noise |
| `V_CARD`, `V_DMG`, `V_HP`, `V_STAT`, `V_TOKEN`, `V_RUSH` | 1.5, 0.5, 0.35, 0.5, 1.0, 0.5 | ±50 % | Re-tiers whole archetypes (e.g. `V_HP` 0.5 pushes Iron Constitution to Rare) | Opposite |
| `ETA_MANA`, `ETA_CRYSTAL`, `ETA_FIRST`, `ETA_OVERHEAL` | 0.7, 0.6, 0.8, 0.5 | 0.4–1.0 | Discounts rated higher → economy treasures drift to Rare | Economy treasures look weak on paper while playing strong |
| Match-model constants (`T_TURNS`, `N_*`, `AOE_FACTOR`) | F1 table | per `/balance-check` from run logs | Longer modelled matches inflate per-turn treasures (Crown, Banner, Charm) | Inflate one-shot treasures (Satchel, Armory) relatively |
| Hollow Crown crystals | 1 | 1–2 | 2 → ~9 mana-eq, above any band; would need a drawback | — |
| Worn Signet power cost | 1 | 0–1 | — | 0 → 4 × 2 × 0.7 = 5.6 (card-effects row 39); Rare |
| Ledger threshold / discount | 5 / 1 | 4–6 / 1 | Threshold 4 hits ~5 plays → 3.5 (boundary) | 6 → ~1.4, below Common |
| Banner discount | 1 | 1 | 2 is a Crown-and-a-half; do not | — |
| Sprinter's Boots cost ceiling | 3 | 2–4 | 4 ≈ Stampede Horn minus one minion → Rare | 2 ≈ 1.5, floor of Common |
| Scholar's Candle turns | player turns {2, 4} | 1–3 turns from {1..6} | Three turns → 4.5, Rare; turn 1 is strongest (tempo) | One turn → 1.5 |
| Bottomless Satchel extra cards | 2 | 1–3 | 3 → 5.9, top of Rare; mulligan screen must fit 6 | 1 → 2.0, Common |
| Iron Constitution Health | 10 | 5–15 | 15 → 5.3, Rare | 5 → 1.75, weakest Common |
| Thornhide Cloak Armour per hit | 1 | 1–2 | 2 → 4.2, Rare | — |
| Mending Charm heal | 2 | 1–3 | 3 → 4.7, Rare | 1 → 1.6 |
| Whetstone Wheel Attack | 1 | 1–2 | 2 → 5.0, Rare; weapon bundles redundant (heroes Tuning Knobs) | — |
| Twin Grip attacks | 2 | 2 (3 needs `MAX_ATTACKS_CAP` ≥ 3) | 3 → ~8, out of band | — |
| Grave Tithe `once_per_turn` | true | true / false | false → unbounded Husks, ~8+; the legendary Husk Mother's job | — |
| Rotting Bargain / Grimoire discount | 1 / 1 | 1 | 2 → 0-cost spells; out of band | — |
| Plague Bell / Captured Standard Attack | 1 / 1 | 1–2 | 2 → Bell 6.0, Standard 8.0; out of band | — |
| Focusing Prism bonus | 1 | 1–2 | 2 → 5.2, Rare | — |
| Living Armory count | 1 | 1–2 | 2 → 8.0; out of band | — |
| `MAX_TREASURES_HELD` (derived, not a knob) | 3 (MVP 2) | — | Set by `treasure_floors`; F5 and the match-screen tray (three chips, match-ui F6; a run holds at most 3 treasures, DD-R05) assume ≤ 3 | — |

## Visual/Audio Requirements

`art-director` not consulted — Lean mode (treasure feedback is one event the player reads, not
central to play). Review manually before production. Placeholder art in v1 (art bible §5–9
deferred): each treasure is a 48×48 chip — hero-colour frame for its affinity (War red-bronze,
Decay green-violet, Knowledge blue-gold, universal parchment), a rarity edge (Common plain, Rare
gilt), and the name's initial. "Torchlit Ledger" rule: the tray sits in the lit band with the
hero portrait, never brighter than the board.

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Treasure draft offered (`draft_offered`, kind treasure) | Three chips scale up face-up in a row, rarity edge visible, text beneath | Reward stinger (shared with bundle draft) | Must |
| Treasure picked (`treasure_granted`) | Picked chip flies to the run strip's treasure tray; the other two fade | Short confirm | Must |
| Hooks installed (match start) | **None** — the tray is simply populated when the match screen opens (decision: no install animation in v1) | None | Must (as a non-event) |
| Treasure fires (hook-hosted `effect_resolved`, `source_id` = treasure) | Chip flare 150 ms + screen-edge glow in the hero colour (card-effects Impact Moments); feed line "Thornhide Cloak: +1 Armour" | Treasure cue, distinct from card SFX (card-effects V/A table) | Must |
| Value hook active (`modify_cost` lowering a card) | Cost gem tinted "discounted" on affected hand cards and on the hero-power button; tooltip names the treasure | None | Must |
| Aura treasure active (Rush / +1 Attack on minions) | Standard buff tint on recipients; chip has a steady low glow while any recipient exists | None | Should |
| Locked treasure in the run log / summary | Chip desaturated with a lock glyph and the unlock hint from Meta Progression | None | Should (Alpha) |

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run
`/asset-spec system:treasures` to produce per-asset visual descriptions, dimensions, and
generation prompts from this section.

## Game Feel

Treasures are passive: the player never operates them, so most feel targets are **N/A** and the
section is short by design. The one feel property the system owns is **"it fires before you can
act"** — a treasure's effect should be visibly done before the hand becomes interactive, so the
player never wonders whether it applied.

### Feel Reference
Monster Train's artifact flare at the top of a fight and Slay the Spire's relic shake when a relic
procs: a small, unmistakable "that was me" from the HUD, never a modal. Anti-reference: Hearthstone
Dungeon Run passives, which apply silently and leave the player checking the tooltip.

### Input Responsiveness
| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|------------------------|-------|
| Hover a tray chip → tooltip | 100 | 6 | Same budget as card tooltips (Match UI) |
| Pick a treasure on the draft screen | 50 | 3 | Shared with the bundle picker |

### Animation Feel Targets
| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Chip flare on fire | 0 | 9 (150 ms) | 6 | Crisp, attributable | Never delays the next rules step; purely cosmetic |
| Chip fly-to-tray on pick | 3 | 18 | 0 | Ownership | Skippable by click |

### Impact Moments
| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Treasure fires | 150 | Chip flare + edge glow (card-effects table) | Yes |
| Hit-stop / screen shake / rumble / slowdown | — | None — treasures add no kinetic feedback of their own | — |

### Weight and Responsiveness Profile
Weightless and instantaneous: a treasure is a rule, not an action. Player control is total before
(the pick) and nil during (it just happens). Snap quality is binary — it fired or it did not, and
the feed says which. Failure texture: a treasure never "fails"; when it does nothing (board full,
empty pool, full health) the log line says why, so the read is always "the rule held, the
situation didn't allow it".

### Feel Acceptance Criteria
- [ ] In playtest, players asked "did your treasure do anything that match?" answer correctly ≥ 90 % of the time without opening the log.
- [ ] No tester describes a treasure effect as "invisible" or "I didn't notice it".
- [ ] A turn-start treasure's flare and feed line complete before the first hand card becomes draggable.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|-----------------|-----------|
| Held treasures as chips, **in pick order** (= installation order) | Run strip's treasure tray on the match screen (next to the player hero portrait) and on the pre-match boss intro | On `treasure_granted`; populated at match-screen open with no animation | Always when ≥ 1 held; tray has 3 chip slots (match-ui F6) |
| Chip tooltip: name, rarity (colour + word), rules `text`, tags as small pills, "picked on floor f" | Hover / keyboard focus on a chip | Static per treasure | Any screen showing chips |
| Treasure fired: feed line naming the treasure and the result ("Scholar's Candle: drew a card") | Event feed; chip flare | Per hook-hosted `effect_resolved` | Always; zero-effect firings (`healed 0`, `empty_pool`) shown as "… (no effect)" |
| Discounted cost from `modify_cost` on hand cards and the hero-power button | Card cost gem / power button | Every F1 evaluation (Match UI reads `legal_commands()` / state) | While the discount applies |
| Treasure draft: three offers with name, rarity edge, text, tags; pick confirm | Reward screen, kind header "Treasure" (then "Bundle") | Per draft | `post_match_reward / treasure` |
| Treasures held, in pick order, on the victory / death summary and the run log | Summary screen; run log entry | Once per run | Terminal states; locked ones shown with a lock glyph (Alpha) |
| Data-error detail for a failed treasure record (`E_TR_*`, `E_FX_*`) | Card Database's data-error screen | At load | `Failed` load |

Not shown anywhere: hook internals, `treasure_state`, F1 power numbers (debug overlay only).

> **📌 UX Flag — Treasures**: This system has UI requirements. In Phase 4 (Pre-Production), run
> `/ux-design` to create a UX spec for each screen or HUD element this system contributes to
> **before** writing epics — the match HUD treasure tray (`design/ux/hud.md`) and the reward /
> draft picker screen. Stories that reference UI should cite `design/ux/[screen].md`, not the GDD
> directly. Note this in the systems index for this system if you update it.

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|-----------|----------------------------|--------|
| The 12 hook points, signatures and "installation order" rule | `design/gdd/match-rules.md` | Interactions, hook table; C3 step 4; C4 Start step 4 / End step 3 | Ownership handoff (they own points, we own content) |
| Post-fold clamps: cost ≥ 0, damage ≥ 0 | `design/gdd/match-rules.md` | F1 `effective_cost` (`hook_delta` term), F2 `apply_damage` | Rule dependency |
| `MatchState.hooks` as the registry's home; `clone()` | `design/gdd/match-rules.md` | C1 data model | Data dependency |
| `HAND_SIZE` 10, `MAX_MANA` 10, `crystal_bonus` (permanent `add_mana` at `on_match_start`), `max_attacks` / Windfury, draw/burn | `design/gdd/match-rules.md` | F9 limits; C8; C11; C5 `add_mana`; C4 Start step 2; F4 | Rule dependency |
| Trigger vocabulary with the treasure-host binding column; `self` illegal | `design/gdd/card-effects.md` | C2; C3 selectors; `E_FX_SELECTOR` | Rule dependency |
| Ops used by the pool: `mana`, `buff`, `armor`, `heal`, `draw`, `summon`, `add_to_hand from`, `aura`, `modify_value`; `once_per_turn`; counters | `design/gdd/card-effects.md` | C5; C6.7–8 `EffectRuntime` | Data dependency |
| Installer binding in pick order, passive last; hooks-first ordering | `design/gdd/card-effects.md` | C6.1, C6.3 table, C9 | Rule dependency |
| Treasure auras hosted on the hero slot; aura stacking and Silence | `design/gdd/card-effects.md` | C7, F2 | Rule dependency |
| Validation codes and `EFFECT_STATIC_STEP_LIMIT` | `design/gdd/card-effects.md` | C10; F6 | Rule dependency |
| Rows 39, 40, 42, 43 as pre-validated treasure shapes | `design/gdd/card-effects.md` | C11 archetype coverage; v2 list (`weapon_durability`) | Data dependency |
| `treasures[]` in pick order; `treasure_state` opaque; `installers_for` at every `begin_match`; nothing at pick time | `design/gdd/run-structure.md` | R1, R3, R5.4, R5.6, R8.3, R8.5 | Ownership handoff (contract restated here) |
| `treasure_floors` `[1, 3, 5]`; `treasures_held(f)` | `design/gdd/run-structure.md` | R5.1; F4; registry `treasure_floors` | Data dependency |
| `TreasureDef` shape; `treasure_pool()` id-ascending; stage-7 validator slot; `rarity` enum | `design/gdd/card-database.md` | CR-3, CR-4, CR-5, CR-6; `min_treasure_pool` = 9 | Ownership handoff / Rule dependency |
| H-5 theme tags; tokens `decay_husk` 1/1, `war_whetstone_blade` 1/2; Whetstone weapon-slot states | `design/gdd/heroes.md` | H-5; token table; States | Data dependency |
| `effect_resolved` with `source_id` and `cause_seq`; JSON-only run state | `design/gdd/rng-event-log.md` | Event catalogue; rule 14 | Data dependency |
| `clone()` carries hook entries for look-ahead | `design/gdd/boss-ai.md` | Provisional note on hooks in clones | Rule dependency |
| Pool snapshot at `init_run`, `seen` derived from `drafts[]`, per-item `treasure_weight`, universal slot, short-pool policy | `design/gdd/reward-draft.md` | D3, D7, D8, F2; Treasures contract paragraph | Ownership handoff (contract restated in T6) |
| Unlock keys and the unlock state (`unlocked_keys()`, M1.3); unlock-key validator (M2.4); the four M10 keys and their conditions; `unlock_granted` (M3.6) | `design/gdd/meta-progression.md` | M1.3, M2.1, M2.2, M2.4, M3.6, M10 | Ownership handoff (keys named here, conditions defined there — R-14 resolved) |
| Pillar 1 ("treasures are run-defining rather than stat bumps"), Pillar 4 | `design/gdd/game-concept.md` | Game Pillars; Unique Hook | Rule dependency |
| DD-R05, DD-H04, DD-H06, DD-M03, DD-M04, DD-T01, DD-T02, DD-X01 (`unlock` object) | `design/design-decisions.md` | Register rows | Rule dependency |
| TD-009 (global, untyped modifier manager) retired by T2 | `docs/tech-debt-register.md` | TD-009 | Rule dependency |
| Prototype hook chain: fold / AND / trigger shapes, priority dropped, no back-reference | `docs/architecture/modifier-hook-chain.md` | Decision; Follow-Up Work | Prior art (not an ADR) |

## Acceptance Criteria

`qa-lead` not consulted — Lean mode. Review manually before production. Fixtures: data file
`tests/fixtures/data/treasures_v1.json` (the 20 T8 records) plus a boss fixture
`boss_test_taxman` whose passive is `modify_cost delta +1` on all friendly cards and hero power;
`run_seed_hex` **`00000000000000A7`** unless stated; hero `hero_war`; Logic criteria are gdUnit4
unit/integration tests (`tests/unit/treasures/`, `tests/integration/treasures/`), UI criteria are
retained screenshots in `production/qa/evidence/`.

**Hook chain and contract**

- [ ] AC-1 **GIVEN** ids `[treasure_worn_signet, treasure_hollow_crown]`, **WHEN** `installers_for` is called twice, **THEN** both results are equal, in that order, no event is emitted and `RunState` is unchanged.
- [ ] AC-2 **GIVEN** those two installers plus `boss_test_taxman`'s passive, **WHEN** the match starts, **THEN** `MatchState.hooks.modify_cost` holds entries in the order `[signet, taxman]` and `on_match_start` holds `[crown]`; the hero power's displayed cost is `fold(2) = set 1 → +1 = 2`.
- [ ] AC-3 **GIVEN** installers `[signet, signet]`, **WHEN** bound, **THEN** exactly one `modify_cost` entry exists and one `hook_install_skipped{host_id: treasure_worn_signet, reason: duplicate}` is logged.
- [ ] AC-4 **GIVEN** `installers_for([signet, crown, signet])`, **THEN** two installers are returned and one `run_warning{code: duplicate_treasure, treasure_id: treasure_worn_signet}` is emitted.
- [ ] AC-5 **GIVEN** fixture records with (a) trigger `battlecry`, (b) a `summon` of a `set: boss` card, (c) tags `[war, decay]`, (d) `rarity: legendary`, **WHEN** loaded, **THEN** the report contains `E_FX_TRIGGER`, `E_TR_TOKEN_REF`, `E_TR_TAGS`, `E_TR_RARITY` respectively and the load is `Failed`.
- [ ] AC-6 **GIVEN** a headless unit test with no `SceneTree` and no autoload, **WHEN** a `HookRegistry` is built from `installers_for` and `on_turn_start` is invoked, **THEN** the entries run and no object in the chain holds a `Node` or a reference back to the registry (reflection check on `HookEntry`).
- [ ] AC-7 **GIVEN** a match with `[crown, cloak]` installed, **WHEN** `MatchState.clone()` is advanced one boss action, **THEN** the clone's hook results equal a real advance's results and the real log gained no event.
- [ ] AC-8 **GIVEN** `[treasure_vanguards_banner, treasure_dogeared_grimoire]` and a 1-cost spell as the first card of the turn, **THEN** its displayed and paid cost is 0 and the F1 event logs `hook_delta: −2`.
- [ ] AC-9 **GIVEN** seed `00000000000000A7`, `[crown, cloak]`, **WHEN** the match is begun, quit after the player's second command, resumed and restarted, **THEN** the two logs are identical up to the first player command (`deck_shuffled`, `mana_added`, `card_drawn` sequences match) and the restarted registry equals the first.
- [ ] AC-10 **GIVEN** any v1 pool subset, **WHEN** `collect_state` runs after `match_ended`, **THEN** it returns `{schema_version: 1, by_treasure: {}}`; **GIVEN** a saved `treasure_state` with `schema_version: 99`, **WHEN** resumed, **THEN** `run_warning{treasure_state_reset}` and the installers equal a stateless run's.
- [ ] AC-11 **GIVEN** a run holding `treasure_grave_tithe` and an `unlocked_keys` set that no longer contains `hero_decay_first_win`, **WHEN** `begin_match`, **THEN** Grave Tithe is installed; **WHEN** `pool(unlocked_keys, [])` is queried, **THEN** it is absent.
- [ ] AC-12 **GIVEN** the 20-record fixture, **WHEN** `pool(∅, ∅)`, **THEN** 16 ids in ascending order; `pool(all four keys, ∅)` → 20; `pool(∅, [treasure_worn_signet])` → 15 without it.
- [ ] AC-13 **GIVEN** `[treasure_bottomless_satchel]` and a passive `modify_starting_hand_size delta +6`, **WHEN** starting hands are dealt, **THEN** the player's hand is exactly 10 (`clamp(3 + 2 + 6, 0, HAND_SIZE)`, match-rules hook table — R-5 landed 2026-11-03), no `card_burned` is emitted during C3 step 5, and the match reaches `Mulligan` without a fault. (Re-issued 2026-11-03 in its post-R-5 form; the pre-R-5 "exactly one `card_burned`" form is withdrawn.)
- [ ] AC-14 Performance (headless, gdUnit4, same machine for both arms): **GIVEN** a registry with 12 entries, **WHEN** `modify_cost` is folded 10,000 times, **THEN** the mean per fold is < 0.05 ms **and** the fold allocates nothing (Godot `Performance.OBJECT_COUNT` / `MEMORY_STATIC` unchanged across the loop); **GIVEN** the same scripted 9-turn match run with 3 treasures and with an empty registry, **THEN** the 3-treasure arm's wall time is ≤ 1.05 × the empty arm's over the median of 5 runs.

**MVP treasures** (one each; all use the fixture seed)

- [ ] AC-15 Hollow Crown: **WHEN** `match_started`, **THEN** the `on_match_start` hook calls `add_mana(PLAYER, 1, temporary=false)` and `mana_added{side: player, n: 1, temporary: false}` (its `cause_seq` → `effect_resolved{source_id: treasure_hollow_crown}`) precedes the first `card_drawn`; `PlayerState.crystal_bonus` is 1 and every Start step reads `mana_max = min(turns_taken + crystal_bonus, 10)` (match-rules C4 step 2, F4), so player turn 1 reads 2/2 (with `crystal_gained`), turn 8 reads 9/9, turn 9 and 10 read 10/10; the boss's `crystal_bonus` stays 0 and its turn 1 reads 1/1.
- [ ] AC-16 Worn Signet: **THEN** the hero-power button shows 1; using it spends 1 mana; a second use the same turn is rejected `HERO_POWER_USED`; against `boss_test_taxman` it shows 2.
- [ ] AC-17 Vanguard's Banner: **GIVEN** player turn 4 (4 mana) with a 3-cost minion and a 2-cost spell in hand, **THEN** both show −1 before any play; after playing the minion for 2, the spell shows 2 and is playable, ending at 0 mana; the hero-power cost is unaffected throughout (card-effects C2: `scope.card` without `kind` matches card instances only — R-13 resolved 2026-11-03).
- [ ] AC-18 Scholar's Candle: **THEN** exactly one extra `card_drawn` with `cause_seq` → `effect_resolved{source_id: treasure_scholars_candle}` occurs at the Start of player turns 2 and 4 (`match.turn` 3 and 7), before that turn's natural draw, and none on turns 1, 3, 5.
- [ ] AC-19 Bottomless Satchel: **THEN** `mulligan_offered` lists 5 cards, a `keep_mask` of length 5 is accepted and length 3 is `INVALID_MASK`; the boss still draws 4.
- [ ] AC-20 Iron Constitution: **THEN** `match_started` shows the player hero at 40/40 with one `enchantment_added{source_id: treasure_iron_constitution, health_delta: 10}`; after 15 damage the hero reads 25/40.
- [ ] AC-21 Thornhide Cloak: **GIVEN** hero 30 health / 0 Armour, **WHEN** a boss minion deals 3, **THEN** `armor_gained 1` follows `damage_dealt` in the same action (27 health, 1 Armour); **WHEN** a fatigue tick of 1 hits, **THEN** Armour absorbs it and a new `armor_gained 1` follows.
- [ ] AC-22 Whetstone Wheel: **WHEN** Whetstone equips the 1/2 blade, **THEN** the weapon reads 2 Attack via an `is_aura` enchantment with `source_id: treasure_whetstone_wheel` and the hero attacks for 2; **WHEN** the weapon is destroyed, **THEN** no aura enchantment remains; a later weapon gains it again.
- [ ] AC-23 Twin Grip: **GIVEN** a weapon with 2 durability, **THEN** the hero attacks twice in one turn (two `attack_resolved`), the weapon is destroyed at the second swing, and a third `attack` is rejected; **GIVEN** a Windfury weapon, **THEN** still two attacks.
- [ ] AC-24 Stampede Horn: as card-effects AC-32 — a minion played this turn may attack an enemy minion and is `RUSH_CANNOT_HIT_HERO` against the hero; next turn it attacks freely; without the treasure the same play is `SUMMONING_SICK`.

**Non-MVP spot checks and data rules**

- [ ] AC-25 Grave Tithe: **WHEN** two friendly minions die in one action, **THEN** one `decay_husk` is summoned at the board's right end; **WHEN** the board is full, **THEN** `summon_failed{board_full}` and no second Husk that turn even if another minion dies.
- [ ] AC-26 Living Armory: **GIVEN** a collectible pool with no Legendary minion, **THEN** `effect_resolved.ops[0].outcome = empty_pool` and the hand is 3 after starting draws; **GIVEN** the full v1 pool and seed `00000000000000A7` twice, **THEN** the same Legendary is added both times.
- [ ] AC-27 Focusing Prism: **WHEN** "deal 1 damage to all enemy minions" is cast at three enemy minions, **THEN** each takes 2 and `effect_resolved.values` show `hook_delta: +1` per target.
- [ ] AC-28 Mending Charm: **WHEN** the owner's turn ends at full health, **THEN** `healed{amount: 0, source_id: treasure_mending_charm}` is emitted and the feed shows "(no effect)".
- [ ] AC-29 **GIVEN** a fixture copy of Hollow Crown with `rarity: common`, **WHEN** loaded, **THEN** `W_TR_POWER` is reported and the load is `OK`.
- [ ] AC-30 No hardcoded values: **GIVEN** the fixture's Iron Constitution edited to `health: 5`, **WHEN** the match starts, **THEN** the hero reads 35/35 with no code change; every magnitude in T8 is read from `treasures.json` and every F1 constant from `treasures_balance.json`.

## Open Questions

Requests to other GDDs are **requests, not assumptions**: the pool above is valid without them
except where the row says a treasure waits on it.

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| **R-1** Does `add_mana(side, 1, temporary=false)` at `on_match_start` raise `mana_max` permanently (Hollow Crown)? Match-rules C5 says "no crystal gain in v1" but lists `add_mana` in the primitive API and card-effects C5 exposes `mana … permanent`. | Match Rules | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-02**: match-rules C5 `add_mana(side, n, temporary=false)` at `on_match_start` raises `PlayerState.crystal_bonus` permanently; C4 Start step 2 / F4 read `mana_max = min(turns_taken + crystal_bonus, MAX_MANA)`; its AC-06 asserts 2/2 on turn 1. Fallback text withdrawn; T8 row 1, T9, Edge Cases and AC-15 updated |
| **R-2** Is `condition` legal on a value trigger and evaluated per fold call (Vanguard's Banner reads `cards_played_this_turn == 0` on every F1 evaluation)? If not, request scope key `first_card_this_turn: true` on `modify_cost`. | Card Effects | before Content batch 1 | **Resolved 2026-11-03 — cross-review C-26**: card-effects C1 — `condition` on a value trigger is evaluated on every fold call; a false condition leaves `context.value` unchanged |
| **R-3** Does the `tag` filter predicate apply to minions on the board (reading the definition's tags)? C3 lists it for cards and pools only. Plague Bell needs it. | Card Effects | Alpha | **Resolved 2026-11-03 — cross-review C-26**: card-effects C3 — `tag` and `set` also apply to minions on the board, reading the definition's `tags` |
| **R-4** State the `modify_heal` post-fold floor (`max(0, ·)`) in match-rules C9/F2 (F2 here assumes it). | Match Rules | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-26**: match-rules hook table, `modify_heal` row — "engine floors at 0" |
| **R-5** Add clamps `modify_starting_hand_size → [0, HAND_SIZE]` and `modify_max_attacks → [0, MAX_ATTACKS_CAP = 4]` to the hook table. | Match Rules | before Bottomless Satchel / Twin Grip stories | **Resolved 2026-11-03 — cross-review C-26**: match-rules hook table clamps `modify_starting_hand_size` to `[0, HAND_SIZE]` and `modify_max_attacks` to `[0, MAX_ATTACKS_CAP]` (default 4); AC-13 re-issued in its post-R-5 form |
| **R-6** Add ref `owner.turns_taken` (and `opponent.turns_taken`) to the C4 closed set so Scholar's Candle does not depend on DD-M03's turn order. | Card Effects | Alpha | **Resolved 2026-11-03 — cross-review C-26**: card-effects C4 ref set includes `owner.turns_taken` (match-rules `PlayerState.turns_taken`); the v1 Candle sketch keeps `match.turn ∈ {3, 7}` (Tuning Knob) — switching is a data change |
| **R-7** Add `tags: string[]` to `TreasureDef` (CR-3); exactly one affinity tag. | Card Database | before `treasures.json` is authored | **Resolved 2026-11-03 — cross-review C-26**: card-database CR-3 `TreasureDef` carries `tags` (reward-draft Interactions confirms) |
| **R-8** Add `treasures_balance.json` to DD-T01's file list. | design-decisions.md | with R-7 | **Resolved 2026-11-03** — DD-T01 already lists it |
| **R-9** Who emits `treasure_granted`: run-structure R5.4 says Run Structure; rng-event-log's catalogue attributes it to Reward Draft. This GDD assumes Run Structure. | Run Structure / RNG & Event Log | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-26 / V-19**: rng-event-log's catalogue now attributes `treasure_granted` to Run Structure (R5.4) |
| **R-10** Confirm T2.5: event triggers legal on treasure hosts but without a hook column (`on_minion_died`, `on_attack`, …) run as observers hosted on the owner's hero slot, queued after hooks, in the "hero power / hero enchantments" candidate position. Grave Tithe depends on it. **Also**: card-effects C6.7 keys `once_per_turn` on `(effect_id, source entity_id, match.turn)`, and a treasure has no `entity_id` (T1) — confirm the key uses `host_id` for treasure/passive hosts. | Card Effects | before Decay content | **Resolved 2026-11-03 — cross-review C-26**: card-effects C9 defines the hero-slot observer position for hook-less event triggers on treasure/passive hosts; its Edge Cases key Grave Tithe's `once_per_turn` mark on the treasure id |
| **R-11** `Treasures.collect_state(hooks, match_result) → Dictionary` called after `match_ended`, before save S2; result stored in `treasure_state`. | Run Structure | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-26**: run-structure R4 calls `Treasures.collect_state(hooks, match_result)` after `match_ended`, before save S2, and persists the result opaquely (its AC-35); no v1 treasure uses it |
| **R-12** Cross-match counter treasures ("+1 Attack per boss beaten") need `add_counter … persist: true` writing through `collect_state`. | Card Effects + this GDD | v2 | Deferred |
| **R-13** Does `scope.card` without `kind` match cards only (excluding the hero power)? Banner and Grimoire assume yes. | Card Effects | with R-2 | **Resolved 2026-11-03 — cross-review C-26**: card-effects C2 `modify_cost` — `card` without `kind` matches card instances only; `kind: hero_power` the hero power only; `kind: any` both. AC-17's conditional clause removed |
| **R-14** Define the four unlock keys named in T8 (`hero_decay_first_win`, `hero_decay_floor_5`, `hero_knowledge_first_win`, `bosses_defeated_16`) and their conditions. | Meta Progression + owner | `/review-all-gdds` | **Resolved 2026-11-03 — cross-review C-26 / V-12 / V-13**: meta-progression M10 now defines exactly these four keys in the M2.2 grammar (`runs_won ≥ 1, hero: hero_decay`; `floor_reached ≥ 5, hero: hero_decay`; `runs_won ≥ 1, hero: hero_knowledge`; `boss_defeated(any) ≥ 16`, cumulative) and the registry `unlock_keys_v1` lists them; the six placeholders are gone. Whether a fifth, any-hero key is added is cross-review D-03 (Content/Meta choice, owner) |
| **R-16** Universal-treasure detection: reward-draft D7/F2 treats `tags == []` as universal, but T1 requires exactly one affinity tag so a universal treasure is tagged `universal` and never `[]` — Reward Draft's universal slot would report `universal_missing` on every draft. Proposed: Reward Draft tests `"universal" ∈ tags` (validator-checked by `E_TR_TAGS`, more legible than absence). | Reward Draft | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-26 / V-26**: reward-draft F2 `universal(t) ⇔ "universal" ∈ tags(t)`; this GDD keeps the explicit tag |
| **R-17** `unlock` field shape: T1 and card-database CR-3 say `string or null`; meta-progression M2.1 proposes `{key, condition} or null` (CR-3 amendment, its Open Questions). T8's `Unlock` column is the key either way; T7 validation is unaffected. | Card Database + Meta Progression + owner | before `/create-architecture` | **Resolved 2026-11-03 — DD-X01 (cross-review C-06)**: `unlock: {key, condition}` or `null` on HeroDef, TreasureDef and BundleDef; T1 updated, T8's Unlock column stays the key |
| **R-18** Unlock-state interface name: this GDD passes a key set (`unlocked_keys`), reward-draft calls `is_treasure_unlocked(id) → bool` at `init_run`, meta-progression offers `unlocked_ids("treasure")`. One name is needed; T6 is written to accept any (`is_unlocked`). | Meta Progression (owner of the interface) | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-10**: meta-progression M1.3 `unlocked_keys() → Set[string]`, read once at `init_run`; `is_treasure_unlocked(id)` is the membership helper; T6 and Interactions updated |
| **R-19** Run UI U8 names the hint field `TreasureDef.synergy_tags[]`; this GDD, Reward Draft and Content all use `tags`. | Run UI | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-26 / V-07**: run-ui U8 reads `tags` ("not a `synergy_tags` field") |
| **R-20** Content CN-5 expects a 5 generic / 5 War / 5 Decay / 5 Knowledge split and an MVP of "5 generic + 5 War"; T8 ships 10 / 4 / 3 / 3 and an MVP of 7 universal + 2 War + 1 Knowledge (Scholar's Candle, a draw effect any hero uses). CN-5 says Content consumes this GDD's ids, so CN-5's expectation updates — unless the owner wants more hero-affine treasures (Pillar 1 favours plan-dependent picks; the current pool is 50/50). | Content + owner | `/review-all-gdds` | **Resolved 2026-11-03 — cross-review C-26**: content CN-5 records the actual 10/4/3/3 split and T8's MVP list (7 universal + 2 War + Scholar's Candle) as the authority |
| **R-15** `summon` with `from: {pool, filter}` (random Legendary **on board** at match start) — v2 candidate; Living Armory uses the hand form. | Card Effects | v2 | Deferred |
| Systems index: add Match Rules and Heroes to Treasures' "Depends On"; add Boss AI, Match UI, Run UI as dependents. | owner (`/map-systems` owns the file) | next index update | **Resolved 2026-11-03 — cross-review V-29 / V-42**: systems-index row 10 lists Match Rules and Heroes upstream and Run UI's row lists Treasures |
| `aura` op targeting `owner_weapon` (Whetstone Wheel): C5 lists `buff` on weapons (attack only); confirm `aura` shares that legality. | Card Effects | with R-2 | **Resolved 2026-11-03 — cross-review C-26**: card-effects C5 `aura` op targets weapons (`attack` only — "your weapons have +1 Attack" on `owner_weapon`) under trigger `aura`; fallback withdrawn |
| Should rarity weights move from Reward Draft to this GDD so power bands and offer odds have one owner? | owner | `/design-system reward-draft` | Open — this GDD cites 70/30 as contract |
