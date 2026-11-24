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


# ---------------------------------------------------------------- launch lip

func _bird_on(w: World, x: float, ground: bool, y: float = 0.0) -> Bird:
	var b := w.bird
	b.position = Vector2(x, w.terrain.height_at(x) if ground else y)
	b.on_ground = ground
	b.vel = Vector2(0.85 * Bird.SPEED_START, 0.0)
	b.holding = false
	return b


func test_lip_kicks_grounded_bird() -> String:
	var w := _world(4242)
	var lip: Dictionary = w.terrain.bays[0]
	var b := _bird_on(w, lip.lip_x - 150.0, true)
	var kicks: Array = []
	b.kicked.connect(func(): kicks.append(b.vel.y))
	var kick_vy := 0.0
	while b.position.x < lip.lip_x + Terrain.KICK_AFTER + 20.0:
		var before := kicks.size()
		b.step(DT)
		if kicks.size() > before:
			kick_vy = b.vel.y
			if b.on_ground:
				return "still on ground after kick"
	if kicks.size() != 1:
		return "kicks=%d" % kicks.size()
	return "" if kick_vy <= -Bird.LIP_KICK + Bird.GRAVITY * DT * 2.0 else "kick vel.y=%f" % kick_vy


func test_airborne_bird_not_kicked() -> String:
	var w := _world(4242)
	var lip: Dictionary = w.terrain.bays[0]
	var b := _bird_on(w, lip.lip_x - 100.0, false, Terrain.LIP_Y - 40.0)
	var kicks := [0]
	b.kicked.connect(func(): kicks[0] += 1)
	while b.position.x < lip.lip_x + 60.0:
		b.position.y = Terrain.LIP_Y - 40.0
		b.vel.y = 0.0
		b.step(DT)
	return "" if kicks[0] == 0 else "kicked while airborne"


func test_bank_landing_is_soft() -> String:
	var w := _world(4242)
	var t := w.terrain
	var bay: Dictionary = t.bays[0]
	var x: float = bay.water_x1 + 2.0
	while x < bay.bank_x and t.slope_at(x) >= Bird.BONK_SLOPE:
		x += 4.0
	if x >= bay.bank_x:
		return "no steep spot on bank (test vacuous)"
	var b := _bird_on(w, x, false, t.height_at(x) - 3.0)
	b.vel = Vector2(0.0, Bird.MAX_FALL)
	var got: Array = []
	b.landed.connect(func(bonk: bool): got.append(bonk))
	for i in 10:
		b.step(DT)
		if not got.is_empty():
			break
	return "" if got == [false] else "landed=%s" % [got]


func test_no_skim_over_bay() -> String:
	var w := _world(4242)
	var bay: Dictionary = w.terrain.bays[0]
	var b := _bird_on(w, bay.water_x0, false, Terrain.WATER_Y - 40.0)
	var skims := [0]
	b.skimmed.connect(func(_d: float): skims[0] += 1)
	b.vel.x = 120.0   # slow: long enough over the water to count as a skim
	while b.position.x < bay.water_x1:
		b.position.y = Terrain.WATER_Y - 40.0
		b.vel = Vector2(120.0, 0.0)
		b.step(DT)
	b.position.y = Terrain.WATER_Y - 400.0
	b.step(DT)
	return "" if skims[0] == 0 else "skimmed over bay water"


# ---------------------------------------------------------------- wave

const CROSS_SEEDS := [4242, 7, 99, 1234, 555]


## Runs the world until the bird is past bay i's far bank, dies, or 6 s pass.
## `setup` positions the bird; returns deaths, kicks, passes and the lowest bird
## center (largest y) seen inside the wave column.
func _cross_bay(w: World, i: int, setup: Callable) -> Dictionary:
	var bay: Dictionary = w.terrain.bays[i]
	var r := {"deaths": [], "kicked": 0, "passed": 0, "low": -INF}
	w.bird_died.connect(func(c: String): r.deaths.append(c))
	w.bird.kicked.connect(func(): r.kicked += 1)
	w.wave_passed.connect(func(): r.passed += 1)
	setup.call(w.bird, bay)
	var t := 0.0
	while t < 6.0 and r.deaths.is_empty() and w.bird.position.x < bay.bank_x + 50.0:
		w._physics_process(DT)
		t += DT
		var c := w.bird.center()
		if absf(c.x - bay.mid) < Wave.WAVE_HALF:
			r.low = maxf(r.low, c.y)
	return r


