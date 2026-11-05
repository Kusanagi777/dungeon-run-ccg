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
- `profile`: settings for this launch only, as `MetaApi.set_setting` keys. The loader
  restores them once the driver has its snapshot, so they never reach the saved profile.
- `pose`: optional, a U11 pose used when the launch names none. `match_end_both_dead`
  needs it: no shipped card kills both heroes in one action, so it ends on a real
  defeat and reads as `end:both_dead` (story 011's allowed fallback).
- `commands`: run in order, and the loader ticks the planner to rest after each.
  An entry is a C2 command's fields, or a macro that expands against the live
  `legal_commands()`:
  - `{"macro": "end_turns", "count": n}`: end the turn n times.
  - `{"macro": "play_all", "keep_mana": m}`: play every legal card, last position,
    until the mana falls to m (default 0).
  - `{"macro": "play_and_pass", "count": n}`: `play_all`, then end the turn, n times.
  - `{"macro": "attack_face"}`: every legal attack, at the boss hero when it can.
  - `{"macro": "aggro_to_end"}`: `play_all`, `attack_face`, `end_turn`, until the match ends.

`<name>_ts150` is `<name>` with the profile `text_scale = 1.5` (U11 settings variants).
`boss_intent_hidden` uses `telegraph_mode: off`: no shipped boss has `intent_mode: hidden`.

Mid-step frames: `--pause-at=<seq>` holds every step after `seq`, freezes halfway through
a step of `seq`, and leaves any later turn unprojected. The boss turns of
`boss_turn_playback` start at `seq` 203 (turn 10); `divine_shield_hit` pops at `seq` 131.

Launch: `godot --path . res://src/ui/match/match_view.tscn -- --fixture=<name>`, or from an
exported debug build `deckdelve-debug.exe -- --fixture=<name>`.
