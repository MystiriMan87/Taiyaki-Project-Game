class_name CharacterStats
extends Resource

@export var display_name := "Hero"
@export var max_hp := 100
@export var attack := 12
@export var defense := 5
@export var speed := 10
@export var texture: Texture2D
@export var sprite_frames: SpriteFrames
@export var drawn_facing_right := true
@export var battle_scale := 1.0
@export var hp_bar_offset := 0.0
@export var max_mp := 20
@export var magic := 14
@export var actions: Array[BattleAction] = []
