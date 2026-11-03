## The one channel player settings travel on (ADR-0004 Decision 9; ADR-0011
## Decision 4; architecture.md §Module Ownership, Foundation, `SettingsBus`).
##
## A `RefCounted` with one signal. The profile owner (`MetaStub` for the MVP,
## `ProfileStore` later) calls [method publish] after it has stored a value;
## every consumer (Run UI's `RunShell`, Match UI's `MatchView`, `BossAI`)
## connects to [signal settings_changed] and applies its own keys. The bus
## keeps the last value published per key so a consumer that connects late
## (Match UI mounts after the profile is published) can ask [method get_setting].
##
## The bus performs no validation and no clamping — that is the owner's job
## (meta-progression M9 ranges). It holds no scene-tree object and runs no tick
## (gates G1–G3, G2b), and it is single-thread-only: publish and read on the
## main thread.
##
## Usage (owner side, after storing a validated value):
## [codeblock]
## var bus := SettingsBus.new()
## bus.publish(&"gamma", 1.2)          # emits settings_changed(&"gamma", 1.2) once
## [/codeblock]
## Usage (consumer side):
## [codeblock]
## bus.settings_changed.connect(_on_settings_changed)
## var gamma: Variant = bus.get_setting(&"gamma")   # null until published
## [/codeblock]
class_name SettingsBus
extends RefCounted


## Fired exactly once per [method publish] call, synchronously, with the key and
## the value the owner stored (ADR-0011 Key Interfaces).
signal settings_changed(key: StringName, value: Variant)


## Last value published per key — the only state the bus owns.
var _last_published: Dictionary[StringName, Variant] = {}


## Records [param value] as the current value of [param key] and emits
## [signal settings_changed] once with [code](key, value)[/code] before
## returning. The profile owner is the only caller (architecture.md Data Flow 5
## step 4); it validates [param value] against M9 first. Containers are stored
## by reference, as given — the owner hands over its own copy.
## [codeblock]
## bus.publish(&"anim_speed", "fast")
## [/codeblock]
func publish(key: StringName, value: Variant) -> void:
	_last_published[key] = value
	settings_changed.emit(key, value)


## Returns the value last published for [param key], or [code]null[/code] when
## nothing was published for it (ADR-0011 Key Interfaces).
## [codeblock]
## var scale: Variant = bus.get_setting(&"text_scale")
## [/codeblock]
func get_setting(key: StringName) -> Variant:
	return _last_published.get(key)
