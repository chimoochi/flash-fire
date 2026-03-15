extends EnemyBase

const SPLIT_COUNT = 3
const LEVEL1_SCENE = preload("res://enemy/level1.tscn")

func _init() -> void:
	enemy_level = "level1"

func _ready() -> void:
	super._ready()
	equipped_power = PowerModule.POWERS["Sword"].duplicate(true)
	EnemyState["Weapon_type"] = PowerModule.PowerType.MELEE
	EnemyState["health"] = 180
	EnemyState["max_health"] = 180
	if health_bar:
		health_bar.max_value = 180
		health_bar.value = 180
	modulate = Color(0.3, 1.0, 0.4)

func die() -> void:
	EnemyState["is_alive"] = false

	for i in range(SPLIT_COUNT):
		var child = LEVEL1_SCENE.instantiate()
		get_tree().root.add_child(child)
		var angle = (TAU / SPLIT_COUNT) * i
		child.global_position = global_position + Vector2.RIGHT.rotated(angle) * 30.0

	if is_instance_valid(_last_damage_source) and _last_damage_source.is_in_group("Player"):
		killed_by_player.emit(equipped_power, equipped_passive)

	queue_free()
