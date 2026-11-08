extends Node
## Building catalogue + procedural landmark builders.
## Every model used here is CC0 (Kenney.nl); see CREDITS.md.

const SUB := "res://assets/models/suburban/"
const COM := "res://assets/models/commercial/"
const NAT := "res://assets/models/nature/"
const PROP := "res://assets/models/roads/"
const CAR := "res://assets/models/cars/"

const SPINNER := preload("res://scripts/world/Spinner.gd")

var buildings: Dictionary = {}
var order: Array[String] = []
var kit_materials: Array[StandardMaterial3D] = []
var _seen_materials: Dictionary = {}
var _soft_circle: Texture2D
var _night_energy := 0.0


func _ready() -> void:
	_define_buildings()
	_soft_circle = _make_soft_circle(64)


func _define_buildings() -> void:
	_add({
		"id": "cottage", "name": "Cottage", "cat": "homes",
		"blurb": "A cosy starter home for six neighbours.",
		"cost": 120, "upkeep": 1.0, "tax": 2.0, "housing": 6, "jobs": 0,
		"power_use": 1, "power_make": 0, "happiness": 0.4, "pollution": 0,
		"unlock": 0, "kind": "model", "scale": 1.0,
		"models": [SUB + "building-type-a.glb", SUB + "building-type-c.glb",
			SUB + "building-type-e.glb", SUB + "building-type-i.glb",
			SUB + "building-type-p.glb"],
	})
	_add({
		"id": "house", "name": "Family House", "cat": "homes",
		"blurb": "A roomy house with a garden and a warm roof.",
		"cost": 260, "upkeep": 2.0, "tax": 4.0, "housing": 14, "jobs": 0,
		"power_use": 2, "power_make": 0, "happiness": 0.8, "pollution": 0,
		"unlock": 25, "kind": "model", "scale": 1.0,
		"models": [SUB + "building-type-f.glb", SUB + "building-type-g.glb",
			SUB + "building-type-h.glb", SUB + "building-type-q.glb"],
	})
	_add({
		"id": "townhouse", "name": "Townhouse", "cat": "homes",
		"blurb": "Smart terraced living close to the shops.",
		"cost": 520, "upkeep": 3.5, "tax": 8.0, "housing": 26, "jobs": 0,
		"power_use": 3, "power_make": 0, "happiness": 1.2, "pollution": 0,
		"unlock": 70, "kind": "model", "scale": 1.0,
		"models": [SUB + "building-type-n.glb", SUB + "building-type-o.glb",
			SUB + "building-type-s.glb", SUB + "building-type-t.glb",
			SUB + "building-type-u.glb"],
	})
	_add({
		"id": "apartment", "name": "Apartment", "cat": "homes",
		"blurb": "Dense, friendly housing for a growing district.",
		"cost": 980, "upkeep": 6.0, "tax": 15.0, "housing": 46, "jobs": 0,
		"power_use": 5, "power_make": 0, "happiness": 1.5, "pollution": 0,
		"unlock": 140, "kind": "model", "scale": 1.9,
		"models": [COM + "low-detail-building-g.glb", COM + "low-detail-building-h.glb",
			COM + "low-detail-building-j.glb"],
	})
	_add({
		"id": "tower", "name": "Residential Tower", "cat": "homes",
		"blurb": "A skyline icon that houses a whole neighbourhood.",
		"cost": 2100, "upkeep": 12.0, "tax": 32.0, "housing": 92, "jobs": 0,
		"power_use": 9, "power_make": 0, "happiness": 2.0, "pollution": 0,
		"unlock": 320, "kind": "model", "scale": 1.0,
		"models": [COM + "building-skyscraper-a.glb", COM + "building-skyscraper-b.glb",
			COM + "building-skyscraper-e.glb"],
	})

	_add({
		"id": "shop", "name": "Corner Shop", "cat": "commerce",
		"blurb": "Daily groceries, jobs and a little tax income.",
		"cost": 220, "upkeep": 1.5, "tax": 7.0, "housing": 0, "jobs": 8,
		"power_use": 2, "power_make": 0, "happiness": 0.6, "pollution": 0,
		"unlock": 0, "kind": "model", "scale": 1.0,
		"models": [COM + "building-a.glb", COM + "building-c.glb", COM + "building-d.glb"],
	})
	_add({
		"id": "cafe", "name": "Cafe", "cat": "commerce",
		"blurb": "A sunny terrace where happiness bubbles up.",
		"cost": 340, "upkeep": 2.0, "tax": 7.0, "housing": 0, "jobs": 5,
		"power_use": 1, "power_make": 0, "happiness": 2.5, "pollution": 0,
		"unlock": 50, "kind": "model", "scale": 1.0,
		"models": [COM + "building-b.glb", COM + "building-h.glb"],
	})
	_add({
		"id": "office", "name": "Office", "cat": "commerce",
		"blurb": "Desks, coffee and a steady stream of rates.",
		"cost": 800, "upkeep": 5.0, "tax": 21.0, "housing": 0, "jobs": 22,
		"power_use": 4, "power_make": 0, "happiness": 0.5, "pollution": 0,
		"unlock": 110, "kind": "model", "scale": 1.0,
		"models": [COM + "building-f.glb", COM + "building-g.glb"],
	})
	_add({
		"id": "market", "name": "Market Hall", "cat": "commerce",
		"blurb": "A wide hall full of stalls and small businesses.",
		"cost": 1250, "upkeep": 7.0, "tax": 30.0, "housing": 0, "jobs": 30,
		"power_use": 5, "power_make": 0, "happiness": 2.0, "pollution": 0,
		"unlock": 200, "kind": "model", "scale": 0.95,
		"models": [COM + "building-e.glb", COM + "building-j.glb"],
	})
	_add({
		"id": "hq", "name": "Corporate HQ", "cat": "commerce",
		"blurb": "Glass towers, big payrolls, bigger tax cheques.",
		"cost": 2800, "upkeep": 15.0, "tax": 62.0, "housing": 0, "jobs": 64,
		"power_use": 10, "power_make": 0, "happiness": 1.0, "pollution": 0,
		"unlock": 350, "kind": "model", "scale": 1.0,
		"models": [COM + "building-skyscraper-c.glb", COM + "building-skyscraper-d.glb"],
	})

	_add({
		"id": "workshop", "name": "Workshop", "cat": "industry",
		"blurb": "Honest work, a little smoke, decent pay.",
		"cost": 300, "upkeep": 2.0, "tax": 10.0, "housing": 0, "jobs": 12,
		"power_use": 3, "power_make": 0, "happiness": 0.0, "pollution": 3,
		"unlock": 0, "kind": "model", "scale": 1.9,
		"models": [COM + "low-detail-building-a.glb", COM + "low-detail-building-f.glb"],
	})
	_add({
		"id": "factory", "name": "Factory", "cat": "industry",
		"blurb": "Serious output. Keep it away from the parks.",
		"cost": 850, "upkeep": 5.5, "tax": 27.0, "housing": 0, "jobs": 30,
		"power_use": 7, "power_make": 0, "happiness": -0.5, "pollution": 9,
		"unlock": 160, "kind": "model", "scale": 1.9,
		"models": [COM + "low-detail-building-c.glb", COM + "low-detail-building-k.glb"],
	})
	_add({
		"id": "powerplant", "name": "Power Plant", "cat": "civic",
		"blurb": "45 MW of dependable power and a little haze.",
		"cost": 1150, "upkeep": 8.0, "tax": 0.0, "housing": 0, "jobs": 6,
		"power_use": 0, "power_make": 46, "happiness": -1.0, "pollution": 13,
		"unlock": 45, "kind": "powerplant", "scale": 1.0, "models": [],
	})

	_add({
		"id": "solar", "name": "Solar Farm", "cat": "civic",
		"blurb": "Clean panels humming in the afternoon sun.",
		"cost": 460, "upkeep": 1.0, "tax": 0.0, "housing": 0, "jobs": 2,
		"power_use": 0, "power_make": 15, "happiness": 0.3, "pollution": 0,
		"unlock": 15, "kind": "solar", "scale": 1.0, "models": [],
	})
	_add({
		"id": "wind", "name": "Wind Turbine", "cat": "civic",
		"blurb": "A gentle spinner that powers a few homes.",
		"cost": 300, "upkeep": 1.0, "tax": 0.0, "housing": 0, "jobs": 1,
		"power_use": 0, "power_make": 8, "happiness": 0.3, "pollution": 0,
		"unlock": 0, "kind": "wind", "scale": 1.0, "models": [],
	})
	_add({
		"id": "park", "name": "Pocket Park", "cat": "civic",
		"blurb": "Trees, flowers and a bench to watch the clouds.",
		"cost": 160, "upkeep": 1.0, "tax": 0.0, "housing": 0, "jobs": 0,
		"power_use": 0, "power_make": 0, "happiness": 5.0, "pollution": 0,
		"unlock": 0, "kind": "park", "scale": 1.0, "models": [],
	})
	_add({
		"id": "plaza", "name": "Fountain Plaza", "cat": "civic",
		"blurb": "A social heart for the city with splashing water.",
		"cost": 400, "upkeep": 1.5, "tax": 0.0, "housing": 0, "jobs": 0,
		"power_use": 1, "power_make": 0, "happiness": 7.0, "pollution": 0,
		"unlock": 60, "kind": "plaza", "scale": 1.0, "models": [],
	})
	_add({
		"id": "school", "name": "School", "cat": "civic",
		"blurb": "Brighter kids, happier parents, better city.",
		"cost": 720, "upkeep": 4.0, "tax": 3.0, "housing": 0, "jobs": 10,
		"power_use": 3, "power_make": 0, "happiness": 7.0, "pollution": 0,
		"unlock": 90, "kind": "model", "scale": 1.0,
		"models": [COM + "building-i.glb"],
	})
	_add({
		"id": "hospital", "name": "Hospital", "cat": "civic",
		"blurb": "Care for everyone. The happiest block in town.",
		"cost": 1550, "upkeep": 8.0, "tax": 5.0, "housing": 0, "jobs": 18,
		"power_use": 6, "power_make": 0, "happiness": 10.0, "pollution": 0,
		"unlock": 240, "kind": "model", "scale": 1.0,
		"models": [COM + "building-l.glb", COM + "building-m.glb"],
	})
	_add({
		"id": "road", "name": "Road", "cat": "civic",
		"blurb": "Connects your districts and lets the traffic flow.",
		"cost": 10, "upkeep": 0.15, "tax": 0.0, "housing": 0, "jobs": 0,
		"power_use": 0, "power_make": 0, "happiness": 0.0, "pollution": 0,
		"unlock": 0, "kind": "road", "scale": 1.0, "models": [],
	})


