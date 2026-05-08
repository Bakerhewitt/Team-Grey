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
@onready var turn_label = $TurnLabel

var dragged_card = null
var placeholder: Control = null
var cards_drawn_this_turn = 0
var MAX_DRAWS = 2
var pending_dest_cards: Array = []
var dest_discarded_this_turn = 0

enum TurnState {IDLE, DRAWING_TRAIN, DRAWING_DEST, CLAIMED_ROUTE}
var turn_state: TurnState = TurnState.IDLE

const MAX_DEST_DISCARDS = 2
const CardScene = preload("res://UI/card.tscn")
const VIEWPORT_WIDTH = 1152
const VIEWPORT_HEIGHT = 648
const HAND_HEIGHT = 160
const ROUTE_SCORE = {1: 1, 2: 2, 3: 4, 4: 7, 5: 10, 6: 15}

func _ready():
	add_to_group("main_ui")
	await get_tree().process_frame
	hand_container.size = Vector2(VIEWPORT_WIDTH, HAND_HEIGHT)
	hand_container.position = Vector2(0, VIEWPORT_HEIGHT - HAND_HEIGHT + 60)
	setup_train_display()
	setup_score_display()
	GameState.initialize()
	populate_hand_from_state()
	populate_market()
	update_turn_label()

func setup_train_display():
	$TrainCarDisplay.position = Vector2(16, 16)
	var color = PlayerData.get_current()["color"]
	var texture = load("res://Assets/Trains/" + color + "_Train_Engine_-_Left.png")
	train_car_icon.texture = texture
	train_car_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	train_car_icon.custom_minimum_size = Vector2(86, 41)
	train_car_icon.size = Vector2(35, 17)
	train_car_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	train_car_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	train_car_label.text = "x " + str(PlayerData.get_current()["trains_remaining"])
	train_car_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func setup_score_display():
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.text = "P1: 0  |  P2: 0"
	score_number.text = ""
	await get_tree().process_frame
	$ScoreDisplay.position = Vector2(VIEWPORT_WIDTH - $ScoreDisplay.size.x - 16, 16)

func update_score_display():
	var p1 = PlayerData.get_player(0)["score"]
	var p2 = PlayerData.get_player(1)["score"]
	score_label.text = "P1: " + str(p1) + "  |  P2: " + str(p2)

func update_turn_label():
	var p = PlayerData.current_player + 1
	turn_label.text = "Player " + str(p) + "'s Turn"

func populate_hand_from_state():
	for child in card_row.get_children():
		child.queue_free()
	var player = PlayerData.get_current()
	for card_data in player["train_hand"]:
		add_card_to_hand(card_data)
	for card_data in player["dest_hand"]:
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
	card.discard_requested.connect(_on_discard_requested)
	card_row.add_child(card)
	card.set_card_data(card_data)

func _on_discard_requested(card):
	if card.card_data.get("type") != "destination":
		return
	if dest_discarded_this_turn >= MAX_DEST_DISCARDS:
		print("Cannot discard more than 2 destination cards per turn.")
		return
	var data = card.card_data
	var hand = PlayerData.get_current()["dest_hand"]
	for i in range(hand.size()):
		if hand[i].get("city_name") == data.get("city_name"):
			hand.remove_at(i)
			break
	GameState.return_destination_cards([data])
	card.queue_free()
	dest_discarded_this_turn += 1

func _on_market_card_clicked(index: int):
	if turn_state == TurnState.CLAIMED_ROUTE or turn_state == TurnState.DRAWING_DEST:
		print("Cannot draw train cards this turn.")
		return
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
	PlayerData.get_current()["train_hand"].append(drawn)
	cards_drawn_this_turn += cost
	turn_state = TurnState.DRAWING_TRAIN
	add_card_to_hand(drawn)
	populate_market()
	if cards_drawn_this_turn >= MAX_DRAWS:
		_lock_turn()

func _on_train_deck_button_pressed():
	if turn_state == TurnState.CLAIMED_ROUTE or turn_state == TurnState.DRAWING_DEST:
		print("Cannot draw train cards this turn.")
		return
	if cards_drawn_this_turn >= MAX_DRAWS:
		print("Already drew 2 cards this turn.")
		return
	var drawn = GameState.draw_from_train_deck()
	if drawn.is_empty():
		print("Train deck is empty.")
		return
	PlayerData.get_current()["train_hand"].append(drawn)
	cards_drawn_this_turn += 1
	turn_state = TurnState.DRAWING_TRAIN
	add_card_to_hand(drawn)
	if cards_drawn_this_turn >= MAX_DRAWS:
		_lock_turn()

