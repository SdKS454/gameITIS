extends BaseAction
class_name MeleeAttackAction

@export var damage: int = 1

func _init():
	id = "melee"
	range = 1

func get_target_cells(unit: Unit, grid: Grid, _unit_manager: UnitManager) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for n in grid.get_neighbor_coords(unit.cell):
		result.append(n)
	return result

func build_effects(unit: Unit, target_cell: Vector2i, grid: Grid, _unit_manager: UnitManager) -> Array[Dictionary]:
	if target_cell not in grid.get_neighbor_coords(unit.cell):
		return []

	return [
		{
			"type": "damage",
			"target_cell": target_cell,
			"amount": damage,
			"source": unit
		}
	]
