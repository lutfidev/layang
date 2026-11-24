extends RefCounted
## Adventure levels: level data, terrain/bird/world following a level, stars, unlocks, level screens, map.

var runner: Node
const DT := 1.0 / 120.0


func _level_world(lv: Dictionary, hazards: bool = true) -> World:
	var w := World.new()
	w.level = lv
	w.hazards = hazards
	w.input_enabled = false
	runner.add_child(w)
	return w


func _free(w: World) -> void:
	runner.remove_child(w)
	w.free()


## Signature hazards on island 0 for the level's biome.
func _hazards_on_first(w: World) -> int:
	var t := w.terrain
	var list: Array = []
	match Biomes.get_biome(t.start_island).id:
		"sawah": list = t.kites
		"pantai": list = t.bays
		"hutan": list = t.canopies
	return list.filter(func(it: Dictionary) -> bool: return int(it.island) == 0).size()


## Number of hills on island 0 = valley keys strictly between the entry keys and the launch ramp
## (bays add 4 keys for one hill, canopies/plain hills add 2).
func _hills_on_first(w: World) -> int:
	var t := w.terrain
	var n := 0
	var first_bay := 0
	for i in t.keys_x.size():
		if t.keys_island[i] != 0:
			break
		n += 1
	for b in t.bays:
		if int(b.island) == 0:
			first_bay += 1
	# island 0 keys: 3 entry + hills (2 keys each, bays 4) + ramp + gate + sea floor
	return (n - 3 - 3 - first_bay * 4) / 2 + first_bay


# ---------------------------------------------------------------- data + world (Task 1)

func test_eighteen_levels() -> String:
	var all := Levels.all()
	if all.size() != 18:
		return "size %d" % all.size()
	var ids := {}
	for i in all.size():
		var lv: Dictionary = all[i]
		var biome := Biomes.get_biome(i / 3)
		if int(lv.island) != i / 3 or int(lv.tier) != i % 3:
			return "level %d: island %d tier %d" % [i, int(lv.island), int(lv.tier)]
		if lv.id != "%s-%d" % [biome.id, i % 3 + 1]:
			return "level %d: id %s" % [i, lv.id]
		var want: String = String(biome.id).capitalize() + " " + Levels.TIER_NAMES[i % 3]
		if lv.name != want:
			return "level %d: name %s, want %s" % [i, lv.name, want]
		ids[lv.id] = true
		if Levels.index_of(lv.id) != i or Levels.get_level(lv.id) != lv:
			return "lookup broken for %s" % lv.id
	return "" if ids.size() == 18 else "ids not unique"


func test_level_hazard_counts() -> String:
	for lv in Levels.all():
		if not Levels.is_ready(lv):
			continue
		var w := _level_world(lv)
		var tier: Dictionary = Levels.TIERS[int(lv.tier)]
		var n := _hazards_on_first(w)
		var hills := _hills_on_first(w)
		var island := w.terrain.start_island
		_free(w)
		if island != int(lv.island):
			return "%s: start island %d" % [lv.id, island]
		if n != int(tier.hazards):
			return "%s: %d hazards, want %d" % [lv.id, n, int(tier.hazards)]
		if hills != int(tier.hills):
			return "%s: %d hills, want %d" % [lv.id, hills, int(tier.hills)]
	return ""


func test_endless_unchanged() -> String:
	# recorded on main before levels existed: island count of keys, last key x, kites, bays, canopies
	var want := ["0:56:30938.545:2:3:0", "1:56:32680.744:0:3:2", "2:50:31895.193:0:0:2"]
	for first in [0, 1, 2]:
		var w := World.new()
		w.run_seed = 4242
		w.start_island = first
		runner.add_child(w)
		var t := w.terrain
		var got := "%d:%d:%.3f:%d:%d:%d" % [first, t.keys_x.size(), t.keys_x[t.keys_x.size() - 1], t.kites.size(), t.bays.size(), t.canopies.size()]
		var speed := w.bird.speed_scale
		_free(w)
		if got != want[first]:
			return "start %d: %s, want %s" % [first, got, want[first]]
		if speed != 1.0:
			return "endless speed_scale %f" % speed
	return ""


