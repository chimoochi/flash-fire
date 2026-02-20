class_name PassiveService
extends RefCounted

const PASSIVE_SCRIPTS = {
	"FlamingBody": "res://scripts/passive/flamingbody.gd",
	"Superspeed": "res://scripts/passive/superspeed.gd",
	"Vampirism": "res://scripts/passive/vampirism.gd"
}

static var _saved_stats: Dictionary = {}

static func get_random_passive_name() -> String:
	var keys = PASSIVE_SCRIPTS.keys()
	if keys.size() == 0:
		return ""
	return keys[randi() % keys.size()]

static func add_passive(node: Node2D, passive_name: String) -> Node:
	if not PASSIVE_SCRIPTS.has(passive_name):
		push_error("PassiveService: Unknown passive '" + passive_name + "'")
		return null

	var script_path = PASSIVE_SCRIPTS[passive_name]
	var script = load(script_path)

	if script == null:
		push_error("PassiveService: Failed to load script at " + script_path)
		return null

	var instance = script.new()
	instance.name = passive_name + "_Passive"

	if "source_node" in instance:
		instance.source_node = node

	node.add_child(instance)

	if node.has_method("on_passive_added"):
		node.on_passive_added(passive_name)

	return instance

static func remove_passive(node: Node2D, passive_name: String) -> void:
	var passive_node_name = passive_name + "_Passive"
	var instance = node.get_node_or_null(passive_node_name)

	if instance:
		instance.queue_free()

		if node.has_method("on_passive_removed"):
			node.on_passive_removed(passive_name)
	else:
		push_warning("PassiveService: No passive '" + passive_name + "' to remove.")

static func remove_all_passives(node: Node2D) -> void:
	for key in PASSIVE_SCRIPTS.keys():
		var passive_node_name = key + "_Passive"
		var instance = node.get_node_or_null(passive_node_name)
		if instance:
			instance.queue_free()
			if node.has_method("on_passive_removed"):
				node.on_passive_removed(key)

static func save_stats(instance_id: int, stats: Dictionary) -> void:
	_saved_stats[instance_id] = stats

static func revert_stats(instance_id: int) -> Dictionary:
	if _saved_stats.has(instance_id):
		var stats = _saved_stats[instance_id]
		_saved_stats.erase(instance_id)
		return stats
	return {}
