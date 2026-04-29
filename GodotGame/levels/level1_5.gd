extends StageScene

const SURVIVE_TIME := 20.0
const LANE_LEFT := 220.0
const LANE_RIGHT := 1700.0
const PLAYER_Y := 880.0
const OBSTACLE_SCENE := preload("res://levels/boat_obstacle.tscn")

var _timer := 0.0
var _spawn_timer := 0.0
var _spawn_interval := 1.4
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
	_obstacle_speed = lerpf(380.0, 700.0, progress)
	_spawn_interval = lerpf(1.4, 0.55, progress)

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _spawn_interval
		_spawn_wave()

	if _timer >= SURVIVE_TIME:
		_finished = true
		finish()

func _lock_player() -> void:
	_player.position.y = PLAYER_Y
	_player.velocity.y = 0.0
	_player.rotation = 0.0
	_player.position.x = clampf(_player.position.x, LANE_LEFT + 16.0, LANE_RIGHT - 16.0)

func _spawn_wave() -> void:
	var count := 1 if _timer < 8.0 else (2 if _timer < 15.0 else 3)
	var lanes := _pick_lanes(count)
	for x in lanes:
		var obs: Area2D = OBSTACLE_SCENE.instantiate()
		obs.speed = _obstacle_speed
		obs.position = Vector2(x, -60.0)
		obs.body_entered.connect(_on_obstacle_hit.bind(obs))
		add_child(obs)

func _pick_lanes(count: int) -> Array:
	var candidates := [260.0, 460.0, 660.0, 860.0, 1060.0, 1260.0, 1460.0, 1660.0]
	candidates.shuffle()
	return candidates.slice(0, count)

func _on_obstacle_hit(body: Node2D, obs: Node2D) -> void:
	if _finished:
		return
	if body.is_in_group("Player"):
		get_tree().reload_current_scene()
