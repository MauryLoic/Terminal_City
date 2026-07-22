extends Area3D
## Item dropped from the inventory: placed on the ground in front of the
## 30 seconds then disappears. Can be picked back up by walking over it,
## after a short delay (otherwise you'd grab it right back when dropping).

const LIFETIME := 30.0
const PICKUP_DELAY := 1.5

var item_id := "junk"

var _t := 0.0
var _base_y := 0.0


func _ready() -> void:
	var world := get_tree().current_scene.get_node_or_null("World")
	if world:
		global_position.y = world.get_height(global_position.x, global_position.z) + 0.4
	_base_y = global_position.y

	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.6
	cs.shape = sp
	add_child(cs)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.24, 0.18, 0.24)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.5, 0.4)
	bm.material = mat
	mi.mesh = bm
	add_child(mi)

	# Item name floating above (fetched from the inventory)
	var label := Label3D.new()
	var inv := get_tree().get_first_node_in_group("inventory_ui")
	label.text = str(inv._item_def(item_id).get("short", item_id)) if inv else item_id
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.outline_size = 8
	label.position.y = 0.55
	add_child(label)

	body_entered.connect(_on_body)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 1.5
	global_position.y = _base_y + sin(_t * 2.0) * 0.06 + 0.08


func _on_body(body: Node3D) -> void:
	if _t < PICKUP_DELAY:
		return
	if body.is_in_group("player"):
		Inventory.add_item(item_id)
		queue_free()
