# ADR-0010: Renderer Choice vs Xvfb Screenshot Capture

## Status

Accepted

> **Who may move this to `Accepted`: the user, or `technical-director` on the
> user's explicit confirmation. No other agent, and no skill on its own.**
> Stories referencing a `Proposed` ADR are set `Blocked`, and epics require
> `Accepted`, so the field needs a named owner. `technical-director` is the role
> `coordination-rules.md` already escalates technical conflicts to, and an ADR is
> that decision made durable. This does **not** relax the rule that
> `Status: Accepted` is never set without explicit user confirmation.

Review record for this run (2026-11-03, `/architecture-decision`, headless, no
`AskUserQuestion` answerer):

- TD-ADR skipped — Lean mode (`review_mode: lean`; TD-ADR is not a PHASE-GATE).
- Engine validation: **NOT ASSESSED** — `godot-specialist` was not spawned (no
  `Agent` tool in this run). Renderer facts are sourced from
  `docs/engine-reference/godot/modules/rendering.md`; the capture facts are
  observed in `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe C
  and the rig check `production/qa/evidence/rig-check-2026-11-03/`; the rest is
  `NOT SOURCEABLE` with the test that will prove it.
- GDD sync: checked 3 referenced GDDs (`match-ui.md` U11, `run-ui.md` U10,
  `game-concept.md` Technical Risks); no naming inconsistencies — the launch
  arguments (`--fixture`, `--pose`, `--pause-at`, `--anim-speed`, `--ai-debug`,
  `--run-ui-screen`, `--run-ui-fixture`) and fixture paths are quoted verbatim.
  One **documented divergence** (not a rename): match-ui U11's example launch
  line omits `xvfb-run` and `--rendering-driver opengl3`; this ADR's wrapper
  adds them on Linux. The GDD line stays correct on a desktop with a display.
- Numbering per `design/design-decisions.md` DD-X08 (0005+ in gate-check
  order; `docs/architecture/architecture.md` §Required ADRs assigns 0010).
- **TD review 2026-11-03 (acceptance pass over ADR-0001..0011):** no change;
  consistent with ADR-0009 Verification (4) and ADR-0011's launch arguments.
- **Accepted 2026-11-03 by technical-director** on the owner's standing approval of the project plan (plan approved 2026-11-03; "accept each" step). Owner may revert to Proposed.
- **Erratum 2026-11-05 (DD-X32, boot-composition-root story 011)**: Decision 5's "until a Windows capture rig exists (Open point)" is closed. A Windows frame from `tools/capture.sh`, in Forward+ (the default) or with `CAPTURE_RENDERER=opengl3`, counts as BLOCKING UI evidence, as the Linux CI PNG does, and each records its renderer in a `<name>.renderer.txt` sidecar beside the PNG (OS, exact Godot arguments, the engine's startup renderer lines); the reviewer says which renderer it is. Decision 4's frame rules and the no-`--headless` rule apply unchanged, and Decisions 1, 2 and 6 do not change: Forward+ still ships and Linux evidence is still Compatibility on llvmpipe through `tools/capture.sh`. The per-UI-story Windows playtest row stays, because an `opengl3` frame or a Linux PNG is no proof of Forward+ output. The control manifest gains the Windows form at the next `/create-control-manifest update`.

## Date

2026-11-03

## Last Verified

2026-11-03 — against Godot 4.7.2, Probe C (this container: Xvfb 21.1.12, Mesa
25.2.8 llvmpipe, no Vulkan ICD), `tools/capture.sh` and the rig check. Re-verify
when the CI image, the Godot build or the project's renderer setting changes.

## Decision Makers

Jacob (owner, standing approval for the Foundation ADR set); authored by the
`/architecture-decision` run; `technical-director` acceptance pending. This is
the carry-forward from the Technical Setup gate (exit criterion 3: a proven
screenshot into `production/qa/evidence/`).

## Summary

Coding standards require a retained screenshot for every Visual/UI story, the
Linux CI runner has no GPU, no display and no Vulkan driver, and the project
ships Forward+ on Windows. This ADR keeps **Forward+ for the shipped Windows
build** and captures evidence under `xvfb-run` with `--rendering-driver opengl3`
(the Compatibility renderer on llvmpipe) through `tools/capture.sh`, taking the
last Movie-Maker frame at the project viewport size. It records that CI evidence
therefore shows the Compatibility path, requires each UI story's Windows look to
be confirmed at playtest, and binds v1's 2D UI to the renderer-neutral subset
(no Forward+-only effects) so the two paths stay equivalent.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.2 (pinned 4.7; `docs/engine-reference/godot/VERSION.md`) |
| **Domain** | Rendering |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH (Rendering 4.5–4.7 is post-cutoff, VERSION.md); the renderer names, the D3D12 default on Windows and the 4.7 `CanvasItem` line change are **sourced**; Forward+ under Xvfb, `--write-movie` flags and the Vulkan→GL fallback are **NOT SOURCEABLE** from the reference and **observed** in Probe C. |
| **References Consulted** | `VERSION.md`; `modules/rendering.md` (§Rendering Backend Selection 4.6, §4.7 Changes); `breaking-changes.md` (4.6→4.7 Rendering rows; 4.5→4.6 D3D12; Project stretch defaults); `current-best-practices.md` (§Rendering 4.7/4.6, §UI and Input 4.7, §Command Line); `deprecated-apis.md`; `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe C; `.claude/docs/run-and-observe.md` § Godot 4; `tools/capture.sh`; `production/qa/evidence/rig-check-2026-11-03/README.md` |
| **Post-Cutoff APIs Used** | None in code. Facts relied on: Forward+ / Mobile / Compatibility (OpenGL 3.3) selection (4.6, sourced); D3D12 default backend on Windows (4.6, sourced); `CanvasItem` lines drawn without the antialiasing feather in 4.7 (sourced) — widths must be set explicitly; new-project stretch defaults changed in 4.7 but this project keeps `canvas_items` / `keep` (`project.godot`, DD-T05). |
| **Verification Required** | (1) Capture under Xvfb with `--rendering-driver opengl3` writes 1280x720 non-blank PNGs, exit 0 — **observed** Probe C rows 2, 4, 6 and the rig check (`01-boot.png`, 473 distinct colours). (2) `--headless --write-movie` crashes (exit 134) — **observed**, never used. (3) Frames are viewport-sized, not `--resolution` — **observed** row 10. (4) Forward+ output parity on Windows for each UI story — **NOT SOURCEABLE**, per-story playtest confirmation (Decision 5). (5) lavapipe making Forward+ render under Xvfb — **NOT SOURCEABLE**, not pursued (Alternative 2). |

