extends SceneTree

var fail_signal_fired := false

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
	var effect_resolver: EffectResolver = grid_root.get_node("EffectResolver")
	var environment_manager: EnvironmentManager = grid_root.get_node("EnvironmentManager")
	var battle_hud: BattleHUD = battle.get_node("BattleHUD")

	_assert_not_null(unit_manager, "UnitManager should exist")
	_assert_not_null(battle_manager, "BattleManager should exist")
	_assert_not_null(turn_manager, "TurnManager should exist")
	_assert_not_null(effect_resolver, "EffectResolver should exist")
	_assert_not_null(environment_manager, "EnvironmentManager should exist")
	_assert_not_null(battle_hud, "BattleHUD should exist")

	turn_manager.battle_failed.connect(func(_reason): fail_signal_fired = true)

	var players := unit_manager.get_units_by_team(Unit.Team.PLAYER)
	var enemies := unit_manager.get_units_by_team(Unit.Team.ENEMY)
	_assert(players.size() > 0, "Expected at least one player unit")
	_assert(enemies.size() > 0, "Expected at least one enemy unit")

	var player: Unit = players[0]
	var enemy: Unit = enemies[0]

	# --- Phase 1 regression: CP and enemy attack still work.
	_relocate_unit(unit_manager, player, Vector2i(3, 3))
	_relocate_unit(unit_manager, enemy, Vector2i(4, 3))
	await process_frame

	var initial_cp := turn_manager.cp_current
	_assert(initial_cp == turn_manager.cp_max, "CP should reset to cp_max at player turn start")
	battle_manager.select_unit(player)
	battle_manager.try_action_command(enemy.cell)
	await process_frame
	_assert(turn_manager.cp_current == max(0, initial_cp - player.action_cost), "CP should be spent after successful action")

	var hp_before_enemy_turn := player.hp
	turn_manager.end_player_turn()
	await process_frame
	_assert(player.hp < hp_before_enemy_turn, "Enemy should attack and reduce player HP")

	# --- Hit flash should trigger on damage pipeline.
	var sprite: Sprite2D = player.get_node("Visual/Sprite2D")
	player.take_damage(1)
	_assert(sprite.modulate.r > 1.0, "Hit flash should brighten sprite on damage")
	await create_timer(0.3).timeout
	_assert(abs(sprite.modulate.r - 1.0) < 0.05, "Hit flash should return sprite modulate to normal")

	# --- Phase 2: threat grows by turns.
	var threat_before := turn_manager.threat_level
	turn_manager.end_player_turn()
	await process_frame
	_assert(turn_manager.threat_level > threat_before, "Threat level should grow after each full turn")

	# --- Phase 2: objective exists and has HP.
	var obj_state := environment_manager.get_objective_state()
	_assert(obj_state["alive"], "Objective should be alive at battle start")
	_assert(obj_state["hp"] > 0, "Objective should have positive HP")

	# --- Phase 2: enemy can target objective when threat is high enough.
	var players_now := unit_manager.get_units_by_team(Unit.Team.PLAYER)
	var enemies_now := unit_manager.get_units_by_team(Unit.Team.ENEMY)
	_assert(players_now.size() > 0 and enemies_now.size() > 0, "Need units for objective targeting scenario")
	var far_player: Unit = players_now[0]
	var obj_enemy: Unit = enemies_now[0]
	_relocate_unit(unit_manager, far_player, Vector2i(0, 0))
	_relocate_unit(unit_manager, obj_enemy, environment_manager.objective_cell + Vector2i(-1, 0))
	turn_manager.threat_level = max(turn_manager.threat_level, turn_manager.threat_objective_focus_start)
	turn_manager._plan_enemy_intents()
	await process_frame

	var objective_target_found := false
	for plan in turn_manager.enemy_plans:
		if plan.get("target_mode", "") == "objective":
			objective_target_found = true
			break
	_assert(objective_target_found, "At least one enemy plan should target objective under threat")

	# --- Phase 3: Intent weave should modify one intent and consume charge.
	var weave_from := Vector2i(-1, -1)
	for plan in turn_manager.enemy_plans:
		if plan.get("target_mode", "") == "objective":
			weave_from = plan.get("target_cell", Vector2i(-1, -1))
			break
	_assert(weave_from != Vector2i(-1, -1), "Need weavable intent source cell")
	var weave_before := turn_manager.weave_uses_left
	var weave_preview := turn_manager.get_weave_preview(weave_from)
	_assert(weave_preview.get("valid", false), "Weave preview should be valid on active intent tile")
	var weave_applied := turn_manager.apply_intent_weave_at(weave_from)
	_assert(weave_applied, "Intent weave should apply on active intent cell")
	_assert(turn_manager.weave_uses_left == weave_before - 1, "Weave use should be consumed")
	turn_manager.weave_uses_left = 0
	_assert(turn_manager.get_weave_unavailable_reason() != "", "Unavailable weave reason should be provided")

	# --- Phase 2: objective takes damage and mission fails on destruction.
	var objective_hp_before := environment_manager.objective_hp
	effect_resolver.resolve_effects([
		{"type": "damage", "target_cell": environment_manager.objective_cell, "amount": 1}
	])
	await process_frame
	_assert(environment_manager.objective_hp == objective_hp_before - 1, "Objective HP should decrease after damage")

	# --- Regression: enemy uses animated movement pipeline (not instant teleport).
	_relocate_unit(unit_manager, obj_enemy, Vector2i(0, 9))
	turn_manager.threat_level = max(turn_manager.threat_level, turn_manager.threat_objective_focus_start)
	turn_manager._plan_enemy_intents()
	var saw_enemy_moving := false
	turn_manager.end_player_turn()
	for _i in range(12):
		await process_frame
		if obj_enemy.is_moving:
			saw_enemy_moving = true
	_assert(saw_enemy_moving, "Enemy should use move animation pipeline (is_moving true during enemy turn)")

	environment_manager.damage_objective(999)
	await process_frame
	_assert(not environment_manager.is_objective_alive(), "Objective should be destroyed")
	_assert(turn_manager.is_battle_over, "TurnManager should mark battle as over on objective destruction")
	_assert(fail_signal_fired, "Battle failed signal should fire when objective is destroyed")
	_assert(not turn_manager.can_accept_player_input(), "Player input should be blocked after mission fail")
	_assert(battle_hud.get_node("Root/FailOverlay").visible, "Fail notification overlay should be visible")

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
