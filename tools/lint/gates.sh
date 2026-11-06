#!/usr/bin/env bash
# Grep gates G1–G8: the rules / presentation split, enforced in CI.
#
#   bash tools/lint/gates.sh [root]      # root defaults to the current directory
#
# Patterns and scopes are ADR-0001 Decision 6 (gate table, with the 2026-11-03
# errata: G2b deny-list under src/ai/**, G3 exclusions and doc-comment filter,
# G6 look-around-free bare-call pattern) and the control manifest's
# Cross-Cutting gate table. Copy them from there, never from memory. G7 is
# ADR-0007 Decision 9 and the manifest's Core Forbidden row.
#
# Every hit prints as `<gate> <file>:<line>: <text>` (file relative to root),
# and every gate prints `<gate> hits: <n>`, so a log that shows a gate with no
# count line is a gate that did not run.
#
# Exit 0: every gate ran and found nothing. Exit 1: at least one hit.
# Exit 2: refused or could not run — rg missing, rg older than 14 (the regex
# engine the patterns were validated on; it has no look-around), root missing,
# or rg itself erroring. A refusal never prints a hit count.
#
# Story: boot-composition-root/story-005 (TD-001, TD-005, TD-006, TD-007).

set -u

# Git Bash rewrites a bare `/` argument into its install path before a native
# rg sees it, so `--path-separator /` below needs that conversion off. Inert on
# Linux and macOS.
export MSYS2_ARG_CONV_EXCL='*'

# --- ripgrep guard (builtins only until rg is known to exist) ---------------
if ! command -v rg > /dev/null 2>&1; then
	echo "gates.sh: ripgrep (rg) not found on PATH — refusing to run (needs ripgrep >= 14)" >&2
	exit 2
fi
rg_version_line="$(rg --version 2>/dev/null | head -n 1)"
echo "gates.sh: ${rg_version_line:-rg --version printed nothing}"
rg_major="$(printf '%s\n' "$rg_version_line" | sed -n 's/^ripgrep \([0-9][0-9]*\)\..*/\1/p')"
if [ -z "$rg_major" ] || [ "$rg_major" -lt 14 ]; then
	echo "gates.sh: '${rg_version_line}' — needs ripgrep >= 14, refusing to run" >&2
	exit 2
fi

root="${1:-.}"
if [ ! -d "$root" ]; then
	echo "gates.sh: root '$root' is not a directory — refusing to run" >&2
	exit 2
fi
cd "$root" || exit 2

total=0
broken=0

# Prints the directories of "$@" that exist (an absent scope is 0 hits; rg on a
# missing directory exits 2).
existing_dirs() {
	local d
	for d in "$@"; do
		[ -d "$d" ] && printf '%s\n' "$d"
	done
}

# rg_hits <rg args...> — runs rg over the existing scope dirs given after `--`,
# prints `file:line:text` lines. Returns 2 when rg errored, else 0.
rg_hits() {
	local args=() dirs=()
	while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
		args+=("$1")
		shift
	done
	shift
	mapfile -t dirs < <(existing_dirs "$@")
	[ "${#dirs[@]}" -eq 0 ] && return 0
	local out rc
	out="$(rg --line-number --with-filename --no-heading --color never --path-separator / --glob '*.gd' "${args[@]}" -- "${dirs[@]}")"
	rc=$?
	if [ "$rc" -ge 2 ]; then
		echo "gates.sh: rg exited $rc (${args[*]})" >&2
		return 2
	fi
	[ -n "$out" ] && printf '%s\n' "$out"
	return 0
}

# report <gate> <hit lines> — prints each hit prefixed with the gate, then the count.
report() {
	local gate="$1" lines="$2" n=0 line
	if [ -n "$lines" ]; then
		while IFS= read -r line; do
			echo "$gate $line"
			n=$((n + 1))
		done <<< "$lines"
	fi
	echo "$gate hits: $n"
	total=$((total + n))
}

# run_gate <gate> <rg args...> -- <scope dirs...>
run_gate() {
	local gate="$1" hits
	shift
	if ! hits="$(rg_hits "$@")"; then
		echo "$gate: could not run" >&2
		broken=1
		return
	fi
	report "$gate" "$hits"
}

# G1 — no Node in rules.
run_gate G1 -e 'extends (Node|Control|Node2D|CanvasItem|Timer)' -- src/gameplay src/ai

# G2 — no tree access in rules (boot.gd is the one Node in src/core).
run_gate G2 --glob '!src/core/boot.gd' \
	-e 'get_tree\(|get_node\(|\$[A-Za-z%]|%[A-Z]|queue_free|add_child' \
	-- src/gameplay src/ai src/core

# G2b — no coroutines in rules. Two scopes, one gate: bare `await` in gameplay
# and core; under src/ai the look-around-free deny-list (ADR-0006 lets the
# planner await its own coroutines). Hit lines that are comments (`#`, `##`)
# are dropped, as for G3: a doc comment saying "no `await`" is not a coroutine
# (erratum 2026-11-03, found when match-rules 003-005 merged).
if g2b_main="$(rg_hits --glob '!src/core/boot.gd' -e '\bawait\b' -- src/gameplay src/core)" \
	&& g2b_ai="$(rg_hits -e '\bawait\b.*(get_tree|process_frame|physics_frame|create_timer|\.timeout|\.finished|tween|signal)' -- src/ai)"; then
	report G2b "$(printf '%s\n%s' "$g2b_main" "$g2b_ai" | rg -v '^[^:]+:[0-9]+:\s*#' | sed '/^$/d')"
else
	echo "G2b: could not run" >&2
	broken=1
fi

