class_name CityWorld
extends Node3D
## Builds and owns the island, sky, water, buildings, roads and traffic.

const GROUND_SHADER := preload("res://scripts/world/ground.gdshader")
const WATER_SHADER := preload("res://scripts/world/water.gdshader")
const SKY_SHADER := preload("res://scripts/world/sky.gdshader")
const HIGHLIGHT_SHADER := preload("res://scripts/world/tile_highlight.gdshader")

const TREE_MODELS := [
	"res://assets/models/nature/tree_default.glb",
	"res://assets/models/nature/tree_default_dark.glb",
	"res://assets/models/nature/tree_detailed.glb",
	"res://assets/models/nature/tree_oak.glb",
	"res://assets/models/nature/tree_cone.glb",
	"res://assets/models/nature/tree_pineTallA.glb",
	"res://assets/models/nature/tree_palmTall.glb",
	"res://assets/models/nature/tree_fat.glb",
	"res://assets/models/nature/tree_pineRoundA.glb",
]
const SMALL_MODELS := [
	"res://assets/models/nature/plant_bush.glb",
	"res://assets/models/nature/plant_bushLarge.glb",
	"res://assets/models/nature/plant_bushDetailed.glb",
	"res://assets/models/nature/grass_large.glb",
	"res://assets/models/nature/flower_redA.glb",
	"res://assets/models/nature/flower_yellowA.glb",
	"res://assets/models/nature/flower_purpleA.glb",
	"res://assets/models/nature/mushroom_redGroup.glb",
]
const ROCK_MODELS := [
	"res://assets/models/nature/rock_largeA.glb",
	"res://assets/models/nature/rock_largeB.glb",
	"res://assets/models/nature/rock_largeC.glb",
	"res://assets/models/nature/rock_smallA.glb",
]

var buildings_root: Node3D
var roads_root: Node3D
var props_root: Node3D
var deco_root: Node3D
var lamps_root: Node3D
var traffic: Traffic

var building_nodes: Dictionary = {}
var road_nodes: Dictionary = {}
var deco: Dictionary = {}
var lamp_glows: Array[Sprite3D] = []

var sun: DirectionalLight3D
var world_env: WorldEnvironment
var env: Environment
var sky: Sky
var sky_mat: ShaderMaterial
var water_mat: ShaderMaterial
var ground_mat: ShaderMaterial

var ghost_holder: Node3D
var ghost_visual: Node3D
var ghost_id: String = ""
var ghost_mats: Array[StandardMaterial3D] = []
var ghost_highlight: MeshInstance3D
var select_highlight: MeshInstance3D

var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _env_acc := 0.0
var _traffic_dirty := false
var _traffic_timer := 0.0
var _tree_count := 0
var _is_preview := false
var _scene_cache: Dictionary = {}


func setup(rebuild_from_state: bool = true) -> void:
	_is_preview = not rebuild_from_state
	_rng.seed = 81377
	_build_roots()
	_build_environment()
	_build_island()
	_build_water()
	_scatter_nature()
	_build_islets()
	_build_highlights()

	ghost_holder = Node3D.new()
	ghost_holder.name = "Ghost"
	add_child(ghost_holder)

	traffic = Traffic.new()
	traffic.name = "Traffic"
	add_child(traffic)

	if rebuild_from_state:
		rebuild_from_state()
	_update_environment(true)
	BuildingDB.apply_night(GameState.night_factor())
	for glow in lamp_glows:
		_update_lamp(glow)


func _build_roots() -> void:
	buildings_root = Node3D.new()
	buildings_root.name = "Buildings"
	add_child(buildings_root)
	roads_root = Node3D.new()
	roads_root.name = "Roads"
	add_child(roads_root)
	props_root = Node3D.new()
	props_root.name = "Props"
	add_child(props_root)
	deco_root = Node3D.new()
	deco_root.name = "Nature"
	add_child(deco_root)
	lamps_root = Node3D.new()
	lamps_root.name = "Lamps"
	add_child(lamps_root)


