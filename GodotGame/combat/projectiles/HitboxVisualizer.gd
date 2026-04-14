extends Node2D

var radius: float = 50.0
var duration: float = 0.5
var color: Color = Color(1, 0.5, 0, 0.5) # Orange semi-transparent

func _ready() -> void:
	queue_redraw()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, duration).from(1.0)
	tween.tween_callback(queue_free)

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, color)
