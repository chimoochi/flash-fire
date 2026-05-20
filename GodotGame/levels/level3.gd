extends Node2D

const LAVA_FINAL_BOSS_SCENE = preload("res://actors/enemies/lava_final_boss.tscn")

enum Phase {INVESTIGATE, COMBAT, BOSS, CLEARED}

var _phase: Phase = Phase.INVESTIGATE
var _player: Node2D = null
var _investigate_area: Node = null
var _investigated := false
var _boss_spawned := false
var _startup_timer := 0.5

func _ready() -> void:
	_investigate_area = get_node_or_null("investigate")
	call_deferred("_deferred_ready")

func _deferred_ready() -> void:
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		_player = players[0]
	TaskService.set_tasks([
		{"label": "Investigate the mysterious fire palace", "type": "static"},
	])

func _process(delta: float) -> void:
	match _phase:
		Phase.INVESTIGATE:
			if _startup_timer > 0.0:
				_startup_timer -= delta
				return
			_check_investigate_trigger()
		Phase.COMBAT:
			_lock_enemies_on_player()
			_check_combat_cleared()
		Phase.BOSS:
			_lock_enemies_on_player()
			_check_boss_cleared()

func _check_investigate_trigger() -> void:
	if _investigated:
		return
	if not is_instance_valid(_player) or not is_instance_valid(_investigate_area):
		return

	var shape_node := _investigate_area.get_node_or_null("CollisionShape2D")
	if not shape_node:
		return

	var radius := 150.0
	if shape_node.shape is CircleShape2D:
		radius = (shape_node.shape as CircleShape2D).radius * shape_node.scale.x

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
	for enemy in get_tree().get_nodes_in_group("Enemy"):
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
	if get_tree().get_nodes_in_group("EnemyUnit").size() > 0:
		return
	if get_tree().get_nodes_in_group("EnemyPortal").size() > 0:
		return
	_spawn_lava_final_boss()

func _spawn_lava_final_boss() -> void:
	if _boss_spawned:
		return
	_boss_spawned = true
	_phase = Phase.BOSS
	EnvironmentService.reset_environment_effects()
	var boss := LAVA_FINAL_BOSS_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(boss)
	boss.global_position = _get_lava_boss_spawn_position()
	TaskService.set_tasks([
		{"label": "Defeat the lava final boss", "type": "count_group", "group": "LavaFinalBoss"},
	])
	VisualEffectsService.set_mood("fire")

func _get_lava_boss_spawn_position() -> Vector2:
	var spawn := get_node_or_null("LavaFinalBossSpawnPoint") as Node2D
	if is_instance_valid(spawn):
		return spawn.global_position
	if is_instance_valid(_investigate_area):
		return _investigate_area.global_position
	return Vector2.ZERO

func _check_boss_cleared() -> void:
	if get_tree().get_nodes_in_group("LavaFinalBoss").size() > 0:
		return
	_phase = Phase.CLEARED
	VisualEffectsService.set_mood("normal")
	TaskService.set_tasks([
		{"label": "Fire palace cleared", "type": "static"},
	])
