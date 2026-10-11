extends Node

const BATTLE_SCENE := preload("res://Scenes/battle.tscn")
const SWIRL_SHADER := preload("res://Shaders/swirl.gdshader")

var overworld: Node 
var party: Array[CharacterStats] = []
var party_hp: Dictionary = {}
var party_mp: Dictionary = {}

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
	_swirl_mat = ShaderMaterial.new()
	_swirl_mat.shader = SWIRL_SHADER
	_fx_rect.material = _swirl_mat
	_fx_rect.visible = false
	_fx_layer.add_child(_fx_rect)
	
func _swirl(from: float, to: float, duration: float) -> void:
	_fx_rect.visible = true
	_swirl_mat.set_shader_parameter("progress", from)
	var tw := create_tween()
	tw.tween_method(func(v: float): _swirl_mat.set_shader_parameter("progress", v), from, to, duration)
	await tw.finished
	if to <= 0.0:
		_fx_rect.visible = false
	
func start_battle(enemies: Array[CharacterStats]) -> void:
	await _swirl(0.0, 1.0, 1.0)
	if party.is_empty() or party.has(null):
		push_warning("Game.party is empty or contains null. Check the hero.tres path in overworld.gd")
		return
	var battle = BATTLE_SCENE.instantiate()
	overworld.process_mode = Node.PROCESS_MODE_DISABLED
	overworld.hide()
	get_tree().root.add_child(battle)
	battle.finished.connect(_on_battle_finished.bind(battle))
	battle.setup(party, enemies)
	await _swirl(1.0, 0.0, 0.7)     # was: await _fade(0.0, 0.5)
	
func _on_battle_finished(won: bool, battle: Node) -> void:
	await _swirl(0.0, 1.0, 0.6)
	battle.queue_free()
	if won:
		overworld.show()
		overworld.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		party_hp.clear()
		party_mp.clear()
		get_tree().reload_current_scene()
	await _swirl(1.0, 0.0, 0.6)
		

func heal_party() -> void:
	party_hp.clear()
	party_mp.clear()
	
