extends Node
class_name BattleManager

signal player_action_committed(unit: Unit, target_cell: Vector2i, action_id: String)
signal player_action_denied(unit: Unit, reason: String)
signal player_unit_selected(unit: Unit)

@export var unit_manager: UnitManager
@export var movement_system: MovementSystem
@export var grid: Grid
@export var turn_manager: TurnManager
@export var effect_resolver: EffectResolver

enum BattleState {
	IDLE,
	UNIT_SELECTED,
	UNIT_MOVING,
	WAITING_FOR_ACTION
}

var state: BattleState = BattleState.IDLE
var selected_unit: Unit = null
var reachable_cells: Array[Vector2i] = []
var action_cells: Array[Vector2i] = []

func select_at(cell: Vector2i):
	if turn_manager != null and not turn_manager.can_accept_player_input():
		return

	var clicked_unit := unit_manager.get_unit_at(cell)
	if clicked_unit != null and clicked_unit.team == Unit.Team.PLAYER:
		select_unit(clicked_unit)
		return

	if selected_unit == null:
		return

	if state == BattleState.UNIT_SELECTED:
		if cell in action_cells:
			state = BattleState.WAITING_FOR_ACTION
			try_action_command(cell)
			return
		if try_move_command(cell):
			return

	if state == BattleState.WAITING_FOR_ACTION:
		try_action_command(cell)

func select_unit(unit: Unit):
	if unit.team != Unit.Team.PLAYER:
		return
	if unit.has_moved_this_turn and unit.has_acted_this_turn:
		return

	selected_unit = unit
	state = BattleState.UNIT_SELECTED
	player_unit_selected.emit(unit)
	refresh_selection()

func refresh_selection():
	grid.clear_all_highlights()
	if turn_manager != null:
		turn_manager.refresh_enemy_intents_visuals()

	if selected_unit == null:
		return

	if selected_unit.can_move_this_turn():
		reachable_cells = movement_system.get_reachable_cells(selected_unit)
		grid.show_reachable(reachable_cells)
	else:
		reachable_cells.clear()

	action_cells = get_action_cells(selected_unit)
	grid.show_action_targets(action_cells)

func unselect():
	selected_unit = null
	reachable_cells.clear()
	action_cells.clear()
	state = BattleState.IDLE
	grid.clear_all_highlights()
	if turn_manager != null:
		turn_manager.refresh_enemy_intents_visuals()

func try_move_command(cell: Vector2i) -> bool:
	if selected_unit == null:
		return false
	if not movement_system.can_move_to(selected_unit, cell):
		return false
	if state != BattleState.UNIT_SELECTED:
		return false

	state = BattleState.UNIT_MOVING
	movement_system.move_unit(selected_unit, cell)
	return true

func on_unit_move_finished():
	if selected_unit == null:
		return
	state = BattleState.WAITING_FOR_ACTION
	refresh_selection()

func try_action_command(cell: Vector2i):
	if selected_unit == null:
		return
	if not selected_unit.can_act_this_turn():
		return
	if selected_unit.action == null:
		return
	if cell not in action_cells:
		return

	var effects := selected_unit.action.build_effects(selected_unit, cell, grid, unit_manager)
	if effects.is_empty():
		return

	var action_cost = max(0, selected_unit.action_cost)
	if turn_manager != null and not turn_manager.try_spend_cp(action_cost):
		player_action_denied.emit(selected_unit, "Not enough CP")
		return

	player_action_committed.emit(selected_unit, cell, selected_unit.action.id)
	effect_resolver.resolve_effects(effects)
	selected_unit.has_acted_this_turn = true
	unit_manager.cleanup_dead_units()
	if turn_manager != null:
		turn_manager.evaluate_battle_state()

	var finished_unit := selected_unit
	unselect()
	if turn_manager != null:
		turn_manager.notify_player_unit_finished(finished_unit)

func get_action_cells(unit: Unit) -> Array[Vector2i]:
	if unit.action == null:
		return []
	return unit.action.get_target_cells(unit, grid, unit_manager)
