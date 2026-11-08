class_name Glyph
extends Control
## Crisp, resolution-independent vector icons drawn with the CanvasItem API.

var kind: String = "coin":
	set(value):
		kind = value
		queue_redraw()

var tint: Color = Color.WHITE:
	set(value):
		tint = value
		queue_redraw()

var accent: Color = Color(0, 0, 0, 0):
	set(value):
		accent = value
		queue_redraw()


func _init(icon_kind: String = "coin", px: float = 24.0, color: Color = Color.WHITE) -> void:
	kind = icon_kind
	tint = color
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 1.0:
		return
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5), 0.0, Vector2(s, s))
	var c := tint
	var dark := tint.darkened(0.40)
	var light := tint.lightened(0.35)
	var soft := Color(tint.r, tint.g, tint.b, 0.30)
	match kind:
		"coin":
			draw_circle(Vector2.ZERO, 0.44, dark)
			draw_circle(Vector2.ZERO, 0.37, c)
			draw_arc(Vector2.ZERO, 0.27, 0.0, TAU, 28, dark, 0.05, true)
			draw_line(Vector2(-0.10, -0.17), Vector2(-0.10, 0.17), dark, 0.065, true)
			draw_line(Vector2(0.10, -0.17), Vector2(0.10, 0.17), dark, 0.065, true)
			draw_line(Vector2(-0.10, 0.0), Vector2(0.10, 0.0), dark, 0.055, true)
		"people":
			draw_circle(Vector2(-0.14, 0.26), 0.20, soft)
			draw_circle(Vector2(0.18, 0.29), 0.16, soft)
			draw_circle(Vector2(-0.14, -0.10), 0.12, c)
			draw_circle(Vector2(0.18, -0.05), 0.095, c)
		"heart":
			draw_circle(Vector2(-0.16, -0.09), 0.19, c)
			draw_circle(Vector2(0.16, -0.09), 0.19, c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-0.345, -0.015), Vector2(0.345, -0.015), Vector2(0.0, 0.44)]), c)
			draw_circle(Vector2(-0.20, -0.15), 0.055, light)
		"bolt":
			draw_colored_polygon(PackedVector2Array([
				Vector2(0.07, -0.46), Vector2(-0.28, 0.06), Vector2(-0.02, 0.06),
				Vector2(-0.09, 0.46), Vector2(0.29, -0.11), Vector2(0.03, -0.11)]), c)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var ang := -PI * 0.5 + float(i) * PI / 5.0
				var r := 0.44 if i % 2 == 0 else 0.18
				pts.append(Vector2(cos(ang), sin(ang)) * r)
			draw_colored_polygon(pts, c)
		"house", "home":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-0.46, 0.03), Vector2(0.0, -0.42), Vector2(0.46, 0.03)]), c)
			draw_rect(Rect2(-0.32, 0.02, 0.64, 0.42), c)
			draw_rect(Rect2(-0.09, 0.20, 0.18, 0.24), dark)
			draw_rect(Rect2(0.16, 0.14, 0.10, 0.10), light)
		"shop":
			draw_rect(Rect2(-0.36, 0.02, 0.72, 0.42), c)
			draw_rect(Rect2(-0.42, -0.18, 0.84, 0.16), dark)
			for i in 4:
				draw_circle(Vector2(-0.30 + float(i) * 0.20, 0.0), 0.075, c)
			draw_rect(Rect2(-0.10, 0.18, 0.20, 0.26), dark)
			draw_rect(Rect2(-0.30, 0.08, 0.14, 0.10), light)
			draw_rect(Rect2(0.16, 0.08, 0.14, 0.10), light)
		"factory":
			draw_rect(Rect2(-0.40, 0.06, 0.80, 0.38), c)
			draw_rect(Rect2(-0.32, -0.34, 0.16, 0.42), c)
			draw_rect(Rect2(0.06, -0.24, 0.16, 0.32), c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-0.40, 0.06), Vector2(-0.40, -0.14), Vector2(-0.18, 0.06)]), light)
			draw_rect(Rect2(-0.30, 0.18, 0.13, 0.14), dark)
			draw_rect(Rect2(-0.10, 0.18, 0.13, 0.14), dark)
			draw_rect(Rect2(0.10, 0.18, 0.13, 0.14), dark)
		"civic":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-0.44, -0.16), Vector2(0.0, -0.44), Vector2(0.44, -0.16)]), c)
			draw_rect(Rect2(-0.40, -0.14, 0.80, 0.08), light)
			for i in 4:
				draw_rect(Rect2(-0.32 + float(i) * 0.18, -0.04, 0.09, 0.34), c)
			draw_rect(Rect2(-0.44, 0.34, 0.88, 0.09), c)
		"tree":
			draw_rect(Rect2(-0.055, 0.10, 0.11, 0.32), Color(0.45, 0.31, 0.18))
			draw_circle(Vector2(0.0, -0.12), 0.28, c)
			draw_circle(Vector2(-0.19, 0.04), 0.19, c)
			draw_circle(Vector2(0.19, 0.04), 0.19, c)
			draw_circle(Vector2(-0.06, -0.22), 0.13, light)
		"road":
			draw_rect(Rect2(-0.46, -0.40, 0.92, 0.80), dark)
			draw_rect(Rect2(-0.28, -0.40, 0.56, 0.80), c)
			var y := -0.30
			while y < 0.40:
				draw_rect(Rect2(-0.035, y, 0.07, 0.16), Color(1.0, 0.92, 0.70))
				y += 0.26
		"close":
			draw_line(Vector2(-0.28, -0.28), Vector2(0.28, 0.28), c, 0.11, true)
			draw_line(Vector2(0.28, -0.28), Vector2(-0.28, 0.28), c, 0.11, true)
		"pause":
			draw_rect(Rect2(-0.22, -0.30, 0.15, 0.60), c)
			draw_rect(Rect2(0.07, -0.30, 0.15, 0.60), c)
		"play":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-0.20, -0.32), Vector2(0.32, 0.0), Vector2(-0.20, 0.32)]), c)
		"gear", "settings":
			for i in 8:
				var ang := float(i) * TAU / 8.0
				draw_line(Vector2(cos(ang), sin(ang)) * 0.26,
					Vector2(cos(ang), sin(ang)) * 0.46, c, 0.11, true)
			draw_circle(Vector2.ZERO, 0.29, c)
			draw_circle(Vector2.ZERO, 0.13, dark)
		"check":
			draw_polyline(PackedVector2Array([
				Vector2(-0.32, 0.02), Vector2(-0.08, 0.28), Vector2(0.34, -0.26)]),
				c, 0.11, true)
		"lock":
			draw_circle(Vector2(0.0, -0.14), 0.22, soft)
			draw_arc(Vector2(0.0, -0.10), 0.22, PI, TAU, 18, c, 0.09, true)
			draw_rect(Rect2(-0.30, -0.10, 0.60, 0.46), c)
			draw_circle(Vector2(0.0, 0.10), 0.06, dark)
		"upgrade":
			draw_colored_polygon(PackedVector2Array([
				Vector2(0.0, -0.40), Vector2(0.34, 0.0), Vector2(0.13, 0.0),
				Vector2(0.13, 0.36), Vector2(-0.13, 0.36), Vector2(-0.13, 0.0),
				Vector2(-0.34, 0.0)]), c)
		"trash":
			draw_rect(Rect2(-0.36, -0.34, 0.72, 0.10), c)
			draw_rect(Rect2(-0.12, -0.44, 0.24, 0.10), c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-0.30, -0.20), Vector2(0.30, -0.20), Vector2(0.23, 0.44),
				Vector2(-0.23, 0.44)]), c)
			draw_line(Vector2(-0.11, -0.10), Vector2(-0.08, 0.32), dark, 0.055, true)
			draw_line(Vector2(0.11, -0.10), Vector2(0.08, 0.32), dark, 0.055, true)
		"task":
			draw_rect(Rect2(-0.34, -0.36, 0.68, 0.78), c)
			draw_rect(Rect2(-0.16, -0.44, 0.32, 0.12), dark)
			draw_line(Vector2(-0.22, -0.14), Vector2(0.22, -0.14), dark, 0.05, true)
			draw_line(Vector2(-0.22, 0.02), Vector2(0.22, 0.02), dark, 0.05, true)
			draw_line(Vector2(-0.22, 0.18), Vector2(0.08, 0.18), dark, 0.05, true)
			draw_circle(Vector2(0.18, 0.24), 0.12, Color(0.35, 0.90, 0.55))
		"sun":
			draw_circle(Vector2.ZERO, 0.22, c)
			for i in 8:
				var ang := float(i) * TAU / 8.0
				draw_line(Vector2(cos(ang), sin(ang)) * 0.31,
					Vector2(cos(ang), sin(ang)) * 0.45, c, 0.055, true)
		"moon":
			var pts2 := PackedVector2Array()
			for i in 21:
				var ang := lerpf(-PI * 0.5, PI * 0.5, float(i) / 20.0)
				pts2.append(Vector2(cos(ang), sin(ang)) * 0.42)
			for i in 21:
				var ang2 := lerpf(PI * 0.5, -PI * 0.5, float(i) / 20.0)
				pts2.append(Vector2(-0.16 + cos(ang2) * 0.34, sin(ang2) * 0.34))
			draw_colored_polygon(pts2, c)
		"zoom_in", "zoom_out":
			draw_arc(Vector2(-0.06, -0.06), 0.28, 0.0, TAU, 26, c, 0.08, true)
			draw_line(Vector2(0.15, 0.15), Vector2(0.40, 0.40), c, 0.11, true)
			draw_line(Vector2(-0.20, -0.06), Vector2(0.08, -0.06), c, 0.06, true)
			if kind == "zoom_in":
				draw_line(Vector2(-0.06, -0.20), Vector2(-0.06, 0.08), c, 0.06, true)
		"rotate_left", "rotate_right":
			var start := 0.35 if kind == "rotate_left" else -2.6
			draw_arc(Vector2.ZERO, 0.30, start, start + 3.4, 24, c, 0.09, true)
			var tip := Vector2(cos(start), sin(start)) * 0.30
			var side := Vector2(cos(start + 0.5), sin(start + 0.5)) * 0.30
			var out := Vector2(cos(start - 0.55), sin(start - 0.55)) * 0.18
			draw_colored_polygon(PackedVector2Array([tip, side, out + Vector2(0, 0)]), c)
			draw_circle(Vector2.ZERO, 0.06, soft)
		"camera":
			draw_rect(Rect2(-0.42, -0.24, 0.84, 0.54), c)
			draw_rect(Rect2(-0.16, -0.36, 0.32, 0.12), c)
			draw_circle(Vector2(0.0, 0.03), 0.16, dark)
			draw_circle(Vector2(0.0, 0.03), 0.09, light)
		"speed":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-0.34, -0.30), Vector2(-0.04, 0.0), Vector2(-0.34, 0.30),
				Vector2(-0.16, 0.30), Vector2(0.14, 0.0), Vector2(-0.16, -0.30)]), c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(0.06, -0.30), Vector2(0.36, 0.0), Vector2(0.06, 0.30),
				Vector2(0.24, 0.30), Vector2(0.54, 0.0), Vector2(0.24, -0.30)]), c)
		"info":
			draw_circle(Vector2.ZERO, 0.42, c)
			draw_circle(Vector2(0.0, -0.20), 0.06, dark)
			draw_rect(Rect2(-0.055, -0.04, 0.11, 0.28), dark)
		"center":
			draw_arc(Vector2.ZERO, 0.30, 0.0, TAU, 26, c, 0.055, true)
			draw_line(Vector2(-0.46, 0.0), Vector2(-0.24, 0.0), c, 0.06, true)
			draw_line(Vector2(0.24, 0.0), Vector2(0.46, 0.0), c, 0.06, true)
			draw_line(Vector2(0.0, -0.46), Vector2(0.0, -0.24), c, 0.06, true)
			draw_line(Vector2(0.0, 0.24), Vector2(0.0, 0.46), c, 0.06, true)
			draw_circle(Vector2.ZERO, 0.07, c)
		"music":
			draw_circle(Vector2(-0.20, 0.24), 0.14, c)
			draw_circle(Vector2(0.22, 0.16), 0.14, c)
			draw_rect(Rect2(-0.08, -0.40, 0.06, 0.64), c)
			draw_rect(Rect2(0.34, -0.44, 0.06, 0.60), c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-0.08, -0.40), Vector2(0.40, -0.48), Vector2(0.40, -0.28),
				Vector2(-0.08, -0.20)]), c)
		"speaker":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-0.42, -0.14), Vector2(-0.18, -0.14), Vector2(0.04, -0.38),
				Vector2(0.04, 0.38), Vector2(-0.18, 0.14), Vector2(-0.42, 0.14)]), c)
			draw_arc(Vector2(0.06, 0.0), 0.20, -0.9, 0.9, 16, c, 0.055, true)
			draw_arc(Vector2(0.06, 0.0), 0.34, -0.9, 0.9, 18, c, 0.055, true)
		"save":
			draw_rect(Rect2(-0.38, -0.40, 0.76, 0.80), c)
			draw_rect(Rect2(-0.24, -0.40, 0.48, 0.28), dark)
			draw_rect(Rect2(-0.26, 0.06, 0.52, 0.34), light)
		"arrow_up":
			draw_colored_polygon(PackedVector2Array([
				Vector2(0.0, -0.40), Vector2(0.34, 0.0), Vector2(0.13, 0.0),
				Vector2(0.13, 0.38), Vector2(-0.13, 0.38), Vector2(-0.13, 0.0),
				Vector2(-0.34, 0.0)]), c)
		"arrow_down":
			draw_colored_polygon(PackedVector2Array([
				Vector2(0.0, 0.40), Vector2(0.34, 0.0), Vector2(0.13, 0.0),
				Vector2(0.13, -0.38), Vector2(-0.13, -0.38), Vector2(-0.13, 0.0),
				Vector2(-0.34, 0.0)]), c)
		"plus":
			draw_line(Vector2(-0.34, 0.0), Vector2(0.34, 0.0), c, 0.12, true)
			draw_line(Vector2(0.0, -0.34), Vector2(0.0, 0.34), c, 0.12, true)
		"minus":
			draw_line(Vector2(-0.34, 0.0), Vector2(0.34, 0.0), c, 0.12, true)
		"leaf":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-0.36, 0.34), Vector2(-0.18, -0.10), Vector2(0.06, -0.34),
				Vector2(0.36, -0.30), Vector2(0.18, 0.06), Vector2(-0.04, 0.30)]), c)
			draw_line(Vector2(-0.32, 0.30), Vector2(0.22, -0.22), light, 0.05, true)
		_:
			draw_circle(Vector2.ZERO, 0.36, soft)
			draw_circle(Vector2.ZERO, 0.10, c)