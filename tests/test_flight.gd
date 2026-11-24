extends RefCounted
## Flight physics tests for Bird (hold = rise, release = glide, stamina, ceiling, ground).

var runner: Node
const DT := 1.0 / 120.0


func _make(seed_value: int) -> Array:
	var coins := CoinField.new()
	var terrain := Terrain.new()
	runner.add_child(coins)
	runner.add_child(terrain)
	terrain.setup(seed_value, 0, coins)
	var bird := Bird.new()
	bird.terrain = terrain
	runner.add_child(bird)
	return [terrain, bird]


func _air(seed_value: int, x: float, y: float) -> Bird:
	var b: Bird = _make(seed_value)[1]
	b.position = Vector2(x, y)
	b.vel = Vector2(Bird.SPEED_START, 0)
	b.on_ground = false
	return b


func _steps(b: Bird, seconds: float) -> void:
	for i in int(seconds / DT):
		b.step(DT)


func test_hold_rises() -> String:
	var b := _air(3, 0, -400)
	b.holding = true
	_steps(b, 0.5)
	if b.position.y >= -400:
		return "did not rise: y=%f" % b.position.y
	if b.vel.y < -Bird.MAX_RISE - 0.1:
		return "rise too fast: %f" % b.vel.y
	return ""


func test_release_glides() -> String:
	var b := _air(3, 0, -1000)
	b.holding = false
	for i in int(2.0 / DT):
		b.step(DT)
		if b.vel.y > Bird.MAX_FALL + 0.1:
			return "fell too fast: %f" % b.vel.y
	return ""


func test_stamina_drains_and_blocks() -> String:
	var b := _air(3, 0, -600)
	b.holding = true
	var guard := 0
	while b.stamina > 0.0 and guard < int(3.0 / DT):
		b.step(DT)
		guard += 1
	b.step(DT)
	if b.stamina > 0.01 or not b.exhausted or b.can_lift():
		return "stamina=%f exhausted=%s can_lift=%s" % [b.stamina, b.exhausted, b.can_lift()]
	return ""


func test_stamina_hysteresis() -> String:
	var b := _air(3, 0, -1400)
	b.holding = true
	_steps(b, 3.0)
	if not b.exhausted:
		return "not exhausted after 3s"
	# keep pressing: still must not lift until stamina >= RESUME
	var guard := 0
	while b.stamina < 0.15 and guard < 10000:
		b.step(DT)
		guard += 1
		if b.position.y > 0:
			b.position.y = -1400
	if not b.exhausted:
		return "resumed early at stamina=%f" % b.stamina
	while b.stamina < Bird.STAMINA_RESUME and guard < 20000:
		b.step(DT)
		guard += 1
		if b.position.y > 0:
			b.position.y = -1400
	b.step(DT)
	if b.exhausted:
		return "still exhausted at stamina=%f" % b.stamina
	return ""


func test_ceiling() -> String:
	var b := _air(3, 0, -600)
	b.holding = true
	for i in int(10.0 / DT):
		b.stamina = 1.0
		b.step(DT)
	if b.position.y < Bird.CEILING_HARD - 5:
		return "passed ceiling: %f" % b.position.y
	return ""


func test_ground_runs_not_dies() -> String:
	var parts := _make(3)
	var t: Terrain = parts[0]
	var b: Bird = parts[1]
	b.position = Vector2(-700, t.height_at(-700) - 60)
	b.vel = Vector2(Bird.SPEED_START, 0)
	b.on_ground = false
	b.holding = false
	var guard := 0
	while not b.on_ground and guard < 2000:
		b.step(DT)
		guard += 1
	if not b.on_ground:
		return "never touched ground"
	b.stamina = 0.0
	b.exhausted = true
	var x0 := b.position.x
	_steps(b, 1.0)
	if b.vel.x <= 0 or b.position.x <= x0:
		return "stopped on ground"
	if not b.on_ground:
		return "left ground without holding (y=%f h=%f)" % [b.position.y, t.height_at(b.position.x)]
	if b.stamina < Bird.STAMINA_REGEN_GROUND * 0.9:
		return "ground regen too slow: %f" % b.stamina
	return ""


func test_forward_speed_ramps() -> String:
	var b := _air(3, 0, -800)
	_steps(b, 0.5)
	if absf(b.vel.x - Bird.SPEED_START) > 25.0:
		return "start speed %f" % b.vel.x
	b.position = Vector2(Bird.SPEED_RAMP_X + 100.0, -900)
	b.on_ground = false
	_steps(b, 1.5)
	if absf(b.vel.x - Bird.SPEED_MAX) > 25.0:
		return "max speed %f" % b.vel.x
	b.fever = true
	b.position.y = -900
	_steps(b, 1.5)
	if absf(b.vel.x - Bird.SPEED_MAX * 1.3) > 30.0:
		return "fever speed %f" % b.vel.x
	return ""


func test_sleepy_cannot_lift() -> String:
	var b := _air(3, 0, -800)
	b.sleepy = true
	b.holding = true
	b.stamina = 0.5
	var y0 := b.position.y
	_steps(b, 0.5)
	if b.position.y <= y0:
		return "sleepy bird rose"
	if b.stamina > 0.5:
		return "sleepy stamina regen %f" % b.stamina
	return ""
