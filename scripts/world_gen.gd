extends Node3D
## Procedural generator of the post-nuclear wasteland (deterministic seed).
##
## Material system: every scenery object carries metadata
## read by bullet.gd on impact:
##   "mat"          : "dirt" | "stone" | "wood" | "bush" | "metal"
##                    -> impact visual (impact.gd)
##   "hp"           : hit points; absent = indestructible
##   "debris_color" / "debris_count" / "debris_size": destruction effect
## RigidBody3D nodes (rocks, junk, barrels) are pushed by bullets;
## their mass determines how fast they move.

const SIZE := 240.0          # world size (meters)
const N := 121               # vertices per grid side
const WATER_Y := -1.1        # toxic water level
const WORLD_SEED := 1337

const TREE_COUNT := 35
const BUSH_COUNT := 90
const ROCK_COUNT := 45
const BUILDING_COUNT := 4
const SHACK_COUNT := 5
const JUNK_COUNT := 30

var current_seed := WORLD_SEED

var _noise := FastNoiseLite.new()
var _noise_big := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_generate(WORLD_SEED)


## Regenerates the whole world with a new seed (sent by the server
## on connection: same seed = same world for every client).
func regenerate(new_seed: int) -> void:
	if new_seed == current_seed:
		return
	for child in get_children():
		child.queue_free()
	_generate(new_seed)


func _generate(world_seed: int) -> void:
	current_seed = world_seed
	_rng.seed = world_seed
	_noise.seed = world_seed
	_noise.frequency = 0.02
	_noise.fractal_octaves = 4
	_noise_big.seed = world_seed + 1
	_noise_big.frequency = 0.006

	_build_terrain()
	_build_water()
	_build_borders()
	_scatter_props()


## Terrain height at (x, z), river already carved.
func get_height(x: float, z: float) -> float:
	var h := _noise.get_noise_2d(x, z) * 4.0 + _noise_big.get_noise_2d(x, z) * 13.0 + 2.5
	var d := absf(z - _river_center(x))
	var t := clampf(1.0 - d / 14.0, 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	h = lerpf(h, -3.5, t)

	# Peripheral dune mountains: the terrain rises sharply toward the
	# edges to hide the world boundary (applied AFTER the river,
	# which thus seems to flow down from the hills). Noise makes the crests
	# irregular, like real dunes.
	var edge := maxf(absf(x), absf(z)) / (SIZE * 0.5)
	var rim := smoothstep(0.7, 1.0, edge)
	if rim > 0.0:
		var dune := 1.0 + 0.35 * _noise.get_noise_2d(x * 0.6 + 500.0, z * 0.6)
		h += rim * rim * 28.0 * dune
	return h


func _river_center(x: float) -> float:
	return 22.0 * sin(x * 0.02) + 6.0 * sin(x * 0.055)


func _build_terrain() -> void:
	var step := SIZE / float(N - 1)
	var half := SIZE * 0.5

	var heights := PackedFloat32Array()
	heights.resize(N * N)
	for iz in N:
		for ix in N:
			heights[iz * N + ix] = get_height(-half + ix * step, -half + iz * step)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var add_vert := func(ix: int, iz: int) -> void:
		var y := heights[iz * N + ix]
		st.set_color(_ground_color(y, -half + ix * step, -half + iz * step))
		st.add_vertex(Vector3(-half + ix * step, y, -half + iz * step))

	for iz in N - 1:
		for ix in N - 1:
			add_vert.call(ix, iz)
			add_vert.call(ix + 1, iz)
			add_vert.call(ix, iz + 1)
			add_vert.call(ix + 1, iz)
			add_vert.call(ix + 1, iz + 1)
			add_vert.call(ix, iz + 1)

	st.generate_normals()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	st.set_material(mat)

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = st.commit()
	add_child(mesh_inst)

	var body := StaticBody3D.new()
	body.set_meta("mat", "dirt")
	var col := CollisionShape3D.new()
	var hshape := HeightMapShape3D.new()
	hshape.map_width = N
	hshape.map_depth = N
	hshape.map_data = heights
	col.shape = hshape
	col.scale = Vector3(step, 1.0, step)
	body.add_child(col)
	add_child(body)


func _ground_color(y: float, x: float, z: float) -> Color:
	var variation := 0.9 + 0.2 * _noise.get_noise_2d(x * 3.0, z * 3.0)
	var c: Color
	if y < WATER_Y + 0.6:
		c = Color(0.24, 0.2, 0.13)
	else:
		var t := clampf((y + 1.0) / 12.0, 0.0, 1.0)
		c = Color(0.42, 0.26, 0.16).lerp(Color(0.76, 0.5, 0.3), t)
	return c * variation


func _build_water() -> void:
	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.55, 0.18, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.5, 0.1)
	mat.emission_energy_multiplier = 0.35
	mat.roughness = 0.15
	plane.material = mat
	mesh_inst.mesh = plane
	mesh_inst.position = Vector3(0, WATER_Y, 0)
	add_child(mesh_inst)


