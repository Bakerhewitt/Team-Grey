extends Node

# --- Configuration & Variables ---
const MIN_CITY_DIST: float = 100.0 
const CANVAS_SIZE: float = 800.0

var city_names_pool: Array = ["Amsterdam", "Berlin", "Casablanca", "Dublin", "Edinburgh", "Florence", "Geneva", "Helsinki", "Istanbul", "Jakarta", "Kyoto", "London", "Madrid", "Naples", "Oslo", "Paris", "Quebec", "Rome", "Stockholm", "Tokyo", "Utrecht", "Vienna", "Warsaw", "Zurich"]

# Data structures used during generation
var cities: Dictionary = {}
var city_id_to_name: Dictionary = {}
var routes: Array = []
var destination_cards: Array = []

# --- Main Entry Point ---
# This matches the call made by NetworkManager: board.generate_full_board(seed, size)
func generate_full_board(game_seed: int, _size: float) -> Dictionary:
	seed(game_seed)
	
	cities.clear()
	city_id_to_name.clear()
	routes.clear()
	destination_cards.clear()

	# 1. Generate Cities
	_generate_cities_logic(18)

	# 2. Perimeter (Convex Hull)
	var hull = get_convex_hull_ids()
	for i in range(hull.size()):
		add_route(hull[i], hull[(i + 1) % hull.size()])
		
	# 3. ADVANCED EDGE SNAP & DECOLLISION (THE FIX)
	# Iterate through EVERY city to check for collisions with the perimeter routes
	for id in cities.keys():
		if not id in hull:
			for r_idx in range(routes.size() - 1, -1, -1):
				var r = routes[r_idx]
				var hull_p1 = cities[r[0]]
				var hull_p2 = cities[r[1]]
				var closest = Geometry2D.get_closest_point_to_segment(cities[id], hull_p1, hull_p2)
				if cities[id].distance_to(closest) < 45.0:
					var old_id1 = r[0]
					var old_id2 = r[1]
					var was_double = r[4] # Preserve if it was a double route
					
					routes.remove_at(r_idx)


					# Re-add as two separate, clean routes
					# This forces the distance/segment calculation to reset
					add_route(id, old_id1, was_double)
					add_route(id, old_id2, was_double)
					break
				
	# 4. Dense Inner Hub Connections
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
			
	# 5. Final Cleanup
	for id in cities.keys():
		while get_city_degree(id) < 3:
			connect_to_nearest_neighbor(id)
			
	# 6. Double Route Conversion
	for i in range(routes.size() - 1, -1, -1):
		var r = routes[i]
		if get_city_degree(r[0]) >= 4 and get_city_degree(r[1]) >= 4:
			if not r[4]: # If not already double
				var id1 = r[0]
				var id2 = r[1]
				routes.remove_at(i)
				add_route(id1, id2, true)
			
	generate_destination_cards(10)

	# Return the completed data to the Network Manager
	return {
		"cities": cities.duplicate(),
		"names": city_id_to_name.duplicate(),
		"routes": routes.duplicate(),
		"cards": destination_cards.duplicate()
	}

# --- Logic Sub-Functions ---

func _generate_cities_logic(count: int):
	var attempts = 0
	var available_names = city_names_pool.duplicate()
	available_names.shuffle()
	
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
			if available_names.size() > 0:
				city_id_to_name[id] = available_names.pop_back()
			else:
				city_id_to_name[id] = "Station " + str(id)
		attempts += 1

func add_route(id1: int, id2: int, is_double: bool = false):
	if id1 == id2 or is_route_duplicate(id1, id2): return
	var d = cities[id1].distance_to(cities[id2])
	if d < 30.0: return

	var length = clamp(floor(d / 55), 2, 6)
	var colors = [Color.DARK_RED, Color.ROYAL_BLUE, Color.FOREST_GREEN, Color.GOLDENROD, 
				 Color.WEB_GRAY, Color.MEDIUM_PURPLE, Color.WHITE, Color.ORANGE]
	
	var color1 = colors.pick_random()
	# Structure: [id1, id2, length, color, is_double, lane_index, claimed_by_id]
	routes.append([id1, id2, length, color1, is_double, 0, -1])
	
	if is_double:
		var color2 = colors.pick_random()
		while color2 == color1: color2 = colors.pick_random()
		routes.append([id1, id2, length, color2, is_double, 1, -1])

# --- Helper Functions ---

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
