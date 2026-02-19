extends Area2D
class_name WallPush

@export var SPEED := 400.0
@export var PUSH_FORCE := 3000.0
@export var LIFETIME := 2.0

var direction = Vector2.RIGHT

func _ready():
	var timer = get_tree().create_timer(LIFETIME)
	timer.timeout.connect(queue_free)
	
	var tween = create_tween()
	tween.tween_property(self, "scale:y", 0.0, LIFETIME)

@export var DAMAGE := 10
var owner_node: Node = null

var hit_cooldowns: Dictionary = {}
const DAMAGE_INTERVAL := 0.5 

func _physics_process(delta):
	var forward = Vector2.RIGHT.rotated(rotation)
	var bodies = get_overlapping_bodies()
	var blocked = false
	
	for body in bodies:
		if body is TileMap or body is StaticBody2D:
			blocked = true
			break
	
	if not blocked:
		position += forward * SPEED * delta
		
	var now = Time.get_ticks_msec()
	var new_cooldowns = {}
	for id in hit_cooldowns:
		if now < hit_cooldowns[id]:
			new_cooldowns[id] = hit_cooldowns[id]
	hit_cooldowns = new_cooldowns

	for body in bodies:
		if body == self:
			continue
		
		if owner_node:
			var is_owner_player = owner_node.is_in_group("Player")
			var is_target_player = body.is_in_group("Player")
			var is_owner_enemy = owner_node.is_in_group("Enemy")
			var is_target_enemy = body.is_in_group("Enemy")
			
			if is_owner_player and is_target_player: continue
			if is_owner_enemy and is_target_enemy: continue
			
		
		if body.has_method("push"):
			body.push(forward * PUSH_FORCE)
			
		if body.has_method("take_damage"):
			# Debounce check
			var id = body.get_instance_id()
			if not hit_cooldowns.has(id):
				body.take_damage(DAMAGE, position)
				hit_cooldowns[id] = now + (DAMAGE_INTERVAL * 1000)
