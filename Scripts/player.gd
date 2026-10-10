extends CharacterBody2D

const SPEED := 180.0
const STEP_DISTANCE := 48.0
const ENCOUNTER_CHANCE := 0.12

@export var possible_enemies: Array[CharacterStats] = []
var distance_walked := 0.0

func _ready() -> void:
	print("possible_enemies: ", possible_enemies)

func _physics_process(delta: float) -> void:
	var dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = dir * SPEED
	move_and_slide()
	if dir != Vector2.ZERO:
		distance_walked += SPEED * delta
		if distance_walked >= STEP_DISTANCE:
			distance_walked = 0.0
			if randf() < ENCOUNTER_CHANCE:
				_trigger_encounter()

func _trigger_encounter() -> void:
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
