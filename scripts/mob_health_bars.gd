extends Control
## Floating mob name + health bar: projected on screen above each mob
## in the "mob" group, Neocron-style (name over a dark bar with red fill).

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
	var font := ThemeDB.fallback_font
	for b in get_tree().get_nodes_in_group("mob"):
		if not (b is Node3D) or not b.has_meta("hp"):
			continue
		var world_pos: Vector3 = b.global_position + Vector3(0, float(b.get_meta("bar_height", 1.0)), 0)
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
		# Enemy name above the bar (shadow + light text for readability)
		var mob_name := str(b.get_meta("mob_name", ""))
		if mob_name != "":
			# Neocron-style plate: "Warbot 32/32*", tinted by how far
			# the mob outranks the player
			var rank := str(b.get_meta("mob_rank", ""))
			var label := mob_name if rank == "" else "%s  %s" % [mob_name, rank]
			var fs := 13
			var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var np := Vector2(p.x - tw * 0.5, tl.y - 5.0)
			var col := Color(1, 0.88, 0.78)
			var player := get_tree().get_first_node_in_group("player")
			if player != null:
				var diff: int = int(b.get_meta("mob_level", 1)) - int(player.level)
				if diff >= 10:
					col = Color(1.0, 0.35, 0.3)     # far above you: lethal
				elif diff >= 4:
					col = Color(1.0, 0.7, 0.35)     # tougher than you
				elif diff <= -6:
					col = Color(0.65, 0.7, 0.65)    # trivial prey
			draw_string(font, np + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
			draw_string(font, np, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
