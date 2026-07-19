extends Node3D
## Joueur distant : purement visuel, piloté par les états reçus du serveur.
## Les positions arrivent à ~20 Hz ; on interpole en douceur vers la
## dernière cible connue pour un rendu fluide quel que soit le framerate.

const LERP_SPEED := 12.0

var _target_pos: Vector3
var _target_yaw := 0.0
var _target_pitch := 0.0
var _has_state := false

@onready var head: Node3D = $Head
@onready var name_label: Label3D = $NameLabel


func set_player_name(n: String) -> void:
	name_label.text = n


## Nouvel état reçu du serveur. Le premier état téléporte (pas de glissement
## depuis l'origine), les suivants sont interpolés dans _process.
func apply_state(pos: Vector3, yaw: float, pitch: float) -> void:
	if not _has_state:
		global_position = pos
		rotation.y = yaw
		head.rotation.x = pitch
		_has_state = true
	_target_pos = pos
	_target_yaw = yaw
	_target_pitch = pitch


func _process(delta: float) -> void:
	if not _has_state:
		return
	var w := minf(delta * LERP_SPEED, 1.0)
	global_position = global_position.lerp(_target_pos, w)
	rotation.y = lerp_angle(rotation.y, _target_yaw, w)
	head.rotation.x = lerp_angle(head.rotation.x, _target_pitch, w)
