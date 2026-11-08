class_name HUD
extends CanvasLayer
## The complete in-game interface: resources, goals, build bar, info panels.

signal build_selected(id: String)
signal demolish_requested()
signal cancel_requested()
signal rotate_requested(direction: float)
signal zoom_requested(direction: float)
signal center_requested()
signal pause_requested()
signal speed_changed(speed: float)
signal upgrade_requested(cell: Vector2i)
signal sell_requested(cell: Vector2i)
signal close_info()
signal save_requested()
signal menu_requested()
signal restart_requested()
signal settings_changed()

const BUILD_BAR_HEIGHT := 172.0

var root: Control
var top_left: HBoxContainer
var top_right: HBoxContainer
var task_panel: TaskPanel
var task_toggle: Button
var build_bar: BuildBar
var toast_stack: ToastStack
var hint_panel: PanelContainer
var hint_label: Label
var info_panel: PanelContainer
var pause_menu: PauseMenu
var loading: Control
var loading_label: Label

var _icons: Dictionary = {}
var _stats: Dictionary = {}
var _clock_value: Label
var _clock_sub: Label
var _clock_icon: Glyph
var _tier_value: Label
var _speed_btn: Button
var _info_cell: Vector2i = Vector2i(-2, -2)
var _info_title: Label
var _info_badge: Label
var _info_stats: Label
var _info_icon: TextureRect
var _info_upgrade: Button
var _info_sell: Button
var _clock_accum: float = 0.0
var _insets := Vector4.ZERO


func setup(icons: Dictionary) -> void:
	_icons = icons
	layer = 5
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_vignette()
	_build_top_left()
	_build_top_right()
	_build_hint()
	_build_camera_controls()
	_build_info_panel()
	_build_toast()
	_build_task_panel()
	_build_build_bar()
	_build_pause()
	_build_loading()

	GameState.changed.connect(_on_state_changed)
	GameState.toast.connect(show_toast)
	GameState.day_passed.connect(func(_d): refresh_stats())
	GameState.tier_changed.connect(func(_idx): AudioMgr.sfx_level())
	QuestManager.tasks_changed.connect(func(): task_panel.refresh())
	QuestManager.progress_changed.connect(func(): task_panel.update_progress())
	QuestManager.task_completed.connect(_on_task_completed)
	get_viewport().size_changed.connect(_apply_layout)
	_apply_layout()
	refresh_stats()
	task_panel.refresh()


# ------------------------------------------------------------------ construction

func _build_vignette() -> void:
	var v := ColorRect.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/ui/vignette.gdshader")
	v.material = mat
	root.add_child(v)


func _make_pill(icon_kind: String, color: Color, width: float, with_bar: bool) -> Dictionary:
	var p := UIKit.pill(Color(0.045, 0.072, 0.118, 0.80), 20, 10)
	p.custom_minimum_size = Vector2(width, 48 if not with_bar else 54)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	row.add_child(Glyph.new(icon_kind, 21.0, color))
	var value := UIKit.label("0", 18, Cfg.COL_TEXT, Cfg.font_bold)
	row.add_child(value)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var sub := UIKit.label("", 11, Cfg.COL_MUTED, Cfg.font_body)
	sub.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	row.add_child(sub)
	var bar: Dictionary = {}
	if with_bar:
		bar = UIKit.make_bar(color, Color(1, 1, 1, 0.10), 6.0)
		var bar_root: Control = bar["root"]
		col.add_child(bar_root)
	return {"panel": p, "value": value, "sub": sub, "bar": bar}


func _build_top_left() -> void:
	top_left = HBoxContainer.new()
	top_left.add_theme_constant_override("separation", 8)
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_left)
	_stats["money"] = _make_pill("coin", Cfg.COL_GOLD, 176, false)
	_stats["people"] = _make_pill("people", Cfg.COL_BLUE, 150, false)
	_stats["happy"] = _make_pill("heart", Cfg.COL_GREEN, 156, true)
	_stats["power"] = _make_pill("bolt", Cfg.COL_PURPLE, 150, true)
	for key in ["money", "people", "happy", "power"]:
		top_left.add_child(_stats[key]["panel"])


