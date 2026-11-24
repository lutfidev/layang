class_name Terrain
extends Node2D
## Endless procedural hills grouped into islands. Each island uses one biome's palette.
## Hills are cosine-interpolated key points (smooth, launch-friendly slopes).

const DEPTH := 1700.0
const SEA_FLOOR := 470.0
const WATER_Y := 300.0
const SAMPLE := 14.0
# Pantai bays: water-filled valleys with a launch lip before them (see Bird.LIP_KICK)
const BAYS_PER_ISLAND := 3
const BAY_VALLEY_Y := 60.0
const LIP_Y := -60.0
const LIP_RAMP := 480.0
const BAY_FLOOR_Y := 380.0
const BAY_HALF := 300.0
const BANK_Y := 40.0
const KICK_BEFORE := 40.0
const KICK_AFTER := 10.0
const NEXT_BAY_MARGIN := 70.0   # = Wave.WAVE_HALF
const LIP_COLOR := Color("#ff7a59")
const LIP_EDGE := Color("#ffe066")

var run_seed: int = 1
var start_island: int = 0

var keys_x := PackedFloat32Array()
var keys_y := PackedFloat32Array()
var keys_island := PackedInt32Array()
## x where island k+1 begins (the deepest point of the sea before it).
var boundaries := PackedFloat32Array()
var island_finish := PackedFloat32Array()   # x of each island's gapura peak
var props: Array = []                         # [{x, kind, island, s}]
## Pantai bays, sorted by x: {lip_x, mid, water_x0, water_x1, bank_x, island}
var bays: Array = []

var coins: CoinField
var _islands_generated := 0
var _materials := {}
var _water_mat: Dictionary = {}
var _meshes := {}          # segment index -> MeshInstance2D
var _built_upto := -1
var _water_layer: Node2D
var _mesh_layer: Node2D
var _props_layer: PropsLayer


func setup(seed_value: int, first_island: int, coin_field: CoinField) -> void:
	run_seed = seed_value
	start_island = first_island
	coins = coin_field
	_water_layer = Node2D.new()
	_water_layer.z_index = -1
	add_child(_water_layer)
	_mesh_layer = Node2D.new()
	add_child(_mesh_layer)
	_props_layer = PropsLayer.new()
	_props_layer.terrain = self
	_props_layer.z_index = 1
	add_child(_props_layer)
	_generate_island()
	_generate_island()


func island_count_generated() -> int:
	return _islands_generated


func biome_index_of_island(k: int) -> int:
	return start_island + k


# ---------------------------------------------------------------- queries

func _seg(x: float) -> int:
	var i := keys_x.bsearch(x) - 1
	return clampi(i, 0, keys_x.size() - 2)


func height_at(x: float) -> float:
	if keys_x.is_empty():
		return 0.0
	if x <= keys_x[0]:
		return keys_y[0]
	var i := _seg(x)
	var x0 := keys_x[i]
	var x1 := keys_x[i + 1]
	var t := clampf((x - x0) / (x1 - x0), 0.0, 1.0)
	return keys_y[i] + (keys_y[i + 1] - keys_y[i]) * (1.0 - cos(PI * t)) * 0.5


## Any water: the sea between islands or a Pantai bay.
func is_water_at(x: float) -> bool:
	return height_at(x) > WATER_Y


## The sea between islands (not a bay).
func is_sea_at(x: float) -> bool:
	return is_water_at(x) and bay_at(x) < 0


## Index of the bay whose water covers x, or -1.
func bay_at(x: float) -> int:
	for i in bays.size():
		var b: Dictionary = bays[i]
		if x >= b.water_x0 and x <= b.water_x1:
			return i
	return -1


## The first bay the bird at x has not fully passed yet, or -1.
func next_bay(x: float) -> int:
	for i in bays.size():
		if bays[i].water_x1 + NEXT_BAY_MARGIN > x:
			return i
	return -1


## True on the launch zone at the top of a bay's lip.
func kick_at(x: float) -> bool:
	for b in bays:
		if x >= b.lip_x - KICK_BEFORE and x <= b.lip_x + KICK_AFTER:
			return true
	return false


