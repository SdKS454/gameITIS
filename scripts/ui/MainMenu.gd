extends Control

func _ready():
	for i in range(1, 6):
		var b: Button = get_node("VBox/Mission%d" % i)
		b.pressed.connect(func(id = i): _start_mission(id))
	$VBox/Continue.pressed.connect(_continue_game)

func _start_mission(mission_id: int):
	SaveManager.save_savegame(mission_id)
	SceneFlow.to_battle()

func _continue_game():
	var save_data := SaveManager.load_savegame()
	SaveManager.save_savegame(save_data.get("mission_id", 1))
	SceneFlow.to_battle()
