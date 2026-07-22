extends Node3D
## Laser beam: instant damage on impact (hitscan), then the glowing
## red beam stays visible for 3 seconds while fading — you can
## fire again only once the beam has dissipated (cooldown handled by player.gd).

const HitEffects := preload("res://scripts/hit_effects.gd")
const DURATION := 3.0

var damage := 3.0
var duration := DURATION   # visual persistence (overridable per shot)

var _from: Vector3
var _to: Vector3
var _normal := Vector3.ZERO
var _collider: Object = null


func setup(from: Vector3, to: Vector3, normal: Vector3, collider: Object, dmg: float) -> void:
	_from = from
	_to = to
	_normal = normal
	_collider = collider
	damage = dmg


func _ready() -> void:
	# Immediate damage: the beam is instantaneous, only the visual lingers
	if _normal != Vector3.ZERO:
		if not is_instance_valid(_collider):
			_collider = null
		var dir := (_to - _from).normalized()
		HitEffects.resolve(self, _collider, _to, _normal, damage, dir * 6.0)

	# Visual: emissive red cylinder stretched from barrel to impact point
	var dist := _from.distance_to(_to)
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.02
	cyl.height = dist
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.1, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.1, 0.05)
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyl.material = mat
	mesh.mesh = cyl
	add_child(mesh)

	global_position = (_from + _to) * 0.5
	global_transform.basis = _basis_y((_to - _from).normalized())

	# Gradual fade over the whole duration, then removal
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, duration)
	get_tree().create_timer(duration).timeout.connect(queue_free)


func _basis_y(y_dir: Vector3) -> Basis:
	var helper := Vector3.FORWARD
	if absf(y_dir.dot(helper)) > 0.9:
		helper = Vector3.RIGHT
	var x := y_dir.cross(helper).normalized()
	var z := x.cross(y_dir)
	return Basis(x, y_dir, z)
