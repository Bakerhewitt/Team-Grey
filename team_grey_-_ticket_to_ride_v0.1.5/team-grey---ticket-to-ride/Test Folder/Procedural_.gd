extends Node2D

const CANVAS_SIZE: float = 800
const MIN_CITY_DIST: float = 150.0 # Increased to give cities more breathing room

var cities: Dictionary = {} 
var routes: Array = [] 
var destination_cards: Array = []

var hovered_route = null

func _ready():
	# Set a seed if you want the same map every time, or leave random
	randomize() 
	generate_board()
	queue_redraw()

#I hate the rewrite of this but its working for now
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos = get_local_mouse_position()
			var route = get_clicked_route(mouse_pos)

			if route != null:
				var gm = get_tree().get_first_node_in_group("game_manager")

				if gm:
					var success = gm.claim_route(gm.current_player, route[0], route[1])

					#ONLY redraw if claim succeeded
					if success:
						queue_redraw()

func _process(delta):
	var mouse_pos = get_local_mouse_position()
	hovered_route = get_clicked_route(mouse_pos)
	queue_redraw()

func get_clicked_route(pos: Vector2):
	var best_route = null
	var best_dist = INF
	var click_threshold = 12.0

	for route in routes:
		var a = cities[route[0]]
		var b = cities[route[1]]

		var closest = Geometry2D.get_closest_point_to_segment(pos, a, b)
		var dist = pos.distance_to(closest)

		if dist < best_dist:
			best_dist = dist
			best_route = route

	if best_dist <= click_threshold:
		return best_route

	return null


func generate_cities(count: int):
	var attempts = 0
	while cities.size() < count and attempts < 500:
		var pos = Vector2(randf_range(50, CANVAS_SIZE - 50), randf_range(50, CANVAS_SIZE - 50))
		var valid = true
		for c_pos in cities.values():
			if pos.distance_to(c_pos) < MIN_CITY_DIST:
				valid = false
				break
		if valid:
			cities[cities.size()] = pos
		attempts += 1

func generate_board():
	cities.clear()
	routes.clear()
	generate_cities(18)

	# 1. PERIMETER (Mandatory Fence)
	var hull = get_convex_hull_ids()
	for i in range(hull.size()):
		add_route(hull[i], hull[(i + 1) % hull.size()])
		
	# 2. THE EDGE SNAP (Include cities like 14 in the loop)
	for id in cities.keys():
		if get_city_degree(id) == 0:
			for r_idx in range(routes.size() - 1, -1, -1):
				var r = routes[r_idx]
				var p_start = cities[r[0]]
				var p_end = cities[r[1]]
				var p_city = cities[id]
				var closest = Geometry2D.get_closest_point_to_segment(p_city, p_start, p_end)
				if p_city.distance_to(closest) < 60.0:
					var old_id1 = r[0]
					var old_id2 = r[1]
					routes.remove_at(r_idx)
					add_route(id, old_id1)
					add_route(id, old_id2)
					break

	# 3. DENSE INNER HUB CONNECTIONS (The "Web")
	# We run two passes to ensure the middle fills out
	for pass_num in range(2):
		for id in cities.keys():
			# If city is NOT on the perimeter, it wants lots of connections
			var is_inner = not id in hull
			var target_connections = 6 if is_inner else 3
			
			if get_city_degree(id) < target_connections:
				# Look for more potential neighbors in the second pass
				var search_count = 5 if pass_num == 0 else 8
				var neighbors = get_closest_neighbors(id, search_count)
				for n_id in neighbors:
					if get_city_degree(id) >= target_connections: break
					# Internal connections use the angle check to keep it looking tidy
					add_route_if_valid(id, n_id, false)
			
	# 4. FINAL CLEANUP
	# Ensure every city has at least 3 connections for maximum playability
	for id in cities.keys():
		while get_city_degree(id) < 3:
			connect_to_nearest_neighbor(id)
			
	generate_destination_cards(10)
	#To make sure the ownership test actually works
	ensure_route_ownership()
	
	# Optional: Print to console to verify they generated
	print("--- Destination Cards Generated ---")
	for card in destination_cards:
		print("Ticket: City %d to City %d (%d points)" % [card.from, card.to, card.points])

# Helper to find which perimeter city is closest
func get_closest_perimeter_city(target_id: int, hull_ids: Array) -> int:
	var best_dist = INF
	var best_id = -1
	for h_id in hull_ids:
		var d = cities[target_id].distance_to(cities[h_id])
		if d < best_dist:
			best_dist = d
			best_id = h_id
	return best_id

