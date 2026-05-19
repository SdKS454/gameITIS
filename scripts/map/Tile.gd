extends Node2D
class_name Tile

enum State {
	NORMAL,
	HOVER,
	SELECTED,
	REACHABLE,
	INTENT,
	ACTION_TARGET
}

const TEAM_NONE := -1
const TEAM_PLAYER := 0
const TEAM_ENEMY := 1

var coord: Vector2i
var state: State = State.NORMAL
var owner_team: int = TEAM_NONE

func set_state(new_state: State):
	state = new_state
	_update_visual()

func set_owner_team(new_owner_team: int):
	owner_team = new_owner_team
	if state == State.NORMAL:
		_update_visual()

func clear_owner_team():
	owner_team = TEAM_NONE
	if state == State.NORMAL:
		_update_visual()

func _update_visual():
	match state:
		State.NORMAL:
			modulate = _get_base_color()
		State.HOVER:
			modulate = Color.YELLOW
		State.SELECTED:
			modulate = Color.GREEN
		State.REACHABLE:
			modulate = Color(0.3, 0.8, 1.0)
		State.INTENT:
			modulate = Color(1.0, 0.4, 0.4)
		State.ACTION_TARGET:
			modulate = Color(1.0, 0.75, 0.2)

func _get_base_color() -> Color:
	match owner_team:
		TEAM_PLAYER:
			return Color(0.80, 0.95, 1.0)
		TEAM_ENEMY:
			return Color(1.0, 0.82, 0.82)
		_:
			return Color.WHITE
