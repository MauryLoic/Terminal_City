extends CharacterBody3D
## Contrôleur FPS minimal.
## Les touches utilisent les keycodes PHYSIQUES : ZQSD fonctionne
## automatiquement sur un clavier AZERTY (positions WASD).

const SPEED := 6.0
const SPRINT_SPEED := 9.5
const CROUCH_SPEED := 3.0
const JUMP_VELOCITY := 4.8
const GRAVITY := 14.0
const MOUSE_SENSITIVITY := 0.002
const SHOOT_FORCE := 10.0
const FIRE_RATE := 9.0   # balles/seconde en tir maintenu (cadence type AK)
const LOCK_TIME := 1.2       # secondes de visée maintenue pour le lock complet
const SPREAD_MAX := 0.075    # dispersion (rad) sans lock (~4.3 deg) : on rate
const SPREAD_MIN := 0.003    # dispersion au lock complet (~0.17 deg)

const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0
const STAMINA_DRAIN := 22.0        # /s en sprint
const STAMINA_REGEN := 14.0        # /s en marchant ou à l'arrêt
const STAMINA_SPRINT_AGAIN := 15.0 # seuil pour re-sprinter après épuisement
const POISON_DPS := 6.0            # dégâts/s dans l'eau toxique
const WATER_LEVEL := -1.1

const LASER_DAMAGE := 3.0     # dégâts du rayon (= 3 balles lockées)
const LASER_COOLDOWN := 3.0   # le rayon reste visible 3 s avant le tir suivant

const BulletScript := preload("res://scripts/bullet.gd")
const LaserBeamScript := preload("res://scripts/laser_beam.gd")

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D
@onready var spring_arm: SpringArm3D = $Camera3D/SpringArm3D
@onready var tp_camera: Camera3D = $Camera3D/SpringArm3D/TPCamera
@onready var visual: Node3D = $Visual
@onready var fp_gun: Node3D = $Camera3D/Gun
@onready var col_shape: CollisionShape3D = $CollisionShape3D
@onready var health_bar: ProgressBar = $HUD/Bars/HealthBar
@onready var stamina_bar: ProgressBar = $HUD/Bars/StaminaBar
@onready var reticle: Control = $HUD/Reticle
@onready var fire_mode_label: Label = $HUD/FireMode
@onready var laser_gun: Node3D = $Camera3D/LaserGun

var health := MAX_HEALTH
var stamina := MAX_STAMINA
var spawn_position := Vector3.ZERO   # renseigné par main.gd

var third_person := false
var crouching := false
var _crouch_toggled := false
var _can_sprint := true
var _fire_cd := 0.0
enum Weapon { AK, LASER }

var weapon: int = Weapon.AK
var _laser_cd := 0.0
var _burst_left := 0
var _prev_fire_pressed := false
var _lock := 0.0                 # progression du lock de visée (0..1)
var _lock_target: Node3D = null


func _ready() -> void:
	add_to_group("player")
	ray.add_exception(self)
	spring_arm.add_excluded_object(get_rid())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_weapon_ui()


func _unhandled_input(event: InputEvent) -> void:
	# Vue à la souris
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x, -1.4, 1.4)

	# Alt+E : bascule première personne / troisième personne (comme Neocron)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_E and event.alt_pressed:
		_toggle_view()

	# C : accroupissement verrouillé (on reste baissé jusqu'au prochain C)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_C:
		_crouch_toggled = not _crouch_toggled

	# 1 / 2 : changement d'arme (le laser doit avoir été construit)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_1 and weapon != Weapon.AK:
			weapon = Weapon.AK
			Sfx.play_click()
			_update_weapon_ui()
		elif event.physical_keycode == KEY_2 and weapon != Weapon.LASER:
			if _owns_laser():
				weapon = Weapon.LASER
				Sfx.play_click()
				_update_weapon_ui()
			else:
				fire_mode_label.text = "LASER : à construire d'abord"


	# Echap : libérer / recapturer la souris
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Clic gauche quand la souris est libre : la recapturer
	# (le tir lui-même est géré en continu dans _physics_process)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_fire_cd = 0.25   # petit délai pour ne pas tirer sur le clic de recapture


