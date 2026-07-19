extends Node3D
## Scène principale du wasteland. Orchestration du multijoueur côté client :
## spawn/despawn des joueurs distants, application des états serveur,
## rejeu des tirs distants, régénération du monde avec la seed du serveur.

const RemotePlayerScene := preload("res://scenes/remote_player.tscn")
const ConnectUiScene := preload("res://scenes/connect_ui.tscn")
const BulletScript := preload("res://scripts/bullet.gd")

var _remotes := {}   # id (int) -> instance de remote_player
var _ui: CanvasLayer


func _ready() -> void:
	# Soleil bas, chaud mais clair : ambiance poussiéreuse, pas étouffante
	$Sun.rotation_degrees = Vector3(-42.0, -60.0, 0.0)
	$Sun.light_color = Color(1.0, 0.85, 0.68)
	$Sun.light_energy = 1.4

	_place_player()

	# Réseau : le joueur local est échantillonné à 20 Hz par l'autoload Net
	Net.local_player = $Player
	Net.connected.connect(_on_connected)
	Net.disconnected.connect(_on_disconnected)
	Net.player_joined.connect(_on_player_joined)
	Net.player_left.connect(_on_player_left)
	Net.state_received.connect(_on_state)
	Net.remote_shot.connect(_on_remote_shot)

	_ui = ConnectUiScene.instantiate()
	add_child(_ui)
	_ui.connect_requested.connect(_on_connect_requested)
	_ui.disconnect_requested.connect(Net.disconnect_from_server)

	# Inventaire (touche I) et faune hostile
	add_child(preload("res://scenes/inventory_ui.tscn").instantiate())
	var spawner := Node.new()
	spawner.set_script(preload("res://scripts/bat_spawner.gd"))
	add_child(spawner)


## Pose le joueur au sol, sur la rive sud de la rivière.
func _place_player() -> void:
	var y: float = $World.get_height(0.0, 60.0)
	$Player.position = Vector3(0.0, y + 1.5, 60.0)
	$Player.spawn_position = $Player.position
	$Player.velocity = Vector3.ZERO


func _process(_delta: float) -> void:
	# Filet de sécurité : si malgré les murs le joueur passe sous le monde,
	# on le repose au spawn au lieu de le laisser tomber indéfiniment.
	if $Player.global_position.y < -40.0:
		_place_player()


func _on_connect_requested(host: String, port: int, player_name: String) -> void:
	var err := Net.connect_to_server(host, port, player_name)
	if err != OK:
		_ui.set_status("Erreur : %s" % error_string(err))


func _on_connected(_my_id: int, world_seed: int) -> void:
	# Même seed serveur = même monde pour tous les clients.
	# seed 0 = le serveur laisse le monde local tel quel.
	if world_seed != 0 and world_seed != $World.current_seed:
		$World.regenerate(world_seed)
		_place_player()


func _on_disconnected(_reason: String) -> void:
	for id in _remotes:
		_remotes[id].queue_free()
	_remotes.clear()


func _on_player_joined(id: int, player_name: String) -> void:
	_ensure_remote(id).set_player_name(player_name)


func _on_player_left(id: int) -> void:
	if _remotes.has(id):
		_remotes[id].queue_free()
		_remotes.erase(id)


## Snapshot d'état du serveur (~20 Hz) : positions de tous les joueurs.
func _on_state(players: Array) -> void:
	for m in players:
		if not m is Dictionary:
			continue
		var id := int(m.get("id", -1))
		if id < 0 or id == Net.my_id:
			continue
		var remote := _ensure_remote(id)
		remote.apply_state(
			Vector3(m.get("x", 0.0), m.get("y", 0.0), m.get("z", 0.0)),
			m.get("ry", 0.0),
			m.get("rx", 0.0)
		)


func _ensure_remote(id: int) -> Node3D:
	if not _remotes.has(id):
		var remote := RemotePlayerScene.instantiate()
		remote.set_player_name("Runner %d" % id)
		add_child(remote)
		_remotes[id] = remote
	return _remotes[id]


## Tir d'un joueur distant : on refait le raycast localement (l'origine et
## la direction viennent du serveur) puis on rejoue la balle traçante et
## l'impact — purement cosmétique, comme pour le tir local.
func _on_remote_shot(_id: int, origin: Vector3, direction: Vector3) -> void:
	var dir := direction.normalized()
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 100.0)
	var hit := space.intersect_ray(query)

	var bullet := BulletScript.new()
	if hit:
		bullet.setup(origin, hit.position, hit.normal, hit.collider, dir * 10.0)
	else:
		bullet.setup(origin, origin + dir * 100.0, Vector3.ZERO, null, Vector3.ZERO)
	add_child(bullet)
