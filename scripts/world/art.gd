class_name Art
extends RefCounted
## Procedural vector art. Everything visual in Layang is drawn with these helpers,
## so the game ships with zero bitmap assets.


static func ellipse_points(c: Vector2, rx: float, ry: float, n: int = 20, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
	ci.draw_colored_polygon(ellipse_points(c, rx, ry, 22, rot), col)


static func leaf(ci: CanvasItem, base: Vector2, dir: float, length: float, width: float, droop: float, col: Color) -> void:
	# A curved, tapered leaf from base along angle `dir`, bending downward by `droop`.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var steps := 7
	for i in steps + 1:
		var t := float(i) / steps
		var ang := dir + droop * t * t
		var p := base + Vector2(cos(ang), sin(ang)) * length * t
		var w := sin(t * PI) * width
		var nrm := Vector2(-sin(ang), cos(ang))
		left.append(p + nrm * w)
		right.append(p - nrm * w)
	right.reverse()
	left.append_array(right)
	ci.draw_colored_polygon(left, col)


static func palm(ci: CanvasItem, base: Vector2, s: float, col: Color, sway: float = 0.0) -> void:
	var pts := PackedVector2Array()
	var h := 120.0 * s
	var lean := (18.0 + sway * 10.0) * s
	for i in 9:
		var t := float(i) / 8.0
		pts.append(base + Vector2(lean * t * t, -h * t))
	ci.draw_polyline(pts, col, 7.0 * s, true)
	var top := pts[pts.size() - 1]
	for a: float in [-2.9, -2.4, -1.9, -1.2, -0.7, -0.2, 0.3]:
		leaf(ci, top, a + sway * 0.08, 62.0 * s, 9.0 * s, 0.9 if a > -1.57 else -0.9, col)
	ellipse(ci, top + Vector2(2, 4) * s, 7 * s, 6 * s, col.darkened(0.15))


static func round_tree(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	ci.draw_rect(Rect2(base + Vector2(-4 * s, -40 * s), Vector2(8 * s, 40 * s)), col)
	ci.draw_circle(base + Vector2(0, -58 * s), 26 * s, col)
	ci.draw_circle(base + Vector2(-18 * s, -44 * s), 18 * s, col)
	ci.draw_circle(base + Vector2(18 * s, -46 * s), 19 * s, col)


static func tall_tree(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	ci.draw_rect(Rect2(base + Vector2(-5 * s, -170 * s), Vector2(10 * s, 170 * s)), col)
	ellipse(ci, base + Vector2(0, -178 * s), 52 * s, 24 * s, col)
	ellipse(ci, base + Vector2(-30 * s, -165 * s), 30 * s, 16 * s, col)
	ellipse(ci, base + Vector2(30 * s, -168 * s), 34 * s, 17 * s, col)
	ci.draw_line(base + Vector2(0, -110 * s), base + Vector2(26 * s, -130 * s), col, 4 * s)


static func fern(ci: CanvasItem, base: Vector2, s: float, col: Color, sway: float = 0.0) -> void:
	for a: float in [-2.6, -2.1, -1.57, -1.05, -0.55]:
		leaf(ci, base, a + sway * 0.05, 58.0 * s, 8.0 * s, 0.7 if a > -1.57 else -0.7, col)


static func dead_tree(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	_branch(ci, base, -PI / 2, 70.0 * s, 7.0 * s, 3, col)


static func _branch(ci: CanvasItem, p: Vector2, ang: float, length: float, w: float, depth: int, col: Color) -> void:
	var e := p + Vector2(cos(ang), sin(ang)) * length
	ci.draw_line(p, e, col, w, true)
	if depth <= 0:
		return
	_branch(ci, e, ang - 0.55, length * 0.62, w * 0.65, depth - 1, col)
	_branch(ci, e, ang + 0.45, length * 0.55, w * 0.6, depth - 1, col)


static func hut(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	# Lumbung-style rice barn: stilts, small body, big saddle roof.
	for x: float in [-16.0, 16.0]:
		ci.draw_rect(Rect2(base + Vector2(x * s - 2 * s, -26 * s), Vector2(4 * s, 26 * s)), col)
	ci.draw_rect(Rect2(base + Vector2(-20 * s, -44 * s), Vector2(40 * s, 18 * s)), col)
	var roof := PackedVector2Array([
		base + Vector2(-34 * s, -40 * s), base + Vector2(-10 * s, -92 * s),
		base + Vector2(0, -98 * s), base + Vector2(10 * s, -92 * s), base + Vector2(34 * s, -40 * s)])
	ci.draw_colored_polygon(roof, col)


static func reeds(ci: CanvasItem, base: Vector2, s: float, col: Color, sway: float = 0.0) -> void:
	for i in 6:
		var x := (i - 2.5) * 6.0 * s
		var hgt := (40.0 + (i * 37 % 23)) * s
		var tip := base + Vector2(x + sway * 8 * s + (i - 2.5) * 4 * s, -hgt)
		ci.draw_line(base + Vector2(x, 0), tip, col, 3.0 * s, true)
		if i % 2 == 0:
			ellipse(ci, tip + Vector2(0, 6 * s), 3 * s, 9 * s, col)


static func boat(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	# Small jukung outrigger with a sail.
	var hull := PackedVector2Array([base + Vector2(-34 * s, -6 * s), base + Vector2(34 * s, -6 * s),
		base + Vector2(24 * s, 4 * s), base + Vector2(-24 * s, 4 * s)])
	ci.draw_colored_polygon(hull, col)
	ci.draw_line(base + Vector2(0, -6 * s), base + Vector2(0, -50 * s), col, 2.5 * s)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(2 * s, -48 * s), base + Vector2(26 * s, -12 * s), base + Vector2(2 * s, -12 * s)]), col.lightened(0.25))
	ci.draw_line(base + Vector2(-30 * s, 8 * s), base + Vector2(30 * s, 8 * s), col, 2 * s)


static func cloud(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c, 30 * s, col)
	ci.draw_circle(c + Vector2(-34 * s, 10 * s), 22 * s, col)
	ci.draw_circle(c + Vector2(34 * s, 8 * s), 24 * s, col)
	ci.draw_circle(c + Vector2(12 * s, -14 * s), 24 * s, col)
	ci.draw_rect(Rect2(c + Vector2(-56 * s, 8 * s), Vector2(112 * s, 24 * s)), col)


static func gapura(ci: CanvasItem, base: Vector2, s: float, col: Color, accent: Color) -> void:
	# Candi bentar (split gate) — the island finish marker.
	for side: float in [-1.0, 1.0]:
		var x0 := side * 22.0 * s
		var w := 38.0 * s
		var steps := [[0.0, 52.0, 1.0], [52.0, 34.0, 0.82], [86.0, 26.0, 0.64], [112.0, 20.0, 0.44], [132.0, 16.0, 0.24]]
		for st in steps:
			var y0: float = st[0] * s
			var hh: float = st[1] * s
			var ww: float = w * st[2]
			var xx := x0 if side > 0 else x0 - ww
			ci.draw_rect(Rect2(base + Vector2(xx, -y0 - hh), Vector2(ww, hh)), col)
			ci.draw_rect(Rect2(base + Vector2(xx, -y0 - hh), Vector2(ww, 3 * s)), accent)
	ci.draw_circle(base + Vector2(0, -150 * s), 6 * s, accent)


static func rice(ci: CanvasItem, base: Vector2, s: float, col: Color, sway: float) -> void:
	for i in 5:
		var a := -PI / 2 + (i - 2) * 0.28 + sway * 0.1
		ci.draw_line(base, base + Vector2(cos(a), sin(a)) * 22 * s, col, 2.5 * s, true)


static func shell(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		pts.append(base + Vector2(cos(a) * 12 * s, sin(a) * 11 * s))
	ci.draw_colored_polygon(pts, col)
	for i in 4:
		var a := PI + PI * (i + 1) / 5.0
		ci.draw_line(base, base + Vector2(cos(a) * 11 * s, sin(a) * 10 * s), col.darkened(0.25), 1.5 * s)


static func mushroom(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	ci.draw_rect(Rect2(base + Vector2(-3 * s, -14 * s), Vector2(6 * s, 14 * s)), Color("#f6ecd8"))
	var cap := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		cap.append(base + Vector2(0, -12 * s) + Vector2(cos(a) * 13 * s, sin(a) * 11 * s))
	ci.draw_colored_polygon(cap, col)
	ci.draw_circle(base + Vector2(-4 * s, -18 * s), 2.2 * s, Color(1, 1, 1, 0.9))
	ci.draw_circle(base + Vector2(5 * s, -16 * s), 1.6 * s, Color(1, 1, 1, 0.9))


static func rock(ci: CanvasItem, base: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-16 * s, 2), base + Vector2(-10 * s, -14 * s),
		base + Vector2(4 * s, -18 * s), base + Vector2(16 * s, -6 * s), base + Vector2(14 * s, 2)]), col)


static func lantern(ci: CanvasItem, base: Vector2, s: float, col: Color, t: float) -> void:
	var glow := 0.55 + 0.25 * sin(t * 3.0 + base.x * 0.01)
	ci.draw_circle(base + Vector2(0, -22 * s), 20 * s, Color(col.r, col.g, col.b, 0.18 * glow))
	ci.draw_line(base, base + Vector2(0, -12 * s), Color(0.2, 0.15, 0.1), 2 * s)
	ellipse(ci, base + Vector2(0, -22 * s), 8 * s, 11 * s, col.lightened(0.2 * glow))


static func star(ci: CanvasItem, c: Vector2, r: float, col: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2 + rot + TAU * float(i) / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)


static func coin(ci: CanvasItem, c: Vector2, r: float, t: float) -> void:
	# A spinning golden "kepeng" coin with a square hole.
	var squash: float = abs(cos(t * 3.0 + c.x * 0.02))
	squash = 0.35 + 0.65 * squash
	ci.draw_circle(c, r * 1.5, Color(1.0, 0.85, 0.3, 0.16))
	ellipse(ci, c + Vector2(0, 2), r * squash, r, Color("#c7861a"))
	ellipse(ci, c, r * squash, r, Color("#ffd24a"))
	ellipse(ci, c, r * 0.72 * squash, r * 0.72, Color("#ffe58a"))
	var hw := r * 0.24 * squash
	ci.draw_rect(Rect2(c - Vector2(hw, r * 0.24), Vector2(hw * 2, r * 0.48)), Color("#c7861a"))


## Original chubby sea serpent head facing left: big eyes, big teeth, rounded fin crest.
## `mouth_open` 0..1 opens the jaw.
static func sea_monster(ci: CanvasItem, pos: Vector2, s: float, body: Color, belly: Color, mouth_open: float, t: float) -> void:
	var r := 58.0 * s
	var wob := sin(t * 9.0) * 2.0 * s
	# fin crest
	for i in 3:
		var fx := pos.x + (6.0 + i * 20.0) * s
		var fy := pos.y - r * 0.82 + i * 7.0 * s
		ci.draw_colored_polygon(PackedVector2Array([Vector2(fx - 13.0 * s, fy + 8.0 * s), Vector2(fx + 4.0 * s, fy - 26.0 * s + wob), Vector2(fx + 15.0 * s, fy + 10.0 * s)]), body.lightened(0.25))
	ellipse(ci, pos, r * 1.05, r, body.darkened(0.22))
	ellipse(ci, pos + Vector2(0, -r * 0.08), r * 0.95, r * 0.9, body)
	ellipse(ci, pos + Vector2(r * 0.1, -r * 0.55), r * 0.4, r * 0.18, Color(1, 1, 1, 0.2), 0.2)
	# mouth: dark wedge opening from a hinge at the cheek
	var open := mouth_open * 0.8
	var hinge := pos + Vector2(r * 0.25, r * 0.15)
	var up_dir := Vector2(-1, 0).rotated(-open * 0.5)
	var lo_dir := Vector2(-1, 0).rotated(open)
	var tip_up := hinge + up_dir * r * 1.35
	var tip_lo := hinge + lo_dir * r * 1.25
	ci.draw_colored_polygon(PackedVector2Array([hinge, tip_up, tip_lo]), Color("#5a1030"))
	# lower jaw
	ci.draw_colored_polygon(PackedVector2Array([hinge + Vector2(10.0 * s, 0), tip_lo, tip_lo + Vector2(r * 0.2, r * 0.32).rotated(open), hinge + Vector2(r * 0.3, r * 0.55)]), belly)
	# big teeth: upper row points down, lower row points up
	var up_n := up_dir.orthogonal()        # points "down" relative to the upper jaw
	var lo_n := -lo_dir.orthogonal()
	for i in 3:
		var u := 0.38 + i * 0.22
		var a := hinge + up_dir * r * 1.35 * u
		ci.draw_colored_polygon(PackedVector2Array([a - up_dir * 10.0 * s, a + up_n * -24.0 * s, a + up_dir * 10.0 * s]), Color.WHITE)
		var b := hinge + lo_dir * r * 1.25 * u
		ci.draw_colored_polygon(PackedVector2Array([b - lo_dir * 9.0 * s, b + lo_n * -18.0 * s, b + lo_dir * 9.0 * s]), Color.WHITE)
	# eye with angry brow, nostril, blush
	ci.draw_circle(pos + Vector2(-r * 0.95, -r * 0.2), 3.5 * s, body.darkened(0.45))
	var eye := pos + Vector2(-r * 0.15, -r * 0.42)
	ci.draw_circle(eye, 20.0 * s, Color.WHITE)
	ci.draw_circle(eye + Vector2(-5.0 * s, 2.0 * s), 11.0 * s, Color("#1b1430"))
	ci.draw_circle(eye + Vector2(-8.0 * s, -3.0 * s), 4.0 * s, Color.WHITE)
	ci.draw_line(eye + Vector2(-20.0 * s, -24.0 * s), eye + Vector2(12.0 * s, -16.0 * s), body.darkened(0.5), 6.0 * s)
	ci.draw_circle(pos + Vector2(r * 0.3, -r * 0.05), 9.0 * s, Color(1.0, 0.45, 0.6, 0.45))


## A circle shaded like a ball lit from above: darker rim at the bottom, soft highlight on top.
static func ball(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(c, r, col.darkened(0.22))
	ci.draw_circle(c + Vector2(0, -r * 0.08), r * 0.9, col)
	ellipse(ci, c + Vector2(-r * 0.2, -r * 0.45), r * 0.42, r * 0.22, Color(1, 1, 1, 0.22), -0.3)


## Soft ground shadow: a few stacked translucent ellipses.
static func shadow(ci: CanvasItem, c: Vector2, rx: float, ry: float, alpha: float, rot: float = 0.0) -> void:
	for i in 3:
		var k := 1.0 - i * 0.28
		ellipse(ci, c, rx * k, ry * k, Color(0.05, 0.02, 0.12, alpha * 0.4), rot)


## Bubbling foam on a bay's surface: the warning before a wave. `density` 0..1 grows as it nears.
static func foam(ci: CanvasItem, x0: float, x1: float, y: float, density: float, t: float) -> void:
	var n := int(6 + 18 * density)
	for i in n:
		var ph := fmod(t * (1.2 + 0.4 * sin(i * 1.7)) + i * 0.41, 1.0)
		var u := fmod(i * 0.618, 1.0)
		var bx := lerpf(x0 + 10.0, x1 - 10.0, u) + sin(t * 3.0 + i) * 6.0
		var by := y + 2.0 - ph * (14.0 + 26.0 * density)
		var r := (4.0 + 7.0 * density) * (1.0 - ph * 0.6)
		ci.draw_circle(Vector2(bx, by), r, Color(1, 1, 1, (0.55 + 0.4 * density) * (1.0 - ph)))
	ci.draw_line(Vector2(x0, y + 1.0), Vector2(x1, y + 1.0), Color(1, 1, 1, 0.5 + 0.4 * density), 5.0)


## Left (face) edge of the curling wall at height y: straight above the tube mouth, then leaning
## further out over the bird's side the higher it gets (the overhang under the curl).
static func _wave_left(x0: float, y: float, crest_y: float, tube_top: float, over: float) -> float:
	if y >= tube_top or crest_y >= tube_top - 1.0:
		return x0
	return x0 - over * pow((tube_top - y) / (tube_top - crest_y), 1.7)


## Back edge of the wall: narrow at the crest, at x1 by the water (never past the hit column).
static func _wave_right(x0: float, x1: float, y: float, crest_y: float, water_y: float) -> float:
	var s := clampf((y - crest_y) / maxf(1.0, water_y - crest_y), 0.0, 1.0)
	return lerpf(x1 - (x1 - x0) * 0.3, x1, sqrt(s))


## Body colour at relative depth s (0 = crest, 1 = water line): bright and see-through at the top,
## deep and dark at the foot, so the wall reads as a thick, round mass of water.
static func _wave_col(s: float, water: Color, water_top: Color) -> Color:
	if s < 0.3:
		return water_top.lerp(Color.WHITE, 0.12).lerp(water.lightened(0.12), s / 0.3)
	return water.lightened(0.12).lerp(water.darkened(0.42), (s - 0.3) / 0.7)


## The giant curling beach wave, the part behind the bird: a fainter copy receding into the distance,
## the graded wall with its overhanging face, the curl at the crest, highlights running up the face,
## the dark tube under the curl (mouth rim on the left, light at the far end) and foam at its foot.
static func wave_wall(ci: CanvasItem, x0: float, x1: float, water_y: float, crest_y: float, tube_top: float, water: Color, water_top: Color, t: float) -> void:
	var h := water_y - crest_y
	var over := minf(220.0, h * 0.12)
	var formed := crest_y < tube_top - 40.0
	var bands := 30
	# depth: the same wall further away (up and to the right), paler, only above the tube's roof
	if formed:
		var off := Vector2(80.0, -70.0)
		var far := water_top.lerp(Color(0.92, 0.97, 1.0), 0.45)
		for k in bands:
			var ya := lerpf(crest_y, tube_top, float(k) / bands)
			var yb := lerpf(crest_y, tube_top, float(k + 1) / bands)
			var pts := PackedVector2Array([
				Vector2(_wave_left(x0, ya, crest_y, tube_top, over), ya) + off,
				Vector2(_wave_right(x0, x1, ya, crest_y, water_y), ya) + off,
				Vector2(_wave_right(x0, x1, yb, crest_y, water_y), yb) + off,
				Vector2(_wave_left(x0, yb, crest_y, tube_top, over), yb) + off])
			ci.draw_colored_polygon(pts, Color(far, 0.55 - 0.3 * float(k) / bands))
	shadow(ci, Vector2((x0 + x1) * 0.5, water_y + 8.0), (x1 - x0) * 0.9, 14.0, 0.4)
	# the wall, band by band with a vertical gradient
	for k in bands:
		var ya := lerpf(crest_y, water_y + 6.0, float(k) / bands)
		var yb := lerpf(crest_y, water_y + 6.0, float(k + 1) / bands)
		var ca := _wave_col(float(k) / bands, water, water_top)
		var cb := _wave_col(float(k + 1) / bands, water, water_top)
		ci.draw_polygon(PackedVector2Array([
			Vector2(_wave_left(x0, ya, crest_y, tube_top, over), ya),
			Vector2(_wave_right(x0, x1, ya, crest_y, water_y), ya),
			Vector2(_wave_right(x0, x1, yb, crest_y, water_y), yb),
			Vector2(_wave_left(x0, yb, crest_y, tube_top, over), yb)]),
			PackedColorArray([ca, ca, cb, cb]))
	# shading on the back: the wall is round, so its far side turns away from the light
	for k in 4:
		var y := lerpf(crest_y + h * 0.1, water_y - 20.0, float(k) / 4.0)
		var xr := _wave_right(x0, x1, y, crest_y, water_y)
		ci.draw_line(Vector2(xr - 10.0 - k * 2.0, y), Vector2(xr - 10.0 - k * 2.0, y + h * 0.2), Color(0, 0, 0.1, 0.06), 18.0)
	# highlights that run up the face, following its lean
	if formed:
		for k in 6:
			var u := fmod(t * 0.3 + k * 0.29, 1.0)
			var yc := lerpf(tube_top - 30.0, crest_y + h * 0.12, u)
			var line := PackedVector2Array()
			for j in 9:
				var y := yc - 70.0 + j * 17.5
				if y > tube_top - 10.0 or y < crest_y + 20.0:
					continue
				line.append(Vector2(_wave_left(x0, y, crest_y, tube_top, over) + 14.0 + k * 19.0, y))
			if line.size() >= 2:
				ci.draw_polyline(line, Color(1, 1, 1, 0.3 * sin(PI * u)), 4.0, true)
	# the curl at the crest: a solid hook of water with a hollow and a foam rim, hanging towards the bird
	var r := clampf(h * 0.07, 16.0, 110.0)
	var cc := Vector2(_wave_left(x0, crest_y, crest_y, tube_top, over) + r * 0.9, crest_y + r)
	ellipse(ci, cc, r * 1.05, r, water_top.lerp(Color.WHITE, 0.1))
	ellipse(ci, cc + Vector2(r * 0.15, r * 0.1), r * 0.55, r * 0.5, water.darkened(0.3))
	for i in 14:
		var a := -PI * 0.5 - float(i) / 13.0 * PI * 1.15
		var p := cc + Vector2(cos(a), sin(a)) * r * 1.02
		ci.draw_circle(p, r * (0.24 - i * 0.008) + sin(t * 6.0 + i) * 1.5, Color.WHITE)
	# foam cap along the crest line
	var xa := cc.x
	var xb := _wave_right(x0, x1, crest_y, crest_y, water_y)
	for i in 8:
		var u := float(i) / 7.0
		ci.draw_circle(Vector2(lerpf(xa, xb, u), crest_y + 4.0 + sin(t * 5.0 + i) * 2.0), r * 0.22 * (1.0 - u * 0.5), Color(1, 1, 1, 0.9))
	# the tube under the curl
	if formed:
		var cy := (tube_top + water_y) * 0.5
		var ry := (water_y - tube_top) * 0.5
		var xm := (x0 + x1) * 0.5
		var c_in := water.darkened(0.25)
		var c_deep := water.darkened(0.55)
		var c_end := water_top.lerp(Color.WHITE, 0.25)
		ci.draw_polygon(PackedVector2Array([Vector2(x0, tube_top), Vector2(xm, tube_top), Vector2(xm, water_y), Vector2(x0, water_y)]),
			PackedColorArray([c_in, c_deep, c_deep, c_in]))
		ci.draw_polygon(PackedVector2Array([Vector2(xm, tube_top), Vector2(x1, tube_top), Vector2(x1, water_y), Vector2(xm, water_y)]),
			PackedColorArray([c_deep, c_end, c_end, c_deep]))
		# rings of spinning water inside the tube (they make it read as a cylinder)
		for k in 6:
			var u := fmod(float(k) / 6.0 - t * 0.55 + 10.0, 1.0)
			var x := lerpf(x0 + 8.0, x1 - 8.0, u)
			var arc := PackedVector2Array()
			for j in 13:
				var a := -PI * 0.5 + float(j) / 12.0 * PI
				arc.append(Vector2(x + cos(a) * 16.0, cy + sin(a) * ry * 0.94))
			ci.draw_polyline(arc, Color(water_top, 0.22 * sin(PI * u)), 5.0, true)
		# light at the far end of the tube
		ellipse(ci, Vector2(x1, cy), 26.0, ry * 0.86, Color(1, 1, 1, 0.22))
		ellipse(ci, Vector2(x1, cy), 14.0, ry * 0.6, Color(1, 1, 1, 0.25))
		# the mouth's rim on the bird's side
		var rim := PackedVector2Array()
		for j in 17:
			var a := PI * 0.5 + float(j) / 16.0 * PI
			rim.append(Vector2(x0 + 6.0 + cos(a) * 26.0, cy + sin(a) * ry))
		ci.draw_polyline(rim, Color(water_top.lerp(Color.WHITE, 0.4), 0.85), 8.0, true)
	# churning foam at the wall's foot
	for i in 12:
		var u := float(i) / 11.0
		var x := lerpf(x0 - 30.0, x1 + 20.0, u) + sin(t * 2.5 + i * 1.3) * 6.0
		ci.draw_circle(Vector2(x, water_y - 2.0 + sin(t * 4.0 + i) * 3.0), 10.0 + 4.0 * sin(t * 3.0 + i * 2.0), Color(1, 1, 1, 0.85))


## The part of the curling wave in front of the bird: the thick foamy lip rolling along the tube's
## roof (its lower edge is the deadly line), a faint glaze of water over the tube so the bird looks
## inside it, drops falling off the lip at the mouth and spray spitting out of the far end.
static func wave_lip(ci: CanvasItem, x0: float, x1: float, water_y: float, crest_y: float, tube_top: float, water: Color, water_top: Color, t: float) -> void:
	if crest_y >= tube_top - 40.0:
		return
	var ry := (water_y - tube_top) * 0.5
	var cy := tube_top + ry
	ci.draw_rect(Rect2(x0, tube_top, x1 - x0, water_y - tube_top), Color(water_top, 0.1))
	# the lip: a rolled band, bright on top, foam along its lower edge
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var x := lerpf(x0 - 34.0, x1 + 8.0, float(i) / n)
		top.append(Vector2(x, tube_top - 48.0 + sin(t * 3.0 + i * 0.8) * 3.0))
		bot.append(Vector2(x, tube_top - 8.0))
	var band := top.duplicate()
	var cols := PackedColorArray()
	for i in top.size():
		cols.append(water_top.lerp(Color.WHITE, 0.2))
	for i in range(bot.size() - 1, -1, -1):
		band.append(bot[i])
		cols.append(water.lightened(0.05))
	ci.draw_polygon(band, cols)
	for i in n + 1:
		var p := bot[i]
		ci.draw_circle(p + Vector2(sin(t * 5.0 + i) * 3.0, -2.0), 11.0 + sin(t * 7.0 + i * 1.9) * 2.0, Color.WHITE)
	ci.draw_polyline(top, Color(1, 1, 1, 0.7), 4.0, true)
	# drops falling off the lip at the mouth
	for k in 7:
		var u := fmod(t * 1.3 + k / 7.0, 1.0)
		var p := Vector2(x0 - 28.0 + sin(k * 2.1) * 10.0, tube_top - 4.0 + u * 110.0)
		ci.draw_circle(p, 6.0 * (1.0 - u * 0.7), Color(1, 1, 1, 0.8 * (1.0 - u)))
	# spray spitting out of the far end of the tube
	for k in 12:
		var u := fmod(t * 1.1 + k * 0.137, 1.0)
		var p := Vector2(x1 + u * 170.0, cy + sin(k * 2.3) * ry * 0.6 - u * 50.0)
		ci.draw_circle(p, 8.0 * (1.0 - u), Color(1, 1, 1, 0.7 * (1.0 - u)))


static func kite(ci: CanvasItem, c: Vector2, hw: float, hh: float, col: Color, accent: Color) -> void:
	# Layangan: a diamond with two-tone halves and its cross sticks.
	var top := c + Vector2(0, -hh)
	var bottom := c + Vector2(0, hh)
	var left := c + Vector2(-hw, -hh * 0.2)
	var right := c + Vector2(hw, -hh * 0.2)
	ci.draw_colored_polygon(PackedVector2Array([top, left, bottom]), col)
	ci.draw_colored_polygon(PackedVector2Array([top, right, bottom]), col.lightened(0.18))
	ci.draw_colored_polygon(PackedVector2Array([top, c + Vector2(-hw * 0.45, -hh * 0.5), c + Vector2(0, -hh * 0.2), c + Vector2(hw * 0.45, -hh * 0.5)]), accent)
	ci.draw_line(top, bottom, col.darkened(0.45), 2.0, true)
	ci.draw_line(left, right, col.darkened(0.45), 2.0, true)
	ci.draw_polyline(PackedVector2Array([top, right, bottom, left, top]), col.darkened(0.3), 2.0, true)


static func kite_tail(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	# the deadly part: a dark cord with big bows so it reads from a screen away
	ci.draw_polyline(pts, col.darkened(0.55), 3.0, true)
	for i in range(1, pts.size()):
		var p := pts[i]
		var bow := col if i % 2 == 0 else col.darkened(0.25)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-12, -7), p, p + Vector2(-12, 7)]), bow)
		ci.draw_colored_polygon(PackedVector2Array([p + Vector2(12, -7), p, p + Vector2(12, 7)]), bow)
		ci.draw_circle(p, 2.5, col.darkened(0.55))


## A villager flying a kite; returns the hand position (where the string starts).
static func villager(ci: CanvasItem, base: Vector2, s: float, col: Color) -> Vector2:
	ci.draw_line(base + Vector2(-5, 0) * s, base + Vector2(-2, -20) * s, col, 4.0 * s, true)
	ci.draw_line(base + Vector2(5, 0) * s, base + Vector2(2, -20) * s, col, 4.0 * s, true)
	ci.draw_line(base + Vector2(0, -20) * s, base + Vector2(0, -40) * s, col, 6.0 * s, true)
	var hand := base + Vector2(12, -46) * s
	ci.draw_line(base + Vector2(0, -36) * s, hand, col, 3.5 * s, true)
	ci.draw_circle(base + Vector2(0, -47) * s, 6.0 * s, col)
	# caping (conical farmer's hat)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-14, -49) * s, base + Vector2(0, -60) * s, base + Vector2(14, -49) * s]), Color("#e8c46a"))
	return hand
