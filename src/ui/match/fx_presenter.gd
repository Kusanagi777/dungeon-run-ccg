## The particle layer of the match view (design/ux/keyword-and-effect-grammar.md
## "Particles"): one-shot bursts and flashes on top of the table, chosen per step
## from `config("match_ui").particles`, so every kind of change has one look.
##
## `particles.steps` maps a step kind to an effect name; `particles.effects` holds
## each effect as a list of emitters; `particles.textures` names the Kenney CC0
## sprites (`assets/art/fx/`). Some kinds choose by their data: a heavy hit, a buff
## or a debuff, the status a badge gained.
##
## Decorative only: an effect never carries state, so it may outlive its step by
## its own lifetime. A skip clears every live effect at once, nothing plays at
## `instant` (no step starts) or under `reduce_motion`, and `fast` doubles the rate.
## [codeblock]
## var fx := FxPresenter.new()
## fx.setup(ui)
## fx.on_step_started(step, 0.4)   # sparks on the hit target
## [/codeblock]
class_name FxPresenter
extends Presenter

const KIND_FLASH: String = "flash"
const STATUS_PREFIX: String = "status_"

var _view: MatchViewState = null
var _cfg: Dictionary = {}
var _textures: Dictionary = {}
## The rate multiplier of the current `anim_speed` (`fast` plays effects faster).
var speed_scale: float = 1.0


## A full-screen layer that takes no input.
func setup(context: MatchUiContext) -> void:
	super(context)
	_cfg = context.config.get("particles", {})
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = int(_cfg.get("z_index", 50))
	for key: Variant in (_cfg.get("textures", {}) as Dictionary):
		var path: String = str(_cfg.textures[key])
		if ResourceLoader.exists(path):
			_textures[str(key)] = load(path) as Texture2D


func bind(view_state: MatchViewState) -> void:
	_view = view_state


## Every step with an effect, whoever draws the rest of it.
func claims(step: AnimStep) -> bool:
	return (_cfg.get("steps", {}) as Dictionary).has(String(step.kind))


func owns(_entity_ids: Array[int]) -> bool:
	return false


func on_step_started(step: AnimStep, _d_eff: float) -> void:
	if ui.reduce_motion:
		return
	var effect: String = effect_for(step)
	if effect.is_empty():
		return
	for at: Vector2 in _anchors(step):
		spawn(effect, at)


func apply_final(step: AnimStep) -> void:
	end_step(step)


## A skip clears the layer: no burst survives the flush.
func on_skipped() -> void:
	super()
	for child: Node in get_children():
		child.queue_free()


func sync_report() -> Array[String]:
	return []


## The effect name for [param step]: the kind's entry in `particles.steps`, refined
## by the step's data where the table names a variant.
func effect_for(step: AnimStep) -> String:
	var effect: String = str((_cfg.get("steps", {}) as Dictionary).get(String(step.kind), ""))
	var effects: Dictionary = _cfg.get("effects", {})
	match step.kind:
		AnimStep.DAMAGE_POP:
			if int(step.data.get("amount", 0)) >= int(_cfg.get("heavy_hit", 5)) and effects.has(effect + "_heavy"):
				effect += "_heavy"
		AnimStep.STAT_RECOLOUR:
			effect = "buff" if bool(step.data.get("up", true)) else "debuff"
		AnimStep.BADGE:
			var added: Array = step.data.get("added", [])
			if added.is_empty():
				return ""
			var named: String = STATUS_PREFIX + str(added[0])
			effect = named if effects.has(named) else effect
	return effect if effects.has(effect) else ""


## Plays effect [param effect] centred on [param at] (global coordinates).
func spawn(effect: String, at: Vector2) -> void:
	for emitter: Dictionary in (_cfg.get("effects", {}) as Dictionary).get(effect, []):
		var texture: Texture2D = _textures.get(str(emitter.get("texture", "")))
		if texture == null:
			continue
		if str(emitter.get("kind", "")) == KIND_FLASH:
			_flash(texture, emitter, at - global_position)
		else:
			_burst(texture, emitter, at - global_position)


