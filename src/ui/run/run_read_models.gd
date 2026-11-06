## Builds each U2 screen's read model (ADR-0011 Decision 2): a plain Dictionary from
## `RunMachine.read_model()`, Meta queries and Card Database records, with every id
## already turned into display text, so a screen resolves nothing. `RunController`
## owns one and is its only caller; nothing here issues a command.
## [codeblock]
## var models := RunReadModels.new(meta, db, ui_config)
## var model: Dictionary = models.boss_intro(run.read_model())
## [/codeblock]
class_name RunReadModels
extends RefCounted

## Colour tokens by hero set; another set reads as neutral.
const SET_PRIMARY: Dictionary = {"war": "war", "decay": "decay", "knowledge": "knowledge"}
const SET_SECONDARY: Dictionary = {"war": "war2", "decay": "decay2", "knowledge": "knowledge2"}
const NEUTRAL_TOKEN: String = "neutral"
const BAND_TOKEN: String = "boss_band_%d"
const STARTER_HERO: String = "hero_war"
const CELL_CLEARED: String = "cleared"
const CELL_KILLED: String = "killed"
const CELL_HOLLOW: String = "hollow"
const DRAFT_SLOTS: int = 3
const REMOVED_KEY: String = "common.removed"
const ROW_TOP_CARDS: int = 3
const SECONDS_PER_MINUTE: int = 60
const COST_BUCKETS: int = 6

var _meta: MetaApi
var _db: CardDatabase
var _config: Dictionary


## [param meta], [param db] and the `config("run_ui")` body [param ui_config].
func _init(meta: MetaApi, db: CardDatabase, ui_config: Dictionary) -> void:
	_meta = meta
	_db = db
	_config = ui_config


## `main_menu` (U2): the Continue card, the stats line and the status lines.
func main_menu(run_model: Dictionary, load_line: String, status_line: String) -> Dictionary:
	var stats: Dictionary = _meta.get_stats()
	var saved: Variant = run_model.get("saved_run")
	return {
		"continue_card": _continue_card(saved) if saved is Dictionary else null,
		"runs": int(stats.get("runs_started", 0)),
		"wins": int(stats.get("runs_won", 0)),
		"best_floor": int(stats.get("best_floor_reached", 0)),
		"load_line": load_line,
		"status_line": status_line,
	}


## `resume_prompt` (U2).
func resume_prompt(run_model: Dictionary) -> Dictionary:
	var saved: Variant = run_model.get("saved_run")
	return _continue_card(saved) if saved is Dictionary else {}


## `hero_select` (U2, U7): the panels, the locked row and the pre-selection.
func hero_select(run_model: Dictionary, seed_preview: Callable) -> Dictionary:
	var panels: Array[Dictionary] = []
	var locked: Array[Dictionary] = []
	for row: Dictionary in run_model.get("heroes", []):
		if bool(row.get("unlocked", true)):
			panels.append(_hero_panel(row))
		else:
			locked.append(_locked_panel(row))
	return {
		"heroes": panels,
		"locked": locked,
		"selected": _preselected(panels),
		"allow_custom_seed": bool(run_model.get("allow_custom_seed", false)),
		"text_scale": float(_meta.get_settings().get("text_scale", 1.0)),
		"seed_preview": seed_preview,
	}


## `run_start` (U2): the hero colour, the seed and how long the card stays.
func run_start(run_model: Dictionary, duration_ms: int) -> Dictionary:
	var hero: Dictionary = run_model.get("hero", {})
	return {
		"hero_name": str(hero.get("name", "")),
		"hero_color": SET_PRIMARY.get(str(hero.get("set", "")), NEUTRAL_TOKEN),
		"seed": str(run_model.get("run_seed_hex", "")),
		"duration_ms": duration_ms,
	}