## True on the far bank of a bay, where a landing never counts as a bonk.
func soft_landing_at(x: float) -> bool:
	for b in bays:
		if x >= b.water_x1 and x <= b.bank_x:
			return true
	return false


## Picks BAYS_PER_ISLAND hill indices in [2, hills-1], sorted, never two in a row.
static func pick_bay_hills(hills: int, rng: RandomNumberGenerator) -> Array[int]:
	var picked: Array[int] = []
	while picked.size() != BAYS_PER_ISLAND:
		picked.clear()
		var pool: Array[int] = []
		for h in range(2, hills):
			pool.append(h)
		while picked.size() < BAYS_PER_ISLAND and not pool.is_empty():
			var h: int = pool[rng.randi_range(0, pool.size() - 1)]
			picked.append(h)
			pool.erase(h)
			pool.erase(h - 1)
			pool.erase(h + 1)
	picked.sort()
	return picked


func slope_at(x: float) -> float:
	if keys_x.is_empty() or x <= keys_x[0]:
		return 0.0
	var i := _seg(x)
	var x0 := keys_x[i]
	var x1 := keys_x[i + 1]
	var t := clampf((x - x0) / (x1 - x0), 0.0, 1.0)
	return (keys_y[i + 1] - keys_y[i]) * PI * sin(PI * t) / (2.0 * (x1 - x0))


func island_at(x: float) -> int:
	var k := 0
	for b in boundaries:
		if x >= b:
			k += 1
	return k


# ---------------------------------------------------------------- streaming

func update_view(left: float, right: float) -> void:
	while keys_x[keys_x.size() - 1] < right + 4000.0:
		_generate_island()
	# build meshes ahead
	var last_needed := _seg(right + 600.0)
	while _built_upto < last_needed:
		_built_upto += 1
		_build_segment(_built_upto)
	# free meshes behind
	for idx in _meshes.keys():
		if keys_x[idx + 1] < left - 1200.0:
			_meshes[idx].queue_free()
			_meshes.erase(idx)
	for w in _water_layer.get_children():
		if w.get_meta("end_x", 0.0) < left - 1500.0:
			w.queue_free()
	_props_layer.view_left = left
	_props_layer.view_right = right
	_props_layer.queue_redraw()


func _add_key(p: Vector2, island: int) -> void:
	keys_x.append(p.x)
	keys_y.append(p.y)
	keys_island.append(island)


func _generate_island() -> void:
	var k := _islands_generated
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed * 7919 + k * 104729
	var diff := float(min(k + start_island * 0.5, 10))
	var amp := 1.0 + diff * 0.07
	var wid := 1.0 + diff * 0.035
	var hills := 9 + int(min(k, 6))
	var biome: Dictionary = Biomes.get_biome(start_island + k)

	if k == 0:
		_add_key(Vector2(-4200, -150), k)
		_add_key(Vector2(-2600, -120), k)
		_add_key(Vector2(-900, -170), k)
	else:
		var lx := keys_x[keys_x.size() - 1]
		_add_key(Vector2(lx + 1100.0, -110.0 * amp), k)

	var bay_hills: Array[int] = []
	if biome.id == "pantai":
		var bay_rng := RandomNumberGenerator.new()
		bay_rng.seed = run_seed * 6151 + k * 92821
		bay_hills = pick_bay_hills(hills, bay_rng)

	var hill_start_key := keys_x.size() - 1
	for h in hills:
		var lx := keys_x[keys_x.size() - 1]
		var vx := lx + rng.randf_range(440.0, 720.0) * wid
		if h in bay_hills:
			_add_bay(vx, k, biome)
			continue
		var vy := rng.randf_range(60.0, 150.0) * amp
		_add_key(Vector2(vx, vy), k)
		var px := vx + rng.randf_range(420.0, 700.0) * wid
		var py := -rng.randf_range(50.0, 165.0) * amp
		if h == 0:
			py = -80.0
		_add_key(Vector2(px, py), k)

	# launch ramp + finish gate
	var lx2 := keys_x[keys_x.size() - 1]
	_add_key(Vector2(lx2 + 700.0, 210.0 * amp), k)
	var fx := lx2 + 700.0 + 760.0
	_add_key(Vector2(fx, -240.0 * amp), k)
	island_finish.append(fx)
	props.append({"x": fx, "kind": "gapura", "island": k, "s": 1.0})

	# sea: gets wider further into the run (room for more sea-monster jumps)
	var sea_x := fx + 1200.0
	var sea_len := 500.0 + minf(k + start_island, 6.0) * 320.0
	_add_key(Vector2(sea_x, SEA_FLOOR), k)
	_add_key(Vector2(sea_x + sea_len, SEA_FLOOR), k + 1)
	boundaries.append(sea_x + sea_len * 0.5)
	_build_water(fx, sea_x + sea_len + 1100.0, biome)

	_place_items(k, hill_start_key, keys_x.size() - 3, rng, biome)
	_islands_generated += 1


