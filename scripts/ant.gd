extends CharacterBody3D
## Mutant ant: small, fast ground critter of the wastelands. Weak
## (2 HP — two crowbar swings) but bites hard when it reaches you.
## Its remains drop medkit components: the low-risk healing source
## when you are hurt (hunt ants in melee, craft medkits).

signal died(pos: Vector3)

const WALK_SPEED := 1.6
const CHASE_SPEED := 4.5
const GRAVITY := 14.0
const AGGRO_RANGE := 7.0
const LOSE_RANGE := 30.0
const BITE_RANGE := 1.4
const BITE_DAMAGE := 4.0
const BITE_COOLDOWN := 1.2
const RemainsScript := preload("res://scripts/ant_remains.gd")

var home := Vector3.ZERO
var aggro := false

var _t := randf() * TAU
var _wander_target := Vector3.ZERO
var _wander_t := 0.0
var _bite_cd := 0.0
var _body: Node3D


func _ready() -> void:
	add_to_group("mob")
	set_meta("mat", "flesh")
	set_meta("hp", 2.0)
	set_meta("hp_max", 2.0)
	set_meta("bar_height", 0.8)
	set_meta("mob_name", "Mutant Ant")
	set_meta("aim_center", 0.26)
	set_meta("aim_half_w", 0.42)
	set_meta("aim_half_h", 0.34)
	set_meta("debris_color", Color(0.24, 0.11, 0.06))
	set_meta("debris_count", 6)
	set_meta("debris_size", 0.08)
	if home == Vector3.ZERO:
		home = global_position
	_wander_target = home
	_build_model()
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.3
	cs.shape = sp
	cs.position.y = 0.28
	add_child(cs)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_t += delta
	_bite_cd = maxf(_bite_cd - delta, 0.0)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var ppos: Vector3 = player.global_position
	var dist := global_position.distance_to(ppos)

	if not aggro and dist < AGGRO_RANGE:
		aggro = true
	elif aggro and dist > LOSE_RANGE:
		aggro = false

	# Destination: charge the player, or wander around the nest spot
	var target: Vector3
	var speed := WALK_SPEED
	if aggro:
		target = ppos
		speed = CHASE_SPEED
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(2.0, 5.0)
			_wander_target = home + Vector3(randf_range(-6.0, 6.0), 0, randf_range(-6.0, 6.0))
		target = _wander_target

	var to := target - global_position
	to.y = 0.0
	if to.length() > 0.5:
		var dir := to.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()

	var flat := Vector3(target.x, global_position.y, target.z)
	if global_position.distance_to(flat) > 0.6:
		look_at(flat, Vector3.UP)

	# Scuttle: quick little body wiggle
	_body.position.y = absf(sin(_t * 14.0)) * 0.02
	_body.rotation.y = sin(_t * 14.0) * 0.06

	# Bite on contact
	if aggro and dist < BITE_RANGE and _bite_cd == 0.0:
		_bite_cd = BITE_COOLDOWN
		player.take_damage(BITE_DAMAGE)
		Sfx.play_swing(global_position)


## Called by hit_effects for every hit taken: the ant fights back.
func on_hit() -> void:
	aggro = true


## Called by hit_effects right before destruction: squashed remains
## with medkit components, and the spawner schedules the respawn.
func on_destroyed() -> void:
	var remains := RigidBody3D.new()
	remains.set_script(RemainsScript)
	remains.position = global_position + Vector3(0, 0.3, 0)
	get_tree().current_scene.add_child(remains)
	died.emit(global_position)


func _build_model() -> void:
	var chitin := StandardMaterial3D.new()
	chitin.albedo_color = Color(0.3, 0.14, 0.08)
	chitin.roughness = 0.75
	_body = Node3D.new()
	add_child(_body)

	# Three body segments along -Z: abdomen, thorax, head
	for seg in [[0.2, Vector3(0, 0.26, 0.2)], [0.14, Vector3(0, 0.26, -0.02)], [0.11, Vector3(0, 0.28, -0.19)]]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = seg[0]
		sm.height = seg[0] * 1.7
		sm.material = chitin
		mi.mesh = sm
		mi.position = seg[1]
		_body.add_child(mi)

	# Six legs, three per side
	for side: float in [-1.0, 1.0]:
		for zoff: float in [-0.1, 0.0, 0.1]:
			var leg := MeshInstance3D.new()
			var lm := CylinderMesh.new()
			lm.top_radius = 0.012
			lm.bottom_radius = 0.012
			lm.height = 0.3
			lm.material = chitin
			leg.mesh = lm
			leg.position = Vector3(side * 0.16, 0.16, zoff)
			leg.rotation.z = side * 1.0
			_body.add_child(leg)

	# Antennae
	for side: float in [-1.0, 1.0]:
		var ant := MeshInstance3D.new()
		var am := CylinderMesh.new()
		am.top_radius = 0.006
		am.bottom_radius = 0.008
		am.height = 0.18
		am.material = chitin
		ant.mesh = am
		ant.position = Vector3(side * 0.05, 0.37, -0.26)
		ant.rotation.x = -0.9
		_body.add_child(ant)