# G3 — no composition root in rules. The composition root's own three files
# are excluded, and hit lines that are doc comments (`##`) are dropped by a
# second filter (ripgrep has no look-around).
if g3_raw="$(rg_hits --glob '!src/core/boot.gd' --glob '!src/core/services.gd' --glob '!src/core/boot_result.gd' \
	-e '\bBoot\b|\bServices\b' -- src/gameplay src/ai src/core)"; then
	report G3 "$(printf '%s\n' "$g3_raw" | rg -v '^[^:]+:[0-9]+:\s*##' | sed '/^$/d')"
else
	echo "G3: could not run" >&2
	broken=1
fi

# G4 — exactly one autoload, named Boot. Counts `^[A-Za-z_]+=` lines between
# `[autoload]` and the next section header of project.godot.
if [ ! -f project.godot ]; then
	report G4 "project.godot: not found"
else
	g4_entries="$(awk '
		/^\[/ { in_autoload = ($0 == "[autoload]"); next }
		in_autoload && /^[A-Za-z_]+=/ { print NR ":" $0 }
	' project.godot)"
	g4_hits=""
	boot_count=0
	entry_count=0
	while IFS= read -r entry; do
		[ -z "$entry" ] && continue
		entry_count=$((entry_count + 1))
		name="${entry#*:}"
		name="${name%%=*}"
		if [ "$name" = "Boot" ]; then
			boot_count=$((boot_count + 1))
		else
			g4_hits+="project.godot:${entry%%:*}: ${entry#*:}"$'\n'
		fi
	done <<< "$g4_entries"
	if [ "$boot_count" -eq 0 ]; then
		g4_hits+="project.godot: no autoload named Boot"$'\n'
	elif [ "$entry_count" -ne 1 ] && [ "$boot_count" -eq "$entry_count" ]; then
		g4_hits+="project.godot: Boot listed $boot_count times"$'\n'
	fi
	report G4 "$(printf '%s' "$g4_hits" | sed '/^$/d')"
fi

# G5 — UI never mutates: no rules-state type names anywhere in src/ui, and
# `.submit(` only in the controller / driver / view input path.
if g5_types="$(rg_hits -e 'MatchState|RunState' -- src/ui)" \
	&& g5_submit="$(rg_hits --glob '!*_controller.gd' --glob '!*_driver.gd' --glob '!*_view.gd' -e '\.submit\(' -- src/ui)"; then
	report G5 "$(printf '%s\n%s' "$g5_types" "$g5_submit" | sed '/^$/d' | sort -t: -k1,1 -k2,2n -u)"
else
	echo "G5: could not run" >&2
	broken=1
fi

# G6 — no global RNG in rules (owned by ADR-0003; same script). `(^|[^.\w])`
# skips `obj.` calls and identifiers that end in a token.
run_gate G6 -e '(^|[^.\w])(randi|randf|randi_range|randf_range|seed|randomize)\(|\.shuffle\(\)|pick_random\(' \
	-- src/gameplay src/ai

# G7 — no direct state writes from effects (sprint-4 review X1). The first
# pattern is the manifest's, verbatim; the heredoc keeps both quote characters
# in it literal. Comment lines count: the manifest's expected result is 0 hits.
g7_writes="$(cat <<'G7_PATTERN'
\.(board|hand|deck|graveyard|enchantments|keywords)\s*\.(append|erase|insert|remove_at|clear)\(|\.(damage_taken|base_attack|base_health|armor|mana_current|mana_max|frozen|silenced|attacks_used|durability|next_entity_id)\s*[+\-]?=|\[\s*["'](board|hand|deck|graveyard|enchantments|keywords)["']\s*\](\s+as\s+Array\s*\))?\s*\.(append|erase|insert|remove_at|clear)\(|\[\s*["'](damage_taken|base_attack|base_health|armor|mana_current|mana_max|frozen|silenced|attacks_used|durability|next_entity_id)["']\s*\]\s*[+\-]?=([^=]|$)
G7_PATTERN
)"
run_gate G7 -e "$g7_writes" -e 'log\.append\(' -e 'RandomNumberGenerator' -- src/gameplay/effects

# G8 — the treasures chain stays Node-free (treasures story 004, AC-T2.1; the
# TD-009 defect): nothing under src/gameplay/treasures, nor hook_registry.gd or
# hook_installer.gd, reaches a Node, the tree, an autoload or Boot. G4 pins Boot
# as the one autoload, so `Boot.` is every autoload name. Globs are last-match-
# wins: the match directory is dropped, then its two chain files are put back.
# Comment lines are dropped, as for G3: they may name what the chain must not do.
if g8_raw="$(rg_hits --glob '!src/gameplay/match/*.gd' \
	--glob 'src/gameplay/match/hook_registry.gd' --glob 'src/gameplay/match/hook_installer.gd' \
	-e 'extends\s+Node|:\s*Node\b|\bas\s+Node\b|\bNode\.new\(|get_tree\(|Engine\.get_main_loop\(|\bBoot\.' \
	-- src/gameplay/treasures src/gameplay/match)"; then
	report G8 "$(printf '%s\n' "$g8_raw" | rg -v '^[^:]+:[0-9]+:\s*#' | sed '/^$/d')"
else
	echo "G8: could not run" >&2
	broken=1
fi

if [ "$broken" -ne 0 ]; then
	echo "gates.sh: at least one gate could not run — not a pass" >&2
	exit 2
fi
if [ "$total" -gt 0 ]; then
	echo "gates.sh: $total hit(s) — FAIL"
	exit 1
fi
echo "gates.sh: all gates 0 hits — PASS"
exit 0
