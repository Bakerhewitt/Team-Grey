extends Node2D



const CANVAS_SIZE_X: float = 1152
const CANVAS_SIZE_Y: float = 568
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
	Color.DARK_RED: "Red", Color.ROYAL_BLUE: "Blue", Color.FOREST_GREEN: "Green",
	Color.YELLOW: "Yellow", Color.MEDIUM_PURPLE: "Purple", Color.WEB_GRAY: "Black",
	Color.WHITE: "White", Color.ORANGE: "Orange"
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
var current_seed: int = 0


func _ready():
	add_to_group("procedural_map")
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		var my_seed = randi()
		setup_game(my_seed, [1])
		return
	
	if multiplayer.is_server():
		var sync_timer = get_tree().create_timer(0.1)
		sync_timer.timeout.connect(send_sync_data)

	if multiplayer.is_server():
		var sync_timer = get_tree().create_timer(0.1)
		sync_timer.timeout.connect(send_sync_data)
		
func send_sync_data():
	var my_seed = randi()
	var current_players = multiplayer.get_peers()

	current_players.append(1)
	current_players.sort() 

	setup_game.rpc(my_seed, current_players)


var is_generated: bool = false
signal generation_finished

@rpc("authority", "call_local", "reliable")
func setup_game(game_seed, server_player_list):
	current_seed = game_seed # Store the seed for saving

	seed(game_seed)

	generate_board()

	players = server_player_list 
	current_turn_index = 0
	active_player_id = players[current_turn_index]

	if multiplayer.is_server():
		initialize_deck()
		sync_market.rpc(face_up_market)

	is_generated = true
	generation_finished.emit()
	queue_redraw()
	
func get_save_data() -> Dictionary:
	var claimed_routes = []
	for i in range(routes.size()):
		if routes[i][6] != -1: # index 6 is player_id
			claimed_routes.append({"idx": i, "owner": routes[i][6]})
			
	return {
		"seed": current_seed,
		"claimed_routes": claimed_routes,
		"deck": deck,
		"market": face_up_market
	}

func load_from_data(data: Dictionary):
	setup_game(data["seed"], [1]) 
	
	for claim in data["claimed_routes"]:
		routes[claim["idx"]][6] = claim["owner"]

	deck = data["deck"]
	face_up_market = data["market"]
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
		var pos = Vector2(randf_range(200, CANVAS_SIZE_X - 50), randf_range(50, CANVAS_SIZE_Y - 75))
		var valid = true
		for c_pos in cities.values():
			if pos.distance_to(c_pos) < MIN_CITY_DIST:
				valid = false
				break
		
		if valid:
			var id = cities.size()
			cities[id] = pos

			if available_names.size() > 0:
				city_id_to_name[id] = available_names.pop_back()
			else:
				city_id_to_name[id] = "Station " + str(id)
				
		attempts += 1

func generate_board():
	cities.clear()
	routes.clear()
	generate_cities(18)

	# Convex HUll perimitor
	var hull = get_convex_hull_ids()
	for i in range(hull.size()):
		add_route(hull[i], hull[(i + 1) % hull.size()])
		
	# Edge Snap
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

	#citie connections
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
			
	for id in cities.keys():
		while get_city_degree(id) < 3:
			connect_to_nearest_neighbor(id)
			
	#Double Route Conversion
	for i in range(routes.size() - 1, -1, -1):
		var r = routes[i]
		if get_city_degree(r[0]) >= 4 and get_city_degree(r[1]) >= 4:
			if not r[4]: # If not already double
				var id1 = r[0]
				var id2 = r[1]
				routes.remove_at(i)
				add_route(id1, id2, true)
			
	generate_destination_cards()

func add_route(id1: int, id2: int, is_double: bool = false):
	if id1 == id2 or is_route_duplicate(id1, id2): return
	
	var d = cities[id1].distance_to(cities[id2])
	if d < 30.0: return

	# Force segments to be at least 2 and no more than 6
	var raw_length = floor(d / 55)
	var length = clamp(raw_length, 2, 6)
	
	var colors = [Color.DARK_RED, Color.ROYAL_BLUE, Color.FOREST_GREEN, 
				  Color(0.784, 0.75, 0.172, 1.0), Color.WEB_GRAY, Color.MEDIUM_PURPLE, Color.WHITE, Color.ORANGE]
	
	var color1 = colors.pick_random()
	routes.append([id1, id2, length, color1, is_double, 0, -1])
	
	if is_double:
		var color2 = colors.pick_random()
		while color2 == color1: color2 = colors.pick_random()
		routes.append([id1, id2, length, color2, is_double, 1, -1])

