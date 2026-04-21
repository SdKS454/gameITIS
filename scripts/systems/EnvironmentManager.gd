extends Node
class_name EnvironmentManager

signal objective_updated(current_hp: int, max_hp: int, cell: Vector2i)
signal objective_destroyed(cell: Vector2i)

@export var grid: Grid
@export var objective_marker: Node2D
@export var objective_cell: Vector2i = Vector2i(8, 1)
@export var objective_max_hp: int = 6

var objects: Dictionary = {}
var objective_hp: int = 0

func _ready():
	objective_hp = objective_max_hp
	_refresh_objective_marker()
	objective_updated.emit(objective_hp, objective_max_hp, objective_cell)

func is_environment_at(cell: Vector2i) -> bool:
	return objects.has(cell) or is_objective_at(cell)

func is_objective_at(cell: Vector2i) -> bool:
	return cell == objective_cell and objective_hp > 0

func is_objective_alive() -> bool:
	return objective_hp > 0

func damage_environment(cell: Vector2i, amount: int):
	if amount <= 0:
		return

	if is_objective_at(cell):
		damage_objective(amount)
		return

	if not objects.has(cell):
		return

	objects[cell] -= amount
	if objects[cell] <= 0:
		objects.erase(cell)

func damage_objective(amount: int):
	if amount <= 0 or objective_hp <= 0:
		return

	objective_hp = max(0, objective_hp - amount)
	objective_updated.emit(objective_hp, objective_max_hp, objective_cell)
	_refresh_objective_marker()

	if objective_hp <= 0:
		objective_destroyed.emit(objective_cell)

func get_objective_state() -> Dictionary:
	return {
		"cell": objective_cell,
		"hp": objective_hp,
		"max_hp": objective_max_hp,
		"alive": objective_hp > 0
	}

func _refresh_objective_marker():
	if objective_marker == null:
		return
	objective_marker.visible = objective_hp > 0
	if not objective_marker.visible or grid == null:
		return
	var tile := grid.get_tile(objective_cell)
	if tile != null:
		objective_marker.position = tile.position
