extends RefCounted
## Missions: templates, progress from game events, rewards once at run end, panels on menu/pause/results.

var runner: Node
const DT := 1.0 / 120.0


func _kinds(list: Array) -> Array:
	var out: Array = []
	for a in list:
		out.append(Missions.get_mission(a.id).kind)
	return out


func _fresh() -> Dictionary:
	var keep := Game.save_data()
	Game.missions = []
	Game.mission_seq = 0
	Game.ensure_missions()
	return keep


func _distinct(list: Array) -> bool:
	var k := _kinds(list)
	for i in k.size():
		if k.find(k[i]) != i:
			return false
	return true


## Replaces the active missions with the given template ids (progress 0).
func _force(ids: Array) -> void:
	Game.missions = []
	for id in ids:
		Game.missions.append({"id": id, "progress": 0})


# ---------------------------------------------------------------- data + Game state (Task 1)

func test_mission_starts_with_three_distinct() -> String:
	var keep := _fresh()
	var r := ""
	if Game.missions.size() != 3:
		r = "missions %s" % [Game.missions]
	elif not _distinct(Game.missions):
		r = "duplicate kinds %s" % [_kinds(Game.missions)]
	else:
		for a in Game.missions:
			if not Missions.available(Missions.get_mission(a.id)):
				r = "unavailable %s" % a.id
		if _kinds(Game.missions) != ["skim", "coins", "pass"]:
			r = "first missions %s, want skim/coins/pass" % [_kinds(Game.missions)]
	Game.apply_save(keep)
	return r


func test_mission_templates_valid() -> String:
	var ids := {}
	for m in Missions.all():
		if ids.has(m.id):
			return "duplicate id %s" % m.id
		ids[m.id] = true
		if int(m.target) <= 0 or int(m.reward) <= 0:
			return "%s target/reward" % m.id
		if not String(m.text).contains("%d"):
			return "%s text has no %%d" % m.id
		if Missions.label(m) != String(m.text) % int(m.target):
			return "%s label" % m.id
	for k in ["skim", "coins", "pass", "pass_ombak", "pass_layangan", "pass_hutan", "stars", "endless_island", "level_clean"]:
		if Missions.all().filter(func(m: Dictionary) -> bool: return m.kind == k).is_empty():
			return "no template for %s" % k
	return ""


func test_mission_event_progress() -> String:
	var keep := _fresh()
	Game.mission_event("skim", 3)
	var r := ""
	for a in Game.missions:
		var want := 3 if Missions.get_mission(a.id).kind == "skim" else 0
		if int(a.progress) != want:
			r = "%s progress %d, want %d" % [a.id, a.progress, want]
	Game.apply_save(keep)
	return r


func test_mission_endless_island_is_max() -> String:
	var keep := Game.save_data()
	_force(["endless_island_3"])
	Game.mission_max("endless_island", 2)
	Game.mission_max("endless_island", 1)
	var p := int(Game.missions[0].progress)
	Game.apply_save(keep)
	return "" if p == 2 else "progress %d, want 2" % p


func test_mission_settle_pays_once() -> String:
	var keep := _fresh()
	var coins0 := Game.coins
	var skim_id: String = Game.missions[0].id
	var m := Missions.get_mission(skim_id)
	Game.mission_event("skim", int(m.target))
	var done := Game.settle_missions()
	var gain := Game.coins - coins0
	var again := Game.settle_missions()
	var r := ""
	if done.size() != 1 or done[0].id != skim_id or int(done[0].reward) != int(m.reward):
		r = "settle %s" % [done]
	elif gain != int(m.reward):
		r = "coins +%d, want +%d" % [gain, m.reward]
	elif not again.is_empty():
		r = "second settle %s" % [again]
	elif Game.missions.size() != 3 or Game.missions.any(func(a: Dictionary) -> bool: return a.id == skim_id):
		r = "not replaced %s" % [Game.missions]
	Game.apply_save(keep)
	return r


