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

const MAX_LEVEL := 50
const MAX_PARTY := 3
var party_level: Dictionary = {}
var party_xp: Dictionary = {}

var reserve: Array[CharacterStats] = []
var seen: Dictionary = {}
var _species_cache: Array[CharacterStats] = []


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
	
func remove_member(s: CharacterStats) -> void:
	party.erase(s)
	party_hp.erase(s)
	party_mp.erase(s)
	party_level.erase(s)
	party_xp.erase(s)
	reserve.erase(s)

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
	battle.begin.emit()
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
		if overworld.has_method("refresh_followers"):
			overworld.refresh_followers()
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
		
func has_member(member_name: String) -> bool:
	for s in party + reserve:
		if s != null and s.display_name == member_name:
			return true
	return false
	
func recruit(s: CharacterStats) -> bool:
	var r: CharacterStats = s.duplicate()
	r.recruitable = false
	r.is_recruit = true
	party_hp[r] = r.max_hp
	party_mp[r] = r.max_mp
	seen[s.display_name] = true
	if party.size() < MAX_PARTY:
		party.append(r)
		return true
	reserve.append(r)
	return false
	
func add_from_reserve(m: CharacterStats) -> void:
	if party.size() < MAX_PARTY and reserve.has(m):
		reserve.erase(m)
		party.append(m)
		
func move_to_reserve(party_index: int) -> void:
	if party_index <= 0 or party_index >= party.size():
		return
	reserve.append(party[party_index])
	party.remove_at(party_index)

func swap_member(party_index: int, incoming: CharacterStats) -> void:
	if party_index <= 0 or party_index >= party.size() or not reserve.has(incoming):
		return
	var outgoing: CharacterStats = party[party_index]
	party[party_index] = incoming
	reserve.erase(incoming)
	reserve.append(outgoing)
	
func get_recruitable_species() -> Array[CharacterStats]:
	if not _species_cache.is_empty():
		return _species_cache
	var dir := DirAccess.open("res://Data")
	if dir == null:
		return _species_cache
	for f in dir.get_files():
		var fname: String = f.trim_suffix(".remap")
		if not fname.ends_with(".tres"):
			continue
		var res: Resource = load("res://Data/" + fname)
		if res is CharacterStats and (res as CharacterStats).recruitable:
			_species_cache.append(res as CharacterStats)
	return _species_cache
	
func get_level(s: CharacterStats) -> int:
	return party_level.get(s, 1)

func xp_to_next(level: int) -> int:
	return int(25 * pow(level, 1.6))  # Lv1->2: 25, Lv2->3: 75, Lv3->4: 139...
	
func award_xp(s: CharacterStats, amount: int) -> Dictionary:
	var lvl: int = get_level(s)
	var xp: int = party_xp.get(s, 0) + amount
	var gain := {"levels": 0, "hp": 0, "mp": 0, "attack": 0, "defense": 0, "magic": 0}
	while lvl < MAX_LEVEL and xp >= xp_to_next(lvl):
		xp -= xp_to_next(lvl)
		lvl += 1
		gain["levels"] += 1
		gain["hp"] += s.hp_growth
		gain["mp"] += s.mp_growth
		gain["attack"] += s.attack_growth
		gain["defense"] += s.defense_growth
		gain["magic"] += s.magic_growth
		s.max_hp += s.hp_growth
		s.max_mp += s.mp_growth
		s.attack += s.attack_growth
		s.defense += s.defense_growth
		s.magic += s.magic_growth
	party_level[s] = lvl
	party_xp[s] = xp
	if gain["levels"] > 0:
		party_hp[s] = mini(party_hp.get(s, s.max_hp) + gain["hp"], s.max_hp)
		party_mp[s] = mini(party_mp.get(s, s.max_mp) + gain["mp"], s.max_mp)
	return gain
