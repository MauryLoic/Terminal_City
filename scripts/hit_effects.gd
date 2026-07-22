extends Object
## Résolution commune des impacts d'armes (balles ET rayons laser) :
## matériau -> visuel d'impact, poussée physique, dégâts, destruction.
## Utilisé par bullet.gd et laser_beam.gd pour ne pas dupliquer la logique.

const ImpactScript := preload("res://scripts/impact.gd")
const DebrisScript := preload("res://scripts/debris.gd")


static func resolve(ctx: Node, collider: Object, point: Vector3, normal: Vector3, damage: float, impulse: Vector3) -> void:
	# Un objet queue_free() reste "valide" jusqu'à la fin de la frame :
	# sans ce test, deux balles d'une même rafale peuvent détruire deux
	# fois le même objet (double corps, double signal de respawn...).
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
	if obj.has_method("on_destroyed"):
		obj.on_destroyed()
	obj.queue_free()
