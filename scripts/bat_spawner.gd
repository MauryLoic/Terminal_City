extends Node
## Gestion des chauves-souris : en fait apparaître au démarrage, et
## quand l'une meurt, en refait apparaître une 10 s plus tard, à une
## position aléatoire dans un rayon autour du joueur.

const BatScript := preload("res://scripts/bat.gd")
const RESPAWN_DELAY := 10.0
const BAT_COUNT := 2
const MIN_DIST := 18.0
const MAX_DIST := 35.0


func _ready() -> void:
	for i in BAT_COUNT:
		_spawn_bat()


func _spawn_bat() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var world := get_tree().current_scene.get_node_or_null("World")

	var angle := randf_range(0.0, TAU)
	var dist := randf_range(MIN_DIST, MAX_DIST)
	var x: float = clampf(player.global_position.x + cos(angle) * dist, -110.0, 110.0)
	var z: float = clampf(player.global_position.z + sin(angle) * dist, -110.0, 110.0)
	var y := 10.0
	if world:
		y = world.get_height(x, z) + randf_range(5.0, 8.0)

	var bat := CharacterBody3D.new()
	bat.set_script(BatScript)
	bat.position = Vector3(x, y, z)
	get_tree().current_scene.add_child(bat)
	bat.died.connect(_on_bat_died)


func _on_bat_died(_pos: Vector3) -> void:
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_spawn_bat)
