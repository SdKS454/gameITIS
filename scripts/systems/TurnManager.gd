extends Node
class_name TurnManager

signal phase_changed(new_phase: TurnPhase)
signal enemy_intents_updated(plans: Array[Dictionary])
signal turn_started(turn_index: int, phase: TurnPhase)
signal command_points_changed(current: int, max: int)

@export var unit_manager: UnitManager
@export var movement_system: MovementSystem
@export var effect_resolver: EffectResolver
@export var enemy_ai: EnemyAI
@export var intent_visualizer: IntentVisualizer
@export var battle_manager: BattleManager
@export var cp_max: int = 1

enum TurnPhase {
	PLAYER_TURN,
	ENEMY_EXECUTION
}

var phase: TurnPhase = TurnPhase.PLAYER_TURN
var enemy_plans: Array[Dictionary] = []
var turn_index: int = 1
var cp_current: int = 0

func _ready():
	start_battle()

func start_battle():
	_reset_player_flags()
	_reset_command_points()
	_plan_enemy_intents()
	phase = TurnPhase.PLAYER_TURN
	phase_changed.emit(phase)
	turn_started.emit(turn_index, phase)

func can_accept_player_input() -> bool:
	return phase == TurnPhase.PLAYER_TURN

func is_player_turn() -> bool:
	return phase == TurnPhase.PLAYER_TURN

func can_spend_cp(cost: int) -> bool:
	if cost <= 0:
		return true
	if phase != TurnPhase.PLAYER_TURN:
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

func end_player_turn():
	if phase != TurnPhase.PLAYER_TURN:
		return

	phase = TurnPhase.ENEMY_EXECUTION
	phase_changed.emit(phase)
	turn_started.emit(turn_index, phase)

	_execute_enemy_turn()
	_reset_player_flags()
	_plan_enemy_intents()

	turn_index += 1
	phase = TurnPhase.PLAYER_TURN
	_reset_command_points()
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
		var unit: Unit = plan.get("unit", null)
		if not _is_unit_alive(unit):
			continue

		var move_to: Vector2i = plan.get("move_to", unit.cell)
		if move_to != unit.cell and not unit_manager.is_occupied(move_to):
			var path := grid_safe_path(unit.cell, move_to)
			if not path.is_empty() and _is_unit_alive(unit):
				movement_system.move_unit_instant(unit, path)

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

func _reset_player_flags():
	for unit in unit_manager.get_units_by_team(Unit.Team.PLAYER):
		unit.reset_turn_flags()
	for unit in unit_manager.get_units_by_team(Unit.Team.ENEMY):
		unit.reset_turn_flags()

func _reset_command_points():
	cp_current = max(0, cp_max)
	command_points_changed.emit(cp_current, cp_max)

func refresh_enemy_intents_visuals():
	_sanitize_enemy_plans()
	if intent_visualizer != null:
		intent_visualizer.show_enemy_intents(enemy_plans)

func _plan_enemy_intents():
	enemy_plans = enemy_ai.plan_enemy_turn(
		unit_manager.get_units_by_team(Unit.Team.ENEMY),
		unit_manager.get_units_by_team(Unit.Team.PLAYER)
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

func grid_safe_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path := battle_manager.grid.find_path(from, to)
	if path.is_empty():
		return []
	var result: Array[Vector2i] = []
	for i in range(1, path.size()):
		result.append(path[i])
	return result
