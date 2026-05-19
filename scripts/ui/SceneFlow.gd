extends Node
class_name SceneFlow

const MAIN_MENU := "res://scenes/ui/MainMenu.tscn"
const BATTLE := "res://scenes/map/Battle.tscn"
const RESULTS := "res://scenes/ui/Results.tscn"

static func go_to(scene_path: String):
	Engine.get_main_loop().current_scene.get_tree().change_scene_to_file(scene_path)

static func to_main_menu():
	go_to(MAIN_MENU)

static func to_battle():
	go_to(BATTLE)

static func to_results():
	go_to(RESULTS)
