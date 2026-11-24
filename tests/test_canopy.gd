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


# ---------------------------------------------------------------- the Canopy hazard

func _ground_speed(x: float, fever: bool) -> float:
	var target := lerpf(Bird.SPEED_START, Bird.SPEED_MAX, clampf(x / Bird.SPEED_RAMP_X, 0.0, 1.0))
	return 0.85 * target * (1.3 if fever else 1.0)


## Flies the bird from x0 to past the tunnel's end (or until it dies); `hold` decides holding each step.
## Returns [deaths, passes].
func _fly(w: World, c: Dictionary, x0: float, y0: float, ground: bool, speed: float, fever: bool, hold: Callable) -> Array:
	var deaths: Array = []
	var passes: Array = []
	w.bird_died.connect(func(cause: String): deaths.append(cause))
	w.hazard_passed.connect(func(cause: String): passes.append(cause))
	var b := w.bird
	b.position = Vector2(x0, w.terrain.height_at(x0) if ground else y0)
	b.on_ground = ground
	b.fever = fever
	b.vel = Vector2(speed, 0.0)
	var end_x: float = float(c.x1) + 200.0
	w.input_enabled = true
	var t := 0.0
	while t < 10.0 and deaths.is_empty() and b.position.x < end_x:
		w._touch_hold = hold.call(b)
		b.stamina = 1.0
		w._physics_process(DT)
		t += DT
	return [deaths, passes]


## Holds toward the corridor's centre line slightly ahead of the bird.
func _centre(tr: Terrain) -> Callable:
	return func(b: Bird) -> bool:
		var ax := b.position.x + b.vel.x * 0.3
		return b.center().y + b.vel.y * 0.15 > tr.height_at(ax) - Canopy.GAP * 0.5


func test_canopy_center_path_passes() -> String:
	for s in SEEDS:
		for mode in ["start", "max", "fever"]:
			var probe := _world(s)
			var n: int = _on(probe, 0).size()
			_free(probe)
			for i in n:
				var w := _world(s)
				var c: Dictionary = _on(w, 0)[i]
				var tr := w.terrain
				var x0: float = float(c.x0) - 600.0
				var speed: float = Bird.SPEED_START if mode == "start" else Bird.SPEED_MAX
				var fever: bool = mode == "fever"
				if fever:
					speed = Bird.SPEED_MAX * 1.3
				var r := _fly(w, c, x0, tr.height_at(x0) - Canopy.GAP * 0.5, false, speed, fever, _centre(tr))
				_free(w)
				if not r[0].is_empty():
					return "seed %d %s canopy %d: died %s" % [s, mode, i, r[0]]
				if r[1] != ["hutan"]:
					return "seed %d %s canopy %d: passes %s" % [s, mode, i, r[1]]
	return ""


func test_canopy_ground_run_dies() -> String:
	for s in SEEDS:
		var w := _world(s)
		var c: Dictionary = _on(w, 0)[0]
		var r := _fly(w, c, float(c.x0) - 400.0, 0.0, true, 500.0, false, func(_b: Bird) -> bool: return false)
		var at := w.bird.position.x
		_free(w)
		if r[0] != ["hutan"]:
			return "seed %d: deaths=%s" % [s, r[0]]
		if at > float(c.x0) + 60.0:
			return "seed %d: died late at x=%.0f" % [s, at]
	return ""


func test_canopy_roof_dies() -> String:
	for s in SEEDS:
		var w := _world(s)
		var c: Dictionary = _on(w, 0)[0]
		var y := Canopy.roof_y(w.terrain, float(c.x0) + 100.0) - 40.0
		var r := _fly(w, c, float(c.x0) - 400.0, y + Bird.RADIUS, false, 500.0, false,
				func(b: Bird) -> bool: return b.center().y > y)
		_free(w)
		if r[0] != ["hutan"]:
			return "seed %d: deaths=%s" % [s, r[0]]
	return ""


func test_canopy_safe_in_menu() -> String:
	var w := _world(4242, HUTAN, false)
	w.autoplay = true
	var cs := _on(w, 0)
	var end_x: float = float(cs[cs.size() - 1].x1) + 100.0
	var t := 0.0
	while t < 120.0 and not w.dead and w.bird.position.x < end_x:
		w._physics_process(DT)
		t += DT
	var at := w.bird.position.x
	var dead := w.dead
	_free(w)
	if dead:
		return "menu world died"
	return "" if at >= end_x else "stopped at x=%.0f" % at


func test_autopilot_clears_canopies() -> String:
	for s in [11, 22, 33, 44, 55]:
		var w := _world(s)
		w.autoplay = true
		var deaths: Array = []
		w.bird_died.connect(func(cause: String): deaths.append(cause))
		var cs := _on(w, 0)
		var end_x: float = float(cs[cs.size() - 1].x1) + 100.0
		var t := 0.0
		while t < 120.0 and deaths.is_empty() and w.bird.position.x < end_x:
			w._physics_process(DT)
			t += DT
		var at := w.bird.position.x
		_free(w)
		if not deaths.is_empty():
			return "seed %d: died (%s) at x=%.0f" % [s, deaths[0], at]
		if at < end_x:
			return "seed %d: only reached x=%.0f" % [s, at]
	return ""
