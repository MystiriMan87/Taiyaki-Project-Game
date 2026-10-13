extends Area2D


@export var stats: CharacterStats
@export var extra_pool: Array[CharacterStats] = []
@export var min_extra := 0
@export var max_extra := 2
@export var battle_backgrounds: Array[Texture2D] = []

@export var wander_speed := 40.0
@export var wander_radius := 120.0
@export var chase_speed := 70.0
@export var chase_range := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var home: Vector2
var target: Vector2
var wait := 0.0
var triggered := false
var player: Node2D

func _ready() -> void:
	home = global_position
	target = home
	if stats and stats.sprite_frames:
		sprite.sprite_frames = stats.sprite_frames
		sprite.play("idle")
	body_entered.connect(_on_body_entered)
	
	if wander_speed >= 1.0 and stats.sprite_frames:
		sprite.sprite_frames = stats.sprite_frames
		sprite.play("walk")
	else:
		sprite.play("idle")
		
	
func _physics_process(delta: float) -> void:
	if triggered:
		return
	var dir := Vector2.ZERO
	if chase_range > 0.0 and player and global_position.distance_to(player.global_position) < chase_range:
		dir = (player.global_position - global_position).normalized()
		global_position += dir * chase_speed * delta
	else:
		wait -= delta
		if wait <= 0.0 and global_position.distance_to(target) < 4.0:
			target = home + Vector2.from_angle(randf() * TAU) * randf() * wander_radius
			wait = randf_range(0.5, 2.0)
		if global_position.distance_to(target) >= 4.0:
			dir = (target - global_position).normalized()
			global_position += dir * wander_speed * delta
	if dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0 if stats.drawn_facing_right else dir.x > 0.0
		
func _on_body_entered(body: Node) -> void:
	if triggered or not body.is_in_group("player"):
		return
	triggered = true
	body.stop()

	var group: Array[CharacterStats] = [stats]
	var valid: Array = extra_pool.filter(func(e): return e != null)
	if not valid.is_empty():
		for i in randi_range(min_extra, max_extra):
			group.append(valid.pick_random())

	var bg: Texture2D = null
	var valid_bgs: Array = battle_backgrounds.filter(func(t): return t != null)
	if not valid_bgs.is_empty():
		bg = valid_bgs.pick_random()

	Game.pending_defeated = self
	await Game.start_battle(group, bg)
