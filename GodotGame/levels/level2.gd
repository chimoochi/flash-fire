extends Node2D

const ICE_GOLEM_BOSS_SCENE = preload("res://actors/enemies/ice_golem_boss.tscn")
const BOSS_CAMERA_PAN_TIME := 1.0
const BOSS_CAMERA_HOLD_TIME := 1.0

enum Phase {INVESTIGATE, COMBAT, BOSS_REVEAL, BOSS}

var _phase: Phase = Phase.INVESTIGATE
var _player: Node2D = null
var _investigate_area: Node = null
var _boss_detection_area: Area2D = null
var _boss_spawn_point: Node2D = null
var _boss_camera_target: Node2D = null
var _investigated: bool = false
var _advanced: bool = false
var _boss_spawned: bool = false
var _startup_timer: float = 0.5

func _ready() -> void:
	_investigate_area = get_node_or_null("investigate")
	_boss_detection_area = get_node_or_null("CaveGuardDetectionArea")
	_boss_spawn_point = get_node_or_null("CaveGuardSpawnPoint")
	_boss_camera_target = get_node_or_null("CaveGuardCameraTarget")
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
	elif _phase == Phase.BOSS:
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
	if _phase != Phase.COMBAT:
		return
	if get_tree().get_nodes_in_group("EnemyUnit").size() > 0:
		return
	if get_tree().get_nodes_in_group("EnemyPortal").size() > 0:
		return

	_begin_boss_reveal()

func _begin_boss_reveal() -> void:
	if _boss_spawned or _phase == Phase.BOSS_REVEAL:
		return
	_phase = Phase.BOSS_REVEAL
	_boss_spawned = true
	await _pan_to_boss_and_spawn()
	_phase = Phase.BOSS
	TaskService.set_tasks([
		{"label": "Destroy the cave guard", "type": "count_group", "group": "CaveGuard"},
	])

func _pan_to_boss_and_spawn() -> void:
	var spawn_pos := _get_boss_spawn_position()
	var camera_target := _boss_camera_target.global_position if is_instance_valid(_boss_camera_target) else spawn_pos
	var player_camera := get_viewport().get_camera_2d()

	if not player_camera:
		var fallback_boss := _spawn_boss(spawn_pos)
		if is_instance_valid(fallback_boss):
			fallback_boss.set_physics_process(true)
		await get_tree().create_timer(BOSS_CAMERA_HOLD_TIME).timeout
		return

	var cutscene_camera := Camera2D.new()
	cutscene_camera.name = "CaveGuardRevealCamera"
	cutscene_camera.global_position = player_camera.get_screen_center_position()
	cutscene_camera.zoom = player_camera.zoom
	add_child(cutscene_camera)
	cutscene_camera.make_current()
	CameraService.current_camera = cutscene_camera

	var pan_to_boss := create_tween()
	pan_to_boss.tween_property(cutscene_camera, "global_position", camera_target, BOSS_CAMERA_PAN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await pan_to_boss.finished

	var boss := _spawn_boss(spawn_pos)
	if is_instance_valid(boss):
		boss.set_physics_process(false)
	await get_tree().create_timer(BOSS_CAMERA_HOLD_TIME).timeout

	var player_return_pos := _player.global_position if is_instance_valid(_player) else player_camera.get_screen_center_position()
	var pan_to_player := create_tween()
	pan_to_player.tween_property(cutscene_camera, "global_position", player_return_pos, BOSS_CAMERA_PAN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await pan_to_player.finished

	if is_instance_valid(player_camera):
		player_camera.make_current()
		CameraService.current_camera = player_camera
	cutscene_camera.queue_free()
	if is_instance_valid(boss):
		boss.set_physics_process(true)

func _get_boss_spawn_position() -> Vector2:
	if is_instance_valid(_boss_spawn_point):
		return _boss_spawn_point.global_position
	if is_instance_valid(_boss_detection_area):
		return _boss_detection_area.global_position
	return Vector2.ZERO

func _spawn_boss(spawn_pos: Vector2) -> Node2D:
	var boss := ICE_GOLEM_BOSS_SCENE.instantiate() as Node2D
	get_tree().current_scene.add_child(boss)
	boss.global_position = spawn_pos
	return boss

func _check_boss_cleared() -> void:
	if _advanced:
		return
	if get_tree().get_nodes_in_group("CaveGuard").size() > 0:
		return
	_advanced = true
	TaskService.clear_tasks()
	MapService.advance_to("res://levels/level3.tscn")