# ------------------------------------------------------------------ scenery

func _build_environment() -> void:
	world_env = WorldEnvironment.new()
	env = Environment.new()
	sky = Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.02
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_strength = 1.0
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("cfe3ee")
	env.fog_density = 0.0028
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.12
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 85.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.6
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 0.25
	sun.position = Vector3(0, 30, 0)
	add_child(sun)


func _build_island() -> void:
	var island := MeshInstance3D.new()
	island.name = "Island"
	var bm := BoxMesh.new()
	bm.size = Vector3(Cfg.ISLAND_SIZE, 3.4, Cfg.ISLAND_SIZE)
	island.mesh = bm
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = GROUND_SHADER
	ground_mat.set_shader_parameter("buildable_half", Cfg.HALF_BUILD)
	ground_mat.set_shader_parameter("island_half", Cfg.ISLAND_HALF)
	ground_mat.set_shader_parameter("tile", Cfg.TILE)
	island.material_override = ground_mat
	island.position.y = -1.7
	island.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(island)

	# A slightly larger underwater shelf softens the silhouette.
	var shelf := MeshInstance3D.new()
	var sbm := BoxMesh.new()
	sbm.size = Vector3(Cfg.ISLAND_SIZE + 6.0, 1.0, Cfg.ISLAND_SIZE + 6.0)
	shelf.mesh = sbm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("c9b98f")
	sm.roughness = 1.0
	shelf.material_override = sm
	shelf.position.y = -1.05
	shelf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shelf)


func _build_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "Ocean"
	var pm := PlaneMesh.new()
	pm.size = Vector2(700.0, 700.0)
	water.mesh = pm
	water_mat = ShaderMaterial.new()
	water_mat.shader = WATER_SHADER
	water_mat.set_shader_parameter("island_half", Cfg.ISLAND_HALF)
	water.material_override = water_mat
	water.position.y = Cfg.WATER_Y
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _scatter_nature() -> void:
	for x in Cfg.GRID_SIZE:
		for z in Cfg.GRID_SIZE:
			var cell := Vector2i(x, z)
			var roll := _rng.randf()
			if roll < 0.10:
				var tree := _new_prop(String(TREE_MODELS[_rng.randi() % TREE_MODELS.size()]))
				if tree != null:
					tree.scale = Vector3.ONE * _rng.randf_range(1.15, 1.75)
					tree.position = Cfg.cell_to_world(cell) + Vector3(
						_rng.randf_range(-0.45, 0.45), 0.0, _rng.randf_range(-0.45, 0.45))
					tree.rotation.y = _rng.randf() * TAU
					deco_root.add_child(tree)
					_add_deco(cell, tree)
					_tree_count += 1
			elif roll < 0.20:
				var small := _new_prop(String(SMALL_MODELS[_rng.randi() % SMALL_MODELS.size()]))
				if small != null:
					_no_shadow(small)
					small.scale = Vector3.ONE * _rng.randf_range(1.2, 2.1)
					small.position = Cfg.cell_to_world(cell) + Vector3(
						_rng.randf_range(-0.6, 0.6), 0.0, _rng.randf_range(-0.6, 0.6))
					small.rotation.y = _rng.randf() * TAU
					deco_root.add_child(small)
					_add_deco(cell, small)
	# Border greenery outside the buildable plateau.
	for i in 90:
		var angle := _rng.randf() * TAU
		var radius := _rng.randf_range(Cfg.HALF_BUILD + 0.6, Cfg.ISLAND_HALF - 0.5)
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if absf(pos.x) < Cfg.HALF_BUILD - 0.2 and absf(pos.z) < Cfg.HALF_BUILD - 0.2:
			continue
		var is_rock := _rng.randf() < 0.28
		var model: String = ROCK_MODELS[_rng.randi() % ROCK_MODELS.size()] if is_rock \
			else TREE_MODELS[_rng.randi() % TREE_MODELS.size()]
		var prop := _new_prop(model)
		if prop == null:
			continue
		prop.scale = Vector3.ONE * (_rng.randf_range(1.2, 2.1) if is_rock else _rng.randf_range(1.4, 2.4))
		_no_shadow(prop)
		prop.position = pos
		prop.rotation.y = _rng.randf() * TAU
		props_root.add_child(prop)
	# Shoreline rocks.
	for i in 40:
		var side := _rng.randi() % 4
		var along := _rng.randf_range(-Cfg.ISLAND_HALF, Cfg.ISLAND_HALF)
		var edge := Cfg.ISLAND_HALF - _rng.randf_range(0.2, 1.2)
		var pos := Vector3.ZERO
		match side:
			0: pos = Vector3(along, 0.0, -edge)
			1: pos = Vector3(along, 0.0, edge)
			2: pos = Vector3(-edge, 0.0, along)
			3: pos = Vector3(edge, 0.0, along)
		var rock := _new_prop(ROCK_MODELS[_rng.randi() % ROCK_MODELS.size()])
		if rock == null:
			continue
		rock.scale = Vector3.ONE * _rng.randf_range(1.2, 2.4)
		_no_shadow(rock)
		rock.rotation.y = _rng.randf() * TAU
		rock.position = pos + Vector3(_rng.randf_range(-0.4, 0.4), -0.1, _rng.randf_range(-0.4, 0.4))
		props_root.add_child(rock)


