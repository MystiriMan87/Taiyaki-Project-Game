extends CanvasLayer

const SHADER := preload("res://Shaders/pixelate.gdshader")

var rect := ColorRect.new()
var mat := ShaderMaterial.new()

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	mat.shader = SHADER
	rect.material = mat
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	add_child(rect)

func _animate(from: float, to: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): mat.set_shader_parameter("progress", v), from, to, time)
	await tw.finished

func change_scene(path: String, out_time := 1.0, in_time := 1.0) -> void:
	rect.visible = true
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _animate(0.0, 1.0, out_time)
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	await _animate(1.0, 0.0, in_time)
	rect.visible = false
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
