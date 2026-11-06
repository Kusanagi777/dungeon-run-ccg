## The headless entry of the sim harness (boss-ai C11; story 016): `tools/sim.sh`.
##
##   godot --headless --path . -s res://tests/integration/boss_ai/sim_main.gd -- --boss boss_x --seeds 100
##
## User arguments: `--boss <id>` (required), `--seeds <n>` (default 100), `--hero <id>` or
## `--vs-boss <id>`, `--band <1-3>`, `--out <dir>`, `--verify`. A thin [SceneTree]:
## [BossAiSimHarness], the class, cannot be a main loop. Exits 0 with a report written,
## 1 with a rejected boss command, a fault, an overflow or any other unclean end in it, 2
## if it could not run.
## A planner time over `planner_target_ms` is printed with the F7 note and is not a
## failure: A22 is measured on the target machine (story 018).
extends SceneTree

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const DEFAULT_SEEDS: int = 100
const EXIT_CLEAN: int = 0
const EXIT_DIRTY: int = 1
const EXIT_NOT_RUN: int = 2


func _initialize() -> void:
	var args: Dictionary = _parse(OS.get_cmdline_user_args())
	if str(args.get("boss", "")).is_empty():
		printerr("sim: --boss <id> is required")
		quit(EXIT_NOT_RUN)
		return
	var boot: Node = BOOT_SCRIPT.new()
	var booted: BootResult = boot.boot()
	if not booted.ok or not boot.services().card_database.has(str(args.boss)):
		printerr("sim: no boss `%s` to run (data load: %s)" % [str(args.boss), str(booted.load_status)])
		boot.free()
		quit(EXIT_NOT_RUN)
		return
	var harness: BossAiSimHarness = BossAiSimHarness.new(boot.services().card_database, boot.driver_factory)
	var opponent: Dictionary = {"boss_id": args["vs-boss"]} if args.has("vs-boss") else {"hero_id": str(args.get("hero", ""))}
	var options: Dictionary = {"verify": args.has("verify")}
	if args.has("band"):
		options["band"] = int(args.band)
	var seeds: Array[int] = BossAiSimHarness.seed_range(int(args.get("seeds", DEFAULT_SEEDS)))
	var report: Dictionary = harness.run(str(args.boss), seeds, opponent, str(args.get("out", BossAiSimHarness.DEFAULT_OUT_DIR)), options)
	boot.free()
	if report.is_empty():
		quit(EXIT_NOT_RUN)
		return
	_print_table(report)
	quit(EXIT_CLEAN if BossAiSimHarness.is_clean(report) else EXIT_DIRTY)


## `--key value` pairs and bare `--flag`s, as a Dictionary.
func _parse(argv: PackedStringArray) -> Dictionary:
	var args: Dictionary = {}
	var index: int = 0
	while index < argv.size():
		var key: String = argv[index].trim_prefix("--")
		var next: int = index + 1
		if next < argv.size() and not argv[next].begins_with("--"):
			args[key] = argv[next]
			index += 2
		else:
			args[key] = true
			index += 1
	return args


func _print_table(report: Dictionary) -> void:
	print("%s, band %d: %d matches" % [report.boss_id, int(report.band), int(report.seeds)])
	print("  boss win rate %.3f, mean turns %.1f, mean final health %.1f" % [report.win_rate, report.mean_turns, report.mean_final_health])
	for floor_key: String in report.by_floor:
		var on_floor: Dictionary = report.by_floor[floor_key]
		print("  floor %s: boss win rate %.3f over %d (player target %.2f)" % [floor_key, on_floor.boss_win_rate, on_floor.matches, on_floor.target_player_win_rate])
	print("  decisions %d (most in a match %d), rejections %d, faults %d, overflows %d" % [report.decision_count, report.max_decisions_in_a_match, report.rejections, report.faults, report.overflows])
	print("  end reasons %s" % str(report.end_reasons))
	for kind: String in ["play_turn", "forecast"]:
		var times: Dictionary = report[kind]
		print("  %s: p50 %.2f ms, p95 %.2f ms over %d runs" % [kind, times.p50_ms, times.p95_ms, int(times.runs)])
		if float(times.p95_ms) > float(report.planner_target_ms):
			print("  %s p95 is over planner_target_ms %.0f: F7 lowers band 3's counts until A22 passes" % [kind, report.planner_target_ms])
