extends Area3D
## Pickable item on the ground: small white kit with a red cross
## that spins and floats. Picked up on player contact -> inventory.

var item_id := "medkit"

var _t := 0.0
var _base_y := 0.0


func _ready() -> void:
	# Snap to the ground wherever the item is dropped
	var world := get_tree().current_scene.get_node_or_null("World")
	if world:
		global_position.y = world.get_height(global_position.x, global_position.z) + 0.5
	_base_y = global_position.y

	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.7
	cs.shape = sp
	add_child(cs)

	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.92, 0.9)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.15, 0.12)

	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.34, 0.2, 0.28)
	bm.material = white
	box.mesh = bm
	add_child(box)

	var c1 := MeshInstance3D.new()
	var m1 := BoxMesh.new()
	m1.size = Vector3(0.2, 0.02, 0.06)
	m1.material = red
	c1.mesh = m1
	c1.position.y = 0.11
	add_child(c1)

	var c2 := MeshInstance3D.new()
	var m2 := BoxMesh.new()
	m2.size = Vector3(0.06, 0.02, 0.2)
	m2.material = red
	c2.mesh = m2
	c2.position.y = 0.11
	add_child(c2)

	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 2.0
	global_position.y = _base_y + sin(_t * 2.0) * 0.1 + 0.1


func _on_body(body: Node3D) -> void:
	if body.is_in_group("player"):
		Inventory.add_item(item_id)
		queue_free()
