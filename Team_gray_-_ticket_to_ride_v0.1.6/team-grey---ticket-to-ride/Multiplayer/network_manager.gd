extends Node2D

@onready var game = $GameManager_egg
@onready var board = $BoardGenerator

var players = []
var active_player_id = 0
var current_turn_index = 0
var hovered_route_index : int = -1
var cities = {}
var routes = []
var city_names = {}

func _ready():
	if multiplayer.is_server():
		get_tree().create_timer(0.1).timeout.connect(initiate_sync)

func initiate_sync():
	var game_seed = randi()
	var peer_list = multiplayer.get_peers()
	peer_list.append(1)
	peer_list.sort()
	setup_game.rpc(game_seed, peer_list)

@rpc("authority", "call_local", "reliable")
func setup_game(s, p_list):
	players = p_list
	active_player_id = players[0]
	var data = board.generate_full_board(s, 800)
	cities = data.cities
	routes = data.routes
	city_names = data.names
	queue_redraw()

@rpc("any_peer", "call_remote", "reliable")
func request_claim_route(index: int):
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1 # Handle local server calls
	
	if sender_id == active_player_id:
		sync_route_claim.rpc(index, sender_id)
		next_turn.rpc()

@rpc("authority", "call_local", "reliable")
func sync_route_claim(index: int, p_id: int):
	routes[index][6] = p_id
	if multiplayer.get_unique_id() == p_id:
		game.spend_resources(routes[index][2], routes[index][3])
	queue_redraw()

@rpc("authority", "call_local", "reliable")
func next_turn():
	current_turn_index = (current_turn_index + 1) % players.size()
	active_player_id = players[current_turn_index]
	queue_redraw()

func _input(event):
	if multiplayer.get_unique_id() != active_player_id: return
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	if event is InputEventMouseButton and event.pressed:
		if hovered_route_index != -1 and routes[hovered_route_index][6] == -1:
			if game.can_afford_route(routes[hovered_route_index]):
				if multiplayer.is_server():
					request_claim_route(hovered_route_index)
				else:
					request_claim_route.rpc_id(1, hovered_route_index)

func _update_hover(m_pos):
	var old_hover = hovered_route_index
	hovered_route_index = -1
	
	for i in range(routes.size()):
		var r = routes[i]
		var p1 = cities[r[0]]
		var p2 = cities[r[1]]
		
		# APPLY SAME OFFSET LOGIC AS DRAWING
		if r[4]: # is_double
			var dir = (p2 - p1).normalized()
			var normal = Vector2(-dir.y, dir.x)
			var offset = normal * (10.0 if r[5] == 0 else -10.0)
			p1 += offset
			p2 += offset
			
		var closest = Geometry2D.get_closest_point_to_segment(m_pos, p1, p2)
		if m_pos.distance_to(closest) < 12.0:
			hovered_route_index = i
			break
			
	if old_hover != hovered_route_index: queue_redraw()

func _draw():
	var font = ThemeDB.get_fallback_font()
	draw_rect(Rect2(0,0,800,800), Color(0.9, 0.85, 0.7))
	
	# Draw Routes
	for i in range(routes.size()):
		var r = routes[i]
		var p1 = cities[r[0]]
		var p2 = cities[r[1]]
		
		if r[4]: # is_double offset
			var dir = (p2 - p1).normalized()
			var normal = Vector2(-dir.y, dir.x)
			var offset = normal * (10.0 if r[5] == 0 else -10.0)
			p1 += offset
			p2 += offset

		if i == hovered_route_index:
			draw_line(p1, p2, Color(1,1,1,0.6), 20.0)
		
		_draw_train_route(p1, p2, r[2], r[3], r[6] != -1)



	# 3. Draw City Name "Nodes"
	for id in cities:
		var pos = cities[id]
		var name_text = city_names.get(id, "Unknown")
		var font_size = 12
	
		# 1. Get precise font metrics
		var string_size = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var ascent = font.get_ascent(font_size)
		var descent = font.get_descent(font_size)
		var total_font_height = ascent + descent
		
		# 2. Define Box Size
		var padding = Vector2(14, 8) # Slightly wider padding for a cleaner look
		var pill_size = Vector2(string_size.x + padding.x, total_font_height + padding.y)
	
		# 3. Center the Pill on the city coordinate
		var pill_rect = Rect2(pos - (pill_size / 2), pill_size)
	
		# 4. Draw Visuals (Shadow + Box)
		var shadow_offset = Vector2(2, 2)
		draw_rect(Rect2(pill_rect.position + shadow_offset, pill_rect.size), Color(0, 0, 0, 0.2), true)
		draw_rect(pill_rect, Color.ANTIQUE_WHITE, true)
		draw_rect(pill_rect, Color.DARK_SLATE_GRAY, false, 1.5)
	
		# 5. THE CENTER FIX:
		# To center vertically, we move down by the padding/2 and the ascent.
		# Then we subtract half of the total height to align the middle of the text 
		# with the middle of the box.
		var vertical_center_offset = (pill_size.y / 2) - (total_font_height / 2) + ascent
	
		var text_pos = Vector2(
			pos.x - (string_size.x / 2), 
			pill_rect.position.y + vertical_center_offset - 1 # -1 tiny tweak for visual balance
			)
	
		draw_string(font, text_pos, name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
		
func _draw_train_route(from, to, segments, color, is_claimed):
	var dir = (to - from).normalized()
	var dist = from.distance_to(to)
	
	# Keep the 70 padding for long routes, but shrink it for short ones 
	# so we don't end up with negative usable distance.
	var padding = min(70.0, dist * 0.4) 
	var usable_dist = dist - padding
	var segment_len = usable_dist / segments
	
	for i in range(segments):
		var center = from + dir * (segment_len * i + segment_len/2 + padding/2)
		draw_set_transform(center, dir.angle(), Vector2.ONE)
		
		# Dynamic width: ensures a gap even on very short routes
		var rect_w = max(segment_len - 4, 2) 
		# Dynamic height: makes short routes look less chunky
		var rect_h = clamp(segment_len, 8, 12) 
		
		if is_claimed:
			draw_rect(Rect2(-rect_w/2, -rect_h/2 - 2, rect_w, rect_h + 4), Color.CYAN)
			draw_rect(Rect2(-rect_w/2, -rect_h/2 - 2, rect_w, rect_h + 4), Color.BLACK, false, 1.5)
		else:
			# Background slot
			draw_rect(Rect2(-rect_w/2, -rect_h/2, rect_w, rect_h), Color(0.1, 0.1, 0.1))
			# Colored track
			draw_rect(Rect2(-rect_w/2 + 2, -rect_h/2 + 2, rect_w - 4, rect_h - 4), color)
	
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