func test_mission_replacement_distinct_and_available() -> String:
	var keep := _fresh()
	var r := ""
	for n in 30:
		var a: Dictionary = Game.missions[n % 3]
		var m := Missions.get_mission(a.id)
		if m.kind == "endless_island":
			Game.mission_max(m.kind, int(m.target))
		else:
			Game.mission_event(m.kind, int(m.target))
		if Game.settle_missions().size() != 1:
			r = "round %d: settle did not pay %s" % [n, a.id]
			break
		if Game.missions.size() != 3 or not _distinct(Game.missions):
			r = "round %d: %s" % [n, [_kinds(Game.missions)]]
			break
		for b in Game.missions:
			if not Missions.available(Missions.get_mission(b.id)):
				r = "round %d: unavailable %s" % [n, b.id]
	Game.apply_save(keep)
	return r


func test_mission_locked_island_never_offered() -> String:
	for m in Missions.all():
		var isl: String = m.get("island", "")
		if isl != "" and not Levels.READY_ISLANDS.has(isl) and Missions.available(m):
			return "%s available for locked %s" % [m.id, isl]
	var fake := {"id": "x", "kind": "pass_lava", "target": 3, "reward": 75, "text": "Lolos %d lava", "island": "gunung"}
	return "" if not Missions.available(fake) else "gunung mission available"


func test_mission_old_save() -> String:
	var keep := Game.save_data()
	var old := keep.duplicate(true)
	old.erase("missions")
	old.erase("mission_seq")
	Game.apply_save(old)
	var r := ""
	if Game.missions.size() != 3 or not _distinct(Game.missions):
		r = "old save missions %s" % [Game.missions]
	var saved := Game.save_data()
	Game.apply_save(saved)
	if r == "" and Game.save_data().missions != saved.missions:
		r = "missions did not round-trip"
	Game.apply_save({"missions": [{"id": "nope", "progress": 4}, "junk"]})
	if r == "" and (Game.missions.size() != 3 or Game.missions.any(func(a: Dictionary) -> bool: return a.id == "nope")):
		r = "bad save entries kept %s" % [Game.missions]
	Game.apply_save(keep)
	return r


# ---------------------------------------------------------------- game events (Task 2)

func _game(level_id: String = "") -> Node:
	Game.current_level = level_id
	var g: Node = load("res://scenes/game.tscn").instantiate()
	runner.add_child(g)
	Game.current_level = ""
	g._start()
	return g


func _progress(id: String) -> int:
	for a in Game.missions:
		if a.id == id:
			return int(a.progress)
	return -1


func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for c in n.get_children():
		var b := _find_button(c, text)
		if b:
			return b
	return null


func test_mission_kite_pass_signal() -> String:
	var t := Terrain.new()
	t.kites = [{"x": 1000.0, "peak_y": 0.0, "island": 0, "color": 0}, {"x": 2000.0, "peak_y": 0.0, "island": 0, "color": 1}]
	var k := Kite.new()
	k.terrain = t
	runner.add_child(k)
	var n := [0]
	k.passed.connect(func(): n[0] += 1)
	var x := 0.0
	var hit := false
	while x < 2600.0:
		hit = k.update(DT, Vector2(x, -60.0), x) or hit
		x += 6.0
	var r := ""
	if hit:
		r = "bird under the tails was hit"
	elif n[0] != 2:
		r = "passed %d times, want 2" % n[0]
	else:
		# respawn past a kite after "Lanjut" is not a pass
		var k2 := Kite.new()
		k2.terrain = t
		runner.add_child(k2)
		k2.passed.connect(func(): n[0] += 1)
		k2.update(DT, Vector2(900.0, -60.0), 900.0)
		k2.reset_current()
		k2.update(DT, Vector2(1300.0, -60.0), 1300.0)
		if n[0] != 2:
			r = "respawn past a kite counted as a pass"
	t.free()
	return r


