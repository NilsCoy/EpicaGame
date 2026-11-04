extends Node

## Кэш предметов: item_type -> ItemData
## Заполняется один раз при первом обращении, чтобы не сканировать директории на каждый снапшот

const ITEMS_PATH: String = "Resources/Items/Data"

var _items: Dictionary[String, ItemData] = {}
var _loaded: bool = false

## Получение предмета по типу, null если такого предмета нет
func get_item(item_type: String) -> ItemData:
	if item_type == "":
		return null
	_ensure_loaded()
	return _items.get(item_type, null)

## Проверка существования предмета
func has_item(item_type: String) -> bool:
	return get_item(item_type) != null

func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_load_items()

## Предметы из .tres ресурсов
func _load_items() -> void:
	for file: String in _list_files(FileManager.get_file_path(ITEMS_PATH, true)):
		if file.get_extension() != "tres" and file.get_extension() != "res":
			continue
		var item: ItemData = load(FileManager.get_file_path(ITEMS_PATH + "/" + file, true)) as ItemData
		if item == null:
			push_warning("ItemRegistry: не удалось загрузить предмет " + file)
			continue
		var item_type: String = item.type if item.type != "" else file.get_basename()
		_items[item_type] = item

## Список файлов директории с учетом remap файлов в экспортированной игре
func _list_files(path: String) -> Array[String]:
	var result: Array[String] = []
	for file: String in FileManager.get_files_in_directory(path):
		if file.ends_with(".import") or file.ends_with(".uid"):
			continue
		file = file.trim_suffix(".remap")
		if not result.has(file):
			result.append(file)
	return result