## Invisible walls all around the world: impossible to fall into the
## void. They react to bullets like stone.
func _build_borders() -> void:
	var body := StaticBody3D.new()
	body.set_meta("mat", "stone")
	var half := SIZE * 0.5
	var walls: Array = [
		[Vector3(SIZE + 4.0, 60.0, 2.0), Vector3(0, 20.0, -half - 1.0)],
		[Vector3(SIZE + 4.0, 60.0, 2.0), Vector3(0, 20.0, half + 1.0)],
		[Vector3(2.0, 60.0, SIZE + 4.0), Vector3(-half - 1.0, 20.0, 0)],
		[Vector3(2.0, 60.0, SIZE + 4.0), Vector3(half + 1.0, 20.0, 0)],
	]
	for w: Array in walls:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = w[0]
		cs.shape = bs
		cs.position = w[1]
		body.add_child(cs)
	add_child(body)


func _scatter_props() -> void:
	var half := SIZE * 0.5 - 8.0

	for i in BUILDING_COUNT:
		var p := _find_flat_spot(half * 0.8, 4.5, 30)
		if p != Vector3.INF:
			var b := _make_stone_building()
			b.position = p - Vector3(0, 0.2, 0)
			b.rotation.y = _rng.randf_range(0.0, TAU)
			add_child(b)

	for i in SHACK_COUNT:
		var p := _find_flat_spot(half * 0.9, 2.5, 30)
		if p != Vector3.INF:
			var s := _make_shack()
			s.position = p - Vector3(0, 0.2, 0)
			s.rotation.y = _rng.randf_range(0.0, TAU)
			add_child(s)

	for i in TREE_COUNT:
		var p := _random_ground_point(half)
		if p.y > WATER_Y + 0.8:
			var tree := _make_dead_tree()
			tree.position = p
			tree.rotation.y = _rng.randf_range(0.0, TAU)
			add_child(tree)

	for i in BUSH_COUNT:
		var p := _random_ground_point(half)
		if p.y > WATER_Y + 0.6:
			add_child(_make_bush(p))

	for i in ROCK_COUNT:
		var p := _random_ground_point(half)
		if p.y > WATER_Y + 0.2:
			add_child(_make_rock(p))

	for i in JUNK_COUNT:
		var p := _random_ground_point(half)
		if p.y > WATER_Y + 0.4:
			add_child(_make_junk(p))


func _random_ground_point(half: float) -> Vector3:
	var x := _rng.randf_range(-half, half)
	var z := _rng.randf_range(-half, half)
	return Vector3(x, get_height(x, z), z)


## Looks for a flat spot (height difference < 0.9 m over the given
## radius) out of the water. Returns Vector3.INF if none found.
func _find_flat_spot(half: float, radius: float, tries: int) -> Vector3:
	for i in tries:
		var x := _rng.randf_range(-half, half)
		var z := _rng.randf_range(-half, half)
		var h0 := get_height(x, z)
		if h0 <= WATER_Y + 1.2:
			continue
		var flat := true
		for off: Vector2 in [Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
			if absf(get_height(x + off.x, z + off.y) - h0) > 0.9:
				flat = false
				break
		if flat:
			return Vector3(x, h0, z)
	return Vector3.INF


## Dead tree: trunk + branches, with collision on the trunk.
## Destructible in a few bullets (wood).
func _make_dead_tree() -> StaticBody3D:
	var tree := StaticBody3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.2, 0.15)
	mat.roughness = 1.0

	var h := _rng.randf_range(4.0, 7.0)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.top_radius = 0.07
	trunk_mesh.height = h
	trunk_mesh.material = mat
	trunk.mesh = trunk_mesh
	trunk.position.y = h * 0.5
	tree.add_child(trunk)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.25
	cyl.height = h
	col.shape = cyl
	col.position.y = h * 0.5
	tree.add_child(col)

	var branch_count := _rng.randi_range(3, 5)
	for i in branch_count:
		var pivot := Node3D.new()
		pivot.position.y = h * _rng.randf_range(0.55, 0.9)
		pivot.rotation.y = _rng.randf_range(0.0, TAU)
		pivot.rotation.z = _rng.randf_range(0.9, 1.4)
		var blen := _rng.randf_range(1.0, 2.2)
		var branch := MeshInstance3D.new()
		var bmesh := CylinderMesh.new()
		bmesh.bottom_radius = 0.07
		bmesh.top_radius = 0.02
		bmesh.height = blen
		bmesh.material = mat
		branch.mesh = bmesh
		branch.position.y = blen * 0.5
		pivot.add_child(branch)
		tree.add_child(pivot)

	tree.set_meta("mat", "wood")
	tree.set_meta("hp", 8.0)
	tree.set_meta("debris_color", mat.albedo_color)
	tree.set_meta("debris_count", 12)
	tree.set_meta("debris_size", 0.18)
	return tree


