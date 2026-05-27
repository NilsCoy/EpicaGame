extends Node

var player: Dictionary
var world: Dictionary
var server: Dictionary

func _ready() -> void:
	if OS.has_feature("dedicated_server"):
		world = get_world_settings()
		server = get_server_settings()
	else:
		var dir: DirAccess = DirAccess.open(FileManager.get_file_path('configs', false))
		if dir == null:
			FileManager.copy_dir(FileManager.get_file_path('defaults/configs', true), FileManager.get_file_path('configs', false))
		player = get_player_settings()

@rpc("any_peer", "reliable")
func get_player_settings() -> Dictionary:
	var settings: Dictionary
	var files: Array = FileManager.get_files_in_directory(FileManager.get_file_path('configs', false))
	for file: String in files:
		var file_name: String = file.split('.')[0]
		settings[file_name] = FileManager.read_json(FileManager.get_file_path('configs', false) + '/' + file)
	return settings

@rpc("any_peer", "reliable")
func get_world_settings() -> Dictionary:
	var settings: Dictionary
	var files: Array = FileManager.get_files_in_directory('./world')
	for file: String in files:
		var file_name: String = file.split('.')[0]
		settings[file_name] = FileManager.read_json('./world/'+file)
	return settings

@rpc("any_peer", "reliable")
func get_server_settings() -> Dictionary:
	var settings: Dictionary
	var files: Array = FileManager.get_files_in_directory('./configs')
	for file: String in files:
		var file_name: String = file.split('.')[0]
		settings[file_name] = FileManager.read_json('./configs/'+file)
	return settings

func save_world_settings() -> void:
	for file: String in world.keys():
		FileManager.save_json('./world/'+file+'.json', world[file])
