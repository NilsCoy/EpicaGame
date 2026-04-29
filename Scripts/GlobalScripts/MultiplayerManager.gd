extends Node

var ip: String = "127.0.0.1"
var port: int = 12345
var max_players: int = 30

var peer: ENetMultiplayerPeer
var _player_scene: Resource = preload("res://Scenes/Entities/player.tscn")
var _player_spawner: Node
var _player_spawn: Node3D

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		_player_spawner = get_tree().root.get_node("Main/Map/Players")
		_player_spawn = get_tree().root.get_node('Main/Map/Spawn')
		port = int(Settings.server['settings']['server_port'])
		max_players = int(Settings.server['settings']['max_players'])
		create_server()
	else:
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_failed)
		multiplayer.peer_disconnected.connect(_on_disconnected)
		#create_client()


func create_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_players)
	print("Create server error: " + str(err))
	multiplayer.multiplayer_peer = peer
	print("Server started on port: ", port)

func _on_peer_connected(id: int) -> void:
	get_tree().root.get_node("Main/UI/MainMenu").rpc_id(id, "register_player")

func _on_peer_disconnected(id: int) -> void:
	print("Player disconnected: ", id)
	for child: Node in _player_spawner.get_children():
		if child.player_id == id:
			child.queue_free()


func create_client() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, port)
	print("Create client error: " + str(err))
	multiplayer.multiplayer_peer = peer
func _on_connected() -> void:
	get_tree().root.get_node("Main/Map").rpc_id(1, "load_scene")
	print("Connected to server")
func _on_failed() -> void:
	print("Connection failed")
func _on_disconnected(id: int) -> void:
	if id == multiplayer.get_unique_id():
		print("Disconnect!")
		get_tree().reload_current_scene()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().root.get_node("Main/UI/MainMenu").show()


func get_connect() -> String:
	var status: MultiplayerPeer = multiplayer.multiplayer_peer
	match status.get_connection_status():
		MultiplayerPeer.CONNECTION_CONNECTING:
			return 'connection'
		MultiplayerPeer.CONNECTION_CONNECTED:
			return 'connected'
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			return 'disconnect'
	return 'none'

@rpc("any_peer")
func create_player(nickname: String) -> void:
	var player: CharacterBody3D = _player_scene.instantiate()
	var id: int = multiplayer.get_remote_sender_id()
	print("Player connected: ", id, " / ", nickname)
	player.player_id = id
	player.name = nickname
	player.nickname = nickname
	player.position = _player_spawn.position
	player.model.model.rotation = _player_spawn.rotation
	player.switch_gamemode(int(Settings.world['settings']['default_gamamode']))
	_player_spawner.add_child(player)

@rpc("any_peer")
func receive_message(msg: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	print("Got:", msg)
	rpc_id(sender, "receive_from_server", "Echo: " + msg)

@rpc("authority")
func receive_from_server(msg: String) -> void:
	print("Server: ", msg)

func send_message(text: String) -> void:
	rpc_id(1, "receive_message", text)
