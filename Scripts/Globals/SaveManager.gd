extends Node

## Сохранение игроков на сервере: инвентарь, хотбар, экипировка (и предмет в курсоре).
## Файл сохранения называется по постоянному player_id, никогда по нику.
## Индекс nickname -> player_id лежит рядом (ники уникальны).
## Изменения помечаются dirty и пишутся периодически, при отключении игрока и при остановке сервера.

## Интервал автосохранения измененных игроков (секунды)
const AUTOSAVE_INTERVAL: float = 60.0
const INDEX_FILE: String = "index.json"

## player_id -> есть несохраненные изменения
var _dirty: Dictionary[String, bool] = {}
## Игроки на сервере: player_id -> nickname
var _online: Dictionary[String, String] = {}
## Индекс nickname -> player_id
var _index: Dictionary = {}
var _index_loaded: bool = false

var _autosave_timer: Timer

func _ready() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(flush)
	add_child(_autosave_timer)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_all()

## Папка сохранений игроков
func get_save_dir() -> String:
	if OS.has_feature("dedicated_server"):
		return "./saves/players"
	return FileManager.get_file_path("saves/players", false)

func _get_player_path(player_id: String) -> String:
	return get_save_dir().path_join(player_id + ".json")


# =====================================================
# ИНДЕКС NICKNAME -> PLAYER_ID
# =====================================================

## Постоянный player_id по нику. Для нового игрока создается UUID
func get_player_id(nickname: String) -> String:
	var player_id: String = find_player_id(nickname)
	if player_id != "":
		return player_id

	player_id = Global.generate_uuid_v4()
	_index[nickname] = player_id
	_save_index()
	print("SaveManager: новый игрок %s -> %s" % [nickname, player_id])
	return player_id

## Поиск player_id по нику, пустая строка если игрок не найден
func find_player_id(nickname: String) -> String:
	_load_index()
	return str(_index.get(nickname, ""))

func _load_index() -> void:
	if _index_loaded:
		return
	_index_loaded = true
	DirAccess.make_dir_recursive_absolute(get_save_dir())

	var path: String = get_save_dir().path_join(INDEX_FILE)
	if FileAccess.file_exists(path):
		_index = FileManager.read_json(path)
		if not _index.is_empty():
			return
		push_error("SaveManager: индекс игроков поврежден, восстанавливаю по файлам сохранений")
	_rebuild_index()

## Восстановление индекса по файлам сохранений (если индекс потерян или поврежден)
func _rebuild_index() -> void:
	_index = {}
	for file: String in FileManager.get_files_in_directory(get_save_dir()):
		if file == INDEX_FILE or file.get_extension() != "json":
			continue
		var data: Dictionary = FileManager.read_json(get_save_dir().path_join(file))
		var nickname: String = str(data.get("nickname", ""))
		var player_id: String = str(data.get("player_id", ""))
		if nickname != "" and player_id != "":
			_index[nickname] = player_id
	if not _index.is_empty():
		_save_index()

func _save_index() -> void:
	DirAccess.make_dir_recursive_absolute(get_save_dir())
	FileManager.save_json(get_save_dir().path_join(INDEX_FILE), _index)


# =====================================================
# ЗАГРУЗКА
# =====================================================

## Загружает сохранение игрока в его зарегистрированные инвентари.
## Нет сохранения — остается стартовый инвентарь. Поврежденное сохранение откладывается в .corrupted
func load_player(player: Node) -> void:
	var player_id: String = InventoryNetwork.get_player_uuid(player)
	if player_id == "":
		push_error("SaveManager: у игрока %s нет player_id" % player.name)
		return
	_online[player_id] = str(player.get("nickname"))

	var path: String = _get_player_path(player_id)
	if not FileAccess.file_exists(path):
		print("SaveManager: сохранение игрока %s не найдено, используется стартовый инвентарь" % player.get("nickname"))
		mark_dirty(player_id)
		return

	var data: Dictionary = FileManager.read_json(path)
	if data.is_empty():
		push_error("SaveManager: сохранение %s повреждено, используется стартовый инвентарь" % path)
		DirAccess.rename_absolute(path, path + ".corrupted")
		mark_dirty(player_id)
		return

	if str(data.get("player_id", "")) != player_id:
		push_warning("SaveManager: player_id в файле %s не совпадает с %s" % [path, player_id])

	for kind: String in InventoryNetwork.SAVED_KINDS:
		if not data.has(kind):
			continue
		var inventory_data: InventoryData = InventoryNetwork.get_inventory(
			InventoryNetwork.make_player_inventory_id(player_id, kind)
		)
		if inventory_data == null:
			push_warning("SaveManager: инвентарь '%s' игрока %s не зарегистрирован" % [kind, player_id])
			continue
		if not(data[kind] is Dictionary):
			push_error("SaveManager: неверный формат '%s' в %s" % [kind, path])
			continue

		var backup: Dictionary = inventory_data.create_backup()
		inventory_data.apply_dict(data[kind], true)
		var error: String = inventory_data.get_state_error()
		if error != "":
			push_error("SaveManager: '%s' в %s поврежден (%s), используется стартовый" % [kind, path, error])
			inventory_data.restore_backup(backup)

	print("SaveManager: загружен игрок %s (%s)" % [player.get("nickname"), player_id])


# =====================================================
# СОХРАНЕНИЕ
# =====================================================

## Пометить игрока как измененного (запись произойдет позже, не на каждый клик)
func mark_dirty(player_id: String) -> void:
	if player_id != "":
		_dirty[player_id] = true

func is_dirty(player_id: String) -> bool:
	return _dirty.get(player_id, false)

## Сохранение игрока по узлу
func save_player(player: Node) -> bool:
	var player_id: String = InventoryNetwork.get_player_uuid(player)
	if player_id == "":
		push_error("SaveManager: у игрока %s нет player_id, сохранение невозможно" % player.name)
		return false
	_online[player_id] = str(player.get("nickname"))
	return save_player_id(player_id)

## Сохранение игрока по player_id (инвентари берутся из реестра InventoryNetwork)
func save_player_id(player_id: String) -> bool:
	var data: Dictionary = {
		"player_id": player_id,
		"nickname": _online.get(player_id, "")
	}

	var has_inventories: bool = false
	for kind: String in InventoryNetwork.SAVED_KINDS:
		var inventory_data: InventoryData = InventoryNetwork.get_inventory(
			InventoryNetwork.make_player_inventory_id(player_id, kind)
		)
		if inventory_data != null:
			data[kind] = inventory_data.to_dict()
			has_inventories = true

	if not has_inventories:
		push_warning("SaveManager: у игрока %s нет зарегистрированных инвентарей, сохранение пропущено" % player_id)
		_dirty.erase(player_id)
		return false

	DirAccess.make_dir_recursive_absolute(get_save_dir())
	if not FileManager.save_json(_get_player_path(player_id), data):
		return false

	_dirty.erase(player_id)
	return true

## Сохранение всех измененных игроков (автосохранение)
func flush() -> void:
	for player_id: String in _dirty.keys():
		save_player_id(player_id)

## Сохранение всех игроков на сервере (остановка сервера)
func save_all() -> void:
	for player_id: String in _online.keys():
		save_player_id(player_id)

## Игрок ушел с сервера
func forget_player(player_id: String) -> void:
	_online.erase(player_id)
	_dirty.erase(player_id)
