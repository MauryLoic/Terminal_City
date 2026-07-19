extends Node
## Gestion des meutes de chauves-souris (par deux). Quand une meute est
## entièrement morte, une nouvelle paire apparaît 10 s plus tard, à une
## position aléatoire dans un rayon autour du joueur.

const BatScript := preload("res://scripts/bat.gd")
const RESPAWN_DELAY := 10.0
const PACK_COUNT := 2        # nombre de meutes (2 meutes = 4 chauves-souris)
const MIN_DIST := 22.0
const MAX_DIST := 40.0

var _next_pack_id := 1
var _packs := {}             # pack_id -> nombre de vivantes


func _ready() -> void:
	for i in PACK_COUNT:
		_spawn_pack()


func _spawn_pack() -> void:
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
	var base := Vector3(x, y, z)

	var pid := _next_pack_id
	_next_pack_id += 1
	_packs[pid] = 0

	for k in 2:
		var bat := CharacterBody3D.new()
		bat.set_script(BatScript)
		bat.pack_id = pid
		bat.home = base
		bat.position = base + Vector3(k * 3.0 - 1.5, randf_range(-0.5, 0.5), randf_range(-1.0, 1.0))
		get_tree().current_scene.add_child(bat)
		bat.died.connect(_on_bat_died.bind(pid))
		_packs[pid] += 1


func _on_bat_died(_pos: Vector3, pid: int) -> void:
	_packs[pid] = int(_packs.get(pid, 1)) - 1
	if _packs[pid] <= 0:
		_packs.erase(pid)
		get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_spawn_pack)
