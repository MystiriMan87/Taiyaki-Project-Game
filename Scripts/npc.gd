class_name NPC
extends StaticBody2D

@export var npc_name := "Villager"
@export var sprite_frames: SpriteFrames
@export var drawn_facing_right := true
@export var sprite_scale := 1.0
@export var lines: Array[String] = ["Hello, traveler!"]
@export var repeat_lines: Array[String] = []
@export var heals_party := false

@export var dialogues: Array[Dialogue] = []

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var zone: Area2D = $InteractArea

var player: Node2D = null
var prompt: Label
var talked := false

func _ready() -> void:
	if sprite_frames:
		sprite.sprite_frames = sprite_frames
	sprite.scale = Vector2.ONE * sprite_scale
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
			
	prompt = Label.new()
	prompt.text = "Talk (Enter)"
	prompt.add_theme_font_size_override("font_size", 9)
	prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt.add_theme_constant_override("outline_size", 3)
	prompt.position = Vector2(-40, -70)
	prompt.z_index = 20
	prompt.hide()
	add_child(prompt)
	
	zone.body_entered.connect(_on_enter)
	zone.body_exited.connect(_on_exit)
	

func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		player = body as Node2D
		prompt.show()
		
func _on_exit(body: Node) -> void:
	if body == player:
		player = null
		prompt.hide()
		
func _unhandled_input(event: InputEvent) -> void:
	if player == null or not event.is_action_pressed("ui_accept"):
		return
	get_viewport().set_input_as_handled()
	_talk()
	
func _talk() -> void:
	var box: DialogueBox = Game.overworld.dialogue_box
	if box == null or box.active:
		return
	if Time.get_ticks_msec() - box.last_closed_msec < 250:
		return
	if player.has_method("stop"):
		player.call("stop")
	_face_player()
	prompt.hide()
	
	var d: Dialogue = null
	for entry in dialogues:
		if entry != null and entry.is_available():
			d = entry
			break
	if d == null:
		prompt.show()
		return
		
	box.start(npc_name, _portrait(), d.lines, d.choices)
	await box.finished
	d.apply(box.last_choice)
	
	if heals_party:
		Game.heal_party()
	if player != null:
		prompt.show()
		
func _face_player() -> void:
	var dx: float = player.global_position.x - global_position.x
	if absf(dx) < 1.0:
		return
	sprite.flip_h = (dx < 0.0) if drawn_facing_right else (dx > 0.0)
	
func _portrait() -> Texture2D:
	if sprite_frames and sprite_frames.has_animation("idle") and sprite_frames.get_frame_count("idle") > 0:
		return sprite_frames.get_frame_texture("idle", 0)
	return null
