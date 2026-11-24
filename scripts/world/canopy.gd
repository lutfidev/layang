class_name Canopy
extends Node2D
## Hutan canopy tunnels (spans in Terrain.canopies): a roof of branches over one gentle hill and thorn
## bushes on its ground. Both are deadly; the bird must fly the corridor between them. A tunnel never
## moves, so its gap reads from the moment its mouth enters the screen.

const CAUSE := "hutan"
const GAP := 300.0            # roof edge sits this far above the ground
const THORN_H := 40.0         # thorn bushes cover this much of the ground inside the tunnel
const BIRD_R := 16.0          # forgiving: smaller than Bird.RADIUS, so grazes are "hampir kena!"
const SPOT_DIST := 1400.0     # the first tunnel of the run announces itself this far ahead
const PASS_MARGIN := 40.0
const ROOF_TOP := -2600.0     # the roof is drawn (and deadly) all the way up, above Bird.CEILING_HARD
const SMOOTH := 60.0
const STEP := 30.0

signal spotted
signal passed

var terrain: Terrain
var view_left := 0.0
var view_right := 0.0
var hit_color := Color("#2f6b3a")
var _anim := 0.0
var _spotted := false
var _first := 0
var _inside := -1            # index of the tunnel the bird is (or last was) flying through


func _ready() -> void:
	z_index = 2


## Lower edge of the roof at x: GAP above the (lightly smoothed) ground.
static func roof_y(tr: Terrain, x: float) -> float:
	return (tr.height_at(x - SMOOTH) + tr.height_at(x) + tr.height_at(x + SMOOTH)) / 3.0 - GAP


## x range (left, right) where the tunnel can hit the bird.
static func span(c: Dictionary) -> Vector2:
	return Vector2(float(c.x0), float(c.x1))


static func hits(tr: Terrain, c: Dictionary, p: Vector2, on_ground: bool) -> bool:
	if p.x < float(c.x0) or p.x > float(c.x1):
		return false
	return on_ground or p.y - BIRD_R < roof_y(tr, p.x) or p.y > tr.height_at(p.x) - THORN_H


## Animates the tunnels; returns true when one hits the bird.
func update(delta: float, bird_center: Vector2, bird_x: float, bird_on_ground: bool) -> bool:
	_anim += delta
	queue_redraw()
	var cs: Array = terrain.canopies
	while _first < cs.size() and float(cs[_first].x1) < bird_x - 600.0:
		_first += 1
	var hit := false
	for i in range(_first, cs.size()):
		var c: Dictionary = cs[i]
		var ahead := float(c.x0) - bird_x
		if ahead > 0.0:
			if not _spotted and ahead < SPOT_DIST:
				_spotted = true
				spotted.emit()
			break
		if bird_x <= float(c.x1):
			_inside = i
		if hits(terrain, c, bird_center, bird_on_ground):
			hit = true
		elif i == _inside and bird_x > float(c.x1) + PASS_MARGIN:
			_inside = -1
			passed.emit()
	return hit


## Moves x forward past any tunnel it is inside of or less than 200 px before (respawn after "Lanjut").
func safe_x_after(x: float) -> float:
	for i in terrain.canopies.size():
		var c: Dictionary = terrain.canopies[i]
		if x >= float(c.x0) - 200.0 and x <= float(c.x1):   # floats, not span(): Vector2 is float32
			x = float(c.x1) + 200.0
			if _inside == i:
				_inside = -1
	return x


func reset_current() -> void:
	pass   # tunnels are static: nothing to clear


func _draw() -> void:
	if terrain == null:
		return
	for c in terrain.canopies:
		var x0: float = c.x0
		var x1: float = c.x1
		if x0 > view_right + 400.0:
			break
		if x1 < view_left - 400.0:
			continue
		var b: Dictionary = Biomes.get_biome(terrain.biome_index_of_island(int(c.island)))
		var edge := PackedVector2Array()
		var ground := PackedVector2Array()
		var x := x0
		while x <= x1 + 0.1:
			edge.append(Vector2(x, roof_y(terrain, x)))
			ground.append(Vector2(x, terrain.height_at(x)))
			x += STEP
		var deep: Color = b.hill_deep
		var leaf: Color = b.hill_a
		Art.thorn_bush(self, ground, THORN_H, deep, Color("#d6323c"))
		Art.canopy_roof(self, edge, ROOF_TOP, deep, leaf, _anim)
