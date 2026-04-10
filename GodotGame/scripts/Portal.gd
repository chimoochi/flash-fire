extends Area2D

@export_file("*.tscn") var target_map_path: String
@export var portal_label: String = "Level"

var locked: bool = false

var _entry_cooldown: float = 1.0

func _ready():
	body_entered.connect(_on_body_entered)
	_update_lock_state()

func _process(delta: float) -> void:
	if _entry_cooldown > 0:
		_entry_cooldown -= delta

func _update_lock_state() -> void:
	var level_num = _get_level_number()
	if level_num > 1 and not MapService.is_level_completed("level" + str(level_num - 1)):
		locked = true
		$Visual.color = Color(0.3, 0.3, 0.3, 0.6)
		$Label.text = portal_label + " [LOCKED]"
	else:
		locked = false
		$Visual.color = Color(0, 0.5, 1, 1)
		$Label.text = portal_label

func _get_level_number() -> int:
	var regex = RegEx.new()
	regex.compile("(\\d+)")
	var result = regex.search(portal_label)
	if result:
		return int(result.get_string())
	return 0

func _on_body_entered(body):
	if body.is_in_group("Player"):
		if locked or _entry_cooldown > 0:
			return
		if target_map_path != "":
			MapService.change_map(target_map_path)
