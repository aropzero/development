class_name BuildBar
extends PanelContainer
## Bottom construction bar: category tabs + scrollable building cards.

signal build_selected(id: String)
signal demolish_selected()

var _icons: Dictionary = {}
var _cards_root: HBoxContainer
var _scroll: ScrollContainer
var _tabs: Dictionary = {}
var _tab_labels: Dictionary = {}
var _cards: Dictionary = {}
var _category: String = "homes"
var _active_id: String = ""
var _demolish_active: bool = false
var _demolish_btn: Button
var _hint_label: Label
var _unlocked_hash: int = -1


func setup(icons: Dictionary, ui_scale: float = 1.0) -> void:
	_icons = icons
	name = "BuildBar"
	add_theme_stylebox_override("panel",
		UIKit.style(Color(0.055, 0.086, 0.14, 0.90), 20, Color(1, 1, 1, 0.07), 1, 6, 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	# --- tabs row ---
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	for cat in Cfg.CATEGORIES:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.add_theme_constant_override("separation", 6)
		var g := Glyph.new(String(cat["icon"]), 19.0, cat["color"])
		h.add_child(g)
		var l := UIKit.label(String(cat["name"]), 15, Cfg.COL_MUTED, Cfg.font_bold)
		l.name = "TabLabel"
		h.add_child(l)
		b.add_child(h)
		b.pressed.connect(_on_tab.bind(String(cat["id"])))
		tabs.add_child(b)
		_tabs[String(cat["id"])] = b
		_tab_labels[String(cat["id"])] = l

	_demolish_btn = Button.new()
	_demolish_btn.custom_minimum_size = Vector2(130, 44)
	_demolish_btn.focus_mode = Control.FOCUS_NONE
	_demolish_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var dh := HBoxContainer.new()
	dh.alignment = BoxContainer.ALIGNMENT_CENTER
	dh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dh.add_theme_constant_override("separation", 6)
	dh.add_child(Glyph.new("trash", 19.0, Cfg.COL_CORAL))
	dh.add_child(UIKit.label("Remove", 15, Cfg.COL_CORAL, Cfg.font_bold))
	_demolish_btn.add_child(dh)
	_demolish_btn.pressed.connect(_on_demolish)
	tabs.add_child(_demolish_btn)

	# --- cards ---
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 104)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	column.add_child(_scroll)
	_cards_root = HBoxContainer.new()
	_cards_root.add_theme_constant_override("separation", 8)
	_cards_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_cards_root)

	_refresh_tabs()
	_show_category(_category)
	refresh()


func _style_tab(b: Button, active: bool, color: Color) -> void:
	if active:
		b.add_theme_stylebox_override("normal", UIKit.style(color.darkened(0.55), 13, color, 1, 0, 10))
		b.add_theme_stylebox_override("hover", UIKit.style(color.darkened(0.45), 13, color, 1, 0, 10))
		b.add_theme_stylebox_override("pressed", UIKit.style(color.darkened(0.6), 13, color, 1, 0, 10))
	else:
		b.add_theme_stylebox_override("normal", UIKit.style(Color(1, 1, 1, 0.05), 13, Color(1, 1, 1, 0.05), 1, 0, 10))
		b.add_theme_stylebox_override("hover", UIKit.style(Color(1, 1, 1, 0.10), 13, Color(1, 1, 1, 0.10), 1, 0, 10))
		b.add_theme_stylebox_override("pressed", UIKit.style(color.darkened(0.5), 13, color, 1, 0, 10))


func _refresh_tabs() -> void:
	for cat in Cfg.CATEGORIES:
		var id := String(cat["id"])
		var active := id == _category
		_style_tab(_tabs[id], active, cat["color"])
		var l: Label = _tab_labels[id]
		l.add_theme_color_override("font_color", Color.WHITE if active else Cfg.COL_MUTED)
	_style_demolish()


func _style_demolish() -> void:
	if _demolish_active:
		_demolish_btn.add_theme_stylebox_override("normal", UIKit.style(Cfg.COL_CORAL.darkened(0.55), 13, Cfg.COL_CORAL, 1, 0, 10))
		_demolish_btn.add_theme_stylebox_override("hover", UIKit.style(Cfg.COL_CORAL.darkened(0.45), 13, Cfg.COL_CORAL, 1, 0, 10))
		_demolish_btn.add_theme_stylebox_override("pressed", UIKit.style(Cfg.COL_CORAL.darkened(0.65), 13, Cfg.COL_CORAL, 1, 0, 10))
	else:
		_demolish_btn.add_theme_stylebox_override("normal", UIKit.style(Color(1, 1, 1, 0.05), 13, Color(1, 1, 1, 0.05), 1, 0, 10))
		_demolish_btn.add_theme_stylebox_override("hover", UIKit.style(Cfg.COL_CORAL.darkened(0.5), 13, Cfg.COL_CORAL, 1, 0, 10))
		_demolish_btn.add_theme_stylebox_override("pressed", UIKit.style(Cfg.COL_CORAL.darkened(0.6), 13, Cfg.COL_CORAL, 1, 0, 10))


func _on_tab(cat: String) -> void:
	_category = cat
	_refresh_tabs()
	_show_category(cat)
	AudioMgr.ui_switch()


