extends CanvasLayer

func _ready():
	# This ensures the menu keeps working even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS 
	get_tree().paused = true

func _on_resume_button_pressed():
	get_tree().paused = false
	queue_free() # Closes the menu

func _on_save_button_pressed():
	# Generate a name based on current time
	var time = Time.get_datetime_dict_from_system()
	var save_name = "Save_%d-%02d-%02d_%02d%02d.dat" % [
		time.year, time.month, time.day, time.hour, time.minute
	]
	
	var main_ui = get_tree().get_first_node_in_group("main_ui")
	if main_ui:
		main_ui.save_hotseat_game(save_name)
		print("Saved as: ", save_name)
	
	# Optional: Show a "Saved!" message or just close the menu
	_on_resume_button_pressed()

func _on_quit_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/StartMenu.tscn")
