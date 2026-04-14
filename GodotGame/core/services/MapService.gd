extends Node


var player_data: Dictionary = {}
var current_map_scene: String = "res://levels/lobby.tscn"
var completed_levels: Array[String] = []

func _ready():
	print("Ready")

func complete_level(level_name: String) -> void:
	if level_name not in completed_levels:
		completed_levels.append(level_name)
		print("Level completed: ", level_name)

func is_level_completed(level_name: String) -> bool:
	return level_name in completed_levels


func save_player_status(player: Node2D):
	if is_instance_valid(player):
		player_data["health"] = player.PlayerState["health"]
		player_data["equipped_power"] = player.equipped_power
		player_data["passives"] = player.PlayerState["passives"].duplicate()
		print("saved ", player_data)


func restore_player_status(player: Node2D):
	if is_instance_valid(player) and not player_data.is_empty():
		player.PlayerState["health"] = player_data["health"]
		player.equipped_power = player_data["equipped_power"]
		player.PlayerState["passives"] = player_data["passives"].duplicate()
		
		if player.health_bar:
			player.health_bar.set_health(player.PlayerState["health"])
		if player.power_label:
			player.power_label.text = "Power: " + player.equipped_power.name
		
		player._equip_weapon_visual()
		player._update_passive_ui()
		
		print("restored")


func change_map(target_scene_path: String):
	var tree = get_tree()

	var players = tree.get_nodes_in_group("Player")
	if players.size() > 0:
		save_player_status(players[0])

	current_map_scene = target_scene_path
	tree.change_scene_to_file(target_scene_path)
	
