extends Node

const SOUNDS: Dictionary = {
	"music": preload("res://gameassets/music.mp3"),
	"kill":  preload("res://gameassets/kill.mp3"),
}


var playing_sounds: Dictionary = {}
var _next_id: int = 0

var _music_player: AudioStreamPlayer = null

func _ready() -> void:
	play_music()


func play_sound(sound_name: String, volume_db: float = 0.0) -> int:
	if not SOUNDS.has(sound_name):
		push_warning("SoundService: unknown sound '%s'" % sound_name)
		return -1

	var player := AudioStreamPlayer.new()
	player.stream = SOUNDS[sound_name]
	player.volume_db = volume_db
	add_child(player)
	player.play()

	var id := _next_id
	_next_id += 1
	playing_sounds[id] = player

	player.finished.connect(func(): _cleanup(id))
	return id


func play_sound_at(sound_name: String, position: Vector2, volume_db: float = 0.0) -> int:
	if not SOUNDS.has(sound_name):
		push_warning("SoundService: unknown sound '%s'" % sound_name)
		return -1

	var player := AudioStreamPlayer2D.new()
	player.stream = SOUNDS[sound_name]
	player.volume_db = volume_db
	player.global_position = position
	get_tree().root.add_child(player)
	player.play()

	var id := _next_id
	_next_id += 1
	playing_sounds[id] = player

	player.finished.connect(func(): _cleanup(id))
	return id


func play_sound_on(sound_name: String, node: Node2D, volume_db: float = 0.0) -> int:
	if not SOUNDS.has(sound_name):
		push_warning("SoundService: unknown sound '%s'" % sound_name)
		return -1

	var player := AudioStreamPlayer2D.new()
	player.stream = SOUNDS[sound_name]
	player.volume_db = volume_db
	node.add_child(player)
	player.play()

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
	if _music_player and is_instance_valid(_music_player):
		_music_player.queue_free()

	_music_player = AudioStreamPlayer.new()
	_music_player.stream = SOUNDS.get(sound_name)
	_music_player.volume_db = volume_db
	_music_player.autoplay = true
	add_child(_music_player)
	_music_player.play()

func stop_music() -> void:
	if _music_player and is_instance_valid(_music_player):
		_music_player.stop()

func _cleanup(id: int) -> void:
	if playing_sounds.has(id):
		var player = playing_sounds[id]
		if is_instance_valid(player):
			player.queue_free()
		playing_sounds.erase(id)
