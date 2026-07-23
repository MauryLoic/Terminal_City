extends Area3D
## Acid glob spat by the bats: flies in a straight line,
## hurts the player on contact, splashes the scenery otherwise.

const SPEED := 13.0
const DAMAGE := 25.0

var direction := Vector3.FORWARD
var _life := 4.0


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.18
	cs.shape = sp
	add_child(cs)

	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.15
	mesh.height = 0.3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.9, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.85, 0.15)
	mat.emission_energy_multiplier = 1.6
	mesh.material = mat
	mi.mesh = mesh
	add_child(mi)

	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	position += direction * SPEED * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body(body: Node3D) -> void:
	if body.is_in_group("mob"):
		return
	if body.is_in_group("player"):
		body.take_damage(DAMAGE)
	_splash()
	queue_free()


func _splash() -> void:
	var impact := preload("res://scripts/impact.gd").new()
	impact.setup(global_position, Vector3.UP, "acid")
	get_tree().current_scene.add_child(impact)
