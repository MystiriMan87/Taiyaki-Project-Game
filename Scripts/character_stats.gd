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
@export var callout_offset := -100.0# negative = higher above the character's center
@export var footprint_height := 0.0   # 0 = measure automatically, otherwise use this many pixels
@export var basic_attack: BattleAction
@export var muzzle_offset := Vector2(40, -20) # where projectiles spawn, relative to the character, in the direction they face
@export var overworld_frames: SpriteFrames # walk/idle animations
@export var overworld_scale := 1.0

@export var xp_reward := 10
@export_group("Growth per level")
@export var hp_growth := 12
@export var mp_growth := 3
@export var attack_growth := 2
@export var defense_growth := 1
@export var magic_growth := 2
