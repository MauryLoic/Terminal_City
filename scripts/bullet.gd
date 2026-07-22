extends Node3D
## Balle traçante visuelle : vole du canon jusqu'au point d'impact
## (le raycast a déjà déterminé la cible), puis déclenche l'effet d'impact.

const SPEED := 70.0
const HitEffects := preload("res://scripts/hit_effects.gd")

var damage := 1.0   # dégâts de cette balle (réduits sans lock de visée)

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
	# Impact réel uniquement si le raycast avait touché quelque chose.
	# L'objet visé a pu être détruit pendant le vol de la balle : une
	# référence libérée ne passe pas le contrôle de type de resolve(),
	# on la remplace donc par null AVANT l'appel.
	if _normal != Vector3.ZERO:
		if not is_instance_valid(_collider):
			_collider = null
		HitEffects.resolve(self, _collider, _target, _normal, damage, _impulse)
	queue_free()
