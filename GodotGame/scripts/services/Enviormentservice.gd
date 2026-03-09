extends Node

enum EnvironmentType {
	NONE,
	WIND,
	SNOW,
	HEAT,
	POISON
}

var current_environment: int = EnvironmentType.NONE

# var WIND_FORCE = Vector2(3500, 0)
const SNOW_SLOW_FACTOR = 0.5
const HEAT_DAMAGE_RATE = 5
const POISON_DAMAGE_RATE = 10

var player: CharacterBody2D = null
var original_speed: float = 0.0
var damage_accumulator: float = 0.0

# UI
var canvas_layer: CanvasLayer
var status_label: Label
var change_button: Button

func _ready() -> void:
	_setup_ui()
	call_deferred("_find_player")

func _setup_ui() -> void:
	canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	status_label = Label.new()
	status_label.text = "Environment: NONE"
	status_label.anchors_preset = Control.PRESET_TOP_RIGHT
	status_label.position = Vector2(1000, 20) 
	canvas_layer.add_child(status_label)
	
	change_button = Button.new()
	change_button.text = "Change Env"
	change_button.position = Vector2(1000, 60)
	change_button.pressed.connect(_cycle_environment)
	canvas_layer.add_child(change_button)

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0]
		original_speed = player.MAX_SPEED
	else:
		await get_tree().create_timer(1.0).timeout
		_find_player()

func _cycle_environment() -> void:
	_exit_environment(current_environment)
	current_environment = (current_environment + 1) % EnvironmentType.size()
	_enter_environment(current_environment)
	_update_label()

func _enter_environment(type: int) -> void:
	if not is_instance_valid(player):
		_find_player()
		return

	match type:
		EnvironmentType.SNOW:
			if player:
				original_speed = player.MAX_SPEED 
				player.MAX_SPEED *= SNOW_SLOW_FACTOR

func _exit_environment(type: int) -> void:
	if not is_instance_valid(player): 
		return

	match type:
		EnvironmentType.SNOW:
			if player:
				player.MAX_SPEED = original_speed

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	match current_environment:
		EnvironmentType.WIND:
			pass
		EnvironmentType.HEAT:
			if not _is_in_safe_zone():
				_apply_damage(HEAT_DAMAGE_RATE * delta)
		EnvironmentType.POISON:
			pass

func _is_in_safe_zone() -> bool:
	return false

func _apply_damage(amount: float) -> void:
	damage_accumulator += amount
	if damage_accumulator >= 1.0:
		var damage_to_deal = int(damage_accumulator)
		damage_accumulator -= damage_to_deal
		if player.has_method("take_damage"):
			player.take_damage(damage_to_deal)

func _update_label() -> void:
	status_label.text = "Environment: " + EnvironmentType.keys()[current_environment] if current_environment < EnvironmentType.keys().size() else "Unknown"