# Updated helper with a "Zig-Zag" filter
func add_route_if_valid(id1: int, id2: int, ignore_angles: bool = false):
	if id1 == id2 or is_route_duplicate(id1, id2): return
	
	var p1 = cities[id1]
	var p2 = cities[id2]
	
	if p1.distance_to(p2) > 300.0: return 
	if is_any_city_blocking(id1, id2): return

	# ZIG-ZAG FILTER: Prevents awkward sharp angles
	if not ignore_angles:
		if is_angle_too_sharp(id1, id2) or is_angle_too_sharp(id2, id1):
			return

	if not is_line_crossing_existing(p1, p2):
		add_route(id1, id2)

func is_angle_too_sharp(from_id: int, to_id: int) -> bool:
	var p_center = cities[from_id]
	var p_new = cities[to_id]
	var new_dir = (p_new - p_center).normalized()
	
	for r in routes:
		var other_id = -1
		if r[0] == from_id: other_id = r[1]
		elif r[1] == from_id: other_id = r[0]
		
		if other_id != -1:
			var existing_dir = (cities[other_id] - p_center).normalized()
			# Dot product check: if > 0.8, routes are too parallel (zig-zaggy)
			# If < -0.9, routes are almost a straight line (usually okay)
			if new_dir.dot(existing_dir) > 0.75: 
				return true
	return false

func is_any_city_blocking(id1: int, id2: int) -> bool:
	var p1 = cities[id1]
	var p2 = cities[id2]
	
	for test_id in cities.keys():
		if test_id == id1 or test_id == id2: continue
		var p_test = cities[test_id]
		
		# Find the closest point on the line segment p1-p2 to p_test
		var closest = Geometry2D.get_closest_point_to_segment(p_test, p1, p2)
		
		# If a city is within 40 pixels of the line, it "blocks" the direct path
		# This forces the map to connect to the 'middle' city instead.
		if p_test.distance_to(closest) < 40.0:
			return true
	return false

# Find the N closest cities to a specific city
func get_closest_neighbors(target_id: int, count: int) -> Array:
	var list = []
	for id in cities.keys():
		if id == target_id: continue
		var d = cities[target_id].distance_to(cities[id])
		list.append({"id": id, "dist": d})
	
	# Sort by distance
	list.sort_custom(func(a, b): return a.dist < b.dist)
	
	var result = []
	for i in range(min(count, list.size())):
		result.append(list[i].id)
	return result

# Simple way to find outer cities (The "Hull")
func get_convex_hull_ids() -> Array:
	var hull_points = Geometry2D.convex_hull(cities.values())
	var hull_ids = []
	# Convert back from positions to our IDs
	for p in hull_points:
		for id in cities:
			if cities[id].distance_to(p) < 1.0:
				hull_ids.append(id)
				break
	return hull_ids

func is_route_duplicate(id1, id2):
	for r in routes:
		if (r[0] == id1 and r[1] == id2) or (r[0] == id2 and r[1] == id1):
			return true
	return false

func is_line_crossing_existing(p1: Vector2, p2: Vector2) -> bool:
	for route in routes:
		var a = cities[route[0]]
		var b = cities[route[1]]
		if geometry_segment_intersection(p1, p2, a, b):
			return true
	return false

func geometry_segment_intersection(a, b, c, d):
	var intersect = Geometry2D.segment_intersects_segment(a, b, c, d)
	if intersect:
		# Check if the intersection is just the cities themselves
		if intersect.distance_to(a) < 1.0 or intersect.distance_to(b) < 1.0 or \
		   intersect.distance_to(c) < 1.0 or intersect.distance_to(d) < 1.0:
			return false
		return true
	return false

func add_route(id1: int, id2: int):
	# 1. Safety: Never connect a city to itself
	if id1 == id2: return
	
	# 2. Safety: Never add a route that already exists (in either direction)
	if is_route_duplicate(id1, id2): return
	
	var d = cities[id1].distance_to(cities[id2])
	
	# 3. Safety: Ignore 'Micro-Routes' (less than 30 pixels) 
	# These usually cause the visual glitches you see at City 0
	if d < 30.0: return

	var length = max(1, floor(d / 60))
	var route_color = [
		Color.DARK_RED, Color.ROYAL_BLUE, Color.FOREST_GREEN, 
		Color.GOLDENROD, Color.WEB_GRAY, Color.MEDIUM_PURPLE
	].pick_random()
	
	routes.append([id1, id2, length, route_color, -1])

func _draw():
	# 1. Background (Parchment color)
	draw_rect(Rect2(0, 0, CANVAS_SIZE, CANVAS_SIZE), Color(0.9, 0.85, 0.7))
	
	# 2. Get font safely
	var temp_node = Control.new()
	var font = temp_node.get_theme_default_font()
	temp_node.free()
	
