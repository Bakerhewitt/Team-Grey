extends Node2D

@export var city_name: String = "City"
@export var dot_color: Color = Color(0.85, 0.15, 0.15) 
@export var dot_radius: float = 10.0

func _draw():
	draw_circle(Vector2.ZERO, dot_radius, dot_color)
	draw_arc(Vector2.ZERO, dot_radius, 0, TAU, 32, Color(0.3, 0.0, 0.0), 2.0)
