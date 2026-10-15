extends Node2D

signal finished(won: bool)
#signal turn_order_changed(order: Array)
signal turn_started(battler: Battler)
signal turn_order_changed(order: Array, next_order: Array)
signal _recruit_decided(accepted: bool)
signal _confirm_pressed



const BATTLER_SCENE := preload("res://Scenes/battler.tscn")
const SPEED_JITTER := 0.35
const GROUND_Y := 400.0   # raise to move everyone down, lower to move up
const MIN_GAP := 10.0   
const SLOT_SPACING := 130.0 #vertical gap
const STAGGER_X := 40.0 # Sideways offset
const DEPTH_SCALE := 0.0012 # extra scale per pixel of y below GROUND_Y


@onready var menu = $UI/CommandMenu

var party: Array[Battler] = []
var enemies: Array[Battler] = []
var turn_bar: TurnOrderBar
var next_order: Array[Battler] = []
var order: Array[Battler] = []
var turn_index := 0


func _ready() -> void:
	turn_bar = TurnOrderBar.new()
	$UI.add_child(turn_bar)
	turn_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	turn_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	turn_order_changed.connect(turn_bar.show_order)
	turn_started.connect(turn_bar.refresh)
	
func setup(party_stats: Array[CharacterStats], enemy_stats: Array[CharacterStats]) -> void:
	$Camera2D.make_current()
	for i in party_stats.size():
		var b := _spawn(party_stats[i], true, Vector2(900, GROUND_Y + i * 90))
		party.append(b)
	for i in enemy_stats.size():
		var b := _spawn(enemy_stats[i], false, Vector2(350, GROUND_Y + i * 90))
		enemies.append(b)
	_run_battle()
	_place_group(party, 900, true)
	_place_group(enemies, 350)
	
func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	$Camera2D.position = Vector2(640 + sin(t * 0.4) * 12.0, 360 + cos(t * 0.3) * 4.0)
	#$Background.scale *= 1.06
	for b in party + enemies:
		b.position.x += sin(t * 0.4) * 0.04
	
func _punch_camera(amount := 1.06, time := 0.18) -> void:
	var cam: Camera2D = $Camera2D
	var tw := create_tween()
	tw.tween_property(cam, "zoom", Vector2(amount, amount), time * 0.5)
	tw.tween_property(cam, "zoom", Vector2.ONE, time)
	
	
func _spawn(s: CharacterStats, player: bool, pos: Vector2) -> Battler:
	var b: Battler = BATTLER_SCENE.instantiate()
	add_child(b)
	b.init(s, player)
	b.position = pos
	return b
	
func _apply_depth(b: Battler) -> void:
	var s := 1.0 + (b.position.y - GROUND_Y) * DEPTH_SCALE
	b.sprite.scale = Vector2.ONE * b.stats.battle_scale * s


func _place_group(group: Array[Battler], x: float, toward_left := false) -> void:
	var top := GROUND_Y - (group.size() - 1) * SLOT_SPACING / 2.0
	for i in group.size():
		var sx := STAGGER_X * i * (-1.0 if toward_left else 1.0)
		group[i].position = Vector2(x + sx, top + i * SLOT_SPACING)
	
	for b in group:
		_apply_depth(b)
	
func _run_battle() -> void:
	await get_tree().create_timer(0.6).timeout
	next_order = _roll_order()
	while true:
		_tick_statuses()
		order = []
		for b in next_order:
			if b.is_alive():
				order.append(b)
		next_order = _roll_order()
		turn_order_changed.emit(order, next_order)
		
		turn_index = 0
		while turn_index < order.size():
			var b: Battler = order[turn_index]
			if b.is_alive():
				turn_started.emit(b)
				b.set_defending(false)
				if b.is_player:
					await _player_turn(b)
				else:
					await _enemy_turn(b)
				turn_bar.refresh()
				if _enemies_dead():
					await _end_battle(true)
					return
				if _party_dead():
					await _end_battle(false)
					return
			turn_index += 1
			
func _tick_statuses() -> void:
	for b in party + enemies:
		if b.speed_turns > 0:
			b.speed_turns -= 1
			if b.speed_turns == 0:
				b.speed_mod = 1.0
				