func _build_top_right() -> void:
	top_right = HBoxContainer.new()
	top_right.add_theme_constant_override("separation", 8)
	top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_right)

	var tier_pill := UIKit.pill(Color(0.045, 0.072, 0.118, 0.80), 20, 10)
	tier_pill.custom_minimum_size = Vector2(150, 48)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 7)
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tier_pill.add_child(th)
	th.add_child(Glyph.new("star", 20.0, Cfg.COL_GOLD))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	th.add_child(tv)
	_tier_value = UIKit.label("Outpost", 16, Cfg.COL_TEXT, Cfg.font_bold)
	tv.add_child(_tier_value)
	tv.add_child(UIKit.label("settlement", 11, Cfg.COL_MUTED))
	top_right.add_child(tier_pill)

	var clock_pill := UIKit.pill(Color(0.045, 0.072, 0.118, 0.80), 20, 10)
	clock_pill.custom_minimum_size = Vector2(158, 48)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 7)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_pill.add_child(ch)
	_clock_icon = Glyph.new("sun", 20.0, Cfg.COL_GOLD)
	ch.add_child(_clock_icon)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	ch.add_child(cv)
	_clock_value = UIKit.label("10:20", 16, Cfg.COL_TEXT, Cfg.font_bold)
	cv.add_child(_clock_value)
	_clock_sub = UIKit.label("Day 1", 11, Cfg.COL_MUTED)
	cv.add_child(_clock_sub)
	top_right.add_child(clock_pill)

	_speed_btn = UIKit.text_button("1×", false, 48)
	_speed_btn.custom_minimum_size = Vector2(58, 48)
	_speed_btn.add_theme_font_size_override("font_size", 18)
	_speed_btn.pressed.connect(_cycle_speed)
	top_right.add_child(_speed_btn)

	task_toggle = UIKit.icon_button("task", 48, Cfg.COL_TEXT, Color(0.045, 0.072, 0.118, 0.80))
	task_toggle.pressed.connect(_toggle_tasks)
	top_right.add_child(task_toggle)

	var pause := UIKit.icon_button("pause", 48, Cfg.COL_TEXT, Color(0.045, 0.072, 0.118, 0.80))
	pause.pressed.connect(func(): pause_requested.emit())
	top_right.add_child(pause)


func _build_hint() -> void:
	hint_panel = PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel",
		UIKit.style(Color(0.05, 0.08, 0.13, 0.86), 18, Color(1, 1, 1, 0.07), 1, 4, 10))
	hint_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_child(h)
	h.add_child(Glyph.new("info", 18.0, Cfg.COL_ACCENT))
	hint_label = UIKit.label("Pick a building from the bar below", 15, Cfg.COL_TEXT)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(hint_label)
	var cancel := UIKit.icon_button("close", 30, Cfg.COL_CORAL, Color(1, 1, 1, 0.06))
	cancel.pressed.connect(func(): cancel_requested.emit())
	h.add_child(cancel)


func _build_camera_controls() -> void:
	var box := HBoxContainer.new()
	box.name = "CameraControls"
	box.add_theme_constant_override("separation", 6)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(box)
	var rb := UIKit.icon_button("rotate_left", 44, Cfg.COL_TEXT, Color(0.045, 0.072, 0.118, 0.78))
	rb.pressed.connect(func(): rotate_requested.emit(-1.0))
	box.add_child(rb)
	var rb2 := UIKit.icon_button("rotate_right", 44, Cfg.COL_TEXT, Color(0.045, 0.072, 0.118, 0.78))
	rb2.pressed.connect(func(): rotate_requested.emit(1.0))
	box.add_child(rb2)
	var zo := UIKit.icon_button("zoom_out", 44, Cfg.COL_TEXT, Color(0.045, 0.072, 0.118, 0.78))
	zo.pressed.connect(func(): zoom_requested.emit(-1.0))
	box.add_child(zo)
	var zi := UIKit.icon_button("zoom_in", 44, Cfg.COL_TEXT, Color(0.045, 0.072, 0.118, 0.78))
	zi.pressed.connect(func(): zoom_requested.emit(1.0))
	box.add_child(zi)
	var cc := UIKit.icon_button("center", 44, Cfg.COL_TEXT, Color(0.045, 0.072, 0.118, 0.78))
	cc.pressed.connect(func(): center_requested.emit())
	box.add_child(cc)


