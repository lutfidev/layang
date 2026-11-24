class_name World
extends Node2D
## The playable world: sky, parallax backdrop, terrain, collectibles, bird, camera, weather.
## Used by the game scene (player control) and by the menus (autopilot demo).

signal island_reached(k: int, biome: Dictionary)
signal item_collected(kind: int, pos: Vector2)
signal bird_landed(bonk: bool)
signal bird_splashed
signal bird_died(cause: String)        # "laut" | "monster" | "ombak" | "layangan"
signal wave_passed
signal hazard_spotted(cause: String)   # an island hazard (Canopy, ...) seen for the first time this run
signal hazard_passed(cause: String)
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
var wave: Wave
var kite: Kite
var canopy: Canopy
var _island_hazards: Array[Node2D] = []   # per-island hazards sharing update/safe_x_after/reset_current/CAUSE

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
var _ai_rng: RandomNumberGenerator
var _ai_react := -1.0


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
	wave = Wave.new()
	wave.terrain = terrain
	wave.sounds = hazards
	add_child(wave)
	kite = Kite.new()
	kite.terrain = terrain
	add_child(kite)
	canopy = Canopy.new()
	_add_island_hazard(canopy)
	wave.passed.connect(func():
		if not dead:
			wave_passed.emit())
	var shade := BirdShadow.new()
	shade.world = self
	add_child(shade)
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


func _add_island_hazard(h: Node2D) -> void:
	h.terrain = terrain
	add_child(h)
	_island_hazards.append(h)
	var cause: String = h.CAUSE
	h.spotted.connect(func():
		if hazards and not dead:
			hazard_spotted.emit(cause))
	h.passed.connect(func():
		if hazards and not dead:
			hazard_passed.emit(cause))


## Moves x forward until it is clear of every hazard and on gentle dry ground (respawn after "Lanjut").
func safe_x_after(x: float) -> float:
	# dry_ground_after always steps 120 px forward, so it runs once; hazard pushes land on dry ground
	x = _past_island_hazards(wave.safe_x_after(x))
	return _past_island_hazards(kite.safe_x_after(terrain.dry_ground_after(x)))


func _past_island_hazards(x: float) -> float:
	for _i in 8:
		var nx := kite.safe_x_after(x)
		for h in _island_hazards:
			nx = h.safe_x_after(nx)
		if absf(nx - x) < 0.5:
			break
		x = nx
	return x


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
	var hit_wave := wave.update(delta, bird.center(), x)
	var hit_kite := kite.update(delta, bird.center(), x)
	var hit_island := ""
	for h in _island_hazards:
		if h.update(delta, bird.center(), x, bird.on_ground) and hit_island == "":
			hit_island = h.CAUSE
	var over_water := terrain.is_water_at(x)
	var over_sea := terrain.is_sea_at(x)
	if not hazards:
		if over_water and bird.position.y > Terrain.WATER_Y - 30.0:
			bird.vel.y = -Bird.MAX_RISE
			bird.on_ground = false
		return
	if over_sea and not _in_sea:
		_jumps_left = monster.jumps_for_island(start_island + terrain.island_at(x))
		_jump_cd = 0.0
	_in_sea = over_sea
	_jump_cd -= delta
	if over_sea and _jumps_left > 0 and _jump_cd <= 0.0 and monster.state == "idle":
		var warn := SeaMonster.FIRST_WARN_TIME if terrain.island_at(x) == 0 else SeaMonster.WARN_TIME
		var half := SeaMonster.SPAN * 0.5
		var sea_end := x
		while terrain.is_sea_at(sea_end + 20.0) and sea_end < x + 8000.0:
			sea_end += 20.0
		# aim where the bird will be, but keep the whole arc over the water
		var tx := minf(x + bird.vel.x * (warn + 0.55), sea_end - half)
		if tx - half > x + 60.0:
			monster.arm(tx, warn)
			_jumps_left -= 1
			_jump_cd = warn + SeaMonster.JUMP_TIME + 0.5
	if monster.update(delta, bird.center()):
		_die("monster")
	elif hit_wave:
		_die("ombak")
	elif hit_kite:
		_die("layangan")
	elif hit_island != "":
		_die(hit_island)
	elif over_water and bird.center().y > Terrain.WATER_Y:
		_die("laut")


