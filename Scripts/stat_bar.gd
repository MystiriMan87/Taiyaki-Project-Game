class_name StatBar
extends TextureProgressBar

const FRAME := preload("res://Art/bar_health_frame.tres")
const HP_FILL := preload("res://Art/bar_health_.tres")
const HP_LOW := preload("res://Art/bar_healthLow_.tres")
const MP_FILL := preload("res://Art/bar_mana_.tres")
const FILL_OFFSET := Vector2(2, 9)  # nudge to center the fill: (2,5) or (3,4) if it looks off by 1px

var is_mp := false
var _tween: Tween

func setup(max_v: int, v: int, mp := false) -> void:
	is_mp = mp
	texture_under = FRAME
	texture_progress = MP_FILL if mp else HP_FILL
	texture_progress_offset = FILL_OFFSET
	fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	max_value = max_v
	value = v
	_recolor()
	
func set_stat(v: int, animate := true) -> void:
	show()
	if _tween:
		_tween.kill()
	if animate:
		_tween = create_tween()
		_tween.tween_property(self, "value", v, 0.25)
	else:
		value = v
	_recolor(v)
	
func _recolor(v := -1) -> void:
	if is_mp:
		return
	var current := value if v < 0 else float(v)
	texture_progress = HP_LOW if current <= max_value * 0.25 else HP_FILL
