extends Node
class_name TurnManager

signal phase_changed(new_phase: TurnPhase)
signal enemy_intents_updated(plans: Array[Dictionary])
signal turn_started(turn_index: int, phase: TurnPhase)
signal command_points_changed(current: int, max: int)
signal threat_changed(level: int)
signal battle_failed(reason: String)
signal battle_won(reason: String)
signal weave_changed(uses_left: int, uses_max: int)
signal intent_weaved(from_cell: Vector2i, to_cell: Vector2i)

@export var unit_manager: UnitManager
@export var movement_system: MovementSystem
@export var effect_resolver: EffectResolver
@export var enemy_ai: EnemyAI
@export var intent_visualizer: IntentVisualizer
@export var battle_manager: BattleManager
@export var environment_manager: EnvironmentManager

@export var cp_max: int = 1
@export var threat_growth_per_turn: int = 1
@export var threat_objective_focus_start: int = 2
@export var weave_uses_per_turn: int = 1

enum TurnPhase {
	PLAYER_TURN,
	ENEMY_EXECUTION
}

var phase: TurnPhase = TurnPhase.PLAYER_TURN
var enemy_plans: Array[Dictionary] = []
var turn_index: int = 1
var cp_current: int = 0
var threat_level: int = 0
var is_battle_over: bool = false
var weave_uses_left: int = 0

func _ready():
	if environment_manager != null:
		environment_manager.objective_destroyed.connect(_on_objective_destroyed)
	start_battle()

func start_battle():
	is_battle_over = false
	threat_level = 0
	threat_changed.emit(threat_level)
	_reset_player_flags()
	_reset_command_points()
	_reset_weave_uses()
	_plan_enemy_intents()
	phase = TurnPhase.PLAYER_TURN
	phase_changed.emit(phase)
	turn_started.emit(turn_index, phase)
	_evaluate_win_condition()

func can_accept_player_input() -> bool:
	return phase == TurnPhase.PLAYER_TURN and not is_battle_over

func is_player_turn() -> bool:
	return phase == TurnPhase.PLAYER_TURN

func can_spend_cp(cost: int) -> bool:
	if cost <= 0:
		return true
	if phase != TurnPhase.PLAYER_TURN or is_battle_over:
		return false
	return cp_current >= cost

func try_spend_cp(cost: int) -> bool:
	if not can_spend_cp(cost):
		return false
	if cost <= 0:
		return true

	cp_current -= cost
	if cp_current < 0:
		cp_current = 0
	command_points_changed.emit(cp_current, cp_max)
	return true

func can_weave_intent() -> bool:
	return phase == TurnPhase.PLAYER_TURN and not is_battle_over and weave_uses_left > 0 and not enemy_plans.is_empty()

func get_weave_unavailable_reason() -> String:
	if phase != TurnPhase.PLAYER_TURN:
		return "Weave is only available during PLAYER phase"
	if is_battle_over:
		return "Battle is over"
	if weave_uses_left <= 0:
		return "No weave charges left this turn"
	if enemy_plans.is_empty():
		return "No enemy intents available"
	return ""

func get_weave_preview(cell: Vector2i) -> Dictionary:
	var result := {
		"valid": false,
		"from_cell": cell,
		"to_cell": cell,
		"reason": ""
	}

	var unavailable_reason := get_weave_unavailable_reason()
	if unavailable_reason != "":
		result["reason"] = unavailable_reason
		return result

	for plan in enemy_plans:
		var target_cell: Vector2i = plan.get("target_cell", Vector2i(-1, -1))
		if target_cell != cell:
			continue
		var to_cell := _find_weave_destination(cell)
		if to_cell == cell:
			result["reason"] = "Intent cannot shift: all adjacent cells are blocked"
			return result
		result["valid"] = true
		result["to_cell"] = to_cell
		return result

	result["reason"] = "Hover an enemy intent tile to weave"
	return result

func apply_intent_weave_at(cell: Vector2i) -> bool:
	if not can_weave_intent():
		return false

	for i in range(enemy_plans.size()):
		var plan: Dictionary = enemy_plans[i]
		if plan.get("target_cell", Vector2i(-1, -1)) != cell:
			continue

		var to_cell := _find_weave_destination(cell)
		if to_cell == cell:
			return false

		plan["target_cell"] = to_cell
		plan["preview_cells"] = [to_cell]
		enemy_plans[i] = plan
		weave_uses_left -= 1
		weave_changed.emit(weave_uses_left, weave_uses_per_turn)
		intent_weaved.emit(cell, to_cell)
		refresh_enemy_intents_visuals()
		enemy_intents_updated.emit(enemy_plans)
		return true

	return false

func _find_weave_destination(from_cell: Vector2i) -> Vector2i:
	for n in battle_manager.grid.get_neighbor_coords(from_cell):
		if not battle_manager.grid.is_in_bounds(n):
			continue
		if unit_manager.is_occupied(n):
			continue
		if environment_manager != null and environment_manager.is_objective_at(n):
			continue
		return n
	return from_cell

