extends Node2D
## Game scene: rules (sunset timer, islands, combos, fever), HUD, pause and results.

const START_TIME := 42.0
const NIGHT_GRACE := 6.0

var world: World
var state := "ready"       # ready → play → night → over
var time_left := START_TIME
var distance := 0
var style_points := 0
var coins_run := 0
var coins_banked := 0
var perfect_streak := 0
var best_streak := 0
var fever_t := 0.0
var night_t := 0.0
var continued := false
var doubled := false
var coin_chain := 0
var coin_chain_t := 0.0
var start_x := 0.0
var hint_t := 0.0

var hud: CanvasLayer
var time_bar: TimeBar
var lbl_time: Label
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
	if Game.dev.has("time"):
		time_left = float(Game.dev["time"])
	world = World.new()
	world.start_island = Game.dev_int("island", 0)
	world.running = false
	world.autoplay = Game.dev.has("autoplay")
	add_child(world)
	start_x = world.bird.position.x
	world.island_reached.connect(_on_island)
	world.item_collected.connect(_on_item)
	world.bird_landed.connect(_on_landed)
	world.bird_splashed.connect(func(): Sfx.play("splash"))
	_build_hud()
	if world.autoplay:
		_start()


# ================================================================ flow

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state in ["play", "night"]:
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


func _physics_process(delta: float) -> void:
	if state == "play":
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_nightfall()
	elif state == "night":
		night_t += delta
		var b := world.bird
		if night_t > NIGHT_GRACE or (b.on_ground and night_t > 1.5 and b.speed() < 150.0):
			_finish()
	if state in ["play", "night"]:
		distance = int((world.bird.position.x - start_x) / 10.0)
		world.sun_progress = clampf(time_left / START_TIME, 0.0, 1.0)
		world.set_dusk(clampf(1.0 - time_left / 12.0, 0.0, 1.0))
		if fever_t > 0.0:
			fever_t -= delta
			if fever_t <= 0.0:
				world.bird.fever = false
				fever_lbl.hide()
		coin_chain_t -= delta
		if coin_chain_t <= 0.0:
			coin_chain = 0
		if hint_t > 0.0:
			hint_t -= delta
			if hint_t <= 0.0:
				_hide_hint()


func _process(_delta: float) -> void:
	time_bar.value = clampf(time_left / START_TIME, 0.0, 1.0)
	lbl_time.text = "%d" % ceili(time_left)
	lbl_score.text = _fmt(score())
	(coin_pill.get_node("H/Label") as Label).text = str(coins_run)
	if fever_lbl.visible:
		fever_lbl.scale = Vector2.ONE * (1.0 + 0.06 * sin(Time.get_ticks_msec() * 0.02))


func score() -> int:
	return distance + style_points


func _nightfall() -> void:
	state = "night"
	night_t = 0.0
	world.bird.sleepy = true
	world.bird.fever = false
	fever_lbl.hide()
	Sfx.play("night")
	_popup("Matahari terbenam…", "Burung mulai mengantuk", Color("#ffd0a8"))


func _finish() -> void:
	state = "over"
	world.running = false
	var earned := coins_run - coins_banked
	coins_banked = coins_run
	Game.add_coins(earned)
	var record := Game.submit_run(score(), distance, world.current_island + 1)
	lbl_hint.hide()
	if Game.dev.has("autoplay"):
		print("RUN score=%d dist=%d islands=%d coins=%d best_streak=%d" % [score(), distance, world.current_island + 1, coins_run, best_streak])
		if Game.dev.has("sim"):
			get_tree().quit()
	_show_results(record)


func _continue_run() -> void:
	continued = true
	result_panel.queue_free()
	result_panel = null
	time_left = 12.0
	state = "play"
	world.bird.sleepy = false
	world.bird.vel.x = maxf(world.bird.vel.x, 500.0)
	world.running = true
	world.release_input()
	_popup("+12 detik!", "Terbang lagi!", Color("#ffe066"))


# ================================================================ events

func _on_island(k: int, biome: Dictionary) -> void:
	var bonus := maxf(6.0, 17.0 - k * 1.5)
	if state == "play":
		time_left += bonus
	elif state == "night":
		# reaching an island at dusk wakes the bird up again
		state = "play"
		time_left = bonus
		world.bird.sleepy = false
	style_points += 500
	coins_run += 20
	Sfx.play("island")
	Ambient.burst(world, world.bird.center(), Color("#ffe066"), 40, 700.0)
	_show_banner(k, biome, bonus)


func _on_item(kind: int, _pos: Vector2) -> void:
	if kind == CoinField.COIN:
		coins_run += 2 if world.bird.fever else 1
		coin_chain += 1
		coin_chain_t = 0.6
		Sfx.play("coin", 1.0 + 0.045 * mini(coin_chain, 14))
	else:
		time_left += 3.0
		Sfx.play("sun")
		_popup("+3 detik", "Matahari kecil!", Color("#ffe066"))


func _on_landed(bonk: bool) -> void:
	if state == "over":
		return
	var height := world.bird.max_air_height
	perfect_streak = 0
	if bonk:
		Sfx.play("bonk")
		_popup("Aduh!", "Nabrak tanjakan", Color("#ff8a8a"))
	elif height > 520.0:
		var pts := int(height / 5.0)
		style_points += pts
		_popup("TERBANG TINGGI!", "+%d" % pts, Color("#8fd8ff"))


