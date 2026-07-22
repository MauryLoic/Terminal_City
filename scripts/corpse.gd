extends RigidBody3D
## Corps d'une chauve-souris abattue : tombe du ciel avec la physique,
## reste au sol et peut être looté (touche E à proximité).
## - Non looté : disparaît après 15 s.
## - Looté : le corps vide reste encore 5 s puis disparaît.
## Le loot contient des composants (arme, médical) ou du junk,
## jamais d'objets finis.

const LOOT_TABLE := [
	["compo_canon", 18],
	["compo_mecanisme", 18],
	["compo_chassis", 18],
	["compo_medical", 26],
	["junk", 20],
]
const LOOT_RANGE := 2.6
const LIFE_UNLOOTED := 15.0
const LIFE_AFTER_LOOT := 5.0

var loot := {}
var _looted := false
var _despawn := LIFE_UNLOOTED
var _label: Label3D


func _ready() -> void:
	mass = 3.0
	_build_model()
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.32
	cs.shape = sp
	add_child(cs)

	# Génération du loot : 1 ou 2 tirages pondérés
	var rolls := 1 + (1 if randf() < 0.5 else 0)
	for i in rolls:
		var id := _weighted_pick()
		loot[id] = int(loot.get(id, 0)) + 1

	_label = Label3D.new()
	_label.text = "E : looter"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 8
	_label.position.y = 0.9
	_label.visible = false
	add_child(_label)

	angular_velocity = Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))


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


## Modèle : la bête inerte, ailes affaissées.
func _build_model() -> void:
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.2, 0.15, 0.13)
	fur.roughness = 1.0
	var membrane := StandardMaterial3D.new()
	membrane.albedo_color = Color(0.12, 0.08, 0.08)
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
