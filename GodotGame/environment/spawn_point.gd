extends Marker2D

func _ready() -> void:
	add_to_group("SpawnPoint")
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		players[0].global_position = global_position
