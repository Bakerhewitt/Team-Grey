extends Node

@onready var ui = $MultiplayerUI
@onready var address_input = $MultiplayerUI/StartPanel/AddressInput
@onready var game_container = $GameContainer
@export var board_scene: PackedScene # Assign your Board.tscn here in the Inspector

const PORT = 7000
var peer = ENetMultiplayerPeer.new()

func _ready():
	# Connect UI buttons
	$MultiplayerUI/StartPanel/HostButton.pressed.connect(_on_host_pressed)
	$MultiplayerUI/StartPanel/JoinButton.pressed.connect(_on_join_pressed)
	multiplayer.peer_connected.connect(_on_peer_connected)
	
func _on_peer_connected(id):
	if multiplayer.is_server():
		print("Player joined! ID: ", id)
		# Now that someone is here, load the board
		if not game_container.has_node("GameBoard"):
			load_board()
			
func _on_host_pressed():
	ui.hide()
	peer.create_server(PORT, 4) # Allow up to 4 players
	multiplayer.multiplayer_peer = peer
	print("Hosting on PORT ", PORT)
	print("Waiting for players...")
	


func _on_join_pressed():
	ui.hide()
	var txt = address_input.text if address_input.text != "" else "127.0.0.1"
	peer.create_client(txt, PORT)
	multiplayer.multiplayer_peer = peer
	print("Joining address: ", txt)

func start_game():
	# Here we will instance your board generation script
	# For now, let's just make sure the server triggers it
	if multiplayer.is_server():
		load_board()

func load_board():
	if multiplayer.is_server():
		var board_instance = board_scene.instantiate()
		# Set a name so the spawner can track it easily
		board_instance.name = "GameBoard" 
		game_container.add_child(board_instance)
