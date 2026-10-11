extends Node2D

signal finished(won: bool)
#signal turn_order_changed(order: Array)
signal turn_started(battler: Battler)
signal turn_order_changed(order: Array, next_order: Array)


const BATTLER_SCENE := preload("res://Scenes/battler.tscn")
const SPEED_JITTER := 0.35
const GROUND_Y := 400.0   # raise to move everyone down, lower to move up
const MIN_GAP := 10.0   
const SLOT_SPACING := 90.0 #vertical gap
const STAGGER_X := 40.0 # Sideways offset


@onready var menu = $UI/CommandMenu

var party: Array[Battler] = []
var enemies: Array[Battler] = []
var turn_bar: TurnOrderBar
var next_order: Array[Battler] = []


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
	next_order = _roll_order()
	while true:
		var order: Array[Battler] = []
		for b in next_order:
			if b.is_alive():
				order.append(b)
		next_order = _roll_order()
		turn_order_changed.emit(order, next_order)

		for b in order:
			if not b.is_alive():
				print("ORDER SLOT: ", b.stats.display_name, " player=", b.is_player, " alive=", b.is_alive())
				continue
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

func _player_turn(actor: Battler) -> void:
	var living := enemies.filter(func(e): return e.is_alive())
	menu.open(actor, living)
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
	if won:
		for p in party:
			Game.party_hp[p.stats] = maxi(p.hp, 1)
			Game.party_mp[p.stats] = p.mp
			
	var banner := Label.new()
	banner.text = "Victory!" if won else "Defeat.."
	banner.add_theme_font_size_override("font_size", 72)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 12)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.modulate.a = 0.0
	$UI.add_child(banner)
	
	create_tween().tween_property(banner, "modulate:a", 1.0, 0.4)
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
	
func _roll_order() -> Array[Battler]:
	var rolls := {}
	var result: Array[Battler] = []
	for b in party + enemies:
		if b.is_alive():
			rolls[b] = b.stats.speed * randf_range(1.0 - SPEED_JITTER, 1.0 + SPEED_JITTER)
			result.append(b)
	result.sort_custom(func(a, b): return rolls[a] > rolls[b])
	return result
	
func _use_skill(actor: Battler, action: BattleAction, targets: Array, free_cost := false) -> void:
	if not free_cost and not actor.spend_mp(action.mp_cost):
		return
	if not actor.is_player and not free_cost:
		await _callout(actor, action.display_name)
	
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
