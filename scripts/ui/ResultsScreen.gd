extends Control

func _ready():
	var text := "No result"
	var won := false
	var result := SaveManager.load_battle_result()
	won = bool(result.get("won", false))
	text = "%s\nMission %d\n%s" % ["VICTORY" if won else "DEFEAT", int(result.get("mission_id", 1)), str(result.get("reason", ""))]
	$VBox/Label.text = text
	$VBox/Next.visible = won
	$VBox/Next.pressed.connect(_next)
	$VBox/Menu.pressed.connect(func(): SceneFlow.to_main_menu())

func _next():
	SceneFlow.to_battle()
