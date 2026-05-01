extends Node2D

const CANVAS_SIZE: float = 800
const MIN_CITY_DIST: float = 100.0 
var city_names_pool: Array = [
	"Amsterdam", "Berlin", "Casablanca", "Dublin", "Edinburgh", 
	"Florence", "Geneva", "Helsinki", "Istanbul", "Jakarta", 
	"Kyoto", "London", "Madrid", "Naples", "Oslo", "Paris", 
	"Quebec", "Rome", "Stockholm", "Tokyo", "Utrecht", "Vienna", 
	"Warsaw", "Zurich"
]
var train_supply: int = 45 # Standard starting trains
var player_hand: Dictionary = {
	"red": 0, "blue": 0, "green": 0, "yellow": 0, 
	"purple": 0, "white": 0, "black": 0, "orange": 0, "wild": 5
}

# Map our Color constants back to hand keys for easy lookups
var color_to_key: Dictionary = {
	Color.DARK_RED: "red", Color.ROYAL_BLUE: "blue", Color.FOREST_GREEN: "green",
	Color.GOLDENROD: "yellow", Color.MEDIUM_PURPLE: "purple", Color.WEB_GRAY: "black",
	Color.WHITE: "white", Color.ORANGE: "orange"
}

# This dictionary will map the City ID to its Name
var city_id_to_name: Dictionary = {}
var cities: Dictionary = {} 
var routes: Array = [] 
var destination_cards: Array = []
var hovered_route_index: int = -1
var players: Array = [] # List of unique multiplayer IDs
var current_turn_index: int = 0 
var active_player_id: int = 0
var deck: Array = []
var face_up_market: Array = [] # The 5 cards on the table


# The _ready function is called when the script first loads into the game world.
func _ready():
	# 1. MULTIPLAYER AUTHORITY CHECK
	# In a networked game, we don't want every player generating their own random map.
	# If they did, Player A might see "Paris" in the top-left while Player B sees "Tokyo".
	# 'multiplayer.is_server()' ensures only the Host/Server executes the following logic.
	if multiplayer.is_server():
		
		# 2. THE NETWORK "LATENCY" BUFFER
		# We create a one-shot timer using the SceneTree (get_tree()).
		# We wait for 0.1 seconds (100 milliseconds).
		# This tiny pause allows the networking system to finish 'registering' all 
		# connected peers before we try to communicate with them.
		var sync_timer = get_tree().create_timer(0.1)
		
		# 3. SIGNAL CONNECTION
		# When the timer finishes (the 'timeout' signal), we trigger the 'send_sync_data' function.
		# This function's job is to tell all clients: "Here is the map we are using for this match."
		sync_timer.timeout.connect(send_sync_data)
		
func send_sync_data():
	# 1. GENERATE THE MASTER SEED
	# randi() generates a random 32-bit integer. 
	# This 'my_seed' will determine the entire layout of the board.
	var my_seed = randi()
	
	# 2. GET THE PLAYER LIST
	# multiplayer.get_peers() returns an array of IDs for everyone EXCEPT the server.
	var current_players = multiplayer.get_peers()
	
	# 3. ADD THE SERVER
	# In Godot, the Server's network ID is always 1. 
	# Since get_peers() excludes the host, we manually add '1' to the list.
	current_players.append(1)
	
	# 4. STANDARDIZE THE ORDER
	# Sorting ensures that if you decide to assign "Player 1, 2, 3" based on this list,
	# every machine has the list in the exact same order (e.g., [1, 542, 982]).
	current_players.sort() 
	
	# 5. THE REMOTE PROCEDURE CALL (RPC)
	# This sends the seed and the sorted player list to the 'setup_game' function 
	# on EVERY connected machine (including the server itself).
	setup_game.rpc(my_seed, current_players)

