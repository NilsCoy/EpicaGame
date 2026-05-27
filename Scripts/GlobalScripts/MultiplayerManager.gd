extends Node

var ip: String = "127.0.0.1"
var port: int = 12345
var max_players: int = 30
var max_channels: int = 1

var peer: ENetMultiplayerPeer
var _player_scene: Resource = preload("res://Scenes/Entities/player.tscn")
var _player_spawner: Node
var _player_spawn: Node3D
var map: Node

func _ready() -> void:
	map = get_tree().root.get_node("Main/Map")
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
		multiplayer.server_disconnected.connect(_on_disconnected)
		#create_client()

func create_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, max_players, max_channels)
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
	var err: Error = peer.create_client(ip, port, max_channels)
	print("Create client error: " + str(err))
	multiplayer.multiplayer_peer = peer
func _on_connected() -> void:
	map.rpc_id(1, "load_scene")
	print("Connected to server")
func _on_failed() -> void:
	print("Connection failed")
func _on_disconnected() -> void:
	print("Disconnect!")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

@rpc("any_peer", "call_remote", "reliable", 1)
func create_player(id: int, nickname: String) -> void:
	if multiplayer.is_server():
		for user: Node in _player_spawner.get_children():
			if user.name == nickname:
				kick_player(id, "nickname is occupied")
				return
		var player: CharacterBody3D = _player_scene.instantiate()
		print("Player connected: ", id, " / ", nickname)
		player.player_id = id
		player.name = nickname
		player.nickname = nickname
		player.position = _player_spawn.position
		player.spawn_position = _player_spawn.position
		player.spawn_rotation = _player_spawn.rotation
		player.set_multiplayer_authority(id)
		_player_spawner.add_child(player)
		map.rpc("add_player", [player.serialize()])
		#player.rpc("init_sunc", player.save_data(), id)
		player._switch_gamemode(int(Settings.world['settings']['default_gamamode']))
		player.model.model.rotation = _player_spawn.rotation

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

@rpc("any_peer", "unreliable")
func send_log(message: String) -> void:
	if multiplayer.is_server():
		print(message)

func kick_player(player_id: int, reason: String) -> void:
	if multiplayer.is_server():
		multiplayer.multiplayer_peer.disconnect_peer(player_id)
		print("Игрок ", player_id, " был кикнут с сервера")
		print("Причина: ", reason)
