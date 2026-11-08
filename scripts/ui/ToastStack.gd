class_name ToastStack
extends VBoxContainer
## Floating notifications at the top of the screen.

const MAX_TOASTS := 3


func setup() -> void:
	name = "ToastStack"
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push(text: String, icon: String = "info", tone: String = "info") -> void:
	while get_child_count() >= MAX_TOASTS:
		var first := get_child(0)
		first.queue_free()
		remove_child(first)
	var accent := _tone_color(tone)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		UIKit.style(Color(0.06, 0.09, 0.15, 0.94), 14, accent, 1, 5, 10))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate = Color(1, 1, 1, 0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	row.add_child(Glyph.new(icon, 20.0, accent))
	var label := UIKit.label(text, 15, Cfg.COL_TEXT, Cfg.font_bold)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(220, 0)
	row.add_child(label)
	add_child(panel)

	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.22)
	tw.tween_interval(3.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.45)
	tw.tween_callback(panel.queue_free)


func _tone_color(tone: String) -> Color:
	match tone:
		"good":
			return Cfg.COL_GREEN
		"bad":
			return Cfg.COL_CORAL
		"level":
			return Cfg.COL_GOLD
		"unlock":
			return Cfg.COL_ACCENT
		"money":
			return Cfg.COL_GOLD
	return Cfg.COL_BLUE