func test_badai_speed_and_storm() -> String:
	var w := _level_world(Levels.get_level("sawah-3"))
	var s := w.bird.speed_scale
	var amb: String = w.current_biome().ambient
	_free(w)
	if absf(s - 1.12) > 0.001:
		return "speed_scale %f" % s
	if amb != "rain":
		return "ambient %s" % amb
	var p := _level_world(Levels.get_level("sawah-1"))
	var amb2: String = p.current_biome().ambient
	var s2 := p.bird.speed_scale
	_free(p)
	return "" if amb2 == "seeds" and s2 == 1.0 else "pagi: ambient %s speed %f" % [amb2, s2]


# ---------------------------------------------------------------- stars + unlocks (Task 2)

func _with_stars(stars: Dictionary, f: Callable) -> String:
	var keep: Dictionary = Game.level_stars.duplicate()
	Game.level_stars = stars.duplicate()
	var r: String = f.call()
	Game.level_stars = keep
	return r


func test_unlock_rules() -> String:
	return _with_stars({}, func() -> String:
		if not Game.is_unlocked("sawah-1"):
			return "sawah-1 locked on a fresh save"
		if Game.is_unlocked("sawah-2"):
			return "sawah-2 open without stars"
		Game.level_stars = {"sawah-1": 1}
		if not Game.is_unlocked("sawah-2") or Game.is_unlocked("sawah-3"):
			return "after sawah-1: sawah-2 %s sawah-3 %s" % [Game.is_unlocked("sawah-2"), Game.is_unlocked("sawah-3")]
		Game.level_stars = {"sawah-1": 3, "sawah-2": 1, "sawah-3": 2, "pantai-1": 1, "pantai-2": 1, "pantai-3": 1, "hutan-1": 1, "hutan-2": 1, "hutan-3": 1}
		if not Game.is_unlocked("hutan-3"):
			return "hutan-3 locked"
		if Game.is_unlocked("gunung-1"):
			return "gunung-1 open but gunung is not ready"
		if Game.total_stars() != 12:
			return "total_stars %d" % Game.total_stars()
		return "" if Game.last_unlocked_index() == 8 else "last_unlocked_index %d" % Game.last_unlocked_index())


func test_record_level_new_stars_only() -> String:
	return _with_stars({}, func() -> String:
		var a := Game.record_level("sawah-1", 2)
		var b := Game.record_level("sawah-1", 2)
		var c := Game.record_level("sawah-1", 3)
		var d := Game.record_level("sawah-1", 1)
		if [a, b, c, d] != [2, 0, 1, 0]:
			return "new stars %s" % [[a, b, c, d]]
		return "" if int(Game.level_stars["sawah-1"]) == 3 else "kept %d" % int(Game.level_stars["sawah-1"]))


func test_old_save_loads() -> String:
	var keep := Game.save_data()
	var old := keep.duplicate()
	old.erase("level_stars")
	Game.level_stars = {"x": 1}
	Game.apply_save(old)
	var got: Dictionary = Game.level_stars.duplicate()
	Game.apply_save(keep)
	return "" if got.is_empty() else "level_stars %s" % got


# ---------------------------------------------------------------- level mode in game.gd (Task 3)

func _level_game(id: String) -> Node:
	Game.current_level = id
	var g: Node = load("res://scenes/game.tscn").instantiate()
	runner.add_child(g)
	Game.current_level = ""
	g._start()
	return g


func _has_text(n: Node, text: String) -> bool:
	if (n is Label and (n as Label).text == text) or (n is Button and (n as Button).text == text):
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


func _button_texts(n: Node) -> Array:
	var out: Array = []
	for b in _buttons(n):
		out.append((b as Button).text)
	return out


