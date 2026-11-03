# Game Concept: Deckdelve (working title)

*Created: 2026-11-03*
*Status: Under Review*

> **Review notes**: `CD-PILLARS skipped — Lean mode.` `AD-CONCEPT-VISUAL skipped — Lean mode.`
> `TD-FEASIBILITY skipped — Lean mode.` `PR-SCOPE skipped — Lean mode.`
> Decisions recorded from the owner's answers on 2026-11-03: Hearthstone-style single-row board;
> launch heroes War, Decay, Knowledge; PC desktop; Godot 4; portfolio scope; content target
> "Small" (3 heroes, 8-boss runs from a pool of ~16, ~120 cards, ~20 treasures).
> **REVISED 2026-11-03** (`/design-review`, lean, independent reviewer — stale cross-document
> facts fixed in place after the 13 system GDDs were designed): treasure drafts are *in addition to*
> the bundle on floors 1, 3, 5 (DD-R04/R05), not an either/or; MVP pool is 5 bosses 3/1/1 for a
> 4-floor run plus 10 boss-only cards and 10 bundles (DD-H06); 36 bundles, not ~30 (DD-H05); Scope
> Tiers aligned to content.md CN-1; floor-1 bosses are teaching bosses with a passive, not vanilla
> decks (Pillar 2, content.md CN-3); hero display names noted (heroes.md H-3); the three resolved
> Open Questions moved to a Resolved list and the genuinely open ones listed; Next Steps ticked.

---

## Elevator Pitch

> It's a single-player roguelike card battler where you pick a hero, fight a gauntlet of eight
> escalating bosses, and build your deck as you go by choosing one of three card bundles after
> every win — and, three times a run, one of three rule-bending treasures as well. One loss ends
> the run. It is Hearthstone's Dungeon Run,
> rebuilt as a standalone game.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Card battler / roguelike deckbuilder (run-based, draft-driven) |
| **Platform** | PC (Windows desktop), mouse-driven, 1280x720 landscape |
| **Target Audience** | Lapsed and current Hearthstone players who loved Dungeon Run; Slay the Spire players who want minion combat |
| **Player Count** | Single-player |
| **Session Length** | One run: 30–45 minutes (8 matches of 3–6 minutes plus drafts; run-structure F5 models a victory run at ≈ 40 min and the median run, which ends in a loss, at ≈ 22 min). Natural stop after any match. |
| **Monetization** | None (portfolio release; free on itch.io) |
| **Estimated Scope** | Medium (4–7 months, solo, part-time) |
| **Comparable Titles** | Hearthstone (Dungeon Run / Monster Hunt), Slay the Spire, Monster Train |

---

## Core Fantasy

You are a lone adventurer descending a dungeon with nothing but a thin starter deck. Every boss you
beat makes you stronger and stranger: a bundle of cards nudges your deck toward a plan, a treasure
breaks a rule in your favour. By the final boss you are piloting a deck nobody could have built on
purpose, and it either comes together or it doesn't. The fantasy is **improvised mastery**: making
a coherent engine out of what the dungeon offered, then watching it fire.

---

## Unique Hook

