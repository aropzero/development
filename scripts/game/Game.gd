class_name Game
extends Node3D
## The main gameplay scene: builds the world, runs input, drives the HUD.

static var load_on_start: bool = false

var world: CityWorld
var rig: CameraRig
var hud: HUD
var baker: IconBaker
var icons: Dictionary = {}

var build_mode: String = ""
var demolish_mode: bool = false
var selected_cell: Vector2i = Vector2i(-2, -2)

var _touches: Dictionary = {}
var _pointer_moved: bool = false
var _pointer_down: bool = false
var _drag_last := Vector2.ZERO
var _two_center := Vector2.ZERO
var _two_dist: float = 0.0
var _save_timer: float = 0.0
var _last_hover_cell: Vector2i = Vector2i(-999, -999)
var _right_down: bool = false
var _middle_down: bool = false
var _touch_seen: bool = false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0a1020"))
	if load_on_start and SaveManager.has_save():
		var data := SaveManager.load_game()
		GameState.from_dict(data.get("city", {}))
		QuestManager.begin(true, data.get("quests", {}))
	else:
		GameState.new_game()
		QuestManager.begin(false)
	GameState.simulate = true

	world = CityWorld.new()
	world.name = "World"
	add_child(world)
	world.setup(true)

	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.reset_view()
	var focus := _city_center()
	rig.target_goal = focus
	rig.target = focus

	# Build the interface first so the player can interact immediately, then
	# fill the build-bar thumbnails in as they finish baking.
	_build_hud()
	_apply_settings()
	await _bake_icons()
	hud.refresh_build_bar(true)

	AudioMgr.start_music()
	_save_timer = 0.0
	if GameState.tutorial_step == 0 and GameState.total_built.is_empty():
		hud.show_toast("Welcome to Horizon City! Build your first cottage.", "star", "level")


func _city_center() -> Vector3:
	if GameState.buildings.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	var n := 0
	for cell in GameState.buildings:
		sum += Cfg.cell_to_world(cell)
		n += 1
	return sum / float(maxi(1, n))


func _bake_icons() -> void:
	baker = IconBaker.new()
	baker.name = "IconBaker"
	add_child(baker)
	await get_tree().process_frame
	var defs := BuildingDB.all()
	for i in defs.size():
		var def: Dictionary = defs[i]
		var id := String(def["id"])
		var tex := await baker.bake(id, (i * 5) % 4)
		if tex != null:
			icons[id] = tex
	baker.queue_free()
	baker = null


func _build_hud() -> void:
	hud = HUD.new()
	hud.name = "HUD"
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	hud.setup(icons)
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.build_selected.connect(_enter_build_mode)
	hud.demolish_requested.connect(_toggle_demolish)
	hud.cancel_requested.connect(_cancel_mode)
	hud.rotate_requested.connect(func(dir): rig.rotate_step(dir))
	hud.zoom_requested.connect(func(dir): rig.zoom(0.86 if dir > 0.0 else 1.16))
	hud.center_requested.connect(func(): rig.focus_center())
	hud.pause_requested.connect(_toggle_pause)
	hud.speed_changed.connect(func(s): GameState.speed = s)
	hud.upgrade_requested.connect(_upgrade)
	hud.sell_requested.connect(_demolish)
	hud.close_info.connect(_clear_selection)
	hud.save_requested.connect(_save_game)
	hud.menu_requested.connect(_go_menu)
	hud.restart_requested.connect(_restart_city)
	hud.settings_changed.connect(_apply_settings)


func _apply_settings() -> void:
	if world == null:
		return
	world.apply_quality(SaveManager.quality)
	if world.sun != null:
		world.sun.shadow_enabled = SaveManager.shadows and SaveManager.quality > 0


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch_seen = true
	# Android also feeds us mouse events emulated from the touchscreen. Handling
	# both would double every gesture (and double the camera orbit speed), so
	# once real touch input exists we ignore the mouse streams.
	if not _touch_seen:
		if event is InputEventMouseButton:
			_handle_mouse_button(event)
			return
		if event is InputEventMouseMotion:
			_handle_mouse_motion(event)
			return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		rig.zoom(0.88)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		rig.zoom(1.14)
	elif event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down = true
			_pointer_moved = false
			_drag_last = event.position
		else:
			if _pointer_down and not _pointer_moved:
				_handle_tap(event.position)
			_pointer_down = false
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_right_down = event.pressed
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_middle_down = event.pressed


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _right_down:
		rig.orbit(event.relative.x, event.relative.y)
	elif _middle_down:
		rig.pan(event.relative.x, event.relative.y)
	elif _pointer_down:
		var moved := event.position.distance_to(_drag_last)
		if moved > 6.0:
			_pointer_moved = true
		if _pointer_moved:
			if build_mode != "" or demolish_mode:
				var cell := rig.cell_under_screen(event.position)
				_paint_cell(cell)
			else:
				rig.orbit(event.relative.x, event.relative.y)
		_drag_last = event.position
	else:
		if build_mode != "" or demolish_mode:
			_update_hover(rig.cell_under_screen(event.position))


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_pointer_down = true
			_pointer_moved = false
			_drag_last = event.position
		else:
			_pointer_moved = true
			var pts := _touch_positions()
			if pts.size() >= 2:
				_two_center = (pts[0] + pts[1]) * 0.5
				_two_dist = pts[0].distance_to(pts[1])
	else:
		_touches.erase(event.index)
		if _touches.size() == 0:
			if _pointer_down and not _pointer_moved:
				_handle_tap(event.position)
			_pointer_down = false
		else:
			_pointer_moved = true


