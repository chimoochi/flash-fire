extends Area2D

const FIREBALL_GIF = preload("res://gameassets/runtime/small-fireball.gif")
const FIREBALL_EXPLOSION_GIF = preload("res://gameassets/runtime/small-fireball-explosion.gif")

var speed: float = 1500.0
var direction: Vector2 = Vector2.RIGHT
var max_distance: float = 2000.0
var start_position: Vector2
var owner_node: Node = null
var damage: int = 0
var hitbox_size: Vector2 = Vector2(16, 4)
var is_player_bullet: bool = false

var _fireball_sprite: Sprite2D = null
var _dead: bool = false

func _ready() -> void:
	start_position = global_position
	var shape := $CollisionShape2D.shape as RectangleShape2D
	shape.size = hitbox_size
	if is_player_bullet:
		$ColorRect.visible = false
		_fireball_sprite = Sprite2D.new()
		_fireball_sprite.texture = FIREBALL_GIF
		add_child(_fireball_sprite)
	else:
		var rect := $ColorRect as ColorRect
		rect.size = hitbox_size
		rect.position = -hitbox_size / 2.0
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if global_position.distance_to(start_position) > max_distance:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body == owner_node:
		return
	if body.is_in_group("Projectiles"):
		return

	if owner_node:
		var is_owner_player = owner_node.is_in_group("Player")
		var is_target_player = body.is_in_group("Player")
		var is_owner_enemy = owner_node.is_in_group("Enemy")
		var is_target_enemy = body.is_in_group("Enemy")

		if is_owner_player and is_target_player:
			return
		if is_owner_enemy and is_target_enemy:
			return

	if body.has_method("take_damage"):
		body.take_damage(damage, start_position, owner_node if is_instance_valid(owner_node) else null)

	if is_player_bullet:
		_explode()
	else:
		queue_free()

func _explode() -> void:
	if _dead:
		return
	_dead = true
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	visible = false

	var explosion := Sprite2D.new()
	explosion.texture = FIREBALL_EXPLOSION_GIF
	explosion.global_position = global_position
	get_tree().root.add_child(explosion)

	var anim_tex := FIREBALL_EXPLOSION_GIF as AnimatedTexture
	var duration := float(anim_tex.frames) / anim_tex.fps if anim_tex and anim_tex.fps > 0 else 0.6
	await get_tree().create_timer(duration).timeout
	explosion.queue_free()
	queue_free()
