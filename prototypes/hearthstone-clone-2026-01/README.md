# Prototype: Hearthstone-Clone (January 2026)

Archived copy of `Kusanagi777/Hearthstone-Project/Hearthstone-Clone` (Godot 4.5, GDScript,
~11.6k lines, single commit dated 2026-01-09). Imported here unchanged except for the removal of
stray `*.tscn*.tmp` editor files and dead `data/cards/red|blue/*.tres.txt` copies. A `.gdignore`
in this folder keeps the root Godot project from importing it.

## Hypothesis tested

Can a Hearthstone-style card battler with a week-based run structure (schedule a week of duels,
side jobs and shop visits, draft card bundles after wins) be built quickly in Godot with
resource-based card data and a global modifier system?

## How to run

Open this folder as its own Godot 4.5+ project (`project.godot` is inside it) and run
`scenes/start_screen.tscn`. "Test Duel" skips the run flow and opens the match screen directly.
Note: the match flow does not complete as written (see Findings).

## Status

**Concluded.** Superseded by the Dungeon Run CCG production design (`design/gdd/`).

## Findings

What worked and is salvaged (rewritten to production standards, never imported from here):

- `scripts/card_ui.gd` hover, drag and hand-fan presentation
- `scripts/targeting_arrow.gd` bezier targeting arrow
- `scripts/discover_selection.gd` generic pick-one-of-N screen
- `scripts/victory_selection.gd` three-bundle reward draft screen
- `scripts/mulligan_screen.gd` flow (rules wrong: draws 10, keeps 5)
- `autoload/modifier_manager.gd` priority-ordered hook chain (good shape for run treasures; needs
  owner scoping and removal of the back-reference in `modifier.gd:77`)
- `data/card_data.gd` field list, `data/enums/keywords.gd` keyword list and
  `data/card_effect_base.gd` helper names as vocabulary for the production card schema and effect DSL

What did not work (registered in `docs/tech-debt-register.md` and driving the production rewrite):

- The match engine does not run as written: `player_controller.gd` and `minion.gd` call
  `GameManager` functions that do not exist (`register_minion_on_board`, `is_valid_attack_target`,
  `get_card_cost`, `damage_hero`); `add_minion_to_board` is never called, so the board model is
  always empty and Taunt, Affinity, Conduit and death checks cannot work.
- No card effect is implemented: `CardEffectBase` is never subclassed or invoked, Last Words is a
  `print`, synergy hooks are empty stubs.
- Rules live in the scene tree (`Minion` Control nodes own state) and the UI mutates game state
  (`card_ui.gd` decides playability; the AI plays by moving UI nodes), so nothing is unit-testable.
- `game_manager.gd` (1,144 lines) is a god object holding match rules, combat, run state as
  untyped `set_meta` keys, and synergy logic.
- Card data is broken: the 35 themed `.tres` cards have no `id`, `card_type`, keywords or rarity;
  starter decks reference card ids that do not exist; the match falls back to generated test minions.
- Unseeded randomness everywhere; two scripts reference a scene that does not exist; no tests.
- The week-runner, schedule builder, shop, aspects and factions are text or stubs and are not part of
  the Dungeon Run loop. They are dropped.

Content inventory for reference: 22 BASE placeholder cards, 35 themed cards across War, Knowledge,
Decay, Fortune, Order, Shadow and Neutral, 7 starter deck lists (2 empty), 2 factions, 6 aspects,
no bosses.
