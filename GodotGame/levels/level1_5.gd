extends StageScene

const SURVIVE_TIME := 20.0
const LANE_LEFT := 220.0
const LANE_RIGHT := 1700.0
const PLAYER_Y := 880.0
const OBSTACLE_SCENE := preload("res://levels/boat_obstacle.tscn")

@export var difficulty: int = 1

var _timer := 0.0
var _spawn_timer := 0.0
var _spawn_interval := 1.75
var _obstacle_speed := 380.0
var _player: CharacterBody2D
var _timer_label: Label
var _finished := false

func _ready() -> void:
	_player = get_node("BoatPlayer")
	_player.position = Vector2(960.0, PLAYER_Y)
	_timer_label = get_node("UI/TimerLabel")

func _process(delta: float) -> void:
	if _finished:
		return

	_lock_player()

	_timer += delta
	var remaining := SURVIVE_TIME - _timer
	_timer_label.text = "Survive: %.1f" % maxf(remaining, 0.0)

	var progress := clampf(_timer / SURVIVE_TIME, 0.0, 1.0)
	var d := clampf(difficulty, 1.0, 10.0)
	_obstacle_speed = lerpf(380.0 + d * 30.0, 700.0 + d * 40.0, progress)
	_spawn_interval = lerpf(maxf(1.4 - d * 0.08, 0.4), maxf(0.55 - d * 0.04, 0.2), progress)

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _spawn_interval
		_spawn_wave()

	if _timer >= SURVIVE_TIME:
		_finished = true
		finish()

func _lock_player() -> void:
	_player.rotation = 0.0
	_player.position.x = clampf(_player.position.x, LANE_LEFT + 16.0, LANE_RIGHT - 16.0)
	_player.position.y = clampf(_player.position.y, 100.0, 1000.0)

func _spawn_wave() -> void:
	var progress := clampf(_timer / SURVIVE_TIME, 0.0, 1.0)
	var count := 3 + int(progress * float(difficulty + 1))
	var lanes := _pick_lanes(count)
	for x in lanes:
		var obs: Area2D = OBSTACLE_SCENE.instantiate()
		obs.speed = _obstacle_speed
		obs.position = Vector2(x, -60.0)
		obs.body_entered.connect(_on_obstacle_hit.bind(obs))
		add_child(obs)

func _pick_lanes(count: int) -> Array:
	var num_slots := 8
	var slot_w := (LANE_RIGHT - LANE_LEFT) / num_slots
	var slots := range(num_slots)
	slots.shuffle()
	var result := []
	for i in slots.slice(0, count):
		var base: float = LANE_LEFT + float(i) * slot_w + slot_w * 0.1
		result.append(base + randf() * slot_w * 0.8)
	return result

func _on_obstacle_hit(body: Node2D, obs: Node2D) -> void:
	if _finished:
		return
	if body.is_in_group("Player"):
		get_tree().reload_current_scene()