# slots > 0 = later, slots < 0 = earlier
func _shift_turn(target: Battler, slots: int) -> void:
	var i := order.find(target)
	if i > turn_index:
		var j := clampi(i + slots, turn_index + 1, order.size() - 1)
		order.remove_at(i)
		order.insert(j, target)
	else:
		var k := next_order.find(target)
		if k == -1:
			return
		var j2 := clampi(k + slots, 0, next_order.size() - 1)
		next_order.remove_at(k)
		next_order.insert(j2, target)
	_announce_order(target)
	

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_confirm_pressed.emit()
	
func _announce_order(moved: Battler = null) -> void:
	turn_order_changed.emit(order, next_order)
	if turn_index < order.size():
		turn_bar.refresh(order[turn_index])
	if moved:
		turn_bar.pulse(moved)
		
func _apply_turn_effect(action: BattleAction, t: Battler) -> void:
	match action.turn_effect:
		BattleAction.TurnEffect.DELAY:
			_callout(t, "Delayed!")
			_shift_turn(t, action.turn_shift)
		BattleAction.TurnEffect.RUSH:
			_callout(t, "Quickened!")
			_shift_turn(t, -99)
		BattleAction.TurnEffect.SPEED:
			t.speed_mod = action.speed_factor
			t.speed_turns = action.status_turns
			next_order = _roll_order(false)
			_callout(t, "Haste!" if action.speed_factor > 1.0 else "Slow...")
			_announce_order(t)

func _player_turn(actor: Battler) -> void:
	var living := enemies.filter(func(e): return e.is_alive())
	var living_allies := party.filter(func(p): return p.is_alive())
	menu.open(actor, living, living_allies)
	var choice = await menu.chosen
	match choice[0]:
		"attack": await _attack(actor, choice[1])
		"defend":
			actor.set_defending(true)
			await get_tree().create_timer(0.5).timeout
		"skill": await _use_skill(actor, choice[1], choice[2])
		
func _enemy_turn(actor: Battler) -> void:
	var targets := party.filter(func(p): return p.is_alive())
	var usable := actor.stats.actions.filter(func(a): return a != null and actor.mp >= a.mp_cost)
	if not usable.is_empty() and randf() < 0.4:
		var action: BattleAction = usable.pick_random()
		var picked: Array = targets if action.target_type == BattleAction.TargetType.ALL_ENEMIES else [targets.pick_random()]
		await _use_skill(actor, action, picked)
	else:
		await _attack(actor, targets.pick_random())
	
func _attack(attacker: Battler, target: Battler) -> void:
	if attacker.stats.basic_attack != null:
		await _use_skill(attacker, attacker.stats.basic_attack, [target], true)
		return
		
	var dmg := maxi(attacker.stats.attack - target.stats.defense / 2, 1)
	dmg = int(dmg * randf_range(0.9, 1.1))
	var dir := -1 if attacker.is_player else 1   # party steps left, enemies step right
	attacker.position.x += 30 * dir
	await attacker.play_anim("attack", true)
	await target.take_damage(dmg)
	attacker.play_anim("idle")
	attacker.position.x -= 30 * dir
	await get_tree().create_timer(0.3).timeout
	
func _enemies_dead() -> bool:
	return enemies.all(func(e): return not e.is_alive())
	
func _party_dead() -> bool:
	return party.all(func(p): return not p.is_alive())
	
