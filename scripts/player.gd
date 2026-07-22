extends CharacterBody3D
## Minimal FPS controller.
## Keys use PHYSICAL keycodes: ZQSD works
## automatically on an AZERTY keyboard (WASD positions).

const SPEED := 6.0
const SPRINT_SPEED := 9.5
const CROUCH_SPEED := 3.0
const JUMP_VELOCITY := 4.8
const GRAVITY := 14.0
const MOUSE_SENSITIVITY := 0.002
const SHOOT_FORCE := 10.0
const FIRE_RATE := 9.0   # bullets/second while firing (AK-like rate)
const AK_AMMO_START := 100
const LASER_AMMO_START := 6
const AK_AMMO_RESPAWN := 30     # given back on death so you can still fight
const LASER_AMMO_RESPAWN := 2
const FOV_ZOOM := 48.0       # aimed-in field of view (right click held)
const ZOOM_SPEED := 10.0     # FOV transition speed
const ZOOM_SENS_FACTOR := 0.6  # mouse sensitivity multiplier while zoomed
const LOCK_TIME := 1.2       # seconds of sustained aim for a full lock
const SPREAD_MAX := 0.075    # spread (rad) without lock (~4.3 deg): you miss
const SPREAD_MIN := 0.003    # spread at full lock (~0.17 deg)

const MAX_HEALTH := 100.0
const MAX_STAMINA := 100.0
const STAMINA_DRAIN := 22.0        # /s while sprinting
const STAMINA_REGEN := 14.0        # /s while walking or standing still
const STAMINA_SPRINT_AGAIN := 15.0 # threshold to sprint again after exhaustion
const POISON_DPS := 6.0            # damage/s in toxic water
const WATER_LEVEL := -1.1

const LASER_DAMAGE := 3.0     # beam damage (= 3 locked bullets)
const LASER_COOLDOWN := 3.0   # the beam stays visible 3 s before the next shot
const MELEE_DAMAGE := 1.5
const MELEE_RANGE := 2.4
const MELEE_COOLDOWN := 0.7
const SABER_DAMAGE := 4.0
const SABER_RANGE := 2.8
const BURN_DPS := 6.0        # blue bat fire ray: damage per second

const BulletScript := preload("res://scripts/bullet.gd")
const LaserBeamScript := preload("res://scripts/laser_beam.gd")
const HitEffects := preload("res://scripts/hit_effects.gd")

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
@onready var crowbar: Node3D = $Camera3D/Crowbar
@onready var saber: Node3D = $Camera3D/Saber

var health := MAX_HEALTH
var stamina := MAX_STAMINA
var spawn_position := Vector3.ZERO   # filled in by main.gd

var third_person := false
var crouching := false
var _crouch_toggled := false
var _can_sprint := true
var _fire_cd := 0.0
enum Weapon { AK, LASER, MELEE }

var weapon: int = Weapon.AK
var _laser_cd := 0.0
var _melee_cd := 0.0
var _burn_t := 0.0
var _burn_overlay: ColorRect
var _burst_left := 0
var _prev_fire_pressed := false
var _lock := 0.0                 # aim lock progress (0..1)
var _lock_target: Node3D = null
var ak_ammo := AK_AMMO_START
var laser_ammo := LASER_AMMO_START
var _zoomed := false
var _fov_normal := 75.0          # captured from the camera in _ready


func _ready() -> void:
	add_to_group("player")
	ray.add_exception(self)
	spring_arm.add_excluded_object(get_rid())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_update_weapon_ui()
	_fov_normal = camera.fov
	# Refresh weapon HUD/viewmodel when the inventory changes (e.g. the
	# laser saber just got crafted while melee is equipped)
	Inventory.changed.connect(_update_weapon_ui)
	# Screen tint shown while burning
	_burn_overlay = ColorRect.new()
	_burn_overlay.color = Color(1.0, 0.35, 0.05, 0.22)
	_burn_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_burn_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burn_overlay.visible = false
	$HUD.add_child(_burn_overlay)


