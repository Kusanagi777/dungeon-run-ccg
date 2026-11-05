#!/usr/bin/env bash
# The src/ai gates: A29's no-literal rule and the symbols the planner may never
# touch, enforced in CI next to the test run.
#
#   bash tools/ci/ai_code_gates.sh [root]      # root defaults to the current directory
#
# Rules are design/gdd/boss-ai.md A29, ADR-0006 Validation Criteria and the
# control manifest's Core Forbidden rows; the shape is story
# boss-ai-match-driver/story-012. Same contract as tools/lint/gates.sh:
#
# Every hit prints as `<rule> <file>:<line>: <text>` (file relative to root), and
# every rule prints `<rule> hits: <n>`, so a log that shows a rule with no count
# line is a rule that did not run.
#
# Exit 0: every rule ran and found nothing. Exit 1: at least one hit.
# Exit 2: refused or could not run — rg missing, rg older than 14 (no look-around;
# ADR-0001 erratum 2026-11-03), root or src/ai missing, or rg or awk erroring. A
# refusal never prints a hit count.
#
# Comment lines never count, as for G2b and G3: a doc comment saying "never
# `get_tree()`" is not a call.
#
# A grep reads text, not types. AI-LOG cannot tell a scratch log from a live one,
# so it has no exception: nothing under src/ai writes a log directly, and a clone's
# scratch log is written by the clone's own engine (story 012 readiness, 2026-11-05).
#
# Story: boss-ai-match-driver/story-012.

set -u

# Git Bash rewrites a bare `/` argument into its install path before a native
# rg sees it, so `--path-separator /` below needs that conversion off. Inert on
# Linux and macOS.
export MSYS2_ARG_CONV_EXCL='*'

# --- A29 allow-lists: every entry says why ----------------------------------

# Tables whose body may hold numbers (`const NAME ... = {` to the closing brace).
ALLOWED_TABLES='RANGES|NORMALISERS|BOARD_SELECTORS'
#   RANGES           boss_ai.gd: validation bounds of each F9 field, which cannot
#                    come from the file they validate (holds BV_NORM, THREAT_NORM)
#   NORMALISERS      scorer.gd, candidates.gd: what A29 calls "normalisers"
#   BOARD_SELECTORS  candidates.gd: how many boards and heroes a selector covers;
#                    counts of the game's zones, not values

# Named constants that may be a bare number. Everything else declared `const` with
# a bare number is a hit even at 0 or 1, or a weight could hide as `= 1.0` (BAI
# review N6: OP_UNVALUED).
ALLOWED_CONSTS='UNPRICED|UNBOUNDED|RANK_FACE|RANK_BODY|RANK_OTHER|ABSENT|NO_OPTION|NEXT_TURN|ALTERNATIVES_MAX|MAX_REJECTIONS'
#   UNPRICED, ABSENT, NO_OPTION  sentinels: "no value here", never compared as sizes
#   UNBOUNDED                    the int ceiling, F4's "cannot prune"
#   RANK_FACE, _BODY, _OTHER     search move order, a rank and no tuning value
#   NEXT_TURN                    Chooser's turn offset: "the turn after this one"
#   ALTERNATIVES_MAX             C9's payload shape, `alternatives[<=3]`
#   MAX_REJECTIONS               C2's fixed recovery rule; A23 holds that any
#                                rejection is a bug, so nothing tunes it

# --- ripgrep guard (builtins only until rg is known to exist) ---------------
if ! command -v rg > /dev/null 2>&1; then
	echo "ai_code_gates.sh: ripgrep (rg) not found on PATH — refusing to run (needs ripgrep >= 14)" >&2
	exit 2
fi
rg_version_line="$(rg --version 2>/dev/null | head -n 1)"
echo "ai_code_gates.sh: ${rg_version_line:-rg --version printed nothing}"
rg_major="$(printf '%s\n' "$rg_version_line" | sed -n 's/^ripgrep \([0-9][0-9]*\)\..*/\1/p')"
if [ -z "$rg_major" ] || [ "$rg_major" -lt 14 ]; then
	echo "ai_code_gates.sh: '${rg_version_line}' — needs ripgrep >= 14, refusing to run" >&2
	exit 2
fi

root="${1:-.}"
if [ ! -d "$root" ]; then
	echo "ai_code_gates.sh: root '$root' is not a directory — refusing to run" >&2
	exit 2
fi
cd "$root" || exit 2
if [ ! -d src/ai ]; then
	echo "ai_code_gates.sh: no src/ai under '$root' — nothing to check, refusing to run" >&2
	exit 2
fi

total=0
broken=0

# rg_hits <rg args...> -- <scope dirs...>: prints `file:line:text`, comment lines
# dropped. Returns 2 when rg errored, else 0. The `*.gd` glob comes first: the last
# matching glob wins, so a caller's exclusion holds.
rg_hits() {
	local args=()
	while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
		args+=("$1")
		shift
	done
	shift
	local out rc
	out="$(rg --line-number --with-filename --no-heading --color never --path-separator / --glob '*.gd' "${args[@]}" -- "$@")"
	rc=$?
	if [ "$rc" -ge 2 ]; then
		echo "ai_code_gates.sh: rg exited $rc (${args[*]})" >&2
		return 2
	fi
	[ -n "$out" ] && printf '%s\n' "$out" | rg -v '^[^:]+:[0-9]+:\s*#'
	return 0
}

