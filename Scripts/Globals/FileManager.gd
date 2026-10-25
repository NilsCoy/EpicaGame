extends Node

func open_or_create_directory(path: String, dir_name: String) -> DirAccess:
	var dir: DirAccess = DirAccess.open(path+'/'+dir_name)
	if dir == null:
		dir = DirAccess.open(path)
		dir.make_dir(dir_name)
		dir = DirAccess.open(path+'/'+dir_name)
	return dir

func get_files_in_directory(path: String) -> Array:
	var files: Array[String]
	var dir: DirAccess = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():  # Проверяем, что это файл, а не папка
				files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Ошибка открытия директории: ", path)
	return files

func get_file_path(path: String, root_dir: bool) -> String:
	if root_dir: return 'res://' + path
	else: return 'user://' + path

func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_string: String = file.get_as_text()
		file.close()

		# Поврежденный или неверный JSON не должен вызывать краш
		var json: JSON = JSON.new()
		var error: Error = json.parse(json_string)
		if error != OK:
			push_error("Ошибка чтения JSON %s (строка %d): %s" % [path, json.get_error_line(), json.get_error_message()])
			return {}
		if not(json.data is Dictionary):
			push_error("Ошибка чтения JSON %s: ожидался словарь" % path)
			return {}
		return json.data
	else: return {}

## Сохраняет словарь в JSON. Запись идет во временный файл, который затем заменяет основной,
## чтобы при сбое во время записи не получить обрезанный файл
func save_json(path: String, data: Dictionary) -> bool:
	var json_string: String = JSON.stringify(data, "\t")
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Ошибка записи файла %s: %s" % [temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(json_string)
	file.close()

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var rename_error: Error = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		push_error("Ошибка сохранения файла %s: %s" % [path, error_string(rename_error)])
		return false
	return true

func save_file(path: String, node: Node) -> void:
	var json_string: String = JSON.stringify(node.save_data())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		#print("Safe node!")

func load_file(path: String, scene: PackedScene) -> Node:
	var result: Dictionary = read_json(path)
	if result:
		var node: Node = scene.instantiate()
		node.load_data(result)
		#print("Load node!")
		return node

	return null

func call_save_on_all_nodes(node: Node) -> void:
	_recursive_save_call(node)

func _recursive_save_call(node: Node) -> void:
	if node.has_method("save"):
		node.save()  
	for child: Node in node.get_children():
		_recursive_save_call(child)

func copy_file(from_path: String, to_path: String) -> void:
	var data: PackedByteArray = FileAccess.get_file_as_bytes(from_path)
	var file: FileAccess = FileAccess.open(to_path, FileAccess.WRITE)
	file.store_buffer(data)

func copy_dir(from_path: String, to_path: String) -> void:
	var dir: DirAccess = DirAccess.open(from_path)
	if dir == null:
		push_error("Cannot open directory: " + from_path)
		return
	DirAccess.make_dir_recursive_absolute(to_path)
	
	dir.list_dir_begin()
	var name: String = dir.get_next()
	
	while name != "":
		if name != "." and name != "..":
			var src: String = from_path.path_join(name)
			var dst: String = to_path.path_join(name)
			
			if dir.current_is_dir():
				# рекурсивно копируем подпапку
				copy_dir(src, dst)
			else:
				copy_file(src, dst)
		name = dir.get_next()
	dir.list_dir_end()
