extends Control

signal drag_started(card)
signal drag_ended(card)

@onready var card_rect = $CardRect

var is_dragging = false
var drag_offset = Vector2.ZERO
var card_color = Color.WHITE

func set_card_color(color: Color):
	card_color = color
	card_rect.color = color

func _input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Check if mouse is actually over this card
			var mouse = get_global_mouse_position()
			var rect = Rect2(global_position, size)
			if rect.has_point(mouse):
				is_dragging = true
				drag_offset = get_global_mouse_position() - global_position
				emit_signal("drag_started", self)
				get_viewport().set_input_as_handled()
		else:
			if is_dragging:
				is_dragging = false
				emit_signal("drag_ended", self)
				get_viewport().set_input_as_handled()

func _process(delta):
	if is_dragging:
		global_position = get_global_mouse_position() - drag_offset
	
