extends Node2D

@export var sprite_path: NodePath = NodePath("Leavessprite")
@export var strength := 1.5
@export var speed_max := 1.4
@export var speed_min := 0.9

const SWAY_SHADER := preload("res://Shaders/sway.gdshader")

func _ready() -> void:
	var s := get_node_or_null(sprite_path) as CanvasItem
	if s == null:
		push_warning("tree_sway: no node at %s" % sprite_path)
		return
	var mat := ShaderMaterial.new()
	mat.shader = SWAY_SHADER
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("speed", randf_range(0.9, 1.4))
	mat.set_shader_parameter("phase", randf() * TAU)
	mat.set_shader_parameter("speed", randf_range(speed_min, speed_max))
	s.material = mat
	
func _on_area_2d_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var mat := (get_node(sprite_path) as CanvasItem).material as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("strength", v), strength * 4.0, strength, 0.6)
