class_name Ambient
extends Node2D
## Screen-space weather/atmosphere particles per biome.

var _current: CPUParticles2D
static var _dot: Texture2D
static var _streak: Texture2D


static func dot_texture() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 32
		t.height = 32
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_dot = t
	return _dot


static func streak_texture() -> Texture2D:
	if _streak == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.set_color(1, Color(1, 1, 1, 1))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 4
		t.height = 44
		t.fill_from = Vector2(0.5, 0.0)
		t.fill_to = Vector2(0.5, 1.0)
		_streak = t
	return _streak


static func fade_ramp(col: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	g.colors = PackedColorArray([Color(col, 0.0), col, col, Color(col, 0.0)])
	return g


func set_biome(b: Dictionary) -> void:
	if _current:
		var old := _current
		old.emitting = false
		get_tree().create_timer(10.0).timeout.connect(old.queue_free)
	_current = _make(String(b.ambient), b.ambient_color)
	add_child(_current)


func _make(kind: String, col: Color) -> CPUParticles2D:
	var size := get_viewport_rect().size
	var p := CPUParticles2D.new()
	p.texture = dot_texture()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.position = size * 0.5
	p.emission_rect_extents = size * 0.55
	p.color_ramp = fade_ramp(col)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	match kind:
		"seeds":
			p.amount = 28
			p.lifetime = 9.0
			p.direction = Vector2(-1, -0.25)
			p.spread = 25.0
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 80.0
			p.gravity = Vector2(0, -4)
			p.scale_amount_min = 0.25
			p.scale_amount_max = 0.5
		"sparkle":
			p.amount = 34
			p.lifetime = 2.2
			p.position = Vector2(size.x * 0.5, size.y * 0.75)
			p.emission_rect_extents = Vector2(size.x * 0.55, size.y * 0.25)
			p.direction = Vector2(-1, 0)
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 30.0
			p.gravity = Vector2.ZERO
			p.scale_amount_min = 0.12
			p.scale_amount_max = 0.32
			p.material = add
		"rain":
			p.texture = streak_texture()
			p.amount = 170
			p.lifetime = 0.9
			p.position = Vector2(size.x * 0.6, -40)
			p.emission_rect_extents = Vector2(size.x * 0.75, 10)
			p.direction = Vector2(-0.35, 1)
			p.spread = 3.0
			p.initial_velocity_min = 900.0
			p.initial_velocity_max = 1200.0
			p.gravity = Vector2.ZERO
			p.particle_flag_align_y = true
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.1
			p.color_ramp = fade_ramp(Color(col, 0.45))
		"embers":
			p.amount = 60
			p.lifetime = 5.0
			p.position = Vector2(size.x * 0.5, size.y * 0.8)
			p.emission_rect_extents = Vector2(size.x * 0.6, size.y * 0.3)
			p.direction = Vector2(-0.3, -1)
			p.spread = 30.0
			p.initial_velocity_min = 40.0
			p.initial_velocity_max = 120.0
			p.gravity = Vector2(0, -18)
			p.scale_amount_min = 0.1
			p.scale_amount_max = 0.28
			p.material = add
		"fireflies":
			p.amount = 46
			p.lifetime = 6.0
			p.position = Vector2(size.x * 0.5, size.y * 0.62)
			p.emission_rect_extents = Vector2(size.x * 0.55, size.y * 0.35)
			p.direction = Vector2(0, -1)
			p.spread = 180.0
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 30.0
			p.gravity = Vector2.ZERO
			p.tangential_accel_min = -25.0
			p.tangential_accel_max = 25.0
			p.scale_amount_min = 0.2
			p.scale_amount_max = 0.45
			p.material = add
		_:
			p.amount = 44
			p.lifetime = 4.0
			p.direction = Vector2(-0.4, 1)
			p.spread = 40.0
			p.initial_velocity_min = 15.0
			p.initial_velocity_max = 40.0
			p.gravity = Vector2(0, 10)
			p.scale_amount_min = 0.1
			p.scale_amount_max = 0.3
			p.material = add
	p.preprocess = p.lifetime
	p.emitting = true
	return p


## One-shot world-space burst (splash, perfect landing, confetti).
static func burst(parent: Node, pos: Vector2, col: Color, amount: int, speed: float, up: bool = true) -> void:
	var p := CPUParticles2D.new()
	p.texture = dot_texture()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.8
	p.position = pos
	p.direction = Vector2(0, -1) if up else Vector2(1, 0)
	p.spread = 70.0 if up else 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 900) if up else Vector2(0, 200)
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	p.color_ramp = fade_ramp(col)
	p.z_index = 5
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(1.5).timeout.connect(p.queue_free)