func _build_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.add_theme_stylebox_override("panel",
		UIKit.style(Color(0.05, 0.08, 0.13, 0.94), 20, Color(1, 1, 1, 0.08), 1, 6, 14))
	info_panel.custom_minimum_size = Vector2(370, 0)
	info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	info_panel.grow_horizontal = Control.GROW_DIRECTION_END
	info_panel.visible = false
	root.add_child(info_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	info_panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	_info_icon = TextureRect.new()
	_info_icon.custom_minimum_size = Vector2(54, 54)
	_info_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_info_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_info_icon)
	var tcol := VBoxContainer.new()
	tcol.add_theme_constant_override("separation", 0)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tcol)
	_info_title = UIKit.label("Building", 20, Cfg.COL_TEXT, Cfg.font_display)
	tcol.add_child(_info_title)
	_info_badge = UIKit.label("Level 1", 13, Cfg.COL_ACCENT, Cfg.font_bold)
	tcol.add_child(_info_badge)
	var close := UIKit.icon_button("close", 36, Cfg.COL_MUTED, Color(1, 1, 1, 0.06))
	close.pressed.connect(func(): close_info.emit())
	head.add_child(close)

	_info_stats = UIKit.label("", 14, Cfg.COL_MUTED)
	_info_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_info_stats)
	col.add_child(UIKit.divider())

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	col.add_child(buttons)
	_info_upgrade = UIKit.text_button("Upgrade", true, 48)
	_info_upgrade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_upgrade.pressed.connect(func():
		if _info_cell.x >= 0:
			upgrade_requested.emit(_info_cell))
	buttons.add_child(_info_upgrade)
	_info_sell = UIKit.text_button("Sell", false, 48)
	_info_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_sell.pressed.connect(func():
		if _info_cell.x >= 0:
			sell_requested.emit(_info_cell))
	buttons.add_child(_info_sell)


func _build_toast() -> void:
	toast_stack = ToastStack.new()
	toast_stack.setup()
	toast_stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(toast_stack)


func _build_task_panel() -> void:
	task_panel = TaskPanel.new()
	task_panel.setup()
	root.add_child(task_panel)


func _build_build_bar() -> void:
	build_bar = BuildBar.new()
	build_bar.setup(_icons)
	build_bar.build_selected.connect(func(id): build_selected.emit(id))
	build_bar.demolish_selected.connect(func(): demolish_requested.emit())
	root.add_child(build_bar)


func _build_pause() -> void:
	pause_menu = PauseMenu.new()
	pause_menu.setup()
	pause_menu.resume_pressed.connect(func(): pause_requested.emit())
	pause_menu.save_pressed.connect(func(): save_requested.emit())
	pause_menu.menu_pressed.connect(func(): menu_requested.emit())
	pause_menu.restart_pressed.connect(func(): restart_requested.emit())
	pause_menu.settings_changed.connect(func(): settings_changed.emit())
	root.add_child(pause_menu)


