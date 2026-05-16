extends Node2D

enum Phase {INVESTIGATE, COMBAT}

var _phase: Phase = Phase.INVESTIGATE
var _player: Node2D = null
var _investigate_area: Node = null
var _investigated: bool = false
var _advanced: bool = false
var _startup_timer: float = 0.5

func _ready() -> void:
	_investigate_area = get_node_or_null("investigate")
	call_deferred("_deferred_ready")

func _deferred_ready() -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		_player = players[0]
	TaskService.set_tasks([
		{"label": "Investigate the abandoned town", "type": "static"},
	])

func _process(delta: float) -> void:
	if _phase == Phase.INVESTIGATE:
		if _startup_timer > 0.0:
			_startup_timer -= delta
			return
		_check_investigate_trigger()
	elif _phase == Phase.COMBAT:
		_lock_enemies_on_player()
		_check_combat_cleared()

func _check_investigate_trigger() -> void:
	if _investigated:
		return
	if not is_instance_valid(_player) or not is_instance_valid(_investigate_area):
		return

	var shape_node := _investigate_area.get_node_or_null("CollisionShape2D")
	if not shape_node:
		return

	var shape = shape_node.shape
	var radius: float = 150.0
	if shape is CircleShape2D:
		radius = (shape as CircleShape2D).radius * shape_node.scale.x

	if _player.global_position.distance_to(shape_node.global_position) > radius:
		return

	_investigated = true
	_begin_combat_phase()

func _begin_combat_phase() -> void:
	_phase = Phase.COMBAT
	TaskService.set_tasks([
		{"label": "Kill all enemies", "type": "count_group", "group": "EnemyUnit"},
		{"label": "Destroy all portals", "type": "count_group", "group": "EnemyPortal"},
	])

func _lock_enemies_on_player() -> void:
	if not is_instance_valid(_player):
		return
	var enemies := get_tree().get_nodes_in_group("Enemy")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if "last_known_position" in enemy:
			enemy.last_known_position = _player.global_position
		if "patience_timer" in enemy:
			enemy.patience_timer = 99.0
		if "target" in enemy:
			enemy.target = _player
		if "EnemyState" in enemy and "behavior" in enemy.EnemyState:
			var state: int = enemy.EnemyState["behavior"]
			if state == 0:
				enemy.EnemyState["behavior"] = 2

func _check_combat_cleared() -> void:
	if _advanced:
		return
	if get_tree().get_nodes_in_group("EnemyUnit").size() > 0:
		return
	if get_tree().get_nodes_in_group("EnemyPortal").size() > 0:
		return

	_advanced = true
	TaskService.clear_tasks()
	MapService.advance_to("res://levels/level3.tscn")
