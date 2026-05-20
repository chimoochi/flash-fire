extends Node2D

@export_file("*.tscn") var next_level_path: String = "res://levels/level2.tscn"

var _player_in_boat := false
var _advanced := false

func _ready() -> void:
	$BoatTrigger.body_entered.connect(_on_boat_entered)
	$BoatTrigger.body_exited.connect(_on_boat_exited)
	call_deferred("_start_spawn_intro")
	TaskService.set_tasks([
		{
			"label": "Kill all enemies",
			"type": "count_group",
			"group": "EnemyUnit",
		},
		{
			"label": "Destroy all portals",
			"type": "count_group",
			"group": "EnemyPortal",
		},
		{
			"label": "Board the boat",
			"type": "static",
		},
	])

func _start_spawn_intro() -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		players[0].play_spawn_intro()

func _on_boat_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_boat = true

func _on_boat_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_player_in_boat = false

func _process(_delta: float) -> void:
	if _advanced or not _player_in_boat:
		return
	if get_tree().get_nodes_in_group("EnemyUnit").size() > 0:
		return
	if get_tree().get_nodes_in_group("EnemyPortal").size() > 0:
		return
	_advanced = true
	TaskService.clear_tasks()
	MapService.advance_to(next_level_path)