func _ground_speed(x: float, fever: bool) -> float:
	var target := lerpf(Bird.SPEED_START, Bird.SPEED_MAX, clampf(x / Bird.SPEED_RAMP_X, 0.0, 1.0))
	return 0.85 * target * (1.3 if fever else 1.0)


func test_kick_clears_every_wave() -> String:
	var worst := -INF
	var worst_at := ""
	for s in CROSS_SEEDS:
		for first in [1, 0]:
			for fever in [false, true]:
				for i in Terrain.BAYS_PER_ISLAND:
					var w := _world(s, first)
					var setup := func(b: Bird, bay: Dictionary) -> void:
						var x: float = bay.lip_x - 200.0
						b.position = Vector2(x, w.terrain.height_at(x))
						b.on_ground = true
						b.fever = fever
						b.vel = Vector2(_ground_speed(x, fever), 0.0)
					var r := _cross_bay(w, i, setup)
					_free(w)
					if not r.deaths.is_empty() or r.kicked != 1 or r.passed != 1:
						return "seed %d start %d fever %s bay %d: deaths=%s kicked=%d passed=%d low=%.1f crest=%.1f" % [s, first, fever, i, r.deaths, r.kicked, r.passed, r.low, Terrain.WATER_Y - Wave.WAVE_H]
					if r.low > worst:
						worst = r.low
						worst_at = "seed %d start %d fever %s bay %d" % [s, first, fever, i]
	print("  kick margin: lowest bird center in wave column y=%.1f (+pad %.0f) vs crest y=%.1f at %s" % [worst, Wave.HIT_PAD, Terrain.WATER_Y - Wave.WAVE_H, worst_at])
	return ""


func test_kick_clears_after_bonk() -> String:
	for s in CROSS_SEEDS:
		for i in Terrain.BAYS_PER_ISLAND:
			var w := _world(s, 1)
			var setup := func(b: Bird, bay: Dictionary) -> void:
				var x: float = bay.lip_x - Terrain.LIP_RAMP
				b.position = Vector2(x, w.terrain.height_at(x))
				b.on_ground = true
				b.vel = Vector2(0.6 * Bird.SPEED_START, 0.0)
			var r := _cross_bay(w, i, setup)
			_free(w)
			if not r.deaths.is_empty() or r.passed != 1:
				return "seed %d bay %d: deaths=%s passed=%d low=%.1f" % [s, i, r.deaths, r.passed, r.low]
	return ""


func test_low_slow_glide_hits_wave() -> String:
	for s in CROSS_SEEDS:
		for i in Terrain.BAYS_PER_ISLAND:
			var w := _world(s, 1)
			var setup := func(b: Bird, bay: Dictionary) -> void:
				b.position = Vector2(bay.lip_x, Terrain.LIP_Y - 40.0)
				b.on_ground = false
				b.vel = Vector2(Bird.SPEED_START, 0.0)
			var r := _cross_bay(w, i, setup)
			_free(w)
			if r.deaths != ["ombak"]:
				return "seed %d bay %d: deaths=%s kicked=%d" % [s, i, r.deaths, r.kicked]
	return ""


func test_holding_clears_wave() -> String:
	for s in CROSS_SEEDS:
		var w := _world(s, 1)
		w.input_enabled = true
		w._touch_hold = true
		var setup := func(b: Bird, bay: Dictionary) -> void:
			b.position = Vector2(bay.lip_x, Terrain.LIP_Y - 40.0)
			b.on_ground = false
			b.vel = Vector2(Bird.SPEED_START, 0.0)
		var r := _cross_bay(w, 0, setup)
		_free(w)
		if not r.deaths.is_empty() or r.passed != 1:
			return "seed %d: deaths=%s passed=%d" % [s, r.deaths, r.passed]
	return ""


