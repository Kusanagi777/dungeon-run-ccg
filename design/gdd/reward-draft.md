# Reward Draft

> Authoring guidance: .claude/docs/templates/guidance/game-design-document-guide.md (load per-section as you author — do not read entirely).

> **Status**: In Review
> **Author**: Jacob (owner) + `/design-system` (guided, lean)
> **REVISED 2026-11-03** (`/design-review`, lean, first review — NEEDS REVISION, blockers fixed in place): (1) treasure `tags` semantics aligned to Treasures T1/T8 and the registry — *universal* is the `universal` affinity tag, not an empty list, `affine` also matches the hero's own affinity tag, `tags` is 1–4 long; (2) the two names for the offer list are now stated as a rule in D11 — `option_ids[]` on `Offer` / `draft_offered` (as Run UI U8 and the RNG & Event Log catalogue use it), `offered_ids[]` only as the `DraftRecord` field Run Structure persists; Run Structure R5.3's `→ offered_ids[]` is flagged; (3) the Meta Progression call is `unlocked_ids("treasure")` at `init_run` (was the non-existent `is_treasure_unlocked(id)`); plus: per-item (not per-slot) rarity weighting stated explicitly against Treasures T6, Treasures' `pool()` declared unused, `theme_labels` declared not emitted, T10 labelled a synthetic fixture, AC-9 pick policies named, a cooling-count arithmetic slip in Edge Cases, stale *(planned)* cross-references and the systems-index note, and five Open Questions rows. Status set to In Review pending re-review.
> **REVISED 2026-11-03 (cross-review)**: C-10 (Meta Progression call is `unlocked_keys()` per M1.3, read once at `init_run`; membership `unlock == null ∨ unlock.key ∈ unlocked_keys()` — D3, Interactions, Dependencies, Cross-References; the earlier `unlocked_ids("treasure")` is superseded), C-13 (`treasure_short_policy = reoffer` is debug-only and rejected by the release config validator, DD-X06 — D8, Edge Cases, Tuning Knobs, AC-11), C-28 (stale Card Database "requests" removed — CR-3 has `TreasureDef.tags`, DD-T01 lists `reward_draft.json`; one universal-floor rule everywhere: hard floor 3, recommended 7 = 3K − 2), C-30 (Open Questions housekeeping: Run Structure amendments, offer naming, `treasure_granted` owner, Run UI row — D1, D11), DD-H05 (36 bundles = 8 per hero + 12 neutral, so B = 20 per hero: D4, F5 incl. the `bundle_pool_min` range 4–27, F7 uniform-picker baseline 0.50 → 0.40, Dependencies, Tuning Knobs, Edge Cases, new fixture P20 in AC-29), D-02 (`AFFINITY_CAP` 8 → 6 so an on-plan bundle tops out at 2.5× not 3.0× — F1 range and floor-7 example, AC-20, Tuning Knobs; `/balance-check` reports the "only off-plan option is the coverage slot" share, Open Questions).
> **REVISED 2026-11-03 (re-review)**: Heroes H-4 / F2 (cross-review C-03, option B) now count the War starter at **7** plan cards — `war_iron_vanguard` carries Content's `armour` tag beside `war_shield_squire` — where this GDD's worked examples still used 6 (`armour` × 1). Re-derived: F1 floor-1 example (`bundle_war_armour` 150, total 675, slot-1 odds 26.7 / 25.9 / 22.2 / 14.8 / 10.4 %), AC-20, F3 example (`3 vs 2 vs 2`), F7 (`plan_share(8) = (7 + 3k)/36`, uniform-picker baseline 0.43), F8 (4.7 plan cards in the first ten at floor 1), AC-29, Tuning Knobs `AFFINITY_STEP`, Cross-References. Housekeeping: the systems-index design-order note (item 4 now lists all six dependencies), the concept's treasure-cadence Open Question (resolved — concept cites DD-R05), a new Open Questions row answering Content's "does pity need ≥ 2 bundles per tag" question. No rule, knob or contract changed.
> **Last Updated**: 2026-11-03
> **Last Verified**: 2026-11-03
> **Implements Pillar**: Pillar 1 (every run builds a deck you couldn't have planned); Pillar 4 (offers reproduce from the seed)
> **Review notes**: `CD-GDD-ALIGN skipped — Lean mode.` Specialists `economy-designer`, `systems-designer`, `game-designer`, `qa-lead` not consulted — Lean mode and no `Agent` tool in this session; review Formulas and Acceptance Criteria manually before the first balance pass. Engine feasibility: `Economy` → Scripting domain; no `docs/engine-reference/godot/modules/scripting.md` exists, so feasibility was **not checked against the pinned engine** (the system is pure GDScript logic with no engine surface beyond `RandomNumberGenerator`, which RNG & Event Log already flags).

## Summary

Reward Draft is the between-floors pick: after every win it offers three themed three-card
bundles (and, on floors 1, 3 and 5, three passive treasures first) and the player takes exactly
one, so the deck grows by three cards a floor and the run gains three rule-bending treasures.
Offers are weighted toward the themes already in the deck and the cost curve the next band
wants, always cover two themes, and a pity rule brings a starved plan back — so the draft is a
plan the player discovers rather than a tier list. Every offer is a pure function of the run
record and the seeded `draft_<floor>` stream, so resumes and shared seeds reproduce it exactly.

> **Quick reference** — Layer: `Feature` · Priority: `MVP` · Key deps: `Run Structure, Card Database, RNG & Event Log, Treasures (contract), Heroes (data), Meta Progression (contract)`

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
| `init_run(run_state) → draft_state` | Run Structure R2.5 (contract confirmed — cross-review S-01) | Card Database `treasure_pool()`, Meta Progression `unlocked_keys()` (M1.3) | returns `draft_state` (D3); emits nothing | 0 |
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
or `unlock.key ∈ MetaProgression.unlocked_keys()` — meta-progression M1.3, read once inside
`init_run`, the Treasures T6 predicate; `unlock` is the `{key, condition}` object of DD-X01 — MVP:
every MVP treasure has `unlock: null`, Treasures T8). Nothing else is stored:
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
window is what keeps a v1 per-hero pool of 20 bundles (DD-H05: 8 hero-set + 12 neutral) solvent
across seven drafts with room to spare.

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
(F2: `"universal" ∈ tags(t)`), `weighted_pick` over the universal candidates, flag `universal_forced`; else
over all. Slots 2 and 3: `weighted_pick` over the remainder. Weights are F2. `option_ids` sorted
ascending by id. Fewer than three candidates → D8.

**D8 — Short pools.** Applied before the slot loop; every fallback is visible in `flags[]` and
in a `run_warning` (Run Structure R10 catalogue).

