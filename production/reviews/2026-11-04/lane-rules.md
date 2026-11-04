## Common rules for every sprint-2 lane (read fully before starting)

You are implementing a chain of stories in a git worktree of /home/user/dungeon-run-ccg (Claude Code Game Studios project; Godot 4.7.2 GDScript at `godot` on PATH; gdUnit4 6.2.3 in `addons/gdUnit4`; workflow standard — match-rules and card-effects at `full`; review lean; qa.level standard; stage Pre-Production; sprint 2 plan `production/sprints/sprint-002.md`, QA plan `production/qa/qa-plan-sprint-002-2026-11-03.md`). The owner (Jacob) gave standing approval and asked for continuous commits: do not ask questions, do not use AskUserQuestion; where a procedure says "ask", treat it as yes.

**Procedure per story, in the order given.** `/dev-story` and `/story-done` cannot be model-invoked, so read `.claude/skills/dev-story/SKILL.md` (+ `references/`) once and follow it by hand per story, acting as the programmer agent yourself (no agent spawning). Read the story file, its governing ADRs by section (several carry dated 2026-11-03 errata in their Status block — read those), the control manifest by layer (`docs/architecture/control-manifest.md`, by section), the GDD sections the story cites (large GDDs: Grep `^#` then Read offset/limit — never a whole-file read of a doc over 40 KB; `validate-read.sh` refuses it), `docs/engine-reference/godot/current-best-practices.md` (your training predates Godot 4.5–4.7; it records observed 4.7.2 pitfalls: bare calls to global-named methods resolve to `@GlobalScope` — call through `self.`; an autoload script must not declare a `class_name` equal to its autoload name; JSON parse error lines are 0-based), the matching `.claude/rules/*.md`, `src/CLAUDE.md`, `tests/README.md`, and the existing code you build on (read it before changing it). Tests first where the story allows; every new test must be seen failing against missing or broken code before it passes. **No wall-clock assertions** in the blocking suite (coding standards). Unit tests do no file I/O except reading committed fixtures.

After each story: run `godot --headless --path . --import`, the full suite exactly as `project.yaml` `commands.test` gives it, and `commands.smoke` (`godot --headless --quit-after 5`), all from the worktree root; require exit 0 and no new SCRIPT ERROR beyond intentional negative-test ones. Then close the story per `.claude/skills/story-done/SKILL.md` read by hand (Status, Last Updated, Files, Completion Notes, and its own `production/sprint-status.yaml` entry). **Record the story's start and end time (UTC, from `date -u`) in its Completion Notes** (retro action 5). Lean-skipped gates are skipped; agent-requiring gates are NOT ASSESSED. If a story is blocked by a missing dependency you cannot stub per the story's own allowance, stop the chain there, leave it Ready with a dated blocker note, and report.

**Commits.** One commit per story on the lane branch named below, Conventional Commits (`feat(<area>): …` / `test(…)` / `ci: …`), body `Story: <epic>/story-NNN`, each ending with:
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01A6qc8RpcdRDuUYNFS7dCHV
Use `git -c user.name="Jacob" -c user.email="jseyfried7@gmail.com" commit`. Include the regenerated `.godot/global_script_class_cache.cfg` (tracked on purpose) and every new `.uid` file. Do not push. Touch only your stories' scope, their story files, their own `production/sprint-status.yaml` entries, and the shared files your stories name. Other lanes run in parallel on other epics; the orchestrator merges lanes one at a time.

**Final message (under 350 words):** branch, one line per story (commit hash, start–end UTC, tests added), the final test result line and smoke exit code, every deviation from a story or ADR, and anything left open.

## Lane hygiene (orchestrator, 2026-11-03)
- Lanes share one session scratchpad: name every scratch file with the lane prefix (`mr_`, `rng_`, `cdb_`, `bai_`, `ce_`, `boot_`) — a shared `mutate.py` was overwritten mid-run on 2026-11-03.

## Sprint-3 rules (orchestrator, 2026-11-03)
- **`src/core/boot.gd` `_collect_validators()` / `PENDING_CONFIG_OWNERS` belong to the orchestrator.** Do not edit them. If your story ships a validator that Boot must register, expose it as a `static func`, test it directly, and state the exact registration line in your final message; the orchestrator adds it at merge.
- Pending config validators now emit `W_VALIDATOR_PENDING` (a warning in debug builds, an error in exported builds). Tests that load fixtures should assert on error severity, not on an empty report.
- `RngService.stream()` accepts root names only (`^[a-z]+(_[0-9]+)?$`); forked streams come only from `fork()` and are keyed by parent + label (ADR-0003 erratum 2026-11-03).
- When diagnosing a failure, run the suite with `-c` (continue) so every failing test shows; the plain `commands.test` stops each suite at its first failure.
- Sprint 3 plan: `production/sprints/sprint-003.md`; QA plan: `production/qa/qa-plan-sprint-003-2026-11-03.md`.

## Sprint-4 rules (orchestrator, 2026-11-04) — these override the sprint-2/3 paths above
- Sprint 4 plan: `production/sprints/sprint-004.md` (read § Lanes, § Readiness notes, and your stories' rows). QA plan: `production/qa/qa-plan-sprint-004-2026-11-04.md` — being written in parallel; if it is not on your branch, work from the story ACs.
- Run `/story-readiness` by hand (`.claude/skills/story-readiness/SKILL.md`) on each story before implementing it; record the verdict in the story file. A NOT READY you can resolve from the docs, resolve and note it; otherwise stop the chain.
- Shared test helpers (`tests/helpers/*`, `test_effect_resolver.gd`, `match_factory.gd`, `test_constants.gd`): keep edits additive (new functions, new constants) — never rename or change an existing helper's behaviour; two lanes edit some of them and the orchestrator merges by hand.
- Scratch-file prefixes this sprint: `l1_` … `l7_`, `qa4_`.
- **Committer identity (2026-11-04, repo hook):** keep Jacob as author but make Claude the committer, or GitHub shows the commit Unverified: `GIT_COMMITTER_NAME=Claude GIT_COMMITTER_EMAIL=noreply@anthropic.com git -c user.name="Jacob" -c user.email="jseyfried7@gmail.com" commit …`.

## Sprint-5 rules (orchestrator, 2026-11-04) — override earlier sprint paths
- Plan `production/sprints/sprint-005.md` (§ Lanes, merge order, "Where the shared files fall", Readiness notes, your stories' rows). QA plan `production/qa/qa-plan-sprint-005-2026-11-04.md` is being written in parallel — use story ACs if absent.
- Decisions DD-X15…X25 in `design/design-decisions.md`; control manifest version 2026-11-04 (`docs/architecture/control-manifest.md`). Commit as Jacob (author) / Claude (committer) — see the committer rule above.
- Before your first commit, `git merge bootstrap/ccgs-template` if your HEAD lacks "prod(sprint): sprint 5 plan".
- `src/core/boot.gd` registration lines stay orchestrator-owned: state the exact line in your final message.
- Scratch prefixes this sprint: `s5l1_` … `s5l8_`, `s5qa_`.
