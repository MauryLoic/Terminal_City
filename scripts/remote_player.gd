extends Node3D
## Remote player: purely visual, driven by states received from the server.
## Positions arrive at ~20 Hz; we smoothly interpolate toward the
## last known target for smooth rendering at any framerate.

const LERP_SPEED := 12.0

var _target_pos: Vector3
var _target_yaw := 0.0
var _target_pitch := 0.0
var _has_state := false

@onready var head: Node3D = $Head
@onready var name_label: Label3D = $NameLabel


func set_player_name(n: String) -> void:
	name_label.text = n


## New state received from the server. The first state teleports (no sliding
## from the origin), subsequent ones are interpolated in _process.
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
