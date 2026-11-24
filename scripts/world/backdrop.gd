class_name Backdrop
extends Node2D
## Screen-space parallax silhouettes (3 layers per biome), cross-fading between islands.

var cam_x := 0.0
var biome_a: Dictionary = {}
var biome_b: Dictionary = {}
var blend := 1.0
var tint := Color.WHITE
var _noises := {}


func _process(_delta: float) -> void:
	queue_redraw()


func _noise(seed_value: int) -> FastNoiseLite:
	if not _noises.has(seed_value):
		var n := FastNoiseLite.new()
		n.seed = seed_value
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_octaves = 3
		n.frequency = 1.0
		_noises[seed_value] = n
	return _noises[seed_value]


static func _hash(k: int, s: int) -> float:
	return fposmod(sin(float(k) * 12.9898 + float(s) * 78.233) * 43758.5453, 1.0)


func _draw() -> void:
	if biome_b.is_empty():
		return
	var size := get_viewport_rect().size
	var la: Array = biome_a.get("layers", [])
	var lb: Array = biome_b.layers
	for i in lb.size():
		if blend < 1.0 and i < la.size():
			_draw_layer(la[i], 1.0, size)
		_draw_layer(lb[i], blend, size)


func _profile(L: Dictionary, u: float, base_y: float) -> float:
	var n := _noise(int(L.seed))
	var amp: float = L.amp
	match String(L.kind):
		"peaks":
			var r := 1.0 - absf(n.get_noise_1d(u * 0.0016))
			return base_y - amp * r * r * 1.1
		"islands":
			var v := n.get_noise_1d(u * 0.0022)
			return base_y - amp * maxf(0.0, v - 0.05) * 2.4
		"sea":
			return base_y + sin(u * 0.02) * amp
		"volcano":
			var ridge := base_y - amp * 0.25 * (0.5 + 0.5 * n.get_noise_1d(u * 0.002))
			var period := 2600.0
			var c := fposmod(u, period) - period * 0.5
			var cone := maxf(0.0, 1.0 - absf(c) / 700.0)
			cone = pow(cone, 1.6)
			var crater := maxf(0.0, 1.0 - absf(c) / 70.0) * 0.08
			return minf(ridge, base_y - amp * (cone - crater))
		_:
			return base_y - amp * (0.5 + 0.5 * n.get_noise_1d(u * 0.0025))


func _draw_layer(L: Dictionary, alpha: float, size: Vector2) -> void:
	if alpha <= 0.01:
		return
	var col: Color = L.color * tint
	col.a = alpha
	var off := cam_x * float(L.factor)
	var base_y := size.y * (float(L.y) * 0.85 - 0.04)
	var pts := PackedVector2Array()
	var sx := -24.0
	while sx <= size.x + 24.0:
		pts.append(Vector2(sx, _profile(L, sx + off, base_y)))
		sx += 16.0
	var edge := pts.duplicate()
	pts.append(Vector2(size.x + 24.0, size.y + 10.0))
	pts.append(Vector2(-24.0, size.y + 10.0))
	draw_colored_polygon(pts, col)
	var hi := col.lightened(0.18)
	hi.a = alpha * 0.6
	draw_polyline(edge, hi, 2.0, true)

	var t := Time.get_ticks_msec() / 1000.0
	var kind := String(L.kind)
	if kind == "cloudbank":
		var step := 70.0
		var k0 := int(floor((off - 120.0) / step))
		var k1 := int(ceil((off + size.x + 120.0) / step))
		for k in range(k0, k1):
			var x := k * step - off + _hash(k, int(L.seed)) * 30.0
			var y := _profile(L, x + off, base_y)
			draw_circle(Vector2(x, y + 10.0), 34.0 + _hash(k, 9) * 30.0, col)
	elif kind == "volcano":
		var period := 2600.0
		var k0 := int(floor((off - 800.0) / period))
		for k in range(k0, k0 + 3):
			var cx := k * period + period * 0.5 - off
			if cx < -600.0 or cx > size.x + 600.0:
				continue
			var top := base_y - float(L.amp) * 0.92
			for j in 6:
				var ph := fposmod(t * 0.12 + j / 6.0, 1.0)
				var p := Vector2(cx + ph * 160.0 + sin(ph * 6.0 + j) * 14.0, top - ph * 220.0)
				var sm := Color(0.35, 0.22, 0.35, alpha * 0.55 * (1.0 - ph))
				draw_circle(p, 18.0 + ph * 50.0, sm)
			draw_circle(Vector2(cx, top + 6.0), 22.0, Color(1.0, 0.55, 0.2, alpha * (0.35 + 0.15 * sin(t * 3.0))))
	elif kind == "sea":
		for j in 5:
			var yy := base_y + 18.0 + j * 22.0
			var seg := 60.0 + j * 20.0
			var x0 := -fposmod(off * (1.0 + j * 0.3) + j * 97.0, seg * 3.0)
			var lc := Color(1, 1, 1, alpha * 0.25)
			while x0 < size.x:
				draw_line(Vector2(x0, yy), Vector2(x0 + seg, yy), lc, 2.0)
				x0 += seg * 3.0

	var obj := String(L.get("obj", "none"))
	if obj == "none":
		return
	var every: float = L.obj_every
	var sc: float = L.obj_scale
	var s0 := int(floor((off - 200.0) / every))
	var s1 := int(ceil((off + size.x + 200.0) / every))
	for k in range(s0, s1):
		var h := _hash(k, int(L.seed))
		if h > 0.62:
			continue
		var x := k * every + _hash(k, int(L.seed) + 5) * every * 0.6 - off
		var y := _profile(L, x + off, base_y) + 6.0
		var s := sc * (0.75 + 0.5 * _hash(k, int(L.seed) + 9))
		var sway := sin(t * 1.4 + k)
		match obj:
			"palm": Art.palm(self, Vector2(x, y), s, col, sway)
			"round": Art.round_tree(self, Vector2(x, y), s, col)
			"tall": Art.tall_tree(self, Vector2(x, y), s, col)
			"fern": Art.fern(self, Vector2(x, y), s, col, sway)
			"dead": Art.dead_tree(self, Vector2(x, y), s, col)
			"hut": Art.hut(self, Vector2(x, y), s, col)
			"reeds": Art.reeds(self, Vector2(x, y), s, col, sway)
			"boat": Art.boat(self, Vector2(x, base_y + 2.0 + sin(t * 2.0 + k) * 3.0), s, col.darkened(0.25))