func _frames(g: Node, seconds: float) -> void:
	for i in int(seconds / DT):
		g._physics_process(DT)
		g.world._physics_process(DT)


func test_level_finishes_at_gate() -> String:
	var keep: Dictionary = Game.level_stars.duplicate()
	var g := _level_game("sawah-1")
	var w: World = g.world
	w.autoplay = true
	var t := 0.0
	while t < 120.0 and g.state == "play":
		g._physics_process(DT)
		w._physics_process(DT)
		t += DT
	var r := ""
	if g.state != "done":
		r = "state %s at x=%.0f (gate %.0f)" % [g.state, w.bird.position.x, w.terrain.island_finish[0]]
	elif w.bird.position.x < w.terrain.island_finish[0]:
		r = "done before the gate"
	elif not _has_text(g.result_panel, "Level selesai!"):
		r = "no level done title"
	Game.level_stars = keep
	return r


func test_level_stars_rules() -> String:
	var g := _level_game("sawah-1")
	g.level_coins_total = 10
	var cases := [[5, false, 2], [6, false, 3], [6, true, 2], [0, true, 1], [10, false, 3]]
	for c in cases:
		g.level_coins = c[0]
		g.continued = c[1]
		if g.level_stars_earned() != c[2]:
			return "coins %d continued %s: %d stars, want %d" % [c[0], c[1], g.level_stars_earned(), c[2]]
	return ""


func test_star_bonus_once() -> String:
	var keep: Dictionary = Game.level_stars.duplicate()
	var coins0 := Game.coins
	Game.level_stars = {}
	var gains: Array = []
	for i in 2:
		var g := _level_game("sawah-1")
		g.level_coins_total = 10
		g.level_coins = 0
		var before := Game.coins
		g._finish_level()
		gains.append(Game.coins - before)
	Game.level_stars = keep
	Game.coins = coins0
	return "" if gains == [2 * 20, 0] else "star bonus gains %s" % [gains]


func test_level_lose_buttons() -> String:
	var g := _level_game("sawah-1")
	g.world.bird_died.emit("laut")
	var texts := _button_texts(g.result_panel)
	texts.sort()
	return "" if texts == ["Lanjut (tonton iklan)", "Peta", "Ulangi"] else "buttons %s" % [texts]


func test_level_done_buttons() -> String:
	var keep: Dictionary = Game.level_stars.duplicate()
	var g := _level_game("sawah-1")
	g._finish_level()
	var texts := _button_texts(g.result_panel)
	texts.sort()
	var r := ""
	if texts != ["Lanjut", "Peta", "Ulangi"]:
		r = "buttons %s" % [texts]
	else:
		var h := _level_game("hutan-3")
		h._finish_level()
		for b in _buttons(h.result_panel):
			if (b as Button).text == "Lanjut" and not (b as Button).disabled:
				r = "hutan-3: Lanjut enabled but gunung is not ready"
	Game.level_stars = keep
	return r


func test_safe_after_gate() -> String:
	var g := _level_game("sawah-1")
	var w: World = g.world
	var deaths: Array = []
	w.bird_died.connect(func(c: String): deaths.append(c))
	w.finished = true
	var x := w.terrain.island_finish[0]
	while not w.terrain.is_sea_at(x):
		x += 10.0
	w.bird.position = Vector2(x + 50.0, Terrain.WATER_Y + 10.0)
	w.bird.on_ground = false
	_frames(g, 1.0)
	return "" if deaths.is_empty() else "died after the gate: %s" % [deaths]


func test_level_no_record() -> String:
	var keep: Dictionary = Game.level_stars.duplicate()
	var best := Game.best_score
	var runs := Game.total_runs
	var g := _level_game("sawah-1")
	g.distance = 999999
	g._finish_level()
	var h := _level_game("sawah-1")
	h.distance = 999999
	h.world.bird_died.emit("laut")
	Game.level_stars = keep
	if Game.best_score != best or Game.total_runs != runs:
		return "level touched endless records: best %d -> %d, runs %d -> %d" % [best, Game.best_score, runs, Game.total_runs]
	return ""


