extends Node2D

signal finished(won: bool)
#signal turn_order_changed(order: Array)
signal turn_started(battler: Battler)
signal turn_order_changed(order: Array, next_order: Array)


const BATTLER_SCENE := preload("res://Scenes/battler.tscn")
const SPEED_JITTER := 0.35
const GROUND_Y := 400.0   # raise to move everyone down, lower to move up
const MIN_GAP := 10.0   
const SLOT_SPACING := 130.0 #vertical gap
const STAGGER_X := 40.0 # Sideways offset


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
	
	
func _spawn(s: CharacterStats, player: bool, pos: Vector2) -> Battler:
	var b: Battler = BATTLER_SCENE.instantiate()
	add_child(b)
	b.init(s, player)
	b.position = pos
	return b
	
func _place_group(group: Array[Battler], x: float, toward_left := false) -> void:
	var top := GROUND_Y - (group.size() - 1) * SLOT_SPACING / 2.0
	for i in group.size():
		var sx := STAGGER_X * i * (-1.0 if toward_left else 1.0)
		group[i].position = Vector2(x + sx, top + i * SLOT_SPACING)
	
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
		while not Input.is_action_just_pressed("ui_accept"):
			await get_tree().process_frame
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
	if tex:
		$Background.texture = tex
		
func _result_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 10)
	return l