| Kind | Condition | Resolution |
|---|---|---|
| bundle | `len(cands) < 3` | (a) drop `cooling` — every offered-not-taken bundle is eligible again; flag `reoffer`. (b) Still `< 3`: offer all `len(cands)` (1–2) with flag `short` and `run_warning{bundle_pool_short, floor, needed: 3, available}`. (c) `len(cands) == 0`: return `option_ids = []`; the run must skip the bundle step for this floor (`floor += 1`, no `deck_grew`, a `DraftRecord` with `picked_id = null`) — **contract amendment for run-structure.md**, Open Questions. Card Database refuses a pool below 3 (`E_COUNT`), so (c) needs 3 bundles and ≥ 4 drafts. |
| treasure | `len(cands) < 3` | per `treasure_short_policy`: `fewer` (default) — offer `len(cands)` (1–2), flag `short`, `run_warning{treasure_pool_short, floor, needed: 3, available}`; `reoffer` — refill the missing slots from the offered-not-held set, flag `reoffer`. `reoffer` is a debug fixture value and is rejected by the config validator in release builds (`E_CONFIG`); `fewer` is the only shipping value (DD-X06 — `reoffer` violates DD-R05's no-repeat rule). `len(cands) == 0` under either policy: return `[]`; the run skips to the bundle step (same amendment). A held treasure is **never** offered again under any policy. |

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
(`universal_missing`: the universal slot was wanted but no universal candidate remained).
`len(option_ids)` is 3 normally and 1–2 only under D8 (an empty offer is never emitted — the run
skips the step, D8 c); Run UI U8 builds `len(option_ids)` options with placeholders for `short`
(its Dependencies row reads 1–3 with `flags` — cross-review V-50). No `theme_labels[]` field is
emitted: Run UI resolves `bundle(id).theme` / `text` and `treasure(id)` through Card Database
from the ids, and the synergy hint reads the `Offer` read model's per-option numbers (UI
Requirements), not a `synergy_tags` field. **Naming rule:** the list is `option_ids[]` on `Offer`
and in `draft_offered` / `draft_picked.option_index` (Run UI U8, RNG & Event Log catalogue);
`offered_ids[]` is the **`DraftRecord` field** in which Run Structure persists the same list after
the pick (R1). Run Structure R5.3 reads `Offer{option_ids[], flags[]}` (DD-X05; cross-review
V-47). `treasure_granted` is owned by **Run Structure** (its R5.4; the RNG & Event Log catalogue
lists it there — cross-review V-19): the mutation it marks is the run's append.
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
| **Meta Progression** | upstream (at `init_run` only) | `unlocked_keys() → Set[string]` (meta-progression M1.3) read once at `init_run`; a treasure is in the pool iff `unlock == null` or `unlock.key ∈ unlocked_keys()` (treasures T6 predicate); Meta confirms `init_run` timing (its Interactions and Dependencies rows); MVP: everything unlocked | pick rates via archived logs | Meta owns unlock state; this GDD never reads it after run start. No bundle key is checked in v1 (every v1 `BundleDef.unlock` is `null`, DD-X01) |
| **Run UI** | downstream | `draft_pick` command (through the run) | `Offer` read model: ids, `flags`, per-option synergy counts (UI Requirements) | UI is display-only (`src/ui/**`) |
| **Content** | soft | bundle and treasure authoring against DD-H05/H04; F5/F6 pool-size floors | `run_warning{*_pool_short}` when content is thin | Content authors; this GDD degrades gracefully |

**Treasures contract — confirmed against treasures.md T1/T6/T8.** Reward Draft needs, per
treasure: `id`, `rarity ∈ {common, rare}` (DD-H04), `unlock` (Card Database CR-3), and
**`tags: string[]`** as Treasures T1 defines it: **exactly one affinity tag** from
`war | decay | knowledge | universal` plus 0–3 plan tags (Heroes H-5) and/or archetype tags
(`economy, tempo, value, defensive, wild`), so `len(tags) ∈ 1..4`. *Universal* means the affinity
tag is `universal` — never an empty list (T8 has no empty `tags`; e.g. Iron Constitution is
`[universal, defensive, armour]`). `tags` is defined by Treasures (T1) and stored and validated
by Card Database CR-3 `TreasureDef.tags` (CR-5 rejects an empty list). Treasures T6
(restated 2026-11-03 against this GDD) agrees on the rest: the pool is snapshotted once at
`init_run` (D3), the exclusion set is derived from `drafts[]` (D7), and weights are **per item**
(F2: each common weighs 70, each rare 30 — not a per-slot 70/30 rarity roll), so the rare share of
offered slots depends on the pool mix (≈ 26 % at T8's 11 C / 9 R before affinity, ≈ 22 % at
60/40) and Treasures' F4 odds are approximations until re-fitted (Open Questions). T6 offers the
membership predicate as `Treasures.pool(is_unlocked, exclude_ids)`; whether `init_run`/D7 call it
or apply the same predicate over Card Database `treasure_pool()` directly is an architecture
choice (`/create-architecture`) — the predicate, not the call site, is the contract. Rules
Treasures must honour: no treasure is offered twice in a run (held or offered-not-taken, DD-R05);
the pool is snapshotted at run start; Content keeps `n_universal` at the F6 floor — **hard floor
3** (one per draft, `K = 3`), **recommended 7** (`= 3K − 2`, the universal slot guaranteed in every
draft; T8: 10 universal at v1, 7 at MVP) — and `n_unlocked_default ≥ min_treasure_pool` (9; T8:
16 / 10).

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
| AFFINITY_CAP | int | 1–20 (default 6; was 8 — cross-review D-02) | data file | Cards counted at most; bounds `affinity` at 2.5 (at 8 it was 3.0 and late drafts read as rails) |
| n_tag(t) | int | 0–36 | calculated | Deck cards carrying tag `t` (a card counts once per tag it carries) |
| band(f) | int | 1–3 | Run Structure F1 `floor_band` | Band of the floor being drafted on |
| avg_cost(b) | float | 0–10 | calculated from Card Database `cost` | Mean mana cost of the bundle's three cards |
| cost_bucket(b) | enum | `low < 2.5 ≤ mid ≤ 4.0 < high` | data file thresholds `COST_LOW`, `COST_HIGH` | Cost class of the bundle |
| band_mult | int (%) | 50–200 | data file table `band_cost_curve[band][bucket]` | Defaults: band 1 = low 120 / mid 100 / high 70; band 2 = 100 / 110 / 100; band 3 = 80 / 100 / 130 |

**Output Range:** 1 to 325 per bundle at defaults (`100 × 2.5 × 1.30`); off-theme mid-cost = 100.
A 50-candidate pool totals under 20,000, far below F4's `2^31 − 1` cap.
**Example (War, floor 1, starter deck):** the starter carries `weapons` × 3 (Sharpen, Rusted Axe,
Quartermaster), `aggro` × 2 (Warcry, Pit Brawler), `armour` × 2 (Shield Squire, and Iron
Vanguard — the non-★ Taunt that carries Content's `armour` tag, Heroes H-4 / F2: 7 plan cards of
15). Candidates:
`bundle_war_aggro` (avg 2.0, low) = 100 × 1.50 × 1.20 = **180**; `bundle_war_weapons` (avg 2.67,
mid) = 100 × 1.75 × 1.00 = **175**; `bundle_war_armour` (avg 3.33, mid) = 100 × 1.50 × 1.00 = **150**;
`bundle_neutral_taunt` (avg 3.0, mid, no shared tag) = **100**; `bundle_neutral_giants` (avg 5.33,
high) = 100 × 1.0 × 0.70 = **70**. Total 675 → slot-1 odds 26.7 / 25.9 / 22.2 / 14.8 / 10.4 %.
On floor 7 (band 3) with nine `weapons` cards in the deck (`affinity = 1 + 0.25 × min(9, 6) =
2.5`): weapons bundle = 100 × 2.5 × 1.0 = 250, giants = 130 — on-plan still leads, but the late
high-cost neutral now beats any off-plan mid.

### F2. Treasure weight

The `treasure_weight` formula is defined as:

`treasure_weight(t) = round(RARITY_W[rarity(t)] × (100 + TREASURE_AFFINITY × affine(t)) / 100)`