func _build_islets() -> void:
	var spots := [
		Vector3(-34.0, -0.15, -14.0),
		Vector3(33.0, -0.15, 18.0),
		Vector3(6.0, -0.15, 35.0),
	]
	var sizes := [4.6, 3.2, 2.6]
	for i in spots.size():
		var root := Node3D.new()
		root.position = spots[i]
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = float(sizes[i])
		cm.bottom_radius = float(sizes[i]) * 0.86
		cm.height = 2.2
		cm.radial_segments = 12
		disc.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("4d7b48")
		mat.roughness = 0.95
		disc.material_override = mat
		root.add_child(disc)
		for j in 3:
			var tree := _new_prop(TREE_MODELS[_rng.randi() % TREE_MODELS.size()])
			if tree == null:
				continue
			tree.scale = Vector3.ONE * _rng.randf_range(1.8, 2.8)
			var a := _rng.randf() * TAU
			var r := _rng.randf_range(0.0, float(sizes[i]) * 0.6)
			tree.position = Vector3(cos(a) * r, 1.1, sin(a) * r)
			tree.rotation.y = _rng.randf() * TAU
			root.add_child(tree)
		var rock := _new_prop(ROCK_MODELS[_rng.randi() % ROCK_MODELS.size()])
		if rock != null:
			rock.scale = Vector3.ONE * 2.0
			rock.position = Vector3(float(sizes[i]) * 0.7, 1.0, 0.0)
			root.add_child(rock)
		add_child(root)


func _build_highlights() -> void:
	ghost_highlight = _make_highlight(Color(0.30, 0.95, 0.72, 0.85))
	ghost_highlight.visible = false
	add_child(ghost_highlight)
	select_highlight = _make_highlight(Color(1.0, 0.80, 0.32, 0.9))
	select_highlight.visible = false
	add_child(select_highlight)


