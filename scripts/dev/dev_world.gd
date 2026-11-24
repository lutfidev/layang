extends Node2D
## Dev scene: autopilot world for screenshots / balancing. Flags: --island=N --sim
func _ready() -> void:
	var w := World.new()
	w.autoplay = true
	w.start_island = Game.dev_int("island", 0)
	w.sun_progress = 0.85
	add_child(w)
	if Game.dev.has("sim"):
		var t := 0.0
		while t < float(Game.dev.get("sim-time", "60")):
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		print("SIM x=", w.bird.position.x, " island=", w.current_island, " speed=", w.bird.speed())
		get_tree().quit()
