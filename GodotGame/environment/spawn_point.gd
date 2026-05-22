extends Marker2D

@export var move_player_on_ready := true

func _ready() -> void:
	add_to_group("SpawnPoint")
	if not move_player_on_ready:
		return
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		players[0].global_position = global_position
