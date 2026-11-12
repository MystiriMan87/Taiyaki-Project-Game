extends CharacterBody2D

const SPEED := 180.0
const MAX_TRAIL := 120
var trail: Array[Vector2] = []

@export var art_faces_right := true   # side-view fallback

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var facing := "down"

func _ready() -> void:
	add_to_group("player")
	for i in MAX_TRAIL:
		trail.append(global_position)

func _physics_process(_delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED
	move_and_slide()
	_update_animation(dir)
	
	if global_position.distance_to(trail.back()) > 1.0:
		trail.append(global_position)
		if trail.size() > MAX_TRAIL:
			trail.pop_front()

func _update_animation(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		if absf(dir.x) > absf(dir.y):
			facing = "right" if dir.x > 0 else "left"
		else:
			facing = "down" if dir.y > 0 else "up"

	var state := "walk" if dir != Vector2.ZERO else "idle"
	var directional := "%s_%s" % [state, facing]
	var frames := sprite.sprite_frames

	if frames.has_animation(directional):
		sprite.flip_h = false
		_play(directional)
	elif frames.has_animation(state):
		if facing == "left":
			sprite.flip_h = art_faces_right
		elif facing == "right":
			sprite.flip_h = not art_faces_right
		_play(state)

func _play(anim: String) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)

func stop() -> void:
	velocity = Vector2.ZERO
	_update_animation(Vector2.ZERO)
