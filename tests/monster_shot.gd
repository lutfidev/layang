extends Node2D
## Dev scene for eyeballing the sea monster: bird hovers high over the first sea while
## the monster warns and jumps. Use with `-- --shot=out.png --shot-delay=1.7`.

var world: World


func _ready() -> void:
	world = World.new()
	world.input_enabled = false
	world.run_seed = 4242
	add_child(world)
	var x := world.terrain.island_finish[0]
	while not world.terrain.is_sea_at(x):
		x += 10.0
	world.bird.position = Vector2(x + 20.0, Terrain.WATER_Y - 560.0)
	world.bird.on_ground = false


func _physics_process(_d: float) -> void:
	world.bird.position.y = Terrain.WATER_Y - 560.0
	world.bird.vel.y = 0.0
