extends CharacterBody2D

const SPEED := 180.0
const STEP_DISTANCE := 48.0
const ENCOUNTER_CHANCE := 0.12

@export var possible_enemies: Array[CharacterStats] = []
@export var art_faces_right := true #sideview
var distance_walked := 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
var facing := "down"

func _ready() -> void:
	print("possible_enemies: ", possible_enemies)

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED
	move_and_slide()
	_update_animation(dir)
	if dir != Vector2.ZERO:
		distance_walked += SPEED * delta
		if distance_walked >= STEP_DISTANCE:
			distance_walked = 0.0
			if randf() < ENCOUNTER_CHANCE:
				_trigger_encounter()

func _trigger_encounter() -> void:
	velocity = Vector2.ZERO
	_update_animation(Vector2.ZERO)
	var valid: Array[CharacterStats] = []
	for e in possible_enemies:
		if e != null:
			valid.append(e)
	if valid.is_empty():
		push_warning("Player.possible_enemies is empty or has blank slots")
		return

	var group: Array[CharacterStats] = []
	for i in randi_range(1, 3):
		group.append(valid.pick_random())
	Game.start_battle(group)
	
func _update_animation(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		if absf(dir.x) > absf(dir.y):
			facing = "right" if dir.x > 0 else "left"
		else:
			facing = "down" if dir.y > 0 else "up"
			
	var state := "walk" if dir != Vector2.ZERO else "idle"
	var directional := "%s_$s" % [state, facing]
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
		
