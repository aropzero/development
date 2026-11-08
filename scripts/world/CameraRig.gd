class_name CameraRig
extends Node3D
## Smooth orbit camera with touch-friendly pan / zoom / rotate helpers.

var cam: Camera3D
var target := Vector3.ZERO
var target_goal := Vector3.ZERO
var yaw := deg_to_rad(38.0)
var yaw_goal := deg_to_rad(38.0)
var pitch := deg_to_rad(50.0)
var pitch_goal := deg_to_rad(50.0)
var distance := 46.0
var dist_goal := 46.0

var min_distance := 15.0
var max_distance := 78.0
var min_pitch := deg_to_rad(28.0)
var max_pitch := deg_to_rad(78.0)

var auto_orbit := false
var auto_orbit_speed := 0.10

const BOUND := 24.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 46.0
	cam.near = 0.15
	cam.far = 500.0
	cam.current = true
	add_child(cam)
	_apply()


func _process(delta: float) -> void:
	if auto_orbit:
		yaw_goal += auto_orbit_speed * delta
	var k := 1.0 - exp(-9.0 * delta)
	target = target.lerp(target_goal, k)
	yaw = lerp_angle(yaw, yaw_goal, k)
	pitch = lerp(pitch, pitch_goal, k)
	distance = lerp(distance, dist_goal, k)
	_apply()


func _apply() -> void:
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)
	) * distance
	if cam != null:
		cam.position = target + offset
		cam.look_at(target + Vector3(0.0, 0.8, 0.0), Vector3.UP)


func orbit(dx: float, dy: float) -> void:
	yaw_goal -= dx * 0.0062
	pitch_goal = clampf(pitch_goal + dy * 0.0042, min_pitch, max_pitch)


func pan(dx: float, dy: float) -> void:
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var scale := distance * 0.00155
	target_goal -= (right * dx + forward * dy) * scale
	target_goal.x = clampf(target_goal.x, -BOUND, BOUND)
	target_goal.z = clampf(target_goal.z, -BOUND, BOUND)


func zoom(factor: float) -> void:
	dist_goal = clampf(dist_goal * factor, min_distance, max_distance)


func rotate_step(direction: float) -> void:
	yaw_goal += deg_to_rad(30.0) * direction


func tilt_step(direction: float) -> void:
	pitch_goal = clampf(pitch_goal + deg_to_rad(7.0) * direction, min_pitch, max_pitch)


func focus_cell(cell: Vector2i) -> void:
	target_goal = Cfg.cell_to_world(cell)
	target_goal.y = 0.0


func focus_center() -> void:
	target_goal = Vector3.ZERO


func reset_view() -> void:
	target_goal = Vector3.ZERO
	yaw_goal = deg_to_rad(38.0)
	pitch_goal = deg_to_rad(50.0)
	dist_goal = 46.0


func cell_under_screen(screen_pos: Vector2) -> Vector2i:
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0005:
		return Vector2i(-999, -999)
	var t := -origin.y / dir.y
	if t < 0.0 or t > 600.0:
		return Vector2i(-999, -999)
	return Cfg.world_to_cell(origin + dir * t)