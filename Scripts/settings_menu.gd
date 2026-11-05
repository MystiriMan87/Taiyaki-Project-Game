extends Control

signal closed

const PATH := "user://settings.cfg"

@onready var music: HSlider = %MusicSlider
@onready var sfx: HSlider = %SfxSlider
@onready var fullscreen: CheckButton = %FullScreen

func _ready() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	music.value = cfg.get_value("audio", "music", 0.8)
	sfx.value = cfg.get_value("audio", "sfx", 0.8)
	fullscreen.button_pressed = cfg.get_value("video", "fullscreen", false)
	_apply()
	music.value_changed.connect(func(_v): _apply())
	sfx.value_changed.connect(func(_v): _apply())
	fullscreen.toggled.connect(func(_on): _apply())
	%Back.pressed.connect(close)
	
func _apply() -> void:
	Audio.set_volume("Music", music.value)
	Audio.set_volume("SFX", sfx.value)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen.button_pressed else DisplayServer.WINDOW_MODE_WINDOWED)
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music.value)
	cfg.set_value("audio", "sfx", sfx.value)
	cfg.set_value("video", "fullscreen", fullscreen.button_pressed)
	cfg.save(PATH)
	
func open() -> void:
	show()
	%Back.grab_focus()
	
func close() -> void:
	hide()
	closed.emit()
	
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
