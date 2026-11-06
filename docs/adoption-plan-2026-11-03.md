# Adoption Plan

> **Generated**: 2026-11-03
> **Project phase**: Concept (`project.stage: Concept` in `project.yaml`; `production/stage.txt` mirrors it)
> **Engine**: Godot 4.7.2 / GDScript / Forward+ / Godot Physics 2D (`project.yaml` `engine:` block, written by `/setup-engine` during this audit; installed binary probed as 4.7.2 stable in `docs/engine-reference/godot/VERSION.md`)
> **Template version**: v1.2.0 (`framework.version`, last upgraded 2026-10-19)
> **Workflow tier**: `standard` (from `modes.rigor: standard`) · **Automation**: `guided` · **Review mode**: resolves to `lean` from `modes.rigor` (nothing pins it — do not pin it)

Work through these steps in order. Check off each item as you complete it.
Re-run `/adopt` anytime to check remaining gaps.

---

## Audit Summary

```
## Adoption Audit Summary
Phase detected: Concept
Engine: configured (project.yaml engine.* + .claude/docs/technical-preferences.md)
GDDs audited: 0 (design/gdd/ does not exist)
ADRs audited: 0 (docs/architecture/ holds only the empty tr-registry.yaml)
Stories audited: 0 (production/epics/ does not exist)
UX specs: 0 (design/ux/ does not exist)

Gap counts:
  BLOCKING: 0 — nothing malformed; no v1.0 migration needed
  HIGH:     2 — the pipeline cannot start until these exist
  MEDIUM:   3 — tracking/infrastructure files the pipeline creates later
  LOW:      5 — housekeeping and config completions

Estimated remediation: 0 blocking items. The HIGH items are pipeline steps,
not repairs — roughly 1 session (/brainstorm) unblocks everything downstream.
```

**What this project is.** The CCGS v1.2.0 template dropped onto a fresh Godot 4.7
project. `/start` has already run (stage, rigor, automation set) and `/setup-engine`
has pinned the engine. The only prior work is a concluded, read-only prototype at
`prototypes/hearthstone-clone-2026-01/` (Godot 4.5, ~11.6k lines, `.gdignore` in
place so the root project does not import it). Its `README.md` records a clear
verdict: the match engine never ran, nothing was unit-testable, card data was
broken; salvage is *vocabulary and UI patterns only, rewritten — never imported*.
There are no GDDs, ADRs, stories, sprints or UX specs to migrate, so this plan is a
**bootstrap sequence**, not a repair list.

### What was checked and found compliant

| Check | Result |
|---|---|
| v1.0 migration (`migrate-v1-config.sh --dry-run`) | `Nothing to do: project.yaml exists and the legacy files mirror it (values agree).` Exit 0 — not a v1.0 project. |
| Stage file | `project.yaml` `project.stage: Concept` and `production/stage.txt` = `Concept` — agree. |
| Engine config (2f) | `engine.name/version/language/rendering/physics` all set in `project.yaml`; `technical-preferences.md` mirrors them with platform, input, naming, specialists and gdUnit4 v6.2.3. `CLAUDE.md` Technology Stack updated. |
| Engine reference | `docs/engine-reference/godot/VERSION.md` present, pinned 4.7, "Installed at pin time" now records 4.7.2 (probe 2026-11-03). `CLAUDE.md` imports it. |
| TR registry | `docs/architecture/tr-registry.yaml` present, valid layout, `requirements: []` — correct for a project with no GDDs. `/architecture-review` appends to it. |
| Entity / architecture registries | `design/registry/entities.yaml`, `docs/registry/architecture.yaml` present and empty — correct. |
| Code root | `src/` (Godot row of `directory-structure.md`), empty except `CLAUDE.md`/`.gitkeep` — correct. |
| GDD structure script | `gdd-structure-check.sh design/gdd/game-concept.md` → `Not found` (discovery result confirming zero GDDs; not a format gap). |
| Prototype isolation | `.gdignore` present; prototype folder is outside `src/`; `**/.godot/*` ignored in `.gitignore`. |

---

## Step 1: Fix Blocking Gaps

None. No artifact is in a format that would make a template skill silently
misbehave, and no legacy config needs converting.

---

## Step 2: Fix High-Priority Gaps

