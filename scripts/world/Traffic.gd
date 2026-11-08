class_name Traffic
extends Node3D
## Gentle vehicle traffic that follows the road network.

const CAR_MODELS := [
	"res://assets/models/cars/sedan.glb",
	"res://assets/models/cars/taxi.glb",
	"res://assets/models/cars/van.glb",
	"res://assets/models/cars/truck.glb",
	"res://assets/models/cars/suv.glb",
	"res://assets/models/cars/hatchback-sports.glb",
	"res://assets/models/cars/police.glb",
	"res://assets/models/cars/delivery.glb",
]

## The Kenney vehicle meshes point along +Z.
const FORWARD_OFFSET := 0.0

var roads: Dictionary = {}
var cars: Array[Dictionary] = []
var max_cars: int = 9
var _rng := RandomNumberGenerator.new()
var _scene_cache: Dictionary = {}


func _ready() -> void:
	_rng.seed = 20240517


func rebuild(road_cells: Array, count: int = 9) -> void:
	for c in get_children():
		c.queue_free()
	cars.clear()
	roads.clear()
	for cell in road_cells:
		roads[cell] = true
	max_cars = count
	if roads.size() < 3:
		return
	var cells := roads.keys()
	cells.shuffle()
	var spawn_count := mini(max_cars, maxi(1, int(roads.size() / 3)))
	for i in spawn_count:
		_spawn_car(cells[i % cells.size()])


func _spawn_car(from_cell: Vector2i) -> void:
	var neighbours := _neighbours(from_cell)
	if neighbours.is_empty():
		return
	var to_cell: Vector2i = neighbours[_rng.randi() % neighbours.size()]
	var node := Node3D.new()
	var model_path: String = CAR_MODELS[_rng.randi() % CAR_MODELS.size()]
	var model := _instantiate(model_path)
	if model != null:
		model.scale = Vector3.ONE * 0.46
		model.position.y = 0.0
		node.add_child(model)
		var body := model as Node3D
		body.rotation.y = FORWARD_OFFSET
	node.position = Cfg.cell_to_world(from_cell) + Vector3(0, 0.14, 0)
	node.rotation.y = _yaw(from_cell, to_cell)
	add_child(node)
	cars.append({
		"node": node,
		"from": from_cell,
		"to": to_cell,
		"t": _rng.randf_range(0.0, 0.85),
		"speed": _rng.randf_range(2.4, 3.6),
	})


func _instantiate(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	var scene: PackedScene = _scene_cache[path]
	return scene.instantiate() as Node3D


func _neighbours(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for d in dirs:
		if roads.has(cell + d):
			out.append(cell + d)
	return out


func _yaw(a: Vector2i, b: Vector2i) -> float:
	var d := Vector2(float(b.x - a.x), float(b.y - a.y))
	return atan2(d.x, d.y) + FORWARD_OFFSET


func _process(delta: float) -> void:
	if roads.size() < 3:
		return
	for car in cars:
		var node: Node3D = car["node"]
		if not is_instance_valid(node):
			continue
		var from_cell: Vector2i = car["from"]
		var to_cell: Vector2i = car["to"]
		car["t"] = float(car["t"]) + delta * float(car["speed"]) / Cfg.TILE
		if float(car["t"]) >= 1.0:
			car["t"] = float(car["t"]) - 1.0
			var prev := from_cell
			var current := to_cell
			var options := _neighbours(current)
			options.erase(prev)
			if options.is_empty():
				options = _neighbours(current)
				options.erase(current)
			if options.is_empty():
				continue
			# Prefer to keep driving straight.
			var straight := current + (current - prev)
			var next := straight if (roads.has(straight) and not options.has(prev)) else options[_rng.randi() % options.size()]
			if not roads.has(next):
				next = options[_rng.randi() % options.size()]
			car["from"] = current
			car["to"] = next
			node.rotation.y = _yaw(current, next)
		var a: Vector3 = Cfg.cell_to_world(car["from"])
		var b: Vector3 = Cfg.cell_to_world(car["to"])
		var t: float = float(car["t"])
		var smooth := t * t * (3.0 - 2.0 * t)
		node.position = a.lerp(b, smooth) + Vector3(0, 0.14, 0)