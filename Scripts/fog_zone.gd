extends Area2D

@export var clear_radius := 0.15
@export var fade_time := 1.0

const RING_SHADER := preload("res://Shaders/fog.gdshader")
const CLOUD_SHADER := preload("res://Shaders/fog_cloud.gdshader")

var ring_mat: ShaderMaterial
var cloud_mat: ShaderMaterial
var dim_rect: ColorRect
var tween: Tween

func _ready() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.01
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true

	# screen-space dim overlay + ring fog, on their own layer
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var screen := get_viewport().get_visible_rect().size

	dim_rect = ColorRect.new()
	dim_rect.color = Color(0.03, 0.04, 0.1, 0.0)
	dim_rect.size = screen
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim_rect)

	ring_mat = ShaderMaterial.new()
	ring_mat.shader = RING_SHADER
	ring_mat.set_shader_parameter("noise_tex", tex)
	ring_mat.set_shader_parameter("clear_radius", clear_radius)
	ring_mat.set_shader_parameter("density", 0.0)
	var ring := ColorRect.new()
	ring.material = ring_mat
	ring.size = screen
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ring)

	# world-space cloud bank over the zone, visible from outside
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape and shape.shape is RectangleShape2D:
		var size: Vector2 = (shape.shape as RectangleShape2D).size
		cloud_mat = ShaderMaterial.new()
		cloud_mat.shader = CLOUD_SHADER
		cloud_mat.set_shader_parameter("noise_tex", tex)
		cloud_mat.set_shader_parameter("rect_size", size)
		cloud_mat.set_shader_parameter("strength", 1.0)
		var cloud := ColorRect.new()
		cloud.material = cloud_mat
		cloud.size = size
		cloud.position = shape.position - size / 2.0
		cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cloud.z_index = 5
		add_child(cloud)
	else:
		push_warning("fog_zone: needs a child named 'CollisionShape2D' with a RectangleShape2D for the outside cloud.")

	body_entered.connect(func(b): if b.is_in_group("player"): _fade(1.0))
	body_exited.connect(func(b): if b.is_in_group("player"): _fade(0.0))

func _fade(to: float) -> void:
	if tween:
		tween.kill()
	tween = create_tween().set_parallel(true)
	tween.tween_method(func(v: float): ring_mat.set_shader_parameter("density", v), ring_mat.get_shader_parameter("density"), to, fade_time)
	tween.tween_property(dim_rect, "color:a", 0.4 * to, fade_time)
	if cloud_mat:
		tween.tween_method(func(v: float): cloud_mat.set_shader_parameter("strength", v), cloud_mat.get_shader_parameter("strength"), 1.0 - to, fade_time)