func _on_dest_deck_button_pressed():
	if turn_state != TurnState.IDLE:
		print("Cannot draw destination cards after another action.")
		return
	pending_dest_cards = GameState.draw_destination_cards()
	if pending_dest_cards.is_empty():
		print("Destination deck is empty.")
		return
	turn_state = TurnState.DRAWING_DEST
	for card_data in pending_dest_cards:
		PlayerData.get_current()["dest_hand"].append(card_data)
		add_card_to_hand(card_data)
	pending_dest_cards.clear()
	_lock_turn()

func _lock_turn():
	train_deck_button.disabled = true
	dest_deck_button.disabled = true

func _unlock_turn():
	train_deck_button.disabled = false
	dest_deck_button.disabled = false
	turn_state = TurnState.IDLE
	cards_drawn_this_turn = 0
	dest_discarded_this_turn = 0

func spend_cards_for_route(route_color: Color, cost: int):
	var color_to_key = {
		Color.DARK_RED: "Red", Color.ROYAL_BLUE: "Blue", Color.FOREST_GREEN: "Green",
		Color.YELLOW: "Yellow", Color.MEDIUM_PURPLE: "Purple", Color.WEB_GRAY: "Grey",
		Color.WHITE: "White", Color.ORANGE: "Orange"
	}
	var color_key = color_to_key.get(route_color, "")
	var hand = PlayerData.get_current()["train_hand"]
	var to_remove = cost
	var i = hand.size() - 1
	while i >= 0 and to_remove > 0:
		if hand[i].get("color") == color_key:
			hand.remove_at(i)
			to_remove -= 1
		i -= 1
	i = hand.size() - 1
	while i >= 0 and to_remove > 0:
		if hand[i].get("color") == "Wild":
			hand.remove_at(i)
			to_remove -= 1
		i -= 1

func on_route_claimed(route_length: int, route_color: Color):
	if turn_state != TurnState.IDLE:
		print("Cannot claim a route this turn.")
		return
	turn_state = TurnState.CLAIMED_ROUTE
	var player = PlayerData.get_current()
	player["trains_remaining"] -= route_length
	train_car_label.text = "x " + str(player["trains_remaining"])
	var points = ROUTE_SCORE.get(route_length, 0)
	player["score"] += points
	update_score_display()
	spend_cards_for_route(route_color, route_length)
	populate_hand_from_state()
	_lock_turn()
	check_destination_completion()
	check_end_game()
	
func check_destination_completion():
	var hand = PlayerData.get_current()["dest_hand"]
	var procedural = get_tree().get_first_node_in_group("procedural_map")
	if not procedural:
		return
	var completed = []
	for card in hand:
		var city_name = card.get("city_name", "")
		for r in procedural.routes:
			if r[6] == PlayerData.current_player:
				var city_a = procedural.city_id_to_name.get(r[0], "")
				var city_b = procedural.city_id_to_name.get(r[1], "")
				if city_a == city_name or city_b == city_name:
					completed.append(card)
					break
	for card in completed:
		hand.erase(card)
		PlayerData.get_current()["score"] += 10
		print("Destination completed: ", card.get("city_name"), " +10 points")
	if completed.size() > 0:
		update_score_display()
		populate_hand_from_state()

func swap_to_next_player():
	PlayerData.current_player = 1 - PlayerData.current_player
	_unlock_turn()
	setup_train_display()
	populate_hand_from_state()
	update_turn_label()

func _on_end_turn_button_pressed():
	if turn_state == TurnState.IDLE:
		print("You must take an action before ending your turn.")
		return
	swap_to_next_player()

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
	
func check_end_game():
	for i in range(2):
		if PlayerData.get_player(i)["trains_remaining"] <= 2:
			# Apply penalties
			for p in range(2):
				for card in PlayerData.get_player(p)["dest_hand"]:
					PlayerData.get_player(p)["score"] -= 10
			update_score_display()
			var p1 = PlayerData.get_player(0)["score"]
			var p2 = PlayerData.get_player(1)["score"]
			var winner = "Player 1 Wins!" if p1 > p2 else ("Player 2 Wins!" if p2 > p1 else "It's a Tie!")
			var popup = AcceptDialog.new()
			popup.title = "Game Over"
			popup.dialog_text = winner + "\n\nPlayer 1: " + str(p1) + "\nPlayer 2: " + str(p2)
			add_child(popup)
			popup.popup_centered()
			return

func _process(_delta):
	if dragged_card == null or placeholder == null:
		return
	var drag_x = dragged_card.global_position.x + dragged_card.size.x / 2.0
	var best_dist = INF
	var best_index = placeholder.get_index()
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
