extends Control

@onready var health_bar = $HealthSection/HealthBar
@onready var stamina_bar: ProgressBar = $StaminaSection/StaminaBar

@onready var _cd1: ColorRect = $Content/AttacksRow/Slot1/IconWrap1/Cooldown1
@onready var _cd2: ColorRect = $Content/AttacksRow/Slot2/IconWrap2/Cooldown2
@onready var _cd3: ColorRect = $Content/AttacksRow/Slot3/IconWrap3/Cooldown3
@onready var _cd4: ColorRect = $Content/AttacksRow/Slot4/IconWrap4/Cooldown4

@onready var _hb1: TextureRect = $HealthBar1
@onready var _hb2: TextureRect = $HealthBar2

var _beat_timer := 0.0
var _beat_intervals := [0.25, 0.25, 0.5]
var _beat_index := 0
var _beat_frame := false

@onready var _wraps: Array = [
	$Content/AttacksRow/Slot1/IconWrap1,
	$Content/AttacksRow/Slot2/IconWrap2,
	$Content/AttacksRow/Slot3/IconWrap3,
	$Content/AttacksRow/Slot4/IconWrap4,
]

var _portal_indicators: Dictionary = {}

const _IND_SIZE := Vector2(120.0, 28.0)

# ── Task Panel ─────────────────────────────────────────────────────────────
var _task_container: VBoxContainer

func _ready() -> void:
	_build_task_panel()
	TaskService.tasks_changed.connect(_refresh_task_panel)
	_refresh_task_panel()

func _build_task_panel() -> void:
	_task_container = VBoxContainer.new()
	_task_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_task_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_task_container.offset_left = 14
	_task_container.offset_top = 14
	_task_container.add_theme_constant_override("separation", 2)
	add_child(_task_container)

func _refresh_task_panel() -> void:
	for child in _task_container.get_children():
		child.queue_free()

	var tasks := TaskService.task_list
	_task_container.visible = tasks.size() > 0

	for task in tasks:
		var done: bool = task.get("done", false)
		var remaining: int = task.get("remaining", -1)
		var text: String = ("[ ] " if not done else "[x] ") + str(task.get("label", ""))
		if remaining >= 0:
			text += " (" + str(remaining) + ")"

		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.modulate.a = 0.45 if done else 1.0
		_task_container.add_child(lbl)


# ── Portal Indicators ───────────────────────────────────────────────────────
func _create_enemy_portal_indicator() -> Control:
	var root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 0.9)
	bg.layout_mode = 0
	bg.offset_right = _IND_SIZE.x
	bg.offset_bottom = _IND_SIZE.y
	root.add_child(bg)

	var lbl = Label.new()
	lbl.text = "ENEMY SPAWNER"
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.layout_mode = 0
	lbl.offset_right = _IND_SIZE.x
	lbl.offset_bottom = _IND_SIZE.y
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(lbl)

	return root

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return get_viewport_rect().size / 2
	var screen_size := get_viewport_rect().size
	return screen_size / 2 + (world_pos - camera.get_screen_center_position()) * camera.zoom

func _clamp_to_screen_edge(screen_pos: Vector2, screen_size: Vector2, margin: float) -> Vector2:
	var center := screen_size / 2
	var dir := screen_pos - center
	if dir.length_squared() < 1.0:
		return center
	var half_w := screen_size.x / 2 - margin
	var half_h := screen_size.y / 2 - margin
	var scale_x := INF
	var scale_y := INF
	if dir.x > 0:
		scale_x = half_w / dir.x
	elif dir.x < 0:
		scale_x = -half_w / dir.x
	if dir.y > 0:
		scale_y = half_h / dir.y
	elif dir.y < 0:
		scale_y = -half_h / dir.y
	return center + dir * min(scale_x, scale_y)


func _update_portal_indicators() -> void:
	var screen_size := get_viewport_rect().size
	var margin := 28.0

	# sync with EnemyPortal group
	var current_portals := get_tree().get_nodes_in_group("EnemyPortal")
	for portal in current_portals:
		if not _portal_indicators.has(portal):
			var ind := _create_enemy_portal_indicator()
			add_child(ind)
			_portal_indicators[portal] = ind

	var to_erase: Array = []
	for portal in _portal_indicators:
		if not is_instance_valid(portal) or portal not in current_portals:
			_portal_indicators[portal].queue_free()
			to_erase.append(portal)
	for p in to_erase:
		_portal_indicators.erase(p)

	var inset := Rect2(Vector2(margin, margin), screen_size - Vector2(margin * 2, margin * 2))

	for portal in _portal_indicators:
		var ind: Control = _portal_indicators[portal]
		ind.size = _IND_SIZE

		var screen_pos := _world_to_screen(portal.global_position)

		# only show when off-screen
		if inset.has_point(screen_pos):
			ind.visible = false
			continue

		ind.visible = true

		var edge_pos := _clamp_to_screen_edge(screen_pos, screen_size, margin + _IND_SIZE.y / 2)
		ind.position = edge_pos - _IND_SIZE / 2

func _process(delta: float) -> void:
	_beat_timer -= delta
	if _beat_timer <= 0.0:
		_beat_frame = not _beat_frame
		_hb1.visible = not _beat_frame
		_hb2.visible = _beat_frame
		_beat_index = (_beat_index + 1) % _beat_intervals.size()
		_beat_timer = _beat_intervals[_beat_index]

	_update_portal_indicators()
	# Live-refresh task counts every frame (TaskService already polls, this just redraws)
	if TaskService.task_list.size() > 0:
		_refresh_task_panel()

func set_selected_slot(slot: int) -> void:
	for i in _wraps.size():
		if i == slot:
			_wraps[i].modulate = Color(1.0, 0.85, 0.2)
			_wraps[i].scale = Vector2(1.15, 1.15)
		else:
			_wraps[i].modulate = Color(0.4, 0.4, 0.4)
			_wraps[i].scale = Vector2(1.0, 1.0)

func set_slot_cooldown(slot: int, ratio: float) -> void:
	var cd: ColorRect = [_cd1, _cd2, _cd3, _cd4][slot]
	if ratio <= 0.01:
		cd.visible = false
		return
	cd.visible = true
	cd.anchor_top = 1.0 - ratio
	cd.anchor_bottom = 1.0
