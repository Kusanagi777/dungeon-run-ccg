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
# ADR-0001 erratum 2026-11-03), root or src/ai missing, no .gd file under src/ai,
# or rg or awk erroring. A refusal never prints a hit count: results are held
# until every rule has run.
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

# --- A29 allow-list: every number src/ai may declare ------------------------

# `<file> <table> <key> <numbers>` for a row of a `const` table, and
# `<file> const <name> <value>` for a named constant. An entry holds for that file,
# that name and that value only, so a new key, a changed value or a copy elsewhere
# is a hit, even at 0 or 1 (BAI-012 review D-2). A number that belongs here is added
# here, where the review sees it: BAI review N6's `OP_UNVALUED = 1.0` is why 0 and 1
# are not free in a constant. An entry whose code has gone is harmless.
export ALLOWED_NUMBERS
ALLOWED_NUMBERS="$(cat <<'PINNED'
# RANGES: the validation bounds of each F9 field, which cannot come from the file
# they validate.
src/ai/boss_ai.gd RANGES w_board 0.0 5.0
src/ai/boss_ai.gd RANGES w_face 0.0 5.0
src/ai/boss_ai.gd RANGES w_self 0.0 5.0
src/ai/boss_ai.gd RANGES w_trade 0.0 3.0
src/ai/boss_ai.gd RANGES w_threat 0.0 5.0
src/ai/boss_ai.gd RANGES w_mana 0.0 3.0
src/ai/boss_ai.gd RANGES w_card 0.0 3.0
src/ai/boss_ai.gd RANGES w_over 0.0 3.0
src/ai/boss_ai.gd RANGES w_heal 0.0 3.0
src/ai/boss_ai.gd RANGES w_hp 0.0 2.0
src/ai/boss_ai.gd RANGES w_passive 0.0 5.0
src/ai/boss_ai.gd RANGES BV_NORM 5.0 20.0
src/ai/boss_ai.gd RANGES THREAT_NORM 5.0 20.0
src/ai/boss_ai.gd RANGES trade_ratio 0.5 2.0
src/ai/boss_ai.gd RANGES tie_epsilon 0.0 0.5
src/ai/boss_ai.gd RANGES overextend_cap_aoe 2.0 7.0
src/ai/boss_ai.gd RANGES burn_per_mana 0.0 2.0
src/ai/boss_ai.gd RANGES defensive_margin 0.0 10.0
src/ai/boss_ai.gd RANGES lethal_max_nodes 10.0 20000.0
src/ai/boss_ai.gd RANGES max_evals_per_action 10.0 1000.0
src/ai/boss_ai.gd RANGES max_actions_per_turn 10.0 100.0
src/ai/boss_ai.gd RANGES op_value 0.0 5.0
src/ai/boss_ai.gd RANGES keyword_value 1.0 1.5
src/ai/boss_ai.gd RANGES choice_preference 0.0 1.0
src/ai/boss_ai.gd RANGES action_delay_s 0.3 1.2
src/ai/boss_ai.gd RANGES max_turn_playback_s 6.0 20.0
src/ai/boss_ai.gd RANGES intent_banner_s 0.2 0.6
src/ai/boss_ai.gd RANGES plan_changed_s 0.6 2.0
src/ai/boss_ai.gd RANGES planner_target_ms 50.0 1000.0
# NORMALISERS: what A29 calls normalisers. taunt_bonus and the flat_* rows are F2
# values whose GDD source is the data file (BAI-012 review D-3): they stay here
# only until that is settled, and a row moved to data comes out of this list.
src/ai/scorer.gd NORMALISERS taunt_bonus 1.5
src/ai/scorer.gd NORMALISERS threat_windfury 0.5
src/ai/scorer.gd NORMALISERS threat_deathrattle 1.0
src/ai/scorer.gd NORMALISERS flat_spell_damage 2.0
src/ai/scorer.gd NORMALISERS flat_deathrattle 1.0
src/ai/scorer.gd NORMALISERS flat_aura 2.0
src/ai/scorer.gd NORMALISERS weapon_bv 0.8
src/ai/scorer.gd NORMALISERS card_norm 3.0
src/ai/scorer.gd NORMALISERS trade_even_band 0.2
src/ai/scorer.gd NORMALISERS board_full_threat 1.25
src/ai/scorer.gd NORMALISERS defensive_taunt_bv 0.5
src/ai/scorer.gd NORMALISERS cost_fit_full 1.0
src/ai/scorer.gd NORMALISERS cost_fit_over 0.5
src/ai/scorer.gd NORMALISERS big_minion_cost 5
src/ai/candidates.gd NORMALISERS op_unvalued 1.0
src/ai/candidates.gd NORMALISERS body_divisor 4.0
# BOARD_SELECTORS: how many boards and heroes a selector covers; counts of the
# game's zones, not values.
src/ai/candidates.gd BOARD_SELECTORS all_friendly_minions 1 0 0
src/ai/candidates.gd BOARD_SELECTORS all_enemy_minions 0 1 0
src/ai/candidates.gd BOARD_SELECTORS all_minions 1 1 0
src/ai/candidates.gd BOARD_SELECTORS all_friendly_characters 1 0 1
src/ai/candidates.gd BOARD_SELECTORS all_enemy_characters 0 1 1
src/ai/candidates.gd BOARD_SELECTORS all_characters 1 1 2
# Sentinels: "no value here", never compared as sizes.
src/ai/lethal_search.gd const UNPRICED -1
src/ai/tie_break.gd const ABSENT -1
src/ai/chooser.gd const NO_OPTION -1
# The int ceiling, F4's "cannot prune".
src/ai/lethal_search.gd const UNBOUNDED 9223372036854775807
# Search move order: a rank, no tuning value.
src/ai/lethal_search.gd const RANK_FACE 0
src/ai/lethal_search.gd const RANK_BODY 1
src/ai/lethal_search.gd const RANK_OTHER 2
# Chooser's turn offset: "the turn after this one".
src/ai/chooser.gd const NEXT_TURN 1
# C9's payload shape, `alternatives[<=3]`.
src/ai/scorer.gd const ALTERNATIVES_MAX 3
# C2's fixed recovery rule; A23 holds that any rejection is a bug, so nothing tunes it.
src/ai/boss_ai.gd const MAX_REJECTIONS 3
PINNED
)"

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

