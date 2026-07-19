extends Node
## Autoload "Net" — client réseau UDP.
## Protocole JSON documenté dans PROTOCOL.md (à implémenter en miroir
## côté serveur Akka/Pekko IO UDP).
##
## Cycle de vie :
##   connect_to_server() -> envoie "join" (avec retry, UDP peut perdre
##   des paquets) -> reçoit "welcome" (id + seed du monde) -> envoie la
##   position du joueur local à 20 Hz + un ping toutes les 2 s.
##   Timeout de 6 s sans nouvelles du serveur -> déconnexion.

signal connected(my_id: int, world_seed: int)
signal disconnected(reason: String)
signal player_joined(id: int, player_name: String)
signal player_left(id: int)
signal state_received(players: Array)
signal remote_shot(id: int, origin: Vector3, direction: Vector3)
signal ping_measured(ms: int)

const SEND_HZ := 20.0          # fréquence d'envoi de la position
const JOIN_RETRY := 1.0        # renvoi du "join" tant que pas de "welcome"
const PING_EVERY := 2.0
const TIMEOUT := 6.0           # silence serveur -> déconnexion

var my_id := -1
var local_player: Node3D = null   # assigné par main.gd

var _udp := PacketPeerUDP.new()
var _active := false
var _joined := false
var _player_name := "Runner"
var _seq := 0                  # numéro de séquence des paquets "pos"
var _send_t := 0.0
var _join_t := 0.0
var _ping_t := 0.0
var _last_recv := 0.0


func is_online() -> bool:
	return _active and _joined


func connect_to_server(host: String, port: int, player_name: String) -> Error:
	disconnect_from_server(true)
	_player_name = player_name if player_name != "" else "Runner"
	var err := _udp.connect_to_host(host, port)
	if err != OK:
		return err
	_active = true
	_joined = false
	_seq = 0
	_last_recv = _now()
	_join_t = JOIN_RETRY   # déclenche l'envoi du join immédiatement
	return OK


func disconnect_from_server(silent := false) -> void:
	if _active and _joined:
		_send_json({"t": "leave", "id": my_id})
	_udp.close()
	_active = false
	_joined = false
	my_id = -1
	if not silent:
		disconnected.emit("déconnexion")


## Appelé par player.gd à chaque tir (no-op hors ligne).
func send_shoot(origin: Vector3, dir: Vector3) -> void:
	if not is_online():
		return
	_send_json({
		"t": "shoot", "id": my_id,
		"o": [origin.x, origin.y, origin.z],
		"d": [dir.x, dir.y, dir.z],
	})


func _process(delta: float) -> void:
	if not _active:
		return
	_receive()

	var t := _now()

	# Phase de connexion : renvoyer "join" jusqu'au "welcome"
	if not _joined:
		_join_t += delta
		if _join_t >= JOIN_RETRY:
			_join_t = 0.0
			if t - _last_recv > TIMEOUT:
				_udp.close()
				_active = false
				disconnected.emit("serveur injoignable")
				return
			_send_json({"t": "join", "name": _player_name, "v": 1})
		return

	# Connecté : timeout ?
	if t - _last_recv > TIMEOUT:
		_udp.close()
		_active = false
		_joined = false
		my_id = -1
		disconnected.emit("timeout serveur")
		return

	# Position du joueur local à tick fixe
	_send_t += delta
	if _send_t >= 1.0 / SEND_HZ and is_instance_valid(local_player):
		_send_t = 0.0
		_seq += 1
		var p := local_player.global_position
		var cam: Node3D = local_player.get_node("Camera3D")
		_send_json({
			"t": "pos", "id": my_id, "seq": _seq,
			"x": snappedf(p.x, 0.001),
			"y": snappedf(p.y, 0.001),
			"z": snappedf(p.z, 0.001),
			"ry": snappedf(local_player.rotation.y, 0.001),
			"rx": snappedf(cam.rotation.x, 0.001),
		})

	# Ping périodique (mesure de latence + keepalive)
	_ping_t += delta
	if _ping_t >= PING_EVERY:
		_ping_t = 0.0
		_send_json({"t": "ping", "id": my_id, "ts": Time.get_ticks_msec()})


func _receive() -> void:
	while _udp.get_available_packet_count() > 0:
		var data = JSON.parse_string(_udp.get_packet().get_string_from_utf8())
		if data is Dictionary and data.has("t"):
			_last_recv = _now()
			_handle(data)


func _handle(m: Dictionary) -> void:
	match str(m.get("t")):
		"welcome":
			if _joined:
				return
			_joined = true
			my_id = int(m.get("id", -1))
			connected.emit(my_id, int(m.get("seed", 0)))
		"state":
			if _joined and m.get("players") is Array:
				state_received.emit(m.get("players"))
		"joined":
			if int(m.get("id", -1)) != my_id:
				player_joined.emit(int(m.get("id")), str(m.get("name", "?")))
		"left":
			player_left.emit(int(m.get("id", -1)))
		"shot":
			if int(m.get("id", -1)) != my_id and m.get("o") is Array and m.get("d") is Array:
				var o: Array = m.get("o")
				var d: Array = m.get("d")
				if o.size() == 3 and d.size() == 3:
					remote_shot.emit(int(m.get("id")),
						Vector3(o[0], o[1], o[2]),
						Vector3(d[0], d[1], d[2]))
		"pong":
			ping_measured.emit(Time.get_ticks_msec() - int(m.get("ts", 0)))


func _send_json(d: Dictionary) -> void:
	_udp.put_packet(JSON.stringify(d).to_utf8_buffer())


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