func _make_highlight(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Cfg.TILE * 1.02, Cfg.TILE * 1.02)
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = HIGHLIGHT_SHADER
	mat.set_shader_parameter("color", color)
	mi.material_override = mat
	mi.position.y = 0.06
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _new_prop(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	var scene: PackedScene = _scene_cache[path]
	return scene.instantiate() as Node3D


func _no_shadow(root: Node) -> void:
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_deco(cell: Vector2i, node: Node3D) -> void:
	if not deco.has(cell):
		deco[cell] = []
	deco[cell].append(node)


func clear_deco(cell: Vector2i) -> void:
	if not deco.has(cell):
		return
	for node in deco[cell]:
		if is_instance_valid(node):
			node.queue_free()
	deco.erase(cell)


# ------------------------------------------------------------------ city data

func rebuild_from_state() -> void:
	for cell in building_nodes.keys():
		var node = building_nodes[cell]
		if is_instance_valid(node):
			node.queue_free()
	building_nodes.clear()
	for cell in road_nodes.keys():
		var node = road_nodes[cell]
		if is_instance_valid(node):
			node.queue_free()
	road_nodes.clear()

	for cell in GameState.buildings:
		var b: Dictionary = GameState.buildings[cell]
		spawn_building(cell, String(b["id"]), int(b["level"]), int(b["variant"]), false)
	for cell in GameState.roads:
		add_road_tile(cell)
	refresh_all_roads()
	GameState.trees = _tree_count
	_rebuild_traffic()
	rebuild_lamps()


func spawn_building(cell: Vector2i, id: String, level: int, variant: int, animate: bool = true) -> CityBuilding:
	if building_nodes.has(cell):
		remove_building(cell)
	clear_deco(cell)
	var b := CityBuilding.new()
	b.name = "B_%d_%d" % [cell.x, cell.y]
	buildings_root.add_child(b)
	b.setup(cell, id, level, variant, animate)
	building_nodes[cell] = b
	return b


func remove_building(cell: Vector2i) -> void:
	if not building_nodes.has(cell):
		return
	var node = building_nodes[cell]
	if is_instance_valid(node):
		node.queue_free()
	building_nodes.erase(cell)


func add_road_tile(cell: Vector2i) -> void:
	if road_nodes.has(cell):
		return
	var tile := RoadTile.new()
	tile.name = "R_%d_%d" % [cell.x, cell.y]
	tile.setup(cell)
	roads_root.add_child(tile)
	road_nodes[cell] = tile
	refresh_roads_around(cell)
	clear_deco(cell)
	_mark_traffic_dirty()


func remove_road_tile(cell: Vector2i) -> void:
	if not road_nodes.has(cell):
		return
	var tile = road_nodes[cell]
	if is_instance_valid(tile):
		tile.queue_free()
	road_nodes.erase(cell)
	refresh_roads_around(cell)
	_mark_traffic_dirty()


func refresh_roads_around(cell: Vector2i) -> void:
	var cells: Array[Vector2i] = [cell,
		cell + Vector2i(0, -1), cell + Vector2i(1, 0),
		cell + Vector2i(0, 1), cell + Vector2i(-1, 0)]
	for c in cells:
		if not road_nodes.has(c):
			continue
		var mask := 0
		if road_nodes.has(c + Vector2i(0, -1)): mask |= 1
		if road_nodes.has(c + Vector2i(1, 0)): mask |= 2
		if road_nodes.has(c + Vector2i(0, 1)): mask |= 4
		if road_nodes.has(c + Vector2i(-1, 0)): mask |= 8
		(road_nodes[c] as RoadTile).set_mask(mask)


func refresh_all_roads() -> void:
	for c in road_nodes:
		var mask := 0
		if road_nodes.has(c + Vector2i(0, -1)): mask |= 1
		if road_nodes.has(c + Vector2i(1, 0)): mask |= 2
		if road_nodes.has(c + Vector2i(0, 1)): mask |= 4
		if road_nodes.has(c + Vector2i(-1, 0)): mask |= 8
		(road_nodes[c] as RoadTile).set_mask(mask)


func _mark_traffic_dirty() -> void:
	_traffic_dirty = true
	_traffic_timer = 0.6


func _rebuild_traffic() -> void:
	if traffic == null:
		return
	var cells: Array = road_nodes.keys()
	traffic.rebuild(cells, 9)


func rebuild_lamps() -> void:
	for c in lamps_root.get_children():
		c.queue_free()
	lamp_glows.clear()
	var count := 0
	var keys: Array = road_nodes.keys()
	keys.sort_custom(func(a, b): return (a.x * 7 + a.y * 3) % 11 < (b.x * 7 + b.y * 3) % 11)
	for cell in keys:
		if count >= 22:
			break
		if ((cell.x * 3 + cell.y * 5) % 6) != 0:
			continue
		count += 1
		var root := Node3D.new()
		root.position = Cfg.cell_to_world(cell) + Vector3(0.72, 0.02, 0.72)
		var lamp := _new_prop("res://assets/models/roads/light-square.glb")
		if lamp != null:
			lamp.scale = Vector3.ONE * 3.4
			root.add_child(lamp)
		var glow := Sprite3D.new()
		glow.texture = BuildingDB.soft_circle()
		glow.pixel_size = 0.014
		glow.scale = Vector3(2.0, 2.0, 1.0)
		glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		glow.modulate = Color(1.0, 0.78, 0.42, 0.0)
		glow.no_depth_test = false
		glow.position.y = 1.95
		root.add_child(glow)
		lamps_root.add_child(root)
		lamp_glows.append(glow)
	for glow in lamp_glows:
		_update_lamp(glow)


func _update_lamp(glow: Sprite3D) -> void:
	glow.modulate.a = GameState.night_factor() * 0.85


# ------------------------------------------------------------------ ghost / selection

func show_ghost(id: String, cell: Vector2i, valid: bool) -> void:
	if id == "":
		hide_ghost()
		return
	if ghost_id != id:
		_build_ghost(id)
	ghost_holder.position = Cfg.cell_to_world(cell, 0.0)
	ghost_holder.visible = true
	ghost_highlight.position = Cfg.cell_to_world(cell, 0.06)
	ghost_highlight.visible = true
	set_ghost_valid(valid)


func set_ghost_valid(valid: bool) -> void:
	var col := Color(0.32, 0.98, 0.70, 0.55) if valid else Color(1.0, 0.36, 0.32, 0.55)
	for m in ghost_mats:
		m.albedo_color = col
		m.emission = col
	var hi := ghost_highlight.material_override as ShaderMaterial
	if hi != null:
		hi.set_shader_parameter("color", Color(0.32, 0.98, 0.70, 0.85) if valid else Color(1.0, 0.36, 0.32, 0.9))


func _build_ghost(id: String) -> void:
	ghost_id = id
	ghost_mats.clear()
	if ghost_visual != null and is_instance_valid(ghost_visual):
		ghost_visual.queue_free()
	ghost_visual = BuildingDB.build_visual(id, 0, 1)
	ghost_holder.add_child(ghost_visual)
	_ghostify(ghost_visual)


func _ghostify(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.material_override is StandardMaterial3D:
			var dup := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dup.albedo_color = Color(0.32, 0.98, 0.70, 0.55)
			dup.emission_enabled = true
			dup.emission = Color(0.32, 0.98, 0.70)
			dup.emission_energy_multiplier = 0.35
			mi.material_override = dup
			ghost_mats.append(dup)
		elif mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var mat := mi.get_active_material(s)
				if mat is StandardMaterial3D:
					var dup := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
					dup.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					dup.albedo_color = Color(0.32, 0.98, 0.70, 0.55)
					dup.emission_enabled = true
					dup.emission = Color(0.32, 0.98, 0.70)
					dup.emission_energy_multiplier = 0.35
					mi.set_surface_override_material(s, dup)
					ghost_mats.append(dup)


func hide_ghost() -> void:
	ghost_holder.visible = false
	ghost_highlight.visible = false
	ghost_id = ""


func set_selected(cell: Vector2i) -> void:
	if cell.x < 0:
		select_highlight.visible = false
		return
	select_highlight.position = Cfg.cell_to_world(cell, 0.065)
	select_highlight.visible = true


# ------------------------------------------------------------------ preview helpers

func preview_place(id: String, cell: Vector2i, variant: int = 0) -> void:
	spawn_building(cell, id, 1, variant, false)


func preview_road(cell: Vector2i) -> void:
	add_road_tile(cell)


func preview_start_traffic() -> void:
	_rebuild_traffic()


# ------------------------------------------------------------------ runtime

func _process(delta: float) -> void:
	_time += delta
	_env_acc += delta
	if _env_acc >= 0.08:
		_env_acc = 0.0
		_update_environment(false)
		BuildingDB.apply_night(GameState.night_factor())
		for glow in lamp_glows:
			_update_lamp(glow)
	if water_mat != null:
		water_mat.set_shader_parameter("time", _time)
	if ghost_highlight != null and ghost_highlight.visible:
		var hm := ghost_highlight.material_override as ShaderMaterial
		if hm != null:
			hm.set_shader_parameter("time", _time)
	if select_highlight != null and select_highlight.visible:
		var sm := select_highlight.material_override as ShaderMaterial
		if sm != null:
			sm.set_shader_parameter("time", _time)
	if _traffic_dirty:
		_traffic_timer -= delta
		if _traffic_timer <= 0.0:
			_traffic_dirty = false
			_rebuild_traffic()
			rebuild_lamps()


func _update_environment(force: bool) -> void:
	var night := GameState.night_factor()
	var sun_dir := GameState.sun_direction()
	var elev := sun_dir.y
	var dusk := clampf(1.0 - absf(elev) / 0.32, 0.0, 1.0)
	var daylight := smoothstep(-0.03, 0.30, elev)

	sky_mat.set_shader_parameter("sun_dir", sun_dir)
	sky_mat.set_shader_parameter("night", night)
	sky_mat.set_shader_parameter("time", _time)
	sky_mat.set_shader_parameter("top_color",
		Color("2f74b5").lerp(Color("040812"), night))
	sky_mat.set_shader_parameter("horizon_color",
		Color("ffd7b2").lerp(Color("14203a"), night))
	sky_mat.set_shader_parameter("sun_color",
		Color("fff1d2").lerp(Color("ff9a52"), dusk * 0.9))
	sky_mat.set_shader_parameter("star_amount", 0.55)
	sky_mat.set_shader_parameter("cloud_amount", 0.42)

	var is_night := elev < -0.02
	var light_dir := -sun_dir if is_night else sun_dir
	var energy := 0.30 * night if is_night else lerpf(0.35, 1.35, smoothstep(0.0, 0.45, elev))
	if not is_night:
		energy = maxf(energy, 0.35)
	var light_color := Color("a9c0ff") if is_night else Color("fff3dc").lerp(Color("ffb27a"), dusk * 0.75)
	sun.light_energy = lerpf(sun.light_energy, energy, 0.08 if not force else 1.0)
	sun.light_color = sun.light_color.lerp(light_color, 0.08 if not force else 1.0)
	var basis := Basis.looking_at(-light_dir.normalized(), Vector3.UP)
	sun.global_transform.basis = basis

	env.ambient_light_energy = lerpf(0.92, 0.42, night)
	env.fog_light_color = Color("d3e5ef").lerp(Color("0d1728"), night)
	env.fog_density = lerpf(0.0026, 0.0052, night)
	if water_mat != null:
		water_mat.set_shader_parameter("sky_tint", Color("93c7ea").lerp(Color("1a2a44"), night))
		water_mat.set_shader_parameter("deep_color", Color("07334a").lerp(Color("04101c"), night))
		water_mat.set_shader_parameter("shallow_color", Color("1a87a0").lerp(Color("0a2a3a"), night))


func apply_quality(quality: int) -> void:
	match quality:
		0:
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			sun.shadow_enabled = false
			env.glow_enabled = false
		1:
			get_viewport().msaa_3d = Viewport.MSAA_2X
			sun.shadow_enabled = true
			env.glow_enabled = true
		_:
			get_viewport().msaa_3d = Viewport.MSAA_4X
			sun.shadow_enabled = true
			env.glow_enabled = true