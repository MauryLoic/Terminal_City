extends RigidBody3D
## Generic lootable remains base class: settles on the ground, can be
## looted (E key when close), then despawns. Subclasses override
## _build_model() / _setup_collision() and set loot_table / rolls.
## - Not looted: vanishes after 60 s.
## - Looted: the empty remains stay 5 more seconds then vanish.

const LOOT_RANGE := 2.8
const LIFE_UNLOOTED := 60.0
const LIFE_AFTER_LOOT := 5.0

var loot_table: Array = [["junk", 1]]
var rolls := 1
var label_height := 0.8

var loot := {}
var _looted := false
var _despawn := LIFE_UNLOOTED
var _label: Label3D


func _ready() -> void:
	_build_model()
	_setup_collision()

	for i in rolls:
		var id := _weighted_pick()
		loot[id] = int(loot.get(id, 0)) + 1

	_label = Label3D.new()
	_label.text = "E: loot"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 8
	_label.position.y = label_height
	_label.visible = false
	add_child(_label)


## Override: visual model of the remains.
func _build_model() -> void:
	pass


## Override if needed: physics shape.
func _setup_collision() -> void:
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.3
	cs.shape = sp
	add_child(cs)


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
	for entry in loot_table:
		total += entry[1]
	var r := randi_range(1, total)
	for entry in loot_table:
		r -= entry[1]
		if r <= 0:
			return entry[0]
	return "junk"
