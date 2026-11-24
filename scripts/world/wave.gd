class_name Wave
extends Node2D
## The giant curling wave over a Pantai bay. It towers past the sky ceiling, so the high path is shut:
## the only way through is the tube under its curl, between the curl's lip (TUBE_TOP) and the water.
## Driven by the bird's distance to the bay (not a clock): foam first, then the wall rises while the
## bay is still far ahead, stands at full height while the bird crosses, then recedes.

const COL_PAD := 40.0          # the wave column spans [water_x0 - COL_PAD, water_x1 + COL_PAD]
const TUBE_TOP := -150.0       # the tube's roof (= Terrain.LIP_Y - 90): a bird running on the lip fits
const CREST_Y := -1800.0       # full-height crest, above Bird.CEILING_HARD
const HIT_PAD := 18.0          # bird hit radius around its center
const FOAM_DIST := 3200.0      # foam starts when mid - bird_x drops below this
const RISE_DIST := 2600.0      # the wall starts rising here
const FULL_DIST := 1500.0      # and stands at full height from here on
const RISE_SPEED := 2600.0     # max change of height per second (no popping between close bays)
const MAX_OVER := 900.0        # how far the face leans out over the approach at the crest
const LEDGE := 140.0           # the back slope ends this far past the tube's exit, at the roof
const CREST_W := 300.0         # width of the wall at the crest
const PASS_MARGIN := 40.0      # past col_x1 + LEDGE + this = passed
const RECEDE_TIME := 0.9
const FULL_H := Terrain.WATER_Y - CREST_Y

signal passed

var terrain: Terrain
var sounds := true             # false in menu / shop demo worlds
var bay := -1
var state := "idle"            # idle | foam | rise | recede
var height := 0.0              # crest height above the water
var _last_done := -1
var _recede_t := 0.0
var _recede_from := 0.0
var _d := INF
var _anim := 0.0
var _front: Node2D


func _ready() -> void:
	z_index = -1               # behind the hills (their slopes hide the wave's feet) and the bird
	_front = _WaveFront.new()
	_front.wave = self
	_front.z_index = 5         # z is relative: -1 + 5 = 4, in front of the bird (3)
	add_child(_front)


func col_x0() -> float:
	return float(terrain.bays[bay].water_x0) - COL_PAD if bay >= 0 else 0.0


func col_x1() -> float:
	return float(terrain.bays[bay].water_x1) + COL_PAD if bay >= 0 else 0.0


func crest_y() -> float:
	return Terrain.WATER_Y - height


## The wave's shape (shared by the hit test and the drawing, so what looks deadly is deadly).
## Above the tube's roof the face leans out over the approach the higher it gets and the back slopes
## down to a short ledge past the exit; below the roof the column is the tube itself.
static func face_x(x0: float, y: float, crest: float) -> float:
	if y >= TUBE_TOP or crest >= TUBE_TOP:
		return x0
	var over := minf(MAX_OVER, (Terrain.WATER_Y - crest) * 0.45)
	return x0 - over * pow(clampf((TUBE_TOP - y) / (TUBE_TOP - crest), 0.0, 1.0), 1.3)


static func back_x(x0: float, x1: float, y: float, crest: float) -> float:
	if y >= TUBE_TOP or crest >= TUBE_TOP:
		return x1
	var s := clampf((TUBE_TOP - y) / (TUBE_TOP - crest), 0.0, 1.0)
	return lerpf(x1 + LEDGE, face_x(x0, crest, crest) + CREST_W, pow(s, 0.7))


