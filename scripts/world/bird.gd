class_name Bird
extends Node2D
## The player. Hold = heavy (dive), release = light (glide / launch off slopes).

signal landed(quality: int)        # 2 perfect, 1 ok, 0 bonk
signal took_off
signal splashed

const GRAVITY := 1500.0
const DIVE_MULT := 2.7
const MIN_SPEED_X := 170.0
const MAX_SPEED := 2700.0
const RADIUS := 22.0

var terrain: Terrain
var vel := Vector2(360, 0)
var holding := false
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


func step(delta: float) -> void:
	if terrain == null:
		return
	var dive := holding and not sleepy
	var g := GRAVITY * (DIVE_MULT if dive else 1.0)
	vel.y += g * delta
	if not on_ground and not dive and vel.y > 0.0:
		vel.y -= 180.0 * delta   # gentle glide lift
	var drag := 0.00003 * vel.length()
	if sleepy:
		drag += 0.9 if on_ground else 0.25
	vel *= max(0.0, 1.0 - drag * delta)
	if not sleepy:
		vel.x = max(vel.x, MIN_SPEED_X * (1.4 if fever else 1.0))
	else:
		vel.x = max(vel.x, 20.0)
	if vel.length() > MAX_SPEED:
		vel = vel.normalized() * MAX_SPEED

	position += vel * delta
	var h := terrain.height_at(position.x)
	var slope := terrain.slope_at(position.x)
	var tangent := Vector2(1.0, slope).normalized()

	var stick := dive and on_ground and position.y > h - 10.0
	if position.y >= h or stick:
		if not on_ground:
			_land(tangent, slope)
		position.y = h
		var s := vel.dot(tangent)
		vel = tangent * max(s, 40.0)
		on_ground = true
	else:
		if on_ground and position.y < h - 2.0:
			on_ground = false
			air_time = 0.0
			max_air_height = 0.0
			took_off.emit()
		if not on_ground:
			air_time += delta
			max_air_height = max(max_air_height, h - position.y)

	var under := position.y > Terrain.WATER_Y + 4.0 and h > Terrain.WATER_Y
	if under and not _was_underwater:
		splashed.emit()
	_was_underwater = under


func _land(tangent: Vector2, slope: float) -> void:
	var dir := vel.normalized()
	var align := dir.dot(tangent)
	var quality := 1
	if align > 0.97 and slope > 0.05:
		quality = 2
		vel = tangent * (vel.length() * 1.05 + 160.0)
	elif align < 0.8 and slope < 0.1:
		quality = 0
		vel = tangent * vel.dot(tangent) * 0.65
	_squash = Vector2(1.3, 0.72) if quality != 2 else Vector2(1.15, 0.85)
	landed.emit(quality)


func _process(delta: float) -> void:
	_flap += delta * (18.0 if (not on_ground and not holding) else 6.0)
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
	var tucked := holding and not preview
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
	draw_circle(Vector2.ZERO, RADIUS, b)
	Art.ellipse(self, Vector2(4, 8), 15, 10, skin.belly)
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
	var wing_ang := -0.4 + sin(_flap) * 0.7 if not tucked else 0.35
	if on_ground and not preview:
		wing_ang = 0.25
	Art.leaf(self, Vector2(-4, -2), PI + wing_ang, 30.0 if not tucked else 22.0, 9.0, -0.6, skin.wing)
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
