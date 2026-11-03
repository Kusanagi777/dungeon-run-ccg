# Systems Index: Deckdelve (working title)

> **Status**: Approved (all 13 system GDDs Approved after individual design review)
> **Created**: 2026-11-03
> **Last Updated**: 2026-11-03 (all 13 systems Designed; reviews pending)
> **Source Concept**: design/gdd/game-concept.md
> **Review notes**: `TD-SYSTEM-BOUNDARY skipped — Lean mode.` `PR-SCOPE skipped — Lean mode.` `CD-SYSTEMS skipped — Lean mode.`

---

## Overview

Deckdelve is a single-player, run-based card battler: one hero, eight bosses, a draft after every
win. Mechanically it is two games stacked. The inner game is a **match**: a Hearthstone-style duel
on a single row of up to seven minions per side, driven by a pure rules engine that reads
data-defined cards and resolves their effects through a trigger/target/operation DSL with an event
log (Pillar 4, readable deterministic rules). The outer game is the **run**: a state machine that
picks a hero, sequences eight bosses from a banded pool, offers a bundle draft after every win and an additional treasure draft after floors 1, 3 and 5, and ends on death or victory (Pillar 1, every run builds a deck you couldn't have planned;
Pillar 3, lose fast). Around both sits a thin **meta** layer: a profile that records runs and
unlocks heroes and treasures.

Systems, one paragraph each (balanced density):

- **Card Database** (Core, Foundation). Loads JSON card, hero, boss, treasure and bundle
  definitions into typed in-memory records, validates them against a schema, and exposes lookups
  by id, set and tag. Everything else reads from it; nothing else parses JSON.
- **RNG & Event Log** (Core, Foundation, inferred). A seeded random service with named streams
  (run, match, draft) and an append-only event log every rules action writes to. Exists so tests
  are deterministic and so the UI can replay what happened (Pillar 4).
- **Match Rules** (Gameplay, Core). Turn structure, mana crystals, draw, hand and board limits,
  playing minions and spells, attacking, Taunt/Divine Shield/Charge/Rush/Windfury/Stealth and the
  core keyword set, damage and death resolution, win/loss. Pure logic over state objects; no nodes.
- **Card Effects** (Gameplay, Core). The effect DSL (triggers such as Battlecry, Deathrattle,
  start/end of turn, on damage; target selectors; operations such as damage, heal, buff, summon,
  draw, discover) and the resolver with a defined ordering for chains and auras. Hero powers and
  treasures are expressed in the same DSL.
- **Boss AI** (Gameplay, Core). A utility-scored opponent that evaluates plays and attacks
  against the match state using data-defined weights per boss, with a telegraphed intent where
  the boss passive allows it. Must play competently against any drafted deck.
- **Heroes** (Gameplay, Feature). The three launch heroes (War, Decay, Knowledge): starting
  health, hero power, 15-card starter deck and card set; the three unlockable heroes (Fortune,
  Order, Shadow) are data only, post-v1.
- **Run Structure** (Progression, Feature). The run state machine: hero select, boss sequence
  generation from three difficulty bands, floor progression, death and victory, save/resume of an
  in-progress run.
- **Reward Draft** (Economy, Feature). After each win, three themed bundles of three cards or, on
  treasure floors, three passive treasures; weighted pools with pity rules so plan-shaped offers
  appear; the deck grows by exactly one pick per floor.