It's like Hearthstone's Dungeon Run, **and also** it is a complete game: bosses are hand-designed
puzzles with their own rule-bending passives and decks, treasures are run-defining rather than
stat bumps, and meta progression unlocks new heroes and treasures so each run's draft pool changes
over time. The hook is that every run poses a different question ("can War's weapons out-race a
boss that heals 5 a turn?") and the draft is how you answer it.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Challenge** (obstacle course, mastery) | 1 | Escalating boss gauntlet, permadeath per run, bosses with rule-bending passives |
| **Discovery** (exploration, secrets) | 2 | 16-boss pool, treasure pool, unlockable heroes; each run reveals combinations |
| **Expression** (self-expression, creativity) | 3 | Draft choices define a deck identity; treasures let players lean into a plan |
| **Fantasy** (make-believe, role-playing) | 4 | Three hero identities — War (Halvard), Decay (Mother Wythe), Knowledge (Archivist Ilse); names are placeholders per heroes.md H-3 — with distinct powers and starter decks |
| **Sensation** (sensory pleasure) | 5 | Crisp card play feedback: snappy drag, impact on attack, clear effect resolution |
| **Narrative** (drama, story arc) | 7 | Light: boss intro lines and a run summary; no campaign |
| **Submission** (relaxation, comfort zone) | 8 | Turn-based, no timers; low-stress between matches |
| **Fellowship** (social connection) | N/A | Single-player, no social features |

### Key Dynamics (Emergent player behaviors)

- Players read the boss's passive before drafting and pick bundles that answer it.
- Players "commit" to a plan around turn 3–4 of a run (weapons, deathrattle chains, spell damage) and
  start passing bundles that do not serve it.
- Players restart immediately after a loss because runs are short and the next boss order differs.
- Players learn boss decks and telegraphed AI intents, turning early losses into later routine wins.

### Core Mechanics (Systems we build)

1. **Turn-based card combat** on a single row of up to 7 minions per side: mana crystals, hand of
   up to 10, draw per turn, minions attack minions or the hero, Taunt and other keywords.
2. **Data-driven card effects**: every card is JSON (cost, stats, keywords, effects as
   trigger + target + operation), resolved by one rules engine with a visible event log.
3. **Boss gauntlet**: eight bosses drawn from a pool of ~16 in three difficulty bands, each with a
   hero power or passive, a hand-tuned deck and a utility-scored AI with telegraphed intents.
4. **Reward draft**: after each win on floors 1–7 choose one of three themed card bundles (3 cards
   each); after wins on floors 1, 3 and 5 also choose one of three passive treasures, treasure
   first (DD-R04, DD-R05).
5. **Meta progression**: wins and losses record to a profile; unlock new heroes, treasures and
   bundle themes; run log with stats.

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | Hero pick, every draft, every mulligan and play; no forced path | Core |
| **Competence** (mastery, skill growth) | Boss patterns are learnable; the same deck piloted better wins more | Core |
| **Relatedness** (connection, belonging) | Minimal; a shareable run summary at most | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** — How: hero/treasure unlocks, run log, boss-defeated tracking
- [x] **Explorers** — How: discovering treasure and bundle synergies; seeing every boss
- [ ] **Socializers** — not served
- [x] **Killers/Competitors** — How: beating the gauntlet on the hardest band; personal bests

### Flow State Design

- **Onboarding curve**: a fresh profile pre-selects the War hero (simplest plan: minions and weapons; DD-X02, nothing is forced),
  floor 1 bosses are teaching bosses — each has one simple, telegraphed passive and a deck of
  mostly vanilla minions, so they still pose a question (Pillar 2; content.md CN-3) — and the
  first treasure pick is offered after the first win (floor 1, per DD-R05).
- **Difficulty scaling**: boss bands (floors 1–3 easy, 4–6 mid, 7–8 hard) with rising health and
  stronger passives; the player's deck scales through drafts.
- **Feedback clarity**: event log shows every effect; AI intents are telegraphed where possible;
  run summary shows damage dealt per card.
- **Recovery from failure**: a loss returns to hero select in under five seconds; nothing is lost
  except the run; unlock progress persists.

---

## Core Loop

### Moment-to-Moment (30 seconds)
Read the board, spend mana on cards from the hand, choose attacks, end turn, watch the boss act.
Satisfying because every card does something visible, attacks have weight, and the opponent's turn
resolves quickly.

### Short-Term (5-15 minutes)
One match (3–6 minutes) against a boss with a known passive, then a draft (30 seconds): a bundle
that pushes the deck toward a plan and, on floors 1, 3 and 5, a treasure that bends the rules
first. "One more boss" is the hook; a draft is a reward and a decision.

### Session-Level (30-120 minutes)
One full run: hero select, eight matches, up to seven bundle drafts and three treasure drafts,
victory screen or death screen with a run summary. Natural stop after any match (runs can be resumed). A session is one or two runs.

### Long-Term Progression
Unlocks: three more heroes (Fortune, Order, Shadow) and additional treasures and bundles earned by
run milestones (first win with each hero, bosses defeated, floors reached). The game is "done" when
every hero has beaten the gauntlet; the hard band keeps it replayable.

### Retention Hooks
- **Curiosity**: unseen bosses, locked heroes and treasures
- **Investment**: the run log and per-hero win counts
- **Social**: none in v1
- **Mastery**: beating the hard band with every hero

---

## Game Pillars

### Pillar 1: Every run builds a deck you couldn't have planned
The draft is the game. Bundles and treasures must create real decisions and real identities.
*Design test*: debating a bundle that is "generically good" vs one that is "strong only with a
plan", this pillar picks the plan-dependent one.

### Pillar 2: Bosses are puzzles, not stat walls
Each boss has a passive or hero power that changes how you must play, plus a deck built around it.
*Design test*: debating "more health" vs "a passive that punishes wide boards", this pillar picks
the passive.

### Pillar 3: Lose fast, learn fast
Runs are short, restarts are instant, and every loss should teach something legible.
*Design test*: debating a hidden boss mechanic vs a telegraphed one, this pillar picks telegraphed.

### Pillar 4: Readable, deterministic rules
Every effect is visible in an event log, resolves in a defined order, and could be reproduced from
a seed. If the player cannot tell why they lost, the rules failed.
*Design test*: debating a flashy effect whose ordering is ambiguous vs a plainer effect with clear
ordering, this pillar picks the clear one.

### Anti-Pillars (What This Game Is NOT)

- **NOT multiplayer or PvP**: it would compromise Pillar 2 (bosses as puzzles) and triple the
  engineering scope with networking and balance for symmetric play.
- **NOT a collection or pack economy**: there is nothing to buy or hoard; decks exist only inside a
  run. A collection would undermine Pillar 1.
- **NOT a constructed deck builder**: the old prototype's deck builder is dropped; starter decks
  are fixed per hero.
- **NOT a narrative campaign**: boss intro lines and flavour only; no dialogue trees or story
  branches.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Hearthstone: Dungeon Run | The whole loop: hero, 8 bosses, bundle/treasure drafts, permadeath | Standalone game; data-driven effects; bosses tuned as puzzles; unlockable heroes | Proves the loop is fun and replayable |
| Slay the Spire | Short runs, telegraphed enemy intents, unlock progression across runs | Minion combat on a board instead of block/attack math | Validates "lose fast, learn fast" and intent telegraphing |
| Monster Train | Treasures/artifacts that redefine a run; clear escalation per floor | One lane, simpler board | Validates run-defining passives |

**Non-game inspirations**: dungeon-crawl board games (one-more-room pacing), speedrun "reset
culture" (instant restarts).

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18–40 |
| **Gaming experience** | Mid-core; comfortable with card-game keywords |
| **Time availability** | 30–60 minute sessions on weeknights |
| **Platform preference** | PC |
| **Current games they play** | Hearthstone, Slay the Spire, Balatro |
| **What they're looking for** | The Dungeon Run feeling without a live-service client or collection grind |
| **What would turn them away** | Unclear rules, long opponent turns, unfair-feeling RNG, grind gates on heroes |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.7 (GDScript): free, strong 2D/UI, headless test and screenshot support; owner's preference |
| **Key Technical Challenges** | A pure, unit-testable rules engine with a data-driven effect DSL; deterministic seeded RNG; boss AI that plays competently against arbitrary drafted decks; effect ordering and triggers (deathrattle chains, auras) |
| **Art Style** | 2D stylized illustration (placeholder shapes and text in v1) |
| **Art Pipeline Complexity** | Low in v1 (placeholder); Medium later (custom 2D card art) |
| **Audio Needs** | Minimal (card play, attack, win/lose stingers; one ambient track) |
| **Networking** | None |
| **Content Volume** | v1: 3 heroes, ~120 collectible cards (3 hero sets of 25 + 45 neutral, DD-H03) plus 32 boss-only cards, 16 bosses (6/6/4, DD-R02), ~20 treasures (DD-H04), 36 bundles (DD-H05); ~8 hours to see most content (unverified — see Open Questions) |
| **Procedural Systems** | Run generation: boss sequence from banded pool, bundle and treasure offers from weighted pools with pity rules; all seeded |

---

## Risks and Open Questions

### Design Risks
- Drafts collapse into "take the strongest bundle" if bundles are not plan-shaped (Pillar 1).
- Boss passives overshoot and feel unfair rather than puzzling (Pillar 2 vs Pillar 3).
- Three heroes may feel samey if their card sets share too many neutral cards.

### Technical Risks
- Effect DSL expressiveness: some Hearthstone-style effects (auras, conditional triggers,
  "whenever" chains) need careful ordering rules; risk of a half-general DSL plus special cases.
- Boss AI quality against arbitrary decks; a utility-scored AI may still misplay drafted decks; mitigated by the AI-vs-AI harness.
- Headless screenshot evidence under Xvfb with Forward+ may need the Compatibility renderer.

### Market Risks
- Not commercial; the risk is portfolio relevance: it must demonstrate engineering craft (tests,
  data-driven design) as much as fun.

### Scope Risks
- Content volume (120 cards, 16 bosses) is the largest cost; mitigated by a data-only authoring
  pipeline and `/balance-check`.
- The salvage from the old prototype is presentation only; the rules engine is a full rewrite.

### Open Questions
- "~8 hours to see most content" vs run-structure F6 (`p_victory ≈ 3.3 %` for the median player,
  ≈ 22 min per median run → ~11 h per hero before skill growth; cross-review 2026-11-03). Not a
  contradiction (Challenge is aesthetic #1), but unmeasured: the first playtest measures floor-4/5
  win rates against the 0.70 / 0.65 targets, and if the audience sits lower the 0.90 floor-1
  onboarding promise is protected first.
- Visual direction "Torchlit Ledger" was chosen without the AD-CONCEPT-VISUAL gate; the art bible
  (`design/art/art-bible.md`, sections 1–4, Draft) builds on it with AD-ART-BIBLE also skipped.
  Owner confirms the direction before `/asset-spec`.
- Hero display names (Halvard, Mother Wythe, Archivist Ilse) and identity lines are designer
  placeholders (heroes.md Open Questions); owner changes them in `heroes.json` only, before
  `/asset-spec system:heroes`.

### Resolved (recorded in design/design-decisions.md)
- Treasure cadence — DD-R05 (after wins on floors 1, 3, 5, in addition to the bundle), reward-draft.md.
- Boss count per band — DD-R02 (6/6/4); MVP pool DD-H06 (5 = 3/1/1); run-structure.md.
- Mulligan — DD-M05 (3 cards, replace any subset once), match-rules.md.
- First-run hero — DD-X02: pre-selected, never forced.

---

## MVP Definition

**Core hypothesis**: "A hero plus eight drafted bosses, with bundle/treasure picks between them,
produces runs that players want to immediately replay."

**Required for MVP**:
1. Match rules engine (single-row board, mana, draw, combat, core keywords) with event log
2. Data-driven cards with an effect DSL; ~40 collectible cards (War set 25 + 15 neutral) plus 10
   boss-only cards (DD-H06, content.md CN-1)
3. Boss AI and a pool of 5 bosses across all three bands (3 / 1 / 1, DD-H06 — one spare band-1
   boss so MVP runs vary, cross-review D-06)
4. Run structure: hero select (War only), 4-floor gauntlet (`floors_per_run` 4, bands 2 / 1 / 1,
   run-structure.md), death/victory screens
5. Reward draft: 10 bundles (8 War + 2 neutral) and 10 treasures (DD-H06)
6. Match and run UI sufficient to play with a mouse

**Explicitly NOT in MVP** (defer to later):
- Decay and Knowledge heroes, remaining bosses, full card pool
- Meta progression, unlocks, run log
- Art, audio, animation polish

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1 hero, 4-floor run from a 5-boss pool (3/1/1), ~40 cards + 10 boss-only, 10 bundles, 10 treasures (DD-H06) | Core loop only | 6–8 weeks |
| **Vertical Slice** | 1 hero, full 8-floor run from a 9-boss pool (4/3/2), ~60 cards + 18 boss-only, 16 bundles, 12 treasures (content.md CN-1) | Core + full run + save/resume | +3–4 weeks |
| **Alpha** | 3 heroes, 16 bosses, ~120 cards + 32 boss-only, 36 bundles, 20 treasures | All features incl. meta progression, placeholder art | +6–8 weeks |
| **Full Vision** | 6 heroes, 24+ bosses, 200 cards | Custom art/audio, hard band modifiers | open |

---

## Visual Identity Anchor

**Direction: "Torchlit Ledger"** (owner to confirm during `/art-bible`; chosen without the
AD-CONCEPT-VISUAL gate in Lean mode).

- **One-line visual rule**: everything the player must read is lit; everything decorative sits in
  shadow.
- **Supporting principles**:
  1. *Cards are documents*: high-contrast type, fixed slots for cost, attack, health and text.
     Design test: if an art treatment reduces text contrast, the art loses.
  2. *The board is a table in a dungeon*: warm torch light on the play area, cool dark edges.
     Design test: UI chrome never competes with the play area for brightness.
  3. *Heroes own a colour*: War red-bronze, Decay green-violet, Knowledge blue-gold; bosses use
     desaturated versions of their band's colour. Design test: a screenshot should identify the
     hero without reading text.
- **Colour philosophy**: warm light vs cool dark; saturated colour reserved for state changes
  (damage, buffs, targeting).

---

## Next Steps

- [x] Engine chosen (Godot 4.7) — `/setup-engine` run
- [x] `/art-bible` sections 1–4 (placeholder art) — `design/art/art-bible.md`, Draft
- [x] `/map-systems` — decompose into systems — `design/gdd/systems-index.md`, 13 systems
- [x] `/design-system [system]` for each MVP system — 13 GDDs designed (8 Approved, 5 In Review on 2026-11-03)
- [ ] `/create-architecture`, `/architecture-decision` ×4, `/architecture-review`
- [ ] `/test-setup`, `/ux-design`, `/create-epics`, `/create-stories`, `/sprint-plan`
- [ ] `/gate-check` at each stage transition
