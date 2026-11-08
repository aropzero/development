class_name PauseMenu
extends Control
## In-game pause / settings overlay.

signal resume_pressed()
signal save_pressed()
signal menu_pressed()
signal restart_pressed()
signal settings_changed()

var _settings_box: VBoxContainer
var _music_slider: HSlider
var _sfx_slider: HSlider
var _quality_buttons: Array[Button] = []
var _shadows_box: CheckButton
var _tips_box: CheckButton


func setup() -> void:
	name = "PauseMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.035, 0.06, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	panel.add_theme_stylebox_override("panel",
		UIKit.style(Color(0.055, 0.086, 0.14, 0.98), 24, Color(1, 1, 1, 0.08), 1, 10, 24))
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	head.add_child(Glyph.new("sun", 26.0, Cfg.COL_GOLD))
	head.add_child(UIKit.title("Horizon City", 26, Cfg.COL_TEXT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(sp)
	col.add_child(UIKit.divider())

	var resume := UIKit.text_button("Resume", true)
	resume.pressed.connect(func(): resume_pressed.emit())
	col.add_child(resume)

	var settings_toggle := UIKit.text_button("Settings")
	settings_toggle.pressed.connect(_toggle_settings)
	col.add_child(settings_toggle)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 8)
	_settings_box.visible = false
	col.add_child(_settings_box)
	_build_settings(_settings_box)

	var save_btn := UIKit.text_button("Save City")
	save_btn.pressed.connect(func(): save_pressed.emit())
	col.add_child(save_btn)

	var restart := UIKit.text_button("New City")
	restart.pressed.connect(func(): restart_pressed.emit())
	col.add_child(restart)

	var menu := UIKit.text_button("Main Menu")
	menu.pressed.connect(func(): menu_pressed.emit())
	col.add_child(menu)


func _build_settings(parent: VBoxContainer) -> void:
	parent.add_child(UIKit.divider())
	var music_row := VBoxContainer.new()
	music_row.add_theme_constant_override("separation", 2)
	parent.add_child(music_row)
	var music_head := HBoxContainer.new()
	music_head.add_theme_constant_override("separation", 8)
	music_head.add_child(Glyph.new("music", 18.0, Cfg.COL_ACCENT))
	music_head.add_child(UIKit.label("Music volume", 15, Cfg.COL_TEXT, Cfg.font_bold))
	music_row.add_child(music_head)
	_music_slider = _make_slider(SaveManager.music_volume)
	_music_slider.value_changed.connect(_on_music)
	music_row.add_child(_music_slider)

	var sfx_row := VBoxContainer.new()
	sfx_row.add_theme_constant_override("separation", 2)
	parent.add_child(sfx_row)
	var sfx_head := HBoxContainer.new()
	sfx_head.add_theme_constant_override("separation", 8)
	sfx_head.add_child(Glyph.new("speaker", 18.0, Cfg.COL_ACCENT))
	sfx_head.add_child(UIKit.label("Sound effects", 15, Cfg.COL_TEXT, Cfg.font_bold))
	sfx_row.add_child(sfx_head)
	_sfx_slider = _make_slider(SaveManager.sfx_volume)
	_sfx_slider.value_changed.connect(_on_sfx)
	sfx_row.add_child(_sfx_slider)

	parent.add_child(UIKit.label("Graphics quality", 15, Cfg.COL_TEXT, Cfg.font_bold))
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override("separation", 8)
	parent.add_child(qrow)
	var names := ["Low", "Medium", "High"]
	for i in 3:
		var b := UIKit.text_button(names[i], false, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_quality.bind(i))
		qrow.add_child(b)
		_quality_buttons.append(b)
	_update_quality_styles()

	_shadows_box = CheckButton.new()
	_shadows_box.text = "Shadows"
	_shadows_box.button_pressed = SaveManager.shadows
	_shadows_box.toggled.connect(_on_shadows)
	parent.add_child(_shadows_box)

	_tips_box = CheckButton.new()
	_tips_box.text = "Show tips"
	_tips_box.button_pressed = SaveManager.show_tips
	_tips_box.toggled.connect(_on_tips)
	parent.add_child(_tips_box)


func _make_slider(value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0, 32)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


func _toggle_settings() -> void:
	_settings_box.visible = not _settings_box.visible
	AudioMgr.ui_switch()


func _update_quality_styles() -> void:
	for i in _quality_buttons.size():
		var b := _quality_buttons[i]
		var active := i == SaveManager.quality
		if active:
			b.add_theme_stylebox_override("normal", UIKit.style(Cfg.COL_ACCENT.darkened(0.45), 15, Cfg.COL_ACCENT, 1, 0, 22))
		else:
			b.add_theme_stylebox_override("normal", UIKit.style(Cfg.COL_PANEL_2, 15, Color(1, 1, 1, 0.07), 1, 0, 22))


func _on_quality(index: int) -> void:
	SaveManager.quality = index
	SaveManager.save_settings()
	_update_quality_styles()
	settings_changed.emit()
	AudioMgr.ui_switch()


func _on_music(value: float) -> void:
	AudioMgr.set_music_volume(value)


func _on_sfx(value: float) -> void:
	AudioMgr.set_sfx_volume(value)
	AudioMgr.ui_tap()


func _on_shadows(pressed: bool) -> void:
	SaveManager.shadows = pressed
	SaveManager.save_settings()
	settings_changed.emit()


func _on_tips(pressed: bool) -> void:
	SaveManager.show_tips = pressed
	SaveManager.save_settings()


func open() -> void:
	visible = true
	_music_slider.value = SaveManager.music_volume
	_sfx_slider.value = SaveManager.sfx_volume
	_shadows_box.button_pressed = SaveManager.shadows
	_tips_box.button_pressed = SaveManager.show_tips
	_update_quality_styles()


func close() -> void:
	visible = false