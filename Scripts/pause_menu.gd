extends CanvasLayer

@onready var buttons: Control = $Center
@onready var settings_menu = $SettingsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS 
	hide()
	%Resume.pressed.connect(close)
	%Party.pressed.connect(_open_party)
	%Settings.pressed.connect(_show_settings)
	%QuitToMenu.pressed.connect(_quit_to_menu)
	settings_menu.closed.connect(_show_buttons)

func open() -> void:
	show()
	get_tree().paused = true
	_show_buttons()

func close() -> void:
	hide()
	get_tree().paused = false

func _open_party() -> void:
	hide()                                  
	Game.overworld.party_menu.open()

func _show_settings() -> void:
	buttons.hide()
	settings_menu.open()

func _show_buttons() -> void:
	buttons.show()
	%Resume.grab_focus()

func _quit_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not settings_menu.visible:
		close()
		get_viewport().set_input_as_handled()
