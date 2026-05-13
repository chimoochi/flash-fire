extends CanvasLayer

var _easy_mode: bool = false
var _easy_btn: Button
var _panel: PanelContainer

func _ready() -> void:
	layer = 100
	_build_ui()
	visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SHIFT and event.location == KEY_LOCATION_RIGHT:
			visible = !visible

func _process(_delta: float) -> void:
	if _easy_mode:
		for p in get_tree().get_nodes_in_group("Player"):
			if p.get("PlayerState") != null:
				p.PlayerState["is_invincible"] = true
	if _panel:
		var vp_size := get_viewport().get_visible_rect().size
		_panel.position = Vector2(vp_size.x - _panel.size.x - 20, 20)

func _build_ui() -> void:
	_panel = PanelContainer.new()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.1, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.25, 0.08, 1.0)
	style.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var inner := MarginContainer.new()
	inner.add_theme_constant_override("margin_top", 10)
	inner.add_theme_constant_override("margin_right", 14)
	inner.add_theme_constant_override("margin_left", 14)
	inner.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size.x = 200
	vbox.add_theme_constant_override("separation", 6)
	inner.add_child(vbox)

	var title := Label.new()
	title.text = "CHEAT MENU"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_add_button(vbox, "Kill All Enemies", _kill_all_enemies)
	_add_button(vbox, "Presenting", _presenting)
	_easy_btn = _add_button(vbox, "Easy Mode: OFF", _toggle_easy_mode)
	_add_button(vbox, "Next Level", _next_level)

	var hint := Label.new()
	hint.text = "[Right Shift] to toggle"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 10)
	vbox.add_child(hint)

func _add_button(parent: VBoxContainer, lbl: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = lbl
	btn.custom_minimum_size = Vector2(200, 34)
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn

func _kill_all_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("EnemyUnit"):
		if is_instance_valid(enemy) and enemy.has_method("die"):
			enemy.die()

func _presenting() -> void:
	for enemy in get_tree().get_nodes_in_group("EnemyUnit"):
		if not is_instance_valid(enemy):
			continue
		if enemy.get("is_execution_ready") == true:
			continue
		enemy.EnemyState["health"] = 1
		if enemy.has_method("start_low_health_pulse"):
			enemy.start_low_health_pulse()
		if enemy.get("health_bar") != null:
			enemy.health_bar.value = 1

func _toggle_easy_mode() -> void:
	_easy_mode = !_easy_mode
	if _easy_btn:
		_easy_btn.text = "Easy Mode: ON" if _easy_mode else "Easy Mode: OFF"

func _next_level() -> void:
	var current := MapService.current_map_scene
	var fname := current.get_file().get_basename()
	var next := "res://levels/lobby.tscn"
	if fname.begins_with("level"):
		var rest := fname.substr(5)
		var major := -1
		if rest.is_valid_int():
			major = rest.to_int()
		elif "_" in rest:
			var parts := rest.split("_")
			if parts[0].is_valid_int():
				major = parts[0].to_int()
		if major >= 0:
			var candidate := "res://levels/level%d.tscn" % (major + 1)
			if ResourceLoader.exists(candidate):
				next = candidate
	MapService.advance_to(next)
