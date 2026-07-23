extends Node3D
## Crude pistol viewmodel: badly made, rust-stained slide, worn grip.
## The level-1 ranged weapon, found on a desk in the starting bunker.

var _swing_tween: Tween


func _ready() -> void:
	var rust := StandardMaterial3D.new()
	rust.albedo_color = Color(0.35, 0.28, 0.24)
	rust.metallic = 0.4
	rust.roughness = 0.7
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.14, 0.11, 0.09)
	grip_mat.roughness = 0.95

	# Slide and short barrel
	_box(rust, Vector3(0.05, 0.06, 0.2), Vector3(0, 0.01, -0.08))
	var barrel := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.012
	bm.bottom_radius = 0.012
	bm.height = 0.07
	bm.material = rust
	barrel.mesh = bm
	barrel.position = Vector3(0, 0.015, -0.21)
	barrel.rotation.x = PI / 2
	add_child(barrel)
	# Grip and trigger guard
	_box(grip_mat, Vector3(0.04, 0.1, 0.05), Vector3(0, -0.07, 0.0), Vector3(0.25, 0, 0))
	_box(rust, Vector3(0.012, 0.012, 0.05), Vector3(0, -0.045, -0.05))

	var m := Marker3D.new()
	m.name = "Muzzle"
	m.position = Vector3(0, 0.015, -0.25)
	add_child(m)


func _box(mat: StandardMaterial3D, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
