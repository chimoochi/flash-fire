extends Node

var source_node: Node2D
const HEAL_AMOUNT := 10

func _ready() -> void:
	if not is_instance_valid(source_node):
		return

	source_node.get_tree().node_removed.connect(_on_node_removed)

func _exit_tree() -> void:
	if is_instance_valid(source_node) and source_node.is_inside_tree():
		if source_node.get_tree().node_removed.is_connected(_on_node_removed):
			source_node.get_tree().node_removed.disconnect(_on_node_removed)

func _on_node_removed(node: Node) -> void:
	if not is_instance_valid(source_node):
		return

	if not node.is_in_group("Enemy"):
		return

	#if source is a player?
	if not source_node.is_in_group("Player"):
		return

	var state = source_node.get("PlayerState")
	if not state:
		return

	state["health"] = min(state["health"] + HEAL_AMOUNT, state.get("max_health", 100))

	if source_node.get("health_bar"):
		source_node.health_bar.set_health(state["health"])
