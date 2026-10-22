class_name RosterMenu
extends CanvasLayer

var slot_box: VBoxContainer
var grid: GridContainer
var detail: Label
var hint: Label
var picking_for: CharacterStats = null
var dirty := false

func _init() -> void:
	layer = 51
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.1, 0.13, 0.2, 0.97), Color(0.85, 0.7, 0.35), 3, 20))
	center.add_child(panel)
	
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)
	root.add_child(_label("Roster", 32, true))
	
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	root.add_child(body)
	
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	body.add_child(left)
	left.add_child(_label("Active party", 20))
	slot_box = VBoxContainer.new()
	left.add_child(slot_box)
	
	var right := VBoxContainer.new()
	body.add_child(right)
	right.add_child(_label("Reserve & monsters", 20))
	grid = GridContainer.new()
	grid.columns = 3
	right.add_child(grid)
	
	detail = _label("", 18)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(760, 110)
	root.add_child(detail)
	
	hint = _label("", 16)
	hint.modulate = Color(1, 1, 1, 0.65)
	root.add_child(hint)
	
func open() -> void:
	picking_for = null
	_refresh()
	visible = true
	get_tree().paused = true
	
func close() -> void:
	picking_for = null
	visible = false
	get_tree().paused = false
	if dirty:
		dirty = false
		if Game.overworld and Game.overworld.has_method("refresh_followers"):
			Game.overworld.refresh_followers()
			
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var is_r: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R
	if event.is_action_pressed("ui_cancel") or is_r:
		if picking_for != null:
			picking_for = null
			_refresh()
		else:
			close()
		get_viewport().set_input_as_handled()
		
func _refresh() -> void:
	_clear(slot_box)
	_clear(grid)
	for i in Game.MAX_PARTY:
		if i < Game.party.size():
			slot_box.add_child(_slot_button(i, Game.party[i]))
		else:
			var e := Button.new()
			e.text = "- empty -"
			e.disabled = true
			slot_box.add_child(e)
	for r in Game.reserve:
		grid.add_child(_member_button(r))
	for sp in Game.get_recruitable_species():
		if not Game.has_member(sp.display_name):
			grid.add_child(_species_button(sp))
	if picking_for != null:
		hint.text = "hint go brrrrr for now %s   (Esc: cancel)" % picking_for.display_name
	else:
		hint.text = "Enter on a party slot: send to reserve   |   Enter on a reserve monster: bring into the party   |   Esc / R: close"
	call_deferred("_focus_first")
	
func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
		
func _focus_first() -> void:
	var order: Array = [slot_box, grid] if picking_for != null else [grid, slot_box]
	for group in order:
		for c in group.get_children():
			var b := c as Button
			if b and not b.disabled:
				b.grab_focus()
				return
				
func _base_button(s: CharacterStats, detail_text: String) -> Button:
	var b := Button.new()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 52)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 40)
	b.icon = _icon(s)
	b.focus_entered.connect(func(): detail.text = detail_text)
	return b
	
func _slot_button(i: int, s: CharacterStats) -> Button:
	var lvl: int = Game.get_level(s)
	var b := _base_button(s, _member_detail(s))
	b.text = "%s  Lv %d%s" % [s.display_name, lvl, "  (Leader)" if i == 0 else ""]
	b.disabled = (i == 0 and picking_for != null)
	b.pressed.connect(_on_slot_pressed.bind(i))
	return b
	
func _member_button(s: CharacterStats) -> Button:
	var b := _base_button(s, _member_detail(s))
	b.text = "%s  Lv %d" % [s.display_name, Game.get_level(s)]
	b.pressed.connect(_on_reserve_pressed.bind(s))
	return b
	
func _species_button(sp: CharacterStats) -> Button:
	var known: bool = Game.seen.has(sp.display_name)
	var text: String = "Not recruited yet.\n%s\nRecruit chance: %d%%" % [sp.recruit_line, int(sp.recruit_chance * 100.0)] if known \
		else "Unknown monster. Find and defeat one to learn about it."
	var b := _base_button(sp, text)
	b.text = sp.display_name if known else "???"
	if not known:
		b.icon = null
	b.modulate = Color(1, 1, 1, 0.6)
	return b
	
func _on_slot_pressed(i: int) -> void:
	if i == 0:
		return
	if picking_for != null:
		Game.swap_member(i, picking_for)
		picking_for = null
	else:
		Game.move_to_reserve(i)
	dirty = true
	_refresh()
	
func _on_reserve_pressed(m: CharacterStats) -> void:
	if Game.party.size() < Game.MAX_PARTY:
		Game.add_from_reserve(m)
		dirty = true
		_refresh()
	else:
		picking_for = m
		_refresh()
		
func _member_detail(s: CharacterStats) -> String:
	var lvl: int = Game.get_level(s)
	var hp: int = Game.party_hp.get(s, s.max_hp)
	var mp: int = Game.party_mp.get(s, s.max_mp)
	return "%s   Lv %d   XP %d / %d\nHP %d/%d    MP %d/%d\nATK %d   DEF %d   MAG %d   SPD %d" % [
		s.display_name, lvl, Game.party_xp.get(s, 0), Game.xp_to_next(lvl),
		hp, s.max_hp, mp, s.max_mp, s.attack, s.defense, s.magic, s.speed]
		
func _icon(s: CharacterStats) -> Texture2D:
	if s.sprite_frames and s.sprite_frames.has_animation("idle") and s.sprite_frames.get_frame_count("idle") > 0:
		return s.sprite_frames.get_frame_texture("idle", 0)
	return s.texture
	

func _label(text: String, size: int, centered := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
	
func _style(bg: Color, border: Color, width: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(margin)
	return s
		
		
