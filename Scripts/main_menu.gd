extends Control

@onready var buttons: Control = $Center
@onready var settings_menu = $SettingsMenu

func _ready() -> void:
	%Play.pressed.connect(_play)
	%Settings.pressed.connect(_show_settings)
	%Quit.pressed.connect(get_tree().quit)
	settings_menu.closed.connect(_show_buttons)
	_show_buttons()
	

func _play() -> void:
	SceneFade.change_scene("res://Scenes/overworld.tscn")
	
func _show_settings()-> void:
	buttons.hide()
	settings_menu.open()
	
func _show_buttons() -> void:
	buttons.show()
	%Play.grab_focus()
