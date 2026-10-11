extends Node

const BATTLE_SCENE := preload("res://Scenes/battle.tscn")
const SWIRL_PATH := "res://Shaders/swirl.gdshader"

var overworld: Node
var party: Array[CharacterStats] = []
var party_hp: Dictionary = {}
var party_mp: Dictionary = {}
var pending_defeated: Node = null
var _transitioning := false

var _fx_layer: CanvasLayer
var _fx_rect: ColorRect
var _swirl_mat: ShaderMaterial

func _ready() -> void:
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 100
	add_child(_fx_layer)
	_fx_rect = ColorRect.new()
	_fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_rect.visible = false
	_fx_layer.add_child(_fx_rect)
	if ResourceLoader.exists(SWIRL_PATH):
		_swirl_mat = ShaderMaterial.new()
		_swirl_mat.shader = load(SWIRL_PATH)
		_fx_rect.material = _swirl_mat
	else:
		_fx_rect.color = Color.BLACK   # fallback: plain fade if the shader file is missing

func heal_party() -> void:
	party_hp.clear()
	party_mp.clear()

func start_battle(enemies: Array[CharacterStats], background: Texture2D = null) -> void:
	if party.is_empty() or party.has(null):
		push_warning("Game.party is empty or contains null.")
		return
	if _transitioning:
		return
	_transitioning = true
	overworld.process_mode = Node.PROCESS_MODE_DISABLED
	await _transition(0.0, 1.0, 1.0)

	var battle = BATTLE_SCENE.instantiate()
	overworld.hide()
	get_tree().root.add_child(battle)
	battle.finished.connect(_on_battle_finished.bind(battle))
	battle.setup(party, enemies)
	if background:
		battle.set_background(background)

	await _transition(1.0, 0.0, 0.7)
	_transitioning = false

func _on_battle_finished(won: bool, battle: Node) -> void:
	await _transition(0.0, 1.0, 0.6)
	battle.queue_free()
	if won:
		if is_instance_valid(pending_defeated):
			pending_defeated.queue_free()
		pending_defeated = null
		overworld.show()
		overworld.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		pending_defeated = null
		party_hp.clear()
		party_mp.clear()
		get_tree().reload_current_scene()
	await _transition(1.0, 0.0, 0.6)

func _transition(from: float, to: float, duration: float) -> void:
	_fx_rect.visible = true
	var tw := create_tween()
	if _swirl_mat:
		tw.tween_method(func(v: float): _swirl_mat.set_shader_parameter("progress", v), from, to, duration)
	else:
		_fx_rect.modulate.a = from
		tw.tween_property(_fx_rect, "modulate:a", to, duration)
	await tw.finished
	if to <= 0.0:
		_fx_rect.visible = false
