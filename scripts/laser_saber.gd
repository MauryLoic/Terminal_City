extends Node3D
## Laser saber viewmodel: metal hilt and a glowing red energy blade,
## with its own light. Replaces the crowbar as the melee weapon (key 3)
## once crafted — better damage and reach.

var _swing_tween: Tween


func _ready() -> void:
	var hilt_mat := StandardMaterial3D.new()
	hilt_mat.albedo_color = Color(0.3, 0.31, 0.34)
	hilt_mat.metallic = 0.7
	hilt_mat.roughness = 0.35
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(1.0, 0.2, 0.12, 0.9)
	blade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blade_mat.emission_enabled = true
	blade_mat.emission = Color(1.0, 0.1, 0.05)
	blade_mat.emission_energy_multiplier = 3.0
	blade_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Hilt along the firing axis
	var hilt := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.028
	hm.bottom_radius = 0.032
	hm.height = 0.24
	hm.material = hilt_mat
	hilt.mesh = hm
	hilt.position = Vector3(0, 0, 0.04)
	hilt.rotation.x = PI / 2
	add_child(hilt)

	# Energy blade
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, 0.035, 0.75)
	bm.material = blade_mat
	blade.mesh = bm
	blade.position = Vector3(0, 0, -0.45)
	add_child(blade)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.2, 0.1)
	light.light_energy = 0.7
	light.omni_range = 1.6
	light.position = Vector3(0, 0, -0.4)
	add_child(light)


## Quick slash, then return to rest.
func swing() -> void:
	if _swing_tween:
		_swing_tween.kill()
	rotation = Vector3.ZERO
	_swing_tween = create_tween()
	_swing_tween.tween_property(self, "rotation:z", -1.0, 0.08)
	_swing_tween.tween_property(self, "rotation:z", 0.0, 0.2)