func _add(def: Dictionary) -> void:
	buildings[String(def["id"])] = def
	order.append(String(def["id"]))


func get_def(id: String) -> Dictionary:
	return buildings.get(id, {})


func all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in order:
		out.append(buildings[id])
	return out


func in_category(cat: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in order:
		var d: Dictionary = buildings[id]
		if String(d["cat"]) == cat:
			out.append(d)
	out.sort_custom(func(a, b): return int(a["unlock"]) < int(b["unlock"]))
	return out


func unlocked_ids(population: float) -> Array[String]:
	var out: Array[String] = []
	for id in order:
		if population >= float(buildings[id]["unlock"]):
			out.append(id)
	return out


func is_road(id: String) -> bool:
	return id == "road"


func build_visual(id: String, variant: int = 0, level: int = 1) -> Node3D:
	var d: Dictionary = get_def(id)
	if d.is_empty():
		return Node3D.new()
	match String(d["kind"]):
		"park":
			return _build_park(variant, level)
		"solar":
			return _build_solar(variant, level)
		"wind":
			return _build_wind(variant, level)
		"powerplant":
			return _build_powerplant(variant, level)
		"plaza":
			return _build_plaza(variant, level)
		"road":
			return _build_road_visual(variant)
	return _build_model(d, variant, level)


func _build_model(d: Dictionary, variant: int, level: int) -> Node3D:
	var models: Array = d["models"]
	if models.is_empty():
		return Node3D.new()
	var path := String(models[variant % models.size()])
	var holder := Node3D.new()
	if not ResourceLoader.exists(path):
		var fallback := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 1.2, 1.4)
		fallback.mesh = bm
		fallback.position.y = 0.6
		holder.add_child(fallback)
		return holder
	var scene: PackedScene = load(path)
	if scene == null:
		var fallback2 := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(1.4, 1.2, 1.4)
		fallback2.mesh = bm2
		fallback2.position.y = 0.6
		holder.add_child(fallback2)
		return holder
	var inst: Node3D = scene.instantiate()
	var s: float = float(d.get("scale", 1.0))
	inst.scale = Vector3.ONE * s
	holder.add_child(inst)
	_register_materials(inst)
	if level > 1:
		inst.scale = Vector3.ONE * s * (1.0 + 0.05 * float(level - 1))
	return holder


