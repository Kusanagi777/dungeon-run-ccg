## The event feed's arithmetic and wording (match-ui U10, F5), pure: lines in, rows and
## text out. No Node, no clock. `FeedPresenter` draws what this returns.
##
## A line is the view-state's `{key, params, group_id, seq}`. A group is every line
## sharing a `group_id`, its command root (U3): the line whose `seq` is the `group_id`
## heads it and the rest are its children. A group whose root made no line (a diagnostic
## or a silent type) has no head, so all its lines are children. F5 counts children.
##
## `quiet` keys are lines the feed keeps but does not show: the bookkeeping events
## (`feed_quiet_types` in `match_ui.json`) would push every readable line out of a
## 3-line ticker. The view-state still holds them, so `FEED_MAX_LINES` is unchanged.
## [codeblock]
## var shown: Array[Dictionary] = FeedLines.shown(view.feed_lines, quiet)
## for row: Dictionary in FeedLines.rows(shown, 6, {}):
##     print(row.kind, row.get("line"), row.get("hidden"))
## FeedLines.line_budget(20, 6)   # 7
## [/codeblock]
class_name FeedLines
extends RefCounted

## `rows()` kinds: a group's head, an indented child, and the "+N more" row.
const ROW_ROOT: StringName = &"root"
const ROW_CHILD: StringName = &"child"
const ROW_MORE: StringName = &"more"
const FEED_PREFIX: String = "feed."
const KEY_SIDE: String = "feed.side.%s"
const KEY_MORE: String = "feed.more"
const KEY_INTENT: String = "intent.%s"
const KEY_REJECT: String = "reject.%s"
## Params that hold an entity id, read through [FeedNames].
const ENTITY_FIELDS: Array[String] = [
	"source", "target", "target_id", "entity_id", "instance_id", "attacker", "defender",
	"attacker_id", "defender_id", "source_id",
]


## F5: the rows [param children] child lines take, the "+N more" row included.
static func line_budget(children: int, collapse: int) -> int:
	return mini(children, collapse) + (1 if children > collapse else 0)


## [param lines] without the keys of [param quiet] (`{feed key: true}`), oldest first.
static func shown(lines: Array, quiet: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: Dictionary in lines:
		if not quiet.has(str(line.get("key", ""))):
			out.append(line)
	return out


## The set [method shown] takes, from `feed_quiet_types`.
static func quiet_keys(types: Array) -> Dictionary:
	var keys: Dictionary = {}
	for type: Variant in types:
		keys[FEED_PREFIX + str(type)] = true
	return keys


## The ticker: the newest [param count] of [param lines], oldest first.
static func newest(lines: Array[Dictionary], count: int) -> Array[Dictionary]:
	return lines.slice(maxi(lines.size() - count, 0))


## The rows of [param lines], groups in order of first appearance: `{kind, line,
## group_id}`, and for [constant ROW_MORE] `{kind, group_id, hidden}`. A group past
## [param collapse] children is cut to its first [param collapse] and a more row,
## unless [param expanded] holds its `group_id`.
static func rows(lines: Array[Dictionary], collapse: int, expanded: Dictionary) -> Array[Dictionary]:
	var order: Array[int] = []
	var groups: Dictionary = {}
	for line: Dictionary in lines:
		var group: int = int(line.get("group_id", 0))
		if not groups.has(group):
			groups[group] = []
			order.append(group)
		(groups[group] as Array).append(line)
	var out: Array[Dictionary] = []
	for group: int in order:
		var children: Array[Dictionary] = []
		for line: Dictionary in groups[group]:
			if int(line.get("seq", -1)) == group:
				out.append({"kind": ROW_ROOT, "line": line, "group_id": group})
			else:
				children.append(line)
		var limit: int = children.size() if expanded.has(group) else mini(children.size(), collapse)
		for i: int in limit:
			out.append({"kind": ROW_CHILD, "line": children[i], "group_id": group})
		if limit < children.size():
			out.append({"kind": ROW_MORE, "group_id": group, "hidden": children.size() - limit})
	return out


## [param line] as text: its key's string with the params filled in, every id and card
## through [param names]. A key with no string reads as the key, so a gap shows.
static func text(line: Dictionary, names: FeedNames) -> String:
	return _translate(str(line.get("key", ""))).format(values_for(line, names))


## "+N more" for [param hidden] lines.
static func more_text(hidden: int) -> String:
	return _translate(KEY_MORE).format({"n": hidden})


## The `{placeholder: text}` of [param line]: its scalar params, with ids, cards, sides,
## intents and rejection codes resolved. A nested value is dropped: no string prints one.
static func values_for(line: Dictionary, names: FeedNames) -> Dictionary:
	var params: Dictionary = line.get("params", {})
	var values: Dictionary = {}
	for field: Variant in params:
		var value: Variant = params[field]
		if not (value is Dictionary or value is Array):
			values[str(field)] = value
	for field: String in ENTITY_FIELDS:
		if params.has(field):
			values[field] = names.of(params[field])
	values["card"] = names.card(str(params.get("card_id", params.get("picked_card_id", ""))))
	values["side"] = _translate(KEY_SIDE % str(params.get("side", "")))
	if params.has("intent_key"):
		values["intent"] = _translate(KEY_INTENT % str(params.intent_key))
	if params.has("code"):
		values["reason"] = _translate(KEY_REJECT % str(params.code))
	return values


static func _translate(key: String) -> String:
	return String(TranslationServer.translate(key))
