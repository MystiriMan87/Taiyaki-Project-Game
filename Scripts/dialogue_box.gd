class_name DialogueBox
extends CanvasLayer

signal finished

var panel: PanelContainer
var name_label: Label
var text_label: Label
var icon: TextureRect
var arrow: Label
var lines: Array[String] = []
var index := 0
var typing := false
var active := false
var opened_msec := 0
var last_closed_msec := -1000
var tween: Tween

func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the map is paused
	visible = false

	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.2, 0.96)
	style.border_color = Color(0.85, 0.7, 0.35)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(900, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 30)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	col.add_child(name_label)

	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(740, 70)
	text_label.add_theme_font_size_override("font_size", 22)
	col.add_child(text_label)

	arrow = Label.new()
	arrow.text = "▼"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arrow.modulate = Color(1, 0.9, 0.5)
	col.add_child(arrow)

func start(speaker: String, portrait: Texture2D, new_lines: Array[String]) -> void:
	if active or new_lines.is_empty():
		return
	lines = new_lines
	index = 0
	name_label.text = speaker
	icon.texture = portrait
	icon.visible = portrait != null
	active = true
	opened_msec = Time.get_ticks_msec()
	visible = true
	get_tree().paused = true
	_show_line()

func _show_line() -> void:
	text_label.text = lines[index]
	text_label.visible_ratio = 0.0
	arrow.hide()
	typing = true
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(text_label, "visible_ratio", 1.0, maxf(lines[index].length() * 0.025, 0.2))
	tween.finished.connect(_on_typed)

func _on_typed() -> void:
	typing = false
	arrow.show()

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		# ignore the same key press that opened the box
		if Time.get_ticks_msec() - opened_msec < 150:
			return
		_advance()

func _advance() -> void:
	if typing:
		if tween:
			tween.kill()
		text_label.visible_ratio = 1.0
		_on_typed()
		return
	index += 1
	if index >= lines.size():
		_close()
	else:
		_show_line()

func _close() -> void:
	active = false
	visible = false
	last_closed_msec = Time.get_ticks_msec()
	get_tree().paused = false
	finished.emit()
