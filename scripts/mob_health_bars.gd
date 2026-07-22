extends Control
## Barres de vie flottantes des mobs : projetées à l'écran au-dessus de
## chaque chauve-souris (fond sombre + remplissage rouge selon les PV).

const BAR_W := 46.0
const BAR_H := 5.0
const MAX_DIST := 60.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for b in get_tree().get_nodes_in_group("bat"):
		if not (b is Node3D) or not b.has_meta("hp"):
			continue
		var world_pos: Vector3 = b.global_position + Vector3(0, 1.0, 0)
		if cam.is_position_behind(world_pos):
			continue
		if cam.global_position.distance_to(world_pos) > MAX_DIST:
			continue
		var p := cam.unproject_position(world_pos)
		var hp: float = b.get_meta("hp")
		var hp_max: float = b.get_meta("hp_max", 5.0)
		var ratio := clampf(hp / hp_max, 0.0, 1.0)
		var tl := p - Vector2(BAR_W * 0.5, BAR_H * 0.5)
		draw_rect(Rect2(tl, Vector2(BAR_W, BAR_H)), Color(0, 0, 0, 0.55))
		draw_rect(Rect2(tl, Vector2(BAR_W * ratio, BAR_H)), Color(0.85, 0.15, 0.12, 0.95))