### 2a. No game concept document — the standard-tier pipeline cannot start
**Problem**: `design/gdd/game-concept.md` does not exist. At `workflow: standard`
`/map-systems`, `/design-system`, `/create-architecture`, `/architecture-decision`,
`/ux-design` and `/art-bible` all read it, and the Concept → Systems Design gate
requires it. Until it exists, every downstream skill either stops or guesses.
**Fix**: Run `/brainstorm`. Feed it the pitch already in `README.md` (single-player
roguelike CCG: pick a hero, eight escalating AI bosses, draft one of three bundles
or a treasure after each win, permadeath per run, meta-unlocks) and the prototype
findings in `prototypes/hearthstone-clone-2026-01/README.md` as the pivot
evidence (the week/schedule/shop/faction loop is dropped; the Dungeon Run loop is
the direction). Make sure the output carries pillars, the core loop at all four
horizons, anti-pillars and a Visual Identity Anchor (the gate recommends it at
`standard`).
**Time**: 1 session
- [ ] `design/gdd/game-concept.md` written with pillars, core loop, anti-pillars
- [ ] Optional: `/design-review design/gdd/game-concept.md`

### 2b. No control manifest
**Problem**: `docs/architecture/control-manifest.md` (with its `Manifest Version:`
stamp) does not exist, so `/create-stories` has no layer rules to embed and
`/story-done` has nothing to check staleness against.
**Why it is sequenced, not fixed now**: the manifest is generated from *accepted
ADRs* and there are none yet. Creating it before Step 3f would produce an empty
sheet. It is resolved at Step 3g below.
**Fix**: `/create-control-manifest` — after the ADRs are Accepted and
`/architecture-review` has run.
**Time**: 30 min (when its turn comes)
- [ ] `docs/architecture/control-manifest.md` created with a `Manifest Version:` stamp

---

## Step 3: Bootstrap Infrastructure (the standard-rigor pipeline, in order)

The template's generic 3a–3d bootstrap (`/architecture-review` → manifest →
`/sprint-plan update` → `/gate-check`) assumes GDDs and ADRs exist. Here nothing
exists, so the bootstrap *is* the pipeline. Run it in this order; each step's
output is the next step's input. Gates are listed where they write
`project.stage` — at Concept itself there is no gate to run.

### 3a. Concept → `/brainstorm` (Step 2a above)
Writes `design/gdd/game-concept.md`.
- [ ] Done (see 2a)

### 3b. Concept prototype — already concluded, decide whether to re-run
The Concept → Systems Design gate asks for a `prototypes/*/REPORT.md` with a
PROCEED verdict from `/prototype`. The archived Hearthstone clone has a `README.md`
with findings but no `REPORT.md`, and its verdict was effectively PIVOT (loop
dropped, engine rewritten). Two options when you reach the gate:
- Run `/prototype [core mechanic]` for the *new* loop (bundle-draft-after-boss
  pacing is the untested hypothesis) — recommended, 1 day max; or
- Accept the gate's CONCERNS on this item, citing the archived prototype's
  findings, and move on.
- [ ] Decision recorded (prototype re-run or CONCERNS accepted)

### 3c. `/map-systems` → `design/gdd/systems-index.md`
Decomposes the concept into systems with Layer / Priority / Status columns.
Expected systems from the README and prototype vocabulary: card schema and
effect DSL, match engine (turn/board/combat rules), keywords, hero system,
boss AI, run structure (eight-boss chain), bundle and treasure draft, meta
progression and unlocks, card/hero/boss data pipeline (JSON under
`assets/data/`), match UI/HUD, run-map UI.
**Keep Status cells to the exact values** `Not Started`, `In Progress`,
`In Review`, `Designed`, `Approved`, `Needs Revision` — no parentheticals, or
`/gate-check`, `/create-stories` and `/architecture-review` break.
**Time**: 30 min – 1 session
- [ ] `design/gdd/systems-index.md` created; Status column uses exact values only

### 3d. `/gate-check systems-design`
First gate. Writes `project.stage: Systems Design` to `project.yaml` and
`production/stage.txt` on PASS (or accepted CONCERNS).
- [ ] Stage advanced to Systems Design

