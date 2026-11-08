extends Node
## Fade transitions between screens and a small loading veil.

var _layer: CanvasLayer
var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 98
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.035, 0.055, 0.09, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)


func fade_out(duration: float = 0.35) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duration)
	await tw.finished


func fade_in(duration: float = 0.45) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, duration)
	await tw.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func change_scene(path: String, duration: float = 0.35) -> void:
	if _busy:
		return
	_busy = true
	await fade_out(duration)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await fade_in(0.5)
	_busy = false