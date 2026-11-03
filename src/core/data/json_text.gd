## Parses one JSON document held in memory (ADR-0002 Decision 2 parser form;
## ADR-0003 Decision 9 `from_json`).
##
## The single-parser gate (`tests/unit/card_database/card_database_single_parser_test.gd`)
## keeps every `JSON` instance under `src/core/data/`. A system that must read
## JSON text that is not game data — the event log's `from_json` (a bug-report
## attachment or a replay input), later the profile — calls this instead of
## holding a parser of its own, so the gate still finds one parser home.
## Game data is never read through here: it goes through `CardDatabase` /
## `DataLoader`, which also apply CR-1's strict-JSON scan and the envelope.
##
## The instance form is used because only it exposes the error line and
## message; `get_error_line()` is 0-based on 4.7.2 (observed, see
## `DataLoader`), so `line` here is 1-based. Every number comes back as a
## `float` (probe E): callers coerce integral values themselves.
##
## [codeblock]
## var parsed: Dictionary = JsonText.parse("{\"a\": 1}")
## parsed.ok        # true
## parsed.data.a    # 1.0 (a float)
## JsonText.parse("{\"a\": }").line   # 1
## [/codeblock]
##
## Pure and stateless; safe on any thread.
class_name JsonText
extends RefCounted


## Parses `text`. Returns `{ok: bool, data: Variant, line: int, message: String}`:
## on success `ok` is true, `data` the parsed value, `line` 0 and `message`
## `""`; on failure `ok` is false, `data` `null`, `line` the 1-based error line
## and `message` the parser's message. Never asserts.
## Example: `var r: Dictionary = JsonText.parse(text); if not r.ok: push_error(r.message)`.
static func parse(text: String) -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "data": null, "line": json.get_error_line() + 1, "message": json.get_error_message()}
	return {"ok": true, "data": json.data, "line": 0, "message": ""}
