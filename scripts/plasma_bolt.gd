extends Area3D
## Plasma bolt fired by warbots: flies straight, burns the player on
## contact, splashes the scenery with metal-like sparks otherwise.

const SPEED := 16.0
const DAMAGE := 15.0

var direction := Vector3.FORWARD
var _life := 4.0


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.2
	cs.shape = sp
	add_child(cs)

	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.12)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.08)
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
	impact.setup(global_position, Vector3.UP, "metal")
	get_tree().current_scene.add_child(impact)
