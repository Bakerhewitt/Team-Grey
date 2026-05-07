extends Control

var selected_color: String = ""
var selecting_player: int = 0

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
@onready var prompt_label = $PromptLabel

#Replaced later after assets were added
#const COLOR_NAMES = {
#	"Red": "red_panel",
#	"Blue": "blue_panel",
#	"Green": "green_panel",
#	"Yellow": "yellow_panel"
#}

func _ready():
	confirm_button.disabled = true
	_update_prompt()

func _update_prompt():
	if selecting_player == 0:
		prompt_label.text = "Player 1: Pick your train color"
	else:
		prompt_label.text = "Player 2: Pick your train color"
		# Grey out Player 1's color
		var p1_color = PlayerData.get_player(0)["color"]
		_disable_color(p1_color)

func _disable_color(color: String):
	var panel_map = {
		"Red": red_panel,
		"Blue": blue_panel,
		"Green": green_panel,
		"Yellow": yellow_panel
	}
	var btn_map = {
		"Red": red_button,
		"Blue": blue_button,
		"Green": green_button,
		"Yellow": yellow_button
	}
	if panel_map.has(color):
		panel_map[color].modulate = Color(0.4, 0.4, 0.4, 1.0)
		btn_map[color].disabled = true

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
	if selected_color == "":
		return
	PlayerData.set_color(selecting_player, selected_color)
	if selecting_player == 0:
		# Move to Player 2 selection
		selecting_player = 1
		selected_color = ""
		confirm_button.disabled = true
		_clear_highlights()
		# Re-enable all buttons first
		for btn in [red_button, blue_button, green_button, yellow_button]:
			btn.disabled = false
		for panel in [red_panel, blue_panel, green_panel, yellow_panel]:
			panel.modulate = Color(1, 1, 1, 1)
		_update_prompt()
	else:
		get_tree().change_scene_to_file("res://Procedural_ticket_to_ride_map/Procedural_ticket_to_ride_version.tscn")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://UI/StartMenu.tscn")
