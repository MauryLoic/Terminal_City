extends Control
## Neocron-style aiming reticle: four corner brackets drawn
## around the enemy currently under the crosshair. The player (player.gd)
## updates `target` every physics frame; we project the target's
## 3D position to screen space and draws the rectangle corners.

var target: Node3D = null
var lock_ratio := 0.0   # 0 = aim just started, 1 = full lock

const COLOR_START := Color(1.0, 0.6, 0.15, 0.95)   # orange: lock in progress
const COLOR_LOCKED := Color(1.0, 0.12, 0.08, 1.0)  # bright red: full lock
const EXTENT_RIGHT := 1.1   # world half-width around the target (wings)
const EXTENT_UP := 0.8      # world half-height


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(target):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# Bracket center and world size come from per-mob metadata, so the
	# brackets fit a tall warbot as well as a tiny ground ant
	var center: Vector3 = target.global_position \
			+ Vector3(0, float(target.get_meta("aim_center", 0.0)), 0)
	if cam.is_position_behind(center):
		return

	# Screen size: project camera-aligned world extents,
	# so the rectangle naturally grows when the target is close.
	var p_c := cam.unproject_position(center)
	var ext_r := float(target.get_meta("aim_half_w", EXTENT_RIGHT))
	var ext_u := float(target.get_meta("aim_half_h", EXTENT_UP))
	var p_r := cam.unproject_position(center + cam.global_transform.basis.x * ext_r)
	var p_u := cam.unproject_position(center + cam.global_transform.basis.y * ext_u)
	var half_w := maxf(absf(p_r.x - p_c.x), 18.0)
	var half_h := maxf(absf(p_u.y - p_c.y), 14.0)
	# The brackets start wide and tighten onto the target as the lock builds
	var tighten := lerpf(1.7, 1.0, lock_ratio)
	half_w *= tighten
	half_h *= tighten
	_draw_brackets(Rect2(p_c - Vector2(half_w, half_h), Vector2(half_w * 2.0, half_h * 2.0)))
	# Full lock: a center dot confirms maximum precision
	if lock_ratio >= 1.0:
		draw_circle(p_c, 2.5, COLOR_LOCKED)


## Four "L"-shaped corners: only the outer edges of the rectangle.
func _draw_brackets(r: Rect2) -> void:
	var col := COLOR_START.lerp(COLOR_LOCKED, lock_ratio)
	var thickness := lerpf(2.0, 3.0, lock_ratio)
	var l := minf(r.size.x, r.size.y) * 0.35
	var tl := r.position
	var tr := r.position + Vector2(r.size.x, 0)
	var bl := r.position + Vector2(0, r.size.y)
	var br := r.position + r.size
	draw_line(tl, tl + Vector2(l, 0), col, thickness)
	draw_line(tl, tl + Vector2(0, l), col, thickness)
	draw_line(tr, tr + Vector2(-l, 0), col, thickness)
	draw_line(tr, tr + Vector2(0, l), col, thickness)
	draw_line(bl, bl + Vector2(l, 0), col, thickness)
	draw_line(bl, bl + Vector2(0, -l), col, thickness)
	draw_line(br, br + Vector2(-l, 0), col, thickness)
	draw_line(br, br + Vector2(0, -l), col, thickness)
