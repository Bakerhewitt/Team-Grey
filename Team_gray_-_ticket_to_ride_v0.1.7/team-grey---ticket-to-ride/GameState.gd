extends Node

const CARD_COLORS = ["Blue", "Green", "Grey", "Orange", "Purple", "Red", "White", "Yellow"]
const COLORED_CARD_COUNT = 12
const WILD_CARD_COUNT = 14
const DEST_CARD_COUNT = 30

var train_deck: Array = []
var destination_deck: Array = []
var face_up_market: Array = []
var player_train_hand: Array = []
var player_dest_hand: Array = []

func initialize():
	_build_train_deck()
	player_train_hand.clear()
	player_dest_hand.clear()
	for i in range(4):
		if train_deck.size() > 0:
			player_train_hand.append(train_deck.pop_back())
	_fill_market()

func _build_train_deck():
	train_deck.clear()
	for color in CARD_COLORS:
		for i in range(COLORED_CARD_COUNT):
			train_deck.append({"type": "train", "color": color})
	for i in range(WILD_CARD_COUNT):
		train_deck.append({"type": "train", "color": "Wild"})
	train_deck.shuffle()

func set_destination_deck(cards: Array):
	destination_deck = cards
	destination_deck.shuffle()

func deal_initial_dest_hand():
	for i in range(3):
		if destination_deck.size() > 0:
			player_dest_hand.append(destination_deck.pop_back())

func _fill_market():
	face_up_market.clear()
	for i in range(5):
		if train_deck.size() > 0:
			face_up_market.append(train_deck.pop_back())

func draw_from_train_deck() -> Dictionary:
	if train_deck.size() > 0:
		return train_deck.pop_back()
	return {}

func take_from_market(index: int) -> Dictionary:
	if index >= face_up_market.size():
		return {}
	var card = face_up_market[index]
	face_up_market[index] = draw_from_train_deck() if train_deck.size() > 0 else {}
	return card

func draw_destination_cards() -> Array:
	var drawn = []
	for i in range(3):
		if destination_deck.size() > 0:
			drawn.append(destination_deck.pop_back())
	return drawn

func return_destination_cards(cards: Array):
	for card in cards:
		destination_deck.insert(0, card)
