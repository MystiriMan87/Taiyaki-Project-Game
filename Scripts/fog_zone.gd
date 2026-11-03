extends Area2D

@export var clear_radius := 0.28
@export var fade_time := 1.0

const FOG_SHADER := preload("res://Shaders/fog.gdshader")

var mat: ShaderMaterial
var layer: CanvasLayer
var tween: Tween
var dim_rect: ColorRect

func _ready() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.01
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	
	mat = ShaderMaterial.new()
	mat.shader = FOG_SHADER
	mat.set_shader_parameter("density", 0.0)
	mat.set_shader_parameter("noise_tex", tex)
	mat.set_shader_parameter("clear_radius", clear_radius)
	
	var rect := ColorRect.new()
	rect.material = mat
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	layer = CanvasLayer.new()
	layer.layer = 10
	dim_rect = ColorRect.new()
	dim_rect.color = Color(0.03, 0.04, 0.1, 0.0)
	dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim_rect)
	layer.add_child(rect)
	add_child(layer)
	#dim = CanvasModulate.new()
	#get_parent().add_child.call_deferred(dim)
	
	body_entered.connect(_on_enter)
	body_exited.connect(func(b): if b.is_in_group("player"): _fade(0.0))
	print("fog zone ready")

func _on_enter(b: Node) -> void:
	print("entered ", b.name)
	if b.is_in_group("player"):
		_fade(1.0)
	
func _fade(to: float) -> void:
	if tween:
		tween.kill()
	var from: float = mat.get_shader_parameter("density")
	tween = create_tween().set_parallel(true)
	tween.tween_method(func(v: float): mat.set_shader_parameter("density", v), from, to, fade_time)
	tween.tween_property(dim_rect, "color:a", 0.4 * to, fade_time)
