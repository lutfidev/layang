class_name World
extends Node2D
## The playable world: sky, parallax backdrop, terrain, collectibles, bird, camera, weather.
## Used by the game scene (player control) and by the menus (autopilot demo).

signal island_reached(k: int, biome: Dictionary)
signal item_collected(kind: int, pos: Vector2)
signal bird_landed(bonk: bool)
signal bird_splashed
signal bird_died(cause: String)        # "laut" | "monster"
signal bird_skimmed(duration: float)

var autoplay := false
var running := true
var start_island := 0
var run_seed := 1
var sun_progress := 1.0     # 1 = high sun, 0 = sunset
var shake := 0.0
var bird_screen_x := 0.3   # where the bird sits horizontally on screen (0..1)

var terrain: Terrain
var bird: Bird
var coins: CoinField
var camera: Camera2D
var backdrop: Backdrop
var ambient: Ambient
var current_island := 0
var input_enabled := true
var hazards := true        # false in menu / shop demo worlds: the sea just bounces the bird
var dead := false
var monster: SeaMonster

var _sky_mat: ShaderMaterial
var _sky_rect: ColorRect
var _modulate: CanvasModulate
var _biome_from: Dictionary
var _biome_to: Dictionary
var _blend := 1.0
var _zoom := 1.0
var _touch_hold := false
var _dusk := 0.0
var _in_sea := false
var _jumps_left := 0
var _jump_cd := 0.0


func _ready() -> void:
	if run_seed == 1:
		run_seed = randi() % 100000 + 2
	# sky
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	_sky_rect = ColorRect.new()
	_sky_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://shaders/sky.gdshader")
	_sky_rect.material = _sky_mat
	sky_layer.add_child(_sky_rect)
	# backdrop
	var bd_layer := CanvasLayer.new()
	bd_layer.layer = -5
	add_child(bd_layer)
	backdrop = Backdrop.new()
	bd_layer.add_child(backdrop)
	# world
	_modulate = CanvasModulate.new()
	add_child(_modulate)
	coins = CoinField.new()
	coins.z_index = 2
	terrain = Terrain.new()
	add_child(terrain)
	add_child(coins)
	terrain.setup(run_seed, start_island, coins)
	bird = Bird.new()
	bird.terrain = terrain
	bird.position = Vector2(-880, terrain.height_at(-880))
	add_child(bird)
	monster = SeaMonster.new()
	add_child(monster)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	# weather
	var amb_layer := CanvasLayer.new()
	amb_layer.layer = 2
	add_child(amb_layer)
	ambient = Ambient.new()
	amb_layer.add_child(ambient)

	coins.collected.connect(func(kind, pos): item_collected.emit(kind, pos))
	bird.landed.connect(_on_landed)
	bird.splashed.connect(_on_splash)
	bird.skimmed.connect(func(d: float): bird_skimmed.emit(d))

	_biome_to = Biomes.get_biome(start_island)
	_biome_from = _biome_to
	backdrop.biome_a = _biome_to
	backdrop.biome_b = _biome_to
	ambient.set_biome(_biome_to)
	_update_camera(1.0, true)
	_update_sky()


func current_biome() -> Dictionary:
	return _biome_to


func set_dusk(v: float) -> void:
	_dusk = v


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_touch_hold = event.pressed
	elif event is InputEventScreenTouch and not ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"):
		_touch_hold = event.pressed


func release_input() -> void:
	_touch_hold = false


func _physics_process(delta: float) -> void:
	if not running or dead:
		return
	if autoplay:
		bird.holding = _ai_hold()
	else:
		bird.holding = input_enabled and (_touch_hold or Input.is_action_pressed("fly"))
	bird.step(delta)
	_update_hazards(delta)
	if dead:
		return
	coins.check(bird.center(), 48.0, 230.0 if bird.fever else 0.0, delta)
	var k := terrain.island_at(bird.position.x)
	if k > current_island:
		current_island = k
		_change_biome(Biomes.get_biome(start_island + k))
		island_reached.emit(k, _biome_to)


func _update_hazards(delta: float) -> void:
	var x := bird.position.x
	var over_sea := terrain.is_sea_at(x)
	if not hazards:
		if over_sea and bird.position.y > Terrain.WATER_Y - 30.0:
			bird.vel.y = -Bird.MAX_RISE
			bird.on_ground = false
		return
	if over_sea and not _in_sea:
		_jumps_left = monster.jumps_for_island(start_island + terrain.island_at(x))
		_jump_cd = 0.0
	_in_sea = over_sea
	_jump_cd -= delta
	if over_sea and _jumps_left > 0 and _jump_cd <= 0.0 and monster.state == "idle":
		var tx := x + bird.vel.x * (SeaMonster.WARN_TIME + 0.55)
		if terrain.is_sea_at(tx - SeaMonster.SPAN * 0.5) and terrain.is_sea_at(tx + SeaMonster.SPAN * 0.5):
			monster.arm(tx)
			_jumps_left -= 1
			_jump_cd = SeaMonster.WARN_TIME + SeaMonster.JUMP_TIME + 0.5
	if monster.update(delta, bird.center()):
		_die("monster")
	elif over_sea and bird.center().y > Terrain.WATER_Y:
		_die("laut")


