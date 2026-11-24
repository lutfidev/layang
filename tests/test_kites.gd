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


# ---------------------------------------------------------------- the Kite hazard

func _ground_speed(x: float, fever: bool) -> float:
	var target := lerpf(Bird.SPEED_START, Bird.SPEED_MAX, clampf(x / Bird.SPEED_RAMP_X, 0.0, 1.0))
	return 0.85 * target * (1.3 if fever else 1.0)


## Flies the bird from x0 past the kite (or until it dies). `hold` decides holding each step.
func _fly(w: World, kt: Dictionary, x0: float, y0: float, ground: bool, fever: bool, hold: Callable) -> Array:
	var deaths: Array = []
	w.bird_died.connect(func(c: String): deaths.append(c))
	var b := w.bird
	b.position = Vector2(x0, w.terrain.height_at(x0) if ground else y0)
	b.on_ground = ground
	b.fever = fever
	b.vel = Vector2(_ground_speed(x0, fever), 0.0)
	var end_x: float = Kite.span(kt).y + 100.0
	w.input_enabled = true     # World reads holding from input: drive it through the touch flag
	var t := 0.0
	while t < 8.0 and deaths.is_empty() and b.position.x < end_x:
		w._touch_hold = hold.call(b)
		b.stamina = 1.0
		w._physics_process(DT)
		t += DT
	return deaths


func test_tail_clearance() -> String:
	for s in SEEDS:
		var w := _world(s)
		for kt in w.terrain.kites:
			var t := 0.0
			while t <= 4.0:
				var pts := Kite.tail_points(kt, t)
				if absf(pts[pts.size() - 1].y - (float(kt.peak_y) - Kite.TAIL_CLEAR)) > 0.5:
					_free(w)
					return "tail tip y=%.1f, want %.1f" % [pts[pts.size() - 1].y, float(kt.peak_y) - Kite.TAIL_CLEAR]
				for p in pts:
					if w.terrain.height_at(p.x) - p.y < Kite.TAIL_CLEAR - 0.5:
						_free(w)
						return "seed %d kite x=%.0f t=%.2f: tail %.1f above ground" % [s, float(kt.x), t, w.terrain.height_at(p.x) - p.y]
				t += 0.05
		_free(w)
	return ""


func test_ground_run_passes_under() -> String:
	for s in SEEDS:
		for fever in [false, true]:
			var probe := _world(s)
			var n: int = _kites_on(probe, 0).size()
			_free(probe)
			for i in n:
				var w := _world(s)
				var kt: Dictionary = _kites_on(w, 0)[i]
				var d := _fly(w, kt, float(kt.x) - 600.0, 0.0, true, fever, func(_b: Bird) -> bool: return false)
				_free(w)
				if not d.is_empty():
					return "seed %d fever %s kite %d: %s" % [s, fever, i, d]
	return ""


func test_skim_passes_under() -> String:
	for s in SEEDS:
		for fever in [false, true]:
			var probe := _world(s)
			var n: int = _kites_on(probe, 0).size()
			_free(probe)
			for i in n:
				var w := _world(s)
				var kt: Dictionary = _kites_on(w, 0)[i]
				var tr := w.terrain
				var d := _fly(w, kt, float(kt.x) - 600.0, 0.0, true, fever,
						func(b: Bird) -> bool: return b.position.y > tr.height_at(b.position.x) - Bird.SKIM_HEIGHT)
				_free(w)
				if not d.is_empty():
					return "seed %d fever %s kite %d: %s" % [s, fever, i, d]
	return ""


func _level(y: float) -> Callable:
	return func(b: Bird) -> bool: return b.center().y > y


func test_body_height_dies() -> String:
	for s in SEEDS:
		var w := _world(s)
		var kt: Dictionary = _kites_on(w, 0)[0]
		var y := Kite.body_center(kt, 0.0).y
		var d := _fly(w, kt, float(kt.x) - 500.0, y + Bird.RADIUS, false, false, _level(y))
		var at := w.bird.position.x
		_free(w)
		if d != ["layangan"]:
			return "seed %d: deaths=%s" % [s, d]
		if at > float(kt.x) + 100.0:
			return "seed %d: died late at x=%.0f" % [s, at]
	return ""


func test_over_body_survives() -> String:
	for s in SEEDS:
		var w := _world(s)
		var kt: Dictionary = _kites_on(w, 0)[0]
		var y := Kite.body_center(kt, 0.0).y - Kite.BODY_HH - 90.0
		var d := _fly(w, kt, float(kt.x) - 500.0, y + Bird.RADIUS, false, false, _level(y))
		_free(w)
		if not d.is_empty():
			return "seed %d: deaths=%s" % [s, d]
	return ""


func test_coins_outside_hit_zone() -> String:
	for s in SEEDS:
		var w := _world(s)
		for kt in w.terrain.kites:
			for p in _arc_coins(w, kt):
				var t := 0.0
				while t <= 4.0:
					if Kite.hits(kt, t, p):
						_free(w)
						return "seed %d kite x=%.0f: coin %s inside the hit zone at t=%.2f" % [s, float(kt.x), p, t]
					t += 0.05
		_free(w)
	return ""


func test_menu_world_no_kite_death() -> String:
	var w := _world(4242, 0, false)
	var kt: Dictionary = _kites_on(w, 0)[0]
	var y := Kite.body_center(kt, 0.0).y
	var d := _fly(w, kt, float(kt.x) - 500.0, y + Bird.RADIUS, false, false, _level(y))
	var at := w.bird.position.x
	_free(w)
	if not d.is_empty():
		return "deaths=%s" % [d]
	return "" if at > Kite.span(kt).y else "stopped at x=%.0f" % at


func test_autopilot_clears_kites() -> String:
	for s in [11, 22, 33, 44, 55]:
		var w := _world(s)
		w.autoplay = true
		var deaths: Array = []
		w.bird_died.connect(func(c: String): deaths.append(c))
		var ks := _kites_on(w, 0)
		var end_x: float = Kite.span(ks[ks.size() - 1]).y + 100.0
		var t := 0.0
		while t < 90.0 and deaths.is_empty() and w.bird.position.x < end_x:
			w._physics_process(DT)
			t += DT
		var at := w.bird.position.x
		_free(w)
		if not deaths.is_empty():
			return "seed %d: died (%s) at x=%.0f" % [s, deaths[0], at]
		if at < end_x:
			return "seed %d: only reached x=%.0f" % [s, at]
	return ""