func _build_road_visual(_variant: int) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(Cfg.TILE, Cfg.TILE)
	mi.mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/world/road.gdshader")
	mat.set_shader_parameter("mask", 15)
	mi.material_override = mat
	mi.position.y = 0.02
	root.add_child(mi)
	return root


func _build_park(variant: int, level: int) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + variant * 131 + level * 17
	root.add_child(_box(Vector3(1.94, 0.07, 1.94), Color("3c6b3d"), Vector3(0, 0.035, 0)))
	root.add_child(_box(Vector3(1.9, 0.02, 0.3), Color("b0a37e"), Vector3(0, 0.08, 0.15)))
	var tree_count := 3 + level
	for i in tree_count:
		var tree := _load_prop(NAT + "tree_default.glb")
		if tree != null:
			tree.scale = Vector3.ONE * rng.randf_range(0.85, 1.15)
			tree.position = Vector3(rng.randf_range(-0.72, 0.72), 0.06, rng.randf_range(-0.72, 0.72))
			tree.rotation.y = rng.randf() * TAU
			root.add_child(tree)
	var flower_models := ["flower_redA.glb", "flower_yellowA.glb", "flower_purpleA.glb"]
	for i in 5:
		var flower := _load_prop(NAT + flower_models[rng.randi() % flower_models.size()])
		if flower != null:
			flower.scale = Vector3.ONE * 1.6
			flower.position = Vector3(rng.randf_range(-0.85, 0.85), 0.08, rng.randf_range(-0.85, 0.85))
			flower.rotation.y = rng.randf() * TAU
			root.add_child(flower)
	if level >= 2:
		var pond := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.34
		cyl.bottom_radius = 0.34
		cyl.height = 0.04
		cyl.radial_segments = 20
		pond.mesh = cyl
		pond.material_override = _mat(Color("2f7fa8"), 0.15, 0.0, 0.25)
		pond.position = Vector3(0.4, 0.09, -0.4)
		root.add_child(pond)
	if level >= 3:
		root.add_child(_box(Vector3(0.9, 0.16, 0.26), Color("8a6a44"), Vector3(-0.5, 0.16, -0.35)))
	return root