### 3e. `/design-system [system]` for each MVP system, then `/design-review`, then `/review-all-gdds`
At `standard` each GDD needs **Overview, Detailed Rules (or Detailed Design), Edge
Cases, Dependencies, Acceptance Criteria**, plus **Formulas** for any system that
defines numeric rules (damage, costs, draft weights, boss scaling, unlock
thresholds — most of this game's systems will). Player Fantasy and Tuning Knobs
are advisory. `/design-system` also registers cross-system facts in
`design/registry/entities.yaml`. Use the prototype's `card_data.gd` field list,
`keywords.gd` and `card_effect_base.gd` helper names as *vocabulary input* to the
card-schema GDD; do not copy rules from it (mulligan drew 10 kept 5, etc.).
Verify each with `bash .claude/scripts/gdd-structure-check.sh design/gdd/<file>.md`
and `/design-review`; finish with `/review-all-gdds`.
**Time**: 1 session per system
- [ ] All MVP GDDs authored with the 5 required sections (+ Formulas where numeric)
- [ ] Each GDD `> **Status**:` set to a valid value (`Draft` … `Approved`)
- [ ] `/review-all-gdds` report exists in `design/gdd/` with a non-FAIL verdict

### 3f. `/gate-check technical-setup`
Writes `project.stage: Technical Setup`.
- [ ] Stage advanced to Technical Setup

### 3g. Architecture: `/create-architecture` → `/architecture-decision` (×N) → `/architecture-review` → `/create-control-manifest`
1. `/create-architecture` — master architecture doc; validates against the Godot
   4.7 pin and flags post-cutoff API gaps. The prototype's failure modes are the
   anti-requirements: rules must not live in the scene tree, UI must not mutate
   game state, no god-object autoload, seeded RNG, data-driven cards.
2. `/architecture-decision` — one ADR per *critical* decision (standard tier
   requires only critical ADRs; when in doubt treat as critical). Each ADR must
   carry `## Status` (`Proposed` → `Accepted`), `## ADR Dependencies`,
   `## Engine Compatibility`, `## GDD Requirements Addressed`. Stories against a
   `Proposed` ADR are auto-blocked, so move them to `Accepted`.
3. `/architecture-review` — traceability matrix; **appends TR-IDs to
   `docs/architecture/tr-registry.yaml`** and writes
   `docs/architecture/requirements-traceability.md`.
4. `/create-control-manifest` — resolves gap 2b.
**Time**: 1 session for the architecture doc, 30 min per ADR, 1 session review
- [ ] `docs/architecture/` master architecture document
- [ ] Critical ADRs Accepted, all required sections present
- [ ] `tr-registry.yaml` holds real entries (remove the example comment block)
- [ ] `docs/architecture/requirements-traceability.md` written
- [ ] `docs/architecture/control-manifest.md` with `Manifest Version:`

### 3h. `/test-setup`
Scaffolds `tests/unit/`, `tests/integration/`, the gdUnit4 runner wiring and a
GitHub Actions workflow (`.github/workflows/` does not exist yet). `commands.test`
in `project.yaml` already holds the headless gdUnit4 command; `/test-setup` should
reuse it. Follow with `/test-helpers` once the first system has code.
**Time**: 30 min
- [ ] `tests/` directory and CI workflow exist; headless run passes on an empty suite

### 3i. `/ux-design [screen]` + `/ux-review`, and `/ux-design accessibility`
Specs for the screens the stories will need — at minimum main menu, hero select,
match HUD/board, bundle-or-treasure reward draft, run map, run summary. The input
profile is already in `technical-preferences.md` (mouse-first, keyboard
reachable, gamepad partial, 1280x720). The prototype's `card_ui.gd` hand fan,
`targeting_arrow.gd` and `discover_selection.gd` are the interaction patterns worth
describing in the pattern library (`/ux-design patterns`).
**Time**: 30 min per screen
- [ ] `design/ux/` specs for the MVP screens, each `/ux-review` APPROVED
- [ ] Accessibility requirements doc

### 3j. `/gate-check pre-production`
Writes `project.stage: Pre-Production`.
- [ ] Stage advanced to Pre-Production

### 3k. `/create-epics` → `/create-stories [epic]` → `/story-readiness`
One epic per architectural module; stories embed TR-IDs, ADR references and the
manifest version automatically because Step 3g ran first.
**Time**: 1 session for epics, 1 session per epic for stories
- [ ] `production/epics/*/EPIC.md`
- [ ] Stories with `Manifest Version:`, TR-IDs, ADR refs, `- [ ]` acceptance criteria

### 3l. `/sprint-plan` → creates `production/sprint-status.yaml`
First sprint from the readiness-checked stories. This resolves gap 4a.
**Time**: 30 min
- [ ] `production/sprints/sprint-001.md` and `production/sprint-status.yaml`

### 3m. `/vertical-slice`, then `/gate-check production`
End-to-end slice (one hero, one boss chain segment, one draft) before committing
to Production. The gate writes `project.stage: Production`.
- [ ] Vertical slice report PROCEED
- [ ] Stage advanced to Production

---

## Step 4: Medium-Priority Gaps

### 4a. No `production/sprint-status.yaml`
**Problem**: `/sprint-status` falls back to markdown parsing until this exists.
**Fix**: created by `/sprint-plan` at Step 3l. Do not hand-create it earlier — there
are no stories to track.
**Time**: 0 (by-product)
- [ ] Resolved by 3l

### 4b. No `docs/architecture/requirements-traceability.md`
**Problem**: no persistent GDD → ADR matrix.
**Fix**: written by `/architecture-review` at Step 3g.
**Time**: 0 (by-product)
- [ ] Resolved by 3g

### 4c. No `tests/` directory and no CI workflow
**Problem**: coding standards require the suite to run on every push/PR as a
blocking gate; nothing is wired. gdUnit4 v6.2.3 is installed and enabled in
`project.godot`, so only the scaffold and workflow are missing.
**Fix**: `/test-setup` at Step 3h.
**Time**: 30 min
- [ ] Resolved by 3h

---

## Step 5: Optional Improvements

### 5a. Performance budgets partly configured
`technical-preferences.md` has 60 fps / 16.6 ms (setup-engine defaults); Draw
Calls and Memory Ceiling are `[TO BE CONFIGURED]` and `project.yaml` has no
`performance:` block. Set them when target hardware is decided, ideally in the
performance-targets ADR, with `/settings performance.<key>=<value>`.
**Time**: 5 min
- [ ] Draw-call and memory budgets recorded

### 5b. `commands.build` is `[TO BE CONFIGURED]`
No `export_presets.cfg` exists yet, so there is no preset to name. Once a
Windows Desktop preset exists: `/settings commands.build="godot --headless --export-debug 'Windows Desktop'"`.
**Time**: 5 min (after the first export preset)
- [ ] Build command set

### 5c. Forbidden Patterns / Allowed Libraries empty (by design — but seed them)
In `.claude/docs/technical-preferences.md` (these two lists are not migrated to
`project.yaml`): add **gdUnit4 v6.2.3** under Allowed Libraries now. When the
architecture ADRs land, promote the prototype's documented failure modes to
Forbidden Patterns and `docs/registry/architecture.yaml` `forbidden_patterns`:
game rules in scene-tree nodes, UI code mutating match state, god-object autoload
holding rules + run state as `set_meta` keys, unseeded randomness in gameplay.
**Time**: 5 min now, 30 min with the ADRs
- [ ] gdUnit4 listed as an allowed addon
- [ ] Forbidden patterns registered once the first ADR bans them

### 5d. Prototype README points at files that do not exist yet
`prototypes/hearthstone-clone-2026-01/README.md` says its failures are
"registered in `docs/tech-debt-register.md`" and that it is "superseded by
`design/gdd/`" — neither exists yet. Either run `/tech-debt` to create the register
and carry the seven failure items into it, or soften the README wording. The
prototype itself stays read-only.
**Time**: 30 min (`/tech-debt`) or 5 min (wording)
- [ ] Register exists or README wording corrected

### 5e. Root `README.md` status line disagrees with the stage
README says "Status: pre-production (see `production/stage.txt`)" while the stage
is `Concept`, and its layout table lists `assets/data/` and `tests/` that do not
exist yet. Harmless, but fix the status line when the first gate passes, or point
it at `project.yaml` `project.stage`.
**Time**: 5 min
- [ ] README status line matches `project.stage`

---

## What to Expect from Existing Stories

There are no existing stories, sprints, GDDs or ADRs — nothing to preserve and
nothing to regenerate. Everything produced by Step 3 will be in template-native
format from the start (TR-IDs, ADR references, manifest version stamps), so the
staleness checks in `/story-readiness` and `/story-done` work from the first
story.

The archived prototype is **not** a migration source. Per its own README, the
salvage is vocabulary (card fields, keyword list, effect helper names) and UI
interaction patterns, to be rewritten to production standards — never imported.
Do not run `/reverse-document` against it to manufacture GDDs or ADRs; the
production design starts from `/brainstorm`.

---

## Decisions taken (guided automation, no prompts available in this run)

1. Treated the project as "template adopted, prototype archived, pipeline not
   started" rather than offering `/start` (it has already run: stage, rigor and
   automation are set).
2. Audit scope `full`; tier `standard` applied to severity (5 required GDD
   sections + conditional Formulas; critical ADRs only).
3. Infra absences that can only be produced by a later pipeline step (control
   manifest, sprint-status, traceability matrix) are kept at the audit table's
   severity but marked "resolved by step N" instead of being presented as
   repairs.
4. `/setup-engine` was running concurrently; `project.yaml`, `CLAUDE.md` and
   `technical-preferences.md` were read, never written. Engine config is
   reported as it stood at the end of the audit (configured).
5. No review mode written (`modes.review_mode` would pin the rigor expansion);
   it resolves to `lean`.
6. Wrote this file as pre-approved; no other file created or modified; no commit.

---

## Re-run

Run `/adopt` again after Step 3g (architecture) and again after Step 3l (first
sprint) to confirm the TR registry, control manifest, traceability matrix and
sprint-status files are present and in the expected format. Each run reflects the
current state of the project; it does not diff against this plan.
