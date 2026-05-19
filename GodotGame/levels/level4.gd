extends Node2D

func _ready() -> void:
	TaskService.set_tasks([
		{
			"label": "Kill all enemies",
			"type": "count_group",
			"group": "EnemyUnit",
		},
		{
			"label": "Find the exit",
			"type": "static",
		},
	])