## `boss_intro` (U2, S11b). The read model's `attempt` counts matches begun on this
## floor, so the coming one is that plus one (AC-29: "Attempt 2" after a fault).
func boss_intro(run_model: Dictionary) -> Dictionary:
	var boss: Dictionary = run_model.get("boss", {})
	var band: int = int(run_model.get("band", 1))
	var hero: Dictionary = run_model.get("hero", {})
	var power: Dictionary = _power_of(hero.get("hero_power"))
	return {
		"floor": int(run_model.get("floor", 1)),
		"floors": int(run_model.get("floors_per_run", 0)),
		"band": band,
		"band_color": BAND_TOKEN % band,
		"attempt": int(run_model.get("attempt", 0)) + 1,
		"boss_name": str(boss.get("name", "")),
		"boss_initial": _initial(str(boss.get("name", ""))),
		"boss_health": int(boss.get("health", 0)),
		"intro_text": RunText.data(boss.get("intro_text")),
		"passive_text": RunText.data(boss.get("passive_text")),
		"power_name": str(power.get("name", "")),
		"power_cost": power.get("cost"),
		"power_text": str(power.get("text", "")),
		"deck_size": int(run_model.get("deck_size", 0)),
		"strip": strip(run_model),
	}


## U6: the F nodes, the gem marks, the held treasures and the deck size. An upcoming
## node carries its band only, never its boss. A gem marks a floor a treasure was taken
## on, which is what AC-4's "two gem marks" at floor 4 counts.
func strip(run_model: Dictionary) -> Dictionary:
	var seen: Array = run_model.get("bosses_seen", [])
	var gem_floors: Array[int] = []
	for row: Dictionary in run_model.get("drafts", []):
		if str(row.get("kind")) == DraftRecord.KIND_TREASURE and row.get("picked_id") != null:
			gem_floors.append(int(row.get("floor", 0)))
	var nodes: Array[Dictionary] = []
	for pip: Dictionary in run_model.get("floors", []):
		var f: int = int(pip.get("floor", 0))
		var state: String = str(pip.get("state", RunCodes.PIP_UPCOMING))
		var boss_name: String = ""
		if state != RunCodes.PIP_UPCOMING and f - 1 < seen.size():
			boss_name = _boss_name(str(seen[f - 1]))
		nodes.append({
			"floor": f,
			"band": int(pip.get("band", 1)),
			"band_color": BAND_TOKEN % int(pip.get("band", 1)),
			"state": state,
			"initial": _initial(boss_name),
			"tip": _node_tip(f, state, boss_name, int(pip.get("band", 1))),
			"gem": gem_floors.has(f),
		})
	return {
		"nodes": nodes,
		"treasures": _treasure_rows(run_model.get("treasures", [])),
		"deck_size": int(run_model.get("deck_size", 0)),
	}


## `draft_treasure` and `draft_bundle` (U2, U8): `DRAFT_SLOTS` slots, the options first
## in `option_ids` order, then placeholders. [param reveal_step_ms] is F2's stagger.
func draft(run_model: Dictionary, reveal_step_ms: int) -> Dictionary:
	var offer: Dictionary = run_model.get("offer", {}) if run_model.get("offer") is Dictionary else {}
	var kind: String = str(offer.get("kind", DraftRecord.KIND_TREASURE))
	var ids: Array = offer.get("option_ids", [])
	var extras: Array = offer.get("options", [])
	var options: Array[Dictionary] = []
	for i: int in ids.size():
		var extra: Dictionary = extras[i] if i < extras.size() and extras[i] is Dictionary else {}
		if kind == DraftRecord.KIND_BUNDLE:
			options.append(_bundle_option(str(ids[i]), extra, int(offer.get("deck_size", 0)), int(offer.get("deck_size_after", 0))))
		else:
			options.append(_treasure_option(str(ids[i]), extra))
	var flags: Array = offer.get("flags", [])
	var reason: String = ""
	if ids.size() < DRAFT_SLOTS and (flags.has(String(Offer.FLAG_SHORT)) or flags.has(String(Offer.FLAG_REOFFER))):
		reason = RunText.t("draft.short.%s" % kind)
	return {
		"kind": kind,
		"floor": int(offer.get("floor", run_model.get("floor", 1))),
		"options": options,
		"slots": DRAFT_SLOTS,
		"reveal_step_ms": reveal_step_ms,
		"short_reason": reason,
		"allow_skip": bool(offer.get("allow_skip", false)),
		"two_step": _floor_has_treasure_step(run_model),
		"deck_rows": deck_rows(run_model.get("deck", []), run_model.get("deck_entries", [])),
		"treasures": _treasure_rows(run_model.get("treasures", [])),
		"deck_size": int(run_model.get("deck_size", 0)),
		"strip": strip(run_model),
	}


