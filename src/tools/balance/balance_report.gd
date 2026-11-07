## The relative balance report: each group is compared with the median of its peers, so it
## works at any content size. Observations only: it flags gaps and a person decides.
## [codeblock]
## var rows := BalanceReport.compare({"a": {"wins": 5, "matches": 10}}, 5.0)
## print(BalanceReport.render_table("Classes", rows, 5.0))
## [/codeblock]
class_name BalanceReport
extends RefCounted

const PERCENT: float = 100.0
## z for a 95 % margin of error.
const Z_95: float = 1.96


## One row per id of [param tallies] (`id -> {wins, matches}`), sorted by id:
## `{id, rate, median, gap, margin, matches, out_of_tolerance, certain}`. Rates are percent.
## `certain` is true when the gap is larger than the row's margin of error.
static func compare(tallies: Dictionary, tolerance: float) -> Array[Dictionary]:
	var rates: Array[float] = []
	for id: Variant in tallies:
		rates.append(_rate(tallies[id]))
	var middle: float = median(rates)
	var ids: Array = tallies.keys()
	ids.sort()
	var rows: Array[Dictionary] = []
	for id: Variant in ids:
		var tally: Dictionary = tallies[id]
		var rate: float = _rate(tally)
		var gap: float = rate - middle
		var margin: float = _margin(int(tally.wins), int(tally.matches))
		rows.append({
			"id": str(id), "rate": rate, "median": middle, "gap": gap, "margin": margin, "matches": int(tally.matches),
			"out_of_tolerance": absf(gap) > tolerance, "certain": absf(gap) > margin,
		})
	return rows


## The median of [param values], 0 for none.
static func median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var half: int = sorted.size() / 2
	return sorted[half] if sorted.size() % 2 == 1 else (sorted[half - 1] + sorted[half]) / 2.0


## A markdown table of [param rows] under [param title].
static func render_table(title: String, rows: Array[Dictionary], tolerance: float) -> String:
	var lines: PackedStringArray = ["## %s (tolerance %.0f points)" % [title, tolerance], ""]
	lines.append("| Group | Player win rate | Gap from median | Margin | Matches | Note |")
	lines.append("| --- | --- | --- | --- | --- | --- |")
	for row: Dictionary in rows:
		lines.append("| %s | %.1f%% | %+.1f | ±%.1f | %d | %s |" % [row.id, row.rate, row.gap, row.margin, row.matches, _note(row)])
	lines.append("")
	return "\n".join(lines)


static func _note(row: Dictionary) -> String:
	if not bool(row.out_of_tolerance):
		return ""
	return "out of tolerance" if bool(row.certain) else "out of tolerance, within noise"


static func _rate(tally: Dictionary) -> float:
	var matches: int = int(tally.matches)
	return PERCENT * float(tally.wins) / float(matches) if matches > 0 else 0.0


# Agresti-Coull: two wins and two losses are added first, so a small sample at 0 % or
# 100 % still shows a wide margin and not a false certainty.
static func _margin(wins: int, matches: int) -> float:
	if matches <= 0:
		return 0.0
	var trials: float = float(matches) + 4.0
	var p: float = (float(wins) + 2.0) / trials
	return PERCENT * Z_95 * sqrt(p * (1.0 - p) / trials)