func _die(cause: String) -> void:
	dead = true
	if cause == "monster":
		shake = 1.2
		Sfx.play("chomp")
		Ambient.burst(self, bird.center(), Color("#ffffff"), 22, 520.0)
	bird_died.emit(cause)


## Removes any active sea monster and its remaining jumps for this sea (used by "Lanjut terbang").
func clear_hazards() -> void:
	monster.reset()
	_jumps_left = 0
	_jump_cd = 0.0


func _ai_hold() -> bool:
	var x := bird.position.x
	var look := x + clampf(bird.vel.x * 0.07, 20.0, 150.0)
	var s := terrain.slope_at(look)
	if bird.on_ground:
		return s > 0.0
	var h := terrain.height_at(look)
	var height_above := h - bird.position.y
	return s > 0.04 and bird.vel.y > -80.0 and height_above < 900.0


func _change_biome(b: Dictionary) -> void:
	_biome_from = _biome_to
	_biome_to = b
	backdrop.biome_a = _biome_from
	backdrop.biome_b = _biome_to
	_blend = 0.0
	ambient.set_biome(b)


func _process(delta: float) -> void:
	if _blend < 1.0:
		_blend = minf(1.0, _blend + delta / 2.2)
	backdrop.blend = _blend
	_update_camera(delta, false)
	_update_sky()
	coins.view_left = camera.position.x - _view_half().x
	coins.view_right = camera.position.x + _view_half().x


func _view_half() -> Vector2:
	return get_viewport_rect().size / (2.0 * _zoom)


func _update_camera(delta: float, snap: bool) -> void:
	var vs := get_viewport_rect().size
	var top := minf(bird.position.y - 260.0, -620.0)
	var bottom := 370.0
	var z := clampf(vs.y / (bottom - top), 0.36, 0.74)
	_zoom = z if snap else lerpf(_zoom, z, minf(1.0, delta * 2.5))
	var half_h := vs.y / (2.0 * _zoom)
	var cy := bottom - half_h
	if bird.position.y < cy - half_h + 90.0:
		cy = bird.position.y + half_h - 90.0
	var cx := bird.position.x + vs.x * (0.5 - bird_screen_x) / _zoom
	var off := Vector2.ZERO
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 2.5)
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 18.0
	camera.position = Vector2(cx, cy) + off
	camera.zoom = Vector2(_zoom, _zoom)
	var hw := vs.x / (2.0 * _zoom)
	terrain.update_view(cx - hw, cx + hw)
	backdrop.cam_x = cx


func _update_sky() -> void:
	var a := _biome_from
	var b := _biome_to
	var t := _blend
	var vs := get_viewport_rect().size
	_sky_mat.set_shader_parameter("top_color", (a.sky_top as Color).lerp(b.sky_top, t))
	_sky_mat.set_shader_parameter("mid_color", (a.sky_mid as Color).lerp(b.sky_mid, t))
	_sky_mat.set_shader_parameter("horizon_color", (a.sky_horizon as Color).lerp(b.sky_horizon, t))
	_sky_mat.set_shader_parameter("sun_color", (a.sun as Color).lerp(b.sun, t))
	_sky_mat.set_shader_parameter("sun_size", lerpf(a.sun_size, b.sun_size, t))
	_sky_mat.set_shader_parameter("stars", lerpf(a.stars, b.stars, t))
	var sx := lerpf(a.sun_x, b.sun_x, t)
	_sky_mat.set_shader_parameter("sun_pos", Vector2(sx, lerpf(0.6, 0.16, sun_progress)))
	_sky_mat.set_shader_parameter("dusk", _dusk)
	_sky_mat.set_shader_parameter("aspect", vs.x / vs.y)
	_sky_mat.set_shader_parameter("scroll", backdrop.cam_x * 0.00002)
	var tint := (a.tint as Color).lerp(b.tint, t)
	var dusk_tint := Color(0.62, 0.52, 0.78)
	var final := tint * Color.WHITE.lerp(dusk_tint, _dusk * 0.75)
	_modulate.color = final
	backdrop.tint = Color.WHITE.lerp(Color(0.55, 0.45, 0.72), _dusk * 0.7)


func _on_landed(bonk: bool) -> void:
	if bonk:
		shake = 0.8
	bird_landed.emit(bonk)


func _on_splash() -> void:
	Ambient.burst(self, Vector2(bird.position.x, Terrain.WATER_Y), (_biome_to.water_top as Color), 26, 620.0)
	bird_splashed.emit()
