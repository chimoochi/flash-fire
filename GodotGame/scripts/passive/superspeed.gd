extends Node

var source_node: Node2D

const SPEED_MULTIPLIER := 1.4
const DASH_COOLDOWN_MULTIPLIER := 0.6
const DASH_SPEED_MULTIPLIER := 1.2

func _ready() -> void:
	if not is_instance_valid(source_node):
		return


	var saved = {}

	if source_node.is_in_group("Player") and source_node.get("PlayerState"):
		saved["MAX_SPEED"] = source_node.MAX_SPEED
		saved["dash_cooldown"] = source_node.PlayerState["dash_cooldown"]
		saved["dash_speed"] = source_node.PlayerState["dash_speed"]

		source_node.MAX_SPEED *= SPEED_MULTIPLIER
		source_node.PlayerState["dash_cooldown"] *= DASH_COOLDOWN_MULTIPLIER
		source_node.PlayerState["dash_speed"] *= DASH_SPEED_MULTIPLIER

	elif source_node.is_in_group("Enemy"):
		saved["move_speed"] = source_node.move_speed
		source_node.move_speed *= SPEED_MULTIPLIER

	PassiveService.save_stats(get_instance_id(), saved)

func _exit_tree() -> void:
	if not is_instance_valid(source_node):
		return

	var saved = PassiveService.revert_stats(get_instance_id())
	if saved.is_empty():
		return

	if source_node.is_in_group("Player") and source_node.get("PlayerState"):
		source_node.MAX_SPEED = saved.get("MAX_SPEED", source_node.MAX_SPEED)
		source_node.PlayerState["dash_cooldown"] = saved.get("dash_cooldown", source_node.PlayerState["dash_cooldown"])
		source_node.PlayerState["dash_speed"] = saved.get("dash_speed", source_node.PlayerState["dash_speed"])

	elif source_node.is_in_group("Enemy"):
		source_node.move_speed = saved.get("move_speed", source_node.move_speed)