func _unhandled_input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		# Lower sensitivity while zoomed: aiming stays steady at low FOV
		var sens := MOUSE_SENSITIVITY * (ZOOM_SENS_FACTOR if _zoomed else 1.0)
		rotate_y(-event.relative.x * sens)
		camera.rotate_x(-event.relative.y * sens)
		camera.rotation.x = clampf(camera.rotation.x, -1.4, 1.4)

	# Alt+E: toggle first person / third person (like Neocron)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_E and event.alt_pressed:
		_toggle_view()

	# C: locked crouch (stay down until the next C)
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_C:
		_crouch_toggled = not _crouch_toggled

	# 1 / 2: weapon switch (the laser must have been crafted first)
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
				fire_mode_label.text = "LASER: craft it first"
		elif event.physical_keycode == KEY_3 and weapon != Weapon.MELEE:
			weapon = Weapon.MELEE
			Sfx.play_click()
			_update_weapon_ui()


	# Escape: release / recapture the mouse
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Left click while the mouse is free: recapture it
	# (firing itself is handled continuously in _physics_process)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_fire_cd = 0.25   # small delay so the recapture click doesn't fire

	# Right click held: aim zoom, with a selector click on zoom-in.
	# Firing (left click) stays fully available while zoomed.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event.pressed and not _zoomed:
			_zoomed = true
			Sfx.play_click()
		elif not event.pressed:
			_zoomed = false


func _physics_process(delta: float) -> void:
	# Gravity and jumping
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_physical_key_pressed(KEY_SPACE) and not crouching:
		velocity.y = JUMP_VELOCITY

	# Crouching (Ctrl held): shortened capsule, lowered camera
	var want_crouch := Input.is_physical_key_pressed(KEY_CTRL) or _crouch_toggled
	if want_crouch != crouching:
		crouching = want_crouch
		var cap: CapsuleShape3D = col_shape.shape
		cap.height = 1.2 if crouching else 1.8
		col_shape.position.y = 0.6 if crouching else 0.9
	camera.position.y = lerpf(camera.position.y, 1.05 if crouching else 1.6, minf(delta * 10.0, 1.0))

	# Aim zoom: smooth FOV transition, applied to both cameras (FP and TP)
	var target_fov := FOV_ZOOM if _zoomed else _fov_normal
	camera.fov = lerpf(camera.fov, target_fov, minf(delta * ZOOM_SPEED, 1.0))
	tp_camera.fov = camera.fov

	# ZQSD movement (physical WASD positions)
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

	# Stamina: sprinting drains it, walking/standing regenerates it.
	# Once emptied, it must recover past a threshold before sprinting again
	# (avoids stuttery sprinting at 0).
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

	# Toxic water: staying in it poisons you
	if global_position.y < WATER_LEVEL + 0.25:
		health -= POISON_DPS * delta
		if health <= 0.0:
			_die()

	# Burning (blue bat fire ray): damage over time + screen tint
	if _burn_t > 0.0:
		_burn_t -= delta
		health -= BURN_DPS * delta
		if health <= 0.0:
			_die()
	_burn_overlay.visible = _burn_t > 0.0

	health_bar.value = health
	stamina_bar.value = stamina

	# Neocron-style reticle: brackets around the enemy under the crosshair
	var aimed: Node3D = null
	if ray.is_colliding():
		var c := ray.get_collider()
		if c is Node3D and c.is_in_group("mob"):
			aimed = c
	# Progressive lock: keeping aim on the same target tightens the
	# reticle and the spread. Leaving the target makes the lock decay
	# quickly (a brief slip does not reset everything).
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

	# Firing: AK in 3-round bursts, or laser (one beam then a 3 s wait)
	_fire_cd = maxf(_fire_cd - delta, 0.0)
	_laser_cd = maxf(_laser_cd - delta, 0.0)
	_melee_cd = maxf(_melee_cd - delta, 0.0)
	var fire_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
			and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if weapon == Weapon.AK:
		if fire_pressed and not _prev_fire_pressed \
				and _burst_left == 0 and _fire_cd == 0.0:
			if ak_ammo > 0:
				_burst_left = 3
			else:
				Sfx.play_click()   # dry fire: out of ammo
				_fire_cd = 0.3
		if _burst_left > 0 and _fire_cd == 0.0:
			if ak_ammo <= 0:
				_burst_left = 0   # magazine ran dry mid-burst
			else:
				ak_ammo -= 1
				_burst_left -= 1
				_fire_cd = (1.0 / FIRE_RATE) if _burst_left > 0 else 0.35
				_shoot()
				_update_weapon_ui()
	elif weapon == Weapon.LASER:
		if fire_pressed and not _prev_fire_pressed and _laser_cd == 0.0:
			if laser_ammo > 0:
				laser_ammo -= 1
				_laser_cd = LASER_COOLDOWN
				_shoot_laser()
				_update_weapon_ui()
			else:
				Sfx.play_click()   # dry fire: no cells left
				_laser_cd = 0.4
	else:
		# Crowbar: always usable, no ammo — the guaranteed fallback
		if fire_pressed and _melee_cd == 0.0:
			_melee_cd = MELEE_COOLDOWN
			_melee_attack()
	_prev_fire_pressed = fire_pressed