func _build_solar(variant: int, level: int) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4241 + variant * 53
	root.add_child(_box(Vector3(1.94, 0.05, 1.94), Color("3a3d46"), Vector3(0, 0.025, 0)))
	var panel_count := 6 + level * 2
	var cols := 3
	for i in panel_count:
		var row := i / cols
		var col := i % cols
		var p := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.54, 0.035, 0.42)
		p.mesh = bm
		p.material_override = _mat(Color("1b2f57"), 0.35, 0.35, 0.10)
		p.position = Vector3(-0.62 + col * 0.62, 0.30 + row * 0.02, -0.55 + row * 0.55)
		p.rotation.x = deg_to_rad(-28.0)
		root.add_child(p)
	root.add_child(_box(Vector3(0.26, 0.22, 0.2), Color("5a606d"), Vector3(0.78, 0.13, 0.78)))
	var rng_jitter := rng.randf() * 0.1
	root.rotation.y += rng_jitter
	return root


func _build_wind(variant: int, level: int) -> Node3D:
	var root := Node3D.new()
	var height := 2.45 + float(level - 1) * 0.32
	var tower := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.12
	cyl.height = height
	cyl.radial_segments = 10
	tower.mesh = cyl
	tower.material_override = _mat(Color("eef2f5"), 0.55, 0.0, 0.08)
	tower.position.y = height * 0.5
	root.add_child(tower)

	var nacelle := MeshInstance3D.new()
	var nbm := BoxMesh.new()
	nbm.size = Vector3(0.16, 0.15, 0.36)
	nacelle.mesh = nbm
	nacelle.material_override = _mat(Color("f4f7fa"), 0.5, 0.0, 0.08)
	nacelle.position = Vector3(0, height + 0.02, 0.06)
	root.add_child(nacelle)

	var hub := Node3D.new()
	hub.position = Vector3(0, height + 0.02, 0.26)
	hub.set_script(SPINNER)
	hub.set("speed", 1.6 + float(variant % 3) * 0.35)
	root.add_child(hub)
	for i in 3:
		var blade := MeshInstance3D.new()
		var bbm := BoxMesh.new()
		bbm.size = Vector3(0.075, 1.05, 0.028)
		blade.mesh = bbm
		blade.material_override = _mat(Color("fbfdff"), 0.5, 0.0, 0.05)
		var pivot := Node3D.new()
		pivot.rotation.z = TAU * float(i) / 3.0
		blade.position.y = 0.52
		pivot.add_child(blade)
		hub.add_child(pivot)
	var hub_cap := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.09
	sph.height = 0.18
	sph.radial_segments = 10
	sph.rings = 6
	hub_cap.mesh = sph
	hub_cap.material_override = _mat(Color("dfe7ee"), 0.5, 0.0, 0.1)
	hub.add_child(hub_cap)
	root.add_child(_box(Vector3(0.7, 0.06, 0.7), Color("7a7f86"), Vector3(0, 0.03, 0)))
	return root