func test_foam_before_rise() -> String:
	var w := _world(4242, 1)
	var bay: Dictionary = w.terrain.bays[0]
	var x: float = bay.mid - 2000.0
	w.bird.position = Vector2(x, w.terrain.height_at(x) - 80.0)
	w.bird.on_ground = false
	w.bird.vel = Vector2(_ground_speed(x, false), 0.0)
	var seq: Array = [w.wave.state]
	var foam_d := INF
	var h_at_mid := -1.0
	var t := 0.0
	while t < 8.0 and not w.dead and w.bird.position.x < bay.mid + 20.0:
		# keep the bird safely above everything: this test only watches the wave
		w.bird.position.y = minf(w.bird.position.y, Terrain.WATER_Y - Wave.WAVE_H - 200.0)
		w._physics_process(DT)
		t += DT
		if w.wave.state != seq[seq.size() - 1]:
			seq.append(w.wave.state)
			if w.wave.state == "foam":
				foam_d = bay.mid - w.bird.position.x
		if h_at_mid < 0.0 and w.bird.position.x >= bay.mid:
			h_at_mid = w.wave.height
	if seq.slice(0, 3) != ["idle", "foam", "rise"]:
		return "states=%s" % [seq]
	if foam_d > Wave.FOAM_DIST or foam_d < Wave.FOAM_DIST - 30.0:
		return "foam started at d=%.1f" % foam_d
	return "" if is_equal_approx(h_at_mid, Wave.WAVE_H) else "height at mid=%.1f" % h_at_mid


func test_no_monster_in_bay() -> String:
	var w := _world(4242, 1)
	var bay: Dictionary = w.terrain.bays[0]
	w.bird.position = Vector2(bay.water_x0 - 100.0, Terrain.WATER_Y - 150.0)
	w.bird.on_ground = false
	w.bird.vel = Vector2(Bird.SPEED_START, 0.0)
	while w.bird.position.x < bay.water_x1 + 100.0:
		w.bird.position.y = Terrain.WATER_Y - 450.0
		w.bird.vel.y = 0.0
		w._physics_process(DT)
		if w.monster.state != "idle":
			return "monster armed over a bay"
	return ""


func test_menu_world_bay_bounces() -> String:
	var w := _world(4242, 1, false)
	var deaths: Array = []
	w.bird_died.connect(func(c: String): deaths.append(c))
	var bay: Dictionary = w.terrain.bays[0]
	w.bird.position = Vector2(bay.water_x0, Terrain.WATER_Y - 60.0)
	w.bird.on_ground = false
	w.bird.vel = Vector2(Bird.SPEED_START, 0.0)
	var saw_wave := false
	for i in int(2.0 / DT):
		w._physics_process(DT)
		saw_wave = saw_wave or w.wave.state != "idle"
	if not deaths.is_empty():
		return "died in menu world: %s" % [deaths]
	if not saw_wave:
		return "no wave in menu world"
	return "" if w.bird.position.y < Terrain.WATER_Y else "bird under water y=%f" % w.bird.position.y


func test_fever_overshoot_passes_once() -> String:
	var w := _world(4242, 1)
	var passes := [0]
	w.wave_passed.connect(func(): passes[0] += 1)
	var bay: Dictionary = w.terrain.bays[0]
	var x: float = bay.lip_x - 200.0
	w.bird.position = Vector2(x, w.terrain.height_at(x))
	w.bird.on_ground = true
	w.bird.fever = true
	w.bird.vel = Vector2(Bird.SPEED_MAX * 1.3, 0.0)
	var t := 0.0
	while t < 4.0 and not w.dead and w.bird.position.x < bay.bank_x + 600.0:
		w._physics_process(DT)
		t += DT
	if w.dead:
		return "died"
	return "" if passes[0] == 1 else "passes=%d" % passes[0]


