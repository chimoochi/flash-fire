extends Node

enum EnvironmentType {
	NONE,
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

var snow_zones: Array[Dictionary] = []
var heat_zones: Array[Dictionary] = []
var is_slowed: bool = false

func _ready() -> void:
	call_deferred("_find_player")

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0]
		original_speed = player.MAX_SPEED
	else:
		await get_tree().create_timer(1.0).timeout
		_find_player()

func add_snow_zone(pos: Vector2, radius: float) -> void:
	snow_zones.append({"pos": pos, "radius": radius})

func add_heat_zone(pos: Vector2, radius: float) -> void:
	heat_zones.append({"pos": pos, "radius": radius})

func _cycle_environment() -> void:
	_exit_environment(current_environment)
	current_environment = (current_environment + 1) % EnvironmentType.size()
	_enter_environment(current_environment)

func _enter_environment(type: int) -> void:
	if not is_instance_valid(player):
		_find_player()
		return
	
	# Reset states when entering new environment if needed
	match type:
		EnvironmentType.SNOW:
			pass # Handled in physics process for zones

func _exit_environment(type: int) -> void:
	if not is_instance_valid(player): 
		return

	match type:
		EnvironmentType.SNOW:
			if player and is_slowed:
				player.MAX_SPEED = original_speed
				is_slowed = false

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
			
	match current_environment:
		EnvironmentType.SNOW:
			var in_snow_zone = false
			if snow_zones.is_empty():
				in_snow_zone = true
			else:
				for zone in snow_zones:
					if player.global_position.distance_to(zone.pos) <= zone.radius:
						in_snow_zone = true
						break
			
			if in_snow_zone:
				if not is_slowed:
					original_speed = player.MAX_SPEED # Update original speed just in case
					player.MAX_SPEED *= SNOW_SLOW_FACTOR
					is_slowed = true
			else:
				if is_slowed:
					player.MAX_SPEED = original_speed
					is_slowed = false

		EnvironmentType.HEAT:
			var in_heat_zone = false
			if heat_zones.is_empty():
				in_heat_zone = true
			else:
				for zone in heat_zones:
					if player.global_position.distance_to(zone.pos) <= zone.radius:
						in_heat_zone = true
						break
			
			if in_heat_zone and not _is_in_safe_zone():
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

