extends TextureRect

@onready var start_menu_music = $StartMenuMusic

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://UI/StartMenu.tscn")

func _on_back_pressed():
	get_tree().change_scene_to_file("res://UI/how_to_play_rules_of_the_game.tscn")
