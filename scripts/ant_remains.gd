extends "res://scripts/remains_base.gd"
## Squashed mutant ant: drops one of the two medkit components
## (medical component or organic gland), sometimes junk.


func _init() -> void:
	loot_table = [
		["compo_medical", 45],
		["compo_organic", 45],
		["junk", 10],
	]
	rolls = 1
	label_height = 0.6


func _build_model() -> void:
	var chitin := StandardMaterial3D.new()
	chitin.albedo_color = Color(0.24, 0.11, 0.06)
	chitin.roughness = 0.8
	# Flattened body segments: the beast lies crushed on its side
	for seg in [[0.2, Vector3(0, 0.08, 0.18)], [0.14, Vector3(0, 0.08, -0.04)], [0.11, Vector3(0, 0.09, -0.2)]]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = seg[0]
		sm.height = seg[0] * 1.2
		sm.material = chitin
		mi.mesh = sm
		mi.position = seg[1]
		mi.scale = Vector3(1.0, 0.55, 1.0)
		add_child(mi)
