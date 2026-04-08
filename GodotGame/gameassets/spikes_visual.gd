extends Node2D

func _draw() -> void:
	# allat is placeholder until artists are done
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.25, 0.25, 0.25, 1))

	var spike_color = Color(0.6, 0.6, 0.6, 1)
	var tip_color = Color(0.85, 0.85, 0.85, 1)

	var cols = 3
	var rows = 3
	var cell_w = 32.0 / cols
	var cell_h = 32.0 / rows
	for r in rows:
		for c in cols:
			var x = -16.0 + c * cell_w
			var y = -16.0 + r * cell_h
			var base_l = Vector2(x + 1, y + cell_h)
			var base_r = Vector2(x + cell_w - 1, y + cell_h)
			var tip = Vector2(x + cell_w / 2.0, y + 2)
			draw_polygon([base_l, tip, base_r], [spike_color, tip_color, spike_color])

	draw_rect(Rect2(-16, -16, 32, 32), Color(0.4, 0.4, 0.4, 1), false, 1.0)
