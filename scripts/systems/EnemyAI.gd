extends Node
class_name EnemyAI

@export var grid: Grid
@export var unit_manager: UnitManager
@export var objective_focus_radius: int = 6

func plan_enemy_turn(
	enemy_units: Array[Unit],
	player_units: Array[Unit],
	objective_state: Dictionary,
	threat_level: int,
	focus_threshold: int
) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	for enemy in enemy_units:
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead():
			continue
		var plan := _build_plan_for_enemy(enemy, player_units, objective_state, threat_level, focus_threshold)
		plans.append(plan)
	return plans

func _build_plan_for_enemy(
	enemy: Unit,
	player_units: Array[Unit],
	objective_state: Dictionary,
	threat_level: int,
	focus_threshold: int
) -> Dictionary:
	var target_cell := enemy.cell
	var target_mode := "idle"

	if enemy.archetype == Unit.Archetype.GUARDIAN or _should_focus_objective(enemy, objective_state, player_units, threat_level, focus_threshold):
		target_cell = objective_state.get("cell", enemy.cell)
		target_mode = "objective"
	elif not player_units.is_empty():
		var target_player := _pick_target_player(enemy, player_units)
		target_cell = target_player.cell
		target_mode = "player"

	var stop_before_target := target_mode == "objective"
	var move_to := _pick_move_cell(enemy, target_cell, stop_before_target)
	var action_target := _pick_action_target(enemy, move_to, target_cell, target_mode)

	var preview := _build_preview_cells(action_target)

	return {
		"unit": enemy,
		"move_to": move_to,
		"action": enemy.action,
		"target_cell": action_target,
		"preview_cells": preview,
		"target_mode": target_mode
	}

func _pick_target_player(enemy: Unit, player_units: Array[Unit]) -> Unit:
	if enemy.archetype == Unit.Archetype.SNIPER:
		return _find_farthest(enemy, player_units)
	return _find_closest(enemy, player_units)

func _pick_action_target(enemy: Unit, move_to: Vector2i, preferred_target: Vector2i, target_mode: String) -> Vector2i:
	if enemy.action == null:
		return move_to

	var candidates: Array[Vector2i] = []
	var original_cell := enemy.cell
	enemy.cell = move_to
	var raw_targets := enemy.action.get_target_cells(enemy, grid, unit_manager)
	for c in raw_targets:
		if grid.is_in_bounds(c):
			candidates.append(c)
	enemy.cell = original_cell

	if candidates.is_empty():
		if target_mode == "objective":
			return preferred_target
		return move_to

	var best := candidates[0]
	var best_dist := best.distance_to(preferred_target)
	for c in candidates:
		var d := c.distance_to(preferred_target)
		if d < best_dist:
			best = c
			best_dist = d
	return best

func _should_focus_objective(
	enemy: Unit,
	objective_state: Dictionary,
	player_units: Array[Unit],
	threat_level: int,
	focus_threshold: int
) -> bool:
	if threat_level < focus_threshold:
		return false
	if not objective_state.get("alive", false):
		return false

	var objective_cell: Vector2i = objective_state.get("cell", enemy.cell)
	var objective_dist := int(enemy.cell.distance_to(objective_cell))
	if objective_dist > objective_focus_radius:
		return false

	if player_units.is_empty():
		return true

	var closest_player := _find_closest(enemy, player_units)
	var player_dist := int(enemy.cell.distance_to(closest_player.cell))
	return objective_dist <= player_dist + 2

func _pick_move_cell(enemy: Unit, target_cell: Vector2i, stop_before_target: bool) -> Vector2i:
	var path := grid.find_path(enemy.cell, target_cell)
	if path.size() <= 1:
		return enemy.cell

	var max_step = min(enemy.move_range, path.size() - 1)
	if stop_before_target:
		max_step = min(max_step, path.size() - 2)
	if max_step <= 0:
		return enemy.cell

	var best := enemy.cell
	for step in range(1, max_step + 1):
		var candidate := path[step]
		if unit_manager.is_occupied(candidate) and candidate != enemy.cell:
			break
		best = candidate

	return best

func _build_preview_cells(target_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if grid.is_in_bounds(target_cell):
		result.append(target_cell)
	return result

func _find_closest(from_unit: Unit, units: Array[Unit]) -> Unit:
	var best := units[0]
	var best_dist := from_unit.cell.distance_to(best.cell)
	for u in units:
		if u == null or not is_instance_valid(u) or u.is_dead():
			continue
		var d := from_unit.cell.distance_to(u.cell)
		if d < best_dist:
			best = u
			best_dist = d
	return best

func _find_farthest(from_unit: Unit, units: Array[Unit]) -> Unit:
	var best := units[0]
	var best_dist := from_unit.cell.distance_to(best.cell)
	for u in units:
		if u == null or not is_instance_valid(u) or u.is_dead():
			continue
		var d := from_unit.cell.distance_to(u.cell)
		if d > best_dist:
			best = u
			best_dist = d
	return best

func _best_step_towards(from_cell: Vector2i, to_cell: Vector2i) -> Vector2i:
	var dir := to_cell - from_cell
	if abs(dir.x) > abs(dir.y):
		return Vector2i(signi(dir.x), 0)
	if dir.y != 0:
		return Vector2i(0, signi(dir.y))
	return Vector2i.ZERO