func _physics_process(delta: float) -> void:
	# Gravité et saut
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_physical_key_pressed(KEY_SPACE) and not crouching:
		velocity.y = JUMP_VELOCITY

	# Accroupissement (Ctrl maintenu) : capsule raccourcie, caméra abaissée
	var want_crouch := Input.is_physical_key_pressed(KEY_CTRL) or _crouch_toggled
	if want_crouch != crouching:
		crouching = want_crouch
		var cap: CapsuleShape3D = col_shape.shape
		cap.height = 1.2 if crouching else 1.8
		col_shape.position.y = 0.6 if crouching else 0.9
	camera.position.y = lerpf(camera.position.y, 1.05 if crouching else 1.6, minf(delta * 10.0, 1.0))

	# Déplacement ZQSD (positions physiques WASD)
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		dir -= transform.basis.z
	if Input.is_physical_key_pressed(KEY_S):
		dir += transform.basis.z
	if Input.is_physical_key_pressed(KEY_A):
		dir -= transform.basis.x
	if Input.is_physical_key_pressed(KEY_D):
		dir += transform.basis.x
	dir.y = 0.0
	dir = dir.normalized()

	var speed := SPEED
	var moving := dir != Vector3.ZERO
	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT) and moving \
			and not crouching and _can_sprint and stamina > 0.0
	if crouching:
		speed = CROUCH_SPEED
	elif sprinting:
		speed = SPRINT_SPEED

	# Endurance : le sprint la consomme, marcher/s'arrêter la régénère.
	# Une fois vidée, il faut remonter à un seuil avant de re-sprinter
	# (évite le sprint saccadé à 0).
	if sprinting:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
		if stamina == 0.0:
			_can_sprint = false
	else:
		stamina = minf(stamina + STAMINA_REGEN * delta, MAX_STAMINA)
		if not _can_sprint and stamina >= STAMINA_SPRINT_AGAIN:
			_can_sprint = true

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	move_and_slide()

	# Eau toxique : rester dedans empoisonne
	if global_position.y < WATER_LEVEL + 0.25:
		health -= POISON_DPS * delta
		if health <= 0.0:
			_die()

	health_bar.value = health
	stamina_bar.value = stamina

	# Réticule façon Neocron : crochets autour de l'ennemi sous le viseur
	var aimed: Node3D = null
	if ray.is_colliding():
		var c := ray.get_collider()
		if c is Node3D and c.is_in_group("bat"):
			aimed = c
	# Lock progressif : la visée maintenue sur la même cible resserre le
	# réticule et la dispersion. Quitter la cible fait décroître le lock
	# rapidement (un bref écart ne remet pas tout à zéro).
	if aimed != null:
		if aimed != _lock_target:
			_lock_target = aimed
			_lock = 0.0
		_lock = minf(_lock + delta / LOCK_TIME, 1.0)
	else:
		_lock = maxf(_lock - delta * 2.5, 0.0)
		if _lock == 0.0:
			_lock_target = null
	reticle.target = aimed
	reticle.lock_ratio = _lock

	# Tir : AK en rafales de 3, ou laser (un rayon puis 3 s d'attente)
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_laser_cd = maxf(_laser_cd - delta, 0.0)
	var fire_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if weapon == Weapon.AK:
		if fire_pressed and not _prev_fire_pressed \
				and _burst_left == 0 and _fire_cd == 0.0:
			_burst_left = 3
		if _burst_left > 0 and _fire_cd == 0.0:
			_burst_left -= 1
			_fire_cd = (1.0 / FIRE_RATE) if _burst_left > 0 else 0.35
			_shoot()
	else:
		if fire_pressed and not _prev_fire_pressed and _laser_cd == 0.0:
			_laser_cd = LASER_COOLDOWN
			_shoot_laser()
	_prev_fire_pressed = fire_pressed


