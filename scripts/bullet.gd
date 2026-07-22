extends Node3D
## Visual tracer bullet: flies from the barrel to the impact point
## (the raycast already determined the target), then triggers the impact effect.

const SPEED := 70.0
const HitEffects := preload("res://scripts/hit_effects.gd")

var damage := 1.0   # this bullet's damage (reduced without aim lock)

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

	# Small elongated projectile, glowing yellow
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

	# Orient the bullet along its flight direction
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
	# Real impact only if the raycast actually hit something.
	# The target may have been destroyed while the bullet was in flight: a
	# freed reference does not pass resolve()'s argument type check,
	# so we replace it with null BEFORE the call.
	if _normal != Vector3.ZERO:
		if not is_instance_valid(_collider):
			_collider = null
		HitEffects.resolve(self, _collider, _target, _normal, damage, _impulse)
	queue_free()
