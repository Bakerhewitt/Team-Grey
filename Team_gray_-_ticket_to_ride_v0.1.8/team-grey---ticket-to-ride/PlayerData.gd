extends Node

var players = [
	{
		"color": "",
		"trains_remaining": 30,
		"score": 0,
		"train_hand": [],
		"dest_hand": [],
	},
	{
		"color": "",
		"trains_remaining": 30,
		"score": 0,
		"train_hand": [],
		"dest_hand": [],
	}
]

var current_player: int = 0

func get_current() -> Dictionary:
	return players[current_player]

func get_player(id: int) -> Dictionary:
	return players[id]

func set_color(player_id: int, color: String):
	players[player_id]["color"] = color

var player_color: String:
	get: return players[current_player]["color"]