# Nothing to scan is not a pass: `rg --files` exits 1 on no file, 2 on an error.
ai_files="$(rg --files --path-separator / --glob '*.gd' src/ai)"
rc=$?
if [ "$rc" -ge 2 ]; then
	echo "ai_code_gates.sh: rg --files exited $rc — refusing to run" >&2
	exit 2
fi
if [ -z "$ai_files" ]; then
	echo "ai_code_gates.sh: no .gd file under src/ai — nothing to check, refusing to run" >&2
	exit 2
fi

total=0
broken=0
results=""

# drop_lines <regex> <hit lines>: prints the lines that do not match. `rg -v` exits 1
# when nothing is left, which is no error; 2 is. Returns 2 then, else 0.
drop_lines() {
	local out rc
	out="$(printf '%s\n' "$2" | rg -v -e "$1")"
	rc=$?
	if [ "$rc" -ge 2 ]; then
		echo "ai_code_gates.sh: rg exited $rc filtering hits" >&2
		return 2
	fi
	[ -n "$out" ] && printf '%s\n' "$out"
	return 0
}

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
	[ -z "$out" ] && return 0
	drop_lines '^[^:]+:[0-9]+:\s*#' "$out"
}

# report <rule> <hit lines>: holds each hit, prefixed with the rule, then the count.
report() {
	local rule="$1" lines="$2" n=0 line
	if [ -n "$lines" ]; then
		while IFS= read -r line; do
			results+="$rule $line"$'\n'
			n=$((n + 1))
		done <<< "$lines"
	fi
	results+="$rule hits: $n"$'\n'
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
# comments go first. A `const` holding a number, or a row of a multi-line `const`
# table, must be pinned in ALLOWED_NUMBERS. Any other number but 0 and 1 is a hit,
# except an index (`x[2]`). The tokeniser takes the longest match, so `0x10` and `1e3`
# are read whole and an identifier's digits (`Node2D`) are never a number.
literal_hits() {
	local files=()
	mapfile -t files < <(printf '%s\n' "$ai_files" | LC_ALL=C sort)
	awk '
		function hit() {
			text = $0
			sub(/^[ \t]+/, "", text)
			print FILENAME ":" FNR ":" text
		}
		function next_token(    token) {
			if (!match(rest, /[A-Za-z_][A-Za-z0-9_]*|-?0[xXbB][0-9a-fA-F_]+|-?[0-9][0-9_]*(\.[0-9_]*)?([eE][-+]?[0-9]+)?|-?\.[0-9]+/)) {
				return ""
			}
			token = substr(rest, RSTART, RLENGTH)
			rest = substr(rest, RSTART + RLENGTH)
			return token
		}
		function numbers(code,    out, token) {
			out = ""
			rest = code
			while ((token = next_token()) != "") {
				if (token ~ /^-?[0-9.]/) {
					out = out (out == "" ? "" : " ") token
				}
			}
			return out
		}
		BEGIN {
			count = split(ENVIRON["ALLOWED_NUMBERS"], rows, "\n")
			for (i = 1; i <= count; i++) {
				if (rows[i] !~ /^#/) {
					pinned[rows[i]] = 1
				}
			}
		}
		FNR == 1 { table = "" }
		{
			code = $0
			gsub(/\\./, "", code)
			key = ""
			if (match(code, /"[^"]*"/)) {
				key = substr(code, RSTART + 1, RLENGTH - 2)
			}
			gsub(/"[^"]*"/, "\"\"", code)
			gsub(/\047[^\047]*\047/, "\"\"", code)
			sub(/#.*/, "", code)
			if (table != "") {
				if (code ~ /^[ \t]*[}\]]/) {
					table = ""
					next
				}
				found = numbers(code)
				if (found != "" && !((FILENAME " " table " " key " " found) in pinned)) {
					hit()
				}
				next
			}
			if (match(code, /^[ \t]*const[ \t]+[A-Za-z0-9_]+/)) {
				name = substr(code, RSTART, RLENGTH)
				sub(/^[ \t]*const[ \t]+/, "", name)
				value = code
				sub(/^[^=]*=/, "", value)
				if (value ~ /[{\[][ \t]*$/) {
					table = name
					next
				}
				found = numbers(value)
				if (found != "" && !((FILENAME " const " name " " found) in pinned)) {
					hit()
				}
				next
			}
			gsub(/[A-Za-z0-9_)\]]\[[0-9]+\]/, "_", code)
			rest = code
			while ((token = next_token()) != "") {
				if (token ~ /^-?[0-9.]/ && token !~ /^-?[01](\.0*)?$/) {
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
if emit_raw="$(rg_hits -e '\.emit\(|\bemit_signal\(' -- src/ai)" \
	&& emit_hits="$(drop_lines '\bengine\.emit\(|^src/ai/time_sliced_planner_task\.gd:[0-9]+:.*\b_resume\.emit\(' "$emit_raw")"; then
	report AI-EMIT "$emit_hits"
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
printf '%s' "$results"
if [ "$total" -gt 0 ]; then
	echo "ai_code_gates.sh: $total hit(s) — FAIL"
	exit 1
fi
echo "ai_code_gates.sh: all rules 0 hits — PASS"
exit 0