func _build_loading() -> void:
	loading = Control.new()
	loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading.mouse_filter = Control.MOUSE_FILTER_STOP
	loading.visible = false
	root.add_child(loading)
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.055, 0.09, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	col.add_child(UIKit.title("Horizon City", 40, Cfg.COL_TEXT))
	var sub := UIKit.label("Growing the trees…", 18, Cfg.COL_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	loading_label = sub


# ------------------------------------------------------------------ layout

func _apply_layout() -> void:
	_insets = _safe_insets()
	var vp := get_viewport().get_visible_rect().size
	var w := vp.x
	var h := vp.y
	var sl := _insets.x
	var st := _insets.y
	var sr := _insets.z
	var sb := _insets.w
	var compact := w < 980.0

	top_left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	top_left.position = Vector2(16.0 + sl, 12.0 + st)

	top_right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	top_right.offset_right = -(16.0 + sr)
	top_right.offset_top = 12.0 + st
	top_right.offset_bottom = top_right.offset_top + 54.0
	top_right.offset_left = top_right.offset_right - top_right.get_combined_minimum_size().x

	task_toggle.visible = compact
	task_panel.visible = not compact
	task_panel.custom_minimum_size = Vector2(300, 0)
	task_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	task_panel.offset_right = -(16.0 + sr)
	task_panel.offset_left = task_panel.offset_right - (minf(320.0, w * 0.30))
	task_panel.offset_top = 78.0 + st
	task_panel.offset_bottom = minf(h - BUILD_BAR_HEIGHT - 30.0 - sb, task_panel.offset_top + 420.0)

	build_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	build_bar.offset_left = 16.0 + sl
	build_bar.offset_right = -(16.0 + sr)
	build_bar.offset_bottom = -(12.0 + sb)
	build_bar.offset_top = build_bar.offset_bottom - BUILD_BAR_HEIGHT

	hint_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_panel.offset_bottom = build_bar.offset_top - 6.0
	hint_panel.offset_top = hint_panel.offset_bottom - 46.0
	hint_panel.offset_left = w * 0.5 - 240.0
	hint_panel.offset_right = w * 0.5 + 240.0

	var box := root.get_node_or_null("CameraControls") as Control
	if box != null:
		box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		box.offset_left = 16.0 + sl
		box.offset_bottom = build_bar.offset_top - 6.0
		box.offset_top = box.offset_bottom - 46.0
		box.offset_right = box.offset_left + box.get_combined_minimum_size().x

	info_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	info_panel.offset_left = 16.0 + sl
	info_panel.offset_bottom = build_bar.offset_top - 58.0
	info_panel.offset_right = info_panel.offset_left + minf(380.0, w * 0.36)
	info_panel.offset_top = info_panel.offset_bottom - info_panel.get_combined_minimum_size().y

	toast_stack.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_stack.offset_left = w * 0.5 - 240.0
	toast_stack.offset_right = w * 0.5 + 240.0
	toast_stack.offset_top = 76.0 + st
	toast_stack.offset_bottom = toast_stack.offset_top + 200.0


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


# ------------------------------------------------------------------ updates

func _process(delta: float) -> void:
	_clock_accum += delta
	if _clock_accum < 0.25:
		return
	_clock_accum = 0.0
	_clock_value.text = Cfg.format_time(GameState.time_of_day)
	_clock_sub.text = "Day %d" % GameState.day
	var night := GameState.night_factor() > 0.5
	_clock_icon.kind = "moon" if night else "sun"
	_clock_icon.tint = Color(0.75, 0.82, 1.0) if night else Cfg.COL_GOLD


func refresh_stats() -> void:
	var money: Dictionary = _stats["money"]
	money["value"].text = Cfg.format_money(GameState.money)
	var net := GameState.estimated_net()
	money["sub"].text = "%s%s/day" % ["+" if net >= 0.0 else "", Cfg.format_short(net)]
	money["sub"].add_theme_color_override("font_color", Cfg.COL_GREEN if net >= 0.0 else Cfg.COL_CORAL)

	var people: Dictionary = _stats["people"]
	people["value"].text = str(int(GameState.population))
	people["sub"].text = "/ %d cap" % GameState.housing_capacity

	var happy: Dictionary = _stats["happy"]
	happy["value"].text = "%d%%" % int(GameState.happiness)
	var hcolor := Cfg.COL_GREEN if GameState.happiness >= 65.0 else (Cfg.COL_GOLD if GameState.happiness >= 40.0 else Cfg.COL_CORAL)
	happy["value"].add_theme_color_override("font_color", hcolor)
	happy["sub"].text = "happy"
	UIKit.set_bar(happy["bar"], GameState.happiness / 100.0)

	var power: Dictionary = _stats["power"]
	power["value"].text = "%d/%d" % [GameState.power_make, GameState.power_use]
	var ok := GameState.power_make >= GameState.power_use
	power["value"].add_theme_color_override("font_color", Cfg.COL_GREEN if ok else Cfg.COL_CORAL)
	power["sub"].text = "power"
	UIKit.set_bar(power["bar"], GameState.power_ratio())

	_tier_value.text = Cfg.tier_name(GameState.population)

	if info_panel.visible and _info_cell.x >= 0:
		refresh_info()


func set_mode(id: String, demolish: bool) -> void:
	build_bar.set_active(id, demolish)
	if demolish:
		hint_label.text = "Tap a tile to remove it"
	elif id != "":
		var def := BuildingDB.get_def(id)
		hint_label.text = "Tap a tile to place %s" % String(def.get("name", ""))
	else:
		hint_label.text = "Pick a building from the bar below"


func refresh_build_bar(force: bool = false) -> void:
	build_bar.refresh(force)


func _on_state_changed() -> void:
	refresh_stats()
	build_bar.refresh()


func _on_task_completed(task: Dictionary) -> void:
	toast_stack.push("Goal complete: %s  +%s" % [String(task.get("title", "")),
		Cfg.format_money(float(task.get("reward", 0)))], "star", "level")
	AudioMgr.sfx_task()
	AudioMgr.ui_confirm()
	task_panel.refresh()


func show_toast(text: String, icon: String = "info", tone: String = "info") -> void:
	toast_stack.push(text, icon, tone)
	if tone == "good" or tone == "level":
		AudioMgr.sfx_coin()


# ------------------------------------------------------------------ selection info

func show_selected(cell: Vector2i) -> void:
	_info_cell = cell
	var b := GameState.building_at(cell)
	if b.is_empty():
		if GameState.has_road(cell):
			_info_icon.texture = _icons.get("road", null)
			_info_title.text = "Road"
			_info_badge.text = "Infrastructure"
			_info_stats.text = "Connects districts. Cars love it."
			_info_upgrade.visible = false
			_info_sell.text = "Remove  +%s" % Cfg.format_money(GameState.sell_value(cell))
			info_panel.visible = true
			_apply_layout()
		return
	var def := BuildingDB.get_def(String(b["id"]))
	_info_icon.texture = _icons.get(String(b["id"]), null)
	_info_title.text = String(def.get("name", "Building"))
	_info_badge.text = "Level %d" % int(b["level"])
	var lines: Array[String] = []
	if int(def.get("housing", 0)) > 0:
		lines.append("Homes %d citizens" % int(def["housing"]))
	if int(def.get("jobs", 0)) > 0:
		lines.append("Jobs %d" % int(def["jobs"]))
	if int(def.get("power_make", 0)) > 0:
		lines.append("Power +%d" % int(def["power_make"]))
	if int(def.get("power_use", 0)) > 0:
		lines.append("Power use %d" % int(def["power_use"]))
	if float(def.get("tax", 0)) > 0.0:
		lines.append("Income %s/day" % Cfg.format_money(float(def["tax"])))
	if float(def.get("happiness", 0)) != 0.0:
		lines.append("Happiness %+.1f" % float(def["happiness"]))
	if float(def.get("pollution", 0)) > 0.0:
		lines.append("Pollution %.0f" % float(def["pollution"]))
	lines.append(String(def.get("blurb", "")))
	_info_stats.text = "\n".join(lines)
	_info_upgrade.visible = int(b["level"]) < 3
	var cost := GameState.upgrade_cost(cell)
	_info_upgrade.text = "Upgrade  %s" % Cfg.format_money(cost)
	_info_upgrade.disabled = GameState.money < cost
	_info_sell.text = "Sell  +%s" % Cfg.format_money(GameState.sell_value(cell))
	info_panel.visible = true
	_apply_layout()


func refresh_info() -> void:
	if _info_cell.x < 0:
		return
	var b := GameState.building_at(_info_cell)
	if b.is_empty():
		return
	if int(b["level"]) >= 3:
		_info_upgrade.disabled = true
		_info_upgrade.text = "Max level"
	else:
		var cost := GameState.upgrade_cost(_info_cell)
		_info_upgrade.text = "Upgrade  %s" % Cfg.format_money(cost)
		_info_upgrade.disabled = GameState.money < cost
	_info_sell.text = "Sell  +%s" % Cfg.format_money(GameState.sell_value(_info_cell))
	_info_badge.text = "Level %d" % int(b["level"])
	_apply_layout()


func hide_info() -> void:
	_info_cell = Vector2i(-2, -2)
	info_panel.visible = false


func reset_info() -> void:
	hide_info()


# ------------------------------------------------------------------ misc

func _cycle_speed() -> void:
	var speeds := [1.0, 2.0, 3.0]
	var idx := speeds.find(GameState.speed)
	idx = (idx + 1) % speeds.size()
	_speed_btn.text = "%d×" % int(speeds[idx])
	speed_changed.emit(speeds[idx])
	AudioMgr.ui_switch()


func _toggle_tasks() -> void:
	task_panel.visible = not task_panel.visible
	AudioMgr.ui_switch()


func set_paused(paused: bool) -> void:
	if paused:
		pause_menu.open()
	else:
		pause_menu.close()


func is_paused() -> bool:
	return pause_menu.visible


func set_loading(text: String, visible: bool = true) -> void:
	loading.visible = visible
	if text != "":
		loading_label.text = text


func hide_loading() -> void:
	loading.visible = false