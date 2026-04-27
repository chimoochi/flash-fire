extends StaticBody2D

const CHECKS_REQUIRED := 5
const MAX_HEALTH := 200
const SPAWN_INTERVAL := 12.0
const ENEMY_SCENE = preload("res://enemy/level1.tscn")

var _in_range: bool = false
var _open: bool = false
var _checks_done: int = 0
var _health: int = MAX_HEALTH
var _destroyed: bool = false
var _spawn_timer: float = SPAWN_INTERVAL

@onready var _hint_label: Label = $HintLabel
@onready var _ui_panel: Panel = $GeneratorCanvas/Panel
@onready var _status_label: Label = $GeneratorCanvas/Panel/VBox/StatusLabel
@onready var _skill_check: Control = $GeneratorCanvas/Panel/VBox/SkillCheck
@onready var _health_bar: ProgressBar = $HealthBar
@onready var _countdown_label: Label = $SpawnCountdownLabel

func _ready() -> void:
	add_to_group("EnemyPortal")
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	_skill_check.succeeded.connect(_on_success)
	_skill_check.failed.connect(_on_fail)
	_ui_panel.visible = false
	_hint_label.visible = false
	_health_bar.max_value = MAX_HEALTH
	_health_bar.value = MAX_HEALTH
	_refresh_status()

func _process(delta: float) -> void:
	if _destroyed or _health <= 0:
		return
	_spawn_timer -= delta
	_countdown_label.text = str(ceili(_spawn_timer))
	if _spawn_timer <= 0:
		_spawn_enemy()
		_spawn_timer = SPAWN_INTERVAL

func _spawn_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_in_range = true
		_hint_label.text = "E — Destroy" if _health <= 0 else "Shoot to damage!"
		_hint_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_in_range = false
		_hint_label.visible = false
		_close()

func _unhandled_input(event: InputEvent) -> void:
	if not _in_range or _destroyed or _health > 0:
		return
	if event.is_action_pressed("interact"):
		if _open:
			_skill_check.attempt()
		else:
			_open_ui()
		get_viewport().set_input_as_handled()

func _open_ui() -> void:
	_open = true
	_ui_panel.visible = true
	_skill_check.start()

func _close() -> void:
	if not _open:
		return
	_open = false
	_ui_panel.visible = false
	_skill_check.stop()

func _on_success() -> void:
	_checks_done += 1
	_refresh_status()
	if _checks_done >= CHECKS_REQUIRED:
		_close()
		_destroy()

func _on_fail() -> void:
	_close()
	var dummy = StaticBody2D.new()
	dummy.global_position = global_position
	get_tree().root.add_child(dummy)
	ThrowableService.explode(120.0, global_position, 30, 1800.0, dummy)
	dummy.queue_free()
	CameraService.shake(0.6)
	CameraService.kick(Vector2(0.12, 0.12), 0.25)

func _refresh_status() -> void:
	_status_label.text = "Destroy: %d / %d" % [_checks_done, CHECKS_REQUIRED]

func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, _source: Node2D = null) -> void:
	if _destroyed or _health <= 0:
		return
	_health = max(0, _health - amount)
	_health_bar.value = _health
	DamageNumber.spawn(get_tree(), global_position + Vector2(randf_range(-8, 8), -40), amount, Color(1.0, 0.4, 0.1))
	if _health <= 0:
		_countdown_label.visible = false
		if _in_range:
			_hint_label.text = "E — Destroy"

func _destroy() -> void:
	_destroyed = true
	queue_free()
