extends Node

var player_data: Dictionary = {}
var current_map_scene: String = "res://levels/lobby.tscn"
var completed_levels: Array[String] = []

var _destination: String = ""
var _queue: Array[String] = []
var _transitioning: bool = false

var _canvas_layer: CanvasLayer
var _fade_overlay: ColorRect

func _ready() -> void:
	_setup_fade()

func _setup_fade() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 128
	add_child(_canvas_layer)

	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color.BLACK
	_fade_overlay.modulate.a = 0.0
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(_fade_overlay)

	await get_tree().process_frame
	_resize_overlay()
	get_viewport().size_changed.connect(_resize_overlay)

func _resize_overlay() -> void:
	if _fade_overlay and get_viewport():
		_fade_overlay.size = get_viewport().get_visible_rect().size
		_fade_overlay.position = Vector2.ZERO

func complete_level(level_name: String) -> void:
	if level_name not in completed_levels:
		completed_levels.append(level_name)

func is_level_completed(level_name: String) -> bool:
	return level_name in completed_levels

func save_player_status(player: Node2D) -> void:
	if is_instance_valid(player) and player.get("PlayerState") != null:
		player_data["health"] = player.PlayerState["health"]
		player_data["equipped_power"] = player.equipped_power
		player_data["passives"] = player.PlayerState["passives"].duplicate()

func restore_player_status(player: Node2D) -> void:
	if is_instance_valid(player) and not player_data.is_empty() and player.get("PlayerState") != null:
		player.PlayerState["health"] = player_data["health"]
		player.equipped_power = player_data["equipped_power"]
		player.PlayerState["passives"] = player_data["passives"].duplicate()
		if player.health_bar:
			player.health_bar.set_health(player.PlayerState["health"])
		player._equip_weapon_visual()
		player._update_passive_ui()

func advance_to(destination: String) -> void:
	if _transitioning:
		return
	var players := get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		save_player_status(players[0])

	var from_num := _get_level_number(current_map_scene)
	var to_num := _get_level_number(destination)
	_queue = _find_between(from_num, to_num)
	_destination = destination

	var first: String = _queue.pop_front() if not _queue.is_empty() else destination
	_load_scene(first)

func next_level() -> void:
	var next: String = _queue.pop_front() if not _queue.is_empty() else _destination
	if next != "":
		_load_scene(next)

func change_map(target_scene_path: String) -> void:
	advance_to(target_scene_path)

func _load_scene(scene_path: String) -> void:
	_transitioning = true
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var out := create_tween()
	out.tween_property(_fade_overlay, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	await out.finished

	current_map_scene = scene_path
	get_tree().change_scene_to_file(scene_path)

	await get_tree().process_frame
	await get_tree().process_frame
	_resize_overlay()

	var in_t := create_tween()
	in_t.tween_property(_fade_overlay, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	await in_t.finished

	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false

func _get_level_number(scene_path: String) -> float:
	var fname := scene_path.get_file().get_basename()
	if not fname.begins_with("level"):
		return -1.0
	var rest := fname.substr(5)
	if "_" in rest:
		var parts := rest.split("_")
		if parts.size() >= 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			return float(parts[0]) + float(parts[1]) / 10.0
	elif rest.is_valid_int():
		return float(rest)
	return -1.0

func _find_between(from_num: float, to_num: float) -> Array[String]:
	var result: Array[String] = []
	if from_num < 0.0 or to_num < 0.0:
		return result
	var from_int := int(round(from_num))
	var to_int := int(round(to_num))
	if not is_equal_approx(from_num, float(from_int)):
		return result
	if not is_equal_approx(to_num, float(to_int)):
		return result
	if to_int != from_int + 1:
		return result
	for i in range(1, 10):
		var path := "res://levels/level%d_%d.tscn" % [from_int, i]
		if ResourceLoader.exists(path):
			result.append(path)
	return result
