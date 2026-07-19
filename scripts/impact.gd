extends Node3D
## Effet d'impact dépendant du matériau touché : couleur des éclats et
## de la marque différente pour terre, pierre, bois, buisson, métal.
## Étincelles + marque orientée sur la surface, libérées après 3 s.

const PALETTE := {
	"dirt":  {"spark": Color(0.52, 0.38, 0.24), "mark": Color(0.22, 0.16, 0.1, 0.9), "glow": false},
	"stone": {"spark": Color(0.78, 0.76, 0.72), "mark": Color(0.2, 0.2, 0.2, 0.9), "glow": false},
	"wood":  {"spark": Color(0.68, 0.46, 0.2), "mark": Color(0.14, 0.09, 0.05, 0.9), "glow": false},
	"bush":  {"spark": Color(0.58, 0.42, 0.2), "mark": Color(0, 0, 0, 0), "glow": false},
	"metal": {"spark": Color(1.0, 0.6, 0.15), "mark": Color(0.08, 0.08, 0.08, 0.9), "glow": true},
	"flesh": {"spark": Color(0.6, 0.07, 0.07), "mark": Color(0, 0, 0, 0), "glow": false, "amount": 22, "size": 0.075},
	"acid":  {"spark": Color(0.35, 0.9, 0.2), "mark": Color(0.15, 0.4, 0.1, 0.85), "glow": true},
}

var _point: Vector3
var _normal: Vector3
var _mat_type := "dirt"


func setup(point: Vector3, normal: Vector3, mat_type := "dirt") -> void:
	_point = point
	_normal = normal.normalized()
	_mat_type = mat_type if PALETTE.has(mat_type) else "dirt"


func _ready() -> void:
	global_transform = Transform3D(_basis_from_normal(_normal), _point + _normal * 0.01)
	var p: Dictionary = PALETTE[_mat_type]
	if p.mark.a > 0.0:
		_make_mark(p.mark)
	_make_sparks(p.spark, p.glow)
	get_tree().create_timer(3.0).timeout.connect(queue_free)


func _basis_from_normal(n: Vector3) -> Basis:
	var helper := Vector3.FORWARD
	if absf(n.dot(helper)) > 0.9:
		helper = Vector3.RIGHT
	var x := n.cross(helper).normalized()
	var z := x.cross(n)
	return Basis(x, n, z)


func _make_mark(mark_color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.1
	cyl.bottom_radius = 0.1
	cyl.height = 0.02
	var mat := StandardMaterial3D.new()
	mat.albedo_color = mark_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cyl.material = mat
	mesh.mesh = cyl
	add_child(mesh)

	var tw := create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 3.0)


func _make_sparks(spark_color: Color, glow: bool) -> void:
	var pal: Dictionary = PALETTE[_mat_type]
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = int(pal.get("amount", 14))
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0

	var m := BoxMesh.new()
	var sz: float = pal.get("size", 0.05)
	m.size = Vector3(sz, sz, sz)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = spark_color
	if glow:
		mat.emission_enabled = true
		mat.emission = spark_color
		mat.emission_energy_multiplier = 2.5
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		mat.roughness = 1.0
	m.material = mat
	p.mesh = m

	p.emitting = true
	add_child(p)
