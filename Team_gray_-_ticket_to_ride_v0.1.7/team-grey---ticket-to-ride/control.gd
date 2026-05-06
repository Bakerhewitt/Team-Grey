extends Control

var selected_color: String = ""

const COLOR_NAMES = ["Red", "Blue", "Green", "Yellow"]

@onready var confirm_button = $ConfirmButton
@onready var back_button = $BackButton

func _ready():
	confirm_button.disabled = true

func _on_color_selected(color: String):
	selected_color = color
	PlayerData.player_color = color
	confirm_button.disabled = false

func _on_confirm_button_pressed():
	if selected_color != "":
		get_tree().change_scene_to_file("res://UI/main.tscn")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://UI/start_menu.tscn")
