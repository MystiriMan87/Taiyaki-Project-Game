class_name TurnOrderBar
extends HBoxContainer

const SLOT_SIZE := Vector2(56, 56)
const PARTY_COLOR := Color(0.15, 0.25, 0.5, 0.9)
const ENEMY_COLOR := Color(0.5, 0.15, 0.15, 0.9)
const BASE_BORDER := Color(0.1, 0.1, 0.1)
const ACTIVE_BORDER := Color(1.0, 0.85, 0.2)
const GHOST_ALPHA := 0.3

var order: Array = []
var slots: Dictionary = {}
var ghosts: Array = []
var active: Battler = null

func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 10)
	
func show_order(new_order: Array, next_order: Array) -> void:
	for c in get_children():
		c.queue_free()
	slots.clear()
	ghosts.clear()
	active = null
	order = new_order.duplicate()
	
	for b in order:
		var slot := _make_slot(b)
		add_child(slot)
		slots[b] = slot
		
	if not next_order.is_empty():
		add_child(VSeparator.new())
		for b in next_order:
			var ghost := _make_slot(b)
			ghost.modulate = Color(1, 1, 1, GHOST_ALPHA)
			add_child(ghost)
			ghosts.append({"b": b, "slot": ghost})

func refresh(act: Battler = null) -> void:
	if act != null:
		active = act
	var idx := order.find(active)
	for i in order.size():
		var b: Battler = order[i]
		var slot: Control = slots[b]
		var is_active := i == idx
		slot.get_meta("style").border_color = ACTIVE_BORDER if is_active else BASE_BORDER
		slot.get_meta("marker").modulate.a = 1.0 if is_active else 0.0
		var done := i < idx or not b.is_alive()
		slot.modulate = Color(1, 1, 1, 0.4) if done else Color.WHITE
	for g in ghosts:
		g["slot"].visible = g["b"].is_alive()
		
func pulse(b: Battler) -> void:
	await get_tree().process_frame
	var found: Array = []
	if slots.has(b):
		found.append(slots[b])
	for g in ghosts:
		if g["b"] == b:
			found.append(g["slot"])
	for s in found:
		s.pivot_offset = s.size / 2.0
		var tw := create_tween()
		tw.tween_property(s, "scale", Vector2(1.25, 1.25), 0.12)
		tw.tween_property(s, "scale", Vector2.ONE, 0.18)
		
func _make_slot(b: Battler) -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	
	var marker := Label.new()
	marker.text = "▼"
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_color_override("font_color", ACTIVE_BORDER)
	marker.add_theme_font_size_override("font_size", 14)
	marker.modulate.a = 0.0
	root.add_child(marker)
	root.set_meta("marker", marker)
	
	var style := StyleBoxFlat.new()
	style.bg_color = PARTY_COLOR if b.is_player else ENEMY_COLOR
	style.border_color = BASE_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	root.set_meta("style", style)
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = SLOT_SIZE
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	
	var icon := TextureRect.new()
	icon.texture = b.get_icon()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_child(icon)
	
	var name_label := Label.new()
	name_label.text = b.stats.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 4)
	root.add_child(name_label)
	
	
	return root
	
