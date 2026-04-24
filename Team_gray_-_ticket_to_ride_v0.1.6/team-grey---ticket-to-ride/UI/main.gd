extends Control

@onready var hand_container = $HandContainer
@onready var card_row = $HandContainer/ScrollContainer/CardRow
@onready var train_car_icon = $TrainCarDisplay/TrainCarIcon
@onready var train_car_label = $TrainCarDisplay/TrainCarLabel
@onready var score_label = $ScoreDisplay/ScoreLabel
@onready var score_number = $ScoreDisplay/ScoreNumber

var dragged_card = null
var placeholder: Control = null
var score = 0
var player_color = "Red"
var trains_remaining = 30
var placeholder_cards = [
	Color(0.8, 0.1, 0.1),
	Color(0.1, 0.3, 0.9),
	Color(0.1, 0.7, 0.2),
	Color(0.9, 0.8, 0.1),
	Color(0.8, 0.1, 0.1),
]

const CardScene = preload("res://UI/card.tscn")
const TRAIN_CAR_SCALE = 0.5
const VIEWPORT_WIDTH = 1152
const VIEWPORT_HEIGHT = 648
const HAND_HEIGHT = 160

func _ready():
	await get_tree().process_frame
	
	hand_container.size = Vector2(VIEWPORT_WIDTH, HAND_HEIGHT)
	hand_container.position = Vector2(0, VIEWPORT_HEIGHT - HAND_HEIGHT)
	
	setup_train_display()
	setup_score_display()
	
	populate_hand(placeholder_cards)

func setup_train_display():
	$TrainCarDisplay.position = Vector2(16, 16)
	
	var texture = load("res://Assets/Trains/" + player_color + "_Train_car.png")
	train_car_icon.texture = texture
	train_car_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	train_car_icon.custom_minimum_size = Vector2(86, 41)
	train_car_icon.size = Vector2(35, 17)
	train_car_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	train_car_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	train_car_label.text = "x " + str(trains_remaining)
	train_car_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
func setup_score_display():
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	score_label.text = "Score"
	score_number.text = str(score)

	await get_tree().process_frame  # wait for VBox to calculate its size
	$ScoreDisplay.position = Vector2(VIEWPORT_WIDTH - $ScoreDisplay.size.x - 16, 16)

func populate_hand(cards: Array):
	for child in card_row.get_children():
		child.queue_free()

	for card_color in cards:
		var card = CardScene.instantiate()
		card.drag_started.connect(_on_card_drag_started)
		card.drag_ended.connect(_on_card_drag_ended)
		card_row.add_child(card)
		card.set_card_color(card_color)

func _on_card_drag_started(card: Control):
	dragged_card = card

	placeholder = Control.new()
	placeholder.custom_minimum_size = card.custom_minimum_size

	var index = card.get_index()
	card_row.add_child(placeholder)
	card_row.move_child(placeholder, index)

	var global_pos = card.global_position
	card.reparent(self)
	card.global_position = global_pos
	card.z_index = 10

func _on_card_drag_ended(card: Control):
	if dragged_card == null:
		return

	var best_index = 0
	var best_dist = INF

	for i in card_row.get_child_count():
		var child = card_row.get_child(i)
		var dist = abs(child.global_position.x - card.global_position.x)
		if dist < best_dist:
			best_dist = dist
			best_index = i

	# Reparent card back into the row
	var global_pos = card.global_position
	card.reparent(card_row)
	card_row.move_child(card, best_index)
	card.global_position = global_pos
	card.z_index = 0

	# Remove placeholder
	placeholder.queue_free()
	placeholder = null
	dragged_card = null

func _process(delta):
	if dragged_card == null or placeholder == null:
		return

	var drag_x = dragged_card.global_position.x + dragged_card.size.x / 2.0
	var best_index = placeholder.get_index()
	var best_dist = INF

	for i in card_row.get_child_count():
		var child = card_row.get_child(i)
		if child == placeholder:
			continue
		var child_center = child.global_position.x + child.size.x / 2.0
		var dist = abs(child_center - drag_x)
		if dist < best_dist:
			best_dist = dist
			best_index = i

	# Only move placeholder if dragged card center is past the midpoint of a neighbour
	var current_index = placeholder.get_index()
	if best_index != current_index:
		var neighbour = card_row.get_child(best_index)
		var neighbour_center = neighbour.global_position.x + neighbour.size.x / 2.0
		if abs(drag_x - neighbour_center) < neighbour.size.x * 0.5:
			card_row.move_child(placeholder, best_index)
