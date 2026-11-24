extends Node2D
## Game scene: rules (endless run, islands, combos, fever), HUD, pause and results.

const SUN_PROGRESS := 0.8      # fixed sun height: the sky no longer counts down
const SIM_MAX := 240.0          # --sim runs end after this many seconds (cause "batas")
const HIGH_FLIGHT := 520.0     # px above ground/water for "TERBANG TINGGI!"
const WAVE_POINTS := 150        # style points for clearing a beach wave
const STAR_BONUS := 20          # coins per newly earned level star
const COIN_STAR_RATIO := 0.6    # level star 2: collect at least this share of the level's coins
const MAIN_MENU := "res://scenes/main_menu.tscn"
const LEVEL_MAP := "res://scenes/level_map.tscn"
const CAUSE_TITLES := {"laut": "Tercebur ke laut!", "monster": "Digigit monster laut!", "ombak": "Terkena ombak", "layangan": "Tersangkut layangan!", "hutan": "Tersangkut di hutan!", "batas": "Simulasi selesai"}
const CAUSE_TIPS := {
	"laut": "Tahan untuk naik sebelum stamina habis di atas laut",
	"monster": "Lihat tandanya di air, lalu naik tinggi menjauh",
	"ombak": "Turun ke bawah gulungan ombak, tahan sedikit supaya tidak tercebur",
	"layangan": "Terbang rendah di bawah ekor, atau tinggi di atasnya",
	"hutan": "Terbang di tengah lorong: jauhi dahan dan semak berduri",
}
## Island hazards (World.hazard_spotted / hazard_passed): first-sighting popup [title, hint, colour]
## and the pass reward [popup, style points].
const HAZARD_POPUPS := {
	"hutan": ["Awas lorong hutan!", "Terbang di tengah, jangan sentuh duri", Color("#b8ff8a")],
}
const HAZARD_PASS := {
	"hutan": ["LOLOS HUTAN!", 150],
}

var world: World
var state := "ready"       # ready → play → over (lost) | done (adventure level finished)
var level: Dictionary = {}  # adventure level (Levels entry); empty = endless run
var level_coins_total := 0  # coin items before the level's gate
var level_coins := 0        # of those, collected this run
var run_time := 0.0
var distance := 0
var style_points := 0
var coins_run := 0
var coins_banked := 0
var skim_streak := 0
var best_skim := 0
var end_cause := ""         # laut | monster | ombak | layangan (batas = sim cap)
var _high_awarded := false
var fever_t := 0.0
var continued := false
var missions_done: Array = []   # every mission paid this run (also before a "Lanjut"): [{id, reward}]
var missions_run: Array = []    # the run's missions, snapshot at its first settle (shown on the results)
var goto_scene: Callable = Game.goto   # scene change used when leaving from the pause panel (tests swap it)
var coin_chain := 0
var coin_chain_t := 0.0
var start_x := 0.0
var hint_t := 0.0

var hud: CanvasLayer
var stamina_bar: StaminaBar
var lbl_score: Label
var coin_pill: PanelContainer
var lbl_island: Label
var lbl_popup: Label
var lbl_sub: Label
var lbl_hint: Label
var lbl_ready: Control
var fever_lbl: Label
var banner: PanelContainer
var pause_panel: Control
var result_panel: Control


func _ready() -> void:
	world = World.new()
	world.start_island = Game.dev_int("island", 0)
	world.run_seed = Game.dev_int("seed", 1)   # 1 = random (see World._ready)
	if Game.current_level != "":
		level = Levels.get_level(Game.current_level)
		world.level = level
	world.running = false
	world.sun_progress = SUN_PROGRESS
	world.autoplay = Game.dev.has("autoplay")
	add_child(world)
	start_x = world.bird.position.x
	if not level.is_empty():
		for it in world.coins.items:
			if (it[0] as Vector2).x < world.terrain.island_finish[0]:
				level_coins_total += 1
	world.island_reached.connect(_on_island)
	world.item_collected.connect(_on_item)
	world.bird_landed.connect(_on_landed)
	world.bird_skimmed.connect(_on_skimmed)
	world.bird_died.connect(_on_died)
	world.wave_passed.connect(_on_wave_passed)
	world.kite.spotted.connect(_on_kite_spotted)
	world.hazard_spotted.connect(_on_hazard_spotted)
	world.hazard_passed.connect(_on_hazard_passed)
	world.bird_splashed.connect(func(): Sfx.play("splash"))
	_build_hud()
	if world.autoplay:
		_start()


