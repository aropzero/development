class_name MainMenu
extends Node3D
## Title screen with a living 3D diorama of a small city.

var world: CityWorld
var rig: CameraRig
var ui: CanvasLayer
var _root: Control
var _overlay: Control
var _music_on: bool = true


func _ready() -> void:
	GameState.simulate = false
	QuestManager.end_city()
	GameState.time_of_day = 0.235

	world = CityWorld.new()
	world.name = "Diorama"
	add_child(world)
	world.setup(false)
	_build_diorama()

	rig = CameraRig.new()
	rig.name = "MenuCamera"
	add_child(rig)
	rig.auto_orbit = true
	rig.auto_orbit_speed = 0.055
	rig.yaw = deg_to_rad(24.0)
	rig.yaw_goal = rig.yaw
	rig.pitch = deg_to_rad(41.0)
	rig.pitch_goal = rig.pitch
	rig.distance = 60.0
	rig.dist_goal = 56.0
	rig.target = Vector3(0.0, 0.6, 0.0)
	rig.target_goal = rig.target

	_build_ui()
	AudioMgr.start_music()


func _build_diorama() -> void:
	var roads := [
		Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8), Vector2i(9, 8), Vector2i(10, 8),
		Vector2i(8, 4), Vector2i(8, 5), Vector2i(8, 6), Vector2i(8, 7),
		Vector2i(8, 9), Vector2i(8, 10), Vector2i(8, 11),
		Vector2i(5, 8), Vector2i(11, 8), Vector2i(8, 12),
	]
	for c in roads:
		world.preview_road(c)
	var homes := [
		["cottage", Vector2i(5, 7), 0], ["cottage", Vector2i(6, 7), 1],
		["house", Vector2i(6, 9), 2], ["house", Vector2i(9, 9), 0],
		["townhouse", Vector2i(9, 10), 1], ["cottage", Vector2i(5, 10), 3],
		["cottage", Vector2i(6, 5), 2], ["townhouse", Vector2i(5, 6), 0],
	]
	for h in homes:
		world.preview_place(String(h[0]), h[1], int(h[2]))
	var town := [
		["shop", Vector2i(7, 7), 0], ["cafe", Vector2i(9, 7), 0],
		["market", Vector2i(6, 10), 0], ["office", Vector2i(10, 9), 0],
		["workshop", Vector2i(10, 7), 0], ["plaza", Vector2i(7, 10), 0],
		["park", Vector2i(9, 6), 0], ["wind", Vector2i(4, 9), 0],
		["solar", Vector2i(11, 10), 0], ["school", Vector2i(10, 6), 0],
		["road", Vector2i(7, 6), 0],
	]
	for t in town:
		if String(t[0]) == "road":
			continue
		world.preview_place(String(t[0]), t[1], int(t[2]))
	world.preview_start_traffic()


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 3
	add_child(ui)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_root)

	var grad := ColorRect.new()
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = load("res://scripts/ui/menu_gradient.gdshader")
	grad.material = gm
	_root.add_child(grad)

	var safe := _safe_insets()
	var side := 76.0 + safe.x
	var content := VBoxContainer.new()
	content.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	content.offset_left = side
	content.offset_right = side + 470.0
	content.offset_top = safe.y + 24.0
	content.offset_bottom = -safe.w - 24.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(content)

	var kick := HBoxContainer.new()
	kick.add_theme_constant_override("separation", 10)
	kick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(kick)
	var line := ColorRect.new()
	line.color = Cfg.COL_ACCENT
	line.custom_minimum_size = Vector2(34, 3)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kick.add_child(line)
	kick.add_child(UIKit.label("A CALM CITY BUILDER", 13, Cfg.COL_ACCENT, Cfg.font_bold))

	var title := Label.new()
	title.text = "Horizon City"
	title.add_theme_font_override("font", Cfg.font_display)
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)

	var sub := UIKit.label("Build a little island town, one gentle day at a time.\nHomes, shops, parks and a skyline that grows with you.", 18, Cfg.COL_MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(430, 0)
	content.add_child(sub)

	content.add_child(UIKit.spacer(0, 22))

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.custom_minimum_size = Vector2(330, 0)
	content.add_child(buttons)

	if SaveManager.has_save():
		var cont := _menu_button(_continue_label(), true, "play")
		cont.pressed.connect(func(): _start(true))
		buttons.add_child(cont)

	var new_btn := _menu_button("New City", not SaveManager.has_save(), "plus")
	new_btn.pressed.connect(_ask_new_city)
	buttons.add_child(new_btn)

	var how := _menu_button("How to Play", false, "info")
	how.pressed.connect(_show_how_to)
	buttons.add_child(how)

	var credits := _menu_button("Credits & Assets", false, "heart")
	credits.pressed.connect(_show_credits)
	buttons.add_child(credits)

	if not OS.has_feature("mobile"):
		var quit := _menu_button("Quit", false, "close")
		quit.pressed.connect(func(): get_tree().quit())
		buttons.add_child(quit)

	content.add_child(UIKit.spacer(0, 14))
	content.add_child(UIKit.label("Godot 4  ·  Offline friendly  ·  Made for Android", 12, Cfg.COL_DIM))

	var sound := UIKit.icon_button("music", 46, Cfg.COL_TEXT, Color(0.045, 0.072, 0.118, 0.74))
	sound.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sound.offset_left = -side - 46.0
	sound.offset_right = -side
	sound.offset_top = safe.y + 20.0
	sound.offset_bottom = sound.offset_top + 46.0
	sound.pressed.connect(_toggle_music.bind(sound))
	_root.add_child(sound)

	var ver := UIKit.label("v1.0.0", 12, Cfg.COL_DIM, Cfg.font_body, HORIZONTAL_ALIGNMENT_RIGHT)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -side - 120.0
	ver.offset_right = -side
	ver.offset_top = -safe.w - 34.0
	ver.offset_bottom = -safe.w - 10.0
	_root.add_child(ver)


func _menu_button(text: String, primary: bool, icon_kind: String) -> Button:
	var b := UIKit.text_button("", primary, 56)
	b.custom_minimum_size = Vector2(330, 56)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22.0
	h.offset_right = -22.0
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint := Color.WHITE if primary else Cfg.COL_TEXT
	h.add_child(Glyph.new(icon_kind, 20.0, tint))
	h.add_child(UIKit.label(text, 18, tint, Cfg.font_bold))
	b.add_child(h)
	b.pressed.connect(func(): AudioMgr.ui_click())
	return b


func _continue_label() -> String:
	var data := SaveManager.load_game()
	var city: Dictionary = data.get("city", {})
	var day := int(city.get("day", 1))
	return "Continue  ·  Day %d" % day


func _start(load_save: bool) -> void:
	Game.load_on_start = load_save
	AudioMgr.ui_tap()
	SceneManager.change_scene("res://scenes/Game.tscn")


func _ask_new_city() -> void:
	if not SaveManager.has_save():
		_start(false)
		return
	var panel := _overlay_shell("Start a new city?", "Your current skyline will be replaced the next time the city is saved.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var go := UIKit.text_button("Start New City", true, 52)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.pressed.connect(func():
		_close_overlay()
		_start(false))
	row.add_child(go)
	var cancel := UIKit.text_button("Keep Playing", false, 52)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_close_overlay)
	row.add_child(cancel)
	panel["body"].add_child(row)


