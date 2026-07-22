extends CanvasLayer
## Server connection panel (F1 to show/hide).
## Escape frees the mouse (handled by player.gd) so you can click.

signal connect_requested(host: String, port: int, player_name: String)
signal disconnect_requested

const DEFAULT_PORT := 4242

@onready var host_edit: LineEdit = $Panel/VBox/HostEdit
@onready var name_edit: LineEdit = $Panel/VBox/NameEdit
@onready var button: Button = $Panel/VBox/ConnectButton
@onready var status: Label = $Panel/VBox/Status

var _online := false


func _ready() -> void:
	button.pressed.connect(_on_button_pressed)
	Net.connected.connect(_on_net_connected)
	Net.disconnected.connect(_on_net_disconnected)
	Net.ping_measured.connect(_on_ping)


func set_status(text: String) -> void:
	status.text = text


func _on_button_pressed() -> void:
	if _online:
		disconnect_requested.emit()
		return
	var parts := host_edit.text.split(":")
	var host := parts[0].strip_edges()
	var port := DEFAULT_PORT
	if parts.size() > 1 and parts[1].is_valid_int():
		port = int(parts[1])
	set_status("Connecting to %s:%d..." % [host, port])
	connect_requested.emit(host, port, name_edit.text.strip_edges())


func _on_net_connected(my_id: int, _world_seed: int) -> void:
	_online = true
	button.text = "Disconnect"
	set_status("Connected (id %d)" % my_id)


func _on_net_disconnected(reason: String) -> void:
	_online = false
	button.text = "Connect"
	set_status("Offline: %s" % reason)


func _on_ping(ms: int) -> void:
	if _online:
		set_status("Connected (id %d) — ping %d ms" % [Net.my_id, ms])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F1:
		$Panel.visible = not $Panel.visible
		# Showing the panel frees the mouse to click into the fields,
		# hiding it recaptures the mouse for gameplay.
		if $Panel.visible:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
