extends "res://scripts/remains_base.gd"
## Squashed critter: drops medkit components and spent casings — the
## safe level-1 economy (healing and pistol ammo).

var blob_color := Color(0.3, 0.18, 0.1)


func _init() -> void:
	loot_table = [
		["compo_medical", 34],
		["compo_organic", 34],
		["res_casing", 26],
		["junk", 6],
	]
	rolls = 2
	label_height = 0.5


func _build_model() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = blob_color
	mat.roughness = 0.85
	for seg in [[0.13, Vector3(0, 0.05, 0.06)], [0.09, Vector3(0, 0.05, -0.08)]]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = seg[0]
		sm.height = seg[0]
		sm.material = mat
		mi.mesh = sm
		mi.position = seg[1]
		mi.scale = Vector3(1.0, 0.5, 1.0)
		add_child(mi)
