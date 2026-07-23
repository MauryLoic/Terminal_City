extends Node
## Starting-zone population:
## - Inside the bunker: passive independent critters (small ants,
##   spiders, roaches — 1 HP each), respawning where they died.
## - Along the canyon path: a few regular Mutant Ants (the "medium"
##   tier guarding the way out).

const CritterScript := preload("res://scripts/critter.gd")
const AntScript := preload("res://scripts/ant.gd")
const MobRank := preload("res://scripts/mob_rank.gd")
const INTERIOR_COUNT := 8
const CORRIDOR_ANTS := 3
const RESPAWN_DELAY := 20.0
const SPECIES_CYCLE := ["small_ant", "spider", "roach"]

var _species_i := 0


func _ready() -> void:
	for i in INTERIOR_COUNT:
		_spawn_critter()
	for i in CORRIDOR_ANTS:
		_spawn_corridor_ant()


## Inside the bunker footprint (world coords: bunker center (0, -104),
## floor at y = 6).
func _spawn_critter() -> void:
	var critter := CharacterBody3D.new()
	critter.set_script(CritterScript)
	critter.species = SPECIES_CYCLE[_species_i % SPECIES_CYCLE.size()]
	critter.level = MobRank.roll_level(1, 5)     # starting-zone vermin
	_species_i += 1
	critter.position = Vector3(randf_range(-9.0, 5.0), 6.6, randf_range(-110.0, -98.0))
	get_tree().current_scene.add_child(critter)
	critter.died.connect(_on_critter_died)


func _on_critter_died(_pos: Vector3) -> void:
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_spawn_critter)


## Along the canyon path between the basin and the main bowl.
func _spawn_corridor_ant() -> void:
	var world := get_tree().current_scene.get_node_or_null("World")
	var x := randf_range(-2.5, 2.5)
	var z := randf_range(-88.0, -38.0)
	var y := 7.0
	if world:
		y = world.get_height(x, z) + 0.4
	var ant := CharacterBody3D.new()
	ant.set_script(AntScript)
	ant.ignores_sanctuary = true
	ant.level = MobRank.roll_level(8, 14)        # canyon guards
	ant.position = Vector3(x, y, z)
	get_tree().current_scene.add_child(ant)
	ant.died.connect(_on_corridor_ant_died)


func _on_corridor_ant_died(_pos: Vector3) -> void:
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_spawn_corridor_ant)