func end_player_turn():
	if phase != TurnPhase.PLAYER_TURN or is_battle_over:
		return

	phase = TurnPhase.ENEMY_EXECUTION
	phase_changed.emit(phase)
	turn_started.emit(turn_index, phase)

	await _execute_enemy_turn()
	if is_battle_over:
		return

	_reset_player_flags()
	_increase_threat()
	_plan_enemy_intents()

	turn_index += 1
	phase = TurnPhase.PLAYER_TURN
	_reset_command_points()
	_reset_weave_uses()
	phase_changed.emit(phase)
	turn_started.emit(turn_index, phase)

func notify_player_unit_finished(_unit: Unit):
	if not _all_player_units_spent():
		return
	end_player_turn()

func _all_player_units_spent() -> bool:
	var players := unit_manager.get_units_by_team(Unit.Team.PLAYER)
	if players.is_empty():
		return false

	for u in players:
		if u.is_dead():
			continue
		if not u.has_acted_this_turn:
			return false
	return true

func _execute_enemy_turn():
	_sanitize_enemy_plans()

	for plan in enemy_plans:
		if is_battle_over:
			return

		var unit: Unit = plan.get("unit", null)
		if not _is_unit_alive(unit):
			continue

		var move_to: Vector2i = plan.get("move_to", unit.cell)
		if move_to != unit.cell and not unit_manager.is_occupied(move_to):
			var moved := movement_system.move_unit(unit, move_to, Callable(), false)
			if moved:
				await unit.move_finished

		if not _is_unit_alive(unit):
			continue

		var action: BaseAction = plan.get("action", null)
		var target_cell: Vector2i = plan.get("target_cell", unit.cell)
		if action == null or not unit.can_act_this_turn():
			continue

		var effects := action.build_effects(unit, target_cell, battle_manager.grid, unit_manager)
		if effects.is_empty():
			continue

		effect_resolver.resolve_effects(effects)
		if _is_unit_alive(unit):
			unit.has_acted_this_turn = true

	unit_manager.cleanup_dead_units()
	_sanitize_enemy_plans()
	_evaluate_win_condition()

func _reset_player_flags():
	for unit in unit_manager.get_units_by_team(Unit.Team.PLAYER):
		unit.reset_turn_flags()
	for unit in unit_manager.get_units_by_team(Unit.Team.ENEMY):
		unit.reset_turn_flags()

func _reset_command_points():
	cp_current = max(0, cp_max)
	command_points_changed.emit(cp_current, cp_max)

func _reset_weave_uses():
	weave_uses_left = max(0, weave_uses_per_turn)
	weave_changed.emit(weave_uses_left, weave_uses_per_turn)

func _increase_threat():
	threat_level += max(0, threat_growth_per_turn)
	threat_changed.emit(threat_level)

func refresh_enemy_intents_visuals():
	_sanitize_enemy_plans()
	if intent_visualizer != null:
		intent_visualizer.show_enemy_intents(enemy_plans)

func _plan_enemy_intents():
	var objective_state := {
		"cell": Vector2i(-1, -1),
		"hp": 0,
		"max_hp": 0,
		"alive": false
	}
	if environment_manager != null:
		objective_state = environment_manager.get_objective_state()

	enemy_plans = enemy_ai.plan_enemy_turn(
		unit_manager.get_units_by_team(Unit.Team.ENEMY),
		unit_manager.get_units_by_team(Unit.Team.PLAYER),
		objective_state,
		threat_level,
		threat_objective_focus_start
	)
	_sanitize_enemy_plans()
	if intent_visualizer != null:
		intent_visualizer.show_enemy_intents(enemy_plans)
	enemy_intents_updated.emit(enemy_plans)

func _sanitize_enemy_plans():
	var filtered: Array[Dictionary] = []
	for plan in enemy_plans:
		var unit: Unit = plan.get("unit", null)
		if _is_unit_alive(unit):
			filtered.append(plan)
	enemy_plans = filtered

func _is_unit_alive(unit: Unit) -> bool:
	return unit != null and is_instance_valid(unit) and not unit.is_queued_for_deletion() and not unit.is_dead()

func _on_objective_destroyed(_cell: Vector2i):
	if is_battle_over:
		return
	is_battle_over = true
	phase_changed.emit(phase)
	battle_failed.emit("Objective destroyed")

func evaluate_battle_state():
	_evaluate_win_condition()

func _evaluate_win_condition():
	if is_battle_over:
		return
	if unit_manager.get_units_by_team(Unit.Team.ENEMY).is_empty():
		is_battle_over = true
		phase_changed.emit(phase)
		battle_won.emit("All enemies eliminated")

func grid_safe_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path := battle_manager.grid.find_path(from, to)
	if path.is_empty():
		return []
	var result: Array[Vector2i] = []
	for i in range(1, path.size()):
		result.append(path[i])
	return result