# ================================================================ flow

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state == "play":
		_toggle_pause()
		return
	if state == "ready":
		var pressed: bool = (event is InputEventMouseButton and event.pressed) or event.is_action_pressed("fly")
		if pressed:
			_start()


func _start() -> void:
	state = "play"
	world.running = true
	Sfx.play("whoosh")
	var t := create_tween()
	t.tween_property(lbl_ready, "modulate:a", 0.0, 0.3)
	t.tween_callback(lbl_ready.hide)
	if not Game.tutorial_done:
		lbl_hint.show()
		hint_t = 14.0
	if world.current_biome().id == "pantai":
		_popup("Awas ombak raksasa!", "Terbang rendah lewat gulungannya", Color("#7ff0e6"))


func _physics_process(delta: float) -> void:
	if state == "play":
		run_time += delta
		distance = maxi(distance, int((world.bird.position.x - start_x) / 10.0))
		_check_high_flight()
		if Game.dev.has("sim") and run_time >= float(Game.dev.get("sim-max", SIM_MAX)):
			_finish("batas")
			return
		if Game.dev.has("die") and run_time >= 2.0:   # dev: show the lose screen for this cause
			_finish(str(Game.dev["die"]))
			return
		if fever_t > 0.0:
			fever_t -= delta
			if fever_t <= 0.0:
				world.bird.fever = false
				fever_lbl.hide()
		if not level.is_empty() and world.bird.position.x >= world.terrain.island_finish[0]:
			_finish_level()
			return
		coin_chain_t -= delta
		if coin_chain_t <= 0.0:
			coin_chain = 0
		if hint_t > 0.0:
			hint_t -= delta
			if hint_t <= 0.0:
				_hide_hint()


func _process(_delta: float) -> void:
	stamina_bar.value = world.bird.stamina
	stamina_bar.exhausted = world.bird.exhausted
	lbl_score.text = _fmt(score())
	var coin_text := str(coins_run)
	if not level.is_empty():
		coin_text = "%d/%d" % [level_coins, level_coins_total]
	(coin_pill.get_node("H/Label") as Label).text = coin_text
	if fever_lbl.visible:
		fever_lbl.scale = Vector2.ONE * (1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.02))


func score() -> int:
	return distance + style_points


func _finish(cause: String) -> void:
	if state == "over":
		return
	state = "over"
	end_cause = cause
	world.running = false
	var earned := coins_run - coins_banked
	coins_banked = coins_run
	Game.add_coins(earned)
	_settle_missions()
	var record := false
	if level.is_empty():
		record = Game.submit_run(score(), distance, world.current_island + 1)
	lbl_hint.hide()
	if Game.dev.has("autoplay"):
		print("RUN score=%d dist=%d islands=%d coins=%d best_skim=%d cause=%s" % [score(), distance, world.current_island + 1, coins_run, best_skim, cause])
		if Game.dev.has("sim"):
			get_tree().quit()
	_show_results(record)


## Stars for this run: 1 for reaching the gate, 1 for enough coins, 1 for not using "Lanjut".
func level_stars_earned() -> int:
	var need := ceili(COIN_STAR_RATIO * level_coins_total)
	return 1 + (1 if level_coins >= need else 0) + (0 if continued else 1)


## The bird passed the level's gate: bank coins + new-star bonus and show "Level selesai!".
func _finish_level() -> void:
	if state == "done" or state == "over":
		return
	state = "done"
	world.finished = true
	var stars := level_stars_earned()
	var new_stars := Game.record_level(String(level.id), stars)
	var bonus := new_stars * STAR_BONUS
	var earned := coins_run - coins_banked
	coins_banked = coins_run
	Game.add_coins(earned + bonus)
	Game.mission_event("stars", new_stars)
	if not continued:
		Game.mission_event("level_clean")
	_settle_missions()
	lbl_hint.hide()
	if Game.dev.has("autoplay"):
		print("RUN level=%s stars=%d coins=%d/%d run_coins=%d dist=%d cause=selesai" % [level.id, stars, level_coins, level_coins_total, coins_run, distance])
		if Game.dev.has("sim"):
			get_tree().quit()
	_show_level_done(stars, new_stars, earned, bonus)


