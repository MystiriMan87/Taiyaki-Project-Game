class_name PartyMenu
extends CanvasLayer

var panel: PanelContainer
var cards: HBoxContainer

func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the game is paused
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.2, 0.96)
	style.border_color = Color(0.85, 0.7, 0.35)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	panel.add_child(root)

	var title := Label.new()
	title.text = "Party"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)

	cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	root.add_child(cards)

	var hint := Label.new()
	hint.text = "Esc / Tab: close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.6)
	root.add_child(hint)

func open() -> void:
	_refresh()
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var is_tab: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB
	if event.is_action_pressed("ui_cancel") or is_tab:
		close()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	for c in cards.get_children():
		c.queue_free()
	for s in Game.party:
		if s != null:
			cards.add_child(_make_card(s))

func _make_card(s: CharacterStats) -> Control:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.2, 0.3)
	style.border_color = Color(0.4, 0.5, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(230, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var icon := TextureRect.new()
	icon.texture = _get_icon(s)
	icon.custom_minimum_size = Vector2(192, 192)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(icon)

	var level: int = Game.get_level(s)
	var xp: int = Game.party_xp.get(s, 0)
	var hp: int = Game.party_hp.get(s, s.max_hp)
	var mp: int = Game.party_mp.get(s, s.max_mp)

	box.add_child(_label(s.display_name, 26))
	box.add_child(_label("Level %d" % level, 18))
	box.add_child(_label("XP %d / %d" % [xp, Game.xp_to_next(level)], 16))
	box.add_child(HSeparator.new())
	box.add_child(_label("HP   %d / %d" % [hp, s.max_hp], 18))
	box.add_child(_label("MP   %d / %d" % [mp, s.max_mp], 18))
	box.add_child(HSeparator.new())
	box.add_child(_label("Attack    %d" % s.attack, 18))
	box.add_child(_label("Defense  %d" % s.defense, 18))
	box.add_child(_label("Magic     %d" % s.magic, 18))
	box.add_child(_label("Speed     %d" % s.speed, 18))
	return card

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l

func _get_icon(s: CharacterStats) -> Texture2D:
	if s.sprite_frames and s.sprite_frames.has_animation("idle") and s.sprite_frames.get_frame_count("idle") > 0:
		return s.sprite_frames.get_frame_texture("idle", 0)
	return s.texture