func _on_demolish() -> void:
	_demolish_active = not _demolish_active
	if _demolish_active:
		_active_id = ""
	_focus_active_card()
	_style_demolish()
	demolish_selected.emit()
	AudioMgr.ui_switch()


func _on_card(id: String) -> void:
	_active_id = id
	_demolish_active = false
	_style_demolish()
	_focus_active_card()
	build_selected.emit(id)
	AudioMgr.ui_tap()


func _focus_active_card() -> void:
	for id in _cards:
		var card: Button = _cards[id]
		var active: bool = String(id) == _active_id
		_style_card(card, active, _is_locked(id))
	# Scroll active into view.
	if _cards.has(_active_id):
		var card: Button = _cards[_active_id]
		await get_tree().process_frame
		if is_instance_valid(card) and _scroll != null:
			_scroll.ensure_control_visible(card)


func _is_locked(id: String) -> bool:
	var d := BuildingDB.get_def(id)
	return GameState.population < float(d.get("unlock", 0))


func _style_card(card: Button, active: bool, locked: bool) -> void:
	var accent := Cfg.COL_ACCENT
	if active:
		card.add_theme_stylebox_override("normal", UIKit.style(Color(0.10, 0.20, 0.24, 0.95), 15, accent, 2, 0, 6))
		card.add_theme_stylebox_override("hover", UIKit.style(Color(0.13, 0.24, 0.29, 0.95), 15, accent, 2, 0, 6))
		card.add_theme_stylebox_override("pressed", UIKit.style(Color(0.09, 0.18, 0.22, 0.95), 15, accent, 2, 0, 6))
	else:
		card.add_theme_stylebox_override("normal", UIKit.style(Color(1, 1, 1, 0.06), 15, Color(1, 1, 1, 0.06), 1, 0, 6))
		card.add_theme_stylebox_override("hover", UIKit.style(Color(1, 1, 1, 0.12), 15, Color(1, 1, 1, 0.14), 1, 0, 6))
		card.add_theme_stylebox_override("pressed", UIKit.style(Color(1, 1, 1, 0.16), 15, accent, 1, 0, 6))
	if locked:
		card.modulate = Color(0.66, 0.70, 0.80, 0.85)
	else:
		card.modulate = Color.WHITE


func _show_category(cat: String) -> void:
	for child in _cards_root.get_children():
		child.queue_free()
	_cards.clear()
	for def in BuildingDB.in_category(cat):
		var card := _make_card(def)
		_cards[String(def["id"])] = card
		_cards_root.add_child(card)
	_style_demolish()
	_focus_active_card()


func _make_card(def: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(118, 96)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var id := String(def["id"])

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 6
	v.offset_bottom = -6
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)

	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(46, 46)
	icon_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _icons.has(id):
		var tex := TextureRect.new()
		tex.texture = _icons[id]
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(tex)
	else:
		var fallback := Glyph.new(_cat_icon(String(def["cat"])), 0.0,
			Cfg.cat_color(String(def["cat"])))
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon_holder.add_child(fallback)
	v.add_child(icon_holder)

	var name_label := UIKit.label(String(def["name"]), 12, Cfg.COL_TEXT, Cfg.font_bold, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	v.add_child(name_label)

	var cost_row := HBoxContainer.new()
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 4)
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.add_child(Glyph.new("coin", 14.0, Cfg.COL_GOLD))
	cost_row.add_child(UIKit.label(Cfg.format_short(float(def["cost"])), 13, Cfg.COL_GOLD, Cfg.font_bold))
	v.add_child(cost_row)

	if _is_locked(id):
		var lock := Control.new()
		lock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var veil := Panel.new()
		veil.add_theme_stylebox_override("panel", UIKit.style(Color(0.03, 0.05, 0.09, 0.72), 15, Color(0, 0, 0, 0), 0, 0, 0))
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.add_child(veil)
		var lv := VBoxContainer.new()
		lv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lv.alignment = BoxContainer.ALIGNMENT_CENTER
		lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lg := Glyph.new("lock", 22.0, Cfg.COL_MUTED)
		lg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lv.add_child(lg)
		var ll := UIKit.label("%d pop" % int(def["unlock"]), 12, Cfg.COL_MUTED, Cfg.font_bold, HORIZONTAL_ALIGNMENT_CENTER)
		lv.add_child(ll)
		lock.add_child(lv)
		b.add_child(lock)

	b.pressed.connect(_on_card.bind(id))
	_style_card(b, id == _active_id, _is_locked(id))
	return b


func refresh(force: bool = false) -> void:
	var ids := BuildingDB.unlocked_ids(GameState.population)
	var h := 0
	for id in ids:
		h += hash(id)
	if not force and h == _unlocked_hash:
		return
	_unlocked_hash = h
	_show_category(_category)


func set_active(id: String, demolish: bool) -> void:
	_active_id = id
	_demolish_active = demolish
	_style_demolish()
	if _cards.has(id):
		_focus_active_card()
	elif demolish:
		for cid in _cards:
			_style_card(_cards[cid], false, _is_locked(String(cid)))


func current_category() -> String:
	return _category


func _cat_icon(cat: String) -> String:
	for c in Cfg.CATEGORIES:
		if String(c["id"]) == cat:
			return String(c["icon"])
	return "civic"