func _continue_run() -> void:
	continued = true
	result_panel.queue_free()
	result_panel = null
	state = "play"
	var b := world.bird
	b.vel.x = maxf(b.vel.x, 500.0)
	b.vel.y = 0.0
	b.stamina = 1.0
	b.exhausted = false
	b.on_ground = false
	# respawn safely: forward onto the first gentle dry ground past the water (score never drops)
	b.position.x = world.safe_x_after(b.position.x)
	b.position.y = world.terrain.height_at(b.position.x) - 200.0
	world.clear_hazards()
	world.dead = false
	world.running = true
	world.release_input()
	_popup("Terbang lagi!", "", Color("#ffe066"))


# ================================================================ events

func _on_island(k: int, biome: Dictionary) -> void:
	if not level.is_empty():
		return   # a level ends at its gate: no island bonus, no banner
	Game.mission_max("endless_island", k + 1)
	style_points += 500
	coins_run += 20
	Sfx.play("island")
	Ambient.burst(world, world.bird.center(), Color("#ffe066"), 40, 700.0)
	_show_banner(k, biome)
	if biome.id == "pantai":
		_popup("Awas ombak raksasa!", "Terbang rendah lewat gulungannya", Color("#7ff0e6"))


func _on_item(_kind: int, pos: Vector2) -> void:
	if state != "play":
		return   # e.g. a fever magnet dragging coins in after "Level selesai!": counts nowhere
	if not level.is_empty() and pos.x < world.terrain.island_finish[0]:
		level_coins += 1
	var gained := 2 if world.bird.fever else 1
	coins_run += gained
	Game.mission_event("coins", gained)
	coin_chain += 1
	coin_chain_t = 0.6
	Sfx.play("coin", 1.0 + 0.045 * mini(coin_chain, 14))


func _on_landed(bonk: bool) -> void:
	if state == "over":
		return
	skim_streak = 0
	_high_awarded = false
	if bonk:
		Sfx.play("bonk")
		_popup("Aduh!", "Nabrak tanjakan", Color("#ff8a8a"))


func _on_skimmed(_duration: float) -> void:
	if state != "play":
		return
	skim_streak += 1
	best_skim = maxi(best_skim, skim_streak)
	Game.mission_event("skim")
	style_points += 25 * skim_streak
	Sfx.play("perfect", 1.0 + 0.06 * mini(skim_streak, 8))
	var b := world.bird
	if skim_streak >= 3 and fever_t <= 0.0:
		fever_t = 6.0
		b.fever = true
		fever_lbl.show()
		_popup("FEVER!", "Koin ×2 • magnet aktif", Color("#ff9d3c"))
	elif fever_t > 0.0:
		fever_t = minf(fever_t + 1.5, 8.0)
		_popup("NYEREMPET ×%d" % skim_streak, "", Color("#9dff8a"))
	else:
		_popup("NYEREMPET!" if skim_streak == 1 else "NYEREMPET ×%d" % skim_streak, "", Color("#9dff8a"))
	if not Game.tutorial_done and skim_streak >= 2:
		Game.tutorial_done = true
		Game.save_game()
		_hide_hint()


func _on_wave_passed() -> void:
	if state != "play":
		return
	Game.mission_event("pass")
	Game.mission_event("pass_ombak")
	style_points += WAVE_POINTS
	Sfx.play("perfect", 1.2)
	_popup("LOLOS OMBAK!", "+%d" % WAVE_POINTS, Color("#7ff0e6"))


func _on_hazard_spotted(cause: String) -> void:
	if state == "play" and HAZARD_POPUPS.has(cause):
		var p: Array = HAZARD_POPUPS[cause]
		_popup(p[0], p[1], p[2])


func _on_hazard_passed(cause: String) -> void:
	if state != "play":
		return
	Game.mission_event("pass")
	Game.mission_event("pass_" + cause)
	if not HAZARD_PASS.has(cause):
		return   # kites count for missions but have no popup
	var p: Array = HAZARD_PASS[cause]
	style_points += int(p[1])
	Sfx.play("perfect", 1.2)
	_popup(p[0], "+%d" % int(p[1]), Color("#7ff0e6"))


func _on_kite_spotted() -> void:
	if state == "play":
		_popup("Awas layangan!", "Terbang rendah di bawah ekornya", Color("#ffd36b"))


func _on_died(cause: String) -> void:
	if state != "play":
		return
	if not level.is_empty() and world.bird.position.x >= world.terrain.island_finish[0]:
		world.dead = false   # hit on the frame it reached the gate: the level still counts and the bird glides on
		_finish_level()
		return
	_finish(cause)


