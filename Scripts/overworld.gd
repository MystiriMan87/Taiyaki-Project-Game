extends Node2D

var party_menu: PartyMenu
var roster_menu: RosterMenu
var dialogue_box: DialogueBox
var pause_menu

func _ready() -> void:
	Game.overworld = self
	if Game.party.is_empty():
		Game.party.append(load("res://Data/hero.tres"))
		Game.party.append(load("res://Data/wizard.tres"))
	_spawn_followers()
	party_menu = PartyMenu.new()
	add_child(party_menu)
	roster_menu = RosterMenu.new()
	add_child(roster_menu)
	dialogue_box = DialogueBox.new()
	add_child(dialogue_box)
	pause_menu = preload("res://Scenes/PauseMenu.tscn").instantiate()
	add_child(pause_menu)

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or Game._transitioning or dialogue_box.active:
		return
	if not (event is InputEventKey and event.pressed and not event.echo) and not event.is_action_pressed("ui_cancel"):
		return
	if event.is_action_pressed("ui_cancel"):
		pause_menu.open()
	elif event.keycode == KEY_TAB:
		party_menu.open()
	elif event.keycode == KEY_R:
		roster_menu.open()
	elif event.keycode == KEY_H:
		Game.heal_party()
	else:
		return
	get_viewport().set_input_as_handled()

func _spawn_followers() -> void:
	var player_node: Node2D = $Player
	for i in range(1, Game.party.size()):
		var f := PartyFollower.new()
		add_child(f)
		f.setup(Game.party[i], player_node, i)
		
func refresh_followers() -> void:
	for c in get_children():
		if c is PartyFollower:
			c.queue_free()
	_spawn_followers()