func test_hud_level_coins() -> String:
	var g := _level_game("sawah-1")
	g._process(0.0)
	var want := "0/%d" % g.level_coins_total
	if g.level_coins_total < 10:
		return "only %d level coins" % g.level_coins_total
	var got: String = (g.coin_pill.get_node("H/Label") as Label).text
	return "" if got == want else "coin label %s, want %s" % [got, want]


# ---------------------------------------------------------------- map + menu (Task 4)

func _scene(path: String) -> Node:
	var n: Node = load(path).instantiate()
	runner.add_child(n)
	return n


func _free_node(n: Node) -> void:
	runner.remove_child(n)
	n.free()


func _count_text(n: Node, text: String) -> int:
	var c := 1 if (n is Label and (n as Label).text == text) else 0
	for ch in n.get_children():
		c += _count_text(ch, text)
	return c


func test_map_buttons() -> String:
	var keep: Dictionary = Game.level_stars.duplicate()
	Game.level_stars = {"sawah-1": 2}
	var m := _scene("res://scenes/level_map.tscn")
	var r := ""
	var btns: Array = m.level_buttons
	if btns.size() != 18:
		r = "%d level buttons" % btns.size()
	else:
		for i in 18:
			var b: Button = btns[i]
			var id: String = Levels.all()[i].id
			if b.text != str(i + 1):
				r = "button %d text %s" % [i, b.text]
				break
			if b.disabled == Game.is_unlocked(id):
				r = "button %d (%s) disabled=%s" % [i, id, b.disabled]
				break
		if r == "" and m.scroll_target_index() != 1:
			r = "scroll target %d" % m.scroll_target_index()
		if r == "" and not _has_text(m, "Bintang 2/54"):
			r = "no star total"
	_free_node(m)
	Game.level_stars = keep
	return r


func test_map_coming_soon() -> String:
	var m := _scene("res://scenes/level_map.tscn")
	var n := _count_text(m, "Segera hadir")
	_free_node(m)
	return "" if n == 3 else "%d 'Segera hadir' labels" % n


func test_menu_two_modes() -> String:
	var m := _scene("res://scenes/main_menu.tscn")
	var r := ""
	if not _has_text(m, "Petualangan") or not _has_text(m, "Tanpa Batas"):
		r = "missing mode buttons"
	elif _has_text(m, "MAIN"):
		r = "old MAIN button still there"
	_free_node(m)
	return r


# ---------------------------------------------------------------- every ready level is completable (Task 5)

func test_ready_levels_completable() -> String:
	var keep: Dictionary = Game.level_stars.duplicate()
	var coins0 := Game.coins
	var r := ""
	for lv in Levels.all():
		if not Levels.is_ready(lv):
			continue
		var g := _level_game(String(lv.id))
		var w: World = g.world
		w.autoplay = true
		var t := 0.0
		while t < 150.0 and g.state == "play":
			g._physics_process(DT)
			w._physics_process(DT)
			t += DT
		if g.state != "done":
			r = "%s: state %s (%s) at x=%.0f of %.0f" % [lv.id, g.state, g.end_cause, w.bird.position.x, w.terrain.island_finish[0]]
		runner.remove_child(g)
		g.free()
		if r != "":
			break
	Game.level_stars = keep
	Game.coins = coins0
	return r


func test_coin_items_sorted() -> String:
	# CoinField.check stops at the first coin ahead of the bird, so items must stay sorted by x
	for lv in [Levels.get_level("sawah-3"), Levels.get_level("pantai-3"), Levels.get_level("hutan-3")]:
		var w := _level_world(lv)
		w.terrain.update_view(0.0, 60000.0)
		var items: Array = w.coins.items
		var bad := -1
		for i in range(1, items.size()):
			if (items[i][0] as Vector2).x < (items[i - 1][0] as Vector2).x:
				bad = i
				break
		_free(w)
		if bad >= 0:
			return "%s: coin %d out of order" % [lv.id, bad]
	return ""


