extends Node2D
## Bird shop: browse skins, buy with coins (or IAP for the premium one), equip.

var world: World
var preview: Bird
var selected := 0
var lbl_name: Label
var lbl_desc: Label
var action_btn: Button
var iap_btn: Button
var coin_pill: PanelContainer
var cards: Array = []
var stage: Control


func _ready() -> void:
	world = World.new()
	world.autoplay = true
	world.input_enabled = false
	world.hazards = false
	world.start_island = Game.dev_int("island", 5)
	world.sun_progress = 0.75
	add_child(world)
	selected = Skins.index_of(Game.equipped_skin)
	_build_ui()
	_select(selected)
	Ads.purchase_finished.connect(func(_id, _ok): _refresh())


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := UIKit.full_rect(Control.new())
	layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.03, 0.14, 0.45)
	UIKit.full_rect(dim)
	root.add_child(dim)

	# top bar
	var back := UIKit.button("Kembali", UIKit.CREAM, Color("#d8c7a8"), 24)
	back.position = Vector2(28, 22)
	back.pressed.connect(func(): Game.goto("res://scenes/main_menu.tscn"))
	root.add_child(back)
	var title := UIKit.label("Toko Burung", 48, Color.WHITE, true, 12)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position.y = 18
	root.add_child(title)
	var tr := HBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	tr.position = Vector2(-28, 22)
	tr.add_theme_constant_override("separation", 12)
	root.add_child(tr)
	var pack := UIKit.button("+1.500 koin  %s" % Ads.PRODUCTS.coin_pack.price, UIKit.CREAM, Color("#d8c7a8"), 20)
	pack.pressed.connect(func(): Ads.purchase("coin_pack"); Sfx.play("buy"))
	tr.add_child(pack)
	coin_pill = _coin_pill(str(Game.coins))
	tr.add_child(coin_pill)
	Game.coins_changed.connect(func(v): (coin_pill.get_node("H/Label") as Label).text = str(v))

	# left: big preview
	var left := UIKit.panel(Color(0.1, 0.06, 0.2, 0.7), 34)
	left.position = Vector2(60, 110)
	left.custom_minimum_size = Vector2(500, 560)
	root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	stage = Control.new()
	stage.custom_minimum_size = Vector2(440, 270)
	stage.clip_contents = false
	lv.add_child(stage)
	preview = Bird.new()
	preview.preview = true
	preview.skin = Skins.all()[selected]
	preview.scale = Vector2(3.6, 3.6)
	preview.position = Vector2(220, 190)
	stage.add_child(preview)
	lbl_name = UIKit.label("", 46, Color.WHITE, true)
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(lbl_name)
	lbl_desc = UIKit.label("", 22, Color(1, 1, 1, 0.8))
	lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_desc.custom_minimum_size = Vector2(440, 60)
	lv.add_child(lbl_desc)
	action_btn = UIKit.button("", UIKit.LEAF, UIKit.LEAF_DARK, 32)
	action_btn.pressed.connect(_on_action)
	lv.add_child(action_btn)
	iap_btn = UIKit.button("", UIKit.PLUM, UIKit.PLUM_DARK, 22)
	iap_btn.pressed.connect(func(): Ads.purchase("skin_garuda"); Sfx.play("buy"))
	lv.add_child(iap_btn)

	# right: grid of cards
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(600, 120)
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	root.add_child(grid)
	var list := Skins.all()
	for i in list.size():
		var card := _make_card(i, list[i])
		grid.add_child(card)
		cards.append(card)


func _make_card(i: int, s: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(196, 256)
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = false
	b.pressed.connect(func(): Sfx.play("click"); _select(i))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var st := Control.new()
	st.custom_minimum_size = Vector2(196, 130)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(st)
	var bird := Bird.new()
	bird.preview = true
	bird.skin = s
	bird.scale = Vector2(1.8, 1.8)
	bird.position = Vector2(98, 104)
	st.add_child(bird)
	var n := UIKit.label(s.name, 24, Color.WHITE, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var p := UIKit.label("", 22, Color("#ffe066"), true)
	p.name = "Price"
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(p)
	b.set_meta("price_label", p)
	return b


func _card_style(selected_card: bool, owned: bool) -> StyleBoxFlat:
	var c := Color(0.16, 0.1, 0.3, 0.82) if owned else Color(0.1, 0.07, 0.18, 0.82)
	var s := UIKit.box(c, 26)
	if selected_card:
		s.border_color = Color("#ffd24a")
		s.set_border_width_all(5)
	return s


func _refresh() -> void:
	var list := Skins.all()
	for i in cards.size():
		var s: Dictionary = list[i]
		var b: Button = cards[i]
		var owned := Game.owns(s.id)
		var st := _card_style(i == selected, owned)
		for k in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(k, st)
		var p: Label = b.get_meta("price_label")
		if Game.equipped_skin == s.id:
			p.text = "Dipakai"
			p.add_theme_color_override("font_color", Color("#9dff8a"))
		elif owned:
			p.text = "Dimiliki"
			p.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		else:
			p.text = "%d koin" % s.price
			p.add_theme_color_override("font_color", Color("#ffe066"))
	var cur: Dictionary = list[selected]
	lbl_name.text = cur.name
	lbl_desc.text = cur.desc
	var owned_cur := Game.owns(cur.id)
	if Game.equipped_skin == cur.id:
		action_btn.text = "Sedang dipakai"
		action_btn.disabled = true
	elif owned_cur:
		action_btn.text = "Pakai"
		action_btn.disabled = false
	else:
		action_btn.text = "Beli  •  %d koin" % cur.price
		action_btn.disabled = Game.coins < int(cur.price)
	iap_btn.visible = cur.has("iap") and not owned_cur
	if iap_btn.visible:
		iap_btn.text = "Beli langsung  %s" % Ads.PRODUCTS[cur.iap].price


func _select(i: int) -> void:
	selected = i
	preview.set_skin(Skins.all()[i])
	preview.scale = Vector2(3.0, 3.0)
	var t := create_tween()
	t.tween_property(preview, "scale", Vector2(3.6, 3.6), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_refresh()


func _on_action() -> void:
	var cur: Dictionary = Skins.all()[selected]
	if Game.owns(cur.id):
		Game.equip_skin(cur.id)
	elif Game.spend_coins(int(cur.price)):
		Game.unlock_skin(cur.id)
		Game.equip_skin(cur.id)
		Sfx.play("buy")
		Ambient.burst(world, world.camera.position, cur.trail_a, 40, 800.0)
	_refresh()


func _process(_d: float) -> void:
	if preview:
		preview.position.y = 190 + sin(Time.get_ticks_msec() * 0.003) * 10.0
		preview.rotation = sin(Time.get_ticks_msec() * 0.002) * 0.08


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
