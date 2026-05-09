extends Control

@onready var save_list = $ScrollContainer/VBoxContainer

func _ready():
	list_save_files()

func list_save_files():
	
	for child in save_list.get_children():
		child.queue_free()
		
	
	var path = "user://saves/"
	if not DirAccess.dir_exists_absolute(path):
		return 

	var dir = DirAccess.open(path)
	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".dat"):
			create_save_button(file_name)
		file_name = dir.get_next()

func create_save_button(file_name: String):
	var btn = Button.new()
	btn.text = file_name.replace(".dat", "").replace("_", " ") # Make it look pretty
	btn.custom_minimum_size.y = 40
	
	
	btn.pressed.connect(func(): _on_save_picked(file_name))
	
	save_list.add_child(btn)

func _on_save_picked(file_name: String):
	print("Button clicked! Attempting to load: ", file_name) # DEBUG LINE
	GameState.pending_load_file = file_name
	
	
	var scene_path = "res://Procedural_ticket_to_ride_map/Procedural_ticket_to_ride_version.tscn" 
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		print("ERROR: Main.tscn not found at ", scene_path)

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://UI/StartMenu.tscn")