# 3. Draw Routes (Lines/Tracks)
	for route in routes:
		var color = route[3]
		
		var gm = get_tree().get_first_node_in_group("game_manager")

		# Owned route → player color
		if route[4] != -1 and gm:
			color = gm.get_player_color(route[4])
			
		# Hover highlight
		elif route == hovered_route:
			color = color.lightened(0.5)
			
		# route[0] = from, route[1] = to, route[2] = segments, route[3] = color
		draw_train_route(cities[route[0]], cities[route[1]], route[2], color)
		
	# 4. Draw Cities
	for id in cities:
		var pos = cities[id]
		var degree = get_city_degree(id)
		
		# Hubs (degree 4+) get a larger radius
		var radius = 10 + (degree * 1.2) 
		
		# Draw Shadow
		draw_circle(pos, radius + 2, Color(0.1, 0.1, 0.1, 0.5))
		# Draw Main Circle
		draw_circle(pos, radius, Color.ANTIQUE_WHITE)
		# Draw Border
		draw_arc(pos, radius, 0, TAU, 32, Color.DARK_SLATE_GRAY, 2.0)
		
		# Label (City ID)
		draw_string(font, pos + Vector2(-30, -radius - 10), "City " + str(id), HORIZONTAL_ALIGNMENT_CENTER, 60.0, 14, Color.BLACK)
	#TEMP Turn Order addition
	draw_turn_indicator(font)

func draw_turn_indicator(font):
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm == null:
		return

	var player_index = gm.current_player
	var player_number = player_index + 1
	var player_name = gm.players[player_index]["name"]
	var color = gm.get_player_color(player_index)

	#Will Print Players Nane or just a number if none (will be none for now)
	var text = "Player %d's Turn" % player_number

	#Background box
	var pos = Vector2(20, 20)
	var text_size = font.get_string_size(text)

	#Draw text
	draw_string(font, pos + Vector2(0, text_size.y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)

func draw_train_route(from: Vector2, to: Vector2, segments: int, track_color: Color):
	var dir = (to - from).normalized()
	var dist = from.distance_to(to)
	var usable_dist = dist - 30 
	var segment_len = usable_dist / segments 
	
	for i in range(segments):
		var center = from + dir * (segment_len * i + segment_len/2 + 15)
		draw_set_transform(center, dir.angle(), Vector2.ONE)
		
		# Track Border (Fixed Dark Gray)
		draw_rect(Rect2(-segment_len/2 + 2, -6, segment_len - 4, 12), Color(0.1, 0.1, 0.1))
		
		# Track Color (Now using the random color we assigned!)
		draw_rect(Rect2(-segment_len/2 + 4, -4, segment_len - 8, 8), track_color)
	
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	
func get_city_degree(id: int) -> int:
	var count = 0
	for r in routes:
		if r[0] == id or r[1] == id:
			count += 1
	return count
	
# Finds the nearest neighbor that doesn't cause a line crossing
func connect_to_nearest_neighbor(id: int):
	var best_dist = INF
	var best_id = -1
	for other_id in cities.keys():
		if id == other_id or is_route_duplicate(id, other_id): continue
		var d = cities[id].distance_to(cities[other_id])
		if d < best_dist:
			if not is_line_crossing_existing(cities[id], cities[other_id]):
				best_dist = d
				best_id = other_id
	if best_id != -1:
		add_route(id, best_id)
		


func generate_destination_cards(count: int):
	destination_cards.clear()
	
	# Setup AStar pathfinding to 'read' the map
	var astar = AStar2D.new()
	for id in cities:
		astar.add_point(id, cities[id])
	for route in routes:
		astar.connect_points(route[0], route[1])
	
	var attempts = 0
	while destination_cards.size() < count and attempts < 150:
		attempts += 1
		var id1 = cities.keys().pick_random()
		var id2 = cities.keys().pick_random()
		
		if id1 == id2 or is_card_duplicate(id1, id2): continue
		
		# Check if a path actually exists between these two cities
		var path = astar.get_id_path(id1, id2)
		
		# Only keep cards that are challenging (at least 3 tracks long)
		if path.size() >= 4: 
			var points = calculate_path_points(path)
			destination_cards.append({"from": id1, "to": id2, "points": points})

func calculate_path_points(path: Array) -> int:
	var total_segments = 0
	for i in range(path.size() - 1):
		for r in routes:
			if (r[0] == path[i] and r[1] == path[i+1]) or (r[1] == path[i] and r[0] == path[i+1]):
				total_segments += r[2]
				break
	return total_segments * 2

func is_card_duplicate(id1, id2):
	for c in destination_cards:
		if (c.from == id1 and c.to == id2) or (c.from == id2 and c.to == id1):
			return true
	return false

func ensure_route_ownership():
	for i in range(routes.size()):
		if routes[i].size() < 5:
			routes[i].append(-1)
