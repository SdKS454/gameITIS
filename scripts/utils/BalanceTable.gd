extends Node
class_name BalanceTable

const DAMAGE := {
	"melee": 1,
	"push_attack": 1,
	"artillery": 1,
	"push_collision": 1
}

const ACTION_COST := {
	Unit.Archetype.STRIKER: 1,
	Unit.Archetype.GUARDIAN: 1,
	Unit.Archetype.ARTILLERY: 1,
	Unit.Archetype.BRUTE: 1,
	Unit.Archetype.RAIDER: 1,
	Unit.Archetype.SNIPER: 1
}

const UNIT_STATS := {
	Unit.Archetype.STRIKER: {"hp": 3, "move": 3},
	Unit.Archetype.GUARDIAN: {"hp": 4, "move": 2},
	Unit.Archetype.ARTILLERY: {"hp": 2, "move": 2},
	Unit.Archetype.BRUTE: {"hp": 4, "move": 2},
	Unit.Archetype.RAIDER: {"hp": 3, "move": 4},
	Unit.Archetype.SNIPER: {"hp": 2, "move": 2}
}

const MISSION_MODIFIERS := {
	1: {"objective_hp": 6, "cp_max": 3, "threat_growth": 1, "threat_focus": 2, "weave_uses": 1, "enemy_hp_multiplier": 1.0, "enemy_density": 1.0},
	2: {"objective_hp": 8, "cp_max": 3, "threat_growth": 3, "threat_focus": 1, "weave_uses": 1, "enemy_hp_multiplier": 1.05, "enemy_density": 1.2},
	3: {"objective_hp": 5, "cp_max": 2, "threat_growth": 2, "threat_focus": 1, "weave_uses": 0, "enemy_hp_multiplier": 1.1, "enemy_density": 1.3},
	4: {"objective_hp": 6, "cp_max": 3, "threat_growth": 2, "threat_focus": 1, "weave_uses": 1, "enemy_hp_multiplier": 1.6, "enemy_density": 0.8},
	5: {"objective_hp": 7, "cp_max": 2, "threat_growth": 2, "threat_focus": 1, "weave_uses": 1, "enemy_hp_multiplier": 1.2, "enemy_density": 1.3}
}

static func apply_action_balance(action: BaseAction):
	if action == null:
		return
	if action is MeleeAttackAction:
		action.damage = DAMAGE["melee"]
	elif action is PushAttackAction:
		action.damage = DAMAGE["push_attack"]
	elif action is ArtilleryAttackAction:
		action.damage = DAMAGE["artillery"]