func test_mission_kite_over_not_counted() -> String:
	# flying high over a kite is safe but is not "passing" it: only going under the body counts
	var t := Terrain.new()
	t.kites = [{"x": 1000.0, "peak_y": 0.0, "island": 0, "color": 0}, {"x": 2000.0, "peak_y": 0.0, "island": 0, "color": 1}]
	var k := Kite.new()
	k.terrain = t
	runner.add_child(k)
	var n := [0]
	k.passed.connect(func(): n[0] += 1)
	var x := 0.0
	var hit := false
	while x < 2600.0:
		hit = k.update(DT, Vector2(x, -600.0), x) or hit
		x += 6.0
	# FEVER-sized steps under the tails still count
	var k2 := Kite.new()
	k2.terrain = t
	runner.add_child(k2)
	var n2 := [0]
	k2.passed.connect(func(): n2[0] += 1)
	x = 0.0
	while x < 2600.0:
		k2.update(DT, Vector2(x, -60.0), x)
		x += 150.0
	t.free()
	if hit:
		return "bird high over the kites was hit"
	if n[0] != 0:
		return "flying over counted %d passes, want 0" % n[0]
	return "" if n2[0] == 2 else "big steps under the tails: %d passes, want 2" % n2[0]


func test_mission_world_forwards_kite_pass() -> String:
	var w := World.new()
	w.input_enabled = false
	runner.add_child(w)
	var got: Array = []
	w.hazard_passed.connect(func(c: String): got.append(c))
	w.kite.passed.emit()
	return "" if got == ["layangan"] else "hazard_passed %s" % [got]


func test_mission_events_reach_missions() -> String:
	var keep := Game.save_data()
	var g := _game()
	_force(["skim_10", "coins_150", "pass_ombak_3"])
	var w: World = g.world
	w.bird_skimmed.emit(0.5)
	w.item_collected.emit(0, w.bird.position)
	w.item_collected.emit(0, w.bird.position)
	w.wave_passed.emit()
	var got := [_progress("skim_10"), _progress("coins_150"), _progress("pass_ombak_3")]
	_force(["pass_5", "pass_hutan_2", "pass_layangan_3"])
	w.hazard_passed.emit("hutan")
	w.hazard_passed.emit("layangan")
	var got2 := [_progress("pass_5"), _progress("pass_hutan_2"), _progress("pass_layangan_3")]
	Game.apply_save(keep)
	if got != [1, 2, 1]:
		return "skim/coins/ombak %s, want [1, 2, 1]" % [got]
	return "" if got2 == [2, 1, 1] else "pass/hutan/layangan %s, want [2, 1, 1]" % [got2]


func test_mission_level_events() -> String:
	var keep := Game.save_data()
	Game.level_stars = {}
	var g := _game("sawah-1")
	_force(["stars_3", "level_clean_1", "endless_island_3"])
	g.world.island_reached.emit(2, Biomes.get_biome(2))
	var isl := _progress("endless_island_3")
	g.level_coins_total = 10
	g.level_coins = 10
	g._finish_level()
	var paid: Array = g.missions_done.map(func(d: Dictionary) -> String: return d.id)
	Game.apply_save(keep)
	if isl != 0:
		return "endless_island moved in a level: %d" % isl
	paid.sort()
	return "" if paid == ["level_clean_1", "stars_3"] else "paid %s" % [paid]


func test_mission_endless_island_in_endless() -> String:
	var keep := Game.save_data()
	var g := _game()
	_force(["endless_island_3"])
	g.world.island_reached.emit(2, Biomes.get_biome(2))
	var p := _progress("endless_island_3")
	Game.apply_save(keep)
	return "" if p == 3 else "progress %d, want 3" % p


## Presses a pause-panel button with a fake scene change; returns the paths it was asked to go to.
func _press_pause(g: Node, text: String) -> Array:
	var went: Array = []
	g.goto_scene = func(path: String): went.append(path)
	g._toggle_pause()
	var b := _find_button(g.pause_panel, text)
	if b:
		b.pressed.emit()
	runner.get_tree().paused = false
	return went


func test_mission_pause_menu_settles() -> String:
	var keep := Game.save_data()
	var g := _game()
	_force(["skim_10"])
	Game.missions[0].progress = 10
	var coins0 := Game.coins
	var went := _press_pause(g, "Menu Utama")
	var r := ""
	if went != ["res://scenes/main_menu.tscn"]:
		r = "went %s" % [went]
	elif Game.coins - coins0 != 50:
		r = "coins +%d, want +50" % (Game.coins - coins0)
	elif _progress("skim_10") != -1:
		r = "finished mission not replaced"
	Game.apply_save(keep)
	return r


