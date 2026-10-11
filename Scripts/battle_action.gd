class_name BattleAction
extends Resource

enum TargetType { ONE_ENEMY, ALL_ENEMIES, ONE_ALLY, ALL_ALLIES }
enum DamageType { PHYSICAL, FIRE, ARCANE }
enum EffectType { DAMAGE, HEAL }


@export var display_name := "Heavy Strike"
@export var mp_cost := 4
@export var power := 1.8 # DMG multiplyer
@export var animation := "heavy_attack"
@export var target_type := TargetType.ONE_ENEMY
@export var damage_type := DamageType.PHYSICAL
@export var effect_type := EffectType.DAMAGE

@export_group("Projectile")
@export var projectile_frames: SpriteFrames
@export var projectile_texture: Texture2D
@export var projectile_scale := 1.0
@export var projectile_time := 0.4
@export var release_delay := 0.4

func calc_damage(user: CharacterStats, target: CharacterStats) -> int:
	var dmg: float 
	if damage_type == DamageType.PHYSICAL:
		dmg = user.attack * power - target.defense / 2.0
	else:
		dmg = user.magic * power - target.defense / 2.0
	return maxi(int(dmg * randf_range(0.9, 1.1)), 1)

func calc_heal(user: CharacterStats) -> int:
	return maxi(int(user.magic * power * randf_range(0.9, 1.1)), 1)