func _draw():
	var bg = preload("res://Assets/Background/World Map.png")
	draw_texture_rect(bg, Rect2(0, 0, CANVAS_SIZE_X, CANVAS_SIZE_Y), false)
	var temp_node = Control.new()
	var font = temp_node.get_theme_default_font()
	temp_node.free()
	
	var color_map = {
		"Red": Color.RED,
		"Blue": Color.BLUE,
		"Green": Color.GREEN,
		"Yellow": Color.YELLOW, 
		"Orange": Color.ORANGE,
		"Purple": Color.PURPLE,
		"White": Color.WHITE,
		"Black": Color.BLACK
	}
	
	for i in range(routes.size()):
		var route = routes[i] 
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
		var owner_id = route[6]
		var is_claimed = owner_id != -1

		if is_claimed:
			# Get the color name string from the player's data
			var player_color_name = PlayerData.get_player(owner_id).get("color", "Cyan")
			# Convert string to Color object using map or engine default
			if color_map.has(player_color_name):
				color_to_draw = color_map[player_color_name]
			else:
				color_to_draw = Color.from_string(player_color_name, Color.CYAN)
			
		#hover highlightT
		if i == hovered_route_index and not is_claimed:
			# Draw a thick white "glow" behind the route
			draw_line(draw_p1, draw_p2, Color(1, 1, 1, 0.5), 18.0) 

		draw_train_route(draw_p1, draw_p2, route[2], color_to_draw, is_claimed)

		
	for id in cities:
		var pos = cities[id]
		var radius = 10 + (get_city_degree(id) * 1.2) 
		var city_name = city_id_to_name[id]
		
		draw_circle(pos, radius + 2, Color(0.1, 0.1, 0.1, 0.5))
		draw_circle(pos, radius, Color.ANTIQUE_WHITE)
		draw_arc(pos, radius, 0, TAU, 32, Color.DARK_SLATE_GRAY, 2.0)
		
		var label_offset_y = radius + 15
		var label_center_pos = pos + Vector2(0, label_offset_y)
		
		var text_size = font.get_string_size(city_name, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		var font_height = font.get_height(14)
		
		var bg_rect = Rect2(
			label_center_pos.x - (text_size.x / 2) - 6, 
			label_center_pos.y - (font_height / 2),     
			text_size.x + 12,                          
			font_height                                
		)
		
		# Draw the Pill
		draw_rect(bg_rect, Color(1, 1, 1, 0.9)) # White background
		draw_rect(bg_rect, Color.DARK_SLATE_GRAY, false, 1.0) # Border
		
		var text_draw_pos = Vector2(
			label_center_pos.x - (text_size.x / 2), 
			label_center_pos.y - (font_height / 2) + font.get_ascent(14) - 2 
		)
		
		draw_string(font, text_draw_pos, city_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)


func draw_train_route(from: Vector2, to: Vector2, segments: int, track_color: Color, is_claimed: bool = false):
	var dir = (to - from).normalized()
	var dist = from.distance_to(to)
	
	var padding = 40.0 
	var usable_dist = dist - padding
	var segment_len = usable_dist / segments 
	
	for i in range(segments):
		var center = from + dir * (segment_len * i + segment_len/2 + (padding/2))
		draw_set_transform(center, dir.angle(), Vector2.ONE)
		
		# We subtract a bit more from the width (6 instead of 4) to ensure there's a visible gap between very long segments
		var rect_w = segment_len - 6
		
		if is_claimed:
			draw_rect(Rect2(-rect_w/2, -8, rect_w, 16), track_color)
			draw_rect(Rect2(-rect_w/2 + 4, -2, rect_w - 8, 4), Color.WHITE, false, 1.0)
		else:
			draw_rect(Rect2(-rect_w/2, -6, rect_w, 12), Color(0.1, 0.1, 0.1))
			draw_rect(Rect2(-rect_w/2 + 2, -4, rect_w - 4, 8), track_color)
		
		draw_rect(Rect2(-rect_w/2, -6, rect_w, 12), Color(0.1, 0.1, 0.1))
		
		draw_rect(Rect2(-rect_w/2 + 2, -4, rect_w - 4, 8), track_color)
	
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
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
	
func generate_destination_cards():
	destination_cards.clear()
	
	# Build one card per generated city
	var available_cities = city_id_to_name.values().duplicate()
	available_cities.shuffle()
	
	for city_name in available_cities:
		destination_cards.append({
			"type": "destination",
			"city_name": city_name,
			"points": randi_range(5, 20)
		})
	
	GameState.set_destination_deck(destination_cards.duplicate())
	
	for card in destination_cards:
		print("Destination: %s (%d points)" % [card.city_name, card.points])
	
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if hovered_route_index != -1:
			var route = routes[hovered_route_index]
			
			# Check if the route is already claimed
			if route[6] != -1:
				print("This route is already owned!")
				return

			var main_node = get_tree().get_first_node_in_group("main_ui")
			if main_node:
				main_node.attempt_claim_route(hovered_route_index)
			else:
				print("Error: Could not find Main UI.")

	if event is InputEventMouseMotion:
		var new_hover_index = -1
		var mouse_pos = get_local_mouse_position()
		
		for i in range(routes.size()):
			var r = routes[i]
			var p1 = cities[r[0]]
			var p2 = cities[r[1]]
			
			var check_p1 = p1
			var check_p2 = p2
			
			if r[4]: # if is_double
				var dir = (p2 - p1).normalized()
				var normal = Vector2(-dir.y, dir.x)
				var offset = 8.0 if r[5] == 0 else -8.0
				check_p1 += normal * offset
				check_p2 += normal * offset
			
			var closest_point = Geometry2D.get_closest_point_to_segment(mouse_pos, check_p1, check_p2)
			
			# Using 10.0 pixels for a tighter, more accurate selection on double routes
			if mouse_pos.distance_to(closest_point) < 10.0:
				new_hover_index = i
				break
				
		if new_hover_index != hovered_route_index:
			hovered_route_index = new_hover_index
			queue_redraw()
			
			if hovered_route_index != -1:
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
				
func draw_random_card():
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
		
		next_turn.rpc() 

@rpc("authority", "call_local", "reliable")
func receive_card(color_key: String):
	player_hand[color_key] += 1
	print("You received a ", color_key, " card!")
	queue_redraw()
	
func can_afford_route(route_index: int) -> bool:
	var r = routes[route_index]
	var cost = r[2]
	var route_color = r[3]
	
	if PlayerData.get_current()["trains_remaining"] < cost:
		return false

	var color_to_key = {
		Color.DARK_RED: "Red", Color.ROYAL_BLUE: "Blue", Color.FOREST_GREEN: "Green",
		Color.YELLOW: "Yellow", Color.MEDIUM_PURPLE: "Purple", Color.WEB_GRAY: "Grey",
		Color.WHITE: "White", Color.ORANGE: "Orange"
	}
	
	var color_key = color_to_key.get(route_color, "")
	var hand = PlayerData.get_current()["train_hand"]
	
	var matching = 0
	var wilds = 0
	for card in hand:
		if card.get("color") == color_key:
			matching += 1
		elif card.get("color") == "Wild":
			wilds += 1
	
	return (matching + wilds) >= cost
	
	
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
	
	sync_route_claim.rpc(index, sender_id)
	
	next_turn.rpc()

@rpc("authority", "call_local", "reliable")
func sync_route_claim(index: int, player_id: int):
	routes[index][6] = player_id
	print("Route ", index, " claimed by Player ", player_id)
	# Notify UI
	var ui = get_tree().get_first_node_in_group("main_ui")
	if ui:
		ui.on_route_claimed(routes[index][2], routes[index][3])
	queue_redraw()

func check_for_route_click(click_pos: Vector2):
	if multiplayer.get_unique_id() != active_player_id:
		print("Wait for your turn! It is Player ", active_player_id, "'s turn.")
		return
	for i in range(routes.size()):
		var r = routes[i]
		var p1 = cities[r[0]]
		var p2 = cities[r[1]]
		
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
						sync_route_claim.rpc(i, PlayerData.current_player)
						next_turn.rpc()
					else:
						# Guest asks the host to do it
						request_claim_route.rpc_id(1, i)
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
	
func is_ticket_completed(city_name: String, player_id: int) -> bool:
	# Find the city ID for this name
	var target_id = -1
	for id in city_id_to_name:
		if city_id_to_name[id] == city_name:
			target_id = id
			break
	if target_id == -1:
		return false
	
	# Check if player has any claimed route touching this city
	for r in routes:
		if r[6] == player_id:
			if r[0] == target_id or r[1] == target_id:
				return true
	return false
	
func check_final_score():
	print("\n--- FINAL SCORE CHECK ---")
	for p in range(2):
		print("Player ", p + 1, ":")
		for card in PlayerData.get_player(p)["dest_hand"]:
			var city_name = card.get("city_name", "")
			var success = is_ticket_completed(city_name, p)
			if success:
				print("✅ COMPLETED: %s (+10 points)" % city_name)
			else:
				print("❌ FAILED: %s (-10 points)" % city_name)
		print("Total Score: ", PlayerData.get_player(p)["score"])