## `summary_*` and `run_detail` (U9), from a run read model in a terminal status.
## [param unlock_keys] are the keys this run granted; [param status_line] the latest
## actionable warning.
func summary(run_model: Dictionary, unlock_keys: Array, status_line: String) -> Dictionary:
	var data: Dictionary = run_model.get("summary", {})
	var hero: Dictionary = run_model.get("hero", {})
	var outcome: String = str(data.get("outcome", RunCodes.STATUS_DEFEAT))
	var floors: int = int(run_model.get("floors_per_run", 0))
	var top_rows: Array[Dictionary] = []
	for row: Dictionary in data.get("top_cards", []):
		top_rows.append({"name": _card_name(str(row.get("card_id", ""))), "damage": int(row.get("damage", 0))})
	var abandon_reason: Variant = data.get("abandon_reason")
	return {
		"outcome": outcome,
		"headline": _headline(data, outcome, floors, abandon_reason),
		"reason": _reason_line(run_model, outcome, abandon_reason),
		"hero_id": str(hero.get("id", "")),
		"hero_name": str(hero.get("name", hero.get("id", ""))),
		"hero_initial": _initial(str(hero.get("name", ""))),
		"hero_color": SET_PRIMARY.get(str(hero.get("set", "")), NEUTRAL_TOKEN),
		"hero_available": _meta.is_hero_unlocked(str(hero.get("id", ""))),
		"floors_cleared": int(data.get("floors_cleared", 0)),
		"floors": floors,
		"matches": int(data.get("matches_played", 0)),
		"turns": int(data.get("total_turns", 0)),
		"duration": _duration(int(data.get("play_seconds", 0))),
		"seed": str(run_model.get("run_seed_hex", "")),
		"custom_seed": str(run_model.get("seed_source", "")) == RunCodes.SEED_CUSTOM,
		"top_cards": top_rows,
		"more_cards": int(data.get("more_cards", 0)),
		"no_damage": bool(data.get("no_damage", true)),
		"cells": floor_cells(run_model),
		"deck_rows": deck_rows(run_model.get("deck", []), run_model.get("deck_entries", [])),
		"treasures": _treasure_rows(run_model.get("treasures", [])),
		"unlocks": unlock_lines(unlock_keys),
		"status_line": status_line,
		"focus": str((_config.default_focus as Dictionary).get("summary", "new_run_same_hero")),
	}


## `summary_abandoned` (U2): one line, New Run, Main Menu.
func summary_abandoned(run_model: Dictionary) -> Dictionary:
	var data: Dictionary = run_model.get("summary", {})
	var reason: String = str(data.get("abandon_reason", RunCodes.REASON_PLAYER))
	var hero: Dictionary = run_model.get("hero", {})
	return {
		"line": RunText.t("summary.abandoned.%s" % reason),
		"hero_id": str(hero.get("id", "")),
		"hero_available": _meta.is_hero_unlocked(str(hero.get("id", ""))),
	}


## U9's compact strip: one cell per floor, the killing boss's cell marked, later floors
## hollow, retried floors carrying their attempt.
func floor_cells(run_model: Dictionary) -> Array[Dictionary]:
	var by_floor: Dictionary = {}
	for row: Dictionary in run_model.get("match_summaries", []):
		by_floor[int(row.get("floor", 0))] = row
	var data: Dictionary = run_model.get("summary", {})
	var killed: int = int(data.get("floor_reached", 0)) if str(data.get("outcome")) == RunCodes.STATUS_DEFEAT else 0
	var cells: Array[Dictionary] = []
	for f: int in range(1, int(run_model.get("floors_per_run", 0)) + 1):
		var row: Dictionary = by_floor.get(f, {})
		var boss_name: String = _boss_name(str(row.get("boss_id", ""))) if not row.is_empty() else ""
		var state: String = CELL_HOLLOW
		if f == killed:
			state = CELL_KILLED
		elif not row.is_empty():
			state = CELL_CLEARED
		var attempt: int = int(row.get("attempt", 1))
		var tip: String = RunText.t("summary.cell.hollow", {"n": f}) if state == CELL_HOLLOW else RunText.t("summary.cell.%s" % state, {"n": f, "boss": boss_name})
		if attempt > 1:
			tip += " " + RunText.t("summary.cell.attempt", {"n": attempt})
		cells.append({
			"floor": f,
			"state": state,
			"initial": _initial(boss_name),
			"band_color": BAND_TOKEN % int(row.get("band", 1)),
			"attempt": attempt,
			"tip": tip,
		})
	return cells


