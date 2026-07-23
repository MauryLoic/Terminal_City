extends Node3D
## Rusty knife viewmodel: the humble level-1 starting weapon. A short
## corroded blade and a worn handle. Replaced by the laser saber later.

var _swing_tween: Tween


func _ready() -> void:
	var rust := StandardMaterial3D.new()
	rust.albedo_color = Color(0.42, 0.26, 0.18)
	rust.metallic = 0.3
	rust.roughness = 0.75
	var handle := StandardMaterial3D.new()
	handle.albedo_color = Color(0.16, 0.12, 0.09)
	handle.roughness = 0.95

	# Blade
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.05, 0.26)
	bm.material = rust
	blade.mesh = bm
	blade.position = Vector3(0, 0, -0.2)
	add_child(blade)
	# Tip
	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.012, 0.03, 0.06)
	tm.material = rust
	tip.mesh = tm
	tip.position = Vector3(0, -0.008, -0.35)
	tip.rotation.x = 0.25
	add_child(tip)
	# Handle and guard
	var grip := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.03, 0.04, 0.13)
	gm.material = handle
	grip.mesh = gm
	grip.position = Vector3(0, 0, -0.01)
	add_child(grip)
	var guard := MeshInstance3D.new()
	var um := BoxMesh.new()
	um.size = Vector3(0.02, 0.08, 0.015)
	um.material = rust
	guard.mesh = um
	guard.position = Vector3(0, 0, -0.075)
	add_child(guard)


## Quick stab, then return to rest.
func swing() -> void:
	if _swing_tween:
		_swing_tween.kill()
	position.z = 0.0
	_swing_tween = create_tween()
	_swing_tween.tween_property(self, "position:z", -0.22, 0.07)
	_swing_tween.tween_property(self, "position:z", 0.0, 0.18)
