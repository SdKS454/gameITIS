extends Node2D
class_name GridRoot

@export var camera: Camera2D
@export var grid: Grid

@export var padding_percent := 0.1

const MISSION_CONFIG := {
	1: {
		"objective_cell": Vector2i(8, 1), "objective_hp": 6,
		"cp_max": 3, "threat_growth": 1, "threat_focus": 2, "weave_uses": 1,
		"enemy_hp_multiplier": 1.0,
		"spawns": [
			{"cell": Vector2i(3, 3), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.STRIKER},
			{"cell": Vector2i(2, 4), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.GUARDIAN},
			{"cell": Vector2i(4, 2), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.ARTILLERY},
			{"cell": Vector2i(7, 7), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.BRUTE},
			{"cell": Vector2i(6, 8), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.RAIDER},
			{"cell": Vector2i(8, 6), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.SNIPER}
		]
	},
	2: {
		"objective_cell": Vector2i(1, 8), "objective_hp": 8,
		"cp_max": 3, "threat_growth": 3, "threat_focus": 1, "weave_uses": 1,
		"enemy_hp_multiplier": 1.05,
		"spawns": [
			{"cell": Vector2i(1, 3), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.GUARDIAN},
			{"cell": Vector2i(2, 2), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.STRIKER},
			{"cell": Vector2i(3, 4), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.ARTILLERY},
			{"cell": Vector2i(7, 3), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.SNIPER},
			{"cell": Vector2i(7, 4), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.SNIPER},
			{"cell": Vector2i(8, 5), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.BRUTE},
			{"cell": Vector2i(8, 4), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.RAIDER}
		]
	},
	3: {
		"objective_cell": Vector2i(5, 5), "objective_hp": 5,
		"cp_max": 2, "threat_growth": 2, "threat_focus": 1, "weave_uses": 0,
		"enemy_hp_multiplier": 1.1,
		"spawns": [
			{"cell": Vector2i(1, 1), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.STRIKER},
			{"cell": Vector2i(1, 2), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.GUARDIAN},
			{"cell": Vector2i(2, 1), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.ARTILLERY},
			{"cell": Vector2i(8, 8), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.BRUTE},
			{"cell": Vector2i(8, 7), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.RAIDER},
			{"cell": Vector2i(7, 8), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.RAIDER},
			{"cell": Vector2i(6, 7), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.SNIPER}
		]
	},
	4: {
		"objective_cell": Vector2i(9, 0), "objective_hp": 6,
		"cp_max": 3, "threat_growth": 2, "threat_focus": 1, "weave_uses": 1,
		"enemy_hp_multiplier": 1.6,
		"spawns": [
			{"cell": Vector2i(0, 8), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.STRIKER},
			{"cell": Vector2i(0, 7), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.ARTILLERY},
			{"cell": Vector2i(1, 8), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.GUARDIAN},
			{"cell": Vector2i(7, 1), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.BRUTE},
			{"cell": Vector2i(8, 2), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.SNIPER}
		]
	},
	5: {
		"objective_cell": Vector2i(5, 0), "objective_hp": 7,
		"cp_max": 2, "threat_growth": 1, "threat_focus": 1, "weave_uses": 1,
		"enemy_hp_multiplier": 1.2,
		"spawns": [
			{"cell": Vector2i(4, 8), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.STRIKER},
			{"cell": Vector2i(5, 8), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.GUARDIAN},
			{"cell": Vector2i(6, 8), "team": Unit.Team.PLAYER, "arch": Unit.Archetype.ARTILLERY},
			{"cell": Vector2i(3, 3), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.SNIPER},
			{"cell": Vector2i(5, 3), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.BRUTE},
			{"cell": Vector2i(7, 3), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.SNIPER},
			{"cell": Vector2i(2, 5), "team": Unit.Team.ENEMY, "arch": Unit.Archetype.RAIDER}
		]
	}
}

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
	var cfg: Dictionary = MISSION_CONFIG.get(mission_id, MISSION_CONFIG[1])
	var unit_manager: UnitManager = get_node("UnitManager")
	var turn_manager: TurnManager = get_node("TurnManager")
	var environment_manager: EnvironmentManager = get_node("EnvironmentManager")
	unit_manager.clear_all_units()
	unit_manager.configure_mission_balance(cfg)
	environment_manager.objective_cell = cfg.get("objective_cell", Vector2i(8, 1))
	environment_manager.objective_max_hp = int(cfg.get("objective_hp", 6))
	turn_manager.cp_max = int(cfg.get("cp_max", 3))
	turn_manager.threat_growth_per_turn = int(cfg.get("threat_growth", 1))
	turn_manager.threat_objective_focus_start = int(cfg.get("threat_focus", 2))
	turn_manager.weave_uses_per_turn = int(cfg.get("weave_uses", 1))
	for spawn in cfg.get("spawns", []):
		unit_manager.spawn_unit(spawn.get("cell", Vector2i.ZERO), int(spawn.get("team", Unit.Team.PLAYER)), int(spawn.get("arch", Unit.Archetype.STRIKER)))

	environment_manager.reset_state()
	turn_manager.turn_index = 1
	if mission_id == 5:
		turn_manager.threat_growth_per_turn = [1, 2, 3, 2, 1][randi() % 5]
	turn_manager.start_battle()
	grid.refresh_ownership_visuals()
