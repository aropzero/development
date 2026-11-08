class_name IconBaker
extends Node
## Bakes charming 3D thumbnails of every building for the build bar.

var viewport: SubViewport
var holder: Node3D
var cam: Camera3D


const ICON_SIZE := 176


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 0, 0)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.78, 0.86, 1.0)
	e.ambient_light_energy = 0.85
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	we.environment = e
	viewport.add_child(we)

	holder = Node3D.new()
	viewport.add_child(holder)

	cam = Camera3D.new()
	cam.fov = 30.0
	cam.near = 0.05
	cam.far = 60.0
	cam.current = true
	viewport.add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, 38.0, 0.0)
	key.light_energy = 1.5
	key.light_color = Color(1.0, 0.97, 0.9)
	viewport.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, -130.0, 0.0)
	fill.light_energy = 0.55
	fill.light_color = Color(0.72, 0.82, 1.0)
	viewport.add_child(fill)


func bake(id: String, variant: int = 0) -> Texture2D:
	for child in holder.get_children():
		child.queue_free()
	await get_tree().process_frame

	var visual := BuildingDB.build_visual(id, variant, 1)
	if visual == null:
		return null
	holder.add_child(visual)
	await get_tree().process_frame

	var box := _world_aabb(visual)
	var center := box.get_center()
	var radius: float = maxf(0.4, box.size.length() * 0.5)
	var fov := deg_to_rad(cam.fov)
	var dist: float = radius / sin(fov * 0.5) * 1.06
	var dir := Vector3(0.72, 0.58, 1.0).normalized()
	cam.position = center + dir * dist
	cam.look_at(center, Vector3.UP)

	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await _wait_for_draw()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var rt := viewport.get_texture()
	if rt == null:
		return null
	var img := rt.get_image()
	if img == null or img.is_empty():
		return null
	img.resize(168, 168, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


## Waits for the next rendered frame, but never blocks forever: on a headless or
## interrupted renderer `frame_post_draw` may never fire, and the rest of the
## game must still start with procedural fallback icons.
func _wait_for_draw(max_frames: int = 8) -> void:
	var drawn := [false]
	var cb := func() -> void: drawn[0] = true
	RenderingServer.frame_post_draw.connect(cb, CONNECT_ONE_SHOT)
	var frames := 0
	while not drawn[0] and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	if RenderingServer.frame_post_draw.is_connected(cb):
		RenderingServer.frame_post_draw.disconnect(cb)


func _world_aabb(root: Node) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box := mi.global_transform * mi.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	if first:
		out = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	return out