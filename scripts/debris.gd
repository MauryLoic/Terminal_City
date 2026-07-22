extends Node3D
## Destruction effect: a burst of physical fragments (RigidBody3D)
## in the destroyed object's color, which fall down then disappear.

var color := Color(0.5, 0.4, 0.3)
var count := 8
var piece_size := 0.15


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0

	for i in count:
		var rb := RigidBody3D.new()
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * piece_size * randf_range(0.6, 1.4)
		bm.material = mat
		mi.mesh = bm
		rb.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		cs.shape = bs
		rb.add_child(cs)
		rb.position = Vector3(
			randf_range(-0.5, 0.5),
			randf_range(0.3, 1.2),
			randf_range(-0.5, 0.5)
		)
		rb.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), 0)
		rb.linear_velocity = Vector3(
			randf_range(-2.5, 2.5),
			randf_range(2.0, 5.0),
			randf_range(-2.5, 2.5)
		)
		rb.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
		add_child(rb)

	get_tree().create_timer(4.0).timeout.connect(queue_free)