func _shoot() -> void:
	# Point de départ de la balle : canon de l'AK (celle du personnage en
	# 3e personne, celle de la vue FPS sinon). La visée reste la caméra.
	var muzzle: Vector3
	if third_person and visual.has_node("AK47/Muzzle"):
		muzzle = visual.get_node("AK47/Muzzle").global_position
	else:
		muzzle = camera.global_transform * Vector3(0.2, -0.2, -0.7)
	# Dispersion : cône aléatoire dont l'angle se resserre avec le lock.
	# Sans lock, l'AK arrose (~2.6 deg) ; visée maintenue = balles précises.
	var spread := lerpf(SPREAD_MAX, SPREAD_MIN, _lock)
	var ang := randf_range(0.0, TAU)
	var dev := randf() * spread
	var b := camera.global_transform.basis
	var aim_dir := (-b.z + b.x * cos(ang) * dev + b.y * sin(ang) * dev).normalized()

	Sfx.play_gunshot(muzzle)

	# En ligne : notifier le serveur (les autres clients rejoueront le tir)
	Net.send_shoot(muzzle, aim_dir)

	# Raycast le long de la direction déviée (le RayCast3D du centre-écran
	# ne sert plus qu'à la détection de cible du réticule)
	var from: Vector3 = camera.global_position
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + aim_dir * 100.0)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)

	var target: Vector3
	var normal := Vector3.ZERO
	var collider: Object = null
	if hit:
		target = hit.position
		normal = hit.normal
		collider = hit.collider
	else:
		# Tir dans le vide : la balle vole tout droit sur 100 m puis disparaît
		target = from + aim_dir * 100.0

	var bullet := BulletScript.new()
	bullet.setup(muzzle, target, normal, collider, aim_dir * SHOOT_FORCE)
	# Sans lock, les balles qui touchent quand même font moitié moins mal
	bullet.damage = lerpf(0.5, 1.0, _lock)
	get_tree().current_scene.add_child(bullet)


func _toggle_view() -> void:
	third_person = not third_person
	visual.visible = third_person
	_update_viewmodels()
	if third_person:
		tp_camera.make_current()
	else:
		camera.make_current()


## Subir des dégâts (acide des chauves-souris, poison...).
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		_die()


## Soin (trousse de soin de l'inventaire).
func heal(amount: float) -> void:
	health = minf(health + amount, MAX_HEALTH)


## Mort : retour au point de spawn, vie et endurance restaurées,
## mais TOUT l'inventaire est perdu.
func _die() -> void:
	health = MAX_HEALTH
	stamina = MAX_STAMINA
	_can_sprint = true
	velocity = Vector3.ZERO
	Inventory.clear()
	if spawn_position != Vector3.ZERO:
		global_position = spawn_position


## --- Système d'armes ---

func _owns_laser() -> bool:
	for id in Inventory.items:
		if String(id).begins_with("laser_slots_"):
			return true
	return false


func _update_weapon_ui() -> void:
	fire_mode_label.text = "AK — RAFALE x3" if weapon == Weapon.AK else "PISTOLET LASER"
	_update_viewmodels()


func _update_viewmodels() -> void:
	fp_gun.visible = not third_person and weapon == Weapon.AK
	laser_gun.visible = not third_person and weapon == Weapon.LASER


## Tir laser : rayon hitscan précis, gros dégâts, visible 3 secondes.
func _shoot_laser() -> void:
	var muzzle: Vector3 = camera.global_transform * Vector3(0.22, -0.2, -0.78)
	var spread := lerpf(0.02, 0.001, _lock)
	var ang := randf_range(0.0, TAU)
	var dev := randf() * spread
	var b := camera.global_transform.basis
	var aim_dir := (-b.z + b.x * cos(ang) * dev + b.y * sin(ang) * dev).normalized()

	Sfx.play_laser(muzzle)
	Net.send_shoot(muzzle, aim_dir)

	var from: Vector3 = camera.global_position
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + aim_dir * 120.0)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)

	var beam := LaserBeamScript.new()
	if hit:
		beam.setup(muzzle, hit.position, hit.normal, hit.collider,
				LASER_DAMAGE * lerpf(0.5, 1.0, _lock))
	else:
		beam.setup(muzzle, from + aim_dir * 120.0, Vector3.ZERO, null, 0.0)
	get_tree().current_scene.add_child(beam)