## The final deck in acquisition order, `drafted` naming the floor a card came from.
func deck_rows(ids: Array, entries: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i: int in ids.size():
		var entry: Dictionary = entries[i] if i < entries.size() and entries[i] is Dictionary else {}
		var row: Dictionary = card_row(str(ids[i]))
		row["drafted"] = entry.get("drafted_on")
		rows.append(row)
	return rows


## One card as a list shows it: `{id, name, cost, text, stats}`. A removed id keeps its
## raw name (Edge Cases).
func card_row(card_id: String) -> Dictionary:
	if not _db.has(card_id):
		return {"id": card_id, "name": _card_name(card_id), "cost": "", "text": "", "stats": ""}
	var card: Dictionary = _db.card(card_id)
	var stats: String = ""
	if card.has("attack") and card.has("health"):
		stats = "%d/%d" % [int(card.attack), int(card.health)]
	elif card.has("attack") and card.has("durability"):
		stats = "%d/%d" % [int(card.attack), int(card.durability)]
	return {"id": card_id, "name": str(card.get("name", card_id)), "cost": str(int(card.get("cost", 0))), "text": RunText.data(card.get("text")), "stats": stats}


## The "New … unlocked" lines of [param keys], for the summary (U9).
func unlock_lines(keys: Array) -> Array[String]:
	var notes: Dictionary = {}
	for note: Variant in _meta.pending_notifications():
		if note is Dictionary:
			notes[str(note.get("key", ""))] = note
	var lines: Array[String] = []
	for key: Variant in keys:
		var note: Dictionary = notes.get(str(key), {})
		if note.is_empty():
			lines.append(RunText.t("unlock.line.generic", {"name": str(key)}))
		else:
			lines.append(str(unlock_toast(str(key), str(note.get("kind", "")), str(note.get("id", ""))).title))
	return lines


## An unlock toast's `{key, title, subtitle, swatch}` from `kind` + `id` (U5): the name
## comes from Card Database, the condition from Meta's hint.
func unlock_toast(key: String, kind: String, id: String) -> Dictionary:
	var name: String = id
	var swatch: String = NEUTRAL_TOKEN
	if _db.has(id):
		match kind:
			"hero":
				var hero: Dictionary = _db.hero(id)
				name = str(hero.get("name", id))
				swatch = SET_PRIMARY.get(str(hero.get("set", "")), NEUTRAL_TOKEN)
			"treasure":
				name = str((_db.treasure(id) as Dictionary).get("name", id))
			"bundle":
				name = str((_db.bundle(id) as Dictionary).get("name", id))
	return {"key": key, "title": RunText.t("unlock.toast.%s" % kind, {"name": name}), "subtitle": _hint_text(key), "swatch": swatch}


## `run_log` (U2; meta-progression AC-28): rows of [param entries] newest first, the
## per-hero stats line, the hero filter's choices.
func run_log(entries: Array, total: int) -> Dictionary:
	var rows: Array[Dictionary] = []
	var hero_ids: Array[String] = []
	for entry: Variant in entries:
		if entry is Dictionary:
			var row: Dictionary = _log_row(entry)
			rows.append(row)
			if not hero_ids.has(str(row.hero_id)):
				hero_ids.append(str(row.hero_id))
	var filters: Array[Dictionary] = []
	for hero_id: String in hero_ids:
		filters.append({"id": hero_id, "name": _hero_name(hero_id)})
	return {"rows": rows, "filters": filters, "stats_lines": _log_stats(), "total": total, "more": rows.size() < total}


## `run_detail` (U2) from one archived row, read-only.
func run_detail(entry: Dictionary) -> Dictionary:
	var model: Dictionary = summary(archived_model(entry), [], "")
	model["read_only"] = true
	return model


## `replay_list`: every archived match log of the run [param entry], in floor and attempt
## order, each with what [MatchReplay] says about it. The refusal copy lives with the
## viewer's strings, which nothing has installed before a first match.
func replays(entry: Dictionary) -> Dictionary:
	MatchStrings.install(_db, _db.config("match_ui"))
	var hero_id: String = str(entry.get("hero_id", ""))
	var bosses: Array = entry.get("boss_sequence", [])
	var rows: Array[Dictionary] = []
	for log_file: Dictionary in MatchReplay.archives(str(entry.get("run_id", ""))):
		var check: Dictionary = MatchReplay.inspect(log_file.path, _db)
		var floor_index: int = int(log_file.floor) - 1
		rows.append({
			"path": log_file.path,
			"label": RunText.t("replay.fault_row" if log_file.fault else "replay.row", {"floor": log_file.floor, "attempt": log_file.attempt}),
			"replayable": check.replayable,
			"reason": tr(str(check.reason_key)) if not check.replayable else "",
			"hero_id": hero_id,
			"boss_id": str(bosses[floor_index]) if floor_index >= 0 and floor_index < bosses.size() else "",
		})
	return {"rows": rows}


## The read model of a stored [param entry], the same one a finished run has.
func archived_model(entry: Dictionary) -> Dictionary:
	return RunRecord.from_dict(entry).read_model(_db, _db.config("run_structure"))


## `settings` (U2): the DD-X07 record and the reset token.
func settings() -> Dictionary:
	var knobs: Dictionary = (_db.config("profile_defaults") as Dictionary).get("knobs", {})
	return {"values": _meta.get_settings().duplicate(), "reset_token": str(knobs.get("reset_confirm_token", ""))}


## `controls` (Alpha, ADR-0004 addendum): one row per rebindable action with its keys.
## `cancel` / `ui_cancel` are never listed. A conflict counts within one group only: the
## same key may mean one thing on run screens and another in a match.
func controls() -> Dictionary:
	var rows: Array[Dictionary] = []
	var groups: Dictionary = (_config.controls as Dictionary).get("actions", {})
	for group: String in groups:
		var names_by_action: Dictionary = {}
		var seen: Dictionary = {}
		for action: String in groups[group]:
			if not InputMap.has_action(action) or ProfileSchema.UNREBINDABLE_ACTIONS.has(action):
				continue
			var names: PackedStringArray = []
			for event: InputEvent in InputMap.action_get_events(action):
				if event is InputEventKey or event is InputEventJoypadButton:
					names.append(event.as_text())
					seen[event.as_text()] = int(seen.get(event.as_text(), 0)) + 1
			names_by_action[action] = names
		for action: String in names_by_action:
			var conflict: bool = false
			for key_name: String in names_by_action[action]:
				conflict = conflict or int(seen[key_name]) > 1
			rows.append({"action": action, "label": RunText.t("controls.action.%s" % action), "keys": ", ".join(names_by_action[action]), "conflict": conflict})
	return {"rows": rows}


## `glossary` (accessibility "Tutorial persistence"): the DD-M09 keywords.
func glossary() -> Dictionary:
	var rows: Array[Dictionary] = []
	for keyword: String in (_config.glossary as Dictionary).get("keywords", []):
		rows.append({"name": RunText.t("glossary.%s.name" % keyword), "text": RunText.t("glossary.%s.text" % keyword)})
	return {"rows": rows}


## `pause` (U2) and the music slider the a11y remainder asks for.
func pause(run_model: Dictionary) -> Dictionary:
	return {"strip": strip(run_model), "volume_music": float(_meta.get_setting(&"volume_music"))}


## `data_error` (U2; AC-8): one row per report entry.
static func data_error(report: ValidationReport) -> Dictionary:
	var rows: Array[Dictionary] = []
	if report != null:
		for entry: Dictionary in report.errors() + report.warnings():
			rows.append({"file": str(entry.get("file", "")), "id": str(entry.get("record_id", "")), "code": str(entry.get("code", "")), "message": str(entry.get("message", ""))})
	return {"rows": rows, "report_text": report.to_text() if report != null else ""}


func _continue_card(saved: Dictionary) -> Dictionary:
	var phase: String = str(saved.get("phase", ""))
	return {
		"hero_name": _hero_name(str(saved.get("hero_id", ""))),
		"floor": int(saved.get("floor", 1)),
		"floors": int(saved.get("floors_per_run", 0)),
		"phase": RunText.t("phase.%s" % phase),
		"last_played": _date(saved.get("updated_at")),
	}


func _hero_panel(row: Dictionary) -> Dictionary:
	var id: String = str(row.id)
	var set_id: String = str(row.get("set", ""))
	var hero: Dictionary = _db.hero(id) if _db.has(id) else {}
	var power: Dictionary = _power_of(row.get("hero_power"))
	var stats: Dictionary = _meta.stats_for_hero(id)
	var ids: Array = row.get("starter_deck", [])
	return {
		"id": id,
		"name": str(row.get("name", id)),
		"initial": _initial(str(row.get("name", id))),
		"health": int(row.get("health", 0)),
		"identity": RunText.data(hero.get("text")),
		"blurb": RunText.t("hero.blurb.%s" % set_id),
		"primary": SET_PRIMARY.get(set_id, NEUTRAL_TOKEN),
		"secondary": SET_SECONDARY.get(set_id, NEUTRAL_TOKEN),
		"power_name": str(power.get("name", "")),
		"power_cost": power.get("cost"),
		"power_text": str(power.get("text", "")),
		"stats_line": RunText.t("hero.stats", {"w": int(stats.get("runs_won", stats.get("wins", 0))), "l": int(stats.get("runs_lost", stats.get("losses", 0))), "f": int(stats.get("best_floor_reached", stats.get("best_floor", 0)))}),
		"stats_short": RunText.t("hero.stats_short", {"w": int(stats.get("runs_won", stats.get("wins", 0))), "l": int(stats.get("runs_lost", stats.get("losses", 0))), "f": int(stats.get("best_floor_reached", stats.get("best_floor", 0)))}),
		"curve": _curve(ids),
		"deck_rows": deck_rows(ids, []),
	}


func _locked_panel(row: Dictionary) -> Dictionary:
	var id: String = str(row.id)
	var hint: Dictionary = _meta.unlock_hint(id)
	var text_key: String = str(hint.get("text_key", ""))
	var hint_text: String = ""
	if not text_key.is_empty():
		hint_text = RunText.t(text_key, {"n": hint.get("target", 1)})
		if hint.get("target") != null:
			var target: int = int(hint.target)
			hint_text = RunText.t("hero.locked.progress", {"hint": hint_text, "have": floori(float(hint.get("progress", 0.0)) * target), "need": target})
	return {"id": id, "name": str(row.get("name", id)), "hint": hint_text}


func _preselected(panels: Array[Dictionary]) -> String:
	var mode: String = str(_config.preselect_hero)
	if mode == "none" or panels.is_empty():
		return ""
	var last: Variant = _meta.last_hero_id() if mode == "last_played" else null
	for wanted: Variant in [last, STARTER_HERO]:
		for panel: Dictionary in panels:
			if panel.id == wanted:
				return str(panel.id)
	return str(panels[0].id)


func _curve(ids: Array) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(COST_BUCKETS)
	for card_id: Variant in ids:
		if _db.has(str(card_id)):
			var cost: int = int((_db.card(str(card_id)) as Dictionary).get("cost", 0))
			counts[mini(cost, COST_BUCKETS - 1)] += 1
	return counts


func _power_of(power_id: Variant) -> Dictionary:
	if not power_id is String or not _db.has(power_id):
		return {}
	var power: Dictionary = _db.hero_power(power_id)
	return {"name": str(power.get("name", power_id)), "cost": int(power.get("cost", 0)), "text": RunText.data(power.get("text"))}


func _treasure_option(id: String, extra: Dictionary) -> Dictionary:
	if not _db.has(id):
		return {"id": id, "missing": true, "name": RunText.t("draft.missing", {"id": id})}
	var treasure: Dictionary = _db.treasure(id)
	return {
		"id": id,
		"missing": false,
		"name": str(treasure.get("name", id)),
		"rarity": RunText.t("rarity.%s" % str(treasure.get("rarity", "common"))),
		"text": RunText.data(treasure.get("text")),
		"hint": RunText.t("draft.hint.affine") if int(extra.get("affine", 0)) == 1 else "",
	}


func _bundle_option(id: String, extra: Dictionary, deck_size: int, deck_after: int) -> Dictionary:
	if not _db.has(id):
		return {"id": id, "missing": true, "name": RunText.t("draft.missing", {"id": id})}
	var bundle: Dictionary = _db.bundle(id)
	var theme: String = RunText.t("theme.%s" % str(bundle.get("theme", "")))
	var rows: Array[Dictionary] = []
	for card_id: Variant in bundle.get("cards", []):
		rows.append(card_row(str(card_id)))
	return {
		"id": id,
		"missing": false,
		"name": theme,
		"pitch": RunText.data(bundle.get("text")),
		"cards": rows,
		"hint": RunText.t("draft.hint.theme", {"n": int(extra.n_tag), "theme": theme}) if extra.has("n_tag") else "",
		"hint2": RunText.t("draft.hint.deck", {"a": deck_size, "b": deck_after}),
	}


func _floor_has_treasure_step(run_model: Dictionary) -> bool:
	var floor_number: int = int(run_model.get("floor", 0))
	for row: Dictionary in run_model.get("drafts", []):
		if int(row.get("floor", 0)) == floor_number and str(row.get("kind")) == DraftRecord.KIND_TREASURE:
			return true
	var offer: Variant = run_model.get("offer")
	return offer is Dictionary and str(offer.get("kind")) == DraftRecord.KIND_TREASURE


func _treasure_rows(ids: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id: Variant in ids:
		var known: bool = _db.has(str(id))
		var treasure: Dictionary = _db.treasure(str(id)) if known else {}
		var name: String = str(treasure.get("name", RunText.t(REMOVED_KEY, {"id": id})))
		rows.append({"id": str(id), "name": name, "initial": _initial(name), "text": RunText.data(treasure.get("text"))})
	return rows


func _headline(data: Dictionary, outcome: String, floors: int, abandon_reason: Variant) -> String:
	match outcome:
		RunCodes.STATUS_VICTORY:
			return RunText.t("summary.headline.victory", {"f": floors})
		RunCodes.STATUS_ABANDONED:
			return RunText.t("summary.abandoned.%s" % str(abandon_reason))
	var boss: Variant = data.get("ended_by_name")
	return RunText.t("summary.headline.defeat", {"n": int(data.get("floor_reached", 0)), "boss": str(boss) if boss != null else ""})


func _reason_line(run_model: Dictionary, outcome: String, abandon_reason: Variant) -> String:
	if outcome == RunCodes.STATUS_ABANDONED:
		return RunText.t("summary.abandoned.%s" % str(abandon_reason))
	var rows: Array = run_model.get("match_summaries", [])
	if rows.is_empty():
		return ""
	return RunText.t("summary.reason.%s.%s" % [outcome, str((rows[rows.size() - 1] as Dictionary).get("reason", ""))])


func _log_row(entry: Dictionary) -> Dictionary:
	var run_id: String = str(entry.get("run_id", ""))
	var hero_id: String = str(entry.get("hero_id", ""))
	var row: Dictionary = {
		"run_id": run_id,
		"hero_id": hero_id,
		"hero": _hero_name(hero_id),
		"date": _date(entry.get("ended_at", entry.get("started_at"))),
		"seed": str(entry.get("run_seed_hex", "")),
		"custom_seed": str(entry.get("seed_source", "")) == RunCodes.SEED_CUSTOM,
		"details": int(entry.get("schema_version", 0)) == RunRecord.SCHEMA_VERSION,
		"replays": MatchReplay.archives(run_id).size(),
	}
	if not bool(row.details):
		row["result"] = RunText.t("log.details_unavailable")
		row["floors"] = ""
		row["deck_size"] = 0
		row["top_cards"] = ""
		row["retried"] = false
		return row
	var model: Dictionary = archived_model(entry)
	var data: Dictionary = model.get("summary", {})
	var outcome: String = str(data.get("outcome", ""))
	var names: PackedStringArray = []
	for card: Dictionary in (data.get("top_cards", []) as Array).slice(0, ROW_TOP_CARDS):
		names.append(_card_name(str(card.get("card_id", ""))))
	row["result"] = _log_result(data, outcome)
	row["floors"] = RunText.t("log.floors", {"n": int(data.get("floors_cleared", 0)), "f": int(model.get("floors_per_run", 0))})
	row["deck_size"] = int(model.get("deck_size", 0))
	row["top_cards"] = ", ".join(names)
	row["retried"] = not (data.get("retried_floors", []) as Array).is_empty()
	return row


func _log_result(data: Dictionary, outcome: String) -> String:
	match outcome:
		RunCodes.STATUS_VICTORY:
			return RunText.t("log.result.victory")
		RunCodes.STATUS_ABANDONED:
			return RunText.t("log.result.abandoned")
	return RunText.t("log.result.defeat", {"n": int(data.get("floor_reached", 0)), "boss": str(data.get("ended_by_name", ""))})


func _log_stats() -> PackedStringArray:
	var lines: PackedStringArray = []
	for hero: Dictionary in _db.heroes():
		var stats: Dictionary = _meta.stats_for_hero(str(hero.id))
		if int(stats.get("runs_started", 0)) > 0:
			lines.append(RunText.t("log.stats", {"hero": str(hero.get("name", hero.id)), "w": int(stats.get("runs_won", 0)), "l": int(stats.get("runs_lost", 0)), "f": int(stats.get("best_floor_reached", 0))}))
	return lines


func _hint_text(key: String) -> String:
	var hint: Dictionary = _meta.unlock_hint(key)
	var text_key: String = str(hint.get("text_key", ""))
	return RunText.t(text_key, {"n": hint.get("target", 1)}) if not text_key.is_empty() else ""


func _node_tip(f: int, state: String, boss_name: String, band: int) -> String:
	match state:
		RunCodes.PIP_CLEARED:
			return RunText.t("strip.tip.cleared", {"n": f, "boss": boss_name})
		RunCodes.PIP_CURRENT:
			return RunText.t("strip.tip.current", {"n": f, "boss": boss_name})
	return RunText.t("strip.tip.upcoming", {"n": f, "band": band})


func _boss_name(boss_id: String) -> String:
	return str((_db.boss(boss_id) as Dictionary).get("name", boss_id)) if _db.has(boss_id) else RunText.t(REMOVED_KEY, {"id": boss_id})


func _hero_name(hero_id: String) -> String:
	return str((_db.hero(hero_id) as Dictionary).get("name", hero_id)) if _db.has(hero_id) else RunText.t(REMOVED_KEY, {"id": hero_id})


## `damage_by_card` also names hero powers and treasures, so any record may be asked for.
func _card_name(card_id: String) -> String:
	var record: Variant = _db.any_record(card_id)
	return str((record as Dictionary).get("name", card_id)) if record is Dictionary else RunText.t(REMOVED_KEY, {"id": card_id})


func _initial(text: String) -> String:
	var words: PackedStringArray = text.trim_prefix(RunText.t("common.article")).strip_edges().split(" ", false)
	return words[0].left(1).to_upper() if not words.is_empty() else ""


func _date(unix_time: Variant) -> String:
	if not (unix_time is int or unix_time is float):
		return ""
	return Time.get_date_string_from_unix_time(int(unix_time))


func _duration(seconds: int) -> String:
	@warning_ignore("integer_division")
	return RunText.t("summary.duration", {"m": seconds / SECONDS_PER_MINUTE, "s": "%02d" % (seconds % SECONDS_PER_MINUTE)})
