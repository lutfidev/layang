class_name CoinField
extends Node2D
## All collectibles in one node: drawn in a single _draw pass and collected by distance.

signal collected(kind: int, pos: Vector2)

const COIN := 0
const SUN := 1

var items: Array = []        # [Vector2 pos, int kind, bool alive]
var view_left := 0.0
var view_right := 0.0
var _first := 0
var _bursts: Array = []      # [pos, age, kind]


func add_item(p: Vector2, kind: int) -> void:
	items.append([p, kind, true])


func check(bird_pos: Vector2, radius: float, magnet: float, delta: float) -> void:
	# advance first index past items far behind
	while _first < items.size() and items[_first][0].x < view_left - 400.0:
		_first += 1
	var i := _first
	while i < items.size():
		var it: Array = items[i]
		var p: Vector2 = it[0]
		if p.x > bird_pos.x + magnet + 100.0:
			break
		if it[2]:
			var d := p.distance_to(bird_pos)
			if magnet > 0.0 and d < magnet:
				it[0] = p.move_toward(bird_pos, delta * 1600.0)
				d = it[0].distance_to(bird_pos)
			var r := radius * (1.6 if it[1] == SUN else 1.0)
			if d < r:
				it[2] = false
				_bursts.append([it[0], 0.0, it[1]])
				collected.emit(it[1], it[0])
		i += 1


func _process(delta: float) -> void:
	for b in _bursts:
		b[1] += delta
	_bursts = _bursts.filter(func(b): return b[1] < 0.45)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var i := _first
	while i < items.size():
		var it: Array = items[i]
		var p: Vector2 = it[0]
		if p.x > view_right + 200.0:
			break
		if it[2] and p.x > view_left - 100.0:
			if it[1] == COIN:
				Art.coin(self, p + Vector2(0, sin(t * 3.0 + p.x * 0.05) * 4.0), 13.0, t)
			else:
				var pulse := 1.0 + 0.12 * sin(t * 6.0)
				draw_circle(p, 40.0 * pulse, Color(1.0, 0.8, 0.3, 0.18))
				draw_circle(p, 26.0 * pulse, Color(1.0, 0.86, 0.4, 0.35))
				Art.star(self, p, 22.0 * pulse, Color("#ffe066"), t)
				draw_circle(p, 9.0, Color("#fff8d6"))
		i += 1
	for b in _bursts:
		var age: float = b[1]
		var k := age / 0.45
		var col := Color(1.0, 0.9, 0.45, 1.0 - k) if b[2] == COIN else Color(1.0, 0.95, 0.7, 1.0 - k)
		draw_arc(b[0], 10.0 + k * 34.0, 0.0, TAU, 24, col, 3.0 * (1.0 - k) + 1.0, true)
		for j in 6:
			var a := TAU * j / 6.0 + age * 3.0
			draw_circle(b[0] + Vector2(cos(a), sin(a)) * (8.0 + k * 40.0), 3.0 * (1.0 - k), col)