## Advances the wave; returns true when it hits the bird.
func update(delta: float, bird_center: Vector2, bird_x: float) -> bool:
	_anim += delta
	queue_redraw()
	_front.queue_redraw()
	if state == "recede":
		_recede_t += delta
		height = _recede_from * clampf(1.0 - _recede_t / RECEDE_TIME, 0.0, 1.0)
		if _recede_t >= RECEDE_TIME:
			state = "idle"
			bay = -1
			height = 0.0
		return false
	if bay < 0:
		var i := terrain.next_bay(bird_x)
		if i <= _last_done:
			i = _last_done + 1 if _last_done + 1 < terrain.bays.size() else -1
		bay = i
		if bay < 0:
			return false
	var b: Dictionary = terrain.bays[bay]
	_d = float(b.mid) - bird_x
	if bird_x > col_x1() + LEDGE + PASS_MARGIN:
		_finish(true)
		return false
	var target := 0.0
	if _d > FOAM_DIST:
		state = "idle"
	elif _d > RISE_DIST:
		if state == "idle" and sounds:
			Sfx.play("fizz")
		state = "foam"
	else:
		if state != "rise" and sounds:
			Sfx.play("surge")
		state = "rise"
		target = FULL_H * ease(clampf((RISE_DIST - _d) / (RISE_DIST - FULL_DIST), 0.0, 1.0), -2.0)
	height = move_toward(height, target, RISE_SPEED * delta)
	return hits(bird_center)


## True when a bird centered at c touches the wall: its shape from the crest down to the tube's roof.
## The tube under the roof is always safe, even while the wave is still rising.
func hits(c: Vector2) -> bool:
	if bay < 0 or height <= 0.0:
		return false
	var crest := crest_y()
	if c.y - HIT_PAD >= TUBE_TOP or c.y + HIT_PAD <= crest:
		return false
	var y := clampf(c.y, crest, TUBE_TOP - 1.0)
	var y_top := clampf(c.y - HIT_PAD, crest, TUBE_TOP - 1.0)
	# the face leans out higher up, so test the bird's top against it
	return c.x + HIT_PAD > face_x(col_x0(), y_top, crest) and c.x - HIT_PAD < back_x(col_x0(), col_x1(), y, crest)


## Where a respawn after x may go: past this wave's back ledge while it is standing (a bird killed by
## the overhang dies before the bay, and must not come back in front of it).
func safe_x_after(x: float) -> float:
	if bay >= 0 and state == "rise":
		return maxf(x, col_x1() + LEDGE + PASS_MARGIN)
	return x


## Lets the current bay's wave go without counting it as passed (used by "Lanjut terbang").
## Only an active wave (foam or rising) is skipped; a bay still far ahead keeps its wave.
func reset_current() -> void:
	if bay >= 0 and state in ["foam", "rise"]:
		_finish(false)


func _finish(count: bool) -> void:
	_last_done = bay
	state = "recede"
	_recede_from = height
	_recede_t = 0.0 if height > 0.0 else RECEDE_TIME
	if count:
		passed.emit()


func _draw() -> void:
	if state == "idle" or bay < 0 or terrain == null:
		return
	var b: Dictionary = terrain.bays[bay]
	var biome: Dictionary = Biomes.get_biome(terrain.start_island + int(b.island))
	var density := 1.0 if state != "foam" else clampf((FOAM_DIST - _d) / (FOAM_DIST - RISE_DIST), 0.0, 1.0)
	Art.foam(self, b.water_x0, b.water_x1, Terrain.WATER_Y, 0.35 + 0.65 * density, _anim)
	if height > 1.0:
		Art.wave_wall(self, col_x0(), col_x1(), Terrain.WATER_Y, crest_y(), TUBE_TOP, biome.water, biome.water_top, _anim)


class _WaveFront:
	extends Node2D
	var wave: Wave

	func _draw() -> void:
		if wave.state == "idle" or wave.bay < 0 or wave.height <= 1.0:
			return
		var b: Dictionary = wave.terrain.bays[wave.bay]
		var biome: Dictionary = Biomes.get_biome(wave.terrain.start_island + int(b.island))
		Art.wave_lip(self, wave.col_x0(), wave.col_x1(), Terrain.WATER_Y, wave.crest_y(), TUBE_TOP, biome.water, biome.water_top, wave._anim)
