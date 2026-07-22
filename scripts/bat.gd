extends CharacterBody3D
## Chauve-souris vampire mutante des wastelands. Vit en meute de deux.
##
## PASSIVE par défaut : elle patrouille tranquillement autour de son
## perchoir (home). Elle devient AGRESSIVE si le joueur s'approche trop
## (< AGGRO_RANGE) ou si un membre de la meute est attaqué — auquel cas
## LES DEUX répondent. Elle se calme si le joueur s'éloigne assez
## (> LOSE_RANGE), ce qui laisse une fenêtre pour récupérer.

signal died(pos: Vector3)

const FLY_SPEED := 6.5
const ORBIT_RADIUS := 9.0
const ATTACK_RANGE := 30.0
const AGGRO_RANGE := 9.0     # distance de déclenchement
const LOSE_RANGE := 45.0     # distance de désengagement
const AcidScript := preload("res://scripts/acid_glob.gd")
const CorpseScript := preload("res://scripts/corpse.gd")

var pack_id := 0             # les membres d'une même meute partagent cet id
var home := Vector3.ZERO     # centre de patrouille (posé par le spawner)
var aggro := false

var _t := randf() * TAU
var _orbit := randf() * TAU
var _shoot_t := randf_range(1.5, 3.0)
var _wing_l: Node3D
var _wing_r: Node3D
var _fur: StandardMaterial3D


func _ready() -> void:
	add_to_group("bat")
	set_meta("mat", "flesh")
	set_meta("hp", 5.0)
	set_meta("debris_color", Color(0.25, 0.18, 0.16))
	set_meta("debris_count", 8)
	set_meta("debris_size", 0.1)
	if home == Vector3.ZERO:
		home = global_position
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
	var ppos: Vector3 = player.global_position
	var dist := global_position.distance_to(ppos)

	# Transitions d'état
	if not aggro and dist < AGGRO_RANGE:
		_alert_pack()
	elif aggro and dist > LOSE_RANGE:
		aggro = false

	var target: Vector3
	if aggro:
		# Chasse : orbite autour du joueur, ~5 m au-dessus
		_orbit += delta * 0.5
		target = ppos + Vector3(
			cos(_orbit) * ORBIT_RADIUS,
			5.0 + sin(_t * 2.0) * 1.2,
			sin(_orbit) * ORBIT_RADIUS
		)
	else:
		# Patrouille paisible : ronde lente autour du perchoir
		_orbit += delta * 0.25
		target = home + Vector3(
			cos(_orbit) * 6.0,
			4.0 + sin(_t * 1.5) * 1.0,
			sin(_orbit) * 6.0
		)

	velocity = (target - global_position).limit_length(FLY_SPEED if aggro else FLY_SPEED * 0.5)
	move_and_slide()

	# Orientation : vers le joueur en chasse, vers sa route en patrouille
	var face := ppos if aggro else target
	var flat := Vector3(face.x, global_position.y, face.z)
	if global_position.distance_to(flat) > 1.0:
		look_at(flat, Vector3.UP)

	# Battement d'ailes (plus nerveux en chasse)
	var flap := sin(_t * (12.0 if aggro else 7.0)) * 0.65
	_wing_l.rotation.z = -flap
	_wing_r.rotation.z = flap

	# Crachat d'acide : uniquement en chasse
	if aggro:
		_shoot_t -= delta
		if _shoot_t <= 0.0 and dist < ATTACK_RANGE:
			_shoot_t = randf_range(2.2, 3.5)
			_spit_acid(ppos)


## Appelé par bullet.gd à chaque balle encaissée : flash rouge et
## toute la meute passe à l'attaque.
func on_hit() -> void:
	_flash()
	_alert_pack()


func _alert_pack() -> void:
	for b in get_tree().get_nodes_in_group("bat"):
		if b.pack_id == pack_id:
			b.aggro = true


func _flash() -> void:
	_fur.albedo_color = Color(0.9, 0.25, 0.2)
	var tw := create_tween()
	tw.tween_property(_fur, "albedo_color", Color(0.22, 0.17, 0.15), 0.25)


func _spit_acid(target: Vector3) -> void:
	var glob := Area3D.new()
	glob.set_script(AcidScript)
	var dir := (target + Vector3(0, 0.9, 0) - global_position).normalized()
	glob.direction = dir
	glob.position = global_position + dir * 0.8
	get_tree().current_scene.add_child(glob)
	Sfx.play_acid(global_position)


## Appelé par bullet.gd juste avant la destruction : la bête tombe du
## ciel en corps lootable (composants / junk), et le spawner est
## prévenu pour programmer la réapparition.
func on_destroyed() -> void:
	var corpse := RigidBody3D.new()
	corpse.set_script(CorpseScript)
	corpse.position = global_position
	get_tree().current_scene.add_child(corpse)
	corpse.linear_velocity = Vector3(randf_range(-1.5, 1.5), -2.0, randf_range(-1.5, 1.5))
	died.emit(global_position)


func _build_model() -> void:
	_fur = StandardMaterial3D.new()
	_fur.albedo_color = Color(0.22, 0.17, 0.15)
	_fur.roughness = 1.0
	var membrane := StandardMaterial3D.new()
	membrane.albedo_color = Color(0.13, 0.09, 0.09)
	membrane.roughness = 1.0

	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.3
	bm.height = 0.5
	bm.material = _fur
	body.mesh = bm
	add_child(body)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.17
	hm.height = 0.34
	hm.material = _fur
	head.mesh = hm
	head.position = Vector3(0, 0.12, -0.3)
	add_child(head)

	for side: float in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.0
		em.bottom_radius = 0.05
		em.height = 0.16
		em.material = _fur
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