func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() >= 2:
		_pointer_moved = true
		var pts := _touch_positions()
		if pts.size() >= 2:
			var center: Vector2 = (pts[0] + pts[1]) * 0.5
			var dist: float = pts[0].distance_to(pts[1])
			rig.pan(center.x - _two_center.x, center.y - _two_center.y)
			if _two_dist > 1.0 and dist > 1.0:
				rig.zoom(clampf(_two_dist / dist, 0.85, 1.18))
			_two_center = center
			_two_dist = dist
		return
	if not _pointer_down:
		return
	var moved := event.position.distance_to(_drag_last)
	if moved > 20.0:
		_pointer_moved = true
	if _pointer_moved:
		if build_mode != "" or demolish_mode:
			_paint_cell(rig.cell_under_screen(event.position))
		else:
			rig.orbit(event.relative.x, event.relative.y)
	_drag_last = event.position


func _touch_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for k in _touches:
		out.append(_touches[k] as Vector2)
	return out


func _handle_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE:
			if hud.is_paused():
				_toggle_pause()
			elif build_mode != "" or demolish_mode:
				_cancel_mode()
			else:
				_toggle_pause()
		KEY_SPACE:
			_toggle_pause()
		KEY_R:
			rig.rotate_step(-1.0)
		KEY_F:
			rig.rotate_step(1.0)
		KEY_EQUAL, KEY_KP_ADD:
			rig.zoom(0.86)
		KEY_MINUS, KEY_KP_SUBTRACT:
			rig.zoom(1.16)
		KEY_HOME:
			rig.focus_center()
		KEY_1, KEY_2, KEY_3:
			var speeds := {KEY_1: 1.0, KEY_2: 2.0, KEY_3: 3.0}
			GameState.speed = speeds[event.keycode]


func _process(delta: float) -> void:
	var pan := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		pan.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		pan.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		pan.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		pan.y += 1.0
	if pan != Vector2.ZERO:
		rig.pan(pan.x * 12.0, pan.y * 12.0)

	if not _touch_seen and (build_mode != "" or demolish_mode) \
			and not _pointer_down and _touches.is_empty():
		var mouse := get_viewport().get_mouse_position()
		_update_hover(rig.cell_under_screen(mouse))

	_save_timer += delta
	if _save_timer > 25.0:
		_save_timer = 0.0
		SaveManager.save_game()


# ------------------------------------------------------------------ actions

func _enter_build_mode(id: String) -> void:
	build_mode = id
	demolish_mode = false
	selected_cell = Vector2i(-2, -2)
	world.set_selected(selected_cell)
	hud.hide_info()
	hud.set_mode(id, false)
	_last_hover_cell = Vector2i(-999, -999)
	var def := BuildingDB.get_def(id)
	if GameState.population < float(def.get("unlock", 0)):
		hud.show_toast("Unlocks at %d citizens" % int(def["unlock"]), "lock", "info")


func _toggle_demolish() -> void:
	demolish_mode = not demolish_mode
	build_mode = ""
	selected_cell = Vector2i(-2, -2)
	world.set_selected(selected_cell)
	hud.hide_info()
	hud.set_mode("", demolish_mode)
	_last_hover_cell = Vector2i(-999, -999)


func _cancel_mode() -> void:
	build_mode = ""
	demolish_mode = false
	hud.set_mode("", false)
	world.hide_ghost()
	_last_hover_cell = Vector2i(-999, -999)


func _update_hover(cell: Vector2i) -> void:
	if cell == _last_hover_cell:
		return
	_last_hover_cell = cell
	if not Cfg.is_inside(cell):
		world.hide_ghost()
		return
	if demolish_mode:
		world.show_ghost("", cell, false)
		world.ghost_holder.visible = false
		world.ghost_highlight.visible = true
		world.ghost_highlight.position = Cfg.cell_to_world(cell, 0.06)
		var hi := world.ghost_highlight.material_override as ShaderMaterial
		if hi != null:
			hi.set_shader_parameter("color", Color(1.0, 0.36, 0.32, 0.9))
		return
	if build_mode == "":
		world.hide_ghost()
		return
	var err := GameState.can_place(build_mode, cell)
	world.show_ghost(build_mode, cell, err == "")


