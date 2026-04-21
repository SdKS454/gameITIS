extends SceneTree

func _init():
	var battle_scene: PackedScene = load("res://scenes/map/Battle.tscn")
	if battle_scene == null:
		push_error("Failed to load Battle scene")
		quit(1)
		return

	var battle := battle_scene.instantiate()
	root.add_child(battle)
	await process_frame

	var grid_root := battle.get_node("GridRoot")
	var unit_manager: UnitManager = grid_root.get_node("UnitManager")
	var battle_manager: BattleManager = grid_root.get_node("BattleManager")
	var turn_manager: TurnManager = grid_root.get_node("TurnManager")

	_assert_not_null(unit_manager, "UnitManager should exist")
	_assert_not_null(battle_manager, "BattleManager should exist")
	_assert_not_null(turn_manager, "TurnManager should exist")

	var players := unit_manager.get_units_by_team(Unit.Team.PLAYER)
	var enemies := unit_manager.get_units_by_team(Unit.Team.ENEMY)
	_assert(players.size() > 0, "Expected at least one player unit")
	_assert(enemies.size() > 0, "Expected at least one enemy unit")

	var player: Unit = players[0]
	var enemy: Unit = enemies[0]

	# Arrange adjacency for deterministic enemy attack test.
	_relocate_unit(unit_manager, player, Vector2i(3, 3))
	_relocate_unit(unit_manager, enemy, Vector2i(4, 3))
	await process_frame

	# CP reset check and spend check.
	var initial_cp := turn_manager.cp_current
	_assert(initial_cp == turn_manager.cp_max, "CP should reset to cp_max at player turn start")
	battle_manager.select_unit(player)
	_assert(battle_manager.action_cells.size() > 0, "Player should have available action targets")
	battle_manager.try_action_command(enemy.cell)
	await process_frame
	_assert(turn_manager.cp_current == max(0, initial_cp - player.action_cost), "CP should be spent after successful action")

	# Enemy attack should happen after ending player turn.
	var hp_before_enemy_turn := player.hp
	turn_manager.end_player_turn()
	await process_frame
	_assert(player.hp < hp_before_enemy_turn, "Enemy should attack and reduce player HP")

	# Kill enemy, then end turn: should not crash.
	var players_after := unit_manager.get_units_by_team(Unit.Team.PLAYER)
	var enemies_after := unit_manager.get_units_by_team(Unit.Team.ENEMY)
	_assert(players_after.size() > 0 and enemies_after.size() > 0, "Need units for kill scenario")

	var killer: Unit = players_after[0]
	var victim: Unit = enemies_after[0]
	_relocate_unit(unit_manager, killer, Vector2i(5, 5))
	_relocate_unit(unit_manager, victim, Vector2i(6, 5))
	victim.hp = 1
	await process_frame

	battle_manager.select_unit(killer)
	battle_manager.try_action_command(victim.cell)
	await process_frame
	_assert(victim.is_dead() or not is_instance_valid(victim) or victim.is_queued_for_deletion(), "Enemy should be dead/removed")

	turn_manager.end_player_turn()
	await process_frame
	_assert(turn_manager.phase == TurnManager.TurnPhase.PLAYER_TURN, "Game should continue to next player turn without crash")

	print("SMOKE_TEST_OK")
	quit(0)

func _relocate_unit(unit_manager: UnitManager, unit: Unit, target: Vector2i):
	if unit.cell == target:
		return
	var old_cell := unit.cell
	unit.set_cell(target)
	unit_manager.on_unit_moved(unit, old_cell, target)

func _assert(condition: bool, message: String):
	if not condition:
		push_error(message)
		quit(1)

func _assert_not_null(value, message: String):
	_assert(value != null, message)