func test_autopilot_clears_bays() -> String:
	for s in [11, 22, 33, 44, 55]:
		var w := _world(s, 1)
		w.autoplay = true
		var deaths: Array = []
		var passes := [0]
		w.bird_died.connect(func(c: String): deaths.append(c))
		w.wave_passed.connect(func(): passes[0] += 1)
		var end_x: float = w.terrain.bays[w.terrain.bays.size() - 1].bank_x + 100.0
		var t := 0.0
		while t < 90.0 and deaths.is_empty() and w.bird.position.x < end_x:
			w._physics_process(DT)
			t += DT
		var at := w.bird.position.x
		var bay := w.terrain.bay_at(at)
		_free(w)
		if not deaths.is_empty():
			return "seed %d: died (%s) at x=%.0f bay=%d after %d passes" % [s, deaths[0], at, bay, passes[0]]
		if passes[0] != Terrain.BAYS_PER_ISLAND:
			return "seed %d: passes=%d (t=%.1f)" % [s, passes[0], t]
	return ""


# ---------------------------------------------------------------- final review fixes

func test_continue_far_from_bay_keeps_next_wave() -> String:
	var w := _world(4242, 1)
	for i in 30:
		w._physics_process(DT)   # wave picks up bay 0 while still far away
	w.clear_hazards()            # e.g. "Lanjut" after a death nowhere near a bay
	var rose := [false]
	var setup := func(b: Bird, bay: Dictionary) -> void:
		var x: float = bay.lip_x - 900.0
		b.position = Vector2(x, w.terrain.height_at(x) - 300.0)
		b.on_ground = false
		b.vel = Vector2(_ground_speed(x, false), 0.0)
	var bay: Dictionary = w.terrain.bays[0]
	setup.call(w.bird, bay)
	var passes := [0]
	w.wave_passed.connect(func(): passes[0] += 1)
	var t := 0.0
	while t < 6.0 and w.bird.position.x < bay.bank_x:
		w.bird.position.y = minf(w.bird.position.y, Terrain.WATER_Y - Wave.WAVE_H - 250.0)
		w._physics_process(DT)
		t += DT
		rose[0] = rose[0] or (w.wave.state == "rise" and w.wave.bay == 0)
	if not rose[0]:
		return "bay 0 wave never rose after a far-away continue (bay=%d)" % w.wave.bay
	return "" if passes[0] == 1 else "passes=%d" % passes[0]


func test_kick_landing_never_bonks() -> String:
	for s in CROSS_SEEDS:
		for first in [1, 0]:
			for fever in [false, true]:
				for i in Terrain.BAYS_PER_ISLAND:
					var w := _world(s, first)
					var bay: Dictionary = w.terrain.bays[i]
					var x: float = bay.lip_x - 200.0
					var b := w.bird
					b.position = Vector2(x, w.terrain.height_at(x))
					b.on_ground = true
					b.fever = fever
					b.vel = Vector2(_ground_speed(x, fever), 0.0)
					var landings: Array = []
					var kicked := [false]
					b.kicked.connect(func(): kicked[0] = true)
					b.landed.connect(func(bonk: bool):
						if kicked[0]:
							landings.append(bonk))
					var t := 0.0
					while t < 5.0 and not w.dead and landings.is_empty():
						w._physics_process(DT)
						t += DT
					_free(w)
					if landings != [false]:
						return "seed %d start %d fever %s bay %d: landings=%s" % [s, first, fever, i, landings]
	return ""


func test_menu_world_is_silent() -> String:
	var was_on := Game.sound_on
	Game.sound_on = true
	var res := _menu_silence()
	Game.sound_on = was_on
	return res


func _menu_silence() -> String:
	var w := _world(4242, 1, false)
	var bay: Dictionary = w.terrain.bays[0]
	var x: float = bay.mid - 2200.0
	w.bird.position = Vector2(x, w.terrain.height_at(x))
	w.bird.on_ground = true
	w.bird.vel = Vector2(_ground_speed(x, false), 0.0)
	var before: int = Sfx._next
	var t := 0.0
	while t < 8.0 and w.bird.position.x < bay.bank_x:
		w._physics_process(DT)
		t += DT
	if w.wave.state == "idle" and w.bird.position.x < bay.mid:
		return "never reached the bay (test vacuous)"
	return "" if Sfx._next == before else "menu world played %d sounds" % posmod(Sfx._next - before, 8)
