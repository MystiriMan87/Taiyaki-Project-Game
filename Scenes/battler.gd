class_name Battler
extends Node2D

var stats: CharacterStats
var hp: int
var mp: int
var is_player := true
var defending := false

var hp_bar: StatBar
#var hp_fill: StyleBoxFlat
var _bar_tween: Tween

const BAR_SCALE := 2.0
const BAR_WIDTH := 89.0


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func init(s: CharacterStats, player: bool) -> void:
	stats = s
	is_player = player
	if player:
		hp = Game.party_hp.get(s, s.max_hp)
		mp = Game.party_mp.get(s, s.max_mp)
	else:
		hp = s.max_hp
		mp = s.max_mp
	_setup_sprite()
	_build_hp_bar()

func is_alive() -> bool:
	return hp > 0
	
func spend_mp(amount: int) -> bool:
	if mp < amount:
		return false
	mp -= amount
	return true

# --- Sprite / animation -------------------------------------------------

func _setup_sprite() -> void:
	if stats.sprite_frames:
		sprite.sprite_frames = stats.sprite_frames
	else:
		# no animations yet: wrap the single texture in a one-frame "idle"
		var frames := SpriteFrames.new()
		frames.rename_animation("default", "idle")
		if stats.texture:
			frames.add_frame("idle", stats.texture)
		sprite.sprite_frames = frames
	sprite.scale = Vector2.ONE * stats.battle_scale
	sprite.flip_h = (stats.drawn_facing_right == is_player)
	play_anim("idle")

func play_anim(anim: String, wait := false) -> void:
	if not sprite.sprite_frames.has_animation(anim):
		return
	sprite.play(anim)
	if wait:
		await sprite.animation_finished

func get_icon() -> Texture2D:
	if stats.texture:
		return stats.texture
	if sprite.sprite_frames.has_animation("idle") and sprite.sprite_frames.get_frame_count("idle") > 0:
		return sprite.sprite_frames.get_frame_texture("idle", 0)
	return null
	

func get_sprite_height() -> float:
	var frames := sprite.sprite_frames
	if frames and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		var tex := frames.get_frame_texture("idle", 0)
		if tex:
			return tex.get_height() * absf(sprite.scale.y)
	return 64.0
	
func set_defending(value: bool) -> void:
	defending = value
	if value:
		play_anim("defend")
	else:
		play_anim("idle")
		
func get_footprint_height() -> float:
	if stats.footprint_height > 0.0:
		return stats.footprint_height
	var frames := sprite.sprite_frames
	if frames and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		var tex := frames.get_frame_texture("idle", 0)
		if tex:
			return tex.get_height() * absf(sprite.scale.y)
	return 64.0

# --- Damage -------------------------------------------------------------

func take_damage(amount: int) -> void:
	if defending:
		amount = ceili(amount / 2.0)
	hp = maxi(hp - amount, 0)
	_show_damage_number(amount)
	_update_hp_bar()
	if is_alive():
		modulate = Color(1, 0.4, 0.4)
		play_anim("hurt")
		await get_tree().create_timer(0.3).timeout
		modulate = Color.WHITE
		play_anim("defend" if defending else "idle")
	else:
		hp_bar.hide()
		if sprite.sprite_frames.has_animation("dead"):
			await play_anim("dead", true)
		if not is_player:
			var tw := create_tween()
			tw.tween_property(self, "modulate:a", 0.0, 0.6)

# --- Health bar ---------------------------------------------------------

func _build_hp_bar() -> void:
	hp_bar = StatBar.new()
	hp_bar.setup(stats.max_hp, hp)
	hp_bar.scale = Vector2(BAR_SCALE, BAR_SCALE)
	hp_bar.z_index = 10
	hp_bar.position = Vector2(-BAR_WIDTH * BAR_SCALE / 2.0, stats.hp_bar_offset)
	add_child(hp_bar)
#func _get_feet_y() -> float:
	#var frames := sprite.sprite_frames
	#if frames and frames.has_animation("idle") and frames.get_frame_count("idle") > 0:
		#var tex := frames.get_frame_texture("idle", 0)
		#if tex:
			#return tex.get_height() * absf(sprite.scale.y) * 0.5
	#return 40.0

	#var bg := StyleBoxFlat.new()
	#bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	#hp_fill = StyleBoxFlat.new()
	#hp_bar.add_theme_stylebox_override("background", bg)
	#hp_bar.add_theme_stylebox_override("fill", hp_fill)

	#var half_h := get_sprite_height() * 0.5
	#hp_bar.position = Vector2(-32, 80)
	#print(stats.display_name, " bar y=", hp_bar.position.y, " offset=", stats.hp_bar_offset)
	#add_child(hp_bar)
	#_recolor_bar()

func _update_hp_bar() -> void:
	hp_bar.set_stat(hp)

#func _recolor_bar() -> void:
	#var ratio := float(hp) / stats.max_hp
	#if ratio <= 0.25:
		#hp_fill.bg_color = Color(0.9, 0.2, 0.2)
	#elif ratio <= 0.5:
		#hp_fill.bg_color = Color(0.95, 0.8, 0.2)
	#else:
		#hp_fill.bg_color = Color(0.2, 0.8, 0.3)
	

# --- Damage numbers -----------------------------------------------------

func _show_damage_number(amount: int, color := Color.WHITE) -> void:
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = 100
	label.top_level = true
	add_child(label)
	label.global_position = global_position + Vector2(-10, -60)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position:y", label.global_position.y - 40, 0.7)
	tw.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tw.chain().tween_callback(label.queue_free)
	
func heal(amount: int) -> void:
	if not is_alive():
		return
	var gained := mini(amount, stats.max_hp - hp)
	hp += gained
	_show_damage_number(gained, Color(0.4, 1.0, 0.5))
	_update_hp_bar()
	modulate = Color(0.6, 1.4, 0.7)
	await get_tree().create_timer(0.3).timeout
	if is_alive():
		modulate = Color.WHITE