func test_mission_pause_exit_banks_coins() -> String:
	var keep := Game.save_data()
	var g := _game()
	_force(["skim_10"])
	Game.missions[0].progress = 10
	g.coins_run = 7
	var coins0 := Game.coins
	_press_pause(g, "Menu Utama")
	var gain := Game.coins - coins0
	Game.apply_save(keep)
	return "" if gain == 57 else "coins +%d, want +57 (7 run coins + 50 reward)" % gain


func test_mission_pause_exit_stops_run() -> String:
	var keep := Game.save_data()
	var g := _game()
	_press_pause(g, "Ulang")
	var r := ""
	if g.state != "over":
		r = "state %s, want over" % g.state
	elif g.world.running:
		r = "world still running under the fade"
	Game.apply_save(keep)
	return r


func test_mission_results_keep_first_payout() -> String:
	var keep := Game.save_data()
	var g := _game()
	_force(["skim_10", "coins_150", "pass_5"])
	Game.missions[0].progress = 10
	g._finish("laut")
	g._continue_run()
	g.world.item_collected.emit(0, g.world.bird.position)
	g._finish("laut")
	var r := ""
	if _count_label(g.result_panel, "Selesai! +50") != 1:
		r = "first payout missing from the last results"
	elif _count_label(g.result_panel, Missions.label(Missions.get_mission("coins_150"))) != 1:
		r = "coins mission row missing"
	elif g.missions_done.size() != 1:
		r = "missions_done %s" % [g.missions_done]
	Game.apply_save(keep)
	return r


func test_mission_continue_no_double_count() -> String:
	var keep := Game.save_data()
	var g := _game()
	_force(["coins_150"])
	var w: World = g.world
	for i in 10:
		w.item_collected.emit(0, w.bird.position)
	g._finish("laut")
	g._continue_run()
	for i in 5:
		w.item_collected.emit(0, w.bird.position)
	g._finish("laut")
	var p := _progress("coins_150")
	Game.apply_save(keep)
	return "" if p == 15 else "coins progress %d, want 15" % p


# ---------------------------------------------------------------- panels (Task 3)

func _count_label(n: Node, text: String) -> int:
	var c := 1 if (n is Label and (n as Label).text == text) else 0
	for ch in n.get_children():
		c += _count_label(ch, text)
	return c


func _shows_active(n: Node) -> String:
	if _count_label(n, "Misi") < 1:
		return "no Misi title"
	for a in Game.missions:
		if _count_label(n, Missions.label(Missions.get_mission(a.id))) != 1:
			return "missing row %s" % a.id
	return ""


func test_mission_menu_shows_missions() -> String:
	var keep := _fresh()
	var m: Node = load("res://scenes/main_menu.tscn").instantiate()
	runner.add_child(m)
	var r := _shows_active(m)
	Game.apply_save(keep)
	return r


func test_mission_pause_shows_missions() -> String:
	var keep := _fresh()
	var g := _game()
	g._toggle_pause()
	var r := _shows_active(g.pause_panel)
	runner.get_tree().paused = false
	Game.apply_save(keep)
	return r


func test_mission_results_show_done() -> String:
	var keep := Game.save_data()
	var g := _game()
	_force(["skim_10", "coins_150", "pass_5"])
	Game.missions[0].progress = 10
	g._finish("laut")
	var r := ""
	if _count_label(g.result_panel, "Selesai! +50") != 1:
		r = "no Selesai! +50 row"
	elif _count_label(g.result_panel, Missions.label(Missions.get_mission("coins_150"))) != 1:
		r = "unfinished mission of the run not shown"
	Game.apply_save(keep)
	return r


func test_mission_level_done_shows_missions() -> String:
	var keep := Game.save_data()
	Game.level_stars = {}
	var g := _game("sawah-1")
	_force(["skim_10", "coins_150", "level_clean_1"])
	g._finish_level()
	var r := "" if _count_label(g.result_panel, "Selesai! +75") == 1 else "no Selesai! +75 on the level done screen"
	Game.apply_save(keep)
	return r


func test_mission_progress_saved_at_settle() -> String:
	var keep := _fresh()
	Game.mission_event("skim", 2)   # finishes nothing
	var before := Game.save_count
	Game.settle_missions()
	var n := Game.save_count - before
	Game.apply_save(keep)
	return "" if n >= 1 else "unfinished mission progress was not saved at the end of the run"
