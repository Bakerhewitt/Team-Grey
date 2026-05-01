extends Control

@onready var menu_music = $MenuMusic

func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://UI/main.tscn")
	
func _on_quit_button_pressed():
	get_tree().quit()


func _on_multi_player_button_2_pressed() -> void:
	get_tree().change_scene_to_file("res://Multiplayer/main_egg.tscn") 
