class_name DamageNumber
extends Node2D

static func spawn(tree: SceneTree, position: Vector2, amount: int, color: Color = Color.WHITE) -> void:
	var node := DamageNumber.new()
	node.global_position = position
	node._amount = amount
	node._color = color
	tree.root.add_child(node)

var _amount: int = 0
var _color: Color = Color.WHITE

func _ready() -> void:
	var label := Label.new()
	label.text = str(_amount)
	label.add_theme_color_override("font_color", _color)
	label.add_theme_font_size_override("font_size", 18)
	label.position = Vector2(-12, -8)
	add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", global_position + Vector2(randf_range(-12, 12), -48), 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(queue_free)
