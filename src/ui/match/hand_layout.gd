## The hand's geometry as pure functions (match-ui F1, F2): no Node, no state, so a
## unit test runs them with an injected config. [param cfg] is `config("match_ui").hand`.
## [codeblock]
## for slot: Dictionary in HandLayout.fan(10, ui.config.hand):
##     print(slot.x, slot.y, slot.rot)
## var preview: Dictionary = HandLayout.hover(slot.x, ui.config.hand)
## [/codeblock]
class_name HandLayout
extends RefCounted


## F1 `s(n)`: the distance between neighbouring card centres.
static func spacing(n: int, cfg: Dictionary) -> float:
	var card_w: float = float(cfg.card_w)
	var step: float = card_w + float(cfg.hand_gap)
	if n < 2 or (n - 1) * step + card_w <= float(cfg.hand_w):
		return step
	return (float(cfg.hand_w) - card_w) / (n - 1)


## F1 for a hand of [param n]: one `{x, y, rot}` per card, left to right, `x` and `y`
## the card's bottom-centre pivot and `rot` in degrees.
static func fan(n: int, cfg: Dictionary) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var c: float = (n - 1) / 2.0
	var s: float = spacing(n, cfg)
	var theta: float = minf(float(cfg.theta_step_max), float(cfg.theta_total_max) / maxi(n - 1, 1))
	for i: int in n:
		var offset: float = i - c
		var arc: float = offset / maxf(c, 1.0)
		slots.append({
			"x": float(cfg.hand_cx) + offset * s,
			"y": float(cfg.hand_base_y) - float(cfg.arc_h) * (1.0 - arc * arc),
			"rot": offset * theta,
		})
	return slots


## F2 for a card at [param x]: `{x, y, rot, scale}`, upright on the baseline and clamped
## inside the viewport.
static func hover(x: float, cfg: Dictionary) -> Dictionary:
	var half: float = float(cfg.hover_scale) * float(cfg.card_w) / 2.0
	return {
		"x": clampf(x, half, float(cfg.viewport_w) - half),
		"y": float(cfg.hand_base_y),
		"rot": 0.0,
		"scale": float(cfg.hover_scale),
	}


## targeting.md §5.2 Parked source: 1.0x, upright, centred on its F1 x, its top at
## `park_top_y`.
static func parked(x: float, cfg: Dictionary) -> Dictionary:
	return {"x": x, "y": float(cfg.park_top_y) + float(cfg.card_h), "rot": 0.0, "scale": 1.0}


## True when [param point] lies on a card placed at [param slot], rotation included.
static func contains(point: Vector2, slot: Dictionary, cfg: Dictionary) -> bool:
	var pivot := Vector2(float(slot.x), float(slot.y))
	var local: Vector2 = (point - pivot).rotated(-deg_to_rad(float(slot.rot)))
	var scale: float = float(slot.get("scale", 1.0))
	var half_w: float = float(cfg.card_w) * scale / 2.0
	return absf(local.x) <= half_w and local.y <= 0.0 and local.y >= -float(cfg.card_h) * scale
