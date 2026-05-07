extends Control

signal drag_started(card)
signal drag_ended(card)
signal draw_card_requested
signal discard_requested(card)

@onready var card_rect = $CardRect
@onready var card_texture = $CardTexture

var is_dragging = false
var drag_offset = Vector2.ZERO
var card_color = Color.WHITE
var card_data: Dictionary = {}

const COLOR_MAP = {
	"Blue": Color(0.1, 0.3, 0.9),
	"Green": Color(0.1, 0.7, 0.2),
	"Grey": Color(0.5, 0.5, 0.5),
	"Orange": Color(0.9, 0.5, 0.1),
	"Purple": Color(0.5, 0.1, 0.8),
	"Red": Color(0.8, 0.1, 0.1),
	"White": Color(0.95, 0.95, 0.95),
	"Yellow": Color(0.9, 0.8, 0.1),
	"Wild": Color(0.2, 0.8, 0.8),
}

const CARD_IMAGES = {
	"Blue": "res://Assets/Train Cards/Blue Train.png",
	"Green": "res://Assets/Train Cards/Green Train.png",
	"Grey": "res://Assets/Train Cards/Grey Train.png",
	"Orange": "res://Assets/Train Cards/Orange Train.png",
	"Purple": "res://Assets/Train Cards/Purple Train.png",
	"Red": "res://Assets/Train Cards/Red Train.png",
	"White": "res://Assets/Train Cards/White Train.png",
	"Yellow": "res://Assets/Train Cards/Yellow Train.png",
	"Wild": "res://Assets/Train Cards/Wild Train.png",
}

const CARD_BACK = "res://Assets/Train Cards/Card backs.png"

func set_card_color(color: Color):
	card_color = color
	card_rect.color = color

func set_card_data(data: Dictionary):
	card_data = data
	if data.get("type") == "train":
		var color_name = data.get("color", "Wild")
		card_rect.color = COLOR_MAP.get(color_name, Color.WHITE)
		if CARD_IMAGES.has(color_name):
			card_texture.texture = load(CARD_IMAGES[color_name])
		card_texture.visible = true
	elif data.get("type") == "destination":
		var city_name = data.get("city_name", "")
		var image_path = "res://Assets/Destination Cards/" + city_name + " Card.png"
		if ResourceLoader.exists(image_path):
			card_texture.texture = load(image_path)
			card_texture.visible = true
		else:
			card_texture.visible = false
		card_rect.color = Color(0.2, 0.4, 0.2)

func set_face_down():
	card_texture.texture = load(CARD_BACK)
	card_texture.visible = true

func _input(event: InputEvent):
	if event is InputEventMouseButton:
		var mouse = get_global_mouse_position()
		var rect = Rect2(global_position, size)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if rect.has_point(mouse):
					emit_signal("draw_card_requested")
					is_dragging = true
					drag_offset = get_global_mouse_position() - global_position
					emit_signal("drag_started", self)
					get_viewport().set_input_as_handled()
			else:
				if is_dragging:
					is_dragging = false
					emit_signal("drag_ended", self)
					get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if rect.has_point(mouse):
				emit_signal("discard_requested", self)
				get_viewport().set_input_as_handled()

func _process(_delta):
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset
