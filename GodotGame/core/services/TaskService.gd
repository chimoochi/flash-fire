extends Node


signal tasks_changed

var task_list: Array = []

var _definitions: Array = []

func set_tasks(defs: Array) -> void:
	_definitions = defs.duplicate(true)
	_refresh()
	tasks_changed.emit()

func clear_tasks() -> void:
	_definitions = []
	task_list = []
	tasks_changed.emit()

func _process(_delta: float) -> void:
	if _definitions.is_empty():
		return
	_refresh()

func _refresh() -> void:
	var tree := get_tree()
	if not tree:
		return
	var changed := false
	var new_list: Array = []

	for def in _definitions:
		var entry: Dictionary = (def as Dictionary).duplicate(true)
		match def.get("type", "static"):
			"count_group":
				var grp: String = def.get("group", "")
				var count := tree.get_nodes_in_group(grp).size() if grp != "" else 0
				var prev = entry.get("remaining", -1)
				entry["remaining"] = count
				entry["done"] = count == 0
				if prev != count:
					changed = true
			"static":
				entry["remaining"] = -1
				entry["done"] = def.get("done", false)
		new_list.append(entry)

	task_list = new_list
	if changed:
		tasks_changed.emit()
