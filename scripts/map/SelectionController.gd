extends Node2D
class_name SelectionController

@export var camera: Camera2D
@export var grid: Grid
@export var unit_manager: UnitManager
@export var battle_manager: BattleManager
@export var turn_manager: TurnManager

var hovered_cell: Vector2i = Vector2i(-1, -1)
var weave_mode: bool = false

func _process(_delta):
	var mouse_world := get_viewport().get_camera_2d().get_global_mouse_position()
	var cell := IsoHelper.screen_to_grid(mouse_world - grid.global_position, grid.iso_config)
	update_hover(cell)

func update_hover(cell: Vector2i):
	if cell == hovered_cell:
		return

	hovered_cell = cell
	if not grid.is_in_bounds(cell):
		grid.hide_hover()
		return
	grid.show_hover(cell)

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			handle_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT and turn_manager != null:
			turn_manager.end_player_turn()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			toggle_weave_mode()

func toggle_weave_mode():
	if turn_manager == null:
		return
	if not turn_manager.can_weave_intent():
		weave_mode = false
		return
	weave_mode = not weave_mode

func handle_click():
	if turn_manager != null and not turn_manager.can_accept_player_input():
		return

	if not grid.is_in_bounds(hovered_cell):
		battle_manager.unselect()
		grid.hide_selected()
		weave_mode = false
		return

	if weave_mode and turn_manager != null:
		var applied := turn_manager.apply_intent_weave_at(hovered_cell)
		if applied:
			weave_mode = false
			return

	battle_manager.select_at(hovered_cell)
	grid.show_selected(hovered_cell)