> Knowledge Risk HIGH: re-validate this ADR on an engine upgrade or a CI image
> change (a Vulkan ICD appearing on the runner changes which renderer the
> project setting selects — the explicit `--rendering-driver opengl3` flag is
> what keeps the evidence path stable).

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None. (ADR-0001 is not a prerequisite: the capture rig works on any launchable scene, and the rig check already ran against `res://src/scenes/boot.tscn`.) |
| **Enables** | ADR-0009 (Match UI scene partition and animation choices must stay within the renderer-neutral subset decided here); ADR-0011 (Run UI shell: same constraint; `--run-ui-screen` / `--run-ui-fixture` launches ride the same wrapper); every Visual/Feel and UI story (evidence gate) |
| **Blocks** | The test-rig completion story (gate exit criterion 3 — partially satisfied by the rig check, which this ADR makes policy); every UI story's Done gate (`/story-done` reads the retained PNG) |
| **Ordering Note** | Foundation, critical at `standard`: `/create-stories` stops without it, because no UI story can close without evidence. Write order 0001 → 0002 → 0003 → 0004 → **0010**. |

## Context

### Problem Statement

`.claude/docs/coding-standards.md` makes a retained screenshot in
`production/qa/evidence/` BLOCKING for Visual/Feel and UI stories ("a parse check
is not a run"), and `run-and-observe.md` fixes the Godot mechanism:
`--write-movie <path>.png --quit-after <N>` on a windowed launch, never
`--headless`. The project pins Forward+ (`project.godot`
`rendering/renderer/rendering_method="forward_plus"`; `project.yaml`
`engine.rendering: Forward+`), which on Windows runs on D3D12 (4.6 default,
sourced) and on Linux needs Vulkan. The CI container has no X display, no GPU
and no Vulkan ICD; game-concept Technical Risks flagged that "headless
screenshot evidence under Xvfb with Forward+ may need the Compatibility
renderer", and the Technical Setup gate carried the question forward. The ADR
must decide the shipped renderer, the capture renderer, whether they differ,
the exact launch line, the frame-selection rule, and what the difference means
for the evidence's validity.

### Current State

Probe C (2026-11-03) ran eleven variants. Under `xvfb-run` every display-backed
combination produced correct 1280x720 frames with exit 0, because 4.7.2 falls
back from Vulkan to OpenGL 3 when no ICD exists (project setting
`rendering/rendering_device/fallback_to_opengl3`, default on — key honoured, row
7); the explicit `--rendering-driver opengl3` form gave identical pixels with
no Vulkan error noise and 3x faster cold start (2.4 s vs 7.6 s). `--headless
--write-movie` crashed (exit 134, dummy rasterizer). `tools/capture.sh` wraps
the explicit command, keeps the last frame as `01-<scene>.png`, deletes the
rest and the `.wav`, and fails on a blank frame; the rig check captured
`boot.tscn` (473 colours, Compatibility/llvmpipe). No Windows capture has been
run; `commands.run` (`godot --path . --windowed --resolution 1280x720`) is the
desktop launch.

### Constraints

- Evidence must be retained on disk under `production/qa/evidence/<story-slug>/`
  and stamped (`review-receipts.sh hash`) — the procedure is fixed by
  `run-and-observe.md`; this ADR fixes only the Godot launch inside it.
- Linux CI: no display → `xvfb-run` mandatory (Probe C row 11); no Vulkan ICD →
  Forward+ cannot initialise without the fallback.
- `--headless` disables rendering; `--headless --write-movie` crashes (row 9).
- Frames record at the project viewport (1280x720, DD-T05), not `--resolution`.
- The shipped build is the Windows export (`export_presets.cfg`); the owner
  chose Forward+ (`project.yaml`); DD-T05 fixes `canvas_items` stretch.
- Fixture launches pass arguments after `--` (`OS.get_cmdline_user_args()`,
  match-ui U11, run-ui U10); the debug loaders are absent from release exports.
- Engine reference has no page for the command-line movie flags or the
  fallback setting; claims about them are observed, not sourced.

### Requirements

- Must produce a non-blank 1280x720 PNG of any launchable scene on the Linux
  CI image, unattended, exit 0, in seconds.
- Must keep the shipped Windows build on Forward+ (owner decision) unless this
  ADR is superseded.
- Must state which renderer the evidence shows and what that does and does not
  prove, so `/story-done` reviewers read it correctly.
- Must keep the match-ui U11 / run-ui U10 fixture seam the only way a
  screenshot reaches a game state (no hand-built view states).
- Must give UI/animation ADRs (0009, 0011) a rule that keeps both renderers
  equivalent for the 2D UI in v1.

## Decision

1. **Shipped renderer: Forward+** (`project.godot` unchanged; D3D12 on Windows,
   sourced). The project's 2D UI does not need Forward+ features in v1, but
   switching the shipped renderer is the owner's call recorded in
   `project.yaml`, and nothing observed argues against it; the decision here is
   about evidence, not about the product.
2. **Capture renderer: Compatibility (OpenGL 3) on llvmpipe under Xvfb, requested
   explicitly.** The one launch line for evidence on Linux/CI is
   ```
   xvfb-run -a -s "-screen 0 1280x720x24" \
     godot --path . --windowed --resolution 1280x720 --rendering-driver opengl3 \
     --write-movie <dir>/f.png --quit-after 60 res://<scene>.tscn [-- <fixture args>]
   ```
   (Probe C; `--fixed-fps` is implied by `--write-movie` and not passed;
   `--quit-after 60` is the frame count; the last frame `f00000059.png` is the
   evidence). The explicit flag is chosen over relying on the silent fallback so
   the evidence path does not change if a Vulkan ICD ever appears on the runner,
   and so logs carry no Vulkan errors a reader might mistake for a defect.
3. **Wrapper: `tools/capture.sh <scene-res-path> <out-dir> [frames] [-- <args>]`**
   is the only sanctioned way to produce evidence on Linux. It runs the line
   above, keeps the last frame as `<out-dir>/01-<scene-basename>.png` (the
   caller renames to `<NN>-<what-it-shows>.png` per `run-and-observe.md` when a
   story needs several), deletes the other frames and `f.wav`, and exits
   non-zero on no PNG (3) or a one-colour frame (4). **Required extension
   (story item, not done here):** pass-through of fixture arguments after `--`
   so U11/U10 launches (`-- --fixture=<name> --anim-speed=instant --pose=…`)
   go through the same wrapper; today the script accepts none. On a desktop
   with a display (Windows), the same `godot` line without `xvfb-run` and
   without `--rendering-driver opengl3` is the Forward+ capture used for
   playtest confirmation (Decision 5).
4. **Frame-selection and validity rules.** The retained frame is the last of
   `--quit-after N` (default 60; a fixture that animates sets `--anim-speed=instant`
   so frame 59 is the settled state, or `--pause-at=<seq>` for a mid-animation
   capture per U11). Frame size is the project viewport (1280x720); a story
   that changes `display/window/size/viewport_*` changes the evidence size and
   says so. A blank or missing frame is a failed capture, not evidence.
5. **What the evidence proves, and the Windows confirmation.** CI evidence
   shows the Compatibility renderer on software GL: layout, text fit, colours
   of `Control` / `ColorRect` / `Label` / `TextureRect` content and the
   fixture-reached state — the properties UI acceptance criteria assert. It
   does **not** show Forward+-only output. Therefore each UI story's **Windows
   look is confirmed at playtest**: the playtest-report for the sprint that
   closes the story records "viewed on Forward+/Windows: matches CI evidence /
   differs (describe)" per story, and a difference opens a bug, not a story
   reopen. `/story-done` accepts the CI PNG as the BLOCKING evidence; the
   Windows confirmation is the ADVISORY follow-through until a Windows capture
   rig exists (Open point; closed by erratum 2026-11-05, DD-X32).
6. **Design rules that keep the two renderers equivalent for 2D UI in v1**
   (binding on ADR-0009, ADR-0011 and every UI story; `/create-control-manifest`
   extracts them):
   - No `WorldEnvironment` glow, HDR, tonemapping, SSR/SSAO, `AreaLight3D`,
     3D viewports, `SubViewport` with 3D content, or any Forward+-only project
     setting in v1. Gamma (DD-X10) is a `CanvasModulate` adjustment, which both
     renderers apply identically.
   - Custom shaders are `canvas_item` shaders only and avoid features absent in
     the Compatibility backend; any custom shader is captured under **both**
     renderers before its story closes (CI frame + Windows playtest row). The
     exact Compatibility GLSL subset is **NOT SOURCEABLE** from the reference;
     the two-renderer capture is the test.
   - Line and outline widths are explicit (4.7 removed the antialiasing feather,
     sourced) so thickness does not depend on renderer-side AA.
   - MSAA/FXAA/SMAA 2D are off in `project.godot` for v1 (text and hard-edged
     UI do not need them; keeps pixel parity).
   - Theme resources, fonts and `text_scale` (DD-X07) are renderer-neutral by
     construction; font hinting default changed in 4.7
     (`ResourceImporterDynamicFont.hinting` 3, sourced) and is the same in both
     paths because it is an import setting.
7. **Fallback setting left at default.** `rendering/rendering_device/fallback_to_opengl3`
   stays on (default): a player machine without a working D3D12/Vulkan driver
   falls back to Compatibility and still runs the game, and rule 6 guarantees
   it looks the same. This is a side benefit of the design rules, not a
   support promise.

### Architecture Diagram

```
                 Windows player / Windows playtest              Linux CI / dev container
                 ─────────────────────────────────              ─────────────────────────
project.godot    rendering_method = forward_plus  ──────────────► same file
                       │ D3D12 (4.6 default, sourced)                   │ no display, no Vulkan ICD
                       ▼                                                 ▼
launch           godot --path . --windowed --resolution 1280x720   xvfb-run -a -s "-screen 0 1280x720x24" godot … \
                 [--write-movie …]  (Forward+)                        --rendering-driver opengl3 --write-movie <dir>/f.png \
                                                                      --quit-after 60 res://<scene>.tscn -- <fixture args>
                       │                                                 │ Compatibility / llvmpipe (observed)
                       ▼                                                 ▼
                 playtest row per UI story                        tools/capture.sh → <out>/01-<scene>.png (last frame, 1280x720)
                 "matches CI evidence / differs"                   blank check (exit 4) · stamp.txt (review-receipts.sh)
                       ▲                                                 │
                       └──────── rule 6: renderer-neutral 2D UI ─────────┘
                                 (no glow/HDR/3D/AA; canvas_item shaders captured on both)

Scene reach (unchanged, U11/U10): MatchDebugLoader / RunDebugLoader read OS.get_cmdline_user_args()
→ tests/fixtures/match_ui/<name>.json / run_ui/<name>.json → real engine / MetaStub → the state on screen.
```

### Key Interfaces

```bash
# tools/capture.sh — the evidence launcher (Linux/CI). Exit 0 kept a non-blank PNG; 2 usage; 3 no PNG / godot failed; 4 blank.
bash tools/capture.sh <scene-res-path> <out-dir> [frames] [-- <args after -- for OS.get_cmdline_user_args()>]
# e.g. (after the pass-through extension)
bash tools/capture.sh res://src/ui/match/match_view.tscn production/qa/evidence/story-012-hand-fan 60 -- --fixture=hand_10 --anim-speed=instant
# → production/qa/evidence/story-012-hand-fan/01-match_view.png  (rename to <NN>-<what>.png per run-and-observe.md)

# Desktop (Windows) Forward+ capture for the playtest confirmation — same flags minus xvfb-run and the driver override:
godot --path . --windowed --resolution 1280x720 --write-movie <dir>/f.png --quit-after 60 res://<scene>.tscn -- <args>
```

```gdscript
# No new GDScript API. The debug loaders (match-ui U11, run-ui U10; architecture.md "Screenshot capture and the fixtures seam")
# are the scene-reach seam this ADR relies on and does not redefine:
# src/ui/match/match_debug_loader.gd — reads --fixture, --pose, --pause-at, --anim-speed, --ai-debug (debug builds only)
# src/ui/run/run_debug_loader.gd     — reads --run-ui-screen=<id> --run-ui-fixture=<name>; Boot.boot({meta: MetaStub})
# Optional diagnostics a UI scene may print once in debug builds so the log names the path taken:
#   RenderingServer.get_current_rendering_method(), get_current_rendering_driver_name(), get_video_adapter_name()  (observed, Probe C)
```

### Implementation Guidelines

- Must produce UI/Visual evidence on Linux with `tools/capture.sh`; must never
  hand-write the `xvfb-run … godot` line in a story or skill.
- Must never add `--headless` to a capture launch (crashes, exit 134); must
  never substitute a headless run for a screenshot.
- Must pass `--rendering-driver opengl3` explicitly on Linux captures; must not
  rely on the silent Vulkan→GL fallback.
- Must keep the frame count ≥ 60 unless a story justifies less, and must use
  `--anim-speed=instant` or `--pause-at=<seq>` to make the last frame the
  intended state.
- Must reach every captured state through a fixture (`--fixture`,
  `--run-ui-fixture`) and the real engine / `MetaStub`; must never build a
  view-state by hand for a screenshot.
- Must record, for every UI story, a Windows playtest row confirming the
  Forward+ look; must not treat the CI PNG as proof of Forward+ output.
- Must keep v1 UI inside the renderer-neutral subset (rule 6): no glow, HDR,
  3D, post-processing or AA; `canvas_item` shaders only, captured on both
  renderers before close; explicit line widths.
- Must not change `rendering/renderer/rendering_method`,
  `rendering/rendering_device/fallback_to_opengl3`, or the viewport size
  without superseding this ADR (renderer) or noting the evidence size change
  (viewport).
- Must stamp evidence (`review-receipts.sh hash`) beside the PNG and retain it
  under `production/qa/evidence/<story-slug>/` (procedure in
  `run-and-observe.md`).

## Alternatives Considered

### Alternative 1: Switch the project to `gl_compatibility` everywhere
- **Description**: Set `rendering_method="gl_compatibility"`; ship and capture
  on the same renderer.
- **Pros**: Zero renderer divergence; identical pixels on CI and Windows (Probe
  C row 4 showed identical output); broadest hardware support (sourced).
- **Cons**: Reverses the owner's `project.yaml` choice without a product reason;
  forecloses Forward+ features for post-v1 art without a design request; the
  rule-6 subset already makes the two equivalent for v1.
- **Estimated Effort**: Trivial.
- **Rejection Reason**: The divergence is contained by rule 6 and the playtest
  row; changing the shipped renderer is a product decision for the owner, and
  this ADR records it as the one-line change to make if the per-story Windows
  confirmation proves too costly (`/propagate-design-change` + supersede).

### Alternative 2: Install a software Vulkan ICD (Mesa lavapipe) on the CI image and capture on Forward+
- **Description**: Add `mesa-vulkan-drivers` so Vulkan initialises under Xvfb.
- **Pros**: Evidence would show the shipped renderer.
- **Cons**: **NOT SOURCEABLE / untested** — no ICD is present and Probe C did
  not exercise it; Forward+ on a software Vulkan device is slower and may
  differ from D3D12 output anyway (the shipped backend is D3D12, not Vulkan);
  ties evidence to a CI package that is not pinned by the engine reference.
- **Estimated Effort**: Low to try, unknown to stabilise.
- **Rejection Reason**: Trades a known-good, observed path for an unverified
  one that still would not show the D3D12 output; recorded as a possible later
  spike if the playtest rows keep finding differences.

### Alternative 3: Capture-on-trigger (`get_viewport().get_texture().get_image().save_png()`) instead of Movie Maker
- **Description**: An autoload or debug node saves the viewport after
  `RenderingServer.frame_post_draw` and quits (run-and-observe "alternative").
- **Pros**: Saves at window size; one PNG, no frame sequence or `.wav`.
- **Cons**: Still needs a display (same Xvfb/renderer question); adds a code
  path in the tree for evidence; `--write-movie` is zero scaffold (run-and-observe)
  and already proven.
- **Estimated Effort**: Low.
- **Rejection Reason**: Solves nothing this ADR is about; kept as the
  run-and-observe fallback for a state a scene launch cannot reach.

### Alternative 4: `--headless --write-movie`
- **Description**: Avoid Xvfb entirely.
- **Pros**: None realised.
- **Cons**: Crashes on 4.7.2 (exit 134, `texture_2d_get` null in the dummy
  rasterizer, Probe C row 9); headless exists to skip rendering.
- **Estimated Effort**: —
- **Rejection Reason**: Observed to crash; forbidden by run-and-observe.

### Alternative 5: Rely on the silent Vulkan→OpenGL fallback (no `--rendering-driver` flag)
- **Description**: Launch Forward+ under Xvfb and let the engine fall back.
- **Pros**: One fewer flag; same pixels (Probe C row 1 vs 2).
- **Cons**: 3x slower cold start; two Vulkan `ERROR:` lines per capture that a
  reviewer must learn to ignore; the path changes silently if an ICD appears.
- **Estimated Effort**: —
- **Rejection Reason**: Explicit beats implicit for an evidence path that must
  stay stable across CI image changes.

## Consequences

### Positive
- Every UI story has an unattended, seconds-long, observed-working evidence
  path on the CI image today (rig check retained).
- The shipped renderer stays the owner's choice; the divergence is named,
  bounded by rule 6 and closed per story by the playtest row.
- `/story-done`, `/dev-story` and `/qa-plan` have one launcher and one
  frame-selection rule to cite; evidence is uniform.
- The fallback-on default plus rule 6 means a player machine without a working
  D3D12/Vulkan driver still gets a correct-looking game.

### Negative
- CI evidence never shows Forward+/D3D12 output; a Forward+-specific regression
  (driver-level text rendering difference, shader compile failure) is caught
  only at playtest.
- Every UI story carries a manual Windows confirmation row until a Windows
  capture rig exists — recurring cost.
- Rule 6 forbids some presentation polish (glow on legendary cards, bloom on
  lethal) for v1; adding it later requires a Forward+ evidence path or a
  Compatibility-equivalent implementation, and a supersession of this ADR.
- `tools/capture.sh` needs the argument pass-through before the first fixture
  story can use it; until then U11 launches must be run by hand with the same
  flags.

### Neutral
- Evidence is 1280x720 regardless of window size; stories do not get to choose
  a capture resolution.
- The `.wav` Movie Maker writes is discarded; audio is not evidenced.

## Risks
- **A Compatibility-only or Forward+-only rendering difference ships unnoticed**
  (font rasterisation, `CanvasItem` line widths, shader precision). *Mitigation*:
  rule 6 (explicit widths, no AA, `canvas_item` shaders captured on both), the
  per-story Windows row, and `/playtest-report` prompting for it.
- **The CI image gains a Vulkan ICD** and the implicit path changes.
  *Mitigation*: the explicit `--rendering-driver opengl3` flag; the rig check
  re-run on every image change.
- **Frame 59 is not the settled state** for an animated fixture. *Mitigation*:
  `--anim-speed=instant` default in fixture launches; `--pause-at` for mid-state
  captures; the blank check catches a black frame but not a wrong one — the
  reviewer reads the PNG (run-and-observe step 4).
- **llvmpipe is slow for a full match scene** so 60 frames take long on CI.
  *Mitigation*: Probe C measured ~2.4 s for a simple scene; the story that
  lands `match_view.tscn` records the capture time and lowers `frames` if it
  exceeds 30 s.
- **Windows confirmation rows get skipped.** *Mitigation*: `/qa-plan` lists the
  row per UI story; the Pre-Production gate reads the playtest report; a
  skipped row reads as "NOT ASSESSED", never as a pass (skill-authoring rule).

## GDD Requirements Addressed

TR-IDs are the provisional ids from `docs/architecture/architecture.md`
§Technical Requirements Baseline; `/architecture-review` registers them.

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-concept.md | TR-game-concept-001 — Technical Considerations / Risks: headless test and screenshot evidence on Linux CI (Xvfb); Forward+ may need the Compatibility renderer for capture | Decision 2–3: capture on Compatibility via `--rendering-driver opengl3` under `xvfb-run`, shipped build on Forward+; the risk is closed with an observed command |
| match-ui.md | TR-match-ui-004 — U11: debug entry points via `OS.get_cmdline_user_args()`, fixtures run the real engine, `MatchDebugLoader` absent from release | The launch line carries `-- <args>` through `tools/capture.sh` (pass-through extension); the seam is unchanged; frame rule uses `--anim-speed=instant` / `--pause-at` |
| run-ui.md | TR-run-ui-004 — U10: `--run-ui-screen=<id> --run-ui-fixture=<name>` into `MetaStub` | Same wrapper and rules; `Boot.boot({meta: stub})` per ADR-0004's seam |
| design-decisions.md | TR-design-decisions-003 — DD-T05: 1280x720 logical, `canvas_items` stretch | Evidence frames are the 1280x720 viewport; `project.godot` keeps `canvas_items` / `keep` (4.7 new-project defaults do not apply, sourced) |
| design-decisions.md | DD-X10 gamma as a `CanvasModulate` adjustment; DD-X07 `text_scale`, `high_contrast_states` | Rule 6: both are renderer-neutral, so CI evidence of them is valid |
| tech-debt-register.md | TR-tech-debt-001 — TD-012 (evidence half) | A proven, retained screenshot path exists before the first UI story |
| coding-standards.md / run-and-observe.md | "A parse check is not a run"; Visual/UI evidence BLOCKING; Godot row (`--write-movie`, never `--headless`) | This ADR is the Godot-on-Linux instantiation of that procedure |

## TD Items Retired

| TD | Prototype root cause | How this ADR rules it out |
|---|---|---|
| TD-012 (evidence half; the test half is `/test-setup` + ADR-0001/0003) | No tests and no way to observe the game unattended; `test_scene.tscn` was a manual scene | An observed, scripted capture path (`tools/capture.sh`, rig check retained) that every UI story must use before it closes |

## Engine Compatibility Details

| Claim | Source / status |
|---|---|
| Renderers: Forward+ (desktop), Mobile, Compatibility (OpenGL 3.3 / WebGL 2) | **Sourced** `modules/rendering.md` §Rendering Backend Selection (4.6) |
| D3D12 is the default backend on Windows since 4.6 | **Sourced** `modules/rendering.md`, `breaking-changes.md` 4.5→4.6 |
| `CanvasItem` lines drawn without antialiasing feather in 4.7; `LinearToSRGB` no longer clamps under Forward+/Mobile | **Sourced** `breaking-changes.md` 4.6→4.7 Rendering; `current-best-practices.md` §Rendering 4.7 |
| New-project stretch defaults `canvas_items` / `expand` in 4.7; existing projects keep their settings (this one: `canvas_items` / `keep`) | **Sourced** `breaking-changes.md` Project row; `project.godot` |
| `--headless`, `--path`, `--quit-after`, `--import` flags | **Sourced** `current-best-practices.md` §Command Line |
| `--write-movie <file>` (PNG sequence), `--fixed-fps` forced/optional, `--quit-after` as frame count, `--rendering-driver opengl3`, `--windowed`, `--resolution` | **NOT SOURCEABLE** from the reference; **observed** Probe C (`godot --help` text and rows 1–11) and `.claude/docs/run-and-observe.md` |
| Under Xvfb with no Vulkan ICD, Forward+ falls back to OpenGL 3 / Compatibility (`rendering/rendering_device/fallback_to_opengl3`, default on; `false` → exit 1 `Could not initialize vulkan`) | **Observed** Probe C rows 1, 3, 7, 8 (setting name taken from the running engine; not in the reference) |
| Explicit `--rendering-driver opengl3` gives identical pixels, no Vulkan errors, ~2.4 s vs 7.6 s cold | **Observed** Probe C rows 2 vs 1 |
| `--headless --write-movie` crashes (exit 134) | **Observed** Probe C row 9 |
| Frames are viewport-sized (1280x720) regardless of `--resolution` | **Observed** Probe C row 10; `run-and-observe.md` |
| Frame 0 already fully rendered for a static scene; last frame taken anyway | **Observed** Probe C (row 2 frame check) |
| `RenderingServer.get_current_rendering_method()` / `get_current_rendering_driver_name()` / `get_video_adapter_name()` | **Observed** Probe C verified API list |
| Rig check: `tools/capture.sh res://src/scenes/boot.tscn …` → exit 0, 1280x720, 473 colours, Compatibility/llvmpipe | **Observed** `production/qa/evidence/rig-check-2026-11-03/README.md` |
| lavapipe would let Forward+ render under Xvfb | **NOT SOURCEABLE**, not tested (Alternative 2) |
| Forward+/D3D12 output parity with the CI frames; Windows/macOS capture behaviour | **NOT SOURCEABLE**; per-story Windows playtest row (Decision 5) |
| Compatibility backend's exact `canvas_item` shader feature subset | **NOT SOURCEABLE**; two-renderer capture per custom shader (rule 6) |

## Verification — How We Know

| Question | Proof | Where |
|---|---|---|
| The launch line produces a correct frame on the CI image | Probe C rows 2/4/6; rig check `01-boot.png` | `docs/architecture/spikes/2026-11-03-engine-probes.md`; `production/qa/evidence/rig-check-2026-11-03/` |
| The wrapper rejects blank frames and failed runs | `capture.sh` exit 3/4 paths; verified against a synthetic solid PNG (rig-check README) | `tools/capture.sh`; `tests/smoke/critical-paths.md` adds "capture.sh exits 0 on boot.tscn" as a rig-health item |
| The wrapper passes fixture args through | After the extension: `capture.sh … -- --fixture=mulligan` yields a frame whose log line names the fixture | `tools/capture.sh`; first U11 fixture story's evidence |
| CI runs the capture | A workflow step runs `tools/capture.sh res://src/scenes/boot.tscn production/qa/evidence/ci-rig-check` on every push and uploads the PNG as an artifact | `.github/workflows/tests.yml` (test-rig story) |
| Each UI story's Windows look matches | Playtest row "viewed on Forward+/Windows" per story | `production/playtests/` reports via `/playtest-report`; `/qa-plan` lists the row |
| Rule 6 is respected | `/create-control-manifest` rule; `project.godot` diff review for `WorldEnvironment`, AA, renderer keys; `/asset-audit` flags non-`canvas_item` shaders under `assets/shaders/` | control manifest; CI grep in the test-rig story |
| The evidence path survives a CI image change | Rig check re-run on image bump (the explicit driver flag keeps the path) | `tests/smoke/critical-paths.md` |

## Performance Implications
- **CPU**: capture is offline tooling: ~2.4 s for a simple scene on llvmpipe
  (Probe C), encoding ~22 ms/frame; a 60-frame capture of a full match scene is
  expected in the 5–30 s range and is measured when `match_view.tscn` lands.
- **Memory**: n/a for the game; frames are 1280x720 PNGs (~10–20 KB for flat UI).
- **Load Time**: none in the game. Rule 6 (no post-processing, no AA) keeps the
  shipped 2D frame cheap on both renderers.
- **Network**: n/a.

## Migration Plan

Nothing to migrate: `project.godot` stays on Forward+; `tools/capture.sh`
exists. Stories: (1) extend `capture.sh` with `-- <args>` pass-through and the
CI artifact step; (2) add the control-manifest rule 6 entries; (3) `/qa-plan`
adds the Windows confirmation row per UI story; (4) the first U11 and U10
fixture stories prove the wrapper end to end. If the per-story Windows
confirmation proves too costly or finds repeated differences, the escape is
Alternative 1 (one `project.godot` line plus `project.yaml`, with
`/propagate-design-change` on ADR-0009/0011) or Alternative 2 (a lavapipe
spike), either superseding this ADR.

**Rollback plan**: revert to the silent-fallback launch (Alternative 5) — same
pixels, slower, noisier — if the explicit flag ever fails on a new engine
build; or to capture-on-trigger (Alternative 3) if Movie Maker regresses.

## Validation Criteria

Correct when: every UI/Visual story closed in the first two Production sprints
has a retained PNG produced by `tools/capture.sh` and a Windows playtest row;
zero stories were blocked by a capture failure that was not a real scene
defect; the Windows rows report "matches" for all rule-6-compliant screens (a
"differs" row traces to a rule-6 violation or opens a renderer bug, which is
the signal to revisit Alternatives 1–2); and the CI rig-check artifact is
present on every push.

## Related
- Enables: ADR-0009 (Match UI animation / scene partition), ADR-0011 (Run UI
  shell); relies on ADR-0004's `MetaApi` seam for `RunDebugLoader`.
- `design/gdd/match-ui.md` U11, U12; `design/gdd/run-ui.md` U10;
  `design/gdd/game-concept.md` Technical Considerations / Technical Risks;
  `design/design-decisions.md` DD-T05, DD-X07, DD-X10.
- `.claude/docs/coding-standards.md` (Test Evidence by Story Type; "A parse
  check is not a run"); `.claude/docs/run-and-observe.md` § Godot 4;
  `docs/architecture/architecture.md` §Screenshot capture and the fixtures
  seam, §Engine Knowledge Gap Summary (Rendering row), Open Question QQ-03;
  `production/gate-checks/gate-technical-setup-2026-11-03.md` (exit criterion 3).
- `docs/architecture/spikes/2026-11-03-engine-probes.md` Probe C;
  `production/qa/evidence/rig-check-2026-11-03/`.
- `tools/capture.sh`; `project.godot` (`[rendering]`, `[display]`);
  `project.yaml` (`engine.rendering`, `commands.run`); `export_presets.cfg`.
- `docs/tech-debt-register.md` TD-012.
