extends Node
class_name SceneFlow

const MAIN_MENU := "res://scenes/ui/MainMenu.tscn"
const BATTLE := "res://scenes/map/Battle.tscn"
const RESULTS := "res://scenes/ui/Results.tscn"

var is_transitioning: bool = false

func go_to(scene_path: String):
	if is_transitioning:
		return
	is_transitioning = true
	var tree := Engine.get_main_loop().current_scene.get_tree()
	tree.change_scene_to_file(scene_path)
	await tree.process_frame
	is_transitioning = false

func to_main_menu():
	go_to(MAIN_MENU)

func to_battle():
	go_to(BATTLE)

func to_results():
	go_to(RESULTS)
