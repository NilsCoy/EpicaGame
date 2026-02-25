extends Node

func get_files_in_directory(path: String, root_dir: bool = true) -> Array:
	var files = []
	var dir = DirAccess.open(get_file_path(path, root_dir))
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():  # Проверяем, что это файл, а не папка
				files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Ошибка открытия директории: ", path)
	return files

func get_file_path(path: String, root_dir: bool):
	if root_dir: return 'res://' + path
	else: return 'user://' + path

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		return JSON.parse_string(json_string)
	else: return {}

func save_file(path: String, node: Node, root_dir: bool = true) -> void:
	var json_string = JSON.stringify(node.save_data())  # превращаем словарь в строку JSON
	var file = FileAccess.open(get_file_path(path, root_dir), FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("Safe node!")

func load_file(path: String, scene: PackedScene, root_dir: bool = true) -> Node:
	var result = read_json(get_file_path(path, root_dir))
	if result:
		var node = scene.instantiate()
		node.load_data(result)
		print("Load node!")
		return node

	return null
