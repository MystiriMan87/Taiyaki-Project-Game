class_name PartyFollower
extends Node2D

const FOLLOW_GAP := 32 

var leader: Node2D
var index := 1
var stats: CharacterStats
var sprite: AnimatedSprite2D
var facing := "down"
var last_pos := Vector2.ZERO

func setup(s: CharacterStats, lead: Node2D, idx: int) -> void:
	stats = s 
	leader = lead
	index = idx
	#z_index = -1
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	sprite.sprite_frames = s.overworld_frames if s.overworld_frames else s.sprite_frames
	sprite.scale = lead.sprite.scale * s.overworld_scale
	global_position = lead.global_position
	last_pos = global_position
	
func _physics_process(_delta: float) -> void:
	if leader == null or sprite.sprite_frames == null:
		return
	var trail: Array[Vector2] = leader.trail
	if trail.is_empty():
		return
	var i: int = maxi(trail.size() - 1 - index * FOLLOW_GAP, 0)
	global_position = trail[i]
	var move: Vector2 = global_position - last_pos
	last_pos = global_position
	_update_animation(move)
	
func _update_animation(move: Vector2) -> void:
	var moving: bool = move.length() > 0.1
	if moving:
		if absf(move.x) > absf(move.y):
			facing = "right" if move.x > 0.0 else "left"
		else:
			facing = "down" if move.y > 0.0 else "up"
	var state: String = "walk" if moving else "idle"
	var frames: SpriteFrames = sprite.sprite_frames
	var directional: String = "%s_%s" % [state, facing]
	
	if frames.has_animation(directional):
		sprite.flip_h = false
		_play(directional)
	else:
		var anim: String = state if frames.has_animation(state) else "idle"
		if not frames.has_animation(anim):
			return
		if facing == "left":
			sprite.flip_h = stats.drawn_facing_right
		elif facing == "right":
			sprite.flip_h = not stats.drawn_facing_right
		_play(anim)
		
func _play(anim: String) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)
