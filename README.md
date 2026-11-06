# Dungeon Run CCG

A single-player roguelike collectible card game inspired by Hearthstone's retired Dungeon Run mode.
Pick a hero, fight a chain of eight escalating AI bosses, and after each win choose one of three card
bundles or a passive treasure. Lose once and the run is over. Meta progression unlocks new heroes,
cards and treasures across runs.

- **Engine:** Godot 4.7 (GDScript), tests with gdUnit4
- **Platform:** Windows desktop, mouse-driven, 1280x720
- **Status:** pre-production (see `production/stage.txt`)

## Repository layout

| Path | What |
|---|---|
| `src/` | Game code: `core/` (foundation), `gameplay/` (pure rules), `ai/` (boss AI), `ui/` (display-only), `scenes/` |
| `assets/data/` | Card, boss, hero, treasure and bundle definitions (JSON) |
| `tests/` | gdUnit4 unit, integration and smoke tests |
| `design/`, `docs/`, `production/` | Design docs, architecture decisions, sprint and QA tracking |
| `prototypes/hearthstone-clone-2026-01/` | The original Hearthstone-clone prototype, archived read-only |
| `tools/setup.sh` | Installs the Godot binary and gdUnit4 for a fresh machine or CI |

## Getting started

```bash
bash tools/setup.sh          # installs Godot 4.7.2 to ~/.local and gdUnit4 into addons/
godot --headless --path . --import
```

## Studio tooling

This project is built with the [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)
template (v1.2.0, MIT). Its agents, skills, hooks and rules live under `.claude/`; `project.yaml` is the
single source of truth for engine and process settings. See `docs/WORKFLOW-GUIDE.md` for the workflow
and `UPGRADING.md` for template upgrades.

## License

MIT. See `LICENSE`.
