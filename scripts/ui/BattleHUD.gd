extends CanvasLayer
class_name BattleHUD

@export var unit_manager: UnitManager
@export var turn_manager: TurnManager
@export var effect_resolver: EffectResolver
@export var battle_manager: BattleManager
@export var environment_manager: EnvironmentManager

@onready var phase_label: Label = $Root/TopBar/TopVBox/PhaseLabel
@onready var cp_label: Label = $Root/TopBar/TopVBox/CPLabel
@onready var threat_label: Label = $Root/TopBar/TopVBox/ThreatLabel
@onready var objective_label: Label = $Root/TopBar/TopVBox/ObjectiveLabel
@onready var hp_label: RichTextLabel = $Root/TopBar/TopVBox/HPLabel
@onready var log_label: RichTextLabel = $Root/LogPanel/LogMargin/LogLabel

const MAX_LOG_LINES := 12
var log_lines: Array[String] = []

func _ready():
	if turn_manager != null:
		turn_manager.turn_started.connect(_on_turn_started)
		turn_manager.phase_changed.connect(_on_phase_changed)
		turn_manager.command_points_changed.connect(_on_command_points_changed)
		turn_manager.threat_changed.connect(_on_threat_changed)
		turn_manager.battle_failed.connect(_on_battle_failed)

	if environment_manager != null:
		environment_manager.objective_updated.connect(_on_objective_updated)
		environment_manager.objective_destroyed.connect(_on_objective_destroyed)

	if effect_resolver != null:
		effect_resolver.damage_resolved.connect(_on_damage_resolved)
		effect_resolver.unit_killed.connect(_on_unit_killed)
		effect_resolver.push_resolved.connect(_on_push_resolved)

	if battle_manager != null:
		battle_manager.player_action_committed.connect(_on_player_action_committed)
		battle_manager.player_action_denied.connect(_on_player_action_denied)

	if unit_manager != null:
		unit_manager.units_changed.connect(_refresh_hp_panel)
		unit_manager.unit_moved.connect(func(_u, _old, _new): _refresh_hp_panel())

	_refresh_hp_panel()
	if turn_manager != null:
		_on_phase_changed(turn_manager.phase)
		_on_command_points_changed(turn_manager.cp_current, turn_manager.cp_max)
		_on_threat_changed(turn_manager.threat_level)
	if environment_manager != null:
		var obj := environment_manager.get_objective_state()
		_on_objective_updated(obj["hp"], obj["max_hp"], obj["cell"])
	_append_log("Battle started")

func _process(_delta):
	_refresh_hp_panel()

func _refresh_hp_panel():
	if unit_manager == null:
		return

	var lines: Array[String] = []
	lines.append("[b]Allies[/b]")
	for unit in unit_manager.get_units_by_team(Unit.Team.PLAYER):
		lines.append(_unit_line(unit))

	lines.append("[b]Enemies[/b]")
	for unit in unit_manager.get_units_by_team(Unit.Team.ENEMY):
		lines.append(_unit_line(unit))

	hp_label.text = "\n".join(lines)

func _unit_line(unit: Unit) -> String:
	return "%s %s HP:%d/%d  Cell:%s" % [
		_team_icon(unit.team),
		unit.name,
		unit.hp,
		unit.max_hp,
		str(unit.cell)
	]

func _team_icon(team: int) -> String:
	return "🟦" if team == Unit.Team.PLAYER else "🟥"

func _on_phase_changed(phase: TurnManager.TurnPhase):
	phase_label.text = "Phase: %s" % _phase_text(phase)

func _on_command_points_changed(current: int, max_points: int):
	cp_label.text = "CP: %d/%d" % [current, max_points]

func _on_threat_changed(level: int):
	threat_label.text = "Threat: %d" % level

func _on_objective_updated(current_hp: int, max_hp: int, cell: Vector2i):
	objective_label.text = "Objective %s HP: %d/%d" % [str(cell), current_hp, max_hp]

func _on_turn_started(turn_idx: int, phase: TurnManager.TurnPhase):
	_append_log("Turn %d -> %s" % [turn_idx, _phase_text(phase)])

func _phase_text(phase: TurnManager.TurnPhase) -> String:
	if phase == TurnManager.TurnPhase.PLAYER_TURN:
		return "PLAYER"
	return "ENEMY"

func _on_player_action_committed(unit: Unit, target_cell: Vector2i, action_id: String):
	_append_log("%s used %s at %s" % [unit.get_team_label(), action_id, str(target_cell)])

func _on_player_action_denied(unit: Unit, reason: String):
	_append_log("%s %s action denied: %s" % [unit.get_team_label(), unit.name, reason])

func _on_damage_resolved(attacker: Unit, target: Unit, amount: int, target_cell: Vector2i):
	var attacker_name := "Environment"
	if attacker != null:
		attacker_name = "%s %s" % [attacker.get_team_label(), attacker.name]

	_append_log("%s hit %s %s for %d at %s" % [
		attacker_name,
		target.get_team_label(),
		target.name,
		amount,
		str(target_cell)
	])

func _on_unit_killed(unit: Unit):
	_append_log("%s %s was destroyed" % [unit.get_team_label(), unit.name])

func _on_push_resolved(target: Unit, from_cell: Vector2i, to_cell: Vector2i):
	_append_log("%s %s pushed: %s -> %s" % [
		target.get_team_label(),
		target.name,
		str(from_cell),
		str(to_cell)
	])

func _on_objective_destroyed(cell: Vector2i):
	_append_log("Objective at %s destroyed" % str(cell))

func _on_battle_failed(reason: String):
	_append_log("MISSION FAILED: %s" % reason)

func _append_log(message: String):
	log_lines.append(message)
	while log_lines.size() > MAX_LOG_LINES:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
