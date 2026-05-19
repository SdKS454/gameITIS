extends Node
class_name EffectResolver

signal damage_resolved(attacker: Unit, target: Unit, amount: int, target_cell: Vector2i)
signal unit_killed(unit: Unit)
signal push_resolved(target: Unit, from_cell: Vector2i, to_cell: Vector2i)

@export var grid: Grid
@export var unit_manager: UnitManager
@export var environment_manager: EnvironmentManager

func resolve_effects(effects: Array[Dictionary]):
	var queue: Array[Dictionary] = effects.duplicate(true)

	while not queue.is_empty():
		var effect = queue.pop_front()
		var type = effect.get("type", "")

		match type:
			"damage":
				_resolve_damage(effect)
			"push":
				var chained := _resolve_push(effect)
				for c in chained:
					queue.append(c)

func _resolve_damage(effect: Dictionary):
	var cell: Vector2i = effect.get("target_cell", Vector2i(-1, -1))
	var amount: int = effect.get("amount", 0)
	var attacker: Unit = effect.get("source", null)
	if amount <= 0:
		return
	if attacker != null and is_instance_valid(attacker) and not attacker.is_dead():
		attacker.play_attack_lunge(cell)

	var target := unit_manager.get_unit_at(cell)
	if target != null:
		target.take_damage(amount)
		damage_resolved.emit(attacker, target, amount, cell)
		if target.is_dead():
			unit_killed.emit(target)
			unit_manager.remove_unit(target)
		return

	if environment_manager != null:
		environment_manager.damage_environment(cell, amount)

func _resolve_push(effect: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cell: Vector2i = effect.get("target_cell", Vector2i(-1, -1))
	var dir: Vector2i = effect.get("direction", Vector2i.ZERO)
	var distance: int = max(1, effect.get("distance", 1))
	var target := unit_manager.get_unit_at(cell)

	if target == null:
		return result

	for _i in range(distance):
		var next_cell := target.cell + dir
		if not grid.is_in_bounds(next_cell):
			result.append({"type": "damage", "target_cell": target.cell, "amount": 1, "source": effect.get("source", null)})
			break

		if environment_manager != null and environment_manager.is_environment_at(next_cell):
			result.append({"type": "damage", "target_cell": target.cell, "amount": 1, "source": effect.get("source", null)})
			result.append({"type": "damage", "target_cell": next_cell, "amount": 1, "source": effect.get("source", null)})
			break

		if unit_manager.is_occupied(next_cell):
			result.append({"type": "damage", "target_cell": target.cell, "amount": 1, "source": effect.get("source", null)})
			result.append({"type": "damage", "target_cell": next_cell, "amount": 1, "source": effect.get("source", null)})
			break

		var old_cell := target.cell
		target.set_cell(next_cell)
		unit_manager.on_unit_moved(target, old_cell, next_cell)
		push_resolved.emit(target, old_cell, next_cell)

	return result
