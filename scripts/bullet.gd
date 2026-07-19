extends Node3D
## Balle traçante visuelle : vole du canon jusqu'au point d'impact
## (le raycast a déjà déterminé la cible), puis déclenche l'effet d'impact.

const SPEED := 70.0
const ImpactScript := preload("res://scripts/impact.gd")
const DebrisScript := preload("res://scripts/debris.gd")

var _start: Vector3
var _target: Vector3
var _normal: Vector3
var _collider: Object = null
var _impulse: Vector3
var _direction: Vector3
var _distance: float
var _traveled := 0.0


func setup(start: Vector3, target: Vector3, normal: Vector3, collider: Object, impulse: Vector3) -> void:
	_start = start
	_target = target
	_normal = normal
	_collider = collider
	_impulse = impulse
	_direction = (target - start).normalized()
	_distance = start.distance_to(target)


func _ready() -> void:
	position = _start

	# Petit projectile allongé, jaune lumineux
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.03, 0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.2)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	mesh.mesh = box
	add_child(mesh)

	# Orienter la balle dans sa direction de vol
	var up := Vector3.UP
	if absf(_direction.dot(up)) > 0.99:
		up = Vector3.RIGHT
	look_at(_start + _direction, up)


func _process(delta: float) -> void:
	var step := SPEED * delta
	_traveled += step
	if _traveled >= _distance:
		_on_arrive()
		return
	position += _direction * step


func _on_arrive() -> void:
	# Impact réel uniquement si le raycast avait touché quelque chose
	if _normal != Vector3.ZERO:
		var mat_type := "dirt"
		if is_instance_valid(_collider):
			# Matériau de l'objet (défini par world_gen) -> visuel d'impact
			if _collider.has_meta("mat"):
				mat_type = _collider.get_meta("mat")
			# Poussée physique : la vitesse résultante dépend de la masse
			if _collider is RigidBody3D:
				_collider.apply_central_impulse(_impulse)
			# Dégâts : les objets avec des PV finissent par être détruits
			if _collider.has_meta("hp"):
				if _collider.has_method("on_hit"):
					_collider.on_hit()
				var hp: float = _collider.get_meta("hp") - 1.0
				if hp <= 0.0:
					_destroy(_collider)
				else:
					_collider.set_meta("hp", hp)

		var impact := ImpactScript.new()
		impact.setup(_target, _normal, mat_type)
		# Attacher l'impact au corps touché pour que la marque suive les objets
		var parent: Node = get_tree().current_scene
		if is_instance_valid(_collider) and _collider is Node3D \
				and not _collider.is_queued_for_deletion():
			parent = _collider
		parent.add_child(impact)
	queue_free()


## Destruction : gerbe de fragments de la couleur de l'objet, puis
## suppression de l'objet.
func _destroy(obj: Node3D) -> void:
	var debris := DebrisScript.new()
	debris.color = obj.get_meta("debris_color", Color(0.5, 0.4, 0.3))
	debris.count = int(obj.get_meta("debris_count", 8))
	debris.piece_size = float(obj.get_meta("debris_size", 0.15))
	debris.position = obj.global_position
	get_tree().current_scene.add_child(debris)
	Sfx.play_explosion(obj.global_position)
	# Hook pour les objets à logique de mort (loot, signal de respawn...)
	if obj.has_method("on_destroyed"):
		obj.on_destroyed()
	obj.queue_free()
