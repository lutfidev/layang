extends RefCounted
## Hutan canopy tunnels: placement, guide coins, collision and the centre path.

var runner: Node
const DT := 1.0 / 120.0
const SEEDS := [4242, 7, 99]
const HUTAN := 2


func _world(seed_value: int, first_island: int = HUTAN, hazards: bool = true) -> World:
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


func _on(w: World, k: int) -> Array:
	return w.terrain.canopies.filter(func(c: Dictionary) -> bool: return int(c.island) == k)


func _coins_in(w: World, x0: float, x1: float) -> Array:
	var out: Array = []
	for it in w.coins.items:
		var p: Vector2 = it[0]
		if p.x > x0 and p.x < x1:
			out.append(p)
	return out


# ---------------------------------------------------------------- placement (terrain)

func test_canopies_only_on_hutan() -> String:
	for s in SEEDS:
		for first in [HUTAN, 0]:
			var w := _world(s, first)
			while w.terrain.island_count_generated() < 7:
				w.terrain._generate_island()
			for k in w.terrain.island_count_generated():
				var want: int = Terrain.CANOPIES_PER_ISLAND if Biomes.get_biome(first + k).id == "hutan" else 0
				var n := _on(w, k).size()
				if n != want:
					_free(w)
					return "seed %d start %d island %d: %d canopies, want %d" % [s, first, k, n, want]
			_free(w)
	return ""


func test_canopy_spans_one_hill() -> String:
	for s in SEEDS:
		var w := _world(s)
		var tr := w.terrain
		for c in tr.canopies:
			var x0: float = c.x0
			var x1: float = c.x1
			if x1 - x0 < 800.0 or x1 - x0 > 1600.0:
				_free(w)
				return "seed %d canopy x0=%.0f: width %.0f" % [s, x0, x1 - x0]
			var peaks := 0
			for i in tr.keys_x.size():
				if tr.keys_x[i] > x0 + 1.0 and tr.keys_x[i] < x1 - 1.0:   # keys are float32
					peaks += 1
			if peaks != 1:
				_free(w)
				return "seed %d canopy x0=%.0f: %d keys inside" % [s, x0, peaks]
		_free(w)
	return ""


func test_canopy_not_first_hills() -> String:
	for s in SEEDS:
		var w := _world(s)
		var tr := w.terrain
		for c in tr.canopies:
			# island keys: [entry..., v0, p0, v1, p1, ...]; the 2nd hill's peak must lie before x0
			var first := -1
			for i in tr.keys_x.size():
				if tr.keys_island[i] == int(c.island):
					first = i
					break
			var lead := 3 if int(c.island) == 0 else 1
			var p1x := tr.keys_x[first + lead + 3]
			if float(c.x0) <= p1x:
				_free(w)
				return "seed %d canopy x0=%.0f inside the first two hills (p1=%.0f)" % [s, float(c.x0), p1x]
		_free(w)
	return ""


func test_canopy_coins() -> String:
	for s in SEEDS:
		var w := _world(s)
		var tr := w.terrain
		for c in tr.canopies:
			var cs := _coins_in(w, float(c.x0), float(c.x1))
			if cs.size() != Terrain.CANOPY_COINS:
				_free(w)
				return "seed %d canopy x0=%.0f: %d coins" % [s, float(c.x0), cs.size()]
			for p in cs:
				if absf(p.y - (tr.height_at(p.x) - Canopy.GAP * 0.5)) > 30.0:
					_free(w)
					return "seed %d canopy x0=%.0f: coin %s off the centre line" % [s, float(c.x0), p]
		_free(w)
	return ""