## Dry bush: fragile, destroyed in two bullets.
func _make_bush(p: Vector3) -> StaticBody3D:
	var bush := StaticBody3D.new()
	var r := _rng.randf_range(0.35, 0.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.33, 0.18) * _rng.randf_range(0.8, 1.1)
	mat.roughness = 1.0

	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r
	mesh.material = mat
	mi.mesh = mesh
	mi.scale = Vector3(1.0, 0.55, 1.0)
	mi.position.y = r * 0.25
	bush.add_child(mi)

	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = r * 0.7
	col.shape = sphere
	col.position.y = r * 0.25
	bush.add_child(col)

	bush.position = p
	bush.set_meta("mat", "bush")
	bush.set_meta("hp", 2.0)
	bush.set_meta("debris_color", mat.albedo_color)
	bush.set_meta("debris_count", 6)
	bush.set_meta("debris_size", 0.1)
	return bush


## Rock: indestructible but pushable RigidBody3D — its mass (based on
## its size) means it barely moves when shot.
func _make_rock(p: Vector3) -> RigidBody3D:
	var rock := RigidBody3D.new()
	var size := Vector3(
		_rng.randf_range(0.6, 2.2),
		_rng.randf_range(0.5, 1.6),
		_rng.randf_range(0.6, 2.2)
	)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.33, 0.3) * _rng.randf_range(0.85, 1.1)
	mat.roughness = 1.0

	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	rock.add_child(mi)

	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	rock.add_child(col)

	rock.mass = clampf(size.x * size.y * size.z * 35.0, 5.0, 160.0)
	rock.position = p + Vector3(0, size.y * 0.6, 0)
	rock.rotation.y = _rng.randf_range(0.0, TAU)
	rock.set_meta("mat", "stone")
	return rock


## Scattered junk: light planks (fly when shot), medium
## stone blocks, rusty metal barrels. Varied masses = varied reactions
## to the weapon.
func _make_junk(p: Vector3) -> RigidBody3D:
	var junk := RigidBody3D.new()
	var roll := _rng.randf()

	if roll < 0.4:
		# Wooden plank, very light: goes flying at the slightest shot
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.42, 0.28, 0.14) * _rng.randf_range(0.85, 1.1)
		mat.roughness = 1.0
		var size := Vector3(_rng.randf_range(0.7, 1.1), 0.06, 0.22)
		_junk_box(junk, size, mat)
		junk.mass = 1.0
		junk.set_meta("mat", "wood")
		junk.set_meta("hp", 4.0)
		junk.set_meta("debris_color", mat.albedo_color)
		junk.set_meta("debris_count", 5)
		junk.set_meta("debris_size", 0.1)
	elif roll < 0.7:
		# Medium stone block: moves a little
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.44, 0.4) * _rng.randf_range(0.85, 1.1)
		mat.roughness = 1.0
		var size := Vector3.ONE * _rng.randf_range(0.3, 0.5)
		_junk_box(junk, size, mat)
		junk.mass = 4.0
		junk.set_meta("mat", "stone")
	else:
		# Rusty metal barrel: heavy, slowly destructible
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.45, 0.3, 0.2) * _rng.randf_range(0.85, 1.1)
		mat.roughness = 0.6
		mat.metallic = 0.4
		var mi := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.35
		mesh.bottom_radius = 0.35
		mesh.height = 0.9
		mesh.material = mat
		mi.mesh = mesh
		junk.add_child(mi)
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.35
		cyl.height = 0.9
		col.shape = cyl
		junk.add_child(col)
		junk.mass = 12.0
		junk.set_meta("mat", "metal")
		junk.set_meta("hp", 12.0)
		junk.set_meta("debris_color", mat.albedo_color)
		junk.set_meta("debris_count", 9)
		junk.set_meta("debris_size", 0.14)

	junk.position = p + Vector3(0, 0.6, 0)
	junk.rotation.y = _rng.randf_range(0.0, TAU)
	return junk


