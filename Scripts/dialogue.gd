class_name Dialogue
extends Resource

@export var requires_flag := ""
@export var lines: Array[String] = []
@export var choices: Array[String] = []
@export var set_flag := ""
@export var choice_flags: Array[String] = []

func is_available() -> bool:
	if requires_flag == "":
		return true
	if requires_flag.begins_with("!"):
		return not Game.flags.get(requires_flag.substr(1), false)
	return Game.flags.get(requires_flag, false)
	
func apply(choice: int) -> void:
	if set_flag != "":
		Game.flags[set_flag] = true
	if choice >= 0 and choice < choice_flags.size() and choice_flags[choice] != "": 
		Game.flags[choice_flags[choice]] = true
	
