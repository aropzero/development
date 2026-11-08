extends Node
## Music + sound effects. Calm, gentle and always safe to call.

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"

var music_player_a: AudioStreamPlayer
var music_player_b: AudioStreamPlayer
var _music_bus: int = 0
var _sfx_bus: int = 0
var _playlist: Array[String] = []
var _play_index: int = 0
var _active_music: AudioStreamPlayer
var _fading: bool = false
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_streams: Dictionary = {}
var _sfx_next: int = 0
var _music_started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_load_sfx()
	_setup_music()
	apply_volumes()


func _setup_buses() -> void:
	_music_bus = AudioServer.get_bus_index("Music")
	if _music_bus == -1:
		AudioServer.add_bus()
		_music_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_music_bus, "Music")
	_sfx_bus = AudioServer.get_bus_index("SFX")
	if _sfx_bus == -1:
		AudioServer.add_bus()
		_sfx_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_sfx_bus, "SFX")
	# A tiny amount of headroom keeps everything soft on phone speakers.
	AudioServer.set_bus_volume_db(_music_bus, -4.0)


func _setup_music() -> void:
	music_player_a = AudioStreamPlayer.new()
	music_player_b = AudioStreamPlayer.new()
	for p in [music_player_a, music_player_b]:
		p.bus = "Music"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
	music_player_a.finished.connect(_on_music_finished.bind(music_player_a))
	music_player_b.finished.connect(_on_music_finished.bind(music_player_b))
	_active_music = music_player_a

	var dir := DirAccess.open(MUSIC_DIR)
	if dir != null:
		for file in dir.get_files():
			if file.ends_with(".mp3") or file.ends_with(".ogg"):
				_playlist.append(MUSIC_DIR + file)
	_playlist.sort()


func _load_sfx() -> void:
	var dir := DirAccess.open(SFX_DIR)
	if dir == null:
		return
	for file in dir.get_files():
		if not (file.ends_with(".ogg") or file.ends_with(".wav") or file.ends_with(".mp3")):
			continue
		var stream = load(SFX_DIR + file)
		if stream is AudioStream:
			var key := file.get_basename()
			_sfx_streams[key] = stream
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players.append(p)


func apply_volumes() -> void:
	if AudioServer.get_bus_index("Music") != -1:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, SaveManager.music_volume)) - 3.0)
	if AudioServer.get_bus_index("SFX") != -1:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, SaveManager.sfx_volume)) - 1.0)


func start_music() -> void:
	if _music_started or _playlist.is_empty():
		return
	_music_started = true
	_play_index = randi() % _playlist.size()
	_play_stream(_active_music, _playlist[_play_index])


func stop_music(fade: bool = true) -> void:
	_music_started = false
	if not fade:
		music_player_a.stop()
		music_player_b.stop()
		return
	for p in [music_player_a, music_player_b]:
		var tw := create_tween()
		tw.tween_property(p, "volume_db", -42.0, 1.2)
		tw.tween_callback(p.stop)


func _play_stream(player: AudioStreamPlayer, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = false
	player.stream = stream
	player.volume_db = -26.0
	player.play()
	var tw := create_tween()
	tw.tween_property(player, "volume_db", 0.0, 2.4)


func _on_music_finished(player: AudioStreamPlayer) -> void:
	if not _music_started or player != _active_music:
		return
	_play_index = (_play_index + 1) % _playlist.size()
	_play_stream(player, _playlist[_play_index])


func set_music_volume(v: float) -> void:
	SaveManager.music_volume = clampf(v, 0.0, 1.0)
	apply_volumes()
	SaveManager.save_settings()


func set_sfx_volume(v: float) -> void:
	SaveManager.sfx_volume = clampf(v, 0.0, 1.0)
	apply_volumes()
	SaveManager.save_settings()


# ------------------------------------------------------------------ effects

func play(key: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream = _sfx_streams.get(key)
	if stream == null:
		return
	var player := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.5, 2.0)
	player.play()


func play_any(prefix: String, volume_db: float = 0.0) -> void:
	var options: Array[String] = []
	for key in _sfx_streams:
		if String(key).begins_with(prefix):
			options.append(String(key))
	if options.is_empty():
		return
	play(String(options[randi() % options.size()]), volume_db, randf_range(0.94, 1.06))


func ui_click() -> void:
	play("ui_click", -9.0, randf_range(0.98, 1.02))


func ui_tap() -> void:
	play("ui_tap", -11.0, randf_range(0.97, 1.03))


func ui_switch() -> void:
	play("ui_switch", -10.0, randf_range(0.98, 1.02))


func ui_confirm() -> void:
	play("ui_confirm", -12.0, randf_range(0.99, 1.01))


func sfx_place() -> void:
	play_any("impactPlank", -9.0)
	play("ui_confirm", -13.0, randf_range(0.98, 1.03))


func sfx_road() -> void:
	play_any("impactWood_light", -11.0)


func sfx_demolish() -> void:
	play_any("impactMining", -7.0)
	play_any("impactWood_medium", -10.0)


func sfx_upgrade() -> void:
	play("impactMetal_light_000", -7.0, 1.12)
	play("impactBell_heavy_000", -16.0, 1.25)


func sfx_coin() -> void:
	play("impactBell_heavy_001", -14.0, 1.35)


func sfx_error() -> void:
	play("impactSoft_medium_000", -7.0, 0.78)


func sfx_task() -> void:
	play("jingle_task", -5.0)


func sfx_level() -> void:
	play("jingle_level", -4.0)