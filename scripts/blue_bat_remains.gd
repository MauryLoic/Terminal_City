extends "res://scripts/remains_base.gd"
## Blue bat corpse: always contains exactly one laser saber part.


func _init() -> void:
	loot_table = [["saber_part", 1]]
	rolls = 1
	label_height = 0.9


func _build_model() -> void:
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.15, 0.26, 0.55)
	fur.roughness = 1.0
	var membrane := StandardMaterial3D.new()
	membrane.albedo_color = Color(0.1, 0.14, 0.3)
	membrane.roughness = 1.0

	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.3
	bm.height = 0.38
	bm.material = fur
	body.mesh = bm
	add_child(body)

	for side: float in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.95, 0.02, 0.5)
		wm.material = membrane
		wing.mesh = wm
		wing.position = Vector3(side * 0.6, -0.05, 0)
		wing.rotation.z = side * -0.25
		add_child(wing)
