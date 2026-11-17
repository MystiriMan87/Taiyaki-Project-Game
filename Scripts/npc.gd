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

@export var altar_mode := false
@export var feed_goal := 10
@export var offerings := {"Orc": 1, "Armored Orc": 3, "Elite Orc": 6}

signal _picked(choice)

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
	
	if altar_mode:
		Game.setup_feed(feed_goal)
	

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
	
	if altar_mode:
		await _offer_menu()
		if player != null:
			prompt.show()
		return
	
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

func _offer_menu() -> void:
	var pool: Array = Game.reserve.duplicate()
	pool.append_array(Game.party.slice(1))
	var options: Array = pool.filter(func(s): return offerings.has(s.display_name))
	
	var layer := CanvasLayer.new()
	layer.layer = 55
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.18, 0.97)
	style.border_color = Color(0.85, 0.7, 0.35)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "Offer to the fog" if not options.is_empty() else "Nothing to offer"
	box.add_child(title)
	for s in options: 
		var b := Button.new()
		b.text = "%s   (+%d)" % [s.display_name, offerings[s.display_name]]
		b.pressed.connect(func(): _picked.emit(s))
		box.add_child(b)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): _picked.emit(null))
	box.add_child(cancel)
	layer.add_child(panel)
	add_child(layer)
	get_tree().paused = true
	box.get_child(1).grab_focus()
	
	var chosen = await _picked 
	layer.queue_free()
	get_tree().paused = false
	if chosen == null:
		return
	
	var was_fed: bool = Game.flags.get("fog_fed", false)
	Game.remove_member(chosen)
	Game.overworld.refresh_followers()
	Game.add_feed(offerings[chosen.display_name])
	if Game.flags.get("fog_fed", false) and not was_fed:
		var lines: Array[String] = ["The fog stirs..."]
		Game.overworld.dialogue_box.start(npc_name, null, lines)
