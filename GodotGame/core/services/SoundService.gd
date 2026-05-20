extends Node

const SOUNDS: Dictionary = {
	"music": preload("res://audio/music.mp3"),
	"kill":  preload("res://audio/kill.mp3"),
	"throw": preload("res://audio/throw.mp3"),
	"stomp": preload("res://audio/stomp.mp3"),
	"shotgun": preload("res://audio/shotgun.mp3"),
	"fireball": preload("res://audio/firefire.mp3"),
	"fire_beam": preload("res://audio/fire beam.mp3"),
	"fire_hurt": preload("res://audio/fire hurt.mp3"),
	"fire_impact": preload("res://audio/fire impact.mp3"),
	"explode": preload("res://audio/explode.mp3"),
	"ice_crack": preload("res://audio/ice-crack.mp3"),
	"tornado": preload("res://audio/tornado wind swoosh.mp3"),
}


var playing_sounds: Dictionary = {}
var _next_id: int = 0

var _music_player: AudioStreamPlayer = null
var _music_enabled := true
var _music_sound_name := "music"
var _music_volume_db := -10.0

func _ready() -> void:
	play_music()

func has_sound(sound_name: String) -> bool:
	return SOUNDS.has(sound_name)

func is_music_enabled() -> bool:
	return _music_enabled

func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	if _music_enabled:
		if _music_player and is_instance_valid(_music_player):
			_music_player.play()
		else:
			play_music(_music_sound_name, _music_volume_db)
	else:
		if _music_player and is_instance_valid(_music_player):
			_music_player.stop()

func toggle_music() -> bool:
	set_music_enabled(not _music_enabled)
	return _music_enabled

func play_sound(sound_name: String, volume_db: float = 0.0, start_time: float = 0.0) -> int:
	if not SOUNDS.has(sound_name):
		push_warning("SoundService: unknown sound '%s'" % sound_name)
		return -1

	var player := AudioStreamPlayer.new()
	player.stream = SOUNDS[sound_name]
	player.volume_db = volume_db
	add_child(player)
	player.play(start_time)

	var id := _next_id
	_next_id += 1
	playing_sounds[id] = player

	player.finished.connect(func(): _cleanup(id))
	return id


func play_sound_at(sound_name: String, position: Vector2, volume_db: float = 0.0, start_time: float = 0.0) -> int:
	if not SOUNDS.has(sound_name):
		push_warning("SoundService: unknown sound '%s'" % sound_name)
		return -1

	var player := AudioStreamPlayer2D.new()
	player.stream = SOUNDS[sound_name]
	player.volume_db = volume_db
	player.global_position = position
	get_tree().root.add_child(player)
	player.play(start_time)

	var id := _next_id
	_next_id += 1
	playing_sounds[id] = player

	player.finished.connect(func(): _cleanup(id))
	return id


func play_sound_on(sound_name: String, node: Node2D, volume_db: float = 0.0, start_time: float = 0.0) -> int:
	if not SOUNDS.has(sound_name):
		push_warning("SoundService: unknown sound '%s'" % sound_name)
		return -1

	var player := AudioStreamPlayer2D.new()
	player.stream = SOUNDS[sound_name]
	player.volume_db = volume_db
	node.add_child(player)
	player.play(start_time)

	var id := _next_id
	_next_id += 1
	playing_sounds[id] = player

	player.finished.connect(func(): _cleanup(id))
	return id

func stop_sound(id: int) -> void:
	if playing_sounds.has(id):
		var player = playing_sounds[id]
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
		playing_sounds.erase(id)

func stop_all() -> void:
	for id in playing_sounds.keys():
		stop_sound(id)

func play_music(sound_name: String = "music", volume_db: float = -10.0) -> void:
	_music_enabled = true
	_music_sound_name = sound_name
	_music_volume_db = volume_db
	if _music_player and is_instance_valid(_music_player):
		_music_player.queue_free()

	_music_player = AudioStreamPlayer.new()
	_music_player.stream = SOUNDS.get(sound_name)
	_music_player.volume_db = volume_db
	_music_player.autoplay = true
	add_child(_music_player)
	_music_player.play()

func stop_music() -> void:
	_music_enabled = false
	if _music_player and is_instance_valid(_music_player):
		_music_player.stop()

func _cleanup(id: int) -> void:
	if playing_sounds.has(id):
		var player = playing_sounds[id]
		if is_instance_valid(player):
			player.queue_free()
		playing_sounds.erase(id)
