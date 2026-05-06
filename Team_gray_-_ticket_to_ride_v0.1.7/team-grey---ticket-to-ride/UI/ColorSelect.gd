extends Control

var selected_color: String = ""

@onready var confirm_button = $ConfirmButton
@onready var back_button = $BackButton
@onready var red_button = $ColorGrid/RedPanel/RedButton
@onready var blue_button = $ColorGrid/BluePanel/BlueButton
@onready var green_button = $ColorGrid/GreenPanel/GreenButton
@onready var yellow_button = $ColorGrid/YellowPanel/YellowButton
@onready var red_panel = $ColorGrid/RedPanel
@onready var blue_panel = $ColorGrid/BluePanel
@onready var green_panel = $ColorGrid/GreenPanel
@onready var yellow_panel = $ColorGrid/YellowPanel

func _ready():
	confirm_button.disabled = true
	print("red_panel found: ", red_panel)
	print("red_panel size: ", red_panel.size)

func _clear_highlights():
	for panel in [red_panel, blue_panel, green_panel, yellow_panel]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_width_left = 0
		style.border_width_right = 0
		style.border_width_top = 0
		style.border_width_bottom = 0
		panel.add_theme_stylebox_override("panel", style)

func _highlight_button(panel: Panel):
	_clear_highlights()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = Color(0, 0, 0, 1)
	panel.add_theme_stylebox_override("panel", style)

func _on_color_selected(color: String, panel: Panel):
	selected_color = color
	PlayerData.player_color = color
	confirm_button.disabled = false
	_highlight_button(panel)

func _on_red_button_pressed():
	_on_color_selected("Red", red_panel)

func _on_blue_button_pressed():
	_on_color_selected("Blue", blue_panel)

func _on_green_button_pressed():
	_on_color_selected("Green", green_panel)

func _on_yellow_button_pressed():
	_on_color_selected("Yellow", yellow_panel)

func _on_confirm_button_pressed():
	if selected_color != "":
		get_tree().change_scene_to_file("res://Procedural_ticket_to_ride_map/Procedural_ticket_to_ride_version.tscn")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://UI/StartMenu.tscn")
