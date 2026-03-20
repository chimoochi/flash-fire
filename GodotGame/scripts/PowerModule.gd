class_name PowerModule

const THROWABLE_SCENE = preload("res://projectiles/throwable.tscn")

enum PowerType {RANGED, MELEE, UTILITY, SPECIAL}
static var OVERRIDE = "Shotgun"
const POWERS = {
	"Pistol": {
		"name": "Pistol",
		"type": PowerType.RANGED,
		"settings": {
			"damage": 20,
			"speed": 1500.0,
			"cooldown": 0.25,
			"range": 600.0
		}
	},
	"Wall": {
		"name": "Wall",
		"type": PowerType.UTILITY,
		"settings": {
			"cooldown": 2.0,
			"range": 200.0
		}
	},
	"Grenade": {
		"name": "Grenade",
		"type": PowerType.RANGED,
		"settings": {
			"damage": 30,
			"speed": 600.0,
			"radius": 100.0,
			"push": 1000.0,
			"cooldown": 1.5,
			"range": 500.0
		}
	},
	"Sword": {
		"name": "Sword",
		"type": PowerType.MELEE,
		"settings": {
			"damage": 25,
			"knockback": 800.0,
			"duration": 0.25,
			"cooldown": 0.5,
			"range": 80.0
		},
		"image": {
			"texture": "res://gameassets/tidepopper (1).png",
			"offset": Vector2(0, 0),
			"rotation": 45.0,
			"scale": Vector2(1, 1)
		},
		"hitbox": {
			"shape": "rectangle",
			"size": Vector2(100, 22),
			"offset": Vector2(10, 20)
		}
	},
	"Shotgun": {
		"name": "Shotgun",
		"type": PowerType.RANGED,
		"settings": {
			"damage": 20,
			"speed": 1200.0,
			"cooldown": 0.8,
			"range": 350.0,
			"spread": 10.0
		}
	},
	"Lightning": {
		"name": "Lightning",
		"type": PowerType.SPECIAL,
		"settings": {
			"cooldown": 0.25,
			"range": 700.0
		}
	}
}
const ENEMY_LEVELS = {
"level1": { 
	"basespeed":1,
	"damagemult":.3,
	"allowedweapons": [PowerType.MELEE],
	"allowedpowers": [], # empty means any (for now)
	},
"level2heavy": {
	"basespeed": .7,
	"damagemult": 1,
	"allowedweapons":[PowerType.RANGED,PowerType.SPECIAL,PowerType.UTILITY],
	"allowedpowers":[],
	
},
}

static func get_random_power() -> Dictionary:
	return get_random_power_for_level("")

static func get_random_power_for_level(level: String) -> Dictionary:
	if OVERRIDE != "" and POWERS.has(OVERRIDE):
		return POWERS[OVERRIDE]
		
	var valid_powers = []
	var allowed_weapons = []
	var allowed_powers = []
	
	if level != "" and ENEMY_LEVELS.has(level):
		var level_data = ENEMY_LEVELS[level]
		allowed_weapons = level_data.get("allowedweapons", [])
		allowed_powers = level_data.get("allowedpowers", [])
		
	for key in POWERS.keys():
		var power = POWERS[key]
		var power_allowed = true
		
		if allowed_powers.size() > 0 and not (power.name in allowed_powers):
			power_allowed = false
		if allowed_weapons.size() > 0 and not (power.type in allowed_weapons):
			power_allowed = false
			
		if power_allowed:
			valid_powers.append(power)
			
	if valid_powers.size() > 0:
		return valid_powers[randi() % valid_powers.size()]
		
	var keys = POWERS.keys()
	return POWERS[keys[randi() % keys.size()]]

static func execute_power(power: Dictionary, caller: Node2D, target: Vector2) -> void:
	var dir = (target - caller.global_position).normalized()
	
	match power.name:
		"Pistol":
			BulletService.spawn_bullet(caller, dir, power.settings.damage, power.settings.speed)
			
		"Wall":
			var wall_dir = Vector2.RIGHT.rotated(caller.rotation)
			WallPushService.spawn_wall(caller, wall_dir)
			
		"Grenade":
			var throwable = THROWABLE_SCENE.instantiate()
			caller.get_tree().root.add_child(throwable)
			throwable.direction = dir
			throwable.speed = power.settings.speed
			
			throwable.add_collision_exception_with(caller)
			
			throwable.global_position = caller.global_position + (dir * 20.0)
			
			var caller_ref = weakref(caller)
			var land_pos = await throwable.landed
			var source = caller_ref.get_ref()
			if source:
				ThrowableService.explode(
					power.settings.radius,
					land_pos,
					power.settings.damage,
					power.settings.push,
					source
				)
			
		"Sword":
			if caller.get("swing_melee"):
				caller.swing_melee.swing(
					caller,
					power.settings.damage,
					power.settings.knockback,
					power.settings.duration
				)
				
		"Shotgun":
			BulletService.spawn_shotgun(caller, dir, power.settings.damage, power.settings.speed, power.settings.spread)

		"Lightning":
			LightningService.activate(caller)
