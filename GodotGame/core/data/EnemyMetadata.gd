class_name EnemyMetadata

const ENEMY_LEVELS = {
	"level1": {
		"basespeed": 1.0,
		"damagemult": 1.0,
		"allowed_weapons": [],
		"allowed_powers": ["Fireball"],
		"drops": [
			{"type": "scrap", "chance": 0.8, "min": 1, "max": 3},
			{"type": "health", "chance": 1.0, "amount": 10}
		]
	},
	"level2heavy": {
		"basespeed": 0.7,
		"damagemult": 1.0,
		"allowed_weapons": [0, 1, 2, 3], # All types
		"allowed_powers": [],
		"drops": [
			{"type": "scrap", "chance": 1.0, "min": 5, "max": 10},
			{"type": "health", "chance": 1.0, "amount": 10}
		]
	},
	"level2water": {
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
