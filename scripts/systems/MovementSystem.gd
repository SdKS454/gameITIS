extends Node
class_name MovementSystem

@export var grid: Grid
@export var unit_manager: UnitManager
@export var battle_manager: BattleManager

func move_unit(unit: Unit, target_cell: Vector2i, on_finished: Callable = Callable(), notify_battle_manager: bool = true) -> bool:
	if not grid.is_in_bounds(target_cell):
		return false
	if unit_manager.is_occupied(target_cell):
		return false
	if not unit.can_move_this_turn():
		return false

	var path := grid.find_path(unit.cell, target_cell)
	if path.is_empty():
		return false

	var limited_path := _apply_move_limit(unit, path)
	if limited_path.is_empty():
		return false

	var start_cell := unit.cell
	unit.move_along_path(limited_path)

	unit.move_finished.connect(func(final_cell):
		unit_manager.on_unit_moved(unit, start_cell, final_cell)
		if notify_battle_manager and battle_manager != null:
			battle_manager.on_unit_move_finished()
		if on_finished.is_valid():
			on_finished.call(final_cell)
	, CONNECT_ONE_SHOT)

	return true

func _apply_move_limit(unit: Unit, path: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cost := 0

	for i in range(1, path.size()):
		result.append(path[i])
		cost += 1
		if cost >= unit.move_range:
			break

	return result

func can_move_to(unit: Unit, target_cell: Vector2i) -> bool:
	if not grid.is_in_bounds(target_cell):
		return false
	if unit.is_moving:
		return false
	if not unit.can_move_this_turn():
		return false
	var reachable := get_reachable_cells(unit)
	return target_cell in reachable

func get_reachable_cells(unit: Unit) -> Array[Vector2i]:
	var start: Vector2i = unit.cell
	var max_range: int = unit.move_range

	var visited := {}
	var result: Array[Vector2i] = []
	var queue: Array = [[start, 0]]
	visited[start] = true

	while queue.size() > 0:
		var current = queue.pop_front()
		var cell: Vector2i = current[0]
		var cost: int = current[1]
		result.append(cell)

		if cost >= max_range:
			continue

		for ncell in grid.get_neighbor_coords(cell):
			if visited.has(ncell):
				continue
			if unit_manager.is_occupied(ncell) and ncell != start:
				continue
			visited[ncell] = true
			queue.append([ncell, cost + 1])

	return result
