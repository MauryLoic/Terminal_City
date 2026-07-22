extends Node
## Warbot management: spawns a handful of lone robots scattered across
## the whole map at startup. Each destroyed warbot respawns 20 s later
## at a new random spot on the map (not tied to the player).

const WarbotScript := preload("res://scripts/warbot.gd")
const COUNT := 7
const RESPAWN_DELAY := 20.0
const HALF := 100.0


func _ready() -> void:
	for i in COUNT:
		_spawn()


func _spawn() -> void:
	var world := get_tree().current_scene.get_node_or_null("World")
	if world == null:
		return
	# Look for a spot out of the toxic water
	for attempt in 25:
		var x := randf_range(-HALF, HALF)
		var z := randf_range(-HALF, HALF)
		var h: float = world.get_height(x, z)
		if h <= world.WATER_Y + 1.0:
			continue
		var bot := CharacterBody3D.new()
		bot.set_script(WarbotScript)
		bot.position = Vector3(x, h + 0.5, z)
		get_tree().current_scene.add_child(bot)
		bot.died.connect(_on_warbot_died)
		return


func _on_warbot_died(_pos: Vector3) -> void:
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_spawn)
