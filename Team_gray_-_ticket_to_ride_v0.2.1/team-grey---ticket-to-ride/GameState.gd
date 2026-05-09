extends Node

#Colors to match to our card assets (Grey is for the black cards but it matches the board which uses grey)
const CARD_COLORS = ["Blue", "Green", "Grey", "Orange", "Purple", "Red", "White", "Yellow"]
const COLORED_CARD_COUNT = 12
const WILD_CARD_COUNT = 14

var pending_load_file: String = ""
#Interactables on board (Train Card Deck - Destination Card Deck - Face-up cards)
var train_deck: Array = []
var destination_deck: Array = []
var face_up_market: Array = []

func initialize():
	_build_train_deck()
	_fill_market()
	#Deals 4 cards to each player at start of game
	for p in range(2):
		PlayerData.players[p]["train_hand"].clear()
		PlayerData.players[p]["dest_hand"].clear()
		var cards_dealt = 0
		while cards_dealt < 4 and train_deck.size() > 0:
			PlayerData.players[p]["train_hand"].append(train_deck.pop_back())
			cards_dealt += 1

#Shuffes the train deck at the beginning of the game
func _build_train_deck():
	train_deck.clear()
	for color in CARD_COLORS:
		for i in range(COLORED_CARD_COUNT):
			train_deck.append({"type": "train", "color": color})
	for i in range(WILD_CARD_COUNT):
		train_deck.append({"type": "train", "color": "Wild"})
	train_deck.shuffle()

#Shuffles the destination deck at the begining of the game. Only allows cards that the procedural map generates to be shuffled in
#No Berlin card will be added if Berlin does not get generated, etc
func set_destination_deck(cards: Array):
	destination_deck = cards
	destination_deck.shuffle()

#Puts 5 face up cards in the face up market display in the UI. Auto fills when one is taken
func _fill_market():
	face_up_market.clear()
	for i in range(5):
		if train_deck.size() > 0:
			face_up_market.append(train_deck.pop_back())

#pulls from the tp of the deck, returns empty if deck is empty
func draw_from_train_deck() -> Dictionary:
	if train_deck.size() > 0:
		return train_deck.pop_back()
	return {}

#takes a Train Card from the face up market and refills
func take_from_market(index: int) -> Dictionary:
	if index >= face_up_market.size():
		return {}
	var card = face_up_market[index]
	face_up_market[index] = draw_from_train_deck() if train_deck.size() > 0 else {}
	return card

#Allows for drawing 3 destination cards. Player must keep 1 at minimum, can discard 2
func draw_destination_cards() -> Array:
	var drawn = []
	for i in range(3):
		if destination_deck.size() > 0:
			drawn.append(destination_deck.pop_back())
	return drawn

#Discarded cards return to bottom of deck
func return_destination_cards(cards: Array):
	for card in cards:
		destination_deck.insert(0, card)