## "TERBANG TINGGI!" once per flight when the bird climbs high above the ground / water.
func _check_high_flight() -> void:
	var b := world.bird
	if b.on_ground or _high_awarded:
		return
	var ground := minf(world.terrain.height_at(b.position.x), Terrain.WATER_Y)
	if ground - b.position.y > HIGH_FLIGHT:
		_high_awarded = true
		style_points += 100
		_popup("TERBANG TINGGI!", "+100", Color("#8fd8ff"))


# ================================================================ HUD

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	var root := UIKit.full_rect(Control.new())
	hud.add_child(root)

	# --- island name + stamina (top-left)
	lbl_island = UIKit.label("", 22, Color(1, 1, 1, 0.92), false, 6)
	lbl_island.position = Vector2(28, 26)
	root.add_child(lbl_island)
	_set_island_label(0, world.current_biome())
	stamina_bar = StaminaBar.new()
	stamina_bar.position = Vector2(28, 62)
	stamina_bar.size = Vector2(200, 14)
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stamina_bar)

	# --- score (top-center)
	lbl_score = UIKit.label("0", 46, Color.WHITE, true, 10)
	lbl_score.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_score.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl_score.position.y = 16
	root.add_child(lbl_score)

	# --- coins + pause (top-right)
	var tr := HBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.position = Vector2(-28, 22)
	tr.alignment = BoxContainer.ALIGNMENT_END
	tr.add_theme_constant_override("separation", 12)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	coin_pill = _coin_pill("0")
	tr.add_child(coin_pill)
	var pause_btn := UIKit.button("II", UIKit.CREAM, Color("#d8c7a8"), 26)
	pause_btn.custom_minimum_size = Vector2(64, 56)
	pause_btn.pressed.connect(_toggle_pause)
	tr.add_child(pause_btn)

	# --- popups
	lbl_popup = UIKit.label("", 64, Color.WHITE, true, 14)
	lbl_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_popup.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl_popup.position.y = 150
	lbl_popup.modulate.a = 0.0
	root.add_child(lbl_popup)
	lbl_sub = UIKit.label("", 26, Color.WHITE, false, 8)
	lbl_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl_sub.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl_sub.position.y = 232
	lbl_sub.modulate.a = 0.0
	root.add_child(lbl_sub)

	fever_lbl = UIKit.label("FEVER", 30, Color("#ffcf5a"), true, 10)
	fever_lbl.position = Vector2(28, 86)
	fever_lbl.hide()
	root.add_child(fever_lbl)

	# --- tutorial hint (bottom)
	lbl_hint = UIKit.label("TAHAN untuk naik  •  LEPAS untuk turun  •  Awas monster laut!", 26, Color.WHITE, true, 10)
	lbl_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	lbl_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	lbl_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hint.position.y = -40
	lbl_hint.hide()
	root.add_child(lbl_hint)

	# --- ready overlay
	var ready_box := VBoxContainer.new()
	ready_box.set_anchors_preset(Control.PRESET_CENTER)
	ready_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ready_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	ready_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ready_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := world.current_biome()
	var l1 := UIKit.label((String(level.name) if not level.is_empty() else String(b.name)).to_upper(), 64, Color.WHITE, true, 14)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_box.add_child(l1)
	var l2 := UIKit.label("Tahan untuk naik", 32, Color("#fff3c4"), false, 10)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_box.add_child(l2)
	root.add_child(ready_box)
	lbl_ready = ready_box
	var pulse := l2.create_tween().set_loops()
	pulse.tween_property(l2, "modulate:a", 0.45, 0.7)
	pulse.tween_property(l2, "modulate:a", 1.0, 0.7)


