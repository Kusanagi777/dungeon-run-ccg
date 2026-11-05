# Match UI fixtures

One file format for capture evidence and `tests/integration/match_ui/` (ADR-0009
Decision 4). `MatchDebugLoader` runs the real engine through a fixture; the view then
projects `events_since(0)`. A fixture never holds a view-state, so a frame can never
show a state the rules cannot reach.

```json
{
  "config": {"hero": "hero_war", "boss": "boss_torchbearer", "seed": 1, "floor": 1, "band": 1, "treasures": []},
  "profile": {},
  "commands": [{"type": "mulligan", "keep_mask": [true, true, true]}]
}
```

- `config`: the `MatchConfig` inputs. Optional, for a state the shipped lists cannot
  reach quickly: `player_deck`, `boss_deck` (card id lists), `boss_health`,
  `max_events` (the log cap, which is how `match_end_fault` reaches a fault).
- `profile`: settings applied before the match, as `MetaApi.set_setting` keys.
- `commands`: run in order, and the loader ticks the planner to rest after each.
  An entry is a C2 command's fields, or a macro that expands against the live
  `legal_commands()`:
  - `{"macro": "end_turns", "count": n}`: end the turn n times.
  - `{"macro": "play_all", "keep_mana": m}`: play every legal card, last position,
    until the mana falls to m (default 0).
  - `{"macro": "attack_face"}`: every legal attack, at the boss hero when it can.
  - `{"macro": "aggro_to_end"}`: `play_all`, `attack_face`, `end_turn`, until the match ends.

Launch: `godot --path . res://src/ui/match/match_view.tscn -- --fixture=<name>`, or from an
exported debug build `deckdelve-debug.exe -- --fixture=<name>`.
