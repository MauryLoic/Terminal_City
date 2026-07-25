extends Node
## Warbot management: spawns a handful of lone robots scattered across
## the whole map at startup. Each destroyed warbot respawns 20 s later
## at a new random spot on the map (not tied to the player).

const WarbotScript := preload("res://scripts/warbot.gd")
const MobRank := preload("res://scripts/mob_rank.gd")
const COUNT := 9
const RESPAWN_DELAY := 8.0
const HALF := 100.0


func _ready() -> void:
	for i in COUNT:
		_spawn()
	# Safety net: every few seconds, top the population back up to COUNT
	# (covers any respawn that failed to find a valid spot)
	var t := Timer.new()
	t.wait_time = 5.0
	t.autostart = true
	t.timeout.connect(_maintain)
	add_child(t)


func _maintain() -> void:
	var alive := 0
	for n in get_tree().get_nodes_in_group("mob"):
		if n.get_script() == WarbotScript:
			alive += 1
	for i in range(alive, COUNT):
		_spawn()


func _spawn() -> void:
	var world := get_tree().current_scene.get_node_or_null("World")
	if world == null:
		return
	# Look for a spot out of the toxic water, in the main zone (south of
	# the mountain massif — the base/canyon sit at negative z)
	for attempt in 30:
		var x := randf_range(-HALF, HALF)
		var z := randf_range(-HALF, 45.0)   # keep them in the open bowl
		var h: float = world.get_height(x, z)
		if h <= world.WATER_Y + 1.0 or world._in_base_area(x, z):
			continue
		if h > 14.0:   # skip steep mountain slopes
			continue
		var bot := CharacterBody3D.new()
		bot.set_script(WarbotScript)
		bot.level = MobRank.roll_level(24, 42)   # main-zone patrols
		bot.position = Vector3(x, h + 0.5, z)
		get_tree().current_scene.add_child(bot)
		bot.died.connect(_on_warbot_died)
		return


func _on_warbot_died(_pos: Vector3) -> void:
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_spawn)
