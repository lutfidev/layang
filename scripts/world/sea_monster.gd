class_name SeaMonster
extends Node2D
## A chubby sea serpent that leaps out of the sea in an arc after a ~1 s warning
## (bubbles + dark shadow on the surface). Drawn in world coordinates.

const WARN_TIME := 1.0
const FIRST_WARN_TIME := 1.4      # first sea of a run: extra time for newcomers
const JUMP_TIME := 1.1
const PEAK_ABOVE_WATER := 600.0
const START_DEPTH := 90.0          # head starts/ends this far below the surface
const HIT_RADIUS := 70.0           # head vs bird center
const BODY_HIT_RADIUS := 42.0
const SPAN := 300.0                # horizontal travel of the head during a jump
const SEGMENTS := 9
const SEG_LAG := 0.032             # seconds of path between body humps
const BODY := Color("#5a46b8")
const BELLY := Color("#ffd29a")

var state := "idle"                # idle | warn | jump
var target_x := 0.0
var t := 0.0
var warn_time := WARN_TIME
var _anim := 0.0


func _ready() -> void:
	z_index = 2


func jumps_for_island(k: int) -> int:
	return mini(1 + k / 2, 3)


func arm(x: float, warn: float = WARN_TIME) -> void:
	state = "warn"
	warn_time = warn
	target_x = x
	t = 0.0
	Sfx.play("blub")


func reset() -> void:
	state = "idle"
	t = 0.0
	queue_redraw()


## Advances the monster; returns true when it bites the bird.
func update(delta: float, bird_center: Vector2) -> bool:
	_anim += delta
	if state == "idle":
		return false
	t += delta
	queue_redraw()
	if state == "warn":
		if t >= warn_time:
			state = "jump"
			t = 0.0
		return false
	if t >= JUMP_TIME + SEG_LAG * SEGMENTS:
		reset()
		return false
	if bird_center.distance_to(path_at(t)) < HIT_RADIUS:
		return true
	for i in range(1, SEGMENTS + 1):
		var p := path_at(t - SEG_LAG * i)
		if p.y < Terrain.WATER_Y and bird_center.distance_to(p) < BODY_HIT_RADIUS:
			return true
	return false


## Head position along the jump arc at time `tt` (seconds since the jump began).
func path_at(tt: float) -> Vector2:
	var p := clampf(tt / JUMP_TIME, 0.0, 1.0)
	var rise := (PEAK_ABOVE_WATER + START_DEPTH) * 4.0 * p * (1.0 - p)
	return Vector2(target_x + (p - 0.5) * SPAN, Terrain.WATER_Y + START_DEPTH - rise)


func _draw() -> void:
	if state == "idle":
		return
	var wy := Terrain.WATER_Y
	if state == "warn":
		var k := clampf(t / warn_time, 0.0, 1.0)
		var sx := target_x - SPAN * 0.5
		Art.ellipse(self, Vector2(sx, wy + 6.0), 70.0 + 50.0 * k, 14.0 + 8.0 * k, Color(0.08, 0.03, 0.2, 0.35 + 0.4 * k))
		for i in 10:
			var ph := fmod(_anim * 1.6 + i * 0.37, 1.0)
			var bx := sx + sin(i * 2.3) * (30.0 + 40.0 * k)
			var by := wy + 4.0 - ph * (40.0 + 30.0 * k)
			draw_circle(Vector2(bx, by), 7.0 + 6.0 * (1.0 - ph), Color(1, 1, 1, 0.85 * (1.0 - ph)))
		return
	# body humps (back to front), only the parts above the water
	var head := path_at(t)
	var height := wy - head.y
	if height > 0.0:
		Art.shadow(self, Vector2(head.x, wy + 4.0), 70.0 + height * 0.08, 12.0, clampf(0.5 - height / 1400.0, 0.1, 0.5))
	for i in range(SEGMENTS, 0, -1):
		var p := path_at(t - SEG_LAG * i)
		var r := 50.0 - i * 2.6
		if p.y - r >= wy:
			draw_circle(p, r, Color(0.06, 0.04, 0.2, 0.35))   # still under water
		else:
			Art.ball(self, p, r, BODY)
			draw_circle(p + Vector2(0, r * 0.35), r * 0.62, BELLY)
			if i % 2 == 0:
				draw_colored_polygon(PackedVector2Array([p + Vector2(-12, -r + 4), p + Vector2(0, -r - 18), p + Vector2(12, -r + 4)]), BODY.lightened(0.25))
	var p01 := clampf(t / JUMP_TIME, 0.0, 1.0)
	var mouth := clampf(1.0 - absf(p01 - 0.5) * 3.0, 0.0, 1.0)
	if head.y - 80.0 >= wy:
		Art.ellipse(self, head, 64.0, 56.0, Color(0.06, 0.04, 0.2, 0.35))
	else:
		Art.sea_monster(self, head, 1.15, BODY, BELLY, mouth, _anim)
