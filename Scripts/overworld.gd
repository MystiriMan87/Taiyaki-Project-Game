extends Node2D

func _ready() -> void:
	Game.overworld = self
	if Game.party.is_empty():
		Game.party.append(load("res://Data/hero.tres"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		Game.heal_party()
		print("Party Healed")
