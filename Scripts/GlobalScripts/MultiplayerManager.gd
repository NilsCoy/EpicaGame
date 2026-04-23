extends Node

var peer: ENetMultiplayerPeer
var ip: String = "127.0.0.1"
var port: int = 12345

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		create_server()
	else:
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_failed)
		multiplayer.peer_disconnected.connect(_on_disconnected)
		#create_client()


func create_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port)
	print("Create server error: " + str(err))
	multiplayer.multiplayer_peer = peer
	print("Server started on port: ", port)
func _on_peer_connected(id: int) -> void:
	print("Player connected: ", id)
func _on_peer_disconnected(id: int) -> void:
	print("Player disconnected: ", id)


func create_client() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, port)
	print("Create client error: " + str(err))
	multiplayer.multiplayer_peer = peer
func _on_connected() -> void:
	print("Connected to server")
func _on_failed() -> void:
	print("Connection failed")
func _on_disconnected() -> void:
	print("Disconnect!")


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
func receive_message(msg: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	print("Got:", msg)
	rpc_id(sender, "receive_from_server", "Echo: " + msg)

@rpc("authority")
func receive_from_server(msg: String) -> void:
	print("Server: ", msg)

func send_message(text: String) -> void:
	rpc_id(1, "receive_message", text)
