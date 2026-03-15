extends Area2D

@export_file("*.tscn") var target_map_path: String
@export var portal_label: String = "Level"

func _ready():
	body_entered.connect(_on_body_entered)
	$Label.text = portal_label

func _on_body_entered(body):
	print("Something entered portal: ", body.name)
	if body.is_in_group("Player"):
		if target_map_path != "":
			print("Teleporting to: ", target_map_path)
			MapService.change_map(target_map_path)
