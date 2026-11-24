extends RefCounted
## Sea hazards: drowning and the jumping sea monster, driven through a real World.

var runner: Node
const DT := 1.0 / 120.0


func _world(hazards: bool = true) -> World:
	var w := World.new()
	w.autoplay = false
	w.running = true
	w.input_enabled = false
	w.run_seed = 4242
	w.hazards = hazards
	runner.add_child(w)
	return w


func _sea_start(w: World) -> float:
	var x := w.terrain.island_finish[0]
	while not w.terrain.is_sea_at(x):
		x += 10.0
	return x


func _put(w: World, x: float, y: float) -> void:
	w.bird.position = Vector2(x, y)
	w.bird.vel = Vector2(Bird.SPEED_START, 0)
	w.bird.on_ground = false


func _deaths(w: World) -> Array:
	var got: Array = []
	w.bird_died.connect(func(c: String): got.append(c))
	return got


func test_drown_ends() -> String:
	var w := _world()
	var deaths := _deaths(w)
	_put(w, _sea_start(w) + 50.0, Terrain.WATER_Y - 200.0)
	for i in int(4.0 / DT):
		w._physics_process(DT)
		if not deaths.is_empty():
			break
	if deaths != ["laut"]:
		return "deaths=%s" % [deaths]
	if not w.dead:
		return "world not dead"
	var x := w.bird.position.x
	for i in 30:
		w._physics_process(DT)
	return "" if w.bird.position.x == x else "bird still moving after death"


func _hold_at(w: World, y: float, seconds: float, deaths: Array) -> Dictionary:
	var warn_at := -1.0
	var jumped := false
	var t := 0.0
	while t < seconds and deaths.is_empty():
		w.bird.position.y = y
		w.bird.vel.y = 0.0
		w._physics_process(DT)
		t += DT
		if w.monster.state == "warn" and warn_at < 0.0:
			warn_at = t
		if w.monster.state == "jump":
			jumped = true
		if not w.terrain.is_sea_at(w.bird.position.x) and t > 0.5:
			break
	return {"t": t, "warn_at": warn_at, "jumped": jumped}


func test_monster_bites_low_bird() -> String:
	var w := _world()
	var deaths := _deaths(w)
	_put(w, _sea_start(w) + 20.0, Terrain.WATER_Y - 150.0)
	var r := _hold_at(w, Terrain.WATER_Y - 150.0, 6.0, deaths)
	if deaths != ["monster"]:
		return "deaths=%s after %.2fs" % [deaths, r.t]
	if r.warn_at < 0.0 or r.t - r.warn_at < 0.9:
		return "no fair warning (warn_at=%.2f bite=%.2f)" % [r.warn_at, r.t]
	return ""


func test_monster_cannot_reach_high_bird() -> String:
	var w := _world()
	var deaths := _deaths(w)
	_put(w, _sea_start(w) + 20.0, 0.0)
	var r := _hold_at(w, Terrain.WATER_Y - SeaMonster.PEAK_ABOVE_WATER - 120.0, 12.0, deaths)
	if not deaths.is_empty():
		return "bitten high: %s" % [deaths]
	return "" if r.jumped else "monster never jumped (test vacuous)"


func test_jumps_scale() -> String:
	var m := SeaMonster.new()
	var got := [m.jumps_for_island(0), m.jumps_for_island(2), m.jumps_for_island(6)]
	m.free()
	return "" if got == [1, 2, 3] else "got %s" % [got]


func test_no_hazards_in_menu_world() -> String:
	var w := _world(false)
	var deaths := _deaths(w)
	_put(w, _sea_start(w) + 50.0, Terrain.WATER_Y + 20.0)
	for i in int(2.0 / DT):
		w._physics_process(DT)
		if w.monster.state != "idle":
			return "monster armed in menu world"
	if not deaths.is_empty():
		return "died in menu world"
	return "" if w.bird.position.y < Terrain.WATER_Y else "bird under water y=%f" % w.bird.position.y


func test_fast_bird_still_gets_a_jump() -> String:
	var w := _world()
	_put(w, _sea_start(w) + 20.0, Terrain.WATER_Y - 450.0)
	w.bird.fever = true
	w.bird.vel.x = Bird.SPEED_MAX * 1.3
	var armed := false
	for i in int(3.0 / DT):
		w.bird.position.y = Terrain.WATER_Y - 450.0
		w.bird.vel.y = 0.0
		w._physics_process(DT)
		if w.monster.state != "idle":
			armed = true
			break
		if not w.terrain.is_sea_at(w.bird.position.x):
			break
	if not armed:
		return "no jump for a fast bird over the first sea"
	var tx := w.monster.target_x
	if not (w.terrain.is_sea_at(tx - SeaMonster.SPAN * 0.5) and w.terrain.is_sea_at(tx + SeaMonster.SPAN * 0.5)):
		return "arc not over the sea: tx=%f" % tx
	return ""
