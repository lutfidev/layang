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


## Launch lip marking: a bright band along the ground surface plus three pulsing chevrons
## pointing up the ramp, so players read it as "touch here to be flung up".
static func launch_ramp(ci: CanvasItem, surface: PackedVector2Array, col: Color, edge: Color, t: float) -> void:
	if surface.size() < 2:
		return
	var band := PackedVector2Array(surface)
	for i in range(surface.size() - 1, -1, -1):
		band.append(surface[i] + Vector2(0, 26))
	ci.draw_colored_polygon(band, col)
	ci.draw_polyline(surface, edge, 4.0, true)
	var n := surface.size()
	for k in 3:
		var u := fmod(t * 0.9 + k / 3.0, 1.0)
		var i := clampi(int(u * (n - 1)), 0, n - 2)
		var dir := (surface[i + 1] - surface[i]).normalized().rotated(-0.15)
		var nrm := dir.orthogonal()
		var a := sin(u * PI)
		var tip := surface[i] + Vector2(0, -46) + dir * 30.0
		var back := tip - dir * 50.0
		# filled arrow head pointing up the ramp
		var c := Color(1, 1, 1, 0.95 * a)
		ci.draw_colored_polygon(PackedVector2Array([tip, back - nrm * 13.0, back + nrm * 13.0]), c)


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


## A standing beach wave: a rounded teal wall around `mid` whose foamy crest curls to the left
## (towards the oncoming bird), plus a soft shadow at its foot.
static func wave(ci: CanvasItem, mid: float, half_w: float, water_y: float, h: float, water: Color, foam_col: Color, t: float) -> void:
	shadow(ci, Vector2(mid, water_y + 6.0), half_w * 1.6, 12.0, 0.35)
	var top := water_y - h
	var wob := sin(t * 3.0) * 4.0
	# body: long gentle back slope on the right, steep curling face on the left
	var pts := PackedVector2Array()
	for i in 17:
		var u := float(i) / 16.0                       # 0 = right foot, 1 = crest
		var x := lerpf(mid + half_w * 2.2, mid + half_w * 0.1, u)
		var y := lerpf(water_y + 4.0, top, 1.0 - pow(1.0 - u, 2.2)) + sin(t * 4.0 + u * 7.0) * 2.0
		pts.append(Vector2(x, y))
	# the curl: crest -> overhanging tip -> back under -> left foot (simple, non-crossing outline)
	pts.append(Vector2(mid - half_w * 0.9, top + h * 0.25 + wob))
	pts.append(Vector2(mid - half_w * 0.55, top + h * 0.42))
	pts.append(Vector2(mid - half_w * 0.85, water_y + 4.0))
	ci.draw_colored_polygon(pts, water)
	# darker hollow under the curl
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(mid - half_w * 0.55, top + h * 0.42), Vector2(mid + half_w * 0.1, top + h * 0.3),
		Vector2(mid + half_w * 0.5, water_y + 4.0), Vector2(mid - half_w * 0.85, water_y + 4.0)]), water.darkened(0.22))
	var cc := Vector2(mid - half_w * 0.35, top + h * 0.12 + wob * 0.5)
	var cr := h * 0.13
	# lighter stripe on the back
	for i in 3:
		var y := lerpf(top + h * 0.3, water_y - 10.0, float(i) / 3.0)
		ci.draw_line(Vector2(mid + half_w * (0.4 + i * 0.4), y), Vector2(mid + half_w * (0.9 + i * 0.45), y + 8.0), water.lightened(0.25), 4.0, true)
	# foam along the crest and curl
	for i in 11:
		var ang := -PI * 0.1 - float(i) / 10.0 * PI
		var p := cc + Vector2(cos(ang), sin(ang)) * Vector2(half_w * 0.6, cr)
		ci.draw_circle(p, 12.0 - i * 0.5 + sin(t * 6.0 + i) * 1.5, foam_col)
	ci.draw_circle(Vector2(mid - half_w * 0.9, top + h * 0.25 + wob), 8.0, foam_col)
	for i in 6:
		var u := fmod(t * 0.8 + i / 6.0, 1.0)
		ci.draw_circle(Vector2(mid - half_w * 0.9 + u * half_w * 0.2, water_y - u * 30.0), 5.0 * (1.0 - u), Color(1, 1, 1, 0.8 * (1.0 - u)))


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
