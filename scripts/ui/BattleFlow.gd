extends Node

@export var turn_manager: TurnManager
@export var grid_root: GridRoot
@export var transition_layer: CanvasItem
var _finish_started := false

func _ready():
	var save_data := SaveManager.load_savegame()
	var mission_id := SaveManager.normalize_mission_id(save_data.get("mission_id", 1))
	grid_root.apply_mission_preset(mission_id)
	turn_manager.battle_won.connect(func(reason): _finish(true, reason, mission_id))
	turn_manager.battle_failed.connect(func(reason): _finish(false, reason, mission_id))

func _finish(won: bool, reason: String, mission_id: int):
	if _finish_started:
		return
	_finish_started = true
	if transition_layer != null:
		transition_layer.visible = true
		var t := create_tween()
		transition_layer.modulate.a = 0.0
		t.tween_property(transition_layer, "modulate:a", 1.0, 0.25)
		await t.finished
	SaveManager.save_battle_result(won, reason, mission_id)
	if won and mission_id < SaveManager.MAX_MISSION_ID:
		SaveManager.save_savegame(mission_id + 1)
	SceneFlow.to_results()

func _process(_delta):
	if turn_manager == null or turn_manager.is_battle_over:
		return
	if not turn_manager.is_player_turn():
		return
	if turn_manager.cp_current > 0:
		return
	var has_actionable := false
	for unit in turn_manager.unit_manager.get_units_by_team(Unit.Team.PLAYER):
		if unit != null and is_instance_valid(unit) and unit.can_act_this_turn():
			has_actionable = true
			break
	if not has_actionable:
		turn_manager.end_player_turn()
