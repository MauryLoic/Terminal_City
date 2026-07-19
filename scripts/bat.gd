extends CharacterBody3D
## Chauve-souris vampire mutante des wastelands (inspirée du bestiaire
## de Neocron). Vole en orbite autour du joueur, crache des globes
## d'acide, meurt en 5 balles (métadonnées lues par bullet.gd) et
## laisse parfois tomber une trousse de soin.

signal died(pos: Vector3)

const FLY_SPEED := 6.5
const ORBIT_RADIUS := 9.0
const ATTACK_RANGE := 30.0
const AcidScript := preload("res://scripts/acid_glob.gd")
const PickupScript := preload("res://scripts/pickup.gd")

var _t := randf() * TAU
var _orbit := randf() * TAU
var _shoot_t := randf_range(1.5, 3.0)
var _wing_l: Node3D
var _wing_r: Node3D


func _ready() -> void:
	add_to_group("bat")
	set_meta("mat", "flesh")
	set_meta("hp", 5.0)
	set_meta("debris_color", Color(0.25, 0.18, 0.16))
	set_meta("debris_count", 8)
	set_meta("debris_size", 0.1)
	_build_model()
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.5
	cs.shape = sp
	add_child(cs)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_t += delta
	_orbit += delta * 0.5

	# Vol : orbite autour du joueur, ~5 m au-dessus, avec un ondoiement
	var ppos: Vector3 = player.global_position
	var target := ppos + Vector3(
		cos(_orbit) * ORBIT_RADIUS,
		5.0 + sin(_t * 2.0) * 1.2,
		sin(_orbit) * ORBIT_RADIUS
	)
	velocity = (target - global_position).limit_length(FLY_SPEED)
	move_and_slide()

	# Toujours face au joueur
	var flat := Vector3(ppos.x, global_position.y, ppos.z)
	if global_position.distance_to(flat) > 1.0:
		look_at(flat, Vector3.UP)

	# Battement d'ailes
	var flap := sin(_t * 12.0) * 0.65
	_wing_l.rotation.z = -flap
	_wing_r.rotation.z = flap

	# Crachat d'acide périodique
	_shoot_t -= delta
	if _shoot_t <= 0.0 and global_position.distance_to(ppos) < ATTACK_RANGE:
		_shoot_t = randf_range(2.2, 3.5)
		_spit_acid(ppos)


func _spit_acid(target: Vector3) -> void:
	var glob := Area3D.new()
	glob.set_script(AcidScript)
	var dir := (target + Vector3(0, 0.9, 0) - global_position).normalized()
	glob.direction = dir
	glob.position = global_position + dir * 0.8
	get_tree().current_scene.add_child(glob)


## Appelé par bullet.gd juste avant la destruction : loot + signal
## pour que le spawner programme la réapparition.
func on_destroyed() -> void:
	if randf() < 0.6:
		var pk := Area3D.new()
		pk.set_script(PickupScript)
		pk.item_id = "medkit"
		pk.position = global_position
		get_tree().current_scene.add_child(pk)
	died.emit(global_position)


func _build_model() -> void:
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.22, 0.17, 0.15)
	fur.roughness = 1.0
	var membrane := StandardMaterial3D.new()
	membrane.albedo_color = Color(0.13, 0.09, 0.09)
	membrane.roughness = 1.0

	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.3
	bm.height = 0.5
	bm.material = fur
	body.mesh = bm
	add_child(body)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.17
	hm.height = 0.34
	hm.material = fur
	head.mesh = hm
	head.position = Vector3(0, 0.12, -0.3)
	add_child(head)

	for side: float in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.0
		em.bottom_radius = 0.05
		em.height = 0.16
		em.material = fur
		ear.mesh = em
		ear.position = Vector3(side * 0.08, 0.3, -0.3)
		add_child(ear)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1, 0.15, 0.1)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1, 0.1, 0.05)
	eye_mat.emission_energy_multiplier = 2.0
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eyem := SphereMesh.new()
		eyem.radius = 0.035
		eyem.height = 0.07
		eyem.material = eye_mat
		eye.mesh = eyem
		eye.position = Vector3(side * 0.07, 0.15, -0.43)
		add_child(eye)

	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.22, 0.08, 0)
		var wing := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(1.1, 0.03, 0.55)
		wm.material = membrane
		wing.mesh = wm
		wing.position = Vector3(side * 0.58, 0, 0)
		pivot.add_child(wing)
		add_child(pivot)
		if side < 0.0:
			_wing_l = pivot
		else:
			_wing_r = pivot
