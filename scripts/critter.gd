extends CharacterBody3D
## Small starting-zone critter: Small Ant, Small Spider or Roach (like
## the Neocron sewers). COMPLETELY PASSIVE and INDEPENDENT: it never
## attacks, and killing one does not alert the others — it only panics
## and flees briefly when hit. 1 HP: dies to a single knife swing.
## Its remains drop medkit components (the level-1 healing economy).

signal died(pos: Vector3)

const WANDER_SPEED := 1.0
const FLEE_SPEED := 3.5
const GRAVITY := 14.0
const RemainsScript := preload("res://scripts/critter_remains.gd")
const MobRank := preload("res://scripts/mob_rank.gd")

const SPECIES := {
	"small_ant": {"name": "Small Ant", "color": Color(0.32, 0.16, 0.09)},
	"spider": {"name": "Small Spider", "color": Color(0.15, 0.13, 0.12)},
	"roach": {"name": "Roach", "color": Color(0.35, 0.2, 0.08)},
}

var level := 1   # set by the spawner before add_child
var species := "roach"
var home := Vector3.ZERO

var _t := randf() * TAU
var _wander_target := Vector3.ZERO
var _wander_t := 0.0
var _flee_t := 0.0
var _body: Node3D


func _ready() -> void:
	add_to_group("mob")
	var info: Dictionary = SPECIES.get(species, SPECIES["roach"])
	set_meta("mat", "flesh")
	MobRank.apply(self, info.name, level, 1.0, 25)
	set_meta("bar_height", 0.55)
	set_meta("aim_center", 0.14)
	set_meta("aim_half_w", 0.3)
	set_meta("aim_half_h", 0.22)
	set_meta("debris_color", info.color)
	set_meta("debris_count", 5)
	set_meta("debris_size", 0.06)
	if home == Vector3.ZERO:
		home = global_position
	_wander_target = home
	_build_model(info.color)
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.22
	cs.shape = sp
	cs.position.y = 0.18
	add_child(cs)


func _physics_process(delta: float) -> void:
	_t += delta
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var target: Vector3
	var speed := WANDER_SPEED
	if _flee_t > 0.0:
		# Panic: scurry away from the player, then calm down
		_flee_t -= delta
		speed = FLEE_SPEED
		var player := get_tree().get_first_node_in_group("player")
		if player:
			var away: Vector3 = global_position - player.global_position
			away.y = 0.0
			target = global_position + away.normalized() * 4.0
		else:
			target = _wander_target
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = randf_range(2.0, 5.0)
			_wander_target = home + Vector3(randf_range(-4.0, 4.0), 0, randf_range(-4.0, 4.0))
		target = _wander_target

	var to := target - global_position
	to.y = 0.0
	if to.length() > 0.4:
		var dir := to.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	move_and_slide()

	var flat := Vector3(target.x, global_position.y, target.z)
	if global_position.distance_to(flat) > 0.5:
		look_at(flat, Vector3.UP)

	_body.position.y = absf(sin(_t * 12.0)) * 0.015


## Hit but not killed: pure panic — no aggression, no pack alert.
func on_hit() -> void:
	_flee_t = 3.0


func on_destroyed() -> void:
	var remains := RigidBody3D.new()
	remains.set_script(RemainsScript)
	remains.blob_color = SPECIES.get(species, SPECIES["roach"]).color
	remains.position = global_position + Vector3(0, 0.2, 0)
	get_tree().current_scene.add_child(remains)
	died.emit(global_position)


func _build_model(color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	_body = Node3D.new()
	add_child(_body)

	match species:
		"spider":
			# Round body + eight thin legs
			_sphere(mat, 0.14, Vector3(0, 0.18, 0.02))
			_sphere(mat, 0.08, Vector3(0, 0.18, -0.14))
			for side: float in [-1.0, 1.0]:
				for zoff: float in [-0.1, -0.03, 0.04, 0.11]:
					var leg := MeshInstance3D.new()
					var lm := CylinderMesh.new()
					lm.top_radius = 0.008
					lm.bottom_radius = 0.008
					lm.height = 0.26
					lm.material = mat
					leg.mesh = lm
					leg.position = Vector3(side * 0.13, 0.12, zoff)
					leg.rotation.z = side * 1.1
					_body.add_child(leg)
		"roach":
			# Flat oval shell + antennae
			var shell := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.16
			sm.height = 0.14
			sm.material = mat
			shell.mesh = sm
			shell.position = Vector3(0, 0.12, 0)
			shell.scale = Vector3(0.8, 1.0, 1.4)
			_body.add_child(shell)
			for side: float in [-1.0, 1.0]:
				var ant := MeshInstance3D.new()
				var am := CylinderMesh.new()
				am.top_radius = 0.005
				am.bottom_radius = 0.007
				am.height = 0.16
				am.material = mat
				ant.mesh = am
				ant.position = Vector3(side * 0.04, 0.18, -0.24)
				ant.rotation.x = -1.0
				_body.add_child(ant)
		_:
			# Small ant: three little segments and six legs
			for seg in [[0.11, Vector3(0, 0.15, 0.11)], [0.08, Vector3(0, 0.15, -0.02)], [0.06, Vector3(0, 0.16, -0.12)]]:
				_sphere(mat, seg[0], seg[1])
			for side: float in [-1.0, 1.0]:
				for zoff: float in [-0.06, 0.0, 0.06]:
					var leg := MeshInstance3D.new()
					var lm := CylinderMesh.new()
					lm.top_radius = 0.007
					lm.bottom_radius = 0.007
					lm.height = 0.18
					lm.material = mat
					leg.mesh = lm
					leg.position = Vector3(side * 0.09, 0.09, zoff)
					leg.rotation.z = side * 1.0
					_body.add_child(leg)


func _sphere(mat: StandardMaterial3D, r: float, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 1.7
	sm.material = mat
	mi.mesh = sm
	mi.position = pos
	_body.add_child(mi)
