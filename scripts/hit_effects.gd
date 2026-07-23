extends Object
## Shared weapon impact resolution (bullets AND laser beams):
## material -> impact visual, physical push, damage, destruction.
## Used by bullet.gd and laser_beam.gd to avoid duplicating the logic.

const ImpactScript := preload("res://scripts/impact.gd")
const DebrisScript := preload("res://scripts/debris.gd")


static func resolve(ctx: Node, collider: Object, point: Vector3, normal: Vector3, damage: float, impulse: Vector3) -> void:
	# A queue_free() object stays "valid" until the end of the frame:
	# without this check, two bullets of the same burst can destroy
	# the same object twice (double corpse, double respawn signal...).
	var alive := is_instance_valid(collider) \
			and not (collider is Node and collider.is_queued_for_deletion())
	var mat_type := "dirt"
	if alive:
		if collider.has_meta("mat"):
			mat_type = collider.get_meta("mat")
		if collider is RigidBody3D:
			collider.apply_central_impulse(impulse)
		if collider.has_meta("hp"):
			if collider.has_method("on_hit"):
				collider.on_hit()
			var hp: float = collider.get_meta("hp") - damage
			if hp <= 0.0:
				_destroy_object(ctx, collider)
			else:
				collider.set_meta("hp", hp)

	var impact := ImpactScript.new()
	impact.setup(point, normal, mat_type)
	var parent: Node = ctx.get_tree().current_scene
	if alive and collider is Node3D and not collider.is_queued_for_deletion():
		parent = collider
	parent.add_child(impact)


static func _destroy_object(ctx: Node, obj: Node3D) -> void:
	var debris := DebrisScript.new()
	debris.color = obj.get_meta("debris_color", Color(0.5, 0.4, 0.3))
	debris.count = int(obj.get_meta("debris_count", 8))
	debris.piece_size = float(obj.get_meta("debris_size", 0.15))
	debris.position = obj.global_position
	ctx.get_tree().current_scene.add_child(debris)
	Sfx.play_explosion(obj.global_position)
	# Experience reward for the player
	if obj.has_meta("xp"):
		var player := ctx.get_tree().get_first_node_in_group("player")
		if player and player.has_method("gain_xp"):
			player.gain_xp(int(obj.get_meta("xp")), int(obj.get_meta("mob_level", 1)))
	if obj.has_method("on_destroyed"):
		obj.on_destroyed()
	obj.queue_free()
