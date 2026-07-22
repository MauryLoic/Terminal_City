extends CharacterBody3D
## Warbot: lone combat robot of the wastelands (Neocron-inspired).
## Spawns scattered across the whole map. Wanders around its drop point;
## turns aggressive when the player gets close (or shoots it), walks
## toward the player and fires plasma bolts from mid range. On death it
## leaves a lootable wreck containing ammo-crafting resources.

signal died(pos: Vector3)

const WALK_SPEED := 2.2
const CHASE_SPEED := 3.4
const GRAVITY := 14.0
const AGGRO_RANGE := 12.0
const LOSE_RANGE := 50.0
const FIRE_RANGE := 26.0
const STOP_RANGE := 11.0
const PlasmaScript := preload("res://scripts/plasma_bolt.gd")
const WreckScript := preload("res://scripts/warbot_wreck.gd")

var home := Vector3.ZERO
var aggro := false

var _t := randf() * TAU
var _wander_target := Vector3.ZERO
var _wander_t := 0.0
var _shoot_t := randf_range(2.0, 4.0)
var _body: Node3D
var _plate: StandardMaterial3D


func _ready() -> void:
	add_to_group("mob")
	set_meta("mat", "metal")
	set_meta("hp", 12.0)
	set_meta("hp_max", 12.0)
	set_meta("bar_height", 3.0)
	set_meta("debris_color", Color(0.35, 0.37, 0.34))
	set_meta("debris_count", 14)
	set_meta("debris_size", 0.2)
	if home == Vector3.ZERO:
		home = global_position
	_wander_target = home
	_build_model()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 2.6, 0.8)
	cs.shape = box
	cs.position.y = 1.3
	add_child(cs)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_t += delta

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var ppos: Vector3 = player.global_position
	var dist := global_position.distance_to(ppos)

	# State transitions: proximity aggro, disengage at long range
	if not aggro and dist < AGGRO_RANGE:
		aggro = true
	elif aggro and dist > LOSE_RANGE:
		aggro = false

	# Destination: chase the player (hold position at firing distance),
	# or slow wander around the drop point
	var target: Vector3
	var speed := WALK_SPEED
	if aggro:
		speed = CHASE_SPEED
		target = ppos if dist > STOP_RANGE else global_position
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(3.0, 6.0)
			_wander_target = home + Vector3(randf_range(-8.0, 8.0), 0, randf_range(-8.0, 8.0))
		target = _wander_target

	var to := target - global_position
	to.y = 0.0
	if to.length() > 0.8:
		var dir := to.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()

	# Face the player while aggressive, the walking direction otherwise
	var face := ppos if aggro else target
	var flat := Vector3(face.x, global_position.y, face.z)
	if global_position.distance_to(flat) > 1.0:
		look_at(flat, Vector3.UP)

	# Heavy mechanical gait: slight torso bob
	_body.position.y = sin(_t * 6.0) * 0.04

	# Plasma fire: only while aggressive and in range
	if aggro:
		_shoot_t -= delta
		if _shoot_t <= 0.0 and dist < FIRE_RANGE:
			_shoot_t = randf_range(2.5, 4.0)
			_fire_plasma(ppos)


func _fire_plasma(target: Vector3) -> void:
	var bolt := Area3D.new()
	bolt.set_script(PlasmaScript)
	var origin := global_position + Vector3(0, 2.0, 0)
	var dir := (target + Vector3(0, 0.9, 0) - origin).normalized()
	bolt.direction = dir
	bolt.position = origin + dir * 1.0
	get_tree().current_scene.add_child(bolt)
	Sfx.play_laser(origin)


## Called by hit_effects for every bullet taken: flash and aggro.
func on_hit() -> void:
	aggro = true
	_plate.albedo_color = Color(0.9, 0.4, 0.3)
	var tw := create_tween()
	tw.tween_property(_plate, "albedo_color", Color(0.42, 0.45, 0.4), 0.25)


## Called by hit_effects right before destruction: the robot collapses
## into a lootable wreck, and the spawner is notified for the respawn.
func on_destroyed() -> void:
	var wreck := RigidBody3D.new()
	wreck.set_script(WreckScript)
	wreck.position = global_position + Vector3(0, 0.6, 0)
	get_tree().current_scene.add_child(wreck)
	died.emit(global_position)


func _build_model() -> void:
	_plate = StandardMaterial3D.new()
	_plate.albedo_color = Color(0.42, 0.45, 0.4)
	_plate.roughness = 0.5
	_plate.metallic = 0.5
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.16, 0.17, 0.18)
	dark.roughness = 0.7
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1, 0.15, 0.1)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1, 0.1, 0.05)
	eye_mat.emission_energy_multiplier = 2.5
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Legs and hips (static: the walk is sold by the torso bob)
	for side: float in [-1.0, 1.0]:
		_box(dark, Vector3(0.28, 1.1, 0.36), Vector3(side * 0.35, 0.55, 0))
		_box(dark, Vector3(0.34, 0.14, 0.5), Vector3(side * 0.35, 0.07, -0.04))
	_box(dark, Vector3(1.0, 0.3, 0.6), Vector3(0, 1.25, 0))

	# Articulated body: torso, head, cannon, antenna
	_body = Node3D.new()
	add_child(_body)
	_box(_plate, Vector3(1.25, 0.9, 0.8), Vector3(0, 1.85, 0), _body)
	_box(_plate, Vector3(0.5, 0.35, 0.5), Vector3(0, 2.48, 0), _body)
	var eye := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.07
	em.height = 0.14
	em.material = eye_mat
	eye.mesh = em
	eye.position = Vector3(0, 2.48, -0.27)
	_body.add_child(eye)
	# Shoulder cannon pointing forward (-Z)
	var cannon := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.09
	cm.height = 0.9
	cm.material = dark
	cannon.mesh = cm
	cannon.position = Vector3(0.55, 2.05, -0.35)
	cannon.rotation.x = PI / 2
	_body.add_child(cannon)
	_box(dark, Vector3(0.04, 0.5, 0.04), Vector3(-0.5, 2.6, 0.2), _body)


func _box(mat: StandardMaterial3D, size: Vector3, pos: Vector3, parent: Node3D = null) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	(parent if parent else self).add_child(mi)
