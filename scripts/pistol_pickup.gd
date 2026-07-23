extends Area3D
## Crude pistol lying on a bunker desk: press E to take it (+50 rounds).
## The level-1 ranged weapon — its ammo can only be crafted inside the
## starting base, from casings dropped by the base critters.

const USE_RANGE := 2.6

var _label: Label3D


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.5
	cs.shape = sp
	add_child(cs)

	var rust := StandardMaterial3D.new()
	rust.albedo_color = Color(0.35, 0.28, 0.24)
	rust.metallic = 0.4
	rust.roughness = 0.7
	var grip_mat := StandardMaterial3D.new()
	grip_mat.albedo_color = Color(0.14, 0.11, 0.09)

	# Small pistol lying flat on the desk
	var slide := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.05, 0.06, 0.2)
	sm.material = rust
	slide.mesh = sm
	slide.rotation.z = PI / 2
	add_child(slide)
	var grip := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.04, 0.1, 0.05)
	gm.material = grip_mat
	grip.mesh = gm
	grip.position = Vector3(0.05, 0.02, 0.05)
	grip.rotation.z = PI / 2
	add_child(grip)

	_label = Label3D.new()
	_label.text = "E: take pistol (+50 rounds)"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 36
	_label.outline_size = 8
	_label.position.y = 0.5
	_label.visible = false
	add_child(_label)


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	_label.visible = player != null \
			and global_position.distance_to(player.global_position) < USE_RANGE


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_E and not event.alt_pressed:
		var player := get_tree().get_first_node_in_group("player")
		if player and global_position.distance_to(player.global_position) < USE_RANGE:
			Inventory.add_item("pistol")
			player.add_ammo("pistol", 50)
			Sfx.play_click()
			queue_free()
