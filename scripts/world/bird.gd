class_name Bird
extends Node2D
## The player. Hold = rise (costs stamina), release = glide down. Runs along the ground.

signal landed(bonk: bool)
signal took_off
signal splashed
signal skimmed(duration: float)    # flew low over land long enough ("NYEREMPET")

const GRAVITY := 1300.0
const LIFT := 2900.0
const MAX_RISE := 620.0
const MAX_FALL := 520.0
const SPEED_START := 420.0
const SPEED_MAX := 740.0
const SPEED_RAMP_X := 60000.0
const SPEED_ACCEL := 600.0
const CEILING_SOFT := -1200.0
const CEILING_HARD := -1500.0
const STAMINA_DRAIN := 0.4
const STAMINA_REGEN_AIR := 0.33
const STAMINA_REGEN_GROUND := 0.8
const STAMINA_RESUME := 0.2
const BONK_SLOPE := -0.5
const BONK_FALL_SPEED := 420.0
const GROUND_STICK := 12.0
const SKIM_HEIGHT := 90.0
const SKIM_MIN_TIME := 0.6
const RADIUS := 22.0

var terrain: Terrain
var vel := Vector2(360, 0)
var holding := false
var stamina := 1.0
var exhausted := false
var skim_t := 0.0
var on_ground := true
var sleepy := false
var fever := false
var air_time := 0.0
var max_air_height := 0.0
var preview := false               # used by shop / menu previews (no physics)
var skin: Dictionary = {}

var _flap := 0.0
var _squash := Vector2.ONE
var _was_underwater := false
var _trail: Line2D
var _glow: Node2D


func _ready() -> void:
	z_index = 3
	if not preview:
		scale = Vector2(1.35, 1.35)
	if skin.is_empty():
		skin = Skins.get_skin(Game.equipped_skin)
	if not preview:
		_trail = Line2D.new()
		_trail.top_level = true
		_trail.z_index = 2
		_trail.width = 16.0
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0))
		curve.add_point(Vector2(1, 1))
		_trail.width_curve = curve
		_trail.joint_mode = Line2D.LINE_JOINT_ROUND
		_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		add_child(_trail)
		_apply_trail()


func set_skin(s: Dictionary) -> void:
	skin = s
	_apply_trail()
	queue_redraw()


func _apply_trail() -> void:
	if _trail == null:
		return
	var g := Gradient.new()
	g.set_color(0, skin.trail_b)
	g.set_color(1, skin.trail_a)
	_trail.gradient = g
	_trail.width = 22.0 if skin.glow else 14.0


func center() -> Vector2:
	return position + Vector2(0, -RADIUS * scale.y).rotated(rotation)


func speed() -> float:
	return vel.length()


func can_lift() -> bool:
	return holding and not sleepy and not exhausted


func step(delta: float) -> void:
	if terrain == null:
		return
	var lifting := can_lift()
	# stamina (with hysteresis: once empty, lift returns only at STAMINA_RESUME)
	if lifting:
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * delta)
		if stamina <= 0.0:
			exhausted = true
	elif not sleepy:
		stamina = minf(1.0, stamina + (STAMINA_REGEN_GROUND if on_ground else STAMINA_REGEN_AIR) * delta)
	if exhausted and stamina >= STAMINA_RESUME:
		exhausted = false

	# forward speed ramps up over distance
	var target := lerpf(SPEED_START, SPEED_MAX, clampf(position.x / SPEED_RAMP_X, 0.0, 1.0))
	if fever:
		target *= 1.3
	if on_ground:
		target *= 0.85
	if sleepy:
		target *= 0.7
	vel.x = move_toward(vel.x, target, SPEED_ACCEL * delta)

	if on_ground and lifting:
		on_ground = false
		air_time = 0.0
		max_air_height = 0.0
		vel.y = minf(vel.y, -120.0)
		took_off.emit()

	# vertical: gravity, lift fading out between the soft and hard ceiling
	vel.y += GRAVITY * delta
	var lift_scale := 1.0 - clampf((CEILING_SOFT - position.y) / (CEILING_SOFT - CEILING_HARD), 0.0, 1.0)
	if lifting:
		vel.y -= LIFT * lift_scale * delta
	vel.y = clampf(vel.y, -MAX_RISE * lift_scale if position.y < CEILING_SOFT else -MAX_RISE, MAX_FALL)

	position += vel * delta
	var h := terrain.height_at(position.x)
	var slope := terrain.slope_at(position.x)
	var stick := on_ground and position.y > h - GROUND_STICK
	if position.y >= h or stick:
		if not on_ground:
			_land(slope)
		position.y = h
		vel.y = vel.x * slope
		on_ground = true
		skim_t = 0.0
	else:
		on_ground = false
		air_time += delta
		max_air_height = maxf(max_air_height, h - position.y)
		var in_zone := (h - position.y) < SKIM_HEIGHT and not terrain.is_sea_at(position.x)
		if in_zone:
			skim_t += delta
		elif skim_t > 0.0:
			if skim_t >= SKIM_MIN_TIME:
				skimmed.emit(skim_t)
			skim_t = 0.0

	var under := position.y > Terrain.WATER_Y + 4.0 and h > Terrain.WATER_Y
	if under and not _was_underwater:
		splashed.emit()
	_was_underwater = under


