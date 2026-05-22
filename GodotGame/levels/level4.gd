extends Node2D

func _ready() -> void:
	TaskService.set_tasks([
		{"label": "The end", "type": "static"},
	])