func _die(cause: String) -> void:
	dead = true
	if cause == "monster":
		shake = 1.2
		Sfx.play("chomp")
		Ambient.burst(self, bird.center(), Color("#ffffff"), 22, 520.0)
	elif cause == "ombak":
		shake = 1.0
		Sfx.play("splash")
		Ambient.burst(self, bird.center(), (_biome_to.water_top as Color), 30, 600.0)
	elif cause == "layangan":
		shake = 0.8
		Sfx.play("bonk")
		Ambient.burst(self, bird.center(), kite.hit_color, 26, 520.0)
	elif cause == "hutan":
		shake = 0.8
		Sfx.play("bonk")
		Ambient.burst(self, bird.center(), (_biome_to.hill_top as Color), 26, 480.0)
	bird_died.emit(cause)


## Removes any active sea monster and its remaining jumps for this sea (used by "Lanjut terbang").
func clear_hazards() -> void:
	monster.reset()
	wave.reset_current()
	for h in _island_hazards:
		h.reset_current()
	_jumps_left = 0
	_jump_cd = 0.0


## Autopilot (menu, shop, balance sim): skims ~70 px over the hills, cruises over the sea,
## climbs out of reach when the sea monster warns (after a seeded, sometimes slow reaction),
## and near a Pantai bay drops to the ground and flies through the wave's tube.
func _ai_hold() -> bool:
	if _ai_rng == null:
		_ai_rng = RandomNumberGenerator.new()
		_ai_rng.seed = run_seed * 31 + 7
	var b := bird
	var x := b.position.x
	var vx := maxf(b.vel.x, 200.0)
	var target: float
	if terrain.is_sea_at(x) or terrain.is_sea_at(x + vx * 0.6):
		target = Terrain.WATER_Y - 450.0
		if monster.state == "warn" and _ai_react < 0.0:
			_ai_react = 0.15 + pow(_ai_rng.randf(), 4.0) * 1.2
		if monster.state == "idle":
			_ai_react = -1.0
		var reacting := monster.state == "jump" or (monster.state == "warn" and monster.t >= _ai_react)
		if reacting and monster.target_x + SeaMonster.SPAN > x:
			target = Terrain.WATER_Y - SeaMonster.PEAK_ABOVE_WATER - 140.0
	else:
		var top := terrain.height_at(x)
		for i in range(1, 7):
			top = minf(top, terrain.height_at(x + vx * 0.12 * i))
		target = minf(top, Terrain.WATER_Y) - 70.0
		var i_can := terrain.canopy_at(x + 500.0)
		if i_can < 0:
			i_can = terrain.canopy_at(x)
		if i_can >= 0:
			# hutan tunnel: hold the corridor's centre line, a little ahead
			target = terrain.height_at(x + vx * 0.35) - Canopy.GAP * 0.5 + Bird.RADIUS
		var i_bay := terrain.next_bay(x)
		if i_bay >= 0:
			var bay: Dictionary = terrain.bays[i_bay]
			if x > float(bay.lip_x) - 900.0:
				if x + vx * 0.3 >= float(bay.water_x0):
					target = Terrain.WATER_Y - 160.0
				else:
					target = maxf(target + 50.0, Wave.TUBE_TOP + 90.0)
	var predicted := b.position.y + b.vel.y * 0.2
	return predicted > target


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
	kite.view_left = coins.view_left
	kite.view_right = coins.view_right
	for h in _island_hazards:
		h.view_left = coins.view_left
		h.view_right = coins.view_right


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



## Soft shadow under the bird on the ground or the water: smaller and darker the closer it flies.
class BirdShadow:
	extends Node2D
	var world: World

	func _ready() -> void:
		z_index = 1

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var b := world.bird
		var x := b.position.x
		var sea := world.terrain.is_water_at(x)
		var gy := Terrain.WATER_Y + 2.0 if sea else world.terrain.height_at(x)
		var h := gy - b.position.y
		if h > 900.0 or h < -4.0:
			return
		var k := clampf(h / 900.0, 0.0, 1.0)
		var rot := 0.0 if sea else atan(world.terrain.slope_at(x))
		Art.shadow(self, Vector2(x, gy + 2.0), 34.0 * (1.0 + k * 0.8), 8.0 * (1.0 + k * 0.4), 0.55 * (1.0 - k), rot)
