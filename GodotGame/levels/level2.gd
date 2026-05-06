extends Node2D

func _ready() -> void:
	await get_tree().create_timer(5.0).timeout
	MapService.change_map("res://levels/lobby.tscn")
