## What `Boot.boot()` returns (ADR-0001 Key Interfaces): whether the
## composition root came up, the Card Database load report, and the state the
## load ended in.
##
## `load_status` is the `CardDatabase` state name after the load —
## `&"Ready"` or `&"Failed"` (card-database States table). A scene root opens
## the `data_error` screen with `report.to_text()` when `ok` is false.
##
## [codeblock]
## var result: BootResult = Boot.boot()
## if not result.ok:
##     print(result.report.to_text())   # result.load_status == &"Failed"
## [/codeblock]
class_name BootResult
extends RefCounted

## True when the Card Database load ended `Ready` and every service was placed.
var ok: bool
## The Card Database load report: warnings only when `ok`, every error when not.
var report: ValidationReport
## The `CardDatabase` state name after the load: `&"Ready"` or `&"Failed"`.
var load_status: StringName


## A result with the three fields set as given.
## Example: `BootResult.new(true, db.report(), &"Ready")`.
func _init(p_ok: bool, p_report: ValidationReport, p_load_status: StringName) -> void:
	ok = p_ok
	report = p_report
	load_status = p_load_status
