extends Node
class_name UnitManager

signal units_changed
signal unit_moved(unit: Unit, old_cell: Vector2i, new_cell: Vector2i)

@export var grid: Grid
@export var unit_scene: PackedScene
@export var units_parent: Node2D

var units: Array[Unit] = []
var occupied: Dictionary = {}

func _ready():
	spawn_unit(Vector2i(3, 3), Unit.Team.PLAYER, Unit.Archetype.STRIKER)
	spawn_unit(Vector2i(2, 4), Unit.Team.PLAYER, Unit.Archetype.GUARDIAN)
	spawn_unit(Vector2i(4, 2), Unit.Team.PLAYER, Unit.Archetype.ARTILLERY)
	spawn_unit(Vector2i(7, 7), Unit.Team.ENEMY, Unit.Archetype.BRUTE)
	spawn_unit(Vector2i(6, 8), Unit.Team.ENEMY, Unit.Archetype.RAIDER)
	spawn_unit(Vector2i(8, 6), Unit.Team.ENEMY, Unit.Archetype.SNIPER)
	grid.refresh_ownership_visuals()

func is_occupied(cell: Vector2i) -> bool:
	return occupied.has(cell)

func get_unit_at(cell: Vector2i) -> Unit:
	return occupied.get(cell, null)

func get_units_by_team(team: Unit.Team) -> Array[Unit]:
	var result: Array[Unit] = []
	for unit in units:
		if unit.team == team and not unit.is_dead():
			result.append(unit)
	return result

func spawn_unit(cell: Vector2i, team: Unit.Team = Unit.Team.PLAYER, archetype: Unit.Archetype = Unit.Archetype.STRIKER) -> void:
	if not grid.is_in_bounds(cell):
		return
	if occupied.has(cell):
		return

	var unit := unit_scene.instantiate() as Unit
	unit.grid = grid
	unit.team = team
	unit.archetype = archetype
	if unit.action == null:
		unit.action = _default_action_for(team, archetype)
	_apply_archetype_stats(unit)
	unit.set_cell(cell)

	units_parent.add_child(unit)
	units.append(unit)
	occupied[cell] = unit
	units_changed.emit()

func _default_action_for(team: Unit.Team, archetype: Unit.Archetype) -> BaseAction:
	match archetype:
		Unit.Archetype.ARTILLERY, Unit.Archetype.SNIPER:
			return ArtilleryAttackAction.new()
		_:
			if team == Unit.Team.PLAYER:
				return PushAttackAction.new()
			return MeleeAttackAction.new()

func _apply_archetype_stats(unit: Unit):
	match unit.archetype:
		Unit.Archetype.GUARDIAN:
			unit.max_hp = 4
			unit.move_range = 2
		Unit.Archetype.ARTILLERY:
			unit.max_hp = 2
			unit.move_range = 2
		Unit.Archetype.BRUTE:
			unit.max_hp = 4
			unit.move_range = 2
		Unit.Archetype.RAIDER:
			unit.max_hp = 3
			unit.move_range = 4
		Unit.Archetype.SNIPER:
			unit.max_hp = 2
			unit.move_range = 2

func on_unit_moved(unit: Unit, old_cell: Vector2i, new_cell: Vector2i):
	occupied.erase(old_cell)
	occupied[new_cell] = unit
	unit_moved.emit(unit, old_cell, new_cell)
	grid.refresh_ownership_visuals()

func remove_unit(unit: Unit):
	if unit == null:
		return
	occupied.erase(unit.cell)
	units.erase(unit)
	units_changed.emit()
	grid.refresh_ownership_visuals()
	_play_unit_death_and_free(unit)

func cleanup_dead_units():
	for unit in units.duplicate():
		if unit.is_dead():
			remove_unit(unit)

func _play_unit_death_and_free(unit: Unit):
	if unit == null or not is_instance_valid(unit):
		return
	unit.death_animation_finished.connect(_on_unit_death_animation_finished.bind(unit), CONNECT_ONE_SHOT)
	unit.play_death_animation()

func _on_unit_death_animation_finished(_animated_unit: Unit, queued_unit: Unit):
	if queued_unit != null and is_instance_valid(queued_unit):
		queued_unit.queue_free()