func _add_bay(valley_x: float, k: int, biome: Dictionary) -> void:
	var lip_x := valley_x + LIP_RAMP
	var floor_x := lip_x + BAY_HALF
	var bank_x := floor_x + BAY_HALF
	_add_key(Vector2(valley_x, BAY_VALLEY_Y), k)
	_add_key(Vector2(lip_x, LIP_Y), k)
	_add_key(Vector2(floor_x, BAY_FLOOR_Y), k)
	_add_key(Vector2(bank_x, BANK_Y), k)
	var x0 := lip_x
	while height_at(x0) <= WATER_Y:
		x0 += 2.0
	var x1 := floor_x
	while height_at(x1) > WATER_Y:
		x1 += 2.0
	bays.append({"lip_x": lip_x, "mid": floor_x, "water_x0": x0, "water_x1": x1 - 2.0, "bank_x": bank_x, "island": k})
	_build_water(lip_x, bank_x, biome)


func _place_items(k: int, first_key: int, last_key: int, rng: RandomNumberGenerator, biome: Dictionary) -> void:
	var prop_kind: String = biome.prop
	var orbs_left := 2
	var i := first_key
	while i < last_key:
		var x0 := keys_x[i]
		var x1 := keys_x[i + 1]
		var downhill := keys_y[i + 1] > keys_y[i]
		var roll := rng.randf()
		if downhill and roll < 0.34:
			for j in 6:
				var t := 0.22 + j * 0.1
				var x := lerpf(x0, x1, t)
				if is_water_at(x):
					continue
				coins.add_item(Vector2(x, height_at(x) - 38.0), CoinField.COIN)
		elif (not downhill) and roll < 0.3:
			var cx := x1 + 260.0
			var top := keys_y[i + 1] - rng.randf_range(250.0, 420.0)
			for j in 7:
				var u := (j - 3) / 3.0
				coins.add_item(Vector2(cx + u * 240.0, top + u * u * 120.0), CoinField.COIN)
			if orbs_left > 0 and rng.randf() < 0.35:
				coins.add_item(Vector2(cx, top - 130.0), CoinField.SUN)
				orbs_left -= 1
		# props on the ground
		var n := 2 if prop_kind == "rice" else 1
		for j in n:
			if rng.randf() < 0.55:
				var px := lerpf(x0, x1, rng.randf_range(0.1, 0.9))
				if is_water_at(px):
					continue
				props.append({"x": px, "kind": prop_kind, "island": k, "s": rng.randf_range(0.8, 1.3)})
		i += 1


func _material_for(island: int) -> ShaderMaterial:
	if _materials.has(island):
		return _materials[island]
	var b: Dictionary = Biomes.get_biome(start_island + island)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/hill.gdshader")
	m.set_shader_parameter("col_a", b.hill_a)
	m.set_shader_parameter("col_b", b.hill_b)
	m.set_shader_parameter("col_top", b.hill_top)
	m.set_shader_parameter("col_deep", b.hill_deep)
	m.set_shader_parameter("pattern", int(b.pattern))
	m.set_shader_parameter("light_x", (float(b.sun_x) - 0.5) * 1.6)
	m.set_shader_parameter("stripe_w", float(b.stripe_w))
	m.set_shader_parameter("glow_rim", 1.0 if b.id == "danau" or b.id == "gunung" else 0.0)
	_materials[island] = m
	return m


