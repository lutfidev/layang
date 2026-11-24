extends RefCounted
## Pantai bays (water-filled valleys), the launch lip before them and the beach wave.

var runner: Node
const DT := 1.0 / 120.0
const SEEDS := [4242, 7, 99]


func _world(seed_value: int, first_island: int = 1, hazards: bool = true) -> World:
	var w := World.new()
	w.autoplay = false
	w.running = true
	w.input_enabled = false
	w.run_seed = seed_value
	w.start_island = first_island
	w.hazards = hazards
	runner.add_child(w)
	return w


func _free(w: World) -> void:
	runner.remove_child(w)
	w.free()


func test_pick_bay_hills_rule() -> String:
	for s in range(1, 201):
		for hills in range(9, 16):
			var rng := RandomNumberGenerator.new()
			rng.seed = s
			var b: Array[int] = Terrain.pick_bay_hills(hills, rng)
			if b.size() != Terrain.BAYS_PER_ISLAND:
				return "seed %d hills %d: size %d" % [s, hills, b.size()]
			for i in b.size():
				if b[i] < 2 or b[i] > hills - 1:
					return "seed %d hills %d: out of range %s" % [s, hills, b]
				if i > 0 and b[i] - b[i - 1] < 2:
					return "seed %d hills %d: not sorted/consecutive %s" % [s, hills, b]
	return ""


func test_bays_only_on_pantai() -> String:
	var w := _world(4242, 0)
	var bays: Array = w.terrain.bays
	if bays.size() != Terrain.BAYS_PER_ISLAND:
		return "start 0: %d bays" % bays.size()
	for b in bays:
		if int(b.island) != 1:
			return "start 0: bay on island %d" % int(b.island)
	_free(w)
	w = _world(4242, 1)
	for b in w.terrain.bays:
		if int(b.island) != 0:
			return "start 1: bay on island %d" % int(b.island)
	return "" if w.terrain.bays.size() == Terrain.BAYS_PER_ISLAND else "start 1: %d bays" % w.terrain.bays.size()


func test_bay_water_is_not_sea() -> String:
	for s in SEEDS:
		var w := _world(s)
		var t := w.terrain
		if t.boundaries.size() != 2:
			return "seed %d: boundaries %d" % [s, t.boundaries.size()]
		for i in t.bays.size():
			var b: Dictionary = t.bays[i]
			if not t.is_water_at(b.mid) or t.is_sea_at(b.mid) or t.bay_at(b.mid) != i:
				return "seed %d bay %d: mid water=%s sea=%s bay_at=%d" % [s, i, t.is_water_at(b.mid), t.is_sea_at(b.mid), t.bay_at(b.mid)]
			if absf(t.height_at(b.lip_x) - Terrain.LIP_Y) > 0.01:
				return "seed %d bay %d: lip height %f" % [s, i, t.height_at(b.lip_x)]
			if t.is_water_at(b.water_x0 - 10.0) or t.is_water_at(b.water_x1 + 10.0):
				return "seed %d bay %d: water range too small" % [s, i]
		_free(w)
	return ""


func test_no_ground_coins_or_props_in_bay() -> String:
	for s in SEEDS:
		var w := _world(s)
		for b in w.terrain.bays:
			for it in w.coins.items:
				var p: Vector2 = it[0]
				if p.x >= b.water_x0 and p.x <= b.water_x1 and p.y > Terrain.WATER_Y - 60.0:
					return "seed %d: coin in bay at %s" % [s, p]
			for pr in w.terrain.props:
				if float(pr.x) >= b.water_x0 and float(pr.x) <= b.water_x1:
					return "seed %d: prop %s in bay" % [s, pr.kind]
		_free(w)
	return ""