func _junk_box(body: RigidBody3D, size: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	mi.mesh = mesh
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	body.add_child(col)


## Adds a block (mesh + collision) to a StaticBody3D, the basic building
## brick of the buildings.
func _add_block(body: StaticBody3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	mi.rotation = rot
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	cs.rotation = rot
	body.add_child(cs)


## Stone building: INDESTRUCTIBLE (just stone chips).
func _make_stone_building() -> StaticBody3D:
	var b := StaticBody3D.new()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.56, 0.53, 0.48) * _rng.randf_range(0.85, 1.05)
	stone.roughness = 1.0

	var w := _rng.randf_range(6.0, 8.0)
	var d := _rng.randf_range(4.5, 6.0)
	var h := _rng.randf_range(2.8, 3.4)
	var t := 0.4
	var door := 1.6

	_add_block(b, Vector3(w - 0.1, 0.3, d - 0.1), Vector3(0, 0.15, 0), stone)
	_add_block(b, Vector3(door, 0.3, 1.0), Vector3(0, 0.15, d * 0.5 + 0.45), stone)

	_add_block(b, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5), stone)
	_add_block(b, Vector3(t, h, d), Vector3(-w * 0.5, h * 0.5, 0), stone)
	if _rng.randf() < 0.5:
		_add_block(b, Vector3(t, h, d), Vector3(w * 0.5, h * 0.5, 0), stone)
	else:
		var rh := h * 0.45
		_add_block(b, Vector3(t, rh, d), Vector3(w * 0.5, rh * 0.5, 0), stone)
	var seg := (w - door) * 0.5
	_add_block(b, Vector3(seg, h, t), Vector3(-(door + seg) * 0.5, h * 0.5, d * 0.5), stone)
	_add_block(b, Vector3(seg, h, t), Vector3((door + seg) * 0.5, h * 0.5, d * 0.5), stone)
	_add_block(b, Vector3(door, 0.5, t), Vector3(0, h - 0.25, d * 0.5), stone)
	if _rng.randf() < 0.5:
		_add_block(b, Vector3(w + 0.4, 0.25, d + 0.4), Vector3(0, h + 0.125, 0), stone)

	b.set_meta("mat", "stone")
	return b


## Wooden shack: SLOWLY destructible (it absorbs ~45 bullets
## before collapsing into debris).
func _make_shack() -> StaticBody3D:
	var b := StaticBody3D.new()
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.38, 0.25, 0.13) * _rng.randf_range(0.85, 1.1)
	wood.roughness = 1.0
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.38, 0.34, 0.32)
	metal.roughness = 0.7
	metal.metallic = 0.3

	var w := _rng.randf_range(3.0, 4.0)
	var d := _rng.randf_range(2.6, 3.4)
	var h := _rng.randf_range(2.0, 2.4)
	var t := 0.15

	_add_block(b, Vector3(w - 0.05, 0.2, d - 0.05), Vector3(0, 0.1, 0), wood)
	_add_block(b, Vector3(1.6, 0.2, 0.8), Vector3(0, 0.1, d * 0.5 + 0.35), wood)

	_add_block(b, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5), wood)
	_add_block(b, Vector3(t, h, d), Vector3(-w * 0.5, h * 0.5, 0), wood)
	var rh := h * _rng.randf_range(0.5, 1.0)
	_add_block(b, Vector3(t, rh, d), Vector3(w * 0.5, rh * 0.5, 0), wood)
	_add_block(b, Vector3(t, h, t), Vector3(w * 0.3, h * 0.5, d * 0.5), wood)
	_add_block(b, Vector3(w + 0.5, 0.08, d + 0.5), Vector3(0, h + 0.02, 0), metal,
		Vector3(0, 0, _rng.randf_range(0.06, 0.14)))

	b.set_meta("mat", "wood")
	b.set_meta("hp", 45.0)
	b.set_meta("debris_color", wood.albedo_color)
	b.set_meta("debris_count", 26)
	b.set_meta("debris_size", 0.28)
	return b