func _land(slope: float) -> void:
	var bonk := vel.y > BONK_FALL_SPEED or slope < BONK_SLOPE
	if bonk:
		vel.x *= 0.6
	_squash = Vector2(1.3, 0.72) if bonk else Vector2(1.12, 0.88)
	landed.emit(bonk)


func _process(delta: float) -> void:
	var flapping := can_lift() and not preview
	_flap += delta * (24.0 if flapping else (6.0 if on_ground or preview else 2.0))
	_squash = _squash.lerp(Vector2.ONE, min(1.0, delta * 9.0))
	if not preview:
		var target_rot := atan2(vel.y, vel.x)
		rotation = lerp_angle(rotation, clampf(target_rot, -1.2, 1.25), min(1.0, delta * 14.0))
		if _trail:
			_trail.add_point(global_position + Vector2(-18, -RADIUS).rotated(rotation) * scale.x)
			while _trail.get_point_count() > (34 if skin.glow or fever else 22):
				_trail.remove_point(0)
	queue_redraw()


func _draw() -> void:
	var b: Color = skin.body
	draw_set_transform(Vector2(0, -RADIUS * _squash.y), 0.0, _squash)
	if fever or skin.glow:
		var a := 0.22 + (0.1 * sin(_flap * 0.5) if fever else 0.0)
		draw_circle(Vector2.ZERO, RADIUS * (2.1 if fever else 1.6), Color(skin.trail_a.r, skin.trail_a.g, skin.trail_a.b, a))
	# tail
	if skin.feature == "plume":
		for i in 3:
			var a2 := 2.8 + i * 0.18 + sin(_flap * 0.4 + i) * 0.08
			Art.leaf(self, Vector2(-16, 4), a2, 46.0, 5.0, -0.5, skin.feature_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-16, -4), Vector2(-36, -12), Vector2(-34, 4), Vector2(-16, 8)]), skin.wing)
	# body
	Art.ball(self, Vector2.ZERO, RADIUS, b)
	Art.ellipse(self, Vector2(4, 8), 15, 10, skin.belly)
	Art.ellipse(self, Vector2(4, 13), 12, 4, Color(0, 0, 0, 0.08))
	# casque / crest / crown (behind eye, on head)
	match String(skin.feature):
		"crest":
			for i in 4:
				Art.leaf(self, Vector2(2, -18), -1.9 - i * 0.28 + sin(_flap * 0.3) * 0.05, 26.0 + i * 3.0, 4.0, -0.4, skin.feature_color)
		"casque":
			Art.ellipse(self, Vector2(20, -12), 12, 6, skin.feature_color, -0.25)
		"crown":
			for i in 3:
				var cx := -6.0 + i * 8.0
				draw_colored_polygon(PackedVector2Array([Vector2(cx - 4, -18), Vector2(cx, -32 - (4 if i == 1 else 0)), Vector2(cx + 4, -18)]), skin.feature_color)
	# wing
	var wing_ang := -0.4 + sin(_flap) * 0.7
	if not preview:
		if on_ground:
			wing_ang = 0.25
		elif not can_lift():
			wing_ang = -0.75 + sin(_flap) * 0.08   # spread, gliding
	Art.leaf(self, Vector2(-4, 0), PI + wing_ang, 30.0, 9.0, -0.6, (skin.wing as Color).darkened(0.3))
	Art.leaf(self, Vector2(-4, -2), PI + wing_ang, 30.0, 9.0, -0.6, skin.wing)
	# beak
	draw_colored_polygon(PackedVector2Array([Vector2(18, -5), Vector2(34 if skin.feature != "casque" else 38, 1), Vector2(18, 6)]), skin.beak)
	# eye
	if skin.feature == "mask":
		Art.ellipse(self, Vector2(10, -6), 9, 7, skin.feature_color)
	draw_circle(Vector2(10, -7), 6.0, Color.WHITE)
	var blink := 1.0 if fmod(_flap, 37.0) > 1.0 else 0.2
	Art.ellipse(self, Vector2(11.5, -7), 3.4, 3.4 * blink, Color("#1b1430"))
	draw_circle(Vector2(12.6, -8.4), 1.2, Color.WHITE)
	# cheek
	draw_circle(Vector2(6, 3), 4.0, Color(1.0, 0.45, 0.5, 0.35))
	if sleepy:
		draw_line(Vector2(6, -8), Vector2(15, -8), Color("#1b1430"), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