func _shoot() -> void:
	# Bullet origin: the AK's barrel (the character's one in
	# third person, the FPS-view one otherwise). Aiming stays camera-based.
	var muzzle: Vector3
	if third_person and visual.has_node("AK47/Muzzle"):
		muzzle = visual.get_node("AK47/Muzzle").global_position
	else:
		muzzle = camera.global_transform * Vector3(0.2, -0.2, -0.7)
	# Spread: random cone whose angle tightens with the lock.
	# Without lock the AK sprays (~2.6 deg); sustained aim = precise bullets.
	var spread := lerpf(SPREAD_MAX, SPREAD_MIN, _lock)
	var ang := randf_range(0.0, TAU)
	var dev := randf() * spread
	var b := camera.global_transform.basis
	var aim_dir := (-b.z + b.x * cos(ang) * dev + b.y * sin(ang) * dev).normalized()

	Sfx.play_gunshot(muzzle)

	# Online: notify the server (other clients will replay the shot)
	Net.send_shoot(muzzle, aim_dir)

	# Raycast along the deviated direction (the center-screen RayCast3D
	# is now only used for the reticle's target detection)
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
		# Shot into the void: the bullet flies straight for 100 m then vanishes
		target = from + aim_dir * 100.0

	var bullet := BulletScript.new()
	bullet.setup(muzzle, target, normal, collider, aim_dir * SHOOT_FORCE)
	# Without lock, bullets that still hit deal half damage
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


## Take damage (bat acid, poison...).
func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		_die()


## Healing (medkit from the inventory).
func heal(amount: float) -> void:
	health = minf(health + amount, MAX_HEALTH)


## Ammo added by the crafting window ("ak" or "laser").
func add_ammo(kind: String, n: int) -> void:
	if kind == "ak":
		ak_ammo += n
	else:
		laser_ammo += n
	_update_weapon_ui()


## Death: back to the spawn point, health and stamina restored,
## but the ENTIRE inventory is lost and ammo drops to survival rations.
func _die() -> void:
	health = MAX_HEALTH
	stamina = MAX_STAMINA
	_can_sprint = true
	velocity = Vector3.ZERO
	ak_ammo = AK_AMMO_RESPAWN
	laser_ammo = LASER_AMMO_RESPAWN
	_update_weapon_ui()
	Inventory.clear()
	if spawn_position != Vector3.ZERO:
		global_position = spawn_position


## --- Weapon system ---

func _owns_laser() -> bool:
	for id in Inventory.items:
		if String(id).begins_with("laser_slots_"):
			return true
	return false


func _update_weapon_ui() -> void:
	if weapon == Weapon.AK:
		fire_mode_label.text = "AK — BURST x3 — AMMO %d" % ak_ammo
	elif weapon == Weapon.LASER:
		fire_mode_label.text = "LASER PISTOL — CELLS %d" % laser_ammo
	else:
		fire_mode_label.text = "LASER SABER — MELEE" if _owns_saber() else "CROWBAR — MELEE"
	_update_viewmodels()


func _update_viewmodels() -> void:
	fp_gun.visible = not third_person and weapon == Weapon.AK
	laser_gun.visible = not third_person and weapon == Weapon.LASER
	var melee := not third_person and weapon == Weapon.MELEE
	var has_saber := _owns_saber()
	crowbar.visible = melee and not has_saber
	saber.visible = melee and has_saber


## Laser shot: precise hitscan beam, heavy damage, visible 3 seconds.
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


## Melee swing: short-range raycast hit, always available (no ammo).
## Guarantees the recovery loop: crowbar -> warbots -> resources ->
## ammo crafting, even with completely empty magazines.
func _melee_attack() -> void:
	var has_saber := _owns_saber()
	var vm: Node3D = saber if has_saber else crowbar
	vm.swing()
	Sfx.play_swing(camera.global_position)
	var from: Vector3 = camera.global_position
	var dir: Vector3 = -camera.global_transform.basis.z
	var reach := SABER_RANGE if has_saber else MELEE_RANGE
	var dmg := SABER_DAMAGE if has_saber else MELEE_DAMAGE
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * reach)
	query.exclude = [get_rid()]
	var hit := space.intersect_ray(query)
	if hit:
		HitEffects.resolve(self, hit.collider, hit.position, hit.normal, dmg, dir * 5.0)


func _owns_saber() -> bool:
	return int(Inventory.items.get("saber", 0)) > 0


## Fire ray hit (blue bat): burn for the given duration (stacks by
## extending, not adding).
func apply_burn(duration := 3.0) -> void:
	_burn_t = maxf(_burn_t, duration)
