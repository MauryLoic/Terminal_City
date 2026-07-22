extends Node3D
## Crowbar viewmodel: dark red steel bar with a hooked end and rubber
## grip. Always-available melee weapon — the anti-softlock fallback
## (crowbar -> warbot wrecks -> resources -> ammo crafting).

var _swing_tween: Tween


func _ready() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.45, 0.1, 0.08)
	steel.metallic = 0.5
	steel.roughness = 0.5
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.08, 0.08, 0.09)
	rubber.roughness = 0.95

	_box(steel, Vector3(0.045, 0.045, 0.55), Vector3(0, 0, -0.2))
	# Hooked end, slightly bent
	var hook := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.045, 0.13, 0.05)
	hm.material = steel
	hook.mesh = hm
	hook.position = Vector3(0, -0.05, -0.47)
	hook.rotation.x = 0.5
	add_child(hook)
	_box(rubber, Vector3(0.05, 0.05, 0.16), Vector3(0, 0, 0.02))


## Quick downward swing, then return to rest.
func swing() -> void:
	if _swing_tween:
		_swing_tween.kill()
	rotation = Vector3.ZERO
	_swing_tween = create_tween()
	_swing_tween.tween_property(self, "rotation:x", -1.1, 0.09)
	_swing_tween.tween_property(self, "rotation:x", 0.0, 0.22)


func _box(mat: StandardMaterial3D, size: Vector3, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	add_child(mi)
