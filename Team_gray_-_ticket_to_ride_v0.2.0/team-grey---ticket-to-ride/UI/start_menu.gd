extends Control

@onready var start_menu_music = $StartMenuMusic
@onready var train_sfx = $TrainSFX

func _on_start_button_pressed():
	train_sfx.play(2)
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://UI/ColorSelect.tscn")
	
func _on_quit_button_pressed():
	get_tree().quit()


func _on_multi_player_button_2_pressed() -> void:
	train_sfx.play(2)
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://Multiplayer/main_egg.tscn") 


func _on_load_game_button_pressed() -> void:
	train_sfx.play(2)
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://LoadMenu.tscn") 
