extends Control

var map_ref: Node = null

var players: Array = []
var current_player: int = 0

var input_locked := false

func _ready():
	add_to_group("game_manager")
	# Adjust path if needed
	map_ref = get_parent().get_node("Procedural")

	add_player("Player 1")
	add_player("Player 2")
	
	#TEMMP FUNC
	print("Starting Game: Player %d's turn" % current_player)


func add_player(name: String):
	var player = {
		"id": players.size(),
		"name": name,
		"claimed_routes": []
	}
	players.append(player)

func get_player_color(player_id: int) -> Color:
	var colors = [
		Color.RED,
		Color.BLUE,
		Color.GREEN,
		Color.YELLOW
	]
	return colors[player_id % colors.size()]

func claim_route(player_id: int, city_a: int, city_b: int) -> bool:
	if input_locked:
		return false

	var found_route = null

	#Find the route first
	for route in map_ref.routes:
		if (route[0] == city_a and route[1] == city_b) or \
		   (route[0] == city_b and route[1] == city_a):
			found_route = route
			break

	if found_route == null:
		print("Route not found")
		return false

	#Reject if already claimed
	if found_route[4] != -1:
		print("Route already claimed")
		return false

	#Now lock ONLY when we are sure we’ll act
	input_locked = true

	var success = set_route_owner(player_id, city_a, city_b)

	if success:
		next_turn()
	else:
		print("Failed to claim route (unexpected)")

	#ALWAYS unlock
	input_locked = false

	return success

func next_turn():
	current_player = (current_player + 1) % players.size()
	print("Now it's Player %d's turn" % current_player)

func player_has_path(player_id: int, start_id: int, end_id: int) -> bool:
	var visited = {}
	var queue = [start_id]

	while queue.size() > 0:
		var current = queue.pop_front()

		if current == end_id:
			return true

		if visited.has(current):
			continue

		visited[current] = true

		for route in map_ref.routes:
			if route[4] != player_id:
				continue

			var neighbor = -1

			if route[0] == current:
				neighbor = route[1]
			elif route[1] == current:
				neighbor = route[0]

			if neighbor != -1:
				queue.append(neighbor)

	return false

#Test Function for Now
func set_route_owner(player_id: int, city_a: int, city_b: int) -> bool:
	for route in map_ref.routes:

		if (route[0] == city_a and route[1] == city_b) or \
		   (route[0] == city_b and route[1] == city_a):

			var old_owner = route[4]

			# Remove from previous owner's list
			if old_owner != -1:
				players[old_owner]["claimed_routes"].erase(route)

			# Assign new owner
			route[4] = player_id
			players[player_id]["claimed_routes"].append(route)

			print("Route %d-%d now owned by Player %d" % [city_a, city_b, player_id])
			return true

	print("Route not found")
	return false

func player_has_path_astar(player_id: int, start_id: int, end_id: int) -> bool:
	var astar = AStar2D.new()

	for id in map_ref.cities:
		astar.add_point(id, map_ref.cities[id])

	for route in map_ref.routes:
		if route[4] == player_id:
			astar.connect_points(route[0], route[1])

	var path = astar.get_id_path(start_id, end_id)
	return path.size() > 0

func test_connection():
	var result = player_has_path(0, 0, 5)
	print("Connected:", result)
