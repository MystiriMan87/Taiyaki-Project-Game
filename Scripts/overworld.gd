extends Node2D

func _ready() -> void:
	Game.overworld = self
	if Game.party.is_empty():
		Game.party.append(load("res://Data/hero.tres"))
		Game.party.append(load("res://Data/wizard.tres"))
	_spawn_followers()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		Game.heal_party()
		print("Party Healed")

func _spawn_followers() -> void:
	var player_node: Node2D = $Player
	for i in range(1, Game.party.size()):
		var f := PartyFollower.new()
		add_child(f)
		f.setup(Game.party[i], player_node, i)
