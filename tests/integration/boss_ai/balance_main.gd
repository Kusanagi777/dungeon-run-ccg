## The headless entry of the relative balance report: `tools/balance.sh`.
##
##   godot --headless --path . -s res://tests/integration/boss_ai/balance_main.gd -- --seeds 4
##
## User arguments: `--seeds <n>`, `--class <hero id>`, `--boss <boss id>`, `--archetype <tag>`,
## `--band <1-3>`, `--all-bosses`, `--no-archetypes`, `--out <dir>`. Each class plays every power against a
## sample of bosses, then each archetype plays its bundles against one boss per band.
## Exits 0 once a report is written, whatever it shows, and 2 if it could not run: it
## reports and never blocks.
extends SceneTree

const BOOT_SCRIPT := preload("res://src/core/boot.gd")
const EXIT_CLEAN: int = 0
const EXIT_NOT_RUN: int = 2
const SCRATCH_DIR: String = "user://balance_sim"
const DEFAULT_OUT: String = "res://production/qa/balance"
const MAX_ARCHETYPE_CARDS: int = 6
const NEUTRAL_PREFIX: String = "neutral_"
const NEUTRAL_SET: String = "neutral"

var _db: CardDatabase = null
var _harness: BossAiSimHarness = null
var _seeds: Array[int] = []
var _faults: int = 0
var _played: int = 0


func _initialize() -> void:
	var args: Dictionary = _parse(OS.get_cmdline_user_args())
	var boot: Node = BOOT_SCRIPT.new()
	var booted: BootResult = boot.boot()
	if not booted.ok:
		printerr("balance: the data did not load: %s" % str(booted.load_status))
		_close(boot)
		quit(EXIT_NOT_RUN)
		return
	_db = boot.services().card_database
	var knobs: Dictionary = (_db.config("heroes_balance") as Dictionary).balance
	_harness = BossAiSimHarness.new(_db, boot.driver_factory)
	_seeds = BossAiSimHarness.seed_range(int(args.get("seeds", knobs.seeds)))
	var _made: Error = DirAccess.make_dir_recursive_absolute(SCRATCH_DIR)
	var heroes: Array = _db.heroes().filter(func(hero: Dictionary) -> bool: return not args.has("class") or hero.id == str(args["class"]))
	var bosses: Array = _bosses(args, int(knobs.bosses_per_band))
	var sections: PackedStringArray = _play_classes(heroes, bosses, knobs)
	if not args.has("no-archetypes"):
		sections.append(_play_archetypes(heroes, args, knobs))
	_close(boot)
	var text: String = _document(sections)
	print(text)
	var written: String = _write(text, str(args.get("out", DEFAULT_OUT)))
	print("balance: %d matches, %d with faults, report at %s" % [_played, _faults, written])
	quit(EXIT_CLEAN if not written.is_empty() else EXIT_NOT_RUN)


func _close(boot: Node) -> void:
	boot._release_profile()
	boot.free()


func _parse(argv: PackedStringArray) -> Dictionary:
	var args: Dictionary = {}
	var index: int = 0
	while index < argv.size():
		var key: String = argv[index].trim_prefix("--")
		if index + 1 < argv.size() and not argv[index + 1].begins_with("--"):
			args[key] = argv[index + 1]
			index += 2
		else:
			args[key] = true
			index += 1
	return args


# Every band's bosses in id order, cut to [param per_band] unless asked for all or one.
func _bosses(args: Dictionary, per_band: int) -> Array:
	var chosen: Array = []
	for band: int in ([int(args.band)] if args.has("band") else [1, 2, 3]):
		var ids: Array = _db.bosses_in_band(band).map(func(boss: Dictionary) -> String: return str(boss.id))
		ids.sort()
		chosen.append_array(ids if args.has("all-bosses") else ids.slice(0, per_band))
	if args.has("boss"):
		return [str(args.boss)]
	return chosen


func _tally(table: Dictionary, id: String, wins: int, matches: int) -> void:
	var row: Dictionary = table.get(id, {"wins": 0, "matches": 0})
	row.wins = int(row.wins) + wins
	row.matches = int(row.matches) + matches
	table[id] = row


# Plays [param seeds] of one matchup; the player's `{wins, matches}`.
func _match(boss_id: String, opponent: Dictionary, seeds: Array[int]) -> Dictionary:
	var report: Dictionary = _harness.run(boss_id, seeds, opponent, SCRATCH_DIR)
	if report.is_empty():
		return {"wins": 0, "matches": 0}
	if not BossAiSimHarness.is_clean(report):
		_faults += 1
		printerr("balance: unclean matches: %s vs %s" % [str(opponent), boss_id])
	var matches: int = int(report.seeds)
	_played += matches
	return {"wins": roundi((1.0 - float(report.win_rate)) * matches), "matches": matches}