- **Treasures** (Gameplay, Feature). Passive run-long modifiers (owner-scoped hook chain evolved
  from the prototype's modifier manager) and the pool of ~20 treasures with rarity and unlock
  state.
- **Meta Progression** (Persistence, Feature). The player profile: run log, per-hero stats,
  unlock conditions and state, settings; versioned save format.
- **Match UI** (UI, Presentation). Hand fan, board, hero portraits and health, mana bar, targeting
  arrow, mulligan screen, event feed, end-turn; display-only over match events; mouse-first.
- **Run UI** (UI, Presentation). Hero select, boss intro with passive text, draft picker (bundle
  or treasure), floor map or progress strip, death and victory summary, main menu and run log.
- **Content** (Gameplay, Feature). The authored data itself: ~120 cards across War, Decay,
  Knowledge and Neutral, 16 bosses in three bands, ~20 treasures, 36 bundles; produced in
  batches and balanced with `/balance-check`.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Card Database | Core | MVP | Approved | design/gdd/card-database.md | — |
| 2 | RNG & Event Log (inferred) | Core | MVP | Approved | design/gdd/rng-event-log.md | — |
| 3 | Match Rules | Gameplay | MVP | Approved | design/gdd/match-rules.md | Card Database, RNG & Event Log |
| 4 | Card Effects | Gameplay | MVP | Approved | design/gdd/card-effects.md | Match Rules, Card Database, RNG & Event Log |
| 5 | Boss AI | Gameplay | MVP | Approved | design/gdd/boss-ai.md | Match Rules, Card Effects, Card Database, RNG & Event Log, Meta Progression |
| 6 | Heroes | Gameplay | MVP | Approved | design/gdd/heroes.md | Card Database, Card Effects, Match Rules |
| 7 | Run Structure | Progression | MVP | Approved | design/gdd/run-structure.md | Match Rules, Heroes, Card Database, RNG & Event Log, Meta Progression |
| 8 | Reward Draft | Economy | MVP | Approved | design/gdd/reward-draft.md | Run Structure, Card Database, Treasures, Heroes, Meta Progression, RNG & Event Log |
| 9 | Treasures | Gameplay | MVP | Approved | design/gdd/treasures.md | Card Effects, Run Structure, Card Database, RNG & Event Log, Match Rules, Heroes |
| 10 | Meta Progression | Persistence | Vertical Slice | Approved | design/gdd/meta-progression.md | Run Structure, Heroes, Treasures, Card Database, RNG & Event Log |
| 11 | Match UI | UI | MVP | Approved | design/gdd/match-ui.md | Match Rules, Card Effects, Boss AI, Card Database, RNG & Event Log, Heroes, Treasures, Run Structure, Run UI, Meta Progression |
| 12 | Run UI | UI | MVP | Approved | design/gdd/run-ui.md | Run Structure, Reward Draft, Meta Progression, Card Database, RNG & Event Log, Match UI, Heroes, Boss AI, Treasures, Content |
| 13 | Content | Gameplay | MVP → Alpha | Approved | design/gdd/content.md | Card Database, Card Effects, Heroes, Treasures, Boss AI, Match Rules |

Priority notes: Meta Progression is Vertical Slice because the MVP hypothesis ("players want to
immediately replay a run") can be tested without unlocks; it is still required for v1 (Alpha).
Content is MVP for the first ~40 cards, 5 bosses (3/1/1) and 10 treasures and grows to Alpha scope.

---

## Categories

| Category | Description | Systems here |
|----------|-------------|--------------|
| **Core** | Foundation systems everything depends on | Card Database, RNG & Event Log |
| **Gameplay** | The systems that make the game fun | Match Rules, Card Effects, Boss AI, Heroes, Treasures, Content |
| **Progression** | How the player grows over time | Run Structure |
| **Economy** | Resource creation and consumption | Reward Draft |
| **Persistence** | Save state and continuity | Meta Progression |
| **UI** | Player-facing information displays | Match UI, Run UI |

Audio, Narrative and Meta categories are not used in v1 (minimal SFX is handled inside Match UI
and Run UI stories; boss intro lines are content, not a narrative system).

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for the core loop to function. Without these, you can't test "is this fun?" | First playable: 1 hero, 5 bosses, ~40 cards | Design FIRST |
| **Vertical Slice** | Required for one complete, polished run. | Full 8-boss run with save/resume | Design SECOND |
| **Alpha** | All features present in rough form. | 3 heroes, 16 bosses, 120 cards, meta progression | Design THIRD |
| **Full Vision** | Polish, edge cases, nice-to-haves, content-complete. | 6 heroes, hard-band modifiers, custom art | Design as needed |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. Card Database — every other system reads definitions from it; it is the only JSON parser (and serves per-system config files, CR-1).
2. RNG & Event Log — determinism and replay underpin testing (Pillar 4) and the UI's event feed.

### Core Layer (depends on foundation)

1. Match Rules — depends on: Card Database, RNG & Event Log
2. Card Effects — depends on: Match Rules, Card Database, RNG & Event Log
3. Boss AI — depends on: Match Rules, Card Effects, Card Database, RNG & Event Log, Meta Progression (telegraph setting, DD-X03)

### Feature Layer (depends on core)

1. Heroes — depends on: Card Database, Card Effects, Match Rules
2. Run Structure — depends on: Match Rules, Heroes, Card Database, RNG & Event Log, Meta Progression
3. Treasures — depends on: Card Effects, Run Structure, Card Database, RNG & Event Log, Match Rules, Heroes
4. Reward Draft — depends on: Run Structure, Card Database, Treasures, Heroes, Meta Progression, RNG & Event Log
5. Meta Progression — depends on: Run Structure, Heroes, Treasures, Card Database, RNG & Event Log
6. Content — depends on: Card Database, Card Effects, Heroes, Treasures, Boss AI, Match Rules

### Presentation Layer (depends on features)

1. Match UI — depends on: Match Rules, Card Effects, Boss AI, Card Database, RNG & Event Log, Heroes, Treasures, Run Structure, Run UI, Meta Progression
2. Run UI — depends on: Run Structure, Reward Draft, Meta Progression, Card Database, RNG & Event Log, Match UI, Heroes, Boss AI, Treasures, Content

### Polish Layer

None in v1 (hard-band modifiers and accessibility options beyond the Standard tier are Full Vision).

**Bottlenecks**: Match Rules (seven dependents in the table: Card Effects, Boss AI, Heroes, Run Structure, Treasures, Match UI, Content) and Card Effects (five: Boss AI, Heroes, Treasures, Match UI, Content). Both get the
`full` section set via `system_overrides` and are designed first after the foundation.
**Leaf nodes**: Match UI, Run UI, Meta Progression, Content.

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Card Database | MVP | Foundation | systems-designer | S |
| 2 | RNG & Event Log | MVP | Foundation | systems-designer | L |
| 3 | Match Rules | MVP | Core | game-designer, systems-designer, ai-programmer | L |
| 4 | Card Effects | MVP | Core | game-designer, systems-designer | L |
| 5 | Boss AI | MVP | Core | game-designer, ai-programmer, systems-designer | M |
| 6 | Heroes | MVP | Feature | game-designer, systems-designer | M |
| 7 | Run Structure | MVP | Feature | game-designer, systems-designer, economy-designer | M |
| 8 | Treasures | MVP | Feature | game-designer, systems-designer | M |
| 9 | Reward Draft | MVP | Feature | economy-designer, systems-designer, game-designer | M |
| 10 | Match UI | MVP | Presentation | game-designer, ux-designer, ui-programmer | M |
| 11 | Run UI | MVP | Presentation | game-designer, ux-designer, ui-programmer | M |
| 12 | Meta Progression | Vertical Slice | Feature | systems-designer, game-designer | S |
| 13 | Content | MVP → Alpha | Feature | game-designer, systems-designer, economy-designer | L |

---

## Circular Dependencies

- Treasures ↔ Reward Draft: Reward Draft offers treasures; Treasures need the run to apply.
  Resolution: Treasures owns the treasure definitions and the hook chain; Reward Draft only reads
  the treasure pool and writes a "treasure granted" event. No cycle in the data flow.
- Match UI ↔ Match Rules: none. The UI subscribes to the event log and sends commands; rules never
  reference UI (rule `src/ui/**`: display-only).

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Card Effects | Technical / Design | DSL may not express needed effects; ordering of triggers, auras and deathrattle chains | Design the DSL from a list of all 120 planned card texts; write ordering rules as Formulas; unit-test each operation and chain |
| Boss AI | Technical | Utility scoring may misplay against drafted decks, making bosses trivial or random | Per-boss weights in data (utility scores); an "intent" preview; AI-vs-AI simulation harness using the seeded RNG |
| Reward Draft | Design | Bundles collapse to "take the strongest" | Themed bundles with plan tags; pity rules; `/balance-check` on pick rates from the run log |
| Content | Scope | 120 cards and 16 bosses is the largest cost | Data-only authoring; batches of 20 cards; MVP ships with 40 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 13 |
| Design docs started | 13 |
| Design docs reviewed | 13 (all Approved 2026-11-03) |
| Design docs approved | 13 |
| MVP systems designed | 12/12 (Approved) |
| Vertical Slice systems designed | 1/1 (Approved) |

---

## Next Steps

- [x] Design MVP-tier systems in the order above (`/design-system [system-name]`) — all 13 Approved 2026-11-03
- [x] Run `/design-review` on each completed GDD — logs under design/gdd/reviews/
- [x] Run `/review-all-gdds` (2026-11-03 and 2026-11-03b, CONCERNS); `/gate-check technical-setup` in progress