func _build_powerplant(variant: int, level: int) -> Node3D:
	var root := Node3D.new()
	var base := _load_prop(COM + "low-detail-building-b.glb")
	if base != null:
		base.scale = Vector3.ONE * 1.7
		base.position = Vector3(-0.32, 0, 0)
		root.add_child(base)
		_register_materials(base)
	root.add_child(_box(Vector3(1.96, 0.05, 1.96), Color("4b4f58"), Vector3(0, 0.025, 0)))
	for i in 2:
		var x := 0.42
		var z := -0.34 + float(i) * 0.62
		var chimney := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.085
		cyl.bottom_radius = 0.12
		cyl.height = 1.9 + float(level - 1) * 0.3
		cyl.radial_segments = 12
		chimney.mesh = cyl
		chimney.material_override = _mat(Color("c9c4bd"), 0.8, 0.0, 0.0)
		chimney.position = Vector3(x, cyl.height * 0.5 + 0.05, z)
		root.add_child(chimney)
		var band := MeshInstance3D.new()
		var band_cyl := CylinderMesh.new()
		band_cyl.top_radius = 0.11
		band_cyl.bottom_radius = 0.125
		band_cyl.height = 0.16
		band_cyl.radial_segments = 12
		band.mesh = band_cyl
		band.material_override = _mat(Color("e0644f"), 0.7, 0.0, 0.0)
		band.position = Vector3(x, cyl.height - 0.2, z)
		root.add_child(band)
		root.add_child(_smoke(Vector3(x, cyl.height + 0.1, z), 0.55, Color(0.72, 0.73, 0.74, 0.5)))
	root.add_child(_box(Vector3(0.3, 0.32, 0.25), Color("6a6f78"), Vector3(-0.72, 0.16, 0.66)))
	return root


func _build_plaza(variant: int, level: int) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 991 + variant * 71
	root.add_child(_cylinder(0.98, 0.07, Color("b8ae97"), Vector3(0, 0.035, 0), 24))
	root.add_child(_cylinder(0.86, 0.09, Color("cfc5ab"), Vector3(0, 0.045, 0), 24))
	root.add_child(_cylinder(0.36, 0.16, Color("a89d86"), Vector3(0, 0.1, 0), 18))
	var water := _cylinder(0.3, 0.03, Color("4aa8c8"), Vector3(0, 0.185, 0), 18)
	water.material_override = _mat(Color("4aa8c8"), 0.1, 0.0, 0.15)
	root.add_child(water)
	root.add_child(_cylinder(0.05, 0.55, Color("cfd3d6"), Vector3(0, 0.36, 0), 8))
	root.add_child(_water_jet(Vector3(0, 0.62, 0), 0.55))
	for i in 2:
		var bench := Node3D.new()
		bench.add_child(_box(Vector3(0.62, 0.07, 0.2), Color("9c7448"), Vector3(0, 0.22, 0)))
		bench.add_child(_box(Vector3(0.62, 0.18, 0.05), Color("9c7448"), Vector3(0, 0.32, -0.08)))
		bench.position = Vector3(-0.45 + float(i) * 0.9, 0, 0.62)
		bench.rotation.y = PI
		root.add_child(bench)
	for i in 2:
		var tree := _load_prop(NAT + "tree_detailed.glb")
		if tree != null:
			tree.scale = Vector3.ONE * 0.8
			tree.position = Vector3(-0.62 + float(i) * 1.24, 0.08, -0.55)
			tree.rotation.y = rng.randf() * TAU
			root.add_child(tree)
	if level >= 2:
		root.add_child(_smoke(Vector3(0, 0.55, 0), 0.4, Color(0.75, 0.9, 1.0, 0.35)))
	return root


