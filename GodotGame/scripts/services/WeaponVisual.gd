class_name WeaponVisual
extends Node2D

var _sprite: Sprite2D = null
static func attach(
	parent: Node2D,
	texture: Texture2D,
	offset: Vector2 = Vector2.ZERO,
	rotation_deg: float = 0.0,
	img_scale: Vector2 = Vector2(1, 1)
) -> WeaponVisual:
	var vis = WeaponVisual.new()
	parent.add_child(vis)

	vis._sprite = Sprite2D.new()
	vis._sprite.texture = texture
	vis._sprite.position = offset
	vis._sprite.rotation_degrees = rotation_deg
	vis._sprite.scale = img_scale
	vis.add_child(vis._sprite)

	return vis

static func attach_from_config(parent: Node2D, image_config: Dictionary) -> WeaponVisual:
	var tex_path: String = image_config.get("texture", "")
	if tex_path == "":
		return null

	var texture: Texture2D = load(tex_path)
	if texture == null:
		return null

	return attach(
		parent,
		texture,
		image_config.get("offset", Vector2.ZERO),
		image_config.get("rotation", 0.0),
		image_config.get("scale", Vector2(1, 1))
	)

func set_offset(offset: Vector2) -> void:
	if _sprite:
		_sprite.position = offset

func set_rotation_deg(deg: float) -> void:
	if _sprite:
		_sprite.rotation_degrees = deg

func set_image_scale(s: Vector2) -> void:
	if _sprite:
		_sprite.scale = s

func set_texture(tex: Texture2D) -> void:
	if _sprite:
		_sprite.texture = tex
        
func remove() -> void:
	queue_free()
