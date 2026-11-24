extends RefCounted
## Run rules in game.gd: skim combo → fever, bonk resets, death causes, continue, endless run, lose screen.

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


func _buttons(n: Node, out: Array = []) -> Array:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_buttons(c, out)
	return out


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
	var score_before: int = g.score()
	g._continue_run()
	if w.terrain.is_water_at(w.bird.position.x):
		return "respawned over water x=%f" % w.bird.position.x
	if w.bird.position.y > w.terrain.height_at(w.bird.position.x) - 150.0:
		return "respawn too low y=%f" % w.bird.position.y
	if w.bird.stamina != 1.0 or w.bird.exhausted:
		return "stamina not restored"
	if w.monster.state != "idle":
		return "monster still active"
	_frames(g, 1.5)
	if g.score() < score_before:
		return "score dropped %d -> %d" % [score_before, g.score()]
	return "" if deaths.size() == 1 else "died again right after continue: %s" % [deaths]


func test_no_timer_endless() -> String:
	var g := _game()
	for p in ["time_left", "night_t", "time_bar"]:
		if p in g:
			return "timer leftover: %s" % p
	var w: World = g.world
	w.hazards = false     # bounces off the water: only a timer could end this run
	_frames(g, 60.0)
	if g.state != "play":
		return "run ended without an obstacle: state=%s cause=%s" % [g.state, g.end_cause]
	return "" if g.distance > 0 else "distance=%d" % g.distance


func test_lose_screen_three_buttons() -> String:
	var g := _game()
	g.world.bird_died.emit("laut")
	var names: Array = []
	for b in _buttons(g.result_panel):
		names.append(String(b.name))
	names.sort()
	if names != ["Lanjut", "MainLagi", "Menu"]:
		return "buttons=%s" % [names]
	var labels: Array = []
	for b in _buttons(g.result_panel):
		labels.append(b.text)
	if not ("Main Lagi" in labels and "Menu" in labels and "Lanjut (tonton iklan)" in labels):
		return "button labels %s" % [labels]
	return "" if _has_text(g.result_panel, g.CAUSE_TIPS["laut"]) else "cause tip missing"


func test_continue_button_once() -> String:
	var g := _game()
	g.world.bird.position = Vector2(_sea_start(g.world) + 50.0, Terrain.WATER_Y + 10.0)
	g.world.bird_died.emit("laut")
	g._continue_run()
	g.world.bird_died.emit("monster")
	var cont: Button = g.result_panel.find_child("Lanjut", true, false)
	if cont == null or not cont.disabled:
		return "Lanjut should be disabled after one continue"
	return "" if _buttons(g.result_panel).size() == 3 else "buttons=%d" % _buttons(g.result_panel).size()


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
	if w.terrain.is_water_at(w.bird.position.x) or w.bird.position.x < bay.water_x1:
		return "respawn not past the bay x=%f" % w.bird.position.x
	_frames(g, 2.0)
	return "" if deaths.size() == 1 else "died again right after continue: %s" % [deaths]
