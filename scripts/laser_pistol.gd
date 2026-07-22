extends Node3D
## Handcrafted laser pistol (viewmodel): compact metal body,
## thin barrel, glowing red emitter at the tip. Barrel points toward -Z.
## A "Muzzle" Marker3D marks the beam's exit point.


func _ready() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.28, 0.29, 0.32)
	metal.roughness = 0.4
	metal.metallic = 0.6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.12)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.2, 0.12)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.12, 0.06)
	glow.emission_energy_multiplier = 2.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_box(metal, Vector3(0.06, 0.08, 0.24), Vector3(0, 0, -0.06))                       # body
	_box(dark, Vector3(0.04, 0.1, 0.05), Vector3(0, -0.08, 0.03), Vector3(0.3, 0, 0))  # grip
	_cyl(metal, 0.016, 0.18, Vector3(0, 0.01, -0.27))                                  # barrel
	_box(metal, Vector3(0.05, 0.02, 0.1), Vector3(0, 0.055, -0.1))                     # rail

	var tip := MeshInstance3D.new()                                                    # emitter
	var sm := SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	sm.material = glow
	tip.mesh = sm
	tip.position = Vector3(0, 0.01, -0.37)
	add_child(tip)

	var m := Marker3D.new()
	m.name = "Muzzle"
	m.position = Vector3(0, 0.01, -0.38)
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


func _cyl(mat: StandardMaterial3D, r: float, h: float, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = h
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.x = PI / 2
	add_child(mi)