func test_magnet_past_gate_not_counted() -> String:
	# a fever magnet drags coins that lie past the gate back to the bird: they must not count for the level
	var g := _level_game("sawah-1")
	var w: World = g.world
	var fin := w.terrain.island_finish[0]
	w.coins.add_item(Vector2(fin + 150.0, -300.0), CoinField.COIN)
	w.coins.view_left = fin - 2000.0
	var before: int = g.level_coins
	for i in 60:
		w.coins.check(Vector2(fin - 60.0, -300.0), 48.0, 230.0, DT)
	return "" if g.level_coins == before else "past-gate coin counted: %d -> %d" % [before, g.level_coins]


func test_map_scroll_passes_touch() -> String:
	# drag-to-scroll on phones: nothing inside the map's ScrollContainer may swallow the drag
	var m := _scene("res://scenes/level_map.tscn")
	var bad := ""
	var stack: Array = [m._scroll.get_child(0)]
	while not stack.is_empty() and bad == "":
		var n: Node = stack.pop_back()
		if n is Control and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			bad = "%s (%s) stops mouse/touch" % [n.name, n.get_class()]
		stack.append_array(n.get_children())
	_free_node(m)
	return bad


# ---------------------------------------------------------------- level end edge cases (perbaikan temuan, Task 1)

func test_death_at_gate_finishes_level() -> String:
	# a hazard hitting the bird on the very frame it reaches the gate must still finish the level
	var keep := Game.save_data()
	var g := _level_game("sawah-1")
	var w: World = g.world
	w.bird.position.x = w.terrain.island_finish[0] + 2.0
	w._die("layangan")
	var x0 := w.bird.position.x
	for i in 30:
		w._physics_process(DT)
	var r := ""
	if g.state != "done":
		r = "state %s, want done" % g.state
	elif w.bird.position.x <= x0:
		r = "bird frozen at the gate after the hit"
	elif not _has_text(g.result_panel, "Level selesai!"):
		r = "no level done title"
	_free_node(g)
	Game.apply_save(keep)
	return r


func test_coins_after_done_ignored() -> String:
	var keep := Game.save_data()
	var g := _level_game("sawah-1")
	var w: World = g.world
	g._finish_level()
	Game.missions = [{"id": "coins_150", "progress": 0}]
	var coins0: int = g.coins_run
	w.item_collected.emit(0, w.bird.position)
	var p := int(Game.missions[0].progress)
	var r := ""
	if g.coins_run != coins0:
		r = "coins_run %d -> %d after the level was done" % [coins0, g.coins_run]
	elif p != 0:
		r = "coin mission moved after the level was done: %d" % p
	_free_node(g)
	Game.apply_save(keep)
	return r


func test_monster_reset_when_finished() -> String:
	var w := _level_world(Levels.get_level("sawah-1"))
	w.monster.arm(w.bird.position.x + 400.0, 0.1)
	w.monster.update(0.2, Vector2(-99999.0, -99999.0))   # past the warning: jumping
	var jumping := w.monster.state == "jump"
	w.finished = true
	w.running = true
	for i in 30:
		w._physics_process(DT)
	var st := w.monster.state
	_free(w)
	if not jumping:
		return "setup: monster not jumping"
	return "" if st == "idle" else "monster stuck in %s after the level finished" % st


func test_menu_clears_current_level() -> String:
	Game.current_level = "sawah-1"
	var m := _scene("res://scenes/main_menu.tscn")
	var lv := Game.current_level
	_free_node(m)
	Game.current_level = ""
	return "" if lv == "" else "current_level still %s on the menu" % lv
