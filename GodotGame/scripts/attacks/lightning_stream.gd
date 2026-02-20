extends Node

const TICK_INTERVAL := 0.12
const STREAM_DAMAGE := 5
const STREAM_RANGE := 300.0
const HIT_RADIUS := 30.0
const CHAIN_CHANCE := 0.3
const CHAIN_RANGE := 250.0
const CHAIN_MAX_TARGETS := 1
const FREEZE_DURATION := 0.4

var source_node: Node2D
var _timer: float = 0.0
var _active: bool = false

func start(caller: Node2D) -> void:
	source_node = caller
	_active = true
	_timer = 0.0
	_fire()

func stop() -> void:
	_active = false

func _physics_process(delta: float) -> void:
	if not _active:
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = TICK_INTERVAL
		_fire()

func _fire() -> void:
	if not is_instance_valid(source_node):
		_active = false
		return

	var parent = source_node.get_parent()
	var origin = source_node.global_position
	var mouse_pos = source_node.get_global_mouse_position()

	var aim_dir = (mouse_pos - origin).normalized()
	var aim_dist = min(origin.distance_to(mouse_pos), STREAM_RANGE)
	var bolt_end = origin + aim_dir * aim_dist

	var jitter = Vector2(randf_range(-8, 8), randf_range(-8, 8))
	bolt_end += jitter

	LightningService.create_bolt(parent, origin, bolt_end, 2.5, 8, 15.0, 0.1)

	var spray_jitter = randf_range(-0.3, 0.3)
	var spray_len = randf_range(aim_dist * 0.4, aim_dist * 0.9)
	var spray_end = origin + aim_dir.rotated(spray_jitter) * spray_len
	LightningService.create_bolt(parent, origin, spray_end, 1.2, 6, 12.0, 0.08)

	var tree = source_node.get_tree()
	var target_group = "Enemy"
	if source_node.is_in_group("Enemy"):
		target_group = "Player"

	var targets = tree.get_nodes_in_group(target_group)
	var hit_targets: Array = []

	for t in targets:
		if not is_instance_valid(t):
			continue
		if _dist_to_line(t.global_position, origin, bolt_end) <= HIT_RADIUS:
			hit_targets.append(t)

	for hit_target in hit_targets:
		if hit_target.has_method("take_damage"):
			hit_target.take_damage(STREAM_DAMAGE, origin, source_node if is_instance_valid(source_node) else null)

		if hit_target.has_method("stun"):
			hit_target.stun(FREEZE_DURATION)

		if randf() < CHAIN_CHANCE:
			_do_chain(hit_target, targets, parent)

func _dist_to_line(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var len_sq = line_vec.length_squared()
	if len_sq == 0.0:
		return point.distance_to(line_start)
	var t = clamp((point - line_start).dot(line_vec) / len_sq, 0.0, 1.0)
	var projection = line_start + line_vec * t
	return point.distance_to(projection)

func _do_chain(start_target: Node2D, all_targets: Array, parent: Node) -> void:
	var hit = [start_target]
	var current_pos = start_target.global_position

	for i in range(CHAIN_MAX_TARGETS):
		var best = null
		var best_dist = INF

		for t in all_targets:
			if not is_instance_valid(t):
				continue
			if t in hit:
				continue
			var dist = current_pos.distance_to(t.global_position)
			if dist > CHAIN_RANGE:
				continue
			if dist < best_dist:
				best_dist = dist
				best = t

		if not best:
			break

		LightningService.create_bolt(parent, current_pos, best.global_position, 1.8, 6, 12.0, 0.1)

		if best.has_method("take_damage"):
			best.take_damage(STREAM_DAMAGE, current_pos, source_node if is_instance_valid(source_node) else null)

		if best.has_method("stun"):
			best.stun(FREEZE_DURATION)

		hit.append(best)
		current_pos = best.global_position