# ---------------------------------------------------------------- helpers

func _register_materials(root: Node) -> void:
	for child in root.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				if sm.albedo_texture != null and not _seen_materials.has(sm.get_instance_id()):
					_seen_materials[sm.get_instance_id()] = true
					sm.emission_enabled = true
					sm.emission_texture = sm.albedo_texture
					sm.emission = Color(1.0, 0.95, 0.85)
					sm.emission_energy_multiplier = 0.0
					kit_materials.append(sm)


func apply_night(night: float) -> void:
	_night_energy = lerp(_night_energy, night, 0.1)
	var energy := _night_energy * 0.55
	for m in kit_materials:
		m.emission_energy_multiplier = energy


func _load_prop(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path)
	var inst = scene.instantiate()
	return inst as Node3D


func _mat(color: Color, roughness: float = 0.85, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, 0.9)
	mi.position = pos
	return mi


func _cylinder(radius: float, height: float, color: Color, pos: Vector3, segments: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segments
	mi.mesh = cm
	mi.material_override = _mat(color, 0.85)
	mi.position = pos
	return mi


func _smoke(pos: Vector3, size: float, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 10
	p.lifetime = 3.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.direction = Vector3(0, 1, 0)
	p.spread = 12.0
	p.gravity = Vector3(0, 0.35, 0)
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.6
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	p.color = color
	var qm := QuadMesh.new()
	qm.size = Vector2(0.35, 0.35)
	qm.material = _particle_material()
	p.mesh = qm
	return p


func _water_jet(pos: Vector3, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 18
	p.lifetime = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.05
	p.direction = Vector3(0, 1, 0)
	p.spread = 16.0
	p.gravity = Vector3(0, -9.0, 0)
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 1.8
	p.scale_amount_min = size * 0.4
	p.scale_amount_max = size
	p.color = Color(0.72, 0.91, 1.0, 0.7)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.12, 0.12)
	qm.material = _particle_material()
	p.mesh = qm
	return p


func make_smoke(pos: Vector3, size: float, color: Color) -> CPUParticles3D:
	return _smoke(pos, size, color)


func soft_circle() -> Texture2D:
	return _soft_circle


func make_dust(pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.amount = 18
	p.lifetime = 1.15
	p.explosiveness = 0.55
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.72
	p.direction = Vector3(0, 1, 0)
	p.spread = 65.0
	p.gravity = Vector3(0, -0.55, 0)
	p.initial_velocity_min = 0.55
	p.initial_velocity_max = 1.35
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.85
	p.color = Color(0.86, 0.79, 0.64, 0.5)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.28, 0.28)
	qm.material = _particle_material()
	p.mesh = qm
	return p


func make_sparkle(pos: Vector3, color: Color = Color(1.0, 0.82, 0.35, 0.9)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.amount = 26
	p.lifetime = 1.0
	p.explosiveness = 0.85
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.55
	p.direction = Vector3(0, 1, 0)
	p.spread = 38.0
	p.gravity = Vector3(0, -1.6, 0)
	p.initial_velocity_min = 1.1
	p.initial_velocity_max = 2.4
	p.scale_amount_min = 0.1
	p.scale_amount_max = 0.24
	p.color = color
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.16)
	qm.material = _particle_material()
	p.mesh = qm
	return p


func _particle_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_circle
	m.disable_receive_shadows = true
	return m


func _make_soft_circle(size: int) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)