func _build_segment(idx: int) -> void:
	if idx < 0 or idx >= keys_x.size() - 1:
		return
	var x0 := keys_x[idx]
	var x1 := keys_x[idx + 1]
	var n := int(ceil((x1 - x0) / SAMPLE))
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for j in n + 1:
		var x := lerpf(x0, x1, float(j) / n)
		var t := float(j) / n
		var h := keys_y[idx] + (keys_y[idx + 1] - keys_y[idx]) * (1.0 - cos(PI * t)) * 0.5
		verts.append(Vector2(x, h))
		uvs.append(Vector2(x, 0.0))
		verts.append(Vector2(x, h + DEPTH))
		uvs.append(Vector2(x, DEPTH))
		# surface slope packed into the vertex color (red = 0.5 + slope * 0.4) for hill.gdshader lighting
		var s := (keys_y[idx + 1] - keys_y[idx]) * PI * sin(PI * t) / (2.0 * (x1 - x0))
		var c := Color(clampf(0.5 + s * 0.4, 0.0, 1.0), 0, 0, 1)
		cols.append(c)
		cols.append(c)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arr)
	var mi := MeshInstance2D.new()
	mi.mesh = mesh
	mi.material = _material_for(keys_island[idx])
	_mesh_layer.add_child(mi)
	_meshes[idx] = mi


func _build_water(x0: float, x1: float, biome: Dictionary) -> void:
	var top := WATER_Y - 12.0
	var bottom := SEA_FLOOR + 600.0
	var verts := PackedVector2Array([Vector2(x0, top), Vector2(x0, bottom), Vector2(x1, top), Vector2(x1, bottom)])
	var uvs := PackedVector2Array([Vector2(x0, 0), Vector2(x0, bottom - top), Vector2(x1, 0), Vector2(x1, bottom - top)])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arr)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/water.gdshader")
	m.set_shader_parameter("water", biome.water)
	m.set_shader_parameter("foam", biome.water_top)
	var mi := MeshInstance2D.new()
	mi.mesh = mesh
	mi.material = m
	mi.set_meta("end_x", x1)
	_water_layer.add_child(mi)


# ================================================================ props

class PropsLayer:
	extends Node2D
	var terrain: Terrain
	var view_left := 0.0
	var view_right := 0.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if terrain == null:
			return
		var t := Time.get_ticks_msec() / 1000.0
		for bay in terrain.bays:
			var lx: float = bay.lip_x
			if lx < view_left - 400.0 or lx > view_right + 400.0:
				continue
			var surf := PackedVector2Array()
			var sx := lx - 220.0
			while sx <= lx + KICK_AFTER:
				surf.append(Vector2(sx, terrain.height_at(sx)))
				sx += 14.0
			Art.launch_ramp(self, surf, LIP_COLOR, LIP_EDGE, t)
		for p in terrain.props:
			var x: float = p.x
			if x < view_left - 300.0 or x > view_right + 300.0:
				continue
			var b: Dictionary = Biomes.get_biome(terrain.start_island + int(p.island))
			var y := terrain.height_at(x) + 3.0
			var s: float = p.s
			var col: Color = b.prop_color
			var sway := sin(t * 2.0 + x * 0.01)
			match String(p.kind):
				"gapura":
					Art.gapura(self, Vector2(x, y + 6.0), 1.15, b.hill_deep.lightened(0.15), b.hill_top)
				"rice":
					Art.rice(self, Vector2(x, y), s, col, sway)
				"shell":
					Art.shell(self, Vector2(x, y), s, col)
				"mushroom":
					Art.mushroom(self, Vector2(x, y), s, col)
				"rock":
					Art.rock(self, Vector2(x, y), s * 1.4, col)
					draw_circle(Vector2(x + 4, y - 10 * s), 3.0 * s, Color(1.0, 0.5, 0.2, 0.6 + 0.4 * sway))
				"lantern":
					Art.lantern(self, Vector2(x, y - 30.0 - 10.0 * sway), s, col, t)
				"star":
					Art.star(self, Vector2(x, y - 26.0 - 8.0 * sway), 9.0 * s, col, t * 0.6)