# report <rule> <hit lines>: prints each hit prefixed with the rule, then the count.
report() {
	local rule="$1" lines="$2" n=0 line
	if [ -n "$lines" ]; then
		while IFS= read -r line; do
			echo "$rule $line"
			n=$((n + 1))
		done <<< "$lines"
	fi
	echo "$rule hits: $n"
	total=$((total + n))
}

# run_rule <rule> <rg args...> -- <scope dirs...>
run_rule() {
	local rule="$1" hits
	shift
	if ! hits="$(rg_hits "$@")"; then
		echo "$rule: could not run" >&2
		broken=1
		return
	fi
	report "$rule" "$hits"
}

# AI-LITERAL — A29: no weight, budget or delay in src/ai. Per line, strings and
# comments go first; a line inside an allowed table is skipped; a `const` of a bare
# number needs its name allowed; then any number but 0 and 1 is a hit, except an
# index (`x[2]`). The tokeniser takes the longest match, so `0x10` and `1e3` are
# read whole and an identifier's digits (`Node2D`) are never a number.
literal_hits() {
	local files=()
	mapfile -t files < <(rg --files --path-separator / --glob '*.gd' src/ai | LC_ALL=C sort)
	[ "${#files[@]}" -eq 0 ] && return 0
	awk -v tables="$ALLOWED_TABLES" -v consts="$ALLOWED_CONSTS" '
		function hit() {
			text = $0
			sub(/^[ \t]+/, "", text)
			print FILENAME ":" FNR ":" text
		}
		FNR == 1 { in_table = 0 }
		{
			code = $0
			gsub(/\\./, "", code)
			gsub(/"[^"]*"/, "\"\"", code)
			gsub(/\047[^\047]*\047/, "\"\"", code)
			sub(/#.*/, "", code)
			if (in_table) {
				if (code ~ /^[ \t]*[}\]]/) {
					in_table = 0
				}
				next
			}
			if (code ~ ("^[ \t]*const[ \t]+(" tables ")[^A-Za-z0-9_]")) {
				if (code ~ /[{\[][ \t]*$/) {
					in_table = 1
				}
				next
			}
			if (code ~ ("^[ \t]*const[ \t]+(" consts ")[^A-Za-z0-9_]")) {
				next
			}
			if (code ~ /^[ \t]*const[ \t]+[A-Za-z0-9_]+[^=]*=[ \t]*-?[0-9.]/) {
				hit()
				next
			}
			gsub(/[A-Za-z0-9_)\]]\[[0-9]+\]/, "_", code)
			while (match(code, /[A-Za-z_][A-Za-z0-9_]*|0[xXbB][0-9a-fA-F_]+|[0-9][0-9_]*(\.[0-9_]*)?([eE][-+]?[0-9]+)?|\.[0-9]+/)) {
				token = substr(code, RSTART, RLENGTH)
				code = substr(code, RSTART + RLENGTH)
				if (token ~ /^[0-9.]/ && token !~ /^[01](\.0*)?$/) {
					hit()
					break
				}
			}
		}
	' "${files[@]}"
}

if literals="$(literal_hits)"; then
	report AI-LITERAL "$literals"
else
	echo "AI-LITERAL: could not run" >&2
	broken=1
fi

# AI-THREAD — ADR-0006: threads live only in the planner tasks, across all of src/.
# `planner_task.gd`, the seam itself, is no `*_planner_task.gd`.
run_rule AI-THREAD --glob '!src/ai/*_planner_task.gd' -e 'WorkerThreadPool|\bThread\b' -- src

# AI-EMIT — no signal from the planner. Two lines are no such thing and are dropped
# by a second pass, as ripgrep has no look-around: `engine.emit(` is the method
# RulesEngine.emit, and `_resume.emit(` is the time-sliced seam waking its own
# coroutine inside poll(), on the main thread (ADR-0006).
if emit_raw="$(rg_hits -e '\.emit\(|\bemit_signal\(' -- src/ai)"; then
	report AI-EMIT "$(printf '%s\n' "$emit_raw" | rg -v '\bengine\.emit\(|^src/ai/time_sliced_planner_task\.gd:[0-9]+:.*\b_resume\.emit\(' | sed '/^$/d')"
else
	echo "AI-EMIT: could not run" >&2
	broken=1
fi

# AI-TREE, AI-MAINLOOP, AI-NODE — the planner has no scene tree (ADR-0001, ADR-0006).
run_rule AI-TREE -e 'get_tree\(' -- src/ai
run_rule AI-MAINLOOP -e 'Engine\.get_main_loop\(' -- src/ai
run_rule AI-NODE -e 'extends\s+Node' -- src/ai

# AI-LOG — no direct log write from the planner; see the header for why the story's
# scratch-log exception is gone.
run_rule AI-LOG -e 'log\.append\(' -- src/ai

if [ "$broken" -ne 0 ]; then
	echo "ai_code_gates.sh: at least one rule could not run — not a pass" >&2
	exit 2
fi
if [ "$total" -gt 0 ]; then
	echo "ai_code_gates.sh: $total hit(s) — FAIL"
	exit 1
fi
echo "ai_code_gates.sh: all rules 0 hits — PASS"
exit 0
