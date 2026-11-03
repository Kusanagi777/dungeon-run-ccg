# Design Decisions Register (cross-system constants)

> Owner decisions and designer defaults that more than one GDD depends on. Each GDD cites the rows
> it uses and may refine them in its Tuning Knobs; a GDD that needs to change a row updates this
> file and runs `/propagate-design-change`. Values here seed `design/registry/entities.yaml`.
>
> Source of owner decisions: Q&A on 2026-11-03 (board layout, heroes, scope, platform).
> Rows marked *default* are designer defaults chosen for coherence, open to tuning.

## Match

| ID | Decision | Value | Source |
|---|---|---|---|
| DD-M01 | Board layout | One row per side, max 7 minions; a summoned minion is placed at a chosen index | Owner |
| DD-M02 | Hero starting health | Player hero 30. Boss health by band: band 1 = 30, band 2 = 40, band 3 = 50 | default |
| DD-M03 | Turn order | Player always acts first on floor 1–8; the boss compensates with one extra starting card | default |
| DD-M04 | Mana | Both sides start turn 1 with 1 crystal, gain 1 per own turn, max 10; crystals refill at start of own turn | default |
| DD-M05 | Starting hand and mulligan | Player draws 3, boss draws 4; the player may replace any subset of the 3 once (Hearthstone rules); replaced cards return to the deck before redraw | default |
| DD-M06 | Hand limit | 10 cards; a draw into a full hand burns the card (logged) | default |
| DD-M07 | Fatigue | Drawing from an empty deck deals 1, then 2, then 3… damage to the owner's hero | default |
| DD-M08 | Card types | Minion, Spell, Weapon. Weapons have attack and durability; a hero with a weapon may attack once per turn (Windfury weapons twice) | default |
| DD-M09 | Keyword set v1 | Taunt, Charge, Rush, Divine Shield, Windfury, Stealth, Lifesteal, Poisonous, Freeze, Silence, Battlecry, Deathrattle, Spell Damage +N, Discover, Aura (static buff while on board) | default |
| DD-M10 | Attack rules | Minions have summoning sickness unless Charge/Rush (Rush: minions only). Taunt must be attacked first. Stealth cannot be targeted until it attacks | default |
| DD-M11 | Death and trigger ordering | Simultaneous damage; deaths checked after each resolution step (match-rules C10), resolved in board order left to right, player side first; Deathrattles queue in that order; auras recomputed after each resolution step. Wording aligned to match-rules on 2026-11-03. | default |
| DD-M12 | Win/loss | A hero at 0 or less health loses when the current action finishes resolving; if both reach 0 in the same action the player loses (boss advantage, legible) | default |
| DD-M13 | Hero power | 2 mana, once per turn, defined in the effect DSL like a spell | default |

## Run

| ID | Decision | Value | Source |
|---|---|---|---|
| DD-R01 | Floors | 8 floors, one boss each. Bands: floors 1–3 band 1, 4–6 band 2, 7–8 band 3 | Owner (8 bosses) |
| DD-R02 | Boss pool | 16 bosses: 6 in band 1, 6 in band 2, 4 in band 3; drawn without replacement within a run | Owner (~16) |
| DD-R03 | Starter deck | 15 cards per hero, fixed | default |
| DD-R04 | Bundle draft | After each win on floors 1–7: choose 1 of 3 bundles; each bundle is 3 cards with a theme tag; all 3 cards join the deck | default (Hearthstone cadence) |
| DD-R05 | Treasure draft | After wins on floors 1, 3 and 5 (in addition to the bundle): choose 1 of 3 passive treasures; no duplicate treasure offers within a run | default (Hearthstone cadence) |
| DD-R06 | Deck growth | 15 → 36 cards by floor 8 (15 + 7×3); no deck size cap; no card removal in v1 | derived |
| DD-R07 | Run end | Losing any match ends the run (death screen with summary); beating floor 8 is victory | Owner |
| DD-R08 | Save/resume | A run saves after every match and every draft; one active run per profile; resume from main menu | default |
| DD-R09 | Run seed | Every run has a 64-bit seed shown on the summary; the same seed and hero reproduce boss sequence and offers (not AI decisions after player divergence) | default (Pillar 4) |

## Heroes and content

