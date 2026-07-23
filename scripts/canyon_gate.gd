extends StaticBody3D
## Chain-link gate at the end of the canyon path: the only doorway
## between the sanctuary (base + path) and the main zone. Press E when
## close to open or close it. Open = panel swung aside + collision
## disabled. The sanctuary boundary sits right at this fence line.

const USE_RANGE := 3.2

var open := false

var _panel: Node3D
var _col: CollisionShape3D
var _label: Label3D
var _tween: Tween


func _ready() -> void:
	set_meta("mat", "metal")

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.3, 0.32, 0.35)
	frame_mat.metallic = 0.5
	frame_mat.roughness = 0.5
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.4, 0.42, 0.45, 0.4)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.metallic = 0.4
	mesh_mat.roughness = 0.6

	# Hinged panel (pivot on the left post)
	_panel = Node3D.new()
	_panel.position = Vector3(-1.1, 0, 0)
	add_child(_panel)

	var grid := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(2.2, 2.6, 0.06)
	gm.material = mesh_mat
	grid.mesh = gm
	grid.position = Vector3(1.1, 1.3, 0)
	_panel.add_child(grid)
	# Panel frame bars
	for bar in [[Vector3(2.2, 0.08, 0.08), Vector3(1.1, 0.06, 0)], [Vector3(2.2, 0.08, 0.08), Vector3(1.1, 2.56, 0)], [Vector3(0.08, 2.6, 0.08), Vector3(0.05, 1.3, 0)], [Vector3(0.08, 2.6, 0.08), Vector3(2.15, 1.3, 0)]]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bar[0]
		bm.material = frame_mat
		b.mesh = bm
		b.position = bar[1]
		_panel.add_child(b)

	# Collision follows the closed pose; opening simply disables it
	_col = CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(2.2, 2.6, 0.15)
	_col.shape = cs
	_col.position = Vector3(0, 1.3, 0)
	add_child(_col)

	_label = Label3D.new()
	_label.text = "E: open gate"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 8
	_label.position = Vector3(0, 3.0, 0)
	_label.visible = false
	add_child(_label)


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var near: bool = player != null \
			and global_position.distance_to(player.global_position) < USE_RANGE
	_label.visible = near
	if near:
		_label.text = "E: close gate" if open else "E: open gate"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_E and not event.alt_pressed:
		var player := get_tree().get_first_node_in_group("player")
		if player and global_position.distance_to(player.global_position) < USE_RANGE:
			open = not open
			Sfx.play_click()
			_col.set_deferred("disabled", open)
			if _tween:
				_tween.kill()
			_tween = create_tween()
			_tween.tween_property(_panel, "rotation:y", -1.9 if open else 0.0, 0.5) \
					.set_trans(Tween.TRANS_SINE)
