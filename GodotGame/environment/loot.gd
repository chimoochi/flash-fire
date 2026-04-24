extends Area2D

enum LootType {SCRAP, HEALTH}

@export var type: LootType = LootType.SCRAP
@export var amount: int = 1

func _ready() -> void:
	match type:
		LootType.SCRAP:
			var visual = ColorRect.new()
			visual.size = Vector2(10, 10)
			visual.position = -visual.size / 2
			visual.color = Color.YELLOW
			add_child(visual)
		LootType.HEALTH:
			var sprite = Sprite2D.new()
			sprite.texture = load("res://gameassets/runtime/sprites/Bandage.png")
			sprite.scale = Vector2(0.15, 0.15)
			add_child(sprite)
	
	body_entered.connect(_on_body_entered)
	
	# Animate a bit
	var tween = create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.5)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if type == LootType.HEALTH:
			if body.has_method("heal"):
				body.heal(amount)
			elif "PlayerState" in body:
				body.PlayerState["health"] = min(body.PlayerState["health"] + amount, body.PlayerState["max_health"])
				if body.health_bar:
					body.health_bar.set_health(body.PlayerState["health"])
		else:
			if body.has_method("add_scrap"):
				body.add_scrap(amount)
			elif "PlayerState" in body:
				body.PlayerState["scrap"] = body.PlayerState.get("scrap", 0) + amount
				if body.has_method("_update_scrap_ui"):
					body._update_scrap_ui()
		
		queue_free()
