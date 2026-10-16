extends Node

const LOCALHOST: String = "127.0.0.1"
const SERVERHOST: String = "127.0.0.1"
var ip: String = LOCALHOST
var port: int = 7777
var max_players: int = 30
var max_channels: int = 0

var peer: ENetMultiplayerPeer
var _player_scene: Resource = preload("res://Scenes/Entities/player.tscn")
var map: Node
var players: Node
var player_spawn: Node3D

func _ready() -> void:
	map = get_tree().root.get_node("Main/Map")
	players = get_tree().root.get_node("Main/Map/Players")
	player_spawn = get_tree().root.get_node('Main/Map/Spawn')
	if OS.has_feature("dedicated_server"):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
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
	rpc('delete_player', id)

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

@rpc("any_peer", "call_local", "reliable", 1)
func create_player(id: int, nickname: String) -> void:
	if multiplayer.is_server():
		for user: Node in players.get_children():
			if user.name == nickname:
				kick_player(id, "nickname is occupied")
				return
		var player: CharacterBody3D = _player_scene.instantiate()
		print("Player connected: ", id, " / ", nickname)
		player.player_id = id
		player.name = nickname
		player.nickname = nickname
		player.position = player_spawn.position
		player.spawn_position = player_spawn.position
		player.spawn_rotation = player_spawn.rotation
		player.set_multiplayer_authority(id)
		players.add_child(player)
		map.rpc("add_player", [player.serialize()])
		#player.rpc("init_sunc", player.save_data(), id)
		player._switch_gamemode(int(Settings.world['settings']['default_gamamode']))
		player.model.model.rotation = player_spawn.rotation

@rpc("authority", "reliable", "call_local", 1)
func delete_player(id: int) -> void:
	for player: Node in players.get_children():
		if player.player_id == id:
			player.queue_free()

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
