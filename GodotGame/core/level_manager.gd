extends Node

@export var level_name: String = ""

var _level_cleared: bool = false

func _process(_delta: float) -> void:
	if _level_cleared:
		return
	if get_tree().get_nodes_in_group("EnemyUnit").size() == 0:
		_level_cleared = true
		if level_name != "":
			MapService.complete_level(level_name)
		MapService.advance_to(_next_level_path())

func _next_level_path() -> String:
	var current := MapService.current_map_scene
	var fname := current.get_file().get_basename()
	if fname.begins_with("level") and fname.substr(5).is_valid_int():
		var num := fname.substr(5).to_int() + 1
		var next := "res://levels/level%d.tscn" % num
		if ResourceLoader.exists(next):
			return next
	return "res://levels/lobby.tscn"
