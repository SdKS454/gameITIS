extends CanvasLayer
class_name BattleHUD

@export var unit_manager: UnitManager
@export var turn_manager: TurnManager
@export var effect_resolver: EffectResolver
@export var battle_manager: BattleManager
@export var environment_manager: EnvironmentManager
@export var selection_controller: SelectionController

@onready var phase_label: Label = $Root/TopBar/TopVBox/PhaseLabel
@onready var cp_label: Label = $Root/TopBar/TopVBox/CPLabel
@onready var weave_label: Label = $Root/TopBar/TopVBox/WeaveLabel
@onready var weave_help_label: Label = $Root/TopBar/TopVBox/WeaveHelpLabel
@onready var weave_mode_label: Label = $Root/TopBar/TopVBox/WeaveModeLabel
@onready var weave_preview_label: Label = $Root/TopBar/TopVBox/WeavePreviewLabel
@onready var threat_label: Label = $Root/TopBar/TopVBox/ThreatLabel
@onready var objective_label: Label = $Root/TopBar/TopVBox/ObjectiveLabel
@onready var hp_label: RichTextLabel = $Root/TopBar/TopVBox/HPLabel
@onready var log_label: RichTextLabel = $Root/LogPanel/LogMargin/LogLabel
@onready var fail_overlay: PanelContainer = $Root/FailOverlay
@onready var fail_label: Label = $Root/FailOverlay/FailLabel

const MAX_LOG_LINES := 12
var log_lines: Array[String] = []
var _fail_shown := false
var _weave_mode_active := false

func _ready():
	if turn_manager != null:
		turn_manager.turn_started.connect(_on_turn_started)
		turn_manager.phase_changed.connect(_on_phase_changed)
		turn_manager.command_points_changed.connect(_on_command_points_changed)
		turn_manager.weave_changed.connect(_on_weave_changed)
		turn_manager.threat_changed.connect(_on_threat_changed)
		turn_manager.battle_failed.connect(_on_battle_failed)
		turn_manager.intent_weaved.connect(_on_intent_weaved)

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

	if selection_controller == null:
		selection_controller = get_parent().get_node_or_null("GridRoot/SelectionController")
	if selection_controller != null:
		selection_controller.weave_mode_changed.connect(_on_weave_mode_changed)
		selection_controller.weave_preview_changed.connect(_on_weave_preview_changed)
		selection_controller.weave_feedback.connect(_append_log)

	fail_overlay.visible = false
	weave_help_label.text = "Weave: shift one enemy intent by 1 tile (MMB to toggle, LMB to apply)"
	weave_mode_label.text = "WEAVE MODE: OFF"
	weave_preview_label.text = "Weave preview: hover an intent tile"
	_refresh_hp_panel()
	if turn_manager != null:
		_on_phase_changed(turn_manager.phase)
		_on_command_points_changed(turn_manager.cp_current, turn_manager.cp_max)
		_on_weave_changed(turn_manager.weave_uses_left, turn_manager.weave_uses_per_turn)
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

func _on_weave_changed(uses_left: int, uses_max: int):
	weave_label.text = "Weave Charges: %d/%d (MMB toggle)" % [uses_left, uses_max]
	if uses_left <= 0 and _weave_mode_active:
		_on_weave_mode_changed(false)

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
	if _fail_shown:
		return
	_fail_shown = true
	fail_label.text = "MISSION FAILED\n%s" % reason
	fail_overlay.visible = true

func _on_intent_weaved(from_cell: Vector2i, to_cell: Vector2i):
	_append_log("Intent shifted: %s -> %s" % [str(from_cell), str(to_cell)])
	weave_preview_label.text = "Weave applied: %s -> %s" % [str(from_cell), str(to_cell)]

func _on_weave_mode_changed(active: bool):
	_weave_mode_active = active
	if active:
		weave_mode_label.text = "WEAVE MODE: ACTIVE"
	else:
		weave_mode_label.text = "WEAVE MODE: OFF"

func _on_weave_preview_changed(from_cell: Vector2i, to_cell: Vector2i, is_valid: bool, reason: String):
	if not _weave_mode_active:
		weave_preview_label.text = "Weave preview: hover an intent tile"
		return
	if is_valid:
		weave_preview_label.text = "Weave preview: %s -> %s" % [str(from_cell), str(to_cell)]
		return
	if reason != "":
		weave_preview_label.text = "Weave unavailable: %s" % reason
	else:
		weave_preview_label.text = "Weave preview: hover an intent tile"

func _append_log(message: String):
	log_lines.append(message)
	while log_lines.size() > MAX_LOG_LINES:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)
