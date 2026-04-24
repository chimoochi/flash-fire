extends Node2D

const CHECKS_REQUIRED := 5
const SKILL_CHECK_SCRIPT = preload("res://gameplay/generator/skill_check.gd")

var _in_range: bool = false
var _open: bool = false
var _checks_done: int = 0

@onready var _hint_label: Label = $HintLabel
@onready var _ui_panel: Panel = $GeneratorCanvas/Panel
@onready var _status_label: Label = $GeneratorCanvas/Panel/VBox/StatusLabel
@onready var _skill_check: Control = $GeneratorCanvas/Panel/VBox/SkillCheck

func _ready() -> void:
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)
	_skill_check.succeeded.connect(_on_success)
	_skill_check.failed.connect(_on_fail)
	_ui_panel.visible = false
	_hint_label.visible = false
	_refresh_status()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		_in_range = true
		_hint_label.visible = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_in_range = false
		_hint_label.visible = false
		_close()

func _unhandled_input(event: InputEvent) -> void:
	if not _in_range:
		return
	if event.is_action_just_pressed("interact"):
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
		_hint_label.visible = false
		_hint_label.text = "Repaired"
		# generator complete — no gameplay effect yet

func _on_fail() -> void:
	pass  # no penalty yet

func _refresh_status() -> void:
	_status_label.text = "Progress: %d / %d" % [_checks_done, CHECKS_REQUIRED]
