class_name TaskPanel
extends PanelContainer
## Right-hand panel listing the active city goals.

signal collapse_toggled(collapsed: bool)

var _body: VBoxContainer
var _rows: VBoxContainer
var _progress_refs: Dictionary = {}
var _count: Label
var _collapse_btn: Button
var collapsed: bool = false


func setup() -> void:
	name = "TaskPanel"
	add_theme_stylebox_override("panel",
		UIKit.style(Color(0.055, 0.086, 0.14, 0.90), 18, Color(1, 1, 1, 0.06), 1, 6, 12))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	column.add_child(header)
	header.add_child(Glyph.new("task", 22.0, Cfg.COL_ACCENT))
	header.add_child(UIKit.title("City Goals", 19, Cfg.COL_TEXT))
	header.add_child(UIKit.spacer(0, 0))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	_count = UIKit.label("0 done", 13, Cfg.COL_MUTED, Cfg.font_bold)
	header.add_child(_count)
	_collapse_btn = UIKit.icon_button("arrow_up", 34, Cfg.COL_MUTED, Color(1, 1, 1, 0.05))
	_collapse_btn.pressed.connect(_toggle)
	header.add_child(_collapse_btn)

	column.add_child(UIKit.divider())

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	column.add_child(_body)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	_body.add_child(_rows)


func _toggle() -> void:
	collapsed = not collapsed
	_body.visible = not collapsed
	UIKit.set_button_icon(_collapse_btn, "arrow_down" if collapsed else "arrow_up", Cfg.COL_MUTED)
	collapse_toggled.emit(collapsed)
	AudioMgr.ui_switch()


func refresh() -> void:
	_progress_refs.clear()
	for child in _rows.get_children():
		child.queue_free()
	_count.text = "%d done" % GameState.tasks_completed
	if QuestManager.active.is_empty():
		var empty := UIKit.label("All goals complete — enjoy the view!", 14, Cfg.COL_MUTED)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rows.add_child(empty)
		return
	for task in QuestManager.active:
		_rows.add_child(_make_row(task))


func _make_row(task: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		UIKit.style(Color(1, 1, 1, 0.05), 13, Color(1, 1, 1, 0.05), 1, 0, 10))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	top.add_child(Glyph.new(String(task.get("icon", "star")), 18.0, Cfg.COL_ACCENT))
	var title := UIKit.label(String(task.get("title", "Goal")), 15, Cfg.COL_TEXT, Cfg.font_bold)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	top.add_child(title)
	top.add_child(Glyph.new("coin", 15.0, Cfg.COL_GOLD))
	top.add_child(UIKit.label(Cfg.format_short(float(task.get("reward", 0))), 14, Cfg.COL_GOLD, Cfg.font_bold))

	var desc := UIKit.label(String(task.get("desc", "")), 13, Cfg.COL_MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc)

	var prog := HBoxContainer.new()
	prog.add_theme_constant_override("separation", 8)
	col.add_child(prog)
	var bar := UIKit.make_bar(Cfg.COL_ACCENT, Color(1, 1, 1, 0.10), 8.0)
	UIKit.set_bar(bar, QuestManager.progress_ratio(task))
	var bar_root: Control = bar["root"]
	bar_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog.add_child(bar_root)
	var prog_label := UIKit.label(QuestManager.progress_text(task), 12, Cfg.COL_TEXT, Cfg.font_bold)
	prog.add_child(prog_label)
	_progress_refs[int(task.get("uid", 0))] = {"bar": bar, "label": prog_label}
	return panel


## Cheap in-place refresh used while the player is building, so the goal bars
## move smoothly without rebuilding the whole panel every frame.
func update_progress() -> void:
	for task in QuestManager.active:
		var refs = _progress_refs.get(int(task.get("uid", 0)))
		if refs == null:
			continue
		UIKit.set_bar(refs["bar"], QuestManager.progress_ratio(task))
		var lbl: Label = refs["label"]
		if is_instance_valid(lbl):
			lbl.text = QuestManager.progress_text(task)