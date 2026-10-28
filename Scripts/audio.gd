extends Node

const SFX_DIR := "res://Audio/sfx/"
const MUSIC_DIR := "res://Audio/music/"
const POOL_SIZE := 12

var _pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	get_tree().node_added.connect(_on_node_added)  
	

func _on_node_added(n: Node) -> void:
	if n is Button:
		n.focus_entered.connect(func(): play("cursor", -6.0))
		n.pressed.connect(func(): play("confirm"))
		
func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_name(idx, "Master")
			
func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return
	
func _find(dir: String, base: String) -> AudioStream:
	var key := dir + base
	if _cache.has(key) and _cache[key] != null:
		return _cache[key]
	if not dir.ends_with("/"):
		dir += "/"
	for ext in ["mp3", "ogg", "wav"]:
		var path := "%s%s.%s" % [dir, base, ext]
		var s = load(path) if ResourceLoader.exists(path) else null
		print("try ", path, " exists=", ResourceLoader.exists(path))
		if s is AudioStream:
			_cache[key] = s
			return s
	return null
	
func play(sfx_name: String, volume_db := 0.0, pitch_var := 0.05) -> void:
	var stream := _find(SFX_DIR, sfx_name)
	print("play ", sfx_name, " -> ", stream)
	if stream == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return
			
func play_music(music_name: String, fade := 1.0) -> void:
	if music_name == _music_name:
		return
	_music_name = music_name
	var stream := _find(MUSIC_DIR, music_name)
	var old := _music_a if _music_a.playing else _music_b
	var fresh := _music_b if old == _music_a else _music_a
	if stream:
		fresh.stream = stream
		fresh.volume_db = -80.0
		fresh.play()
		create_tween().tween_property(fresh, "volume_db", 0.0, fade)
	if old.playing:
		var t := create_tween()
		t.tween_property(old, "volume_db", -80.0, fade)
		t.tween_callback(old.stop)
		
func stop_music(fade := 1.0) -> void:
	_music_name = ""
	for p in [_music_a, _music_b]:
		if p.playing:
			var t := create_tween()
			t.tween_property(p, "volume_db", -80.0, fade)
			t.tween_callback(p.stop)
			
func set_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
	

#func play_victory() -> void:
	#var stream := _find(MUSIC_DIR, "victory")
	#if stream == null:
		#return
	#var p := AudioStreamPlayer.new()
	#p.stream = stream
	#p.bus = "SFX"
	#add_child(p)
	#p.play()
	#p.finished.connect(p.queue_free)