func _paint_cell(cell: Vector2i) -> void:
	if not Cfg.is_inside(cell):
		return
	if cell == _last_hover_cell:
		return
	_last_hover_cell = cell
	if demolish_mode:
		_demolish(cell)
		return
	if build_mode == "road":
		_place(cell)
	else:
		_update_hover(cell)


func _handle_tap(pos: Vector2) -> void:
	var cell := rig.cell_under_screen(pos)
	if not Cfg.is_inside(cell):
		if not demolish_mode and build_mode == "":
			_clear_selection()
		return
	if demolish_mode:
		_demolish(cell)
	elif build_mode != "":
		_place(cell)
	else:
		_select(cell)


func _place(cell: Vector2i) -> void:
	if build_mode == "road":
		var err := GameState.try_road(cell)
		if err == "":
			world.add_road_tile(cell)
			AudioMgr.sfx_road()
			_sparkle(cell, Color(0.85, 0.88, 0.92))
		else:
			hud.show_toast(err, "bolt", "bad")
			AudioMgr.sfx_error()
		return
	if build_mode == "":
		return
	var def := BuildingDB.get_def(build_mode)
	var variant := posmod(cell.x * 31 + cell.y * 17 + build_mode.hash(), 997)
	var err := GameState.try_place(build_mode, cell, variant)
	if err == "":
		world.spawn_building(cell, build_mode, 1, variant, true)
		AudioMgr.sfx_place()
		_sparkle(cell, Cfg.cat_color(String(def.get("cat", "civic"))))
		_last_hover_cell = Vector2i(-999, -999)
	else:
		hud.show_toast(err, "bolt", "bad")
		AudioMgr.sfx_error()


func _demolish(cell: Vector2i) -> void:
	if not GameState.cell_free(cell):
		var refund := GameState.sell_value(cell)
		var err := GameState.demolish(cell)
		if err == "":
			if world.building_nodes.has(cell):
				world.remove_building(cell)
			if world.road_nodes.has(cell):
				world.remove_road_tile(cell)
			AudioMgr.sfx_demolish()
			hud.show_toast("Removed  +%s" % Cfg.format_money(refund), "coin", "good")
			if selected_cell == cell:
				_clear_selection()
		else:
			hud.show_toast(err, "bolt", "bad")
	else:
		hud.show_toast("Nothing to remove here", "info", "info")
		AudioMgr.sfx_error()


func _upgrade(cell: Vector2i) -> void:
	var err := GameState.try_upgrade(cell)
	if err == "":
		var node = world.building_nodes.get(cell)
		if node != null and is_instance_valid(node):
			(node as CityBuilding).refresh(true)
		AudioMgr.sfx_upgrade()
		_sparkle(cell, Cfg.COL_GOLD)
		hud.show_selected(cell)
	else:
		hud.show_toast(err, "upgrade", "bad")
		AudioMgr.sfx_error()


func _select(cell: Vector2i) -> void:
	if GameState.cell_free(cell):
		_clear_selection()
		return
	selected_cell = cell
	world.set_selected(cell)
	hud.show_selected(cell)
	AudioMgr.ui_tap()


func _clear_selection() -> void:
	selected_cell = Vector2i(-2, -2)
	world.set_selected(selected_cell)
	hud.hide_info()


func _sparkle(cell: Vector2i, color: Color) -> void:
	var p := BuildingDB.make_sparkle(Cfg.cell_to_world(cell, 0.6), color)
	world.add_child(p)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ flow

func _toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	hud.set_paused(paused)
	if paused:
		SaveManager.save_game()
		AudioMgr.ui_switch()


func _save_game() -> void:
	SaveManager.save_game()
	hud.show_toast("City saved", "save", "good")


func _go_menu() -> void:
	SaveManager.save_game()
	GameState.simulate = false
	QuestManager.end_city()
	get_tree().paused = false
	hud.set_paused(false)
	SceneManager.change_scene("res://scenes/MainMenu.tscn")


func _restart_city() -> void:
	GameState.new_game()
	GameState.simulate = true
	QuestManager.begin(false)
	world.rebuild_from_state()
	hud.hide_info()
	hud.set_mode("", false)
	hud.refresh_stats()
	hud.refresh_build_bar()
	build_mode = ""
	demolish_mode = false
	get_tree().paused = false
	hud.set_paused(false)
	rig.reset_view()
	hud.show_toast("A brand new city begins!", "star", "level")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		SaveManager.save_game()


## Android hardware / gesture back: never dumps the player straight out of a
## running city. Close the topmost layer first, then offer the pause menu.
func _on_back_pressed() -> void:
	if hud != null and hud.is_paused():
		_toggle_pause()
	elif build_mode != "" or demolish_mode:
		_cancel_mode()
	elif hud != null and hud.info_panel.visible:
		_clear_selection()
	else:
		SaveManager.save_game()
		_toggle_pause()