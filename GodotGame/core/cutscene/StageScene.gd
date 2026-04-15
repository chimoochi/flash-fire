class_name StageScene
extends Node2D

func _ready() -> void:
	# minigame setup runs here
	pass
	
func finish() -> void:
	MapService.next_level()