func _show_how_to() -> void:
	var text := """[b]Welcome to your island.[/b]

• One finger drag — orbit the camera.
• Pinch or two-finger drag — zoom and pan.
• Right mouse drag — orbit on desktop.
• Pick a building from the bottom bar, then tap a tile to place it.
• Roads connect your districts; little cars will use them.
• Tap a placed building to upgrade or sell it.

[b]Growing your city[/b]
Citizens need homes, jobs and power. Taxes arrive every day, upkeep is paid every day. Happiness rises with parks, plazas, schools and hospitals, and falls with unemployment and pollution.

Complete the City Goals on the right to earn coins and unlock new buildings. Your settlement grows from an Outpost into a Hamlet, Village, Town, City, Metropolis and finally a Megacity."""
	_overlay_shell("How to Play", text)


func _show_credits() -> void:
	var text := """[b]Horizon City[/b] was built with Godot Engine 4.

[b]3D models[/b]
Kenney — City Kit Suburban, City Kit Commercial, City Kit Roads, Nature Kit, Car Kit.
kenney.nl  ·  CC0 1.0

[b]Sound effects[/b]
Kenney — Interface Sounds, Impact Sounds, UI Pack.
kenney.nl  ·  CC0 1.0

[b]Music[/b]
Kevin MacLeod — "Floating Cities", "Meditation Impromptu 01", "Deliberate Thought".
incompetech.com  ·  CC BY 4.0

[b]Fonts[/b]
Nunito and Quicksand — SIL Open Font License 1.1.

All trademarks belong to their respective owners."""
	_overlay_shell("Credits & Assets", text)


func _overlay_shell(title: String, body_text: String) -> Dictionary:
	_close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.035, 0.06, 0.74)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(minf(640.0, get_viewport().get_visible_rect().size.x - 80.0), 0)
	panel.add_theme_stylebox_override("panel",
		UIKit.style(Color(0.055, 0.086, 0.14, 0.98), 22, Color(1, 1, 1, 0.08), 1, 10, 22))
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	head.add_child(UIKit.title(title, 24, Cfg.COL_TEXT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close := UIKit.icon_button("close", 38, Cfg.COL_MUTED, Color(1, 1, 1, 0.06))
	close.pressed.connect(_close_overlay)
	head.add_child(close)
	col.add_child(UIKit.divider())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(420.0, get_viewport().get_visible_rect().size.y - 260.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	scroll.add_child(body)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.text = body_text
	text.fit_content = true
	text.scroll_active = false
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_color_override("default_color", Cfg.COL_MUTED)
	text.add_theme_font_override("normal_font", Cfg.font_body)
	text.add_theme_font_override("bold_font", Cfg.font_bold)
	text.add_theme_font_size_override("normal_font_size", 15)
	text.add_theme_font_size_override("bold_font_size", 15)
	body.add_child(text)
	return {"panel": panel, "body": body}


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _toggle_music(btn: Button) -> void:
	_music_on = not _music_on
	if _music_on:
		AudioMgr.set_music_volume(SaveManager.music_volume)
		UIKit.set_button_icon(btn, "music", Cfg.COL_TEXT)
	else:
		AudioMgr.set_music_volume(0.0)
		UIKit.set_button_icon(btn, "speaker", Cfg.COL_DIM)
	AudioMgr.ui_tap()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and _overlay != null:
		_close_overlay()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
		if _overlay == null:
			_start(SaveManager.has_save())


func _safe_insets() -> Vector4:
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var vp := get_viewport().get_visible_rect().size
	var sx := vp.x / float(win.x)
	var sy := vp.y / float(win.y)
	return Vector4(
		maxf(0.0, float(safe.position.x) * sx),
		maxf(0.0, float(safe.position.y) * sy),
		maxf(0.0, float(win.x - safe.end.x) * sx),
		maxf(0.0, float(win.y - safe.end.y) * sy))