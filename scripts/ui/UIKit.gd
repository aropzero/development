class_name UIKit
## Shared theme + widget helpers. Everything is generated in code so the UI is
## crisp at any phone resolution.

static var _theme: Theme
static var _grabber: Texture2D


static func theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme


static func style(bg: Color, radius: int = 18, border: Color = Color(0, 0, 0, 0),
		border_w: int = 0, shadow: int = 0, margin: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	if border_w > 0:
		s.border_width_left = border_w
		s.border_width_top = border_w
		s.border_width_right = border_w
		s.border_width_bottom = border_w
		s.border_color = border
	if shadow > 0:
		s.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0.0, 3.0)
	s.content_margin_left = float(margin)
	s.content_margin_right = float(margin)
	s.content_margin_top = float(margin * 0.66)
	s.content_margin_bottom = float(margin * 0.66)
	s.anti_aliasing = true
	return s


static func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Cfg.font_body
	t.default_font_size = 18

	t.set_font("font", "Label", Cfg.font_body)
	t.set_font_size("font_size", "Label", 18)
	t.set_color("font_color", "Label", Cfg.COL_TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.35))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 2)

	var normal := style(Cfg.COL_PANEL_2, 15, Color(1, 1, 1, 0.06), 1, 0, 16)
	var hover := style(Cfg.COL_PANEL_3, 15, Color(1, 1, 1, 0.12), 1, 0, 16)
	var pressed := style(Cfg.COL_ACCENT.darkened(0.45), 15, Cfg.COL_ACCENT, 1, 0, 16)
	var disabled := style(Cfg.COL_PANEL.darkened(0.25), 15, Color(1, 1, 1, 0.03), 1, 0, 16)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", Cfg.font_bold)
	t.set_font_size("font_size", "Button", 17)
	t.set_color("font_color", "Button", Cfg.COL_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Cfg.COL_DIM)

	t.set_stylebox("panel", "PanelContainer", style(Cfg.COL_PANEL, 18, Color(1, 1, 1, 0.05), 1, 0, 16))
	t.set_stylebox("panel", "Panel", style(Cfg.COL_PANEL, 18, Color(1, 1, 1, 0.05), 1, 0, 16))

	t.set_stylebox("scroll", "VScrollBar", style(Color(0, 0, 0, 0), 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", style(Color(1, 1, 1, 0.18), 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", style(Color(1, 1, 1, 0.32), 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("scroll", "HScrollBar", style(Color(0, 0, 0, 0), 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("grabber", "HScrollBar", style(Color(1, 1, 1, 0.18), 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("grabber_highlight", "HScrollBar", style(Color(1, 1, 1, 0.32), 4, Color(0, 0, 0, 0), 0, 0, 0))

	t.set_stylebox("slider", "HSlider", style(Color(1, 1, 1, 0.12), 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("grabber_area", "HSlider", style(Cfg.COL_ACCENT, 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", style(Cfg.COL_ACCENT.lightened(0.15), 4, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_icon("grabber", "HSlider", grabber_texture())
	t.set_icon("grabber_highlight", "HSlider", grabber_texture())
	t.set_icon("grabber_disabled", "HSlider", grabber_texture())
	return t


static func grabber_texture() -> Texture2D:
	if _grabber != null:
		return _grabber
	var size := 26
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - c, float(y) - c).length()
			if d <= 9.0:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			elif d <= 11.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0.35))
	_grabber = ImageTexture.create_from_image(img)
	return _grabber


static func circle_texture(size: int = 64, inner: Color = Color.WHITE, outer: Color = Color(1, 1, 1, 0)) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(inner.r, inner.g, inner.b, inner.a * a))
	return ImageTexture.create_from_image(img)


static func label(text: String, font_size: int = 18, color: Color = Cfg.COL_TEXT,
		font: Font = null, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", font if font != null else Cfg.font_body)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, font_size: int = 24, color: Color = Cfg.COL_TEXT) -> Label:
	return label(text, font_size, color, Cfg.font_display)


static func icon(kind: String, px: float = 24.0, color: Color = Cfg.COL_TEXT) -> Glyph:
	return Glyph.new(kind, px, color)


static func icon_button(kind: String, px: float = 46.0, tint: Color = Cfg.COL_TEXT,
		bg: Color = Color(0.09, 0.14, 0.22, 0.72)) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(px, px)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", style(bg, int(px * 0.32), Color(1, 1, 1, 0.06), 1, 0, 0))
	b.add_theme_stylebox_override("hover", style(bg.lightened(0.10), int(px * 0.32), Color(1, 1, 1, 0.12), 1, 0, 0))
	b.add_theme_stylebox_override("pressed", style(Cfg.COL_ACCENT_DARK, int(px * 0.32), Cfg.COL_ACCENT, 1, 0, 0))
	b.add_theme_stylebox_override("disabled", style(bg.darkened(0.2), int(px * 0.32), Color(0, 0, 0, 0), 0, 0, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var g := Glyph.new(kind, 0.0, tint)
	g.name = "Glyph"
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.offset_left = px * 0.24
	g.offset_top = px * 0.24
	g.offset_right = -px * 0.24
	g.offset_bottom = -px * 0.24
	b.add_child(g)
	return b


static func set_button_icon(b: Button, kind: String, color: Color = Cfg.COL_TEXT) -> void:
	var g := b.get_node_or_null("Glyph")
	if g is Glyph:
		(g as Glyph).kind = kind
		(g as Glyph).tint = color


static func text_button(text: String, primary: bool = false, height: float = 50.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		b.add_theme_stylebox_override("normal", style(Cfg.COL_ACCENT_DARK, 15, Cfg.COL_ACCENT, 1, 0, 22))
		b.add_theme_stylebox_override("hover", style(Cfg.COL_ACCENT_DARK.lightened(0.12), 15, Cfg.COL_ACCENT, 1, 0, 22))
		b.add_theme_stylebox_override("pressed", style(Cfg.COL_ACCENT_DARK.darkened(0.2), 15, Cfg.COL_ACCENT, 1, 0, 22))
		b.add_theme_color_override("font_color", Color.WHITE)
	else:
		b.add_theme_stylebox_override("normal", style(Cfg.COL_PANEL_2, 15, Color(1, 1, 1, 0.07), 1, 0, 22))
		b.add_theme_stylebox_override("hover", style(Cfg.COL_PANEL_3, 15, Color(1, 1, 1, 0.14), 1, 0, 22))
		b.add_theme_stylebox_override("pressed", style(Cfg.COL_PANEL_3.darkened(0.15), 15, Cfg.COL_ACCENT, 1, 0, 22))
	b.add_theme_font_override("font", Cfg.font_bold)
	b.add_theme_font_size_override("font_size", 18)
	return b


static func pill(bg: Color = Color(0.07, 0.11, 0.18, 0.72), radius: int = 22, margin: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, radius, Color(1, 1, 1, 0.06), 1, 0, margin))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func spacer(w: float = 0.0, h: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func divider(height: float = 1.0, color: Color = Color(1, 1, 1, 0.08)) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func set_anchors_full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func make_bar(fill: Color, bg: Color = Color(1, 1, 1, 0.10), height: float = 8.0) -> Dictionary:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, height)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bgp := Panel.new()
	bgp.add_theme_stylebox_override("panel", style(bg, int(maxf(2.0, height * 0.5)), Color(0, 0, 0, 0), 0, 0, 0))
	bgp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bgp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bgp)
	var fillp := Panel.new()
	fillp.add_theme_stylebox_override("panel", style(fill, int(maxf(2.0, height * 0.5)), Color(0, 0, 0, 0), 0, 0, 0))
	fillp.anchor_top = 0.0
	fillp.anchor_bottom = 1.0
	fillp.anchor_left = 0.0
	fillp.anchor_right = 0.0
	fillp.offset_left = 0.0
	fillp.offset_right = 0.0
	fillp.offset_top = 0.0
	fillp.offset_bottom = 0.0
	fillp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fillp)
	return {"root": holder, "fill": fillp}


static func set_bar(bar: Dictionary, ratio: float) -> void:
	var f = bar.get("fill")
	if f is Control:
		(f as Control).anchor_right = clampf(ratio, 0.0, 1.0)
