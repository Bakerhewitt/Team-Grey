extends Node2D

# Constants and Settings
const NOISE_SCALE: float = 0.02
const MIN_DISTANCE: float = 40.0
const MAX_PATHS: int = 10
const CANVAS_SIZE: float = 500.0

var start_point: Vector2
var end_point: Vector2
var astar = AStar2D.new()
var points: Array[Vector2] = []
var active_points: Dictionary = {} # Use dictionary for quick lookup
var all_paths: Array[PackedInt64Array] = [] # Stores the sequences of point IDs

func _ready():
	# 1. Setup Coordinates
	start_point = Vector2(CANVAS_SIZE * 0.45, CANVAS_SIZE * 0.9)
	end_point = Vector2(CANVAS_SIZE * 0.45, CANVAS_SIZE * 0.1)
	
	generate_graph()
	queue_redraw() # Tells Godot to call _draw()

func generate_graph():
	# 2. Simple Random Point Generation (Simplified Poisson Replacement)
	points.append(start_point)
	points.append(end_point)
	
	var center = Vector2(CANVAS_SIZE * 0.45, CANVAS_SIZE * 0.45)
	var radius = CANVAS_SIZE * 0.45
	
	for i in range(100):
		var p = Vector2(randf_range(0, CANVAS_SIZE), randf_range(0, CANVAS_SIZE))
		if p.distance_to(center) <= radius:
			var too_close = false
			for existing in points:
				if p.distance_to(existing) < MIN_DISTANCE:
					too_close = true
					break
			if not too_close:
				points.append(p)

	# 3. Build AStar Graph (Simplified Delaunay Replacement)
	for i in range(points.size()):
		astar.add_point(i, points[i])
	
	for i in range(points.size()):
		for j in range(i + 1, points.size()):
			var d = points[i].distance_to(points[j])
			# Only connect points within a reasonable distance
			if d < 100:
				astar.connect_points(i, j)

	# 4. Find multiple paths and remove middle nodes (Iterative Pathfinding)
	var start_id = astar.get_closest_point(start_point)
	var end_id = astar.get_closest_point(end_point)
	
	for i in range(MAX_PATHS):
		var path_ids = astar.get_id_path(start_id, end_id)
		if path_ids.size() < 2:
			break
			
		all_paths.append(path_ids) # Save the path to draw later!
		# Store path for drawing
		for id in path_ids:
			active_points[id] = points[id]
			
		# Remove a random internal node to force a new path next iteration
		if path_ids.size() > 2:
			var remove_idx = randi_range(1, path_ids.size() - 2)
			astar.remove_point(path_ids[remove_idx])

func _draw():
	# 1. Background
	draw_rect(Rect2(0, 0, CANVAS_SIZE, CANVAS_SIZE), Color(0.15, 0.2, 0.2))
	
	# 2. Get the font safely
	# We create a dummy Control node just to "borrow" the default system font
	var temp_node = Control.new()
	var font = temp_node.get_theme_default_font()
	temp_node.free() # Clean up the dummy node
	
	# --- Draw Path Lines ---
	for path in all_paths:
		for i in range(path.size() - 1):
			var p1 = points[path[i]]
			var p2 = points[path[i+1]]
			
			# Using Godot's built-in draw_line
			# Or swap this for your custom draw_dotted_arrow(p1, p2)
			draw_line(p1, p2, Color(0.3, 0.5, 0.3, 0.6), 2.0, true)
	
	# 3. Draw Points
	for id in active_points.keys():
		var p = active_points[id]
		var symbol = "💀"
		
		# Position check with a small margin of error
		if p.distance_to(start_point) < 2.0:
			symbol = "😀"
		elif p.distance_to(end_point) < 2.0:
			symbol = "😈"
		else:
			# Note: pick_random() works in Godot 4.x
			symbol = ["💀", "💰", "❓"].pick_random()
			
		# draw_string(font, position, text, alignment, width, size)
		# We offset p slightly because text draws from the baseline
		draw_string(font, p + Vector2(-10, 8), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)

# Helper function to mimic your dotted arrow
func draw_dotted_arrow(from: Vector2, to: Vector2):
	var dir = (to - from).normalized()
	var dist = from.distance_to(to)
	var arrow_size = 6
	
	# Draw dotted line
	var segments = floor(dist / 10)
	for i in range(segments):
		var s_start = from + dir * (i * 10)
		var s_end = from + dir * (i * 10 + 5)
		draw_line(s_start, s_end, Color.DARK_GREEN, 2.0)
	
	# Draw Arrowhead
	var head_pos = to - dir * 5
	draw_line(head_pos, head_pos - dir.rotated(0.5) * arrow_size, Color.DARK_GREEN, 2.0)
	draw_line(head_pos, head_pos - dir.rotated(-0.5) * arrow_size, Color.DARK_GREEN, 2.0)