func _coin_pill(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := UIKit.box(UIKit.GLASS, 30)
	s.content_margin_left = 10
	s.content_margin_right = 20
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.name = "H"
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	h.add_child(UIKit.CoinIcon.new(34))
	var l := UIKit.label(text, 28, Color.WHITE, true)
	l.name = "Label"
	h.add_child(l)
	return p


func _set_island_label(k: int, b: Dictionary) -> void:
	if not level.is_empty():
		lbl_island.text = "Level %d  •  %s" % [Levels.index_of(String(level.id)) + 1, level.name]
		return
	lbl_island.text = "Pulau %d  •  %s" % [k + 1, b.name]


func _popup(text: String, sub: String, col: Color) -> void:
	lbl_popup.text = text
	lbl_popup.add_theme_color_override("font_color", col)
	lbl_sub.text = sub
	lbl_popup.pivot_offset = lbl_popup.size * 0.5
	var t := create_tween().set_parallel()
	lbl_popup.scale = Vector2(0.6, 0.6)
	lbl_popup.modulate.a = 1.0
	lbl_sub.modulate.a = 1.0 if sub != "" else 0.0
	t.tween_property(lbl_popup, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(0.6)
	t.chain().tween_property(lbl_popup, "modulate:a", 0.0, 0.35)
	t.parallel().tween_property(lbl_sub, "modulate:a", 0.0, 0.35)


func _hide_hint() -> void:
	if lbl_hint.visible:
		var t := create_tween()
		t.tween_property(lbl_hint, "modulate:a", 0.0, 0.5)
		t.tween_callback(lbl_hint.hide)


func _show_banner(k: int, b: Dictionary) -> void:
	_set_island_label(k, b)
	if banner:
		banner.queue_free()
	banner = UIKit.panel(Color(0.1, 0.06, 0.2, 0.78), 30)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_child(v)
	var a := UIKit.label("PULAU %d" % (k + 1), 24, Color("#ffd27c"), true)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(a)
	var n := UIKit.label(String(b.name), 50, Color.WHITE, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var s := UIKit.label("%s   •   +500" % b.subtitle, 22, Color(1, 1, 1, 0.85))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(banner)
	await get_tree().process_frame
	var vs := get_viewport_rect().size
	banner.position = Vector2((vs.x - banner.size.x) * 0.5, -banner.size.y)
	var t := create_tween()
	t.tween_property(banner, "position:y", 96.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(2.0)
	t.tween_property(banner, "position:y", -banner.size.y - 10, 0.35).set_ease(Tween.EASE_IN)


# ================================================================ pause

func _toggle_pause() -> void:
	if state != "play":
		return
	if pause_panel:
		pause_panel.queue_free()
		pause_panel = null
		get_tree().paused = false
		world.release_input()
		return
	get_tree().paused = true
	pause_panel = _overlay()
	var p := UIKit.panel()
	var side := HBoxContainer.new()
	side.add_theme_constant_override("separation", 20)
	side.add_child(p)
	var mp := UIKit.missions_panel(UIKit.active_mission_entries(), 400.0)
	mp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	side.add_child(mp)
	_center(pause_panel, side)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	p.add_child(v)
	var t := UIKit.label("Jeda", 54, Color.WHITE, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b1 := UIKit.button("Lanjut", UIKit.LEAF, UIKit.LEAF_DARK, 32, 320)
	b1.pressed.connect(_toggle_pause)
	v.add_child(b1)
	var b2 := UIKit.button("Ulang", UIKit.SUN, UIKit.SUN_DARK, 28, 320)
	b2.pressed.connect(func(): _leave_run("res://scenes/game.tscn"))
	v.add_child(b2)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	v.add_child(hb)
	var snd := UIKit.button(_onoff("Suara", Game.sound_on), UIKit.CREAM, Color("#d8c7a8"), 22)
	snd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snd.pressed.connect(func(): Game.toggle_sound(); snd.text = _onoff("Suara", Game.sound_on))
	hb.add_child(snd)
	var mus := UIKit.button(_onoff("Musik", Game.music_on), UIKit.CREAM, Color("#d8c7a8"), 22)
	mus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mus.pressed.connect(func(): Game.toggle_music(); mus.text = _onoff("Musik", Game.music_on))
	hb.add_child(mus)
	var b3 := UIKit.button("Menu Utama", UIKit.PLUM, UIKit.PLUM_DARK, 26, 320)
	b3.pressed.connect(func(): _leave_run("res://scenes/main_menu.tscn"))
	v.add_child(b3)


## Leaving mid-run from the pause panel banks the run's coins, pays finished missions and stops the run.
func _leave_run(path: String) -> void:
	state = "over"
	world.running = false
	var earned := coins_run - coins_banked
	coins_banked = coins_run
	Game.add_coins(earned)
	_settle_missions()
	goto_scene.call(path)


## Pays finished missions. Called at every run end (also after "Lanjut"): the results keep the missions
## the run started with, with their latest progress, and every payout of the run; replacements are not shown.
func _settle_missions() -> void:
	if missions_run.is_empty():
		missions_run = Game.missions.duplicate(true)
	else:
		for a in missions_run:
			for b in Game.missions:
				if b.id == a.id:
					a.progress = b.progress
	missions_done.append_array(Game.settle_missions())


## The run's missions for the results panel, with the reward of the ones just paid.
func _run_mission_entries() -> Array:
	var out: Array = []
	for a in missions_run:
		var paid := 0
		for d in missions_done:
			if d.id == a.id:
				paid = int(d.reward)
		out.append([Missions.get_mission(a.id), int(a.progress), paid])
	return out


## Puts the results panel and the run's missions side by side in the centre of the overlay.
func _center_with_missions(parent: Control, p: Control) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(p)
	var mp := UIKit.missions_panel(_run_mission_entries(), 400.0)
	mp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(mp)
	_center(parent, hb)


static func _onoff(name: String, on: bool) -> String:
	return "%s: %s" % [name, "On" if on else "Off"]


func _overlay() -> Control:
	var c := ColorRect.new()
	c.color = Color(0.05, 0.03, 0.12, 0.55)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(c)
	return c


func _center(parent: Control, child: Control) -> void:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(cc)
	cc.add_child(child)


# ================================================================ results

func _show_results(record: bool) -> void:
	result_panel = _overlay()
	result_panel.modulate.a = 0.0
	create_tween().tween_property(result_panel, "modulate:a", 1.0, 0.4)
	var p := UIKit.panel(Color(0.12, 0.08, 0.24, 0.9), 34)
	p.custom_minimum_size = Vector2(620, 0)
	_center_with_missions(result_panel, p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)

	var title := UIKit.label(String(CAUSE_TITLES.get(end_cause, "Run selesai")), 44, Color("#ffd8a8"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var tip := String(CAUSE_TIPS.get(end_cause, ""))
	if tip != "":
		var tl := UIKit.label(tip, 22, Color(1, 1, 1, 0.8))
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(tl)
	if record:
		var rec := UIKit.label("REKOR BARU!", 28, Color("#ffe066"), true, 6)
		rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(rec)
		var tw := rec.create_tween().set_loops()
		tw.tween_property(rec, "modulate", Color(1.3, 1.2, 0.8), 0.4)
		tw.tween_property(rec, "modulate", Color.WHITE, 0.4)

	var big := UIKit.label("0", 84, Color.WHITE, true, 12)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var final_score := score()
	var counter := create_tween()
	counter.tween_method(func(x: float): big.text = _fmt(int(x)), 0.0, float(final_score), 1.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	var rows := [["Jarak", "%s m" % _fmt(distance)], ["Pulau dicapai", str(world.current_island + 1)],
			["Nyerempet beruntun", str(best_skim)], ["Koin didapat", "+%d" % coins_run], ["Rekor", _fmt(Game.best_score)]]
	if not level.is_empty():
		rows = [["Level", String(level.name)], ["Koin level", "%d/%d" % [level_coins, level_coins_total]],
				["Nyerempet beruntun", str(best_skim)], ["Koin didapat", "+%d" % coins_run]]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	v.add_child(gc)
	for row in rows:
		grid.add_child(UIKit.label(row[0], 24, Color(1, 1, 1, 0.7)))
		var val := UIKit.label(row[1], 24, Color.WHITE, true)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)

	# exactly three buttons: Lanjut (ad, once per run), Main Lagi, Menu
	var cont := UIKit.button("Lanjut (tonton iklan)", UIKit.LEAF, UIKit.LEAF_DARK, 28)
	cont.name = "Lanjut"
	if continued:
		cont.text = "Lanjut sudah dipakai"
		cont.disabled = true
	else:
		cont.pressed.connect(func(): Ads.show_rewarded("Lanjut terbang", _on_continue_reward))
	v.add_child(cont)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var again := UIKit.button("Main Lagi" if level.is_empty() else "Ulangi", UIKit.SKY, UIKit.SKY_DARK, 30)
	again.name = "MainLagi"
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func(): Ads.on_run_finished(); _goto_level(String(level.get("id", ""))))
	row.add_child(again)
	var menu := UIKit.button("Menu" if level.is_empty() else "Peta", UIKit.PLUM, UIKit.PLUM_DARK, 30)
	menu.name = "Menu"
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(func(): Ads.on_run_finished(); Game.goto(MAIN_MENU if level.is_empty() else LEVEL_MAP))
	row.add_child(menu)


## Starts a run of the given level ("" = endless).
func _goto_level(id: String) -> void:
	Game.current_level = id
	Game.goto("res://scenes/game.tscn")


func _show_level_done(stars: int, new_stars: int, earned: int, bonus: int) -> void:
	result_panel = _overlay()
	result_panel.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_interval(0.8)   # let the bird glide past the gate first
	fade.tween_property(result_panel, "modulate:a", 1.0, 0.4)
	var p := UIKit.panel(Color(0.12, 0.08, 0.24, 0.9), 34)
	p.custom_minimum_size = Vector2(620, 0)
	_center_with_missions(result_panel, p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var title := UIKit.label("Level selesai!", 48, Color("#ffe066"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var name_l := UIKit.label(String(level.name), 26, Color(1, 1, 1, 0.85))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var row_s := StarRow.new()
	row_s.custom_minimum_size = Vector2(0, 110)
	row_s.total = stars
	v.add_child(row_s)
	var st := create_tween()
	st.tween_interval(1.2)
	for i in stars:
		st.tween_callback(func(): row_s.shown = i + 1; row_s.queue_redraw(); Sfx.play("perfect", 1.0 + 0.12 * i))
		st.tween_interval(0.3)
	var info := "Koin +%d" % earned
	if new_stars > 0:
		info += "   •   Bintang baru +%d koin" % bonus
	var il := UIKit.label(info, 24, Color.WHITE, true)
	il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(il)
	var hint := ""
	if level_coins < ceili(COIN_STAR_RATIO * level_coins_total):
		hint = "Kumpulkan %d koin untuk dapat bintang lagi" % ceili(COIN_STAR_RATIO * level_coins_total)
	elif continued:
		hint = "Selesaikan tanpa Lanjut untuk dapat bintang lagi"
	if hint != "":
		var hl := UIKit.label(hint, 22, Color(1, 1, 1, 0.75))
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(hl)
	# three buttons: Lanjut (next level), Ulangi, Peta
	var i_next := Levels.index_of(String(level.id)) + 1
	var next_id := ""
	if i_next < Levels.all().size():
		next_id = String(Levels.all()[i_next].id)
	var nxt := UIKit.button("Lanjut", UIKit.LEAF, UIKit.LEAF_DARK, 30)
	nxt.name = "Lanjut"
	nxt.disabled = next_id == "" or not Game.is_unlocked(next_id)
	nxt.pressed.connect(func(): Ads.on_run_finished(); _goto_level(next_id))
	v.add_child(nxt)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var again := UIKit.button("Ulangi", UIKit.SKY, UIKit.SKY_DARK, 28)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func(): Ads.on_run_finished(); _goto_level(String(level.id)))
	row.add_child(again)
	var map := UIKit.button("Peta", UIKit.PLUM, UIKit.PLUM_DARK, 28)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.pressed.connect(func(): Ads.on_run_finished(); Game.goto(LEVEL_MAP))
	row.add_child(map)


func _on_continue_reward(ok: bool) -> void:
	if ok:
		_continue_run()


static func _fmt(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


# ================================================================ level stars

class StarRow:
	extends Control
	var total := 0      # stars earned this run
	var shown := 0      # how many have popped in so far

	func _draw() -> void:
		var c := size * 0.5
		for i in 3:
			var p := c + Vector2((i - 1) * 96.0, 6.0 if i != 1 else -6.0)
			Art.level_star(self, p, 40.0 if i == 1 else 34.0, i < shown and i < total)


# ================================================================ stamina bar

class StaminaBar:
	extends Control
	var value := 1.0
	var exhausted := false

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.08, 0.05, 0.16, 0.55)
		bg.set_corner_radius_all(int(size.y / 2))
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		if value <= 0.0:
			return
		var col := Color("#7be07b").lerp(Color("#ffd24a"), clampf((0.6 - value) / 0.4, 0.0, 1.0))
		if exhausted:
			col = Color("#ff6b5a").lerp(Color.WHITE, 0.2 + 0.2 * sin(Time.get_ticks_msec() * 0.02))
		var fill := StyleBoxFlat.new()
		fill.bg_color = col
		fill.set_corner_radius_all(int((size.y - 4) / 2))
		draw_style_box(fill, Rect2(Vector2(2, 2), Vector2(maxf(size.y - 4, (size.x - 4) * value), size.y - 4)))

