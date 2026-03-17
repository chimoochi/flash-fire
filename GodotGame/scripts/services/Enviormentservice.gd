extends Node

enum EnvironmentType {
	NONE,
	WIND,
	SNOW,
	HEAT,
	POISON
}

var current_environment: int = EnvironmentType.NONE


const SNOW_SLOW_FACTOR = 0.5

const HEAT_TIME_TO_KILL = 30.0 
const DAMAGE_REDUCTION_FACTOR = 0.6


const POISON_MAX_STACKS = 10
const POISON_DURATION = 10.0
const POISON_DAMAGE_PERCENT = 0.01 

var player: CharacterBody2D = null
var original_speed: float = 0.0
var damage_accumulator: float = 0.0

var poison_stacks: int = 0
var poison_timer: float = 0.0
var poison_env_timer: float = 0.0 

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

	if poison_stacks > 0:
		poison_timer -= delta
		if poison_timer <= 0:
			poison_stacks = 0
		else:
			var max_hp = player.PlayerState.get("max_health", 100)
			var poison_raw_dps = (max_hp * POISON_DAMAGE_PERCENT * poison_stacks) / DAMAGE_REDUCTION_FACTOR
			_apply_damage(poison_raw_dps * delta)
			
	_update_label()

	match current_environment:
		EnvironmentType.WIND:
			pass
		EnvironmentType.HEAT:
			if not _is_in_safe_zone():
				var max_hp = player.PlayerState.get("max_health", 100)
				var heat_raw_dps = (max_hp / HEAT_TIME_TO_KILL) / DAMAGE_REDUCTION_FACTOR
				_apply_damage(heat_raw_dps * delta)
		EnvironmentType.POISON:
			poison_env_timer -= delta
			if poison_env_timer <= 0:
				add_poison_stack()
				poison_env_timer = 1.0 

func add_poison_stack() -> void:
	poison_stacks = min(poison_stacks + 1, POISON_MAX_STACKS)
	poison_timer = POISON_DURATION

func _is_in_safe_zone() -> bool:
	return false

func _apply_damage(amount: float) -> void:
	damage_accumulator += amount
	if damage_accumulator >= 2.0:
		var damage_to_deal = int(damage_accumulator)
		damage_accumulator -= damage_to_deal
		if player.has_method("take_damage"):
			player.take_damage(damage_to_deal)

func _update_label() -> void:
	var text = "Environment: " + EnvironmentType.keys()[current_environment] if current_environment < EnvironmentType.keys().size() else "Unknown"
	if poison_stacks > 0:
		text += "\nPoison: " + str(poison_stacks) + " (" + ("%.1f" % poison_timer) + "s)"
	status_label.text = text
