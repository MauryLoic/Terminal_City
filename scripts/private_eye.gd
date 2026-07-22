extends Node3D
## Private Eye-style character: long trench coat, armored chest plate,
## dark glasses and fedora — Neocron's urban detective.
## Character faces -Z. Holds an AK-47 (with its "Muzzle" Marker3D).
## Used as the model for the local player (third person) and remote players.


func _ready() -> void:
	var coat := _mat(Color(0.27, 0.26, 0.22))
	var coat_dark := _mat(Color(0.19, 0.18, 0.15))
	var pants := _mat(Color(0.17, 0.17, 0.19))
	var skin := _mat(Color(0.82, 0.62, 0.48))
	var dark := _mat(Color(0.08, 0.08, 0.09))
	var armor := _mat(Color(0.45, 0.47, 0.5))
	armor.metallic = 0.5
	armor.roughness = 0.4

	# Legs and boots (visible under the trench coat)
	for side in [-1.0, 1.0]:
		_cyl(pants, 0.09, 0.1, 0.8, Vector3(side * 0.13, 0.45, 0))
		_box(dark, Vector3(0.15, 0.12, 0.3), Vector3(side * 0.13, 0.06, -0.04))

	# Flared trench coat, from torso to knees
	_cyl(coat, 0.27, 0.37, 0.95, Vector3(0, 1.08, 0))
	# Torso (upper coat)
	_cyl(coat, 0.28, 0.28, 0.5, Vector3(0, 1.5, 0))
	# Armored chest plate
	_box(armor, Vector3(0.34, 0.3, 0.08), Vector3(0, 1.47, -0.2))
	# Belt
	_cyl(coat_dark, 0.29, 0.29, 0.08, Vector3(0, 1.24, 0))
	# Shoulders
	_sphere(coat_dark, 0.12, Vector3(0.3, 1.7, 0))
	_sphere(coat_dark, 0.12, Vector3(-0.3, 1.7, 0))
	# Arms stretched forward, toward the weapon (coat sleeves)
	_arm(coat, Vector3(0.3, 1.7, 0), 1.15, 0.3)
	_arm(coat, Vector3(-0.3, 1.7, 0), 1.05, -0.3)
	# Hands
	_sphere(skin, 0.06, Vector3(0.24, 1.31, -0.33))
	_sphere(skin, 0.06, Vector3(0.05, 1.33, -0.5))

	# Head, dark glasses, fedora
	_sphere(skin, 0.135, Vector3(0, 1.88, -0.02))
	_box(dark, Vector3(0.2, 0.055, 0.08), Vector3(0, 1.9, -0.11))
	_cyl(coat_dark, 0.2, 0.2, 0.04, Vector3(0, 1.99, 0))
	_cyl(coat_dark, 0.12, 0.13, 0.12, Vector3(0, 2.06, 0))

	# AK-47 held in front
	var ak := preload("res://scenes/ak47.tscn").instantiate()
	ak.name = "AK47"
	ak.position = Vector3(0.22, 1.33, -0.32)
	ak.rotation = Vector3(0, -0.08, 0)
	add_child(ak)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _sphere(mat: StandardMaterial3D, r: float, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
	return mi


func _box(mat: StandardMaterial3D, size: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)


func _cyl(mat: StandardMaterial3D, top: float, bottom: float, height: float, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)


## Arm: pivot at the shoulder, cylinder pointing down then tilted
## forward (pitch) and toward the center (yaw) to reach the weapon.
func _arm(mat: StandardMaterial3D, shoulder: Vector3, pitch: float, yaw: float) -> void:
	var pivot := Node3D.new()
	pivot.position = shoulder
	pivot.rotation = Vector3(pitch, yaw, 0)
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.065
	mesh.bottom_radius = 0.058
	mesh.height = 0.55
	mesh.material = mat
	mi.mesh = mesh
	mi.position = Vector3(0, -0.275, 0)
	pivot.add_child(mi)
	add_child(pivot)
