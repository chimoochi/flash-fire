extends Control

signal succeeded
signal failed

const RADIUS := 90.0
const TRACK_WIDTH := 20.0
const ZONE_SIZE := deg_to_rad(38.0)
const NEEDLE_SPEED := PI  # half rotation per second

var _needle_angle: float = 0.0
var _zone_start: float = 0.0
var _running: bool = false

func start() -> void:
	_needle_angle = 0.0
	_zone_start = randf() * TAU
	_running = true

func stop() -> void:
	_running = false

func attempt() -> void:
	var offset := fmod(_needle_angle - _zone_start + TAU, TAU)
	if offset < ZONE_SIZE:
		_zone_start = randf() * TAU
		succeeded.emit()
	else:
		failed.emit()

func _process(delta: float) -> void:
	if not _running:
		return
	_needle_angle = fmod(_needle_angle + NEEDLE_SPEED * delta, TAU)
	queue_redraw()

func _draw() -> void:
	var c := size / 2.0

	# dark track
	draw_arc(c, RADIUS, 0.0, TAU, 80, Color(0.12, 0.12, 0.12), TRACK_WIDTH)

	# orange arc (full circle minus success zone)
	draw_arc(c, RADIUS, _zone_start + ZONE_SIZE, _zone_start + TAU, 80, Color(0.95, 0.45, 0.05), TRACK_WIDTH)

	# white success zone
	draw_arc(c, RADIUS, _zone_start, _zone_start + ZONE_SIZE, 20, Color(1.0, 1.0, 1.0), TRACK_WIDTH)

	# needle
	var tip := c + Vector2(cos(_needle_angle), sin(_needle_angle)) * RADIUS
	draw_line(c, tip, Color(1.0, 0.15, 0.15), 4.0, true)
	draw_circle(c, 5.0, Color(1.0, 1.0, 1.0))