with `affine(t) = 1` if `tags(t) ∩ plan_tags(hero) ≠ ∅` else `0` (plan tags only, as Treasures T6
states; the affinity tag `war | decay | knowledge` is display information here — every T8
hero-affine treasure also carries one of its hero's plan tags, so nothing is lost);
`universal(t) ⇔ "universal" ∈ tags(t)` (Treasures T1: exactly one affinity tag per treasure, so a
universal treasure is tagged `universal`, never `[]`). A universal treasure can also be affine —
Iron Constitution `[universal, defensive, armour]` is affine for War — so `universal` and `affine`
are independent predicates, not a partition.

**Variables:**
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| RARITY_W | int | 1–100 each (default common 70, rare 30) | data file `treasure_rarity_weights` | Per-item weight by rarity (DD-H04 two tiers) |
| TREASURE_AFFINITY | int (%) | 0–200 (default 50) | data file | Boost for a treasure tagged with one of the hero's plan tags |
| plan_tags(hero) | string[] | 3–4 | Heroes H-5 (data) | The hero set's theme tags |
| tags(t) | string[] | 1–4 | Treasures T1 (`TreasureDef.tags`) | one affinity tag (`war \| decay \| knowledge \| universal`) + 0–3 plan/archetype tags; only the plan tags and `universal` are read here |

**Output Range:** 30 (plain rare) · 45 (affine rare) · 70 (plain common) · 105 (affine common).
With a 60/40 common/rare pool, rares are ≈ 22 % of offered slots (0.4 × 30 ÷ (0.6 × 70 + 0.4 × 30)).
**Example (T10 — a *synthetic* fixture shaped like an MVP pool: 7 universal with no War plan tag
— 4 common, 3 rare; 3 War-affine `weapons` — 2 common, 1 rare. The real T8 MVP pool is 5 C / 5 R
with 7 universal of which 4 are rare and three carry War plan tags, so its numbers differ; the
fixture exists to make the arithmetic checkable, Treasures owns the real mix):** slot 1 over the 7 universal: total 370, P(rare) = 90/370 = 24 %. If slot 1 took a
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
**Example:** War starter, `D = weapons` (3 vs 2 vs 2). Floors 1 and 2 offer no `weapons` bundle
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

**Output Range:** `B_min` runs from 4 (`F = 3, W = 0`) to 27 (`F = 12, W = 7`) over the variable
ranges — the registry's `bundle_pool_min` range. v1 (`F = 8`): `W = 1 → 11`, `W = 2 → 13`,
`W = 3 → 15`, `W = 5 → 19`, never re-offer → 21. DD-H05's per-hero pool is `B = 20` (8 hero-set +
12 neutral, raised from 6 neutral on 2026-11-03), so any `W ≤ 5` is solvent and the default
`W = 2` leaves 7 spare; only "never re-offer" (21) is one short. MVP (`F = 4`): `B_min = 9` for
any `W ≥ 2`; DD-H06's 10 bundles leave one spare. **Example (v1, B = 20, W = 2):** eligible per
floor 20, 17, 14, 13, 12, 11, 10 — never below 3; with no re-offer it would be 20, 17, 14, 11, 8,
5, 2 (short on floor 7). (With the former 14-bundle pool the same series read 14, 11, 8, 7, 6, 5,
4 and no-re-offer went short on floor 5; fixture **P14** in Acceptance Criteria keeps that shape
so the bound stays testable.)

### F6. Treasure pool sufficiency

`remaining_before_draft_k = N − 3 × (k − 1)`; need `≥ 3` for `k = K` ⇒ `N ≥ 3K` (= Card Database
`min_treasure_pool`, 9 at `K = 3`). Universal floor — one rule, cited by Interactions and
Dependencies: **hard floor `n_universal ≥ K`** (3 at `K = 3`: one universal per draft, best-effort
slot, flag `universal_missing` when a draft finds none); **recommended `n_universal ≥ 3K − 2`**
(7 at `K = 3`: the slot is guaranteed in every draft). T8 ships 10 at v1 and 7 at MVP, so the
recommendation holds for both.

| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| N | int | 0–100 | `draft_state.treasure_pool` size | Unlocked treasures at run start |
| K | int | 0–7 | `len(treasure_floors ∩ [1, F − 1])` | Treasure drafts in this run |
| n_universal | int | 0–N | Treasures T8 | Unlocked treasures whose affinity tag is `universal` (T8: 10 of 20 at v1, 7 of 10 at MVP) |

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
| plan_tags(hero) | string[] | 3–4 | Heroes H-5 | Same set Heroes F2 scores the starter with (War 7/15 ≈ 0.47 — `war_iron_vanguard` carries Content's `armour` tag; Decay 5/15, Knowledge 6/15) |
| k | int | 0–7 | from `drafts[]` | Hero-set bundles taken (each adds 3 plan cards; neutral bundles add 0) |

**Output Range (War, 7 starter plan cards):** `plan_share(8) = (7 + 3k) / 36`: k = 0 → 0.19,
3 → 0.44, 4 → 0.53, 5 → 0.61, 7 → 0.78 (Decay starts from 5, Knowledge from 6 — the intercept
moves, the slope does not). **Targets:** median player `plan_share(8) ≥ 0.45` (≥ 4 hero bundles
of 7 — a uniform random picker lands near **0.43** because 8 of DD-H05's 20 per-hero bundles are
hero-set (`k ≈ 7 × 8/20 = 2.8 → (7 + 8.4)/36`), so the 0.45 target rests on affinity and pity,
which is what they are for; at the former 14-bundle pool the uniform baseline was ≈ 0.53), and
`top_tag_share(8) ≥ 0.30` (three bundles per tag at DD-H05's 8 hero bundles give 3 + 9 = 12/36 =
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
*plan* cards in the first ten = `10 × plan_share`: 4.7 at floor 1 (0.47, War), 4.5 at floor 8 if F7's
0.45 holds. The affinity + pity rules therefore exist to keep plan density flat-to-rising under
dilution, which is the design claim `/balance-check` tests.

## Edge Cases

`systems-designer` not consulted — Lean mode and no `Agent` tool in this session.

**Short and exhausted pools**
- **If fewer than 3 bundles are eligible**: D8 — first drop the cooling window (`reoffer`), then
  offer what remains with `short` and `run_warning{bundle_pool_short}`, then, at zero, return
  `[]` and the run skips the bundle step. Card Database rejects a pool under 3 at load, so zero
  needs 3 bundles and a 4th draft.
- **If fewer than 3 treasures are eligible**: with DD-H06's 10 and `K = 3` this never happens
  (10, 7, 4 — F6); with 8 it happens on draft 3 (2 left) → `treasure_short_policy = fewer` offers
  two with `short` + `run_warning{treasure_pool_short}`; `reoffer` (debug builds only, DD-X06)
  refills from offered-not-held. Zero eligible → `[]` and the run proceeds to the bundle step. A held treasure is never offered.
- **If every hero-set bundle is taken or cooling** (possible from floor 5 at v1 with `W = 2`: 8
  hero bundles, 4 taken on floors 1–4, up to 4 cooling from floors 3–4): candidates are neutral-only; pity has no `D` candidate and does not fire
  (no flag — pity never invents a bundle); coverage still works across neutral themes; no warning
  because this is expected late-run content pressure, visible in `flags` and `/balance-check`.
- **If pity is due but no candidate carries `D`**: slot 1 is an ordinary weighted pick; `starve`
  keeps counting and pity re-arms on the next draft that has a `D` candidate.
- **If every candidate shares one theme**: three same-theme offers; `coverage_forced` is not set
  (it marks a restriction that was applied, not a wish). Content can see it in `draft_offered`.
- **If no universal treasure remains**: slot 1 draws over all candidates; flag `universal_missing`.

**Ties, tags and data**
- **If two plan tags tie for `n_tag`**: `D` is the earlier tag in `plan_tags(hero)` data order
  (War: `weapons` before `aggro` before `armour`) — fixed, never a draw.
- **If a deck card carries several tags**: it counts once toward each tag's `n_tag`; a card can
  feed two themes' affinity and two themes can tie through it (previous rule).
- **If a bundle's theme is not one of the hero's plan tags** (every neutral theme): affinity
  still counts deck cards carrying that tag (a Taunt-heavy deck boosts `bundle_neutral_taunt`),
  but pity never forces it because `D ∈ plan_tags(hero)`.
- **If a bundle contains a token id, a missing id, or not exactly 3 cards**: impossible after
  Card Database CR-5 stage 6 (`E_TOKEN_IN_LIST`, `E_UNKNOWN_REF`, `E_COUNT`). Defensively, `offer`
  checks `len(cards) == 3` and `card(id) != null ∧ !token` (reachable only via a debug
  `reload()`), excludes the bundle, and emits `run_warning{bundle_invalid, bundle_id}`.
- **If `pick` names an offered id whose record no longer resolves** (debug reload between offer
  and pick): `E_UNKNOWN_ID`, no event; the run calls `offer` again.
- **If `weighted_pick` returns `−1`** (zero total — impossible since F1/F2 weights are ≥ 1):
  assert in debug; in release return `[]` with `run_warning{draft_fault, floor, kind}` so a bug
  is a logged empty draft, never a crash or a silent pick.

**Save, resume, seeds**
- **If the app quits between the treasure pick and the bundle pick**: the S3 save holds the
  treasure and `draft_<floor>` at `draws = 3`; the bundle offer regenerates identically — nothing
  the treasure pick changed (`treasures[]`, the treasure `DraftRecord`) is an input to D4–D6.
- **If the app quits while an offer is on screen**: nothing is written mid-pick (DD-R08); resume
  restores S2/S3 and `offer` regenerates the same ids; a second `draft_offered` is logged.
- **If a treasure is unlocked mid-run**: invisible to this run — `draft_state.treasure_pool` was
  snapshotted at `init_run`; it appears from the next `new_run`. The reverse (a snapshotted
  treasure becoming locked) likewise changes nothing.
- **If `draft_state` lacks `schema_version`/`treasure_pool`** (save predating `init_run`, or
  tampered): Run Structure calls `init_run` at resume before any `offer`, emits
  `run_warning{draft_state_init_late}`, and the offers may differ from those shown before the quit
  — accepted on a corrupted-save path (**contract amendment**, Open Questions).
- **If two runs share a seed and hero**: identical offers on every floor while picks are
  identical; from the first divergent pick, `deck`, weights and pity history differ and so do
  later offers (DD-R09). Quitting and resuming cannot re-roll an offer, so pity cannot be farmed.
- **If `allow_custom_seed` is off**: no effect here; `offer` never reads the seed, only the stream.

**Layout and configuration**
- **If `floors_per_run = 4` (MVP, DD-H06)**: Run Structure filters `treasure_floors` to `[1, 3]`
  (`K = 2`, needs 6 treasures); three bundle drafts need `B ≥ 9` (F5), satisfied by 10.
- **If a treasure floor is `≥ floors_per_run`**: Run Structure ignores it; `offer(treasure)` is
  never called for it.
- **If `reoffer_after_floors = 0`**: no cooling — a declined bundle can return next floor; legal,
  but F5 collapses to `B ≥ F + 1` and offers feel repetitive (Tuning Knobs warns).
- **If `allow_skip` is on and the player skips every floor**: the deck stays at 15; every
  invariant holds (non-null picks counted); F7/F8 tables degenerate to floor-1 values.
- **If the deck exceeds 40 cards** (longer `floors_per_run`): no cap (DD-R06); `AFFINITY_CAP`
  bounds every weight so a 50-card deck cannot inflate totals; Run UI's deck list must scroll.
- **If `hero(hero_id).set` has no bundles of its own** (an unlock hero shipped early): the pool
  is neutral-only (12 at v1, DD-H05 — one under F5's `B_min = 13` at `W = 2`, so floor 7 drops
  the cooling window with flag `reoffer` and still offers 3, never `short`); pity never fires;
  everything else works.

## Dependencies

Hard = Reward Draft cannot produce an offer without it; soft = degrades to a default.
Bidirectional check against `design/gdd/systems-index.md`: the index's system row lists Reward
Draft as depending on Run Structure, Card Database, Treasures, Heroes, Meta Progression and RNG &
Event Log (all below) and lists Run UI as depending on Reward Draft (below) — consistent; its
design-order list (§ "Design order", item 4) still names only four of the six — flagged for
`/map-systems`, not edited here. This table **adds** Content as a soft dependent. Run Structure,
Card Database, RNG & Event Log, Heroes, Treasures, Meta Progression and Run UI each already name
Reward Draft in their own Dependencies — consistent.

| System | Direction | Hard/Soft | Nature of dependency / interface |
|---|---|---|---|
| Run Structure | Mutual | Hard | It invokes `init_run` (R2 — amendment), `offer` (R5.3, R8.2) and `pick` (T11/T12), passes `run_state` and `draft_<floor>`, persists `draft_state` opaquely, enforces the pick guards, and emits `treasure_granted` / `deck_grew`. We own offer content, weights, pity, the two draft events and `draft_state`'s schema. Amendments to its R5 contract: `init_run`, empty-offer skip, `draft_state` schema, `pick` signature. |
| Card Database | This depends on Card Database | Hard | `bundle_pool(set)`, `treasure_pool()`, `bundle(id)`, `card(id)` (`cost`, `tags`, `token`), `hero(id).set`; id-sorted results (CR-6) are what make seeded draws reproducible; CR-5 stage 6 guarantees bundle integrity; CR-3 carries `TreasureDef.tags` and CR-1/DD-T01 list `reward_draft.json`. |
| RNG & Event Log | This depends on RNG & Event Log | Hard | `draft_<floor>` stream, `weighted_pick` (1 draw, integer weights, positive total guaranteed here); the run log for `draft_offered` / `draft_picked`; `restore()` semantics make D12 true. |
| Treasures | This depends on Treasures (data) | Hard for treasure drafts | `rarity`, `tags` (T1 shape: one affinity tag + plan/archetype tags), `unlock` per treasure (contract confirmed against T6 as restated 2026-11-03: `init_run` snapshot, `drafts[]`-derived exclusion, per-item weights; `Treasures.pool(is_unlocked, exclude_ids)` is the predicate, call site is an architecture choice); Treasures owns effects and applies picks at match start; we never call it. |
| Heroes | This depends on Heroes (data) | Soft | `HeroDef.set` selects the pools; H-5 theme tags are `plan_tags(hero)`. Without plan tags, pity and affinity are inert and offers are uniform-by-band. |
| Meta Progression | This depends on Meta Progression | Soft | `unlocked_keys() → Set[string]` (meta-progression M1.3) read once at `init_run`; a treasure is in the pool iff `unlock == null` or `unlock.key ∈ unlocked_keys()` (treasures T6 predicate); Meta confirms `init_run` timing (its Interactions and Dependencies rows); the filter runs before any seeded draw, as Meta requires; MVP: everything unlocked. Downstream it reads pick rates from archived logs. |
| Run UI | Run UI depends on this | Soft (headless in tests) | Renders the `Offer` read model and issues `draft_pick`; UI Requirements. |
| Content | Content depends on this | Soft | F5/F6 pool floors (`B_min = 13` at v1 with `W = 2`, met by DD-H05's 20 per hero; `N ≥ 9`; `n_universal` hard floor 3, recommended 7); theme tags per bundle; `run_warning{*_pool_short}` tells Content when it is thin. |

## Tuning Knobs

All in `assets/data/reward_draft.json` unless noted. `systems-designer` not consulted — Lean mode.
Interactions to check together: `reoffer_after_floors` and `PITY_WINDOW` (a long cooling window
can remove every `D` bundle exactly when pity wants one); `AFFINITY_STEP` × `AFFINITY_CAP` against
the coverage rule (defaults top out at 2.5; the cross-review's D-02 found 3.0 already made the
coverage slot the only off-plan option from floor 5; above ≈ 4.0 the draft reads as solved); `treasure_offers_per_draft` against Card Database `min_treasure_pool`.

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|---|---|---|---|---|
| `BASE_WEIGHT` | 100 | 10–1000 | Pure scale; no behavioural effect unless rounding bites below ~20 | Below 10, rounding flattens affinity steps |
| `AFFINITY_STEP` (stored ×100) | 0.25 | 0.10–0.50 | Stronger "the game knows my deck"; above 0.5 off-plan bundles appear only via coverage (solved draft) | Offers drift toward uniform; plan_share falls toward the random-picker 0.40 (F7) |
| `AFFINITY_CAP` | 6 (was 8 — cross-review D-02) | 4–12 | Late decks keep gaining pull; at 8 an on-plan bundle weighs 3.0× and from floor 5 the coverage slot is usually the only off-plan option (rails); above 12 the floor-7 draft is a formality | Affinity saturates early (a War starter with one `weapons` bundle already sits at the cap); below 4 late drafts feel random |
| `band_cost_curve` | band 1 = 120/100/70; 2 = 100/110/100; 3 = 80/100/130 (%) | 50–200 each | Steeper curve: cheaper early, bigger late; above 150/50 a bundle class vanishes from a band | Flat (100 everywhere): cost ignored, floor-1 offers of 5-drops |
| `COST_LOW` / `COST_HIGH` | 2.5 / 4.0 | 2.0–3.0 / 3.5–5.0 | Moves bundles between buckets; must keep `COST_LOW < COST_HIGH` | — |
| `PITY_WINDOW` | 2 | 1–4 | Rarer forced returns; at 4 a theme can vanish for half a run | At 1, `D` is offered every other draft at least — strong rails, less discovery |
| `reoffer_after_floors` | 2 | 0–3 (F5 permits `W ≤ 5` at DD-H05's 20 bundles per hero; above 3 a declined bundle vanishes for half the run) | Fewer repeats; above 5 the v1 pool goes short on floor 7 (F5) | 0 = a declined bundle can return immediately; repetitive |
| `universal_slot` | true | bool | — | Off: a themed-only treasure offer is possible; weaker "always a safe pick" promise |
| `treasure_rarity_weights` | common 70 / rare 30 | each 1–100 | More of that tier per slot; 50/50 makes rares ~40 % of slots at a 60/40 pool | — |
| `TREASURE_AFFINITY` | 50 (%) | 0–200 | Hero-tagged treasures crowd the two free slots; above 100 universal-only offers never happen except by the forced slot | 0: tags ignored |
| `treasure_short_policy` | `fewer` | `fewer` only in shipping builds; `reoffer` is debug-only (DD-X06 — it violates DD-R05's no-repeat rule) | — | — |
| `allow_skip` | false | bool | On: a "Take nothing" option; deck growth becomes optional (anti-Pillar 1; DD-R06 becomes an upper bound) | — |
| `bundle_offers_per_draft` / `treasure_offers_per_draft` | 3 / 3 | 2–4 (constants in v1 — DD-R04 / DD-R05) | More choice, faster pool exhaustion (F5/F6 scale with it), wider UI | 2: coverage rule degenerates to "the two differ" |
| `treasure_floors`, `floors_per_run` | `[1, 3, 5]`, 8 | Run Structure | See `design/gdd/run-structure.md` Tuning Knobs — not duplicated | — |
| `bundle_card_count`, `starter_deck_size` | 3, 15 | Card Database | Registry constants; F7/F8 read them | — |

## Visual/Audio Requirements

Optional for `Economy`; `art-director` not consulted — Lean mode. Run UI owns the screen; this
GDD only names the events that need feedback so they are not lost.

| Event | Visual Feedback | Audio Feedback | Priority |
|---|---|---|---|
| `draft_offered` | Three options revealed left to right (bundles: 3-card fan with theme label; treasures: single card with rarity frame) | Soft reveal stinger, one per option | Medium |
| hover on an option | Cards enlarge; synergy count shown (UI Requirements) | — | Low |
| `draft_picked` | Chosen option lifts and flies to the deck/treasure tray; unchosen fade | Confirm tone; rare treasure gets a brighter variant | Medium |
| `short` / `reoffer` flag | Empty slot drawn as a dimmed placeholder with the one-line reason | — | Low |

Placeholder art in v1 (art bible §5–9 deferred). 📌 **Asset Spec** — after the art bible is
approved, run `/asset-spec system:reward-draft` for the option frames and the deck-fly animation.

## Game Feel

Not applicable as a feel system — `Economy` category, no real-time control. The one target: a
pick is committed on an explicit confirm (no undo exists, DD-R08 saves right after), and the
confirm-to-`draft_picked` response is immediate (under one frame of logic; the fly animation is
Run UI's). Anti-reference: a drafting screen that auto-advances on a single click.

## UI Requirements

`ux-designer` not consulted — Lean mode. Run UI renders from the `Offer` read model and the
run-scope events (`src/ui/**` display-only); no weight, flag or pity state is ever shown.

| Information | Display Location | Update Frequency | Condition |
|---|---|---|---|
| Step indicator "Treasure → Bundle" / "Bundle" | Draft screen header | On `draft_offered` | Treasure floors show both steps, current one highlighted |
| Bundle option: 3 card previews (name, cost, stats, text), theme label, `BundleDef.text` pitch | One panel per option, left to right in `option_ids` order | On `draft_offered` | kind = bundle |
| Treasure option: name, rarity frame (common/rare), `text` | One panel per option | On `draft_offered` | kind = treasure |
| Synergy count — "N cards in your deck share *theme*" (bundle `n_tag(theme)`) / "fits your plan" (treasure `affine`) | Hover tooltip on the option | On hover | Shows the number, never the weight; Open Questions asks whether to show it at all |
| Deck size preview "Deck 21 → 24" | Below the bundle options | On hover of an option | kind = bundle |
| Empty slot placeholder with reason ("No more treasures in this run") | In place of the missing option | On `draft_offered` with `short` | `len(option_ids) < 3` |
| Confirm control (select, then Confirm; or double-click) | Bottom centre | — | Always; "Take nothing" appears only when `allow_skip` |
| Current deck list (scrollable; no cap) and held treasures | Side drawer | On open | Always available from the draft screen |
| Rejection toast (`E_NOT_OFFERED`, `E_DRAFT_KIND`, `E_DRAFT_DONE`) | Toast | On rejection | Should never fire from a correct UI; shown for debugging honesty |

> **📌 UX Flag — Reward Draft**: This system has UI requirements. In Phase 4 (Pre-Production),
> run `/ux-design draft-picker` to create the UX spec for the draft screen **before** writing
> epics. Stories that reference UI should cite `design/ux/draft-picker.md`, not this GDD.

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|---|---|---|---|
| `offer(kind, run_state, stream)`, treasure-before-bundle, `draft_state` opaque | `design/gdd/run-structure.md` | R5 Reward phase, Interactions row | Ownership handoff (contract confirmed; amendments D1, D3, D8) |
| `DraftRecord` fields used for exclusion and pity | `design/gdd/run-structure.md` | R1 `drafts[]` | Data dependency |
| Save S2 before `offer`, S3 after treasure pick; resume regenerates | `design/gdd/run-structure.md` | R7, R8.2, AC-18 | Rule dependency |
| Pick guards `E_DRAFT_KIND` / `E_NOT_OFFERED` / `E_DRAFT_DONE`; `deck_grew`, `treasure_granted` emitted by the run | `design/gdd/run-structure.md` | R5.3–5, T11/T12 | State trigger |
| `band(f)`, `deck_size(f)`, `treasure_floors` filtered below `floors_per_run` | `design/gdd/run-structure.md` | F1, F4, R5.1 | Data dependency |
| `BundleDef` (`theme`, 3 cards, no tokens), `TreasureDef` (`rarity`, `unlock`) | `design/gdd/card-database.md` | CR-3, CR-5 stage 6 | Data dependency |
| Id-sorted `bundle_pool`, `treasure_pool`, `card().tags/cost` | `design/gdd/card-database.md` | CR-6 | Rule dependency |
| `bundle_pool_size` ≥ 3 else `E_COUNT`; `min_treasure_pool` = 9 | `design/gdd/card-database.md` | Formulas | Rule dependency |
| Cards are not weighted by rarity (treasures are) | `design/gdd/card-database.md` | CR-4 | Rule dependency |
| `draft_<floor>` stream ownership; draws only inside commands | `design/gdd/rng-event-log.md` | Core Rules A.3, B.7–8 | Rule dependency |
| `weighted_pick` = 1 draw, integer weights, positive total | `design/gdd/rng-event-log.md` | F4, Edge Cases | Rule dependency |
| `snapshot()`/`restore()` by draw count | `design/gdd/rng-event-log.md` | B.10, F5 | Data dependency |
| `draft_offered` / `draft_picked` rows; `treasure_granted` owner | `design/gdd/rng-event-log.md` | Core Rules D catalogue | Ownership handoff |
| `plan_tags(hero)`, starter tags, 6/15 plan share | `design/gdd/heroes.md` | H-4, H-5, F2 | Data dependency |
| `TreasureDef.tags` shape (one affinity tag + plan/archetype), the T8 pool (20 / 10 MVP, 10 universal), T6 pool predicate and per-item weights | `design/gdd/treasures.md` | T1, T6, T8 | Ownership handoff (contract confirmed both ways) |
| `unlocked_keys()` at `init_run` | `design/gdd/meta-progression.md` | M1.3, Interactions row "Reward Draft" | Data dependency (contract confirmed both ways — cross-review C-10) |
| `draft_offered{floor, kind, option_ids[], flags[]}`, 0–3 offers, no `theme_labels` | `design/gdd/run-ui.md` / `design/ux/draft-picker.md` *(planned)* | U8 contract, UI Requirements | Ownership handoff (contract) |

## Acceptance Criteria

`qa-lead` not consulted — Lean mode and no `Agent` tool in this session (Section H is HIGH-risk
per the skill). Fixtures: **P14** = the F1 example pool (8 `war` bundles — 3 `weapons`, 3
`aggro`, 2 `armour` — plus 6 neutral bundles over 3 themes; kept at 14 so the F5 bound in AC-9
stays testable), **P20** = the same 8 `war` bundles plus 12 neutral bundles over 4 themes (the
DD-H05 v1 shape; F5/F7 defaults), **T10** = the F2 example treasures,
**War starter** = Heroes H-4, defaults from `reward_draft.json`, `floors_per_run = 8`,
`treasure_floors = [1, 3, 5]`. "Seeds 1..N" means `run_seed` = 1, 2, …, N with the real RNG
service; a **zero stub** is a stream whose `randi32()` always returns 0 (so `weighted_pick`
returns the first candidate). Every test is a Logic story: automated unit tests under
`tests/unit/reward_draft/`.

**Determinism and purity (D1, D12, F4)**
- [ ] AC-1 **GIVEN** seed 42, War, P14/T10, floor 1, **WHEN** `offer(treasure)` then `offer(bundle)` run twice from an identical `run_state` and a freshly restored `draft_1`, **THEN** both runs yield identical `option_ids` and `flags` and `draft_1.draws` reads 3 after the treasure offer and 6 after the bundle offer.
- [ ] AC-2 **GIVEN** floor 2 (no treasure), **WHEN** `offer(bundle)` runs, **THEN** `draft_2.draws == 3`; over a full 8-floor simulated run the `draft_*` streams total 30 draws, and 15 with `floors_per_run = 4`.
- [ ] AC-3 **GIVEN** a run saved at S3 on floor 3 (`draft_3` at `draws = 3`) whose pre-quit bundle offer was `[a, b, c]`, **WHEN** restored and `offer(bundle)` is called, **THEN** it returns `[a, b, c]` with the same flags; **AND** a run saved at S2 (`draws = 0`) regenerates the same treasure offer.
- [ ] AC-4 **GIVEN** any `run_state` fixture, **WHEN** `offer` runs, **THEN** a deep comparison of `run_state` (including `draft_state`) before and after is equal, and no event other than one `draft_offered` was appended.
- [ ] AC-5 **GIVEN** seeds 1..1000 on any floor, **WHEN** offers are generated, **THEN** every `option_ids` is strictly ascending by id and contains no duplicates.

**Exclusion and cooling (D4, D7, F5, F6)**
- [ ] AC-6 **GIVEN** bundle `b1` picked on floor 1, **WHEN** offers on floors 2–7 are generated for seeds 1..1000, **THEN** `b1` never appears.
- [ ] AC-7 **GIVEN** `b2` offered but not taken on floor 1 and `reoffer_after_floors = 2`, **WHEN** offers are generated for seeds 1..1000, **THEN** `b2` appears on no floor-2 or floor-3 offer and on at least one floor-4 offer.
- [ ] AC-8 **GIVEN** `t1` held and `t2`, `t3` offered on floor 1, **WHEN** treasure offers on floors 3 and 5 are generated for seeds 1..1000, **THEN** none contains `t1`, `t2` or `t3`.
- [ ] AC-9 **GIVEN** P14 and `W = 2`, **WHEN** a run drafts a bundle on every floor 1–7 for seeds 1..1000 under each of three pick policies (always the id-first option, always the id-last option, uniform random from `draft_<floor>`), **THEN** no bundle offer carries `short` or `reoffer`; **AND GIVEN** `W = 3`, **THEN** at least one seed carries `reoffer` by floor 7 (F5 bound).
- [ ] AC-10 **GIVEN** a treasure snapshot of 10 (T10), **WHEN** the three treasure drafts run, **THEN** none carries `short`; **GIVEN** a snapshot of 8 and `treasure_short_policy = fewer`, **THEN** the floor-5 offer has exactly 2 options, flag `short`, and one `run_warning{treasure_pool_short, floor: 5, needed: 3, available: 2}` is emitted.
- [ ] AC-11 **GIVEN** a debug build, the 8-treasure case and `treasure_short_policy = reoffer`, **WHEN** the floor-5 offer runs, **THEN** it has 3 options, flag `reoffer`, the refilled option was previously offered and not held, and no held treasure appears; **AND GIVEN** a release build, **WHEN** `reward_draft.json` carries `treasure_short_policy = reoffer`, **THEN** the config validator rejects it with `E_CONFIG` (DD-X06, D8).
- [ ] AC-11b **GIVEN** P20 and `W = 2`, **WHEN** a run drafts a bundle on every floor 1–7 for seeds 1..1000 under the three AC-9 pick policies, **THEN** no offer carries `short` or `reoffer` and floor 7 has ≥ 10 eligible candidates before the draw (F5 example); **AND GIVEN** `W = 6`, **THEN** at least one seed carries `reoffer` by floor 7 (`B_min = 21 > 20`).
- [ ] AC-12 **GIVEN** a 3-bundle pool and `floors_per_run = 8`, **WHEN** floors 1–4 are drafted, **THEN** floor 1 offers 3; floor 2 offers 2 with flags `[reoffer, short]` and a `run_warning{bundle_pool_short}`; floor 3 offers 1; floor 4 returns `[]`, and a stub run records `DraftRecord{picked_id: null}`, leaves `deck` unchanged and advances the floor.

**Pity and coverage (D6, F3)**
- [ ] AC-13 **GIVEN** War starter (`D = weapons`) and injected `drafts[]` where floors 1 and 2 offered no `weapons` bundle, **WHEN** `offer(bundle)` on floor 3 runs for seeds 1..1000, **THEN** every offer contains a `weapons` bundle and `flags` contains `pity_forced`.
- [ ] AC-14 **GIVEN** any deck, **WHEN** offers on floors 1 and 2 are generated for seeds 1..1000, **THEN** `pity_forced` never appears; **AND GIVEN** `PITY_WINDOW = 1` in the fixture config, **THEN** it can appear on floor 2 (proves the value is data-driven).
- [ ] AC-15 **GIVEN** a `weapons` bundle offered but declined on floor 2, **WHEN** floor 3 is offered, **THEN** `pity_forced` is absent for every seed (decline resets `starve`).
- [ ] AC-16 **GIVEN** the deck pivots to `aggro` × 8 vs `weapons` × 3 and `aggro` was offered on floor 2, **WHEN** floor 3 is offered, **THEN** `D == aggro` and no pity fires even though `weapons` was starved.
- [ ] AC-17 **GIVEN** `weapons` 3 and `aggro` 3 in the deck, **WHEN** `D` is computed, **THEN** `D == weapons` (first in `plan_tags` data order).
- [ ] AC-18 **GIVEN** P14 on floor 1, **WHEN** offers run for seeds 1..1000, **THEN** no offer has three options of one theme; `coverage_forced` is present exactly in the offers where the first two drawn slots shared a theme (verified against a recording stream).
- [ ] AC-19 **GIVEN** every candidate shares one theme (fixture), **WHEN** an offer runs, **THEN** all three share it and `coverage_forced` is absent; **AND GIVEN** no candidate carries `D` while pity is due, **THEN** `pity_forced` is absent and the offer still has 3 options.

**Weights (F1, F2)**
- [ ] AC-20 **GIVEN** the F1 example deck and candidates on floor 1, **WHEN** `bundle_weight` is computed, **THEN** the values are 180 / 175 / 125 / 100 / 70; **AND** on floor 7 with nine `weapons` cards the weapons bundle is 250 (`AFFINITY_CAP = 6`) and the giants bundle 130; **AND GIVEN** `AFFINITY_CAP = 8` in the fixture config, **THEN** the weapons bundle is 300 (proves the cap is data-driven).
- [ ] AC-21 **GIVEN** T10 for War, **WHEN** `treasure_weight` is computed, **THEN** affine common = 105, plain common = 70, affine rare = 45, plain rare = 30.
- [ ] AC-22 **GIVEN** a zero stub stream on floor 1 with P14, **WHEN** `offer(bundle)` runs, **THEN** `option_ids` are the id-first eligible candidate of each slot's (possibly restricted) list, sorted; with a stream returning `total − 1` it is the id-last candidate of each list.
- [ ] AC-23 **GIVEN** T10 (6 common / 4 rare), **WHEN** floor-1 treasure offers run for seeds 1..10000, **THEN** every offer contains ≥ 1 universal treasure with `universal_forced` set, and rares are 15–30 % of the slot-2/3 picks.

**Pick resolution and events (D9, D11)**
- [ ] AC-24 **GIVEN** bundle offer `[a, b, c]`, **WHEN** `pick(bundle, b, offer, run_state)` is called, **THEN** exactly one `draft_picked{floor, kind: bundle, picked_id: b, option_index: 1, card_ids_added: bundle(b).cards}` is emitted with 3 ids in data order and the return matches.
- [ ] AC-25 **GIVEN** a treasure offer, **WHEN** `pick(treasure, id, …)` is called, **THEN** `draft_picked.card_ids_added == []` and `option_index` is `id`'s position in the sorted list; the run's `treasure_granted` follows it in the log.
- [ ] AC-26 **GIVEN** `allow_skip = false`, **WHEN** `pick(bundle, null, …)` is called, **THEN** it is rejected (`E_NOT_OFFERED`) with no event; **GIVEN** `allow_skip = true`, **THEN** it is accepted with `picked_id: null`, `card_ids_added: []`, and the run's deck is unchanged.
- [ ] AC-27 **GIVEN** `init_run` with a stub Meta Progression reporting `t9` locked, **WHEN** `t9` is unlocked after floor 1, **THEN** `t9` never appears on floors 3 or 5 of this run and appears in the next run's `draft_state.treasure_pool`.
- [ ] AC-28 **GIVEN** a bundle whose card list is corrupted to include a token id in a debug reload, **WHEN** `offer` runs, **THEN** that bundle is excluded, `run_warning{bundle_invalid}` names it, and the offer still has 3 options when ≥ 3 valid candidates remain.

**Coherence and dilution (F7, F8)**
- [ ] AC-29 **GIVEN** 1,000 simulated 8-floor runs (seeds 1..1000, War, P14) under a "follower" policy (always the option with the highest `n_tag(theme)`), **WHEN** final decks are measured, **THEN** mean `plan_share(8) ≥ 0.60` and mean `top_tag_share(8) ≥ 0.30`; under a uniform-random policy mean `plan_share(8) ≥ 0.45`; **AND GIVEN** the same 1,000 runs on **P20** (DD-H05 shape), **THEN** the follower mean `plan_share(8) ≥ 0.60` still holds, the uniform-random mean lands within ±0.05 of F7's 0.40 baseline (reported, not gated — it measures the pool, not the weighting), and the harness also prints the share of floor-5+ drafts whose only off-plan option is the `coverage_forced` slot (cross-review D-02 rails metric; Open Questions names the ~70 % trigger); the harness prints every number so a regression is a number, not a feeling.
- [ ] AC-30 **GIVEN** `deck_size = 36`, **WHEN** F8 is evaluated, **THEN** `p_starter = 15/36`, `P_no_starter_hand = 1330/7140` (±1e-9) and `P_card_seen(8, 10) = 10/36`.
- [ ] AC-31 **GIVEN** 50 bundles, 20 treasures and a 36-card deck, **WHEN** `offer` runs, **THEN** it completes in under 5 ms on the CI runner (measurement only, logged); **AND** no constant from Tuning Knobs appears as a literal in `src/` (grep gate in the story).

## Open Questions

| Question | Owner | Deadline | Resolution |
|---|---|---|---|
| Run Structure amendments proposed here: `init_run` at R2 step 5; `pick(kind, id, offer, run_state)` signature; empty offer ⇒ step skipped with `DraftRecord{picked_id: null}`; `draft_state` schema (D3) replaces "pity counters + `offered_treasure_ids[]`"; `init_run` on resume when `draft_state` lacks `schema_version`. | Run Structure GDD | `/consistency-check` after this GDD | **Resolved 2026-11-03 — cross-review C-30** (run-structure R2.5 / R5 / R8.2 confirmed both ways, scenario S-01) |
| `TreasureDef.tags: string[]` is needed for F2 affinity and the universal slot but is absent from Card Database CR-3. Add to CR-3 and `treasures.json`? | Card Database GDD | before `treasures.json` is authored | **Resolved 2026-11-03 — cross-review C-28** (Treasures T1 defines the shape; Card Database CR-3 carries `TreasureDef.tags`) |
| Rarity model: this GDD weights per item (F2), so the rare share of slots is ≈ 26 % at 11 C / 9 R, not the 30 % a per-slot roll gives; Treasures T6 (restated 2026-11-03) adopts per-item and calls its F4 odds approximations. Re-fit Treasures F4 `p_seen` and F1 band budgets from F2 at the first balance pass. | Treasures GDD | first balance pass | Agreed model; numbers to re-fit |
| Call site for the T6 predicate: `init_run`/D7 call `Treasures.pool(is_unlocked, exclude_ids)` or apply the same predicate over Card Database `treasure_pool()` directly (one fewer dependency edge at run time). | `/create-architecture` | before Reward Draft stories | Open — contract is the predicate either way |
| Offer-list naming: `Offer.option_ids[]` / `draft_offered.option_ids[]` (this GDD, Run UI U8, RNG catalogue) vs `DraftRecord.offered_ids[]` (Run Structure R1) — two names kept on purpose (D11 naming rule); Run Structure R5.3 writes `offer(...) → offered_ids[]` for the return value and should read `Offer{option_ids[], flags[]}`. | Run Structure GDD | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-30** (DD-X05; run-structure R5.3 now reads `Offer{option_ids[], flags[]}`, V-47) |
| Meta Progression's Interactions row reads `unlocked_ids("treasure")` "at `offer()` time"; this GDD reads it once at `init_run` and snapshots (D3) so a resume cannot change the pool (AC-3, AC-27). Amend Meta's row to `init_run`. | Meta Progression GDD | `/consistency-check` | **Resolved 2026-11-03 — cross-review C-10** (the call is `unlocked_keys()`, meta M1.3; Meta's rows already say `init_run`, V-49) |
| Run UI U8 (revised 2026-11-03) now builds `len(option_ids)` options (1–3) with placeholders, reads no `theme_labels` and no `synergy_tags` — matching D8/D11; its Dependencies row still says "exactly 3 ids and optional theme labels" and its own Open Questions row still asks the question. RNG & Event Log's catalogue `draft_offered` row lacks `flags[]` and `draft_picked` lacks `option_index`. | Run UI GDD, RNG & Event Log GDD | `/consistency-check` | Run UI part **Resolved 2026-11-03** (its Dependencies row reads 1–3 with `flags`, cross-review V-50); catalogue fields assigned to RNG & Event Log as cross-review C-09 |
| Content CN-4: 6 neutral bundles reach 16 of 38 non-starter neutrals; Content recommends 12 neutral bundles (B = 20 per hero). Effect here: F5 allows `W ≤ 3` at B = 20; F7's "uniform picker ≈ 0.50" becomes 8/20 = 0.40, so AC-29's uniform-random `plan_share ≥ 0.45` would rest on affinity alone; the P14 fixture stays as is. Content also states pity wants ≥ 2 bundles per plan tag where this GDD's brief says ~3 (F7's `top_tag_share ≥ 0.30` assumes 3). | Owner (DD-H05) + Content GDD | before VS neutral-bundle batch | **Resolved 2026-11-03 — DD-H05 raised to 12 neutral (36 bundles, B = 20 per hero)**: F5 (`W ≤ 5` solvent, default 2 leaves 7 spare), F7 (uniform baseline 0.40; 0.45 rests on affinity), Tuning Knobs, Dependencies and AC-29 (fixture P20) updated; P14 kept as the F5-bound fixture. Bundles-per-tag stays ~3 (8 hero bundles over 3 tags) |
| `assets/data/reward_draft.json` is a new DD-T01 file (knobs in Tuning Knobs). | owner | before `/create-architecture` | **Resolved 2026-11-03 — cross-review C-28** (DD-T01 lists `reward_draft.json`) |
| `treasure_granted` owner in the RNG & Event Log catalogue: Reward Draft (catalogue) vs Run Structure (its R5.4 and this GDD's D11). | RNG & Event Log GDD | `/consistency-check` | **Resolved 2026-11-03 — cross-review V-19** (catalogue now lists Run Structure) |
| The brief's coherence target "top theme ≥ 45 % by floor 8" is unreachable from one tag with ~3 bundles per tag (F7); set as `plan_share ≥ 0.45` plus `top_tag_share ≥ 0.30`. Accept, or raise bundles-per-tag in Content? | owner | first balance pass | Reinterpreted here |
| Card Database OQ "MVP 8 treasures vs 9 needed": DD-H06 already raised to 10; F6 shows 10 → 10/7/4; the 8-case falls to D8 `fewer`. | — | — | **Resolved** by F6 + D8 |
| Concept doc says the first treasure is on floor 2; DD-R05 says 1/3/5 (inherited from run-structure OQ). This GDD follows DD-R05. | owner | before Content batch 1 | Open |
| Should the synergy count / "fits your plan" hint be shown at all? Player Fantasy wants pity felt as luck; the brief asks for a hover count. | ux-designer (`/ux-design draft-picker`) | Pre-Production | Proposed: show the count on hover only |
| v2 sinks: card removal at a treasure floor, or "forge" a bundle into one card. Out of v1. | owner | post-MVP | Deferred |
| Content brief: neutral bundle theme vocabulary (≥ 3 themes), `B ≥ 13` per hero at v1 (DD-H05 gives 20), `n_universal` hard floor 3 / recommended 7 (F6), ~3 bundles per plan tag. | Content GDD | `/design-system content` | Proposed |
| `/balance-check` rule for the "take the strongest" risk: flag any bundle whose pick rate when offered exceeds 60 % over ≥ 30 offers, and any below 10 %. | economy-designer | first balance pass | Proposed |
| `/balance-check` rails metric (cross-review D-02): report `top_tag_share` and the share of floor-5+ drafts whose only off-plan option is the `coverage_forced` slot; `AFFINITY_CAP` was lowered 8 → 6 (affinity 3.0× → 2.5×) on 2026-11-03 as the first response — if the share still exceeds ~70 % from floor 5, lower `AFFINITY_STEP` next (0.25 → 0.20), never below the 4–12 cap range. The cross-review itself proposed measuring first and lowering only on evidence; the owner may restore 8 and keep the metric. | economy-designer / owner | first balance pass | Applied (cap 6) — metric pending |