func _play_classes(heroes: Array, bosses: Array, knobs: Dictionary) -> PackedStringArray:
	var classes: Dictionary = {}
	var by_boss: Dictionary = {}
	var by_band: Dictionary = {}
	var power_tables: Dictionary = {}
	for hero: Dictionary in heroes:
		print("balance: %s" % hero.id)
		var powers: Dictionary = {}
		for power: String in Heroes.power_ids(hero):
			for boss_id: String in bosses:
				var result: Dictionary = _match(boss_id, {"hero_id": hero.id, "hero_power": power}, _seeds)
				_tally(classes, str(hero.id), result.wins, result.matches)
				_tally(powers, power, result.wins, result.matches)
				_tally(by_boss, boss_id, result.wins, result.matches)
		power_tables[str(hero.id)] = powers
	for boss_id: String in by_boss:
		var band: int = int((_db.boss(boss_id) as Dictionary).band)
		if not by_band.has(band):
			by_band[band] = {}
		by_band[band][boss_id] = by_boss[boss_id]
	var sections: PackedStringArray = [BalanceReport.render_table("Classes", BalanceReport.compare(classes, float(knobs.class_tol)), float(knobs.class_tol))]
	for hero_id: String in power_tables:
		sections.append(BalanceReport.render_table("Powers: %s" % hero_id, BalanceReport.compare(power_tables[hero_id], float(knobs.power_tol)), float(knobs.power_tol)))
	var bands: Array = by_band.keys()
	bands.sort()
	for band: int in bands:
		sections.append(BalanceReport.render_table("Bosses: band %d" % band, BalanceReport.compare(by_band[band], float(knobs.boss_tol)), float(knobs.boss_tol)))
	return sections


func _play_archetypes(heroes: Array, args: Dictionary, knobs: Dictionary) -> String:
	var bosses: Array = _bosses(args, 1)
	var tables: Dictionary = {}
	var seen: Dictionary = {}
	for hero: Dictionary in heroes:
		for bundle: Dictionary in _db.bundle_pool(str(hero["set"])):
			var owner: String = str(bundle["set"])
			var theme: String = str(bundle.theme)
			var key: String = "%s/%s" % [owner, theme]
			if seen.has(key) or (args.has("archetype") and theme != str(args.archetype)):
				continue
			seen[key] = true
			print("balance: archetype %s" % key)
			if not tables.has(owner):
				tables[owner] = {}
			var deck: Array = _archetype_deck(hero, owner, theme)
			for boss_id: String in bosses:
				var result: Dictionary = _match(boss_id, {"hero_id": hero.id, "hero_power": str(hero.hero_power), "deck": deck}, _seeds)
				_tally(tables[owner], theme, result.wins, result.matches)
	var text: PackedStringArray = []
	var owners: Array = tables.keys()
	owners.sort()
	for owner: String in owners:
		text.append(BalanceReport.render_table("Archetypes: %s" % owner, BalanceReport.compare(tables[owner], float(knobs.archetype_tol)), float(knobs.archetype_tol)))
	return "\n".join(text)


# The starter with up to [constant MAX_ARCHETYPE_CARDS] of the theme's bundle cards in
# place of its neutral cards, last ones first.
func _archetype_deck(hero: Dictionary, owner: String, theme: String) -> Array:
	var deck: Array = (hero.starter_deck as Array).duplicate()
	var cards: Array = []
	for bundle: Dictionary in _db.bundle_pool(owner if owner != NEUTRAL_SET else str(hero["set"])):
		if str(bundle.theme) == theme and str(bundle["set"]) == owner:
			for card: Variant in bundle.cards:
				if not cards.has(card):
					cards.append(card)
	var slot: int = deck.size() - 1
	for card: Variant in cards.slice(0, MAX_ARCHETYPE_CARDS):
		while slot >= 0 and not str(deck[slot]).begins_with(NEUTRAL_PREFIX):
			slot -= 1
		if slot < 0:
			break
		deck[slot] = card
		slot -= 1
	return deck


func _document(sections: PackedStringArray) -> String:
	var header: String = "# Relative balance report, %s\n\nAI matches against bosses, using starter decks. Rates show how the AI plays, not how people play.\nA gap inside its margin of error may be noise.\n" % Time.get_date_string_from_system()
	return header + "\n" + "\n".join(sections)


func _write(text: String, out_dir: String) -> String:
	var _made: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var path: String = out_dir.path_join("%s.md" % Time.get_date_string_from_system())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null or not file.store_string(text):
		printerr("balance: cannot write %s" % path)
		return ""
	return path
