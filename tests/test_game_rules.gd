extends RefCounted
## Run rules in game.gd: skim combo → fever, bonk resets, death causes, continue, nightfall.

var runner: Node
const DT := 1.0 / 120.0


func _game() -> Node:
	var g: Node = load("res://scenes/game.tscn").instantiate()
	runner.add_child(g)
	g._start()
	return g


func _has_text(n: Node, text: String) -> bool:
	if n is Label and (n as Label).text == text:
		return true
	for c in n.get_children():
		if _has_text(c, text):
			return true
	return false


func _sea_start(w: World) -> float:
	var x := w.terrain.island_finish[0]
	while not w.terrain.is_sea_at(x):
		x += 10.0
	return x


func _frames(g: Node, seconds: float) -> void:
	for i in int(seconds / DT):
		g._physics_process(DT)
		g.world._physics_process(DT)


func test_skim_combo_fever() -> String:
	var g := _game()
	for i in 3:
		g.world.bird_skimmed.emit(1.0)
	if g.fever_t <= 0.0:
		return "no fever after 3 skims"
	return "" if g.style_points == 25 + 50 + 75 else "style_points=%d" % g.style_points


func test_bonk_resets_combo() -> String:
	var g := _game()
	g.world.bird_skimmed.emit(1.0)
	g.world.bird_skimmed.emit(1.0)
	g.world.bird_landed.emit(true)
	return "" if g.skim_streak == 0 else "streak=%d" % g.skim_streak


func test_death_ends_run() -> String:
	var g := _game()
	g.world.bird_died.emit("monster")
	if g.state != "over" or g.end_cause != "monster":
		return "state=%s cause=%s" % [g.state, g.end_cause]
	return "" if _has_text(g.result_panel, "Digigit monster laut!") else "results title missing"


func test_continue_after_drown_is_safe() -> String:
	var g := _game()
	var w: World = g.world
	var deaths: Array = []
	w.bird_died.connect(func(c: String): deaths.append(c))
	w.bird.position = Vector2(_sea_start(w) + 50.0, Terrain.WATER_Y - 100.0)
	w.bird.on_ground = false
	_frames(g, 3.0)
	if deaths != ["laut"] or g.state != "over":
		return "did not drown first: %s state=%s" % [deaths, g.state]
	g._continue_run()
	if w.bird.position.y > Terrain.WATER_Y - 500.0:
		return "respawn too low y=%f" % w.bird.position.y
	if w.bird.stamina != 1.0 or w.bird.exhausted:
		return "stamina not restored"
	if w.monster.state != "idle":
		return "monster still active"
	_frames(g, 1.5)
	return "" if deaths.size() == 1 else "died again right after continue: %s" % [deaths]


func test_night_over_sea_ends_run() -> String:
	var g := _game()
	var w: World = g.world
	w.bird.position = Vector2(_sea_start(w) + 50.0, Terrain.WATER_Y - 400.0)
	w.bird.on_ground = false
	g.time_left = 0.1
	_frames(g, g.NIGHT_GRACE + 4.0)
	if g.state != "over":
		return "still %s after grace" % g.state
	return "" if g.end_cause in ["laut", "senja"] else "cause=%s" % g.end_cause


func test_wave_death_title() -> String:
	var g := _game()
	g.world.bird_died.emit("ombak")
	if g.state != "over" or g.end_cause != "ombak":
		return "state=%s cause=%s" % [g.state, g.end_cause]
	return "" if _has_text(g.result_panel, "Terkena ombak") else "results title missing"


func test_wave_passed_rewards() -> String:
	var g := _game()
	g.world.wave_passed.emit()
	if g.style_points != g.WAVE_POINTS:
		return "style_points=%d" % g.style_points
	return "" if g.lbl_popup.text == "LOLOS OMBAK!" else "popup=%s" % g.lbl_popup.text


func test_pantai_warns_about_waves() -> String:
	var g := _game()
	g._on_island(1, Biomes.get_biome(1))
	return "" if g.lbl_popup.text == "Awas ombak!" else "popup=%s" % g.lbl_popup.text


func test_continue_after_bay_death_is_safe() -> String:
	Game.dev["island"] = 1
	var g := _game()
	Game.dev.erase("island")
	var w: World = g.world
	var deaths: Array = []
	w.bird_died.connect(func(c: String): deaths.append(c))
	var bay: Dictionary = w.terrain.bays[0]
	w.bird.position = Vector2(bay.lip_x, Terrain.LIP_Y - 40.0)
	w.bird.vel = Vector2(Bird.SPEED_START, 0.0)
	w.bird.on_ground = false
	_frames(g, 3.0)
	if deaths != ["ombak"] or g.state != "over":
		return "did not hit the wave first: %s state=%s" % [deaths, g.state]
	g._continue_run()
	if w.bird.position.y > Terrain.WATER_Y - 500.0:
		return "respawn too low y=%f" % w.bird.position.y
	_frames(g, 2.0)
	return "" if deaths.size() == 1 else "died again right after continue: %s" % [deaths]
