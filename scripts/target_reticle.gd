extends Control
## Réticule de visée façon Neocron : quatre crochets d'angle dessinés
## autour de l'ennemi actuellement sous le viseur. Le joueur (player.gd)
## met à jour `target` à chaque frame physique ; on projette la position
## 3D de la cible à l'écran et on dessine les coins du rectangle.

var target: Node3D = null
var lock_ratio := 0.0   # 0 = visée qui débute, 1 = lock complet

const COLOR_START := Color(1.0, 0.6, 0.15, 0.95)   # orange : lock en cours
const COLOR_LOCKED := Color(1.0, 0.12, 0.08, 1.0)  # rouge vif : lock complet
const EXTENT_RIGHT := 1.1   # demi-largeur monde autour de la cible (ailes)
const EXTENT_UP := 0.8      # demi-hauteur monde


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
	var center: Vector3 = target.global_position
	if cam.is_position_behind(center):
		return

	# Taille écran : on projette des extents monde alignés sur la caméra,
	# le rectangle grossit donc naturellement quand la cible est proche.
	var p_c := cam.unproject_position(center)
	var p_r := cam.unproject_position(center + cam.global_transform.basis.x * EXTENT_RIGHT)
	var p_u := cam.unproject_position(center + cam.global_transform.basis.y * EXTENT_UP)
	var half_w := maxf(absf(p_r.x - p_c.x), 18.0)
	var half_h := maxf(absf(p_u.y - p_c.y), 14.0)
	# Les crochets partent larges et se resserrent sur la cible avec le lock
	var tighten := lerpf(1.7, 1.0, lock_ratio)
	half_w *= tighten
	half_h *= tighten
	_draw_brackets(Rect2(p_c - Vector2(half_w, half_h), Vector2(half_w * 2.0, half_h * 2.0)))
	# Lock complet : un point central confirme la précision maximale
	if lock_ratio >= 1.0:
		draw_circle(p_c, 2.5, COLOR_LOCKED)


## Quatre coins en "L" : uniquement les bords extérieurs du rectangle.
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