# ================================================================ HUD

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	var root := UIKit.full_rect(Control.new())
	hud.add_child(root)

	# --- time bar (top-left)
	var tb := HBoxContainer.new()
	tb.position = Vector2(28, 24)
	tb.add_theme_constant_override("separation", 10)
	tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tb)
	tb.add_child(UIKit.SunIcon.new(42))
	time_bar = TimeBar.new()
	time_bar.custom_minimum_size = Vector2(300, 26)
	time_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tb.add_child(time_bar)
	lbl_time = UIKit.label("42", 32, Color.WHITE, true, 8)
	tb.add_child(lbl_time)
	lbl_island = UIKit.label("", 22, Color(1, 1, 1, 0.92), false, 6)
	lbl_island.position = Vector2(84, 62)
	root.add_child(lbl_island)
	_set_island_label(0, world.current_biome())

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
	fever_lbl.position = Vector2(30, 100)
	fever_lbl.hide()
	root.add_child(fever_lbl)

	# --- tutorial hint (bottom)
	lbl_hint = UIKit.label("TAHAN layar saat menurun  •  LEPAS saat menanjak untuk melambung", 26, Color.WHITE, true, 10)
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
	var l1 := UIKit.label(String(b.name).to_upper(), 64, Color.WHITE, true, 14)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_box.add_child(l1)
	var l2 := UIKit.label("Ketuk untuk terbang", 32, Color("#fff3c4"), false, 10)
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


func _show_banner(k: int, b: Dictionary, bonus: float) -> void:
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
	var s := UIKit.label("%s   •   +%d detik" % [b.subtitle, int(bonus)], 22, Color(1, 1, 1, 0.85))
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
	if state == "over" or state == "ready":
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
	_center(pause_panel, p)
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
	b2.pressed.connect(func(): Game.goto("res://scenes/game.tscn"))
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
	b3.pressed.connect(func(): Game.goto("res://scenes/main_menu.tscn"))
	v.add_child(b3)


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
	_center(result_panel, p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)

	var title := UIKit.label("Senja telah tiba", 44, Color("#ffd8a8"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
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

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 4)
	var gc := CenterContainer.new()
	gc.add_child(grid)
	v.add_child(gc)
	for row in [["Jarak", "%s m" % _fmt(distance)], ["Pulau dicapai", str(world.current_island + 1)],
			["Mulus beruntun", str(best_streak)], ["Koin didapat", "+%d" % coins_run], ["Rekor", _fmt(Game.best_score)]]:
		grid.add_child(UIKit.label(row[0], 24, Color(1, 1, 1, 0.7)))
		var val := UIKit.label(row[1], 24, Color.WHITE, true)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)

	var ads_row := HBoxContainer.new()
	ads_row.add_theme_constant_override("separation", 12)
	v.add_child(ads_row)
	if not continued:
		var cont := UIKit.button("Lanjut +12 dtk (iklan)", UIKit.LEAF, UIKit.LEAF_DARK, 24)
		cont.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cont.pressed.connect(func(): Ads.show_rewarded("Lanjut terbang", _on_continue_reward))
		ads_row.add_child(cont)
	if coins_run > 0 and not doubled:
		var dbl := UIKit.button("Koin ×2 (iklan)", UIKit.SUN, UIKit.SUN_DARK, 24)
		dbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dbl.pressed.connect(func(): Ads.show_rewarded("Gandakan koin", _on_double_reward.bind(dbl)))
		ads_row.add_child(dbl)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	v.add_child(row2)
	var again := UIKit.button("Main Lagi", UIKit.SKY, UIKit.SKY_DARK, 30)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func(): Ads.on_run_finished(); Game.goto("res://scenes/game.tscn"))
	row2.add_child(again)
	var menu := UIKit.button("Menu", UIKit.PLUM, UIKit.PLUM_DARK, 30)
	menu.pressed.connect(func(): Ads.on_run_finished(); Game.goto("res://scenes/main_menu.tscn"))
	row2.add_child(menu)


func _on_continue_reward(ok: bool) -> void:
	if ok:
		_continue_run()


func _on_double_reward(ok: bool, btn: Button) -> void:
	if ok and not doubled:
		doubled = true
		Game.add_coins(coins_run)
		btn.disabled = true
		btn.text = "+%d koin!" % coins_run
		Sfx.play("buy")


static func _fmt(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


# ================================================================ time bar

class TimeBar:
	extends Control
	var value := 1.0

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.08, 0.05, 0.16, 0.6)
		bg.set_corner_radius_all(int(size.y / 2))
		draw_style_box(bg, r)
		var w := maxf(size.y, (size.x - 6) * value)
		var fill := StyleBoxFlat.new()
		var low := value < 0.28
		var col := Color("#ffd24a").lerp(Color("#ff6b4a"), clampf((0.45 - value) / 0.35, 0.0, 1.0))
		if low:
			col = col.lerp(Color.WHITE, 0.25 + 0.25 * sin(Time.get_ticks_msec() * 0.015))
		fill.bg_color = col
		fill.set_corner_radius_all(int((size.y - 6) / 2))
		if value > 0.0:
			draw_style_box(fill, Rect2(Vector2(3, 3), Vector2(w, size.y - 6)))
		draw_rect(Rect2(Vector2(10, 6), Vector2(maxf(0.0, w - 14), 3)), Color(1, 1, 1, 0.35))
