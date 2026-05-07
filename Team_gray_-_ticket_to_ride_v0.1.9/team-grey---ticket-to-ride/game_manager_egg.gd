extends Node
# This script manages the logical flow and player inventory

# Increased these so you can click as many as you want while testing
var train_supply: int = 100 
var player_hand: Dictionary = {
	"red": 50, "blue": 50, "green": 50, "yellow": 50, 
	"purple": 50, "white": 50, "black": 50, "orange": 50, "wild": 50
}

# Mapping color constants to keys
var color_to_key: Dictionary = {
	Color.DARK_RED: "red", Color.ROYAL_BLUE: "blue", Color.FOREST_GREEN: "green",
	Color.GOLDENROD: "yellow", Color.MEDIUM_PURPLE: "purple", Color.WEB_GRAY: "black",
	Color.WHITE: "white", Color.ORANGE: "orange"
}

func can_afford_route(route_data: Array) -> bool:
	var cost = route_data[2]
	var color_key = color_to_key.get(route_data[3], "wild")
	
	# Check if we have enough of the specific color + wilds
	var total_available = player_hand.get(color_key, 0) + player_hand["wild"]
	
	if train_supply < cost: 
		print("Debug: Out of trains!")
		return false
	if total_available < cost:
		print("Debug: Cannot afford! Cost: ", cost, " Have: ", total_available)
		return false
		
	return true

func spend_resources(cost: int, color: Color):
	var color_key = color_to_key.get(color, "wild")
	var cards_to_pay = cost
	var color_spend = min(player_hand[color_key], cards_to_pay)
	player_hand[color_key] -= color_spend
	cards_to_pay -= color_spend
	player_hand["wild"] -= cards_to_pay
	train_supply -= cost