# This decorator ensures only the host can trigger this, 
# that it runs for everyone (including the host), and that the data is guaranteed to arrive.
@rpc("authority", "call_local", "reliable")
func setup_game(game_seed, server_player_list):
	# 1. LOCKING THE RANDOMNESS
	# By setting the seed to the one sent by the server, 
	# randf() and randi() will now produce the EXACT same results for every player.
	seed(game_seed)
	
	# 2. BUILDING THE WORLD
	# Now that the seeds are synced, this function creates the cities and routes.
	# Because the seed is identical, the map will look the same for everyone.
	generate_board()
	
	# 3. SETTING THE TURN ORDER
	# We save the player list and start the game at the first person in that list.
	players = server_player_list 
	current_turn_index = 0
	active_player_id = players[current_turn_index]
	
	# 4. SERVER-ONLY HOUSEKEEPING
	# Only the host initializes the shared card deck and "market" (face-up cards).
	# It then broadcasts what those cards are to everyone else.
	if multiplayer.is_server():
		initialize_deck()
		sync_market.rpc(face_up_market)
	
	# 5. REFRESH SCREEN
	# Tells Godot to clear the old screen and draw the new, synced board.
	queue_redraw()

@rpc("authority", "call_local", "reliable")
func sync_market(new_market_data: Array):
	face_up_market = new_market_data
	print("Market updated: ", face_up_market)
	queue_redraw()
	
func initialize_deck():
	var colors = ["red", "blue", "green", "yellow", "purple", "black", "white", "orange"]
	for c in colors:
		for i in range(12): deck.append(c)
		for i in range(14): deck.append("wild")
		deck.shuffle()
	
	# Fill the market
	for i in range(5):
		face_up_market.append(deck.pop_back())
		
@rpc("authority", "call_local", "reliable")
func next_turn():
	current_turn_index = (current_turn_index + 1) % players.size()
	active_player_id = players[current_turn_index]
	
	# Visual feedback for testing
	var my_id = multiplayer.get_unique_id()
	if my_id == active_player_id:
		print("IT IS YOUR TURN!")
	else:
		print("Waiting for Player: ", active_player_id)
		
	queue_redraw()

func generate_cities(count: int):
	var attempts = 0
	var available_names = city_names_pool.duplicate()
	available_names.shuffle() # Randomize the name order
	
	while cities.size() < count and attempts < 500:
		var pos = Vector2(randf_range(50, CANVAS_SIZE - 50), randf_range(50, CANVAS_SIZE - 50))
		var valid = true
		for c_pos in cities.values():
			if pos.distance_to(c_pos) < MIN_CITY_DIST:
				valid = false
				break
		
		if valid:
			var id = cities.size()
			cities[id] = pos
			
			# Assign a name from the pool, fallback to ID if we run out of names
			if available_names.size() > 0:
				city_id_to_name[id] = available_names.pop_back()
			else:
				city_id_to_name[id] = "Station " + str(id)
				
		attempts += 1

func generate_board():
	cities.clear()
	routes.clear()
	generate_cities(18)

	# 1. PERIMETER
	var hull = get_convex_hull_ids()
	for i in range(hull.size()):
		add_route(hull[i], hull[(i + 1) % hull.size()])
		
	# 2. EDGE SNAP
	for id in cities.keys():
		if get_city_degree(id) == 0:
			for r_idx in range(routes.size() - 1, -1, -1):
				var r = routes[r_idx]
				var closest = Geometry2D.get_closest_point_to_segment(cities[id], cities[r[0]], cities[r[1]])
				if cities[id].distance_to(closest) < 60.0:
					var old_id1 = r[0]
					var old_id2 = r[1]
					routes.remove_at(r_idx)
					add_route(id, old_id1)
					add_route(id, old_id2)
					break

	# 3. DENSE INNER HUB CONNECTIONS
	for pass_num in range(2):
		for id in cities.keys():
			var is_inner = not id in hull
			var target_connections = 6 if is_inner else 3
			if get_city_degree(id) < target_connections:
				var search_count = 5 if pass_num == 0 else 8
				var neighbors = get_closest_neighbors(id, search_count)
				for n_id in neighbors:
					if get_city_degree(id) >= target_connections: break
					add_route_if_valid(id, n_id, false)
			
	# 4. FINAL CLEANUP
	for id in cities.keys():
		while get_city_degree(id) < 3:
			connect_to_nearest_neighbor(id)
			
	# 5. DOUBLE ROUTE CONVERSION
	# We iterate backwards and convert high-traffic routes to double lanes
	for i in range(routes.size() - 1, -1, -1):
		var r = routes[i]
		if get_city_degree(r[0]) >= 4 and get_city_degree(r[1]) >= 4:
			if not r[4]: # If not already double
				var id1 = r[0]
				var id2 = r[1]
				routes.remove_at(i)
				add_route(id1, id2, true)
			
	generate_destination_cards(10)

