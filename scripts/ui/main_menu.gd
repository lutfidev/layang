extends Node2D
## Title screen: autopilot bird flies through a random island behind the menu.

var world: World
var coin_pill: PanelContainer
var daily_btn: Button
var lbl_now: Label
var logo: Label


func _ready() -> void:
	Game.current_level = ""   # back on the menu: no adventure level is being played
	world = World.new()
	world.autoplay = true
	world.input_enabled = false
	world.hazards = false
	world.start_island = Game.dev_int("island", randi() % Biomes.count())
	world.sun_progress = 0.8
	world.bird_screen_x = 0.56
	add_child(world)
	world.island_reached.connect(func(_k, b): lbl_now.text = "Sedang melintas: %s" % b.name)
	_build_ui()
	Game.coins_changed.connect(func(v): (coin_pill.get_node("H/Label") as Label).text = str(v))


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := UIKit.full_rect(Control.new())
	layer.add_child(root)

	# readability gradient on the left
	var g := Gradient.new()
	g.set_color(0, Color(0.06, 0.03, 0.14, 0.72))
	g.set_color(1, Color(0.06, 0.03, 0.14, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.anchor_bottom = 1.0
	shade.offset_right = 760
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)

	var col := VBoxContainer.new()
	col.position = Vector2(80, 70)
	col.add_theme_constant_override("separation", 14)
	root.add_child(col)

	logo = UIKit.label("LAYANG", 132, Color("#fff3c4"), true, 22)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	logo.add_theme_constant_override("shadow_offset_y", 8)
	col.add_child(logo)
	var tag := UIKit.label("Terbang tanpa batas melintasi Nusantara", 28, Color.WHITE, false, 8)
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	col.add_child(gap)

	var play := UIKit.button("Petualangan", UIKit.LEAF, UIKit.LEAF_DARK, 42, 380)
	play.custom_minimum_size.y = 86
	play.pressed.connect(func(): Game.goto("res://scenes/level_map.tscn"))
	col.add_child(play)
	var endless := UIKit.button("Tanpa Batas", UIKit.SKY, UIKit.SKY_DARK, 30, 380)
	endless.pressed.connect(func():
		Game.current_level = ""
		Game.goto("res://scenes/game.tscn"))
	col.add_child(endless)
	var shop := UIKit.button("Toko Burung", UIKit.SUN, UIKit.SUN_DARK, 30, 380)
	shop.pressed.connect(func(): Game.goto("res://scenes/shop.tscn"))
	col.add_child(shop)
	daily_btn = UIKit.button("", UIKit.PLUM, UIKit.PLUM_DARK, 26, 380)
	daily_btn.pressed.connect(_claim_daily)
	col.add_child(daily_btn)
	_refresh_daily()

	var stats := UIKit.label("Rekor %s   •   Pulau terjauh %d" % [_fmt(Game.best_score), max(1, Game.best_island)], 24, Color(1, 1, 1, 0.85), false, 6)
	col.add_child(stats)

	# top-right: coins + toggles
	var tr := HBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.position = Vector2(-28, 24)
	tr.add_theme_constant_override("separation", 12)
	root.add_child(tr)
	if not Game.ads_removed:
		var noads := UIKit.button("Hapus Iklan", UIKit.CREAM, Color("#d8c7a8"), 22)
		noads.pressed.connect(func(): Ads.purchase("remove_ads"); noads.hide())
		tr.add_child(noads)
	var snd := UIKit.button(_onoff("Suara", Game.sound_on), UIKit.CREAM, Color("#d8c7a8"), 22)
	snd.pressed.connect(func(): Game.toggle_sound(); snd.text = _onoff("Suara", Game.sound_on))
	tr.add_child(snd)
	var mus := UIKit.button(_onoff("Musik", Game.music_on), UIKit.CREAM, Color("#d8c7a8"), 22)
	mus.pressed.connect(func(): Game.toggle_music(); mus.text = _onoff("Musik", Game.music_on))
	tr.add_child(mus)
	coin_pill = _coin_pill(str(Game.coins))
	tr.add_child(coin_pill)

	# right: the three active missions
	var mp := UIKit.missions_panel(UIKit.active_mission_entries(), 420.0)
	root.add_child(mp)
	mp.anchor_left = 1.0
	mp.anchor_right = 1.0
	mp.offset_left = -448.0
	mp.offset_right = -28.0
	mp.offset_top = 150.0

	lbl_now = UIKit.label("Sedang melintas: %s" % world.current_biome().name, 22, Color(1, 1, 1, 0.9), false, 6)
	lbl_now.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(lbl_now)
	lbl_now.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	lbl_now.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	# entrance animation
	col.modulate.a = 0.0
	col.position.x = 40
	var t := create_tween().set_parallel()
	t.tween_property(col, "modulate:a", 1.0, 0.6)
	t.tween_property(col, "position:x", 80.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _process(_d: float) -> void:
	if logo:
		logo.rotation = sin(Time.get_ticks_msec() * 0.0015) * 0.015


func _refresh_daily() -> void:
	if Game.can_claim_daily():
		daily_btn.text = "Hadiah Harian  +%d" % Game.next_daily_amount()
		daily_btn.disabled = false
	else:
		daily_btn.text = "Hadiah besok lagi (hari ke-%d)" % (Game.daily_streak + 1)
		daily_btn.disabled = true


func _claim_daily() -> void:
	var amount := Game.claim_daily()
	if amount <= 0:
		return
	Sfx.play("buy")
	var cam := world.camera
	Ambient.burst(world, cam.position, Color("#ffe066"), 50, 900.0)
	var l := UIKit.label("+%d koin!" % amount, 72, Color("#ffe066"), true, 14)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	daily_btn.get_parent().get_parent().add_child(l)
	var t := create_tween()
	t.tween_property(l, "position:y", l.position.y - 80.0, 1.2)
	t.parallel().tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.5)
	t.tween_callback(l.queue_free)
	_refresh_daily()


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


static func _onoff(name: String, on: bool) -> String:
	return "%s: %s" % [name, "On" if on else "Off"]


static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