| ID | Decision | Value | Source |
|---|---|---|---|
| DD-H01 | Launch heroes | War (weapons, aggro), Decay (deathrattle, sacrifice), Knowledge (spells, draw, spell damage) | Owner |
| DD-H02 | Unlock heroes | Fortune, Order, Shadow: data-only after v1 | Owner |
| DD-H03 | Card pool v1 | ~120 cards: ~25 per hero set (75) + ~45 neutral | Owner (~120) |
| DD-H04 | Treasure pool v1 | ~20 passive treasures with rarity Common/Rare; some unlock via meta progression | Owner (~20) |
| DD-H05 | Bundles | 36 bundles: 8 per hero (hero cards) + 12 neutral (raised from 6 on 2026-11-03 so neutral bundles cover the non-starter neutral pool, per content review); each bundle has one theme tag used by Reward Draft weighting | default |
| DD-H06 | MVP content cut | War hero only, 5 bosses (3 band 1, 1 band 2, 1 band 3; raised from 4 on 2026-11-03 per cross-review D-06 so MVP runs vary), ~40 cards + 10 boss-only cards, 10 treasures (DD-R05 needs 9 distinct per run; was 8, raised per card-database GDD), 10 bundles | Concept doc |

## Technical constants shared by GDDs

| ID | Decision | Value | Source |
|---|---|---|---|
| DD-T01 | Data format | All definitions are JSON under `assets/data/` (`cards_<set>.json` incl. `cards_boss.json`, `heroes.json`, `hero_powers.json`, `bosses.json`, `treasures.json`, `bundles.json`, `ai_profiles.json`, `match_rules.json`, `run_structure.json`, `heroes_balance.json`, `card_effects.json`, `reward_draft.json`, `treasures_balance.json`, `match_ui.json`, `run_ui.json`, `profile_defaults.json`, `card_database.json`; the player profile itself is saved at `user://profile.json`), snake_case keys, `schema_version` field. Files added 2026-11-03 by the card-database, match-rules and boss-ai GDDs. | Plan |
| DD-T02 | Rules purity | Match and run rules are `RefCounted` GDScript with no Node references; the UI subscribes to events and issues commands | Plan / ADR-0001 |
| DD-T03 | RNG | One seeded service; named streams `run`, `match_<floor>`, `draft_<floor>`, `ai_<floor>` (rng-event-log F2); tests inject fixed seeds | Plan / ADR-0003 |
| DD-T04 | Event log | Append-only list of `{seq, turn, type, payload, cause_seq}` (rng-event-log rule 11; wording updated 2026-11-03); every state mutation emits exactly one event; the UI renders from events | Pillar 4 |
| DD-T05 | Resolution | 1280x720 logical, `canvas_items` stretch, mouse primary, keyboard shortcuts for end turn and cancel | Owner (PC) |

## Cross-GDD decisions taken after the 2026-11-03 design reviews

| ID | Decision | Value | Source |
|---|---|---|---|
| DD-X01 | Unlock field shape | `unlock: {key, condition}` object on HeroDef, TreasureDef and BundleDef (meta-progression M2.1 grammar); `unlock: null` = always unlocked. Card Database CR-3 adopts it; Heroes and Treasures cite it. | designer default |
| DD-X02 | First-run hero | No forced hero. Run UI pre-selects War on a fresh profile; all three launch heroes are unlocked. The concept's "first run forces War" line is withdrawn (autonomy). | designer default |
| DD-X03 | Telegraph setting | `telegraph_mode` (`full` / `brief` / `off`) is a player setting stored by Meta Progression, surfaced by Run UI settings, consumed by Boss AI as `effective_mode = min(boss.intent_mode, setting)`; Match UI only renders what Boss AI emits. | designer default |
| DD-X04 | Event names | Match Rules C15 is the authoritative spelling for match events; RNG & Event Log's catalogue mirrors it; `choice_requested` (Match Rules) and `discover_offered` (Card Effects) are two distinct events. | designer default |
| DD-X05 | Offer naming | `Offer{option_ids[], flags[]}` on events and APIs; `offered_ids[]` only inside the persisted DraftRecord. | designer default |
| DD-X06 | Treasure shortfall policy | `treasure_short_policy = fewer` is the only shipping value; `reoffer` is debug-only and violates DD-R05. | designer default |
| DD-X07 | Player settings owned by Meta Progression | `anim_speed` (`instant`/`fast`/`normal`), `reduce_motion`, `text_scale`, `high_contrast_states`, `telegraph_mode`, `action_delay_ms` (consumed by Match UI pacing), `volume_*`, `fullscreen`, `keep_run_records`. Run UI edits them; Match UI and Boss AI read them. | designer default |
