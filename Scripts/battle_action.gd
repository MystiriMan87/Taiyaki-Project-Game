class_name BattleAction
extends Resource

enum TargetType { ONE_ENEMY, ALL_ENEMIES }
enum DamageType { PHYSICAL, FIRE }

@export var display_name := "Heavy Strike"
@export var mp_cost := 4
@export var power := 1.8 # DMG multiplyer
@export var animation := "heavy_attack"
@export var target_type := TargetType.ONE_ENEMY
@export var damage_type := DamageType.PHYSICAL

func calc_damage(user: CharacterStats, target: CharacterStats) -> int:
	var dmg: float 
	if damage_type == DamageType.PHYSICAL:
		dmg = user.attack * power - target.defense / 2.0
	else:
		dmg = user.magic * power - target.defense / 2.0
	return maxi(int(dmg * randf_range(0.9, 1.1)), 1)
