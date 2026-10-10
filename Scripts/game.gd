extends Node

const BATTLE_SCENE := preload("res://Scenes/battle.tscn")

var overworld: Node 
var party: Array[CharacterStats] = []
var party_hp: Dictionary = {}
var party_mp: Dictionary = {}

func start_battle(enemies: Array[CharacterStats]) -> void:
	if party.is_empty() or party.has(null):
		push_warning("Game.party is empty or contains null. Check the hero.tres path in overworld.gd")
		return
	var battle = BATTLE_SCENE.instantiate()
	overworld.process_mode = Node.PROCESS_MODE_DISABLED
	overworld.hide()
	get_tree().root.add_child(battle)
	battle.finished.connect(_on_battle_finished.bind(battle))
	battle.setup(party, enemies)
	
func _on_battle_finished(won: bool, battle: Node) -> void:
	battle.queue_free()
	if won:
		overworld.show()
		overworld.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		party_hp.clear()   # placeholder: full heal on defeat
		party_mp.clear()
		get_tree().reload_current_scene()
		

func heal_party() -> void:
	party_hp.clear()
	party_mp.clear()
	
