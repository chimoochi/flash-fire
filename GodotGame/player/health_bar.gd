extends ProgressBar

var health_tween: Tween

func _ready() -> void:
	pass

func set_health(amount: int):
	_animate_value(amount)
	
func add_health(amount: int):
	var target = min(max_value, value + amount)
	_animate_value(target)
	
func remove_health(amount: int):
	var target = max(min_value, value - amount)
	_animate_value(target)

func _animate_value(target_value: float) -> void:
	if health_tween:
		health_tween.kill()
	
	health_tween = create_tween()
	health_tween.tween_property(self, "value", target_value, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
