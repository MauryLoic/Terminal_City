extends StaticBody3D
## Supply crate, Neocron-style: press E when close to open it and take
## what is inside — mostly rounds for the crude pistol, sometimes a few
## salvage resources. Once emptied the lid stays open and the crate
## restocks after a minute, so ammo never runs dry for good.
##
## Crates sit beside or inside the ruined buildings of the main zone,
## and a couple are stored in the starting bunker.

const USE_RANGE := 3.0
const RESTOCK_TIME := 60.0
const AMMO_MIN := 270          # "around 300 rounds" per crate
const AMMO_MAX := 330
const BONUS_TABLE := [
	["res_casing", 34],
	["res_metal", 26],
	["res_powder", 18],
	["compo_medical", 12],
	["compo_organic", 10],
]

var empty := false

var _restock := 0.0
var _lid: Node3D
var _label: Label3D
var _tween: Tween


func _ready() -> void:
	set_meta("mat", "metal")
	_build_model()

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.72, 0.8)
	cs.shape = box
	cs.position.y = 0.36
	add_child(cs)

	_label = Label3D.new()
	_label.text = "E: open crate"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 38
	_label.outline_size = 8
	_label.position.y = 1.15
	_label.visible = false
	add_child(_label)


func _physics_process(delta: float) -> void:
	# Restocking: the lid drops back and the crate can be looted again
	if empty:
		_restock -= delta
		if _restock <= 0.0:
			empty = false
			_animate_lid(false)

	var player := get_tree().get_first_node_in_group("player")
	var near: bool = player != null \
			and global_position.distance_to(player.global_position) < USE_RANGE
	_label.visible = near
	if near:
		if empty:
			_label.text = "Empty — restocking (%ds)" % int(ceilf(_restock))
		else:
			_label.text = "E: open crate"


func _unhandled_input(event: InputEvent) -> void:
	if empty:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_E and not event.alt_pressed:
		var player := get_tree().get_first_node_in_group("player")
		if player == null:
			return
		if global_position.distance_to(player.global_position) >= USE_RANGE:
			return

		var rounds := randi_range(AMMO_MIN, AMMO_MAX)
		player.add_ammo("pistol", rounds)
		# A crate rarely holds only ammo: one or two salvage items too
		for i in randi_range(1, 2):
			Inventory.add_item(_weighted_pick())
		Sfx.play_click()

		empty = true
		_restock = RESTOCK_TIME
		_animate_lid(true)


func _weighted_pick() -> String:
	var total := 0
	for entry in BONUS_TABLE:
		total += entry[1]
	var r := randi_range(1, total)
	for entry in BONUS_TABLE:
		r -= entry[1]
		if r <= 0:
			return entry[0]
	return "junk"


func _animate_lid(open: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_lid, "rotation:x", -1.7 if open else 0.0, 0.4) \
			.set_trans(Tween.TRANS_SINE)


## Model: olive-green army crate with metal corner bands and a hinged
## lid that swings open at the back.
func _build_model() -> void:
	var army := StandardMaterial3D.new()
	army.albedo_color = Color(0.26, 0.32, 0.22)
	army.roughness = 0.9
	var band := StandardMaterial3D.new()
	band.albedo_color = Color(0.18, 0.19, 0.2)
	band.metallic = 0.5
	band.roughness = 0.6

	_box(army, Vector3(1.2, 0.62, 0.8), Vector3(0, 0.31, 0), self)
	for side: float in [-1.0, 1.0]:
		_box(band, Vector3(0.07, 0.66, 0.84), Vector3(side * 0.5, 0.31, 0), self)
	_box(band, Vector3(0.16, 0.1, 0.06), Vector3(0, 0.34, 0.42), self)   # latch

	# Hinged lid, pivoting on the rear edge
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.62, -0.4)
	add_child(_lid)
	_box(army, Vector3(1.22, 0.1, 0.82), Vector3(0, 0.05, 0.4), _lid)
	_box(band, Vector3(0.07, 0.12, 0.84), Vector3(-0.5, 0.05, 0.4), _lid)
	_box(band, Vector3(0.07, 0.12, 0.84), Vector3(0.5, 0.05, 0.4), _lid)


func _box(mat: StandardMaterial3D, size: Vector3, pos: Vector3, parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
