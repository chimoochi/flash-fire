class_name EnemyMetadata

const ENEMY_LEVELS = {
	"fire": {
		"basespeed": 1.0,
		"damagemult": 1.0,
		"allowed_weapons": [],
		"allowed_powers": ["Fireball"],
		"drops": [
			{"type": "scrap", "chance": 0.8, "min": 1, "max": 3},
			{"type": "health", "chance": 1.0, "amount": 10}
		]
	},
	"fire_weak": {
		"basespeed": 1.05,
		"damagemult": 1.0,
		"allowed_weapons": [],
		"allowed_powers": [],
		"drops": [
			{"type": "scrap", "chance": 0.8, "min": 1, "max": 3},
			{"type": "health", "chance": 0.45, "amount": 10}
		]
	},
	"fire_heavy": {
		"basespeed": 0.85,
		"damagemult": 1.0,
		"allowed_weapons": [],
		"allowed_powers": [],
		"drops": [
			{"type": "scrap", "chance": 0.95, "min": 2, "max": 6},
			{"type": "health", "chance": 0.6, "amount": 15}
		]
	},
	"ice_brute": {
		"basespeed": 0.7,
		"damagemult": 1.0,
		"allowed_weapons": [0, 1, 2, 3], # All types
		"allowed_powers": [],
		"drops": [
			{"type": "scrap", "chance": 1.0, "min": 5, "max": 10},
			{"type": "health", "chance": 1.0, "amount": 10}
		]
	},
	"heavy_ice": {
		"basespeed": 0.9,
		"damagemult": 1.0,
		"allowed_weapons": [],
		"allowed_powers": [],
		"drops": [
			{"type": "scrap", "chance": 0.9, "min": 2, "max": 5},
			{"type": "health", "chance": 0.6, "amount": 15}
		]
	},
	"weak_ice": {
		"basespeed": 0.9,
		"damagemult": 1.0,
		"allowed_weapons": [],
		"allowed_powers": [],
		"drops": [
			{"type": "scrap", "chance": 0.9, "min": 2, "max": 5},
			{"type": "health", "chance": 0.6, "amount": 15}
		]
	}
}