# The places a step's effect plays: each entity it names, else the zone it is about.
func _anchors(step: AnimStep) -> Array[Vector2]:
	var at: Array[Vector2] = []
	match step.kind:
		AnimStep.SPELL_CAST:
			at.append(ui.rect("cast_zone").get_center())
		AnimStep.BURN:
			var owner: String = str(step.data.get("side", "player"))
			at.append(ui.rect("player_deck" if owner == "player" else "boss_deck").get_center())
		AnimStep.SUMMON_FAILED:
			var row: Rect2 = ui.rect("player_row" if str(step.data.get("side", "player")) == "player" else "boss_row")
			at.append(Vector2(row.end.x - float(ui.config.board.token_w) / 2.0, row.get_center().y))
		AnimStep.ATTACK_LUNGE:
			if step.entity_ids.size() > 1:
				at.append(ui.locate.call(step.entity_ids[1]))
		_:
			var ids: Array[int] = step.entity_ids
			if step.kind == AnimStep.DAMAGE_POP or step.kind == AnimStep.HEAL_POP:
				ids = []
				for pop: AnimStep in (step.members if not step.members.is_empty() else [step] as Array[AnimStep]):
					ids.append_array(pop.entity_ids)
			# An id not on the table (a hand card's cost) locates to the table's centre:
			# no effect plays for it.
			var nowhere: Vector2 = ui.rect("viewport").get_center()
			for id: int in ids:
				if ui.locate.is_valid():
					var found: Vector2 = ui.locate.call(id)
					if found != nowhere:
						at.append(found)
	return at


func _burst(texture: Texture2D, e: Dictionary, at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.texture = texture
	p.position = at
	p.one_shot = true
	p.explosiveness = float(e.get("explosiveness", 1.0))
	p.amount = int(e.get("amount", 8))
	p.lifetime = float(e.get("lifetime", 0.5))
	p.speed_scale = speed_scale
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = float(e.get("radius", 6.0))
	p.direction = _vec(e.get("direction", [0, -1]))
	p.spread = float(e.get("spread", 180.0))
	p.gravity = _vec(e.get("gravity", [0, 0]))
	var speed: Array = e.get("speed", [60, 160])
	p.initial_velocity_min = float(speed[0])
	p.initial_velocity_max = float(speed[1])
	var scale: Array = e.get("scale", [0.1, 0.2])
	p.scale_amount_min = float(scale[0])
	p.scale_amount_max = float(scale[1])
	p.angle_min = 0.0
	p.angle_max = 360.0 if bool(e.get("spin", true)) else 0.0
	p.damping_min = float(e.get("damping", 0.0))
	p.damping_max = float(e.get("damping", 0.0))
	var colour: Color = _colour(e)
	var fade := Gradient.new()
	fade.set_color(0, colour)
	fade.set_color(1, Color(colour, 0.0))
	p.color_ramp = fade
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, float(e.get("scale_end", 0.4))))
	p.scale_amount_curve = shrink
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if bool(e.get("additive", true)) else CanvasItemMaterial.BLEND_MODE_MIX
	p.material = additive
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# One sprite that swells and fades: a flash, a slash, a rune.
func _flash(texture: Texture2D, e: Dictionary, at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = at
	sprite.modulate = _colour(e)
	var scale: Array = e.get("scale", [0.3, 0.6])
	sprite.scale = Vector2.ONE * float(scale[0])
	if bool(e.get("spin", false)):
		sprite.rotation = randf() * TAU
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if bool(e.get("additive", true)) else CanvasItemMaterial.BLEND_MODE_MIX
	sprite.material = additive
	add_child(sprite)
	var life: float = float(e.get("lifetime", 0.3)) / maxf(speed_scale, 0.01)
	var grow: Tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	grow.tween_property(sprite, "scale", Vector2.ONE * float(scale[1]), life)
	grow.tween_property(sprite, "modulate:a", 0.0, life)
	if bool(e.get("spin", false)):
		grow.tween_property(sprite, "rotation", sprite.rotation + float(e.get("turn", 1.5)), life)
	grow.chain().tween_callback(sprite.queue_free)


func _colour(e: Dictionary) -> Color:
	var token: String = str(e.get("color", "text_light"))
	var colour: Color = ui.color(token) if not token.begins_with("#") else Color(token)
	colour.a = float(e.get("alpha", 1.0))
	return colour


static func _vec(value: Variant) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value is Array and (value as Array).size() == 2 else Vector2.ZERO
