extends "res://scripts/bat.gd"
## Blue Vampire Bat: mini-boss summoned by the player's killing spree
## (every few normal bat kills). Much tougher (20 HP), permanently
## aggressive, and alternates two attacks: the regular acid glob, and a
## fire ray that sets the player ablaze for 3 seconds. Its remains
## always contain one laser saber part (10 needed to craft the saber).

const BlueRemainsScript := preload("res://scripts/blue_bat_remains.gd")
const LaserBeamScript := preload("res://scripts/laser_beam.gd")
const FIRE_RAY_BURN := 3.0


func _ready() -> void:
	super._ready()
	MobRank.apply(self, "Blue Vampire Bat", level, 20.0, 400)
	set_meta("debris_color", Color(0.15, 0.3, 0.7))
	pack_id = -1        # loner: pack alerts don't concern it
	aggro = true        # it spawned because of you — it knows
	_fur.albedo_color = Color(0.16, 0.28, 0.6)


## Attack override: 50% regular acid glob, 50% fire ray.
func _spit_acid(target: Vector3) -> void:
	if randf() < 0.5:
		super._spit_acid(target)
	else:
		_fire_ray(target)


## Fire ray: instant hitscan toward the player; on hit, ignites a
## 3-second burn (damage over time handled by player.gd).
func _fire_ray(target: Vector3) -> void:
	var from := global_position
	var dir := (target + Vector3(0, 0.9, 0) - from).normalized()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 60.0)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	var to: Vector3 = hit.position if hit else from + dir * 60.0

	var beam := LaserBeamScript.new()
	beam.setup(from, to, Vector3.ZERO, null, 0.0)  # purely visual ray
	beam.duration = 0.6
	get_tree().current_scene.add_child(beam)
	Sfx.play_laser(from)

	if hit and hit.collider and hit.collider.is_in_group("player"):
		hit.collider.apply_burn(FIRE_RAY_BURN)


## Hit flash override (the base flash would repaint it brown).
func _flash() -> void:
	_fur.albedo_color = Color(0.65, 0.35, 0.9)
	var tw := create_tween()
	tw.tween_property(_fur, "albedo_color", Color(0.16, 0.28, 0.6), 0.25)


## Death override: guaranteed saber-part remains. No respawn wiring —
## blue bats only ever come from the kill counter.
func on_destroyed() -> void:
	var remains := RigidBody3D.new()
	remains.set_script(BlueRemainsScript)
	remains.position = global_position
	get_tree().current_scene.add_child(remains)
	died.emit(global_position)
