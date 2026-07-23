extends Node
## Bat pack management (pairs). When a pack is
## entirely dead, a new pair appears 10 s later, at a
## random position within a radius around the player.

const BatScript := preload("res://scripts/bat.gd")
const BlueBatScript := preload("res://scripts/blue_bat.gd")
const MobRank := preload("res://scripts/mob_rank.gd")
const BLUE_EVERY := 6   # every N bat kills, a blue mini-boss appears
const RESPAWN_DELAY := 10.0
const PACK_COUNT := 2        # number of packs (2 packs = 4 bats)
const MIN_DIST := 22.0
const MAX_DIST := 40.0

var _next_pack_id := 1
var _kills := 0
var _packs := {}             # pack_id -> number alive


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

	# Pack members share a rank bracket: you fight a matched pair
	var pack_level := MobRank.roll_level(15, 30)
	for k in 2:
		var bat := CharacterBody3D.new()
		bat.set_script(BatScript)
		bat.level = maxi(1, pack_level + randi_range(-1, 1))
		bat.pack_id = pid
		bat.home = base
		bat.position = base + Vector3(k * 3.0 - 1.5, randf_range(-0.5, 0.5), randf_range(-1.0, 1.0))
		get_tree().current_scene.add_child(bat)
		bat.died.connect(_on_bat_died.bind(pid))
		_packs[pid] += 1


func _on_bat_died(_pos: Vector3, pid: int) -> void:
	# The killing spree counter: every BLUE_EVERY kills, summon the boss
	_kills += 1
	if _kills % BLUE_EVERY == 0:
		_spawn_blue_bat()
	_packs[pid] = int(_packs.get(pid, 1)) - 1
	if _packs[pid] <= 0:
		_packs.erase(pid)
		get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_spawn_pack)


## The Blue Vampire Bat: a lone mini-boss spawned near the player.
## Its death schedules nothing — it only comes from the kill counter.
func _spawn_blue_bat() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var world := get_tree().current_scene.get_node_or_null("World")
	var angle := randf_range(0.0, TAU)
	var dist := randf_range(20.0, 30.0)
	var x: float = clampf(player.global_position.x + cos(angle) * dist, -110.0, 110.0)
	var z: float = clampf(player.global_position.z + sin(angle) * dist, -110.0, 110.0)
	var y := 12.0
	if world:
		y = world.get_height(x, z) + randf_range(6.0, 9.0)
	var bat := CharacterBody3D.new()
	# The mini-boss scales with the player: always a real challenge
	var player_lv := 1
	if player and "level" in player:
		player_lv = int(player.level)
	bat.set_script(BlueBatScript)
	bat.level = clampi(player_lv + 8, 12, 60)
	bat.position = Vector3(x, y, z)
	bat.home = bat.position
	get_tree().current_scene.add_child(bat)
