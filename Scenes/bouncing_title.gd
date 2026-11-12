extends Label

@export var speed := 140.0

var velocity := Vector2(1, 0.75).normalized() * speed

func _ready() -> void:
	position = Vector2(randf_range(0.0, 200.0), randf_range(0.0, 200.0))

func _process(delta: float) -> void:
	position += velocity * delta
	var text_size := get_minimum_size()
	var area := get_parent_area_size() - text_size
	if position.x <= 0.0 or position.x >= area.x:
		velocity.x = -velocity.x
		position.x = clampf(position.x, 0.0, area.x)
	if position.y <= 0.0 or position.y >= area.y:
		velocity.y = -velocity.y
		position.y = clampf(position.y, 0.0, area.y)
