extends CharacterBody2D

const SPEED = 600.0
const BULLET_SPEED = 1500.0
const BULLET_SCENE = preload("res://player/bullet.tscn")
@onready var melee_pivot: Node2D = $MeleePivot

var PlayerState: Dictionary = {
	"health": 100,
	"abilities": [],
	"passives": [],
	"is_alive": true
}

var is_swinging: bool = false
var can_shoot: bool = false
func _ready() -> void:
	add_to_group("Player")

func _physics_process(delta):
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("MoveRight"):
		direction.x += 1
	if Input.is_action_pressed("MoveLeft"):
		direction.x -= 1
	if Input.is_action_pressed("MoveDown"):
		direction.y += 1
	if Input.is_action_pressed("MoveUp"):
		direction.y -= 1
	
	if direction.length() > 0:
		direction = direction.normalized()
	
	velocity = direction * SPEED
	move_and_slide()
	
	look_at(get_global_mouse_position())

	if Input.is_action_just_pressed("shoot"): 
		attack()

func spawn_bullet(direction: Vector2) -> void:	
	if not can_shoot:
		return
	var bullet = BULLET_SCENE.instantiate()
	bullet.direction = direction
	bullet.speed = BULLET_SPEED
	bullet.owner_node = self  
	get_tree().root.add_child(bullet)
	bullet.global_position = global_position
	bullet.rotation = rotation


func attack() -> void:
	var shoot_dir = Vector2.RIGHT.rotated(rotation)
	spawn_bullet(shoot_dir)
	
	CameraService.shake(0.3)
	CameraService.kick(Vector2(0.05, 0.05))
	
	swing()

func swing() -> void:
	if is_swinging: # no spam
		return
		
	is_swinging = true # line 40
	var tween = create_tween()
	var start_rot = melee_pivot.rotation
	
	tween.tween_property(melee_pivot, "rotation", start_rot - PI/2, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(melee_pivot, "rotation", start_rot, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	await tween.finished
	is_swinging = false

func use_ability(ability_name: String) -> void:
	# Placeholder
	# But grab table of abilities from PlayerState, and use ability
	return
	

func transfer_abilities(enemy_killed) -> void:
	# Placeholder
	# But grab table of abilities from enemy killed, and add to PlayerState
	return

	
	#restart concurrent states, boot up new
