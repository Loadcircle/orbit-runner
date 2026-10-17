extends Node
## Music with cross-fades and a small pool of one-shot sound effects.
## Streams are referenced by id and loaded on first use from audio/.

const MUSIC := {
	&"menu": "res://audio/music/menu_theme.wav",
	&"isles": "res://audio/music/sky_isles.wav",
	&"toyworks": "res://audio/music/toyworks.wav",
	&"ruins": "res://audio/music/solar_ruins.wav",
	&"tutorial": "res://audio/music/sky_isles.wav",
	&"victory": "res://audio/music/victory_jingle.wav",
}
const SFX_DIR := "res://audio/sfx/%s.wav"
const POOL_SIZE := 12
const FADE_TIME := 0.8

var _music_players: Array[AudioStreamPlayer] = []
var _active_music := 0
var _current_music: StringName
var _sfx_pool: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		_music_players.append(player)
		# Loop tracks seamlessly; jingles (victory) play once.
		player.finished.connect(func():
			if player == _music_players[_active_music] and _current_music != &"victory":
				player.play())
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_sfx_pool.append(player)


func play_music(id: StringName, restart := false) -> void:
	if id == _current_music and not restart:
		return
	_current_music = id
	var stream := _load(MUSIC.get(id, ""))
	var old := _music_players[_active_music]
	_active_music = 1 - _active_music
	var new := _music_players[_active_music]
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	if stream:
		new.stream = stream
		new.volume_db = -40.0
		new.play()
		_fade_tween.tween_property(new, "volume_db", 0.0, FADE_TIME)
	_fade_tween.tween_property(old, "volume_db", -40.0, FADE_TIME)
	_fade_tween.chain().tween_callback(old.stop)


func stop_music() -> void:
	_current_music = &""
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	var player := _music_players[_active_music]
	_fade_tween.tween_property(player, "volume_db", -40.0, FADE_TIME)
	_fade_tween.tween_callback(player.stop)


## Plays a one-shot from audio/sfx/<id>.wav. `pitch_jitter` adds variety.
func play_sfx(id: StringName, volume_db := 0.0, pitch := 1.0, pitch_jitter := 0.0) -> void:
	var stream := _load(SFX_DIR % id)
	if stream == null:
		return
	var player := _free_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


func _free_player() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player
	# All busy: steal the one that started first.
	var oldest := _sfx_pool[0]
	for player in _sfx_pool:
		if player.get_playback_position() > oldest.get_playback_position():
			oldest = player
	return oldest


func _load(path: String) -> AudioStream:
	if path.is_empty():
		return null
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]
