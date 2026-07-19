extends Node3D
## AK-47 en primitives : boîtier et chargeur courbé métal, crosse,
## poignée et garde-main bois. L'axe -Z est la direction du tir,
## un Marker3D "Muzzle" marque le bout du canon.


func _ready() -> void:
	var metal := _mat(Color(0.14, 0.14, 0.16), 0.45, 0.6)
	var wood := _mat(Color(0.46, 0.27, 0.12), 0.85, 0.0)

	# Boîtier de culasse
	_box(metal, Vector3(0.06, 0.075, 0.34), Vector3(0, 0, -0.02))
	# Canon
	_cyl(metal, 0.016, 0.30, Vector3(0, 0.012, -0.33))
	# Tube de gaz au-dessus du canon
	_cyl(metal, 0.011, 0.16, Vector3(0, 0.048, -0.25))
	# Guidon
	_box(metal, Vector3(0.016, 0.055, 0.016), Vector3(0, 0.055, -0.44))
	# Garde-main bois
	_box(wood, Vector3(0.062, 0.06, 0.15), Vector3(0, 0.004, -0.23))
	# Chargeur courbé vers l'avant
	_box(metal, Vector3(0.045, 0.19, 0.07), Vector3(0, -0.115, -0.02), Vector3(0.45, 0, 0))
	# Poignée pistolet
	_box(wood, Vector3(0.045, 0.12, 0.06), Vector3(0, -0.085, 0.12), Vector3(-0.3, 0, 0))
	# Crosse bois, légèrement tombante
	_box(wood, Vector3(0.05, 0.1, 0.26), Vector3(0, -0.025, 0.28), Vector3(0.1, 0, 0))

	# Bout du canon (origine des balles traçantes en vue 3e personne)
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0.012, -0.49)
	add_child(muzzle)


func _mat(c: Color, rough: float, metallic: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metallic
	return m


func _box(mat: StandardMaterial3D, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	add_child(mi)


func _cyl(mat: StandardMaterial3D, radius: float, height: float, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = Vector3(PI / 2.0, 0, 0)   # cylindre couché le long de Z
	add_child(mi)