func _end_battle(won: bool) -> void:
	var details: Array[String] = []
	if won:
		var total_xp := 0
		for e in enemies:
			total_xp += e.stats.xp_reward
		# save HP/MP first (level-ups add to the saved values)
		for p in party:
			Game.party_hp[p.stats] = maxi(p.hp, 1)
			Game.party_mp[p.stats] = p.mp
		details.append("+%d XP" % total_xp)
		for p in party:
			if not p.is_alive():
				continue          # knocked-out members earn no XP
			var g: Dictionary = Game.award_xp(p.stats, total_xp)
			var lvl: int = Game.get_level(p.stats)
			details.append("%s  Lv %d   (%d / %d XP)" % [
				p.stats.display_name, lvl,
				Game.party_xp.get(p.stats, 0), Game.xp_to_next(lvl)])
			if g["levels"] > 0:
				details.append("%s reached Lv %d!   HP +%d  MP +%d  ATK +%d  DEF +%d  MAG +%d" % [
					p.stats.display_name, Game.get_level(p.stats),
					g["hp"], g["mp"], g["attack"], g["defense"], g["magic"]])

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.modulate.a = 0.0
	box.add_child(_result_label("Victory!" if won else "Defeat...", 72))
	for line in details:
		box.add_child(_result_label(line, 28))
	if won:
		box.add_child(_result_label("Press Enter", 20))
	$UI.add_child(box)

	create_tween().tween_property(box, "modulate:a", 1.0, 0.4)

	if won:
		await get_tree().create_timer(0.8).timeout
		await _confirm_pressed
		box.hide()
		await get_tree().create_timer(0.25).timeout
		await _try_recruit()
	else:
		await get_tree().create_timer(1.8).timeout

	finished.emit(won)

	create_tween().tween_property(box, "modulate:a", 1.0, 0.4)
	if won:
		await get_tree().create_timer(0.8).timeout
		while not Input.is_action_just_pressed("ui_accepted"):
			await get_tree().process_frame
		box.hide()
		await get_tree().create_timer(0.25).timeout # so it doesnt gain sentience
		await _try_recruit()
	else:
		await get_tree().create_timer(1.8).timeout
	finished.emit(won)

	
