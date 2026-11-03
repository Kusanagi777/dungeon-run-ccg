# Reward Draft

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Design
> **Author**: Jacob (owner) + `/design-system` (guided, lean)
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 1 (every run builds a deck you couldn't have planned); Pillar 4 (offers reproduce from the seed)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` Specialists `economy-designer`, `systems-designer`, `game-designer`, `qa-lead` not consulted — Lean mode and no `Agent` tool in this session; review Formulas and Acceptance Criteria manually before the first balance pass. Engine feasibility: `Economy` → Scripting domain; no `docs/engine-reference/godot/modules/scripting.md` exists, so feasibility was **not checked against the pinned engine** (the system is pure GDScript logic with no engine surface beyond `RandomNumberGenerator`, which RNG & Event Log already flags).

## Summary

[To be designed]

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `[To be designed]`

## Overview

Reward Draft is the system that turns a won match into deck growth. After every win on floors
1–7 it offers **three authored bundles** (three fixed cards sharing one theme tag, DD-R04) and the
player takes exactly one, all three cards joining the deck; on treasure floors (1, 3, 5 by
default, DD-R05) it first offers **three distinct passive treasures** and the player takes one.
There is no skip and no removal in v1, so the deck grows 15 → 36 over a run (DD-R06) and the
only economy is "what did you add". The system's job is to make that choice plan-shaped rather
than "take the strongest": offers are weighted toward the themes already in the deck, bent by
floor band toward the cost curve the next bosses demand, forced to cover at least two themes, and
backed by a pity rule that brings the player's dominant theme back when the stream has starved
it. Everything is a pure function of the run record and the `draft_<floor>` RNG stream, so a
resume regenerates the identical offer and a shared seed reproduces a run's drafts given the same
picks (DD-R09). Reward Draft reads pools from Card Database, is invoked by Run Structure between
floors (its R5 contract, confirmed here), and is rendered by Run UI; it never touches match state.
Without it the game is a fixed-deck boss gauntlet — Pillar 1 ("the draft is the game") lives here.

## Player Fantasy

`creative-director` not consulted — Lean mode. Framing: **both** — a direct screen the player
operates for ~30 seconds a floor, over an invisible weighting layer whose only job is to make
that screen feel authored.

The feeling is the Dungeon Run moment: the smoke clears, three cards fan out, and the player
says "oh — *that* is what this deck is now". The fantasy is **authorship under constraint**: the
player did not plan a Husk-swarm deck, but the second Husk bundle arrived at the right time and
now they are committed, and the next three picks are judged against *that* plan rather than a
tier list. Pillar 1's design test applies verbatim: when a bundle is "generically good" and
another is "strong only with a plan", the plan one must be the interesting pick, and the
weighting exists to make the plan one *present* often enough for that debate to happen.

Two feelings to protect and one to avoid. Protect **recognition** — the player should notice
their deck's theme coming back ("the game knows I'm on weapons") without ever seeing a weight; the
pity rule is felt as luck, not as a system. Protect **temptation** — the coverage rule guarantees
an off-plan option every draft, so the choice is never a formality; the off-plan bundle is the
one that starts a second plan. Avoid **the solved draft**: if players can rank bundles once and
stop reading, the system has failed (systems-index high-risk row). Treasures are the louder
sibling: one pick that bends a rule for the rest of the run, offered *before* the bundle so the
bundle can answer it (Run Structure R5.2). The anchor moment is floor 3: two bundles in, the
treasure just taken, and the first draft where the deck has an opinion.

## Detailed Design

### Core Rules

`economy-designer` / `systems-designer` / `game-designer` not consulted — Lean mode and no
`Agent` tool in this session. Review manually before production.

Reward Draft is pure logic (`RefCounted`, no Node references, DD-T02). It owns no persistent
state of its own: the run record is the memory, the stream is the randomness. All numeric values
below are read from `assets/data/reward_draft.json` (new file — DD-T01 addition, Open Questions).

**D1 — API (confirms and extends Run Structure R5 / Interactions contract).**

| Call | Called by | Reads | Writes / emits | Draws |
|---|---|---|---|---|
| `init_run(run_state) → draft_state` | Run Structure R2 step 5 (new — contract amendment) | Card Database `treasure_pool()`, Meta Progression unlock state | returns `draft_state` (D3); emits nothing | 0 |
| `offer(kind, run_state, stream) → Offer{option_ids[], flags[]}` | Run Structure R5.3, and again on resume (R8.2) | `run_state` fields `hero_id, floor, deck, treasures, drafts, draft_state`; Card Database | emits `draft_offered`; **mutates nothing** | D6 / D7 |
| `pick(kind, id, offer, run_state) → Pick{picked_id, option_index, card_ids_added[]}` | Run Structure T11/T12 after its own guards | `offer`, Card Database `bundle(id)` | emits `draft_picked`; mutates nothing (the run appends and emits `treasure_granted` / `deck_grew`) | 0 |

`offer` is a **pure function of `(run_state, stream position)`**: no clock, no profile read, no
global RNG (RNG & Event Log rule 7). Run Structure saves S2 *before* calling `offer` (its AC-18
has `draft_<floor>` at `draws = 0` at S2), so the call must be repeatable — which is why it
writes nothing and why the treasure pool is snapshotted in D3 rather than read live.

**D2 — Cadence and order.** Owned by Run Structure R5 and restated for the reader: a bundle
offer after every win on floors `1 .. floors_per_run − 1`; a treasure offer additionally on
floors in `treasure_floors` below `floors_per_run`; on such a floor **treasure first, then
bundle**, and on `draft_<floor>` the treasure draws precede the bundle draws (F4). Confirmed —
the R5.2 contract stands.

**D3 — `draft_state` (confirms Run Structure R1, amends its guess).**

```
draft_state = { "schema_version": 1, "treasure_pool": [ "<treasure_id>", ... ] }   # id-sorted
```

`treasure_pool` is the set of treasures unlocked **at run start** (`TreasureDef.unlock == null`,
or the key reported met by Meta Progression — MVP: all `unlock == null`). Nothing else is stored:
exclusion history and pity history are **derived from `run_state.drafts[]`** (R1 `DraftRecord
{floor, kind, offered_ids[], picked_id, card_ids_added[]}`) at every call. Rationale: a counter
that can drift from the record is a resume bug waiting to happen, and the record already holds
every offered id. Run Structure R1 described `draft_state` as "pity counters and
`offered_treasure_ids[]`" — superseded by this schema (flag for `/consistency-check`).

**D4 — Bundle candidates on floor `f`.**

```
pool    = bundle_pool(hero(hero_id).set)                       # Card Database CR-6, id-sorted
taken   = { d.picked_id : d ∈ drafts, d.kind == bundle }
cooling = { b : d ∈ drafts, d.kind == bundle, b ∈ d.offered_ids, b ≠ d.picked_id,
            f − d.floor ≤ reoffer_after_floors }               # default 2
cands   = pool − taken − cooling                                # order preserved
```

A taken bundle is never re-offered (its cards are already in the deck). A bundle offered but
not taken is excluded for `reoffer_after_floors` floors and then eligible again; F5 shows this
window is what keeps a 14-bundle v1 pool solvent across seven drafts.

**D5 — Bundle weights.** Each candidate gets the integer weight of F1: base × theme affinity
with the current deck × floor-band cost curve. Weights are ≥ 1 by construction, so
`weighted_pick` (RNG & Event Log F4) never sees a zero total.

**D6 — Bundle offer algorithm.** Three slots, each one `weighted_pick` over the current
candidate list = **one draw each**, in this order:

1. Compute the dominant theme `D` and whether pity is due (F3). If due and some candidate has
   `theme == D`: slot 1 = `weighted_pick` over `{c ∈ cands : theme == D}`; flag `pity_forced`.
   Otherwise slot 1 = `weighted_pick(cands)`.
2. Remove slot 1 from `cands`; slot 2 = `weighted_pick(cands)`.
3. Remove slot 2. **Coverage**: if `theme(slot1) == theme(slot2)` and some candidate has a
   different theme, slot 3 = `weighted_pick` over `{c : theme ≠ theme(slot1)}`; flag
   `coverage_forced`. Otherwise slot 3 = `weighted_pick(cands)`.
4. `option_ids` = the three ids **sorted ascending by id**. Display order therefore carries no
   information about which slot was forced; a player cannot learn "slot 1 is the pity slot".
5. Fewer than three candidates at any step → D8 before step 1 runs.

**D7 — Treasure candidates and offer algorithm.**

```
pool  = draft_state.treasure_pool
seen  = treasures ∪ { t : d ∈ drafts, d.kind == treasure, t ∈ d.offered_ids }
cands = pool − seen                                             # DD-R05: no duplicate offers
```

Three slots, one draw each. Slot 1: if `universal_slot` is on and some candidate is universal
(F2: `tags == []`), `weighted_pick` over the universal candidates, flag `universal_forced`; else
over all. Slots 2 and 3: `weighted_pick` over the remainder. Weights are F2. `option_ids` sorted
ascending by id. Fewer than three candidates → D8.

**D8 — Short pools.** Applied before the slot loop; every fallback is visible in `flags[]` and
in a `run_warning` (Run Structure R10 catalogue).

| Kind | Condition | Resolution |
|---|---|---|
| bundle | `|cands| < 3` | (a) drop `cooling` — every offered-not-taken bundle is eligible again; flag `reoffer`. (b) Still `< 3`: offer all `|cands|` (1–2) with flag `short` and `run_warning{bundle_pool_short, floor, needed: 3, available}`. (c) `|cands| == 0`: return `option_ids = []`; the run must skip the bundle step for this floor (`floor += 1`, no `deck_grew`, a `DraftRecord` with `picked_id = null`) — **contract amendment for run-structure.md**, Open Questions. Card Database refuses a pool below 3 (`E_COUNT`), so (c) needs 3 bundles and ≥ 4 drafts. |
| treasure | `|cands| < 3` | per `treasure_short_policy`: `fewer` (default) — offer `|cands|` (1–2), flag `short`, `run_warning{treasure_pool_short, floor, needed: 3, available}`; `reoffer` — refill the missing slots from `{offered-not-held}`, flag `reoffer`. `|cands| == 0` under either policy: return `[]`; the run skips to the bundle step (same amendment). A held treasure is **never** offered again under any policy. |

**D9 — Pick resolution.** Run Structure guards `kind == reward_step`, `id ∈ option_ids`, and
"not already drafted this floor" (`E_DRAFT_KIND`, `E_NOT_OFFERED`, `E_DRAFT_DONE`) and then calls
`pick`. For a bundle, `card_ids_added = bundle(id).cards` in data order (exactly
`bundle_card_count` = 3); for a treasure, `card_ids_added = []`. `option_index` is the index of
`id` in the sorted `option_ids`. `pick` emits `draft_picked` and returns; the run appends to
`deck` / `treasures`, records the `DraftRecord`, and emits `deck_grew` / `treasure_granted`
(R5.4–5). **No skip in v1**: `allow_skip` defaults to `false`, because Pillar 1 wants the deck to
move every floor and DD-R06's growth invariant (`len(deck) == 15 + 3 × n_bundle_picks`) is what
Run Structure validates on resume. When `allow_skip` is `true`, `pick(kind, null, …)` is legal,
records `picked_id = null`, adds nothing, and the invariant still holds because it counts
non-null bundle picks; the UI shows a "Take nothing" control only then.

**D10 — Economy framing** (`.claude/docs/templates/economy-model.md` shape; no currency).

| Flow | Resource | Amount | Frequency | Conditions |
|---|---|---|---|---|
| Faucet | cards | 3 | per bundle draft (floors 1–7) → 21 per full run, 9 at MVP | always (no skip) |
| Faucet | treasures | 1 | per treasure floor → 3 per full run, 2 at MVP | floor ∈ `treasure_floors` |
| Sink | — | — | — | **none in v1**: no removal, no transform, no upgrade |

With no sink the deck only dilutes (F8). The affinity and pity rules are the *substitute* for a
sink: they keep the inflow on-theme so dilution reads as "my plan got deeper" rather than "my
starter got buried". v2 sink candidates (Open Questions): remove one card at a treasure floor;
"forge" a bundle into one copy of its best card.

**D11 — Events owned here** (extends the RNG & Event Log catalogue; payloads JSON-only, rule 14).

| Type | Payload | When |
|---|---|---|
| `draft_offered` | `floor, kind (bundle \| treasure), option_ids[], flags[]` | every `offer` call, including the regeneration after a resume (the log records that the offer was shown again; `/balance-check` dedupes offers by `(floor, kind)`) |
| `draft_picked` | `floor, kind, picked_id, option_index, card_ids_added[]` | every accepted `pick` |

`flags[]` ⊆ `{pity_forced, coverage_forced, universal_forced, universal_missing, reoffer, short}`
(`universal_missing`: the universal slot was wanted but no universal candidate remained). The catalogue
lists `treasure_granted` under Reward Draft; the mutation it marks is the run's append, so the
owner is **Run Structure** (agreeing with its Open Question) — flag for `/consistency-check`.
`run_warning` codes introduced: `bundle_pool_short`, `treasure_pool_short`,
`draft_state_init_late`, `bundle_invalid`.

**D12 — Determinism.** Same `(run_state, stream position)` ⇒ same `option_ids` and `flags`.
The stream is advanced only inside `offer`, by exactly the draws F4 counts, in the fixed order
treasure-then-bundle. A resume at S2 or S3 restores the stream to the position the save
recorded and regenerates the same offer (Run Structure AC-18). Under a custom seed, two runs with
identical picks see identical offers on every floor; the first divergent pick changes the deck,
hence the weights and the pity history, hence later offers — exactly the DD-R09 limit.

### States and Transitions

A draft is a per-`(floor, kind)` value, not a long-lived object; its state is readable from
`run_state.reward_step` and `drafts[]`.

| State | Entry Condition | Exit Condition | Behavior |
|---|---|---|---|
| `Idle` | No pending reward (run in `pre_match` / `in_match`) | Run enters `post_match_reward` | Nothing to show; `offer` is not called |
| `Offered(kind)` | `offer` returned `option_ids` with `len ≥ 1` | `pick` accepted, or `abandon` | `draft_offered` emitted; the offer is held in memory by the run; a quit here loses nothing (regenerated on resume) |
| `Short(kind)` | `offer` returned `1 ≤ len < 3` | as `Offered` | Same as `Offered`; `flags` contains `short` (or `reoffer`); UI shows the empty slots as "no more treasures/bundles in this run" |
| `Empty(kind)` | `offer` returned `[]` | Run skips the step (D8 c) | `DraftRecord{picked_id: null}` recorded by the run; next step or next floor |
| `Resolved(kind)` | `pick` accepted | Immediately — the run moves to the next step (`bundle`) or floor | `draft_picked` then the run's `treasure_granted` / `deck_grew`; a second `pick` for the same `(floor, kind)` is `E_DRAFT_DONE` |

Transitions: `Idle → Offered | Short | Empty` (on `offer`); `Offered | Short → Resolved` (on
`pick`); `Empty → Idle`; `Resolved → Idle` (bundle) or `Resolved → Offered(bundle)` (treasure,
via a second `offer`). `abandon` from `Offered`/`Short` ends the run (Run Structure T13) with
no draft event.

### Interactions with Other Systems

| System | Direction | Data in (to Reward Draft) | Data out (from Reward Draft) | Interface owner |
|---|---|---|---|---|
| **Run Structure** | upstream (invokes) / downstream (records) | `init_run`, `offer`, `pick` calls; `run_state` read access (`hero_id, floor, deck, treasures, drafts, draft_state, treasure_floors`); the `draft_<floor>` stream | `draft_state` (once), `Offer`, `Pick`; the two events; `run_warning` codes | Run Structure R5 contract confirmed; amendments: `init_run` hook, empty-offer skip, `draft_state` schema (D3) |
| **Card Database** | upstream | `bundle_pool(set)`, `treasure_pool()`, `bundle(id)`, `card(id).tags / cost`, `hero(id).set` — all id-sorted (CR-6) | — | Card Database owns shapes and validation (CR-5 stage 6 guarantees 3 non-token cards per bundle sharing `theme`); this GDD owns weighting |
| **Treasures** | upstream (data) | `TreasureDef.rarity`, `TreasureDef.tags` (**contract**, below), `unlock` | the picked treasure id reaches Treasures only through `run_state.treasures[]` at the next `begin_match` (R5.6) | Treasures owns effects and the hook chain; this GDD owns offer weights and the no-duplicate rule |
| **RNG & Event Log** | upstream | `stream("draft_<floor>")` with `weighted_pick`; the run log | `draft_offered`, `draft_picked`; exact draw counts (F4) | RNG & Event Log owns primitives and the envelope |
| **Heroes** | upstream (data) | `HeroDef.set` → pool choice; H-5 theme tags = `plan_tags(hero)` (the F3 candidate set) | — | Heroes owns which tags exist per set; this GDD owns how they weight |
| **Meta Progression** | upstream (at `init_run` only) | `is_treasure_unlocked(id) → bool` (**contract — to be confirmed in meta-progression.md**; MVP: `unlock == null`) | pick rates via archived logs | Meta owns unlock state; this GDD never reads it after run start |
| **Run UI** | downstream | `draft_pick` command (through the run) | `Offer` read model: ids, `flags`, per-option synergy counts (UI Requirements) | UI is display-only (`src/ui/**`) |
| **Content** | soft | bundle and treasure authoring against DD-H05/H04; F5/F6 pool-size floors | `run_warning{*_pool_short}` when content is thin | Content authors; this GDD degrades gracefully |

**Treasures contract — to be confirmed in treasures.md.** Reward Draft needs, per treasure:
`id`, `rarity ∈ {common, rare}` (DD-H04), `unlock` (Card Database CR-3), and **`tags: string[]`**
(`^[a-z_]+$`, drawn from the H-5 theme-tag vocabulary; `[]` means *universal*). `tags` is not in
Card Database CR-3's `TreasureDef` today — flagged for that GDD's Open Questions; until it exists
every treasure is treated as universal and F2's affinity term is inert. Rules Treasures must
honour: no treasure is offered twice in a run (held or offered-not-taken, DD-R05); the pool is
snapshotted at run start; Content keeps `n_universal ≥ treasure_drafts_per_run` (3) so the
universal slot is satisfiable in every draft, and `n_unlocked_default ≥ min_treasure_pool` (9).

## Formulas

`systems-designer` / `economy-designer` not consulted — Lean mode and no `Agent` tool in this
session (Section D is HIGH-risk per the skill); the defaults below are designer defaults for the
first balance pass, to be re-fitted from `draft_picked` logs with `/balance-check`. All weights
are integers because RNG & Event Log F4's `weighted_pick` takes `Array[int]`; percentages are
stored as integers in `reward_draft.json`.

### F1. Bundle weight

The `bundle_weight` formula is defined as:

`bundle_weight(b) = max(1, round(BASE_WEIGHT × affinity(b) × band_mult(band(f), cost_bucket(b)) / 100))`

with `affinity(b) = 1 + AFFINITY_STEP × min(n_tag(theme(b)), AFFINITY_CAP)`,
`n_tag(t) = |{c ∈ deck : t ∈ tags(c)}|`, and `cost_bucket(b)` from `avg_cost(b) = Σ cost(cards(b)) / 3`.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| BASE_WEIGHT | int | 10–1000 (default 100) | data file | Weight of an off-theme, mid-cost bundle |
| AFFINITY_STEP | float | 0–1 (default 0.25; stored as 25) | data file | Boost per deck card sharing the bundle's theme |
| AFFINITY_CAP | int | 1–20 (default 8) | data file | Cards counted at most; bounds `affinity` at 3.0 |
| n_tag(t) | int | 0–36 | calculated | Deck cards carrying tag `t` (a card counts once per tag it carries) |
| band(f) | int | 1–3 | Run Structure F1 `floor_band` | Band of the floor being drafted on |
| avg_cost(b) | float | 0–10 | calculated from Card Database `cost` | Mean mana cost of the bundle's three cards |
| cost_bucket(b) | enum | `low < 2.5 ≤ mid ≤ 4.0 < high` | data file thresholds `COST_LOW`, `COST_HIGH` | Cost class of the bundle |
| band_mult | int (%) | 50–200 | data file table `band_cost_curve[band][bucket]` | Defaults: band 1 = low 120 / mid 100 / high 70; band 2 = 100 / 110 / 100; band 3 = 80 / 100 / 130 |

**Output Range:** 1 to 390 per bundle at defaults (`100 × 3.0 × 1.30`); off-theme mid-cost = 100.
A 50-candidate pool totals under 20,000, far below F4's `2^31 − 1` cap.
**Example (War, floor 1, starter deck):** the starter carries `weapons` × 3 (Sharpen, Rusted Axe,
Quartermaster), `aggro` × 2 (Warcry, Pit Brawler), `armour` × 1 (Shield Squire). Candidates:
`bundle_war_aggro` (avg 2.0, low) = 100 × 1.50 × 1.20 = **180**; `bundle_war_weapons` (avg 2.67,
mid) = 100 × 1.75 × 1.00 = **175**; `bundle_war_armour` (avg 3.33, mid) = **125**;
`bundle_neutral_taunt` (avg 3.0, mid, no shared tag) = **100**; `bundle_neutral_giants` (avg 5.33,
high) = 100 × 1.0 × 0.70 = **70**. Total 650 → slot-1 odds 27.7 / 26.9 / 19.2 / 15.4 / 10.8 %.
On floor 7 (band 3) with nine `weapons` cards in the deck: weapons bundle = 100 × 3.0 × 1.0 =
300, giants = 130 — on-plan still leads, but the late high-cost neutral now beats any off-plan mid.

### F2. Treasure weight

The `treasure_weight` formula is defined as:

`treasure_weight(t) = round(RARITY_W[rarity(t)] × (100 + TREASURE_AFFINITY × affine(t)) / 100)`

with `affine(t) = 1` if `tags(t) ∩ plan_tags(hero) ≠ ∅` else `0`; `universal(t) ⇔ tags(t) == []`.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| RARITY_W | int | 1–100 each (default common 70, rare 30) | data file `treasure_rarity_weights` | Per-item weight by rarity (DD-H04 two tiers) |
| TREASURE_AFFINITY | int (%) | 0–200 (default 50) | data file | Boost for a treasure tagged with one of the hero's plan tags |
| plan_tags(hero) | string[] | 3–4 | Heroes H-5 (data) | The hero set's theme tags |
| tags(t) | string[] | 0–4 | Treasures contract (`TreasureDef.tags`) | `[]` = universal |

**Output Range:** 30 (plain rare) · 45 (affine rare) · 70 (plain common) · 105 (affine common).
With a 60/40 common/rare pool, rares are ≈ 22 % of offered slots (0.4 × 30 ÷ (0.6 × 70 + 0.4 × 30)).
**Example (MVP pool of 10 for War: 7 universal — 4 common, 3 rare; 3 tagged `weapons` — 2 common,
1 rare):** slot 1 over the 7 universal: total 370, P(rare) = 90/370 = 24 %. If slot 1 took a
plain common, slots 2–3 draw over 9 with total 2 × 105 + 3 × 70 + 45 + 3 × 30 = 555; P(an affine
treasure in slot 2) = 255/555 = 46 %, so most offers show at least one on-plan treasure beside
the guaranteed universal one.

### F3. Dominant theme and pity

```
D          = argmax_{t ∈ plan_tags(hero)} n_tag(t)          # ties → earliest in plan_tags order
starve     = count of most-recent consecutive bundle drafts (by floor) whose offered_ids
             contain no bundle with theme == D
pity_due   = starve ≥ PITY_WINDOW
```

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| D | string | one of `plan_tags(hero)` | calculated per draft | The deck's dominant plan theme *now* (a pivot changes it) |
| starve | int | 0–7 | calculated from `drafts[]` | Drafts since `D` was last *offered* — declining it resets the count; the player had the chance |
| PITY_WINDOW | int | 1–4 (default 2) | data file | Starved drafts that force a `D` bundle into slot 1 |

**Output Range:** `pity_due` is boolean; it is never true on floors 1–2 (fewer than 2 prior
drafts) and fires at most every `PITY_WINDOW + 1` floors. Pity is deterministic — **no draw** —
so RNG & Event Log's "pity rolls" wording reduces to "pity restricts the slot-1 candidate list".
**Example:** War starter, `D = weapons` (3 vs 2 vs 1). Floors 1 and 2 offer no `weapons` bundle
→ `starve = 2` on floor 3 → slot 1 is drawn among weapons bundles, flag `pity_forced`. Had the
player taken two `aggro` bundles meanwhile (`aggro` 8 vs `weapons` 3), `D` is `aggro` on floor 3
and its own starve count applies.

### F4. Draws per floor on `draft_<floor>`

`draws(f) = [f ∈ treasure_floors] × min(3, |cands_T(f)|) + min(3, |cands_B(f)|)`

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| cands_T, cands_B | sets | 0–100 | D7, D4 (after D8) | Eligible treasures / bundles on floor f |
| treasure_floors | int[] | ⊆ 1..F−1 | Run Structure (registry `treasure_floors`) | Floors with a treasure draft |

**Output Range:** 3 or 6 per floor; 30 per full 8-floor run (3 × 6 + 4 × 3), 15 at MVP (2 × 6 +
3). Treasure draws occupy positions 0–2 and bundle draws 3–5 on a treasure floor, so a save at
S3 restores `draft_<floor>` to `draws = 3` and the bundle offer regenerates identically.

### F5. Bundle pool sufficiency (never short before the last draft)

`B_min(F, W) = 3 + (F − 2) + 2 × min(F − 2, W)`  — because on the last drafting floor `f = F − 1`
there are `f − 1` taken bundles and at most `2 × min(f − 1, W)` cooling ones.

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| B | int | ≥ 3 | Card Database `bundle_pool_size` | Hero-set + neutral bundles |
| F | int | 3–12 | registry `floors_per_run` | Floors per run |
| W | int | 0–7 | data file `reoffer_after_floors` | Cooling window for declined bundles |

**Output Range:** v1 (`F = 8`): `W = 1 → 11`, `W = 2 → 13`, `W = 3 → 15`, never re-offer → 21.
DD-H05's 14 bundles therefore require `W ≤ 2` — the default. MVP (`F = 4`): `B_min = 9` for any
`W ≥ 2`; DD-H06's 10 bundles leave one spare. **Example (v1, W = 2):** eligible per floor 14, 11,
8, 7, 6, 5, 4 — never below 3; with no re-offer it would be 14, 11, 8, 5, 2 (short on floor 5).

### F6. Treasure pool sufficiency

`remaining_before_draft_k = N − 3 × (k − 1)`; need `≥ 3` for `k = K` ⇒ `N ≥ 3K` (= Card Database
`min_treasure_pool`, 9 at `K = 3`). Universal slot guaranteed for every draft iff `n_universal ≥
3K − 2` (7 at `K = 3`); recommended `n_universal ≥ 5` with the slot best-effort (flag
`universal_missing` when unmet).

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| N | int | 0–100 | `draft_state.treasure_pool` size | Unlocked treasures at run start |
| K | int | 0–7 | `|treasure_floors ∩ [1, F − 1]|` | Treasure drafts in this run |
| n_universal | int | 0–N | Treasures data | Treasures with `tags == []` |

**Output Range / Example (DD-H06 arithmetic):** `N = 10, K = 3` → 10, 7, 4 before drafts 1–3: all
≥ 3, one spare. `N = 8` (the concept's MVP line) → 8, 5, **2**: draft 3 is short and D8 offers
two. MVP's 4-floor run has `K = 2` → 10, 7: four spare, so the raise to 10 matters only for the
8-floor Vertical Slice.

### F7. Theme coherence

```
plan_share(f)    = |{c ∈ deck_f : tags(c) ∩ plan_tags(hero) ≠ ∅}| / deck_size(f)
top_tag_share(f) = max_t n_tag(t) / deck_size(f)
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| deck_size(f) | int | 15–36 | Run Structure F4 (registry) | `15 + 3 × (f − 1)` |
| plan_tags(hero) | string[] | 3–4 | Heroes H-5 | Same set Heroes F2 scores the starter with (6/15 = 0.40) |
| k | int | 0–7 | from `drafts[]` | Hero-set bundles taken (each adds 3 plan cards; neutral bundles add 0) |

**Output Range:** `plan_share(8) = (6 + 3k) / 36`: k = 0 → 0.17, 3 → 0.42, 4 → 0.50, 5 → 0.58,
7 → 0.75. **Targets:** median player `plan_share(8) ≥ 0.45` (≥ 4 hero bundles of 7 — a uniform
random picker already lands near 0.50 because 8 of 14 bundles are hero-set; affinity pushes
above it), and `top_tag_share(8) ≥ 0.30` (three bundles per tag at DD-H05 give 3 + 9 = 12/36 =
0.33 from bundles alone). The brief's "top theme ≥ 45 %" is unreachable from a single tag with
~3 bundles per tag, so 45 % is set on `plan_share` — Open Questions. Measured by `/balance-check`
from the final `deck` in archived run records.

### F8. Starter dilution

```
p_starter(f)        = starter_deck_size / deck_size(f)
E_starter_seen(f,n) = n × p_starter(f)                              # first n cards seen
P_no_starter_hand(f) = C(deck_size(f) − 15, 3) / C(deck_size(f), 3)   # opening hand of 3
P_card_seen(f, n)   = n / deck_size(f)                               # one specific card in first n
```

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| starter_deck_size | int | 15 | registry (Card Database) | Starter cards, never removed in v1 |
| n | int | 3–20 | analysis (default 10 = hand 3 + 7 draws) | Cards seen by turn 7 |

**Output Range (floors 1 / 4 / 8, deck 15 / 24 / 36):** `p_starter` 1.00 / 0.63 / 0.42;
`E_starter_seen(·, 10)` 10 / 6.3 / 4.2; `P_no_starter_hand` 0 / 0.04 / 0.19; `P_card_seen(·, 10)`
0.67 / 0.42 / 0.28. **Reading:** by floor 8 a given starter card shows up in the first ten cards
of fewer than three matches in ten — the plan can no longer be carried by the starter. Expected
*plan* cards in the first ten = `10 × plan_share`: 4.0 at floor 1 (0.40), 4.5 at floor 8 if F7's
0.45 holds. The affinity + pity rules therefore exist to keep plan density flat-to-rising under
dilution, which is the design claim `/balance-check` tests.

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

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
