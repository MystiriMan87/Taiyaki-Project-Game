extends Node2D

var party_menu: PartyMenu

func _ready() -> void:
	Game.overworld = self
	if Game.party.is_empty():
		Game.party.append(load("res://Data/hero.tres"))
		Game.party.append(load("res://Data/wizard.tres"))
	_spawn_followers()
	party_menu = PartyMenu.new()
	add_child(party_menu)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		Game.heal_party()
		print("Party Healed")
	var is_tab: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB
	if (event.is_action_pressed("ui_cancel") or is_tab) and not party_menu.visible and not Game._transitioning:
		party_menu.open()
		get_viewport().set_input_as_handled()

func _spawn_followers() -> void:
	var player_node: Node2D = $Player
	for i in range(1, Game.party.size()):
		var f := PartyFollower.new()
		add_child(f)
		f.setup(Game.party[i], player_node, i)
