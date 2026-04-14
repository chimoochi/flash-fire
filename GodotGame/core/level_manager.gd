extends Node

@export var level_name: String = ""

var _level_cleared: bool = false

func _process(_delta: float) -> void:
	if _level_cleared:
		return
	var enemies = get_tree().get_nodes_in_group("EnemyUnit")
	if enemies.size() == 0:
		_level_cleared = true
		print("LevelManager: all enemies dead, changing map")
		if level_name != "":
			MapService.complete_level(level_name)
		MapService.change_map("res://levels/lobby.tscn")
