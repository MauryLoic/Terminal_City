extends Node
## Mutant ant management: spawns a bunch of lone ants scattered across
## the map. Each squashed ant respawns 15 s later at a new random spot.

const AntScript := preload("res://scripts/ant.gd")
const COUNT := 8
const RESPAWN_DELAY := 15.0
const HALF := 100.0


func _ready() -> void:
	for i in COUNT:
		_spawn()


func _spawn() -> void:
	var world := get_tree().current_scene.get_node_or_null("World")
	if world == null:
		return
	for attempt in 25:
		var x := randf_range(-HALF, HALF)
		var z := randf_range(-HALF, HALF)
		var h: float = world.get_height(x, z)
		if h <= world.WATER_Y + 1.0:
			continue
		var ant := CharacterBody3D.new()
		ant.set_script(AntScript)
		ant.position = Vector3(x, h + 0.4, z)
		get_tree().current_scene.add_child(ant)
		ant.died.connect(_on_ant_died)
		return


func _on_ant_died(_pos: Vector3) -> void:
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_spawn)
