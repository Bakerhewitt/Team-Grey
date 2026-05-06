extends Control

@onready var hand_container = $HandContainer
@onready var card_row = $HandContainer/ScrollContainer/CardRow
@onready var train_car_icon = $TrainCarDisplay/TrainCarIcon
@onready var train_car_label = $TrainCarDisplay/TrainCarLabel
@onready var score_label = $ScoreDisplay/ScoreLabel
@onready var score_number = $ScoreDisplay/ScoreNumber
@onready var market_row = $MarketRow
@onready var train_deck_button = $TrainDeckButton
@onready var dest_deck_button = $DestDeckButton

var dragged_card = null
var placeholder: Control = null
var score = 0
var player_color = PlayerData.player_color
var trains_remaining = 30

# Turn draw state
var cards_drawn_this_turn = 0
var MAX_DRAWS = 2
var is_draw_phase_active = false
var pending_dest_cards: Array = []

const CardScene = preload("res://UI/card.tscn")
const VIEWPORT_WIDTH = 1152
const VIEWPORT_HEIGHT = 648
const HAND_HEIGHT = 160

func _ready():
	await get_tree().process_frame
	hand_container.size = Vector2(VIEWPORT_WIDTH, HAND_HEIGHT)
	hand_container.position = Vector2(0, VIEWPORT_HEIGHT - HAND_HEIGHT + 60)
	setup_train_display()
	setup_score_display()
	GameState.initialize()
	populate_hand_from_state()
	populate_market()

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
	await get_tree().process_frame
	$ScoreDisplay.position = Vector2(VIEWPORT_WIDTH - $ScoreDisplay.size.x - 16, 16)

func populate_hand_from_state():
	for child in card_row.get_children():
		child.queue_free()
	for card_data in GameState.player_train_hand:
		add_card_to_hand(card_data)
	for card_data in GameState.player_dest_hand:
		add_card_to_hand(card_data)

func populate_market():
	for child in market_row.get_children():
		child.queue_free()
	for i in range(GameState.face_up_market.size()):
		var card_data = GameState.face_up_market[i]
		if card_data.is_empty():
			continue
		var card = CardScene.instantiate()
		market_row.add_child(card)
		market_row.move_child(card, 0)
		card.set_card_data(card_data)
		var idx = i
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.connect("draw_card_requested", func(): _on_market_card_clicked(idx))

func add_card_to_hand(card_data: Dictionary):
	var card = CardScene.instantiate()
	card.drag_started.connect(_on_card_drag_started)
	card.drag_ended.connect(_on_card_drag_ended)
	card_row.add_child(card)
	card.set_card_data(card_data)

func _on_market_card_clicked(index: int):
	if cards_drawn_this_turn >= MAX_DRAWS:
		print("Already drew 2 cards this turn.")
		return
	var card_data = GameState.face_up_market[index]
	if card_data.is_empty():
		return
	var cost = 2 if card_data.get("color") == "Wild" else 1
	if cards_drawn_this_turn + cost > MAX_DRAWS:
		print("Not enough draws remaining for a Wild.")
		return
	var drawn = GameState.take_from_market(index)
	GameState.player_train_hand.append(drawn)
	cards_drawn_this_turn += cost
	add_card_to_hand(drawn)
	print("Cards drawn: ", cards_drawn_this_turn, " / ", MAX_DRAWS)
	populate_market()
	if cards_drawn_this_turn >= MAX_DRAWS:
		_end_draw_phase()

func _on_train_deck_button_pressed():
	if cards_drawn_this_turn >= MAX_DRAWS:
		print("Already drew 2 cards this turn.")
		return
	var drawn = GameState.draw_from_train_deck()
	if drawn.is_empty():
		print("Train deck is empty.")
		return
	GameState.player_train_hand.append(drawn)
	cards_drawn_this_turn += 1
	add_card_to_hand(drawn)
	print("Cards drawn: ", cards_drawn_this_turn, " / ", MAX_DRAWS)
	if cards_drawn_this_turn >= MAX_DRAWS:
		_end_draw_phase()

func _on_dest_deck_button_pressed():
	if cards_drawn_this_turn > 0:
		print("Cannot draw destination cards after drawing train cards.")
		return
	pending_dest_cards = GameState.draw_destination_cards()
	if pending_dest_cards.is_empty():
		print("Destination deck is empty.")
		return
	for card_data in pending_dest_cards:
		GameState.player_dest_hand.append(card_data)
		add_card_to_hand(card_data)
	pending_dest_cards.clear()
	_end_draw_phase()

func _end_draw_phase():
	print("Draw phase ended. Resetting for next turn.")
	cards_drawn_this_turn = 0

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
	var global_pos = card.global_position
	card.reparent(card_row)
	card_row.move_child(card, best_index)
	card.global_position = global_pos
	card.z_index = 0
	placeholder.queue_free()
	placeholder = null
	dragged_card = null
	
func _on_end_turn_button_pressed():
	cards_drawn_this_turn = 0
	print("Turn ended manually.")

func _process(_delta):
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
	var current_index = placeholder.get_index()
	if best_index != current_index:
		var neighbour = card_row.get_child(best_index)
		var neighbour_center = neighbour.global_position.x + neighbour.size.x / 2.0
		if abs(drag_x - neighbour_center) < neighbour.size.x * 0.5:
			card_row.move_child(placeholder, best_index)
