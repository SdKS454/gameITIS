extends Node2D
class_name GridRoot

@export var camera: Camera2D
@export var grid: Grid

@export var padding_percent := 0.1

func _ready() -> void:
	call_deferred("fit_grid_to_screen")

func fit_grid_to_screen() -> void:
	if grid == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var available_size: Vector2 = viewport_size * (1.0 - padding_percent * 2.0)
	var bounds: Rect2 = grid.get_bounds()
	var grid_size: Vector2 = bounds.size
	var scale_x: float = available_size.x / grid_size.x
	var scale_y: float = available_size.y / grid_size.y
	var scale: float = min(scale_x, scale_y)
	camera.zoom = Vector2(scale, scale)
	center_on_bounds(bounds)

func center_on_bounds(bounds: Rect2) -> void:
	var center_local: Vector2 = bounds.position + bounds.size * 0.5
	camera.global_position = grid.to_global(center_local)

func center_grid() -> void:
	var center := Vector2((grid.width - 1) / 2.0, (grid.height - 1) / 2.0)
	var center_screen := IsoHelper.grid_to_screen(Vector2i(center), grid.iso_config)
	camera.global_position = grid.to_global(center_screen)

func apply_mission_preset(mission_id: int):
	mission_id = SaveManager.normalize_mission_id(mission_id)
	var unit_manager: UnitManager = get_node("UnitManager")
	var turn_manager: TurnManager = get_node("TurnManager")
	var environment_manager: EnvironmentManager = get_node("EnvironmentManager")
	unit_manager.clear_all_units()

	match mission_id:
		1:
			environment_manager.objective_cell = Vector2i(8, 1)
			environment_manager.objective_max_hp = 6
			turn_manager.cp_max = 3
			turn_manager.threat_growth_per_turn = 1
			unit_manager.spawn_unit(Vector2i(3, 3), Unit.Team.PLAYER, Unit.Archetype.STRIKER)
			unit_manager.spawn_unit(Vector2i(2, 4), Unit.Team.PLAYER, Unit.Archetype.GUARDIAN)
			unit_manager.spawn_unit(Vector2i(4, 2), Unit.Team.PLAYER, Unit.Archetype.ARTILLERY)
			unit_manager.spawn_unit(Vector2i(7, 7), Unit.Team.ENEMY, Unit.Archetype.BRUTE)
			unit_manager.spawn_unit(Vector2i(6, 8), Unit.Team.ENEMY, Unit.Archetype.RAIDER)
			unit_manager.spawn_unit(Vector2i(8, 6), Unit.Team.ENEMY, Unit.Archetype.SNIPER)
		2:
			environment_manager.objective_cell = Vector2i(1, 8)
			environment_manager.objective_max_hp = 8
			turn_manager.cp_max = 2
			turn_manager.threat_growth_per_turn = 2
			unit_manager.spawn_unit(Vector2i(1, 3), Unit.Team.PLAYER, Unit.Archetype.GUARDIAN)
			unit_manager.spawn_unit(Vector2i(2, 2), Unit.Team.PLAYER, Unit.Archetype.STRIKER)
			unit_manager.spawn_unit(Vector2i(3, 4), Unit.Team.PLAYER, Unit.Archetype.ARTILLERY)
			unit_manager.spawn_unit(Vector2i(7, 3), Unit.Team.ENEMY, Unit.Archetype.SNIPER)
			unit_manager.spawn_unit(Vector2i(7, 4), Unit.Team.ENEMY, Unit.Archetype.SNIPER)
			unit_manager.spawn_unit(Vector2i(8, 5), Unit.Team.ENEMY, Unit.Archetype.BRUTE)
		3:
			environment_manager.objective_cell = Vector2i(5, 5)
			environment_manager.objective_max_hp = 10
			turn_manager.cp_max = 4
			turn_manager.weave_uses_per_turn = 2
			unit_manager.spawn_unit(Vector2i(1, 1), Unit.Team.PLAYER, Unit.Archetype.STRIKER)
			unit_manager.spawn_unit(Vector2i(1, 2), Unit.Team.PLAYER, Unit.Archetype.GUARDIAN)
			unit_manager.spawn_unit(Vector2i(2, 1), Unit.Team.PLAYER, Unit.Archetype.ARTILLERY)
			unit_manager.spawn_unit(Vector2i(8, 8), Unit.Team.ENEMY, Unit.Archetype.BRUTE)
			unit_manager.spawn_unit(Vector2i(8, 7), Unit.Team.ENEMY, Unit.Archetype.RAIDER)
			unit_manager.spawn_unit(Vector2i(7, 8), Unit.Team.ENEMY, Unit.Archetype.RAIDER)
		4:
			environment_manager.objective_cell = Vector2i(9, 0)
			environment_manager.objective_max_hp = 4
			turn_manager.cp_max = 3
			turn_manager.threat_objective_focus_start = 1
			unit_manager.spawn_unit(Vector2i(0, 8), Unit.Team.PLAYER, Unit.Archetype.STRIKER)
			unit_manager.spawn_unit(Vector2i(0, 7), Unit.Team.PLAYER, Unit.Archetype.ARTILLERY)
			unit_manager.spawn_unit(Vector2i(1, 8), Unit.Team.PLAYER, Unit.Archetype.GUARDIAN)
			unit_manager.spawn_unit(Vector2i(6, 1), Unit.Team.ENEMY, Unit.Archetype.RAIDER)
			unit_manager.spawn_unit(Vector2i(7, 1), Unit.Team.ENEMY, Unit.Archetype.RAIDER)
			unit_manager.spawn_unit(Vector2i(8, 1), Unit.Team.ENEMY, Unit.Archetype.BRUTE)
		5:
			environment_manager.objective_cell = Vector2i(5, 0)
			environment_manager.objective_max_hp = 7
			turn_manager.cp_max = 2
			turn_manager.threat_growth_per_turn = 1
			turn_manager.weave_uses_per_turn = 1
			unit_manager.spawn_unit(Vector2i(4, 8), Unit.Team.PLAYER, Unit.Archetype.STRIKER)
			unit_manager.spawn_unit(Vector2i(5, 8), Unit.Team.PLAYER, Unit.Archetype.GUARDIAN)
			unit_manager.spawn_unit(Vector2i(6, 8), Unit.Team.PLAYER, Unit.Archetype.ARTILLERY)
			unit_manager.spawn_unit(Vector2i(3, 3), Unit.Team.ENEMY, Unit.Archetype.SNIPER)
			unit_manager.spawn_unit(Vector2i(5, 3), Unit.Team.ENEMY, Unit.Archetype.BRUTE)
			unit_manager.spawn_unit(Vector2i(7, 3), Unit.Team.ENEMY, Unit.Archetype.SNIPER)

	environment_manager.reset_state()
	turn_manager.turn_index = 1
	turn_manager.start_battle()
	grid.refresh_ownership_visuals()
