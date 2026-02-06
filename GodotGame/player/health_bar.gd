extends ProgressBar

func _ready() -> void:
	pass

func set_health(amount: int):
	value = amount
	
func add_health(amount: int):
	value = min(max_value, value + amount)
	
func remove_health(amount: int):
	value = max(min_value, value - amount)