func add_route(id1: int, id2: int, is_double: bool = false):
	if id1 == id2 or is_route_duplicate(id1, id2): return
	
	var d = cities[id1].distance_to(cities[id2])
	if d < 30.0: return

	# Force segments to be at least 2 and no more than 6
	var raw_length = floor(d / 55)
	var length = clamp(raw_length, 2, 6)
	
	var colors = [Color.DARK_RED, Color.ROYAL_BLUE, Color.FOREST_GREEN, 
				  Color.GOLDENROD, Color.WEB_GRAY, Color.MEDIUM_PURPLE, Color.WHITE, Color.ORANGE]
	
	var color1 = colors.pick_random()
	routes.append([id1, id2, length, color1, is_double, 0, -1])
	
	if is_double:
		var color2 = colors.pick_random()
		while color2 == color1: color2 = colors.pick_random()
		routes.append([id1, id2, length, color2, is_double, 1, -1])

func _draw():
	draw_rect(Rect2(0, 0, CANVAS_SIZE, CANVAS_SIZE), Color(0.9, 0.85, 0.7))
	var temp_node = Control.new()
	var font = temp_node.get_theme_default_font()
	temp_node.free()
	
	for i in range(routes.size()):
		var route = routes[i] # Now we define 'route' based on the index 'i'
		var p1 = cities[route[0]]
		var p2 = cities[route[1]]
		var draw_p1 = p1
		var draw_p2 = p2
		
		if route[4]: # is_double
			var dir = (p2 - p1).normalized()
			var normal = Vector2(-dir.y, dir.x)
			var offset = 8.0 if route[5] == 0 else -8.0
			draw_p1 += normal * offset
			draw_p2 += normal * offset
				
		var color_to_draw = route[3] # Default track color
		var is_claimed = route[6] != -1

		if is_claimed:
			# Use a specific player color (Player 0 = Cyan/Blue)
			color_to_draw = Color.CYAN
			
		# ADD HOVER HIGHLIGHT
		if i == hovered_route_index and not is_claimed:
			# Draw a thick white "glow" behind the route
			draw_line(draw_p1, draw_p2, Color(1, 1, 1, 0.5), 18.0) 

		draw_train_route(draw_p1, draw_p2, route[2], color_to_draw, is_claimed)

		
	for id in cities:
		var pos = cities[id]
		var radius = 10 + (get_city_degree(id) * 1.2) 
		var city_name = city_id_to_name[id]
		
		# Draw Shadow & Main Circle
		draw_circle(pos, radius + 2, Color(0.1, 0.1, 0.1, 0.5))
		draw_circle(pos, radius, Color.ANTIQUE_WHITE)
		draw_arc(pos, radius, 0, TAU, 32, Color.DARK_SLATE_GRAY, 2.0)
		
		# Draw Label Background (The "Pill")
		var label_offset_y = radius + 15
		var label_center_pos = pos + Vector2(0, label_offset_y)
		
		# Get actual text dimensions
		var text_size = font.get_string_size(city_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		var font_height = font.get_height(14)
		
		# Define the rectangle area (centered on X)
		var bg_rect = Rect2(
			label_center_pos.x - (text_size.x / 2) - 6, # X (centered)
			label_center_pos.y - (font_height / 2),     # Y (centered)
			text_size.x + 12,                          # Width (with padding)
			font_height                                # Height
		)
		
		# Draw the Pill
		draw_rect(bg_rect, Color(1, 1, 1, 0.9)) # White background
		draw_rect(bg_rect, Color.DARK_SLATE_GRAY, false, 1.0) # Border
		
		# Draw the String 
		# We add 'font.get_ascent(14)' to the Y to move the baseline to the middle of the rect
		var text_draw_pos = Vector2(
			label_center_pos.x - (text_size.x / 2), 
			label_center_pos.y - (font_height / 2) + font.get_ascent(14) - 2 
		)
		
		draw_string(font, text_draw_pos, city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		draw_hud(font)

func draw_hud(font):
	var cards_text = ""
	for color in player_hand:
		if player_hand[color] > 0:
			cards_text += "%s:%d " % [color.capitalize(), player_hand[color]]
	
	var hud_text = "Trains: %d | Hand: %s | [ENTER] to Score" % [train_supply, cards_text]
	
	draw_rect(Rect2(10, CANVAS_SIZE - 40, CANVAS_SIZE - 20, 30), Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(20, CANVAS_SIZE - 20), hud_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

func draw_train_route(from: Vector2, to: Vector2, segments: int, track_color: Color, is_claimed: bool = false):
	var dir = (to - from).normalized()
	var dist = from.distance_to(to)
	
	var padding = 40.0 
	var usable_dist = dist - padding
	var segment_len = usable_dist / segments 
	
	for i in range(segments):
		var center = from + dir * (segment_len * i + segment_len/2 + (padding/2))
		draw_set_transform(center, dir.angle(), Vector2.ONE)
		
		# We subtract a bit more from the width (6 instead of 4) 
		# to ensure there's a visible gap between very long segments
		var rect_w = segment_len - 6
		
		if is_claimed:
			# Draw a solid, thicker "Train Car"
			draw_rect(Rect2(-rect_w/2, -8, rect_w, 16), track_color)
			# Add a little "window" or detail to make it look like a train car
			draw_rect(Rect2(-rect_w/2 + 4, -2, rect_w - 8, 4), Color.WHITE, false, 1.0)
		else:
			# Draw your existing empty slot
			draw_rect(Rect2(-rect_w/2, -6, rect_w, 12), Color(0.1, 0.1, 0.1))
			draw_rect(Rect2(-rect_w/2 + 2, -4, rect_w - 4, 8), track_color)
		
		# Track Border
		draw_rect(Rect2(-rect_w/2, -6, rect_w, 12), Color(0.1, 0.1, 0.1))
		
		# Track Color
		draw_rect(Rect2(-rect_w/2 + 2, -4, rect_w - 4, 8), track_color)
	
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# code to draw curved paths #	
#	func draw_train_route(from: Vector2, to: Vector2, segments: int, track_color: Color):
#	# 1. Determine a Control Point for the curve
#	# Pulling it slightly toward the center of the map (CANVAS_SIZE / 2) 
#	# makes the whole board feel more "bloomed"
#	var map_center = Vector2(CANVAS_SIZE/2, CANVAS_SIZE/2)
#	var mid_point = (from + to) / 2
#	var dir_to_center = (map_center - mid_point).normalized()
#	
#	# The 'curve_intensity' determines how much the tracks bow
#	var curve_intensity = 30.0 
#	var control_point = mid_point + (dir_to_center * curve_intensity)
#
#	# 2. Draw the segments along the curve
#	for i in range(segments):
#		# t is the progress along the curve (0.0 to 1.0)
#		var t_start = float(i) / segments
#		var t_mid = (float(i) + 0.5) / segments
#		
#		# Quadratic Bezier Formula: (1-t)^2*P0 + 2(1-t)*t*P1 + t^2*P2
#		var pos = from.lerp(control_point, t_mid).lerp(control_point.lerp(to, t_mid), t_mid)
#		
#		# To get the rotation, we look at a tiny bit further down the curve
#		var next_t = t_mid + 0.01
#		var next_pos = from.lerp(control_point, next_t).lerp(control_point.lerp(to, next_t), next_t)
#		var angle = (next_pos - pos).angle()
##		# Calculate dynamic segment length to account for curve stretching
#		var seg_len = from.distance_to(to) / segments - 4
#
#		draw_set_transform(pos, angle, Vector2.ONE)
#		draw_rect(Rect2(-seg_len/2 + 2, -6, seg_len - 4, 12), Color(0.1, 0.1, 0.1))
#		draw_rect(Rect2(-seg_len/2 + 4, -4, seg_len - 8, 8), track_color)
#	
#	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

# --- HELPER FUNCTIONS ---

func get_city_degree(id: int) -> int:
	var count = 0
	for r in routes:
		if r[0] == id or r[1] == id: count += 1
	return count

func get_closest_neighbors(target_id: int, count: int) -> Array:
	var list = []
	for id in cities.keys():
		if id == target_id: continue
		list.append({"id": id, "dist": cities[target_id].distance_to(cities[id])})
	list.sort_custom(func(a, b): return a.dist < b.dist)
	var result = []
	for i in range(min(count, list.size())): result.append(list[i].id)
	return result

func add_route_if_valid(id1: int, id2: int, ignore_angles: bool = false):
	if id1 == id2 or is_route_duplicate(id1, id2): return
	if cities[id1].distance_to(cities[id2]) > 300.0: return 
	if is_any_city_blocking(id1, id2): return
	if not ignore_angles and (is_angle_too_sharp(id1, id2) or is_angle_too_sharp(id2, id1)): return
	if not is_line_crossing_existing(cities[id1], cities[id2]):
		add_route(id1, id2)

func is_angle_too_sharp(from_id: int, to_id: int) -> bool:
	var p_center = cities[from_id]
	var new_dir = (cities[to_id] - p_center).normalized()
	for r in routes:
		var other_id = r[1] if r[0] == from_id else (r[0] if r[1] == from_id else -1)
		if other_id != -1:
			if new_dir.dot((cities[other_id] - p_center).normalized()) > 0.75: return true
	return false

func is_any_city_blocking(id1: int, id2: int) -> bool:
	for test_id in cities.keys():
		if test_id == id1 or test_id == id2: continue
		if cities[test_id].distance_to(Geometry2D.get_closest_point_to_segment(cities[test_id], cities[id1], cities[id2])) < 40.0:
			return true
	return false

func is_line_crossing_existing(p1: Vector2, p2: Vector2) -> bool:
	for r in routes:
		var intersect = Geometry2D.segment_intersects_segment(p1, p2, cities[r[0]], cities[r[1]])
		if intersect:
			if intersect.distance_to(p1) > 1.0 and intersect.distance_to(p2) > 1.0 and \
			   intersect.distance_to(cities[r[0]]) > 1.0 and intersect.distance_to(cities[r[1]]) > 1.0:
				return true
	return false

func is_route_duplicate(id1, id2):
	for r in routes:
		if (r[0] == id1 and r[1] == id2) or (r[0] == id2 and r[1] == id1): return true
	return false

func get_convex_hull_ids() -> Array:
	var hull_points = Geometry2D.convex_hull(cities.values())
	var hull_ids = []
	for p in hull_points:
		for id in cities:
			if cities[id].distance_to(p) < 1.0:
				hull_ids.append(id)
				break
	return hull_ids

func connect_to_nearest_neighbor(id: int):
	var best_dist = INF
	var best_id = -1
	for other_id in cities.keys():
		if id == other_id or is_route_duplicate(id, other_id): continue
		var d = cities[id].distance_to(cities[other_id])
		if d < best_dist and not is_line_crossing_existing(cities[id], cities[other_id]):
			best_dist = d
			best_id = other_id
	if best_id != -1: add_route(id, best_id)

func generate_destination_cards(count: int):
	destination_cards.clear()
	var astar = AStar2D.new()
	for id in cities: astar.add_point(id, cities[id])
	for r in routes: astar.connect_points(r[0], r[1])
	
	var attempts = 0
	while destination_cards.size() < count and attempts < 150:
		attempts += 1
		var id1 = cities.keys().pick_random()
		var id2 = cities.keys().pick_random()
		if id1 == id2 or is_card_duplicate(id1, id2): continue
		var path = astar.get_id_path(id1, id2)
		if path.size() >= 4:
			destination_cards.append({"from": id1, "to": id2, "points": calculate_path_points(path)})
		for card in destination_cards:
			var name_from = city_id_to_name[card.from]
			var name_to = city_id_to_name[card.to]
			print("Ticket: %s to %s (%d points)" % [name_from, name_to, card.points])
func calculate_path_points(path: Array) -> int:
	var total = 0
	for i in range(path.size() - 1):
		for r in routes:
			if (r[0] == path[i] and r[1] == path[i+1]) or (r[1] == path[i] and r[0] == path[i+1]):
				total += r[2]
				break
	return total * 2

func is_card_duplicate(id1, id2):
	for c in destination_cards:
		if (c.from == id1 and c.to == id2) or (c.from == id2 and c.to == id1): return true
	return false
	
func _input(event):
	# Handle Mouse Movement for Hovering
	if event is InputEventMouseMotion:
		var new_hover_index = -1
		for i in range(routes.size()):
			var r = routes[i]
			var p1 = cities[r[0]]
			var p2 = cities[r[1]]
			
			if r[4]: # account for double lane offset
				var dir = (p2 - p1).normalized()
				var normal = Vector2(-dir.y, dir.x)
				var offset = 8.0 if r[5] == 0 else -8.0
				p1 += normal * offset
				p2 += normal * offset
			
			var closest_point = Geometry2D.get_closest_point_to_segment(event.position, p1, p2)
			if event.position.distance_to(closest_point) < 10.0:
				new_hover_index = i
				break
		if hovered_route_index != -1 and routes[hovered_route_index][6] == -1:
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		else:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		# Only redraw if the hover actually changed to save performance
		if new_hover_index != hovered_route_index:
			hovered_route_index = new_hover_index
			queue_redraw()
			
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		check_for_route_click(event.position)
	# Press Space to draw a random colored card
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if multiplayer.get_unique_id() == active_player_id:
			request_card_draw.rpc_id(1) # Only talk to the Server (Host)
		else:
			print("Wait for your turn to draw!")
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		check_final_score()	
		
func draw_random_card():
	# Create a list of valid colors + a chance for a wild
	var valid_keys = color_to_key.values()
	
	# 10% chance to draw a wild, otherwise draw a track color
	var drawn_key = ""
	if randf() < 0.1:
		drawn_key = "wild"
	else:
		drawn_key = valid_keys.pick_random()
		
	player_hand[drawn_key] += 1
	print("Drew a ", drawn_key, " card!")
	queue_redraw()
		
@rpc("any_peer", "call_local", "reliable")
func request_card_draw():
	if not multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if deck.size() > 0:
		var card = deck.pop_back()
		receive_card.rpc_id(sender_id, card) # Only send to the person who asked
		
		# In TTR, drawing from the deck usually ends your turn 
		# (after drawing 2, but let's start with 1 to keep it simple)
		next_turn.rpc() 

@rpc("authority", "call_local", "reliable")
func receive_card(color_key: String):
	player_hand[color_key] += 1
	print("You received a ", color_key, " card!")
	queue_redraw()
	
func can_afford_route(route_index: int) -> bool:
	var r = routes[route_index]
	var cost = r[2]
	
	# Grey routes (Color.WEB_GRAY) can be paid with ANY color, 
	# but for now, let's treat everything as requiring its specific color.
	var color_key = color_to_key.get(r[3], "wild")
	
	if train_supply < cost:
		return false
	
	# Calculate total purchasing power for this specific color
	var total_power = player_hand[color_key] + player_hand["wild"]
	
	return total_power >= cost
#version of code for making gray tracks universal and negating the need for black cards.
#func can_afford_route(route_index: int) -> bool:
#	var r = routes[route_index]
#	var cost = r[2]
#	
#	if train_supply < cost: return false
#
#	# If it's a grey route, find the best color in our hand to use
#	if r[3] == Color.WEB_GRAY:
#		var max_cards = 0
#			if key != "wild":
#				max_cards = max(max_cards, player_hand[key])
#		return (max_cards + player_hand["wild"]) >= cost
#	
#	# Otherwise, use the specific color logic
#	var color_key = color_to_key.get(r[3], "wild")
#	return (player_hand[color_key] + player_hand["wild"]) >= cost
@rpc("any_peer", "call_remote", "reliable")
func request_claim_route(index: int):
	# Only the server should process this
	if not multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Verify it's actually this player's turn
	if sender_id != active_player_id:
		print("Cheating attempt or desync: Player ", sender_id, " tried to claim out of turn.")
		return
		
	# The server performs the logic. 
	# Note: In a full game, the server would also verify the player has enough cards.
	# For now, we'll assume the client's 'can_afford_route' check was honest.
	
	# Tell everyone to update their board
	sync_route_claim.rpc(index, sender_id)
	
	# Advance the turn
	next_turn.rpc()

@rpc("authority", "call_local", "reliable")
func sync_route_claim(index: int, player_id: int):
	# This actually colors the route for everyone
	routes[index][6] = player_id
	print("Route ", index, " claimed by Player ", player_id)
	queue_redraw()

func check_for_route_click(click_pos: Vector2):
	if multiplayer.get_unique_id() != active_player_id:
		print("Wait for your turn! It is Player ", active_player_id, "'s turn.")
		return
	for i in range(routes.size()):
		var r = routes[i]
		var p1 = cities[r[0]]
		var p2 = cities[r[1]]
		
		# If it's a double lane, we must account for the visual offset we used in _draw
		if r[4]: # is_double
			var dir = (p2 - p1).normalized()
			var normal = Vector2(-dir.y, dir.x)
			var offset = 8.0 if r[5] == 0 else -8.0
			p1 += normal * offset
			p2 += normal * offset
		
		var closest_point = Geometry2D.get_closest_point_to_segment(click_pos, p1, p2)
		if click_pos.distance_to(closest_point) < 10.0:
			if r[6] == -1: # unclaimed
				if can_afford_route(i):
					if multiplayer.is_server():
						# Host handles it immediately
						sync_route_claim.rpc(i, 1)
						next_turn.rpc()
					else:
						# Guest asks the host to do it
						request_claim_route.rpc_id(1, i)
						# Note: Local card/train deduction happens in claim_route 
						# We should move that to sync_route_claim later to keep counts perfect
				else:
					print("Insufficient resources.")
				return
func claim_route(index: int, player_id: int):
	var r = routes[index]
	var cost = r[2]
	var color_key = color_to_key.get(r[3], "wild")
	
	# Spend cards (prioritize matching color, then use wilds)
	var cards_to_pay = cost
	var color_spend = min(player_hand[color_key], cards_to_pay)
	player_hand[color_key] -= color_spend
	cards_to_pay -= color_spend
	player_hand["wild"] -= cards_to_pay
	
	# Spend trains
	train_supply -= cost
	
	routes[index][6] = player_id
	print("Claimed! Remaining trains: ", train_supply)
	queue_redraw()
	
func is_ticket_completed(city_a: int, city_b: int) -> bool:
	var stack = [city_a]
	var visited = []
	
	while stack.size() > 0:
		var current = stack.pop_back()
		if current == city_b:
			return true
			
		if not current in visited:
			visited.append(current)
			# Find all cities connected to 'current' via a CYAN route
			for r in routes:
				if r[6] == 0: # If claimed by Player 0
					if r[0] == current and not r[1] in visited:
						stack.append(r[1])
					elif r[1] == current and not r[0] in visited:
						stack.append(r[0])
	return false
	
func check_final_score():
	print("\n--- FINAL SCORE CHECK ---")
	var total_points = 0
	for card in destination_cards:
		var success = is_ticket_completed(card.from, card.to)
		var city_1 = city_id_to_name[card.from]
		var city_2 = city_id_to_name[card.to]
		
		if success:
			print("✅ COMPLETED: %s to %s (+%d points)" % [city_1, city_2, card.points])
			total_points += card.points
		else:
			print("❌ FAILED: %s to %s (-%d points)" % [city_1, city_2, card.points])
			total_points -= card.points
			
	print("TOTAL DESTINATION POINTS: ", total_points)
