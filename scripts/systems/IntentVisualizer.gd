extends Node
class_name IntentVisualizer

@export var grid: Grid

func show_enemy_intents(plans: Array[Dictionary]):
	var cells: Array[Vector2i] = []
	for plan in plans:
		for c in plan.get("preview_cells", []):
			if c not in cells:
				cells.append(c)
	grid.clear_intents()
	grid.show_intents(cells)

func clear():
	grid.clear_intents()
