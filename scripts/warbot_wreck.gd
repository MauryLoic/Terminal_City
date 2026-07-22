extends RigidBody3D
## Wreck of a destroyed warbot: heavy carcass that settles on the
## ground and can be looted (E key when close). Contains ammo-crafting
## resources. Same timers as bat corpses:
## - Not looted: vanishes after 60 s.
## - Looted: the empty wreck remains 5 more seconds then vanishes.

const LOOT_TABLE := [
	["res_metal", 40],
	["res_powder", 28],
	["res_cell", 22],
	["junk", 10],
]
const LOOT_RANGE := 3.0
const LIFE_UNLOOTED := 60.0
const LIFE_AFTER_LOOT := 5.0

var loot := {}
var _looted := false
var _despawn := LIFE_UNLOOTED
var _label: Label3D


func _ready() -> void:
	mass = 40.0
	_build_model()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 0.9, 1.0)
	cs.shape = box
	add_child(cs)

	# Loot generation: 2 weighted rolls (robots are worth the fight)
	for i in 2:
		var id := _weighted_pick()
		loot[id] = int(loot.get(id, 0)) + 1

	_label = Label3D.new()
	_label.text = "E: loot"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 8
	_label.position.y = 1.2
	_label.visible = false
	add_child(_label)


func _physics_process(delta: float) -> void:
	_despawn -= delta
	if _despawn <= 0.0:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player")
	var near: bool = player != null \
			and global_position.distance_to(player.global_position) < LOOT_RANGE
	_label.visible = near and not _looted


func _unhandled_input(event: InputEvent) -> void:
	if _looted:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_E and not event.alt_pressed:
		var player := get_tree().get_first_node_in_group("player")
		if player and global_position.distance_to(player.global_position) < LOOT_RANGE:
			for id in loot:
				Inventory.add_item(id, loot[id])
			_looted = true
			_label.visible = false
			_despawn = minf(_despawn, LIFE_AFTER_LOOT)
			Sfx.play_click()


func _weighted_pick() -> String:
	var total := 0
	for entry in LOOT_TABLE:
		total += entry[1]
	var r := randi_range(1, total)
	for entry in LOOT_TABLE:
		r -= entry[1]
		if r <= 0:
			return entry[0]
	return "junk"


## Model: charred torso toppled over, one leg sticking out.
func _build_model() -> void:
	var burnt := StandardMaterial3D.new()
	burnt.albedo_color = Color(0.18, 0.18, 0.17)
	burnt.roughness = 0.9

	var torso := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.25, 0.8, 0.8)
	tm.material = burnt
	torso.mesh = tm
	torso.rotation.z = 0.35
	add_child(torso)

	var leg := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.26, 1.0, 0.32)
	lm.material = burnt
	leg.mesh = lm
	leg.position = Vector3(0.5, 0.5, 0.2)
	leg.rotation = Vector3(0.4, 0.3, 0.6)
	add_child(leg)