func _callout(actor: Battler, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = 100
	label.modulate.a = 0.0
	add_child(label) # child of the battle, so the enemy's red flash can't tint it
	
	label.reset_size()
	var start := actor.global_position + Vector2(-label.size.x / 2.0, actor.stats.callout_offset)
	label.global_position = start
	
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(label, "global_position:y", start.y - 12, 0.15)
	tw.tween_interval(0.7)
	tw.tween_property(label, "modulate:a", 0.0, 0.2)
	await tw.finished
	label.queue_free()
	
func _roll_order(reroll := true) -> Array[Battler]:
	var result: Array[Battler] = []
	for b in party + enemies:
		if b.is_alive():
			if reroll:
				b.jitter = randf_range(1.0 - SPEED_JITTER, 1.0 + SPEED_JITTER)
			result.append(b)
	result.sort_custom(func(x, y): return x.stats.speed * x.speed_mod * x.jitter > y.stats.speed * y.speed_mod * y.jitter)
	return result
	
	
func _use_skill(actor: Battler, action: BattleAction, targets: Array, free_cost := false) -> void:
	if not free_cost and not actor.spend_mp(action.mp_cost):
		return
	if not actor.is_player and not free_cost:
		await _callout(actor, action.display_name)
		
	if action.effect_type == BattleAction.EffectType.HEAL:
		actor.play_anim(action.animation)
		await get_tree().create_timer(action.release_delay).timeout
		for t in targets: 
			if t.is_alive():
				t.heal(action.calc_heal(actor.stats))
		await get_tree().create_timer(0.8).timeout
		actor.play_anim("defend" if actor.defending else "idle")
		return
	if action.effect_type == BattleAction.EffectType.TURN_ONLY:
		actor.play_anim(action.animation)
		await get_tree().create_timer(action.release_delay).timeout
		for t in targets:
			if t.is_alive():
				_apply_turn_effect(action, t)
		await get_tree().create_timer(0.9).timeout
		actor.play_anim("defend" if actor.defending else "idle")
		return
			
	var ranged := action.projectile_frames != null or action.projectile_texture != null
	var dir := -1 if actor.is_player else 1
	
	if ranged:
		actor.play_anim(action.animation)
		await get_tree().create_timer(action.release_delay).timeout
		for t in targets:
			if t.is_alive():
				_fly_and_hit(actor, action, t)
		await get_tree().create_timer(action.projectile_time + 0.35).timeout
	else:
		actor.position.x += 30 * dir
		await actor.play_anim(action.animation, true)
		for t in targets:
			if t.is_alive():
				t.take_damage(action.calc_damage(actor.stats, t.stats))
		actor.position.x -= 30 * dir 
		await get_tree().create_timer(0.6).timeout
	
	for t in targets:
		if t.is_alive():
			_apply_turn_effect(action, t)
	
	actor.play_anim("defend" if actor.defending else "idle")
	
	
func _fly_and_hit(actor: Battler, action: BattleAction, target: Battler) -> void:
	var p := _make_projectile(action)
	add_child(p)
	var facing := -1.0 if actor.is_player else 1.0
	var start := actor.global_position + Vector2(actor.stats.muzzle_offset.x * facing, actor.stats.muzzle_offset.y)
	var end := target.global_position + Vector2(0, -20)
	p.global_position = start
	p.rotation = (end - start).angle()
	var tw := create_tween()
	tw.tween_property(p, "global_position", end, action.projectile_time)
	await tw.finished
	p.queue_free()
	if target.is_alive():
		target.take_damage(action.calc_damage(actor.stats, target.stats))
		
func _make_projectile(action: BattleAction) -> Node2D:
	var p: Node2D
	if action.projectile_frames:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = action.projectile_frames
		var names := anim.sprite_frames.get_animation_names()
		anim.play("fly" if anim.sprite_frames.has_animation("fly") else names[0])
		p = anim
	else:
		var s := Sprite2D.new()
		s.texture = action.projectile_texture
		p = s
	p.scale = Vector2.ONE * action.projectile_scale
	p.z_index = 50
	return p
	
func set_background(tex: Texture2D) -> void:
	var bg := get_node_or_null("Background")
	if bg == null or tex == null:
		return
	bg.texture = tex
	bg.position = Vector2(640, 360)
	bg.z_index = -10
	var size := tex.get_size()
	var s := maxf(1280.0 / size.x, 720.0 / size.y) * 1.06   # cover the screen plus a 6% margin for the drift
	bg.scale = Vector2(s, s)
		
func _result_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	return l
	
func _try_recruit() -> void:
	if Game.party.size() >= Game.MAX_PARTY:
		return
	var candidates: Array[Battler] = []
	for e in enemies:
		var s: CharacterStats = e.stats
		if s.recruitable and not Game.has_member(s.display_name) and randf() < s.recruit_chance:
			candidates.append(e)
	if candidates.is_empty():
		return
	var chosen: Battler = candidates.pick_random()
	var accepted: bool = await _recruit_dialog(chosen.stats, chosen.get_icon())
	if accepted:
		Game.recruit(chosen.stats)
		var msg := _result_label("%s joined the party!" % chosen.stats.display_name, 40)
		msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		$UI.add_child(msg)
		await get_tree().create_timer(1.6).timeout
		msg.queue_free()
		
func _recruit_dialog(s: CharacterStats, icon_tex: Texture2D) -> bool:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.2, 0.96)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(680, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	
	var icon := TextureRect.new()
	icon.texture = icon_tex
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(icon)
	
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	
	var name_label := Label.new()
	name_label.text = s.display_name
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	col.add_child(name_label)
	
	var line := Label.new()
	line.text = s.recruit_line
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(480, 0)
	line.add_theme_font_size_override("font_size", 20)
	line.visible_ratio = 0.0
	col.add_child(line)
	
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.modulate.a = 0.0
	col.add_child(buttons)
	var yes := Button.new()
	yes.text = "Welcome aboard"
	yes.pressed.connect(func(): _recruit_decided.emit(true))
	buttons.add_child(yes)
	var no := Button.new()
	no.text = "Not now"
	no.pressed.connect(func(): _recruit_decided.emit(false))
	buttons.add_child(no)
	
	$UI.add_child(panel)
	
	#typewriter effect slaps
	var tw := create_tween()
	tw.tween_property(line, "visible_ratio", 1.0, maxf(s.recruit_line.length() * 0.03, 0.3))
	await tw.finished
	buttons.modulate.a = 1.0
	yes.grab_focus()
	
	var accepted: bool = await _recruit_decided
	panel.queue_free()
	return accepted 
	
	
	
