class_name Wave
extends Node2D
## The beach wave in a Pantai bay. Driven by the bird's distance to the bay (not a clock), so it is
## always a challenge: foam starts bubbling once the bay is about a screen ahead, the wave rises as the
## bird nears the launch lip and stands at full height while the bird is over the water, then recedes.

const WAVE_H := 200.0          # crest height above the water (crest at WATER_Y - WAVE_H)
const WAVE_HALF := 70.0        # half width of the wave column around the bay's mid
const HIT_PAD := 18.0          # bird hit radius around its center
const FOAM_DIST := 1900.0      # foam starts when mid - bird_x drops below this
const RISE_DIST := 750.0       # the wave starts rising here
const FULL_DIST := 200.0       # and is at full height from here on
const PASS_MARGIN := 40.0      # past mid + WAVE_HALF + this = passed
const RECEDE_TIME := 0.9

signal passed

var terrain: Terrain
var sounds := true             # false in menu / shop demo worlds
var bay := -1
var state := "idle"            # idle | foam | rise | recede
var height := 0.0
var _last_done := -1
var _recede_t := 0.0
var _d := INF
var _anim := 0.0


func _ready() -> void:
	z_index = 2


## Advances the wave; returns true when it hits the bird.
func update(delta: float, bird_center: Vector2, bird_x: float) -> bool:
	_anim += delta
	queue_redraw()
	if state == "recede":
		_recede_t += delta
		height = WAVE_H * clampf(1.0 - _recede_t / RECEDE_TIME, 0.0, 1.0)
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
	if bird_x > float(b.mid) + WAVE_HALF + PASS_MARGIN:
		_finish(true)
		return false
	if _d > FOAM_DIST:
		state = "idle"
		height = 0.0
		return false
	if _d > RISE_DIST:
		if state == "idle" and sounds:
			Sfx.play("fizz")
		state = "foam"
		height = 0.0
		return false
	if state != "rise" and sounds:
		Sfx.play("surge")
	state = "rise"
	height = WAVE_H * ease(clampf((RISE_DIST - _d) / (RISE_DIST - FULL_DIST), 0.0, 1.0), -2.0)
	return absf(bird_center.x - float(b.mid)) < WAVE_HALF and bird_center.y + HIT_PAD > Terrain.WATER_Y - height


## Lets the current bay's wave go without counting it as passed (used by "Lanjut terbang").
## Only an active wave (foam or rising) is skipped; a bay still far ahead keeps its wave.
func reset_current() -> void:
	if bay >= 0 and state in ["foam", "rise"]:
		_finish(false)


func _finish(count: bool) -> void:
	_last_done = bay
	state = "recede"
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
	if height > 24.0:
		Art.wave(self, b.mid, WAVE_HALF, Terrain.WATER_Y, height, biome.water, biome.water_top, _anim)
	elif height > 1.0:
		# too low for the curl outline (it would degenerate): a swelling mound
		Art.ellipse(self, Vector2(b.mid, Terrain.WATER_Y), WAVE_HALF * 1.4, height, biome.water)
