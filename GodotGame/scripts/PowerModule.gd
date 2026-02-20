class_name PowerModule

const THROWABLE_SCENE = preload("res://projectiles/throwable.tscn")

enum PowerType { RANGED, MELEE, UTILITY, SPECIAL }
static var OVERRIDE = ""
const POWERS = {
	"Pistol": {
		"name": "Pistol",
		"type": PowerType.RANGED,
		"settings": {
			"damage": 20,
			"speed": 1500.0,
			"cooldown": 0.5,
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
		}
	},
	"Lightning": {
		"name": "Lightning",
		"type": PowerType.SPECIAL,
		"settings": {
			"cooldown": 0.5,
			"range": 700.0
		}
	}
}

static func get_random_power() -> Dictionary:
	if OVERRIDE != "" and POWERS.has(OVERRIDE):
		return POWERS[OVERRIDE]
	var keys = POWERS.keys()
	var random_key = keys[randi() % keys.size()]
	return POWERS[random_key]

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
				
		"Lightning":
			LightningService.activate(caller)
