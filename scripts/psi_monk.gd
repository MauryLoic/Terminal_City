extends Node3D
## Personnage style Psi Monk (Confrérie de Crahn) : longue robe-armure
## bordeaux à capuche, ceinture, gantelet PSI lumineux à la main droite,
## AK-47 tenue devant. Entièrement en primitives.
## Sert de modèle au joueur local (vue 3e personne) et aux joueurs distants.


func _ready() -> void:
	var robe := _mat(Color(0.42, 0.11, 0.1))
	var robe_dark := _mat(Color(0.3, 0.08, 0.08))
	var skin := _mat(Color(0.82, 0.62, 0.48))
	var belt := _mat(Color(0.22, 0.17, 0.1))

	# Jupe de robe évasée jusqu'au sol
	_cyl(robe, 0.27, 0.58, 1.25, Vector3(0, 0.62, 0))
	# Torse
	_cyl(robe, 0.3, 0.28, 0.6, Vector3(0, 1.5, 0))
	# Ceinture
	_cyl(belt, 0.315, 0.315, 0.09, Vector3(0, 1.22, 0))
	# Épaulières
	_sphere(robe_dark, 0.13, Vector3(0.32, 1.72, 0))
	_sphere(robe_dark, 0.13, Vector3(-0.32, 1.72, 0))
	# Bras tendus vers l'avant, vers l'arme
	_arm(robe, Vector3(0.32, 1.72, 0), 1.15, 0.3)
	_arm(robe, Vector3(-0.32, 1.72, 0), 1.05, -0.3)
	# Tête sous la capuche
	_sphere(skin, 0.145, Vector3(0, 1.95, -0.02))
	var hood := _sphere(robe, 0.2, Vector3(0, 1.98, 0.06))
	hood.scale = Vector3(1.0, 1.08, 1.05)

	# Gantelet PSI Crahn à la main droite, légèrement lumineux
	var g := _mat(Color(0.2, 0.55, 0.9))
	g.emission_enabled = true
	g.emission = Color(0.2, 0.55, 0.9)
	g.emission_energy_multiplier = 1.2
	_sphere(g, 0.075, Vector3(0.3, 1.32, -0.35))

	# AK-47 tenue devant
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


## Bras : pivot à l'épaule, cylindre orienté vers le bas puis basculé
## vers l'avant (pitch) et vers le centre (yaw) pour rejoindre l'arme.
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
