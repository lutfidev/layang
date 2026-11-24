extends Node2D
## Adventure map: 6 island groups x 3 levels in a sideways scroll, over an autopilot island backdrop.
## A level opens when the one before has a star and its island's hazard exists (Game.is_unlocked).

const BTN := 96.0

var world: World
var level_buttons: Array[Button] = []
var _scroll: ScrollContainer
var _groups: Array[Control] = []


func _ready() -> void:
	world = World.new()
	world.autoplay = true
	world.input_enabled = false
	world.hazards = false
	world.start_island = int(Levels.all()[scroll_target_index()].island)
	world.sun_progress = 0.8
	world.bird_screen_x = 0.5
	add_child(world)
	_build_ui()


## Index of the level the map scrolls to: the last one the player can open.
func scroll_target_index() -> int:
	return Game.last_unlocked_index()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := UIKit.full_rect(Control.new())
	layer.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.03, 0.14, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(UIKit.full_rect(shade))

	# top bar: back, title, star total
	var back := UIKit.button("Kembali", UIKit.CREAM, Color("#d8c7a8"), 24)
	back.position = Vector2(28, 24)
	back.pressed.connect(func(): Game.goto("res://scenes/main_menu.tscn"))
	root.add_child(back)
	var title := UIKit.label("Petualangan", 54, Color("#fff3c4"), true, 14)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position.y = 22
	root.add_child(title)
	var total := UIKit.pill("Bintang %d/%d" % [Game.total_stars(), Levels.all().size() * 3])
	root.add_child(total)
	total.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 28)
	total.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	# the island groups
	_scroll = ScrollContainer.new()
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 12   # a tap on a level stays a tap; a drag scrolls
	_scroll.anchor_right = 1.0
	_scroll.anchor_bottom = 1.0
	_scroll.offset_top = 130
	_scroll.offset_bottom = -40
	root.add_child(_scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(row)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(12, 0)
	row.add_child(pad)
	for k in Biomes.count():
		var g := _island_group(k)
		_groups.append(g)
		row.add_child(g)
	var pad2 := pad.duplicate()
	row.add_child(pad2)
	_pass_touch(row)
	_scroll_to.call_deferred(scroll_target_index() / 3)


func _island_group(k: int) -> Control:
	var b := Biomes.get_biome(k)
	var ready_island := Levels.READY_ISLANDS.has(b.id)
	var p := UIKit.panel(Color(0.1, 0.06, 0.2, 0.72), 30)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var name_l := UIKit.label(String(b.name), 30, Color.WHITE, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var sub := UIKit.label(String(b.subtitle), 18, Color(1, 1, 1, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 22)
	v.add_child(h)
	for t in 3:
		var i := k * 3 + t
		h.add_child(_level_cell(i))
	if not ready_island:
		var soon := UIKit.label("Segera hadir", 24, Color("#ffd27c"), true, 6)
		soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(soon)
	return p


func _level_cell(i: int) -> Control:
	var lv: Dictionary = Levels.all()[i]
	var open := Game.is_unlocked(String(lv.id))
	var stars := int(Game.level_stars.get(lv.id, 0))
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 6)
	var col := UIKit.SUN if stars > 0 else UIKit.LEAF
	var dark := UIKit.SUN_DARK if stars > 0 else UIKit.LEAF_DARK
	if not open:
		col = Color("#8f8aa3")
		dark = Color("#5d5870")
	var btn := UIKit.button(str(i + 1), col, dark, 36)
	btn.custom_minimum_size = Vector2(BTN, BTN)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := btn.get_theme_stylebox(st)
		if sb is StyleBoxFlat:
			var c := (sb as StyleBoxFlat).duplicate()
			c.set_corner_radius_all(int(BTN / 2))
			btn.add_theme_stylebox_override(st, c)
	btn.disabled = not open
	btn.pressed.connect(func():
		Game.current_level = String(lv.id)
		Game.goto("res://scenes/game.tscn"))
	level_buttons.append(btn)
	cell.add_child(btn)
	var strip := StarStrip.new()
	strip.stars = stars
	strip.custom_minimum_size = Vector2(BTN, 26)
	cell.add_child(strip)
	var tier := UIKit.label(Levels.TIER_NAMES[int(lv.tier)], 18, Color(1, 1, 1, 0.8))
	tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(tier)
	return cell


## Lets a finger drag anywhere on the map scroll it: nothing inside may stop the touch
## (buttons still get their press with PASS).
func _pass_touch(n: Node) -> void:
	if n is Control and (n as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for c in n.get_children():
		_pass_touch(c)


func _scroll_to(group: int) -> void:
	if group < _groups.size():
		_scroll.scroll_horizontal = int(maxf(0.0, _groups[group].position.x - 40.0))


class StarStrip:
	extends Control
	var stars := 0

	func _draw() -> void:
		for i in 3:
			Art.level_star(self, Vector2(size.x * 0.5 + (i - 1) * 28.0, size.y * 0.5), 11.0, i < stars)
