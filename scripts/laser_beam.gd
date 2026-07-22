extends Node3D
## Rayon laser : dégâts instantanés à l'impact (hitscan), puis le rayon
## rouge lumineux reste visible 3 secondes en s'évanouissant — on ne
## peut retirer qu'une fois le rayon dissipé (cooldown géré par player.gd).

const HitEffects := preload("res://scripts/hit_effects.gd")
const DURATION := 3.0

var damage := 3.0

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
	# Dégâts immédiats : le rayon est instantané, seul le visuel persiste
	if _normal != Vector3.ZERO:
		if not is_instance_valid(_collider):
			_collider = null
		var dir := (_to - _from).normalized()
		HitEffects.resolve(self, _collider, _to, _normal, damage, dir * 6.0)

	# Visuel : cylindre rouge émissif tendu du canon au point d'impact
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

	# Fondu progressif sur toute la durée, puis disparition
	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, DURATION)
	tw.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, DURATION)
	get_tree().create_timer(DURATION).timeout.connect(queue_free)


func _basis_y(y_dir: Vector3) -> Basis:
	var helper := Vector3.FORWARD
	if absf(y_dir.dot(helper)) > 0.9:
		helper = Vector3.RIGHT
	var x := y_dir.cross(helper).normalized()
	var z := x.cross(y_dir)
	return Basis(x, y_dir, z)
