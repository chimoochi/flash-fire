extends Area2D

const FIREBALL_SHEET     = preload("res://gameassets/runtime/sprites/small-fireball.png")
const EXPLOSION_SHEET    = preload("res://gameassets/runtime/sprites/small-fireball-explosion.png")
const FIREBALL_FRAMES    = 13
const EXPLOSION_FRAMES   = 6
const FRAME_SIZE         = Vector2(87, 86)
const ANIM_FPS           = 10.0

var speed: float = 1500.0
var direction: Vector2 = Vector2.RIGHT
var max_distance: float = 2000.0
var start_position: Vector2
var owner_node: Node = null
var damage: int = 0
var hitbox_size: Vector2 = Vector2(16, 4)
var is_player_bullet: bool = false

var _dead: bool = false

func _ready() -> void:
	start_position = global_position
	var shape := $CollisionShape2D.shape as RectangleShape2D
	shape.size = hitbox_size
	if is_player_bullet:
		$ColorRect.visible = false
		var anim := _make_animated_sprite(FIREBALL_SHEET, FIREBALL_FRAMES, true)
		anim.rotation = -PI / 2.0
		add_child(anim)
		anim.play("default")
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
		var is_owner_player := owner_node.is_in_group("Player")
		var is_target_player := body.is_in_group("Player")
		var is_owner_enemy := owner_node.is_in_group("Enemy")
		var is_target_enemy := body.is_in_group("Enemy")
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

	var explosion := _make_animated_sprite(EXPLOSION_SHEET, EXPLOSION_FRAMES, false)
	explosion.global_position = global_position
	get_tree().root.add_child(explosion)
	explosion.animation_finished.connect(func(): explosion.queue_free())
	explosion.play("default")
	queue_free()

func _make_animated_sprite(sheet: Texture2D, frame_count: int, loop: bool) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()
	frames.add_animation("default")
	frames.set_animation_speed("default", ANIM_FPS)
	frames.set_animation_loop("default", loop)
	for i in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * FRAME_SIZE.x, 0, FRAME_SIZE.x, FRAME_SIZE.y)
		frames.add_frame("default", atlas)
	var anim := AnimatedSprite2D.new()
	anim.sprite_frames = frames
	return anim
