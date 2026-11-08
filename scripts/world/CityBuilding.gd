class_name CityBuilding
extends Node3D
## A single placed building with a little construction animation.

var cell: Vector2i
var id: String = "cottage"
var level: int = 1
var variant: int = 0
var visual: Node3D
var _smoke: CPUParticles3D
var _glow: Sprite3D


func setup(c: Vector2i, building_id: String, lvl: int, var_id: int, animate: bool = true) -> void:
	cell = c
	id = building_id
	level = lvl
	variant = var_id
	position = Cfg.cell_to_world(c, 0.0)
	_rebuild(animate)


func _rebuild(animate: bool) -> void:
	if visual != null and is_instance_valid(visual):
		visual.queue_free()
	if _smoke != null and is_instance_valid(_smoke):
		_smoke.queue_free()
	visual = BuildingDB.build_visual(id, variant, level)
	if visual == null:
		visual = Node3D.new()
	add_child(visual)
	visual.rotation.y = _facing()
	var def: Dictionary = BuildingDB.get_def(id)

	if animate:
		var target_scale := visual.scale
		visual.scale = Vector3(0.02, 0.02, 0.02)
		var tw := create_tween()
		tw.tween_property(visual, "scale", target_scale, 0.55) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_spawn_dust()

	# Factories and workshops get a friendly puff of smoke.
	var pollution := float(def.get("pollution", 0))
	if pollution >= 4.0 and String(def.get("kind", "model")) == "model":
		_smoke = BuildingDB.make_smoke(Vector3(0.15, 3.2, -0.15), 0.7, Color(0.68, 0.68, 0.7, 0.35))
		add_child(_smoke)


func _facing() -> float:
	var seed_val := variant * 37 + cell.x * 13 + cell.y * 7
	return float(posmod(seed_val, 4)) * PI * 0.5


func _spawn_dust() -> void:
	var dust := BuildingDB.make_dust(Vector3(0, 0.12, 0))
	add_child(dust)
	dust.emitting = true
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(dust.queue_free)


func refresh(animate: bool = false) -> void:
	_rebuild(animate)


func brand_new() -> void:
	scale = Vector3.ONE