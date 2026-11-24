extends RefCounted
## Villagers' kites over Sawah peaks: placement, coin arcs, collision and the safe low path.

var runner: Node
const DT := 1.0 / 120.0
const SEEDS := [4242, 7, 99]


func _world(seed_value: int, first_island: int = 0, hazards: bool = true) -> World:
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


func _kites_on(w: World, k: int) -> Array:
	return w.terrain.kites.filter(func(kt: Dictionary) -> bool: return int(kt.island) == k)


# ---------------------------------------------------------------- placement (terrain)

func test_pick_hills_rule() -> String:
	for count in [2, 3]:
		for s in range(1, 201):
			for hills in range(9, 16):
				var rng := RandomNumberGenerator.new()
				rng.seed = s
				var p: Array[int] = Terrain.pick_hills(hills, count, rng)
				if p.size() != count:
					return "count %d seed %d hills %d: size %d" % [count, s, hills, p.size()]
				for i in p.size():
					if p[i] < 2 or p[i] > hills - 1:
						return "count %d seed %d hills %d: out of range %s" % [count, s, hills, p]
					if i > 0 and p[i] - p[i - 1] < 2:
						return "count %d seed %d hills %d: not sorted/consecutive %s" % [count, s, hills, p]
	return ""


func test_kites_only_on_sawah() -> String:
	for first in [0, 1]:
		for s in SEEDS:
			var w := _world(s, first)
			while w.terrain.island_count_generated() < 7:
				w.terrain._generate_island()
			var total := 0
			for k in w.terrain.island_count_generated():
				var n := _kites_on(w, k).size()
				total += n
				var sawah: bool = Biomes.get_biome(w.terrain.biome_index_of_island(k)).id == "sawah"
				var want: int = Terrain.KITES_PER_ISLAND if sawah else 0
				if n != want:
					_free(w)
					return "start %d seed %d island %d: %d kites, want %d" % [first, s, k, n, want]
			if total != w.terrain.kites.size():
				_free(w)
				return "start %d seed %d: kites on ungenerated islands" % [first, s]
			for i in range(1, w.terrain.kites.size()):
				if float(w.terrain.kites[i].x) <= float(w.terrain.kites[i - 1].x):
					_free(w)
					return "kites not sorted by x"
			_free(w)
	return ""


func test_kite_at_peak() -> String:
	for s in SEEDS:
		var w := _world(s)
		for kt in w.terrain.kites:
			var x: float = kt.x
			var py: float = kt.peak_y
			if absf(w.terrain.height_at(x) - py) > 1.0:
				_free(w)
				return "seed %d kite x=%.0f: peak_y %.1f vs ground %.1f" % [s, x, py, w.terrain.height_at(x)]
			var dx := -200.0
			while dx <= 200.0:
				if w.terrain.height_at(x + dx) < py - 1.0:
					_free(w)
					return "seed %d kite x=%.0f: ground higher than the peak at dx=%.0f" % [s, x, dx]
				dx += 10.0
		_free(w)
	return ""


func _arc_coins(w: World, kt: Dictionary) -> Array:
	var out: Array = []
	for it in w.coins.items:
		var p: Vector2 = it[0]
		if absf(p.x - float(kt.x)) <= Terrain.KITE_ARC_HALF + 0.5 and p.y < float(kt.peak_y) - 380.0:
			out.append(p)
	return out


func test_kite_coin_arc() -> String:
	for s in SEEDS:
		var w := _world(s)
		for kt in w.terrain.kites:
			var n := _arc_coins(w, kt).size()
			if n != Terrain.KITE_ARC_COINS:
				_free(w)
				return "seed %d kite x=%.0f: %d arc coins" % [s, float(kt.x), n]
		_free(w)
	return ""
