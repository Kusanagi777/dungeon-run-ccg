# Smoke Test: Critical Paths

**Purpose**: Run these 10-15 checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches without crash — `timeout 30 godot --headless --quit-after 5`
   (`commands.smoke`) exits 0 with no `SCRIPT ERROR`; it launches
   `run/main_scene` = `res://src/scenes/boot.tscn` (boot screen until a main
   menu exists)
2. New game / session can be started from the main menu
3. Main menu responds to all inputs without freezing

## Core Mechanic (update per sprint)

<!-- Add the primary mechanic for each sprint here as it is implemented -->
<!-- Example: "Player can move, jump, and the camera follows correctly" -->
4. [Primary mechanic — update when first core system is implemented]

## Data Integrity

5. Save game completes without error (once save system is implemented)
6. Load game restores correct state (once load system is implemented)
6a. Exported build prints a non-empty `data_version()` -- `deckdelve.exe --headless -- --print-data-version` exits 0 and prints the 16 hex digits the editor build prints for the same files (card-database story 010)

## Performance

7. No visible frame rate drops on target hardware (60fps target)
8. No memory growth over 5 minutes of play (once core loop is implemented)
