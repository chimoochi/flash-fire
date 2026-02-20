extends Node

var source_node: Node2D
const HEAL_AMOUNT := 10

var _tracked_enemies: Array = []

func _ready() -> void:
	if not is_instance_valid(source_node):
		return


	_refresh_enemies()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(source_node):
		return
	if not source_node.is_in_group("Player"):
		return


	var still_alive: Array = []
	for enemy_ref in _tracked_enemies:
		var enemy = enemy_ref.get_ref()
		if enemy:
			still_alive.append(enemy_ref)
		else:
			_heal_player()

	_tracked_enemies = still_alive


	var current_enemies = source_node.get_tree().get_nodes_in_group("Enemy")
	for enemy in current_enemies:
		var already_tracked = false
		for ref in _tracked_enemies:
			if ref.get_ref() == enemy:
				already_tracked = true
				break
		if not already_tracked:
			_tracked_enemies.append(weakref(enemy))

func _refresh_enemies() -> void:
	_tracked_enemies.clear()
	if not source_node.is_inside_tree():
		return
	for enemy in source_node.get_tree().get_nodes_in_group("Enemy"):
		_tracked_enemies.append(weakref(enemy))

func _heal_player() -> void:
	var state = source_node.get("PlayerState")
	if not state:
		return

	var max_h = state.get("max_health", 100)
	var heal_amount = ceil(max_h * 0.80)
	state["health"] = min(state["health"] + heal_amount, max_h)

	if source_node.get("health_bar"):
		source_node.health_bar.set_health(state["health"])
