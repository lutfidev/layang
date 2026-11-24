class_name Kite
extends Node2D
## Villagers' kites over Sawah peaks (positions in Terrain.kites). A kite never moves: its body bobs a
## little and its tail flutters only sideways, so the safe gap under the tail tip is always the same.
## The body and tail are deadly; the string is decoration.

const BODY_ABOVE := 400.0      # body center at peak_y - this
const BODY_HW := 34.0
const BODY_HH := 44.0
const BOB := 8.0
const TAIL_CLEAR := 170.0      # tail tip at peak_y - this (the peak is the highest ground under the tail)
const TAIL_DRIFT := 40.0       # tail tip sits this far behind (left of) the body
const TAIL_SWAY := 20.0
const TAIL_SEGS := 10
const BIRD_R := 16.0           # forgiving: smaller than Bird.RADIUS, so grazes are "hampir kena!"
const SPOT_DIST := 1400.0      # first kite of the run announces itself this far ahead
const VILLAGER_BACK := 360.0
const COLORS := [
	[Color("#ff5a5f"), Color("#ffd23f")],
	[Color("#3d8bff"), Color("#ffffff")],
	[Color("#3fbf6f"), Color("#ff9d3c")],
]

signal spotted

var terrain: Terrain
var view_left := 0.0
var view_right := 0.0
var hit_color := Color.WHITE
var _anim := 0.0
var _spotted := false
var _first := 0


func _ready() -> void:
	z_index = 2


static func body_center(k: Dictionary, t: float) -> Vector2:
	var x: float = k.x
	return Vector2(x, float(k.peak_y) - BODY_ABOVE + sin(t * 1.4 + x * 0.01) * BOB)


## TAIL_SEGS + 1 points from the bottom of the body to the tip; sway is horizontal only.
static func tail_points(k: Dictionary, t: float) -> PackedVector2Array:
	var top := body_center(k, t) + Vector2(0.0, BODY_HH)
	var tip := Vector2(float(k.x) - TAIL_DRIFT, float(k.peak_y) - TAIL_CLEAR)
	var pts := PackedVector2Array()
	for i in TAIL_SEGS + 1:
		var f := float(i) / TAIL_SEGS
		var p := top.lerp(tip, f)
		p.x += sin(t * 3.0 + f * 5.0 + float(k.x) * 0.02) * TAIL_SWAY * f
		pts.append(p)
	return pts


static func hits(k: Dictionary, t: float, p: Vector2) -> bool:
	var d := (p - body_center(k, t)).abs()
	if d.x / (BODY_HW + BIRD_R) + d.y / (BODY_HH + BIRD_R) <= 1.0:
		return true
	var pts := tail_points(k, t)
	for i in pts.size() - 1:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])) < BIRD_R:
			return true
	return false


## x range (left, right) where the kite can hit the bird.
static func span(k: Dictionary) -> Vector2:
	var x: float = k.x
	return Vector2(x - maxf(BODY_HW, TAIL_DRIFT + TAIL_SWAY) - BIRD_R, x + BODY_HW + BIRD_R)


## Animates the kites; returns true when one hits the bird.
func update(delta: float, bird_center: Vector2, bird_x: float) -> bool:
	_anim += delta
	queue_redraw()
	var kites: Array = terrain.kites
	while _first < kites.size() and span(kites[_first]).y < bird_x - 400.0:
		_first += 1
	if not _spotted:
		for i in range(_first, kites.size()):
			var ahead: float = float(kites[i].x) - bird_x
			if ahead > 0.0:
				if ahead < SPOT_DIST:
					_spotted = true
					spotted.emit()
				break
	for i in range(_first, kites.size()):
		var k: Dictionary = kites[i]
		var sp := span(k)
		if sp.x > bird_center.x:
			break
		if bird_center.x <= sp.y and hits(k, _anim, bird_center):
			hit_color = COLORS[int(k.color)][0]
			return true
	return false


## Moves x forward past any kite it is inside of or less than 200 px before (respawn after "Lanjut").
func safe_x_after(x: float) -> float:
	for k in terrain.kites:
		var sp := span(k)
		if x >= sp.x - 200.0 and x <= sp.y:
			x = sp.y + 200.0
	return x


func _draw() -> void:
	if terrain == null:
		return
	for k in terrain.kites:
		var x: float = k.x
		if x - VILLAGER_BACK > view_right + 600.0:
			break
		if x < view_left - 600.0:
			continue
		var pal: Array = COLORS[int(k.color)]
		var c := body_center(k, _anim)
		var vx := x - VILLAGER_BACK
		var hand := Art.villager(self, Vector2(vx, terrain.height_at(vx)), 1.0, Color("#3a2a3f"))
		# string: a thin sagging line from the villager's hand to the body
		var anchor := c + Vector2(-BODY_HW * 0.3, BODY_HH * 0.3)
		var line := PackedVector2Array()
		for i in 13:
			var f := i / 12.0
			line.append(hand.lerp(anchor, f) + Vector2(0.0, sin(f * PI) * 40.0))
		draw_polyline(line, Color(1, 1, 1, 0.55), 1.5, true)
		Art.kite_tail(self, tail_points(k, _anim), pal[0])
		Art.kite(self, c, BODY_HW, BODY_HH, pal[0], pal[1])
